// The owner's notifications (ownernotify; api/_notify.js) through the real
// handlers: each event raised where it happens (api/otp.js's sign-up,
// api/share.js's publish, api/_feedback.js, api/plans.js's Admission webhook,
// api/_noted.js's 5xx, the cron's looks at Supabase and the social desk),
// supabase/owner_notify.sql's tables held in memory as PostgREST would
// answer (tools/web/held_tables.mjs), and Resend stood in for here: every
// mail it is handed is kept, and none leaves this process. The sign-in of
// billing/world.mjs; the console's gate of api/admin.js. What
// tests/test_owner_notify.py asks.
//
//   node tests/fixtures/owner_notify/api_check.mjs
//
// Time passes by making the held rows older (pass below), as the clock
// would, so a run takes seconds. Prints one JSON object: {checks: [{name,
// ok, saw}]}, every check by name.
import { randomUUID } from "node:crypto";
import { Readable } from "node:stream";
import { SUPABASE_URL, world } from "../billing/world.mjs";
import { signWebhook, WEBHOOK_SECRET } from "../billing/fake_admission.mjs";
import { BOUND, afterHow, settled } from "../../../api/_after.js";

const logged = [];
for (const level of ["log", "error", "warn", "info"]) {
  const was = console[level].bind(console);
  console[level] = (...said) => {
    logged.push(said.map(String).join(" "));
    if (level === "error" && process.env.NOTIFY_CHECK_LOUD) was(...said);
  };
}

const checks = [];
const check = (name, ok, saw = null) => checks.push({ name, ok: Boolean(ok), ...(ok ? {} : { saw }) });
const HOST = "brickworks.diy";
const ADMIN = "https://brickworks.diy/admin?tests=1";

const w = await world({ master: "owner@example.com", billing: "test" });
process.env.CRON_SECRET = "cron-check-secret";
process.env.ADMISSION_WEBHOOK_SECRET = WEBHOOK_SECRET;
// A key for the stand-in below, nobody's: with it the mail goes to Resend,
// which here is this file.
process.env.RESEND_API_KEY = "re_check_stand_in_only";
delete process.env.PUBLIC_ORIGIN;
delete process.env.EMAIL_FROM;

// ---------------------------------------------------------------------------
// What the handlers talk to, over world.mjs's: Resend, the console's audit,
// Supabase's auth and the functions each path asks.

const sent = [];
const audit = [];
const users = new Map();
const signedIn = new Set();
const handles = new Map();
const models = [];
const flags = { resendDown: false, supabaseDown: false, feedbackDown: false, publishing: false, erasing: false,
  usage: null, both: null };
let feedbackId = 40;
const worldFetch = globalThis.fetch;
const reply = (status, body) => new Response(body === undefined ? "" : JSON.stringify(body), { status,
  headers: { "content-type": "application/json" } });
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(String(input.url || input));
  const method = String(init.method || "GET").toUpperCase();
  const body = () => {
    try {
      return JSON.parse(String(init.body || "null"));
    } catch {
      return init.body;
    }
  };
  if (url.origin === "https://api.resend.com") {
    sent.push({ ...body(), key: String(init.headers?.authorization || ""), once: init.headers?.["Idempotency-Key"] });
    return flags.resendDown ? reply(500, { message: "down" }) : reply(200, { id: `re_${sent.length}` });
  }
  if (url.origin !== SUPABASE_URL) return worldFetch(input, init);
  const path = url.pathname;
  const eq = (name) => /^eq\.(.*)$/.exec(url.searchParams.get(name) || "")?.[1] ?? null;
  if (path === "/rest/v1/rpc/admin_audit_note") {
    const b = body();
    audit.push({ id: audit.length + 1, at: new Date().toISOString(), actor: b.p_actor, op: b.p_op, target_kind: b.p_kind,
      target: b.p_target, detail: b.p_detail, status: b.p_status, said: b.p_said, test: b.p_test, scope: b.p_scope });
    return reply(200, audit.length);
  }
  if (path === "/rest/v1/rpc/admin_audit_list") {
    const b = body();
    const rows = audit.filter((one) => one.test === b.p_tests && (!b.p_kind || one.target_kind === b.p_kind)
      && (!b.p_op || one.op === b.p_op)).sort((a, z) => z.id - a.id).slice(0, b.p_limit || 50);
    return reply(200, { rows, more: false });
  }
  if (path === "/rest/v1/rpc/cron_noted") return reply(200, null);
  if (path === "/rest/v1/rpc/may_ask_for_code") return reply(200, true);
  if (path === "/auth/v1/admin/users" && method === "POST") {
    const { email } = body();
    if (users.has(email)) return reply(422, { msg: "A user with this email address has already been registered" });
    const id = randomUUID();
    users.set(email, id);
    return reply(200, { id, email });
  }
  const user = /^\/auth\/v1\/admin\/users\/([0-9a-f-]{36})$/.exec(path);
  if (user && method === "GET") return reply(200, { id: user[1], last_sign_in_at: signedIn.has(user[1]) ? new Date().toISOString() : null });
  if (path === "/auth/v1/admin/generate_link") return reply(200, { email_otp: "12345678" });
  if (path === "/rest/v1/people" && method === "GET") {
    const asked = /^in\.\((.*)\)$/.exec(url.searchParams.get("account") || "")?.[1]?.split(",") || [];
    return reply(200, asked.filter((one) => handles.has(one)).map((one) => ({ account: one, handle: handles.get(one) })));
  }
  if (path === "/rest/v1/rpc/admin_usage") return flags.usage ? reply(200, flags.usage) : reply(404, { message: "no such function" });
  if (["/auth/v1/health", "/rest/v1/canary_runs", "/storage/v1/bucket"].includes(path)) {
    return flags.supabaseDown ? reply(402, { message: "Project restricted: the organization is over its spend cap" }) : reply(200, []);
  }
  if (path === "/rest/v1/rpc/feedback_send") {
    if (flags.feedbackDown) return reply(500, { message: "down" });
    feedbackId += 1;
    return reply(200, { id: feedbackId, beta: false });
  }
  if (flags.publishing) {
    if (path === "/rest/v1/rpc/may_publish" || path === "/rest/v1/rpc/may_list") return reply(200, true);
    if (path === "/rest/v1/rpc/is_barred") return reply(200, false);
    if (path === "/rest/v1/shared_models") {
      if (method === "HEAD") {
        const n = models.filter((one) => one.owner === eq("owner")).length;
        return new Response(null, { status: 200, headers: { "content-range": n ? `0-${n - 1}/${n}` : "*/0" } });
      }
      if (method === "POST") {
        models.push({ created_at: new Date().toISOString(), ...body() });
        if (flags.both && models.filter((one) => one.owner === flags.both.owner).length === 2) flags.both.open();
        return new Response(null, { status: 201 });
      }
      // api/share.js's first-model test: the owner's other models made
      // before a time, one at most.
      const not = /^neq\.(.*)$/.exec(url.searchParams.get("id") || "")?.[1] ?? null;
      const before = /^lt\.(.*)$/.exec(url.searchParams.get("created_at") || "")?.[1] ?? null;
      // flags.both: the test waits until both of a pair are written, as a
      // slow database would let it.
      if (eq("owner") && not !== null) {
        if (flags.both && eq("owner") === flags.both.owner) await flags.both.written;
        return reply(200, models.filter((one) => one.owner === eq("owner") && one.id !== not && (before === null || one.created_at < before))
          .slice(0, 1).map((one) => ({ id: one.id })));
      }
      return reply(200, []);
    }
    if (path.startsWith("/storage/v1/")) return reply(200, {});
    if (path.startsWith("/rest/v1/rpc/")) return reply(200, null);
    if (path.startsWith("/rest/v1/")) return reply(200, []);
  }
  if (flags.erasing && !path.startsWith("/auth/")) {
    if (path.startsWith("/storage/v1/")) return reply(200, []);
    if (path.startsWith("/rest/v1/rpc/")) return reply(200, null);
    if (path.startsWith("/rest/v1/")) return method === "GET" ? reply(200, []) : new Response(null, { status: 204 });
  }
  return worldFetch(input, init);
};

