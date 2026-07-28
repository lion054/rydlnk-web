# Phase 7 — Launch runbook

Phase 7 is mostly **procurement, legal, and operations**, not code. This is the
ordered plan. Items marked 🟢 are done/prepared in-repo; 🟡 need your action;
🔴 are hard external dependencies (money, vendors, review queues) — start these
**now**, in parallel, because they take weeks.

---

## A. Release engineering (technical — I can do most)

1. 🟢 **App identity** set — `com.rydlnk.rydlnk`, v1.0.0(1), release signing config
   wired ([android/app/build.gradle.kts](android/app/build.gradle.kts)).
2. 🟢 **AAB builds** — `flutter build appbundle --release` produces the Play
   bundle (currently debug-signed; upload-signs once you add the keystore).
3. 🟡 **Create your upload keystore** (you must own it — never share it):
   ```bash
   keytool -genkey -v -keystore ~/rydlnk-upload.jks -keyalg RSA \
           -keysize 2048 -validity 10000 -alias upload
   cp android/key.properties.template android/key.properties   # fill in values
   flutter build appbundle --release                            # now upload-signed
   ```
4. 🟢 **App icon** — branded emerald map-pin generated for Android (adaptive) +
   iOS via `flutter_launcher_icons` (source: `assets/icon/`). Swap the source
   PNG + re-run if you want a designer's mark later.
5. 🟡 **Store listing** — content ready in [STORE_LISTING.md](STORE_LISTING.md);
   add screenshots (capture on a device) + host the privacy policy.

## B. Driver vetting (system 🟢 built — operations 🟡🔴)

- 🟢 Drivers upload ID/licence/vehicle-reg/insurance; `request_verification`
  gates on all four; `claim_trip` requires `verified=true`.
- 🔴 **Contract a background-check vendor** and define your SOP:
  1. Driver submits documents in-app.
  2. Ops runs identity + criminal + driving-record checks via the vendor.
  3. Verify insurance validity + expiry.
  4. On pass → set `verified=true`, `verification_status='approved'` on the
     `drivers` row (Table Editor now; build a small admin view before scale).
  5. On fail → set `verification_status='rejected'` + a `note`.
- 🟡 Build a lightweight **ops/admin console** once you have >a handful of drivers.

## C. Insurance 🔴 (you procure — the app only records it)

- Obtain **commercial rideshare / platform insurance**: driver liability +
  passenger cover + platform liability. The app stores each driver's policy +
  expiry and blocks unverified drivers, but **Rydlnk is not the insurer**.
- Decide the model (driver-provided vs platform-provided vs hybrid) with your
  insurer, and reflect it in the Driver Agreement.

## D. Legal 🟡 (drafts 🟢 in-repo — a lawyer must finalise)

- 🟢 Drafts + in-app consent capture: [assets/legal/](assets/legal/)
  (Terms, Privacy, Rider & Driver agreements), recorded in `legal_acceptances`.
- 🔴 **Engage a lawyer** in your jurisdiction (Zimbabwe) to finalise every
  `[bracketed]` gap: liability/indemnity, insurance interaction, driver
  classification, dispute resolution, data-protection compliance.
- 🟡 Fill company/contact/jurisdiction details; bump the doc `version` strings so
  consent re-captures.

## E. Safety & support 🟡

- 🟢 In-app SOS + share-trip built. Set `SafetySheet.emergencyNumber` per market
  (currently `999`).
- 🔴 Stand up a real **incident-response + support** process (channel, refunds,
  disputes, safety escalation).

## F. External hookups (parked by you, but required for a paid launch)

- 🔴 **Stripe** — deploy the payment functions + `flutter_stripe` (see
  [PHASE_2_3_SETUP.md](PHASE_2_3_SETUP.md)). Not needed for a free pilot.
- 🔴 **FCM push** — Firebase project + `firebase_messaging` for "driver arriving".
- 🟡 **OSM at scale** — move off the public OSRM/Nominatim demo servers to a
  hosted/self-hosted instance before real traffic.

## G. Beta → GA

1. 🟡 **Run it on real devices** — the #1 unverified thing. Walk rider + driver
   end-to-end; exercise GPS.
2. 🟡 **Closed beta** in one corridor / one company's employees (helps the
   two-sided cold start). Internal testing track on Play, TestFlight on iOS.
3. 🟡 Fix what the beta surfaces → **phased GA**.

---

## The critical path, in order
1. **Device run** (technical, free, do first).
2. **Keystore + signed AAB** → internal-testing upload.
3. In parallel from day 1: **insurance**, **background-check vendor**, **lawyer**.
4. **Closed beta** → fix → **GA**.

Everything in A/D-drafts/B-system is prepared; C, and the human parts of B/D/E,
are procurement/legal that only you can execute.
