// A part pointed out in a Build together room of two tabs (pointat, APP_UX8
// #17): seen by both within 500 ms with the pointer's name, gone after 5 s
// or on Esc; and the owner's Claude pointing in one call.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9011 --static=build/web &
//   node tools/web/pointat_flow.mjs --url=http://127.0.0.1:9011 --out=shots/pointat
//   BW_BYPASS=… node tools/web/pointat_flow.mjs --url=<a preview> --out=DIR
//
// Two browser contexts, each a person with their own account (throwaway
// ones at Resend's test addresses, deleted at the end), at 1280 x 720 (or
// --size=WxH). The owner opens the car, File, Build together…, Start a
// session; the other opens the link and is in.
//
//   1. 20 times, the owner puts the pointer on a part (one of those the page
//      names as clickable, each other than the last) and presses Alt+W, as
//      a person does: the timer starts at the key. The owner's own tab
//      shows it at once; the second tab has it outlined in the owner's
//      colour, by the owner's name, and the time to the frame it was drawn
//      in is kept, with where it went (each page's Together.timing: the
//      owner's page handling the key, the server saying it, the second page
//      having it and drawing it). Bar: every one seen, p95 within 500 ms;
//      or, as together_flow holds the pointer under load, 95 of 100 within
//      500 ms or with their trip (the key handled to the line had: the send,
//      the server, the network both ways) within 500 ms less a frame each
//      side. This box draws in software at a load of 30-60, and a page
//      held by its own frame is the box's, not the trip's.
//   2. The outline read off the second tab's pixels: the owner's colour
//      more than before by an outline's worth.
//   3. One alone: it stays 4.5 s and is gone 5 s after (by 5.7 s) on both
//      tabs, and the second tab's pixels are back to the pointer's alone.
//   4. Esc in the owner's tab takes it back: gone there at once, and in the
//      second tab within 500 ms (the same rule).
//   5. Esc in the second tab puts it away there alone: the owner's own
//      still shown.
//   6. The owner's Claude: point_at in one MCP call (its part a number the
//      owner's page names), shown in the second tab within 500 ms of the
//      answer, named "<owner>'s Claude".
//
// Red on a build without it: Alt+W shows nothing, in either tab.
// Pictures in --out. Exit 1 on any failure.
import { askApp, clickStill, launch, typeInMenu } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import { loadavg } from "node:os";
import { inflateSync } from "node:zlib";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:9011").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/pointat"));
mkdirSync(out, { recursive: true });
const bypass = args.bypass || process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const [width, height] = String(args.size || "1280x720").split("x").map(Number);
const ROUNDS = Number(args.rounds || 20);
const BAR_MS = 500;
const rand = randomBytes(4).toString("hex");
const emails = {
  owner: `delivered+bw-pointat-owner-${rand}@resend.dev`,
  guest: `delivered+bw-pointat-guest-${rand}@resend.dev`,
};

let failed = 0;
const check = (what, ok, more = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${more ? `  (${more})` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const controls = (page) => page.evaluate(() => window.brickworksControls || {});
const state = (page) => page.evaluate(() => window.brickworksState || {});
const together = (page) => page.evaluate(() => window.brickworksTogether || {});
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const percentile = (list, p) => {
  const sorted = list.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  return sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))] : NaN;
};

async function until(test, what, seconds = 120) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await test().catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await wait(300);
  }
}
// As until, read every 15 ms: a time a person waits.
async function soon(test, ms) {
  for (const end = Date.now() + ms; Date.now() < end;) {
    const value = await test().catch(() => null);
    if (value) return Date.now();
    await wait(15);
  }
  return null;
}

async function menu(page, title, words, shown, seconds = 30) {
  for (let n = 0; n < 3; n++) {
    const at = await until(async () => (await controls(page))[`menu_${title}`], `the ${title} menu`, 240);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(2000 + 1500 * n);
    await typeInMenu(page, words);
    await page.waitForTimeout(700);
    await page.keyboard.press("Enter");
    const got = await until(async () => (await controls(page))[shown], shown, seconds).catch(() => null);
    if (got) return got;
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1500);
  }
  return null;
}

