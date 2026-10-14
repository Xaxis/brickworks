// Claude signing in to a Brickworks account: the connector's
// authorization server (OAuth 2.1, as MCP's authorization spec asks).
//
// There is one connector address for everybody now,
// https://brickworks.diy/api/mcp. Someone adds it to Claude — one click
// from the app opens claude.ai's "Add custom connector" with it filled in
// — and Claude, finding it needs signing in to, comes here: it reads where
// to sign in (the metadata below), identifies itself, and sends the person
// to /oauth/authorize. That page (web/authorize.html) signs them in with
// the same email code as the app, or with the session the app already
// keeps in that browser, and asks whether Claude may build in Brickworks
// as them — once: while that account is connected to that same client, a
// connection made again (claude.ai reconnecting, another of Claude's apps)
// is answered at once, until Disconnect in the app ends it (remembered,
// 2026-10-14). Yes sends Claude back a code; Claude trades it here for a
// token that names their account, and the relay (api/mcp.js) sends each
// call it makes to that account's open tab, on whichever device.
//
// Routes (deploy.sh maps the public paths onto this function):
//   GET  /.well-known/oauth-protected-resource[/api/mcp]   ?op=resource
//   GET  /.well-known/oauth-authorization-server[/…]      ?op=metadata
//   POST /oauth/register     dynamic client registration    ?op=register
//   GET  /oauth/authorize    the page, web/authorize.html, which asks:
//   GET  /api/oauth?op=check      is this request one to show?
//   POST /api/oauth?op=remembered has the signed-in person said yes to this
//                                 client before? a code at once if so
//   POST /api/oauth?op=approve    yes, as the signed-in person: a code
//   POST /api/oauth?op=deny       no
//   POST /oauth/token        a code or a refresh token for tokens  ?op=token
//   POST /oauth/revoke       RFC 7009                       ?op=revoke
//   GET  /api/oauth?op=connections   the signed-in account's connections
//   POST /api/oauth?op=disconnect    end one (?id=) or all of them
//
// How Claude identifies itself. Claude (claude.ai, the desktop and mobile
// apps) and Claude Code each publish a Client ID Metadata Document: their
// client_id is its address, and it lists where they may be sent back to.
// Claude uses that when this server's metadata says it may, so most
// people never touch registration. Anything else registers itself
// (RFC 7591). Either way the client is public and proves itself with
// PKCE (S256 only). A return address must match one the client declared
// exactly, except that a loopback address (Claude Code's
// http://localhost:<any port>/callback) may name any port, as RFC 8252
// requires for a program on the person's own machine.
//
// What is kept (supabase/oauth.sql): codes good once, for two minutes;
// access tokens for an hour; refresh tokens until used, then replaced —
// all by SHA-256, never the token. A refresh token used twice, outside a
// few seconds' grace for a retry, ends the whole connection. Disconnect in
// the app deletes the connection, and every token of it goes with it.

