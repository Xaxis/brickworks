// signin6: whether the database itself was slow to run the session reads (pg_stat_statements),
// read in a READ ONLY transaction; prints only counts and times, never a query's values.
//
//   set -a; . ./.env; set +a
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node bench/results/signin6-2026-11-25/slow.mjs
const pg = (await import(process.env.PG_MODULE || "pg")).default;
const client = new pg.Client({
  host: process.env.SUPABASE_POOLER || "aws-0-us-east-1.pooler.supabase.com", port: 5432,
  user: `postgres.${process.env.SUPABASE_PROJECT_REF}`, password: process.env.SUPABASE_DB_PASSWORD,
  database: "postgres", ssl: { rejectUnauthorized: false },
});
await client.connect();
await client.query("begin transaction read only");
try {
  const { rows } = await client.query(`select calls, round(mean_exec_time::numeric, 1) as mean_ms,
      round(max_exec_time::numeric, 1) as max_ms, stats_since,
      regexp_replace(left(query, 400), '.*(oc_session_of|session_standing|oauth_code_grant|way_set|oc_unlink|oc_claim|oc_bind_session|oc_keep_handle|way_may_try).*', '\\1') as fn
    from extensions.pg_stat_statements
    where query ~ '(oc_session_of|session_standing|oauth_code_grant|way_set|oc_unlink|oc_claim|oc_bind_session|oc_keep_handle|way_may_try)"?\\('
    order by max_exec_time desc limit 12`);
  for (const r of rows) console.log(`${r.fn}: ${r.calls} calls, mean ${r.mean_ms} ms, max ${r.max_ms} ms (since ${r.stats_since?.toISOString?.() || r.stats_since})`);
  const waits = await client.query(`select count(*)::int as n, wait_event_type, wait_event from pg_stat_activity
    where state <> 'idle' group by 2, 3 order by 1 desc limit 8`);
  for (const r of waits.rows) console.log(`now: ${r.n} active, waiting on ${r.wait_event_type || "-"} ${r.wait_event || ""}`);
} finally {
  await client.query("rollback");
  await client.end();
}
