-- Rydlnk — 022: production financial health and reconciliation
-- Run after 021. Safe to re-run.

create table if not exists public.health_snapshots (
  id bigint generated always as identity primary key,
  status text not null check (status in ('healthy', 'warning', 'critical')),
  checks jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.health_snapshots enable row level security;
revoke all on public.health_snapshots from public, anon, authenticated;

create or replace function public.financial_health_snapshot()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_failed_events int;
  v_stuck_events int;
  v_stale_topups int;
  v_unbacked_topups int;
  v_negative_wallets int;
  v_negative_floats int;
  v_unsettled_ledger int;
  v_statement_mismatches int;
  v_status text;
begin
  select count(*) into v_failed_events from public.stripe_webhook_events where status = 'failed';
  select count(*) into v_stuck_events from public.stripe_webhook_events
    where status = 'processing' and updated_at < now() - interval '10 minutes';
  select count(*) into v_stale_topups from public.float_topups
    where status = 'pending' and created_at < now() - interval '3 days';
  select count(*) into v_unbacked_topups
    from public.float_topups t
    where t.status = 'succeeded' and not exists (
      select 1 from public.credit_ledger l
      where l.company_id = t.company_id and l.ref = 'TOPUP-' || left(t.id::text, 8)
    );
  select count(*) into v_negative_wallets from public.employee_wallet_balance where credits < 0;
  select count(*) into v_negative_floats from public.company_float_balance where credits < 0;
  select count(*) into v_unsettled_ledger
    from public.seat_funding sf
    where sf.status = 'settled' and sf.company_credits > 0 and not exists (
      select 1 from public.credit_ledger l
      where l.company_id = sf.company_id and (
        (l.ref = 'SETTLE-' || sf.ride_id::text and l.from_kind = 'seat')
        or (l.to_ride_id = sf.ride_id and l.kind = 'consumption')
      )
    );
  select count(*) into v_statement_mismatches
    from public.company_invoices i
    where i.generated_at is not null and (
      i.total_cents <> coalesce((select sum(l.amount_cents) from public.company_invoice_lines l where l.invoice_id = i.id), 0)
      or i.seat_credits <> coalesce((select sum(l.credits) from public.company_invoice_lines l where l.invoice_id = i.id), 0)
    );

  v_status := case
    when v_unbacked_topups + v_negative_wallets + v_negative_floats + v_unsettled_ledger + v_statement_mismatches > 0
      then 'critical'
    when v_failed_events + v_stuck_events + v_stale_topups > 0 then 'warning'
    else 'healthy'
  end;

  return jsonb_build_object(
    'status', v_status,
    'checked_at', now(),
    'checks', jsonb_build_object(
      'failed_webhook_events', v_failed_events,
      'stuck_webhook_events', v_stuck_events,
      'stale_pending_topups', v_stale_topups,
      'succeeded_topups_without_ledger', v_unbacked_topups,
      'negative_employee_wallets', v_negative_wallets,
      'negative_company_floats', v_negative_floats,
      'settled_seats_without_consumption', v_unsettled_ledger,
      'statement_total_mismatches', v_statement_mismatches
    )
  );
end $$;

create or replace function public.record_health_snapshot()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  v := public.financial_health_snapshot();
  insert into public.health_snapshots(status, checks)
  values(v->>'status', v->'checks');
  delete from public.health_snapshots where created_at < now() - interval '90 days';
  return v;
end $$;

create or replace function public.operator_health()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_operator() then
    raise exception 'platform operator access required' using errcode = '42501';
  end if;
  return public.financial_health_snapshot();
end $$;

create or replace function public.retry_stuck_stripe_events()
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update public.stripe_webhook_events
     set status = 'failed', last_error = 'processing lease expired', updated_at = now()
   where status = 'processing' and updated_at < now() - interval '10 minutes';
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.financial_health_snapshot() from public;
revoke all on function public.record_health_snapshot() from public;
revoke all on function public.operator_health() from public;
revoke all on function public.retry_stuck_stripe_events() from public;
grant execute on function public.financial_health_snapshot(), public.record_health_snapshot(),
  public.retry_stuck_stripe_events() to service_role;
grant execute on function public.operator_health() to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'rydlnk-health-snapshot') then
      perform cron.unschedule('rydlnk-health-snapshot');
    end if;
    perform cron.schedule('rydlnk-health-snapshot', '*/15 * * * *',
      $cron$select public.record_health_snapshot(); select public.retry_stuck_stripe_events();$cron$);
  else
    raise notice 'pg_cron unavailable — schedule record_health_snapshot externally';
  end if;
exception when others then
  raise notice 'health schedule not installed: %', sqlerrm;
end $$;

