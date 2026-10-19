// Whether a SQL file that replaces the gallery's functions answers as the
// live ones do. Each of a set of directory_models queries, and every model's
// directory_card, is run on the live project, then again after the file
// inside a transaction that is rolled back; the answers are compared whole,
// the keys the file adds left out. Nothing is kept.
//
//   set -a; . ./.env; set +a
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
//     node tools/sql_compare.mjs supabase/play.sql moves
//
// directory_card and directory_models are defined in a dozen files and the
// last applied wins, so a unit that redefines them can drop what another
// added. Trial files check what a unit adds; this checks what it keeps.
// Play's file answered 16 of 16 the same (2026-10-19). Exits 1 on a
// difference or a failure.
import { readFileSync } from "node:fs";
const [file, newKeys = ""] = process.argv.slice(2);
const skip = new Set(newKeys.split(",").filter(Boolean));
const pg = (await import(process.env.PG_MODULE)).default;
const client = new pg.Client({ host: process.env.SUPABASE_POOLER || "aws-0-us-east-1.pooler.supabase.com", port: 5432,
  user: `postgres.${process.env.SUPABASE_PROJECT_REF}`, password: process.env.SUPABASE_DB_PASSWORD, database: "postgres",
  ssl: { rejectUnauthorized: false } });
await client.connect();
const queries = [
  {}, { tests: true }, { sort: "views" }, { sort: "builds" }, { sort: "top" }, { sort: "newest", size: 3 },
  { tests: true, sort: "top", size: 50 }, { technic: true }, { tests: true, technic: true }, { tested: true, tests: true },
  { words: "castle" }, { kind: "vehicle" }, { size_band: "small" }, { tests: true, page: 2, size: 2 }, { tests: true, sort: "builds", size: 100 },
];
const strip = (rows) => rows.map((r) => { const c = { ...(r.c || r) }; for (const k of skip) delete c[k]; return c; });
const run = async () => {
  const out = [];
  for (const q of queries) {
    const r = await client.query("select c from public.directory_models($1::jsonb) c", [JSON.stringify(q)]);
    out.push(strip(r.rows));
  }
  const cards = await client.query("select public.directory_card(m) as c from public.shared_models m order by m.id");
  out.push(strip(cards.rows));
  return out;
};
const before = await run();
await client.query("begin");
let after, failed = null;
try {
  await client.query(readFileSync(file, "utf8"));
  after = await run();
} catch (e) { failed = String(e); }
await client.query("rollback");
await client.end();
if (failed) { console.log("the file failed:", failed); process.exit(1); }
let same = 0, differ = [];
before.forEach((b, i) => {
  const name = i < queries.length ? JSON.stringify(queries[i]) : "every card";
  if (JSON.stringify(b) === JSON.stringify(after[i])) same += 1;
  else differ.push(`${name}: ${b.length} rows before, ${after[i].length} after; first difference ${JSON.stringify(b.find((x, j) => JSON.stringify(x) !== JSON.stringify(after[i][j]))).slice(0, 200)}`);
});
console.log(`${same} of ${before.length} answered the same (rows: ${before.map((b) => b.length).join(" ")}), rolled back`);
for (const d of differ) console.log("  DIFFERS " + d);
process.exit(differ.length ? 1 : 0);
