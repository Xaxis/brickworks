// The gallery as one page to browse (browse, 2026-11-02; the owner: "one is
// just a tab in another... they should be like filters too, not loading
// actual separate pages"): Top, New, Builds, Collections and Sets are tabs
// of one page (web/gallery.html, web/gallery.js) that switch in place, each
// at its own address (/gallery, /gallery?sort=newest, /builds, /collections,
// /library), against a deployment.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/browse_flow.mjs --url=<preview> --out=DIR
//
//   1. At 1280 px, /gallery, then each tab by a click: no new document (a
//      mark left on window is still there, and one navigation entry), the
//      address the tab's own, the header, the search box, the tab row, the
//      bar of filters and the grid the same elements, the tab marked, the
//      top nav's Gallery marked and no Library in it, and its first cards
//      the ones its list answers for the same question (its API asked
//      directly, the old page's source).
//   2. Back and Forward: Sets scrolled down, then Top; Back is Sets again
//      at its scroll, Forward Top again.
//   3. One search box: "castle" typed on Top asks the models; Sets then
//      keeps the words and asks the sets (/library?q=castle), its first
//      cards the library's for "castle".
//   4. A reload of each tab's address shows that tab.
//   5. The old addresses: /library, /library?theme=Town, /builds,
//      /collections and /de/library answer 200 with their own canonical
//      link and hreflang alternates, and open on their tab (in German for
//      /de/library).
//   6. At 390 px, in English and German: the tab row scrolls inside itself
//      or fits, every tab reachable whole, the page never sideways; each
//      tab switched to in place.
//
// Pictures in --out: <tab>_<width>_<lang>.png of the window, and
// <tab>_<width>_<lang>_scrolled.png a screen down.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("browse_flow: --url=<deployment>");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/browse"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const CANONICAL = "https://brickworks.diy";

// Each tab: its address's path and what it asks, and where its list comes
// from (what its old page drew).
const TABS = {
  top: { path: "/gallery", sort: null, api: (q) => `/api/share?op=list&sort=top&page=1${q ? `&q=${encodeURIComponent(q)}` : ""}`,
    ids: (body) => (body.models || []).map((one) => String(one.id)) },
  new: { path: "/gallery", sort: "newest", api: (q) => `/api/share?op=list&sort=newest&page=1${q ? `&q=${encodeURIComponent(q)}` : ""}`,
    ids: (body) => (body.models || []).map((one) => String(one.id)) },
  builds: { path: "/builds", api: () => "/api/people?op=builds&page=1", ids: (body) => (body.photos || []).map((one) => String(one.id)) },
  collections: { path: "/collections", api: () => "/api/people?op=collections&page=1",
    ids: (body) => (body.collections || []).map((one) => String(one.id)) },
  sets: { path: "/library", api: (q) => `/api/share?op=library&page=1${q ? `&q=${encodeURIComponent(q)}&sort=match` : ""}`,
    ids: (body) => (body.models || []).map((one) => String(one.id)) },
};

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const problems = [];

const browser = await launch({ signedOut: true });
async function context(width) {
  return browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, extraHTTPHeaders: headers,
    isMobile: width < 600, hasTouch: width < 600 });
}
async function opened(made, address) {
  const page = await made.newPage();
  page.on("pageerror", (e) => problems.push(`${address}: ${String(e).slice(0, 200)}`));
  const said = await page.goto(`${site}${address}`, { waitUntil: "load", timeout: 120000 }).catch(() => null);
  return { page, status: said?.status() };
}
/// Whether [test] in the page comes true within [seconds].
async function until(page, test, arg = null, seconds = 30) {
  try {
    await page.waitForFunction(test, arg, { timeout: seconds * 1000, polling: 250 });
    return true;
  } catch {
    return false;
  }
}
/// The tab [which] drawn: the page says so, and its list has come.
const shown = (page, which, seconds = 20) => until(page, (tab) => document.documentElement.dataset.tab === tab
  && document.documentElement.dataset.browse === "ready", which, seconds);
/// The ids of the first [n] cards of the grid, in order.
const firstCards = (page, n = 8) => page.$$eval("#models > .model, #pick-card .model", (all, most) =>
  all.map((one) => one.dataset.id).filter(Boolean).slice(0, most), n).catch(() => []);
