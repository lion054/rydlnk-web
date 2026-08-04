-- Rydlnk — 027: repair schema drift between the migrations and production
--
-- A review on 2026-07-30 found ten functions defined in the migrations but ABSENT
-- from the production database, and no pg_cron extension, so none of the
-- scheduled jobs had ever run. The tables from those migrations all exist, which
-- points at 015 and 023 having been applied by hand and failing part-way — the
-- `do $$ … exception when others then raise notice` blocks in both files swallow
-- an error and continue, so a partial apply leaves no trace.
--
-- There is no migration ledger to compare against either:
-- supabase_migrations.schema_migrations does not exist on this project, so
-- `supabase migration list` reports every local file as unapplied.
--
-- What was missing, and what it broke:
--
--   run_entitlements            employees never receive their monthly credits
--   expire_credits              credits never expire
--   release_stale_holds         seat holds are never released
--   offboard_user               hris-offboard is deployed and calls it → 404
--   company_dashboard           unused by current code, restored for completeness
--   platform_audit_is_append_only  the "immutable" platform audit log was MUTABLE
--   admin_audit_user_status     super-admin user status changes unaudited
--   admin_prepare_topup_refund  }
--   admin_finalize_topup_refund } admin-refund-topup is deployed and calls all
--   admin_cancel_topup_refund   } three → refunds fail outright
--
-- Bodies below are copied verbatim from 015_automation.sql and 023_super_admin.sql
-- so this file cannot drift from them. Re-running the source migrations wholesale
-- was rejected: 023 contains `create policy` statements for policies that already
-- exist, which would abort the transaction and roll back everything before them.


-- ── from 015_automation.sql ──────────────────────────────────────

create or replace function public.run_entitlements()
returns table (entitlement uuid, company uuid, people int, credits int)
language plpgsql security definer set search_path = public as $$
declare
  e record; m record; v_float int; v_count int; v_total int;
  v_pre int; v_post int; v_cap int; v_month date := date_trunc('month', now())::date;
  v_due boolean;
begin
  for e in select * from public.entitlements where active loop
    -- Is it due? 'once' only ever runs if it never has.
    v_due := case e.cadence
      when 'once'     then e.last_run_at is null
      when 'weekly'   then e.last_run_at is null
                          or e.last_run_at < now() - interval '6 days'
      when 'biweekly' then e.last_run_at is null
                          or e.last_run_at < now() - interval '13 days'
      when 'monthly'  then e.last_run_at is null
                          or date_trunc('month', e.last_run_at) < date_trunc('month', now())
      else false                       -- on_roster_publish is event-driven
    end;
    if not v_due then continue; end if;

    select count(*) into v_count
    from public.company_members cm
    where cm.company_id = e.company_id and cm.status = 'active'
      and (e.department is null or cm.department = e.department)
      and (e.cost_center_id is null or cm.cost_center_id = e.cost_center_id);

    if v_count = 0 then
      update public.entitlements set last_run_at = now() where id = e.id;
      continue;
    end if;

    v_total := v_count * e.credits_each;
    select credits into v_float from public.company_float_balance
    where company_id = e.company_id;

    -- Not enough float: leave it due and record why, rather than part-paying.
    if coalesce(v_float, 0) < v_total then
      perform public.audit(e.company_id, 'entitlement.skipped', e.id::text,
        jsonb_build_object('needed', v_total, 'float', coalesce(v_float, 0)));
      continue;
    end if;

    select coalesce(monthly_cap_cents, 34000) / 100 into v_cap
    from public.benefit_settings where company_id = e.company_id;
    v_cap := coalesce(v_cap, 340);

    for m in
      select cm.user_id from public.company_members cm
      where cm.company_id = e.company_id and cm.status = 'active'
        and (e.department is null or cm.department = e.department)
        and (e.cost_center_id is null or cm.cost_center_id = e.cost_center_id)
    loop
      v_pre  := least(e.credits_each, public.benefit_headroom(e.company_id, m.user_id));
      v_post := e.credits_each - v_pre;

      insert into public.credit_ledger
        (company_id, kind, from_kind, to_kind, to_user_id, credits, ref, memo)
      values
        (e.company_id, 'allocation', 'company_float', 'employee_wallet', m.user_id,
         e.credits_each, 'RULE-' || upper(replace(e.name, ' ', '-')), 'Scheduled entitlement');

      insert into public.benefit_periods
        (company_id, user_id, period_month, pretax_credits, posttax_credits, cap_cents)
      values
        (e.company_id, m.user_id, v_month, v_pre, v_post, v_cap * 100)
      on conflict (company_id, user_id, period_month) do update
        set pretax_credits  = public.benefit_periods.pretax_credits  + v_pre,
            posttax_credits = public.benefit_periods.posttax_credits + v_post,
            updated_at      = now();
    end loop;

    update public.entitlements set last_run_at = now() where id = e.id;
    perform public.audit(e.company_id, 'entitlement.ran', e.id::text,
      jsonb_build_object('people', v_count, 'total', v_total));

    entitlement := e.id; company := e.company_id; people := v_count; credits := v_total;
    return next;
  end loop;
