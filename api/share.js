// Sharing a model by link (2026-10-12).
//
// Someone signed in publishes the model they have open, from File ›
// Share… in the app, and gets https://brickworks.diy/m/<id>. Anyone may
// open that link without an account: the app in a read-only mode
// (/app?view=<id>) with the model, its steps, its booklet and its parts
// list, and Open in Brickworks to copy it into their own account.
//
//   GET  ?id=X               the model, as the viewer loads it: name,
//                            author, part count and the .mpd itself, which
//                            version it is and what each version changed;
//                            with v=N, version N's .mpd
//   GET  ?op=page&id=X       /m/X: the link's own page — a title and a
//                            picture for anything that previews links,
//                            and then the viewer; with v=N, /m/X/v/N, an
//                            older version's, marked as older
//   GET  ?op=image&id=X      /m/X.png: that picture, rendered by the app
//                            when it published; with v=N, /m/X/v/N.png
//   GET  ?op=embed&id=X      /m/X/embed: a card for a blog or a forum to
//                            put in an iframe
//   GET  ?op=thumb&id=X      /m/X.webp: the small picture the gallery's
//                            cards show, made by the app beside the big one
//   GET  ?op=list&page=N     /gallery's models: the listed ones, a page at
//                            a time, searched (q), filtered (kind, size,
//                            instructions, technic, tested, tag, made:
//                            hand or assistant) and sorted (sort: newest,
//                            views, likes, remixes, builds, top; window:
//                            week or month, Top's); with tests=1, test
//                            models too, which nobody else is shown
//   GET  ?op=shelves         /gallery's front: this week's pick and the small
//                            builds' shelf (supabase/discovery.sql); tests=1
//                            as the list
//   GET  ?op=list&mine=1     the list, with the session: each card's share of
//   GET  ?op=shelves&mine=1  its parts the person owns (owned) and whether
//                            they like it (liked), the sort owned (Parts I
//                            own), ready=1 (only what they can build now)
//                            and following=1 (the models of the people they
//                            follow) on the list, and the shelf of what
//                            they can build now on the front; never kept
//                            by the CDN
//   GET  ?op=tested&id=X     the owner's own: what the app found of the
//                            newest version, every test and why, passed
//                            or not (with v=N, version N's)
//   POST                     publish, with the session: {name, author?,
//                            model, image?, thumb?, id?, listed?,
//                            remixed_from?, remixed_from_version?,
//                            description?, tags?, kind?, licence?, note?,
//                            tested?}. tested is what the app found of the
//                            model as it published it (api/_tested.js).
//                            With an id, the owner's own link gets its
//                            next version, and the one before is kept.
//                            listed puts it in the gallery; remixed_from
//                            is the link it was copied from (Open in
//                            Brickworks), and remixed_from_version which
//                            version of it, which its page names; note is
//                            what its owner says changed. What it says
//                            about itself is kept on a republish that does
//                            not say it again.
//   POST ?op=seen&id=X       its page was looked at: counted once a day per
//                            visitor, and never for a robot
//   POST ?op=built&id=X      {device, v?}: built to its last step, in the
//                            step player or the viewer: counted once per
//                            device, never for a robot (api/_builds.js)
//   POST ?op=unpublish&id=X  the owner takes it down, every version of it
//   GET  ?op=mine            the session's own links
//   GET  ?op=sweep           the daily clean-up (Vercel's cron, with
//                            CRON_SECRET): files no published row owns
//
// Where it is kept and who may touch it is in supabase/shared_models.sql.
// In short: a visitor's read asks for a published row and its public
// columns alone (the key a page holds reaches nothing in the database
// since supabase/no_client_access.sql), and the files are read only after
// that. Every write is here, after the session has been verified and the
// row found to be the caller's.
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
// A test account's models (one signed in at a Resend test address, as
// every probe is: api/_auth.js isTestAccount) are marked a test when they
// are published, and no public list shows them (supabase/test_models.sql):
// the probes ran against the live site and their models were in its
// gallery, newest first, while they ran (2026-10-17). A probe asks with
// tests=1 to see them; such an answer is never kept by the CDN.
//
// Versions (2026-10-18, supabase/versions.sql, api/_versions.js): a
// republish is the link's next version, and the one before it is kept,
// its files renamed for its number (<id>.v<n>.mpd and .png) as the new one
// takes the link's own. What changed is worked out here from the two
// files: the parts by part and colour, the steps by number, and the first
// step that differs, which keeps a builder's place on the new one
// (src/assembly/build_steps.gd). A version is counted as a publish.
//
// The Tested mark (2026-10-18, supabase/tested.sql, api/_tested.js): the
// app tests a model as it publishes it — it stands at every step, every
// step can be reached, every part is made in its colour, nothing is loose —
// and sends what it found. It is kept with the version, as the app's own
// finding and the app version's, once it is found to be of this very file
// and the steps the file carries; this server cannot run the tests. A pass
// is shown on the page, the card and the viewer; a failure only to its
// owner; the site's owner can clear either (api/admin.js ?op=untest).
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
//
// The ground rules (2026-10-18, supabase/trust.sql, api/_trust.js): an
// account under 13 shares by link like anyone, but is refused a listing and
// a credited name, in words, here and again by the database; and listing
// anything new needs the age question answered.
//
// Real builds (2026-10-18, supabase/builds.sql, api/_builds.js): a model
// built to its last step is counted once per device (?op=built), "12 built"
// on its page and its card, and the gallery sorts by it; and its page has a
// strip of photos of people's real builds of it, with the way to add one
// (web/model-page.js), which api/people.js keeps.
//
// Discovery (2026-10-19, supabase/discovery.sql): the gallery sorts by Top
// builds, a score of builds finished, remixes and the Tested mark
// (_directory.js SCORE), and its front has this week's pick, worked out
// from the past seven days unless the site's owner chose one (api/admin.js),
// and a shelf of small builds, the Size filter's Small by Top builds
// (?op=shelves). Build with what I own (api/_owned.js): what a model needs,
// by part and colour, is counted from its file as it is published and
// kept (model_needs), so that a signed-in person's share of every model in
// the gallery is one join in the database (&mine=1).

