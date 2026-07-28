-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Driver vetting (document capture + review workflow) and legal
-- consent capture. Run in SQL Editor after 010. Safe to re-run.
--
-- What this does NOT do (and cannot): buy insurance, run background checks, or
-- make the legal drafts binding. It provides the SYSTEM to collect, record and
-- enforce those — you still procure the policy/vendor/counsel.
-- ════════════════════════════════════════════════════════════════════

-- ── Enums ───────────────────────────────────────────────────────────
do $$ begin
  create type doc_type as enum
    ('national_id','drivers_license','vehicle_registration','insurance','profile_photo');
exception when duplicate_object then null; end $$;

do $$ begin
  create type doc_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

-- ── Driver verification state ───────────────────────────────────────
alter table public.drivers
  add column if not exists verification_status text not null default 'unverified',
      -- unverified → pending → approved | rejected
  add column if not exists insurance_expiry date;

-- ── Uploaded documents (files live in the private storage bucket) ────
create table if not exists public.driver_documents (
  id           uuid primary key default gen_random_uuid(),
  driver_id    uuid not null references public.drivers (id) on delete cascade,
  doc_type     doc_type not null,
  storage_path text not null,
  status       doc_status not null default 'pending',
  expiry_date  date,
  note         text,                       -- reviewer note on rejection
  created_at   timestamptz not null default now(),
  reviewed_at  timestamptz,
  unique (driver_id, doc_type)
);
create index if not exists driver_docs_driver_idx on public.driver_documents (driver_id);

alter table public.driver_documents enable row level security;

drop policy if exists "docs self read"  on public.driver_documents;
create policy "docs self read"  on public.driver_documents
  for select using (driver_id = auth.uid());

drop policy if exists "docs self write" on public.driver_documents;
create policy "docs self write" on public.driver_documents
  for insert with check (driver_id = auth.uid());

drop policy if exists "docs self update" on public.driver_documents;
create policy "docs self update" on public.driver_documents
  for update using (driver_id = auth.uid()) with check (driver_id = auth.uid());
-- (reviewers approve/reject via the service role, which bypasses RLS)

-- ── Private storage bucket for the files ────────────────────────────
insert into storage.buckets (id, name, public)
values ('driver-docs', 'driver-docs', false)
on conflict (id) do nothing;

-- Each driver can only touch files under a folder named their own uid.
drop policy if exists "driver docs read own"  on storage.objects;
create policy "driver docs read own"  on storage.objects
  for select using (bucket_id = 'driver-docs'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "driver docs write own" on storage.objects;
create policy "driver docs write own" on storage.objects
  for insert with check (bucket_id = 'driver-docs'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "driver docs update own" on storage.objects;
create policy "driver docs update own" on storage.objects
  for update using (bucket_id = 'driver-docs'
    and (storage.foldername(name))[1] = auth.uid()::text);

-- ── Submit for review: requires the mandatory docs on file ──────────
create or replace function public.request_verification()
returns void
language plpgsql security definer set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_have int;
begin
  if not exists (select 1 from public.drivers where id = v_uid) then
    raise exception 'not a driver';
  end if;

  select count(distinct doc_type) into v_have
  from public.driver_documents
  where driver_id = v_uid
    and doc_type in ('national_id','drivers_license','vehicle_registration','insurance');

  if v_have < 4 then
    raise exception 'upload your ID, licence, vehicle registration and insurance first';
  end if;

  update public.drivers set verification_status = 'pending' where id = v_uid;
  -- carry the insurance expiry onto the driver for enforcement/reminders
  update public.drivers d
    set insurance_expiry = (select expiry_date from public.driver_documents
                            where driver_id = v_uid and doc_type = 'insurance')
    where d.id = v_uid;
end $$;

grant execute on function public.request_verification() to authenticated;

-- Ops approve/reject helper (call with the service role from an admin tool):
--   update drivers set verified=true, verification_status='approved' where id=…;
-- claim_trip already gates on verified=true (migration 008).

-- ── Legal consent capture ───────────────────────────────────────────
create table if not exists public.legal_acceptances (
  user_id     uuid not null references auth.users (id) on delete cascade,
  doc_type    text not null,   -- terms | privacy | rider_agreement | driver_agreement
  version     text not null,
  accepted_at timestamptz not null default now(),
  primary key (user_id, doc_type, version)
);

alter table public.legal_acceptances enable row level security;

drop policy if exists "acceptances self read"  on public.legal_acceptances;
create policy "acceptances self read"  on public.legal_acceptances
  for select using (user_id = auth.uid());

drop policy if exists "acceptances self write" on public.legal_acceptances;
create policy "acceptances self write" on public.legal_acceptances
  for insert with check (user_id = auth.uid());
