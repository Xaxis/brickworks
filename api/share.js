// Sharing a model by link (2026-10-12).
//
// Someone signed in publishes the model they have open, from File ›
// Share… in the app, and gets https://brickworks.diy/m/<id>. Anyone may
// open that link without an account: the app in a read-only mode
// (/app?view=<id>) with the model, its steps, its booklet and its parts
// list, and Open in Brickworks to copy it into their own account.
//
//   GET  ?id=X               the model, as the viewer loads it: name,
//                            author, part count and the .mpd itself
//   GET  ?op=page&id=X       /m/X: the link's own page — a title and a
//                            picture for anything that previews links,
//                            and then the viewer
//   GET  ?op=image&id=X      /m/X.png: that picture, rendered by the app
//                            when it published
//   GET  ?op=embed&id=X      /m/X/embed: a card for a blog or a forum to
//                            put in an iframe
//   GET  ?op=thumb&id=X      /m/X.webp: the small picture the gallery's
//                            cards show, made by the app beside the big one
//   GET  ?op=list&page=N     /gallery's models: the listed ones, a page at
//                            a time, searched (q), filtered (kind, size,
//                            instructions, technic, tag) and sorted (sort:
//                            newest, views, likes, remixes)
//   POST                     publish, with the session: {name, author?,
//                            model, image?, thumb?, id?, listed?,
//                            remixed_from?, description?, tags?, kind?,
//                            licence?}. With an id, the owner's own link is
//                            updated in place. listed puts it in the
//                            gallery; remixed_from is the link it was
//                            copied from (Open in Brickworks), which its
//                            page names. What it says about itself is kept
//                            on a republish that does not say it again.
//   POST ?op=seen&id=X       its page was looked at: counted once a day per
//                            visitor, and never for a robot
//   POST ?op=unpublish&id=X  the owner takes it down
//   GET  ?op=mine            the session's own links
//   GET  ?op=sweep           the daily clean-up (Vercel's cron, with
//                            CRON_SECRET): files no published row owns
//
// Where it is kept and who may touch it is in supabase/shared_models.sql.
// In short: a visitor's read goes through the publishable key, so row
// security is what decides that a row is published, and the files are
// read with the secret key only after that. Every write is here, after
// the session has been verified and the row found to be the caller's.
//
// The upload is checked at this edge, before anything is stored: LDraw
// text only (every line one of LDraw's six kinds, well formed, at least
// one part), at most 2 MB, a PNG picture of at most 600 KB, and a name.
// The part count is the server's own, counted here, not the client's.
//
// The gallery (2026-10-13, supabase/gallery.sql) shows what a person
// chose to list, and so names and pictures strangers chose: a name is one
// printable line of at most 80 characters, escaped wherever a page shows
// it; listing is counted (may_list) on top of publishing; and the site's
// owner can take any model out of it for good (api/admin.js).
//
// The directory (2026-10-13, supabase/directory.sql, api/_directory.js)
// searches, filters and sorts the gallery, and gives each model a page of
// its own at /m/X: what its owner wrote about it, its tags, its kind and
// its licence, how many have looked, liked and remixed it, and its remix
// tree. The facts the filters use that are about the file — its steps,
// whether they are its builder's own, whether it is Technic — are counted
// here from the file, like the part count. Nothing a page does writes per
// request: a view is a beacon the page sends once a day (?op=seen), and
// counted once per visitor per day, never for a robot.

import { randomBytes, timingSafeEqual } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { originOf } from "./_oauth.js";
import {
  KINDS, LICENCES, NOTICE, SIZES, SORTS, Unacceptable, cardOf, cleanDescription, cleanKind,
  cleanLicence, cleanTags, count, escapeHtml, isTechnic, kindLabel, listQuery, looksLikePerson,
  modelHash, partFacts, siteChrome, visitorKey,
} from "./_directory.js";
import { namesTrouble } from "./_names.js";

export const MAX_MODEL_BYTES = 2 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 600 * 1024;
export const MAX_THUMB_BYTES = 64 * 1024;
const MAX_NAME = 80;
const MAX_AUTHOR = 60;
const BUCKET = "shared-models";
// The gallery's small pictures, in a bucket of their own
// (supabase/directory.sql): shared-models takes only its two kinds of file.
const THUMBS = "shared-thumbs";
/// Which bucket a file is in: the small pictures in theirs.
const bucketOf = (name) => (name.endsWith(".webp") ? THUMBS : BUCKET);
const ID = /^[A-Za-z0-9]{10}$/;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
// What a visitor's key may read: the columns supabase/shared_models.sql
// and supabase/gallery.sql grant, which are all of them but the owner and
// barred.
const PUBLIC = "id,name,author,parts,bytes,has_image,published,updated_at,listed,remixed_from,"
  + "description,tags,licence,kind,has_thumb";
export const PER_PAGE = 24;
const MOST_PAGES = 400;
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const RIFF = Buffer.from("RIFF");
const WEBP = Buffer.from("WEBP");

function project() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// Ten characters from an alphabet without the ones people misread
/// (0/O, 1/l/I): about 58 bits, so a link cannot be guessed.
function newId() {
  const bytes = randomBytes(10);
  let id = "";
  for (const byte of bytes) id += ALPHABET[byte % ALPHABET.length];
  return id;
}

// ---------------------------------------------------------------------------
// The model's text, checked.

const NUMBER = /^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/;
const COLOUR = /^(\d+|0x[0-9A-Fa-f]{7})$/;
// How many numbers follow the line type and colour for each kind of line.
const COORDS = { 2: 6, 3: 9, 4: 12, 5: 12 };

// The pieces a hose, a tube, a flexible axle or a string is laid from
// along a bend, by the kind they are of (Flex.KINDS, src/assembly/flex.gd).
// A submodel of nothing but one kind's pieces is the one part a shop sells,
// as the app's parts list counts it (Inventory.of): a ribbed hose is two
// ends and thirty rings in the file and one hose to buy. A chain is its
// links, which are what is sold, and they count as themselves.
const FLEX_PIECES = new Map([
  ["71944k01", "ribbed_hose"], ["71944k02", "ribbed_hose"],
  ["71533k02", "pneumatic_tube"], ["71533k03", "pneumatic_tube"],
  ["u9053", "flex_hose"], ["77", "flex_hose"],
  ["u9010", "flex_axle"], ["u9011", "flex_axle"], ["u9012", "flex_axle"],
  ["71149k01", "string"], ["71149k02", "string"],
]);

/// Whether a file's parts are all one flexible part's pieces.
function laidFlexible(placed) {
  const kinds = new Set(placed.map((ref) => FLEX_PIECES.get(ref.replace(/\.dat$/, ""))));
  return placed.length > 0 && kinds.size === 1 && !kinds.has(undefined);
}

