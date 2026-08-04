import { createClient } from "@/lib/supabase/server";

/**
 * Portal data access.
 *
 * Every read here is scoped by RLS to the caller's company membership — none of
 * these functions filter by company_id in application code, because a filter in
 * application code is not a security boundary. If a query returns another
 * company's row, the policy is wrong and that's where it gets fixed.
 */

export type Membership = {
  company_id: string;
  role: "owner" | "admin" | "finance" | "manager" | "viewer";
  companies: { name: string; join_mode: string; ein: string | null } | null;
};

/** The signed-in user plus their active company. Null when either is missing. */
export async function getSession() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("company_members")
    .select("company_id, role, companies(name, join_mode, ein)")
    .eq("user_id", user.id)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();

  if (!data) return { user, membership: null as Membership | null };
  return { user, membership: data as unknown as Membership };
}

export async function getFloat(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("company_float_balance")
    .select("credits")
    .eq("company_id", companyId)
    .maybeSingle();
  return data?.credits ?? 0;
}

export async function getMembers(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("company_members")
    .select("id, user_id, role, status, department, employee_no, job_title, cost_centers(code, name)")
    .eq("company_id", companyId)
    .eq("status", "active")
    .order("joined_at", { ascending: true });
  return data ?? [];
}

/** Wallet balances keyed by user, so the directory can show them inline. */
export async function getWalletBalances(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("employee_wallet_balance")
    .select("user_id, credits")
    .eq("company_id", companyId);
  return new Map((data ?? []).map((r) => [r.user_id as string, r.credits as number]));
}

export async function getPendingApprovals(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("approvals")
    .select("id, ride_id, rider_id, reason, detail, company_credits, personal_cents, created_at, expires_at")
    .eq("company_id", companyId)
    .eq("status", "pending")
    .order("created_at", { ascending: true });
  return data ?? [];
}

export async function getLedger(companyId: string, limit = 25) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("credit_ledger")
    .select("id, kind, from_kind, to_kind, credits, ref, memo, created_at")
    .eq("company_id", companyId)
    .order("created_at", { ascending: false })
    .limit(limit);
  return data ?? [];
}

export async function getSpendByCostCenter(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("company_spend_by_cost_center")
    .select("code, name, seats, credits")
    .eq("company_id", companyId)
    .order("credits", { ascending: false });
  return data ?? [];
}

export async function getCorridors(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("company_corridors")
    .select("id, name, destination, miles, seat_credits, pooling, guaranteed_seats, seats_per_vehicle, active")
    .eq("company_id", companyId)
    .eq("active", true)
    .order("name");
  return data ?? [];
}

export async function getSites(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("company_sites")
    .select("id, name, address, lat, lng, is_primary")
    .eq("company_id", companyId)
    .order("is_primary", { ascending: false });
  return data ?? [];
}

export async function getInvites(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("company_invites")
    .select("id, email, role, department, status, expires_at, created_at")
    .eq("company_id", companyId)
    .order("created_at", { ascending: false })
    .limit(50);
  return data ?? [];
}

export async function getInvoices(companyId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("company_invoices")
    .select("id, number, period_start, period_end, seat_credits, platform_cents, total_cents, status, due_at, currency, document_kind")
    .eq("company_id", companyId)
    .order("period_start", { ascending: false });
  return data ?? [];
}

/** Seats this company funded — the manifest rows it is allowed to see. */
export async function getFundedSeats(companyId: string, limit = 50) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("seat_funding")
    .select(
      "ride_id, trip_id, rider_id, source, company_credits, personal_cents, pretax_credits, status, created_at",
    )
    .eq("company_id", companyId)
    .order("created_at", { ascending: false })
    .limit(limit);
  return data ?? [];
}

export async function getBenefitUsage(companyId: string) {
  const supabase = await createClient();
  const month = new Date();
  const first = new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth(), 1))
    .toISOString()
    .slice(0, 10);
  const { data } = await supabase
    .from("benefit_periods")
    .select("user_id, pretax_credits, posttax_credits, cap_cents")
    .eq("company_id", companyId)
    .eq("period_month", first);
  return data ?? [];
}

export type CompanyScheduleRow = {
  schedule_id: string;
  rider_id: string;
  rider_name: string | null;
  employee_no: string | null;
  department: string | null;
  title: string | null;
  destination: string;
  pickup_after: string | null;
  arrive_by: string | null;
  days: number[];
  start_date: string;
  end_date: string | null;
  return_ride: boolean;
  recurring: boolean;
  schedule_status: string;
  upcoming_rides: number;
  funded_rides: number;
  held_credits: number;
};

export async function getCompanySchedules(companyId: string): Promise<CompanyScheduleRow[]> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("company_schedule_overview", { p_company: companyId });
  return (data ?? []) as CompanyScheduleRow[];
}

export type ShiftCandidate = {
  user_id: string;
  email: string;
  department: string | null;
  role: string;
};

/**
 * Active members, for the shift form's employee picker.
 *
 * Goes through company_shift_candidates() rather than selecting company_members
 * directly because the picker needs the email, and auth.users is not reachable
 * under RLS. The function re-checks that the caller is a member of the company
 * it was asked about.
 */
export async function getShiftCandidates(companyId: string): Promise<ShiftCandidate[]> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("company_shift_candidates", { p_company: companyId });
  return (data ?? []) as ShiftCandidate[];
}
