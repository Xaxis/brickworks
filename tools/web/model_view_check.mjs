// Does Claude show the model beside the call? MCP Apps, end to end.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/model_view_check.mjs --url=<a preview>/app --out=shots/model_view
//   node tools/web/relay_server.mjs 8797 &
//   node tools/web/model_view_check.mjs --url=http://127.0.0.1:8797/app --relay-only
//
// claude.ai, the Claude apps and other hosts of the MCP Apps extension
// (io.modelcontextprotocol/ui, spec 2026-01-26) can show a server's own page
// inline in a conversation. The relay serves one, a viewer of the model
// (api/_viewer.js); the tools whose answer is the model as it now stands
// name it in their _meta; and a client that says it shows such pages is
// given, in each of those answers' _meta, the parts count and pictures of
// the model (src/net/model_views.gd).
//
// Played here from both ends, through the deployed relay, as claude.ai does
// it: signed in with OAuth to a throwaway account (deleted at the end), with
// a real tab of that account open in a browser answering the calls.
//
//   1. The relay alone: initialize says it serves resources and the
//      extension; tools/list names the viewer on its tools, and the tool
//      count is the app's 47, the relay's two and the viewer's own five,
//      for its page alone; resources/read gives the page, self-contained,
//      declaring the one origin it fetches part geometry from.
//   2. A real tab: a design built, looked over and looked at by a session
//      that shows pages (the model packed and the front corner in _meta;
//      the whole turntable from viewer_scene), and the same calls by one
//      that does not, whose answers carry nothing more and whose words and
//      pictures are the same.
//   3. A host, as the spec says one behaves, in a browser that cannot draw
//      in 3D: the page in a sandboxed frame under the policy it declares,
//      the handshake answered, the real answers sent as tool-input and
//      tool-result, and the page's own tool calls answered by the relay.
//      The page asks for the turntable and shows it, the parts count, it
//      turns, and nothing is refused by the policy.
//      tools/web/app_host_check.mjs is the 3D page, in the reference host.
//   4. Every call a job: a second tab of the account opened with
//      /app?jobs-after=0 (ToolJobs.after_s), where any call becomes a job
//      however small the model, called with target. The same design built
//      and looked at there: each call answers "Started job N" with which job
//      in its _meta, and one call of job once it is done gives the call's
//      own answer, the words, the picture and the _meta the inline answer
//      carried; a client that does not show pages gets the same words and
//      picture. And the card beside a call that became a job follows it,
//      through the host, and shows its picture.
//
// Before 2026-10-14 the relay served no resources and named nothing, so
// every check from 1 on failed. Before 2026-10-16 a job's answer carried
// no _meta and the card beside a call that became one showed the model as
// it stood mid-call, so 4 failed; on a loaded box view_model became a job
// in 2 as well (release m33, load 75), which 2 now follows as a session
// does. Costs nothing: no model is called.
import { createHash, randomBytes } from "node:crypto";
import { mkdirSync, readFileSync } from "node:fs";

// An account of its own, so no other test's tab is the one Claude's calls
// go to. Set before browser.mjs is loaded, which reads it once.
const email = `delivered+bwmodelview${Date.now().toString(36)}@resend.dev`;
process.env.BW_TEST_EMAIL = email;
const { launch, openColumnFor, withAssistant, withJobs } = await import("./browser.mjs");
const { mintSession } = await import("./session.mjs");

