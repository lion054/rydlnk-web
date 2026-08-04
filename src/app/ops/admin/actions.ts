"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

type Result = { ok: true; message: string } | { ok: false; error: string };

export async function setCompanySuspension(
  companyId: string, suspended: boolean, reason: string,
): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_set_company_suspension", {
    p_company: companyId, p_suspended: suspended, p_reason: reason,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/ops/admin");
  return { ok: true, message: suspended ? "Company suspended." : "Company reactivated." };
}

export async function decideDriver(driverId: string, approve: boolean, reason: string): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_decide_driver", {
    p_driver: driverId, p_approve: approve, p_reason: reason,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/ops/admin");
  return { ok: true, message: approve ? "Driver approved." : "Driver rejected." };
}

export async function reviewDriverDocument(
  documentId: string, approve: boolean, reason: string,
): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_review_driver_document", {
    p_document: documentId, p_approve: approve, p_reason: reason,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/ops/admin");
  return { ok: true, message: approve ? "Document approved." : "Document rejected." };
}

export async function setPlatformStaff(input: {
  userId: string; role: "dispatcher" | "operations_admin"; active: boolean; reason: string;
}): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_set_platform_staff", {
    p_user: input.userId, p_role: input.role, p_active: input.active, p_reason: input.reason,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/ops/admin");
  return { ok: true, message: "Platform access updated." };
}

export async function refundCompanyTopup(topupId: string, reason: string): Promise<Result> {
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-refund-topup", {
    body: { topup_id: topupId, reason },
  });
  if (error || data?.error) return { ok: false, error: data?.error ?? error?.message ?? "Refund failed." };
  revalidatePath("/ops/admin");
  return { ok: true, message: data?.already_refunded ? "Top-up was already refunded." : "Stripe refund completed." };
}

export async function setUserDisabled(userId: string, disabled: boolean, reason: string): Promise<Result> {
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-set-user-status", {
    body: { user_id: userId, disabled, reason },
  });
  if (error || data?.error) return { ok: false, error: data?.error ?? error?.message ?? "User update failed." };
  revalidatePath("/ops/admin");
  return { ok: true, message: disabled ? "User disabled." : "User re-enabled." };
}
