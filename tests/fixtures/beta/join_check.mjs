// Joining the beta (betajoin, supabase/beta_join.sql) through the API
// (api/_beta.js through api/plans.js, api/account.js and api/admin.js),
// against beta.sql, feedback.sql and beta_join.sql themselves in pg.mjs's
// Postgres, with the stand-in Admission: what tests/test_beta_join.py asks.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/beta/join_check.mjs
//
// Prints one JSON object, each scenario's findings by name.
import { askAccount, askAdmin, askPlans, SUPABASE_URL, world } from "../billing/world.mjs";
import { startPostgres } from "./pg.mjs";

const db = await startPostgres({ also: ["supabase/feedback.sql", "supabase/beta_join.sql"] });
const out = {};
let withoutJoin = false;
let rae = null;

try {
  const w = await world({ billing: "test" });
  const stood = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const rpc = /^\/rest\/v1\/rpc\/(beta_[a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && rpc) {
      w.calls.push(`POST ${url.pathname}`);
      // As a project without beta_join.sql answers its functions.
      if (withoutJoin && ["beta_member", "beta_join", "beta_leave", "beta_testers_list"].includes(rpc[1])) {
        return new Response(JSON.stringify({ message: "not there" }), { status: 404 });
      }
      try {
        const answer = await db.rpc(rpc[1], JSON.parse(String(init.body || "{}")));
        return new Response(JSON.stringify(answer), { status: 200 });
      } catch (trouble) {
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: 400 });
      }
    }
    if (url.origin === "https://api.resend.com") return new Response(JSON.stringify({ id: "re-1" }), { status: 200 });
    return stood(input, init);
  };
  delete process.env.RESEND_API_KEY;
  const owner = await w.signIn({ sub: "00000000-0000-4000-8000-0000000000ff", email: "owner@example.com" });
  const asOwner = { authorization: `Bearer ${owner}` };
  const as = (token) => ({ authorization: `Bearer ${token}` });
  const now = new Date().toISOString();
  const person = async (email, made = now) => {
    const id = await db.user(email, { made });
    return { id, token: await w.signIn({ sub: id, email }) };
  };
  const pick = (json) => json && { tester: json.tester, state: json.state, welcome: json.welcome,
    joined: Boolean(json.joined_at), month: json.month ? Object.keys(json.month).sort() : null,
    application: json.application ?? null };

  // Off: no welcome, joining refused, nothing asked of the database for it.
  delete process.env.BRICKWORKS_BETA;
  const nell = await person("delivered+bw-beta-nell@resend.dev");
  out.off_get = await askPlans({ query: { op: "beta" }, headers: as(nell.token) });
  const before = w.calls.length;
  out.off_join = await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(nell.token), body: { via: "welcome" } });
  out.off_join_calls = w.calls.slice(before);
  out.off_account = (await askAccount({ headers: as(nell.token) })).json?.beta;

  process.env.BRICKWORKS_BETA = "open";
  // Signed out: the spots, nothing about anybody.
  const signedOut = await askPlans({ query: { op: "beta" } });
  out.signed_out = { status: signedOut.status, beta: signedOut.json?.beta, spots: signedOut.json?.spots,
    signed_in: signedOut.json?.signed_in, tester: signedOut.json?.tester ?? null };
  out.join_signed_out = (await askPlans({ method: "POST", query: { op: "beta_join" }, body: {} })).status;
  out.join_get = (await askPlans({ query: { op: "beta_join" }, headers: as(nell.token) })).status;

  // A new account: the welcome is due, at /api/account and at op=beta.
  out.new_account = (await askAccount({ headers: as(nell.token) })).json?.beta;
  out.new_status = pick((await askPlans({ query: { op: "beta" }, headers: as(nell.token) })).json);
  // Join: a tester in one call, which answers as GET does.
  const joined = await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(nell.token), body: { via: "welcome" } });
  out.joined = { status: joined.status, ...pick(joined.json), spots: joined.json?.spots };
  out.joined_get = pick((await askPlans({ query: { op: "beta" }, headers: as(nell.token) })).json);
  out.joined_account = (await askAccount({ headers: as(nell.token) })).json?.beta;
  out.joined_hub = (await askPlans({ query: { op: "beta_hub" }, headers: as(nell.token) })).status;
  out.joined_tester_fn = await db.rpc("beta_tester", { p_account: nell.id });
  const firstJoin = await db.q("select joined_at, via, terms from public.beta_testers where account = $1", [nell.id]);
  // Joining again changes nothing.
  await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(nell.token), body: { via: "settings" } });
  const secondJoin = await db.q("select joined_at, via from public.beta_testers where account = $1", [nell.id]);
  out.join_again_same = String(firstJoin[0].joined_at) === String(secondJoin[0].joined_at) && secondJoin[0].via === "welcome";
  out.join_terms = firstJoin[0].terms;

  // Not now: never a tester, never welcomed again.
  const otto = await person("delivered+bw-beta-otto@resend.dev");
  const later = await askPlans({ method: "POST", query: { op: "beta_leave" }, headers: as(otto.token) });
  out.not_now = { status: later.status, ...pick(later.json) };
  out.not_now_account = (await askAccount({ headers: as(otto.token) })).json?.beta;
  out.not_now_hub = (await askPlans({ query: { op: "beta_hub" }, headers: as(otto.token) })).status;

  // An existing account (made a month ago): no welcome; joins from
  // Settings in one call, and leaves.
  const ida = await person("delivered+bw-beta-ida@resend.dev", "2026-10-01T00:00:00Z");
  out.old_account = (await askAccount({ headers: as(ida.token) })).json?.beta;
  out.old_join = pick((await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(ida.token),
    body: { via: "settings" } })).json);
  const left = await askPlans({ method: "POST", query: { op: "beta_leave" }, headers: as(ida.token) });
  out.old_left = { status: left.status, ...pick(left.json) };
  out.old_left_hub = (await askPlans({ query: { op: "beta_hub" }, headers: as(ida.token) })).status;
  out.old_rejoin = pick((await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(ida.token),
    body: { via: "nowhere-at-all" } })).json);
  out.old_rejoin_via = (await db.q("select via from public.beta_testers where account = $1", [ida.id]))[0].via;

  // Telling us about you, as a tester: no boxes to tick again. And as
  // somebody who has not joined: it joins them, with the boxes.
  const about = { build: "A Technic tower crane with a working slewing ring and a two-speed winch.", ai: "claude",
    background: "lego", background_line: "", link: "" };
  const told = await askPlans({ method: "POST", query: { op: "beta" }, headers: as(nell.token), body: about });
  out.told = { status: told.status, status_of: told.json?.application?.status, error: told.json?.error ?? null };
  const pia = await person("delivered+bw-beta-pia@resend.dev");
  out.untold_no_boxes = (await askPlans({ method: "POST", query: { op: "beta" }, headers: as(pia.token), body: about })).status;
  const piaApplied = await askPlans({ method: "POST", query: { op: "beta" }, headers: as(pia.token),
    body: { ...about, terms: true, emails: true } });
  out.untold_applied = piaApplied.status;
  out.untold_now = pick((await askPlans({ query: { op: "beta" }, headers: as(pia.token) })).json);
  out.untold_via = (await db.q("select via from public.beta_testers where account = $1", [pia.id]))[0]?.via;

  // The month, as today: approved from the queue, a spot of the checks'
  // pool, given at Admission's test mode; a tester who leaves keeps it.
  const decided = await askAdmin({ method: "POST", query: { op: "beta_decide", account: nell.id }, headers: asOwner,
    body: { decision: "approve" } });
  out.month_approved = { status: decided.status, spot: decided.json?.application?.spot, comp: decided.json?.month?.comp };
  await askPlans({ method: "POST", query: { op: "beta_leave" }, headers: as(nell.token) });
  const kept = (await askPlans({ query: { op: "beta" }, headers: as(nell.token) })).json;
  out.month_after_leaving = { tester: kept?.tester, status: kept?.month?.application?.status, comp: kept?.month?.application?.comp,
    spot: kept?.month?.application?.spot };
  out.comps_asked = w.admission.compsAsked.length;

  // An approval from before beta_join.sql, with no row: still a tester.
  const quin = await person("delivered+bw-beta-quin@resend.dev");
  await db.rpc("beta_apply", { p_account: quin.id, p_build: about.build, p_ai: "claude", p_background: "lego",
    p_background_line: "", p_link: null, p_terms: "2026-10-29", p_signals: {} });
  await db.q("delete from public.beta_testers where account = $1", [quin.id]);
  await db.rpc("beta_decide", { p_account: quin.id, p_decision: "approve", p_note: null, p_by: "owner@example.com" });
  out.legacy = pick((await askPlans({ query: { op: "beta" }, headers: as(quin.token) })).json);
  out.legacy_left = pick((await askPlans({ method: "POST", query: { op: "beta_leave" }, headers: as(quin.token) })).json);

  // The owner's list of testers, and nobody else's.
  out.list_stranger = (await askAdmin({ query: { op: "beta_testers" }, headers: as(ida.token) })).status;
  const listed = await askAdmin({ query: { op: "beta_testers", tests: "1" }, headers: asOwner });
  out.list = { status: listed.status, counts: listed.json?.counts,
    rows: listed.json?.testers?.map((one) => [one.email.replace(/^delivered\+bw-beta-|@resend\.dev$/g, ""), one.state, one.via,
      one.application?.status ?? null]) };
  out.list_real = (await askAdmin({ query: { op: "beta_testers" }, headers: asOwner })).json?.testers?.length;

  // Off again: anybody may leave; nobody may join.
  delete process.env.BRICKWORKS_BETA;
  out.off_leave = await askPlans({ method: "POST", query: { op: "beta_leave" }, headers: as(ida.token) });
  out.off_rejoin = (await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(ida.token), body: {} })).status;

  // Before beta_join.sql is applied: everything as it was.
  process.env.BRICKWORKS_BETA = "open";
  withoutJoin = true;
  rae = await person("delivered+bw-beta-rae@resend.dev");
  out.without_account = (await askAccount({ headers: as(rae.token) })).json?.beta;
  out.without_get = pick((await askPlans({ query: { op: "beta" }, headers: as(rae.token) })).json);
  out.without_join = (await askPlans({ method: "POST", query: { op: "beta_join" }, headers: as(rae.token), body: {} })).status;
  out.without_apply = (await askPlans({ method: "POST", query: { op: "beta" }, headers: as(rae.token),
    body: { ...about, terms: true, emails: true } })).status;
  out.without_list = (await askAdmin({ query: { op: "beta_testers", tests: "1" }, headers: asOwner })).status;
  withoutJoin = false;

  // Deleting an account takes its row with it.
  await db.q("delete from auth.users where id = $1", [otto.id]);
  out.deleted_row = Number(await db.one("select count(*) from public.beta_testers where account = $1", [otto.id]));

  // The table as the page's keys see it: nothing.
  out.exposure = await db.q(`select has_table_privilege('anon', 'public.beta_testers', 'select') as anon,
    has_table_privilege('authenticated', 'public.beta_testers', 'select') as signed_in,
    has_function_privilege('anon', 'public.beta_join(uuid, text, text)', 'execute') as anon_join,
    has_function_privilege('authenticated', 'public.beta_member(uuid)', 'execute') as signed_in_member,
    has_function_privilege('service_role', 'public.beta_join(uuid, text, text)', 'execute') as server_join,
    (select relrowsecurity from pg_class where relname = 'beta_testers') as row_security`);

  // Applied again: an application made before it (Rae's, above) joins its
  // account to the testers, as the first application did; a third time
  // changes nothing.
  const file = (await import("node:fs")).readFileSync(new URL("../../../supabase/beta_join.sql", import.meta.url), "utf8");
  await db.q(file);
  out.backfilled = (await db.q("select state, via from public.beta_testers where account = $1", [rae.id]))[0] ?? null;
  const rowsBefore = await db.q("select account, state, joined_at, via from public.beta_testers order by account");
  await db.q(file);
  const rowsAfter = await db.q("select account, state, joined_at, via from public.beta_testers order by account");
  out.again_same = JSON.stringify(rowsBefore) === JSON.stringify(rowsAfter);
} catch (trouble) {
  out.error = String(trouble?.stack || trouble);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
