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
