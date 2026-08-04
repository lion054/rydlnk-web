import Link from "next/link";
import { redirect } from "next/navigation";
import { Chip } from "@/components/ui";
import { Kpi, Panel, TopBar, td, th } from "@/components/portal/chrome";
import { createClient } from "@/lib/supabase/server";
import { ReasonedAction, RefundTopup, StaffManager, StaffToggle, UserStatusToggle } from "./admin-controls";

export const metadata = { title: "Super admin" };
export const dynamic = "force-dynamic";

export default async function SuperAdminPage() {
  const supabase = await createClient();
  const { data: allowed } = await supabase.rpc("is_platform_admin");
  if (!allowed) redirect("/ops/dispatch");

  const [
    { data: dashboard }, { data: companies }, { data: users }, { data: drivers },
    { data: payments }, { data: staff }, { data: audit },
  ] = await Promise.all([
    supabase.rpc("admin_dashboard"),
    supabase.rpc("admin_companies"),
    supabase.rpc("admin_users", { p_search: null }),
    supabase.rpc("admin_drivers"),
    supabase.rpc("admin_payments"),
    supabase.rpc("admin_platform_staff"),
    supabase.rpc("admin_platform_audit"),
  ]);
  const d = dashboard ?? {};

  return (
    <main className="min-h-screen bg-paper">
      <TopBar title="Super admin">
        <Link href="/ops/dispatch" className="text-xs font-semibold text-muted underline underline-offset-4">Dispatch</Link>
        <Link href="/ops/health" className="text-xs font-semibold text-muted underline underline-offset-4">Health</Link>
        <Chip tone="bad">operations admin</Chip>
      </TopBar>
      <div className="space-y-4 p-5 lg:p-7">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <Kpi label="Companies" value={String(d.companies ?? 0)} sub={`${d.suspended_companies ?? 0} suspended`} />
          <Kpi label="Active members" value={String(d.active_members ?? 0)} />
          <Kpi label="Drivers" value={String(d.drivers ?? 0)} sub={`${d.pending_drivers ?? 0} pending review`} />
          <Kpi label="Payment attention" value={String((d.pending_topups ?? 0) + (d.failed_webhooks ?? 0))} sub="pending top-ups + failed webhooks" />
        </div>

        <Panel title="Companies">
          <div className="overflow-x-auto"><table className="w-full min-w-[900px] text-base">
            <thead><tr><th className={th}>Company</th><th className={th}>Country</th><th className={`${th} text-right`}>Members</th><th className={`${th} text-right`}>Float</th><th className={`${th} text-right`}>Seats</th><th className={th}>State</th><th className={th}>Control</th></tr></thead>
            <tbody>{(companies ?? []).map((c: any) => <tr key={c.company_id}>
              <td className={td}><span className="font-semibold">{c.company_name}</span><span className="block text-xs text-muted">{c.billing_email}</span></td>
              <td className={td}>{c.country}</td><td className={`${td} nums text-right`}>{c.members}</td><td className={`${td} nums text-right`}>{c.float_credits} cr</td><td className={`${td} nums text-right`}>{c.settled_seats}</td>
              <td className={td}><Chip tone={c.suspended_at ? "bad" : "ok"}>{c.suspended_at ? "suspended" : "active"}</Chip></td>
              <td className={td}><ReasonedAction kind="company" targetId={c.company_id} active={!c.suspended_at} /></td>
            </tr>)}</tbody>
          </table></div>
        </Panel>

        <Panel title="Driver verification">
          <div className="overflow-x-auto"><table className="w-full min-w-[900px] text-base">
            <thead><tr><th className={th}>Driver</th><th className={th}>Documents</th><th className={th}>Insurance</th><th className={th}>Status</th><th className={th}>Review</th></tr></thead>
            <tbody>{(drivers ?? []).map((x: any) => <tr key={x.driver_id}>
              <td className={td}><span className="font-semibold">{x.full_name ?? x.email}</span><span className="block text-xs text-muted">{x.email}</span></td>
              <td className={`${td} nums`}>{x.document_count} · {x.pending_documents} pending · {x.rejected_documents} rejected</td>
              <td className={`${td} nums`}>{x.insurance_expiry ?? "—"}</td><td className={td}><Chip tone={x.verified ? "ok" : "warn"}>{x.verification_status}</Chip></td>
              <td className={td}><Link className="mr-2 text-xs font-semibold text-signal underline" href={`/ops/admin/drivers/${x.driver_id}`}>Documents</Link><ReasonedAction kind="driver" targetId={x.driver_id} active={x.verified} /></td>
            </tr>)}</tbody>
          </table></div>
        </Panel>

        <Panel title="Recent company funding">
          <div className="overflow-x-auto"><table className="w-full min-w-[800px] text-base">
            <thead><tr><th className={th}>Company</th><th className={`${th} text-right`}>Credits</th><th className={`${th} text-right`}>Amount</th><th className={th}>Status</th><th className={th}>Stripe reference</th><th className={th}>Created</th><th className={th}>Control</th></tr></thead>
            <tbody>{(payments ?? []).map((p: any) => <tr key={p.topup_id}><td className={td}>{p.company_name}</td><td className={`${td} nums text-right`}>{p.credits}</td><td className={`${td} nums text-right`}>${(p.amount_cents / 100).toFixed(2)}</td><td className={td}><Chip tone={p.status === "succeeded" ? "ok" : p.status === "failed" ? "bad" : "warn"}>{p.status}</Chip></td><td className={`${td} font-mono text-xs`}>{p.stripe_payment_intent_id ?? "manual"}</td><td className={`${td} nums`}>{new Date(p.created_at).toLocaleString()}</td><td className={td}>{p.status === "succeeded" && p.stripe_payment_intent_id ? <RefundTopup topupId={p.topup_id} /> : "—"}</td></tr>)}</tbody>
          </table></div>
        </Panel>

        <Panel title="Platform staff"><StaffManager />
          <div className="overflow-x-auto border-t border-line"><table className="w-full text-base"><thead><tr><th className={th}>User</th><th className={th}>Role</th><th className={th}>State</th><th className={th}>Control</th></tr></thead><tbody>{(staff ?? []).map((s: any) => <tr key={s.user_id}><td className={td}>{s.full_name ?? s.email}<span className="block text-xs text-muted">{s.email}</span></td><td className={td}>{s.role}</td><td className={td}><Chip tone={s.active ? "ok" : "neutral"}>{s.active ? "active" : "inactive"}</Chip></td><td className={td}><StaffToggle userId={s.user_id} role={s.role} active={s.active} /></td></tr>)}</tbody></table></div>
        </Panel>

        <Panel title={`Users · ${(users ?? []).length}`}><div className="overflow-x-auto"><table className="w-full min-w-[800px] text-base"><thead><tr><th className={th}>User</th><th className={th}>Company</th><th className={th}>Role</th><th className={th}>Membership</th><th className={th}>Account</th><th className={th}>Control</th></tr></thead><tbody>{(users ?? []).map((u: any, i: number) => { const disabled = Boolean(u.banned_until && new Date(u.banned_until) > new Date()); return <tr key={`${u.user_id}-${i}`}><td className={td}>{u.full_name ?? u.email}<span className="block text-xs text-muted">{u.email}</span></td><td className={td}>{u.company_name ?? "—"}</td><td className={td}>{u.company_role ?? "—"}</td><td className={td}>{u.member_status ?? "no company"}</td><td className={td}><Chip tone={disabled ? "bad" : "ok"}>{disabled ? "disabled" : "active"}</Chip></td><td className={td}><UserStatusToggle userId={u.user_id} disabled={disabled} /></td></tr>; })}</tbody></table></div></Panel>

        <Panel title="Immutable platform audit"><div className="overflow-x-auto"><table className="w-full min-w-[900px] text-base"><thead><tr><th className={th}>When</th><th className={th}>Actor</th><th className={th}>Action</th><th className={th}>Target</th><th className={th}>Reason</th></tr></thead><tbody>{(audit ?? []).map((a: any) => <tr key={a.id}><td className={`${td} nums`}>{new Date(a.created_at).toLocaleString()}</td><td className={td}>{a.actor_email}</td><td className={td}>{a.action}</td><td className={`${td} font-mono text-xs`}>{a.target_type}:{a.target_id.slice(0, 8)}</td><td className={td}>{a.reason}</td></tr>)}</tbody></table></div></Panel>
      </div>
    </main>
  );
}
