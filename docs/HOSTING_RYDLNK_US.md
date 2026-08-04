# Hosting rydlnk.us

Self-hosted on the shared box at `13.247.190.131`, alongside six other sites.
Not Vercel — `DEPLOY.md` describes the Vercel path and still applies if you ever
move back, but nothing in this document depends on it.

## What is running

| | |
|---|---|
| App | Next.js 15 standalone, `node server.js` |
| Process manager | pm2, process name `rydlnk`, as user `ubuntu` |
| Bind address | `127.0.0.1:3002` — loopback only, nginx is the sole route in |
| Web root | `/var/www/rydlnk.us` |
| nginx vhost | `/etc/nginx/sites-available/rydlnk.us` (committed at `deploy/nginx-rydlnk.us.conf`) |
| Reboot | `pm2-ubuntu` systemd unit is enabled and the list is saved |

## Deploying

```bash
./scripts/deploy-to-server.sh              # build, ship, reload, verify
./scripts/deploy-to-server.sh --no-build   # ship the existing .next
./scripts/deploy-to-server.sh --dry-run    # show what would transfer
```

The build runs **locally**, on purpose. The server has 1.9G of RAM and already
runs nginx, MariaDB, Redis, PHP-FPM and two other Node apps; `next build` peaks
above what is free, and an OOM there would take the other six sites down with it.
Only the traced `.next/standalone` output ships — about 123M against the ~760M a
full `node_modules` would need on a volume that is already 76% full.

`pm2 reload` (not `restart`) brings the replacement up before retiring the old
process, so a deploy does not drop in-flight requests.

## The env file that decides your canonical URLs

`.env.production.local` — gitignored, and the `.local` suffix is load-bearing.
Next's precedence is:

```
process.env  >  .env.production.local  >  .env.local  >  .env.production  >  .env
```

`.env.local` is loaded in every environment except test, so a plain
`.env.production` **loses to it**. Named that way, the local
`NEXT_PUBLIC_SITE_URL=http://localhost:3000` beat the production value and got
baked into `metadataBase`, every canonical tag, and the sitemap. Every
`NEXT_PUBLIC_*` value is inlined at build time and is not read at runtime, so the
only fix is another build.

`deploy-to-server.sh` now asserts the rendered sitemap contains `https://rydlnk.us`
and refuses to ship otherwise, which catches that class of error regardless of
cause.

## DNS and TLS cutover — done 2026-07-30

Certificate issued for `rydlnk.us` and `www.rydlnk.us`, expires **2026-10-28**,
auto-renewing via `certbot.timer`. Verified from the public internet:

```
https://rydlnk.us/           HTTP/2 200, server: nginx
http://rydlnk.us/            301 -> https://rydlnk.us/
https://www.rydlnk.us/       200, 0 redirects (no loop through Cloudflare)
https://rydlnk.us/portal     307 -> https://rydlnk.us/signin?next=%2Fportal
```

The auth redirect picked up `https` on its own: nginx passes
`X-Forwarded-Proto: $scheme`, which `proxyAwareRedirect()` reads.

### Current DNS shape

| Name | Resolves to | Cloudflare proxy |
|---|---|---|
| `rydlnk.us` | `13.247.190.131` | off (grey cloud) |
| `www.rydlnk.us` | Cloudflare edge → origin | **on** (orange cloud) |

The split is fine — both reach nginx and neither loops. Worth knowing that they
behave differently: the apex is served straight off the origin, so an origin
outage is immediately visible, while `www` sits behind Cloudflare's cache and can
serve a stale page for a while after the origin goes down.

If you turn the proxy on for the apex too, set SSL/TLS mode to **Full (strict)**.
With a real Let's Encrypt cert on the origin there is no reason to use Flexible,
and Flexible plus the HTTP→HTTPS redirect that certbot just added is the standard
recipe for an infinite redirect loop.

### Re-running certbot

```bash
ssh ubuntu@13.247.190.131 'sudo certbot certificates'
ssh ubuntu@13.247.190.131 'sudo certbot renew --dry-run'
```

Renewal uses HTTP-01 against `/.well-known/acme-challenge/`, which the vhost
routes to `/var/www/html` ahead of the proxy pass. That keeps working with the
Cloudflare proxy on, because Cloudflare forwards the challenge to the origin —
but it breaks if DNS ever stops pointing here, which is exactly how the
`snappyfresh.net` and `avance.co.zw` renewals had been failing every 8 hours.

## Still to do

- [ ] **Supabase redirect allowlist.** Authentication → URL Configuration:
      Site URL `https://rydlnk.us`, and add `https://rydlnk.us/auth/callback` to
      Redirect URLs. Magic links fail silently without it — Supabase refuses to
      redirect to a host it was not told about and the user just lands back on
      the sign-in page.
- [ ] **Deploy the edge functions.** `supabase functions deploy`. Until then the
      portal cannot invite a worker: `send-company-invite` returns 404.
- [ ] **`SITE_ORIGIN`** is already `https://rydlnk.us` in `supabase/.env`, but it
      only reaches the functions once you run
      `supabase secrets set --env-file supabase/.env`.

## Why the middleware does not use `req.nextUrl`

It emitted `Location: http://localhost:3002/signin` — verified against the
origin, and true even on a direct request carrying a correct `Host` header. Next
builds `nextUrl` from the address it bound, not from the request, so every
signed-out visitor would have been redirected to their own machine.

`proxyAwareRedirect()` in `src/middleware.ts` builds the target from
`X-Forwarded-Host` / `X-Forwarded-Proto` instead. Those are trustworthy here
because the app listens on `127.0.0.1` only — nothing reaches it without passing
through nginx, which overwrites both headers.

## Operations

```bash
ssh ubuntu@13.247.190.131 'pm2 status'
ssh ubuntu@13.247.190.131 'pm2 logs rydlnk --lines 50 --nostream'
ssh ubuntu@13.247.190.131 'pm2 reload rydlnk'
ssh ubuntu@13.247.190.131 'sudo tail -50 /var/log/nginx/rydlnk.us.error.log'
```

## Headroom

Tight but workable. After adding this app: **874Mi of 1905Mi available**, disk at
**76%** with 3.5G free. The app itself sits around 31–80M resident.

The next thing to reclaim if you need room is `/var/www/peachpy` (1.6G) or
`/var/lib/snapd` (330M). Each deploy also leaves the previous `.next/standalone`
replaced rather than accumulated, so deploys do not grow the volume over time.

## Known gaps

- **No WebSocket support in the vhost.** The usual `Upgrade`/`Connection` pair
  needs a `map $http_upgrade $connection_upgrade` in the http block, and this box
  has none defined — referencing the variable would fail `nginx -t` and block
  reloads for every site. A production standalone build serves no WebSocket
  traffic, so nothing is broken today. Add the map to `conf.d` first if that
  changes.
- **Edge functions are still not deployed.** Unrelated to hosting, but the portal
  cannot invite a worker until they are. See `docs/GO_LIVE_CHECKLIST.md`.
- **`NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` is the live key**, so top-ups on this
  deployment move real money.