export class Refusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

/// Whether [text] is an LDraw model, and how many parts it has.
///
/// Every line must be one of LDraw's six kinds: 0 a comment or meta
/// command, 1 a part or submodel placed with a colour and a matrix, 2 to 5
/// lines and faces. That is what an .ldr, a .dat and an .mpd are, prints,
/// stickers and custom parts included — those travel inside the .mpd as
/// `0 FILE` sections and `0 !DATA` blocks, which are type 0 lines. A JSON
/// file, a picture or a script fails on its first line.
///
/// Parts are counted through the model's own submodels: a submodel
/// placed three times is its parts three times. A `0 FILE` whose name
/// ends .dat is a part (LDraw's own convention, and how the app writes a
/// custom part), so it counts once wherever it is placed; so does a
/// submodel that is a hose laid along a bend (FLEX_PIECES).
///
/// And what the gallery filters on, read from the same lines: how many
/// build steps the model has (its own file's, split by 0 STEP and 0
/// ROTSTEP), whether they are its builder's (LdrModel.steps_are_authored:
/// steps there, and either marked so by Brickworks or written by another
/// tool), and how many of its parts are Technic and how many make it move
/// (partFacts), counted through its submodels as its parts are.
export function checkModel(text) {
  if (typeof text !== "string" || text.trim() === "") {
    throw new Refusal("there is no model to share");
  }
  const bytes = Buffer.byteLength(text, "utf8");
  if (bytes > MAX_MODEL_BYTES) {
    throw new Refusal(`that model is ${(bytes / 1048576).toFixed(1)} MB, and a shared model can be at most 2 MB`, 413);
  }
  // Control characters other than tab, line feed and carriage return
  // have no place in LDraw, and NUL is how a binary file gives itself away.
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)) {
    throw new Refusal("that is not LDraw text: it has binary in it", 415);
  }

  const files = new Map();
  const order = [];
  let current = { name: "", placed: [], isPart: false, steps: 0, open: false, author: "" };
  let inData = false;
  let lineNo = 0;
  let stepped = false;
  let markedAuthored = false;
  // A file is known once it has a name or places something: an .ldr
  // has no 0 FILE line, and an .mpd starts with one.
  const keep = () => {
    if (!files.has(current.name)) {
      files.set(current.name, current);
      order.push(current.name);
    }
  };
  const start = (name) => {
    current = { name: name.toLowerCase(), placed: [], isPart: /\.dat$/i.test(name), steps: 0, open: false, author: "" };
    keep();
  };

  for (const raw of text.replace(/^﻿/, "").split(/\r?\n/)) {
    lineNo += 1;
    const line = raw.trim();
    if (line === "") continue;
    const tokens = line.split(/\s+/);
    const kind = tokens[0];
    if (!/^[0-5]$/.test(kind)) {
      throw new Refusal(`that is not LDraw text: line ${lineNo} does not start with an LDraw line type`, 415);
    }
    if (kind === "0") {
      const meta = (tokens[1] || "").toUpperCase();
      if (meta === "FILE") {
        start(line.replace(/^0\s+FILE\s+/i, "").trim());
        inData = false;
      } else if (meta === "!DATA") {
        // An embedded picture: base64 in `0 !:` lines, not a model.
        inData = true;
        current = { name: "", placed: [], isPart: true };
      } else if (meta === "NOFILE") {
        inData = false;
      } else if (meta === "!LDRAW_ORG" && /part|shortcut|primitive|subpart/i.test(tokens[2] || "")) {
        current.isPart = true;
      } else if (meta === "STEP" || meta === "ROTSTEP") {
        // A step ends with its parts: a STEP with none since the last is
        // not one, as a file's closing 0 STEP is not.
        stepped = true;
        if (current.open) current.steps += 1;
        current.open = false;
      } else if (meta === "AUTHOR:" && !current.author) {
        current.author = line.replace(/^0\s+Author:\s*/i, "").trim();
      } else if (meta === "!BRICKWORKS" && (tokens[2] || "").toUpperCase() === "AUTHORED_STEPS") {
        markedAuthored = true;
      }
      continue;
    }
    if (inData) {
      throw new Refusal(`that is not LDraw text: line ${lineNo} is inside a 0 !DATA block`, 415);
    }
    if (kind === "1") {
      if (tokens.length < 15 || !COLOUR.test(tokens[1]) || !tokens.slice(2, 14).every((t) => NUMBER.test(t))) {
        throw new Refusal(`that is not LDraw text: line ${lineNo} is not a well-formed part line`, 415);
      }
      keep();
      current.placed.push(line.split(/\s+/).slice(14).join(" ").toLowerCase());
      current.open = true;
    } else {
      const need = COORDS[kind];
      if (tokens.length !== need + 2 || !COLOUR.test(tokens[1]) || !tokens.slice(2).every((t) => NUMBER.test(t))) {
        throw new Refusal(`that is not LDraw text: line ${lineNo} is not a well-formed type ${kind} line`, 415);
      }
    }
  }

  // The first file is the model; the rest are what it places. Each file
  // counts as [parts, Technic parts, parts that move].
  const facts = partFacts();
  const kindOf = (ref) => {
    const id = ref.replace(/\.dat$/, "");
    return [1, facts.technic.has(id) ? 1 : 0, facts.mechanism.has(id) ? 1 : 0];
  };
  const counted = new Map();
  const visiting = new Set();
  const tally = (name) => {
    const file = files.get(name);
    if (!file) return kindOf(name);
    if (file.isPart || laidFlexible(file.placed)) return [1, 0, 0];
    if (counted.has(name)) return counted.get(name);
    if (visiting.has(name)) throw new Refusal("that model places itself inside itself", 415);
    visiting.add(name);
    const total = [0, 0, 0];
    for (const ref of file.placed) {
      const one = files.has(ref) ? tally(ref) : kindOf(ref);
      for (let k = 0; k < 3; k += 1) total[k] += one[k];
    }
    visiting.delete(name);
    counted.set(name, total);
    return total;
  };
  const main = order.find((name) => !files.get(name).isPart);
  const [parts, technicParts, movingParts] = main === undefined ? [0, 0, 0] : tally(main);
  if (parts < 1) throw new Refusal("that model has no parts in it", 415);
  if (parts > 200000) throw new Refusal("that model has more parts than a shared model can have", 413);
  const top = files.get(main);
  const steps = Math.max(1, top.steps + (top.open ? 1 : 0));
  const ownSteps = stepped && (markedAuthored || top.author !== "Brickworks");
  return { parts, bytes, steps, ownSteps, technic: isTechnic(parts, technicParts, movingParts) };
}

