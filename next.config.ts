import type { NextConfig } from "next";

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
  images: {
    // Photography is served from the Unsplash CDN and optimised by Next at
    // request time. Swap this for your own bucket once you have commissioned
    // photography of the real corridors.
    remotePatterns: [{ protocol: "https", hostname: "images.unsplash.com", pathname: "/**" }],
    formats: ["image/avif", "image/webp"],
    minimumCacheTTL: 60 * 60 * 24 * 30,
  },
  async redirects() {
    return legacyRoutes.map((r) => ({ ...r, permanent: true }));
  },
};

export default nextConfig;
