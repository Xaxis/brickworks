// How people use the site and the studio (insights, 2026-11-18;
// docs/ANALYTICS.md, supabase/analytics.sql). The owner: "detailed
// analytics across the site so I can track and see how users are using
// every aspect of the site and the studio".
//
//   POST /api/plans?op=tally        a visit's beacon (web/tally.js): what
//                                   happened since the last one, counted.
//                                   Always 204, and nothing kept from a
//                                   browser asking not to be (DNT, GPC), from
//                                   the EU, the EEA, the UK or Switzerland
//                                   without the visitor's yes, or from a
//                                   check's browser unless it asked.
//   GET  /api/plans?op=tally_daily  Vercel's cron (/api/plans/tally-daily,
//                                   03:27 UTC): yesterday rolled up, rows
//                                   past 30 days forgotten.
//   GET  /api/admin?op=analytics    the console's Analytics (api/admin.js,
//                                   after its owner check): a range, its
//                                   filters, every section's numbers.
//   tallyCall(...)                  a tool call the connector relayed
//                                   (api/mcp.js): its name, whether it
//                                   went, how long it took.
//
// What is never kept: an address, an IP (Vercel's country header is read to
// know whether to ask, and let go), a page's id, a model, words typed, a
// file's path. An account is kept only as an HMAC of its id with a server
// secret, so the rows cannot be joined to anything outside this database,
// and the owner's console makes the same hash to join them to sign-ups.

import { createHmac } from "node:crypto";
import { AuthError, bearer, isTestAccount, verify } from "./_auth.js";
import { cronNoted, isCron } from "./_cron.js";
import { db, dbConfigured } from "./_db.js";

