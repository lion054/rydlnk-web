"use client";

import { useState } from "react";
import { PLATFORM_FEE, POOL_REBATE_PER_SEAT, SEATS_PER_VEHICLE, WEEKS_PER_MONTH } from "@/lib/data";

const SEAT_PRICE = 4; // credits, mid-corridor

/** How full your own staff leave a vehicle on a corridor — the 78% on /work. */
const OWN_FILL = 0.78;

export function PricingEstimator() {
  const [staff, setStaff] = useState(150);
  const [tripsPerWeek, setTripsPerWeek] = useState(10);
  const [mode, setMode] = useState<"pooled" | "exclusive">("pooled");

  /* Employee-trips a month. Everything else is derived from this. */
  const seats = staff * tripsPerWeek * WEEKS_PER_MONTH;
  const platform = staff * PLATFORM_FEE;

  /* Vehicles your roster actually needs, given you don't fill them perfectly. */
  const vehicles = seats / (SEATS_PER_VEHICLE * OWN_FILL);
  const spareSeats = vehicles * SEATS_PER_VEHICLE - seats;

  /* One seat price in both modes. The difference isn't a rate premium — it's
     who pays for the empty seats. Pooled, you're billed only for the seats your
     staff sat in, and the spare ones rebate when another employer buys them.
     Exclusive, you charter the vehicle and buy every seat on it, full or not.
     The rebate scales with spare seats freed up, never with your own
     consumption. */
  const billedSeats = mode === "pooled" ? seats : vehicles * SEATS_PER_VEHICLE;
  const rebate = mode === "pooled" ? spareSeats * POOL_REBATE_PER_SEAT : 0;

  const creditSpend = billedSeats * SEAT_PRICE;
  const total = creditSpend + platform - rebate;
  const perTrip = total / seats;

  const money = (n: number) => `$${Math.round(n).toLocaleString()}`;

  return (
    <div className="overflow-hidden rounded-[16px] border border-line bg-white">
      <div className="grid gap-8 p-6 lg:grid-cols-[1fr_320px] lg:p-7">
        <div className="space-y-5">
          <div>
            <label htmlFor="staff" className="mb-2 flex items-baseline justify-between text-[0.82rem] font-semibold">
              Staff who commute on Rydlnk
              <span className="font-mono text-[0.8rem] text-muted">{staff}</span>
            </label>
            <input
              id="staff"
              type="range"
              min={25}
              max={800}
              step={25}
              value={staff}
              onChange={(e) => setStaff(Number(e.target.value))}
              className="w-full accent-signal h-6"
            />
          </div>

          <div>
            <label htmlFor="trips" className="mb-2 flex items-baseline justify-between text-[0.82rem] font-semibold">
              Trips per person per week
              <span className="font-mono text-[0.8rem] text-muted">{tripsPerWeek}</span>
            </label>
            <input
              id="trips"
              type="range"
              min={2}
              max={14}
              value={tripsPerWeek}
              onChange={(e) => setTripsPerWeek(Number(e.target.value))}
              className="w-full accent-signal h-6"
            />
            <p className="mt-1.5 font-mono text-[0.72rem] text-muted">
              10 = a five-day shift pattern, both directions.
            </p>
          </div>

          <div>
            <span className="mb-2 block text-[0.82rem] font-semibold">Corridor policy</span>
            <div className="flex gap-1 rounded-full border border-line p-0.5">
              {(["pooled", "exclusive"] as const).map((m) => (
                <button
                  key={m}
                  onClick={() => setMode(m)}
                  aria-pressed={mode === m}
                  className={`flex-1 rounded-full py-2 font-mono text-[0.68rem] uppercase tracking-[0.09em] transition-colors ${
                    mode === m ? "bg-ink text-white" : "text-muted hover:text-ink"
                  }`}
                >
                  {m === "pooled" ? "Pooled" : "Exclusive"}
                </button>
              ))}
            </div>
            <p className="mt-2 text-[0.82rem] text-muted" aria-live="polite">
              {mode === "pooled"
                ? `Shared with approved employers on the same corridor. You're billed for the seats your staff sat in, and the ${Math.round(spareSeats).toLocaleString()} spare ones rebate back to your float when somebody else buys them.`
                : `Your staff alone in the vehicle. Same seat price — but you buy all ${Math.round(billedSeats).toLocaleString()} seats on the vehicles you charter, including the ${Math.round(spareSeats).toLocaleString()} nobody sits in.`}
            </p>
          </div>
        </div>

        <aside className="self-start rounded-[12px] bg-paper p-5">
          <p className="font-mono text-[0.62rem] uppercase tracking-[0.13em] text-muted">Estimated monthly</p>
          <p className="mt-1.5 font-display text-[2.4rem] font-extrabold leading-none tracking-[-0.03em]">{money(total)}</p>
          <dl className="mt-5 space-y-2 font-mono text-[0.76rem]">
            <div className="flex justify-between text-muted">
              <dt>Seats billed · {Math.round(billedSeats).toLocaleString()}</dt>
              <dd>{money(creditSpend)}</dd>
            </div>
            {mode === "exclusive" ? (
              <div className="flex justify-between text-flag">
                <dt>…of which empty</dt>
                <dd>{Math.round(spareSeats).toLocaleString()}</dd>
              </div>
            ) : null}
            <div className="flex justify-between text-muted">
              <dt>Platform · {staff} staff</dt>
              <dd>{money(platform)}</dd>
            </div>
            {rebate > 0 ? (
              <div className="flex justify-between text-signaldim">
                <dt>Pool rebate · {Math.round(spareSeats).toLocaleString()} spare</dt>
                <dd>−{money(rebate)}</dd>
              </div>
            ) : null}
            <div className="flex justify-between border-t border-line pt-2 font-medium">
              <dt>Per employee trip</dt>
              <dd>${perTrip.toFixed(2)}</dd>
            </div>
          </dl>
          <p className="mt-4 text-[0.78rem] text-muted">
            Indicative only, at $1.00 per credit, a {SEAT_PRICE}-credit mid-length Utah County corridor and{" "}
            {Math.round(OWN_FILL * 100)}% seat fill. Real quotes are built from your actual corridors and shift
            pattern.
          </p>
        </aside>
      </div>
    </div>
  );
}
