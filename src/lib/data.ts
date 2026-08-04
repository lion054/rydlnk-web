/**
 * Prototype data — Utah County.
 *
 * The important shape here: a Trip is owned by Rydlnk, and a Seat on that trip
 * is owned by a payer. "me" means the employer currently signed in to the
 * portal. Everything downstream — ledger, invoices, authorization — hangs off
 * the seat, never the trip.
 *
 * Pooling partners are deliberately invented names. Putting real Utah employers
 * here would read as a customer list, which would be false — the same reason
 * the marketing photography avoids identifiable people.
 */

/* ------------------------------------------------------------- constants */

/** Seats in a standard Rydlnk van. Every vehicle-count derivation reads this. */
export const SEATS_PER_VEHICLE = 8;

/** Credits returned to the float when a spare seat is sold to another employer. */
export const POOL_REBATE_PER_SEAT = 2;

/** Platform fee, per active employee per month. */
export const PLATFORM_FEE = 4.5;

/** A credit is worth a dollar. */
export const CREDIT_VALUE = 1;

/** 52 / 12. Used by every calculator so they can't drift apart. */
export const WEEKS_PER_MONTH = 52 / 12;

/**
 * Per-corridor fares. The single source for every calculator.
 *
 * `seat` is what Rydlnk charges. `solo` is the single-rider ride-hail fare for
 * the same trip, **derived from Lyft's Utah County pricing** — it is the basis
 * for the "% cheaper than booking alone" figure the fare calculator prints, and
 * it is the only competitor-derived number on the site.
 *
 * Kept as measured per-corridor values rather than collapsed into a
 * base-plus-mileage formula on purpose. A least-squares fit over these four
 * corridors gives roughly $2.00 + $0.393/mile (max residual 9c), but real
 * ride-hail pricing also carries a per-minute component and surge, so a
 * per-corridor quote survives contact with a specific route better than the
 * linear model does. The fitted figures are recorded here only as a sanity
 * check: if a future edit drifts far from them, something was mistyped.
 *
 * ── Before launch ──────────────────────────────────────────────────────────
 * These need a dated substantiation record. A specific "N% cheaper" claim
 * benchmarked against a named competitor is comparative advertising, and the
 * FTC expects the comparison to be current, like-for-like and documented. Two
 * things follow: re-quote these when Lyft's Utah rates move, and keep a note of
 * when each was captured. Neither the basis nor a capture date is disclosed to
 * the visitor today — see docs/PRICING_BASIS.md.
 */
export type CorridorFare = {
  name: string;
  miles: number;
  /** Rydlnk seat fare, USD. Fixed — no surge, no time component. */
  seat: number;
  /** Comparable single-rider Lyft fare for the same corridor, USD. */
  solo: number;
};

export const CORRIDOR_FARES: CorridorFare[] = [
  { name: "Spanish Fork → East Bay", miles: 24, seat: 3.2, solo: 11.5 },
  { name: "Payson → CBD", miles: 19, seat: 2.8, solo: 9.4 },
  { name: "Orem → East Bay", miles: 16, seat: 2.4, solo: 8.2 },
  { name: "Lehi → CBD", miles: 12, seat: 2.0, solo: 6.8 },
];

/**
 * IRS §132(f) qualified transportation fringe benefit, monthly cap per employee.
 * Employer-funded commuting up to this amount is excluded from the employee's
 * gross income and from payroll tax — the single strongest reason a US employer
 * funds a commute rather than raising pay. Confirm the current-year figure with
 * your accountant before quoting it.
 */
export const TRANSIT_BENEFIT_CAP = 340;

export type Payer = "me" | string | null;

export type Trip = {
  id: string;
  depart: string;
  corridor: string;
  vehicle: string;
  miles: number;
  anchor: Payer;
  seats: Payer[];
  credits: number;
  pooling: "open" | "approved" | "exclusive";
};

const s = (...payers: Payer[]): Payer[] => {
  const row = [...payers];
  while (row.length < SEATS_PER_VEHICLE) row.push(null);
  return row;
};

