// Is every page of the site laid out as one site? (listkit, 2026-11-23;
// web/site.css "an inner page": .page-hero, .page-head, .list-layout;
// docs/DESIGN_SYSTEM.md "One page pattern")
//
// flows_for: every page
//
//   node tools/web/layout_audit.mjs [--out=DIR]                 # this checkout's web/ and api/, served here
//   node tools/web/layout_audit.mjs --root=DIR [--out=...]      # another checkout's (an old one, to see it fail)
//   node tools/web/layout_audit.mjs --url=<deployment> [--out=...]   # a deployment's pages, the API answered here
//   [--only=feed,notifications] [--widths=1280,390] [--themes=dark,light]
//
// The owner, 23 Nov: "the 'your feed' page vs the 'your notification' page
// are inconsistent widths and layouts". Every list and signed-in page had
// been built on its own: four page widths, titles from 32 to 172 px under
// the header, three row components, an aside at 300 or 320 px or none.
// This visits every page at 1280 and 390, signed out and signed in, and
// fails, naming the page, on:
//
//   every page: its main container (the first drawn .wrap in <main>) not
//     at the header's left and right edges, within a pixel;
//   a page with the site's head (HEAD below): no .page-hero first in
//     <main> with the h1 in its .page-title; the h1's left not the
//     container's, its top not the pattern's, its size not --t-h1; its
//     tabs (when it has views) not the site's .tabs, their left not the
//     container's, or their top not the pattern's distance under the head;
//   a list page (LIST): no .list-main, its left not the container's or its
//     width not the pattern's; an aside not at the container's right edge.
//
// "The pattern's" is the feed's, drawn at the same width and theme: the
// first page here. Its own h1 is held to the tokens (--t-h1, at the band's
// top plus its padding), so the pattern cannot drift with it.
//
// With no --url nothing leaves this machine: the pages and the API are
// design_stand_in.mjs's (tools/web/site_pages.mjs visit), as design_flow
// serves them. Prints "layout audit: all ok" when every page passes.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { onDeployment, sitePages, until, visit } from "./site_pages.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(String(args.root || path.resolve(here, "../..")));
const web = path.join(root, "web");
const api = path.join(root, "api");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const widths = String(args.widths || "1280,390").split(",").map(Number);
const themes = String(args.themes || "dark").split(",");
const only = args.only ? String(args.only).split(",") : null;
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

// The pages, in the order they are judged: the feed first, the pattern.
// HEAD: the site's head; LIST: and its list layout; EDGES: an object's or
// a landing page (its own head), held to the page's width only.
const HEAD = "head";
const LIST = "list";
const EDGES = "edges";
const listed = new Map(sitePages({ remote }).map((one) => [one.name, one]));
const talkReady = (page) => until(page, () => document.querySelector("main .page-hero h1"));
const PAGES = [
  ["feed", LIST], ["notifications", LIST],
  [{ name: "talk", path: "/talk", ready: talkReady }, LIST],
  [{ name: "talk-board", path: "/talk/b/help", ready: talkReady }, LIST],
  [{ name: "talk-new", path: "/talk/new", ready: talkReady }, HEAD],
  ["lists", HEAD], ["gallery", HEAD], [{ name: "search", path: "/gallery?q=castle" }, HEAD], ["builds", HEAD],
  ["collections", HEAD], [{ name: "library", path: "/library" }, HEAD], ["settings", HEAD],
  ["faq", HEAD], ["terms", HEAD], ["privacy", HEAD], ["guidelines", HEAD], ["changelog", HEAD], ["compare", HEAD],
  ["takedown", HEAD], ["share-model", HEAD],
  ["home", EDGES], ["model", EDGES], ["person", EDGES], ["collection", EDGES], ["challenge", EDGES], ["account", EDGES],
  ["plans", EDGES], ["beta", EDGES], ["download", EDGES],
].map(([one, kind]) => ({ ...(typeof one === "string" ? listed.get(one) : one), kind }))
  .filter((one) => one.name && (!only || only.includes(one.name)));

let passed = 0;
let failed = 0;
const fail = (where, what) => {
  failed += 1;
  console.log(`  FAIL  ${where}: ${what}`);
};

