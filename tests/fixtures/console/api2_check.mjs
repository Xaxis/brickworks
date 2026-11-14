// The console's part B (api/admin.js's plans, mail, connector and site;
// api/otp.js's mail_event) against supabase/console2.sql itself, in pg.mjs's
// Postgres after the files it reads: what tests/test_console2.py asks of it.
// Functions are answered by the real files, as PostgREST calls them; a
// table's select (relay_tabs, oauth_grants, canary_runs...) by the same
// Postgres, as PostgREST would read it; auth's accounts from that
// Postgres; Admission as the billing world's stand-in answers it; Supabase's
// health as [health] says.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/console/api2_check.mjs
//
// Prints one JSON object, each finding by name.
import { createHmac } from "node:crypto";
import { createRequire } from "node:module";
import { askAdmin, askOtp, SUPABASE_URL, world } from "../billing/world.mjs";
import { ADMISSION_URL, FAKE_KEY, FAKE_READ_TOKEN } from "../billing/fake_admission.mjs";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS } from "./needs2.mjs";

// A date as PostgREST sends one ("2026-11-13"), not node's midnight in this box's zone.
createRequire(import.meta.url)(process.env.PG_MODULE || "/tmp/pg/node_modules/pg/lib/index.js").types.setTypeParser(1082, (v) => v);
const db = await startPostgres({ also: [...NEEDS, "supabase/oauth.sql", "supabase/canary.sql", "supabase/console2.sql"] });
const out = {};
const TABLES = new Set(["relay_tabs", "relay_picks", "oauth_grants", "relay_call_days", "canary_runs"]);
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
      if (!value.split(",").every((c) => COLUMN.test(c))) throw new Error(`select ${value}`);
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
      if (op === "eq") { values.push(given); where.push(`${key}::text = $${values.length}`); }
      else if (op === "gte") { values.push(given); where.push(`${key} >= $${values.length}`); }
      else if (value === "not.is.null") where.push(`${key} is not null`);
      else if (value === "is.true") where.push(`${key} is true`);
      else throw new Error(`filter ${key}=${value}`);
    }
  }
  const rows = await db.q(`select ${columns} from public.${table}${where.length ? ` where ${where.join(" and ")}` : ""}${order}${limit}`,
    values);
  // As PostgREST sends them: times as text, as JSON does.
  return JSON.parse(JSON.stringify(rows));
}

/// A function called as PostgREST calls it: by its arguments' names.
async function rpc(name, args = {}) {
  const names = Object.keys(args);
  if (!/^[a-z_]+$/.test(name) || names.some((key) => !/^[a-z_]+$/.test(key))) throw new Error(`rpc ${name}`);
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" && !Array.isArray(args[key])
    ? JSON.stringify(args[key]) : args[key]));
  const rows = await db.q(`select * from public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`, values);
  // A set's rows as a list, as PostgREST sends them; a value alone.
  const [{ set }] = await db.q("select bool_or(proretset) as set from pg_proc where proname = $1", [name]);
  const plain = rows.every((row) => Object.keys(row).length === 1 && "answer" in row);
  if (!set && rows.length === 1 && plain) return rows[0].answer;
  return JSON.parse(JSON.stringify(plain ? rows.map((row) => row.answer) : rows));
}

/// Resend's event, signed with [secret] as Svix signs one.
function signed(secret, event, { id = `msg_${Math.random().toString(36).slice(2)}`, at = Math.floor(Date.now() / 1000) } = {}) {
  const raw = JSON.stringify(event);
  const key = Buffer.from(secret.replace(/^whsec_/, ""), "base64");
  const signature = createHmac("sha256", key).update(`${id}.${at}.${raw}`).digest("base64");
  return { raw, headers: { "svix-id": id, "svix-timestamp": String(at), "svix-signature": `v1,${signature}` } };
}

