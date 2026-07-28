"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import * as Icon from "@/components/icons";

/**
 * Redeem an invite.
 *
 * The token is only ever exchanged through `accept_company_invite()`, which
 * validates it against the stored hash, checks expiry, and writes the
 * membership itself. The client never touches `company_members` directly —
 * that path is closed by RLS.
 */
export function AcceptInvite({ token, signedIn }: { token: string; signedIn: boolean }) {
  const router = useRouter();
  const supabase = createClient();
  const [email, setEmail] = useState("");
  const [pending, setPending] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function accept() {
    setPending(true);
    setError(null);
    const { error } = await supabase.rpc("accept_company_invite", { p_token: token });
    setPending(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.push("/portal");
    router.refresh();
  }

  async function sendLink() {
    setPending(true);
    setError(null);
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback?next=/invite/${token}`,
      },
    });
    setPending(false);
    if (error) setError(error.message);
    else setSent(true);
  }

  if (sent) {
    return (
      <p role="status" className="flex items-start gap-3 rounded-card border border-line bg-white p-5 text-base">
        <Icon.Check size={18} className="mt-0.5 shrink-0 text-signal" />
        Check <span className="font-semibold">{email}</span> — open the link and you&apos;ll come straight back
        here to join.
      </p>
    );
  }

  return (
    <div className="rounded-card border border-line bg-white p-5">
      {error ? (
        <p role="alert" className="mb-4 flex items-start gap-2.5 text-base text-flag">
          <Icon.Alert size={17} className="mt-0.5 shrink-0" />
          {error}
        </p>
      ) : null}

      {signedIn ? (
        <>
          <p className="text-base text-muted">You&apos;re signed in. Join this company to pick up your seat.</p>
          <button
            onClick={accept}
            disabled={pending}
            className="mt-4 inline-flex min-h-[48px] w-full items-center justify-center gap-2 rounded-full bg-signal px-6 font-semibold text-white transition-colors hover:bg-signaldim disabled:opacity-70"
          >
            {pending ? "Joining…" : "Accept invite"}
            {!pending ? <Icon.ArrowRight size={17} /> : null}
          </button>
        </>
      ) : (
        <>
          <label htmlFor="inv-email" className="label mb-1.5 block">
            Confirm your email to join
          </label>
          <div className="flex gap-2">
            <input
              id="inv-email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@company.com"
              className="min-w-0 flex-1 rounded-sm border border-linestrong px-3.5 py-3 text-base focus:border-signal focus:outline-none"
            />
            <button
              onClick={sendLink}
              disabled={pending || !/.+@.+\..+/.test(email)}
              className="inline-flex min-h-[48px] shrink-0 items-center gap-2 rounded-full bg-signal px-5 font-semibold text-white transition-colors hover:bg-signaldim disabled:opacity-60"
            >
              Continue
            </button>
          </div>
          <p className="mt-2 text-xs text-muted">
            Use the address your employer invited — that&apos;s how the credits attach to you.
          </p>
        </>
      )}
    </div>
  );
}
