// What the app needs to know about this deployment and about who is
// using it, in one request.
//
//   No token  — where the part geometry the build did not ship is served
//               from, whether this deployment has accounts, and where to
//               sign in. The same answer for everybody, so any cache may
//               keep it. Enough to draw the sign-in screen.
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
//   POST ?op=delete, with a token and {confirm: <the account's address>}:
//   the account deleted, and everything of it (2026-10-20). The address
//   typed again is the confirmation, so a stray click or a stolen page
//   cannot do it. The files of the build photos it posted, and of those
//   posted of its models, are deleted from storage first, by name, since
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
  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET, or POST ?op=age or ?op=delete" });
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
  const typed = String(body?.confirm || "").trim().toLowerCase();
  if (!address || typed !== address) {
    return response.status(422).json({ error: "Type your email address exactly as you sign in with it to delete this account." });
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
    const gone = await fetch(`${base}/auth/v1/admin/users/${account}`, {
      method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(20000) });
    if (!gone.ok && gone.status !== 404) throw new Error(`auth DELETE: ${gone.status}`);
    return response.status(200).json({ deleted: true, photos: photos.length });
  } catch (trouble) {
    console.error(`account: not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return response.status(502).json({ error: "Brickworks could not delete the account just now. Try again in a minute." });
  }
}
