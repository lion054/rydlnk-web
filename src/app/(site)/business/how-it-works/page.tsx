import type { Metadata } from "next";
import { CtaBand, NextSteps, PageHero } from "@/components/page-chrome";
import { Card, SectionHead, Stat } from "@/components/ui";
import * as Icon from "@/components/icons";
import { POOL_REBATE_PER_SEAT, SEATS_PER_VEHICLE, corridors } from "@/lib/data";
import { images } from "@/lib/images";

export const metadata: Metadata = {
  title: "How it works for business",
  description:
    "How money becomes credits, credits become seats, and your shift roster fills them — with pooling that only bills you for the seats your staff sat in.",
};

/* Merged from /work/credits, /work/pooling and /work/roster. Three pages that
   each explained one third of a single mechanic, sitting behind three separate
   nav entries. One page, three sections, one argument. */

const lifecycle = [
  { step: "01", title: "You fund a float", body: "One purchase order, one invoice, one ledger entry. The float is company money sitting in a wallet Rydlnk holds but doesn't own." },
  { step: "02", title: "Rules allocate it", body: "Credits move from the float to employee wallets on a schedule you set — every Monday, on roster publish, or once. Each movement names a source, a destination and a reference." },
  { step: "03", title: "Seats consume it", body: "At the boarding PIN, credits move from the employee's wallet to a seat. That entry is the invoice line, the benefit record and the audit record." },
  { step: "04", title: "The remainder returns", body: "Unspent credits expire back to the float on your cycle. A leaver's wallet is frozen on the termination webhook, not overnight." },
];

