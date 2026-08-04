import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Chip } from "@/components/ui";
import { Panel, TopBar, td, th } from "@/components/portal/chrome";
import { createClient } from "@/lib/supabase/server";
import { getSession } from "@/lib/queries";
import { PrintButton } from "./print-button";

export const metadata = { title: "Company statement" };

export default async function CompanyStatementPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const { id } = await params;
  const supabase = await createClient();
  const [{ data: invoice }, { data: lines }] = await Promise.all([
    supabase
      .from("company_invoices")
      .select("id, company_id, number, period_start, period_end, seat_credits, platform_cents, rebate_credits, total_cents, status, currency, document_kind, issued_at")
      .eq("id", id)
      .eq("company_id", session.membership.company_id)
      .maybeSingle(),
    supabase
      .from("company_invoice_lines")
      .select("id, description, seats, credits, amount_cents, ride_id, cost_centers(code, name)")
      .eq("invoice_id", id)
      .order("description"),
  ]);

  if (!invoice) notFound();
  const money = (c: number) =>
    new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: invoice.currency?.toUpperCase() ?? "USD",
    }).format(c / 100);

  return (
    <>
      <TopBar title={invoice.number ?? "Company statement"}>
        <Link href="/portal/billing" className="text-xs font-semibold text-muted underline underline-offset-4">
          Back to billing
        </Link>
        <PrintButton />
      </TopBar>

      <div className="space-y-4 p-5 print:p-0 lg:p-7">
        <Panel title="Statement summary">
          <div className="grid gap-5 p-5 sm:grid-cols-2 lg:grid-cols-4 lg:p-6">
            <div>
              <p className="label text-muted">Company</p>
              <p className="mt-1 font-semibold">{session.membership.companies?.name ?? "Company"}</p>
            </div>
            <div>
              <p className="label text-muted">Period</p>
              <p className="nums mt-1">
                {new Date(invoice.period_start).toLocaleDateString()} –{" "}
                {new Date(invoice.period_end).toLocaleDateString()}
              </p>
            </div>
            <div>
              <p className="label text-muted">Status</p>
              <p className="mt-1"><Chip tone="ok">{invoice.status}</Chip></p>
            </div>
            <div>
              <p className="label text-muted">Reconciled value</p>
              <p className="nums mt-1 text-lg font-extrabold">{money(invoice.total_cents)}</p>
            </div>
          </div>
          <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">
            This is a prepaid usage statement. The listed seats were paid from the company float and are not
            an additional amount due.
          </p>
        </Panel>

        <Panel title="Seat lines">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-base">
              <thead>
                <tr>
                  <th scope="col" className={th}>Description</th>
                  <th scope="col" className={th}>Cost center</th>
                  <th scope="col" className={`${th} text-right`}>Seats</th>
                  <th scope="col" className={`${th} text-right`}>Credits</th>
                  <th scope="col" className={`${th} text-right`}>Value</th>
                </tr>
              </thead>
              <tbody>
                {(lines ?? []).map((line) => {
                  const costCenter = line.cost_centers as unknown as { code: string; name: string } | null;
                  return (
                    <tr key={line.id}>
                      <td className={td}>{line.description}</td>
                      <td className={`${td} nums text-muted`}>{costCenter?.code ?? "UNASSIGNED"}</td>
                      <td className={`${td} nums text-right`}>{line.seats}</td>
                      <td className={`${td} nums text-right`}>{line.credits}</td>
                      <td className={`${td} nums text-right font-semibold`}>{money(line.amount_cents)}</td>
                    </tr>
                  );
                })}
                {(lines ?? []).length === 0 ? (
                  <tr><td className={`${td} text-muted`} colSpan={5}>No seat lines in this period.</td></tr>
                ) : null}
              </tbody>
              <tfoot>
                <tr className="border-t border-linestrong">
                  <td className={`${td} font-semibold`} colSpan={3}>Total</td>
                  <td className={`${td} nums text-right font-semibold`}>{invoice.seat_credits}</td>
                  <td className={`${td} nums text-right font-extrabold`}>{money(invoice.total_cents)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </Panel>
      </div>
    </>
  );
}