export const trips: Trip[] = [
  { id: "RYD-88412", depart: "10:15 PM", corridor: "East Bay → Spanish Fork", vehicle: "UT 482-BQC", miles: 10, anchor: "me", seats: s("me", "me", "Wasatch Foods", "me", "me", "Wasatch Foods"), credits: 6, pooling: "approved" },
  { id: "RYD-88408", depart: "10:15 PM", corridor: "East Bay → Payson", vehicle: "UT 715-JMD", miles: 17, anchor: "me", seats: s("me", "me", "Timpanogos Logistics", "Wasatch Foods", "me"), credits: 7, pooling: "approved" },
  { id: "RYD-88414", depart: "10:30 PM", corridor: "East Bay → Orem", vehicle: "UT 233-KRP", miles: 7, anchor: "Timpanogos Logistics", seats: s("me", "Timpanogos Logistics", "Timpanogos Logistics"), credits: 5, pooling: "open" },
  { id: "RYD-88417", depart: "10:30 PM", corridor: "East Bay → Springville", vehicle: "UT 908-FLT", miles: 5, anchor: "me", seats: s("me", "me", "Alpine Components", "me", "me"), credits: 4, pooling: "approved" },
  { id: "RYD-88421", depart: "11:00 PM", corridor: "East Bay → Lehi", vehicle: "UT 641-XNV", miles: 21, anchor: "me", seats: s("me", "me"), credits: 8, pooling: "exclusive" },
];

export function seatStats(t: Trip) {
  const filled = t.seats.filter(Boolean).length;
  const mine = t.seats.filter((x) => x === "me").length;
  const others = t.seats.filter((x) => x && x !== "me") as string[];
  const byOrg = others.reduce<Record<string, number>>((acc, o) => {
    acc[o] = (acc[o] || 0) + 1;
    return acc;
  }, {});
  return { filled, mine, empty: t.seats.length - filled, byOrg, orgs: Object.keys(byOrg) };
}

/**
 * Totals across a set of runs, for the departures board.
 *
 * The subtle one is `vehicles`. A Trip *is* a vehicle on a corridor — you can't
 * consolidate riders bound for Payson and Lehi into one van. So the vehicle
 * count doesn't fall when pooling is switched off; what changes is how many
 * seats you have to pay for. Pooled, you pay for the seats your staff sat in.
 * Unpooled, you charter the whole van and pay for every seat on it, occupied or
 * not. That difference is the entire pooling argument, so it is derived here
 * rather than written into copy.
 */
export function boardTotals(rows: Trip[]) {
  const seats = rows.reduce((a, t) => a + t.seats.length, 0);
  const filled = rows.reduce((a, t) => a + seatStats(t).filled, 0);
  const mine = rows.reduce((a, t) => a + seatStats(t).mine, 0);
  const vehicles = rows.filter((t) => t.seats.some((x) => x === "me")).length;
  return {
    seats,
    filled,
    mine,
    vehicles,
    fill: seats ? Math.round((filled / seats) * 100) : 0,
    billedPooled: mine,
    billedExclusive: vehicles * SEATS_PER_VEHICLE,
  };
}

export function corridorByName(name: string) {
  return corridors.find((c) => c.name === name);
}

/* ---------------------------------------------------------------- people */

export type Person = {
  id: string;
  initials: string;
  name: string;
  department: string;
  costCenter: string;
  entitlement: string;
  balance: number;
  source: "Workday" | "Deputy" | "Manual";
  status: "Active" | "Needs review" | "No entitlement";
  city: string;
};

export const people: Person[] = [
  { id: "E-1041", initials: "MR", name: "Maria Ruiz", department: "Production", costCenter: "CC-4100", entitlement: "60 cr / week", balance: 54, source: "Workday", status: "Active", city: "Spanish Fork" },
  { id: "E-1078", initials: "DN", name: "Derek Nielsen", department: "Production", costCenter: "CC-4100", entitlement: "60 cr / week", balance: 18, source: "Workday", status: "Active", city: "Payson" },
  { id: "E-1102", initials: "AP", name: "Ashley Pratt", department: "Customer Support", costCenter: "CC-4210", entitlement: "30 cr / week", balance: 30, source: "Workday", status: "Active", city: "Orem" },
  { id: "E-1119", initials: "JT", name: "Jordan Tso", department: "Production", costCenter: "CC-4100", entitlement: "60 cr / week", balance: 6, source: "Workday", status: "Active", city: "Springville" },
  { id: "E-1155", initials: "BH", name: "Brianna Hansen", department: "Warehouse", costCenter: "CC-4150", entitlement: "36 cr / week", balance: 27, source: "Deputy", status: "Active", city: "Salem" },
  { id: "E-1160", initials: "KO", name: "Kevin Olsen", department: "Head Office", costCenter: "CC-4300", entitlement: "—", balance: 0, source: "Manual", status: "No entitlement", city: "Provo" },
  { id: "E-1204", initials: "SM", name: "Sam Merrill", department: "—", costCenter: "—", entitlement: "—", balance: 0, source: "Workday", status: "Needs review", city: "—" },
  { id: "E-1211", initials: "TA", name: "Tyler Ashby", department: "Production", costCenter: "CC-4100", entitlement: "60 cr / week", balance: 42, source: "Workday", status: "Active", city: "Spanish Fork" },
];

