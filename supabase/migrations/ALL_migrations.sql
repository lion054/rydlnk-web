-- Rydlnk — all migrations 001–012, in order. Paste into SQL Editor → Run. Idempotent.

-- ########## 001_init.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 1 schema + Row Level Security
-- Paste this whole file into the Supabase dashboard → SQL Editor → Run.
-- Safe to re-run: everything is guarded with IF NOT EXISTS / CREATE OR REPLACE.
-- ════════════════════════════════════════════════════════════════════

-- ── Enums ────────────────────────────────────────────────────────────
do $$ begin
  create type user_role   as enum ('rider', 'driver', 'company_admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type ride_status as enum ('scheduled', 'matched', 'enroute',
                                   'arrived', 'started', 'completed',
                                   'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type schedule_status as enum ('active', 'paused', 'cancelled');
exception when duplicate_object then null; end $$;

-- ── companies ────────────────────────────────────────────────────────
create table if not exists public.companies (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  admin_id    uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

-- ── profiles (1:1 with auth.users) ───────────────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text,
  initials      text,
  phone         text,
  home_address  text,
  work_address  text,
  role          user_role not null default 'rider',
  company_id    uuid references public.companies (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ── drivers (extra data for users who drive) ─────────────────────────
create table if not exists public.drivers (
  id             uuid primary key references auth.users (id) on delete cascade,
  vehicle        text,
  license_plate  text,
  rating         numeric(2,1) default 5.0,
  is_available   boolean not null default false,
  verified       boolean not null default false,
  created_at     timestamptz not null default now()
);

-- ── schedules (a recurring booking) ──────────────────────────────────
create table if not exists public.schedules (
  id               uuid primary key default gen_random_uuid(),
  rider_id         uuid not null references public.profiles (id) on delete cascade,
  pickup           text not null,
  dropoff          text not null,
  pickup_after     time,
  arrive_by        time,
  days             int[] not null default '{}',   -- 0=Sun … 6=Sat
  start_date       date not null,
  end_date         date,
  return_ride      boolean not null default false,
  recurring        boolean not null default true,
  auto_reschedule  boolean not null default true,
  status           schedule_status not null default 'active',
  created_at       timestamptz not null default now()
);

-- ── rides (individual trips generated from a schedule) ───────────────
create table if not exists public.rides (
  id           uuid primary key default gen_random_uuid(),
  schedule_id  uuid references public.schedules (id) on delete set null,
  rider_id     uuid not null references public.profiles (id) on delete cascade,
  driver_id    uuid references public.drivers (id) on delete set null,
  pickup       text not null,
  dropoff      text not null,
  ride_date    date not null,
  pickup_time  time,
  status       ride_status not null default 'scheduled',
  price_cents  int,
  created_at   timestamptz not null default now()
);

create index if not exists rides_rider_idx    on public.rides (rider_id);
create index if not exists rides_driver_idx   on public.rides (driver_id);
create index if not exists schedules_rider_idx on public.schedules (rider_id);

-- ════════════════════════════════════════════════════════════════════
-- Auto-create a profile row whenever a new auth user signs up.
-- Reads full_name / phone from the sign-up metadata.
-- ════════════════════════════════════════════════════════════════════
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'phone'
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ════════════════════════════════════════════════════════════════════
-- Row Level Security — each user sees only their own data.
-- ════════════════════════════════════════════════════════════════════
alter table public.profiles  enable row level security;
alter table public.drivers   enable row level security;
alter table public.schedules enable row level security;
alter table public.rides     enable row level security;
alter table public.companies enable row level security;

-- profiles: owner can read + update their own row
drop policy if exists "profiles self read"   on public.profiles;
create policy "profiles self read"   on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- drivers: owner manages own driver record; anyone authenticated may read
drop policy if exists "drivers read"        on public.drivers;
create policy "drivers read"        on public.drivers
  for select using (auth.role() = 'authenticated');

drop policy if exists "drivers self write" on public.drivers;
create policy "drivers self write" on public.drivers
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- schedules: rider owns their schedules
drop policy if exists "schedules owner all" on public.schedules;
create policy "schedules owner all" on public.schedules
  for all using (auth.uid() = rider_id) with check (auth.uid() = rider_id);

-- rides: rider sees own rides; assigned driver may read + update status
drop policy if exists "rides rider all"     on public.rides;
create policy "rides rider all"     on public.rides
  for all using (auth.uid() = rider_id) with check (auth.uid() = rider_id);

drop policy if exists "rides driver read"   on public.rides;
create policy "rides driver read"   on public.rides
  for select using (auth.uid() = driver_id);

drop policy if exists "rides driver update" on public.rides;
create policy "rides driver update" on public.rides
  for update using (auth.uid() = driver_id);

-- companies: admin manages their company
drop policy if exists "companies admin all" on public.companies;
create policy "companies admin all" on public.companies
  for all using (auth.uid() = admin_id) with check (auth.uid() = admin_id);

-- ########## 002_schedules_rides.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 2: schedule → rides engine
-- Run in Supabase → SQL Editor AFTER 001_init.sql. Safe to re-run.
-- ════════════════════════════════════════════════════════════════════

-- Extra columns the booking flow needs.
alter table public.schedules
  add column if not exists title text,
  add column if not exists estimated_price_cents int not null default 0;

-- ────────────────────────────────────────────────────────────────────
-- Generate rides for a schedule across [p_from, p_to].
-- Idempotent: never inserts a duplicate (same schedule + date + direction).
-- Day convention: 0=Sun … 6=Sat, matching extract(dow …) and the client.
-- ────────────────────────────────────────────────────────────────────
create or replace function public.generate_rides_for_schedule(
  p_schedule_id uuid,
  p_from date,
  p_to date
) returns int
language plpgsql
as $$
declare
  s public.schedules;
  d date;
  n int := 0;
begin
  select * into s from public.schedules where id = p_schedule_id;
  if not found or s.status = 'cancelled' then
    return 0;
  end if;

  -- One-time booking: a single ride (plus its return) on the start date.
  if not s.recurring then
    insert into public.rides
      (schedule_id, rider_id, pickup, dropoff, ride_date, pickup_time, price_cents, status)
    select s.id, s.rider_id, s.pickup, s.dropoff, s.start_date, s.pickup_after,
           s.estimated_price_cents, 'scheduled'
    where not exists (
      select 1 from public.rides r
      where r.schedule_id = s.id and r.ride_date = s.start_date
        and r.pickup = s.pickup and r.dropoff = s.dropoff);
    n := n + 1;

    if s.return_ride then
      insert into public.rides
        (schedule_id, rider_id, pickup, dropoff, ride_date, pickup_time, price_cents, status)
      select s.id, s.rider_id, s.dropoff, s.pickup, s.start_date, s.arrive_by,
             s.estimated_price_cents, 'scheduled'
      where not exists (
        select 1 from public.rides r
        where r.schedule_id = s.id and r.ride_date = s.start_date
          and r.pickup = s.dropoff and r.dropoff = s.pickup);
      n := n + 1;
    end if;
    return n;
  end if;

  -- Recurring: walk each day in the window and match the weekday pattern.
  d := greatest(p_from, s.start_date);
  while d <= p_to and (s.end_date is null or d <= s.end_date) loop
    if array_position(s.days, extract(dow from d)::int) is not null then
      insert into public.rides
        (schedule_id, rider_id, pickup, dropoff, ride_date, pickup_time, price_cents, status)
      select s.id, s.rider_id, s.pickup, s.dropoff, d, s.pickup_after,
             s.estimated_price_cents, 'scheduled'
      where not exists (
        select 1 from public.rides r
        where r.schedule_id = s.id and r.ride_date = d
          and r.pickup = s.pickup and r.dropoff = s.dropoff);
      n := n + 1;

      if s.return_ride then
        insert into public.rides
          (schedule_id, rider_id, pickup, dropoff, ride_date, pickup_time, price_cents, status)
        select s.id, s.rider_id, s.dropoff, s.pickup, d, s.arrive_by,
               s.estimated_price_cents, 'scheduled'
        where not exists (
          select 1 from public.rides r
          where r.schedule_id = s.id and r.ride_date = d
            and r.pickup = s.dropoff and r.dropoff = s.pickup);
      end if;
    end if;
    d := d + 1;
  end loop;
  return n;
end $$;

-- ────────────────────────────────────────────────────────────────────
-- Create a schedule + generate its rides in one call (used by the app).
-- SECURITY INVOKER (default) so RLS enforces rider_id = auth.uid().
-- ────────────────────────────────────────────────────────────────────
create or replace function public.create_schedule(
  p_title text,
  p_pickup text,
  p_dropoff text,
  p_pickup_after time,
  p_arrive_by time,
  p_days int[],
  p_start date,
  p_end date,
  p_return_ride boolean,
  p_recurring boolean,
  p_auto_reschedule boolean,
  p_price_cents int
) returns uuid
language plpgsql
as $$
declare
  v_id uuid;
  v_uid uuid := auth.uid();
  v_horizon date;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.schedules (
    rider_id, title, pickup, dropoff, pickup_after, arrive_by,
    days, start_date, end_date, return_ride, recurring, auto_reschedule,
    estimated_price_cents, status)
  values (
    v_uid, p_title, p_pickup, p_dropoff, p_pickup_after, p_arrive_by,
    coalesce(p_days, '{}'), p_start, p_end, p_return_ride, p_recurring,
    coalesce(p_auto_reschedule, false), coalesce(p_price_cents, 0), 'active')
  returning id into v_id;

  -- Generate now, but never further than 3 weeks out for open-ended schedules
  -- (pg_cron keeps rolling them forward — see below).
  v_horizon := least(coalesce(p_end, p_start + 21), p_start + 21);
  perform public.generate_rides_for_schedule(v_id, p_start, v_horizon);

  return v_id;
end $$;

grant execute on function public.create_schedule(
  text, text, text, time, time, int[], date, date,
  boolean, boolean, boolean, int) to authenticated;

-- ════════════════════════════════════════════════════════════════════
-- Auto-reschedule rollover (keeps recurring rides ~3 weeks ahead).
-- Requires the pg_cron extension: Dashboard → Database → Extensions → pg_cron.
-- This block is guarded so the migration still succeeds if pg_cron is off;
-- enable it, then re-run just this section.
-- ════════════════════════════════════════════════════════════════════
create or replace function public.roll_recurring_schedules()
returns void
language plpgsql
security definer set search_path = public
as $$
declare s public.schedules;
begin
  for s in
    select * from public.schedules
    where status = 'active' and recurring and auto_reschedule
  loop
    perform public.generate_rides_for_schedule(
      s.id, current_date, (current_date + 21));
  end loop;
end $$;

do $$
begin
  perform 1 from pg_extension where extname = 'pg_cron';
  if found then
    if exists (select 1 from cron.job where jobname = 'rydlnk-roll-schedules') then
      perform cron.unschedule('rydlnk-roll-schedules');
    end if;
    perform cron.schedule(
      'rydlnk-roll-schedules',
      '0 2 * * *',                                   -- nightly at 02:00 UTC
      $cron$ select public.roll_recurring_schedules(); $cron$);
  else
    raise notice 'pg_cron not enabled — schedule rollover job not created. Enable pg_cron and re-run this section.';
  end if;
end $$;

-- ########## 003_payments.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 3: payments & weekly billing
-- Run in Supabase → SQL Editor AFTER 002. Safe to re-run.
--
-- Card DATA never lives here — Stripe holds it. We only store references
-- (Stripe customer id, payment-method id, brand/last4 for display).
-- ════════════════════════════════════════════════════════════════════

do $$ begin
  create type billing_status as enum ('open', 'paid', 'failed', 'void');
exception when duplicate_object then null; end $$;

-- One Stripe customer per user.
create table if not exists public.stripe_customers (
  user_id            uuid primary key references auth.users (id) on delete cascade,
  stripe_customer_id text not null unique,
  created_at         timestamptz not null default now()
);

-- Saved cards (display metadata + Stripe reference only).
create table if not exists public.payment_methods (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references auth.users (id) on delete cascade,
  stripe_payment_method_id text not null,
  brand                    text,          -- 'visa', 'mastercard', …
  last4                    text,
  exp_month                int,
  exp_year                 int,
  is_default               boolean not null default false,
  created_at               timestamptz not null default now(),
  unique (user_id, stripe_payment_method_id)
);

-- A weekly bill = the rides in a Mon–Sun window, charged once.
create table if not exists public.billing_cycles (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references auth.users (id) on delete cascade,
  period_start             date not null,
  period_end               date not null,
  amount_cents             int not null default 0,
  ride_count               int not null default 0,
  status                   billing_status not null default 'open',
  stripe_payment_intent_id text,
  created_at               timestamptz not null default now(),
  charged_at               timestamptz,
  unique (user_id, period_start)
);

create index if not exists pm_user_idx on public.payment_methods (user_id);
create index if not exists bc_user_idx on public.billing_cycles (user_id);

-- ── Row Level Security ───────────────────────────────────────────────
alter table public.stripe_customers enable row level security;
alter table public.payment_methods  enable row level security;
alter table public.billing_cycles   enable row level security;

-- Users may READ their own billing data. Writes happen only through Edge
-- Functions using the service role (which bypasses RLS) — never the client,
-- so there are deliberately no INSERT/UPDATE policies here.
drop policy if exists "customers self read" on public.stripe_customers;
create policy "customers self read" on public.stripe_customers
  for select using (auth.uid() = user_id);

drop policy if exists "pm self read"   on public.payment_methods;
create policy "pm self read"   on public.payment_methods
  for select using (auth.uid() = user_id);

-- Let users remove their own saved card (the Edge Function also detaches it
-- from Stripe; this keeps the UI responsive).
drop policy if exists "pm self delete" on public.payment_methods;
create policy "pm self delete" on public.payment_methods
  for delete using (auth.uid() = user_id);

drop policy if exists "billing self read" on public.billing_cycles;
create policy "billing self read" on public.billing_cycles
  for select using (auth.uid() = user_id);

-- ########## 004_drivers.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 4: driver side
-- Run in Supabase → SQL Editor AFTER 003. Safe to re-run.
--
-- Drivers claim unassigned rides from a shared pool. Because the ride pool is
-- otherwise rider-private (RLS), the pool read + claim go through
-- SECURITY DEFINER functions that check the caller is a driver.
-- ════════════════════════════════════════════════════════════════════

-- Promote the current user to driver and create/refresh their driver record.
create or replace function public.become_driver(
  p_vehicle text,
  p_plate text
) returns void
language plpgsql
security definer set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  update public.profiles set role = 'driver', updated_at = now()
  where id = v_uid;

  insert into public.drivers (id, vehicle, license_plate, is_available, verified)
  values (v_uid, p_vehicle, p_plate, false, false)
  on conflict (id) do update
    set vehicle = excluded.vehicle,
        license_plate = excluded.license_plate;
end $$;

grant execute on function public.become_driver(text, text) to authenticated;

-- The pool of unclaimed, upcoming rides — drivers only.
create or replace function public.available_rides()
returns setof public.rides
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (select 1 from public.drivers where id = auth.uid()) then
    raise exception 'not a driver';
  end if;

  return query
    select * from public.rides
    where driver_id is null
      and status = 'scheduled'
      and ride_date >= current_date
    order by ride_date asc, pickup_time asc nulls last
    limit 100;
end $$;

grant execute on function public.available_rides() to authenticated;

-- Atomically claim an unassigned ride. Fails if already taken (race-safe).
create or replace function public.claim_ride(p_ride_id uuid)
returns public.rides
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_ride public.rides;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.drivers where id = v_uid) then
    raise exception 'not a driver';
  end if;

  update public.rides
    set driver_id = v_uid, status = 'matched'
    where id = p_ride_id and driver_id is null and status = 'scheduled'
    returning * into v_ride;

  if not found then raise exception 'ride no longer available'; end if;
  return v_ride;
end $$;

grant execute on function public.claim_ride(uuid) to authenticated;

-- Note: an assigned driver updates their own ride's status directly — the
-- "rides driver update" RLS policy from 001 already permits that, so no extra
-- function is needed for enroute → arrived → started → completed.

-- ########## 005_shared_trips.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 5: shared trips (Lyft-Line pooling) + fare splitting
-- Run in Supabase → SQL Editor AFTER 004. Safe to re-run.
--
-- Model: a `trip` is one shared vehicle journey. Riders with a compatible
-- route/date/time are auto-pooled onto the same trip (up to capacity). Each
-- rider's fare = trip.base_fare_cents ÷ number of passengers, so the price
-- drops as more riders join. The driver claims a whole trip and earns the
-- full base fare.
-- ════════════════════════════════════════════════════════════════════

create table if not exists public.trips (
  id              uuid primary key default gen_random_uuid(),
  driver_id       uuid references public.drivers (id) on delete set null,
  pickup          text not null,
  dropoff         text not null,
  ride_date       date not null,
  pickup_time     time,
  capacity        int not null default 4,
  base_fare_cents int not null default 0,   -- full cost of the journey
  status          ride_status not null default 'scheduled',
  created_at      timestamptz not null default now()
);

create index if not exists trips_match_idx
  on public.trips (ride_date, pickup, dropoff, pickup_time, status);
create index if not exists trips_driver_idx on public.trips (driver_id);

-- A ride is now a passenger seat on a trip.
alter table public.rides
  add column if not exists trip_id uuid references public.trips (id) on delete set null;
create index if not exists rides_trip_idx on public.rides (trip_id);

-- ── RLS: riders see trips they're on; drivers see trips they own ─────
alter table public.trips enable row level security;

drop policy if exists "trips rider read" on public.trips;
create policy "trips rider read" on public.trips
  for select using (
    exists (select 1 from public.rides r
            where r.trip_id = trips.id and r.rider_id = auth.uid()));

drop policy if exists "trips driver read" on public.trips;
create policy "trips driver read" on public.trips
  for select using (driver_id = auth.uid());
-- (all writes to trips happen through the SECURITY DEFINER functions below)

-- ── Fare split: base ÷ live passenger count ─────────────────────────
create or replace function public.recompute_trip_fares(p_trip uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare v_base int; v_n int;
begin
  select base_fare_cents into v_base from public.trips where id = p_trip;
  select count(*) into v_n
    from public.rides where trip_id = p_trip and status <> 'cancelled';
  if coalesce(v_n, 0) = 0 then return; end if;
  update public.rides
    set price_cents = round(v_base::numeric / v_n)
    where trip_id = p_trip and status <> 'cancelled';
end $$;

-- ── Find a compatible open trip to pool into, else open a new one ────
create or replace function public.find_or_create_open_trip(
  p_pickup text, p_dropoff text, p_date date, p_time time,
  p_base_fare int, p_capacity int
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare v_trip uuid;
begin
  select t.id into v_trip
  from public.trips t
  where t.pickup = p_pickup
    and t.dropoff = p_dropoff
    and t.ride_date = p_date
    and t.pickup_time is not distinct from p_time
    and t.status = 'scheduled'
    and t.driver_id is null
    and (select count(*) from public.rides r
         where r.trip_id = t.id and r.status <> 'cancelled') < t.capacity
  order by t.created_at asc
  limit 1
  for update;

  if v_trip is null then
    insert into public.trips
      (pickup, dropoff, ride_date, pickup_time, capacity, base_fare_cents, status)
    values
      (p_pickup, p_dropoff, p_date, p_time,
       coalesce(p_capacity, 4), coalesce(p_base_fare, 0), 'scheduled')
    returning id into v_trip;
  end if;
  return v_trip;
end $$;

grant execute on function public.recompute_trip_fares(uuid) to authenticated;
grant execute on function public.find_or_create_open_trip(
  text, text, date, time, int, int) to authenticated;

-- ── Ride generation now pools each seat onto a trip ─────────────────
create or replace function public.generate_rides_for_schedule(
  p_schedule_id uuid, p_from date, p_to date
) returns int
language plpgsql
as $$
declare
  s public.schedules;
  d date;
  n int := 0;
  base int;
  cap int := 4;
  v_trip uuid;
begin
  select * into s from public.schedules where id = p_schedule_id;
  if not found or s.status = 'cancelled' then return 0; end if;
  base := coalesce(s.estimated_price_cents, 0);

  if not s.recurring then
    if not exists (select 1 from public.rides r
        where r.schedule_id = s.id and r.ride_date = s.start_date
          and r.pickup = s.pickup and r.dropoff = s.dropoff) then
      v_trip := public.find_or_create_open_trip(
        s.pickup, s.dropoff, s.start_date, s.pickup_after, base, cap);
      insert into public.rides (schedule_id, rider_id, pickup, dropoff,
        ride_date, pickup_time, price_cents, status, trip_id)
      values (s.id, s.rider_id, s.pickup, s.dropoff, s.start_date,
        s.pickup_after, base, 'scheduled', v_trip);
      perform public.recompute_trip_fares(v_trip);
      n := n + 1;
    end if;
    if s.return_ride and not exists (select 1 from public.rides r
        where r.schedule_id = s.id and r.ride_date = s.start_date
          and r.pickup = s.dropoff and r.dropoff = s.pickup) then
      v_trip := public.find_or_create_open_trip(
        s.dropoff, s.pickup, s.start_date, s.arrive_by, base, cap);
      insert into public.rides (schedule_id, rider_id, pickup, dropoff,
        ride_date, pickup_time, price_cents, status, trip_id)
      values (s.id, s.rider_id, s.dropoff, s.pickup, s.start_date,
        s.arrive_by, base, 'scheduled', v_trip);
      perform public.recompute_trip_fares(v_trip);
      n := n + 1;
    end if;
    return n;
  end if;

  d := greatest(p_from, s.start_date);
  while d <= p_to and (s.end_date is null or d <= s.end_date) loop
    if array_position(s.days, extract(dow from d)::int) is not null then
      if not exists (select 1 from public.rides r
          where r.schedule_id = s.id and r.ride_date = d
            and r.pickup = s.pickup and r.dropoff = s.dropoff) then
        v_trip := public.find_or_create_open_trip(
          s.pickup, s.dropoff, d, s.pickup_after, base, cap);
        insert into public.rides (schedule_id, rider_id, pickup, dropoff,
          ride_date, pickup_time, price_cents, status, trip_id)
        values (s.id, s.rider_id, s.pickup, s.dropoff, d,
          s.pickup_after, base, 'scheduled', v_trip);
        perform public.recompute_trip_fares(v_trip);
        n := n + 1;
      end if;
      if s.return_ride and not exists (select 1 from public.rides r
          where r.schedule_id = s.id and r.ride_date = d
            and r.pickup = s.dropoff and r.dropoff = s.pickup) then
        v_trip := public.find_or_create_open_trip(
          s.dropoff, s.pickup, d, s.arrive_by, base, cap);
        insert into public.rides (schedule_id, rider_id, pickup, dropoff,
          ride_date, pickup_time, price_cents, status, trip_id)
        values (s.id, s.rider_id, s.dropoff, s.pickup, d,
          s.arrive_by, base, 'scheduled', v_trip);
        perform public.recompute_trip_fares(v_trip);
        n := n + 1;
      end if;
    end if;
    d := d + 1;
  end loop;
  return n;
end $$;

-- ── Driver: the trip pool, claim, and status ────────────────────────
create or replace function public.available_trips()
returns table (
  id uuid, pickup text, dropoff text, ride_date date, pickup_time time,
  capacity int, base_fare_cents int, seats_taken int
)
language plpgsql security definer set search_path = public
as $$
#variable_conflict use_column
begin
  if not exists (select 1 from public.drivers where id = auth.uid()) then
    raise exception 'not a driver';
  end if;
  return query
    select t.id, t.pickup, t.dropoff, t.ride_date, t.pickup_time,
           t.capacity, t.base_fare_cents,
           (select count(*)::int from public.rides r
            where r.trip_id = t.id and r.status <> 'cancelled')
    from public.trips t
    where t.driver_id is null
      and t.status = 'scheduled'
      and t.ride_date >= current_date
    order by t.ride_date asc, t.pickup_time asc nulls last
    limit 100;
end $$;

grant execute on function public.available_trips() to authenticated;

create or replace function public.claim_trip(p_trip_id uuid)
returns public.trips
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_trip public.trips;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.drivers where id = v_uid) then
    raise exception 'not a driver';
  end if;

  update public.trips set driver_id = v_uid, status = 'matched'
    where id = p_trip_id and driver_id is null and status = 'scheduled'
    returning * into v_trip;
  if not found then raise exception 'trip no longer available'; end if;

  update public.rides set driver_id = v_uid, status = 'matched'
    where trip_id = p_trip_id and status = 'scheduled';
  return v_trip;
end $$;

grant execute on function public.claim_trip(uuid) to authenticated;

create or replace function public.set_trip_status(
  p_trip_id uuid, p_status ride_status
) returns void
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if not exists (select 1 from public.trips
                 where id = p_trip_id and driver_id = v_uid) then
    raise exception 'not your trip';
  end if;
  update public.trips set status = p_status where id = p_trip_id;
  update public.rides set status = p_status
    where trip_id = p_trip_id and status <> 'cancelled';
end $$;

grant execute on function public.set_trip_status(uuid, ride_status) to authenticated;

-- ########## 006_fix_available_trips.sql ##########

-- ════════════════════════════════════════════════════════════════════

-- Rydlnk — patch: fix "column reference id is ambiguous" in available_trips.
-- The RETURNS TABLE output names collide with trips columns; tell PL/pgSQL to
-- resolve ambiguous names to the column. Run in SQL Editor after 005.
-- ════════════════════════════════════════════════════════════════════
create or replace function public.available_trips()
returns table (
  id uuid, pickup text, dropoff text, ride_date date, pickup_time time,
  capacity int, base_fare_cents int, seats_taken int
)
language plpgsql security definer set search_path = public
as $$
#variable_conflict use_column
begin
  if not exists (select 1 from public.drivers where id = auth.uid()) then
    raise exception 'not a driver';
  end if;
  return query
    select t.id, t.pickup, t.dropoff, t.ride_date, t.pickup_time,
           t.capacity, t.base_fare_cents,
           (select count(*)::int from public.rides r
            where r.trip_id = t.id and r.status <> 'cancelled')
    from public.trips t
    where t.driver_id is null
      and t.status = 'scheduled'
      and t.ride_date >= current_date
    order by t.ride_date asc, t.pickup_time asc nulls last
    limit 100;
end $$;

grant execute on function public.available_trips() to authenticated;

-- ########## 007_messaging_tracking.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 6 + tracking: per-trip chat, live driver location,
-- push tokens. Run in SQL Editor after 006. Safe to re-run.
-- ════════════════════════════════════════════════════════════════════

-- ── Only surface trips that actually have a passenger to the driver pool.
create or replace function public.available_trips()
returns table (
  id uuid, pickup text, dropoff text, ride_date date, pickup_time time,
  capacity int, base_fare_cents int, seats_taken int
)
language plpgsql security definer set search_path = public
as $$
#variable_conflict use_column
begin
  if not exists (select 1 from public.drivers where id = auth.uid()) then
    raise exception 'not a driver';
  end if;
  return query
    select t.id, t.pickup, t.dropoff, t.ride_date, t.pickup_time,
           t.capacity, t.base_fare_cents,
           (select count(*)::int from public.rides r
            where r.trip_id = t.id and r.status <> 'cancelled')
    from public.trips t
    where t.driver_id is null
      and t.status = 'scheduled'
      and t.ride_date >= current_date
      and exists (select 1 from public.rides r
                  where r.trip_id = t.id and r.status <> 'cancelled')
    order by t.ride_date asc, t.pickup_time asc nulls last
    limit 100;
end $$;

grant execute on function public.available_trips() to authenticated;

-- One-off tidy: remove empty trips left by cancellations/deletions.
delete from public.trips t
where not exists (select 1 from public.rides r where r.trip_id = t.id);

-- ════════════════════════════════════════════════════════════════════
-- Per-trip group chat (rider(s) ↔ driver on one shared trip).
-- ════════════════════════════════════════════════════════════════════
create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid not null references public.trips (id) on delete cascade,
  sender_id  uuid not null references auth.users (id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists messages_trip_idx on public.messages (trip_id, created_at);

-- Is the current user a participant on this trip (a rider on it, or its driver)?
create or replace function public.is_trip_participant(p_trip uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.trips t where t.id = p_trip and t.driver_id = auth.uid())
      or exists (select 1 from public.rides r where r.trip_id = p_trip and r.rider_id = auth.uid());
$$;

alter table public.messages enable row level security;

drop policy if exists "messages read" on public.messages;
create policy "messages read" on public.messages
  for select using (public.is_trip_participant(trip_id));

drop policy if exists "messages send" on public.messages;
create policy "messages send" on public.messages
  for insert with check (sender_id = auth.uid() and public.is_trip_participant(trip_id));

-- ════════════════════════════════════════════════════════════════════
-- Live driver location — one current position per driver.
-- ════════════════════════════════════════════════════════════════════
create table if not exists public.driver_locations (
  driver_id  uuid primary key references public.drivers (id) on delete cascade,
  lat        double precision not null,
  lng        double precision not null,
  heading    double precision,
  updated_at timestamptz not null default now()
);

alter table public.driver_locations enable row level security;

drop policy if exists "loc driver upsert" on public.driver_locations;
create policy "loc driver upsert" on public.driver_locations
  for all using (driver_id = auth.uid()) with check (driver_id = auth.uid());

-- A rider may see the location of a driver on their active trip.
drop policy if exists "loc rider read" on public.driver_locations;
create policy "loc rider read" on public.driver_locations
  for select using (
    exists (
      select 1 from public.trips t
      join public.rides r on r.trip_id = t.id
      where t.driver_id = driver_locations.driver_id
        and r.rider_id = auth.uid()
        and t.status in ('matched', 'enroute', 'arrived', 'started')));

-- ════════════════════════════════════════════════════════════════════
-- Push notification tokens (FCM). One or more devices per user.
-- ════════════════════════════════════════════════════════════════════
create table if not exists public.device_tokens (
  user_id    uuid not null references auth.users (id) on delete cascade,
  token      text not null,
  platform   text,
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table public.device_tokens enable row level security;

drop policy if exists "tokens self" on public.device_tokens;
create policy "tokens self" on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── Add chat + location tables to the Realtime publication ──────────
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'driver_locations') then
    alter publication supabase_realtime add table public.driver_locations;
  end if;
exception when undefined_object then
  raise notice 'supabase_realtime publication not found — enable Realtime, then re-run this block.';
end $$;

-- ########## 008_vetting_cancel_ratings.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — MVP hardening: driver vetting gate, cancellation (+ fare
-- recompute), and ratings. Run in SQL Editor after 007. Safe to re-run.
-- ════════════════════════════════════════════════════════════════════

-- ── 1) Vetting gate: only VERIFIED drivers can claim trips ──────────
-- New drivers are verified=false until ops approves them (flip the flag in the
-- Dashboard, or via an admin tool). Going online is allowed; taking paid work
-- is not, until verified.
create or replace function public.claim_trip(p_trip_id uuid)
returns public.trips
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_trip public.trips;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.drivers where id = v_uid) then
    raise exception 'not a driver';
  end if;
  if not exists (select 1 from public.drivers where id = v_uid and verified) then
    raise exception 'account pending verification';
  end if;

  update public.trips set driver_id = v_uid, status = 'matched'
    where id = p_trip_id and driver_id is null and status = 'scheduled'
    returning * into v_trip;
  if not found then raise exception 'trip no longer available'; end if;

  update public.rides set driver_id = v_uid, status = 'matched'
    where trip_id = p_trip_id and status = 'scheduled';
  return v_trip;
end $$;

-- ── 2) Cancellation (rider) + live fare recompute ───────────────────
create or replace function public.cancel_ride(p_ride_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_trip uuid;
begin
  select trip_id into v_trip
    from public.rides where id = p_ride_id and rider_id = v_uid;
  if not found then raise exception 'ride not found'; end if;

  update public.rides set status = 'cancelled'
    where id = p_ride_id and rider_id = v_uid;
  if v_trip is not null then
    perform public.recompute_trip_fares(v_trip);
  end if;
end $$;

create or replace function public.cancel_schedule(p_schedule_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); r record;
begin
  if not exists (select 1 from public.schedules
                 where id = p_schedule_id and rider_id = v_uid) then
    raise exception 'schedule not found';
  end if;

  update public.schedules set status = 'cancelled'
    where id = p_schedule_id and rider_id = v_uid;

  for r in
    select id, trip_id from public.rides
    where schedule_id = p_schedule_id and rider_id = v_uid
      and status in ('scheduled', 'matched') and ride_date >= current_date
  loop
    update public.rides set status = 'cancelled' where id = r.id;
    if r.trip_id is not null then
      perform public.recompute_trip_fares(r.trip_id);
    end if;
  end loop;
end $$;

grant execute on function public.cancel_ride(uuid) to authenticated;
grant execute on function public.cancel_schedule(uuid) to authenticated;

-- ── 3) Ratings ──────────────────────────────────────────────────────
create table if not exists public.ratings (
  id         uuid primary key default gen_random_uuid(),
  ride_id    uuid references public.rides (id) on delete cascade,
  trip_id    uuid references public.trips (id) on delete set null,
  rider_id   uuid not null references auth.users (id) on delete cascade,
  driver_id  uuid not null references public.drivers (id) on delete cascade,
  stars      int not null check (stars between 1 and 5),
  comment    text,
  created_at timestamptz not null default now(),
  unique (ride_id, rider_id)
);
create index if not exists ratings_driver_idx on public.ratings (driver_id);

