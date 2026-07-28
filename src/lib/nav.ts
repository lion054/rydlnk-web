/**
 * Information architecture.
 *
 * The previous structure forked into two parallel tracks, each with its own
 * 5–8 item list, and rendered that list twice — once in the header, once in a
 * subnav directly beneath it. This replaces both with a single five-item
 * header whose depth lives in dropdowns.
 *
 * Riders never sign in on the web; the app owns that surface. So the web is
 * three audiences (rider → download, employer → portal, driver → apply) and
 * one signed-in surface (the employer portal).
 */

export type NavLink = {
  href: string;
  label: string;
  blurb?: string;
  /** Icon key, resolved in the header. */
  icon?: string;
};

export type NavSection = {
  label: string;
  /** Landing page for the section, if the top-level label is itself a link. */
  href?: string;
  columns: { heading?: string; links: NavLink[] }[];
  /** Optional promoted card in the dropdown. */
  feature?: { href: string; title: string; body: string; cta: string };
};

export const primaryNav: NavSection[] = [
  {
    label: "How it works",
    href: "/how-it-works",
    columns: [
      {
        heading: "For your commute",
        links: [
          { href: "/how-it-works", label: "How it works", blurb: "Set your week once, then just get in.", icon: "Calendar" },
          { href: "/fares", label: "Fares", blurb: "A fixed price per seat, published in advance.", icon: "Wallet" },
          { href: "/safety", label: "Safety", blurb: "Built around the 22:00 finish.", icon: "Shield" },
        ],
      },
      {
        heading: "For your company",
        links: [
          { href: "/business/how-it-works", label: "Credits, pooling & roster", blurb: "How money becomes seats.", icon: "Route" },
          { href: "/business/integrations", label: "Integrations", blurb: "The HR and finance systems you already run.", icon: "Plug" },
        ],
      },
    ],
    feature: {
      href: "/download",
      title: "Get the app",
      body: "iOS, Android, or run the whole thing by text message without installing anything.",
      cta: "Download",
    },
  },
  {
    label: "For business",
    href: "/business",
    columns: [
      {
        links: [
          { href: "/business", label: "Overview", blurb: "Employer-funded commuting, run off your roster.", icon: "Building" },
          { href: "/business/how-it-works", label: "How it works", blurb: "Credits, pooling and roster sync.", icon: "Route" },
          { href: "/business/integrations", label: "Integrations", blurb: "Deputy, Workday, SAP and a CSV drop.", icon: "Plug" },
          { href: "/customers", label: "Customers", blurb: "Who runs on Rydlnk, and what it changed.", icon: "Chart" },
        ],
      },
    ],
    feature: {
      href: "/portal",
      title: "See the portal",
      body: "The company console is live in this build. Run an allocation and watch the float move.",
      cta: "Open the demo",
    },
  },
  { label: "Pricing", href: "/pricing", columns: [] },
  {
    label: "Company",
    columns: [
      {
        links: [
          { href: "/about", label: "About", blurb: "Why we built this in Provo.", icon: "Building" },
          { href: "/security", label: "Security", blurb: "What other employers can see. Nothing.", icon: "Lock" },
          { href: "/drivers", label: "Drive with us", blurb: "Fixed corridors, seats sold in advance.", icon: "Car" },
          { href: "/help", label: "Help", blurb: "The questions people actually ask.", icon: "Help" },
          { href: "/contact", label: "Contact", blurb: "Talk to someone.", icon: "Chat" },
        ],
      },
    ],
  },
];

/** Footer columns. Derived where possible so it can't drift from the header. */
export const footerNav: { title: string; links: NavLink[] }[] = [
  {
    title: "Commute",
    links: [
      { href: "/how-it-works", label: "How it works" },
      { href: "/fares", label: "Fares" },
      { href: "/safety", label: "Safety" },
      { href: "/download", label: "Get the app" },
    ],
  },
  {
    title: "Business",
    links: [
      { href: "/business", label: "Overview" },
      { href: "/business/how-it-works", label: "How it works" },
      { href: "/business/integrations", label: "Integrations" },
      { href: "/pricing", label: "Pricing" },
      { href: "/portal", label: "Company portal" },
    ],
  },
  {
    title: "Company",
    links: [
      { href: "/about", label: "About" },
      { href: "/customers", label: "Customers" },
      { href: "/security", label: "Security" },
      { href: "/drivers", label: "Drive with Rydlnk" },
      { href: "/contact", label: "Contact" },
    ],
  },
  {
    title: "Support",
    links: [
      { href: "/help", label: "Help center" },
      { href: "/legal/terms", label: "Terms" },
      { href: "/legal/privacy", label: "Privacy" },
      { href: "/legal/dpa", label: "Data processing" },
    ],
  },
];

/** Portal rail, grouped. */
export const portalNav = [
  {
    group: "Operate",
    items: [
      { href: "/portal", label: "Overview", icon: "Dashboard" },
      { href: "/portal/trips", label: "Trips & manifests", icon: "Route" },
      { href: "/portal/approvals", label: "Approvals", icon: "Check", badgeKey: "approvals" },
      { href: "/portal/corridors", label: "Corridors & roster", icon: "Clock" },
    ],
  },
  {
    group: "Administer",
    items: [
      { href: "/portal/people", label: "People", icon: "Users" },
      { href: "/portal/credits", label: "Credits & policy", icon: "Wallet" },
      { href: "/portal/billing", label: "Billing", icon: "Receipt" },
      { href: "/portal/integrations", label: "Integrations", icon: "Plug" },
    ],
  },
];
