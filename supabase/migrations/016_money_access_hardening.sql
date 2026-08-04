-- ════════════════════════════════════════════════════════════════════════════
-- Rydlnk — 016: money and access hardening
--
-- Run after 015. This is forward-only and safe to re-run.
--
-- Fixes:
--   • an invite can only be accepted by the email address it names
--   • a held seat settles seat -> clearing instead of debiting the wallet twice
--   • existing double-debited settled seats receive one compensating entry
--   • approval decisions apply/release funding atomically
--   • internal funding and settlement RPCs are no longer callable by every user
-- ════════════════════════════════════════════════════════════════════════════

-- ── Invite redemption ────────────────────────────────────────────────────────

create or replace function public.accept_company_invite(p_token text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  inv public.company_invites;
  v_uid uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select lower(email) into v_email from auth.users where id = v_uid;
  if v_email is null then raise exception 'no email on account'; end if;

  select * into inv
  from public.company_invites
  where token_hash = encode(sha256(p_token::bytea), 'hex')
  for update;

  if not found then raise exception 'invite not found'; end if;
  if inv.status <> 'pending' then raise exception 'invite already %', inv.status; end if;
  if inv.expires_at < now() then
    update public.company_invites set status = 'expired' where id = inv.id;
    raise exception 'invite expired';
  end if;
  if lower(inv.email) <> v_email then
    raise exception 'this invite was issued to a different email address'
      using errcode = '42501';
  end if;

  insert into public.company_members
    (company_id, user_id, role, status, department, cost_center_id, employee_no, invited_by)
  values
    (inv.company_id, v_uid, inv.role, 'active', inv.department, inv.cost_center_id,
     inv.employee_no, inv.invited_by)
  on conflict (company_id, user_id)
    do update set
      status = 'active',
      role = excluded.role,
      department = excluded.department,
      cost_center_id = excluded.cost_center_id,
      employee_no = excluded.employee_no,
      removed_at = null;

  update public.company_invites
     set status = 'accepted', accepted_at = now(), accepted_by = v_uid
   where id = inv.id;

  perform public.audit(inv.company_id, 'invite.accepted', v_uid::text, null);
  return inv.company_id;
end $$;

-- ── Correct historical double debits ─────────────────────────────────────────
--
-- 013 posted both employee -> seat HOLD and employee -> seat CONSUMPTION.
-- The compensating entry restores the second wallet debit. A unique index on
-- the reference makes this repair idempotent without changing ledger history.

create unique index if not exists credit_ledger_company_ref_unique
  on public.credit_ledger (company_id, ref)
  where ref like 'SETTLEMENT-CORRECTION-%';

insert into public.credit_ledger
  (company_id, kind, from_kind, from_ride_id, to_kind, to_user_id, credits, ref, memo)
select
  sf.company_id,
  'adjustment',
  'seat',
  sf.ride_id,
  'employee_wallet',
  sf.rider_id,
  sf.company_credits,
  'SETTLEMENT-CORRECTION-' || sf.ride_id::text,
  '016 correction: settlement previously debited the employee wallet after hold'
from public.seat_funding sf
where sf.status = 'settled'
  and sf.company_id is not null
  and sf.company_credits > 0
  and exists (
    select 1 from public.credit_ledger l
    where l.company_id = sf.company_id
      and l.to_ride_id = sf.ride_id
      and l.kind = 'hold'
  )
  and exists (
    select 1 from public.credit_ledger l
    where l.company_id = sf.company_id
      and l.to_ride_id = sf.ride_id
      and l.kind = 'consumption'
      and l.from_kind = 'employee_wallet'
  )
on conflict (company_id, ref) where ref like 'SETTLEMENT-CORRECTION-%'
do nothing;

-- Settlement consumes the already-held seat balance. Only a trusted backend
-- (boarding verification/webhook) may invoke this function.
create or replace function public.settle_seat(p_ride uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare sf public.seat_funding;
begin
  select * into sf
  from public.seat_funding
  where ride_id = p_ride
  for update;

  if not found or sf.status <> 'held' then return; end if;

  if sf.company_credits > 0 then
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_ride_id, to_kind, credits, ref, memo)
    values
      (sf.company_id, 'consumption', 'seat', p_ride, 'clearing',
       sf.company_credits, 'SETTLE-' || p_ride::text, 'Boarding verified');
  end if;

  update public.seat_funding
     set status = 'settled', settled_at = now()
   where ride_id = p_ride;
end $$;

revoke execute on function public.fund_seat(uuid) from public, anon, authenticated;
revoke execute on function public.settle_seat(uuid) from public, anon, authenticated;
grant execute on function public.settle_seat(uuid) to service_role;

-- A browser caller must never be able to mint a manual top-up. Company Stripe
-- top-ups are inserted by the edge function and settled by the signed webhook.
-- A future wire-transfer workflow must verify the bank settlement server-side
-- before calling this function with service-role credentials.
revoke execute on function public.topup_float(uuid, int, text, boolean)
  from public, anon, authenticated;
grant execute on function public.topup_float(uuid, int, text, boolean)
  to service_role;

-- ── Approval decisions ───────────────────────────────────────────────────────

create or replace function public.decide_company_approval(
  p_approval uuid,
  p_decision approval_status
) returns void
language plpgsql security definer set search_path = public as $$
declare
  a public.approvals;
  sf public.seat_funding;
begin
  if p_decision not in ('approved', 'declined') then
    raise exception 'decision must be approved or declined';
  end if;

  select * into a from public.approvals where id = p_approval for update;
  if not found then raise exception 'approval not found'; end if;
  if not public.can_spend(a.company_id) then
    raise exception 'only an owner, admin or finance user can decide approvals'
      using errcode = '42501';
  end if;
  if a.status <> 'pending' then raise exception 'approval already %', a.status; end if;

  select * into sf from public.seat_funding where ride_id = a.ride_id for update;
  if not found then raise exception 'seat funding not found'; end if;

  if p_decision = 'declined' and sf.status = 'held' and sf.company_credits > 0 then
    insert into public.credit_ledger
      (company_id, kind, from_kind, from_ride_id, to_kind, to_user_id, credits, ref, memo)
    values
      (sf.company_id, 'release', 'seat', sf.ride_id, 'employee_wallet', sf.rider_id,
       sf.company_credits, 'APPROVAL-DECLINED-' || a.id::text, 'Company funding declined');

    update public.seat_funding
       set source = 'personal',
           personal_cents = personal_cents + company_credits * 100,
           company_credits = 0,
           pretax_credits = 0
     where ride_id = sf.ride_id;
  end if;

  update public.approvals
     set status = p_decision, decided_by = auth.uid(), decided_at = now()
   where id = p_approval;

  perform public.audit(
    a.company_id,
    'approval.' || p_decision::text,
    a.id::text,
    jsonb_build_object('ride_id', a.ride_id)
  );
end $$;

revoke all on function public.decide_company_approval(uuid, approval_status) from public;
grant execute on function public.decide_company_approval(uuid, approval_status) to authenticated;
