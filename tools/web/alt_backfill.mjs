// Which real set builds every published model, counted and kept once
// (altbuilds, supabase/alt_builds.sql): a model published after the file is
// applied is counted as it is published (api/share.js); those before are
// counted here, by the site's owner, from what each needs as already kept
// (model_needs), never from its file.
//
//   node --env-file=.env tools/web/alt_backfill.mjs --dry   reads only: what it would keep
//   node --env-file=.env tools/web/alt_backfill.mjs         after alt_builds.sql is applied
//       [--out=FILE]     every model's count as JSON lines, for the report
//       [--files]        with --dry before the file: each model's needs from its
//                        published file (the shared-models bucket), as
//                        needs_backfill.mjs reads them, since model_needs is
//                        read only through the file's alt_needs_of
//
// Counted by the same api/_alts.js countRows the publish uses, against the
// sets' index of this checkout (the shards and the set catalogue). A model
// credited to the app's Library (modelled_by, api/_omr_credit.js) is held to
// the Library's models of its page, as the publish holds it: the one sharing
// the most of its parts, at least half of each, says whether it is a set's
// own model or another model of a set. The Library's index is read once
// from the parts store; its files from vendor/omr/files where they are.
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { ALT_RULE, altIndex, countRows, keepAlts, needsOf } from "../../api/_alts.js";
import { keyed } from "../../api/_owned.js";
import { LEAST_SHARED, storeRoot } from "../../api/_omr_credit.js";
import { checkModel } from "../../api/share.js";

