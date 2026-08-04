// Measures real page performance with a headless browser.
//
//   node scripts/perf-measure.mjs https://rydlnk.us/ [runs]
//
// Reports LCP, TTFB, transfer size, request count and the slowest resources.
// Cold-loads each run with a fresh context so nothing is served from the
// browser cache — the numbers describe a first-time visitor, which is the case
// that actually matters for the marketing pages.

import { chromium } from "@playwright/test";

const url = process.argv[2] ?? "https://rydlnk.us/";
const runs = Number(process.argv[3] ?? 3);

const browser = await chromium.launch();
const results = [];
const resourceTotals = new Map();

for (let run = 0; run < runs; run++) {
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    // Cold cache per run.
    storageState: undefined,
  });
  const page = await context.newPage();

  const requests = [];
  const pending = [];
  page.on("response", (res) => {
    const req = res.request();
    // body() gives the decoded bytes; content-length is absent on gzipped and
    // chunked responses, which is most of them here. Encoded size comes from
    // the Network entry below instead.
    pending.push(
      res.body().then(
        (buf) => {
          const t = req.timing();
          requests.push({
            url: res.url(),
            type: req.resourceType(),
            status: res.status(),
            size: buf.length,
            // responseEnd is already relative to the request start; the earlier
            // version subtracted the absolute epoch startTime from it and
            // produced negative milliseconds.
            ms: t.responseEnd >= 0 ? t.responseEnd : null,
          });
        },
        () => {},
      ),
    );
  });

  // Must be installed before navigation: LCP entries are only delivered to an
  // observer, and getEntriesByType() returns nothing for them in Chromium.
  await page.addInitScript(() => {
    window.__lcp = null;
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const last = entries[entries.length - 1];
      window.__lcp = { time: last.startTime, tag: last.element?.tagName ?? "?", url: last.url ?? "" };
    }).observe({ type: "largest-contentful-paint", buffered: true });
  });

  await page.goto(url, { waitUntil: "load", timeout: 60_000 });

  // Give LCP a moment to settle, then read it from the buffered entries.
  await page.waitForTimeout(1500);
  await Promise.all(pending);

  const metrics = await page.evaluate(() => {
    const nav = performance.getEntriesByType("navigation")[0];
    const paints = performance.getEntriesByType("paint");
    const lcp = window.__lcp;
    return {
      ttfb: nav ? nav.responseStart : null,
      domContentLoaded: nav ? nav.domContentLoadedEventEnd : null,
      load: nav ? nav.loadEventEnd : null,
      transferSize: nav ? nav.transferSize : null,
      fcp: paints.find((p) => p.name === "first-contentful-paint")?.startTime ?? null,
      lcp: lcp ? lcp.time : null,
      lcpElement: lcp ? `${lcp.tag} ${lcp.url.slice(0, 70)}` : null,
    };
  });

  results.push({ ...metrics, requests });
  for (const r of requests) {
    const prev = resourceTotals.get(r.type) ?? { count: 0, bytes: 0 };
    resourceTotals.set(r.type, { count: prev.count + 1, bytes: prev.bytes + r.size });
  }

  await context.close();
}

await browser.close();

const med = (nums) => {
  const s = nums.filter((n) => n != null).sort((a, b) => a - b);
  return s.length ? s[Math.floor(s.length / 2)] : null;
};
const ms = (n) => (n == null ? "n/a" : `${Math.round(n)}ms`);
const kb = (n) => `${(n / 1024).toFixed(1)}KB`;

console.log(`\n${url}   (median of ${runs} cold loads)\n${"─".repeat(64)}`);
console.log(`  TTFB                ${ms(med(results.map((r) => r.ttfb)))}`);
console.log(`  First Contentful    ${ms(med(results.map((r) => r.fcp)))}`);
console.log(`  Largest Contentful  ${ms(med(results.map((r) => r.lcp)))}`);
console.log(`  DOMContentLoaded    ${ms(med(results.map((r) => r.domContentLoaded)))}`);
console.log(`  Load               ${ms(med(results.map((r) => r.load)))}`);
console.log(`  LCP element         ${results[0].lcpElement ?? "n/a"}`);

const last = results[results.length - 1];
console.log(`\n  Requests: ${last.requests.length}`);
for (const [type, v] of [...resourceTotals.entries()].sort((a, b) => b[1].bytes - a[1].bytes)) {
  console.log(`    ${type.padEnd(12)} ${String(Math.round(v.count / runs)).padStart(3)} reqs  ${kb(v.bytes / runs).padStart(9)}`);
}

console.log(`\n  Slowest resources (last run):`);
for (const r of last.requests.sort((a, b) => b.ms - a.ms).slice(0, 8)) {
  const name = r.url.replace(/^https?:\/\/[^/]+/, "").slice(0, 62) || "/";
  console.log(`    ${ms(r.ms).padStart(7)}  ${String(r.status)}  ${name}`);
}
console.log();
