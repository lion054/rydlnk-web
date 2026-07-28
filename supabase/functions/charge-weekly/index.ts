// Weekly billing. Builds each user's bill from the previous Mon–Sun rides and
// charges their default card off-session via a Stripe PaymentIntent. The
// webhook flips the cycle to 'paid' / 'failed'.
//
// IMPORTANT — this bills the RIDER'S SHARE ONLY.
//   Since migration 013 a seat can be funded by an employer. `seat_funding`
//   splits every ride into company credits and personal cents; billing
//   `rides.price_cents` here would charge an employee for a trip their employer
//   already paid for. The rider's card is only ever charged
//   `seat_funding.personal_cents`, which is zero for a fully funded seat and
//   the over-cap remainder on a split one.
//
// Deploy:   supabase functions deploy charge-weekly
// Schedule: run every Monday 03:00 — via pg_cron (net.http_post) or an external
//           scheduler. See go-live checklist.

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

function ymd(d: Date): string {
  return d.toISOString().slice(0, 10);
}

// Previous week's Monday..Sunday.
function lastWeek(): { start: string; end: string } {
  const now = new Date();
  const day = now.getUTCDay(); // 0=Sun … 6=Sat
  const daysSinceMonday = (day + 6) % 7;
  const thisMonday = new Date(now);
  thisMonday.setUTCDate(now.getUTCDate() - daysSinceMonday);
  const start = new Date(thisMonday);
  start.setUTCDate(thisMonday.getUTCDate() - 7);
  const end = new Date(start);
  end.setUTCDate(start.getUTCDate() + 6);
  return { start: ymd(start), end: ymd(end) };
}

Deno.serve(async () => {
  const { start, end } = lastWeek();

  const { data: rides, error } = await admin
    .from('rides')
    .select('id, rider_id, price_cents')
    .gte('ride_date', start)
    .lte('ride_date', end)
    .neq('status', 'cancelled');

  if (error) return new Response(`query failed: ${error.message}`, { status: 500 });

  // What each seat actually costs the rider. A seat with no funding row (a
  // legacy ride, or one created before the trigger existed) falls back to the
  // full fare, because an unattributed seat is the rider's own.
  const rideIds = (rides ?? []).map((r) => r.id);
  const personal = new Map<string, number>();
  for (let i = 0; i < rideIds.length; i += 500) {
    const { data: funding } = await admin
      .from('seat_funding')
      .select('ride_id, personal_cents, status')
      .in('ride_id', rideIds.slice(i, i + 500));
    for (const f of funding ?? []) {
      // A cancelled seat is not billable at all.
      personal.set(f.ride_id, f.status === 'cancelled' ? 0 : (f.personal_cents ?? 0));
    }
  }

  // Aggregate per rider, on the personal share only.
  const totals = new Map<string, { amount: number; count: number }>();
  for (const r of rides ?? []) {
    const due = personal.has(r.id) ? personal.get(r.id)! : (r.price_cents ?? 0);
    if (due <= 0) continue;  // fully employer-funded — nothing to charge
    const t = totals.get(r.rider_id) ?? { amount: 0, count: 0 };
    t.amount += due;
    t.count += 1;
    totals.set(r.rider_id, t);
  }

  let charged = 0;
  for (const [userId, t] of totals) {
    if (t.amount <= 0) continue;

    const { data: cycle } = await admin
      .from('billing_cycles')
      .upsert(
        {
          user_id: userId,
          period_start: start,
          period_end: end,
          amount_cents: t.amount,
          ride_count: t.count,
          status: 'open',
        },
        { onConflict: 'user_id,period_start' },
      )
      .select()
      .single();

    if (!cycle || cycle.status === 'paid') continue;

    const { data: cust } = await admin
      .from('stripe_customers')
      .select('stripe_customer_id')
      .eq('user_id', userId)
      .maybeSingle();
    const { data: pm } = await admin
      .from('payment_methods')
      .select('stripe_payment_method_id')
      .eq('user_id', userId)
      .eq('is_default', true)
      .maybeSingle();

    if (!cust || !pm) continue; // no card on file — skip, dun later

    try {
      const pi = await stripe.paymentIntents.create({
        amount: t.amount,
        currency: CURRENCY,
        customer: cust.stripe_customer_id,
        payment_method: pm.stripe_payment_method_id,
        off_session: true,
        confirm: true,
        metadata: { user_id: userId, period_start: start },
      });
      await admin
        .from('billing_cycles')
        .update({ stripe_payment_intent_id: pi.id })
        .eq('id', cycle.id);
      charged += 1;
    } catch (e) {
      await admin
        .from('billing_cycles')
        .update({ status: 'failed' })
        .eq('id', cycle.id);
      console.error(`charge failed for ${userId}: ${e}`);
    }
  }

  return new Response(
    JSON.stringify({ period: { start, end }, charged, users: totals.size }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
