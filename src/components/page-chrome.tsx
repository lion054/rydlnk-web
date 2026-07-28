import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";
import { Button } from "./ui";
import * as Icon from "./icons";
import { blur, src, type Img } from "@/lib/images";

/*
 * SubNav and Pager are gone.
 *
 * SubNav rendered the same array the header rendered, 45px below it — the same
 * eight labels printed twice. Pager existed to walk people through eight
 * sequential marketing pages, which is a documentation pattern, not a
 * marketing one. The pages it linked have been merged; related content is now
 * surfaced by `NextSteps` at the foot of a page, chosen per page rather than
 * derived from array position.
 */

/* ------------------------------------------------------------ page header */

export function PageHero({
  eyebrow,
  title,
  lede,
  tone = "light",
  aside,
  actions,
  image,
}: {
  eyebrow?: string;
  title: ReactNode;
  lede?: ReactNode;
  tone?: "light" | "forest" | "ink";
  aside?: ReactNode;
  actions?: ReactNode;
  /** Photography behind a dark hero. Ignored on the light tone, where a photo
   *  behind body text can't be made to hold contrast reliably. */
  image?: Img;
}) {
  const dark = tone !== "light";
  const bg = tone === "forest" ? "bg-forest text-white" : tone === "ink" ? "bg-ink text-white" : "bg-shell";
  const photo = dark ? image : undefined;

  return (
    <section
      className={`relative isolate overflow-hidden border-b ${dark ? "border-white/10" : "border-line"} ${bg} py-14 lg:py-20`}
    >
      {photo ? (
        <>
          <Image
            src={src(photo, 2000)}
            alt=""
            aria-hidden
            fill
            sizes="100vw"
            priority
            placeholder="blur"
            blurDataURL={blur(photo)}
            className="-z-20"
            style={{ objectFit: "cover", objectPosition: photo.position ?? "50% 50%" }}
          />
          {/* Angled scrim: heaviest where the words are, lifting toward the
              image side so the photograph stays visible rather than muddied. */}
          <div
            aria-hidden
            className={`absolute inset-0 -z-10 ${
              tone === "ink"
                ? "bg-[linear-gradient(100deg,rgba(7,35,26,0.94)_0%,rgba(7,35,26,0.78)_42%,rgba(7,35,26,0.30)_100%)]"
                : "bg-[linear-gradient(100deg,rgba(14,58,43,0.94)_0%,rgba(14,58,43,0.76)_42%,rgba(14,58,43,0.28)_100%)]"
            }`}
          />
        </>
      ) : null}
      {dark ? <div className="grid-lines pointer-events-none absolute inset-0 -z-10" /> : null}
      <div className={`wrap relative ${aside ? "grid items-center gap-12 lg:grid-cols-[1fr_auto]" : ""}`}>
        <div>
          {eyebrow ? <p className={`eyebrow ${dark ? "text-amber" : "text-signal"}`}>{eyebrow}</p> : null}
          <h1
            className={`mt-3 max-w-[20ch] font-display text-[clamp(2.1rem,4.4vw,3.4rem)] font-extrabold leading-[1.04] tracking-[-0.03em] ${
              dark ? "text-white" : "text-ink"
            }`}
          >
            {title}
          </h1>
          {lede ? (
            <p className={`mt-5 max-w-[58ch] text-md ${dark ? "text-muteddark" : "text-muted"}`}>{lede}</p>
          ) : null}
          {actions ? <div className="mt-8 flex flex-wrap gap-3">{actions}</div> : null}
        </div>
        {aside ? <div className="justify-self-center lg:justify-self-end">{aside}</div> : null}
      </div>
    </section>
  );
}

/* --------------------------------------------------------------- next steps */

export function NextSteps({ items }: { items: { href: string; label: string; blurb: string }[] }) {
  return (
    <section className="border-t border-line bg-white py-14">
      <div className="wrap">
        <h2 className="eyebrow text-muted">Keep reading</h2>
        <div className="mt-5 grid gap-3 md:grid-cols-3">
          {items.map((i) => (
            <Link
              key={i.href}
              href={i.href}
              className="group rounded-card border border-line p-5 transition-colors hover:border-signal hover:bg-shell"
            >
              <span className="flex items-center justify-between gap-3 text-base font-semibold text-ink">
                {i.label}
                <Icon.ArrowRight size={16} className="shrink-0 text-signal transition-transform group-hover:translate-x-1" />
              </span>
              <span className="mt-1.5 block text-xs text-muted">{i.blurb}</span>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------- CTA banner */

export function CtaBand({
  title,
  lede,
  primary,
  secondary,
}: {
  title: string;
  lede: string;
  primary: { href: string; label: string };
  secondary?: { href: string; label: string };
}) {
  return (
    <section className="bg-signal py-16 text-center text-white">
      <div className="wrap">
        <h2 className="h2 mx-auto max-w-[22ch] text-white">{title}</h2>
        <p className="mx-auto mt-4 max-w-[56ch] text-md text-white/90">{lede}</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Button href={primary.href} variant="amber">
            {primary.label}
          </Button>
          {secondary ? (
            <Button href={secondary.href} variant="ghostDark">
              {secondary.label}
            </Button>
          ) : null}
        </div>
      </div>
    </section>
  );
}
