// Notifications apart from the feed (docs/SOCIAL.md U7), in real browsers:
// your avatar in the header with what is new for you, opening the account
// menu; a comment, a photo of a build and ten likes on your model in
// /notifications as one group with its picture, the ten likes one row
// that names nobody; opened, the count gone; a group read once opened;
// the feed apart; and the pages at 390 and 1280 px, light and dark, signed
// in and signed out.
//
//   node --env-file=.env tools/web/relay_server.mjs 8820 &
//   node --env-file=.env tools/web/notifications_flow.mjs --url=http://127.0.0.1:8820 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/notifications_flow.mjs --url=<preview> --out=DIR
//
// Against the live project, with throwaway accounts at Resend test
// addresses (their day's email a dry run), deleted at the end with their
// models: Ada designs a tower, Bob comments on it and posts a photo of his
// build of it, ten more like it (each with a profile, so a name that must
// not be shown is there to find). Before supabase/notifications.sql is
// applied the API reads the feed of before (feed_of) and model_likes: the
// flow sees which from the answer (kept) and checks each its own way: the
// feed still has her model's comment and photo, and nothing is kept as
// read but what was seen.
//
//   1. Ada signs in: the header shows her avatar, no count, and its menu.
//   2. Bob comments and posts a photo; ten like the tower.
//   3. Ada's next page: the avatar carries the count, and its menu says
//      Notifications with its own; at 390 px Menu is her avatar.
//   4. /notifications: one group, the tower's picture and name, its rows
//      newest first, the ten likes one row ("10 new likes today"), no
//      liker named. Opened: the count gone, from the API too.
//   5. A row opened, Back: its group read (kept, after the file).
//   6. /feed beside it (a tab): the comment and the photo not in it (after
//      the file).
//   7. Mark all read; Bob's empty page; signed out at both widths.
//
// Once supabase/achievements.sql is applied (the profile's answer says
// levels), each level reached is told in a group of its own: Ada's first
// listed model is Designer · first model (seen as she first opens the list,
// so not counted again), its group after the tower's, its row opening her
// profile's Achievements tab, read once opened and after a reload; and
// Bob's page has his Builder · first build in place of the empty state.
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
const site = String(args.url || "http://127.0.0.1:8820").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/notifications"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const { encode } = await import(path.join(root, "api/_jpeg.js"));
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-notify-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-notify-bob-${rand}@resend.dev`;
const likerEmails = Array.from({ length: 10 }, (_, n) => `delivered+bw-notify-l${n}-${rand}@resend.dev`);
const ADA = `bwn-ada-${rand}`;
const BOB = `bwn-bob-${rand}`;
const LIKER = (n) => `bwn-l${n}-${rand}`;
const LIKER_NAME = (n) => `Liker ${"ABCDEFGHIJ"[n]} Notify`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: notify.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // notifications flow ${rand} ${name}\r\n`;

