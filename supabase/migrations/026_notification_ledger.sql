-- Rydlnk — 026: delivery ledger for lifecycle email
--
-- The three lifecycle emails (top-up receipt, statement ready, low float) are
-- all driven by polling state rather than by a single event, so without a
-- record of what has been sent the low-float job would mail every billing
-- contact on every run for as long as the balance stayed low.
--
-- The ledger is claim-then-send, the same shape as stripe_webhook_events in
-- 017: the row is inserted *before* the send is attempted, and a unique index
-- makes a second claim fail rather than duplicate. Two workers racing, or one
-- retried after a timeout, produce one email.
--
-- The trade-off is deliberate. If a send fails after the claim, that
-- notification is skipped rather than retried — for these three, a missed
-- reminder is a smaller harm than mailing a finance team a duplicate receipt.
-- claim_notification() takes a `p_retry_after` for the caller that disagrees.

create table if not exists public.notification_log (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies (id) on delete cascade,
  kind         text not null check (kind in ('topup_receipt', 'statement_ready', 'low_balance')),
  -- What the notification is *about*: a top-up id, an invoice id, or for the
  -- recurring low-float warning, the period it covers. Two notifications of the
  -- same kind about the same subject are the same notification.
  ref          text not null,
  recipients   text[] not null default '{}',
  status       text not null default 'claimed' check (status in ('claimed', 'sent', 'failed')),
  error        text,
  claimed_at   timestamptz not null default now(),
  sent_at      timestamptz
);

create unique index if not exists notification_log_once
  on public.notification_log (company_id, kind, ref);

create index if not exists notification_log_company_idx
  on public.notification_log (company_id, claimed_at desc);

-- Contains billing email addresses. No browser role has any business here.
alter table public.notification_log enable row level security;
revoke all on public.notification_log from public, anon, authenticated;

-- ── Claim ───────────────────────────────────────────────────────────────────

/**
 * Reserve the right to send one notification.
 *
 * Returns true if the caller now owns it, false if it has already been sent or
 * is being sent. `p_retry_after` reopens a claim that is older than the given
 * interval and did not reach 'sent', so a caller that crashed mid-send is not
 * blocked forever; leave it null to never retry.
 */
create or replace function public.claim_notification(
  p_company uuid,
  p_kind text,
  p_ref text,
  p_retry_after interval default null
) returns boolean
language plpgsql security definer set search_path = public as $$
declare v_existing public.notification_log;
begin
  select * into v_existing from public.notification_log
   where company_id = p_company and kind = p_kind and ref = p_ref
   for update;

  if found then
    if v_existing.status = 'sent' then return false; end if;

    -- A stale claim is one that never reached 'sent'. Reopening it is the only
    -- way a crashed worker's notification ever goes out.
    if p_retry_after is not null and v_existing.claimed_at < now() - p_retry_after then
      update public.notification_log
         set status = 'claimed', claimed_at = now(), error = null
       where id = v_existing.id;
      return true;
    end if;

    return false;
  end if;

  insert into public.notification_log (company_id, kind, ref)
  values (p_company, p_kind, p_ref);
  return true;

exception when unique_violation then
  -- Another worker claimed it between the select and the insert.
  return false;
end $$;

/** Record the outcome of a claimed notification. */
create or replace function public.finish_notification(
  p_company uuid,
  p_kind text,
  p_ref text,
  p_recipients text[] default '{}',
  p_error text default null
) returns void
language sql security definer set search_path = public as $$
  update public.notification_log
     set status     = case when p_error is null then 'sent' else 'failed' end,
         recipients = p_recipients,
         error      = left(p_error, 2000),
         sent_at    = case when p_error is null then now() else null end
   where company_id = p_company and kind = p_kind and ref = p_ref;
$$;

-- ── Who gets billing mail ───────────────────────────────────────────────────

/**
 * Billing recipients for a company: every active owner, admin and finance user,
 * plus the company's billing_email.
 *
 * Reads auth.users, so this must never be reachable from a browser role — an
 * arbitrary company id would otherwise enumerate staff addresses.
 */
create or replace function public.billing_recipients(p_company uuid)
returns text[]
language sql security definer set search_path = public as $$
  select coalesce(array_agg(distinct email), '{}')
  from (
    select lower(u.email) as email
    from public.company_members m
    join auth.users u on u.id = m.user_id
    where m.company_id = p_company
      and m.status = 'active'
      and m.role in ('owner', 'admin', 'finance')
      and u.email is not null
    union
    select lower(c.billing_email)
    from public.companies c
    where c.id = p_company and c.billing_email is not null
  ) s;
$$;

-- ── Work queues for billing-notify ──────────────────────────────────────────

/**
 * Companies whose float has fallen to or below their configured threshold.
 *
 * Companies with no autotopup_rules row still qualify, at the table's default
 * threshold — a company that never configured a threshold is exactly the one
 * most likely to be surprised by an empty float.
 */
create or replace function public.companies_low_float()
returns table (
  company_id uuid, company_name text, credits int,
  threshold int, auto_enabled boolean
)
language sql security definer set search_path = public as $$
  select c.id, c.name, coalesce(b.credits, 0)::int,
         coalesce(r.threshold_credits, 500)::int,
         coalesce(r.enabled, false)
  from public.companies c
  left join public.company_float_balance b on b.company_id = c.id
  left join public.autotopup_rules r on r.company_id = c.id
  where c.suspended_at is null
    and coalesce(b.credits, 0) <= coalesce(r.threshold_credits, 500)
    -- A company that has never funded anything is not "running low", it has
    -- not started. Mailing it a warning on day one reads as a dunning notice.
    and exists (
      select 1 from public.credit_ledger l
      where l.company_id = c.id and l.to_kind = 'company_float'
    );
$$;

/** Statements generated but not yet announced. Paired with notification_log. */
create or replace function public.statements_awaiting_notice(p_since interval default '7 days')
returns table (
  invoice_id uuid, company_id uuid, company_name text, number text,
  period_start date, period_end date, seats int, credits int
)
language sql security definer set search_path = public as $$
  select i.id, i.company_id, c.name, i.number,
         i.period_start, i.period_end,
         (select count(*)::int from public.company_invoice_lines l where l.invoice_id = i.id),
         i.seat_credits
  from public.company_invoices i
  join public.companies c on c.id = i.company_id
  where i.generated_at is not null
    and i.generated_at > now() - p_since
    and c.suspended_at is null
    and not exists (
      select 1 from public.notification_log n
      where n.company_id = i.company_id
        and n.kind = 'statement_ready'
        and n.ref = i.id::text
        and n.status = 'sent'
    );
$$;

-- ── Grants ──────────────────────────────────────────────────────────────────
-- All five are backend-only and none has an internal caller check, so the grant
-- is the whole control. Written out per 025's convention: revoke from every
-- browser role explicitly, never from `public` alone.

do $$
declare sig text;
begin
  for sig in
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('claim_notification', 'finish_notification', 'billing_recipients',
                        'companies_low_float', 'statements_awaiting_notice')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', sig);
    execute format('grant execute on function %s to service_role', sig);
  end loop;
end $$;