/// The page as laid out: the header's and the container's edges, the band,
/// the head, the h1, the tabs, the list and the aside, in page pixels.
/// Runs in the page.
function layout() {
  const drawn = (el) => Boolean(el) && el.getClientRects().length > 0 && el.getBoundingClientRect().width > 0
    && getComputedStyle(el).visibility !== "hidden";
  const box = (el) => {
    if (!drawn(el)) return null;
    const r = el.getBoundingClientRect();
    return { left: r.left, right: r.right, top: r.top + scrollY, bottom: r.bottom + scrollY, width: r.width };
  };
  const token = (name) => {
    const probe = document.createElement("span");
    probe.style.fontSize = `var(${name})`;
    document.body.append(probe);
    const size = parseFloat(getComputedStyle(probe).fontSize);
    probe.remove();
    return size;
  };
  const px = (name) => {
    const probe = document.createElement("div");
    probe.style.paddingTop = `var(${name})`;
    document.body.append(probe);
    const size = parseFloat(getComputedStyle(probe).paddingTop);
    probe.remove();
    return size;
  };
  const main = document.querySelector("main");
  const container = main?.closest(".wrap") || [...(main?.querySelectorAll(".wrap") || [])].find(drawn) || null;
  const band = main?.querySelector(":scope > .page-hero") || null;
  const first = main ? [...main.children].find(drawn) : null;
  const h1 = [...(main?.querySelectorAll("h1") || [])].find(drawn) || null;
  const tabs = band ? [...band.querySelectorAll(":scope > .wrap > .tabs, :scope > .wrap > .tab-bar > .tabs")].find(drawn) : null;
  const listMain = [...(main?.querySelectorAll(".list-main") || [])].find(drawn) || null;
  const aside = [...(main?.querySelectorAll(".list-aside") || [])].find(drawn) || null;
  return {
    screen: innerWidth,
    header: box(document.querySelector(".site-head > .wrap")),
    container: box(container), containerIs: container ? `.${String(container.className).trim().split(/\s+/).join(".")}` : "",
    band: box(band), bandFirst: Boolean(band) && first === band, bandPad: band ? parseFloat(getComputedStyle(band).paddingTop) : 0,
    head: box(band?.querySelector(":scope > .wrap > .page-head")),
    h1: h1 ? { ...box(h1), size: parseFloat(getComputedStyle(h1).fontSize), inTitle: Boolean(h1.closest(".page-hero .page-title")) } : null,
    want: { h1: token("--t-h1"), pad: px(innerWidth < 600 ? "--s-4" : "--s-6") },
    tabs: box(tabs),
    listMain: box(listMain), aside: box(aside),
  };
}

const near = (a, b) => Math.abs(a - b) <= 1;
const n = (value) => Math.round(value * 10) / 10;

