/**
 * Single source for the details that appear in more than one place.
 *
 * These were previously inline strings and `href="#"` stubs scattered across
 * the footer, the download page and the contact page. Anything still marked
 * PLACEHOLDER must be replaced before launch — grep this file, not the tree.
 */

export const site = {
  name: "Rydlnk",
  /**
   * Used by `metadataBase`, magic-link redirects and invite links.
   *
   * Falls back to VERCEL_URL so preview deployments work without configuration
   * — a preview that emails links pointing at production is worse than one that
   * points at itself. Set NEXT_PUBLIC_SITE_URL explicitly on production.
   */
  url:
    process.env.NEXT_PUBLIC_SITE_URL ??
    (process.env.NEXT_PUBLIC_VERCEL_URL
      ? `https://${process.env.NEXT_PUBLIC_VERCEL_URL}`
      : "http://localhost:3000"),
  description:
    "Rydlnk pools commuters traveling the same corridor at the same time in Utah County. Ride on your own account, or on pre-tax credits your employer funds.",
  locale: "en_US",
  timeZone: "America/Denver",
} as const;

export const company = {
  city: "Provo",
  state: "Utah",
  stateShort: "UT",
  /** PLACEHOLDER — replace with the registered business address. */
  address: "Provo, UT 84601",
  region: "Utah County",
} as const;

export const contact = {
  workEmail: "work@rydlnk.us",
  supportEmail: "help@rydlnk.us",
  /** PLACEHOLDER — 555-01xx is the reserved fictional range. Swap for the live
   *  number before launch. */
  phone: "+18015550142",
  phoneDisplay: "(801) 555-0142",
  /** SMS is the default channel in the US; the app carries the rest. */
  smsKeyword: "RIDE",
} as const;

/** PLACEHOLDER — replace with the real store listings once published. */
export const stores = {
  ios: "https://apps.apple.com/app/rydlnk",
  android: "https://play.google.com/store/apps/details?id=us.rydlnk.app",
} as const;

/** Pre-filled SMS link. Works on iOS and Android; the `?&body=` form is the one
 *  both accept. */
export const smsHref = `sms:${contact.phone}?&body=${encodeURIComponent(contact.smsKeyword)}`;

export const telHref = `tel:${contact.phone}`;
export const mailtoWork = `mailto:${contact.workEmail}`;
export const mailtoSupport = `mailto:${contact.supportEmail}`;
