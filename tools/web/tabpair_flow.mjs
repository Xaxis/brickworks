// Two chats, two tabs, in real Chromium: each Claude chat builds only in its
// own Brickworks tab, and each tab shows which chat drives it.
//
//   node tools/web/relay_server.mjs 8832 --static=build/web &     # a local export
//   node tools/web/tabpair_flow.mjs --url=http://127.0.0.1:8832/app --out=shots/tabpair
//   BW_BYPASS=… node tools/web/tabpair_flow.mjs --url=<a preview>/app --out=…
//
// The owner (2026-10-17): "say a user has two brickworks studio tabs open
// with separate projects, and two claude.ai tabs open, how does the user
// 'map' a given claude session to the right tab so they dont interfere".
// One browser context signed in to a throwaway account, two tabs in it on
// two models, and Claude signed in to the account as claude.ai is, with
// three MCP sessions (three Mcp-Session-Ids) through the relay:
//
//   1. Each tab, Claude connected, shows its own id on the toolbar and that
//      no chat works in it.
//   2. A fresh chat that names no tab is stopped before its first change
//      and shown both tabs; neither model changes.
//   3. New chat for this tab, in each tab's Account: claude.ai opens on a
//      new chat whose first message names that tab and its model; the
//      Claude app's and Claude Code's links name it too, and the page stays.
//   4. Chat A chooses the castle by its model's name, chat B the truck by
//      the id its tab's first message gave; each change lands in its own
//      tab and not the other. Each tab then shows a chat working in it.
//   5. Chat C chooses the castle too: the castle's tab says two chats are
//      working in it; C's undo leaves A's change standing; Keep this one
//      beside A moves C off; C's next call is told so and changes nothing,
//      and A builds on.
//
// Pictures: 1_castle.png and 1_truck.png (each tab with Account open, its
// chat named), 2_two_chats.png, 3_kept.png.
import { launch, withAssistant } from "./browser.mjs";
import { mintSession, STORAGE_KEY } from "./session.mjs";
import { createHash, randomBytes } from "node:crypto";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = withAssistant(String(args.url || "http://127.0.0.1:8832/app"));
const out = args.out || "shots/tabpair";
const bypass = args.bypass || process.env.BW_BYPASS || "";
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const join = (base, query) => `${base}${base.includes("?") ? "&" : "?"}${query}`;
const origin = new URL(url).origin;
const relayHeaders = bypass ? { "x-vercel-protection-bypass": bypass } : {};

