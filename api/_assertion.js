// A client proving at the token endpoint that it is who it says, with a
// JWT it signed (private_key_jwt: RFC 7523 section 2.2, RFC 7521 section
// 4.2). ChatGPT does (2026-10-29): its Client ID Metadata Document,
// https://chatgpt.com/oauth/client.json, says private_key_jwt, RS256, and
// where its public keys are (jwks_uri). A client that registered here may
// too, with the public keys it gave (RFC 7591's jwks).
//
// What is checked, in this order: signature before any claim, so nothing
// an attacker wrote is believed before it is known who wrote it.
//
//   the JWT's shape, and RS256: never "none", never a shared secret;
//   the signature, by one of the client's RSA keys (the kid's, if named);
//   iss and sub, both the client's id;
//   aud, naming this server: its issuer or its token endpoint;
//   exp ahead, and no more than an hour ahead; nbf and iat not ahead;
//   jti, spent once: the same assertion presented twice is refused.
//
// The keys at a jwks_uri are read and kept an hour, as a client's document
// is (api/oauth.js), and read again at once when the kid named is not
// among them (a key rotated), at most once a minute.

import { createPublicKey, verify } from "node:crypto";

export const ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
const KEYS_TTL_MS = 3600_000;
const AGAIN_MS = 60_000;
const SKEW_S = 60;
const LONGEST_S = 3600;
const MOST_BYTES = 8192;
const SMALLEST_RSA = 2048;

const kept = new Map(); // jwks_uri -> { at, keys, again }: read at, read again at

