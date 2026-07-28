import Link from "next/link";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Button } from "@/components/ui";
import * as Icon from "@/components/icons";
import { footerNav } from "@/lib/nav";

export const metadata = { title: "Page not found" };

export default function NotFound() {
  return (
    <>
      <SiteHeader />
      <main id="main" className="bg-shell">
        <section className="wrap py-20 lg:py-28">
          <p className="eyebrow text-signal">404</p>
          <h1 className="h1 mt-3 max-w-[16ch]">This page isn&apos;t on the route.</h1>
          <p className="mt-5 max-w-[52ch] text-md text-muted">
            The link may be old, or the page may have moved when we reorganised the site. Everything below is
            still where it should be.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Button href="/">Back to the start</Button>
            <Button href="/help" variant="ghost">
              Search help
            </Button>
          </div>

          <div className="mt-14 grid gap-8 border-t border-line pt-10 sm:grid-cols-2 lg:grid-cols-4">
            {footerNav.map((g) => (
              <nav key={g.title} aria-label={g.title}>
                <h2 className="eyebrow text-signal">{g.title}</h2>
                <ul className="mt-3.5 space-y-1">
                  {g.links.map((l) => (
                    <li key={l.href}>
                      <Link
                        href={l.href}
                        className="inline-flex items-center gap-1.5 py-1.5 text-base transition-colors hover:text-signal"
                      >
                        {l.label}
                        <Icon.ArrowRight size={13} className="text-signal opacity-0 transition-opacity hover:opacity-100" />
                      </Link>
                    </li>
                  ))}
                </ul>
              </nav>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
