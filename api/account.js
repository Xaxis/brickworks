// What the app needs to know about this deployment and about who is
// using it, in one request.
//
//   No token  — where the part geometry the build did not ship is served
//               from, whether this deployment has accounts, and where to
//               sign in, with orangecheck too ({ready, everyone}). The
//               same answer for everybody, so any cache may keep it.
//               Enough to draw the sign-in screen.
//   A token   — the same, and who that token belongs to: the address,
//               and whether it is the owner's (MASTER_EMAIL), which is
//               what puts the admin page in the account panel; and its age
//               as kept ({ask, over_13}: supabase/trust.sql), which is
//               what puts the age question after a first sign-in.
//
//   POST ?op=age, with a token and {month, year}: the answer to the age
//   question (2026-10-18). Worked out here into whether that is 13 or over
//   (api/_trust.js); only that is kept, with when, never the date. An
//   account that has answered keeps its answer: a second try changes
//   nothing, and what comes back is the answer it gave.
//
//   GET ?op=theme, with a token: the theme this account chose for the
//   site ({theme: system, light or dark, chosen, ready}), and POST ?op=theme
//   with {theme} to keep one (2026-10-22, supabase/theme.sql), so a new
//   browser follows a person once they sign in (web/theme-account.js).
//   Until theme.sql is applied the column is not there: GET answers
//   "system", not chosen, ready false, and POST keeps nothing (kept
//   false); neither is an error, since the browser keeps it all the same.
//
//   POST ?op=delete, with a token and {confirm: <the account's address>}:
//   the account deleted, and everything of it (2026-10-20). The address
//   typed again is the confirmation, so a stray click or a stolen page
//   cannot do it. An orangecheck account, whose address is made up
//   (api/orangecheck.js), sends {orangecheck: <a token>} instead: a fresh
//   sign-in with orangecheck, as the same person (2026-10-23). The files of the build photos it posted, of those
//   posted of its models, and of its own picture as its avatar
//   (supabase/avatars.sql), are deleted from storage first, by name, since
//   storage keeps no link to the account; then the account itself, and
//   with it every row that names it (each table's owner column cascades:
//   its models, versions, comments, favourites,
//   collections, follows, its collection of sets and its Claude
//   connections). Model files no row owns any longer go with the daily
//   sweep (api/share.js). The site owner's account is refused: it holds
//   the admin page.
//
// Everyone who uses Brickworks signs in (2026-10-11). There were
// accounts before, until 2026-10-09, so that one of them could design on
// the project's key; they went with that, and came back because the
// owner wants every person on the platform to have one — and because a
// connector that drives somebody's tab should belong to somebody. The
// route kept answering through both, so builds already out never lost
// their parts.
//
// Publishable key, not the secret one. It is meant to be in the client —
// it identifies the project and nothing more, and every table it can
// reach is behind row level security. Serving it from here rather than
// compiling it in means a rotated key reaches the desktop build without
// anyone reinstalling.

