"use client";

import { useState, useTransition } from "react";
import { Button, Chip } from "@/components/ui";
import { Panel, td, th } from "@/components/portal/chrome";
import { assignDispatch, saveFleetVehicle } from "../actions";

type Trip = {
  trip_id: string; ride_date: string; pickup_time: string | null; pickup: string; dropoff: string;
  status: string; capacity: number; filled: number; driver_id: string | null; driver_name: string | null;
  vehicle_id: string | null; vehicle_label: string | null; vehicle_registration: string | null;
};
type Driver = { driver_id: string; driver_name: string; rating: number; available: boolean };
type Vehicle = { vehicle_id: string; label: string; registration: string; make_model: string | null; capacity: number; active: boolean };

const field = "rounded-sm border border-linestrong px-3 py-2 text-sm focus:border-signal focus:outline-none";

export function DispatchClient({
  trips, drivers, vehicles, canManageFleet,
}: { trips: Trip[]; drivers: Driver[]; vehicles: Vehicle[]; canManageFleet: boolean }) {
  const [pending, startTransition] = useTransition();
  const [notice, setNotice] = useState<string | null>(null);
  const [label, setLabel] = useState("");
  const [registration, setRegistration] = useState("");
  const [makeModel, setMakeModel] = useState("");
  const [capacity, setCapacity] = useState(8);

  function assign(tripId: string, form: FormData) {
    startTransition(async () => {
      const result = await assignDispatch(tripId, String(form.get("driver")), String(form.get("vehicle")));
      setNotice(result.ok ? result.message : result.error);
    });
  }

  return (
    <div className="space-y-4 p-5 lg:p-7">
      {notice ? <p role="status" className="rounded-sm border border-line bg-white px-4 py-3 text-base">{notice}</p> : null}
      {canManageFleet ? (
        <Panel title="Add fleet vehicle">
          <div className="flex flex-wrap items-end gap-3 p-5">
            <label className="label">Label<input className={`${field} mt-1 block`} value={label} onChange={(e) => setLabel(e.target.value)} /></label>
            <label className="label">Registration<input className={`${field} mt-1 block`} value={registration} onChange={(e) => setRegistration(e.target.value)} /></label>
            <label className="label">Make/model<input className={`${field} mt-1 block`} value={makeModel} onChange={(e) => setMakeModel(e.target.value)} /></label>
            <label className="label">Capacity<input type="number" min={1} className={`${field} mt-1 block w-24`} value={capacity} onChange={(e) => setCapacity(Number(e.target.value))} /></label>
            <Button disabled={pending || !label.trim() || !registration.trim()} onClick={() => startTransition(async () => {
              const result = await saveFleetVehicle({ label, registration, makeModel, capacity });
              setNotice(result.ok ? result.message : result.error);
              if (result.ok) { setLabel(""); setRegistration(""); setMakeModel(""); }
            })}>{pending ? "Saving…" : "Add vehicle"}</Button>
          </div>
        </Panel>
      ) : null}

      <Panel title="Dispatch board">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[1100px] text-base">
            <thead><tr>
              <th className={th}>When</th><th className={th}>Route</th><th className={th}>Manifest</th>
              <th className={th}>Current assignment</th><th className={th}>Assign</th><th className={th}>Status</th>
            </tr></thead>
            <tbody>
              {trips.map((trip) => (
                <tr key={trip.trip_id}>
                  <td className={`${td} nums`}>{new Date(trip.ride_date).toLocaleDateString()} {trip.pickup_time?.slice(0, 5)}</td>
                  <td className={td}>{trip.pickup} → {trip.dropoff}</td>
                  <td className={`${td} nums`}>{trip.filled}/{trip.capacity}</td>
                  <td className={td}>{trip.driver_name ?? "Unassigned"}{trip.vehicle_registration ? ` · ${trip.vehicle_registration}` : ""}</td>
                  <td className={td}>
                    <form action={assign.bind(null, trip.trip_id)} className="flex gap-2">
                      <select name="driver" required defaultValue={trip.driver_id ?? ""} className={field}>
                        <option value="">Driver…</option>
                        {drivers.map((d) => <option key={d.driver_id} value={d.driver_id}>{d.driver_name}{d.available ? "" : " · unavailable"}</option>)}
                      </select>
                      <select name="vehicle" required defaultValue={trip.vehicle_id ?? ""} className={field}>
                        <option value="">Vehicle…</option>
                        {vehicles.filter((v) => v.active && v.capacity >= trip.filled).map((v) => <option key={v.vehicle_id} value={v.vehicle_id}>{v.label} · {v.registration} · {v.capacity} seats</option>)}
                      </select>
                      <Button size="sm" disabled={pending}>Assign</Button>
                    </form>
                  </td>
                  <td className={td}><Chip tone={trip.status === "matched" ? "ok" : "warn"}>{trip.status}</Chip></td>
                </tr>
              ))}
              {trips.length === 0 ? <tr><td className={`${td} text-muted`} colSpan={6}>No trips in the next seven days.</td></tr> : null}
            </tbody>
          </table>
        </div>
      </Panel>
    </div>
  );
}
