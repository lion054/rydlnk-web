import { redirect } from "next/navigation";
import { EmptyState, Kpi, Panel, TopBar, td, th } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import { getFundedSeats, getSession } from "@/lib/queries";

export const metadata = { title: "Trips & seats" };

const STATUS: Record<string, { label: string; tone: "ok" | "warn" | "bad" | "neutral" }> = {
  held: { label: "Held", tone: "warn" },
  settled: { label: "Settled", tone: "ok" },
  refunded: { label: "Refunded", tone: "neutral" },
  no_show: { label: "No-show · charged", tone: "bad" },
  cancelled: { label: "Cancelled", tone: "neutral" },
};

const SOURCE: Record<string, { label: string; tone: "ok" | "warn" | "neutral" }> = {
  company: { label: "Company", tone: "ok" },
  split: { label: "Split", tone: "warn" },
  personal: { label: "Personal", tone: "neutral" },
};

/**
 * Seats this company funded.
 *
 * Scoped by RLS to `seat_funding.company_id` — a pooled trip carrying three
 * employers returns only your rows here. The occupancy of the rest of the
 * vehicle is available through `trip_occupancy()`, which returns a count and
 * nothing else.
 */
export default async function TripsPage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const seats = await getFundedSeats(session.membership.company_id, 100);

  const held = seats.filter((s) => s.status === "held").length;
  const settled = seats.filter((s) => s.status === "settled");
  const credits = settled.reduce((a, s) => a + (s.company_credits ?? 0), 0);
  const personal = seats.reduce((a, s) => a + (s.personal_cents ?? 0), 0);
  const trips = new Set(seats.map((s) => s.trip_id).filter(Boolean)).size;

  return (
    <>
      <TopBar title="Trips & seats">
        {held > 0 ? <Chip tone="warn">{held} held</Chip> : <Chip tone="ok">Nothing pending</Chip>}
      </TopBar>

      <div className="space-y-4 p-5 lg:p-7">
        <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
          <Kpi label="Seats funded" value={seats.length.toLocaleString()} />
          <Kpi label="Distinct trips" value={trips.toLocaleString()} sub="vehicles your staff rode" />
          <Kpi label="Credits consumed" value={credits.toLocaleString()} sub={`${settled.length} settled`} />
          <Kpi
            label="Employee share"
            value={`$${(personal / 100).toFixed(2)}`}
            sub={personal ? "over-policy split" : "nothing over policy"}
          />
        </div>

        <Panel title="Seats">
          {seats.length === 0 ? (
            <EmptyState
              title="No seats yet."
              body="Once your staff have schedules, each ride they take creates a funded seat here — with who paid, how much, and whether it settled."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[820px] text-base">
                <caption className="sr-only">Seats funded by this company</caption>
                <thead>
                  <tr>
                    <th scope="col" className={th}>Seat</th>
                    <th scope="col" className={th}>When</th>
                    <th scope="col" className={th}>Funding</th>
                    <th scope="col" className={`${th} text-right`}>Company</th>
                    <th scope="col" className={`${th} text-right`}>Employee</th>
                    <th scope="col" className={`${th} text-right`}>Pre-tax</th>
                    <th scope="col" className={th}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {seats.map((s) => {
                    const st = STATUS[s.status] ?? { label: s.status, tone: "neutral" as const };
                    const src = SOURCE[s.source] ?? { label: s.source, tone: "neutral" as const };
                    return (
                      <tr key={s.ride_id} className="hover:bg-[#fafbfa]">
                        <td className={`${td} nums text-xs`}>{s.ride_id.slice(0, 8)}</td>
                        <td className={`${td} nums text-muted`}>
                          {new Date(s.created_at).toLocaleDateString("en-US", {
                            month: "short",
                            day: "numeric",
                          })}
                        </td>
                        <td className={td}>
                          <Chip tone={src.tone}>{src.label}</Chip>
                        </td>
                        <td className={`${td} nums text-right`}>{s.company_credits} cr</td>
                        <td className={`${td} nums text-right`}>
                          {s.personal_cents ? `$${(s.personal_cents / 100).toFixed(2)}` : "—"}
                        </td>
                        <td className={`${td} nums text-right text-signal`}>
                          {s.pretax_credits ? `${s.pretax_credits} cr` : "—"}
                        </td>
                        <td className={td}>
                          <Chip tone={st.tone}>{st.label}</Chip>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
          <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">
            Only seats your company funded. On a pooled run carrying several employers, the others&apos; seats are
            an occupancy count and nothing more — enforced in the row policy, not in this page.
          </p>
        </Panel>
      </div>
    </>
  );
}
