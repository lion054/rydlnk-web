import type { Metadata } from "next";
import { PageHero } from "@/components/page-chrome";
import { PricingEstimator } from "@/components/pricing-estimator";
import { Card, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "Pricing — Rydlnk for Work",
  description:
    "What a seat costs, what the platform costs, and what changes when you anchor a corridor or keep it exclusive.",
};

const included: string[] = [
  "Company portal, unlimited admin users",
  "Roster sync and clustering",
  "Credit ledger, allocation rules and policy limits",
  "Manifests, boarding PINs and no-show reporting",
  "text message and SMS channel for staff",
  "Monthly journal export, or a posted journal via a finance connector",
];

const notIncluded: [string, string][] = [
  ["Dedicated charter", "A vehicle held for you outside published departure times, priced per run rather than per seat."],
  ["Custom integrations", "Anything beyond the published connectors and the CSV/SFTP path is scoped separately."],
  ["On-site coordination", "If you want a Rydlnk person at the gate during a shift change, that's a service line, not a platform fee."],
];

export default function PricingPage() {
  return (
    <>
      <PageHero
        eyebrow="Pricing"
        title="A seat price, a platform fee, and no third thing."
        lede="Credits are bought at face value — a dollar is a credit. Rydlnk charges a platform fee per active employee per month, and the seat price varies by corridor length, time band and whether the run is pooled."
      />

      <section className="py-16">
        <div className="wrap">
          <PricingEstimator />
        </div>
      </section>

      <section className="border-y border-line bg-white py-16">
        <div className="wrap">
          <SectionHead
            eyebrow="Three ways to buy a seat"
            title="What you pay depends on how much risk you take off us."
            lede="The more predictable your demand, the cheaper the seat — because predictability is what lets a vehicle leave full."
          />
          <div className="grid gap-3.5 lg:grid-cols-3">
            {[
              {
                name: "Spot",
                price: "Highest",
                who: "Occasional or unpredictable travel",
                points: [
                  "Buy a seat on a published run when you need it",
                  "No commitment, no minimum",
                  "Subject to availability on the corridor",
                ],
              },
              {
                name: "Anchor",
                price: "Contract rate",
                who: "Regular shift patterns on a fixed corridor",
                points: [
                  "Guarantee a number of seats per departure",
                  "Spare seats sold to approved employers rebate to your float",
                  "The rate most shift-based employers end up on",
                ],
                featured: true,
              },
              {
                name: "Exclusive",
                price: "Premium",
                who: "Security-sensitive or NDA-bound travel",
                points: [
                  "Your staff only, nobody pooled in",
                  "You carry every empty seat",
                  "Set per corridor, so you can apply it to the night run alone",
                ],
              },
            ].map((p) => (
              <div
                key={p.name}
                className={`flex flex-col rounded-[14px] border p-6 ${
                  p.featured ? "border-ink bg-ink text-white" : "border-line bg-paper"
                }`}
              >
                <h3 className="font-display text-[1.3rem] font-extrabold">{p.name}</h3>
                <p className={`mt-1 font-mono text-[0.72rem] uppercase tracking-[0.11em] ${p.featured ? "text-amber" : "text-amberdim"}`}>
                  {p.price}
                </p>
                <p className={`mt-3 text-[0.88rem] ${p.featured ? "text-muteddark" : "text-muted"}`}>{p.who}</p>
                <ul className={`mt-5 space-y-2.5 text-[0.87rem] ${p.featured ? "text-muteddark" : "text-muted"}`}>
                  {p.points.map((pt) => (
                    <li key={pt} className="flex gap-2.5">
                      <span className={p.featured ? "text-amber" : "text-signaldim"}>·</span>
                      {pt}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="wrap grid gap-10 lg:grid-cols-2">
          <div>
            <SectionHead eyebrow="In the platform fee" title="Everything you need to actually run it." />
            <ul className="space-y-2.5 text-[0.9rem] text-muted">
              {included.map((i) => (
                <li key={i} className="flex gap-3">
                  <span className="mt-0.5 grid h-4 w-4 shrink-0 place-items-center rounded-full bg-signal/15 text-[0.6rem] text-signaldim">✓</span>
                  {i}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <SectionHead eyebrow="Priced separately" title="The things it would be dishonest to bundle." />
            <div className="space-y-3">
              {notIncluded.map(([h, p]) => (
                <Card key={h} className="bg-white">
                  <h3 className="text-[0.95rem] font-extrabold">{h}</h3>
                  <p className="mt-1.5 text-[0.86rem] text-muted">{p}</p>
                </Card>
              ))}
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
