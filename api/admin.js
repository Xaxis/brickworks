// What the owner's account can see, and nobody else can: who has an
// account, when each last signed in, and whose Claude connectors there
// are.
//
// Everything here reads as the service role, which can see every row in
// the database regardless of the policies that keep one person out of
// another's. That is the whole risk of the file: the check that this is
// the owner's account is the only thing between a signed-in stranger and
// a list of everybody's email addresses.
//
// So it is the first thing that happens, it is done against a verified
// token rather than anything the caller supplies, and it fails closed —
// MASTER_EMAIL unset means nobody rather than everybody. There is nothing
// about an account to change from here. The writes are the gallery's: a
// model listed there that should not be (2026-10-13) is taken out, and
// barred, so its owner cannot list it again — and since the directory's
// moderation (supabase/moderation.sql), neither can anybody list the same
// file again at another link; and an account can be taken out whole, every
// model of it, so that publishing again does not dodge it. Links still
// work; taking those down is their owners'. What visitors reported is here
// to act on, or to let go.
//
// Comments (2026-10-18, supabase/comments.sql): the newest are listed with
// the reported ones, each with its model, where it was said and by whom,
// and Remove takes one off every page for good. It is kept, shown to
// nobody, and what was reported about it is settled. Taking a model or an
// account out settles what was reported about that model, not about the
// comments on it, which are still on its page.
//
//   GET /api/admin                       accounts, sign-ins, connectors, the
//                                        email sender, the gallery's models,
//                                        open reports, accounts taken out
//   POST /api/admin?op=unlist&id=X       take model X out of the gallery for good
//   POST /api/admin?op=bar&id=X          take the account that shares X out of it
//   POST /api/admin?op=unbar&account=U   let account U list again
//   POST /api/admin?op=dismiss&report=N  let report N go: nothing wrong
//   POST /api/admin?op=untest&id=X&v=N   clear the Tested mark of version N
//                                        of model X (the newest without v):
//                                        the app's finding, which the server
//                                        cannot check (supabase/tested.sql)
//   POST /api/admin?op=uncomment&comment=N  remove comment N, for good
//   POST /api/admin?op=remove_photo&photo=P  take photo P of a build out: its
//                                        file deleted from storage, that one
//                                        file only, its reports settled
//                                        (supabase/builds.sql)
//   GET  /api/admin?op=photo&photo=P     photo P, hidden or not, to look at
//                                        before taking it out
//   POST /api/admin?op=remove_avatar&handle=H  take the picture profile H
//                                        shows as its avatar out: its file
//                                        deleted, the avatar made from the
//                                        handle shown again, the reports
//                                        about the profile settled
//                                        (supabase/avatars.sql)
//   POST /api/admin?op=pick&id=X&days=N  make model X this week's pick for N
//                                        days (7 without days, 1 to 31), in
//                                        place of the one worked out
//                                        (supabase/discovery.sql)
//   POST /api/admin?op=unpick&pick=N     end choice N: back to the pick
//                                        worked out from the past seven days
//   POST /api/admin?op=challenge         {title, brief, starts_on, ends_on,
//                                        most_parts?, set_number?, tested?}:
//                                        a challenge set, one at a time
//                                        (supabase/challenges.sql); &tests=1
//                                        makes it a test one, which only a
//                                        page asked with tests=1 shows
//   POST /api/admin?op=end_challenge&challenge=N  challenge N ended now
//   POST /api/admin?op=plan              {themes: [{month: "2026-11", title,
//                                        brief}]}: a year of themes at once, up
//                                        to twelve, each its whole month, told
//                                        to visitors a month before it opens
//                                        (supabase/challenge_year.sql); all or
//                                        none; &tests=1 as for one
//
// Challenges (2026-10-19, supabase/challenges.sql): GET lists them, newest
// first, with their entries, votes and winners (&tests=1: the flows' test
// ones too). A set's rule keeps the set's parts with the challenge, read
// from its inventory (api/_owned.js) as the gallery reads a collection's.
//
// This week's pick (2026-10-19, supabase/discovery.sql): GET says what a
// visitor's gallery shows as the pick now, chosen or worked out, the
// choices still open, and the week's best five with their numbers.
//
// Restored 2026-10-11 with accounts, without the tiers and the design
// budget the first one managed: those belonged to the proxy that spent
// the project's key, which has not come back.

