// A person's page, /u/<handle> (api/people.js profilePage, docs/SOCIAL.md
// U5, supabase/profile_shows.sql), in a real browser at 390 and 1280 px, in
// light and dark, signed out and signed in.
//
//   node tools/web/profile_flow.mjs [--out=DIR]                       this checkout, the stand-in's people
//   node --env-file=.env tools/web/relay_server.mjs 8993 --hold=profile_shows &
//   node --env-file=.env tools/web/profile_flow.mjs --url=http://127.0.0.1:8993 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/profile_flow.mjs --url=<preview> --out=DIR
//
// The owner: "the users account/profile page needs to be drastically
// improved". What a person sees, on every page and both widths, themes and
// sign-ins:
//
//   the head: an avatar made from the handle (a coloured tile and the
//     initial, never a picture of a figure), or the picture its owner chose
//     (Robin's, here: supabase/avatars.sql), the name, @handle, the words
//     and links (https, rel="ugc nofollow"), one row of numbers with no
//     count of none, Follow, Share and More; at 390 px the avatar, the
//     name, the numbers and Follow on the first screen;
//   the models they pinned, in their order, above the tabs; a banner of
//     one of their models' pictures when they chose one;
//   the tabs, Models · Builds · Collections, one shown, each with its count
//     once there is one, and what goes there said when it has nothing;
//   every model reached: a person with 60 has three pages, Show more
//     brings each, and with no script each is a page of its own;
//   whom they follow only when they chose to show it, and never a list of
//     who follows them;
//   what they earned (docs/SOCIAL.md U13), a row of pills under the
//     numbers: each challenge won (a link to the model that won it), ten
//     builds of their models, a model Tested, their first model listed and
//     their first build finished, the rarest first, worked out from what
//     the page shows and never kept; none for somebody with nothing yet;
//   nothing scrolling sideways, no script error, no refused request.
//
// Locally (no --url) nothing leaves this machine: design_stand_in.mjs's
// people, served as design_flow.mjs serves them. Robin chose links, a
// banner and pins; the house account ("Brickworks", as the live gallery's
// models are credited) chose nothing and has a person-shaped page all the
// same; Ines has 60 models; Alex has nothing yet.
//
// With --url: throwaway accounts at Resend test addresses on that site's
// project. Ada makes a profile, lists two models and chooses links, a
// banner and pins through /api/people?op=showcase, which refuses what it
// should whether or not profile_shows.sql is applied, and says "not open
// yet" until it is. Her page is checked as above (links, banner and pins
// only once it is applied, or held by the relay). Her account is deleted
// at the end, and with it her row of profile_shows: read back with the
// secret key on a deployment; on the relay the table is held in memory,
// where the dry run (tools/profile_shows_try.sql) proves the cascade.
// Her achievements, earned by doing each thing: none with a profile alone;
// First model listed once she lists; Tested once a model of hers is; First
// build finished once she posts a photo of her build of Bob's model; Ten
// builds once her castle is built to its last step on ten devices. And Cy,
// who had a profile and a model in the gallery before saying he is under 13
// (an account from before the age question): his page, its answer and his
// achievements are shown to nobody, and his own /profile shows none.
// A challenge won is challenges_flow.mjs's, which has the challenge.
// Pictures in --out.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { modelHash } from "../../api/_directory.js";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const site = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const widths = String(args.widths || "390,1280").split(",").map(Number);
const themes = String(args.themes || "light,dark").split(",");
const bypass = process.env.BW_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const ID = /^[A-Za-z0-9]{10}$/;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" || /Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}
const shot = (page, name, full = true) => (out ? page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`)) : null);

/// Until [test] holds in [page], or [ms] pass: whether it did.
const until = (page, test, arg, ms = 15000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);

/// The page as a person reads it: its head, numbers, links, pins, tabs,
/// what its tab shows, and where things sit on the first screen.
const drawn = (page) => page.evaluate(() => {
  const box = (el) => (el ? el.getBoundingClientRect() : null);
  const shown = (el) => Boolean(el && !el.hidden && el.offsetParent !== null);
  const avatar = document.querySelector(".profile-head .avatar");
  const follow = document.querySelector(".profile-head button[data-follow]");
  const numbers = [...document.querySelectorAll(".numbers li")];
  const firstNumber = numbers.find(shown);
  return {
    name: document.querySelector(".profile-head h1")?.textContent || "",
    handle: document.querySelector(".profile-head .handle")?.textContent.replace(/\s+/g, " ").trim() || "",
    avatar: avatar ? { letter: avatar.textContent, picture: Boolean(avatar.querySelector("img")),
      loaded: Boolean(avatar.querySelector("img")?.naturalWidth),
      tile: [...avatar.classList].some((c) => /^c[1-8]$/.test(c)), bottom: box(avatar).bottom } : null,
    nameBottom: box(document.querySelector(".profile-head h1"))?.bottom ?? 1e9,
    numbersBottom: firstNumber ? box(firstNumber).bottom : null,
    follow: follow ? { shown: shown(follow), text: follow.textContent, bottom: box(follow).bottom } : null,
    numbers: numbers.map((li) => ({ kind: li.dataset.stat, shown: shown(li), n: li.querySelector("b")?.textContent || "",
      text: li.textContent.replace(/\s+/g, " ").trim() })),
    links: [...document.querySelectorAll(".profile .links a")].map((a) => ({ href: a.getAttribute("href"), rel: a.rel,
      text: a.textContent })),
    banner: document.querySelector(".profile .banner img")?.getAttribute("src") || "",
    bannerLoaded: Boolean(document.querySelector(".profile .banner img")?.naturalWidth),
    pins: [...document.querySelectorAll(".pinned .model")].map((card) => card.dataset.id),
    tabs: [...document.querySelectorAll(".profile .tabs a")].map((a) => ({ tab: a.dataset.tab, current: a.getAttribute("aria-current") === "page",
      n: a.querySelector(".n")?.textContent || "" })),
    panel: document.querySelector(".tab-panel")?.dataset.panel || "",
    cards: [...document.querySelectorAll("[data-models] .model")].map((card) => card.dataset.id),
    builds: document.querySelectorAll(".tab-panel figure.build").length,
    lists: [...document.querySelectorAll(".list-card")].map((card) => ({ id: card.dataset.id,
      pictures: card.querySelectorAll(".mosaic img").length, name: card.querySelector("b")?.textContent || "" })),
    empty: document.querySelector(".tab-panel .state")?.textContent.replace(/\s+/g, " ").trim() || "",
    more: document.querySelector("a[data-more]")?.getAttribute("href") || "",
    follows: [...document.querySelectorAll(".follows a")].map((a) => a.getAttribute("href")),
    awards: [...document.querySelectorAll(".profile .awards li")].map((li) => ({ id: li.dataset.award,
      text: li.textContent.replace(/\s+/g, " ").trim(), href: li.querySelector("a")?.getAttribute("href") || "",
      said: li.querySelector(".pill")?.title || "", icon: Boolean(li.querySelector("svg.icon use[href$='#award']")) })),
    // Beside the numbers or under them, never before them.
    awardsAfter: Boolean(document.querySelector(".profile .numbers")?.compareDocumentPosition(document.querySelector(".profile .awards") || document.body)
      & Node.DOCUMENT_POSITION_FOLLOWING) && Boolean(document.querySelector(".profile .awards")),
    share: shown(document.querySelector("button[data-share]")),
    sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    screen: innerHeight,
  };
});

/// What every person's page holds, whoever they are.
function headHolds(said, label, { name, handle, phone, pictured = false, likes = false }) {
  check(`${label}: "${said.name}", ${said.handle.split(" · ")[0]}`, said.name === name && said.handle.startsWith(`@${handle}`));
  // Their own picture, where they chose one (supabase/avatars.sql: Robin,
  // in the stand-in), on its tile until it loads; else the tile's letter.
  if (pictured) {
    check(`${label}: their own picture as the avatar, loaded, over its tile`,
      Boolean(said.avatar && said.avatar.tile && said.avatar.picture && said.avatar.loaded));
  } else {
    check(`${label}: an avatar made from the handle ("${said.avatar?.letter}" on a coloured tile, no picture)`,
      Boolean(said.avatar && said.avatar.tile && !said.avatar.picture && said.avatar.letter === [...name][0].toUpperCase()));
  }
  const zeros = said.numbers.filter((one) => one.shown && (!one.n || one.n === "0"));
  check(`${label}: numbers ${said.numbers.filter((one) => one.shown).map((one) => one.text).join(" · ") || "(none yet)"}, no count of none`,
    zeros.length === 0);
  check(`${label}: tabs ${said.tabs.map((one) => `${one.tab}${one.n ? ` ${one.n}` : ""}${one.current ? "*" : ""}`).join(" · ")}`,
    // Likes too where they chose to show them (Robin, here: supabase/avatars.sql).
    said.tabs.map((one) => one.tab).join(",") === `models,builds,collections${likes ? ",likes" : ""}`
    && said.tabs.filter((one) => one.current).length === 1
      && said.tabs.every((one) => one.n !== "0"));
  check(`${label}: every link https and ugc nofollow`, said.links.every((one) => /^https:\/\//.test(one.href)
    && /\bugc\b/.test(one.rel) && /\bnofollow\b/.test(one.rel)));
  if (phone) {
    const last = Math.max(said.avatar?.bottom ?? 1e9, said.nameBottom, said.numbersBottom ?? 0, said.follow?.shown ? said.follow.bottom : 0);
    check(`${label}: avatar, name, numbers and Follow on the first screen (to ${Math.round(last)} of ${said.screen} px)`, last <= said.screen);
  }
  check(`${label}: nothing sideways`, !said.sideways);
}

const browser = await launch({ signedOut: true });

/// A page of the site at [width] in [theme], [signedIn] or not.
async function open(pathname, { width, theme, signedIn = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!remote) await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api") });
  if (signedIn) {
    await context.addInitScript(([key, value, access]) => {
      try {
        localStorage.setItem(key, value);
        if (access) sessionStorage.setItem("brickworks.access", access);
      } catch { /* a browser that keeps nothing */ }
    }, signedIn);
  }
  // What Share copies, kept where the check reads it: the stand-in's site is
  // plain http, which a browser gives no clipboard.
  await context.addInitScript(() => {
    const keep = { writeText: async (text) => { window.copiedText = String(text); } };
    try {
      Object.defineProperty(navigator, "clipboard", { value: keep, configurable: true });
    } catch { /* kept as the browser has it */ }
  });
  const page = await context.newPage();
  listen(page, label);
  await page.goto(site + pathname, { waitUntil: "load", timeout: 60000 });
  await until(page, () => document.querySelector("button[data-share]") && !document.querySelector("button[data-share]").hidden);
  await page.evaluate(async () => {
    for (const img of document.querySelectorAll("img[loading=lazy]")) img.loading = "eager";
    await Promise.race([Promise.all([...document.images].map((img) => img.decode().catch(() => {}))),
      new Promise((done) => setTimeout(done, 8000))]);
  });
  return { page, context };
}

/// The stand-in's signed-in session (Sam), as web/account.js keeps one.
function standSession() {
  const kept = stand.signedInStorage();
  return [STORAGE_KEY, JSON.stringify(kept.session), JSON.stringify(kept.access)];
}

async function local() {
  console.log("1. Robin: links, a banner and three models pinned");
  for (const width of widths) {
    for (const theme of themes) {
      for (const who of ["out", "in"]) {
        const label = `Robin ${width} ${theme} ${who}`;
        const { page, context } = await open(`/u/${stand.HANDLE}`, { width, theme, label, signedIn: who === "in" ? standSession() : null });
        if (who === "in") await until(page, () => !document.querySelector("button[data-follow]")?.hidden);
        const said = await drawn(page);
        headHolds(said, label, { name: "Robin Castell", handle: stand.HANDLE, phone: width < 600, pictured: true, likes: true });
        const kinds = said.numbers.filter((one) => one.shown).map((one) => one.kind).join(",");
        check(`${label}: builds finished and remixes first (${kinds}); 77 builds, the sum of the cards`,
          kinds === "builds,remixes,models,likes,followers,following" && said.numbers[0].n === "77");
        check(`${label}: two links, said as their domain (${said.links.map((one) => one.text).join(", ")})`,
          said.links.map((one) => one.text).join(",") === "robin-castell.example/castles,flickr.com/photos/robin-castell");
        check(`${label}: the watchtower across the top (${said.banner}), loaded`, said.banner === `/m/${stand.MODEL_ID}.png` && said.bannerLoaded);
        check(`${label}: pinned in Robin's order: ${said.pins.join(", ")}`, said.pins.join(",") === `DesignGea1,${stand.MODEL_ID},DesignFox1`);
        check(`${label}: achievements ${said.awards.map((one) => one.text).join(" · ")}, the win a link to the watchtower, each with its icon and what it means`,
          said.awards.map((one) => one.id).join(",") === "won,ten,tested,listed,built"
          && said.awards[0].text === "Won “Castle September”, by hand" && said.awards[0].href === `/m/${stand.MODEL_ID}`
          && said.awards.slice(1).map((one) => one.text).join("|") === "Ten builds|Tested|First model listed|First build finished"
          && said.awards.every((one) => one.icon && one.said));
        check(`${label}: Models shown, 4 cards; whom Robin follows, shown by choice (${said.follows.join(", ")}); Follow ${said.follow?.shown ? "shown" : "hidden"}`,
          said.panel === "models" && said.cards.length === 4 && said.follows.join(",") === "/u/priya-plays,/u/mika-mocs"
          && Boolean(said.follow?.shown));
        // Jo follows Robin; Robin does not follow Jo: nobody's followers are listed.
        check(`${label}: no list of who follows Robin`, !(await page.content()).includes("jo-bricks"));
        if (width >= 600 && who === "out") {
          await page.click("button[data-share]");
          const told = await until(page, () => document.querySelector("body > .toast.shown")?.textContent === "Link copied");
          const copied = await page.evaluate(() => window.copiedText || "");
          check(`${label}: Share copies the page's link ("${copied}") and says so`, told && copied === `${stand.ORIGIN}/u/${stand.HANDLE}`);
          await page.click(".profile-head .more-menu summary");
          check(`${label}: More opens with Report it`, await until(page, () => document.querySelector(".profile-head .more-menu[open] button[data-report]")?.offsetParent !== null));
          await page.keyboard.press("Escape");
        }
        await shot(page, `robin_${width}_${theme}_${who}.png`);
        await shot(page, `robin_${width}_${theme}_${who}_fold.png`, false);
        await context.close();
      }
    }
  }

  console.log("2. Robin's other tabs");
  for (const width of widths) {
    for (const theme of themes) {
      const { page, context } = await open(`/u/${stand.HANDLE}?tab=builds`, { width, theme, label: `builds ${width} ${theme}` });
      let said = await drawn(page);
      const loaded = await page.evaluate(() => [...document.querySelectorAll(".tab-panel figure.build img")].every((img) => img.naturalWidth > 0));
      check(`builds ${width} ${theme}: the Builds tab, ${said.builds} photos in columns, loaded`, said.panel === "builds"
        && said.tabs.find((one) => one.current)?.tab === "builds" && said.builds === Number(said.tabs[1].n) && said.builds > 0 && loaded);
      check(`builds ${width} ${theme}: nothing sideways`, !said.sideways);
      await shot(page, `robin-builds_${width}_${theme}.png`);
      await page.click('.profile .tabs a[data-tab="collections"]');
      await page.waitForLoadState("load");
      said = await drawn(page);
      check(`collections ${width} ${theme}: ${said.lists.map((one) => `"${one.name}" (${one.pictures} pictures)`).join(", ")}`,
        said.panel === "collections" && said.lists.length === 2 && said.lists[0].pictures === 3 && said.lists[1].pictures === 2);
      check(`collections ${width} ${theme}: nothing sideways`, !said.sideways);
      await shot(page, `robin-collections_${width}_${theme}.png`);
      await context.close();
    }
  }

  console.log("3. The house account, and somebody with nothing yet");
  for (const width of widths) {
    for (const theme of themes) {
      const house = await open("/u/brickworks?tests=1", { width, theme, label: `house ${width} ${theme}` });
      let said = await drawn(house.page);
      headHolds(said, `house ${width} ${theme}`, { name: "Brickworks", handle: "brickworks", phone: width < 600 });
      check(`house ${width} ${theme}: its 7 models, no banner, no pins, no links`, said.cards.length === 7 && !said.banner
        && said.pins.length === 0 && said.links.length === 0);
      check(`house ${width} ${theme}: achievements ${said.awards.map((one) => one.text).join(" · ")}, no challenge won`,
        said.awards.some((one) => one.id === "listed") && !said.awards.some((one) => one.id === "won"));
      await shot(house.page, `house_${width}_${theme}.png`);
      await house.page.click('.profile .tabs a[data-tab="builds"]');
      await house.page.waitForLoadState("load");
      said = await drawn(house.page);
      check(`house ${width} ${theme}: Builds says what goes there: "${said.empty.slice(0, 60)}…"`, /^No builds yet\./.test(said.empty));
      await house.context.close();
      const alex = await open("/u/new-here", { width, theme, label: `new ${width} ${theme}` });
      said = await drawn(alex.page);
      headHolds(said, `new ${width} ${theme}`, { name: "Alex Moreau", handle: "new-here", phone: width < 600 });
      check(`new ${width} ${theme}: no numbers, no achievements, Models says what goes there: "${said.empty.slice(0, 50)}…"`,
        said.numbers.every((one) => !one.shown) && said.awards.length === 0 && /^Nothing in the gallery yet\./.test(said.empty));
      await shot(alex.page, `new_${width}_${theme}.png`);
      await alex.page.click('.profile .tabs a[data-tab="collections"]');
      await alex.page.waitForLoadState("load");
      said = await drawn(alex.page);
      check(`new ${width} ${theme}: Collections says what goes there`, /^No collections yet\./.test(said.empty));
      await alex.context.close();
    }
  }

  console.log("4. Ines: 60 models, every one reached");
  for (const width of widths) {
    const theme = themes[themes.length - 1];
    const { page, context } = await open("/u/ines-many?tests=1", { width, theme, label: `Ines ${width}` });
    let said = await drawn(page);
    check(`Ines ${width}: pinned ${said.pins.join(", ")}; Models ${said.tabs[0].n}; the first page ${said.cards.length} cards`,
      said.pins.join(",") === "InesMod003,InesMod059" && said.tabs[0].n === "60" && said.cards.length === 24);
    for (const wanted of [48, 60]) {
      await page.click("a[data-more]");
      await until(page, (n) => document.querySelectorAll("[data-models] .model").length >= n, wanted);
    }
    said = await drawn(page);
    const all = new Set(said.cards);
    const every = Array.from({ length: 60 }, (_, at) => `InesMod${String(at + 1).padStart(3, "0")}`);
    check(`Ines ${width}: Show more twice: ${said.cards.length} cards, ${all.size} different, every one of hers, then no Show more`,
      said.cards.length === 60 && every.every((id) => all.has(id)) && !said.more);
    check(`Ines ${width}: nothing sideways`, !said.sideways);
    await shot(page, `ines_${width}_${theme}_all.png`);
    await context.close();
  }
  // With no script: each page a page of its own.
  const third = await stand.serverPage(path.join(root, "api"), "/u/ines-many?tab=models&page=3&tests=1");
  const grid = /<div class="models" data-models[^>]*>([\s\S]*?)<\/div>\s*<p class="paging">/.exec(third.html)?.[1] || "";
  // A card is an article, its id its own (web/card.js).
  const cards = [...grid.matchAll(/<article class="model" data-id="(InesMod\d{3})"/g)].map((one) => one[1]);
  check(`page 3 as served: ${cards.length} cards (${cards[0]}…${cards[cards.length - 1]}), no Show more, back to the first`,
    third.status === 200 && cards.length === 12 && !third.html.includes("data-more") && third.html.includes("Back to the first"));
  const nobody = await stand.serverPage(path.join(root, "api"), "/u/nobody-here");
  check(`a handle nobody has: ${nobody.status}`, nobody.status === 404);

  console.log("5. Your own page shows what you earned, as everybody sees it on your page");
  const theirs = await stand.serverPage(path.join(root, "api"), "/u/sam-builds");
  const shownToAll = [...theirs.html.matchAll(/<li data-award="([a-z]+)"/g)].map((one) => one[1]);
  for (const width of widths) {
    const theme = themes[0];
    const phone = width < 600;
    const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
      ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
    await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api") });
    await context.addInitScript(([key, value, access]) => {
      try {
        localStorage.setItem(key, value);
        if (access) sessionStorage.setItem("brickworks.access", access);
      } catch { /* a browser that keeps nothing */ }
    }, standSession());
    const page = await context.newPage();
    listen(page, `your page ${width}`);
    await page.goto(`${site}/profile`, { waitUntil: "load", timeout: 60000 });
    await until(page, () => document.documentElement.dataset.profile === "ready");
    const mine = await page.evaluate(() => [...document.querySelectorAll("#awards-shown .awards li")]
      .map((li) => `${li.dataset.award}:${li.textContent.trim()}`));
    check(`your page ${width} ${theme}: ${mine.join(" · ") || "(none)"}, as /u/sam-builds shows everybody (${shownToAll.join(", ")})`,
      mine.length > 0 && mine.map((one) => one.split(":")[0]).join(",") === shownToAll.join(","));
    await shot(page, `yours_${width}_${theme}.png`, false);
    await context.close();
  }
}

