import type { Metadata } from "next";
import { CtaBand, PageHero } from "@/components/page-chrome";
import { HelpCentre, type HelpGroup } from "./help-client";

export const metadata: Metadata = {
  title: "Help",
  description:
    "Answers for riders and for employers — fares, credits, privacy, roster sync, invoicing and what happens when something goes wrong.",
};

/* Replaces /individual/faq and /work/faq. Content reauthored against the
   current product pages rather than migrated verbatim; check each answer
   against policy before launch. */

const groups: HelpGroup[] = [
  {
    audience: "Riders",
    topic: "Getting started",
    items: [
      {
        q: "Do I need my employer to sign up first?",
        a: "No. You can ride and pay from your own balance whether or not your employer is on Rydlnk. If they join later, their credits appear as a second balance in the app you're already using — nothing to reinstall, nothing to claim back.",
      },
      {
        q: "What do I need to sign up?",
        a: "A phone number, a home pickup point, and a driver's license or state ID, checked once. The pickup point doesn't have to be your gate — a corner you're happy to walk to is normal, and a lot of people prefer that.",
      },
      {
        q: "Can I use it without installing the app?",
        a: "Yes. Scheduling, seat confirmations, the boarding PIN and top-ups all work by text message. You'll get your week every Sunday, a confirm-or-decline the evening before each trip, and your driver and PIN an hour ahead.",
      },
      {
        q: "Is this a good fit if my hours change every week?",
        a: "Honestly, no. Rydlnk works when your week is roughly the same each week. If you never travel at the same time twice, an e-hailing app suits you better and we'd rather tell you now.",
      },
    ],
  },
  {
    audience: "Riders",
    topic: "Money",
    items: [
      {
        q: "Does the fare change with traffic or weather?",
        a: "No. The seat price is fixed per corridor and time band, published in advance. It's the same on a Monday morning as on a rainy Friday night. There is no surge multiplier in the product at all.",
      },
      {
        q: "What happens if I don't travel?",
        a: "You can change or cancel up to the manifest lock, four hours before departure. After that the seat is charged whether or not you travel, because the vehicle has already been committed.",
      },
      {
        q: "My employer pays. What comes out of my own money?",
        a: "Company credits are spent first, up to whatever their policy covers. If a trip goes over the cap — a longer drop-off, say — the difference comes off your balance rather than the trip being refused, and you're told before it confirms.",
      },
      {
        q: "If I leave my job, do I lose everything?",
        a: "You lose the company credits — those return to your employer's float. Your own balance stays yours and is still withdrawable, and your personal account isn't closed by your employer.",
      },
    ],
  },
  {
    audience: "Riders",
    topic: "People and privacy",
    items: [
      {
        q: "Who else is in the vehicle?",
        a: "People travelling the same corridor at the same time — often the same group most weeks. On a pooled corridor that can include staff of other employers. What you see about them is set per corridor: first name only, first name and employer, or nothing but a seat number.",
      },
      {
        q: "Can my employer see my weekend trips?",
        a: "No. Employers see the seats they funded and nothing else. Personal trips don't appear in any employer report, at any time, in any form.",
      },
      {
        q: "Who sees my home address?",
        a: "Your driver sees the pickup points on their manifest, because they have to. Your employer sees the corridor and the cluster, never the pin. Your ID is stored encrypted and no employer ever sees it.",
      },
      {
        q: "What do I do if something goes wrong on a trip?",
        a: "Every trip has a driver, a vehicle registration and a boarding PIN on record, so a report always attaches to a specific run. Report it in the app or by text message; conduct that makes a shared vehicle unsafe gets an account suspended.",
      },
    ],
  },
  {
    audience: "Employers",
    topic: "Finance",
    items: [
      {
        q: "What actually appears on the invoice?",
        a: "One invoice per period, split by cost center, with a line per seat consumed. Because a seat belongs to a payer rather than to a trip, a pooled run generates a separate line — and a separate benefit record — for each employer on it.",
      },
      {
        q: "How is this different from a minibus contract?",
        a: "A contract bills you for a vehicle. Rydlnk bills you for seats your staff sat in. On a pooled corridor the empty seats are sold to another employer instead of being carried by you, and the rebate lands back in your float.",
      },
      {
        q: "What does it cost?",
        a: "A platform fee per active employee per month, plus credits spent on seats. Seat price is fixed per corridor and time band. The pricing page has a live estimator you can put your own headcount into.",
      },
      {
        q: "Can we cap what an employee can spend?",
        a: "Yes — per trip, per distance, and per period, set per corridor or per group. Anything over the cap is split: policy covers what it covers, the employee's own balance covers the rest.",
      },
    ],
  },
  {
    audience: "Employers",
    topic: "Operations",
    items: [
      {
        q: "Do staff have to book every day?",
        a: "No, and that's the point. Rydlnk reads your shift roster and publishes manifests from it. Staff confirm or decline; they don't book. The daily booking step is what kills most staff-transport schemes.",
      },
      {
        q: "What if our roster lives in a spreadsheet?",
        a: "Fine. There are connectors for Deputy, Workday, UKG, BambooHR, Zoho, Sage and SAP, and an SFTP/CSV drop where we map your columns once. The minimum is employee number, home address, department and shift start.",
      },
      {
        q: "Someone leaves on Friday. What happens?",
        a: "Terminations arrive on a webhook, not the nightly job, so the wallet is frozen at the point your HR system records it and unspent credits return to the float. A leaver riding on Monday morning is money straight out of your float, which is why this isn't batched.",
      },
      {
        q: "What counts as a no-show?",
        a: "A confirmed seat on a locked manifest that nobody boarded. It's charged to the cost center, and it's attributable — you can see which seat, which run and which employee, which is usually enough for it to stop happening.",
      },
    ],
  },
  {
    audience: "Employers",
    topic: "Risk and HR",
    items: [
      {
        q: "Can another employer see our staff?",
        a: "No. Authorization is scoped per seat at the query layer, not in the interface. Asking for a pooled trip you partly own returns your own seats plus an occupancy count — never another employer's names, departments or addresses.",
      },
      {
        q: "What about the late shift specifically?",
        a: "Night-shift rules reorder the drop sequence so the last passenger is never dropped alone after 21:00, and add a security check-in. It's set per corridor and it's on by default.",
      },
      {
        q: "Are drivers vetted?",
        a: "License held two years or more, police clearance renewed six-monthly, vehicle inspection, and passenger liability insurance. Documents are re-checked automatically and a lapsed certificate takes a driver off published runs the day it expires.",
      },
      {
        q: "Will legal need anything from us?",
        a: "Expect your legal team to ask for a data processing agreement — there's one on the site. We hold employee identifiers and home locations to cluster corridors, and the DPA sets out exactly what for and for how long.",
      },
    ],
  },
];

export default function HelpPage() {
  return (
    <>
      <PageHero
        eyebrow="Help"
        title="The questions people actually ask."
        lede="Riders and employers ask about the same mechanics from opposite sides. Both sets live here — filter or search across all of them."
      />

      <HelpCentre groups={groups} />

      <CtaBand
        title="Still stuck?"
        lede="Riders can message us by text. Employers get a reply within one business day."
        primary={{ href: "/contact", label: "Contact us" }}
        secondary={{ href: "/download", label: "Get the app" }}
      />
    </>
  );
}
