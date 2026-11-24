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
//               what puts the age question after a first sign-in; and
//               whether it is a beta tester, with the early features it
//               may use ({tester, early}: api/_early.js), whether the beta
//               is open, and whether its welcome is due: a new account not
//               yet asked to join (open, welcome: api/_beta.js memberOf),
//               which the site and the app show after the age question;
//               and its profile ({handle, name}, or null for none), which
//               is what asks a name before its first comment, reply or
//               post on the site (web/account.js nameFirst, socialloop).
//               And, after answering, a sign-in of the last 15 minutes of
//               an account 13 or over gets its orangecheck account, made
//               once, by Connect (signin3, api/_oc.js ensureOrangecheck):
//               every page and the app ask this as soon as they are
//               signed in, by a code, Google, GitHub or orangecheck.
//               Without a token, which of Google and GitHub sign people
//               in here ({google, github}: api/_ways.js waysOffered).
//
//   POST ?op=age, with a token and {month, year}: the answer to the age
//   question (2026-10-18). Worked out here into whether that is 13 or over
//   (api/_trust.js). Brickworks accounts are for 13 and over (2026-11-03):
//   13 or over, only that is kept, with when, never the date; under 13, the
//   account is deleted there and then, as ?op=delete deletes one, with the
//   sign-in codes' count of its address (otp_requests), so nothing of the
//   child is kept, and the answer is 403 {error, deleted: true}: a younger
//   builder uses a parent's or guardian's account. {again: true} instead of
//   a date is a browser or computer told so before (web/account.js,
//   src/account/account.gd), whose new account is not asked again but
//   deleted the same way. An account that has answered keeps its answer: a
//   second try changes nothing, and what comes back is the answer it gave.
//
//   GET ?op=theme, with a token: the theme this account chose for the
//   site ({theme: system, light or dark, chosen, ready}), and POST ?op=theme
//   with {theme} to keep one (2026-10-22, supabase/theme.sql), so a new
//   browser follows a person once they sign in (web/theme-account.js).
//   Until theme.sql is applied the column is not there: GET answers
//   "system", not chosen, ready false, and POST keeps nothing (kept
//   false); neither is an error, since the browser keeps it all the same.
//
//   GET ?op=keys, with a token: the app's keys this account set ({keys:
//   {preset, own, colours, at} or null, ready}), and POST ?op=keys with {preset,
//   own, colours, at} to keep them (2026-10-30, supabase/keymap.sql): the
//   preset (brickworks, studio, mecabricks or ldcad), the keys set over it (a
//   command's name and its key), the ten favourite colours on keys (keys3;
//   none from an app before them) and when, so a new browser or computer has
//   a person's keys once they sign in (src/account/keymap_sync.gd). Until
//   keymap.sql is applied, GET answers null, ready false, and POST keeps
//   nothing (kept false): the app keeps them on the device all the same.
//
//   POST ?op=fetch, with a token and {url}: the picture or 3D model at a
//   link, fetched for the app in a browser, which cannot fetch from most
//   sites itself (api/_link.js says what it will fetch, and from where).
//
//   POST ?op=delete, with a token and {confirm: <the account's address>}:
//   the account deleted, and everything of it (2026-10-20). The address
//   typed again is the confirmation, so a stray click or a stolen page
//   cannot do it. An orangecheck account, whose address is made up
//   (api/orangecheck.js), sends {orangecheck: <a token>} instead: a fresh
//   sign-in with orangecheck, as the same person (2026-10-23); an account
//   with its own email, signed in with orangecheck, a code emailed in the
//   last five minutes first, as unlinking asks. The files of the build photos it posted, of those
//   posted of its models, and of its own picture as its avatar
//   (supabase/avatars.sql), and of its feedback's pictures and models
//   (supabase/feedback.sql), are deleted from storage first, by name, since
//   storage keeps no link to the account; then the account itself, and
//   with it every row that names it (each table's owner column cascades:
//   its models, versions, comments, favourites,
//   collections, follows, its collection of sets and its Claude
//   connections). Model files no row owns any longer go with the daily
//   sweep (api/share.js). The site owner's account is refused: it holds
//   the admin page. An orangecheck account Connect made for it, at its
//   tick (2026-10-24), is deleted at orangecheck before anything here; one
//   orangecheck will not delete stays the person's at ochk.app, and the
//   answer says so ({orangecheck: {kept, said}}). While billing is on
//   (api/_billing.js), its plan goes before any of that (2026-10-29): the
//   account erased at Admission, and a subscription it pays for ended now,
//   with nothing charged again ({plan: {ended}}). If Admission cannot,
//   nothing is deleted (503), and asking again finishes what a deletion
//   that stopped later began. Billing off, Admission is never asked.
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

