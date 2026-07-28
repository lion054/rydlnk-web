"use client";

import { useState, useTransition } from "react";
import { Panel } from "@/components/portal/chrome";
import { Button } from "@/components/ui";
import * as Icon from "@/components/icons";
import { CREDIT_VALUE } from "@/lib/data";
import { topUpFloat } from "../actions";

/**
 * Fund the float.
 *
 * Until Stripe keys are in, this posts a manual `topup` ledger entry so the
 * rest of the system — allocation, holds, settlement — can be exercised
 * end to end. The button says so plainly rather than pretending a card was
 * charged. Once `stripe-company-topup` exists it takes over and this becomes
 * the fallback for wire transfers, which a finance team will want anyway.
 */
export function TopUpPanel({ companyId, connected }: { companyId: string; connected: boolean }) {
  const [credits, setCredits] = useState(2000);
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);

  function submit() {
    startTransition(async () => {
      const res = await topUpFloat(companyId, credits);
      setNotice(res.ok ? res.message : res.error);
    });
  }

  return (
    <Panel title="Add credits">
      <div className="grid gap-5 p-5 lg:grid-cols-[1fr_auto] lg:items-end lg:p-6">
        <div>
          <label htmlFor="credits" className="label mb-1.5 block">
            Credits to add
          </label>
          <div className="flex flex-wrap items-center gap-3">
            <input
              id="credits"
              type="number"
              min={100}
              step={100}
              value={credits}
              onChange={(e) => setCredits(Math.max(100, Number(e.target.value) || 100))}
              className="w-40 rounded-sm border border-linestrong px-3.5 py-2.5 text-base focus:border-signal focus:outline-none"
            />
            <span className="nums text-base text-muted">
              = ${(credits * CREDIT_VALUE).toLocaleString()}.00
            </span>
            <span className="flex gap-1.5">
              {[1000, 2500, 5000].map((v) => (
                <button
                  key={v}
                  onClick={() => setCredits(v)}
                  className="rounded-full border border-line px-3 py-1.5 text-xs font-semibold text-muted transition-colors hover:border-signal hover:text-ink"
                >
                  {v.toLocaleString()}
                </button>
              ))}
            </span>
          </div>
          <p className="mt-2.5 text-xs text-muted">
            {connected
              ? "Charged to your saved payment method."
              : "Stripe isn't connected — this records the top-up against the ledger so you can test allocation and settlement. Wire it to Stripe before taking real money."}
          </p>
        </div>

        <Button onClick={submit} disabled={pending}>
          {pending ? "Working…" : `Add ${credits.toLocaleString()} cr`}
          {!pending ? <Icon.ArrowRight size={16} /> : null}
        </Button>
      </div>

      {notice ? (
        <p role="status" className="flex items-center gap-2.5 border-t border-line px-5 py-3 text-base">
          <Icon.Check size={17} className="text-signal" />
          {notice}
        </p>
      ) : null}
    </Panel>
  );
}