const EMAIL = `delivered+bwtabpairflow${randomBytes(3).toString("hex")}@resend.dev`;
const browser = await launch({ signedOut: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const minted = await mintSession(EMAIL);
await context.addInitScript(([name, value]) => {
  try {
    if (!localStorage.getItem(name)) localStorage.setItem(name, value);
  } catch {}
}, [STORAGE_KEY, JSON.stringify(minted.kept)]);
const problems = [];
// What New chat for this tab opens: the address claude.ai is asked for,
// kept, and answered here, so no test reaches claude.ai itself.
const popups = [];
await context.route(/^https:\/\/claude\.ai\//, (route) => {
  popups.push(route.request().url());
  return route.fulfill({ status: 200, contentType: "text/html", body: "<title>claude.ai</title>" });
});

async function claudeToken() {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${origin}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...relayHeaders, "content-type": "application/json", authorization: `Bearer ${minted.access_token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "tabpair",
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
  try { body = JSON.parse(raw); } catch {
    // An event stream: the last message is the answer.
    const last = raw.split("\n").filter((l) => l.startsWith("data: ")).pop();
    try { body = JSON.parse(last.slice(6)); } catch {}
  }
  return [answer.status, body, answer.headers.get("mcp-session-id") || ""];
}
// A Claude chat: its own session, and its name as its tab is shown it.
async function newChat(token) {
  const [, , session] = await mcp(token, "", "initialize", { protocolVersion: "2025-06-18",
    capabilities: {}, clientInfo: { name: "tabpair-flow", version: "1" } });
  return {
    session,
    chat: createHash("sha256").update(`session:${session}`).digest("hex").slice(0, 8),
    async call(name, input = {}) {
      const [, body] = await mcp(token, session, "tools/call", { name, arguments: input });
      const result = body.result || {};
      return { words: (result.content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n"),
        error: Boolean(result.isError) };
    },
  };
}
const head = (words) => words.split("\n")[0].slice(0, 150);

async function state(page) {
  return page.evaluate(() => window.brickworksState || {});
}
async function claude(page) {
  return page.evaluate(() => window.brickworksClaude || {});
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
async function press(page, name) {
  const at = await controlAt(page, name, 60);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(600);
}
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await wait(500);
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
  await page.keyboard.press("Escape");
  return until(async () => (await page.title()) === `${name} — Brickworks`, 20);
}
// Account open, for a picture of what the tab says about Claude.
async function accountOpen(page) {
  if (!(await page.evaluate(() => Boolean((window.brickworksControls || {}).account_done)))) {
    await press(page, "account");
  }
  return until(async () => Boolean(await page.evaluate(() => (window.brickworksControls || {}).account_done)), 20);
}
async function accountShut(page) {
  if (await page.evaluate(() => Boolean((window.brickworksControls || {}).account_done))) {
    await press(page, "account_done");
  }
}

// Claude connected to the account first, as a person who has used it before:
// every tab opened after listens by itself.
let token = "";
try {
  token = await claudeToken();
} catch (trouble) {
  console.log(`  (Claude could not sign in: ${trouble.message})`);
}
check("Claude signs in to the account with OAuth", token.startsWith("bwa_"));

const TABS = [
  { model: "house", name: "Pair Castle" },
  { model: "kart", name: "Pair Truck" },
];
for (const [n, tab] of TABS.entries()) {
  const page = await context.newPage();
  page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  if (n === 0 && bypass) {
    await page.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
      { waitUntil: "domcontentloaded", timeout: 180000 });
  }
  await page.goto(join(url, `model=res://models/${tab.model}.ldr`), { waitUntil: "domcontentloaded", timeout: 180000 });
  await controlAt(page, "model_name");
  await page.waitForTimeout(8000);
  tab.page = page;
}
const [castle, truck] = TABS;

console.log("\n1. two tabs, each its own model, Claude connected");
for (const tab of TABS) {
  check(`${tab.model}: renamed "${tab.name}"`, await rename(tab.page, tab.name));
}
for (const tab of TABS) {
  tab.on = await until(async () => Boolean(await tab.page.evaluate(() => window.brickworksConnector || "")), 120);
  tab.id = (await claude(tab.page)).tab || "";
  tab.bricks = (await state(tab.page)).bricks;
}
check(`each tab switched its connector on by itself: ${TABS.map((t) => `${t.id} ${t.on ? "on" : "off"}`).join(", ")}`,
  TABS.every((t) => t.on) && castle.id !== truck.id);
// Each page's word that it is alive, with its model's name.
await wait(12000);
for (const tab of TABS) {
  const badge = (await claude(tab.page)).badge;
  check(`${tab.name}'s toolbar names the tab, no chat in it: "${badge}"`, badge === `Tab ${tab.id}`);
}

console.log("\n2. a fresh chat that names no tab");
const a = await newChat(token);
check(`initialize hands chat A a session: ${a.session.slice(0, 8)}…`, a.session.length >= 16);
const stopped = await a.call("edit_model", { add: [{ part: "3003", color: 4, x: 30, y: 0, z: 30, rot: 0 }] });
console.log(stopped.words.split("\n").map((l) => `        ${l}`).join("\n"));
check("its first change is stopped, nothing done, both tabs listed with how to choose",
  stopped.error && stopped.words.startsWith("Nothing was done")
  && stopped.words.includes(`${castle.id}: “${castle.name}”`) && stopped.words.includes(`${truck.id}: “${truck.name}”`)
  && stopped.words.includes("select_tab"));
await wait(3000);
check(`...and neither model changed: ${(await state(castle.page)).bricks}, ${(await state(truck.page)).bricks}`,
  (await state(castle.page)).bricks === castle.bricks && (await state(truck.page)).bricks === truck.bricks);

console.log("\n3. New chat for this tab");
for (const tab of TABS) {
  await accountOpen(tab.page);
  const before = popups.length;
  await press(tab.page, "account_new_chat");
  const opened = await until(async () => popups.length > before
    && String((await claude(tab.page)).opened || "").startsWith("https://claude.ai/new"), 15);
  const said = await claude(tab.page);
  tab.message = said.first_message || "";
  const link = String(said.opened || "");
  const landed = popups[popups.length - 1] || "";
  const message = landed.includes("?q=") ? decodeURIComponent(landed.split("?q=")[1].split("&")[0]) : "";
  check(`${tab.name}: claude.ai opens a new chat, its first message naming the tab: "${message}"`,
    link.startsWith("https://claude.ai/new?q=") && opened && message === tab.message
      && message.includes(tab.id) && message.includes(tab.name));
}
const where = castle.page.url();
await press(castle.page, "account_new_chat_app");
await until(async () => String((await claude(castle.page)).opened || "").startsWith("claude://"), 15);
const app = String((await claude(castle.page)).opened || "");
await wait(2000);
check(`the Claude app's link names it too, and the page stays: ${app.slice(0, 60)}…`,
  app.startsWith("claude://claude.ai/new?q=") && decodeURIComponent(app.split("?q=")[1]) === castle.message
    && castle.page.url() === where && (await state(castle.page)).bricks === castle.bricks);
await press(castle.page, "account_new_chat_code");
await until(async () => String((await claude(castle.page)).opened || "").startsWith("claude-cli://"), 15);
const code = String((await claude(castle.page)).opened || "");
check(`Claude Code's link names it too: ${code.slice(0, 60)}…`,
  code.startsWith("claude-cli://open?q=") && decodeURIComponent(code.split("?q=")[1]) === castle.message);
for (const tab of TABS) await accountShut(tab.page);

console.log("\n4. chat A in the castle by name, chat B in the truck by its tab's message");
const chose = await a.call("select_tab", { tab: `the ${castle.name.toLowerCase()} tab` });
check(`A: select_tab "the ${castle.name.toLowerCase()} tab": "${chose.words.split("\n").pop()}"`,
  !chose.error && chose.words.includes(`go to tab ${castle.id} now`));
const b = await newChat(token);
const named = /tab ([a-z2-9]{4,12})/.exec(truck.message || "") || [];
check(`B reads the truck's tab from its first message: ${named[1]}`, named[1] === truck.id);
// A part on the ground beside each model, clear of it.
async function beside(chat, target) {
  const look = await chat.call("look_at_model", target ? { target } : {});
  const span = /They span x (-?[\d.]+)\.\.(-?[\d.]+), z (-?[\d.]+)\.\.(-?[\d.]+) studs/.exec(look.words) || [];
  return { x: Math.round(Number(span[2] || 0)) + 3, z: Math.round(Number(span[3] || 0)), look };
}
const aSpot = await beside(a);
check(`A's look is in the castle: "${head(aSpot.look.words)}"`, aSpot.look.words.startsWith(`Tab ${castle.id}`));
const aEdit = await a.call("edit_model", { add: [{ part: "3003", color: 4, x: aSpot.x, y: 0, z: aSpot.z, rot: 0 }] });
const castleGrew = await until(async () => (await state(castle.page)).bricks === castle.bricks + 1, 40);
check(`A's change lands in the castle: "${head(aEdit.words)}" ${(await state(castle.page)).bricks} parts, was ${castle.bricks}`,
  aEdit.words.startsWith(`Tab ${castle.id}`) && castleGrew);
castle.bricks += castleGrew ? 1 : 0;
const bSpot = await beside(b, named[1]);
const bEdit = await b.call("edit_model", { add: [{ part: "3003", color: 1, x: bSpot.x, y: 0, z: bSpot.z, rot: 0 }] });
const truckGrew = await until(async () => (await state(truck.page)).bricks === truck.bricks + 1, 40);
check(`B's change lands in the truck: "${head(bEdit.words)}" ${(await state(truck.page)).bricks} parts, was ${truck.bricks}`,
  bEdit.words.startsWith(`Tab ${truck.id}`) && truckGrew);
truck.bricks += truckGrew ? 1 : 0;
const bLook = await b.call("look_at_model");
check(`B, untargeted now, stays in the truck: "${head(bLook.words)}"`, bLook.words.startsWith(`Tab ${truck.id}`));
check(`...and neither touched the other's model: castle ${(await state(castle.page)).bricks}, truck ${(await state(truck.page)).bricks}`,
  (await state(castle.page)).bricks === castle.bricks && (await state(truck.page)).bricks === truck.bricks);
for (const [tab, chat] of [[castle, a], [truck, b]]) {
  const shown = await until(async () => {
    const said = await claude(tab.page);
    return said.badge === `Claude working · tab ${tab.id}` && (said.chats || []).length === 1
      && said.chats[0].chat === chat.chat;
  }, 30);
  await accountOpen(tab.page);
  await wait(1500);
  const said = await claude(tab.page);
  check(`${tab.name} shows one chat working in it, the right one: "${said.badge}" / "${(said.account_says || "").split("\n")[1] || ""}"`,
    shown && /A Claude chat is working here: since \d\d:\d\d, last: changed the model/.test(said.account_says || ""));
  await tab.page.screenshot({ path: `${out}/1_${tab === castle ? "castle" : "truck"}.png` });
  await accountShut(tab.page);
}

console.log("\n5. a second chat in the castle, and keeping one");
const c = await newChat(token);
const intoHeld = await c.call("select_tab", { tab: castle.name });
check(`C chooses the castle and is told another chat works there: "${intoHeld.words.slice(0, 170)}…"`,
  intoHeld.words.includes(`go to tab ${castle.id} now`) && intoHeld.words.includes("Careful: another chat"));
const two = await until(async () => (await claude(castle.page)).badge === `2 Claude chats · tab ${castle.id}`, 30);
await accountOpen(castle.page);
await wait(1500);
const twoSaid = await claude(castle.page);
check(`the castle's toolbar and Account say two chats are working in it: "${twoSaid.badge}"`,
  two && (twoSaid.account_says || "").includes("2 Claude chats are working in this tab"));
await castle.page.screenshot({ path: `${out}/2_two_chats.png` });
check(`...while the truck's still says one: "${(await claude(truck.page)).badge}"`,
  (await claude(truck.page)).badge === `Claude working · tab ${truck.id}`);
// Undo per chat: C's undo does not take back A's change.
const theirs = await c.call("undo");
await wait(2000);
check(`C's undo leaves A's change standing: "${theirs.words.split("\n").slice(1).join(" ").slice(0, 160)}"`,
  theirs.words.includes("was made by another Claude chat") && (await state(castle.page)).bricks === castle.bricks);
const keepA = (twoSaid.chats || []).findIndex((one) => one.chat === a.chat);
check(`A is among the castle's chats (row ${keepA})`, keepA >= 0);
await press(castle.page, `account_keep_chat_${Math.max(0, keepA)}`);
const one = await until(async () => {
  const said = await claude(castle.page);
  return said.badge === `Claude working · tab ${castle.id}` && (said.chats || []).length === 1 && said.chats[0].chat === a.chat;
}, 30);
await wait(1000);
await castle.page.screenshot({ path: `${out}/3_kept.png` });
check(`Keep this one beside A: the castle has one chat again, A: "${(await claude(castle.page)).badge}"`, one);
const moved = await c.call("edit_model", { add: [{ part: "3003", color: 14, x: aSpot.x + 4, y: 0, z: aSpot.z, rot: 0 }] });
console.log(moved.words.split("\n").map((l) => `        ${l}`).join("\n"));
await wait(3000);
check("C's next call is told it was moved off, and the castle did not change",
  moved.error && moved.words.startsWith(`The person moved this chat off tab ${castle.id}`)
  && (await state(castle.page)).bricks === castle.bricks);
const aOn = await a.call("edit_model", { add: [{ part: "3003", color: 2, x: aSpot.x, y: 0, z: aSpot.z + 4, rot: 0 }] });
check(`A builds on in the castle, no longer warned: "${head(aOn.words)}"`,
  aOn.words.startsWith(`Tab ${castle.id}`) && !aOn.words.includes("Careful")
  && await until(async () => (await state(castle.page)).bricks === castle.bricks + 1, 40));

check(`the pages raised no errors${problems.length ? ": " + problems[0] : ""}`, problems.length === 0);
await browser.close();
async function removeAccount() {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  if (!base || !secret || !minted.kept.user_id) return false;
  const gone = await fetch(`${base}/auth/v1/admin/users/${minted.kept.user_id}`, {
    method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` },
  });
  return gone.ok;
}
console.log(`  (the throwaway account ${(await removeAccount().catch(() => false)) ? "deleted" : "NOT deleted"})`);
console.log(failed ? `\n${failed} failed`
  : "\ntwo chats, two tabs: each builds in its own, a new one waits for a choice, and a tab keeps one");
process.exit(failed ? 1 : 0);
