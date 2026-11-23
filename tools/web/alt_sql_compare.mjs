// Whether supabase/alt_builds.sql's gallery_models answers as the live one does
// for lists asked without its two filters: the dry run's answers
// (tools/alt_builds_try.sql's first select, in apply_sql.mjs --dry's log) held
// whole to the live project's, card by card.
//
//   node --env-file=.env tools/web/alt_sql_compare.mjs DRY.log
//
// Run straight after the dry run: a model liked or published between the two
// differs for that reason alone. Exits 1 on a difference.
import { readFileSync } from "node:fs";

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const log = process.argv[2];
if (!SUPABASE || !SECRET || !log) {
  console.error("alt_sql_compare: name the dry run's log, with --env-file=.env");
  process.exit(2);
}
const QUERIES = {
  newest: { sort: "newest", size: 49 },
  top: { sort: "top", size: 49 },
  "likes technic": { sort: "likes", size: 49, technic: true },
  "hand 200 up tests": { sort: "newest", size: 49, made: "hand", least: 200, tests: true },
};
const lines = readFileSync(log, "utf8").split("\n");
const at = lines.findIndex((line) => line.startsWith("try: select (select jsonb_agg(g) from public.gallery_models"));
const dry = at >= 0 ? JSON.parse(lines[at + 1].trim()) : null;
if (!dry) {
  console.error("alt_sql_compare: no gallery answers in the log");
  process.exit(1);
}
let differ = 0;
for (const [name, query] of Object.entries(QUERIES)) {
  const reply = await fetch(`${SUPABASE}/rest/v1/rpc/gallery_models`, { method: "POST", body: JSON.stringify({ query }),
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" } });
  const live = await reply.json();
  const was = dry[name] || [];
  const same = JSON.stringify(live) === JSON.stringify(was);
  differ += same ? 0 : 1;
  console.log(`${same ? "same" : "DIFFERS"}  ${name}: ${live.length} cards live, ${was.length} with the file`);
  if (!same) {
    for (let k = 0; k < Math.max(live.length, was.length); k += 1) {
      if (JSON.stringify(live[k]) !== JSON.stringify(was[k])) {
        console.log(`    first difference at card ${k}: live ${JSON.stringify(live[k]).slice(0, 200)} / file ${JSON.stringify(was[k]).slice(0, 200)}`);
        break;
      }
    }
  }
}
process.exit(differ ? 1 : 0);