import { timingSafeEqual } from "node:crypto";
import { AuthError, authConfigured, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { SCOPE, clientLabel, originOf, resourceOf, secret, sha256 } from "./_oauth.js";

const CODE_TTL_S = 120;
const ACCESS_TTL_S = 3600;
const REFRESH_TTL_S = 90 * 24 * 3600;
// A refresh token presented again this soon after it was replaced is a
// client retrying a request whose answer it lost, not a stolen copy.
const RETRY_GRACE_MS = 30_000;
// How long a client's published description is trusted before it is read
// again.
const DOCUMENT_TTL_MS = 3600_000;
const LOOPBACK = new Set(["localhost", "127.0.0.1", "[::1]"]);
const REGISTERED_ID = /^bwc_[A-Za-z0-9_-]{43}$/;
const CHALLENGE = /^[A-Za-z0-9_-]{43}$/;
const VERIFIER = /^[A-Za-z0-9._~-]{43,128}$/;
const METHODS = ["none", "client_secret_post", "client_secret_basic"];

const iso = (msFromNow = 0) => new Date(Date.now() + msFromNow).toISOString();
const text = (value, most = 2000) => (typeof value === "string" ? value.slice(0, most) : "");

// ---------------------------------------------------------------- metadata

function serverMetadata(origin) {
  return {
    issuer: origin,
    authorization_endpoint: `${origin}/oauth/authorize`,
    token_endpoint: `${origin}/oauth/token`,
    registration_endpoint: `${origin}/oauth/register`,
    revocation_endpoint: `${origin}/oauth/revoke`,
    // offline_access listed, so Claude asks for it and expects the refresh
    // token it is always given.
    scopes_supported: [SCOPE, "offline_access"],
    response_types_supported: ["code"],
    response_modes_supported: ["query"],
    grant_types_supported: ["authorization_code", "refresh_token"],
    code_challenge_methods_supported: ["S256"],
    // "none" and the document flag together are what make Claude use its
    // published description rather than register a new client each time.
    token_endpoint_auth_methods_supported: METHODS,
    revocation_endpoint_auth_methods_supported: METHODS,
    client_id_metadata_document_supported: true,
    authorization_response_iss_parameter_supported: true,
    service_documentation: `${origin}/faq#claude`,
  };
}

function resourceMetadata(origin) {
  return {
    resource: resourceOf(origin),
    authorization_servers: [origin],
    scopes_supported: [SCOPE],
    bearer_methods_supported: ["header"],
    resource_name: "Brickworks",
    resource_documentation: `${origin}/faq#claude`,
  };
}

// ---------------------------------------------------------------- clients

/// Somewhere a client may be sent back to: https anywhere, http only to
/// this machine, or a native app's own scheme — never one a browser would
/// run (javascript:, data:) or a fragment.
export function returnAddressAllowed(uri) {
  if (typeof uri !== "string" || uri.length > 500 || uri.includes("#")) return false;
  let url;
  try {
    url = new URL(uri);
  } catch {
    return false;
  }
  if (url.username || url.password) return false;
  if (url.protocol === "https:") return Boolean(url.hostname);
  if (url.protocol === "http:") return LOOPBACK.has(url.hostname);
  if (["javascript:", "data:", "file:", "blob:", "about:", "vbscript:", "ftp:", "ws:", "wss:"]
    .includes(url.protocol)) return false;
  return /^[a-z][a-z0-9+.-]*:$/.test(url.protocol);
}

/// Whether [given] is one of [declared]: exactly, or for a loopback
/// address the same in everything but the port.
export function returnAddressMatches(declared, given) {
  if (typeof given !== "string" || !given) return false;
  if (declared.includes(given)) return true;
  let asked;
  try {
    asked = new URL(given);
  } catch {
    return false;
  }
  if (asked.protocol !== "http:" || !LOOPBACK.has(asked.hostname)) return false;
  return declared.some((one) => {
    try {
      const mine = new URL(one);
      return mine.protocol === "http:" && mine.hostname === asked.hostname
        && mine.pathname === asked.pathname && mine.search === asked.search;
    } catch {
      return false;
    }
  });
}

/// A host a server should not be sent to fetch from on a stranger's say.
function privateHost(hostname) {
  return hostname === "localhost" || hostname.endsWith(".localhost")
    || hostname.endsWith(".local") || hostname.endsWith(".internal")
    || /^\d+\.\d+\.\d+\.\d+$/.test(hostname) || hostname.startsWith("[");
}

/// A client named by the address of its description: read it (or the
/// copy kept within the hour) and keep what it says.
async function documentClient(clientId) {
  let url;
  try {
    url = new URL(clientId);
  } catch {
    return null;
  }
  if (url.protocol !== "https:" || url.pathname === "/" || url.hash || url.username
      || privateHost(url.hostname)) return null;
  const rows = await db(`oauth_clients?client_id=eq.${encodeURIComponent(clientId)}&select=*`);
  const kept = rows && rows[0];
  if (kept && kept.fetched_at && Date.now() - Date.parse(kept.fetched_at) < DOCUMENT_TTL_MS) {
    return kept;
  }
  let said;
  try {
    const reply = await fetch(clientId, {
      redirect: "manual",
      headers: { accept: "application/json" },
      signal: AbortSignal.timeout(5000),
    });
    const body = reply.status === 200 ? await reply.text() : "";
    said = body.length > 0 && body.length <= 10_000 ? JSON.parse(body) : null;
  } catch {
    said = null;
  }
  // Unreadable just now: what was read before stands, for a while.
  if (!said) return kept || null;
  if (said.client_id !== clientId) return null;
  const uris = Array.isArray(said.redirect_uris)
    ? said.redirect_uris.filter(returnAddressAllowed).slice(0, 10) : [];
  // A document cannot carry a secret, so it is a public client or nothing.
  if (!uris.length || (said.token_endpoint_auth_method || "none") !== "none") return null;
  const row = {
    client_id: clientId,
    client_name: text(said.client_name, 200) || url.host,
    redirect_uris: uris,
    auth_method: "none",
    secret_hash: null,
    fetched_at: iso(),
  };
  await db("oauth_clients", { method: "POST", body: row, prefer: "resolution=merge-duplicates" });
  return { ...kept, ...row };
}

async function clientOf(clientId) {
  if (typeof clientId !== "string") return null;
  if (clientId.startsWith("https://") && clientId.length <= 512) return documentClient(clientId);
  if (!REGISTERED_ID.test(clientId)) return null;
  const rows = await db(`oauth_clients?client_id=eq.${clientId}&select=*`);
  return rows && rows[0] ? rows[0] : null;
}

/// RFC 7591. Open to anyone, as dynamic registration is; what it can do
/// is limited to the return addresses it names, which the person sees
/// before saying yes.
async function register(request, response) {
  const given = fields(request);
  const uris = given.redirect_uris;
  if (!Array.isArray(uris) || uris.length === 0 || uris.length > 10
      || !uris.every(returnAddressAllowed)) {
    return response.status(400).json({
      error: "invalid_redirect_uri",
      error_description: "redirect_uris: one to ten https addresses, loopback http, or an app's own scheme",
    });
  }
  const method = given.token_endpoint_auth_method || "none";
  if (!METHODS.includes(method)) {
    return response.status(400).json({
      error: "invalid_client_metadata",
      error_description: `token_endpoint_auth_method must be one of ${METHODS.join(", ")}`,
    });
  }
  if (Array.isArray(given.response_types) && !given.response_types.includes("code")) {
    return response.status(400).json({
      error: "invalid_client_metadata", error_description: "only response_type code",
    });
  }
  const clientId = secret("bwc");
  const clientSecret = method === "none" ? null : secret("bws");
  const name = text(given.client_name, 200) || null;
  await db("oauth_clients", {
    method: "POST",
    body: {
      client_id: clientId, client_name: name, redirect_uris: uris, auth_method: method,
      secret_hash: clientSecret ? sha256(clientSecret) : null,
    },
  });
  if (Math.random() < 0.05) await db("rpc/oauth_sweep", { method: "POST", body: {} }).catch(() => {});
  const answer = {
    client_id: clientId,
    client_id_issued_at: Math.floor(Date.now() / 1000),
    client_name: name,
    redirect_uris: uris,
    grant_types: ["authorization_code", "refresh_token"],
    response_types: ["code"],
    token_endpoint_auth_method: method,
    scope: SCOPE,
  };
  if (clientSecret) Object.assign(answer, { client_secret: clientSecret, client_secret_expires_at: 0 });
  return response.status(201).json(answer);
}

// ---------------------------------------------------------- authorization

/// The address of this server Claude asked for a token to, made canonical,
/// or null for somewhere else. Absent means this one.
function resourceAsked(given, origin) {
  const mine = resourceOf(origin);
  if (given === undefined || given === null || given === "") return mine;
  let url;
  try {
    url = new URL(String(given));
  } catch {
    return null;
  }
  if (url.search || url.hash) return null;
  const path = url.pathname.replace(/\/+$/, "");
  return `${url.origin}${path}` === mine || (`${url.origin}${path}` === origin) ? mine : null;
}

function withQuery(address, values) {
  const url = new URL(address);
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== null && value !== "") url.searchParams.set(key, value);
  }
  return url.toString();
}

