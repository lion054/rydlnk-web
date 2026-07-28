"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { Button } from "./ui";
import * as Icon from "./icons";
import { primaryNav, type NavSection } from "@/lib/nav";

const icons: Record<string, (p: { size?: number; className?: string }) => React.ReactNode> = {
  Calendar: Icon.Calendar,
  Wallet: Icon.Wallet,
  Shield: Icon.Shield,
  Route: Icon.Route,
  Plug: Icon.Plug,
  Building: Icon.Building,
  Chart: Icon.Chart,
  Lock: Icon.Lock,
  Car: Icon.Car,
  Help: Icon.Help,
  Chat: Icon.Chat,
};

/**
 * The real wordmark, replacing the CSS approximation.
 *
 * Extracted from the supplied JPEG: white knocked out to transparency and both
 * brand colors snapped flat, so it composites cleanly on paper, ink and green
 * without the halo the raw file would leave.
 */
export function Logo({ dark = false, sub }: { dark?: boolean; sub?: string }) {
  return (
    <Link href="/" aria-label="Rydlnk — home" className="flex shrink-0 items-center gap-2.5">
      <Image
        src="/rydlnk-logo.png"
        alt="Rydlnk"
        width={341}
        height={149}
        priority
        className="h-[26px] w-auto"
      />
      {sub ? (
        <span
          className={`rounded-[6px] px-1.5 py-[3px] text-2xs font-semibold uppercase tracking-[0.1em] ${
            dark ? "bg-white/10 text-amber" : "bg-ink/8 text-muted"
          }`}
        >
          {sub}
        </span>
      ) : null}
    </Link>
  );
}

/* ------------------------------------------------------------- dropdown */

function Dropdown({ section, open }: { section: NavSection; open: boolean }) {
  if (!open || section.columns.length === 0) return null;
  const wide = section.columns.length > 1 || !!section.feature;

  return (
    <div
      className={`absolute left-1/2 top-full z-50 -translate-x-1/2 pt-3 ${wide ? "w-[min(46rem,90vw)]" : "w-[22rem]"}`}
    >
      <div className="overflow-hidden rounded-lg border border-line bg-white shadow-[0_28px_60px_-24px_rgba(7,35,26,0.28)]">
        <div className={`grid ${section.feature ? "sm:grid-cols-[1fr_15rem]" : ""}`}>
          <div className={`grid gap-x-2 p-3 ${section.columns.length > 1 ? "sm:grid-cols-2" : ""}`}>
            {section.columns.map((col, i) => (
              <div key={col.heading ?? i}>
                {col.heading ? (
                  <p className="eyebrow px-3 pb-1 pt-2.5 text-muted">{col.heading}</p>
                ) : null}
                {col.links.map((l) => {
                  const Glyph = l.icon ? icons[l.icon] : null;
                  return (
                    <Link
                      key={l.href}
                      href={l.href}
                      className="group flex gap-3 rounded-sm px-3 py-2.5 transition-colors hover:bg-shell"
                    >
                      {Glyph ? (
                        <span className="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-sm bg-signal/10 text-signal transition-colors group-hover:bg-signal group-hover:text-white">
                          <Glyph size={17} />
                        </span>
                      ) : null}
                      <span className="min-w-0">
                        <span className="block text-base font-semibold text-ink">{l.label}</span>
                        {l.blurb ? <span className="block text-xs text-muted">{l.blurb}</span> : null}
                      </span>
                    </Link>
                  );
                })}
              </div>
            ))}
          </div>

          {section.feature ? (
            <Link
              href={section.feature.href}
              className="group flex flex-col justify-between gap-4 border-line bg-shell p-5 sm:border-l"
            >
              <span>
                <span className="block text-base font-semibold text-ink">{section.feature.title}</span>
                <span className="mt-1.5 block text-xs text-muted">{section.feature.body}</span>
              </span>
              <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-signal">
                {section.feature.cta}
                <Icon.ArrowRight size={14} className="transition-transform group-hover:translate-x-0.5" />
              </span>
            </Link>
          ) : null}
        </div>
      </div>
    </div>
  );
}

/* --------------------------------------------------------------- header */