import { randomBytes, timingSafeEqual } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { AuthError, bearer, isTestAccount, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { originOf } from "./_oauth.js";
import {
  KINDS, LICENCES, MADES, MINE_SORTS, MOVES, NOTICE, SCORE, SHELF, SIZES, SORTS, TESTS_CACHE, Unacceptable, WINDOWS, cardOf,
  cleanDescription, cleanKind, cleanLicence, cleanTags, count, escapeHtml, isTechnic, kindLabel,
  listQuery, looksLikePerson, modelHash, motionsIn, movesWords, partFacts, siteChrome, testsAsked, visitorKey,
} from "./_directory.js";
import { namesTrouble } from "./_names.js";
import { checkTested, markOf, ownerMark, publicMark } from "./_tested.js";
import { changesBetween, lotSaid, readChanges, saidOf } from "./_versions.js";
import { countSaid, sideSaid, stepCount, stepsSaid } from "./_steps.js";
import { publicTrouble, shownPublicly } from "./_trust.js";
import { freshPool, keyed } from "./_owned.js";
import { challengeLine, withWins } from "./_challenges.js";
// The one model card, the browser's too (web/card.js): a model's remixes,
// more by its designer and similar models.
import { cardHtml } from "./_card.js";
// The kit, made in the card's file: the designer's avatar and the action
// bar's buttons.
import { avatarHtml, iconButtonHtml, iconHtml } from "./_card.js";
// Whose picture to show beside their name (supabase/avatars.sql).
import { withFaces } from "./_faces.js";
import {
  BuildRefusal, UPLOADS, buildsOf, countBuild, deleteFiles as deleteBuildFiles, fromTheApp, photosWhere,
  uploadsLeft,
} from "./_builds.js";

export const MAX_MODEL_BYTES = 2 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 600 * 1024;
export const MAX_THUMB_BYTES = 64 * 1024;
const MAX_NAME = 80;
const MAX_AUTHOR = 60;
// What changed, as its owner says it: a line or two (supabase/versions.sql).
const MAX_NOTE = 280;
// How many of a link's versions an answer names, newest first: a builder
// further back than this is told the model changed from step 1.
const VERSIONS_SHOWN = 100;
const VERSION = /^[1-9][0-9]{0,5}$/;
const BUCKET = "shared-models";
// The gallery's small pictures, in a bucket of their own
// (supabase/directory.sql): shared-models takes only its two kinds of file.
const THUMBS = "shared-thumbs";
/// Which bucket a file is in: the small pictures in theirs.
const bucketOf = (name) => (name.endsWith(".webp") ? THUMBS : BUCKET);
const ID = /^[A-Za-z0-9]{10}$/;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
// What a visitor's key may read: the columns supabase/shared_models.sql
// and supabase/gallery.sql grant, which are all of them but the owner,
// barred and test.
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
/// And what the gallery filters on, read from the same lines: whether its
/// steps are its builder's (LdrModel.steps_are_authored: steps there, not
/// marked worked out, and either marked so by Brickworks or written by
/// another tool), and how many of its parts are Technic and how many make
/// it move (partFacts), counted through its submodels as its parts are.
/// And its steps, every page the step player turns to (stepCount, the
/// steps it carries), which a comment is on: null when it carries none;
/// and [count], the steps as a person is told of them (api/_steps.js).
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
  let current = { name: "", placed: [], colours: [], isPart: false, steps: 0, open: false, author: "" };
  let inData = false;
  let lineNo = 0;
  let stepped = false;
  let markedAuthored = false;
  let markedWorked = false;
  // A file is known once it has a name or places something: an .ldr
  // has no 0 FILE line, and an .mpd starts with one.
  const keep = () => {
    if (!files.has(current.name)) {
      files.set(current.name, current);
      order.push(current.name);
    }
  };
  const start = (name) => {
    current = { name: name.toLowerCase(), placed: [], colours: [], isPart: /\.dat$/i.test(name), steps: 0, open: false,
      author: "" };
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
        current = { name: "", placed: [], colours: [], isPart: true };
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
      } else if (meta === "!BRICKWORKS" && (tokens[2] || "").toUpperCase() === "WORKED_STEPS") {
        markedWorked = true;
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
      current.colours.push(tokens[1]);
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
  const ownSteps = stepped && !markedWorked && (markedAuthored || top.author !== "Brickworks");
  const oneModel = top.placed.every((ref) => !files.has(ref) || files.get(ref).isPart);
  const stepsCount = stepCount(text, { own: ownSteps, oneModel, steps: top.steps + (top.open ? 1 : 0) });
  const steps = stepsCount?.pages ?? null;
  // What it needs, by part and colour, for Build with what I own
  // (api/_owned.js): every part line the tally counts, through its
  // sub-models in the colour each is placed in (16 is that colour). A
  // flexible part laid as segments is one part nobody owns by that name,
  // and is left out, as the app leaves out what is not a part.
  const memo = new Map();
  const needsOf = (name, colour) => {
    const key = `${name}\n${colour}`;
    if (memo.has(key)) return memo.get(key);
    const file = files.get(name);
    const out = new Map();
    const add = (lot, n) => out.set(lot, (out.get(lot) || 0) + n);
    file.placed.forEach((ref, at) => {
      const own = file.colours[at];
      const placedIn = own === "16" ? colour : own;
      const sub = files.get(ref);
      if (sub && !sub.isPart) {
        if (laidFlexible(sub.placed)) return;
        for (const [lot, n] of needsOf(ref, placedIn)) add(lot, n);
      } else {
        add(`${ref.replace(/\.dat$/, "")}\n${placedIn}`, 1);
      }
    });
    memo.set(key, out);
    return out;
  };
  const needs = [...needsOf(main, "16")].map(([lot, qty]) => {
    const [part, colour] = lot.split("\n");
    return [part, Number(colour), qty];
  });
  return { parts, bytes, steps, count: stepsCount, ownSteps, technic: isTechnic(parts, technicParts, movingParts), needs };
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

/// A published row, as a visitor may see it: only while it is published,
/// and only the columns anybody may read. Asked as the server: the key a
/// page holds reaches nothing in the database (supabase/no_client_access.sql,
/// 2026-10-24), where row security used to say what was published.
async function publishedRow(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`shared_models?id=eq.${id}&published=is.true&select=${PUBLIC}`);
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
    + "description,tags,kind,licence,author,parts,steps,bytes,has_image,updated_at");
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
// Versions (supabase/versions.sql).

/// A link's versions, newest first, as [{n, at, note, parts, steps, bytes,
/// has_image, changes, first, from_version}]: read with the secret key, so
/// only for a row already read as published, or for its owner. A link with
/// none (published before its versions were kept, and not since) is its
/// version 1, as the row says it is.
async function versionsOf(id, row = null, limit = VERSIONS_SHOWN) {
  const rows = await db(`share_versions?model=eq.${id}&select=n,at,note,parts,steps,bytes,has_image,changes,`
    + `first_changed,remixed_from_version&order=n.desc&limit=${limit}`);
  const versions = rows.map((one) => ({ n: one.n, at: one.at, note: one.note ?? null, parts: one.parts,
    steps: one.steps ?? null, bytes: one.bytes, has_image: one.has_image === true,
    changes: readChanges(one.changes), first: one.first_changed ?? null,
    from_version: one.remixed_from_version ?? null }));
  if (versions.length === 0 && row) {
    versions.push({ n: 1, at: row.updated_at, note: null, parts: row.parts, steps: row.steps ?? null,
      bytes: row.bytes, has_image: row.has_image === true, changes: null, first: null, from_version: null,
      implied: true });
  }
  return versions;
}

/// Where version [n] of link [id] keeps its model or its picture: the
/// newest at the link's own name, as every link always has, and an older
/// one under its number beside it.
const versionFile = (id, n, newest, kind) => (n === newest ? `${id}.${kind}` : `${id}.v${n}.${kind}`);

/// The version a request asks for (?v=N), or null for the newest. A v that
/// is not a version number is refused at this edge.
function askedVersion(request) {
  const given = request.query?.v;
  if (given === undefined || given === null || given === "") return null;
  if (!VERSION.test(String(given))) throw new Refusal("v is a version's number, from 1");
  return Number(given);
}

/// Which version of the model it was remixed from its copy was made of:
/// said when the copy was first shared and kept by each version after.
const remixVersion = (versions) => versions.find((one) => one.from_version)?.from_version ?? null;

/// A version as an answer says it.
function versionSaid(origin, id, one, newest) {
  return { n: one.n, at: one.at, note: one.note, said: saidOf(one.n, one.changes),
    first_changed: one.first, parts: one.parts, steps: one.steps, newest: one.n === newest,
    url: one.n === newest ? `${origin}/m/${id}` : `${origin}/m/${id}/v/${one.n}` };
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

/// Whom a model credits, by name, wherever it is said: its designer's
/// profile as it is named now, as Studio and Mecabricks credit your
/// username, when they have one shown in public (a page's by, or a row's
/// looked up by profileOf); else the name given as it was published; null
/// when it credits nobody. The page's head said the profile while its
/// licence credited a name the app had made from the address its designer
/// signs in with (walk180, 2026-10-23).
export const creditName = (model) => (model.author ? (model.by && model.by.name) || model.author : null);

/// The profile a published model's credit names, for an answer made from
/// its row alone: its owner's, while shown in public (supabase/follows.sql
/// feed_who), and only when it credits anybody. null when there is none,
/// or the database does not say.
async function profileOf(id, author) {
  if (!author) return null;
  try {
    const rows = await db(`shared_models?id=eq.${id}&select=owner`);
    return rows[0] ? await db("rpc/feed_who", { method: "POST", body: { account: rows[0].owner } }) : null;
  } catch {
    return null;
  }
}

/// Whether a credit is made from the address [email] signs in with: the
/// letters and digits of the part before its @, as an app before m157
/// offered it ("Delivered+walk 180 Web"), or the address in it. An address
/// is never shown, nor any part of one.
export function madeFromAddress(credit, email) {
  const plain = (text) => String(text || "").toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
  const local = String(email || "").split("@")[0].toLowerCase();
  const said = String(credit || "").toLowerCase();
  return Boolean(local) && (plain(said) === plain(local) || said.includes(local) || said.includes("@"));
}

function describe(row) {
  const parts = count(row.parts, "part");
  const by = creditName(row);
  return by ? `${parts}, by ${by}` : parts;
}

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

/// Who to credit, as a page says it: their profile's name and handle, a
/// link to it, or the name the owner gave; the link itself when they gave
/// none.
function creditOf(model, nobody = "this page’s link") {
  if (!model.author) return nobody;
  if (!model.by) return escapeHtml(model.author);
  const handle = escapeHtml(model.by.handle);
  return `${escapeHtml(model.by.name)} (<a href="/u/${handle}">@${handle}</a>)`;
}

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
      + `${creditOf(model, "whoever shared it")} before you share a copy `
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
    author: model.author ? { "@type": "Person", name: creditName(model),
      url: model.by ? `${origin}/u/${model.by.handle}` : undefined } : undefined,
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

/// The Tested mark, for a version that passed (api/_tested.js publicMark):
/// small, the four results on hover (its title) and on a tap (it opens),
/// and whose finding it is. Nothing for any other version.
function testedMark(mark, counted = null) {
  if (!mark) return "";
  return `<details class="tested-mark" data-tested="yes"><summary class="pill good" title="${escapeHtml(mark.line)}">`
    + `<span class="tick" aria-hidden="true">✓</span> Tested</summary><div class="tested-says">`
    + `<ul>${mark.said.map((one) => `<li>${escapeHtml(one)}</li>`).join("")}</ul>`
    + `<p class="note">Worked out by the Brickworks app ${escapeHtml(mark.app)} as it was published, `
    + `building it by its own ${counted ? countSaid(counted) : count(mark.steps, "step")}.</p></div></details>`;
}

/// Who made it, at the head of its page: their avatar, name and handle, a
/// link to their profile, and Follow beside it (web/follow.js shows it once
/// it knows who is asking). A credit with no profile behind it is the name
/// alone, with an avatar made from it; a model shared with no credit, none.
function designerRow(model) {
  if (model.by) {
    const handle = escapeHtml(model.by.handle);
    return `<div class="shared-by"><a class="who" href="/u/${handle}">${avatarHtml(model.by)}`
      + `<span class="names"><b>${escapeHtml(model.by.name)}</b><small>@${handle}</small></span></a>`
      + `<button type="button" class="cta ghost small follow" data-follow="${handle}" hidden>Follow</button>`
      + `<span class="said" role="status"></span></div>`;
  }
  if (!model.author) return "";
  return `<div class="shared-by"><span class="who">${avatarHtml({ name: model.author })}`
    + `<span class="names"><b>${escapeHtml(model.author)}</b></span></span></div>`;
}

/// What a model's page leads on to (docs/SOCIAL.md D4, D12, D13): at most
/// NEXT_MOST cards a row, and a row only once it has NEXT_LEAST, since a
/// row of one or two reads as a gallery nobody uses.
export const NEXT_MOST = 6;
export const NEXT_LEAST = 3;

/// The cards a model's page ends with: more by its designer, their other
/// models in the gallery by Top builds; and similar models, of its kind or
/// sharing its tags, the most tags shared first, then its kind, then Top
/// builds; or, with neither, the gallery's Top. Never from who looked at
/// what (D13). A card the page shows
/// already (the model, its remixes, a card in More by) is not shown again.
/// Read through directory_models, as the gallery is, so a model taken out
/// is never offered; a test model's own page, which only a probe has the
/// link to, offers test models too, as it lists its test remixes
/// (supabase/test_models.sql). The database not answering is no rows: the
/// page is drawn without them, never refused.
async function nextOf(origin, id, model, own) {
  const none = { by: [], like: [], gallery: [] };
  if (!own) return none;
  const ask = (query) => db("rpc/directory_models", { method: "POST",
    body: { query: { sort: "top", tests: own.test === true, ...query } } }).catch(() => []);
  const tags = model.tags || [];
  const [theirs, kin, ...tagged] = await Promise.all([
    model.by ? ask({ owner: own.owner, size: NEXT_MOST + 1 }) : [],
    model.kind ? ask({ kind: model.kind, size: 24 }) : [],
    ...tags.slice(0, 3).map((tag) => ask({ tag, size: 12 })),
  ]);
  const by = (theirs || []).filter((row) => row && row.id !== id).slice(0, NEXT_MOST);
  const shown = new Set([id, ...(model.remixes_listed || []).map((row) => row.id),
    ...(by.length >= NEXT_LEAST ? by.map((row) => row.id) : [])]);
  const top = (row) => SCORE.builds * (Number(row.builds) || 0) + SCORE.remixes * (Number(row.remixes) || 0)
    + (row.tested === true ? SCORE.tested : 0);
  const near = (row) => 2 * (row.tags || []).filter((tag) => tags.includes(tag)).length
    + (model.kind && row.kind === model.kind ? 1 : 0);
  const found = new Map();
  for (const row of [...(kin || []), ...tagged.flat()]) {
    if (row && !shown.has(row.id) && !found.has(row.id)) found.set(row.id, row);
  }
  const like = [...found.values()].sort((a, b) => near(b) - near(a) || top(b) - top(a)
    || String(b.listed_at || "").localeCompare(String(a.listed_at || ""))).slice(0, NEXT_MOST);
  const cards = (rows) => (rows.length >= NEXT_LEAST ? rows.map((row) => cardOf(origin, row)) : []);
  const next = { by: cards(by), like: cards(like), gallery: [] };
  // Neither row: the gallery's own Top, so the page's last screen always
  // has another model to open (docs/SOCIAL.md U4), however few there are.
  if (!next.by.length && !next.like.length) {
    const top = await ask({ size: NEXT_MOST + shown.size });
    next.gallery = (top || []).filter((row) => row && !shown.has(row.id)).slice(0, NEXT_MOST)
      .map((row) => cardOf(origin, row));
  }
  return next;
}

/// A row of cards the page ends with, or nothing for none.
function nextRow(key, title, cards) {
  if (!cards.length) return "";
  return `<section class="next" id="${key}" aria-labelledby="${key}-h"><h2 id="${key}-h">${title}</h2>`
    + `<div class="models row">${cards.map((card) => cardHtml(card)).join("")}</div></section>`;
}

/// The action bar: Like, Save, Share, Comment, I built it and More, each an
/// icon button that says its name and count (web/kit.js), never a count of
/// none. web/model-page.js makes them work, asking to sign in first where
/// one must be; it counts the comments as it lists them.
function actionBar(origin, id, model) {
  const embed = links(origin, id).embed;
  return `<div class="action-bar" id="marks" data-id="${id}" role="group" aria-label="What you can do with it">`
    + iconButtonHtml({ icon: "like", name: "Like", count: model.likes, one: "like", pressed: false,
      attrs: 'data-mark="like" title="Like it"' })
    + `<button type="button" class="icon-btn" data-mark="save" aria-label="Save" aria-expanded="false" `
      + `aria-controls="save-panel" title="Save it to your favourites or a collection">${iconHtml("save")}</button>`
    + iconButtonHtml({ icon: "share", name: "Share", attrs: 'data-share title="Share it: copy its link"' })
    + iconButtonHtml({ icon: "comment", name: "Comment", attrs: 'data-mark="comment" title="Comments on it and its steps"' })
    + iconButtonHtml({ icon: "build", name: "I built it", count: model.builds, one: "build",
      attrs: 'data-mark="built" title="I built it: add a photo of your build"' })
    + `<details class="more-menu end" id="more"><summary class="icon-btn" aria-label="More" title="More">`
      + `${iconHtml("more")}</summary><div class="menu-list">`
      + `<button type="button" data-embed="${escapeHtml(embed)}">Copy the embed code</button>`
      + `<button type="button" data-report="this model" data-report-model="${id}" hidden>Report it</button>`
      + `<a href="/takedown">Takedown requests</a></div></details>`
    + `</div>`
    // Save opens your lists, Favourites first (docs/SOCIAL.md D2), and a
    // new collection's name; drawn by web/model-page.js once signed in.
    + `<div class="save-panel" id="save-panel" hidden><p class="save-head">Save it to</p>`
    + `<div class="collect-list"></div>`
    + `<form class="collect-new"><label class="visually-hidden" for="new-list">A new collection's name</label>`
    + `<input id="new-list" maxlength="80" placeholder="A new collection">`
    + `<button class="cta ghost" type="submit">Make it</button></form></div>`
    + `<p class="said marks-said" role="status"></p>`;
}

/// /m/X: the model's own page. Its picture first, with the strip of its
/// other pictures, and beside it on a laptop (under it on a phone) what it
/// is, who made it, the way into the viewer and the app, and the action
/// bar; then its tabs, About (what its owner said, its tags and licence),
/// Comments, Builds, Remixes and Versions, each a part of the page; and at
/// the end more by its designer and similar models, or, with neither, the
/// gallery's. Every word an owner typed is escaped.
/// web/share-page.js counts the view, and if a reload finds the viewer was
/// here (it keeps the link in the address bar), goes back to it.
/// [counted] is the shown version's steps, counted from its file as it is
/// read (api/_steps.js), or null where they are not known.
function sharePage(origin, id, model, versions = [], shown = null, mark = null, photos = [], next = { by: [], like: [] },
  counted = null) {
  const newest = versions[0]?.n ?? 1;
  const version = shown ?? versions[0] ?? { n: 1, has_image: model.has_image };
  // An older version: its own page, marked as older, its own picture and
  // counts, its viewer, and the newest a click away. Never indexed: the
  // link is what a search should find.
  const old = version.n !== newest;
  const title = old ? `${model.name}, version ${version.n} — a Brickworks model` : `${model.name} — a Brickworks model`;
  const viewer = `/app?view=${id}${old ? `&v=${version.n}` : ""}`;
  const copyLink = `/app?copy=${id}${old ? `&v=${version.n}` : ""}`;
  const shownModel = old ? { ...model, parts: version.parts } : model;
  const picture = old ? (version.has_image ? `/m/${id}/v/${version.n}.png` : "")
    : (model.has_image ? `/m/${id}.png` : "");
  const { head, header, footer } = siteChrome();
  const kind = kindLabel(model.kind);
  const about = model.description
    ? model.description.replace(/\s+/g, " ").slice(0, 157) + (model.description.length > 157 ? "…" : "")
    : "";
  // The one it came from, while it is listed; one shared only by link is
  // not named. And which version of it the copy was made of, when its app
  // said: that version's page, which is the newest's while it is newest.
  const parent = (model.from || [])[0];
  const fromVersion = remixVersion(versions);
  const fromLine = !parent ? "" : parent.id
    ? `<p class="from">Remixed from <a href="/m/${parent.id}">${escapeHtml(parent.name)}</a>`
      + `${fromVersion ? `, <a class="from-version" href="/m/${parent.id}/v/${fromVersion}">version ${fromVersion}</a>` : ""}`
      + `${parent.author ? `, by ${escapeHtml(parent.author)}` : ""}</p>`
    : `<p class="from">Remixed from a model shared by link</p>`;
  // What it is, as pills, each said once there is one. Its steps are the
  // ones its step player and booklet number, counted from the file shown;
  // a file that carries none has them worked out as it opens, and they are
  // not said. What is built on the side is said apart: the orrery's 87
  // steps, and its 12 sub-assemblies' 64.
  const side = counted ? sideSaid(counted) : "";
  const facts = [
    `<li class="pill">${escapeHtml(count(shownModel.parts, "part"))}</li>`,
    counted ? `<li class="pill" data-steps="${counted.steps}">${stepsSaid(counted)}${model.own_steps ? ", laid out by its builder" : ""}</li>` : "",
    side ? `<li class="pill" data-side="${counted.side}">${side}</li>` : "",
    model.technic ? `<li class="pill">Technic or a mechanism</li>` : "",
    // What it does: its own motions' names, else what its app found moves.
    movesWords(model) ? `<li class="pill">${escapeHtml(`Moves: ${movesWords(model)}`)}</li>` : "",
    Number(model.views) ? `<li class="pill"><span data-count="views">${count(model.views, "view")}</span></li>` : "",
    `<li class="pill">${model.listed ? `In the gallery since ${when(model.listed_at)}` : "Shared by link"}</li>`,
    newest > 1 ? `<li><a class="pill version-line" href="#versions">Version ${version.n}${old ? ` of ${newest}` : ""}</a></li>` : "",
    Number(model.remixes) ? `<li><a class="pill" href="#remixes">${count(model.remixes, "remix", "remixes")}</a></li>` : "",
  ].join("");
  const tags = (model.tags || []).map((tag) =>
    `<li><a class="pill tag" href="/gallery?tag=${encodeURIComponent(tag)}">${escapeHtml(tag)}</a></li>`).join("");
  const line = (model.from || []).map((one) => one.id
    ? `<li><a href="/m/${one.id}">${escapeHtml(one.name)}</a>${one.author ? `, by ${escapeHtml(one.author)}` : ""}</li>`
    : "<li>a model shared by link</li>").join("");
  const listedRemixes = model.remixes_listed || [];
  const unlisted = Math.max(0, (Number(model.remixes) || 0) - listedRemixes.length);
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, model, id, title, { about, canonical: links(origin, id).url })}
${old ? '<meta name="robots" content="noindex">\n' : ""}${head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/share-page.js" defer></script>
<script src="/model-page.js" type="module"></script>
<script src="/report.js" type="module"></script>
<script src="/follow.js" type="module"></script>
${structured(origin, id, model)}
</head>
<body data-viewer="${escapeHtml(viewer)}" data-id="${id}" data-version="${version.n}" data-newest="${newest}">
<a class="skip" href="#main">Skip to content</a>
${header}
<main id="main">
<article class="wrap model-page">
  <nav class="crumbs" aria-label="Where it is"><a href="/gallery">Gallery</a>${model.kind
    ? ` <span aria-hidden="true">›</span> <a href="/gallery?kind=${model.kind}">${escapeHtml(kind)}</a>` : ""}</nav>
  ${old ? `<p class="old-version" role="note"><b>An older version.</b> This is version ${version.n} of
    ${newest}, published ${when(version.at)}. <a href="/m/${id}">See the newest, version ${newest}</a></p>` : ""}
  <div class="top">
    <div class="media">
    <a class="picture" href="${escapeHtml(viewer)}" aria-label="View ${escapeHtml(model.name)} in 3D">${picture
      ? `<span class="waiting" aria-hidden="true">Loading its picture…</span><img src="${picture}" alt="${escapeHtml(model.name)}" width="1200" height="630" fetchpriority="high">`
      : `<span class="none">No picture</span>`}<span class="go" aria-hidden="true">View in 3D</span></a>
    ${mediaStrip(model, picture, photos)}
    </div>
    <div class="side">
      <h1>${escapeHtml(model.name)}</h1>
      ${designerRow(model)}
      <div class="actions">
        <a class="cta" href="${escapeHtml(`${viewer}&build`)}" title="Build it with real bricks, one step at a time from step 1: no account needed">Build it</a>
        <a class="cta ghost" href="${escapeHtml(copyLink)}" title="Copy it into your own models, to change and make yours">Open in Brickworks</a>
      </div>
      ${actionBar(origin, id, model)}
      <ul class="facts pills">${mark ? `<li class="tested">${testedMark(mark, counted)}</li>` : ""}${facts}</ul>
      ${fromLine}
      <p class="tested-note" id="tested-note" data-id="${id}" data-version="${version.n}" role="note" hidden></p>
    </div>
    <div class="rest">
  ${pageTabs(model, newest)}
  <section class="words" id="about" aria-labelledby="about-h"><h2 id="about-h">About it</h2>
    ${model.description ? `<p class="description">${escapeHtml(model.description)}</p>` : ""}
    ${tags ? `<ul class="tags pills" aria-label="Tags">${tags}</ul>` : ""}
    <div class="licence"><h3 id="licence-h">Licence</h3>${licenceWords(model)}</div></section>
  ${commentsSection(id, version.n, newest, counted ? counted.pages : null)}
  ${buildsSection(id, model, photos)}
  <section class="tree" id="remixes" aria-labelledby="tree-h"><h2 id="tree-h">Remixes</h2>
    ${line ? `<h3>It came from</h3><ol class="line">${line}</ol>` : ""}
    ${listedRemixes.length || unlisted
      ? `<h3>Made from it</h3>${listedRemixes.length
        ? `<div class="models compact">${listedRemixes.map((row) => cardHtml(cardOf(origin, row))).join("")}</div>` : ""}`
        + (unlisted ? `<p class="note">${listedRemixes.length ? "And " : ""}${count(unlisted, "remix", "remixes")} `
          + `shared by link, not in the gallery.</p>` : "")
      : `<p class="note none">Nobody has remixed it yet. <a href="${escapeHtml(copyLink)}">Open it in Brickworks</a>
        to make a copy of your own to change; share that, and it shows here.</p>`}
  </section>
  ${versionsSection(id, versions, version)}
    </div>
  </div>
  ${model.by ? nextRow("more-by", `More by <a href="/u/${escapeHtml(model.by.handle)}">${escapeHtml(model.by.name)}</a>`, next.by) : ""}
  ${nextRow("similar", "Similar models", next.like)}
  ${nextRow("from-gallery", "More in the gallery", next.gallery || [])}
</article>
</main>
${footer}
</body>
</html>`;
}

/// The strip under the picture (docs/SOCIAL.md U4): the picture it was
/// published with, then its owner's own photos, then the photos of real
/// builds, each a link to its place under Builds; web/model-page.js shows
/// the one chosen in the picture's place. With no photo it is drawn hidden,
/// for its owner to add the first: model-page.js shows it to them alone.
function mediaStrip(model, picture, photos) {
  const thumb = (src, alt, attrs) => `<a class="thumb" ${attrs}><img src="${src}" alt="${escapeHtml(alt)}" `
    + `width="96" height="72" loading="lazy" decoding="async"></a>`;
  const file = (photo) => `/api/people?op=photo_file&amp;id=${photo.id}`;
  return `<div class="media-strip" id="pictures" role="group" aria-label="Its pictures"${photos.length ? "" : " hidden"}>`
    + (picture ? thumb(picture, `${model.name}, as it was published`,
      `href="${picture}" data-picture="${picture}" aria-current="true"`) : "")
    + photos.map((photo) => thumb(file(photo), photo.own ? `${model.name}, a photo by its designer`
      : `A real build of ${model.name}${photo.by ? `, by ${photo.by.name}` : ""}`,
    `href="#photo-${photo.id}" data-picture="${file(photo)}"${photo.own ? " data-own" : ""}`)).join("")
    + `<button type="button" class="thumb add" data-add-picture hidden>Add a picture</button></div>`;
}

/// The page's tabs (docs/SOCIAL.md U4): a link to each part below, with its
/// count once there is one, kept on screen as the page scrolls; the one
/// being read is marked by web/model-page.js, which also counts the
/// comments as it lists them. Versions only once there are two.
function pageTabs(model, newest) {
  const tab = (key, name, n = 0) => `<a href="#${key}" data-tab="${key}">${name}`
    + `${Number(n) ? ` <span class="n">${Number(n).toLocaleString("en-US")}</span>` : ""}</a>`;
  return `<nav class="tabs page-tabs" id="page-tabs" aria-label="On this page">${tab("about", "About")}`
    + `${tab("comments", "Comments")}${tab("builds", "Builds", model.builds)}${tab("remixes", "Remixes", model.remixes)}`
    + `${newest > 1 ? tab("versions", "Versions", newest) : ""}</nav>`;
}

/// One photo of a real build, as the strip shows it: the photo, the line
/// its builder wrote, who (their profile, if they made one) and when, and
/// a way to report it. Every word is theirs, escaped.
function buildFigure(model, photo) {
  const by = photo.by ? `by <a href="/u/${escapeHtml(photo.by.handle)}">${escapeHtml(photo.by.name)}</a>` : "by a builder";
  return `<figure class="build" id="photo-${photo.id}" data-photo="${photo.id}">`
    + `<img src="/api/people?op=photo_file&amp;id=${photo.id}" alt="${escapeHtml(`A real build of ${model.name}`)}" `
    + `width="${photo.width}" height="${photo.height}" loading="lazy" decoding="async">`
    + `<figcaption>${photo.words ? `<q>${escapeHtml(photo.words)}</q>` : ""}`
    + `<span class="by">${by} · ${when(photo.at)}</span>`
    + ` <button type="button" class="link" data-report="this photo" data-report-photo="${photo.id}" hidden>Report it</button>`
    + `</figcaption></figure>`;
}

/// Built by people: how many have built it to the last step, the strip of
/// photos of their real builds, and the way to add one (web/model-page.js
/// shows the form to somebody signed in, and to the model's owner the
/// photos they hid, with a way to hide each). Nobody yet is one line and
/// the way in, never a count of none.
function buildsSection(id, model, photos) {
  const builds = Number(model.builds) || 0;
  return `<section class="builds" id="builds" aria-labelledby="builds-h" data-id="${id}">
    <h2 id="builds-h">Built by people</h2>
    ${builds ? `<p class="built-line">Built to the last step ${builds === 1 ? "once" : `${count(builds, "time")}`}, `
      + "by people following its steps in Brickworks.</p>" : ""}
    ${photos.length ? `<div class="build-strip">${photos.map((photo) => buildFigure(model, photo)).join("")}</div>`
      : `<p class="note no-builds">${builds ? "No photos of a real build yet. Built it? Add yours."
        : "Nobody has built it yet. Built it? Add a photo of yours."}</p>`}
    <div class="add-build" id="add-build" data-id="${id}" hidden>
      <button type="button" class="cta ghost" data-add-build>I built it: add a photo</button>
      <form class="build-form" hidden>
        <label>A photo of your build <small>JPEG, PNG or WebP, up to 8 MB</small>
          <input type="file" name="photo" accept="image/jpeg,image/png,image/webp" required></label>
        <label>A line about it <small>optional</small>
          <input type="text" name="words" maxlength="140" placeholder="Built it with my own bricks, one swap in step 4"></label>
        <p class="note">Photos show the build, not people: no faces, and nobody's name or address.</p>
        <div class="actions"><button class="cta" type="submit">Add the photo</button>
          <button class="cta ghost" type="button" data-cancel>Cancel</button></div>
        <p class="said" role="status"></p>
      </form>
      <p class="said build-said" role="status"></p>
    </div>
  </section>`;
}

/// Where the comments go: drawn by web/model-page.js from
/// /api/people?op=comments (api/_comments.js) as threads, so the page
/// itself is the same for everybody and kept by the CDN. The step picker has the steps of
/// the version shown; a model of more than a thousand has a number to type.
function commentsSection(id, shown, newest, steps) {
  // Steps not known: any step, by number.
  const many = !steps || Number(steps) > 1000;
  const options = !steps || many ? "" : Array.from({ length: Number(steps) },
    (_, at) => `<option value="${at + 1}">step ${at + 1}</option>`).join("");
  const picker = many
    ? `<input id="comment-step" type="number" min="1"${steps ? ` max="${Number(steps)}"` : ""} inputmode="numeric" placeholder="the whole model">`
    : `<select id="comment-step"><option value="">the whole model</option>${options}</select>`;
  return `<section class="comments" id="comments" aria-labelledby="comments-h" data-id="${id}"
    data-version="${shown}" data-newest="${newest}" hidden>
    <h2 id="comments-h">Comments</h2>
    <p class="note comments-lede">What builders said about it and its steps, the newest first, with
      the replies under each. Plain words only; <a href="/guidelines">the guidelines</a> say what is welcome.</p>
    <ol class="comment-list"></ol>
    <form class="comment-new" hidden>
      <div class="comment-on"><label for="comment-step">On</label> ${picker}
        <span class="note">of version ${shown}${shown < newest ? ", an older one" : ""}</span></div>
      <label class="visually-hidden" for="comment-body">Your comment</label>
      <textarea id="comment-body" maxlength="1000" rows="3"
        placeholder="Say something about it, or about a step: this part goes under, not over"></textarea>
      <div class="actions"><button class="cta small" type="submit">Add the comment</button>
        <span class="note comment-count" aria-live="polite"></span></div>
    </form>
    <div class="comment-why" hidden><p class="note"></p></div>
    <p class="said comments-said" role="status"></p>
  </section>`;
}

/// What a page says of the model's versions, once it has more than one:
/// the version shown, what changed in it (worked out from the files, and
/// part by part on request) and what its owner said, how far a builder of
/// the one before can carry on, and the others, newest first.
function versionsSection(id, versions, shown) {
  const newest = versions[0]?.n ?? 1;
  if (newest <= 1 || !shown) return "";
  const said = saidOf(shown.n, shown.changes);
  const changes = shown.changes;
  const lots = changes ? [...changes.added.map((lot) => `<li>Added ${escapeHtml(lotSaid(lot))}</li>`),
    ...changes.removed.map((lot) => `<li>Removed ${escapeHtml(lotSaid(lot))}</li>`)].join("") : "";
  const kept = shown.n > 1 && shown.first > 1
    ? `<p class="kept">${shown.first === 2 ? "Step 1 is" : `Steps 1–${shown.first - 1} are`} as they were in
      version ${shown.n - 1}: a builder who got that far can carry on.</p>` : "";
  const others = versions.filter((one) => one.n !== shown.n).map((one) => {
    const href = one.n === newest ? `/m/${id}` : `/m/${id}/v/${one.n}`;
    const words = saidOf(one.n, one.changes).replace(/^Version \d+: /, "");
    return `<li><a href="${href}">Version ${one.n}</a>${one.n === newest ? ", the newest" : ""}, `
      + `${when(one.at)}${words ? `: ${escapeHtml(words)}` : ""}${one.note ? ` <q>${escapeHtml(one.note)}</q>` : ""}</li>`;
  }).join("");
  return `<section class="versions" id="versions" aria-labelledby="versions-h"><h2 id="versions-h">Versions</h2>
    <p class="changed" data-version="${shown.n}">${said ? escapeHtml(said) : `Version ${shown.n}, the first.`}
      <span class="when">${when(shown.at)}</span></p>
    ${shown.note ? `<blockquote class="version-note"><p>${escapeHtml(shown.note)}</p></blockquote>` : ""}
    ${kept}
    ${lots ? `<details class="lots"><summary>Part by part</summary><ul>${lots}</ul></details>` : ""}
    ${others ? `<h3>${shown.n === newest ? "Earlier versions" : "The others"}</h3><ol class="earlier">${others}</ol>` : ""}
  </section>`;
}

/// /m/X/v/N for a version the model does not have.
function noVersionPage(origin, id, model, asked, newest) {
  const title = `There is no version ${asked} of this model`;
  const { head, header, footer } = siteChrome();
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, model, id, title)}
<meta name="robots" content="noindex">
${head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/follow.js" type="module"></script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
${header}
<main id="main">
  <div class="wrap gone">
    <h1>${escapeHtml(title)}</h1>
    <p class="lede">${escapeHtml(model.name)} has ${count(newest, "version")}.</p>
    <div class="actions"><a class="cta" href="/m/${id}">See the newest</a>
      <a class="cta ghost" href="/gallery">See the gallery</a></div>
  </div>
</main>
${footer || `<footer><small>${NOTICE}</small></footer>`}
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
<link rel="stylesheet" href="/site.css">
<style>
  /* The site's colours, type and corners (site.css); only the card's layout here. */
  body { background: var(--panel); }
  a.whole { display: flex; flex-direction: column; height: 100vh; color: inherit; text-decoration: none; }
  a.whole img { flex: 1; min-height: 0; width: 100%; object-fit: cover; background: var(--bg-soft); }
  .embed-bar { display: flex; align-items: center; gap: var(--s-3); padding: 10px 14px; }
  .embed-bar .words { flex: 1; min-width: 0; display: grid; }
  .embed-bar b { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .embed-bar small { color: var(--ink-soft); font-size: var(--t-small); }
</style>
</head>
<body>
<main>
<a class="whole" href="${escapeHtml(link.url)}" target="_blank" rel="noopener">
  <img src="${row.has_image ? `/m/${id}.png` : "/share.png"}" alt="">
  <span class="embed-bar"><span class="words"><b>${escapeHtml(row.name)}</b><small>${escapeHtml(describe(row))} · Brickworks</small></span><span class="cta small">View in 3D<span class="visually-hidden"> (opens in a new tab)</span></span></span>
</a>
</main>
</body>
</html>`;
}

function gonePage(origin, id, existed) {
  const title = existed ? "This model is no longer shared" : "There is no model at this link";
  const said = existed
    ? "Whoever shared it has taken it down. If they share it again, this link will work again."
    : "The link may be mistyped, or cut short.";
  const { head, header, footer } = siteChrome();
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, null, id, title)}
<meta name="robots" content="noindex">
${head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/follow.js" type="module"></script>
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
// The site's stylesheet ('self'), so the card is drawn in the site's colours.
const EMBED_CSP = "default-src 'none'; img-src 'self'; style-src 'self' 'unsafe-inline'; "
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
/// The steps of the model in the bucket's file [name], counted as it is
/// read (checkModel's count): what was counted when it was published was
/// the 0 STEP lines of its first model until steps206, and is not shown.
/// Null for none known, or no file.
async function countedOf(name) {
  const file = await getFile(name).catch(() => null);
  if (!file) return null;
  try {
    return checkModel(file.toString("utf8")).count;
  } catch {
    return null;
  }
}

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
  if (op === "tested") return testedOwn(request, response);
  if (op === "sweep") return sweep(request, response);
  if (op === "list") return gallery(request, response, origin);
  if (op === "shelves") return shelves(request, response, origin);
  if (op === "sitemap") return sitemap(response, origin);

  // A version asked for, where there can be one: the page, its picture and
  // the model. The gallery's small picture says which upload it is with a
  // v of its own (cardOf), which is not a version.
  const asked = ["page", "image", ""].includes(op) ? askedVersion(request) : null;

  if (op === "page") {
    const page = await modelPage(id);
    if (!page) {
      const gone = await missing(id);
      return html(response, gone.status, gonePage(origin, id, gone.unpublished));
    }
    const versions = await versionsOf(id, page);
    const shown = asked === null ? versions[0] : versions.find((one) => one.n === asked);
    if (!shown) return html(response, 404, noVersionPage(origin, id, page, asked, versions[0].n));
    // Whose it is: their own pictures lead its strip, and the page leads on
    // to the rest of their work. The database not answering is no owner.
    const own = await db(`shared_models?id=eq.${id}&select=owner,test`).then((rows) => rows[0]).catch(() => null);
    const [mark, photos, next, counted] = await Promise.all([markOf(db, id, shown.n),
      photosWhere(`model=eq.${id}`, shownPublicly), nextOf(origin, id, page, own),
      countedOf(versionFile(id, shown.n, versions[0].n, "mpd"))]);
    // The owner's own photos first, as its pictures (docs/SOCIAL.md U4),
    // then the builds of everybody else, newest first.
    const ordered = photos.map((photo) => ({ ...photo, own: Boolean(own && photo.account === own.owner) }))
      .sort((a, b) => Number(b.own) - Number(a.own));
    // Each person on it with their own picture, where they have one.
    await withFaces([page, ordered, next]);
    return html(response, 200, sharePage(origin, id, page, versions, shown, publicMark(mark), ordered, next, counted));
  }

  const row = await publishedRow(id);

  if (op === "embed") {
    if (!row) {
      const gone = await missing(id);
      return html(response, gone.status, gonePage(origin, id, gone.unpublished), { embed: true });
    }
    return html(response, 200, embedCard(origin, id, { ...row, by: await profileOf(id, row.author) }), { embed: true });
  }

  if (op === "image" || op === "thumb") {
    let name = op === "image" ? `${id}.png` : `${id}.webp`;
    let has = row && (op === "image" ? row.has_image : row.has_thumb);
    // An older version's own picture, kept with it.
    if (row && op === "image" && asked !== null) {
      const versions = await versionsOf(id, row);
      const one = versions.find((version) => version.n === asked);
      has = Boolean(one && one.has_image);
      if (one) name = versionFile(id, one.n, versions[0].n, "png");
    }
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
  // Which version: the newest unless one is asked for, and each version's
  // first changed step, for a builder's place (BuildSteps.changed_since).
  const versions = await versionsOf(id, row);
  const newest = versions[0].n;
  const shown = asked === null ? versions[0] : versions.find((one) => one.n === asked);
  if (!shown) {
    return response.status(404).json({ error: `There is no version ${asked} of this model: `
      + `it has ${count(newest, "version")}.`, unpublished: false, newest });
  }
  const model = await getFile(versionFile(id, shown.n, newest, "mpd"));
  if (!model) return response.status(410).json({ error: "This model is no longer shared.", unpublished: true });
  // The mark this version passed, for the viewer's bar; a failure is its
  // owner's alone (?op=tested), so here it is no mark at all.
  const [mark, builds, by] = await Promise.all([markOf(db, id, shown.n), buildsOf(id), profileOf(id, row.author)]);
  const tested = publicMark(mark);
  return response.status(200).json({
    tested,
    // How many have built it to the last step (supabase/builds.sql).
    builds,
    id,
    name: row.name,
    // Whom it credits, as its page says it: the viewer's "by".
    author: creditName({ ...row, by }),
    parts: shown.n === newest ? row.parts : shown.parts,
    updated_at: row.updated_at,
    version: shown.n,
    newest,
    versions: versions.map((one) => versionSaid(origin, id, one, newest)),
    listed: row.listed === true,
    licence: row.licence ?? null,
    // What its owner said about it, for a session reading it as a
    // reference (src/net/gallery_tool.gd) as for its page.
    description: row.description ?? null,
    tags: row.tags || [],
    kind: row.kind ?? null,
    remixed_from: from ? { id: from.id, name: from.name, url: `${origin}/m/${from.id}`,
      version: remixVersion(versions) } : null,
    ...links(origin, id),
    model: model.toString("utf8"),
  });
}

/// /gallery's models, a page at a time: the listed ones a query asks for
/// (api/_directory.js listQuery), through gallery_models, which says for
/// itself what a visitor may see. With the kinds, sizes, sorts, Top's
/// windows and how a model was made, so a client can ask in its words;
/// signed in, whether they like each, and Following.
///
/// Until supabase/gallery_tabs.sql is applied there is no gallery_models:
/// the list is asked of directory_models, as before, and says nothing of
/// windows, Made or Following, so the page offers none of them; a question
/// that asks one is refused in words (400), never a 500.
async function gallery(request, response, origin) {
  const mine = await whoseOwn(request, origin);
  let asked;
  let said;
  try {
    ({ asked, said } = listQuery(request.query || {}, PER_PAGE, MOST_PAGES, { mine: Boolean(mine?.pool),
      signedIn: Boolean(mine) }));
  } catch (trouble) {
    // Signed in, with nothing in their collection to sort or filter by.
    if (mine && trouble instanceof Unacceptable && trouble.status === 401) {
      throw new Unacceptable("There is nothing in your collection yet: add what you own in the app "
        + "(Build › My collection…) and the gallery can say what you can build.", 422);
    }
    throw trouble;
  }
  // Their shares only once there is something to share of.
  if (mine?.pool) asked.pool = mine.account;
  if (asked.following) asked.following = mine.account;
  let rows;
  let tabs = true;
  try {
    rows = await db("rpc/gallery_models", { method: "POST", body: { query: asked } });
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) throw trouble;
    if (asked.following || asked.days || asked.made) {
      throw new Unacceptable("Following, Made and Top's time windows are not here yet: they come with "
        + "the gallery's next update.");
    }
    tabs = false;
    rows = await db("rpc/directory_models", { method: "POST", body: { query: asked } });
  }
  const models = await withWins(rows.slice(0, PER_PAGE).map((row) => ownedCard(origin, row)), Boolean(said.tests));
  if (mine) await withLiked(models, mine.account);
  await withFaces(models);
  // Kept briefly by the CDN, like the pages: the same question asked by
  // a hundred phones is one call to the database. Never with test models,
  // nor anybody's own shares.
  response.setHeader("Cache-Control", said.tests || mine ? TESTS_CACHE : SHARED_CACHE);
  return response.status(200).json({
    ...said,
    per_page: PER_PAGE,
    more: rows.length > PER_PAGE,
    // What each won in the monthly challenges (supabase/challenges.sql).
    models,
    kinds: KINDS,
    sizes: Object.entries(SIZES).map(([id, size]) => ({ id, label: size.label })),
    sorts: Object.entries({ ...SORTS, ...(mine?.pool ? MINE_SORTS : {}) }).map(([id, label]) => ({ id, label })),
    ...(tabs ? {
      windows: Object.entries(WINDOWS).map(([id, one]) => ({ id, label: one.label })),
      mades: Object.entries(MADES).map(([id, label]) => ({ id, label })),
      following: Boolean(mine),
    } : {}),
    score: SCORE,
    ...(mine ? { mine: mine.pool } : {}),
  });
}

