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
  const { error } = await supabase.rpc("decide_company_approval", {
    p_approval: approvalId,
    p_decision: decision,
  });

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
  const { data, error } = await supabase.functions.invoke("send-company-invite", {
    body: {
      company_id: companyId,
      email,
      role,
      department,
      employee_no: null,
    },
  });

  if (error) return { ok: false, error: error.message };

  // Built from the request host so a preview deployment mints preview links
  // rather than links into production.
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const proto = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const base = `${proto}://${host}`;
  const link = data?.link ?? (data?.token ? `${base}/invite/${data.token}` : undefined);
  if (!link) return { ok: false, error: data?.error ?? "Invite delivery failed." };
  revalidatePath("/portal/people");
  return {
    ok: true,
    message: data?.delivered ? `Invite emailed to ${email}.` : `Invite created for ${email}; copy the link to deliver it.`,
    link,
  };
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

export async function saveCompanySite(input: {
  companyId: string;
  siteId?: string;
  name: string;
  address: string;
  lat?: number;
  lng?: number;
  primary: boolean;
}): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("upsert_company_site", {
    p_company: input.companyId,
    p_site: input.siteId ?? null,
    p_name: input.name,
    p_address: input.address,
    p_lat: input.lat ?? null,
    p_lng: input.lng ?? null,
    p_primary: input.primary,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal/corridors");
  return { ok: true, message: "Site saved." };
}

export async function saveCompanyCorridor(input: {
  companyId: string;
  corridorId?: string;
  siteId?: string;
  name: string;
  destination: string;
  miles?: number;
  seatCredits: number;
  pooling: "open" | "approved" | "exclusive";
  guaranteedSeats: number;
  seatsPerVehicle: number;
}): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("upsert_company_corridor", {
    p_company: input.companyId,
    p_corridor: input.corridorId ?? null,
    p_site: input.siteId ?? null,
    p_name: input.name,
    p_destination: input.destination,
    p_miles: input.miles ?? null,
    p_seat_credits: input.seatCredits,
    p_pooling: input.pooling,
    p_guaranteed_seats: input.guaranteedSeats,
    p_seats_per_vehicle: input.seatsPerVehicle,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal/corridors");
  return { ok: true, message: "Corridor saved." };
}

export async function archiveCompanyCorridor(companyId: string, corridorId: string): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("archive_company_corridor", {
    p_company: companyId,
    p_corridor: corridorId,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal/corridors");
  return { ok: true, message: "Corridor archived." };
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath("/", "layout");
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
    const { data, error } = await supabase.functions.invoke("send-company-invite", {
      body: {
        company_id: companyId,
        email: row.email.trim().toLowerCase(),
        role: roles.has(row.role ?? "") ? row.role : "viewer",
        department: row.department?.trim() || null,
        employee_no: row.employee_no?.trim() || null,
      },
    });
    if (error || data?.error) failures.push(`${row.email}: ${data?.error ?? error?.message}`);
    else created++;
  }

  revalidatePath("/portal/people");

  if (created === 0) {
    return { ok: false, error: failures[0] ?? "No invites were created." };
  }
  const tail = failures.length ? ` ${failures.length} row(s) failed.` : "";
  return { ok: true, message: `Created ${created} invite${created === 1 ? "" : "s"}.${tail}` };
}

/* ── Employee shifts ────────────────────────────────────────────────────────
 *
 * A shift is an ordinary `schedules` row that the employer authored rather than
 * the rider. Rides generate from it exactly as they do for a rider-created
 * schedule, so `rides_autofund` funds each seat through the normal path — see
 * migration 028. Nothing about the money changes; only who created the row.
 */

export type ShiftInput = {
  companyId: string;
  riderId: string;
  title: string;
  pickup: string;
  dropoff: string;
  /** "HH:MM" — at least one of these two is required by the form. */
  pickupAfter: string | null;
  arriveBy: string | null;
  /** 0 = Sunday … 6 = Saturday, matching Postgres `extract(dow)`. */
  days: number[];
  startDate: string;
  endDate: string | null;
  returnRide: boolean;
  /** Dollars, as typed. Converted to cents here so the RPC only sees integers. */
  fareEstimate: number;
};

export async function createShift(input: ShiftInput): Promise<Result & { rides?: number }> {
  if (!input.days.length) return { ok: false, error: "Pick at least one day." };
  if (!input.pickupAfter && !input.arriveBy) {
    return { ok: false, error: "Set a pickup time or an arrive-by time." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("create_company_shift", {
    p_company: input.companyId,
    p_rider: input.riderId,
    p_title: input.title.trim() || null,
    p_pickup: input.pickup.trim(),
    p_dropoff: input.dropoff.trim(),
    p_pickup_after: input.pickupAfter,
    p_arrive_by: input.arriveBy,
    p_days: input.days,
    p_start: input.startDate,
    p_end: input.endDate,
    p_return_ride: input.returnRide,
    p_recurring: true,
    // Math.round, not truncation: 3.205 must not silently become 320 cents.
    p_price_cents: Math.round((input.fareEstimate || 0) * 100),
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal/schedules");
  revalidatePath("/portal/trips");
  return { ok: true, message: "Shift scheduled. Rides are generated three weeks ahead.", rides: data };
}

export async function cancelShift(companyId: string, scheduleId: string): Promise<Result> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("cancel_company_shift", {
    p_company: companyId,
    p_schedule: scheduleId,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/portal/schedules");
  revalidatePath("/portal/trips");
  const n = typeof data === "number" ? data : 0;
  return { ok: true, message: `Shift cancelled. ${n} upcoming ride${n === 1 ? "" : "s"} released.` };
}
