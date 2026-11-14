// The owner's console's own reads, and the audit of every act (/admin;
// docs/ADMIN.md). api/admin.js asks these only after its owner check: a
// verified token and MASTER_EMAIL, 404 to anybody else. Everything here
// reads as the service role.
//
//   overview   what needs the owner now (reports open, feedback unread,
//              applications new, months still to give, a borrowed sender)
//              and how things stand (accounts and sign-ups, testers and
//              the months of Pro, models published, mail kept as sent, the
//              switches), with the newest acts of the audit
//   people     every account with what the console lists of it: joined,
//              last sign-in, how it signs in, its profile, its models, its
//              connectors, whether it is taken out, where it stands with
//              the beta, and its plan as far as the server knows it
//   person     one account whole: the same, its models one by one, its
//              feedback, its beta application, its plan as Admission says
//              (read, never written), and the acts of the audit on it
//   audit      the acts, newest first, filtered and paged
//   switches   the beta's switch where the console is open (api/_beta.js
//              betaSwitch), billing's mode (shown, never changed here),
//              the mail's sender and which outside services are set up
//
// audited() runs one of admin.js's acts and keeps it in admin_audit
// (supabase/console.sql), whatever came of it: who, what, on what, when,
// what was asked and what was said. Kept before the answer goes, so a
// function stopped after answering never loses one. Before console.sql is
// applied the act still runs, and its answer says audit: null.

import { isMaster } from "./_auth.js";
import { betaSwitch } from "./_beta.js";
import { billingMode, entitlementOf } from "./_billing.js";
import { db, reach } from "./_db.js";
import { scopeOf } from "./_settings.js";
import { siteSummary } from "./_console_site.js";
import { mailTrouble } from "./_console_mail.js";

const DAY = 864e5;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
export const isTestAddress = (email) => /@resend\.dev$/i.test(String(email || "").trim());

function project() {
  return (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

function secretHeaders(extra = {}) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  return { apikey: secret, authorization: `Bearer ${secret}`, ...extra };
}

/// A lookup that may fail on its own (a file not applied, a table not
/// there yet): null then, and the console says that part is not known.
const known = (promise) => Promise.resolve(promise).catch((trouble) => {
  if (!notYet(trouble)) console.error(`console: ${String(trouble?.message || trouble).slice(0, 160)}`);
  return null;
});

/// Every account, a thousand a page, at most ten pages.
export async function allUsers() {
  const users = [];
  for (let page = 1; page <= 10; page += 1) {
    const reply = await reach("server GET users", 15, `${project()}/auth/v1/admin/users?page=${page}&per_page=1000`,
      { headers: secretHeaders() });
    if (!reply.ok) throw new Error(`server GET users: ${reply.status}`);
    const listed = (await reply.json()).users || [];
    users.push(...listed);
    if (listed.length < 1000) break;
  }
  return users;
}

/// How many rows [path] (a PostgREST table and filter) has.
async function countOf(path) {
  const reply = await reach(`server COUNT ${path.split("?")[0]}`, 10, `${project()}/rest/v1/${path}`,
    { method: "HEAD", headers: secretHeaders({ prefer: "count=exact" }) });
  if (!reply.ok) throw new Error(`server COUNT ${path.split("?")[0]}: ${reply.status}`);
  const total = Number(String(reply.headers.get("content-range") || "").split("/")[1]);
  return Number.isFinite(total) ? total : null;
}

const providerOf = (user) => {
  const ways = user.app_metadata?.providers || (user.app_metadata?.provider ? [user.app_metadata.provider] : []);
  if (/@oc\.brickworks\.diy$/i.test(String(user.email || ""))) return "orangecheck";
  return ways.includes("email") || !ways.length ? "email" : ways[0];
};

/// The plan as far as the server knows it without asking Admission: the
/// owner's, a beta month given (Pro until it ends) or still to give, or Free.
function planOf(user, application, mode) {
  if (isMaster({ email: user.email })) return { name: "Owner", said: "every feature, unlimited" };
  if (application?.status === "approved" && application.comp === "granted") return { name: "Pro", said: "a beta month" };
  if (application?.status === "approved") {
    return { name: "Free", said: mode === "off" ? "a beta month to give when Pro launches" : "a beta month to give" };
  }
  return { name: "Free", said: mode === "off" ? "plans are off" : "" };
}

// ---------------------------------------------------------------------------
// The switches.

/// What is set where the console is open, and what is set up.
export async function switches(request) {
  let ready = true;
  try {
    await db("rpc/site_setting", { method: "POST", body: { p_name: "beta", p_scope: scopeOf(request) } });
  } catch (trouble) {
    if (!notYet(trouble)) throw trouble;
    ready = false;
  }
  const beta = await betaSwitch(request);
  const scope = scopeOf(request);
  return {
    beta: { ...beta, scope, ready },
    billing: { mode: billingMode() },
    mail: {
      sender: process.env.EMAIL_FROM || "Brickworks <noreply@brickworks.diy>",
      borrowing: process.env.EMAIL_FROM_FALLBACK || null,
      key: Boolean(process.env.RESEND_API_KEY),
      reply_to: String(process.env.BETA_REPLY_TO || "").trim() || null,
    },
    services: {
      database: Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SECRET_KEY),
      mail: Boolean(process.env.RESEND_API_KEY),
      admission: Boolean(String(process.env.ADMISSION_KEY || "").trim()),
      admission_read: Boolean(String(process.env.ADMISSION_READ_TOKEN || "").trim()),
      mail_events: Boolean(String(process.env.RESEND_WEBHOOK_SECRET || "").trim()),
      orangecheck: Boolean(process.env.OC_PROJECT_KEY),
      crons: Boolean(process.env.CRON_SECRET),
    },
  };
}