/// What the tab's own list answers, asked directly.
async function listed(which, q = "") {
  const reply = await fetch(`${site}${TABS[which].api(q)}`, { headers: { accept: "application/json", ...headers } }).catch(() => null);
  if (!reply || reply.status !== 200) return null;
  const body = await reply.json().catch(() => null);
  return body ? { ids: TABS[which].ids(body), body } : null;
}
/// Whether the address is the tab's own.
function addressed(which, href) {
  const at = new URL(href);
  const tab = TABS[which];
  if (at.pathname.replace(/^\/(de|fr|es)(?=\/)/, "") !== tab.path) return false;
  if ("sort" in tab) return (at.searchParams.get("sort") || null) === tab.sort && at.searchParams.get("following") !== "1";
  return true;
}
/// Leaves a mark on the window and on the page's parts, to find again.
const mark = (page) => page.evaluate(() => {
  const at = (selector) => document.querySelector(selector);
  window.__browse = { mark: Math.random(), head: at(".site-head"), q: at("#q"), tabs: at("#tabs"), bar: at("#toolbar"),
    grid: at("#models") };
  return window.__browse.mark;
}).catch(() => 0);
/// What of the marks is still there: the same window, and each part the same element.
const marks = (page) => page.evaluate(() => {
  const was = window.__browse;
  if (!was) return { mark: 0 };
  const at = (selector) => document.querySelector(selector);
  return { mark: was.mark, same: ["head", "q", "tabs", "bar", "grid"].filter((k) => was[k] && was[k] === at({
    head: ".site-head", q: "#q", tabs: "#tabs", bar: "#toolbar", grid: "#models" }[k])),
  navigations: performance.getEntriesByType("navigation").length };
}).catch(() => ({ mark: 0 }));
/// Clicks the tab [which], as a person does.
async function press(page, which) {
  const tab = page.locator(`#tabs [data-tab="${which}"]`);
  if (!(await tab.count())) return false;
  await tab.first().click({ timeout: 10000 }).catch(() => {});
  return true;
}
const current = (page) => page.$$eval("#tabs [aria-current]", (all) => all.map((one) => one.dataset.tab || one.textContent.trim()))
  .catch(() => []);

