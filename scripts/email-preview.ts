// Renders every transactional email to disk.
//
//   npm run email:preview     → .email-preview/ , plus an index to browse them
//   npm run email:templates   → supabase/templates/*.html for Supabase auth
//
// Both modes render through the same functions the edge functions call, so a
// preview cannot drift from what actually gets sent, and the Supabase auth
// templates cannot drift from the rest of the mail.

import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  AUTH_SUBSTITUTIONS,
  AUTH_URL_SENTINEL,
  authConfirmSignup,
  authEmailChange,
  authMagicLink,
  authReauthentication,
  authRecovery,
  companyInvite,
  lowBalance,
  statementReady,
  topupReceipt,
} from '../supabase/functions/_shared/messages.ts';

// npm sets cwd to the package root for every script, and this is only ever
// invoked through one.
const ROOT = process.cwd();

// Sample data chosen to stress the layout rather than flatter it: a company
// name long enough to wrap, a four-figure credit count, a real-length token.
const SAMPLE_LINK =
  'https://rydlnk.us/invite/9f2c41ab7d0e4c8fa1b6539e02d7c4185ab3e9d1c7f04628';

const transactional = {
  'company-invite': companyInvite({
    companyName: 'Wasatch Manufacturing & Logistics',
    recipientEmail: 'dana.okoro@wasatch-mfg.com',
    role: 'viewer',
    link: SAMPLE_LINK,
    expiresInDays: 14,
  }),
  'company-invite-admin': companyInvite({
    companyName: 'Wasatch Manufacturing & Logistics',
    recipientEmail: 'finance@wasatch-mfg.com',
    role: 'admin',
    link: SAMPLE_LINK,
    expiresInDays: 14,
  }),
  'topup-receipt': topupReceipt({
    companyName: 'Wasatch Manufacturing & Logistics',
    credits: 2000,
    amountCents: 200000,
    currency: 'usd',
    reference: 'TOPUP-8f3a1c92',
    settledAt: '2026-07-29T14:21:00Z',
    floatAfter: 2480,
    automatic: false,
    portalUrl: 'https://rydlnk.us/portal/credits',
  }),
  'topup-receipt-automatic': topupReceipt({
    companyName: 'Wasatch Manufacturing & Logistics',
    credits: 2000,
    amountCents: 200000,
    currency: 'usd',
    reference: 'TOPUP-1b7e4d05',
    settledAt: '2026-07-29T03:02:00Z',
    floatAfter: 2140,
    automatic: true,
    portalUrl: 'https://rydlnk.us/portal/credits',
  }),
  'statement-ready': statementReady({
    companyName: 'Wasatch Manufacturing & Logistics',
    periodStart: '2026-06-01',
    periodEnd: '2026-06-30',
    seats: 1284,
    credits: 3852,
    number: 'RYD-202606-8F3A1C92',
    invoiceUrl: 'https://rydlnk.us/portal/billing/invoices/8f3a1c92',
  }),
  'low-balance': lowBalance({
    companyName: 'Wasatch Manufacturing & Logistics',
    credits: 320,
    threshold: 500,
    autoTopupEnabled: false,
    topupUrl: 'https://rydlnk.us/portal/billing',
  }),
  'low-balance-autotopup-failed': lowBalance({
    companyName: 'Wasatch Manufacturing & Logistics',
    credits: 180,
    threshold: 500,
    autoTopupEnabled: true,
    topupUrl: 'https://rydlnk.us/portal/billing',
  }),
  'low-balance-empty': lowBalance({
    companyName: 'Wasatch Manufacturing & Logistics',
    credits: 0,
    threshold: 500,
    autoTopupEnabled: true,
    topupUrl: 'https://rydlnk.us/portal/billing',
  }),
};

// Filenames are what Supabase's config.toml points at.
const authTemplates = {
  'magic-link': authMagicLink(AUTH_URL_SENTINEL),
  'confirmation': authConfirmSignup(AUTH_URL_SENTINEL),
  'recovery': authRecovery(AUTH_URL_SENTINEL),
  'email-change': authEmailChange(AUTH_URL_SENTINEL),
};

/* Carries a code rather than a URL, so it has no Go-template substitution and is
   preview-only — the hook always renders it with a real token. */
