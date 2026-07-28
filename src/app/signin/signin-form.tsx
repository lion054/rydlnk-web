"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import * as Icon from "@/components/icons";
import { contact, mailtoWork } from "@/lib/site";

/**
 * Employer portal sign-in.
 *
 * Riders never sign in on the web — the app owns that surface — so this is
 * work-email only. Magic link by default because it needs no password store;
 * password sign-in is offered for admins who already set one.
 */
export function SignInForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next") ?? "/portal";
  const urlError = params.get("error");

  const [mode, setMode] = useState<"link" | "password">("link");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [sent, setSent] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(urlError);
  const [touched, setTouched] = useState(false);

  const emailError = /.+@.+\..+/.test(email) ? null : "Enter your work email address.";

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setTouched(true);
    setError(null);
    if (emailError) return;

    setPending(true);
    const supabase = createClient();

    if (mode === "link") {
      const { error } = await supabase.auth.signInWithOtp({
        email: email.trim(),
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`,
        },
      });
      setPending(false);
      if (error) setError(error.message);
      else setSent(true);
      return;
    }

    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    setPending(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.push(next);
    router.refresh();
  }

  if (sent) {
    return (
      <div role="status">
        <span className="grid h-12 w-12 place-items-center rounded-full bg-signal/12 text-signal">
          <Icon.Check size={24} />
        </span>
        <h1 className="mt-6 font-display text-[1.9rem] font-extrabold tracking-[-0.03em]">Check your inbox.</h1>
        <p className="mt-3 text-base text-muted">
          We&apos;ve sent a sign-in link to <span className="font-semibold text-ink">{email}</span>. It expires in
          an hour and can only be used once.
        </p>
        <button
          onClick={() => {
            setSent(false);
            setError(null);
          }}
          className="mt-6 text-base font-semibold text-signal underline underline-offset-4"
        >
          Use a different address
        </button>
      </div>
    );
  }

  return (
    <>
      <h1 className="font-display text-[1.9rem] font-extrabold tracking-[-0.03em]">Sign in to the portal.</h1>
      <p className="mt-3 text-base text-muted">
        For employer administrators. If you ride with Rydlnk, everything you need is in the app — there&apos;s
        nothing to sign into here.
      </p>

      {error ? (
        <p role="alert" className="mt-6 flex items-start gap-2.5 rounded-sm border border-flag/40 bg-flag/5 px-4 py-3 text-base text-flag">
          <Icon.Alert size={17} className="mt-0.5 shrink-0" />
          {error}
        </p>
      ) : null}

      <form onSubmit={submit} noValidate className="mt-7">
        <label htmlFor="email" className="label mb-2 block">
          Work email
        </label>
        <input
          id="email"
          type="email"
          inputMode="email"
          autoComplete="email"
          autoFocus
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          onBlur={() => setTouched(true)}
          aria-invalid={touched && emailError ? true : undefined}
          placeholder="you@company.com"
          className={`w-full rounded-sm border bg-white px-4 py-3 text-base focus:outline-none ${
            touched && emailError ? "border-flag bg-flag/5" : "border-linestrong focus:border-signal"
          }`}
        />
        {touched && emailError ? <p className="mt-2 text-xs text-flag">{emailError}</p> : null}

        {mode === "password" ? (
          <div className="mt-4">
            <label htmlFor="password" className="label mb-2 block">
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-sm border border-linestrong bg-white px-4 py-3 text-base focus:border-signal focus:outline-none"
            />
          </div>
        ) : null}

        <button
          type="submit"
          disabled={pending}
          className="mt-4 flex min-h-[48px] w-full items-center justify-center gap-2 rounded-full bg-signal font-semibold text-white transition-colors hover:bg-signaldim disabled:opacity-70"
        >
          {pending ? "Working…" : mode === "link" ? "Email me a sign-in link" : "Sign in"}
          {!pending ? <Icon.ArrowRight size={17} /> : null}
        </button>
      </form>

      <button
        onClick={() => {
          setMode(mode === "link" ? "password" : "link");
          setError(null);
        }}
        className="mt-5 text-base font-semibold text-signal underline underline-offset-4"
      >
        {mode === "link" ? "Use a password instead" : "Email me a link instead"}
      </button>

      <p className="mt-8 text-xs text-muted">
        No account yet?{" "}
        <Link href="/business/get-started" className="font-semibold text-signal underline underline-offset-4">
          Set up your company
        </Link>{" "}
        — or email{" "}
        <a href={mailtoWork} className="font-semibold text-signal underline underline-offset-4">
          {contact.workEmail}
        </a>
        .
      </p>
    </>
  );
}
