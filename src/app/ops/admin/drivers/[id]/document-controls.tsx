"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui";
import { reviewDriverDocument } from "../../actions";

export function DocumentControls({ documentId }: { documentId: string }) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  function decide(approve: boolean) {
    const reason = window.prompt(`${approve ? "Approval" : "Rejection"} note (required):`)?.trim();
    if (!reason) return;
    startTransition(async () => {
      const result = await reviewDriverDocument(documentId, approve, reason);
      setNotice(result.ok ? result.message : result.error);
    });
  }
  return (
    <div className="flex items-center gap-2">
      <Button size="sm" disabled={pending} onClick={() => decide(true)}>Approve</Button>
      <Button size="sm" variant="ghost" disabled={pending} onClick={() => decide(false)}>Reject</Button>
      {notice ? <span className="text-xs text-muted">{notice}</span> : null}
    </div>
  );
}
