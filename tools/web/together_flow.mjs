// Building together, in real browsers and the desktop app at once: two
// people build one model live, each in their own copy of the app.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9011 --static=build/web --hold=together_sessions,together_ops,together_people &
//   node tools/web/together_flow.mjs --url=http://127.0.0.1:9011 --out=shots/together
//   BW_BYPASS=… node tools/web/together_flow.mjs --url=<a preview> --out=DIR     once together.sql is applied
//   ... --desktop=no                                                              without the desktop's half
//
// Two browser contexts, each a person with their own account (throwaway
// ones at Resend's test addresses, deleted at the end); the second is under
// 13, who builds together like anyone and is never shown by name:
//
//   1. The owner opens the car, and File, Build together… (the menu typed
//      to, as a person does), and presses Start a session: a link.
//   2. The second person opens the link, signed in: they join, and have the
//      car byte for byte; each sees who is in it ("Builder 2", never an
//      email). The desktop app joins the same session too
//      (src/dev/together_probe.gd --join), and makes edits of its own.
//   3. 50 random edits from the two browsers, interleaved, as the keys make
//      them (Together.check_edit: place, move, paint, delete, undo), some on
//      the same part at the same moment; then, once nothing is on its way,
//      the model is byte-identical in both browsers and the desktop.
//   4. Per-person undo, by the key: the owner puts a part down, the other
//      paints another; the owner's Ctrl+Z takes back the owner's part and
//      leaves the paint, on both sides.
//   5. How long a change takes to reach the other browser: p50 and p95 over
//      20 changes each way, from the edit to the other page having it.
//   6. A third account, not invited: a made-up link is refused in its page,
//      and the session refuses it outright (api/together.js 403).
//   7. The owner ends it, from the panel: the other browser and the desktop
//      are told, and keep what was built; the owner's model is as it was.
//
// Red on a build without it: there is no Build together… in the File menu.
// Pictures in --out. Exit 1 on any failure.
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:9011").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/together"));
mkdirSync(out, { recursive: true });
const bypass = args.bypass || process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const withDesktop = String(args.desktop || "yes") !== "no";
const EDITS = Number(args.edits || 50);
const rand = randomBytes(4).toString("hex");
const emails = {
  owner: `delivered+bw-together-owner-${rand}@resend.dev`,
  guest: `delivered+bw-together-guest-${rand}@resend.dev`,
  stranger: `delivered+bw-together-stranger-${rand}@resend.dev`,
  desktop: `delivered+bwtogetherd${rand}@resend.dev`,
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

async function until(test, what, seconds = 120) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await test().catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await wait(300);
  }
}

async function press(page, name, seconds = 60) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    let at = (await controls(page))[name];
    for (let n = 0; at && n < 6; n += 1) {
      await page.waitForTimeout(550);
      const again = (await controls(page))[name];
      if (again && again.x === at.x && again.y === at.y) break;
      at = again;
    }
    if (at) {
      await page.mouse.click(at.x, at.y);
      await page.waitForTimeout(400);
      return at;
    }
    if (Date.now() > end) throw new Error(`no ${name} on the page`);
    await page.waitForTimeout(500);
  }
}

// File, then the item's first words typed, then Enter: the menu as a
// person drives it from the keyboard (floor_flow.mjs).
async function menu(page, title, words, shown, seconds = 30) {
  for (let n = 0; n < 3; n++) {
    const at = await until(async () => (await controls(page))[`menu_${title}`], `the ${title} menu`, 240);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(2000 + 1500 * n);
    // Typed without its spaces: a space in a menu presses the row it is on.
    await page.keyboard.type(words.replace(/ /g, ""), { delay: 110 });
    await page.waitForTimeout(700);
    if (n === 0) await shot(page, `menu_${title}_${words.replace(/\W+/g, "_")}.png`);
    await page.keyboard.press("Enter");
    const got = await until(async () => (await controls(page))[shown], shown, seconds).catch(() => null);
    if (got) return got;
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1500);
  }
  return null;
}

// Edits through the app's own builder, and the model's file, asked of the
// page (Together._tell_page).
async function ask(page, asks) {
  await page.evaluate((a) => { window.brickworksTogetherDone = undefined; window.brickworksTogetherAsk = a; }, asks);
  return until(() => page.evaluate(() => window.brickworksTogetherDone), "the page's answer", 180);
}
const textOf = async (page) => (await ask(page, [{ text: true }]))[0];


