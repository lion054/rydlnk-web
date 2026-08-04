// Browser-side Sentry, loaded only when it is actually configured.
//
// The SDK is 124KB gzipped — 28% of all client JS on this site, measured by
// building with and without this file's import. It was being shipped on every
// page while NEXT_PUBLIC_SENTRY_DSN was empty, which means every visitor
// downloaded and parsed it for an SDK that immediately no-opped.
//
// A static `import * as Sentry from "@sentry/nextjs"` cannot be tree-shaken away
// by the DSN check, because the import is evaluated before `enabled` is ever
// read. Moving to a dynamic import puts the SDK in its own chunk that is
// requested only if the branch below runs.
//
// The trade-off, stated plainly: when a DSN *is* set, the SDK now initialises a
// tick later than it used to, so an error thrown in the first few hundred
// milliseconds of a page load can be missed. If you would rather have that
// coverage than the 124KB, replace this file with a plain top-level import —
// everything else keeps working.

type SentryModule = typeof import("@sentry/nextjs");

const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN;

/**
 * Resolves to the loaded SDK, or null when there is no DSN.
 *
 * Started eagerly rather than lazily so the request overlaps page hydration
 * instead of waiting for the first navigation.
 */
const sentryReady: Promise<SentryModule | null> = dsn
  ? import("@sentry/nextjs").then((Sentry) => {
      Sentry.init({
        dsn,
        environment: process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT ?? process.env.NODE_ENV,
        enabled: true,
        tracesSampleRate: Number(process.env.NEXT_PUBLIC_SENTRY_TRACES_SAMPLE_RATE ?? "0.1"),
        sendDefaultPii: false,
      });
      return Sentry;
    })
  : Promise.resolve(null);

/**
 * Next calls this on every client-side route change and requires the export to
 * exist synchronously, so it cannot itself be awaited into place.
 *
 * Sentry's own `captureRouterTransitionStart` takes the navigation arguments and
 * is safe to call late — the span is created from the arguments, not from the
 * clock — so forwarding through the promise loses the timing of a transition
 * that happens before the SDK lands, and nothing else.
 */
export function onRouterTransitionStart(
  ...args: Parameters<SentryModule["captureRouterTransitionStart"]>
): void {
  // No DSN: this is a no-op with no chunk behind it.
  if (!dsn) return;
  void sentryReady.then((Sentry) => Sentry?.captureRouterTransitionStart(...args));
}
