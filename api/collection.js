// My collection: what a person owns, kept with their account.
//
//   GET    /api/collection   the caller's collection, and its rev
//   POST   /api/collection   one change: an import, or an op
//   DELETE /api/collection   all of it gone (an older app's Start over)
//   PUT    /api/collection   refused: an older app's whole collection
//
// Every change is one op, made on the row as it is in the database and
// written only if the row is still that row (mybricks2, 2026-11-06). A
// collection is never written from a copy an app holds: the app says what
// to change, and what it saw where that matters, and the change is made
// here on what is kept. supabase/collection_ops.sql gives the row its rev,
// which moves on every write by anyone; a write here is a PATCH held to the
// rev it read, and when another write came first it reads again and makes
// the change again on what that one left (TRIES times). So two changes at
// once both land, and a change never brings back what another took out.
//
// Imports, parsed and mapped here and nowhere else, so a Rebrickable
// export, a BrickLink XML and a list fetched from Rebrickable's API with
// the person's own key all land in one shape and one numbering, LDraw's
// (supabase/collection.sql says what that shape is):
//
//   {"from": "rebrickable_csv", "text": "<the file>", "mode": "add"}
//   {"from": "bricklink_xml",   "text": "<the file>", "mode": "add"}
//   {"from": "rebrickable_api", "sets": [["10237-1", 1, true]],
//                               "parts": [["3001", 4, 12]], "mode": "add"}
//   {"from": "brickset_csv",    "text": "<the file>", "mode": "add"}
//                                                      Brickset's My sets
//                                                      (bricksetCsv): the
//                                                      sets owned; those
//                                                      wanted are the
//                                                      wishlist's
//                                                      (api/_mylists.js)
//   {"from": "sets", "text": "10237-1, 6020"}          typed by number
//   {"from": "figs", "figs": [{"fig": "sw0001a", "name": "Luke Skywalker"}]}
//                                                      minifigures, by
//                                                      BrickLink's number
//
// Every lot and set keeps where it came from ("src"): "hand" (added in My
// collection, a set typed by number, or owned on the website), "rebrickable"
// (the person's Rebrickable data, fetched with their key or exported as a
// CSV: one person's one list, however it came), "bricklink_xml" or
// "brickset" (a Brickset export, its sets only); a lot a session
// added says who instead ("by", the name the session goes by, "Claude")
// and which of its chats ("chat"). Each is its own lot, apart from the
// same part and colour from anywhere else, so "replace" (a Rebrickable
// fetch) replaces only what Rebrickable brought before: a sets list its
// sets, a parts list its lots. A set the person typed that the fetch lists
// is the same set, kept once, as the fetch's. What was kept before sources
// were (no src, no by) came from imports, and a replace takes it as it
// always did (My collection lists it as brought in before, and says a
// fetch replaces it); a lot counted by hand or a session's is never
// touched by an import.
//
// Ops, each with an "id" the app makes per action and sends again as it was
// when the network fails: an id already applied is not applied again, and
// is answered as it was the first time (its reply is kept with it, the last
// MOST_REMEMBERED).
//
//   {"op": "lots", "add": [{part, colour, qty, by?, chat?}],
//                  "remove": [{part, colour, qty?, by, chat?, was}]}
//       added to the lot (made if new: the person's own, src "hand", or the
//       session's); a session's own lot, at the count it saw ("was"), taken
//       down by qty (all of it when qty is 0 or none), never below none.
//       Several removes of one lot add up. Only a session's lots are taken
//       down this way.
//   {"op": "set", "lots": [{part, colour, src?, by?, chat?, was, qty}]}
//       each lot from the count the person saw ("was") to qty (0 takes it
//       out)
//   {"op": "keep", "lots": [{part, colour, by, chat?, was}]}
//       a session's lots, at the counts the person saw, made their own
//   {"op": "take_back", "lots": [{part, colour, by, chat?, was}]}
//       a session's lots, at the counts the person saw, taken out
//   {"op": "remove_set", "set": "6020-1", "src"?, "was": 1}
//       a set, at the count the person saw, taken out
//   {"op": "own", "set": "6020-1", "was": 0, "qty": 1}
//       how many of a set the person owns, every copy from anywhere, from
//       the count they saw to qty (0: none): the website's Own (lists1).
//       More goes onto their own copy (src "hand"); fewer comes off theirs
//       first, then off the other sources' copies. Back up to a count an
//       Own (with an id) took it down from, nothing changed since, puts
//       back those copies as they were: their source and their marks
//       (an Undo). Answered with no more
//       than a card needs: {done: {owned}, rev}, and a 409 {error, owned}
//       with the count as it is now (a card asks it on every page, and the
//       whole collection is thousands of lots)
//   {"op": "start_over", "rev": <the rev the person saw>}
//   {"op": "missing", "set": "7140-1", "src"?: "hand",
//                     "lots": [{part, colour, was, qty}]}
//       the parts a set has missing (mysets, APP_UX6 #6): each lot's count
//       missing from the count the person saw ("was", 0 for none) to qty
//       (0: none missing). Kept on the set as "missing": [{part, colour,
//       qty}], in LDraw's numbers as the set's inventory has them.
//
// A set as it really is (mysets, 2026-11-07), additive: a set entry may
// carry "missing", the lots it is short of, and a minifigure is kept among
// the sets as {"set": "sw0001a", "fig": true, "name": ..., "qty", "src"},
// BrickLink's number with no -1 (no set number is without one, so the two
// never meet). Every op keeps both as they are; a Rebrickable fetch that
// lists a set again keeps its missing lots, as an import of a set already
// there does, as far as the copies it keeps hold each part (its inventory,
// read from the shards; a part by the number it means today and the colour
// a shop files it under, as the app counts it): what is more goes onto the
// person's other copy of the set, or is said ("unkept"). A set whose
// inventory could not be read keeps its marks as they were ("unread"); a
// set the replace no longer lists goes with its marks, said ("gone").
// remove_set takes a figure out by its number, from an older app too. An
// older app reads every set and lot as
// before and counts a set with parts missing as whole, as it always has.
//
// What was seen and is no longer so (a count moved on, a lot gone, the rev
// moved on) is refused with 409 and the collection as it is now, changing
// nothing: the app shows it and the person asks again.
//
// An older app (rel-m267 and before, desktop 0.17.0) takes a set out by PUT
// of its whole copy, without any lot's source or session, and says nothing
// of when it was read. It is made as remove_set only when it is the
// collection as kept with one set number gone: its sets exactly the sets
// kept without that number, and its lots, added up by part and colour,
// exactly the lots kept. Anything else (a copy read before another device
// changed something) is refused with 409 and words that say to update,
// changing nothing. Its imports and its DELETE are ops as above.
//
// A count over MAX_QTY is kept at MAX_QTY, and the reply says which lots
// were ("clamped").
//
// The Rebrickable key is never sent here. The app calls Rebrickable's API
// itself (its CORS allows any page) and sends on only what came back.
//
// Numbers. A Rebrickable colour id becomes an LDraw code through the same
// join the catalogue is built with (tools/rebrickable.py), and the few
// Rebrickable part numbers that are not LDraw's are renamed through it too;
// both come from tools/collection_data.py's index, which deploy.sh puts
// beside this file. A BrickLink colour becomes an LDraw code through the
// numbers the app exports wanted lists with (colors.json's bricklink, from
// tools/bricklink_colours.py), read into the same index. A colour neither
// knows is left out and said so, never guessed: a guessed colour is the
// wrong plastic. A lot given in LDraw's numbers is an LDConfig colour code
// (COLOUR_NAMES), never 16 or 24, and never null, "", false or a word.
//
// Refused, with words: no sign-in (401), naming another account's
// collection (403 — a collection is only ever its owner's, and there is no
// way to ask for anyone else's), a body over MAX_BYTES (MAX_KEEP_BYTES for
// Keep them and Take back) or a collection over MAX_SETS sets or MAX_LOTS
// lots (413), and a file that is not what it says it is (400, with the
// line). The database's own row security is the second lock
// (supabase/collection.sql).

import { randomUUID } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { AuthError, authConfigured, bearer, verify } from "./_auth.js";
import { COLOUR_NAMES } from "./_colours.js";
import { db, dbConfigured } from "./_db.js";
import { originOf } from "./_oauth.js";
import { plainColour, readShard, resolvePart, shardOf } from "./_owned.js";

