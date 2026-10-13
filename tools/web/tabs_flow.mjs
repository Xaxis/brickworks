// Several tabs of one browser, each on a project of its own, in real Chromium.
//
//   node tools/web/relay_server.mjs 8790 --static=build/web &     # a local export
//   node tools/web/tabs_flow.mjs --url=http://127.0.0.1:8790/app --out=shots/tabs
//   BW_BYPASS=… node tools/web/tabs_flow.mjs --url=<a preview>/app --out=…
//
// The owner: "multiple tabs of brickworks studio in the same browser should
// be able to support and work on separate projects". One browser context,
// so one IndexedDB and one signed-in account, and three pages in it, as a
// person's tabs are:
//
//   1. Each tab opens a different model (the house, the kart, the tree),
//      is renamed by typing, and has a part deleted by clicking it and
//      pressing Delete. Each has its own id (window.brickworksTab), and its
//      own autosave reaches the browser's storage under its own session,
//      named as it was renamed.
//   2. Each tab, reloaded, comes back with its own model: its name in the
//      tab's title and its own number of parts.
//   3. A save in one tab survives the others writing: the model saved in
//      the first is still in storage after the second and third have each
//      changed and autosaved their own.
//   4. The third tab opens that saved model; the first deletes another part
//      and saves again; the third is offered a reload (its Reload it
//      button, the app's ReloadOffer) and, reloading, has the first's model
//      part for part.
//   5. Claude, signed in to the account with OAuth as claude.ai is, through
//      the deployment's relay: each tab, reloaded, switched its connector on
//      by itself and is a target of its own; tabs lists the three by the ids
//      the pages have and the names their models were given; a look
//      targeted at each is answered by that tab, naming it, with its own
//      part count; an edit targeted at the kart lands in the kart's page
//      alone, read back from the pages and over the relay; and a tab closed
//      mid-session is reported on the next call, nothing done.
//
// Before 2026-10-13 every tab wrote the one autosave and the engine made
// the stored copy of user:// match its own wholesale, and the tabs shared
// one connector. Run against the live site then, it failed from step 1: no
// tab had an id or a session, the house's tab reloaded showing the tree's
// model ("Tabs Tree"), and that page then said its sign-in had ended, so the
// run stopped there.
//
// Signs in as a throwaway account of its own, deleted at the end, so the
// tabs other flows have open on the shared test account are not among its.
import { launch } from "./browser.mjs";
import { mintSession, STORAGE_KEY } from "./session.mjs";
import { createHash, randomBytes } from "node:crypto";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8790/app");
const out = args.out || "shots/tabs";
const bypass = args.bypass || process.env.BW_BYPASS || "";
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
// Where the engine keeps user:// in the browser's storage: the project's
// user folder under /userfs, not /userfs itself.
const USER = "/userfs/godot/app_userdata/Brickworks";
const join = (base, query) => `${base}${base.includes("?") ? "&" : "?"}${query}`;

