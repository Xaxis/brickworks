// The directory of collections (walk256 W12, supabase/collection_directory.sql,
// api/people.js collectionsPage), in real browsers at 390 and 1280 px, light
// and dark: /collections lists the public collections as cards, each with
// its cover, its name, whose, how many models and Follow.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/collections_flow.mjs --url=<preview> --out=DIR
//   node --env-file=.env tools/web/relay_server.mjs 9310 --static=web &
//   node --env-file=.env tools/web/collections_flow.mjs --url=http://127.0.0.1:9310 --out=DIR
//
// The live project's tables, so collection_directory.sql applied; before it
// the page says collections are not listed yet, and the flow says so and
// fails. Throwaway accounts at Resend test addresses, deleted at the end
// with their models and collections; test accounts, so their collections
// are listed only where ?tests=1 asks, as every list of the site has it.
//
//   1. Ada makes a profile, shares a tower in the gallery and puts it in a
//      public collection and in a private one.
//   2. A visitor: /collections?tests=1 has her public one as a card (its
//      cover a picture of the tower, its name, Ada and her avatar, 1 model,
//      Follow), and never the private one; the address with no tests says
//      what is there or that there is nothing yet, never a 404; the
//      gallery links to it.
//   3. Bob, signed in, at 390 px: Follow on the card, Following, pressed,
//      "1 follower" on the card, and the API agrees; Most followed lists it
//      with its follower.
//   4. At 390 and 1280 px, light and dark: the page, its tabs and its cards,
//      nothing sideways.
//   5. Made private: gone from the directory.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
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
const site = String(args.url || "http://127.0.0.1:9310").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/collections"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-dir-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-dir-bob-${rand}@resend.dev`;
const ADA = `bwd-ada-${rand}`;
const LIST = `Towers worth a weekend ${rand}`;
const HIDDEN = `Not for anyone ${rand}`;
const TOWER = `Collections Flow Tower ${rand}`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: dir.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // collections flow ${rand}\r\n`;

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, dark = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", isMobile: width < 600, hasTouch: width < 600 });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

const shot = (page, name, full = true) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}
const text = async (pathname) => {
  const reply = await fetch(`${site}${pathname}`, { headers });
  return { status: reply.status, html: await reply.text() };
};

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

/// The directory as drawn: its title, tabs, cards and empty state, and
/// whether the page scrolls sideways.
const drawn = (page) => page.evaluate(() => ({
  title: document.querySelector("main h1")?.textContent || "",
  tabs: [...document.querySelectorAll("main .tabs a")].map((a) => `${a.textContent}${a.getAttribute("aria-current") ? "*" : ""}`),
  cards: [...document.querySelectorAll("#collections .list-card")].map((card) => ({
    id: card.dataset.id, name: card.querySelector(".name b")?.textContent || "",
    who: card.querySelector("a.who")?.getAttribute("href") || "", avatar: Boolean(card.querySelector("a.who .avatar")),
    numbers: [...card.querySelectorAll(".numbers > span")].filter((one) => !one.hidden).map((one) => one.textContent.trim()).join(" · "),
    pictures: [...card.querySelectorAll(".mosaic img")].map((img) => ({ src: img.getAttribute("src"), drawn: img.complete && img.naturalWidth > 0 })),
    follow: (() => { const b = card.querySelector("button[data-follow-list]"); return b ? { shown: !b.hidden, text: b.textContent, pressed: b.getAttribute("aria-pressed") } : null; })(),
    link: card.querySelector("a.name")?.getAttribute("href") || "" })),
  empty: document.getElementById("collections-empty")?.textContent.replace(/\s+/g, " ").trim() || "",
  sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
}));