/// One request to api/<route>.js's handler, as Vercel makes one: its
/// response's statusCode set by status() (api/_noted.js reads it). [settle]:
/// and what it began after its answer (api/_after.js) done, as the checks
/// read what that wrote; ms: how long the answer took.
async function call(route, { method = "GET", query = {}, headers = {}, body, raw, token, host = HOST, settle = true } = {}) {
  const { default: handle } = await import(`../../../api/${route}.js`);
  const response = { statusCode: 200, headers: {}, body: undefined,
    status(code) { this.statusCode = code; return this; },
    setHeader(name, value) { this.headers[String(name).toLowerCase()] = value; return this; },
    json(value) { this.body = value; return this; },
    send(value) { this.body = value; return this; },
    end() { return this; } };
  const given = { host, ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers };
  let request = { method, query, headers: given, body };
  if (raw !== undefined) {
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      parsed = raw;
    }
    request = Object.assign(Readable.from([Buffer.from(raw)]), { method, query, headers: given, body: parsed });
  }
  const t0 = performance.now();
  try {
    await handle(request, response);
  } catch (trouble) {
    return { status: 500, threw: String(trouble?.message || trouble).slice(0, 200) };
  }
  const ms = performance.now() - t0;
  if (settle) await settled();
  return { status: response.statusCode, json: response.body, ms };
}

const owner = await w.signIn({ sub: "11111111-1111-4111-8111-111111111111", email: "owner@example.com" });
const stranger = await w.signIn({ sub: "22222222-2222-4222-8222-222222222222", email: "someone@example.com" });
const admin = (op, { method = "POST", body, query = {}, token = owner, tests = true, host = HOST } = {}) => call("admin",
  { method, query: { op, ...(tests ? { tests: "1" } : {}), ...query }, body, token, host });
const signUp = (email, came) => call("otp", { method: "POST", body: { email, ...(came ? { came } : {}) } });

// The time zone where it is now about nine in the morning, so every window
// below (quiet hours 08:00-11:00, the digest at 08:00 or 20:00) holds for
// the run whenever it is run.
let offset = (((9 - new Date().getUTCHours()) % 24) + 24) % 24;
if (offset > 14) offset -= 24;
const ZONE = offset === 0 ? "UTC" : `Etc/GMT${offset > 0 ? "-" : "+"}${Math.abs(offset)}`;
const T = { scope: "live", test: true };
const GAP = 2 * 60000;

