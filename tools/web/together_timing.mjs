// Where the time of a change goes in Build together, as the model grows
// richer: a measure, not a check (tools/release/preview_checks.sh marks it
// local only).
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9011 --static=build/web --hold=together_sessions,together_ops,together_people &
//   node tools/web/together_timing.mjs --url=http://127.0.0.1:9011 --out=DIR [--rounds=12]
//
// Two browsers in one session on the car. First a baseline: --rounds paints
// of one part, each side in turn. Then each of the seven kinds of change
// the flow makes (the name, the floor, a printed part, a build step, a
// booklet look, a motion, the hidden parts coloured), one at a time, each
// followed by the same paints. For every paint, where its time went, from
// the app's own clocks (Together.timing) on one machine:
//
//   pickup   the edit asked of the page to the change queued (the sender's frame)
//   send     queued to sent (waiting for the request before it)
//   number   sent to numbered (the server's append, and back)
//   reach    sent to the other side's poll answering with it
//   apply    the poll's answer to the change put down (the receiver's take)
//   shown    put down to the page saying so (the receiver's next frame)
//
// and the worst frame, capture and read of the model's own state on each
// side meanwhile. Medians, a line a kind.
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:9011").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/together_timing"));
mkdirSync(out, { recursive: true });
const rounds = Number(args.rounds || 12);
const only = String(args.only || "");
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const emails = [`delivered+bw-tt-owner-${rand}@resend.dev`, `delivered+bw-tt-guest-${rand}@resend.dev`,
  `delivered+bwttdesk${rand}@resend.dev`];
// Then what the flow has besides, one at a time on the rich model (--extras):
// Ctrl+Z with the pointer left on the model, twice the parts, the desktop
// copy, the owner's assistant with Claude connected, the guest under 13.
const extras = String(args.extras || "").split(",").filter(Boolean);
let desktop = null;
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const controls = (page) => page.evaluate(() => window.brickworksControls || {});
const state = (page) => page.evaluate(() => window.brickworksState || {});
const together = (page) => page.evaluate(() => window.brickworksTogether || {});

async function until(test, what, seconds = 120) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await test().catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await wait(100);
  }
}
async function press(page, name) {
  const at = await until(async () => (await controls(page))[name], name, 60);
  await page.waitForTimeout(800);
  const again = (await controls(page))[name] || at;
  await page.mouse.click(again.x, again.y);
}
async function ask(page, asks) {
  await page.evaluate((a) => { window.brickworksTogetherDone = undefined; window.brickworksTogetherAsk = a; }, asks);
  return until(() => page.evaluate(() => window.brickworksTogetherDone), "the page's answer", 240);
}
const textOf = async (page) => (await ask(page, [{ text: true }]))[0];
async function tool(page, name, argsGiven) {
  let words = (await ask(page, [{ op: "tool", name, arguments: argsGiven }]))[0]?.words || "";
  const job = /Started job (\d+)/.exec(words);
  for (let n = 0; job && n < 30; n++) {
    words = (await ask(page, [{ op: "tool", name: "job", arguments: { id: Number(job[1]), wait_s: 10 } }]))[0]?.words || "";
    if (/ is done/.test(words) || !/^Job \d+/.test(words)) break;
  }
  return words;
}
async function settled(pages) {
  return until(async () => {
    const all = await Promise.all(pages.map(together));
    const top = Math.max(...all.map((one) => one.seq || 0));
    if (!all.every((one) => one.live && one.waiting === 0 && one.seq === top)) return null;
    await wait(800);
    const again = await Promise.all(pages.map(together));
    return again.every((one) => one.seq === top && one.waiting === 0) ? { top } : null;
  }, "nothing on its way", 120).catch(async (trouble) => {
    for (const page of pages) {
      const now = await together(page);
      console.log(`  (${JSON.stringify({ live: now.live, seq: now.seq, waiting: now.waiting, owner: now.owner, ended: now.ended })})`);
    }
    throw trouble;
  });
}
const median = (list) => {
  const sorted = list.filter((n) => Number.isFinite(n)).sort((a, b) => a - b);
  return sorted.length ? sorted[Math.floor(sorted.length / 2)] : NaN;
};

