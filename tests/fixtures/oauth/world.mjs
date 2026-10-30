// What api/oauth.js's client checks talk to, in memory, behind the one
// fetch: the database's oauth_clients and oc_spend, and the clients'
// published documents and keys. ChatGPT's and Claude's documents are as
// they read on 2026-10-29; ChatGPT's keys are a test key standing in for
// its own, since only ChatGPT holds that one. Every request is in [calls].
//
//   const w = await world();
//   const jwt = w.sign({ iss: CHATGPT, sub: CHATGPT, aud: `${ORIGIN}/oauth/token` });
//   const { client, why } = await oauth.callingClient(w.request(), { client_assertion: jwt, ... }, ORIGIN);

import { generateKeyPairSync, randomUUID, sign } from "node:crypto";

export const ORIGIN = "https://brickworks.test";
export const CHATGPT = "https://chatgpt.com/oauth/client.json";
export const CHATGPT_KEYS = "https://chatgpt.com/oauth/jwks.json";
export const CLAUDE = "https://claude.ai/oauth/mcp-oauth-client-metadata";
export const ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
const DB = "https://db.test";

const b64url = (value) => Buffer.from(typeof value === "string" ? value : JSON.stringify(value)).toString("base64url");

export function keyPair() {
  return generateKeyPairSync("rsa", { modulusLength: 2048 });
}

export function publicJwk(pair, kid) {
  return { ...pair.publicKey.export({ format: "jwk" }), kid, use: "sig", alg: "RS256" };
}

export async function world() {
  process.env.SUPABASE_URL = DB;
  process.env.SUPABASE_SECRET_KEY = "secret";
  process.env.SUPABASE_PUBLISHABLE_KEY = "publishable";
  const chatgptKey = keyPair();
  const clients = new Map();
  const spent = new Map();
  const calls = [];
  const documents = new Map([
    [CHATGPT, {
      client_id: CHATGPT, client_uri: "https://chatgpt.com/",
      redirect_uris: ["https://chatgpt.com/connector_platform_oauth_redirect"],
      token_endpoint_auth_method: "private_key_jwt", token_endpoint_auth_methods_supported: ["none", "private_key_jwt"],
      grant_types: ["authorization_code", "refresh_token"], response_types: ["code"], client_name: "ChatGPT",
      token_endpoint_auth_signing_alg: "RS256", jwks_uri: CHATGPT_KEYS,
    }],
    [CLAUDE, {
      client_id: CLAUDE, client_name: "Claude", client_uri: "https://claude.ai",
      redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
      grant_types: ["authorization_code", "refresh_token", "urn:ietf:params:oauth:grant-type:jwt-bearer"],
      response_types: ["code"], token_endpoint_auth_method: "none",
    }],
  ]);
  const keys = new Map([[CHATGPT_KEYS, { keys: [publicJwk(chatgptKey, "cimd-test")] }]]);
  const json = (status, body) => new Response(body === undefined ? "" : JSON.stringify(body), { status });

  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const method = (init.method || "GET").toUpperCase();
    calls.push(`${method} ${url.origin}${url.pathname}`);
    if (url.origin !== DB) {
      const found = documents.get(url.href) || keys.get(url.href);
      return found ? json(200, found) : json(404, { error: "not here" });
    }
    const body = init.body ? JSON.parse(String(init.body)) : undefined;
    if (url.pathname === "/rest/v1/rpc/oc_spend") {
      if (spent.has(body.token_id)) return json(200, false);
      spent.set(body.token_id, body.until);
      return json(200, true);
    }
    if (url.pathname.startsWith("/rest/v1/rpc/")) return json(204);
    if (url.pathname === "/rest/v1/oauth_clients") {
      if (method === "GET") {
        const id = decodeURIComponent((url.search.match(/client_id=eq\.([^&]+)/) || [])[1] || "");
        return json(200, clients.has(id) ? [clients.get(id)] : []);
      }
      if (method === "POST") {
        clients.set(body.client_id, { ...(clients.get(body.client_id) || {}), ...body });
        return json(201);
      }
    }
    return json(404, { message: `the test world has no ${method} ${url.pathname}` });
  };

  return {
    calls, clients, spent, documents, keys, chatgptKey,
    /// A request with these headers, as Vercel hands one over.
    request: (headers = {}) => ({ method: "POST", headers, query: {} }),
    /// A client assertion: [claims] over the usual ones, signed by [pair]
    /// (ChatGPT's test key unless said) as [alg] with [kid].
    sign(claims = {}, { pair = chatgptKey, kid = "cimd-test", alg = "RS256", client = CHATGPT } = {}) {
      const now = Math.floor(Date.now() / 1000);
      const header = b64url({ alg, kid, typ: "JWT" });
      const body = b64url({ iss: client, sub: client, aud: `${ORIGIN}/oauth/token`, iat: now, exp: now + 300,
        jti: randomUUID(), ...claims });
      const signature = sign("sha256", Buffer.from(`${header}.${body}`), pair.privateKey).toString("base64url");
      return `${header}.${body}.${signature}`;
    },
  };
}

/// One request through api/oauth.js's handler, as Vercel would make it.
export async function askOAuth({ method = "GET", query = {}, headers = {}, body } = {}) {
  const { default: handle } = await import("../../../api/oauth.js");
  let status = 0;
  let json = null;
  const response = {
    setHeader: () => response,
    status: (s) => { status = s; return response; },
    json: (b) => { json = b; return response; },
    end: () => response,
  };
  await handle({ method, query, headers: { host: "brickworks.test", ...headers }, body }, response);
  return { status, json };
}
