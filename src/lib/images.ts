/**
 * Image manifest.
 *
 * Every ID here was verified to return HTTP 200 from images.unsplash.com before
 * being committed — a 404 in a hero is worse than no hero.
 *
 * LICENSING NOTE, read before launch:
 *
 * The Unsplash License permits free commercial use without attribution, but it
 * does NOT grant model or property releases. That matters here in one specific
 * way: photographs of identifiable people must never be presented as Rydlnk's
 * own riders, drivers or customers, and must never sit next to a testimonial or
 * a named quote — that would be a misrepresentation regardless of the license.
 *
 * So these are used as *context and atmosphere* only. The customer stories on
 * /customers deliberately use no photography of people. Replace these with
 * commissioned photography of your actual corridors before launch; that is also
 * the single biggest credibility upgrade available to this site.
 */

export type Img = {
  /** Unsplash photo ID, verified reachable. */
  id: string;
  /** Written for a screen reader, not for SEO stuffing. */
  alt: string;
  /** Average color, used as the placeholder while the image loads. */
  tone: string;
  /** Focal point, so the crop keeps the subject at narrow widths. */
  position?: string;
};

export const images = {
  /* ------------------------------------------------------------ marketing */
  homeHero: {
    id: "photo-1548218650-3a3e68e69595",
    alt: "Utah County neighbourhoods spreading out beneath the Wasatch Range",
    tone: "#8d8f8a",
    position: "50% 55%",
  },
  homeCommute: {
    id: "photo-1461088945293-0c17689e48ac",
    alt: "Long-exposure photograph of commuters moving along a city street",
    tone: "#2e3438",
  },
  transitGroup: {
    id: "photo-1494627344499-afd1027ee1f5",
    alt: "A group of passengers travelling together in the same carriage",
    tone: "#4a4640",
  },
  busInterior: {
    id: "photo-1656501029164-d1fefd9689f9",
    alt: "Interior of a passenger vehicle showing rows of seats",
    tone: "#575049",
  },
  busBoarding: {
    id: "photo-1563359250-602107d96e47",
    alt: "People gathered beside a bus before departure",
    tone: "#6b6357",
  },
  busFleet: {
    id: "photo-1503902082432-d2ba320b72ef",
    alt: "A line of buses parked at a depot",
    tone: "#8a8378",
  },
  busStop: {
    id: "photo-1685470883352-ba1ea87c937d",
    alt: "A bus waiting at a roadside stop",
    tone: "#7d8894",
  },

  /* -------------------------------------------------------------- business */
  workers: {
    id: "photo-1664382953403-fc1ac77073a0",
    alt: "Two colleagues working together on a warehouse floor",
    tone: "#6d6a64",
    position: "50% 35%",
  },
  warehouse: {
    id: "photo-1586528116022-aeda1613c63d",
    alt: "Staff walking between storage racks in a distribution center",
    tone: "#5c5b58",
  },
  workerPortrait: {
    id: "photo-1598299803204-b73796f43289",
    alt: "A warehouse employee at a workstation during a shift",
    tone: "#7a7268",
  },
  industrial: {
    id: "photo-1553413077-190dd305871c",
    alt: "The interior of a large distribution facility",
    tone: "#585b5e",
  },

  /* --------------------------------------------------------------- drivers */
  driverNight: {
    id: "photo-1608719362752-2104fb42ea3c",
    alt: "A driver at the wheel on a night-time run",
    tone: "#1e2226",
    position: "50% 40%",
  },
  driverNightAlt: {
    id: "photo-1584310881889-93bc9c4577ff",
    alt: "View from inside a vehicle being driven after dark",
    tone: "#232629",
  },
  streetNight: {
    id: "photo-1623346483743-b968a27ed34c",
    alt: "A city street after dark with vehicle lights",
    tone: "#181c22",
  },
  carsNight: {
    id: "photo-1603638725730-233a04d9dca4",
    alt: "Traffic moving along a road at night",
    tone: "#15181d",
  },
  highway: {
    id: "photo-1516319915504-015b432d407c",
    alt: "Long-exposure trails of traffic along a highway at night",
    tone: "#121519",
  },

  /* ----------------------------------------------------------------- place */
  /* ------------------------------------------------------------ Utah County */
  valley: {
    id: "photo-1548218650-3a3e68e69595",
    alt: "Aerial view of Utah County housing spreading toward the Wasatch Range",
    tone: "#8d8f8a",
  },
  wasatch: {
    id: "photo-1621432667047-edcb75619ba4",
    alt: "The Wasatch Range rising behind Utah Valley under a clear sky",
    tone: "#7d8a92",
  },
  provoLot: {
    id: "photo-1661368120066-7e460da2e91e",
    alt: "A parking lot with the Wasatch mountains behind it",
    tone: "#9198a0",
  },
  provoBuilding: {
    id: "photo-1592343502015-76cfbed9e853",
    alt: "A building in Provo with the mountains behind it",
    tone: "#8b8d8e",
  },
  utahField: {
    id: "photo-1727816585894-1f1dd5eb3aa4",
    alt: "Open Utah Valley farmland with the mountains beyond",
    tone: "#95917f",
  },
  utahHome: {
    id: "photo-1586150055299-767c90f0ce21",
    alt: "A Utah County home backing onto the mountains",
    tone: "#8f8e85",
  },
  commutersWaiting: {
    id: "photo-1522850403397-b0c8f2f75451",
    alt: "People waiting on a platform, checking their phones",
    tone: "#4d5257",
  },
} satisfies Record<string, Img>;

const BASE = "https://images.unsplash.com";

/** Sized, cropped, auto-formatted source URL. */
export function src(img: Img, width: number, height?: number) {
  const crop = height ? `&h=${height}&fit=crop&crop=entropy` : "&fit=max";
  return `${BASE}/${img.id}?auto=format&q=72&w=${width}${crop}`;
}

/** A 1x1 SVG in the image's average color — avoids a flash of empty box. */
export function blur(img: Img) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="4" height="3"><rect width="4" height="3" fill="${img.tone}"/></svg>`;
  return `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`;
}
