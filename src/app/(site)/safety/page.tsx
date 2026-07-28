import type { Metadata } from "next";
import { PageHero } from "@/components/page-chrome";
import { Card, SectionHead } from "@/components/ui";
import { images } from "@/lib/images";

export const metadata: Metadata = {
  title: "Safety — Rydlnk",
  description: "Designed around the 22:00 finish: drop-order rules, verified drivers, live trip sharing and PIN boarding.",
};

const controls: [string, string][] = [
  ["Never last, alone", "After 21:00 the drop order is rearranged so nobody is the final passenger in the vehicle on their own. If the route makes that impossible, the trip gets a second passenger or a check-in call, not a shrug."],
  ["Checked drivers", "License, police clearance, vehicle inspection and passenger insurance, re-verified every six months. An expiring document pulls a driver off published runs automatically."],
  ["Live trip sharing", "Share your trip with someone you trust, or with your employer's security desk, for as long as you're travelling. It stops when the trip does."],
  ["PIN on boarding", "Your fare only moves when you give the driver your PIN. It also means a driver can't complete a trip you weren't in."],
  ["The same faces", "Because runs repeat, you travel with the same small group week after week. Familiarity does more for how safe a night trip feels than any feature we could ship."],
  ["Report from the trip", "One tap during or after a trip, and it goes to a person, not a queue. Drivers accumulate a record, and the record has consequences."],
];

export default function SafetyPage() {
  return (
    <>
      <PageHero
        image={images.streetNight}
        tone="ink"
        eyebrow="Safety"
        title="The night shift was the hard part. We designed for it first."
        lede="Most shared-ride products are built around a Friday night in town. This one was built around someone finishing at 22:00 in East Bay and needing to get home to Spanish Fork — which is a different problem with different failure modes."
      />

      <section className="py-16">
        <div className="wrap">
          <SectionHead eyebrow="The controls" title="Six things, and none of them are a badge on a marketing page." />
          <div className="grid gap-3.5 md:grid-cols-2 xl:grid-cols-3">
            {controls.map(([h, p]) => (
              <Card key={h}>
                <h3 className="h3">{h}</h3>
                <p className="mt-2 text-[0.88rem] text-muted">{p}</p>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="border-y border-line bg-white py-16">
        <div className="wrap grid gap-10 lg:grid-cols-2">
          <div>
            <SectionHead eyebrow="What we ask of you" title="Two things, and the second one matters more." />
            <p className="text-[0.95rem] text-muted">
              Verify your identity once, so that everyone else in the vehicle is travelling with a verified person too.
              And pick a pickup point you're comfortable standing at for two minutes — it doesn't have to be your gate,
              and plenty of people deliberately choose that it isn't.
            </p>
            <p className="mt-4 text-[0.95rem] text-muted">
              If a pickup point stops feeling right, change it in the app. It takes one tap and needs no explanation.
            </p>
          </div>
          <Card className="bg-paper">
            <h3 className="h3">If something goes wrong</h3>
            <ol className="mt-4 space-y-3.5 text-[0.88rem] text-muted">
              {[
                ["In the vehicle", "The report button is on the trip screen and works without the driver seeing it."],
                ["Driver didn't arrive", "Report it. No PIN was given, so no fare is charged, and the run is investigated."],
                ["Wrong vehicle", "Check the plate against the one in the app before boarding. If it doesn't match, don't get in — tell us and we'll find you a seat."],
                ["After the trip", "Reports stay open for seven days. You don't have to decide how serious it is in the moment."],
              ].map(([k, v], i) => (
                <li key={k} className="flex gap-3 border-b border-line pb-3.5 last:border-b-0 last:pb-0">
                  <span className="font-mono text-[0.7rem] text-amberdim">{String(i + 1).padStart(2, "0")}</span>
                  <span>
                    <span className="block font-semibold text-ink">{k}</span>
                    {v}
                  </span>
                </li>
              ))}
            </ol>
          </Card>
        </div>
      </section>
    </>
  );
}
