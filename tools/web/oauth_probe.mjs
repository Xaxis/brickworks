// Does Claude's sign-in to Brickworks work, and refuse what it should?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 &
//   node tools/web/oauth_probe.mjs --url=http://127.0.0.1:8790
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/oauth_probe.mjs --url=<a preview>
//
// Plays the client's part against the real functions and database, as
// claude.ai and Claude Code do it (claude.com/docs/connectors/building/
// authentication): the MCP address answers 401 naming its metadata; the
// metadata names the authorization server; Claude identifies itself by
// its published Client ID Metadata Document (or registers, RFC 7591);
// the person signs in and allows it (here: a throwaway account at a
// Resend test address, its session minted on this side, and the page's
// own calls made directly); the code is traded with PKCE for tokens; the
// token reaches the MCP address, and a call goes to the account's tab
// (played here by this probe, as a tab would: hello, next, answer).
// Then refresh, rotation and a reused refresh token, revocation, the
// account's list of connections and Disconnect. And the refusals: a wrong
// verifier, a wrong or undeclared return address, a code used twice, no
// PKCE, another server's resource, an unknown client, a missing secret.
//
// Costs nothing and emails nobody. The throwaway account is deleted at
// the end, and every connection with it.
import { createHash, randomBytes } from "node:crypto";
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:8790").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const CLAUDE = "https://claude.ai/oauth/mcp-oauth-client-metadata";
const CLAUDE_CODE = "https://claude.ai/oauth/claude-code-client-metadata";
const CALLBACK = "https://claude.ai/api/mcp/auth_callback";

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const pkce = () => {
  const verifier = b64url(randomBytes(32));
  return { verifier, challenge: b64url(createHash("sha256").update(verifier).digest()) };
};

async function call(path, { method = "GET", headers = {}, body, form } = {}) {
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
  const reply = await fetch(path.startsWith("http") ? path : base + path, {
    method, headers: sent, body: payload, redirect: "manual",
  });
  const text = await reply.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: reply.status, headers: reply.headers, json, text };
}

const mcp = (token, method, params = {}, id = 1) => call("/api/mcp", {
  method: "POST",
  headers: { accept: "application/json, text/event-stream", ...(token ? { authorization: `Bearer ${token}` } : {}) },
  body: { jsonrpc: "2.0", id, method, params },
});

/// The authorize page's two calls, made directly: is this request one to
/// show, then yes as the signed-in person.
async function authorize(session, { clientId, redirect, challenge, state = "s-" + b64url(randomBytes(6)),
  resource = `${base}/api/mcp`, extra = {} }) {
  const params = {
    response_type: "code", client_id: clientId, redirect_uri: redirect,
    code_challenge: challenge, code_challenge_method: "S256", state, resource, scope: "build", ...extra,
  };
  for (const [key, value] of Object.entries(params)) if (value === undefined) delete params[key];
  const checked = await call(`/api/oauth?op=check&${new URLSearchParams(params)}`);
  const approved = await call("/api/oauth?op=approve", {
    method: "POST", headers: session ? { authorization: `Bearer ${session}` } : {}, body: params,
  });
  const to = approved.json?.redirect ? new URL(approved.json.redirect) : null;
  return { checked, approved, to, code: to?.searchParams.get("code"), state };
}

const exchange = (form, headers = {}) => call("/oauth/token", { method: "POST", form, headers });

console.log(`Claude signing in to Brickworks at ${base}\n`);
const email = `delivered+bwoauth${Date.now().toString(36)}@resend.dev`;
const { access_token: session } = await mintSession(email);
const stranger = `delivered+bwoauthx${Date.now().toString(36)}@resend.dev`;
const { access_token: theirs } = await mintSession(stranger);