import { AuthError, authConfigured, bearer, isMaster, verify } from "./_auth.js";
import { db } from "./_db.js";
import { modelHash } from "./_directory.js";
import { BuildRefusal, photoFileForAdmin, photosReported, removePhoto } from "./_builds.js";
import { AvatarRefusal, removeAvatar } from "./_avatars.js";
import { facesOf, pictureAt } from "./_faces.js";
import { keyed, readShard, shardOf } from "./_owned.js";
import { originOf } from "./_oauth.js";

const ID = /^[A-Za-z0-9]{10}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function project() {
  return (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// As the service role. Every call here is one.
async function asServer(path) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!secret) throw new AuthError("accounts are not configured here", 503);
  const reply = await fetch(`${project()}${path}`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` },
    signal: AbortSignal.timeout(10000),
  });
  if (!reply.ok) throw new AuthError(`the database said ${reply.status}`, 502);
  return reply.json();
}

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
  // Never cached, anywhere. This is somebody's account list.
  response.setHeader("Cache-Control", "no-store");

  if (!authConfigured()) {
    return response.status(503).json({ error: "accounts are not configured here" });
  }

  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 401;
    return response.status(status).json({ error: error.message });
  }
  if (!isMaster(claims)) {
    // Deliberately the same answer as a route that does not exist. A
    // 403 here would confirm to anyone signed in that there is an admin
    // surface and that they are simply not it.
    return response.status(404).json({ error: "not found" });
  }
  const op = String(request.query?.op || "");
  const acts = { unlist, bar, unbar, dismiss, untest, uncomment, remove_photo: takePhotoOut,
    remove_avatar: takeAvatarOut, pick, unpick, challenge: setChallenge, end_challenge: endChallenge, plan: planYear };
  if (request.method === "POST" && acts[op]) {
    try {
      return await acts[op](request, response);
    } catch (error) {
      return response.status(error instanceof AuthError || error instanceof BuildRefusal
        || error instanceof AvatarRefusal ? error.status : 502)
        .json({ error: error.message });
    }
  }
  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET, or POST ?op=unlist, bar, unbar, dismiss, untest, uncomment, remove_photo, "
      + "remove_avatar, pick, unpick, challenge, end_challenge or plan" });
  }
  if (op === "photo") {
    const file = await photoFileForAdmin(String(request.query?.photo || "")).catch(() => null);
    if (!file) return response.status(404).json({ error: "no photo there" });
    response.setHeader("Content-Type", "image/jpeg");
    response.setHeader("X-Content-Type-Options", "nosniff");
    return response.status(200).end(file);
  }

  try {
    return response.status(200).json(await report(String(request.query?.tests || "") === "1"));
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 500;
    return response.status(status).json({ error: error.message });
  }
}

/// The model's file as published, for its fingerprint: null when its
/// files went (taken down by its owner).
async function modelText(id) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  const reply = await fetch(`${project()}/storage/v1/object/shared-models/${id}.mpd`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` },
    signal: AbortSignal.timeout(20000),
  });
  return reply.ok ? reply.text() : null;
}

/// The file's fingerprint kept, so that the same model published again at
/// another link, by anybody, cannot be listed (api/share.js).
async function barFile(id) {
  const text = await modelText(id);
  if (text === null) return false;
  await db("barred_models?on_conflict=hash", { method: "POST",
    body: { hash: modelHash(text), model: id }, prefer: "resolution=ignore-duplicates" });
  return true;
}

