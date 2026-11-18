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
import { AuthError } from "./_auth.js";
import { cronNoted, isCron } from "./_cron.js";
import { db, dbConfigured } from "./_db.js";

// Where the law asks for a visitor's yes before counting (GDPR and the
// ePrivacy rules, the UK's, Switzerland's): Vercel's country header.
export const ASK_FIRST = new Set(["AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT",
  "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "IS", "LI", "NO", "GB", "CH"]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const VISIT = /^[a-z0-9]{16}$/;
const NAME = /^[a-z0-9_:/#.-]{1,60}$/;
const MAX_BODY = 32768;

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

/// Whether rows from here are the checks' own: anything but production.
function testHere(asked) {
  return asked === true || process.env.VERCEL_ENV !== "production";
}

function bodyOf(request) {
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

/// A beacon's events as rows may hold them, at most 80: anything else let go.
export function eventsOf(given) {
  if (!Array.isArray(given)) return [];
  const out = [];
  for (const one of given.slice(0, 80)) {
    if (!Array.isArray(one)) continue;
    const [surface, kind, name, n, ms, ok] = one;
    if (!["site", "studio"].includes(surface) || typeof kind !== "string" || typeof name !== "string" || !NAME.test(name)) continue;
    out.push([surface, kind, name, Number.isFinite(n) ? Math.round(n) : 1, Number.isFinite(ms) ? Math.round(ms * 10) / 10 : null,
      typeof ok === "boolean" ? ok : null]);
  }
  return out;
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
  const about = b.about && typeof b.about === "object" && !Array.isArray(b.about) ? b.about : {};
  const seen = Array.isArray(b.seen) ? b.seen.filter((one) => typeof one === "string" && NAME.test(one)).slice(0, 400) : [];
  const seconds = Number.isFinite(b.seconds) ? Math.max(0, Math.min(3600, Math.round(b.seconds))) : 0;
  try {
    await db("rpc/insights_take", { method: "POST", seconds: 8, body: {
      p_visit: b.v, p_about: about, p_events: eventsOf(b.e), p_seen: seen, p_account: accountHash(b.who),
      p_seconds: seconds, p_test: testHere(b.check === true),
    } });
  } catch (trouble) {
    // Before analytics.sql there is nowhere to keep it; anything else is said.
    if (!/: 404$/.test(String(trouble?.message || ""))) {
      console.error(`tally: not kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
  return response.status(204).end();
}

/// A tool call the connector relayed (api/mcp.js): [owner]'s, named
/// [tool], [ok] or not (null: not told), [ms] long. Never throws: the call
/// is not the count's.
export async function tallyCall(owner, tool, ok, ms) {
  const name = String(tool || "").toLowerCase();
  if (!NAME.test(name) || !dbConfigured()) return;
  try {
    await db("rpc/insights_call", { method: "POST", seconds: 5, body: { p_account: accountHash(owner), p_tool: name,
      p_ok: typeof ok === "boolean" ? ok : null, p_ms: Number.isFinite(ms) ? Math.max(0, Math.round(ms)) : null, p_test: testHere(false) } });
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) {
      console.error(`tally: a call not counted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
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
/// and not rolled up (yesterday, or any the cron missed in 30 days) rolled
/// up with each account's plan as it is now, and rows past 30 days
/// forgotten. Written down as it ends (/admin#site).
export async function tallyDaily(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the daily rollup is the cron's" });
  if (!dbConfigured()) return response.status(503).json({ error: "no database here" });
  const started = new Date().toISOString();
  try {
    const plans = {};
    for (const tests of [false, true]) for (const one of await accountsOf(tests)) plans[one.h] = one.plan;
    const out = await db("rpc/insights_daily", { method: "POST", seconds: 50, body: { p_plans: plans } });
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
