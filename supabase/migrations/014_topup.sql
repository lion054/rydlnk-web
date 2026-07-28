-- ════════════════════════════════════════════════════════════════════════════
-- Rydlnk — 014: funding the float
--
-- Run after 013. Safe to re-run.
--
-- Why this is a function and not an insert.
--   `credit_ledger` and `float_topups` carry SELECT policies only — there is no
--   INSERT policy on either, on purpose. A client that can write to the ledger
--   can mint credits. So every write goes through a SECURITY DEFINER function
--   that re-checks the caller's role in the database, which is the same rule
--   allocate_credits() already follows.
-- ════════════════════════════════════════════════════════════════════════════

/**
 * Add credits to a company's float.
 *
 * `p_stripe_pi` is the Stripe PaymentIntent id once payments are wired. Until
 * then it is null and the entry is memoed as manual, so a balance that appeared
 * without money moving is visible in the ledger rather than indistinguishable
 * from a real charge.
 */
create or replace function public.topup_float(
  p_company    uuid,
  p_credits    int,
  p_stripe_pi  text default null,
  p_auto       boolean default false
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_topup uuid; v_ref text;
begin
  if not public.can_spend(p_company) then
    raise exception 'only an owner, admin or finance user can fund the float'
      using errcode = '42501';
  end if;
  if p_credits is null or p_credits <= 0 then
    raise exception 'credits must be positive';
  end if;

  insert into public.float_topups
    (company_id, credits, amount_cents, status, stripe_payment_intent_id, auto, requested_by, settled_at)
  values
    (p_company, p_credits, p_credits * 100,
     case when p_stripe_pi is null then 'succeeded' else 'pending' end,
     p_stripe_pi, coalesce(p_auto, false), auth.uid(),
     case when p_stripe_pi is null then now() else null end)
  returning id into v_topup;

  v_ref := 'TOPUP-' || left(v_topup::text, 8);

  -- Only credit the float once money is actually settled. With Stripe wired,
  -- the webhook posts this entry after payment_intent.succeeded instead.
  if p_stripe_pi is null then
    insert into public.credit_ledger
      (company_id, kind, from_kind, to_kind, credits, ref, memo, created_by)
    values
      (p_company, 'topup', 'external', 'company_float', p_credits, v_ref,
       'Manual top-up — no card charged', auth.uid());
  end if;

  perform public.audit(p_company, 'float.topup', v_ref,
                       jsonb_build_object('credits', p_credits, 'stripe', p_stripe_pi));
  return v_topup;
end $$;

grant execute on function public.topup_float(uuid, int, text, boolean) to authenticated;

/**
 * Settle a Stripe-backed top-up. Called by the webhook on the service role,
 * which is why it takes the PaymentIntent rather than trusting a client.
 */
create or replace function public.settle_topup(p_stripe_pi text)
returns void
language plpgsql security definer set search_path = public as $$
declare t public.float_topups;
begin
  select * into t from public.float_topups
  where stripe_payment_intent_id = p_stripe_pi for update;
  if not found or t.status = 'succeeded' then return; end if;

  update public.float_topups
     set status = 'succeeded', settled_at = now()
   where id = t.id;

  insert into public.credit_ledger
    (company_id, kind, from_kind, to_kind, credits, ref, memo)
  values
    (t.company_id, 'topup', 'external', 'company_float', t.credits,
     'TOPUP-' || left(t.id::text, 8), 'Stripe ' || p_stripe_pi);
end $$;

-- ════════════════════════════════════════════════════════════════════════════
-- Done.
-- ════════════════════════════════════════════════════════════════════════════