/// What was reported about [where] (a PostgREST filter), settled.
async function settle(where, resolution) {
  await db(`reports?${where}&resolved_at=is.null`, { method: "PATCH",
    body: { resolved_at: new Date().toISOString(), resolution } });
}

/// What was reported about a model itself, settled: not what was reported
/// about a comment on it. Before comments.sql there is no such column, and
/// every report is about the model.
async function settleModel(where, resolution) {
  try {
    await settle(`${where}&comment=is.null`, resolution);
  } catch (trouble) {
    if (!/: 400$/.test(String(trouble?.message || ""))) throw trouble;
    await settle(where, resolution);
  }
}

/// A comment off every page for good: kept, shown to nobody, and what was
/// reported about it settled as taken out.
async function uncomment(request, response) {
  const comment = Number(request.query?.comment);
  if (!Number.isInteger(comment) || comment < 1) {
    return response.status(400).json({ error: "name a comment: ?comment=<number>" });
  }
  const removed = await db("rpc/admin_remove_comment", { method: "POST", body: { comment_id: comment } });
  if (removed !== true) return response.status(404).json({ error: "no such comment" });
  await settle(`comment=eq.${comment}`, "taken_out");
  return response.status(200).json({ comment, removed: true });
}

/// Out of the gallery, and barred from it: listed false, and a republish
/// with the box ticked refused (api/share.js), at this link or with the
/// same file at any other. The row and its files are untouched, so the
/// link goes on working.
async function unlist(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  const rows = await db(`shared_models?id=eq.${id}`, {
    method: "PATCH", body: { listed: false, listed_at: null, barred: true },
    prefer: "return=representation" });
  if (!Array.isArray(rows) || rows.length === 0) return response.status(404).json({ error: "no model at that link" });
  const file = await barFile(id);
  await settleModel(`model=eq.${id}`, "taken_out");
  return response.status(200).json({ id, listed: false, barred: true, file_barred: file });
}

/// The account that shares a model, or one named, out of the gallery: none
/// of its models listed or listable, its profile not shown, and the files
/// of what it had listed barred too, so a new account cannot list them.
async function bar(request, response) {
  const id = String(request.query?.id || "");
  let account = String(request.query?.account || "");
  if (ID.test(id)) {
    const rows = await db(`shared_models?id=eq.${id}&select=owner`);
    if (!rows.length) return response.status(404).json({ error: "no model at that link" });
    account = rows[0].owner;
  }
  if (!UUID.test(account)) return response.status(400).json({ error: "name a model (?id=) or an account (?account=)" });
  const reason = String(request.body?.reason || "").slice(0, 200) || null;
  await db("barred_accounts?on_conflict=account", { method: "POST", body: { account, reason },
    prefer: "resolution=ignore-duplicates" });
  const listed = await db(`shared_models?owner=eq.${account}&listed=is.true&select=id&limit=500`);
  let files = 0;
  for (const model of listed) if (await barFile(model.id)) files += 1;
  await db(`shared_models?owner=eq.${account}&listed=is.true`, { method: "PATCH",
    body: { listed: false, listed_at: null, barred: true } });
  const models = (await db(`shared_models?owner=eq.${account}&select=id`)).map((m) => m.id);
  for (let at = 0; at < models.length; at += 100) {
    await settleModel(`model=in.(${models.slice(at, at + 100).join(",")})`, "account_barred");
  }
  const person = await db(`people?account=eq.${account}&select=handle`);
  if (person.length) await settle(`handle=eq.${person[0].handle}`, "account_barred");
  return response.status(200).json({ account, barred: true, unlisted: listed.length, files_barred: files });
}

/// An account let back: it may list again. What it had listed stays out
/// (each model still barred); the owner of this page lists them again by
/// hand if they should be.
async function unbar(request, response) {
  const account = String(request.query?.account || "");
  if (!UUID.test(account)) return response.status(400).json({ error: "name an account: ?account=<id>" });
  await db(`barred_accounts?account=eq.${account}`, { method: "DELETE" });
  return response.status(200).json({ account, barred: false });
}

