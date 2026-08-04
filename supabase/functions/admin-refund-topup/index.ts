// Full refund of a settled company top-up. Requires operations_admin.
// Stripe idempotency plus the database row lock make retries safe.
//
// Deploy: supabase functions deploy admin-refund-topup

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
});
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
  const { data: allowed } = await userClient.rpc('is_platform_admin');
  if (!allowed) return json({ error: 'operations admin access required' }, 403);

  const { topup_id, reason } = await req.json().catch(() => ({}));
  if (!topup_id || !String(reason ?? '').trim()) return json({ error: 'topup_id and reason are required' }, 400);
  const { data: topup, error } = await admin.from('float_topups')
    .select('id, status').eq('id', topup_id).single();
  if (error || !topup) return json({ error: 'top-up not found' }, 404);
  if (topup.status === 'refunded') return json({ ok: true, already_refunded: true });

  const { data: paymentIntentId, error: prepareError } = await userClient.rpc('admin_prepare_topup_refund', {
    p_topup: topup.id, p_reason: String(reason).trim(),
  });
  if (prepareError || !paymentIntentId) return json({ error: prepareError?.message ?? 'refund reservation failed' }, 409);

  let refund: Stripe.Refund;
  try {
    const stripeRefund = await stripe.refunds.create(
      { payment_intent: paymentIntentId, metadata: { topup_id } },
      { idempotencyKey: `topup-refund-${topup.id}` },
    );
    // Assign outside the catch boundary: once Stripe returns success the credit
    // reservation must never be released, even if database finalization retries.
    refund = stripeRefund;
  } catch (e) {
    await userClient.rpc('admin_cancel_topup_refund', {
      p_topup: topup.id, p_reason: e instanceof Error ? e.message : String(e),
    });
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
  const { error: finalizeError } = await userClient.rpc('admin_finalize_topup_refund', {
    p_topup: topup.id, p_stripe_refund: refund.id, p_reason: String(reason).trim(),
  });
  if (finalizeError) return json({ error: finalizeError.message, stripe_refund: refund.id }, 500);
  return json({ ok: true, stripe_refund: refund.id });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
