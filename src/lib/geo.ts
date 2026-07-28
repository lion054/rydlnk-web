/**
 * Geography for Utah County.
 *
 * Coordinates are real, so the OpenStreetMap tiles line up with the corridor
 * data and a visitor's browser geolocation can be matched against it without
 * calling any geocoding service. That matters for two reasons: Nominatim's
 * usage policy rules out using it as a live lookup on every page view, and
 * doing the match locally means the feature works offline and leaks nothing.
 */

export type Place = {
  name: string;
  /** [latitude, longitude] */
  at: [number, number];
  kind: "hub" | "city";
};

/** Rydlnk's operating hub — the employment district the corridors run out of. */
export const HUB: Place = {
  name: "East Bay, Provo",
  at: [40.2075, -111.653],
  kind: "hub",
};

/** Utah County communities people commute in from. */
export const places: Place[] = [
  { name: "Provo", at: [40.2338, -111.6585], kind: "city" },
  { name: "Orem", at: [40.2969, -111.6946], kind: "city" },
  { name: "Vineyard", at: [40.308, -111.7541], kind: "city" },
  { name: "Lindon", at: [40.3391, -111.7208], kind: "city" },
  { name: "Pleasant Grove", at: [40.3641, -111.7385], kind: "city" },
  { name: "American Fork", at: [40.3769, -111.7958], kind: "city" },
  { name: "Lehi", at: [40.3916, -111.8508], kind: "city" },
  { name: "Saratoga Springs", at: [40.3491, -111.9041], kind: "city" },
  { name: "Eagle Mountain", at: [40.3141, -112.0069], kind: "city" },
  { name: "Springville", at: [40.1652, -111.6108], kind: "city" },
  { name: "Mapleton", at: [40.1302, -111.5785], kind: "city" },
  { name: "Spanish Fork", at: [40.115, -111.6549], kind: "city" },
  { name: "Salem", at: [40.053, -111.6738], kind: "city" },
  { name: "Payson", at: [40.0444, -111.7321], kind: "city" },
  { name: "Santaquin", at: [39.9769, -111.7852], kind: "city" },
];

/** Great-circle distance in miles. */
export function distanceMiles([lat1, lon1]: [number, number], [lat2, lon2]: [number, number]) {
  const R = 3958.8;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLon = rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/** Nearest known community to an arbitrary point. */
export function nearestPlace(at: [number, number]) {
  let best = places[0];
  let bestD = Infinity;
  for (const p of places) {
    const d = distanceMiles(at, p.at);
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return { place: best, miles: bestD };
}

/* ------------------------------------------------------------ tile maths */

/** Slippy-map tile coordinates for a lat/lon at a zoom level. */
export function toTile(lat: number, lon: number, z: number) {
  const n = 2 ** z;
  const x = ((lon + 180) / 360) * n;
  const latRad = (lat * Math.PI) / 180;
  const y = ((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2) * n;
  return { x, y };
}

/** Pixel offset of a point within a rendered tile grid. */
export function project(
  lat: number,
  lon: number,
  center: [number, number],
  z: number,
  width: number,
  height: number,
) {
  const c = toTile(center[0], center[1], z);
  const p = toTile(lat, lon, z);
  return {
    left: width / 2 + (p.x - c.x) * 256,
    top: height / 2 + (p.y - c.y) * 256,
  };
}
