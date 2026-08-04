import Link from "next/link";
import { redirect } from "next/navigation";
import { Chip } from "@/components/ui";
import { Panel, TopBar, td, th } from "@/components/portal/chrome";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "Production health" };
export const dynamic = "force-dynamic";

export default async function OperatorHealthPage() {
  const supabase = await createClient();
  const { data: health, error } = await supabase.rpc("operator_health");
  if (error) redirect("/portal");

  const checks = Object.entries((health?.checks ?? {}) as Record<string, number>);
  const status = String(health?.status ?? "critical");
  return (
    <main className="min-h-screen bg-paper">
      <TopBar title="Production health">
        <Link href="/ops/dispatch" className="text-xs font-semibold text-muted underline underline-offset-4">Dispatch</Link>
        <Chip tone={status === "healthy" ? "ok" : status === "warning" ? "warn" : "bad"}>{status}</Chip>
      </TopBar>
      <div className="space-y-4 p-5 lg:p-7">
        <Panel title="Financial integrity checks">
          <table className="w-full text-base">
            <thead><tr><th className={th}>Check</th><th className={`${th} text-right`}>Issues</th><th className={th}>State</th></tr></thead>
            <tbody>
              {checks.map(([name, count]) => (
                <tr key={name}>
                  <td className={td}>{name.replaceAll("_", " ")}</td>
                  <td className={`${td} nums text-right`}>{count}</td>
                  <td className={td}><Chip tone={count === 0 ? "ok" : "bad"}>{count === 0 ? "clear" : "investigate"}</Chip></td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">
            Checked {health?.checked_at ? new Date(health.checked_at).toLocaleString() : "just now"}. Critical checks return HTTP 503 from the private health endpoint.
          </p>
        </Panel>
      </div>
    </main>
  );
}
