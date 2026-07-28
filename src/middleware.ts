import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

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

  if (path.startsWith("/portal")) {
    if (!user) {
      const url = req.nextUrl.clone();
      url.pathname = "/signin";
      url.searchParams.set("next", path);
      return NextResponse.redirect(url);
    }

    // Signed in but not attached to a company yet — send them to set one up.
    const { data: membership } = await supabase
      .from("company_members")
      .select("company_id")
      .eq("user_id", user.id)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();

    if (!membership && path !== "/portal/setup") {
      const url = req.nextUrl.clone();
      url.pathname = "/business/get-started";
      return NextResponse.redirect(url);
    }
  }

  // Already signed in — no reason to look at the sign-in page.
  if (path === "/signin" && user) {
    const url = req.nextUrl.clone();
    url.pathname = req.nextUrl.searchParams.get("next") ?? "/portal";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return res;
}

export const config = {
  matcher: [
    "/portal/:path*",
    "/signin",
    "/business/get-started",
    "/invite/:path*",
  ],
};
