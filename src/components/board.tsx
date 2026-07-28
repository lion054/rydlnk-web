"use client";

import { useMemo, useState } from "react";
import { trips, seatStats, boardTotals } from "@/lib/data";
import { SeatPips } from "./ui";

export function DeparturesBoard() {
  const [pooled, setPooled] = useState(true);

  const rows = useMemo(
    () =>
      trips.map((t) => ({
        ...t,
        seats: pooled ? t.seats : t.seats.map((s) => (s === "me" ? s : null)),
      })),
    [pooled],
  );

  const totals = boardTotals(rows);
  const billed = pooled ? totals.billedPooled : totals.billedExclusive;

  return (
    <div>
      <div className="overflow-hidden rounded-[14px] border border-white/12 bg-ink shadow-[0_30px_60px_-30px_rgba(0,0,0,0.7)]">
        <div className="flex items-center justify-between border-b border-white/12 bg-gradient-to-b from-forest to-ink px-4 py-3">
          <span className="font-mono text-[0.68rem] uppercase tracking-[0.16em] text-muteddark">Tonight · East Bay · departures</span>
          <span className="flex items-center gap-2 font-mono text-[0.68rem] tracking-[0.1em] text-signalbright">
            <i className="h-1.5 w-1.5 animate-pulse rounded-full bg-signalbright" />
            live
          </span>
        </div>

        {rows.map((t) => {
          const s = seatStats(t);
          return (
            <div key={t.id} className="grid grid-cols-[52px_1fr_auto_54px] items-center gap-3 border-b border-white/6 px-4 py-3 font-mono text-[0.78rem] text-[#dce9e3] last:border-b-0">
              <span className="font-medium text-amber">{t.depart}</span>
              <span className="min-w-0">
                <span className="block truncate font-body text-[0.88rem] font-medium tracking-normal text-white">{t.corridor}</span>
                <span className="mt-0.5 block font-mono text-[0.64rem] uppercase tracking-[0.07em] text-muteddark">
                  {t.vehicle} · {s.orgs.length ? `+${s.orgs.join(", ")}` : "your staff only"}
                </span>
              </span>
              <SeatPips seats={t.seats} />
              <span className="text-right font-medium text-amber">{t.credits} cr</span>
            </div>
          );
        })}

        <div className="flex flex-wrap justify-between gap-3 bg-white/3 px-4 py-3 font-mono text-[0.68rem] tracking-[0.06em] text-muteddark">
          <span>
            fill <b className="font-medium text-white">{totals.fill}%</b>
          </span>
          <span>
            your staff <b className="font-medium text-white">{totals.mine}</b>
          </span>
          <span>
            vehicles <b className="font-medium text-white">{totals.vehicles}</b>
          </span>
          <span>
            you pay for{" "}
            <b className={`font-medium ${pooled ? "text-signalbright" : "text-amber"}`}>{billed} seats</b>
          </span>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 font-mono text-[0.64rem] tracking-[0.06em] text-muteddark">
        <button
          onClick={() => setPooled((p) => !p)}
          className="flex items-center gap-2 rounded-full border border-white/20 px-3 py-1.5 text-white transition-colors hover:border-amber"
          aria-pressed={pooled}
        >
          <span className={`h-2 w-2 rounded-full ${pooled ? "bg-signalbright" : "bg-white/30"}`} />
          pooling {pooled ? "on" : "off"}
        </button>
        <span className="flex items-center gap-1.5">
          <i className="h-2 w-2 rounded-[3px] bg-signalbright" /> your staff
        </span>
        <span className="flex items-center gap-1.5">
          <i className="h-2 w-2 rounded-[3px] bg-white/55" /> other employers
        </span>
        <span className="flex items-center gap-1.5">
          <i className="h-2 w-2 rounded-[3px] bg-white/15" /> empty
        </span>
      </div>

      <p className="mt-3 max-w-[46ch] text-[0.82rem] text-muteddark" aria-live="polite">
        {pooled ? (
          <>
            Pooled, these {totals.vehicles} runs carry {totals.filled} people and you pay for the{" "}
            <b className="font-medium text-white">{totals.billedPooled} seats</b> your staff sat in.
          </>
        ) : (
          <>
            On your own, the same {totals.vehicles} runs carry only your {totals.mine} people — but you
            charter the whole vehicle, so you pay for all{" "}
            <b className="font-medium text-white">{totals.billedExclusive} seats</b>.
          </>
        )}
      </p>
    </div>
  );
}
