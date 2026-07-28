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