end $$;

create or replace function public.expire_credits()
returns int
language plpgsql security definer set search_path = public as $$
declare p record; w record; v_keep int; v_return int; n int := 0;
begin
  for p in
    select company_id, unused_credits_policy, carry_over_cap_credits
    from public.company_policies
    where unused_credits_policy <> 'never_expire'
  loop
    for w in
      select user_id, credits from public.employee_wallet_balance
      where company_id = p.company_id and credits > 0
    loop
      v_keep := case p.unused_credits_policy
        when 'carry_over' then least(w.credits, coalesce(p.carry_over_cap_credits, w.credits))
        else 0                              -- return_after_7_days
      end;
      v_return := w.credits - v_keep;
      if v_return <= 0 then continue; end if;

      insert into public.credit_ledger
        (company_id, kind, from_kind, from_user_id, to_kind, credits, ref, memo)
      values
        (p.company_id, 'expiry', 'employee_wallet', w.user_id, 'company_float',
         v_return, 'CYCLE-END', p.unused_credits_policy);
      n := n + 1;
    end loop;
  end loop;
  return n;
end $$;

create or replace function public.release_stale_holds(p_older_than interval default '48 hours')
returns int
language plpgsql security definer set search_path = public as $$
declare sf record; n int := 0;
begin
  for sf in
    select * from public.seat_funding
    where status = 'held'
      and created_at < now() - p_older_than
      and company_id is not null
      and company_credits > 0
  loop
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_ride_id, to_kind, to_user_id, credits, ref, memo)
    values
      (sf.company_id, 'release', 'seat', sf.ride_id, 'employee_wallet', sf.rider_id,
       sf.company_credits, 'HOLD-EXPIRED', 'Never settled');

    update public.seat_funding set status = 'cancelled' where ride_id = sf.ride_id;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.offboard_user(p_company uuid, p_email text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user uuid; v_balance int; v_seats int;
begin
  select id into v_user from auth.users where lower(email) = lower(p_email);
  if v_user is null then
    return jsonb_build_object('ok', false, 'reason', 'no user for that email');
  end if;

  -- Cancel seats not yet travelled and release their holds.
  select count(*) into v_seats
  from public.seat_funding sf
  join public.rides r on r.id = sf.ride_id
  where sf.company_id = p_company and sf.rider_id = v_user
    and sf.status = 'held' and r.ride_date >= current_date;

  insert into public.credit_ledger
    (company_id, kind, from_kind, from_ride_id, to_kind, to_user_id, credits, ref, memo)
  select p_company, 'release', 'seat', sf.ride_id, 'employee_wallet', sf.rider_id,
         sf.company_credits, 'TERMINATION', 'Seat cancelled on offboarding'
  from public.seat_funding sf
  join public.rides r on r.id = sf.ride_id
  where sf.company_id = p_company and sf.rider_id = v_user
    and sf.status = 'held' and r.ride_date >= current_date
    and sf.company_credits > 0;

  update public.seat_funding sf
     set status = 'cancelled'
    from public.rides r
   where r.id = sf.ride_id and sf.company_id = p_company and sf.rider_id = v_user
     and sf.status = 'held' and r.ride_date >= current_date;

  -- Reclaim what's left in the wallet.
  select credits into v_balance from public.employee_wallet_balance
  where company_id = p_company and user_id = v_user;

  if coalesce(v_balance, 0) > 0 then
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_user_id, to_kind, credits, ref, memo)
    values
      (p_company, 'reclaim', 'employee_wallet', v_user, 'company_float',
       v_balance, 'TERMINATION', 'Offboarded');
  end if;

  update public.company_members
     set status = 'removed', removed_at = now()
   where company_id = p_company and user_id = v_user;

  perform public.audit(p_company, 'member.offboarded', p_email,
    jsonb_build_object('reclaimed', coalesce(v_balance, 0), 'seats_cancelled', v_seats));

  return jsonb_build_object('ok', true, 'reclaimed', coalesce(v_balance, 0),
                            'seats_cancelled', v_seats);
