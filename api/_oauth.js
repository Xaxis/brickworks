// What the connector's sign-in (api/oauth.js) and the relay (api/mcp.js)
// both need to know about Claude's tokens: where this deployment is, what
// a token looks like, and whose connection one belongs to.
//
// A token is random and is never stored: supabase/oauth.sql keeps its
// SHA-256, so the database cannot be read back into a working token.

import { createHash, randomBytes } from "node:crypto";
import { db } from "./_db.js";

export const SCOPE = "build";
// claude.ai's published identity, which the Claude desktop and mobile apps
// share: the client a "custom connector" on a Claude account signs in as.
export const CLAUDE_AI = "https://claude.ai/oauth/mcp-oauth-client-metadata";
// The tokens' shapes: a prefix to tell them apart at a glance, and 32
// random bytes.
const ACCESS = /^bwa_[A-Za-z0-9_-]{43}$/;
const HOST = /^(?:[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*|\[::1\])(?::\d{1,5})?$/;
const LOOPBACK = /^(?:127\.0\.0\.1|localhost|\[::1\])(?::\d+)?$/;

export function sha256(text) {
  return createHash("sha256").update(text).digest("hex");
}

/// 32 random bytes, URL-safe, after a prefix saying what it is.
export function secret(prefix) {
  return `${prefix}_${randomBytes(32).toString("base64url")}`;
}

/// Where this deployment answers: https://brickworks.diy in production, a
/// preview's own address on a preview, http://127.0.0.1:PORT on this
/// machine. Taken from the request rather than written down, so a preview
/// is its own issuer and its tokens are good only there.
export function originOf(request) {
  const fixed = String(process.env.PUBLIC_ORIGIN || "").replace(/\/+$/, "");
  if (fixed) return fixed;
  const headers = request.headers || {};
  const host = String(headers["x-forwarded-host"] || headers.host || "").split(",")[0].trim();
  if (!HOST.test(host)) return "https://brickworks.diy";
  const said = String(headers["x-forwarded-proto"] || "").split(",")[0].trim();
  const proto = said === "http" || said === "https" ? said : LOOPBACK.test(host) ? "http" : "https";
  return `${proto}://${host}`;
}

/// The MCP server's own address: what Claude adds, and what every token
/// this deployment issues is for.
export function resourceOf(origin) {
  return `${origin}/api/mcp`;
}

/// What a 401 from the MCP address says, so a client knows where to sign
/// in: the protected resource metadata (RFC 9728), and why, if it had a
/// token that did not do.
export function challenge(origin, error = "") {
  const parts = [`resource_metadata="${origin}/.well-known/oauth-protected-resource/api/mcp"`,
    `scope="${SCOPE}"`];
  if (error) parts.unshift(`error="invalid_token"`, `error_description="${error}"`);
  return `Bearer ${parts.join(", ")}`;
}

/// The connection an access token belongs to, or null: unknown, expired,
/// for another deployment, or disconnected (its grant gone, and every
/// token with it).
export async function grantOf(token, resource) {
  if (!ACCESS.test(token || "")) return null;
  const rows = await db(`oauth_tokens?hash=eq.${sha256(token)}&kind=eq.access`
    + "&select=expires_at,grant:oauth_grants(id,owner,resource,client_name,redirect_uri,"
    + "client_info,channel,used_at,oc_rh,oc_aud,oc_iat)");
  const row = rows && rows[0];
  if (!row || !row.grant) return null;
  if (Date.parse(row.expires_at) <= Date.now()) return null;
  if (row.grant.resource !== resource) return null;
  // Approved while signed in with orangecheck (supabase/orangecheck.sql):
  // ended with that sign-in, everywhere; and while that cannot be known,
  // marked unsure, which the relay answers with "try again" rather than
  // "sign in". Loaded only for such a connection.
  const { oc_rh: rh, oc_aud: aud, oc_iat: iat, ...grant } = row.grant;
  if (rh) {
    const { grantStanding } = await import("./_oc.js");
    const standing = await grantStanding({ oc_rh: rh, oc_aud: aud, oc_iat: iat });
    if (standing === "revoked") {
      await db(`oauth_grants?id=eq.${grant.id}`, { method: "DELETE" });
      return null;
    }
    if (standing !== "live") grant.unsure = true;
  }
  return grant;
}

/// The account's record kept by the server alone (Supabase's app_metadata,
/// which nobody signed in can write): one request to the accounts' admin
/// API with the secret key. [change] is merged into it, key by key.
async function accountRecord(owner, change = null) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY;
  const reply = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(owner)}`, {
    method: change ? "PUT" : "GET",
    headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: change ? JSON.stringify({ app_metadata: change }) : undefined,
    signal: AbortSignal.timeout(15000),
  });
  if (!reply.ok) throw new Error(`accounts ${change ? "PUT" : "GET"}: ${reply.status}`);
  const user = await reply.json();
  return (user && user.app_metadata) || {};
}

/// That this account has had Claude (claude.ai and its apps) connected:
/// kept past a Disconnect, so connecting again can send the person to the
/// Brickworks connector they already have in Claude rather than to add a
/// second one.
export async function rememberClaude(owner) {
  await accountRecord(owner, { claude_connected_at: new Date().toISOString() });
}

/// Whether this account has ever had Claude connected (rememberClaude).
export async function hadClaude(owner) {
  return Boolean((await accountRecord(owner)).claude_connected_at);
}

/// Which Claude a connection is, in words for the panel: Claude (claude.ai
/// and the Claude apps share one list of connectors), Claude Code (a
/// program on somebody's machine, sent back to it on a loopback address),
/// or whatever another client called itself.
export function clientLabel(grant) {
  const info = grant.client_info && typeof grant.client_info === "object" ? grant.client_info : {};
  const said = `${grant.client_name || ""} ${info.name || ""}`.toLowerCase();
  let host = "";
  try {
    host = new URL(grant.redirect_uri || "").host.toLowerCase();
  } catch {
    host = "";
  }
  if (/(^|\.)claude\.(ai|com)$/.test(host)) return "Claude";
  if (said.includes("claude code") || said.includes("claude-code")) return "Claude Code";
  if (LOOPBACK.test(host) && said.includes("claude")) return "Claude Code";
  const name = String(grant.client_name || info.name || "").trim();
  return name ? name.slice(0, 60) : "An MCP client";
}