export const MAX_BYTES = 1_000_000;
/// Keep them and Take back name every lot a session added, up to MAX_LOTS.
export const MAX_KEEP_BYTES = 4_000_000;
export const MAX_SETS = 5000;
export const MAX_LOTS = 20000;
const MAX_QTY = 100000;

const SET_NUMBER = /^[a-z0-9][a-z0-9._]{0,24}(-[0-9]{1,3})?$/;
const PART_NUMBER = /^[a-z0-9][a-z0-9._-]{0,40}$/;
/// A minifigure's BrickLink number (sw0001a, pln190s, 47394pb001): never a
/// set number's -N.
const FIG_NUMBER = /^[a-z0-9][a-z0-9._]{0,40}$/;
/// The most lots one set is marked as missing.
export const MOST_MISSING = 5000;
/// Which of a session's chats added a lot: an id.
const CHAT = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,99}$/;
/// A request's id: the app's, one per action.
const REQUEST = /^[A-Za-z0-9._:-]{8,64}$/;
/// The most lots one "lots" or "set" op changes.
export const MOST_LOT_CHANGES = 2000;
/// How many request ids a collection remembers.
export const MOST_REMEMBERED = 100;
/// How many of the remembered changes keep the copies an Own took down
/// from, and how large each may be: an Own back up puts those back.
const MOST_AWAY = 20;
const MOST_AWAY_BYTES = 32000;
/// How many times a change is made again on what another write left.
const TRIES = 12;

/// Where each import's lots and sets come from; "hand" is My collection's.
export const HAND = "hand";
/// A fetch from the person's Rebrickable account and an export from it are
/// one list: one source.
export const REBRICKABLE = "rebrickable";
export const SOURCE_OF = {
  sets: HAND, rebrickable_api: REBRICKABLE, rebrickable_csv: REBRICKABLE, bricklink_xml: "bricklink_xml",
  figs: HAND, brickset_csv: "brickset",
};
const SOURCES = new Set(Object.values(SOURCE_OF));
/// The sources there were before each set and lot said its own: a replace
/// from one of them took everything, what is kept with no src included.
const BEFORE_SOURCES = new Set([HAND, REBRICKABLE, "bricklink_xml"]);

export class Refusal extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/// What the person saw is no longer so: 409, with the collection as it is.
export class Conflict extends Refusal {
  constructor(message, row) {
    super(409, message);
    this.row = row;
  }
}

let cachedIndex = null;

/// The joins tools/collection_data.py writes: beside this file in a
/// deployment, under assets/ in a checkout.
export function joins() {
  if (cachedIndex) return cachedIndex;
  for (const where of ["./_collection_index.json", "../assets/generated/sets/index.json"]) {
    const url = new URL(where, import.meta.url);
    if (existsSync(url)) {
      const raw = JSON.parse(readFileSync(url, "utf8"));
      cachedIndex = {
        colours: new Map(Object.entries(raw.colours || {}).map(([k, v]) => [Number(k), Number(v)])),
        parts: new Map(Object.entries(raw.parts || {})),
        bricklink: new Map(Object.entries(raw.bricklink_colours || {}).map(([k, v]) => [Number(k), Number(v)])),
      };
      return cachedIndex;
    }
  }
  throw new Refusal(503, "the parts index is not on this deployment");
}


/// "10237" is "10237-1": Rebrickable's and BrickLink's first version.
export function setNumber(raw) {
  let text = String(raw ?? "").trim().toLowerCase();
  if (text && !/-[0-9]{1,3}$/.test(text)) text += "-1";
  return SET_NUMBER.test(text) ? text : null;
}

export function partNumber(raw) {
  const text = String(raw ?? "").trim().toLowerCase().replace(/\.dat$/, "");
  return PART_NUMBER.test(text) ? text : null;
}

export function figNumber(raw) {
  const text = String(raw ?? "").trim().toLowerCase();
  return FIG_NUMBER.test(text) && !/-[0-9]{1,3}$/.test(text) ? text : null;
}

/// A minifigure's name as its finder gave it: printable, 120 characters at most.
function figName(raw) {
  return [...whoName(raw)].slice(0, 120).join("").replace(/ +$/, "");
}

/// Minifigures found by a photo: [{fig, name}], each kept once.
export function typedFigs(list) {
  if (!Array.isArray(list) || list.length === 0) throw new Refusal(400, "no minifigure given");
  if (list.length > 100) throw new Refusal(413, `that is ${list.length} minifigures; one change is at most 100`);
  return list.map((one, n) => {
    const fig = figNumber(one?.fig);
    if (!fig) throw new Refusal(400, `minifigure ${n + 1}: "${one?.fig ?? ""}" is not a BrickLink minifigure number`);
    return [fig, 1, figName(one?.name)];
  });
}

function quantity(raw, line) {
  const text = String(raw ?? "").trim();
  if (!/^[0-9]+$/.test(text)) throw new Refusal(400, `${line}: the quantity "${text}" is not a whole number`);
  const n = Number(text);
  if (n < 1 || n > MAX_QTY) throw new Refusal(400, `${line}: a quantity of ${n} is outside 1 to ${MAX_QTY}`);
  return n;
}

/// RFC 4180, the way spreadsheets write it: quoted fields may hold commas,
/// quotes doubled, and line breaks inside quotes.
export function csvRows(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"' && field === "") quoted = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(field); rows.push(row); row = []; field = "";
    } else field += c;
  }
  if (quoted) throw new Refusal(400, "the file ends inside a quoted field");
  if (field !== "" || row.length) { row.push(field); rows.push(row); }
  return rows.filter((r) => r.some((f) => f.trim() !== ""));
}

const HEADINGS = {
  part: ["part", "part_num", "part number", "part_number", "partnum", "part no"],
  colour: ["color", "colour", "color_id", "color id", "colour_id", "colour id"],
  qty: ["quantity", "qty", "count", "quantity owned"],
  set: ["set number", "set_num", "set", "set no", "set_number", "setnumber"],
  spares: ["includes spares", "include_spares", "include spares", "includes_spares"],
};

function column(headings, kind) {
  return headings.findIndex((h) => HEADINGS[kind].includes(h));
}

/// A Rebrickable export: a sets list (Set Number, Quantity, Includes
/// Spares) or a parts list (Part, Color, Quantity), in Rebrickable's
/// numbers. Anything else is refused with the line it went wrong on.
export function rebrickableCsv(text) {
  const rows = csvRows(String(text || "").replace(/^﻿/, ""));
  if (rows.length === 0) throw new Refusal(400, "the file is empty");
  const headings = rows[0].map((h) => h.trim().toLowerCase());
  const at = Object.fromEntries(Object.keys(HEADINGS).map((k) => [k, column(headings, k)]));
  if (at.qty < 0) throw new Refusal(400, "line 1: no Quantity column — is this a Rebrickable export?");
  const sets = [];
  const parts = [];
  if (at.set >= 0 && at.part < 0) {
    rows.slice(1).forEach((row, n) => {
      const line = `line ${n + 2}`;
      const set = setNumber(row[at.set]);
      if (!set) throw new Refusal(400, `${line}: "${row[at.set] ?? ""}" is not a set number`);
      const spares = at.spares >= 0 && /^(true|yes|1)$/i.test(String(row[at.spares]).trim());
      sets.push([set, quantity(row[at.qty], line), spares]);
    });
  } else if (at.part >= 0 && at.colour >= 0) {
    rows.slice(1).forEach((row, n) => {
      const line = `line ${n + 2}`;
      const part = partNumber(row[at.part]);
      if (!part) throw new Refusal(400, `${line}: "${row[at.part] ?? ""}" is not a part number`);
      const colour = String(row[at.colour] ?? "").trim();
      if (!/^-?[0-9]+$/.test(colour)) throw new Refusal(400, `${line}: the colour "${colour}" is not a Rebrickable colour number`);
      parts.push([part, Number(colour), quantity(row[at.qty], line)]);
    });
  } else {
    throw new Refusal(400, "line 1: neither a sets list (Set Number, Quantity) nor a parts list (Part, Color, Quantity)");
  }
  if (sets.length + parts.length === 0) throw new Refusal(400, "the file has a heading and nothing under it");
  return { sets, parts };
}

