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
