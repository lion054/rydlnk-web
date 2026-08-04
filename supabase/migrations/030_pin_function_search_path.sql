-- Rydlnk — 030: pin search_path on the last six functions that lacked it
--
-- Flagged by Supabase's security advisor as function_search_path_mutable. Every
-- other function in this schema already sets search_path at definition time;
-- these six were missed.
--
-- Why it matters for a SECURITY DEFINER function: without a pinned search_path
-- the function resolves unqualified names using the *caller's* search_path. A
-- caller who can create objects in a schema that sorts earlier can shadow a
-- table or operator the function relies on, and the body then runs against the
-- attacker's object with the definer's privileges.
--
-- Two of these are the append-only triggers on credit_ledger and
-- platform_audit_log — the controls that make the money ledger and the admin
-- audit trail immutable. They are the last functions that should be shadowable.
--
-- `public, pg_temp` matches the convention used by the rest of the codebase.
-- pg_temp is listed last explicitly: if it is left implicit it sits FIRST in the
-- effective path, which is the shadowing vector this is meant to close.

do $$
declare
  sig text;
  targets text[] := array[
    'generate_rides_for_schedule',   -- called by create_schedule and by 028's shifts
    'create_schedule',               -- rider-facing, from the mobile app
    'sync_site_geo',                 -- trigger: keeps company_sites.geo in step
    'ledger_is_append_only',         -- trigger: credit_ledger immutability
    'guard_profile_company_id',      -- trigger: stops a profile changing company
    'platform_audit_is_append_only'  -- trigger: platform_audit_log immutability
  ];
  t text;
  found int;
begin
  foreach t in array targets loop
    found := 0;
    for sig in
      select p.oid::regprocedure::text
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = t
    loop
      execute format('alter function %s set search_path = public, pg_temp', sig);
      found := found + 1;
    end loop;
    if found = 0 then
      raise notice '030: public.% not present, skipped', t;
    end if;
  end loop;
end $$;
