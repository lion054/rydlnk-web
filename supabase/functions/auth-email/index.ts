// Supabase "Send Email" auth hook.
//
// Supabase calls this instead of sending auth mail itself, so magic links,
// signup confirmations, password resets, email changes and reauthentication
// codes all render through _shared/email.ts and go out through Resend from
// rydlnk.us — the same pipeline as the invite and billing mail.
//
// This replaces the built-in mailer, which could not be fixed by editing
// templates: it sends as "Supabase Auth <noreply@mail.app.supabase.io>", stamps
// "powered by Supabase" and an opt-out link into the footer, and is rate limited
// to a handful of messages an hour — documented as unsuitable for production.
//
// Deploy:  supabase functions deploy auth-email --no-verify-jwt
// Secrets: supabase secrets set SEND_EMAIL_HOOK_SECRET=v1,whsec_… \
//            RESEND_API_KEY=re_… INVITE_FROM_EMAIL="Rydlnk <no-reply@rydlnk.us>"
//
// Then: Dashboard → Authentication → Hooks → Send Email → this function's URL,
// with the same secret. docs/NOTIFICATIONS.md has the full sequence.
//
// verify_jwt is false because Supabase Auth calls this without a user JWT. The
// request is authenticated by the Standard Webhooks HMAC signature below, which
// is checked before the body is trusted for anything.

import {
  authConfirmSignup,
  authEmailChange,
  authMagicLink,
  authReauthentication,
  authRecovery,
} from '../_shared/messages.ts';
import { sendEmail } from '../_shared/resend.ts';

/** Reject signatures older than this. Bounds replay of a captured request. */
const TOLERANCE_SECONDS = 5 * 60;

type EmailActionType =
  | 'signup'
  | 'magiclink'
  | 'recovery'
  | 'invite'
  | 'email_change'
  | 'email_change_new'
  | 'reauthentication';

type HookPayload = {
  user: { email?: string; new_email?: string };
  email_data: {
    token: string;
    token_hash: string;
    redirect_to: string;
    email_action_type: EmailActionType;
    site_url: string;
    token_new?: string;
    token_hash_new?: string;
  };
};

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  const secret = Deno.env.get('SEND_EMAIL_HOOK_SECRET');
  if (!secret) {
    // Fail closed. Without the secret every caller is unauthenticated, and this
    // endpoint can make us send mail to an arbitrary address.
    console.error('SEND_EMAIL_HOOK_SECRET is not set — refusing to send');
    return json({ error: 'hook secret not configured' }, 500);
  }

  const raw = await req.text();

  const verified = await verifySignature(req.headers, raw, secret);
  if (!verified.ok) {
    console.error('auth-email: signature rejected —', verified.reason);
    return json({ error: 'invalid signature' }, 401);
  }

  let payload: HookPayload;
  try {
    payload = JSON.parse(raw);
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const data = payload.email_data;
  const action = data?.email_action_type;
  const recipient = action === 'email_change_new' ? payload.user?.new_email : payload.user?.email;

  if (!recipient || !action) return json({ error: 'missing user email or action type' }, 400);

  const message = compose(action, data, payload);
  if (!message) {
    // An action type we have no template for. Returning an error tells Supabase
    // the send failed, which surfaces to the user, rather than silently
    // swallowing a password reset.
    console.error('auth-email: no template for action', action);
    return json({ error: `unsupported email action: ${action}` }, 400);
  }

  const sent = await sendEmail({
    to: recipient,
    subject: message.subject,
    email: message,
    tags: { type: `auth_${action}` },
  });

  if (!sent.delivered) {
    // Surfaced to Supabase as a failure so the caller sees it, unlike the
    // billing mail where a bounce must never fail the underlying operation. Here
    // the email IS the operation — a swallowed failure is a user who can never
    // sign in.
    console.error('auth-email: delivery failed', action, sent.error);
    return json({ error: sent.error ?? 'delivery failed' }, 500);
  }

  return json({});
});

// ── Composition ─────────────────────────────────────────────────────────────