// ---------------------------------------------------------------------------
// The overview.

export async function overview(request, tests = false) {
  const now = Date.now();
  const since = (days) => new Date(now - days * DAY).toISOString();
  const test = tests ? "true" : "false";
  const [users, published, listed, fresh, reportsOpen, feedback, queue, testers, mail, audit, set, site, delivery]
    = await Promise.all([
    // The accounts may not be read (Supabase's sign-in refusing, 2026-11-12):
    // the rest is shown, with the backend's health saying why.
    known(allUsers()),
    known(countOf(`shared_models?select=id&published=is.true&test=is.${test}`)),
    known(countOf(`shared_models?select=id&published=is.true&listed=is.true&test=is.${test}`)),
    known(countOf(`shared_models?select=id&published=is.true&test=is.${test}&created_at=gte.${since(7)}`)),
    known(countOf("reports?select=id&resolved_at=is.null")),
    known(db("rpc/feedback_inbox", { method: "POST", body: { p_kind: null, p_beta: null, p_status: "new", p_tests: tests,
      p_limit: 1 } })),
    known(db("rpc/beta_queue", { method: "POST", body: { p_status: "new", p_tests: tests, p_limit: 1 } })),
    known(db("rpc/beta_testers_list", { method: "POST", body: { p_tests: tests, p_limit: 1 } })),
    known(db("rpc/admin_mail_counts", { method: "POST", body: { p_days: 7, p_tests: tests } })),
    known(auditOf({ tests, limit: 6 })),
    known(switches(request)),
    // The live release, the crons that failed or are late, and the
    // backend's health (api/_console_site.js); Resend's word on the week's
    // mail (api/_console_mail.js).
    known(siteSummary()),
    known(mailTrouble(tests)),
  ]);
  const mine = (users || []).filter((user) => isTestAddress(user.email) === tests);
  const after = (iso, days) => iso && Date.parse(iso) > now - days * DAY;
  return {
    tests,
    accounts: users === null ? null : {
      all: mine.length,
      joined_day: mine.filter((user) => after(user.created_at, 1)).length,
      joined_week: mine.filter((user) => after(user.created_at, 7)).length,
      signed_in_week: mine.filter((user) => after(user.last_sign_in_at, 7)).length,
    },
    models: { published, listed, published_week: fresh },
    reports: { open: reportsOpen },
    feedback: feedback ? { new: feedback.counts?.new ?? 0, all: feedback.counts?.all ?? 0 } : null,
    beta: {
      testers: testers ? testers.counts?.testers ?? 0 : null,
      pool: queue?.pool ?? null,
      applications: queue ? { new: queue.counts?.new ?? 0, waitlist: queue.counts?.waitlist ?? 0,
        pending: queue.counts?.pending ?? 0 } : null,
    },
    mail,
    delivery,
    site,
    audit: audit ? audit.rows : null,
    switches: set,
  };
}