/**
 * Real headcount per department.
 *
 * `people` above is a visible sample of eight; the synced organization is 412
 * staff (see `syncLog`). Allocation sizing must read these numbers — deriving a
 * headcount by scaling the eight sample rows against the 412 *shift* count
 * mixes two different units.
 */
export const departments: { name: string; headcount: number; entitled: boolean }[] = [
  { name: "Production", headcount: 148, entitled: true },
  { name: "Customer Support", headcount: 96, entitled: true },
  { name: "Warehouse", headcount: 74, entitled: true },
  { name: "Head Office", headcount: 62, entitled: false },
];

export const unassignedHeadcount = 32;

export const totalHeadcount =
  departments.reduce((a, d) => a + d.headcount, 0) + unassignedHeadcount;

export const entitledHeadcount = departments
  .filter((d) => d.entitled)
  .reduce((a, d) => a + d.headcount, 0);

export function headcountFor(department: string) {
  return departments.find((d) => d.name === department)?.headcount ?? 0;
}

/* ---------------------------------------------------------------- ledger */

export type LedgerEntry = {
  at: string;
  kind: string;
  from: string;
  to: string;
  ref: string;
  credits: number;
};

export const ledger: LedgerEntry[] = [
  { at: "Jul 27, 6:00 AM", kind: "Allocation", from: "Company float", to: "Production · 148 staff", ref: "RULE-NIGHT-60", credits: -8880 },
  { at: "Jul 27, 6:00 AM", kind: "Reclaim", from: "L. Mhaka wallet", to: "Company float", ref: "TERMINATION", credits: 33 },
  { at: "Jul 26, 10:20 PM", kind: "Pool rebate", from: "Rydlnk clearing", to: "Company float", ref: "SEAT-88414-S3 · sold to Timpanogos", credits: 2 },
  { at: "Jul 26, 10:18 PM", kind: "Consumption", from: "M. Ruiz wallet", to: "Seat 88412-S1", ref: "BOARDING-PIN", credits: -6 },
  { at: "Jul 26, 10:15 PM", kind: "No-show charge", from: "J. Tso wallet", to: "Seat 88417-S4", ref: "MANIFEST-LOCK", credits: -4 },
  { at: "Jul 26, 6:02 PM", kind: "Hold", from: "D. Nielsen wallet", to: "Seat 88408-S2", ref: "HOLD", credits: -7 },
  { at: "Jul 25, 9:11 AM", kind: "Purchase", from: "Card ****4417", to: "Company float", ref: "INV-2026-0417", credits: 12000 },
  { at: "Jul 24, 6:00 AM", kind: "Expiry", from: "Support wallets", to: "Company float", ref: "CYCLE-END", credits: 318 },
];

/* -------------------------------------------------------------- corridors */

export type Corridor = {
  name: string;
  /** Destination community, matched against `places` in lib/geo. */
  destination: string;
  stops: number;
  miles: number;
  departures: string[];
  avgRiders: number;
  credits: number;
  pooling: "open" | "approved" | "exclusive";
  guaranteed: number;
};

export const corridors: Corridor[] = [
  { name: "East Bay → Spanish Fork", destination: "Spanish Fork", stops: 6, miles: 10, departures: ["6:00 AM", "2:00 PM", "10:15 PM"], avgRiders: 6.4, credits: 6, pooling: "approved", guaranteed: 5 },
  { name: "East Bay → Payson", destination: "Payson", stops: 4, miles: 17, departures: ["6:00 AM", "10:15 PM"], avgRiders: 5.2, credits: 7, pooling: "approved", guaranteed: 4 },
  { name: "East Bay → Orem", destination: "Orem", stops: 5, miles: 7, departures: ["6:00 AM", "2:00 PM", "10:30 PM"], avgRiders: 5.8, credits: 5, pooling: "open", guaranteed: 3 },
  { name: "East Bay → Springville", destination: "Springville", stops: 5, miles: 5, departures: ["10:30 PM"], avgRiders: 6.1, credits: 4, pooling: "approved", guaranteed: 5 },
  { name: "East Bay → Lehi", destination: "Lehi", stops: 3, miles: 21, departures: ["6:00 AM", "11:00 PM"], avgRiders: 3.2, credits: 8, pooling: "exclusive", guaranteed: 8 },
];