alter table public.ratings enable row level security;

drop policy if exists "ratings rider read" on public.ratings;
create policy "ratings rider read" on public.ratings
  for select using (rider_id = auth.uid());

drop policy if exists "ratings driver read" on public.ratings;
create policy "ratings driver read" on public.ratings
  for select using (driver_id = auth.uid());
-- inserts go through rate_ride() (SECURITY DEFINER) below.

-- Keep drivers.rating as the running average.
create or replace function public.update_driver_rating()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.drivers d
    set rating = (select round(avg(stars)::numeric, 1)
                  from public.ratings where driver_id = new.driver_id)
    where d.id = new.driver_id;
  return new;
end $$;

drop trigger if exists on_rating_change on public.ratings;
create trigger on_rating_change
  after insert or update on public.ratings
  for each row execute function public.update_driver_rating();

-- Rate a completed ride's driver (idempotent per ride).
create or replace function public.rate_ride(
  p_ride_id uuid, p_stars int, p_comment text
) returns void
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_ride public.rides;
begin
  select * into v_ride from public.rides
    where id = p_ride_id and rider_id = v_uid;
  if not found then raise exception 'ride not found'; end if;
  if v_ride.status <> 'completed' then raise exception 'ride not completed'; end if;
  if v_ride.driver_id is null then raise exception 'no driver to rate'; end if;
  if p_stars < 1 or p_stars > 5 then raise exception 'stars must be 1..5'; end if;

  insert into public.ratings (ride_id, trip_id, rider_id, driver_id, stars, comment)
  values (p_ride_id, v_ride.trip_id, v_uid, v_ride.driver_id, p_stars, p_comment)
  on conflict (ride_id, rider_id)
    do update set stars = excluded.stars, comment = excluded.comment;
