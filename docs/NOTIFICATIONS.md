# Notifications

Every email Rydlnk sends — auth included — renders through one design system and
goes out through Resend from `rydlnk.us`.

## Why auth email needed rebuilding

Sign-in mail was arriving as:

```
From:    Supabase Auth <noreply@mail.app.supabase.io>
Subject: Your sign-in link
Body:    Follow the link below to sign in.  [Sign in]
Footer:  You're receiving this email because you signed up for an application
         powered by Supabase ⚡   ·   Opt out of these emails
```

That could not be fixed by editing templates. Supabase's built-in mailer:

- sends as `noreply@mail.app.supabase.io` — the sender cannot be changed
- appends "powered by Supabase" and an opt-out link
- is **rate limited to a handful of messages per hour** and documented as not for
  production — at launch volume, most sign-in links would simply never arrive

Separately, `supabase/templates/*.html` were wired only through `config.toml`,
which governs `supabase start` and a linked `db push`. The hosted dashboard keeps
its own copy, so the branded templates were never in effect in production.

## How it works now

```
                      ┌─ magic link ─┐
Supabase Auth ────────┤  signup      ├──→ Send Email Hook
  (no longer sends)   │  recovery    │         │
                      │  email change│         ▼
                      └─ reauth code ┘   supabase/functions/auth-email
                                                │  HMAC-verified
                                                ▼
stripe-webhook ─── topup receipt ─────→ _shared/messages.ts
billing-notify ─── statement ready ───→ _shared/email.ts   (one design system)
               └── low float ─────────→        │
send-company-invite ─ invite ─────────→ _shared/resend.ts
                                                ▼
                                    Resend → no-reply@rydlnk.us
```

| Email | Sent by | Trigger |
|---|---|---|
| Sign-in link | `auth-email` | magic link request |
| Confirm signup | `auth-email` | new account |
| Reset password | `auth-email` | recovery request |
| Confirm new address | `auth-email` | email change (fires twice — old and new) |
| Confirmation code | `auth-email` | reauthentication (code, not a link) |
| Company invite | `send-company-invite` | portal invite or roster import |
| Top-up receipt | `stripe-webhook` | `payment_intent.succeeded` |
| Statement ready | `billing-notify` | monthly, after statements generate |
| Low float | `billing-notify` | hourly check, once per company per day |

13 rendered variants. Browse them all with `npm run email:preview`.

## Turning it on

Order matters: the hook refuses to send without its secret, and a hook enabled
before the function is deployed breaks sign-in for everyone.

1. **Verify the sending domain in Resend.** Add `rydlnk.us`, publish the DKIM and
   SPF records it gives you, wait for verification. Resend rejects every send
   from an unverified domain, so nothing below works until this is green.

2. **Fill in `supabase/.env`** — `RESEND_API_KEY` at minimum. `INVITE_FROM_EMAIL`
   and `SITE_ORIGIN` are already set to `rydlnk.us`.

3. **Deploy the function and push secrets:**
   ```bash
   supabase link --project-ref zpduvchwzoxkzfjuqlww
   supabase secrets set --env-file supabase/.env
   supabase functions deploy auth-email --no-verify-jwt
   ```

4. **Create the hook.** Dashboard → Authentication → Hooks → **Send Email** →
   HTTPS, URL:
   ```
   https://zpduvchwzoxkzfjuqlww.supabase.co/functions/v1/auth-email
   ```
   It shows a secret like `v1,whsec_…`. Copy it verbatim.

5. **Store that secret and redeploy secrets:**
   ```bash
   # paste into SEND_EMAIL_HOOK_SECRET in supabase/.env, then
   supabase secrets set --env-file supabase/.env
   ```

6. **Enable the hook**, then immediately test a magic link to a real inbox.

7. **Confirm the result.** The sender must read `Rydlnk <no-reply@rydlnk.us>`,
   with no "powered by Supabase" footer and no opt-out link.

### If sign-in breaks

Disable the hook in the dashboard. Supabase falls straight back to its built-in
mailer — ugly and rate limited, but working — which is why
`supabase/templates/*.html` are still generated and committed: they are the
fallback path's templates. Then:

```bash
supabase functions logs auth-email
```

`signature rejected` means `SEND_EMAIL_HOOK_SECRET` does not match the hook's
secret. `hook secret not configured` means the secret never reached the function —
re-run `secrets set`.

## Custom SMTP is not needed

Supabase also offers custom SMTP under Authentication → Emails. It would fix the
sender but leave Supabase rendering the body from its own templates, so the two
systems would drift. The hook replaces both concerns at once. Leave SMTP unset.

## Design system

`supabase/functions/_shared/email.ts` — table-based layout, inline styles, VML
button for Outlook, dark-mode overrides, and a plain-text alternative generated
for every message (a missing `text/plain` part is scored as spam, and the invite
is the first mail a fresh sending domain ever sends).

`messages.ts` holds the content for all 13 variants, subject included, so a
subject cannot drift from the body it belongs to.

Blocks available: `text`, `facts` (label/value rows with an optional total),
`callout` (neutral / warning / positive), `bullets`, `code` (one-time codes,
monospaced and letter-spaced so 0/O and 1/l cannot be misread), `link-fallback`,
`divider`.

Regeneration is deterministic — `npm run email:templates` twice produces
byte-identical files, verified by hashing.

## Changing an email

1. Edit `messages.ts`.
2. `npm run email:preview` and look at it, light and dark.
3. `npm run email:templates` if an auth template changed, and commit the result.
4. `supabase functions deploy auth-email` — the rest pick it up on their next
   deploy, since they all import the same module.

## Known gaps

- **No delivery dashboard.** Resend's own logs are the only record for auth mail;
  `notification_log` covers billing mail only. Auth email is not claimed there on
  purpose — Supabase already guarantees one call per request, and a claim would
  add a way for a sign-in to be silently skipped.
- **Bounces are not handled.** A hard bounce to a billing contact is invisible
  until someone asks why they stopped getting statements. Resend can webhook
  bounces; nothing consumes it yet.
- **No unsubscribe on billing mail.** Transactional messages do not legally need
  one, but the low-float warning is arguably promotional at the margin.