/// An authorization request, checked. One of:
///   { ok, client, redirect, state, challenge, resource, scope }
///   { refuse: "why" }       nowhere safe to send the person back to
///   { back: url }           send them back to the client with an error
async function authorization(params, origin) {
  const client = await clientOf(params.client_id);
  if (!client) {
    return { refuse: "Brickworks does not know the app that sent you here. "
      + "Go back to it and add Brickworks again." };
  }
  let redirect = text(params.redirect_uri, 500);
  if (!redirect && client.redirect_uris.length === 1) redirect = client.redirect_uris[0];
  if (!returnAddressMatches(client.redirect_uris, redirect)) {
    return { refuse: "The app that sent you here asked to be answered at an "
      + "address it did not declare, so Brickworks will not send you there." };
  }
  const state = text(params.state);
  const back = (error, description) => ({
    back: withQuery(redirect, { error, error_description: description, state, iss: origin }),
  });
  if (params.response_type !== "code") {
    return back("unsupported_response_type", "only response_type=code");
  }
  if (!CHALLENGE.test(params.code_challenge || "") || params.code_challenge_method !== "S256") {
    return back("invalid_request", "PKCE is required: code_challenge with code_challenge_method=S256");
  }
  const resource = resourceAsked(params.resource, origin);
  if (!resource) return back("invalid_target", `this server issues tokens for ${resourceOf(origin)}`);
  return {
    ok: true, client, redirect, state, challenge: params.code_challenge, resource, scope: SCOPE,
  };
}

