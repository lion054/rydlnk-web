"use client";

import { useMemo, useState, useTransition } from "react";
import { EmptyState, Panel, td, th } from "@/components/portal/chrome";
import { Button, Chip } from "@/components/ui";
import * as Icon from "@/components/icons";
import { allocateCredits, inviteMember, removeMember } from "../actions";

export type MemberRow = {
  id: string;
  user_id: string;
  role: string;
  status: string;
  department: string | null;
  employee_no: string | null;
  job_title: string | null;
  cost_centers: { code: string; name: string } | null;
};

export type InviteRow = {
  id: string;
  email: string;
  role: string;
  department: string | null;
  status: string;
  expires_at: string;
};

export function PeopleClient({
  companyId,
  members,
  invites,
  balances,
  float,
  canAdminister,
  canSpend,
}: {
  companyId: string;
  members: MemberRow[];
  invites: InviteRow[];
  balances: Record<string, number>;
  float: number;
  canAdminister: boolean;
  canSpend: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  const [inviteLink, setInviteLink] = useState<string | null>(null);

  const [q, setQ] = useState("");
  const [dept, setDept] = useState("All");

  // Allocate panel
  const [allocOpen, setAllocOpen] = useState(false);
  const [amount, setAmount] = useState(60);

  // Invite panel
  const [inviteOpen, setInviteOpen] = useState(false);
  const [email, setEmail] = useState("");
  const [inviteRole, setInviteRole] = useState("viewer");
  const [inviteDept, setInviteDept] = useState("");

  const departments = useMemo(
    () => ["All", ...Array.from(new Set(members.map((m) => m.department).filter(Boolean) as string[]))],
    [members],
  );

  const rows = useMemo(
    () =>
      members.filter(
        (m) =>
          (dept === "All" || m.department === dept) &&
          (q === "" ||
            `${m.employee_no ?? ""} ${m.department ?? ""} ${m.job_title ?? ""} ${m.role}`
              .toLowerCase()
              .includes(q.toLowerCase())),
      ),
    [members, q, dept],
  );

  const target = dept === "All" ? members.length : members.filter((m) => m.department === dept).length;
  const total = target * amount;
  const short = total - float;

  function doAllocate() {
    startTransition(async () => {
      const res = await allocateCredits(companyId, dept === "All" ? null : dept, amount);
      setNotice(res.ok ? res.message : res.error);
      if (res.ok) setAllocOpen(false);
    });
  }

  function doInvite() {
    startTransition(async () => {
      const res = await inviteMember(companyId, email.trim(), inviteRole, inviteDept.trim() || null);
      setNotice(res.ok ? res.message : res.error);
      if (res.ok && res.link) {
        setInviteLink(res.link);
        setEmail("");
      }
    });
  }

  function doRemove(userId: string) {
    startTransition(async () => {
      const res = await removeMember(companyId, userId);
      setNotice(res.ok ? res.message : res.error);
    });
  }

  return (
    <div className="space-y-4 p-5 lg:p-7">
      {notice ? (
        <p role="status" className="flex items-center gap-2.5 rounded-card border border-line bg-white px-4 py-3 text-base">
          <Icon.Check size={17} className="text-signal" />
          {notice}
        </p>
      ) : null}

      {inviteLink ? (
        <div className="rounded-card border border-signal/40 bg-signal/5 p-4">
          <p className="text-base font-semibold">Invite link — copy it now.</p>
          <p className="mt-1 text-xs text-muted">
            Only the hash is stored, so this link can&apos;t be shown again.
          </p>
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <code className="min-w-0 flex-1 truncate rounded-sm border border-line bg-white px-3 py-2 font-mono text-xs">
              {inviteLink}
            </code>
            <Button size="sm" variant="ghost" onClick={() => navigator.clipboard?.writeText(inviteLink)}>
              Copy
            </Button>
            <Button size="sm" variant="ghost" onClick={() => setInviteLink(null)}>
              Done
            </Button>
          </div>
        </div>
      ) : null}

      <Panel
        title="Directory"
        actions={
          <>
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search department, role…"
              aria-label="Search people"
              className="w-full max-w-[240px] rounded-full border border-linestrong px-3.5 py-2 text-base focus:border-signal focus:outline-none"
            />
            <select
              value={dept}
              onChange={(e) => setDept(e.target.value)}
              aria-label="Filter by department"
              className="rounded-full border border-linestrong px-3 py-2 text-base focus:border-signal focus:outline-none"
            >
              {departments.map((d) => (
                <option key={d}>{d}</option>
              ))}
            </select>
            <span className="ml-auto flex gap-2">
              {canAdminister ? (
                <Button size="sm" variant="ghost" onClick={() => setInviteOpen((v) => !v)}>
                  <Icon.Users size={15} /> Invite
                </Button>
              ) : null}
              {canSpend ? (
                <Button size="sm" onClick={() => setAllocOpen((v) => !v)}>
                  Allocate credits
                </Button>
              ) : null}
            </span>
          </>
        }
      >
        {members.length === 0 ? (
          <EmptyState
            title="Nobody here yet."
            body="Invite your first employees and they'll appear as soon as they accept."
            action={
              canAdminister ? (
                <Button size="sm" onClick={() => setInviteOpen(true)}>
                  Invite someone
                </Button>
              ) : undefined
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-base">
              <caption className="sr-only">People in this company</caption>
              <thead>
                <tr>
                  <th scope="col" className={th}>Employee</th>
                  <th scope="col" className={th}>Department</th>
                  <th scope="col" className={th}>Cost center</th>
                  <th scope="col" className={th}>Role</th>
                  <th scope="col" className={`${th} text-right`}>Balance</th>
                  {canAdminister ? <th scope="col" className={th}></th> : null}
                </tr>
              </thead>
              <tbody>
                {rows.map((m) => (
                  <tr key={m.id} className="hover:bg-[#fafbfa]">
                    <td className={td}>
                      <span className="nums font-medium">{m.employee_no ?? m.user_id.slice(0, 8)}</span>
                      {m.job_title ? (
                        <span className="mt-0.5 block text-xs text-muted">{m.job_title}</span>
                      ) : null}
                    </td>
                    <td className={td}>{m.department ?? "—"}</td>
                    <td className={`${td} nums text-muted`}>{m.cost_centers?.code ?? "—"}</td>
                    <td className={td}>
                      <Chip tone={m.role === "owner" || m.role === "admin" ? "ok" : "neutral"}>{m.role}</Chip>
                    </td>
                    <td className={`${td} nums text-right`}>{balances[m.user_id] ?? 0}</td>
                    {canAdminister ? (
                      <td className={`${td} text-right`}>
                        {m.role !== "owner" ? (
                          <Button size="sm" variant="ghost" disabled={pending} onClick={() => doRemove(m.user_id)}>
                            Remove
                          </Button>
                        ) : null}
                      </td>
                    ) : null}
                  </tr>
                ))}
                {rows.length === 0 ? (
                  <tr>
                    <td className={`${td} text-muted`} colSpan={6}>
                      Nobody matches that filter.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        )}
      </Panel>

      {inviteOpen && canAdminister ? (
        <Panel title="Invite someone">
          <div className="grid gap-4 p-5 sm:grid-cols-[1fr_1fr_auto] sm:items-end lg:p-6">
            <div>
              <label htmlFor="inv-email" className="label mb-1.5 block">Work email</label>
              <input
                id="inv-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="name@company.com"
                className="w-full rounded-sm border border-linestrong px-3.5 py-2.5 text-base focus:border-signal focus:outline-none"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label htmlFor="inv-dept" className="label mb-1.5 block">Department</label>
                <input
                  id="inv-dept"
                  value={inviteDept}
                  onChange={(e) => setInviteDept(e.target.value)}
                  placeholder="Production"
                  className="w-full rounded-sm border border-linestrong px-3.5 py-2.5 text-base focus:border-signal focus:outline-none"
                />
              </div>
              <div>
                <label htmlFor="inv-role" className="label mb-1.5 block">Role</label>
                <select
                  id="inv-role"
                  value={inviteRole}
                  onChange={(e) => setInviteRole(e.target.value)}
                  className="w-full rounded-sm border border-linestrong px-3 py-2.5 text-base focus:border-signal focus:outline-none"
                >
                  {["viewer", "manager", "finance", "admin"].map((r) => (
                    <option key={r} value={r}>{r}</option>
                  ))}
                </select>
              </div>
            </div>
            <Button disabled={pending || !/.+@.+\..+/.test(email)} onClick={doInvite}>
              {pending ? "Working…" : "Create invite"}
            </Button>
          </div>

          {invites.length > 0 ? (
            <div className="overflow-x-auto border-t border-line">
              <table className="w-full min-w-[560px] text-base">
                <thead>
                  <tr>
                    <th scope="col" className={th}>Email</th>
                    <th scope="col" className={th}>Role</th>
                    <th scope="col" className={th}>Status</th>
                    <th scope="col" className={th}>Expires</th>
                  </tr>
                </thead>
                <tbody>
                  {invites.map((i) => (
                    <tr key={i.id}>
                      <td className={td}>{i.email}</td>
                      <td className={td}>{i.role}</td>
                      <td className={td}>
                        <Chip tone={i.status === "accepted" ? "ok" : i.status === "pending" ? "warn" : "neutral"}>
                          {i.status}
                        </Chip>
                      </td>
                      <td className={`${td} nums text-muted`}>
                        {new Date(i.expires_at).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}
        </Panel>
      ) : null}

      {allocOpen && canSpend ? (
        <Panel title="Allocate credits">
          <div className="grid gap-6 p-5 lg:grid-cols-[1fr_300px] lg:p-6">
            <div className="grid max-w-[520px] gap-4">
              <div>
                <span className="label mb-1.5 block">Who</span>
                <p className="text-base">
                  {dept === "All" ? "Everyone in the company" : dept} —{" "}
                  <span className="nums font-semibold">{target}</span>{" "}
                  {target === 1 ? "person" : "people"}
                </p>
                <p className="mt-1 text-xs text-muted">
                  Change the department filter above to target a group.
                </p>
              </div>
              <div>
                <label htmlFor="amt" className="label mb-1.5 block">Credits each</label>
                <input
                  id="amt"
                  type="number"
                  min={1}
                  value={amount}
                  onChange={(e) => setAmount(Math.max(1, Number(e.target.value) || 1))}
                  className="w-full max-w-[200px] rounded-sm border border-linestrong px-3.5 py-2.5 text-base focus:border-signal focus:outline-none"
                />
              </div>
            </div>

            <aside className="self-start rounded-card bg-shell p-5">
              <p className="eyebrow text-muted">This allocation</p>
              <p className="nums mt-1.5 font-display text-[2rem] font-extrabold leading-none tracking-[-0.03em]">
                {total.toLocaleString()} <span className="text-base text-muted">cr</span>
              </p>
              <dl className="nums mt-4 space-y-1.5 text-sm">
                <div className="flex justify-between text-muted">
                  <dt>Float before</dt>
                  <dd>{float.toLocaleString()}</dd>
                </div>
                <div className={`flex justify-between font-semibold ${short > 0 ? "text-flag" : "text-signal"}`}>
                  <dt>Float after</dt>
                  <dd>{(float - total).toLocaleString()}</dd>
                </div>
              </dl>
              {short > 0 ? (
                <p className="mt-3 text-xs text-flag">
                  Short by {short.toLocaleString()} cr. Top up, or drop to{" "}
                  <button
                    onClick={() => setAmount(Math.max(1, Math.floor(float / Math.max(target, 1))))}
                    className="nums font-semibold underline underline-offset-2"
                  >
                    {Math.floor(float / Math.max(target, 1))} cr each
                  </button>
                  .
                </p>
              ) : (
                <p className="mt-3 text-xs text-muted">
                  Split pre-tax and post-tax against each employee&apos;s §132(f) monthly cap automatically.
                </p>
              )}
              <Button
                className="mt-4 w-full"
                size="sm"
                disabled={pending || short > 0 || target === 0}
                onClick={doAllocate}
              >
                {pending ? "Working…" : short > 0 ? "Not enough float" : `Allocate ${total.toLocaleString()} cr`}
              </Button>
            </aside>
          </div>
        </Panel>
      ) : null}
    </div>
  );
}
