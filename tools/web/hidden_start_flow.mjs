// Does a tab that goes out of view while it starts still reach Claude? The
// person opens Brickworks, or reloads it, and is in claude.ai before its
// window is drawn. A browser gives a tab out of view no frames, and the app
// runs on them, so only the page's own frames out of view
// (ClaudeConnector._watch_the_page) keep it going. Up to rel-m237 the page
// made them only for a connector already on, so a new tab, which first
// asks whether Claude is connected, asked with none and was heard only
// once the person came back; and made with the assistant's panel, on the
// first drawn frame, the connector asking was heard 5 times in 8
// (2026-11-01).
//
//   node tools/web/hidden_start_flow.mjs --url=https://brickworks.diy/app --hide=ui [--reload]
//   BW_BYPASS=… node tools/web/hidden_start_flow.mjs --url=<a preview>/app …
//   set -a; . ./.env; set +a
//   node tools/web/hidden_start_flow.mjs --dir=build/web …     a local export, served here
//
// A throwaway account, signed in, with Claude connected to it as claude.ai
// connects (the OAuth approve and token exchange): a tab opened after
// listens by itself. The page's frames are gated from boot as
// connector_flow.mjs gates them, and it goes out of view (document.hidden,
// visibilitychange, frames stopped):
//   --hide=start   as the page begins: nothing of the app has run, and
//                  nothing can until it is seen again (the engine's start
//                  waits on frames too), so this one is expected to fail
//   --hide=ui      the moment the app marks its window built (brickworksBoot.ui)
//   --hide=model   the moment it marks the model in (brickworksBoot.model)
// --reload: a visible load until the tab listens and answers, then a
// reload of the same tab (its id, and "on", kept with it), out of view as
// above. Without it, a new tab.
//
// Then, as Claude, every 5 s for --within s (30): is the tab listed
// (`tabs`), and is a read-only call (search_parts) answered by it? A
// reloaded tab stays listed a while on its last page's word, so the call
// is what counts. Then the page is shown, and the same asked until it
// answers: the control, that it does connect when seen. Passes when a call
// was answered out of view. The account is deleted after.
import { createHash, randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import { createServer } from "node:net";

const EMAIL = `delivered+bwhiddenstart${randomBytes(3).toString("hex")}@resend.dev`;
// Read by session.mjs as it loads.
process.env.BW_TEST_EMAIL = EMAIL;
const { launch, withAssistant, withJobs } = await import("./browser.mjs");
const { mintSession, STORAGE_KEY } = await import("./session.mjs");

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const hideAt = String(args.hide || "ui");
const within = Number(args.within || 30) * 1000;
const bypass = process.env.BW_BYPASS || "";
const relayHeaders = bypass ? { "x-vercel-protection-bypass": bypass } : {};
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const t0 = Date.now();
const at = () => `${((Date.now() - t0) / 1000).toFixed(1)} s`;

let server = null;
let address = args.url ? String(args.url) : "";
if (!address) {
  const port = await new Promise((done) => {
    const s = createServer();
    s.listen(0, "127.0.0.1", () => { const { port } = s.address(); s.close(() => done(port)); });
  });
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${args.dir || "build/web"}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  address = `http://127.0.0.1:${port}/`;
}
const url = withAssistant(address);
const origin = new URL(url).origin;

const minted = await mintSession(EMAIL);
async function claudeToken() {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${origin}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...relayHeaders, "content-type": "application/json", authorization: `Bearer ${minted.access_token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "hidden",
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
async function mcp(token, session, method, params, signal) {
  const answer = await fetch(`${origin}/api/mcp`, {
    method: "POST", signal,
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
const said = (body) => ((body?.result || {}).content || []).map((c) => c.text || "").join("\n");
async function listed(token, session, id) {
  const [status, body, , raw] = await mcp(token, session, "tools/call", { name: "tabs", arguments: {} });
  const words = said(body) || `(${status}: ${raw.slice(0, 160)})`;
  const open = /(\d+) Brickworks tabs? (?:is|are) open/.exec(words);
  return { words, here: id ? words.includes(id) : Boolean(open && Number(open[1]) > 0) };
}
// A read-only call the tab itself answers, given at most [ms].
async function answered(token, session, ms) {
  const began = Date.now();
  const send = async (method, params) => (await mcp(token, session, method, params,
    AbortSignal.timeout(Math.max(1000, ms - (Date.now() - began)))))[1];
  try {
    const answer = await withJobs(send, { waits: 5 })("tools/call",
      { name: "search_parts", arguments: { query: "brick 1 x 2" } });
    return { ok: said(answer).includes("3004") && !answer?.result?.isError, words: said(answer) };
  } catch (e) {
    return { ok: false, words: String(e).slice(0, 80) };
  }
}

const token = await claudeToken();
console.log(`${at()} Claude connected to ${EMAIL}: ${token.startsWith("bwa_")}`);
const [, , session] = await mcp(token, "", "initialize", { protocolVersion: "2025-06-18",
  capabilities: {}, clientInfo: { name: "hidden_start_flow", version: "1" } });

const browser = await launch({ signedOut: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
await context.addInitScript(([name, value]) => {
  try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
}, [STORAGE_KEY, JSON.stringify(minted.kept)]);
// Out of view as a browser puts a tab out of view: its frames stop. The
// moment is the app's own boot mark (window.brickworksBoot), caught as it
// is set; a reload reads it from the tab's session.
await context.addInitScript(([key, firstHide]) => {
  const real = window.requestAnimationFrame.bind(window);
  const frames = { stopped: false, held: [] };
  window.brickworksTestFrames = frames;
  window.requestAnimationFrame = (callback) => {
    if (frames.stopped) { frames.held.push(callback); return 0; }
    return real(callback);
  };
  window.__see = (hidden) => {
    Object.defineProperty(document, "hidden", { value: hidden, configurable: true });
    Object.defineProperty(document, "visibilityState", { value: hidden ? "hidden" : "visible", configurable: true });
    frames.stopped = hidden;
    document.dispatchEvent(new Event("visibilitychange"));
    if (!hidden) frames.held.splice(0).forEach((f) => window.requestAnimationFrame(f));
  };
  const hide = sessionStorage.getItem(key) ?? firstHide;
  if (hide === "start") window.__see(true);
  window.brickworksBoot = new Proxy({}, { set(marks, mark, when) {
    marks[mark] = when;
    if (mark === hide && !frames.stopped) window.__see(true);
    return true;
  } });
}, ["bwHideAt", args.reload ? "" : hideAt]);
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 160)));
const first = bypass ? `${url}&x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true` : url;
const pageSays = () => page.evaluate(() => ({
  connector: window.brickworksConnector || "", tab: window.brickworksTab || "",
  watched: Boolean(window.brickworksConnectorWatched), asking: Boolean(window.brickworksConnectorAsking),
  boot: Object.fromEntries(Object.entries(window.brickworksBoot || {}).map(([k, v]) => [k, Math.round(v)])),
  held: window.brickworksTestFrames.held.length, stopped: window.brickworksTestFrames.stopped,
})).catch((e) => ({ error: String(e).slice(0, 80) }));

let tab = "";
if (args.reload) {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  let on = false;
  for (let n = 0; n < 240 && !on; n++) {
    on = Boolean((await pageSays()).connector);
    if (!on) await wait(500);
  }
  tab = (await pageSays()).tab;
  const seen = await answered(token, session, 30000);
  console.log(`${at()} in view first: listening ${on}, tab ${tab}, a call answered: ${seen.ok}`);
  await page.evaluate((hide) => sessionStorage.setItem("bwHideAt", hide), hideAt);
  await page.reload({ waitUntil: "commit", timeout: 180000 });
} else {
  await page.goto(first, { waitUntil: "commit", timeout: 180000 });
}
let hidden = false;
for (let n = 0; n < 600 && !hidden; n++) {
  hidden = Boolean((await pageSays()).stopped);
  if (!hidden) await wait(250);
}
console.log(`${at()} out of view at "${hideAt}": ${hidden}; boot marks then ${JSON.stringify((await pageSays()).boot)}`);
const hidAt = Date.now();
let wasListed = false;
let calledIn = 0;
let lastWords = "";
while (Date.now() - hidAt < within && !calledIn) {
  await wait(5000);
  tab = tab || (await pageSays()).tab;
  wasListed = wasListed || (await listed(token, session, tab)).here;
  const left = within - (Date.now() - hidAt);
  if (left < 1000) break;
  const call = await answered(token, session, left);
  lastWords = call.words;
  if (call.ok) calledIn = Date.now() - hidAt;
}
const after = await pageSays();
console.log(`${at()} out of view ${Math.round((Date.now() - hidAt) / 1000)} s: listed ${wasListed}, `
  + (calledIn ? `a call answered ${(calledIn / 1000).toFixed(1)} s after it went` : `no call answered ("${lastWords.slice(0, 90)}")`));
console.log(`        page: connector ${after.connector ? "on" : "off"}${after.watched ? "" : " (its page watch never made)"}`
  + `${after.asking ? ", asking" : ""}, frames held ${after.held}, boot ${JSON.stringify(after.boot)}`);
await page.evaluate(() => window.__see(false));
const shownAt = Date.now();
let shown = Boolean(calledIn);
while (!shown && Date.now() - shownAt < 120000) {
  await wait(3000);
  shown = (await answered(token, session, 30000)).ok;
}
console.log(`${at()} in view again: ${shown ? `answered within ${Math.round((Date.now() - shownAt) / 1000)} s` : "NOT answered in 120 s"}`);
console.log(`RESULT hide=${hideAt} reload=${Boolean(args.reload)} answered_out_of_view=${Boolean(calledIn)}`
  + `${calledIn ? `(${(calledIn / 1000).toFixed(1)}s)` : ""} listed=${wasListed} answered_in_view=${shown}`
  + `${errors.length ? ` page error: ${errors[0]}` : ""}`);
await browser.close();
if (server) server.kill();
const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const secret = process.env.SUPABASE_SECRET_KEY || "";
const gone = base && secret && minted.kept.user_id ? await fetch(`${base}/auth/v1/admin/users/${minted.kept.user_id}`, {
  method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` } }).then((r) => r.ok).catch(() => false) : false;
console.log(`the throwaway account ${gone ? "deleted" : "NOT deleted"}`);
process.exit(calledIn ? 0 : 1);
