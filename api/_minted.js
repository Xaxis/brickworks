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

import { isIP } from "node:net";
import { db, reach } from "./_db.js";

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
///
/// [count], {key, per, minutes}: the one limit on minted sign-ins
/// (signin6), per identity that its provider has verified (a Google or
/// GitHub account, an orangecheck id: api/_ways.js COUNTED), never per
/// network. Counted once, after [vet] passes and right before the verify it
/// protects, so a try refused before it counts nothing; and given back when
/// the verify answers 429 or no answer comes (signreview4 R4-4: during a
/// rush, each of a person's retries counted, and once it ended they waited
/// up to 15 minutes more). A link spoiled by another sign-in of the same
/// account spent a verify, and stays counted. Over it: throws with often,
/// and nothing is redeemed. When the count cannot be asked: throws with
/// uncounted, and nothing is either.
///
/// [from], the address of the person signing in (clientAddress): Supabase
/// is told it (Sb-Forwarded-For, with the secret key, the only key it takes
/// it from), so that once the project counts verifies by the address it
/// forwards (security_sb_forwarded_for_enabled, the lead's to turn on), a
/// minted sign-in spends the verifies of the person's own address, as their
/// emailed code does, and not the server's, which every minted sign-in
/// shared (R4-2: nine free provider accounts held it empty). Until then
/// Supabase counts the server's address, as before.
export async function mintedSession(email, { account = null, vet = null, count = null, from = null } = {}) {
  let held = null;
  const once = async () => {
    if (!count || held) return;
    let one;
    try {
      one = await counted(count.key, count.per, count.minutes);
    } catch (trouble) {
      throw Object.assign(new Error(`auth: not counted: ${String(trouble?.message || trouble).slice(0, 120)}`), { uncounted: true });
    }
    if (!one) throw Object.assign(new Error("auth: too many sign-ins of this identity"), { often: true });
    held = one;
  };
  for (let attempt = 1; ; attempt += 1) {
    try {
      return await redeemed(email, account, vet, once, from);
    } catch (trouble) {
      if (trouble.unspent && held) {
        await givenBack(count.key, held);
        held = null;
      }
      if (attempt >= 4 || !trouble.spoiled) throw trouble;
      await new Promise((done) => setTimeout(done, 100 + Math.random() * 400 * attempt));
    }
  }
}

/// One try of [key] counted, when it has had fewer than [per] in the last
/// [minutes]: {at}, which gives it back (givenBack); null, and nothing
/// counted, when it has had that many. Throws when it cannot be asked.
/// Before supabase/way_try_back.sql is applied, way_may_try counts it, and
/// it cannot be given back ({at: null}).
export async function counted(key, per, minutes) {
  const body = { try_key: key, per, window_minutes: minutes };
  try {
    const at = await db("rpc/way_try", { method: "POST", body });
    return at ? { at } : null;
  } catch (trouble) {
    if (!/rpc\/way_try: 404$/.test(String(trouble?.message || ""))) throw trouble;
  }
  return (await db("rpc/way_may_try", { method: "POST", body })) === true ? { at: null } : null;
}

/// The try [one] counted under [key] given back. Never throws: one not given
/// back stays counted, and the log says so.
export async function givenBack(key, one) {
  if (!one?.at) return;
  try {
    await db("rpc/way_try_back", { method: "POST", body: { try_key: key, tried_at: one.at } });
  } catch (trouble) {
    console.error(`auth: a try was not given back: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
}

/// The address [request] came from, for Supabase to count a minted
/// sign-in's verify by: x-forwarded-for's first, which Vercel writes itself
/// and never takes from the caller, else the socket's. null when it is not
/// an address.
export function clientAddress(request) {
  const said = String(request?.headers?.["x-forwarded-for"] || "").split(",")[0].trim()
    || String(request?.socket?.remoteAddress || "");
  const address = said.replace(/^::ffff:(?=\d+\.\d+\.\d+\.\d+$)/i, "");
  return isIP(address) ? address : null;
}

// reach's words when no connection was made (api/_db.js): nothing sent.
const NEVER_REACHED = /: not reached \((ECONNREFUSED|ENOTFOUND|EAI_AGAIN|EHOSTUNREACH|ENETUNREACH|UND_ERR_CONNECT_TIMEOUT)\)$/;

async function redeemed(email, account, vet, once, from) {
  const link = await reach("auth POST admin/generate_link", 10, `${supabase()}/auth/v1/admin/generate_link`, {
    method: "POST", headers: admin(),
    body: JSON.stringify({ type: "magiclink", email }) });
  const made = await link.json().catch(() => ({}));
  const hashed = made.hashed_token || made.properties?.hashed_token;
  const id = made.id || made.user?.id;
  if (!link.ok || !hashed || !id || (account && id !== account)) throw new Error(`auth: no link: ${link.status}`);
  if (vet) await vet(made.user || made);
  await once();
  const headers = from
    ? { apikey: process.env.SUPABASE_SECRET_KEY, "sb-forwarded-for": from, "content-type": "application/json" }
    : { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" };
  let verify;
  try {
    verify = await reach("auth POST verify", 10, `${supabase()}/auth/v1/verify`, {
      method: "POST", headers, body: JSON.stringify({ type: "magiclink", token_hash: hashed }) });
  } catch (trouble) {
    // Given back only when the verify was never reached: no connection made.
    // A reply lost, or none within the deadline, may have spent it there.
    const failed = trouble instanceof Error ? trouble : new Error(String(trouble));
    throw Object.assign(failed, { unspent: NEVER_REACHED.test(failed.message) });
  }
  const session = await verify.json().catch(() => ({}));
  if (verify.status === 403 || verify.status === 401) {
    throw Object.assign(new Error(`auth: the link was spoiled: ${verify.status}`), { spoiled: true });
  }
  if (verify.status === 429) throw Object.assign(new Error("auth: verify answered 429"), { busy: true, unspent: true });
  const claims = claimsOf(session.access_token);
  if (!verify.ok || !session.refresh_token || session.user?.id !== id || claims.sub !== id || !claims.session_id) {
    throw new Error(`auth: the session was not for this account: ${verify.status}`);
  }
  return { session, sessionId: claims.session_id, account: id, user: made.user || made };
}
