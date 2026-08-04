# Pre-launch review — 2026-07-30

Database and blocker review against the live project `zpduvchwzoxkzfjuqlww`
(`eu-west-1`), with the app self-hosted at `13.247.190.131` (`af-south-1`).

Everything below was measured, not inferred. Where a check was ineffective or a
result confounded, that is stated.

## Fixed during this review

| | Was | Now |
|---|---|---|
| Edge functions | none deployed | **12 deployed** |
| `charge-weekly` | **200 to an unauthenticated POST** — charged saved cards | gated on `CHARGE_WEEKLY_SECRET` |
| Schema drift | **10 functions missing** from production | all 94 present (migration 027) |
| `platform_audit_log` | **no trigger — mutable** | append-only trigger installed |
| Refunds | 3 functions missing, `admin-refund-topup` deployed | present, service_role only |
| `offboard_user` | missing, `hris-offboard` deployed | present |
| Migration ledger | **did not exist** — `db push` would replay all 27 | reconciled, 0 mismatched |
| `SITE_URL` | **`http://localhost:3000`** | `https://rydlnk.us` |
| Redirect allowlist | **empty** — every magic link fell back to localhost | 4 URLs allowlisted |
| pgtap | not installed | 1.3.3 |

### The two that would have hurt most

**`charge-weekly` was an unauthenticated money endpoint.** It had
`Deno.serve(async () => {` — no request parameter, so no auth check — and relied
on `verify_jwt = true`. A POST carrying only the publishable `apikey` that ships
in the browser bundle was accepted and returned 200. The function calls
`paymentIntents.create({ off_session: true, confirm: true })`, so it takes money
from riders' saved cards on call. My own deploy is what exposed it; it was 404
before. `verify-production.sh` now **fails** when a private function answers 200
to an unauthenticated call, so this class cannot pass as "deployed ✓" again.

**Ten functions defined in migrations were absent from production.** Tables from
the same migrations all existed, which points at 015 and 023 having been applied
by hand and failing part-way — both files wrap work in
`do $$ … exception when others then raise notice`, which swallows an error and
continues. With no migration ledger there was nothing to compare against.

The consequences were live: `run_entitlements` missing means **employees never
receive their monthly credits**, all three refund functions missing means
**refunds fail outright**, and `platform_audit_is_append_only` missing meant the
"immutable" audit log **was mutable**. Repaired by migration 027, which copies the
bodies verbatim from 015/023 rather than restating them.

## Verified sound

- **RLS**: enabled on every table in `public` except `spatial_ref_sys` (PostGIS
  reference data). Six tables have RLS and no policies — all are service_role-only
  with no browser grant, which is correct, not a lockout.
- **Write policies**: every `INSERT`/`UPDATE` policy is conditional. Nothing is
  `WITH CHECK (true)` for a browser role. Three that looked unconditional
  (`driver_documents`, `legal_acceptances`, `messages`) are all scoped to
  `auth.uid()` — my first query flagged them because `INSERT` policies use
  `WITH CHECK`, not `USING`, so `qual` is always null.
- **Privileged grants**: 18 backend-only signatures resolved, **0** executable by
  `anon` or `authenticated`, **0** missing `service_role`.
- **`credit_ledger`** append-only trigger present.
- **`company_invite_preview`** still reachable by anon, as `/invite/[token]`
  requires.
- **MFA** enrolment enabled.

## Open — decide before launch

### 1. No scheduled jobs run at all

`pg_cron` is **not installed** (available: 1.6.4). Migrations 015 and 017 guard
their `cron.schedule` calls with `if exists (select 1 from pg_extension …)`, so
they silently skipped. Four jobs have never run:

| Job | Consequence of it not running |
|---|---|
| `run_entitlements` | employees never receive monthly credits |
| `expire_credits` | credits never expire |
| `release_stale_holds` | seat holds accumulate forever |
| `generate_company_statements` | no monthly statements |

I did not install it. Enabling `pg_cron` immediately starts four jobs that move
credits, and `expire_credits` removes them — that is a business decision on live
data, not a repair. Either install it and schedule them, or drive the same four
functions from the existing GitHub Actions scheduler alongside `billing-notify`.

### 2. Migration 025's fail-closed protection does not work

Verified ineffective. A function created afterwards still comes out executable by
`anon`. Its ACL is `{=X/postgres, postgres=X/postgres, service_role=X/postgres}` —
the empty grantee is PUBLIC, which every role inherits. `pg_default_acl` shows no
anon entry for the `postgres` grantor, so it *looks* fixed when you inspect the
defaults; adding an explicit `revoke execute on functions from public` to the
default privileges did not remove it either.

So there is no automatic protection for a new SECURITY DEFINER function. Both
working controls are manual: an explicit revoke in every migration that adds one,
and `supabase/tests/grant_hardening.sql`, which is now in CI and is load-bearing
rather than belt-and-braces.

### 3. No point-in-time recovery

`pitr_enabled: false`, and the backups endpoint lists **0** logical backups.
`walg_enabled` is true, so WAL archiving exists, but recovery granularity is a
daily snapshot at best. For a system holding a credit ledger and Stripe payment
records that is thin — a bad migration at 14:00 loses the day. PITR is a paid
add-on; the go-live checklist already asks for a *tested* restore, which has not
happened.

### 4. Password policy is weak

`password_min_length: 6` and leaked-password protection (HIBP) **off**. Both are
one-line config changes. I left them alone because they are policy, not defects.

### 5. Database and app are on different continents

DB in `eu-west-1`, app server in `af-south-1`, target users in Utah. Measured
from the app server:

- cold connection: **~260ms** per query
- with keep-alive: **~50ms** per query (5 queries in 256ms total)

So Supabase's edge terminates locally and connection reuse absorbs most of the
cost. Real but not catastrophic, and worth knowing before adding chatty
server-side queries. For a US-focused product, both tiers in a US region would be
the natural end state.

### 6. Thirty unindexed foreign keys

At 92 rides this is invisible. It matters for join performance and for
`on delete cascade` once the tables grow — deleting a company walks every child
table without an index. Not a launch blocker; worth a migration before real
volume.

## Current data

```
auth users        12        credit_ledger      0
companies          4        float_topups       0
company_members    4        seat_funding      15
rides             92
```

`credit_ledger` is empty, so **no credits have ever moved** — consistent with
`run_entitlements` never having existed in the database.

## Still required to launch

Ordered by what blocks what.

1. **`RESEND_API_KEY`** — verify `rydlnk.us` in Resend, then push secrets. Without
   it no email sends at all: invites fall back to a copyable link.
2. **`SEND_EMAIL_HOOK_SECRET`** + enable the Send Email hook — until then auth
   mail is Supabase-branded and rate limited. `auth-email` returns 500 by design
   while the secret is unset. See `docs/NOTIFICATIONS.md`.
3. **`STRIPE_WEBHOOK_SECRET`** — add the deployed `stripe-webhook` URL as a Stripe
   endpoint, paste the `whsec_` back. Without it the webhook rejects every event
   and **top-ups never credit the float**.
4. **Decide on `pg_cron`** (item 1 above). The product does not function without
   entitlements running somewhere.
5. **PITR + a tested restore** (item 3).
6. **`E2E_COMPANY_EMAIL` / `E2E_COMPANY_PASSWORD`** — the 4 skipped Playwright
   tests are the ones covering the authenticated portal. That path has never been
   covered by a passing run.
7. **Rotate the access token** used for this review (expires 06 Aug 2026) and the
   Stripe secret key, both of which were pasted into a chat transcript.
