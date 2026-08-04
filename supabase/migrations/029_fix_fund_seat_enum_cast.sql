-- Rydlnk — 029: fix fund_seat, which could never fund a company seat
--
-- Found by an end-to-end test of the new employer shift feature on 2026-07-30:
-- creating a ride for any rider who belongs to a company raised
--
--   ERROR: 42804: column "source" is of type funding_source
--          but expression is of type text
--
-- fund_seat has two inserts into seat_funding. The first (rider has no company)
-- passes a bare literal 'personal', which Postgres types as `unknown` and
-- coerces to the enum without complaint. The second builds the value with a
-- CASE, and a CASE resolves to `text` — for which there is no implicit cast to
-- an enum. The statement fails, the rides_autofund trigger raises, and the ride
-- insert rolls back.
--
-- The blast radius is the entire employer-funded product: no company member's
-- ride could ever be created. That is why credit_ledger holds 0 rows and
-- seat_funding holds only personal-payer rows. Latent since 013, invisible
-- because nothing had exercised the company path end to end.
--
-- Body below is production's own definition with one change — that CASE wrapped
-- in ::funding_source — so nothing else can drift.

CREATE OR REPLACE FUNCTION public.fund_seat(p_ride uuid)
 RETURNS seat_funding
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r public.rides; pol public.company_policies;
  v_company uuid; v_member public.company_members;
  v_seat_credits int; v_cap int; v_company_pay int; v_personal int;
  v_wallet int; v_reason approval_reason; v_needs_approval boolean := false;
  v_row public.seat_funding; v_dow int;
begin
  select * into r from public.rides where id = p_ride;
  if not found then raise exception 'ride not found'; end if;

  select cm.* into v_member from public.company_members cm
  where cm.user_id = r.rider_id and cm.status = 'active' limit 1;

  -- No membership: the rider pays for themselves, as they do today.
  if v_member.company_id is null then
    insert into public.seat_funding (ride_id, trip_id, rider_id, source, personal_cents, status)
    values (p_ride, r.trip_id, r.rider_id, 'personal', coalesce(r.price_cents, 0), 'held')
    on conflict (ride_id) do update set personal_cents = excluded.personal_cents
    returning * into v_row;
    return v_row;
  end if;

  v_company := v_member.company_id;
  select * into pol from public.company_policies where company_id = v_company;
  v_seat_credits := ceil(coalesce(r.price_cents, 0) / 100.0)::int;
  v_company_pay  := v_seat_credits;
  v_personal     := 0;

  -- Per-trip credit cap.
  v_cap := pol.per_trip_cap_credits;
  if v_cap is not null and v_seat_credits > v_cap then
    v_company_pay := v_cap;
    v_personal    := (v_seat_credits - v_cap) * 100;
    v_reason      := 'over_trip_cap';
    v_needs_approval := coalesce(pol.require_approval_over_cap, true);
  end if;

  -- Funded days.
  v_dow := extract(dow from r.ride_date)::int;
  if pol.funded_days is not null and array_length(pol.funded_days, 1) is not null
     and array_position(pol.funded_days, v_dow) is null then
    v_reason := 'outside_funded_days';
    v_needs_approval := true;
  end if;

  -- Funded hours.
  if pol.funded_from is not null and pol.funded_to is not null and r.pickup_time is not null
     and (r.pickup_time < pol.funded_from or r.pickup_time > pol.funded_to) then
    v_reason := 'outside_funded_hours';
    v_needs_approval := true;
  end if;

  -- Wallet has to actually hold it; the shortfall falls to the rider.
  select credits into v_wallet from public.employee_wallet_balance
  where company_id = v_company and user_id = r.rider_id;
  if coalesce(v_wallet, 0) < v_company_pay then
    v_personal    := v_personal + (v_company_pay - coalesce(v_wallet, 0)) * 100;
    v_company_pay := coalesce(v_wallet, 0);
  end if;

  insert into public.seat_funding
    (ride_id, trip_id, rider_id, company_id, cost_center_id, source,
     company_credits, personal_cents, pretax_credits, status)
  values
    (p_ride, r.trip_id, r.rider_id, v_company, v_member.cost_center_id,
     (case when v_company_pay > 0 and v_personal > 0 then 'split'
          when v_company_pay > 0 then 'company' else 'personal' end)::funding_source,
     v_company_pay, v_personal,
     least(v_company_pay, public.benefit_headroom(v_company, r.rider_id)),
     'held')
  on conflict (ride_id) do update
    set company_credits = excluded.company_credits,
        personal_cents  = excluded.personal_cents,
        source          = excluded.source
  returning * into v_row;

  -- Hold the company portion so two bookings can't spend the same credits.
  if v_company_pay > 0 then
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_user_id, to_kind, to_ride_id, credits, ref)
    values
      (v_company, 'hold', 'employee_wallet', r.rider_id, 'seat', p_ride, v_company_pay, 'HOLD');
  end if;

  if v_needs_approval and v_reason is not null then
    insert into public.approvals
      (company_id, ride_id, rider_id, reason, company_credits, personal_cents)
    values
      (v_company, p_ride, r.rider_id, v_reason, v_company_pay, v_personal);
  end if;

  return v_row;
end $function$;

-- fund_seat stays service_role-only, per 016 and 025. CREATE OR REPLACE keeps
-- existing privileges, but restated so a future recreate cannot silently widen.
do $$
declare sig text;
begin
  for sig in
    select p.oid::regprocedure::text from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'fund_seat'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', sig);
    execute format('grant execute on function %s to service_role', sig);
  end loop;
end $$;