const EMAIL = `delivered+bwtabsflow${randomBytes(3).toString("hex")}@resend.dev`;
const browser = await launch({ signedOut: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
// One session, minted here and given to the pages as a returning visitor's
// browser would hold it; its access token is the person's yes to Claude
// below. A second session minted for that had the pages told their
// sign-in had ended.
const minted = await mintSession(EMAIL);
await context.addInitScript(([name, value]) => {
  try {
    if (!localStorage.getItem(name)) localStorage.setItem(name, value);
  } catch {}
}, [STORAGE_KEY, JSON.stringify(minted.kept)]);
const problems = [];
const origin = new URL(url).origin;
const relayHeaders = bypass ? { "x-vercel-protection-bypass": bypass } : {};

// Claude's sign-in to the account, as claude.ai does it: its published
// identity, PKCE, the person's yes with their session, the code traded.
async function claudeToken() {
  const session = minted.access_token;
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${origin}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...relayHeaders, "content-type": "application/json", authorization: `Bearer ${session}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "tabs",
      resource: `${origin}/api/mcp` }),
  })).json();
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) throw new Error(`no code: ${JSON.stringify(yes)}`);
  const tokens = await (await fetch(`${origin}/oauth/token`, {
    method: "POST",
    headers: { ...relayHeaders, "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back,
      client_id: client, code_verifier: verifier, resource: `${origin}/api/mcp` }).toString(),
  })).json();
  return tokens.access_token || "";
}
let sent = 0;
// One MCP request as Claude makes it: [status, body, the session id handed out].
async function mcp(token, session, method, params) {
  const answer = await fetch(`${origin}/api/mcp`, {
    method: "POST",
    headers: { ...relayHeaders, "content-type": "application/json",
      accept: "application/json, text/event-stream", authorization: `Bearer ${token}`,
      ...(session ? { "mcp-session-id": session } : {}) },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++sent, method, params }),
  });
  const raw = await answer.text();
  let body = {};
  try { body = JSON.parse(raw); } catch {}
  return [answer.status, body, answer.headers.get("mcp-session-id") || "", raw];
}
async function call(token, session, name, args = {}) {
  const since = Date.now();
  const [status, body, , raw] = await mcp(token, session, "tools/call", { name, arguments: args });
  const result = body.result || {};
  const words = (result.content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
  if (!words) console.log(`        (${name}: ${status} after ${Date.now() - since} ms: ${raw.slice(0, 200)})`);
  return { words, error: Boolean(result.isError) };
}
const partsSaid = (words) => Number((/(\d+) parts are on the baseplate/.exec(words) || [])[1] ?? -1);

const TABS = [
  { model: "house", name: "Tabs House" },
  { model: "kart", name: "Tabs Kart" },
  { model: "tree", name: "Tabs Tree" },
];

async function state(page) {
  return page.evaluate(() => window.brickworksState || {});
}
async function controlAt(page, name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate((c) => (window.brickworksControls || {})[c], name);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/missing_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed its ${name} control`);
}
async function titleBecomes(page, wanted, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    if ((await page.title()) === wanted) return true;
    await page.waitForTimeout(500);
  }
  return false;
}
async function rename(page, name) {
  const field = await controlAt(page, "model_name");
  await page.mouse.click(field.x, field.y);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(name);
  await page.keyboard.press("Enter");
  await page.waitForTimeout(500);
  // Out of the field, so the keys after go to the model.
  await page.keyboard.press("Escape");
  return titleBecomes(page, `${name} — Brickworks`, 20);
}
// Click a part as a person does, and delete it. The parts' places on the
// page come from the app (brickworksLayout.targets).
async function deleteAPart(page) {
  const before = (await state(page)).bricks;
  await page.keyboard.press("KeyF");
  await page.waitForTimeout(1500);
  await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
  let layout = null;
  for (let n = 0; n < 60 && !layout; n++) {
    layout = await page.evaluate(() => window.brickworksLayout || null);
    if (!layout) await page.waitForTimeout(250);
  }
  for (const target of (layout && layout.targets) || []) {
    await page.mouse.move(target.x, target.y, { steps: 3 });
    await page.waitForTimeout(300);
    await page.mouse.click(target.x, target.y);
    await page.waitForTimeout(700);
    if (((await state(page)).selected || 0) !== 1) continue;
    await page.keyboard.press("Delete");
    for (let n = 0; n < 20; n++) {
      await page.waitForTimeout(300);
      if ((await state(page)).bricks === before - 1) return true;
    }
  }
  return false;
}
// What the browser has stored, read from a page of it: path -> its text.
async function stored(page, prefix) {
  return page.evaluate((wanted) => new Promise((resolve) => {
    const found = {};
    const opened = indexedDB.open("/userfs");
    opened.onerror = () => resolve(found);
    opened.onsuccess = () => {
      const db = opened.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); resolve(found); return; }
      const cursor = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").openCursor();
      cursor.onsuccess = (e) => {
        const c = e.target.result;
        if (!c) { db.close(); resolve(found); return; }
        const key = String(c.key);
        if (key.startsWith(wanted) && c.value && c.value.contents) {
          found[key] = new TextDecoder().decode(c.value.contents);
        }
        c.continue();
      };
    };
  }), prefix);
}
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await wait(500);
  }
  return false;
}
async function open(page, query) {
  const target = query ? join(url, query) : url;
  await page.goto(target, { waitUntil: "domcontentloaded", timeout: 180000 });
  await controlAt(page, "model_name");
  // The parts arrive over the network; the model is whole once they have.
  await page.waitForTimeout(8000);
}