let out = {};
try {
  const notify = await import("../../../api/_notify.js");
  check("the zone is mid-morning", notify.localOf(Date.now(), ZONE).hhmm.startsWith("09:"), { ZONE });

  // 1. Before owner_notify.sql: the section says so, and nothing it raises
  //    gets in the way of what raised it.
  const before = await admin("notify", { method: "GET" });
  check("not applied: the section says so", before.status === 200 && before.json?.applied === false
    && before.json?.said === notify.NOT_APPLIED, before);
  const beforeSet = await admin("notify_set", { body: { cap: 3 } });
  check("not applied: a change is refused, saying why", beforeSet.status === 503 && beforeSet.json?.error === notify.NOT_APPLIED,
    beforeSet);
  const early = await signUp("early@resend.dev");
  check("not applied: a sign-up still goes", early.status === 200, early);

  const held = await import("../../../tools/web/held_tables.mjs");
  held.hold(["owner_notify_settings", "owner_notify_mails", "owner_notify_events", "owner_notify_errors", "social_accounts",
    "social_tokens", "social_items", "social_sends", "social_results", "social_visits", "social_rules"]);
  const rows = (table) => held.rowsOf(table);
  const events = (filter = () => true) => rows("owner_notify_events").filter((one) => one.test && filter(one));
  /// Time passing: every kept time [ms] earlier.
  const pass = (ms) => {
    for (const table of ["owner_notify_events", "owner_notify_mails", "owner_notify_errors"]) {
      for (const row of held.liveRowsOf(table)) {
        for (const column of ["at", "changed_at"]) {
          if (row[column]) row[column] = new Date(Date.parse(row[column]) - ms).toISOString();
        }
      }
    }
  };
  const flush = (options = {}) => notify.flush(T, { now: Date.now() + (options.later ?? GAP), force: Boolean(options.force) });
  const mailsSince = (n) => sent.slice(n);

  // 2. The gate: every op, signed out (401, as the whole console) and as
  //    anybody but the owner (404, as a page that is not there).
  const OPS = [["notify", "GET"], ["notify_set", "POST"], ["notify_address", "POST"], ["notify_confirm", "POST"],
    ["notify_test", "POST"], ["notify_flush", "POST"]];
  const gate = [];
  for (const [op, method] of OPS) {
    for (const tests of [true, false]) {
      const out1 = await admin(op, { method, token: null, tests, body: { cap: 1, address: "x@resend.dev", code: "123456" } });
      const out2 = await admin(op, { method, token: stranger, tests, body: { cap: 1, address: "x@resend.dev", code: "123456" } });
      gate.push(`${op}:${out1.status}:${out2.status}`);
    }
  }
  check("gate: signed out 401, anybody else 404, every op", gate.every((one) => /:401:404$/.test(one)), gate);
  const mailOther = await admin("notify", { method: "GET", token: stranger, query: { mail: "abcdefabcdef" } });
  check("gate: a mail's words, to anybody else, 404", mailOther.status === 404 && mailOther.json?.error === "not found", mailOther);
  const cronNo = await call("plans", { query: { op: "owner_notify" } });
  check("gate: the cron's run without its secret, 401", cronNo.status === 401, cronNo);
  const offGet = await call("plans", { query: { op: "notify_off", event: "signup", pool: "t", token: "0".repeat(32) } });
  check("gate: a one-click link is a POST", offGet.status === 405, offGet);
  check("gate: nothing written, nothing mailed", rows("owner_notify_settings").length === 0 && sent.length === 1
    && sent[0].subject?.includes("sign-in code"), { settings: rows("owner_notify_settings"), sent: sent.map((one) => one.subject) });

  // 3. The section, opened: its defaults, and the checks' own pool off until set.
  const fresh = await admin("notify", { method: "GET" });
  check("open: applied, the eight kinds and the four not here", fresh.status === 200 && fresh.json?.applied === true
    && fresh.json.catalog.length === 8 && fresh.json.not_here.map((one) => one.id).join() === "vercel,resend,egress,release", fresh);
  check("open: the checks' pool mails nothing until set", fresh.json?.active === false && fresh.json?.set === false
    && fresh.json?.address?.to === "de•••@resend.dev", fresh.json?.address);
  const real = await admin("notify", { method: "GET", tests: false });
  check("open: the site's own pool is on, to the owner's address in part", real.json?.active === true
    && real.json?.address?.to === "ow•••@example.com" && real.json?.address?.own === true, real.json?.address);

  // 4. The owner's settings: each checked, kept, audited; two at once both kept.
  const set = await admin("notify_set", { body: { tz: ZONE, quiet: { on: false, from: "08:00", to: "11:00" }, digest_at: "20:00", cap: 6 } });
  check("settings: kept", set.status === 200 && set.json?.settings?.tz === ZONE && set.json.settings.cap === 6
    && set.json.settings.digest_at === "20:00", set);
  const refusals = [];
  for (const [body, words] of [[{ cap: 0 }, "At most 1 to 60 mails an hour."],
    [{ tz: "Mars/Olympus" }, "That is not a time zone this server knows, as Europe/London is."],
    [{ events: { nope: { on: true } } }, "There is no notification called nope."],
    [{ quiet: { on: true, from: "09:00", to: "09:00" } }, "Quiet hours need a start and an end that differ."],
    [{ events: { errors: { threshold: 0 } } }, "Server errors: errors in an hour is a number from 1 to 100,000."],
    [{ events: { signup: { when: "weekly" } } }, "A new sign-up: at once or in the daily digest."],
    [{ volume: 11 }, "There is no setting called volume."]]) {
    const got = await admin("notify_set", { body });
    refusals.push(got.status === 400 && got.json?.error === words ? "ok" : `${JSON.stringify(body)} -> ${got.status} ${got.json?.error}`);
  }
  check("settings: each wrong one refused in words", refusals.every((one) => one === "ok"), refusals);
  const [one, two] = await Promise.all([admin("notify_set", { body: { cap: 5 } }), admin("notify_set", { body: { digest_at: "20:30" } })]);
  const both = rows("owner_notify_settings").find((row) => row.test)?.settings;
  check("settings: two changes at once both kept", one.status === 200 && two.status === 200 && both?.cap === 5
    && both?.digest_at === "20:30", { one: one.status, two: two.status, both });
  await admin("notify_set", { body: { cap: 6, digest_at: "20:00" } });
  check("settings: each change audited as the owner's", audit.filter((row) => row.op === "notify_set"
    && row.actor === "owner@example.com" && row.test === true).length >= 4, audit.filter((row) => row.op === "notify_set").length);

  // 5. A burst of sign-ups (api/otp.js): one mail, once the burst is over.
  const came = { referrer: "www.reddit.com", source: "reddit", medium: "social", campaign: "launch" };
  const burst = [];
  for (let n = 1; n <= 12; n += 1) burst.push(await signUp(`s${String(n).padStart(2, "0")}@resend.dev`, n === 1 ? came : null));
  const ada = users.get("s01@resend.dev");
  handles.set(ada, "ada");
  signedIn.add(ada);
  check("burst: twelve sign-ups answered", burst.every((got) => got.status === 200), burst.map((got) => got.status));
  const signups = events((row) => row.event === "signup");
  check("burst: twelve events, kept without an address", signups.length === 12
    && signups.every((row) => !JSON.stringify(row.detail).includes("@") && !("email" in row.detail)), signups.map((row) => row.detail));
  const told = signups.find((row) => row.account === ada)?.detail;
  check("burst: how the first came, as the page told it", told?.via === "code" && Object.keys(came).every((name) => told.came?.[name] === came[name])
    && Object.keys(told).length === 2, told);
  await signUp("s01@resend.dev");
  check("burst: an address with its account raises nothing", events((row) => row.event === "signup").length === 12);
  let n0 = sent.length;
  const soon = await flush({ later: 0 });
  check("burst: nothing mailed while they still come", soon.mails.length === 0 && sent.length === n0, soon);
  const after = await flush();
  const burstMail = mailsSince(n0)[0];
  check("burst: one mail of twelve", after.mails.length === 1 && mailsSince(n0).length === 1
    && burstMail?.subject === "12 new sign-ups", { mails: after.mails, subjects: mailsSince(n0).map((one) => one.subject) });
  check("burst: to the checks' inbox, from brickworks.diy, with the site's own key", burstMail?.to?.join() === notify.TEST_INBOX
    && burstMail?.from === "Brickworks <noreply@brickworks.diy>" && burstMail?.key === "Bearer re_check_stand_in_only"
    && burstMail?.tags?.[0]?.value === "owner_notify", { to: burstMail?.to, from: burstMail?.from });
  check("burst: who and how they came, each with its link", burstMail?.text.includes(
    "- @ada signed up, from www.reddit.com, tags reddit / social / launch") && burstMail.text.includes(`  ${ADMIN}#people/${ada}`)
    && burstMail.text.includes("Someone new signed up, nothing said of how they came (no code typed yet)"), burstMail?.text);
  check("burst: ten listed and the rest counted", (burstMail?.text.match(/ signed up/g) || []).length === 10
    && burstMail.text.includes(`- and 2 more: ${ADMIN}#people`), burstMail?.text);
  check("burst: no address of the people in it", !/s\d\d@|s\d\d•/.test(`${burstMail?.text}${burstMail?.html}`));
  const offLink = /#notifications\/off\/signup\/t\/([0-9a-f]{32})/.exec(burstMail?.text || "");
  check("burst: a one-click off link, and the mail app's own", Boolean(offLink)
    && burstMail.headers?.["List-Unsubscribe"] === `<https://brickworks.diy/api/plans?op=notify_off&event=signup&pool=t&token=${offLink[1]}>`
    && burstMail.headers?.["List-Unsubscribe-Post"] === "List-Unsubscribe=One-Click", burstMail?.headers);
  check("burst: readable on a phone: plain text, and HTML at most 560 px wide", /max-width:560px/.test(burstMail?.html || "")
    && burstMail.text.split("\n").length < 40, burstMail?.html?.slice(0, 200));
  const burstRow = rows("owner_notify_mails").find((row) => row.subject === "12 new sign-ups");
  check("burst: the mail kept, its events marked mailed", burstRow?.kind === "now" && burstRow.events === 12 && burstRow.state === "sent"
    && burstRow.sent_to === "de•••@resend.dev" && events((row) => row.event === "signup").every((row) => row.state === "mailed"
      && row.mail === burstRow.id), burstRow);
  const burstAudit = audit.find((row) => row.op === "notify_sent" && row.target === "signup");
  check("burst: audited as sent, without its words", burstAudit?.actor === "notifications" && burstAudit.target_kind === "notification"
    && burstAudit.test === true && burstAudit.scope === "live" && burstAudit.detail?.said?.mail === burstRow?.id
    && !JSON.stringify(burstAudit).includes("@ada"), burstAudit);

  // 6. A kind that keeps coming waits at most ten minutes from its first.
  pass(2 * 3600000);
  await signUp("w01@resend.dev");
  pass(9 * 60000);
  await signUp("w02@resend.dev");
  n0 = sent.length;
  const waits = await flush({ later: 0 });
  pass(90000);
  const goes = await flush({ later: 0 });
  check("batching: still coming after nine minutes, it waits", waits.mails.length === 0, waits);
  check("batching: ten minutes after its first, it goes, though the last is new", goes.mails.length === 1
    && mailsSince(n0)[0]?.subject === "2 new sign-ups", goes);

  // 7. Each other event, raised where it happens, makes its mail.
  pass(2 * 3600000);
  // A first model (api/share.js), and a second that raises nothing.
  const makerId = randomUUID();
  const maker = await w.signIn({ sub: makerId, email: "maker@resend.dev" });
  handles.set(makerId, "maker");
  const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]).toString("base64");
  const model = (name) => `0 ${name}\r\n0 Name: ${name.toLowerCase()}.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`;
  flags.publishing = true;
  const firstPublish = await call("share", { method: "POST", token: maker, body: { name: "Lighthouse", image: PNG, model: model("Lighthouse") } });
  const secondPublish = await call("share", { method: "POST", token: maker, body: { name: "Harbour", image: PNG, model: model("Harbour") } });
  // Someone who published before the owner's notifications: their next is not a first.
  const veteranId = randomUUID();
  models.push({ id: "veteranold01", owner: veteranId, created_at: "2026-10-01T09:00:00.000Z" });
  const veteran = await w.signIn({ sub: veteranId, email: "veteran@resend.dev" });
  const veteranPublish = await call("share", { method: "POST", token: veteran, body: { name: "Mill", image: PNG, model: model("Mill") } });
  flags.publishing = false;
  check("first model: one who published before raises nothing", veteranPublish.status === 201
    && events((row) => row.event === "first_model" && row.account === veteranId).length === 0, veteranPublish);
  const firsts = events((row) => row.event === "first_model" && row.account !== veteranId);
  check("first model: published, and only the first raised", firstPublish.status === 201 && secondPublish.status === 201
    && firsts.length === 1 && firsts[0].account === makerId && firsts[0].detail.name === "Lighthouse" && firsts[0].detail.parts === 2,
  { firstPublish, secondPublish, firsts });
  // A bug report (api/_feedback.js).
  const reporterId = randomUUID();
  const reporter = await w.signIn({ sub: reporterId, email: "fb@resend.dev" });
  handles.set(reporterId, "fbr");
  const report = await call("plans", { method: "POST", query: { op: "feedback" }, token: reporter,
    body: { kind: "bug", words: "The bin forgets my parts after a reload.", source: "site" } });
  check("feedback: sent and raised", report.status === 200 && events((row) => row.event === "feedback").length === 1, report);
  // Plans and payments (api/plans.js, Admission's signed word).
  const payer = "33333333-3333-4333-8333-333333333333";
  handles.set(payer, "payer");
  const hear = async (id, reason, subscription) => {
    const raw = JSON.stringify({ id, type: "customer.updated", createdAt: new Date().toISOString(), mode: "test", seq: 1,
      data: { customerId: payer, reason, customer: { plan: { key: subscription?.plan || "free" }, subscription } } });
    return call("plans", { method: "POST", query: { op: "webhook" }, raw,
      headers: { "content-type": "application/json", "admission-signature": await signWebhook(raw) } });
  };
  const heard = [await hear("adm_evt_bought", "subscription.created", { plan: "pro", interval: "month", status: "active" }),
    await hear("adm_evt_failed", "subscription.changed", { plan: "pro", interval: "month", status: "past_due" }),
    await hear("adm_evt_cancel", "subscription.changed", { plan: "pro", interval: "month", status: "active",
      endsAt: "2026-12-18T00:00:00Z" }),
    await hear("adm_evt_renew", "subscription.renewed", { plan: "pro", interval: "month", status: "active" }),
    await hear("adm_evt_bought", "subscription.created", { plan: "pro", interval: "month", status: "active" })];
  const plans = events((row) => row.event === "plan");
  check("plans: heard, three told and a renewal not", heard.every((got) => got.status === 200) && plans.length === 3
    && plans.map((row) => row.detail.how).sort().join() === "bought,cancelling,failed", { heard, plans: plans.map((row) => row.detail) });
  const forged = await call("plans", { method: "POST", query: { op: "webhook" }, raw: JSON.stringify({ id: "adm_evt_x", type: "customer.updated",
    mode: "test", data: { customerId: payer, reason: "subscription.created", customer: null } }),
  headers: { "content-type": "application/json", "admission-signature": "t=1,v1=" + "0".repeat(64) } });
  check("plans: what Admission did not sign raises nothing", forged.status === 400 && events((row) => row.event === "plan").length === 3);
  // Server errors (api/_noted.js): three answers of 503 from the feedback route.
  await admin("notify_set", { body: { events: { errors: { threshold: 3 } } } });
  flags.feedbackDown = true;
  const fives = [];
  for (let n = 0; n < 3; n += 1) {
    fives.push((await call("plans", { method: "POST", query: { op: "feedback" }, token: reporter,
      body: { kind: "idea", words: "A darker grid, please.", source: "site" } })).status);
  }
  flags.feedbackDown = false;
  const errorRows = rows("owner_notify_errors");
  check("errors: each 5xx written down, by function and op", fives.join() === "503,503,503" && errorRows.length === 3
    && errorRows.every((row) => row.fn === "plans" && row.op === "feedback" && row.status === 503 && row.scope === "live"),
  { fives, errorRows });
  // Supabase: the database past 80% of its 8 GB.
  flags.usage = { database: Math.round(7.2 * 1024 ** 3), buckets: [{ bucket: "shared-models", files: 9, bytes: 20 * 1024 ** 3 }] };
  // The social desk: a reply came in, and four scheduled posts moved.
  const at = new Date().toISOString();
  const pressed = { pressed_at: at, pressed_by: "owner@example.com", pressed_hash: "a".repeat(64), route: "api" };
  const behind = (table, row) => fetch(`${SUPABASE_URL}/rest/v1/${table}`, { method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify(row) });
  await behind("social_items", { provider: "reddit", test: true, external_id: "t1_abc", kind: "reply", author: "brickfan", community: "lego",
    body: "Does it export to LDraw?", url: "https://www.reddit.com/r/lego/comments/x/y/abc/", made_at: at, seen_at: at });
  for (const [id, status, extra] of [["sendwent01", "sent", { sent_at: at, url: "https://www.reddit.com/r/lego/comments/went/" }],
    ["sendfail01", "failed", { said: "Reddit said 403: you are doing that too much" }],
    ["sendunsr01", "sending", { said: "Unsure: Reddit did not answer in time" }],
    ["sendhand01", "scheduled", { route: "by_hand" }]]) {
    await behind("social_sends", { id, provider: "reddit", kind: "post", community: "lego", title: `A free LEGO CAD (${id})`, body: "Words",
      status, send_at: new Date(Date.now() - 60000).toISOString(), test: true, ...pressed, ...extra });
  }
  n0 = sent.length;
  const each = await flush({ force: true });
  const bySubject = Object.fromEntries(mailsSince(n0).map((one) => [one.subject, one]));
  check("each: one mail a kind, six", each.mails.length === 6 && mailsSince(n0).length === 6, Object.keys(bySubject));
  const errorsMail = bySubject["Server errors: 3 in an hour"];
  check("each: server errors, with where they came from and the Site link", errorsMail?.text.includes(
    "- 3 server errors in the last hour, past your 3; most from plans feedback (3)") && errorsMail.text.includes(`  ${ADMIN}#site`),
  errorsMail?.text);
  const quotaMail = bySubject["Supabase: the database at 90%"];
  check("each: Supabase near its quota, with the Data link", quotaMail?.text.includes("- The database is at 90% of its 8 GB (your line: 80%)")
    && quotaMail.text.includes(`  ${ADMIN}#data`) && events((row) => row.event === "quota").length === 1, quotaMail?.text);
  const planMail = bySubject["3 plans and payments"];
  check("each: plans and payments, each said, to the person's page", ["@payer: bought Pro (monthly)", "@payer: a payment failed (Pro)",
    "@payer: cancelled Pro: it ends 2026-12-18"].every((line) => planMail?.text.includes(`- ${line}`))
    && planMail.text.includes(`  ${ADMIN}#people/${payer}`), planMail?.text);
  const sendMail = bySubject["4 scheduled posts"];
  check("each: scheduled posts that went, failed, may be up or are due", ["went", "did not go: Reddit said 403: you are doing that too much",
    "may be up, or not: look on the network", "is due: post it by hand"].every((how) => sendMail?.text.includes(how))
    && sendMail.text.includes("  https://www.reddit.com/r/lego/comments/went/") && sendMail.text.includes(`  ${ADMIN}#social/sent`),
  sendMail?.text);
  const feedbackMail = bySubject["Bug report: “The bin forgets my parts after a reload.”"];
  check("each: a bug report, its words, its link, and its sender by handle, never an address", feedbackMail?.text.includes(
    "- Bug report from @fbr: “The bin forgets my parts after a reload.”") && feedbackMail.text.includes(`  ${ADMIN}#feedback-41`)
    && !/•••|@resend\.dev/.test(feedbackMail.text.split("\nWhat mails you")[0]) && !/fb•••|f•••@/.test(feedbackMail.html || ""),
  feedbackMail?.text);
  const modelMail = bySubject["First model published: “Lighthouse”"];
  check("each: a first model, at its page", modelMail?.text.includes("- @maker published their first model, “Lighthouse” (2 parts), at its link")
    && /\n {2}https:\/\/brickworks\.diy\/m\/[A-Za-z0-9]+\n/.test(modelMail.text), modelMail?.text);
  check("each: each mail its own kind's off link and header", Object.values(bySubject).every((one) => {
    const kind = /#notifications\/off\/([a-z_]+)\/t\//.exec(one.text)?.[1];
    return kind && one.headers?.["List-Unsubscribe"]?.includes(`event=${kind}&pool=t&`);
  }), Object.values(bySubject).map((one) => one.headers));
  check("each: what came in on the desk waits for the digest", events((row) => row.event === "social").length === 1
    && events((row) => row.event === "social")[0].state === "digest");
  const again = await flush({ force: true });
  check("each: read again, nothing new and no second alert", again.mails.length === 0 && events((row) => row.event === "errors").length === 1
    && events((row) => row.event === "social_send").length === 4, again);
  pass(2 * 3600000);
  flags.supabaseDown = true;
  n0 = sent.length;
  await flush({ force: true });
  flags.supabaseDown = false;
  check("each: Supabase refusing the project, mailed at once", mailsSince(n0)[0]?.subject === "Supabase is refusing the project"
    && mailsSince(n0)[0].text.includes("Supabase is refusing the project:"), mailsSince(n0).map((one) => one.subject));

  // 7b. A report sent signed out: said so, with no address in the mail
  //     (onreview: the sender went in as wi•••@domain).
  pass(2 * 3600000);
  const outReport = await call("plans", { method: "POST", query: { op: "feedback" },
    body: { kind: "question", words: "Can I sign up later?", source: "site", email: "out@resend.dev" } });
  n0 = sent.length;
  await flush();
  const outMail = mailsSince(n0)[0];
  check("feedback: sent signed out, the mail says so, with no address in it", outReport.status === 200
    && outMail?.text.includes("- Question from someone signed out: “Can I sign up later?”")
    && !/ou•••|out@/.test(`${outMail?.text}${outMail?.html}`), outMail?.text);

  // 8. The digest, at the owner's time, once a day.
  pass(2 * 3600000);
  n0 = sent.length;
  await admin("notify_set", { body: { digest_at: "08:00" } });
  const day = await flush({ later: 0 });
  const digestMail = mailsSince(n0)[0];
  const local = notify.localOf(Date.now(), ZONE);
  check("digest: at its time, what came in on the desk", day.mails.length === 1 && digestMail?.subject === "Your Brickworks day: 1 new on the social desk"
    && digestMail.text.includes("- A reply from u/brickfan in r/lego: “Does it export to LDraw?”")
    && digestMail.text.includes(`Your daily digest, at 08:00 (${ZONE}).`), { day, text: digestMail?.text });
  check("digest: once a day", (await flush({ later: 0 })).mails.length === 0
    && rows("owner_notify_settings").find((row) => row.test)?.digest_on === local.date);
  await admin("notify_set", { body: { digest_at: "20:00" } });

  // 9. Quiet hours: held, and sent as one when they end.
  pass(2 * 3600000);
  await admin("notify_set", { body: { quiet: { on: true, from: "08:00", to: "11:00" } } });
  for (const words of ["The Undo button skips a step.", "Colours look washed out on my phone."]) {
    await call("plans", { method: "POST", query: { op: "feedback" }, token: reporter, body: { kind: "bug", words, source: "site" } });
  }
  await signUp("q01@resend.dev");
  n0 = sent.length;
  const hush = await flush();
  const quietRead = await admin("notify", { method: "GET" });
  check("quiet: nothing mailed, three held", hush.mails.length === 0 && hush.held === 3 && sent.length === n0
    && quietRead.json?.quiet_now === true && quietRead.json?.waiting?.held === 3, { hush, waiting: quietRead.json?.waiting });
  check("quiet: the hold audited", audit.some((row) => row.op === "notify_held" && row.target === "quiet hours" && row.detail?.said?.events === 3));
  await admin("notify_set", { body: { quiet: { on: true, from: "06:00", to: "08:00" } } });
  const woke = await flush();
  const quietMail = mailsSince(n0)[0];
  check("quiet: as they end, one mail of all three", woke.mails.length === 1 && mailsSince(n0).length === 1
    && quietMail?.subject === "While quiet hours were on: 2 bug reports and feedback, 1 new sign-up"
    && quietMail.text.includes("Held while your quiet hours were on, and sent as they ended."), { woke, subject: quietMail?.subject });
  await admin("notify_set", { body: { quiet: { on: false } } });

  // 10. The hour's cap: the rest folded into one, then held for the next hour.
  pass(2 * 3600000);
  await admin("notify_set", { body: { cap: 2 } });
  const raiseOne = (event, key, detail) => notify.raise(event, { ...T, key, detail });
  await raiseOne("plan", "cap1", { how: "bought", plan: "pro", interval: "year" });
  await raiseOne("feedback", "cap2", { kind: "idea", words: "Dark mode for the booklet." });
  await raiseOne("signup", "cap3", {});
  await raiseOne("first_model", "cap4", { name: "Tram", parts: 90 });
  n0 = sent.length;
  const capped = await flush();
  const subjects = mailsSince(n0).map((one) => one.subject);
  check("cap: two mails in the hour, the first kind alone and the rest in one", capped.mails.length === 2
    && subjects[0] === "Someone: bought Pro (yearly)"
    && subjects[1] === "And 3 more: 1 bug report or feedback, 1 new sign-up, 1 first model published"
    && mailsSince(n0)[1].text.includes("At most 2 mails an hour: what came past them is here, in one."), subjects);
  await raiseOne("feedback", "cap5", { kind: "question", words: "Can I print the booklet?" });
  await raiseOne("signup", "cap6", {});
  n0 = sent.length;
  const full = await flush();
  const capRead = await admin("notify", { method: "GET" });
  check("cap: past it, nothing mailed and two held for the next hour", full.mails.length === 0 && full.capped === 2 && sent.length === n0
    && capRead.json?.waiting?.capped === 2 && capRead.json?.hour?.sent === 2 && capRead.json.hour.cap === 2, { full, read: capRead.json?.hour });
  check("cap: the hold audited", audit.some((row) => row.op === "notify_held" && row.target === "the hour's cap" && row.detail?.said?.events === 2));
  pass(61 * 60000);
  const next = await flush({ later: 0 });
  check("cap: the next hour, one mail of both", next.mails.length === 1
    && mailsSince(n0)[0]?.subject === "And 2 more: 1 bug report or feedback, 1 new sign-up", mailsSince(n0).map((one) => one.subject));
  await admin("notify_set", { body: { cap: 6 } });

  // 11. Pause all, and one kind off.
  pass(2 * 3600000);
  await admin("notify_set", { body: { paused: true } });
  await raiseOne("feedback", "pause1", { kind: "bug", words: "Paused, this is never mailed." });
  n0 = sent.length;
  const paused = await flush();
  check("pause: nothing mailed, the event kept as paused", paused.mails.length === 0 && paused.state === "paused" && sent.length === n0
    && events((row) => row.key === "pause1")[0]?.state === "paused", paused);
  const pausedTest = await admin("notify_test", { body: {} });
  check("pause: a test still goes, and says so", pausedTest.status === 200 && pausedTest.json?.outcome === "sent"
    && sent.at(-1)?.text.includes("once you take off Pause all"), pausedTest);
  await admin("notify_set", { body: { paused: false, events: { feedback: { on: false } } } });
  await raiseOne("feedback", "off1", { kind: "bug", words: "Off, this is never mailed." });
  n0 = sent.length;
  await flush();
  check("off: a kind turned off is not mailed", sent.length === n0 && events((row) => row.key === "off1")[0]?.state === "off");
  await admin("notify_set", { body: { events: { feedback: { on: true } } } });

  // 12. The one-click links: the page's and the mail app's.
  const offPost = (asked, extra = {}) => call("plans", { method: "POST", query: { op: "notify_off", ...(extra.query || {}) },
    body: extra.raw === undefined ? asked : undefined, ...(extra.raw === undefined ? {} : { raw: extra.raw }), host: extra.host || HOST });
  const token = offLink?.[1] || "";
  const flipped = token.replace(/^./, (c) => (c === "0" ? "1" : "0"));
  const wrong = [await offPost({ event: "signup", pool: "t", token: flipped }), await offPost({ event: "signup", pool: "r", token }),
    await offPost({ event: "feedback", pool: "t", token }), await offPost({ event: "signup", pool: "t", token }, { host: "brickworks-x.vercel.app" }),
    await offPost({ event: "nothing", pool: "t", token })];
  check("off link: anything not signed for it, 404", wrong.every((got) => got.status === 404), wrong.map((got) => got.status));
  const offOk = await offPost({ event: "signup", pool: "t", token });
  const afterOff = await admin("notify", { method: "GET" });
  check("off link: turns that kind off, and is audited", offOk.status === 200 && offOk.json?.off === true
    && afterOff.json?.settings?.events?.signup?.on === false && audit.some((row) => row.op === "notify_off" && row.target === "signup"),
  { offOk, signup: afterOff.json?.settings?.events?.signup });
  const header = /<([^>]+)>/.exec(feedbackMail?.headers?.["List-Unsubscribe"] || "")?.[1] || "";
  const query = Object.fromEntries(new URL(header || "https://x/").searchParams);
  const oneClick = await offPost(null, { query, raw: "List-Unsubscribe=One-Click" });
  const afterClick = await admin("notify", { method: "GET" });
  check("off link: the mail app's one-click POST (RFC 8058) turns it off", oneClick.status === 200
    && afterClick.json?.settings?.events?.feedback?.on === false, { oneClick, query });
  await signUp("off01@resend.dev");
  await flush();
  check("off link: a sign-up after it is not mailed", events((row) => row.account === users.get("off01@resend.dev"))[0]?.state === "off");
  await admin("notify_set", { body: { events: { signup: { on: true }, feedback: { on: true } } } });

  // 13. Send a test, and its hour's limit.
  const sample = await admin("notify_test", { body: { event: "plan" } });
  check("test: a kind's sample, to the checks' inbox", sample.status === 200 && sample.json?.to === "de•••@resend.dev"
    && sent.at(-1)?.subject === "[Test] @ada: bought Pro (monthly)" && sent.at(-1).text.includes("Made up for the test: nobody did this.")
    && sent.at(-1).to.join() === notify.TEST_INBOX, { sample, subject: sent.at(-1)?.subject });
  const unknown = await admin("notify_test", { body: { event: "nope" } });
  check("test: a kind there is not, refused", unknown.status === 400, unknown);
  let tries = 2;
  let limited = null;
  let whole = null;
  while (tries < 12 && !limited) {
    // The first with its kind sent as false: no kind, so a test of the whole.
    const got = await admin("notify_test", { body: whole ? {} : { event: false } });
    whole ||= { status: got.status, subject: sent.at(-1)?.subject };
    tries += 1;
    if (got.status === 429) limited = { got, tries };
  }
  check("test: a kind sent as false is a test of the whole", whole?.status === 200
    && whole.subject === "A test from Brickworks' notifications", whole);
  check("test: at most ten an hour", limited?.tries === 11, limited);
  // 13b. On a preview, a test in its real pool (no ?tests=1) goes to the
  //      owner as asked and leaves the pool off: Check now there mails
  //      nobody (onreview: the test's row made it mail the owner).
  {
    const PREVIEW = "brickworks-pv.vercel.app";
    const ownerWas = process.env.MASTER_EMAIL;
    process.env.MASTER_EMAIL = "owner-preview@resend.dev";
    const asOwner = await w.signIn({ sub: "44444444-4444-4444-8444-444444444444", email: "owner-preview@resend.dev" });
    const tried = await admin("notify_test", { tests: false, host: PREVIEW, token: asOwner, body: {} });
    const triedTo = sent.at(-1)?.to?.join();
    const read1 = await admin("notify", { method: "GET", tests: false, host: PREVIEW, token: asOwner });
    await notify.raise("feedback", { scope: PREVIEW, test: false, key: "pv1", detail: { kind: "bug", words: "Raised on a preview." } });
    n0 = sent.length;
    const checkNow = await admin("notify_flush", { tests: false, host: PREVIEW, token: asOwner, body: {} });
    const read2 = await admin("notify", { method: "GET", tests: false, host: PREVIEW, token: asOwner });
    process.env.MASTER_EMAIL = ownerWas;
    check("test: on a preview, a test leaves its pool off, and Check now there mails nobody", tried.status === 200
      && triedTo === "owner-preview@resend.dev" && read1.json?.active === false && read1.json?.set === false
      && checkNow.status === 200 && checkNow.json?.mails === 0 && sent.length === n0 && read2.json?.active === false
      && rows("owner_notify_events").find((one) => one.key === "pv1")?.state === "paused",
    { tried: tried.status, triedTo, read1: read1.json?.active, checkNow: checkNow.json, sent: sent.length - n0 });
  }

  // 14. Another address: only once its code is typed; the checks' only at resend.dev.
  const realAddress = await admin("notify_address", { body: { address: "me@example.com" } });
  check("address: the checks' own never to a real address", realAddress.status === 400 && /resend\.dev/.test(realAddress.json?.error || ""),
    realAddress);
  n0 = sent.length;
  // Pasted as a mail app copies it: a zero-width space before, a no-break space after.
  const asked = await admin("notify_address", { body: { address: "\u200BNotes@resend.dev\u00A0" } });
  const codeMail = mailsSince(n0)[0];
  const code = /: (\d{6})\n/.exec(codeMail?.text || "")?.[1];
  check("address: a code mailed to it (pasted with zero-width and no-break spaces), kept without the code", asked.status === 200 && asked.json?.pending === "no•••@resend.dev"
    && codeMail?.to?.join() === "notes@resend.dev" && Boolean(code)
    && rows("owner_notify_mails").find((row) => row.kind === "confirm")?.body.includes("••••••")
    && !rows("owner_notify_mails").some((row) => row.body.includes(code)), { asked, text: codeMail?.text });
  const badCode = await admin("notify_confirm", { body: { code: code === "000000" ? "000001" : "000000" } });
  // Typed on a phone's full-width keys, with a space in it.
  const wide = [...code].map((digit) => String.fromCharCode(0xFF10 + Number(digit))).join("");
  const goodCode = await admin("notify_confirm", { body: { code: `${wide.slice(0, 3)} ${wide.slice(3)}` } });
  const noneWaiting = await admin("notify_confirm", { body: { code } });
  check("address: a wrong code refused, the right one (full-width, a space in it) kept once", badCode.status === 400 && goodCode.status === 200
    && goodCode.json?.to === "no•••@resend.dev" && noneWaiting.status === 409, { badCode, goodCode, noneWaiting });
  pass(2 * 3600000);
  await raiseOne("feedback", "addr1", { kind: "bug", words: "Mailed to the new address." });
  n0 = sent.length;
  await flush();
  check("address: mail goes there now", mailsSince(n0)[0]?.to?.join() === "notes@resend.dev");
  const backHome = await admin("notify_address", { body: { address: "" } });
  check("address: back to the account's own", backHome.status === 200 && backHome.json?.own === true
    && rows("owner_notify_settings").find((row) => row.test)?.address === null, backHome);
  // 15. Resend failing: tried again, three times at most, each audited.
  pass(2 * 3600000);
  flags.resendDown = true;
  await raiseOne("feedback", "fail1", { kind: "bug", words: "Resend is down for this one." });
  const failed = [];
  for (let n = 0; n < 4; n += 1) {
    failed.push((await flush({ later: GAP })).mails.map((one) => one.state).join() || "none");
    pass(61 * 60000);
  }
  flags.resendDown = false;
  const given = events((row) => row.key === "fail1")[0];
  check("failing: tried three times, then given up", failed.join("|") === "failed|failed|failed|none" && given?.state === "failed"
    && given.tries === 3, { failed, given });
  check("failing: each audited, with Resend's words", audit.filter((row) => row.op === "notify_failed").length === 3
    && audit.find((row) => row.op === "notify_failed")?.said === "Resend said 500: down");

  // 16. Notifications › Sent, and one mail's words, the pool's own only.
  const read = await admin("notify", { method: "GET" });
  const ops = new Set((read.json?.sent || []).map((one) => one.op));
  check("sent: the audit of what was sent, folded, held, failed and turned off", ["notify_sent", "notify_folded", "notify_held",
    "notify_failed", "notify_off"].every((op) => ops.has(op)), [...ops]);
  const oneMail = await admin("notify", { method: "GET", query: { mail: burstRow?.id } });
  const otherPool = await admin("notify", { method: "GET", tests: false, query: { mail: burstRow?.id } });
  check("sent: a mail's words, and never another pool's", oneMail.json?.mail?.subject === "12 new sign-ups" && otherPool.status === 404,
    { one: oneMail.status, other: otherPool.status });
  const now = await admin("notify_flush", { body: {} });
  check("check now: the run, answered", now.status === 200 && typeof now.json?.outcome === "string", now);

  // 16b. A digest whose time is inside quiet hours that run past midnight
  //     (onreview A: 23:00 in 22:00-07:00 never went): sent as they end,
  //     once a day, across both of 2027's clock changes in the owner's zone,
  //     run every five minutes. A pool of its own, only feedback on.
  {
    const DQ = { scope: "brickworks-dq.vercel.app", test: true };
    const DAY = 86400000;
    const only = Object.fromEntries(Object.keys(notify.EVENTS).map((name) => [name, { on: name === "feedback", when: "digest" }]));
    let k = 0;
    const days = async ({ tz, quiet, digestAt, start, n, extra = [] }) => {
      for (const one of held.liveRowsOf("owner_notify_settings")) if (one.scope === DQ.scope) one.digest_on = null;
      const set = await admin("notify_set", { host: DQ.scope, body: { tz, quiet, digest_at: digestAt, cap: 60, events: only } });
      const got = [];
      const t0 = Date.parse(start);
      for (let t = t0; t < t0 + n * DAY; t += 5 * 60000) {
        if ((t - t0) % DAY === 0 || extra.includes(t)) {
          await notify.raise("feedback", { ...DQ, key: `dq${k += 1}`, detail: { kind: "bug", words: `Number ${k}.` } });
        }
        const ran = await notify.flush(DQ, { now: t });
        for (const mail of ran.mails) got.push({ ...notify.localOf(t, tz), subject: mail.subject });
      }
      const waiting = rows("owner_notify_events").filter((one) => one.scope === DQ.scope && one.state === "digest").length;
      return { set: set.status, got, waiting };
    };
    // Europe/London springs forward at 01:00 GMT on 28 March 2027.
    const spring = await days({ tz: "Europe/London", quiet: { on: true, from: "22:00", to: "07:00" }, digestAt: "23:00",
      start: "2027-03-26T12:00:00Z", n: 4 });
    const springText = sent.filter((one) => /Your Brickworks day/.test(one.subject || "")).at(-1)?.text || "";
    check("digest: inside overnight quiet hours, sent at 07:00 as they end, once a day across the spring change",
      spring.set === 200 && spring.got.length === 4 && spring.got.every((one) => one.hhmm === "07:00")
      && spring.got.map((one) => one.date).join() === "2027-03-27,2027-03-28,2027-03-29,2027-03-30" && spring.waiting === 0
      && springText.includes("Your daily digest, at 23:00 (Europe/London), sent at 07:00 when quiet hours end."), spring);
    const said = await admin("notify", { method: "GET", host: DQ.scope });
    check("digest: the page says it goes as quiet hours end", said.json?.digest?.held_until === "07:00"
      && said.json?.digest?.said === "sent at 07:00 when quiet hours end", said.json?.digest);
    // ... and falls back at 02:00 BST on 31 October 2027: 01:30 comes twice
    // that night, with a report between the two.
    const autumn = await days({ tz: "Europe/London", quiet: { on: false }, digestAt: "01:30", start: "2027-10-29T12:00:00Z", n: 4,
      extra: [Date.parse("2027-10-31T00:45:00Z")] });
    const dates = autumn.got.map((one) => one.date);
    check("digest: once a day across the autumn change, though 01:30 came twice", autumn.got.length === 4
      && new Set(dates).size === 4 && dates.join() === "2027-10-29,2027-10-31,2027-11-01,2027-11-02"
      && autumn.got.slice(1).every((one) => one.hhmm === "01:30") && autumn.got[2]?.subject === "Your Brickworks day: 2 bug reports and feedback"
      && autumn.waiting === 0, autumn);
    // On the night it springs forward, 01:30 is never on the clock: with a
    // report waiting, it goes at 02:00, the first moment after.
    const gap = await days({ tz: "Europe/London", quiet: { on: false }, digestAt: "01:30", start: "2027-03-27T12:00:00Z", n: 2,
      extra: [Date.parse("2027-03-27T20:00:00Z")] });
    check("digest: a time the clock skips goes the first moment after it", gap.got.length === 3
      && gap.got[1]?.date === "2027-03-28" && gap.got[1]?.hhmm === "02:00" && gap.got[2]?.date === "2027-03-29"
      && gap.got[2]?.hhmm === "01:30" && gap.waiting === 0, gap);
  }

  // 16c. At a cap of 1 the hour's one mail is the hour's own, not "And 2
  //      more" after nothing (onreview C).
  pass(2 * 3600000);
  await admin("notify_set", { body: { cap: 1 } });
  await raiseOne("feedback", "one1", { kind: "idea", words: "One mail an hour, please." });
  await raiseOne("signup", "one2", {});
  n0 = sent.length;
  const lone = await flush();
  check("cap: at 1 an hour, the hour's one mail is titled as its own", lone.mails.length === 1
    && mailsSince(n0)[0]?.subject === "This hour: 1 bug report or feedback, 1 new sign-up"
    && mailsSince(n0)[0].text.includes("At most 1 mail an hour: what came is here, in one."), mailsSince(n0).map((one) => one.subject));
  await admin("notify_set", { body: { cap: 6 } });

  // 16d. Codes to another address: at most five an hour, counted as tests
  //      are (onreview: no limit).
  {
    n0 = sent.length;
    const asks = [];
    for (let n = 1; n <= 6; n += 1) asks.push(await admin("notify_address", { body: { address: `code${n}@resend.dev` } }));
    check("address: five codes an hour, the sixth refused in words and not mailed", asks.slice(0, 5).every((one) => one.status === 200)
      && asks[5].status === 429 && asks[5].json?.error === "5 codes an hour at most: try again later." && sent.length - n0 === 5,
    { statuses: asks.map((one) => one.status), said: asks[5].json?.error, mailed: sent.length - n0 });
    await admin("notify_address", { body: { address: "" } });
  }

  // 17. An account deleted: its events go, and the words of the mails of it.
  flags.erasing = true;
  const { erase } = await import("../../../api/_erase.js");
  const erased = await erase(ada);
  flags.erasing = false;
  const scrubbed = rows("owner_notify_mails").find((row) => row.id === burstRow?.id);
  check("erase: its events gone, its mail's words with them", erased?.status === 200 && events((row) => row.account === ada).length === 0
    && scrubbed?.subject === "About an account since deleted" && scrubbed.body === "", { erased, scrubbed });

  // 18. The cron: run by hand on a preview, only that preview's pools.
  pass(2 * 3600000);
  await admin("notify_set", { tests: false, body: { paused: true } });
  await raiseOne("feedback", "cron1", { kind: "bug", words: "Mailed by the cron." });
  pass(GAP);
  n0 = sent.length;
  const byHand = await call("plans", { query: { op: "owner_notify" }, headers: { authorization: "Bearer cron-check-secret" },
    host: "brickworks-check.vercel.app" });
  check("cron: by hand on a preview, the site's pools untouched", byHand.status === 200 && sent.length === n0
    && events((row) => row.key === "cron1")[0]?.state === "new" && byHand.json?.pools?.every((one) => one.startsWith("brickworks-check")),
  byHand);
  const fromVercel = await call("plans", { query: { op: "owner_notify" }, headers: { authorization: "Bearer cron-check-secret",
    "user-agent": "vercel-cron/1.0" } });
  check("cron: Vercel's, the site's pools", fromVercel.status === 200 && events((row) => row.key === "cron1")[0]?.state === "mailed"
    && mailsSince(n0).length === 1, fromVercel);

  // 19. The database itself refusing (a spend cap): the cron cannot read its
  //     tables, so the owner is told without them, once a day.
  const heldFetch = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input.url || input));
    if (url.origin === SUPABASE_URL && /^\/(rest|storage)\//.test(url.pathname)) {
      return reply(402, { message: "Project restricted: the organization is over its spend cap" });
    }
    return heldFetch(input, init);
  };
  const ownerWas = process.env.MASTER_EMAIL;
  process.env.MASTER_EMAIL = "owner-alarm@resend.dev";
  n0 = sent.length;
  const vercel = { authorization: "Bearer cron-check-secret", "user-agent": "vercel-cron/1.0" };
  const refusedRuns = [await call("plans", { query: { op: "owner_notify" }, headers: vercel }),
    await call("plans", { query: { op: "owner_notify" }, headers: vercel }),
    await call("plans", { query: { op: "owner_notify" }, headers: { authorization: "Bearer cron-check-secret" },
      host: "brickworks-check.vercel.app" })];
  globalThis.fetch = heldFetch;
  process.env.MASTER_EMAIL = ownerWas;
  const alarms = mailsSince(n0);
  check("alarm: the database refusing, mailed without it to the owner's own address", refusedRuns[0].status === 500
    && refusedRuns[0].json?.alarm === "sent" && alarms[0]?.to?.join() === "owner-alarm@resend.dev"
    && alarms[0]?.subject === "Supabase is refusing the project" && alarms[0]?.headers === undefined
    && /^owner-notify-alarm-\d{4}-\d\d-\d\d$/.test(alarms[0]?.once || ""), { refusedRuns, alarms });
  check("alarm: at most one a day, and never from a preview run by hand", alarms.length === 1
    && refusedRuns[1].json?.alarm === "already today" && refusedRuns[2].json?.alarm === undefined, refusedRuns.map((one) => one.json));

  // 19b. Every hook after the answer (api/_after.js): with owner_notify's
  //     tables hung, each path answers in under 300 ms, nothing thrown into
  //     it, and what it raised lands once the tables answer within the bound.
  {
    let release = () => {};
    let gate = null;
    const hang = () => {
      gate = new Promise((resolve) => { release = resolve; });
    };
    const below = globalThis.fetch;
    globalThis.fetch = async (input, init = {}) => {
      const url = new URL(String(input.url || input));
      if (gate && url.origin === SUPABASE_URL && /^\/rest\/v1\/owner_notify_(events|errors)$/.test(url.pathname)
        && String(init.method || "GET").toUpperCase() === "POST") {
        await new Promise((resolve, reject) => {
          gate.then(resolve);
          init.signal?.addEventListener?.("abort", () => reject(init.signal.reason));
        });
      }
      return below(input, init);
    };
    try {
      const hungMakerId = randomUUID();
      const hungMaker = await w.signIn({ sub: hungMakerId, email: "hungmaker@resend.dev" });
      const errorsBefore = rows("owner_notify_errors").length;
      hang();
      const began = performance.now();
      flags.publishing = true;
      const paths = {
        otp: await call("otp", { method: "POST", body: { email: "hung01@resend.dev", came }, settle: false }),
        share: await call("share", { method: "POST", token: hungMaker, body: { name: "Signal box", image: PNG, model: model("Signal box") },
          settle: false }),
      };
      flags.publishing = false;
      paths.feedback = await call("plans", { method: "POST", query: { op: "feedback" }, token: reporter,
        body: { kind: "bug", words: "Sent while the table hung.", source: "site" }, settle: false });
      paths.webhook = await (async () => {
        const raw = JSON.stringify({ id: "adm_evt_hung", type: "customer.updated", createdAt: new Date().toISOString(), mode: "test", seq: 2,
          data: { customerId: payer, reason: "subscription.created", customer: { plan: { key: "pro" },
            subscription: { plan: "pro", interval: "year", status: "active" } } } });
        return call("plans", { method: "POST", query: { op: "webhook" }, raw, settle: false,
          headers: { "content-type": "application/json", "admission-signature": await signWebhook(raw) } });
      })();
      flags.feedbackDown = true;
      paths.error = await call("plans", { method: "POST", query: { op: "feedback" }, token: reporter,
        body: { kind: "idea", words: "A 503 while the table hung.", source: "site" }, settle: false });
      flags.feedbackDown = false;
      const asked = performance.now() - began;
      const hungAnswers = Object.fromEntries(Object.entries(paths).map(([name, got]) => [name, `${got.status} in ${Math.round(got.ms)} ms`]));
      check("after: with the tables hung, every path answers as before, each in under 300 ms",
        paths.otp.status === 200 && paths.share.status === 201 && paths.feedback.status === 200 && paths.webhook.status === 200
        && paths.error.status === 503 && Object.values(paths).every((got) => got.ms < 300 && !got.threw), hungAnswers);
      const landedBefore = events((row) => row.key === String(paths.feedback.json?.id)).length;
      // The tables answer again, within the bound of the first.
      release();
      gate = null;
      await settled();
      const signupRow = events((row) => row.event === "signup" && row.account === users.get("hung01@resend.dev"))[0];
      const landed = { before: landedBefore, signup: Boolean(signupRow), came: signupRow?.detail?.came?.source,
        first_model: events((row) => row.event === "first_model" && row.account === hungMakerId).length,
        feedback: events((row) => row.key === String(paths.feedback.json?.id)).length,
        plan: events((row) => row.key === "adm_evt_hung").length, errors: rows("owner_notify_errors").length - errorsBefore, asked };
      check("after: what each raised lands once the tables answer within the bound", landed.before === 0 && landed.signup
        && landed.came === "reddit" && landed.first_model === 1 && landed.feedback === 1 && landed.plan === 1 && landed.errors === 1
        && asked < BOUND, landed);
      // Hung past the bound: still answered at once, and nobody waits past it.
      hang();
      const late = await call("plans", { method: "POST", query: { op: "feedback" }, token: reporter,
        body: { kind: "bug", words: "Sent while the table hung for good.", source: "site" }, settle: false });
      const t1 = performance.now();
      let threw = null;
      await settled().catch((trouble) => { threw = String(trouble); });
      const waited = performance.now() - t1;
      release();
      gate = null;
      check("after: hung past the bound, answered at once, and given up at the bound without a throw", late.status === 200 && late.ms < 300
        && threw === null && waited >= BOUND - 300 && waited < BOUND + 500, { late: late.status, ms: late.ms, waited, threw });
    } finally {
      globalThis.fetch = below;
      flags.publishing = false;
      flags.feedbackDown = false;
    }
  }

  // 19c. On Vercel the work is the request's own: its context's waitUntil
  //     is given it, called as the context's method, and nothing is kept
  //     here (the shape @vercel/functions 3.10.6 reads, get-context.js).
  {
    const CONTEXT = Symbol.for("@vercel/request-context");
    const given = [];
    const context = { waitUntil(promise) { given.push({ promise, self: this === context }); } };
    globalThis[CONTEXT] = { get: () => context };
    const how = afterHow();
    const read = await admin("notify", { method: "GET" });
    const got = await call("plans", { method: "POST", query: { op: "feedback" }, token: reporter,
      body: { kind: "bug", words: "Kept alive by Vercel.", source: "site" }, settle: false });
    delete globalThis[CONTEXT];
    await Promise.all(given.map((one) => one.promise));
    check("after: on Vercel, given to the request's waitUntil, and it lands", how === "waitUntil" && read.json?.after === "waitUntil"
      && got.status === 200 && given.length === 1 && given[0].self === true
      && events((row) => row.key === String(got.json?.id)).length === 1 && afterHow() === "bounded",
    { how, after: read.json?.after, given: given.length, status: got.status });
  }

  // 19d. The old rows pruned once a UTC day at its first run, whenever it
  //     comes (onreview: only a run at 03:00-03:04 UTC pruned); before
  //     owner_notify2.sql's pruned_on, in the hour from 03:00 UTC.
  {
    await admin("notify_set", { body: { paused: true } });
    const DAY = 86400000;
    const site = () => held.liveRowsOf("owner_notify_settings").find((one) => one.scope === "live" && !one.test);
    const old = async (key) => {
      await notify.raise("feedback", { scope: "live", test: false, key, detail: { kind: "bug", words: "Ninety-one days ago." } });
      const row = held.liveRowsOf("owner_notify_events").find((one) => one.key === key);
      row.at = new Date(Date.now() - 91 * DAY).toISOString();
    };
    const there = (key) => held.liveRowsOf("owner_notify_events").some((one) => one.key === key);
    // Tomorrow: today's was pruned by the cron's runs above.
    const day0 = Date.parse(`${new Date(Date.now() + DAY).toISOString().slice(0, 10)}T10:17:00Z`);
    await old("prune1");
    const first = await notify.notifyDue({ now: day0, scope: "live" });
    const firstOn = site()?.pruned_on;
    await old("prune2");
    const again = await notify.notifyDue({ now: day0 + 5 * 60000, scope: "live" });
    const nextDay = await notify.notifyDue({ now: day0 + DAY + 6 * 3600000, scope: "live" });
    check("prune: at a day's first run, any hour, once a day, by pruned_on", first.pruned === true && !there("prune1")
      && firstOn === new Date(day0).toISOString().slice(0, 10) && again.pruned === false && nextDay.pruned === true && !there("prune2")
      && site()?.pruned_on === new Date(day0 + DAY).toISOString().slice(0, 10),
    { first: first.pruned, firstOn, again: again.pruned, nextDay: nextDay.pruned, on: site()?.pruned_on });
    delete site().pruned_on;
    await old("prune3");
    const noColumn = await notify.notifyDue({ now: day0 + 2 * DAY, scope: "live" });
    const kept3 = there("prune3");
    const atThree = await notify.notifyDue({ now: Date.parse(`${new Date(day0 + 3 * DAY).toISOString().slice(0, 10)}T03:40:00Z`), scope: "live" });
    check("prune: before owner_notify2.sql, in the hour from 03:00 UTC, past its first five minutes too", noColumn.pruned === false && kept3
      && atThree.pruned === true && !there("prune3") && !("pruned_on" in site()), { noColumn: noColumn.pruned, kept3, atThree: atThree.pruned });
    site().pruned_on = null;
    await admin("notify_set", { body: { paused: false } });
  }

  // 19e. A new person's two models published at once: one told of, the
  //      first made (api/share.js: no model of theirs made before the
  //      row was written, and once by the owner's key).
  {
    const twinId = randomUUID();
    const twin = await w.signIn({ sub: twinId, email: "twin@resend.dev" });
    flags.publishing = true;
    let open = () => {};
    flags.both = { owner: twinId, written: new Promise((resolve) => { open = resolve; }), open: () => open() };
    const twins = await Promise.all(["Tower", "Gate"].map((name) => call("share", { method: "POST", token: twin, settle: false,
      body: { name, image: PNG, model: model(name) } })));
    await settled();
    flags.publishing = false;
    flags.both = null;
    const twinEvents = events((row) => row.event === "first_model" && row.account === twinId);
    const twinFirst = models.filter((one) => one.owner === twinId).sort((a, b) => (a.created_at < b.created_at ? -1 : 1))[0];
    check("first model: two published at once, one told of, the first made", twins.every((one) => one.status === 201)
      && twinEvents.length === 1 && twinEvents[0].detail?.id === twinFirst?.id,
    { statuses: twins.map((one) => one.status), told: twinEvents.map((row) => row.detail?.name) });
  }

  // 20. Nobody real was mailed: every mail went to Resend's test inboxes.
  check("no real address: every mail to resend.dev", sent.length > 20 && sent.every((one) => one.to.every((to) => /@resend\.dev$/.test(to))),
    sent.map((one) => one.to).filter((to) => !to.every((one) => /@resend\.dev$/.test(one))));
  check("no real address: the site's own pool mailed nothing", rows("owner_notify_mails").every((row) => row.test || row.scope !== "live"));
  out = { checks, sent: sent.length };
} catch (trouble) {
  out = { checks, threw: String(trouble?.stack || trouble).slice(0, 1200) };
}
out.errors = logged.filter((line) => /notify/.test(line)).slice(0, 20);
process.stdout.write(`${JSON.stringify(out)}\n`);
process.exit(0);
