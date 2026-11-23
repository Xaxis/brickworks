// What every remix shared before supabase/remix_changes.sql changed from the
// model it was copied from, counted and kept (remixdiff, 2026-11-23): a
// remix published after the file is applied is counted as it is published
// (api/share.js); those published before are counted here, once, by the
// site's owner.
//
//   node --env-file=.env tools/web/remix_backfill.mjs --dry --current=FILE    reads only: what it would keep
//   node --env-file=.env tools/web/remix_backfill.mjs --current=FILE          after remix_changes.sql is applied
//       [--recount]   every remix again, counted ones too (after the rule for what changed changed)
//
// FILE is part_current.json as a web build writes it (<build>/part_names,
// tools/export.sh, src/dev/write_part_names.gd): each part LDraw draws in
// one colour only as the app reads it, so an old file counts as the app's
// Compare counts it. A deployment has it beside its functions; a checkout
// only once it is exported, so it is asked for, and the tool stops without.
//
// Each remix is counted by the same countRemix the publish runs: the
// remix's newest version (its own file, from the shared-models bucket, with
// the secret key) against the version of the original its app said it was
// copied from, else the newest there was when it was first shared. Two
// files read per remix, once. With --dry nothing is written or taken away,
// and nothing is asked of a table the file adds.
import { readFileSync } from "node:fs";
import { countRemix } from "../../api/_remix.js";
import { useCurrent } from "../../api/_parts.js";
import { changeLine } from "../../api/_remix_changes.js";

const flag = (name) => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3);
const dry = process.argv.includes("--dry");
const recount = process.argv.includes("--recount");
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET) {
  console.error("remix_backfill: no SUPABASE_URL / SUPABASE_SECRET_KEY: run it with --env-file=.env");
  process.exit(2);
}
const current = flag("current");
if (!current) {
  console.error("remix_backfill: no --current=FILE: give it a web build's part_names/part_current.json "
    + "(godot --headless --path . --script src/dev/write_part_names.gd -- --out=DIR writes one)");
  process.exit(2);
}
const table = JSON.parse(readFileSync(current, "utf8"));
if (!table || typeof table.parts !== "object") {
  console.error(`remix_backfill: ${current} is not a part_current.json ({format, parts})`);
  process.exit(2);
}
useCurrent(table.parts);
const headers = { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" };

async function rest(path) {
  const reply = await fetch(`${SUPABASE}/rest/v1/${path}`, { headers, signal: AbortSignal.timeout(30000) });
  if (!reply.ok) throw new Error(`${path.split("?")[0]}: ${reply.status} ${(await reply.text()).slice(0, 160)}`);
  const text = await reply.text();
  return text ? JSON.parse(text) : null;
}

/// A file of the shared-models bucket, as api/share.js getFile reads it: null for none.
async function getFile(name) {
  const reply = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${name}`, { headers,
    signal: AbortSignal.timeout(30000) });
  if (reply.status === 400 || reply.status === 404) return null;
  if (!reply.ok) throw new Error(`storage GET ${name}: ${reply.status}`);
  return Buffer.from(await reply.arrayBuffer());
}

const remixes = await rest("shared_models?remixed_from=not.is.null&published=is.true"
  + "&select=id,remixed_from&order=created_at.asc&limit=10000");
const counted = dry || recount ? new Set()
  : new Set((await rest("remix_changes?select=model&limit=10000")).map((row) => row.model));
console.log(`${remixes.length} published remixes, ${counted.size} counted already${dry ? " (dry: nothing is kept)" : ""}`);
let done = 0;
let failed = 0;
for (const { id, remixed_from: from } of remixes) {
  if (counted.has(id)) continue;
  try {
    const [newest] = await rest(`share_versions?model=eq.${id}&select=n,remixed_from_version&order=n.desc&limit=1`);
    const n = newest?.n || 1;
    // Which version its app said it copied: the newest version that says.
    const [said] = await rest(`share_versions?model=eq.${id}&remixed_from_version=not.is.null`
      + "&select=remixed_from_version&order=n.desc&limit=1");
    const file = await getFile(`${id}.mpd`);
    if (!file) {
      console.log(`  --    ${id}: no file`);
      failed += 1;
      continue;
    }
    const row = await countRemix({ id, n, text: file.toString("utf8"), from, said: said?.remixed_from_version ?? null,
      since: null, getFile, keep: !dry });
    if (!row) {
      console.log(`  --    ${id}: against ${from}, which is not published or has no file: ${dry ? "would take" : "took"} its row away`);
      continue;
    }
    console.log(`  ${dry ? "would" : "kept "}  ${id} v${n} against ${from} v${row.against_n}${row.inferred ? " (by date)" : ""}: `
      + `${changeLine(row)}${row.turned ? `, ${row.turned} of them turned` : ""}; ${row.parts_was} parts to ${row.parts_now}, `
      + `${row.shown?.ghost ? `${row.shown.ghosts} ghosts packed` : "no ghosts"}`);
    done += 1;
  } catch (trouble) {
    console.log(`  --    ${id}: ${String(trouble?.message || trouble).slice(0, 200)}`);
    failed += 1;
  }
}
console.log(`remix_backfill: ${done} ${dry ? "would be kept" : "kept"}, ${failed} failed`);
process.exit(failed ? 1 : 0);
