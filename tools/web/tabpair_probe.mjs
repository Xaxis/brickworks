// Two chats, two tabs, at the relay alone: the rules of api/mcp.js's "Two
// chats, two tabs", with two stand-in tabs and two MCP sessions, in seconds.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8831 &
//   node tools/web/tabpair_probe.mjs --url=http://127.0.0.1:8831
//   BW_BYPASS=… node tools/web/tabpair_probe.mjs --url=<a preview>
//
// The tabs here are the relay's side of a tab only (op=hello, op=next,
// op=answer, op=chats, op=keep), answering every call by naming themselves;
// tools/web/tabpair_flow.mjs proves the same with the app in two browser
// tabs. Signs in as a throwaway account, deleted at the end.
//
//   1. With two tabs open, a new chat that names none is stopped before its
//      first change, nothing reaching either tab, and shown both; a look
//      goes ahead in the most recent tab and says so, binding nothing.
//   2. select_tab by the model's name ("the castle tab") binds it; a second
//      chat's target by id binds it to the other; each builds in its own.
//   3. A third chat in a held tab: the list says which chat holds it; it
//      chooses it anyway, both are working there, the tab hears both
//      (brickworks/chats); the tab keeps one, and the other's next call is
//      told it was moved off and does nothing.
//   4. A name two tabs share is not guessed: both are listed.
//   5. Two chats on one connection, each naming its tab on every call.
//   6. A resumed chat, which Claude Code makes a new session (2026-10-19):
//      it chooses again, told plainly that it is a new chat here and cannot
//      undo what it did before; the account's first chat is not told that.
//      And Claude Code's first request, server/discover, is answered by the
//      relay ("method not found"), no tab asked.
import { createHash, randomBytes } from "node:crypto";
import { mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const origin = String(args.url || "http://127.0.0.1:8831").replace(/\/+$/, "");
const bypass = args.bypass || process.env.BW_BYPASS || "";
const extra = bypass ? { "x-vercel-protection-bypass": bypass } : {};

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const wait = (ms) => new Promise((done) => setTimeout(done, ms));

const EMAIL = `delivered+bwtabpair${randomBytes(3).toString("hex")}@resend.dev`;
const minted = await mintSession(EMAIL);

// Claude's sign-in to the account, as claude.ai does it (tabs_flow.mjs).
async function claudeToken() {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${origin}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${minted.access_token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "tabpair",
      resource: `${origin}/api/mcp` }),
  })).json();
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) throw new Error(`no code: ${JSON.stringify(yes)}`);
  const tokens = await (await fetch(`${origin}/oauth/token`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back,
      client_id: client, code_verifier: verifier, resource: `${origin}/api/mcp` }).toString(),
  })).json();
  return tokens.access_token || "";
}

