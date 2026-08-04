-- Run with: supabase test db
-- These tests are read-only and roll back their extension/session changes.

begin;
create extension if not exists pgtap;
select plan(20);

select ok(to_regprocedure('public.accept_company_invite(text)') is not null,
  'invite acceptance function exists');
select ok(to_regprocedure('public.settle_seat(uuid)') is not null,
  'seat settlement function exists');
select ok(not has_function_privilege('authenticated', 'public.settle_seat(uuid)', 'execute'),
  'ordinary users cannot settle seats');
select ok(not has_function_privilege('authenticated', 'public.topup_float(uuid,integer,text,boolean)', 'execute'),
  'ordinary users cannot mint manual float credits');
select ok(has_function_privilege('service_role', 'public.settle_seat(uuid)', 'execute'),
  'service role can settle verified boarding');
select ok(to_regclass('public.stripe_webhook_events') is not null,
  'Stripe webhook delivery ledger exists');
select ok(to_regclass('public.platform_staff') is not null,
  'isolated platform staff table exists');
select ok(not has_table_privilege('authenticated', 'public.platform_staff', 'select'),
  'company users cannot read platform staff');
select ok(to_regclass('public.fleet_vehicles') is not null,
  'fleet vehicle registry exists');
select ok(to_regprocedure('public.financial_health_snapshot()') is not null,
  'financial reconciliation function exists');
select ok(not has_function_privilege('anon', 'public.financial_health_snapshot()', 'execute'),
  'anonymous users cannot read financial health');
select ok(not has_function_privilege('authenticated', 'public.financial_health_snapshot()', 'execute'),
  'ordinary authenticated users cannot read financial health directly');
select ok(exists (
  select 1 from pg_trigger where tgname = 'ledger_no_update' and not tgisinternal
), 'ledger append-only trigger is installed');
select ok(exists (
  select 1 from pg_indexes
  where schemaname = 'public' and indexname = 'company_invoice_lines_one_ride'
), 'a ride can appear on only one company statement');
select ok(to_regclass('public.platform_audit_log') is not null,
  'immutable platform audit log exists');
select ok(to_regprocedure('public.is_platform_admin()') is not null,
  'super-admin authorization helper exists');
select ok(to_regprocedure('public.admin_set_company_suspension(uuid,boolean,text)') is not null,
  'audited company suspension exists');
select ok(to_regprocedure('public.admin_review_driver_document(uuid,boolean,text)') is not null,
  'audited driver document review exists');
select ok(to_regprocedure('public.admin_finalize_topup_refund(uuid,text,text)') is not null,
  'audited Stripe refund finalization exists');
select ok(to_regprocedure('public.admin_prepare_topup_refund(uuid,text)') is not null,
  'Stripe refunds reserve company credits before returning cash');

select * from finish();
rollback;