// The throwaway account, and with it its connections and tabs. Not
// session.mjs's deleteAccount, which never deletes BW_TEST_EMAIL's.
async function dropAccount(id) {
  if (!id) return false;
  const secret = process.env.SUPABASE_SECRET_KEY;
  const gone = await fetch(`${process.env.SUPABASE_URL.replace(/\/+$/, "")}/auth/v1/admin/users/${id}`, {
    method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` } });
  return gone.ok;
}

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = withAssistant(args.url || "https://brickworks.diy/app");
const site = new URL(url).origin;
const out = args.out || "shots/model_view";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const extra = bypass ? { "x-vercel-protection-bypass": bypass } : {};
const withBypass = (address) => (bypass
  ? `${address}${address.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : address);

const EXTENSION = "io.modelcontextprotocol/ui";
const MIME = "text/html;profile=mcp-app";
const URI = "ui://brickworks/model.html";
const SHOWN = ["submit_design", "look_at_model", "view_model", "edit_model", "open_model", "brickify"];
const VIEWER_ONLY = ["viewer_scene", "viewer_check", "viewer_steps", "viewer_parts", "viewer_pick"];
// The policy a host builds from what the page declares (apps.mdx, "CSP
// Construction from Metadata").
const policyOf = (csp = {}) => {
  const resources = (csp.resourceDomains || []).join(" ");
  return `default-src 'none'; script-src 'self' 'unsafe-inline' ${resources}; style-src 'self' 'unsafe-inline' ${resources}; `
    + `connect-src 'self' ${(csp.connectDomains || []).join(" ")}; img-src 'self' data: ${resources}; `
    + `font-src 'self' ${resources}; media-src 'self' data: ${resources}; frame-src 'none'; object-src 'none';`;
};

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
  return ok;
};
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");

// Claude's sign-in to the account, as claude.ai does it (list_changed_check).
async function claudeToken(session) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = b64url(randomBytes(32));
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${site}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${session}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "mv", resource: `${site}/api/mcp` }),
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

// One conversation, as Claude: [shows] whether its client says, at
// initialize, that it shows a server's pages.
class Conversation {
  constructor(token, shows) {
    this.token = token;
    this.shows = shows;
    this.session = "";
    this.sent = 0;
  }
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
    const raw = await answer.text();
    const type = answer.headers.get("content-type") || "";
    let messages = [];
    if (type.startsWith("text/event-stream")) {
      for (const event of raw.split(/\r?\n\r?\n/)) {
        const data = event.split(/\r?\n/).filter((l) => l.startsWith("data:")).map((l) => l.slice(5).trim()).join("\n");
        if (data) messages.push(JSON.parse(data));
      }
    } else {
      try { messages = [JSON.parse(raw)]; } catch { messages = []; }
    }
    return messages.find((m) => m.id === this.sent) || { error: { message: `status ${answer.status}: ${raw.slice(0, 120)}` } };
  }
  async start() {
    const capabilities = this.shows ? { extensions: { [EXTENSION]: { mimeTypes: [MIME] } } } : {};
    const said = await this.ask("initialize", { protocolVersion: "2025-06-18", capabilities,
      clientInfo: { name: this.shows ? "model-view-check (shows pages)" : "model-view-check (text)", version: "1" } });
    // A notification: no id, and no answer.
    await fetch(`${site}/api/mcp`, {
      method: "POST",
      headers: { ...extra, "content-type": "application/json", accept: "application/json, text/event-stream",
        authorization: `Bearer ${this.token}`, ...(this.session ? { "mcp-session-id": this.session } : {}) },
      body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
    });
    return said;
  }
  call(name, input = {}) { return this.ask("tools/call", { name, arguments: input }); }
  // A call as a session makes it: one that became a job is followed with
  // job to its end (browser.mjs withJobs), and that answer is the call's.
  followed(name, input = {}) {
    return withJobs((method, params) => this.ask(method, params), { waits: 90 })("tools/call", { name, arguments: input });
  }
}

const texts = (answer) => ((answer.result || {}).content || []).filter((b) => b.type === "text").map((b) => b.text);
const images = (answer) => ((answer.result || {}).content || []).filter((b) => b.type === "image");
const shownOf = (answer) => ((answer.result || {})._meta || {})["brickworks/view"];
const kinds = (answer) => ((answer.result || {}).content || []).map((b) => b.type).join(",");
const jobOf = (answer) => ((answer.result || {})._meta || {})["brickworks/job"];
// The words a call's own answer says: not the relay's line naming the tab,
// nor the job's line saying which job it was.
const ownTexts = (answer) => texts(answer).filter((t) => !/^Tab \S+, /.test(t) && !/^Job \d+ \(\w+\) is done/.test(t));
const ownKinds = (answer) => ((answer.result || {}).content || [])
  .filter((b) => !(b.type === "text" && (/^Tab \S+, /.test(b.text) || /^Job \d+ \(\w+\) is done/.test(b.text))))
  .map((b) => b.type).join(",");

