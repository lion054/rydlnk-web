"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui";
import { decideDriver, refundCompanyTopup, setCompanySuspension, setPlatformStaff, setUserDisabled } from "./actions";

export function ReasonedAction({
  kind, targetId, active,
}: { kind: "company" | "driver"; targetId: string; active: boolean }) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  const label = kind === "company"
    ? (active ? "Suspend" : "Reactivate")
    : (active ? "Reject" : "Approve");

  return (
    <div className="inline-flex items-center gap-2">
      <Button size="sm" variant="ghost" disabled={pending} onClick={() => {
        const reason = window.prompt(`Reason required to ${label.toLowerCase()} this ${kind}:`)?.trim();
        if (!reason) return;
        startTransition(async () => {
          const result = kind === "company"
            ? await setCompanySuspension(targetId, active, reason)
            : await decideDriver(targetId, !active, reason);
          setNotice(result.ok ? result.message : result.error);
        });
      }}>{pending ? "Working…" : label}</Button>
      {notice ? <span className="max-w-48 text-xs text-muted">{notice}</span> : null}
    </div>
  );
}

export function StaffManager() {
  const [pending, startTransition] = useTransition();
  const [userId, setUserId] = useState("");
  const [role, setRole] = useState<"dispatcher" | "operations_admin">("dispatcher");
  const [reason, setReason] = useState("");
  const [notice, setNotice] = useState<string | null>(null);
  const field = "rounded-sm border border-linestrong px-3 py-2 text-sm focus:border-signal focus:outline-none";
  return (
    <div className="flex flex-wrap items-end gap-3 p-5">
      <label className="label">Auth user UUID<input className={`${field} mt-1 block w-80`} value={userId} onChange={(e) => setUserId(e.target.value)} /></label>
      <label className="label">Role<select className={`${field} mt-1 block`} value={role} onChange={(e) => setRole(e.target.value as typeof role)}><option value="dispatcher">Dispatcher</option><option value="operations_admin">Operations admin</option></select></label>
      <label className="label">Reason<input className={`${field} mt-1 block w-64`} value={reason} onChange={(e) => setReason(e.target.value)} /></label>
      <Button disabled={pending || !userId || !reason.trim()} onClick={() => startTransition(async () => {
        const result = await setPlatformStaff({ userId, role, active: true, reason });
        setNotice(result.ok ? result.message : result.error);
        if (result.ok) { setUserId(""); setReason(""); }
      })}>{pending ? "Saving…" : "Grant access"}</Button>
      {notice ? <p role="status" className="text-xs text-muted">{notice}</p> : null}
    </div>
  );
}

export function StaffToggle({
  userId, role, active,
}: { userId: string; role: "dispatcher" | "operations_admin"; active: boolean }) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  return (
    <div className="inline-flex items-center gap-2">
      <Button size="sm" variant="ghost" disabled={pending} onClick={() => {
        const reason = window.prompt(`Reason required to ${active ? "deactivate" : "reactivate"} platform access:`)?.trim();
        if (!reason) return;
        startTransition(async () => {
          const result = await setPlatformStaff({ userId, role, active: !active, reason });
          setNotice(result.ok ? result.message : result.error);
        });
      }}>{pending ? "Working…" : active ? "Deactivate" : "Reactivate"}</Button>
      {notice ? <span className="text-xs text-muted">{notice}</span> : null}
    </div>
  );
}

export function RefundTopup({ topupId }: { topupId: string }) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  return (
    <div className="inline-flex items-center gap-2">
      <Button size="sm" variant="ghost" disabled={pending} onClick={() => {
        const reason = window.prompt("Reason required for this full Stripe refund:")?.trim();
        if (!reason || !window.confirm("Refund this entire top-up and remove its credits from the company float?")) return;
        startTransition(async () => {
          const result = await refundCompanyTopup(topupId, reason);
          setNotice(result.ok ? result.message : result.error);
        });
      }}>{pending ? "Refunding…" : "Refund"}</Button>
      {notice ? <span className="max-w-48 text-xs text-muted">{notice}</span> : null}
    </div>
  );
}

export function UserStatusToggle({ userId, disabled }: { userId: string; disabled: boolean }) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  return (
    <div className="inline-flex items-center gap-2">
      <Button size="sm" variant="ghost" disabled={pending} onClick={() => {
        const reason = window.prompt(`Reason required to ${disabled ? "re-enable" : "disable"} this user:`)?.trim();
        if (!reason) return;
        startTransition(async () => {
          const result = await setUserDisabled(userId, !disabled, reason);
          setNotice(result.ok ? result.message : result.error);
        });
      }}>{pending ? "Working…" : disabled ? "Re-enable" : "Disable"}</Button>
      {notice ? <span className="text-xs text-muted">{notice}</span> : null}
    </div>
  );
}
