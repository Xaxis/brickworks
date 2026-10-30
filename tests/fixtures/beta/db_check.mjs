// supabase/beta.sql in a Postgres of its own, made and thrown away here:
// what tests/test_beta.py asks of the database itself, above all that
// approvals at once never pass the cap or share a spot, which no single
// transaction (the dry run's) can show.
//
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js PG_BIN=<postgres's bin> \
//     node tests/fixtures/beta/db_check.mjs
//
// The Postgres is pg.mjs's, stopped and deleted at the end. Prints one
// JSON object, each scenario's findings by name.
import { SQL, startPostgres } from "./pg.mjs";

const db = await startPostgres();
const { q, one, connect, user } = db;
const out = {};

try {
  // Applying it again changes nothing.
  await q(SQL);
  out.pools = await q("select pool, cap, given from public.beta_pools order by pool");

  const apply = (id, signals = {}) => one(
    "select public.beta_apply($1, $2, 'claude', 'lego', 'Ten years of Technic', 'https://rebrickable.com/users/x/mocs/', '2026-10-29', $3)",
    [id, "A working crane with a slewing ring and a two-speed winch", JSON.stringify(signals)]);
  const decide = (id, what, client = undefined, note = null) => one("select public.beta_decide($1, $2, $3, 'owner@example.com')",
    [id, what, note], client);

  // Applying, once.
  const ada = await user("ada@example.com");
  out.apply_first = await apply(ada, { disposable: false });
  out.apply_again = await apply(ada);
  out.status_signed_out = await one("select public.beta_status(null)");

  // Two approvals at once at 99 given: one spot 100, one refusal.
  await q("update public.beta_pools set given = 99 where pool = 'beta'");
  const bo = await user("bo@example.com");
  const cy = await user("cy@example.com");
  const late = await user("late@example.com");
  for (const id of [bo, cy, late]) await apply(id);
  const [first, second] = [await connect(), await connect()];
  await q("begin", [], first);
  await q("begin", [], second);
  // The first takes the pool's lock and holds it; the second waits on it.
  const one1 = decide(bo, "approve", first);
  await new Promise((done) => setTimeout(done, 150));
  const one2 = decide(cy, "approve", second);
  await new Promise((done) => setTimeout(done, 150));
  out.second_waits = (await q("select count(*)::int as n from pg_stat_activity where wait_event_type = 'Lock'"))[0].n;
  const a1 = await one1;
  await q("commit", [], first);
  const a2 = await one2;
  await q("commit", [], second);
  await first.end();
  await second.end();
  out.race_at_99 = [a1, a2];
  out.race_spots = await q("select spot, status from public.beta_applications where pool = 'beta' and spot is not null order by spot");
  out.race_pool = await one("select public.beta_pool_view('beta')");
  out.late_status = await one("select status from public.beta_applications where account = $1", [late]);
  // Applied once all are given: the waitlist from the start.
  const after = await user("after@example.com");
  out.after_full = await apply(after);

  // From none given, 120 approvals from ten connections at once: spots 1
  // to 100, each once, and 20 refused.
  await q("delete from public.beta_applications where pool = 'beta'; update public.beta_pools set given = 0 where pool = 'beta'");
  const many = [];
  for (let i = 0; i < 120; i += 1) many.push(await user(`many${i}@example.com`));
  for (const id of many) await apply(id);
  const clients = await Promise.all(Array.from({ length: 10 }, () => connect()));
  const answers = await Promise.all(clients.map(async (client, k) => {
    const said = [];
    for (let i = k; i < many.length; i += clients.length) said.push(await decide(many[i], "approve", client));
    return said;
  }));
  await Promise.all(clients.map((client) => client.end()));
  const flat = answers.flat();
  const spots = flat.filter((a) => a.application?.spot).map((a) => a.application.spot).sort((x, y) => x - y);
  out.many = { approved: spots.length, refused: flat.filter((a) => a.refused === "full").length,
    distinct: new Set(spots).size, lowest: spots[0], highest: spots.at(-1),
    pool: await one("select public.beta_pool_view('beta')"),
    rows: await one("select count(*)::int from public.beta_applications where pool = 'beta' and spot is not null") };

  // An account from before 29 October 2026 takes no spot, even with none left.
  const early = await user("early@example.com", { made: "2026-10-20T12:00:00Z" });
  out.early_apply = await apply(early);
  out.early_approve = await decide(early, "approve");
  // The cutoff: midnight in California.
  out.early_edges = await q(`select public.beta_early('2026-10-29 06:59:59+00') as before,
    public.beta_early('2026-10-29 07:00:00+00') as at`);

  // Declined: refused again for 30 days, then made anew.
  await q("delete from public.beta_applications where pool = 'beta'; update public.beta_pools set given = 0 where pool = 'beta'");
  const dee = await user("dee@example.com");
  await apply(dee);
  out.decline = await decide(dee, "decline", undefined, "Not yet: tell us more about what you would build");
  out.decline_again = await decide(dee, "decline");
  out.apply_too_soon = await apply(dee);
  await q("update public.beta_applications set decided_at = now() - interval '31 days' where account = $1", [dee]);
  out.apply_after_30 = await apply(dee);
  // The owner may approve one declined before; never decline one approved.
  const eve = await user("eve@example.com");
  await apply(eve);
  await decide(eve, "decline");
  out.approve_declined = await decide(eve, "approve");
  out.decline_approved = await decide(eve, "decline");
  out.approve_twice = await decide(eve, "approve");
  out.decisions_of_eve = await q("select decision, by_email from public.beta_decisions where account = $1 order by id", [eve]);

  // The month: pending, then granted, never pending again.
  out.comp_pending = await one("select public.beta_comp_note($1, 'pending', null, null, 'Starts when Pro opens')", [eve]);
  out.comp_granted = await one("select public.beta_comp_note($1, 'granted', now(), now() + interval '30 days', null)", [eve]);
  out.comp_not_undone = await one("select public.beta_comp_note($1, 'pending', null, null, 'again')", [eve]);
  out.comps_due = await one("select public.beta_comps_due('beta')");
  // A reminder three days before the end, once.
  out.remind_too_early = await one("select public.beta_reminders_due()");
  await q("update public.beta_applications set month_ends_at = now() + interval '2 days 20 hours' where account = $1", [eve]);
  out.remind = await one("select public.beta_reminders_due()");
  out.remind_again = await one("select public.beta_reminders_due()");

  // The owner's queue: what is read of each account.
  const gmail = await user("a.da.l+beta@gmail.com");
  const gmailToo = await user("adal@googlemail.com");
  await apply(gmail);
  await apply(gmailToo);
  await q("insert into public.account_models (owner, name) values ($1, 'Crane'), ($1, 'Tower')", [gmail]);
  await q("insert into public.shared_models (owner, id) values ($1, 'abcdefghij')", [gmail]);
  const unconfirmed = await user("never@example.com", { confirmed: false });
  await apply(unconfirmed);
  const queue = await one("select public.beta_queue('new', false, 50)");
  out.queue_counts = queue.counts;
  out.queue_pool = queue.pool;
  out.queue_facts = Object.fromEntries(queue.applications.map((a) => [a.email, a.facts]));
  out.queue_order = queue.applications.map((a) => a.email);
  out.queue_all = (await one("select public.beta_queue(null, false, 500)")).applications.map((a) => [a.status, a.email]);
  out.inbox = await q(`select public.beta_inbox('A.Da.L+x@GMail.com') as g, public.beta_inbox('ada+news@example.com') as e,
    public.beta_inbox(' Ada@Example.com ') as plain`);

  // The checks' pool is their own.
  const tester = await user("delivered+bw-beta-1@resend.dev");
  out.test_apply = await apply(tester);
  out.test_pool = await one("select public.beta_test_pool(98)");
  out.test_approve = await decide(tester, "approve");
  out.beta_pool_untouched = await one("select public.beta_pool_view('beta')");
  out.test_queue = (await one("select public.beta_queue(null, true, 50)")).applications.map((a) => a.email);

  // Mail kept, and read back.
  await q("select public.beta_mail_note($1, 'approved', 'sent', 're_123-abc', 'You are in')", [tester]);
  out.mail = await one("select public.beta_mail_of($1)", [tester]);

  // Deleting the account erases the application, its decisions and its mail.
  await q("delete from auth.users where id = $1", [tester]);
  out.deleted = await q(`select (select count(*)::int from public.beta_applications where account = $1) as applications,
    (select count(*)::int from public.beta_decisions where account = $1) as decisions,
    (select count(*)::int from public.beta_mail where account = $1) as mail`, [tester]);
  out.deleted_status = await one("select public.beta_status($1)", [tester]);
  out.spot_spent = await one("select public.beta_pool_view('test')");

  // Declined 90 days ago: erased by the sweep, with what it kept.
  await q("update public.beta_applications set status = 'declined', spot = null, decided_at = now() - interval '91 days' where account = $1", [dee]);
  await q("update public.beta_decisions set at = now() - interval '91 days' where account = $1", [dee]);
  out.sweep = await one("select public.beta_sweep()");
  out.swept = await q(`select (select count(*)::int from public.beta_applications where account = $1) as applications,
    (select count(*)::int from public.beta_decisions where account = $1) as decisions`, [dee]);

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
      read_applications: await tries(role, "select count(*) from public.beta_applications"),
      read_pools: await tries(role, "select count(*) from public.beta_pools"),
      status: await tries(role, "select public.beta_status(null)"),
      decide: await tries(role, `select public.beta_decide('${ada}', 'approve', null, 'x@example.com')`),
      test_pool: await tries(role, "select public.beta_test_pool(0)"),
    };
  }
  out.row_security = await q(`select c.relname, c.relrowsecurity as on, (select count(*)::int from pg_policies p
    where p.tablename = c.relname) as policies from pg_class c where c.relname like 'beta\\_%' and c.relkind = 'r' order by 1`);
  // Nothing else may push past the cap or reuse a spot, even by hand.
  out.past_cap = await tries("postgres", "update public.beta_pools set given = cap + 1 where pool = 'beta'");
  out.spot_twice = await tries("postgres", `update public.beta_applications set status = 'approved', spot = 1
    where account in (select account from public.beta_applications where pool = 'beta' and spot is null limit 2)`);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
