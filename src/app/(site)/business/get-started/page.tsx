import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { PageHero } from "@/components/page-chrome";
import { createClient } from "@/lib/supabase/server";
import { images } from "@/lib/images";
import * as Icon from "@/components/icons";
import { TRANSIT_BENEFIT_CAP } from "@/lib/data";
import { GetStartedForm } from "./get-started-form";

export const metadata: Metadata = {
  title: "Set up your company",
  description: "Create a Rydlnk company account — fund commuting, set policy, and run it off your roster.",
};

export default async function GetStartedPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Already attached to a company — nothing to set up.
  if (user) {
    const { data: membership } = await supabase
      .from("company_members")
      .select("company_id")
      .eq("user_id", user.id)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();
    if (membership) redirect("/portal");
  }

  return (
    <>
      <PageHero
        image={images.valley}
        tone="forest"
        eyebrow="For business"
        title="Set up your company."
        lede="Four steps. You'll have a funded wallet, a policy and an invite link by the end of it — no call required."
      />

      <section className="py-14 lg:py-20">
        <div className="wrap grid gap-10 lg:grid-cols-[1.15fr_0.85fr] lg:items-start">
          <GetStartedForm signedInEmail={user?.email ?? null} />

          <aside className="space-y-3">
            <div className="rounded-lg border border-line bg-shell p-6">
              <h2 className="text-lg font-extrabold tracking-[-0.015em]">What you get immediately</h2>
              <ul className="mt-4 space-y-3 text-base text-muted">
                {[
                  "A company wallet you fund once and allocate from.",
                  "Policy caps per trip, per week and per corridor.",
                  "An invite link your staff can use the same day.",
                  "One invoice, split by cost center.",
                ].map((t) => (
                  <li key={t} className="flex gap-3">
                    <Icon.Check size={17} className="mt-0.5 shrink-0 text-signal" />
                    {t}
                  </li>
                ))}
              </ul>
            </div>

            <div className="rounded-lg border border-line bg-ink p-6 text-white">
              <h2 className="text-lg font-extrabold tracking-[-0.015em] text-white">
                Why finance signs this off
              </h2>
              <p className="mt-2 text-base text-muteddark">
                Under IRS §132(f), employer-funded commuting up to{" "}
                <span className="font-semibold text-amber">${TRANSIT_BENEFIT_CAP} per employee per month</span> is
                excluded from their gross income and from payroll tax. You save the FICA; they save the income
                tax. It&apos;s cheaper than the equivalent raise on both sides.
              </p>
              <p className="mt-3 text-xs text-muteddark">
                Confirm the current-year cap with your accountant — we track it per employee per month either way.
              </p>
            </div>
          </aside>
        </div>
      </section>
    </>
  );
}
