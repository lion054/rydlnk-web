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