/// Which of [cards] [account] likes, said on each (liked), for the hearts
/// on the cards: their own, so only in an answer never kept by the CDN.
/// Left unsaid when it cannot be read.
async function withLiked(cards, account) {
  const ids = cards.map((one) => String(one.id)).filter((id) => ID.test(id));
  if (!ids.length) return cards;
  try {
    const liked = new Set((await db(`model_likes?account=eq.${account}&model=in.(${[...new Set(ids)].join(",")})&select=model`))
      .map((row) => row.model));
    for (const one of cards) one.liked = liked.has(one.id);
  } catch {
    // Unsaid: the hearts are drawn as not pressed.
  }
  return cards;
}

/// The person asking with &mine=1, and what their collection holds as the
/// gallery counts it (api/_owned.js freshPool: lots, pieces, how many of
/// their sets no inventory has), or null for a list asked without it.
/// Asked with it and not signed in is refused (401): their own shares are
/// only ever theirs.
async function whoseOwn(request, origin) {
  const value = String(request.query?.mine ?? "").toLowerCase();
  if (!value || value === "0" || value === "false") return null;
  if (!["1", "true", "yes", "on"].includes(value)) throw new Unacceptable("mine is 1 or left out");
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    throw new Unacceptable(trouble?.message || "sign in to see what you own", trouble?.status || 401);
  }
  const pool = await freshPool(claims.sub, origin);
  return { account: claims.sub, pool: pool && typeof pool === "object"
    ? { lots: Number(pool.lots) || 0, pieces: Number(pool.pieces) || 0,
      unknown: Array.isArray(pool.unknown) ? pool.unknown.length : 0 } : null };
}

