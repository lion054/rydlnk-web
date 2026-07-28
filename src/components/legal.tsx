import type { ReactNode } from "react";
import { PageHero } from "@/components/page-chrome";

/**
 * Shell for the legal routes.
 *
 * The banner is deliberate: these pages exist so the footer links resolve and
 * so the commitments already made elsewhere on the site are written down in one
 * place. They are a drafting brief, not counsel's copy — remove the banner only
 * when a lawyer has signed the text off.
 */
export function LegalPage({
  title,
  lede,
  updated,
  children,
}: {
  title: string;
  lede: string;
  updated: string;
  children: ReactNode;
}) {
  return (
    <>
      <PageHero eyebrow="Legal" title={title} lede={lede} />
      <section className="py-14">
        <div className="wrap max-w-[70ch]">
          <p className="mb-9 rounded-[12px] border border-amber/60 bg-amber/10 px-4 py-3 text-[0.86rem] text-ink">
            <b className="font-semibold">Draft — pending legal review.</b> This summarises commitments Rydlnk
            already makes elsewhere on this site. It is not yet a binding agreement and must be reviewed against
            US federal and Utah law — including the Utah Consumer Privacy Act — before launch.
          </p>
          <div className="space-y-8">{children}</div>
          <p className="mt-12 border-t border-line pt-5 font-mono text-[0.72rem] text-muted">
            Last updated {updated}
          </p>
        </div>
      </section>
    </>
  );
}

export function Clause({ heading, children }: { heading: string; children: ReactNode }) {
  return (
    <section>
      <h2 className="h3">{heading}</h2>
      <div className="mt-2.5 space-y-3 text-[0.95rem] leading-relaxed text-muted">{children}</div>
    </section>
  );
}