// Where the law asks for a visitor's yes before counting (GDPR and the
// ePrivacy rules, the UK's, Switzerland's): Vercel's country header. The
// EU's outermost regions and Åland have country codes of their own.
export const ASK_FIRST = new Set(["AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT",
  "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "IS", "LI", "NO", "GB", "CH",
  "RE", "GP", "MQ", "GF", "YT", "MF", "AX"]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const VISIT = /^[a-z0-9]{16}$/;
const NAME = /^[a-z0-9_:/#.-]{1,60}$/;
const MAX_BODY = 32768;
// The live site's hosts. Every deployment is a production one (tools/deploy.sh
// --prod --skip-domain), so VERCEL_ENV says "production" on a preview too
// (inreview H1): a row is people's only when it came to one of these.
const LIVE = new Set(["brickworks.diy", "www.brickworks.diy"]);

/// The secret an account's hash is keyed with: the deployment's
/// VIEW_SECRET, which shared views' signatures already keep stable (a new
/// one would start every account's history anew), under a prefix of its
/// own. None: accounts are not told apart.
function secret() {
  return process.env.VIEW_SECRET || "";
}

/// [id]'s hash as the rows keep it (24 hex characters), or null.
export function accountHash(id) {
  const key = secret();
  if (!key || !UUID.test(String(id || ""))) return null;
  return createHmac("sha256", key).update(`brickworks insights account|${String(id).toLowerCase()}`).digest("hex").slice(0, 24);
}

/// Whether [request] came to the live site, by the host Vercel routed it by.
export function liveHost(request) {
  const headers = request?.headers || {};
  const host = String(headers["x-forwarded-host"] || headers.host || "").split(",")[0].trim().toLowerCase().replace(/:\d+$/, "");
  return LIVE.has(host);
}

/// Whether a row is the checks' own: asked as one, not on the live site
/// (a preview, a local run), or by a test account (an @resend.dev address,
/// the console's isTestAddress: the checks' pool and the shared accounts).
export function testOf(request, email, asked = false) {
  return asked === true || process.env.VERCEL_ENV !== "production" || !liveHost(request) || isTestAccount({ email });
}

// ---------------------------------------------------------------------------
// The names a row may hold: closed sets the code that counts them names
// (api/_insights_names.js, made by tools/insights_names.py). A made-up name
// is let go before it reaches a row (inreview H2). Loaded at the first
// beacon, never by a tool call.

let known = null;
export async function namesKnown() {
  if (known) return known;
  const { NAMES } = await import("./_insights_names.js");
  const exact = new Map();
  for (const [surface, kinds] of Object.entries(NAMES.exact)) {
    for (const [kind, list] of Object.entries(kinds)) exact.set(`${surface}|${kind}`, new Set(list));
  }
  known = {
    exact,
    // Longest prefix first: phone_row_ before phone_.
    families: Object.entries(NAMES.families).sort((a, b) => b[0].length - a[0].length),
    words: NAMES.words.map((list) => new Set(list)),
    common: new Set([...NAMES.exact.studio.command, ...NAMES.exact.studio.tool, "#"]),
    js: new Set(NAMES.errors.js),
    gd: new Set(NAMES.errors.gd),
    mcp: new Set(NAMES.mcp),
  };
  return known;
}

/// Whether [name] is one the code counts as [surface] [kind]: [sets] from
/// namesKnown.
export function nameKnown(sets, surface, kind, name) {
  if (typeof name !== "string" || !NAME.test(name)) return false;
  if (kind === "error") {
    if (name === "js:rejection") return true;
    const js = /^js:([a-z0-9_.-]+):\d{1,7}$/.exec(name);
    if (js) return sets.js.has(js[1]);
    const gd = /^gd:([a-z0-9_/.-]+\.gd):\d{1,7}$/.exec(name);
    return surface === "studio" && Boolean(gd) && sets.gd.has(gd[1]);
  }
  if (sets.exact.get(`${surface}|${kind}`)?.has(name)) return true;
  if (surface !== "studio" || kind !== "press") return false;
  // A family: its prefix, then a number, a command, a tool or a word of its
  // own file, and at most one more of those after an underscore.
  for (const [prefix, file] of sets.families) {
    if (!name.startsWith(prefix)) continue;
    const rest = name.slice(prefix.length);
    const words = sets.words[file];
    const word = (one) => sets.common.has(one) || words.has(one);
    if (word(rest)) return true;
    for (let at = rest.indexOf("_"); at > 0; at = rest.indexOf("_", at + 1)) {
      if (word(rest.slice(0, at)) && word(rest.slice(at + 1))) return true;
    }
  }
  return false;
}

// The most each kind may count in one beacon, summed over its names: a page
// sends one every 15 s, so a person sees a few pages, presses a few dozen
// controls (inreview M2: one beacon counted 800,000 likes).
export const KIND_MOST = { view: 20, act: 20, panel: 20, tool: 60, press: 200, command: 60, part: 60, save: 30,
  run: 30, milestone: 5, load: 20, frames: 20, error: 50 };

/// A beacon's events as rows may hold them, at most 80, each name known
/// and each kind's count capped: anything else let go.
export function eventsOf(given, sets) {
  if (!Array.isArray(given)) return [];
  const out = [];
  const left = { ...KIND_MOST };
  for (const one of given.slice(0, 80)) {
    if (!Array.isArray(one)) continue;
    const [surface, kind, name, n, ms, ok] = one;
    if (!["site", "studio"].includes(surface) || !Object.hasOwn(KIND_MOST, kind) || !nameKnown(sets, surface, kind, name)) continue;
    const most = Math.min(Number.isFinite(n) ? Math.max(1, Math.round(n)) : 1, left[kind]);
    if (most < 1) continue;
    left[kind] -= most;
    out.push([surface, kind, name, most, Number.isFinite(ms) && ms >= 0 && ms <= 86400000 ? Math.round(ms * 10) / 10 : null,
      typeof ok === "boolean" ? ok : null]);
  }
  return out;
}

/// What a beacon says of its visit, from its known fields only: never the
/// rest of what was sent (inreview L1). Its landing is a page the site has,
/// and its last act ("press:render_go") a name of its kind, or none.
export function aboutOf(given, sets) {
  const a = given && typeof given === "object" && !Array.isArray(given) ? given : {};
  const text = (value, most) => (typeof value === "string" && value.length <= most ? value : undefined);
  const studio = a.studio === true;
  const last = /^([a-z]+):(.+)$/.exec(text(a.last, 60) || "");
  const lastKnown = last && Object.hasOwn(KIND_MOST, last[1])
    && (nameKnown(sets, studio ? "studio" : "site", last[1], last[2]) || (last[1] === "view" && nameKnown(sets, "site", "view", last[2])));
  return {
    landing: nameKnown(sets, "site", "view", a.landing) || a.landing === "/app" ? a.landing : undefined, studio,
    channel: text(a.channel, 12), source: text(a.source, 60), medium: text(a.medium, 40), campaign: text(a.campaign, 60),
    device: text(a.device, 10), browser: text(a.browser, 10), os: text(a.os, 10), lang: text(a.lang, 2),
    last: lastKnown ? last[0] : undefined,
  };
}

// Each client's beacons, by its address, held in this instance's memory and
// never written: a token bucket of BUCKET beacons, one more each REFILL_MS
// (a tab sends one each 15 s; four tabs keep well inside it), and at most
// NEW_VISITS new visits an hour. One address cannot fill the day (inreview
// M3).
const BUCKET = 40;
const REFILL_MS = 4000;
const NEW_VISITS = 60;
const clients = new Map();

/// Whether [request]'s client may send this beacon now; [fresh]: it starts
/// a visit.
export function clientMay(request, fresh, now = Date.now()) {
  const headers = request?.headers || {};
  const address = String(headers["x-real-ip"] || String(headers["x-forwarded-for"] || "").split(",")[0]).trim()
    || request?.socket?.remoteAddress || "";
  if (!address) return true;
  let one = clients.get(address);
  if (!one) {
    if (clients.size > 20000) {
      for (const [key, kept] of clients) if (now - kept.at > 3600000) clients.delete(key);
      if (clients.size > 20000) clients.clear();
    }
    one = { tokens: BUCKET, at: now, hour: now, visits: 0 };
    clients.set(address, one);
  }
  one.tokens = Math.min(BUCKET, one.tokens + (now - one.at) / REFILL_MS);
  one.at = now;
  if (now - one.hour > 3600000) {
    one.hour = now;
    one.visits = 0;
  }
  if (one.tokens < 1 || (fresh && one.visits >= NEW_VISITS)) return false;
  one.tokens -= 1;
  if (fresh) one.visits += 1;
  return true;
}

/// The signed-in account a beacon names, from its access token alone (the
/// bearer, or the body's, since a beacon sent as the page leaves cannot
/// carry a header): {id, email}, or null. Never a body's word for whose it
/// is (inreview H3, M1).
export async function signedIn(request, b) {
  const token = bearer(request) || (typeof b?.bearer === "string" && b.bearer.length < 4096 ? b.bearer : null);
  if (!token) return null;
  try {
    // Asked as a read: a beacon never holds a write back.
    const claims = await verify(token, { method: "GET" });
    return UUID.test(String(claims?.sub || "")) ? { id: claims.sub, email: String(claims.email || "") } : null;
  } catch {
    return null;
  }
}

function bodyOf(request) {
  if (Number(request.headers?.["content-length"] || 0) > MAX_BODY) return null;
  if (typeof request.body === "string") {
    if (request.body.length > MAX_BODY) return null;
    try {
      return JSON.parse(request.body);
    } catch {
      return null;
    }
  }
  return request.body && typeof request.body === "object" ? request.body : null;
}

/// POST /api/plans?op=tally: one visit's beacon. Always 204: it tells the
/// page nothing, and nothing it sent is ever said back.
export async function tallyRoute(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (request.method !== "POST") return response.status(405).json({ error: "POST a beacon" });
  // A browser asking not to be tracked is not, whatever its page sent.
  const headers = request.headers || {};
  if (String(headers.dnt || "") === "1" || String(headers["sec-gpc"] || "") === "1") return response.status(204).end();
  const b = bodyOf(request);
  if (!b || !VISIT.test(String(b.v || "")) || !dbConfigured()) return response.status(204).end();
  if (ASK_FIRST.has(String(headers["x-vercel-ip-country"] || "").toUpperCase()) && b.consent !== true) {
    return response.status(204).end();
  }
  if (!clientMay(request, b.first === true)) return response.status(204).end();
  const sets = await namesKnown();
  const seen = Array.isArray(b.seen)
    ? [...new Set(b.seen.filter((one) => nameKnown(sets, "studio", "press", one)))].slice(0, 400) : [];
  const seconds = Number.isFinite(b.seconds) ? Math.max(0, Math.min(3600, Math.round(b.seconds))) : 0;
  const who = await signedIn(request, b);
  try {
    await db("rpc/insights_take", { method: "POST", seconds: 8, body: {
      p_visit: b.v, p_about: aboutOf(b.about, sets), p_events: eventsOf(b.e, sets), p_seen: seen, p_account: accountHash(who?.id),
      p_seconds: seconds, p_test: testOf(request, who?.email, b.check === true),
    } });
  } catch (trouble) {
    // Before analytics.sql there is nowhere to keep it; anything else is said.
    if (!/: 404$/.test(String(trouble?.message || ""))) {
      console.error(`tally: not kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
  return response.status(204).end();
}

// Each account's address, as far as whether it is a test account: read once
// an hour an instance (the auth admin API), for a tool call to be told a
// check's from a person's.
const addresses = new Map();
async function emailOf(owner) {
  const held = addresses.get(owner);
  if (held && Date.now() - held.at < 3600000) return held.email;
  let email = "";
  try {
    const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
    const key = process.env.SUPABASE_SECRET_KEY;
    const reply = await fetch(`${base}/auth/v1/admin/users/${owner}`, { headers: { apikey: key, authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(3000) });
    email = reply.ok ? String((await reply.json())?.email || "") : "";
  } catch {
    email = "";
  }
  if (addresses.size > 5000) addresses.clear();
  addresses.set(owner, { email, at: Date.now() });
  return email;
}

/// A tool call the connector relayed (api/mcp.js): [owner]'s, named
/// [tool], [ok] or not (null: not told), [ms] long, at [host] (the
/// request's, to tell the live site from a preview). Kept with no account:
/// a person's choice not to be counted lives in their browser, which a
/// tool call does not come from (inreview M4); retention reads the relay's
/// own days. Never throws: the call is not the count's.
export async function tallyCall(owner, tool, ok, ms, host = "") {
  const name = String(tool || "").toLowerCase();
  if (!NAME.test(name) || !dbConfigured()) return;
  try {
    // A tool the connector serves, never a made-up name (inreview H2).
    if (!(await namesKnown()).mcp.has(name)) return;
    const email = UUID.test(String(owner || "")) ? await emailOf(owner) : "";
    await db("rpc/insights_call", { method: "POST", seconds: 5, body: { p_account: null, p_tool: name,
      p_ok: typeof ok === "boolean" ? ok : null, p_ms: Number.isFinite(ms) ? Math.max(0, Math.round(ms)) : null,
      p_test: testOf({ headers: { host } }, email) } });
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) {
      console.error(`tally: a call not counted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
}

/// An account deleted (api/_erase.js): every row of it, its days, its
/// firsts and its hash on visits and events, gone at once, not at the next
/// day's rollup. Throws when the database does not answer, so the deletion
/// can say so.
export async function forgetAccount(id) {
  const hash = accountHash(id);
  if (!hash || !dbConfigured()) return 0;
  try {
    return await db("rpc/insights_forget_account", { method: "POST", seconds: 8, body: { p_account: hash } });
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return 0;
    throw trouble;
  }
}

// ---------------------------------------------------------------------------
// The owner's reads (api/admin.js, after its owner check) and the cron.

/// Every account of [tests]'s kind, as the SQL joins them: its hash, id,
/// when it joined and its plan (owner, pro, tester or free). Read by the
/// console's People (api/_console.js), imported only here, so a beacon never
/// loads it.
async function accountsOf(tests) {
  const { people } = await import("./_console.js");
  const read = await people(tests);
  return (read.people || []).map((one) => ({
    h: accountHash(one.id),
    id: one.id,
    joined: one.joined,
    plan: one.owner ? "owner" : one.plan?.name === "Pro" ? "pro" : one.beta?.state === "tester" ? "tester" : "free",
  })).filter((one) => one.h);
}

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const iso = (date) => date.toISOString().slice(0, 10);

/// The range and filters asked (?from=&to=&device=&lang=&plan=&signed=):
/// the last 30 days to today, and everyone but the owner, unless asked.
export function askedOf(query = {}) {
  const today = new Date();
  const to = DAY.test(String(query.to || "")) ? String(query.to) : iso(today);
  const from = DAY.test(String(query.from || "")) ? String(query.from)
    : iso(new Date(Date.parse(`${to}T00:00:00Z`) - 29 * 86400000));
  if (Date.parse(to) < Date.parse(from) || Date.parse(to) - Date.parse(from) > 400 * 86400000) {
    throw new AuthError("a range of at most 400 days, from before to", 400);
  }
  const filters = {};
  if (["desktop", "phone", "tablet"].includes(query.device)) filters.device = query.device;
  if (["en", "de", "fr", "es"].includes(query.lang)) filters.lang = query.lang;
  // Everyone but the owner unless asked: "all" is everyone.
  const plan = String(query.plan || "!owner");
  if (["free", "tester", "pro", "owner", "!owner", "none"].includes(plan)) filters.plan = plan;
  if (query.signed === "yes" || query.signed === "no") filters.signed = query.signed === "yes";
  return { from, to, filters };
}

/// GET /api/admin?op=analytics: every section's numbers for the range.
export async function analyticsRead(request, tests) {
  const { from, to, filters } = askedOf(request.query || {});
  const accounts = await accountsOf(tests);
  let read;
  try {
    read = await db("rpc/insights_read", { method: "POST", seconds: 25, body: { p_from: from, p_to: to, p_tests: tests,
      p_filters: filters, p_accounts: accounts } });
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return { ready: false, tests, from, to, filters };
    throw trouble;
  }
  return { ready: true, tests, from, to, filters, hashed: Boolean(secret()), accounts: accounts.length, ...read };
}

/// GET /api/plans?op=tally_daily: Vercel's cron. Every day that is over
/// and not rolled up (yesterday, or any the cron missed in 30 days), one
/// call a day, oldest first, each with each account's plan as it is now:
/// a backlog of flooded days rolls up over as many runs as it takes, never
/// all in one call that cannot finish (inreview L5). Then rows past 30 days
/// forgotten, and what deleted accounts left (insights_gone). Written down
/// as it ends (/admin#site).
export async function tallyDaily(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the daily rollup is the cron's" });
  if (!dbConfigured()) return response.status(503).json({ error: "no database here" });
  const started = new Date().toISOString();
  const began = Date.now();
  try {
    const plans = {};
    let listed = 0;
    for (const tests of [false, true]) {
      for (const one of await accountsOf(tests)) {
        plans[one.h] = one.plan;
        listed += 1;
      }
    }
    const days = await db("rpc/insights_unrolled", { method: "POST", seconds: 10,
      body: { p_from: iso(new Date(Date.now() - 30 * 86400000)) } });
    const rolled = [];
    for (const day of Array.isArray(days) ? days : []) {
      // A day at most 25 s, and none begun past 30 s of the run.
      if (Date.now() - began > 30000) break;
      rolled.push({ day, rows: await db("rpc/insights_rollup", { method: "POST", seconds: 25, body: { p_day: day, p_plans: plans } }) });
    }
    const out = { rolled, left: Math.max(0, (Array.isArray(days) ? days.length : 0) - rolled.length),
      ...(await db("rpc/insights_gone", { method: "POST", seconds: 15, body: { p_plans: plans, p_listed: listed } })) };
    await cronNoted(request, "tally_daily", started, "done", out);
    return response.status(200).json(out);
  } catch (trouble) {
    const words = String(trouble?.message || trouble).slice(0, 200);
    if (/: 404$/.test(words)) return response.status(200).json({ said: "analytics.sql is not applied here" });
    console.error(`tally: daily: ${words}`);
    await cronNoted(request, "tally_daily", started, "failed", { error: words });
    return response.status(500).json({ error: "the rollup stopped" });
  }
}