/**
 * Builds the verification URL Supabase would have put in its own template.
 *
 * There is no ready-made link in the payload — the hook hands over the token and
 * expects the sender to assemble it. `token_hash` is what /auth/v1/verify
 * accepts; `token` is the six-digit code for flows that use one.
 */
function verifyUrl(
  data: HookPayload['email_data'],
  tokenHash: string,
  type: string,
): string {
  const base = (Deno.env.get('SUPABASE_URL') ?? '').replace(/\/$/, '');
  const params = new URLSearchParams({ token: tokenHash, type });
  // redirect_to is where the user lands after the token is consumed. It must be
  // on the Supabase redirect allowlist or verification fails at the last step.
  if (data.redirect_to) params.set('redirect_to', data.redirect_to);
  return `${base}/auth/v1/verify?${params.toString()}`;
}

function compose(
  action: EmailActionType,
  data: HookPayload['email_data'],
  _payload: HookPayload,
) {
  switch (action) {
    case 'magiclink':
      return authMagicLink(verifyUrl(data, data.token_hash, 'magiclink'));

    case 'signup':
      return authConfirmSignup(verifyUrl(data, data.token_hash, 'signup'));

    case 'recovery':
      return authRecovery(verifyUrl(data, data.token_hash, 'recovery'));

    // Supabase fires the change flow twice — once to the current address and
    // once to the new one. The new address gets token_hash_new.
    case 'email_change':
      return authEmailChange(verifyUrl(data, data.token_hash, 'email_change'));
    case 'email_change_new':
      return authEmailChange(
        verifyUrl(data, data.token_hash_new ?? data.token_hash, 'email_change'),
      );

    // Reauthentication carries a code, not a link.
    case 'reauthentication':
      return authReauthentication(data.token);

    // `invite` is deliberately absent: company invites are created by
    // send-company-invite, which mints its own token and owns that email. If
    // Supabase's own invite flow is ever used it should get its own template
    // rather than borrowing one that promises a company context it lacks.
    default:
      return null;
  }
}

// ── Standard Webhooks signature ─────────────────────────────────────────────

/**
 * Verifies the Standard Webhooks signature Supabase sends.
 *
 * Signed content is `{id}.{timestamp}.{body}`, HMAC-SHA256 with the secret's
 * base64 payload, compared against the base64 digest in `webhook-signature`.
 * That header can carry several space-separated `v1,<sig>` values during a
 * secret rotation, so every candidate is checked.
 */
async function verifySignature(
  headers: Headers,
  body: string,
  secret: string,
): Promise<{ ok: true } | { ok: false; reason: string }> {
  const id = headers.get('webhook-id');
  const timestamp = headers.get('webhook-timestamp');
  const signatureHeader = headers.get('webhook-signature');

  if (!id || !timestamp || !signatureHeader) return { ok: false, reason: 'missing webhook headers' };

  const sent = Number(timestamp);
  if (!Number.isFinite(sent)) return { ok: false, reason: 'unparseable timestamp' };
  const drift = Math.abs(Math.floor(Date.now() / 1000) - sent);
  if (drift > TOLERANCE_SECONDS) return { ok: false, reason: `timestamp drift ${drift}s` };

  // The dashboard shows the secret as `v1,whsec_…`; either form is accepted so a
  // copy-paste of the displayed value works.
  const base64Secret = secret.replace(/^v1,/, '').replace(/^whsec_/, '');
  let keyBytes: Uint8Array;
  try {
    keyBytes = base64ToBytes(base64Secret);
  } catch {
    return { ok: false, reason: 'secret is not valid base64' };
  }

  const key = await crypto.subtle.importKey(
    'raw',
    keyBytes,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${id}.${timestamp}.${body}`),
  );
  const expected = bytesToBase64(new Uint8Array(mac));

  const candidates = signatureHeader
    .split(' ')
    .map((part) => (part.startsWith('v1,') ? part.slice(3) : part))
    .filter(Boolean);

  for (const candidate of candidates) {
    if (timingSafeEqual(candidate, expected)) return { ok: true };
  }
  return { ok: false, reason: 'no candidate signature matched' };
}

/**
 * Constant-time string comparison.
 *
 * `===` on a signature leaks how many leading characters matched through timing.
 * The length is compared first because it is not secret.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
