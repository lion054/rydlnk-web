# Rydlnk — Go-Live Checklist

Everything the app *code* needs is built and verified (Phases 1–6 + Lyft-style
pooling + OSM fares + MVP hardening). What remains is **external hookups** and
**launch/compliance work** — none of which is code I can finish for you. This is
the single list to work through.

---

## A. External hookups (need your accounts)

### 1. Payments — Stripe  🔴 blocks revenue
- Create a Stripe account → get `sk_…` (secret) + `pk_…` (publishable).
- `supabase secrets set STRIPE_SECRET_KEY=… STRIPE_WEBHOOK_SECRET=…`
- Deploy: `stripe-setup-intent`, `stripe-webhook`, `charge-weekly` (already written).
- Add the webhook endpoint in Stripe; subscribe to setup/payment intents.
- Add `flutter_stripe` + publishable key for the in-app card sheet.
- Set `BILLING_CURRENCY` (defaults `usd`) to your market before charging.
- See [PHASE_2_3_SETUP.md](PHASE_2_3_SETUP.md).

### 2. Push notifications — Firebase/FCM  🟡 expected by users
- Create a Firebase project; add iOS + Android apps (`google-services.json` /
  `GoogleService-Info.plist`).
- Add `firebase_core` + `firebase_messaging`; register the token via
  [NotificationsRepository](lib/data/notifications_repository.dart).
- Deploy the `send-push` function; wire the service-account auth (see the note
  in [send-push](supabase/functions/send-push/index.ts)).
- Reminder: iOS push always goes through Apple APNs — configure APNs in Firebase.

### 3. Maps / routing — OpenStreetMap (already wired)  🟢 no Google
- App uses OSM tiles + Nominatim geocoding + OSRM routing (real fares) — no key.
- **Before scale**, move off the public demo servers: self-host OSRM +
  Nominatim (Docker), or use a keyed OSM provider (openrouteservice, Geoapify,
  MapTiler). One-line URL swap in [RoutingService](lib/data/routing_service.dart).
- Sanity-check OSM coverage in your launch city.

### 4. Real-device test  🔴 blocks launch
- Nothing has run on a physical phone yet. Run rider + driver flows end-to-end;
  in particular exercise **live GPS tracking** (geolocator permissions + real
  coordinates) which is code-complete but unverified on-device.

---

## B. Operations — driver vetting (system built, migration 011)

**Built (code):**
- Drivers upload **ID, licence, vehicle registration, insurance** (Account →
  Verification) into a private storage bucket; each has a review status.
- `request_verification()` requires all four before a driver can submit; that
  sets `verification_status = 'pending'`.
- `claim_trip` still gates on `drivers.verified = true` (migration 008), so an
  un-approved driver can go online but **cannot accept trips**.
- Insurance expiry is captured and carried onto the driver record.

**You still procure / do:**
- [ ] **Contract a background-check vendor**; feed its result into the review.
- [ ] **Buy rideshare/platform insurance** (the app records driver policies, it
      is not the insurer).
- [ ] **Approve drivers**: after review, set `verified = true` +
      `verification_status = 'approved'` on the `drivers` row (Table Editor now;
      build a small admin/ops view before scale).

## B2. Legal (drafts built, migration 011)

**Built (code):**
- Draft **Terms, Privacy Policy, Rider & Driver agreements** ship as in-app docs
  (`assets/legal/`), viewable from sign-up.
- **Consent is captured** at sign-up (`legal_acceptances`), versioned.

**You still do:**
- [ ] **Have a lawyer finalise every draft** for your jurisdiction (Zimbabwe) —
      they are marked DRAFT and contain `[bracketed]` gaps to complete.
- [ ] Fill in company/contact/jurisdiction details and bump the doc versions.

---

## C. Launch & compliance (non-code — the real long poles)

Start these **now, in parallel** — they take weeks and often cost more than the
build.

- [ ] **Rideshare insurance** — commercial/rideshare cover for drivers + platform liability.
- [ ] **Driver background checks** — vetting vendor; feed results into the `verified` flag above.
- [ ] **Legal** — Terms of Service, Privacy Policy, rider + driver agreements, refund/cancellation policy. Have a lawyer review (esp. the pooled-fare model + data/location handling).
- [ ] **Safety program** — the in-app SOS + share-trip is built; back it with a real emergency-response process, incident reporting, and support escalation. Set `SafetySheet.emergencyNumber` per market (currently `999`).
- [ ] **Support & disputes** — channel for riders/drivers, refund handling, dispute resolution.
- [ ] **Data/privacy compliance** — location + payment data handling per your jurisdiction.
- [ ] **App Store + Play submission** — accounts, listings, review (rideshare + location + background-location justifications), privacy nutrition labels.
- [ ] **Closed beta** — one corridor / one company's employees first (helps the two-sided cold-start), fix, then phased GA.

---

## D. Nice-to-haves after MVP

- Geo-proximity pooling (currently pools on exact route/time match — a map-based
  radius would pool more riders). Would add lat/lng to trips + a PostGIS matcher.
- Rider-side "shared with N others" indicator on a ride.
- Scheduled-function trigger for `charge-weekly` (pg_cron `net.http_post`).
- In-app driver onboarding doc uploads (license/insurance) → `Supabase Storage`.

---

**Bottom line:** the buildable product is feature-complete and RLS-verified.
The gate to a real launch is now **A (your accounts) + C (legal/ops)** — not code.
