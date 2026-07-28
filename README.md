# Rydlnk — Next.js prototype

Two audiences, one seat inventory.

- **For me** (`/individual`, `/download`) — a commuter buys a seat on a run that's already happening.
- **For work** (`/work`, `/portal`) — an employer funds credits, the roster fills the seats, finance gets one invoice.

Both spend against the same seat. That's the point of the product and the reason the site forks at `/`
rather than being two separate sites.

## Running it

```bash
npm install
npm run dev      # http://localhost:3000
npm run build    # verified clean
```

Next.js 15 (App Router) · React 19 · TypeScript · Tailwind CSS v4. No other runtime dependencies.

## Routes

**Marketing — individual track** (`src/app/individual/layout.tsx` adds subnav + pager)

| Route | What it is |
| --- | --- |
| `/` | Audience fork — individual vs employer |
| `/individual` | Hub: hero, dual-wallet phone mock, links into the track |
| `/individual/how-it-works` | Three steps, then the week in order, then the trade-off |
| `/individual/fares` | Live fare calculator + published corridor price table |
| `/individual/safety` | Night-shift controls, what we ask of riders, what to do when it goes wrong |
| `/individual/faq` | Grouped: basics, money, people & privacy |
| `/download` | Store links, SMS/WhatsApp link sender, what you need to sign up |
| `/drivers` | Supply side — why drivers stay, documents, a typical run |

**Marketing — work track** (`src/app/work/layout.tsx`)

| Route | What it is |
| --- | --- |
| `/work` | Hub: departures board with pooling toggle, proof strip, links into the track |
| `/work/credits` | Credit lifecycle, why it's a ledger, split-tender worked example |
| `/work/pooling` | Anchor seats, fixed pricing, alone-vs-pooled cost table, what others see |
| `/work/roster` | Roster-driven vs on-demand, a week in the system, the numbers |
| `/work/integrations` | Connectors by role, sync pipeline, minimum CSV columns |
| `/work/security` | Per-seat tenant isolation, operating controls, portal roles |
| `/work/pricing` | Live estimator, spot/anchor/exclusive, what's in and out of the fee |
| `/work/faq` | Grouped: finance, operations, risk & HR |
| `/work/contact` | Working enquiry form that previews what the walkthrough will show |

**Portal** (`src/app/portal/layout.tsx`)

| Route | What it is |
| --- | --- |
| `/portal` | Overview — tonight's board, alerts, cost-centre spend |
| `/portal/trips` | Manifest cards and per-seat funding/status, filterable |
| `/portal/corridors` | Editable pooling policy per corridor, roster grid, clustering rules |
| `/portal/people` | Directory with search/filter and a working allocation drawer |
| `/portal/credits` | Double-entry ledger, allocation rules, policy limits |
| `/portal/integrations` | Connectors and a sync log you can run |

Navigation is driven from `src/lib/nav.ts` — the header, the section subnav, the prev/next pager and the
footer all read from it, so adding a page is one entry plus the route file.

## The model, in one paragraph

A **Trip** belongs to Rydlnk, not to a company. A **Seat** on that trip belongs to a payer — an employer
wallet, a personal wallet, or a split of both. Everything downstream hangs off the seat: the ledger entry,
the invoice line, the fiscal receipt, and the authorization check. This is what makes cross-employer pooling
possible, and it is the single hardest thing to retrofit later.

Seat price is **fixed per corridor and time band**, not derived from the actual vehicle cost divided by
riders. One employer's no-show must never change what another employer pays. Rydlnk carries the yield risk
between the sum of seat prices and the real cost of running the vehicle, and the margin lives in fill rate.

See `src/lib/data.ts` — the shapes there are deliberately close to what the real schema should be.

## What's mocked

Everything is static data plus local component state. Specifically not built:

- Auth, sessions, org context
- Any persistence — the portal float is React context, so it resets on reload
- Real matching/clustering (the board is hand-authored to make the pooling argument legible)
- Form submissions are local state; nothing is posted anywhere

Numbers shown to the user are **derived**, not written into copy. `src/lib/data.ts` holds the shared
constants (`SEATS_PER_VEHICLE`, `POOL_REBATE_PER_SEAT`, `WEEKS_PER_MONTH`, department headcounts) and the
derivations (`seatStats`, `boardTotals`). If you find yourself typing a figure into a sentence, derive it
instead — the previous build had copy claiming "4 vehicles" next to a stat reading 3.

Anything still standing in for real content is marked `PLACEHOLDER` in `src/lib/site.ts`: the WhatsApp
Business number and the two store listing URLs. Grep that file, not the tree.

## Before this goes anywhere near production

1. **Tenant isolation is per-seat, not per-trip.** Trip IDs are shared across employers. A company querying
   a pooled trip must get back its own seats and an occupancy count — never another employer's names,
   departments or home addresses. Enforce it at the query layer, not in controllers, and write the tests
   first. This is the highest-severity bug class in the whole product.
2. **The ledger is append-only.** No balance columns that get mutated. A wallet balance is a projection over
   entries, and every entry names a source, a destination and a reference.
3. **Terminations run on webhooks, not the nightly job.** A leaver who rides on Monday morning is money
   straight out of the float.
4. **Fiscal receipts** are per payer, not per trip — a pooled run generates several. Hook fiscalization at
   seat settlement.
5. **Legal copy is a draft.** `/legal/terms` and `/legal/privacy` write down commitments already made
   elsewhere on the site so the footer links resolve. Both carry a visible "pending legal review" banner —
   remove it only once counsel has signed the text off against the Cyber and Data Protection Act.

Fonts are self-hosted via `next/font/google`, so `npm run build` needs network access on a cold cache.
