// Build with what I own, across the whole gallery (2026-10-19,
// supabase/discovery.sql): for a signed-in person with a collection, each
// model's share of its parts they own, by part and colour, as the app's
// one-model check counts it (src/collection/collection.gd).
//
// Two sides, each counted once and kept, so the gallery asks the database
// one join and never reads a file:
//
//   a model's needs   counted from its file when it is published
//                     (api/share.js checkModel: every part it places, through
//                     its sub-models, in the colour it is placed in), kept in
//                     model_needs
//   a person's pool   their loose parts and their sets through the sets'
//                     inventories (tools/collection_data.py's shards, the
//                     app's own), counted the first time the gallery is
//                     asked for their shares after their collection changed
//                     (freshPool), kept in collection_pools. Counted here,
//                     in the share function, because the catalogue's facts
//                     are beside it (_part_facts.json) and nowhere else.
//
// Both are spelled the one way the app compares them (Collection.key_of): a
// part by the number it means today (LDraw retires numbers and keeps a
// stub: PartLibrary.resolve), a colour by the one a shop files it under (a
// Rubber Black tyre is a Black tyre: PartLibrary.plain_code). And, as the
// app lets another moulding of a part stand in for it before anything is
// called short (Collection.family_of, allocate), a mould's letter is left
// off: 3794a and 3794b are both 3794 here. A part the catalogue does not
// know is not one anybody owns (a primitive drawn into a model, a
// sub-model a file names and does not carry), and is left out of what a
// model needs, as the app leaves it out.

import { existsSync, readFileSync } from "node:fs";
import { db } from "./_db.js";

let facts = null;

/// The catalogue's facts these sums need: {known: Set of part numbers,
/// moved: number -> the one it moved to, plain: colour code -> its plain
/// code}. From _part_facts.json beside this file in a deployment
/// (tools/web/part_facts.mjs writes them there with the Technic facts),
/// worked out of the catalogue and the colours in a checkout; none where
/// there are neither, and then every part is counted as it is named.
export function ownedFacts() {
  if (facts) return facts;
  const beside = new URL("./_part_facts.json", import.meta.url);
  if (existsSync(beside)) {
    const raw = JSON.parse(readFileSync(beside, "utf8"));
    if (Array.isArray(raw.known)) {
      facts = factsFrom(raw);
      return facts;
    }
  }
  const catalogue = new URL("../assets/generated/catalogue.json", import.meta.url);
  const colours = new URL("../assets/generated/colors.json", import.meta.url);
  if (existsSync(catalogue) && existsSync(colours)) {
    facts = factsFrom(deriveOwnedFacts(JSON.parse(readFileSync(catalogue, "utf8")),
      JSON.parse(readFileSync(colours, "utf8"))));
    return facts;
  }
  facts = { known: null, moved: new Map(), plain: new Map() };
  return facts;
}

/// These sums' facts from a _part_facts.json named by hand (a tool run in a
/// checkout without the catalogue: tools/web/needs_backfill.mjs --facts).
export function useFacts(raw) {
  facts = factsFrom(raw);
  return facts;
}

/// What _part_facts.json holds for these sums, from the catalogue and the
/// colours.
export function deriveOwnedFacts(catalogue, colours) {
  const known = [];
  const moved = {};
  for (const part of catalogue.parts || []) {
    known.push(String(part.id));
    if (part.moved_to) moved[part.id] = String(part.moved_to);
  }
  const plain = {};
  for (const colour of Array.isArray(colours) ? colours : []) {
    if (Number.isInteger(colour.plain_code) && colour.plain_code !== colour.code) plain[colour.code] = colour.plain_code;
  }
  return { known: known.sort(), moved, plain };
}

function factsFrom(raw) {
  return {
    known: Array.isArray(raw.known) && raw.known.length ? new Set(raw.known) : null,
    moved: new Map(Object.entries(raw.moved || {})),
    plain: new Map(Object.entries(raw.plain || {}).map(([code, to]) => [Number(code), Number(to)])),
  };
}

/// The number a part means today, as PartLibrary.resolve: through LDraw's
/// moves, at most eight, and only to a part the catalogue has.
export function resolvePart(part, given = ownedFacts()) {
  let at = String(part).toLowerCase();
  for (let hop = 0; hop < 8; hop++) {
    const to = given.moved.get(at);
    if (!to || (given.known && !given.known.has(to))) return at;
    at = to;
  }
  return at;
}

export const plainColour = (code, given = ownedFacts()) => given.plain.get(code) ?? code;

/// A part's moulds as one: one more letter on a number is another moulding
/// of the same part (3794a, 3794b, 3660a), as Collection.family_of; a
/// number with more after the letter (3626bp01, a print) is only itself.
const MOULD = /^([ux]?\d+)[a-z]$/;
export const familyOf = (part) => MOULD.exec(part)?.[1] ?? part;

