import type { Metadata } from "next";
import { PageHero } from "@/components/page-chrome";
import { Card, SectionHead } from "@/components/ui";
import { connectors } from "@/lib/data";

export const metadata: Metadata = {
  title: "Integrations — Rydlnk for Work",
  description:
    "Rydlnk pulls people and shifts from the HR and workforce systems you already run, and pushes spend back to finance as journals.",
};

const pipeline: [string, string, string][] = [
  ["Pull", "Read on a schedule", "A nightly full sync plus webhooks for hires, terminations and roster changes. Full sync catches drift; webhooks catch the things that can't wait until morning."],
  ["Resolve", "Match to a person", "Employee number first, work email second. Conflicts go to a review queue instead of quietly creating a duplicate person with a second wallet."],
  ["Apply", "Move entitlements", "A department change moves the cost center. A promotion changes the entitlement rule. A termination freezes the wallet and reclaims unspent credits."],
  ["Push", "Send spend back", "A journal per cost center per period, with seat-level detail attached, posted through the finance connector or exported as CSV."],
];

export default function IntegrationsPage() {
  const byRole = ["People", "Rosters", "Payroll", "Finance", "Field CRM", "Any system"];

  return (
    <>
      <PageHero
        eyebrow="Integrations"
        title="Nobody should type a staff list twice."
        lede="A new hire appears on Monday and rides on Tuesday. Someone leaves, and their credits stop the same hour. That only works if Rydlnk reads from the systems you already keep accurate."
      />

      <section className="py-16">
        <div className="wrap">
          <SectionHead
            eyebrow="Connectors"
            title="Three kinds of system, one canonical employee."
            lede="People come from HR. Shifts come from workforce management. Spend goes back to finance. Rydlnk keeps one employee record and treats every source as a feed into it."
          />
          <div className="space-y-8">
            {byRole.map((role) => {
              const items = connectors.filter((c) => c.role === role);
              if (!items.length) return null;
              return (
                <div key={role}>
                  <h3 className="mb-3 font-mono text-[0.68rem] uppercase tracking-[0.14em] text-muted">{role}</h3>
                  <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                    {items.map((c) => (
                      <div key={c.name} className="flex items-start gap-3 rounded-[10px] border border-line bg-white px-4 py-3.5">
                        <span
                          className="grid h-8 w-8 shrink-0 place-items-center rounded-[8px] font-mono text-[0.6rem] font-semibold text-white"
                          style={{ background: c.color }}
                        >
                          {c.code}
                        </span>
                        <span className="min-w-0">
                          <span className="block text-[0.9rem] font-medium">{c.name}</span>
                          <span className="mt-0.5 block text-[0.8rem] text-muted">{c.detail}</span>
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      <section className="border-y border-line bg-white py-16">
        <div className="wrap">
          <SectionHead eyebrow="How a sync runs" title="Pull, resolve, apply, push." />
          <div className="grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
            {pipeline.map(([k, h, p]) => (
              <Card key={k} className="bg-paper">
                <p className="font-mono text-[0.64rem] uppercase tracking-[0.13em] text-amberdim">{k}</p>
                <h3 className="mt-2 font-display text-[1rem] font-extrabold">{h}</h3>
                <p className="mt-2 text-[0.86rem] text-muted">{p}</p>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="wrap grid gap-10 lg:grid-cols-2">
          <div>
            <SectionHead eyebrow="If you have none of these" title="A file drop is a perfectly good integration." />
            <p className="text-[0.95rem] text-muted">
              Plenty of good employers run their roster in a spreadsheet. Drop a CSV on SFTP, or upload it in the portal,
              and Rydlnk maps the columns once and remembers. The only fields that genuinely matter are an employee
              identifier, a home address, a department and a shift time.
            </p>
            <p className="mt-4 text-[0.95rem] text-muted">
              The one thing worth getting right early is the home address, because an employee without a geocoded
              location can&apos;t be clustered and quietly disappears from every manifest. The portal surfaces those as
              a review queue rather than letting them fall through.
            </p>
          </div>
          <Card className="bg-ink text-white">
            <p className="font-mono text-[0.62rem] uppercase tracking-[0.13em] text-muteddark">Minimum viable columns</p>
            <div className="mt-4 overflow-x-auto">
              <table className="w-full min-w-[320px] font-mono text-[0.8rem]">
                <tbody>
                  {[
                    ["employee_no", "E-1041", "required"],
                    ["full_name", "Tendai Moyo", "required"],
                    ["department", "Production", "required"],
                    ["cost_centre", "CC-4100", "recommended"],
                    ["home_city", "Spanish Fork", "required"],
                    ["shift_start", "2026-07-27 22:00", "required"],
                    ["work_email", "t.moyo@…", "optional"],
                  ].map(([k, v, req]) => (
                    <tr key={k} className="border-b border-white/10 last:border-b-0">
                      <td className="py-2 pr-4 text-amber">{k}</td>
                      <td className="py-2 pr-4 text-muteddark">{v}</td>
                      <td className={`py-2 text-right text-[0.7rem] ${req === "required" ? "text-signalbright" : "text-muteddark"}`}>{req}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      </section>
    </>
  );
}