// ---------------------------------------------------------------------------
// People.

/// Every account (the checks' own for [tests], and nobody else's), newest
/// sign-in first.
export async function people(tests = false) {
  const [users, tabs, models, profiles, barred, testers] = await Promise.all([
    allUsers(),
    known(db("relay_tabs?select=owner,seen_at&owner=not.is.null")),
    known(db("shared_models?select=owner,listed&published=is.true&limit=50000")),
    known(db("people?select=account,handle,name&limit=50000")),
    known(db("barred_accounts?select=account,at,reason&limit=5000")),
    known(db("rpc/beta_testers_list", { method: "POST", body: { p_tests: tests, p_limit: 1000 } })),
  ]);
  const tally = new Map();
  for (const tab of tabs || []) {
    const one = tally.get(tab.owner) || { connectors: 0, connector_seen: null, models: 0, listed: 0 };
    one.connectors += 1;
    if (!one.connector_seen || tab.seen_at > one.connector_seen) one.connector_seen = tab.seen_at;
    tally.set(tab.owner, one);
  }
  for (const model of models || []) {
    const one = tally.get(model.owner) || { connectors: 0, connector_seen: null, models: 0, listed: 0 };
    one.models += 1;
    if (model.listed) one.listed += 1;
    tally.set(model.owner, one);
  }
  const profile = new Map((profiles || []).map((one) => [one.account, one]));
  const out = new Map((barred || []).map((one) => [one.account, one]));
  const member = new Map((testers?.testers || []).map((one) => [one.account, one]));
  const mode = billingMode();
  const rows = users.filter((user) => isTestAddress(user.email) === tests).map((user) => {
    const t = tally.get(user.id) || {};
    const m = member.get(user.id);
    return {
      id: user.id,
      email: user.email || null,
      owner: isMaster({ email: user.email }),
      joined: user.created_at || null,
      last_sign_in: user.last_sign_in_at || null,
      confirmed: Boolean(user.email_confirmed_at || user.confirmed_at),
      signs_in_with: providerOf(user),
      handle: profile.get(user.id)?.handle ?? null,
      name: profile.get(user.id)?.name ?? null,
      models: t.models || 0,
      listed: t.listed || 0,
      connectors: t.connectors || 0,
      connector_seen: t.connector_seen || null,
      barred: out.has(user.id) ? { at: out.get(user.id).at, reason: out.get(user.id).reason ?? null } : null,
      beta: m ? { state: m.state, joined_at: m.joined_at ?? null, via: m.via ?? null, application: m.application ?? null } : null,
      plan: planOf(user, m?.application, mode),
    };
  }).sort((a, b) => String(b.last_sign_in || "").localeCompare(String(a.last_sign_in || "")));
  return { tests, billing: mode, beta_known: testers !== null, people: rows };
}

