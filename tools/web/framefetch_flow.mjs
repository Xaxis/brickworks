// How long a web page's send waits between being asked for and leaving the
// page, on each path the app sends by, while each of its frames takes long.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 10101 --static=build/web --arrivals \
//     --hold=together_sessions,together_ops,together_people,together_snapshot_parts &
//   node tools/web/framefetch_flow.mjs --url=http://127.0.0.1:10101 --out=DIR
//
// The page says when each send was asked (PageFetch.asked, unix ms, in
// window.brickworksAsked) and the server when each arrived (relay_server
// --arrivals), on this box's one clock; the difference is the wait. Every
// frame of the app is made --busy ms longer (250), as a phone's or a
// software-drawn frame is: the work runs in the app's own frame, after it.
// A send that leaves when asked arrives within a few ms whatever the frame
// costs; one held to the frame's end waits the frame out, and one held to a
// later frame waits a frame and more.
//
//   1. Together: a session of one tab; parts placed and chat lines said,
//      each sent (op=send).
//   2. The relay: the tab's Claude (OAuth, as claude.ai signs in) calls the
//      gallery tool, which asks the site (/api/people) as the tool runs, and
//      the tab answers the relay (op=answer) and asks it for the next call
//      (op=next).
//
// Bar: each path's p95 wait under --busy / 2 ms, every send arrived. And
// the time each call took as Claude saw it, said.
//
// Red on a build whose sends wait for their frame, or in a browser that
// holds them (a Playwright route holds every request of the page until the
// page's task ends: tools/web/page_routes.mjs). Exit 1 on any failure.
import { clickStill, launch, typeInMenu } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import { loadavg } from "node:os";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:10101").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/framefetch"));
mkdirSync(out, { recursive: true });
const BUSY = Number(args.busy || 250);
const ROUNDS = Number(args.rounds || 8);
const BAR = BUSY / 2;
const rand = randomBytes(4).toString("hex");
const email = `delivered+bw-framefetch-${rand}@resend.dev`;

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

