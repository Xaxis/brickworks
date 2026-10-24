// Following a collection, in real browsers (docs/SOCIAL.md U11,
// supabase/collection_follows.sql, api/_lists.js): a public collection's
// page with its cover, Follow and its count; what is put in it in the
// follower's feed; a model's page saying how many collections it is in,
// linked; letting it go; an account under 13 refused; its owner told
// nothing; made private, followed by nobody.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/list_follows_flow.mjs --url=<preview> --out=DIR
//   node --env-file=.env tools/web/relay_server.mjs 9240 --static=web &
//   node --env-file=.env tools/web/list_follows_flow.mjs --url=http://127.0.0.1:9240 --out=DIR
//
// The live project's tables, so collection_follows.sql applied; before it
// the collection's page has no Follow, and the flow says so and fails.
// Throwaway accounts at Resend test addresses, deleted at the end with
// their models and collections: Ada collects, Bob follows, Cy is under 13.
//
//   1. Ada makes a profile, shares a tower in the gallery and makes a
//      public collection, empty: its page's cover waits for pictures.
//   2. Bob opens it and presses Follow: Following, pressed, "1 follower";
//      a visitor is shown the count and nobody's name; Ada may not follow
//      her own (409), and is told of nobody (her counts unchanged).
//   3. Cy, under 13, is told why not on its page, and refused (422).
//   4. Ada puts the tower in it: Bob's feed says "Ada added “tower” to
//      their collection “…”", the tower's card under it, the collection a
//      link; it is counted on his avatar.
//   5. The tower's page says "In 1 collection", a pill that goes to its
//      Collections part, a card of the collection with the tower as its
//      cover; the collection's page has the tower as its cover too.
//   6. Bob lets it go: Follow again, the count gone, and his feed has
//      nothing of the collection.
//   7. Ada makes it private: its page is gone, and the tower's says no
//      collection.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY, answerAge } from "./session.mjs";
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
const site = String(args.url || "http://127.0.0.1:9240").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/list_follows"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-lists-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-lists-bob-${rand}@resend.dev`;
const cyEmail = `delivered+bw-lists-cy-${rand}@resend.dev`;
const ADA = `bwl-ada-${rand}`;
const LIST = `Towers to build ${rand}`;
const TOWER = `Lists Flow Tower ${rand}`;
const UNDER_13 = "Following is for people 13 and over, because a follow is counted in public. "
  + "Building, your models and sharing by link are all yours.";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: lists.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // list follows flow ${rand}\r\n`;

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900 } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers });
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

const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
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

/// The collection's head as drawn: Follow, its count, its cover.
const headDrawn = (page) => page.evaluate(() => {
  const button = document.querySelector("button[data-follow-list]");
  const count = document.querySelector("[data-list-followers]");
  return { shown: Boolean(button && !button.hidden), text: button?.textContent || "",
    pressed: button?.getAttribute("aria-pressed") || "",
    said: (button?.parentElement?.querySelector(".said")?.textContent || "").trim(),
    followers: count && !count.hidden ? count.textContent.replace(/\s+/g, " ").trim() : "",
    cover: document.querySelector(".list-head .mosaic")?.className || "",
    pictures: [...document.querySelectorAll(".list-head .mosaic img")].map((img) => img.getAttribute("src")) };
});

/// The feed's rows of a collection, as drawn.
const listRows = (page) => page.evaluate(() => [...document.querySelectorAll("#rows .feed-row[data-kind=collection]")]
  .map((li) => ({ text: li.querySelector(".what")?.textContent.replace(/\s+/g, " ").trim() || "",
    model: li.querySelector("a.go")?.getAttribute("href") || "", list: li.querySelector("a.list")?.getAttribute("href") || "",
    card: li.querySelector(".model")?.dataset.id || "" })));

