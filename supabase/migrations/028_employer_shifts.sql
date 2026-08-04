-- Rydlnk — 028: let an employer schedule a shift on an employee's behalf
--
-- Until now a commute could only be scheduled by the rider, from the app:
-- create_schedule() writes `rider_id = auth.uid()` and has no other path. The
-- employer portal could read schedules (company_schedule_overview, 020) but had
-- no way to create one, and the mobile app is not published yet — so there was no
-- route by which an employee's ride ever came into existence.
--
-- That is the gap this closes. It deliberately does NOT change how funding works:
-- a shift creates ordinary `schedules` and `rides` rows, so the existing
-- rides_autofund trigger fires fund_seat() exactly as it does for a rider-created
-- schedule. The money path is untouched; only the authorship changes.
--
-- Two rules make employer authorship safe:
--
--   1. The caller must be an owner or admin of the company (can_administer).
--   2. The target rider must be an ACTIVE member of that same company. Without
--      this an admin could schedule rides for any user id in the system and
--      have their own float charged for a stranger's travel — or worse, use it
--      to probe which user ids exist.
--
-- Consent note for whoever operates this: an employer scheduling travel for a
-- named employee is a different privacy proposition from an employee booking
-- their own. `created_by` is recorded on every such schedule so a rider can see
-- the shift was not theirs, and cancel_company_shift leaves the rider's own
-- cancel path (cancel_schedule) untouched.

-- ── Provenance ──────────────────────────────────────────────────────────────
-- Nullable: every schedule that already exists was rider-created, and that is
-- exactly what NULL means here.

alter table public.schedules
  add column if not exists created_by uuid references auth.users (id) on delete set null;

comment on column public.schedules.created_by is
  'Company admin who scheduled this on the rider''s behalf. NULL = the rider created it themselves.';

create index if not exists schedules_created_by_idx
  on public.schedules (created_by) where created_by is not null;

-- ── Create ──────────────────────────────────────────────────────────────────

/**
 * Schedule a recurring shift for an employee.
 *
 * Mirrors create_schedule()'s arguments so the two stay comparable, minus
 * auto_reschedule — that is a rider preference about being re-booked when a trip
 * falls through, and it is not the employer's to set.
 *
 * Returns the schedule id. Rides are generated immediately, out to the same
 * 21-day horizon create_schedule uses, so the portal can show them at once.
 */
