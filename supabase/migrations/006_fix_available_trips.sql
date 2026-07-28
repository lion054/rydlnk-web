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
