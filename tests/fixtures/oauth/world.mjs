// What api/oauth.js's client checks talk to, in memory, behind the one
// fetch: the database's oauth_clients, oauth_grants, oauth_tokens and
// oc_spend, and the clients' published documents and keys. ChatGPT's and
// Claude's documents are as they read on 2026-10-29; ChatGPT's keys are a
// test key standing in for its own, since only ChatGPT holds that one.
// Every request is in [calls].
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
  // Codes, connections and their tokens, as rows (supabase/oauth.sql).
  const tables = { oauth_codes: [], oauth_grants: [], oauth_tokens: [] };
  // The sessions there are, by id (auth.sessions): {owner, way}, way the
  // one that started it ("google", "github") or null, and {oc_did, oc_rh,
  // oc_aud, oc_iat} when orangecheck did (oc_sessions). A code names one
  // (supabase/approving_session.sql): its key refuses any other (409).
  const sessions = new Map();
  // Whether "<account> <way>" signs the account in (way_links' state 'on'):
  // true, or unset or false for not.
  const ways = new Map();
  // Called before oauth_tokens' rows are written, as another request
  // could act just then: a test deletes a connection under a refresh here.
  const hooks = { beforeTokens: null };
  const grantRow = (body) => ({ id: randomUUID(), owner: body.owner, client_id: body.client,
    client_name: body.client_name, redirect_uri: body.redirect_uri, resource: body.resource, scope: body.scope });
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
    // A code's connection and its two tokens, written only while the
    // session that approved it is there, the account's, and its way still
    // signs the account in; or nothing, and why (oauth_code_grant).
    if (url.pathname === "/rest/v1/rpc/oauth_code_grant") {
      if (!body.session || !body.owner) return json(200, { refused: "unknown" });
      const session = sessions.get(body.session);
      if (!session || session.owner !== body.owner) return json(200, { refused: "gone" });
      if (session.way && ways.get(`${body.owner} ${session.way}`) !== true) return json(200, { refused: "unlinked" });
      const oc = session.oc_did ? { oc_did: session.oc_did, oc_rh: session.oc_rh, oc_aud: session.oc_aud,
        oc_iat: session.oc_iat } : { oc_did: null, oc_rh: null, oc_aud: null, oc_iat: null };
      const grant = { ...grantRow(body), way: session.way, session_id: body.session, ...oc };
      tables.oauth_grants.push(grant);
      tables.oauth_tokens.push(
        { id: randomUUID(), hash: body.access_hash, grant_id: grant.id, kind: "access", replaced_at: null,
          expires_at: body.access_until },
        { id: randomUUID(), hash: body.refresh_hash, grant_id: grant.id, kind: "refresh", replaced_at: null,
          expires_at: body.refresh_until });
      return json(200, { grant: grant.id, way: session.way, ...oc });
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
    const table = tables[url.pathname.replace("/rest/v1/", "")];
    if (table) {
      // PostgREST's eq, is.null and gt, which is all the token endpoint asks.
      const wanted = [...url.searchParams].filter(([name]) => name !== "select");
      const matches = (row) => wanted.every(([name, said]) => {
        const [op, ...rest] = said.split(".");
        const value = rest.join(".");
        if (op === "eq") return String(row[name]) === value;
        if (op === "is") return row[name] === null || row[name] === undefined;
        if (op === "gt") return Date.parse(row[name]) > Date.parse(value);
        throw new Error(`the test world has no filter ${op}`);
      });
      const found = table.filter(matches);
      if (method === "GET") return json(200, found);
      if (method === "POST") {
        const added = (Array.isArray(body) ? body : [body]).map((row) => ({ id: randomUUID(), ...row }));
        // The foreign keys: a code's to its session, a token's to its
        // connection. Refused whole, as PostgREST answers 23503.
        if (url.pathname.endsWith("/oauth_tokens") && hooks.beforeTokens) await hooks.beforeTokens(added);
        const orphan = url.pathname.endsWith("/oauth_codes")
          ? added.some((row) => row.session_id != null && !sessions.has(row.session_id))
          : url.pathname.endsWith("/oauth_tokens")
            && added.some((row) => !tables.oauth_grants.some((g) => g.id === row.grant_id));
        if (orphan) return json(409, { code: "23503", message: "violates foreign key constraint" });
        tables[url.pathname.replace("/rest/v1/", "")].push(...added);
        return json(201, added);
      }
      if (method === "PATCH") {
        for (const row of found) Object.assign(row, body);
        return json(200, found);
      }
      if (method === "DELETE") {
        for (const row of found) table.splice(table.indexOf(row), 1);
        // A connection's tokens go with it, as the foreign key cascades.
        if (url.pathname.endsWith("/oauth_grants")) {
          tables.oauth_tokens = tables.oauth_tokens.filter((one) => !found.some((g) => g.id === one.grant_id));
        }
        return json(200, found);
      }
    }
    return json(404, { message: `the test world has no ${method} ${url.pathname}` });
  };

  return {
    calls, clients, spent, documents, keys, chatgptKey, tables, sessions, ways, hooks,
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