/// Yes in a spreadsheet's words: 1, true, yes, y, x.
const YES = /^(1|true|yes|y|x)$/i;

/// A Brickset export (My sets, as CSV): each set's number (Number, with its
/// Variant where Number has none), how many the person owns (QtyOwned, or
/// QtyOwnedNew and QtyOwnedUsed, or Own ticked: one) and whether they want
/// it (Want). Matched by its headings, never by place: Brickset's columns
/// moved twice since 2014 (docs/LISTS.md). OwnCount and WantCount are how
/// many people on Brickset own and want it, never this person's, and are
/// never read; nor SetID, Brickset's own row number. Returns {sets: [[set,
/// qty, false]] owned, wanted: [set]}; a row neither owned nor wanted is
/// left out. Anything else is refused with the line it went wrong on.
export function bricksetCsv(text) {
  const rows = csvRows(String(text || "").replace(/^﻿/, ""));
  if (rows.length === 0) throw new Refusal(400, "the file is empty");
  const headings = rows[0].map((h) => h.trim().toLowerCase().replace(/[\s_]+/g, ""));
  const at = (...names) => headings.findIndex((h) => names.includes(h));
  const number = at("number", "setnumber", "setno");
  const variant = at("variant");
  const qty = at("qtyowned");
  const fresh = at("qtyownednew");
  const used = at("qtyownedused");
  const own = at("own", "owned");
  const want = at("want", "wanted");
  if (number < 0) throw new Refusal(400, "line 1: no Number column — is this a Brickset export?");
  if (qty < 0 && fresh < 0 && used < 0 && own < 0 && want < 0) {
    throw new Refusal(400, "line 1: no QtyOwned, Own or Want column — is this a Brickset export of your sets?");
  }
  const whole = (raw, line) => {
    const said = String(raw ?? "").trim();
    if (said === "") return 0;
    if (!/^[0-9]+$/.test(said)) throw new Refusal(400, `${line}: the quantity "${said}" is not a whole number`);
    return Math.min(Number(said), MAX_QTY);
  };
  const sets = [];
  const wanted = [];
  rows.slice(1).forEach((row, n) => {
    const line = `line ${n + 2}`;
    let raw = String(row[number] ?? "").trim();
    const v = variant >= 0 ? String(row[variant] ?? "").trim() : "";
    if (raw && !/-[0-9]{1,3}$/.test(raw) && /^[0-9]{1,3}$/.test(v)) raw = `${raw}-${v}`;
    const set = setNumber(raw);
    if (!set) throw new Refusal(400, `${line}: "${raw}" is not a set number`);
    let owned = qty >= 0 ? whole(row[qty], line) : 0;
    if (!owned && (fresh >= 0 || used >= 0)) {
      owned = (fresh >= 0 ? whole(row[fresh], line) : 0) + (used >= 0 ? whole(row[used], line) : 0);
    }
    if (!owned && own >= 0 && YES.test(String(row[own] ?? "").trim())) owned = 1;
    if (owned) sets.push([set, Math.min(owned, MAX_QTY), false]);
    if (want >= 0 && YES.test(String(row[want] ?? "").trim())) wanted.push(set);
  });
  if (sets.length + wanted.length === 0) throw new Refusal(400, "the file lists no set you own or want");
  return { sets, parts: [], wanted: [...new Set(wanted)] };
}

function tag(block, name) {
  const found = new RegExp(`<${name}>\\s*([^<]*?)\\s*</${name}>`, "i").exec(block);
  return found ? found[1] : null;
}

/// A BrickLink XML: a wanted list (MINQTY) or an inventory upload (QTY),
/// in BrickLink's numbers. Parts and sets are kept; minifigures, books
/// and gear are counted and left out, since nothing here can say what is
/// in a BrickLink minifigure.
export function bricklinkXml(text) {
  const source = String(text || "");
  if (!/<INVENTORY>/i.test(source)) throw new Refusal(400, "not a BrickLink XML: there is no <INVENTORY>");
  const items = [...source.matchAll(/<ITEM>([\s\S]*?)<\/ITEM>/gi)].map((m) => m[1]);
  if (items.length === 0) throw new Refusal(400, "the BrickLink XML lists no <ITEM>");
  const sets = [];
  const parts = [];
  let otherKinds = 0;
  items.forEach((item, n) => {
    const line = `item ${n + 1}`;
    const type = (tag(item, "ITEMTYPE") || "").toUpperCase();
    const id = tag(item, "ITEMID");
    const qty = tag(item, "MINQTY") ?? tag(item, "QTY") ?? "1";
    if (type === "S") {
      const set = setNumber(id);
      if (!set) throw new Refusal(400, `${line}: "${id}" is not a set number`);
      sets.push([set, quantity(qty, line), false]);
    } else if (type === "P") {
      const part = partNumber(id);
      if (!part) throw new Refusal(400, `${line}: "${id}" is not a part number`);
      const colour = tag(item, "COLOR") ?? "0";
      if (!/^[0-9]+$/.test(colour.trim())) throw new Refusal(400, `${line}: the colour "${colour}" is not a BrickLink colour number`);
      parts.push([part, Number(colour), quantity(qty, line)]);
    } else {
      otherKinds++;
    }
  });
  return { sets, parts, otherKinds };
}

/// Set numbers typed or pasted: separated by commas, spaces or lines.
export function typedSets(text) {
  const words = String(text || "").split(/[\s,;]+/).filter(Boolean);
  if (words.length === 0) throw new Refusal(400, "no set number given");
  return {
    sets: words.map((word) => {
      const set = setNumber(word);
      if (!set) throw new Refusal(400, `"${word}" is not a set number`);
      return [set, 1, false];
    }),
    parts: [],
  };
}

/// Into LDraw numbers. Returns the lots kept and what was left out, by why.
function mapped(parsed, numbering, index) {
  const leftOut = {};
  const leave = (why, n = 1) => { leftOut[why] = (leftOut[why] || 0) + n; };
  const parts = [];
  for (const [rawPart, colour, qty] of parsed.parts) {
    let code;
    let part = rawPart;
    if (numbering === "bricklink") {
      code = index.bricklink.get(colour);
    } else {
      code = index.colours.get(colour);
      part = index.parts.get(rawPart) || rawPart;
    }
    if (code === undefined) {
      leave(numbering === "bricklink"
        ? "a BrickLink colour with no LDraw code here"
        : "a Rebrickable colour with no LDraw code (stickers, gear and [No Color] among them)", qty);
      continue;
    }
    parts.push({ part, colour: code, qty });
  }
  if (parsed.otherKinds) leave("BrickLink minifigures, books and gear, which are not expanded", parsed.otherKinds);
  const sets = parsed.sets.map(([set, qty, spares]) => ({ set, qty, spares: Boolean(spares) }));
  for (const [fig, qty, name] of parsed.figs || []) {
    sets.push(name ? { set: fig, qty, spares: false, fig: true, name } : { set: fig, qty, spares: false, fig: true });
  }
  return { sets, parts, leftOut };
}

// --- lots and sets, as kept ---------------------------------------------------

/// One lot per part, colour and where it came from: the person's own by
/// source, a session's by who and which chat. Keyed as a list, so no name
/// can be read as another's.
export function lotKey(p) {
  return JSON.stringify([p.part, p.colour, p.src || "", p.by || "", p.chat || ""]);
}

/// One set entry per set number and source.
export function setKey(s) {
  return JSON.stringify([s.set, s.src || ""]);
}

/// A session's name as a person reads it: any printable name, with control
/// characters, line breaks and the marks that turn text round made spaces,
/// spaces run together, trimmed, 60 characters at most. Collection.who_name
/// in the app is the same, so a lot the app marks is found by its name.
export function whoName(raw) {
  const text = String(raw ?? "")
    .replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029\u202a-\u202e\u2066-\u2069]/g, " ")
    .replace(/ {2,}/g, " ")
    .replace(/^ +| +$/g, "");
  return [...text].slice(0, 60).join("").replace(/ +$/, "");
}

