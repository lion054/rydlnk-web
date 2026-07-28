"use client";

import { useState } from "react";
import { PageHero } from "@/components/page-chrome";
import { Card } from "@/components/ui";
import * as Icon from "@/components/icons";
import { corridors } from "@/lib/data";
import { contact, smsHref } from "@/lib/site";
import { images } from "@/lib/images";

/**
 * Driver application.
 *
 * Before this, "Apply to drive" on /drivers pointed at /download, and
 * /download's "Apply to drive" pointed back at /drivers — a closed loop with
 * no application anywhere in it. This is the form that was missing.
 *
 * Submissions are local state; wire to your intake before launch.
 */

const documents = [
  "Driver's license, held at least two years",
  "Police clearance, renewed every six months",
  "Vehicle registration or a signed operator agreement",
  "Current vehicle inspection certificate",
  "Passenger liability insurance",
];

const field =
  "w-full rounded-sm border border-linestrong bg-white px-3.5 py-3 text-base focus:border-signal focus:outline-none";

export default function DriverApplyPage() {
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [corridor, setCorridor] = useState(corridors[0].name);
  const [vehicle, setVehicle] = useState("");
  const [seats, setSeats] = useState(4);
  const [experience, setExperience] = useState("2–5 years");
  const [has, setHas] = useState<string[]>([]);
  const [touched, setTouched] = useState(false);
  const [sent, setSent] = useState(false);

  const errors = {
    name: name.trim().length > 2 ? null : "Please give your full name.",
    phone: phone.replace(/\D/g, "").length >= 9 ? null : "We need a number we can reach you on.",
  };
  const ready = !errors.name && !errors.phone;

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setTouched(true);
    if (ready) setSent(true);
  }

  function toggle(doc: string) {
    setHas((h) => (h.includes(doc) ? h.filter((d) => d !== doc) : [...h, doc]));
  }

  return (
    <>
      <PageHero
        image={images.driverNightAlt}
        tone="ink"
        eyebrow="Apply to drive"
        title="Take a corridor."
        lede="Tell us which side of town you run and what you drive. If there's a published corridor that fits, we'll come back with the run, the times and what it pays."
      />

      <section className="py-16">
        <div className="wrap grid gap-10 lg:grid-cols-[1.15fr_0.85fr] lg:items-start">
          {sent ? (
            <Card role="status">
              <span className="grid h-11 w-11 place-items-center rounded-full bg-signal/12 text-signal">
                <Icon.Check size={22} />
              </span>
              <h2 className="mt-5 text-xl font-extrabold tracking-[-0.02em]">
                Thanks, {name.split(" ")[0]}.
              </h2>
              <p className="mt-3 text-base text-muted">
                We&apos;ll call you on <span className="font-semibold text-ink">{phone}</span> within two business
                days. Have the {documents.length} documents ready — we check them before offering a run, not after.
              </p>
              <a
                href={smsHref}
                target="_blank"
                rel="noopener noreferrer"
                className="mt-6 inline-flex min-h-[44px] items-center gap-2 rounded-full border border-linestrong px-5 font-semibold transition-colors hover:border-signal"
              >
                <Icon.Chat size={17} /> Send documents by text
              </a>
            </Card>
          ) : (
            <Card>
              <form onSubmit={submit} noValidate className="grid gap-4">
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label htmlFor="name" className="label mb-1.5 block">
                      Full name
                    </label>
                    <input
                      id="name"
                      autoComplete="name"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      onBlur={() => setTouched(true)}
                      aria-invalid={touched && errors.name ? true : undefined}
                      className={touched && errors.name ? `${field} border-flag bg-flag/5` : field}
                      placeholder="Tapiwa Chirwa"
                    />
                    {touched && errors.name ? <p className="mt-1.5 text-xs text-flag">{errors.name}</p> : null}
                  </div>
                  <div>
                    <label htmlFor="phone" className="label mb-1.5 block">
                      Phone
                    </label>
                    <input
                      id="phone"
                      type="tel"
                      inputMode="tel"
                      autoComplete="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      onBlur={() => setTouched(true)}
                      aria-invalid={touched && errors.phone ? true : undefined}
                      className={touched && errors.phone ? `${field} border-flag bg-flag/5` : field}
                      placeholder="(801) 555-0199"
                    />
                    {touched && errors.phone ? <p className="mt-1.5 text-xs text-flag">{errors.phone}</p> : null}
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label htmlFor="corridor" className="label mb-1.5 block">
                      Corridor you could run
                    </label>
                    <select id="corridor" value={corridor} onChange={(e) => setCorridor(e.target.value)} className={field}>
                      {corridors.map((c) => (
                        <option key={c.name}>{c.name}</option>
                      ))}
                      <option>Somewhere else in Provo</option>
                    </select>
                  </div>
                  <div>
                    <label htmlFor="experience" className="label mb-1.5 block">
                      Years driving professionally
                    </label>
                    <select id="experience" value={experience} onChange={(e) => setExperience(e.target.value)} className={field}>
                      {["Under 2 years", "2–5 years", "5–10 years", "Over 10 years"].map((o) => (
                        <option key={o}>{o}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label htmlFor="vehicle" className="label mb-1.5 block">
                      Vehicle
                    </label>
                    <input
                      id="vehicle"
                      value={vehicle}
                      onChange={(e) => setVehicle(e.target.value)}
                      className={field}
                      placeholder="Toyota Hiace, 2016"
                    />
                  </div>
                  <div>
                    <label htmlFor="seats" className="label mb-1.5 block">
                      Passenger seats
                    </label>
                    <input
                      id="seats"
                      type="number"
                      min={3}
                      max={22}
                      value={seats}
                      onChange={(e) => setSeats(Number(e.target.value) || 4)}
                      className={field}
                    />
                  </div>
                </div>

                <fieldset>
                  <legend className="label mb-2">Which of these do you already have?</legend>
                  <div className="grid gap-2">
                    {documents.map((d) => (
                      <label
                        key={d}
                        className="flex cursor-pointer items-center gap-3 rounded-sm border border-line px-3.5 py-2.5 text-base transition-colors hover:border-signal has-[:checked]:border-signal has-[:checked]:bg-signal/5"
                      >
                        <input
                          type="checkbox"
                          checked={has.includes(d)}
                          onChange={() => toggle(d)}
                          className="h-[18px] w-[18px] accent-signal"
                        />
                        {d}
                      </label>
                    ))}
                  </div>
                  <p className="mt-2 text-xs text-muted">
                    You don&apos;t need all five to apply — we&apos;ll tell you what&apos;s missing and how to get it.
                  </p>
                </fieldset>

                <div className="flex flex-wrap items-center gap-4 pt-1">
                  <button
                    type="submit"
                    className="inline-flex min-h-[48px] items-center gap-2 rounded-full bg-signal px-7 font-semibold text-white transition-colors hover:bg-signaldim"
                  >
                    Send application <Icon.ArrowRight size={17} />
                  </button>
                  <p className="text-xs text-muted">We reply within two business days.</p>
                </div>
              </form>
            </Card>
          )}

          <aside className="space-y-3">
            <Card className="bg-ink text-white">
              <h2 className="text-lg font-extrabold tracking-[-0.015em] text-white">Why drivers stay</h2>
              <ul className="mt-4 space-y-3 text-base text-muteddark">
                {[
                  ["No dead running", "You know where the run starts and ends. No crossing town empty."],
                  ["Seats sold in advance", "A no-show costs the person who booked it, not you."],
                  ["The same week, every week", "Corridors repeat. You can plan a life around it."],
                  ["Settled weekly", "A statement per run: seats, distance, waiting time."],
                ].map(([k, v]) => (
                  <li key={k}>
                    <span className="block font-semibold text-white">{k}</span>
                    <span>{v}</span>
                  </li>
                ))}
              </ul>
            </Card>
            <Card className="bg-shell">
              <h2 className="text-lg font-extrabold tracking-[-0.015em]">Rather just talk?</h2>
              <p className="mt-2 text-base text-muted">
                Message{" "}
                <a href={smsHref} target="_blank" rel="noopener noreferrer" className="font-mono text-signal underline underline-offset-4">
                  {contact.phoneDisplay}
                </a>{" "}
                and say you want to drive. Same queue, fewer boxes.
              </p>
            </Card>
          </aside>
        </div>
      </section>
    </>
  );
}
