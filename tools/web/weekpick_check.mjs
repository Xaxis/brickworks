// The week's pick says only what is true of it, and View in 3D draws on a
// protected preview (weekpick, 2026-11-28).
//
// askaudit saw on rel-m355's preview the gallery call a cactus shared on
// 24 Oct "New this week, and Tested" (the cron kept it as the pick of the
// week of 23 Nov, a quiet week), the home's first post call it "this week's
// pick · 24 Oct", and View in 3D say "the network did not answer": the 3D
// view asked for the site's own scene with credentials "omit", so a
// preview's bypass cookie stayed behind and Vercel's sign-in answered.
//
//   node tools/web/weekpick_check.mjs [--out=DIR] [--web=DIR]           the cases, this checkout's pages (or DIR's)
//   node tools/web/weekpick_check.mjs --url=<deployment> [--out=DIR]    the deployment as a person sees it
//
// With no --url nothing leaves this machine: the pages are this checkout's
// web/ (or --web's, another checkout's, to see the fault there), the API
// design_stand_in.mjs, its pick replaced by each case's, at 1280 and 390:
//   old    shared 24 Oct, nothing done with it this week, Tested: the
//          gallery's card marked Week's pick, its line "Shared 24 Oct, and
//          Tested", never "new this week"; the home's first post marked
//          Week's pick, its head "shared a build · 24 Oct", never "this
//          week's pick"
//   new    shared two days ago, Tested: "New this week, and Tested"
//   fresh  shared two days ago, not Tested: "New this week"
//   built  shared 24 Oct, built twice this week: "Built twice this week"
//   and today's featured model marked "Featured today" only when the cron
//   kept it today, else the day it was featured.
// With --url, a protected preview's own pages and API, in a browser that
// carries the preview's bypass as Vercel's cookie alone (as a person's does
// after the preview's link), never as a header on every request (as the
// other flows send it, which hid this):
//   the pick's line and the home's first post say what the deployment's
//   own shelves say of it (new only when shared in the past seven days);
//   View in 3D on a set's page (6208-1) and on the pick's own page draws
//   the model, at 1280 and 390.
// Pictures in --out. Exits 1 on any FAIL.
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const web = path.resolve(String(args.web || path.join(root, "web")));
const api = path.join(root, "api");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const out = path.resolve(String(args.out || "shots/weekpick"));
mkdirSync(out, { recursive: true });
const WIDTHS = [1280, 390];
const DAY = 24 * 3600 * 1000;

