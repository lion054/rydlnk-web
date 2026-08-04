-- Rydlnk — 018: safe invite landing-page resolution
-- Run after 017. Safe to re-run.

create or replace function public.company_invite_preview(p_token text)
returns table (
  company_name text,
  invited_email text,
  invited_role company_role,
  department text,
  expires_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select c.name, i.email, i.role, i.department, i.expires_at
  from public.company_invites i
  join public.companies c on c.id = i.company_id
  where i.token_hash = encode(sha256(p_token::bytea), 'hex')
    and i.status = 'pending'
    and i.expires_at >= now()
    and c.suspended_at is null
  limit 1;
$$;

revoke all on function public.company_invite_preview(text) from public;
grant execute on function public.company_invite_preview(text) to anon, authenticated;

