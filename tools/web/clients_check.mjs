// Every assistant's documented sign-in against the relay: what the sign-in
// page names it, the tools it is given, who a tab is told is calling, what
// Account lists, and a refresh token sent again after the grace.
// docs/ANY_ASSISTANT.md A.3 measured this as a probe; U1 and U2 made it
// this check.
//
//   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 9671 &
//   tools/release/live_db.sh you node tools/web/clients_check.mjs --url=http://127.0.0.1:9671
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/clients_check.mjs --url=<a preview>
//
// Each client plays its sign-in as its maker documents it (section B.1):
// its published document where it has one, else registration with its
// documented return address and way of proving itself. Then a call into a
// tab played here (hello, next, answer) carrying a `brickworks/who` and a
// `brickworks/chat` of the client's own making, which the tab must never
// see: it is told the label the relay checked. A refresh, a call with the
// new token, and, 32 s on (past the 30 s retry grace), the first refresh
// token sent again: a client that proves itself (a secret, or a signed
// assertion) still holds it and stays connected, as Google tells Gemini to
// expect; a public client's reuse ends its connection, as before.
//
// About a minute, most of it the grace. Calls no model and emails nobody;
// fetches the clients' published documents. A throwaway account at a
// Resend test address, deleted at the end with every connection.
import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:9671").replace(/\/+$/, "").replace(/\/app$/, "");
const bypass = process.env.BW_BYPASS || "";
const RESOURCE = `${base}/api/mcp`;
const ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
const GRACE_MS = 32_000;

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};
const b64url = (value) => Buffer.from(typeof value === "string" ? value : JSON.stringify(value)).toString("base64url");
const pkce = () => {
  const verifier = randomBytes(32).toString("base64url");
  return { verifier, challenge: createHash("sha256").update(verifier).digest("base64url") };
};

async function call(path, { method = "GET", headers = {}, body, form } = {}) {
  const sent = { ...headers };
  if (bypass) sent["x-vercel-protection-bypass"] = bypass;
  let payload;
  if (form) {
    sent["content-type"] = "application/x-www-form-urlencoded";
    payload = new URLSearchParams(Object.entries(form).filter(([, v]) => v !== undefined)).toString();
  } else if (body !== undefined) {
    sent["content-type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const reply = await fetch(path.startsWith("http") ? path : base + path, { method, headers: sent, body: payload,
    redirect: "manual" });
  const text = await reply.text();
  let json = null;
  try {
    json = (reply.headers.get("content-type") || "").startsWith("text/event-stream")
      ? text.split("\n").filter((l) => l.startsWith("data:")).map((l) => JSON.parse(l.slice(5)))
        .find((m) => m.id !== undefined) || null
      : text ? JSON.parse(text) : null;
  } catch { json = null; }
  return { status: reply.status, headers: reply.headers, json, text };
}
const mcp = (token, method, params = {}, id = 1, session = "") => call("/api/mcp", { method: "POST",
  headers: { accept: "application/json, text/event-stream", authorization: `Bearer ${token}`,
    ...(session ? { "mcp-session-id": session } : {}) },
  body: { jsonrpc: "2.0", id, method, params } });
const basic = (id, secret) => `Basic ${Buffer.from(`${encodeURIComponent(id)}:${encodeURIComponent(secret)}`).toString("base64")}`;

/// A client assertion for [client], signed by [pair]: RFC 7523, as ChatGPT
/// signs its token requests.
function assertion(client, pair) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url({ alg: "RS256", kid: "stand-in", typ: "JWT" });
  const body = b64url({ iss: client, sub: client, aud: `${base}/oauth/token`, iat: now, exp: now + 300,
    jti: randomUUID() });
  return `${header}.${body}.${sign("sha256", Buffer.from(`${header}.${body}`), pair.privateKey).toString("base64url")}`;
}

const appTools = JSON.parse(readFileSync(new URL("../mcp_tools.json", import.meta.url), "utf8"))
  .map((one) => ({ name: one.name, description: one.description, inputSchema: one.input_schema,
    annotations: one.annotations }));
/// Every array in [schema] that does not say what its items are: Claude's
/// list keeps some, as the tab sent it; a portable one has none.
function bareArrays(schema, found = []) {
  if (!schema || typeof schema !== "object") return found;
  if (schema.type === "array" && schema.items === undefined) found.push(schema);
  for (const one of Object.values(schema.properties || {})) bareArrays(one, found);
  if (schema.items && typeof schema.items === "object") bareArrays(schema.items, found);
  for (const key of ["anyOf", "oneOf", "allOf"]) for (const one of schema[key] || []) bareArrays(one, found);
  return found;
}
const bare = (tools) => tools.filter((t) => bareArrays(t.inputSchema).length).length;

