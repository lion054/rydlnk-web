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
