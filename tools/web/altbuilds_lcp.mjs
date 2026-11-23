// Whether a set's page paints as fast with altbuilds' Built from this set
// as without it: the same set's page from two sites at the same moment, --a
// the one to beat (a relay of the tree before the change), --b this
// unit's, each in a browser of its own, at a phone's 390 px and a desk's
// 1280 px. A round opens both at once in fresh contexts, as a first visit,
// the one asked first by turns; one round to warm them is not counted, then
// [--rounds] (8) at each width. Each page's largest contentful paint (the
// browser's own PerformanceObserver), its first paint (first-contentful-paint;
// set3d, 2026-11-23) and when its #built-from row was there.
//
//   node --env-file=.env tools/web/relay_server.mjs 11360   (in the tree before)
//   node --env-file=.env tools/web/relay_server.mjs 11361   (in this one)
//   node tools/web/altbuilds_lcp.mjs --a=http://127.0.0.1:11360 --b=http://127.0.0.1:11361 --out=DIR
//
// The bar (altbuilds): b's LCP, and its first paint, no later than a's,
// beyond the noise, at the median of the rounds' differences at each width;
// DIR/lcp.json keeps every round. Signed out, a visitor's page. Exits 1 when
// a page never painted or b is later at either width.
import { writeFileSync, mkdirSync } from "node:fs";
import { launch } from "./browser.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || `=${fallback}`).split("=").slice(1).join("=");
const A = arg("a");
const B = arg("b");
const OUT = arg("out", "altbuilds_lcp");
const ROUNDS = Number(arg("rounds", "8"));
const SETS = arg("sets", "6080-1,31009-1,10497-1,42115-1").split(",");
if (!A || !B) {
  console.error("altbuilds_lcp: --a=SITE --b=SITE");
  process.exit(2);
}
mkdirSync(OUT, { recursive: true });
const WIDTHS = [[390, 844, true], [1280, 860, false]];

/// One page's paint: LCP (ms from navigation start), #built-from's arrival.
async function paint(browser, site, set, [width, height, phone]) {
  const context = await browser.newContext({ viewport: { width, height }, isMobile: phone, hasTouch: phone,
    deviceScaleFactor: phone ? 2 : 1 });
  const page = await context.newPage();
  await page.addInitScript(() => {
    window.__lcp = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) window.__lcp = Math.max(window.__lcp, entry.startTime);
    }).observe({ type: "largest-contentful-paint", buffered: true });
  });
  try {
    await page.goto(`${site}/library/set/${set}`, { waitUntil: "load", timeout: 120000 });
    await page.waitForSelector("#built-from", { timeout: 60000 }).catch(() => null);
    const row = await page.evaluate(() => {
      const at = document.querySelector("#built-from");
      const mark = performance.getEntriesByType("resource").find((r) => r.name.includes("op=set_based"));
      return { built: at ? at.querySelectorAll(".model").length : -1, based: document.documentElement.dataset.based || null,
        asked: mark ? Math.round(mark.responseEnd) : null };
    });
    // A paint settles when input or a second has passed with nothing larger.
    await page.waitForTimeout(1000);
    const { lcp, fcp } = await page.evaluate(() => ({ lcp: window.__lcp,
      fcp: performance.getEntriesByName("first-contentful-paint")[0]?.startTime || 0 }));
    return { lcp: Math.round(lcp), fcp: Math.round(fcp), ...row };
  } finally {
    await context.close();
  }
}

const median = (list) => {
  const sorted = [...list].sort((x, y) => x - y);
  return sorted.length ? (sorted[(sorted.length - 1) >> 1] + sorted[sorted.length >> 1]) / 2 : NaN;
};
const browsers = [await launch({ signedOut: true }), await launch({ signedOut: true })];
const rounds = [];
let failed = 0;
try {
  for (const width of WIDTHS) {
    for (let k = 0; k <= ROUNDS; k += 1) {
      const set = SETS[k % SETS.length];
      // Both at once; the first asked by turns.
      const order = k % 2 ? [[1, B], [0, A]] : [[0, A], [1, B]];
      const got = await Promise.all(order.map(([n, site]) => paint(browsers[n], site, set, width)));
      const byName = k % 2 ? { b: got[0], a: got[1] } : { a: got[0], b: got[1] };
      if (k === 0) continue;
      rounds.push({ width: width[0], set, ...byName });
      console.log(`${width[0]} px ${set}: LCP a ${byName.a.lcp} ms, b ${byName.b.lcp} ms; first paint a ${byName.a.fcp} ms, `
        + `b ${byName.b.fcp} ms; built from it a ${byName.a.built}, b ${byName.b.built}`);
    }
  }
} finally {
  await Promise.all(browsers.map((one) => one.close()));
}
const lines = [];
for (const [width] of WIDTHS) {
  const mine = rounds.filter((r) => r.width === width);
  for (const [key, said] of [["lcp", "LCP"], ["fcp", "first paint"]]) {
    const never = mine.filter((r) => !(r.a[key] > 0) || !(r.b[key] > 0)).length;
    const diff = median(mine.map((r) => r.b[key] - r.a[key]));
    const spread = median(mine.map((r) => Math.abs(r.b[key] - r.a[key])));
    // Later beyond the noise: the median difference over 50 ms and over half the rounds' spread.
    const later = diff > Math.max(50, spread / 2);
    failed += never || later ? 1 : 0;
    lines.push(`${later || never ? "FAIL" : "ok  "} ${width} px, ${mine.length} rounds: ${said} a ${median(mine.map((r) => r.a[key]))} ms, `
      + `b ${median(mine.map((r) => r.b[key]))} ms (medians); b - a ${diff} ms at the median, ${spread} ms apart at the median`
      + `${never ? `; ${never} rounds never painted` : ""}`);
  }
}
writeFileSync(`${OUT}/lcp.json`, JSON.stringify({ a: A, b: B, rounds }, null, 1));
writeFileSync(`${OUT}/lcp.txt`, `${lines.join("\n")}\n`);
console.log(lines.join("\n"));
process.exit(failed ? 1 : 0);