end $$;

create or replace function public.company_dashboard(p_company uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.is_company_member(p_company) then
    raise exception 'not a member of that company' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'float',      coalesce((select credits from public.company_float_balance where company_id = p_company), 0),
    'members',    (select count(*) from public.company_members
                   where company_id = p_company and status = 'active'),
    'invites',    (select count(*) from public.company_invites
                   where company_id = p_company and status = 'pending'),
    'approvals',  (select count(*) from public.approvals
                   where company_id = p_company and status = 'pending'),
    'seats',      (select count(*) from public.seat_funding
                   where company_id = p_company and status = 'settled'),
    'credits',    coalesce((select sum(company_credits) from public.seat_funding
                            where company_id = p_company and status = 'settled'), 0),
    'pretax',     coalesce((select sum(pretax_credits) from public.benefit_periods
                            where company_id = p_company
                              and period_month = date_trunc('month', now())::date), 0),
    'corridors',  (select count(*) from public.company_corridors
                   where company_id = p_company and active),
    'sites',      (select count(*) from public.company_sites where company_id = p_company)
  ) into v;
  return v;
end $$;


-- ── from 023_super_admin.sql ─────────────────────────────────────

create or replace function public.platform_audit_is_append_only()
returns trigger language plpgsql as $$
begin
  raise exception 'platform_audit_log is append-only';
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

-- ── The append-only trigger the audit log was missing ───────────────────────
--
-- platform_audit_log had no trigger at all, so any role able to write it could
-- also rewrite or delete history. Guarded because the trigger name is fixed and
-- `create trigger` is not idempotent.

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'platform_audit_no_update' and not tgisinternal
  ) then
    create trigger platform_audit_no_update
      before update or delete on public.platform_audit_log
      for each row execute function public.platform_audit_is_append_only();
    raise notice '027: installed platform_audit_no_update';
  end if;
end $$;

-- ── Grants, per the policy set in 025 ──────────────────────────────────────
--
-- Every function restored above is backend-only: the scheduled jobs run as
-- service_role, and the admin_* refund functions check platform-admin membership
-- internally but must still not be reachable from a browser role. Written as a
-- loop over pg_proc so an overload cannot be missed.

do $$
declare sig text;
begin
  for sig in
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'run_entitlements','expire_credits','release_stale_holds','offboard_user',
        'company_dashboard','admin_audit_user_status','admin_prepare_topup_refund',
        'admin_finalize_topup_refund','admin_cancel_topup_refund')
      and p.prorettype <> 'pg_catalog.trigger'::regtype
  loop
    execute format('revoke all on function %s from public, anon, authenticated', sig);
    execute format('grant execute on function %s to service_role', sig);
  end loop;
end $$;

-- company_dashboard is read by a signed-in company member in the portal, so it
-- keeps `authenticated` — it takes a company id and checks membership itself.
do $$
declare sig text;
begin
  for sig in
    select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='company_dashboard'
  loop
    execute format('grant execute on function %s to authenticated', sig);
  end loop;
end $$;