try {
  const w = await world({ billing: "" });
  const health = { status: 200 };
  const stood = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    if (url.origin === SUPABASE_URL && ["/auth/v1/health", "/storage/v1/bucket"].includes(url.pathname)) {
      return new Response(JSON.stringify(health.status === 200 ? {} : { code: "exceed_cached_egress_quota", message: "restricted" }),
        { status: health.status });
    }
    const call = /^\/rest\/v1\/rpc\/([a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && call && !["admission_snapshot_get", "admission_snapshot_put"].includes(call[1])) {
      w.calls.push(`POST ${url.pathname}`);
      try {
        return new Response(JSON.stringify(await rpc(call[1], JSON.parse(String(init.body || "{}")))), { status: 200 });
      } catch (trouble) {
        const missing = /does not exist/.test(String(trouble.message));
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: missing ? 404 : 400 });
      }
    }
    const table = /^\/rest\/v1\/([a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && table && (init.method || "GET") === "GET") {
      if (health.status !== 200) return new Response(JSON.stringify({ message: "restricted" }), { status: health.status });
      if (!TABLES.has(table[1])) return new Response(JSON.stringify({ message: "no such table" }), { status: 404 });
      return new Response(JSON.stringify(await select(table[1], url.searchParams)), { status: 200 });
    }
    if (url.origin === SUPABASE_URL && url.pathname === "/auth/v1/admin/users") {
      const users = await db.q("select id, email, created_at, last_sign_in_at, email_confirmed_at from auth.users order by 1");
      return new Response(JSON.stringify({ users }), { status: 200 });
    }
    return stood(input, init);
  };
  const ownerId = await db.user("owner@example.com");
  const adaId = await db.user("ada@example.com");
  const bobId = await db.user("bob@resend.dev");
  const owner = await w.signIn({ sub: ownerId, email: "owner@example.com" });
  const ada = await w.signIn({ sub: adaId, email: "ada@example.com" });
  const preview = "brickworks-abc123-xaxis-projects.vercel.app";
  const as = (token, host = preview) => ({ host, ...(token ? { authorization: `Bearer ${token}` } : {}) });
  const read = async (query) => askAdmin({ query, headers: as(owner) });

  // Every new op: 401 signed out, 404 to anybody but the owner.
  out.gate = {};
  for (const op of ["plans", "mail", "connector", "site"]) {
    out.gate[op] = [(await askAdmin({ query: { op }, headers: as(null) })).status,
      (await askAdmin({ query: { op }, headers: as(ada) })).status];
  }
  out.audit_after_reads = (await db.q("select count(*)::int as n from public.admin_audit"))[0].n;

  // Mail: Resend's events, signed. No secret, no op.
  const secret = `whsec_${Buffer.from("a secret of Resend's for this test, thirty-two bytes").toString("base64")}`;
  const mail = (type, to, extra = {}) => ({ type: `email.${type}`, created_at: extra.at || new Date().toISOString(),
    data: { email_id: extra.email || "em_1", from: extra.from || "Brickworks <noreply@brickworks.diy>", to: [to],
      subject: extra.subject || "123456 is your Brickworks sign-in code", tags: extra.tags || [{ name: "kind", value: "sign_in_code" }],
      ...(extra.data || {}) } });
  const post = (event, key = secret, opts = {}) => {
    const s = signed(key, event, opts);
    return askOtp({ method: "POST", query: { op: "mail_event" }, headers: { ...s.headers, ...(opts.headers || {}) }, raw: opts.raw ?? s.raw });
  };
  delete process.env.RESEND_WEBHOOK_SECRET;
  out.event_no_secret = (await post(mail("sent", "ada@example.com"))).status;
  process.env.RESEND_WEBHOOK_SECRET = secret;
  const sent = await post(mail("sent", "ada@example.com"), secret, { id: "msg_sent_1" });
  out.event_sent = { status: sent.status, json: sent.json };
  out.event_again = (await post(mail("sent", "ada@example.com"), secret, { id: "msg_sent_1" })).json;
  out.event_delivered = (await post(mail("delivered", "ada@example.com"))).json;
  out.event_bounced = (await post(mail("bounced", "nobody@example.com", { email: "em_2", subject: "You're in the Brickworks beta",
    tags: [{ name: "kind", value: "beta" }], data: { bounce: { type: "Permanent", subType: "General", message: "No such mailbox" } } }))).json;
  out.event_test = (await post(mail("delivered", "delivered+console@resend.dev", { email: "em_3" }))).json;
  out.event_foreign = (await post(mail("delivered", "someone@example.com", { email: "em_4", from: "Other <hi@other.example>" }))).json;
  out.event_not_mail = (await post({ type: "contact.created", created_at: new Date().toISOString(), data: {} })).json;
  out.event_badly_signed = (await post(mail("delivered", "ada@example.com"), `whsec_${Buffer.from("not the secret at all").toString("base64")}`)).status;
  out.event_stale = (await post(mail("delivered", "ada@example.com"), secret, { at: Math.floor(Date.now() / 1000) - 3600 })).status;
  out.event_tampered = (await post(mail("delivered", "ada@example.com"), secret, {
    raw: JSON.stringify(mail("complained", "ada@example.com")) })).status;
  out.events_kept = (await db.q("select type, email_id, kind, test from public.mail_events order by id")).map((row) =>
    `${row.email_id}:${row.type}:${row.kind}:${row.test}`);
  // The checks' own secret keeps only mail to Resend's test inboxes.
  const { STAND_IN_MAIL_SECRET } = await import("../../../api/_console_mail.js");
  process.env.RESEND_WEBHOOK_SECRET = STAND_IN_MAIL_SECRET;
  out.stand_in_real = (await post(mail("delivered", "ada@example.com", { email: "em_5" }), STAND_IN_MAIL_SECRET)).json;
  out.stand_in_test = (await post(mail("delivered", "bounced@resend.dev", { email: "em_6" }), STAND_IN_MAIL_SECRET)).json;
  process.env.RESEND_WEBHOOK_SECRET = secret;
  const m = await read({ op: "mail", days: "30" });
  out.mail = { status: m.status, ready: m.json.ready, webhook: m.json.webhook, totals: m.json.totals,
    mails: m.json.mails.map((one) => `${one.id}:${one.kind}:${one.address}:${[...one.states].sort().join("+")}:${one.detail || ""}`) };
  out.mail_tests = (await read({ op: "mail", tests: "1" })).json.mails.map((one) => `${one.id}:${one.address}`);

  // Connector: bob let a Claude in, switched a tab on, and a conversation in it
  // called twice; ada's tab went quiet an hour ago with no Claude.
  const channel = (n) => String(n).repeat(64).slice(0, 64);
  await db.q(`insert into public.oauth_clients (client_id, client_name, redirect_uris) values ('https://claude.ai/oauth/x-client', 'Claude', '{https://claude.ai/cb}')`);
  await db.q(`insert into public.oauth_grants (owner, client_id, client_name, resource, used_at) values ($1, 'https://claude.ai/oauth/x-client', 'Claude', 'https://brickworks.diy/api/mcp', now())`, [bobId]);
  await db.q("insert into public.relay_tabs (channel, owner, tab, model, open, seen_at) values ($1, $2, 'k3m9', 'lighthouse.mpd', true, now())",
    [channel(1), bobId]);
  await db.q("insert into public.relay_tabs (channel, owner, tab, open, seen_at) values ($1, $2, 'oldt', true, now() - interval '1 hour')",
    [channel(2), adaId]);
  await db.q("insert into public.relay_picks (key, owner, channel) values ('session:abc', $1, $2)", [bobId, channel(1)]);
  out.calls_noted = [await rpc("relay_call_note", { p_key: "session:abc", p_did: "add_parts" }),
    await rpc("relay_call_note", { p_key: "session:abc", p_did: "get_model" })];
  const c = await read({ op: "connector" });
  const byEmail = (list) => Object.fromEntries((list || []).map((one) => [one.email, one]));
  const cAll = byEmail(c.json.accounts);
  out.connector = { status: c.status, days_kept: c.json.days_kept, emails: Object.keys(cAll).sort(),
    ada_state: cAll["ada@example.com"]?.state, bob_state: cAll["bob@resend.dev"]?.state };
  const cTests = (await read({ op: "connector", tests: "1" })).json;
  const bob = cTests.accounts?.[0];
  out.connector_tests = { emails: (cTests.accounts || []).map((one) => one.email), claudes: bob?.claudes.length, calls: bob?.calls,
    last_tool: bob?.last?.tool, live_tabs: bob?.live_tabs, sessions: (cTests.sessions || []).map((s) => `${s.chat}:${s.calls}:${s.live}:${s.tool}`) };
  out.connector_one = (await read({ op: "connector", account: bobId })).json.accounts.map((one) => one.email);
  out.connector_bad = (await read({ op: "connector", account: "nobody" })).status;
  out.connector_none = (await read({ op: "connector", account: "00000000-0000-4000-8000-00000000abcd" })).json.accounts;

  // Site: a release kept, a cron that failed, the canary's last answer, health.
  await rpc("site_release_live", { p_tag: "rel-m1", p_sha: "abcdef123456", p_title: "The first", p_units: ["one", "two"],
    p_live_at: new Date(Date.now() - 864e5).toISOString() });
  await rpc("site_release_live", { p_tag: "rel-m2", p_sha: "0123456789ab", p_title: "The second", p_units: ["three"], p_live_at: null });
  await rpc("cron_noted", { job: "share_sweep", holder: "vercel-cron", started_at: new Date(Date.now() - 6e5).toISOString(),
    outcome: "failed", said: { error: "storage 500" } });
  await db.q(`insert into public.canary_runs (ok, host, checks) values (false, 'brickworks.diy', '[{"check":"code","ok":false,"what":"no code came"}]')`);
  const s = await read({ op: "site" });
  const crons = Object.fromEntries((s.json.crons || []).map((one) => [one.job, one]));
  out.site = { status: s.status, releases: (s.json.releases || []).map((one) => `${one.tag}:${one.sha}:${(one.units || []).join("+")}`),
    share_sweep: crons.share_sweep?.state, share_said: crons.share_sweep?.runs?.[0]?.said, canary: crons.canary?.state,
    canary_said: crons.canary?.runs?.[0]?.said, beta_daily: crons.beta_daily?.state, health_ok: s.json.health?.ok,
    health_parts: Object.keys(s.json.health?.parts || {}) };
  const o = (await read({ op: "overview" })).json;
  out.overview_site = { live: o.site?.live?.tag ?? null, failed: (o.site?.crons || []).map((one) => `${one.job}:${one.state}`).sort(),
    health_ok: o.site?.health?.ok, delivery: o.delivery };
  // Supabase restricted: a 402 said, with where the owner lifts it.
  const { supabaseHealth } = await import("../../../api/_console_site.js");
  health.status = 402;
  const down = await supabaseHealth({ fresh: true });
  out.health_402 = { ok: down.ok, restricted: down.restricted, fix: down.fix,
    parts: Object.fromEntries(Object.entries(down.parts).map(([k, v]) => [k, `${v.status}:${v.restricted}`])) };
  health.status = 200;
  out.health_back = (await supabaseHealth({ fresh: true })).ok;

  // Plans: billing off asks Admission nothing.
  const before = w.admission.calls.length;
  const off = (await read({ op: "plans" })).json;
  out.plans_off = { billing: off.billing, plans: off.plans, customers: off.customers, asked: w.admission.calls.length - before };
  // Test mode with a read token: plans, a customer from the snapshots, revenue.
  process.env.BRICKWORKS_BILLING = "test";
  process.env.ADMISSION_KEY = FAKE_KEY;
  process.env.ADMISSION_READ_TOKEN = FAKE_READ_TOKEN;
  process.env.ADMISSION_URL = ADMISSION_URL;
  w.admission.subscribe(bobId, { at: "2026-10-03T10:00:00Z" });
  w.admission.refund(bobId, 300, "2026-11-02T10:00:00Z");
  await db.q("insert into public.admission_snapshots (key, value) values ($1, $2)", [`admission:v2:brickworks:test:c:${bobId}`,
    JSON.stringify({ at: Date.now(), value: { plan: { key: "pro", name: "Pro", source: "subscription" },
      subscription: { status: "active", interval: "month", currentPeriodEnd: "2026-12-03T10:00:00Z" } } })]);
  await db.q("insert into public.admission_snapshots (key, value) values ($1, $2)", [`admission:v2:brickworks:test:c:${adaId}`,
    JSON.stringify({ at: Date.now(), value: { plan: { key: "pro", name: "Pro", source: "override", until: "2026-12-31" } } })]);
  await db.q("insert into public.admission_snapshots (key, value) values ($1, $2)", [`admission:v2:brickworks:live:c:${adaId}`,
    JSON.stringify({ at: Date.now(), value: { plan: { key: "free", name: "Free", source: "default" } } })]);
  const on = (await read({ op: "plans" })).json;
  out.plans_on = { billing: on.billing, read: on.read, plans: (on.plans || []).map((one) => one.key),
    customers: (on.customers || []).map((one) => `${one.email}:${one.plan}:${one.source}`).sort(),
    comps: (on.comps || []).map((one) => one.email), mrr: on.metrics?.revenue?.[0]?.mrr ?? null,
    months: (on.months || []).map((one) => `${one.month}:${one.paid}:${one.refunded}:${one.net}`),
    events: (on.events || []).map((one) => one.type), said: on.said };
  out.audit_after_all = (await db.q("select count(*)::int as n from public.admin_audit"))[0].n;
} catch (trouble) {
  out.error = String(trouble.stack || trouble);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
