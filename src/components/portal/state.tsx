"use client";

import { createContext, useContext, useMemo, type ReactNode } from "react";

/**
 * Portal session context.
 *
 * Now hydrated from the database by the layout rather than seeded with mock
 * values. The float and the approval count are shared because the rail renders
 * the balance while People spends it, and the top bar badges the queue while
 * Approvals drains it — all three have to be looking at the same number.
 *
 * Mutations go through server actions, which revalidate and push new values
 * down. Nothing writes to this context directly.
 */

type PortalState = {
  companyId: string;
  companyName: string;
  role: "owner" | "admin" | "finance" | "manager" | "viewer";
  userEmail: string;
  float: number;
  pendingApprovals: number;
  canAdminister: boolean;
  canSpend: boolean;
};

const Ctx = createContext<PortalState | null>(null);

export function PortalProvider({ value, children }: { value: PortalState; children: ReactNode }) {
  const memo = useMemo(() => value, [
    value.companyId,
    value.companyName,
    value.role,
    value.userEmail,
    value.float,
    value.pendingApprovals,
  ]);
  return <Ctx.Provider value={memo}>{children}</Ctx.Provider>;
}

export function usePortal() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("usePortal must be used inside <PortalProvider>");
  return ctx;
}