/// A throwaway account's request to the site's API.
async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

/// [count] 1 x 2 bricks, each its own step: a model small enough to share.
function stepped(name, count, rand) {
  const lines = [`0 ${name}`, `0 Name: profile_${rand}.ldr`, "0 Author: Profile Flow", `0 !BRICKWORKS PAGES {"v":1,"steps":${count}}`];
  for (let n = 0; n < count; n++) lines.push(`1 14 ${(n % 6) * 80} ${-24 * Math.floor(n / 6)} 0 1 0 0 0 1 0 0 0 1 3004.dat`, "0 STEP");
  return `${lines.join("\r\n")}\r\n`;
}

/// The app's finding of [text] as the Share panel sends it: all four passed.
const finding = (text, count) => ({ v: 1, app: "0.3.0", model: modelHash(text), steps: count, parts: count,
  tests: Object.fromEntries(["stands", "steps", "parts", "whole"].map((name) => [name, { ok: true, why: "The profile flow's model" }])) });

/// What [handle]'s page answers it earned (?op=profile), by id: "listed,built".
async function earned(handle) {
  const r = await api(`/api/people?op=profile&handle=${handle}&tests=1`);
  return r.status === 200 ? (r.json?.achievements || []).map((one) => one.id).join(",") : `HTTP ${r.status}`;
}