const codeTemplates = {
  'reauthentication': authReauthentication('418 902'),
};

function applyAuthSubstitutions(html: string): string {
  let out = html;
  for (const [from, to] of AUTH_SUBSTITUTIONS) out = out.split(from).join(to);
  return out;
}

// ── Supabase auth templates ─────────────────────────────────────────────────

function writeAuthTemplates(): void {
  const dir = join(ROOT, 'supabase', 'templates');
  mkdirSync(dir, { recursive: true });

  for (const [name, message] of Object.entries(authTemplates)) {
    const html = applyAuthSubstitutions(message.html);

    if (html.includes('rydlnk.invalid')) {
      throw new Error(
        `${name}: a sentinel URL survived substitution — the generated template would ship a dead link`,
      );
    }
    if (!html.includes('{{ .ConfirmationURL }}')) {
      throw new Error(`${name}: no {{ .ConfirmationURL }} in the output — the link would be missing`);
    }

    writeFileSync(join(dir, `${name}.html`), html, 'utf8');
    console.log(`  supabase/templates/${name}.html   ${message.subject}`);
  }
}

// ── Browsable previews ──────────────────────────────────────────────────────

function writePreviews(): void {
  const dir = join(ROOT, '.email-preview');
  mkdirSync(dir, { recursive: true });

  const all = [
    ...Object.entries(transactional).map(([n, m]) => [n, m, 'Transactional'] as const),
    ...Object.entries(authTemplates).map(
      ([n, m]) => [`auth-${n}`, { ...m, html: applyAuthSubstitutions(m.html) }, 'Supabase auth'] as const,
    ),
    ...Object.entries(codeTemplates).map(([n, m]) => [`auth-${n}`, m, 'Supabase auth'] as const),
  ];

  for (const [name, message] of all) {
    writeFileSync(join(dir, `${name}.html`), message.html, 'utf8');
    writeFileSync(join(dir, `${name}.txt`), `Subject: ${message.subject}\n\n${message.text}`, 'utf8');
  }

  const groups = ['Transactional', 'Supabase auth'] as const;
  const index = `<!doctype html>
<meta charset="utf-8"><title>Rydlnk email previews</title>
<style>
  :root { color-scheme: light dark; }
  body { margin:0; font:15px/1.6 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; background:#edf1ee; color:#07231a; }
  @media (prefers-color-scheme: dark) { body { background:#0b1d16; color:#e8f0eb; } aside { background:#12291f !important; border-color:#1e4c3a !important; } a { color:#8fb0a2 !important; } }
  .wrap { display:flex; height:100vh; }
  aside { width:280px; flex:none; overflow:auto; padding:20px; background:#fff; border-right:1px solid #dde5e0; }
  h1 { font-size:17px; letter-spacing:-.02em; margin:0 0 4px; }
  p.note { font-size:12px; color:#5c7268; margin:0 0 18px; }
  h2 { font-size:11px; text-transform:uppercase; letter-spacing:.08em; color:#5c7268; margin:20px 0 8px; }
  a { display:block; padding:7px 10px; border-radius:8px; color:#0e3a2b; text-decoration:none; font-size:13px; }
  a:hover { background:#edf1ee; }
  a.txt { font-size:11px; opacity:.65; padding:2px 10px 8px; }
  iframe { flex:1; border:0; background:#edf1ee; }
</style>
<div class="wrap">
  <aside>
    <h1>Email previews</h1>
    <p class="note">Rendered from the same functions the edge functions call.</p>
${groups
  .map(
    (group) => `    <h2>${group}</h2>\n` +
      all
        .filter(([, , g]) => g === group)
        .map(
          ([name]) =>
            `    <a href="${name}.html" target="preview">${name}</a>\n` +
            `    <a class="txt" href="${name}.txt" target="preview">plain text →</a>`,
        )
        .join('\n'),
  )
  .join('\n')}
  </aside>
  <iframe name="preview" src="${all[0][0]}.html"></iframe>
</div>`;

  writeFileSync(join(dir, 'index.html'), index, 'utf8');
  console.log(`\n  ${all.length} emails → .email-preview/index.html`);
}

const mode = process.argv[2] ?? 'preview';
if (mode === 'templates') {
  writeAuthTemplates();
} else {
  writePreviews();
  writeAuthTemplates();
}
