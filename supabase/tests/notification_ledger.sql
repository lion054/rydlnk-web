-- Run with: supabase test db
-- Structural and privilege regression coverage for migration 026.

begin;
create extension if not exists pgtap;
select plan(13);

select ok(to_regclass('public.notification_log') is not null,
  'notification delivery ledger exists');
select ok(to_regprocedure('public.claim_notification(uuid,text,text,interval)') is not null,
  'notification claim RPC exists');
select ok(to_regprocedure('public.finish_notification(uuid,text,text,text[],text)') is not null,
  'notification completion RPC exists');
select ok(to_regprocedure('public.billing_recipients(uuid)') is not null,
  'billing recipient RPC exists');
select ok(to_regprocedure('public.companies_low_float()') is not null,
  'low-float work queue exists');
select ok(to_regprocedure('public.statements_awaiting_notice(interval)') is not null,
  'statement work queue exists');

select ok(not has_table_privilege('anon', 'public.notification_log', 'select'),
  'anonymous users cannot read billing recipients');
select ok(not has_table_privilege('authenticated', 'public.notification_log', 'select'),
  'ordinary users cannot read the notification ledger');
select ok(not has_function_privilege('anon', 'public.claim_notification(uuid,text,text,interval)', 'execute'),
  'anonymous users cannot claim notifications');
select ok(not has_function_privilege('authenticated', 'public.claim_notification(uuid,text,text,interval)', 'execute'),
  'ordinary users cannot claim notifications');
select ok(not has_function_privilege('anon', 'public.billing_recipients(uuid)', 'execute'),
  'anonymous users cannot enumerate billing addresses');
select ok(not has_function_privilege('authenticated', 'public.billing_recipients(uuid)', 'execute'),
  'ordinary users cannot enumerate billing addresses');
select ok(has_function_privilege('service_role', 'public.claim_notification(uuid,text,text,interval)', 'execute'),
  'service role can claim notifications');

select * from finish();
rollback;
