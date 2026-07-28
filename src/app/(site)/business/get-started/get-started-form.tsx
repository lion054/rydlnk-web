"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import * as Icon from "@/components/icons";
import { TRANSIT_BENEFIT_CAP } from "@/lib/data";

/**
 * Company account creation.
 *
 * Four steps, and unlike the Flutter version every field is persisted —
 * `create_company()` writes the company, makes the caller its owner, and seeds
 * default policy, benefit settings and auto-top-up rows in one transaction.
 *
 * Signing in comes first: `create_company()` needs an authenticated caller,
 * because the row it creates makes that caller the owner.
 */

const INDUSTRIES = [
  "Manufacturing",
  "Warehousing & logistics",
  "Healthcare",
  "Customer support",
  "Food production",
  "Retail",
  "Technology",
  "Other",
];

const SIZES = ["25–100", "101–250", "251–500", "500+"];

const field =
  "w-full rounded-sm border border-linestrong bg-white px-3.5 py-3 text-base focus:border-signal focus:outline-none";

export function GetStartedForm({ signedInEmail }: { signedInEmail: string | null }) {
  const router = useRouter();
  const supabase = createClient();

  const [step, setStep] = useState(signedInEmail ? 1 : 0);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [linkSent, setLinkSent] = useState(false);

  // Step 0 — identify
  const [email, setEmail] = useState(signedInEmail ?? "");
  // Step 1 — company
  const [name, setName] = useState("");
  const [industry, setIndustry] = useState("");
  const [size, setSize] = useState("");
  // Step 2 — tax + joining
  const [ein, setEin] = useState("");
  const [joinMode, setJoinMode] = useState<"invite_only" | "both">("invite_only");
  // Step 3 — first worksite
  const [siteName, setSiteName] = useState("");
  const [siteAddress, setSiteAddress] = useState("");

  useEffect(() => {
    if (signedInEmail) setEmail(signedInEmail);
  }, [signedInEmail]);

  const emailOk = /.+@.+\..+/.test(email);
  const canContinue =
    step === 0 ? emailOk : step === 1 ? name.trim().length > 1 && industry && size : true;

  async function sendLink() {
    setPending(true);
    setError(null);
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: `${window.location.origin}/auth/callback?next=/business/get-started` },
    });
    setPending(false);
    if (error) setError(error.message);
    else setLinkSent(true);
  }

  async function create() {
    setPending(true);
    setError(null);

    const { data: companyId, error: rpcError } = await supabase.rpc("create_company", {
      p_name: name.trim(),
      p_legal_name: name.trim(),
      p_industry: industry,
      p_size_band: size,
      p_ein: ein.trim() || null,
      p_billing_email: email.trim(),
      p_join_mode: joinMode,
    });

    if (rpcError) {
      setPending(false);
      setError(rpcError.message);
      return;
    }

    if (siteAddress.trim()) {
      const { error: siteError } = await supabase.from("company_sites").insert({
        company_id: companyId,
        name: siteName.trim() || "Main site",
        address: siteAddress.trim(),
        is_primary: true,
      });
      // A failed site insert shouldn't strand a created company.
      if (siteError) console.warn("site insert failed", siteError.message);
    }

    router.push("/portal");
    router.refresh();
  }

  /* ------------------------------------------------------------------ */

  if (linkSent) {
    return (
      <div role="status" className="rounded-lg border border-line bg-white p-8">
        <span className="grid h-12 w-12 place-items-center rounded-full bg-signal/12 text-signal">
          <Icon.Check size={24} />
        </span>
        <h2 className="mt-5 text-xl font-extrabold tracking-[-0.02em]">Check your inbox.</h2>
        <p className="mt-2 text-base text-muted">
          We sent a link to <span className="font-semibold text-ink">{email}</span>. Open it and you&apos;ll come
          straight back here to finish setting up.
        </p>
      </div>
    );
  }

  return (
    <div className="rounded-lg border border-line bg-white">
      {/* progress */}
      <div className="flex gap-1.5 border-b border-line p-5">
        {["Your email", "Company", "Tax & access", "First site"].map((label, i) => (
          <div key={label} className="flex-1">
            <div className={`h-1 rounded-full ${i <= step ? "bg-signal" : "bg-line"}`} />
            <p className={`mt-2 text-2xs font-semibold ${i <= step ? "text-ink" : "text-muted"}`}>{label}</p>
          </div>
        ))}
      </div>

      <div className="p-6 lg:p-8">
        {error ? (
          <p role="alert" className="mb-5 flex items-start gap-2.5 rounded-sm border border-flag/40 bg-flag/5 px-4 py-3 text-base text-flag">
            <Icon.Alert size={17} className="mt-0.5 shrink-0" />
            {error}
          </p>
        ) : null}

        {step === 0 ? (
          <div className="grid gap-4">
            <div>
              <label htmlFor="email" className="label mb-1.5 block">
                Work email
              </label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@company.com"
                className={field}
              />
              <p className="mt-2 text-xs text-muted">
                We&apos;ll email a link to confirm it&apos;s you. Use the domain your staff use — it lets you turn
                on self-serve joining later.
              </p>
            </div>
          </div>
        ) : null}

        {step === 1 ? (
          <div className="grid gap-5">
            <div>
              <label htmlFor="name" className="label mb-1.5 block">
                Company name
              </label>
              <input id="name" value={name} onChange={(e) => setName(e.target.value)} className={field} placeholder="Wasatch Manufacturing" />
            </div>
            <div>
              <span className="label mb-2 block">Industry</span>
              <div className="flex flex-wrap gap-2">
                {INDUSTRIES.map((i) => (
                  <button
                    key={i}
                    onClick={() => setIndustry(i)}
                    aria-pressed={industry === i}
                    className={`rounded-full border px-3.5 py-2 text-xs font-semibold transition-colors ${
                      industry === i ? "border-signal bg-signal text-white" : "border-linestrong text-muted hover:border-signal"
                    }`}
                  >
                    {i}
                  </button>
                ))}
              </div>
            </div>
            <div>
              <span className="label mb-2 block">Staff who&apos;d commute</span>
              <div className="flex flex-wrap gap-2">
                {SIZES.map((s) => (
                  <button
                    key={s}
                    onClick={() => setSize(s)}
                    aria-pressed={size === s}
                    className={`rounded-full border px-4 py-2 text-xs font-semibold transition-colors ${
                      size === s ? "border-signal bg-signal text-white" : "border-linestrong text-muted hover:border-signal"
                    }`}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          </div>
        ) : null}

        {step === 2 ? (
          <div className="grid gap-5">
            <div>
              <label htmlFor="ein" className="label mb-1.5 block">
                EIN <span className="font-normal text-muted">(optional now, required for pre-tax)</span>
              </label>
              <input id="ein" value={ein} onChange={(e) => setEin(e.target.value)} className={field} placeholder="12-3456789" />
              <p className="mt-2 text-xs text-muted">
                Funding a commute under IRS §132(f) is excluded from your employees&apos; gross income and from
                payroll tax, up to ${TRANSIT_BENEFIT_CAP}/month each. We need the EIN to run it that way.
              </p>
            </div>
            <div>
              <span className="label mb-2 block">How do staff join?</span>
              <div className="grid gap-2">
                {[
                  ["invite_only", "Invite only", "You add people. Nobody joins without a link from you."],
                  ["both", "Invite + verified domain", "Anyone with your email domain can self-join, once you've proven you own the domain."],
                ].map(([v, title, body]) => (
                  <label
                    key={v}
                    className={`flex cursor-pointer gap-3 rounded-sm border p-3.5 transition-colors ${
                      joinMode === v ? "border-signal bg-signal/5" : "border-line hover:border-linestrong"
                    }`}
                  >
                    <input
                      type="radio"
                      name="joinmode"
                      checked={joinMode === v}
                      onChange={() => setJoinMode(v as "invite_only" | "both")}
                      className="mt-0.5 h-4 w-4 accent-signal"
                    />
                    <span>
                      <span className="block text-base font-semibold">{title}</span>
                      <span className="block text-xs text-muted">{body}</span>
                    </span>
                  </label>
                ))}
              </div>
            </div>
          </div>
        ) : null}

        {step === 3 ? (
          <div className="grid gap-4">
            <div>
              <label htmlFor="siteName" className="label mb-1.5 block">
                Site name
              </label>
              <input id="siteName" value={siteName} onChange={(e) => setSiteName(e.target.value)} className={field} placeholder="East Bay plant" />
            </div>
            <div>
              <label htmlFor="siteAddress" className="label mb-1.5 block">
                Address
              </label>
              <input id="siteAddress" value={siteAddress} onChange={(e) => setSiteAddress(e.target.value)} className={field} placeholder="1200 S East Bay Blvd, Provo, UT 84606" />
              <p className="mt-2 text-xs text-muted">
                Corridors are built outward from your sites. You can add more later.
              </p>
            </div>
          </div>
        ) : null}

        <div className="mt-8 flex items-center gap-3">
          {step > (signedInEmail ? 1 : 0) ? (
            <button
              onClick={() => setStep((s) => s - 1)}
              className="inline-flex min-h-[48px] items-center gap-2 rounded-full border border-linestrong px-5 font-semibold transition-colors hover:border-signal"
            >
              <Icon.ArrowLeft size={16} /> Back
            </button>
          ) : null}

          <button
            onClick={() => {
              if (step === 0) return void sendLink();
              if (step === 3) return void create();
              setStep((s) => s + 1);
            }}
            disabled={!canContinue || pending}
            className="inline-flex min-h-[48px] flex-1 items-center justify-center gap-2 rounded-full bg-signal px-6 font-semibold text-white transition-colors hover:bg-signaldim disabled:cursor-not-allowed disabled:bg-line disabled:text-muted"
          >
            {pending ? "Working…" : step === 0 ? "Email me a link" : step === 3 ? "Create company" : "Continue"}
            {!pending ? <Icon.ArrowRight size={17} /> : null}
          </button>
        </div>
      </div>
    </div>
  );
}