export default function BusinessHowItWorks() {
  const pooled = corridors.filter((c) => c.pooling !== "exclusive");
  const avgFill = Math.round(
    (corridors.reduce((a, c) => a + c.avgRiders, 0) / corridors.length / SEATS_PER_VEHICLE) * 100,
  );

  return (
    <>
      <PageHero
        image={images.warehouse}
        tone="forest"
        eyebrow="How it works"
        title="Money in at the top. A seat, a receipt and a journal line at the bottom."
        lede="Three mechanics do all the work: a credit ledger that never mutates a balance, corridor pooling that bills you per seat, and a roster feed that means nobody books anything daily."
      />

      {/* ------------------------------------------------------- credits */}
      <section className="py-16 lg:py-20">
        <div className="wrap">
          <SectionHead
            eyebrow="Credits"
            title="A credit is a unit of account, not a coupon."
            lede="Everything is double-entry. A wallet balance is a projection over entries, never a column somebody updates — which is what makes month-end reconcile without an argument."
          />
          <ol className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
            {lifecycle.map((l) => (
              <li key={l.step}>
                <Card className="h-full">
                  <span className="eyebrow text-signal">{l.step}</span>
                  <h3 className="mt-2.5 text-lg font-extrabold tracking-[-0.015em]">{l.title}</h3>
                  <p className="mt-2 text-xs text-muted">{l.body}</p>
                </Card>
              </li>
            ))}
          </ol>

          <Card className="mt-4 bg-shell">
            <div className="grid gap-6 lg:grid-cols-[1.1fr_1fr] lg:items-center">
              <div>
                <h3 className="text-lg font-extrabold tracking-[-0.015em]">Split tender, worked through</h3>
                <p className="mt-2 text-base text-muted">
                  An employee books a 41 miles drop-off on a corridor capped at 25 miles. Policy covers the first{" "}
                  {SEATS_PER_VEHICLE * 2} credits; the difference comes off their own balance. They&apos;re told
                  before the trip confirms, and the seat still gets one manifest entry.
                </p>
              </div>
              <dl className="rounded-card border border-line bg-white p-5 text-sm nums">
                {[
                  ["Seat price, 41 miles", "8 cr"],
                  ["Company policy cap", "−6 cr"],
                  ["Employee balance", "−$2.10"],
                ].map(([k, v], i) => (
                  <div key={k} className={`flex justify-between py-2 ${i < 2 ? "border-b border-line" : ""}`}>
                    <dt className="text-muted">{k}</dt>
                    <dd className="font-semibold">{v}</dd>
                  </div>
                ))}
              </dl>
            </div>
          </Card>
        </div>
      </section>

      {/* ------------------------------------------------------- pooling */}
      <section className="border-y border-line bg-white py-16 lg:py-20">
        <div className="wrap">
          <SectionHead
            eyebrow="Pooling"
            title="You pay for the seat, not the vehicle."
            lede="On a pooled corridor your staff share the run with approved employers going the same way. You're billed per seat occupied. On an exclusive corridor you charter the whole vehicle and buy every seat on it, full or not."
          />

          <div className="grid gap-3 md:grid-cols-3">
            <Stat value={`${pooled.length}/${corridors.length}`} label="corridors open to pooling" />
            <Stat value={`${avgFill}%`} label="average seat fill across live corridors" />
            <Stat value={`${POOL_REBATE_PER_SEAT} cr`} label="back to your float per spare seat sold" />
          </div>

          <div className="mt-4 grid gap-3 lg:grid-cols-2">
            <Card>
              <span className="mb-4 grid h-10 w-10 place-items-center rounded-sm bg-signal/10 text-signal">
                <Icon.Users size={19} />
              </span>
              <h3 className="text-lg font-extrabold tracking-[-0.015em]">What other employers see</h3>
              <p className="mt-2 text-base text-muted">
                An occupancy count. Not a name, not a department, not a home address. Authorization is scoped per
                seat at the query layer, so asking for a trip you partly own returns your seats and a number.
              </p>
            </Card>
            <Card>
              <span className="mb-4 grid h-10 w-10 place-items-center rounded-sm bg-signal/10 text-signal">
                <Icon.Wallet size={19} />
              </span>
              <h3 className="text-lg font-extrabold tracking-[-0.015em]">Why the price never moves</h3>
              <p className="mt-2 text-base text-muted">
                Seat price is fixed per corridor and time band — not the vehicle cost divided by whoever showed up.
                Another employer&apos;s no-show can never change what you pay. Rydlnk carries that yield risk.
              </p>
            </Card>
          </div>
        </div>
      </section>

      {/* -------------------------------------------------------- roster */}
      <section className="py-16 lg:py-20">
        <div className="wrap">
          <SectionHead
            eyebrow="Roster sync"
            title="Nobody books a trip. The roster does."
            lede="Your shift system already knows who works when and where they live. Rydlnk reads it, clusters people into corridors, and publishes manifests — so the daily booking step that kills every staff-transport scheme simply isn't there."
          />
          <div className="grid gap-3 md:grid-cols-3">
            {[
              ["Shifts in", "A nightly pull plus a webhook on roster publish. 412 shifts becomes 96 trips across five corridors.", Icon.Calendar],
              ["Manifests out", "Published to drivers and riders with a lock four hours before departure. After the lock, a no-show is charged to the cost center.", Icon.Route],
              ["Leavers out", "Terminations arrive on a webhook, not the nightly job. A leaver who rides on Monday morning is money out of the float.", Icon.Shield],
            ].map(([title, body, Glyph]) => {
              const G = Glyph as typeof Icon.Calendar;
              return (
                <Card key={title as string}>
                  <span className="mb-4 grid h-10 w-10 place-items-center rounded-sm bg-signal/10 text-signal">
                    <G size={19} />
                  </span>
                  <h3 className="text-lg font-extrabold tracking-[-0.015em]">{title as string}</h3>
                  <p className="mt-2 text-base text-muted">{body as string}</p>
                </Card>
              );
            })}
          </div>
        </div>
      </section>

      <NextSteps
        items={[
          { href: "/business/integrations", label: "Integrations", blurb: "The systems this reads from." },
          { href: "/pricing", label: "Pricing", blurb: "What a seat and the platform cost." },
          { href: "/security", label: "Security", blurb: "What other employers can see." },
        ]}
      />

      <CtaBand
        title="See it against your own roster."
        lede="Send a week of shifts and the cities your staff live in. We'll show you the seats you're currently paying for twice."
        primary={{ href: "/contact", label: "Book a walkthrough" }}
        secondary={{ href: "/portal", label: "Open the portal demo" }}
      />
    </>
  );
}