try {
  console.log("discovery");
  const bare = await mcp(null, "initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "probe", version: "1" } });
  const said = bare.headers.get("www-authenticate") || "";
  const pointer = /resource_metadata="([^"]+)"/.exec(said)?.[1];
  check(bare.status === 401 && pointer === `${base}/.well-known/oauth-protected-resource/api/mcp`,
    `the MCP address asked with no token: 401, naming ${pointer}`);
  check(/scope="build"/.test(said), "...and the scope to ask for");
  const prm = await call(pointer);
  check(prm.status === 200 && prm.json?.resource === `${base}/api/mcp`
      && prm.json?.authorization_servers?.[0] === base,
    `protected resource metadata: resource ${prm.json?.resource}, server ${prm.json?.authorization_servers?.[0]}`);
  const root = await call("/.well-known/oauth-protected-resource");
  check(root.status === 200 && root.json?.resource === prm.json?.resource, "...and at the root, as a client falls back to");
  const meta = await call("/.well-known/oauth-authorization-server");
  const m = meta.json || {};
  check(meta.status === 200 && m.issuer === base, `authorization server metadata, issuer ${m.issuer}`);
  check(JSON.stringify(m.code_challenge_methods_supported) === '["S256"]', "PKCE: S256 and nothing else");
  check(m.client_id_metadata_document_supported === true
      && m.token_endpoint_auth_methods_supported?.includes("none"),
    "Client ID Metadata Documents and public clients: what makes claude.ai use its published identity");
  check(m.authorization_endpoint === `${base}/oauth/authorize` && m.token_endpoint === `${base}/oauth/token`
      && m.registration_endpoint === `${base}/oauth/register` && m.revocation_endpoint === `${base}/oauth/revoke`,
    "authorize, token, register and revoke at their addresses");
  const pathed = await call("/.well-known/oauth-authorization-server/api/mcp");
  check(pathed.status === 200 && pathed.json?.issuer === base, "...and with the MCP path appended, as claude.ai has been seen to ask");
  const page = await call("/oauth/authorize?client_id=x");
  check(page.status === 200 && page.text.includes("authorize.js") && page.text.includes("Connect Claude"),
    "/oauth/authorize is the sign-in page");
  if (!base.startsWith("http://127.")) {
    check(!page.headers.get("cross-origin-opener-policy") || page.headers.get("cross-origin-opener-policy") === "unsafe-none",
      `...without cutting itself off from the window that opened it (COOP ${page.headers.get("cross-origin-opener-policy")})`);
    check((page.headers.get("content-security-policy") || "").includes("frame-ancestors 'none'"),
      "...and cannot be framed");
  }

  console.log("\nClaude (claude.ai and the Claude apps), by its published identity");
  const p1 = pkce();
  const shown = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code", client_id: CLAUDE,
    redirect_uri: CALLBACK, code_challenge: p1.challenge, code_challenge_method: "S256", state: "x",
    resource: `${base}/api/mcp` })}`);
  check(shown.json?.client === "Claude" && shown.json?.return_to === "claude.ai" && !shown.json?.loopback,
    `the page is told who is asking and where the answer goes: ${shown.json?.client}, ${shown.json?.return_to}`);
  const unsigned = await authorize(null, { clientId: CLAUDE, redirect: CALLBACK, challenge: p1.challenge });
  check(unsigned.approved.status === 401 && !unsigned.code, "yes from nobody signed in: 401, no code");
  const a1 = await authorize(session, { clientId: CLAUDE, redirect: CALLBACK, challenge: p1.challenge });
  check(a1.code && a1.to.origin + a1.to.pathname === CALLBACK && a1.to.searchParams.get("state") === a1.state
      && a1.to.searchParams.get("iss") === base,
    "yes, signed in: back to claude.ai's callback with a code, the state, and the issuer");
  const wrongVerifier = await exchange({ grant_type: "authorization_code", code: a1.code, redirect_uri: CALLBACK,
    client_id: CLAUDE, code_verifier: pkce().verifier, resource: `${base}/api/mcp` });
  check(wrongVerifier.status === 400 && wrongVerifier.json?.error === "invalid_grant",
    `a wrong code_verifier is refused: ${wrongVerifier.json?.error}`);
  const after = await exchange({ grant_type: "authorization_code", code: a1.code, redirect_uri: CALLBACK,
    client_id: CLAUDE, code_verifier: p1.verifier, resource: `${base}/api/mcp` });
  check(after.status === 400 && after.json?.error === "invalid_grant",
    "...and the code is spent by the attempt: the right verifier after it is refused too");

  const p2 = pkce();
  const a2 = await authorize(session, { clientId: CLAUDE, redirect: CALLBACK, challenge: p2.challenge });
  const wrongBack = await exchange({ grant_type: "authorization_code", code: a2.code,
    redirect_uri: "https://claude.ai/api/mcp/other", client_id: CLAUDE, code_verifier: p2.verifier });
  check(wrongBack.status === 400 && wrongBack.json?.error === "invalid_grant",
    "a token request with another redirect_uri is refused");
  const p3 = pkce();
  const a3 = await authorize(session, { clientId: CLAUDE, redirect: CALLBACK, challenge: p3.challenge });
  const t0 = Date.now();
  const tokens = await exchange({ grant_type: "authorization_code", code: a3.code, redirect_uri: CALLBACK,
    client_id: CLAUDE, code_verifier: p3.verifier, resource: `${base}/api/mcp` });
  const tk = tokens.json || {};
  check(tokens.status === 200 && /^bwa_/.test(tk.access_token) && /^bwr_/.test(tk.refresh_token)
      && tk.token_type === "Bearer" && tk.expires_in === 3600,
    `the code and its verifier, form-encoded, for tokens in ${Date.now() - t0} ms: Bearer, an hour, and a refresh token`);
  check((tokens.headers.get("cache-control") || "").includes("no-store"), "...never cached");
  const twice = await exchange({ grant_type: "authorization_code", code: a3.code, redirect_uri: CALLBACK,
    client_id: CLAUDE, code_verifier: p3.verifier });
  check(twice.status === 400 && twice.json?.error === "invalid_grant", "the same code twice is refused");

  console.log("\nthe token at the MCP address");
  const hi = await mcp(tk.access_token, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "claude-ai", version: "0.1.0" } });
  check(hi.status === 200 && hi.json?.result?.serverInfo?.name === "brickworks",
    `initialize with the token: ${hi.status}, ${hi.json?.result?.serverInfo?.name}`);
  const listed = await mcp(tk.access_token, "tools/list", {}, 2);
  const names = (listed.json?.result?.tools || []).map((tool) => tool.name);
  check(names.includes("search_parts"), `tools/list with no tab of this account open: the app's ${names.length} tools`);
  const noTab = await mcp(tk.access_token, "tools/call", { name: "search_parts", arguments: { query: "brick" } }, 3);
  const noTabText = (noTab.json?.result?.content || []).map((c) => c.text).join(" ");
  check(noTab.json?.result?.isError && noTabText.includes("No Brickworks tab is open for the account"),
    "a call with no tab open is told so, in words Claude can pass on");
  const forged = await mcp(`bwa_${b64url(randomBytes(32))}`, "tools/list", {}, 4);
  check(forged.status === 401 && /error="invalid_token"/.test(forged.headers.get("www-authenticate") || ""),
    "a made-up token: 401, invalid_token");

  console.log("\nthe account's tab answers (played here as a tab plays it)");
  const tabToken = b64url(randomBytes(32));
  const tab = `/api/mcp?t=${tabToken}&i=oauthprobe1`;
  const hello = await call(`${tab}&op=hello`, { method: "POST", headers: { authorization: `Bearer ${session}` },
    body: { instructions: "probe tab", tools: [{ name: "search_parts", description: "", inputSchema: {} }] } });
  check(hello.status === 204, "a tab of this account switches on");
  const strangerTab = `/api/mcp?t=${b64url(randomBytes(32))}&i=oauthprobe2`;
  await call(`${strangerTab}&op=hello`, { method: "POST", headers: { authorization: `Bearer ${theirs}` },
    body: { instructions: "stranger", tools: [] } });
  const asked = mcp(tk.access_token, "tools/call", { name: "search_parts", arguments: { query: "2 x 4" } }, 5);
  let taken = null;
  for (let tries = 0; tries < 6 && !taken; tries++) {
    const next = await call(`${tab}&op=next`, { method: "POST" });
    if (next.json?.request?.method === "tools/call") taken = next.json;
  }
  check(taken?.request?.params?.arguments?.query === "2 x 4",
    "Claude's call reaches this account's tab, not another account's");
  if (taken) {
    await call(`${tab}&op=answer&id=${taken.id}`, { method: "POST",
      body: { jsonrpc: "2.0", id: taken.request.id, result: { content: [{ type: "text", text: "3001 Brick 2 x 4" }] } } });
  }
  const answered = await asked;
  check((answered.json?.result?.content || [])[0]?.text === "3001 Brick 2 x 4", "...and the tab's answer reaches Claude");
  const strangerNext = await call(`${strangerTab}&op=next`, { method: "POST" });
  check(strangerNext.status === 204, "the other account's tab was handed nothing");
  await call(`${strangerTab}&op=close`, { method: "POST" });

  console.log("\nrefresh");
  const r1 = await exchange({ grant_type: "refresh_token", refresh_token: tk.refresh_token, client_id: CLAUDE,
    resource: `${base}/api/mcp` });
  check(r1.status === 200 && r1.json?.refresh_token && r1.json.refresh_token !== tk.refresh_token
      && r1.json.access_token !== tk.access_token,
    "a refresh token for a new pair: both tokens replaced (rotation)");
  const retry = await exchange({ grant_type: "refresh_token", refresh_token: tk.refresh_token, client_id: CLAUDE });
  check(retry.status === 200, "the old refresh token again within seconds (a client retrying): answered");
  const otherClient = await exchange({ grant_type: "refresh_token", refresh_token: r1.json.refresh_token,
    client_id: CLAUDE_CODE });
  check(otherClient.status === 400 && otherClient.json?.error === "invalid_grant",
    "a refresh token presented by another client: invalid_grant");
  const fresh = await mcp(r1.json.access_token, "tools/list", {}, 6);
  check(fresh.status === 200, "the refreshed access token works");

  console.log("\nClaude Code, by its published identity, on a loopback port it chose");
  const p4 = pkce();
  const cc = `http://localhost:${40000 + Math.floor(Math.random() * 20000)}/callback`;
  const ccShown = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code",
    client_id: CLAUDE_CODE, redirect_uri: cc, code_challenge: p4.challenge, code_challenge_method: "S256" })}`);
  check(ccShown.json?.client === "Claude Code" && ccShown.json?.loopback === true,
    `any port on its declared loopback address, shown with a warning: ${ccShown.json?.return_to}`);
  const ccWrong = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code",
    client_id: CLAUDE_CODE, redirect_uri: cc.replace("/callback", "/elsewhere"), code_challenge: p4.challenge,
    code_challenge_method: "S256" })}`);
  check(ccWrong.status === 400 && /did not declare/.test(ccWrong.json?.refuse || ""),
    "a loopback path it did not declare is refused, and nobody is sent there");
  const a4 = await authorize(session, { clientId: CLAUDE_CODE, redirect: cc, challenge: p4.challenge });
  const ccTokens = await exchange({ grant_type: "authorization_code", code: a4.code, redirect_uri: cc,
    client_id: CLAUDE_CODE, code_verifier: p4.verifier, resource: `${base}/api/mcp` });
  check(ccTokens.status === 200 && /^bwa_/.test(ccTokens.json?.access_token || ""), "Claude Code gets its tokens");

  console.log("\na client that registers itself (RFC 7591)");
  const reg = await call("/oauth/register", { method: "POST", body: {
    client_name: "probe client", redirect_uris: [CALLBACK], token_endpoint_auth_method: "none",
    grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] } });
  check(reg.status === 201 && /^bwc_/.test(reg.json?.client_id || "") && !reg.json?.client_secret,
    "registered: a client id, public, no secret");
  for (const [bad, what] of [[["javascript:alert(1)"], "a javascript: address"],
    [["http://example.com/cb"], "plain http to another machine"], [["https://x.example/cb#frag"], "an address with a fragment"],
    [[], "no address at all"]]) {
    const refused = await call("/oauth/register", { method: "POST", body: { redirect_uris: bad } });
    check(refused.status === 400 && refused.json?.error === "invalid_redirect_uri", `registration refuses ${what}`);
  }
  const p5 = pkce();
  const undeclared = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code",
    client_id: reg.json.client_id, redirect_uri: "https://evil.example/cb", code_challenge: p5.challenge,
    code_challenge_method: "S256" })}`);
  check(undeclared.status === 400 && undeclared.json?.refuse, "an undeclared return address is refused outright");
  const noPkce = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code",
    client_id: reg.json.client_id, redirect_uri: CALLBACK, state: "np" })}`);
  const npTo = noPkce.json?.back ? new URL(noPkce.json.back) : null;
  check(npTo?.searchParams.get("error") === "invalid_request" && npTo?.searchParams.get("state") === "np",
    "no PKCE: sent back with invalid_request");
  const plain = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code",
    client_id: reg.json.client_id, redirect_uri: CALLBACK, code_challenge: p5.challenge, code_challenge_method: "plain" })}`);
  check(new URL(plain.json?.back || CALLBACK).searchParams.get("error") === "invalid_request",
    "PKCE with the plain method: refused the same way");
  const elsewhere = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code",
    client_id: reg.json.client_id, redirect_uri: CALLBACK, code_challenge: p5.challenge, code_challenge_method: "S256",
    resource: "https://elsewhere.example/api/mcp" })}`);
  check(new URL(elsewhere.json?.back || CALLBACK).searchParams.get("error") === "invalid_target",
    "a token for another server's resource: invalid_target");
  const unknown = await call(`/api/oauth?op=check&${new URLSearchParams({ response_type: "code",
    client_id: "bwc_" + b64url(randomBytes(32)), redirect_uri: CALLBACK, code_challenge: p5.challenge,
    code_challenge_method: "S256" })}`);
  check(unknown.status === 400 && unknown.json?.refuse, "an unknown client is refused outright");
  const secretReg = await call("/oauth/register", { method: "POST", body: {
    client_name: "probe secret client", redirect_uris: [CALLBACK], token_endpoint_auth_method: "client_secret_post" } });
  check(secretReg.status === 201 && /^bws_/.test(secretReg.json?.client_secret || ""), "a client that asks for a secret gets one");
  const p6 = pkce();
  const a6 = await authorize(session, { clientId: secretReg.json.client_id, redirect: CALLBACK, challenge: p6.challenge });
  const noSecret = await exchange({ grant_type: "authorization_code", code: a6.code, redirect_uri: CALLBACK,
    client_id: secretReg.json.client_id, code_verifier: p6.verifier });
  check(noSecret.status === 401 && noSecret.json?.error === "invalid_client", "...and without it is refused: invalid_client");
  const p7 = pkce();
  const a7 = await authorize(session, { clientId: secretReg.json.client_id, redirect: CALLBACK, challenge: p7.challenge });
  const basic = Buffer.from(`${encodeURIComponent(secretReg.json.client_id)}:${encodeURIComponent(secretReg.json.client_secret)}`).toString("base64");
  const withSecret = await exchange({ grant_type: "authorization_code", code: a7.code, redirect_uri: CALLBACK,
    code_verifier: p7.verifier }, { authorization: `Basic ${basic}` });
  check(withSecret.status === 200 && withSecret.json?.access_token, "...and with it (HTTP Basic) gets tokens");
  const denied = await call("/api/oauth?op=deny", { method: "POST", body: { response_type: "code",
    client_id: CLAUDE, redirect_uri: CALLBACK, code_challenge: pkce().challenge, code_challenge_method: "S256", state: "d" } });
  const deniedTo = new URL(denied.json?.redirect || CALLBACK);
  check(deniedTo.searchParams.get("error") === "access_denied" && deniedTo.searchParams.get("state") === "d",
    "Cancel sends Claude back access_denied");

  console.log("\nthe account's connections");
  const mine = await call("/api/oauth?op=connections", { headers: { authorization: `Bearer ${session}` } });
  const clients = (mine.json?.connections || []).map((c) => c.client);
  check(clients.includes("Claude") && clients.includes("Claude Code"),
    `listed for the account: ${clients.join(", ")}`);
  const claudeOne = (mine.json?.connections || []).find((c) => c.client === "Claude" && c.last_used);
  check(Boolean(claudeOne), "...with when Claude last used it");
  const notMine = await call("/api/oauth?op=connections", { headers: { authorization: `Bearer ${theirs}` } });
  check((notMine.json?.connections || []).length === 0, "another account sees none of them");
  const noOne = await call("/api/oauth?op=connections");
  check(noOne.status === 401, "nobody signed in sees nothing: 401");

  console.log("\nrevocation and disconnecting");
  const revoked = await call("/oauth/revoke", { method: "POST",
    form: { token: ccTokens.json.refresh_token, token_type_hint: "refresh_token", client_id: CLAUDE_CODE } });
  check(revoked.status === 200, "Claude Code's refresh token revoked (RFC 7009): 200");
  const ccAfter = await mcp(ccTokens.json.access_token, "tools/list", {}, 7);
  check(ccAfter.status === 401, "...and its whole connection with it: its access token is refused");
  const gone = await call("/api/oauth?op=disconnect", { method: "POST", headers: { authorization: `Bearer ${session}` } });
  check(gone.status === 200 && gone.json?.disconnected >= 2, `Disconnect Claude: ${gone.json?.disconnected} connection(s) ended`);
  const afterDisconnect = await mcp(r1.json.access_token, "tools/list", {}, 8);
  check(afterDisconnect.status === 401 && /resource_metadata=/.test(afterDisconnect.headers.get("www-authenticate") || ""),
    "Claude's token is refused at once, and told where to sign in again");
  const refreshAfter = await exchange({ grant_type: "refresh_token", refresh_token: r1.json.refresh_token, client_id: CLAUDE });
  check(refreshAfter.status === 400 && refreshAfter.json?.error === "invalid_grant", "...and so is its refresh token");
  const left = await call("/api/oauth?op=connections", { headers: { authorization: `Bearer ${session}` } });
  check((left.json?.connections || []).length === 0, "none left");

  console.log("\na refresh token used again long after it was replaced");
  const p8 = pkce();
  const a8 = await authorize(session, { clientId: CLAUDE, redirect: CALLBACK, challenge: p8.challenge });
  const t8 = (await exchange({ grant_type: "authorization_code", code: a8.code, redirect_uri: CALLBACK,
    client_id: CLAUDE, code_verifier: p8.verifier })).json;
  const r8 = (await exchange({ grant_type: "refresh_token", refresh_token: t8.refresh_token, client_id: CLAUDE })).json;
  await new Promise((done) => setTimeout(done, 31_000));
  const replay = await exchange({ grant_type: "refresh_token", refresh_token: t8.refresh_token, client_id: CLAUDE });
  check(replay.status === 400 && replay.json?.error === "invalid_grant", "after the grace: invalid_grant");
  const victim = await mcp(r8.access_token, "tools/list", {}, 9);
  check(victim.status === 401, "...and the connection is ended: somebody else has a copy");
  await call(`${tab}&op=close`, { method: "POST" });
} finally {
  const removed = (await deleteAccount(email) ? 1 : 0) + (await deleteAccount(stranger) ? 1 : 0);
  console.log(`\n  (removed ${removed} throwaway account(s), and their connections with them)`);
}

console.log(failures ? `\n${failures} FAILURE(S)` : "\nClaude can sign in to Brickworks, and nothing else can");
process.exit(failures ? 1 : 0);
