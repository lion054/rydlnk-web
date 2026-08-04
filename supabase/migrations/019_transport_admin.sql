-- Rydlnk — 019: company transport administration
-- Run after 018. Safe to re-run.

create or replace function public.upsert_company_site(
  p_company uuid,
  p_site uuid,
  p_name text,
  p_address text,
  p_lat double precision default null,
  p_lng double precision default null,
  p_primary boolean default false
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.can_administer(p_company) then
    raise exception 'only an owner or admin can manage sites' using errcode = '42501';
  end if;
  if nullif(trim(p_name), '') is null or nullif(trim(p_address), '') is null then
    raise exception 'site name and address are required';
  end if;
  if (p_lat is null) <> (p_lng is null) then
    raise exception 'latitude and longitude must be supplied together';
  end if;

  if p_primary then
    update public.company_sites set is_primary = false where company_id = p_company;
  end if;

  if p_site is null then
    insert into public.company_sites (company_id, name, address, lat, lng, is_primary)
    values (p_company, trim(p_name), trim(p_address), p_lat, p_lng, p_primary)
    returning id into v_id;
  else
    update public.company_sites
       set name = trim(p_name), address = trim(p_address), lat = p_lat, lng = p_lng,
           is_primary = p_primary
     where id = p_site and company_id = p_company
     returning id into v_id;
    if v_id is null then raise exception 'site not found'; end if;
  end if;

  perform public.audit(p_company, 'site.saved', v_id::text, jsonb_build_object('name', trim(p_name)));
  return v_id;
end $$;

create or replace function public.upsert_company_corridor(
  p_company uuid,
  p_corridor uuid,
  p_site uuid,
  p_name text,
  p_destination text,
  p_miles numeric,
  p_seat_credits int,
  p_pooling text,
  p_guaranteed_seats int,
  p_seats_per_vehicle int
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.can_administer(p_company) then
    raise exception 'only an owner or admin can manage corridors' using errcode = '42501';
  end if;
  if nullif(trim(p_name), '') is null or nullif(trim(p_destination), '') is null then
    raise exception 'corridor name and destination are required';
  end if;
  if p_pooling not in ('open', 'approved', 'exclusive') then raise exception 'invalid pooling mode'; end if;
  if p_seat_credits <= 0 or p_seats_per_vehicle <= 0 then raise exception 'prices and capacity must be positive'; end if;
  if p_guaranteed_seats < 0 or p_guaranteed_seats > p_seats_per_vehicle then
    raise exception 'guaranteed seats must fit within vehicle capacity';
  end if;
  if p_site is not null and not exists (
    select 1 from public.company_sites where id = p_site and company_id = p_company
  ) then raise exception 'site does not belong to company'; end if;

  if p_corridor is null then
    insert into public.company_corridors
      (company_id, site_id, name, destination, miles, seat_credits, pooling,
       guaranteed_seats, seats_per_vehicle)
    values
      (p_company, p_site, trim(p_name), trim(p_destination), p_miles, p_seat_credits,
       p_pooling, p_guaranteed_seats, p_seats_per_vehicle)
    returning id into v_id;
  else
    update public.company_corridors
       set site_id = p_site, name = trim(p_name), destination = trim(p_destination),
           miles = p_miles, seat_credits = p_seat_credits, pooling = p_pooling,
           guaranteed_seats = p_guaranteed_seats, seats_per_vehicle = p_seats_per_vehicle
     where id = p_corridor and company_id = p_company
     returning id into v_id;
    if v_id is null then raise exception 'corridor not found'; end if;
  end if;

  perform public.audit(p_company, 'corridor.saved', v_id::text, jsonb_build_object('name', trim(p_name)));
  return v_id;
end $$;

create or replace function public.archive_company_corridor(p_company uuid, p_corridor uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.can_administer(p_company) then
    raise exception 'only an owner or admin can archive corridors' using errcode = '42501';
  end if;
  update public.company_corridors set active = false
  where id = p_corridor and company_id = p_company;
  if not found then raise exception 'corridor not found'; end if;
  perform public.audit(p_company, 'corridor.archived', p_corridor::text, null);
end $$;

revoke all on function public.upsert_company_site(uuid,uuid,text,text,double precision,double precision,boolean) from public;
revoke all on function public.upsert_company_corridor(uuid,uuid,uuid,text,text,numeric,int,text,int,int) from public;
revoke all on function public.archive_company_corridor(uuid,uuid) from public;
grant execute on function public.upsert_company_site(uuid,uuid,text,text,double precision,double precision,boolean) to authenticated;
grant execute on function public.upsert_company_corridor(uuid,uuid,uuid,text,text,numeric,int,text,int,int) to authenticated;
grant execute on function public.archive_company_corridor(uuid,uuid) to authenticated;