async function dismiss(request, response) {
  const report = Number(request.query?.report);
  if (!Number.isInteger(report) || report < 1) return response.status(400).json({ error: "name a report: ?report=<number>" });
  await db(`reports?id=eq.${report}&resolved_at=is.null`, { method: "PATCH",
    body: { resolved_at: new Date().toISOString(), resolution: "dismissed" } });
  return response.status(200).json({ report, resolution: "dismissed" });
}

/// A Tested mark cleared: the app said it passed, and the site's owner says
/// it should not be shown. Kept, with when and why, so it is not shown
/// again; the model's next version is tested afresh.
async function untest(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  let n = Number(request.query?.v || 0);
  if (!n) {
    const newest = await db(`share_versions?model=eq.${id}&select=n&order=n.desc&limit=1`);
    n = newest[0]?.n ?? 0;
  }
  if (!Number.isInteger(n) || n < 1) return response.status(404).json({ error: "no version of that model" });
  const why = String(request.query?.why || "").replace(/[\u0000-\u001f\u007f]+/g, " ").trim().slice(0, 280)
    || "Cleared by Brickworks";
  const rows = await db(`share_tests?model=eq.${id}&n=eq.${n}`, { method: "PATCH",
    body: { cleared_at: new Date().toISOString(), cleared_why: why }, prefer: "return=representation" });
  if (!Array.isArray(rows) || rows.length === 0) return response.status(404).json({ error: "that version is not tested" });
  return response.status(200).json({ id, version: n, cleared: true, why });
}

/// A photo of a build taken out (supabase/builds.sql): not shown anywhere
/// again, its file deleted from storage — that photo's file and no other —
/// and what was reported about it settled.
async function takePhotoOut(request, response) {
  const photo = String(request.query?.photo || "");
  if (!ID.test(photo)) return response.status(400).json({ error: "name a photo: ?photo=<ten characters>" });
  const why = String(request.query?.why || request.body?.why || "").replace(/[\u0000-\u001f\u007f]+/g, " ")
    .trim().slice(0, 200) || "Taken out by Brickworks";
  return response.status(200).json(await removePhoto(photo, why));
}

/// The picture a profile shows as its avatar taken out (supabase/avatars.sql):
/// its file deleted, the row kept to say so, the avatar made from the
/// handle shown again, and what was reported about the profile settled.
async function takeAvatarOut(request, response) {
  const handle = String(request.query?.handle || "").toLowerCase();
  if (!/^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/.test(handle)) return response.status(400).json({ error: "name a profile: ?handle=<handle>" });
  const person = (await db(`people?handle=eq.${handle}&select=account`))[0];
  if (!person) return response.status(404).json({ error: "nobody has that handle" });
  const why = String(request.query?.why || request.body?.why || "").replace(/[\u0000-\u001f\u007f]+/g, " ")
    .trim().slice(0, 200) || "Taken out by Brickworks";
  return response.status(200).json({ handle, ...(await removeAvatar(person.account, why)) });
}

/// Model X this week's pick for N days, in place of the one worked out
/// (supabase/discovery.sql gallery_choose_pick): refused for a model the
/// gallery does not show.
async function pick(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  const days = request.query?.days === undefined ? 7 : Number(request.query.days);
  if (!Number.isInteger(days) || days < 1 || days > 31) {
    return response.status(400).json({ error: "a pick is for 1 to 31 days: ?days=<number>" });
  }
  const made = await db("rpc/gallery_choose_pick", { method: "POST", body: { model_id: id, days } });
  if (made?.refused) {
    return response.status(422).json({ error: "Only a model in the gallery can be the pick: this one is not listed, "
      + "or was taken out." });
  }
  return response.status(200).json({ pick: made.pick, id: made.model, chosen_at: made.chosen_at, until: made.until });
}

