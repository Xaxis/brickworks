// What every published model needs, counted and kept for Build with what I
// own (supabase/discovery.sql model_needs): a model published after the
// file is applied is counted as it is published (api/share.js); those
// published before are counted here, once, by the site's owner.
//
//   node --env-file=.env tools/web/needs_backfill.mjs --dry    reads only: what it would keep
//   node --env-file=.env tools/web/needs_backfill.mjs          after discovery.sql is applied
//   node --env-file=.env tools/web/needs_backfill.mjs --recount   every published model again,
//       after the rule for what a model needs changed (owned_keep_needs replaces a model's rows)
//       [--facts=FILE]   tools/web/part_facts.mjs's output, where no catalogue is beside api/
//
// Each model is read as the server reads it (the link's own file, from the
// shared-models bucket, with the secret key) and counted by the same
// checkModel and keyed that publishing uses, so a model counts the same
// whichever counted it. With --dry it asks the database nothing it cannot
// answer before the file is applied: the published models, and their files.
import { readFileSync } from "node:fs";
import { checkModel } from "../../api/share.js";
import { keyed, ownedFacts, useFacts } from "../../api/_owned.js";

const dry = process.argv.includes("--dry");
// Counted ones too: m95 changed what a model needs (a set's own pieces by
// their Rebrickable names, minifig parts, stickers left out), and the
// models counted before kept the old count.
const recount = process.argv.includes("--recount");
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET) {
  console.error("needs_backfill: no SUPABASE_URL / SUPABASE_SECRET_KEY: run it with --env-file=.env");
  process.exit(2);
}
const headers = { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" };

async function rest(path, init = {}) {
  const reply = await fetch(`${SUPABASE}/rest/v1/${path}`, { ...init, headers, signal: AbortSignal.timeout(30000) });
  if (!reply.ok) throw new Error(`${path.split("?")[0]}: ${reply.status} ${(await reply.text()).slice(0, 160)}`);
  const text = await reply.text();
  return text ? JSON.parse(text) : null;
}

async function file(id) {
  const reply = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${id}.mpd`, { headers,
    signal: AbortSignal.timeout(30000) });
  return reply.ok ? reply.text() : null;
}

const named = (process.argv.find((a) => a.startsWith("--facts=")) || "").slice(8);
const facts = named ? useFacts(JSON.parse(readFileSync(named, "utf8"))) : ownedFacts();
console.log(`the catalogue's facts: ${facts.known ? `${facts.known.size} parts, ${facts.moved.size} moved, `
  + `${facts.plain.size} plain colours` : "none here, so every part is counted as it is named"}`);
let done = 0;
let failed = 0;
const seen = new Set();
for (;;) {
  const ids = dry || recount
    ? (await rest("shared_models?published=is.true&select=id&order=created_at.asc&limit=1000")).map((row) => row.id)
    : await rest("rpc/owned_uncounted", { method: "POST", body: JSON.stringify({ size: 50 }) });
  const fresh = ids.filter((id) => !seen.has(id));
  if (fresh.length === 0) break;
  for (const id of fresh) {
    seen.add(id);
    const text = await file(id);
    if (text === null) {
      console.log(`  --    ${id}: no file`);
      failed += 1;
      continue;
    }
    let counted;
    try {
      counted = checkModel(text);
    } catch (trouble) {
      console.log(`  --    ${id}: ${trouble.message}`);
      failed += 1;
      continue;
    }
    const lots = keyed(counted.needs);
    const pieces = lots.reduce((sum, lot) => sum + lot.qty, 0);
    if (!dry) await rest("rpc/owned_keep_needs", { method: "POST", body: JSON.stringify({ model_id: id, needs: lots }) });
    console.log(`  ${dry ? "would" : "kept "}  ${id}: ${counted.parts} parts, ${pieces} anybody can own, in ${lots.length} lots`);
    done += 1;
  }
  if (dry || recount) break;
}
console.log(`needs_backfill: ${done} ${dry ? "counted, nothing kept" : "kept"}${failed ? `, ${failed} not counted` : ""}`);
process.exit(0);
