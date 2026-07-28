"use client";

import { useEffect, useMemo, useState } from "react";
import { HUB, distanceMiles, nearestPlace, places, project, toTile } from "@/lib/geo";
import { corridors } from "@/lib/data";
import * as Icon from "./icons";

/**
 * OpenStreetMap corridor map.
 *
 * Raster tiles positioned by slippy-map maths rather than a mapping library —
 * Leaflet or MapLibre would be ~40–150 KB of JavaScript to render what is
 * fundamentally a static picture with a dozen markers on it.
 *
 * OSM's tile usage policy requires visible attribution and rules out heavy or
 * bulk use; a handful of tiles on a marketing page is within it. If this ever
 * gets real traffic, move to a paid tile host and keep the attribution.
 */

const TILE = 256;
const ZOOM = 10;

export function CorridorMap({
  height = 460,
  interactive = true,
}: {
  height?: number;
  interactive?: boolean;
}) {
  const [width, setWidth] = useState(900);
  const [located, setLocated] = useState<{ at: [number, number]; name: string; miles: number } | null>(null);
  const [locating, setLocating] = useState(false);
  const [denied, setDenied] = useState<string | null>(null);
  const [hover, setHover] = useState<string | null>(null);

  useEffect(() => {
    const el = document.getElementById("corridor-map");
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setWidth(e.contentRect.width));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  /* Center between the hub and the furthest destination so every corridor fits. */
  const center: [number, number] = [40.21, -111.75];

  const tiles = useMemo(() => {
    const c = toTile(center[0], center[1], ZOOM);
    const cols = Math.ceil(width / TILE) + 2;
    const rows = Math.ceil(height / TILE) + 2;
    const out: { x: number; y: number; left: number; top: number }[] = [];
    for (let dx = -Math.floor(cols / 2); dx <= Math.floor(cols / 2); dx++) {
      for (let dy = -Math.floor(rows / 2); dy <= Math.floor(rows / 2); dy++) {
        const tx = Math.floor(c.x) + dx;
        const ty = Math.floor(c.y) + dy;
        out.push({
          x: tx,
          y: ty,
          left: width / 2 + (tx - c.x) * TILE,
          top: height / 2 + (ty - c.y) * TILE,
        });
      }
    }
    return out;
  }, [width, height, center[0], center[1]]);

  const hub = project(HUB.at[0], HUB.at[1], center, ZOOM, width, height);

  const routes = corridors.map((c) => {
    const dest = places.find((p) => p.name === c.destination)!;
    const to = project(dest.at[0], dest.at[1], center, ZOOM, width, height);
    return { corridor: c, dest, to };
  });

  function locate() {
    if (!("geolocation" in navigator)) {
      setDenied("This browser can't share a location.");
      return;
    }
    setLocating(true);
    setDenied(null);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const at: [number, number] = [pos.coords.latitude, pos.coords.longitude];
        /* Matched against our own list of Utah County communities rather than a
           geocoding API — no key, no rate limit, nothing leaves the browser. */
        const { place, miles } = nearestPlace(at);
        setLocated({ at, name: place.name, miles });
        setLocating(false);
      },
      (err) => {
        setLocating(false);
        setDenied(
          err.code === err.PERMISSION_DENIED
            ? "Location permission was declined — pick your city from the list instead."
            : "Couldn't get a location fix. Pick your city from the list instead.",
        );
      },
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 600000 },
    );
  }

  /* Nearest corridor to whatever the visitor has told us about themselves. */
  const match = useMemo(() => {
    if (!located) return null;
    let best = routes[0];
    let bestD = Infinity;
    for (const r of routes) {
      const d = distanceMiles(located.at, r.dest.at);
      if (d < bestD) {
        bestD = d;
        best = r;
      }
    }
    return { ...best, miles: bestD };
  }, [located, routes]);

  const you = located ? project(located.at[0], located.at[1], center, ZOOM, width, height) : null;

  return (
    <div className="overflow-hidden rounded-lg border border-line bg-white">
      <div
        id="corridor-map"
        className="relative overflow-hidden bg-[#aad3df]"
        style={{ height }}
        role="img"
        aria-label={`Map of Rydlnk corridors running out of ${HUB.name} across Utah County`}
      >
        {tiles.map((t) => (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            key={`${t.x}-${t.y}`}
            src={`https://tile.openstreetmap.org/${ZOOM}/${t.x}/${t.y}.png`}
            alt=""
            width={TILE}
            height={TILE}
            loading="lazy"
            className="absolute select-none"
            style={{ left: t.left, top: t.top }}
          />
        ))}

        {/* Tint so the brand markers read against OSM's own color palette. */}
        <div aria-hidden className="pointer-events-none absolute inset-0 bg-forest/25 mix-blend-multiply" />

        <svg className="pointer-events-none absolute inset-0 h-full w-full" aria-hidden>
          {routes.map(({ corridor, to }) => (
            <line
              key={corridor.name}
              x1={hub.left}
              y1={hub.top}
              x2={to.left}
              y2={to.top}
              stroke={hover === corridor.name ? "#ffc531" : "#12833f"}
              strokeWidth={hover === corridor.name ? 5 : 3}
              strokeLinecap="round"
              opacity={0.95}
            />
          ))}
          {match ? (
            <line
              x1={hub.left}
              y1={hub.top}
              x2={match.to.left}
              y2={match.to.top}
              stroke="#ffc531"
              strokeWidth={5}
              strokeLinecap="round"
            />
          ) : null}
        </svg>

        {/* destinations */}
        {routes.map(({ corridor, dest, to }) => (
          <button
            key={corridor.name}
            onMouseEnter={() => setHover(corridor.name)}
            onMouseLeave={() => setHover(null)}
            onFocus={() => setHover(corridor.name)}
            onBlur={() => setHover(null)}
            tabIndex={interactive ? 0 : -1}
            className="absolute -translate-x-1/2 -translate-y-1/2"
            style={{ left: to.left, top: to.top }}
            aria-label={`${corridor.name}, ${corridor.miles} miles, ${corridor.credits} credits a seat`}
          >
            <span className="flex flex-col items-center gap-1">
              <span
                className={`block rounded-full border-2 border-white shadow-md transition-all ${
                  match?.corridor.name === corridor.name ? "h-4 w-4 bg-amber" : "h-3 w-3 bg-signal"
                }`}
              />
              <span className="whitespace-nowrap rounded-full bg-white/95 px-2 py-0.5 text-2xs font-semibold text-ink shadow-sm">
                {dest.name}
              </span>
            </span>
          </button>
        ))}

        {/* hub */}
        <span
          className="absolute -translate-x-1/2 -translate-y-1/2"
          style={{ left: hub.left, top: hub.top }}
        >
          <span className="flex flex-col items-center gap-1">
            <span className="grid h-8 w-8 place-items-center rounded-full border-2 border-white bg-ink text-white shadow-lg">
              <Icon.Building size={16} />
            </span>
            <span className="whitespace-nowrap rounded-full bg-ink px-2.5 py-1 text-2xs font-semibold text-white shadow-sm">
              {HUB.name}
            </span>
          </span>
        </span>

        {/* the visitor */}
        {you ? (
          <span
            className="absolute -translate-x-1/2 -translate-y-1/2"
            style={{ left: you.left, top: you.top }}
          >
            <span className="relative flex h-4 w-4">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-amber opacity-60" />
              <span className="relative inline-flex h-4 w-4 rounded-full border-2 border-white bg-amber shadow" />
            </span>
          </span>
        ) : null}

        {/* OSM requires this attribution to stay visible. */}
        <a
          href="https://www.openstreetmap.org/copyright"
          target="_blank"
          rel="noopener noreferrer"
          className="absolute bottom-0 right-0 bg-white/85 px-2 py-0.5 text-[10px] text-ink/70 hover:underline"
        >
          © OpenStreetMap contributors
        </a>
      </div>

      {interactive ? (
        <div className="flex flex-wrap items-center gap-3 border-t border-line p-4">
          {match ? (
            <p className="flex-1 text-base" role="status">
              You&apos;re nearest <span className="font-semibold">{located!.name}</span> — the{" "}
              <span className="font-semibold">{match.corridor.name}</span> run departs{" "}
              <span className="nums font-semibold">{match.corridor.departures.at(-1)}</span> at{" "}
              <span className="nums font-semibold">{match.corridor.credits} credits</span> a seat.
            </p>
          ) : (
            <p className="flex-1 text-base text-muted">
              {denied ?? `${corridors.length} corridors running out of ${HUB.name}. Find the one nearest you.`}
            </p>
          )}
          <button
            onClick={locate}
            disabled={locating}
            className="inline-flex min-h-[44px] items-center gap-2 rounded-full border border-linestrong px-5 text-base font-semibold transition-colors hover:border-signal hover:bg-signal/5 disabled:opacity-60"
          >
            <Icon.Pin size={17} className="text-signal" />
            {locating ? "Locating…" : located ? "Update my location" : "Use my location"}
          </button>
        </div>
      ) : null}
    </div>
  );
}
