// Apply one supabase/*.sql file to the live project, as a migration, and
// say exactly what is there afterwards.
//
//   npm install --prefix /tmp/pg pg@8          once; pg is not a dependency here
//   set -a; . ./.env; set +a
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs supabase/collection.sql
//   ... --look                                  read only: what exists, change nothing
//   ... --dry [--try=FILE]                      the file run in a transaction that is
//                                               rolled back: what it would make, and FILE's
//                                               queries' rows, run after it inside it
//
// The file runs in one transaction, so a statement that fails leaves the
// database as it was. When the project has Supabase's migration table
// (supabase_migrations.schema_migrations, which the Supabase CLI keeps) the
// file is recorded there under today's date and its name; a project
// without one is not given one.
//
// Through Supabase's IPv4 pooler (session mode, port 5432, user
// postgres.<ref>): the direct host is IPv6-only and this machine has no
// IPv6 (HANDOFF.md, 2026-10-11).
//
// What it prints afterwards is read back from the catalogue, not from the
// file: the table's columns, its constraints, row security, the policies
// and the grants — the record of what was created is what the database
// says it has.

import { readFileSync } from "node:fs";
import { basename } from "node:path";

const file = process.argv.find((a) => !a.startsWith("--") && a.endsWith(".sql"));
const lookOnly = process.argv.includes("--look");
const dry = process.argv.includes("--dry");
const trial = (process.argv.find((a) => a.startsWith("--try=")) || "").slice(6);
const table = (process.argv.find((a) => a.startsWith("--table=")) || "--table=collections").slice(8);
if (!file && !lookOnly) {
  console.error("apply_sql: name a supabase/*.sql file, or --look");
  process.exit(2);
}
const ref = process.env.SUPABASE_PROJECT_REF;
const password = process.env.SUPABASE_DB_PASSWORD;
if (!ref || !password) {
  console.error("apply_sql: no SUPABASE_PROJECT_REF / SUPABASE_DB_PASSWORD — source .env");
  process.exit(2);
}
const pg = (await import(process.env.PG_MODULE || "pg")).default;
const client = new pg.Client({
  host: process.env.SUPABASE_POOLER || "aws-0-us-east-1.pooler.supabase.com",
  port: 5432,
  user: `postgres.${ref}`,
  password,
  database: "postgres",
  ssl: { rejectUnauthorized: false },
});
await client.connect();
const rows = async (sql, args = []) => (await client.query(sql, args)).rows;

/// What the table is now, read back from the catalogue.
async function look() {
  const columns = await rows(
    `select column_name, data_type, is_nullable, column_default
       from information_schema.columns
      where table_schema = 'public' and table_name = $1 order by ordinal_position`, [table]);
  if (columns.length === 0) {
    console.log(`public.${table}: not there`);
  } else {
    console.log(`public.${table}:`);
    for (const c of columns) {
      console.log(`  ${c.column_name} ${c.data_type}${c.is_nullable === "NO" ? " not null" : ""}` +
        `${c.column_default ? ` default ${c.column_default}` : ""}`);
    }
    for (const c of await rows(
      `select conname, pg_get_constraintdef(oid) as def from pg_constraint
        where conrelid = ('public.' || $1)::regclass order by conname`, [table])) {
      console.log(`  constraint ${c.conname}: ${c.def}`);
    }
    const rls = await rows(
      "select relrowsecurity from pg_class where oid = ('public.' || $1)::regclass", [table]);
    console.log(`  row level security: ${rls[0].relrowsecurity ? "on" : "OFF"}`);
    for (const p of await rows(
      `select policyname, cmd, roles::text, qual, with_check from pg_policies
        where schemaname = 'public' and tablename = $1 order by policyname`, [table])) {
      console.log(`  policy ${p.policyname}: ${p.cmd} to ${p.roles}` +
        `${p.qual ? ` using ${p.qual}` : ""}${p.with_check ? ` check ${p.with_check}` : ""}`);
    }
    const grants = await rows(
      `select grantee, string_agg(privilege_type, ', ' order by privilege_type) as what
         from information_schema.role_table_grants
        where table_schema = 'public' and table_name = $1 group by grantee order by grantee`, [table]);
    for (const g of grants) console.log(`  grant ${g.grantee}: ${g.what}`);
    const count = await rows(`select count(*)::int as n from public.${table.replace(/[^a-z_]/g, "")}`);
    console.log(`  rows: ${count[0].n}`);
  }
}

try {
  if (dry) {
    // Everything in one transaction, and none of it kept: the file, the
    // trial queries after it, and the look at what the table would be.
    await client.query("begin");
    try {
      await client.query(readFileSync(file, "utf8"));
      console.log(`dry run: ${file} ran`);
      if (trial) {
        for (const statement of readFileSync(trial, "utf8").split(/;\s*\n/).map((s) => s.trim()).filter(Boolean)) {
          const said = await client.query(statement);
          const first = statement.split("\n").find((line) => line.trim() && !line.trim().startsWith("--")) || statement;
          console.log(`try: ${first.trim().slice(0, 100)}`);
          for (const row of said.rows || []) console.log(`  ${JSON.stringify(row)}`);
        }
      }
      await look();
    } finally {
      await client.query("rollback");
      console.log("dry run: rolled back, nothing kept");
    }
  } else if (!lookOnly) {
    const text = readFileSync(file, "utf8");
    const tracked = (await rows("select to_regclass('supabase_migrations.schema_migrations') as t"))[0].t;
    await client.query("begin");
    try {
      await client.query(text);
      if (tracked) {
        const stamp = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
        await client.query(
          "insert into supabase_migrations.schema_migrations (version, name, statements) values ($1, $2, $3)",
          [stamp, basename(file, ".sql"), [text]],
        );
        console.log(`recorded as migration ${stamp} ${basename(file, ".sql")}`);
      } else {
        console.log("no supabase_migrations.schema_migrations here: applied, not recorded there");
      }
      await client.query("commit");
      console.log(`applied ${file}`);
    } catch (error) {
      await client.query("rollback");
      throw error;
    }
  }

  if (!dry) await look();
} finally {
  await client.end();
}
