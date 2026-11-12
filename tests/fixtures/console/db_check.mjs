// supabase/console.sql itself, in pg.mjs's Postgres after beta.sql,
// feedback.sql and beta_join.sql: what tests/test_console.py asks of it.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/console/db_check.mjs
//
// Prints one JSON object, each finding by name.
import { startPostgres } from "../beta/pg.mjs";

const db = await startPostgres({ also: ["supabase/feedback.sql", "supabase/beta_join.sql", "supabase/console.sql"] });
const out = {};
try {
  // A switch: none, set, set again (was), and another scope apart.
  out.unset = await db.rpc("site_setting", { p_name: "beta", p_scope: "live" });
  out.set = await db.rpc("site_setting_set", { p_name: "beta", p_scope: "live", p_value: "off", p_by: "owner@example.com" });
  out.again = await db.rpc("site_setting_set", { p_name: "beta", p_scope: "live", p_value: "open", p_by: "owner@example.com" });
  out.read = await db.rpc("site_setting", { p_name: "beta", p_scope: "live" });
  out.other_scope = await db.rpc("site_setting", { p_name: "beta", p_scope: "preview-abc.vercel.app" });
  out.bad_scope = await db.rpc("site_setting_set", { p_name: "beta", p_scope: "Not A Host!", p_value: "off", p_by: "x" })
    .then(() => "kept", (trouble) => String(trouble.message).slice(0, 160));

  // The audit: kept, listed newest first, paged, filtered, a test's apart.
  const owner = await db.user("owner@example.com");
  const ada = await db.user("ada@example.com");
  const note = (op, kind, target, extra = {}) => db.rpc("admin_audit_note", { p_actor: "owner@example.com", p_account: owner,
    p_op: op, p_kind: kind, p_target: target, p_detail: extra.detail || {}, p_status: extra.status || 200,
    p_said: extra.said || null, p_test: extra.test || false, p_scope: extra.scope || "live" });
  out.ids = [];
  out.ids.push(await note("unlist", "model", "AbCdEfGhIj", { detail: { asked: { why: "spam" } } }));
  out.ids.push(await note("beta_decide", "account", ada, { detail: { asked: { decision: "approve" } } }));
  out.ids.push(await note("dismiss", "report", "12", { status: 404, said: "no such report" }));
  out.ids.push(await note("beta_switch", "setting", "beta", { test: true, scope: "preview-abc.vercel.app" }));
  const list = (args) => db.rpc("admin_audit_list", { p_before: null, p_limit: 50, p_tests: false, p_op: null, p_kind: null,
    p_target: null, p_query: null, ...args });
  out.all = await list({});
  out.page1 = await list({ p_limit: 2 });
  out.page2 = await list({ p_limit: 2, p_before: out.page1.rows.at(-1).id });
  out.by_op = await list({ p_op: "beta_decide" });
  out.on_ada = await list({ p_kind: "account", p_target: ada });
  out.query = await list({ p_query: "SPAM" });
  out.tests = await list({ p_tests: true });
  out.bad_op = await note("Drop Table", "model", "x").then(() => "kept", (trouble) => String(trouble.message).slice(0, 160));

  // Waitlist by hand: from New only, no spot, then approved from it.
  const bob = await db.user("bob@resend.dev");
  await db.rpc("beta_apply", { p_account: bob, p_build: "A tall lighthouse with a turning lamp inside it", p_ai: "claude",
    p_background: "lego", p_background_line: "", p_link: "", p_terms: "2026-10-29", p_signals: {} });
  out.waitlist = await db.rpc("beta_waitlist", { p_account: bob, p_note: "  after the first wave ", p_by: "owner@example.com" });
  out.waitlist_again = await db.rpc("beta_waitlist", { p_account: bob, p_note: "", p_by: "owner@example.com" });
  out.waitlist_none = await db.rpc("beta_waitlist", { p_account: ada, p_note: "", p_by: "owner@example.com" });
  out.row = (await db.q("select status, note, spot, decided_by from public.beta_applications where account = $1", [bob]))[0];
  out.approved = await db.rpc("beta_decide", { p_account: bob, p_decision: "approve", p_note: "", p_by: "owner@example.com" });

  // The mail counted: the beta's and the answers', a test's apart.
  await db.q("insert into public.beta_mail (account, kind, state, subject) values ($1, 'received', 'sent', 's'), "
    + "($1, 'approved', 'failed', 's'), ($2, 'received', 'dry', 's')", [ada, bob]);
  out.mail = await db.rpc("admin_mail_counts", { p_days: 7, p_tests: false });
  out.mail_tests = await db.rpc("admin_mail_counts", { p_days: 7, p_tests: true });

  // Nobody but the server reaches any of it.
  out.grants = await db.q(`select c.relname, r.rolname, has_table_privilege(r.rolname, c.oid, 'select') as can
    from pg_class c, pg_roles r where c.relname in ('site_settings', 'admin_audit')
    and r.rolname in ('anon', 'authenticated', 'service_role') order by 1, 2`);
  out.functions = await db.q(`select p.proname, r.rolname, has_function_privilege(r.rolname, p.oid, 'execute') as can
    from pg_proc p, pg_roles r where p.proname in ('site_setting', 'site_setting_set', 'admin_audit_note', 'admin_audit_list',
    'beta_waitlist', 'admin_mail_counts') and r.rolname in ('anon', 'authenticated', 'service_role') order by 1, 2`);

  // Applied again: nothing changes.
  await db.q((await import("node:fs")).readFileSync(new URL("../../../supabase/console.sql", import.meta.url), "utf8"));
  out.after_again = { settings: Number(await db.one("select count(*) from public.site_settings")),
    audit: Number(await db.one("select count(*) from public.admin_audit")) };
} catch (trouble) {
  out.error = String(trouble.stack || trouble);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