/// The picture, from the base64 the app sends, or null for none.
export function checkImage(given) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string" || !/^[A-Za-z0-9+/]+=*$/.test(given)) {
    throw new Refusal("the picture is not readable", 415);
  }
  const bytes = Buffer.from(given, "base64");
  if (bytes.length > MAX_IMAGE_BYTES) throw new Refusal("the picture is too large", 413);
  if (bytes.length < PNG.length || !bytes.subarray(0, PNG.length).equals(PNG)) {
    throw new Refusal("the picture is not a PNG", 415);
  }
  return bytes;
}

/// The small picture for the gallery's cards, from the base64 the app
/// sends, or null for none: a WebP of at most 64 KB.
export function checkThumb(given) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string" || !/^[A-Za-z0-9+/]+=*$/.test(given)) {
    throw new Refusal("the small picture is not readable", 415);
  }
  const bytes = Buffer.from(given, "base64");
  if (bytes.length > MAX_THUMB_BYTES) throw new Refusal("the small picture is too large", 413);
  if (bytes.length < 16 || !bytes.subarray(0, 4).equals(RIFF) || !bytes.subarray(8, 12).equals(WEBP)) {
    throw new Refusal("the small picture is not a WebP", 415);
  }
  return bytes;
}

/// A name for a link: one line, printable, trimmed to its limit.
function cleanText(given, limit) {
  if (typeof given !== "string") return "";
  return given.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, limit).trim();
}

// ---------------------------------------------------------------------------
// The database and the bucket.

/// A published row, read as a visitor reads it: through the publishable
/// key, so row security is what says it is published.
async function publishedRow(id) {
  if (!ID.test(id || "")) return null;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  const answer = await fetch(`${project()}/rest/v1/shared_models?id=eq.${id}&select=${PUBLIC}`, {
    headers: { apikey: key },
    signal: AbortSignal.timeout(10000),
  });
  if (!answer.ok) throw new Error(`database GET shared_models: ${answer.status}`);
  const rows = await answer.json();
  return rows[0] || null;
}

/// Whether a link that is not published ever was: "taken down" and "no
/// such link" are different things to tell somebody.
async function wasShared(id) {
  if (!ID.test(id || "")) return false;
  const rows = await db(`shared_models?id=eq.${id}&select=id`);
  return rows.length > 0;
}

async function ownRow(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`shared_models?id=eq.${id}&select=id,owner,published,listed,listed_at,barred,remixed_from,`
    + "description,tags,kind,licence");
  return rows[0] || null;
}

/// The link a model says it was copied from, as {id, owner, licence}: null
/// for none, or for one that is not there any more (it went with its
/// account). An id that is not one is refused, like anything else
/// malformed at this edge.
async function remixOf(given, self) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string" || !ID.test(given)) throw new Refusal("remixed_from is not a link");
  if (given === self) return null;
  const rows = await db(`shared_models?id=eq.${given}&select=id,owner,licence`);
  return rows[0] || null;
}

function storageHeaders(extra = {}) {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, ...extra };
}

async function putFile(name, body, type) {
  const answer = await fetch(`${project()}/storage/v1/object/${bucketOf(name)}/${name}`, {
    method: "POST",
    headers: storageHeaders({ "content-type": type, "x-upsert": "true", "cache-control": "no-store" }),
    body,
    signal: AbortSignal.timeout(20000),
  });
  if (!answer.ok) throw new Error(`storage POST ${name.split(".").pop()}: ${answer.status}`);
}

async function getFile(name) {
  const answer = await fetch(`${project()}/storage/v1/object/${bucketOf(name)}/${name}`, {
    headers: storageHeaders(),
    signal: AbortSignal.timeout(20000),
  });
  if (answer.status === 400 || answer.status === 404) return null;
  if (!answer.ok) throw new Error(`storage GET ${name.split(".").pop()}: ${answer.status}`);
  return Buffer.from(await answer.arrayBuffer());
}

async function deleteFiles(names) {
  for (const bucket of [BUCKET, THUMBS]) {
    const these = names.filter((name) => bucketOf(name) === bucket);
    if (these.length === 0) continue;
    const answer = await fetch(`${project()}/storage/v1/object/${bucket}`, {
      method: "DELETE",
      headers: storageHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ prefixes: these }),
      signal: AbortSignal.timeout(20000),
    });
    if (!answer.ok) throw new Error(`storage DELETE: ${answer.status}`);
  }
}

/// Every file in both buckets, a page at a time: [{name, updated_at}].
async function listFiles() {
  const files = [];
  for (const bucket of [BUCKET, THUMBS]) {
    for (let offset = 0; ; offset += 1000) {
      const answer = await fetch(`${project()}/storage/v1/object/list/${bucket}`, {
        method: "POST",
        headers: storageHeaders({ "content-type": "application/json" }),
        body: JSON.stringify({ prefix: "", limit: 1000, offset, sortBy: { column: "name", order: "asc" } }),
        signal: AbortSignal.timeout(20000),
      });
      if (!answer.ok) throw new Error(`storage list: ${answer.status}`);
      const page = await answer.json();
      files.push(...page.filter((file) => file.id !== null));
      if (page.length < 1000) break;
    }
  }
  return files;
}

async function mayPublish(owner) {
  const allowed = await db("rpc/may_publish", { method: "POST", body: { account: owner } });
  return allowed === true;
}

async function barred(owner) {
  return (await db("rpc/is_barred", { method: "POST", body: { account: owner } })) === true;
}

async function barredFile(text) {
  const rows = await db(`barred_models?hash=eq.${modelHash(text)}&select=hash`);
  return rows.length > 0;
}

async function mayList(owner) {
  const allowed = await db("rpc/may_list", { method: "POST", body: { account: owner } });
  return allowed === true;
}

// ---------------------------------------------------------------------------
// What a link answers.

function links(origin, id) {
  const url = `${origin}/m/${id}`;
  return {
    url,
    image: `${url}.png`,
    viewer: `${origin}/app?view=${id}`,
    embed: `<iframe src="${url}/embed" width="560" height="420" style="border:0;max-width:100%" `
      + `title="A Brickworks model" loading="lazy"></iframe>`,
  };
}

function describe(row) {
  const parts = count(row.parts, "part");
  return row.author ? `${parts}, by ${row.author}` : parts;
}

