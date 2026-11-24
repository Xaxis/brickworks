// A Supabase session for an account, minted by the server: what signing in
// with orangecheck (api/orangecheck.js) and with Google or GitHub
// (api/_ways.js) hand the person, the same kind of session an emailed code
// gives, so the page keeps it where the app finds it.
//
// A one-time link for the account's address, asked of the admin API
// without sending anything, and redeemed at once. Each step must name the
// account, or nothing is handed out. An account has one such link at a
// time, so two sign-ins of it at once (two tabs, or two first sign-ins
// racing) can each spoil the other's: the one refused asks again, after a
// moment that differs each time.

import { reach } from "./_db.js";

function supabase() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

function admin() {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" };
}

export function claimsOf(jwt) {
  try {
    return JSON.parse(Buffer.from(String(jwt).split(".")[1], "base64url").toString("utf8"));
  } catch {
    return {};
  }
}

/// A session for [email]'s account: {session, sessionId, account, user}.
/// [account], when given, is the account it must be. [vet], when given, is
/// shown the account (Supabase's user) before the link is redeemed, and
/// throws (or rejects) to stop: nothing is minted or handed out then.
/// Throws with spoiled after four links spoiled in a row, with busy when
/// Supabase's verify answered 429 (it counts redemptions by address, and
/// every one of these is this server's).
export async function mintedSession(email, { account = null, vet = null } = {}) {
  for (let attempt = 1; ; attempt += 1) {
    try {
      return await redeemed(email, account, vet);
    } catch (trouble) {
      if (attempt >= 4 || !trouble.spoiled) throw trouble;
      await new Promise((done) => setTimeout(done, 100 + Math.random() * 400 * attempt));
    }
  }
}

async function redeemed(email, account, vet) {
  const link = await reach("auth POST admin/generate_link", 10, `${supabase()}/auth/v1/admin/generate_link`, {
    method: "POST", headers: admin(),
    body: JSON.stringify({ type: "magiclink", email }) });
  const made = await link.json().catch(() => ({}));
  const hashed = made.hashed_token || made.properties?.hashed_token;
  const id = made.id || made.user?.id;
  if (!link.ok || !hashed || !id || (account && id !== account)) throw new Error(`auth: no link: ${link.status}`);
  if (vet) await vet(made.user || made);
  const verify = await reach("auth POST verify", 10, `${supabase()}/auth/v1/verify`, {
    method: "POST",
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
    body: JSON.stringify({ type: "magiclink", token_hash: hashed }) });
  const session = await verify.json().catch(() => ({}));
  if (verify.status === 403 || verify.status === 401) {
    throw Object.assign(new Error(`auth: the link was spoiled: ${verify.status}`), { spoiled: true });
  }
  if (verify.status === 429) throw Object.assign(new Error("auth: verify answered 429"), { busy: true });
  const claims = claimsOf(session.access_token);
  if (!verify.ok || !session.refresh_token || session.user?.id !== id || claims.sub !== id || !claims.session_id) {
    throw new Error(`auth: the session was not for this account: ${verify.status}`);
  }
  return { session, sessionId: claims.session_id, account: id, user: made.user || made };
}
