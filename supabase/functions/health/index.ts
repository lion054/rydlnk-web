// Private operational health endpoint. Requires HEALTH_CHECK_SECRET and returns
// 503 when financial reconciliation detects a critical condition.
//
// Deploy: supabase functions deploy health --no-verify-jwt
// Secrets: supabase secrets set HEALTH_CHECK_SECRET=...

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req) => {
  const expected = Deno.env.get('HEALTH_CHECK_SECRET');
  const supplied = req.headers.get('x-health-secret');
  if (!expected || supplied !== expected) return json({ error: 'unauthorized' }, 401);

  const started = Date.now();
  const { data, error } = await admin.rpc('financial_health_snapshot');
  if (error) return json({ status: 'critical', database: error.message }, 503);

  return json(
    { ...data, latency_ms: Date.now() - started },
    data?.status === 'critical' ? 503 : 200,
  );
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

