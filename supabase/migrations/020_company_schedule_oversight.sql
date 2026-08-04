-- Rydlnk — 020: privacy-safe company schedule oversight
-- Run after 019. Safe to re-run.

create or replace function public.company_schedule_overview(p_company uuid)
returns table (
  schedule_id uuid,
  rider_id uuid,
  rider_name text,
  employee_no text,
  department text,
  title text,
  destination text,
  pickup_after time,
  arrive_by time,
  days int[],
  start_date date,
  end_date date,
  return_ride boolean,
  recurring boolean,
  schedule_status schedule_status,
  upcoming_rides int,
  funded_rides int,
  held_credits int
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_company_member(p_company) then
    raise exception 'not a member of that company' using errcode = '42501';
  end if;

  return query
  select
    s.id,
    s.rider_id,
    p.full_name,
    cm.employee_no,
    cm.department,
    s.title,
    -- Pickup is intentionally omitted: it can be a home address. Employers see
    -- the destination and time pattern needed for transport planning.
    s.dropoff,
    s.pickup_after,
    s.arrive_by,
    s.days,
    s.start_date,
    s.end_date,
    s.return_ride,
    s.recurring,
    s.status,
    count(r.id) filter (
      where r.ride_date >= current_date and r.status <> 'cancelled'
    )::int,
    count(sf.ride_id) filter (
      where sf.company_id = p_company and sf.status in ('held', 'settled', 'no_show')
    )::int,
    coalesce(sum(sf.company_credits) filter (
      where sf.company_id = p_company and sf.status = 'held'
    ), 0)::int
  from public.company_members cm
  join public.profiles p on p.id = cm.user_id
  join public.schedules s on s.rider_id = cm.user_id
  left join public.rides r on r.schedule_id = s.id
  left join public.seat_funding sf on sf.ride_id = r.id and sf.company_id = p_company
  where cm.company_id = p_company and cm.status = 'active'
  group by s.id, s.rider_id, p.full_name, cm.employee_no, cm.department
  order by (s.status = 'active') desc, p.full_name nulls last, s.created_at desc;
end $$;

revoke all on function public.company_schedule_overview(uuid) from public;
grant execute on function public.company_schedule_overview(uuid) to authenticated;

