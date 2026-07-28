# Rydlnk — Phase 2 & 3 setup / go-live checklist

Everything below is **already written in the repo**. This is the sequence of
things *you* run to make it live.

## Phase 2 — recurring engine (fully self-contained)

1. **Run the migration.** Supabase → SQL Editor → paste & run
   [`supabase/migrations/002_schedules_rides.sql`](supabase/migrations/002_schedules_rides.sql).
   (Run `001_init.sql` first if you haven't.)
2. **Enable the rollover job (optional but recommended).**
   Database → Extensions → enable **`pg_cron`**, then re-run the bottom
   section of `002` — it registers a nightly job that keeps recurring rides
   ~3 weeks ahead.
3. **Test in the app** (`flutter run`):
   - Home → *Find rides* → book a Mon–Fri recurring schedule → it now writes a
     real `schedule` + `rides`.
   - Check **Table Editor → schedules / rides** — rows appear.
   - **Schedules** tab lists it; **Pause/Resume** flips status live.
   - **Rides** tab (Today/History) and Home's next-ride are all live queries.

That's the whole Phase 2 loop: book → persist → generate → display → manage.
Driver matching is intentionally still stubbed (that's Phase 4/5) — rides show
"Finding driver" until a driver is assigned.

## Phase 3 — payments (needs your Stripe account)

The database + Edge Functions are written; wiring them up needs Stripe keys.

1. **Run** [`supabase/migrations/003_payments.sql`](supabase/migrations/003_payments.sql)
   (payment_methods, billing_cycles, stripe_customers + RLS).
2. **Create a Stripe account** → get `sk_test_…` (secret) and `pk_test_…`
   (publishable).
3. **Set function secrets** (never commit these):
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_test_...
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...   # from step 5
   ```
4. **Deploy the functions:**
   ```bash
   supabase functions deploy stripe-setup-intent
   supabase functions deploy stripe-webhook --no-verify-jwt
   supabase functions deploy charge-weekly
   ```
5. **Add the webhook** in the Stripe dashboard → Developers → Webhooks → point
   it at the `stripe-webhook` function URL; subscribe to `setup_intent.succeeded`,
   `payment_intent.succeeded`, `payment_intent.payment_failed`. Copy the signing
   secret into `STRIPE_WEBHOOK_SECRET`.
6. **Schedule weekly billing** — invoke `charge-weekly` every Monday (via a
   pg_cron `net.http_post`, or a scheduled Supabase routine / external cron).
7. **Last client step to finish "Add card":** add the `flutter_stripe` package
   and your **publishable** key, then feed the `client_secret` from
   `PaymentsRepository.createSetupIntent()` into Stripe's card sheet.
   Until then, the Payment screen lists/deletes saved cards and the backend is
   ready — it just can't render the native card form yet.

## What's wired in the app

| Area | File | State |
|---|---|---|
| Models | `lib/models/{schedule,ride,payment_method}.dart` | ✅ |
| Data layer | `lib/data/{rides,payments}_repository.dart` | ✅ |
| Booking → schedule | `lib/widgets/ride_booking_card.dart` | ✅ writes real data |
| Schedule wizard | `lib/screens/create_schedule_screen.dart` | ✅ uses home/work addresses |
| My Schedules | `lib/screens/my_schedules_screen.dart` | ✅ live list + pause/resume |
| Rides (today/history) | `lib/screens/rides_screen.dart` | ✅ live |
| Home (next ride / today) | `lib/screens/home_screen.dart` | ✅ live |
| Payment methods | `lib/screens/payment_methods_screen.dart` | ✅ lists/deletes; add-card pending Stripe SDK |

## Notes / honest gaps

- **Pricing is a flat `$8.17`/ride estimate** for now — real fares come with
  Google Maps distance in Phase 5. Change the `priceCents` default in
  `RidesRepository.createSchedule` / the wizard if you want a different number.
- **Billing currency** defaults to `usd` (`BILLING_CURRENCY` env on
  `charge-weekly`). Set it to your market's currency before charging real money.
- **Card detach:** removing a card deletes the DB row; add a Stripe
  `paymentMethods.detach` call in an Edge Function when you wire the SDK.
