// A page's Largest Contentful Paint in two checkouts, timed at the same
// moments (remixdiff, 2026-11-23; memory same-moment-pairs): is a change
// to the pages the server makes any slower to show?
//
//   node tools/web/page_lcp_pairs.mjs --base=DIR [--rounds=8] [--widths=390,1280]
//       [--pages=/m/CottageB01,/m/CottageA01,/m/DesignAbc1] [--out=DIR] [--world=remix]
//
// DIR is a tree with the base's web/ and api/ (git archive of the branch
// it is to be no worse than); this checkout's are the other arm. Both are
// served as model_page_flow.mjs serves them, every call answered by this
// checkout's design_stand_in.mjs, with --world=remix's cottages
// (remix_world.mjs) added. Each round, each page at each width is opened
// in both arms at once, each in a browser of its own (the second a quarter
// second after the first, which goes first alternating by round), each a
// fresh context (nothing cached), at 4x CPU slowdown for a phone's width:
// the LCP the browser says (buffered PerformanceObserver), read once the
// page has loaded and a second more.
//
// Judged as tools/release/timing_judge.py judges a timing: a page is worse
// only where this arm's mean is past the base's by more than the wider of
// the two arms' spreads (max - min of their rounds) and by 2% of the
// base's mean besides. Prints each round, then each page and width with
// both arms' median, mean and spread; exits 1 if any is worse.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { cottageWorld } from "./remix_world.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const mine = path.resolve(here, "../..");
if (!args.base) {
  console.error("page_lcp_pairs: --base=DIR, a tree with the base's web/ and api/");
  process.exit(2);
}
const base = path.resolve(String(args.base));
const rounds = Number(args.rounds || 8);
const widths = String(args.widths || "390,1280").split(",").map(Number);
const pages = String(args.pages || "/m/CottageB01,/m/CottageA01,/m/DesignAbc1").split(",");
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
if ((args.world || "remix") === "remix") await cottageWorld(stand, path.join(mine, "api"));

const ARMS = [{ name: "base", root: base }, { name: "this", root: mine }];
const browsers = [await launch({ signedOut: true }), await launch({ signedOut: true })];

async function lcp(browser, arm, at, width) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await stand.serveSite(context, { web: path.join(arm.root, "web"), api: path.join(arm.root, "api") });
  const page = await context.newPage();
  await page.addInitScript(() => {
    window.lcpSeen = { at: 0, what: "" };
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        window.lcpSeen = { at: entry.startTime, what: `${entry.element?.tagName || "?"}.${entry.element?.className || ""}`.slice(0, 60) };
      }
    }).observe({ type: "largest-contentful-paint", buffered: true });
  });
  if (phone) {
    const cdp = await context.newCDPSession(page);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
  }
  let seen = null;
  try {
    await page.goto(`${stand.ORIGIN}${at}`, { waitUntil: "load", timeout: 120000 });
    await page.waitForTimeout(1000);
    seen = await page.evaluate(() => window.lcpSeen);
  } catch (trouble) {
    seen = { at: 0, what: `failed: ${String(trouble).split("\n")[0].slice(0, 80)}` };
  }
  await context.close();
  return seen;
}

const times = new Map();
const key = (at, width, arm) => `${at} ${width} ${arm}`;
const lines = [];
for (let round = 0; round < rounds; round += 1) {
  for (const at of pages) {
    for (const width of widths) {
      const order = round % 2 === 0 ? [0, 1] : [1, 0];
      const both = order.map((k, slot) => (async () => {
        if (slot === 1) await new Promise((resolve) => setTimeout(resolve, 250));
        return [k, await lcp(browsers[k], ARMS[k], at, width)];
      })());
      for (const [k, seen] of await Promise.all(both)) {
        const name = ARMS[k].name;
        if (!times.has(key(at, width, name))) times.set(key(at, width, name), []);
        if (seen.at > 0) times.get(key(at, width, name)).push(seen.at);
        const line = `round ${round + 1} ${at} ${width} ${name}${k === order[0] ? " (first)" : ""}: ${Math.round(seen.at)} ms ${seen.what}`;
        lines.push(line);
        console.log(line);
      }
    }
  }
}
await Promise.all(browsers.map((b) => b.close()));

const mean = (xs) => xs.reduce((a, b) => a + b, 0) / Math.max(1, xs.length);
const median = (xs) => { const s = [...xs].sort((a, b) => a - b); return s.length ? s[Math.floor(s.length / 2)] : 0; };
const spread = (xs) => (xs.length ? Math.max(...xs) - Math.min(...xs) : 0);
let worse = 0;
const verdicts = [];
for (const at of pages) {
  for (const width of widths) {
    const a = times.get(key(at, width, "base")) || [];
    const b = times.get(key(at, width, "this")) || [];
    const noise = Math.max(spread(a), spread(b));
    const past = mean(b) - mean(a);
    const bad = a.length < rounds / 2 || b.length < rounds / 2 || (past > noise && past > 0.02 * mean(a));
    if (bad) worse += 1;
    const line = `${bad ? "WORSE" : "ok   "} ${at} ${width}: this ${Math.round(median(b))} ms median (mean ${Math.round(mean(b))}, `
      + `${b.length} rounds), base ${Math.round(median(a))} ms (mean ${Math.round(mean(a))}, ${a.length}); `
      + `${past >= 0 ? "+" : ""}${Math.round(past)} ms against a noise of ${Math.round(noise)} ms`;
    verdicts.push(line);
    console.log(line);
  }
}
if (out) writeFileSync(path.join(out, "lcp_pairs.txt"), `${[...lines, "", ...verdicts].join("\n")}\n`);
console.log(worse ? `page_lcp_pairs: ${worse} worse beyond the noise` : "page_lcp_pairs: no page worse beyond the noise");
process.exit(worse ? 1 : 0);