const PAGE_STYLE = `
  :root { color-scheme: light dark; --ink: #1d232b; --soft: #5b6573; --card: #fff; --page: #eef0f3; --accent: #c8102e; }
  @media (prefers-color-scheme: dark) { :root { --ink: #e8ebef; --soft: #a3adba; --card: #1f252d; --page: #13171c; } }
  * { box-sizing: border-box; }
  body { margin: 0; font: 16px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; color: var(--ink); background: var(--page); }
  main { max-width: 760px; margin: 0 auto; padding: 24px 16px 40px; }
  .card { background: var(--card); border-radius: 14px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.12); }
  .card img { display: block; width: 100%; height: auto; aspect-ratio: 1200 / 630; object-fit: cover; background: #d9dce1; }
  .body { padding: 16px 20px 20px; }
  h1 { font-size: 1.5rem; margin: 0 0 4px; overflow-wrap: anywhere; }
  p { margin: 0 0 14px; color: var(--soft); }
  .actions { display: flex; flex-wrap: wrap; gap: 10px; }
  a.button { display: inline-block; padding: 10px 16px; border-radius: 9px; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; }
  footer { margin-top: 18px; font-size: .9rem; color: var(--soft); }
  footer small { display: block; margin-top: 6px; font-size: .8rem; }`;

/// What a link preview reads: the title, a sentence, the picture.
function pageHead(origin, row, id, title, { about = "", canonical = "" } = {}) {
  const link = links(origin, id);
  const description = about || (row
    ? `${describe(row)}. Turn it in 3D, step through the build, and get its booklet and parts list.`
    : "A model built in Brickworks, the CAD app for LEGO® bricks in your browser.");
  const image = row && row.has_image ? link.image : `${origin}/share.png`;
  return `<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
${canonical ? `<link rel="canonical" href="${escapeHtml(canonical)}">\n` : ""}<meta property="og:type" content="website">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:url" content="${escapeHtml(link.url)}">
<meta property="og:image" content="${escapeHtml(image)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(description)}">
<meta name="twitter:image" content="${escapeHtml(image)}">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">`;
}

const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const when = (iso) => {
  const at = Date.parse(iso || "");
  return Number.isFinite(at) ? `<time datetime="${escapeHtml(new Date(at).toISOString())}">${DAY.format(at)}</time>` : "";
};

/// Who to credit, as a page says it: the name the owner gave, or the link
/// itself when they gave none.
const creditOf = (model) => (model.author ? escapeHtml(model.author) : "this page’s link");

/// The licence, said for a person: what they may do, whom to credit, and
/// the licence itself.
function licenceWords(model) {
  const licence = LICENCES[model.licence];
  if (!licence) {
    return `<p><b>No licence chosen.</b> It was shared before Brickworks asked for one: ask whoever `
      + `shared it before you use it anywhere else.</p>`;
  }
  const deed = licence.url ? ` <a href="${licence.url}" rel="license">The licence</a>.` : "";
  if (model.licence === "all-rights-reserved") {
    return `<p><b>${licence.name}.</b> Look at it and build it for yourself; ask `
      + `${model.author ? escapeHtml(model.author) : "whoever shared it"} before you share a copy `
      + `or a version of it.</p>`;
  }
  if (model.licence === "cc-by-sa-4.0") {
    return `<p><b>${licence.name}.</b> Anyone may share it, change it and build on it, as long as `
      + `they credit ${creditOf(model)}, link to this page, and share what they make under the `
      + `same licence.${deed}</p>`;
  }
  return `<p><b>${licence.name}.</b> Anyone may share it, change it and build on it, for any `
    + `purpose, as long as they credit ${creditOf(model)} and link to this page.${deed}</p>`;
}

/// What a search engine reads of the model: schema.org's CreativeWork,
/// with its maker as credited, its licence, and what it was remixed from.
/// A data block, never run, so the page's policy has nothing to allow; its
/// "<" written as \u003c, so nothing typed can end the block.
function structured(origin, id, model) {
  const url = links(origin, id).url;
  const parent = (model.from || [])[0];
  const data = {
    "@context": "https://schema.org", "@type": "CreativeWork", name: model.name, url,
    description: model.description || describe(model), image: model.has_image ? `${url}.png` : undefined,
    author: model.author ? { "@type": "Person", name: model.author } : undefined,
    license: LICENCES[model.licence]?.url || undefined, dateCreated: model.listed_at || undefined,
    keywords: (model.tags || []).join(", ") || undefined,
    isBasedOn: parent && parent.id ? `${origin}/m/${parent.id}` : undefined,
    interactionStatistic: [
      { "@type": "InteractionCounter", interactionType: "https://schema.org/ViewAction", userInteractionCount: Number(model.views) || 0 },
      { "@type": "InteractionCounter", interactionType: "https://schema.org/LikeAction", userInteractionCount: Number(model.likes) || 0 },
    ],
  };
  return `<script type="application/ld+json">${JSON.stringify(data).replace(/</g, "\\u003c")}</script>`;
}

