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
//   {"from": "sets", "text": "10237-1, 6020"}          typed by number
//
// Every lot and set keeps where it came from ("src"): "hand" (added in My
// collection, a set typed by number), "rebrickable", "rebrickable_csv" or
// "bricklink_xml"; a lot a session added says who instead ("by", the name
// the session goes by, "Claude") and which of its chats ("chat"). Each is
// its own lot, apart from the same part and colour from anywhere else, so
// "replace" (a Rebrickable fetch) replaces only what that source brought
// before: a sets list its sets, a parts list its lots. What was kept before
// sources were (no src, no by) came from imports, and a replace takes it as
// it always did; a lot counted by hand or a session's is never touched by
// an import.
//
// Ops, each with an "id" the app makes per action and sends again as it was
// when the network fails: an id already applied is not applied again.
//
//   {"op": "lots", "add": [{part, colour, qty, by?, chat?}],
//                  "remove": [{part, colour, qty?, by, chat?}]}
//       added to the lot (made if new: the person's own, src "hand", or the
//       session's); a session's own lot taken down by qty (all of it when
//       qty is 0 or none), never below none. Several removes of one lot add
//       up. Only a session's lots are taken down this way.
//   {"op": "set", "lots": [{part, colour, src?, by?, chat?, was, qty}]}
//       each lot from the count the person saw ("was") to qty (0 takes it
//       out)
//   {"op": "keep", "lots": [{part, colour, by, chat?, was}]}
//       a session's lots, at the counts the person saw, made their own
//   {"op": "take_back", "lots": [{part, colour, by, chat?, was}]}
//       a session's lots, at the counts the person saw, taken out
//   {"op": "remove_set", "set": "6020-1", "src"?, "was": 1}
//       a set, at the count the person saw, taken out
//   {"op": "start_over", "rev": <the rev the person saw>}
//
// What was seen and is no longer so (a count moved on, a lot gone, the rev
// moved on) is refused with 409 and the collection as it is now, changing
// nothing: the app shows it and the person asks again.
//
// An older app (rel-m266, desktop 0.17.0) takes a set out by PUT of its
// whole copy, which says nothing of when it was read: a copy read before
// another device took a set out and added another names the one added as
// the one to take out. So a PUT is refused with 409 and words that say to
// update, changing nothing; its imports and its DELETE are ops as above.
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

import { existsSync, readFileSync } from "node:fs";
import { AuthError, authConfigured, bearer, verify } from "./_auth.js";
import { COLOUR_NAMES } from "./_colours.js";
import { db, dbConfigured } from "./_db.js";

export const MAX_BYTES = 1_000_000;
/// Keep them and Take back name every lot a session added, up to MAX_LOTS.
export const MAX_KEEP_BYTES = 4_000_000;
export const MAX_SETS = 5000;
export const MAX_LOTS = 20000;
const MAX_QTY = 100000;

const SET_NUMBER = /^[a-z0-9][a-z0-9._]{0,24}(-[0-9]{1,3})?$/;
const PART_NUMBER = /^[a-z0-9][a-z0-9._-]{0,40}$/;
/// Which of a session's chats added a lot: an id.
const CHAT = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,99}$/;
/// A request's id: the app's, one per action.
const REQUEST = /^[A-Za-z0-9._:-]{8,64}$/;
/// The most lots one "lots" or "set" op changes.
export const MOST_LOT_CHANGES = 2000;
/// How many request ids a collection remembers.
export const MOST_REMEMBERED = 100;
/// How many times a change is made again on what another write left.
const TRIES = 12;

/// Where each import's lots and sets come from; "hand" is My collection's.
export const HAND = "hand";
export const SOURCE_OF = {
  sets: HAND, rebrickable_api: "rebrickable", rebrickable_csv: "rebrickable_csv", bricklink_xml: "bricklink_xml",
};
const SOURCES = new Set(Object.values(SOURCE_OF));

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

/// Lots or sets by key, in their order; one added to the end when new.
class Keyed {
  constructor(keyOf, list = []) {
    this.keyOf = keyOf;
    this.list = [];
    this.at = new Map();
    for (const one of list) this.keep({ ...one });
  }