create or replace function public.create_company_shift(
  p_company      uuid,
  p_rider        uuid,
  p_title        text,
  p_pickup       text,
  p_dropoff      text,
  p_pickup_after time,
  p_arrive_by    time,
  p_days         int[],
  p_start        date,
  p_end          date default null,
  p_return_ride  boolean default true,
  p_recurring    boolean default true,
  p_price_cents  int default 0
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_horizon date;
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not public.can_administer(p_company) then
    raise exception 'only an owner or admin can schedule shifts'
      using errcode = '42501';
  end if;

  -- Rule 2. Checked against the caller's own company, so a valid admin of
  -- company A cannot name a member of company B.
  if not exists (
    select 1 from public.company_members
    where company_id = p_company and user_id = p_rider and status = 'active'
  ) then
    raise exception 'that person is not an active member of this company'
      using errcode = '42501';
  end if;

  if p_start is null then
    raise exception 'a start date is required';
  end if;
  if p_end is not null and p_end < p_start then
    raise exception 'the end date cannot fall before the start date';
  end if;
  if p_days is null or array_length(p_days, 1) is null then
    raise exception 'pick at least one day of the week';
  end if;
  -- extract(dow) is 0-6; anything else silently generates no rides, which reads
  -- as "the feature is broken" rather than "the input was wrong".
  if exists (select 1 from unnest(p_days) d where d < 0 or d > 6) then
    raise exception 'days must be 0 (Sunday) through 6 (Saturday)';
  end if;

  insert into public.schedules (
    rider_id, title, pickup, dropoff, pickup_after, arrive_by,
    days, start_date, end_date, return_ride, recurring, auto_reschedule,
    estimated_price_cents, status, created_by)
  values (
    p_rider, p_title, p_pickup, p_dropoff, p_pickup_after, p_arrive_by,
    p_days, p_start, p_end, coalesce(p_return_ride, true),
    coalesce(p_recurring, true), false,
    coalesce(p_price_cents, 0), 'active', v_actor)
  returning id into v_id;

  -- Same horizon as create_schedule: generate now, but never more than three
  -- weeks ahead for an open-ended shift.
  v_horizon := least(coalesce(p_end, p_start + 21), p_start + 21);
  perform public.generate_rides_for_schedule(v_id, p_start, v_horizon);

  perform public.audit(p_company, 'shift.created', v_id::text,
    jsonb_build_object('rider', p_rider, 'title', p_title,
                       'days', p_days, 'start', p_start, 'end', p_end));

  return v_id;
end $$;

-- ── Cancel ──────────────────────────────────────────────────────────────────

/**
 * Cancel a shift the company scheduled.
 *
 * Scoped to schedules belonging to a member of the calling company, so this
 * cannot reach a rider's private schedule at another employer. Future rides are
 * cancelled too; past ones are left alone because they are billing history.
 */
create or replace function public.cancel_company_shift(
  p_company  uuid,
  p_schedule uuid
) returns int
language plpgsql security definer set search_path = public as $$
declare v_rider uuid; v_cancelled int;
begin
  if not public.can_administer(p_company) then
    raise exception 'only an owner or admin can cancel shifts'
      using errcode = '42501';
  end if;

  select s.rider_id into v_rider
  from public.schedules s
  join public.company_members cm
    on cm.user_id = s.rider_id and cm.company_id = p_company and cm.status = 'active'
  where s.id = p_schedule;

  if v_rider is null then
    raise exception 'no such shift for this company' using errcode = '42501';
  end if;

  update public.schedules set status = 'cancelled' where id = p_schedule;

  -- Only rides that have not happened yet. fund_seat holds credits at insert,
  -- and the existing cancellation path releases them.
  update public.rides
     set status = 'cancelled'
   where schedule_id = p_schedule
     and ride_date >= current_date
     and status <> 'cancelled';
  get diagnostics v_cancelled = row_count;

  perform public.audit(p_company, 'shift.cancelled', p_schedule::text,
    jsonb_build_object('rider', v_rider, 'rides_cancelled', v_cancelled));

  return v_cancelled;
end $$;

-- ── Who can be given a shift ────────────────────────────────────────────────

/**
 * Active members of a company, for the shift form's rider picker.
 *
 * Exists because the portal needs names and emails together and company_members
 * alone cannot reach auth.users under RLS. Membership of the *calling* company
 * is re-checked here, so it cannot be used to enumerate another company's staff.
 */
create or replace function public.company_shift_candidates(p_company uuid)
returns table (user_id uuid, email text, department text, role company_role)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_company_member(p_company) then
    raise exception 'not a member of that company' using errcode = '42501';
  end if;

  return query
    select cm.user_id, lower(u.email)::text, cm.department, cm.role
    from public.company_members cm
    join auth.users u on u.id = cm.user_id
    where cm.company_id = p_company and cm.status = 'active'
    order by lower(u.email);
end $$;

-- ── Grants ──────────────────────────────────────────────────────────────────
-- Called from the portal by a signed-in admin, so these take `authenticated`.
-- Each one re-checks the caller's role internally — the grant is not the control.
-- Written as a loop per the convention in 025: never `revoke … from public` alone.

do $$
declare sig text;
begin
  for sig in
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('create_company_shift', 'cancel_company_shift', 'company_shift_candidates')
  loop
    execute format('revoke all on function %s from public, anon', sig);
    execute format('grant execute on function %s to authenticated, service_role', sig);
  end loop;
end $$;
