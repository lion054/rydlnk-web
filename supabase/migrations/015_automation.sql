-- ════════════════════════════════════════════════════════════════════════════
-- Rydlnk — 015: automation
--
-- Run after 014. Safe to re-run. This is the last SQL for the company build.
--
-- Adds
--   • run_entitlements()   — allocates on a schedule, so nobody grants by hand
--   • expire_credits()     — returns unused wallet credits to the float
--   • release_stale_holds() — frees seats that were held and never boarded
--   • offboard_user()      — freeze + reclaim on a termination webhook
--   • company_dashboard()  — one round trip for the portal overview
--   • pg_cron schedules for the three recurring jobs
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- 1. Entitlements — scheduled allocation
-- ════════════════════════════════════════════════════════════════════════════

/**
 * Run every entitlement that is due.
 *
 * Runs as the table owner with no auth.uid(), so it cannot call
 * allocate_credits() (which authorises on the caller). It posts the same ledger
 * entries and benefit splits directly, and it skips any company whose float
 * can't cover the grant rather than driving the balance negative.
 */
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

-- ════════════════════════════════════════════════════════════════════════════
-- 2. Expiry — unused credits go back to the float
-- ════════════════════════════════════════════════════════════════════════════

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

-- ════════════════════════════════════════════════════════════════════════════
-- 3. Stale holds
--
-- fund_seat() holds credits when a seat is booked. If the trip never settles —
-- cancelled, no-show handled elsewhere, or a booking abandoned — the hold would
-- otherwise pin credits nobody can spend.
-- ════════════════════════════════════════════════════════════════════════════

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

-- ════════════════════════════════════════════════════════════════════════════
-- 4. Offboarding
--
-- Called from an HRIS termination webhook on the service role. A leaver riding
-- on Monday morning is money straight out of the float, which is why this must
-- not wait for a nightly batch.
-- ════════════════════════════════════════════════════════════════════════════

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

-- ════════════════════════════════════════════════════════════════════════════
-- 5. Dashboard in one round trip
-- ════════════════════════════════════════════════════════════════════════════

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

grant execute on function public.company_dashboard(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 6. Schedules
--
-- pg_cron may not be available on every plan. If this block is skipped, call
-- the three functions from an external scheduler instead — they are idempotent
-- and safe to run more often than needed.
-- ════════════════════════════════════════════════════════════════════════════

do $$
begin
  create extension if not exists pg_cron;

  perform cron.unschedule(jobid) from cron.job
   where jobname in ('rydlnk-entitlements','rydlnk-expiry','rydlnk-stale-holds');

  -- Every day at 06:00 UTC; each entitlement decides for itself if it's due.
  perform cron.schedule('rydlnk-entitlements', '0 6 * * *',
                        $cron$select public.run_entitlements()$cron$);

  -- Mondays 05:00 UTC, before the week's allocations land.
  perform cron.schedule('rydlnk-expiry', '0 5 * * 1',
                        $cron$select public.expire_credits()$cron$);

  -- Hourly — a pinned hold is credits nobody can spend.
  perform cron.schedule('rydlnk-stale-holds', '15 * * * *',
                        $cron$select public.release_stale_holds()$cron$);
exception when others then
  raise notice 'pg_cron unavailable (%) — schedule run_entitlements(), expire_credits() and release_stale_holds() externally', sqlerrm;
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- Done.
-- ════════════════════════════════════════════════════════════════════════════
