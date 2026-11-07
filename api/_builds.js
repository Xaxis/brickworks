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
// build-photos/<id>.jpg, and a copy at most 480 px wide beside it for the
// cards (<id>.card.jpg, made from the kept photo the first time a card asks
// for one kept before there were copies), and deletes the original
// whatever came of it.
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
import { db, orUnknown, reach } from "./_db.js";
import { cardSize, photoUrls } from "./_card.js";
import { cardPhoto, cleanPhoto, jpegSize, MAX_PHOTO_BYTES, PhotoTrouble, TYPES } from "./_photo.js";

export const UPLOADS = "build-photo-uploads";
export const PHOTOS = "build-photos";
export const MOST_ON_A_MODEL = 3;
export const MAX_WORDS = 140;
// How many photos a model's page and a profile show.
export const PHOTOS_SHOWN = 24;
/// A photo's files in PHOTOS: the kept photo, and its copy for the cards
/// (api/account.js names both too, when an account is deleted).
export const photoName = (id) => `${id}.jpg`;
export const cardName = (id) => `${id}.card.jpg`;
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
/// builds is null when the count, read after it was kept, could not be:
/// the finish was counted all the same.
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
  return { counted, builds: await orUnknown("builds", buildsOf(model)) };
}

// ---------------------------------------------------------------------------
// Storage: the two buckets, with the secret key.

function storageHeaders(extra = {}) {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, ...extra };
}

export async function getFile(bucket, name) {
  const answer = await reach(`storage GET ${bucket}`, 30, `${project()}/storage/v1/object/${bucket}/${name}`, {
    headers: storageHeaders() });
  if (answer.status === 400 || answer.status === 404) return null;
  if (!answer.ok) throw new Error(`storage GET ${bucket}: ${answer.status}`);
  return Buffer.from(await answer.arrayBuffer());
}

export async function putFile(bucket, name, body, type) {
  const answer = await reach(`storage POST ${bucket}`, 30, `${project()}/storage/v1/object/${bucket}/${name}`, {
    method: "POST", headers: storageHeaders({ "content-type": type, "x-upsert": "true", "cache-control": "no-store" }),
    body });
  if (!answer.ok) throw new Error(`storage POST ${bucket}: ${answer.status}`);
}

/// Exactly these files of [bucket], and nothing else.
export async function deleteFiles(bucket, names) {
  if (names.length === 0) return;
  const answer = await reach(`storage DELETE ${bucket}`, 20, `${project()}/storage/v1/object/${bucket}`, {
    method: "DELETE", headers: storageHeaders({ "content-type": "application/json" }),
    body: JSON.stringify({ prefixes: names }) });
  if (!answer.ok) throw new Error(`storage DELETE ${bucket}: ${answer.status}`);
}

/// A URL the browser may send one file to, once: [name] in the uploads
/// bucket. Supabase answers a path under /storage/v1; a stand-in may answer
/// an address of its own.
async function signUpload(name) {
  const answer = await reach("storage sign", 15, `${project()}/storage/v1/object/upload/sign/${UPLOADS}/${name}`, {
    method: "POST", headers: storageHeaders({ "content-type": "application/json" }), body: "{}" });
  if (answer.status === 400 || answer.status === 404) {
    const said = await answer.text().catch(() => "");
    if (/bucket|not found/i.test(said)) throw new BuildRefusal("photos of builds are not open on this deployment yet", 503);
  }
  if (!answer.ok) throw new Error(`storage sign: ${answer.status}`);
  const { url } = await answer.json();
  if (typeof url !== "string" || !url) throw new Error("storage sign: no url");
  return /^https?:\/\//.test(url) ? url : `${project()}/storage/v1${url.startsWith("/") ? "" : "/"}${url}`;
}

// ---------------------------------------------------------------------------
// The daily sweep's share (api/share.js sweep): a photo's files outlive it
// when a delete fails (keeping it, taking it out, a copy put as it went),
// or when a deployment's code deleted only the photo and not its copy.

/// A file of PHOTOS: a photo, or its copy for the cards.
const PHOTO_FILE = /^([A-Za-z0-9]{10})\.(?:card\.)?jpg$/;

