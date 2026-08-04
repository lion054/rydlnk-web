-- Rydlnk — 025: lock every backend-only function to service_role
--
-- Migration 017 wrote `revoke all on function … from public` and stopped there.
-- That is not enough on Supabase. `anon` and `authenticated` hold EXECUTE grants
-- of their own, handed out by the default privileges Supabase installs on the
-- public schema, and revoking PUBLIC does not touch a role-specific grant. The
-- functions stayed callable by anyone holding the publishable key — which ships
-- in the browser bundle by design.
--
-- Confirmed against production before writing this, using only the anon key:
--
--   generate_company_statements  → 200   (wrote invoices for every company)
--   finish_stripe_event          → 204   (marked a webhook event complete)
--   settle_topup                 → 204   (credited a float without payment)
--   recompute_trip_fares         → 204
--   benefit_headroom             → 200   (leaked policy headroom)
--
-- settle_topup is the sharpest of these: it credits a company float from a
-- pending float_topups row, so anyone could turn an unpaid top-up into live
-- credits. generate_company_statements is the widest: it rewrites statements
-- for *every* company, and its `on conflict do update` overwrites existing ones.
--
-- Migration 024 fixed this correctly for the three health functions. This one
-- does the same for the rest and becomes the single canonical list, so 016's and
-- 024's entries are repeated here deliberately — the statements are idempotent.
--
-- Scope check that produced the list: of 83 SECURITY DEFINER functions, 23 have
-- no internal caller check, so the grant is their only control. Of those, none
-- is reachable from the web or mobile clients except company_invite_preview,
-- which anon must keep — the invite landing page renders before sign-in.
-- Trigger functions are excluded: PostgREST does not expose a function returning
-- `trigger`, and their EXECUTE privilege is checked when the trigger is created
-- rather than each time it fires, so revoking would buy nothing and risks
-- disturbing signup.

do $$
declare
  -- Backend-only. Reached by the Stripe webhook, the scheduled jobs, and the
  -- edge functions — all of which authenticate as service_role.
  target text;
  targets text[] := array[
    -- Stripe webhook idempotency (017). A caller who can claim an event id
    -- makes the real webhook skip it: the payment lands, the credits never do.
    'claim_stripe_event',
    'finish_stripe_event',
    -- Money movement (014, 017).
    'settle_topup',
    'generate_company_statements',
    -- Scheduled jobs (015). Every one of these mutates across all companies.
    'run_entitlements',
    'expire_credits',
    'release_stale_holds',
    'roll_recurring_schedules',
    'offboard_user',
    -- Internal helpers. Called by other SECURITY DEFINER functions, which run
    -- as the function owner and are unaffected by these revokes.
    'recompute_trip_fares',
    'find_or_create_open_trip',
    'benefit_headroom',
    'trip_occupancy',
    -- Already correct in 016 and 024; restated so this list is complete.
    'fund_seat',
    'settle_seat',
    'financial_health_snapshot',
    'record_health_snapshot',
    'retry_stuck_stripe_events'
  ];
  sig text;
  found int;
begin
  foreach target in array targets loop
    found := 0;

    -- Resolved from pg_proc rather than written out by hand: several of these
    -- are overloaded across migrations (settle_seat and accept_company_invite
    -- were each redefined in 016), and a hand-written signature would silently
    -- miss the overload it did not name.
    for sig in
      select p.oid::regprocedure::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = target
        and p.prorettype <> 'pg_catalog.trigger'::regtype
    loop
      execute format('revoke all on function %s from public, anon, authenticated', sig);
      execute format('grant execute on function %s to service_role', sig);
      found := found + 1;
    end loop;

    if found = 0 then
      -- Not fatal: this list is deliberately a superset so it stays correct if
      -- a function is renamed or dropped later.
      raise notice '025: public.% not present, skipped', target;
    end if;
  end loop;
end $$;

-- ── Deliberately left callable ──────────────────────────────────────────────
--
-- public.company_invite_preview(text) stays executable by anon. The invite
-- landing page at /invite/[token] renders the company name and role before the
-- recipient has signed in, so anon is the intended audience. It is safe there:
-- 018 has it take a token, look up only the matching invite, and return nothing
-- when the token does not resolve — it discloses only what the token's holder
-- already possesses.

-- ── Fail closed for anything added later — VERIFIED INEFFECTIVE ─────────────
--
-- The statements below run without error but do not change the outcome. Checked
-- against production on 2026-07-30: a function created afterwards in this schema
-- still comes out executable by anon.
--
-- Measured by creating a throwaway function as `postgres` and reading its ACL:
--
--   {=X/postgres, postgres=X/postgres, service_role=X/postgres}
--    ^ empty grantee means PUBLIC, and every role inherits PUBLIC
--
-- pg_default_acl shows no anon/authenticated entry for the `postgres` grantor, so
-- this looks fixed when you inspect the defaults. It is not: the built-in
-- "EXECUTE TO PUBLIC" for functions survives, and adding an explicit
-- `revoke execute on functions from public` to the default privileges did not
-- remove it either. Supabase's own grant automation is the likely cause.
--
-- Consequence: there is NO automatic protection for a newly added SECURITY
-- DEFINER function. Both working controls are manual and both are mandatory:
--
--   1. Every migration adding a backend-only function must revoke it explicitly,
--      the way the pg_proc loop above does. 026 and 027 both follow this.
--   2. supabase/tests/grant_hardening.sql fails when one is missed, and is the
--      only thing that catches the omission. It has to run in CI.
--
-- Kept because they are harmless and correct in intent — if Supabase changes its
-- automation they would begin working. Do not rely on them.

-- Hardens the role executing this migration: CLI migrations and SQL Editor
-- queries both create application functions as this role.
alter default privileges in schema public
  revoke execute on functions from public, anon, authenticated;

-- Harden supabase_admin too where the environment permits it. On hosted
-- Supabase, insufficient_privilege is expected and must not roll back the
-- concrete revokes above. Existing functions are already covered by the
-- pg_proc loop earlier in this migration, regardless of their owner.
do $$
begin
  if current_user <> 'supabase_admin'
     and exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    begin
      alter default privileges for role supabase_admin in schema public
        revoke execute on functions from public, anon, authenticated;
    exception when insufficient_privilege then
      raise notice
        '025: cannot alter supabase_admin defaults from role %, skipped',
        current_user;
    end;
  end if;
end $$;

-- Existing client RPCs are unaffected — this changes nothing already granted.
-- Verify after applying with supabase/tests/grant_hardening.sql.