// Each client as its maker documents it (docs/ANY_ASSISTANT.md B.1).
// cimd: its published document's address. reg: what it registers with
// (RFC 7591). auth: how it proves itself at the token endpoint. label: what
// the page, Account and a tab must call it (named: Account and a tab, once
// initialize has given a name it had not); claude: given Claude's list.
const port = () => 40000 + Math.floor(Math.random() * 20000);
const standIn = generateKeyPairSync("rsa", { modulusLength: 2048 });
const CLIENTS = [
  { who: "Claude (claude.ai's document)", cimd: "https://claude.ai/oauth/mcp-oauth-client-metadata",
    back: "https://claude.ai/api/mcp/auth_callback", auth: "none", info: "claude-ai", label: "Claude", claude: true },
  { who: "ChatGPT (its document; only ChatGPT holds its key)", cimd: "https://chatgpt.com/oauth/client.json",
    back: "https://chatgpt.com/connector_platform_oauth_redirect", label: "ChatGPT", pageOnly: true },
  { who: "ChatGPT-shaped (registers its own key, back to chatgpt.com)", reg: { client_name: "ChatGPT stand-in",
    redirect_uris: ["https://chatgpt.com/connector_platform_oauth_redirect"], token_endpoint_auth_method: "private_key_jwt",
    token_endpoint_auth_signing_alg: "RS256",
    jwks: { keys: [{ ...standIn.publicKey.export({ format: "jwk" }), kid: "stand-in", use: "sig", alg: "RS256" }] } },
    auth: "signed", info: "openai-mcp", label: "ChatGPT" },
  { who: "Codex (its document)", cimd: "https://chatgpt.com/oauth/codex/client.json",
    back: `http://127.0.0.1:${port()}/callback`, auth: "none", info: "codex-mcp-client", label: "Codex" },
  { who: "VS Code (its document)", cimd: "https://vscode.dev/oauth/client-metadata.json",
    back: "https://vscode.dev/redirect", auth: "none", info: "Visual Studio Code", label: "Visual Studio Code" },
  { who: "Zed (its document)", cimd: "https://zed.dev/oauth/client-metadata.json",
    back: `http://127.0.0.1:${port()}/callback`, auth: "none", info: "Zed", label: "Zed" },
  { who: "Gemini app (registers, a secret, a googleusercontent.com return)", reg: { client_name: "Gemini",
    redirect_uris: ["https://oauth-redirect.googleusercontent.com/r/gemini-connected-apps"],
    token_endpoint_auth_method: "client_secret_post" }, auth: "secret_post", info: "gemini", label: "Gemini" },
  { who: "Gemini CLI (registers, loopback)", reg: { client_name: "Gemini CLI MCP Client",
    redirect_uris: [`http://localhost:${port()}/oauth/callback`], token_endpoint_auth_method: "none" },
    auth: "none", info: "gemini-cli-mcp-client", label: "Gemini CLI MCP Client" },
  { who: "Cursor (registers, public)", reg: { client_name: "Cursor",
    redirect_uris: ["https://www.cursor.com/agents/mcp/oauth/callback"], token_endpoint_auth_method: "none" },
    auth: "none", info: "cursor-vscode", label: "Cursor" },
  { who: "Microsoft 365 Copilot (registers, a secret, HTTP Basic)", reg: { client_name: "Microsoft Copilot",
    redirect_uris: ["https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect"],
    token_endpoint_auth_method: "client_secret_basic" }, auth: "secret_basic", info: "copilot",
    label: "Microsoft Copilot" },
  { who: "Perplexity (registers, public)", reg: { client_name: "Perplexity",
    redirect_uris: ["https://www.perplexity.ai/rest/connections/oauth_callback"], token_endpoint_auth_method: "none" },
    auth: "none", info: "perplexity", label: "Perplexity" },
  { who: "Grok (registers, public)", reg: { client_name: "Grok",
    redirect_uris: ["https://console.x.ai/connectors-oauth-exchange-code/"], token_endpoint_auth_method: "none" },
    auth: "none", info: "grok", label: "Grok" },
  { who: "A client with no name", reg: { redirect_uris: ["https://assistant.example/oauth/callback"],
    token_endpoint_auth_method: "none" }, auth: "none", info: "assistant-x", label: "An MCP client",
    named: "assistant-x" },
  { who: "A client calling itself Claude, back to not-claude.example", reg: { client_name: "Claude",
    redirect_uris: ["https://not-claude.example/callback"], token_endpoint_auth_method: "none" },
    auth: "none", info: "claude-ai", label: "not-claude.example" },
];
const proves = (c) => c.auth !== "none";

