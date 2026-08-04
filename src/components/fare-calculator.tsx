"use client";

import { useState } from "react";
import { CORRIDOR_FARES, WEEKS_PER_MONTH } from "@/lib/data";

/* Fares come from lib/data.ts, not from a table here. The `solo` figures are
   Lyft-derived and drive the "% cheaper" claim, so they belong with the other
   shared rate constants where a change is visible to anyone auditing the claim
   — not inlined in one component where the pricing page and this calculator can
   silently disagree. */
const routes = CORRIDOR_FARES;

export function FareCalculator() {
  const [route, setRoute] = useState(0);
  const [days, setDays] = useState(5);
  const r = routes[route];

  const trips = days * 2;
  const weekly = trips * r.seat;
  const solo = trips * r.solo;
  const saved = solo - weekly;

  /* Percentage saved is a property of the corridor, not of how often you ride —
     both sides scale linearly with `trips`, so this figure is constant across
     the slider by definition. It's labelled as a per-seat fact rather than
     driving a progress bar that would never move. The bars below are scaled
     against a full seven-day week, so they do respond to the slider. */
  const pct = Math.round((1 - r.seat / r.solo) * 100);
  const maxSolo = 7 * 2 * r.solo;

  return (
    <div className="overflow-hidden rounded-[16px] border border-line bg-white">
      <div className="grid gap-6 p-6 sm:grid-cols-2">
        <div>
          <label htmlFor="route" className="mb-2 block text-[0.8rem] font-semibold">
            Your commute
          </label>
          <select
            id="route"
            value={route}
            onChange={(e) => setRoute(Number(e.target.value))}
            className="w-full rounded-[9px] border border-linestrong bg-white px-3 py-2.5 text-[0.9rem] focus:border-signal focus:outline-none"
          >
            {routes.map((x, i) => (
              <option key={x.name} value={i}>
                {x.name} · {x.miles} miles
              </option>
            ))}
          </select>

          <label htmlFor="days" className="mb-2 mt-5 block text-[0.8rem] font-semibold">
            Days a week <span className="font-mono text-muted">({days} · {trips} trips)</span>
          </label>
          <input
            id="days"
            type="range"
            min={1}
            max={7}
            value={days}
            onChange={(e) => setDays(Number(e.target.value))}
            className="w-full accent-signal h-6"
          />
          <p className="mt-3 font-mono text-[0.72rem] text-muted">
            Seat fare is fixed at ${r.seat.toFixed(2)} — it doesn&apos;t change with traffic, weather or how many people
            book.
          </p>
        </div>

        <div className="rounded-[12px] bg-paper p-5">
          <p className="font-mono text-[0.62rem] uppercase tracking-[0.13em] text-muted">Your week on Rydlnk</p>
          <p className="mt-1 font-display text-[2.6rem] font-extrabold leading-none tracking-[-0.03em]">
            ${weekly.toFixed(2)}
          </p>
          <div className="mt-4 space-y-2.5 font-mono text-[0.76rem]">
            <div>
              <div className="flex justify-between font-medium text-signaldim">
                <span>On Rydlnk</span>
                <span>${weekly.toFixed(2)}</span>
              </div>
              <div className="mt-1 h-2 overflow-hidden rounded-full bg-line">
                <div
                  className="h-full rounded-full bg-signal transition-[width] duration-300"
                  style={{ width: `${(weekly / maxSolo) * 100}%` }}
                />
              </div>
            </div>
            <div>
              <div className="flex justify-between text-muted">
                <span>Booking alone</span>
                <span>${solo.toFixed(2)}</span>
              </div>
              <div className="mt-1 h-2 overflow-hidden rounded-full bg-line">
                <div
                  className="h-full rounded-full bg-muted/50 transition-[width] duration-300"
                  style={{ width: `${(solo / maxSolo) * 100}%` }}
                />
              </div>
            </div>
          </div>
          <p className="mt-3.5 border-t border-line pt-3 font-mono text-[0.68rem] text-muted">
            You keep <b className="font-medium text-signaldim">${saved.toFixed(2)}</b> a week ·{" "}
            <b className="font-medium text-signaldim">${(saved * WEEKS_PER_MONTH).toFixed(0)}</b> a month
          </p>
          <p className="mt-1 font-mono text-[0.68rem] text-muted">
            A seat on this corridor is {pct}% cheaper than booking alone, however often you ride.
          </p>
        </div>
      </div>
      {/* The savings figure above is a comparative claim, so the basis for it
          has to travel with it. Described by category rather than by brand:
          naming a specific operator raises trademark and comparative-advertising
          questions that are a decision for counsel, not a default. */}
      <p className="border-t border-line bg-paper/60 px-6 py-3 font-mono text-[0.66rem] text-muted">
        Indicative fares for the Utah County corridors currently running. Your employer can cover some or all of this.
        &ldquo;Booking alone&rdquo; is the fare for the same trip as a single rider on a typical on-demand ride-hail
        service, before surge pricing.
      </p>
    </div>
  );
}