// A screenshot's pixels (tools/web/together_flow.mjs decodePng).
function decodePng(buffer) {
  let at = 8;
  let w = 0, h = 0, channels = 0;
  const idat = [];
  while (at < buffer.length) {
    const length = buffer.readUInt32BE(at);
    const type = buffer.toString("ascii", at + 4, at + 8);
    const body = buffer.subarray(at + 8, at + 8 + length);
    if (type === "IHDR") {
      w = body.readUInt32BE(0);
      h = body.readUInt32BE(4);
      channels = { 2: 3, 6: 4 }[body[9]];
    } else if (type === "IDAT") idat.push(body);
    at += 12 + length;
  }
  const raw = inflateSync(Buffer.concat(idat));
  const stride = w * channels;
  const data = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= channels ? data[y * stride + x - channels] : 0;
      const b = y > 0 ? data[(y - 1) * stride + x] : 0;
      const c = x >= channels && y > 0 ? data[(y - 1) * stride + x - channels] : 0;
      let v = line[x];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : (pb <= pc ? b : c);
      }
      data[y * stride + x] = v & 255;
    }
  }
  return { width: w, height: h, channels, data };
}
// The pixels of the whole picture within [slack] of "#rrggbb".
function pixelsOf(picture, hex, slack = 28) {
  const want = [1, 3, 5].map((n) => parseInt(hex.slice(n, n + 2), 16));
  let count = 0;
  for (let i = 0; i < picture.data.length; i += picture.channels) {
    if (want.every((v, n) => Math.abs(picture.data[i + n] - v) <= slack)) count += 1;
  }
  return count;
}
const colourCount = async (page, hex, name) => {
  const buffer = await page.screenshot({ timeout: 90000 });
  if (name) writeFileSync(path.join(out, name), buffer);
  return pixelsOf(decodePng(buffer), hex);
};

// The owner's Claude, signed in as claude.ai does it (together_flow.mjs).
async function claudeToken(who) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${site}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${who.token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "pointat", resource: `${site}/api/mcp` }),
  })).json().catch(() => ({}));
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) return "";
  const tokens = await (await fetch(`${site}/oauth/token`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back, client_id: client,
      code_verifier: verifier, resource: `${site}/api/mcp` }).toString(),
  })).json().catch(() => ({}));
  return tokens.access_token || "";
}
let mcpSent = 0;
async function mcp(token, session, method, params) {
  const answer = await fetch(`${site}/api/mcp`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json", accept: "application/json, text/event-stream",
      authorization: `Bearer ${token}`, ...(session ? { "mcp-session-id": session } : {}) },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++mcpSent, method, params }),
  });
  const raw = await answer.text();
  let body = {};
  try { body = JSON.parse(raw); } catch {
    const data = raw.split("\n").filter((line) => line.startsWith("data:")).map((line) => line.slice(5)).pop();
    try { body = JSON.parse(data || "{}"); } catch {}
  }
  return [answer.status, body, answer.headers.get("mcp-session-id") || ""];
}

const browser = await launch({ signedOut: true });
async function person(email) {
  const context = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers });
  const session = await mintSession(email, { age: true });
  await context.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(session.kept)]);
  const page = await context.newPage();
  page.on("pageerror", (e) => console.log(`        [page error] ${String(e).slice(0, 160)}`));
  return { context, page, token: session.access_token, email };
}

// The points a tab shows: [{who, name, colour, parts, left}], its own as "me".
const looks = async (page) => (await together(page)).looks || [];
const theirs = (list, who) => list.find((one) => one.who === who);

