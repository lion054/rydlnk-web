import Link from "next/link";
import type { ReactNode } from "react";
import type { Payer } from "@/lib/data";

/* ---------------------------------------------------------------- button */

type ButtonProps = {
  children: ReactNode;
  href?: string;
  variant?: "primary" | "amber" | "ghost" | "ghostDark";
  size?: "md" | "sm";
  className?: string;
  onClick?: () => void;
  type?: "button" | "submit";
  disabled?: boolean;
};

const variants: Record<string, string> = {
  primary: "bg-signal text-white hover:bg-signaldim",
  amber: "bg-amber text-ink hover:bg-[#ffd75e]",
  /* A ghost button's border *is* the control, so it needs the 3:1 boundary —
     `line` at 1.28:1 on white made it all but invisible. */
  ghost: "border border-linestrong text-ink hover:border-signal hover:bg-signal/5",
  ghostDark: "border border-white/40 text-white hover:border-amber",
};

export function Button({
  children,
  href,
  variant = "primary",
  size = "md",
  className = "",
  onClick,
  type = "button",
  disabled = false,
}: ButtonProps) {
  /* min-h keeps every button at or above the 44px comfortable touch target,
     including the `sm` variant used throughout the portal. */
  const cls = `inline-flex items-center justify-center gap-2 rounded-full font-semibold transition-colors ${
    size === "sm" ? "min-h-[38px] px-4 py-2 text-sm" : "min-h-[44px] px-6 py-3 text-[0.95rem]"
  } ${variants[variant]} ${className}`;
  if (href) {
    return (
      <Link href={href} className={cls}>
        {children}
      </Link>
    );
  }
  return (
    <button type={type} onClick={onClick} disabled={disabled} className={cls}>
      {children}
    </button>
  );
}

/* ------------------------------------------------------------------ chip */

export function Chip({ children, tone = "neutral", className = "" }: { children: ReactNode; tone?: "neutral" | "ok" | "warn" | "bad" | "dark"; className?: string }) {
  const tones: Record<string, string> = {
    neutral: "border-line text-muted",
    ok: "border-signal/40 bg-signal/10 text-signaldim",
    warn: "border-amber/60 bg-amber/15 text-[#8a5a00]",
    bad: "border-flag/30 bg-flag/10 text-flag",
    dark: "border-white/20 text-muteddark",
  };
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 font-mono text-[0.68rem] tracking-wide ${tones[tone]} ${className}`}>
      {children}
    </span>
  );
}

/* --------------------------------------------------------------- eyebrow */

export function Eyebrow({ children, dark = false }: { children: ReactNode; dark?: boolean }) {
  return <span className={`eyebrow ${dark ? "text-amber" : "text-signal"}`}>{children}</span>;
}

/* -------------------------------------------------------- section header */

export function SectionHead({ eyebrow, title, lede, dark = false }: { eyebrow: string; title: ReactNode; lede?: ReactNode; dark?: boolean }) {
  return (
    <div className="mb-10 max-w-[62ch]">
      <Eyebrow dark={dark}>{eyebrow}</Eyebrow>
      <h2 className={`h2 mb-3.5 mt-3 ${dark ? "text-white" : ""}`}>{title}</h2>
      {lede ? <p className={`text-md ${dark ? "text-muteddark" : "text-muted"}`}>{lede}</p> : null}
    </div>
  );
}

/* ------------------------------------------------------------------ stat */

export function Stat({ value, label, dark = false }: { value: string; label: string; dark?: boolean }) {
  return (
    <div className={`rounded-card border p-5 ${dark ? "border-white/12 bg-white/5" : "border-line bg-white"}`}>
      <p
        className={`nums font-display text-[2rem] font-extrabold leading-none tracking-[-0.03em] ${
          dark ? "text-amber" : "text-ink"
        }`}
      >
        {value}
      </p>
      <p className={`mt-2 text-xs ${dark ? "text-muteddark" : "text-muted"}`}>{label}</p>
    </div>
  );
}

/* ------------------------------------------------------------------ card */

export function Card({
  children,
  dark = false,
  className = "",
  role,
}: {
  children: ReactNode;
  dark?: boolean;
  className?: string;
  role?: string;
}) {
  return (
    <div
      role={role}
      className={`rounded-card border p-6 ${dark ? "border-white/12 bg-white/5" : "border-line bg-white"} ${className}`}
    >
      {children}
    </div>
  );
}

export function Icon({ children, dark = false }: { children: ReactNode; dark?: boolean }) {
  return (
    <div className={`mb-4 grid h-9 w-9 place-items-center rounded-[10px] text-base ${dark ? "bg-amber/15 text-amber" : "bg-signal/12 text-signaldim"}`}>
      {children}
    </div>
  );
}

/* ------------------------------------------------------------ seat pips */

export function SeatPips({ seats, light = false }: { seats: Payer[]; light?: boolean }) {
  /* The pips carry the entire occupancy argument, so they need a text
     equivalent — previously the whole row was aria-hidden and a screen reader
     got nothing at all. */
  const mine = seats.filter((s) => s === "me").length;
  const others = seats.filter((s) => s && s !== "me").length;
  const empty = seats.filter((s) => !s).length;
  const label = [
    `${seats.length} seats`,
    mine ? `${mine} yours` : null,
    others ? `${others} other employers` : null,
    empty ? `${empty} empty` : null,
  ]
    .filter(Boolean)
    .join(", ");

  return (
    <span className="inline-flex gap-1 align-middle" role="img" aria-label={label}>
      {seats.map((s, i) => {
        const base = "h-2.5 w-2.5 rounded-[3px]";
        const cls =
          s === "me"
            ? "bg-signalbright"
            : s
              ? light
                ? "bg-[#a3b8ae]"
                : "bg-white/55"
              : light
                ? "bg-line"
                : "bg-white/15";
        return <i key={i} className={`${base} ${cls}`} aria-hidden />;
      })}
    </span>
  );
}