/// [lots] ([part, colour, qty] or {part, colour, qty}) in the one spelling,
/// the same key counted once: [{part, colour, qty}]. A part the catalogue
/// does not know is left out, when there is a catalogue to ask.
export function keyed(lots, given = ownedFacts()) {
  const out = new Map();
  for (const lot of lots) {
    const [rawPart, rawColour, rawQty] = Array.isArray(lot) ? lot : [lot.part, lot.colour, lot.qty];
    const qty = Number(rawQty);
    const colour = Number(rawColour);
    if (!Number.isInteger(qty) || qty < 1 || !Number.isInteger(colour) || colour < 0) continue;
    const id = String(rawPart || "").toLowerCase().replace(/\.dat$/, "");
    if (!id || (given.known && !given.known.has(id))) continue;
    const part = familyOf(resolvePart(id, given));
    const code = plainColour(colour, given);
    const key = `${part}/${code}`;
    const held = out.get(key);
    if (held) held.qty += qty;
    else out.set(key, { part, colour: code, qty });
  }
  return [...out.values()];
}

/// Which of the 256 shards a set's inventory is in: SetInventories.shard_of
/// and tools/collection_data.py shard_of, the same sum.
export function shardOf(setNumber) {
  let h = 0;
  for (const byte of Buffer.from(String(setNumber).trim().toLowerCase(), "utf8")) h = (h * 31 + byte) % 1000003;
  return h % 256;
}

/// A shard of the sets' inventories: beside the app in a checkout, or the
/// deployment's own /sets/, which deploy.sh fills (a preview's through its
/// protection, with the bypass Vercel gives its functions), or else the
/// site's, which has the same. Null when none has it.
export async function readShard(n, origin) {
  const name = `${String(n).padStart(3, "0")}.json`;
  const local = new URL(`../assets/generated/sets/${name}`, import.meta.url);
  if (existsSync(local)) return JSON.parse(readFileSync(local, "utf8"));
  const bypass = process.env.VERCEL_AUTOMATION_BYPASS_SECRET;
  for (const from of [...new Set([origin, "https://brickworks.diy"].filter(Boolean))]) {
    const reply = await fetch(`${from}/sets/${name}`, { signal: AbortSignal.timeout(15000),
      headers: bypass && from === origin ? { "x-vercel-protection-bypass": bypass } : {} }).catch(() => null);
    const read = reply && reply.ok ? await reply.json().catch(() => null) : null;
    if (read && read.sets) return read;
  }
  return null;
}

/// Everything on hand, as Collection.pool counts it: the loose parts, and
/// each set's parts (its spares too when the person said they kept them)
/// times how many of it. {lots: [{part, colour, qty}], unknown: [set
/// numbers no inventory has]}. [read] is readShard, or a probe's own.
export async function poolOf(collection, read) {
  const sets = Array.isArray(collection?.sets) ? collection.sets : [];
  const wanted = [...new Set(sets.map((one) => shardOf(one.set)))];
  const shards = new Map();
  for (let at = 0; at < wanted.length; at += 16) {
    const batch = wanted.slice(at, at + 16);
    const read16 = await Promise.all(batch.map((n) => read(n)));
    batch.forEach((n, k) => shards.set(n, read16[k]));
  }
  const lots = [...(Array.isArray(collection?.parts) ? collection.parts : [])];
  const unknown = [];
  for (const one of sets) {
    const record = shards.get(shardOf(one.set))?.sets?.[String(one.set).toLowerCase()];
    if (!record) {
      unknown.push(String(one.set));
      continue;
    }
    const times = Math.max(1, Number(one.qty) || 1);
    for (const [part, colour, qty] of [...(record.p || []), ...(one.spares ? record.s || [] : [])]) {
      lots.push([part, colour, Number(qty) * times]);
    }
  }
  return { lots: keyed(lots), unknown };
}

const notYet = (trouble) => (/: 404$/.test(String(trouble?.message || "")) ? null : Promise.reject(trouble));

/// [account]'s pool as the gallery counts it, counted again first when
/// their collection changed since it was (or it never was): {lots, pieces,
/// unknown, at}, or null for nobody with a collection, and before
/// supabase/discovery.sql. A collection deleted takes its pool with it.
export async function freshPool(account, origin) {
  const [kept, rows] = await Promise.all([
    db("rpc/owned_pool_of", { method: "POST", body: { account } }).catch(notYet),
    db(`collections?owner=eq.${account}&select=sets,parts,updated_at`),
  ]);
  const collection = rows && rows[0];
  if (!collection || (!(collection.sets || []).length && !(collection.parts || []).length)) {
    if (kept) await db("rpc/owned_forget_pool", { method: "POST", body: { account } }).catch(() => null);
    return null;
  }
  if (kept && Date.parse(kept.at) >= Date.parse(collection.updated_at)) return kept;
  const { lots, unknown } = await poolOf(collection, (n) => readShard(n, origin));
  const made = await db("rpc/owned_keep_pool", { method: "POST", body: { account, lots, unknown } }).catch(notYet);
  return made ? { ...made, unknown, at: new Date().toISOString() } : null;
}
