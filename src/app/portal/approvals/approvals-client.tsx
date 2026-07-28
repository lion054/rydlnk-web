"use client";

import { useState, useTransition } from "react";
import { EmptyState, Panel } from "@/components/portal/chrome";
import { Button, Chip } from "@/components/ui";
import * as Icon from "@/components/icons";
import { decideApproval } from "../actions";

export type ApprovalRow = {
  id: string;
  ride_id: string | null;
  rider_id: string;
  reason: string;
  detail: string | null;
  company_credits: number;
  personal_cents: number;
  created_at: string;
  expires_at: string;
  rider_name?: string | null;
};

const REASONS: Record<string, string> = {
  over_trip_cap: "Over the per-trip cap",
  over_distance_cap: "Over the distance cap",
  over_weekly_cap: "Over the weekly cap",
  off_roster: "Not on the published roster",
  outside_funded_days: "Outside funded days",
  outside_funded_hours: "Outside funded hours",
  corridor_not_allowed: "Corridor not approved",
};

export function ApprovalsClient({
  rows,
  float,
  canDecide,
}: {
  rows: ApprovalRow[];
  float: number;
  canDecide: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const total = rows.reduce((a, r) => a + r.company_credits, 0);

  function decide(id: string, decision: "approved" | "declined") {
    setBusy(id);
    startTransition(async () => {
      const res = await decideApproval(id, decision);
      setBusy(null);
      setNotice(res.ok ? res.message : res.error);
    });
  }

  return (
    <div className="space-y-4 p-5 lg:p-7">
      {notice ? (
        <p role="status" className="flex items-center gap-2.5 rounded-card border border-line bg-white px-4 py-3 text-base">
          <Icon.Check size={17} className="text-signal" />
          {notice}
        </p>
      ) : null}

      <Panel
        title="Over policy"
        actions={
          rows.length > 0 ? (
            <span className="nums text-xs text-muted">{total} cr if you approve everything</span>
          ) : null
        }
      >
        {rows.length === 0 ? (
          <EmptyState
            title="Nothing waiting."
            body="Trips inside policy confirm on their own — only exceptions land here. This being empty is the good outcome."
            action={
              <Button href="/portal/trips" variant="ghost" size="sm">
                See tonight&apos;s manifests
              </Button>
            }
          />
        ) : (
          <div className="divide-y divide-line">
            {rows.map((a) => (
              <article key={a.id} className="grid gap-4 p-5 lg:grid-cols-[1fr_auto] lg:items-center lg:p-6">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2.5">
                    <h3 className="text-base font-semibold">{a.rider_name ?? "Employee"}</h3>
                    <Chip tone="warn">{REASONS[a.reason] ?? a.reason}</Chip>
                  </div>
                  {a.detail ? <p className="mt-1.5 text-base text-muted">{a.detail}</p> : null}
                  <dl className="nums mt-3 flex flex-wrap gap-x-6 gap-y-1 text-xs text-muted">
                    <div className="flex gap-1.5">
                      <dt>Company pays</dt>
                      <dd className="font-semibold text-ink">{a.company_credits} cr</dd>
                    </div>
                    {a.personal_cents > 0 ? (
                      <div className="flex gap-1.5">
                        <dt>Employee covers</dt>
                        <dd className="font-semibold text-ink">${(a.personal_cents / 100).toFixed(2)}</dd>
                      </div>
                    ) : null}
                    <div className="flex gap-1.5">
                      <dt>Float after</dt>
                      <dd className="font-semibold text-ink">{(float - a.company_credits).toLocaleString()} cr</dd>
                    </div>
                  </dl>
                </div>

                {canDecide ? (
                  <div className="flex shrink-0 gap-2">
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={pending && busy === a.id}
                      onClick={() => decide(a.id, "declined")}
                    >
                      Decline
                    </Button>
                    <Button
                      size="sm"
                      disabled={pending && busy === a.id}
                      onClick={() => decide(a.id, "approved")}
                    >
                      {busy === a.id ? "Working…" : `Approve ${a.company_credits} cr`}
                    </Button>
                  </div>
                ) : (
                  <p className="text-xs text-muted">Ask an admin or manager to decide.</p>
                )}
              </article>
            ))}
          </div>
        )}
      </Panel>
    </div>
  );
}