/// An LDraw colour code as LDConfig has it: a whole number, never 16 (the
/// colour a part is placed in) or 24 (its edges), and never null, "",
/// false or a word, which Number() would have made Black.
export function colourOf(raw, where) {
  const text = typeof raw === "number" ? String(raw) : typeof raw === "string" ? raw.trim() : "";
  const code = /^[0-9]{1,9}$/.test(text) ? Number(text) : NaN;
  if (!Number.isInteger(code) || !Object.hasOwn(COLOUR_NAMES, code) || code === 16 || code === 24) {
    throw new Refusal(400, `${where}: the colour ${JSON.stringify(raw ?? null)} is not an LDraw colour code`);
  }
  return code;
}

/// A whole number from [least] to MAX_QTY, given as a number or its digits.
function counted(raw, where, least = 1, what = "count") {
  const text = typeof raw === "number" ? String(raw) : typeof raw === "string" ? raw.trim() : "";
  if (!/^[0-9]{1,9}$/.test(text)) {
    throw new Refusal(400, `${where}: the ${what} ${JSON.stringify(raw ?? null)} is not a whole number`);
  }
  const n = Number(text);
  if (n < least || n > MAX_QTY) throw new Refusal(400, `${where}: a ${what} of ${n} is outside ${least} to ${MAX_QTY}`);
  return n;
}

/// A lot as an op names it: its part, its LDraw colour, and whose it is:
/// where it came from (src; none for one kept before sources were), or
/// the session that added it (by, chat). [session] "must" refuses the
/// person's own.
export function lotId(p, where, session = "may") {
  const part = partNumber(p?.part);
  if (!part) throw new Refusal(400, `${where}: "${p?.part}" is not a part number`);
  const lot = { part, colour: colourOf(p?.colour, where) };
  if (p?.by !== undefined && p?.by !== null && typeof p.by !== "string") {
    throw new Refusal(400, `${where}: who added it is a name`);
  }
  const by = whoName(p?.by);
  if (!by && String(p?.by ?? "") !== "") throw new Refusal(400, `${where}: ${JSON.stringify(p.by)} is not a name`);
  const chat = p?.chat === undefined || p?.chat === null ? "" : String(p.chat).trim();
  const src = p?.src === undefined || p?.src === null ? "" : String(p.src);
  if (by) {
    if (src) throw new Refusal(400, `${where}: a lot a session added comes from that session, not from ${src}`);
    lot.by = by;
    if (chat) {
      if (!CHAT.test(chat)) throw new Refusal(400, `${where}: "${chat}" is not a chat`);
      lot.chat = chat;
    }
    return lot;
  }
  if (chat) throw new Refusal(400, `${where}: a chat is said only with who added the lot`);
  if (session === "must") {
    throw new Refusal(400, `${where}: only a lot a session added is taken down, kept or taken back this way`);
  }
  if (src) {
    if (!SOURCES.has(src)) throw new Refusal(400, `${where}: "${src}" is not where a lot comes from`);
    lot.src = src;
  }
  return lot;
}

function said(lot) {
  return `${lot.part} in colour ${lot.colour}${lot.by ? ` that ${lot.by} added` : ""}`;
}

/// Lots or sets by key, in their order; one added to the end when new. A
/// Map keeps the order it was given, and takes one out at once.
class Keyed {
  constructor(keyOf, list = []) {
    this.keyOf = keyOf;
    this.at = new Map();
    /// The lots a count went past MAX_QTY in: [{part, colour, over}].
    this.clamped = [];
    for (const one of list) this.keep({ ...one });
  }

  get list() {
    return [...this.at.values()];
  }

  keep(one) {
    if (this.at.has(this.keyOf(one))) return this.add(one, one.qty);
    this.at.set(this.keyOf(one), one);
    return one;
  }

  get(one) {
    return this.at.get(this.keyOf(one));
  }

  /// [qty] more of [one], made at the end if new; at most MAX_QTY, and a
  /// lot that would have held more noted in [clamped].
  add(one, qty) {
    const held = this.get(one);
    if (!held) return this.keep({ ...one, qty: Math.min(MAX_QTY, qty) });
    const sum = held.qty + qty;
    if (sum > MAX_QTY && one.part !== undefined) {
      this.clamped.push({ part: held.part, colour: held.colour, over: sum - MAX_QTY });
    }
    held.qty = Math.min(MAX_QTY, sum);
    if (one.spares) held.spares = true;
    return held;
  }

  take(one) {
    this.at.delete(this.keyOf(one));
  }
}

/// [done] with the lots [parts] kept at MAX_QTY, when there were any: the
/// first 50 named, and how many in all.
function withClamped(done, parts) {
  if (parts.clamped.length === 0) return done;
  return { ...done, clamped: parts.clamped.slice(0, 50), clamped_lots: parts.clamped.length };
}

/// [have] with an import added: each lot and set marked with [src]. In a
/// replace, what [src] brought before goes first: its sets when the import
/// has sets, its lots when it has parts. What was kept before sources were
/// (no src) goes too in a replace from a source there was then, as such a
/// replace always took everything (My collection says a fetch replaces
/// it); never in one from a source that came later (Brickset), which can
/// never have brought it (review of lists1: a Brickset replace took a set
/// kept before sources were). Nothing of another source's, the person's
/// own counting or a session's is touched. [books] is set number -> its inventory record (or
/// null, none known), for the sets whose marks a replace carries.
function merged(have, add, mode, src, books = new Map()) {
  const replaceSets = mode === "replace" && add.sets.length > 0;
  const replaceParts = mode === "replace" && add.parts.length > 0;
  const brought = (one) => !one.by && (one.src === src || (!one.src && BEFORE_SOURCES.has(src)));
  // A set typed by hand that Rebrickable's list has is that set, kept once.
  const fetched = new Set(replaceSets && src === REBRICKABLE ? add.sets.map((s) => s.set) : []);
  const sets = new Keyed(setKey, have.sets.filter((s) => !(replaceSets && brought(s))
    && !(s.src === HAND && fetched.has(s.set))));
  const parts = new Keyed(lotKey, have.parts.filter((p) => !(replaceParts && brought(p))));
  // A set a replace takes out and puts back keeps the parts marked missing
  // in it (mysets): the fetch says it is owned, not that it is whole.
  // Two entries of one set taken out (typed by hand, and Rebrickable's)
  // put their marks together on the one put back, as far as its copies
  // hold each part (lbcheck 6: a 1 + 1 spread was 2 on a copy of 1), a
  // part by the app's key whatever number and colour code each was marked
  // under (lb2check M1: 6141 and its old 4073 were capped apart).
  const marked = new Map();
  for (const s of have.sets) {
    if (!Array.isArray(s.missing) || !s.missing.length || sets.get(s)) continue;
    const both = new Keyed(lotKey, marked.get(s.set) || []);
    for (const p of s.missing) both.add({ ...p }, p.qty);
    marked.set(s.set, both.list);
  }
  const carried = [];
  for (const s of add.sets) {
    const held = sets.add({ ...s, src }, s.qty);
    if (!held.missing && marked.has(s.set)) {
      held.missing = marked.get(s.set);
      marked.delete(s.set);
      carried.push(held);
    }
  }
  // Taken out and not put back: gone, and its marks with it.
  const gone = [...marked].map(([set, lots]) => ({ set, marked: lots.reduce((n, p) => n + p.qty, 0) }));
  const unkept = [];
  const unread = [];
  for (const held of carried) {
    const record = books.get(held.set);
    // No inventory read: nothing to count the marks against, so they are
    // kept as they were. More marked than a copy holds loses nothing;
    // fewer would (lb2check L1).
    if (!record) {
      unread.push(held.set);
      continue;
    }
    const rows = rowsByKey(record);
    const others = sets.list.filter((s) => s.set === held.set && s !== held && !s.fig);
    const kept = [];
    for (const [key, lots] of byKey(held.missing)) {
      const spelled = rows.get(key);
      // A part its inventory does not list is kept as marked: the app lets
      // such a mark only come down.
      if (!spelled) {
        kept.push(...lots);
        continue;
      }
      const total = lots.reduce((n, p) => n + p.qty, 0);
      const here = Math.min(total, oneCopy(spelled) * copies(held));
      kept.push(...placed(lots, here, spelled, copies(held)));
      let over = total - here;
      // Over what this copy holds: onto the person's other copy of the set,
      // as far as it holds the part, else said.
      for (const other of others) {
        if (over === 0) break;
        const theirs = Array.isArray(other.missing) ? other.missing : [];
        const same = theirs.filter((p) => keyOf(p) === key);
        const now = same.reduce((n, p) => n + p.qty, 0);
        const put = Math.min(over, Math.max(0, oneCopy(spelled) * copies(other) - now));
        if (put <= 0) continue;
        other.missing = [...theirs.filter((p) => keyOf(p) !== key), ...placed(same, now + put, spelled, copies(other))];
        over -= put;
      }
      if (over > 0) unkept.push({ set: held.set, part: spelled[0].part, colour: spelled[0].colour, qty: over });
    }
    held.missing = kept;
    if (!held.missing.length) delete held.missing;
  }
  for (const p of add.parts) parts.add({ ...p, src }, p.qty);
  return { next: { sets: sets.list, parts: parts.list }, parts, unkept, unread, gone };
}

