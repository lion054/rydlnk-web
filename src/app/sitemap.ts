import type { MetadataRoute } from "next";
import { footerNav } from "@/lib/nav";
import { site } from "@/lib/site";

/** Marketing routes only — the portal and invite links are not indexable. */
export default function sitemap(): MetadataRoute.Sitemap {
  const fromNav = footerNav
    .flatMap((g) => g.links.map((l) => l.href))
    .filter((h) => !h.startsWith("/portal"));

  const paths = Array.from(new Set(["/", ...fromNav, "/customers", "/drivers/apply", "/legal/dpa"]));

  return paths.map((path) => ({
    url: `${site.url}${path === "/" ? "" : path}`,
    changeFrequency: "monthly" as const,
    priority: path === "/" ? 1 : 0.7,
  }));
}