// The tab's Claude, signed in as claude.ai does it (pointat_flow.mjs).
async function claudeToken(token) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${site}/api/oauth?op=approve`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "framefetch", resource: `${site}/api/mcp` }),
  })).json().catch(() => ({}));
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) return "";
  const tokens = await (await fetch(`${site}/oauth/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back, client_id: client,
      code_verifier: verifier, resource: `${site}/api/mcp` }).toString(),
  })).json().catch(() => ({}));
  return tokens.access_token || "";
}
let mcpSent = 0;
async function mcp(token, session, method, params) {
  const answer = await fetch(`${site}/api/mcp`, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json, text/event-stream",
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

// The sends the page asked for since [from] matched to the server's
// arrivals: [{key, asked, left}], left null for one that never arrived.
async function waits(page, from, keep) {
  const asked = (await page.evaluate(() => window.brickworksAsked || [])).filter((one) => one.at >= from);
  const arrived = await (await fetch(`${site}/__arrived?since=${from - 1000}`)).json();
  const taken = new Set();
  const rows = [];
  for (const one of asked) {
    const url = new URL(one.url, site);
    const key = `${url.pathname}${url.search}`;
    if (!keep(url)) continue;
    const index = arrived.findIndex((got, n) => !taken.has(n) && `${got.path}${got.search}` === key && got.at >= one.at - 5);
    if (index >= 0) taken.add(index);
    rows.push({ key, path: url.pathname, op: url.searchParams.get("op") || "", asked: one.at,
      left: index >= 0 ? arrived[index].at - one.at : null });
  }
  return rows;
}
function judge(label, rows) {
  const left = rows.map((row) => row.left);
  const came = left.filter((x) => Number.isFinite(x));
  console.log(`        ${label}: ${left.map((x) => (x === null ? "never" : x)).join(" ")} ms`);
  return check(`${label}: ${came.length} of ${rows.length} arrived, waited p50 ${percentile(came, 0.5)} ms,`
    + ` p95 ${percentile(came, 0.95)} ms, most ${came.length ? Math.max(...came) : NaN} ms;`
    + ` bar p95 under ${BAR} ms with every frame ${BUSY} ms longer`,
  rows.length > 0 && came.length === rows.length && percentile(came, 0.95) < BAR);
}

const browser = await launch({ signedOut: true });
const results = { busy: BUSY, load: loadavg()[0] };
try {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const session = await mintSession(email, { age: true });
  await context.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(session.kept)]);
  // Every frame of the app made longer by the page's own work after it,
  // in the same task, as drawing in software makes it: the app's frame is
  // the callback it gives requestAnimationFrame.
  await context.addInitScript(() => {
    window.brickworksBusy = 0;
    const asked = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (frame) => asked((time) => {
      frame(time);
      const until = performance.now() + window.brickworksBusy;
      while (performance.now() < until) { /* the frame's drawing */ }
    });
  });
  const page = await context.newPage();
  page.on("pageerror", (e) => console.log(`        [page error] ${String(e).slice(0, 160)}`));
  const claude = await claudeToken(session.access_token);
  check("the tab's Claude signs in with OAuth", claude.startsWith("bwa_"));
  await page.goto(`${site}/app?model=res://models/car.ldr&assistant=on`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await controls(page)).model_name, "the app", 300);
  await until(async () => {
    const now = await state(page);
    return now.bricks > 0 && now.awaited === 0;
  }, "the car whole", 180);

  console.log(`\n1. Together: sends asked in a frame ${BUSY} ms longer`);
  const panel = await menu(page, "file", "Build tog", "together_start");
  if (!panel) throw new Error("no Build together in the File menu");
  await clickStill(page, "together_start", { seconds: 60, after: 400 });
  await until(async () => {
    const now = await together(page);
    return now.live && now.link ? now : null;
  }, "the session's link", 60);
  await clickStill(page, "together_close", { seconds: 20, after: 400 }).catch(() => {});
  await wait(1000);
  await page.evaluate((busy) => { window.brickworksBusy = busy; }, BUSY);
  const from1 = Date.now();
  for (let n = 0; n < ROUNDS; n++) {
    const ask = n % 2 ? { op: "chat", text: `framefetch ${n}` } : { op: "place", part: "3001", colour: 4, x: 40 * n, y: 0, z: 400 };
    await page.evaluate((a) => { window.brickworksTogetherDone = undefined; window.brickworksTogetherAsk = [a]; }, ask);
    await until(() => page.evaluate(() => window.brickworksTogetherDone), "the edit done", 60);
    await until(async () => (await together(page)).waiting === 0, "the send answered", 60);
    await wait(300);
  }
  const sends = await waits(page, from1, (url) => url.searchParams.get("op") === "send");
  results.together = sends;
  judge("Together's sends (op=send)", sends);
  await page.evaluate(() => { window.brickworksBusy = 0; });

  console.log(`\n2. the relay: Claude's calls, each frame ${BUSY} ms longer`);
  await until(() => page.evaluate(() => window.brickworksConnector || ""), "the tab's connector", 180);
  const [, , mcpSession] = await mcp(claude, "", "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "framefetch_flow", version: "1" } });
  await mcp(claude, mcpSession, "tools/list", {});
  await wait(1500);
  await page.evaluate((busy) => { window.brickworksBusy = busy; }, BUSY);
  await wait(1000);
  const from2 = Date.now();
  const calls = [];
  for (let n = 0; n < ROUNDS; n++) {
    const t0 = Date.now();
    const called = await mcp(claude, mcpSession, "tools/call", { name: "gallery", arguments: { designer: `framefetch${n}` } });
    calls.push(Date.now() - t0);
    if (n === 0) {
      const words = (called[1].result?.content || []).filter((b) => b.type === "text").map((b) => b.text).join(" ");
      console.log(`        gallery: ${called[0]} ${words.slice(0, 120)}`);
    }
    await wait(500);
  }
  await wait(1500);
  const relay = await waits(page, from2, (url) => url.pathname === "/api/mcp" || url.pathname === "/api/people");
  results.relay = relay;
  results.calls = calls;
  judge("the tool's own ask of the site (gallery, /api/people)", relay.filter((row) => row.path === "/api/people"));
  judge("the tab's answers to the relay (op=answer)", relay.filter((row) => row.path === "/api/mcp" && row.op === "answer"));
  judge("the tab's asks for the next call (op=next)", relay.filter((row) => row.path === "/api/mcp" && row.op === "next"));
  console.log(`        each call as Claude saw it: ${calls.join(" ")} ms (p50 ${percentile(calls, 0.5)})`);
  await page.evaluate(() => { window.brickworksBusy = 0; });
} catch (trouble) {
  check(`the flow ran to the end: ${String(trouble.message || trouble).split("\n")[0]}`, false);
} finally {
  writeFileSync(path.join(out, "waits.json"), JSON.stringify(results, null, 1));
  await browser.close().catch(() => {});
  await deleteAccount(email).catch(() => {});
}
console.log(`\nframefetch_flow: ${failed ? `${failed} FAILED` : "all ok"} (load ${loadavg()[0].toFixed(0)})`);
process.exit(failed ? 1 : 0);