/// One account, whole; null when there is none.
export async function person(account, tests = false) {
  if (!UUID.test(String(account || ""))) return null;
  const reply = await reach("server GET user", 10, `${project()}/auth/v1/admin/users/${account}`, { headers: secretHeaders() });
  if (reply.status === 404) return null;
  if (!reply.ok) throw new Error(`server GET user: ${reply.status}`);
  const user = await reply.json();
  if (!user?.id) return null;
  const mode = billingMode();
  const [profile, models, tabs, barred, member, status, feedback, plan, audit, claudes] = await Promise.all([
    known(db(`people?account=eq.${account}&select=handle,name,bio,created_at`)),
    known(db(`shared_models?owner=eq.${account}&select=id,name,parts,published,listed,listed_at,barred,test,created_at`
      + "&order=created_at.desc&limit=200")),
    known(db(`relay_tabs?owner=eq.${account}&select=seen_at,open`)),
    known(db(`barred_accounts?account=eq.${account}&select=at,reason`)),
    known(db("rpc/beta_member", { method: "POST", body: { p_account: account } })),
    known(db("rpc/beta_status", { method: "POST", body: { p_account: account } })),
    known(db("rpc/feedback_mine", { method: "POST", body: { p_account: account } })),
    mode === "off" ? null : known(entitlementOf(account)),
    known(auditOf({ tests: null, kind: "account", target: account, limit: 50 })),
    known(db(`oauth_grants?owner=eq.${account}&select=client_name,created_at,used_at&order=created_at.desc&limit=20`)),
  ]);
  return {
    id: user.id,
    email: user.email || null,
    owner: isMaster({ email: user.email }),
    test: isTestAddress(user.email),
    joined: user.created_at || null,
    last_sign_in: user.last_sign_in_at || null,
    confirmed: Boolean(user.email_confirmed_at || user.confirmed_at),
    signs_in_with: providerOf(user),
    profile: profile?.[0] ?? null,
    models: models || [],
    connectors: (tabs || []).map((tab) => ({ seen_at: tab.seen_at, open: tab.open ?? null })),
    // Each Claude it let in to the connector (oauth_grants): the Connector
    // section has its conversations.
    claudes: (claudes || []).map((one) => ({ name: one.client_name || "a Claude", since: one.created_at, used_at: one.used_at })),
    barred: barred?.[0] ?? null,
    beta: member ? { state: member.state ?? null, joined_at: member.joined_at ?? null, via: member.via ?? null,
      application: status?.application ?? null, pool: status?.pool ?? null } : null,
    feedback: (feedback?.reports || []).map((one) => ({ id: one.id, kind: one.kind, status: one.status, at: one.at,
      words: String(one.words || "").slice(0, 200) })),
    billing: mode,
    plan: plan ? { standing: plan.standing, plan: plan.plan, owner: plan.owner === true,
      subscription: plan.subscription ?? null } : planOf(user, status?.application, mode),
    audit: audit?.rows ?? null,
    tests,
  };
}

// ---------------------------------------------------------------------------
// The audit.

/// The acts kept, newest first: {rows, more}; throws before console.sql.
/// [tests] null is both the tests' and the rest (an account's own history).
export async function auditOf({ tests = false, before = null, act = "", kind = "", target = "", query = "", limit = 50 } = {}) {
  const ask = (asTests) => db("rpc/admin_audit_list", { method: "POST", body: { p_before: before, p_limit: limit,
    p_tests: asTests, p_op: act || null, p_kind: kind || null, p_target: target || null, p_query: query || null } });
  if (tests !== null) return ask(tests);
  const [real, test] = await Promise.all([ask(false), ask(true)]);
  return { rows: [...real.rows, ...test.rows].sort((a, b) => b.id - a.id).slice(0, limit), more: real.more || test.more };
}

/// GET /api/admin?op=audit[&before=N][&act=OP][&kind=K&target=T][&q=WORDS][&tests=1].
export async function auditRoute(request, response) {
  const q = request.query || {};
  const before = q.before === undefined || q.before === "" ? null : Number(q.before);
  if (before !== null && (!Number.isSafeInteger(before) || before < 1)) {
    return response.status(400).json({ error: "before is an act's number" });
  }
  const act = String(q.act || "");
  if (act && !/^[a-z_]{1,40}$/.test(act)) return response.status(400).json({ error: "act is an op's name" });
  const kind = String(q.kind || "");
  if (kind && !/^[a-z_]{1,24}$/.test(kind)) return response.status(400).json({ error: "kind is a kind of thing" });
  try {
    const listed = await auditOf({ tests: String(q.tests || "") === "1", before, act, kind,
      target: String(q.target || "").slice(0, 200), query: String(q.q || "").slice(0, 100), limit: 50 });
    return response.status(200).json({ ready: true, ...listed });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(200).json({ ready: false, rows: [], more: false });
    throw trouble;
  }
}

// ---------------------------------------------------------------------------
// An act, kept.

/// A response that holds what an act answers, to keep it before it goes.
class Held {
  constructor() {
    this.statusCode = 200;
    this.headers = [];
    this.body = undefined;
  }

  status(code) {
    this.statusCode = code;
    return this;
  }

  setHeader(name, value) {
    this.headers.push([name, value]);
    return this;
  }

  json(body) {
    this.body = body;
    return this;
  }
}

function bodyOf(request) {
  if (typeof request.body !== "string") return request.body && typeof request.body === "object" ? request.body : {};
  try {
    return JSON.parse(request.body) || {};
  } catch {
    return {};
  }
}

