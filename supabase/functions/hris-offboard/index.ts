// HRIS termination webhook.
//
// Workday, BambooHR, ADP and Deputy can all post a worker-terminated event.
// This freezes the wallet, cancels seats not yet travelled and returns the
// unspent balance to the float — immediately, not on a nightly batch, because
// a leaver riding on Monday morning is money straight out of the float.
//
// Deploy:  supabase functions deploy hris-offboard --no-verify-jwt
// Secrets: supabase secrets set HRIS_WEBHOOK_SECRET=...
//
// Providers differ in payload shape, so the parser below is deliberately
// forgiving about where the email lives and strict about the shared secret.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const SECRET = Deno.env.get('HRIS_WEBHOOK_SECRET');

/** Constant-time compare so the secret can't be probed by timing. */
function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function findEmail(payload: Record<string, unknown>): string | null {
  const direct =
    payload.email ??
    payload.work_email ??
    payload.workEmail ??
    (payload.worker as Record<string, unknown> | undefined)?.email ??
    (payload.employee as Record<string, unknown> | undefined)?.email ??
    (payload.data as Record<string, unknown> | undefined)?.email;
  if (typeof direct === 'string' && direct.includes('@')) return direct;

  // Last resort: any string in the payload that looks like an address.
  const seen = JSON.stringify(payload).match(/[\w.+-]+@[\w-]+\.[\w.]+/);
  return seen ? seen[0] : null;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);

  if (!SECRET) return json({ error: 'HRIS_WEBHOOK_SECRET not configured' }, 500);
  const provided = req.headers.get('x-rydlnk-secret') ?? '';
  if (!safeEqual(provided, SECRET)) return json({ error: 'bad secret' }, 401);

  const payload = await req.json().catch(() => null);
  if (!payload) return json({ error: 'invalid json' }, 400);

  const company_id = payload.company_id ?? payload.companyId;
  if (!company_id) return json({ error: 'company_id is required' }, 400);

  const email = findEmail(payload);
  if (!email) return json({ error: 'no email found in payload' }, 400);

  const event = String(payload.event ?? payload.type ?? 'terminated').toLowerCase();
  if (!event.includes('terminat') && !event.includes('offboard') && !event.includes('deactivat')) {
    // Not a termination — acknowledge so the provider stops retrying.
    return json({ ok: true, ignored: event });
  }

  const { data, error } = await admin.rpc('offboard_user', {
    p_company: company_id,
    p_email: email,
  });

  if (error) {
    console.error('offboard failed', error.message);
    return json({ error: error.message }, 500);
  }

  return json({ ok: true, email, result: data });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
