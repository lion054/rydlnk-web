import Image from "next/image";
import type { ReactNode } from "react";
import { blur, images, src, type Img } from "@/lib/images";

/**
 * Image primitives.
 *
 * Everything goes through next/image so widths are negotiated per breakpoint
 * and AVIF/WebP are served where supported. Each image ships a blur placeholder
 * in its own average color, so a slow connection sees the layout settle rather
 * than a white box snapping to a photo.
 */

type Ratio = "wide" | "hero" | "square" | "portrait" | "banner";

const ratios: Record<Ratio, string> = {
  banner: "aspect-[21/9]",
  hero: "aspect-[16/10]",
  wide: "aspect-[3/2]",
  square: "aspect-square",
  portrait: "aspect-[4/5]",
};

export function Photo({
  img,
  ratio = "wide",
  className = "",
  sizes = "(max-width: 1024px) 100vw, 50vw",
  priority = false,
  rounded = true,
}: {
  img: Img;
  ratio?: Ratio;
  className?: string;
  sizes?: string;
  priority?: boolean;
  rounded?: boolean;
}) {
  return (
    <div
      className={`relative overflow-hidden bg-forest2 ${ratios[ratio]} ${rounded ? "rounded-lg" : ""} ${className}`}
    >
      <Image
        src={src(img, 1600)}
        alt={img.alt}
        fill
        sizes={sizes}
        priority={priority}
        placeholder="blur"
        blurDataURL={blur(img)}
        style={{ objectFit: "cover", objectPosition: img.position ?? "50% 50%" }}
      />
    </div>
  );
}

/**
 * Full-bleed banner with the content sitting on top.
 *
 * The scrim is two stacked gradients rather than a flat overlay: a strong one
 * from the text side and a soft one from the bottom. A single flat tint either
 * washes the photo out or leaves the text unreadable — this keeps the image
 * legible while guaranteeing contrast where the words actually are.
 */
export function Banner({
  img,
  children,
  height = "tall",
  align = "left",
  priority = false,
}: {
  img: Img;
  children: ReactNode;
  height?: "tall" | "medium" | "short";
  align?: "left" | "center";
  priority?: boolean;
}) {
  const h =
    height === "tall"
      ? "min-h-[clamp(30rem,58vw,40rem)]"
      : height === "medium"
        ? "min-h-[clamp(24rem,44vw,32rem)]"
        : "min-h-[clamp(16rem,30vw,22rem)]";

  return (
    <section className={`relative isolate flex items-center overflow-hidden bg-ink ${h}`}>
      <Image
        src={src(img, 2400)}
        alt=""
        aria-hidden
        fill
        sizes="100vw"
        priority={priority}
        placeholder="blur"
        blurDataURL={blur(img)}
        className="-z-20"
        style={{ objectFit: "cover", objectPosition: img.position ?? "50% 50%" }}
      />
      <div
        aria-hidden
        className={`absolute inset-0 -z-10 ${
          align === "center"
            ? "bg-[radial-gradient(ellipse_at_center,rgba(7,35,26,0.55),rgba(7,35,26,0.85))]"
            : "bg-[linear-gradient(100deg,rgba(7,35,26,0.93)_0%,rgba(7,35,26,0.72)_34%,rgba(7,35,26,0.28)_66%,rgba(7,35,26,0.05)_100%)]"
        }`}
      />
      <div aria-hidden className="absolute inset-x-0 bottom-0 -z-10 h-32 bg-gradient-to-t from-ink to-transparent" />
      <div className="grid-lines pointer-events-none absolute inset-0 -z-10" />
      <div className={`wrap relative py-16 lg:py-20 ${align === "center" ? "text-center" : ""}`}>{children}</div>
    </section>
  );
}

/** Thin strip of photography used to break up long text pages. */
export function PhotoStrip() {
  const strip = [images.busStop, images.commutersWaiting, images.busFleet, images.transitGroup];
  return (
    <div className="grid grid-cols-2 gap-px bg-line md:grid-cols-4" aria-hidden>
      {strip.map((img) => (
        <div key={img.id} className="relative aspect-[4/3] overflow-hidden bg-forest2">
          <Image
            src={src(img, 600)}
            alt=""
            fill
            sizes="(max-width: 768px) 50vw, 25vw"
            placeholder="blur"
            blurDataURL={blur(img)}
            style={{ objectFit: "cover" }}
          />
        </div>
      ))}
    </div>
  );
}
