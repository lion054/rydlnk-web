import { redirect } from "next/navigation";
import Link from "next/link";
import { EmptyState, Kpi, Panel, TopBar, td, th } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import * as Icon from "@/components/icons";
import { getFloat, getInvoices, getSession, getSpendByCostCenter } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";
import { TopUpPanel } from "./topup";

export const metadata = { title: "Billing" };

export default async function BillingPage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const companyId = session.membership.company_id;
  const supabase = await createClient();

  const [float, invoices, spend, topupsRes, stripeRes] = await Promise.all([
    getFloat(companyId),
    getInvoices(companyId),
    getSpendByCostCenter(companyId),
    supabase
      .from("float_topups")
      .select("id, credits, amount_cents, status, auto, created_at")
      .eq("company_id", companyId)
      .order("created_at", { ascending: false })
      .limit(20),
    supabase
      .from("company_stripe_customers")
      .select("stripe_customer_id, ach_enabled")
      .eq("company_id", companyId)
      .maybeSingle(),
  ]);

  const topups = topupsRes.data ?? [];
  const connected = Boolean(stripeRes.data?.stripe_customer_id);
  const role = session.membership.role;
  const canSpend = role === "owner" || role === "admin" || role === "finance";

  const money = (c: number) => `$${(c / 100).toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
  const openInvoice = invoices.find((i) => i.status === "open");
  const totalSpend = spend.reduce((a, c) => a + (c.credits ?? 0), 0);

  return (
    <>
      <TopBar title="Billing">
        {openInvoice ? <Chip tone="warn">1 invoice open</Chip> : <Chip tone="ok">Nothing outstanding</Chip>}
      </TopBar>

      <div className="space-y-4 p-5 lg:p-7">
        <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
          <Kpi label="Float" value={`${float.toLocaleString()} cr`} tone={float < 500 ? "down" : "up"} />
          <Kpi label="Consumed this period" value={`${totalSpend.toLocaleString()} cr`} />
          <Kpi label="Top-ups" value={topups.length.toLocaleString()} sub="most recent 20" />
          <Kpi
            label="Payment method"
            value={connected ? "Connected" : "Not set"}
            sub={connected ? (stripeRes.data?.ach_enabled ? "ACH enabled" : "Card only") : "Add one to fund the float"}
            tone={connected ? "up" : "down"}
          />
        </div>

        {!connected ? (
          <Panel title="Connect a payment method">
            <div className="flex flex-wrap items-center gap-4 p-5 lg:p-6">
              <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-amber/15 text-amberdim">
                <Icon.Alert size={20} />
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-base font-semibold">Stripe isn&apos;t connected yet.</p>
                <p className="mt-1 text-base text-muted">
                  Until it is, the float can only be topped up manually. ACH is worth enabling before you go live —
                  a five-figure monthly float on a card will hit limits and cost you interchange.
                </p>
              </div>
            </div>
          </Panel>
        ) : null}

        {canSpend ? <TopUpPanel companyId={companyId} connected={connected} /> : null}

        <Panel title="Top-ups">
          {topups.length === 0 ? (
            <EmptyState title="No top-ups yet." body="Funding the float posts a 'topup' entry to the ledger and the credits become available immediately." />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[620px] text-base">
                <thead>
                  <tr>
                    <th scope="col" className={th}>When</th>
                    <th scope="col" className={`${th} text-right`}>Credits</th>
                    <th scope="col" className={`${th} text-right`}>Amount</th>
                    <th scope="col" className={th}>Source</th>
                    <th scope="col" className={th}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {topups.map((t) => (
                    <tr key={t.id} className="hover:bg-[#fafbfa]">
                      <td className={`${td} nums text-muted`}>
                        {new Date(t.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                      </td>
                      <td className={`${td} nums text-right font-semibold`}>{t.credits.toLocaleString()}</td>
                      <td className={`${td} nums text-right`}>{money(t.amount_cents)}</td>
                      <td className={td}>{t.auto ? "Auto top-up" : "Manual"}</td>
                      <td className={td}>
                        <Chip tone={t.status === "succeeded" ? "ok" : t.status === "failed" ? "bad" : "warn"}>
                          {t.status}
                        </Chip>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>

        <Panel title="Prepaid statements">
          {invoices.length === 0 ? (
            <EmptyState
              title="No statements yet."
              body="Monthly statements reconcile settled seats against the prepaid float, split by cost center. They do not charge the company a second time."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[680px] text-base">
                <thead>
                  <tr>
                    <th scope="col" className={th}>Statement</th>
                    <th scope="col" className={th}>Period</th>
                    <th scope="col" className={th}>Due</th>
                    <th scope="col" className={th}>Status</th>
                    <th scope="col" className={`${th} text-right`}>Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {invoices.map((i) => (
                    <tr key={i.id} className="hover:bg-[#fafbfa]">
                      <td className={`${td} nums font-semibold`}>
                        <Link className="text-signal underline underline-offset-4" href={`/portal/billing/invoices/${i.id}`}>
                          {i.number ?? i.id.slice(0, 8)}
                        </Link>
                      </td>
                      <td className={`${td} nums text-muted`}>
                        {new Date(i.period_start).toLocaleDateString("en-US", { month: "short", year: "numeric" })}
                      </td>
                      <td className={`${td} nums text-muted`}>
                        {i.due_at ? new Date(i.due_at).toLocaleDateString("en-US", { month: "short", day: "numeric" }) : "—"}
                      </td>
                      <td className={td}>
                        <Chip tone={i.status === "paid" ? "ok" : i.status === "open" ? "warn" : "neutral"}>
                          {i.status}
                        </Chip>
                      </td>
                      <td className={`${td} nums text-right font-semibold`}>{money(i.total_cents)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>
      </div>
    </>
  );
}