end $$;

grant execute on function public.rate_ride(uuid, int, text) to authenticated;

-- ########## 009_ride_details.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — UX: expose the assigned driver's public identity + live pool size
-- to the riders on a trip (RLS-safe via SECURITY DEFINER + rider filter).
-- Run in SQL Editor after 008. Safe to re-run.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.my_rides_detailed(p_from date, p_to date)
returns table (
  ride_id        uuid,
  trip_id        uuid,
  pickup         text,
  dropoff        text,
  ride_date      date,
  pickup_time    time,
  status         ride_status,
  price_cents    int,
  driver_id      uuid,
  driver_name    text,
  driver_initials text,
  driver_rating  numeric,
  vehicle        text,
  license_plate  text,
  seats_taken    int
)
language plpgsql security definer set search_path = public
as $$
#variable_conflict use_column
begin
  return query
    select
      r.id, r.trip_id, r.pickup, r.dropoff, r.ride_date, r.pickup_time,
      r.status, r.price_cents,
      r.driver_id, p.full_name, p.initials, d.rating, d.vehicle, d.license_plate,
      (select count(*)::int from public.rides rr
       where rr.trip_id = r.trip_id and rr.status <> 'cancelled')
    from public.rides r
    left join public.drivers d  on d.id = r.driver_id
    left join public.profiles p on p.id = r.driver_id
    where r.rider_id = auth.uid()
      and r.status <> 'cancelled'
      and r.ride_date between p_from and p_to
    order by r.ride_date asc, r.pickup_time asc nulls last;