// Each tab, its own project.
const pages = [];
for (const [n, tab] of TABS.entries()) {
  const page = await context.newPage();
  page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  // What the app says of its sign-in, to tell a tab signed out from a slow one.
  page.on("console", (m) => {
    if (/sign|session|refus|renew/i.test(m.text())) console.log(`        [${tab.model}] ${m.text().slice(0, 160)}`);
  });
  if (n === 0 && bypass) {
    await page.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
      { waitUntil: "domcontentloaded", timeout: 180000 });
  }
  await open(page, `model=res://models/${tab.model}.ldr`);
  tab.page = page;
  pages.push(page);
}
console.log("\neach tab, its own project");
for (const tab of TABS) {
  check(`${tab.model}: renamed by typing to "${tab.name}"`, await rename(tab.page, tab.name));
  check(`${tab.model}: a part clicked and deleted`, await deleteAPart(tab.page));
  tab.bricks = (await state(tab.page)).bricks;
  tab.id = await tab.page.evaluate(() => window.brickworksTab || "");
}
const ids = new Set(TABS.map((t) => t.id).filter(Boolean));
check(`three tabs, three ids of their own: ${TABS.map((t) => t.id || "none").join(", ")}`, ids.size === 3);
for (const tab of TABS) {
  const key = `${USER}/sessions/${tab.id}/autosave.ldr`;
  const landed = await until(async () => {
    const text = (await stored(tab.page, key))[key] || "";
    return text.split("\n")[0] === `0 ${tab.name}`;
  }, 120);
  check(`${tab.name}: its autosave reaches the browser's storage in its own session (${tab.bricks} parts)`, landed);
}
const shared = (await stored(pages[0], `${USER}/autosave.ldr`))[`${USER}/autosave.ldr`];
if (shared) console.log(`  (the one autosave of before says: ${shared.split("\n")[0]})`);
await pages[0].screenshot({ path: `${out}/1_house.png` }).catch(() => {});
await pages[1].screenshot({ path: `${out}/1_kart.png` }).catch(() => {});

// Claude connected to the account now: every tab the person opens after
// listens by itself, as the reloads below do.
let token = "";
try {
  token = await claudeToken();
} catch (trouble) {
  console.log(`  (Claude could not sign in: ${trouble.message})`);
}
check("Claude signs in to the account with OAuth", token.startsWith("bwa_"));

console.log("\neach tab, reloaded");
for (const tab of TABS) {
  await open(tab.page, "");
  const named = await titleBecomes(tab.page, `${tab.name} — Brickworks`, 120);
  const bricks = (await state(tab.page)).bricks;
  check(`${tab.model}'s tab reloads its own model: "${await tab.page.title()}", ${bricks} parts (was ${tab.bricks})`,
    named && bricks === tab.bricks);
  check(`...in the same session: ${await tab.page.evaluate(() => window.brickworksTab || "none")}`,
    (await tab.page.evaluate(() => window.brickworksTab || "")) === tab.id);
}

console.log("\na save in one tab, kept while the others write");
const [house, kart, tree] = TABS;
const savedKey = `${USER}/models/${house.name}.ldr`;
await house.page.mouse.click((await controlAt(house.page, "save")).x, (await controlAt(house.page, "save")).y);
check(`"${house.name}" saved in its tab reaches the browser's storage`,
  await until(async () => Boolean((await stored(house.page, savedKey))[savedKey]), 120));
