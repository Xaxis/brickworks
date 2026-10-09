// Does the landing page hold together in a browser?
//
//   node tools/web/landing_check.mjs --url=https://brickworks.diy
//   node tools/web/landing_check.mjs --file=web/index.html
//
// The deploy asked the landing page for its status code and nothing
// else, so it could only catch a page that was missing. What it missed
// for as long as the page has existed: five header links are 405px wide
// in a 358px bar and the nav does not wrap, so on a phone the document
// came out 566px wide and the whole page scrolled sideways. A status
// code cannot see that. A browser at 390px can.
import { launch } from "./browser.mjs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const target = args.url || ("file://" + resolve(args.file || "web/index.html"));
const bypass = process.env.VERCEL_BYPASS;

const browser = await launch();
const problems = [];

// A phone first, because that is where it was broken, then a laptop.
for (const [label, width, height] of [["phone", 390, 844], ["laptop", 1280, 900]]) {
  const page = await browser.newPage({ viewport: { width, height } });
  if (bypass) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  const response = await page.goto(target, { waitUntil: "load", timeout: 45000 });
  if (response && !response.ok()) {
    problems.push(`${label}: the page answered ${response.status()}`);
    await page.close();
    continue;
  }

  const seen = await page.evaluate(() => {
    const doc = document.documentElement;
    const wide = [];
    for (const el of document.querySelectorAll("body *")) {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.right > doc.clientWidth + 1) {
        wide.push(el.tagName.toLowerCase()
          + (el.className ? "." + String(el.className).split(" ")[0] : ""));
      }
    }
    return {
      scrollW: doc.scrollWidth,
      clientW: doc.clientWidth,
      wide: [...new Set(wide)].slice(0, 4),
      // The one thing every visitor must be able to do.
      intoTheApp: [...document.querySelectorAll('a[href="/app"]')]
        .filter((a) => a.getBoundingClientRect().width > 0).length,
      h1: (document.querySelector("h1") || {}).textContent || "",
    };
  });

  if (seen.scrollW > seen.clientW + 1) {
    problems.push(`${label}: the page scrolls sideways — ${seen.scrollW}px of `
      + `content in ${seen.clientW}px, from ${seen.wide.join(", ") || "something"}`);
  }
  if (seen.intoTheApp < 1) {
    problems.push(`${label}: nothing visible links to /app`);
  }
  if (!seen.h1.trim()) {
    problems.push(`${label}: no heading`);
  }
  console.log(`  ${label.padEnd(7)} ${seen.scrollW}px in ${seen.clientW}px, `
    + `${seen.intoTheApp} way${seen.intoTheApp === 1 ? "" : "s"} into the app`);
  await page.close();
}

await browser.close();
if (problems.length) {
  for (const p of problems) console.log(`  FAIL  ${p}`);
  process.exit(1);
}
console.log("  the landing page holds together");
