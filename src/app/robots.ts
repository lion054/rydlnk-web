import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      // The portal is a demo of a signed-in surface — keep it out of the index.
      disallow: "/portal",
    },
    sitemap: `${site.url}/sitemap.xml`,
  };
}