export function SiteHeader() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [menu, setMenu] = useState<string | null>(null);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const closeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    setOpen(false);
    setMenu(null);
  }, [pathname]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      if (menu) setMenu(null);
      else if (open) {
        setOpen(false);
        toggleRef.current?.focus();
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [menu, open]);

  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  /* Hover opens on desktop, but with a close delay so crossing the gap between
     the trigger and the panel doesn't dismiss it. Click and keyboard both work
     independently of hover. */
  function hoverOpen(label: string) {
    if (closeTimer.current) clearTimeout(closeTimer.current);
    setMenu(label);
  }
  function hoverClose() {
    closeTimer.current = setTimeout(() => setMenu(null), 120);
  }

  const isActive = (href?: string) =>
    href ? (href === "/" ? pathname === "/" : pathname.startsWith(href)) : false;

  return (
    <header className="sticky top-0 z-50 border-b border-line bg-paper/90 backdrop-blur-md">
      <div className="wrap flex h-[68px] items-center gap-6">
        <Logo />

        {/* One navigation. Depth lives in the dropdowns, not a second row. */}
        <nav className="hidden lg:flex" aria-label="Main">
          {primaryNav.map((s) => {
            const hasMenu = s.columns.length > 0;
            const active = isActive(s.href) || menu === s.label;
            return (
              <div
                key={s.label}
                className="relative"
                onMouseEnter={() => hasMenu && hoverOpen(s.label)}
                onMouseLeave={hoverClose}
              >
                {hasMenu ? (
                  <button
                    onClick={() => setMenu(menu === s.label ? null : s.label)}
                    aria-expanded={menu === s.label}
                    className={`flex items-center gap-1.5 rounded-full px-3.5 py-2 text-base font-medium transition-colors ${
                      active ? "text-ink" : "text-muted hover:text-ink"
                    }`}
                  >
                    {s.label}
                    <Icon.ChevronDown
                      size={14}
                      className={`transition-transform ${menu === s.label ? "rotate-180" : ""}`}
                    />
                  </button>
                ) : (
                  <Link
                    href={s.href!}
                    aria-current={isActive(s.href) ? "page" : undefined}
                    className={`flex items-center rounded-full px-3.5 py-2 text-base font-medium transition-colors ${
                      active ? "text-ink" : "text-muted hover:text-ink"
                    }`}
                  >
                    {s.label}
                  </Link>
                )}
                <Dropdown section={s} open={menu === s.label} />
              </div>
            );
          })}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <Link
            href="/signin"
            className="hidden items-center gap-1.5 rounded-full px-3.5 py-2.5 text-base font-medium text-muted transition-colors hover:text-ink sm:inline-flex"
          >
            <Icon.Lock size={15} />
            Sign in
          </Link>
          <Button href="/download" size="sm">
            Get the app
          </Button>
          <button
            ref={toggleRef}
            onClick={() => setOpen((o) => !o)}
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
            aria-controls="site-menu"
            className="grid h-11 w-11 place-items-center rounded-full border border-linestrong text-ink lg:hidden"
          >
            {open ? <Icon.Close /> : <Icon.Menu />}
          </button>
        </div>
      </div>

      {/* Backdrop closes the dropdown on click-outside. */}
      {menu ? (
        <button
          aria-hidden
          tabIndex={-1}
          onClick={() => setMenu(null)}
          className="fixed inset-0 top-[68px] -z-10 hidden cursor-default lg:block"
        />
      ) : null}

      {open ? (
        <div
          id="site-menu"
          className="max-h-[calc(100dvh-68px)] overflow-y-auto overscroll-contain border-t border-line bg-white lg:hidden"
        >
          <div className="wrap py-2">
            {primaryNav.map((s) => (
              <div key={s.label} className="border-b border-line py-3 last:border-b-0">
                {s.columns.length === 0 ? (
                  <Link href={s.href!} className="block py-1.5 text-md font-semibold text-ink">
                    {s.label}
                  </Link>
                ) : (
                  <>
                    <p className="eyebrow pb-1.5 text-muted">{s.label}</p>
                    {s.columns.flatMap((c) => c.links).map((l) => {
                      const Glyph = l.icon ? icons[l.icon] : null;
                      return (
                        <Link key={l.href} href={l.href} className="flex items-center gap-3 py-2.5">
                          {Glyph ? (
                            <span className="grid h-9 w-9 shrink-0 place-items-center rounded-sm bg-signal/10 text-signal">
                              <Glyph size={17} />
                            </span>
                          ) : null}
                          <span>
                            <span className="block text-base font-semibold text-ink">{l.label}</span>
                            {l.blurb ? <span className="block text-xs text-muted">{l.blurb}</span> : null}
                          </span>
                        </Link>
                      );
                    })}
                  </>
                )}
              </div>
            ))}
            <Link href="/signin" className="flex items-center gap-2 py-4 text-base font-semibold text-signal">
              <Icon.Lock size={16} />
              Sign in to the portal
            </Link>
          </div>
        </div>
      ) : null}
    </header>
  );
}
