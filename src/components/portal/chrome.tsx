"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { Logo } from "@/components/site-header";
import * as Icon from "@/components/icons";
import { SEATS_PER_VEHICLE } from "@/lib/data";
import { portalNav } from "@/lib/nav";
import { usePortal } from "./state";
import { signOut } from "@/app/portal/actions";

const icons: Record<string, (p: { size?: number; className?: string }) => React.ReactNode> = {
  Dashboard: Icon.Dashboard,
  Route: Icon.Route,
  Calendar: Icon.Calendar,
  Check: Icon.Check,
  Clock: Icon.Clock,
  Users: Icon.Users,
  Wallet: Icon.Wallet,
  Receipt: Icon.Receipt,
  Plug: Icon.Plug,
};

/* ------------------------------------------------------------------ rail */

export function Rail() {
  const pathname = usePathname();
  const { float, pendingApprovals, companyName, canSpend } = usePortal();

  /* No opening balance to compare against once this is real money, so the bar
     reads against a rolling target rather than a fabricated starting point. */
  const seatsLeft = Math.round(float / 5);
  const pct = Math.max(4, Math.min(100, Math.round((float / 5000) * 100)));
  const badges: Record<string, number> = { approvals: pendingApprovals };

  return (
    /* Below `lg` this is a horizontal strip above the top bar, so it must not be
       sticky — two sticky elements at top-0 overlapped. Full-height rail at lg. */
    <aside className="z-30 bg-ink text-white lg:sticky lg:top-0 lg:flex lg:h-screen lg:flex-col lg:p-4">
      <div className="flex items-center justify-between gap-3 px-3 py-3 lg:block lg:px-2 lg:pb-5 lg:pt-1">
        <Logo dark sub="portal" />
        <span className="flex items-center gap-2 lg:hidden">
          <span className="nums font-mono text-xs text-amber">{float.toLocaleString()} cr</span>
          {canSpend ? (
            <Link
              href="/portal/billing"
              className="rounded-full bg-amber px-3 py-1.5 text-2xs font-semibold text-ink"
            >
              Top up
            </Link>
          ) : null}
        </span>
      </div>

      <nav aria-label="Portal" className="flex gap-1.5 overflow-x-auto px-3 pb-3 lg:block lg:flex-1 lg:overflow-y-auto lg:px-0 lg:pb-0">
        {portalNav.map((g) => (
          <div key={g.group} className="flex gap-1.5 lg:block">
            <p className="eyebrow hidden px-2.5 pb-1.5 pt-4 text-railmuted lg:block">{g.group}</p>
            {g.items.map((i) => {
              const active = pathname === i.href;
              // Keep a bad navigation configuration from taking down the
              // entire authenticated portal. Calendar was previously omitted
              // here, which made the schedules item render as <undefined />.
              const Glyph = icons[i.icon] ?? Icon.Help;
              const badge = i.badgeKey ? badges[i.badgeKey] : 0;
              return (
                <Link
                  key={i.href}
                  href={i.href}
                  aria-current={active ? "page" : undefined}
                  className={`flex shrink-0 items-center gap-2.5 whitespace-nowrap rounded-sm px-2.5 py-2.5 text-base transition-colors lg:w-full ${
                    active ? "bg-forest2 font-semibold text-white" : "text-[#b9cec4] hover:bg-white/8 hover:text-white"
                  }`}
                >
                  <Glyph size={17} />
                  {i.label}
                  {badge ? (
                    <span className="nums ml-auto hidden rounded-full bg-amber px-1.5 py-0.5 text-2xs font-bold text-ink lg:inline">
                      {badge}
                    </span>
                  ) : null}
                </Link>
              );
            })}
          </div>
        ))}
      </nav>

      <div className="mt-5 hidden rounded-card border border-white/12 bg-gradient-to-br from-forest2 to-forest p-4 lg:block">
        <p className="eyebrow text-muteddark">{companyName}</p>
        <p className="nums my-1 font-mono text-[1.35rem] font-medium text-amber" aria-live="polite">
          {float.toLocaleString()} <span className="text-2xs text-muteddark">cr</span>
        </p>
        <p className="text-2xs text-muteddark">
          ≈ {seatsLeft.toLocaleString()} seats · {Math.floor(seatsLeft / SEATS_PER_VEHICLE).toLocaleString()} vehicles
        </p>
        <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/12">
          <div className="h-full rounded-full bg-amber transition-[width] duration-500" style={{ width: `${pct}%` }} />
        </div>
        {canSpend ? (
          <Link
            href="/portal/billing"
            className="mt-3 flex w-full items-center justify-center rounded-full bg-amber py-2.5 text-xs font-semibold text-ink transition-colors hover:bg-[#ffd75e]"
          >
            Top up float
          </Link>
        ) : null}
      </div>

      <Link
        href="/"
        className="mt-4 hidden items-center gap-1.5 px-2.5 text-2xs text-railmuted transition-colors hover:text-white lg:inline-flex"
      >
        <Icon.ArrowLeft size={13} /> Back to site
      </Link>
    </aside>
  );
}

/* --------------------------------------------------------------- top bar */

function isoWeek(d: Date) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
}

