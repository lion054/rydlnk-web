# Go-live checklist

## Blocking

- [ ] Migrations 001–026 applied to staging and production.
- [x] Migrations 025 and 026 applied to production; `npm run verify:production`
      reports every privileged function denied to anon. *(Verified 2026-07-29.)*
- [ ] **All edge functions deployed.** `npm run verify:production` shows none as
      "not deployed". Nothing works without this: `send-company-invite` is what
      adds a worker to a company, and it was absent at the 2026-07-29 audit.
- [ ] `supabase test db` passes, including `tests/grant_hardening.sql`.
- [ ] CI typecheck, build, `deno check` and Playwright checks pass.
- [ ] Stripe staging verification passes.
- [ ] Stripe live webhook endpoint shows successful deliveries.
- [ ] Sentry DSN and release source maps configured.
- [ ] Resend sending domain verified; invitation delivery tested.
- [ ] Branded auth templates pasted into Authentication → Emails in the hosted
      dashboard. A deploy does *not* push these — see `docs/EMAIL.md`.
- [ ] `billing-notify` reachable, and `BILLING_NOTIFY_URL` / `BILLING_NOTIFY_SECRET`
      set as repository secrets so the scheduled workflow can call it.
- [ ] First `operations_admin` account created with MFA.
- [ ] Second break-glass `operations_admin` created, tested and stored securely.
- [ ] Super-admin company suspension, user disable and test-mode refund verified.
- [ ] Private health endpoint connected to an uptime monitor.
- [ ] Supabase PITR/backup retention confirmed and a restore tested.
- [ ] Production legal terms, privacy notice and DPA approved by counsel.
- [ ] Placeholder phone, address and app-store URLs replaced.
- [ ] Launch currency, credit value and tax treatment signed off.

## Environment variables

### Vercel

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_SITE_URL`
- `NEXT_PUBLIC_SENTRY_DSN`
- `SENTRY_DSN`
- `SENTRY_AUTH_TOKEN` (build only)
- `SENTRY_ORG`
- `SENTRY_PROJECT`

### Supabase edge functions

- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `RESEND_API_KEY`
- `INVITE_FROM_EMAIL`
- `SITE_ORIGIN`
- `HEALTH_CHECK_SECRET`
- `HRIS_WEBHOOK_SECRET`
- `BILLING_NOTIFY_SECRET` — authenticates the scheduled `billing-notify` call
- `BILLING_CURRENCY` — optional, defaults to `usd`; must match what Stripe charges

### GitHub repository secrets

Used by `.github/workflows/billing-notify.yml`, which is what actually drives
the statement and low-float emails — there is no pg_cron path to an edge
function on this project.

- `BILLING_NOTIFY_URL`
- `BILLING_NOTIFY_SECRET` — the same value as the edge function secret above

## Launch window

- [ ] Named incident commander and rollback owner available.
- [ ] No unrelated database or Stripe changes during the window.
- [ ] Thirty-minute post-deploy monitoring completed.
- [ ] Test company registration, invitation, top-up, allocation, booking,
      settlement and statement generation recorded successfully.
- [ ] Invitation email received and rendered correctly in Gmail, Outlook and
      iOS Mail. Outlook is the one that matters — it renders through Word, so a
      broken button shows up there and nowhere else.
- [ ] Top-up receipt received exactly once. Replay the Stripe event from the
      dashboard and confirm a second one does *not* arrive — that is
      `notification_log` doing its job.