try {
  const owner = await person(emails.owner);
  const guest = await person(emails.guest);
  if (bypass) {
    await owner.page.goto(`${site}/app?x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`,
      { waitUntil: "domcontentloaded", timeout: 180000 }).catch(() => {});
  }
  console.log(`\n0. a room of two tabs, ${width} x ${height}`);
  // The owner's Claude connected first: the tab then listens by itself.
  const claude = await claudeToken(owner);
  check("the owner's Claude signs in with OAuth", claude.startsWith("bwa_"));
  await owner.page.goto(`${site}/app?model=res://models/car.ldr&assistant=on`,
    { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await controls(owner.page)).model_name, "the app", 300);
  await until(async () => {
    const now = await state(owner.page);
    return now.bricks > 0 && now.awaited === 0;
  }, "the car whole", 180);
  const panel = await menu(owner.page, "file", "Build tog", "together_start");
  check("File, Build together… opens its panel", Boolean(panel));
  if (!panel) throw new Error("no Build together in the File menu");
  await clickStill(owner.page, "together_start", { seconds: 60, after: 400 });
  const started = await until(async () => {
    const now = await together(owner.page);
    return now.live && now.link ? now : null;
  }, "the session's link", 60);
  check("Start a session gives a link", Boolean(started.link), started.link);
  // Grown by the session, the panel stays inside the window: its Close ran
  // off the foot of a 720-pixel one, and the panel stayed over the view.
  const grown = (await controls(owner.page)).together_close;
  check(`...the panel, grown by it, keeps Close inside the window (${grown ? `${Math.round(grown.x)}, ${Math.round(grown.y)}` : "none"})`,
    Boolean(grown) && grown.y > 0 && grown.y < height && grown.x > 0 && grown.x < width);
  await clickStill(owner.page, "together_close", { seconds: 20, after: 400 }).catch(() => {});
  const shut = await soon(async () => !(await controls(owner.page)).together_close, 5000);
  check("...and Close puts it away", Boolean(shut));
  await guest.page.goto(started.link, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => {
    const asked = (await controls(guest.page)).replace_discard;
    if (asked) await guest.page.mouse.click(asked.x, asked.y);
    const now = await together(guest.page);
    return now.live && (await state(guest.page)).awaited === 0 ? now : null;
  }, "the second tab in the session by the link", 300);
  const both = await until(async () => {
    const now = await together(guest.page);
    return (now.people || []).length === 2 && (now.people || []).every((one) => one.here) ? now : null;
  }, "both here", 60);
  const ownerSaid = both.people.find((one) => one.owner);
  const ownerWho = ownerSaid.who;
  const ownerName = ownerSaid.name;
  const ownerColour = both.colours[ownerWho];
  check(`both in the room: ${both.people.map((one) => one.name).join(", ")}`, Boolean(ownerWho && ownerColour),
    `the owner's colour ${ownerColour}`);
  // The second tab's own view of the model: it closes its panel, and its
  // keys go to the app.
  await clickStill(guest.page, "together_close", { seconds: 20, after: 400 }).catch(() => {});
  const view = (await controls(guest.page)).view;
  if (view) await guest.page.mouse.move(view.x, view.y);

  const laid = ((await askApp(owner.page, "Layout", { seconds: 30 })) || {}).targets || [];
  check(`the owner's tab names parts to point at (${laid.length})`, laid.length >= 2);
  if (laid.length < 2) throw new Error("no parts to point at");

  // Each page's own times (Together.timing, unix ms, the box's one clock;
  // people_said is the server's), once the page has published them.
  const timesOf = (page, ready) => until(async () => {
    const now = (await together(page)).timing || {};
    return ready(now) ? now : null;
  }, "the page's times", 5).catch(() => ({}));
  const after0 = (value, t0) => (Number.isFinite(value) && value >= t0 ? value - t0 : null);
  // The bar on the pages' own time, as together_flow holds the pointer under
  // load: within 500 ms in all, or with its trip (the owner's page handling
  // the key to the second page having the line: the send, the server, the
  // network both ways) within 500 ms less a frame on each side. What each
  // page spent on this box's software drawing, the owner's before it handled
  // the key and the second's drawing it, is said, not counted.
  const FRAME_MS = 17;
  const tripWithin = (total, trip) => Number.isFinite(total) && (total <= BAR_MS
    || (Number.isFinite(trip) && trip <= BAR_MS - 2 * FRAME_MS));

  console.log(`\n1. Alt+W over a part, ${ROUNDS} times: seen in the second tab within ${BAR_MS} ms`);
  const rows = [];
  let last = null;
  let firstPicture = null;
  for (let n = 0; n < ROUNDS; n++) {
    const spots = laid.filter((one) => one.brick !== last);
    const aim = spots[n % spots.length];
    last = aim.brick;
    await owner.page.mouse.move(aim.x, aim.y, { steps: 2 });
    await wait(700);
    const was = theirs(await looks(guest.page), ownerWho)?.n;
    const wasOwn = theirs(await looks(owner.page), "me")?.n;
    if (n === 0) firstPicture = await colourCount(guest.page, ownerColour, "1_before.png");
    const t0 = Date.now();
    await owner.page.keyboard.press("Alt+w");
    const own = await soon(async () => {
      const mine = theirs(await looks(owner.page), "me");
      return mine && mine.n !== wasOwn;
    }, 3000);
    const got = await soon(async () => {
      const mine = theirs(await looks(guest.page), ownerWho);
      return mine && mine.n !== was;
    }, 5000);
    const seen = theirs(await looks(guest.page), ownerWho);
    const sender = await timesOf(owner.page, (now) => now.looked >= t0 && now.look_drawn >= now.looked);
    const timing = got ? await timesOf(guest.page, (now) => now.look_shown >= t0 && now.look_drawn >= now.look_shown) : {};
    rows.push({ n, t0, part: aim.part,
      looked: after0(sender.looked, t0), sent: after0(sender.look_sent, t0),
      own: after0(sender.look_drawn, t0) ?? (own ? own - t0 : null),
      said: Number.isFinite(timing.people_said) ? timing.people_said - t0 : null,
      heard: after0(timing.people_heard, t0), drawn: after0(timing.look_drawn, t0),
      seen: got ? got - t0 : null, name: seen?.name, parts: seen?.parts });
    if (n === 0) {
      const during = await colourCount(guest.page, ownerColour, "1_pointed_guest.png");
      await shot(owner.page, "1_pointed_owner.png");
      rows[0].pixels = { before: firstPicture, during };
    }
    await wait(500);
  }
  writeFileSync(path.join(out, "rounds.json"), JSON.stringify(rows, null, 1));
  for (const row of rows) {
    console.log(`        ${String(row.n).padStart(2)} ${row.part}: key handled ${row.looked}, sent ${row.sent},`
      + ` own drawn ${row.own}; server said ${row.said}, heard ${row.heard}, drawn ${row.drawn},`
      + ` read ${row.seen} ms; "${row.name}"`);
  }
  const p = percentile;
  const of = (key) => rows.map((row) => row[key]).filter((x) => Number.isFinite(x));
  const spread = (list) => `p50 ${p(list, 0.5)}, p95 ${p(list, 0.95)}`;
  const total = (row) => row.drawn ?? row.seen;
  const trip = (row) => row.heard - row.looked;
  const owns = of("own");
  const ownWithin = rows.filter((row) => tripWithin(row.own, row.own - row.looked)).length;
  check(`the owner's own tab draws each at once: ${owns.length} of ${ROUNDS}, ${spread(owns)} ms;`
    + ` ${ownWithin} within ${BAR_MS} ms, or a frame after its page handled the key`
    + ` (key handled ${spread(of("looked"))} ms)`,
    owns.length === ROUNDS && (p(owns, 0.95) <= BAR_MS || ownWithin >= Math.ceil(0.95 * ROUNDS)));
  const drawn = rows.map(total).filter((x) => Number.isFinite(x));
  const trips = rows.map(trip).filter((x) => Number.isFinite(x));
  const within = rows.filter((row) => tripWithin(total(row), trip(row))).length;
  console.log(`        where the time went (p50, p95 ms): the owner's page handling the key ${spread(of("looked"))};`
    + ` the trip ${spread(trips)} (to the server saying it ${spread(rows.map((row) => row.said - row.looked)
      .filter((x) => Number.isFinite(x)))}, from there to the page having it ${spread(rows.map((row) => row.heard - row.said)
      .filter((x) => Number.isFinite(x)))}); the second page drawing it ${spread(rows.map((row) => row.drawn - row.heard)
      .filter((x) => Number.isFinite(x)))}`);
  check(`the second tab draws each: ${drawn.length} of ${ROUNDS}, ${spread(drawn)} ms, most ${Math.max(...drawn)} ms;`
    + ` ${within} of ${ROUNDS} within ${BAR_MS} ms, or their trip within it less a frame each side`
    + ` (trip ${spread(trips)} ms, load ${loadavg()[0].toFixed(0)})`,
    drawn.length === ROUNDS && (p(drawn, 0.95) <= BAR_MS || within >= Math.ceil(0.95 * ROUNDS)));
  check(`...each by the owner's name ("${ownerName}")`, rows.every((row) => row.name === ownerName));

  console.log("\n2. read off the second tab's pixels");
  const px = rows[0].pixels || {};
  check(`the owner's colour ${ownerColour}: ${px.during} pixels with it pointed out, ${px.before} before`,
    px.during >= px.before + 150, "an outline and a name's worth more");

  console.log("\n3. gone 5 s after");
  // One alone, with the pointer where it stays: the last round's gone first,
  // so the pixels after are read against the same pointer and no point.
  await owner.page.mouse.move(laid[0].x, laid[0].y, { steps: 2 });
  await soon(async () => !theirs(await looks(guest.page), ownerWho)
    && !(await looks(owner.page)).some((one) => one.who === "me"), 8000);
  await wait(700);
  const base = await colourCount(guest.page, ownerColour, "3_before_guest.png");
  const lastAt = Date.now();
  await owner.page.keyboard.press("Alt+w");
  await soon(async () => theirs(await looks(guest.page), ownerWho), 5000);
  await soon(async () => Date.now() - lastAt >= 4500, 6000);
  const stillGuest = Boolean(theirs(await looks(guest.page), ownerWho));
  const stillOwner = (await looks(owner.page)).some((one) => one.who === "me");
  check("still shown 4.5 s after, on both tabs", stillGuest && stillOwner);
  const goneGuest = await soon(async () => !theirs(await looks(guest.page), ownerWho), 2500);
  const goneOwner = await soon(async () => !(await looks(owner.page)).some((one) => one.who === "me"), 2500);
  check(`gone after 5 s: the second tab at ${goneGuest ? goneGuest - lastAt : "never"} ms,`
    + ` the owner's at ${goneOwner ? goneOwner - lastAt : "never"} ms (from its Alt+W, by 5.7 s)`,
    goneGuest && goneOwner && goneGuest - lastAt <= 5700 && goneOwner - lastAt <= 5700);
  await wait(300);
  const after = await colourCount(guest.page, ownerColour, "3_gone_guest.png");
  check(`...and off the second tab's pixels: ${after} of the owner's colour (${base} before it, the pointer's)`,
    after <= base + 60);

  console.log("\n4. Esc in the owner's tab takes it back from both");
  await owner.page.keyboard.press("Alt+w");
  await soon(async () => theirs(await looks(guest.page), ownerWho), 5000);
  await wait(300);
  const t1 = Date.now();
  await owner.page.keyboard.press("Escape");
  const ownGone = await soon(async () => !(await looks(owner.page)).some((one) => one.who === "me"), 3000);
  const guestGone = await soon(async () => !theirs(await looks(guest.page), ownerWho), 3000);
  const taken = await timesOf(owner.page, (now) => now.look_taken >= t1);
  const dropped = await timesOf(guest.page, (now) => now.look_gone >= t1);
  const takeTrip = dropped.people_heard - taken.look_taken;
  check(`Esc: gone in the owner's tab at ${ownGone ? ownGone - t1 : "never"} ms, in the second at`
    + ` ${guestGone ? guestGone - t1 : "never"} ms (its trip ${Number.isFinite(takeTrip) ? takeTrip : "-"} ms;`
    + ` bar ${BAR_MS})`,
    ownGone && guestGone && tripWithin(guestGone - t1, takeTrip));

  console.log("\n5. Esc in the second tab puts it away there alone");
  await owner.page.keyboard.press("Alt+w");
  await soon(async () => theirs(await looks(guest.page), ownerWho), 5000);
  await guest.page.keyboard.press("Escape");
  const putAway = await soon(async () => !theirs(await looks(guest.page), ownerWho), 1500);
  const ownerKeeps = (await looks(owner.page)).some((one) => one.who === "me");
  check("Esc in the second tab: gone there, still shown in the owner's", Boolean(putAway) && ownerKeeps);
  await owner.page.keyboard.press("Escape");
  await wait(1000);

  console.log("\n6. the owner's Claude points in one call");
  const listening = await until(() => owner.page.evaluate(() => window.brickworksConnector || ""),
    "the owner's connector", 180).catch(() => null);
  check("the owner's tab listens for Claude", Boolean(listening));
  const [, , mcpSession] = await mcp(claude, "", "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "pointat_flow", version: "1" } });
  const target = laid[laid.length - 1];
  const sentBefore = mcpSent;
  const t2 = Date.now();
  const called = await mcp(claude, mcpSession, "tools/call", { name: "point_at", arguments: { part: target.brick } });
  const answered = Date.now();
  const words = (called[1].result?.content || []).filter((b) => b.type === "text").map((b) => b.text).join(" ");
  console.log(`        point_at: ${called[0]} ${words.slice(0, 200)}`);
  const shownAt = await soon(async () => {
    const mine = theirs(await looks(guest.page), ownerWho);
    return mine && mine.name === `${ownerName}'s Claude`;
  }, 5000);
  // The chat's first answer leads with how to work here; the point's words
  // follow it.
  const pointed = words.indexOf(`Pointed out part ${target.brick}`);
  check(`point_at in ${mcpSent - sentBefore} call: "${words.slice(Math.max(pointed, 0), Math.max(pointed, 0) + 90)}…"`,
    called[0] === 200 && mcpSent - sentBefore === 1 && pointed >= 0);
  check(`...shown in the second tab as "${ownerName}'s Claude" ${shownAt ? shownAt - answered : "never"} ms after`
    + ` the answer (${shownAt ? shownAt - t2 : "-"} ms after the call)`, Boolean(shownAt) && shownAt - answered <= BAR_MS);
  await shot(guest.page, "6_claude_guest.png");
  await shot(owner.page, "6_claude_owner.png");
} catch (trouble) {
  check(`the flow ran to its end: ${String(trouble?.message || trouble).split("\n")[0]}`, false);
} finally {
  await browser.close().catch(() => {});
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
console.log(failed === 0 ? "\npointat_flow: all ok" : `\npointat_flow: ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