/// A card, and the asker's share of its parts when it was asked for theirs:
/// {pieces, have, share}, pieces null for a model not counted yet.
function ownedCard(origin, row) {
  const card = cardOf(origin, row);
  if (row.owned && typeof row.owned === "object") {
    const pieces = row.owned.pieces === null || row.owned.pieces === undefined ? null : Number(row.owned.pieces);
    const have = pieces === null ? null : Math.min(Number(row.owned.have) || 0, pieces);
    card.owned = { pieces, have, share: pieces ? have / pieces : null };
  }
  return card;
}

/// What a model needs kept (supabase/discovery.sql owned_keep_needs), in
/// the one spelling a collection is compared by. Never throws.
/// What moves in the model, as its app found from the model's joints
/// (src/assembly/playable.gd): each of MOVES at most once, in its order.
/// Undefined when not said (an app from before), which leaves what a model
/// had as it was.
export function checkMoves(given) {
  if (given === undefined || given === null) return undefined;
  if (!Array.isArray(given) || given.length > MOVES.length) {
    throw new Refusal(`moves is a list of what moves: ${MOVES.join(", ")}`);
  }
  for (const word of given) {
    if (typeof word !== "string" || !MOVES.includes(word)) {
      throw new Refusal(`moves is a list of what moves: ${MOVES.join(", ")}`);
    }
  }
  return MOVES.filter((word) => given.includes(word));
}

