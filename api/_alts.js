// Alternate builds, counted (altbuilds, 2026-11-23; supabase/alt_builds.sql):
// for every model in the gallery, the real set whose parts build it, or the
// smallest group of sets that do, counted from what the model needs and what
// each set holds by the app's own rules, never typed in by anybody.
//
// Rebrickable lists a set's alternate builds on the set's own page, "by far
// the most popular MOCs to build" (docs/MASTERPLAN.md, rb-alt), and its
// designers type each inventory in. Here both sides are already counted:
//
//   a model's needs   model_needs, counted from its file as it is published
//                     (api/share.js checkModel, api/_owned.js keyed): every
//                     part anybody can own, a mould's letter left off, a
//                     colour as its shop files it, stickers and parts the
//                     catalogue does not know left out
//   a set's parts     the sets' inventories (tools/collection_data.py's 256
//                     shards, the app's My collection's), one copy, no
//                     spares, in that same spelling (api/_owned.js keyed):
//                     what a Collection holding that one set has on hand
//
// So a model's share of a set is what the app's Collection check says when
// the person owns that set alone: each part and colour the model needs,
// as many as the set holds of it at most (Collection.coverage's owned, with
// allocate's other mouldings, which the spelling has already made one).
//
// The sets are held at deploy as one index (packIndex, tools/web/alt_index.mjs,
// beside each function as _alt_index.bin): each part and colour, the sets
// that hold it and how many. A publish reads nothing else: no shard, no
// file. Kept per model (keepAlts, supabase/alt_builds.sql model_alt_sets):
//
//   whole    the one set that holds every part of it, the smallest of
//            those that do: "An alternate build of 31009 Small Cottage:
//            every part from the set"
//   group    when no one set does, the fewest sets, up to five, that do
//            together, each with what it gives: "An alternate build of
//            42115 and 42054"
//   best     when neither, the set that holds the most of it: "97% from
//            31009 Small Cottage", said from SHOWN_SHARE up
//   library  the set the app's Library says it is another model of (a
//            B-model's file, published: api/_omr_credit.js), counted the same
//   declared a set its designer says it is an alternate build of
//            (model_bases), counted the same, so a set's page says how
//            much of it is from the set and its designer hears what is not
//
// A model that is a set's own build (the Library's model of the set itself,
// published: api/_omr_credit.js) is that set's (own), and an alternate of
// nothing: its page credits the set already, and the set's page shows it as
// its 3D model.

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { db } from "./_db.js";
import { keyed, ownedFacts } from "./_owned.js";

/// The rule the rows were counted by: a model counted by an older one is
/// counted again (alt_uncounted).
export const ALT_RULE = 1;
/// The most sets a group may be: Rebrickable's partial alternates' five.
export const MOST_GROUP = 5;
/// From what share of its pieces one set's share is said on its page and
/// it is listed on the set's page, when no set and no group holds it all
/// (supabase/alt_builds.sql set_built says the same 80%): of the LDraw
/// library's 337 other models of a set, 250 hold this much of their own set
/// by these rules and 220 hold 90%.
export const SHOWN_SHARE = 0.8;
/// How long a group is looked for, at most, in sets tried: a model no five
/// sets hold is given up on quickly, and one that needs this many is said
/// as its best set (cut, counted in the backfill's report).
export const MOST_TRIED = 60000;
/// Rebrickable's "Database Sets" (theme 746): the parts no set has, which
/// are not sets anybody owns (tools/collection_data.py NOT_SETS).
const NOT_SETS = new Set([746]);

const MAGIC = "BWA1";

// ---------------------------------------------------------------------------
// The index: every set's parts, by part and colour.

