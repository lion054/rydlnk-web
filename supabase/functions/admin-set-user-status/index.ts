// Disables or re-enables a Supabase Auth user. Requires operations_admin.
// Deploy: supabase functions deploy admin-set-user-status

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const CORS = {
  'Access-Control-Allow-Origin': Deno.env.get('SITE_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json({ ok: true });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);
  const authorization = req.headers.get('Authorization');
  if (!authorization) return json({ error: 'missing authorization' }, 401);
  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authorization } } },
  );
  const { data: caller } = await admin.auth.getUser(authorization.replace('Bearer ', ''));
  const { data: allowed } = await userClient.rpc('is_platform_admin');
  if (!allowed || !caller.user) return json({ error: 'operations admin access required' }, 403);

  const { user_id, disabled, reason } = await req.json().catch(() => ({}));
  if (!user_id || !String(reason ?? '').trim()) return json({ error: 'user_id and reason are required' }, 400);
  if (user_id === caller.user.id && disabled) return json({ error: 'you cannot disable your own account' }, 409);

  const action = disabled ? 'user.disable' : 'user.enable';
  const { error: requestAuditError } = await admin.from('platform_audit_log').insert({
    actor_id: caller.user.id,
    action: `${action}_requested`,
    target_type: 'user',
    target_id: user_id,
    reason: String(reason).trim(),
  });
  if (requestAuditError) return json({ error: 'could not create audit record' }, 500);

  const { error } = await admin.auth.admin.updateUserById(user_id, {
    ban_duration: disabled ? '876000h' : 'none',
  });
  if (error) {
    await admin.from('platform_audit_log').insert({
      actor_id: caller.user.id, action: `${action}_failed`, target_type: 'user',
      target_id: user_id, reason: String(reason).trim(), detail: { error: error.message },
    });
    return json({ error: error.message }, 400);
  }
  const { error: auditError } = await admin.from('platform_audit_log').insert({
    actor_id: caller.user.id,
    action: `${action}_completed`,
    target_type: 'user',
    target_id: user_id,
    reason: String(reason).trim(),
  });
  if (auditError) return json({ error: auditError.message }, 500);
  return json({ ok: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
