// Fund a company's credit float.
//
// Creates (or reuses) a Stripe customer for the COMPANY — not the admin who
// happens to be clicking — and returns a PaymentIntent client secret. The
// credits are NOT posted here: `settle_topup()` runs from the webhook once
// Stripe confirms, so a float can never show a balance that no money backs.
//
// Deploy:  supabase functions deploy company-topup
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_...
//
// ACH note: card payments cap out well below a five-figure monthly float and
// cost interchange on every dollar. `us_bank_account` is enabled below so
// Stripe can offer ACH debit where the customer supports it.

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
});

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const CURRENCY = Deno.env.get('BILLING_CURRENCY') ?? 'usd';
const CORS = {
  'Access-Control-Allow-Origin': Deno.env.get('SITE_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  // Identify the caller from their JWT — never trust a user id in the body.
  const jwt = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!jwt) return json({ error: 'missing token' }, 401);

  const { data: userData } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (!user) return json({ error: 'invalid token' }, 401);

  const { company_id, credits } = await req.json().catch(() => ({}));
  if (!company_id || !Number.isFinite(credits) || credits <= 0) {
    return json({ error: 'company_id and a positive credits value are required' }, 400);
  }

  // Re-check the role in the database. The UI hides the button; this is what
  // actually stops someone calling the endpoint directly.
  const { data: member } = await admin
    .from('company_members')
    .select('role')
    .eq('company_id', company_id)
    .eq('user_id', user.id)
    .eq('status', 'active')
    .maybeSingle();

  if (!member || !['owner', 'admin', 'finance'].includes(member.role)) {
    return json({ error: 'only an owner, admin or finance user can fund the float' }, 403);
  }

  // One Stripe customer per company.
  let customerId: string | null = null;
  const { data: existing } = await admin
    .from('company_stripe_customers')
    .select('stripe_customer_id')
    .eq('company_id', company_id)
    .maybeSingle();

  if (existing) {
    customerId = existing.stripe_customer_id;
  } else {
    const { data: company } = await admin
      .from('companies')
      .select('name, billing_email, ein')
      .eq('id', company_id)
      .single();

    const customer = await stripe.customers.create({
      name: company?.name ?? 'Rydlnk company',
      email: company?.billing_email ?? user.email ?? undefined,
      metadata: { company_id, ein: company?.ein ?? '' },
    });
    customerId = customer.id;

    await admin.from('company_stripe_customers').insert({
      company_id,
      stripe_customer_id: customerId,
      ach_enabled: true,
    });
  }

  const amount = Math.round(credits) * 100;

  const intent = await stripe.paymentIntents.create({
    amount,
    currency: CURRENCY,
    customer: customerId!,
    payment_method_types: ['card', 'us_bank_account'],
    setup_future_usage: 'off_session',
    metadata: { company_id, credits: String(Math.round(credits)), kind: 'float_topup' },
  });

  // Record the intent as pending.
  //
  // Inserted directly rather than through topup_float(), because that function
  // authorises on auth.uid() and this runs on the service role where there is
  // no end user — the role check above is the equivalent gate. No ledger entry
  // is written here: the float is only credited once Stripe confirms, via
  // settle_topup() in the webhook.
  const { error } = await admin.from('float_topups').insert({
    company_id,
    credits: Math.round(credits),
    amount_cents: amount,
    status: 'pending',
    stripe_payment_intent_id: intent.id,
    requested_by: user.id,
  });
  if (error) console.error('float_topups insert failed', error.message);

  return json({ client_secret: intent.client_secret, payment_intent: intent.id });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}
