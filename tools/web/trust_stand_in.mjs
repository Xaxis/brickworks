// A stand-in for supabase/trust.sql's functions, in the local server's own
// process, for proving the API and the pages before the file is applied.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 --static=build/web --trust-stand-in
//
// The database is the live project's, and trust.sql is applied to it only
// at a release, by its owner. Until then age_of, answer_age, shown_publicly,
// claim_report_digest and finish_report_digest are not there, and the API
// behaves as it did before them (api/_trust.js). With this, the local
// server answers those five calls itself, in memory, as the SQL does, and
// sends every other request to the real database as before: the API, the
// app and the pages run as they will once the file is applied. What it
// cannot stand in for is the SQL itself, which tools/trust_trial.sql
// proves in a rolled-back transaction, triggers and all.
//
// Only for test accounts' reports (api/_auth.js isTestAccount): a report of
// anything else is told "none", so nothing real is claimed or recorded
// here. Its records are read at /__stand_in/digest?id=N, and an age is set
// at /__stand_in/age (POST {account, at_least_13}), as tools/web/session.mjs
// answers for a test account.

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const ages = new Map();
const digests = [];
const waiting = new Map();
const tests = new Map();
let realFetch = null;

const reply = (status, value) => new Response(value === undefined ? "" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });

async function real(path, init = {}) {
  const answer = await realFetch(`${REST}${path}`, { ...init,
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json",
      ...(init.headers || {}) } });
  if (!answer.ok) throw new Error(`stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}

async function isTest(account) {
  if (!account) return false;
  if (!tests.has(account)) {
    const answer = await realFetch(`${SUPABASE}/auth/v1/admin/users/${account}`, {
      headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
    const user = answer.ok ? await answer.json() : {};
    tests.set(account, /@resend\.dev$/i.test(String(user.email || "")));
  }
  return tests.get(account);
}

function ageOf(account) {
  const kept = ages.get(account);
  const overThirteen = kept ? kept.over_13 : null;
  return { over_13: overThirteen, asked_at: kept ? kept.at : null,
    ask: overThirteen === null || (overThirteen === false && Date.parse(kept.at) < Date.now() - 365 * 864e5) };
}

async function answerAge({ account, at_least_13: atLeast13 }) {
  if (typeof atLeast13 !== "boolean") return reply(400, { message: "say whether the account is 13 or over" });
  if (!ageOf(account).ask) return reply(200, ageOf(account));
  ages.set(account, { over_13: atLeast13, at: new Date().toISOString() });
  if (!atLeast13) {
    await real(`shared_models?owner=eq.${account}&listed=is.true`, { method: "PATCH",
      body: JSON.stringify({ listed: false, listed_at: null }) });
    await real(`model_collections?owner=eq.${account}&public=is.true`, { method: "PATCH",
      body: JSON.stringify({ public: false }) });
  }
  return reply(200, ageOf(account));
}

/// The report's stream, as report_stream says it. Which comment it is
/// about, when comments.sql is held beside this (comments_stand_in.mjs),
/// and that comment's words.
async function streamOf(report) {
  const columns = "id,at,model,handle,collection,reporter,reason,note,resolved_at";
  const rows = await real(`reports?id=eq.${report}&select=${columns},comment`)
    .catch(() => real(`reports?id=eq.${report}&select=${columns}`));
  const row = rows[0];
  if (!row) return null;
  if (row.comment) {
    const about = await real("rpc/admin_comments", { method: "POST", body: JSON.stringify({ wanted: [row.comment] }) })
      .catch(() => []);
    row.said = String(about?.[0]?.body || "").slice(0, 240) || null;
  }
  let owner = null;
  let name = null;
  if (row.model) {
    const found = (await real(`shared_models?id=eq.${row.model}&select=owner,name`))[0];
    owner = found?.owner ?? null;
    name = found?.name ?? null;
  } else if (row.collection) {
    const found = (await real(`model_collections?id=eq.${row.collection}&select=owner,name`))[0];
    owner = found?.owner ?? null;
    name = found?.name ?? null;
  } else if (row.handle) {
    const found = (await real(`people?handle=eq.${row.handle}&select=account,name`))[0];
    if (!found) return null;
    owner = found.account;
    name = found.name;
  }
  let stream = "owner";
  if (owner && await isTest(owner)) stream = `test:${owner}`;
  else if (row.reporter && await isTest(row.reporter)) stream = `test:${row.reporter}`;
  return { stream, row: { ...row, name } };
}

async function claim({ wanted = "owner", report = null }) {
  let stream = wanted;
  if (report !== null && report !== undefined) {
    const found = await streamOf(report);
    if (!found) return reply(200, null);
    stream = found.stream;
    if (!waiting.has(stream)) waiting.set(stream, []);
    waiting.get(stream).push(found.row);
  }
  // Nothing real is ever claimed here.
  if (!String(stream).startsWith("test:")) return reply(200, null);
  const hour = new Date();
  hour.setUTCMinutes(0, 0, 0);
  if (digests.some((d) => d.stream === stream && d.state !== "failed" && Date.parse(d.at) >= hour.getTime())) {
    return reply(200, null);
  }
  const ready = (waiting.get(stream) || []).filter((row) => !row.digest && !row.resolved_at);
  if (ready.length === 0) return reply(200, null);
  const taken = ready.slice(0, 100);
  const digest = { id: digests.length + 1, stream, at: new Date().toISOString(), state: "sending", reports: taken.length };
  digests.push(digest);
  for (const row of taken) row.digest = digest.id;
  return reply(200, { digest: digest.id, stream, more: ready.length - taken.length,
    reports: taken.map(({ id, at, reason, note, model, handle, collection, name, comment = null, said = null }) =>
      ({ id, at, reason, note, model, handle, collection, name, comment, said })) });
}

function finish({ one, outcome, said_subject: subject, said_body: body, said_html: html }) {
  const digest = digests.find((d) => d.id === one && d.state === "sending");
  if (!digest || !["sent", "failed", "dry"].includes(outcome)) return reply(200, false);
  Object.assign(digest, { state: outcome }, outcome === "dry" ? { subject, body, html } : {});
  return reply(200, true);
}

async function shown({ account }) {
  if (ageOf(account).over_13 === false) return reply(200, false);
  return reply(200, (await real("rpc/is_barred", { method: "POST", body: JSON.stringify({ account }) })) !== true);
}

const STOOD_IN = {
  age_of: async ({ account }) => reply(200, ageOf(account)),
  answer_age: answerAge,
  shown_publicly: shown,
  claim_report_digest: claim,
  finish_report_digest: async (body) => finish(body),
};

/// Put the stand-in in front of the database, for this process.
export function standIn() {
  if (realFetch) return;
  realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const where = String(url);
    if (where.startsWith(`${REST}rpc/`)) {
      const name = where.slice(`${REST}rpc/`.length).split("?")[0];
      if (STOOD_IN[name]) {
        let body = {};
        try {
          body = init.body ? JSON.parse(init.body) : {};
        } catch {
          body = {};
        }
        return STOOD_IN[name](body);
      }
    }
    return realFetch(url, init);
  };
  console.log("trust.sql stood in for: age_of, answer_age, shown_publicly, claim_report_digest, finish_report_digest");
}

/// The stand-in's own two addresses, or null for any other.
export async function standInRoute(url, method, body) {
  if (url.pathname === "/__stand_in/digest" && method === "GET") {
    const digest = digests.find((d) => d.id === Number(url.searchParams.get("id")));
    return digest ? { status: 200, value: digest } : { status: 404, value: { error: "no such digest" } };
  }
  if (url.pathname === "/__stand_in/age" && method === "POST") {
    const account = String(body?.account || "");
    if (!(await isTest(account))) return { status: 403, value: { error: "a test account's only" } };
    const answered = await (await answerAge({ account, at_least_13: body?.at_least_13 })).json();
    return { status: 200, value: answered };
  }
  return null;
}
