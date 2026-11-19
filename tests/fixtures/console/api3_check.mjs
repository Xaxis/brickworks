// The console's part C (api/admin.js's notice_set, notice_clear, run_cron,
// export, delete_account, sign_out, unbar_model, and its reads switches,
// data, find, challenge_view; api/plans.js's public notice) against
// supabase/console3.sql itself, in pg.mjs's Postgres after the files it
// reads: what tests/test_console3.py asks of it. Functions are answered by
// the real files, as PostgREST calls them; a few tables' selects by the same
// Postgres; auth's accounts from that Postgres; a cron's own address by a
// stand-in that says who called it.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/console/api3_check.mjs
//
// Prints one JSON object, each finding by name.
import { readFileSync } from "node:fs";
import { askAdmin, SUPABASE_URL, world } from "../billing/world.mjs";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS3, STAND_INS } from "./needs3.mjs";

const db = await startPostgres({ also: NEEDS3 });
const out = {};
const TABLES = new Set(["people", "model_collections", "oauth_grants", "relay_tabs", "collection_sets"]);
const COLUMN = /^[a-z_]+$/;

/// A PostgREST select of one of TABLES, read from the Postgres: its rows.
async function select(table, params) {
  const where = [];
  const values = [];
  let order = "";
  let limit = "";
  let columns = "*";
  for (const [key, value] of params) {
    if (key === "select") {
      if (value !== "*" && !value.split(",").every((c) => COLUMN.test(c))) throw new Error(`select ${value}`);
      columns = value;
    } else if (key === "order") {
      const [c, way] = value.split(".");
      if (!COLUMN.test(c)) throw new Error(`order ${value}`);
      order = ` order by ${c} ${way === "desc" ? "desc" : "asc"}`;
    } else if (key === "limit") {
      limit = ` limit ${Number(value) || 1}`;
    } else if (COLUMN.test(key)) {
      const [op, ...rest] = value.split(".");
      const given = rest.join(".");
      if (op === "in" && /^\(.*\)$/.test(given)) {
        values.push(given.slice(1, -1).split(","));
        where.push(`${key}::text = any($${values.length})`);
        continue;
      }
      if (op !== "eq") throw new Error(`filter ${key}=${value}`);
      values.push(given);
      where.push(`${key}::text = $${values.length}`);
    }
  }
  const rows = await db.q(`select ${columns} from public.${table}${where.length ? ` where ${where.join(" and ")}` : ""}${order}${limit}`,
    values);
  return JSON.parse(JSON.stringify(rows));
}

/// A function called as PostgREST calls it: by its arguments' names.
async function rpc(name, args = {}) {
  const names = Object.keys(args);
  if (!/^[a-z_]+$/.test(name) || names.some((key) => !/^[a-z_]+$/.test(key))) throw new Error(`rpc ${name}`);
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
  const rows = await db.q(`select * from public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`, values);
  const [{ set }] = await db.q("select bool_or(proretset) as set from pg_proc where proname = $1", [name]);
  const plain = rows.every((row) => Object.keys(row).length === 1 && "answer" in row);
  if (!set && rows.length === 1 && plain) return rows[0].answer;
  return JSON.parse(JSON.stringify(plain ? rows.map((row) => row.answer) : rows));
}

const auditCount = async () => (await db.q("select count(*)::int as n from public.admin_audit"))[0].n;

