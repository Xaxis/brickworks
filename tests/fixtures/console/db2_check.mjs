// supabase/console2.sql itself, in pg.mjs's Postgres after the files it
// needs: what tests/test_console2.py asks of it.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/console/db2_check.mjs
//
// Prints one JSON object, each finding by name.
import { readFileSync } from "node:fs";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS } from "./needs2.mjs";

const db = await startPostgres({ also: [...NEEDS, "supabase/console2.sql"] });
/// A function called as PostgREST calls it: by its arguments' names.
db.rpc = async (name, args = {}) => {
  const names = Object.keys(args);
  const sql = `select public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`;
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" && !Array.isArray(args[key])
    ? JSON.stringify(args[key]) : args[key]));
  const rows = await db.q(sql, values);
  return rows.length === 1 ? rows[0].answer : rows.map((row) => row.answer);
};
const out = {};
try {
  // Applied again, nothing changes and nothing fails.
  await db.q(readFileSync(new URL("../../../supabase/console2.sql", import.meta.url), "utf8"));
  out.again = "ok";

  // Mail: an event kept once, however often it comes; another project's
  // never reaches here (the API keeps only brickworks.diy's).
  const keep = (event, email, type, at, extra = {}) => db.rpc("mail_event_keep", { p_event: event, p_email: email,
    p_type: type, p_at: at, p_address: extra.address ?? "ada@example.com", p_subject: extra.subject ?? "123456 is your code",
    p_kind: extra.kind ?? "sign_in_code", p_detail: extra.detail ?? null, p_test: extra.test ?? false });
  const now = Date.now();
  const iso = (minutes) => new Date(now - minutes * 60000).toISOString();
  out.kept = [await keep("msg_1", "e1", "sent", iso(30)), await keep("msg_1", "e1", "sent", iso(30)),
    await keep("msg_2", "e1", "delivered", iso(29))];
  await keep("msg_3", "e2", "sent", iso(20), { address: "bob@example.com", subject: "You're in the Brickworks beta", kind: "beta" });
  await keep("msg_4", "e2", "bounced", iso(19), { address: "bob@example.com", subject: "You're in the Brickworks beta", kind: "beta",
    detail: "Mailbox does not exist" });
  await keep("msg_5", "e3", "sent", iso(10), { address: "delivered@resend.dev", kind: "canary", test: true });
  await keep("msg_6", "e3", "delivered", iso(9), { address: "delivered@resend.dev", kind: "canary", test: true });
  out.bad_type = await keep("msg_7", "e4", "exploded", iso(5)).then(() => "kept", (t) => String(t.message).slice(0, 120));
  out.events = (await db.q("select count(*)::int as n from public.mail_events"))[0].n;

  // What Brickworks kept as sent: a beta mail, dry for a test inbox, and a
  // feedback answer sent with Resend's id e1.
  const ada = await db.user("ada@example.com");
  const tester = await db.user("t1@resend.dev");
  await db.q("insert into public.beta_mail (account, kind, state, sent_id, subject) values ($1, 'approved', 'sent', 'e2', "
    + "'You''re in the Brickworks beta'), ($2, 'received', 'dry', null, 'We have your Brickworks beta application')", [ada, tester]);
  const [fb] = await db.q("insert into public.feedback (account, kind, words, source) values ($1, 'bug', 'It broke', 'site') "
    + "returning id", [ada]);
  await db.q("insert into public.feedback_replies (feedback, words, by_email, mail, sent_id) values ($1, 'Fixed', "
    + "'owner@example.com', 'sent', 'e9')", [fb.id]);

  out.mail = await db.rpc("admin_mail", { p_days: 30, p_tests: false, p_limit: 100 });
  out.mail_tests = await db.rpc("admin_mail", { p_days: 30, p_tests: true, p_limit: 100 });
  // A year on, it goes at the next keep.
  await db.q("update public.mail_events set received_at = now() - interval '366 days' where event_id = 'msg_1'");
  await keep("msg_8", "e5", "sent", iso(1));
  out.after_a_year = (await db.q("select array_agg(event_id order by id) as ids from public.mail_events"))[0].ids;

  // Releases: kept, kept again when shipped again, listed latest first.
  out.release = await db.rpc("site_release_live", { p_tag: "rel-m290", p_sha: "9c1b25131", p_title: "Rows carried again",
    p_units: ["treedrag", "heldsteps"], p_live_at: "2026-11-12T08:40:34Z" });
  await db.rpc("site_release_live", { p_tag: "rel-m289", p_sha: "28178971c", p_title: "Titles keep everything",
    p_units: [], p_live_at: "2026-11-11T20:00:00Z" });
  out.release_again = await db.rpc("site_release_live", { p_tag: "rel-m290", p_sha: "9c1b25131", p_title: "Rows carried again",
    p_units: ["treedrag", "heldsteps", "f5"], p_live_at: "2026-11-12T09:00:00Z" });
  out.releases = await db.rpc("site_releases_list", { p_limit: 10 });
  out.bad_release = await db.rpc("site_release_live", { p_tag: "Not A Tag!", p_sha: "xyz", p_title: null, p_units: [],
    p_live_at: null }).then(() => "kept", (t) => String(t.message).slice(0, 120));

  // The connector's calls: a conversation's count and its account's day.
  await db.q("insert into public.relay_picks (key, owner, channel) values ('session:abc', $1, repeat('a', 64)), "
    + "('session:nobody', null, repeat('b', 64))", [ada]);
  out.calls = [await db.rpc("relay_call_note", { p_key: "session:abc", p_did: "look_at_model" }),
    await db.rpc("relay_call_note", { p_key: "session:abc", p_did: "place_part" }),
    await db.rpc("relay_call_note", { p_key: "session:nobody", p_did: "look_at_model" }),
    await db.rpc("relay_call_note", { p_key: "session:none", p_did: "look_at_model" })];
  out.pick = (await db.q("select calls, did, called_at is not null as called from public.relay_picks where key = 'session:abc'"))[0];
  out.days = await db.q("select calls, last_tool from public.relay_call_days");

  // A cron with no lock, written down.
  const run = await db.rpc("cron_noted", { job: "share_sweep", holder: "vercel", started_at: iso(1), outcome: "done",
    said: { gone: 3 } });
  out.cron = (await db.rpc("cron_runs_of", { job: "share_sweep", most: 5 }));
  out.cron_run = Number(run) > 0;

  // Admission's customers, from its snapshots: this mode's, never an emptied one's.
  const snap = (mode, who, value) => db.rpc("admission_snapshot_put", { p_key: `admission:v2:brickworks:${mode}:c:${who}`,
    p_value: value });
  await snap("test", ada, JSON.stringify({ at: 1, value: { plan: { key: "pro", name: "Pro", source: "override" } } }));
  await snap("test", tester, "");
  await snap("live", ada, JSON.stringify({ at: 1, value: { plan: { key: "free" } } }));
  await db.rpc("admission_snapshot_put", { p_key: "admission:v2:brickworks:test:plans", p_value: "{}" });
  out.customers_test = await db.rpc("admission_customers", { p_mode: "test", p_limit: 10 });
  out.customers_bad = await db.rpc("admission_customers", { p_mode: "x%", p_limit: 10 });

  // Nothing reachable but by the server.
  out.grants = await db.q(`select c.relname, c.relrowsecurity as rls,
      has_table_privilege('anon', c.oid, 'select') as anon, has_table_privilege('authenticated', c.oid, 'select') as signed_in
      from pg_class c where c.relname in ('mail_events', 'site_releases', 'relay_call_days') order by 1`);
  out.functions = await db.q(`select p.proname, p.prosecdef as definer, has_function_privilege('anon', p.oid, 'execute') as anon,
      has_function_privilege('authenticated', p.oid, 'execute') as signed_in,
      has_function_privilege('service_role', p.oid, 'execute') as server
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname in ('mail_event_keep', 'admin_mail', 'site_release_live', 'site_releases_list',
        'relay_call_note', 'cron_noted', 'admission_customers') order by 1`);
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 2000);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
