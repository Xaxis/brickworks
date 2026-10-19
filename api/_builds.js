// Real builds (2026-10-18, supabase/builds.sql): builds finished, counted
// once per device, and "I built it" photos of them.
//
// A finish. The app sends one when a model's last step is reached from the
// step before, in the step player or the viewer (src/main.gd), with a key
// its device made for itself at random and keeps: POST /api/share?op=built.
// Only for what looks like a person, as a view is counted: a browser's
// fetch from this site's own page, or the desktop app, which says it is
// with its user agent ("Brickworks/0.3.0 (desktop)"). What is kept is an
// HMAC of the model and the device's key with a secret only this server
// has, so the same device counts once, and no row can be taken back to a
// device, nor one model's finishes matched to another's.
//
// A photo. An account that said it is 13 or over (api/_trust.js) adds a
// photo of its real build to a model, with a line: at most three on a
// model, a few an hour (may_act). The phone sends it straight to storage,
// at most 8 MB, through an upload URL signed here for one path of the
// account's own (a function cannot take a body over 4.5 MB), then asks for
// it to be kept (?op=photo): the server reads the original, makes a new
// JPEG from its pixels alone (api/_photo.js: no metadata survives, and
// what is not a picture does not decode), keeps that as
// build-photos/<id>.jpg, and deletes the original whatever came of it.
//
// Shown on the model's page as a strip of builds and on the builder's
// profile, while it may be: not hidden by the model's owner, not taken out
// by the site's owner (its file deleted), its model published and not taken
// out, its builder neither taken out nor under 13. Anyone can report one
// (api/people.js ?op=report with photo), which the admin page shows with
// the photo and can take out.
//
// Until builds.sql is applied, its tables are not there: nothing is
// counted, no photo is shown, and asking to add one says so.

import { createHmac, randomBytes } from "node:crypto";
import { db } from "./_db.js";
import { cleanPhoto, MAX_PHOTO_BYTES, PhotoTrouble, TYPES } from "./_photo.js";

export const UPLOADS = "build-photo-uploads";
export const PHOTOS = "build-photos";
export const MOST_ON_A_MODEL = 3;
export const MAX_WORDS = 140;
// How many photos a model's page and a profile show.
export const PHOTOS_SHOWN = 24;
const ID = /^[A-Za-z0-9]{10}$/;
const DEVICE = /^[0-9a-f]{32}$/;
const TICKET = /^[0-9a-f]{32}\.(jpg|png|webp)$/;
const EXTENSION = { jpeg: "jpg", png: "png", webp: "webp" };
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
const APP = /^Brickworks\/[0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.+-]* \(desktop\b/;

export class BuildRefusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

const NOT_YET = /: 40[04]$/;
/// Whether the database said a table or a function of builds.sql is not there.
const notYet = (trouble) => NOT_YET.test(String(trouble?.message || ""));

function project() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

export function newPhotoId() {
  let id = "";
  for (const byte of randomBytes(10)) id += ALPHABET[byte % ALPHABET.length];
  return id;
}

// ---------------------------------------------------------------------------
// Builds finished.

/// Whether the desktop app sent this: its own user agent, which no browser
/// and no robot sends.
export const fromTheApp = (request) => APP.test(String(request.headers?.["user-agent"] || ""));

/// The key a finish is kept under: the model and the device's own key,
/// through an HMAC nobody else can make, cut to 32 hex.
export function buildKey(model, device) {
  const secret = process.env.VIEW_SECRET || process.env.SUPABASE_SECRET_KEY || "";
  return createHmac("sha256", `builds:${secret}`).update(`${model}\n${device}`).digest("hex").slice(0, 32);
}

/// How many have built [model], or 0 before builds.sql.
export async function buildsOf(model) {
  try {
    const rows = await db(`model_stats?model=eq.${model}&select=builds`);
    return Number(rows[0]?.builds) || 0;
  } catch (trouble) {
    if (notYet(trouble)) return 0;
    throw trouble;
  }
}

/// A finish, counted once per device: {counted, builds}. [person] says
/// whether the request looks like one (api/_directory.js looksLikePerson).
export async function countBuild(model, device, person) {
  if (!ID.test(model || "")) throw new BuildRefusal("name a link: ?id=<ten characters>");
  if (!DEVICE.test(device || "")) throw new BuildRefusal("device is the 32 hex digits this device keeps");
  let counted = false;
  if (person) {
    try {
      counted = (await db("rpc/count_build", { method: "POST",
        body: { model_id: model, device_key: buildKey(model, device) } })) === true;
    } catch (trouble) {
      if (!notYet(trouble)) throw trouble;
    }
  }
  return { counted, builds: await buildsOf(model) };
}

// ---------------------------------------------------------------------------
// Storage: the two buckets, with the secret key.

function storageHeaders(extra = {}) {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, ...extra };
}