/// Every file in PHOTOS: [{name, at}], a thousand a page.
export async function photosLeft() {
  const out = [];
  for (let offset = 0; ; offset += 1000) {
    const answer = await reach(`storage list ${PHOTOS}`, 20, `${project()}/storage/v1/object/list/${PHOTOS}`, {
      method: "POST", headers: storageHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ prefix: "", limit: 1000, offset, sortBy: { column: "name", order: "asc" } }) });
    if (answer.status === 400 || answer.status === 404) return out;
    if (!answer.ok) throw new Error(`storage list ${PHOTOS}: ${answer.status}`);
    const page = await answer.json();
    for (const file of page) if (file.id !== null) out.push({ name: file.name, at: file.updated_at || file.created_at });
    if (page.length < 1000) return out;
  }
}

/// Of [files] in PHOTOS ({name, at}), those to delete: a photo's or its
/// copy's whose photo has no row in [rows] ({id, removed_at}) or was taken
/// out. Never one younger than [age] ms at [now] (a photo's files are put a
/// moment before its row), unless [only] names its photo; with [only],
/// those photos' alone. Never a name no photo here has. Pure.
export function photosGone(files, rows, { now, age, only = [] }) {
  const live = new Set(rows.filter((row) => !row.removed_at).map((row) => row.id));
  return files.filter((file) => {
    const id = PHOTO_FILE.exec(file.name)?.[1];
    if (!id || live.has(id)) return false;
    return only.length ? only.includes(id) : now - Date.parse(file.at || 0) > age;
  }).map((file) => file.name);
}

/// Delete the files photosGone names: {looked_at, removed}. Before
/// builds.sql there are no rows to go by, and nothing is deleted.
export async function sweepPhotos({ now, age, only = [] }) {
  const files = (await photosLeft()).filter((file) => {
    const id = PHOTO_FILE.exec(file.name)?.[1];
    return id && (!only.length || only.includes(id));
  });
  const ids = [...new Set(files.map((file) => PHOTO_FILE.exec(file.name)[1]))];
  const rows = [];
  try {
    for (let at = 0; at < ids.length; at += 100) {
      rows.push(...await db(`build_photos?id=in.(${ids.slice(at, at + 100).join(",")})&select=id,removed_at`));
    }
  } catch (trouble) {
    if (notYet(trouble)) return { looked_at: files.length, removed: [] };
    throw trouble;
  }
  const gone = photosGone(files, rows, { now, age, only });
  for (let at = 0; at < gone.length; at += 100) await deleteFiles(PHOTOS, gone.slice(at, at + 100));
  return { looked_at: files.length, removed: gone };
}

/// Every file in the uploads bucket, by account folder: [{name, at}].
export async function uploadsLeft() {
  const out = [];
  const list = async (prefix) => {
    const answer = await reach(`storage list ${UPLOADS}`, 20, `${project()}/storage/v1/object/list/${UPLOADS}`, {
      method: "POST", headers: storageHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ prefix, limit: 1000, offset: 0 }) });
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
/// With [card], its copy for the cards (web/card.js cardSize).
export async function photoFile(id, shown, { owner = false, card = false } = {}) {
  const row = await photoRow(id);
  if (!row || row.removed_at || (row.hidden_at && !owner)) return null;
  const models = await db(`shared_models?id=eq.${row.model}&published=is.true&barred=is.false&select=id`);
  if (!models.length || !(await shown(row.account))) return null;
  return card ? cardFile(row) : getFile(PHOTOS, photoName(id));
}

/// Whether the JPEG [bytes] is [want] ({width, height}) in size.
function sized(bytes, want) {
  try {
    const got = jpegSize(bytes);
    return got.width === want.width && got.height === want.height;
  } catch {
    return false;
  }
}

