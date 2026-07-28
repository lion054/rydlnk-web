# Rydlnk — Store Listing Pack

Copy-ready content for Google Play + Apple App Store. Screenshots and the final
privacy-policy URL are yours to add (see gaps marked ⚠️).

## Identity
- **App name:** Rydlnk
- **Package / Bundle ID:** `com.rydlnk.rydlnk`
- **Version:** 1.0.0 (build 1)
- **Category:** Maps & Navigation / Travel (Play) · Travel (App Store)
- **Content rating:** Everyone / 4+ (no objectionable content)

## Short description (Play, ≤80 chars)
> Shared commutes, split fares. Book a recurring ride and pool with co-riders.

## Full description
> Rydlnk is a shared-commute app. Book a one-time or recurring ride, and we pool
> you with other riders heading the same way — so everyone splits the fare and
> pays less.
>
> • **Recurring schedules** — set your days and times once; rides repeat.
> • **Corridor pooling** — nearby riders share one trip and split the cost.
> • **Real fares** — priced on actual distance, shown before you book.
> • **Drive with Rydlnk** — verified drivers pick up shared trips and earn.
> • **Live tracking & chat** — follow your driver and message your trip.
> • **Safety built in** — share your trip and reach help fast.
>
> Rydlnk connects riders with independent drivers; it is a marketplace, not a
> transport provider.

## Required URLs
- ⚠️ **Privacy Policy URL** — host `assets/legal/privacy.md` publicly and link it.
- ⚠️ **Support / contact** — an email or page (e.g. support@rydlnk.app).

## Screenshots (capture on a real device — you run the app)
Recommended set (phone, portrait): Home dashboard · Booking sheet with map picker
· Shared-trip fare split · Driver "Today" manifest · Live tracking · Ratings.

---

## Google Play — Data Safety form
Answer these truthfully; they reflect what the app actually collects today.

| Data type | Collected | Shared | Purpose | Notes |
|---|---|---|---|---|
| Name | Yes | With trip participants | Account, matching | driver name shown to riders |
| Email | Yes | No | Account | |
| Phone | Yes | No | Account | |
| **Precise location** | Yes | With trip participants | Matching, pickup, live tracking | driver GPS shown to riders on active trip only |
| App activity (rides, schedules) | Yes | No | App function | |
| Photos (driver ID/licence/insurance/reg) | Yes (drivers) | With reviewers | Driver verification | private storage bucket |
| Messages | Yes | With trip participants | In-trip chat | |
| Device push token | When push is enabled | No | Notifications | FCM, once wired |
| **Payment info** | Not yet | — | — | via Stripe when enabled; card data held by Stripe, not us |

- **Encrypted in transit:** Yes (HTTPS/TLS).
- **Users can request deletion:** **Yes** — in-app "Delete account" removes the
  account and all data.
- **Data not sold.**

## Apple App Store — Privacy "Nutrition" labels
- **Data used to track you:** None.
- **Data linked to you:** Contact info (name, email, phone), Location (precise),
  User content (photos for verification, messages), Identifiers (user id),
  Usage data (rides/schedules).
- **Purposes:** App functionality, matching, safety.
- Provide the same Privacy Policy URL.

## App Store review notes (paste into "Notes for Reviewer")
> Rydlnk is a shared-ride marketplace. To review the driver flow: sign up and
> toggle "Drive", then submit test documents under Account → Verification. A
> reviewer/admin approves drivers by setting `verified=true` (we can pre-approve
> a demo driver account on request). Location is used for pickup/matching and
> live trip tracking. No payments are processed in this build.
