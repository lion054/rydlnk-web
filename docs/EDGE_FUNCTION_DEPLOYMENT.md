# Edge Function deployment

The repository contains eleven functions: the ten original application
functions plus `billing-notify`.

## Preflight

```bash
npm run check:functions
npm run typecheck:scripts
npx deno check supabase/functions/**/*.ts
./scripts/verify-production.sh
```

The last command is read-only. Before deployment it should report missing Edge
Functions; after migrations 025–026 it must report that privileged RPCs are not
exposed to the anonymous role.

## Deploy

```bash
supabase login
supabase link --project-ref zpduvchwzoxkzfjuqlww
supabase db push
supabase functions deploy --project-ref zpduvchwzoxkzfjuqlww
```

The per-function JWT policy lives in `supabase/config.toml`. Stripe, HRIS,
health, and billing scheduler endpoints disable gateway JWT verification
because they validate their own signature or private header.

Set the secrets listed in `DEPLOY.md` before exercising a function. Supabase
provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` automatically.

## Post-deploy

```bash
./scripts/verify-production.sh
```

Then:

1. Send a Stripe test-mode top-up and confirm exactly one receipt.
2. Replay the Stripe event and confirm no second receipt.
3. Call `billing-notify?dry=1` with `x-billing-secret`.
4. Run it normally and confirm statement/low-balance counts.
5. Repeat the normal call and confirm the messages are skipped.
6. Call `/health` with and without its secret and verify 200/401 behavior.

