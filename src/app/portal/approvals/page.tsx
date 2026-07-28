import { redirect } from "next/navigation";
import { TopBar } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import { getFloat, getPendingApprovals, getSession } from "@/lib/queries";
import { ApprovalsClient, type ApprovalRow } from "./approvals-client";

export const metadata = { title: "Approvals" };

/**
 * The approvals queue.
 *
 * Every surface used to advertise "N awaiting approval" with nowhere to approve
 * anything. Rows now come from the `approvals` table, written by `fund_seat()`
 * whenever a ride breaches policy.
 */
export default async function ApprovalsPage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const companyId = session.membership.company_id;
  const [rows, float] = await Promise.all([getPendingApprovals(companyId), getFloat(companyId)]);

  const role = session.membership.role;
  const canDecide = role === "owner" || role === "admin" || role === "manager";

  return (
    <>
      <TopBar title="Approvals">
        {rows.length > 0 ? (
          <Chip tone="warn">{rows.length} awaiting you</Chip>
        ) : (
          <Chip tone="ok">Queue clear</Chip>
        )}
      </TopBar>
      <ApprovalsClient rows={rows as ApprovalRow[]} float={float} canDecide={canDecide} />
    </>
  );
}