/// What moves, kept with the model's row: the app's words (supabase/play.sql)
/// and its motions' names, read from the text published (supabase/motions.sql).
/// {moves, motions}, each as kept or null. Never stops the publish: before
/// motions.sql there is nowhere to keep the names, and the words are kept
/// alone; before play.sql, neither.
async function keepMoves(id, owner, moves, motions) {
  const row = `shared_models?id=eq.${id}&owner=eq.${owner}`;
  try {
    await db(row, { method: "PATCH", body: moves === undefined ? { motions } : { moves, motions } });
    return { moves: moves ?? null, motions };
  } catch {
    if (moves === undefined) return { moves: null, motions: null };
  }
  try {
    await db(row, { method: "PATCH", body: { moves } });
    return { moves, motions: null };
  } catch {
    return { moves: null, motions: null };
  }
}

async function keepNeeds(id, needs) {
  try {
    await db("rpc/owned_keep_needs", { method: "POST", body: { model_id: id, needs: keyed(needs || []) } });
    return true;
  } catch {
    return false;
  }
}

/// The week's numbers of a pick, as the page says them.
const weekOf = (week) => ({ builds: Number(week?.builds) || 0, remixes: Number(week?.remixes) || 0,
  tested: week?.tested === true, score: Number(week?.score) || 0 });

