// My collection: what a person owns, kept with their account.
//
//   GET    /api/collection   the caller's collection
//   POST   /api/collection   an import, parsed and mapped here, added to it
//   PUT    /api/collection   the whole collection, already in LDraw numbers
//   DELETE /api/collection   all of it gone
//
// Every import is parsed here and nowhere else, so a Rebrickable export, a
// BrickLink XML and a list fetched from Rebrickable's API with the
// person's own key all land in one shape and one numbering, LDraw's
// (supabase/collection.sql says what that shape is):
//
//   {"from": "rebrickable_csv", "text": "<the file>", "mode": "add"}
//   {"from": "bricklink_xml",   "text": "<the file>", "mode": "add"}
//   {"from": "rebrickable_api", "sets": [["10237-1", 1, true]],
//                               "parts": [["3001", 4, 12]], "mode": "add"}
//   {"from": "sets", "text": "10237-1, 6020"}          typed by number
//
// "replace" instead of "add" replaces what the import carries: a sets list
// replaces the sets, a parts list the loose parts.
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
// wrong plastic.
//
// Refused, with words: no sign-in (401), naming another account's
// collection (403 — a collection is only ever its owner's, and there is no
// way to ask for anyone else's), a body over MAX_BYTES or a collection over
// MAX_SETS sets or MAX_LOTS lots (413), and a file that is not what it says
// it is (400, with the line). The database's own row security is the
// second lock (supabase/collection.sql).

import { existsSync, readFileSync } from "node:fs";
import { AuthError, authConfigured, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";

export const MAX_BYTES = 1_000_000;
export const MAX_SETS = 5000;
export const MAX_LOTS = 20000;
const MAX_QTY = 100000;

const SET_NUMBER = /^[a-z0-9][a-z0-9._]{0,24}(-[0-9]{1,3})?$/;
const PART_NUMBER = /^[a-z0-9][a-z0-9._-]{0,40}$/;

export class Refusal extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
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

function merged(have, add, mode) {
  const sets = new Map();
  const parts = new Map();
  const keepSets = !(mode === "replace" && add.sets.length > 0);
  const keepParts = !(mode === "replace" && add.parts.length > 0);
  for (const s of keepSets ? have.sets : []) sets.set(s.set, { ...s });
  for (const p of keepParts ? have.parts : []) parts.set(`${p.part}/${p.colour}`, { ...p });
  for (const s of add.sets) {
    const held = sets.get(s.set);
    if (held) { held.qty = Math.min(MAX_QTY, held.qty + s.qty); held.spares = held.spares || s.spares; }
    else sets.set(s.set, { ...s });
  }
  for (const p of add.parts) {
    const key = `${p.part}/${p.colour}`;
    const held = parts.get(key);
    if (held) held.qty = Math.min(MAX_QTY, held.qty + p.qty);
    else parts.set(key, { ...p });
  }
  return { sets: [...sets.values()], parts: [...parts.values()] };
}

/// A whole collection sent by the app, already in LDraw numbers: checked
/// field by field, because it goes into the database as it is.
export function wholeCollection(body) {
  if (!body || !Array.isArray(body.sets) || !Array.isArray(body.parts)) {
    throw new Refusal(400, "a collection is {sets: [...], parts: [...]}");
  }
  const sets = body.sets.map((s, n) => {
    const set = setNumber(s?.set);
    if (!set) throw new Refusal(400, `set ${n + 1}: "${s?.set}" is not a set number`);
    return { set, qty: quantity(s?.qty, `set ${n + 1}`), spares: Boolean(s?.spares) };
  });
  const parts = body.parts.map((p, n) => {
    const part = partNumber(p?.part);
    if (!part) throw new Refusal(400, `part ${n + 1}: "${p?.part}" is not a part number`);
    const colour = Number(p?.colour);
    if (!Number.isInteger(colour) || colour < 0 || colour > 0x3ffffff) {
      throw new Refusal(400, `part ${n + 1}: the colour "${p?.colour}" is not an LDraw colour code`);
    }
    return { part, colour, qty: quantity(p?.qty, `part ${n + 1}`) };
  });
  return merged({ sets: [], parts: [] }, { sets, parts }, "add");
}

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

async function read(owner) {
  const rows = await db(`collections?owner=eq.${owner}&select=sets,parts,updated_at`);
  const row = rows && rows[0];
  return row
    ? { sets: row.sets || [], parts: row.parts || [], updated_at: row.updated_at }
    : { sets: [], parts: [], updated_at: null };
}

async function write(owner, collection) {
  const rows = await db("collections?on_conflict=owner", {
    method: "POST",
    prefer: "resolution=merge-duplicates,return=representation",
    body: [{ owner, sets: collection.sets, parts: collection.parts, updated_at: new Date().toISOString() }],
  });
  const row = rows && rows[0];
  return { sets: row.sets, parts: row.parts, updated_at: row.updated_at };
}

function bodyOf(request) {
  try {
    const body = request.body;
    return typeof body === "string" ? JSON.parse(body) : body;
  } catch {
    throw new Refusal(400, "the request is not JSON");
  }
}

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
    if (declared > MAX_BYTES) throw new Refusal(413, `that is ${declared} bytes; an import is at most ${MAX_BYTES}`);

    if (request.method === "GET") {
      return response.status(200).json(await read(owner));
    }
    if (request.method === "DELETE") {
      await db(`collections?owner=eq.${owner}`, { method: "DELETE" });
      return response.status(200).json({ sets: [], parts: [], updated_at: null });
    }
    if (request.method !== "POST" && request.method !== "PUT") {
      throw new Refusal(405, "GET, POST, PUT or DELETE");
    }

    const body = bodyOf(request);
    if (body && body.owner !== undefined && String(body.owner) !== owner) {
      throw new Refusal(403, "a collection is only ever its owner's");
    }
    const size = JSON.stringify(body ?? null).length;
    if (size > MAX_BYTES) throw new Refusal(413, `that is ${size} bytes; an import is at most ${MAX_BYTES}`);

    if (request.method === "PUT") {
      const whole = wholeCollection(body);
      within(whole);
      return response.status(200).json(await write(owner, whole));
    }

    const mode = body?.mode === "replace" ? "replace" : "add";
    const imported = parseImport(body);
    const next = merged(await read(owner), imported, mode);
    within(next);
    const saved = await write(owner, next);
    return response.status(200).json({
      ...saved,
      imported: { sets: imported.sets.length, lots: imported.parts.length },
      left_out: Object.entries(imported.leftOut).map(([why, count]) => ({ why, count })),
    });
  } catch (error) {
    if (error instanceof Refusal) return response.status(error.status).json({ error: error.message });
    // A database failure names the table and the status and nothing else.
    return response.status(502).json({ error: String(error.message || error).slice(0, 200) });
  }
}