  keep(one) {
    const key = this.keyOf(one);
    if (this.at.has(key)) return this.add(one, one.qty);
    this.at.set(key, one);
    this.list.push(one);
    return one;
  }

  get(one) {
    return this.at.get(this.keyOf(one));
  }

  /// [qty] more of [one], made at the end if new.
  add(one, qty) {
    const held = this.get(one);
    if (held) {
      held.qty = Math.min(MAX_QTY, held.qty + qty);
      if (one.spares) held.spares = true;
      return held;
    }
    return this.keep({ ...one, qty });
  }

  take(one) {
    const held = this.get(one);
    if (!held) return;
    this.at.delete(this.keyOf(one));
    this.list = this.list.filter((other) => other !== held);
  }
}

/// [have] with an import added: each lot and set marked with [src]. In a
/// replace, what [src] brought before (and what was kept before sources
/// were) goes first: its sets when the import has sets, its lots when it
/// has parts. Nothing of another source's, the person's own counting or a
/// session's is touched.
function merged(have, add, mode, src) {
  const replaceSets = mode === "replace" && add.sets.length > 0;
  const replaceParts = mode === "replace" && add.parts.length > 0;
  const brought = (one) => !one.by && (one.src === src || !one.src);
  const sets = new Keyed(setKey, have.sets.filter((s) => !(replaceSets && brought(s))));
  const parts = new Keyed(lotKey, have.parts.filter((p) => !(replaceParts && brought(p))));
  for (const s of add.sets) sets.add({ ...s, src }, s.qty);
  for (const p of add.parts) parts.add({ ...p, src }, p.qty);
  return { sets: sets.list, parts: parts.list };
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
      p?.qty === undefined || p?.qty === null ? 0 : counted(p.qty, `remove ${n + 1}`, 0)]);
    // A lot taken down all the way by one remove is not missing for the next.
    const gone = new Set();
    removes.forEach(([id, qty], n) => {
      const held = parts.get(id);
      if (!held) {
        if (gone.has(lotKey(id))) return;
        throw new Conflict(`remove ${n + 1}: ${id.part} in colour ${id.colour} is not a lot ${id.by} added`
          + `${id.chat ? " in this chat" : ""} (the person may have kept it or taken it back)`, have);
      }
      if (qty === 0 || qty >= held.qty) {
        parts.take(id);
        gone.add(lotKey(id));
      } else {
        held.qty -= qty;
      }
    });
    for (const [id, qty] of adds) parts.add(id, qty);
    return { next: next(), done: { added: adds.length, taken_down: removes.length } };
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
    return { next: next(), done: { [op === "keep" ? "kept" : "taken_back"]: ids.length } };
  }

  if (op === "remove_set") {
    const set = setNumber(body?.set);
    if (!set) throw new Refusal(400, `"${body?.set}" is not a set number`);
    const src = body?.src === undefined || body?.src === null ? "" : String(body.src);
    if (src && !SOURCES.has(src)) throw new Refusal(400, `"${src}" is not where a set comes from`);
    const was = counted(body?.was, set, 1, "count seen");
    const id = src ? { set, src } : { set };
    const held = sets.get(id);
    // Taken out already, elsewhere: what the person asked for is so.
    if (!held) return { next: null, done: { removed_sets: 0 } };
    if (held.qty !== was) throw new Conflict(`${set} is ${held.qty} now, not the ${was} shown`, have);
    sets.take(id);
    return { next: next(), done: { removed_sets: 1 } };
  }

  if (op === "start_over") {
    const seen = body?.rev === undefined || body?.rev === null ? null : Number(body.rev);
    const now = have.rev === undefined || have.rev === null ? null : Number(have.rev);
    if (seen !== now) throw new Conflict("your collection changed since it was shown; here it is now", have);
    if (have.sets.length + have.parts.length === 0) return { next: null, done: {} };
    return { next: { sets: [], parts: [] }, done: { started_over: true } };
  }

  throw new Refusal(400, "say what this is: op lots, set, keep, take_back, remove_set or start_over, "
    + "or from rebrickable_csv, bricklink_xml, rebrickable_api or sets");
}

