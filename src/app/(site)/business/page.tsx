import type { Metadata } from "next";
import Link from "next/link";
import { DeparturesBoard } from "@/components/board";
import { CtaBand, PageHero } from "@/components/page-chrome";
import { Button, Card, SectionHead } from "@/components/ui";
import * as Icon from "@/components/icons";
import { CorridorMap } from "@/components/corridor-map";
import { images } from "@/lib/images";

export const metadata: Metadata = {
  title: "Rydlnk for Work — company-funded staff transport",
  description:
    "Fund a company wallet, set the policy, and let the roster fill the seats. Pool with other employers on the same corridor and pay only for the seats your people sat in.",
};

export default function BusinessOverview() {
  return (
    <>
      <PageHero
        image={images.valley}
        tone="forest"
        eyebrow="Employer-funded commuting"
        title={
          <>
            Your staff already travel together.
            <br />
            <span className="text-amber">Stop paying like they don&apos;t.</span>
          </>
        }
        lede="Rydlnk for Work turns your shift roster into filled seats. Fund a wallet, set who gets what, and let people ride — on schedule, on policy, on one invoice."
        aside={<DeparturesBoard />}
      />

      <section className="border-b border-line bg-white py-5">
        <div className="wrap flex flex-wrap items-center gap-x-8 gap-y-3">
          {[
            ["78%", "average seat fill on pooled corridors"],
            ["$1.94", "cost per employee trip"],
            ["1×", "roster upload replaces ~20 bookings a month"],
            ["T−4h", "manifest lock, after which no-shows cost the cost center"],
          ].map(([b, s]) => (
            <div key={s} className="flex items-baseline gap-2.5">
              <span className="font-display text-[1.35rem] font-extrabold tracking-[-0.03em]">{b}</span>
              <span className="max-w-[28ch] text-[0.8rem] text-muted">{s}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="py-16 lg:py-20">
        <div className="wrap">
          <SectionHead
            eyebrow="Start here"
            title="Three things worth understanding before you talk to us."
            lede="Staff transport fails for boring, predictable reasons: daily booking, empty seats, and nobody being able to tell finance what a trip actually cost. These cover all three."
          />
          <div className="grid gap-3.5 md:grid-cols-3">
            {[
              { href: "/business/how-it-works", label: "How it works", blurb: "Credits, pooling and roster sync — the three mechanics that do all the work." },
              { href: "/pricing", label: "Pricing", blurb: "A seat price, a platform fee, and an estimator you can put your own headcount into." },
              { href: "/customers", label: "Customers", blurb: "Employers running this now, and the numbers after they switched." },
            ].map((n, i) => (
              <Link
                key={n.href}
                href={n.href}
                className="group flex flex-col justify-between rounded-card border border-line bg-white p-6 transition-[transform,border-color] hover:-translate-y-0.5 hover:border-signal"
              >
                <div>
                  <span className="eyebrow text-muted">{String(i + 1).padStart(2, "0")}</span>
                  <h3 className="mt-2.5 text-lg font-extrabold tracking-[-0.015em]">{n.label}</h3>
                  <p className="mt-2 text-base text-muted">{n.blurb}</p>
                </div>
                <span className="mt-6 inline-flex items-center gap-1.5 text-xs font-semibold text-signal">
                  Read <Icon.ArrowRight size={14} className="transition-transform group-hover:translate-x-1" />
                </span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-ink py-16 text-white lg:py-20">
        <div className="wrap grid gap-10 lg:grid-cols-2 lg:items-center">
          <div>
            <SectionHead
              dark
              eyebrow="The portal"
              title="See the working version, not a screenshot."
              lede="The company console in this build is live. Filter the staff directory, run an allocation and watch the float move, switch a corridor from pooled to exclusive, trigger a sync."
            />
            <Button href="/portal" variant="amber">
              Open the portal demo →
            </Button>
          </div>
          <Card dark>
            <ul className="space-y-4 text-[0.9rem] text-muteddark">
              {[
                ["Overview", "Tonight's departures, alerts, and spend by cost center."],
                ["Trips", "Per-seat funding and status, including no-shows you've been charged for."],
                ["Corridors", "Pooling policy per route, roster grid, clustering and safety rules."],
                ["People", "Directory with entitlements, balances and sync source."],
                ["Credits", "The double-entry ledger and the policy limits behind it."],
                ["Integrations", "Connectors and a sync log you can run."],
              ].map(([k, v]) => (
                <li key={k} className="flex gap-3">
                  <span className="w-[86px] shrink-0 font-mono text-[0.7rem] uppercase tracking-[0.1em] text-amber">{k}</span>
                  <span>{v}</span>
                </li>
              ))}
            </ul>
          </Card>
        </div>
      </section>

      <section className="border-t border-line bg-shell py-16 lg:py-20">
        <div className="wrap">
          <p className="eyebrow text-signal">Where we run</p>
          <h2 className="h2 mb-3 mt-3 max-w-[22ch]">Utah County, timed to shift changes.</h2>
          <p className="mb-8 max-w-[58ch] text-md text-muted">
            Corridors run out of the East Bay district in Provo along I-15, north toward Lehi and south toward
            Payson — scheduled around 6:00 AM, 2:00 PM and 10:00 PM shift changes rather than peak-hour demand.
          </p>
          <CorridorMap height={420} />
        </div>
      </section>

      <CtaBand
        title="See it against your own roster."
        lede="Send us a week of shifts and the cities your staff live in. We'll show you the seats you're currently paying for twice."
        primary={{ href: "/work/contact", label: "Book a walkthrough →" }}
        secondary={{ href: "/work/pricing", label: "What it costs" }}
      />
    </>
  );
}
