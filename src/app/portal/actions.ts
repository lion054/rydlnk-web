"use server";

import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { createClient } from "@/lib/supabase/server";

/**
 * Portal mutations.
 *
 * Every one of these goes through a SECURITY DEFINER function that re-checks
 * the caller's role in the database. The role check in the UI is a convenience,
 * not the control — an admin-only action stays admin-only even if someone calls
 * the action directly.
 */

type Result = { ok: true; message: string } | { ok: false; error: string };

export async function allocateCredits(
  companyId: string,
  department: string | null,
  creditsEach: number,
): Promise<Result> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("allocate_credits", {
    p_company: companyId,
    p_department: department,
    p_credits_each: creditsEach,
    p_ref: "PORTAL",
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal", "layout");
  return { ok: true, message: `Allocated ${creditsEach} credits to ${data} ${data === 1 ? "person" : "people"}.` };
}

export async function decideApproval(
  approvalId: string,
  decision: "approved" | "declined",
): Promise<Result> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false, error: "Not signed in." };

  const { error } = await supabase
    .from("approvals")
    .update({ status: decision, decided_by: user.id, decided_at: new Date().toISOString() })
    .eq("id", approvalId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal", "layout");
  return { ok: true, message: decision === "approved" ? "Approved." : "Declined." };
}

/**
 * Invite someone. Returns the raw token exactly once — it is stored only as a
 * hash, so this is the only moment the link can be produced.
 */
export async function inviteMember(
  companyId: string,
  email: string,
  role: string,
  department: string | null,
): Promise<Result & { link?: string }> {
  const supabase = await createClient();
  const { data: token, error } = await supabase.rpc("invite_to_company", {
    p_company: companyId,
    p_email: email,
    p_role: role,
    p_department: department,
    p_employee_no: null,
  });

  if (error) return { ok: false, error: error.message };

  // Built from the request host so a preview deployment mints preview links
  // rather than links into production.
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const proto = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const base = `${proto}://${host}`;
  revalidatePath("/portal/people");
  return { ok: true, message: `Invite created for ${email}.`, link: `${base}/invite/${token}` };
}

export async function removeMember(companyId: string, userId: string): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("remove_company_member", {
    p_company: companyId,
    p_user: userId,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal/people");
  return { ok: true, message: "Removed. Unspent credits returned to the float." };
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath("/", "layout");
}

/**
 * Fund the float.
 *
 * Posts a `topup` ledger entry and a matching `float_topups` row. There is no
 * Stripe charge yet — the row is marked so, and the UI says so, because a
 * balance that appears without money moving is exactly the kind of thing that
 * has to be obvious rather than discovered at reconciliation.
 */
export async function topUpFloat(companyId: string, credits: number): Promise<Result> {
  if (!Number.isFinite(credits) || credits <= 0) return { ok: false, error: "Enter a positive amount." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("topup_float", {
    p_company: companyId,
    p_credits: Math.round(credits),
    p_stripe_pi: null,
    p_auto: false,
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal", "layout");
  return { ok: true, message: `Added ${credits.toLocaleString()} credits to the float.` };
}

export type ImportRow = {
  email: string;
  employee_no?: string;
  department?: string;
  cost_center?: string;
  job_title?: string;
  role?: string;
};

/**
 * Bulk-invite a roster.
 *
 * Creates one invite per row rather than inserting memberships directly —
 * nobody joins a company without redeeming a token, which is the same rule the
 * single-invite path follows. Cost centers named in the file are created on
 * first sight so finance codes don't have to be set up by hand first.
 */
export async function importRoster(companyId: string, rows: ImportRow[]): Promise<Result> {
  if (!rows.length) return { ok: false, error: "Nothing to import." };
  if (rows.length > 2000) return { ok: false, error: "Split files over 2,000 rows." };

  const supabase = await createClient();
  const roles = new Set(["viewer", "manager", "finance", "admin"]);

  // Create any cost centers the file references but the company doesn't have.
  const codes = Array.from(
    new Set(rows.map((r) => r.cost_center?.trim()).filter((c): c is string => Boolean(c))),
  );
  if (codes.length) {
    const { data: existing } = await supabase
      .from("cost_centers")
      .select("code")
      .eq("company_id", companyId);
    const have = new Set((existing ?? []).map((c) => c.code));
    const missing = codes.filter((c) => !have.has(c)).map((code) => ({
      company_id: companyId,
      code,
      name: code,
    }));
    if (missing.length) await supabase.from("cost_centers").insert(missing);
  }

  let created = 0;
  const failures: string[] = [];

  for (const row of rows) {
    const { error } = await supabase.rpc("invite_to_company", {
      p_company: companyId,
      p_email: row.email.trim().toLowerCase(),
      p_role: roles.has(row.role ?? "") ? row.role : "viewer",
      p_department: row.department?.trim() || null,
      p_employee_no: row.employee_no?.trim() || null,
    });
    if (error) failures.push(`${row.email}: ${error.message}`);
    else created++;
  }

  revalidatePath("/portal/people");

  if (created === 0) {
    return { ok: false, error: failures[0] ?? "No invites were created." };
  }
  const tail = failures.length ? ` ${failures.length} row(s) failed.` : "";
  return { ok: true, message: `Created ${created} invite${created === 1 ? "" : "s"}.${tail}` };
}