/// An import, as a change: {next, done}.
function importing(have, body, imported) {
  const mode = body?.mode === "replace" ? "replace" : "add";
  return {
    next: merged(have, imported, mode, SOURCE_OF[String(body.from)]),
    done: { imported: { sets: imported.sets.length, lots: imported.parts.length } },
  };
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
  else if (from === "sets") parsed = typedSets(body.text);
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
    throw new Refusal(400, "say what this is: from rebrickable_csv, bricklink_xml, rebrickable_api or sets");
  }
  return mapped(parsed, numbering, index);
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

const pause = (attempt) => new Promise((done) => setTimeout(done, 15 + Math.random() * 40 * (attempt + 1)));

/// [make] made on the row as kept and written only over that row: the rev
/// it was made on is the PATCH's condition (a new row's, that there is
/// none). When another write came first, nothing is written, and it is
/// made again on what that one left. [id], when given, is remembered with
/// the write, and a change whose id is remembered is not made again.
/// Returns {row, done}; throws what [make] refuses.
async function change(owner, make, id = "") {
  for (let attempt = 0; attempt < TRIES; attempt++) {
    const have = await readRow(owner);
    if (id && have.recent.includes(id)) return { row: have, done: { again: true } };
    const made = make(have);
    if (!made.next) return { row: have, done: made.done };
    within(made.next);
    const kept = {
      sets: made.next.sets,
      parts: made.next.parts,
      recent: id ? [...have.recent.filter((one) => one !== id), id].slice(-MOST_REMEMBERED) : have.recent,
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

function bodyOf(request) {
  try {
    const body = request.body;
    return typeof body === "string" ? JSON.parse(body) : body;
  } catch {
    throw new Refusal(400, "the request is not JSON");
  }
}

/// What an older app's PUT is told: it would write a copy that may be days
/// old over what another device changed since.
export const UPDATE_WORDS = "This copy of Brickworks is older than the way collections are kept now: taking a "
  + "set out from it could undo what you changed on another device, so nothing was changed. Update "
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
    if (body && body.owner !== undefined && String(body.owner) !== owner) {
      throw new Refusal(403, "a collection is only ever its owner's");
    }
    const size = JSON.stringify(body ?? null).length;
    const most = ["keep", "take_back"].includes(body?.op) ? MAX_KEEP_BYTES : MAX_BYTES;
    if (size > most) {
      throw new Refusal(413, `that is ${size} bytes; ${body?.op ? "a change" : "an import"} is at most ${most}`);
    }

    if (request.method === "PUT") throw new Conflict(UPDATE_WORDS, await readRow(owner));

    const id = body?.id === undefined || body?.id === null ? "" : String(body.id);
    if (id && !REQUEST.test(id)) throw new Refusal(400, `"${id.slice(0, 80)}" is not a request id`);
    if (body?.op !== undefined) {
      // A change of lots adds and takes down: said again as it was, it is
      // never made twice, so it says which it is.
      if (body.op === "lots" && !id) throw new Refusal(400, "a change of lots says its id");
      const { row, done } = await change(owner, (have) => applyOp(have, body), id);
      return response.status(200).json({ ...shown(row), done });
    }
    if (!Object.hasOwn(SOURCE_OF, String(body?.from || ""))) {
      throw new Refusal(400, "say what this is: from rebrickable_csv, bricklink_xml, rebrickable_api or sets, "
        + "or op lots, set, keep, take_back, remove_set or start_over");
    }
    const imported = parseImport(body);
    const { row, done } = await change(owner, (have) => importing(have, body, imported), id);
    return response.status(200).json({
      ...shown(row),
      done,
      imported: done.again ? { sets: 0, lots: 0 } : done.imported,
      left_out: Object.entries(imported.leftOut).map(([why, count]) => ({ why, count })),
    });
  } catch (error) {
    if (error instanceof Conflict) return response.status(409).json({ error: error.message, ...shown(error.row) });
    if (error instanceof Refusal) return response.status(error.status).json({ error: error.message });
    // A database failure names the table and the status and nothing else.
    return response.status(502).json({ error: String(error.message || error).slice(0, 200) });
  }
}