let ada = null;
let bob = null;
let tower = "";
let listId = "";
let hiddenId = "";
try {
  // --- 1. Ada's tower and her collections ------------------------------------
  console.log("Ada shares a tower and puts it in a public collection and a private one");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  const profile = await api("/api/people?op=profile", { method: "POST", token: ada.access_token,
    body: { handle: ADA, name: "Ada Collects" } });
  const shared = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: TOWER, author: "Ada Collects", model: model(TOWER), image: picture, listed: true } });
  tower = shared.body.id || "";
  const list = await api("/api/people?op=collection", { method: "POST", token: ada.access_token,
    body: { name: LIST, description: "Towers that stand at every step.", public: true } });
  listId = list.body.id || "";
  const hidden = await api("/api/people?op=collection", { method: "POST", token: ada.access_token,
    body: { name: HIDDEN, public: false } });
  hiddenId = hidden.body.id || "";
  const put = await api("/api/people?op=collect", { method: "POST", token: ada.access_token,
    body: { collection: listId, model: tower, on: true } });
  const putHidden = await api("/api/people?op=collect", { method: "POST", token: ada.access_token,
    body: { collection: hiddenId, model: tower, on: true } });
  check(`her profile ${profile.status}, the tower /m/${tower} ${shared.status}, /c/${listId} public and /c/${hiddenId} private, `
    + `the tower in both (${put.status}, ${putHidden.status})`, profile.status === 200 && shared.status === 201
    && list.status === 200 && list.body.public === true && hidden.status === 200 && hidden.body.public === false
    && put.status === 200 && putHidden.status === 200);

  // --- 2. A visitor ------------------------------------------------------------
  console.log("a visitor's /collections");
  {
    const visitor = await context();
    const page = await visitor.newPage();
    listen(page, "visitor");
    const opened = await page.goto(`${site}/collections?tests=1`, { waitUntil: "load" });
    const seen = await drawn(page);
    const card = seen.cards.find((one) => one.id === listId);
    check(`/collections?tests=1 ${opened.status()}: "${seen.title}", tabs ${seen.tabs.join(" · ")}, ${seen.cards.length} cards`,
      opened.status() === 200 && seen.title === "Collections" && seen.tabs.length === 2 && seen.tabs[0].endsWith("*"));
    check(`her public one is a card: "${card?.name}", ${card?.who}, "${card?.numbers}", ${card?.pictures.length} picture`
      + `${card?.avatar ? ", her avatar" : ""}, its name a link to ${card?.link}`, Boolean(card) && card.name === LIST
      && card.who === `/u/${ADA}` && card.avatar && /^1 model\b/.test(card.numbers) && card.pictures.length === 1
      && card.link === `/c/${listId}`);
    await until(page, (id) => [...document.querySelectorAll(`#collections [data-id="${id}"] .mosaic img`)]
      .every((img) => img.complete && img.naturalWidth > 0), "its cover drawn", 30, listId).catch(() => null);
    const cover = (await drawn(page)).cards.find((one) => one.id === listId);
    check(`...its cover the tower's picture, drawn (${cover?.pictures[0]?.src})`, Boolean(cover?.pictures[0]?.drawn)
      && String(cover.pictures[0].src).startsWith(`/m/${tower}`));
    const follow = await until(page, (id) => {
      const b = document.querySelector(`#collections [data-id="${id}"] button[data-follow-list]`);
      return b && !b.hidden ? b.textContent : null;
    }, "Follow on the card", 30, listId).catch(() => "");
    check(`...and Follow on it for a visitor: "${follow}"`, follow === "Follow");
    check(`the private one never: ${seen.cards.some((one) => one.id === hiddenId) ? "shown" : "not shown"}`,
      !seen.cards.some((one) => one.id === hiddenId) && !(await page.content()).includes(HIDDEN));
    await shot(page, "1_visitor-1280-light.png");
    const plain = await text("/collections");
    check(`/collections with no tests ${plain.status}: ${plain.html.includes(listId) ? "lists a test account's" : "no test account's"}`
      + `, ${/id="collections-empty"/.test(plain.html) ? "nothing yet, said so" : "cards"}`,
      plain.status === 200 && !plain.html.includes(listId) && !plain.html.includes("There is no collection here"));
    const gallery = await page.goto(`${site}/gallery`, { waitUntil: "load" });
    const link = await page.evaluate(() => document.querySelector('#tabs a[href="/collections"]')?.textContent || "");
    const foot = await page.evaluate(() => Boolean(document.querySelector('.site-foot a[href="/collections"]')));
    check(`the gallery (${gallery.status()}) links to it: "${link}" among its tabs, and the footer${foot ? "" : " does not"}`,
      link === "Collections" && foot);
    await visitor.close();
  }

  // --- 3. Bob follows it from its card ------------------------------------------
  console.log("Bob follows it from its card, at 390 px");
  {
    const made = await context({ as: bob, width: 390, height: 844, dark: true });
    const page = await made.newPage();
    listen(page, "Bob");
    await page.goto(`${site}/collections?tests=1`, { waitUntil: "load" });
    const button = `#collections [data-id="${listId}"] button[data-follow-list]`;
    await until(page, (at) => document.querySelector(at) && !document.querySelector(at).hidden, "Follow for Bob", 30, button);
    await page.locator(button).scrollIntoViewIfNeeded();
    await page.click(button);
    await until(page, (at) => document.querySelector(at)?.getAttribute("aria-pressed") === "true", "Following", 30, button);
    const card = (await drawn(page)).cards.find((one) => one.id === listId);
    const said = await page.evaluate((at) => document.querySelector(at)?.parentElement?.querySelector(".said")?.textContent.trim() || "", button);
    check(`Follow on the card: "${card?.follow?.text}", pressed, "${card?.numbers}"; said "${said}"`,
      card?.follow?.text === "Following" && card.follow.pressed === "true" && /1 follower\b/.test(card.numbers));
    const asked = await api(`/api/people?op=list_follows&id=${listId}`, { token: bob.access_token });
    check(`...and the API agrees: you_follow ${asked.body.you_follow}, ${asked.body.followers} follower`,
      asked.status === 200 && asked.body.you_follow === true && asked.body.followers === 1);
    const many = await api(`/api/people?op=list_follows&ids=${listId},${hiddenId}`, { token: bob.access_token });
    check(`...asked for a page of cards at once: ${Object.keys(many.body.follows || {}).join(",")} (the private one left out)`,
      many.status === 200 && many.body.follows?.[listId]?.you_follow === true && !many.body.follows?.[hiddenId]);
    await shot(page, "2_followed-390-dark.png");
    await page.goto(`${site}/collections?sort=followed&tests=1`, { waitUntil: "load" });
    const followed = await drawn(page);
    const there = followed.cards.find((one) => one.id === listId);
    check(`Most followed (${followed.tabs.join(" · ")}): hers listed, "${there?.numbers}", Following`,
      followed.tabs[1]?.endsWith("*") && Boolean(there) && /1 follower\b/.test(there.numbers));
    await made.close();
  }

  // --- 4. Both widths, both themes ----------------------------------------------
  console.log("at 390 and 1280 px, light and dark");
  for (const [width, height] of [[390, 844], [1280, 900]]) {
    for (const dark of [false, true]) {
      const made = await context({ as: bob, width, height, dark });
      const page = await made.newPage();
      listen(page, `${width} ${dark ? "dark" : "light"}`);
      const opened = await page.goto(`${site}/collections?tests=1`, { waitUntil: "load" });
      await page.waitForTimeout(1200);
      const seen = await drawn(page);
      const theme = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      check(`${width} px ${dark ? "dark" : "light"}: ${opened.status()}, ${seen.cards.length} cards, background ${theme}, `
        + `${seen.sideways ? "scrolls sideways" : "nothing sideways"}`, opened.status() === 200 && seen.cards.length > 0 && !seen.sideways);
      await shot(page, `3_${width}-${dark ? "dark" : "light"}.png`);
      await made.close();
    }
  }

  // --- 5. Made private -----------------------------------------------------------
  console.log("Ada makes it private");
  const shut = await api("/api/people?op=collection", { method: "POST", token: ada.access_token,
    body: { id: listId, name: LIST, public: false } });
  const after = await text(`/collections?tests=1&asked=${Date.now()}`);
  check(`made private (${shut.status}): ${after.html.includes(listId) ? "still listed" : "gone from the directory"}`,
    shut.status === 200 && after.status === 200 && !after.html.includes(listId));
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (tower && ada) await api(`/api/share?op=unpublish&id=${tower}`, { method: "POST", token: ada.access_token }).catch(() => {});
  for (const id of [listId, hiddenId]) {
    if (id && ada) await api(`/api/people?op=uncollection&id=${id}`, { method: "POST", token: ada.access_token }).catch(() => {});
  }
  await browser.close();
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "collections: public ones as cards with covers and Follow, never a private one, at 390 and 1280 in both themes");
process.exit(failed ? 1 : 0);