let ada = null;
let bob = null;
let cy = null;
let tower = "";
let listId = "";
try {
  // --- 1. Ada's tower and her collection ----------------------------------
  console.log("Ada shares a tower and makes a public collection");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  cy = await mintSession(cyEmail, { age: false });
  await answerAge(cy.kept.user_id, cyEmail, false);
  const profile = await api("/api/people?op=profile", { method: "POST", token: ada.access_token,
    body: { handle: ADA, name: "Ada Collects" } });
  const shared = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: TOWER, author: "Ada Collects", model: model(TOWER), image: picture, listed: true } });
  tower = shared.body.id || "";
  const list = await api("/api/people?op=collection", { method: "POST", token: ada.access_token,
    body: { name: LIST, description: "Towers that stand at every step.", public: true } });
  listId = list.body.id || "";
  check(`her profile ${profile.status}, the tower /m/${tower} ${shared.status}, the collection /c/${listId} ${list.status}`,
    profile.status === 200 && shared.status === 201 && list.status === 200 && list.body.public === true);
  const adaBefore = await api("/api/people?op=feed_count", { token: ada.access_token });

  // --- 2. Bob follows it ---------------------------------------------------
  console.log("Bob follows it from its page");
  const bobSite = await context({ as: bob });
  const bobPage = await bobSite.newPage();
  listen(bobPage, "Bob");
  await bobPage.goto(`${site}/c/${listId}?tests=1`, { waitUntil: "load" });
  const ready = await until(bobPage, () => !document.querySelector("button[data-follow-list]")?.hidden, "Follow", 30)
    .catch(() => false);
  if (!check("its page has Follow (collection_follows.sql applied)", ready)) throw new Error("no Follow on a collection's page");
  let drawn = await headDrawn(bobPage);
  check(`its head: "${drawn.text}", no count yet ("${drawn.followers}"), its cover waiting (${drawn.cover})`,
    drawn.text === "Follow" && drawn.followers === "" && /\bn0\b/.test(drawn.cover));
  await bobPage.click("button[data-follow-list]");
  await until(bobPage, () => document.querySelector("button[data-follow-list]")?.textContent === "Following", "Following");
  drawn = await headDrawn(bobPage);
  check(`pressed: "${drawn.text}" (pressed ${drawn.pressed}), "${drawn.followers}", "${drawn.said}"`,
    drawn.text === "Following" && drawn.pressed === "true" && drawn.followers === "1 follower" && /in your feed/.test(drawn.said));
  await shot(bobPage, "1_followed.png");
  const asVisitor = await api(`/api/people?op=list_follows&id=${listId}`);
  check(`a visitor is told the count and nobody's name: ${JSON.stringify(asVisitor.body)}`, asVisitor.status === 200
    && asVisitor.body.followers === 1 && asVisitor.body.you_follow === false && !JSON.stringify(asVisitor.body).includes("bob"));
  const own = await api("/api/people?op=list_follow", { method: "POST", token: ada.access_token, body: { id: listId, on: true } });
  check(`Ada following her own: ${own.status} "${own.body.error}"`, own.status === 409);
  const adaAfter = await api("/api/people?op=feed_count", { token: ada.access_token });
  check(`Ada is told nothing: her counts ${JSON.stringify(adaBefore.body.count)} then ${JSON.stringify(adaAfter.body.count)}`,
    adaAfter.body.count === adaBefore.body.count);

  // --- 3. Cy, under 13 -----------------------------------------------------
  console.log("Cy, under 13");
  const cySite = await context({ as: cy });
  const cyPage = await cySite.newPage();
  listen(cyPage, "Cy");
  await cyPage.goto(`${site}/c/${listId}?tests=1`, { waitUntil: "load" });
  await until(cyPage, () => !document.querySelector("button[data-follow-list]")?.hidden, "Cy's Follow");
  await cyPage.click("button[data-follow-list]");
  const told = await until(cyPage, () => document.querySelector("button[data-follow-list] + .said")?.textContent.trim(), "why not");
  check(`on its page Cy is told "${told}"`, told === UNDER_13);
  const refused = await api("/api/people?op=list_follow", { method: "POST", token: cy.access_token, body: { id: listId, on: true } });
  check(`and refused: ${refused.status} "${refused.body.error}"`, refused.status === 422 && refused.body.error === UNDER_13);
  await shot(cyPage, "2_under_13.png");

  // --- 4. Ada puts the tower in: Bob's feed --------------------------------
  console.log("Ada puts the tower in it");
  const put = await api("/api/people?op=collect", { method: "POST", token: ada.access_token,
    body: { collection: listId, model: tower, on: true } });
  check(`put in: ${put.status}`, put.status === 200 && put.body.has === true);
  const counted = await api("/api/people?op=feed_count", { token: bob.access_token });
  check(`counted on Bob's avatar: feed ${counted.body.feed}`, Number(counted.body.feed) >= 1);
  await bobPage.goto(`${site}/feed`, { waitUntil: "load" });
  await until(bobPage, () => document.documentElement.dataset.feed === "ready", "Bob's feed");
  let rows = await listRows(bobPage);
  check(`Bob's feed: "${rows[0]?.text}"`, rows.length === 1
    && rows[0].text.startsWith(`Ada Collects added “${TOWER}” to their collection “${LIST}”`));
  check(`its links: the tower ${rows[0]?.model}, the collection ${rows[0]?.list}, the tower's card ${rows[0]?.card}`,
    rows[0]?.model === `/m/${tower}` && rows[0]?.list === `/c/${listId}` && rows[0]?.card === tower);
  await shot(bobPage, "3_feed.png", true);

  // --- 5. In 1 collection ---------------------------------------------------
  console.log("the tower's page, and the collection's");
  await bobPage.goto(`${site}/m/${tower}`, { waitUntil: "load" });
  const pill = await bobPage.evaluate(() => {
    const link = document.querySelector('.facts a[href="#collections"]');
    return { words: link?.textContent || "", tab: document.querySelector('#page-tabs a[data-tab="collections"]')?.textContent || "" };
  });
  check(`its facts say "${pill.words}", its tabs "${pill.tab.replace(/\s+/g, " ")}"`, pill.words === "In 1 collection"
    && /^Collections\s*1$/.test(pill.tab.trim()));
  await bobPage.click('.facts a[href="#collections"]');
  await until(bobPage, () => location.hash === "#collections", "the part");
  const part = await bobPage.evaluate(() => [...document.querySelectorAll("#collections .list-card")].map((card) => ({
    href: card.getAttribute("href"), words: card.querySelector(".words")?.textContent.replace(/\s+/g, " ").trim(),
    pictures: card.querySelectorAll(".mosaic img").length, top: Math.round(card.getBoundingClientRect().top) })));
  check(`the pill goes to its collections: ${JSON.stringify(part)}`, part.length === 1 && part[0].href === `/c/${listId}`
    && part[0].words.startsWith(LIST) && part[0].words.includes("Ada Collects") && part[0].pictures === 1
    && part[0].top >= 0 && part[0].top < 900);
  await shot(bobPage, "4_in_collections.png");
  await bobPage.goto(`${site}/c/${listId}?tests=1`, { waitUntil: "load" });
  drawn = await headDrawn(bobPage);
  check(`the collection's cover is the tower now (${drawn.cover}: ${drawn.pictures.join(", ")})`,
    /\bn1\b/.test(drawn.cover) && drawn.pictures.length === 1 && drawn.pictures[0].includes(tower));

  // --- 6. Bob lets it go ----------------------------------------------------
  console.log("Bob lets it go");
  await until(bobPage, () => document.querySelector("button[data-follow-list]")?.textContent === "Following", "Following again");
  await bobPage.click("button[data-follow-list]");
  await until(bobPage, () => document.querySelector("button[data-follow-list]")?.textContent === "Follow", "Follow again");
  drawn = await headDrawn(bobPage);
  check(`let go: "${drawn.text}" (pressed ${drawn.pressed}), the count gone ("${drawn.followers}")`,
    drawn.text === "Follow" && drawn.pressed === "false" && drawn.followers === "");
  await shot(bobPage, "5_let_go.png");
  await bobPage.goto(`${site}/feed`, { waitUntil: "load" });
  await until(bobPage, () => document.documentElement.dataset.feed === "ready", "Bob's feed again");
  rows = await listRows(bobPage);
  check(`and his feed has nothing of it (${rows.length} rows)`, rows.length === 0);

  // --- 7. Made private --------------------------------------------------------
  console.log("Ada makes it private");
  const again = await api("/api/people?op=list_follow", { method: "POST", token: bob.access_token, body: { id: listId, on: true } });
  const shut = await api("/api/people?op=collection", { method: "POST", token: ada.access_token,
    body: { id: listId, name: LIST, public: false } });
  const gone = await text(`/c/${listId}?tests=1`);
  const towerNow = await text(`/m/${tower}`);
  const feedNow = await api("/api/people?op=feed", { token: bob.access_token });
  check(`private: its page ${gone.status}, the tower's page counts no collection, Bob's feed none of it `
    + `(followed again ${again.status}, made private ${shut.status})`, again.status === 200 && shut.status === 200
    && gone.status === 404 && !towerNow.html.includes('href="#collections"')
    && !(feedNow.body.rows || []).some((row) => row.kind === "collection"));
  const follows = await api(`/api/people?op=list_follows&id=${listId}`, { token: bob.access_token });
  check(`and nobody may follow it: ${follows.status}`, follows.status === 404);
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (tower && ada) await api(`/api/share?op=unpublish&id=${tower}`, { method: "POST", token: ada.access_token }).catch(() => {});
  if (listId && ada) await api(`/api/people?op=uncollection&id=${listId}`, { method: "POST", token: ada.access_token }).catch(() => {});
  await browser.close();
  for (const email of [adaEmail, bobEmail, cyEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "list follows: a collection followed, its growth in the feed, In N collections, under 13, let go, private");
process.exit(failed ? 1 : 0);
