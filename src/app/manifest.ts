import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Rydlnk — one seat, two ways to pay for it",
    short_name: "Rydlnk",
    description: site.description,
    start_url: "/",
    display: "standalone",
    background_color: "#edf1ee",
    theme_color: "#0e3a2b",
  };
}
