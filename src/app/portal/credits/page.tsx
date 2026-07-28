import { redirect } from "next/navigation";
import { EmptyState, Kpi, Panel, TopBar, td, th } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import { getBenefitUsage, getFloat, getLedger, getSession } from "@/lib/queries";
import { TRANSIT_BENEFIT_CAP } from "@/lib/data";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "Credits & policy" };

/** Human labels for the ledger's movement kinds. */
const KINDS: Record<string, { label: string; tone: "ok" | "warn" | "bad" | "neutral" }> = {
  topup: { label: "Top-up", tone: "ok" },
  allocation: { label: "Allocation", tone: "neutral" },
  consumption: { label: "Consumption", tone: "neutral" },
  hold: { label: "Hold", tone: "warn" },
  release: { label: "Release", tone: "neutral" },
  rebate: { label: "Pool rebate", tone: "ok" },
  reclaim: { label: "Reclaim", tone: "ok" },
  expiry: { label: "Expiry", tone: "warn" },
  no_show: { label: "No-show charge", tone: "bad" },
  refund: { label: "Refund", tone: "ok" },
  adjustment: { label: "Adjustment", tone: "warn" },
};

const ACCOUNTS: Record<string, string> = {
  external: "External",
  company_float: "Company float",
  employee_wallet: "Employee wallet",
  seat: "Seat",
  clearing: "Rydlnk clearing",
};

export default async function CreditsPage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const companyId = session.membership.company_id;
  const supabase = await createClient();

  const [float, ledger, benefit, policyRes] = await Promise.all([
    getFloat(companyId),
    getLedger(companyId, 50),
    getBenefitUsage(companyId),
    supabase.from("company_policies").select("*").eq("company_id", companyId).maybeSingle(),
  ]);
  const policy = policyRes.data;

  const pretax = benefit.reduce((a, b) => a + (b.pretax_credits ?? 0), 0);
  const posttax = benefit.reduce((a, b) => a + (b.posttax_credits ?? 0), 0);

  return (
    <>
      <TopBar title="Credits & policy">
        <Chip tone={float > 0 ? "ok" : "warn"}>{float.toLocaleString()} cr in float</Chip>
      </TopBar>

      <div className="space-y-4 p-5 lg:p-7">
        <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
          <Kpi label="Float" value={`${float.toLocaleString()} cr`} />
          <Kpi
            label="Pre-tax allocated"
            value={`${pretax.toLocaleString()} cr`}
            sub={`cap $${TRANSIT_BENEFIT_CAP}/person/month`}
            tone={pretax ? "up" : undefined}
          />
          <Kpi
            label="Post-tax allocated"
            value={`${posttax.toLocaleString()} cr`}
            sub={posttax ? "above the §132(f) cap" : "none over the cap"}
          />
          <Kpi label="Ledger entries" value={ledger.length.toLocaleString()} sub="most recent 50" />
        </div>

        <Panel title="Ledger">
          {ledger.length === 0 ? (
            <EmptyState
              title="Nothing posted yet."
              body="Fund the float and every movement after it — allocations, holds, consumption, rebates — appears here as an append-only entry."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[760px] text-base">
                <caption className="sr-only">Append-only credit ledger</caption>
                <thead>
                  <tr>
                    <th scope="col" className={th}>When</th>
                    <th scope="col" className={th}>Kind</th>
                    <th scope="col" className={th}>From</th>
                    <th scope="col" className={th}>To</th>
                    <th scope="col" className={th}>Reference</th>
                    <th scope="col" className={`${th} text-right`}>Credits</th>
                  </tr>
                </thead>
                <tbody>
                  {ledger.map((e) => {
                    const k = KINDS[e.kind] ?? { label: e.kind, tone: "neutral" as const };
                    return (
                      <tr key={e.id} className="hover:bg-[#fafbfa]">
                        <td className={`${td} nums whitespace-nowrap text-muted`}>
                          {new Date(e.created_at).toLocaleString("en-US", {
                            month: "short",
                            day: "numeric",
                            hour: "numeric",
                            minute: "2-digit",
                          })}
                        </td>
                        <td className={td}>
                          <Chip tone={k.tone}>{k.label}</Chip>
                        </td>
                        <td className={`${td} text-muted`}>{ACCOUNTS[e.from_kind] ?? e.from_kind}</td>
                        <td className={`${td} text-muted`}>{ACCOUNTS[e.to_kind] ?? e.to_kind}</td>
                        <td className={`${td} nums text-xs text-muted`}>{e.ref}</td>
                        <td className={`${td} nums text-right font-semibold`}>{e.credits.toLocaleString()}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
          <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">
            Append-only by design. Nothing here is edited or deleted — a correction is a new reversing entry, which
            is what lets month-end reconcile without an argument.
          </p>
        </Panel>

        <Panel title="Policy">
          <dl className="grid gap-x-8 gap-y-4 p-5 sm:grid-cols-2 lg:grid-cols-3 lg:p-6">
            {[
              ["Per-trip cap", policy?.per_trip_cap_credits ? `${policy.per_trip_cap_credits} cr` : "No cap"],
              ["Per-week cap", policy?.per_week_cap_credits ? `${policy.per_week_cap_credits} cr` : "No cap"],
              ["Max trip distance", policy?.max_trip_miles ? `${policy.max_trip_miles} miles` : "No limit"],
              [
                "Funded days",
                ((policy?.funded_days ?? []) as number[])
                  .map((d) => ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d])
                  .join(", ") || "Every day",
              ],
              ["Over-cap trips", policy?.split_tender_over_cap ? "Split — rider covers the difference" : "Refused"],
              ["Unused credits", String(policy?.unused_credits_policy ?? "return after 7 days").replace(/_/g, " ")],
              ["Night-shift rule", policy?.night_safety_rule ? "On — never drop the last rider alone" : "Off"],
              [
                "Visible to pooled riders",
                String(policy?.visible_to_pooled_riders ?? "first name").replace(/_/g, " "),
              ],
            ].map(([k, v]) => (
              <div key={k as string}>
                <dt className="label text-muted">{k as string}</dt>
                <dd className="mt-1 text-base font-semibold">{v as string}</dd>
              </div>
            ))}
          </dl>
        </Panel>
      </div>
    </>
  );
}
