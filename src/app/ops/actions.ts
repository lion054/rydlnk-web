"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

type Result = { ok: true; message: string } | { ok: false; error: string };

export async function assignDispatch(tripId: string, driverId: string, vehicleId: string): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("assign_trip_dispatch", {
    p_trip: tripId, p_driver: driverId, p_vehicle: vehicleId,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/ops/dispatch");
  return { ok: true, message: "Driver and vehicle assigned." };
}

export async function saveFleetVehicle(input: {
  label: string; registration: string; makeModel: string; capacity: number;
}): Promise<Result> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("upsert_fleet_vehicle", {
    p_vehicle: null,
    p_label: input.label,
    p_registration: input.registration,
    p_make_model: input.makeModel,
    p_capacity: input.capacity,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/ops/dispatch");
  return { ok: true, message: "Fleet vehicle added." };
}