/// The index from the sets' shards ([shards]: {sets: {number: record}}
/// each, collection_data.py's) in this deployment's spelling ([given]:
/// api/_owned.js ownedFacts): {sets: [number, lowercased], pieces: [each
/// set's pieces anybody owns], keys: Map "part/colour" -> {at: Uint32Array
/// of set numbers' places, qty: Uint16Array}}. [skip] is the set numbers,
/// lowercased, that are not sets (a database set).
export function indexFrom(shards, given = ownedFacts(), skip = new Set()) {
  const records = [];
  for (const shard of shards) {
    for (const [number, record] of Object.entries(shard?.sets || {})) {
      const set = number.toLowerCase();
      if (!skip.has(set)) records.push([set, record]);
    }
  }
  records.sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
  const sets = [];
  const pieces = [];
  const postings = new Map();
  for (const [set, record] of records) {
    const lots = keyed(record.p || [], given);
    if (!lots.length) continue;
    const at = sets.length;
    sets.push(set);
    let all = 0;
    for (const lot of lots) {
      const key = `${lot.part}/${lot.colour}`;
      let list = postings.get(key);
      if (!list) postings.set(key, (list = []));
      list.push(at, lot.qty);
      all += lot.qty;
    }
    pieces.push(all);
  }
  const keys = new Map();
  for (const [key, list] of postings) {
    const n = list.length / 2;
    const at = new Uint32Array(n);
    const qty = new Uint16Array(n);
    for (let i = 0; i < n; i += 1) {
      at[i] = list[2 * i];
      qty[i] = Math.min(65535, list[2 * i + 1]);
    }
    keys.set(key, { at, qty });
  }
  return { sets, pieces, keys };
}

/// The set numbers, lowercased, that are not sets, from the set catalogue
/// as tools/set_catalog.py writes it (its rows' theme).
export function notSetsOf(rawCatalogue) {
  const out = new Set();
  for (const row of Array.isArray(rawCatalogue?.sets) ? rawCatalogue.sets : []) {
    if (Array.isArray(row) && NOT_SETS.has(Number(row[3]))) out.add(String(row[0]).toLowerCase());
  }
  return out;
}

/// [index] as the bytes beside a function: "BWA1", a header's length (u32,
/// little end first), the header (JSON: rule, sets, pieces, keys and each
/// key's count), to a multiple of four, then every key's set places (u32)
/// and then every key's counts (u16), key by key in the header's order.
export function packIndex(index) {
  const keys = [...index.keys.keys()].sort();
  const counts = keys.map((key) => index.keys.get(key).at.length);
  const total = counts.reduce((sum, n) => sum + n, 0);
  const header = Buffer.from(JSON.stringify({ rule: ALT_RULE, sets: index.sets, pieces: index.pieces, keys, counts }), "utf8");
  const start = Math.ceil((8 + header.length) / 4) * 4;
  const out = Buffer.alloc(start + total * 6);
  out.write(MAGIC, 0, "latin1");
  out.writeUInt32LE(header.length, 4);
  header.copy(out, 8);
  const at = new Uint32Array(out.buffer, out.byteOffset + start, total);
  const qty = new Uint16Array(out.buffer, out.byteOffset + start + total * 4, total);
  let k = 0;
  for (const key of keys) {
    const one = index.keys.get(key);
    at.set(one.at, k);
    qty.set(one.qty, k);
    k += one.at.length;
  }
  return out;
}

/// The index from packIndex's bytes; null for bytes that are not one.
export function unpackIndex(bytes) {
  if (!bytes || bytes.length < 8 || bytes.toString("latin1", 0, 4) !== MAGIC) return null;
  const length = bytes.readUInt32LE(4);
  const header = JSON.parse(bytes.toString("utf8", 8, 8 + length));
  const start = Math.ceil((8 + length) / 4) * 4;
  const total = header.counts.reduce((sum, n) => sum + n, 0);
  // Copied to a buffer of its own, aligned, so the views can be made.
  const body = new Uint8Array(total * 6);
  body.set(bytes.subarray(start, start + total * 6));
  const at = new Uint32Array(body.buffer, 0, total);
  const qty = new Uint16Array(body.buffer, total * 4, total);
  const keys = new Map();
  let k = 0;
  header.keys.forEach((key, i) => {
    const n = header.counts[i];
    keys.set(key, { at: at.subarray(k, k + n), qty: qty.subarray(k, k + n) });
    k += n;
  });
  return { sets: header.sets, pieces: header.pieces, keys, rule: header.rule };
}

let held = null;

