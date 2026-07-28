import type { Metadata } from "next";
import { Clause, LegalPage } from "@/components/legal";
import { contact, mailtoWork } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms",
  description: "The terms on which Rydlnk sells a seat, and what a fixed fare does and doesn't cover.",
};

export default function TermsPage() {
  return (
    <LegalPage
      title="What you're buying when you buy a seat."
      lede="Rydlnk sells a seat on a scheduled run, not a vehicle and not a private hire. The difference matters in a few specific places."
      updated="July 2026"
    >
      <Clause heading="What a seat is">
        <p>
          A seat is a place on a published run along a fixed corridor at a stated departure time. It is not an
          exclusive booking of the vehicle. Other people — including staff of other employers, where the corridor
          allows pooling — may occupy the other seats.
        </p>
      </Clause>

      <Clause heading="The fare is fixed">
        <p>
          The seat price for a corridor and time band is published in advance and does not change with traffic,
          weather, demand or how many other seats sell. Rydlnk carries the difference between the seats sold and
          the cost of running the vehicle.
        </p>
      </Clause>

      <Clause heading="Changes and no-shows">
        <p>
          You can change or cancel a trip up to the manifest lock, stated per corridor and currently four hours
          before departure. After the lock the seat is charged whether or not you travel, because the vehicle has
          been committed.
        </p>
      </Clause>

      <Clause heading="Employer-funded seats">
        <p>
          Where an employer funds your seat, their credits are spent first and their policy sets what is covered —
          typically a distance or credit cap per trip. Anything above the cap comes off your own balance rather than
          being refused, and you are told before the trip is confirmed.
        </p>
        <p>
          Credits are a prepaid balance held by your employer, not money owed to you. Unspent credits return to the
          employer&apos;s float on the schedule they set.
        </p>
      </Clause>

      <Clause heading="Conduct in the vehicle">
        <p>
          Everyone in the vehicle is a stranger until they aren&apos;t, which is why riders are verified as well as
          drivers. Rydlnk may suspend an account for conduct that makes a shared vehicle unsafe.
        </p>
      </Clause>

      <Clause heading="When a run doesn't happen">
        <p>
          If Rydlnk cancels a run, the seat is not charged and any credits or balance spent on it are returned. We
          are not liable for consequential loss — a missed shift, for instance — arising from a canceled or delayed
          run.
        </p>
      </Clause>

      <Clause heading="Questions">
        <p>
          <a className="font-mono text-signaldim underline underline-offset-4" href={mailtoWork}>{contact.workEmail}</a>
        </p>
      </Clause>
    </LegalPage>
  );
}
