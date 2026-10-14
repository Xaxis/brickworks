// Prove connecting Claude on a deployment, as a person and as claude.ai.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/oauth_flow.mjs --url=<a preview>/app --out=shots/oauth
//   node tools/web/oauth_flow.mjs --url=https://brickworks.diy/app --out=shots/oauth
//
// In a real browser, signed in as a throwaway account: press Connect
// Claude, and see claude.ai's "Add custom connector" open with Brickworks
// filled in and the address on the clipboard. Then do what claude.ai does
// once the person presses Add and Connect (claude.com/docs/connectors/
// building/authentication): ask the MCP address with no token and follow
// its 401 to the metadata, identify as Claude by its published client
// document, and send the browser to Brickworks' sign-in page with PKCE —
// where the app's own session in that browser means only Allow is left.
// Allow, catch the browser arriving back at claude.ai's callback (claude.ai
// itself is stood in for: nothing reaches it), trade the code for tokens,
// and call tools with the token: the signed-in tab answers, out of view
// too (its frames stopped, as a hidden tab's are), and the panel says
// Connected. claude.ai connecting again is sent straight back with a code,
// asked nothing: this account allowed it already. Then the same sign-in
// from another browser that is not signed in: the email code, minted on
// this side, typed into the page, and again nothing more asked — and that
// browser's token builds in the first one's tab, as another device would.
// Then Account shows the connections and Disconnect Claude ends them: every
// token is refused at once. Last, claude.ai connecting after that is asked
// again, and Allow connects it.
//
// Costs nothing: no model is called. Emails one Resend test address.
// The throwaway account and everything of it are deleted at the end.
import { createHash, randomBytes } from "node:crypto";
import { mkdirSync } from "node:fs";

// An account of its own, so no other test's tab of the shared test account
// can be the one Claude's calls go to. Set before browser.mjs is loaded,
// which reads it once: a static import of it ran first, and the flow signed
// in as the shared test account and disconnected its Claude (2026-10-14).
const email = `delivered+bwoauthflow${Date.now().toString(36)}@resend.dev`;
process.env.BW_TEST_EMAIL = email;
const { launch, openColumnFor, withAssistant } = await import("./browser.mjs");
const { mintCode } = await import("./session.mjs");

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = withAssistant(args.url || "https://brickworks.diy/app");
const site = new URL(url).origin;
const out = args.out || "shots/oauth";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";