/// /gallery's front: this week's pick (gallery_pick: the owner's choice
/// while it is open and in the gallery, or the best of the past seven days)
/// and the small builds' shelf (the Size filter's Small, by Top builds).
/// Before supabase/discovery.sql is applied there is no pick, and the shelf
/// is the newest small models. Kept briefly by the CDN, as the list.
async function shelves(request, response, origin) {
  const tests = testsAsked(request.query || {});
  const mine = await whoseOwn(request, origin);
  const notYet = (trouble) => (/: 404$/.test(String(trouble?.message || "")) ? null : Promise.reject(trouble));
  const [pick, small, ready, challenge] = await Promise.all([
    db("rpc/gallery_pick", { method: "POST", body: { tests } }).catch(notYet),
    db("rpc/directory_models", { method: "POST", body: { query: {
      most: SIZES.small.most, sort: "top", size: SHELF + 1, ...(tests ? { tests: true } : {}),
      ...(mine?.pool ? { pool: mine.account } : {}) } } }),
    // What they can build now, every piece in their collection: by Top builds.
    mine?.pool ? db("rpc/directory_models", { method: "POST", body: { query: {
      pool: mine.account, buildable: true, sort: "top", size: SHELF + 1, ...(tests ? { tests: true } : {}) } } }) : null,
    // The monthly challenge open now, or the next (supabase/challenges.sql).
    challengeLine(tests),
  ]);
  const cards = {
    ready: (ready || []).slice(0, SHELF).map((row) => ownedCard(origin, row)),
    pick: pick && pick.card && ID.test(String(pick.card.id || "")) ? cardOf(origin, pick.card) : null,
    small: await withWins((small || []).slice(0, SHELF).map((row) => ownedCard(origin, row)), tests),
  };
  if (mine) await withLiked([...cards.ready, ...(cards.pick ? [cards.pick] : []), ...cards.small], mine.account);
  await withFaces(cards);
  response.setHeader("Cache-Control", tests || mine ? TESTS_CACHE : SHARED_CACHE);
  return response.status(200).json({
    ...(mine ? { mine: mine.pool, ready: { models: cards.ready, more: (ready || []).length > SHELF } } : {}),
    pick: cards.pick ? {
      chosen: pick.chosen === true, until: pick.chosen === true ? pick.until ?? null : null,
      week: weekOf(pick.week), model: cards.pick,
    } : null,
    small: { size: "small", label: SIZES.small.label, most: SIZES.small.most, models: cards.small,
      more: (small || []).length > SHELF },
    challenge,
    score: SCORE,
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

/// A build finished on some device, sent by the app once it reaches the
/// last step from the step before (src/main.gd): counted once per device,
/// and only for a person in a browser on this site or the desktop app. The
/// answer says whether it was, and how many now, and never who.
async function built(request, response) {
  const id = String(request.query?.id || "");
  const device = String(request.body?.device || "");
  const person = looksLikePerson(request) || fromTheApp(request);
  return response.status(200).json(await countBuild(id, device, person));
}

async function signedIn(request) {
  const claims = await verify(bearer(request), request);
  return claims.sub;
}

async function mine(request, response, origin) {
  response.setHeader("Cache-Control", "private, no-store");
  const owner = await signedIn(request);
  const [rows, profile] = await Promise.all([
    db(`shared_models?owner=eq.${owner}&select=${PUBLIC},barred&order=updated_at.desc`),
    db("rpc/feed_who", { method: "POST", body: { account: owner } }).catch(() => null),
  ]);
  const marks = await newestMarks(rows.filter((row) => row.published).map((row) => row.id));
  return response.status(200).json({
    shared: rows.map((row) => ({ ...row, ...links(origin, row.id), tested: ownerMark(marks.get(row.id)) })),
    // Whom Show who made it credits (src/ui/share_panel.gd): their profile
    // shown in public, {name, handle}, or null with none.
    credit: profile && profile.name ? { name: profile.name, handle: profile.handle } : null,
  });
}

/// The mark of each link's newest version, for its owner: id -> row. A
/// newest version with none is untested, whatever an older one passed.
async function newestMarks(ids) {
  const out = new Map();
  for (let at = 0; at < ids.length; at += 100) {
    const some = ids.slice(at, at + 100).join(",");
    if (!some) continue;
    try {
      const [versions, marks] = await Promise.all([
        db(`share_versions?model=in.(${some})&select=model,n&order=n.desc`),
        db(`share_tests?model=in.(${some})&select=model,n,at,app,parts,steps,tests,passed,cleared_at,cleared_why`
          + "&order=n.desc"),
      ]);
      const newest = new Map();
      for (const one of versions) if (!newest.has(one.model)) newest.set(one.model, one.n);
      for (const one of marks) {
        if (!out.has(one.model) && one.n === (newest.get(one.model) ?? 1)) out.set(one.model, one);
      }
    } catch {
      // Before tested.sql: nothing is tested.
    }
  }
  return out;
}

/// ?op=tested&id=X: what the app found of the owner's own model, every
/// test and why — the note to its designer a failing mark is. Nobody else's.
async function testedOwn(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const owner = await signedIn(request);
  const id = String(request.query?.id || "");
  const row = await ownRow(id);
  if (!row || !row.published) throw new Refusal("there is no shared model at that link", 404);
  // Somebody else's model: nothing to tell them, and nothing refused, since
  // every signed-in visitor's page asks (web/model-page.js) and a 403 was a
  // refused request in their console on every model not theirs.
  if (row.owner !== owner) return response.status(200).json({ id, mine: false, tested: null });
  const asked = askedVersion(request);
  const n = asked ?? (await versionsOf(id, row, 1))[0].n;
  return response.status(200).json({ id, version: n, tested: ownerMark(await markOf(db, id, n)) });
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
  const claims = await verify(bearer(request), request);
  const owner = claims.sub;
  const body = request.body && typeof request.body === "object" ? request.body : {};

  // Everything about the upload is checked before anything is counted
  // or stored, so a refused upload costs nobody a publish.
  const { parts, bytes, steps, ownSteps, technic, needs } = checkModel(body.model);
  const picture = checkImage(body.image);
  const thumb = checkThumb(body.thumb);
  // What the app found, checked against this very file (api/_tested.js).
  const finding = checkTested(body.tested, body.model);
  // And what moves in it, from its joints (supabase/play.sql), and its own
  // motions' names, from the text itself (supabase/motions.sql).
  const moves = checkMoves(body.moves);
  const motions = motionsIn(body.model);
  const name = cleanText(body.name, MAX_NAME);
  if (!name) throw new Refusal("give the model a name to share it under");
  // A credit is the person's profile, by its name, when they have one shown
  // in public, whatever name came with it: as Studio and Mecabricks credit
  // your username, and as the model's page heads it. Without one, the name
  // given, but never one made from the address they sign in with, which an
  // app before m157 offered (walk180, 2026-10-23).
  let author = cleanText(body.author, MAX_AUTHOR) || null;
  if (author) {
    const profile = await db("rpc/feed_who", { method: "POST", body: { account: owner } });
    if (profile && profile.name) author = profile.name;
    else if (madeFromAddress(author, claims.email)) {
      throw new Refusal("that name to credit is made from the address you sign in with, which Brickworks never "
        + "shows: make a profile at brickworks.diy/profile to be credited by its name, or give another", 422);
    }
  }
  if (body.listed !== undefined && typeof body.listed !== "boolean") {
    throw new Refusal("listed is true or false");
  }
  const listed = body.listed === true;
  const about = saidAbout(body);
  // What its owner says changed in this version, if anything.
  const note = cleanText(body.note, MAX_NOTE) || null;
  const fromVersion = body.remixed_from_version;
  if (fromVersion !== undefined && fromVersion !== null
      && !(Number.isInteger(fromVersion) && fromVersion >= 1 && fromVersion <= 100000)) {
    throw new Refusal("remixed_from_version is a version's number, from 1");
  }
  // What a stranger may not be shown, in a name or anywhere it is said
  // (api/_names.js): before anything is counted or stored.
  const said = namesTrouble({ "The name": [name, "name"], "The credit": [author, "name"],
    "A tag": [about.tags, "name"], "The description": [about.description, "words"],
    "What changed": [note, "words"] });
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
  // The age rule (api/_trust.js): a listing needs 13 or over, and a name
  // shown on the link not being under 13. 422, never 403 (above).
  const young = await publicTrouble(owner, { listing: newlyListed ? true : listed ? "kept" : false,
    credit: Boolean(author) && author !== (existing?.author ?? null) });
  if (young) throw new Refusal(young, 422);

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

  // Its next version, and the one before kept: the newest's files are
  // renamed for its number before the new one takes the link's own, and
  // what changed is worked out from the two models. A link taken down has
  // no versions left (unpublish), and shared again it starts at 1; any a
  // takedown before versions were kept left behind go first.
  const republish = Boolean(existing && existing.published);
  let earlier = [];
  let changes = null;
  if (republish) {
    earlier = await versionsOf(id, existing, 1);
    const last = earlier[0];
    if (last.implied) {
      // Shared before its versions were kept, and not since: its version 1
      // is written down now, as it is.
      await db("share_versions", { method: "POST", body: { model: id, n: 1, at: last.at, parts: last.parts,
        steps: last.steps, bytes: last.bytes, has_image: last.has_image } });
    }
    const before = await getFile(`${id}.mpd`);
    if (before) {
      await putFile(`${id}.v${last.n}.mpd`, before, "text/plain");
      changes = changesBetween(before.toString("utf8"), body.model);
    }
    const picturedBefore = last.has_image ? await getFile(`${id}.png`) : null;
    if (picturedBefore) await putFile(`${id}.v${last.n}.png`, picturedBefore, "image/png");
  } else if (existing) {
    await db(`share_versions?model=eq.${id}`, { method: "DELETE" });
  }
  const n = republish ? earlier[0].n + 1 : 1;
  // Which version of the model it was copied from, when it is a copy and
  // its app said: one that model has, or none. Kept by a republish that
  // does not say it again, as remixed_from is.
  let remixedFromVersion = null;
  if (parent && fromVersion) {
    const parentNewest = (await versionsOf(parent.id, null, 1))[0]?.n ?? 1;
    remixedFromVersion = fromVersion <= parentNewest ? fromVersion : null;
  } else if (remixedFrom && republish) {
    remixedFromVersion = earlier[0].from_version ?? null;
  }

  await putFile(`${id}.mpd`, body.model, "text/plain").catch(dropNew);
  if (picture) await putFile(`${id}.png`, picture, "image/png").catch(dropNew);
  else if (existing) await deleteFiles([`${id}.png`]).catch(() => {});
  if (thumb) await putFile(`${id}.webp`, thumb, "image/webp").catch(dropNew);
  else if (existing) await deleteFiles([`${id}.webp`]).catch(() => {});

  const now = new Date().toISOString();
  const row = { name, author, parts, bytes, has_image: Boolean(picture), has_thumb: Boolean(thumb),
    published: true, updated_at: now, listed, listed_at: listed ? (newlyListed ? now : existing.listed_at) : null,
    remixed_from: remixedFrom, description, tags, kind, licence, steps, own_steps: ownSteps, technic,
    test: isTestAccount(claims) };
  if (existing) {
    await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: row });
  } else {
    await db("shared_models", { method: "POST", body: { id, owner, ...row } }).catch(dropNew);
  }
  // The version itself, after its model's row (it is that row's).
  const first = n === 1 ? null : changes ? changes.first : 1;
  await db("share_versions", { method: "POST", body: { model: id, n, at: now, note, parts, steps, bytes,
    has_image: Boolean(picture), changes, first_changed: first, remixed_from_version: remixedFromVersion } });
  // What the app found of this version, kept with it as the app's finding.
  // One that cannot be kept, or a table not there yet, never stops the
  // publish: the version is then untested, and the answer says why.
  let kept = null;
  if (finding?.row) {
    try {
      await db("share_tests", { method: "POST", body: { model: id, n, at: now, ...finding.row } });
      kept = { kept: true, passed: finding.row.passed, by: "app", app: finding.row.app,
        tests: ownerMark({ ...finding.row, n, at: now }).tests };
    } catch {
      kept = { kept: false, why: "Brickworks could not keep what it found just now" };
    }
  } else if (finding?.refused) {
    kept = { kept: false, why: finding.refused };
  }
  // What it needs, by part and colour, in place of what it needed: the
  // gallery's Build with what I own. Never stops the publish; before
  // supabase/discovery.sql there is nowhere to keep it.
  await keepNeeds(id, needs);
  const movesKept = await keepMoves(id, owner, moves, motions);

  const origin = originOf(request);
  return response.status(existing ? 200 : 201).json({
    id, name, author, parts, bytes, published: true, updated: Boolean(existing),
    listed, remixed_from: remixedFrom, remixed_from_version: remixedFromVersion, gallery: `${origin}/gallery`,
    description, tags, kind, licence, steps, own_steps: ownSteps, technic,
    version: n, note, changes: readChanges(changes), said: saidOf(n, changes), first_changed: first,
    version_url: `${origin}/m/${id}/v/${n}`, tested: kept, moves: movesKept.moves, motions: movesKept.motions,
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
  // republish from the same model keeps the same link. The files go, every
  // version's, and then the versions themselves.
  const versions = await db(`share_versions?model=eq.${id}&select=n`);
  await deleteFiles([`${id}.mpd`, `${id}.png`, `${id}.webp`,
    ...versions.flatMap((one) => [`${id}.v${one.n}.mpd`, `${id}.v${one.n}.png`])]);
  await db(`share_versions?model=eq.${id}`, { method: "DELETE" });
  return response.status(200).json({ id, published: false, versions: versions.length });
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
  // A photo as a phone sent it is read and deleted at once (api/_builds.js);
  // one whose sender never asked for it to be kept is gone within the day,
  // an hour after it came. Only that bucket's, and only files over an hour.
  let originals = 0;
  if (only.length === 0) {
    const stale = (await uploadsLeft()).filter((file) => now - Date.parse(file.at || 0) > SWEEP_AGE_MS)
      .map((file) => file.name);
    for (let at = 0; at < stale.length; at += 100) await deleteBuildFiles(UPLOADS, stale.slice(at, at + 100));
    originals = stale.length;
  }
  return response.status(200).json({ looked_at: files.length, kept: files.length - gone.length, removed: gone,
    originals });
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
    if (op === "built") return await built(request, response);
    if (op === "") return await publish(request, response);
    return response.status(400).json({ error: `unknown op ${op}` });
  } catch (trouble) {
    if (trouble instanceof AuthError) return response.status(trouble.status).json({ error: trouble.message });
    if (trouble instanceof Refusal || trouble instanceof Unacceptable || trouble instanceof BuildRefusal) {
      return response.status(trouble.status).json({ error: trouble.message });
    }
    console.error("share:", trouble.message);
    return response.status(502).json({ error: "Brickworks could not reach its storage just now. Try again in a minute." });
  }
}