// A stand-in tab: says hello signed in, answers each call by naming itself
// and what it did, and keeps what the relay tells it.
class Tab {
  constructor(id, model) {
    this.id = id;
    this.model = model;
    this.token = randomBytes(32).toString("base64url");
    this.instance = randomBytes(8).toString("hex");
    this.did = [];
    this.told = [];
    this.metas = [];
    this.on = true;
  }
  url(op, more = "") {
    return `${origin}/api/mcp?t=${this.token}&i=${this.instance}&op=${op}${more}`;
  }
  async hello() {
    const tools = [
      { name: "look_at_model", description: "look", inputSchema: { type: "object", properties: {} },
        annotations: { title: "List what is built", readOnlyHint: true } },
      { name: "edit_model", description: "edit", inputSchema: { type: "object", properties: {} },
        annotations: { title: "Edit the model", readOnlyHint: false, destructiveHint: true } },
    ];
    const said = await fetch(this.url("hello", `&tab=${this.id}&used=5`), {
      method: "POST",
      headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${minted.access_token}` },
      body: JSON.stringify({ instructions: "stand-in", tools, model: this.model }),
    });
    return said.status;
  }
  async listen() {
    while (this.on) {
      let got;
      try {
        got = await fetch(this.url("next", `&used=5&model=${encodeURIComponent(this.model)}`),
          { method: "POST", headers: extra });
      } catch {
        await wait(500);
        continue;
      }
      if (got.status !== 200) {
        if (got.status !== 204) await wait(500);
        continue;
      }
      const { id, request } = await got.json();
      if (request.id === undefined || request.id === null) {
        this.told.push(request);
        continue;
      }
      const name = request.params?.name || request.method;
      this.did.push(name);
      this.metas.push(request.params?._meta || {});
      await fetch(this.url("answer", `&id=${id}`), {
        method: "POST",
        headers: { ...extra, "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: request.id, result: {
          content: [{ type: "text", text: `${this.id} did ${name}` }],
          _meta: { "brickworks/tab": this.id, "brickworks/model": this.model } } }),
      });
    }
  }
  async ask(op, more = "") {
    const got = await fetch(this.url(op, more), { method: "POST", headers: extra });
    return [got.status, await got.json().catch(() => ({}))];
  }
  async close() {
    this.on = false;
    await fetch(this.url("close"), { method: "POST", headers: extra });
  }
}

let sent = 0;
async function mcp(token, session, method, params) {
  const answer = await fetch(`${origin}/api/mcp`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", accept: "application/json",
      authorization: `Bearer ${token}`, ...(session ? { "mcp-session-id": session } : {}) },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++sent, method, params }),
  });
  const raw = await answer.text();
  let body = {};
  try { body = JSON.parse(raw); } catch {}
  return [answer.status, body, answer.headers.get("mcp-session-id") || ""];
}
async function chat(token) {
  const [, , session] = await mcp(token, "", "initialize", { protocolVersion: "2025-06-18",
    capabilities: {}, clientInfo: { name: "tabpair-probe", version: "1" } });
  return {
    session,
    async call(name, args = {}) {
      const [, body] = await mcp(token, session, "tools/call", { name, arguments: args });
      const result = body.result || {};
      return { words: (result.content || []).map((b) => b.text || "").join("\n"), error: Boolean(result.isError) };
    },
  };
}
const first = (words) => words.split("\n")[0].slice(0, 160);
// What a chat's first choice says when the account has other chats (api/mcp.js RESUMED).
const RESUMED = "If this chat was resumed from an earlier one, Brickworks counts it as a new chat";

// An id as a tab makes one (TabSession.LETTERS): no i, l, o, 0 or 1.
const LETTERS = "abcdefghjkmnpqrstuvwxyz23456789";
const fresh = (lead) => lead + [...randomBytes(4)].map((n) => LETTERS[n % LETTERS.length]).join("");
const castle = new Tab(fresh("c"), "Castle");
const truck = new Tab(fresh("t"), "Fire Truck");
const tabs = [castle, truck];
for (const tab of tabs) check(`tab ${tab.id} (“${tab.model}”) says hello signed in`, (await tab.hello()) === 204);
const loops = tabs.map((tab) => tab.listen());
const token = await claudeToken();
check("Claude signs in to the account", token.startsWith("bwa_"));
await wait(1500);

console.log("\n1. a new chat with two tabs open and none chosen");
const a = await chat(token);
const before = tabs.map((t) => t.did.length);
const stopped = await a.call("edit_model", { add: [] });
console.log(`        ${stopped.words.split("\n").join("\n        ")}`);
check("its first change does nothing and says so", stopped.error && stopped.words.startsWith("Nothing was done"));
check("...and, the account's first chat, is not told about resumed chats", !stopped.words.includes("resumed"));
check("...lists both tabs by id and model", stopped.words.includes(`${castle.id}: “Castle”`)
  && stopped.words.includes(`${truck.id}: “Fire Truck”`));
check("...and says how to choose", stopped.words.includes("select_tab"));
await wait(500);
check("...and neither tab was asked anything", tabs.every((t, n) => t.did.length === before[n]));
const look = await a.call("look_at_model");
check(`a look goes ahead in one tab and says so: "${first(look.words)}"`,
  !look.error && /this look was made in/.test(look.words) && / did look_at_model/.test(look.words));
const again = await a.call("edit_model", { add: [] });
check("...and binds nothing: the next change is still stopped", again.error && again.words.startsWith("Nothing was done"));

console.log("\n2. chosen by name, and by target");
const chose = await a.call("select_tab", { tab: "the castle tab" });
check(`select_tab "the castle tab": "${first(chose.words)}"`, !chose.error
  && chose.words.includes(`go to tab ${castle.id} now`) && !chose.words.includes("resumed"));
const built = await a.call("edit_model", { add: [] });
check(`chat A's change lands in the castle: "${first(built.words)}"`,
  !built.error && built.words.startsWith(`Tab ${castle.id}, “Castle”.`) && built.words.includes(`${castle.id} did edit_model`));
const b = await chat(token);
const listed = await b.call("tabs");
console.log(`        ${listed.words.split("\n").join("\n        ")}`);
check("chat B's tabs says another chat works in the castle",
  listed.words.split("\n").some((l) => l.startsWith(`- ${castle.id}`) && l.includes("another chat has been working in it")));
const byId = await b.call("edit_model", { add: [], target: truck.id });
check(`chat B's change targeted at ${truck.id} lands in the truck: "${first(byId.words)}"`,
  !byId.error && byId.words.startsWith(`Tab ${truck.id}, “Fire Truck”.`));
check("...told, as its first choice with another chat's about, what a resumed chat is here",
  byId.words.includes(RESUMED));
const bAgain = await b.call("edit_model", { add: [] });
check("...and binds it: its next change, untargeted, goes there too",
  !bAgain.error && bAgain.words.startsWith(`Tab ${truck.id}`));
check("...and is not told again", !bAgain.words.includes("resumed"));
const aAgain = await a.call("edit_model", { add: [] });
check("chat A, untargeted, still builds in the castle", aAgain.words.startsWith(`Tab ${castle.id}`));
const meta = castle.metas[castle.metas.length - 1]["brickworks/chat"] || {};
check(`the castle's calls carry chat A's name for the tab: ${JSON.stringify(meta)}`, /^[0-9a-f]{8}$/.test(meta.chat || ""));

console.log("\n3. a second chat in a held tab, and keeping one");
const c = await chat(token);
const intoHeld = await c.call("select_tab", { tab: "castle" });
check(`chat C chooses the castle anyway, and is told another chat works there: "${intoHeld.words.slice(0, 200)}"`,
  intoHeld.words.includes("Careful: another chat has been working in it"));
await wait(2500);
const [, inCastle] = await castle.ask("chats");
check(`the castle tab hears two chats working in it: ${(inCastle.chats || []).map((x) => x.chat).join(", ")}`,
  (inCastle.chats || []).length === 2);
const toldChats = castle.told.filter((r) => r.method === "brickworks/chats");
check(`...and was told so as it happened (${toldChats.length} brickworks/chats)`,
  toldChats.length > 0 && (toldChats[toldChats.length - 1].params.chats || []).length === 2);
const keepA = meta.chat;
const [kept, after] = await castle.ask("keep", `&chat=${keepA}`);
check(`the tab keeps chat A: ${kept}, moved ${after.moved}, ${(after.chats || []).length} left`,
  kept === 200 && after.moved === 1 && (after.chats || []).length === 1 && after.chats[0].chat === keepA);
const castleDid = castle.did.length;
const moved = await c.call("edit_model", { add: [] });
console.log(`        ${moved.words.split("\n").join("\n        ")}`);
check("chat C's next call is told it was moved off, nothing done",
  moved.error && moved.words.startsWith(`The person moved this chat off tab ${castle.id}`));
const movedAgain = await c.call("look_at_model");
check("...and so is the one after, until it chooses", movedAgain.error && movedAgain.words.includes("moved this chat off"));
await wait(500);
check("...and the castle was asked nothing", castle.did.length === castleDid);
const aStill = await a.call("edit_model", { add: [] });
check("chat A builds on in the castle", !aStill.error && aStill.words.startsWith(`Tab ${castle.id}`)
  && !aStill.words.includes("Careful"));

console.log("\n4. a name two tabs share");
const fort = new Tab(fresh("f"), "Castle Gate");
check(`a third tab, “${fort.model}”, says hello`, (await fort.hello()) === 204);
const fortLoop = fort.listen();
await wait(1500);
const d = await chat(token);
const vague = await d.call("select_tab", { tab: "cast" });
check(`select_tab "cast" matches two and chooses neither: "${first(vague.words)}"`,
  vague.error && vague.words.startsWith("2 open tabs match"));
const exact = await d.call("select_tab", { tab: "Castle" });
check(`select_tab "Castle" takes the exact name: "${exact.words.split("\n").pop().slice(0, 120)}"`,
  !exact.error && exact.words.includes(`go to tab ${castle.id} now`));

console.log("\n5. two chats on one connection, as claude.ai is reported to share one");
// One Mcp-Session-Id, two conversations: nothing tells them apart here, so
// each names its tab on every call, as select_tab's answer asks.
const shared = await chat(token);
const told = await shared.call("select_tab", { tab: castle.id });
check(`select_tab asks for target on every call while tabs are open: "${(told.words.match(/[^.]*pass target[^.]*/) || [""])[0].trim().slice(0, 110)}"`,
  told.words.includes(`pass target: "${castle.id}" on every call`));
await shared.call("select_tab", { tab: truck.id });
const castleNow = castle.did.length;
const truckNow = truck.did.length;
const x = await shared.call("edit_model", { add: [], target: castle.id });
const y = await shared.call("edit_model", { add: [], target: truck.id });
check("each conversation's targeted change lands in its own tab, the shared pick notwithstanding",
  x.words.startsWith(`Tab ${castle.id}`) && y.words.startsWith(`Tab ${truck.id}`)
  && castle.did.length === castleNow + 1 && truck.did.length === truckNow + 1);

console.log("\n6. a resumed chat, and Claude Code's first request");
// Claude Code, resuming a chat, discovers and initializes again: a new
// session, and nothing that says it is chat A (measured, 2.1.303).
const asked = [...tabs, fort].map((t) => t.did.length);
const [discovered, discovery] = await mcp(token, "", "server/discover", { _meta: {
  "io.modelcontextprotocol/protocolVersion": "2026-07-28",
  "io.modelcontextprotocol/clientInfo": { name: "claude-code", version: "2.1.303" } } });
check(`server/discover is answered by the relay: ${discovered} ${JSON.stringify(discovery.error || discovery.result || {})}`,
  discovered === 200 && discovery.error && discovery.error.code === -32601);
const resumed = await chat(token);
const resumedStopped = await resumed.call("edit_model", { add: [] });
check(`a resumed chat is a new one: its first change waits for a tab, told why: "${resumedStopped.words.split(". ").pop()}"`,
  resumedStopped.error && resumedStopped.words.startsWith("Nothing was done") && resumedStopped.words.includes(RESUMED));
const resumedChose = await resumed.call("select_tab", { tab: truck.id });
check("...and its choice says it cannot undo what it did before the resume",
  !resumedChose.error && resumedChose.words.includes(`go to tab ${truck.id} now`) && resumedChose.words.includes(RESUMED));
await wait(500);
check(`...no tab asked server/discover (${[...tabs, fort].map((t) => t.did.filter((n) => n === "server/discover").length).join(", ")})`,
  [...tabs, fort].every((t, n) => !t.did.slice(asked[n]).includes("server/discover")));

for (const tab of [...tabs, fort]) await tab.close();
await Promise.race([Promise.all([...loops, fortLoop]), wait(30000)]);
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
console.log(failed ? `\n${failed} failed` : "\ntwo chats, two tabs: each chat in its own, a new one stopped before a change, one kept");
process.exit(failed ? 1 : 0);
