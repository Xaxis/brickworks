// supabase/announce.sql in a test's Postgres (tests/fixtures/beta/pg.mjs),
// after the console's own files, for api_check.mjs here and the local
// server's stand-in (tools/web/announce_stand_in.mjs): the files themselves
// answer, as PostgREST calls them.
//
// The notifications' marks are stood in for, with the columns announce.sql
// reads. Its notification_rows reads the notifications' own files' tables,
// which this world does not hold: it is made unchecked and never run here;
// tools/announce_try.sql runs it on the project's own, rolled back.
import { readFileSync } from "node:fs";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS3, STAND_INS } from "../console/needs3.mjs";

export const MARKS = `
  create table if not exists public.notification_marks (account uuid primary key references auth.users (id) on delete cascade,
    seen_at timestamptz, read_at timestamptz, at timestamptz not null default now());
  create table if not exists public.feed_marks (account uuid primary key references auth.users (id) on delete cascade,
    seen_at timestamptz);
`;

const file = (name) => readFileSync(new URL(`../../../${name}`, import.meta.url), "utf8");

/// The world: pg.mjs's, with db.call(name, args) answering any public
/// function as PostgREST does, each call on a connection of a small pool
/// so two at once run at once (a double press is two).
export async function announceWorld() {
  const db = await startPostgres({ also: NEEDS3 });
  await db.q(STAND_INS);
  await db.q(file("supabase/console3.sql"));
  await db.q(MARKS);
  await db.q("set check_function_bodies = off");
  await db.q(file("supabase/announce.sql"));
  await db.q("set check_function_bodies = on");
  const pool = [];
  for (let at = 0; at < 4; at += 1) pool.push(await db.connect());
  let next = 0;
  db.call = async (name, args = {}) => {
    const names = Object.keys(args || {});
    if (!/^[a-z_]+$/.test(name) || names.some((key) => !/^[a-z_]+$/.test(key))) throw new Error(`rpc ${name}`);
    const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
    const client = pool[next++ % pool.length];
    const rows = (await client.query(`select * from public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`,
      values)).rows;
    const [{ set }] = (await client.query("select bool_or(proretset) as set from pg_proc where proname = $1", [name])).rows;
    const plain = rows.every((row) => Object.keys(row).length === 1 && "answer" in row);
    if (!set && rows.length === 1 && plain) return JSON.parse(JSON.stringify(rows[0].answer));
    return JSON.parse(JSON.stringify(plain ? rows.map((row) => row.answer) : rows));
  };
  const stop = db.stop;
  db.stop = async () => {
    for (const client of pool) await client.end().catch(() => {});
    await stop();
  };
  return db;
}
