import { redirect } from "next/navigation";
import { TopBar } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import { getFloat, getInvites, getMembers, getSession, getWalletBalances } from "@/lib/queries";
import { PeopleClient, type InviteRow, type MemberRow } from "./people-client";
import { RosterImport } from "./import";

export const metadata = { title: "People" };

export default async function PeoplePage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const companyId = session.membership.company_id;
  const [members, invites, balances, float] = await Promise.all([
    getMembers(companyId),
    getInvites(companyId),
    getWalletBalances(companyId),
    getFloat(companyId),
  ]);

  const role = session.membership.role;
  const pendingInvites = invites.filter((i) => i.status === "pending").length;

  return (
    <>
      <TopBar title="People">
        <Chip tone="ok">{members.length} active</Chip>
        {pendingInvites > 0 ? <Chip tone="warn">{pendingInvites} invited</Chip> : null}
      </TopBar>
      <PeopleClient
        companyId={companyId}
        members={members as unknown as MemberRow[]}
        invites={invites as InviteRow[]}
        balances={Object.fromEntries(balances)}
        float={float}
        canAdminister={role === "owner" || role === "admin"}
        canSpend={role === "owner" || role === "admin" || role === "finance"}
      />
      {role === "owner" || role === "admin" ? (
        <div className="px-5 pb-5 lg:px-7 lg:pb-7">
          <RosterImport companyId={companyId} />
        </div>
      ) : null}
    </>
  );
}
