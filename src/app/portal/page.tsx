import Link from "next/link";
import { redirect } from "next/navigation";
import { EmptyState, Kpi, Panel, TopBar, td, th } from "@/components/portal/chrome";
import { Button, Chip } from "@/components/ui";
import * as Icon from "@/components/icons";
import {
  getBenefitUsage,
  getFloat,
  getFundedSeats,
  getMembers,
  getPendingApprovals,
  getSession,
  getSpendByCostCenter,
} from "@/lib/queries";
import { CREDIT_VALUE, TRANSIT_BENEFIT_CAP } from "@/lib/data";

export const metadata = { title: "Overview" };

export default async function PortalOverview() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const companyId = session.membership.company_id;
  const [float, members, approvals, seats, spend, benefit] = await Promise.all([
    getFloat(companyId),
    getMembers(companyId),
    getPendingApprovals(companyId),
    getFundedSeats(companyId, 200),
    getSpendByCostCenter(companyId),
    getBenefitUsage(companyId),
  ]);

  /* Everything below is derived from the rows above — no figure is written into
     the markup, so a stat can never disagree with the table beneath it. */
  const settled = seats.filter((s) => s.status === "settled");
  const creditsSpent = settled.reduce((a, s) => a + (s.company_credits ?? 0), 0);
  const pretax = benefit.reduce((a, b) => a + (b.pretax_credits ?? 0), 0);
  const perTrip = settled.length ? creditsSpent / settled.length : 0;
  const totalSpend = spend.reduce((a, c) => a + (c.credits ?? 0), 0);

  /* FICA saved on the pre-tax portion — the reason finance signs this off. */
  const ficaSaved = pretax * CREDIT_VALUE * 0.0765;

  const isNew = members.length <= 1 && seats.length === 0;

  return (
    <>
      <TopBar title="Overview">
        <Chip tone="ok">
          {session.membership.companies?.name ?? "Your company"} · {members.length}{" "}
          {members.length === 1 ? "person" : "people"}
        </Chip>
      </TopBar>

      <div className="space-y-4 p-5 lg:p-7">
        {isNew ? (
          <Panel title="Get set up">
            <div className="grid gap-3 p-5 sm:grid-cols-3 lg:p-6">
              {[
                { href: "/portal/billing", title: "Fund the float", body: "Add credits so allocations have something to draw on.", icon: Icon.Wallet },
                { href: "/portal/people", title: "Invite your team", body: "Send a link. They join and pick up their seat the same day.", icon: Icon.Users },
                { href: "/portal/corridors", title: "Set your corridors", body: "Where runs start and end, and what a seat costs.", icon: Icon.Route },
              ].map(({ href, title, body, icon: Glyph }) => (
                <Link
                  key={href}
                  href={href}
                  className="group rounded-card border border-line p-5 transition-colors hover:border-signal hover:bg-shell"
                >
                  <span className="grid h-10 w-10 place-items-center rounded-sm bg-signal/10 text-signal">
                    <Glyph size={19} />
                  </span>
                  <p className="mt-3 flex items-center justify-between text-base font-semibold">
                    {title}
                    <Icon.ArrowRight size={16} className="text-signal transition-transform group-hover:translate-x-1" />
                  </p>
                  <p className="mt-1.5 text-xs text-muted">{body}</p>
                </Link>
              ))}
            </div>
          </Panel>
        ) : null}

        <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
          <Kpi label="Float" value={`${float.toLocaleString()} cr`} sub={`≈ ${Math.floor(float / 5)} seats`} tone={float < 500 ? "down" : "up"} />
          <Kpi label="Seats this period" value={settled.length.toLocaleString()} sub={`${creditsSpent.toLocaleString()} cr spent`} />
          <Kpi label="Cost per employee trip" value={perTrip ? `$${perTrip.toFixed(2)}` : "—"} sub={settled.length ? "settled seats" : "no seats yet"} />
          <Kpi
            label="Pre-tax this month"
            value={`${pretax.toLocaleString()} cr`}
            sub={pretax ? `≈ $${ficaSaved.toFixed(0)} FICA saved` : `cap $${TRANSIT_BENEFIT_CAP}/person`}
            tone={pretax ? "up" : undefined}
          />
        </div>

        <Panel
          title="Needs your attention"
          actions={
            approvals.length > 0 ? (
              <span className="ml-auto">
                <Button href="/portal/approvals" size="sm" variant="ghost">
                  Open queue
                </Button>
              </span>
            ) : null
          }
        >
          {approvals.length === 0 ? (
            <EmptyState
              title="Nothing waiting."
              body="Trips inside policy confirm on their own. Only exceptions land here."
            />
          ) : (
            <table className="w-full text-base">
              <tbody>
                {approvals.slice(0, 5).map((a) => (
                  <tr key={a.id} className="hover:bg-[#fafbfa]">
                    <td className={`${td} w-px whitespace-nowrap`}>
                      <Chip tone="warn">{a.reason.replace(/_/g, " ")}</Chip>
                    </td>
                    <td className={td}>{a.detail ?? "Over policy — needs a decision."}</td>
                    <td className={`${td} nums text-right`}>{a.company_credits} cr</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Panel>

        <Panel title="Spend by cost center · this period">
          {spend.length === 0 ? (
            <EmptyState
              title="No settled seats yet."
              body="Once your staff start riding, spend appears here split by the cost center each seat belongs to."
            />
          ) : (
            <table className="w-full text-base">
              <caption className="sr-only">Company spend grouped by cost center</caption>
              <thead>
                <tr>
                  <th scope="col" className={th}>Cost center</th>
                  <th scope="col" className={`${th} text-right`}>Seats</th>
                  <th scope="col" className={th}>Share</th>
                  <th scope="col" className={`${th} text-right`}>Credits</th>
                </tr>
              </thead>
              <tbody>
                {spend.map((c) => (
                  <tr key={c.code} className="hover:bg-[#fafbfa]">
                    <td className={td}>
                      {c.name}
                      <span className="nums ml-2 text-xs text-muted">{c.code}</span>
                    </td>
                    <td className={`${td} nums text-right`}>{c.seats}</td>
                    <td className={`${td} w-[160px]`}>
                      <span className="block h-1.5 w-full overflow-hidden rounded-full bg-line">
                        <span
                          className="block h-full rounded-full bg-signal"
                          style={{ width: `${totalSpend ? Math.round((c.credits / totalSpend) * 100) : 0}%` }}
                        />
                      </span>
                    </td>
                    <td className={`${td} nums text-right font-semibold`}>{c.credits.toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Panel>
      </div>
    </>
  );
}