import { noted } from "./_noted.js";
import { afterAnswer } from "./_after.js";
import { AuthError, authConfigured, bearer, isMaster, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { betaMode, memberOf } from "./_beta.js";
import { earlyFor } from "./_early.js";
import { linkFetch } from "./_link.js";
import { orangecheckOffer } from "./_oc_config.js";
import { waysOffered } from "./_ways.js";
import { ageOf, answerAge, birthOf, thirteenOrOver, TOO_YOUNG } from "./_trust.js";
import { erase, NOT_DELETED } from "./_erase.js";

async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }

  // The app's own page alone: no other site may read what it fetches.
  if (String(request.query?.op || "") === "fetch") return linkFetch(request, response);

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
  if (String(request.query?.op || "") === "keys" && ["GET", "POST"].includes(request.method)) {
    return keys(request, response);
  }
  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET, or POST ?op=age, ?op=theme, ?op=keys, ?op=fetch or ?op=delete" });
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
    orangecheck: enabled ? orangecheckOffer() : { ready: false, everyone: false, connect: false, native: null },
    // Sign in with Google and with GitHub (api/_ways.js): where each is
    // offered here, its keys in and its switch in the console not off.
    ways: enabled ? await waysOffered(request) : { google: false, github: false },
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
    claims = await verify(token, request);
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
  // reach, or trust.sql not applied) asks nothing. And whether this is a
  // beta tester, and so which early features it may use (api/_early.js),
  // asked at the same time: not knowing (feedback.sql not applied) is not
  // one. While the beta is open, where it stands with the testers instead,
  // which says that too, and whether its welcome is due.
  let age = null;
  let tester = false;
  let welcome = false;
  // Its own profile, the name its comments and posts go out under: null
  // for none, left out when it could not be read (nobody is asked then).
  let profile;
  const open = await betaMode(request) === "open";
  if (dbConfigured()) {
    const [kept, isTester, people] = await Promise.allSettled([ageOf(claims.sub),
      open ? memberOf(claims.sub).catch(() => asTester(claims.sub)) : asTester(claims.sub),
      db(`people?account=eq.${claims.sub}&select=handle,name&limit=1`)]);
    if (kept.status === "fulfilled" && kept.value.ready) age = { ask: kept.value.ask, over_13: kept.value.over_13 };
    if (kept.status === "rejected") {
      console.error(`account: no age: ${String(kept.reason?.message || kept.reason).slice(0, 120)}`);
    }
    const said = isTester.status === "fulfilled" ? isTester.value : null;
    tester = said?.tester === true;
    welcome = open && said?.welcome === true;
    if (people.status === "fulfilled" && Array.isArray(people.value)) {
      const row = people.value[0];
      profile = row && row.handle ? { handle: String(row.handle), name: String(row.name || row.handle) } : null;
    }
  }
  // Signed in just now, 13 or over: its orangecheck account, after the
  // answer. Never for an account still to answer the age question (a
  // child's is deleted): that one gets it with its answer (takeAge).
  if (age && age.ask === false && age.over_13 === true) wrapOrangecheck(claims);

  return response.status(200).json({
    ...base,
    signed_in: true,
    email: claims.email || null,
    master: isMaster(claims),
    // open: the beta's switch, so the app shows its top bar's Report a bug
    // while it is (bugreport); welcome only while it is open (betajoin).
    beta: { tester, early: earlyFor(tester), open, ...(open ? { welcome } : {}) },
    ...(age ? { age } : {}),
    ...(profile !== undefined ? { profile } : {}),
  });
}