/// What the page shows before anyone says yes: who is asking, and where
/// the answer will go.
async function check(request, response, origin) {
  const asked = await authorization(request.query || {}, origin);
  if (asked.refuse) return response.status(400).json({ refuse: asked.refuse });
  if (asked.back) return response.status(200).json({ back: asked.back });
  const to = new URL(asked.redirect);
  const loopback = to.protocol === "http:" && LOOPBACK.has(to.hostname);
  return response.status(200).json({
    client: clientLabel({ client_name: asked.client.client_name, redirect_uri: asked.redirect }),
    client_name: asked.client.client_name || null,
    // The host the person will be sent back to, which the page shows
    // plainly (MCP's authorization spec asks for it).
    return_to: loopback ? `${to.hostname}:${to.port || "80"}` : to.host || to.protocol,
    loopback,
  });
}

/// Where the person goes back to with a code for [asked], as [owner].
async function codeFor(asked, owner, origin) {
  const code = secret("bwk");
  await db("oauth_codes", {
    method: "POST",
    body: {
      hash: sha256(code), client_id: asked.client.client_id, owner,
      redirect_uri: asked.redirect, code_challenge: asked.challenge,
      resource: asked.resource, scope: asked.scope, expires_at: iso(CODE_TTL_S * 1000),
    },
  });
  await db(`oauth_clients?client_id=eq.${encodeURIComponent(asked.client.client_id)}`, {
    method: "PATCH", body: { used_at: iso() },
  });
  return withQuery(asked.redirect, { code, state: asked.state, iss: origin });
}

async function approve(request, response, origin) {
  const claims = await signedIn(request, response);
  if (!claims) return response;
  const asked = await authorization(fields(request), origin);
  if (asked.refuse) return response.status(400).json({ refuse: asked.refuse });
  if (asked.back) return response.status(200).json({ redirect: asked.back });
  return response.status(200).json({ redirect: await codeFor(asked, claims.sub, origin) });
}

/// Asked by the page before it asks the person: has this account allowed
/// this client already? If it still holds a connection to it — the same
/// client, answered at the same return address, for this server — the code
/// is given at once and nothing is asked, as an OAuth server does once
/// someone has said yes. Otherwise { ask: true }. The client is the one
/// named by its id (the address of its published document, or the id
/// registration gave it), never another that calls itself by the same
/// name; a loopback client is remembered at the port it was allowed on.
/// Disconnect, a revocation, and a refresh token used by somebody else
/// each end the connection, and the next one asks again.
async function remembered(request, response, origin) {
  const claims = await signedIn(request, response);
  if (!claims) return response;
  const asked = await authorization(fields(request), origin);
  // A request the page would not ask about is the page's to explain.
  if (!asked.ok) return response.status(200).json({ ask: true });
  const allowed = await db(`oauth_grants?owner=eq.${claims.sub}`
    + `&client_id=eq.${encodeURIComponent(asked.client.client_id)}`
    + `&redirect_uri=eq.${encodeURIComponent(asked.redirect)}`
    + `&resource=eq.${encodeURIComponent(asked.resource)}&select=id&limit=1`);
  if (!allowed || !allowed.length) return response.status(200).json({ ask: true });
  return response.status(200).json({ redirect: await codeFor(asked, claims.sub, origin) });
}

