// Creates a company invite using the caller's JWT and delivers it through
// Resend. If delivery fails, the raw link is returned so the portal can still
// offer a copyable fallback.
//
// Deploy: supabase functions deploy send-company-invite
// Secrets: supabase secrets set RESEND_API_KEY=re_... INVITE_FROM_EMAIL="Rydlnk <rides@your-domain.com>"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendEmail } from '../_shared/resend.ts';
import { companyInvite } from '../_shared/messages.ts';

// company_invites.expires_at defaults to now() + 14 days (migration 013). Stated
// in the email so the recipient knows the link has a life; keep the two in step.
const INVITE_EXPIRY_DAYS = 14;

const CORS = {
  'Access-Control-Allow-Origin': Deno.env.get('SITE_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json({ ok: true });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  const authorization = req.headers.get('Authorization');
  if (!authorization) return json({ error: 'missing authorization' }, 401);

  const client = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authorization } } },
  );

  const body = await req.json().catch(() => ({}));
  const companyId = String(body.company_id ?? '');
  const email = String(body.email ?? '').trim().toLowerCase();
  const role = String(body.role ?? 'viewer');
  const department = body.department ? String(body.department).trim() : null;
  const employeeNo = body.employee_no ? String(body.employee_no).trim() : null;
  if (!companyId || !/.+@.+\..+/.test(email)) return json({ error: 'company and valid email are required' }, 400);
  if (!['viewer', 'manager', 'finance', 'admin'].includes(role)) return json({ error: 'invalid company role' }, 400);

  const { data: token, error: inviteError } = await client.rpc('invite_to_company', {
    p_company: companyId,
    p_email: email,
    p_role: role,
    p_department: department,
    p_employee_no: employeeNo,
  });
  if (inviteError) return json({ error: inviteError.message }, 403);

  const site = (Deno.env.get('SITE_ORIGIN') ?? '').replace(/\/$/, '');
  if (!site) return json({ error: 'SITE_ORIGIN is not configured', token, delivered: false });
  const link = `${site}/invite/${token}`;

  const { data: company } = await client.from('companies').select('name').eq('id', companyId).single();
  const companyName = company?.name ?? 'Your employer';

  const message = companyInvite({
    companyName,
    recipientEmail: email,
    role,
    link,
    expiresInDays: INVITE_EXPIRY_DAYS,
  });

  const sent = await sendEmail({
    to: email,
    subject: message.subject,
    email: message,
    tags: { type: 'company_invite', company: companyId },
  });

  // The invite row already exists, so a delivery failure is recoverable: hand
  // the link back and let the portal offer it for copying. Returning an error
  // here would strand an invite that is perfectly valid.
  if (!sent.delivered) {
    return json({
      token,
      link,
      delivered: false,
      warning: sent.error ?? 'email delivery failed',
    });
  }

  return json({ token, link, delivered: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