export const roster = [
  { name: "M. Ruiz", shifts: ["10:00 PM", "10:00 PM", "10:00 PM", "10:00 PM", "—", "—", "—"] },
  { name: "D. Nielsen", shifts: ["6:00 AM", "6:00 AM", "—", "6:00 AM", "6:00 AM", "6:00 AM", "—"] },
  { name: "A. Pratt", shifts: ["2:00 PM", "2:00 PM", "2:00 PM", "—", "—", "10:00 PM", "10:00 PM"] },
  { name: "J. Tso", shifts: ["—", "10:00 PM", "10:00 PM", "10:00 PM", "10:00 PM", "—", "—"] },
  { name: "B. Hansen", shifts: ["6:00 AM", "6:00 AM", "6:00 AM", "6:00 AM", "—", "—", "—"] },
  { name: "T. Ashby", shifts: ["10:00 PM", "—", "10:00 PM", "10:00 PM", "10:00 PM", "—", "—"] },
];

/* ----------------------------------------------------------- integrations */

export const connectors = [
  { code: "DP", name: "Deputy", color: "#e9354c", role: "Schedules", state: "connected", detail: "Nightly 6:00 AM pull plus webhooks on schedule publish", note: "412 shifts · week 31" },
  { code: "WD", name: "Workday", color: "#005cb9", role: "People", state: "connected", detail: "Workers, departments, cost centers, terminations", note: "3 unresolved" },
  { code: "NS", name: "NetSuite", color: "#1f4e79", role: "Finance", state: "connected", detail: "Posts the monthly commuter journal via SuiteTalk", note: "Next post Jul 31" },
  { code: "BH", name: "BambooHR", color: "#6ad25d", role: "People", state: "available", detail: "Workers and employment status", note: "" },
  { code: "ADP", name: "ADP Workforce Now", color: "#d0271d", role: "Payroll", state: "available", detail: "Employee master, cost centers, pre-tax benefit codes", note: "" },
  { code: "PL", name: "Paylocity", color: "#0075c9", role: "Payroll", state: "available", detail: "Employee master and deduction codes", note: "" },
  { code: "UK", name: "UKG Ready", color: "#005151", role: "Schedules", state: "available", detail: "Published schedules and time off", note: "" },
  { code: "SF", name: "Salesforce", color: "#00a1e0", role: "Field CRM", state: "available", detail: "Charge field trips to an account or opportunity", note: "" },
  { code: "HS", name: "HubSpot", color: "#ff7a59", role: "Field CRM", state: "available", detail: "Charge field trips to a deal", note: "" },
  { code: "CSV", name: "SFTP / CSV", color: "#5b6770", role: "Any system", state: "available", detail: "Drop a file, we map the columns once", note: "" },
];

export const syncLog = [
  { t: "06:00:02", level: "ok", msg: "deputy.schedules — pulled 412 shifts for week 31" },
  { t: "06:00:04", level: "ok", msg: "workday.workers — 368 active, 2 new hires, 1 termination" },
  { t: "06:00:04", level: "warn", msg: "identity — 3 records matched on email, employee number differs → review queue" },
  { t: "06:00:05", level: "ok", msg: "wallet — froze 1 wallet (termination), reclaimed 33 cr to float" },
  { t: "06:00:07", level: "ok", msg: "clustering — 412 shifts → 96 trips across 5 corridors" },
  { t: "06:00:07", level: "warn", msg: "clustering — 3 employees skipped, no geocoded home address" },
  { t: "06:00:08", level: "ok", msg: "pooling — 22 spare seats offered to approved employers" },
  { t: "06:00:08", level: "ok", msg: "manifests — 96 drafts created, awaiting publish" },
];

export const alerts = [
  { level: "bad", tag: "Low float", text: "Customer Support runs out of credits Thursday at the current burn rate.", action: "Allocate" },
  { level: "warn", tag: "Unmatched", text: "3 employees from the Workday sync have no home address, so they can't be clustered.", action: "Review" },
  { level: "warn", tag: "Policy", text: "M. Ruiz requested a 26-mile drop-off — 11 miles over the night-shift cap.", action: "Approve" },
  { level: "bad", tag: "Compliance", text: "Driver's CDL medical certificate for van UT 482-BQC expires in 6 days.", action: "Notify" },
];

export const spendByCostCenter = [
  { name: "Production — Night", cc: "CC-4100", pct: 88, amount: 11840 },
  { name: "Production — Day", cc: "CC-4105", pct: 61, amount: 8150 },
  { name: "Customer Support", cc: "CC-4210", pct: 44, amount: 5870, low: true },
  { name: "Warehouse", cc: "CC-4150", pct: 29, amount: 3840 },
  { name: "Head Office", cc: "CC-4300", pct: 12, amount: 1600 },
];
