// Stripe → Supabase webhook. Persists saved cards and updates billing status.
// This is the ONLY writer of payment_methods / billing status (service role).
//
// Deploy:  supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_... STRIPE_WEBHOOK_SECRET=whsec_...
// Then add the function URL as an endpoint in the Stripe dashboard.

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

Deno.serve(async (req) => {
  const signature = req.headers.get('stripe-signature');
  const body = await req.text();
  if (!signature) return new Response('missing signature', { status: 400 });

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      Deno.env.get('STRIPE_WEBHOOK_SECRET')!,
    );
  } catch (e) {
    return new Response(`bad signature: ${e}`, { status: 400 });
  }

  switch (event.type) {
    case 'setup_intent.succeeded': {
      const si = event.data.object as Stripe.SetupIntent;
      const pm = await stripe.paymentMethods.retrieve(
        si.payment_method as string,
      );
      const { data: cust } = await admin
        .from('stripe_customers')
        .select('user_id')
        .eq('stripe_customer_id', si.customer as string)
        .maybeSingle();

      if (cust) {
        // The user's first card becomes their default.
        const { count } = await admin
          .from('payment_methods')
          .select('*', { count: 'exact', head: true })
          .eq('user_id', cust.user_id);

        await admin.from('payment_methods').upsert(
          {
            user_id: cust.user_id,
            stripe_payment_method_id: pm.id,
            brand: pm.card?.brand,
            last4: pm.card?.last4,
            exp_month: pm.card?.exp_month,
            exp_year: pm.card?.exp_year,
            is_default: (count ?? 0) === 0,
          },
          { onConflict: 'user_id,stripe_payment_method_id' },
        );
      }
      break;
    }

    case 'payment_intent.succeeded': {
      const pi = event.data.object as Stripe.PaymentIntent;

      // Rider weekly bill.
      await admin
        .from('billing_cycles')
        .update({ status: 'paid', charged_at: new Date().toISOString() })
        .eq('stripe_payment_intent_id', pi.id);

      // Company float top-up. settle_topup() is idempotent and is the ONLY
      // thing that credits the float — so a balance can never appear before
      // the money behind it has actually settled.
      if (pi.metadata?.kind === 'float_topup') {
        const { error } = await admin.rpc('settle_topup', { p_stripe_pi: pi.id });
        if (error) console.error('settle_topup failed', error.message);
      }
      break;
    }

    case 'payment_intent.payment_failed': {
      const pi = event.data.object as Stripe.PaymentIntent;
      await admin
        .from('billing_cycles')
        .update({ status: 'failed' })
        .eq('stripe_payment_intent_id', pi.id);
      await admin
        .from('float_topups')
        .update({ status: 'failed' })
        .eq('stripe_payment_intent_id', pi.id);
      break;
    }

    // ACH settles asynchronously — a top-up can sit pending for days, so the
    // company needs to see that rather than wonder where the credits went.
    case 'payment_intent.processing': {
      const pi = event.data.object as Stripe.PaymentIntent;
      await admin
        .from('float_topups')
        .update({ status: 'pending' })
        .eq('stripe_payment_intent_id', pi.id);
      break;
    }
  }

  return new Response('ok', { status: 200 });
});
