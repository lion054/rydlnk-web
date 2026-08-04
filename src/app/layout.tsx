import type { Metadata, Viewport } from "next";
import { Bricolage_Grotesque, IBM_Plex_Mono, Public_Sans } from "next/font/google";
import { site } from "@/lib/site";
import "./globals.css";

/* Self-hosted at build time. The previous <link> to fonts.googleapis.com was
   render-blocking and shipped a guaranteed layout shift; `adjustFontFallback`
   metric-matches the fallback so the swap doesn't move anything. */
const display = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: ["400", "600", "800"],
  variable: "--font-display-loaded",
  display: "swap",
});

/* 300 was dropped: `font-light` has zero uses across src/, so it was a preloaded
   font file that nothing could ever render. */
const body = Public_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-body-loaded",
  display: "swap",
});

/* `preload: false` — the weights stay available, they just stop being fetched at
   highest priority on every page.

   All five font files were preloaded, and a preload competes with the LCP image
   for the connection on exactly the pages where the mono face is never rendered:
   it appears on the legal, drivers, security and admin pages, not in the
   marketing hero. Without the preload hint the browser fetches it when the CSS
   actually applies it, which on those pages is early enough, and on the homepage
   is never. */
const mono = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-mono-loaded",
  display: "swap",
  preload: false,
});

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: "Rydlnk — one seat, two ways to pay for it",
    template: "%s · Rydlnk",
  },
  description: site.description,
  applicationName: site.name,
  openGraph: {
    type: "website",
    siteName: site.name,
    locale: "en_US",
    url: site.url,
    title: "Rydlnk — one seat, two ways to pay for it",
    description: site.description,
  },
  twitter: {
    card: "summary_large_image",
    title: "Rydlnk — one seat, two ways to pay for it",
    description: site.description,
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#0e3a2b",
  colorScheme: "light",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable} ${mono.variable}`}>
      <body>
        {/* Sticky header + subnav put ~15 links ahead of the content on every
            page. Visible only once focused. */}
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[100] focus:rounded-full focus:bg-ink focus:px-5 focus:py-3 focus:text-sm focus:font-semibold focus:text-white"
        >
          Skip to content
        </a>
        {children}
      </body>
    </html>
  );
}
