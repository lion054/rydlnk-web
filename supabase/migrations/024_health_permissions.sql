-- Rydlnk — 024: close inherited health-function execution privileges
--
-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Explicitly
-- revoke browser roles too in case an earlier environment granted them.

revoke all on function public.financial_health_snapshot()
  from public, anon, authenticated;
revoke all on function public.record_health_snapshot()
  from public, anon, authenticated;
revoke all on function public.retry_stuck_stripe_events()
  from public, anon, authenticated;

grant execute on function public.financial_health_snapshot(),
  public.record_health_snapshot(),
  public.retry_stuck_stripe_events()
  to service_role;

