"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui";
import { Panel } from "@/components/portal/chrome";
import * as Icon from "@/components/icons";
import { archiveCompanyCorridor, saveCompanyCorridor, saveCompanySite } from "../actions";

type Site = { id: string; name: string };

const field = "w-full rounded-sm border border-linestrong px-3.5 py-2.5 text-base focus:border-signal focus:outline-none";

export function TransportAdmin({ companyId, sites }: { companyId: string; sites: Site[] }) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  const [mode, setMode] = useState<"site" | "corridor" | null>(null);

  const [siteName, setSiteName] = useState("");
  const [address, setAddress] = useState("");
  const [primary, setPrimary] = useState(sites.length === 0);

  const [corridorName, setCorridorName] = useState("");
  const [destination, setDestination] = useState("");
  const [siteId, setSiteId] = useState(sites[0]?.id ?? "");
  const [miles, setMiles] = useState("");
  const [credits, setCredits] = useState(5);
  const [pooling, setPooling] = useState<"open" | "approved" | "exclusive">("approved");
  const [guaranteed, setGuaranteed] = useState(0);
  const [capacity, setCapacity] = useState(8);

  function saveSite() {
    startTransition(async () => {
      const result = await saveCompanySite({
        companyId, name: siteName.trim(), address: address.trim(), primary,
      });
      setNotice(result.ok ? result.message : result.error);
      if (result.ok) {
        setSiteName(""); setAddress(""); setMode(null);
      }
    });
  }

  function saveCorridor() {
    startTransition(async () => {
      const result = await saveCompanyCorridor({
        companyId,
        siteId: siteId || undefined,
        name: corridorName.trim(),
        destination: destination.trim(),
        miles: miles ? Number(miles) : undefined,
        seatCredits: credits,
        pooling,
        guaranteedSeats: guaranteed,
        seatsPerVehicle: capacity,
      });
      setNotice(result.ok ? result.message : result.error);
      if (result.ok) {
        setCorridorName(""); setDestination(""); setMode(null);
      }
    });
  }

  return (
    <>
      {notice ? <p role="status" className="rounded-sm border border-line bg-white px-4 py-3 text-base">{notice}</p> : null}
      <Panel
        title="Transport setup"
        actions={
          <>
            <Button size="sm" variant="ghost" onClick={() => setMode(mode === "site" ? null : "site")}>
              <Icon.Pin size={15} /> Add site
            </Button>
            <Button size="sm" onClick={() => setMode(mode === "corridor" ? null : "corridor")}>
              <Icon.Route size={15} /> Add corridor
            </Button>
          </>
        }
      >
        {mode === null ? (
          <p className="p-5 text-base text-muted">Add the workplaces and funded routes that define your transport network.</p>
        ) : null}

        {mode === "site" ? (
          <div className="grid gap-4 p-5 sm:grid-cols-2 lg:p-6">
            <label className="label">Site name<input className={`${field} mt-1.5`} value={siteName} onChange={(e) => setSiteName(e.target.value)} /></label>
            <label className="label">Address<input className={`${field} mt-1.5`} value={address} onChange={(e) => setAddress(e.target.value)} /></label>
            <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={primary} onChange={(e) => setPrimary(e.target.checked)} /> Primary site</label>
            <div className="sm:text-right"><Button disabled={pending || !siteName.trim() || !address.trim()} onClick={saveSite}>{pending ? "Saving…" : "Save site"}</Button></div>
          </div>
        ) : null}

        {mode === "corridor" ? (
          <div className="grid gap-4 p-5 sm:grid-cols-2 lg:grid-cols-3 lg:p-6">
            <label className="label">Corridor name<input className={`${field} mt-1.5`} value={corridorName} onChange={(e) => setCorridorName(e.target.value)} /></label>
            <label className="label">Destination<input className={`${field} mt-1.5`} value={destination} onChange={(e) => setDestination(e.target.value)} /></label>
            <label className="label">Site<select className={`${field} mt-1.5`} value={siteId} onChange={(e) => setSiteId(e.target.value)}><option value="">No site</option>{sites.map((s) => <option value={s.id} key={s.id}>{s.name}</option>)}</select></label>
            <label className="label">Miles<input type="number" min="0" step="0.1" className={`${field} mt-1.5`} value={miles} onChange={(e) => setMiles(e.target.value)} /></label>
            <label className="label">Seat credits<input type="number" min="1" className={`${field} mt-1.5`} value={credits} onChange={(e) => setCredits(Number(e.target.value))} /></label>
            <label className="label">Pooling<select className={`${field} mt-1.5`} value={pooling} onChange={(e) => setPooling(e.target.value as typeof pooling)}><option value="open">Open</option><option value="approved">Approved companies</option><option value="exclusive">Exclusive</option></select></label>
            <label className="label">Guaranteed seats<input type="number" min="0" max={capacity} className={`${field} mt-1.5`} value={guaranteed} onChange={(e) => setGuaranteed(Number(e.target.value))} /></label>
            <label className="label">Vehicle capacity<input type="number" min="1" className={`${field} mt-1.5`} value={capacity} onChange={(e) => setCapacity(Number(e.target.value))} /></label>
            <div className="flex items-end sm:justify-end"><Button disabled={pending || !corridorName.trim() || !destination.trim() || guaranteed > capacity} onClick={saveCorridor}>{pending ? "Saving…" : "Save corridor"}</Button></div>
          </div>
        ) : null}
      </Panel>
    </>
  );
}

export function ArchiveCorridorButton({ companyId, corridorId }: { companyId: string; corridorId: string }) {
  const [pending, startTransition] = useTransition();
  return (
    <Button
      size="sm"
      variant="ghost"
      disabled={pending}
      onClick={() => {
        if (!window.confirm("Archive this corridor? Existing ride records will be kept.")) return;
        startTransition(async () => { await archiveCompanyCorridor(companyId, corridorId); });
      }}
    >
      {pending ? "Archiving…" : "Archive"}
    </Button>
  );
}
