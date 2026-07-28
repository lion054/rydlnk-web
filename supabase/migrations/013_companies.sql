-- ════════════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 13: Companies
--
-- ONE script. Paste into Supabase → SQL Editor → Run. Safe to re-run.
-- Requires 001–012 to have been applied first.
--
-- What this adds
--   • Multi-admin company membership with roles (replaces companies.admin_id)
--   • Invite-only joining AND verified-domain auto-join
--   • Worksites, cost centers, corridors seeded from company geography
--   • An append-only credit ledger — balances are projections, never columns
--   • seat_funding: which payer owns each seat  ← the retrofit everything needs
--   • Policy caps + an approvals queue for anything over them
--   • IRS §132(f) pre-tax commuter benefit tracking, per employee per month
--   • Prepaid float top-ups and company invoices (Stripe references only)
--   • Per-seat tenant isolation enforced at the query layer, not in the UI
--   • An audit log of every privileged action
--
-- SECURITY NOTE — this closes a live hole.
--   `profiles.company_id` is client-writable today (profiles RLS allows a user
--   to update their own row), so any signed-in user can join any company by
--   setting that column. Harmless while companies hold no money; a way to spend
--   someone else's the moment they do. After this migration `company_members`
--   is authoritative and direct writes to profiles.company_id are blocked by
--   trigger — the column is kept only so the existing Flutter build keeps
--   working, and is now written *for* you when membership changes.
-- ════════════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- ════════════════════════════════════════════════════════════════════════════
-- 1. Enums
-- ════════════════════════════════════════════════════════════════════════════

