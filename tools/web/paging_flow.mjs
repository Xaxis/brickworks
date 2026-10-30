// The site's one pager (web/pager.js, site.css .pager) on two lists, as a
// person pages them: the LDraw library, which its page draws from the API's
// JSON, and a person's models, which the server draws and the next page of
// which is read from its own HTML (site357; the owner, 2026-10-29: "a
// consistent best practice pagination system").
//
//   node --env-file=.env tools/web/relay_server.mjs 8890 &
//   node tools/web/paging_flow.mjs --url=http://127.0.0.1:8890 [--out=DIR]
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/paging_flow.mjs --url=<preview> [--out=DIR]
//   [--profile=/u/brickworks]   a person with more than two pages of models
//                                (49 in the live database: the third has one)
//
// On each list, at 1280 x 900 (and the pager's fit at 390 x 844):
//   1. page 1: 24 cards, the count ("Showing 1–24 of N"), Show more, the
//      numbered links with page 1 current, and a server page's <link
//      rel="next">; scrolled to the foot and left there, nothing comes by
//      itself;
//   2. Show more, from the keyboard: 48 cards, none twice, the address
//      ?page=2, the keyboard on the first new card, a screen reader told
//      "24 more ..."; pressed while that page is still on its way (made
//      slow here), the press is kept and the page drawn when it comes
//      (#81), with skeletons in its place meanwhile;
//   3. the address opened afresh at ?page=3: that page alone, Show earlier
//      over it, which puts page 2 back above it with the keyboard on its
//      first card, the address still ?page=3;
//   4. Back from a card of page 2: pages 1 and 2 again, and the card within
//      100 px of where it was;
//   5. a numbered link is a real link: page 1's opens the list's first page;
//   6. at 390 the pager fits: nothing sideways, Previous and Next as their
//      arrows, the numbers far from the current one left out.
// Pictures in --out: <list>_<step>.png.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "");
if (!site) {
  console.error("paging_flow: --url=<site>");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/paging"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

// The two lists: where each is, its cards, how it says it is drawn, and
// the request that brings its page n (to slow it down).
const LISTS = [
  { name: "library", address: "/library", noun: "sets", ready: () => document.documentElement.dataset.library === "ready",
    asks: (n) => (url) => url.pathname === "/api/share" && url.searchParams.get("op") === "library"
      && url.searchParams.get("page") === String(n) },
  { name: "profile", address: String(args.profile || "/u/brickworks"), noun: "models", server: true,
    ready: () => Boolean(document.querySelector("#models .model")),
    asks: (n) => (url) => url.pathname.startsWith("/u/") && url.searchParams.get("page") === String(n) },
];

let failed = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const problems = [];
const browser = await launch({ signedOut: true });

async function visit(address, { width = 1280 } = {}) {
  const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, extraHTTPHeaders: headers,
    isMobile: width < 600, hasTouch: width < 600 });
  const page = await context.newPage();
  page.on("pageerror", (e) => problems.push(`${address}: ${String(e).slice(0, 200)}`));
  await page.goto(`${site}${address}`, { waitUntil: "load", timeout: 120000 });
  return { context, page };
}

async function until(page, test, arg = null, ms = 30000) {
  try {
    await page.waitForFunction(test, arg, { timeout: ms, polling: 100 });
    return true;
  } catch {
    return false;
  }
}

/// What the list and its pager say now.
const seen = (page) => page.evaluate(() => {
  const nav = document.querySelector("nav.pager[data-pager]");
  const list = document.getElementById(nav?.dataset.pager || "models");
  const cards = [...(list?.children || [])].filter((one) => !one.classList.contains("skeleton"));
  const focus = document.activeElement;
  const box = (el) => el && !el.closest("[hidden]") ? el.getBoundingClientRect() : null;
  return {
    ids: cards.map((one) => one.dataset.id),
    bones: list ? list.querySelectorAll(".skeleton").length : 0,
    count: nav?.querySelector(".pager-count")?.hidden ? "" : nav?.querySelector(".pager-count")?.textContent || "",
    more: Boolean(box(nav?.querySelector(".pager-more"))),
    moreHref: nav?.querySelector(".pager-more")?.getAttribute("href") || "",
    earlier: Boolean(box(document.querySelector("[data-pager-earlier] a"))),
    earlierHref: document.querySelector("[data-pager-earlier] a")?.getAttribute("href") || "",
    numbers: [...(nav?.querySelectorAll(".pager-pages li:not(.step) a") || [])].map((a) => a.textContent),
    current: nav?.querySelector('.pager-pages [aria-current="page"]')?.textContent || "",
    next: nav?.querySelector('.pager-pages a[rel="next"]')?.getAttribute("href") || "",
    said: nav?.querySelector("[data-pager-said]")?.textContent || "",
    // The card the keyboard is on, and where it is in the list.
    focused: focus && list?.contains(focus) ? cards.findIndex((one) => one.contains(focus)) : -1,
    address: location.pathname + location.search,
    links: [...document.querySelectorAll('head link[rel="prev"], head link[rel="next"]')].map((l) => `${l.rel} ${l.getAttribute("href")}`),
    sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    back: document.documentElement.dataset.back || "",
  };
});

