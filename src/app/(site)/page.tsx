import Link from "next/link";
import { Banner, Photo } from "@/components/media";
import * as Icon from "@/components/icons";
import { images } from "@/lib/images";

const doors = [
  {
    href: "/how-it-works",
    tag: "For me",
    title: "I pay for my own commute",
    line: "Set your week once. Ride with people going your way. A fixed fare, no surge, no daily booking.",
    price: "from $2.40",
    unit: "a seat",
    cta: "How it works",
    tone: "light" as const,
  },
  {
    href: "/business",
    tag: "For work",
    title: "My company pays for staff transport",
    line: "Fund a wallet, set the policy, and let the roster fill the seats. One invoice, split by cost center.",
    price: "one invoice",
    unit: "every cost center",
    cta: "See how it works",
    tone: "dark" as const,
  },
];

export default function Home() {
  return (
    <>
      <Banner img={images.homeHero} priority>
        <p className="eyebrow text-amber">Provo · shared commuting</p>
        <h1 className="h1 mt-4 max-w-[17ch] text-white">
          A seat is a seat.
          <br />
          <span className="text-amber">Who pays for it is the question.</span>
        </h1>
        <p className="mt-6 max-w-[52ch] text-md text-white/80">
          Rydlnk pools people travelling the same corridor at the same time. Same vehicle, same fixed fare —
          settled against your own wallet, or against credits your employer funds.
        </p>
        <div className="mt-9 flex flex-wrap gap-3">
          <Link
            href="/download"
            className="inline-flex min-h-[48px] items-center gap-2 rounded-full bg-amber px-7 font-semibold text-ink transition-colors hover:bg-[#ffd75e]"
          >
            Get the app <Icon.ArrowRight size={17} />
          </Link>
          <Link
            href="/business"
            className="inline-flex min-h-[48px] items-center gap-2 rounded-full border border-white/40 px-7 font-semibold text-white transition-colors hover:border-amber hover:bg-white/5"
          >
            For employers
          </Link>
        </div>
      </Banner>

      <section className="wrap -mt-14 pb-20">
        <div className="grid gap-4 lg:grid-cols-2">
          {doors.map((d) => (
            <Link
              key={d.href}
              href={d.href}
              className={`group relative flex flex-col justify-between overflow-hidden rounded-[18px] border p-8 transition-all hover:-translate-y-1 ${
                d.tone === "light"
                  ? "border-line bg-white hover:shadow-[0_24px_50px_-30px_rgba(7,35,26,0.5)]"
                  : "border-ink bg-ink text-white hover:shadow-[0_24px_50px_-24px_rgba(7,35,26,0.8)]"
              }`}
            >
              <div>
                <span
                  className={`font-mono text-[0.66rem] uppercase tracking-[0.16em] ${
                    d.tone === "light" ? "text-amberdim" : "text-amber"
                  }`}
                >
                  {d.tag}
                </span>
                <h2 className="h3 mt-3 text-[1.55rem] leading-tight">{d.title}</h2>
                <p className={`mt-3 max-w-[38ch] text-[0.95rem] ${d.tone === "light" ? "text-muted" : "text-muteddark"}`}>
                  {d.line}
                </p>
              </div>
              <div className="mt-10 flex items-end justify-between">
                <div>
                  <p className={`font-mono text-[1.35rem] font-medium ${d.tone === "light" ? "text-amberdim" : "text-amber"}`}>
                    {d.price}
                  </p>
                  <p className={`font-mono text-[0.66rem] uppercase tracking-[0.12em] ${d.tone === "light" ? "text-muted" : "text-muteddark"}`}>
                    {d.unit}
                  </p>
                </div>
                <span
                  className={`inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-semibold transition-colors ${
                    d.tone === "light" ? "bg-signal text-white group-hover:bg-signaldim" : "bg-amber text-ink"
                  }`}
                >
                  {d.cta} →
                </span>
              </div>
            </Link>
          ))}
        </div>

        <div className="mt-4 overflow-hidden rounded-lg border border-line bg-white">
          <div className="grid gap-0 md:grid-cols-[1.15fr_1fr] md:items-center">
            <div className="p-7 lg:p-9">
              <p className="eyebrow text-signal">One app either way</p>
              <h2 className="mt-3 max-w-[20ch] font-display text-[1.7rem] font-extrabold leading-[1.15] tracking-[-0.025em]">
                Your employer joining doesn&apos;t change the app you&apos;re holding.
              </h2>
              <p className="mt-3 max-w-[56ch] text-base text-muted">
                Their credits appear as a second balance. Work trips spend credits first; anything outside policy
                comes off your own balance instead of being refused. Nobody installs a second thing.
              </p>
              <Link
                href="/download"
                className="mt-6 inline-flex items-center gap-2 text-base font-semibold text-signal"
              >
                Download the app <Icon.ArrowRight size={16} />
              </Link>
            </div>
            <Photo
              img={images.transitGroup}
              ratio="wide"
              rounded={false}
              sizes="(max-width: 768px) 100vw, 45vw"
              className="h-full"
            />
          </div>
        </div>
      </section>

      {/* Context strip — the corridors, not the product. */}
      <section className="relative">
        <Photo
          img={images.homeCommute}
          ratio="banner"
          rounded={false}
          priority={false}
          sizes="100vw"
          className="hidden md:block"
        />
        <div aria-hidden className="pointer-events-none absolute inset-0 hidden bg-ink/45 md:block" />
        <div className="absolute inset-0 hidden items-center md:flex">
          <div className="wrap">
            <p className="max-w-[26ch] font-display text-[clamp(1.6rem,3vw,2.4rem)] font-extrabold leading-[1.15] tracking-[-0.03em] text-white">
              The same forty people leave the same gate at the same time every night.
            </p>
            <p className="mt-3 max-w-[46ch] text-base text-white/75">
              Each of them paying as though they were the only one making the trip. That&apos;s the whole problem.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
