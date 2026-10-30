// ChatGPT connecting to Brickworks, stood in for: discovery, sign-in, the
// token, and building in the account's tab (docs/PROVIDERS.md, P1).
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9640 &
//   node tools/web/chatgpt_flow.mjs --url=http://127.0.0.1:9640
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/chatgpt_flow.mjs --url=<a preview> --out=shots/chatgpt
//
// Plays ChatGPT's part as OpenAI documents it (developers.openai.com/
// apps-sdk/build/auth, read 2026-10-29): the MCP address asked with no
// token answers 401 naming its metadata; the metadata says Client ID
// Metadata Documents, S256, the issuer on the way back, and private_key_jwt
// with RS256, which is what makes ChatGPT sign; ChatGPT names itself by
// https://chatgpt.com/oauth/client.json, read live here, and the sign-in
// page names it. Allow sends a code to ChatGPT's return address. Only
// ChatGPT holds the key its document points to, so that code is refused
// here without ChatGPT's signature, and with a signature by any other key.
//
// The rest is a client shaped as ChatGPT is but holding a key of its own,
// registered (RFC 7591) with its public key, standing in for ChatGPT's
// managed one: sign-in, the code traded with a signed assertion, initialize
// as ChatGPT says hello, tools/list (the app's tools, each array's items
// said and all three hints, as OpenAI asks), and one tools/call into the
// account's tab (played here as a tab plays it: hello, next, answer).
// Refresh with a fresh assertion; the same assertion again, or none, is
// refused. And Claude, connected to the same account, is given the tool
// list exactly as the tab sent it, as before.
//
// With --out, the sign-in page as ChatGPT's person sees it, in a real
// browser at 390 and 1280 px, light and dark: ChatGPT named, no word of
// Claude, and Allow arriving at chatgpt.com (stood in for: nothing reaches
// it). Costs nothing, calls no model, emails nobody; the throwaway account
// is deleted at the end, and every connection with it.

import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";
import { mkdirSync, readFileSync } from "node:fs";
import { deleteAccount, mintSession, signInContext } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:9640").replace(/\/+$/, "").replace(/\/app$/, "");
const bypass = process.env.BW_BYPASS || (typeof args.bypass === "string" ? args.bypass : "");
const out = typeof args.out === "string" ? args.out : "";
const CHATGPT = "https://chatgpt.com/oauth/client.json";
const CHATGPT_BACK = "https://chatgpt.com/connector_platform_oauth_redirect";
const CLAUDE_CODE = "https://claude.ai/oauth/claude-code-client-metadata";
const ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
const RESOURCE = `${base}/api/mcp`;

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
      ? text.split("\n").filter((line) => line.startsWith("data:"))
        .map((line) => JSON.parse(line.slice(5))).find((message) => message.id !== undefined) || null
      : text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: reply.status, headers: reply.headers, json, text };
}

const mcp = (token, method, params = {}, id = 1, session = "") => call("/api/mcp", {
  method: "POST",
  headers: { accept: "application/json, text/event-stream", ...(token ? { authorization: `Bearer ${token}` } : {}),
    ...(session ? { "mcp-session-id": session } : {}) },
  body: { jsonrpc: "2.0", id, method, params },
});

/// A client assertion for [client], signed by [pair]: RFC 7523, as ChatGPT
/// signs its token requests.
function assertion(client, pair, kid, claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url({ alg: "RS256", kid, typ: "JWT" });
  const body = b64url({ iss: client, sub: client, aud: `${base}/oauth/token`, iat: now, exp: now + 300,
    jti: randomUUID(), ...claims });
  return `${header}.${body}.${sign("sha256", Buffer.from(`${header}.${body}`), pair.privateKey).toString("base64url")}`;
}

/// The sign-in page's two calls, made directly: what to show, then Allow.
async function allow(session, { clientId, redirect, challenge, state = `s-${randomBytes(6).toString("hex")}` }) {
  const params = { response_type: "code", client_id: clientId, redirect_uri: redirect, code_challenge: challenge,
    code_challenge_method: "S256", state, resource: RESOURCE, scope: "build" };
  const shown = await call(`/api/oauth?op=check&${new URLSearchParams(params)}`);
  const approved = await call("/api/oauth?op=approve", { method: "POST",
    headers: { authorization: `Bearer ${session}` }, body: params });
  const to = approved.json?.redirect ? new URL(approved.json.redirect) : null;
  return { shown, to, code: to?.searchParams.get("code"), state, params };
}

