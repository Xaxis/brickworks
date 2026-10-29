// How long a call through the connector relay (api/mcp.js) takes, from
// Claude's side, when the tab answers at once: the relay's own cost.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 &
//   node tools/web/relay_timing.mjs --url=http://127.0.0.1:8790 [--rounds=4]
//   BW_BYPASS=… node tools/web/relay_timing.mjs --url=<a preview> [--rounds=4]
//
// A measure with no verdict (preview_checks.sh says so). One throwaway
// account, deleted at the end; one stand-in tab of it (the relay's side of a
// tab only, tabpair_probe.mjs's kind) that says hello with the app's own tool
// list (tools/mcp_tools.json, a quarter of a megabyte, as a real tab's is)
// and answers every call the moment it has it; and Claude signed in with
// OAuth, in one conversation, making the same calls each round: tabs (the
// relay answers it alone), search_parts and look_at_model (fast in the
// app), edit_model. Prints the median and the 90th percentile of each, in
// milliseconds.
//
// 2026-10-29 (relay338), the local relay on this machine, about 150 ms from
// Supabase: a call took 2.6-2.7 s at the median before, of which the tab's
// own work was nothing; tabs 0.63 s.
import { createHash, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import { mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const origin = String(args.url || "http://127.0.0.1:8790").replace(/\/+$/, "");
const rounds = Number(args.rounds || 4);
const bypass = args.bypass || process.env.BW_BYPASS || "";
const extra = bypass ? { "x-vercel-protection-bypass": bypass } : {};
const wait = (ms) => new Promise((done) => setTimeout(done, ms));

const minted = await mintSession(`delivered+bwrelaytime${randomBytes(3).toString("hex")}@resend.dev`);

async function removeAccount() {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  if (!base || !secret || !minted.kept.user_id) return false;
  const gone = await fetch(`${base}/auth/v1/admin/users/${minted.kept.user_id}`, {
    method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` },
  });
  return gone.ok;
}

// Claude's sign-in to the account, as claude.ai does it (tabpair_probe.mjs).
async function claudeToken() {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${origin}/api/oauth?op=approve`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${minted.access_token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "relay_timing",
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

// The stand-in tab: hello with the app's tools, then answers at once.
const token = randomBytes(32).toString("base64url");
const instance = randomBytes(8).toString("hex");
const at = (op, more = "") => `${origin}/api/mcp?t=${token}&i=${instance}&op=${op}${more}`;
let listening = true;
async function listen() {
  while (listening) {
    let got;
    try {
      got = await fetch(at("next", "&used=5&model=Timing"), { method: "POST", headers: extra });
    } catch {
      await wait(500);
      continue;
    }
    if (got.status !== 200) {
      if (got.status !== 204) await wait(500);
      continue;
    }
    const { id, request } = await got.json();
    if (request.id === undefined || request.id === null) continue;
    await fetch(at("answer", `&id=${id}`), {
      method: "POST",
      headers: { ...extra, "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: request.id, result: {
        content: [{ type: "text", text: `did ${request.params?.name || request.method}` }],
        _meta: { "brickworks/tab": "tmng", "brickworks/model": "Timing" } } }),
    });
  }
}

let sent = 0;
let session = "";
async function claude(bearer, method, params) {
  const started = performance.now();
  const answer = await fetch(`${origin}/api/mcp`, {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", accept: "application/json, text/event-stream",
      authorization: `Bearer ${bearer}`, ...(session ? { "mcp-session-id": session } : {}) },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++sent, method, params }),
  });
  const body = await answer.text();
  session = answer.headers.get("mcp-session-id") || session;
  return { ms: performance.now() - started, status: answer.status, body };
}

let failed = false;
try {
  const tools = JSON.parse(readFileSync(new URL("../mcp_tools.json", import.meta.url), "utf8"));
  const hello = await fetch(at("hello", "&tab=tmng&used=5"), {
    method: "POST",
    headers: { ...extra, "content-type": "application/json", authorization: `Bearer ${minted.access_token}` },
    body: JSON.stringify({ instructions: "relay timing", tools, model: "Timing" }),
  });
  if (hello.status !== 204) throw new Error(`the stand-in tab's hello: ${hello.status}`);
  const loop = listen();
  const bearer = await claudeToken();
  if (!bearer) throw new Error("no token for Claude");
  await claude(bearer, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "relay_timing", version: "1" } });
  await claude(bearer, "tools/list", {});
  const calls = [
    ["tabs", {}],
    ["search_parts", { query: "brick 2 x 4" }],
    ["edit_model", { add: [{ part: "3001", color: 4, x: 0, y: 0, z: 0 }] }],
    ["look_at_model", {}],
  ];
  const times = {};
  // The first round warms the relay (a deployment's function starts cold).
  for (let round = 0; round <= rounds; round++) {
    for (const [name, given] of calls) {
      const said = await claude(bearer, "tools/call", { name, arguments: given });
      if (said.status !== 200 || !said.body.includes(name === "tabs" ? "tab is open" : `did ${name}`)) {
        throw new Error(`${name}: ${said.status} ${said.body.slice(0, 200)}`);
      }
      if (round > 0) (times[name] ||= []).push(said.ms);
    }
  }
  const pct = (xs, q) => [...xs].sort((a, b) => a - b)[Math.min(xs.length - 1, Math.floor(q * xs.length))];
  console.log(`${origin}: ${rounds} rounds, ms from Claude's side (median / p90)`);
  for (const [name, xs] of Object.entries(times)) {
    console.log(`  ${name.padEnd(14)} ${String(Math.round(pct(xs, 0.5))).padStart(6)} / ${Math.round(pct(xs, 0.9))}`);
  }
  listening = false;
  await fetch(at("close"), { method: "POST", headers: extra });
  await Promise.race([loop, wait(30000)]);
} catch (trouble) {
  failed = true;
  console.log(`relay timing stopped: ${trouble.message}`);
  listening = false;
}
console.log(`  (the throwaway account ${(await removeAccount().catch(() => false)) ? "deleted" : "NOT deleted"})`);
process.exit(failed ? 1 : 0);
