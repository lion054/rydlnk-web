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
