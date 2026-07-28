import type { Metadata } from "next";
import { Clause, LegalPage } from "@/components/legal";
import { contact, mailtoWork } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy",
  description:
    "What Rydlnk collects, who can see it, and what an employer funding your seat is never shown.",
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="What we hold, and who can see it."
      lede="Rydlnk sits between an employer paying for a seat and the person sitting in it. Most of this page is about the wall between those two."
      updated="July 2026"
    >
      <Clause heading="What we collect">
        <p>
          A phone number, verified by SMS, which becomes your account. A home pickup point — a pin or a corner
          you&apos;re happy to walk to, which does not have to be your gate. A driver's license or state ID, checked once
          at sign-up. Your trip history on Rydlnk.
        </p>
        <p>
          If your employer funds your seat, we also receive your employee number, department, cost center and shift
          pattern from their roster or HR system.
        </p>
      </Clause>

      <Clause heading="What your employer never sees">
        <p>
          Your ID. Your home address — they see the corridor and the cluster, not the pin. Any trip
          you paid for yourself, in any report, including trips at the weekend or outside your shift.
        </p>
        <p>
          Employers see the seats they funded: who travelled, on which run, at what cost to their float. That is the
          whole of it.
        </p>
      </Clause>

      <Clause heading="What other riders see">
        <p>
          This is set per corridor by whoever funds it, and the options are first name only, first name and
          employer, or nothing but a seat number. Drivers see the names and pickup points on their manifest,
          because they have to.
        </p>
      </Clause>

      <Clause heading="Numbers we don't keep">
        <p>
          If you ask us to send an install link to your phone and then don&apos;t sign up, the number is discarded.
          It is not added to a marketing list.
        </p>
      </Clause>

      <Clause heading="How long we hold things">
        <p>
          ID documents are stored encrypted for as long as your account is active, and deleted when it
          closes. Trip and ledger records are retained for the period US tax and tax reporting rules
          require, because they back benefit records.
        </p>
      </Clause>

      <Clause heading="If you leave your employer">
        <p>
          Company credits stop and unspent ones return to the employer&apos;s float. Your own balance stays yours
          and remains withdrawable. Your personal account is not closed by your employer.
        </p>
      </Clause>

      <Clause heading="Asking us about your data">
        <p>
          Write to <a className="font-mono text-signaldim underline underline-offset-4" href={mailtoWork}>{contact.workEmail}</a>{" "}
          to request a copy of what we hold, correct it, or ask for deletion.
        </p>
      </Clause>
    </LegalPage>
  );
}
