// The gallery as a person uses it (docs/SOCIAL.md U3, web/gallery.js):
//
//   node tools/web/gallery_flow.mjs [--out=shots/gallery]             # this checkout's web/ and api/
//   node tools/web/gallery_flow.mjs --url=<deployment> [--out=...]    # a deployment's pages, the API answered here
//
// The owner asked for a gallery that feels like a social site, the work
// first. This holds the page to it, at 390 x 844 and 1280 x 900, light and
// dark:
//
//   1. the first screen: at 390 the first card's picture starts within
//      330 px of the top, two cards to a row, four cards' names on the
//      first two screens; at 1280 four
//      to a row and four whole cards on the first screen, the cards marked
//      once (no row of marks, none that nearly every card carries, no
//      card ending in a row that holds only its like); Top the tab shown,
//      its window All time; nothing scrolls sideways; Today in the
//      gallery's model card has its like and its set's card none, and its
//      why says only what is true; a picture of it in each theme;
//   2. Top, New and Following: New is the newest first and says so in the
//      address; Top over this week is the week's builds and remixes, no
//      pick, no shelves; a kind's pill and Made in Filters ask the list
//      and mark their cards; Following, signed in, is only the people Sam
//      follows, and is not offered signed out; a search (words, New, a
//      size, two pages) sent to somebody shows them its second page, with
//      Show earlier bringing back the first, the same cards in order;
//   3. a like from a card: signed out it asks to sign in; signed in the
//      heart is pressed and its count one more at once, and the model's own
//      page shows it liked;
//   4. paged (web/pager.js): scrolled to the end six times, nothing comes
//      by itself; Show more four times brings five pages, none twice, the
//      address page=5, the count "Showing models 1–120", the keyboard on
//      the first new card; flung to the foot of the page, nothing moves;
//   5. Back from a model deep in the list comes back to its card, within
//      100 px of where it was, with the five pages asked again (an unload
//      listener keeps it out of the back-forward cache, which would keep
//      the page as it was);
//   6. the cold start: an empty gallery says what goes there and how in,
//      Following and a quiet week each say theirs, and no shelf of fewer
//      than three shows;
//   7. before supabase/gallery_tabs.sql is applied: the page offers no
//      Following, window or Made, and the checkout's own api/share.js
//      answers the list from directory_models, refusing those words in
//      words (400), never a 500; after, it offers them and its cards carry
//      their comments.
//
// With no --url nothing leaves this machine: the pages are this checkout's
// web/, the server's pages its api/, and every API call is answered by
// design_stand_in.mjs, with a crowd of 130 plain models behind its own so
// the list pages. With --url the pages are the deployment's and the API
// is still answered here (a deployment's real gallery has too few models
// to page, and no account is made); its /m/ pages are made by this
// checkout's api/ so a like can be seen there.
//
// Pictures in --out: gallery_<width>_<theme>[_fold].png and the steps'.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const web = path.join(root, "web");
const api = path.join(root, "api");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = path.resolve(String(args.out || "shots/gallery"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const CROWD = 130;
stand.crowd(CROWD);

let failed = 0;
let passed = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
};
const until = (page, test, arg, ms = 10000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
const errors = [];

let remoteDb = "";
if (remote) {
  try {
    remoteDb = new URL((await (await fetch(`${remote}/api/account`, { headers })).json()).url).origin;
  } catch { /* none: the stand-in's own */ }
}

const browser = await launch({ signedOut: true });

/// A browser context as a person at [width] in [theme], signed in as the
/// stand-in's Sam or not, the API answered with [state].
async function visit({ width, theme = "light", signedIn = false, state = {}, cached = true }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await stand.serveSite(context, { web, api, remote, headers, remoteDb, state });
  if (remote) {
    // The model's own page by this checkout's api/, as locally.
    await context.route((url) => /^\/m\/[A-Za-z0-9]{10}\/?$/.test(url.pathname), async (route) => {
      const made = await stand.serverPage(api, new URL(route.request().url()).pathname);
      const policy = made.headers?.["content-security-policy"];
      await route.fulfill({ status: made.status, contentType: "text/html; charset=utf-8", body: made.html,
        headers: policy ? { "content-security-policy": policy } : {} });
    });
  }
  if (signedIn) {
    const kept = JSON.parse(JSON.stringify(stand.signedInStorage()).split(stand.DB).join(remoteDb || stand.DB));
    await context.addInitScript(([session, access]) => {
      try {
        localStorage.setItem("brickworks.session", session);
        sessionStorage.setItem("brickworks.access", access);
      } catch { /* a browser that keeps nothing */ }
    }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
  }
  // A page with an unload listener is never kept in the back-forward
  // cache: Back asks it again, the way a browser that dropped it would.
  if (!cached) await context.addInitScript(() => addEventListener("unload", () => {}));
  const page = await context.newPage();
  const label = `${width} ${theme} ${signedIn ? "in" : "out"}`;
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 200)}`);
    }
  });
  return { context, page };
}

/// The gallery at [address], drawn: its list and, on the front, its shelves.
async function gallery(page, address = "/gallery") {
  await page.goto(base + address, { waitUntil: "load", timeout: 60000 });
  await until(page, () => document.documentElement.dataset.gallery === "ready" && document.documentElement.dataset.shelves);
  await page.waitForTimeout(300);
}

/// What the page shows, read as a person reads it.
const drawn = (page) => page.evaluate(() => {
  const cards = [...document.querySelectorAll("#feed .model")].filter((el) => el.getClientRects().length);
  const boxes = cards.map((el) => el.getBoundingClientRect());
  const firstPicture = Math.min(...cards.map((el) => el.querySelector(".frame").getBoundingClientRect().top));
  // To a row: the most cards that share a top, outside the shelves' rows.
  const rows = {};
  for (const el of cards.filter((one) => !one.closest(".models.row"))) {
    const top = Math.round(el.getBoundingClientRect().top);
    rows[top] = (rows[top] || 0) + 1;
  }
  // A mark shown: drawn, and inside its row (one that does not fit is
  // clipped off whole by .marks).
  const shownMarks = (el, which = ".pill") => [...el.querySelectorAll(`.marks ${which}`)].filter((p) => {
    const box = p.getBoundingClientRect();
    const row = p.parentElement.getBoundingClientRect();
    return p.getClientRects().length && box.bottom <= row.bottom + 1;
  });
  const tab = document.querySelector("#tabs [aria-current]")?.dataset.tab || "";
  return {
    address: location.pathname + location.search,
    firstPicture: Math.round(firstPicture + scrollY),
    columns: Math.max(0, ...Object.values(rows)),
    // The marks shown: the most rows of them on a card, and the share of
    // the cards that show each; cards whose numbers' row holds only a button.
    markRows: Math.max(0, ...cards.map((el) => new Set(shownMarks(el).map((p) => Math.round(p.getBoundingClientRect().top))).size)),
    markShare: Object.fromEntries(["tested", "made"].map((mark) => [mark,
      cards.filter((el) => shownMarks(el, `.${mark}`).length).length / Math.max(1, cards.length)])),
    lonelyLike: cards.filter((el) => { const acts = el.querySelector(".acts"); return acts && [...acts.children].length > 0
      && [...acts.children].every((c) => c.matches(".icon-btn")); }).length,

    // Where each card's name ends, down the page, in the order they come.
    names: cards.map((el) => Math.round(el.querySelector(".open b").getBoundingClientRect().bottom + scrollY)).sort((a, b) => a - b),
    whole: boxes.filter((b) => b.top >= 0 && b.bottom <= innerHeight && b.width > 0).length,
    tab,
    tabs: [...document.querySelectorAll("#tabs [data-tab]")].filter((a) => !a.hidden).map((a) => a.dataset.tab),
    window: document.getElementById("window-label").hidden ? null : document.getElementById("window").value,
    made: !document.getElementById("made-label").hidden,
    ids: [...document.querySelectorAll("#models .model")].map((el) => el.dataset.id),
    pick: document.getElementById("pick").hidden ? "" : document.querySelector("#pick-card .model")?.dataset.id || "",
    shelves: !document.getElementById("shelves").hidden,
    small: document.getElementById("small").hidden ? 0 : document.querySelectorAll("#small-models .model").length,
    sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    pages: Number(document.documentElement.dataset.pages || 0),
    auto: Number(document.documentElement.dataset.auto || 0),
    more: !document.querySelector(".pager-more").hidden && !document.querySelector("nav.pager").hidden,
    earlier: !document.querySelector("[data-pager-earlier]").hidden,
    count: document.querySelector(".pager-count").hidden ? "" : document.querySelector(".pager-count").textContent,
    focused: [...document.querySelectorAll("#models .model")].findIndex((el) => el.contains(document.activeElement)),
    states: ["empty", "nothing", "quiet", "broken"].filter((id) => !document.getElementById(id).hidden),
    quiet: document.getElementById("quiet").hidden ? "" : document.getElementById("quiet").textContent.replace(/\s+/g, " ").trim(),
    empty: document.getElementById("empty").hidden ? "" : document.getElementById("empty").textContent.replace(/\s+/g, " ").trim(),
    zero: /(^|\s)0 (likes?|views?|built|comments?|remix)/.test(document.getElementById("feed").innerText),
    // Today in the gallery: each card's slot, whether it has a like, and its why.
    spot: document.getElementById("spotlight").hidden ? [] : [...document.querySelectorAll("#spotlight-models .model")]
      .map((el) => ({ slot: el.dataset.slot, like: Boolean(el.querySelector("[data-like]")),
        why: el.querySelector(".why")?.textContent || "" })),
  };
});

const shot = async (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full });

console.log(`gallery flow: ${remote || `${root} (its web/ and api/, served here)`}`);
try {
  // --- 1. The first screen ---------------------------------------------------
  console.log("the first screen");
  for (const width of [390, 1280]) {
    for (const theme of ["light", "dark"]) {
      const { context, page } = await visit({ width, theme });
      await gallery(page);
      await page.evaluate(() => Promise.all([...document.images].filter((i) => i.getBoundingClientRect().top < innerHeight)
        .map((i) => (i.complete ? null : new Promise((done) => { i.onload = i.onerror = done; })))));
      const seen = await drawn(page);
      if (width === 390) {
        check(seen.firstPicture <= 330 && seen.columns === 2 && !seen.sideways,
          `390 ${theme}: the first card's picture at ${seen.firstPicture} px (330 at most), ${seen.columns} to a row, nothing sideways`);
        check(seen.names.length >= 4 && seen.names[3] <= 2 * 844,
          `390 ${theme}: four cards' names on the first two screens, the fourth's ending at ${seen.names[3]} px (${2 * 844} at most)`);
      } else {
        check(seen.whole >= 4 && seen.columns === 4 && !seen.sideways,
          `1280 ${theme}: ${seen.whole} whole cards on the first screen (4 at least), ${seen.columns} to a row, nothing sideways`);
      }
      const common = Object.entries(seen.markShare).filter(([, share]) => share >= 0.9).map(([mark]) => mark);
      check(seen.markRows <= 1 && !common.length && seen.lonelyLike === 0,
        `${width} ${theme}: one row of marks at most (${seen.markRows}), none on 90% of the cards (${Object.entries(seen.markShare)
          .map(([mark, share]) => `${mark} ${Math.round(share * 100)}%`).join(", ")}), no card ending in its like alone (${seen.lonelyLike})`);
      check(seen.tab === "top" && seen.window === "" && seen.tabs.join(",") === "top,new" && seen.pick && !seen.zero,
        `${width} ${theme}: Top shown over all time, tabs ${seen.tabs.join(" · ")} signed out, this week's pick first (${seen.pick}), no count of 0`);
      // Today in the gallery (api/_featured.js): a model's card has its like
      // and a set's none; and the why says only what is true: Gatehouse
      // Starter is Tested, listed in May, and nobody did anything with it in
      // the past 30 days, so neither "New" nor a count.
      const [featured, set] = [seen.spot.find((one) => one.slot === "featured"), seen.spot.find((one) => one.slot === "library")];
      check(seen.spot.map((one) => one.slot).join(",") === "featured,library" && featured?.like && !set?.like
        && featured?.why === "Tested",
        `${width} ${theme}: Today in the gallery: ${seen.spot.map((one) => `${one.slot} ${one.like ? "with" : "without"} a like, "${one.why}"`).join("; ")}`);
      await shot(page, `gallery_${width}_${theme}_fold.png`);
      await shot(page, `gallery_${width}_${theme}.png`, true);
      await context.close();
    }
  }

  // --- 2. Top, New, Following; kinds and Made ---------------------------------
  console.log("Top, New and Following; a kind and Made");
  {
    const { context, page } = await visit({ width: 1280 });
    await gallery(page);
    await page.click('#tabs [data-tab="new"]');
    await until(page, () => location.search.includes("sort=newest") && document.documentElement.dataset.gallery === "ready");
    let seen = await drawn(page);
    check(seen.tab === "new" && seen.ids[0] === "PriyaSpc01" && !seen.pick && !seen.shelves && seen.window === null,
      `New: ${seen.address}, the newest first (${seen.ids.slice(0, 2).join(", ")}), no pick, no shelves, no window`);
    await page.click('#tabs [data-tab="top"]');
    await until(page, () => location.search === "" && document.documentElement.dataset.gallery === "ready");
    await page.selectOption("#window", "week");
    await until(page, () => location.search.includes("window=week") && document.documentElement.dataset.gallery === "ready");
    seen = await drawn(page);
    check(seen.tab === "top" && seen.ids.join(",") === "DesignAbc1,PriyaSpc01,DesignPar1,SamModel01,MikaRobot1" && !seen.pick && !seen.shelves,
      `Top over this week: ${seen.address}, ${seen.ids.join(", ")}: the week's, best first, no pick, no shelves`);
    await shot(page, "2_top_this_week_1280.png");
    await page.click('#tabs [data-tab="top"]');
    await until(page, () => location.search === "" && document.documentElement.dataset.gallery === "ready");
    await page.click('#kinds [data-kind="space"]');
    await until(page, () => location.search.includes("kind=space") && document.documentElement.dataset.gallery === "ready");
    const kinds = await page.evaluate(() => ({ pressed: document.querySelector('#kinds [aria-pressed="true"]')?.dataset.kind,
      cards: document.querySelectorAll("#models .model").length }));
    check(kinds.pressed === "space" && kinds.cards > 0, `the Space pill: pressed, ${kinds.cards} cards, ${await page.evaluate(() => location.search)}`);
    await page.click('#kinds [data-kind=""]');
    await until(page, () => !location.search.includes("kind=") && document.documentElement.dataset.gallery === "ready");
    await page.click("#filters summary");
    await page.selectOption("#made", "assistant");
    await until(page, () => location.search.includes("made=assistant") && document.documentElement.dataset.gallery === "ready");
    const made = await page.evaluate(() => {
      const cards = [...document.querySelectorAll("#models .model")];
      // Each made so, and none saying it: a mark every card carries tells none apart.
      return { n: cards.length, all: cards.every((el) => el.dataset.made === "assistant" && el.querySelector(".marks .pill.made")),
        shown: cards.filter((el) => el.querySelector(".marks .pill.made")?.getClientRects().length).length,
        quiet: document.body.dataset.quiet || "", said: document.getElementById("filters-said").textContent };
    });
    check(made.n > 0 && made.all && (made.n < 4 || (made.shown === 0 && /made/.test(made.quiet))) && made.said === "1",
      `Made: with the assistant: ${made.n} cards, each made so, its mark shown on ${made.shown} (data-quiet "${made.quiet}"); Filters says ${made.said} on`);
    await shot(page, "2_made_assistant_1280.png");
    await context.close();
  }
  {
    const { context, page } = await visit({ width: 390, signedIn: true, state: { likes: new Map() } });
    await gallery(page);
    let seen = await drawn(page);
    check(seen.tabs.join(",") === "top,new,following", `signed in at 390: the tabs are ${seen.tabs.join(" · ")}`);
    await page.click('#tabs [data-tab="following"]');
    await until(page, () => location.search.includes("following=1") && document.documentElement.dataset.gallery === "ready");
    seen = await drawn(page);
    const whose = await page.evaluate(() => [...new Set([...document.querySelectorAll("#models .model a.who")]
      .map((a) => a.getAttribute("href")))]);
    check(seen.tab === "following" && seen.ids.length > 0 && whose.every((href) => ["/u/mika-mocs", "/u/priya-plays"].includes(href)),
      `Following: ${seen.ids.length} cards, all by ${whose.join(", ")} (whom Sam follows)`);
    await shot(page, "2_following_390.png");
    await context.close();
  }

  // A search sent to somebody: the words, a filter, New and a second page,
  // all in the address; opened by somebody else, on a phone in the dark,
  // the same cards in the same order, and the controls saying the same.
  {
    const { context, page } = await visit({ width: 1280 });
    await gallery(page);
    await page.fill("#q", "crowd");
    await until(page, () => location.search.includes("q=crowd") && document.documentElement.dataset.gallery === "ready");
    await page.click('#tabs [data-tab="new"]');
    await until(page, () => location.search.includes("sort=newest") && document.documentElement.dataset.gallery === "ready");
    await page.click("#filters summary");
    await page.selectOption("#size", "medium");
    await until(page, () => location.search.includes("size=medium") && document.documentElement.dataset.gallery === "ready");
    await page.click("#filters summary");
    await page.click(".pager-more");
    await until(page, () => Number(document.documentElement.dataset.pages) === 2);
    const sent = await drawn(page);
    await context.close();
    // Opened by somebody else: the page the address says, page 2, and Show
    // earlier over it bringing back page 1 above it.
    const pages = Number(/[?&]page=(\d+)/.exec(sent.address)?.[1] || 0);
    const other = await visit({ width: 390, theme: "dark" });
    await gallery(other.page, sent.address);
    const second = await drawn(other.page);
    await other.page.click("[data-pager-earlier] a");
    await until(other.page, () => document.querySelectorAll("#models .model").length === 48);
    const got = await drawn(other.page);
    const controls = await other.page.evaluate(() => ({ q: document.getElementById("q").value,
      size: document.getElementById("size").value, on: document.getElementById("filters-said").textContent }));
    check(pages === 2 && sent.ids.length === 48 && second.ids.join(",") === sent.ids.slice(24).join(",") && second.earlier
      && got.ids.join(",") === sent.ids.join(",") && got.tab === "new" && controls.q === "crowd" && controls.size === "medium"
      && controls.on === "1",
      `a search sent to somebody: ${sent.address}, ${sent.ids.length} cards; opened at 390 in the dark, its page 2 `
      + `(${second.ids.length} cards, Show earlier ${second.earlier ? "over it" : "MISSING"}), then ${got.ids.length} cards, `
      + `${got.ids.join(",") === sent.ids.join(",") ? "the same, in the same order" : "NOT the same"}, New, "${controls.q}", ${controls.size}, Filters ${controls.on}`);
    await shot(other.page, "2_search_sent_390_dark.png");
    await other.context.close();
  }
  // Filters on a phone: a sheet inside the screen. A search that finds
  // nothing says so, and its Clear brings the gallery back.
  {
    const { context, page } = await visit({ width: 390 });
    await gallery(page);
    await page.click("#filters summary");
    const sheet = await page.evaluate(() => {
      const box = document.querySelector("#filters .sheet").getBoundingClientRect();
      return { left: Math.round(box.left), right: Math.round(box.right), width: innerWidth };
    });
    check(sheet.left >= 0 && sheet.right <= sheet.width, `390: Filters opens a sheet inside the screen (${sheet.left} to ${sheet.right} of ${sheet.width})`);
    await shot(page, "2_filters_390.png");
    await page.click("#filters summary");
    await page.fill("#q", "zzzqx");
    await until(page, () => location.search.includes("q=zzzqx") && document.documentElement.dataset.gallery === "ready");
    let seen = await drawn(page);
    const words = await page.evaluate(() => document.getElementById("nothing").textContent.replace(/\s+/g, " ").trim());
    check(seen.states.join(",") === "nothing" && seen.ids.length === 0 && !seen.pick && !seen.shelves,
      `nothing matches "zzzqx": "${words}"`);
    await shot(page, "2_nothing_390.png");
    await page.click("#clear");
    await until(page, () => location.search === "" && document.documentElement.dataset.gallery === "ready");
    seen = await drawn(page);
    check(seen.ids.length > 0 && seen.states.length === 0 && (await page.inputValue("#q")) === "",
      `...and Clear brings the gallery back: ${seen.ids.length} cards, ${seen.address}`);
    await context.close();
  }

  // --- 3. A like from a card ---------------------------------------------------
  console.log("a like from a card");
  {
    const { context, page } = await visit({ width: 390 });
    await gallery(page);
    await page.click('#models .model[data-id="DesignGea1"] [data-like]').catch(() => {});
    const asked = await until(page, () => document.querySelector("dialog.sign-in[open]"));
    const words = await page.evaluate(() => document.querySelector("dialog.sign-in p")?.textContent || "");
    check(asked && /Sign in to like it/.test(words), `signed out, the heart asks to sign in: "${words}"`);
    await shot(page, "3_like_signed_out_390.png");
    await context.close();
  }
  for (const width of [1280, 390]) {
    const likes = new Map();
    const { context, page } = await visit({ width, signedIn: true, state: { likes } });
    await gallery(page);
    const card = `#feed .model[data-id="${stand.MODEL_ID}"]`;
    const before = await page.evaluate((sel) => {
      const button = document.querySelector(`${sel} [data-like]`);
      return { pressed: button?.getAttribute("aria-pressed"), n: button?.querySelector(".n")?.textContent || "", label: button?.getAttribute("aria-label") };
    }, card);
    await page.click(`${card} [data-like]`);
    const pressed = await until(page, (sel) => document.querySelector(`${sel} [data-like]`)?.getAttribute("aria-pressed") === "true", card, 3000);
    const after = await page.evaluate((sel) => {
      const button = document.querySelector(`${sel} [data-like]`);
      return { n: button?.querySelector(".n")?.textContent || "", label: button?.getAttribute("aria-label") };
    }, card);
    check(before.pressed === "false" && pressed && Number(after.n) === Number(before.n) + 1 && likes.get(stand.MODEL_ID) === true,
      `${width}: a like from the Watchtower's card: pressed, ${before.n} → ${after.n} at once ("${after.label}")`);
    await shot(page, `3_liked_${width}.png`);
    if (width === 1280) {
      await page.goto(`${base}/m/${stand.MODEL_ID}`, { waitUntil: "load" });
      const shown = await until(page, () => document.querySelector('[data-mark="like"]')?.getAttribute("aria-pressed") === "true", null, 10000);
      check(shown, `its page shows it liked: ${await page.evaluate(() => document.querySelector('[data-mark="like"]')?.textContent || "no Like")}`);
    }
    await context.close();
  }

  // --- 4. Paged: Show more, never by itself -----------------------------------
  console.log("paged: Show more, never by itself");
  let deep = null;
  {
    const { context, page } = await visit({ width: 1280 });
    await gallery(page);
    // Down the list as a person reads it: its end 100 px under the screen
    // each time, which once asked for the next page by itself.
    for (let at = 0; at < 6; at += 1) {
      await page.evaluate(() => scrollBy({ top: document.getElementById("feed").getBoundingClientRect().bottom - innerHeight - 100,
        behavior: "instant" }));
      await page.waitForTimeout(700);
    }
    let seen = await drawn(page);
    check(seen.pages === 1 && seen.more && !/[?&]page=/.test(seen.address) && /^Showing models 1–24$/.test(seen.count),
      `scrolled to the end six times: ${seen.pages} page, Show more ${seen.more ? "shown" : "hidden"}, "${seen.count}", ${seen.address}`);
    await shot(page, "4_show_more_1280.png");
    for (let n = 2; n <= 5; n += 1) {
      await page.click(".pager-more");
      await until(page, (want) => Number(document.documentElement.dataset.pages) === want, n);
    }
    seen = await drawn(page);
    check(seen.pages === 5 && /[?&]page=5\b/.test(seen.address) && seen.ids.length === new Set(seen.ids).size
      && seen.count === "Showing models 1–120" && seen.focused === seen.ids.length - 24,
      `Show more four times: five pages, ${seen.ids.length} cards, none twice, "${seen.count}", the keyboard on card `
      + `${seen.focused + 1}, ${seen.address}`);
    deep = { address: seen.address, id: seen.ids[100], at: 101 };
    await context.close();
  }
  {
    // Flung to the foot: nothing comes by itself, so Put yours here stays
    // where it is (a page put in by itself there pushed it down: CLS 0.51
    // at 1280, site277); Show more then draws the next page.
    const { context, page } = await visit({ width: 1280 });
    await gallery(page);
    const was = await page.evaluate(() => {
      scrollTo({ top: document.documentElement.scrollHeight, behavior: "instant" });
      return document.querySelector(".yours").getBoundingClientRect().top;
    });
    await page.waitForTimeout(1500);
    const held = await page.evaluate(() => ({ pages: Number(document.documentElement.dataset.pages),
      yours: document.querySelector(".yours").getBoundingClientRect().top }));
    check(held.pages === 1 && held.yours === was,
      `flung to the foot, nothing comes by itself: ${held.pages} page drawn, Put yours here at ${Math.round(held.yours)} px, was ${Math.round(was)}`);
    await page.click(".pager-more");
    const drew = await until(page, () => Number(document.documentElement.dataset.pages) === 2, null, 5000);
    check(drew, "Show more draws the next page");
    await context.close();
  }

  // --- 5. Back to the same card -------------------------------------------------
  console.log("Back to the same card");
  {
    const cached = false;
    const { context, page } = await visit({ width: 390, cached });
    await gallery(page, deep.address);
    const card = `#feed .model[data-id="${deep.id}"]`;
    await page.locator(card).scrollIntoViewIfNeeded();
    await page.evaluate(() => scrollBy(0, -200));
    await page.waitForTimeout(300);
    const top = await page.evaluate((sel) => Math.round(document.querySelector(sel).getBoundingClientRect().top), card);
    await page.click(`${card} a.open`);
    await page.waitForURL(`**/m/${deep.id}`, { timeout: 20000 });
    await page.waitForTimeout(500);
    await page.goBack({ waitUntil: "load" });
    await until(page, (id) => document.documentElement.dataset.gallery === "ready"
      && (document.documentElement.dataset.back === id || document.querySelector(`#feed .model[data-id="${id}"]`)), deep.id, 20000);
    await page.waitForTimeout(600);
    const back = await page.evaluate((sel) => ({ top: Math.round(document.querySelector(sel)?.getBoundingClientRect().top ?? 1e9),
      how: performance.getEntriesByType("navigation")[0]?.type || "", restored: document.documentElement.dataset.back || "kept",
      address: location.pathname + location.search }), card);
    check(Math.abs(back.top - top) <= 100 && back.address === deep.address && back.restored === deep.id,
      `Back from its page, the gallery asked again (${back.how}): ${deep.id}, card ${deep.at} of the list, at ${back.top} px, `
      + `was ${top} (100 at most apart), ${back.address}`);
    await shot(page, "5_back_390.png");
    await context.close();
  }

  // --- 6. The cold start --------------------------------------------------------
  console.log("the cold start");
  {
    const { context, page } = await visit({ width: 390, signedIn: true, state: { empty: true } });
    await gallery(page);
    let seen = await drawn(page);
    const way = await page.evaluate(() => document.querySelector("#empty a")?.getAttribute("href"));
    check(seen.states.join(",") === "empty" && /List it in the gallery/.test(seen.empty) && way === "/app" && !seen.pick && !seen.shelves,
      `nothing listed: "${seen.empty.slice(0, 60)}…", its way in ${way}; no pick, no shelf`);
    await shot(page, "6_empty_390.png");
    await gallery(page, "/gallery?following=1");
    seen = await drawn(page);
    check(seen.states.join(",") === "quiet" && /Nobody you follow has listed a model yet/.test(seen.quiet) && /See Top/.test(seen.quiet),
      `Following with nothing: "${seen.quiet.slice(0, 70)}…"`);
    await shot(page, "6_following_empty_390.png");
    await page.click("#quiet-go");
    await until(page, () => location.search === "" && document.documentElement.dataset.gallery === "ready");
    check((await drawn(page)).tab === "top", "...and See Top goes to Top");
    await gallery(page, "/gallery?window=week");
    seen = await drawn(page);
    check(seen.states.join(",") === "quiet" && /Nothing was built or remixed here this week yet/.test(seen.quiet),
      `Top over a quiet week: "${seen.quiet.slice(0, 70)}…"`);
    await context.close();
  }
  {
    const { context, page } = await visit({ width: 1280 });
    await gallery(page);
    const seen = await drawn(page);
    check(seen.small >= 3, `the small builds' shelf shows with ${seen.small} cards (three at least)`);
    await context.close();
  }

  // --- 7. Before supabase/gallery_tabs.sql, and after -----------------------------
  console.log("before supabase/gallery_tabs.sql is applied, and after");
  stand.applied(false);
  {
    const { context, page } = await visit({ width: 1280, signedIn: true });
    await gallery(page);
    const seen = await drawn(page);
    const comments = await page.evaluate(() => document.querySelectorAll('#feed .model .tally[title*="comment"]').length);
    check(seen.tabs.join(",") === "top,new" && seen.window === null && !seen.made && comments === 0 && seen.ids.length > 0,
      `before: tabs ${seen.tabs.join(" · ")}, no window, no Made, no comment counts; ${seen.ids.length} cards`);
    await gallery(page, "/gallery?following=1");
    const put = await drawn(page);
    check(put.address === "/gallery" && put.ids.length > 0, `before: an address asking Following is put right: ${put.address}`);
    await context.close();
  }
  const ask = async (query) => {
    const said = await stand.serverAsk(api, { name: "share", query: { op: "list", ...query } });
    let body = {};
    try {
      body = JSON.parse(said.html || "{}");
    } catch { /* not JSON */ }
    return { status: said.status, body };
  };
  let list = await ask({});
  const top = await ask({ sort: "top", window: "week" });
  const hand = await ask({ made: "hand" });
  check(list.status === 200 && !("windows" in list.body) && !("mades" in list.body) && list.body.models?.length > 0
      && top.status === 400 && hand.status === 400 && /not here yet/.test(top.body.error || ""),
    `api/share.js before: the list ${list.status} with ${list.body.models?.length} cards and no windows; a window ${top.status}, Made ${hand.status}: "${top.body.error}"`);
  stand.applied(true);
  list = await ask({ sort: "top" });
  const week = await ask({ sort: "top", window: "week" });
  const said = (list.body.models || []).find((one) => one.id === stand.MODEL_ID);
  check(list.status === 200 && (list.body.windows || []).map((one) => one.id).join(",") === "week,month"
      && (list.body.mades || []).length === 2 && said?.comments === 6 && week.status === 200 && week.body.window === "week",
    `api/share.js after: windows ${(list.body.windows || []).map((one) => one.label).join(", ")}, Made, the Watchtower's ${said?.comments} comments; this week ${week.status}`);
  const nobody = await ask({ following: "1" });
  check(nobody.status === 401, `api/share.js: Following asked signed out is ${nobody.status}`);
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  await browser.close();
}
for (const error of errors) check(false, `script: ${error}`);
console.log(`\ngallery flow: ${passed} passed, ${failed} failed; pictures in ${out}`);
process.exit(failed || !passed ? 1 : 0);
