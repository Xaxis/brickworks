// What you hear of, and where (inbox, 2026-11-23), in real browsers:
// Settings › Notifications' grid (each kind here, by push, by email), a
// model muted from its notification and from its page, Done and Mark all
// done, and the account menu's newest five.
//
//   node --env-file=.env tools/web/relay_server.mjs 11561 &
//   node --env-file=.env tools/web/inbox_flow.mjs --url=http://127.0.0.1:11561 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/inbox_flow.mjs --url=<preview> --out=DIR
//
// Against the live project, with throwaway accounts at Resend test
// addresses (their day's email a dry run, recorded and never sent), deleted
// at the end with their models: Ada designs five models, Bob comments on
// each, likes two and replies to her. Push is homescreen_flow's (a device
// of hers, Firefox, ticked in this grid); every kind on every channel is
// the dry run's (tools/notification_prefs_matrix_try.sql).
//
//   1. Settings › Notifications: eleven rows, a box a place, each named by
//      its row and its column, 44 px each; at 390 and 1280, light and dark.
//   2. Bob comments on her five: the account menu's newest five are the
//      list's first five, with their pictures, each opening its place;
//      opening the menu marks nothing seen.
//   Once supabase/notification_prefs.sql is applied (op=notification_prefs
//   says ready; before it the page offers none of this, and says so):
//   3. In the grid: likes off here, replies and likes by email; kept
//      across a reload.
//   4. The shed muted from its notification: gone, with Undo; in
//      Settings' Muted models.
//   5. Bob likes the tower and the shed and replies to her: the bell has
//      no likes and nothing of the shed; the day's email says the reply and
//      the likes, of the tower only; his comment on the shed is not counted.
//   6. Unmuted from Settings: the shed back. Muted and unmuted from the
//      barn's own page.
//   7. Done: one request, out of the inbox and into Done, in a second tab
//      and after a reload; Undo; Mark all done; something new comes back.
//
// Pictures in --out (the docs' are named docs_*).
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:11561").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/inbox"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-inbox-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-inbox-bob-${rand}@resend.dev`;
const ADA = `bwi-ada-${rand}`;
const BOB = `bwi-bob-${rand}`;
const NAMES = ["Inbox Flow Boat", "Inbox Flow Mill", "Inbox Flow Barn", "Inbox Flow Shed", "Inbox Flow Tower"];
const KINDS = ["comment", "reply", "mention", "photo", "remix", "likes", "talk", "challenge", "result", "achievement", "news"];

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const note = (what) => console.log(`  --    ${what}`);
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: inbox.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // inbox flow ${rand} ${name}\r\n`;

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, phone = false, theme = "dark" } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, colorScheme: theme,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
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

