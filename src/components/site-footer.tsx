import Link from "next/link";
import { Logo } from "./site-header";
import * as Icon from "./icons";
import { footerNav } from "@/lib/nav";
import { contact, mailtoWork, stores, smsHref } from "@/lib/site";

export function SiteFooter() {
  return (
    <footer className="bg-ink pb-8 pt-16 text-base text-muteddark">
      <div className="wrap">
        <div className="grid gap-10 lg:grid-cols-[1.4fr_repeat(4,minmax(0,1fr))]">
          <div>
            <Logo dark />
            <p className="mt-4 max-w-[32ch] text-base">
              One seat, two ways to pay for it. Ride on your own account, or on credits your employer funds.
            </p>
            <div className="mt-6 flex flex-wrap gap-2">
              <a
                href={stores.ios}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex min-h-[40px] items-center gap-2 rounded-full border border-white/25 px-4 text-xs font-semibold text-white transition-colors hover:border-amber"
              >
                <Icon.Phone size={15} /> App Store
              </a>
              <a
                href={stores.android}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex min-h-[40px] items-center gap-2 rounded-full border border-white/25 px-4 text-xs font-semibold text-white transition-colors hover:border-amber"
              >
                <Icon.Phone size={15} /> Google Play
              </a>
            </div>
          </div>

          {footerNav.map((g) => (
            <nav key={g.title} aria-label={g.title}>
              <h2 className="eyebrow mb-3 text-signalbright">{g.title}</h2>
              {g.links.map((l) => (
                <Link key={l.href} href={l.href} className="block py-2 text-base transition-colors hover:text-white">
                  {l.label}
                </Link>
              ))}
            </nav>
          ))}
        </div>

        <div className="mt-12 flex flex-wrap items-center justify-between gap-4 border-t border-white/12 pt-6 text-xs">
          <span>© {new Date().getFullYear()} Rydlnk · Provo, Utah</span>
          <span className="flex flex-wrap items-center gap-5">
            <a href={mailtoWork} className="inline-flex items-center gap-1.5 py-1 transition-colors hover:text-white">
              <Icon.Chat size={14} /> {contact.workEmail}
            </a>
            <a
              href={smsHref}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 py-1 transition-colors hover:text-white"
            >
              <Icon.Phone size={14} /> {contact.phoneDisplay}
            </a>
          </span>
        </div>
      </div>
    </footer>
  );
}
