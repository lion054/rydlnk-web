# Deploying

Next.js 15 App Router on Vercel, Supabase for data and auth. Nothing here needs
a custom server or a Docker image.

## 1. Push to GitHub

```bash
git remote add origin git@github.com:<you>/rydlnk-web.git
git branch -M main
git push -u origin main
```

`.env.local` is gitignored — check `git status` shows no `.env` file before the
first push.

## 2. Import to Vercel

New Project → import the repo. Framework preset detects Next.js; leave the build
and output settings alone.

## 3. Environment variables

Project → Settings → Environment Variables:

| Name | Value | Environments |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://zpduvchwzoxkzfjuqlww.supabase.co` | all |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `sb_publishable_…` | all |
| `NEXT_PUBLIC_SITE_URL` | `https://your-domain.com` | **production only** |

Leave `NEXT_PUBLIC_SITE_URL` unset on preview and development. The code falls
back to `VERCEL_URL`, so a preview deployment emails sign-in links that point at
*itself* rather than at production.

All three are `NEXT_PUBLIC_` and end up in the browser bundle. That is correct:
the Supabase anon key is publishable and every table it can reach is protected
by Row Level Security. **The `service_role` key must never appear here** — it
bypasses RLS entirely and belongs only in Edge Function secrets.

## 4. Supabase auth redirect allowlist — do not skip this

Authentication → URL Configuration:

- **Site URL**: `https://your-domain.com`
- **Redirect URLs**, one per line:
  ```
  https://your-domain.com/auth/callback
  https://*-<your-vercel-scope>.vercel.app/auth/callback
  http://localhost:3000/auth/callback
  ```

Without the wildcard entry, magic links from preview deployments silently fail —
Supabase refuses to redirect to a host it hasn't been told about, and the user
just lands back on the sign-in page with no explanation.

## 5. Edge functions and cron

These live in the Flutter repo (`supabase/functions`) and deploy separately —
Vercel does not host them.

```bash
supabase functions deploy company-topup
supabase functions deploy hris-offboard --no-verify-jwt
supabase functions deploy stripe-webhook --no-verify-jwt
supabase functions deploy charge-weekly

supabase secrets set STRIPE_SECRET_KEY=sk_… STRIPE_WEBHOOK_SECRET=whsec_…
supabase secrets set HRIS_WEBHOOK_SECRET=… SITE_ORIGIN=https://your-domain.com
```

Then add the `stripe-webhook` function URL as an endpoint in the Stripe
dashboard, subscribed to `setup_intent.succeeded`, `payment_intent.succeeded`,
`payment_intent.payment_failed` and `payment_intent.processing`.

## Before it is genuinely public

These are content and licensing decisions, not code:

1. **`/customers` contains invented figures.** It is marked in the file. A trust
   page with fabricated results is worse than no trust page — replace every
   number with a signed-off customer reference or take the page down.
2. **`/legal/*` are drafts** carrying a visible "pending legal review" banner.
   They exist so the footer links resolve. Have counsel sign them off against
   the Utah Consumer Privacy Act before removing the banner.
3. **OpenStreetMap tiles.** `CorridorMap` fetches directly from
   `tile.openstreetmap.org`. That is fine at low volume and the attribution is
   in place, but OSM's tile usage policy rules out heavy use — move to a paid
   tile host (MapTiler, Stadia, Protomaps) before real traffic.
4. **Photography is Unsplash stock**, used for atmosphere only and never
   presented as Rydlnk's own riders or vehicles. Commissioned photos of the real
   corridors would be the single biggest credibility upgrade.
5. **`contact.phone` and the store URLs in `src/lib/site.ts` are placeholders**,
   marked `PLACEHOLDER`. Grep that file, not the tree.

## Cost note

Middleware runs `supabase.auth.getUser()` on every matched route, which is a
network call to Supabase. It is scoped to `/portal`, `/signin`,
`/business/get-started` and `/invite` — deliberately not the marketing pages,
which stay static and cost nothing to serve.
