import type { Metadata } from "next";
import Link from "next/link";
import { PageHero } from "@/components/page-chrome";
import { FareCalculator } from "@/components/fare-calculator";
import { Card, SectionHead } from "@/components/ui";
import { images } from "@/lib/images";
import { CorridorMap } from "@/components/corridor-map";

export const metadata: Metadata = {
  title: "Fares — Rydlnk",
  description: "A fixed price per seat, published in advance. No surge, no estimate ranges, no fare that moves between booking and arriving.",
};

export default function FaresPage() {
  return (
    <>
      <PageHero
        image={images.busInterior}
        tone="forest"
        eyebrow="Fares"
        title="A fixed price per seat, published in advance."
        lede="No surge, no estimate range, no fare that changes between booking and arriving. Move the sliders and see what your week actually costs."
      />

      <section className="py-14">
        <div className="wrap">
          <p className="eyebrow text-signal">The network</p>
          <h2 className="h2 mb-3 mt-3 max-w-[20ch]">Five corridors out of East Bay.</h2>
          <p className="mb-8 max-w-[58ch] text-md text-muted">
            Every run starts at the East Bay employment district in Provo and works south or north along I-15.
            Share your location and we&apos;ll point at the one nearest you.
          </p>
          <CorridorMap />
        </div>
      </section>

      <section className="py-16">
        <div className="wrap">
          <FareCalculator />
        </div>
      </section>

      <section className="border-y border-line bg-white py-16">
        <div className="wrap">
          <SectionHead
            eyebrow="Published corridors"
            title="What each Utah County corridor costs today."
            lede="Seat prices are set by distance and time band, not by demand. They change when a corridor's economics change, and we tell you before they do."
          />
          <div className="overflow-x-auto rounded-[14px] border border-line">
            <table className="w-full min-w-[560px] text-[0.88rem]">
              <thead>
                <tr>
                  {["Corridor", "Distance", "Departures", "Day seat", "Night seat"].map((h, i) => (
                    <th key={h} className={`border-b border-line bg-paper px-4 py-2.5 font-mono text-[0.63rem] uppercase tracking-[0.11em] text-muted ${i > 1 ? "text-right" : "text-left"}`}>
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="bg-white">
                {[
                  ["Spanish Fork ↔ East Bay", "24 miles", "06:00 · 14:00 · 22:15", "$3.20", "$4.00"],
                  ["Payson ↔ CBD", "19 miles", "06:00 · 22:15", "$2.80", "$3.60"],
                  ["Orem ↔ East Bay", "16 miles", "06:00 · 14:00 · 22:30", "$2.40", "$3.20"],
                  ["Springville ↔ East Bay", "21 miles", "22:30", "—", "$4.00"],
                  ["Lehi ↔ CBD", "12 miles", "06:00 · 23:00", "$2.00", "$2.80"],
                ].map(([a, b, c, d, e]) => (
                  <tr key={a}>
                    <td className="border-b border-line px-4 py-3 font-medium">{a}</td>
                    <td className="border-b border-line px-4 py-3 font-mono text-[0.8rem] text-muted">{b}</td>
                    <td className="border-b border-line px-4 py-3 text-right font-mono text-[0.78rem] text-muted">{c}</td>
                    <td className="border-b border-line px-4 py-3 text-right font-mono">{d}</td>
                    <td className="border-b border-line px-4 py-3 text-right font-mono text-amberdim">{e}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-4 text-[0.84rem] text-muted">
            Night seats cost more because vehicles come back empty and drivers are paid a night rate. That difference is
            published rather than buried in a multiplier.
          </p>
        </div>
      </section>

      <section className="py-16">
        <div className="wrap grid gap-3.5 lg:grid-cols-3">
          <Card>
            <h3 className="h3">Why it can be this cheap</h3>
            <p className="mt-2 text-[0.9rem] text-muted">
              You're paying for one seat, not the vehicle. Four people on a 24 miles run each pay a quarter of what it costs
              to send that vehicle — and because the runs repeat weekly, the driver isn't burning fuel looking for the
              next job.
            </p>
          </Card>
          <Card>
            <h3 className="h3">How the wallet works</h3>
            <p className="mt-2 text-[0.9rem] text-muted">
              Top up from $2 by card, mobile money or bank transfer. Fares come off as you travel. Unused money stays
              yours and can be withdrawn back to the card you paid with — it isn't credit, and it doesn't expire.
            </p>
          </Card>
          <Card>
            <h3 className="h3">If your employer pays</h3>
            <p className="mt-2 text-[0.9rem] text-muted">
              Employer credits appear as a second balance and are spent first. If a trip costs more than their policy
              allows, the difference comes off your balance rather than the trip being refused.{" "}
              <Link href="/business" className="text-signaldim underline underline-offset-2">
                How that works
              </Link>
              .
            </p>
          </Card>
        </div>
      </section>
    </>
  );
}
