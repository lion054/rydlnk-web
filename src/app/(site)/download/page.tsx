import type { Metadata } from "next";
import type { ReactNode } from "react";
import Link from "next/link";
import { SendLink } from "@/components/send-link";
import { Card, Eyebrow, SectionHead } from "@/components/ui";
import { contact, stores, smsHref } from "@/lib/site";

export const metadata: Metadata = {
  title: "Get Rydlnk — iOS, Android or text message",
  description: "Download the Rydlnk app, or use it entirely by text message if you'd rather not install anything.",
};

function StoreButton({ store, sub, href, glyph }: { store: string; sub: string; href: string; glyph: ReactNode }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="flex items-center gap-3 rounded-[12px] border border-white/15 bg-white/6 px-5 py-3.5 transition-colors hover:border-amber"
    >
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-[9px] bg-white/10 text-amber" aria-hidden>
        {glyph}
      </span>
      <span>
        <span className="block font-mono text-[0.6rem] uppercase tracking-[0.12em] text-muteddark">{sub}</span>
        <span className="block text-[0.95rem] font-semibold text-white">{store}</span>
      </span>
    </a>
  );
}

/* Inline marks so both tiles have an icon and neither depends on a font
   shipping the glyph — the App Store tile previously rendered an empty box. */
const AppleMark = (
  <svg viewBox="0 0 24 24" className="h-[18px] w-[18px]" fill="currentColor">
    <path d="M16.36 12.72c.02-2.2 1.8-3.26 1.88-3.31-1.02-1.5-2.62-1.7-3.19-1.72-1.36-.14-2.65.8-3.34.8-.69 0-1.75-.78-2.87-.76-1.48.02-2.84.86-3.6 2.18-1.53 2.66-.39 6.6 1.1 8.76.73 1.06 1.6 2.25 2.74 2.2 1.1-.04 1.52-.71 2.85-.71 1.33 0 1.7.71 2.87.69 1.18-.02 1.93-1.08 2.65-2.14.83-1.22 1.18-2.41 1.2-2.47-.03-.01-2.3-.88-2.32-3.5zM14.2 6.3c.6-.74 1.01-1.76.9-2.78-.87.04-1.93.58-2.56 1.31-.56.65-1.06 1.7-.93 2.7.97.08 1.97-.5 2.59-1.23z" />
  </svg>
);

const PlayMark = (
  <svg viewBox="0 0 24 24" className="h-[18px] w-[18px]" fill="currentColor">
    <path d="M3.6 2.4c-.3.3-.5.75-.5 1.34v16.52c0 .59.2 1.04.5 1.34l.06.05 9.25-9.25v-.2L3.66 2.95l-.06-.05zm12.5 6.1L4.5 2.13l9.5 9.5 2.1-2.13zM17.9 9.6l-2.3 2.03 2.3 2.32 2.77-1.58c.79-.45.79-1.18 0-1.63L17.9 9.6zM4.5 21.87l11.6-6.37-2.1-2.13-9.5 8.5z" />
  </svg>
);

