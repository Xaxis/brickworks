// signreview4: what production holds, read in a READ ONLY transaction (nothing can be written):
// whether its function bodies are the repo's, the foreign keys the redesign rests on, and
// blocks' policy and grants (orangecheck_check N1). Counts and definitions only: no address,
// account id or session id is printed.
//
//   set -a; . ./.env; set +a
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node bench/results/signreview4-2026-11-26/look4.mjs
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const pg = (await import(process.env.PG_MODULE || "pg")).default;
const client = new pg.Client({
  host: process.env.SUPABASE_POOLER || "aws-0-us-east-1.pooler.supabase.com", port: 5432,
  user: `postgres.${process.env.SUPABASE_PROJECT_REF}`, password: process.env.SUPABASE_DB_PASSWORD,
  database: "postgres", ssl: { rejectUnauthorized: false },
});
const ROOT = new URL("../../../", import.meta.url).pathname;
// The body between the $$ of each function in a repo file, whitespace folded.
const fold = (text) => text.replace(/\s+/g, " ").trim();
function repoBodies(file) {
  const text = readFileSync(`${ROOT}supabase/${file}`, "utf8");
  const out = new Map();
  for (const m of text.matchAll(/create (?:or replace )?function public\.(\w+)\([^$]*?\$\$([\s\S]*?)\$\$/g)) out.set(m[1], fold(m[2]));
  return out;
}
const repo = new Map([...repoBodies("way_links.sql"), ...repoBodies("way_grants.sql"), ...repoBodies("orangecheck.sql"),
  ...repoBodies("approving_session.sql")]);
await client.connect();
const q = async (sql, args = []) => (await client.query(sql, args)).rows;
await q("begin transaction read only");
try {
  console.log("== production's bodies against the repo's (the last file to define each)");
  for (const name of ["session_standing", "oauth_code_grant", "way_set", "way_signed_in", "way_bind", "way_may_try",
    "oc_unlink", "oc_bind_session", "oc_session_of", "oc_end_session"]) {
    const rows = await q(`select p.prosrc, p.prosecdef, p.provolatile,
        has_function_privilege('anon', p.oid, 'execute') as anon,
        has_function_privilege('authenticated', p.oid, 'execute') as authed
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = $1`, [name]);
    if (!rows.length) { console.log(`  ${name}: NOT THERE`); continue; }
    for (const r of rows) {
      const same = repo.has(name) && fold(r.prosrc) === repo.get(name);
      const h = createHash("sha256").update(fold(r.prosrc)).digest("hex").slice(0, 12);
      console.log(`  ${name}: ${same ? "same as the repo" : "DIFFERS from the repo"} (${h}), definer=${r.prosecdef} `
        + `volatile=${r.provolatile} anon=${r.anon} authenticated=${r.authed}`);
    }
  }
  console.log("== foreign keys to auth.sessions and auth.users from the sign-in tables");
  for (const r of await q(`select conrelid::regclass::text as t, conname, pg_get_constraintdef(oid) as def from pg_constraint
      where contype = 'f' and conrelid in ('public.oauth_codes'::regclass, 'public.oauth_grants'::regclass,
        'public.oauth_tokens'::regclass, 'public.way_sessions'::regclass, 'public.oc_sessions'::regclass,
        'public.relay_tabs'::regclass) order by 1, 2`)) {
    console.log(`  ${r.t} ${r.conname}: ${r.def}`);
  }
  console.log("== who may lock or delete auth.sessions (the definer of oauth_code_grant locks it for key share)");
  for (const r of await q(`select p.proname, pg_get_userbyid(p.proowner) as owner,
        has_table_privilege(pg_get_userbyid(p.proowner), 'auth.sessions', 'update') as can_update,
        has_table_privilege(pg_get_userbyid(p.proowner), 'auth.sessions', 'delete') as can_delete
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname in ('oauth_code_grant', 'session_standing', 'way_set')`)) {
    console.log(`  ${r.proname}: owner ${r.owner}, update ${r.can_update}, delete ${r.can_delete}`);
  }
  console.log("== public.blocks: row security, policies, table grants (orangecheck_check N1)");
  const rls = await q(`select relrowsecurity, relforcerowsecurity from pg_class where oid = 'public.blocks'::regclass`);
  console.log(`  row level security: ${JSON.stringify(rls[0])}`);
  for (const r of await q(`select policyname, roles::text, cmd, qual, with_check from pg_policies
      where schemaname = 'public' and tablename = 'blocks'`)) {
    console.log(`  policy ${r.policyname} for ${r.roles} ${r.cmd}: using ${r.qual} check ${r.with_check}`);
  }
  for (const role of ["anon", "authenticated", "service_role"]) {
    const privs = [];
    for (const p of ["select", "insert", "update", "delete"]) {
      const [r] = await q(`select has_table_privilege($1, 'public.blocks', $2) as y`, [role, p]);
      if (r.y) privs.push(p);
    }
    console.log(`  ${role} on public.blocks: ${privs.length ? privs.join(", ") : "nothing"}`);
  }
  const col = await q(`select count(*)::int as n from information_schema.column_privileges
      where table_schema = 'public' and table_name = 'blocks' and grantee in ('anon', 'authenticated')`);
  console.log(`  column grants to anon/authenticated on public.blocks: ${col[0].n}`);
  console.log("== the counts behind the limit (kinds only)");
  console.log("  way_attempts:", JSON.stringify(await q(
    "select split_part(try_key, ' ', 1) as kind, count(*)::int as n from public.way_attempts group by 1 order by 1")));
} finally {
  await q("rollback");
  await client.end();
}
