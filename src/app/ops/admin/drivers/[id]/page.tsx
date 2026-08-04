import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Chip } from "@/components/ui";
import { Panel, TopBar, td, th } from "@/components/portal/chrome";
import { createClient } from "@/lib/supabase/server";
import { DocumentControls } from "./document-controls";

export const metadata = { title: "Driver documents" };
export const dynamic = "force-dynamic";

export default async function DriverDocumentsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: allowed } = await supabase.rpc("is_platform_admin");
  if (!allowed) redirect("/ops/dispatch");
  const [{ data: documents }, { data: drivers }] = await Promise.all([
    supabase.rpc("admin_driver_documents", { p_driver: id }),
    supabase.rpc("admin_drivers"),
  ]);
  const driver = (drivers ?? []).find((d: any) => d.driver_id === id);
  if (!driver) notFound();

  const rows = await Promise.all((documents ?? []).map(async (document: any) => {
    const { data } = await supabase.storage.from("driver-docs").createSignedUrl(document.storage_path, 300);
    return { ...document, signedUrl: data?.signedUrl ?? null };
  }));

  return (
    <main className="min-h-screen bg-paper">
      <TopBar title={driver.full_name ?? driver.email}>
        <Link href="/ops/admin" className="text-xs font-semibold text-muted underline underline-offset-4">Back to super admin</Link>
        <Chip tone={driver.verified ? "ok" : "warn"}>{driver.verification_status}</Chip>
      </TopBar>
      <div className="p-5 lg:p-7">
        <Panel title="Private verification documents">
          <div className="overflow-x-auto"><table className="w-full min-w-[900px] text-base">
            <thead><tr><th className={th}>Type</th><th className={th}>Expiry</th><th className={th}>State</th><th className={th}>Review note</th><th className={th}>File</th><th className={th}>Decision</th></tr></thead>
            <tbody>{rows.map((d: any) => <tr key={d.document_id}>
              <td className={td}>{String(d.doc_type).replaceAll("_", " ")}</td>
              <td className={`${td} nums`}>{d.expiry_date ?? "—"}</td>
              <td className={td}><Chip tone={d.status === "approved" ? "ok" : d.status === "rejected" ? "bad" : "warn"}>{d.status}</Chip></td>
              <td className={td}>{d.note ?? "—"}</td>
              <td className={td}>{d.signedUrl ? <a className="font-semibold text-signal underline" href={d.signedUrl} target="_blank" rel="noopener noreferrer">Open for 5 minutes</a> : <span className="text-flag">Unavailable</span>}</td>
              <td className={td}><DocumentControls documentId={d.document_id} /></td>
            </tr>)}
            {rows.length === 0 ? <tr><td className={`${td} text-muted`} colSpan={6}>No documents uploaded.</td></tr> : null}</tbody>
          </table></div>
          <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">Documents remain private. Review links expire after five minutes and must not be downloaded to unmanaged devices.</p>
        </Panel>
      </div>
    </main>
  );
}
