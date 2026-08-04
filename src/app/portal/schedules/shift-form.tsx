"use client";

import { useState } from "react";
import { cancelShift, createShift } from "../actions";
import type { ShiftCandidate } from "@/lib/queries";
import * as Icon from "@/components/icons";

/**
 * Schedule a commute on an employee's behalf.
 *
 * Until this existed a schedule could only be created by the rider in the app,
 * so an employer with no app-using staff had no way to put anyone on a vehicle.
 *
 * The employer chooses a destination and a time window, not a route: which
 * vehicle serves it is a dispatch decision, and pickup addresses stay with the
 * rider — the read side of this page is explicit that employers see patterns
 * rather than doorsteps, and creating a shift must not quietly widen that.
 */

const DAYS = [
  { value: 1, label: "Mon" },
  { value: 2, label: "Tue" },
  { value: 3, label: "Wed" },
  { value: 4, label: "Thu" },
  { value: 5, label: "Fri" },
  { value: 6, label: "Sat" },
  { value: 0, label: "Sun" },
];

const field =
  "w-full rounded-sm border border-linestrong bg-white px-3 py-2.5 text-base focus:border-signal focus:outline-none";
const label = "mb-1.5 block text-[0.8rem] font-semibold";

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

export function ShiftForm({
  companyId,
  candidates,
}: {
  companyId: string;
  candidates: ShiftCandidate[];
}) {
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<{ tone: "ok" | "bad"; text: string } | null>(null);

  const [riderId, setRiderId] = useState(candidates[0]?.user_id ?? "");
  const [title, setTitle] = useState("");
  const [pickup, setPickup] = useState("");
  const [dropoff, setDropoff] = useState("");
  // Default to Mon–Fri: a commute shift is the overwhelmingly common case, and
  // an empty selection is the one input the RPC rejects outright.
  const [days, setDays] = useState<number[]>([1, 2, 3, 4, 5]);
  const [mode, setMode] = useState<"arrive" | "pickup">("arrive");
  const [time, setTime] = useState("07:00");
  const [startDate, setStartDate] = useState(today());
  const [endDate, setEndDate] = useState("");
  const [returnRide, setReturnRide] = useState(true);
  const [fare, setFare] = useState("3.20");

  const toggleDay = (d: number) =>
    setDays((prev) => (prev.includes(d) ? prev.filter((x) => x !== d) : [...prev, d]));

  const ready = riderId && pickup.trim() && dropoff.trim() && days.length > 0 && startDate;

  async function submit() {
    setPending(true);
    setNotice(null);
    const res = await createShift({
      companyId,
      riderId,
      title,
      pickup,
      dropoff,
      pickupAfter: mode === "pickup" ? time : null,
      arriveBy: mode === "arrive" ? time : null,
      days,
      startDate,
      endDate: endDate || null,
      returnRide,
      fareEstimate: Number(fare),
    });
    setPending(false);
    setNotice({ tone: res.ok ? "ok" : "bad", text: res.ok ? res.message : res.error });
    if (res.ok) {
      setOpen(false);
      setPickup("");
      setDropoff("");
      setTitle("");
    }
  }

  if (candidates.length === 0) {
    return (
      <p className="rounded-sm border border-line bg-[#fafbfa] px-4 py-3 text-base text-muted">
        Invite someone from <b className="font-semibold text-ink">People</b> first — a shift has to be
        scheduled for an active member.
      </p>
    );
  }

  return (
    <div>
      <div className="flex flex-wrap items-center gap-3">
        <button
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          className="inline-flex min-h-[44px] items-center gap-2 rounded-full bg-signal px-5 font-semibold text-white transition-colors hover:bg-signaldim"
        >
          <Icon.Calendar size={16} /> {open ? "Close" : "Schedule a shift"}
        </button>
        {notice ? (
          <p
            role="status"
            className={`text-base ${notice.tone === "ok" ? "text-signaldim" : "text-flag"}`}
          >
            {notice.text}
          </p>
        ) : null}
      </div>

      {open ? (
        <div className="mt-4 grid gap-5 rounded-lg border border-line bg-white p-5">
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label htmlFor="rider" className={label}>Employee</label>
              <select id="rider" value={riderId} onChange={(e) => setRiderId(e.target.value)} className={field}>
                {candidates.map((c) => (
                  <option key={c.user_id} value={c.user_id}>
                    {c.email}
                    {c.department ? ` · ${c.department}` : ""}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label htmlFor="title" className={label}>
                Shift name <span className="font-normal text-muted">(optional)</span>
              </label>
              <input id="title" value={title} onChange={(e) => setTitle(e.target.value)} className={field} placeholder="Early shift" />
            </div>
            <div>
              <label htmlFor="pickup" className={label}>Pickup area</label>
              <input id="pickup" value={pickup} onChange={(e) => setPickup(e.target.value)} className={field} placeholder="Spanish Fork" />
            </div>
            <div>
              <label htmlFor="dropoff" className={label}>Worksite</label>
              <input id="dropoff" value={dropoff} onChange={(e) => setDropoff(e.target.value)} className={field} placeholder="East Bay plant" />
            </div>
          </div>

          <div>
            <span className={label}>Days</span>
            <div className="flex flex-wrap gap-2">
              {DAYS.map((d) => (
                <button
                  key={d.value}
                  onClick={() => toggleDay(d.value)}
                  aria-pressed={days.includes(d.value)}
                  className={`min-h-[40px] rounded-full border px-4 text-xs font-semibold transition-colors ${
                    days.includes(d.value)
                      ? "border-signal bg-signal text-white"
                      : "border-linestrong text-muted hover:border-signal"
                  }`}
                >
                  {d.label}
                </button>
              ))}
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            <div>
              <span className={label}>Time is a…</span>
              <div className="flex rounded-full border border-line p-0.5">
                {(["arrive", "pickup"] as const).map((m) => (
                  <button
                    key={m}
                    onClick={() => setMode(m)}
                    aria-pressed={mode === m}
                    className={`flex-1 rounded-full py-2 text-xs font-semibold transition-colors ${
                      mode === m ? "bg-signal text-white" : "text-muted"
                    }`}
                  >
                    {m === "arrive" ? "Arrive by" : "Pickup after"}
                  </button>
                ))}
              </div>
            </div>
            <div>
              <label htmlFor="time" className={label}>
                {mode === "arrive" ? "Arrive by" : "Pickup after"}
              </label>
              <input id="time" type="time" value={time} onChange={(e) => setTime(e.target.value)} className={field} />
            </div>
            <div>
              <label htmlFor="fare" className={label}>
                Seat fare <span className="font-normal text-muted">(USD)</span>
              </label>
              <input id="fare" type="number" min="0" step="0.10" value={fare} onChange={(e) => setFare(e.target.value)} className={field} />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label htmlFor="start" className={label}>Starts</label>
              <input id="start" type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className={field} />
            </div>
            <div>
              <label htmlFor="end" className={label}>
                Ends <span className="font-normal text-muted">(optional — leave blank to run on)</span>
              </label>
              <input id="end" type="date" value={endDate} min={startDate} onChange={(e) => setEndDate(e.target.value)} className={field} />
            </div>
          </div>

          <label className="flex cursor-pointer items-center gap-2.5">
            <input
              type="checkbox"
              checked={returnRide}
              onChange={(e) => setReturnRide(e.target.checked)}
              className="h-4 w-4 accent-signal"
            />
            <span className="text-base">Book the journey home as well</span>
          </label>

          <div className="flex items-center gap-3 border-t border-line pt-4">
            <button
              onClick={() => void submit()}
              disabled={!ready || pending}
              className="inline-flex min-h-[46px] items-center gap-2 rounded-full bg-signal px-6 font-semibold text-white transition-colors hover:bg-signaldim disabled:cursor-not-allowed disabled:bg-line disabled:text-muted"
            >
              {pending ? "Scheduling…" : "Schedule shift"}
            </button>
            <p className="text-xs text-muted">
              Rides are generated three weeks ahead and funded from this company&apos;s credits.
            </p>
          </div>
        </div>
      ) : null}
    </div>
  );
}

/** Cancel control, rendered per row on the schedules table. */
export function CancelShift({ companyId, scheduleId }: { companyId: string; scheduleId: string }) {
  const [pending, setPending] = useState(false);
  const [confirming, setConfirming] = useState(false);

  if (!confirming) {
    return (
      <button
        onClick={() => setConfirming(true)}
        className="text-xs font-semibold text-muted underline-offset-2 hover:text-flag hover:underline"
      >
        Cancel
      </button>
    );
  }

  return (
    <span className="inline-flex items-center gap-2">
      <button
        onClick={async () => {
          setPending(true);
          await cancelShift(companyId, scheduleId);
          setPending(false);
          setConfirming(false);
        }}
        disabled={pending}
        className="text-xs font-semibold text-flag underline underline-offset-2 disabled:opacity-60"
      >
        {pending ? "Cancelling…" : "Confirm"}
      </button>
      <button onClick={() => setConfirming(false)} className="text-xs text-muted">
        Keep
      </button>
    </span>
  );
}
