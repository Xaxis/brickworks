// Your sets and lists (lists1, docs/LISTS.md, web/keep.js, web/lists.js,
// api/_mylists.js), in real browsers at 1280 px and at 430 px with touch,
// light and dark, as people use it:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/lists_flow.mjs --url=<preview> --out=DIR
//   node --env-file=.env tools/web/relay_server.mjs 10081 --static=web &
//   node --env-file=.env tools/web/lists_flow.mjs --url=http://127.0.0.1:10081 --out=DIR
//
// The live project's tables, so supabase/lists.sql applied. Throwaway
// accounts at Resend test addresses, deleted at the end with everything of
// theirs (their collection, lists and models go with the account).
//
//   1. Signed out, Own on a set's card asks to sign in, saying why.
//   2. Ada: Own on a set's card in the library, pressed at once, the toast's
//      Undo takes it back, Own again; the server agrees each time.
//   3. Her set's page: Own and Want pressed from the bar; its lists'
//      panel makes a new list there with the set in it.
//   4. The gallery: her model's card's panel puts it in the same list.
//   5. /lists: the list holds both; Your order and an arrow move the model
//      first, the toast's Undo puts it back; made public it is a page Bob
//      and a visitor see and can share (its social card names it); made
//      private again, neither does.
//   6. The sets she owns on her profile once she chooses: the Sets tab, its
//      numbers, a theme filter and a search.
//   7. A small Rebrickable CSV brought in, its set owned; the sets she owns
//      downloaded as a CSV holding them.
//   8. At 430 px with touch, dark: Own on a card, the panel as a sheet, the
//      lists page with its dropdown, nothing sideways anywhere.
//   9. Undo puts back exactly what its step changed: Own off and back gives
//      the copy with its source and missing parts; a list that already held
//      an item adds nothing; an item taken out goes back to its place.
//
// And lists2a (docs/LISTS.md section 5), on the same accounts:
//   4b. One Save: a model's page has the card's control, one panel, the
//      same op=keep; no panel of its own.
//   5b. Shared by its link (supabase/lists_link.sql applied): Share on a
//      private list asks, Anyone with the link chosen; the link opens it for
//      Bob and a visitor, kept by no cache and no search engine; without
//      its key or with another, 404; absent from her profile, the
//      directory, its search and the sitemap; Stop sharing, and the next
//      request for the link is a 404; shared again, a new key.
//   7. Add sets shows what it adds first: to add, already there and not
//      found, counted as this flow reckons them; Cancel writes nothing, Add
//      writes what it showed; a list's own Add sets the same.
//
// Pictures of every step in --out, light and dark at both widths.
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
const site = String(args.url || "http://127.0.0.1:10081").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/lists"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-lists-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-lists-bob-${rand}@resend.dev`;
const ADA = `bwl-ada-${rand}`;
const LIST = `Castles to build ${rand}`;
const TOWER = `Lists Flow Tower ${rand}`;
// Two sets the catalogue has: King's Castle, and Galaxy Explorer, brought in
// from a file.
const SET = "6080-1";
const IMPORTED = "10497-1";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: lists.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // lists flow ${rand}\r\n`;

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, dark = false } = {}) {
  const phone = width < 600;
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", isMobile: phone, hasTouch: phone, acceptDownloads: true });
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

// The viewport, never the whole page: a full-page picture of a phone draws
// its mouse's controls (fullpage-shot-drops-touch).
// Each once what is opening has opened (a dialog rises and fades in).
const shot = async (page, name) => {
  await page.waitForFunction(() => document.getAnimations().every((one) => one.playState !== "running" || one.effect?.getTiming().iterations === Infinity),
    null, { timeout: 3000 }).catch(() => null);
  await page.screenshot({ path: path.join(out, name), timeout: 90000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let json = {};
  try { json = JSON.parse(text); } catch { json = {}; }
  return { status: reply.status, body: json, text };
}

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

async function untilApi(test, what, seconds = 20) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await test().catch(() => null);
    if (value) return value;
    if (Date.now() > end) return null;
    await new Promise((done) => setTimeout(done, 400));
  }
}

/// [page] at [where], once what its cards' controls show is answered (one
/// op=keeps for the page) and a gallery's list is drawn: a card pressed
/// before that may be one the list is about to replace.
async function visit(page, where) {
  const answered = page.waitForResponse((reply) => reply.url().includes("op=keeps"), { timeout: 60000 }).catch(() => null);
  await page.goto(`${site}${where}`, { waitUntil: "load" });
  await answered;
  if (/^\/(gallery|library)/.test(where)) {
    await until(page, () => !document.documentElement.dataset.browse || document.documentElement.dataset.browse === "ready",
      "the list drawn", 30).catch(() => null);
  }
  await page.waitForTimeout(300);
}

const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const pressed = (page, selector) => page.evaluate((s) => document.querySelector(s)?.getAttribute("aria-pressed") || "", selector);
const keeps = (who, sets = "", models = "") => api(`/api/people?op=keeps&sets=${sets}&models=${models}`, { token: who.access_token });
const ownedOf = async (who, set) => Number((await keeps(who, set)).body?.sets?.[set]?.own ?? -1);
const toastSays = (page) => until(page, () => {
  const t = document.querySelector("body > .toast.shown");
  return t && t.textContent.trim() ? t.textContent.trim() : null;
}, "the toast", 15);
/// The page's own line (#said) once it says [pattern]: what is done and
/// cannot be undone is said there alone, with no toast (web/lists.js tell).
const lineSays = (page, pattern) => until(page, (source) => {
  const words = document.getElementById("said")?.textContent.trim() || "";
  return new RegExp(source).test(words) ? words : null;
}, `the page's line: ${pattern}`, 15, pattern.source);

let ada = null;
let bob = null;
let tower = "";
let listId = "";
let current = null;
try {
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  const profile = await api("/api/people?op=profile", { method: "POST", token: ada.access_token,
    body: { handle: ADA, name: "Ada Lists" } });
  const shared = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: TOWER, author: "Ada Lists", model: model(TOWER), image: picture, listed: true } });
  tower = shared.body.id || "";
  check(`Ada's profile ${profile.status}, her tower /m/${tower} ${shared.status}`, profile.status === 200 && shared.status === 201);

  // --- 1. Signed out --------------------------------------------------------
  console.log("signed out: Own on a set's card asks to sign in");
  {
    const visitor = await context();
    const page = await visitor.newPage();
    listen(page, "visitor");
    await page.goto(`${site}/library?q=${SET}`, { waitUntil: "load" });
    const button = `.model .keep[data-keep="set:${SET}"] [data-keep-main]`;
    await page.waitForSelector(button, { timeout: 60000 });
    await page.click(button);
    const dialog = await until(page, () => {
      const d = document.querySelector("dialog.sign-in[open]");
      return d ? d.textContent.replace(/\s+/g, " ").trim().slice(0, 160) : null;
    }, "the sign-in dialog", 15).catch(() => "");
    check(`a visitor's Own opens the sign-in, saying why: "${dialog.slice(0, 90)}…"`, /keep the sets you own/i.test(dialog));
    await shot(page, "01_signed-out-own-1280-light.png");
    await visitor.close();
  }

  // --- 2. Own from a card -----------------------------------------------------
  console.log("Ada: Own from a set's card, Undo, Own again");
  const desk = await context({ as: ada });
  const page = await desk.newPage();
  current = page;
  listen(page, "ada");
  await visit(page, `/library?q=${SET}`);
  const own = `.model .keep[data-keep="set:${SET}"] [data-keep-main]`;
  await page.waitForSelector(own, { timeout: 60000 });
  check(`the card's Own not pressed before: ${await pressed(page, own)}`, (await pressed(page, own)) === "false");
  await page.click(own);
  check(`pressed at once: ${await pressed(page, own)}`, (await pressed(page, own)) === "true");
  const said = await toastSays(page).catch(() => "");
  const owned1 = await untilApi(async () => ((await ownedOf(ada, SET)) === 1 ? 1 : null), "owned");
  check(`the toast: "${said}", and the server: ${owned1 ?? "not"} owned`, /in the sets you own/i.test(said) && /Undo/.test(said) && owned1 === 1);
  await shot(page, "02_card-own-toast-1280-light.png");
  await page.click("body > .toast .toast-act");
  const undone = await untilApi(async () => ((await ownedOf(ada, SET)) === 0 ? "none" : null), "undone");
  await until(page, (s) => document.querySelector(s)?.getAttribute("aria-pressed") === "false", "unpressed", 10, own).catch(() => null);
  check(`Undo: ${await pressed(page, own)} on the card, the server owns ${undone ?? "still one"}`, undone === "none"
    && (await pressed(page, own)) === "false");
  await page.click(own);
  const owned2 = await untilApi(async () => ((await ownedOf(ada, SET)) === 1 ? 1 : null), "owned");
  check(`Own again: ${owned2 ?? 0} owned`, owned2 === 1);
  // A set owned on the site is My collection's: the app reads it there.
  const mine = await api("/api/collection", { token: ada.access_token });
  const kept = (mine.body.sets || []).filter((one) => one.set === SET);
  check(`My collection holds it as hers (src ${kept.map((one) => one.src).join(",")}, qty ${kept.map((one) => one.qty).join(",")})`,
    kept.length === 1 && kept[0].src === "hand" && kept[0].qty === 1);

  // --- 3. Its set page -------------------------------------------------------
  console.log("the set's page: Own and Want, and a new list from its panel");
  await visit(page, `/library/set/${SET}`);
  const bar = `.keep-bar[data-keep="set:${SET}"]`;
  await page.waitForSelector(`${bar} [data-keep-want]`, { timeout: 60000 });
  await until(page, (s) => document.querySelector(s)?.getAttribute("aria-pressed") === "true", "Own pressed", 20,
    `${bar} [data-keep-main]`).catch(() => null);
  check(`the page's Own pressed (she owns it): ${await pressed(page, `${bar} [data-keep-main]`)}`, (await pressed(page, `${bar} [data-keep-main]`)) === "true");
  await page.click(`${bar} [data-keep-want]`);
  const wanted = await untilApi(async () => {
    const answer = await keeps(ada, SET);
    return answer.body.want && answer.body.sets?.[SET]?.lists?.includes(answer.body.want) ? answer.body.want : null;
  }, "wanted");
  check(`Want: pressed ${await pressed(page, `${bar} [data-keep-want]`)}, on her wishlist ${wanted ? `(${wanted})` : "not"}`,
    (await pressed(page, `${bar} [data-keep-want]`)) === "true" && Boolean(wanted));
  await shot(page, "03_set-page-own-want-1280-light.png");
  await page.click(`${bar} [data-keep-more]`);
  await page.waitForSelector("dialog.keep-panel[open]", { timeout: 15000 });
  const rows = await page.evaluate(() => [...document.querySelectorAll("dialog.keep-panel .keep-row")]
    .map((row) => `${row.querySelector(".keep-name")?.textContent}${row.querySelector("input")?.checked ? "*" : ""}`));
  check(`its panel: ${rows.join(" · ")}`, rows[0] === "I own it*" && rows[1] === "I want it*");
  await page.click("dialog.keep-panel .keep-new-open");
  await page.fill("dialog.keep-panel .keep-new input[type=text]", LIST);
  await page.click("dialog.keep-panel .keep-new button[type=submit]");
  await until(page, (name) => [...document.querySelectorAll("dialog.keep-panel .keep-row")]
    .some((row) => row.querySelector(".keep-name")?.textContent === name && row.querySelector("input").checked), "the new list ticked", 20, LIST);
  listId = await page.evaluate((name) => [...document.querySelectorAll("dialog.keep-panel .keep-row")]
    .find((row) => row.querySelector(".keep-name")?.textContent === name)?.dataset.keepList || "", LIST);
  const inList = await untilApi(async () => ((await keeps(ada, SET)).body.sets?.[SET]?.lists?.includes(listId) ? true : null), "in the list");
  const panelSaid = await until(page, () => document.querySelector("dialog.keep-panel .said")?.textContent || null,
    "the panel says so", 10).catch(() => "");
  check(`New list… made "${LIST}" (${listId}) with the set in it: ${inList ? "yes" : "no"}; it says "${panelSaid}"`,
    /^[A-Za-z0-9]{10}$/.test(listId) && inList === true && /Made/.test(panelSaid));
  await shot(page, "04_set-page-panel-new-list-1280-light.png");
  await page.keyboard.press("Escape");
  const closed = await page.evaluate(() => !document.querySelector("dialog.keep-panel[open]"));
  const focus = await page.evaluate(() => document.activeElement?.matches("[data-keep-more]") || false);
  check(`Escape closes it${focus ? ", the keyboard back on its button" : ""}`, closed && focus);

  // --- 4. A gallery model into the same list -----------------------------------
  console.log("the gallery: her model's card into the same list");
  await visit(page, `/gallery?tests=1&q=${encodeURIComponent(TOWER)}`);
  const card = `.model[data-id="${tower}"] .keep`;
  await page.waitForSelector(`${card} [data-keep-more]`, { timeout: 60000 });
  await page.click(`${card} [data-keep-more]`);
  await page.waitForSelector(`dialog.keep-panel[open] [data-keep-list="${listId}"] input`, { timeout: 15000 });
  const modelRows = await page.evaluate(() => [...document.querySelectorAll("dialog.keep-panel .keep-row")]
    .map((row) => row.querySelector(".keep-name")?.textContent));
  await page.check(`dialog.keep-panel [data-keep-list="${listId}"] input`);
  const modelIn = await untilApi(async () => ((await keeps(ada, "", tower)).body.models?.[tower]?.lists?.includes(listId) ? true : null), "model in");
  check(`its panel (${modelRows.join(" · ")}) put it in "${LIST}": ${modelIn ? "yes" : "no"}`, modelRows[0] === "Saved" && modelIn === true);
  await shot(page, "05_gallery-card-panel-1280-light.png");
  await page.keyboard.press("Escape");
  const dot = await page.evaluate((s) => document.querySelector(`${s} [data-keep-more]`)?.hasAttribute("data-in"), card);
  check(`its card marks it as in a list: ${dot}`, dot === true);

  // --- 4b. One Save: the model's page has the card's (lists2a) ----------------
  console.log("the model's page: Save is the card's, one panel");
  const keepPosts = [];
  const heard = (request) => {
    if (request.method() === "POST" && /\/api\/people\?op=/.test(request.url())) keepPosts.push(new URL(request.url()).searchParams.get("op"));
  };
  page.on("request", heard);
  await visit(page, `/m/${tower}`);
  const onPage = `.action-bar .keep[data-keep="model:${tower}"]`;
  await page.waitForSelector(`${onPage} [data-keep-main]`, { timeout: 60000 });
  const one = await page.evaluate((id) => ({ keeps: document.querySelectorAll(`.action-bar .keep[data-keep="model:${id}"]`).length,
    panel: Boolean(document.getElementById("save-panel")), marks: document.querySelectorAll('.action-bar [data-mark="save"]').length }), tower);
  check(`its bar has one Save, the card's (${one.keeps}), and no panel of its own (${one.panel ? "there" : "none"}, ${one.marks} old buttons)`,
    one.keeps === 1 && !one.panel && one.marks === 0);
  await page.click(`${onPage} [data-keep-main]`);
  const savedNow = await untilApi(async () => ((await keeps(ada, "", tower)).body.models?.[tower]?.saved ? true : null), "saved");
  check(`Save keeps it in Saved: ${savedNow ? "yes" : "no"}, pressed ${await pressed(page, `${onPage} [data-keep-main]`)}`,
    savedNow === true && (await pressed(page, `${onPage} [data-keep-main]`)) === "true");
  await page.click(`${onPage} [data-keep-more]`);
  await page.waitForSelector(`dialog.keep-panel[open] [data-keep-list="${listId}"] input`, { timeout: 15000 });
  const pageRows = await page.evaluate(() => [...document.querySelectorAll("dialog.keep-panel .keep-row")]
    .map((row) => row.querySelector(".keep-name")?.textContent));
  const ticks = await page.evaluate((id) => ({ saved: document.querySelector("dialog.keep-panel .keep-row input")?.checked,
    list: document.querySelector(`dialog.keep-panel [data-keep-list="${id}"] input`)?.checked,
    panels: document.querySelectorAll("dialog.keep-panel").length }), listId);
  check(`its arrow opens the card's panel (${pageRows.join(" · ")}), Saved and "${LIST}" ticked, one panel in the page`,
    pageRows.join("|") === modelRows.join("|") && ticks.saved === true && ticks.list === true && ticks.panels === 1);
  await shot(page, "05b_model-page-save-1280-light.png");
  await page.keyboard.press("Escape");
  await page.click(`${onPage} [data-keep-main]`);
  const letGo = await untilApi(async () => ((await keeps(ada, "", tower)).body.models?.[tower]?.saved === false ? true : null), "let go");
  page.off("request", heard);
  check(`pressed again it is let go (${letGo ? "yes" : "no"}); both went by op=keep alone: ${keepPosts.join(", ")}`,
    letGo === true && keepPosts.length >= 2 && keepPosts.every((op) => op === "keep"));

  // --- 5. /lists ---------------------------------------------------------------
  console.log("/lists: her list, its order, public and private");
  await page.goto(`${site}/lists?list=${listId}`, { waitUntil: "load" });
  await page.waitForSelector("#items .model[data-key]", { timeout: 60000 });
  const order = () => page.evaluate(() => [...document.querySelectorAll("#items .model[data-key]")].map((one) => one.dataset.key));
  const first = await order();
  check(`it holds the model and the set, newest first: ${first.join(", ")}`, first.length === 2 && first[0] === `model:${tower}`
    && first[1] === `set:${SET}`);
  const head = await page.evaluate(() => ({ h: document.getElementById("view-h").textContent, meta: document.getElementById("view-meta").textContent,
    rail: document.querySelector('#rail a[aria-current="page"]')?.textContent || "" }));
  check(`its head: "${head.h}", "${head.meta}"; the rail marks "${head.rail}"`, head.h === LIST && /1 set/.test(head.meta) && /1 model/.test(head.meta)
    && /Only you/.test(head.meta) && head.rail.startsWith(LIST));
  const shown = await until(page, (key) => document.querySelector(`#items .model[data-key="${key}"] [data-keep-main]`)
    ?.getAttribute("aria-pressed") === "true", "its set card's Own", 30, `set:${SET}`).then(() => true, () => false);
  check(`its set card shows Own pressed: ${shown}`, shown);
  await shot(page, "06_lists-page-1280-light.png");
  await page.click('#order button[data-sort="manual"]');
  await page.waitForSelector("#items .model .moves button:not(:disabled)", { timeout: 15000 });
  await page.click(`#items .model[data-key="set:${SET}"] .moves button:first-child`);
  await page.waitForTimeout(400);
  check(`an arrow moved the set first: ${(await order()).join(", ")}`, (await order())[0] === `set:${SET}`);
  const moved = await toastSays(page).catch(() => "");
  const placed = await untilApi(async () => {
    const answer = await api(`/api/people?op=list_items&id=${listId}`, { token: ada.access_token });
    return answer.body.sort === "manual" && answer.body.items?.[0]?.key === `set:${SET}` ? answer.body.items.map((one) => one.key) : null;
  }, "placed");
  check(`the server keeps her order (${placed?.join(", ") || "not"}); the toast: "${moved}"`, Boolean(placed) && /moved to 1 of 2/i.test(moved));
  await shot(page, "07_lists-order-1280-light.png");
  await page.click("body > .toast .toast-act");
  const back = await untilApi(async () => {
    const answer = await api(`/api/people?op=list_items&id=${listId}`, { token: ada.access_token });
    return answer.body.items?.[0]?.key === `model:${tower}` ? true : null;
  }, "back");
  await until(page, (key) => document.querySelector("#items .model[data-key]")?.dataset.key === key, "redrawn", 15, `model:${tower}`).catch(() => null);
  check(`Undo put it back: the server ${back ? "agrees" : "does not"}, the page ${(await order()).join(", ")}`, back === true
    && (await order())[0] === `model:${tower}`);

  // Public: a page Bob and a visitor see, with its social card, and Share.
  await page.click("#edit");
  await page.waitForSelector("dialog.lists-dialog[open] fieldset.who-sees");
  await page.check('dialog.lists-dialog fieldset.who-sees input[value="public"]');
  await page.click('dialog.lists-dialog button[type="submit"]');
  const made = await untilApi(async () => ((await api(`/api/people?op=list_items&id=${listId}`)).status === 200 ? true : null), "public");
  check(`made public: a visitor's list_items ${made ? "200" : "refused"}`, made === true);
  // Share shows on a private list too since lists2a (994baf213, 11-22), where
  // it asks who may open it: pressed before the page has heard the save, it
  // asks that, not the sheet. The page says the save once it has redrawn.
  await lineSays(page, /^Saved: it is public\.$/).catch(() => "");
  await page.waitForSelector("#share:not([hidden])", { timeout: 15000 });
  await page.click("#share");
  const sheet = await until(page, () => document.querySelector("#share-sheet[open] #share-link")?.value || null, "the share sheet", 15).catch(() => "");
  check(`Share opens its sheet with its link: ${sheet}`, sheet.endsWith(`/c/${listId}`));
  await shot(page, "08_lists-share-1280-light.png");
  await page.keyboard.press("Escape");
  for (const [who, as] of [["Bob", bob], ["a visitor", null]]) {
    const other = await context({ as });
    const seen = await other.newPage();
    listen(seen, who);
    // ?tests=1: Ada is a test account, whose models only a list asked with
    // tests shows (as the gallery's); her set shows either way.
    const opened = await seen.goto(`${site}/c/${listId}?tests=1`, { waitUntil: "load" });
    const page2 = await seen.evaluate(() => ({ title: document.title, og: document.querySelector('meta[property="og:title"]')?.content || "",
      image: document.querySelector('meta[property="og:image"]')?.content || "",
      cards: [...document.querySelectorAll(".models .model")].length }));
    check(`${who} sees /c/${listId} (${opened.status()}): "${page2.title}", og:title "${page2.og}", a picture ${page2.image ? "yes" : "no"}, ${page2.cards} cards`,
      opened.status() === 200 && page2.og.includes(LIST) && Boolean(page2.image) && page2.cards === 2);
    if (who === "a visitor") await shot(seen, "09_list-page-visitor-1280-light.png");
    await other.close();
  }
  // Private again: absent to Bob and to a visitor.
  await page.click("#edit");
  await page.waitForSelector("dialog.lists-dialog[open] fieldset.who-sees");
  await page.check('dialog.lists-dialog fieldset.who-sees input[value="private"]');
  await page.click('dialog.lists-dialog button[type="submit"]');
  await untilApi(async () => ((await api(`/api/people?op=list_items&id=${listId}`)).status === 404 ? true : null), "private");
  for (const [who, token] of [["Bob", bob.access_token], ["a visitor", null]]) {
    const items = await api(`/api/people?op=list_items&id=${listId}`, { token });
    const pageAt = await api(`/c/${listId}`, { token });
    check(`private: ${who} gets list_items ${items.status} and /c/ ${pageAt.status}, its name nowhere`, items.status === 404
      && pageAt.status === 404 && !pageAt.text.includes(LIST));
  }
  const directory = await api("/api/people?op=collections&tests=1&q=" + encodeURIComponent(LIST));
  check(`not in the directory: ${(directory.body.collections || []).some((one) => one.id === listId) ? "listed" : "absent"}`,
    !(directory.body.collections || []).some((one) => one.id === listId));

  // --- 5b. Shared by its link (lists2a) -----------------------------------------
  console.log("shared by its link: by the link alone, nowhere else, and Stop sharing ends it");
  await page.goto(`${site}/lists?list=${listId}`, { waitUntil: "load" });
  await page.waitForSelector("#share:not([hidden])", { timeout: 30000 });
  await page.click("#share");
  await page.waitForSelector("dialog.lists-dialog[open] fieldset.who-sees", { timeout: 15000 });
  const asked = await page.evaluate(() => ({
    choices: [...document.querySelectorAll("dialog.lists-dialog[open] fieldset.who-sees label")].filter((one) => !one.hidden)
      .map((one) => one.querySelector("input").value),
    chosen: document.querySelector("dialog.lists-dialog[open] fieldset.who-sees input:checked")?.value || "" }));
  check(`Share on a private list asks who may open it: ${asked.choices.join(", ")}, ${asked.chosen} chosen`,
    asked.choices.join(",") === "link,public" && asked.chosen === "link");
  await shot(page, "09b_share-who-1280-light.png");
  await page.click('dialog.lists-dialog[open] button[type="submit"]');
  const linkUrl = await until(page, () => document.querySelector("#share-sheet[open] #share-link")?.value || null, "the link's sheet", 20)
    .catch(() => "");
  const key = new URL(linkUrl || "http://x/").searchParams.get("link") || "";
  if (!check(`its sheet gives its link: ${linkUrl || "none"}`, linkUrl.includes(`/c/${listId}?link=`) && /^[A-Za-z0-9_-]{22}$/.test(key))) {
    const tried = await api("/api/people?op=list_link", { method: "POST", token: ada.access_token, body: { id: listId, on: true } });
    console.log(`  --    op=list_link answers ${tried.status}: ${tried.text.slice(0, 160)} (503: supabase/lists_link.sql not applied)`);
  }
  await shot(page, "09c_share-link-sheet-1280-light.png");
  await page.keyboard.press("Escape");
  const rail = await page.evaluate((id) => document.querySelector(`#rail a[data-rail="${id}"] .rail-note`)?.textContent || "", listId);
  const unshareShown = await page.isVisible("#unshare");
  check(`the rail says "${rail}", and Stop sharing is there: ${unshareShown}`, /by its link/.test(rail) && unshareShown);
  const byLink = `/c/${listId}?link=${key}&tests=1`;
  for (const [who, as] of [["Bob", bob], ["a visitor", null]]) {
    const other = await context({ as });
    const seen = await other.newPage();
    listen(seen, `${who} by link`);
    const opened = await seen.goto(`${site}${byLink}`, { waitUntil: "load" });
    const said = await seen.evaluate(() => ({ h: document.querySelector("h1")?.textContent || "",
      note: document.querySelector(".list-head .note, .by-link")?.textContent || document.body.textContent.match(/Shared with you by its link[^.]*\./)?.[0] || "",
      robots: document.querySelector('meta[name="robots"]')?.content || "", follow: document.querySelectorAll("[data-follow-list]:not([hidden])").length,
      alternates: document.querySelectorAll('link[rel="alternate"][hreflang]').length, cards: document.querySelectorAll(".models .model").length }));
    check(`${who} opens its link (${opened.status()}): "${said.h}", "${said.note.trim().slice(0, 60)}", robots "${said.robots}", `
      + `${said.cards} cards, no Follow (${said.follow}), no other languages (${said.alternates})`, opened.status() === 200 && said.h === LIST
      && /Shared with you by its link/.test(said.note) && /noindex/.test(said.robots) && said.cards === 2 && said.follow === 0 && said.alternates === 0);
    if (who === "a visitor") await shot(seen, "09d_list-by-link-visitor-1280-light.png");
    await other.close();
  }
  const raw = await fetch(`${site}${byLink}`, { headers });
  check(`its page is kept by no cache and no search engine: "${raw.headers.get("cache-control")}", "${raw.headers.get("x-robots-tag")}"`,
    raw.status === 200 && /no-store/.test(raw.headers.get("cache-control") || "") && /noindex/.test(raw.headers.get("x-robots-tag") || ""));
  const otherKey = (key.slice(0, 21) + (key.endsWith("A") ? "B" : "A"));
  for (const [what, where] of [["without its key", `/c/${listId}?tests=1`], ["with another key", `/c/${listId}?link=${otherKey}&tests=1`],
    ["list_items without its key", `/api/people?op=list_items&id=${listId}`]]) {
    const answer = await api(where, { token: bob.access_token });
    check(`${what}: ${answer.status}, its name nowhere`, answer.status === 404 && !answer.text.includes(LIST));
  }
  const itemsByLink = await api(`/api/people?op=list_items&id=${listId}&link=${key}&tests=1`);
  check(`list_items with its key: ${itemsByLink.status}, ${(itemsByLink.body.items || []).length} items`,
    itemsByLink.status === 200 && (itemsByLink.body.items || []).length === 2);
  const profileHtml = await api(`/u/${ADA}?tab=lists&tests=1`);
  const profileJson = await api(`/api/people?op=profile&handle=${ADA}&tests=1`);
  const everyList = await api("/api/people?op=collections&tests=1");
  const searched = await api(`/api/people?op=collections&tests=1&q=${encodeURIComponent(LIST)}`);
  const sitemap = await api("/sitemap.xml");
  const nowhere = {
    profile: profileHtml.status === 200 && !profileHtml.text.includes(listId) && !profileHtml.text.includes(LIST),
    "its profile's answer": profileJson.status === 200 && !JSON.stringify(profileJson.body).includes(listId),
    directory: everyList.status === 200 && !(everyList.body.collections || []).some((one) => one.id === listId),
    search: searched.status === 200 && !(searched.body.collections || []).some((one) => one.id === listId),
    sitemap: sitemap.status === 200 && sitemap.text.includes("<urlset") && !sitemap.text.includes(`/c/${listId}`),
  };
  for (const [where, absent] of Object.entries(nowhere)) check(`shared by its link, it is not in the ${where}`, absent);
  await page.click("#unshare");
  // Stopping cannot be undone, so it is said in the page's line, not a toast.
  const stopped = await lineSays(page, /Stopped sharing/).catch(() => "");
  const gone = await api(byLink);
  check(`Stop sharing ("${stopped.slice(0, 60)}"): the next request for its link is ${gone.status}, its name nowhere`,
    /Stopped sharing/.test(stopped) && gone.status === 404 && !gone.text.includes(LIST));
  const again = await api("/api/people?op=list_link", { method: "POST", token: ada.access_token, body: { id: listId, on: true } });
  const newKey = new URL(again.body.link || "http://x/").searchParams.get("link") || "";
  const oldAgain = await api(byLink);
  const newOpens = await api(`/c/${listId}?link=${newKey}&tests=1`);
  check(`shared again: a new key (${newKey !== key ? "new" : "the same"}), the old link ${oldAgain.status}, the new ${newOpens.status}`,
    again.status === 200 && again.body.visibility === "link" && /^[A-Za-z0-9_-]{22}$/.test(newKey) && newKey !== key
    && oldAgain.status === 404 && newOpens.status === 200);
  const off = await api("/api/people?op=list_link", { method: "POST", token: ada.access_token, body: { id: listId, on: false } });
  const bobTries = await api("/api/people?op=list_link", { method: "POST", token: bob.access_token, body: { id: listId, on: true } });
  check(`only its owner shares it: Bob's list_link ${bobTries.status}; hers off again ${off.status}`, bobTries.status === 404 && off.status === 200);

  // --- 6. The profile's Sets tab ----------------------------------------------
  console.log("her profile shows the sets she owns once she chooses");
  const before = await api(`/u/${ADA}?tab=sets&tests=1`);
  check(`no Sets tab before she chooses: ${/data-tab="sets"/.test(before.text) ? "there" : "none"}`, !/data-tab="sets"/.test(before.text));
  await page.goto(`${site}/lists`, { waitUntil: "load" });
  await page.waitForSelector("#shows-owned:not([hidden])", { timeout: 30000 });
  await page.check("#shows-owned-box");
  await until(page, () => /Sets tab/.test(document.getElementById("shows-owned-note")?.textContent || ""), "shown", 15).catch(() => null);
  await shot(page, "10_lists-owned-1280-light.png");
  await visit(page, `/u/${ADA}?tab=sets&tests=1`);
  const tab = await page.evaluate((set) => ({
    marked: document.querySelector('.tabs [aria-current="page"]')?.textContent.trim() || "",
    stats: [...document.querySelectorAll(".owned-stats li")].map((li) => li.textContent.replace(/\s+/g, " ").trim()),
    cards: [...document.querySelectorAll("#models .model .keep")].map((one) => one.dataset.keep),
    themes: [...document.querySelectorAll('.owned-filters select[name="theme"] option')].map((one) => one.value).filter(Boolean),
    has: Boolean(document.querySelector(`#models .keep[data-keep="set:${set}"]`)),
  }), SET);
  check(`/u/${ADA}?tab=sets: "${tab.marked}", ${tab.stats.join(" · ")}, ${tab.cards.length} card, themes ${tab.themes.join(", ")}`,
    /^Sets/.test(tab.marked) && tab.stats.some((one) => /1 set/.test(one)) && tab.has && tab.themes.length >= 1);
  const mineShown = await until(page, (set) => document.querySelector(`#models .keep[data-keep="set:${set}"] [data-keep-main]`)
    ?.getAttribute("aria-pressed") === "true", "pressed", 15, SET).catch(() => false);
  check(`on her own Sets tab its card's Own is pressed: ${mineShown}`, mineShown === true);
  await shot(page, "11_profile-sets-1280-light.png");
  const filtered = await api(`/u/${ADA}?tab=sets&tests=1&q=nothing-like-this`);
  check(`a search for nothing says so: ${/None of/.test(filtered.text) ? "yes" : "no"}`, /None of/.test(filtered.text));
  const themed = await api(`/u/${ADA}?tab=sets&tests=1&theme=${encodeURIComponent(tab.themes[0] || "")}`);
  check(`its theme filter keeps it: ${themed.text.includes(`set:${SET}`) ? "yes" : "no"}`, themed.text.includes(`set:${SET}`));

  // --- 7. A Rebrickable CSV in, a CSV out ------------------------------------------
  console.log("a small Rebrickable CSV shown, cancelled, then brought in; the sets she owns downloaded");
  // What it should show, reckoned here: Galaxy Explorer to add, King's
  // Castle (hers since step 2) already there, 99999-1 no set at all.
  const CSV = `Set Number,Quantity,Includes Spares\n${IMPORTED},1,True\n${SET},1,True\n99999-1,1,True\n`;
  const reckoned = { matched: 1, already: 1, missing: 1 };
  const rowBefore = JSON.stringify(((await api("/api/collection", { token: ada.access_token })).body.sets || []));
  const bring = async () => {
    await page.goto(`${site}/lists`, { waitUntil: "load" });
    await page.waitForSelector("#import:not([hidden])", { timeout: 30000 });
    await page.click("#import");
    await page.waitForSelector("dialog.lists-dialog[open] input[type=file]");
    await page.setInputFiles("dialog.lists-dialog input[type=file]", { name: "rebrickable_sets.csv", mimeType: "text/csv",
      buffer: Buffer.from(CSV) });
    await page.click('dialog.lists-dialog button[type="submit"]');
    await page.waitForSelector('dialog.lists-dialog[open] [data-import-count="matched"]', { timeout: 30000 });
    return page.evaluate(() => Object.fromEntries([...document.querySelectorAll("dialog.lists-dialog[open] [data-import-count]")]
      .map((one) => [one.dataset.importCount, Number(one.textContent.replace(/\D/g, "")) || 0])));
  };
  const counts = await bring();
  const button = await page.evaluate(() => document.querySelector('dialog.lists-dialog[open] button[type="submit"]')?.textContent || "");
  check(`its preview before anything is written: ${JSON.stringify(counts)}, "${button}" (reckoned ${JSON.stringify(reckoned)})`,
    counts.matched === reckoned.matched && counts.already === reckoned.already && counts.missing === reckoned.missing && /Add 1 set/.test(button));
  await shot(page, "12_import-preview-1280-light.png");
  await page.locator("dialog.lists-dialog[open] .actions button", { hasText: "Cancel" }).first().click();
  await until(page, () => !document.querySelector("dialog.lists-dialog[open]"), "cancelled", 15).catch(() => null);
  await page.waitForTimeout(1500);
  const rowAfterCancel = JSON.stringify(((await api("/api/collection", { token: ada.access_token })).body.sets || []));
  check(`Cancel wrote nothing: ${IMPORTED} owned ${await ownedOf(ada, IMPORTED)}, the sets the same (${rowAfterCancel === rowBefore})`,
    rowAfterCancel === rowBefore && (await ownedOf(ada, IMPORTED)) === 0);
  await bring();
  await page.click('dialog.lists-dialog[open] button[type="submit"]');
  await until(page, () => !document.querySelector("dialog.lists-dialog[open]"), "imported", 60);
  check(`Add wrote what it showed: King's Castle still ${await ownedOf(ada, SET)} (already there, left as it was)`,
    (await ownedOf(ada, SET)) === 1);
  const importedOwned = await untilApi(async () => ((await ownedOf(ada, IMPORTED)) === 1 ? 1 : null), "imported");
  await page.waitForSelector(`#items .model[data-key="set:${IMPORTED}"]`, { timeout: 30000 }).catch(() => null);
  const shownNow = await page.evaluate(() => [...document.querySelectorAll("#items .model[data-key]")].map((one) => one.dataset.key));
  check(`${IMPORTED} owned (${importedOwned ?? 0}) and on the page: ${shownNow.join(", ")}`, importedOwned === 1
    && shownNow.includes(`set:${IMPORTED}`) && shownNow.includes(`set:${SET}`));
  // A list's own Add sets: typed, shown, Cancel, then Add.
  await page.goto(`${site}/lists?list=${listId}`, { waitUntil: "load" });
  await page.waitForSelector("#import:not([hidden])", { timeout: 30000 });
  const listBefore = (await api(`/api/people?op=list_items&id=${listId}`, { token: ada.access_token })).body.items?.map((one) => one.key) || [];
  const typedIn = async () => {
    await page.click("#import");
    await page.waitForSelector("dialog.lists-dialog[open] textarea");
    await page.fill("dialog.lists-dialog[open] textarea", `${SET}, ${IMPORTED.replace(/-1$/, "")} 99999`);
    await page.click('dialog.lists-dialog button[type="submit"]');
    await page.waitForSelector('dialog.lists-dialog[open] [data-import-count="matched"]', { timeout: 30000 });
    return page.evaluate(() => Object.fromEntries([...document.querySelectorAll("dialog.lists-dialog[open] [data-import-count]")]
      .map((one) => [one.dataset.importCount, Number(one.textContent.replace(/\D/g, "")) || 0])));
  };
  const listCounts = await typedIn();
  check(`a list's Add sets shows ${JSON.stringify(listCounts)} (reckoned 1 to add, 1 there, 1 not found)`,
    listCounts.matched === 1 && listCounts.already === 1 && listCounts.missing === 1);
  await page.locator("dialog.lists-dialog[open] .actions button", { hasText: "Cancel" }).first().click();
  await page.waitForTimeout(1200);
  const listAfterCancel = (await api(`/api/people?op=list_items&id=${listId}`, { token: ada.access_token })).body.items?.map((one) => one.key) || [];
  check(`Cancel wrote nothing to the list: ${listAfterCancel.join(", ")}`, listAfterCancel.join() === listBefore.join());
  await typedIn();
  await page.click('dialog.lists-dialog button[type="submit"]');
  await until(page, () => !document.querySelector("dialog.lists-dialog[open]"), "added", 60);
  const listAdded = await untilApi(async () => {
    const keys = (await api(`/api/people?op=list_items&id=${listId}`, { token: ada.access_token })).body.items?.map((one) => one.key) || [];
    return keys.includes(`set:${IMPORTED}`) ? keys : null;
  }, "added to the list");
  check(`Add put Galaxy Explorer in, and only it: ${listAdded?.join(", ") || "nothing"}`,
    Boolean(listAdded) && listAdded.length === listBefore.length + 1);
  await page.goto(`${site}/lists`, { waitUntil: "load" });
  await page.waitForSelector("#download:not([hidden])", { timeout: 30000 });
  const download = page.waitForEvent("download", { timeout: 30000 });
  await page.click("#download");
  const file = await download;
  const text = readFileSync(await file.path(), "utf8");
  check(`Download CSV: ${file.suggestedFilename()}, "${text.split(/\r?\n/)[0]}", with both sets`, /\.csv$/.test(file.suggestedFilename())
    && text.startsWith("Set Number,Quantity,Includes Spares") && text.includes(SET) && text.includes(IMPORTED));
  check(`nothing sideways at 1280: ${await sideways(page) ? "it is" : "no"}`, !(await sideways(page)));

  // Dark at 1280: each place again.
  const darkDesk = await context({ as: ada, dark: true });
  const dark = await darkDesk.newPage();
  listen(dark, "ada dark");
  for (const [where, name] of [[`/library?q=${SET}`, "13_library-1280-dark.png"], [`/library/set/${SET}`, "14_set-page-1280-dark.png"],
    [`/lists?list=${listId}`, "15_lists-1280-dark.png"], [`/u/${ADA}?tab=sets&tests=1`, "16_profile-sets-1280-dark.png"]]) {
    await visit(dark, where);
    if (where.startsWith("/library/set/")) {
      await dark.click(`${bar} [data-keep-more]`);
      await dark.waitForSelector("dialog.keep-panel[open]");
    }
    await shot(dark, name);
    if (where.startsWith("/library/set/")) await dark.keyboard.press("Escape");
    check(`dark ${where}: nothing sideways`, !(await sideways(dark)));
  }
  await darkDesk.close();
  await desk.close();

  // --- 8. A phone, with touch ---------------------------------------------------
  for (const isDark of [true, false]) {
    const tone = isDark ? "dark" : "light";
    console.log(`at 430 px with touch, ${tone}`);
    const phone = await context({ as: ada, width: 430, height: 932, dark: isDark });
    const tap = await phone.newPage();
    current = tap;
    listen(tap, `ada phone ${tone}`);
    await visit(tap, `/library?q=${IMPORTED}`);
    const main = `.model .keep[data-keep="set:${IMPORTED}"] [data-keep-main]`;
    await tap.waitForSelector(main, { timeout: 60000 });
    await until(tap, (s) => document.querySelector(s)?.getAttribute("aria-pressed") === "true", "owned shown", 20, main).catch(() => null);
    check(`${tone}: the card says she owns ${IMPORTED}: ${await pressed(tap, main)}`, (await pressed(tap, main)) === "true");
    await tap.tap(`.model .keep[data-keep="set:${IMPORTED}"] [data-keep-more]`);
    await tap.waitForSelector("dialog.keep-panel.at-foot[open]", { timeout: 15000 });
    // Measured once it has risen into place (a dialog's opening, docs/DESIGN_SYSTEM.md Motion).
    await until(tap, () => document.querySelector("dialog.keep-panel")?.getAnimations({ subtree: true })
      .every((one) => one.playState !== "running"), "opened", 5).catch(() => null);
    const box = await tap.evaluate(() => {
      const r = document.querySelector("dialog.keep-panel").getBoundingClientRect();
      return { top: Math.round(r.top), bottom: Math.round(r.bottom), width: Math.round(r.width), inner: innerHeight, innerWidth };
    });
    check(`${tone}: its panel is a sheet at the foot, as tall as it needs (${box.width} wide, ${box.top} to ${box.bottom} of ${box.inner})`,
      box.width >= box.innerWidth - 2 && Math.abs(box.bottom - box.inner) <= 1 && box.top > box.inner * 0.3);
    // How many: one more, then one fewer.
    await tap.tap('dialog.keep-panel .keep-qty button[aria-label="One more"]');
    const two = await untilApi(async () => ((await ownedOf(ada, IMPORTED)) === 2 ? 2 : null), "two");
    await shot(tap, `17_phone-sheet-430-${tone}.png`);
    await tap.tap('dialog.keep-panel .keep-qty button[aria-label="One fewer"]');
    const one = await untilApi(async () => ((await ownedOf(ada, IMPORTED)) === 1 ? 1 : null), "one");
    check(`${tone}: one more makes ${two ?? "?"} and one fewer ${one ?? "?"}`, two === 2 && one === 1);
    await tap.keyboard.press("Escape");
    check(`${tone}: the library at 430 is not sideways`, !(await sideways(tap)));
    await tap.goto(`${site}/lists`, { waitUntil: "load" });
    await tap.waitForSelector("#pick", { state: "visible", timeout: 30000 });
    const options = await tap.evaluate(() => [...document.querySelectorAll("#pick option")].map((one) => one.value));
    check(`${tone}: the lists' dropdown in place of the rail: ${options.length} lists`, options.includes("owned") && options.includes(listId));
    await shot(tap, `18_phone-lists-430-${tone}.png`);
    await tap.selectOption("#pick", listId);
    await tap.waitForSelector(`#items .model[data-key="model:${tower}"]`, { timeout: 30000 });
    await shot(tap, `19_phone-list-430-${tone}.png`);
    check(`${tone}: /lists at 430 is not sideways`, !(await sideways(tap)));
    await visit(tap, `/library/set/${SET}`);
    await tap.waitForSelector(".keep-bar [data-keep-want]");
    await tap.waitForTimeout(1500);
    await shot(tap, `20_phone-set-page-430-${tone}.png`);
    check(`${tone}: the set's page at 430 is not sideways`, !(await sideways(tap)));
    await visit(tap, `/u/${ADA}?tab=sets&tests=1`);
    await shot(tap, `21_phone-profile-sets-430-${tone}.png`);
    check(`${tone}: the Sets tab at 430 is not sideways`, !(await sideways(tap)));
    await phone.close();
  }

  // --- 9. Undo puts back exactly what its step changed (lists1 review) ------------
  console.log("Undo puts back exactly what its step changed");
  const rowNow = async () => (await api("/api/collection", { token: ada.access_token })).body;
  const copiesNow = async (set) => JSON.stringify(((await rowNow()).sets || []).filter((one) => one.set === set));
  await api("/api/collection", { method: "POST", token: ada.access_token,
    body: { op: "missing", set: IMPORTED, src: "rebrickable", lots: [{ part: "3001", colour: 4, was: 0, qty: 2 }] } });
  const markedCopy = await copiesNow(IMPORTED);
  const ownOff = await api("/api/collection", { method: "POST", token: ada.access_token, body: { op: "own", set: IMPORTED, was: 1, qty: 0 } });
  const ownBack = await api("/api/collection", { method: "POST", token: ada.access_token, body: { op: "own", set: IMPORTED, was: 0, qty: 1 } });
  const restoredCopy = await copiesNow(IMPORTED);
  check(`Own off then Undo (${ownOff.status}/${ownBack.status}) gives back the copy with its source and missing parts: ${restoredCopy}`,
    /"missing"/.test(markedCopy) && /rebrickable/.test(markedCopy) && restoredCopy === markedCopy);
  const keepNow = (body) => api("/api/people?op=keep", { method: "POST", token: ada.access_token, body });
  const listOrder = async () => ((await api(`/api/people?op=list_items&id=${listId}`, { token: ada.access_token })).body.items || [])
    .map((one) => one.key).join(",");
  const keptAgain = await keepNow({ list: listId, items: [`set:${SET}`], on: true });
  check(`putting a set into a list that holds it adds nothing to take away: added ${JSON.stringify(keptAgain.body.added)}`,
    keptAgain.status === 200 && Array.isArray(keptAgain.body.added) && keptAgain.body.added.length === 0);
  const orderWas = await listOrder();
  const takenOut = await keepNow({ list: listId, items: [`set:${SET}`], on: false });
  const putBack = await keepNow({ list: listId, items: [`set:${SET}`], on: true, back: takenOut.body.taken });
  const orderNow = await listOrder();
  check(`taken out then put back (${takenOut.status}/${putBack.status}), it is where it was: ${orderNow} (was ${orderWas})`,
    Boolean(takenOut.body.taken?.[`set:${SET}`]) && orderNow === orderWas && orderWas.includes(`set:${SET}`));

  check(`no script errors${errors.length ? `: ${errors.slice(0, 4).join(" | ")}` : ""}`, errors.length === 0);
} catch (trouble) {
  if (current) {
    await shot(current, "zz_where-it-stopped.png");
    const there = await current.evaluate(() => ({ at: location.href,
      panel: document.querySelector("dialog.keep-panel")?.outerHTML.slice(0, 1500) || "" })).catch(() => null);
    console.log(`  --    it stopped at ${there?.at}; its panel: ${there?.panel || "none"}`);
  }
  for (const error of errors) console.log(`  page: ${error}`);
  check(`the flow ran to its end: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" ")}`, false);
} finally {
  if (tower && ada) await api(`/api/share?op=unpublish&id=${tower}`, { method: "POST", token: ada.access_token }).catch(() => {});
  if (listId && ada) await api(`/api/people?op=uncollection&id=${listId}`, { method: "POST", token: ada.access_token }).catch(() => {});
  await browser.close().catch(() => {});
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => {});
}
console.log(failed ? `\nlists flow: ${failed} failed (pictures in ${out})` : `\nlists flow: all passed (pictures in ${out})`);
process.exit(failed ? 1 : 0);