const browser = await launch({ signedOut: true });
async function person(email, { age = true } = {}) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 }, extraHTTPHeaders: headers });
  const session = await mintSession(email, { age });
  await context.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(session.kept)]);
  return { context, page: await context.newPage(), session };
}
// The owner's Claude signed in as claude.ai does it (tabs_flow.mjs).
async function claudeToken(token) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${site}/api/oauth?op=approve`, { method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back, code_challenge: challenge,
      code_challenge_method: "S256", state: "t", resource: `${site}/api/mcp` }) })).json().catch(() => ({}));
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) return "";
  const tokens = await (await fetch(`${site}/oauth/token`, { method: "POST",
    headers: { ...headers, "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back, client_id: client,
      code_verifier: verifier, resource: `${site}/api/mcp` }).toString() })).json().catch(() => ({}));
  return tokens.access_token || "";
}

const rows = [];
try {
  // A guest not asked its age yet, when it is to say under 13 later.
  const [owner, guest] = [await person(emails[0]), await person(emails[1], { age: !extras.includes("under13") })];
  await owner.page.goto(`${site}/app?model=res://models/car.ldr`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await state(owner.page)).bricks > 0 && (await state(owner.page)).awaited === 0, "the car", 300);
  // File, Build together…, Start a session.
  const file = await until(async () => (await controls(owner.page)).menu_file, "the File menu", 120);
  await owner.page.mouse.click(file.x, file.y);
  await owner.page.waitForTimeout(2000);
  await owner.page.keyboard.type("Buildtog", { delay: 110 });
  await owner.page.keyboard.press("Enter");
  await press(owner.page, "together_start");
  const link = (await until(async () => ((await together(owner.page)).link || null), "the link", 60));
  await press(owner.page, "together_close").catch(() => {});
  await guest.page.goto(link, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await together(guest.page)).live, "the guest in", 300);
  await press(guest.page, "together_close").catch(() => {});
  await settled([owner.page, guest.page]);
  const hinges = (await textOf(owner.page)).parts || {};
  const hinge = Object.keys(hinges).find((uid) => /^3938/.test(hinges[uid]));

  // A part of its own for the paints, out of the way.
  const [swatch] = await ask(owner.page, [{ op: "place", part: "3005", colour: 4, x: -2400, y: 48, z: 2400 }]);
  await settled([owner.page, guest.page]);
  let colour = 4;

  async function paints(kind) {
    const stages = { total: [], pickup: [], send: [], number: [], reach: [], apply: [], shown: [] };
    const worst = { owner: {}, guest: {} };
    for (let n = 0; n < rounds; n++) {
      const [from, to] = n % 2 === 0 ? [owner, guest] : [guest, owner];
      const before = (await together(to.page)).seq;
      colour = colour === 4 ? 1 : 4;
      const t0 = Date.now();
      await from.page.evaluate((a) => { window.brickworksTogetherDone = undefined; window.brickworksTogetherAsk = a; },
        [{ op: "paint", uid: swatch.uid, colour }]);
      let seen = null;
      for (const end = Date.now() + 20000; Date.now() < end && !seen;) {
        if ((await together(to.page)).seq > before) seen = Date.now();
        else await wait(15);
      }
      await until(() => from.page.evaluate(() => window.brickworksTogetherDone), "the paint's answer", 30).catch(() => null);
      await wait(400);
      const sender = (await together(from.page)).timing || {};
      const receiver = (await together(to.page)).timing || {};
      const sent = sender.sent || {};
      if (n < 2) console.log(`    sent ${JSON.stringify({ keys: sent.keys, bytes: sent.bytes, ops: sent.ops })}`
        + ` meta put here ${JSON.stringify(receiver.meta_put || {})}`);
      const taken = receiver.taken || {};
      if (seen) stages.total.push(seen - t0);
      stages.pickup.push(sent.queued - t0);
      stages.send.push(sent.sent - sent.queued);
      stages.number.push(sent.answered - sent.sent);
      stages.reach.push(taken.polled - sent.sent);
      stages.apply.push(taken.applied - taken.polled);
      stages.shown.push(seen - taken.applied);
      for (const [who, timing] of [["owner", (await together(owner.page)).timing], ["guest", (await together(guest.page)).timing]]) {
        for (const [what, ms] of Object.entries(timing?.worst || {})) worst[who][what] = Math.max(worst[who][what] || 0, ms);
      }
    }
    const row = { kind, ...Object.fromEntries(Object.entries(stages).map(([k, v]) => [k, median(v)])),
      p95: [...stages.total].sort((a, b) => a - b)[Math.floor(0.95 * stages.total.length)] ?? NaN, worst };
    rows.push(row);
    console.log(`${kind.padEnd(14)} total ${row.total} (p95 ${row.p95})  pickup ${row.pickup}  send ${row.send}  number ${row.number}`
      + `  reach ${row.reach}  apply ${row.apply}  shown ${row.shown}  | owner worst ${JSON.stringify(worst.owner)}`
      + `  guest worst ${JSON.stringify(worst.guest)}`);
  }

  const kinds = [
    ["name", async () => ask(guest.page, [{ op: "title", title: "Timing Cottage" }])],
    ["floor", async () => tool(owner.page, "set_floor", { kind: "baseplate", across: 32, colour: 2 })],
    ["print", async () => {
      const [printed] = await ask(guest.page, [{ op: "place", part: "3004", colour: 15, x: 1200, y: 48, z: 1200 }]);
      return tool(guest.page, "print_part", { brick: `uid:${printed.uid}`,
        svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 24"><rect width="40" height="24" fill="#ffd500"/></svg>' });
    }],
    ["steps", async () => tool(guest.page, "edit_steps", { op: "new", bricks: [`uid:${swatch.uid}`] })],
    ["looks", async () => tool(owner.page, "edit_booklet", { step: 1, zoom: 1.5 })],
    ["motion", async () => tool(guest.page, "define_motion", { name: "Open the door",
      tracks: [{ joint: `#uid:${hinge}`, keys: [{ t: 0, place: 0 }, { t: 1, place: 45 }] }] })],
    ["hidden", async () => tool(owner.page, "colour_hidden_parts", { mode: "stages", stages: 2, apply: true, agreed: true })],
  ];
  await paints("baseline");
  for (const [kind, make] of kinds) {
    if (only && !only.split(",").includes(kind)) continue;
    const said = String(await make() || "").split("\n")[0].slice(0, 100);
    console.log(`  ${kind}: ${said}`);
    await settled([owner.page, guest.page]);
    await paints(`after ${kind}`);
  }
  const extra = {
    undo: async () => {
      await owner.page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
      const layout = await until(() => owner.page.evaluate(() => window.brickworksLayout || null), "layout", 30);
      const aim = (layout.targets || [])[0];
      if (aim) await owner.page.mouse.move(aim.x, aim.y, { steps: 3 });
      await owner.page.keyboard.press("Control+z");
      return `pointer on ${aim ? "a part" : "nothing"}, Ctrl+Z`;
    },
    parts: async () => {
      const many = [];
      for (let n = 0; n < 80; n++) many.push({ op: "place", part: "3001", colour: [1, 4, 14][n % 3], x: 2000 + 80 * (n % 10), y: 48 + 24 * Math.floor(n / 10), z: -2000 });
      await ask(owner.page, many);
      return `${(await textOf(owner.page)).uids.length} parts`;
    },
    desktop: async () => {
      const file = path.join(out, "desktop.json");
      desktop = spawn("godot", ["--headless", "--path", path.resolve("."), "--script", "src/dev/together_probe.gd", "--",
        `--api=${site}`, `--join=${link}`, `--out=${file}`, "--edits=0", `--email=${emails[2]}`, "--seconds=900"],
      { env: { ...process.env, XDG_DATA_HOME: process.env.TOGETHER_XDG || path.join(out, "desktop-data") }, stdio: "ignore" });
      await until(async () => (existsSync(file) && JSON.parse(readFileSync(file, "utf8")).live) || null, "the desktop in", 300);
      return "the desktop joined";
    },
    assistant: async () => {
      const claude = await claudeToken(owner.session.access_token);
      await owner.page.goto(`${site}/app?assistant=on`, { waitUntil: "domcontentloaded", timeout: 180000 });
      await until(async () => (await together(owner.page)).live, "the owner back in", 300);
      const listening = await until(() => owner.page.evaluate(() => window.brickworksConnector || ""), "the connector", 180)
        .catch(() => "");
      return `Claude ${claude ? "connected" : "not connected"}, connector ${listening ? "listening" : "not listening"}`;
    },
    under13: async () => {
      await answerAge(guest.session.kept.user_id, emails[1], false);
      return "the guest said under 13";
    },
  };
  for (const name of extras) {
    const said = await extra[name]();
    console.log(`  + ${name}: ${said}`);
    await settled([owner.page, guest.page]);
    await paints(`+ ${name}`);
  }
} catch (trouble) {
  console.log(`stopped: ${String(trouble.message || trouble).split("\n")[0]}`);
} finally {
  writeFileSync(path.join(out, "timing.json"), JSON.stringify(rows, null, 1));
  await browser.close().catch(() => {});
  if (desktop) desktop.kill();
  for (const email of emails) await deleteAccount(email).catch(() => {});
}
