-- Run with: supabase test db
--
-- Regression cover for the defect migration 025 closes: a SECURITY DEFINER
-- function whose only access control is its EXECUTE grant, left reachable by
-- anon or authenticated because the revoke named `public` and stopped there.
--
-- Written data-driven rather than as one assertion per function so that an
-- overload added later is covered the moment it exists — the hand-written
-- signature style in phase5_invariants.sql is what let settle_seat's second
-- definition go unchecked.

begin;
create extension if not exists pgtap;
select plan(11);

-- ── The backend-only surface ────────────────────────────────────────────────
-- Kept in sync with the `targets` array in 025. Anything here must be callable
-- by service_role alone.

create temporary table privileged_fn (name text primary key) on commit drop;
insert into privileged_fn (name) values
  ('claim_stripe_event'), ('finish_stripe_event'),
  ('settle_topup'), ('generate_company_statements'),
  ('run_entitlements'), ('expire_credits'), ('release_stale_holds'),
  ('roll_recurring_schedules'), ('offboard_user'),
  ('recompute_trip_fares'), ('find_or_create_open_trip'),
  ('benefit_headroom'), ('trip_occupancy'),
  ('fund_seat'), ('settle_seat'),
  ('financial_health_snapshot'), ('record_health_snapshot'),
  ('retry_stuck_stripe_events');

create temporary view privileged_sig as
  select p.oid::regprocedure::text as sig, p.proname
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join privileged_fn f on f.name = p.proname
  where n.nspname = 'public'
    and p.prorettype <> 'pg_catalog.trigger'::regtype;

-- ── The bug itself, in both directions ──────────────────────────────────────

select is(
  (select coalesce(string_agg(sig, ', ' order by sig), '')
   from privileged_sig where has_function_privilege('anon', sig, 'execute')),
  '',
  'no backend-only function is executable by anon'
);

select is(
  (select coalesce(string_agg(sig, ', ' order by sig), '')
   from privileged_sig where has_function_privilege('authenticated', sig, 'execute')),
  '',
  'no backend-only function is executable by authenticated'
);

select is(
  (select coalesce(string_agg(sig, ', ' order by sig), '')
   from privileged_sig where not has_function_privilege('service_role', sig, 'execute')),
  '',
  'every backend-only function stays executable by service_role'
);

-- Catches a rename or a dropped migration: an empty view would make the three
-- assertions above pass vacuously.
select cmp_ok(
  (select count(*)::int from privileged_sig), '>=', 18,
  'every function named in 025 resolved to at least one signature'
);

-- ── The specific endpoints proven exploitable against production ────────────
-- Named individually because these are the ones that were actually reachable,
-- and a failure here should say which door reopened.

select ok(not has_function_privilege('anon', 'public.settle_topup(text)', 'execute'),
  'anon cannot credit a company float without payment');
select ok(not has_function_privilege('anon', 'public.generate_company_statements(date,date,text)', 'execute'),
  'anon cannot rewrite every company statement');
select ok(not has_function_privilege('anon', 'public.finish_stripe_event(text,text)', 'execute'),
  'anon cannot mark a Stripe webhook event complete');
select ok(not has_function_privilege('anon', 'public.claim_stripe_event(text,text)', 'execute'),
  'anon cannot claim a Stripe event id and starve the webhook');

-- ── The one that must stay open ─────────────────────────────────────────────
-- /invite/[token] renders the company name before the recipient signs in, so
-- losing this grant breaks invite acceptance rather than securing anything.

select ok(has_function_privilege('anon', 'public.company_invite_preview(text)', 'execute'),
  'invite preview stays anonymous — the landing page renders before sign-in');

-- ── Future functions fail closed ────────────────────────────────────────────
-- This function is created by the same migration owner used in normal CLI
-- migrations. It receives only the current default privileges, so these two
-- assertions catch PUBLIC being accidentally left in those defaults.

create function public.__grant_hardening_probe()
returns int language sql as $$ select 1 $$;

select ok(not has_function_privilege('anon', 'public.__grant_hardening_probe()', 'execute'),
  'new functions are not executable by anon through default privileges');
select ok(not has_function_privilege('authenticated', 'public.__grant_hardening_probe()', 'execute'),
  'new functions are not executable by authenticated through default privileges');

select * from finish();
rollback;
