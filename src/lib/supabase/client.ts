import { createBrowserClient } from "@supabase/ssr";

/**
 * Browser Supabase client.
 *
 * The anon key is public by design — every table this touches is protected by
 * Row Level Security, and the company policies added in migration 013 scope
 * reads to the caller's membership. Nothing here is trusted server-side.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
