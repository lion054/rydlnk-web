import type { Metadata } from "next";
import { PageHero } from "@/components/page-chrome";
import { Card, Icon, SectionHead } from "@/components/ui";

export const metadata: Metadata = {
  title: "How it works — Rydlnk",
  description: "Set your week once, get matched with people going your way, and board with a PIN. That's the whole thing.",
};

const week: [string, string, string][] = [
  ["Sunday", "You set the week", "Pickup point, drop-off, and the times you need to be there. Five minutes, and it carries over to next week unless you change it."],
  ["Sunday night", "We build the runs", "Rydlnk groups people within about 1.5 miles of each other heading the same way at the same time, and works out how many vehicles each departure needs."],
  ["Every evening", "You get tomorrow", "Driver, plate, pickup time and your seat cost. Confirm, decline, or ignore it — ignoring it means you're riding."],
  ["4 hours before", "The run locks", "The vehicle is committed. You can still travel; you just can't get the seat back if you don't."],
  ["At the vehicle", "You give the PIN", "That's the only moment money moves. No PIN, no charge, nothing to dispute afterwards."],
];

export default function HowItWorksPage() {
  return (
    <>
      <PageHero
        eyebrow="How it works"
        title="Three things happen, and only one of them involves you."
        lede="A commute is the most predictable trip you take all week. It shouldn't need a decision every morning, and it shouldn't cost you as though it were a surprise."
      />

      <section className="py-16">
        <div className="wrap">
          <div className="grid gap-3.5 md:grid-cols-3">
            <Card>
              <Icon>◷</Icon>
              <h3 className="h3">You set your week</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                Where you leave from, where you're going, and when you need to be there. Change it whenever your shift
                changes — up to four hours before any single trip.
              </p>
            </Card>
            <Card>
              <Icon>◈</Icon>
              <h3 className="h3">We fill the vehicle</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                People going the same way at the same time get grouped onto one run, and a driver is assigned the night
                before. Usually the same faces week after week.
              </p>
            </Card>
            <Card>
              <Icon>✓</Icon>
              <h3 className="h3">You get a seat and a PIN</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                Your driver, plate and pickup time arrive the evening before. Give the PIN when you board — that's the
                only time money moves.
              </p>
            </Card>
          </div>
        </div>
      </section>

      <section className="border-y border-line bg-white py-16">
        <div className="wrap">
          <SectionHead
            eyebrow="A week, in order"
            title="What actually lands on your phone, and when."
          />
          <ol className="overflow-hidden rounded-[14px] border border-line">
            {week.map(([when, what, detail], i) => (
              <li key={what} className={`grid gap-1 bg-paper p-5 sm:grid-cols-[120px_180px_1fr] sm:items-baseline sm:gap-5 ${i < week.length - 1 ? "border-b border-line" : ""}`}>
                <span className="font-mono text-[0.68rem] uppercase tracking-[0.13em] text-amberdim">{when}</span>
                <span className="font-display text-[1rem] font-extrabold">{what}</span>
                <span className="text-[0.88rem] text-muted">{detail}</span>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="py-16">
        <div className="wrap grid gap-10 lg:grid-cols-2">
          <div>
            <SectionHead eyebrow="The trade-off" title="You give up spontaneity. That's the deal." />
            <p className="text-[0.95rem] text-muted">
              A seat is a third of the price of a vehicle because the run was already happening. That only holds if the
              run is predictable, which means departures are on a timetable and pickups are at a point rather than at
              your gate.
            </p>
            <p className="mt-4 text-[0.95rem] text-muted">
              If your week is genuinely different every day, Rydlnk will annoy you. If you leave at roughly the same time
              most days — which is most people with a job — it's the cheapest way to make that trip.
            </p>
          </div>
          <Card className="bg-paper">
            <h3 className="h3">What happens when things change</h3>
            <div className="mt-4 space-y-3.5 text-[0.88rem] text-muted">
              {[
                ["Shift moved earlier", "Change it in the app and your seat moves to the earlier run if there's space, or you're offered the next departure."],
                ["Finished late", "Book an off-roster trip. It costs the normal seat price for that corridor and time band."],
                ["Didn't travel", "Inside four hours the seat is charged. Outside four hours it isn't."],
                ["Driver didn't arrive", "Report it in the app. The seat isn't charged, because no PIN was given."],
              ].map(([k, v]) => (
                <div key={k} className="border-b border-line pb-3.5 last:border-b-0 last:pb-0">
                  <span className="block font-semibold text-ink">{k}</span>
                  <span>{v}</span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </section>
    </>
  );
}