/// Choice N ended: the pick is the one worked out again, unless another
/// choice is still open.
async function unpick(request, response) {
  const choice = Number(request.query?.pick);
  if (!Number.isInteger(choice) || choice < 1) return response.status(400).json({ error: "name a choice: ?pick=<number>" });
  const ended = await db("rpc/gallery_end_pick", { method: "POST", body: { pick: choice } });
  if (ended !== true) return response.status(404).json({ error: "no open choice by that number" });
  return response.status(200).json({ pick: choice, ended: true });
}

// ---------------------------------------------------------------------------
// The monthly challenge (supabase/challenges.sql).

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const line = (given, limit) => String(given ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim()
  .slice(0, limit).trim();

/// The challenges, the ones not yet ended first (open, then upcoming by
/// their first day), then the ended ones, the one that ended last first, at most 24
/// (supabase/challenge_list_order.sql); null before challenges.sql.
async function challengesListed(tests) {
  try {
    return (await db("rpc/challenge_list", { method: "POST", body: { tests } })) || [];
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return null;
    throw trouble;
  }
}

/// Whether a year of themes can be set: supabase/challenge_year.sql applied.
async function yearReady() {
  try {
    await db("rpc/challenge_next", { method: "POST", body: { tests: false } });
    return true;
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return false;
    throw trouble;
  }
}

/// A brief as the owner typed it: its lines kept, at most 600 characters.
const briefOf = (given) => String(given ?? "").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000b-\u001f\u007f]+/g, " ")
  .replace(/\n{3,}/g, "\n\n").trim().slice(0, 600).trim();

/// What the owner's form says, checked, before the database checks it again.
function challengeAsked(given) {
  const title = line(given.title, 80);
  const brief = briefOf(given.brief);
  if (!title) return { error: "Give it a title." };
  if (!brief) return { error: "Give it a brief: a line or two of what to build." };
  const starts = String(given.starts_on || "");
  const ends = String(given.ends_on || "");
  if (!DATE.test(starts) || !DATE.test(ends) || Number.isNaN(Date.parse(starts)) || Number.isNaN(Date.parse(ends))) {
    return { error: "Give the first and the last day." };
  }
  const days = (Date.parse(ends) - Date.parse(starts)) / 864e5;
  if (days < 0) return { error: "The last day comes after the first." };
  if (days > 62) return { error: "A challenge runs at most 63 days." };
  let most = null;
  if (given.most_parts !== undefined && given.most_parts !== null && given.most_parts !== "") {
    most = Number(given.most_parts);
    if (!Number.isInteger(most) || most < 1 || most > 200000) return { error: "At most how many parts: a whole number from 1." };
  }
  let set = null;
  if (given.set_number !== undefined && given.set_number !== null && String(given.set_number).trim() !== "") {
    set = String(given.set_number).trim().toLowerCase();
    if (!/-\d+$/.test(set)) set = `${set}-1`;
    if (!/^[0-9a-z][0-9a-z.-]{0,30}$/.test(set)) return { error: "A set is its number, as 6080 or 6080-1." };
  }
  return { title, brief, starts_on: starts, ends_on: ends, most_parts: most, set_number: set, tested: given.tested === true };
}

const CHALLENGE_REFUSED = {
  past: "It would end before today.",
  set_empty: "That set's inventory has no parts in it.",
};