/// /sitemap.xml: the site's own pages (web/sitemap.xml, beside this file
/// as _sitemap.xml in a deployment) and every page of the directory a
/// search engine may find — each listed model, each profile with a model in
/// the gallery, each public collection (sitemap_pages, which leaves out
/// whatever was barred). Kept by the CDN for an hour.
async function sitemap(response, origin) {
  let site = "";
  for (const where of ["./_sitemap.xml", "../web/sitemap.xml"]) {
    const url = new URL(where, import.meta.url);
    if (existsSync(url)) {
      site = readFileSync(url, "utf8");
      break;
    }
  }
  const pages = await db("rpc/sitemap_pages", { method: "POST", body: {} }) || {};
  const day = (iso) => String(iso || "").slice(0, 10);
  const entry = (loc, when, often, rank) => `  <url><loc>${escapeHtml(loc)}</loc>`
    + `${when ? `<lastmod>${day(when)}</lastmod>` : ""}<changefreq>${often}</changefreq><priority>${rank}</priority></url>`;
  const ours = [...site.matchAll(/<url>[\s\S]*?<\/url>/g)].map((m) => `  ${m[0]}`);
  const rows = [
    ...ours,
    ...(pages.models || []).map((m) => entry(`${origin}/m/${m.id}`, m.updated_at, "weekly", "0.6")),
    ...(pages.people || []).map((p) => entry(`${origin}/u/${p.handle}`, p.updated_at, "weekly", "0.4")),
    ...(pages.collections || []).map((c) => entry(`${origin}/c/${c.id}`, c.updated_at, "weekly", "0.3")),
  ];
  response.setHeader("Content-Type", "application/xml; charset=utf-8");
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=3600, stale-while-revalidate=600");
  return response.status(200).end(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${rows.join("\n")}
</urlset>
`);
}

/// A small card of a model, for the remix tree.
function smallCard(card) {
  const picture = card.has_thumb ? `/m/${card.id}.webp` : card.has_image ? `/m/${card.id}.png` : "";
  return `<a class="mini" href="/m/${card.id}">`
    + (picture ? `<img src="${picture}" alt="" width="1200" height="630" loading="lazy" decoding="async">`
      : `<span class="none">No picture</span>`)
    + `<b>${escapeHtml(card.name)}</b><span>${escapeHtml(describe(card))}</span></a>`;
}

/// /m/X: the model's own page. What its owner said about it, what it is,
/// its counts, its licence and its remix tree, with the way into the 3D
/// viewer and into the app. Every word an owner typed is escaped.
/// web/share-page.js counts the view, and if a reload finds the viewer was
/// here (it keeps the link in the address bar), goes back to it.
function sharePage(origin, id, model) {
  const title = `${model.name} — a Brickworks model`;
  const { header, footer } = siteChrome();
  const kind = kindLabel(model.kind);
  const about = model.description
    ? model.description.replace(/\s+/g, " ").slice(0, 157) + (model.description.length > 157 ? "…" : "")
    : "";
  // The one it came from, while it is listed; one shared only by link is
  // not named.
  const parent = (model.from || [])[0];
  const fromLine = !parent ? "" : parent.id
    ? `<p class="from">Remixed from <a href="/m/${parent.id}">${escapeHtml(parent.name)}</a>`
      + `${parent.author ? `, by ${escapeHtml(parent.author)}` : ""}</p>`
    : `<p class="from">Remixed from a model shared by link</p>`;
  // A model shared before the directory was not counted: its steps are
  // not known, and are not said.
  const facts = [
    model.steps ? `${count(model.steps, "step")}${model.own_steps ? ", laid out by its builder" : ""}` : "",
    model.technic ? "Technic or a mechanism" : "",
    model.listed ? `In the gallery since ${when(model.listed_at)}` : "Shared by link",
  ].filter(Boolean);
  const tags = (model.tags || []).map((tag) =>
    `<li><a href="/gallery?tag=${encodeURIComponent(tag)}">${escapeHtml(tag)}</a></li>`).join("");
  const line = (model.from || []).map((one) => one.id
    ? `<li><a href="/m/${one.id}">${escapeHtml(one.name)}</a>${one.author ? `, by ${escapeHtml(one.author)}` : ""}</li>`
    : "<li>a model shared by link</li>").join("");
  const listedRemixes = model.remixes_listed || [];
  const unlisted = Math.max(0, (Number(model.remixes) || 0) - listedRemixes.length);
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, model, id, title, { about, canonical: links(origin, id).url })}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/share-page.js" defer></script>
<script src="/model-page.js" type="module"></script>
<script src="/report.js" type="module"></script>
${structured(origin, id, model)}
</head>
<body data-viewer="${escapeHtml(`/app?view=${id}`)}" data-id="${id}">
<a class="skip" href="#main">Skip to content</a>
${header}
<main id="main">
<article class="wrap model-page">
  <nav class="crumbs" aria-label="Where it is"><a href="/gallery">Gallery</a>${model.kind
    ? ` <span aria-hidden="true">›</span> <a href="/gallery?kind=${model.kind}">${escapeHtml(kind)}</a>` : ""}</nav>
  <div class="top">
    <a class="picture" href="/app?view=${id}" aria-label="View ${escapeHtml(model.name)} in 3D">${model.has_image
      ? `<img src="/m/${id}.png" alt="${escapeHtml(model.name)}" width="1200" height="630">`
      : `<span class="none">No picture</span>`}<span class="go" aria-hidden="true">View in 3D</span></a>
    <div class="side">
      <h1>${escapeHtml(model.name)}</h1>
      <p class="by">${escapeHtml(describe(model))}</p>
      ${model.by ? `<p class="shared-by">Shared by <a href="/u/${escapeHtml(model.by.handle)}">${escapeHtml(model.by.name)}</a></p>` : ""}
      ${fromLine}
      <ul class="facts">${facts.map((fact) => `<li>${fact}</li>`).join("")}</ul>
      <p class="counts"><span data-count="views">${count(model.views, "view")}</span>
        <span data-count="likes">${count(model.likes, "like")}</span>
        <span data-count="remixes">${count(model.remixes, "remix", "remixes")}</span></p>
      <div class="actions">
        <a class="cta" href="/app?view=${id}">View in 3D</a>
        <a class="cta ghost" href="/app?copy=${id}">Open in Brickworks</a>
      </div>
      <div class="marks" id="marks" data-id="${id}" hidden>
        <button type="button" class="mark" data-mark="like" aria-pressed="false">Like</button>
        <button type="button" class="mark" data-mark="favourite" aria-pressed="false">Favourite</button>
        <details class="collect"><summary>Add to a collection</summary>
          <div class="collect-panel"><div class="collect-list"></div>
            <form class="collect-new"><label class="visually-hidden" for="new-list">A new collection's name</label>
              <input id="new-list" maxlength="80" placeholder="A new collection">
              <button class="cta ghost small" type="submit">Make it</button></form></div></details>
        <p class="said" role="status"></p>
      </div>
      <p class="note">View in 3D turns it, steps through its build and gives its booklet and parts
        list, with no account. Open in Brickworks copies it into your own models, to change and make yours.</p>
      <p class="note report-line"><button type="button" class="link" data-report="this model"
        data-report-model="${id}" hidden>Report it</button> <a href="/takedown">Takedown requests</a></p>
    </div>
  </div>
  ${model.description ? `<section class="words" aria-labelledby="about-h"><h2 id="about-h">About it</h2>
    <p class="description">${escapeHtml(model.description)}</p></section>` : ""}
  ${tags ? `<ul class="tags" aria-label="Tags">${tags}</ul>` : ""}
  <section class="licence" aria-labelledby="licence-h"><h2 id="licence-h">Licence</h2>
    ${licenceWords(model)}</section>
  <section class="tree" aria-labelledby="tree-h"><h2 id="tree-h">Remixes</h2>
    ${line ? `<h3>It came from</h3><ol class="line">${line}</ol>` : ""}
    ${listedRemixes.length || unlisted
      ? `<h3>Made from it</h3>${listedRemixes.length
        ? `<div class="minis">${listedRemixes.map(smallCard).join("")}</div>` : ""}`
        + (unlisted ? `<p class="note">${listedRemixes.length ? "And " : ""}${count(unlisted, "remix", "remixes")} `
          + `shared by link, not in the gallery.</p>` : "")
      : `<p class="note">Nobody has remixed it yet. Open in Brickworks makes a copy of your own to change;
        share that, and it shows here.</p>`}
  </section>
</article>
</main>
${footer}
</body>
</html>`;
}

/// /m/X/embed: a card sized for an iframe. The app itself cannot run in
/// somebody else's page — its threaded engine needs the page to be
/// cross-origin isolated, which only the top window can ask for — so the
/// card opens the viewer in a tab of its own.
function embedCard(origin, id, row) {
  const link = links(origin, id);
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, row, id, `${row.name} — a Brickworks model`)}
<style>${PAGE_STYLE}
  body { background: var(--card); }
  a.whole { display: flex; flex-direction: column; height: 100vh; color: inherit; text-decoration: none; }
  a.whole img { flex: 1; min-height: 0; width: 100%; object-fit: cover; background: #d9dce1; }
  .bar { display: flex; align-items: center; gap: 12px; padding: 10px 14px; }
  .bar div { flex: 1; min-width: 0; }
  .bar b { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .bar span { color: var(--soft); font-size: .9rem; }
  .bar em { font-style: normal; font-weight: 600; color: #fff; background: var(--accent); padding: 7px 12px; border-radius: 8px; white-space: nowrap; }
</style>
</head>
<body>
<a class="whole" href="${escapeHtml(link.url)}" target="_blank" rel="noopener">
  ${row.has_image ? `<img src="/m/${id}.png" alt="${escapeHtml(row.name)}">` : `<img src="/share.png" alt="">`}
  <span class="bar"><div><b>${escapeHtml(row.name)}</b><span>${escapeHtml(describe(row))} · Brickworks</span></div><em>View in 3D</em></span>
</a>
</body>
</html>`;
}

function gonePage(origin, id, existed) {
  const title = existed ? "This model is no longer shared" : "There is no model at this link";
  const said = existed
    ? "Whoever shared it has taken it down. If they share it again, this link will work again."
    : "The link may be mistyped, or cut short.";
  const { header, footer } = siteChrome();
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, null, id, title)}
<meta name="robots" content="noindex">
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
${header}
<main id="main">
  <div class="wrap gone">
    <h1>${escapeHtml(title)}</h1>
    <p class="lede">${escapeHtml(said)}</p>
    <div class="actions"><a class="cta" href="/gallery">See the gallery</a>
      <a class="cta ghost" href="/">Go to Brickworks</a></div>
  </div>
</main>
${footer || `<footer><small>${NOTICE}</small></footer>`}
</body>
</html>`;
}

// What the pages may load and where they may send anything: themselves,
// and the sign-in service. The site's stylesheet and the page's own; the
// page's scripts (web/share-page.js counts a view on this same origin,
// web/model-page.js likes and keeps it for somebody signed in).
/// Its policy, with the sign-in service (SUPABASE_URL) beside itself for
/// a person who likes it, keeps it or puts it in a list (web/account.js).
function pageCsp() {
  let signIn = "";
  try {
    signIn = new URL(process.env.SUPABASE_URL || "").origin;
  } catch {
    signIn = "";
  }
  return "default-src 'none'; script-src 'self'; img-src 'self'; style-src 'self' 'unsafe-inline'; "
    + `connect-src 'self'${signIn ? ` ${signIn}` : ""}; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`;
}
const EMBED_CSP = "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; "
  + "base-uri 'none'; form-action 'none'; frame-ancestors *";

/// What the CDN may keep, and for how long: what every visitor is shown
/// (the list, a page, a picture) for half a minute, and given while it
/// asks again for half a minute more, so a page shared widely is one
/// function call a minute rather than one a visit. A browser asks the CDN
/// each time. The cost is that a model taken down, unlisted or taken out
/// leaves within a minute rather than at once (2026-10-13; it was no-cache
/// before the directory, when the probe found a picture outliving its
/// model by a minute at max-age=60).
export const SHARED_CACHE = "public, max-age=0, s-maxage=30, stale-while-revalidate=30";

function html(response, status, body, { embed = false } = {}) {
  response.setHeader("Content-Type", "text/html; charset=utf-8");
  response.setHeader("Content-Security-Policy", embed ? EMBED_CSP : pageCsp());
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  response.setHeader("Cache-Control", SHARED_CACHE);
  return response.status(status).end(body);
}

/// A link that does not answer with a model: taken down (410) or never
/// there (404).
async function missing(id) {
  const existed = await wasShared(id);
  return existed
    ? { status: 410, error: "This model is no longer shared: whoever shared it has taken it down.", unpublished: true }
    : { status: 404, error: "There is no model at this link.", unpublished: false };
}

/// A model's page, read as the server: directory_model says for itself
/// that it is published, and names only what a visitor may know.
async function modelPage(id) {
  if (!ID.test(id || "")) return null;
  const page = await db("rpc/directory_model", { method: "POST", body: { model_id: id } });
  return page && typeof page === "object" ? page : null;
}

// ---------------------------------------------------------------------------

async function read(request, response) {
  const op = String(request.query?.op || "");
  const id = String(request.query?.id || "");
  const origin = originOf(request);

  if (op === "mine") return mine(request, response, origin);
  if (op === "sweep") return sweep(request, response);
  if (op === "list") return gallery(request, response, origin);
  if (op === "sitemap") return sitemap(response, origin);

  if (op === "page") {
    const page = await modelPage(id);
    if (!page) {
      const gone = await missing(id);
      return html(response, gone.status, gonePage(origin, id, gone.unpublished));
    }
    return html(response, 200, sharePage(origin, id, page));
  }

  const row = await publishedRow(id);

  if (op === "embed") {
    if (!row) {
      const gone = await missing(id);
      return html(response, gone.status, gonePage(origin, id, gone.unpublished), { embed: true });
    }
    return html(response, 200, embedCard(origin, id, row), { embed: true });
  }

  if (op === "image" || op === "thumb") {
    const name = op === "image" ? `${id}.png` : `${id}.webp`;
    const has = row && (op === "image" ? row.has_image : row.has_thumb);
    const picture = has ? await getFile(name) : null;
    if (!picture) return response.status(404).setHeader("Cache-Control", "no-store").end("");
    response.setHeader("Content-Type", op === "image" ? "image/png" : "image/webp");
    // A link preview on any site may show it.
    response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
    // Kept as briefly as the pages (SHARED_CACHE). The small picture's
    // address says which version it is (?v=), so a browser keeps it a few
    // minutes too; a republish is a new address.
    response.setHeader("Cache-Control", op === "thumb" && request.query?.v
      ? "public, max-age=300, s-maxage=600" : SHARED_CACHE);
    return response.status(200).end(picture);
  }

  if (op !== "") return response.status(400).json({ error: `unknown op ${op}` });

  // The viewer's one request: what the model is, and the model.
  response.setHeader("Cache-Control", "no-store");
  if (!row) {
    const gone = await missing(id);
    return response.status(gone.status).json({ error: gone.error, unpublished: gone.unpublished });
  }
  // What it was remixed from, while that is listed: read as a visitor
  // reads it, so a link taken down, or only ever sent to some people, is
  // not named.
  const parent = row.remixed_from ? await publishedRow(row.remixed_from) : null;
  const from = parent && parent.listed ? parent : null;
  const model = await getFile(`${id}.mpd`);
  if (!model) return response.status(410).json({ error: "This model is no longer shared.", unpublished: true });
  return response.status(200).json({
    id,
    name: row.name,
    author: row.author,
    parts: row.parts,
    updated_at: row.updated_at,
    listed: row.listed === true,
    licence: row.licence ?? null,
    remixed_from: from ? { id: from.id, name: from.name, url: `${origin}/m/${from.id}` } : null,
    ...links(origin, id),
    model: model.toString("utf8"),
  });
}

/// /gallery's models, a page at a time: the listed ones a query asks for
/// (api/_directory.js listQuery), through directory_models, which says
/// for itself what a visitor may see. With the kinds, sizes and sorts it
/// knows, so a client can ask in its words.
async function gallery(request, response, origin) {
  const { asked, said } = listQuery(request.query || {}, PER_PAGE, MOST_PAGES);
  const rows = await db("rpc/directory_models", { method: "POST", body: { query: asked } });
  // Kept briefly by the CDN, like the pages: the same question asked by
  // a hundred phones is one call to the database.
  response.setHeader("Cache-Control", SHARED_CACHE);
  return response.status(200).json({
    ...said,
    per_page: PER_PAGE,
    more: rows.length > PER_PAGE,
    models: rows.slice(0, PER_PAGE).map((row) => cardOf(origin, row)),
    kinds: KINDS,
    sizes: Object.entries(SIZES).map(([id, size]) => ({ id, label: size.label })),
    sorts: Object.entries(SORTS).map(([id, label]) => ({ id, label })),
  });
}

/// A view of a model's page, sent by the page (web/share-page.js) once a
/// day: counted once per visitor per day, and only for what looks like a
/// person in a browser on this site. The answer says whether it was, and
/// never who.
async function seen(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  if (!looksLikePerson(request)) return response.status(200).json({ counted: false });
  const counted = await db("rpc/count_view", { method: "POST",
    body: { model_id: id, visitor_key: visitorKey(request, id) } });
  return response.status(200).json({ counted: counted === true });
}

async function signedIn(request) {
  const claims = await verify(bearer(request));
  return claims.sub;
}

async function mine(request, response, origin) {
  response.setHeader("Cache-Control", "private, no-store");
  const owner = await signedIn(request);
  const rows = await db(`shared_models?owner=eq.${owner}&select=${PUBLIC},barred&order=updated_at.desc`);
  return response.status(200).json({
    shared: rows.map((row) => ({ ...row, ...links(origin, row.id) })),
  });
}

/// What the owner says about the model, checked at this edge: undefined
/// for anything not said, which a republish keeps as it was.
function saidAbout(body) {
  try {
    return {
      description: cleanDescription(body.description),
      tags: cleanTags(body.tags),
      kind: cleanKind(body.kind),
      licence: cleanLicence(body.licence),
    };
  } catch (trouble) {
    if (trouble instanceof Unacceptable) throw new Refusal(trouble.message, trouble.status);
    throw trouble;
  }
}

async function publish(request, response) {
  const owner = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};

  // Everything about the upload is checked before anything is counted
  // or stored, so a refused upload costs nobody a publish.
  const { parts, bytes, steps, ownSteps, technic } = checkModel(body.model);
  const picture = checkImage(body.image);
  const thumb = checkThumb(body.thumb);
  const name = cleanText(body.name, MAX_NAME);
  if (!name) throw new Refusal("give the model a name to share it under");
  const author = cleanText(body.author, MAX_AUTHOR) || null;
  if (body.listed !== undefined && typeof body.listed !== "boolean") {
    throw new Refusal("listed is true or false");
  }
  const listed = body.listed === true;
  const about = saidAbout(body);
  // What a stranger may not be shown, in a name or anywhere it is said
  // (api/_names.js): before anything is counted or stored.
  const said = namesTrouble({ "The name": [name, "name"], "The credit": [author, "name"],
    "A tag": [about.tags, "name"], "The description": [about.description, "words"] });
  if (said) throw new Refusal(said);

  let id = body.id === undefined || body.id === null || body.id === "" ? "" : String(body.id);
  let existing = null;
  if (id) {
    existing = await ownRow(id);
    if (!existing) throw new Refusal("there is no shared model at that link to update", 404);
    if (existing.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  }
  // 409, not 403: the app answers a 403 (somebody else's link) by
  // publishing at a new link, which here would list it again.
  if (listed && existing && existing.barred) {
    throw new Refusal("Brickworks took this model out of the gallery. It is still shared at its link: "
      + "publish it without listing it.", 409);
  }
  // Said once and kept: a republish from a copy that no longer carries it
  // does not forget where the model came from.
  const parent = await remixOf(body.remixed_from, id);
  const remixedFrom = parent?.id ?? existing?.remixed_from ?? null;
  const description = about.description !== undefined ? about.description : existing?.description ?? null;
  const tags = about.tags !== undefined ? about.tags : existing?.tags ?? [];
  const kind = about.kind !== undefined ? about.kind : existing?.kind ?? null;
  const licence = about.licence !== undefined ? about.licence : existing?.licence ?? null;
  // What the model it came from allows. 422, never 403 (above).
  const from = parent ?? (remixedFrom ? await remixOf(remixedFrom, id) : null);
  if (from && from.owner !== owner && from.licence === "cc-by-sa-4.0" && licence !== "cc-by-sa-4.0") {
    throw new Refusal("the model this was copied from is shared under CC BY-SA 4.0, so a version of it "
      + "has to be too: choose CC BY-SA 4.0 as its licence", 422);
  }
  if (from && from.owner !== owner && from.licence === "all-rights-reserved" && listed) {
    throw new Refusal("the model this was copied from is all rights reserved, so its builder has not "
      + "let versions of it into the gallery: share it by link without listing it, or ask them", 422);
  }
  // Taken out of the gallery for good, by the site's owner: the account,
  // or this very file at any link (api/admin.js). 409, never 403 (above).
  if (listed && (await barred(owner))) {
    throw new Refusal("Brickworks took your models out of the gallery, so this one cannot be listed. "
      + "It can still be shared by link: publish it without listing it.", 409);
  }
  if (listed && (await barredFile(body.model))) {
    throw new Refusal("Brickworks took this model out of the gallery, so it cannot be listed again, "
      + "at this link or another. It can still be shared by link: publish it without listing it.", 409);
  }
  // Into the gallery, as against staying in it: only that is counted.
  const newlyListed = listed && !(existing && existing.published && existing.listed);

  if (newlyListed && !(await mayList(owner))) {
    throw new Refusal("you have listed a lot in the gallery in a short time: try again in an hour, "
      + "or publish it without listing it", 429);
  }
  if (!(await mayPublish(owner))) {
    throw new Refusal("you have published a lot in a short time: try again in an hour", 429);
  }

  if (!id) id = newId();
  // A new link whose row is never written leaves no files behind: they go
  // as the publish fails, rather than wait a day for the sweep.
  const dropNew = (trouble) => {
    if (!existing) return deleteFiles([`${id}.mpd`, `${id}.png`, `${id}.webp`]).catch(() => {}).then(() => { throw trouble; });
    throw trouble;
  };
  await putFile(`${id}.mpd`, body.model, "text/plain").catch(dropNew);
  if (picture) await putFile(`${id}.png`, picture, "image/png").catch(dropNew);
  else if (existing) await deleteFiles([`${id}.png`]).catch(() => {});
  if (thumb) await putFile(`${id}.webp`, thumb, "image/webp").catch(dropNew);
  else if (existing) await deleteFiles([`${id}.webp`]).catch(() => {});

  const now = new Date().toISOString();
  const row = { name, author, parts, bytes, has_image: Boolean(picture), has_thumb: Boolean(thumb),
    published: true, updated_at: now, listed, listed_at: listed ? (newlyListed ? now : existing.listed_at) : null,
    remixed_from: remixedFrom, description, tags, kind, licence, steps, own_steps: ownSteps, technic };
  if (existing) {
    await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: row });
  } else {
    await db("shared_models", { method: "POST", body: { id, owner, ...row } }).catch(dropNew);
  }

  const origin = originOf(request);
  return response.status(existing ? 200 : 201).json({
    id, name, author, parts, bytes, published: true, updated: Boolean(existing),
    listed, remixed_from: remixedFrom, gallery: `${origin}/gallery`,
    description, tags, kind, licence, steps, own_steps: ownSteps, technic,
    ...links(origin, id),
  });
}

