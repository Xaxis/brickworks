// The part count every published model keeps, as its page counts it
// (web295): a card shows the count kept when the model was published, and
// until web295 a publish kept the file's part lines (checkModel), not the
// parts a builder buys (api/_parts.js inventoryOf: sub-models expanded, a
// sticker counted, a hose once), which the page has said since site278.
// 10243-1's card said 2,479 and its page 2,458. A publish keeps the page's
// count now (api/share.js piecesIn); those published before are counted
// here, once, and written as SQL for the site's owner to apply.
//
//   node --env-file=.env tools/web/parts_backfill.mjs [--out=supabase/parts_counted.sql]
//   [--facts=FILE]   tools/web/part_facts.mjs's table, where no catalogue is beside api/
//
// It reads only: every published model's row and versions, and each
// version's file from the shared-models bucket with the secret key, counted
// by the very function a publish uses. It writes one update a count that
// differs, each held to the row as it was read (its count, and the model's
// updated_at), so a model published again since is left as that publish
// kept it. Then, as for any SQL file:
//
//   node tools/apply_sql.mjs supabase/parts_counted.sql --dry   rolled back: what it would change
import { readFileSync, writeFileSync } from "node:fs";
import { piecesIn } from "../../api/share.js";
import { partsTable, useTable } from "../../api/_parts.js";

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET) {
  console.error("parts_backfill: no SUPABASE_URL / SUPABASE_SECRET_KEY: run it with --env-file=.env");
  process.exit(2);
}
const out = (process.argv.find((a) => a.startsWith("--out=")) || "--out=supabase/parts_counted.sql").slice(6);
const named = (process.argv.find((a) => a.startsWith("--facts=")) || "").slice(8);
if (named) useTable(JSON.parse(readFileSync(named, "utf8")));
if (!partsTable()) {
  console.error("parts_backfill: no parts table: run it in a checkout with assets/generated, or give --facts=FILE");
  process.exit(2);
}
const headers = { apikey: SECRET, authorization: `Bearer ${SECRET}` };

async function rest(path) {
  const reply = await fetch(`${SUPABASE}/rest/v1/${path}`, { headers, signal: AbortSignal.timeout(30000) });
  if (!reply.ok) throw new Error(`${path.split("?")[0]}: ${reply.status} ${(await reply.text()).slice(0, 160)}`);
  return reply.json();
}

async function file(name) {
  const reply = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${name}`, { headers,
    signal: AbortSignal.timeout(60000) });
  return reply.ok ? reply.text() : null;
}

/// Every row of [table] [query] asks for, a thousand at a time.
async function all(table, query) {
  const rows = [];
  for (let from = 0; ; from += 1000) {
    const page = await rest(`${table}?${query}&limit=1000&offset=${from}`);
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
}

const quoted = (text) => `'${String(text).replace(/'/g, "''")}'`;
const models = await all("shared_models", "published=is.true&select=id,name,parts,updated_at&order=created_at.asc");
const versions = await all("share_versions", "select=model,n,parts&order=model.asc,n.asc");
const versionsOf = new Map();
for (const one of versions) {
  if (!versionsOf.has(one.model)) versionsOf.set(one.model, []);
  versionsOf.get(one.model).push(one);
}
const lines = [];
let counted = 0;
let changed = 0;
let unread = 0;
for (const model of models) {
  const kept = versionsOf.get(model.id) || [];
  const newest = kept.length ? kept[kept.length - 1].n : 1;
  // The newest version's file is the link's own; an older one's is named for its number.
  for (const one of [...kept.filter((v) => v.n !== newest), { model: model.id, n: newest, parts: null, newest: true }]) {
    const text = await file(one.n === newest ? `${model.id}.mpd` : `${model.id}.v${one.n}.mpd`);
    if (text === null) {
      console.log(`  --    ${model.id} v${one.n}: no file`);
      unread += 1;
      continue;
    }
    // None where nothing in it is a part the catalogue knows: left as kept.
    const pieces = piecesIn(text, null);
    if (pieces === null) {
      console.log(`  --    ${model.id} v${one.n}: no part counted, left as kept`);
      unread += 1;
      continue;
    }
    counted += 1;
    if (one.newest) {
      if (pieces !== model.parts) {
        changed += 1;
        console.log(`  ${model.id} "${model.name}": ${model.parts} -> ${pieces}`);
        lines.push(`update public.shared_models set parts = ${pieces} where id = ${quoted(model.id)} `
          + `and parts = ${model.parts} and updated_at = ${quoted(model.updated_at)};`);
      }
      const row = kept.find((v) => v.n === newest);
      if (row && row.parts !== pieces) {
        lines.push(`update public.share_versions set parts = ${pieces} where model = ${quoted(model.id)} `
          + `and n = ${newest} and parts = ${row.parts};`);
      }
    } else if (one.parts !== pieces) {
      lines.push(`update public.share_versions set parts = ${pieces} where model = ${quoted(model.id)} `
        + `and n = ${one.n} and parts = ${one.parts};`);
    }
  }
}
const said = `${models.length} published models, ${counted} files counted, ${changed} models' counts and `
  + `${lines.length - changed} versions' to change${unread ? `, ${unread} left as they were` : ""}`;
writeFileSync(out, `-- The part count each published model keeps, as its page counts it
-- (web295, tools/web/parts_backfill.mjs): ${said}, read ${new Date().toISOString().slice(0, 10)}.
--
-- Data only: no table, function or grant is made or changed. Each update
-- is held to the row as it was read (its count, and the model's updated_at),
-- so a model published again since keeps what that publish kept.
--
--   node tools/apply_sql.mjs supabase/parts_counted.sql --dry
--   node tools/apply_sql.mjs supabase/parts_counted.sql

${lines.join("\n")}
`);
console.log(`parts_backfill: ${said}; written to ${out}`);