let failed = 0;
let passed = 0;
const t0 = Date.now();
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const until = (page, test, arg, ms = 30000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
const errors = [];

// A person's browser: the bypass (BW_BYPASS) as Vercel's cookie, which
// browser.mjs takes for a preview's host before a page first goes there,
// and no header on any request.
const browser = await launch({ signedOut: true });
async function visit(width) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: "light",
    serviceWorkers: "block", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${width}: ${String(e).slice(0, 200)}`));
  return { context, page };
}

/// What the gallery's front says of its pick and its featured model.
async function galleryFront(page, at) {
  await page.goto(`${at}/gallery`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await until(page, () => document.documentElement.dataset.gallery === "ready" && document.documentElement.dataset.shelves, null, 90000);
  return page.evaluate(() => {
    const card = document.querySelector("#pick:not([hidden]) #pick-card .model");
    const featured = document.querySelector('#spotlight-models [data-slot="featured"]');
    return { pick: card?.dataset.id || "", marks: [...(card?.querySelectorAll(".marks .pill") || [])].map((one) => one.textContent.trim()),
      why: card?.querySelector(".why")?.textContent.trim() || "",
      featured: featured?.querySelector(".marks .pill.new")?.textContent.trim() || "" };
  });
}

/// What the home's first post says, the week's pick where it leads.
async function homeFirst(page, at) {
  await page.goto(`${at}/`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await until(page, () => document.querySelector("article.post.build[data-pick]") || document.querySelectorAll("article.post.build").length > 1, null, 90000);
  return page.evaluate(() => {
    const post = document.querySelector("article.post.build[data-pick]");
    return { pick: post?.dataset.id || "", line: post?.querySelector(".post-line")?.textContent.trim() || "",
      marks: [...(post?.querySelectorAll(".pill") || [])].map((one) => one.textContent.trim()) };
  });
}

async function shot(page, name, selector) {
  const at = selector ? await page.$(selector) : null;
  if (at) await at.scrollIntoViewIfNeeded().catch(() => {});
  await page.screenshot({ path: path.join(out, `${name}.png`) }).catch(() => {});
}

const ago = (days) => new Date(Date.now() - days * DAY).toISOString();
const dayOf = (days) => new Date(Date.now() - days * DAY).toISOString().slice(0, 10);
const today = new Date().toISOString().slice(0, 10);
const year = new Date().getUTCFullYear();
const OLD = "2026-10-24T08:41:00Z";
const oldSaid = new Date(OLD).getUTCFullYear() === year ? "24 Oct" : "24 Oct 2026";

if (!remote) {
  const CASES = [
    { name: "old", listed: OLD, week: { builds: 0, remixes: 0, tested: true, score: 5 }, featured: today,
      why: `Shared ${oldSaid}, and Tested`, label: "Featured today" },
    { name: "new", listed: ago(2), week: { builds: 0, remixes: 0, tested: true, score: 5 }, featured: dayOf(1),
      why: "New this week, and Tested", label: `Featured ${new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", timeZone: "UTC" }).format(Date.now() - DAY)}` },
    { name: "fresh", listed: ago(2), week: { builds: 0, remixes: 0, tested: false, score: 0 }, featured: today,
      why: "New this week", label: "Featured today" },
    { name: "built", listed: OLD, week: { builds: 2, remixes: 0, tested: true, score: 11 }, featured: today,
      why: "Built twice this week", label: "Featured today" },
  ];
  for (const c of CASES) {
    for (const width of WIDTHS) {
      const { context, page } = await visit(width);
      await stand.serveSite(context, { web, api });
      // The shelves as the stand-in answers them, with this case's pick and featured day.
      await context.route((url) => url.pathname === "/api/share" && url.searchParams.get("op") === "shelves", async (route) => {
        const url = new URL(route.request().url());
        const said = stand.apiAnswer({ url: new URL(url.pathname + url.search, stand.ORIGIN), method: "GET", state: {} });
        const json = said.json;
        if (json.pick) json.pick = { ...json.pick, week: c.week, model: { ...json.pick.model, listed_at: c.listed } };
        if (json.featured) json.featured = { ...json.featured, day: c.featured };
        await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(json) });
      });
      const base = stand.ORIGIN;
      const g = await galleryFront(page, base);
      check(g.pick && g.marks[0] === "Week’s pick" && g.why === c.why && (/new this week/i.test(g.why) === /^New/.test(c.why)),
        `${c.name} ${width}: the gallery's pick ${g.pick || "none"} marked ${g.marks.join(" + ") || "nothing"}, its line "${g.why}" (wanted "${c.why}")`);
      check(g.featured === c.label, `${c.name} ${width}: today's featured model marked "${g.featured}" (wanted "${c.label}", kept ${c.featured})`);
      if (c.name === "old") await shot(page, `gallery_old_${width}`, "#pick");
      const h = await homeFirst(page, base);
      // A recent day is said as a time ago once the page is in (web/landing.js): "2 days ago".
      const wantLine = c.listed === OLD ? `shared a build · ${oldSaid}` : "shared a build · 2 days ago";
      check(h.pick && h.marks.includes("Week’s pick") && h.line === wantLine && !/pick/i.test(h.line),
        `${c.name} ${width}: the home's first post ${h.pick || "none"} marked ${h.marks.join(" + ") || "nothing"}, its head "${h.line}" (wanted "${wantLine}")`);
      if (c.name === "old") await shot(page, `home_old_${width}`, "article.post.build[data-pick]");
      await context.close();
    }
  }
} else {
  // The deployment's own shelves, read as its pages read them.
  for (const width of WIDTHS) {
    const { context, page } = await visit(width);
    await page.goto(`${remote}/gallery`, { waitUntil: "domcontentloaded", timeout: 120000 });
    const front = await page.evaluate(async () => {
      const answer = await fetch("/api/share?op=shelves", { headers: { accept: "application/json" } }).catch(() => null);
      return answer && answer.ok ? answer.json() : null;
    });
    const pick = front?.pick;
    const listed = Date.parse(String(pick?.model?.listed_at || ""));
    const quiet = pick && !pick.week?.builds && !pick.week?.remixes;
    const fresh = Number.isFinite(listed) && Date.now() - listed <= 7 * DAY;
    const g = await galleryFront(page, remote);
    check(Boolean(pick) && g.pick === pick.model.id && (!quiet || /new this week/i.test(g.why) === fresh),
      `${width}: the gallery's pick ${g.pick || "none"} (shared ${pick?.model?.listed_at?.slice(0, 10) || "?"}, `
      + `built ${pick?.week?.builds ?? "?"}, remixed ${pick?.week?.remixes ?? "?"} this week): "${g.why}"${quiet ? (fresh ? ", new this week" : ", never new this week") : ""}`);
    await shot(page, `gallery_${width}`, "#pick");
    const h = await homeFirst(page, remote);
    check(h.pick === pick?.model?.id && !/pick/i.test(h.line) && h.marks.includes("Week’s pick"),
      `${width}: the home's first post ${h.pick || "none"} marked ${h.marks.join(" + ") || "nothing"}, its head "${h.line}" (says what its builder did and when, not "this week's pick")`);
    await shot(page, `home_${width}`, "article.post.build[data-pick]");
    // View in 3D: a set's page, and the pick's own page.
    for (const [where, frame] of [[`/library/set/6208-1`, ".set-page .picture"], [`/m/${pick?.model?.id || ""}`, ".model-page .picture"]]) {
      await page.goto(`${remote}${where}`, { waitUntil: "domcontentloaded", timeout: 120000 });
      const ready = await until(page, (sel) => document.querySelector(`${sel} .go`), frame, 60000);
      if (ready) {
        if (width < 600) await page.tap(`${frame} .go`);
        else await page.click(`${frame} .go`);
      }
      const drew = await until(page, () => {
        const b = window.brickworks3d;
        return b && (b.timings.complete3d || b.state === "failed" || b.state === "big");
      }, null, 300000);
      const got = await page.evaluate(() => ({ state: window.brickworks3d?.state || "none", parts: window.brickworks3d?.parts || 0,
        complete: Boolean(window.brickworks3d?.timings?.complete3d), said: document.querySelector(".view3d-said")?.textContent || "" }));
      check(ready && drew && got.complete && got.state !== "failed" && !/could not load/.test(got.said),
        `${width}: View in 3D on ${where}: ${got.state}, ${got.parts} parts${got.complete ? ", drawn whole" : ""}${got.said ? ` ("${got.said.slice(0, 90)}")` : ""}`);
      await shot(page, `view3d_${where.split("/").filter(Boolean).join("_")}_${width}`, frame);
    }
    await context.close();
  }
}

await browser.close();
check(errors.length === 0, `no script error on any page${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""}`);
console.log(failed ? `weekpick: ${failed} FAILED, ${passed} passed`
  : `weekpick: the pick says what is true${remote ? ", View in 3D draws" : ""} (${passed} passed)`);
process.exit(failed ? 1 : 0);