function photo() {
  const width = 320;
  const height = 240;
  const data = Buffer.alloc(width * height * 4);
  for (let at = 0; at < data.length; at += 4) {
    const x = (at / 4) % width;
    const yellow = x > 90 && x < 230;
    data[at] = yellow ? 230 : 40; data[at + 1] = yellow ? 190 : 90; data[at + 2] = yellow ? 30 : 160; data[at + 3] = 255;
  }
  return encode({ width, height, data }, 85).data;
}

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, phone = false, theme = "dark" } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, colorScheme: theme,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    // Once a tab: a reload after Sign out stays signed out.
    await made.addInitScript(([name, value]) => {
      try {
        if (!sessionStorage.getItem("flow.seeded") && !localStorage.getItem(name)) localStorage.setItem(name, value);
        sessionStorage.setItem("flow.seeded", "1");
      } catch {}
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
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
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

/// The header as drawn: Sign in shown or not, the avatar's count, and the
/// account menu's places with their counts, on a laptop and behind Menu.
const headerDrawn = (page) => page.evaluate(() => {
  const signIn = document.querySelector(".site-head .nav a[data-account]");
  const menu = document.querySelector(".site-head .nav .account-menu");
  const phone = document.querySelector(".site-head .menu summary");
  const places = (root) => [...(root?.querySelectorAll(".account-part nav a") || [])]
    .map((a) => `${a.dataset.place}${a.querySelector(".count") ? `:${a.querySelector(".count").textContent}` : ""}`);
  return { signIn: Boolean(signIn && !signIn.hidden && signIn.offsetParent), signInText: signIn?.textContent.trim() || "",
    avatar: Boolean(menu?.querySelector("summary .avatar")), avatarShown: Boolean(menu && menu.offsetParent),
    count: menu?.querySelector("summary .count")?.textContent || "", label: menu?.querySelector("summary")?.getAttribute("aria-label") || "",
    who: `${menu?.querySelector(".menu-who b")?.textContent || ""} ${menu?.querySelector(".menu-who small")?.textContent || ""}`.trim(),
    places: places(menu), phoneAvatar: Boolean(phone?.querySelector(".avatar")), phoneCount: phone?.querySelector(".count")?.textContent || "",
    phonePlaces: places(document.querySelector(".site-head .menu")),
    signOut: Boolean(document.querySelector(".site-head .sign-out")) };
});

/// /notifications as drawn: [{model, name, picture, unread, rows: [{kind, text, href, unread, avatar}]}].
const listDrawn = (page) => page.evaluate(() => [...document.querySelectorAll("#groups .notice")].map((li) => ({
  model: li.dataset.model, achievements: "achievements" in li.dataset, name: li.querySelector("h2")?.textContent.trim() || "",
  award: Boolean(li.querySelector(".pic svg.icon use[href$='#award']")),
  picture: li.querySelector(".pic img")?.getAttribute("src") || "",
  pictureShown: Boolean(li.querySelector(".pic img")?.naturalWidth), unread: li.classList.contains("unread"),
  rows: [...li.querySelectorAll(".lines li")].map((row) => ({ kind: row.dataset.kind,
    text: (row.querySelector(".what")?.textContent || "").replace(/\s+/g, " ").trim(), href: row.querySelector("a")?.getAttribute("href") || "",
    unread: row.classList.contains("unread"), avatar: Boolean(row.querySelector(".avatar")) })) })));

let ada = null;
let bob = null;
const likers = [];
const made = [];
try {
  // --- 1. Ada, her tower, her avatar --------------------------------------
  console.log("Ada designs a tower");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  const adaProfile = await api("/api/people?op=profile", { method: "POST", token: ada.access_token,
    body: { handle: ADA, name: "Ada Notify" } });
  const bobProfile = await api("/api/people?op=profile", { method: "POST", token: bob.access_token,
    body: { handle: BOB, name: "Bob Notify" } });
  check(`profiles: ${adaProfile.status}, ${bobProfile.status}`, adaProfile.status === 200 && bobProfile.status === 200);
  const tower = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: "Notify Flow Tower", author: "Ada Notify", model: model("Notify Flow Tower"), image: picture, listed: true } });
  made.push([tower.body.id, ada]);
  check(`her tower in the gallery: ${tower.status} /m/${tower.body.id}`, tower.status === 201 && Boolean(tower.body.id));
  // Opened once, so what came before this flow is not new.
  const first = await api("/api/people?op=notifications", { token: ada.access_token });
  const kept = first.body.kept === true;
  console.log(`  --    supabase/notifications.sql ${kept ? "applied: kept marks" : "not applied: the feed of before"}`);
  const levelled = Array.isArray((await api(`/api/people?op=profile&handle=${ADA}&tests=1`)).body?.levels);
  console.log(`  --    supabase/achievements.sql ${levelled ? "applied: levels told" : "not applied: no levels"}`);
  // Her first model listed is her first level: told, new (she never opened
  // the list before) and seen as she opens it, so not counted again.
  const reached = first.body.groups?.find((one) => one.achievements);
  check(`her notifications, none yet${levelled ? " but her first level" : ""}: ${first.status}, ${first.body.groups?.length} groups`
    + `${reached ? ` (${reached.rows.map((one) => `${one.who} ${one.did}`).join("; ")})` : ""}`,
    first.status === 200 && first.body.ready === true && first.body.groups.length === (levelled ? 1 : 0)
    && (!levelled || (reached?.rows.length === 1 && reached.rows[0].did === "reached Designer · first model, level 1 of 6"
      && reached.rows[0].new && reached.rows[0].unread)));
  await api("/api/people?op=feed", { token: ada.access_token });

  const adaSite = await context({ as: ada });
  const adaPage = await adaSite.newPage();
  listen(adaPage, "Ada");
  await adaPage.goto(`${site}/gallery`, { waitUntil: "load" });
  await until(adaPage, () => document.querySelector(".site-head .account-menu .menu-who b")?.textContent === "Ada Notify", "her avatar");
  let header = await headerDrawn(adaPage);
  check(`signed in, her avatar where Sign in was, no count: avatar ${header.avatar}, sign in shown ${header.signIn}, count "${header.count}"`,
    header.avatar && header.avatarShown && !header.signIn && header.count === "");
  await adaPage.click(".site-head .account-menu summary");
  header = await headerDrawn(adaPage);
  check(`its menu: "${header.who}", ${header.places.join(", ")}, sign out ${header.signOut}`,
    header.who === `Ada Notify @${ADA}` && header.places.join(",") === "profile,notifications,feed,saved,settings,feedback" && header.signOut);
  await shot(adaPage, "1_account_menu-1280-dark.png");
  await adaPage.keyboard.press("Escape");

  // --- 2. a comment, a photo and ten likes --------------------------------
  console.log("Bob comments and posts a photo; ten people like the tower");
  const comment = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
    body: { model: tower.body.id, version: 1, body: "The tower is taller than mine. Lovely stairs." } });
  check(`his comment: ${comment.status}`, comment.status === 201);
  const jpeg = photo();
  const start = await api("/api/people?op=photo_start", { method: "POST", token: bob.access_token,
    body: { model: tower.body.id, type: "image/jpeg", size: jpeg.length } });
  if (start.status === 200) await fetch(start.body.upload, { method: "PUT", headers: { "content-type": "image/jpeg" }, body: jpeg });
  const kept1 = await api("/api/people?op=photo", { method: "POST", token: bob.access_token,
    body: { model: tower.body.id, ticket: start.body.ticket, words: "Built it with my daughter" } });
  check(`his photo: ${start.status}, ${kept1.status}`, start.status === 200 && kept1.status === 201);
  for (let n = 0; n < 10; n += 1) {
    const liker = await mintSession(likerEmails[n]);
    likers.push(liker);
    await api("/api/people?op=profile", { method: "POST", token: liker.access_token, body: { handle: LIKER(n), name: LIKER_NAME(n) } });
    const liked = await api(`/api/people?op=like&id=${tower.body.id}`, { method: "POST", token: liker.access_token, body: { on: true } });
    if (liked.status !== 200) check(`like ${n}: ${liked.status} ${JSON.stringify(liked.body)}`, false);
  }
  const counted = await api("/api/people?op=feed_count", { token: ada.access_token });
  // After the file: a comment, a photo and a day's likes, three rows. Before
  // it, the feed of before's count: the comment and the photo.
  const expected = kept ? 3 : 2;
  check(`what is new for her: ${JSON.stringify({ count: counted.body.count, notifications: counted.body.notifications, feed: counted.body.feed })}`,
    counted.body.count === expected && (kept ? counted.body.notifications === 3 && counted.body.feed === 0 : counted.body.notifications === null));

  // --- 3. the count on her avatar, and in its menu ------------------------
  console.log("her avatar carries it");
  await adaPage.goto(`${site}/gallery`, { waitUntil: "load" });
  await until(adaPage, (n) => document.querySelector(".site-head .account-menu summary .count")?.textContent === n, "the avatar's count", 30, String(expected));
  header = await headerDrawn(adaPage);
  check(`the avatar: ${header.count}, "${header.label}"`, header.count === String(expected) && header.label === `Your account, ${expected} new`);
  await adaPage.click(".site-head .account-menu summary");
  header = await headerDrawn(adaPage);
  check(`its menu: ${header.places.join(", ")}`, kept ? header.places.includes("notifications:3") && header.places.includes("feed")
    : header.places.includes("notifications"));
  await shot(adaPage, "2_avatar_count-1280-dark.png");

  const adaPhoneSite = await context({ as: ada, width: 390, height: 844, phone: true, theme: "light" });
  const phone = await adaPhoneSite.newPage();
  listen(phone, "Ada's phone");
  await phone.goto(`${site}/gallery`, { waitUntil: "load" });
  await until(phone, (n) => document.querySelector(".site-head .menu summary .count")?.textContent === n, "Menu's count", 30, String(expected));
  header = await headerDrawn(phone);
  check(`at 390 px Menu is her avatar with ${header.phoneCount}, nothing sideways`, header.phoneAvatar && header.phoneCount === String(expected)
    && !(await sideways(phone)));
  await phone.click(".site-head .menu summary");
  header = await headerDrawn(phone);
  check(`...holding the site's links and hers: ${header.phonePlaces.join(", ")}`,
    header.phonePlaces.join(",").startsWith("profile,notifications") && header.signOut);
  await shot(phone, "3_menu-390-light.png");

  // --- 4. /notifications --------------------------------------------------
  console.log("her notifications");
  await adaPage.click('.site-head .account-menu a[data-place="notifications"]');
  await adaPage.waitForURL("**/notifications", { timeout: 20000 });
  await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list");
  await adaPage.waitForFunction(() => [...document.querySelectorAll("#groups .pic img")].every((img) => img.complete), null, { timeout: 15000 }).catch(() => {});
  let list = await listDrawn(adaPage);
  const group = list[0];
  check(`one group, the tower: ${list.length}, "${group?.name}", its picture ${group?.picture} drawn ${group?.pictureShown}`,
    list.length === (levelled ? 2 : 1) && group?.model === tower.body.id && group.name.startsWith("Notify Flow Tower") && group.pictureShown);
  if (levelled) {
    const levels = list[1];
    check(`then her achievements: "${levels?.name}", the award for a picture ${levels?.award}, `
      + `"${levels?.rows.map((one) => one.text).join("; ")}" → ${levels?.rows[0]?.href}, unread ${levels?.unread}`,
      levels?.achievements && levels.name === "Your achievements" && levels.award && levels.unread && levels.rows.length === 1
      && levels.rows[0].kind === "achievement" && /^You reached Designer · first model, level 1 of 6/.test(levels.rows[0].text)
      && !/New/.test(levels.rows[0].text) && levels.rows[0].href === "/profile?tab=achievements");
  }
  check(`its rows, newest first: ${group?.rows.map((one) => one.kind).join(", ")}`,
    group?.rows.map((one) => one.kind).join(",") === "likes,photo,comment");
  const likes = group?.rows.find((one) => one.kind === "likes");
  const commentRow = group?.rows.find((one) => one.kind === "comment");
  const photoRow = group?.rows.find((one) => one.kind === "photo");
  check(`ten likes, one row: "${likes?.text}" → ${likes?.href}`, /^10 new likes today/.test(likes?.text || "") && likes?.href === `/m/${tower.body.id}`
    && !likes.avatar);
  check(`"${commentRow?.text}" → ${commentRow?.href}`, /^Bob Notify commented/.test(commentRow?.text || "") && /Lovely stairs/.test(commentRow?.text || "")
    && new RegExp(`^/m/${tower.body.id}#comment-\\d+$`).test(commentRow?.href || "") && commentRow.avatar);
  check(`"${photoRow?.text}" → ${photoRow?.href}`, /^Bob Notify posted a photo of their build/.test(photoRow?.text || "")
    && photoRow?.href === `/m/${tower.body.id}#photo-${kept1.body.id}`);
  check(`new and unread: ${group?.unread}, ${group?.rows.filter((one) => /New/.test(one.text)).length} marked New`,
    group?.unread && group.rows.every((one) => one.unread && /New/.test(one.text)));
  const text = await adaPage.evaluate(() => document.body.innerText);
  check("no liker named anywhere, nor whom anybody followed",
    likers.every((_, n) => !text.includes(LIKER_NAME(n)) && !text.includes(LIKER(n))) && !/followed you/i.test(text));
  header = await headerDrawn(adaPage);
  check(`opened: the avatar's count gone ("${header.count}")`, header.count === "");
  const cleared = await api("/api/people?op=feed_count", { token: ada.access_token });
  check(`...and from the API: ${cleared.body.count}`, cleared.body.count === 0);
  check(`Mark all read offered: ${await adaPage.isVisible("#all-read")}`, await adaPage.isVisible("#all-read"));
  await shot(adaPage, "4_notifications-1280-dark.png", true);

  await phone.goto(`${site}/notifications`, { waitUntil: "load" });
  await until(phone, () => document.documentElement.dataset.notifications === "ready", "the list at 390");
  await phone.waitForFunction(() => [...document.querySelectorAll("#groups .pic img")].every((img) => img.complete), null, { timeout: 15000 }).catch(() => {});
  check(`at 390 px: ${(await listDrawn(phone)).length} groups, nothing sideways`, (await listDrawn(phone)).length === (levelled ? 2 : 1)
    && !(await sideways(phone)));
  await shot(phone, "4_notifications-390-light.png", true);

  // --- 5. a row opened, and Back ------------------------------------------
  console.log("a row opened, and back");
  await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
  await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list again");
  list = await listDrawn(adaPage);
  check(`reloaded: no longer new (${list[0]?.rows.filter((one) => /New/.test(one.text)).length} New), ${kept ? "still unread" : "seen is read"}`,
    list[0]?.rows.every((one) => !/New/.test(one.text)) && list[0]?.unread === kept);
  await adaPage.click(".notice .lines li[data-kind=comment] a");
  await adaPage.waitForURL(`**/m/${tower.body.id}**`, { timeout: 20000 });
  check(`the comment's row opens its model: ${new URL(adaPage.url()).pathname}${new URL(adaPage.url()).hash}`,
    new URL(adaPage.url()).hash.startsWith("#comment-"));
  await adaPage.waitForTimeout(800);
  await adaPage.goBack({ waitUntil: "load" });
  await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list after Back");
  await adaPage.waitForTimeout(600);
  list = await listDrawn(adaPage);
  check(`back: the tower's group read (${!list[0]?.unread})`, list[0] && !list[0].unread);
  await adaPage.reload({ waitUntil: "load" });
  await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list reloaded");
  list = await listDrawn(adaPage);
  check(`and still read on a reload (${!list[0]?.unread})`, list[0] && !list[0].unread);
  if (levelled) {
    // Her achievements' row opens her profile's Achievements tab; back, read.
    await adaPage.click(".notice[data-achievements] .lines li[data-kind=achievement] a");
    await adaPage.waitForURL("**/profile?tab=achievements", { timeout: 20000 });
    await until(adaPage, () => document.querySelector('[data-panel="achievements"]:not([hidden]) #achievements li'), "her Achievements tab");
    const tile = await adaPage.evaluate(() => {
      const li = document.querySelector('#achievements li[data-track="designer"]');
      return { level: li?.dataset.level, name: li?.querySelector("h3")?.textContent.trim(), next: li?.querySelector(".to-next")?.textContent.trim() };
    });
    check(`its row opens her Achievements tab: Designer at level ${tile.level}, "${tile.name}", "${tile.next}"`,
      tile.level === "1" && tile.name === "Designer · first model" && tile.next === "2 more to reach Designer · 3 models.");
    await shot(adaPage, "5_achievements_tab-1280-dark.png");
    await adaPage.goBack({ waitUntil: "load" });
    await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list after her achievements");
    await adaPage.waitForTimeout(600);
    await adaPage.reload({ waitUntil: "load" });
    await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list reloaded again");
    list = await listDrawn(adaPage);
    const levels = list.find((one) => one.achievements);
    check(`back and reloaded: her achievements read (${levels && !levels.unread})`, levels && !levels.unread);
  }
  if (kept) {
    // Since U8 a commenter hears of replies on the model, so Bob, who
    // commented, may mark his own read there (replies.sql's notification_read);
    // one who only liked it has nothing of it to mark.
    const his = await api("/api/people?op=notifications_read", { method: "POST", token: bob.access_token, body: { model: tower.body.id } });
    check(`Bob, who commented, may mark his own read on Ada's: ${his.status}`, his.status === 200);
    const wrong = await api("/api/people?op=notifications_read", { method: "POST", token: likers[0].access_token, body: { model: tower.body.id } });
    check(`one who only liked it may not: ${wrong.status}`, wrong.status === 404);
  }
  const nobody = await api("/api/people?op=notifications");
  const badly = await api("/api/people?op=notifications_read", { method: "POST", token: ada.access_token, body: { model: "nope" } });
  check(`signed out: ${nobody.status}; a model that is not one: ${badly.status}`, nobody.status === 401 && badly.status === 400);

  // --- 6. the feed, apart --------------------------------------------------
  console.log("the feed beside it");
  await adaPage.click('.tabs a[href="/feed"]');
  await adaPage.waitForURL("**/feed", { timeout: 20000 });
  await until(adaPage, () => document.documentElement.dataset.feed === "ready", "the feed");
  const feedKinds = await adaPage.evaluate(() => [...document.querySelectorAll("#rows .feed-row")].map((li) => li.dataset.kind));
  check(`her feed: ${feedKinds.join(", ") || "nothing"} (${kept ? "what she follows only" : "the feed of before, with her model's news"})`,
    kept ? !feedKinds.includes("comment") && !feedKinds.includes("photo") : feedKinds.includes("comment") && feedKinds.includes("photo"));
  check(`its tabs: ${await adaPage.evaluate(() => [...document.querySelectorAll(".tabs a")].map((a) => `${a.textContent.trim()}${a.getAttribute("aria-current") ? "*" : ""}`).join(" · "))}`,
    await adaPage.evaluate(() => document.querySelector('.tabs a[aria-current="page"]')?.getAttribute("href") === "/feed"));
  await shot(adaPage, "6_feed-1280-dark.png");

  // --- 7. Mark all read, Bob's empty page, signed out ----------------------
  console.log("Mark all read; Bob's; signed out");
  await api(`/api/people?op=like&id=${tower.body.id}`, { method: "POST", token: bob.access_token, body: { on: true } });
  await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
  await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list with Bob's like");
  list = await listDrawn(adaPage);
  check(`Bob's like: today's likes say ${list[0]?.rows.find((one) => one.kind === "likes")?.text.match(/^\d+ new likes?/)?.[0]}, unread ${list[0]?.unread}`,
    /^11 new likes/.test(list[0]?.rows.find((one) => one.kind === "likes")?.text || "") && list[0]?.unread);
  await adaPage.click("#all-read");
  await until(adaPage, () => !document.querySelector("#groups .notice.unread") && document.getElementById("all-read").hidden, "all read");
  await adaPage.reload({ waitUntil: "load" });
  await until(adaPage, () => document.documentElement.dataset.notifications === "ready", "the list after Mark all read");
  list = await listDrawn(adaPage);
  check(`Mark all read: kept across a reload (${list.every((one) => !one.unread)}), offered no more`,
    list.every((one) => !one.unread) && !(await adaPage.isVisible("#all-read")));
  await adaPage.emulateMedia({ colorScheme: "light" });
  await shot(adaPage, "7_notifications_read-1280-light.png");

  const bobSite = await context({ as: bob, width: 1280, height: 900, theme: "light" });
  const bobPage = await bobSite.newPage();
  listen(bobPage, "Bob");
  await bobPage.goto(`${site}/notifications`, { waitUntil: "load" });
  await until(bobPage, () => document.documentElement.dataset.notifications === "ready", "Bob's list");
  if (levelled) {
    // His photo of his build of the tower is his first level.
    const his = await listDrawn(bobPage);
    check(`Bob, with no models: only his achievements, "${his.map((one) => one.rows.map((row) => row.text).join("; ")).join(" | ")}"`,
      his.length === 1 && his[0].achievements && his[0].rows.length === 1
      && /^You reached Builder · first build, level 1 of 5/.test(his[0].rows[0].text) && !(await bobPage.isVisible("#empty")));
  } else {
    check(`Bob, with no models: the empty state, its ways in (${await bobPage.isVisible("#empty")})`,
      await bobPage.isVisible("#empty") && (await bobPage.textContent("#empty")).includes("Nothing yet"));
  }
  await shot(bobPage, "7_empty-1280-light.png");

  for (const [width, height, theme] of [[1280, 900, "dark"], [390, 844, "light"], [390, 844, "dark"]]) {
    const visitor = await context({ width, height, phone: width < 500, theme });
    const page = await visitor.newPage();
    listen(page, `visitor ${width}`);
    await page.goto(`${site}/notifications`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.notifications === "signed-out", "signed out");
    header = await headerDrawn(page);
    check(`signed out at ${width} ${theme}: Sign in ${width < 500 ? "behind Menu" : `"${header.signInText}"`}, no avatar, nothing sideways`,
      !header.avatar && !header.phoneAvatar && (width < 500 || header.signIn) && !(await sideways(page)));
    await shot(page, `7_signed_out-${width}-${theme}.png`);
    await visitor.close();
  }

  // Signing out from the menu.
  await adaPage.click(".site-head .account-menu summary");
  await adaPage.click(".site-head .account-menu .sign-out");
  await adaPage.waitForLoadState("load");
  await until(adaPage, () => document.documentElement.dataset.notifications === "signed-out", "signed out from the menu");
  header = await headerDrawn(adaPage);
  check(`Sign out from her menu: the header says "${header.signInText}"`, header.signIn && header.signInText === "Sign in" && !header.avatar);
  await adaPhoneSite.close();
  await bobSite.close();
  await adaSite.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const one of errors.slice(0, 5)) console.log(`        ${one}`);
  for (const [id, who] of made) {
    if (id && who) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who.access_token }).catch(() => {});
  }
  for (const email of [adaEmail, bobEmail, ...likerEmails]) await deleteAccount(email).catch(() => {});
  await browser.close();
}
console.log(failed ? `notifications: ${failed} FAILED` : "notifications: the avatar, the menu, the list, read and seen, the feed apart: ok");
process.exit(failed ? 1 : 0);