/// What [c] adds to a token request to prove itself, and the headers.
function proof(c) {
  if (c.auth === "secret_basic") return { form: {}, headers: { authorization: basic(c.id, c.secret) } };
  if (c.auth === "secret_post") return { form: { client_id: c.id, client_secret: c.secret }, headers: {} };
  if (c.auth === "signed") {
    return { form: { client_assertion_type: ASSERTION_TYPE, client_assertion: assertion(c.id, standIn) }, headers: {} };
  }
  return { form: { client_id: c.id }, headers: {} };
}
const token = (c, form) => {
  const { form: more, headers } = proof(c);
  return call("/oauth/token", { method: "POST", form: { ...form, ...more, resource: RESOURCE }, headers });
};

const email = `delivered+bwclients${Date.now().toString(36)}@resend.dev`;
const { access_token: session } = await mintSession(email);
const tabToken = randomBytes(32).toString("base64url");
const tab = `/api/mcp?t=${tabToken}&i=clientscheck1`;

/// A tools/call made as [c], with a `brickworks/who` and `brickworks/chat`
/// of its own: the _meta the played tab is handed with it, and whether the
/// tab's answer came back.
async function callIntoTab(c, accessToken, n) {
  const asked = mcp(accessToken, "tools/call", { name: "search_parts", arguments: { query: "2 x 4" },
    _meta: { "brickworks/who": "Somebody else", "brickworks/chat": { chat: "forged", since: "2020-01-01" },
      progressToken: n } }, 10 + n, c.sid);
  let taken = null;
  for (let tries = 0; tries < 8 && !taken; tries++) {
    const next = await call(`${tab}&op=next`, { method: "POST" });
    if (next.json?.request?.method === "tools/call") taken = next.json;
  }
  if (taken) {
    await call(`${tab}&op=answer&id=${taken.id}`, { method: "POST", body: { jsonrpc: "2.0", id: taken.request.id,
      result: { content: [{ type: "text", text: "3001 Brick 2 x 4" }] } } });
  }
  const answered = await asked;
  return { meta: taken?.request?.params?._meta || null,
    answered: (answered.json?.result?.content || []).some((block) => /3001 Brick 2 x 4/.test(block.text || "")) };
}

