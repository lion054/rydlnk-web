import { redirect } from "next/navigation";
import { Panel, TopBar, td, th } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import * as Icon from "@/components/icons";
import { getSession } from "@/lib/queries";
import { createClient } from "@/lib/supabase/server";
import { connectors } from "@/lib/data";

export const metadata = { title: "Integrations" };

export default async function IntegrationsPage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const companyId = session.membership.company_id;
  const supabase = await createClient();

  /* The audit log is the real sync history — every privileged action writes to
     it, so this shows what actually happened rather than a scripted demo. */
  const [{ data: audit }, { data: domains }, { data: stripe }] = await Promise.all([
    supabase
      .from("company_audit_log")
      .select("id, action, target, detail, created_at")
      .eq("company_id", companyId)
      .order("created_at", { ascending: false })
      .limit(25),
    supabase
      .from("company_domains")
      .select("id, domain, verification_token, verified_at")
      .eq("company_id", companyId),
    supabase
      .from("company_stripe_customers")
      .select("stripe_customer_id, ach_enabled")
      .eq("company_id", companyId)
      .maybeSingle(),
  ]);

  const live = [
    {
      name: "Stripe",
      role: "Payments",
      state: stripe?.stripe_customer_id ? "connected" : "available",
      detail: stripe?.stripe_customer_id
        ? `Funding the float${stripe.ach_enabled ? " · ACH enabled" : " · card only"}`
        : "Fund the credit float by card or ACH",
    },
    {
      name: "HRIS termination webhook",
      role: "Offboarding",
      state: "available",
      detail: "Freezes the wallet and reclaims credits the moment someone leaves",
    },
    ...connectors.map((c) => ({
      name: c.name,
      role: c.role,
      state: "available" as const,
      detail: c.detail,
    })),
  ];

  return (
    <>
      <TopBar title="Integrations">
        <Chip tone={stripe?.stripe_customer_id ? "ok" : "warn"}>
          {stripe?.stripe_customer_id ? "Stripe connected" : "Stripe not connected"}
        </Chip>
      </TopBar>

      <div className="space-y-4 p-5 lg:p-7">
        <Panel title="Connectors">
          <div className="grid gap-px bg-line sm:grid-cols-2 xl:grid-cols-3">
            {live.map((c) => (
              <article key={c.name} className="bg-white p-5">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <h3 className="text-base font-semibold">{c.name}</h3>
                    <p className="eyebrow mt-0.5 text-muted">{c.role}</p>
                  </div>
                  <Chip tone={c.state === "connected" ? "ok" : "neutral"}>{c.state}</Chip>
                </div>
                <p className="mt-2.5 text-xs text-muted">{c.detail}</p>
              </article>
            ))}
          </div>
          <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">
            Roster connectors are on the roadmap — until one is live, import a CSV from the People page. The
            minimum columns are email, employee number, home address and shift start.
          </p>
        </Panel>

        <Panel title="Email domains">
          {(domains ?? []).length === 0 ? (
            <div className="p-5 text-base text-muted lg:p-6">
              <p>
                No domains claimed. Adding one lets staff with that email address join without an individual
                invite — but only after you&apos;ve proven you control it.
              </p>
            </div>
          ) : (
            <table className="w-full text-base">
              <thead>
                <tr>
                  <th scope="col" className={th}>Domain</th>
                  <th scope="col" className={th}>Status</th>
                  <th scope="col" className={th}>DNS TXT record</th>
                </tr>
              </thead>
              <tbody>
                {(domains ?? []).map((d) => (
                  <tr key={d.id}>
                    <td className={`${td} font-medium`}>{d.domain}</td>
                    <td className={td}>
                      {d.verified_at ? (
                        <Chip tone="ok">verified</Chip>
                      ) : (
                        <Chip tone="warn">unverified — grants nothing yet</Chip>
                      )}
                    </td>
                    <td className={`${td} font-mono text-xs text-muted`}>
                      rydlnk-verify={d.verification_token}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Panel>

        <Panel title="Activity">
          {(audit ?? []).length === 0 ? (
            <div className="p-5 text-base text-muted lg:p-6">
              Nothing yet. Every privileged action — company created, credits allocated, invites sent, members
              removed — is written here and cannot be edited.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[600px] text-base">
                <caption className="sr-only">Audit log</caption>
                <thead>
                  <tr>
                    <th scope="col" className={th}>When</th>
                    <th scope="col" className={th}>Action</th>
                    <th scope="col" className={th}>Target</th>
                    <th scope="col" className={th}>Detail</th>
                  </tr>
                </thead>
                <tbody>
                  {(audit ?? []).map((a) => (
                    <tr key={a.id} className="hover:bg-[#fafbfa]">
                      <td className={`${td} nums whitespace-nowrap text-muted`}>
                        {new Date(a.created_at).toLocaleString("en-US", {
                          month: "short",
                          day: "numeric",
                          hour: "numeric",
                          minute: "2-digit",
                        })}
                      </td>
                      <td className={td}>
                        <span className="inline-flex items-center gap-1.5 font-medium">
                          <Icon.Check size={14} className="text-signal" />
                          {a.action}
                        </span>
                      </td>
                      <td className={`${td} truncate text-xs text-muted`}>{a.target ?? "—"}</td>
                      <td className={`${td} font-mono text-xs text-muted`}>
                        {a.detail ? JSON.stringify(a.detail).slice(0, 80) : "—"}
                      </td>
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
