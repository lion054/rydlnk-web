# Rydlnk production runbook

## Service ownership

| Area | Primary signal | Immediate control |
| --- | --- | --- |
| Web application | Sentry error rate and Vercel health | Roll back Vercel deployment |
| Authentication/database | Supabase status and `/ops/health` | Disable affected portal mutation |
| Company funding | Stripe webhook delivery and health checks | Disable top-up UI / Stripe endpoint |
| Seat ledger | Negative-balance and settlement checks | Stop settlement worker |
| Dispatch | Unassigned trips on `/ops/dispatch` | Assign verified standby driver/vehicle |

Target recovery time is 60 minutes. Target recovery point is the latest completed
Supabase point-in-time recovery checkpoint. Confirm the actual PITR window in the
Supabase plan before launch.

## Deployment order

1. Take or verify a restorable database backup.
2. Apply migrations to staging in filename order.
3. Run `supabase test db`.
4. Deploy edge functions to staging.
5. Run Stripe test-mode verification from `STRIPE_VERIFICATION.md`.
6. Run `npm ci`, `npm run typecheck`, `npm run build`, and `npm run test:e2e`.
7. Apply the same migrations to production.
8. Deploy edge functions, then Vercel.
9. Verify `/`, `/signin`, `/portal`, `/ops/health`, and one zero-risk test invite.
10. Watch Sentry, Stripe deliveries and health checks for at least 30 minutes.

Never deploy the web top-up UI before the corresponding webhook and database
migration. That ordering can accept money without crediting the float.

## Rollback

Database migrations are forward-only. Do not edit or delete an applied migration
and do not run destructive down migrations during an incident.

- Web regression: use Vercel's previous production deployment.
- Edge regression: redeploy the last known-good function bundle.
- Database regression: create a new corrective migration.
- Data corruption: stop writers, record the incident timestamp, preserve logs,
  and restore to a new Supabase project before changing production.

## Financial incident response

When `/ops/health` is warning or critical:

1. Record the health payload and incident start time.
2. For negative balances or missing top-up ledger entries, disable company top-ups.
3. Compare the Stripe PaymentIntent with `float_topups` and `credit_ledger`.
4. Never update or delete `credit_ledger`; post an auditable reversing or adjustment entry.
5. Retry failed Stripe deliveries from the Stripe dashboard only after confirming
   the handler is idempotent and migration `017` is installed.
6. Re-run `select public.financial_health_snapshot();`.
7. Document every affected company, amount, correction reference and approver.

## Dispatch incident response

1. Filter the next departure window on `/ops/dispatch`.
2. Assign only verified drivers and active vehicles with sufficient capacity.
3. Contact riders using the approved operational messaging channel.
4. If a trip is cancelled, ensure held company credits are released.
5. Do not expose one employer's rider manifest to another employer.

## Secret rotation

Rotate immediately after suspected exposure:

- Supabase service-role key
- Stripe secret and webhook signing secrets
- Resend API key
- health-check secret
- Sentry auth token

After rotating Stripe's webhook secret, update the Supabase edge-function secret
before expiring the old endpoint secret. No service-role key belongs in Vercel or
in a `NEXT_PUBLIC_` variable.

## Backup verification

Monthly, restore the latest backup into an isolated project and verify:

- company and membership counts;
- the ledger append-only trigger;
- company float and employee wallet projections;
- settled-seat and statement reconciliation;
- authentication redirect configuration;
- private storage objects used for driver vetting.

An untested backup is not considered a backup.

