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