async function unpublish(request, response) {
  const owner = await signedIn(request);
  const id = String(request.query?.id || request.body?.id || "");
  const row = await ownRow(id);
  if (!row) throw new Refusal("there is no shared model at that link", 404);
  if (row.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  // Out of the gallery with it: published again, it is listed again only
  // if the box is ticked again.
  await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, {
    method: "PATCH", body: { published: false, listed: false, listed_at: null,
      updated_at: new Date().toISOString() } });
  // The row stays, so the link can say it was taken down, and a
  // republish from the same model keeps the same link. The files go.
  await deleteFiles([`${id}.mpd`, `${id}.png`, `${id}.webp`]);
  return response.status(200).json({ id, published: false });
}

// ---------------------------------------------------------------------------
// The sweep.
//
// A row goes with its account (on delete cascade), but the bucket's files
// are not rows, and Supabase refuses to delete storage objects from SQL,
// so an account deleted in the dashboard left its models' files behind
// for good. Once a day this takes away every file that no published row
// owns. A publish writes its files a moment before its row, so a file
// younger than an hour is left for the next day's sweep.

const SWEEP_AGE_MS = 60 * 60 * 1000;

/// Vercel's cron sends "Bearer <CRON_SECRET>"; nobody else has it.
function isCron(request) {
  const secret = process.env.CRON_SECRET || "";
  if (!secret) return false;
  const given = Buffer.from(String(request.headers?.authorization || ""));
  const want = Buffer.from(`Bearer ${secret}`);
  return given.length === want.length && timingSafeEqual(given, want);
}