/// A challenge set: refused, in words, for one sharing a day with another.
async function setChallenge(request, response) {
  const asked = challengeAsked(request.body && typeof request.body === "object" ? request.body : {});
  if (asked.error) return response.status(400).json({ error: asked.error });
  let setName = null;
  let setParts = null;
  if (asked.set_number) {
    const shard = await readShard(shardOf(asked.set_number), originOf(request));
    const record = shard?.sets?.[asked.set_number];
    if (!record) {
      return response.status(422).json({ error: `No inventory here knows set ${asked.set_number}: check its number.` });
    }
    setName = String(record.n || asked.set_number).slice(0, 200);
    // Its spares too: they come in the box.
    setParts = keyed([...(record.p || []), ...(record.s || [])]);
  }
  const tests = String(request.query?.tests || "") === "1";
  let made;
  try {
    made = await db("rpc/challenge_set", { method: "POST", body: { title: asked.title, brief: asked.brief,
      starts_on: asked.starts_on, ends_on: asked.ends_on, most_parts: asked.most_parts, set_number: asked.set_number,
      set_name: setName, set_parts: setParts, tested: asked.tested, test: tests } });
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) {
      return response.status(503).json({ error: "Challenges are not open yet: supabase/challenges.sql is not applied." });
    }
    throw trouble;
  }
  if (made?.refused === "overlap") {
    return response.status(409).json({ error: `One at a time: “${made.with?.title}” has a day of these. End it first, or `
      + "choose other days." });
  }
  if (made?.refused) return response.status(422).json({ error: CHALLENGE_REFUSED[made.refused] || "That was refused." });
  return response.status(200).json({ challenge: made.challenge, starts_on: made.starts_on, ends_on: made.ends_on,
    set: setName ? { number: asked.set_number, name: setName, lots: setParts.length } : null, test: tests });
}

const MONTH = /^(\d{4})-(\d{2})$/;
const MONTH_SAID = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });

/// A year of themes, each its whole month and told a month before it opens:
/// refused whole, in words that name the month.
async function planYear(request, response) {
  const given = request.body && typeof request.body === "object" ? request.body : {};
  const asked = Array.isArray(given.themes) ? given.themes : [];
  if (!asked.length) return response.status(400).json({ error: "Give at least one month a theme." });
  if (asked.length > 12) return response.status(400).json({ error: "A year is twelve themes at most." });
  const themes = [];
  for (const one of asked) {
    const [, year, month] = MONTH.exec(String(one?.month || "")) || [];
    if (!year || Number(month) < 1 || Number(month) > 12) {
      return response.status(400).json({ error: "Each theme names its month, as 2026-11." });
    }
    const said = MONTH_SAID.format(Date.UTC(Number(year), Number(month) - 1, 1));
    const title = line(one.title, 80);
    const brief = briefOf(one.brief);
    if (!title || !brief) return response.status(400).json({ error: `${said}: give it a title and a brief.` });
    const last = new Date(Date.UTC(Number(year), Number(month), 0)).toISOString().slice(0, 10);
    themes.push({ said, title, brief, starts_on: `${year}-${month}-01`, ends_on: last });
  }
  const tests = String(request.query?.tests || "") === "1";
  let made;
  try {
    made = await db("rpc/challenge_plan", { method: "POST", body: { lead_days: 31, test: tests,
      themes: themes.map(({ title, brief, starts_on: starts, ends_on: ends }) => ({ title, brief, starts_on: starts, ends_on: ends })) } });
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) {
      return response.status(503).json({ error: "A year of themes is not open yet: supabase/challenge_year.sql is not applied." });
    }
    throw trouble;
  }
  if (made?.refused) {
    const month = themes[Number(made.at)]?.said || "A month";
    const words = { none: "Give at least one month a theme.",
      words: `${month}: a title of up to 80 characters and a brief of up to 600.`,
      past: `${month} has ended already.`,
      overlap: made.with ? `${month} shares days with “${made.with.title}”: end it first, or leave ${month} out.`
        : `Two themes share ${month}.` }[made.refused] || "That was refused.";
    return response.status(made.refused === "overlap" ? 409 : 422).json({ error: words, refused: made.refused });
  }
  return response.status(200).json({ planned: made.planned || [], test: tests });
}

/// Challenge N ended now: its winners are counted the next time it is shown.
async function endChallenge(request, response) {
  const id = Number(request.query?.challenge);
  if (!Number.isInteger(id) || id < 1) return response.status(400).json({ error: "name a challenge: ?challenge=<number>" });
  const ended = await db("rpc/challenge_end", { method: "POST", body: { challenge_id: id } });
  if (ended !== true) return response.status(404).json({ error: "no challenge by that number that has not ended" });
  return response.status(200).json({ challenge: id, ended: true });
}

