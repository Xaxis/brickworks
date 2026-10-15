// Is the model in Claude interactive, in a real MCP Apps host? End to end.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/app_host_check.mjs --url=<a preview>/app \
//     --host=<basic-host dir> --out=shots/app_host [--sizes] [--port=18680]
//
// The host is the MCP Apps reference host, ext-apps' examples/basic-host
// (github.com/modelcontextprotocol/ext-apps), built in a directory of its
// own (--host: its dist/ and node_modules, untouched), and run as it runs:
// serve.ts, the host page on --port and its sandbox on the next, the view
// in a sandboxed frame inside a frame of another origin, under the content
// policy built from what the resource declares. Its sandbox address is
// fixed at localhost:8081 in its build, so the browser is pointed from
// there to this check's port.
//
// Between the host and the deployed relay stands what claude.ai's own
// servers are: an MCP connection signed in with OAuth to a throwaway
// account (deleted at the end), whose tab is open in the same browser,
// answering. Three such connections, each a kind of host:
//
//   1. strips   says it shows pages, then hands the page the result with
//               no _meta at all (a host that forwards only content)
//   2. plain    never says it shows pages, as most of claude.ai's sessions
//               do not, and refuses the page any tool its model was not
//               listed (a strict host): the page reads brickworks://viewer/…
//   3. passes   says it, and hands the result on whole
//
// In each the page must draw the model in 3D (WebGL pixels drawn, and as
// many parts as the tab has), and in the first everything else: it turns
// when dragged, Check calls through and tints, the instructions step, a
// part clicked is told to the host as model context and selected in the
// tab, full screen is asked for and given, the parts list and its BrickLink
// list, Open in Brickworks. --sizes measures a 400- and a 4,000-part model.
//
// Before 2026-10-15 the page drew four pictures and asked for nothing:
// against main every check from "the page draws the model in 3D" on fails.
import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import http from "node:http";
import { join } from "node:path";

const email = `delivered+bwapphost${Date.now().toString(36)}@resend.dev`;
process.env.BW_TEST_EMAIL = email;
const { launch, openColumnFor, withAssistant } = await import("./browser.mjs");
const { mintSession } = await import("./session.mjs");

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = withAssistant(args.url || "https://brickworks.diy/app");
const site = new URL(url).origin;
const hostDir = String(args.host || "");
const out = args.out || "shots/app_host";
const port = Number(args.port || 18680);
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const extra = bypass ? { "x-vercel-protection-bypass": bypass } : {};
const withBypass = (address) => (bypass
  ? `${address}${address.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : address);
const EXTENSION = "io.modelcontextprotocol/ui";
const MIME = "text/html;profile=mcp-app";
const URI = "ui://brickworks/model.html";

let failures = 0;
const results = [];
const check = (ok, what) => {
  const line = `  ${ok ? "ok  " : "FAIL"}  ${what}`;
  console.log(line);
  results.push(line);
  if (!ok) failures += 1;
  return ok;
};
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

async function dropAccount(id) {
  if (!id) return false;
  const secret = process.env.SUPABASE_SECRET_KEY;
  const gone = await fetch(`${process.env.SUPABASE_URL.replace(/\/+$/, "")}/auth/v1/admin/users/${id}`, {
    method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` } });
  return gone.ok;
}

// Claude's sign-in to the account, as claude.ai does it (model_view_check).
async function claudeToken(session) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = b64url(randomBytes(32));
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${site}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${session}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "ah", resource: `${site}/api/mcp` }),
  })).json();
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) throw new Error(`no code: ${JSON.stringify(yes).slice(0, 200)}`);
  const tokens = await (await fetch(`${site}/oauth/token`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back,
      client_id: client, code_verifier: verifier, resource: `${site}/api/mcp` }).toString(),
  })).json();
  if (!tokens.access_token) throw new Error("no token");
  return tokens.access_token;
}

function parseAnswer(raw, type) {
  if (String(type || "").startsWith("text/event-stream")) {
    return raw.split(/\r?\n\r?\n/).map((event) => event.split(/\r?\n/).filter((l) => l.startsWith("data:"))
      .map((l) => l.slice(5).trim()).join("\n")).filter(Boolean).map((d) => JSON.parse(d));
  }
  try { return [JSON.parse(raw)]; } catch { return []; }
}

