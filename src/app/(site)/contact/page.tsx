"use client";

import { useState } from "react";
import { PageHero } from "@/components/page-chrome";
import { Card } from "@/components/ui";
import { contact, mailtoWork } from "@/lib/site";
import { images } from "@/lib/images";

const rosterSystems = ["Deputy", "Workday", "UKG Ready", "BambooHR", "Zoho People", "Sage 300 People", "SAP Business One", "Spreadsheet", "Something else"];
const patterns = ["Single day shift", "Two shifts", "Three shifts, 24/7", "Irregular / field staff"];

const field =
  "w-full rounded-[9px] border border-linestrong bg-white px-3.5 py-2.5 text-[0.9rem] focus:border-signal focus:outline-none";
const fieldError = `${field.replace("border-linestrong", "border-flag")} bg-flag/5`;
const labelCls = "mb-1.5 block text-[0.8rem] font-semibold";
const errorCls = "mt-1.5 text-[0.78rem] text-flag";

export default function ContactPage() {
  const [company, setCompany] = useState("");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [staff, setStaff] = useState(150);
  const [sites, setSites] = useState("East Bay");
  const [system, setSystem] = useState(rosterSystems[0]);
  const [pattern, setPattern] = useState(patterns[2]);
  const [notes, setNotes] = useState("");
  const [sent, setSent] = useState(false);
  /* Errors only surface once a field has been left, so the form doesn't scold
     you for not having finished typing yet. */
  const [touched, setTouched] = useState<Record<string, boolean>>({});

  const errors = {
    company: company.trim().length > 1 ? null : "Tell us which company this is for.",
    name: name.trim().length > 1 ? null : "We need a name to address the reply to.",
    email: /.+@.+\..+/.test(email) ? null : "That doesn't look like a work email address.",
  };
  const ready = !errors.company && !errors.name && !errors.email;

  const blur = (k: string) => () => setTouched((t) => ({ ...t, [k]: true }));
  const showError = (k: keyof typeof errors) => (touched[k] ? errors[k] : null);

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setTouched({ company: true, name: true, email: true });
    if (ready) setSent(true);
  }

  return (
    <>
      <PageHero
        image={images.workers}
        tone="forest"
        eyebrow="Book a walkthrough"
        title="Bring a week of shifts. We'll bring the seats you're paying for twice."
        lede="Forty-five minutes, no deck. We load a sample of your roster into the portal, cluster it against real Utah County corridors, and show you what the run sheet would look like next Monday."
      />

      <section className="py-16">
        <div className="wrap grid gap-10 lg:grid-cols-[1.15fr_0.85fr] lg:items-start">
          {sent ? (
            <Card className="bg-white">
              <div className="flex items-start gap-4" role="status">
                <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-signal/15 text-signaldim">✓</span>
                <div>
                  <h2 className="h3">Thanks, {name.split(" ")[0]}.</h2>
                  <p className="mt-2 text-[0.92rem] text-muted">
                    We&apos;ll come back to {email} within one business day with two or three times. If it&apos;s
                    quicker, send a week of anonymized shifts ahead of the call — employee number, home address,
                    department, shift start — and we&apos;ll have the corridors already clustered when we meet.
                  </p>
                  <button onClick={() => setSent(false)} className="mt-5 font-mono text-[0.72rem] uppercase tracking-[0.11em] text-signaldim underline underline-offset-4">
                    Edit the details
                  </button>
                </div>
              </div>
            </Card>
          ) : (
            <Card className="bg-white">
              <form className="grid gap-4" onSubmit={submit} noValidate>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label htmlFor="company" className={labelCls}>
                      Company
                    </label>
                    <input
                      id="company"
                      name="organization"
                      autoComplete="organization"
                      required
                      aria-invalid={showError("company") ? true : undefined}
                      aria-describedby={showError("company") ? "company-error" : undefined}
                      className={showError("company") ? fieldError : field}
                      value={company}
                      onChange={(e) => setCompany(e.target.value)}
                      onBlur={blur("company")}
                      placeholder="Acme Manufacturing"
                    />
                    {showError("company") ? <p id="company-error" className={errorCls}>{errors.company}</p> : null}
                  </div>
                  <div>
                    <label htmlFor="name" className={labelCls}>
                      Your name
                    </label>
                    <input
                      id="name"
                      name="name"
                      autoComplete="name"
                      required
                      aria-invalid={showError("name") ? true : undefined}
                      aria-describedby={showError("name") ? "name-error" : undefined}
                      className={showError("name") ? fieldError : field}
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      onBlur={blur("name")}
                      placeholder="Tendai Moyo"
                    />
                    {showError("name") ? <p id="name-error" className={errorCls}>{errors.name}</p> : null}
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label htmlFor="email" className={labelCls}>
                      Work email
                    </label>
                    <input
                      id="email"
                      name="email"
                      type="email"
                      inputMode="email"
                      autoComplete="email"
                      required
                      aria-invalid={showError("email") ? true : undefined}
                      aria-describedby={showError("email") ? "email-error" : undefined}
                      className={showError("email") ? fieldError : field}
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      onBlur={blur("email")}
                      placeholder="you@company.co.zw"
                    />
                    {showError("email") ? <p id="email-error" className={errorCls}>{errors.email}</p> : null}
                  </div>
                  <div>
                    <label htmlFor="sites" className={labelCls}>
                      Site or industrial area
                    </label>
                    <input
                      id="sites"
                      name="sites"
                      autoComplete="address-level2"
                      className={field}
                      value={sites}
                      onChange={(e) => setSites(e.target.value)}
                      placeholder="East Bay, Springville"
                    />
                  </div>
                </div>

                <div>
                  <label htmlFor="staff" className="mb-2 flex items-baseline justify-between text-[0.8rem] font-semibold">
                    Staff who&apos;d use it
                    <span className="font-mono text-[0.8rem] text-muted">{staff}</span>
                  </label>
                  <input id="staff" type="range" min={25} max={800} step={25} value={staff} onChange={(e) => setStaff(Number(e.target.value))} className="w-full accent-signal h-6" />
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label htmlFor="system" className={labelCls}>
                      Where your roster lives
                    </label>
                    <select id="system" className={field} value={system} onChange={(e) => setSystem(e.target.value)}>
                      {rosterSystems.map((s) => (
                        <option key={s}>{s}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label htmlFor="pattern" className={labelCls}>
                      Shift pattern
                    </label>
                    <select id="pattern" className={field} value={pattern} onChange={(e) => setPattern(e.target.value)}>
                      {patterns.map((s) => (
                        <option key={s}>{s}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div>
                  <label htmlFor="notes" className={labelCls}>
                    Anything we should know
                  </label>
                  <textarea
                    id="notes"
                    rows={3}
                    className={field}
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="We currently contract two operators and can't tell what a trip costs per person."
                  />
                </div>

                <div className="flex flex-wrap items-center gap-4">
                  <button
                    type="submit"
                    className="min-h-[44px] rounded-full bg-signal px-6 py-3 text-[0.92rem] font-semibold text-white transition-colors hover:bg-signaldim"
                  >
                    Request a walkthrough
                  </button>
                  <p className="text-[0.78rem] text-muted">
                    {ready ? "We reply within one business day." : "Company, name and work email are enough to start."}
                  </p>
                </div>
              </form>
            </Card>
          )}

          <aside className="space-y-3.5">
            <Card className="bg-ink text-white">
              <p className="font-mono text-[0.62rem] uppercase tracking-[0.13em] text-muteddark">What we&apos;ll show you</p>
              <ul className="mt-4 space-y-3 text-[0.88rem] text-muteddark">
                {[
                  ["Your corridors", `${sites || "Your site"} clustered into real pickup groups, with vehicle counts.`],
                  ["Your seat cost", `About ${Math.round(staff * 10 * 4.33).toLocaleString()} seats a month at ${staff} staff on a five-day pattern.`],
                  ["Your leakage", "Where the empty seats and no-shows are hiding in what you spend now."],
                  ["Your roster path", `How ${system} would feed it, and what happens the week somebody leaves.`],
                ].map(([k, v]) => (
                  <li key={k}>
                    <span className="block font-medium text-white">{k}</span>
                    <span>{v}</span>
                  </li>
                ))}
              </ul>
            </Card>

            <Card>
              <h3 className="h3">Rather just email?</h3>
              <p className="mt-2 text-[0.88rem] text-muted">
                <a
                  href={mailtoWork}
                  className="font-mono text-signaldim underline underline-offset-4"
                >
                  {contact.workEmail}
                </a>{" "}
                — or ask your staff to point us at you, which is how most of these start.
              </p>
            </Card>
          </aside>
        </div>
      </section>
    </>
  );
}
