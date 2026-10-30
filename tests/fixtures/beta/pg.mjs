// A Postgres of its own, made, given supabase/beta.sql and thrown away: for
// db_check.mjs (the database itself) and api_check.mjs (the API against it).
//
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js   node's pg (npm install --prefix /tmp/pg pg@8)
//   PG_BIN=<a folder with initdb and postgres>        Admission's embedded Postgres has both:
//     ~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/
//     @embedded-postgres/linux-x64/native/bin
//   BETA_DB_DIR=<where its data goes>                 the system's temporary folder without it
//
// It listens on a socket in a folder of its own, never a port. Supabase's
// part is stood in for: its three roles, auth.users with the columns the
// file reads, and the two tables of models it counts.
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const SQL = readFileSync(path.join(here, "../../../supabase/beta.sql"), "utf8");

export async function startPostgres() {
  const pg = createRequire(import.meta.url)(process.env.PG_MODULE || "/tmp/pg/node_modules/pg/lib/index.js");
  const bin = process.env.PG_BIN;
  const lib = path.join(bin, "..", "lib");
  const env = { ...process.env, LD_LIBRARY_PATH: `${lib}${process.env.LD_LIBRARY_PATH ? `:${process.env.LD_LIBRARY_PATH}` : ""}` };
  // The socket's folder is short, under the system's own temporary folder:
  // a socket's path is at most 107 bytes.
  const dir = mkdtempSync(path.join(tmpdir(), "beta-"));
  const store = mkdtempSync(path.join(process.env.BETA_DB_DIR || tmpdir(), "beta-db-"));
  const data = path.join(store, "data");
  const made = spawnSync(path.join(bin, "initdb"), ["-D", data, "-U", "postgres", "-A", "trust", "--no-sync"], { env });
  if (made.status !== 0) throw new Error(`initdb: ${String(made.stderr).slice(0, 500)}`);
  const server = spawn(path.join(bin, "postgres"), ["-D", data, "-k", dir, "-c", "listen_addresses=", "-c", "fsync=off",
    "-c", "max_connections=60"], { env, stdio: ["ignore", "ignore", "pipe"] });
  let log = "";
  server.stderr.on("data", (chunk) => { log += chunk; });
  const connect = async () => {
    const client = new pg.Client({ host: dir, user: "postgres", database: "postgres" });
    await client.connect();
    return client;
  };
  let admin;
  for (let tries = 0; ; tries += 1) {
    try {
      admin = await connect();
      break;
    } catch (trouble) {
      if (tries > 100) throw new Error(log || String(trouble));
      await new Promise((done) => setTimeout(done, 100));
    }
  }
  const q = async (sql, params = [], client = admin) => (await client.query(sql, params)).rows;
  const one = async (sql, params = [], client = admin) => Object.values((await q(sql, params, client))[0] || {})[0];
  await q(`create role anon nologin; create role authenticated nologin; create role service_role nologin;
    create schema auth;
    create table auth.users (id uuid primary key, email text, created_at timestamptz not null default now(),
      email_confirmed_at timestamptz, last_sign_in_at timestamptz);
    create table public.account_models (owner uuid not null references auth.users (id) on delete cascade, name text);
    create table public.shared_models (owner uuid not null references auth.users (id) on delete cascade, id text);`);
  await q(SQL);
  let n = 0;
  return {
    q,
    one,
    connect,
    /// An account in auth.users: its id.
    async user(email, { made = "2026-11-01T00:00:00Z", confirmed = true } = {}) {
      n += 1;
      const id = `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
      await q("insert into auth.users (id, email, created_at, email_confirmed_at, last_sign_in_at) values ($1, $2, $3, $4, $4)",
        [id, email, made, confirmed ? made : null]);
      return id;
    },
    /// PostgREST's rpc for a public function: its named arguments, its answer.
    async rpc(name, args) {
      const names = Object.keys(args || {});
      if (names.some((key) => !/^p_[a-z_]+$/.test(key)) || !/^beta_[a-z_]+$/.test(name)) throw new Error(`no rpc ${name}`);
      const sql = `select public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`;
      const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
      return (await q(sql, values))[0].answer;
    },
    async stop() {
      await admin.end().catch(() => {});
      server.kill("SIGINT");
      await new Promise((done) => server.on("exit", done));
      rmSync(dir, { recursive: true, force: true });
      rmSync(store, { recursive: true, force: true });
    },
  };
}