// A set's marks, counted as the app counts them. One rule, read from one
// set of facts: the app's edit_collection counts a copy by its inventory's
// rows of each key, summed (src/net/app_tools.gd, per_copy), a key being
// Collection.key_of (PartLibrary.resolve, PartLibrary.plain_code); here
// the same key from the same catalogue and colours (api/_owned.js
// ownedFacts: _part_facts.json beside the function in a deployment, which
// tools/package_api.sh puts there and checks).

/// A lot's key, as Collection.key_of: the number it means today and the
/// colour a shop files it under.
const keyOf = (p) => `${resolvePart(p.part)}/${plainColour(Number(p.colour))}`;
const copies = (entry) => Math.max(1, Number(entry.qty) || 1);

/// [lots] by [keyOf], in the order first marked: key -> lots.
function byKey(lots) {
  const out = new Map();
  for (const p of lots) out.set(keyOf(p), [...(out.get(keyOf(p)) || []), p]);
  return out;
}

/// One copy's rows of the inventory [record] by [keyOf]: key -> [{part,
/// colour, qty}], each spelling once with its rows summed, in the
/// inventory's order.
function rowsByKey(record) {
  const out = new Map();
  for (const row of Array.isArray(record?.p) ? record.p : []) {
    if (!Array.isArray(row) || row.length < 3) continue;
    const one = { part: String(row[0]), colour: Number(row[1]), qty: Number(row[2]) || 0 };
    const spelled = out.get(keyOf(one)) || [];
    const same = spelled.find((r) => r.part === one.part && r.colour === one.colour);
    if (same) same.qty += one.qty;
    else spelled.push(one);
    out.set(keyOf(one), spelled);
  }
  return out;
}

/// How many one copy holds of a key's rows [spelled].
const oneCopy = (spelled) => spelled.reduce((n, r) => n + r.qty, 0);

/// [total] of one key's marks [lots], at most what [times] copies hold,
/// written under its inventory's spellings [spelled], as edit_collection
/// writes a mark under the inventory's number (app_tools.gd _mark_writes):
/// a mark stays on its row when the inventory spells it so, as far as the
/// row holds, and the rest goes on the rows in the inventory's order, so
/// the set's page shows every one on a row of its own.
function placed(lots, total, spelled, times) {
  const rows = spelled.map((r) => ({ part: r.part, colour: r.colour, qty: 0, most: r.qty * times }));
  let left = total;
  for (const lot of lots) {
    const row = rows.find((r) => r.part === lot.part && r.colour === lot.colour);
    if (!row) continue;
    const put = Math.min(left, lot.qty, row.most - row.qty);
    row.qty += put;
    left -= put;
  }
  for (const row of rows) {
    const put = Math.min(left, row.most - row.qty);
    row.qty += put;
    left -= put;
  }
  return rows.filter((r) => r.qty > 0).map(({ part, colour, qty }) => ({ part, colour, qty }));
}

/// How long a fetch waits for the inventories it reads, all of them
/// together; any not read by then is unknown (lb2check L2: read one after
/// another at 15 s each, ~20 marked sets in other shards passed the
/// function's 300 s, and the fetch failed on every retry).
const READING_MS = 60000;

/// The inventories [books] needs for an import: of each set it lists that
/// a replace would take out marked (set number -> record, or null when
/// none is known or it was not read in time), each shard read once a
/// request, 16 at a time.
async function inventoriesFor(have, body, add, books, origin) {
  if (body?.mode !== "replace" || !add.sets.length) return;
  const listed = new Set(add.sets.map((s) => s.set));
  const wanted = [...new Set(have.sets.filter((s) => listed.has(s.set) && Array.isArray(s.missing) && s.missing.length
    && !books.has(s.set)).map((s) => s.set))];
  if (!wanted.length) return;
  const shards = [...new Set(wanted.map(shardOf))];
  const read = new Map();
  let next = 0;
  const reader = async () => {
    while (next < shards.length) {
      const n = shards[next++];
      read.set(n, await readShard(n, origin).catch(() => null));
    }
  };
  let timer;
  await Promise.race([Promise.all(Array.from({ length: Math.min(16, shards.length) }, reader)),
    new Promise((done) => { timer = setTimeout(done, READING_MS); })]);
  clearTimeout(timer);
  for (const set of wanted) books.set(set, read.get(shardOf(set))?.sets?.[set] || null);
}

function listed(body, field, most, where = field) {
  const list = body?.[field] === undefined ? [] : body[field];
  if (!Array.isArray(list)) throw new Refusal(400, `${where} is a list of lots`);
  if (list.length > most) throw new Refusal(413, `that is ${list.length} lots; one change is at most ${most}`);
  return list;
}

/// Lots named once each: an op that names one twice is refused.
function once(ids, where) {
  const seen = new Set();
  ids.forEach((id, n) => {
    const key = lotKey(id);
    if (seen.has(key)) throw new Refusal(400, `${where} ${n + 1}: ${said(id)} is named twice`);
    seen.add(key);
  });
}

