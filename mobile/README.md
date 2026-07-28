# rydlnk — refined Flutter rebuild

A nicer take on the rydlnk / RydLink ride-share app from the reference videos. Full feature parity with both reference designs, unified under one elegant design system.

## What changed from the originals

| | Originals | This rebuild |
|---|---|---|
| Primary green | Lime `#22A04A` / saturated emerald | Deep emerald `#0B5D3B` |
| Background | Pure white | Warm off-white `#FAFAF6` |
| Hero greeting | Cursive script "Tafadzwa" | DM Serif Display italic |
| Status bar | Green strip behind iOS clock | Edge-to-edge, system-adaptive |
| Logo | Yellow blob behind "ln" | Subtle warm-gold accent dot |
| Cards | Hairline borders | 1px warm border + soft shadow |
| Day chips | Tight circles | 12px radius rounded squares |
| Bottom nav | 3 tabs, static | 4 tabs + center FAB, animated indicator |
| Wizard | Linear, plain | Animated stepper with check marks |
| Confirmation | Static check + slab | Hand-drawn animated check, glass detail card |
| Live ride pill | Static label | Pulsing red dot animation |

## App flow

```
Onboarding  →  Sign in  →  NavShell (Home / Schedules / Rides / Profile)
                                         ↓ (FAB)
                                  Quick booking sheet
                                  Create schedule wizard
                                         ↓
                                  Driver profile  →  Booking confirmed
```

## Run it

```bash
unzip rydlnk_flutter.zip
cd rydlnk_flutter
flutter pub get
flutter run
```

## File map

```
lib/
├── main.dart                              app entry, starts at onboarding
├── theme/
│   ├── app_colors.dart                    palette + accent tints
│   ├── app_typography.dart                DM Serif + Instrument Serif + Inter
│   └── app_theme.dart                     Material 3 theme wiring
├── widgets/
│   ├── rydlnk_logo.dart                   wordmark + gold accent dot
│   ├── primary_button.dart                primary / secondary CTAs
│   ├── day_selector.dart                  S M T W T F S chips
│   ├── wizard_stepper.dart                animated 4-step indicator
│   ├── stats_hero_card.dart               green gradient hero w/ 3 stats
│   ├── next_ride_card.dart                countdown + track live + message
│   ├── quick_action_tile.dart             colored dashboard tile
│   ├── impact_card.dart                   weekly impact stats
│   ├── schedule_list_item.dart            today's schedule row
│   ├── ride_booking_card.dart             ★ recurring ride form
│   ├── ride_list_item.dart                past rides card
│   └── confirm_rides_sheet.dart           weekly billing bottom sheet
└── screens/
    ├── onboarding_screen.dart             gradient bg + 3 feature cards
    ├── sign_in_screen.dart                email/password + loading state
    ├── nav_shell.dart                     4-tab nav + center FAB
    ├── home_screen.dart                   dashboard
    ├── my_schedules_screen.dart           active/paused schedules list
    ├── rides_screen.dart                  Today/History segmented tabs
    ├── profile_screen.dart                profile + gradient referral card
    ├── create_schedule_screen.dart        4-step wizard
    ├── driver_profile_screen.dart         driver detail + reviews
    ├── booking_confirmed_screen.dart      animated celebration
    ├── past_rides_screen.dart             grouped ride history
    └── payment_methods_screen.dart        cards + Apple Pay
```

## Notable interactions

- **Quick book** — tap the FAB in the center of the nav, or "Find rides" on the dashboard, to open the recurring ride form as a bottom sheet that dynamically computes ride count from day pattern × date range
- **Schedule wizard** — every step is animated; selecting "Daily" or "Weekends only" skips the custom day picker on step 2 and shows a summary chip instead
- **Booking confirmed** — elastic scale-in, then a custom-painted check stroke animates from start to mid to end (no static checkmark icon)
- **Live ride** — the red dot on an in-progress ride pulses opacity continuously
- **Stepper** — completed steps morph from outlined to filled with a check; current step shows an inner dot

## Wiring for production

- Replace state in `RideBookingCard`, `CreateScheduleScreen` and the screen lists with your data layer
- The `SignInScreen` simulates a 900ms call then `pushAndRemoveUntil` to `NavShell` — swap for real auth
- All screens are reachable through `Navigator.push` — no router package required, but easy to migrate to `go_router` or `auto_route`
- `flutter_svg` is in pubspec for when you add brand illustrations (the rydlnk logo is pure Flutter widgets)