async function getFile(bucket, name) {
  const answer = await fetch(`${project()}/storage/v1/object/${bucket}/${name}`, {
    headers: storageHeaders(), signal: AbortSignal.timeout(30000) });
  if (answer.status === 400 || answer.status === 404) return null;
  if (!answer.ok) throw new Error(`storage GET ${bucket}: ${answer.status}`);
  return Buffer.from(await answer.arrayBuffer());
}

async function putFile(bucket, name, body, type) {
  const answer = await fetch(`${project()}/storage/v1/object/${bucket}/${name}`, {
    method: "POST", headers: storageHeaders({ "content-type": type, "x-upsert": "true", "cache-control": "no-store" }),
    body, signal: AbortSignal.timeout(30000) });
  if (!answer.ok) throw new Error(`storage POST ${bucket}: ${answer.status}`);
}

/// Exactly these files of [bucket], and nothing else.
export async function deleteFiles(bucket, names) {
  if (names.length === 0) return;
  const answer = await fetch(`${project()}/storage/v1/object/${bucket}`, {
    method: "DELETE", headers: storageHeaders({ "content-type": "application/json" }),
    body: JSON.stringify({ prefixes: names }), signal: AbortSignal.timeout(20000) });
  if (!answer.ok) throw new Error(`storage DELETE ${bucket}: ${answer.status}`);
}

/// A URL the browser may send one file to, once: [name] in the uploads
/// bucket. Supabase answers a path under /storage/v1; a stand-in may answer
/// an address of its own.
async function signUpload(name) {
  const answer = await fetch(`${project()}/storage/v1/object/upload/sign/${UPLOADS}/${name}`, {
    method: "POST", headers: storageHeaders({ "content-type": "application/json" }), body: "{}",
    signal: AbortSignal.timeout(15000) });
  if (answer.status === 400 || answer.status === 404) {
    const said = await answer.text().catch(() => "");
    if (/bucket|not found/i.test(said)) throw new BuildRefusal("photos of builds are not open on this deployment yet", 503);
  }
  if (!answer.ok) throw new Error(`storage sign: ${answer.status}`);
  const { url } = await answer.json();
  if (typeof url !== "string" || !url) throw new Error("storage sign: no url");
  return /^https?:\/\//.test(url) ? url : `${project()}/storage/v1${url.startsWith("/") ? "" : "/"}${url}`;
}

