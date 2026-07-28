import type { Metadata } from "next";
import { PageHero } from "@/components/page-chrome";
import { Card, SectionHead } from "@/components/ui";
import { images } from "@/lib/images";

export const metadata: Metadata = {
  title: "Security — Rydlnk for Work",
  description:
    "What another employer can see when you pool a corridor, how rider data is scoped and retained, and how drivers are vetted.",
};

const isolation: [string, string][] = [
  ["Authorization is per seat, not per trip", "A pooled trip has one identifier and several owners. Every read is scoped to the seats you paid for, at the query layer rather than in the interface. Asking for a trip you partly own returns your seats and an occupancy count."],
  ["No cross-employer directory", "There is no screen, export or API response in the product where one employer can enumerate another's staff. Pooled riders are counted, never named."],
  ["Drivers see one manifest at a time", "A driver sees names and PINs for the run they are currently driving, and loses access when the run closes. Historic manifests are not browsable from the driver app."],
  ["Home addresses are the sensitive field", "Pickup points are stored separately from the rest of the employee record, are never exposed to another employer, and are only resolved to a street location inside the routing engine."],
];

const practices: [string, string][] = [
  ["Driver vetting", "License, police clearance, vehicle inspection and passenger insurance, re-verified every six months. An expiring document pulls the driver off published runs automatically rather than raising a task somebody has to action."],
  ["Trip integrity", "A credit only moves when a boarding PIN is presented. That single control removes the two common fraud patterns: charging for a passenger who was never collected, and a rider claiming a seat they were not entitled to."],
  ["Data retention", "Trip records are kept for the period your finance team needs for audit, then reduced to aggregate. Rider location history is not retained beyond the settlement window."],
  ["Data protection", "Processing is registered under the applicable data protection legislation, with a named controller relationship for employer-funded trips and a separate basis for personal trips."],
];

export default function SecurityPage() {
  return (
    <>
      <PageHero
        image={images.carsNight}
        tone="ink"
        eyebrow="Security & privacy"
        title="Sharing a vehicle is not sharing your data."
        lede="Pooling is the part of this product that makes a risk team sit up, and rightly so — the trip record is shared, and the passenger list contains where people live and what time they finish work in the dark. Here is exactly how that is separated."
      />

      <section className="py-16">
        <div className="wrap">
          <SectionHead
            eyebrow="Tenant isolation"
            title="One trip, several owners, no shared view."
            lede="This is the highest-severity design question in the whole product, so it is worth being concrete about it rather than saying the word encryption."
          />
          <div className="grid gap-3.5 lg:grid-cols-2">
            {isolation.map(([h, p]) => (
              <Card key={h}>
                <h3 className="h3">{h}</h3>
                <p className="mt-2 text-[0.9rem] text-muted">{p}</p>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="border-y border-line bg-white py-16">
        <div className="wrap">
          <SectionHead eyebrow="Operating practice" title="The controls that hold up on a Tuesday night." />
          <div className="grid gap-3.5 lg:grid-cols-2">
            {practices.map(([h, p]) => (
              <Card key={h} className="bg-paper">
                <h3 className="h3">{h}</h3>
                <p className="mt-2 text-[0.9rem] text-muted">{p}</p>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="wrap grid gap-10 lg:grid-cols-2">
          <div>
            <SectionHead eyebrow="Roles in the portal" title="Not everyone who needs a report needs the directory." />
            <p className="text-[0.95rem] text-muted">
              Transport tends to be owned by three teams at once, which is how staff lists end up in email attachments.
              The portal separates them so nobody has to be over-privileged in order to do their part.
            </p>
          </div>
          <div className="overflow-hidden rounded-[14px] border border-line bg-white">
            {[
              ["HR admin", "People, entitlements, allocation rules. No trip-level rider detail."],
              ["Operations", "Manifests, corridors, no-show reports. Sees riders on runs they operate."],
              ["Finance", "Ledger, invoices, journals, cost-center reporting. No personal addresses."],
              ["Security desk", "Live trip status for staff who opted to share it, for the duration of the trip only."],
            ].map(([role, scope], i, arr) => (
              <div key={role} className={`grid gap-1 p-5 sm:grid-cols-[130px_1fr] sm:gap-4 ${i < arr.length - 1 ? "border-b border-line" : ""}`}>
                <span className="font-mono text-[0.7rem] uppercase tracking-[0.11em] text-amberdim">{role}</span>
                <span className="text-[0.88rem] text-muted">{scope}</span>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