end $$;

grant execute on function public.my_rides_detailed(date, date) to authenticated;

-- ########## 010_corridor_pooling.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Corridor pooling (PostGIS). Riders whose pickup AND dropoff are
-- near a trip's corridor (within a radius) and within a small time window are
-- pooled onto one MULTI-STOP trip — no longer only exact-address matches.
-- Run in SQL Editor after 009. Safe to re-run.
--
-- Needs PostGIS: Dashboard → Database → Extensions → enable `postgis`
-- (the CREATE EXTENSION below does it if your role allows).
-- ════════════════════════════════════════════════════════════════════

create extension if not exists postgis;

-- Per-rider coordinates carried from the location picker.
alter table public.schedules
  add column if not exists pickup_lat double precision,
  add column if not exists pickup_lng double precision,
  add column if not exists dropoff_lat double precision,
  add column if not exists dropoff_lng double precision;

alter table public.rides
  add column if not exists pickup_lat double precision,
  add column if not exists pickup_lng double precision,
  add column if not exists dropoff_lat double precision,
  add column if not exists dropoff_lng double precision;

-- A trip's corridor endpoints (seeded from its first rider).
alter table public.trips
  add column if not exists origin geography(Point, 4326),
  add column if not exists dest   geography(Point, 4326);
create index if not exists trips_origin_gix on public.trips using gist (origin);
create index if not exists trips_dest_gix   on public.trips using gist (dest);