/// This week's pick as a visitor's gallery shows it, the owner's choices
/// still open, and the week's best five; none of it before
/// supabase/discovery.sql.
async function picks() {
  try {
    const [now, choices, week] = await Promise.all([
      db("rpc/gallery_pick", { method: "POST", body: { tests: false } }),
      db("rpc/gallery_choices", { method: "POST", body: {} }),
      db("rpc/gallery_week", { method: "POST", body: { tests: false, size: 5 } }),
    ]);
    const card = (one) => (one ? { id: one.id, name: one.name, parts: one.parts, builds: one.builds,
      remixes: one.remixes, tested: one.tested === true } : null);
    return {
      now: now && now.card ? { pick: now.pick ?? null, chosen: now.chosen === true, until: now.until ?? null,
        week: now.week, model: card(now.card) } : null,
      choices: choices || [],
      week: (week || []).map((one) => ({ week: one.week, model: card(one.card) })),
    };
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return null;
    throw trouble;
  }
}

/// Every Tested mark showing, newest first, with its model's name; none
/// while supabase/tested.sql is not applied.
async function marks() {
  try {
    const rows = await db("share_tests?passed=is.true&cleared_at=is.null&select=model,n,at,app,parts,steps"
      + "&order=at.desc&limit=200");
    const ids = [...new Set(rows.map((row) => row.model))];
    const names = ids.length ? await db(`shared_models?id=in.(${ids.join(",")})&select=id,name,published`) : [];
    const named = new Map(names.map((one) => [one.id, one]));
    return rows.filter((row) => named.get(row.model)?.published)
      .map((row) => ({ ...row, name: named.get(row.model)?.name ?? null }));
  } catch {
    return [];
  }
}

/// The comments to show: the newest, and those reported, as
/// admin_comments gives them. None before comments.sql.
async function commentsShown(reported) {
  try {
    const [newest, named] = await Promise.all([
      db("rpc/admin_comments", { method: "POST", body: { wanted: null } }),
      reported.length ? db("rpc/admin_comments", { method: "POST", body: { wanted: reported } }) : [],
    ]);
    const all = new Map();
    for (const one of [...(named || []), ...(newest || [])]) all.set(one.id, one);
    return [...all.values()].sort((a, b) => String(b.at).localeCompare(String(a.at)));
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return [];
    throw trouble;
  }
}

const REPORTS = "/rest/v1/reports?resolved_at=is.null&select=id,model,handle,collection,reason,note,contact,at,"
  + "shared_models(name,owner,listed,published)&order=at.desc&limit=300";