const CLAUDE = "https://claude.ai/oauth/mcp-oauth-client-metadata";
const CALLBACK = "https://claude.ai/api/mcp/auth_callback";
const LINK = "https://claude.ai/customize/connectors?modal=add-custom-connector"
  + `&connectorName=Brickworks&connectorUrl=${encodeURIComponent(`${site}/api/mcp`)}`;

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const withBypass = (address) => (bypass
  ? `${address}${address.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : address);

async function call(address, { method = "GET", headers = {}, body, form } = {}) {
  const sent = { ...headers };
  if (bypass) sent["x-vercel-protection-bypass"] = bypass;
  let payload;
  if (form) {
    sent["content-type"] = "application/x-www-form-urlencoded";
    payload = new URLSearchParams(form).toString();
  } else if (body !== undefined) {
    sent["content-type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const reply = await fetch(address, { method, headers: sent, body: payload, redirect: "manual" });
  const text = await reply.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: reply.status, headers: reply.headers, json };
}

let sent = 0;
async function claude(token, method, params = {}) {
  sent += 1;
  const reply = await call(`${site}/api/mcp`, {
    method: "POST",
    headers: { accept: "application/json, text/event-stream", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: { jsonrpc: "2.0", id: sent, method, params },
  });
  return reply;
}
const textOf = (reply) => (reply.json?.result?.content || []).map((c) => c.text || "").join(" ");

// claude.ai, stood in for: whatever the browser is sent there is answered
// here, so nothing reaches the real site and the address can be read.
async function standInForClaude(context) {
  await context.route(/^https:\/\/claude\.ai\//, (route) => route.fulfill({
    status: 200, contentType: "text/html",
    body: "<!doctype html><title>claude.ai (stand-in)</title><p style='font:16px sans-serif;padding:24px'>"
      + "claude.ai, stood in for by the test. The address this page was sent to is what is checked.</p>",
  }));
}

/// claude.ai's half of connecting: discovery from the 401, then the
/// authorization request it would send the browser to.
async function discover() {
  const bare = await claude(null, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "oauth_flow", version: "1" } });
  const pointer = /resource_metadata="([^"]+)"/.exec(bare.headers.get("www-authenticate") || "")?.[1];
  const resource = (await call(pointer)).json;
  const server = (await call(`${resource.authorization_servers[0]}/.well-known/oauth-authorization-server`)).json;
  return { bare, pointer, resource, server };
}

function authorizationRequest(server, resource) {
  const verifier = b64url(randomBytes(32));
  const challenge = b64url(createHash("sha256").update(verifier).digest());
  const state = b64url(randomBytes(9));
  const asked = new URL(server.authorization_endpoint);
  for (const [key, value] of Object.entries({
    response_type: "code", client_id: CLAUDE, redirect_uri: CALLBACK, code_challenge: challenge,
    code_challenge_method: "S256", state, scope: "build offline_access", resource: resource.resource,
  })) asked.searchParams.set(key, value);
  return { address: asked.toString(), verifier, state };
}

/// What the sign-in page did with a request: sent the browser back to
/// claude.ai ("back"), or put the question ("asked").
async function outcome(tab) {
  for (let n = 0; n < 160; n++) {
    if (tab.url().startsWith(CALLBACK)) return "back";
    const asking = await tab.evaluate(() => {
      const step = document.querySelector("#allow-step");
      return Boolean(step && !step.classList.contains("hide"));
    }).catch(() => false);
    if (asking) return "asked";
    await tab.waitForTimeout(250);
  }
  return "neither";
}

async function trade(server, resource, back, verifier) {
  const code = new URL(back).searchParams.get("code");
  return call(server.token_endpoint, { method: "POST", form: {
    grant_type: "authorization_code", code, redirect_uri: CALLBACK, client_id: CLAUDE,
    code_verifier: verifier, resource: resource.resource,
  } });
}

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: site });
await standInForClaude(context);
// A browser stops giving a tab out of view its frames; one driven from
// here never hides a page, so the frames are gated as a hidden tab's are
// (connector_flow.mjs says why this matters).
await context.addInitScript(() => {
  const real = window.requestAnimationFrame.bind(window);
  const held = [];
  window.brickworksTestFrames = { stopped: false, held };
  window.requestAnimationFrame = (callback) => {
    if (window.brickworksTestFrames.stopped) { held.push(callback); return 0; }
    return real(callback);
  };
});
const page = await context.newPage();
await page.goto(withBypass(url), { waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForTimeout(Number(args.load || 90000));

async function where(name, tries = 600) {
  for (let n = 0; n < tries; n++) {
    const at = await page.evaluate((key) => (window.brickworksControls || {})[key], name);
    if (at) return at;
    // In a laptop's window the assistant's column starts folded.
    if (n === 6) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  return null;
}
async function click(name) {
  const at = await where(name);
  if (!at) {
    await page.screenshot({ path: `${out}/never_showed_${name}.png` }).catch(() => {});
    throw new Error(`the app never showed "${name}"; see ${out}/never_showed_${name}.png`);
  }
  await page.mouse.click(at.x, at.y);
}
const claudeState = () => page.evaluate(() => window.brickworksClaude || {});
async function waitFor(test, ms = 30000) {
  const until = Date.now() + ms;
  let state = await claudeState();
  while (!test(state) && Date.now() < until) {
    await page.waitForTimeout(500);
    state = await claudeState();
  }
  return state;
}
const shot = (name) => page.screenshot({ path: `${out}/${name}.png`, timeout: 120000 }).catch(() => {});
const seeing = (hidden) => page.evaluate((hide) => {
  Object.defineProperty(document, "hidden", { value: hide, configurable: true });
  Object.defineProperty(document, "visibilityState", { value: hide ? "hidden" : "visible", configurable: true });
  const frames = window.brickworksTestFrames;
  frames.stopped = hide;
  document.dispatchEvent(new Event("visibilitychange"));
  if (!hide) frames.held.splice(0).forEach((f) => window.requestAnimationFrame(f));
}, hidden);

let first = null;
let second = null;
let otherBrowser = null;
try {
  console.log(`connecting Claude at ${url}, as ${email}\n`);
  console.log("the one click");
  const account = await page.evaluate(() => window.brickworksAccount || {});
  check(account.state === "signed_in" && account.email === email, `signed in as ${account.email}`);
  await shot("1_before_connect");
  const opened = context.waitForEvent("page", { timeout: 30000 });
  await click("connect_claude");
  const claudeTab = await opened;
  await claudeTab.waitForLoadState("domcontentloaded").catch(() => {});
  check(claudeTab.url() === LINK, `Connect Claude opens claude.ai's Add custom connector, filled in:\n          ${claudeTab.url()}`);
  await claudeTab.close();
  const copied = await page.evaluate(() => navigator.clipboard.readText());
  check(copied === `${site}/api/mcp`, `...with the address on the clipboard: ${copied}`);
  const waiting = await waitFor((s) => s.on && /Waiting for you/.test(s.status || ""));
  check(waiting.on && /Waiting for you to connect in Claude/.test(waiting.status || ""),
    `the tab is listening, and the panel waits: "${waiting.status}"`);
  await shot("2_waiting_for_claude");

  console.log("\nclaude.ai adds it: discovery, its published identity, PKCE");
  const found = await discover();
  check(found.bare.status === 401 && found.pointer === `${site}/.well-known/oauth-protected-resource/api/mcp`,
    `the address with no token: 401, pointing at ${found.pointer}`);
  check(found.resource?.resource === `${site}/api/mcp` && found.server?.issuer === site
      && found.server?.client_id_metadata_document_supported === true,
    `metadata: resource ${found.resource?.resource}, issuer ${found.server?.issuer}, published identities accepted`);
  const asked = authorizationRequest(found.server, found.resource);
  const signIn = await context.newPage();
  await signIn.goto(asked.address, { waitUntil: "domcontentloaded", timeout: 60000 });
  await signIn.waitForSelector("#allow-step:not(.hide)", { timeout: 30000 });
  const who = await signIn.textContent("#signed-in-as");
  const backTo = await signIn.textContent("#back-to");
  check(who === email, `Brickworks' sign-in uses the app's session in this browser: signed in as ${who}`);
  const question = await signIn.textContent("#allow-step h1");
  check(/claude\.ai/.test(backTo) && /Let Claude build in Brickworks/.test(question),
    `...and asks once — "${question.trim()}" — saying where the answer goes: "${backTo.trim()}"`);
  await signIn.screenshot({ path: `${out}/3_authorize_signed_in.png` });
  await signIn.click("#allow");
  await signIn.waitForURL((address) => address.toString().startsWith(CALLBACK), { timeout: 30000 });
  const back = new URL(signIn.url());
  check(back.searchParams.get("state") === asked.state && back.searchParams.get("iss") === site
      && /^bwk_/.test(back.searchParams.get("code") || ""),
    "Allow: the browser goes back to claude.ai's callback with a code, the state and the issuer");
  // A request it will not serve (no PKCE) from a client it can answer: said
  // on the page with a way back, never forwarded by itself.
  const malformed = new URL(asked.address);
  malformed.searchParams.delete("code_challenge");
  await signIn.goto(malformed.toString(), { waitUntil: "domcontentloaded", timeout: 60000 });
  await signIn.waitForSelector("#refused:not(.hide)", { timeout: 30000 });
  await signIn.waitForTimeout(1500);
  const stayed = new URL(signIn.url()).origin === site;
  const backLink = await signIn.getAttribute("#refused-why a", "href").catch(() => null);
  check(stayed && new URL(backLink || "https://x/").searchParams.get("error") === "invalid_request",
    "a request without PKCE is refused on the page, with a way back carrying the error — not forwarded");
  await signIn.close();
  const tokens = await trade(found.server, found.resource, back.toString(), asked.verifier);
  first = tokens.json?.access_token;
  check(tokens.status === 200 && /^bwa_/.test(first || "") && /^bwr_/.test(tokens.json?.refresh_token || ""),
    "claude.ai trades the code and its verifier for tokens");
  const connected = await waitFor((s) => (s.connected || []).includes("Claude") && /^Connected/.test(s.status || ""));
  check((connected.connected || []).includes("Claude") && /^Connected to Claude/.test(connected.status || ""),
    `the panel says so by itself: "${connected.status}"`);
  check(!(await where("connect_claude", 2)) && Boolean(await where("claude_disconnect", 4)),
    "...Connect Claude gives way to Disconnect");
  await shot("4_connected");

  console.log("\nclaude.ai connects again (reconnected in Claude, or another of its apps)");
  const askedTwice = authorizationRequest(found.server, found.resource);
  const signInTwice = await context.newPage();
  await signInTwice.goto(askedTwice.address, { waitUntil: "domcontentloaded", timeout: 60000 });
  const twice = await outcome(signInTwice);
  check(twice === "back" && new URL(signInTwice.url()).searchParams.get("state") === askedTwice.state,
    `allowed already by this account: back to claude.ai's callback with a code, the question not put (${twice})`);
  await signInTwice.screenshot({ path: `${out}/4b_allowed_before.png` }).catch(() => {});
  const tokensTwice = twice === "back"
    ? await trade(found.server, found.resource, signInTwice.url(), askedTwice.verifier) : { status: 0 };
  const firstAgain = tokensTwice.json?.access_token;
  check(tokensTwice.status === 200 && /^bwa_/.test(firstAgain || ""), "...and that code is traded for tokens");
  await signInTwice.close();

  console.log("\nClaude builds, through the one address");
  const hello = await claude(first, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "claude-ai", version: "0.1.0" } });
  check(hello.json?.result?.serverInfo?.name === "brickworks" && (hello.json?.result?.instructions || "").length > 1000,
    "initialize with the token: the app's design guidance");
  const listed = await claude(first, "tools/list");
  const names = (listed.json?.result?.tools || []).map((t) => t.name);
  check(names.includes("submit_design") && names.includes("search_parts"), `the tab's tools: ${names.length}`);
  const searched = await claude(first, "tools/call", { name: "search_parts", arguments: { query: "brick 2 x 4" } });
  check(textOf(searched).includes("3001") && !searched.json?.result?.isError,
    `a call runs in the signed-in tab: ${textOf(searched).slice(0, 50)}`);
  await seeing(true);
  await page.waitForTimeout(3000);
  let t0 = Date.now();
  const built = await claude(first, "tools/call", { name: "submit_design", arguments: { name: "connected",
    bricks: [{ part: "3001", color: 4, x: 40, y: 0, z: 40 }, { part: "3001", color: 1, x: 40, y: 3, z: 40 }] } });
  check(!built.json?.result?.isError && !/not open|paused/.test(textOf(built)),
    `out of view, a design is built, in ${Math.round((Date.now() - t0) / 1000)}s: ${textOf(built).slice(0, 60)}`);
  await seeing(false);
  await page.waitForTimeout(2000);
  const bricks = await page.evaluate(() => window.brickworksState?.bricks);
  check(bricks >= 2, `...and stands in the tab: ${bricks} bricks`);
  await shot("5_built");

  console.log("\nanother browser, not signed in: the email code");
  otherBrowser = await launch({ signedOut: true });
  const elsewhere = await otherBrowser.newContext({ viewport: { width: 900, height: 900 } });
  await standInForClaude(elsewhere);
  const away = await elsewhere.newPage();
  if (bypass) await away.goto(withBypass(`${site}/`), { waitUntil: "domcontentloaded", timeout: 60000 });
  const askedAgain = authorizationRequest(found.server, found.resource);
  await away.goto(askedAgain.address, { waitUntil: "domcontentloaded", timeout: 60000 });
  await away.waitForSelector("#email-step:not(.hide)", { timeout: 30000 });
  await away.screenshot({ path: `${out}/6_authorize_email.png` });
  await away.fill("#email", email);
  await away.click("#send");
  await away.waitForSelector("#code-step:not(.hide)", { timeout: 30000 });
  check(true, "an address, and Email me a code: the deployment sent one");
  // Minted here, which replaces the emailed one (the test has no inbox).
  const code = await mintCode(email);
  await away.fill("#code", "000000");
  await away.click("#verify");
  await away.waitForFunction(() => document.querySelector("#say")?.classList.contains("bad"), null, { timeout: 30000 });
  check(/wrong or has expired/.test(await away.textContent("#say")), `a wrong code is refused: "${await away.textContent("#say")}"`);
  await away.fill("#code", code);
  await away.screenshot({ path: `${out}/7_authorize_code.png` });
  await away.click("#verify");
  // This account allowed Claude in the first browser, and is connected to
  // it still: signed in here, it is not asked again.
  const awayOutcome = await outcome(away);
  check(awayOutcome === "back",
    `the code signs in, and, Claude being allowed by this account already, nothing more is asked (${awayOutcome})`);
  const tokens2 = awayOutcome === "back"
    ? await trade(found.server, found.resource, away.url(), askedAgain.verifier) : { json: null };
  second = tokens2.json?.access_token;
  check(/^bwa_/.test(second || ""), "...and the code traded: a second connection");
  // That browser is another device now: the app there opens signed in, from
  // the session the sign-in page kept, and listens by itself.
  const device = await elsewhere.newPage();
  await device.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
  let there = {};
  for (let n = 0; n < 400 && !(there.on && (there.connected || []).length); n++) {
    await device.waitForTimeout(500);
    there = await device.evaluate(() => window.brickworksClaude || {});
  }
  const signedThere = await device.evaluate(() => window.brickworksAccount?.email);
  check(signedThere === email && there.on && (there.connected || []).includes("Claude"),
    `the app in that browser opens signed in, from the session the sign-in page kept, and listens by itself, nothing pressed: "${there.status}"`);
  await device.screenshot({ path: `${out}/8b_second_device.png`, timeout: 120000 }).catch(() => {});
  const across = await claude(second, "tools/call", { name: "search_parts", arguments: { query: "brick 1 x 2" } });
  check(textOf(across).includes("3004"), "its calls go to one of the account's open tabs");
  await device.close();

  console.log("\nAccount, and Disconnect Claude");
  await click("account");
  await page.waitForTimeout(2500);
  check(Boolean(await where("account_disconnect_claude", 20)), "Account shows Claude connected, with Disconnect Claude");
  await shot("9_account_connected");
  await click("account_disconnect_claude");
  // A minute: at a load of thirty the disconnect, the renewal before it and
  // the list after it took longer than twenty seconds between them.
  const gone = await waitFor((s) => (s.connected || []).length === 0, 60000);
  check((gone.connected || []).length === 0, "Disconnect Claude: no connections left");
  const after = await waitFor((s) => !s.on && /^Disconnected/.test(s.status || ""), 20000);
  check(!after.on && /^Disconnected/.test(after.status || ""),
    `...this tab stops listening, and the panel says so: "${after.status}"`);
  const refused1 = await claude(first, "tools/list");
  const refused2 = await claude(second, "tools/list");
  const refused3 = await claude(firstAgain, "tools/list");
  check(refused1.status === 401 && refused2.status === 401 && refused3.status === 401
      && /resource_metadata=/.test(refused1.headers.get("www-authenticate") || ""),
    "all three connections' tokens are refused at once, and told where to sign in again");
  check(Boolean(await where("account_connect_claude", 20)), "...and Account offers Connect Claude again");
  await shot("10_disconnected");
  // This account has had Claude connected: Brickworks is in its Claude
  // already, so Connect Claude goes to Claude's connectors, to connect that
  // one, not to Add custom connector, which sets up another.
  const openedAgain = context.waitForEvent("page", { timeout: 30000 });
  await click("account_connect_claude");
  const listTab = await openedAgain.catch(() => null);
  await listTab?.waitForLoadState("domcontentloaded").catch(() => {});
  check(listTab?.url() === "https://claude.ai/customize/connectors",
    `Connect Claude again, for an account that had Claude: Claude's connectors, not Add custom connector: ${listTab?.url()}`);
  await listTab?.close();
  await page.waitForTimeout(1000);
  await shot("10b_connect_again");

  console.log("\nclaude.ai connects again after Disconnect");
  const askedAfter = authorizationRequest(found.server, found.resource);
  const signInAfter = await context.newPage();
  await signInAfter.goto(askedAfter.address, { waitUntil: "domcontentloaded", timeout: 60000 });
  const afterOutcome = await outcome(signInAfter);
  const questionAfter = afterOutcome === "asked" ? await signInAfter.textContent("#allow-step h1") : "";
  check(afterOutcome === "asked" && /Let Claude build in Brickworks/.test(questionAfter),
    `the question is put again, Disconnect having ended what was allowed (${afterOutcome})`);
  await signInAfter.screenshot({ path: `${out}/11_asked_again.png` });
  if (afterOutcome === "asked") {
    await signInAfter.click("#allow");
    await signInAfter.waitForURL((address) => address.toString().startsWith(CALLBACK), { timeout: 30000 });
    const tokensAfter = await trade(found.server, found.resource, signInAfter.url(), askedAfter.verifier);
    const hiAfter = await claude(tokensAfter.json?.access_token, "tools/list");
    check(tokensAfter.status === 200 && hiAfter.status === 200, "...and Allow connects Claude again");
  }
  await signInAfter.close();
} finally {
  await browser.close().catch(() => {});
  if (otherBrowser) await otherBrowser.close().catch(() => {});
  // The throwaway account, and with it its connections and tabs.
  const p = { url: process.env.SUPABASE_URL.replace(/\/+$/, ""), secret: process.env.SUPABASE_SECRET_KEY };
  const listed = await (await fetch(`${p.url}/auth/v1/admin/users?page=1&per_page=1000`, {
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` } })).json();
  const user = (listed.users || []).find((u) => (u.email || "").toLowerCase() === email);
  const removed = user && (await fetch(`${p.url}/auth/v1/admin/users/${user.id}`, { method: "DELETE",
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` } })).ok;
  console.log(`\n  (${removed ? "removed" : "could not remove"} the throwaway account)`);
}
console.log(failures ? `\n${failures} failure(s)` : "\nconnecting Claude works on this deployment");
process.exit(failures ? 1 : 0);