/// This deployment's index: _alt_index.bin beside this file (tools/package_api.sh
/// puts it there), else worked out of the checkout's shards and set catalogue
/// (a few seconds, once); null where there are neither.
export function altIndex() {
  if (held !== null) return held || null;
  const beside = new URL("./_alt_index.bin", import.meta.url);
  if (existsSync(beside)) {
    held = unpackIndex(readFileSync(beside)) || false;
    return held || null;
  }
  const shards = new URL("../assets/generated/sets/", import.meta.url);
  if (!existsSync(shards)) {
    held = false;
    return null;
  }
  const catalogue = new URL("../assets/generated/set_catalog.json", import.meta.url);
  const skip = existsSync(catalogue) ? notSetsOf(JSON.parse(readFileSync(catalogue, "utf8"))) : new Set();
  const read = readdirSync(shards).filter((name) => /^\d{3}\.json$/.test(name))
    .map((name) => JSON.parse(readFileSync(new URL(name, shards), "utf8")));
  held = read.length ? indexFrom(read, ownedFacts(), skip) : false;
  return held || null;
}

/// [index] as this deployment's (a test's own, or tools/web/alt_index.mjs's).
export function useIndex(index) {
  held = index || false;
  return index;
}

// ---------------------------------------------------------------------------
// The count. Pure.

/// The place of [set] (a number, any case) in [index], or -1.
export function placeOf(index, set) {
  const asked = String(set || "").toLowerCase();
  let low = 0;
  let high = index.sets.length - 1;
  while (low <= high) {
    const mid = (low + high) >> 1;
    const at = index.sets[mid];
    if (at === asked) return mid;
    if (at < asked) low = mid + 1;
    else high = mid - 1;
  }
  return -1;
}

/// How many of a key's pieces set [place] holds: the key's postings are in
/// the sets' order, so it is looked up by halves.
function qtyOf(posting, place) {
  if (!posting) return 0;
  let low = 0;
  let high = posting.at.length - 1;
  while (low <= high) {
    const mid = (low + high) >> 1;
    const at = posting.at[mid];
    if (at === place) return posting.qty[mid];
    if (at < place) low = mid + 1;
    else high = mid - 1;
  }
  return 0;
}

/// [lots] (what a model needs: [{part, colour, qty}] in the one spelling, as
/// model_needs keeps them, or [part, colour, qty]) as a Map key -> pieces.
function needsMap(lots) {
  const need = new Map();
  for (const lot of lots || []) {
    const [part, colour, qty] = Array.isArray(lot) ? lot : [lot.part, lot.colour, lot.qty];
    const n = Number(qty);
    if (!part || !Number.isInteger(n) || n < 1) continue;
    const key = `${part}/${colour}`;
    need.set(key, (need.get(key) || 0) + n);
  }
  return need;
}

/// How much of a model [lots] one set [set] holds: {set, have, pieces,
/// short: [{part, colour, need, have}] each part and colour it is short of,
/// the most short first}; with [every], lots: each part and colour it
/// needs, so (tools/web/altbuilds_probe.mjs) it can be held to the app's
/// Collection check part by part. Null for a set the index does not have.
export function shareOf(lots, set, index, { every = false } = {}) {
  const place = placeOf(index, set);
  if (place < 0) return null;
  let have = 0;
  let pieces = 0;
  const short = [];
  const all = [];
  for (const [key, n] of needsMap(lots)) {
    const held = Math.min(n, qtyOf(index.keys.get(key), place));
    pieces += n;
    have += held;
    const [part, colour] = key.split("/");
    if (every) all.push({ part, colour: Number(colour), need: n, have: held });
    if (held < n) short.push({ part, colour: Number(colour), need: n, have: held });
  }
  if (every) return { set: index.sets[place], have, pieces, lots: all };
  short.sort((a, b) => b.need - b.have - (a.need - a.have) || (a.part < b.part ? -1 : a.part > b.part ? 1 : a.colour - b.colour));
  return { set: index.sets[place], have, pieces, short };
}