/// [have] changed by one op: {next: {sets, parts} or null for no change,
/// done: what was done}. Refuses with words (400, 413) or, when what the
/// person saw is no longer so, a Conflict carrying [have]; either way
/// nothing is changed. Pure: made again on a fresh [have] when another
/// write came first.
export function applyOp(have, body) {
  const op = String(body?.op || "");
  const parts = new Keyed(lotKey, have.parts);
  const sets = new Keyed(setKey, have.sets);
  const next = () => ({ sets: sets.list, parts: parts.list });

  if (op === "lots") {
    const adding = listed(body, "add", MOST_LOT_CHANGES);
    const removing = listed(body, "remove", MOST_LOT_CHANGES);
    if (adding.length + removing.length === 0) throw new Refusal(400, "no lots to add or take off");
    if (adding.length + removing.length > MOST_LOT_CHANGES) {
      throw new Refusal(413, `that is ${adding.length + removing.length} lots; one change is at most ${MOST_LOT_CHANGES}`);
    }
    const adds = adding.map((p, n) => {
      const id = lotId(p, `add ${n + 1}`);
      if (!id.by) {
        if (id.src && id.src !== HAND) throw new Refusal(400, `add ${n + 1}: a lot added here is the person's own (hand)`);
        id.src = HAND;
      }
      return [id, counted(p?.qty, `add ${n + 1}`)];
    });
    const removes = removing.map((p, n) => [lotId(p, `remove ${n + 1}`, "must"),
      p?.qty === undefined || p?.qty === null ? 0 : counted(p.qty, `remove ${n + 1}`, 0),
      counted(p?.was, `remove ${n + 1}`, 1, "count seen")]);
    // Each lot as the session saw it, before any of this call's removes.
    removes.forEach(([id, , was], n) => {
      const held = parts.get(id);
      if (!held) {
        throw new Conflict(`remove ${n + 1}: ${id.part} in colour ${id.colour} is not a lot ${id.by} added`
          + `${id.chat ? " in this chat" : ""} (the person may have kept it or taken it back)`, have);
      }
      if (held.qty !== was) throw new Conflict(`remove ${n + 1}: ${said(id)} is ${held.qty} now, not the ${was} seen`, have);
    });
    // A lot taken down all the way by one remove is not missing for the next.
    for (const [id, qty] of removes) {
      const held = parts.get(id);
      if (!held) continue;
      if (qty === 0 || qty >= held.qty) parts.take(id);
      else held.qty -= qty;
    }
    for (const [id, qty] of adds) parts.add(id, qty);
    return { next: next(), done: withClamped({ added: adds.length, taken_down: removes.length }, parts) };
  }

  if (op === "set") {
    const changes = listed(body, "lots", MOST_LOT_CHANGES);
    if (changes.length === 0) throw new Refusal(400, "no lots to set");
    const ids = changes.map((p, n) => lotId(p, `lot ${n + 1}`));
    once(ids, "lot");
    const counts = changes.map((p, n) => [counted(p?.was, `lot ${n + 1}`, 1, "count seen"),
      counted(p?.qty, `lot ${n + 1}`, 0)]);
    ids.forEach((id, n) => {
      const held = parts.get(id);
      if (!held) throw new Conflict(`lot ${n + 1}: ${said(id)} is not there any more`, have);
      if (held.qty !== counts[n][0]) {
        throw new Conflict(`lot ${n + 1}: ${said(id)} is ${held.qty} now, not the ${counts[n][0]} shown`, have);
      }
    });
    ids.forEach((id, n) => {
      if (counts[n][1] === 0) parts.take(id);
      else parts.get(id).qty = counts[n][1];
    });
    return { next: next(), done: { set: ids.length } };
  }

  if (op === "keep" || op === "take_back") {
    const named = listed(body, "lots", MAX_LOTS);
    if (named.length === 0) throw new Refusal(400, "no lots named");
    const ids = named.map((p, n) => lotId(p, `lot ${n + 1}`, "must"));
    once(ids, "lot");
    const was = named.map((p, n) => counted(p?.was, `lot ${n + 1}`, 1, "count seen"));
    ids.forEach((id, n) => {
      const held = parts.get(id);
      if (!held) throw new Conflict(`lot ${n + 1}: ${said(id)} is not there any more`, have);
      if (held.qty !== was[n]) throw new Conflict(`lot ${n + 1}: ${said(id)} is ${held.qty} now, not the ${was[n]} shown`, have);
    });
    ids.forEach((id, n) => {
      parts.take(id);
      if (op === "keep") parts.add({ part: id.part, colour: id.colour, src: HAND }, was[n]);
    });
    return { next: next(), done: withClamped({ [op === "keep" ? "kept" : "taken_back"]: ids.length }, parts) };
  }

  if (op === "remove_set") {
    // A minifigure by its own number (mysets); an older app, which knows
    // no figures, names one as it was kept, and is found by it too.
    const fig = figNumber(body?.set);
    const set = body?.fig === true ? fig : setNumber(body?.set);
    if (!set) throw new Refusal(400, `"${body?.set}" is not a set number`);
    const src = body?.src === undefined || body?.src === null ? "" : String(body.src);
    if (src && !SOURCES.has(src)) throw new Refusal(400, `"${src}" is not where a set comes from`);
    const was = counted(body?.was, set, 1, "count seen");
    let id = src ? { set, src } : { set };
    if (!sets.get(id) && fig && body?.fig !== true) {
      const asFig = src ? { set: fig, src } : { set: fig };
      if (sets.get(asFig)?.fig === true) id = asFig;
    }
    const held = sets.get(id);
    // Taken out already, elsewhere: what the person asked for is so.
    if (!held) return { next: null, done: { removed_sets: 0 } };
    if (held.qty !== was) throw new Conflict(`${set} is ${held.qty} now, not the ${was} shown`, have);
    sets.take(id);
    return { next: next(), done: { removed_sets: 1 } };
  }

  if (op === "own") {
    // How many of a set the person owns, from the count they saw ("was",
    // every copy of it from anywhere, 0 for none) to qty (0: none): the
    // website's one tap, Own and its count (lists1, docs/LISTS.md). More is
    // added to their own copy (src "hand"); fewer comes off their own copy
    // first, then off the other sources', the last kept first, a copy that
    // goes taking its marks with it as remove_set's does. A figure is never
    // one of its copies: a figure's number is never a set's.
    const set = setNumber(body?.set);
    if (!set) throw new Refusal(400, `"${body?.set}" is not a set number`);
    const was = counted(body?.was, set, 0, "count seen");
    const qty = counted(body?.qty, set, 0);
    const copiesOf = () => sets.list.filter((s) => s.set === set && !s.fig);
    const now = copiesOf().reduce((sum, s) => sum + (Number(s.qty) || 0), 0);
    if (now !== was) throw new Conflict(`${set} is ${now} now, not the ${was} shown`, have);
    if (qty === now) return { next: null, done: { owned: now } };
    if (qty > now) {
      // Back to a count an Own took it down from, with nothing changed
      // since: the copies as they were, their source and their marks
      // (review of lists1: an Undo made a bare copy of the person's own,
      // and "my bricks" counted the parts marked missing as owned).
      // Put back once: the record is spent with this change (change()).
      const away = putAway(have.recent, set, copiesOf(), qty);
      if (away) {
        for (const held of copiesOf()) sets.take(held);
        for (const one of away.before) sets.keep(structuredClone(one));
      } else {
        sets.add({ set, qty: qty - now, spares: false, src: HAND }, qty - now);
      }
      return { next: next(), done: { owned: qty, ...(away ? { spent: away.id } : {}) } };
    }
    const before = structuredClone(copiesOf());
    let off = now - qty;
    // Their own copy first, then the others from the last kept back.
    const copies = copiesOf();
    for (const held of [...copies.filter((s) => s.src === HAND), ...copies.filter((s) => s.src !== HAND).reverse()]) {
      if (off === 0) break;
      const take = Math.min(off, held.qty);
      if (take >= held.qty) sets.take(held);
      else held.qty -= take;
      off -= take;
    }
    // What it took down from, remembered with the change (never sent):
    // an Own back to that count puts these back.
    const away = { set, before, after: structuredClone(copiesOf()) };
    return { next: next(), done: { owned: qty, ...(JSON.stringify(away).length <= MOST_AWAY_BYTES ? { away } : {}) } };
  }

  if (op === "missing") {
    const set = setNumber(body?.set);
    if (!set) throw new Refusal(400, `"${body?.set}" is not a set number`);
    const src = body?.src === undefined || body?.src === null ? "" : String(body.src);
    if (src && !SOURCES.has(src)) throw new Refusal(400, `"${src}" is not where a set comes from`);
    const changes = listed(body, "lots", MOST_LOT_CHANGES);
    if (changes.length === 0) throw new Refusal(400, "no lots to mark");
    const ids = changes.map((p, n) => {
      const part = partNumber(p?.part);
      if (!part) throw new Refusal(400, `lot ${n + 1}: "${p?.part}" is not a part number`);
      return { part, colour: colourOf(p?.colour, `lot ${n + 1}`) };
    });
    once(ids, "lot");
    const counts = changes.map((p, n) => [counted(p?.was, `lot ${n + 1}`, 0, "count seen"),
      counted(p?.qty, `lot ${n + 1}`, 0)]);
    const held = sets.get(src ? { set, src } : { set });
    if (!held || held.fig) throw new Conflict(`${set} is not in your collection any more`, have);
    const missing = new Keyed(lotKey, Array.isArray(held.missing) ? held.missing : []);
    ids.forEach((id, n) => {
      const now = missing.get(id)?.qty || 0;
      if (now !== counts[n][0]) {
        throw new Conflict(`lot ${n + 1}: ${id.part} in colour ${id.colour} is ${now} missing now, not the ${counts[n][0]} shown`, have);
      }
    });
    ids.forEach((id, n) => {
      if (counts[n][1] === 0) missing.take(id);
      else if (missing.get(id)) missing.get(id).qty = counts[n][1];
      else missing.keep({ ...id, qty: counts[n][1] });
    });
    if (missing.list.length > MOST_MISSING) {
      throw new Refusal(413, `that marks ${missing.list.length} lots missing; a set is at most ${MOST_MISSING}`);
    }
    if (missing.list.length) held.missing = missing.list;
    else delete held.missing;
    return { next: next(), done: { marked: ids.length, missing: missing.list.reduce((sum, p) => sum + p.qty, 0) } };
  }

  if (op === "start_over") {
    const seen = body?.rev === undefined || body?.rev === null ? null : Number(body.rev);
    const now = have.rev === undefined || have.rev === null ? null : Number(have.rev);
    if (seen !== now) throw new Conflict("your collection changed since it was shown; here it is now", have);
    if (have.sets.length + have.parts.length === 0) return { next: null, done: {} };
    return { next: { sets: [], parts: [] }, done: { started_over: true } };
  }

  throw new Refusal(400, "say what this is: op lots, set, keep, take_back, remove_set, own, missing or start_over, "
    + "or from rebrickable_csv, bricklink_xml, brickset_csv, rebrickable_api, sets or figs");
}