/// What is wrong with [got] against the pattern [want] (the feed's, at
/// this width and theme), as [what, why].
function judge(one, got, want) {
  const found = [];
  const { header, container } = got;
  if (!container) return [["the page", "has no .wrap in <main>"]];
  if (header && !(near(header.left, container.left) && near(header.right, container.right))) {
    found.push(["the page", `is ${n(container.left)} to ${n(container.right)} px (main ${got.containerIs}), not the header's ${n(header.left)} to ${n(header.right)}`]);
  }
  if (one.kind === EDGES) return found;
  // Each fault is named and the page measured on past it, so a page drawn
  // its own way says how far it is off, not only that it is.
  const band = got.band && got.bandFirst;
  if (!band) found.push(["its head", "is not the site's (.page-hero first in <main>)"]);
  if (!got.h1) return [...found, ["the page", "has no h1"]];
  if (!got.h1.inTitle) found.push(["its h1", "is not in the head's .page-title"]);
  if (!near(got.h1.left, container.left)) found.push(["its h1", `starts at ${n(got.h1.left)} px, not the page's edge at ${n(container.left)}`]);
  if (Math.abs(got.h1.size - got.want.h1) > 0.25) found.push(["its h1", `is ${n(got.h1.size)} px, not --t-h1's ${n(got.want.h1)}`]);
  // The tokens, whatever the feed does: the head padded --s-6 (--s-4 on a
  // phone) over the h1, and the h1 the first thing in it.
  if (band && !near(got.bandPad, got.want.pad)) found.push(["its head", `is padded ${n(got.bandPad)} px over the title, not ${n(got.want.pad)}`]);
  if (band && !near(got.h1.top - got.band.top, got.want.pad)) {
    found.push(["its h1", `is ${n(got.h1.top - got.band.top)} px under the head's top, not the padding's ${n(got.want.pad)}`]);
  }
  if (want?.h1) {
    if (!near(got.h1.top, want.h1.top)) found.push(["its h1", `is ${n(got.h1.top)} px down the page, the feed's at ${n(want.h1.top)}`]);
    if (got.tabs && want.tabs && got.head && want.head
      && !near(got.tabs.top - got.head.bottom, want.tabs.top - want.head.bottom)) {
      found.push(["its tabs", `are ${n(got.tabs.top - got.head.bottom)} px under its head, the feed's ${n(want.tabs.top - want.head.bottom)}`]);
    }
  }
  if (got.tabs && !near(got.tabs.left, container.left)) found.push(["its tabs", `start at ${n(got.tabs.left)} px, not the page's edge at ${n(container.left)}`]);
  if (one.kind !== LIST) return found;
  if (!got.listMain) return [...found, ["its list", "is not the site's (.list-layout > .list-main)"]];
  if (!near(got.listMain.left, container.left)) found.push(["its list", `starts at ${n(got.listMain.left)} px, not the page's edge at ${n(container.left)}`]);
  if (want?.listMain && !near(got.listMain.width, want.listMain.width) && !(got.aside && got.screen < 900)) {
    found.push(["its list", `is ${n(got.listMain.width)} px wide, the pattern's ${n(want.listMain.width)}`]);
  }
  if (got.aside && got.screen >= 900 && !near(got.aside.right, container.right)) {
    found.push(["its aside", `ends at ${n(got.aside.right)} px, not the page's edge at ${n(container.right)}`]);
  }
  return found;
}

console.log(`layout audit: ${remote || `${root} (its web/ and api/, served here)`}`);
const remoteDb = remote ? await onDeployment(PAGES, remote, headers) : "";
const browser = await launch({ signedOut: true });
const patterns = new Map();
let pages = 0;
try {
  for (const width of widths) {
    for (const theme of themes) {
      for (const one of PAGES) {
        if (one.skip || (remote && one.local)) continue;
        for (const signedIn of one.signedInOnly ? [true] : [false, true]) {
          const who = signedIn ? "in" : "out";
          const label = `${one.name} ${width} ${theme} ${who}`;
          const context = await visit(browser, one, { width, theme, signedIn, web, api, remote, headers, remoteDb });
          const page = await context.newPage();
          try {
            await page.goto(base + one.path, { waitUntil: "load", timeout: 60000 });
            if (one.ready && !(await one.ready(page, { width, signedIn }))) console.log(`  --    ${label}: did not finish drawing; judged as it is`);
            await page.evaluate(() => document.fonts.ready);
            await page.waitForTimeout(300);
            const got = await page.evaluate(layout);
            pages += 1;
            const key = `${width} ${theme} ${who}`;
            // The pattern: the feed's, held to the tokens like every page.
            if (one.name === "feed" && !patterns.has(key)) patterns.set(key, got);
            const found = judge(one, got, patterns.get(key) || patterns.get(`${width} ${theme} out`));
            for (const [what, why] of found) fail(label, `${what} ${why}`);
            if (!found.length) {
              passed += 1;
              console.log(`  ok    ${label}: page ${n(got.container.left)}-${n(got.container.right)}${got.h1 && one.kind !== EDGES
                ? `, h1 at ${n(got.h1.left)},${n(got.h1.top)}${got.tabs ? `, tabs at ${n(got.tabs.top)}` : ""}` : ""}`);
            }
            if (out) {
              await page.screenshot({ path: path.join(out, `${one.name}_${width}_${theme}_${who}.png`), fullPage: false })
                .catch(() => {});
            }
          } catch (trouble) {
            fail(label, `could not be visited: ${String(trouble).split("\n")[0]}`);
          } finally {
            await context.close();
          }
        }
      }
    }
  }
} finally {
  await browser.close();
}
console.log(`\nlayout audit: ${pages} pages, ${passed} ok, ${failed} failed`);
if (!pages) {
  console.log("layout audit: no page was judged");
  process.exit(1);
}
if (!failed) console.log("layout audit: all ok");
process.exit(failed ? 1 : 0);