/// What builds a model, by [index]: {pieces, best: {set, have} the set that
/// holds the most of it (on a tie the smaller set: a model of 40 bricks is
/// an alternate of a set of 60 before one of 6,000), group: [{set, have}]
/// the fewest sets, two to MOST_GROUP, that hold all of it together when no
/// one set does (each with what it alone holds of it, the most first), or
/// null, cut: true when the search for a group was given up (MOST_TRIED)}.
/// pieces 0 for a model with nothing anybody owns (best null).
export function altsOf(lots, index, { mostTried = MOST_TRIED } = {}) {
  const need = needsMap(lots);
  let pieces = 0;
  const rows = [];
  for (const [key, n] of need) {
    pieces += n;
    rows.push({ n, posting: index.keys.get(key) || null });
  }
  if (!pieces) return { pieces: 0, best: null, group: null, cut: false };
  // What each set holds of it, and each set's rows with what it gives.
  const have = new Int32Array(index.sets.length);
  const lend = new Map();
  rows.forEach((row, r) => {
    const posting = row.posting;
    if (!posting) return;
    for (let i = 0; i < posting.at.length; i += 1) {
      const place = posting.at[i];
      const gives = Math.min(row.n, posting.qty[i]);
      have[place] += gives;
      let list = lend.get(place);
      if (!list) lend.set(place, (list = []));
      list.push(r, gives);
    }
  });
  let top = -1;
  for (const place of lend.keys()) {
    if (top < 0 || have[place] > have[top] || (have[place] === have[top]
      && (index.pieces[place] < index.pieces[top] || (index.pieces[place] === index.pieces[top] && place < top)))) top = place;
  }
  if (top < 0) return { pieces, best: null, group: null, cut: false };
  const best = { set: index.sets[top], have: have[top] };
  if (have[top] >= pieces) return { pieces, best, group: null, cut: false };
  // A part and colour no set holds, or holds enough of in five, is in no
  // group: nothing to look for.
  const found = groupOf(rows, have, lend, pieces, mostTried);
  const group = found.group && found.group.map((place) => ({ set: index.sets[place], have: have[place] }))
    .sort((a, b) => b.have - a.have || (a.set < b.set ? -1 : 1));
  return { pieces, best, group, cut: found.cut };
}

/// The fewest sets that hold every row's pieces together: {group: [places]
/// or null, cut}. Looked for size by size, two up to MOST_GROUP, each time
/// by the row the fewest sets can give to (a rare part decides first), its
/// sets tried the most giving first; a branch is left once the sets still
/// to come could not make up what is left even if each gave all it gives
/// to the whole model.
function groupOf(rows, have, lend, pieces, mostTried) {
  for (const row of rows) {
    if (!row.posting) return { group: null, cut: false };
    // Five copies of the most any one set has of it are still too few.
    let most = 0;
    for (let i = 0; i < row.posting.qty.length; i += 1) most = Math.max(most, row.posting.qty[i]);
    if (most * MOST_GROUP < row.n) return { group: null, cut: false };
  }
  const order = [...lend.keys()].sort((a, b) => have[b] - have[a] || a - b);
  const left = rows.map((row) => row.n);
  const chosen = [];
  let tried = 0;
  let cut = false;
  // The most the [slots] best sets not yet chosen could give.
  const couldGive = (slots) => {
    let sum = 0;
    let taken = 0;
    for (const place of order) {
      if (taken === slots) break;
      if (chosen.includes(place)) continue;
      sum += have[place];
      taken += 1;
    }
    return sum;
  };
  const take = (place) => {
    const list = lend.get(place);
    const moved = [];
    for (let i = 0; i < list.length; i += 2) {
      const r = list[i];
      const gives = Math.min(left[r], list[i + 1]);
      if (gives > 0) {
        left[r] -= gives;
        moved.push(r, gives);
      }
    }
    return moved;
  };
  const untake = (moved) => {
    for (let i = 0; i < moved.length; i += 2) left[moved[i]] += moved[i + 1];
  };
  const search = (slots, still) => {
    if (still <= 0) return true;
    if (slots === 0 || cut) return false;
    if (couldGive(slots) < still) return false;
    // The row still short that the fewest sets can give to.
    let pivot = -1;
    for (let r = 0; r < rows.length; r += 1) {
      if (left[r] > 0 && (pivot < 0 || rows[r].posting.at.length < rows[pivot].posting.at.length)) pivot = r;
    }
    const posting = rows[pivot].posting;
    const candidates = [];
    for (let i = 0; i < posting.at.length; i += 1) if (!chosen.includes(posting.at[i])) candidates.push(posting.at[i]);
    candidates.sort((a, b) => have[b] - have[a] || a - b);
    for (const place of candidates) {
      tried += 1;
      if (tried > mostTried) {
        cut = true;
        return false;
      }
      const moved = take(place);
      let gave = 0;
      for (let i = 1; i < moved.length; i += 2) gave += moved[i];
      chosen.push(place);
      const done = search(slots - 1, still - gave);
      if (done) return true;
      chosen.pop();
      untake(moved);
    }
    return false;
  };
  for (let size = 2; size <= MOST_GROUP; size += 1) {
    if (search(size, pieces)) return { group: [...chosen], cut: false };
    if (cut) return { group: null, cut: true };
  }
  return { group: null, cut: false };
}