import { AuthError, authConfigured, bearer, isMaster, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { orangecheckOffer } from "./_oc_config.js";
import { ageOf, answerAge, birthOf, thirteenOrOver } from "./_trust.js";

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }

  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Vary", "Authorization");

  if (request.method === "POST" && String(request.query?.op || "") === "age") {
    return takeAge(request, response);
  }
  if (request.method === "POST" && String(request.query?.op || "") === "delete") {
    return deleteAccount(request, response);
  }
  if (String(request.query?.op || "") === "theme" && ["GET", "POST"].includes(request.method)) {
    return theme(request, response);
  }
  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET, or POST ?op=age, ?op=theme or ?op=delete" });
  }

  const enabled = authConfigured();
  const base = {
    // True: this deployment has accounts, and the app asks everyone to
    // sign in before it can be used.
    enabled,
    url: enabled ? process.env.SUPABASE_URL.replace(/\/+$/, "") : null,
    key: enabled ? process.env.SUPABASE_PUBLISHABLE_KEY : null,
    // The assistant runs on the person's own key, sent only to
    // Anthropic, or on their own Claude plan through the connector.
    // Never on ours.
    assistant: "own_key",
    // Where the geometry this build did not ship is served from. The
    // library runs to 27,000 meshes and a deployment takes 15,000 files,
    // so the parts cannot live beside the app. Null means "next to the
    // app", which is what a deployment carrying its own parts wants.
    parts_url: process.env.PARTS_URL || null,
    // Sign in with orangecheck (api/orangecheck.js): whether it works here,
    // and whether everybody is offered it (api/_oc_config.js).
    orangecheck: enabled ? orangecheckOffer() : { ready: false, everyone: false },
  };

  const token = bearer(request);
  if (!enabled || !token) {
    // The same answer for everybody, so any cache may keep it a while.
    response.setHeader("Cache-Control", "public, max-age=300");
    return response.status(200).json({ ...base, signed_in: false });
  }

  // From here the answer is about one person.
  response.setHeader("Cache-Control", "private, no-store");
  let claims;
  try {
    claims = await verify(token);
  } catch (error) {
    // Not an error the app should show. A token that has aged out is
    // the ordinary way a session ends, and the app renews it with
    // Supabase rather than asking here; this only reports what it saw.
    return response.status(200).json({
      ...base,
      signed_in: false,
      reason: error instanceof AuthError ? error.message : "sign in again",
    });
  }

  // Whether to ask the age question. Not knowing (the database out of
  // reach, or trust.sql not applied) asks nothing.
  let age = null;
  if (dbConfigured()) {
    try {
      const kept = await ageOf(claims.sub);
      if (kept.ready) age = { ask: kept.ask, over_13: kept.over_13 };
    } catch (trouble) {
      console.error(`account: no age: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }

  return response.status(200).json({
    ...base,
    signed_in: true,
    email: claims.email || null,
    master: isMaster(claims),
    ...(age ? { age } : {}),
  });
}

/// The age question's answer. The month and year are read, turned into
/// 13 or over or not, and let go: nothing of them is kept or logged.
async function takeAge(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!authConfigured() || !dbConfigured()) {
    return response.status(503).json({ error: "Accounts are not configured here." });
  }
  let claims;
  try {
    claims = await verify(bearer(request));
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 401;
    return response.status(status).json({ error: error.message });
  }
  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      body = {};
    }
  }
  const born = birthOf(body);
  if (born.trouble) return response.status(422).json({ error: born.trouble });
  try {
    const kept = await ageOf(claims.sub);
    if (!kept.ready) return response.status(503).json({ error: "Brickworks does not ask this here yet." });
    const now = kept.ask ? await answerAge(claims.sub, thirteenOrOver(born.month, born.year)) : kept;
    return response.status(200).json({ age: { ask: now.ask, over_13: now.over_13 } });
  } catch (trouble) {
    console.error(`account: the age was not kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return response.status(502).json({ error: "Brickworks could not take that just now. Try again in a minute." });
  }
}

const THEMES = ["system", "light", "dark"];
// PostgREST's answer to a column it does not know: 400 (42703 on a read,
// PGRST204 on a write). theme.sql not applied.
const NO_COLUMN = /: 400$/;
let saidNoTheme = false;

/// The site's theme on the account: read (GET) or kept (POST {theme}).
async function theme(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  if (!authConfigured()) return response.status(503).json({ error: "Accounts are not configured here." });
  let claims;
  try {
    claims = await verify(bearer(request));
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 401;
    return response.status(status).json({ error: error.message });
  }
  const notHere = (trouble) => {
    if (NO_COLUMN.test(String(trouble?.message || "")) && !saidNoTheme) {
      saidNoTheme = true;
      console.error("account: supabase/theme.sql is not applied here; the theme is kept in the browser only");
    } else if (!NO_COLUMN.test(String(trouble?.message || ""))) {
      console.error(`account: no theme: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  };
  if (request.method === "GET") {
    const none = { theme: "system", chosen: false, ready: false };
    if (!dbConfigured()) return response.status(200).json(none);
    try {
      const rows = await db(`profiles?id=eq.${claims.sub}&select=theme`);
      const kept = THEMES.includes(rows?.[0]?.theme) ? rows[0].theme : null;
      return response.status(200).json({ theme: kept || "system", chosen: Boolean(kept), ready: true });
    } catch (trouble) {
      notHere(trouble);
      return response.status(200).json(none);
    }
  }
  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      body = {};
    }
  }
  const wanted = String(body?.theme || "");
  if (!THEMES.includes(wanted)) return response.status(422).json({ error: "A theme is system, light or dark." });
  if (!dbConfigured()) return response.status(200).json({ theme: wanted, kept: false });
  try {
    const changed = await db(`profiles?id=eq.${claims.sub}`, { method: "PATCH", body: { theme: wanted },
      prefer: "return=representation" });
    // An account older than schema.sql's trigger has no row: one is made.
    if (!changed?.length) {
      await db("profiles?on_conflict=id", { method: "POST", body: { id: claims.sub, email: claims.email || null, theme: wanted },
        prefer: "resolution=merge-duplicates,return=minimal" });
    }
    return response.status(200).json({ theme: wanted, kept: true });
  } catch (trouble) {
    notHere(trouble);
    if (NO_COLUMN.test(String(trouble?.message || ""))) return response.status(200).json({ theme: wanted, kept: false });
    return response.status(502).json({ error: "Brickworks could not keep that just now. It is kept in this browser." });
  }
}

/// The account deleted, at its own asking, with its address typed again.
async function deleteAccount(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!authConfigured() || !dbConfigured()) {
    return response.status(503).json({ error: "Accounts are not configured here." });
  }
  let claims;
  try {
    claims = await verify(bearer(request));
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 401;
    return response.status(status).json({ error: error.message });
  }
  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      body = {};
    }
  }
  const address = String(claims.email || "").trim().toLowerCase();
  if (/@oc\.brickworks\.diy$/.test(address)) {
    // An orangecheck account (api/orangecheck.js) has no address of its own
    // to type: it signs in with orangecheck again, as itself, and that
    // sign-in is spent here. Loaded only here, so the route every start of
    // the app asks does not carry orangecheck's code.
    const { checkToken, endToken, spendToken } = await import("./_oc.js");
    const checked = await checkToken(body?.orangecheck);
    if (!checked.session) return response.status(checked.status).json({ error: checked.error });
    let whose = null;
    try {
      whose = await db("rpc/oc_account_of", { method: "POST", body: { did: checked.session.did_oc } });
    } catch (trouble) {
      console.error(`account: whose orangecheck id: ${String(trouble?.message || trouble).slice(0, 120)}`);
      return response.status(502).json({ error: "Brickworks could not delete the account just now. Try again in a minute." });
    }
    if (whose !== claims.sub) {
      return response.status(403).json({ error: "That orangecheck sign-in is not this account's. Sign in with the one you use here." });
    }
    try {
      if (!(await spendToken(checked.session.jti, checked.session.exp))) {
        return response.status(409).json({ error: "That sign-in was used already. Sign in with orangecheck again." });
      }
    } catch {
      return response.status(502).json({ error: "Brickworks could not delete the account just now. Try again in a minute." });
    }
    await endToken(String(body.orangecheck).trim());
  } else {
    const typed = String(body?.confirm || "").trim().toLowerCase();
    if (!address || typed !== address) {
      return response.status(422).json({ error: "Type your email address exactly as you sign in with it to delete this account." });
    }
  }
  if (isMaster(claims)) {
    return response.status(403).json({ error: "The site owner's account holds the admin page and is not deleted from here." });
  }
  const account = claims.sub;
  try {
    // The files of the build photos it posted, and of those posted of its
    // models (their rows go with the models), by name: storage keeps no
    // link to the account.
    let photos = [];
    try {
      const models = (await db(`shared_models?owner=eq.${account}&select=id`)).map((one) => one.id);
      const ofModels = models.length ? await db(`build_photos?model=in.(${models.join(",")})&select=id`) : [];
      const own = await db(`build_photos?account=eq.${account}&select=id`);
      photos = [...new Map([...own, ...ofModels].map((one) => [one.id, one])).values()];
    } catch (trouble) {
      if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    }
    const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
    const key = process.env.SUPABASE_SECRET_KEY;
    // Exactly these files of build-photos (api/_builds.js PHOTOS), not
    // imported from there: this route answers every start of the app, and
    // _builds.js brings the picture decoders with it.
    for (let at = 0; at < photos.length; at += 100) {
      const files = await fetch(`${base}/storage/v1/object/build-photos`, {
        method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
        body: JSON.stringify({ prefixes: photos.slice(at, at + 100).map((one) => `${one.id}.jpg`) }),
        signal: AbortSignal.timeout(20000) });
      if (!files.ok) throw new Error(`storage DELETE build-photos: ${files.status}`);
    }
    // Its own picture as its avatar (api/_avatars.js AVATARS), by name too.
    let avatars = [];
    try {
      avatars = await db(`profile_avatars?account=eq.${account}&select=id`);
    } catch (trouble) {
      if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    }
    if (avatars.length) {
      const files = await fetch(`${base}/storage/v1/object/avatars`, {
        method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
        body: JSON.stringify({ prefixes: avatars.map((one) => `${one.id}.jpg`) }), signal: AbortSignal.timeout(20000) });
      if (!files.ok) throw new Error(`storage DELETE avatars: ${files.status}`);
    }
    const gone = await fetch(`${base}/auth/v1/admin/users/${account}`, {
      method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(20000) });
    if (!gone.ok && gone.status !== 404) throw new Error(`auth DELETE: ${gone.status}`);
    return response.status(200).json({ deleted: true, photos: photos.length, avatars: avatars.length });
  } catch (trouble) {
    console.error(`account: not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return response.status(502).json({ error: "Brickworks could not delete the account just now. Try again in a minute." });
  }
}