try {
  await db.q(STAND_INS);
  await db.q(readFileSync(new URL("../../../supabase/console3.sql", import.meta.url), "utf8"));
  const w = await world({ billing: "" });
  const fromWorld = globalThis.fetch;
  // The crons' own address, as Run now reaches it: who asked, with what key.
  const cronCalls = [];
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    if (url.pathname.startsWith("/api/share/") || url.pathname.startsWith("/api/otp/")) {
      cronCalls.push({ url: `${url.origin}${url.pathname}`, key: init.headers?.authorization || null });
      if (url.pathname === "/api/share/sweep") await new Promise((done) => setTimeout(done, 400));
      return new Response(JSON.stringify({ outcome: "done", job: url.pathname }), { status: 200 });
    }
    const call = /^\/rest\/v1\/rpc\/([a-z_]+)$/.exec(url.pathname);
    // The world answers the deletion's own stand-ins (oc_connect_leaving...).
    if (url.origin === SUPABASE_URL && call && !["oc_connect_leaving", "admission_snapshot_get", "admission_snapshot_put"].includes(call[1])) {
      try {
        return new Response(JSON.stringify(await rpc(call[1], JSON.parse(String(init.body || "{}")))), { status: 200 });
      } catch (trouble) {
        const missing = /does not exist/.test(String(trouble.message));
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: missing ? 404 : 400 });
      }
    }
    const table = /^\/rest\/v1\/([a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && table && (init.method || "GET") === "GET" && TABLES.has(table[1])) {
      return new Response(JSON.stringify(await select(table[1], url.searchParams)), { status: 200 });
    }
    if (url.origin === SUPABASE_URL && url.pathname === "/auth/v1/admin/users") {
      const users = await db.q("select id, email, created_at, last_sign_in_at, email_confirmed_at from auth.users order by 1");
      return new Response(JSON.stringify({ users }), { status: 200 });
    }
    const one = /^\/auth\/v1\/admin\/users\/([0-9a-f-]{36})$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && one && (init.method || "GET") === "GET") {
      const [user] = await db.q("select id, email, created_at, last_sign_in_at, email_confirmed_at from auth.users where id = $1", [one[1]]);
      return user ? new Response(JSON.stringify(user), { status: 200 }) : new Response(JSON.stringify({ message: "User not found" }), { status: 404 });
    }
    if (url.origin === SUPABASE_URL && one && init.method === "DELETE") {
      // Supabase deletes the user, and everything with a key to it goes too.
      const answer = await fromWorld(input, init);
      if (answer.ok) await db.q("delete from auth.users where id = $1", [one[1]]);
      return answer;
    }
    return fromWorld(input, init);
  };
  const ownerId = await db.user("owner@example.com");
  const adaId = await db.user("ada@example.com");
  const bobId = await db.user("bob@resend.dev");
  const owner = await w.signIn({ sub: ownerId, email: "owner@example.com" });
  const ada = await w.signIn({ sub: adaId, email: "ada@example.com" });
  const preview = "brickworks-abc123-xaxis-projects.vercel.app";
  const as = (token, host = preview) => ({ host, ...(token ? { authorization: `Bearer ${token}` } : {}) });
  const read = (query, host) => askAdmin({ query, headers: as(owner, host) });
  const act = (query, body, host) => askAdmin({ method: "POST", query, headers: as(owner, host), body });
  process.env.CRON_SECRET = "cron-key-for-this-test-only";

  // Every new op: 401 signed out, 404 to anybody but the owner, and none kept.
  out.gate = {};
  for (const [op, method] of [["data", "GET"], ["find", "GET"], ["challenge_view", "GET"], ["switches", "GET"], ["unbar_model", "POST"],
    ["notice_set", "POST"], ["notice_clear", "POST"], ["run_cron", "POST"], ["export", "POST"], ["delete_account", "POST"],
    ["sign_out", "POST"]]) {
    const query = { op, account: adaId, job: "canary", id: "AbCdEfGhIj", q: "ada", challenge: "1" };
    out.gate[op] = [(await askAdmin({ method, query, headers: as(null), body: { confirm: "ada@example.com" } })).status,
      (await askAdmin({ method, query, headers: as(ada), body: { confirm: "ada@example.com" } })).status];
  }
  out.audit_after_gate = await auditCount();
  out.ada_after_gate = (await db.q("select count(*)::int as n from auth.users where id = $1", [adaId]))[0].n;

  // The reads, none of them kept in the audit.
  const sw = await read({ op: "switches" });
  out.switches = { status: sw.status, scope: sw.json.scope, names: (sw.json.variables || []).map((one) => one.name),
    cron_here: sw.json.variables?.find((one) => one.name === "CRON_SECRET")?.here,
    vercel_ready: sw.json.vercel_ready, notice: sw.json.notice, notice_ready: sw.json.notice_ready,
    // Before the train has written Vercel's list down: not known, never "Not set".
    master_before: sw.json.variables?.find((one) => one.name === "MASTER_EMAIL")?.environments,
    // Never a value: the keys this test set are nowhere in it.
    leaks: ["cron-key-for-this-test-only", process.env.SUPABASE_SECRET_KEY === "secret" ? "\"secret\"" : process.env.SUPABASE_SECRET_KEY]
      .filter((value) => JSON.stringify(sw.json).includes(value)) };
  await rpc("site_env_note", { p_vars: [{ name: "CRON_SECRET", environments: ["production", "preview"] },
    { name: "ANTHROPIC_API_KEY", environments: ["production"] }] });
  const sw2 = (await read({ op: "switches" })).json;
  out.switches_noted = { cron: sw2.variables.find((one) => one.name === "CRON_SECRET")?.environments,
    unread: sw2.variables.filter((one) => one.unread).map((one) => `${one.name}:${one.environments.join("+")}`),
    master: sw2.variables.find((one) => one.name === "MASTER_EMAIL")?.environments };
  const d = await read({ op: "data" });
  out.data = { status: d.status, database: d.json.usage?.database > 0, buckets: d.json.usage?.buckets, egress_read: d.json.egress?.read,
    egress_why: Boolean(d.json.egress?.why), arrivals: d.json.omr?.arrivals ?? "missing" };
  await db.q("insert into public.people (account, handle, name) values ($1, 'ada-builds', 'Ada')", [adaId]);
  const f = await read({ op: "find", q: "ada" });
  out.find = { status: f.status, accounts: f.json.accounts.map((one) => one.email), people: f.json.people.map((one) => one.handle),
    ready: f.json.ready };
  out.find_tests = (await read({ op: "find", q: "bob", tests: "1" })).json.accounts.map((one) => one.email);
  out.find_short = (await read({ op: "find", q: "a" })).json;
  out.challenge_bad = (await read({ op: "challenge_view", challenge: "x" })).status;
  out.challenge_before_sql = (await read({ op: "challenge_view", challenge: "5" })).json;
  out.audit_after_reads = await auditCount();

  // The notice: refused without English, set on this preview alone, shown
  // to anybody there (api/plans.js), replaced, cleared, cleared again.
  const { askPlans } = await import("../billing/world.mjs");
  out.notice_no_english = await act({ op: "notice_set" }, { words: { de: "Nur Deutsch." } });
  const set = await act({ op: "notice_set" }, { words: { en: "Down for upkeep at 02:00 UTC.", de: "Wartung um 02:00 UTC.", xx: "no" },
    tone: "warn" });
  out.notice_set = { status: set.status, json: set.json };
  const shown = await askPlans({ query: { op: "notice" }, headers: { host: preview } });
  out.notice_shown = { status: shown.status, json: shown.json };
  out.notice_live = (await askPlans({ query: { op: "notice" }, headers: { host: "brickworks.diy" } })).json;
  out.notice_again = (await act({ op: "notice_set" }, { words: { en: "Back up." }, tone: "info" })).json;
  out.notice_overview = (await read({ op: "overview" })).json.notice;
  const markup = '<img src=x onerror="alert(1)"><b>Bold</b> &amp; <script>alert(2)</script>';
  out.notice_markup_set = (await act({ op: "notice_set" }, { words: { en: markup, fr: `<i>${markup}</i>` } })).status;
  const told = (await askPlans({ query: { op: "notice" }, headers: { host: preview } })).json;
  out.notice_markup = { en: told.notice?.words?.en === markup, fr: told.notice?.words?.fr === `<i>${markup}</i>` };
  out.notice_cleared = (await act({ op: "notice_clear" })).status;
  out.notice_cleared_again = (await act({ op: "notice_clear" })).status;
  out.notice_after = (await askPlans({ query: { op: "notice" }, headers: { host: preview } })).json;

  // Run now: the beta's mail never; a safe one at this request's own address,
  // with the crons' key, and never at another address.
  out.run_beta = await act({ op: "run_cron", job: "beta_daily" });
  out.run_unknown = (await act({ op: "run_cron", job: "nope" })).status;
  // Names Object's prototype lends: not crons, not ops, and no op audited for them (c3review R).
  const proto = ["constructor", "__proto__", "hasOwnProperty", "toString"];
  out.run_proto = [];
  for (const job of proto) out.run_proto.push((await act({ op: "run_cron", job })).status);
  const auditBeforeProto = await auditCount();
  out.op_proto = [];
  for (const op of proto) out.op_proto.push([(await read({ op })).status, (await act({ op })).status]);
  out.audit_after_proto = (await auditCount()) - auditBeforeProto;
  // A real read asked by POST, a real act by GET: the method is wrong, not the op.
  out.wrong_method = [(await act({ op: "data" })).status, (await read({ op: "export" })).status];
  const ran = await act({ op: "run_cron", job: "gallery_feature" });
  out.run = { status: ran.status, ran: ran.json.ran, outcome: ran.json.outcome, calls: [...cronCalls] };
  const both = await Promise.all([act({ op: "run_cron", job: "share_sweep" }), act({ op: "run_cron", job: "share_sweep" })]);
  out.run_twice = both.map((one) => [one.status, one.json.ran ?? null, one.status === 409 ? one.json.error : null]).sort();
  out.run_twice_calls = cronCalls.filter((one) => one.url.endsWith("/api/share/sweep")).length;
  out.run_after_twice = (await act({ op: "run_cron", job: "share_sweep" })).status;
  out.run_holds = (await db.q("select job, holder, outcome from public.cron_runs where job like 'run_now_%' order by id"))
    .map((row) => `${row.job}:${row.holder}:${row.outcome}`);
  out.run_elsewhere = (await askAdmin({ method: "POST", query: { op: "run_cron", job: "canary" },
    headers: { ...as(owner), host: "evil.example.com" } })).status;
  out.calls_after_elsewhere = cronCalls.length;
  delete process.env.CRON_SECRET;
  out.run_no_secret = (await act({ op: "run_cron", job: "canary" })).status;

  // Sign out everywhere: bob's sessions and Claudes ended, ada's kept.
  await db.q("insert into auth.sessions (id, user_id) values (gen_random_uuid(), $1), (gen_random_uuid(), $1), (gen_random_uuid(), $2)",
    [bobId, adaId]);
  out.sign_out = (await act({ op: "sign_out", account: bobId })).json;
  out.sessions_left = (await db.q("select (select count(*)::int from auth.sessions where user_id = $1) as bob, "
    + "(select count(*)::int from auth.sessions where user_id = $2) as ada", [bobId, adaId]))[0];
  out.sign_out_nobody = (await act({ op: "sign_out", account: "00000000-0000-4000-8000-00000000abcd" })).status;

  // Export: every row of ada's, no secret column.
  await db.q("insert into public.model_collections (id, owner, name, public) values ('AdaList001', $1, 'Castles', true)", [adaId]);
  await db.q("insert into public.relay_tabs (channel, owner, tab) values ($1, $2, 'k3m9')", ["a".repeat(64), adaId]);
  await db.q("insert into public.collection_sets (collection, set_num) values ('AdaList001', '10305-1')");
  // Bob follows ada: his act, not hers. Her export counts him, never names his account (c3review X).
  await db.q("insert into public.follows (follower, followed) values ($1, $2)", [bobId, adaId]);
  const ex = await act({ op: "export", account: adaId });
  out.export = { status: ex.status, email: ex.json.email, tables: Object.keys(ex.json.tables || {}).sort(), counts: ex.json.counts,
    rows: ex.json.rows, channel: JSON.stringify(ex.json).includes("a".repeat(64)), sign_in: Object.keys(ex.json.sign_in || {}).sort(),
    sets: (ex.json.tables?.collection_sets || []).map((one) => `${one.collection}:${one.set_num}`),
    followers: ex.json.followers, follower_named: JSON.stringify(ex.json).includes(bobId), more: ex.json.more };
  // Bob's own export keeps whom he follows: his act, his data.
  const bobs = await act({ op: "export", account: bobId });
  out.export_follower = { status: bobs.status, follows: (bobs.json.tables?.["follows.follower"] || []).map((one) => one.followed === adaId),
    followers: bobs.json.followers };
  const cleoId = await db.user("cleo@resend.dev");
  const none = await act({ op: "export", account: cleoId });
  out.export_empty = { status: none.status, email: none.json.email, tables: none.json.tables, rows: none.json.rows, more: none.json.more };

  // Delete: never the owner's; the address typed again, exactly; then gone,
  // as its person would delete it, and kept in the audit by its address.
  out.delete_owner = await act({ op: "delete_account", account: ownerId }, { confirm: "owner@example.com" });
  out.delete_untyped = await act({ op: "delete_account", account: adaId }, {});
  out.delete_mistyped = await act({ op: "delete_account", account: adaId }, { confirm: "ada@example.org" });
  out.ada_after_refusals = (await db.q("select count(*)::int as n from auth.users where id = $1", [adaId]))[0].n;
  const gone = await act({ op: "delete_account", account: adaId }, { confirm: "  ADA@Example.com ", reason: "Asked by email" });
  out.delete = { status: gone.status, json: gone.json, deleted: w.deleted };
  out.ada_after = (await db.q("select count(*)::int as n from auth.users where id = $1", [adaId]))[0].n;
  out.ada_rows_after = (await db.q("select (select count(*)::int from public.people where account = $1) as people, "
    + "(select count(*)::int from public.model_collections where owner = $1) as lists", [adaId]))[0];
  out.delete_again = (await act({ op: "delete_account", account: adaId }, { confirm: "ada@example.com" })).status;

  // A model let back: its link named, or refused.
  out.unbar_bad = (await act({ op: "unbar_model", id: "short" })).status;

  // What the audit kept: each act once, its target, never a key or the export's rows.
  const kept = await db.q("select op, target_kind, target, status, detail from public.admin_audit order by id");
  out.audit = kept.map((row) => `${row.op}:${row.target_kind}:${row.target}:${row.status}`);
  out.audit_detail = Object.fromEntries(kept.filter((row) => row.status === 200).map((row) => [row.op, row.detail]));
  out.audit_exports = kept.filter((row) => row.op === "export").map((row) => row.detail?.said ?? null);
  out.audit_leaks = kept.some((row) => JSON.stringify(row.detail).includes("cron-key-for-this-test-only")
    || JSON.stringify(row.detail).includes("AdaList001"));

  // The numbers a phone is warned by (phonetruth, api/_phone.js), after the
  // audit above is read so console3's own list stands: the measured defaults
  // before any is set; closed to anybody but the owner; refused with words out
  // of range, not whole, or none named, and then none kept; set on this
  // preview alone, read back by anybody there and in the console's Switches;
  // each act kept in the audit.
  const phoneAt = (host) => askPlans({ query: { op: "phone" }, headers: { host } });
  const phoneAudit = async () => (await db.q("select count(*)::int as n from public.admin_audit where op = 'phone_rules'"))[0].n;
  out.phone_before = (await phoneAt(preview)).json;
  const shut = { method: "POST", query: { op: "phone_rules" }, body: { phone_parts: 900 } };
  out.phone_gate = [(await askAdmin({ ...shut, headers: as(null) })).status, (await askAdmin({ ...shut, headers: as(ada) })).status];
  out.phone_audit_gate = await phoneAudit();
  out.phone_none = await act({ op: "phone_rules" }, {});
  out.phone_low = await act({ op: "phone_rules" }, { phone_parts: 10 });
  out.phone_half = await act({ op: "phone_rules" }, { phone_parts: 900, phone_start_s: "12.5" });
  out.phone_words = await act({ op: "phone_rules" }, { phone_start_s: "soon" });
  out.phone_after_refused = (await phoneAt(preview)).json;
  out.phone_set = await act({ op: "phone_rules" }, { phone_parts: "1\u200b200", phone_start_s: 40 });
  out.phone_shown = await phoneAt(preview);
  out.phone_live = (await phoneAt("brickworks.diy")).json;
  out.phone_one = (await act({ op: "phone_rules" }, { phone_start_s: " 30 " })).json;
  out.phone_switches = (await read({ op: "switches" })).json.phone;
  out.phone_audit = (await db.q("select status, target_kind, target, detail from public.admin_audit where op = 'phone_rules' order by id"))
    .map((row) => ({ status: row.status, target: `${row.target_kind}:${row.target}`, asked: row.detail?.asked, said: row.detail?.said }));

  // The engine iPhones and iPads start (nothreads, api/_phone.js): the
  // threaded one until it is set; closed to anybody but the owner; refused
  // unless on is said as true or false, and then nothing kept; set on this
  // preview alone, read back by anybody there and in Switches; each act kept.
  const engineAudit = async () => (await db.q("select count(*)::int as n from public.admin_audit where op = 'phone_engine'"))[0].n;
  const engineShut = { method: "POST", query: { op: "phone_engine" }, body: { on: true } };
  out.engine_before = (await phoneAt(preview)).json.phone_nothreads;
  out.engine_gate = [(await askAdmin({ ...engineShut, headers: as(null) })).status, (await askAdmin({ ...engineShut, headers: as(ada) })).status];
  out.engine_audit_gate = await engineAudit();
  out.engine_words = await act({ op: "phone_engine" }, { on: "yes" });
  out.engine_none = await act({ op: "phone_engine" }, {});
  out.engine_after_refused = (await phoneAt(preview)).json.phone_nothreads;
  out.engine_on = await act({ op: "phone_engine" }, { on: true });
  out.engine_shown = (await phoneAt(preview)).json;
  out.engine_live = (await phoneAt("brickworks.diy")).json.phone_nothreads;
  out.engine_switch = (await read({ op: "switches" })).json.phone.find((one) => one.name === "phone_nothreads");
  out.engine_off = await act({ op: "phone_engine" }, { on: false });
  out.engine_after_off = (await phoneAt(preview)).json.phone_nothreads;
  out.engine_audit = (await db.q("select status, target_kind, target, detail from public.admin_audit where op = 'phone_engine' order by id"))
    .map((row) => ({ status: row.status, target: `${row.target_kind}:${row.target}`, asked: row.detail?.asked }));

  // What a report is, as Moderation's queue sorts it.
  const { reportKind } = await import("../../../api/admin.js");
  out.kinds = [
    reportKind({ model: "a", reason: "spam" }),
    reportKind({ model: "a", reason: "spam", comment: 4 }),
    reportKind({ model: "a", reason: "offensive" }, true),
    reportKind({ handle: "ada", reason: "personal" }),
    reportKind({ collection: "AdaList001", reason: "spam" }),
    reportKind({ model: "a", reason: "copied", note: "It is my set. Signed: A. Person" }),
    reportKind({ model: "a", reason: "other", note: "Counter-notice: it is mine. Signed: B" }),
    reportKind({ model: "a", reason: "copied", note: "Looks copied" }),
  ];
} catch (trouble) {
  out.error = String(trouble.stack || trouble);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
