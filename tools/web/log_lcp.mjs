// A model's page with its Log against the page before it, at the same
// moment: its largest paint (LCP), at 390 and 1280 px in light and dark
// (2026-11-23, unit buildlog; api/share.js versionsSection).
//
//   node tools/web/log_lcp.mjs --base=DIR [--rounds=8] [--out=DIR]
//
// DIR holds the tree before (its web/ and api/, as `git archive` gives
// them, with node_modules and assets linked in from this checkout). Both
// are served by the design stand-in (tools/web/design_stand_in.mjs
// serveSite), the watchtower's page (/m/DesignAbc1, two versions) asked of
// each in a browser of its own at once, a round at a time, the one asked
// first turn about: a box under load slows both alike (memory
// same-moment-pairs), and the medians are compared. A difference within the
// rounds' own spread is noise; worse than both the spread and 10% fails.
// With the newest version said to be work in progress (the stand-in's
// versions answered with wip), as this tree reads it; the tree before
// leaves it out, as it always did.
//
// Pictures of the Log at each size and theme, this tree's, in --out.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const base = path.resolve(String(args.base || ""));
if (!args.base) throw new Error("--base=DIR: the tree before, its web/ and api/");
const rounds = Number(args.rounds || 8);
const out = path.resolve(String(args.out || "shots/log_lcp"));
mkdirSync(out, { recursive: true });

// The newest version said to be work in progress, as supabase/wip.sql
// keeps it: every share_versions answer, for both trees (the one before
// never reads it). Wrapped over the stand-in's own fetch, which its first
// page puts in place.
await stand.serverPage(path.join(root, "api"), `/m/${stand.MODEL_ID}`);
const real = globalThis.fetch;
globalThis.fetch = async (input, init) => {
  const url = String(input?.url || input);
  const answer = await real(input, init);
  if (!/\/rest\/v1\/share_versions\?/.test(url) || !answer.ok) return answer;
  const rows = await answer.clone().json().catch(() => null);
  if (!Array.isArray(rows)) return answer;
  const newest = Math.max(0, ...rows.map((row) => Number(row.n) || 0));
  return new Response(JSON.stringify(rows.map((row) => (row.n === newest ? { ...row, wip: true, finished_at: null } : row))),
    { status: answer.status, headers: { "content-type": "application/json" } });
};

const browser = await launch({ signedOut: true });
const trees = { before: base, after: root };

async function contextOf(tree, width, dark) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: dark ? "dark" : "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await context.addInitScript((theme) => {
    try { localStorage.setItem("brickworks.theme", theme); } catch {}
  }, dark ? "dark" : "light");
  await stand.serveSite(context, { web: path.join(trees[tree], "web"), api: path.join(trees[tree], "api"), state: {} });
  return context;
}

/// One visit's largest paint, in ms from the navigation's start.
async function visit(context) {
  const page = await context.newPage();
  await page.addInitScript(() => {
    window.__lcp = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) window.__lcp = Math.max(window.__lcp, entry.startTime);
    }).observe({ type: "largest-contentful-paint", buffered: true });
  });
  await page.goto(`${stand.ORIGIN}/m/${stand.MODEL_ID}`, { waitUntil: "load", timeout: 120000 });
  await page.waitForTimeout(2500);
  const lcp = await page.evaluate(() => window.__lcp);
  return { page, lcp };
}

const median = (list) => {
  const sorted = [...list].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
};
const spread = (list) => {
  const sorted = [...list].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length * 0.75)] - sorted[Math.floor(sorted.length * 0.25)];
};

let failed = 0;
const results = [];
for (const width of [390, 1280]) {
  for (const dark of [false, true]) {
    const theme = dark ? "dark" : "light";
    const contexts = { before: await contextOf("before", width, dark), after: await contextOf("after", width, dark) };
    const times = { before: [], after: [] };
    for (let n = 0; n < rounds + 1; n++) {
      // Both at once, the one asked first turn about.
      const order = n % 2 ? ["after", "before"] : ["before", "after"];
      const seen = await Promise.all(order.map((tree) => visit(contexts[tree])));
      for (const [k, tree] of order.entries()) {
        // The first round warms both (the stand-in's modules, the fonts).
        if (n > 0) times[tree].push(seen[k].lcp);
        if (n === rounds && tree === "after") {
          const log = await seen[k].page.evaluate(() => {
            const section = document.getElementById("versions");
            section?.scrollIntoView();
            return { entries: document.querySelectorAll(".earlier.log li.log-entry").length,
              wip: Boolean(document.querySelector(".wip-line")), wide: document.documentElement.scrollWidth - window.innerWidth };
          });
          await seen[k].page.waitForTimeout(400);
          await seen[k].page.screenshot({ path: path.join(out, `log_${width}_${theme}.png`) });
          results.push({ width, theme, log });
          if (!(log.entries === 2 && log.wip && log.wide <= 0)) {
            failed += 1;
            console.log(`  FAIL  ${width} px ${theme}: the Log ${JSON.stringify(log)}`);
          }
        }
      }
      for (const one of seen) await one.page.close();
    }
    const said = { width, theme, before: median(times.before), after: median(times.after),
      spread: Math.max(spread(times.before), spread(times.after)), times };
    const worse = said.after - said.before;
    const ok = worse <= Math.max(said.spread, said.before * 0.1);
    if (!ok) failed += 1;
    console.log(`  ${ok ? "ok  " : "FAIL"}  ${width} px ${theme}: LCP ${said.after.toFixed(0)} ms with the Log, `
      + `${said.before.toFixed(0)} ms before (spread ${said.spread.toFixed(0)} ms, ${rounds} rounds)`);
    results.push(said);
    for (const context of Object.values(contexts)) await context.close();
  }
}
await browser.close();
writeFileSync(path.join(out, "log_lcp.json"), JSON.stringify(results, null, 1));
console.log(failed ? `${failed} FAILED` : "the Log draws at every size and theme, its page's largest paint no worse beyond the noise");
process.exit(failed ? 1 : 0);
