-- Rydlnk — 023: audited super-admin control plane
-- Run after 022. Safe to re-run.

create table if not exists public.platform_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text not null,
  reason text,
  detail jsonb,
  created_at timestamptz not null default now()
);

alter type topup_status add value if not exists 'refunding';

alter table public.platform_audit_log enable row level security;
revoke all on public.platform_audit_log from public, anon, authenticated;

create or replace function public.platform_audit_is_append_only()
returns trigger language plpgsql as $$
begin
  raise exception 'platform_audit_log is append-only';
end $$;
drop trigger if exists platform_audit_no_update on public.platform_audit_log;
create trigger platform_audit_no_update before update or delete on public.platform_audit_log
  for each row execute function public.platform_audit_is_append_only();

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.platform_staff
    where user_id = auth.uid() and active and role = 'operations_admin'
  );
$$;

-- Suspension is an authorization boundary, not just a dashboard flag.
create or replace function public.is_company_member(p_company uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.company_members cm
    join public.companies c on c.id = cm.company_id
    where cm.company_id = p_company and cm.user_id = auth.uid()
      and cm.status = 'active' and c.suspended_at is null
  );
$$;

create or replace function public.has_company_role(p_company uuid, p_roles company_role[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.company_members cm
    join public.companies c on c.id = cm.company_id
    where cm.company_id = p_company and cm.user_id = auth.uid()
      and cm.status = 'active' and cm.role = any(p_roles) and c.suspended_at is null
  );
$$;

create or replace function public.platform_audit(
  p_action text, p_target_type text, p_target_id text, p_reason text, p_detail jsonb default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    raise exception 'operations admin access required' using errcode = '42501';
  end if;
  if nullif(trim(p_reason), '') is null then raise exception 'a reason is required'; end if;
  insert into public.platform_audit_log(actor_id, action, target_type, target_id, reason, detail)
  values(auth.uid(), p_action, p_target_type, p_target_id, trim(p_reason), p_detail);
end $$;

create or replace function public.admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return jsonb_build_object(
    'companies', (select count(*) from public.companies),
    'suspended_companies', (select count(*) from public.companies where suspended_at is not null),
    'active_members', (select count(*) from public.company_members where status = 'active'),
    'drivers', (select count(*) from public.drivers),
    'pending_drivers', (select count(*) from public.drivers where verification_status = 'pending'),
    'trips_next_7_days', (select count(*) from public.trips where ride_date between current_date and current_date + 7 and status <> 'cancelled'),
    'pending_topups', (select count(*) from public.float_topups where status = 'pending'),
    'failed_webhooks', (select count(*) from public.stripe_webhook_events where status = 'failed')
  );
end $$;

create or replace function public.admin_companies()
returns table (
  company_id uuid, company_name text, billing_email text, country text,
  suspended_at timestamptz, members int, float_credits int, settled_seats int, created_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return query
  select c.id, c.name, c.billing_email, c.country, c.suspended_at,
    (select count(*)::int from public.company_members cm where cm.company_id = c.id and cm.status = 'active'),
    coalesce((select b.credits from public.company_float_balance b where b.company_id = c.id), 0),
    (select count(*)::int from public.seat_funding sf where sf.company_id = c.id and sf.status = 'settled'),
    c.created_at
  from public.companies c order by c.created_at desc;
end $$;

create or replace function public.admin_users(p_search text default null)
returns table (
  user_id uuid, email text, full_name text, company_name text, company_role company_role,
  member_status member_status, joined_at timestamptz, banned_until timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return query
  select u.id, u.email, p.full_name, c.name, cm.role, cm.status, cm.joined_at, u.banned_until
  from auth.users u
  left join public.profiles p on p.id = u.id
  left join public.company_members cm on cm.user_id = u.id and cm.status <> 'removed'
  left join public.companies c on c.id = cm.company_id
  where p_search is null or u.email ilike '%' || p_search || '%' or p.full_name ilike '%' || p_search || '%'
  order by u.created_at desc limit 200;
end $$;

create or replace function public.admin_audit_user_status(
  p_user uuid, p_disabled boolean, p_reason text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  perform public.platform_audit(
    case when p_disabled then 'user.disabled' else 'user.enabled' end,
    'user', p_user::text, p_reason, null
  );
end $$;

create or replace function public.admin_drivers()
returns table (
  driver_id uuid, email text, full_name text, verification_status text, verified boolean,
  rating numeric, available boolean, insurance_expiry date, document_count int,
  pending_documents int, rejected_documents int
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return query
  select d.id, u.email, p.full_name, d.verification_status, d.verified, d.rating, d.is_available,
    d.insurance_expiry,
    (select count(*)::int from public.driver_documents x where x.driver_id = d.id),
    (select count(*)::int from public.driver_documents x where x.driver_id = d.id and x.status = 'pending'),
    (select count(*)::int from public.driver_documents x where x.driver_id = d.id and x.status = 'rejected')
  from public.drivers d join auth.users u on u.id = d.id left join public.profiles p on p.id = d.id
  order by (d.verification_status = 'pending') desc, p.full_name;
end $$;

create or replace function public.admin_driver_documents(p_driver uuid)
returns table (
  document_id uuid, doc_type doc_type, storage_path text, status doc_status,
  expiry_date date, note text, created_at timestamptz, reviewed_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return query select d.id, d.doc_type, d.storage_path, d.status, d.expiry_date, d.note, d.created_at, d.reviewed_at
  from public.driver_documents d where d.driver_id = p_driver order by d.doc_type;
end $$;

create or replace function public.admin_payments()
returns table (
  topup_id uuid, company_name text, credits int, amount_cents int, status topup_status,
  stripe_payment_intent_id text, created_at timestamptz, settled_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return query select t.id, c.name, t.credits, t.amount_cents, t.status, t.stripe_payment_intent_id,
    t.created_at, t.settled_at from public.float_topups t join public.companies c on c.id = t.company_id
    order by t.created_at desc limit 200;
end $$;

create or replace function public.admin_platform_staff()
returns table (user_id uuid, email text, full_name text, role text, active boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return query select s.user_id, u.email, p.full_name, s.role, s.active, s.created_at
  from public.platform_staff s join auth.users u on u.id = s.user_id left join public.profiles p on p.id = s.user_id
  order by s.active desc, u.email;
end $$;

create or replace function public.admin_platform_audit()
returns table (
  id bigint, actor_email text, action text, target_type text, target_id text,
  reason text, detail jsonb, created_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  return query select a.id, u.email, a.action, a.target_type, a.target_id, a.reason, a.detail, a.created_at
  from public.platform_audit_log a left join auth.users u on u.id = a.actor_id
  order by a.created_at desc limit 500;
end $$;

create or replace function public.admin_set_company_suspension(
  p_company uuid, p_suspended boolean, p_reason text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  update public.companies set suspended_at = case when p_suspended then now() else null end, updated_at = now()
  where id = p_company;
  if not found then raise exception 'company not found'; end if;
  perform public.platform_audit(
    case when p_suspended then 'company.suspended' else 'company.reactivated' end,
    'company', p_company::text, p_reason, null
  );
end $$;

create or replace function public.admin_decide_driver(
  p_driver uuid, p_approve boolean, p_reason text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  if p_approve and exists (
    select 1 from public.driver_documents where driver_id = p_driver
      and (status <> 'approved' or (expiry_date is not null and expiry_date < current_date))
  ) then raise exception 'all uploaded documents must be approved and unexpired'; end if;
  update public.drivers set verified = p_approve,
    verification_status = case when p_approve then 'approved' else 'rejected' end
  where id = p_driver;
  if not found then raise exception 'driver not found'; end if;
  if not p_approve then
    update public.drivers set is_available = false where id = p_driver;
  end if;
  perform public.platform_audit(
    case when p_approve then 'driver.approved' else 'driver.rejected' end,
    'driver', p_driver::text, p_reason, null
  );
end $$;

create or replace function public.admin_review_driver_document(
  p_document uuid, p_approve boolean, p_reason text
) returns void language plpgsql security definer set search_path = public as $$
declare v_driver uuid;
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'a review note is required'; end if;
  update public.driver_documents
     set status = case when p_approve then 'approved'::doc_status else 'rejected'::doc_status end,
         note = trim(p_reason), reviewed_at = now()
   where id = p_document returning driver_id into v_driver;
  if v_driver is null then raise exception 'document not found'; end if;
  perform public.platform_audit(
    case when p_approve then 'driver_document.approved' else 'driver_document.rejected' end,
    'driver_document', p_document::text, p_reason, jsonb_build_object('driver_id', v_driver)
  );
end $$;

create or replace function public.admin_set_platform_staff(
  p_user uuid, p_role text, p_active boolean, p_reason text
) returns void language plpgsql security definer set search_path = public as $$
declare v_active_admins int;
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  if p_role not in ('dispatcher', 'operations_admin') then raise exception 'invalid platform role'; end if;
  if not exists (select 1 from auth.users where id = p_user) then raise exception 'user not found'; end if;
  if p_user = auth.uid() and not p_active then raise exception 'you cannot deactivate your own platform access'; end if;
  select count(*) into v_active_admins from public.platform_staff where active and role = 'operations_admin';
  if not p_active and exists (
    select 1 from public.platform_staff where user_id = p_user and active and role = 'operations_admin'
  ) and v_active_admins <= 1 then raise exception 'cannot deactivate the last operations admin'; end if;
  insert into public.platform_staff(user_id, role, active) values(p_user, p_role, p_active)
  on conflict(user_id) do update set role = excluded.role, active = excluded.active;
  perform public.platform_audit('platform_staff.updated', 'user', p_user::text, p_reason,
    jsonb_build_object('role', p_role, 'active', p_active));
end $$;

create or replace function public.admin_prepare_topup_refund(
  p_topup uuid, p_reason text
) returns text language plpgsql security definer set search_path = public as $$
declare t public.float_topups; v_float int;
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  select * into t from public.float_topups where id = p_topup for update;
  if not found then raise exception 'top-up not found'; end if;
  if t.status = 'refunded' then return t.stripe_payment_intent_id; end if;
  if t.status = 'refunding' then return t.stripe_payment_intent_id; end if;
  if t.status <> 'succeeded' or t.stripe_payment_intent_id is null then
    raise exception 'only settled Stripe top-ups can be refunded';
  end if;
  select credits into v_float from public.company_float_balance where company_id = t.company_id;
  if coalesce(v_float, 0) < t.credits then
    raise exception 'company float no longer covers this refund';
  end if;
  insert into public.credit_ledger(company_id, kind, from_kind, to_kind, credits, ref, memo, created_by)
  values(t.company_id, 'hold', 'company_float', 'clearing', t.credits,
    'TOPUP-REFUND-HOLD-' || left(t.id::text, 8), 'Reserved pending Stripe refund', auth.uid());
  update public.float_topups set status = 'refunding' where id = t.id;
  perform public.platform_audit('topup.refund_started', 'float_topup', t.id::text, p_reason,
    jsonb_build_object('credits', t.credits));
  return t.stripe_payment_intent_id;
end $$;

create or replace function public.admin_finalize_topup_refund(
  p_topup uuid, p_stripe_refund text, p_reason text
) returns void language plpgsql security definer set search_path = public as $$
declare t public.float_topups;
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  select * into t from public.float_topups where id = p_topup for update;
  if not found then raise exception 'top-up not found'; end if;
  if t.status = 'refunded' then return; end if;
  if t.status <> 'refunding' then raise exception 'top-up refund was not reserved'; end if;
  insert into public.credit_ledger(company_id, kind, from_kind, to_kind, credits, ref, memo, created_by)
  values(t.company_id, 'refund', 'clearing', 'external', t.credits,
    'TOPUP-REFUND-' || left(t.id::text, 8), 'Stripe refund ' || p_stripe_refund, auth.uid());
  update public.float_topups set status = 'refunded' where id = t.id;
  perform public.platform_audit('topup.refunded', 'float_topup', t.id::text, p_reason,
    jsonb_build_object('credits', t.credits, 'stripe_refund', p_stripe_refund));
end $$;

create or replace function public.admin_cancel_topup_refund(
  p_topup uuid, p_reason text
) returns void language plpgsql security definer set search_path = public as $$
declare t public.float_topups;
begin
  if not public.is_platform_admin() then raise exception 'operations admin access required' using errcode = '42501'; end if;
  select * into t from public.float_topups where id = p_topup for update;
  if not found or t.status <> 'refunding' then return; end if;
  insert into public.credit_ledger(company_id, kind, from_kind, to_kind, credits, ref, memo, created_by)
  values(t.company_id, 'release', 'clearing', 'company_float', t.credits,
    'TOPUP-REFUND-RELEASE-' || left(t.id::text, 8), 'Stripe refund failed', auth.uid());
  update public.float_topups set status = 'succeeded' where id = t.id;
  perform public.platform_audit('topup.refund_cancelled', 'float_topup', t.id::text, p_reason, null);
end $$;

revoke all on function public.is_platform_admin() from public;
revoke all on function public.platform_audit(text,text,text,text,jsonb) from public;
revoke all on function public.admin_dashboard() from public;
revoke all on function public.admin_companies() from public;
revoke all on function public.admin_users(text) from public;
revoke all on function public.admin_audit_user_status(uuid,boolean,text) from public;
revoke all on function public.admin_drivers() from public;
revoke all on function public.admin_driver_documents(uuid) from public;
revoke all on function public.admin_payments() from public;
revoke all on function public.admin_platform_staff() from public;
revoke all on function public.admin_platform_audit() from public;
revoke all on function public.admin_set_company_suspension(uuid,boolean,text) from public;
revoke all on function public.admin_decide_driver(uuid,boolean,text) from public;
revoke all on function public.admin_review_driver_document(uuid,boolean,text) from public;
revoke all on function public.admin_set_platform_staff(uuid,text,boolean,text) from public;
revoke all on function public.admin_prepare_topup_refund(uuid,text) from public;
revoke all on function public.admin_finalize_topup_refund(uuid,text,text) from public;
revoke all on function public.admin_cancel_topup_refund(uuid,text) from public;
grant execute on function public.is_platform_admin(), public.admin_dashboard(), public.admin_companies(),
  public.admin_users(text), public.admin_audit_user_status(uuid,boolean,text),
  public.admin_drivers(), public.admin_payments(), public.admin_platform_staff(),
  public.admin_driver_documents(uuid),
  public.admin_platform_audit(), public.admin_set_company_suspension(uuid,boolean,text),
  public.admin_decide_driver(uuid,boolean,text), public.admin_review_driver_document(uuid,boolean,text),
  public.admin_set_platform_staff(uuid,text,boolean,text),
  public.admin_prepare_topup_refund(uuid,text),
  public.admin_finalize_topup_refund(uuid,text,text),
  public.admin_cancel_topup_refund(uuid,text)
  to authenticated;

drop policy if exists "driver docs platform admin read" on public.driver_documents;
create policy "driver docs platform admin read" on public.driver_documents
  for select using (public.is_platform_admin());
drop policy if exists "driver storage platform admin read" on storage.objects;
create policy "driver storage platform admin read" on storage.objects
  for select using (bucket_id = 'driver-docs' and public.is_platform_admin());