let browser = null;
let account = "";
try {
  console.log(`the model beside the call, at ${site}, as ${email}\n`);
  const signedIn = await mintSession(email);
  account = signedIn.kept.user_id;
  const token = await claudeToken(signedIn.access_token);

  console.log("1. the relay: what a host that shows pages is told");
  const viewer = new Conversation(token, true);
  const greeted = await viewer.start();
  const caps = (greeted.result || {}).capabilities || {};
  check(Boolean(caps.resources) && Boolean((caps.extensions || {})[EXTENSION]),
    `initialize says it serves resources and ${EXTENSION}: ${JSON.stringify(caps)}`);
  const listed = await viewer.ask("tools/list");
  const tools = (listed.result || {}).tools || [];
  const named = tools.filter((t) => t._meta && t._meta.ui && t._meta.ui.resourceUri === URI
    && t._meta["ui/resourceUri"] === URI).map((t) => t.name);
  check(SHOWN.every((n) => named.includes(n)) && named.length === SHOWN.length,
    `tools/list names the viewer (_meta.ui.resourceUri, and "ui/resourceUri") on ${named.join(", ") || "none"}`);
  const app = JSON.parse(readFileSync(new URL("../mcp_tools.json", import.meta.url), "utf8")).map((t) => t.name);
  const names = tools.map((t) => t.name);
  const onlyApp = tools.filter((t) => VIEWER_ONLY.includes(t.name));
  // The app's own count comes from tools/mcp_tools.json, which mcp_sync
  // holds to what the app serves; a number written here went stale when a
  // tool was added (47 → 48, colour_hidden_parts).
  check(app.length > 0 && names.length === app.length + 2 + VIEWER_ONLY.length && app.every((n) => names.includes(n))
      && names.includes("tabs") && names.includes("select_tab"),
    `...and the tools are the app's ${app.length}, the relay's tabs and select_tab, and the viewer's own: ${names.length}`);
  check(onlyApp.length === VIEWER_ONLY.length && onlyApp.every((t) => JSON.stringify(t._meta.ui.visibility) === '["app"]'
      && t._meta.ui.resourceUri === URI),
    `...which are for its page alone (_meta.ui.visibility ["app"]): ${onlyApp.map((t) => t.name).join(", ")}`);
  const resources = ((await viewer.ask("resources/list")).result || {}).resources || [];
  check(resources.some((r) => r.uri === URI && r.mimeType === MIME), `resources/list: ${resources.map((r) => `${r.uri} ${r.mimeType}`).join("; ") || "none"}`);
  const read = await viewer.ask("resources/read", { uri: URI });
  const page = (((read.result || {}).contents || [])[0]) || {};
  const html = String(page.text || "");
  check(page.uri === URI && page.mimeType === MIME && /^<!doctype html>/i.test(html),
    `resources/read gives the page: ${page.mimeType}, ${html.length} characters`);
  check(html.length > 0 && !/<(link|iframe)\b|\bsrc=["']?https?:|@import|url\(\s*["']?https?:/i.test(html),
    "...self-contained: no font, script, style or picture from anywhere, three.js and all inline");
  const csp = ((page._meta || {}).ui || {}).csp || {};
  check((csp.connectDomains || []).length === 1 && /^https:\/\/[^/]+$/.test(csp.connectDomains[0]) && !(csp.resourceDomains || []).length,
    `...and it declares the one origin it fetches from, the parts' geometry: ${JSON.stringify(csp)}`);
  const missing = await viewer.ask("resources/read", { uri: "ui://brickworks/nothing.html" });
  check(Boolean(missing.error), `an address that is not the viewer's is refused: ${missing.error?.message}`);
  if (!html) throw new Error("no page to show: the rest has nothing to load");
  // --relay-only: the relay's half, against tools/web/relay_server.mjs.
  if (args["relay-only"]) throw Object.assign(new Error("the relay alone, as asked"), { asked: true });

  console.log("\n2. a real tab answers: the session that shows pages, and one that does not");
  browser = await launch();
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
  await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: site });
  // Connect Claude opens claude.ai, stood in for here.
  await context.route(/^https:\/\/claude\.ai\//, (route) => route.fulfill({ status: 200, contentType: "text/html",
    body: "<!doctype html><title>claude.ai (stand-in)</title>" }));
  const tab = await context.newPage();
  await tab.goto(withBypass(url), { waitUntil: "domcontentloaded", timeout: 180000 });
  // The tab listening for Claude, switched on as a person does.
  async function listen(page) {
    const controls = () => page.evaluate(() => window.brickworksControls || {});
    const claudeState = () => page.evaluate(() => window.brickworksClaude || {});
    let on = false;
    for (let n = 0; n < 600 && !on; n++) {
      on = Boolean((await claudeState()).on);
      if (on) break;
      const at = (await controls()).connect_claude;
      if (at) {
        const opened = context.waitForEvent("page", { timeout: 30000 }).catch(() => null);
        await page.mouse.click(at.x, at.y);
        const claude = await opened;
        if (claude) await claude.close();
      } else if (n % 12 === 6) {
        await openColumnFor(page, "connect_claude");
      }
      await page.waitForTimeout(500);
    }
    return { on, status: (await claudeState()).status || "" };
  }
  const listened = await listen(tab);
  check(listened.on, `the account's tab is listening for Claude: "${listened.status}"`);

  // A small model: six parts, on bare ground.
  const design = { name: "Viewer check tower", bricks: [
    { part: "3001", color: 4, x: 10, y: 0, z: 10 }, { part: "3001", color: 1, x: 10, y: 3, z: 10 },
    { part: "3001", color: 14, x: 10, y: 6, z: 10 }, { part: "3003", color: 2, x: 10, y: 9, z: 10 },
    { part: "3003", color: 15, x: 10, y: 12, z: 10 }, { part: "3062b", color: 4, x: 10, y: 15, z: 10 },
  ] };
  // On bare ground, so what the tab opened with is not in the way. The
  // panel says it listens a moment before the relay has its hello.
  let cleared = await viewer.call("clear_model");
  for (let n = 0; n < 12 && /No Brickworks tab is open/.test(texts(cleared).join(" ")); n++) {
    await tab.waitForTimeout(5000);
    cleared = await viewer.call("clear_model");
  }
  check(!cleared.result?.isError && !shownOf(cleared), `clear_model first, which shows nothing: "${texts(cleared).slice(-1)[0]?.slice(0, 60)}"`);
  let t0 = Date.now();
  const built = await viewer.call("submit_design", design);
  const builtShown = shownOf(built) || {};
  check(!built.result?.isError && /Built\./.test(texts(built).join(" ")),
    `submit_design builds it, in ${Math.round((Date.now() - t0) / 1000)} s: "${texts(built).join(" ").replace(/\s+/g, " ").slice(0, 70)}"`);
  // The count the app itself states, which the viewer's must be.
  const looked = await viewer.call("look_at_model");
  const stated = Number((/(\d+) parts are on the baseplate/.exec(texts(looked).join(" ")) || [])[1]);
  check(builtShown.parts === stated && stated >= design.bricks.length,
    `...its answer's _meta carries the parts count, ${builtShown.parts}, as look_at_model states it (${stated})`);
  const turntable = (builtShown.views || []);
  const webp = (views) => views.every((v) => v.mimeType === "image/webp" && v.data.length > 1000);
  // The front corner, to show while the 3D comes; the rest of the turntable
  // only for a page that cannot draw in 3D, which asks (viewer_scene).
  check(turntable.length === 1 && turntable[0].from === "corner" && webp(turntable),
    `...and the front corner: ${turntable.map((v) => `${v.from} ${Math.round(v.data.length / 1024)}k`).join(", ")}`);
  check((builtShown.scene || {}).v === 1 && (builtShown.scene || {}).count >= stated && /^https:\/\//.test((builtShown.scene || {}).root),
    `...and the model packed for the page to draw in 3D: ${(builtShown.scene || {}).count} bricks, geometry from ${(builtShown.scene || {}).root}`);
  check(kinds(built).split(",").every((k) => k === "text") && !built.result?.structuredContent,
    `...while its content is words alone, as before, and there is no structuredContent (${kinds(built)})`);
  const lookedShown = shownOf(looked) || {};
  check(lookedShown.parts === stated && (lookedShown.scene || {}).of === (builtShown.scene || {}).of,
    `look_at_model carries the count and the same model packed, of ${(lookedShown.scene || {}).of}`);
  const carried = JSON.stringify(looked.result?._meta || {}).length;
  check(carried < 100000, `...in ${carried} characters, well inside the ~150,000 claude.ai keeps in a conversation`);
  // The whole turntable, asked for as a page that cannot draw in 3D asks.
  let asked = await viewer.call("viewer_scene", { views: true });
  for (let n = 0; n < 3 && ((asked.result?.structuredContent || {}).views || []).length < 4; n++) {
    asked = await viewer.call("viewer_scene", { views: true });
  }
  const whole = (asked.result?.structuredContent || {}).views || [];
  check(whole.length === 4 && webp(whole) && (asked.result?.structuredContent || {}).parts === stated,
    `viewer_scene, views: true, gives the count and the whole turntable: ${whole.map((v) => v.from).join(", ")}`);
  // A picture the tab cannot draw in 20 s comes back as letters (asked
  // again), or as a job, which is followed as a session follows it: its
  // answer is the call's own (4 below proves it).
  async function aPicture(conversation) {
    let answer = await conversation.followed("view_model", { from: "front" });
    for (let n = 0; n < 3 && images(answer).length === 0; n++) {
      console.log(`  (view_model came back without a picture: "${texts(answer).slice(-1)[0]?.slice(0, 60)}"; again)`);
      await tab.waitForTimeout(15000);
      answer = await conversation.followed("view_model", { from: "front" });
    }
    return answer;
  }
  const viewed = await aPicture(viewer);
  check(images(viewed).length === 1 && (shownOf(viewed) || {}).parts === stated
      && ((shownOf(viewed) || {}).views || []).length === 0,
    `view_model carries the count, and its own picture is the one shown (${kinds(viewed)})`);

  const plain = new Conversation(token, false);
  const plainGreeted = await plain.start();
  check(Boolean(plainGreeted.result?.serverInfo), "a client that does not show pages connects as before");
  const plainLooked = await plain.call("look_at_model");
  const plainViewed = await aPicture(plain);
  check(!shownOf(plainLooked) && !shownOf(plainViewed) && !plainLooked.result?.structuredContent,
    "...its answers carry nothing for a viewer");
  check(JSON.stringify(texts(plainLooked)) === JSON.stringify(texts(looked)),
    "...and look_at_model's words are the same, word for word");
  check(ownKinds(plainViewed) === ownKinds(viewed) && JSON.stringify(ownTexts(plainViewed)) === JSON.stringify(ownTexts(viewed))
      && images(plainViewed)[0]?.mimeType === images(viewed)[0]?.mimeType,
    `...and view_model's words and picture the same (${kinds(plainViewed)})`);
  await tab.screenshot({ path: `${out}/1_tab.png`, timeout: 120000 }).catch(() => {});

  console.log("\n3. a host, as the spec says one behaves, in a browser that cannot draw in 3D");
  const host = await browser.newPage({ viewport: { width: 760, height: 900 } });
  const refused = [];
  host.on("console", (m) => { if (/Content Security Policy|Refused to/i.test(m.text())) refused.push(m.text().slice(0, 200)); });
  // No WebGL in any frame of it: the page falls back to the turntable,
  // which it asks the tab for (viewer_scene, views) through this host.
  await host.addInitScript(() => {
    const given = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
      return /webgl/i.test(String(kind)) ? null : given.call(this, kind, ...rest);
    };
  });
  const calledByPage = [];
  await host.exposeFunction("relayCall", async (name, input) => {
    calledByPage.push(name);
    const answer = await viewer.call(name, input || {});
    return answer.result || { isError: true, content: [{ type: "text", text: answer.error?.message || "no answer" }] };
  });
  await host.setContent(`<!doctype html><html><head><style>
    body{margin:0;padding:24px;background:#262624;font:14px system-ui}
    body.light{background:#f5f4ed} iframe{display:block;width:100%;border:0;height:200px}
    </style></head><body><iframe id="app" sandbox="allow-scripts"></iframe><script>
    // The host's half (apps.mdx, "Lifecycle"): answer ui/initialize, and once
    // the page says it is initialized, send it the call's input and result.
    window.heard = [];
    window.show = (html, tool, input, result, theme, policy) => new Promise((done) => {
      const frame = document.getElementById("app");
      const toPage = (m) => frame.contentWindow.postMessage(m, "*");
      window.toPage = toPage;
      window.onmessage = (e) => {
        if (e.source !== frame.contentWindow) return;
        const m = e.data || {};
        window.heard.push(m.method || "answer");
        if (m.method === "ui/initialize") {
          toPage({ jsonrpc: "2.0", id: m.id, result: { protocolVersion: "2026-01-26",
            hostInfo: { name: "model-view-check", version: "1" }, hostCapabilities: { serverTools: {} },
            hostContext: { theme, displayMode: "inline", availableDisplayModes: ["inline"],
              toolInfo: { tool: { name: tool } } } } });
        } else if (m.method === "tools/call") {
          window.relayCall(m.params.name, m.params.arguments)
            .then((r) => toPage({ jsonrpc: "2.0", id: m.id, result: r }));
        } else if (m.method === "ui/notifications/initialized") {
          toPage({ jsonrpc: "2.0", method: "ui/notifications/tool-input", params: { arguments: input } });
          toPage({ jsonrpc: "2.0", method: "ui/notifications/tool-result", params: result });
          done(true);
        } else if (m.method === "ui/notifications/size-changed") {
          window.size = m.params;
          frame.style.height = m.params.height + "px";
        }
      };
      const meta = document.createElement("meta");
      meta.httpEquiv = "Content-Security-Policy";
      meta.content = policy;
      frame.srcdoc = html.replace(/<head>/i, "<head>" + meta.outerHTML);
    });
    </script></body></html>`);
  const inFrame = async () => host.frames().find((f) => f !== host.mainFrame());
  async function showIn(tool, input, answer, theme = "dark") {
    await host.evaluate(() => { window.size = null; window.heard = []; });
    const started = await Promise.race([
      host.evaluate(([h, t, i, r, th, p]) => window.show(h, t, i, r, th, p),
        [html, tool, input, answer.result, theme, policyOf(csp)]),
      new Promise((done) => setTimeout(() => done(false), 20000)),
    ]);
    const frame = await inFrame();
    // Until it is showing what it will show: a picture, and done asking.
    for (let n = 0; n < 240; n++) {
      await host.waitForTimeout(500);
      const settled = await frame.evaluate(() => !window.brickworksCard.fetching
        && document.getElementById("picture").naturalWidth > 0).catch(() => false);
      if (settled) break;
    }
    await host.waitForTimeout(800);
    const seen = await frame.evaluate(() => {
      const img = document.getElementById("picture");
      // Drawn, and whole: the picture's box inside the frame it is shown
      // in, so none of the model is cut off.
      const box = img.getBoundingClientRect();
      const frameBox = document.getElementById("stage").getBoundingClientRect();
      const whole = box.width > 50 && box.height > 50 && box.top >= frameBox.top - 1 && box.left >= frameBox.left - 1
        && box.bottom <= frameBox.bottom + 1 && box.right <= frameBox.right + 1;
      return { name: document.getElementById("name").textContent, parts: document.getElementById("parts").textContent,
        drawn: !img.hidden && img.complete && img.naturalWidth > 0 && whole, src: (img.src || "").slice(0, 22), alt: img.alt,
        views: document.querySelectorAll("#views button").length, where: document.getElementById("where").textContent,
        theme: document.documentElement.dataset.theme };
    });
    const sized = await host.evaluate(() => window.size);
    return { started, frame, seen, sized };
  }

  const one = await showIn("submit_design", design, built);
  check(one.started, "the page asks ui/initialize and says it is initialized; the host sends the input and the result");
  check(one.seen.drawn && one.seen.src.startsWith("data:image/webp"),
    `submit_design: the model's picture is drawn (${one.seen.src}…, "${one.seen.alt}")`);
  const count = `${stated.toLocaleString()} parts`;
  check(one.seen.parts === count && one.seen.name === design.name,
    `...with its name and parts count: "${one.seen.name}", "${one.seen.parts}"`);
  // The answer carries the front corner; a page that cannot draw in 3D
  // asks the tab, through the host, for the whole turntable, a button each.
  check(calledByPage.includes("viewer_scene") && one.seen.views === 4 && /^Front right$/.test(one.seen.where),
    `...as the turntable it asked the tab for (${calledByPage.join(", ") || "nothing asked"}): ${one.seen.views} views, "${one.seen.where}"`);
  check(Boolean(one.sized && one.sized.height > 150), `...and tells the host its size: ${JSON.stringify(one.sized)}`);
  await host.screenshot({ path: `${out}/2_submit_dark.png` });

  const whole3 = await showIn("look_at_model", {}, looked);
  check(whole3.seen.drawn && whole3.seen.views === 4 && whole3.seen.parts === count && /Front right/.test(whole3.seen.where),
    `look_at_model: the whole turntable and the count, "${whole3.seen.parts}", "${whole3.seen.where}"`);
  // Watched, not sampled once: a slow screenshot can let it come round again.
  let moved = whole3.seen.where;
  for (let n = 0; n < 20 && moved === whole3.seen.where; n++) {
    await host.waitForTimeout(200);
    moved = await whole3.frame.evaluate(() => document.getElementById("where").textContent);
  }
  check(moved !== whole3.seen.where, `...which turns by itself: "${whole3.seen.where}", then "${moved}"`);

  // Still, as for a person who asks for less motion: what follows is the keys.
  await host.emulateMedia({ reducedMotion: "reduce" });
  const three = await showIn("look_at_model", {}, looked);
  await host.waitForTimeout(2000);
  const still = await three.frame.evaluate(() => document.getElementById("where").textContent);
  check(three.seen.where === "Front right" && still === "Front right",
    `asked for less motion, it stays still: "${three.seen.where}", 2 s later "${still}"`);
  await three.frame.focus("#stage");
  await three.frame.press("#stage", "ArrowRight");
  await host.waitForTimeout(300);
  const turned = await three.frame.evaluate(() => ({ where: document.getElementById("where").textContent,
    drawn: document.getElementById("picture").naturalWidth > 0 }));
  check(/Back right/.test(turned.where) && turned.drawn, `the arrow key turns it a quarter: "${turned.where}"`);
  await host.screenshot({ path: `${out}/3_look_dark.png` });
  await host.evaluate(() => { document.body.classList.add("light"); window.toPage({ jsonrpc: "2.0",
    method: "ui/notifications/host-context-changed", params: { theme: "light" } }); });
  await host.waitForTimeout(500);
  const light = await three.frame.evaluate(() => document.documentElement.dataset.theme);
  check(light === "light", `the host turns light, and so does the page: ${light}`);
  await host.screenshot({ path: `${out}/4_look_light.png` });
  await host.evaluate(() => document.body.classList.remove("light"));

  const two = await showIn("view_model", { from: "front" }, viewed);
  check(two.seen.drawn && two.seen.src.startsWith("data:image/png") && two.seen.parts === count
      && /From the front/.test(two.seen.where),
    `view_model: its own picture, and the count: "${two.seen.where}", "${two.seen.parts}"`);
  await host.screenshot({ path: `${out}/5_view_model.png` });

  console.log("\n4. every call a job, in a second tab (/app?jobs-after=0): the job's answer is the call's own");
  const jobTab = await context.newPage();
  await jobTab.goto(withBypass(`${url}&jobs-after=0`), { waitUntil: "domcontentloaded", timeout: 180000 });
  const jobListened = await listen(jobTab);
  check(jobListened.on, `the second tab is listening too: "${jobListened.status}"`);
  const first = String((looked.result?._meta || {})["brickworks/tab"] || "");
  let target = "";
  for (let n = 0; n < 24 && !target; n++) {
    const open = texts(await viewer.call("tabs")).join("\n");
    target = ([...open.matchAll(/^- ([a-z2-9]{4,12}): /gm)].map((m) => m[1]).find((id) => id !== first)) || "";
    if (!target) await jobTab.waitForTimeout(5000);
  }
  check(Boolean(target) && Boolean(first), `tabs names it beside the first: ${target} (the first ${first})`);
  // Started, and its _meta says which job; then one call of job, once it is
  // done, gives the call's answer.
  async function asJob(conversation, name, input) {
    const started = await conversation.call(name, { ...input, target });
    const id = Number((/Started job (\d+)/.exec(texts(started).join(" ")) || [])[1] || 0);
    let done = started;
    for (let n = 0; n < 90 && id; n++) {
      done = await conversation.call("job", { id, target });
      if (!/ is still going/.test(texts(done).join(" "))) break;
    }
    return { started, id, done };
  }
  await asJob(viewer, "clear_model", {});
  const jobBuilt = await asJob(viewer, "submit_design", design);
  check(jobBuilt.id > 0 && (jobOf(jobBuilt.started) || {}).id === jobBuilt.id && !shownOf(jobBuilt.started),
    `submit_design answers "Started job ${jobBuilt.id}", its _meta saying which (${JSON.stringify(jobOf(jobBuilt.started))}) and carrying no model yet`);
  const builtJob = shownOf(jobBuilt.done) || {};
  check(/is done/.test(texts(jobBuilt.done).join(" ")) && /Built\./.test(texts(jobBuilt.done).join(" "))
      && builtJob.parts === stated && (builtJob.views || []).length === 1 && (builtJob.views || [])[0]?.from === "corner"
      && (builtJob.scene || {}).count === (builtShown.scene || {}).count && (jobOf(jobBuilt.done) || {}).done === true,
    `...and job, once done, gives its answer with the _meta it would have carried at once: ${builtJob.parts} parts, `
      + `${(builtJob.views || []).map((v) => v.from).join(",")}, ${(builtJob.scene || {}).count} bricks packed`);
  const jobViewed = await asJob(viewer, "view_model", { from: "front" });
  const viewedJob = shownOf(jobViewed.done) || {};
  check(jobViewed.id > 0 && images(jobViewed.done).length === 1 && images(jobViewed.done)[0].data.length > 1000,
    `view_model as job ${jobViewed.id}: one call of job once it is done gives the picture (${kinds(jobViewed.done)})`);
  check(ownKinds(jobViewed.done) === ownKinds(viewed) && JSON.stringify(ownTexts(jobViewed.done)) === JSON.stringify(ownTexts(viewed))
      && images(jobViewed.done)[0]?.mimeType === images(viewed)[0]?.mimeType,
    `...the words and picture view_model answered with at once, block for block (${ownKinds(jobViewed.done)})`);
  check(viewedJob.parts === stated && (viewedJob.views || []).length === 0 && (viewedJob.scene || {}).count >= stated,
    `...and the _meta it carried at once: ${viewedJob.parts} parts, the model packed, its own picture the one shown`);
  const plainJob = await asJob(plain, "view_model", { from: "front" });
  check(plainJob.id > 0 && !shownOf(plainJob.done) && !jobOf(plainJob.done) && !jobOf(plainJob.started)
      && ownKinds(plainJob.done) === ownKinds(jobViewed.done)
      && JSON.stringify(ownTexts(plainJob.done)) === JSON.stringify(ownTexts(jobViewed.done)),
    `a client that does not show pages: the same words and picture as a job, and no _meta (${kinds(plainJob.done)})`);
  // The card beside the call that became a job: handed "Started job N", it
  // follows the job through the host and shows the picture it gave.
  const pageCalls = calledByPage.length;
  const followedCard = await showIn("view_model", { from: "front" }, jobViewed.started);
  const followedBy = await followedCard.frame.evaluate(() => ({ job: window.brickworksCard.job, followed: window.brickworksCard.followed }));
  check(followedCard.seen.drawn && followedCard.seen.src.startsWith("data:image/png") && followedCard.seen.parts === count
      && followedBy.followed === jobViewed.id && calledByPage.slice(pageCalls).includes("job"),
    `the card beside the call that became job ${jobViewed.id} follows it (${calledByPage.slice(pageCalls).join(", ")}) and shows its picture: `
      + `"${followedCard.seen.where}", "${followedCard.seen.parts}"`);
  await host.screenshot({ path: `${out}/6_view_model_job.png` });
  await jobTab.close();
  check(refused.length === 0, `the policy built from what the page declares refused nothing${refused.length ? `: ${refused[0]}` : ""}`);
} catch (trouble) {
  if (!trouble.asked) check(false, `stopped: ${trouble.message}`);
} finally {
  if (browser) await browser.close().catch(() => {});
  const gone = await dropAccount(account).catch(() => false);
  console.log(`\nthe throwaway account ${gone ? "deleted" : "NOT deleted"}`);
}
console.log(failures ? `${failures} failure(s)` : "Claude is shown the model, and every other client what it saw before");
process.exit(failures ? 1 : 0);