/// A model's count as it is kept (alt_keep): {pieces, cut, rows: [{set,
/// have, role, n}]}, one row a set, from what it needs ([lots], keyed) and
/// [index]. [library] is the app's Library's word on it, when it is one of
/// the Library's models (api/_omr_credit.js libraryCredit: {set,
/// alternate_of}): the set's own model is that set's (own) and nothing
/// else's; another model of a set (alternate_of) is that set's (library),
/// counted, and counted against every set as any model is. [declared] is
/// the sets its designer names (model_bases), each counted for what it
/// holds of it. The whole set or the group first, then the best set when
/// it is said (SHOWN_SHARE).
export function countRows(lots, index, { library = null, declared = [] } = {}) {
  const rows = [];
  const seen = new Set();
  const add = (set, have, role, n = 0) => {
    const key = String(set || "").toLowerCase();
    if (!key || seen.has(key)) return;
    seen.add(key);
    rows.push({ set: key, have, role, n });
  };
  const held = (set) => shareOf(lots, set, index);
  let counted = { pieces: needsPieces(lots), best: null, group: null, cut: false };
  const ownSet = library && library.set && !library.alternate_of ? held(library.set) : null;
  if (ownSet) {
    add(ownSet.set, ownSet.have, "own");
  } else {
    if (library && library.alternate_of) {
      const of = held(library.alternate_of);
      if (of) add(of.set, of.have, "library");
    }
    counted = altsOf(lots, index);
    const { pieces, best, group } = counted;
    if (best && pieces > 0) {
      if (best.have >= pieces) add(best.set, best.have, "whole");
      else if (group) group.forEach((one, n) => add(one.set, one.have, "group", n + 1));
      if (best.have < pieces && best.have >= SHOWN_SHARE * pieces) add(best.set, best.have, "best");
    }
  }
  for (const set of declared) {
    const one = held(set);
    if (one) add(one.set, one.have, "declared");
  }
  return { pieces: counted.pieces, cut: counted.cut, rows };
}

const needsPieces = (lots) => [...needsMap(lots).values()].reduce((sum, n) => sum + n, 0);

/// A model's line, as its page says it, from its kept rows ([{set, have,
/// role, n}], alt_of's) and its pieces: {how: "whole" | "group" | "best",
/// sets: [{set, have}], pieces}, or null for none to say (a set's own
/// model says none). The whole set first, else the group, else the share
/// of the set the Library says it is a model of, else the best set's.
export function altSaid(rows, pieces) {
  const list = Array.isArray(rows) ? rows : [];
  if (!(pieces > 0) || list.some((row) => row.role === "own")) return null;
  const one = (row, how) => ({ how, sets: [{ set: row.set, have: Math.min(row.have, pieces) }], pieces });
  const whole = list.find((row) => row.role === "whole" || (row.role === "library" && row.have >= pieces));
  if (whole) return one(whole, "whole");
  const group = list.filter((row) => row.role === "group").sort((a, b) => a.n - b.n);
  if (group.length >= 2) return { how: "group", sets: group.map((row) => ({ set: row.set, have: row.have })), pieces };
  // The Library's word that it is another model of the set, whatever its
  // share; else the best set's, from SHOWN_SHARE.
  const library = list.find((row) => row.role === "library");
  if (library) return one(library, "best");
  const best = list.find((row) => row.role === "best");
  if (best && best.have >= SHOWN_SHARE * pieces) return one(best, "best");
  return null;
}

