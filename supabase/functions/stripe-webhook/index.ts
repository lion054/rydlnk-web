// Stripe → Supabase webhook. Persists saved cards and updates billing status.
// This is the ONLY writer of payment_methods / billing status (service role).
//
// Deploy:  supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: supabase secrets set STRIPE_SECRET_KEY=sk_... STRIPE_WEBHOOK_SECRET=whsec_...
// Then add the function URL as an endpoint in the Stripe dashboard.

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { notifyCompany, siteOrigin } from '../_shared/notify.ts';
import { topupReceipt } from '../_shared/messages.ts';

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

  const { data: claimed, error: claimError } = await admin.rpc(
    'claim_stripe_event',
    { p_event_id: event.id, p_event_type: event.type },
  );
  if (claimError) {
    console.error('could not claim Stripe event', claimError.message);
    return new Response('event claim failed', { status: 500 });
  }
  if (!claimed) return new Response('already processed', { status: 200 });

  try {
    await processEvent(event);
    const { error } = await admin.rpc('finish_stripe_event', {
      p_event_id: event.id,
      p_error: null,
    });
    if (error) throw error;
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error(`Stripe event ${event.id} failed`, message);
    await admin.rpc('finish_stripe_event', {
      p_event_id: event.id,
      p_error: message.slice(0, 2000),
    });
    return new Response('processing failed', { status: 500 });
  }

  return new Response('ok', { status: 200 });
});

async function processEvent(event: Stripe.Event): Promise<void> {
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

        const { error } = await admin.from('payment_methods').upsert(
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
        if (error) throw error;
      }
      break;
    }

    case 'payment_intent.succeeded': {
      const pi = event.data.object as Stripe.PaymentIntent;

      // Rider weekly bill.
      const { error: billError } = await admin
        .from('billing_cycles')
        .update({ status: 'paid', charged_at: new Date().toISOString() })
        .eq('stripe_payment_intent_id', pi.id);
      if (billError) throw billError;

      // Company float top-up. settle_topup() is idempotent and is the ONLY
      // thing that credits the float — so a balance can never appear before
      // the money behind it has actually settled.
      if (pi.metadata?.kind === 'float_topup') {
        const { error } = await admin.rpc('settle_topup', { p_stripe_pi: pi.id });
        if (error) console.error('settle_topup failed', error.message);
        else await sendTopupReceipt(pi.id);
      }
      break;
    }

    case 'payment_intent.payment_failed': {
      const pi = event.data.object as Stripe.PaymentIntent;
      const { error: billError } = await admin
        .from('billing_cycles')
        .update({ status: 'failed' })
        .eq('stripe_payment_intent_id', pi.id);
      if (billError) throw billError;
      const { error: topupError } = await admin
        .from('float_topups')
        .update({ status: 'failed' })
        .eq('stripe_payment_intent_id', pi.id);
      if (topupError) throw topupError;
      break;
    }

    // ACH settles asynchronously — a top-up can sit pending for days, so the
    // company needs to see that rather than wonder where the credits went.
    case 'payment_intent.processing': {
      const pi = event.data.object as Stripe.PaymentIntent;
      const { error } = await admin
        .from('float_topups')
        .update({ status: 'pending' })
        .eq('stripe_payment_intent_id', pi.id);
      if (error) throw error;
      break;
    }
  }
}

/**
 * Emails the billing contacts a receipt for a settled top-up.
 *
 * Never throws. The money has already moved and the ledger is already correct
 * by the time this runs; letting a Resend outage bubble up would fail the
 * webhook, and Stripe would redeliver an event whose real work was done.
 * Double-sending is prevented by the claim in notifyCompany(), keyed on the
 * top-up id, so a redelivery for any other reason still sends one receipt.
 */
async function sendTopupReceipt(paymentIntentId: string): Promise<void> {
  try {
    const { data: topup, error } = await admin
      .from('float_topups')
      .select('id, company_id, credits, amount_cents, auto, settled_at, status')
      .eq('stripe_payment_intent_id', paymentIntentId)
      .maybeSingle();

    if (error || !topup) {
      console.error('receipt: top-up not found', paymentIntentId, error?.message);
      return;
    }
    // settle_topup() returns quietly when the row was already settled, so this
    // is reached on a redelivery too. Only a genuinely succeeded row gets mail.
    if (topup.status !== 'succeeded') return;

    const [{ data: company }, { data: balance }] = await Promise.all([
      admin.from('companies').select('name').eq('id', topup.company_id).maybeSingle(),
      admin.from('company_float_balance').select('credits').eq('company_id', topup.company_id).maybeSingle(),
    ]);

    const outcome = await notifyCompany(admin, {
      companyId: topup.company_id,
      kind: 'topup_receipt',
      ref: topup.id,
      message: topupReceipt({
        companyName: company?.name ?? 'Your company',
        credits: topup.credits,
        amountCents: topup.amount_cents,
        currency: Deno.env.get('BILLING_CURRENCY') ?? 'usd',
        reference: `TOPUP-${String(topup.id).slice(0, 8)}`,
        settledAt: topup.settled_at ?? new Date().toISOString(),
        floatAfter: balance?.credits ?? topup.credits,
        automatic: Boolean(topup.auto),
        portalUrl: `${siteOrigin()}/portal/credits`,
      }),
    });

    if (outcome.status === 'failed') {
      console.error('receipt: send failed', topup.id, outcome.reason);
    }
  } catch (e) {
    console.error('receipt: unexpected', e instanceof Error ? e.message : String(e));
  }
}
