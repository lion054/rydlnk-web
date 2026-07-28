import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Rail } from "@/components/portal/chrome";
import { PortalProvider } from "@/components/portal/state";
import { getFloat, getPendingApprovals, getSession } from "@/lib/queries";

export const metadata: Metadata = {
  title: "Company portal",
  robots: { index: false, follow: false },
};

/**
 * The portal shell now loads from the database.
 *
 * Middleware already turned away anyone without a session or membership; these
 * checks are the belt to that braces, because a layout that assumes it can't be
 * reached unauthenticated is one config change from being wrong.
 */
export default async function PortalLayout({ children }: { children: React.ReactNode }) {
  const session = await getSession();
  if (!session) redirect("/signin?next=/portal");
  if (!session.membership) redirect("/business/get-started");

  const { user, membership } = session;
  const [float, approvals] = await Promise.all([
    getFloat(membership.company_id),
    getPendingApprovals(membership.company_id),
  ]);

  const role = membership.role;

  return (
    <PortalProvider
      value={{
        companyId: membership.company_id,
        companyName: membership.companies?.name ?? "Your company",
        role,
        userEmail: user.email ?? "",
        float,
        pendingApprovals: approvals.length,
        canAdminister: role === "owner" || role === "admin",
        canSpend: role === "owner" || role === "admin" || role === "finance",
      }}
    >
      <div className="min-h-screen bg-paper lg:grid lg:grid-cols-[236px_1fr]">
        <Rail />
        <main id="main" className="min-w-0">
          {children}
        </main>
      </div>
    </PortalProvider>
  );
}
