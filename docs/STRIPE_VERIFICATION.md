# Stripe staging verification

Use Stripe test mode and a dedicated staging Supabase project. Never run this
check with a live publishable key.

## Company top-up

1. Configure `pk_test_…`, `sk_test_…` and the staging webhook secret.
2. Open `/portal/billing` as a finance-authorized company member.
3. Start a small top-up with Stripe's successful test card.
4. Confirm `float_topups.status` moves `pending → succeeded`.
5. Confirm exactly one matching `credit_ledger` top-up exists.
6. Resend the same Stripe webhook and confirm the balance does not change.
7. Test a declined card and confirm no ledger credit is created.
8. Test an asynchronous bank payment and confirm credits remain unavailable
   while the PaymentIntent is `processing`.

## Rider split payment

1. Allocate fewer credits than a test ride costs.
2. Book the ride and verify `seat_funding.source = 'split'`.
3. Run the weekly billing function for the test period.
4. Confirm Stripe charges only `personal_cents`, never the full seat price.

## Reconciliation

Run:

```sql
select public.financial_health_snapshot();
```

The result must be `healthy`. Then inspect `/ops/health` and verify all issue
counts are zero.

## Webhook events

The Stripe endpoint must subscribe to:

- `setup_intent.succeeded`
- `payment_intent.processing`
- `payment_intent.succeeded`
- `payment_intent.payment_failed`

Failed deliveries must remain visible in `stripe_webhook_events` and return HTTP
500 so Stripe retries them.