try {
  console.log(`browse: ${site}`);

  // 1. Each tab in place, at 1280 px.
  {
    const made = await context(1280);
    const { page, status } = await opened(made, "/gallery");
    check("/gallery answers 200", status === 200);
    check("/gallery opens on Top", await shown(page, "top"));
    const nav = await page.$$eval(".site-head .nav a", (all) => all.map((one) => ({ href: one.getAttribute("href"),
      current: one.getAttribute("aria-current") === "page" })));
    check("the top nav's Gallery is marked", nav.some((one) => one.href === "/gallery" && one.current));
    check("the top nav has no Library", !nav.some((one) => one.href === "/library"));
    const first = await mark(page);
    for (const which of ["new", "builds", "collections", "sets", "top"]) {
      const before = page.url();
      if (!check(`${which}: a tab in the row`, await press(page, which))) continue;
      const drawn = await shown(page, which);
      check(`${which}: drawn`, drawn);
      const kept = await marks(page);
      check(`${which}: no new document (the window's mark kept, ${kept.navigations ?? "?"} navigation)`,
        kept.mark === first && kept.navigations === 1);
      check(`${which}: the header, search, tab row, bar of filters and grid the same elements (${(kept.same || []).join(", ")})`,
        (kept.same || []).length === 5);
      check(`${which}: the address is its own (${page.url().replace(site, "")}, was ${before.replace(site, "")})`,
        addressed(which, page.url()));
      check(`${which}: its tab marked`, (await current(page)).join() === which);
      const asked = await listed(which);
      const cards = await firstCards(page);
      if (!asked) {
        check(`${which}: its list answers`, false);
      } else if (!asked.ids.length) {
        check(`${which}: nothing listed, and no card drawn`, cards.length === 0);
      } else {
        // The front of Top leads with the week's pick, which the list has
        // too: every first card is one of the list's first page.
        const pick = which === "top" ? await page.$eval("#pick-card .model", (one) => one.dataset.id).catch(() => "") : "";
        const pool = new Set([...asked.ids, pick].filter(Boolean));
        check(`${which}: its first cards the list's own (${cards.slice(0, 4).join(", ")} of ${asked.ids.slice(0, 4).join(", ")})`,
          cards.length > 0 && cards.every((id) => pool.has(id))
          && (which === "top" || cards.join() === asked.ids.slice(0, cards.length).join()));
      }
    }
    check(`${await page.evaluate(() => history.length)} history entries for six tabs`, await page.evaluate(() => history.length) >= 6);

    // 2. Back to Sets at its scroll, Forward to Top.
    if (await press(page, "sets") && await shown(page, "sets")) {
      await page.evaluate(() => scrollTo({ top: 1200, behavior: "instant" }));
      await page.waitForTimeout(300);
      const left = await page.evaluate(() => Math.round(scrollY));
      // The tab row is off screen: the click a keyboard's Enter gives it.
      await page.evaluate(() => document.querySelector('#tabs [data-tab="top"]').click());
      check("Top from Sets scrolled down", await shown(page, "top"));
      await page.goBack({ timeout: 20000 }).catch(() => {});
      const back = await shown(page, "sets");
      const at = await page.evaluate(() => Math.round(scrollY));
      check(`Back: Sets again (${(await current(page)).join()}), at /library`, back && addressed("sets", page.url()));
      check(`Back: at its scroll, ${at} px (left at ${left})`, Math.abs(at - left) <= 40);
      check("Back: the same document", (await marks(page)).mark === first);
      await page.goForward({ timeout: 20000 }).catch(() => {});
      check("Forward: Top again", (await shown(page, "top")) && addressed("top", page.url()));
    } else {
      check("Back and Forward: Sets opened", false);
    }

    // 3. One search box, searching the tab it is on.
    await page.evaluate(() => scrollTo({ top: 0, behavior: "instant" }));
    await page.fill("#q", "castle").catch(() => {});
    const searched = await until(page, () => new URL(location.href).searchParams.get("q") === "castle"
      && document.documentElement.dataset.browse === "ready", null, 30);
    check("castle on Top: the address asks it", searched && addressed("top", page.url()));
    const models = await listed("top", "castle");
    const modelCards = await firstCards(page);
    check(`castle on Top: the models' list (${modelCards.slice(0, 3).join(", ")})`, Boolean(models)
      && modelCards.join() === models.ids.slice(0, modelCards.length).join());
    await press(page, "sets");
    const setsSearched = await shown(page, "sets");
    const url = new URL(page.url());
    check(`castle kept on Sets (${url.pathname}${url.search})`, setsSearched && addressed("sets", page.url())
      && url.searchParams.get("q") === "castle" && (await page.inputValue("#q").catch(() => "")) === "castle");
    const sets = await listed("sets", "castle");
    const setCards = await firstCards(page);
    check(`castle on Sets: the library's list (${setCards.slice(0, 3).join(", ")} of ${(sets?.ids || []).slice(0, 3).join(", ")})`,
      Boolean(sets) && setCards.length > 0 && setCards.join() === sets.ids.slice(0, setCards.length).join());
    check("still one document", (await marks(page)).mark === first);
    await made.close();
  }

  // 4. A reload of each tab's address shows that tab.
  {
    const made = await context(1280);
    for (const [which, address] of [["top", "/gallery"], ["new", "/gallery?sort=newest"], ["builds", "/builds"],
      ["collections", "/collections"], ["sets", "/library"]]) {
      const { page, status } = await opened(made, address);
      const drawn = await shown(page, which);
      await page.reload({ waitUntil: "load" }).catch(() => {});
      check(`${address} (${status}) reloaded shows ${which}: ${(await current(page)).join()}`, drawn
        && (await shown(page, which)) && (await current(page)).join() === which);
      await page.close();
    }
    await made.close();
  }

  // 5. The old addresses, each on its tab, with its canonical link and hreflang.
  {
    const made = await context(1280);
    for (const [address, which, canonical] of [["/library", "sets", "/library"], ["/library?theme=Town", "sets", "/library"],
      ["/builds", "builds", "/builds"], ["/collections", "collections", "/collections"], ["/de/library", "sets", "/de/library"]]) {
      const { page, status } = await opened(made, address);
      const head = await page.evaluate(() => ({
        canonical: document.querySelector('link[rel="canonical"]')?.getAttribute("href") || "",
        langs: [...document.querySelectorAll('link[rel="alternate"][hreflang]')].map((one) => `${one.hreflang} ${one.getAttribute("href")}`),
        lang: document.documentElement.lang })).catch(() => ({ canonical: "", langs: [] }));
      const bare = canonical.replace(/^\/(de|fr|es)(?=\/)/, "");
      check(`${address}: 200 (${status})`, status === 200);
      check(`${address}: canonical ${head.canonical}`, head.canonical === `${CANONICAL}${canonical}`);
      check(`${address}: hreflang en, de, fr, es and x-default`, ["en", "de", "fr", "es", "x-default"].every((code) =>
        head.langs.includes(`${code} ${CANONICAL}${code === "en" || code === "x-default" ? "" : `/${code}`}${bare}`)));
      check(`${address}: on ${which} (${(await current(page)).join()})`, (await shown(page, which))
        && (await current(page)).join() === which);
      if (address.includes("theme=")) {
        check(`${address}: the theme Town chosen`, await until(page, () => document.querySelector('#themes [data-pick="Town"]')
          ?.getAttribute("aria-pressed") === "true", null, 20));
      }
      if (address.startsWith("/de/")) check(`${address}: in German (${head.lang})`, head.lang === "de");
      await page.close();
    }
    await made.close();
  }

  // 6. A phone, in English and German; and the pictures, at both widths.
  for (const width of [390, 1280]) {
    for (const lang of ["en", "de"]) {
      const made = await context(width);
      const at = lang === "en" ? "" : `/${lang}`;
      const { page } = await opened(made, `${at}/gallery`);
      await shown(page, "top");
      const first = await mark(page);
      for (const which of ["top", "new", "builds", "collections", "sets"]) {
        if (which !== "top") {
          await press(page, which);
          check(`${width} ${lang}: ${which} in place`, (await shown(page, which)) && (await marks(page)).mark === first);
        }
        const row = await page.evaluate(() => {
          const tabs = document.getElementById("tabs");
          const box = tabs.getBoundingClientRect();
          const scrolls = getComputedStyle(tabs).overflowX === "auto" || getComputedStyle(tabs).overflowX === "scroll";
          // Whole where the row can come to rest with it in view: its tabs
          // snap to their starts, so the nearest place may leave a long
          // one cut where the row's start or end shows it whole.
          const whole = [...tabs.querySelectorAll("[data-tab]:not([hidden])")].map((tab) => ({ tab: tab.dataset.tab,
            whole: ["nearest", "start", "end"].some((inline) => {
              tab.scrollIntoView({ block: "nearest", inline, behavior: "instant" });
              const r = tab.getBoundingClientRect();
              return r.left >= box.left - 1 && r.right <= box.right + 1 && r.right <= innerWidth;
            }) }));
          scrollTo({ top: 0, behavior: "instant" });
          return { fits: tabs.scrollWidth <= tabs.clientWidth + 1, scrolls, whole,
            sideways: document.documentElement.scrollWidth - innerWidth };
        });
        check(`${width} ${lang} ${which}: the tab row ${row.fits ? "fits" : "scrolls inside itself"}, every tab reachable whole`,
          (row.fits || row.scrolls) && row.whole.every((one) => one.whole));
        check(`${width} ${lang} ${which}: nothing sideways (${row.sideways} px)`, row.sideways <= 0);
        await page.evaluate(() => document.querySelector("#tabs [aria-current]")?.scrollIntoView({ block: "nearest", inline: "nearest" }));
        await page.screenshot({ path: path.join(out, `${which}_${width}_${lang}.png`) });
        await page.evaluate(() => scrollTo({ top: innerHeight, behavior: "instant" }));
        await page.waitForTimeout(300);
        await page.screenshot({ path: path.join(out, `${which}_${width}_${lang}_scrolled.png`) });
        await page.evaluate(() => scrollTo({ top: 0, behavior: "instant" }));
      }
      await made.close();
    }
  }
} catch (trouble) {
  check(`the flow ran to its end (${String(trouble).slice(0, 200)})`, false);
} finally {
  await browser.close();
}

for (const problem of problems) check(`no script error: ${problem}`, false);
console.log(failed ? `browse: ${failed} FAILED` : "browse: ok");
process.exit(failed ? 1 : 0);