async function report(tests = false) {
  const [listed, tabs, gallery, reports, barred, tested, pickNow, challenges, year] = await Promise.all([
    asServer("/auth/v1/admin/users?page=1&per_page=1000"),
    asServer("/rest/v1/relay_tabs?select=owner,seen_at,open&owner=not.is.null"),
    // What strangers can see in /gallery right now, and whose it is.
    asServer("/rest/v1/shared_models?listed=is.true&published=is.true"
      + "&select=id,owner,name,author,parts,listed_at&order=listed_at.desc&limit=500"),
    // What visitors said should not be there, still to act on; which
    // comment, once comments.sql has the column.
    asServer(REPORTS.replace("contact,at,", "contact,at,comment,")).catch(() => asServer(REPORTS)),
    asServer("/rest/v1/barred_accounts?select=account,at,reason&order=at.desc&limit=200"),
    marks(),
    picks(),
    challengesListed(tests),
    yearReady(),
  ]);
  const users = listed.users || [];
  const emails = new Map(users.map((user) => [user.id, user.email || null]));
  const comments = await commentsShown([...new Set(reports.map((one) => one.comment).filter(Boolean))]);
  const commentsById = new Map(comments.map((one) => [one.id, one]));
  // Which reports are about a photo of a build, and that photo.
  const photos = await photosReported(reports.map((one) => one.id)).catch(() => new Map());
  // The picture each reported profile shows as its avatar, if one of its own.
  const faces = await facesOf(reports.map((one) => one.handle).filter(Boolean));

  // Whose connectors, and when each was last heard from.
  const connectors = new Map();
  for (const tab of tabs) {
    const mine = connectors.get(tab.owner) || { count: 0, seen: null };
    mine.count += 1;
    if (!mine.seen || tab.seen_at > mine.seen) mine.seen = tab.seen_at;
    connectors.set(tab.owner, mine);
  }

  const week = Date.now() - 7 * 24 * 3600 * 1000;
  const people = users
    .map((user) => ({
      id: user.id,
      email: user.email || null,
      joined: user.created_at || null,
      last_sign_in: user.last_sign_in_at || null,
      connectors: connectors.get(user.id)?.count || 0,
      connector_seen: connectors.get(user.id)?.seen || null,
    }))
    .sort((a, b) => String(b.last_sign_in || "").localeCompare(String(a.last_sign_in || "")));

  return {
    accounts: people.length,
    signed_in_this_week: people.filter((p) => p.last_sign_in && Date.parse(p.last_sign_in) > week).length,
    connectors: tabs.length,
    // Asked of the configuration, not of the last send: each function is
    // its own instance, and what api/otp.js saw last is not visible here.
    email: {
      sender: process.env.EMAIL_FROM || "Brickworks <noreply@brickworks.diy>",
      // Only ever set while the proper domain waits on its DNS records,
      // so its presence is the signal that codes go out under another
      // product's name.
      borrowing: process.env.EMAIL_FROM_FALLBACK || null,
    },
    people,
    gallery: gallery.map((model) => ({
      id: model.id, name: model.name, author: model.author, parts: model.parts,
      listed_at: model.listed_at, email: emails.get(model.owner) || null,
    })),
    // Each open report with what it is about; the reporter is never named.
    reports: reports.map((report) => ({
      id: report.id, model: report.model, handle: report.handle, collection: report.collection,
      reason: report.reason, note: report.note, contact: report.contact, at: report.at,
      name: report.shared_models?.name ?? null, listed: report.shared_models?.listed ?? null,
      email: report.shared_models ? emails.get(report.shared_models.owner) || null : null,
      comment: report.comment ? commentOf(commentsById.get(report.comment), emails) ?? { id: report.comment } : null,
      photo: photos.has(report.id) ? (({ id, words, at, hidden_at: hidden, removed_at: removed, account }) => ({
        id, words, at, hidden: Boolean(hidden), removed: Boolean(removed), email: emails.get(account) || null,
      }))(photos.get(report.id)) : null,
      picture: report.handle && faces.has(report.handle) ? pictureAt(faces.get(report.handle)) : null,
    })),
    // The newest comments and the reported ones, newest first; who wrote
    // each, for the owner of this page alone.
    comments: comments.map((one) => commentOf(one, emails)),
    barred: barred.map((one) => ({ account: one.account, at: one.at, reason: one.reason,
      email: emails.get(one.account) || null })),
    tested,
    // This week's pick (supabase/discovery.sql); null before it.
    picks: pickNow,
    // The monthly challenges (supabase/challenges.sql); null before it.
    challenges,
    // Whether a year of themes can be set (supabase/challenge_year.sql).
    year,
  };
}

function commentOf(one, emails) {
  if (!one) return null;
  return { id: one.id, model: one.model, name: one.name, version: one.version, step: one.step ?? null,
    body: one.body, at: one.at, edited_at: one.edited_at ?? null, hidden: Boolean(one.hidden_at),
    removed: Boolean(one.removed_at), removed_by: one.removed_by ?? null, handle: one.handle ?? null,
    email: emails.get(one.author) || null };
}