const dry = process.argv.includes("--dry");
const fromFiles = process.argv.includes("--files");
const out = (process.argv.find((a) => a.startsWith("--out=")) || "").slice(6);
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET) {
  console.error("alt_backfill: no SUPABASE_URL / SUPABASE_SECRET_KEY: run it with --env-file=.env");
  process.exit(2);
}
const headers = { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" };

async function rest(path, init = {}) {
  const reply = await fetch(`${SUPABASE}/rest/v1/${path}`, { ...init, headers, signal: AbortSignal.timeout(30000) });
  if (!reply.ok) throw new Error(`${path.split("?")[0]}: ${reply.status} ${(await reply.text()).slice(0, 160)}`);
  const text = await reply.text();
  return text ? JSON.parse(text) : null;
}

const began = performance.now();
const index = altIndex();
if (!index) {
  console.error("alt_backfill: no sets' shards in this checkout (assets/generated/sets)");
  process.exit(1);
}
console.log(`the sets' index: ${index.sets.length} sets, ${index.keys.size} parts and colours`);

// The Library's models, by page, and what each needs (read when asked).
let library = null;
async function libraryOf(page) {
  if (!library) {
    const reply = await fetch(`${storeRoot()}library/index.json`, { signal: AbortSignal.timeout(30000) }).catch(() => null);
    const read = reply && reply.ok ? await reply.json().catch(() => null) : null;
    library = new Map();
    for (const entry of read?.models || []) {
      if (!entry || typeof entry.page !== "string") continue;
      if (!library.has(entry.page)) library.set(entry.page, []);
      library.get(entry.page).push(entry);
    }
  }
  return library.get(page) || [];
}
const needsOfEntry = new Map();
async function entryNeeds(entry) {
  if (needsOfEntry.has(entry.id)) return needsOfEntry.get(entry.id);
  const local = `vendor/omr/files/${String(entry.file).replace(/^library\/omr\//, "")}`;
  let text = existsSync(local) ? readFileSync(local, "utf8") : null;
  if (text === null) {
    const reply = await fetch(`${storeRoot()}${entry.file}`, { signal: AbortSignal.timeout(30000) }).catch(() => null);
    text = reply && reply.ok ? await reply.text() : null;
  }
  let lots = null;
  try {
    lots = text ? keyed(checkModel(text).needs) : null;
  } catch {
    lots = null;
  }
  needsOfEntry.set(entry.id, lots);
  return lots;
}

/// The Library's model [lots] is, of those of [page]: {set, alternate_of}, or null.
async function libraryWord(lots, page) {
  if (!page) return null;
  const mine = new Map(lots.map((lot) => [`${lot.part}/${lot.colour}`, lot.qty]));
  const all = lots.reduce((sum, lot) => sum + lot.qty, 0);
  let found = null;
  for (const entry of await libraryOf(page)) {
    const theirs = await entryNeeds(entry);
    if (!theirs) continue;
    let shared = 0;
    let total = 0;
    for (const lot of theirs) {
      total += lot.qty;
      shared += Math.min(lot.qty, mine.get(`${lot.part}/${lot.colour}`) || 0);
    }
    if (shared >= LEAST_SHARED * all && shared >= LEAST_SHARED * total && (!found || shared > found.shared)) {
      found = { shared, set: entry.set || null, alternate_of: entry.alternate_of || null, id: entry.id };
    }
  }
  return found;
}

// The models to count: before the file, every published one; after, those
// with needs kept and no count by this rule.
const published = await rest("shared_models?published=is.true&select=id,name,parts,listed,test,modelled_by&order=created_at.asc&limit=5000");
const rows = new Map(published.map((row) => [row.id, row]));
let ready = true;
try {
  await rest("rpc/alt_uncounted", { method: "POST", body: JSON.stringify({ rule: ALT_RULE, size: 1 }) });
} catch (trouble) {
  if (!/: 404/.test(String(trouble.message))) throw trouble;
  ready = false;
}
if (!ready && !dry) {
  console.error("alt_backfill: supabase/alt_builds.sql is not applied: run it with --dry, or apply the file first");
  process.exit(1);
}
const ids = ready && !dry
  ? await rest("rpc/alt_uncounted", { method: "POST", body: JSON.stringify({ rule: ALT_RULE, size: 500 }) })
  : published.map((row) => row.id);
console.log(`${ids.length} models to count${ready ? "" : " (alt_builds.sql not applied: --dry reads their files)"}`);
if (out) writeFileSync(out, "");

async function needsFor(batch) {
  if (ready && !fromFiles) return needsOf(batch);
  const found = new Map();
  for (const id of batch) {
    const reply = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${id}.mpd`, { headers, signal: AbortSignal.timeout(30000) });
    if (!reply.ok) continue;
    try {
      found.set(id, keyed(checkModel(await reply.text()).needs));
    } catch {
      // A file the publish would refuse has no needs kept either.
    }
  }
  return found;
}

const tally = { counted: 0, whole: 0, group: 0, best: 0, own: 0, library: 0, none: 0, cut: 0, failed: 0 };
let slowest = 0;
for (let at = 0; at < ids.length; at += 50) {
  const batch = ids.slice(at, at + 50);
  const needs = await needsFor(batch);
  await Promise.all(batch.map(async (id) => {
    const lots = needs?.get(id);
    const row = rows.get(id) || {};
    if (!lots || !lots.length) {
      tally.failed += 1;
      console.log(`  --    ${id}: no needs kept`);
      return;
    }
    const word = row.modelled_by?.page ? await libraryWord(lots, row.modelled_by.page) : null;
    const word2 = word ? { set: word.set, alternate_of: word.alternate_of } : null;
    const t0 = performance.now();
    const counted = dry ? countRows(lots, index, { library: word2, declared: [] })
      : await keepAlts(id, lots, { library: word2, index });
    slowest = Math.max(slowest, performance.now() - t0);
    if (!counted) {
      tally.failed += 1;
      console.log(`  --    ${id}: not kept`);
      return;
    }
    tally.counted += 1;
    if (counted.cut) tally.cut += 1;
    const roles = new Set(counted.rows.map((one) => one.role));
    for (const role of ["whole", "group", "best", "own", "library"]) if (roles.has(role)) tally[role] += 1;
    if (!counted.rows.length) tally.none += 1;
    const said = counted.rows.map((one) => `${one.role} ${one.set} ${one.have}/${counted.pieces}`).join(", ") || "none";
    console.log(`  ${dry ? "would" : "kept "}  ${id} ${String(row.name || "").slice(0, 40)}: ${said}${counted.cut ? " (cut)" : ""}`);
    if (out) appendFileSync(out, `${JSON.stringify({ id, name: row.name, listed: row.listed, test: row.test, library: word,
      pieces: counted.pieces, cut: counted.cut, rows: counted.rows })}\n`);
  }));
}
console.log(`alt_backfill: ${tally.counted} counted (${tally.whole} every part from one set, ${tally.group} from a group, `
  + `${tally.best} with a best set from 80%, ${tally.library} the Library's other model of a set, ${tally.own} a set's own model, `
  + `${tally.none} none), ${tally.cut} searches cut, ${tally.failed} not counted; slowest count ${slowest.toFixed(0)} ms; `
  + `${((performance.now() - began) / 1000).toFixed(1)} s in all`);
process.exit(tally.failed && !dry ? 1 : 0);