async function sweep(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the sweep is the cron's" });
  // ?only=A,B looks at those links alone, whatever their files' age: how
  // share_probe proves an orphan goes without waiting an hour.
  const only = String(request.query?.only || "").split(",").filter((id) => ID.test(id));
  const now = Date.now();
  const files = (await listFiles()).filter((file) => {
    const id = file.name.split(".")[0];
    if (only.length > 0) return only.includes(id);
    return now - Date.parse(file.updated_at || file.created_at || 0) > SWEEP_AGE_MS;
  });
  const ids = [...new Set(files.map((file) => file.name.split(".")[0]).filter((id) => ID.test(id)))];
  const kept = new Set();
  for (let at = 0; at < ids.length; at += 100) {
    const rows = await db(`shared_models?id=in.(${ids.slice(at, at + 100).join(",")})&published=is.true&select=id`);
    for (const row of rows) kept.add(row.id);
  }
  const gone = files.map((file) => file.name).filter((name) => !kept.has(name.split(".")[0]));
  for (let at = 0; at < gone.length; at += 100) await deleteFiles(gone.slice(at, at + 100));
  // Who looked at what, kept only as long as it takes to count a visitor
  // once a day: today's and yesterday's.
  const yesterday = new Date(now - 24 * 3600 * 1000).toISOString().slice(0, 10);
  if (only.length === 0) await db(`model_views?day=lt.${yesterday}`, { method: "DELETE" });
  // How often each account or visitor did things (may_act), kept a day.
  if (only.length === 0) await db(`act_log?at=lt.${new Date(now - 24 * 3600 * 1000).toISOString()}`, { method: "DELETE" });
  return response.status(200).json({ looked_at: files.length, kept: files.length - gone.length, removed: gone });
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
  // The desktop app publishes from no page at all; a browser on another
  // site gains nothing from a session it does not have.
  response.setHeader("Access-Control-Allow-Origin", "*");

  if (!dbConfigured() || !process.env.SUPABASE_PUBLISHABLE_KEY) {
    return response.status(503).json({ error: "sharing is not set up on this deployment" });
  }

  try {
    // HEAD as GET, its body left off by the server: what a link checker,
    // a crawler and a preview ask a page and a picture first.
    if (request.method === "GET" || request.method === "HEAD") return await read(request, response);
    if (request.method !== "POST") return response.status(405).json({ error: "GET or POST" });
    response.setHeader("Cache-Control", "no-store");
    const op = String(request.query?.op || "");
    if (op === "unpublish") return await unpublish(request, response);
    if (op === "seen") return await seen(request, response);
    if (op === "") return await publish(request, response);
    return response.status(400).json({ error: `unknown op ${op}` });
  } catch (trouble) {
    if (trouble instanceof AuthError) return response.status(trouble.status).json({ error: trouble.message });
    if (trouble instanceof Refusal || trouble instanceof Unacceptable) {
      return response.status(trouble.status).json({ error: trouble.message });
    }
    console.error("share:", trouble.message);
    return response.status(502).json({ error: "Brickworks could not reach its storage just now. Try again in a minute." });
  }
}
