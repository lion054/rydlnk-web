-- ════════════════════════════════════════════════════════════════════════════
-- Rydlnk — 017: Stripe delivery ledger and prepaid company statements
--
-- Run after 016. Safe to re-run.
--
-- Stripe funds the company float. Statements reconcile consumption against
-- that prepaid balance; they do not charge the company for the same seats a
-- second time.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Durable Stripe webhook delivery ledger ──────────────────────────────────

create table if not exists public.stripe_webhook_events (
  event_id       text primary key,
  event_type     text not null,
  status         text not null check (status in ('processing', 'processed', 'failed')),
  attempts       int not null default 1,
  last_error     text,
  received_at    timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  processed_at   timestamptz
);

alter table public.stripe_webhook_events enable row level security;
revoke all on public.stripe_webhook_events from public, anon, authenticated;

create or replace function public.claim_stripe_event(p_event_id text, p_event_type text)
returns boolean
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into public.stripe_webhook_events (event_id, event_type, status)
  values (p_event_id, p_event_type, 'processing')
  on conflict (event_id) do update
    set status = 'processing',
        attempts = public.stripe_webhook_events.attempts + 1,
        last_error = null,
        updated_at = now()
    where public.stripe_webhook_events.status = 'failed'
       or (
         public.stripe_webhook_events.status = 'processing'
         and public.stripe_webhook_events.updated_at < now() - interval '10 minutes'
       );

  get diagnostics n = row_count;
  return n = 1;
end $$;

create or replace function public.finish_stripe_event(
  p_event_id text,
  p_error text default null
) returns void
language sql security definer set search_path = public as $$
  update public.stripe_webhook_events
     set status = case when p_error is null then 'processed' else 'failed' end,
         last_error = p_error,
         updated_at = now(),
         processed_at = case when p_error is null then now() else processed_at end
   where event_id = p_event_id;
$$;

revoke all on function public.claim_stripe_event(text, text) from public;
revoke all on function public.finish_stripe_event(text, text) from public;
grant execute on function public.claim_stripe_event(text, text) to service_role;
grant execute on function public.finish_stripe_event(text, text) to service_role;

-- ── Prepaid company statement generation ────────────────────────────────────

alter table public.company_invoices
  add column if not exists currency text not null default 'usd',
  add column if not exists document_kind text not null default 'prepaid_statement',
  add column if not exists generated_at timestamptz;

create unique index if not exists company_invoice_lines_one_ride
  on public.company_invoice_lines (ride_id)
  where ride_id is not null;

create or replace function public.generate_company_statements(
  p_period_start date,
  p_period_end date,
  p_currency text default 'usd'
) returns table (invoice_id uuid, company_id uuid, seats int, credits int)
language plpgsql security definer set search_path = public as $$
declare c record; v_invoice uuid; v_seats int; v_credits int;
begin
  if p_period_start is null or p_period_end is null or p_period_end < p_period_start then
    raise exception 'invalid statement period';
  end if;

  for c in
    select distinct sf.company_id
    from public.seat_funding sf
    where sf.company_id is not null
      and sf.status in ('settled', 'no_show')
      and sf.settled_at >= p_period_start::timestamptz
      and sf.settled_at < (p_period_end + 1)::timestamptz
  loop
    select count(*)::int, coalesce(sum(sf.company_credits), 0)::int
      into v_seats, v_credits
    from public.seat_funding sf
    where sf.company_id = c.company_id
      and sf.status in ('settled', 'no_show')
      and sf.settled_at >= p_period_start::timestamptz
      and sf.settled_at < (p_period_end + 1)::timestamptz;

    insert into public.company_invoices
      (company_id, number, period_start, period_end, seat_credits, total_cents,
       status, currency, document_kind, issued_at, paid_at, generated_at)
    values
      (c.company_id,
       'RYD-' || to_char(p_period_start, 'YYYYMM') || '-' || upper(left(c.company_id::text, 8)),
       p_period_start, p_period_end, v_credits, v_credits * 100,
       'paid', lower(p_currency), 'prepaid_statement', now(), now(), now())
    on conflict (company_id, period_start) do update
      set period_end = excluded.period_end,
          seat_credits = excluded.seat_credits,
          total_cents = excluded.total_cents,
          currency = excluded.currency,
          document_kind = excluded.document_kind,
          generated_at = now()
    returning id into v_invoice;

    insert into public.company_invoice_lines
      (invoice_id, cost_center_id, description, seats, credits, amount_cents, ride_id)
    select
      v_invoice,
      sf.cost_center_id,
      'Funded seat ' || r.ride_date::text || ' · ' || r.pickup || ' → ' || r.dropoff,
      1,
      sf.company_credits,
      sf.company_credits * 100,
      sf.ride_id
    from public.seat_funding sf
    join public.rides r on r.id = sf.ride_id
    where sf.company_id = c.company_id
      and sf.status in ('settled', 'no_show')
      and sf.settled_at >= p_period_start::timestamptz
      and sf.settled_at < (p_period_end + 1)::timestamptz
    on conflict (ride_id) where ride_id is not null do update
      set invoice_id = excluded.invoice_id,
          cost_center_id = excluded.cost_center_id,
          description = excluded.description,
          credits = excluded.credits,
          amount_cents = excluded.amount_cents;

    perform public.audit(
      c.company_id,
      'statement.generated',
      v_invoice::text,
      jsonb_build_object('period_start', p_period_start, 'period_end', p_period_end,
                         'seats', v_seats, 'credits', v_credits)
    );

    invoice_id := v_invoice;
    company_id := c.company_id;
    seats := v_seats;
    credits := v_credits;
    return next;
  end loop;
end $$;

revoke all on function public.generate_company_statements(date, date, text) from public;
grant execute on function public.generate_company_statements(date, date, text) to service_role;

-- Generate the previous calendar month's statements on the first day.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'rydlnk-company-statements') then
      perform cron.unschedule('rydlnk-company-statements');
    end if;
    perform cron.schedule(
      'rydlnk-company-statements',
      '20 4 1 * *',
      $cron$
        select public.generate_company_statements(
          (date_trunc('month', current_date) - interval '1 month')::date,
          (date_trunc('month', current_date) - interval '1 day')::date,
          'usd'
        )
      $cron$
    );
  else
    raise notice 'pg_cron unavailable — schedule generate_company_statements externally';
  end if;
exception when others then
  raise notice 'company statement schedule not installed: %', sqlerrm;
end $$;

