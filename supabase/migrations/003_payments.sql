-- ════════════════════════════════════════════════════════════════════
-- Rydlnk — Phase 3: payments & weekly billing
-- Run in Supabase → SQL Editor AFTER 002. Safe to re-run.
--
-- Card DATA never lives here — Stripe holds it. We only store references
-- (Stripe customer id, payment-method id, brand/last4 for display).
-- ════════════════════════════════════════════════════════════════════

do $$ begin
  create type billing_status as enum ('open', 'paid', 'failed', 'void');
exception when duplicate_object then null; end $$;

-- One Stripe customer per user.
create table if not exists public.stripe_customers (
  user_id            uuid primary key references auth.users (id) on delete cascade,
  stripe_customer_id text not null unique,
  created_at         timestamptz not null default now()
);

-- Saved cards (display metadata + Stripe reference only).
create table if not exists public.payment_methods (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references auth.users (id) on delete cascade,
  stripe_payment_method_id text not null,
  brand                    text,          -- 'visa', 'mastercard', …
  last4                    text,
  exp_month                int,
  exp_year                 int,
  is_default               boolean not null default false,
  created_at               timestamptz not null default now(),
  unique (user_id, stripe_payment_method_id)
);

-- A weekly bill = the rides in a Mon–Sun window, charged once.
create table if not exists public.billing_cycles (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references auth.users (id) on delete cascade,
  period_start             date not null,
  period_end               date not null,
  amount_cents             int not null default 0,
  ride_count               int not null default 0,
  status                   billing_status not null default 'open',
  stripe_payment_intent_id text,
  created_at               timestamptz not null default now(),
  charged_at               timestamptz,
  unique (user_id, period_start)
);

create index if not exists pm_user_idx on public.payment_methods (user_id);
create index if not exists bc_user_idx on public.billing_cycles (user_id);

-- ── Row Level Security ───────────────────────────────────────────────
alter table public.stripe_customers enable row level security;
alter table public.payment_methods  enable row level security;
alter table public.billing_cycles   enable row level security;

-- Users may READ their own billing data. Writes happen only through Edge
-- Functions using the service role (which bypasses RLS) — never the client,
-- so there are deliberately no INSERT/UPDATE policies here.
drop policy if exists "customers self read" on public.stripe_customers;
create policy "customers self read" on public.stripe_customers
  for select using (auth.uid() = user_id);

drop policy if exists "pm self read"   on public.payment_methods;
create policy "pm self read"   on public.payment_methods
  for select using (auth.uid() = user_id);

-- Let users remove their own saved card (the Edge Function also detaches it
-- from Stripe; this keeps the UI responsive).
drop policy if exists "pm self delete" on public.payment_methods;
create policy "pm self delete" on public.payment_methods
  for delete using (auth.uid() = user_id);

drop policy if exists "billing self read" on public.billing_cycles;
create policy "billing self read" on public.billing_cycles
  for select using (auth.uid() = user_id);