/// The orangecheck account of [claims]' account made, after the answer,
/// when its session is a sign-in of the last 15 minutes and Connect is set
/// up here (api/_oc.js ensureOrangecheck); said in the log when it is not
/// made for a reason worth reading (orangecheck out, its daily limit).
function wrapOrangecheck(claims) {
  if (!process.env.OC_CONNECT_KEY) return;
  afterAnswer(async () => {
    const { codeOf, ensureOrangecheck, signedInJustNow } = await import("./_oc.js");
    if (!signedInJustNow(claims)) return;
    const { emailed } = await codeOf(claims).catch(() => ({ emailed: null }));
    const done = await ensureOrangecheck(claims, emailed);
    if (!done.made && !["has_orangecheck", "has_one", "asked_just_now"].includes(done.reason)) {
      console.error(`account: no orangecheck account made at a sign-in: ${done.reason}`);
    }
  }, "account: orangecheck");
}

/// Whether [account] is a beta tester, as feedback.sql's beta_tester says
/// (beta_join.sql's once applied): {tester}.
async function asTester(account) {
  return { tester: (await db("rpc/beta_tester", { method: "POST", body: { p_account: account } })) === true };
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
    claims = await verify(bearer(request), request);
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
  const again = body?.again === true;
  const born = again ? null : birthOf(body);
  if (born?.trouble) return response.status(422).json({ error: born.trouble });
  let kept;
  try {
    kept = await ageOf(claims.sub);
    if (!kept.ready) return response.status(503).json({ error: "Brickworks does not ask this here yet." });
    if (!kept.ask) return response.status(200).json({ age: { ask: kept.ask, over_13: kept.over_13 } });
    if (!again && thirteenOrOver(born.month, born.year)) {
      const now = await answerAge(claims.sub);
      if (now.over_13 === true) wrapOrangecheck(claims);
      return response.status(200).json({ age: { ask: now.ask, over_13: now.over_13 } });
    }
  } catch (trouble) {
    console.error(`account: the age was not kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return response.status(502).json({ error: "Brickworks could not take that just now. Try again in a minute." });
  }
  // Under 13: nothing is kept. The site owner's account holds the admin
  // page and is never deleted from here; it is only told.
  if (isMaster(claims)) return response.status(403).json({ error: TOO_YOUNG, deleted: false });
  const gone = await erase(claims.sub);
  if (gone.status !== 200) {
    return response.status(gone.status).json({ error: "Brickworks could not take that just now. Try again in a minute." });
  }
  // The address's count of codes asked for (api/otp.js may_ask_for_code),
  // the one row besides the account that holds it.
  const address = String(claims.email || "").trim().toLowerCase();
  if (address) {
    await db(`otp_requests?email=eq.${encodeURIComponent(address)}`, { method: "DELETE" }).catch((trouble) =>
      console.error(`account: the codes' count was not cleared: ${String(trouble?.message || trouble).slice(0, 120)}`));
  }
  return response.status(403).json({ error: TOO_YOUNG, deleted: true });
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
    claims = await verify(bearer(request), request);
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

const KEY_PRESETS = ["brickworks", "studio", "mecabricks", "ldcad"];
// A command's name (src/ui/shell.gd, src/ui/keymap.gd) and a key with its
// modifiers as Godot writes one, under 2^31. The app has some 150.
const KEY_ACTION = /^[a-z0-9_]{1,48}$/;
const MOST_KEYS = 400;
const FAVOURITE_COLOURS = 10;
let saidNoKeys = false;

/// The app's keys as an account sends them, or why not: {preset, own, at}.
export function keysOf(body) {
  const preset = String(body?.preset || "");
  if (!KEY_PRESETS.includes(preset)) return { trouble: "The keys' preset is brickworks, studio, mecabricks or ldcad." };
  const own = body?.own;
  if (own === null || typeof own !== "object" || Array.isArray(own)) return { trouble: "The keys set are a command's name and its key." };
  const entries = Object.entries(own);
  if (entries.length > MOST_KEYS) return { trouble: `At most ${MOST_KEYS} keys.` };
  const kept = {};
  for (const [action, key] of entries) {
    if (!KEY_ACTION.test(action) || !Number.isInteger(key) || key < 0 || key >= 2 ** 31) {
      return { trouble: "The keys set are a command's name and its key." };
    }
    kept[action] = key;
  }
  const at = Number(body?.at);
  if (!Number.isFinite(at) || at < 0) return { trouble: "When the keys were set is a time in seconds." };
  // The ten favourite colours on keys (src/ui/colour_keys.gd), LDraw colour
  // codes; an app from before them sends none.
  const colours = body?.colours;
  if (colours === undefined || colours === null) return { keys: { preset, own: kept, at } };
  if (!Array.isArray(colours) || colours.length !== FAVOURITE_COLOURS
      || !colours.every((code) => Number.isInteger(code) && code >= 0 && code < 2 ** 31)) {
    return { trouble: `The favourite colours are ${FAVOURITE_COLOURS} colour codes.` };
  }
  return { keys: { preset, own: kept, colours, at } };
}

/// The app's keys on the account: read (GET) or kept (POST {preset, own, at}).
async function keys(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  if (!authConfigured()) return response.status(503).json({ error: "Accounts are not configured here." });
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 401;
    return response.status(status).json({ error: error.message });
  }
  const notHere = (trouble) => {
    if (NO_COLUMN.test(String(trouble?.message || "")) && !saidNoKeys) {
      saidNoKeys = true;
      console.error("account: supabase/keymap.sql is not applied here; the keys are kept on the device only");
    } else if (!NO_COLUMN.test(String(trouble?.message || ""))) {
      console.error(`account: no keys: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  };
  if (request.method === "GET") {
    const none = { keys: null, ready: false };
    if (!dbConfigured()) return response.status(200).json(none);
    try {
      const rows = await db(`profiles?id=eq.${claims.sub}&select=keys`);
      const kept = rows?.[0]?.keys ? keysOf(rows[0].keys).keys || null : null;
      return response.status(200).json({ keys: kept, ready: true });
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
  const sent = keysOf(body);
  if (sent.trouble) return response.status(422).json({ error: sent.trouble });
  if (!dbConfigured()) return response.status(200).json({ keys: sent.keys, kept: false });
  try {
    const changed = await db(`profiles?id=eq.${claims.sub}`, { method: "PATCH", body: { keys: sent.keys },
      prefer: "return=representation" });
    // An account older than schema.sql's trigger has no row: one is made.
    if (!changed?.length) {
      await db("profiles?on_conflict=id", { method: "POST", body: { id: claims.sub, email: claims.email || null, keys: sent.keys },
        prefer: "resolution=merge-duplicates,return=minimal" });
    }
    return response.status(200).json({ keys: sent.keys, kept: true });
  } catch (trouble) {
    notHere(trouble);
    if (NO_COLUMN.test(String(trouble?.message || ""))) return response.status(200).json({ keys: sent.keys, kept: false });
    return response.status(502).json({ error: "Brickworks could not keep that just now. The keys are kept on this device." });
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
    claims = await verify(bearer(request), request);
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
      return response.status(502).json({ error: NOT_DELETED });
    }
    if (whose !== claims.sub) {
      return response.status(403).json({ error: "That orangecheck sign-in is not this account's. Sign in with the one you use here." });
    }
    try {
      if (!(await spendToken(checked.session.jti, checked.session.exp))) {
        return response.status(409).json({ error: "That sign-in was used already. Sign in with orangecheck again." });
      }
    } catch {
      return response.status(502).json({ error: NOT_DELETED });
    }
    await endToken(String(body.orangecheck).trim());
  } else {
    const typed = String(body?.confirm || "").trim().toLowerCase();
    if (!address || typed !== address) {
      return response.status(422).json({ error: "Type your email address exactly as you sign in with it to delete this account." });
    }
    // Signed in with orangecheck to an account that has its own email: the
    // same fresh emailed code as unlinking asks first (api/orangecheck.js),
    // so an orangecheck sign-in alone cannot delete the account it was
    // linked to (oc188's review, L4).
    if (claims.app_metadata?.orangecheck === true) {
      const { codeOf } = await import("./_oc.js");
      let asked;
      try {
        asked = await codeOf(claims);
      } catch (trouble) {
        console.error(`account: whose sign-in: ${String(trouble?.message || trouble).slice(0, 120)}`);
        return response.status(502).json({ error: NOT_DELETED });
      }
      if (asked.bound && !asked.fresh) {
        return response.status(403).json({ error: "Confirm it is you first, with a code we email you.", fresh: false });
      }
    }
  }
  if (isMaster(claims)) {
    return response.status(403).json({ error: "The site owner's account holds the admin page and is not deleted from here." });
  }
  const gone = await erase(claims.sub);
  return response.status(gone.status).json(gone.body);
}

// Each 5xx kept for the owner's server-errors notification (api/_noted.js).
export default noted("account", handler);
