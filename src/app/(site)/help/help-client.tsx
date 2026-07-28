"use client";

import { useMemo, useState } from "react";
import { Faq, type QA } from "@/components/faq";
import * as Icon from "@/components/icons";

export type HelpGroup = { audience: "Riders" | "Employers"; topic: string; items: QA[] };

/**
 * One help center replacing /individual/faq and /work/faq.
 *
 * Two FAQ pages behind two nav entries meant a rider question and an employer
 * question about the same mechanic lived on different pages. This filters one
 * corpus by audience and searches across all of it.
 */
export function HelpCentre({ groups }: { groups: HelpGroup[] }) {
  const [q, setQ] = useState("");
  const [audience, setAudience] = useState<"All" | "Riders" | "Employers">("All");

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return groups
      .filter((g) => audience === "All" || g.audience === audience)
      .map((g) => ({
        ...g,
        items: needle
          ? g.items.filter((i) => `${i.q} ${i.a}`.toLowerCase().includes(needle))
          : g.items,
      }))
      .filter((g) => g.items.length > 0);
  }, [groups, q, audience]);

  const total = filtered.reduce((a, g) => a + g.items.length, 0);

  return (
    <>
      <div className="sticky top-[68px] z-20 border-b border-line bg-paper/95 py-4 backdrop-blur-md">
        <div className="wrap flex flex-wrap items-center gap-3">
          <div className="relative min-w-0 flex-1">
            <Icon.Search
              size={17}
              className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-muted"
            />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              type="search"
              placeholder="Search help…"
              aria-label="Search help"
              className="w-full rounded-full border border-linestrong bg-white py-3 pl-11 pr-4 text-base focus:border-signal focus:outline-none"
            />
          </div>
          <div className="flex gap-1 rounded-full border border-line bg-white p-1">
            {(["All", "Riders", "Employers"] as const).map((a) => (
              <button
                key={a}
                onClick={() => setAudience(a)}
                aria-pressed={audience === a}
                className={`label rounded-full px-4 py-2 transition-colors ${
                  audience === a ? "bg-ink text-white" : "text-muted hover:text-ink"
                }`}
              >
                {a}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="wrap py-14">
        <p className="text-xs text-muted" aria-live="polite">
          {total} {total === 1 ? "answer" : "answers"}
          {q ? ` matching “${q}”` : ""}
        </p>

        {filtered.length === 0 ? (
          <div className="mt-8 rounded-card border border-line bg-white p-10 text-center">
            <p className="text-lg font-extrabold tracking-[-0.015em]">Nothing matches that.</p>
            <p className="mx-auto mt-2 max-w-[46ch] text-base text-muted">
              Try a shorter phrase, or ask us directly — we answer within one business day.
            </p>
            <a
              href="/contact"
              className="mt-6 inline-flex min-h-[44px] items-center gap-2 rounded-full bg-signal px-6 font-semibold text-white transition-colors hover:bg-signaldim"
            >
              Ask a question <Icon.ArrowRight size={16} />
            </a>
          </div>
        ) : (
          <div className="mt-8 space-y-12">
            {filtered.map((g) => (
              <section key={`${g.audience}-${g.topic}`}>
                <div className="flex items-baseline gap-3">
                  <h2 className="text-xl font-extrabold tracking-[-0.02em]">{g.topic}</h2>
                  <span className="label rounded-full bg-shell px-2.5 py-1 text-muted">{g.audience}</span>
                </div>
                <div className="mt-4">
                  <Faq items={g.items} />
                </div>
              </section>
            ))}
          </div>
        )}
      </div>
    </>
  );
}