-- Old signatures are replaced by wider ones below.
drop function if exists public.find_or_create_open_trip(text, text, date, time, int, int);
drop function if exists public.create_schedule(
  text, text, text, time, time, int[], date, date, boolean, boolean, boolean, int);

-- ── Geo-aware matcher: pool into a nearby corridor, else open a trip ──
create or replace function public.find_or_create_open_trip(
  p_pickup text, p_dropoff text, p_date date, p_time time,
  p_base_fare int, p_capacity int,
  p_pickup_lat double precision, p_pickup_lng double precision,
  p_dropoff_lat double precision, p_dropoff_lng double precision
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_trip uuid;
  v_radius int := 1500;  -- corridor radius, metres
  v_o geography;
  v_d geography;
begin
  if p_pickup_lat is not null and p_dropoff_lat is not null then
    v_o := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
    v_d := ST_SetSRID(ST_MakePoint(p_dropoff_lng, p_dropoff_lat), 4326)::geography;
  end if;

  select t.id into v_trip
  from public.trips t
  where t.ride_date = p_date
    and t.status = 'scheduled'
    and t.driver_id is null
    and (select count(*) from public.rides r
         where r.trip_id = t.id and r.status <> 'cancelled') < t.capacity
    -- within ~15 min of the same departure time
    and (t.pickup_time is not distinct from p_time
         or (t.pickup_time is not null and p_time is not null
             and abs(extract(epoch from (t.pickup_time - p_time))) <= 900))
    -- same corridor (geo) OR exact-address fallback when coords are missing
    and (
      (v_o is not null and t.origin is not null and t.dest is not null
        and ST_DWithin(t.origin, v_o, v_radius)
        and ST_DWithin(t.dest, v_d, v_radius))
      or (v_o is null and t.pickup = p_pickup and t.dropoff = p_dropoff)
    )
  order by
    (case when v_o is not null and t.origin is not null
          then ST_Distance(t.origin, v_o) else 0 end) asc,
    t.created_at asc
  limit 1
  for update;

  if v_trip is null then
    insert into public.trips
      (pickup, dropoff, ride_date, pickup_time, capacity, base_fare_cents,
       status, origin, dest)
    values
      (p_pickup, p_dropoff, p_date, p_time, coalesce(p_capacity, 4),
       coalesce(p_base_fare, 0), 'scheduled', v_o, v_d)
    returning id into v_trip;
  end if;
  return v_trip;
end $$;

grant execute on function public.find_or_create_open_trip(
  text, text, date, time, int, int,
  double precision, double precision, double precision, double precision)
  to authenticated;

-- ── Ride generation now carries coordinates into rides + the matcher ──
create or replace function public.generate_rides_for_schedule(
  p_schedule_id uuid, p_from date, p_to date
) returns int
language plpgsql
as $$
declare
  s public.schedules;
  d date;
  n int := 0;
  base int;
  cap int := 4;
  v_trip uuid;
begin
  select * into s from public.schedules where id = p_schedule_id;
  if not found or s.status = 'cancelled' then return 0; end if;
  base := coalesce(s.estimated_price_cents, 0);

  if not s.recurring then
    if not exists (select 1 from public.rides r
        where r.schedule_id = s.id and r.ride_date = s.start_date
          and r.pickup = s.pickup and r.dropoff = s.dropoff) then
      v_trip := public.find_or_create_open_trip(s.pickup, s.dropoff, s.start_date,
        s.pickup_after, base, cap, s.pickup_lat, s.pickup_lng, s.dropoff_lat, s.dropoff_lng);
      insert into public.rides (schedule_id, rider_id, pickup, dropoff, ride_date,
        pickup_time, price_cents, status, trip_id,
        pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
      values (s.id, s.rider_id, s.pickup, s.dropoff, s.start_date, s.pickup_after,
        base, 'scheduled', v_trip,
        s.pickup_lat, s.pickup_lng, s.dropoff_lat, s.dropoff_lng);
      perform public.recompute_trip_fares(v_trip);
      n := n + 1;
    end if;
    if s.return_ride and not exists (select 1 from public.rides r
        where r.schedule_id = s.id and r.ride_date = s.start_date
          and r.pickup = s.dropoff and r.dropoff = s.pickup) then
      v_trip := public.find_or_create_open_trip(s.dropoff, s.pickup, s.start_date,
        s.arrive_by, base, cap, s.dropoff_lat, s.dropoff_lng, s.pickup_lat, s.pickup_lng);
      insert into public.rides (schedule_id, rider_id, pickup, dropoff, ride_date,
        pickup_time, price_cents, status, trip_id,
        pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
      values (s.id, s.rider_id, s.dropoff, s.pickup, s.start_date, s.arrive_by,
        base, 'scheduled', v_trip,
        s.dropoff_lat, s.dropoff_lng, s.pickup_lat, s.pickup_lng);
      perform public.recompute_trip_fares(v_trip);
      n := n + 1;
    end if;
    return n;
  end if;

  d := greatest(p_from, s.start_date);
  while d <= p_to and (s.end_date is null or d <= s.end_date) loop
    if array_position(s.days, extract(dow from d)::int) is not null then
      if not exists (select 1 from public.rides r
          where r.schedule_id = s.id and r.ride_date = d
            and r.pickup = s.pickup and r.dropoff = s.dropoff) then
        v_trip := public.find_or_create_open_trip(s.pickup, s.dropoff, d,
          s.pickup_after, base, cap, s.pickup_lat, s.pickup_lng, s.dropoff_lat, s.dropoff_lng);
        insert into public.rides (schedule_id, rider_id, pickup, dropoff, ride_date,
          pickup_time, price_cents, status, trip_id,
          pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        values (s.id, s.rider_id, s.pickup, s.dropoff, d, s.pickup_after,
          base, 'scheduled', v_trip,
          s.pickup_lat, s.pickup_lng, s.dropoff_lat, s.dropoff_lng);
        perform public.recompute_trip_fares(v_trip);
        n := n + 1;
      end if;
      if s.return_ride and not exists (select 1 from public.rides r
          where r.schedule_id = s.id and r.ride_date = d
            and r.pickup = s.dropoff and r.dropoff = s.pickup) then
        v_trip := public.find_or_create_open_trip(s.dropoff, s.pickup, d,
          s.arrive_by, base, cap, s.dropoff_lat, s.dropoff_lng, s.pickup_lat, s.pickup_lng);
        insert into public.rides (schedule_id, rider_id, pickup, dropoff, ride_date,
          pickup_time, price_cents, status, trip_id,
          pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        values (s.id, s.rider_id, s.dropoff, s.pickup, d, s.arrive_by,
          base, 'scheduled', v_trip,
          s.dropoff_lat, s.dropoff_lng, s.pickup_lat, s.pickup_lng);
        perform public.recompute_trip_fares(v_trip);
        n := n + 1;
      end if;
    end if;
    d := d + 1;
  end loop;
  return n;
end $$;

-- ── create_schedule now accepts coordinates ──
create or replace function public.create_schedule(
  p_title text, p_pickup text, p_dropoff text, p_pickup_after time, p_arrive_by time,
  p_days int[], p_start date, p_end date, p_return_ride boolean, p_recurring boolean,
  p_auto_reschedule boolean, p_price_cents int,
  p_pickup_lat double precision, p_pickup_lng double precision,
  p_dropoff_lat double precision, p_dropoff_lng double precision
) returns uuid
language plpgsql
as $$
declare v_id uuid; v_uid uuid := auth.uid(); v_horizon date;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  insert into public.schedules (
    rider_id, title, pickup, dropoff, pickup_after, arrive_by, days, start_date,
    end_date, return_ride, recurring, auto_reschedule, estimated_price_cents, status,
    pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
  values (
    v_uid, p_title, p_pickup, p_dropoff, p_pickup_after, p_arrive_by,
    coalesce(p_days, '{}'), p_start, p_end, p_return_ride, p_recurring,
    coalesce(p_auto_reschedule, false), coalesce(p_price_cents, 0), 'active',
    p_pickup_lat, p_pickup_lng, p_dropoff_lat, p_dropoff_lng)
  returning id into v_id;

  v_horizon := least(coalesce(p_end, p_start + 21), p_start + 21);
  perform public.generate_rides_for_schedule(v_id, p_start, v_horizon);
  return v_id;
end $$;

grant execute on function public.create_schedule(
  text, text, text, time, time, int[], date, date, boolean, boolean, boolean, int,
  double precision, double precision, double precision, double precision)
  to authenticated;

-- ── Driver manifest: the ordered pickup stops on a trip ──
create or replace function public.trip_stops(p_trip_id uuid)
returns table (
  ride_id uuid, pickup text, dropoff text,
  pickup_lat double precision, pickup_lng double precision, rider_name text
)
language plpgsql security definer set search_path = public
as $$
begin
  if not exists (select 1 from public.trips
                 where id = p_trip_id and driver_id = auth.uid()) then
    raise exception 'not your trip';
  end if;
  return query
    select r.id, r.pickup, r.dropoff, r.pickup_lat, r.pickup_lng, p.full_name
    from public.rides r
    left join public.profiles p on p.id = r.rider_id
    where r.trip_id = p_trip_id and r.status <> 'cancelled'
    order by r.created_at asc;
end $$;

grant execute on function public.trip_stops(uuid) to authenticated;

-- ########## 011_vetting_legal.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Driver vetting (document capture + review workflow) and legal
-- consent capture. Run in SQL Editor after 010. Safe to re-run.
--
-- What this does NOT do (and cannot): buy insurance, run background checks, or
-- make the legal drafts binding. It provides the SYSTEM to collect, record and
-- enforce those — you still procure the policy/vendor/counsel.
-- ════════════════════════════════════════════════════════════════════

-- ── Enums ───────────────────────────────────────────────────────────
do $$ begin
  create type doc_type as enum
    ('national_id','drivers_license','vehicle_registration','insurance','profile_photo');
exception when duplicate_object then null; end $$;

do $$ begin
  create type doc_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

-- ── Driver verification state ───────────────────────────────────────
alter table public.drivers
  add column if not exists verification_status text not null default 'unverified',
      -- unverified → pending → approved | rejected
  add column if not exists insurance_expiry date;

-- ── Uploaded documents (files live in the private storage bucket) ────
create table if not exists public.driver_documents (
  id           uuid primary key default gen_random_uuid(),
  driver_id    uuid not null references public.drivers (id) on delete cascade,
  doc_type     doc_type not null,
  storage_path text not null,
  status       doc_status not null default 'pending',
  expiry_date  date,
  note         text,                       -- reviewer note on rejection
  created_at   timestamptz not null default now(),
  reviewed_at  timestamptz,
  unique (driver_id, doc_type)
);
create index if not exists driver_docs_driver_idx on public.driver_documents (driver_id);

alter table public.driver_documents enable row level security;

drop policy if exists "docs self read"  on public.driver_documents;
create policy "docs self read"  on public.driver_documents
  for select using (driver_id = auth.uid());

drop policy if exists "docs self write" on public.driver_documents;
create policy "docs self write" on public.driver_documents
  for insert with check (driver_id = auth.uid());

drop policy if exists "docs self update" on public.driver_documents;
create policy "docs self update" on public.driver_documents
  for update using (driver_id = auth.uid()) with check (driver_id = auth.uid());
-- (reviewers approve/reject via the service role, which bypasses RLS)

-- ── Private storage bucket for the files ────────────────────────────
insert into storage.buckets (id, name, public)
values ('driver-docs', 'driver-docs', false)
on conflict (id) do nothing;

-- Each driver can only touch files under a folder named their own uid.
drop policy if exists "driver docs read own"  on storage.objects;
create policy "driver docs read own"  on storage.objects
  for select using (bucket_id = 'driver-docs'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "driver docs write own" on storage.objects;
create policy "driver docs write own" on storage.objects
  for insert with check (bucket_id = 'driver-docs'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "driver docs update own" on storage.objects;
create policy "driver docs update own" on storage.objects
  for update using (bucket_id = 'driver-docs'
    and (storage.foldername(name))[1] = auth.uid()::text);

-- ── Submit for review: requires the mandatory docs on file ──────────
create or replace function public.request_verification()
returns void
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_have int;
begin
  if not exists (select 1 from public.drivers where id = v_uid) then
    raise exception 'not a driver';
  end if;

  select count(distinct doc_type) into v_have
  from public.driver_documents
  where driver_id = v_uid
    and doc_type in ('national_id','drivers_license','vehicle_registration','insurance');

  if v_have < 4 then
    raise exception 'upload your ID, licence, vehicle registration and insurance first';
  end if;

  update public.drivers set verification_status = 'pending' where id = v_uid;
  -- carry the insurance expiry onto the driver for enforcement/reminders
  update public.drivers d
    set insurance_expiry = (select expiry_date from public.driver_documents
                            where driver_id = v_uid and doc_type = 'insurance')
    where d.id = v_uid;
end $$;

grant execute on function public.request_verification() to authenticated;

-- Ops approve/reject helper (call with the service role from an admin tool):
--   update drivers set verified=true, verification_status='approved' where id=…;
-- claim_trip already gates on verified=true (migration 008).

-- ── Legal consent capture ───────────────────────────────────────────
create table if not exists public.legal_acceptances (
  user_id     uuid not null references auth.users (id) on delete cascade,
  doc_type    text not null,   -- terms | privacy | rider_agreement | driver_agreement
  version     text not null,
  accepted_at timestamptz not null default now(),
  primary key (user_id, doc_type, version)
);

alter table public.legal_acceptances enable row level security;

drop policy if exists "acceptances self read"  on public.legal_acceptances;
create policy "acceptances self read"  on public.legal_acceptances
  for select using (user_id = auth.uid());

drop policy if exists "acceptances self write" on public.legal_acceptances;
create policy "acceptances self write" on public.legal_acceptances
  for insert with check (user_id = auth.uid());

-- ########## 012_account_settings.sql ##########

-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — account settings: self-service deletion + notification prefs.
-- Run in SQL Editor after 011. Safe to re-run.
-- ════════════════════════════════════════════════════════════════════

-- Persisted notification preferences (honoured once push is wired).
alter table public.profiles
  add column if not exists notification_prefs jsonb not null default '{}'::jsonb;

-- Self-service account deletion. Deleting the auth user cascades to profiles,
-- drivers, schedules, rides, documents, acceptances, etc. (all FK on delete
-- cascade). SECURITY DEFINER runs as the function owner, which can delete from
-- auth.users. If your project restricts this, deploy an Edge Function that
-- calls admin.deleteUser instead and point the app at it.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = v_uid;
end $$;

grant execute on function public.delete_my_account() to authenticated;
