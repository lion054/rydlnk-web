import { redirect } from "next/navigation";
import { Chip } from "@/components/ui";
import { EmptyState, Kpi, Panel, TopBar, td, th } from "@/components/portal/chrome";
import { getCompanySchedules, getShiftCandidates, getSession } from "@/lib/queries";
import { CancelShift, ShiftForm } from "./shift-form";

export const metadata = { title: "Employee schedules" };

const DAY = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function time(value: string | null) {
  if (!value) return "—";
  const [hour, minute] = value.split(":").map(Number);
  return new Date(2000, 0, 1, hour, minute).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

export default async function CompanySchedulesPage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");
  const companyId = session.membership.company_id;
  const [schedules, candidates] = await Promise.all([
    getCompanySchedules(companyId),
    getShiftCandidates(companyId),
  ]);

  const active = schedules.filter((s) => s.schedule_status === "active");
  const upcoming = schedules.reduce((total, s) => total + (s.upcoming_rides ?? 0), 0);
  const funded = schedules.reduce((total, s) => total + (s.funded_rides ?? 0), 0);
  const held = schedules.reduce((total, s) => total + (s.held_credits ?? 0), 0);

  return (
    <>
      <TopBar title="Employee schedules">
        <Chip tone="ok">{active.length} active</Chip>
      </TopBar>
      <div className="space-y-4 p-5 lg:p-7">
        <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
          <Kpi label="Active schedules" value={active.length.toLocaleString()} />
          <Kpi label="Upcoming rides" value={upcoming.toLocaleString()} sub="generated from schedules" />
          <Kpi label="Funded rides" value={funded.toLocaleString()} sub="held, settled or no-show" />
          <Kpi label="Credits held" value={`${held.toLocaleString()} cr`} sub="reserved for upcoming seats" />
        </div>

        <Panel title="Schedule a shift">
          <div className="p-5">
            <ShiftForm companyId={companyId} candidates={candidates} />
          </div>
        </Panel>

        <Panel title="Schedule patterns">
          {schedules.length === 0 ? (
            <EmptyState
              title="No employee schedules yet."
              body="Schedule one above, or wait for an employee to create their own in the rider app — both appear here."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[920px] text-base">
                <caption className="sr-only">Employee commute schedule patterns</caption>
                <thead>
                  <tr>
                    <th scope="col" className={th}>Employee</th>
                    <th scope="col" className={th}>Destination</th>
                    <th scope="col" className={th}>Days</th>
                    <th scope="col" className={th}>Window</th>
                    <th scope="col" className={`${th} text-right`}>Upcoming</th>
                    <th scope="col" className={`${th} text-right`}>Funded</th>
                    <th scope="col" className={th}>Status</th>
                    <th scope="col" className={th}><span className="sr-only">Actions</span></th>
                  </tr>
                </thead>
                <tbody>
                  {schedules.map((s) => (
                    <tr key={s.schedule_id} className="hover:bg-[#fafbfa]">
                      <td className={td}>
                        <span className="font-semibold">{s.rider_name || s.employee_no || s.rider_id.slice(0, 8)}</span>
                        <span className="mt-0.5 block text-xs text-muted">{s.department ?? "No department"}</span>
                      </td>
                      <td className={td}>
                        {s.title || s.destination}
                        {s.return_ride ? <span className="ml-1 text-xs text-muted">· return</span> : null}
                      </td>
                      <td className={`${td} text-xs`}>
                        {(s.days ?? []).map((d: number) => DAY[d]).join(", ") || "One-time"}
                      </td>
                      <td className={`${td} nums text-muted`}>
                        {s.pickup_after ? `After ${time(s.pickup_after)}` : `Arrive by ${time(s.arrive_by)}`}
                      </td>
                      <td className={`${td} nums text-right`}>{s.upcoming_rides}</td>
                      <td className={`${td} nums text-right`}>{s.funded_rides}</td>
                      <td className={td}>
                        <Chip tone={s.schedule_status === "active" ? "ok" : "neutral"}>{s.schedule_status}</Chip>
                      </td>
                      <td className={td}>
                        {s.schedule_status === "active" ? (
                          <CancelShift companyId={companyId} scheduleId={s.schedule_id} />
                        ) : null}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">
            Employers see destination and time patterns for planning. Exact pickup addresses are deliberately not returned.
          </p>
        </Panel>
      </div>
    </>
  );
}