// The owner's Claude, signed in to their account as claude.ai does it
// (tabs_flow.mjs): its published identity, PKCE, the person's yes with their
// session, the code traded.
async function claudeToken(who) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${site}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${who.token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "together", resource: `${site}/api/mcp` }),
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
// One MCP request as Claude makes it: [status, body, the session id handed out].
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
async function person(email, { under13 = false } = {}) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 }, extraHTTPHeaders: headers });
  const session = await mintSession(email, { age: !under13 });
  if (under13) await answerAge(session.kept.user_id, email, false);
  await context.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(session.kept)]);
  const page = await context.newPage();
  page.on("pageerror", (e) => console.log(`        [page error] ${String(e).slice(0, 160)}`));
  return { context, page, token: session.access_token, email, kept: session.kept };
}
async function opened(who, query) {
  await who.page.goto(`${site}/app?${query}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await controls(who.page)).model_name, "the app", 300);
  await until(async () => {
    const now = await state(who.page);
    return now.bricks > 0 && now.awaited === 0;
  }, "the model whole", 180);
}
async function settled(pages, desktopFile = null, seconds = 60) {
  return until(async () => {
    const all = await Promise.all(pages.map(together));
    const top = Math.max(...all.map((one) => one.seq || 0));
    if (!all.every((one) => one.live && one.waiting === 0 && one.seq === top)) return null;
    if (desktopFile) {
      const desk = readDesktop(desktopFile);
      if (!desk || desk.seq !== top || desk.waiting !== 0) return null;
    }
    // Twice, a moment apart, so nothing was numbered meanwhile.
    await wait(1200);
    const again = await Promise.all(pages.map(together));
    return again.every((one) => one.seq === top && one.waiting === 0) ? top : null;
  }, "nothing on its way", seconds);
}
// Both files and the lines that differ, for a check that found them apart.
function dumpTexts(what, mine, theirs) {
  const name = what.replace(/\W+/g, "_").slice(0, 40);
  writeFileSync(path.join(out, `${name}_owner.ldr`), mine);
  writeFileSync(path.join(out, `${name}_guest.ldr`), theirs);
  const a = mine.split("\n");
  const b = theirs.split("\n");
  const differ = [];
  for (let n = 0; n < Math.max(a.length, b.length) && differ.length < 6; n++) {
    if (a[n] !== b[n]) differ.push(`        line ${n + 1}: ${String(a[n]).slice(0, 90)} | ${String(b[n]).slice(0, 90)}`);
  }
  console.log(differ.join("\n"));
}
// How long a change takes to reach the other browser: [rounds] paints of a
// part of its own, each side in turn, a colour that is always a change, from
// the moment it is asked of one page to the frame the other page has it,
// read every 20 ms: what a person waits, frames and all.
// The network's share of a change's wait in the rich measure's bar: the
// plain measure's under-a-second, less the frames.
const NETWORK_MS = 500;
async function measure(label, rounds, relative = false) {
  const { owner, guest } = people;
  const times = { "owner to guest": [], "guest to owner": [] };
  // Where each change's time went (Together.timing, both pages' clocks), and
  // the longest the page's thread was held between two frames in the second
  // after it: a frame that draws the whole model, in software, is that long.
  const stages = { pickup: [], number: [], reach: [], apply: [], shown: [], held_sender: [], held_receiver: [] };
  const each = [];
  for (const who of [owner, guest]) {
    await who.page.evaluate(() => {
      if (window.__frameTimes) return;
      window.__frameTimes = [];
      const tick = (t) => {
        window.__frameTimes.push(t);
        if (window.__frameTimes.length > 600) window.__frameTimes.splice(0, 300);
        requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    });
  }
  const heldSince = (page, since) => page.evaluate((from) => {
    const t = window.__frameTimes.filter((x) => x >= from);
    let most = 0;
    for (let n = 1; n < t.length; n++) most = Math.max(most, t[n] - t[n - 1]);
    return Math.round(most);
  }, since);
  const [swatch] = await ask(owner.page, [{ op: "place", part: "3005", colour: 4, x: -2400, y: 48, z: 2400 + 80 * rounds }]);
  await settled([owner.page, guest.page]);
  for (let n = 0; n < rounds; n++) {
    const [from, to, way] = n % 2 === 0 ? [owner, guest, "owner to guest"] : [guest, owner, "guest to owner"];
    const before = (await together(to.page)).seq;
    await from.page.evaluate(() => { window.brickworksTogetherDone = undefined; });
    const t0 = Date.now();
    const [fromSince, toSince] = await Promise.all([from.page.evaluate(() => performance.now()),
      to.page.evaluate(() => performance.now())]);
    await from.page.evaluate((a) => { window.brickworksTogetherAsk = a; },
      [{ op: "paint", uid: swatch.uid, colour: n % 2 ? 4 : 1 }]);
    let got = null;
    for (const end = Date.now() + 20000; Date.now() < end && !got;) {
      if ((await together(to.page)).seq > before) got = Date.now();
      else await wait(20);
    }
    if (got) times[way].push(got - t0);
    if (got) each.push({ total: got - t0, from: from === owner ? "owner" : "guest", to: to === owner ? "owner" : "guest" });
    await until(() => from.page.evaluate(() => window.brickworksTogetherDone), "the edit's answer", 20).catch(() => null);
    await wait(300);
    const sent = (await together(from.page)).timing?.sent || {};
    const taken = (await together(to.page)).timing?.taken || {};
    stages.pickup.push(sent.queued - t0);
    stages.number.push(sent.answered - sent.sent);
    stages.reach.push(taken.polled - sent.sent);
    stages.apply.push(taken.applied - taken.polled);
    stages.shown.push(got - taken.applied);
    stages.held_sender.push(await heldSince(from.page, fromSince));
    stages.held_receiver.push(await heldSince(to.page, toSince));
  }
  const mid = (list) => {
    const sorted = list.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
    return sorted.length ? sorted[Math.floor(sorted.length / 2)] : NaN;
  };
  console.log(`        stages (median ms): ${Object.entries(stages).map(([k, v]) => `${k} ${mid(v)}`).join(", ")}`);
  // Each page's own frame: the median hold after a turn of the view alone.
  const frame = {};
  for (const [name, who] of [["owner", owner], ["guest", guest]]) {
    const timing = (await together(who.page)).timing || {};
    // And the same hold after nothing but the view turning (Shift+Q): the
    // model drawn again, no change made and nothing sent. As long, and the
    // time is the drawing's.
    const turns = [];
    const view = (await controls(who.page)).view;
    if (view) await who.page.mouse.move(view.x, view.y + 60);
    for (let n = 0; n < 3; n++) {
      const since = await who.page.evaluate(() => performance.now());
      await who.page.keyboard.press("Shift+KeyQ");
      await wait(1500);
      turns.push(await heldSince(who.page, since));
    }
    console.log(`        ${name}: worst ${JSON.stringify(timing.worst || {})}, last autosave ${timing.autosave_ms} ms;`
      + ` held after a turn of the view alone ${turns.join(", ")} ms`);
    frame[name] = mid(turns);
  }
  const all = [...times["owner to guest"], ...times["guest to owner"]].sort((x, y) => x - y);
  const pct = (list, p) => list[Math.min(list.length - 1, Math.floor(p * list.length))];
  // The plain measure: p95 under a second. The rich one, relative to the
  // pages' own drawing (a real graphics card draws the rich car in a
  // fraction of a software frame): each change within the network's
  // budget, plus one of the sender's frames (the edit picked up) and three
  // of the receiver's (the frame it lands in, the one it is drawn in, and
  // the one the page is told in), for 95 of every 100.
  const p95 = pct(all, 0.95);
  const within = each.filter((one) => one.total <= NETWORK_MS + frame[one.from] + 3 * frame[one.to]).length;
  const relativeOk = each.length > 0 && within >= Math.ceil(0.95 * each.length);
  const verdict = relative ? `; frames ${frame.owner} ms (owner), ${frame.guest} ms (other); ${within} of ${each.length}`
    + ` within ${NETWORK_MS} ms + the sender's frame + 3 of the receiver's` : "";
  // How many frames a second each page drew meanwhile: a change is seen at
  // the frame after it arrives, and a browser drawing in software on a
  // loaded box draws few.
  const fps = await Promise.all([owner, guest].map((who) => who.page.evaluate(() => new Promise((done) => {
    let frames = 0;
    const from = performance.now();
    const tick = () => {
      frames += 1;
      if (performance.now() - from < 3000) requestAnimationFrame(tick);
      else done(Math.round(10 * frames / ((performance.now() - from) / 1000)) / 10);
    };
    requestAnimationFrame(tick);
  }))));
  console.log(`        frames a second meanwhile: the owner's page ${fps[0]}, the other's ${fps[1]}`);
  return check(`${label}: ${all.length} changes arrived, p50 ${pct(all, 0.5)} ms, p95 ${p95} ms${verdict}`,
    all.length >= rounds * 0.9 && (relative ? p95 < 1000 || relativeOk : p95 < 1000),
    Object.entries(times).map(([k, v]) => `${k} p50 ${pct([...v].sort((x, y) => x - y), 0.5)}`).join(", "));
}
function readDesktop(file) {
  try { return existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null; } catch { return null; }
}

let desktop = null;
let claude = "";
const desktopFile = path.join(out, "desktop.json");
const people = {};
try {
  people.owner = await person(emails.owner);
  people.guest = await person(emails.guest, { under13: true });
  const { owner, guest } = people;
  if (bypass) {
    await owner.page.goto(`${site}/app?x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`,
      { waitUntil: "domcontentloaded", timeout: 180000 }).catch(() => {});
  }

  console.log("\n1. the owner starts a session");
  // The owner's Claude connected first, as a person connects it before
  // asking it to build: their tab then listens by itself when it opens.
  claude = await claudeToken(owner);
  check("the owner's Claude signs in with OAuth", claude.startsWith("bwa_"));
  // The car, the app's own first model: its doors move.
  await opened(owner, "model=res://models/car.ldr&assistant=on");
  const panel = await menu(owner.page, "file", "Build tog", "together_start");
  check("File, Build together… opens its panel", Boolean(panel));
  if (!panel) throw new Error("no Build together in the File menu");
  await shot(owner.page, "1_panel.png");
  await press(owner.page, "together_start");
  const started = await until(async () => {
    const now = await together(owner.page);
    return now.live && now.link ? now : null;
  }, "the session's link", 60);
  check("Start a session gives a link", /\/app\?together=[A-Za-z0-9_-]{32}$/.test(started.link), started.link);
  await until(async () => (await controls(owner.page)).together_copy, "the link in the panel", 20);
  await shot(owner.page, "1_link.png");

  console.log("\n2. the other person joins by the link, and the desktop");
  await guest.page.goto(started.link, { waitUntil: "domcontentloaded", timeout: 180000 });
  const joined = await until(async () => {
    const now = await together(guest.page);
    return now.live ? now : null;
  }, "the second browser in the session", 240);
  check("the link joins the second person (under 13)", joined.live && !joined.owner);
  await until(async () => (await state(guest.page)).awaited === 0, "the car whole there", 120);
  const [a0, b0] = [await textOf(owner.page), await textOf(guest.page)];
  check("both have the car, byte for byte", a0.hash === b0.hash && a0.text.length > 1000,
    `${a0.uids.length} parts, ${a0.text.length} bytes`);
  const names = (await until(async () => {
    const now = await together(owner.page);
    return now.people?.length === 2 ? now.people : null;
  }, "two people in it", 30)).map((one) => one.name);
  check(`each is shown who is in it: ${names.join(", ")}`, names.length === 2
    && !names.some((name) => name.includes("@")) && names.includes("Builder 2"));
  await until(async () => (await controls(guest.page)).together_end, "the guest's panel", 30).catch(() => null);
  await shot(guest.page, "2_joined.png");
  await press(guest.page, "together_close").catch(() => {});
  await press(owner.page, "together_close").catch(() => {});

  if (withDesktop) {
    // Plain godot: the flow holds the box's slot already, and the desktop's
    // half is a headless copy that mostly waits on the network.
    const godotArgs = ["--headless", "--path", root, "--script", "src/dev/together_probe.gd", "--",
      `--api=${site}`, `--join=${started.link}`, `--out=${desktopFile}`, "--edits=6", `--email=${emails.desktop}`,
      "--seconds=900"];
    desktop = spawn("godot", godotArgs, {
      env: { ...process.env, XDG_DATA_HOME: process.env.TOGETHER_XDG || path.join(out, "desktop-data") },
      stdio: ["ignore", "pipe", "pipe"],
    });
    desktop.stdout.on("data", (bytes) => {
      for (const line of String(bytes).split("\n")) if (/ok  |FAIL|together probe/.test(line)) console.log(`        [desktop] ${line.trim()}`);
    });
    const live = await until(async () => readDesktop(desktopFile)?.live, "the desktop in the session", 300).catch(() => null);
    check("the desktop app joins the same session", Boolean(live));
  }

  console.log(`\n3. ${EDITS} edits from both browsers, interleaved`);
  const sides = [owner, guest];
  let made = 0;
  let together_moves = 0;
  // The car's hinge kept out of the random edits: a motion is made on it below.
  const carParts = (await textOf(owner.page)).parts || {};
  const hinges = new Set(Object.keys(carParts).filter((uid) => /^393[78]/.test(carParts[uid])));
  const uidsOf = async (page) => (await textOf(page)).uids.filter((uid) => !hinges.has(uid));
  let known = await uidsOf(owner.page);
  for (let n = 0; n < EDITS; n++) {
    if (n % 10 === 0) known = await uidsOf(sides[n % 2].page);
    const pick = () => known[Math.floor(Math.random() * known.length)];
    const roll = Math.random();
    let edits;
    if (n % 9 === 4) {
      // The same part, both at once.
      const uid = pick();
      const [x, y] = await Promise.all([
        ask(owner.page, [{ op: "move", uid, by: [0, 6 + 2 * n, 0] }]),
        ask(guest.page, [{ op: "move", uid, by: [0, 8 + 2 * n, 0] }]),
      ]);
      if (x[0]?.ok && y[0]?.ok) together_moves += 1;
      made += (x[0]?.ok ? 1 : 0) + (y[0]?.ok ? 1 : 0);
      continue;
    }
    if (roll < 0.3) {
      edits = [{ op: "place", part: ["3001", "3003", "3004", "3010"][n % 4], colour: [1, 2, 4, 14, 15][n % 5],
        x: 600 + 80 * Math.floor(Math.random() * 20), y: 48 + 24 * Math.floor(Math.random() * 6),
        z: 600 + 80 * Math.floor(Math.random() * 20) }];
    } else if (roll < 0.6) {
      edits = [{ op: "move", uid: pick(), by: [10 * Math.floor(Math.random() * 7 - 3), 12 * (1 + Math.floor(Math.random() * 3)),
        10 * Math.floor(Math.random() * 7 - 3)] }];
    } else if (roll < 0.8) {
      edits = [{ op: "paint", uid: pick(), colour: [1, 2, 4, 14, 15, 0][Math.floor(Math.random() * 6)] }];
    } else if (roll < 0.9) {
      edits = [{ op: "delete", uid: pick() }];
    } else {
      edits = [{ op: "undo" }];
    }
    const [done] = await ask(sides[n % 2].page, edits);
    if (done?.ok) made += 1;
    if (done?.uid) known.push(done.uid);
    await wait(Math.floor(Math.random() * 250));
  }
  const top = await settled([owner.page, guest.page], withDesktop ? desktopFile : null, 90).catch(() => null);
  check(`${made} edits made (${together_moves} times the same part moved by both at once); all numbered`, Boolean(top) && made >= EDITS * 0.6,
    `seq ${top}`);
  const [a1, b1] = [await textOf(owner.page), await textOf(guest.page)];
  if (a1.hash !== b1.hash) dumpTexts("after the edits", a1.text, b1.text);
  check("the model is byte-identical in both browsers", a1.hash === b1.hash, `${a1.uids.length} parts, ${a1.text.length} bytes`);
  if (withDesktop) {
    const desk = readDesktop(desktopFile);
    check(`...and in the desktop app (${desk?.made ?? 0} edits of its own)`, desk?.hash === a1.hash, `seq ${desk?.seq}`);
  }
  await shot(owner.page, "3_owner.png");
  await shot(guest.page, "3_guest.png");
  await measure("how long a change takes to reach the other browser", 40);


  console.log("\n3b. what the model is besides its parts, each kind from either side");
  // Each through the app's own code: the name typed into its field, the rest
  // through the tools Claude calls (Together.check_edit "tool").
  const sameEverywhere = async (what) => {
    const top = await settled([owner.page, guest.page], withDesktop ? desktopFile : null, 90).catch(() => null);
    const [a, b] = [await textOf(owner.page), await textOf(guest.page)];
    let desk = withDesktop ? readDesktop(desktopFile) : null;
    if (a.hash !== b.hash) dumpTexts(what, a.text, b.text);
    // The desktop's file is written twice a second: read again for up to 5 s
    // before it is called apart, and then shown how.
    for (let n = 0; withDesktop && desk?.hash !== a.hash && n < 10; n++) {
      await wait(500);
      desk = readDesktop(desktopFile);
    }
    if (withDesktop && desk?.hash !== a.hash) {
      const deskText = existsSync(`${desktopFile}.ldr`) ? readFileSync(`${desktopFile}.ldr`, "utf8") : "";
      console.log(`        the desktop at seq ${desk?.seq}, the owner's at ${top}:`);
      dumpTexts(`${what}_desktop`, a.text, deskText);
    }
    if (desk?.healed) console.log(`        (the desktop put back ${desk.healed} parts so far: ${(desk.healed_last || []).join(", ")})`);
    return check(`${what}: byte-identical in both browsers${withDesktop ? " and the desktop" : ""}`,
      Boolean(top) && a.hash === b.hash && (!withDesktop || desk?.hash === a.hash),
      `seq ${top}, ${a.text.length} bytes`);
  };
  // A tool's answer; one that became a job (a long one) waited on until done.
  const tool = async (page, name, args) => {
    let words = (await ask(page, [{ op: "tool", name, arguments: args }]))[0]?.words || "";
    const job = /Started job (\d+)/.exec(words);
    for (let n = 0; job && n < 30; n++) {
      words = (await ask(page, [{ op: "tool", name: "job", arguments: { id: Number(job[1]), wait_s: 10 } }]))[0]?.words || "";
      if (/ is done/.test(words) || !/^Job \d+/.test(words)) break;
    }
    return words;
  };
  // The name, typed by the second person as a person types it.
  const field = await until(async () => (await controls(guest.page)).model_name, "the name field", 60);
  await guest.page.mouse.click(field.x, field.y);
  await guest.page.keyboard.press("Control+A");
  await guest.page.keyboard.type("Together Cottage", { delay: 40 });
  await guest.page.keyboard.press("Enter");
  await guest.page.keyboard.press("Escape");
  await sameEverywhere("the model's name typed by the second person");
  check("...and the owner's tab is called it", (await textOf(owner.page)).text.includes("Together Cottage"));
  const floorSaid = await tool(owner.page, "set_floor", { kind: "baseplate", across: 32, colour: 2 });
  console.log(`        set_floor: ${floorSaid.split("\n")[0].slice(0, 120)}`);
  await sameEverywhere("the floor chosen by the owner");
  // A part made in the app: a print on a brick of the second person's own,
  // a part of its own from then on, which the other side has to be sent.
  const [printed] = await ask(guest.page, [{ op: "place", part: "3004", colour: 15, x: 1200, y: 48, z: 1200 }]);
  const printSaid = await tool(guest.page, "print_part", { brick: `uid:${printed?.uid}`,
    svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 24"><rect width="40" height="24" fill="#ffd500"/>'
      + '<circle cx="20" cy="12" r="8" fill="#d01012"/></svg>' });
  console.log(`        print_part: ${printSaid.split("\n")[0].slice(0, 140)}`);
  await sameEverywhere("a part printed by the second person, made in the app");
  const someUid = (await textOf(guest.page)).uids[3];
  const stepSaid = await tool(guest.page, "edit_steps", { op: "new", bricks: [`uid:${someUid}`] });
  console.log(`        edit_steps: ${stepSaid.split("\n")[0].slice(0, 120)}`);
  await sameEverywhere("a build step made by the second person");
  const lookSaid = await tool(owner.page, "edit_booklet", { step: 1, zoom: 1.5 });
  console.log(`        edit_booklet: ${lookSaid.split("\n")[0].slice(0, 120)}`);
  await sameEverywhere("the booklet's look of a step, set by the owner");
  // A motion: the car's door swung open, kept by the second person.
  const partsNow = (await textOf(guest.page)).parts || {};
  const hinge = Object.keys(partsNow).find((uid) => /^3938/.test(partsNow[uid]));
  const motionSaid = await tool(guest.page, "define_motion", { name: "Open the door",
    tracks: [{ joint: `#uid:${hinge}`, keys: [{ t: 0, place: 0 }, { t: 1, place: 45 }] }] });
  console.log(`        define_motion: ${motionSaid.split("\n")[0].slice(0, 140)}`);
  await sameEverywhere("a motion kept by the second person");
  check("...and the owner's file has it", (await textOf(owner.page)).text.includes("Open the door"));
  const hiddenSaid = await tool(owner.page, "colour_hidden_parts", { mode: "stages", stages: 2, apply: true, agreed: true });
  console.log(`        colour_hidden_parts: ${hiddenSaid.split("\n")[0].slice(0, 160)}`);
  await sameEverywhere("the hidden parts coloured by the owner");

  console.log("\n4. each undo is its own");
  const [placed] = await ask(owner.page, [{ op: "place", part: "3001", colour: 4, x: -1200, y: 96, z: -1200 }]);
  await settled([owner.page, guest.page]);
  const target = (await uidsOf(guest.page)).find((uid) => uid !== placed.uid);
  const [painted] = await ask(guest.page, [{ op: "paint", uid: target, colour: 14 }]);
  await settled([owner.page, guest.page]);
  // The owner's own key, in the owner's page.
  const view = (await controls(owner.page)).view;
  if (view) await owner.page.mouse.move(view.x, view.y + 40);
  await owner.page.keyboard.press("Control+z");
  await settled([owner.page, guest.page]);
  const [a2, b2] = [await textOf(owner.page), await textOf(guest.page)];
  check("the owner's Ctrl+Z takes back the owner's part, on both sides", placed?.ok && !a2.uids.includes(placed.uid)
    && !b2.uids.includes(placed.uid));
  const paintSeen = (text) => text.includes(" 14 ") ;
  check("...and leaves the other's paint, on both", painted?.ok && paintSeen(a2.text) && a2.hash === b2.hash);

  console.log("\n5. how long a change takes to reach the other browser, now");
  await measure("again, with a motion, a print, steps and the hidden colours", 20, true);

  console.log("\n5b. a reload, and a lost connection, go back in by themselves");
  await guest.page.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  for (let n = 0; n < 3; n++) {
    await ask(owner.page, [{ op: "place", part: "3003", colour: 14, x: -1600 + 80 * n, y: 48, z: 1200 }]);
  }
  const back = await until(async () => (await together(guest.page)).live, "the second browser back in", 300).catch(() => null);
  check("the reloaded browser went back into the session by itself", Boolean(back));
  await sameEverywhere("what the owner did while it was reloading");
  await guest.context.setOffline(true);
  for (let n = 0; n < 3; n++) {
    await ask(guest.page, [{ op: "place", part: "3001", colour: 1, x: 1600, y: 48 + 24 * n, z: -1600 + 80 * n }]);
    await ask(owner.page, [{ op: "place", part: "3001", colour: 4, x: -1600, y: 48 + 24 * n, z: -1600 + 80 * n }]);
  }
  await wait(8000);
  const offlineSeq = (await together(guest.page)).seq;
  await guest.context.setOffline(false);
  check("offline, the second browser held its changes", (await together(guest.page)).waiting >= 1, `seq ${offlineSeq}`);
  await sameEverywhere("both sides' changes made while the second was offline");

  console.log("\n5c. where each person is working, shown in the others' view");
  await owner.page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
  const layout = await until(() => owner.page.evaluate(() => window.brickworksLayout || null), "the owner's layout", 30);
  let seen = null;
  for (const aim of (layout.targets || []).slice(0, 6)) {
    await owner.page.mouse.move(aim.x, aim.y, { steps: 4 });
    seen = await until(async () => {
      const now = await together(guest.page);
      const them = (now.people || []).find((one) => one.owner);
      return them?.at && now.pointers >= 1 ? them : null;
    }, "the owner's pointer in the second browser", 8).catch(() => null);
    if (seen) break;
  }
  check("the owner's pointer is drawn in the second browser's view, with their name", Boolean(seen),
    seen ? `${seen.name} at ${seen.at.join(", ")}` : "");
  await shot(guest.page, "5c_pointer.png");

  console.log("\n5d. a short chat");
  const chatPanel = await menu(owner.page, "file", "Build tog", "together_chat_field");
  check("the owner's panel has a chat", Boolean(chatPanel));
  if (chatPanel) {
    await owner.page.mouse.click(chatPanel.x, chatPanel.y);
    await owner.page.keyboard.type("Roof next?", { delay: 40 });
    await owner.page.keyboard.press("Enter");
  }
  const said = await until(async () => ((await together(owner.page)).messages || []).find((m) => m.text === "Roof next?"),
    "the owner's line numbered", 20).catch(() => null);
  check("the owner's line is in the chat", Boolean(said));
  await shot(owner.page, "5d_chat.png");
  if (withDesktop) {
    const heard = await until(async () => (readDesktop(desktopFile)?.messages || []).includes("The owner: Roof next?"),
      "the desktop hearing it", 20).catch(() => null);
    check("the desktop app (13 or over) hears it", Boolean(heard));
  }
  const kid = await together(guest.page);
  check("the second person, under 13, is not shown the chat, and is told why",
    !(kid.messages || []).some((m) => m.text === "Roof next?") && /13/.test(kid.chat_words || ""), kid.chat_words);
  const [kidSays] = await ask(guest.page, [{ op: "chat", text: "hi" }]);
  check("...and cannot say anything in it", !kidSays.ok && /13/.test(kidSays.words || ""), kidSays.words);
  await press(owner.page, "together_close").catch(() => {});

  console.log("\n5e. Claude in the owner's tab, building for both");
  const listening = await until(() => owner.page.evaluate(() => window.brickworksConnector || ""), "the owner's connector", 180)
    .catch(() => null);
  check("the owner's tab listens for Claude", Boolean(listening));
  const before5e = (await state(guest.page)).bricks;
  const [, , mcpSession] = await mcp(claude, "", "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "together_flow", version: "1" } });
  const edited = await mcp(claude, mcpSession, "tools/call", { name: "edit_model",
    arguments: { add: [{ part: "3003", color: 1, x: 30, y: 0, z: 30, rot: 0 }] } });
  const words = (edited[1].result?.content || []).filter((b) => b.type === "text").map((b) => b.text).join(" ");
  console.log(`        edit_model: ${edited[0]} ${words.slice(0, 160)}`);
  const grew = await until(async () => (await state(guest.page)).bricks === before5e + 1, "Claude's part in the second browser", 60)
    .catch(() => null);
  check("a real MCP edit by the owner's Claude shows in the other person's browser", Boolean(grew),
    `${(await state(guest.page)).bricks} parts, was ${before5e}`);
  await sameEverywhere("Claude's edit");

  console.log("\n6. an account not invited");
  people.stranger = await person(emails.stranger);
  await people.stranger.page.goto(`${site}/app?together=${"Z".repeat(32)}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await controls(people.stranger.page)).model_name, "the stranger's app", 300);
  await wait(6000);
  check("a made-up link joins nobody", !(await together(people.stranger.page)).live);
  const secret = started.link.split("together=")[1];
  const refused = await fetch(`${site}/api/together?op=poll`, { method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${people.stranger.token}` },
    body: JSON.stringify({ s: secret, after: 0 }) });
  check("the session refuses an account that never joined it", refused.status === 403, `${refused.status}`);
  await shot(people.stranger.page, "6_stranger.png");

  console.log("\n7. the owner ends it");
  const before = await textOf(owner.page);
  const reopened = await menu(owner.page, "file", "Build tog", "together_end");
  check("the panel shows the session", Boolean(reopened));
  await shot(owner.page, "7_panel.png");
  await press(owner.page, "together_end");
  const told = await until(async () => {
    const now = await together(guest.page);
    return !now.live && now.ended ? now : null;
  }, "the guest told", 40).catch(() => null);
  check("the other browser is told, and keeps what was built", Boolean(told)
    && (await state(guest.page)).bricks === (await state(owner.page)).bricks, told?.ended);
  const after = await textOf(owner.page);
  check("the owner's model is as it was, and theirs", !(await together(owner.page)).live && after.hash === before.hash);
  if (withDesktop) {
    const desk = await until(async () => {
      const now = readDesktop(desktopFile);
      return now && now.live === false ? now : null;
    }, "the desktop told", 60).catch(() => null);
    check("the desktop is told too, and has the same model", Boolean(desk) && desk.hash === before.hash, desk?.ended);
  }
  await shot(guest.page, "7_guest.png");
} catch (trouble) {
  check(`the flow ran to the end: ${String(trouble.message || trouble).split("\n")[0]}`, false);
  for (const [name, who] of Object.entries(people)) await shot(who.page, `stopped_${name}.png`);
} finally {
  if (desktop) {
    await until(async () => desktop.exitCode !== null, "the desktop to finish", 60).catch(() => desktop.kill());
  }
  await browser.close().catch(() => {});
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
console.log(failed ? `\ntogether_flow: ${failed} FAILED` : "\ntogether_flow: all ok");
process.exit(failed ? 1 : 0);
