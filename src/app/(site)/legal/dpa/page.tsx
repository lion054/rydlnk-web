import type { Metadata } from "next";
import { Clause, LegalPage } from "@/components/legal";
import { contact, mailtoWork } from "@/lib/site";

export const metadata: Metadata = {
  title: "Data processing",
  description:
    "What Rydlnk processes on an employer's behalf, on what basis, and for how long — the agreement your legal team will ask for.",
};

/* Employers' legal teams ask for this before signing. Having no DPA is a
   procurement blocker, not a content gap. */

export default function DpaPage() {
  return (
    <LegalPage
      title="Data processing agreement."
      lede="When an employer funds seats, Rydlnk processes employee data on their instructions. This sets out what, why, for how long, and what happens at the end."
      updated="July 2026"
    >
      <Clause heading="Roles">
        <p>
          For employee records supplied by an employer — names, employee numbers, departments, cost centers, home
          cities and shift patterns — the employer is the <strong className="font-semibold text-ink">controller</strong>{" "}
          and Rydlnk is the <strong className="font-semibold text-ink">processor</strong>.
        </p>
        <p>
          For a rider&apos;s own account — their phone number, ID, personal trips and personal
          balance — Rydlnk is the controller. An employer never becomes a controller of that data by funding a
          seat.
        </p>
      </Clause>

      <Clause heading="What we process, and why">
        <p>
          Employee identifier, department and cost center, to attribute a seat to the right budget line. Home
          city or pickup point, to cluster people into corridors. Shift start and end, to schedule runs.
          Employment status, so a leaver&apos;s wallet freezes.
        </p>
        <p>
          We do not process employee data for any purpose the employer has not instructed, and we do not use it to
          train models or to market to your staff.
        </p>
      </Clause>

      <Clause heading="Sub-processors">
        <p>
          Cloud hosting, SMS and text message delivery, and payment processing. A current list is available on request
          and we give notice before adding one, so you have the chance to object.
        </p>
      </Clause>

      <Clause heading="Security measures">
        <p>
          Authorization is scoped per seat at the query layer rather than in the interface, which is what keeps one
          employer from reading another&apos;s staff on a pooled trip. ID documents are encrypted at rest.
          Access to production data is limited, logged and reviewed.
        </p>
      </Clause>

      <Clause heading="Breach notification">
        <p>
          We notify the employer without undue delay and in any case within 72 hours of becoming aware of a
          personal data breach affecting their employees, with what we know at the time and what we&apos;re doing
          about it.
        </p>
      </Clause>

      <Clause heading="Retention and deletion">
        <p>
          Employee records are deleted or anonymized within 90 days of the end of the agreement, except trip and
          ledger entries retained for the period US tax and tax reporting rules require — those back the
          benefit records already issued and cannot be removed earlier.
        </p>
      </Clause>

      <Clause heading="Audit and assistance">
        <p>
          We&apos;ll respond to reasonable audit requests, and assist with data subject requests your employees
          make to you — access, correction and deletion — within the statutory window.
        </p>
      </Clause>

      <Clause heading="Contact">
        <p>
          Data protection queries:{" "}
          <a className="font-mono text-signal underline underline-offset-4" href={mailtoWork}>
            {contact.workEmail}
          </a>
        </p>
      </Clause>
    </LegalPage>
  );
}
