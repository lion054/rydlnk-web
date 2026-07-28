-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — account settings: self-service deletion + notification prefs.
-- Run in SQL Editor after 011. Safe to re-run.
-- ════════════════════════════════════════════════════════════════════

-- Persisted notification preferences (honoured once push is wired).
alter table public.profiles
  add column if not exists notification_prefs jsonb not null default '{}'::jsonb;

-- Self-service account deletion. Deleting the auth user cascades to profiles,
-- drivers, schedules, rides, documents, acceptances, etc. (all FK on delete
-- cascade). SECURITY DEFINER runs as the function owner, which can delete from
-- auth.users. If your project restricts this, deploy an Edge Function that
-- calls admin.deleteUser instead and point the app at it.
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
