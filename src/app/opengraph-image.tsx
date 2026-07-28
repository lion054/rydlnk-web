import { ImageResponse } from "next/og";

export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const alt = "Rydlnk — one seat, two ways to pay for it";

/**
 * Link preview card. Matters more than usual here: the product is shared over
 * text message, so a bare URL with no card is the default sharing experience
 * without this.
 */
export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          background: "#0e3a2b",
          padding: 72,
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 10,
              background: "#15803d",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <div style={{ width: 13, height: 13, borderRadius: 999, background: "#ffc531" }} />
          </div>
          <div style={{ color: "white", fontSize: 34, fontWeight: 800, letterSpacing: -1 }}>rydlnk</div>
        </div>

        <div style={{ display: "flex", flexDirection: "column" }}>
          <div style={{ color: "white", fontSize: 76, fontWeight: 800, letterSpacing: -2.5, lineHeight: 1.05 }}>
            A seat is a seat.
          </div>
          <div style={{ color: "#ffc531", fontSize: 76, fontWeight: 800, letterSpacing: -2.5, lineHeight: 1.05 }}>
            Who pays for it is the question.
          </div>
        </div>

        <div style={{ color: "#8fb0a2", fontSize: 27, display: "flex" }}>
          Provo · shared commuting · fixed fare per seat
        </div>
      </div>
    ),
    size,
  );
}