const shot = (page, name) => page.screenshot({ path: path.join(out, name) });
const pageOf = (address) => Number(new URL(address, site).searchParams.get("page") || "1");
const said = (n) => n.toLocaleString("en-US");

try {
  for (const list of LISTS) {
    console.log(`${list.name}: ${list.address}`);
    let back = null;
    // How many the list has, as its count says; up to page n, and on it.
    let total = 0;
    const upTo = (n) => Math.min(total, n * 24);
    const on = (n) => upTo(n) - upTo(n - 1);
    // 1-2. Page 1, then Show more.
    {
      const { context, page } = await visit(list.address);
      await until(page, list.ready);
      let now = await seen(page);
      total = Number((/of ([\d,]+)/.exec(now.count)?.[1] || "0").replace(/,/g, ""));
      check(now.ids.length === 24 && /^Showing 1–24 of [\d,]+ /.test(now.count) && total > 48
        && now.more && now.current === "1" && pageOf(now.next) === 2 && !now.earlier,
        `page 1: ${now.ids.length} cards, "${now.count}", Show more ${now.more ? "shown" : "MISSING"}, `
        + `pages ${now.numbers.join(" ")} with ${now.current} current, Next to ${now.next}`);
      if (list.server) check(now.links.join(", ") === `next ${now.next}`, `its head links the next page: ${now.links.join(", ") || "none"}`);
      await page.evaluate(() => scrollTo({ top: document.documentElement.scrollHeight, behavior: "instant" }));
      await page.waitForTimeout(1500);
      now = await seen(page);
      check(now.ids.length === 24 && pageOf(now.address) === 1,
        `scrolled to the foot and left there: still ${now.ids.length} cards, ${now.address}`);
      await shot(page, `${list.name}_1_foot.png`);
      // From the keyboard: Show more focused, Enter.
      await page.focus(".pager-more");
      await page.keyboard.press("Enter");
      await until(page, () => document.querySelector("[data-pager-said]")?.textContent.includes("more"));
      now = await seen(page);
      check(now.ids.length === 48 && new Set(now.ids).size === 48 && pageOf(now.address) === 2 && now.focused === 24
        && now.said === `24 more ${list.noun}` && /^Showing 1–48 of /.test(now.count),
        `Show more: ${now.ids.length} cards, ${new Set(now.ids).size} different, ${now.address}, the keyboard on card `
        + `${now.focused + 1}, told "${now.said}", "${now.count}"`);
      // Pressed while page 3 is on its way: held 1.5 s, the press kept.
      await page.route((url) => list.asks(3)(url), async (route) => {
        await new Promise((done) => setTimeout(done, 1500));
        await route.continue();
      });
      await page.click(".pager-more");
      await page.waitForTimeout(200);
      const waiting = await seen(page);
      const came = await until(page, (shown) => [...document.querySelectorAll("nav.pager")].some((nav) =>
        (nav.querySelector(".pager-count")?.textContent || "").includes(`–${shown} `)), said(upTo(3)), 15000);
      now = await seen(page);
      check(waiting.bones > 0 && came && now.ids.length === upTo(3) && pageOf(now.address) === 3,
        `pressed while page 3 was on its way: ${waiting.bones} skeletons meanwhile, then ${now.ids.length} cards, ${now.address}`);
      await page.unroute((url) => list.asks(3)(url));
      await shot(page, `${list.name}_2_more.png`);
      // Back from a card of page 2: its place kept.
      const id = now.ids[30];
      const card = `[data-id="${id}"]`;
      await page.locator(card).scrollIntoViewIfNeeded();
      await page.evaluate(() => scrollBy(0, -150));
      await page.waitForTimeout(300);
      const top = await page.evaluate((sel) => Math.round(document.querySelector(sel).getBoundingClientRect().top), card);
      back = { id, top, address: now.address, card };
      // Kept out of the back-forward cache, which would hand the page back
      // as it was: the pager itself puts the pages back.
      await page.evaluate(() => addEventListener("unload", () => {}));
      const listPath = new URL(list.address, site).pathname;
      await Promise.all([page.waitForURL((url) => url.pathname !== listPath, { timeout: 30000 }),
        page.click(`${card} a.open`)]);
      await page.waitForTimeout(500);
      await page.goBack({ waitUntil: "load" });
      await until(page, (wanted) => document.documentElement.dataset.back === wanted, id, 30000);
      await page.waitForTimeout(400);
      now = await seen(page);
      const at = await page.evaluate((sel) => Math.round(document.querySelector(sel)?.getBoundingClientRect().top ?? 1e9), card);
      const how = await page.evaluate(() => performance.getEntriesByType("navigation")[0]?.type || "");
      check(now.ids.length === upTo(3) && now.back === id && Math.abs(at - top) <= 100 && now.address === back.address,
        `Back from card 31 (${how}, put back by the pager: ${now.back === id ? "yes" : `NO, "${now.back}"`}): `
        + `${now.ids.length} cards again, the card at ${at} px (was ${top}), ${now.address}`);
      await context.close();
    }
    // 3. A page opened by its address, and Show earlier.
    {
      const address = `${list.address}${list.address.includes("?") ? "&" : "?"}page=3`;
      const { context, page } = await visit(address);
      await until(page, list.ready);
      let now = await seen(page);
      const from = on(3) === 1 ? said(49) : `49–${said(upTo(3))}`;
      check(now.ids.length === on(3) && now.earlier && pageOf(now.earlierHref) === 2 && now.count.startsWith(`Showing ${from} of `)
        && now.current === "3",
        `${address} opened afresh: ${now.ids.length} cards, Show earlier ${now.earlier ? `to ${now.earlierHref}` : "MISSING"}, "${now.count}"`);
      if (list.server) {
        const after = total > 72;
        check(now.links.length === (after ? 2 : 1) && pageOf(now.links[0].split(" ")[1]) === 2
          && (!after || pageOf(now.links[1].split(" ")[1]) === 4), `its head links the pages either side: ${now.links.join(", ")}`);
      }
      const first = now.ids[0];
      await page.click("[data-pager-earlier] a");
      await until(page, () => document.querySelector("[data-pager-said]")?.textContent.includes("earlier"));
      now = await seen(page);
      check(now.ids.length === 24 + on(3) && now.ids[24] === first && now.focused === 0 && pageOf(now.address) === 3
        && now.said === `24 earlier ${list.noun}` && now.count.startsWith(`Showing 25–${said(upTo(3))} of `),
        `Show earlier: ${now.ids.length} cards, page 3's after page 2's, the keyboard on card ${now.focused + 1}, `
        + `"${now.said}", "${now.count}", ${now.address}`);
      await shot(page, `${list.name}_3_earlier.png`);
      // 5. A numbered link is a real link.
      const one = await page.$('.pager-pages a[aria-label="Page 1"]');
      if (one) {
        await Promise.all([page.waitForURL((url) => !url.searchParams.has("page"), { timeout: 30000 }), one.click()]);
        await until(page, list.ready);
        await page.waitForTimeout(500);
        now = await seen(page);
        check(now.ids.length === 24 && now.current === "1" && !now.earlier, `page 1's number opens ${now.address}: ${now.ids.length} cards`);
      } else {
        check(false, "page 1's number is there to follow");
      }
      await context.close();
    }
    // 6. On a phone.
    {
      const address = `${list.address}${list.address.includes("?") ? "&" : "?"}page=2`;
      const { context, page } = await visit(address, { width: 390 });
      await until(page, list.ready);
      await page.locator("nav.pager").scrollIntoViewIfNeeded();
      const fit = await page.evaluate(() => {
        const nav = document.querySelector("nav.pager");
        const shown = [...nav.querySelectorAll(".pager-pages li")].filter((li) => getComputedStyle(li).display !== "none");
        // A row more for each that starts under the first one's foot.
        const foot = shown[0].getBoundingClientRect().bottom;
        return { rows: 1 + shown.filter((li) => li.getBoundingClientRect().top >= foot).length, words: [...nav.querySelectorAll(".step .words")].map((w) => w.getBoundingClientRect().width),
          right: Math.max(...shown.map((li) => li.getBoundingClientRect().right)) };
      });
      const now = await seen(page);
      check(!now.sideways && fit.rows === 1 && fit.right <= 390 && fit.words.every((w) => w <= 1),
        `at 390: nothing sideways, the numbers in ${fit.rows} row to ${Math.round(fit.right)} px, Previous and Next as arrows`);
      await shot(page, `${list.name}_6_phone.png`);
      await context.close();
    }
  }
} catch (trouble) {
  check(false, `the flow ran to its end (${String(trouble?.message || trouble).slice(0, 300)})`);
} finally {
  await browser.close();
}
check(problems.length === 0, `no script error on the pages${problems.length ? `: ${problems.join("; ")}` : ""}`);
console.log(failed ? `paging_flow: ${failed} failed` : "paging_flow: all passed");
process.exit(failed ? 1 : 0);