const exchange = (form) => call("/oauth/token", { method: "POST", form });

/// The app's tools as a tab serves them (CommandSocket.served_tools).
const appTools = JSON.parse(readFileSync(new URL("../mcp_tools.json", import.meta.url), "utf8"))
  .map((one) => ({ name: one.name, description: one.description, inputSchema: one.input_schema,
    annotations: one.annotations }));

/// [value] as JSON with every object's keys in order: the tab's hello is kept
/// as jsonb, which keeps no key order of its own.
const canonical = (value) => JSON.stringify(value, (key, one) => (one && typeof one === "object" && !Array.isArray(one)
  ? Object.fromEntries(Object.keys(one).sort().map((name) => [name, one[name]])) : one));

/// Every array in [schema] that does not say what its items are.
function bareArrays(schema, where, found = []) {
  if (!schema || typeof schema !== "object") return found;
  if (schema.type === "array" && schema.items === undefined) found.push(where);
  for (const [name, one] of Object.entries(schema.properties || {})) bareArrays(one, `${where}.${name}`, found);
  if (schema.items && typeof schema.items === "object") bareArrays(schema.items, `${where}[]`, found);
  for (const key of ["anyOf", "oneOf", "allOf"]) {
    for (const [i, one] of (Array.isArray(schema[key]) ? schema[key] : []).entries()) {
      bareArrays(one, `${where}<${key}${i}>`, found);
    }
  }
  return found;
}

/// The sign-in page as ChatGPT's person sees it, in a real browser.
async function consentInBrowser(email) {
  const { launch } = await import("./browser.mjs");
  mkdirSync(out, { recursive: true });
  const browser = await launch({ signedOut: true });
  try {
    for (const scheme of ["light", "dark"]) {
      for (const width of [390, 1280]) {
        const context = await browser.newContext({ viewport: { width, height: 900 }, colorScheme: scheme });
        if (bypass) await context.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
        await signInContext(context, email);
        let arrived = "";
        await context.route(/^https:\/\/chatgpt\.com\//, (route) => {
          arrived = route.request().url();
          return route.fulfill({ status: 200, contentType: "text/html",
            body: "<!doctype html><title>chatgpt.com (stand-in)</title><p>chatgpt.com, stood in for by the test.</p>" });
        });
        const page = await context.newPage();
        const { challenge } = pkce();
        const state = `b-${randomBytes(6).toString("hex")}`;
        await page.goto(`${base}/oauth/authorize?${new URLSearchParams({ response_type: "code", client_id: CHATGPT,
          redirect_uri: CHATGPT_BACK, code_challenge: challenge, code_challenge_method: "S256", state,
          resource: RESOURCE, scope: "build" })}`, { waitUntil: "domcontentloaded", timeout: 120000 });
        // Allowed before, by this same account, a connection is answered at
        // once; the first view of all is the question.
        const asked = await page.locator("#allow-step:not(.hide)").waitFor({ timeout: 60000 }).then(() => true)
          .catch(() => false);
        const seen = asked ? await page.evaluate(() => document.body.innerText) : "";
        const title = await page.title();
        await page.screenshot({ path: `${out}/consent_${width}_${scheme}.png`, fullPage: true }).catch(() => {});
        const wide = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
        if (scheme === "light" && width === 390) {
          check(asked && /Let ChatGPT build in Brickworks\?/.test(seen) && !/Claude/.test(seen),
            `the question names ChatGPT and no word of Claude is shown (${width} px ${scheme})`);
          check(title === "Connect ChatGPT to Brickworks" && /your ChatGPT conversations/.test(seen)
              && /chatgpt\.com/.test(seen), `title "${title}", its conversations, and where the answer goes`);
          await page.click("#allow");
          await page.waitForURL(/^https:\/\/chatgpt\.com\//, { timeout: 60000 }).catch(() => {});
          const back = arrived ? new URL(arrived) : null;
          check(back && back.origin + back.pathname === CHATGPT_BACK && /^bwk_/.test(back.searchParams.get("code") || "")
              && back.searchParams.get("state") === state && back.searchParams.get("iss") === base,
            "Allow: back at ChatGPT's return address with a code, the state and the issuer");
        } else {
          check(asked ? !/Claude/.test(seen) && wide <= 0 : /Connected|Taking you back/.test(await page
            .evaluate(() => document.body.innerText)), `${width} px ${scheme}: ${asked ? "no Claude, nothing wider "
            + "than the window" : "allowed before, answered at once"}`);
        }
        await context.close();
      }
    }
  } finally {
    await browser.close();
  }
}