// A phone's picture clipped to its window: a full-page one draws the
// mouse's controls (fullpage-shot-drops-touch).
const shot = (page, name, { full = false, clip = null } = {}) => page.screenshot({ path: path.join(out, name), fullPage: full,
  ...(clip ? { clip } : {}), timeout: 90000 }).catch((trouble) => note(`no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const clipOf = (page, selector, pad = 16) => page.evaluate(([css, room]) => {
  const box = document.querySelector(css)?.getBoundingClientRect();
  if (!box) return null;
  return { x: 0, y: Math.max(0, box.top + scrollY - room), width: innerWidth, height: Math.min(2400, box.height + 2 * room) };
}, [selector, pad]);

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

/// The day's email the API said it told ([id]), as the project kept it:
/// its tables are the server's alone, so asked with the secret key of
/// comment_digest_kept (a test account's only).
async function digestKept(id) {
  const reply = await fetch(`${SUPABASE}/rest/v1/rpc/comment_digest_kept`, { method: "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: JSON.stringify({ one: id }) }).catch(() => null);
  return reply && reply.ok ? reply.json().catch(() => null) : null;
}

/// Settings' grid as drawn: each row's kind, its label, and each box's
/// place, name (its row's and column's words), state and size.
const gridDrawn = (page) => page.evaluate(() => [...document.querySelectorAll("#kinds tbody tr[data-notice]")].map((tr) => ({
  kind: tr.dataset.notice, label: tr.querySelector("th")?.textContent.trim() || "",
  boxes: [...tr.querySelectorAll("input[data-channel]")].map((box) => {
    const cell = box.closest("label").getBoundingClientRect();
    return { channel: box.dataset.channel, on: box.checked, disabled: box.disabled,
      name: (box.getAttribute("aria-labelledby") || "").split(" ").map((id) => document.getElementById(id)?.textContent.trim() || "").join(" "),
      w: Math.round(cell.width), h: Math.round(cell.height) };
  }) })));
const on = (grid, channel) => grid.filter((row) => row.boxes.find((box) => box.channel === channel)?.on).map((row) => row.kind);

/// /notifications as drawn: each group's key, model, name and rows' kinds.
const listDrawn = (page) => page.evaluate(() => [...document.querySelectorAll("ol.notices .notice")].map((li) => ({
  key: li.dataset.key || "", model: li.dataset.model || "", name: li.querySelector(".row-title a, .row-title")?.textContent.trim() || "",
  kinds: [...li.querySelectorAll(".lines li")].map((row) => row.dataset.kind), done: Boolean(li.querySelector("[data-done]")),
  mute: Boolean(li.querySelector("[data-mute]")) })));
const listReady = (page, what) => until(page, () => document.documentElement.dataset.notifications === "ready", what, 45);

let ada = null;
let bob = null;
const made = [];
try {
  // --- 0. Ada and her five ---------------------------------------------------
  console.log("Ada designs five models");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  const profiles = [await api("/api/people?op=profile", { method: "POST", token: ada.access_token, body: { handle: ADA, name: "Ada Inbox" } }),
    await api("/api/people?op=profile", { method: "POST", token: bob.access_token, body: { handle: BOB, name: "Bob Inbox" } })];
  check(`profiles: ${profiles.map((one) => one.status).join(", ")}`, profiles.every((one) => one.status === 200));
  const ids = {};
  for (const name of NAMES) {
    const shared = await api("/api/share", { method: "POST", token: ada.access_token,
      body: { name, author: "Ada Inbox", model: model(name), image: picture, listed: true } });
    ids[name] = shared.body.id;
    made.push([shared.body.id, ada]);
  }
  check(`her five: ${Object.values(ids).join(", ")}`, Object.values(ids).every((id) => /^[A-Za-z0-9]{10}$/.test(id || "")));
  const [boat, mill, barn, shed, tower] = NAMES.map((name) => ids[name]);
  // The day's email of comments off, so the only email today is the one
  // her grid asks for (her feed has nothing: she follows nobody).
  await api("/api/people?op=mail", { method: "POST", token: ada.access_token, body: { comments: false } });
  await api("/api/people?op=notifications", { token: ada.access_token });
  const prefs = await api("/api/people?op=notification_prefs", { token: ada.access_token });
  const ready = prefs.body.ready === true;
  note(`supabase/notification_prefs.sql ${ready ? "applied: chosen, muted, done" : "not applied: everything here, as before"}`);
  check(`her choices, never made: ${prefs.status}, here ${prefs.body.here?.length} kinds, pushed ${prefs.body.push?.join(",")}, muted ${prefs.body.muted?.length}`,
    prefs.status === 200 && prefs.body.here?.join(",") === KINDS.join(",") && prefs.body.push?.join(",") === "reply,mention"
    && prefs.body.muted?.length === 0);

  // --- 1. Settings › Notifications' grid --------------------------------------
  console.log("Settings › Notifications: what you hear of, and where");
  for (const [width, height, theme] of [[1280, 900, "dark"], [1280, 900, "light"], [390, 844, "light"], [390, 844, "dark"]]) {
    const phone = width < 500;
    const site_ = await context({ as: ada, width, height, phone, theme });
    const page = await site_.newPage();
    listen(page, `settings ${width} ${theme}`);
    await page.goto(`${site}/settings#kinds-part`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.settings === "ready", "Settings drawn", 45);
    if (ready) await until(page, () => document.querySelector('#kinds input[data-channel="here"]')?.disabled === false, "the grid enabled", 20);
    const grid = await gridDrawn(page);
    const boxes = grid.flatMap((row) => row.boxes);
    const said = await page.evaluate(() => document.getElementById("mail-said")?.textContent.trim() || "");
    const fits = await page.evaluate(() => document.getElementById("kinds").getBoundingClientRect().right
      <= document.querySelector("#kinds-part").getBoundingClientRect().right + 1);
    check(`${width} ${theme}: ${grid.length} kinds (${grid.map((row) => row.kind).join(",")}), ${boxes.length} boxes, each named by its row and column`
      + ` ("${boxes[0]?.name}"), each at least 44 px (${Math.min(...boxes.map((box) => Math.min(box.w, box.h)))}), the table inside its part, nothing sideways`,
      grid.map((row) => row.kind).join(",") === KINDS.join(",") && boxes.length === 33
      && boxes.every((box) => box.name.split(" ").length >= 2 && !box.name.startsWith(" ") && box.name.endsWith({ here: "Here", push: "Push", email: "Email" }[box.channel]))
      && boxes.every((box) => box.w >= 44 && box.h >= 44) && fits && !(await sideways(page)));
    if (width === 1280 && theme === "dark") {
      if (ready) {
        // By email as before: the seven kinds the grid newly offers off, and
        // comments, photos, remixes and news each its own choice (her
        // comments' turned off above).
        const mailedNew = on(grid, "email").filter((kind) => !["comment", "photo", "remix", "news"].includes(kind));
        check(`her defaults: here ${on(grid, "here").length} of 11, pushed ${on(grid, "push").join(",")}, emailed ${on(grid, "email").join(",") || "nothing"}`,
          on(grid, "here").length === 11 && on(grid, "push").join(",") === "reply,mention" && mailedNew.length === 0
          && !on(grid, "email").includes("comment") && grid.every((row) => row.boxes.every((box) => box.channel === "email" || !box.disabled)));
      } else {
        check(`before the file: the grid not to be ticked, and why ("${said}")`, boxes.filter((box) => box.channel !== "email").every((box) => box.disabled)
          && /not open on Brickworks yet/.test(said));
      }
    }
    await page.locator("#kinds-part").scrollIntoViewIfNeeded();
    await shot(page, `docs_settings_kinds-${width}-${theme}.png`, { clip: await clipOf(page, "#email-part") });
    await site_.close();
  }

  // --- 2. Bob's five comments; the account menu's newest five -------------------
  console.log("Bob comments on her five; the account menu's newest five");
  const told = [];
  for (const id of [boat, mill, barn, shed, tower]) {
    const said = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
      body: { model: id, version: 1, body: `Lovely work ${rand}` } });
    if (said.status !== 201) check(`his comment on ${id}: ${said.status} ${JSON.stringify(said.body).slice(0, 120)}`, false);
    if (said.body.told) told.push(said.body.told.id);
    await new Promise((done) => setTimeout(done, 1100));
  }
  check(`his five comments: no email for her yet, none chosen (${told.length})`, told.length === 0);
  const countBefore = (await api("/api/people?op=feed_count", { token: ada.access_token })).body.notifications;
  const adaSite = await context({ as: ada });
  const adaPage = await adaSite.newPage();
  listen(adaPage, "Ada");
  await adaPage.goto(`${site}/gallery`, { waitUntil: "load" });
  await until(adaPage, () => document.querySelector(".site-head .account-menu .menu-who b")?.textContent === "Ada Inbox", "her avatar", 45);
  await adaPage.click(".site-head .account-menu summary");
  await until(adaPage, () => document.querySelectorAll(".site-head .account-menu .menu-latest a[data-latest]").length >= 5, "the newest five", 30);
  await adaPage.waitForFunction(() => [...document.querySelectorAll(".site-head .account-menu .menu-latest img")].every((img) => img.complete), null,
    { timeout: 15000 }).catch(() => {});
  const menuFive = await adaPage.evaluate(() => [...document.querySelectorAll(".site-head .account-menu .menu-latest a[data-latest]")].map((a) => ({
    key: a.dataset.latest, href: a.getAttribute("href"), name: a.querySelector("b")?.textContent || "",
    line: a.querySelector("small")?.textContent || "", picture: Boolean(a.querySelector("img")?.naturalWidth),
    icon: Boolean(a.querySelector(".pic svg")), tall: Math.round(a.getBoundingClientRect().height) })));
  await shot(adaPage, "docs_account_menu_newest-1280-dark.png");
  const countPeeked = (await api("/api/people?op=feed_count", { token: ada.access_token })).body.notifications;
  check(`opening the menu marks nothing seen: her count ${countBefore} before, ${countPeeked} after`, countBefore === countPeeked && countBefore >= 5);
  await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
  await listReady(adaPage, "the list");
  let list = await listDrawn(adaPage);
  check(`the menu's five are the list's first five: ${menuFive.map((one) => `${one.name} ("${one.line}")`).join("; ")}`,
    menuFive.length === 5 && menuFive.map((one) => one.key).join(",") === list.slice(0, 5).map((one) => one.key).join(","));
  check(`each with its picture (or its icon) and a 44 px row: ${menuFive.map((one) => (one.picture ? "picture" : one.icon ? "icon" : "none")).join(", ")}`,
    menuFive.every((one) => one.picture || one.icon) && menuFive.filter((one) => Object.values(ids).includes(one.key)).every((one) => one.picture)
    && menuFive.every((one) => one.tall >= 44));
  const towerEntry = menuFive.find((one) => one.key === tower);
  await adaPage.goto(`${site}/gallery`, { waitUntil: "load" });
  await until(adaPage, () => document.querySelector(".site-head .account-menu .menu-who b"), "her avatar again", 45);
  await adaPage.click(".site-head .account-menu summary");
  await until(adaPage, (key) => document.querySelector(`.site-head .account-menu .menu-latest a[data-latest="${key}"]`), "the tower in the menu", 30, tower);
  await Promise.all([adaPage.waitForURL(`**/m/${tower}**`, { timeout: 20000 }),
    adaPage.click(`.site-head .account-menu .menu-latest a[data-latest="${tower}"]`)]);
  check(`its entry opens its place: ${towerEntry?.href} → ${new URL(adaPage.url()).pathname}${new URL(adaPage.url()).hash}`,
    new URL(adaPage.url()).pathname === `/m/${tower}` && new URL(adaPage.url()).hash.startsWith("#comment-"));
  {
    const phoneSite = await context({ as: ada, width: 390, height: 844, phone: true, theme: "light" });
    const phone = await phoneSite.newPage();
    listen(phone, "Ada's phone");
    await phone.goto(`${site}/gallery`, { waitUntil: "load" });
    await until(phone, () => document.querySelector(".site-head .menu summary .avatar"), "Menu as her avatar", 45);
    await phone.click(".site-head .menu summary");
    await until(phone, () => document.querySelectorAll(".site-head .menu .menu-latest a[data-latest]").length >= 5, "the five on her phone", 30);
    await phone.locator(".site-head .menu .menu-latest").scrollIntoViewIfNeeded();
    const phoneFive = await phone.evaluate(() => [...document.querySelectorAll(".site-head .menu .menu-latest a[data-latest]")].map((a) => a.dataset.latest));
    check(`at 390 px Menu holds the same five, nothing sideways`, phoneFive.join(",") === menuFive.map((one) => one.key).join(",") && !(await sideways(phone)));
    await shot(phone, "docs_account_menu_newest-390-light.png");
    await phoneSite.close();
  }

  if (!ready) {
    await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
    await listReady(adaPage, "the list before the file");
    list = await listDrawn(adaPage);
    check(`before the file: no Done, no Mute, no Inbox and Done (${list.filter((one) => one.done || one.mute).length})`,
      list.every((one) => !one.done && !one.mute) && await adaPage.evaluate(() => document.getElementById("views").hidden && document.getElementById("all-done").hidden));
    const chose = await api("/api/people?op=notification_prefs", { method: "POST", token: ada.access_token, body: { kind: "likes", channel: "here", on: false } });
    check(`...and the API says so: ${chose.status}`, chose.status === 503);
  } else {
    // --- 3. her choices, in the grid ---------------------------------------------
    console.log("her choices: likes off here; replies and likes by email");
    await adaPage.goto(`${site}/settings#kinds-part`, { waitUntil: "load" });
    await until(adaPage, () => document.querySelector('#kinds input[data-channel="here"]')?.disabled === false, "the grid", 45);
    const tick = async (kind, channel, want) => {
      const box = `#kinds tr[data-notice="${kind}"] input[data-channel="${channel}"]`;
      await adaPage.evaluate(() => { document.getElementById("mail-said").textContent = ""; });
      await adaPage.click(box);
      const said = await until(adaPage, () => document.getElementById("mail-said")?.textContent.trim(), `${kind} ${channel} said`, 15).catch(() => "");
      const now = await adaPage.evaluate((css) => document.querySelector(css).checked, box);
      check(`${kind} ${channel} ${want ? "on" : "off"}: "${said}"`, now === want && new RegExp(`^${want ? "On" : "Off"}:`).test(said));
    };
    await tick("likes", "here", false);
    await tick("reply", "email", true);
    await tick("likes", "email", true);
    await adaPage.reload({ waitUntil: "load" });
    await until(adaPage, () => document.querySelector('#kinds input[data-channel="here"]')?.disabled === false, "the grid reloaded", 45);
    const grid = await gridDrawn(adaPage);
    const kept = (await api("/api/people?op=notification_prefs", { token: ada.access_token })).body;
    check(`kept across a reload: here without likes (${!on(grid, "here").includes("likes")}), emailed ${on(grid, "email").join(",")}; `
      + `the server's ${kept.email?.join(",")}`, !on(grid, "here").includes("likes") && on(grid, "here").length === 10
      && on(grid, "email").join(",") === "reply,likes" && kept.email?.slice().sort().join(",") === "likes,reply" && !kept.here?.includes("likes"));

    // --- 4. the shed muted from its notification ---------------------------------
    console.log("the shed muted from its notification");
    await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
    await listReady(adaPage, "the list");
    await adaPage.click(`#groups .notice[data-key="${shed}"] .acts summary`);
    await adaPage.click(`#groups .notice[data-key="${shed}"] .acts button[data-mute]`);
    await until(adaPage, (key) => !document.querySelector(`#groups .notice[data-key="${key}"]`), "the shed gone", 15, shed);
    const toast = await until(adaPage, () => document.querySelector(".toast.act.shown")?.textContent.trim(), "its toast", 10).catch(() => "");
    const muted = (await api("/api/people?op=notification_prefs", { token: ada.access_token })).body.muted || [];
    check(`muted: the shed's group gone, "${toast}", her muted ${muted.map((one) => one.name).join(", ")}`,
      /^Muted: Inbox Flow Shed/.test(toast) && /Undo/.test(toast) && muted.length === 1 && muted[0].model === shed);
    await shot(adaPage, "docs_notifications_muted_toast-1280-dark.png");
    await adaPage.goto(`${site}/settings#muted-part`, { waitUntil: "load" });
    const mutedList = await until(adaPage, () => [...document.querySelectorAll("#muted li")].map((li) => li.textContent.replace(/\s+/g, " ").trim()).join(" | "),
      "the muted list", 30).catch(() => "");
    check(`Settings › Muted models: "${mutedList}", its Unmute`, /Inbox Flow Shed/.test(mutedList)
      && await adaPage.evaluate(() => Boolean(document.querySelector("#muted li button")) && document.getElementById("muted-none").hidden));
    await adaPage.locator("#muted-part").scrollIntoViewIfNeeded();
    await shot(adaPage, "docs_settings_muted-1280-dark.png", { clip: await clipOf(adaPage, "#muted-part") });

    // --- 5. likes, a reply and a muted comment: the bell and the day's email -----
    console.log("Bob likes the tower and the shed, and replies to her: the bell, and the day's email");
    await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
    await listReady(adaPage, "the list, seen");
    const hers = await api("/api/people?op=comment", { method: "POST", token: ada.access_token,
      body: { model: tower, version: 1, body: `Thank you, the stairs took a week ${rand}` } });
    const likes = [await api(`/api/people?op=like&id=${tower}`, { method: "POST", token: bob.access_token, body: { on: true } }),
      await api(`/api/people?op=like&id=${shed}`, { method: "POST", token: bob.access_token, body: { on: true } })];
    const reply = await api("/api/people?op=reply", { method: "POST", token: bob.access_token,
      body: { id: hers.body.comment?.id, body: `A week well spent ${rand}` } });
    const onShed = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
      body: { model: shed, version: 1, body: `Muted words ${rand}` } });
    check(`her comment ${hers.status}, his likes ${likes.map((one) => one.status).join(",")}, his reply ${reply.status}, on the shed ${onShed.status}`,
      hers.status === 201 && likes.every((one) => one.status === 200) && reply.status === 201 && onShed.status === 201);
    const digest = reply.body.told?.id ? await digestKept(reply.body.told.id) : null;
    const body = String(digest?.body || "");
    writeFileSync(path.join(out, "digest.txt"), `${digest?.subject || "(none)"}\n\n${body}\n`);
    check(`the day's email, told as the reply came (${reply.body.told?.state}): "${digest?.subject}"`,
      reply.body.told?.state === "dry" && digest?.subject === "Brickworks: 2 new things for you" && !onShed.body.told);
    check("...saying his reply and the tower's like, each with its link, and nothing of the muted shed or of comments",
      /For you since the last email:/.test(body) && /A week well spent/.test(body) && /1 new like/.test(body)
      && body.includes(`/m/${tower}`) && !body.includes("Inbox Flow Shed") && !body.includes(`/m/${shed}`) && !/Muted words/.test(body)
      && !/commented on/.test(body));
    await adaPage.reload({ waitUntil: "load" });
    await listReady(adaPage, "the list with his reply");
    list = await listDrawn(adaPage);
    const kindsShown = list.flatMap((one) => one.kinds);
    check(`the bell: the reply on the tower (${list.find((one) => one.key === tower)?.kinds.join(",")}), no likes (${kindsShown.filter((k) => k === "likes").length}), `
      + `nothing of the shed (${list.filter((one) => one.key === shed).length})`, list.find((one) => one.key === tower)?.kinds.includes("reply")
      && !kindsShown.includes("likes") && !list.some((one) => one.key === shed));

    // --- 6. unmuted from Settings; muted and unmuted from the barn's page --------
    console.log("unmuted from Settings; the barn's own page");
    await adaPage.goto(`${site}/settings#muted-part`, { waitUntil: "load" });
    await until(adaPage, () => document.querySelector("#muted li button"), "Unmute", 30);
    await adaPage.click("#muted li button");
    const unmuted = await until(adaPage, () => document.getElementById("muted-said")?.textContent.trim(), "unmuted, said", 15).catch(() => "");
    await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
    await listReady(adaPage, "the list, the shed back");
    list = await listDrawn(adaPage);
    check(`"${unmuted}": the shed back, his words on it with it (${list.find((one) => one.key === shed)?.kinds.join(",")})`,
      /^Unmuted: you hear of Inbox Flow Shed again/.test(unmuted) && list.some((one) => one.key === shed));
    const barnSite = await context({ as: ada, width: 390, height: 844, phone: true, theme: "dark" });
    const barnPage = await barnSite.newPage();
    listen(barnPage, "the barn");
    await barnPage.goto(`${site}/m/${barn}`, { waitUntil: "load" });
    const mutePress = async () => {
      await barnPage.click("#more summary");
      await until(barnPage, () => document.querySelector("#more [data-mute]")?.textContent, "the menu's Mute", 20);
      const said = await barnPage.evaluate(() => document.querySelector("#more [data-mute]").textContent);
      await barnPage.click("#more [data-mute]");
      return said;
    };
    await until(barnPage, () => document.querySelector("#more summary"), "the barn's More", 45);
    const first = await mutePress();
    const saidOn = await until(barnPage, () => /^Muted/.test(document.querySelector(".marks-said")?.textContent || "")
      && document.querySelector(".marks-said").textContent, "muted, said", 15).catch(() => "");
    const barnMuted = ((await api("/api/people?op=notification_prefs", { token: ada.access_token })).body.muted || []).map((one) => one.model);
    await barnPage.click("#more summary");
    await until(barnPage, () => document.querySelector("#more [data-mute]")?.textContent === "Unmute notifications", "Unmute offered", 10).catch(() => null);
    await shot(barnPage, "docs_model_mute-390-dark.png");
    await barnPage.keyboard.press("Escape");
    await barnPage.evaluate(() => { document.getElementById("more").open = false; });
    const second = await mutePress();
    const saidOff = await until(barnPage, () => /^Unmuted/.test(document.querySelector(".marks-said")?.textContent || "")
      && document.querySelector(".marks-said").textContent, "unmuted, said", 15).catch(() => "");
    const barnAfter = ((await api("/api/people?op=notification_prefs", { token: ada.access_token })).body.muted || []).map((one) => one.model);
    check(`the barn's page, More: "${first}" → "${saidOn}" (muted ${barnMuted.join(",")}), then "${second}" → "${saidOff}" (muted ${barnAfter.length}), nothing sideways`,
      first === "Mute notifications" && Boolean(saidOn) && barnMuted.includes(barn) && second === "Unmute notifications" && Boolean(saidOff)
      && !barnAfter.includes(barn) && !(await sideways(barnPage)));
    await barnSite.close();

    // --- 7. Done -------------------------------------------------------------------
    console.log("Done, Undo, Mark all done");
    await adaPage.goto(`${site}/notifications`, { waitUntil: "load" });
    await listReady(adaPage, "the list for Done");
    const asked = [];
    const hear = (request) => {
      if (/\/api\/people\?op=notification/.test(request.url())) asked.push(`${request.method()} ${new URL(request.url()).searchParams.get("op")}`);
    };
    adaPage.on("request", hear);
    await adaPage.click(`#groups .notice[data-key="${tower}"] [data-done]`);
    await until(adaPage, (key) => !document.querySelector(`#groups .notice[data-key="${key}"]`), "the tower gone", 15, tower);
    const doneAsked = asked.slice();
    adaPage.off("request", hear);
    const doneToast = await until(adaPage, () => document.querySelector(".toast.act.shown")?.textContent.trim(), "Done's toast", 10).catch(() => "");
    check(`Done on the tower: gone from the inbox in one request (${doneAsked.join(", ")}), "${doneToast}"`,
      doneAsked.join(",") === "POST notifications_done" && /^Done: Inbox Flow Tower/.test(doneToast));
    await shot(adaPage, "docs_notifications_done_toast-1280-dark.png");
    const second2 = await adaSite.newPage();
    listen(second2, "Ada's second tab");
    await second2.goto(`${site}/notifications`, { waitUntil: "load" });
    await listReady(second2, "the second tab");
    const inSecond = await listDrawn(second2);
    await Promise.all([second2.waitForResponse((r) => /op=notifications.*view=done/.test(r.url()), { timeout: 20000 }),
      second2.click('#views [data-view="done"]')]);
    await second2.waitForTimeout(400);
    const doneSecond = await listDrawn(second2);
    check(`a second tab: not in its inbox (${inSecond.some((one) => one.key === tower)}), in its Done (${doneSecond.map((one) => one.name).join(", ")}), `
      + `the address ${new URL(second2.url()).search}`, !inSecond.some((one) => one.key === tower) && doneSecond.length === 1 && doneSecond[0].key === tower
      && new URL(second2.url()).search === "?view=done");
    await second2.reload({ waitUntil: "load" });
    await listReady(second2, "Done reloaded");
    const doneReloaded = await listDrawn(second2);
    check(`Done after a reload: ${doneReloaded.map((one) => one.name).join(", ")}, no Done or Mark all done there`,
      doneReloaded.length === 1 && doneReloaded[0].key === tower && !doneReloaded[0].done
      && await second2.evaluate(() => document.getElementById("all-done").hidden));
    await shot(second2, "docs_notifications_done-1280-dark.png", { full: true });
    // Undo, on the mill.
    await adaPage.click(`#groups .notice[data-key="${mill}"] [data-done]`);
    await until(adaPage, (key) => !document.querySelector(`#groups .notice[data-key="${key}"]`), "the mill gone", 15, mill);
    await until(adaPage, () => /^Done: Inbox Flow Mill/.test(document.querySelector(".toast.act.shown")?.textContent.trim() || ""), "the mill's Undo", 10);
    await adaPage.click(".toast.act.shown .toast-act");
    await until(adaPage, (key) => document.querySelector(`#groups .notice[data-key="${key}"]`), "the mill back", 15, mill).catch(() => null);
    await adaPage.reload({ waitUntil: "load" });
    await listReady(adaPage, "the list after Undo");
    list = await listDrawn(adaPage);
    check(`Undo: the mill back, and after a reload (${list.some((one) => one.key === mill)}); the tower still done (${!list.some((one) => one.key === tower)})`,
      list.some((one) => one.key === mill) && !list.some((one) => one.key === tower));
    for (const [width, height, theme] of [[1280, 900, "light"], [390, 844, "light"], [390, 844, "dark"]]) {
      const look = await context({ as: ada, width, height, phone: width < 500, theme });
      const page = await look.newPage();
      listen(page, `the list ${width} ${theme}`);
      await page.goto(`${site}/notifications`, { waitUntil: "load" });
      await listReady(page, `the list ${width} ${theme}`);
      await page.waitForFunction(() => [...document.querySelectorAll("#groups .pic img")].every((img) => img.complete), null, { timeout: 15000 }).catch(() => {});
      const acts = await page.evaluate(() => [...document.querySelectorAll("#groups .acts [data-done], #groups .acts summary")]
        .map((one) => Math.round(Math.min(one.getBoundingClientRect().width, one.getBoundingClientRect().height))));
      check(`${width} ${theme}: Done and More on each group, ${width < 500 ? "each 44 px on touch" : "each its size"} (${Math.min(...acts)}), nothing sideways`,
        acts.length >= 2 && (width >= 500 || acts.every((size) => size >= 44)) && !(await sideways(page)));
      await shot(page, `docs_notifications-${width}-${theme}.png`, width < 500 ? {} : { full: true });
      await look.close();
    }
    await shot(adaPage, "docs_notifications-1280-dark.png", { full: true });
    // Mark all done: the inbox empty, here and in the second tab.
    await adaPage.click("#all-done");
    await until(adaPage, () => !document.querySelector("#groups .notice") && !document.getElementById("empty").hidden, "all done", 15);
    await second2.goto(`${site}/notifications`, { waitUntil: "load" });
    await listReady(second2, "the second tab, all done");
    const emptied = await listDrawn(second2);
    const allCount = (await api("/api/people?op=feed_count", { token: ada.access_token })).body.notifications;
    await Promise.all([second2.waitForResponse((r) => /op=notifications.*view=done/.test(r.url()), { timeout: 20000 }),
      second2.click('#views [data-view="done"]')]);
    await second2.waitForTimeout(400);
    const allDone = await listDrawn(second2);
    check(`Mark all done: her inbox empty here and in the second tab (${emptied.length}), her count ${allCount}, ${allDone.length} groups in Done`,
      emptied.length === 0 && allCount === 0 && allDone.length >= 5);
    // Something new about a model done: back in the inbox, only what is new.
    const again = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
      body: { model: tower, version: 1, body: `One more thing ${rand}` } });
    await adaPage.reload({ waitUntil: "load" });
    await listReady(adaPage, "the list with something new");
    list = await listDrawn(adaPage);
    check(`something new on the tower (${again.status}): back in the inbox, its one new row (${list.map((one) => `${one.name}: ${one.kinds.join(",")}`).join("; ")})`,
      again.status === 201 && list.length === 1 && list[0].key === tower && list[0].kinds.join(",") === "comment");
    await second2.close();
  }
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
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => {});
  await browser.close();
}
console.log(failed ? `inbox: ${failed} FAILED` : "inbox: the grid, muted, done and the newest five: ok");
process.exit(failed ? 1 : 0);