/// Every file in the uploads bucket, by account folder: [{name, at}].
export async function uploadsLeft() {
  const out = [];
  const list = async (prefix) => {
    const answer = await fetch(`${project()}/storage/v1/object/list/${UPLOADS}`, {
      method: "POST", headers: storageHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ prefix, limit: 1000, offset: 0 }), signal: AbortSignal.timeout(20000) });
    if (answer.status === 400 || answer.status === 404) return [];
    if (!answer.ok) throw new Error(`storage list ${UPLOADS}: ${answer.status}`);
    return answer.json();
  };
  for (const folder of await list("")) {
    if (folder.id !== null) continue;
    for (const file of await list(`${folder.name}/`)) {
      if (file.id !== null) out.push({ name: `${folder.name}/${file.name}`, at: file.updated_at || file.created_at });
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Photos.

/// The photos that may be shown of [where] (a PostgREST filter on
/// build_photos), newest first, each with who built it: [{id, model, words,
/// width, height, at, by: {handle, name} | null}]. [shown] says whether an
/// account may be shown in public (api/_trust.js shownPublicly). With
/// [hidden], the model's owner's view: the hidden ones too, marked.
export async function photosWhere(where, shown, { hidden = false, limit = PHOTOS_SHOWN } = {}) {
  let rows;
  try {
    rows = await db(`build_photos?${where}&removed_at=is.null&select=id,model,account,words,width,height,at,hidden_at`
      + `&order=at.desc&limit=${limit * 2}`);
  } catch (trouble) {
    if (notYet(trouble)) return [];
    throw trouble;
  }
  rows = rows.filter((row) => hidden || !row.hidden_at);
  const accounts = [...new Set(rows.map((row) => row.account))];
  const allowed = new Map(await Promise.all(accounts.map(async (one) => [one, await shown(one)])));
  rows = rows.filter((row) => allowed.get(row.account));
  const people = accounts.length ? await db(`people?account=in.(${accounts.join(",")})&select=account,handle,name`) : [];
  const named = new Map(people.map((one) => [one.account, { handle: one.handle, name: one.name }]));
  return rows.slice(0, limit).map((row) => ({ id: row.id, model: row.model, words: row.words ?? null,
    width: row.width, height: row.height, at: row.at, by: named.get(row.account) || null,
    hidden: Boolean(row.hidden_at), account: row.account }));
}

/// One photo's row, whatever its state, or null.
export async function photoRow(id) {
  if (!ID.test(id || "")) return null;
  try {
    const rows = await db(`build_photos?id=eq.${id}&select=id,model,account,words,width,height,at,hidden_at,removed_at`);
    return rows[0] || null;
  } catch (trouble) {
    if (notYet(trouble)) return null;
    throw trouble;
  }
}

/// How many photos [account] has on [model] that count against the three.
async function photosBy(account, model) {
  const rows = await db(`build_photos?account=eq.${account}&model=eq.${model}&removed_at=is.null&select=id`);
  return rows.length;
}

/// The photo's file, for whoever may see it: null when it may not be shown
/// (hidden, taken out, its model down, its builder not shown) or is gone.
export async function photoFile(id, shown, { owner = false } = {}) {
  const row = await photoRow(id);
  if (!row || row.removed_at || (row.hidden_at && !owner)) return null;
  const models = await db(`shared_models?id=eq.${row.model}&published=is.true&barred=is.false&select=id`);
  if (!models.length || !(await shown(row.account))) return null;
  return getFile(PHOTOS, `${id}.jpg`);
}

/// The file of any photo not taken out, for the site's owner only.
export async function photoFileForAdmin(id) {
  const row = await photoRow(id);
  if (!row || row.removed_at) return null;
  return getFile(PHOTOS, `${id}.jpg`);
}

/// Step one of a photo: where the phone sends it. {upload, ticket, most}.
/// [check] is the caller's own refusals (the age rule, the rate limit),
/// asked once everything about the photo itself is in order.
export async function startPhoto(account, model, { type, size }, check) {
  if (!TYPES[type]) throw new BuildRefusal("a photo is a JPEG, a PNG or a WebP", 415);
  if (!Number.isInteger(size) || size < 1) throw new BuildRefusal("say how big the photo is, in bytes");
  if (size > MAX_PHOTO_BYTES) {
    throw new BuildRefusal(`that photo is ${(size / 1048576).toFixed(1)} MB: at most 8 MB, please`, 413);
  }
  await room(account, model);
  await check();
  const ticket = `${randomBytes(16).toString("hex")}.${EXTENSION[TYPES[type]]}`;
  const upload = await signUpload(`${account}/${ticket}`);
  // The publishable key, which is meant for a page (api/account.js serves
  // it): the storage gateway wants one beside the URL's own token.
  return { upload, ticket, type, most: MAX_PHOTO_BYTES, key: process.env.SUPABASE_PUBLISHABLE_KEY || "" };
}

/// Whether [account] may add another photo to [model]: three at most.
async function room(account, model) {
  let had;
  try {
    had = await photosBy(account, model);
  } catch (trouble) {
    if (notYet(trouble)) throw new BuildRefusal("photos of builds are not open on this deployment yet", 503);
    throw trouble;
  }
  if (had >= MOST_ON_A_MODEL) {
    throw new BuildRefusal(`you have ${MOST_ON_A_MODEL} photos on this model already: that is the most`, 409);
  }
}

/// Step two: the photo the phone sent, made safe and kept. The original is
/// deleted however it goes. {id, width, height, words, was}.
export async function keepPhoto(account, model, ticket, words, check) {
  if (!TICKET.test(ticket || "")) throw new BuildRefusal("that is not a photo this server asked for");
  const original = `${account}/${ticket}`;
  try {
    await room(account, model);
    await check();
    const sent = await getFile(UPLOADS, original);
    if (!sent) throw new BuildRefusal("the photo did not arrive: send it again", 404);
    const declared = { jpg: "image/jpeg", png: "image/png", webp: "image/webp" }[ticket.split(".").pop()];
    let made;
    try {
      made = await cleanPhoto(sent, declared);
    } catch (trouble) {
      if (trouble instanceof PhotoTrouble) throw new BuildRefusal(trouble.message, trouble.status);
      throw trouble;
    }
    const id = newPhotoId();
    await putFile(PHOTOS, `${id}.jpg`, made.bytes, "image/jpeg");
    try {
      await db("build_photos", { method: "POST", body: { id, model, account, words, width: made.width,
        height: made.height, bytes: made.bytes.length, was: made.was } });
    } catch (trouble) {
      await deleteFiles(PHOTOS, [`${id}.jpg`]).catch(() => {});
      if (/: 400$/.test(trouble.message)) {
        throw new BuildRefusal("that photo could not be kept: the most is three on a model, by accounts 13 or over", 422);
      }
      throw trouble;
    }
    return { id, width: made.width, height: made.height, words, was: made.was, bytes: made.bytes.length };
  } finally {
    await deleteFiles(UPLOADS, [original]).catch((trouble) =>
      console.error(`builds: the original was not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`));
  }
}

/// The model's owner hides a photo on their model, or shows it again.
export async function hidePhoto(account, id, on) {
  const row = await photoRow(id);
  if (!row || row.removed_at) throw new BuildRefusal("there is no photo at that id", 404);
  const models = await db(`shared_models?id=eq.${row.model}&select=owner`);
  if (models[0]?.owner !== account) throw new BuildRefusal("only the model's owner hides a photo on it", 403);
  await db(`build_photos?id=eq.${id}`, { method: "PATCH", body: { hidden_at: on ? new Date().toISOString() : null } });
  return { id, hidden: on };
}

/// The site's owner takes a photo out: its file deleted from storage, that
/// one file and no other, and the row kept to say it was. What was
/// reported about it is settled.
export async function removePhoto(id, why) {
  const row = await photoRow(id);
  if (!row) throw new BuildRefusal("there is no photo at that id", 404);
  if (!row.removed_at) {
    await db(`build_photos?id=eq.${id}`, { method: "PATCH",
      body: { removed_at: new Date().toISOString(), removed_why: why || "Taken out by Brickworks" } });
  }
  await deleteFiles(PHOTOS, [`${id}.jpg`]);
  const reports = await db(`report_photos?photo=eq.${id}&select=report`);
  const ids = reports.map((one) => one.report);
  if (ids.length) {
    await db(`reports?id=in.(${ids.join(",")})&resolved_at=is.null`, { method: "PATCH",
      body: { resolved_at: new Date().toISOString(), resolution: "taken_out" } });
  }
  return { id, removed: true, file: `${PHOTOS}/${id}.jpg`, reports: ids.length };
}

/// Which photo each of [reports] is about: report id -> photo row.
export async function photosReported(reports) {
  if (reports.length === 0) return new Map();
  let links;
  try {
    links = await db(`report_photos?report=in.(${reports.join(",")})&select=report,photo`);
  } catch (trouble) {
    if (notYet(trouble)) return new Map();
    throw trouble;
  }
  const ids = [...new Set(links.map((one) => one.photo))];
  const rows = ids.length ? await db(`build_photos?id=in.(${ids.join(",")})`
    + "&select=id,model,account,words,at,hidden_at,removed_at") : [];
  const byId = new Map(rows.map((row) => [row.id, row]));
  return new Map(links.filter((one) => byId.has(one.photo)).map((one) => [one.report, byId.get(one.photo)]));
}

/// A report is about this photo.
export async function reportPhoto(report, photo) {
  await db("report_photos", { method: "POST", body: { report, photo } });
}