/// A set's copies as text that is the same however a database kept them
/// (jsonb keeps an object's keys in an order of its own).
function sameCopies(list) {
  const plain = (value) => (Array.isArray(value) ? value.map(plain)
    : value && typeof value === "object" ? Object.fromEntries(Object.keys(value).sort().map((key) => [key, plain(value[key])]))
      : value);
  return JSON.stringify(plain(list));
}

/// The copies of [set] an Own took down from, to put back when an Own goes
/// back up to that count ([qty]) from the copies it left ([now], exactly):
/// the latest such change the row remembers, as {before, id} (the id of
/// the change that remembers it), else null.
function putAway(recent, set, now, qty) {
  const left = sameCopies(now);
  for (const one of [...recent].reverse()) {
    const away = one?.done?.away;
    if (!away || away.set !== set || !Array.isArray(away.before) || !Array.isArray(away.after)) continue;
    const had = away.before.reduce((sum, s) => sum + (Number(s?.qty) || 0), 0);
    if (had === qty && sameCopies(away.after) === left) return { before: away.before, id: idOf(one) };
  }
  return null;
}

/// [recent] as a change leaves it: [done] remembered under [id], and the
/// copies an Own put back ([done].spent) forgotten, so they come back once.
function remembered(recent, id, done) {
  let list = id ? [...recent.filter((one) => idOf(one) !== id), { id, done }].slice(-MOST_REMEMBERED) : recent;
  if (done?.spent) {
    list = list.map((one) => {
      if (idOf(one) !== done.spent || !one?.done?.away) return one;
      const { away, ...rest } = one.done;
      return { ...one, done: rest };
    });
  }
  return keptAway(list);
}

/// [recent] with what Owns took down from kept on the newest MOST_AWAY of
/// them only, so the row stays small.
function keptAway(recent) {
  let kept = 0;
  return [...recent].reverse().map((one) => {
    if (!one?.done?.away) return one;
    kept += 1;
    if (kept <= MOST_AWAY) return one;
    const { away, ...done } = one.done;
    return { ...one, done };
  }).reverse();
}

/// An import, as a change: {next, done}. What it imported and left out is
/// in [done], so a resend is told the same.
function importing(have, body, imported, books = new Map()) {
  const mode = body?.mode === "replace" ? "replace" : "add";
  const { next, parts, unkept, unread, gone } = merged(have, imported, mode, SOURCE_OF[String(body.from)], books);
  return {
    next,
    done: withClamped({
      imported: { sets: imported.sets.length, lots: imported.parts.length },
      left_out: Object.entries(imported.leftOut).map(([why, count]) => ({ why, count })),
      // Marks more than the copies kept hold, and not carried to another;
      // the sets whose marks were kept as they were, their inventories not
      // read; and the sets that went with their marks: the first 50 of
      // each, and how many in all.
      ...(unkept.length ? { unkept: unkept.slice(0, 50), unkept_lots: unkept.length } : {}),
      ...(unread.length ? { unread: unread.slice(0, 50), unread_sets: unread.length } : {}),
      ...(gone.length ? { gone: gone.slice(0, 50), gone_sets: gone.length } : {}),
    }, parts),
  };
}

/// An older app's PUT (rel-m267 and before), made as remove_set when it is
/// the collection as kept with one set number gone, every lot as kept:
/// such an app takes a set out by filtering its whole copy and sending it.
/// Anything else is refused with UPDATE_WORDS, changing nothing.
export function olderRemoval(have, body) {
  const refuse = () => { throw new Conflict(UPDATE_WORDS, have); };
  if (!Array.isArray(body?.sets) || !Array.isArray(body?.parts)) refuse();
  const setOf = (s) => JSON.stringify([String(s?.set ?? ""), Number(s?.qty), Boolean(s?.spares)]);
  const tally = (list, keyOf, qtyOf = () => 1) => {
    const out = new Map();
    for (const one of list) out.set(keyOf(one), (out.get(keyOf(one)) || 0) + qtyOf(one));
    return out;
  };
  const same = (a, b) => a.size === b.size && [...a].every(([key, n]) => b.get(key) === n);
  const sent = new Set(body.sets.map((s) => String(s?.set ?? "")));
  const gone = [...new Set(have.sets.map((s) => s.set))].filter((set) => !sent.has(set));
  if (gone.length !== 1) refuse();
  if (!same(tally(body.sets, setOf), tally(have.sets.filter((s) => s.set !== gone[0]), setOf))) refuse();
  const lot = (p) => JSON.stringify([String(p?.part ?? ""), Number(p?.colour)]);
  if (!same(tally(body.parts, lot, (p) => Number(p?.qty)), tally(have.parts, lot, (p) => p.qty))) refuse();
  const taken = have.sets.filter((s) => s.set === gone[0]).length;
  return { next: { sets: have.sets.filter((s) => s.set !== gone[0]), parts: have.parts },
    done: { removed_sets: taken, set: gone[0] } };
}

// --- imports ----------------------------------------------------------------------

/// An import, parsed and mapped. Exported for the probe, which checks the
/// parsing without a database.
export function parseImport(body) {
  const from = String(body?.from || "");
  const index = joins();
  let parsed;
  let numbering = "rebrickable";
  if (from === "rebrickable_csv") parsed = rebrickableCsv(body.text);
  else if (from === "bricklink_xml") { parsed = bricklinkXml(body.text); numbering = "bricklink"; }
  else if (from === "brickset_csv") parsed = bricksetCsv(body.text);
  else if (from === "sets") parsed = typedSets(body.text);
  else if (from === "figs") parsed = { sets: [], parts: [], figs: typedFigs(body.figs) };
  else if (from === "rebrickable_api") {
    const sets = (Array.isArray(body.sets) ? body.sets : []).map((s, n) => {
      const set = setNumber(s?.[0]);
      if (!set) throw new Refusal(400, `set ${n + 1}: "${s?.[0]}" is not a set number`);
      return [set, quantity(s?.[1], `set ${n + 1}`), Boolean(s?.[2])];
    });
    const parts = (Array.isArray(body.parts) ? body.parts : []).map((p, n) => {
      const part = partNumber(p?.[0]);
      if (!part) throw new Refusal(400, `part ${n + 1}: "${p?.[0]}" is not a part number`);
      if (!Number.isInteger(p?.[1])) throw new Refusal(400, `part ${n + 1}: no colour`);
      return [part, p[1], quantity(p?.[2], `part ${n + 1}`)];
    });
    if (sets.length + parts.length === 0) throw new Refusal(400, "Rebrickable sent back no sets and no parts");
    parsed = { sets, parts };
  } else {
    throw new Refusal(400, "say what this is: from rebrickable_csv, bricklink_xml, brickset_csv, rebrickable_api, sets or figs");
  }
  const made = mapped(parsed, numbering, index);
  // The sets a Brickset export marks wanted: not owned, so not kept here,
  // but said back, for the website to put in the wishlist (api/_mylists.js).
  if (parsed.wanted) made.wanted = parsed.wanted;
  return made;
}

function within(collection) {
  if (collection.sets.length > MAX_SETS) {
    throw new Refusal(413, `that makes ${collection.sets.length} different sets; a collection holds ${MAX_SETS}`);
  }
  if (collection.parts.length > MAX_LOTS) {
    throw new Refusal(413, `that makes ${collection.parts.length} lots of loose parts; a collection holds ${MAX_LOTS}`);
  }
}

// --- the row ----------------------------------------------------------------------

/// The row as kept, or an empty one ("there": false) when there is none.
async function readRow(owner) {
  const rows = await db(`collections?owner=eq.${owner}&select=sets,parts,updated_at,rev,recent`);
  const row = rows && rows[0];
  if (!row) return { there: false, sets: [], parts: [], updated_at: null, rev: null, recent: [] };
  return {
    there: true,
    sets: Array.isArray(row.sets) ? row.sets : [],
    parts: Array.isArray(row.parts) ? row.parts : [],
    updated_at: row.updated_at ?? null,
    rev: row.rev ?? null,
    recent: Array.isArray(row.recent) ? row.recent : [],
  };
}

