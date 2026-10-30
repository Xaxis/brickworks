// supabase/feedback.sql, after beta.sql, in a Postgres of its own made and
// thrown away here (tests/fixtures/beta/pg.mjs): what tests/test_feedback.py
// asks of the database itself.
//
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js PG_BIN=<postgres's bin> \
//     node tests/fixtures/feedback/db_check.mjs
//
// Prints one JSON object, each scenario's findings by name.
import { readFileSync } from "node:fs";
import { startPostgres } from "../beta/pg.mjs";

const FILE = readFileSync(new URL("../../../supabase/feedback.sql", import.meta.url), "utf8");
const db = await startPostgres({ also: ["supabase/feedback.sql"] });
const { q, one, connect, user } = db;
const out = {};

const send = (account, email, { kind = "bug", place = "here", words = "The hinge turns the wrong way" } = {}) => one(
  "select public.feedback_send($1, $2, $3, $4, 'site', '/gallery', '{\"screen\": \"1280x800\"}', null, $5)",
  [account, email, kind, words, place]);

try {
  // Applying it again changes nothing.
  await q(FILE);
  out.bucket = await q("select id, public, file_size_limit::int as cap, allowed_mime_types as types from storage.buckets");

  // From an account: its address never copied; not a tester.
  const ada = await user("ada@example.com");
  out.from_account = await send(ada, null);
  out.kept_row = await q("select account is not null as has_account, email, kind, words, source, page, beta, test, status from public.feedback where id = $1",
    [out.from_account.id]);
  // Signed out: the address, lower case.
  out.signed_out = await send(null, "Visitor@Example.com", { place: "p1" });
  out.signed_out_row = await q("select account, email from public.feedback where id = $1", [out.signed_out.id]);
  // Both, or neither, refused by the table itself.
  const refusedBy = async (sql, params) => q(sql, params).then(() => "allowed", (trouble) => `refused: ${trouble.message}`);
  out.both = await refusedBy("insert into public.feedback (account, email, kind, words, source) values ($1, 'a@b.co', 'bug', 'x', 'app')", [ada]);
  out.neither = await refusedBy("insert into public.feedback (kind, words, source) values ('bug', 'x', 'app')", []);
  out.bad_kind = await refusedBy("insert into public.feedback (account, kind, words, source) values ($1, 'rant', 'x', 'app')", [ada]);
  out.bad_picture = await refusedBy("update public.feedback set picture = '../etc/passwd' where id = $1", [out.from_account.id]);
  out.nobody = await send("00000000-0000-4000-8000-0000000000ee", null);

  // A tester: approved by beta.sql's own steps; their report marked beta.
  const bo = await user("bo@example.com");
  await one("select public.beta_apply($1, 'A working crane with a slewing ring and a two-speed winch', 'claude', 'lego', '', null, '2026-10-29', '{}')", [bo]);
  out.before_approval = await one("select public.beta_tester($1)", [bo]);
  await one("select public.beta_decide($1, 'approve', null, 'owner@example.com')", [bo]);
  out.tester = await one("select public.beta_tester($1)", [bo]);
  out.tester_nobody = await one("select public.beta_tester(null)");
  out.from_tester = await send(bo, null, { kind: "idea", words: "Let me pin a part" });
  // A test address (the site's checks): marked test, kept apart.
  const check = await user("delivered+bw-feedback@resend.dev");
  out.from_check = await send(check, null, { kind: "question", words: "Does it save?" });

  // The files, once stored.
  out.files = await one("select public.feedback_files($1, $2, $3)", [out.from_tester.id, `${out.from_tester.id}/picture.jpg`,
    `${out.from_tester.id}/model.mpd`]);
  out.files_none = await one("select public.feedback_files(999999, null, null)");

  // The owner: a note, a status, an answer.
  out.triage = await one("select public.feedback_triage($1, 'planned', 'Next week')", [out.from_tester.id]);
  out.triage_keeps_note = await one("select public.feedback_triage($1, null, null)", [out.from_tester.id]);
  out.triage_clears_note = await one("select public.feedback_triage($1, null, '')", [out.from_account.id]);
  out.triage_none = await one("select public.feedback_triage(999999, 'seen', null)");
  out.reply = await one("select public.feedback_reply($1, 'Thank you: fixed in the next release.', 'owner@example.com', 'sent', 're_1')",
    [out.from_account.id]);
  out.reply_none = await one("select public.feedback_reply(999999, 'x', 'owner@example.com', 'sent', null)");

  // What a sender sees of their own: no note, no address, no log.
  out.mine_tester = await one("select public.feedback_mine($1)", [bo]);
  out.mine_ada = await one("select public.feedback_mine($1)", [ada]);
  // The inbox: filters and counts; the checks' apart.
  out.inbox_all = await one("select public.feedback_inbox(null, null, null, false, 50)");
  out.inbox_beta = await one("select public.feedback_inbox(null, true, null, false, 50)");
  out.inbox_ideas = await one("select public.feedback_inbox('idea', null, null, false, 50)");
  out.inbox_new = await one("select public.feedback_inbox(null, null, 'new', false, 50)");
  out.inbox_open = await one("select public.feedback_inbox(null, null, 'open', false, 50)");
  out.inbox_tests = await one("select public.feedback_inbox(null, null, null, true, 50)");
  out.one = await one("select public.feedback_one($1)", [out.from_account.id]);

  // The rate: an account ten an hour; signed out five from a place, three
  // to an inbox.
  const cy = await user("cy@example.com");
  out.account_rate = [];
  for (let n = 0; n < 11; n += 1) out.account_rate.push(Object.keys(await send(cy, null)).join(","));
  out.place_rate = [];
  for (let n = 0; n < 6; n += 1) out.place_rate.push(Object.keys(await send(null, `p${n}@example.com`, { place: "busy" })).join(","));
  out.inbox_rate = [];
  for (let n = 0; n < 4; n += 1) {
    out.inbox_rate.push(Object.keys(await send(null, n % 2 ? "d.ee+x@gmail.com" : "dee@googlemail.com", { place: `q${n}` })).join(","));
  }
  // A day on, the tries are gone.
  await q("update public.feedback_tries set at = now() - interval '25 hours'");
  await send(cy, null);
  out.tries_left = await one("select count(*)::int from public.feedback_tries");

  // Deleting an account: its files named first, then its reports go with it.
  out.files_of = await one("select public.feedback_files_of($1)", [bo]);
  await q("delete from auth.users where id = $1", [bo]);
  out.deleted = await one("select count(*)::int from public.feedback where account = $1", [bo]);
  out.deleted_replies_kept_apart = await one("select count(*)::int from public.feedback_replies");

  // The sweep: the checks' after a day; signed out and closed after a year.
  await q("update public.feedback set at = now() - interval '2 days' where test");
  await q("update public.feedback set changed_at = now() - interval '366 days' where account is null and email = 'visitor@example.com'");
  await q("update public.feedback set status = 'fixed', changed_at = now() - interval '366 days', picture = id || '/picture.png' where id = $1",
    [out.from_account.id]);
  out.sweep = await one("select public.feedback_sweep()");
  out.after_sweep = await one("select count(*)::int from public.feedback where id = any($1)",
    [[out.from_account.id, out.signed_out.id, out.from_check.id]]);

  // Who may do what.
  const tries = async (role, sql) => {
    const client = await connect();
    try {
      await client.query(`set role ${role}`);
      await client.query(sql);
      return "allowed";
    } catch (trouble) {
      return `refused: ${trouble.message}`;
    } finally {
      await client.end();
    }
  };
  out.grants = {};
  for (const role of ["anon", "authenticated", "service_role"]) {
    out.grants[role] = {
      read_feedback: await tries(role, "select count(*) from public.feedback"),
      read_replies: await tries(role, "select count(*) from public.feedback_replies"),
      inbox: await tries(role, "select public.feedback_inbox(null, null, null, false, 5)"),
      send: await tries(role, `select public.feedback_send('${ada}', null, 'bug', 'x', 'app', null, '{}', null, 'r')`),
      tester: await tries(role, `select public.beta_tester('${ada}')`),
    };
  }
  out.row_security = await q(`select c.relname, c.relrowsecurity as on, (select count(*)::int from pg_policies p
    where p.tablename = c.relname) as policies from pg_class c where c.relname like 'feedback%' and c.relkind = 'r' order by 1`);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