const clip = (given, most = 200) => String(given ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim()
  .slice(0, most);
const name = (given, most = 200) => clip(given, most) || null;

/// What each act was on: [kind, target].
const TARGETS = {
  unlist: (q) => ["model", q.id],
  bar: (q, _, a) => (a?.account ? ["account", a.account] : q.id ? ["model", q.id] : ["account", q.account]),
  unbar: (q) => ["account", q.account],
  dismiss: (q) => ["report", q.report],
  untest: (q) => ["model", q.id],
  uncomment: (q) => ["comment", q.comment],
  remove_photo: (q) => ["photo", q.photo],
  remove_avatar: (q) => ["profile", q.handle],
  pick: (q) => ["model", q.id],
  unpick: (q) => ["pick", q.pick],
  challenge: (_, b, a) => ["challenge", a?.challenge ?? b.title],
  end_challenge: (q) => ["challenge", q.challenge],
  plan: () => ["challenges", "a year of themes"],
  beta_decide: (q) => ["account", q.account],
  beta_waitlist: (q) => ["account", q.account],
  beta_grant: () => ["beta", "months"],
  beta_switch: () => ["setting", "beta"],
  feedback_triage: (q) => ["feedback", q.id],
  feedback_reply: (q) => ["feedback", q.id],
};
const ASKED = ["id", "v", "days", "why", "reason", "decision", "note", "status", "words", "mode", "title", "starts_on",
  "ends_on", "most_parts", "set_number", "tested"];
const ANSWERED = ["listed", "barred", "file_barred", "unlisted", "files_barred", "resolution", "cleared", "removed", "ended",
  "pick", "until", "challenge", "granted", "pending", "mail", "was", "value", "scope", "refused", "again"];

/// What the audit keeps of an act: {kind, target, detail, test}.
export function describe(op, request, answer) {
  const q = request.query || {};
  const b = bodyOf(request);
  const [kind, target] = (TARGETS[op] || (() => [null, null]))(q, b, answer);
  const asked = {};
  for (const key of ASKED) {
    const given = b[key] ?? q[key];
    if (given !== undefined && given !== null && given !== "" && !(key === "id" && kind === "model")) asked[key] = clip(given);
  }
  if (op === "plan" && Array.isArray(b.themes)) asked.themes = b.themes.map((one) => clip(one?.month, 7)).join(", ");
  const said = {};
  if (answer && typeof answer === "object" && !Array.isArray(answer)) {
    for (const key of ANSWERED) if (answer[key] !== undefined && answer[key] !== null) said[key] = clip(answer[key], 120);
    if (answer.application?.status) said.status = clip(answer.application.status, 20);
    if (answer.application?.spot) said.spot = Number(answer.application.spot);
  }
  const test = String(q.tests || "") === "1" || answer?.test === true || answer?.application?.pool === "test"
    || answer?.pool?.pool === "test";
  return { kind, target: name(target), detail: { asked, said }, test };
}

/// [act] (one of admin.js's) run and kept in the audit, then answered.
export async function audited(op, act, request, response, claims, statusOf) {
  const held = new Held();
  try {
    await act(request, held, claims);
  } catch (trouble) {
    held.status(statusOf(trouble)).json({ error: trouble.message });
  }
  if (held.body === undefined) held.json({});
  const kept = describe(op, request, held.body);
  let audit = null;
  try {
    audit = await db("rpc/admin_audit_note", { method: "POST", body: { p_actor: clip(claims.email || "the owner", 320),
      p_account: UUID.test(String(claims.sub || "")) ? claims.sub : null, p_op: op, p_kind: kept.kind, p_target: kept.target,
      p_detail: kept.detail, p_status: held.statusCode, p_said: held.statusCode >= 400 ? clip(held.body?.error, 300) : null,
      p_test: kept.test, p_scope: scopeOf(request) } });
  } catch (trouble) {
    if (!notYet(trouble)) console.error(`console: audit: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  for (const [header, value] of held.headers) response.setHeader(header, value);
  const body = held.body && typeof held.body === "object" && !Array.isArray(held.body)
    ? { ...held.body, audit: audit === null ? null : Number(audit) } : held.body;
  return response.status(held.statusCode).json(body);
}
