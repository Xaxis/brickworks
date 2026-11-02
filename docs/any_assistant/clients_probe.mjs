// Each assistant's documented OAuth shape against a local relay: what the
// sign-in page names it, the tools it is given, what a tab sees of a call,
// what Account lists, and Gemini's documented "do not rotate" refresh.
// The measurement behind docs/ANY_ASSISTANT.md section A.3 (anyai,
// 2026-11-02), kept as it ran; ANY_ASSISTANT U1 makes it a check.
// Makes a throwaway account and deletes it; take the live database's lock:
//   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 9671 &
//   tools/release/live_db.sh you node docs/any_assistant/clients_probe.mjs --url=http://127.0.0.1:9671
import { createHash, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
const WT = new URL("../..", import.meta.url).pathname.replace(/\/$/, "");
const { deleteAccount, mintSession } = await import(`${WT}/tools/web/session.mjs`);

const args = Object.fromEntries(process.argv.slice(2).map((a) => a.replace(/^--/, "").split("=")));
const base = String(args.url || "http://127.0.0.1:9671").replace(/\/+$/, "");
const RESOURCE = `${base}/api/mcp`;
const out = [];
const say = (line) => { console.log(line); out.push(line); };

const pkce = () => {
  const verifier = randomBytes(32).toString("base64url");
  return { verifier, challenge: createHash("sha256").update(verifier).digest("base64url") };
};
async function call(path, { method = "GET", headers = {}, body, form } = {}) {
  const sent = { ...headers };
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

const appTools = JSON.parse(readFileSync(`${WT}/tools/mcp_tools.json`, "utf8"))
  .map((one) => ({ name: one.name, description: one.description, inputSchema: one.input_schema,
    annotations: one.annotations }));

// Each client as its maker documents it (docs/ANY_ASSISTANT.md section B).
// cimd: its published document's address. reg: what it registers with
// (RFC 7591). auth: how it proves itself at the token endpoint.
const port = () => 40000 + Math.floor(Math.random() * 20000);
const CLIENTS = [
  { who: "Claude (claude.ai)", cimd: "https://claude.ai/oauth/mcp-oauth-client-metadata",
    back: "https://claude.ai/api/mcp/auth_callback", auth: "none", info: "claude-ai" },
  { who: "Codex", cimd: "https://chatgpt.com/oauth/codex/client.json",
    back: `http://127.0.0.1:${port()}/callback`, auth: "none", info: "codex-mcp-client" },
  { who: "VS Code", cimd: "https://vscode.dev/oauth/client-metadata.json",
    back: "https://vscode.dev/redirect", auth: "none", info: "Visual Studio Code" },
  { who: "Zed", cimd: "https://zed.dev/oauth/client-metadata.json",
    back: `http://127.0.0.1:${port()}/callback`, auth: "none", info: "Zed" },
  { who: "Gemini app (DCR, secret)", reg: { client_name: "Gemini",
    redirect_uris: ["https://oauth-redirect.googleusercontent.com/r/gemini-connected-apps"],
    token_endpoint_auth_method: "client_secret_post" }, auth: "secret_post", info: "gemini", geminiRefresh: true },
  { who: "Gemini CLI (DCR)", reg: { client_name: "Gemini CLI MCP Client",
    redirect_uris: [`http://localhost:${port()}/oauth/callback`], token_endpoint_auth_method: "none" },
    auth: "none", info: "gemini-cli-mcp-client" },
  { who: "Cursor (DCR)", reg: { client_name: "Cursor",
    redirect_uris: ["https://www.cursor.com/agents/mcp/oauth/callback"], token_endpoint_auth_method: "none" },
    auth: "none", info: "cursor-vscode" },
  { who: "M365 Copilot (DCR, Basic)", reg: { client_name: "Microsoft Copilot",
    redirect_uris: ["https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect"],
    token_endpoint_auth_method: "client_secret_basic" }, auth: "secret_basic", info: "copilot" },
  { who: "Perplexity (DCR)", reg: { client_name: "Perplexity",
    redirect_uris: ["https://www.perplexity.ai/rest/connections/oauth_callback"], token_endpoint_auth_method: "none" },
    auth: "none", info: "perplexity" },
  { who: "Grok (DCR)", reg: { client_name: "Grok",
    redirect_uris: ["https://console.x.ai/connectors-oauth-exchange-code/"], token_endpoint_auth_method: "none" },
    auth: "none", info: "grok" },
  { who: "Nameless DCR client", reg: { redirect_uris: ["https://assistant.example/oauth/callback"],
    token_endpoint_auth_method: "none" }, auth: "none", info: "" },
  { who: "A client calling itself Claude", reg: { client_name: "Claude",
    redirect_uris: ["https://not-claude.example/callback"], token_endpoint_auth_method: "none" },
    auth: "none", info: "claude-ai" },
];

const email = `delivered+bwanyai${Date.now().toString(36)}@resend.dev`;
const { access_token: session } = await mintSession(email);
const tabToken = randomBytes(32).toString("base64url");
const tab = `/api/mcp?t=${tabToken}&i=anyaiprobe1`;
const rows = [];
try {
  const hello = await call(`${tab}&op=hello`, { method: "POST", headers: { authorization: `Bearer ${session}` },
    body: { instructions: "Brickworks (anyai probe's tab)", tools: appTools } });
  say(`tab hello: ${hello.status} (${appTools.length} tools)`);
  for (const c of CLIENTS) {
    const row = { who: c.who };
    let clientId = c.cimd;
    let secret = "";
    if (c.reg) {
      const reg = await call("/oauth/register", { method: "POST", body: { grant_types: ["authorization_code",
        "refresh_token"], response_types: ["code"], ...c.reg } });
      row.register = `${reg.status}${reg.json?.client_secret ? " +secret" : ""}${reg.json?.error ? ` ${reg.json.error}` : ""}`;
      clientId = reg.json?.client_id;
      secret = reg.json?.client_secret || "";
      if (!clientId) { rows.push(row); say(JSON.stringify(row)); continue; }
    }
    const back = c.back || c.reg.redirect_uris[0];
    const p = pkce();
    const params = { response_type: "code", client_id: clientId, redirect_uri: back, code_challenge: p.challenge,
      code_challenge_method: "S256", state: "s1", resource: RESOURCE, scope: "build" };
    const shown = await call(`/api/oauth?op=check&${new URLSearchParams(params)}`);
    row.page = shown.json?.refuse ? `REFUSED ${JSON.stringify(shown.json.refuse)}`
      : `"${shown.json?.client}" claude=${shown.json?.claude} back=${shown.json?.return_to}`;
    if (shown.status !== 200 || !shown.json?.client) { rows.push(row); say(JSON.stringify(row)); continue; }
    const approved = await call("/api/oauth?op=approve", { method: "POST", headers: { authorization: `Bearer ${session}` },
      body: params });
    const code = approved.json?.redirect ? new URL(approved.json.redirect).searchParams.get("code") : "";
    const form = { grant_type: "authorization_code", code, redirect_uri: back, code_verifier: p.verifier,
      resource: RESOURCE, client_id: c.auth === "secret_basic" ? undefined : clientId,
      client_secret: c.auth === "secret_post" ? secret : undefined };
    const tok = await call("/oauth/token", { method: "POST", form,
      headers: c.auth === "secret_basic" ? { authorization: basic(clientId, secret) } : {} });
    row.token = `${tok.status}${tok.json?.error ? ` ${tok.json.error}: ${tok.json.error_description}` : ""}`;
    const tk = tok.json || {};
    if (!tk.access_token) { rows.push(row); say(JSON.stringify(row)); continue; }
    const hi = await mcp(tk.access_token, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
      clientInfo: { name: c.info || "x", version: "1" } });
    const sid = hi.headers.get("mcp-session-id") || "";
    row.instructions = (hi.json?.result?.instructions || "").length;
    const listed = await mcp(tk.access_token, "tools/list", {}, 2, sid);
    const tools = listed.json?.result?.tools || [];
    const bare = tools.filter((t) => JSON.stringify(t.inputSchema).includes('"type":"array"}')).length;
    row.tools = `${tools.length} (${bare ? "as the tab sent" : "portable"})`;
    const asked = mcp(tk.access_token, "tools/call", { name: "search_parts", arguments: { query: "2 x 4" } }, 3, sid);
    let taken = null;
    for (let tries = 0; tries < 8 && !taken; tries++) {
      const next = await call(`${tab}&op=next`, { method: "POST" });
      if (next.json?.request?.method === "tools/call") taken = next.json;
    }
    row.tab_sees = taken ? JSON.stringify(taken.request.params._meta || {}) : "no call";
    if (taken) {
      await call(`${tab}&op=answer&id=${taken.id}`, { method: "POST", body: { jsonrpc: "2.0", id: taken.request.id,
        result: { content: [{ type: "text", text: "3001 Brick 2 x 4" }] } } });
    }
    await asked;
    if (c.geminiRefresh) {
      // Google: "you must avoid rotating the Refresh Token... return the exact
      // same Refresh Token" (developers.google.com/connected-apps/mcp/oauth).
      // If Gemini keeps the first one, it comes back after the access token's
      // hour: here, after the 30 s retry grace.
      const r0 = tk.refresh_token;
      const r1 = await call("/oauth/token", { method: "POST", form: { grant_type: "refresh_token", refresh_token: r0,
        client_id: clientId, client_secret: secret, resource: RESOURCE } });
      row.refresh1 = `${r1.status} rotated=${Boolean(r1.json?.refresh_token && r1.json.refresh_token !== r0)}`;
      await new Promise((ok) => setTimeout(ok, 32000));
      const again = await call("/oauth/token", { method: "POST", form: { grant_type: "refresh_token", refresh_token: r0,
        client_id: clientId, client_secret: secret, resource: RESOURCE } });
      row.refresh_same_after_grace = `${again.status} ${again.json?.error || ""} ${again.json?.error_description || ""}`;
      const after = await mcp(r1.json?.access_token, "tools/list", {}, 9, sid);
      row.newest_access_after = after.status;
      const r2 = await call("/oauth/token", { method: "POST", form: { grant_type: "refresh_token",
        refresh_token: r1.json?.refresh_token, client_id: clientId, client_secret: secret, resource: RESOURCE } });
      row.newest_refresh_after = `${r2.status} ${r2.json?.error || ""}`;
    }
    rows.push(row);
    say(JSON.stringify(row));
  }
  const conns = await call("/api/oauth?op=connections", { headers: { authorization: `Bearer ${session}` } });
  say(`Account lists: ${(conns.json?.connections || []).map((one) => one.client).join(" | ")}`);
  await call(`${tab}&op=close`, { method: "POST" });
} finally {
  const removed = await deleteAccount(email);
  say(`throwaway account ${removed ? "removed" : "NOT REMOVED"}`);
}
