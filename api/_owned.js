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
// sub-model a file names and does not carry), and neither is a sticker, a
// link of a hose drawn link by link, or a piece LDraw draws a bigger part
// with (Collection.ownable): each is left out of what a model needs, as
// the app leaves it out.

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

/// Whether anybody owns a catalogue part on its own, as Collection.ownable
/// says: not a sticker (it comes on its set's sheet), not a link of a chain
/// or a hose drawn link by link, and not a piece LDraw draws a bigger part
/// with and names with a ~ (a train wheel's axle), unless the ~ only says
/// the number moved or is obsolete. A moved number is judged by the part it
/// means today (deriveOwnedFacts).
export function ownable(part) {
  const name = String(part.name || "");
  if (part.category === "Sticker" || String(part.kind || "").includes("Flexible_Section")) return false;
  return !name.startsWith("~") || Boolean(part.moved_to) || name.includes("(Obsolete)");
}

/// What _part_facts.json holds for these sums, from the catalogue and the
/// colours: the parts anybody owns, the numbers LDraw moved, and the
/// colours a shop files under another.
export function deriveOwnedFacts(catalogue, colours) {
  const known = [];
  const moved = {};
  const byId = new Map((catalogue.parts || []).map((part) => [String(part.id), part]));
  for (const part of catalogue.parts || []) {
    let today = part;
    for (let hop = 0; hop < 8 && today.moved_to && byId.has(String(today.moved_to)); hop++) today = byId.get(String(today.moved_to));
    if (ownable(today)) known.push(String(part.id));
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

/// A part and colour in the one spelling: {key, part, colour}, or null for
/// a colour that is none, or a part the catalogue does not know when there
/// is a catalogue to ask.
function spelled(rawPart, rawColour, given = ownedFacts()) {
  const colour = Number(rawColour);
  if (!Number.isInteger(colour) || colour < 0) return null;
  const id = String(rawPart || "").toLowerCase().replace(/\.dat$/, "");
  if (!id || (given.known && !given.known.has(id))) return null;
  const part = familyOf(resolvePart(id, given));
  const code = plainColour(colour, given);
  return { key: `${part}/${code}`, part, colour: code };
}

/// [lots] ([part, colour, qty] or {part, colour, qty}) in the one spelling,
/// the same key counted once: [{part, colour, qty}]. A part the catalogue
/// does not know is left out, when there is a catalogue to ask.
export function keyed(lots, given = ownedFacts()) {
  const out = new Map();
  for (const lot of lots) {
    const [rawPart, rawColour, rawQty] = Array.isArray(lot) ? lot : [lot.part, lot.colour, lot.qty];
    const qty = Number(rawQty);
    const at = Number.isInteger(qty) && qty >= 1 ? spelled(rawPart, rawColour, given) : null;
    if (!at) continue;
    const held = out.get(at.key);
    if (held) held.qty += qty;
    else out.set(at.key, { part: at.part, colour: at.colour, qty });
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

/// How many of a set entry's copies a kept "built" says stand built
/// (keptbuilt): a whole number, from none to its copies. Anything else (a
/// string, true, 1.5) is none, as Collection.built_count reads it: one rule
/// for the app, poolOf and the API's ops.
export function builtCount(entry) {
  const value = entry?.built;
  if (entry?.fig === true || typeof value !== "number" || !Number.isInteger(value)) return 0;
  return Math.min(Math.max(1, Number(entry.qty) || 1), Math.max(0, value));
}

/// Everything on hand, as Collection.pool counts it: the loose parts, and
/// each set's parts (its spares too when the person said they kept them)
/// times how many of it, less the copies kept built on a shelf, whose spares
/// stay (keptbuilt), and less the parts marked missing, which come off the
/// copies still apart as far as those hold them (mysets). A set is counted
/// once by its number, all its entries together, so which entry holds a
/// mark changes nothing (kbfix). {lots: [{part, colour, qty}], unknown:
/// [set numbers no inventory has]}. [read] is readShard, or a probe's own.
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
  // Each number's copies, those kept built, those whose spares were kept,
  // and its missing marks, every entry's.
  const numbers = new Map();
  for (const one of sets) {
    const number = String(one.set);
    const held = numbers.get(number) || { copies: 0, built: 0, spares: 0, missing: [] };
    const copies = Math.max(1, Number(one.qty) || 1);
    held.copies += copies;
    held.built += builtCount(one);
    if (one.spares) held.spares += copies;
    for (const lot of Array.isArray(one.missing) ? one.missing : []) if (lot && typeof lot === "object") held.missing.push(lot);
    numbers.set(number, held);
  }
  for (const [number, held] of numbers) {
    const record = shards.get(shardOf(number))?.sets?.[number.toLowerCase()];
    if (!record) {
      unknown.push(number);
      continue;
    }
    const apart = held.copies - held.built;
    // Marked against the inventory's lots, never its spares: what is missing
    // past the apart copies' lots is missing from a copy on the shelf.
    const gone = new Map(keyed(held.missing).map((lot) => [`${lot.part}/${lot.colour}`, lot.qty]));
    for (const [part, colour, qty] of record.p || []) {
      const count = Number(qty) * apart;
      const key = spelled(part, colour)?.key;
      const taken = Math.min(count, gone.get(key) || 0);
      if (taken > 0) gone.set(key, gone.get(key) - taken);
      lots.push([part, colour, count - taken]);
    }
    for (const [part, colour, qty] of record.s || []) lots.push([part, colour, Number(qty) * held.spares]);
  }
  return { lots: keyed(lots), unknown };
}

/// The rule poolOf counts by, kept with each pool (supabase/pool_rule.sql):
/// 1 the sets' parts, 2 less the copies kept built and the parts marked
/// missing (kbfix). A pool kept by an older rule is counted again.
export const POOL_RULE = 2;

const notYet = (trouble) => (/: 404$/.test(String(trouble?.message || "")) ? null : Promise.reject(trouble));

/// [account]'s pool as the gallery counts it, counted again first when
/// their collection changed since it was, when it was counted by an older
/// rule ([POOL_RULE]), or when it never was: {lots, pieces, unknown, rule,
/// at}, or null for nobody with a collection, and before
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
  // A pool with no rule is from before pool_rule.sql was applied, which
  // can tell no rule from another: it is kept as it was.
  const ruled = !kept || kept.rule === undefined || Number(kept.rule) >= POOL_RULE;
  if (kept && ruled && Date.parse(kept.at) >= Date.parse(collection.updated_at)) return kept;
  const { lots, unknown } = await poolOf(collection, (n) => readShard(n, origin));
  const keep = (body) => db("rpc/owned_keep_pool", { method: "POST", body }).catch(notYet);
  const made = await keep({ account, lots, unknown, rule: POOL_RULE }) ?? await keep({ account, lots, unknown });
  return made ? { ...made, unknown, rule: POOL_RULE, at: new Date().toISOString() } : null;
}