/// A photo's copy for the cards, of its [row]: kept beside it, or made from
/// it and kept the first time it is asked for (a photo kept before there
/// were copies, or one whose copy is not the size the pages describe it by,
/// as a copy made before copies covered a 4:3 card). The whole photo when
/// no copy can be made of it; null when it is gone.
async function cardFile(row) {
  const { id } = row;
  const kept = await getFile(PHOTOS, cardName(id));
  const want = cardSize(row.width, row.height);
  if (kept && (!want.width || sized(kept, want))) return kept;
  const whole = await getFile(PHOTOS, photoName(id));
  if (!whole) return null;
  let made;
  try {
    made = (await cardPhoto(whole)).bytes;
  } catch (trouble) {
    console.error(`builds: no card copy of ${id}: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return whole;
  }
  await putFile(PHOTOS, cardName(id), made, "image/jpeg").catch((trouble) =>
    console.error(`builds: the card copy of ${id} was not kept: ${String(trouble?.message || trouble).slice(0, 120)}`));
  // Taken out, or its account deleted, while it was made: the copy goes
  // with it, never left behind. Both delete the photo's files by name,
  // the whole one with its copy, so a copy put after that finds the whole
  // one gone (an account's rows go only after its files).
  const now = await photoRow(id);
  if (!now || now.removed_at || !(await stillThere(photoName(id)))) {
    await deleteFiles(PHOTOS, [cardName(id)]).catch((trouble) => console.error(`builds: the card copy of ${id} outlived `
      + `its photo and was not deleted (the daily sweep takes it): ${String(trouble?.message || trouble).slice(0, 120)}`));
    return null;
  }
  return made;
}

/// Whether [name] is still in PHOTOS, asked without its bytes.
async function stillThere(name) {
  const answer = await reach(`storage HEAD ${PHOTOS}`, 30, `${project()}/storage/v1/object/${PHOTOS}/${name}`, {
    method: "HEAD", headers: storageHeaders() });
  if (answer.status === 400 || answer.status === 404) return false;
  if (!answer.ok) throw new Error(`storage HEAD ${PHOTOS}: ${answer.status}`);
  return true;
}

/// The file of any photo not taken out, for the site's owner only.
export async function photoFileForAdmin(id) {
  const row = await photoRow(id);
  if (!row || row.removed_at) return null;
  return getFile(PHOTOS, photoName(id));
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
    await putFile(PHOTOS, photoName(id), made.bytes, "image/jpeg");
    // Its card's copy: if it does not go, the first card to ask makes it.
    await putFile(PHOTOS, cardName(id), made.card.bytes, "image/jpeg").catch((trouble) =>
      console.error(`builds: the card copy of ${id} was not kept: ${String(trouble?.message || trouble).slice(0, 120)}`));
    try {
      await db("build_photos", { method: "POST", body: { id, model, account, words, width: made.width,
        height: made.height, bytes: made.bytes.length, was: made.was } });
    } catch (trouble) {
      await deleteFiles(PHOTOS, [photoName(id), cardName(id)]).catch((gone) => console.error(`builds: the files of ${id}, `
        + `not kept, were not deleted (the daily sweep takes them): ${String(gone?.message || gone).slice(0, 120)}`));
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

/// The site's owner takes a photo out: its files deleted from storage, the
/// photo and its card's copy and no other, and the row kept to say it was.
/// What was reported about it is settled.
export async function removePhoto(id, why) {
  const row = await photoRow(id);
  if (!row) throw new BuildRefusal("there is no photo at that id", 404);
  if (!row.removed_at) {
    await db(`build_photos?id=eq.${id}`, { method: "PATCH",
      body: { removed_at: new Date().toISOString(), removed_why: why || "Taken out by Brickworks" } });
  }
  await deleteFiles(PHOTOS, [photoName(id), cardName(id)]);
  const reports = await db(`report_photos?photo=eq.${id}&select=report`);
  const ids = reports.map((one) => one.report);
  if (ids.length) {
    await db(`reports?id=in.(${ids.join(",")})&resolved_at=is.null`, { method: "PATCH",
      body: { resolved_at: new Date().toISOString(), resolution: "taken_out" } });
  }
  return { id, removed: true, file: `${PHOTOS}/${photoName(id)}`, card: `${PHOTOS}/${cardName(id)}`, reports: ids.length };
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

// ---------------------------------------------------------------------------
// The gallery's Builds tab (docs/SOCIAL.md section 7, item 8): everybody's
// photos of real builds, newest first, a page of the gallery's own 24 at a
// time. A photo is in it while it may be shown anywhere (not hidden by the
// model's owner, not taken out, its builder shown in public) and, here,
// while no report of it waits for the site's owner: one page of every
// builder's photos is more than one model's strip, so a photo somebody
// says should not be there waits out of it until it is looked at. Its
// model listed in the gallery, published and not taken out, by an account
// not taken out; a test model's only when asked for.

export const BUILDS_PAGE = 24;

/// The words of a search, as a PostgREST pattern may hold them: letters and
/// digits only (no wildcard, comma or bracket of its own), the first eight.
export const searchWords = (q) => String(q || "").slice(0, 100).split(/[^\p{L}\p{N}]+/u).filter(Boolean).slice(0, 8);

/// What the database is asked for page [page] of the Builds tab: a
/// PostgREST path on build_photos, with its model's name and owner, and one
/// row more than the page holds, which says whether there is another.
/// [barred]: accounts taken out; [waiting]: photos a report waits on.
/// [q]: words searched, each in the name of the model built (any case,
/// letters and digits alone, up to eight words).
export function buildsQuery({ page = 1, tests = false, barred = [], waiting = [], q = "" }) {
  const asked = new URLSearchParams({ select: "id,model,account,words,width,height,at,shared_models!inner(name,owner)",
    removed_at: "is.null", hidden_at: "is.null", "shared_models.published": "is.true",
    "shared_models.listed": "is.true", "shared_models.barred": "is.false" });
  if (!tests) asked.set("shared_models.test", "is.false");
  for (const word of searchWords(q)) asked.append("shared_models.name", `ilike.*${word}*`);
  if (barred.length) {
    asked.set("account", `not.in.(${barred.join(",")})`);
    asked.set("shared_models.owner", `not.in.(${barred.join(",")})`);
  }
  if (waiting.length) asked.set("id", `not.in.(${waiting.join(",")})`);
  asked.set("order", "at.desc,id.desc");
  asked.set("limit", String(BUILDS_PAGE + 1));
  asked.set("offset", String((page - 1) * BUILDS_PAGE));
  return `build_photos?${asked}`;
}

/// One printable line of what a builder typed, or null.
const lineOf = (text) => String(text ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim() || null;

/// The page made of buildsQuery's [rows]: {photos, more}, each photo with
/// its model's name and its builder's {handle, name} from [people]
/// (account -> person; none for a builder with no profile), less any by
/// the accounts in [unshown] (not shown in public: under 13, or taken
/// out since). Its words as one line, every word as typed: the page
/// escapes them.
export function buildsPage(rows, { origin = "", people = {}, unshown = [] }) {
  const out = new Set(unshown);
  const shown = rows.slice(0, BUILDS_PAGE).filter((row) => ID.test(String(row.id)) && ID.test(String(row.model))
    && !out.has(row.account));
  return {
    photos: shown.map((row) => ({ id: row.id, model: row.model, model_name: String(row.shared_models?.name || ""),
      words: lineOf(row.words), width: Number(row.width) || null, height: Number(row.height) || null, at: row.at,
      by: people[row.account] ? { handle: people[row.account].handle, name: people[row.account].name } : null,
      ...photoUrls(origin, row.id), page: `${origin}/m/${row.model}#photo-${row.id}` })),
    more: rows.length > BUILDS_PAGE,
  };
}

/// Page [page] of the Builds tab: {photos, more}, as buildsPage makes it.
/// [shown] says whether an account may be shown in public (api/_trust.js
/// shownPublicly). Before builds.sql, none.
export async function galleryBuilds({ origin = "", page = 1, tests = false, q = "", shown }) {
  let barred;
  let waiting;
  let rows;
  try {
    [barred, waiting] = await Promise.all([
      db("barred_accounts?select=account"),
      db("report_photos?select=photo,reports!inner(resolved_at)&reports.resolved_at=is.null"),
    ]);
    rows = await db(buildsQuery({ page, tests, q, barred: barred.map((one) => one.account),
      waiting: [...new Set(waiting.map((one) => one.photo))].filter((id) => ID.test(String(id))) }));
  } catch (trouble) {
    if (notYet(trouble)) return { photos: [], more: false };
    throw trouble;
  }
  const accounts = [...new Set(rows.slice(0, BUILDS_PAGE).map((row) => row.account))];
  const [people, allowed] = await Promise.all([
    accounts.length ? db(`people?account=in.(${accounts.join(",")})&select=account,handle,name`) : [],
    Promise.all(accounts.map(async (one) => [one, await shown(one)])),
  ]);
  return buildsPage(rows, { origin, people: Object.fromEntries(people.map((one) => [one.account, one])),
    unshown: allowed.filter(([, may]) => !may).map(([one]) => one) });
}
