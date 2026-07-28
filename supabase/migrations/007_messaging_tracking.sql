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
