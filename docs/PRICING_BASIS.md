# Pricing basis

Where every number in the public calculators comes from, and what has to be true
before launch.

## Single source

All shared rate constants live in [`src/lib/data.ts`](../src/lib/data.ts).
Nothing that a calculator displays should be a literal inside a component — the
file says as much for `WEEKS_PER_MONTH` ("used by every calculator so they can't
drift apart"), and the corridor fares now follow the same rule.

| Constant | Value | Meaning |
|---|---|---|
| `CORRIDOR_FARES[].seat` | $2.00–$3.20 | What Rydlnk charges per seat |
| `CORRIDOR_FARES[].solo` | $6.80–$11.50 | **Lyft-derived** single-rider fare, same corridor |
| `CREDIT_VALUE` | $1.00 | One credit is one dollar |
| `SEAT_PRICE` (pricing-estimator) | 4 credits | Mid-corridor seat, employer side |
| `PLATFORM_FEE` | $4.50 | Per active employee per month |
| `POOL_REBATE_PER_SEAT` | 2 credits | Returned when a spare seat is sold on |
| `SEATS_PER_VEHICLE` | 8 | Standard van |
| `TRANSIT_BENEFIT_CAP` | see data.ts | IRS §132(f) monthly cap |

## The competitor-derived number

`CORRIDOR_FARES[].solo` is the only figure on the site derived from a
competitor's pricing. It is based on **Lyft's Utah County rates**, and it drives
the claim the fare calculator prints:

> A seat on this corridor is **N% cheaper** than booking alone.

With the current values that renders as 70–72% cheaper depending on corridor.

### Why the values are per-corridor rather than a formula

A least-squares fit across the four corridors gives about **$2.00 + $0.393 per
mile** (largest residual 9c). That model is recorded in `data.ts` as a sanity
check only. It is deliberately *not* what the site computes, because real
ride-hail pricing also carries a per-minute component and surge multipliers, so
a quote captured for a specific route is more defensible than a mileage line fit
through four points.

If a future edit moves a `solo` value far off that line, it is probably a typo.

## Before launch — required

- [ ] **Record a capture date for each `solo` fare.** There is currently no note
      of when these were quoted. A comparative price claim has to be current,
      and "current" is unprovable without a date.
- [ ] **Keep the substantiation evidence.** Screenshots or API quotes per
      corridor, filed somewhere durable. The FTC's position on comparative
      advertising is that the advertiser holds the proof; an undocumented "70%
      cheaper" is the exposure, not the number itself.
- [ ] **Decide whether to name Lyft publicly.** The calculator footer currently
      says "a typical on-demand ride-hail service" rather than naming a brand.
      Naming one is stronger marketing and invites trademark and comparative-ad
      scrutiny — a question for counsel. The code comment names Lyft; the page
      does not.
- [ ] **Confirm like-for-like.** The comparison should be the same trip, same
      time of day, standard service tier (not shared/pooled Lyft, which would be
      the closer analogue and a smaller gap), excluding surge — which is what the
      footer now discloses.
- [ ] **Set a re-quote cadence.** These go stale silently. Ride-hail base rates
      move; nothing in the build will warn you.

## Related

`TRANSIT_BENEFIT_CAP` in `data.ts` carries its own warning to confirm the
current-year IRS figure. That is a separate annual obligation from the fare
basis above, and the go-live checklist already lists "launch currency, credit
value and tax treatment signed off".