for (const tab of [kart, tree]) {
  await rename(tab.page, `${tab.name} 2`);
  tab.name = `${tab.name} 2`;
  const key = `${USER}/sessions/${tab.id}/autosave.ldr`;
  await until(async () => ((await stored(tab.page, key))[key] || "").startsWith(`0 ${tab.name}`), 120);
}
await wait(3000);
check(`...and is still there after the other two tabs changed and autosaved their own`,
  Boolean((await stored(house.page, savedKey))[savedKey]));

console.log("\na save in one tab, offered to another that has it open");
await open(tree.page, `model=${encodeURIComponent(`user://models/${house.name}.ldr`)}`);
check(`the tree's tab opens "${house.name}" from the saved models`,
  await titleBecomes(tree.page, `${house.name} — Brickworks`, 60));
check(`the house's tab deletes another part`, await deleteAPart(house.page));
const after = (await state(house.page)).bricks;
await house.page.mouse.click((await controlAt(house.page, "save")).x, (await controlAt(house.page, "save")).y);
// The page says when its writes are in the browser's storage.
await wait(2000);
await until(async () => (await house.page.evaluate(() => window.brickworksUnstored ? window.brickworksUnstored() : 0)) === 0, 180);
let offered = false;
for (let n = 0; n < 240 && !offered; n++) {
  offered = Boolean(await tree.page.evaluate(() => (window.brickworksControls || {}).reload_model));
  if (!offered) await wait(500);
}
await tree.page.screenshot({ path: `${out}/2_offered.png` }).catch(() => {});
check(`...and saving it there, the tab that has it open is offered a reload`, offered);
if (offered) {
  const reload = await controlAt(tree.page, "reload_model");
  await tree.page.mouse.click(reload.x, reload.y);
  const same = await until(async () => (await state(tree.page)).bricks === after, 60);
  check(`...and reloading it, has the saved model part for part: ${(await state(tree.page)).bricks} of ${after}`, same);
  await tree.page.screenshot({ path: `${out}/3_reloaded.png` }).catch(() => {});
}
console.log("\nClaude, through the relay, with three tabs open");
for (const tab of TABS) {
  tab.listening = await until(async () => Boolean(await tab.page.evaluate(() => window.brickworksConnector || "")), 120);
  tab.bricks = (await state(tab.page)).bricks;
  tab.name = (await tab.page.title()).replace(/ — Brickworks$/, "");
}
check(`each tab switched its connector on by itself: ${TABS.map((t) => `${t.id} ${t.listening ? "on" : "off"}`).join(", ")}`,
  TABS.every((t) => t.listening));
// Long enough for each page's word that it is alive, with its model's name.
await wait(12000);
const [, , session] = await mcp(token, "", "initialize", { protocolVersion: "2025-06-18",
  capabilities: {}, clientInfo: { name: "tabs-flow", version: "1" } });
check(`initialize hands out a session id: ${session.slice(0, 8)}…`, session.length >= 16);
const listed = await call(token, session, "tabs");
console.log(listed.words.split("\n").map((line) => `        ${line}`).join("\n"));
check("tabs lists the three, by the ids the pages have and their models' names",
  listed.words.includes("3 Brickworks tabs are open")
    && TABS.every((t) => listed.words.includes(`${t.id}: “${t.name}”`)));
for (const tab of TABS) {
  const look = await call(token, session, "look_at_model", { target: tab.id });
  check(`a look targeted at ${tab.id} is answered by that tab, named, with its ${tab.bricks} parts: `
      + `"${look.words.split("\n")[0]}" ${partsSaid(look.words)}`,
    look.words.startsWith(`Tab ${tab.id}, “${tab.name}”.`) && partsSaid(look.words) === tab.bricks);
}
const [home, cart, wood] = TABS;
// A 2 x 2 brick on the ground beside the kart, clear of it: where the
// kart stands, as its tab says.
const span = /They span x (-?[\d.]+)\.\.(-?[\d.]+), z (-?[\d.]+)\.\.(-?[\d.]+) studs/
  .exec((await call(token, session, "look_at_model", { target: cart.id })).words) || [];
const beside = { x: Math.round(Number(span[2] || 0)) + 3, z: Math.round(Number(span[3] || 0)) };
const edit = await call(token, session, "edit_model", { target: cart.id,
  add: [{ part: "3003", color: 1, x: beside.x, y: 0, z: beside.z, rot: 0 }] });
if (!edit.words.startsWith(`Tab ${cart.id}`) || edit.error) console.log(`        ${edit.words.slice(0, 300)}`);
const grew = await until(async () => (await state(cart.page)).bricks === cart.bricks + 1, 30);
check(`an edit targeted at the kart (${cart.id}) says so and lands in the kart's page: `
    + `${(await state(cart.page)).bricks} parts, was ${cart.bricks}`,
  edit.words.startsWith(`Tab ${cart.id}`) && grew);
check(`...and in neither other page: ${(await state(home.page)).bricks} and ${(await state(wood.page)).bricks}`,
  (await state(home.page)).bricks === home.bricks && (await state(wood.page)).bricks === wood.bricks);
// A look, once the tab is free: an edit drawn in software can still be
// going as a job (ToolJobs) when the next call comes, and is waited for.
async function partsIn(tab) {
  let said = "";
  for (let n = 0; n < 12; n++) {
    said = (await call(token, session, "look_at_model", { target: tab.id })).words;
    if (partsSaid(said) >= 0) return partsSaid(said);
    if (/job (\d+)/.test(said)) {
      await call(token, session, "job", { target: tab.id, id: Number(/job (\d+)/.exec(said)[1]), wait_s: 10 });
    } else {
      await wait(5000);
    }
  }
  console.log(`        ${said.slice(0, 300)}`);
  return -1;
}
const backCart = await partsIn(cart);
const backHome = await partsIn(home);
check(`read back over the relay: the kart ${backCart}, the house ${backHome}`,
  backCart === cart.bricks + 1 && backHome === home.bricks);
const chose = await call(token, session, "select_tab", { tab: wood.id });
check(`select_tab ${wood.id}: "${chose.words.split("\n").pop()}"`, chose.words.includes(`go to tab ${wood.id} now`));
// Closed as a person closes a tab: if a write is still on its way the page
// asks first, and they say leave.
wood.page.on("dialog", (dialog) => dialog.accept().catch(() => {}));
await wood.page.close({ runBeforeUnload: true });
await wait(3000);
const gone = await call(token, session, "edit_model", {
  add: [{ part: "3005", color: 4, x: 0, y: 0, z: 20, rot: 0 }] });
check(`the tree's tab closed, the session's next call says so: "${gone.words.split(".")[0]}"`,
  gone.error && gone.words.includes(`The tab this session was working in, ${wood.id}`)
    && gone.words.includes("has closed, so nothing was done"));
check(`...and nothing was done in the tabs still open: ${(await state(home.page)).bricks}, ${(await state(cart.page)).bricks}`,
  (await state(home.page)).bricks === home.bricks && (await state(cart.page)).bricks === cart.bricks + 1);

check(`the pages raised no errors${problems.length ? ": " + problems[0] : ""}`, problems.length === 0);

await browser.close();
// By its id, which the session names: looking it up by email reads one page
// of a thousand users, and the test project has more.
async function removeAccount() {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  if (!base || !secret || !minted.kept.user_id) return false;
  const gone = await fetch(`${base}/auth/v1/admin/users/${minted.kept.user_id}`, {
    method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` },
  });
  return gone.ok;
}
const removed = await removeAccount().catch(() => false);
console.log(`  (the throwaway account ${removed ? "deleted" : "NOT deleted"})`);
console.log(failed ? `\n${failed} failed`
  : "\nseveral tabs, each on its own project: autosaves kept apart, and a save offered to the tab that has it open");
process.exit(failed ? 1 : 0);