/// A share as a page says it: a whole number of percent, never 100 short of
/// every piece (199 of 200 is 99%, not 100%).
export function percentOf(have, pieces) {
  if (!(pieces > 0)) return 0;
  if (have >= pieces) return 100;
  return Math.min(99, Math.floor((100 * have) / pieces));
}

// ---------------------------------------------------------------------------
// The database (supabase/alt_builds.sql). Before the file is applied every
// read is none and every keep does nothing: a publish never waits on it.

const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));

/// The sets model [id]'s designer names it as based on (model_bases_of),
/// whatever the how: each is counted, so a set's page says how much of the
/// model is from it.
async function declaredOf(id) {
  const rows = await db("rpc/model_bases_of", { method: "POST", body: { model_ids: [id] } }).catch(() => []);
  return (Array.isArray(rows) ? rows : []).filter((row) => row && row.set_number).map((row) => String(row.set_number));
}

/// Model [id] counted from [lots] (what it needs, keyed: api/_owned.js
/// keyed, as model_needs keeps them) and kept, whole (alt_keep):
/// countRows' {pieces, cut, rows}, or null when there is no index here, no
/// alt_builds.sql yet, or the database would not keep it. Never throws.
/// [library] as countRows takes it; [declared] the designer's sets, read
/// when not given.
export async function keepAlts(id, lots, { library = null, declared = null, index = altIndex() } = {}) {
  if (!index) return null;
  try {
    const counted = countRows(lots, index, { library, declared: declared ?? await declaredOf(id) });
    const kept = await db("rpc/alt_keep", { method: "POST", body: { model_id: id, pieces: counted.pieces, rule: ALT_RULE,
      cut: counted.cut, sets: counted.rows } });
    return kept && !kept.refused ? counted : null;
  } catch {
    return null;
  }
}

/// The kept counts of [ids]: Map id -> {pieces, rule, cut, sets: [{set,
/// role, n, have}]}, or null before alt_builds.sql.
export async function altRowsOf(ids) {
  const asked = [...new Set(ids.filter((id) => typeof id === "string" && id))].slice(0, 100);
  if (!asked.length) return new Map();
  let rows;
  try {
    rows = await db("rpc/alt_of", { method: "POST", body: { model_ids: asked } });
  } catch (trouble) {
    if (notYet(trouble)) return null;
    throw trouble;
  }
  return new Map((Array.isArray(rows) ? rows : []).filter((row) => row && row.model)
    .map((row) => [row.model, { pieces: Number(row.pieces) || 0, rule: Number(row.rule) || 0, cut: row.cut === true,
      sets: Array.isArray(row.sets) ? row.sets : [] }]));
}

/// What [ids] need, as kept (alt_needs_of): Map id -> [{part, colour, qty}],
/// or null before alt_builds.sql.
export async function needsOf(ids) {
  let rows;
  try {
    rows = await db("rpc/alt_needs_of", { method: "POST", body: { model_ids: ids.slice(0, 100) } });
  } catch (trouble) {
    if (notYet(trouble)) return null;
    throw trouble;
  }
  return new Map(Object.entries(rows && typeof rows === "object" ? rows : {})
    .map(([id, lots]) => [id, (Array.isArray(lots) ? lots : []).map(([part, colour, qty]) => ({ part, colour, qty }))]));
}

/// Model [id] counted again from what it needs as kept, its designer's list
/// read afresh (their list changed: api/_bases.js basesPut), the Library's
/// word kept as it was counted: keepAlts' answer, or null. Never throws.
export async function recountAlts(id, { index = altIndex() } = {}) {
  if (!index) return null;
  try {
    const [needs, kept] = await Promise.all([needsOf([id]), altRowsOf([id])]);
    const lots = needs && needs.get(id);
    if (!lots || !lots.length) return null;
    const was = kept?.get(id)?.sets || [];
    const own = was.find((row) => row.role === "own");
    const other = was.find((row) => row.role === "library");
    const library = own ? { set: own.set } : other ? { set: other.set, alternate_of: other.set } : null;
    return await keepAlts(id, lots, { library, index });
  } catch {
    return null;
  }
}
