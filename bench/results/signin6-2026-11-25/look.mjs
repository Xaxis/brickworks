// signin6: what production holds for the redesign, read in a READ ONLY transaction
// (nothing can be written): function bodies, columns, and counts only. No address,
// account id or session id is printed.
//
//   set -a; . ./.env; set +a
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node bench/results/signin6-2026-11-25/look.mjs [--defs=a,b]
const pg = (await import(process.env.PG_MODULE || "pg")).default;
const client = new pg.Client({
  host: process.env.SUPABASE_POOLER || "aws-0-us-east-1.pooler.supabase.com", port: 5432,
  user: `postgres.${process.env.SUPABASE_PROJECT_REF}`, password: process.env.SUPABASE_DB_PASSWORD,
  database: "postgres", ssl: { rejectUnauthorized: false },
});
await client.connect();
const q = async (sql, args = []) => (await client.query(sql, args)).rows;
await q("begin transaction read only");
try {
  const fns = ["way_set", "way_on", "way_signed_in", "way_bind", "way_links_of", "way_may_try", "way_session_of",
    "oc_session_of", "oc_unlink", "oc_bind_session", "oc_link", "oc_may_try", "oc_spend", "oc_end_session",
    "session_standing", "oauth_code_issue", "oauth_code_grant", "oauth_sweep", "admin_sign_out"];
  const wantDefs = new Set((process.argv.find((a) => a.startsWith("--defs=")) || "--defs=").slice(7).split(",").filter(Boolean));
  console.log("== functions");
  for (const name of fns) {
    const rows = await q(`select p.oid::regprocedure::text as sig, p.prosecdef, p.provolatile,
        has_function_privilege('anon', p.oid, 'execute') as anon,
        has_function_privilege('authenticated', p.oid, 'execute') as authed,
        has_function_privilege('service_role', p.oid, 'execute') as server,
        pg_get_functiondef(p.oid) as def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = $1`, [name]);
    if (!rows.length) console.log(`  ${name}: NOT THERE`);
    for (const r of rows) {
      console.log(`  ${r.sig}: definer=${r.prosecdef} volatile=${r.provolatile} anon=${r.anon} authenticated=${r.authed} service_role=${r.server}`);
      if (wantDefs.has(name) || wantDefs.has("all")) console.log(r.def.split("\n").map((l) => `      | ${l}`).join("\n"));
    }
  }
  console.log("== columns");
  for (const t of ["oauth_codes", "oauth_grants", "oauth_tokens", "way_sessions", "oc_sessions"]) {
    const cols = await q(`select column_name, data_type, is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = $1 order by ordinal_position`, [t]);
    console.log(`  ${t}: ${cols.map((c) => `${c.column_name} ${c.data_type}${c.is_nullable === "NO" ? " not null" : ""}`).join(", ")}`);
  }
  console.log("== constraints on oauth_tokens and oauth_grants");
  for (const r of await q(`select conrelid::regclass::text as t, conname, pg_get_constraintdef(oid) as def from pg_constraint
      where conrelid in ('public.oauth_tokens'::regclass, 'public.oauth_grants'::regclass, 'public.oauth_codes'::regclass) order by 1, 2`)) {
    console.log(`  ${r.t} ${r.conname}: ${r.def}`);
  }
  console.log("== counts");
  console.log("  oauth_codes:", JSON.stringify(await q("select count(*)::int as n, count(way)::int as with_way, count(oc_did)::int as with_oc from public.oauth_codes")));
  console.log("  oauth_grants:", JSON.stringify(await q("select count(*)::int as n, count(way)::int as with_way, count(oc_did)::int as with_oc from public.oauth_grants")));
  console.log("  way_sessions:", JSON.stringify(await q("select way, count(*)::int as n from public.way_sessions group by 1")));
  console.log("  way_attempts kinds:", JSON.stringify(await q(
    "select split_part(try_key, ' ', 1) as kind, count(*)::int as n from public.way_attempts group by 1 order by 1")));
} finally {
  await q("rollback");
  await client.end();
}
