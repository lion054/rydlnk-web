import type { Metadata } from "next";
import { CtaBand, PageHero } from "@/components/page-chrome";
import { Card, SectionHead } from "@/components/ui";
import { PhotoStrip } from "@/components/media";
import { images } from "@/lib/images";

export const metadata: Metadata = {
  title: "Drive with Rydlnk",
  description: "Fixed corridors, seats sold before you set off, and the same run every week. What you need and how you get paid.",
};

export default function DriversPage() {
  return (
    <>
      <PageHero
          image={images.driverNight}
          tone="forest"
          eyebrow="Drive with Rydlnk"
          title="The seats are sold before you turn the key."
          lede="Rydlnk isn't a queue you sit in waiting for a ping. You take a published run on a fixed corridor, with a manifest, at a time you agreed to — and the fares for those seats are already collected."
        />

        <section className="py-16">
          <div className="wrap">
            <SectionHead eyebrow="Why drivers stay" title="Four things a hailing app can't offer you." />
            <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
              {[
                ["No dead running", "You know where the run starts, where it ends and when. You're not crossing town empty hoping for a fare on the other side."],
                ["Paid per run, not per ping", "The seats on your manifest are already paid for. A no-show doesn't cost you — it costs the person who booked it."],
                ["The same week, every week", "Corridors repeat. You build a schedule you can plan a life around, and you get to know your passengers."],
                ["Settled weekly", "Earnings are paid out weekly, with a statement per run showing seats, distance and any waiting time."],
              ].map(([h, p]) => (
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
              <SectionHead eyebrow="What you need" title="Five documents and a roadworthy vehicle." />
              <ul className="space-y-3 text-[0.9rem] text-muted">
                {[
                  "Valid driver's license, held for at least two years",
                  "Police clearance, renewed every six months",
                  "Vehicle registration in your name or a signed operator agreement",
                  "Current vehicle inspection certificate",
                  "Passenger liability insurance",
                ].map((i) => (
                  <li key={i} className="flex gap-3">
                    <span className="mt-0.5 grid h-4 w-4 shrink-0 place-items-center rounded-full bg-signal/15 text-[0.6rem] text-signaldim">✓</span>
                    {i}
                  </li>
                ))}
              </ul>
              <p className="mt-5 text-[0.88rem] text-muted">
                Documents are re-checked automatically. If something is about to expire you'll hear about it two weeks
                out, because a lapsed certificate takes you off published runs the day it expires.
              </p>
            </div>
            <Card className="bg-paper">
              <h3 className="h3">A typical night run</h3>
              <table className="mt-4 w-full font-mono text-[0.82rem]">
                <tbody>
                  {[
                    ["Corridor", "East Bay → Spanish Fork"],
                    ["Departure", "22:15, Mon–Thu"],
                    ["Distance", "24 miles, 6 stops"],
                    ["Seats sold", "4 of 4"],
                    ["Passengers", "Same group most weeks"],
                    ["Settlement", "Weekly, per run"],
                  ].map(([k, v]) => (
                    <tr key={k} className="border-b border-line last:border-b-0">
                      <td className="py-2.5 text-muted">{k}</td>
                      <td className="py-2.5 text-right text-ink">{v}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <p className="mt-4 text-[0.84rem] text-muted">
                Runs are offered by corridor. You can hold a regular slot, or pick up runs when they're published.
              </p>
            </Card>
          </div>
        </section>
      <PhotoStrip />


        <CtaBand
          title="Take a corridor."
          lede="Send your documents and tell us which side of town you work. We'll match you to a run that's already selling seats."
          primary={{ href: "/drivers/apply", label: "Apply to drive" }}
        />
    </>
  );
}