try {
  const hello = await call(`${tab}&op=hello`, { method: "POST", headers: { authorization: `Bearer ${session}` },
    body: { instructions: "Brickworks (clients_check's tab)", tools: appTools } });
  check(hello.status === 204, `a tab of the throwaway account says hello: ${hello.status}`);
  for (const c of CLIENTS) {
    console.log(`\n${c.who}`);
    c.id = c.cimd;
    if (c.reg) {
      const reg = await call("/oauth/register", { method: "POST", body: { grant_types: ["authorization_code",
        "refresh_token"], response_types: ["code"], ...c.reg } });
      c.id = reg.json?.client_id;
      c.secret = reg.json?.client_secret || "";
      check(reg.status === 201 && Boolean(c.secret) === c.auth.startsWith("secret"),
        `registered: ${reg.status}${c.secret ? ", with a secret" : ""}`);
      if (!c.id) continue;
    }
    c.back = c.back || c.reg.redirect_uris[0];
    const p = pkce();
    const params = { response_type: "code", client_id: c.id, redirect_uri: c.back, code_challenge: p.challenge,
      code_challenge_method: "S256", state: "s1", resource: RESOURCE, scope: "build" };
    const shown = await call(`/api/oauth?op=check&${new URLSearchParams(params)}`);
    check(shown.json?.client === c.label && shown.json?.claude === Boolean(c.claude),
      `the sign-in page names it "${shown.json?.client}" (claude ${shown.json?.claude}), back to ${shown.json?.return_to}`);
    if (c.pageOnly || !shown.json?.client) continue;
    const approved = await call("/api/oauth?op=approve", { method: "POST", headers: { authorization: `Bearer ${session}` },
      body: params });
    const code = approved.json?.redirect ? new URL(approved.json.redirect).searchParams.get("code") : "";
    const tok = await token(c, { grant_type: "authorization_code", code, redirect_uri: c.back, code_verifier: p.verifier });
    c.tokens = tok.json || {};
    check(tok.status === 200 && /^bwr_/.test(c.tokens.refresh_token || ""),
      `tokens: ${tok.status}${tok.json?.error ? ` ${tok.json.error}: ${tok.json.error_description}` : ""}`);
    if (!c.tokens.access_token) continue;
    const hi = await mcp(c.tokens.access_token, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
      clientInfo: { name: c.info, version: "1" } });
    c.sid = hi.headers.get("mcp-session-id") || "";
    const tools = (await mcp(c.tokens.access_token, "tools/list", {}, 2, c.sid)).json?.result?.tools || [];
    check(tools.length === appTools.length + 2 && (bare(tools) > 0) === Boolean(c.claude),
      `${tools.length} tools, ${bare(tools) ? "as the tab sent them (Claude's)" : "portable"}`);
    const first = await callIntoTab(c, c.tokens.access_token, 1);
    check(first.meta?.["brickworks/who"] === (c.named || c.label) && first.meta?.["brickworks/chat"]?.chat !== "forged"
      && first.meta?.progressToken === 1 && first.answered,
      `a call into the tab, which is told who: ${JSON.stringify(first.meta?.["brickworks/who"])}, `
        + `chat ${JSON.stringify(first.meta?.["brickworks/chat"]?.chat)}; answered ${first.answered}`);
    const r1 = await token(c, { grant_type: "refresh_token", refresh_token: c.tokens.refresh_token });
    c.r1 = r1.json || {};
    const kept = c.r1.refresh_token === c.tokens.refresh_token;
    check(r1.status === 200 && /^bwa_/.test(c.r1.access_token || "") && kept === proves(c),
      `refreshed: ${r1.status}, the refresh token ${kept ? "kept (it proves itself)" : "replaced (public)"}`);
    const second = await callIntoTab(c, c.r1.access_token, 2);
    check(second.meta?.["brickworks/who"] === (c.named || c.label) && second.answered,
      `a call with the new token: who ${JSON.stringify(second.meta?.["brickworks/who"])}`);
  }

  const signedIn = CLIENTS.filter((c) => c.r1?.access_token);
  const listed = async () => ((await call("/api/oauth?op=connections", { headers: { authorization: `Bearer ${session}` } }))
    .json?.connections || []).map((one) => one.client);
  const before = await listed();
  const want = signedIn.map((c) => c.named || c.label);
  console.log("\nAccount");
  check(want.every((label) => before.filter((one) => one === label).length === want.filter((one) => one === label).length)
    && before.length === want.length && before.filter((one) => one === "Claude").length === 1,
    `lists each by what was checked, one Claude: ${before.join(" | ")}`);

  console.log(`\n${GRACE_MS / 1000} s on, past the grace: the first refresh token again`);
  await new Promise((done) => setTimeout(done, GRACE_MS));
  for (const c of signedIn) {
    const again = await token(c, { grant_type: "refresh_token", refresh_token: c.tokens.refresh_token });
    const after = await mcp(c.r1.access_token, "tools/list", {}, 9, c.sid);
    if (proves(c)) {
      check(again.status === 200 && again.json?.refresh_token === c.tokens.refresh_token && after.status === 200,
        `${c.label}: answered ${again.status} with the same token; still connected (${after.status})`);
    } else {
      check(again.status === 400 && again.json?.error === "invalid_grant" && after.status === 401,
        `${c.label}: ${again.status} ${again.json?.error}; the connection ended (${after.status}): somebody else has a copy`);
    }
  }
  const left = await listed();
  const stay = signedIn.filter(proves).map((c) => c.named || c.label);
  check(left.length === stay.length && stay.every((label) => left.includes(label)),
    `Account then lists those that prove themselves: ${left.join(" | ")}`);
  await call(`${tab}&op=close`, { method: "POST" });
} finally {
  const removed = await deleteAccount(email);
  console.log(`\n  (throwaway account ${removed ? "removed" : "NOT REMOVED"}, and its connections with it)`);
}

console.log(failures ? `\n${failures} FAILURE(S)`
  : "\nEvery assistant signs in, is named by what was checked, and stays connected as it should");
process.exit(failures ? 1 : 0);