function part(text) {
  try {
    const value = JSON.parse(Buffer.from(text, "base64url").toString("utf8"));
    return value && typeof value === "object" && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
}

/// The client an assertion says it is from, unchecked: only to find the
/// client whose keys check it. Null if it is not a JWT naming one.
export function claimedClient(assertion) {
  if (typeof assertion !== "string" || assertion.length > MOST_BYTES) return null;
  const parts = assertion.split(".");
  const claims = parts.length === 3 ? part(parts[1]) : null;
  return claims && typeof claims.iss === "string" ? claims.iss : null;
}

/// The public keys at [uri]: kept within the hour, or read again when
/// [fresh] (a kid not among them) unless that was done in the last minute.
/// Throws when there are none to be had.
export async function keysAt(uri, { fresh = false } = {}) {
  const was = kept.get(uri);
  const now = Date.now();
  if (was && !fresh && now - was.at < KEYS_TTL_MS) return was.keys;
  if (was && fresh && now - (was.again || 0) < AGAIN_MS) return was.keys;
  let keys = null;
  try {
    const reply = await fetch(uri, {
      redirect: "manual",
      headers: { accept: "application/json" },
      signal: AbortSignal.timeout(5000),
    });
    const body = reply.status === 200 ? await reply.text() : "";
    const said = body.length > 0 && body.length <= 50_000 ? JSON.parse(body) : null;
    keys = said && Array.isArray(said.keys) ? said.keys.slice(0, 20) : null;
  } catch {
    keys = null;
  }
  // Unreadable just now: the keys read before stand, for a while.
  if (!keys) {
    if (!was) throw new Error("its keys could not be read");
    if (fresh) was.again = now;
    return was.keys;
  }
  kept.set(uri, { at: now, keys, again: fresh ? now : was?.again || 0 });
  return keys;
}

/// Tests: forget every kept key set, as a cold instance has none.
export function forgetKeys() {
  kept.clear();
}

/// [key] as a public key to check RS256 with, or null: an RSA key of at
/// least 2048 bits that is for signing, if it says.
function rsaKey(key) {
  if (!key || key.kty !== "RSA" || typeof key.n !== "string" || typeof key.e !== "string") return null;
  if (key.use !== undefined && key.use !== "sig") return null;
  if (key.alg !== undefined && key.alg !== "RS256") return null;
  try {
    const made = createPublicKey({ key: { kty: "RSA", n: key.n, e: key.e }, format: "jwk" });
    return made.asymmetricKeyDetails.modulusLength >= SMALLEST_RSA ? made : null;
  } catch {
    return null;
  }
}

function signedBy(keys, kid, data, signature) {
  const named = keys.filter((key) => kid === undefined || key.kid === kid);
  return named.some((key) => {
    const made = rsaKey(key);
    return Boolean(made) && verify("sha256", data, made, signature);
  });
}

/// Why [assertion] does not prove the caller is [clientId], or null when it
/// does. [keysOf]({fresh}) gives the client's public keys; [audiences] the
/// names this server answers to; [spend](key, untilSeconds) is true the
/// first time a key is spent and false ever after. The jti is spent last,
/// so an assertion that fails anything else spends nothing.
export async function assertionTrouble(assertion, { clientId, keysOf, audiences, spend, now = Date.now() }) {
  if (typeof assertion !== "string" || assertion.length > MOST_BYTES) return "client_assertion is not a JWT";
  const parts = assertion.split(".");
  if (parts.length !== 3) return "client_assertion is not a JWT";
  const header = part(parts[0]);
  const claims = part(parts[1]);
  if (!header || !claims) return "client_assertion is not a JWT";
  if (header.alg !== "RS256") return "client_assertion must be signed RS256";
  if (header.crit !== undefined) return "client_assertion names a critical header this server does not know";
  const kid = typeof header.kid === "string" ? header.kid : undefined;
  const data = Buffer.from(`${parts[0]}.${parts[1]}`);
  const signature = Buffer.from(parts[2], "base64url");
  let keys;
  try {
    keys = await keysOf({ fresh: false });
    if (kid !== undefined && !keys.some((key) => key.kid === kid)) keys = await keysOf({ fresh: true });
  } catch (trouble) {
    return `client_assertion cannot be checked: ${String(trouble?.message || trouble).slice(0, 80)}`;
  }
  if (!signedBy(keys, kid, data, signature)) return "client_assertion is not signed by a key of this client";

  if (claims.iss !== clientId || claims.sub !== clientId) return "client_assertion's iss and sub must be the client_id";
  const named = (Array.isArray(claims.aud) ? claims.aud : [claims.aud])
    .filter((one) => typeof one === "string").map((one) => one.replace(/\/+$/, ""));
  if (!named.some((one) => audiences.includes(one))) return "client_assertion's aud must name this server";
  const seconds = Math.floor(now / 1000);
  if (!Number.isFinite(claims.exp)) return "client_assertion has no exp";
  if (claims.exp <= seconds - SKEW_S) return "client_assertion has expired";
  if (claims.exp > seconds + LONGEST_S + SKEW_S) return "client_assertion lasts longer than an hour";
  if (claims.nbf !== undefined && !(Number.isFinite(claims.nbf) && claims.nbf <= seconds + SKEW_S)) {
    return "client_assertion is not valid yet";
  }
  if (claims.iat !== undefined && !(Number.isFinite(claims.iat) && claims.iat <= seconds + SKEW_S)) {
    return "client_assertion was issued in the future";
  }
  if (typeof claims.jti !== "string" || !claims.jti || claims.jti.length > 256) return "client_assertion has no jti";
  if (!(await spend(claims.jti, Math.ceil(claims.exp + SKEW_S)))) return "client_assertion was used before";
  return null;
}

/// The public keys a client gave, as kept: one to five RSA signing keys, or
/// null for anything else.
export function givenKeys(jwks) {
  const keys = jwks && typeof jwks === "object" && Array.isArray(jwks.keys) ? jwks.keys : null;
  if (!keys || keys.length < 1 || keys.length > 5 || JSON.stringify(jwks).length > 10_000) return null;
  if (!keys.every((key) => rsaKey(key))) return null;
  return { keys: keys.map(({ kty, kid, use, alg, n, e }) => ({ kty, kid, use, alg, n, e })) };
}
