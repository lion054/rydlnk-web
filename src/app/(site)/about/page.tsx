import type { Metadata } from "next";
import { CtaBand, PageHero } from "@/components/page-chrome";
import { Card, SectionHead } from "@/components/ui";
import { images } from "@/lib/images";

export const metadata: Metadata = {
  title: "About",
  description: "Why Rydlnk exists, what we chose not to build, and how we make money.",
};

export default function AboutPage() {
  return (
    <>
      <PageHero
        image={images.wasatch}
        tone="forest"
        eyebrow="About"
        title="Built for the 22:00 shift change, not the Friday night out."
        lede="Rydlnk started from a specific observation in Provo: the same forty people leave the same industrial park at the same time every night, and each of them pays for that trip as though they were the only one making it."
      />

      <section className="py-16 lg:py-20">
        <div className="wrap grid gap-12 lg:grid-cols-[1.2fr_1fr] lg:items-start">
          <div className="max-w-[62ch] space-y-5 text-md text-muted">
            <h2 className="h2 text-ink">Why this shape</h2>
            <p>
              E-hailing solved the unpredictable trip. Nobody solved the predictable one. A commute that repeats
              four or five times a week at a known time, along a known road, with known people, does not need
              real-time matching, surge pricing or a daily booking step — and paying for all three is why staff
              transport costs what it does.
            </p>
            <p>
              So the unit here is a <strong className="font-semibold text-ink">seat on a scheduled run</strong>,
              priced in advance. A seat belongs to whoever pays for it, which is what makes it possible for one
              vehicle to carry staff from three employers plus two people paying their own way, and for each of
              them to get a correct receipt.
            </p>
            <h2 className="h2 pt-4 text-ink">What we chose not to build</h2>
            <p>
              No surge. No dynamic pricing of any kind — one employer&apos;s no-show must never change what another
              pays. No consumer marketplace. No attempt to serve trips that don&apos;t repeat: if your week is
              different every week, an e-hailing app genuinely suits you better and we&apos;d rather say so.
            </p>
            <h2 className="h2 pt-4 text-ink">How we make money</h2>
            <p>
              A platform fee per active employee per month, and the margin between the sum of seat prices and the
              real cost of running the vehicle. That margin lives entirely in fill rate — which is why pooling
              exists and why we carry the yield risk rather than passing it to you.
            </p>
          </div>

          <div className="space-y-3">
            <Card className="bg-shell">
              <h3 className="text-lg font-extrabold tracking-[-0.015em]">Where we operate</h3>
              <p className="mt-2 text-base text-muted">
                Provo. Five corridors out of East Bay and Springville, timed to shift changes. We&apos;d rather run
                a few corridors densely than many corridors badly.
              </p>
            </Card>
            <Card className="bg-shell">
              <h3 className="text-lg font-extrabold tracking-[-0.015em]">Who we&apos;re for</h3>
              <p className="mt-2 text-base text-muted">
                Employers with shift patterns and staff who live in clusters — manufacturing, warehousing, support
                centers. And the people on those shifts, whether or not their employer ever signs up.
              </p>
            </Card>
            <Card className="bg-ink text-white">
              <h3 className="text-lg font-extrabold tracking-[-0.015em] text-white">The hard part</h3>
              <p className="mt-2 text-base text-muteddark">
                Tenant isolation. A pooled trip has one identifier and several owners. Getting that wrong once —
                showing one employer another&apos;s staff list — would end the product. It&apos;s enforced at the
                query layer, not in the interface.
              </p>
            </Card>
          </div>
        </div>
      </section>

      <CtaBand
        title="Come and argue with the numbers."
        lede="Bring a week of shifts. We'll cluster them against real corridors and show you what next Monday would cost."
        primary={{ href: "/contact", label: "Book a walkthrough" }}
        secondary={{ href: "/customers", label: "See customers" }}
      />
    </>
  );
}