do $$ begin
  create type company_role as enum ('owner','admin','finance','manager','viewer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type member_status as enum ('invited','active','suspended','removed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type invite_status as enum ('pending','accepted','revoked','expired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type join_mode as enum ('invite_only','verified_domain','both');
exception when duplicate_object then null; end $$;

-- Ledger movements. Every one of these names a source and a destination.
do $$ begin
  create type ledger_kind as enum (
    'topup',        -- external money  → company float
    'allocation',   -- company float   → employee wallet
    'consumption',  -- employee wallet → seat
    'hold',         -- employee wallet → seat (pending, released or settled)
    'release',      -- seat            → employee wallet (hold reversed)
    'rebate',       -- clearing        → company float (spare seat sold)
    'reclaim',      -- employee wallet → company float (leaver)
    'expiry',       -- employee wallet → company float (cycle end)
    'no_show',      -- employee wallet → seat (charged anyway)
    'refund',       -- seat            → employee wallet
    'adjustment'    -- manual correction, always with a reason
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type account_kind as enum ('external','company_float','employee_wallet','seat','clearing');
exception when duplicate_object then null; end $$;

do $$ begin
  create type funding_source as enum ('company','personal','split');
exception when duplicate_object then null; end $$;

do $$ begin
  create type seat_funding_status as enum ('held','settled','refunded','no_show','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type approval_status as enum ('pending','approved','declined','expired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type approval_reason as enum (
    'over_trip_cap','over_distance_cap','over_weekly_cap',
    'off_roster','outside_funded_days','outside_funded_hours','corridor_not_allowed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type invoice_status as enum ('draft','open','paid','void','uncollectible');
exception when duplicate_object then null; end $$;

do $$ begin
  create type topup_status as enum ('pending','succeeded','failed','refunded');
exception when duplicate_object then null; end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 2. Company profile
-- ════════════════════════════════════════════════════════════════════════════

alter table public.companies
  add column if not exists legal_name       text,
  add column if not exists dba              text,
  -- Needed to run the §132(f) pre-tax benefit properly.
  add column if not exists ein              text,
  add column if not exists industry         text,
  add column if not exists size_band        text,
  add column if not exists billing_email    text,
  add column if not exists phone            text,
  add column if not exists address_line1    text,
  add column if not exists address_line2    text,
  add column if not exists city             text,
  add column if not exists state            text default 'UT',
  add column if not exists postal_code      text,
  add column if not exists country          text default 'US',
  add column if not exists timezone         text default 'America/Denver',
  add column if not exists join_mode        join_mode not null default 'invite_only',
  add column if not exists onboarding_step  text default 'company',
  add column if not exists activated_at     timestamptz,
  add column if not exists suspended_at     timestamptz,
  add column if not exists updated_at       timestamptz not null default now();

-- ════════════════════════════════════════════════════════════════════════════
-- 3. Membership — the authority on who belongs to which company
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.company_members (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  role          company_role  not null default 'viewer',
  status        member_status not null default 'active',
  job_title     text,
  department    text,
  cost_center_id uuid,
  employee_no   text,
  invited_by    uuid references auth.users (id) on delete set null,
  joined_at     timestamptz not null default now(),
  removed_at    timestamptz,
  unique (company_id, user_id)
);

create index if not exists cm_company_idx on public.company_members (company_id) where status = 'active';
create index if not exists cm_user_idx    on public.company_members (user_id)    where status = 'active';

-- ── Membership helpers ──────────────────────────────────────────────────────
-- SECURITY DEFINER and STABLE so RLS policies can call them without recursing
-- back into company_members' own policies.

create or replace function public.is_company_member(p_company uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.company_members
    where company_id = p_company and user_id = auth.uid() and status = 'active'
  );
$$;

create or replace function public.has_company_role(p_company uuid, p_roles company_role[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.company_members
    where company_id = p_company and user_id = auth.uid()
      and status = 'active' and role = any(p_roles)
  );
$$;

/** Companies the caller belongs to. Used by policies on child tables. */
create or replace function public.my_company_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select company_id from public.company_members
  where user_id = auth.uid() and status = 'active';
$$;

/** Admin-or-better. The set that can change money, people and policy. */
create or replace function public.can_administer(p_company uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_company_role(p_company, array['owner','admin']::company_role[]);
$$;

create or replace function public.can_spend(p_company uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_company_role(p_company, array['owner','admin','finance']::company_role[]);
$$;

grant execute on function public.is_company_member(uuid)            to authenticated;
grant execute on function public.has_company_role(uuid, company_role[]) to authenticated;
grant execute on function public.my_company_ids()                   to authenticated;
grant execute on function public.can_administer(uuid)               to authenticated;
grant execute on function public.can_spend(uuid)                    to authenticated;

-- ── Keep profiles.company_id in sync, and block direct writes to it ──────────
-- The existing Flutter build reads profiles.company_id, so it stays populated —
-- but only ever as a mirror of company_members, never as an input.

create or replace function public.sync_profile_company()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform set_config('rydlnk.membership_write', 'on', true);

  if tg_op = 'DELETE' then
    update public.profiles
       set company_id = (select company_id from public.company_members
                         where user_id = old.user_id and status = 'active' limit 1)
     where id = old.user_id;
    perform set_config('rydlnk.membership_write', 'off', true);
    return old;
  end if;

  if new.status = 'active' then
    update public.profiles set company_id = new.company_id where id = new.user_id;
  else
    update public.profiles
       set company_id = (select company_id from public.company_members
                         where user_id = new.user_id and status = 'active' limit 1)
     where id = new.user_id;
  end if;

  perform set_config('rydlnk.membership_write', 'off', true);
  return new;
end $$;

drop trigger if exists company_members_sync_profile on public.company_members;
create trigger company_members_sync_profile
  after insert or update or delete on public.company_members
  for each row execute function public.sync_profile_company();

create or replace function public.guard_profile_company_id()
returns trigger language plpgsql as $$
begin
  if new.company_id is distinct from old.company_id
     and coalesce(current_setting('rydlnk.membership_write', true), 'off') <> 'on' then
    raise exception
      'company_id is managed by company_members — use accept_company_invite() or join_company_by_domain()'
      using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_company on public.profiles;
create trigger profiles_guard_company
  before update on public.profiles
  for each row execute function public.guard_profile_company_id();

-- Migrate anyone created by the old single-admin flow into membership.
insert into public.company_members (company_id, user_id, role, status)
select c.id, c.admin_id, 'owner', 'active'
from public.companies c
where c.admin_id is not null
on conflict (company_id, user_id) do nothing;

-- ════════════════════════════════════════════════════════════════════════════
-- 4. Domains (auto-join) and invites
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.company_domains (
  id                 uuid primary key default gen_random_uuid(),
  company_id         uuid not null references public.companies (id) on delete cascade,
  domain             text not null,
  -- Put this in DNS as a TXT record to prove ownership. Until verified_at is
  -- set, the domain grants nothing — otherwise anyone could claim any employer.
  verification_token text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  verified_at        timestamptz,
  verified_by        uuid references auth.users (id) on delete set null,
  created_at         timestamptz not null default now(),
  unique (domain)
);

create index if not exists cd_company_idx on public.company_domains (company_id);

create table if not exists public.company_invites (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies (id) on delete cascade,
  email        text not null,
  phone        text,
  role         company_role not null default 'viewer',
  department   text,
  cost_center_id uuid,
  employee_no  text,
  -- Only the hash is stored. The raw token goes out in the email/SMS once and
  -- is never recoverable from the database.
  token_hash   text not null unique,
  status       invite_status not null default 'pending',
  invited_by   uuid references auth.users (id) on delete set null,
  expires_at   timestamptz not null default now() + interval '14 days',
  accepted_at  timestamptz,
  accepted_by  uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now()
);

create index if not exists ci_company_idx on public.company_invites (company_id);
create index if not exists ci_email_idx    on public.company_invites (lower(email));

-- ════════════════════════════════════════════════════════════════════════════
-- 5. Worksites, cost centers, corridors
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.company_sites (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  name        text not null,
  address     text not null,
  lat         double precision,
  lng         double precision,
  geo         geography(Point, 4326),
  is_primary  boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists cs_company_idx on public.company_sites (company_id);
create index if not exists cs_geo_gix     on public.company_sites using gist (geo);

/** Keep the PostGIS point in step with the lat/lng the picker writes. */
create or replace function public.sync_site_geo()
returns trigger language plpgsql as $$
begin
  if new.lat is not null and new.lng is not null then
    new.geo := ST_SetSRID(ST_MakePoint(new.lng, new.lat), 4326)::geography;
  end if;
  return new;
end $$;

drop trigger if exists company_sites_geo on public.company_sites;
create trigger company_sites_geo
  before insert or update on public.company_sites
  for each row execute function public.sync_site_geo();

create table if not exists public.cost_centers (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  code        text not null,
  name        text not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (company_id, code)
);

do $$ begin
  alter table public.company_members
    add constraint company_members_cost_center_fk
    foreign key (cost_center_id) references public.cost_centers (id) on delete set null;
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.company_invites
    add constraint company_invites_cost_center_fk
    foreign key (cost_center_id) references public.cost_centers (id) on delete set null;
exception when duplicate_object then null; end $$;

/** A commuting corridor the company funds, anchored on one of its sites. */
create table if not exists public.company_corridors (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  site_id         uuid references public.company_sites (id) on delete cascade,
  name            text not null,
  destination     text not null,
  dest_lat        double precision,
  dest_lng        double precision,
  miles           numeric(6,1),
  seat_credits    int not null default 5,
  -- 'open' pools with anyone approved, 'exclusive' charters the whole vehicle
  -- and therefore bills every seat on it, occupied or not.
  pooling         text not null default 'approved'
                    check (pooling in ('open','approved','exclusive')),
  guaranteed_seats int not null default 0,
  seats_per_vehicle int not null default 8,
  active          boolean not null default true,
  created_at      timestamptz not null default now()
);

create index if not exists cc_company_idx on public.company_corridors (company_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 6. The credit ledger
--
-- Append-only, double-entry. A balance is a projection over entries — there is
-- deliberately no mutable balance column anywhere, because that is the thing
-- that silently drifts and cannot be reconciled at month end.
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.credit_ledger (
  id            bigint generated always as identity primary key,
  company_id    uuid not null references public.companies (id) on delete cascade,
  kind          ledger_kind not null,
  from_kind     account_kind not null,
  from_user_id  uuid references auth.users (id) on delete set null,
  from_ride_id  uuid references public.rides (id) on delete set null,
  to_kind       account_kind not null,
  to_user_id    uuid references auth.users (id) on delete set null,
  to_ride_id    uuid references public.rides (id) on delete set null,
  credits       int  not null check (credits > 0),
  ref           text not null,
  memo          text,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now()
);

create index if not exists cl_company_idx on public.credit_ledger (company_id, created_at desc);
create index if not exists cl_from_user_idx on public.credit_ledger (company_id, from_user_id);
create index if not exists cl_to_user_idx   on public.credit_ledger (company_id, to_user_id);
create index if not exists cl_ride_idx      on public.credit_ledger (to_ride_id);

/** Append-only. Nothing rewrites history; corrections are new entries. */
create or replace function public.ledger_is_append_only()
returns trigger language plpgsql as $$
begin
  raise exception 'credit_ledger is append-only — post a reversing entry instead'
    using errcode = '42501';
end $$;

drop trigger if exists ledger_no_update on public.credit_ledger;
create trigger ledger_no_update before update or delete on public.credit_ledger
  for each row execute function public.ledger_is_append_only();

-- ── Balance projections ─────────────────────────────────────────────────────

create or replace view public.company_float_balance
  with (security_invoker = true) as
select c.id as company_id,
       coalesce(sum(case when l.to_kind   = 'company_float' then l.credits else 0 end), 0)
     - coalesce(sum(case when l.from_kind = 'company_float' then l.credits else 0 end), 0)
       as credits
from public.companies c
left join public.credit_ledger l on l.company_id = c.id
group by c.id;

create or replace view public.employee_wallet_balance
  with (security_invoker = true) as
with moves as (
  select company_id, to_user_id   as user_id,  credits as delta
  from public.credit_ledger where to_kind   = 'employee_wallet' and to_user_id   is not null
  union all
  select company_id, from_user_id as user_id, -credits as delta
  from public.credit_ledger where from_kind = 'employee_wallet' and from_user_id is not null
)
select company_id, user_id, coalesce(sum(delta), 0)::int as credits
from moves
group by company_id, user_id;

grant select on public.company_float_balance, public.employee_wallet_balance
  to authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 7. seat_funding — who pays for this seat
--
-- The retrofit everything else depends on. A Trip belongs to Rydlnk; a Seat on
-- it belongs to a payer. Without this row a pooled trip cannot be invoiced,
-- cannot be isolated per tenant, and cannot substantiate a pre-tax benefit.
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.seat_funding (
  ride_id         uuid primary key references public.rides (id) on delete cascade,
  trip_id         uuid references public.trips (id) on delete set null,
  rider_id        uuid not null references auth.users (id) on delete cascade,
  company_id      uuid references public.companies (id) on delete set null,
  cost_center_id  uuid references public.cost_centers (id) on delete set null,
  corridor_id     uuid references public.company_corridors (id) on delete set null,
  source          funding_source not null default 'personal',
  company_credits int not null default 0 check (company_credits >= 0),
  personal_cents  int not null default 0 check (personal_cents  >= 0),
  -- Of company_credits, how much is inside the §132(f) monthly cap.
  pretax_credits  int not null default 0 check (pretax_credits  >= 0),
  status          seat_funding_status not null default 'held',
  settled_at      timestamptz,
  created_at      timestamptz not null default now(),
  check (pretax_credits <= company_credits)
);

create index if not exists sf_company_idx  on public.seat_funding (company_id, created_at desc);
create index if not exists sf_rider_idx    on public.seat_funding (rider_id);
create index if not exists sf_trip_idx     on public.seat_funding (trip_id);
create index if not exists sf_cc_idx       on public.seat_funding (cost_center_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 8. Policy, entitlements, approvals
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.company_policies (
  company_id          uuid primary key references public.companies (id) on delete cascade,
  per_trip_cap_credits    int,
  per_week_cap_credits    int,
  per_month_cap_credits   int,
  max_trip_miles          numeric(6,1),
  -- 0=Sun … 6=Sat. Empty means every day.
  funded_days             int[] not null default '{1,2,3,4,5}',
  funded_from             time,
  funded_to               time,
  allow_offroster         boolean not null default false,
  require_approval_over_cap boolean not null default true,
  -- Over-cap trips are split rather than refused: policy pays what it covers,
  -- the rider's own balance covers the rest, and they're told before confirming.
  split_tender_over_cap   boolean not null default true,
  unused_credits_policy   text not null default 'return_after_7_days'
                            check (unused_credits_policy in
                              ('return_after_7_days','carry_over','never_expire')),
  carry_over_cap_credits  int,
  night_safety_rule       boolean not null default true,
  visible_to_pooled_riders text not null default 'first_name'
                            check (visible_to_pooled_riders in
                              ('first_name','first_name_employer','seat_only')),
  updated_at              timestamptz not null default now()
);

create table if not exists public.entitlements (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies (id) on delete cascade,
  name          text not null,
  -- Who it applies to. Null department means everyone with a membership.
  department    text,
  cost_center_id uuid references public.cost_centers (id) on delete set null,
  credits_each  int not null check (credits_each >= 0),
  cadence       text not null default 'weekly'
                  check (cadence in ('once','weekly','biweekly','monthly','on_roster_publish')),
  run_at        time not null default '06:00',
  run_on_dow    int  not null default 1,
  active        boolean not null default true,
  last_run_at   timestamptz,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now()
);

create index if not exists ent_company_idx on public.entitlements (company_id) where active;

create table if not exists public.approvals (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies (id) on delete cascade,
  ride_id       uuid references public.rides (id) on delete cascade,
  rider_id      uuid not null references auth.users (id) on delete cascade,
  reason        approval_reason not null,
  detail        text,
  company_credits int not null default 0,
  personal_cents  int not null default 0,
  status        approval_status not null default 'pending',
  decided_by    uuid references auth.users (id) on delete set null,
  decided_at    timestamptz,
  expires_at    timestamptz not null default now() + interval '24 hours',
  created_at    timestamptz not null default now()
);

create index if not exists ap_company_pending_idx
  on public.approvals (company_id) where status = 'pending';

-- ════════════════════════════════════════════════════════════════════════════
-- 9. §132(f) pre-tax commuter benefit
--
-- Employer-funded commuting up to a monthly cap is excluded from the employee's
-- gross income and from payroll tax. This tracks the cap per employee per month
-- so allocation can be split pre-tax / post-tax, and so the amount can be
-- substantiated later. Confirm the current-year figure before relying on it.
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.benefit_settings (
  company_id        uuid primary key references public.companies (id) on delete cascade,
  enabled           boolean not null default true,
  monthly_cap_cents int not null default 34000,
  tax_year          int not null default extract(year from now())::int,
  payroll_system    text,
  updated_at        timestamptz not null default now()
);

create table if not exists public.benefit_periods (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  period_month    date not null,                      -- always the 1st
  pretax_credits  int  not null default 0,
  posttax_credits int  not null default 0,
  cap_cents       int  not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (company_id, user_id, period_month)
);

create index if not exists bp_company_month_idx on public.benefit_periods (company_id, period_month);

/** Pre-tax headroom left this month, in credits (1 credit = $1). */
create or replace function public.benefit_headroom(p_company uuid, p_user uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare v_cap int; v_used int;
begin
  select coalesce(monthly_cap_cents, 34000) / 100 into v_cap
  from public.benefit_settings where company_id = p_company;
  v_cap := coalesce(v_cap, 340);

  select coalesce(pretax_credits, 0) into v_used
  from public.benefit_periods
  where company_id = p_company and user_id = p_user
    and period_month = date_trunc('month', now())::date;

  return greatest(0, v_cap - coalesce(v_used, 0));
end $$;

grant execute on function public.benefit_headroom(uuid, uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 10. Money in and out — Stripe references only, never card data
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.company_stripe_customers (
  company_id         uuid primary key references public.companies (id) on delete cascade,
  stripe_customer_id text not null unique,
  default_pm_id      text,
  -- ACH matters here: nobody puts a five-figure monthly float on a card.
  ach_enabled        boolean not null default false,
  created_at         timestamptz not null default now()
);

create table if not exists public.float_topups (
  id                       uuid primary key default gen_random_uuid(),
  company_id               uuid not null references public.companies (id) on delete cascade,
  credits                  int  not null check (credits > 0),
  amount_cents             int  not null check (amount_cents > 0),
  status                   topup_status not null default 'pending',
  stripe_payment_intent_id text unique,
  auto                     boolean not null default false,
  requested_by             uuid references auth.users (id) on delete set null,
  created_at               timestamptz not null default now(),
  settled_at               timestamptz
);

create index if not exists ft_company_idx on public.float_topups (company_id, created_at desc);

/** Refill automatically when the float drops below a threshold. */
create table if not exists public.autotopup_rules (
  company_id      uuid primary key references public.companies (id) on delete cascade,
  enabled         boolean not null default false,
  threshold_credits int not null default 500,
  topup_credits     int not null default 2000,
  updated_at      timestamptz not null default now()
);

create table if not exists public.company_invoices (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid not null references public.companies (id) on delete cascade,
  number            text unique,
  period_start      date not null,
  period_end        date not null,
  seat_credits      int  not null default 0,
  platform_cents    int  not null default 0,
  rebate_credits    int  not null default 0,
  total_cents       int  not null default 0,
  status            invoice_status not null default 'draft',
  stripe_invoice_id text,
  due_at            date,
  issued_at         timestamptz,
  paid_at           timestamptz,
  created_at        timestamptz not null default now(),
  unique (company_id, period_start)
);

create table if not exists public.company_invoice_lines (
  id             uuid primary key default gen_random_uuid(),
  invoice_id     uuid not null references public.company_invoices (id) on delete cascade,
  cost_center_id uuid references public.cost_centers (id) on delete set null,
  description    text not null,
  seats          int  not null default 0,
  credits        int  not null default 0,
  amount_cents   int  not null default 0,
  -- A pooled run generates one line per employer, never a shared one.
  ride_id        uuid references public.rides (id) on delete set null
);

create index if not exists cil_invoice_idx on public.company_invoice_lines (invoice_id);

-- ════════════════════════════════════════════════════════════════════════════
-- 11. Audit log
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.company_audit_log (
  id          bigint generated always as identity primary key,
  company_id  uuid not null references public.companies (id) on delete cascade,
  actor_id    uuid references auth.users (id) on delete set null,
  action      text not null,
  target      text,
  detail      jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists cal_company_idx on public.company_audit_log (company_id, created_at desc);

create or replace function public.audit(p_company uuid, p_action text, p_target text, p_detail jsonb)
returns void language sql security definer set search_path = public as $$
  insert into public.company_audit_log (company_id, actor_id, action, target, detail)
  values (p_company, auth.uid(), p_action, p_target, p_detail);
$$;

-- ════════════════════════════════════════════════════════════════════════════
-- 12. Company creation, invites, domain join
-- ════════════════════════════════════════════════════════════════════════════

/** Create a company and make the caller its owner. */
create or replace function public.create_company(
  p_name text, p_legal_name text default null, p_industry text default null,
  p_size_band text default null, p_ein text default null,
  p_billing_email text default null, p_join_mode join_mode default 'invite_only'
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  insert into public.companies
    (name, legal_name, industry, size_band, ein, billing_email, admin_id, join_mode, onboarding_step)
  values
    (p_name, coalesce(p_legal_name, p_name), p_industry, p_size_band, p_ein,
     coalesce(p_billing_email, (select email from auth.users where id = v_uid)),
     v_uid, coalesce(p_join_mode, 'invite_only'), 'sites')
  returning id into v_id;

  insert into public.company_members (company_id, user_id, role, status)
  values (v_id, v_uid, 'owner', 'active')
  on conflict (company_id, user_id) do update set role = 'owner', status = 'active';

  update public.profiles set role = 'company_admin' where id = v_uid;

  insert into public.company_policies (company_id) values (v_id) on conflict do nothing;
  insert into public.benefit_settings (company_id) values (v_id) on conflict do nothing;
  insert into public.autotopup_rules  (company_id) values (v_id) on conflict do nothing;

  perform public.audit(v_id, 'company.created', v_id::text, jsonb_build_object('name', p_name));
  return v_id;
end $$;

/**
 * Invite someone. Returns the RAW token — the caller emails or texts it and it
 * is never stored or recoverable, only its hash.
 */
create or replace function public.invite_to_company(
  p_company uuid, p_email text, p_role company_role default 'viewer',
  p_department text default null, p_employee_no text default null
) returns text
language plpgsql security definer set search_path = public as $$
declare v_token text;
begin
  if not public.can_administer(p_company) then
    raise exception 'only an owner or admin can invite' using errcode = '42501';
  end if;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');

  insert into public.company_invites
    (company_id, email, role, department, employee_no, token_hash, invited_by)
  values
    (p_company, lower(trim(p_email)), p_role, p_department, p_employee_no,
     encode(sha256(v_token::bytea), 'hex'), auth.uid());

  perform public.audit(p_company, 'invite.sent', lower(trim(p_email)),
                       jsonb_build_object('role', p_role));
  return v_token;
end $$;

/** Redeem an invite. The caller becomes a member of that company. */
create or replace function public.accept_company_invite(p_token text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare inv public.company_invites; v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select * into inv from public.company_invites
  where token_hash = encode(sha256(p_token::bytea), 'hex')
  for update;

  if not found then raise exception 'invite not found'; end if;
  if inv.status <> 'pending' then raise exception 'invite already %', inv.status; end if;
  if inv.expires_at < now() then
    update public.company_invites set status = 'expired' where id = inv.id;
    raise exception 'invite expired';
  end if;

  insert into public.company_members
    (company_id, user_id, role, status, department, cost_center_id, employee_no, invited_by)
  values
    (inv.company_id, v_uid, inv.role, 'active', inv.department, inv.cost_center_id,
     inv.employee_no, inv.invited_by)
  on conflict (company_id, user_id)
    do update set status = 'active', role = excluded.role;

  update public.company_invites
     set status = 'accepted', accepted_at = now(), accepted_by = v_uid
   where id = inv.id;

  perform public.audit(inv.company_id, 'invite.accepted', v_uid::text, null);
  return inv.company_id;
end $$;

/**
 * Join by verified email domain.
 *
 * Only works when the company has proven it controls the domain (a DNS TXT
 * record matching verification_token) AND has opted into domain joining.
 * Without the verification step this would let anyone claim any employer.
 */
create or replace function public.join_company_by_domain()
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_email text; v_domain text; v_company uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select email into v_email from auth.users where id = v_uid;
  if v_email is null then raise exception 'no email on account'; end if;
  v_domain := lower(split_part(v_email, '@', 2));

  select d.company_id into v_company
  from public.company_domains d
  join public.companies c on c.id = d.company_id
  where d.domain = v_domain
    and d.verified_at is not null
    and c.join_mode in ('verified_domain','both')
    and c.suspended_at is null
  limit 1;

  if v_company is null then
    raise exception 'no company accepts self-join for domain %', v_domain;
  end if;

  insert into public.company_members (company_id, user_id, role, status)
  values (v_company, v_uid, 'viewer', 'active')
  on conflict (company_id, user_id) do update set status = 'active';

  perform public.audit(v_company, 'member.domain_join', v_uid::text,
                       jsonb_build_object('domain', v_domain));
  return v_company;
end $$;

/** Offboard. Freezes the wallet and returns the unspent balance to the float. */
create or replace function public.remove_company_member(p_company uuid, p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v_balance int;
begin
  if not public.can_administer(p_company) then
    raise exception 'only an owner or admin can remove members' using errcode = '42501';
  end if;

  select credits into v_balance from public.employee_wallet_balance
  where company_id = p_company and user_id = p_user;

  if coalesce(v_balance, 0) > 0 then
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_user_id, to_kind, credits, ref, created_by)
    values
      (p_company, 'reclaim', 'employee_wallet', p_user, 'company_float',
       v_balance, 'TERMINATION', auth.uid());
  end if;

  update public.company_members
     set status = 'removed', removed_at = now()
   where company_id = p_company and user_id = p_user;

  perform public.audit(p_company, 'member.removed', p_user::text,
                       jsonb_build_object('reclaimed', coalesce(v_balance, 0)));
end $$;

grant execute on function public.create_company(text,text,text,text,text,text,join_mode) to authenticated;
grant execute on function public.invite_to_company(uuid,text,company_role,text,text)      to authenticated;
grant execute on function public.accept_company_invite(text)                              to authenticated;
grant execute on function public.join_company_by_domain()                                 to authenticated;
grant execute on function public.remove_company_member(uuid,uuid)                          to authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 13. Allocation and spending
-- ════════════════════════════════════════════════════════════════════════════

/**
 * Move credits from the float into employee wallets.
 *
 * Splits each grant into pre-tax and post-tax against the §132(f) monthly cap
 * so payroll gets the right figure without a second reconciliation pass.
 */
create or replace function public.allocate_credits(
  p_company uuid, p_department text, p_credits_each int, p_ref text default 'MANUAL'
) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_float int; v_count int; v_total int; m record;
  v_pre int; v_post int; v_month date := date_trunc('month', now())::date;
begin
  if not public.can_spend(p_company) then
    raise exception 'only an owner, admin or finance user can allocate' using errcode = '42501';
  end if;
  if p_credits_each <= 0 then raise exception 'credits must be positive'; end if;

  select count(*) into v_count from public.company_members
  where company_id = p_company and status = 'active'
    and (p_department is null or department = p_department);

  if v_count = 0 then return 0; end if;
  v_total := v_count * p_credits_each;

  select credits into v_float from public.company_float_balance where company_id = p_company;
  if coalesce(v_float, 0) < v_total then
    raise exception 'float holds % credits, allocation needs %', coalesce(v_float, 0), v_total;
  end if;

  for m in
    select user_id from public.company_members
    where company_id = p_company and status = 'active'
      and (p_department is null or department = p_department)
  loop
    v_pre  := least(p_credits_each, public.benefit_headroom(p_company, m.user_id));
    v_post := p_credits_each - v_pre;

    insert into public.credit_ledger
      (company_id, kind, from_kind, to_kind, to_user_id, credits, ref, created_by)
    values
      (p_company, 'allocation', 'company_float', 'employee_wallet', m.user_id,
       p_credits_each, p_ref, auth.uid());

    insert into public.benefit_periods
      (company_id, user_id, period_month, pretax_credits, posttax_credits, cap_cents)
    values
      (p_company, m.user_id, v_month, v_pre, v_post,
       coalesce((select monthly_cap_cents from public.benefit_settings where company_id = p_company), 34000))
    on conflict (company_id, user_id, period_month) do update
      set pretax_credits  = public.benefit_periods.pretax_credits  + v_pre,
          posttax_credits = public.benefit_periods.posttax_credits + v_post,
          updated_at      = now();
  end loop;

  perform public.audit(p_company, 'credits.allocated', coalesce(p_department, 'everyone'),
                       jsonb_build_object('each', p_credits_each, 'people', v_count, 'total', v_total));
  return v_count;
end $$;

grant execute on function public.allocate_credits(uuid,text,int,text) to authenticated;

/**
 * Decide who pays for a seat, and how much.
 *
 * Applies the policy caps, splits over-cap trips between company and rider
 * rather than refusing them, and raises an approval when the policy says so.
 * Called when a ride is created for someone with an active membership.
 */
create or replace function public.fund_seat(p_ride uuid)
returns public.seat_funding
language plpgsql security definer set search_path = public as $$
declare
  r public.rides; pol public.company_policies;
  v_company uuid; v_member public.company_members;
  v_seat_credits int; v_cap int; v_company_pay int; v_personal int;
  v_wallet int; v_reason approval_reason; v_needs_approval boolean := false;
  v_row public.seat_funding; v_dow int;
begin
  select * into r from public.rides where id = p_ride;
  if not found then raise exception 'ride not found'; end if;

  select cm.* into v_member from public.company_members cm
  where cm.user_id = r.rider_id and cm.status = 'active' limit 1;

  -- No membership: the rider pays for themselves, as they do today.
  if v_member.company_id is null then
    insert into public.seat_funding (ride_id, trip_id, rider_id, source, personal_cents, status)
    values (p_ride, r.trip_id, r.rider_id, 'personal', coalesce(r.price_cents, 0), 'held')
    on conflict (ride_id) do update set personal_cents = excluded.personal_cents
    returning * into v_row;
    return v_row;
  end if;

  v_company := v_member.company_id;
  select * into pol from public.company_policies where company_id = v_company;
  v_seat_credits := ceil(coalesce(r.price_cents, 0) / 100.0)::int;
  v_company_pay  := v_seat_credits;
  v_personal     := 0;

  -- Per-trip credit cap.
  v_cap := pol.per_trip_cap_credits;
  if v_cap is not null and v_seat_credits > v_cap then
    v_company_pay := v_cap;
    v_personal    := (v_seat_credits - v_cap) * 100;
    v_reason      := 'over_trip_cap';
    v_needs_approval := coalesce(pol.require_approval_over_cap, true);
  end if;

  -- Funded days.
  v_dow := extract(dow from r.ride_date)::int;
  if pol.funded_days is not null and array_length(pol.funded_days, 1) is not null
     and array_position(pol.funded_days, v_dow) is null then
    v_reason := 'outside_funded_days';
    v_needs_approval := true;
  end if;

  -- Funded hours.
  if pol.funded_from is not null and pol.funded_to is not null and r.pickup_time is not null
     and (r.pickup_time < pol.funded_from or r.pickup_time > pol.funded_to) then
    v_reason := 'outside_funded_hours';
    v_needs_approval := true;
  end if;

  -- Wallet has to actually hold it; the shortfall falls to the rider.
  select credits into v_wallet from public.employee_wallet_balance
  where company_id = v_company and user_id = r.rider_id;
  if coalesce(v_wallet, 0) < v_company_pay then
    v_personal    := v_personal + (v_company_pay - coalesce(v_wallet, 0)) * 100;
    v_company_pay := coalesce(v_wallet, 0);
  end if;

  insert into public.seat_funding
    (ride_id, trip_id, rider_id, company_id, cost_center_id, source,
     company_credits, personal_cents, pretax_credits, status)
  values
    (p_ride, r.trip_id, r.rider_id, v_company, v_member.cost_center_id,
     case when v_company_pay > 0 and v_personal > 0 then 'split'
          when v_company_pay > 0 then 'company' else 'personal' end,
     v_company_pay, v_personal,
     least(v_company_pay, public.benefit_headroom(v_company, r.rider_id)),
     'held')
  on conflict (ride_id) do update
    set company_credits = excluded.company_credits,
        personal_cents  = excluded.personal_cents,
        source          = excluded.source
  returning * into v_row;

  -- Hold the company portion so two bookings can't spend the same credits.
  if v_company_pay > 0 then
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_user_id, to_kind, to_ride_id, credits, ref)
    values
      (v_company, 'hold', 'employee_wallet', r.rider_id, 'seat', p_ride, v_company_pay, 'HOLD');
  end if;

  if v_needs_approval and v_reason is not null then
    insert into public.approvals
      (company_id, ride_id, rider_id, reason, company_credits, personal_cents)
    values
      (v_company, p_ride, r.rider_id, v_reason, v_company_pay, v_personal);
  end if;

  return v_row;
end $$;

grant execute on function public.fund_seat(uuid) to authenticated;

/** Settle a held seat at boarding. This entry is the invoice line. */
create or replace function public.settle_seat(p_ride uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare sf public.seat_funding;
begin
  select * into sf from public.seat_funding where ride_id = p_ride;
  if not found or sf.status <> 'held' then return; end if;

  if sf.company_credits > 0 then
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_user_id, to_kind, to_ride_id, credits, ref)
    values
      (sf.company_id, 'consumption', 'employee_wallet', sf.rider_id, 'seat', p_ride,
       sf.company_credits, 'BOARDING-PIN');
  end if;

  update public.seat_funding
     set status = 'settled', settled_at = now()
   where ride_id = p_ride;
end $$;

grant execute on function public.settle_seat(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 14. Per-seat tenant isolation
--
-- A pooled trip has one id and several owners. A company asking about that trip
-- must get back its own seats and an occupancy count — never another employer's
-- names, departments or addresses. Enforced here, at the query layer, so no
-- interface bug can leak it.
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.company_trip_manifest(p_company uuid, p_trip uuid)
returns table (
  ride_id uuid, rider_name text, pickup text, dropoff text,
  pickup_time time, company_credits int, personal_cents int, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_company_member(p_company) then
    raise exception 'not a member of that company' using errcode = '42501';
  end if;

  return query
  select r.id,
         -- Names only for your own seats. Other employers' riders are a count.
         case when sf.company_id = p_company then p.full_name else null end,
         case when sf.company_id = p_company then r.pickup    else null end,
         case when sf.company_id = p_company then r.dropoff   else null end,
         r.pickup_time,
         case when sf.company_id = p_company then sf.company_credits else 0 end,
         case when sf.company_id = p_company then sf.personal_cents  else 0 end,
         (sf.company_id = p_company)
  from public.rides r
  join public.seat_funding sf on sf.ride_id = r.id
  left join public.profiles p on p.id = r.rider_id
  where r.trip_id = p_trip and r.status <> 'cancelled'
  order by (sf.company_id = p_company) desc, r.created_at;
end $$;

grant execute on function public.company_trip_manifest(uuid, uuid) to authenticated;

/** Occupancy only — safe to show for any pooled trip you have a seat on. */
create or replace function public.trip_occupancy(p_trip uuid)
returns table (capacity int, filled int, mine int)
language plpgsql stable security definer set search_path = public as $$
begin
  return query
  select t.capacity,
         (select count(*)::int from public.rides r
          where r.trip_id = t.id and r.status <> 'cancelled'),
         (select count(*)::int from public.rides r
          join public.seat_funding sf on sf.ride_id = r.id
          where r.trip_id = t.id and r.status <> 'cancelled'
            and sf.company_id in (select public.my_company_ids()))
  from public.trips t where t.id = p_trip;
end $$;

grant execute on function public.trip_occupancy(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 15. Dashboard views
-- ════════════════════════════════════════════════════════════════════════════

create or replace view public.company_spend_by_cost_center
  with (security_invoker = true) as
select sf.company_id,
       coalesce(cc.code, 'UNASSIGNED') as code,
       coalesce(cc.name, 'Unassigned') as name,
       count(*)::int                   as seats,
       sum(sf.company_credits)::int    as credits
from public.seat_funding sf
left join public.cost_centers cc on cc.id = sf.cost_center_id
where sf.company_id is not null and sf.status = 'settled'
group by sf.company_id, cc.code, cc.name;

create or replace view public.company_daily_spend
  with (security_invoker = true) as
select sf.company_id,
       date_trunc('day', sf.created_at)::date as day,
       count(*)::int                          as seats,
       sum(sf.company_credits)::int           as credits,
       sum(sf.pretax_credits)::int            as pretax_credits
from public.seat_funding sf
where sf.company_id is not null
group by sf.company_id, date_trunc('day', sf.created_at)::date;

grant select on public.company_spend_by_cost_center, public.company_daily_spend
  to authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 16. Row Level Security
-- ════════════════════════════════════════════════════════════════════════════

alter table public.company_members       enable row level security;
alter table public.company_domains       enable row level security;
alter table public.company_invites       enable row level security;
alter table public.company_sites         enable row level security;
alter table public.cost_centers          enable row level security;
alter table public.company_corridors     enable row level security;
alter table public.credit_ledger         enable row level security;
alter table public.seat_funding          enable row level security;
alter table public.company_policies      enable row level security;
alter table public.entitlements          enable row level security;
alter table public.approvals             enable row level security;
alter table public.benefit_settings      enable row level security;
alter table public.benefit_periods       enable row level security;
alter table public.company_stripe_customers enable row level security;
alter table public.float_topups          enable row level security;
alter table public.autotopup_rules       enable row level security;
alter table public.company_invoices      enable row level security;
alter table public.company_invoice_lines enable row level security;
alter table public.company_audit_log     enable row level security;

-- companies: members read; owners/admins write. Replaces the single-admin rule.
drop policy if exists "companies admin all"  on public.companies;
drop policy if exists "companies member read" on public.companies;
create policy "companies member read" on public.companies
  for select using (public.is_company_member(id));
drop policy if exists "companies admin write" on public.companies;
create policy "companies admin write" on public.companies
  for update using (public.can_administer(id)) with check (public.can_administer(id));

-- membership: you can always see your own row; admins see the whole roster.
drop policy if exists "members self read" on public.company_members;
create policy "members self read" on public.company_members
  for select using (user_id = auth.uid() or public.is_company_member(company_id));
drop policy if exists "members admin write" on public.company_members;
create policy "members admin write" on public.company_members
  for all using (public.can_administer(company_id)) with check (public.can_administer(company_id));

-- Read-for-members, write-for-admins across the company's configuration.
do $$
declare t text;
begin
  foreach t in array array[
    'company_domains','company_invites','company_sites','cost_centers',
    'company_corridors','company_policies','entitlements','benefit_settings',
    'autotopup_rules'
  ] loop
    execute format('drop policy if exists %I on public.%I', t || ' member read', t);
    execute format(
      'create policy %I on public.%I for select using (public.is_company_member(company_id))',
      t || ' member read', t);
    execute format('drop policy if exists %I on public.%I', t || ' admin write', t);
    execute format(
      'create policy %I on public.%I for all using (public.can_administer(company_id)) with check (public.can_administer(company_id))',
      t || ' admin write', t);
  end loop;
end $$;

-- Money: members read, nobody writes from the client. Every mutation goes
-- through a SECURITY DEFINER function or an Edge Function on the service role.
do $$
declare t text;
begin
  foreach t in array array[
    'credit_ledger','float_topups','company_invoices','company_stripe_customers',
    'company_audit_log','benefit_periods'
  ] loop
    execute format('drop policy if exists %I on public.%I', t || ' member read', t);
    execute format(
      'create policy %I on public.%I for select using (public.is_company_member(company_id))',
      t || ' member read', t);
  end loop;
end $$;

drop policy if exists "invoice lines member read" on public.company_invoice_lines;
create policy "invoice lines member read" on public.company_invoice_lines
  for select using (exists (
    select 1 from public.company_invoices i
    where i.id = invoice_id and public.is_company_member(i.company_id)));

-- approvals: members read, admins/managers decide.
drop policy if exists "approvals member read" on public.approvals;
create policy "approvals member read" on public.approvals
  for select using (public.is_company_member(company_id) or rider_id = auth.uid());
drop policy if exists "approvals admin write" on public.approvals;
create policy "approvals admin write" on public.approvals
  for update using (public.has_company_role(company_id, array['owner','admin','manager']::company_role[]));

-- seat_funding: the rider sees their own seat; the company sees seats it funded.
-- This is the per-seat isolation rule — a company can never select a row whose
-- company_id is not theirs, so a pooled trip can't leak another employer's staff.
drop policy if exists "seat funding rider read"   on public.seat_funding;
create policy "seat funding rider read" on public.seat_funding
  for select using (rider_id = auth.uid());
drop policy if exists "seat funding company read" on public.seat_funding;
create policy "seat funding company read" on public.seat_funding
  for select using (company_id is not null and public.is_company_member(company_id));

-- ════════════════════════════════════════════════════════════════════════════
-- 17. Hook seat funding into ride creation
-- ════════════════════════════════════════════════════════════════════════════

create or replace function public.autofund_new_ride()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.fund_seat(new.id);
  return new;
end $$;

drop trigger if exists rides_autofund on public.rides;
create trigger rides_autofund
  after insert on public.rides
  for each row execute function public.autofund_new_ride();

-- Backfill: every existing ride gets a funding row so nothing is unattributed.
do $$
declare r record;
begin
  for r in select id from public.rides
           where id not in (select ride_id from public.seat_funding)
  loop
    begin
      perform public.fund_seat(r.id);
    exception when others then
      null;  -- a bad legacy row must not abort the migration
    end;
  end loop;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- Done.
--
-- Next, outside SQL:
--   1. Edge function `charge-weekly` must skip the company-funded portion —
--      bill riders only seat_funding.personal_cents, never the whole fare.
--   2. New edge functions: company-topup (PaymentIntent → ledger 'topup'),
--      company-invoice, and domain-verify (DNS TXT lookup).
--   3. Point the Stripe webhook at float_topups and company_invoices too.
-- ════════════════════════════════════════════════════════════════════════════