export default function DownloadPage() {
  return (
    <>
      <section className="bg-ink py-16 text-white lg:py-20">
        <div className="wrap grid items-center gap-12 lg:grid-cols-[1fr_auto]">
          <div>
            <Eyebrow dark>Get Rydlnk</Eyebrow>
            <h1 className="h1 mt-3.5 max-w-[14ch]">
              Install it, or <span className="text-amber">don&apos;t</span>.
            </h1>
            <p className="mt-5 max-w-[50ch] text-[1.05rem] text-muteddark">
              The app is the comfortable way to run your week. But every part of Rydlnk — scheduling, seat
              confirmations, the boarding PIN, topping up — also works by text message, because half of the people who need
              this most aren&apos;t going to install anything.
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <StoreButton store="App Store" sub="Download on the" href={stores.ios} glyph={AppleMark} />
              <StoreButton store="Google Play" sub="Get it on" href={stores.android} glyph={PlayMark} />
            </div>

            <div className="mt-8 max-w-[430px]">
              <SendLink />
            </div>
          </div>

          {/* Was a decorative fake QR captioned "placeholder". Replaced with the
              channel this page argues for anyway — one that actually works. */}
          <div className="w-full max-w-[300px] justify-self-center rounded-[18px] border border-white/12 bg-white/5 p-6 text-center">
            <span className="mx-auto grid h-14 w-14 place-items-center rounded-[16px] bg-signal/15 text-signal" aria-hidden>
              <svg viewBox="0 0 24 24" className="h-7 w-7" fill="currentColor">
                <path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.25-1.38a9.9 9.9 0 004.79 1.22h.01c5.46 0 9.9-4.45 9.9-9.91 0-2.65-1.03-5.14-2.9-7.01A9.82 9.82 0 0012.04 2zm5.8 14.13c-.25.69-1.43 1.32-1.97 1.37-.53.05-1.02.24-3.44-.72-2.9-1.14-4.75-4.1-4.9-4.29-.14-.19-1.17-1.55-1.17-2.96s.74-2.1 1-2.39c.26-.29.57-.36.76-.36.19 0 .38 0 .55.01.18.01.41-.07.64.49.24.57.81 1.98.88 2.13.07.14.12.31.02.5-.09.19-.14.31-.28.48-.14.16-.3.36-.42.49-.14.14-.29.29-.12.57.16.29.73 1.2 1.56 1.95 1.08.96 1.98 1.25 2.27 1.39.28.14.45.12.61-.07.17-.19.71-.83.9-1.11.19-.29.38-.24.64-.14.26.09 1.66.78 1.94.93.29.14.48.21.55.33.07.12.07.69-.18 1.38z" />
              </svg>
            </span>
            <p className="mt-4 text-[0.95rem] font-semibold text-white">No install needed</p>
            <p className="mt-1.5 text-[0.84rem] text-muteddark">
              Run the whole thing by text message — schedule, seat confirmations, boarding PIN, top-ups.
            </p>
            <a
              href={smsHref}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-5 inline-flex min-h-[44px] w-full items-center justify-center rounded-full bg-signal px-5 text-[0.88rem] font-semibold text-white transition-colors hover:bg-signaldim"
            >
              Message {contact.smsKeyword} by text
            </a>
            <p className="mt-2.5 font-mono text-[0.62rem] text-muteddark">{contact.phoneDisplay}</p>
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="wrap">
          <SectionHead
            eyebrow="Setting up"
            title="Four minutes, and you'll need one document."
            lede="Rydlnk verifies riders as well as drivers, because everyone in the vehicle is a stranger until they aren't."
          />
          <div className="grid gap-4 md:grid-cols-3">
            <Card>
              <h3 className="h3">A phone number</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                Verified by SMS. This becomes your account whether you use the app or text message.
              </p>
            </Card>
            <Card>
              <h3 className="h3">A home pickup point</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                Drop a pin, or pick a corner you&apos;re happy to walk to. It doesn&apos;t have to be your gate — a lot
                of people prefer that it isn&apos;t.
              </p>
            </Card>
            <Card>
              <h3 className="h3">An ID, once</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                Driver's license or state ID, checked once and then stored encrypted. Employers funding your seat never see
                it.
              </p>
            </Card>
          </div>

          <div className="mt-4 grid gap-4 lg:grid-cols-2">
            <Card className="bg-paper">
              <h3 className="h3">Using it by text message</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                Message{" "}
                <a
                  href={smsHref}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-mono text-signaldim underline underline-offset-4"
                >
                  {contact.phoneDisplay}
                </a>{" "}
                with the word <span className="font-mono text-ink">{contact.smsKeyword}</span>. You&apos;ll get
                your weekly schedule every Sunday, a confirm-or-decline the evening before each trip, and your driver
                and PIN an hour ahead.
              </p>
            </Card>
            <Card className="bg-paper">
              <h3 className="h3">Driving with Rydlnk</h3>
              <p className="mt-2 text-[0.9rem] text-muted">
                Same corridors, every week, with the seats sold before you set off. You&apos;ll need a valid license,
                police clearance, a roadworthy vehicle and passenger insurance.
              </p>
              <p className="mt-4">
                <Link
                  href="/drivers/apply"
                  className="inline-flex items-center gap-1.5 py-1.5 text-xs font-semibold text-signal underline underline-offset-4"
                >
                  Apply to drive
                </Link>
              </p>
            </Card>
          </div>
        </div>
      </section>
    </>
  );
}
