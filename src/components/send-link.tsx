"use client";

import { useState } from "react";
import * as Icon from "./icons";

/**
 * Send the install link to a phone.
 *
 * Was a WhatsApp/SMS toggle, which is the right shape for Zimbabwe and the
 * wrong one for Utah — WhatsApp isn't a default channel here. SMS only, so
 * there's no choice to make before the one field that matters.
 */
export function SendLink() {
  const [phone, setPhone] = useState("");
  const [sent, setSent] = useState(false);
  const [touched, setTouched] = useState(false);

  const digits = phone.replace(/\D/g, "");
  const valid = digits.length === 10 || (digits.length === 11 && digits.startsWith("1"));

  /** Format as (801) 555-0142 while typing. */
  function onChange(v: string) {
    const d = v.replace(/\D/g, "").slice(0, 10);
    if (d.length <= 3) setPhone(d);
    else if (d.length <= 6) setPhone(`(${d.slice(0, 3)}) ${d.slice(3)}`);
    else setPhone(`(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`);
  }

  return (
    <div className="rounded-card border border-white/12 bg-white/5 p-5">
      <p className="eyebrow text-muteddark">Text me the link</p>

      {sent ? (
        <div role="status" className="mt-3">
          <p className="flex items-center gap-2.5 text-base text-signalbright">
            <Icon.Check size={18} className="shrink-0" />
            Sent to {phone} — check your messages.
          </p>
          <button
            onClick={() => {
              setSent(false);
              setTouched(false);
            }}
            className="mt-2 py-1.5 text-xs font-semibold text-muteddark underline underline-offset-4 hover:text-white"
          >
            Send to a different number
          </button>
        </div>
      ) : (
        <form
          className="mt-3"
          onSubmit={(e) => {
            e.preventDefault();
            setTouched(true);
            if (valid) setSent(true);
          }}
          noValidate
        >
          <div className="flex gap-2">
            <label htmlFor="phone" className="sr-only">
              Mobile number
            </label>
            <input
              id="phone"
              value={phone}
              onChange={(e) => onChange(e.target.value)}
              onBlur={() => setTouched(true)}
              placeholder="(801) 555-0142"
              inputMode="tel"
              autoComplete="tel-national"
              aria-invalid={touched && !valid ? true : undefined}
              aria-describedby={touched && !valid ? "phone-error" : undefined}
              className={`min-w-0 flex-1 rounded-full border bg-white/5 px-4 py-3 text-base text-white placeholder:text-muteddark/70 focus:outline-none ${
                touched && !valid ? "border-flag" : "border-white/25 focus:border-amber"
              }`}
            />
            <button
              type="submit"
              className="inline-flex min-h-[48px] shrink-0 items-center gap-2 rounded-full bg-signal px-5 font-semibold text-white transition-colors hover:bg-signaldim"
            >
              Send <Icon.ArrowRight size={16} />
            </button>
          </div>
          {touched && !valid ? (
            <p id="phone-error" className="mt-2 text-xs text-amber">
              Enter a 10-digit US mobile number.
            </p>
          ) : null}
        </form>
      )}
      <p className="mt-2.5 text-xs text-muteddark">
        One message. Standard rates apply. We don&apos;t keep the number if you don&apos;t sign up.
      </p>
    </div>
  );
}
