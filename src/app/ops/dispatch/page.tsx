import { redirect } from "next/navigation";
import { TopBar } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { DispatchClient } from "./dispatch-client";

export const metadata = { title: "Platform dispatch" };
export const dynamic = "force-dynamic";

export default async function DispatchPage() {
  const supabase = await createClient();
  const { data: role } = await supabase.rpc("platform_operator_role");
  if (!role) redirect("/portal");
  const today = new Date();
  const end = new Date(today); end.setDate(end.getDate() + 7);
  const [{ data: trips }, { data: drivers }, { data: vehicles }] = await Promise.all([
    supabase.rpc("dispatch_board", { p_from: today.toISOString().slice(0, 10), p_to: end.toISOString().slice(0, 10) }),
    supabase.rpc("dispatch_drivers"),
    supabase.rpc("dispatch_vehicles"),
  ]);
  return (
    <main className="min-h-screen bg-paper">
      <TopBar title="Platform dispatch">
        {role === "operations_admin" ? <Link href="/ops/admin" className="text-xs font-semibold text-muted underline underline-offset-4">Super admin</Link> : null}
        <Link href="/ops/health" className="text-xs font-semibold text-muted underline underline-offset-4">Production health</Link>
        <Chip tone="ok">{role.replace("_", " ")}</Chip>
      </TopBar>
      <DispatchClient
        trips={(trips ?? []) as never[]}
        drivers={(drivers ?? []) as never[]}
        vehicles={(vehicles ?? []) as never[]}
        canManageFleet={role === "operations_admin"}
      />
    </main>
  );
}
