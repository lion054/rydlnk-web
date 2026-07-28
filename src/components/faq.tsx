"use client";

import { useId, useState } from "react";

export type QA = { q: string; a: string };

export function Faq({ items }: { items: QA[] }) {
  const [open, setOpen] = useState<number | null>(0);
  const id = useId();

  return (
    <div className="border-t border-line">
      {items.map((item, i) => {
        const isOpen = open === i;
        const panelId = `${id}-panel-${i}`;
        const buttonId = `${id}-button-${i}`;
        return (
          <div key={item.q} className="border-b border-line">
            <h3>
              <button
                id={buttonId}
                onClick={() => setOpen(isOpen ? null : i)}
                aria-expanded={isOpen}
                aria-controls={panelId}
                className="flex w-full items-center justify-between gap-4 py-5 text-left text-[1rem] font-semibold"
              >
                {item.q}
                <span className="shrink-0 font-mono text-lg text-signaldim" aria-hidden>
                  {isOpen ? "–" : "+"}
                </span>
              </button>
            </h3>
            {/* Kept mounted and hidden rather than unmounted, so answers stay
                findable with the browser's own find-in-page. */}
            <div id={panelId} role="region" aria-labelledby={buttonId} hidden={!isOpen}>
              <p className="max-w-[78ch] pb-5 text-[0.94rem] text-muted">{item.a}</p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