// Claude, talking to the relay straight: to build the model, and as the
// client that does not show pages, whose list must be what it always was.
class Conversation {
  constructor(token, shows) { this.token = token; this.shows = shows; this.session = ""; this.sent = 0; }
  async ask(method, params = {}) {
    this.sent += 1;
    const answer = await fetch(`${site}/api/mcp`, {
      method: "POST",
      headers: { ...extra, "content-type": "application/json", accept: "application/json, text/event-stream",
        authorization: `Bearer ${this.token}`, ...(this.session ? { "mcp-session-id": this.session } : {}) },
      body: JSON.stringify({ jsonrpc: "2.0", id: this.sent, method, params }),
    });
    const given = answer.headers.get("mcp-session-id");
    if (given && !this.session) this.session = given;
    const messages = parseAnswer(await answer.text(), answer.headers.get("content-type"));
    return messages.find((m) => m.id === this.sent) || { error: { message: `status ${answer.status}` } };
  }
  async start() {
    const capabilities = this.shows ? { extensions: { [EXTENSION]: { mimeTypes: [MIME] } } } : {};
    return this.ask("initialize", { protocolVersion: "2025-06-18", capabilities,
      clientInfo: { name: "app-host-check", version: "1" } });
  }
  call(name, input = {}) { return this.ask("tools/call", { name, arguments: input }); }
}
const texts = (answer) => ((answer.result || {}).content || []).filter((b) => b.type === "text").map((b) => b.text);

// What claude.ai's servers are to the host: the MCP connection, signed in.
// [mode]: strips, plain or passes, as the head of this file says. Every
// request and answer kept, for the checks to read.
function connection(mode, listen, token) {
  const seen = [];
  const listed = new Set();
  const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "*",
    "access-control-allow-methods": "GET, POST, DELETE, OPTIONS", "access-control-expose-headers": "mcp-session-id" };
  const server = http.createServer(async (request, response) => {
    if (request.method === "OPTIONS") { response.writeHead(204, cors).end(); return; }
    if (request.method !== "POST") { response.writeHead(405, { ...cors, allow: "POST" }).end(); return; }
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    let message = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
    if (message.method === "initialize") {
      const capabilities = { ...(message.params?.capabilities || {}) };
      if (mode === "plain") delete capabilities.extensions;
      else capabilities.extensions = { ...(capabilities.extensions || {}), [EXTENSION]: { mimeTypes: [MIME] } };
      message = { ...message, params: { ...message.params, capabilities } };
    }
    const one = { method: message.method, name: message.params?.name, uri: message.params?.uri, at: Date.now() };
    seen.push(one);
    // A strict host: no tool for the page that its model was not listed.
    if (mode === "plain" && message.method === "tools/call" && !listed.has(message.params?.name)) {
      one.refused = true;
      response.writeHead(200, { ...cors, "content-type": "application/json" });
      response.end(JSON.stringify({ jsonrpc: "2.0", id: message.id, error: { code: -32602, message: `no tool ${message.params?.name} for this app` } }));
      return;
    }
    const answer = await fetch(`${site}/api/mcp`, {
      method: "POST",
      headers: { ...extra, "content-type": "application/json", accept: request.headers.accept || "application/json, text/event-stream",
        authorization: `Bearer ${token}`,
        ...(request.headers["mcp-session-id"] ? { "mcp-session-id": request.headers["mcp-session-id"] } : {}),
        ...(request.headers["mcp-protocol-version"] ? { "mcp-protocol-version": request.headers["mcp-protocol-version"] } : {}) },
      body: JSON.stringify(message),
    });
    const type = answer.headers.get("content-type") || "application/json";
    const session = answer.headers.get("mcp-session-id");
    let raw = await answer.text();
    one.status = answer.status;
    one.chars = raw.length;
    const messages = parseAnswer(raw, type);
    let changed = false;
    for (const m of messages) {
      if (message.method === "tools/list" && m.result) for (const t of m.result.tools || []) listed.add(t.name);
      if (m.id === message.id) one.answer = m;
      if (mode === "strips" && m.result && message.method === "tools/call") { delete m.result._meta; changed = true; }
      // And it takes no notice of the origins the page declares: the page
      // may fetch from nowhere but itself.
      if (mode === "plain" && m.result && message.method === "resources/read") {
        for (const c of m.result.contents || []) delete c._meta;
        changed = true;
      }
      if (mode === "plain" && m.result && message.method === "resources/list") {
        for (const r of m.result.resources || []) delete r._meta;
        changed = true;
      }
    }
    if (changed && messages.length) {
      raw = String(type).startsWith("text/event-stream")
        ? messages.map((m) => `event: message\ndata: ${JSON.stringify(m)}\n\n`).join("") : JSON.stringify(messages[0]);
    }
    response.writeHead(answer.status, { ...cors, "content-type": type, ...(session ? { "mcp-session-id": session } : {}) });
    response.end(raw);
  });
  return new Promise((done) => server.listen(listen, "127.0.0.1", () => done({ server, seen, listed, mode,
    url: `http://localhost:${listen}/mcp` })));
}

