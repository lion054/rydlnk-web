-- Rydlnk — 021: isolated platform operations and fleet dispatch
-- Run after 020. Safe to re-run.

create table if not exists public.platform_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('dispatcher', 'operations_admin')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.fleet_vehicles (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  registration text not null unique,
  make_model text,
  capacity int not null default 8 check (capacity > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.drivers add column if not exists fleet_vehicle_id uuid
  references public.fleet_vehicles(id) on delete set null;
alter table public.trips add column if not exists fleet_vehicle_id uuid
  references public.fleet_vehicles(id) on delete set null;

alter table public.platform_staff enable row level security;
alter table public.fleet_vehicles enable row level security;
revoke all on public.platform_staff, public.fleet_vehicles from public, anon, authenticated;

create or replace function public.is_platform_operator()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.platform_staff
    where user_id = auth.uid() and active and role in ('dispatcher', 'operations_admin')
  );
$$;

create or replace function public.platform_operator_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.platform_staff where user_id = auth.uid() and active limit 1;
$$;

create or replace function public.dispatch_board(p_from date default current_date, p_to date default current_date + 7)
returns table (
  trip_id uuid, ride_date date, pickup_time time, pickup text, dropoff text,
  status ride_status, capacity int, filled int, driver_id uuid, driver_name text,
  vehicle_id uuid, vehicle_label text, vehicle_registration text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_operator() then
    raise exception 'platform operator access required' using errcode = '42501';
  end if;
  return query
  select t.id, t.ride_date, t.pickup_time, t.pickup, t.dropoff, t.status, t.capacity,
         (select count(*)::int from public.rides r where r.trip_id = t.id and r.status <> 'cancelled'),
         t.driver_id, p.full_name, t.fleet_vehicle_id, v.label, v.registration
  from public.trips t
  left join public.profiles p on p.id = t.driver_id
  left join public.fleet_vehicles v on v.id = t.fleet_vehicle_id
  where t.ride_date between p_from and p_to and t.status <> 'cancelled'
  order by t.ride_date, t.pickup_time nulls last;
end $$;

create or replace function public.dispatch_drivers()
returns table (
  driver_id uuid, driver_name text, rating numeric, available boolean,
  vehicle_id uuid, vehicle_label text, vehicle_registration text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_operator() then
    raise exception 'platform operator access required' using errcode = '42501';
  end if;
  return query
  select d.id, p.full_name, d.rating, d.is_available, d.fleet_vehicle_id, v.label, v.registration
  from public.drivers d
  join public.profiles p on p.id = d.id
  left join public.fleet_vehicles v on v.id = d.fleet_vehicle_id
  where d.verified
  order by d.is_available desc, p.full_name;
end $$;

create or replace function public.dispatch_vehicles()
returns table (vehicle_id uuid, label text, registration text, make_model text, capacity int, active boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_operator() then
    raise exception 'platform operator access required' using errcode = '42501';
  end if;
  return query select v.id, v.label, v.registration, v.make_model, v.capacity, v.active
  from public.fleet_vehicles v order by v.active desc, v.label;
end $$;

create or replace function public.upsert_fleet_vehicle(
  p_vehicle uuid, p_label text, p_registration text, p_make_model text, p_capacity int
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if public.platform_operator_role() <> 'operations_admin' then
    raise exception 'operations admin access required' using errcode = '42501';
  end if;
  if nullif(trim(p_label), '') is null or nullif(trim(p_registration), '') is null or p_capacity <= 0 then
    raise exception 'label, registration and positive capacity are required';
  end if;
  if p_vehicle is null then
    insert into public.fleet_vehicles(label, registration, make_model, capacity)
    values(trim(p_label), upper(trim(p_registration)), nullif(trim(p_make_model), ''), p_capacity)
    returning id into v_id;
  else
    update public.fleet_vehicles set label = trim(p_label), registration = upper(trim(p_registration)),
      make_model = nullif(trim(p_make_model), ''), capacity = p_capacity, updated_at = now()
    where id = p_vehicle returning id into v_id;
    if v_id is null then raise exception 'vehicle not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.assign_trip_dispatch(
  p_trip uuid, p_driver uuid, p_vehicle uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare t public.trips; d public.drivers; v public.fleet_vehicles; v_filled int;
begin
  if not public.is_platform_operator() then
    raise exception 'platform operator access required' using errcode = '42501';
  end if;
  select * into t from public.trips where id = p_trip for update;
  if not found then raise exception 'trip not found'; end if;
  if t.status in ('started', 'completed', 'cancelled') then raise exception 'trip can no longer be assigned'; end if;
  select * into d from public.drivers where id = p_driver and verified;
  if not found then raise exception 'driver is not verified'; end if;
  select * into v from public.fleet_vehicles where id = p_vehicle and active;
  if not found then raise exception 'vehicle is not active'; end if;
  select count(*) into v_filled from public.rides where trip_id = p_trip and status <> 'cancelled';
  if v.capacity < v_filled then raise exception 'vehicle capacity is below the current manifest'; end if;

  update public.trips set driver_id = p_driver, fleet_vehicle_id = p_vehicle,
    capacity = v.capacity, status = 'matched' where id = p_trip;
  update public.rides set driver_id = p_driver, status = 'matched'
    where trip_id = p_trip and status = 'scheduled';
  update public.drivers set fleet_vehicle_id = p_vehicle where id = p_driver;
end $$;

revoke all on function public.is_platform_operator() from public;
revoke all on function public.platform_operator_role() from public;
revoke all on function public.dispatch_board(date,date) from public;
revoke all on function public.dispatch_drivers() from public;
revoke all on function public.dispatch_vehicles() from public;
revoke all on function public.upsert_fleet_vehicle(uuid,text,text,text,int) from public;
revoke all on function public.assign_trip_dispatch(uuid,uuid,uuid) from public;
grant execute on function public.is_platform_operator(), public.platform_operator_role(),
  public.dispatch_board(date,date), public.dispatch_drivers(), public.dispatch_vehicles(),
  public.upsert_fleet_vehicle(uuid,text,text,text,int),
  public.assign_trip_dispatch(uuid,uuid,uuid) to authenticated;

-- Bootstrap the first operator using the service role / SQL editor:
-- insert into public.platform_staff(user_id, role)
-- values ('AUTH-USER-UUID', 'operations_admin');

