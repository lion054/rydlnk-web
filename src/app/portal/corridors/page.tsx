import { redirect } from "next/navigation";
import { EmptyState, Panel, TopBar, td, th } from "@/components/portal/chrome";
import { Chip } from "@/components/ui";
import { CorridorMap } from "@/components/corridor-map";
import { getCorridors, getSession, getSites } from "@/lib/queries";
import { CREDIT_VALUE } from "@/lib/data";
import { ArchiveCorridorButton, TransportAdmin } from "./transport-admin";

export const metadata = { title: "Corridors & sites" };

export default async function CorridorsPage() {
  const session = await getSession();
  if (!session?.membership) redirect("/business/get-started");

  const companyId = session.membership.company_id;
  const [corridors, sites] = await Promise.all([getCorridors(companyId), getSites(companyId)]);

  const exclusive = corridors.filter((c) => c.pooling === "exclusive");
  const canAdminister = session.membership.role === "owner" || session.membership.role === "admin";

  /* What each exclusive corridor costs in seats nobody sits in. Derived from
     the live rows, so it moves when the policy does. */
  const emptyCost = exclusive.reduce((total, c) => {
    const empty = Math.max(0, (c.seats_per_vehicle ?? 8) - Number(c.guaranteed_seats ?? 0));
    return total + empty * (c.seat_credits ?? 0) * CREDIT_VALUE * 20; // ~20 working days
  }, 0);

  return (
    <>
      <TopBar title="Corridors & sites">
        <Chip tone={exclusive.length > 0 ? "warn" : "ok"}>
          {exclusive.length} exclusive
        </Chip>
      </TopBar>

      <div className="space-y-4 p-5 lg:p-7">
        {canAdminister ? <TransportAdmin companyId={companyId} sites={sites.map((s) => ({ id: s.id, name: s.name }))} /> : null}
        <Panel title="Sites">
          {sites.length === 0 ? (
            <EmptyState
              title="No sites yet."
              body="A site is where runs start and end. Corridors are built outward from it, so add one before setting up routes."
            />
          ) : (
            <table className="w-full text-base">
              <thead>
                <tr>
                  <th scope="col" className={th}>Site</th>
                  <th scope="col" className={th}>Address</th>
                  <th scope="col" className={th}>Geocoded</th>
                </tr>
              </thead>
              <tbody>
                {sites.map((s) => (
                  <tr key={s.id} className="hover:bg-[#fafbfa]">
                    <td className={td}>
                      {s.name}
                      {s.is_primary ? <Chip tone="ok" className="ml-2">primary</Chip> : null}
                    </td>
                    <td className={`${td} text-muted`}>{s.address}</td>
                    <td className={td}>
                      {s.lat && s.lng ? (
                        <Chip tone="ok">yes</Chip>
                      ) : (
                        <Chip tone="warn">pending — can&apos;t cluster yet</Chip>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Panel>

        <Panel title="Corridors">
          {corridors.length === 0 ? (
            <EmptyState
              title="No corridors yet."
              body="Once your roster syncs, Rydlnk clusters home addresses into corridors out of each site. You can also add them by hand."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[760px] text-base">
                <caption className="sr-only">Corridors this company funds</caption>
                <thead>
                  <tr>
                    <th scope="col" className={th}>Corridor</th>
                    <th scope="col" className={`${th} text-right`}>Miles</th>
                    <th scope="col" className={`${th} text-right`}>Seat price</th>
                    <th scope="col" className={th}>You guarantee</th>
                  <th scope="col" className={th}>Pooling</th>
                  {canAdminister ? <th scope="col" className={th}>Actions</th> : null}
                  </tr>
                </thead>
                <tbody>
                  {corridors.map((c) => (
                    <tr key={c.id} className="hover:bg-[#fafbfa]">
                      <td className={td}>{c.name}</td>
                      <td className={`${td} nums text-right text-muted`}>{c.miles ?? "—"}</td>
                      <td className={`${td} nums text-right`}>{c.seat_credits} cr</td>
                      <td className={`${td} nums text-muted`}>
                        {c.guaranteed_seats} of {c.seats_per_vehicle}
                      </td>
                      <td className={td}>
                        <Chip tone={c.pooling === "exclusive" ? "warn" : "ok"}>{c.pooling}</Chip>
                      </td>
                      {canAdminister ? <td className={td}><ArchiveCorridorButton companyId={companyId} corridorId={c.id} /></td> : null}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {exclusive.length > 0 ? (
            <p className="border-t border-line bg-[#fafbfa] px-5 py-3 text-xs text-muted">
              Exclusive corridors charter the whole vehicle, so you buy every seat on them — occupied or not. At
              the current guarantees that&apos;s roughly{" "}
              <span className="nums font-semibold text-ink">${Math.round(emptyCost).toLocaleString()}</span> a
              month in seats nobody sits in. Opening them to approved employers sells those seats instead.
            </p>
          ) : null}
        </Panel>

        <Panel title="The network">
          <div className="p-5 lg:p-6">
            <CorridorMap height={420} />
          </div>
        </Panel>
      </div>
    </>
  );
}