/// What the app is sent of a row: never the request ids.
function shown(row) {
  return { sets: row.sets || [], parts: row.parts || [], updated_at: row.updated_at ?? null, rev: row.rev ?? null };
}

/// A remembered change's id: an entry is {id, done}.
const idOf = (one) => (typeof one === "string" ? one : one?.id);

const pause = (attempt) => new Promise((done) => setTimeout(done, 15 + Math.random() * 40 * (attempt + 1)));

/// [make] made on the row as kept and written only over that row: the rev
/// it was made on is the PATCH's condition (a new row's, that there is
/// none). When another write came first, nothing is written, and it is
/// made again on what that one left. [id], when given, is remembered with
/// the write, and a change whose id is remembered is not made again.
/// Returns {row, done}; throws what [make] refuses. [make] may be async (an
/// import reads the inventories of the sets whose marks it carries).
async function change(owner, make, id = "") {
  for (let attempt = 0; attempt < TRIES; attempt++) {
    const have = await readRow(owner);
    const before = id ? have.recent.find((one) => idOf(one) === id) : undefined;
    if (before !== undefined) return { row: have, done: { ...(before?.done || {}), again: true } };
    const made = await make(have);
    // A change that changes nothing is remembered too, where there is a
    // row to keep it in, so a resend is told what the first was.
    if (!made.next && !(id && have.there)) return { row: have, done: made.done };
    const next = made.next || { sets: have.sets, parts: have.parts };
    within(next);
    // What an Own took down is remembered though its caller gave no id, so
    // an Own back to that count puts those very copies back.
    const remember = id || (made.done?.away ? `own-${randomUUID()}` : "");
    const kept = {
      sets: next.sets,
      parts: next.parts,
      recent: remember || made.done?.spent ? remembered(have.recent, remember, made.done) : have.recent,
      updated_at: new Date().toISOString(),
    };
    let saved = null;
    if (have.there) {
      const held = have.rev === null ? "is.null" : `eq.${have.rev}`;
      const rows = await db(`collections?owner=eq.${owner}&rev=${held}`,
        { method: "PATCH", prefer: "return=representation", body: kept });
      saved = rows && rows[0];
    } else {
      try {
        const rows = await db("collections", { method: "POST", prefer: "return=representation", body: [{ owner, ...kept }] });
        saved = rows && rows[0];
      } catch (error) {
        // Made by another write since it was read: read again.
        if (!/: 409$/.test(String(error?.message))) throw error;
      }
    }
    if (saved) return { row: saved, done: made.done };
    await pause(attempt);
  }
  throw new Refusal(503, "your collection was being changed from elsewhere at that moment, so nothing was changed: "
    + "try again");
}

/// How many of the set [raw] names [row] holds, every copy from anywhere
/// (a figure is never one): what an Own's 409 says.
export function ownedOf(row, raw) {
  const set = setNumber(raw);
  if (!set) return 0;
  return (Array.isArray(row?.sets) ? row.sets : []).filter((s) => s && !s.fig && s.set === set)
    .reduce((sum, s) => sum + (Number(s.qty) || 0), 0);
}

function bodyOf(request) {
  try {
    const body = request.body;
    return typeof body === "string" ? JSON.parse(body) : body;
  } catch {
    throw new Refusal(400, "the request is not JSON");
  }
}

/// What an older app's PUT is told when its copy is not the collection as
/// kept: taking a set out from it could bring back or drop what another
/// device changed since.
export const UPDATE_WORDS = "This copy of Brickworks read your collection before it last changed (on another "
  + "device, or by an assistant), so taking the set out from it could undo that, and nothing was changed. Update "
  + "Brickworks (on the web, reload the page), then take the set out again.";

export default async function handler(request, response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
      .end();
  }
  // Somebody's own things: never kept by anything in between.
  response.setHeader("Cache-Control", "private, no-store");

  // The set an Own asks about: its 409 says that set's count alone.
  let owning = null;
  try {
    if (!authConfigured() || !dbConfigured()) throw new Refusal(503, "accounts are not configured here");
    let claims;
    try {
      claims = await verify(bearer(request), request);
    } catch (error) {
      throw new Refusal(error instanceof AuthError ? error.status : 401, error.message);
    }
    const owner = claims.sub;
    if (!/^[0-9a-f-]{36}$/i.test(owner)) throw new Refusal(401, "that sign-in names nobody");

    // There is no way to name an account here. One that tries is asking
    // for somebody else's, and is told so rather than silently given its
    // own, which would read as "theirs is empty".
    const query = request.query || {};
    for (const key of ["owner", "user", "user_id", "account", "id"]) {
      if (query[key] !== undefined && String(query[key]) !== owner) {
        throw new Refusal(403, "a collection is only ever its owner's");
      }
    }

    const declared = Number(request.headers?.["content-length"] || 0);
    if (declared > MAX_KEEP_BYTES) throw new Refusal(413, `that is ${declared} bytes; a change is at most ${MAX_KEEP_BYTES}`);

    if (request.method === "GET") {
      return response.status(200).json(shown(await readRow(owner)));
    }
    if (request.method === "DELETE") {
      // An older app's Start over, asked first there: everything out, the
      // row kept with the ids it remembers.
      const { row } = await change(owner, (have) => ({
        next: have.sets.length + have.parts.length ? { sets: [], parts: [] } : null, done: {},
      }));
      return response.status(200).json(shown(row));
    }
    if (request.method !== "POST" && request.method !== "PUT") {
      throw new Refusal(405, "GET, POST or DELETE");
    }

    const body = bodyOf(request);
    if (body?.op === "own") owning = body.set;
    if (body && body.owner !== undefined && String(body.owner) !== owner) {
      throw new Refusal(403, "a collection is only ever its owner's");
    }
    const size = JSON.stringify(body ?? null).length;
    const most = ["keep", "take_back"].includes(body?.op) ? MAX_KEEP_BYTES : MAX_BYTES;
    if (size > most) {
      throw new Refusal(413, `that is ${size} bytes; ${body?.op ? "a change" : "an import"} is at most ${most}`);
    }

    if (request.method === "PUT") {
      const { row, done } = await change(owner, (have) => olderRemoval(have, body));
      return response.status(200).json({ ...shown(row), done });
    }

    const id = body?.id === undefined || body?.id === null ? "" : String(body.id);
    if (id && !REQUEST.test(id)) throw new Refusal(400, `"${id.slice(0, 80)}" is not a request id`);
    if (body?.op !== undefined) {
      // A change of lots adds and takes down: said again as it was, it is
      // never made twice, so it says which it is.
      if (body.op === "lots" && !id) throw new Refusal(400, "a change of lots says its id");
      const { row, done } = await change(owner, (have) => applyOp(have, body), id);
      if (body.op === "own") {
        const { away, spent, ...said } = done;
        return response.status(200).json({ done: said, rev: row.rev ?? null });
      }
      return response.status(200).json({ ...shown(row), done });
    }
    if (!Object.hasOwn(SOURCE_OF, String(body?.from || ""))) {
      throw new Refusal(400, "say what this is: from rebrickable_csv, bricklink_xml, brickset_csv, rebrickable_api, sets or "
        + "figs, or op lots, set, keep, take_back, remove_set, own, missing or start_over");
    }
    const imported = parseImport(body);
    const books = new Map();
    const { row, done } = await change(owner, async (have) => {
      await inventoriesFor(have, body, imported, books, originOf(request));
      return importing(have, body, imported, books);
    }, id);
    return response.status(200).json({ ...shown(row), done, imported: done.imported, left_out: done.left_out || [],
      ...(imported.wanted ? { wanted: imported.wanted } : {}) });
  } catch (error) {
    if (error instanceof Conflict && owning !== null) {
      return response.status(409).json({ error: error.message, owned: ownedOf(error.row, owning) });
    }
    if (error instanceof Conflict) return response.status(409).json({ error: error.message, ...shown(error.row) });
    if (error instanceof Refusal) return response.status(error.status).json({ error: error.message });
    // A database failure names the table and the status and nothing else.
    return response.status(502).json({ error: String(error.message || error).slice(0, 200) });
  }
}
