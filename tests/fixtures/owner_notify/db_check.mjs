// supabase/owner_notify.sql in a Postgres of its own (tests/fixtures/beta/pg.mjs),
// applied twice: what the database itself keeps of the owner's
// notifications. No role a page or a visitor has reaches any table; the
// server's does; an event is kept once by its key; each check refuses in its
// own name; a mail deleted leaves its events. supabase/owner_notify2.sql,
// applied twice more over the rows there, adds its one column and keeps
// them. What tests/test_owner_notify.py asks.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/owner_notify/db_check.mjs
import { readFileSync } from "node:fs";
import { startPostgres } from "../beta/pg.mjs";

const out = {};
const db = await startPostgres({ also: ["supabase/owner_notify.sql", "supabase/owner_notify.sql"] });
/// [sql] as [role]: "ok", "denied", or the database's words.
async function as(role, sql) {
  const client = await db.connect();
  try {
    await client.query("begin");
    await client.query(`set local role ${role}`);
    await client.query(sql);
    await client.query("rollback");
    return "ok";
  } catch (trouble) {
    await client.query("rollback").catch(() => {});
    const said = String(trouble?.message || trouble);
    return /permission denied/.test(said) ? "denied" : said.slice(0, 160);
  } finally {
    await client.end?.().catch(() => {});
  }
}
/// [sql] run: "kept", or the name of the constraint that refused it.
const refused = async (sql) => {
  try {
    await db.q(sql);
    return "kept";
  } catch (trouble) {
    return String(trouble?.constraint || trouble?.message || trouble);
  }
};
try {
  // As Supabase makes it: the secret key's role is past row security.
  await db.q("alter role service_role bypassrls");
  const TABLES = ["owner_notify_settings", "owner_notify_mails", "owner_notify_events", "owner_notify_errors"];
  out.tables = (await db.q("select relname, relrowsecurity from pg_class where relname like 'owner_notify_%' and relkind = 'r' order by relname"))
    .map((one) => `${one.relname}:${one.relrowsecurity}`);
  out.policies = Number(await db.one("select count(*) from pg_policies where tablename like 'owner_notify_%'"));
  out.reach = {};
  for (const table of TABLES) {
    out.reach[table] = [await as("anon", `select * from public.${table}`), await as("authenticated", `select * from public.${table}`),
      await as("service_role", `select * from public.${table}`)];
  }
  // The server's writes, as api/_notify.js makes them (identity ids included).
  out.server_writes = [
    await as("service_role", "insert into public.owner_notify_events (scope, test, event, key) values ('live', true, 'feedback', 'sr1')"),
    await as("service_role", "insert into public.owner_notify_errors (scope, fn, status) values ('live', 'share', 500)"),
    await as("service_role", "insert into public.owner_notify_settings (scope, test) values ('sr.example', false)"),
    await as("service_role", "update public.owner_notify_events set state = 'held' where key = 'sr1'"),
    await as("service_role", "delete from public.owner_notify_errors where status = 500"),
    await as("anon", "insert into public.owner_notify_events (scope, test, event, key) values ('live', true, 'feedback', 'an1')"),
  ];
  out.fk_to_users = Number(await db.one(`select count(*) from pg_constraint c join pg_class r on r.oid = c.conrelid
    where r.relname like 'owner_notify_%' and c.contype = 'f' and c.confrelid = 'auth.users'::regclass`));

  // Settings: a row's own key, made here, and its version from 0.
  await db.q("insert into public.owner_notify_settings (scope, test) values ('live', true)");
  const row = (await db.q("select off_key, version, pending_tries, settings from public.owner_notify_settings where scope = 'live'"))[0];
  out.settings_made = { key: /^[0-9a-f]{64}$/.test(row.off_key), version: row.version, tries: row.pending_tries,
    settings: JSON.stringify(row.settings) };
  out.two_keys_differ = await refused("insert into public.owner_notify_settings (scope, test) values ('live', false)") === "kept"
    && Number(await db.one("select count(distinct off_key) from public.owner_notify_settings")) === 2;
  out.settings_refused = [
    await refused("insert into public.owner_notify_settings (scope) values ('Brickworks.DIY')"),
    await refused("update public.owner_notify_settings set address = 'not an address' where scope = 'live' and test"),
    await refused("update public.owner_notify_settings set pending_address = 'a@resend.dev' where scope = 'live' and test"),
    await refused("update public.owner_notify_settings set settings = '[]' where scope = 'live' and test"),
    await refused("update public.owner_notify_settings set version = -1 where scope = 'live' and test"),
    await refused("update public.owner_notify_settings set pending_tries = 11 where scope = 'live' and test"),
  ];

  // Events: once by their key; each refusal by its constraint's name.
  const event = (key, extra = "") => `insert into public.owner_notify_events (scope, test, event, key${extra ? `, ${extra.split("=")[0]}` : ""})
    values ('live', true, 'signup', '${key}'${extra ? `, ${extra.split("=").slice(1).join("=")}` : ""}) on conflict (scope, test, event, key) do nothing`;
  await db.q(event("a1"));
  await db.q(event("a1"));
  out.once = Number(await db.one("select count(*) from public.owner_notify_events where key = 'a1'"));
  out.event_states = [];
  for (const state of ["new", "held", "capped", "digest", "sending", "mailed", "off", "paused", "failed"]) {
    out.event_states.push(await refused(`update public.owner_notify_events set state = '${state}' where key = 'a1'`));
  }
  out.events_refused = [
    await refused("insert into public.owner_notify_events (scope, event, key) values ('live', 'lunch', 'x')"),
    await refused("update public.owner_notify_events set state = 'lost' where key = 'a1'"),
    await refused("insert into public.owner_notify_events (scope, event, key) values ('live', 'signup', '')"),
    await refused(`insert into public.owner_notify_events (scope, event, key, detail) values ('live', 'signup', 'big',
      jsonb_build_object('words', repeat('x', 6000)))`),
    await refused("insert into public.owner_notify_events (scope, event, key, detail) values ('live', 'signup', 'arr', '[]')"),
    await refused("insert into public.owner_notify_events (scope, event, key, mail) values ('live', 'signup', 'nomail', 'nosuchmail00')"),
  ];

  // Mails: kept with their events; a mail deleted leaves the events, unlinked.
  await db.q(`insert into public.owner_notify_mails (id, scope, test, kind, event, subject, body, events, sent_to, state)
    values ('abcdefabcdef', 'live', true, 'now', 'signup', '1 new sign-up', 'words', 1, 'de•••@resend.dev', 'sent')`);
  await db.q("update public.owner_notify_events set state = 'mailed', mail = 'abcdefabcdef' where key = 'a1'");
  await db.q("delete from public.owner_notify_mails where id = 'abcdefabcdef'");
  out.after_mail_deleted = (await db.q("select state, mail from public.owner_notify_events where key = 'a1'"))[0];
  out.mails_refused = [
    await refused(`insert into public.owner_notify_mails (id, scope, kind, subject, sent_to, state) values ('SHOUTING0000', 'live', 'now', 's', 'x', 'sent')`),
    await refused(`insert into public.owner_notify_mails (id, scope, kind, subject, sent_to, state) values ('abcdefabcde1', 'live', 'sms', 's', 'x', 'sent')`),
    await refused(`insert into public.owner_notify_mails (id, scope, kind, subject, sent_to, state) values ('abcdefabcde2', 'live', 'now', 's', 'x', 'lost')`),
    await refused(`insert into public.owner_notify_mails (id, scope, kind, subject, sent_to, state, body) values ('abcdefabcde3', 'live', 'now', 's',
      'x', 'sent', repeat('x', 8001))`),
  ];

  // Errors: only 5xx, by a function's name.
  out.errors = [
    await refused("insert into public.owner_notify_errors (scope, fn, op, status) values ('live', 'share', 'publish', 503)"),
    await refused("insert into public.owner_notify_errors (scope, fn, status) values ('live', 'share', 404)"),
    await refused("insert into public.owner_notify_errors (scope, fn, status) values ('live', 'Share!', 500)"),
  ];

  // owner_notify2.sql, twice, over the rows above: one date column, null
  // until the prune writes it, every row and its settings kept.
  const rowsBefore = Number(await db.one("select count(*) from public.owner_notify_settings"));
  const second = readFileSync(new URL("../../../supabase/owner_notify2.sql", import.meta.url), "utf8");
  await db.q(second);
  await db.q(second);
  out.second = {
    column: (await db.q(`select data_type, is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'owner_notify_settings' and column_name = 'pruned_on'`))
      .map((one) => `${one.data_type}:${one.is_nullable}`),
    rows: Number(await db.one("select count(*) from public.owner_notify_settings")) === rowsBefore && rowsBefore > 0,
    nulls: Number(await db.one("select count(*) from public.owner_notify_settings where pruned_on is not null")),
    written: await refused("update public.owner_notify_settings set pruned_on = '2026-11-18' where scope = 'live' and test"),
  };
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 1500);
} finally {
  await db.stop();
}
process.stdout.write(`${JSON.stringify(out)}\n`);
