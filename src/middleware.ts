import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * Builds a redirect target that survives the reverse proxy.
 *
 * `req.nextUrl` cannot be used for this. Self-hosted behind nginx, Next builds
 * nextUrl from the address it bound rather than from the request, so
 * `NextResponse.redirect(req.nextUrl.clone())` emitted an absolute
 * `Location: http://localhost:3002/signin` — verified against the origin, and
 * true even on a direct request carrying a correct Host header. Every signed-out
 * visitor would have been redirected to their own machine.
 *
 * nginx sets X-Forwarded-Host and X-Forwarded-Proto, and the app listens on
 * 127.0.0.1 only, so nothing can reach it without passing through nginx and
 * having those headers rewritten. That makes them safe to trust here.
 *
 * The `host` fallback covers `next start` in local development, where there is
 * no proxy and no forwarded headers.
 */
function proxyAwareRedirect(req: NextRequest, pathname: string, search?: URLSearchParams): URL {
  const forwardedHost = req.headers.get("x-forwarded-host");
  const host = forwardedHost ?? req.headers.get("host") ?? req.nextUrl.host;
  const proto =
    req.headers.get("x-forwarded-proto") ?? req.nextUrl.protocol.replace(":", "") ?? "https";

  const url = new URL(`${proto}://${host}`);
  url.pathname = pathname;
  if (search) url.search = search.toString();
  return url;
}

/**
 * Session refresh + portal gate.
 *
 * `/portal` was fully public — anyone could walk into the company console.
 * This now requires a real Supabase session and, for portal routes, an active
 * company membership.
 *
 * Note this only decides whether someone gets *in*. Per-seat tenant scoping is
 * enforced in RLS and in `company_trip_manifest()`, never here — an interface
 * check is not a security boundary.
 */
export async function middleware(req: NextRequest) {
  let res = NextResponse.next({ request: req });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return req.cookies.getAll();
        },
        setAll(toSet) {
          toSet.forEach(({ name, value }) => req.cookies.set(name, value));
          res = NextResponse.next({ request: req });
          toSet.forEach(({ name, value, options }) => res.cookies.set(name, value, options));
        },
      },
    },
  );

  // getUser() revalidates against the auth server — getSession() only reads the
  // cookie, which a client could have forged.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = req.nextUrl.pathname;

  if (path.startsWith("/portal") || path.startsWith("/ops")) {
    if (!user) {
      const next = new URLSearchParams({ next: path });
      return NextResponse.redirect(proxyAwareRedirect(req, "/signin", next));
    }

    // Signed in but not attached to a company yet — send them to set one up.
    if (path.startsWith("/ops")) {
      const { data: role } = await supabase.rpc("platform_operator_role");
      if (!role) {
        return NextResponse.redirect(proxyAwareRedirect(req, "/portal"));
      }
      return res;
    }

    const { data: membership } = await supabase
      .from("company_members")
      .select("company_id, companies(suspended_at)")
      .eq("user_id", user.id)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();

    if (!membership && path !== "/portal/setup") {
      return NextResponse.redirect(proxyAwareRedirect(req, "/business/get-started"));
    }
    const company = membership?.companies as unknown as { suspended_at: string | null } | null;
    if (company?.suspended_at) {
      return NextResponse.redirect(proxyAwareRedirect(req, "/account-suspended"));
    }
  }

  // Already signed in — no reason to look at the sign-in page.
  if (path === "/signin" && user) {
    // Only same-origin paths: `next` is attacker-controllable, so anything that
    // is not a plain absolute path falls back to /portal rather than becoming an
    // open redirect.
    const requested = req.nextUrl.searchParams.get("next");
    const target = requested && /^\/(?!\/)/.test(requested) ? requested : "/portal";
    return NextResponse.redirect(proxyAwareRedirect(req, target));
  }

  return res;
}

export const config = {
  matcher: [
    "/portal/:path*",
    "/ops/:path*",
    "/signin",
    "/business/get-started",
    "/invite/:path*",
    "/account-suspended",
  ],
};
