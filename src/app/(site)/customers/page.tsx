import type { Metadata } from "next";
import { CtaBand, NextSteps, PageHero } from "@/components/page-chrome";
import { images } from "@/lib/images";
import { Card, SectionHead, Stat } from "@/components/ui";

export const metadata: Metadata = {
  title: "Customers",
  description: "Employers running staff transport on Rydlnk in Provo, and what changed when they did.",
};

/* NOTE: the numbers below are illustrative and must be replaced with signed-off
   customer figures before launch. A trust page with invented results is worse
   than no trust page — every claim here needs a named reference behind it. */

const cases = [
  {
    company: "Manufacturing · East Bay",
    staff: "412 staff · 3 shifts",
    headline: "Two contracted operators became one line on the ledger.",
    body: "Night shift ran on two minibus contracts nobody could reconcile. Roster sync clustered 412 shifts into 96 trips; finance got one invoice split by cost center for the first time.",
    stats: [
      ["−31%", "cost per employee trip"],
      ["78%", "seat fill, from 46%"],
      ["1", "invoice, from 2 contracts"],
    ],
  },
  {
    company: "Customer support · Springville",
    staff: "96 staff · late shift",
    headline: "The 22:00 finish stopped being a retention problem.",
    body: "Staff were expensing e-hailing home at unpredictable rates. A fixed seat fare on two corridors, funded by credits, replaced the claims process entirely.",
    stats: [
      ["0", "expense claims for transport"],
      ["4h", "manifest lock, so no-shows are attributable"],
      ["+18%", "late-shift retention"],
    ],
  },
];

export default function CustomersPage() {
  return (
    <>
      {/* Deliberately an industrial context shot, not people. Photography of
          identifiable strangers beside a customer story reads as "this is our
          customer" — which would be false regardless of the image license. */}
      <PageHero
        image={images.industrial}
        tone="ink"
        eyebrow="Customers"
        title="Employers who stopped paying for empty seats."
        lede="Staff transport usually fails for boring reasons: daily booking, empty vehicles, and nobody able to tell finance what a trip cost. These are the numbers after those three go away."
      />

      <section className="py-16 lg:py-20">
        <div className="wrap space-y-4">
          {cases.map((c) => (
            <Card key={c.company} className="p-0">
              <div className="grid gap-8 p-7 lg:grid-cols-[1.3fr_1fr] lg:items-center lg:p-9">
                <div>
                  <p className="eyebrow text-signal">{c.company}</p>
                  <h2 className="mt-3 max-w-[24ch] font-display text-[1.7rem] font-extrabold leading-[1.15] tracking-[-0.025em]">
                    {c.headline}
                  </h2>
                  <p className="mt-3 max-w-[58ch] text-base text-muted">{c.body}</p>
                  <p className="mt-4 text-xs text-muted">{c.staff}</p>
                </div>
                <dl className="grid gap-3 sm:grid-cols-3 lg:grid-cols-1">
                  {c.stats.map(([v, l]) => (
                    <div key={l} className="rounded-card bg-shell px-4 py-3">
                      <dt className="nums font-display text-[1.6rem] font-extrabold leading-none tracking-[-0.03em]">
                        {v}
                      </dt>
                      <dd className="mt-1.5 text-xs text-muted">{l}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            </Card>
          ))}
        </div>
      </section>

      <section className="border-y border-line bg-white py-16">
        <div className="wrap">
          <SectionHead
            eyebrow="Across the network"
            title="What the corridors look like today."
            lede="Rydlnk runs fixed corridors out of Provo's industrial areas, timed to shift changes rather than to peak-hour demand."
          />
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <Stat value="5" label="live corridors out of East Bay" />
            <Stat value="96" label="trips published a week" />
            <Stat value="78%" label="average seat fill on pooled runs" />
            <Stat value="$1.94" label="median cost per employee trip" />
          </div>
        </div>
      </section>

      <NextSteps
        items={[
          { href: "/pricing", label: "Pricing", blurb: "What a seat and the platform cost." },
          { href: "/business/how-it-works", label: "How it works", blurb: "Credits, pooling and roster sync." },
          { href: "/security", label: "Security", blurb: "What other employers can see." },
        ]}
      />

      <CtaBand
        title="Ask us for a reference."
        lede="We'll put you in touch with a transport or HR lead running this now, and show you the same numbers against your roster."
        primary={{ href: "/contact", label: "Book a walkthrough" }}
        secondary={{ href: "/portal", label: "Open the portal demo" }}
      />
    </>
  );
}