async function deny(request, response, origin) {
  const asked = await authorization(fields(request), origin);
  if (asked.refuse) return response.status(400).json({ refuse: asked.refuse });
  if (asked.back) return response.status(200).json({ redirect: asked.back });
  return response.status(200).json({
    redirect: withQuery(asked.redirect, {
      error: "access_denied", error_description: "the person said no",
      state: asked.state, iss: origin,
    }),
  });
}

// ---------------------------------------------------------------- tokens

function oauthError(response, status, error, description) {
  return response.status(status).json({ error, error_description: description });
}

function sameSecret(given, hash) {
  if (typeof given !== "string" || !hash) return false;
  const a = Buffer.from(sha256(given), "hex");
  const b = Buffer.from(hash, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

/// The client making a token or revocation request, with its secret
/// checked if it has one; null if it is unknown or the secret is wrong.
async function callingClient(request, given) {
  let clientId = given.client_id;
  let clientSecret = given.client_secret;
  const basic = /^Basic\s+(.+)$/i.exec(String(request.headers?.authorization || ""));
  if (basic) {
    const [id, ...rest] = Buffer.from(basic[1], "base64").toString("utf8").split(":");
    try {
      clientId = decodeURIComponent(id);
      clientSecret = decodeURIComponent(rest.join(":"));
    } catch {
      return null;
    }
  }
  const client = await clientOf(clientId);
  if (!client) return null;
  if (client.auth_method !== "none" && !sameSecret(clientSecret, client.secret_hash)) return null;
  return client;
}

function verifierMatches(verifier, challenge) {
  if (!VERIFIER.test(verifier || "")) return false;
  const made = Buffer.from(sha256Base64Url(verifier));
  const want = Buffer.from(challenge);
  return made.length === want.length && timingSafeEqual(made, want);
}

function sha256Base64Url(value) {
  return Buffer.from(sha256(value), "hex").toString("base64url");
}

async function issue(grant) {
  const access = secret("bwa");
  const refresh = secret("bwr");
  await db("oauth_tokens", {
    method: "POST",
    body: [
      { hash: sha256(access), grant_id: grant.id, kind: "access", expires_at: iso(ACCESS_TTL_S * 1000) },
      { hash: sha256(refresh), grant_id: grant.id, kind: "refresh", expires_at: iso(REFRESH_TTL_S * 1000) },
    ],
  });
  return {
    access_token: access,
    token_type: "Bearer",
    expires_in: ACCESS_TTL_S,
    refresh_token: refresh,
    scope: grant.scope || SCOPE,
  };
}

/// The person's open tabs hear that Claude has just been connected, so the
/// panel can say so without asking.
async function tellTabs(owner, client) {
  const since = iso(-45_000);
  const tabs = await db(`relay_tabs?owner=eq.${owner}&open=is.true&seen_at=gt.${since}&select=channel`);
  if (!tabs || !tabs.length) return;
  await db("relay", {
    method: "POST",
    body: tabs.map((tab) => ({
      channel: tab.channel,
      request: { jsonrpc: "2.0", method: "brickworks/connected", params: { client } },
    })),
  });
}

async function token(request, response, origin) {
  response.setHeader("pragma", "no-cache");
  const given = fields(request);
  const client = await callingClient(request, given);
  if (!client) return oauthError(response, 401, "invalid_client", "unknown client, or a wrong secret");

  if (given.grant_type === "authorization_code") {
    if (typeof given.code !== "string" || !given.code_verifier) {
      return oauthError(response, 400, "invalid_request", "code and code_verifier are required");
    }
    // Deleted as it is read: a code works once, whoever presents it first.
    const [row] = await db(`oauth_codes?hash=eq.${sha256(given.code)}`, {
      method: "DELETE", prefer: "return=representation",
    }) || [];
    if (!row || Date.parse(row.expires_at) <= Date.now() || row.client_id !== client.client_id) {
      return oauthError(response, 400, "invalid_grant", "that code is unknown, used or expired");
    }
    if (given.redirect_uri !== row.redirect_uri) {
      return oauthError(response, 400, "invalid_grant", "redirect_uri is not the one the code was issued to");
    }
    if (!verifierMatches(given.code_verifier, row.code_challenge)) {
      return oauthError(response, 400, "invalid_grant", "code_verifier does not match the code_challenge");
    }
    if (given.resource !== undefined && resourceAsked(given.resource, origin) !== row.resource) {
      return oauthError(response, 400, "invalid_target", "resource is not the one the code was issued for");
    }
    const [grant] = await db("oauth_grants", {
      method: "POST",
      body: {
        owner: row.owner, client_id: client.client_id, client_name: client.client_name,
        redirect_uri: row.redirect_uri, resource: row.resource, scope: row.scope, used_at: iso(),
      },
      prefer: "return=representation",
    });
    const tokens = await issue(grant);
    await tellTabs(row.owner, clientLabel(grant)).catch(() => {});
    if (Math.random() < 0.1) await db("rpc/oauth_sweep", { method: "POST", body: {} }).catch(() => {});
    return response.status(200).json(tokens);
  }

  if (given.grant_type === "refresh_token") {
    const presented = typeof given.refresh_token === "string" ? given.refresh_token : "";
    if (!/^bwr_[A-Za-z0-9_-]{43}$/.test(presented)) {
      return oauthError(response, 400, "invalid_grant", "that refresh token is unknown");
    }
    const hash = sha256(presented);
    // Replaced as it is read, so two requests cannot both trade it.
    const traded = await db(
      `oauth_tokens?hash=eq.${hash}&kind=eq.refresh&replaced_at=is.null&expires_at=gt.${iso()}`,
      { method: "PATCH", body: { replaced_at: iso() }, prefer: "return=representation" });
    let grantId = traded && traded[0] ? traded[0].grant_id : null;
    if (!grantId) {
      const [seen] = await db(`oauth_tokens?hash=eq.${hash}&kind=eq.refresh&select=grant_id,replaced_at,expires_at`) || [];
      if (seen && seen.replaced_at && Date.parse(seen.expires_at) > Date.now()
          && Date.now() - Date.parse(seen.replaced_at) < RETRY_GRACE_MS) {
        grantId = seen.grant_id;
      } else {
        if (seen && seen.replaced_at) {
          // Used again long after it was replaced: somebody else has a copy.
          // The connection ends, and the person connects Claude again.
          await db(`oauth_grants?id=eq.${seen.grant_id}`, { method: "DELETE" });
        }
        return oauthError(response, 400, "invalid_grant", "that refresh token is no longer good");
      }
    }
    const [grant] = await db(`oauth_grants?id=eq.${grantId}&select=id,client_id,resource,scope,owner`) || [];
    if (!grant || grant.client_id !== client.client_id) {
      return oauthError(response, 400, "invalid_grant", "that refresh token is no longer good");
    }
    if (given.resource !== undefined && resourceAsked(given.resource, origin) !== grant.resource) {
      return oauthError(response, 400, "invalid_target", "resource is not the one the token was issued for");
    }
    await db(`oauth_grants?id=eq.${grant.id}`, { method: "PATCH", body: { used_at: iso() } });
    return response.status(200).json(await issue(grant));
  }

  return oauthError(response, 400, "unsupported_grant_type",
    "grant_type must be authorization_code or refresh_token");
}

/// RFC 7009: always 200, whether or not the token meant anything. A
/// refresh token ends its whole connection; an access token only itself.
async function revoke(request, response) {
  const given = fields(request);
  const presented = typeof given.token === "string" ? given.token : "";
  if (!/^bw[ar]_[A-Za-z0-9_-]{43}$/.test(presented)) return response.status(200).end();
  const [row] = await db(`oauth_tokens?hash=eq.${sha256(presented)}`
    + "&select=kind,grant_id,grant:oauth_grants(client_id)") || [];
  if (!row) return response.status(200).end();
  if (given.client_id && row.grant && row.grant.client_id !== given.client_id) {
    return response.status(200).end();
  }
  if (row.kind === "refresh") {
    await db(`oauth_grants?id=eq.${row.grant_id}`, { method: "DELETE" });
  } else {
    await db(`oauth_tokens?hash=eq.${sha256(presented)}`, { method: "DELETE" });
  }
  return response.status(200).end();
}

// ------------------------------------------------- the account's own view

async function signedIn(request, response) {
  try {
    return await verify(bearer(request));
  } catch (trouble) {
    response.status(trouble instanceof AuthError ? trouble.status : 401)
      .json({ error: trouble.message });
    return null;
  }
}

async function connections(request, response) {
  const claims = await signedIn(request, response);
  if (!claims) return response;
  const rows = await db(`oauth_grants?owner=eq.${claims.sub}`
    + "&select=id,client_name,redirect_uri,client_info,created_at,used_at&order=created_at.desc") || [];
  return response.status(200).json({
    connections: rows.map((grant) => ({
      id: grant.id,
      client: clientLabel(grant),
      since: grant.created_at,
      last_used: grant.used_at,
    })),
  });
}

async function disconnect(request, response) {
  const claims = await signedIn(request, response);
  if (!claims) return response;
  const id = String(request.query?.id || "");
  if (id && !/^[0-9a-f-]{36}$/.test(id)) return response.status(400).json({ error: "no such connection" });
  const gone = await db(`oauth_grants?owner=eq.${claims.sub}${id ? `&id=eq.${id}` : ""}`, {
    method: "DELETE", prefer: "return=representation",
  }) || [];
  return response.status(200).json({ disconnected: gone.length });
}

// ---------------------------------------------------------------- routing

/// The request's fields, whichever way they came: Vercel parses JSON and
/// form bodies into an object; a plain server hands over the text.
function fields(request) {
  let body = request.body;
  if (Buffer.isBuffer(body)) body = body.toString("utf8");
  if (typeof body === "string") {
    const raw = body.trim();
    if (raw.startsWith("{")) {
      try {
        return JSON.parse(raw);
      } catch {
        return {};
      }
    }
    return Object.fromEntries(new URLSearchParams(raw));
  }
  return body && typeof body === "object" ? body : {};
}

export default async function handler(request, response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Cache-Control", "no-store");
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Headers", "authorization, content-type, mcp-protocol-version")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }
  const origin = originOf(request);
  const op = String(request.query?.op || "");

  // Metadata needs nothing configured, and says nothing about anybody.
  if (op === "resource" || op === "metadata") {
    if (request.method !== "GET" && request.method !== "HEAD") return response.status(405).end();
    response.setHeader("Cache-Control", "public, max-age=300");
    return response.status(200).json(op === "resource" ? resourceMetadata(origin) : serverMetadata(origin));
  }
  if (!dbConfigured() || !authConfigured()) {
    return response.status(503).json({
      error: "temporarily_unavailable",
      error_description: "accounts are not configured on this deployment",
    });
  }
  const wants = { check: "GET", connections: "GET" }[op] || "POST";
  if (request.method !== wants) return response.status(405).setHeader("allow", wants).end();
  try {
    switch (op) {
      case "register": return await register(request, response);
      case "check": return await check(request, response, origin);
      case "approve": return await approve(request, response, origin);
      case "remembered": return await remembered(request, response, origin);
      case "deny": return await deny(request, response, origin);
      case "token": return await token(request, response, origin);
      case "revoke": return await revoke(request, response);
      case "connections": return await connections(request, response);
      case "disconnect": return await disconnect(request, response);
      default: return response.status(404).json({ error: `no op ${op}` });
    }
  } catch (trouble) {
    console.error(`oauth ${op}: ${String(trouble?.message || trouble).slice(0, 200)}`);
    return response.status(502).json({
      error: "temporarily_unavailable",
      error_description: "Brickworks could not reach its database just now; try again",
    });
  }
}
