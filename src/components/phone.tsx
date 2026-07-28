"use client";

import { useState } from "react";

type Ride = {
  when: string;
  route: string;
  meta: string;
  price: string;
  fund: "company" | "own" | "split";
  tags: string[];
};

const rides: Record<"work" | "personal", Ride[]> = {
  work: [
    { when: "Tonight", route: "East Bay → Spanish Fork", meta: "22:15 · Gate 2 · with Rudo, Farai +1", price: "4 cr", fund: "company", tags: ["Confirmed", "PIN 4417"] },
    { when: "Tue", route: "East Bay → Spanish Fork", meta: "22:15 · from your roster", price: "4 cr", fund: "company", tags: ["Auto-confirms 18:15"] },
    { when: "Thu", route: "East Bay → Spanish Fork", meta: "22:15 · 41 miles drop-off requested", price: "4 cr + $2.10", fund: "split", tags: ["Over policy cap", "You cover the difference"] },
  ],
  personal: [
    { when: "Sat", route: "Home → University Place", meta: "10:00 · 3 seats on this run", price: "$5.20", fund: "own", tags: ["Fixed fare", "No surge"] },
    { when: "Sun", route: "Home → Lehi", meta: "08:30 · shared with 2 neighbors", price: "$3.80", fund: "own", tags: ["Recurring weekly"] },
  ],
};

export function PhoneMock() {
  const [tab, setTab] = useState<"work" | "personal">("work");
  const list = rides[tab];

  return (
    <div className="relative w-[336px] max-w-full overflow-hidden rounded-[34px] border-[9px] border-[#04170f] bg-paper shadow-[0_40px_80px_-30px_rgba(0,0,0,0.65)]">
      <div className="absolute inset-x-0 top-0 z-10 mx-auto h-6 w-[120px] rounded-b-[14px] bg-[#04170f]" />

      <div className="bg-ink px-4 pb-4 pt-9 text-white">
        <p className="text-[0.78rem] text-muteddark">Good evening,</p>
        <p className="font-display text-[1.24rem] font-extrabold tracking-[-0.02em]">Tendai Moyo</p>
        <div className="mt-4 grid grid-cols-2 gap-2">
          <div className="rounded-[11px] border border-white/12 bg-white/7 p-2.5">
            <p className="font-mono text-[0.57rem] uppercase tracking-[0.11em] text-muteddark">Work credits</p>
            <p className="mt-1 font-mono text-[1.1rem] font-medium text-amber">
              36 <span className="text-[0.62rem]">cr</span>
            </p>
          </div>
          <div className="rounded-[11px] border border-white/12 bg-white/7 p-2.5">
            <p className="font-mono text-[0.57rem] uppercase tracking-[0.11em] text-muteddark">Own balance</p>
            <p className="mt-1 font-mono text-[1.1rem] font-medium text-signalbright">$8.40</p>
          </div>
        </div>
      </div>

      <div className="flex gap-1 border-b border-line bg-white p-1.5">
        {(["work", "personal"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            aria-pressed={tab === t}
            className={`flex-1 rounded-full py-2.5 font-mono text-[0.62rem] uppercase tracking-[0.1em] transition-colors ${
              tab === t ? "bg-ink text-white" : "text-muted hover:text-ink"
            }`}
          >
            {t === "work" ? "Work trips" : "My trips"}
          </button>
        ))}
      </div>

      <div className="min-h-[268px] p-3.5">
        {list.map((r) => (
          <div key={r.route + r.when} className="mb-2 rounded-[12px] border border-line bg-white p-3.5">
            <div className="flex items-start justify-between gap-2.5">
              <div className="min-w-0">
                <p className="text-[0.92rem] font-semibold">
                  <span className="text-muted">{r.when} · </span>
                  {r.route}
                </p>
                <p className="mt-0.5 font-mono text-[0.7rem] text-muted">{r.meta}</p>
              </div>
              <div className="shrink-0 text-right font-mono text-[0.78rem]">
                <b className={r.fund === "own" ? "block text-signaldim" : "block text-amberdim"}>{r.price}</b>
                <span className="text-[0.64rem] text-muted">
                  {r.fund === "company" ? "employer" : r.fund === "own" ? "your wallet" : "split"}
                </span>
              </div>
            </div>
            <div className="mt-2.5 flex flex-wrap gap-1.5">
              {r.tags.map((t) => (
                <span key={t} className="rounded-full bg-paper px-2 py-0.5 font-mono text-[0.6rem] tracking-[0.05em] text-muted">
                  {t}
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="px-3.5 pb-5">
        <button className="w-full rounded-full bg-signal py-2.5 text-[0.88rem] font-semibold text-white">
          {tab === "work" ? "Book a trip off-roster" : "Plan a trip"}
        </button>
        <p className="mt-2.5 text-center font-mono text-[0.62rem] text-muted">
          {tab === "work" ? "36 credits expire Monday 06:00" : "Top up from $2"}
        </p>
      </div>
    </div>
  );
}