console.log(`ChatGPT connecting to Brickworks at ${base}\n`);
const email = `delivered+bwchatgpt${Date.now().toString(36)}@resend.dev`;
const { access_token: session } = await mintSession(email);
const tabToken = randomBytes(32).toString("base64url");
const tab = `/api/mcp?t=${tabToken}&i=chatgptflow1`;

try {
  console.log("discovery, as ChatGPT finds where to sign in");
  const bare = await mcp(null, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "openai-mcp", version: "1.0.0" } });
  const pointer = /resource_metadata="([^"]+)"/.exec(bare.headers.get("www-authenticate") || "")?.[1];
  check(bare.status === 401 && pointer === `${base}/.well-known/oauth-protected-resource/api/mcp`,
    `the MCP address with no token: 401, naming ${pointer}`);
  const prm = (await call(pointer)).json || {};
  check(prm.resource === RESOURCE && prm.authorization_servers?.[0] === base,
    `protected resource metadata: ${prm.resource}, server ${prm.authorization_servers?.[0]}`);
  const meta = (await call("/.well-known/oauth-authorization-server")).json || {};
  check(meta.client_id_metadata_document_supported === true && JSON.stringify(meta.code_challenge_methods_supported)
      === '["S256"]' && meta.authorization_response_iss_parameter_supported === true,
    "Client ID Metadata Documents, S256 and the issuer on the way back: ChatGPT's stable return address");
  check(meta.token_endpoint_auth_methods_supported?.includes("private_key_jwt")
      && meta.token_endpoint_auth_methods_supported?.[0] === "none"
      && JSON.stringify(meta.token_endpoint_auth_signing_alg_values_supported) === '["RS256"]',
    `token endpoint takes ${meta.token_endpoint_auth_methods_supported?.join(", ")}, signed RS256`);

  console.log("\nChatGPT, by its own published document");
  const doc = await (await fetch(CHATGPT)).json();
  check(doc.client_id === CHATGPT && doc.token_endpoint_auth_method === "private_key_jwt"
      && doc.redirect_uris?.includes(CHATGPT_BACK),
    `its document, read now: ${doc.token_endpoint_auth_method}, keys at ${doc.jwks_uri}`);
  const p1 = pkce();
  const real = await allow(session, { clientId: CHATGPT, redirect: CHATGPT_BACK, challenge: p1.challenge });
  check(real.shown.json?.client === "ChatGPT" && real.shown.json?.claude === false
      && real.shown.json?.return_to === "chatgpt.com",
    `the sign-in page is told: ${real.shown.json?.client}, back to ${real.shown.json?.return_to}`);
  check(real.code && real.to.origin + real.to.pathname === CHATGPT_BACK && real.to.searchParams.get("iss") === base
      && real.to.searchParams.get("state") === real.state, "Allow: a code at ChatGPT's return address, with state and iss");
  const unsigned = await exchange({ grant_type: "authorization_code", code: real.code, redirect_uri: CHATGPT_BACK,
    client_id: CHATGPT, code_verifier: p1.verifier, resource: RESOURCE });
  check(unsigned.status === 401 && unsigned.json?.error === "invalid_client" && /client_assertion/.test(unsigned.json
    ?.error_description || ""), `its code without ChatGPT's signature: ${unsigned.status} ${unsigned.json?.error_description}`);
  const impostor = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const forged = await exchange({ grant_type: "authorization_code", code: real.code, redirect_uri: CHATGPT_BACK,
    code_verifier: p1.verifier, resource: RESOURCE, client_assertion_type: ASSERTION_TYPE,
    client_assertion: assertion(CHATGPT, impostor, "cimd-20260428030119") });
  check(forged.status === 401 && /not signed by a key of this client/.test(forged.json?.error_description || ""),
    `...and signed by a key that is not ChatGPT's: ${forged.status} ${forged.json?.error_description}`);

  if (out) {
    console.log("\nthe sign-in page, as ChatGPT's person sees it");
    await consentInBrowser(email);
  }

  console.log("\na client shaped as ChatGPT, holding a key of its own");
  const key = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const jwk = { ...key.publicKey.export({ format: "jwk" }), kid: "stand-in-1", use: "sig", alg: "RS256" };
  const back = `http://127.0.0.1:${9640 + Math.floor(Math.random() * 20)}/connector/oauth/callback`;
  const reg = await call("/oauth/register", { method: "POST", body: { client_name: "ChatGPT stand-in",
    redirect_uris: [back], token_endpoint_auth_method: "private_key_jwt", token_endpoint_auth_signing_alg: "RS256",
    jwks: { keys: [jwk] }, grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] } });
  const id = reg.json?.client_id;
  check(reg.status === 201 && /^bwc_/.test(id || "") && !reg.json?.client_secret
      && reg.json?.token_endpoint_auth_method === "private_key_jwt", "registered with its public key: no secret");
  const p2 = pkce();
  const mine = await allow(session, { clientId: id, redirect: back, challenge: p2.challenge });
  check(mine.shown.json?.client === "ChatGPT stand-in" && mine.shown.json?.claude === false,
    `the sign-in page names it: ${mine.shown.json?.client}`);
  const t0 = Date.now();
  const tokens = await exchange({ grant_type: "authorization_code", code: mine.code, redirect_uri: back,
    client_id: id, code_verifier: p2.verifier, resource: RESOURCE, client_assertion_type: ASSERTION_TYPE,
    client_assertion: assertion(id, key, "stand-in-1") });
  const tk = tokens.json || {};
  check(tokens.status === 200 && /^bwa_/.test(tk.access_token || "") && /^bwr_/.test(tk.refresh_token || ""),
    `the code, its verifier and a signed assertion, for tokens in ${Date.now() - t0} ms`);

  console.log("\nthe MCP address, as ChatGPT uses it");
  const hello = await call(`${tab}&op=hello`, { method: "POST", headers: { authorization: `Bearer ${session}` },
    body: { instructions: "Brickworks (chatgpt_flow's tab)", tools: appTools } });
  check(hello.status === 204, `a tab of this account switches on, serving the app's ${appTools.length} tools`);
  const hi = await mcp(tk.access_token, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "openai-mcp", version: "1.0.0" } });
  const mcpSession = hi.headers.get("mcp-session-id") || "";
  check(hi.status === 200 && hi.json?.result?.serverInfo?.name === "brickworks" && mcpSession,
    `initialize: ${hi.json?.result?.serverInfo?.name}, protocol ${hi.json?.result?.protocolVersion}, a session id`);
  const listed = await mcp(tk.access_token, "tools/list", {}, 2, mcpSession);
  const tools = listed.json?.result?.tools || [];
  const bareOnes = tools.flatMap((tool) => bareArrays(tool.inputSchema, tool.name));
  const hinted = tools.filter((tool) => ["readOnlyHint", "destructiveHint", "openWorldHint"]
    .every((hint) => typeof tool.annotations?.[hint] === "boolean"));
  check(tools.length === appTools.length + 2 && tools.some((tool) => tool.name === "submit_design"),
    `tools/list: ${tools.length} tools, the app's and the relay's two`);
  check(bareOnes.length === 0, `every array says what its items are (${bareOnes.length} do not)`);
  check(hinted.length === tools.length, `all three hints on ${hinted.length} of ${tools.length}`);
  const asked = mcp(tk.access_token, "tools/call", { name: "search_parts", arguments: { query: "2 x 4" } }, 3,
    mcpSession);
  let taken = null;
  for (let tries = 0; tries < 8 && !taken; tries++) {
    const next = await call(`${tab}&op=next`, { method: "POST" });
    if (next.json?.request?.method === "tools/call") taken = next.json;
  }
  check(taken?.request?.params?.name === "search_parts" && taken?.request?.params?.arguments?.query === "2 x 4",
    "tools/call reaches this account's tab");
  if (taken) {
    await call(`${tab}&op=answer&id=${taken.id}`, { method: "POST", body: { jsonrpc: "2.0", id: taken.request.id,
      result: { content: [{ type: "text", text: "3001 Brick 2 x 4" }] } } });
  }
  const answered = await asked;
  check((answered.json?.result?.content || []).some((block) => block.text === "3001 Brick 2 x 4"),
    "...and the tab's answer reaches ChatGPT");

  console.log("\nrefresh");
  const signed = assertion(id, key, "stand-in-1");
  const r1 = await exchange({ grant_type: "refresh_token", refresh_token: tk.refresh_token, resource: RESOURCE,
    client_assertion_type: ASSERTION_TYPE, client_assertion: signed });
  check(r1.status === 200 && /^bwa_/.test(r1.json?.access_token || ""), "a refresh token and a fresh assertion: new tokens");
  const replayed = await exchange({ grant_type: "refresh_token", refresh_token: r1.json?.refresh_token,
    client_assertion_type: ASSERTION_TYPE, client_assertion: signed });
  check(replayed.status === 401 && /used before/.test(replayed.json?.error_description || ""),
    `the same assertion again: ${replayed.status} ${replayed.json?.error_description}`);
  const none = await exchange({ grant_type: "refresh_token", refresh_token: r1.json?.refresh_token, client_id: id });
  check(none.status === 401 && none.json?.error === "invalid_client", "a refresh token with no assertion: refused");
  const wrongAud = await exchange({ grant_type: "refresh_token", refresh_token: r1.json?.refresh_token,
    client_assertion_type: ASSERTION_TYPE,
    client_assertion: assertion(id, key, "stand-in-1", { aud: "https://elsewhere.example/oauth/token" }) });
  check(wrongAud.status === 401 && /aud/.test(wrongAud.json?.error_description || ""), "an assertion for another server: refused");
  const still = await mcp(r1.json?.access_token, "tools/list", {}, 4, mcpSession);
  check(still.status === 200, "the refreshed token works");

  console.log("\nClaude on the same account, as before");
  const p3 = pkce();
  const loop = `http://localhost:${40000 + Math.floor(Math.random() * 20000)}/callback`;
  const cc = await allow(session, { clientId: CLAUDE_CODE, redirect: loop, challenge: p3.challenge });
  const ccTokens = (await exchange({ grant_type: "authorization_code", code: cc.code, redirect_uri: loop,
    client_id: CLAUDE_CODE, code_verifier: p3.verifier, resource: RESOURCE })).json || {};
  check(cc.shown.json?.client === "Claude Code" && cc.shown.json?.claude === true && /^bwa_/.test(ccTokens.access_token || ""),
    "Claude Code signs in as a public client, with nothing more sent");
  const ccHi = await mcp(ccTokens.access_token, "initialize", { protocolVersion: "2025-06-18", capabilities: {},
    clientInfo: { name: "claude-code", version: "2.1.303" } });
  const ccList = (await mcp(ccTokens.access_token, "tools/list", {}, 5, ccHi.headers.get("mcp-session-id") || ""))
    .json?.result?.tools || [];
  const byName = new Map(appTools.map((tool) => [tool.name, tool]));
  const asSent = ccList.filter((tool) => byName.has(tool.name)).every((tool) => {
    const sent = byName.get(tool.name);
    const { target, ...props } = tool.inputSchema.properties || {};
    return Boolean(target) && canonical({ ...tool.inputSchema, properties: props })
      === canonical({ type: "object", ...sent.inputSchema, properties: sent.inputSchema.properties || {} })
      && canonical(tool.annotations) === canonical(sent.annotations) && tool.description === sent.description;
  });
  check(ccList.length === tools.length && asSent && ccList.some((tool) => bareArrays(tool.inputSchema, "").length),
    `Claude's ${ccList.length} tools are the tab's as it sent them, schemas and hints untouched`);

  console.log("\nthe account's connections");
  const mineNow = await call("/api/oauth?op=connections", { headers: { authorization: `Bearer ${session}` } });
  const names = (mineNow.json?.connections || []).map((one) => one.client);
  check(names.includes("ChatGPT stand-in") && names.includes("Claude Code"), `listed: ${names.join(", ")}`);
  await call(`${tab}&op=close`, { method: "POST" });
} finally {
  const removed = await deleteAccount(email);
  console.log(`\n  (${removed ? "removed" : "COULD NOT REMOVE"} the throwaway account, and its connections with it)`);
  if (!removed) failures += 1;
}

console.log(failures ? `\n${failures} FAILURE(S)` : "\nChatGPT can connect to Brickworks and build in its tab");
process.exit(failures ? 1 : 0);