let browser = null;
let account = "";
let host = null;
const conns = [];
try {
  if (!hostDir) throw new Error("--host=<basic-host dir>: ext-apps' examples/basic-host, built (dist/) with its node_modules");
  console.log(`the model in Claude, interactive, in basic-host, at ${site}, as ${email}\n`);
  const signedIn = await mintSession(email);
  account = signedIn.kept.user_id;
  const token = await claudeToken(signedIn.access_token);

  console.log("1. a real tab of the account, and a model in it");
  browser = await launch();
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
  await context.route(/^https:\/\/claude\.ai\//, (route) => route.fulfill({ status: 200, contentType: "text/html",
    body: "<!doctype html><title>claude.ai (stand-in)</title>" }));
  const tab = await context.newPage();
  await tab.goto(withBypass(url), { waitUntil: "domcontentloaded", timeout: 180000 });
  const claudeState = () => tab.evaluate(() => window.brickworksClaude || {});
  let listening = false;
  for (let n = 0; n < 600 && !listening; n++) {
    listening = Boolean((await claudeState()).on);
    if (listening) break;
    const at = (await tab.evaluate(() => window.brickworksControls || {})).connect_claude;
    if (at) {
      const opened = context.waitForEvent("page", { timeout: 30000 }).catch(() => null);
      await tab.mouse.click(at.x, at.y);
      const claude = await opened;
      if (claude) await claude.close();
    } else if (n % 12 === 6) {
      await openColumnFor(tab, "connect_claude");
    }
    await tab.waitForTimeout(500);
  }
  check(listening, `the account's tab is listening for Claude: "${(await claudeState()).status || ""}"`);
  const claude = new Conversation(token, false);
  await claude.start();
  let cleared = await claude.call("clear_model");
  for (let n = 0; n < 12 && /No Brickworks tab is open/.test(texts(cleared).join(" ")); n++) {
    await tab.waitForTimeout(5000);
    cleared = await claude.call("clear_model");
  }
  // A tower in blue and white with an arm held out on one stud (a 1 x 1
  // plate), a weight at its end, and one part turned: something for the
  // check to find (src/dev/viewer_tools_probe.gd builds the same). No red,
  // orange or yellow, so the check's tint is the only warm colour there.
  const design = { name: "Host check crane", bricks: [
    { part: "3001", color: 1, x: 10, y: 0, z: 10 }, { part: "3001", color: 15, x: 10, y: 3, z: 10 },
    { part: "3001", color: 1, x: 10, y: 6, z: 10 }, { part: "3024", color: 72, x: 13, y: 9, z: 10 },
    { part: "3034", color: 72, x: 13, y: 10, z: 10 }, { part: "3001", color: 0, x: 17, y: 11, z: 10 },
    { part: "3001", color: 0, x: 17, y: 14, z: 10 }, { part: "3003", color: 2, x: 17, y: 17, z: 10, rot: 1 },
  ] };
  const built = await claude.call("submit_design", design);
  check(!built.result?.isError && /Built\./.test(texts(built).join(" ")),
    `the model is built in the tab: "${texts(built).join(" ").replace(/\s+/g, " ").slice(0, 90)}"`);
  const stated = Number((/(\d+) parts are on the baseplate/.exec(texts(await claude.call("look_at_model")).join(" ")) || [])[1]);

  console.log("\n2. Claude's tool list, for a client that does not show pages, is what it was");
  const listedPlain = ((await claude.ask("tools/list")).result || {}).tools || [];
  const app = JSON.parse(readFileSync(new URL("../mcp_tools.json", import.meta.url), "utf8")).map((t) => t.name);
  check(listedPlain.length === app.length + 2 && !listedPlain.some((t) => t.name.startsWith("viewer_")),
    `${listedPlain.length} tools: the app's ${app.length}, tabs and select_tab, and none of the viewer's`);
  const carry = listedPlain.filter((t) => t._meta?.ui?.resourceUri === URI).map((t) => t.name);
  check(["submit_design", "look_at_model", "view_model", "edit_model", "open_model", "brickify"].every((n) => carry.includes(n)),
    `the tools that carry the card: ${carry.join(", ")}`);

  console.log("\n3. basic-host, the MCP Apps reference host, with three kinds of connection");
  for (const [k, mode] of ["strips", "plain", "passes"].entries()) conns.push(await connection(mode, port + 2 + k, token));
  host = spawn(process.execPath, [join(hostDir, "serve.ts")], {
    env: { ...process.env, HOST_PORT: String(port), SANDBOX_PORT: String(port + 1),
      SERVERS: JSON.stringify(conns.map((c) => c.url)), NODE_ENV: "production" },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let hostSaid = "";
  host.stdout.on("data", (d) => { hostSaid += d; });
  host.stderr.on("data", (d) => { hostSaid += d; });
  for (let n = 0; n < 60 && !/Sandbox server/.test(hostSaid); n++) await sleep(500);
  check(/Sandbox server/.test(hostSaid), `basic-host serves the host on ${port} and its sandbox on ${port + 1}`);
  // Its build asks for the sandbox at localhost:8081, the other origin.
  await context.route(/^http:\/\/localhost:8081\//, async (route) => {
    const moved = route.request().url().replace("http://localhost:8081/", `http://localhost:${port + 1}/`);
    const answer = await route.fetch({ url: moved });
    await route.fulfill({ response: answer });
  });
  const page = await context.newPage();
  await page.setViewportSize({ width: 1100, height: 1000 });
  const refused = [];
  page.on("console", (m) => { if (/Content Security Policy|Refused to/i.test(m.text())) refused.push(m.text().slice(0, 240)); });
  await page.goto(`http://localhost:${port}/index.html`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector("form select", { timeout: 60000 });
  for (let n = 0; n < 60; n++) {
    if ((await page.locator("form select").first().locator("option").count()) >= 3) break;
    await sleep(500);
  }

  // A tool called from the host's form, as a person would; the card's frame.
  async function callFromHost(index, tool, input = "{}") {
    await page.locator("form select").first().selectOption(String(index));
    await sleep(500);
    await page.locator("form select").nth(1).selectOption(tool);
    await page.locator("form textarea").fill(input);
    const before = page.frames().length;
    await page.locator("form button[type=submit]").click();
    let frame = null;
    for (let n = 0; n < 240 && !frame; n++) {
      await sleep(500);
      for (const f of page.frames().slice(1)) {
        // The card's page, whichever build of it: main's too, to fail on.
        const has = await f.evaluate(() => Boolean(document.getElementById("stage"))).catch(() => false);
        if (has && !(callFromHost.used || []).includes(f)) { frame = f; break; }
      }
    }
    callFromHost.used = [...(callFromHost.used || []), frame];
    return frame;
  }
  const cardOf = (frame) => frame.evaluate(() => {
    const c = window.brickworksCard;
    // Main's page, which draws pictures and has nothing to read.
    if (!c) return { state: "a page with no 3D", called: [], told: [], errors: [], timings: {}, shown: 0, sample: null,
      angle: null, geometry: { files: 0, bytes: 0 }, partsText: (document.getElementById("parts") || {}).textContent };
    return { state: c.state, mode: c.mode, source: c.source, via: c.via, parts: c.parts, bricks: c.bricks,
      called: c.called, told: c.told, errors: c.errors, timings: c.timings, of: c.of, picked: c.picked,
      displayMode: c.displayMode, step: c.step, tinted: c.tinted, lots: c.lots, tab: c.tab, opened: c.opened,
      webgl: c.webgl, partsText: document.getElementById("parts").textContent, shown: c.shown(),
      sample: c.sample(), angle: c.angle(), geometry: c.geometry(), copied: c.copied, downloaded: c.downloaded };
  });
  async function ready(frame, seconds = 180) {
    let now = await cardOf(frame);
    for (let n = 0; n < seconds * 2 && now.state !== "ready"; n++) { await sleep(500); now = await cardOf(frame); }
    return now;
  }
  async function stageBox(frame) {
    const box = await frame.locator("#stage").boundingBox();
    return box;
  }
  const parts = `${stated.toLocaleString()} parts`;

  // ── 1. A host that hands the page no _meta ──
  console.log("\n  a. a host that hands the page the result with no _meta at all");
  const stripping = conns[0];
  let frame = await callFromHost(0, "look_at_model");
  check(Boolean(frame), "basic-host draws the card for look_at_model, a call whose answer is words");
  let now = await ready(frame);
  const answered = stripping.seen.find((s) => s.method === "tools/call" && s.name === "look_at_model");
  check(answered && answered.answer && answered.answer.result && !answered.answer.result.isError,
    "the call is answered through the deployed relay");
  check(now.called.includes("viewer_scene") && now.source === "tools/call",
    `the page asks the tab for the model itself (tools/call viewer_scene): source ${now.source}, asked ${now.called.join(", ")}`);
  check(now.state === "ready" && now.mode === "3d" && now.sample && now.sample.drawn > 0.02 && now.sample.colours >= 4,
    `the page draws the model in 3D: WebGL ${now.sample ? `${now.sample.width}x${now.sample.height}, ${Math.round(now.sample.drawn * 1000) / 10}% of it the model, ${now.sample.colours} colours` : "none"}`);
  check(now.shown === stated && now.partsText === parts,
    `...every part of it: ${now.shown} drawn, "${now.partsText}", as look_at_model states (${stated})`);
  check(now.geometry.files >= 4 && now.errors.length === 0,
    `...in the parts' own geometry, ${now.geometry.files} files fetched (${Math.round(now.geometry.bytes / 1024)} KB), from the origin the page declares${now.errors.length ? `; ${now.errors[0]}` : ""}`);
  await page.screenshot({ path: `${out}/1_drawn.png` });

  // Turned by dragging, once it has stopped turning by itself.
  for (let n = 0; n < 40 && await frame.evaluate(() => window.brickworksCard.turning()); n++) await sleep(500);
  const box = await stageBox(frame);
  const was = (await cardOf(frame)).angle;
  await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.5);
  await page.mouse.down();
  for (let k = 1; k <= 12; k++) await page.mouse.move(box.x + box.width * (0.5 + k * 0.025), box.y + box.height * (0.5 - k * 0.006));
  await page.mouse.up();
  await sleep(900);
  now = await cardOf(frame);
  check(was && now.angle && Math.abs(now.angle.round - was.round) > 0.15,
    `a drag turns it: from ${was ? was.round.toFixed(2) : "?"} to ${now.angle ? now.angle.round.toFixed(2) : "?"} radians round`);
  await page.screenshot({ path: `${out}/2_turned.png` });

  // A part clicked: told to the host, and selected in the tab.
  let point = null;
  for (let gy = 0.3; gy <= 0.75 && !point; gy += 0.05) {
    for (let gx = 0.3; gx <= 0.7 && !point; gx += 0.05) {
      const x = box.width * gx;
      const y = box.height * gy;
      const hit = await frame.evaluate(([px, py]) => {
        const r = document.getElementById("stage").getBoundingClientRect();
        return window.brickworksCard.pickAt(r.left + px, r.top + py);
      }, [x, y]);
      if (hit >= 0) point = { x, y, hit };
    }
  }
  check(Boolean(point), "a point on the stage over a part");
  if (point) {
    await page.mouse.click(box.x + point.x, box.y + point.y);
    await sleep(1500);
    now = await cardOf(frame);
    const told = now.told[now.told.length - 1] || "";
    check(now.picked && /picked brick #\d+/.test(told),
      `a click picks it, and the page tells Claude: "${told.slice(0, 120)}…"`);
    const panel = await page.locator("text=Model Context").count();
    const hostHas = panel ? await page.locator("text=Model Context").first().evaluate((el) => el.closest("div").parentElement.textContent) : "";
    check(panel > 0 && hostHas.includes(`#${now.picked.id}`),
      `...through ui/update-model-context: basic-host holds it as the model's context (#${now.picked && now.picked.id})`);
    let selected = "";
    for (let n = 0; n < 10 && !selected.includes(`#${now.picked.id}`); n++) {
      await sleep(1000);
      selected = texts(await claude.call("selection")).join(" ");
    }
    check(selected.includes(`#${now.picked.id}`),
      `...and it is selected in the tab, so Claude's selection tool reads it: "${selected.replace(/\s+/g, " ").slice(0, 100)}"`);
    await page.screenshot({ path: `${out}/3_picked.png` });
  }

  // Check: through the host, and tinted.
  const plainSample = (await cardOf(frame)).sample;
  await frame.locator("#check").click();
  for (let n = 0; n < 120 && !(await cardOf(frame)).tinted; n++) await sleep(500);
  await sleep(800);
  now = await cardOf(frame);
  check(now.called.includes("viewer_check") && now.tinted,
    `Check calls the tab through the host (viewer_check): ${now.tinted ? `${now.tinted.weak} weak, ${now.tinted.strained} strained` : "no answer"}`);
  check(now.tinted && now.tinted.marked > 0 && now.sample.warm > plainSample.warm + 0.001 && now.sample.grey > plainSample.grey,
    `...and tints the model: the parts it names amber to red (${Math.round(plainSample.warm * 1000) / 10}% to ${Math.round(now.sample.warm * 1000) / 10}% of the stage), the rest clay`);
  await page.screenshot({ path: `${out}/4_checked.png` });

  // Instructions, a step at a time.
  await frame.locator("#steps").click();
  for (let n = 0; n < 120 && !(await cardOf(frame)).step; n++) await sleep(500);
  const first = (await cardOf(frame)).step;
  await frame.locator("button[aria-label='Next step']").click();
  await sleep(800);
  const second = (await cardOf(frame)).step;
  await frame.locator("button[aria-label='Next step']").click();
  await sleep(800);
  const third = (await cardOf(frame)).step;
  check(now.called !== undefined && first && second && third && first.at === 1 && second.at === 2 && third.at === Math.min(3, first.of)
      && first.shown < second.shown && second.shown <= third.shown && third.shown <= stated,
    `the instructions step: step ${first && first.number} shows ${first && first.shown} parts, then ${second && second.shown}, then ${third && third.shown}, of ${first && first.of} steps`);
  await frame.locator("button[aria-label='Previous step']").click();
  await sleep(600);
  check((await cardOf(frame)).step.at === 2, "...and back");
  await page.screenshot({ path: `${out}/5_steps.png` });

  // The parts list, and the wanted list for BrickLink.
  await frame.locator("#list").click();
  for (let n = 0; n < 120 && !(await cardOf(frame)).lots; n++) await sleep(500);
  now = await cardOf(frame);
  check(now.called.includes("viewer_parts") && now.lots >= 5,
    `Parts lists the model's ${now.lots} lots`);
  await frame.locator("button:has-text('BrickLink wanted list')").click();
  await sleep(1500);
  const xml = await frame.evaluate(() => (document.querySelector(".copybox") || {}).value || "");
  now = await cardOf(frame);
  check(xml.startsWith("<INVENTORY>") || now.copied || now.downloaded,
    `...and gives the BrickLink wanted list${xml ? `, to copy (${xml.length} characters): basic-host offers no download` : now.downloaded ? `, downloaded as ${now.downloaded}` : ", copied"}`);
  await page.screenshot({ path: `${out}/6_parts.png` });

  // Full screen, asked for as the spec says.
  await frame.locator("#full").click();
  await sleep(1500);
  now = await cardOf(frame);
  const tall = await page.evaluate(() => Math.max(...[...document.querySelectorAll("iframe")].map((f) => f.getBoundingClientRect().height)));
  check(now.displayMode === "fullscreen" && tall > 700,
    `full screen is asked for (ui/request-display-mode) and given: ${now.displayMode}, the frame ${Math.round(tall)} px tall`);
  await page.screenshot({ path: `${out}/7_fullscreen.png` });
  await frame.locator("#full").click();
  await sleep(1000);
  check((await cardOf(frame)).displayMode === "inline", "...and back inline");

  // Open in Brickworks: the person's tab, by its id.
  await context.route(new RegExp(`^${site.replace(/[.]/g, "[.]")}/app\\?tab=`), (route) => route.fulfill({ status: 200,
    contentType: "text/html", body: "<!doctype html><title>Brickworks (stand-in)</title>" }));
  const opening = context.waitForEvent("page", { timeout: 20000 }).catch(() => null);
  await frame.locator("#open").click();
  const opened = await opening;
  const openedAt = opened ? opened.url() : "";
  if (opened) await opened.close();
  const tabId = (await cardOf(frame)).tab;
  check(Boolean(tabId) && openedAt.startsWith(`${site}/app?tab=${tabId}`),
    `Open in Brickworks opens the person's tab: ${openedAt || "nothing opened"}`);
  // That link, for real, in the browser the tab is open in: the page starts
  // nothing, says the model is in another tab, and that tab says it is it.
  await context.unroute(new RegExp(`^${site.replace(/[.]/g, "[.]")}/app\\?tab=`));
  const titles = [];
  const watching = setInterval(() => { tab.title().then((t) => titles.push(t)).catch(() => {}); }, 250);
  const linked = await context.newPage();
  await linked.goto(withBypass(`${site}/app?tab=${tabId}`), { waitUntil: "domcontentloaded", timeout: 120000 });
  let elsewhere = null;
  for (let n = 0; n < 60 && !elsewhere; n++) {
    await sleep(500);
    elsewhere = await linked.evaluate(() => window.brickworksElsewhere || null).catch(() => null);
  }
  await sleep(2000);
  clearInterval(watching);
  const said = await linked.evaluate(() => (document.getElementById("note") || {}).textContent || "").catch(() => "");
  check(elsewhere === tabId && /another Brickworks tab/.test(said) && titles.some((t) => /Your model is here/.test(t)),
    `...and that link, in the browser the tab is open in, starts nothing and points there: "${said.slice(0, 70)}", the tab's title "${titles.find((t) => /here/.test(t)) || titles[titles.length - 1] || ""}"`);
  await linked.close();

  // ── 2. A host that never says it shows pages, and will not call a tool its model was not given ──
  console.log("\n  b. a host that never says it shows pages, and refuses the page tools its model was not listed");
  const plain = conns[1];
  frame = await callFromHost(1, "look_at_model");
  now = await ready(frame);
  check(!plain.listed.has("viewer_scene") && plain.listed.size === app.length + 2,
    `its model is listed the same ${plain.listed.size} tools, none of the viewer's`);
  check(plain.seen.some((s) => s.refused && s.name === "viewer_scene") && plain.seen.some((s) => s.uri === "brickworks://viewer/scene"),
    "the page's tool call is refused, and it reads brickworks://viewer/scene instead");
  check(now.source === "resources/read" && now.mode === "3d" && now.sample && now.sample.drawn > 0.02 && now.shown === stated,
    `...and draws the model all the same: ${now.shown} parts, ${now.sample ? Math.round(now.sample.drawn * 1000) / 10 : 0}% of the stage`);
  const throughHost = await frame.evaluate(() => window.brickworksCard.geometryThroughHost || 0);
  check(throughHost >= 4 && plain.seen.some((s) => /^brickworks:\/\/viewer\/part\//.test(s.uri || "")),
    `...though this host lets it fetch from nowhere, the geometry too, read through the host: ${throughHost} parts`);
  await frame.locator("#check").click();
  for (let n = 0; n < 120 && !(await cardOf(frame)).tinted; n++) await sleep(500);
  check(Boolean((await cardOf(frame)).tinted) && plain.seen.some((s) => s.uri === "brickworks://viewer/check"),
    "...and Check works there too, by reading brickworks://viewer/check");
  await page.screenshot({ path: `${out}/8_plain_host.png` });

  // ── 3. A host that hands the result on whole ──
  console.log("\n  c. a host that says it shows pages and hands the result on whole");
  const passing = conns[2];
  // The strict host's refusals were its own; from here none is wanted.
  refused.length = 0;
  frame = await callFromHost(2, "look_at_model");
  now = await ready(frame);
  const toolsSeen = [...passing.listed];
  check(["viewer_scene", "viewer_check", "viewer_steps", "viewer_parts", "viewer_pick"].every((n) => passing.listed.has(n)),
    "the viewer's own tools are listed to it, for its page alone");
  const options = await page.locator("form select").nth(1).locator("option").allTextContents();
  check(!options.some((o) => o.startsWith("viewer_")) && options.length === toolsSeen.length - 5,
    `...and basic-host keeps them from its tool list, as a host keeps them from its model (${options.length} of ${toolsSeen.length})`);
  const lookAnswer = passing.seen.find((s) => s.method === "tools/call" && s.name === "look_at_model");
  check(now.source === "result" && !now.called.includes("viewer_scene") && now.shown === stated,
    `the page draws the model from the answer's own _meta, asking for nothing (${lookAnswer ? lookAnswer.chars : "?"} characters, the whole answer)`);
  check(refused.length === 0, `the content policy refused nothing${refused.length ? `: ${refused[0]}` : ""}`);
  await page.screenshot({ path: `${out}/9_passes.png` });

  if (args.sizes) {
    console.log("\n4. sizes and first paint, at 400 and 4,000 parts");
    const sizes = [];
    const { unpack } = await import("../viewer/scene.js");
    for (const wanted of [400, 4000]) {
      // Orthanc, cut to its first [wanted] parts by number: the numbers
      // read off the model as the card reads them.
      const opened = await claude.call("open_model", { name: "orthanc", discard_changes: true });
      const whole = await unpack((await claude.call("viewer_scene")).result.structuredContent.scene);
      const ids = [...whole.ids].filter((id, k) => !(whole.flags[k] & 1)).sort((a, b) => a - b);
      const cut = await claude.call("edit_model", { remove: ids.slice(wanted) });
      const have = Number((/(\d+) parts are on the baseplate/.exec(texts(await claude.call("look_at_model")).join(" ")) || [])[1]);
      for (const cold of [true, false]) {
        frame = await callFromHost(2, "look_at_model");
        now = await ready(frame, 600);
        const answer = passing.seen.filter((s) => s.method === "tools/call" && s.name === "look_at_model").pop();
        const sceneChars = answer && answer.answer && answer.answer.result && answer.answer.result._meta
          ? JSON.stringify(answer.answer.result._meta["brickworks/view"]?.scene || {}).length : 0;
        const row = { parts: have, cold, answerChars: answer ? answer.chars : 0, sceneChars, shapes: now.geometry.files,
          geometryKB: Math.round(now.geometry.bytes / 1024),
          firstMs: now.timings.first3d - now.timings.result, completeMs: now.timings.complete3d - now.timings.result,
          drawn: now.shown, opened: texts(opened).join(" ").slice(0, 60), cut: texts(cut).join(" ").slice(0, 80) };
        sizes.push(row);
        console.log(`  ${have} parts${cold ? "" : " (geometry cached)"}: the answer ${row.answerChars} characters, the model in it ${sceneChars}; `
          + `${row.shapes} shapes, ${row.geometryKB} KB of geometry; first 3D frame ${row.firstMs} ms, every part drawn ${row.completeMs} ms`);
      }
    }
    writeFileSync(`${out}/sizes.json`, JSON.stringify(sizes, null, 2));
    check(sizes.every((s) => s.drawn === s.parts && s.answerChars < 150000), "every size drawn whole, each answer inside claude.ai's 150,000 characters");
  }
} catch (trouble) {
  check(false, `stopped: ${trouble.stack || trouble.message}`);
} finally {
  if (browser) await browser.close().catch(() => {});
  if (host) host.kill();
  for (const c of conns) c.server.close();
  const gone = await dropAccount(account).catch(() => false);
  console.log(`\nthe throwaway account ${gone ? "deleted" : "NOT deleted"}`);
}
writeFileSync(`${out}/results.txt`, results.join("\n") + "\n");
console.log(failures ? `${failures} failure(s)` : "the model in Claude is 3D and interactive, whatever the host hands it");
process.exit(failures ? 1 : 0);
