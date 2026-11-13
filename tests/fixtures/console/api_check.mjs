// The console's API (api/admin.js and api/_console.js, the beta's switch in
// api/_beta.js and api/_settings.js) against supabase/console.sql itself, in
// pg.mjs's Postgres after beta.sql, feedback.sql and beta_join.sql: what
// tests/test_console.py asks of it. The database's functions are answered
// by the real files, as PostgREST would call them; auth's list of accounts
// from that Postgres; anything else as the billing world answers it.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/console/api_check.mjs
//
// Prints one JSON object, each finding by name.
import { askAdmin, askPlans, SUPABASE_URL, world } from "../billing/world.mjs";
import { startPostgres } from "../beta/pg.mjs";

const db = await startPostgres({ also: ["supabase/feedback.sql", "supabase/beta_join.sql", "supabase/console.sql"] });
const out = {};
const RPC = /^\/rest\/v1\/rpc\/((?:beta_|feedback_|admin_audit_|admin_mail_|site_setting)[a-z_]*)$/;
try {
  const w = await world({ billing: "" });
  const stood = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const rpc = RPC.exec(url.pathname);
    if (url.origin === SUPABASE_URL && rpc) {
      w.calls.push(`POST ${url.origin}${url.pathname}`);
      try {
        const answer = await db.rpc(rpc[1], JSON.parse(String(init.body || "{}")));
        return new Response(JSON.stringify(answer), { status: 200 });
      } catch (trouble) {
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: 400 });
      }
    }
    if (url.origin === SUPABASE_URL && url.pathname === "/auth/v1/admin/users") {
      const users = await db.q("select id, email, created_at, last_sign_in_at, email_confirmed_at from auth.users order by 1");
      return new Response(JSON.stringify({ users }), { status: 200 });
    }
    const one = /^\/auth\/v1\/admin\/users\/([0-9a-f-]{36})$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && one && (init.method || "GET") === "GET") {
      const [user] = await db.q("select id, email, created_at, last_sign_in_at, email_confirmed_at from auth.users where id = $1",
        [one[1]]);
      return new Response(JSON.stringify(user || {}), { status: user ? 200 : 404 });
    }
    return stood(input, init);
  };
  process.env.BRICKWORKS_BETA = "open";
  const ownerId = await db.user("owner@example.com");
  const adaId = await db.user("ada@example.com");
  const bobId = await db.user("bob@resend.dev");
  const owner = await w.signIn({ sub: ownerId, email: "owner@example.com" });
  const ada = await w.signIn({ sub: adaId, email: "ada@example.com" });
  const preview = "brickworks-abc123-xaxis-projects.vercel.app";
  const as = (token, host = preview) => ({ host, ...(token ? { authorization: `Bearer ${token}` } : {}) });

  // Every new op: 401 signed out, 404 to anybody but the owner.
  const ops = [["GET", "overview"], ["GET", "people"], ["GET", "person", { account: adaId }], ["GET", "audit"],
    ["GET", "switches"], ["POST", "beta_switch"], ["POST", "beta_waitlist", { account: adaId }]];
  out.gate = {};
  for (const [method, op, extra] of ops) {
    const query = { op, ...(extra || {}) };
    const body = method === "POST" ? { mode: "off" } : undefined;
    out.gate[op] = [(await askAdmin({ method, query, headers: as(null), body })).status,
      (await askAdmin({ method, query, headers: as(ada), body })).status];
  }
  out.audit_after_refusals = (await db.q("select count(*)::int as n from public.admin_audit"))[0].n;

  // The switch: the project's (open) until flipped; flipped on the preview,
  // only the preview follows.
  out.switch_before = (await askAdmin({ query: { op: "switches" }, headers: as(owner) })).json?.beta;
  out.flip_off = await askAdmin({ method: "POST", query: { op: "beta_switch" }, headers: as(owner), body: { mode: "off" } });
  out.spots_preview_off = (await askPlans({ query: { op: "beta_spots" }, headers: { host: preview } })).json;
  out.spots_live = (await askPlans({ query: { op: "beta_spots" }, headers: { host: "brickworks.diy" } })).json;
  out.beta_preview_off = (await askPlans({ query: { op: "beta" }, headers: { host: preview } })).json;
  out.join_preview_off = (await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(ada), body: { via: "site" } })).status;
  out.flip_bad = await askAdmin({ method: "POST", query: { op: "beta_switch" }, headers: as(owner), body: { mode: "maybe" } });
  out.flip_on = await askAdmin({ method: "POST", query: { op: "beta_switch" }, headers: as(owner), body: { mode: "open" } });
  out.spots_preview_on = (await askPlans({ query: { op: "beta_spots" }, headers: { host: preview } })).json;
  out.switch_after = (await askAdmin({ query: { op: "switches" }, headers: as(owner) })).json?.beta;
  // Flipped from another instance of the function (the owner's next request
  // can land on any): this one read the switch a moment ago, and the owner
  // still reads it as it is now.
  await db.rpc("site_setting_set", { p_name: "beta", p_scope: preview, p_value: "off", p_by: "other@example.com" });
  out.switch_elsewhere = (await askAdmin({ query: { op: "switches" }, headers: as(owner) })).json?.beta;
  await db.rpc("site_setting_set", { p_name: "beta", p_scope: preview, p_value: "open", p_by: "owner@example.com" });

  // A tester's application put on the waitlist by hand, then approved.
  await db.rpc("beta_apply", { p_account: bobId, p_build: "A tall lighthouse with a turning lamp inside it", p_ai: "claude",
    p_background: "lego", p_background_line: "", p_link: "", p_terms: "2026-10-29", p_signals: {} });
  out.waitlist = await askAdmin({ method: "POST", query: { op: "beta_waitlist", account: bobId, tests: "1" },
    headers: as(owner), body: { note: "after the first wave" } });
  out.waitlist_again = await askAdmin({ method: "POST", query: { op: "beta_waitlist", account: bobId, tests: "1" },
    headers: as(owner), body: {} });
  out.waitlist_bad = await askAdmin({ method: "POST", query: { op: "beta_waitlist", account: "nobody" }, headers: as(owner) });

  // What the audit kept, and how it lists.
  out.audit = (await askAdmin({ query: { op: "audit" }, headers: as(owner) })).json;
  out.audit_tests = (await askAdmin({ query: { op: "audit", tests: "1" }, headers: as(owner) })).json;
  out.audit_switch = (await askAdmin({ query: { op: "audit", act: "beta_switch" }, headers: as(owner) })).json;
  out.audit_bad = (await askAdmin({ query: { op: "audit", before: "x" }, headers: as(owner) })).status;

  // The reads.
  out.overview = await askAdmin({ query: { op: "overview" }, headers: as(owner) });
  out.overview_tests = (await askAdmin({ query: { op: "overview", tests: "1" }, headers: as(owner) })).json;
  out.people = (await askAdmin({ query: { op: "people" }, headers: as(owner) })).json;
  out.people_tests = (await askAdmin({ query: { op: "people", tests: "1" }, headers: as(owner) })).json;
  out.person = (await askAdmin({ query: { op: "person", account: bobId, tests: "1" }, headers: as(owner) })).json;
  out.person_none = (await askAdmin({ query: { op: "person", account: "00000000-0000-4000-8000-00000000abcd" },
    headers: as(owner) })).status;
} catch (trouble) {
  out.error = String(trouble.stack || trouble);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