async function deployed() {
  const rand = randomBytes(4).toString("hex");
  const adaEmail = `delivered+bw-profile-ada-${rand}@resend.dev`;
  const bobEmail = `delivered+bw-profile-bob-${rand}@resend.dev`;
  const cyEmail = `delivered+bw-profile-cy-${rand}@resend.dev`;
  const ADA = `profile-ada-${rand}`;
  const CY = `profile-cy-${rand}`;
  const made = [];
  const others = [];
  let ada = null;
  let bob = null;
  let cy = null;
  try {
    console.log("1. Ada makes a profile, lists two models, and chooses what her page shows");
    ada = await mintSession(adaEmail);
    bob = await mintSession(bobEmail);
    let r = await api("/api/people?op=profile", { method: "POST", token: ada.access_token,
      body: { handle: ADA, name: "Ada Profile", bio: "Castles and small machines, for the profile flow." } });
    check(`Ada's profile: ${r.status} /u/${r.json?.handle}`, r.status === 200 && r.json?.handle === ADA);
    let marks = await earned(ADA);
    check(`a profile alone has earned nothing: "${marks}"`, marks === "");
    const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
    for (const [file, name] of [["castle.ldr", "Profile Castle"], ["lighthouse.ldr", "Profile Lighthouse"]]) {
      r = await api("/api/share", { method: "POST", token: ada.access_token, body: { name: `${name} ${rand}`, author: "Ada Profile",
        model: readFileSync(path.join(root, "models", file), "utf8"), image: picture, listed: true, kind: "castle",
        tags: "profile flow", licence: "cc-by-4.0" } });
      check(`listed ${name}: ${r.status} ${r.json?.id}`, r.status === 201 && ID.test(String(r.json?.id || "")));
      made.push(r.json?.id);
    }
    marks = await earned(ADA);
    check(`listed, she has her first model listed: "${marks}"`, marks === "listed");
    {
      // A model the app tested as she shared it.
      const text = stepped(`Profile Tested ${rand}`, 6, rand);
      r = await api("/api/share", { method: "POST", token: ada.access_token, body: { name: `Profile Tested ${rand}`,
        author: "Ada Profile", model: text, image: picture, listed: true, tested: finding(text, 6) } });
      check(`a Tested one listed: ${r.status} ${r.json?.id}, Tested ${r.json?.tested?.passed}`, r.status === 201 && r.json?.tested?.passed === true);
      made.push(r.json?.id);
    }
    marks = await earned(ADA);
    check(`...and Tested: "${marks}"`, marks === "tested,listed");
    {
      // Bob lists a model, and Ada posts a photo of her real build of it.
      r = await api("/api/share", { method: "POST", token: bob.access_token, body: { name: `Profile Bob's ${rand}`, author: "Bob Profile",
        model: readFileSync(path.join(root, "models", "castle.ldr"), "utf8"), image: picture, listed: true } });
      others.push([r.json?.id, bob]);
      const png = readFileSync(path.join(root, "web/share.png"));
      const start = await api("/api/people?op=photo_start", { method: "POST", token: ada.access_token,
        body: { model: r.json?.id, type: "image/png", size: png.length } });
      const sent = start.status === 200 ? await fetch(start.json.upload, { method: "PUT", headers: { "content-type": "image/png" }, body: png }) : null;
      const kept = start.status === 200 ? await api("/api/people?op=photo", { method: "POST", token: ada.access_token,
        body: { model: r.json?.id, ticket: start.json.ticket } }) : start;
      check(`her photo of her build of Bob's model: ${start.status}, ${sent?.status ?? "-"}, ${kept.status}`, kept.status === 201);
    }
    marks = await earned(ADA);
    check(`...and her first build finished: "${marks}"`, marks === "tested,listed,built");
    {
      // Her castle built to its last step on ten devices (the desktop app's finish).
      const counted = [];
      for (let n = 0; n < 10; n += 1) {
        const one = await fetch(`${site}/api/share?op=built&id=${made[0]}`, { method: "POST", body: JSON.stringify({ device: randomBytes(16).toString("hex") }),
          headers: { ...headers, "content-type": "application/json", "user-agent": "Brickworks/0.3.0 (desktop)" } });
        counted.push((await one.json().catch(() => ({}))).counted === true);
      }
      check(`her castle finished on ten devices: ${counted.filter(Boolean).length} counted`, counted.every(Boolean));
    }
    marks = await earned(ADA);
    check(`...and ten builds of her models, the rarest first: "${marks}"`, marks === "ten,tested,listed,built");

    // Refused whether or not profile_shows.sql is applied: each is checked first.
    const refused = [
      ["signed out", null, { links: ["https://ada.example"] }, 401],
      ["a link not https", ada, { links: ["http://ada.example"] }, 400],
      ["three links", ada, { links: ["https://a.example", "https://b.example", "https://c.example"] }, 400],
      ["javascript:", ada, { links: ["javascript:alert(1)"] }, 400],
      ["four pins", ada, { pins: ["AAAAAAAAAA", "BBBBBBBBBB", "CCCCCCCCCC", "DDDDDDDDDD"] }, 400],
      ["a model not hers", ada, { pins: ["AAAAAAAAAA"] }, 422],
      ["Bob pinning Ada's model", bob, { pins: [made[0]] }, 422],
    ];
    for (const [what, who, body, status] of refused) {
      r = await api("/api/people?op=showcase", { method: "POST", token: who?.access_token, body });
      check(`refused, ${what}: ${r.status} "${r.json?.error}"`, r.status === status);
    }
    r = await api("/api/people?op=showcase", { method: "POST", token: ada.access_token,
      body: { links: ["ada-builds.example/castles", "https://www.flickr.com/photos/ada"], banner: made[1], pins: [made[1], made[0]] } });
    const applied = r.status === 200;
    check(applied ? `kept: links ${r.json.links.join(", ")}, banner ${r.json.banner}, pins ${r.json.pins.join(", ")}`
      : `not open yet: ${r.status} "${r.json?.error}"`, applied ? r.json.links[0] === "https://ada-builds.example/castles"
      && r.json.banner === made[1] && r.json.pins.join(",") === `${made[1]},${made[0]}`
      : r.status === 503 && /not open on Brickworks yet/.test(r.json?.error || ""));
    const me = await api("/api/people?op=me", { token: ada.access_token });
    check(`her account page has them to choose from: ${me.json?.showcase?.models?.length} models`,
      me.status === 200 && me.json.showcase.ready === applied && me.json.showcase.models.length === 3);

    console.log("2. Her page, at both widths and themes, signed out and as Bob");
    for (const width of widths) {
      for (const theme of themes) {
        for (const who of ["out", "in"]) {
          const label = `Ada ${width} ${theme} ${who}`;
          const signedIn = who === "in" ? [STORAGE_KEY, JSON.stringify(bob.kept), ""] : null;
          const { page, context } = await open(`/u/${ADA}?tests=1`, { width, theme, label, signedIn });
          await until(page, () => !document.querySelector("button[data-follow]")?.hidden);
          const said = await drawn(page);
          headHolds(said, label, { name: "Ada Profile", handle: ADA, phone: width < 600 });
          check(`${label}: her 3 models; the Models tab shown`, said.panel === "models" && said.cards.length === 3
            && said.cards.every((id) => made.includes(id)) && said.tabs[0].n === "3");
          check(`${label}: what she earned, after her numbers: ${said.awards.map((one) => one.text).join(" · ")}`,
            said.awards.map((one) => one.id).join(",") === "ten,tested,listed,built" && said.awards.every((one) => one.icon)
            && said.awardsAfter);
          check(applied ? `${label}: links, the lighthouse across the top, pins in her order`
            : `${label}: no links, banner or pins before profile_shows.sql`, applied
            ? said.links.length === 2 && said.banner === `/m/${made[1]}.png` && said.pins.join(",") === `${made[1]},${made[0]}`
            : said.links.length === 0 && !said.banner && said.pins.length === 0);
          await shot(page, `ada_${width}_${theme}_${who}.png`);
          await context.close();
        }
      }
    }

    console.log("3. Cy had a profile and a model in the gallery, then said he is under 13");
    cy = await mintSession(cyEmail);
    r = await api("/api/people?op=profile", { method: "POST", token: cy.access_token, body: { handle: CY, name: "Cy Profile" } });
    const cys = await api("/api/share", { method: "POST", token: cy.access_token, body: { name: `Profile Cy ${rand}`, author: "Cy Profile",
      model: readFileSync(path.join(root, "models", "castle.ldr"), "utf8"), image: picture, listed: true } });
    others.push([cys.json?.id, cy]);
    marks = await earned(CY);
    check(`before: /u/${CY} shows his first model listed ("${marks}")`, r.status === 200 && marks === "listed");
    // As an account from before the age question stands once it answers
    // under 13: its row says so (answer_age would also take its models out
    // of the gallery; here they stay in it, the harder case).
    const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
    const secret = process.env.SUPABASE_SECRET_KEY || "";
    const said = await fetch(`${base}/rest/v1/profiles?id=eq.${cy.kept.user_id}`, { method: "PATCH",
      headers: { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json", prefer: "return=minimal" },
      body: JSON.stringify({ over_13: false, age_asked_at: new Date().toISOString() }) });
    const page = await fetch(`${site}/u/${CY}?tests=1`, { headers });
    const body = await page.text();
    const json = await api(`/api/people?op=profile&handle=${CY}&tests=1`);
    check(`after (${said.status}): his page ${page.status}, its answer ${json.status}, neither naming what he earned`,
      said.ok && page.status === 404 && json.status === 404 && !/First model listed|data-award/.test(body)
      && !/achievements|First model listed/.test(JSON.stringify(json.json || {})));
    {
      const width = widths[0];
      const phone = width < 600;
      const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: themes[0],
        extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
      await context.addInitScript(([key, value]) => {
        try { localStorage.setItem(key, value); } catch { /* a browser that keeps nothing */ }
      }, [STORAGE_KEY, JSON.stringify(cy.kept)]);
      const his = await context.newPage();
      listen(his, `Cy's own page ${width}`);
      await his.goto(`${site}/profile`, { waitUntil: "load", timeout: 60000 });
      await until(his, () => document.documentElement.dataset.profile === "ready", undefined, 45000);
      const own = await his.evaluate(() => ({ young: document.documentElement.dataset.young,
        awards: document.querySelectorAll("#awards-shown li, .awards li").length,
        told: document.getElementById("young")?.hidden === false }));
      check(`his own /profile at ${width}: under 13 said (${own.young}), no achievements (${own.awards})`,
        own.young === "yes" && own.told && own.awards === 0);
      await shot(his, `cy_own_${width}.png`, false);
      await context.close();
    }
  } finally {
    for (const id of made) {
      if (id && ada) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: ada.access_token }).catch(() => {});
    }
    for (const [id, who] of others) {
      if (id && who) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who.access_token }).catch(() => {});
    }
    const account = ada?.kept?.user_id;
    // Ada's by the site's own Delete account, which deletes her photo's file
    // by name first; the others' as every flow's.
    const hers = ada ? await api("/api/account?op=delete", { method: "POST", token: ada.access_token, body: { confirm: adaEmail } }) : null;
    const gone = [hers?.status === 200 || await deleteAccount(adaEmail), await deleteAccount(bobEmail), await deleteAccount(cyEmail)];
    check(`the throwaway accounts deleted (Ada's by Delete account: ${hers?.status})`, gone.every(Boolean));
    const page = await api(`/u/${ADA}?tests=1`);
    check(`her page after: ${page.status}`, page.status === 404);
    // Her row of profile_shows, gone with her account (on delete cascade).
    // A deployment answers /__held/ with a page, not JSON: only a relay holds rows.
    const held = remote ? await fetch(`${site}/__held/profile_shows`).then((a) => (a.ok ? a.json() : null)).catch(() => null) : null;
    if (held) {
      console.log("  --    the relay holds profile_shows in memory: the cascade is the dry run's (tools/profile_shows_try.sql)");
    } else if (account && process.env.SUPABASE_URL) {
      const base = String(process.env.SUPABASE_URL).replace(/\/+$/, "");
      const secret = process.env.SUPABASE_SECRET_KEY || "";
      const rows = await fetch(`${base}/rest/v1/profile_shows?account=eq.${account}&select=account`,
        { headers: { apikey: secret, authorization: `Bearer ${secret}` } });
      const left = rows.ok ? await rows.json().catch(() => null) : null;
      check(`her row of profile_shows after: ${rows.status === 404 ? "no table yet" : `${left?.length ?? `HTTP ${rows.status}`} rows`}`,
        rows.status === 404 || (Array.isArray(left) && left.length === 0));
    }
  }
}

try {
  console.log(`profile flow: ${remote || `${root} (its web/ and api/, the stand-in's people)`}`);
  if (remote) await deployed();
  else await local();
} catch (trouble) {
  check(`ran: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  await browser.close();
}
for (const error of errors) check(`no script error: ${error}`, false);
console.log(`\nprofile flow: ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
