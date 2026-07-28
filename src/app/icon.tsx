import { ImageResponse } from "next/og";
import { readFileSync } from "node:fs";
import { join } from "node:path";

export const size = { width: 64, height: 64 };
export const contentType = "image/png";

/** The brand disc, cropped from the supplied lockup — the only part of the
 *  wordmark that stays legible at favicon size. */
export default function Icon() {
  const mark = readFileSync(join(process.cwd(), "public", "rydlnk-mark.png"));
  const dataUri = `data:image/png;base64,${mark.toString("base64")}`;
  return new ImageResponse(
    (
      <div style={{ width: "100%", height: "100%", display: "flex" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={dataUri} width={64} height={64} alt="" />
      </div>
    ),
    size,
  );
}
