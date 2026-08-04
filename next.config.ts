import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs";

/**
 * Permanent redirects for the pre-restructure URLs.
 *
 * The two-track IA (`/individual/*`, `/work/*`) collapsed into one. Nothing
 * that was ever linked, shared or indexed should 404 — including the three
 * business pages that merged into a single `/business/how-it-works`.
 */
const legacyRoutes: { source: string; destination: string }[] = [
  { source: "/individual", destination: "/how-it-works" },
  { source: "/individual/how-it-works", destination: "/how-it-works" },
  { source: "/individual/fares", destination: "/fares" },
  { source: "/individual/safety", destination: "/safety" },
  { source: "/individual/faq", destination: "/help" },
  { source: "/work", destination: "/business" },
  { source: "/work/credits", destination: "/business/how-it-works" },
  { source: "/work/pooling", destination: "/business/how-it-works" },
  { source: "/work/roster", destination: "/business/how-it-works" },
  { source: "/work/integrations", destination: "/business/integrations" },
  { source: "/work/security", destination: "/security" },
  { source: "/work/pricing", destination: "/pricing" },
  { source: "/work/faq", destination: "/help" },
  { source: "/work/contact", destination: "/contact" },
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  /**
   * Self-hosted on the shared box behind nginx, so the build has to be a
   * self-contained server rather than a Vercel function bundle.
   *
   * `standalone` traces the modules actually reached and emits
   * `.next/standalone` with just those, which is what makes this deployable to a
   * 15G volume that is already 76% full — shipping the full node_modules would
   * be roughly 5x the size. Run it with `node server.js`, not `next start`.
   *
   * The trade-off: `public/` and `.next/static` are NOT copied into standalone
   * by design (they are meant to be served by a CDN). deploy-to-server.sh copies
   * both, and nginx serves /_next/static directly.
   */
  output: "standalone",
  images: {
    // Photography is served from the Unsplash CDN and optimised by Next at
    // request time. Swap this for your own bucket once you have commissioned
    // photography of the real corridors.
    remotePatterns: [{ protocol: "https", hostname: "images.unsplash.com", pathname: "/**" }],
    formats: ["image/avif", "image/webp"],
    minimumCacheTTL: 60 * 60 * 24 * 30,
    /**
     * Trimmed from the default, which ends at 3840.
     *
     * Source images are requested from Unsplash at w=2400 (hero) and w=1600
     * (everything else), so the 3840 variant was asking sharp to upscale a
     * 2400px original — more bytes on the wire for a blurrier picture. It also
     * inflated the cache surface: each image was 8 variants when 7 suffice, and
     * every distinct variant is a separate sharp run and a separate cache entry
     * on a box with 2 CPUs and 3.5G free.
     */
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048],
  },
  async redirects() {
    return legacyRoutes.map((r) => ({ ...r, permanent: true }));
  },
};

export default withSentryConfig(nextConfig, {
  silent: true,
  widenClientFileUpload: true,
  sourcemaps: { deleteSourcemapsAfterUpload: true },
});