export function TopBar({ title, children }: { title: string; children?: ReactNode }) {
  const [stamp, setStamp] = useState<string | null>(null);
  const [menu, setMenu] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const { pendingApprovals, companyName, userEmail, role } = usePortal();

  useEffect(() => {
    const now = new Date();
    setStamp(`Week ${isoWeek(now)} · ${now.toLocaleDateString("en-US", { month: "short", day: "numeric" })}`);
  }, []);

  useEffect(() => {
    if (!menu) return;
    const onDown = (e: MouseEvent) => {
      if (!menuRef.current?.contains(e.target as Node)) setMenu(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setMenu(false);
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [menu]);

  return (
    <div className="sticky top-0 z-20 flex flex-wrap items-center gap-3 border-b border-line bg-white px-5 py-3.5 lg:px-7">
      <h1 className="font-display text-[1.28rem] font-extrabold tracking-[-0.025em]">{title}</h1>
      {children}

      <div className="ml-auto flex items-center gap-2">
        <span className="nums hidden text-xs text-muted md:inline">{stamp}</span>

        <Link
          href="/portal/approvals"
          aria-label={`Notifications — ${pendingApprovals} awaiting approval`}
          className="relative grid h-10 w-10 place-items-center rounded-full text-muted transition-colors hover:bg-shell hover:text-ink"
        >
          <Icon.Bell size={18} />
          {pendingApprovals > 0 ? (
            <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-flag ring-2 ring-white" />
          ) : null}
        </Link>

        {/* The avatar was decorative — no menu, no sign-out, no org context. */}
        <div className="relative" ref={menuRef}>
          <button
            onClick={() => setMenu((m) => !m)}
            aria-expanded={menu}
            aria-haspopup="menu"
            className="flex items-center gap-2 rounded-full py-1 pl-1 pr-2 transition-colors hover:bg-shell"
          >
            <span className="grid h-9 w-9 place-items-center rounded-full bg-forest2 text-xs font-semibold uppercase text-white">
              {(userEmail || "?").slice(0, 2)}
            </span>
            <Icon.ChevronDown size={14} className="text-muted" />
          </button>

          {menu ? (
            <div
              role="menu"
              className="absolute right-0 top-full z-50 mt-2 w-64 overflow-hidden rounded-lg border border-line bg-white shadow-[0_24px_50px_-20px_rgba(7,35,26,0.3)]"
            >
              <div className="border-b border-line px-4 py-3">
                <p className="text-base font-semibold">Tendai Moyo</p>
                <p className="text-xs text-muted">Administrator · Wasatch Manufacturing</p>
              </div>
              {[
                { href: "/portal/billing", label: "Billing & invoices", Glyph: Icon.Receipt },
                { href: "/portal/credits", label: "Credits & policy", Glyph: Icon.Wallet },
                { href: "/portal/integrations", label: "Integrations", Glyph: Icon.Plug },
              ].map(({ href, label, Glyph }) => (
                <Link
                  key={href}
                  href={href}
                  role="menuitem"
                  className="flex items-center gap-3 px-4 py-2.5 text-base transition-colors hover:bg-shell"
                >
                  <Glyph size={17} className="text-muted" /> {label}
                </Link>
              ))}
              <form action={signOut}>
                <button
                  type="submit"
                  role="menuitem"
                  className="flex w-full items-center gap-3 border-t border-line px-4 py-2.5 text-left text-base text-flag transition-colors hover:bg-shell"
                >
                  <Icon.Lock size={17} /> Sign out
                </button>
              </form>
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}

/* ----------------------------------------------------------------- panel */

export function Panel({
  title,
  actions,
  children,
  className = "",
}: {
  title?: string;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`overflow-hidden rounded-card border border-line bg-white ${className}`}>
      {title ? (
        <header className="flex flex-wrap items-center gap-3 border-b border-line px-4 py-3 lg:px-5">
          <h2 className="text-base font-extrabold">{title}</h2>
          {actions}
        </header>
      ) : null}
      {children}
    </section>
  );
}

export function Kpi({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "up" | "down" }) {
  return (
    <div className="rounded-card border border-line bg-white px-5 py-4">
      <p className="eyebrow text-muted">{label}</p>
      <p className="nums mt-2 font-display text-[1.9rem] font-extrabold leading-none tracking-[-0.03em]">{value}</p>
      {sub ? (
        <p className={`mt-1.5 text-xs ${tone === "up" ? "text-signal" : tone === "down" ? "text-flag" : "text-muted"}`}>
          {sub}
        </p>
      ) : null}
    </div>
  );
}

/** Shown when a filter or a queue legitimately has nothing in it. */
export function EmptyState({ title, body, action }: { title: string; body: string; action?: ReactNode }) {
  return (
    <div className="px-6 py-14 text-center">
      <span className="mx-auto grid h-12 w-12 place-items-center rounded-full bg-signal/10 text-signal">
        <Icon.Check size={24} />
      </span>
      <p className="mt-4 text-lg font-extrabold tracking-[-0.015em]">{title}</p>
      <p className="mx-auto mt-1.5 max-w-[46ch] text-base text-muted">{body}</p>
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  );
}

export const th =
  "border-b border-line bg-[#fafbfa] px-4 py-2.5 text-left text-2xs font-semibold uppercase tracking-[0.09em] text-muted lg:px-5";
export const td = "border-b border-line px-4 py-3 align-middle lg:px-5";
