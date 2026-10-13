// Does a Claude conversation hear that Brickworks' tools have changed?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 &
//   node tools/web/list_changed_check.mjs --url=http://127.0.0.1:8790
//   BW_BYPASS=… node tools/web/list_changed_check.mjs --url=<a preview>
//
// A conversation lists a connector's tools once, when it connects, and
// goes on with that list. After a deploy, a tab reloaded into the newer
// build says hello to the relay again (api/mcp.js) with the newer build's
// tools — and every conversation went on with the old list, because the
// relay said listChanged: false and never said otherwise.
//
// Now the relay says listChanged: true, and remembers which list each
// conversation was given. The first time a conversation calls after the
// tab it works in has said hello with another list, the answer comes as an
// event stream, notifications/tools/list_changed ahead of it — which a
// client that supports it answers by listing the tools again — and only
// that once. A client that takes JSON alone has no stream to be told in, so
// it is told in words, at the end of the call's answer.
//
// Played here from both ends, as a tab and as Claude do it, both ways in:
// a tab's own address (?t=), and the one address Claude signs in to with
// OAuth. The tab is a throwaway account's, deleted at the end. Before
// 2026-10-13 the relay answered every call in plain JSON and initialize
// with listChanged: false, so the checks marked * failed.
import { createHash, randomBytes } from "node:crypto";
import { mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:8790").replace(/\/+$/, "");
const bypass = args.bypass || process.env.BW_BYPASS || "";
const extra = bypass ? { "x-vercel-protection-bypass": bypass } : {};

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const CHANGED = "notifications/tools/list_changed";

// The tools a build serves: one, then a newer build's two, then three.
const tool = (name, description) => ({ name, description, inputSchema: { type: "object", properties: {} } });
const BUILDS = [
  [tool("look_at_model", "What is on the baseplate.")],
  [tool("look_at_model", "What is on the baseplate."), tool("newer_tool", "Only the newer build has it.")],
  [tool("look_at_model", "What is on the baseplate."), tool("newer_tool", "Only the newer build has it."),
    tool("newest_tool", "And the one after.")],
];

// The tab: says hello with a build's tools, and answers each call with
// which build it is.
class Tab {
  constructor(session, id) {
    this.session = session;
    this.token = b64url(randomBytes(32));
    this.id = id;
    this.build = 0;
    this.instance = "";
    this.stopped = false;
    this.answering = null;
  }
  address(op) {
    return `${base}/api/mcp?t=${this.token}&i=${this.instance}&tab=${this.id}${op ? `&op=${op}` : ""}`;
  }
  async hello(build) {
    this.build = build;
    // Each build is a page load of its own, as a reload is.
    this.instance = `lc${b64url(randomBytes(9))}`;
    const answer = await fetch(this.address("hello"), {
      method: "POST",
      headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${this.session}` },
      body: JSON.stringify({ instructions: `build ${build}`, tools: BUILDS[build], model: "List Check" }),
    });
    if (!this.answering) this.answering = this.answer();
    return answer.status;
  }
  async answer() {
    while (!this.stopped) {
      const asked = await fetch(this.address("next"), { method: "POST", headers: extra }).catch(() => null);
      if (!asked || asked.status !== 200) {
        if (asked && asked.status !== 204) await new Promise((done) => setTimeout(done, 500));
        continue;
      }
      const { id, request } = await asked.json();
      if (request.id === undefined || request.id === null) continue;
      await fetch(`${this.address("answer")}&id=${id}`, {
        method: "POST",
        headers: { ...extra, "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: request.id,
          result: { content: [{ type: "text", text: `answered by build ${this.build}` }] } }),
      });
    }
  }
  async close() {
    this.stopped = true;
    await fetch(this.address("close"), { method: "POST", headers: extra }).catch(() => {});
  }
}

// Claude: one conversation, by the way in it was given and the session id
// it was handed. [stream]: whether it takes an event stream, as the spec
// asks every client to, or JSON alone.
class Claude {
  constructor(path, auth, stream = true) {
    this.path = path;
    this.auth = auth;
    this.stream = stream;
    this.session = "";
    this.sent = 0;
  }
  // Every message of the answer, in order, and how it came.
  async ask(method, params = {}) {
    const answer = await fetch(`${base}${this.path}`, {
      method: "POST",
      headers: { ...extra, "content-type": "application/json",
        accept: this.stream ? "application/json, text/event-stream" : "application/json",
        ...(this.auth ? { authorization: `Bearer ${this.auth}` } : {}),
        ...(this.session ? { "mcp-session-id": this.session } : {}) },
      body: JSON.stringify({ jsonrpc: "2.0", id: ++this.sent, method, params }),
    });
    const given = answer.headers.get("mcp-session-id");
    if (given && !this.session) this.session = given;
    const type = answer.headers.get("content-type") || "";
    const raw = await answer.text();
    let messages = [];
    if (type.startsWith("text/event-stream")) {
      for (const event of raw.split(/\r?\n\r?\n/)) {
        const data = event.split(/\r?\n/).filter((l) => l.startsWith("data:")).map((l) => l.slice(5).trim()).join("\n");
        if (data) messages.push(JSON.parse(data));
      }
    } else {
      try { messages = [JSON.parse(raw)]; } catch {}
    }
    const reply = messages.find((m) => m.id === this.sent) || {};
    const text = ((reply.result || {}).content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
    return { status: answer.status, type, messages, reply, text,
      told: messages.findIndex((m) => m.method === CHANGED) };
  }
  call(name) { return this.ask("tools/call", { name, arguments: {} }); }
  async start() {
    const said = await this.ask("initialize", { protocolVersion: "2025-06-18", capabilities: {},
      clientInfo: { name: "list-changed-check", version: "1" } });
    await this.ask("notifications/initialized");
    return said;
  }
}
const names = (said) => ((said.reply.result || {}).tools || []).map((t) => t.name);

// Claude's sign-in to the account, as claude.ai does it.
async function claudeToken(session) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = b64url(randomBytes(32));
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${base}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${session}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "lc", resource: `${base}/api/mcp` }),
  })).json();
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) throw new Error(`no code: ${JSON.stringify(yes)}`);
  const tokens = await (await fetch(`${base}/oauth/token`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back,
      client_id: client, code_verifier: verifier, resource: `${base}/api/mcp` }).toString(),
  })).json();
  return tokens.access_token || "";
}

// One way in: a conversation lists the tools and calls; the tab reloads
// into a newer build; the conversation's next call is told, once.
async function wayIn(label, tab, claude, jsonOnly) {
  console.log(`\n${label}`);
  check(`the tab says hello with its build's tools: ${await tab.hello(0)}`, true);
  const started = await claude.start();
  const caps = ((started.reply.result || {}).capabilities || {}).tools || {};
  check(`* initialize says the tool list can change (listChanged: ${caps.listChanged})`, caps.listChanged === true);
  check(`initialize hands out a session id: ${claude.session.slice(0, 8) || "none"}…`, claude.session.length >= 16);
  const listed = await claude.ask("tools/list");
  check(`tools/list: ${names(listed).join(", ")}`, names(listed).includes("look_at_model") && !names(listed).includes("newer_tool"));
  const first = await claude.call("look_at_model");
  check(`a call is answered by the tab, with nothing said about the tools: "${first.text.split("\n").pop()}"`,
    first.text.includes("answered by build 0") && first.told < 0);

  check(`the tab reloads into a newer build and says hello with its tools: ${await tab.hello(1)}`, true);
  const next = await claude.call("look_at_model");
  check(`* the next call is told the tools changed, ahead of its answer, as an event stream (${next.type.split(";")[0]})`,
    next.told === 0 && next.type.startsWith("text/event-stream") && next.messages.length === 2);
  check(`...and answered by the newer build: "${next.text.split("\n").pop()}"`, next.text.includes("answered by build 1"));
  const again = await claude.call("look_at_model");
  check("...once: the call after is not told again", again.told < 0 && !again.type.startsWith("text/event-stream"));
  const relisted = await claude.ask("tools/list");
  check(`listed again, the tools are the newer build's: ${names(relisted).join(", ")}`, names(relisted).includes("newer_tool"));
  const after = await claude.call("look_at_model");
  check("...and the call after that is told nothing", after.told < 0);

  // A client that takes only JSON.
  const plain = jsonOnly;
  await plain.start();
  await plain.ask("tools/list");
  check(`a client that takes JSON alone lists the newer build's tools too`, true);
  await tab.hello(2);
  const worded = await plain.call("look_at_model");
  check(`* after the next reload it is answered in JSON, told in words: "${worded.text.split("\n").pop().slice(0, 110)}…"`,
    worded.told < 0 && worded.type.startsWith("application/json") && /tools have changed/i.test(worded.text));
  const quiet = await plain.call("look_at_model");
  check("...once", !/tools have changed/i.test(quiet.text));
  // And the conversation that took the stream hears of the third build too.
  const third = await claude.call("look_at_model");
  check("the first conversation is told of that build too", third.told === 0);
  await tab.close();
}

const email = `delivered+bwlistcheck${randomBytes(3).toString("hex")}@resend.dev`;
const minted = await mintSession(email);
console.log(`Claude hearing that the tools changed, at ${base}`);
try {
  const own = new Tab(minted.access_token, "lcone");
  await wayIn("a tab's own address (?t=)", own,
    new Claude(`/api/mcp?t=${own.token}`, ""), new Claude(`/api/mcp?t=${own.token}`, "", false));
  let token = "";
  try { token = await claudeToken(minted.access_token); } catch (trouble) { console.log(`  (${trouble.message})`); }
  check("Claude signs in to the account with OAuth", token.startsWith("bwa_"));
  const signed = new Tab(minted.access_token, "lctwo");
  await wayIn("the account's address, signed in with OAuth", signed,
    new Claude("/api/mcp", token), new Claude("/api/mcp", token, false));
} finally {
  const p = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const gone = minted.kept.user_id && p && secret ? await fetch(`${p}/auth/v1/admin/users/${minted.kept.user_id}`, {
    method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` } }).then((r) => r.ok).catch(() => false) : false;
  console.log(`\n  (the throwaway account ${gone ? "deleted" : "NOT deleted"})`);
}
console.log(failed ? `\n${failed} failed` : "\nevery conversation is told, once, when the tab it works in serves other tools");
process.exit(failed ? 1 : 0);
