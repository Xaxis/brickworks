// The console's Site section (/admin#site, docs/ADMIN.md, console2): which
// release is live and since when, the ones before it with their units, each
// cron's last runs, the sign-in canary's last answers, and the backend's
// health. api/admin.js asks these only after its owner check.
//
//   releases  site_releases (supabase/console2.sql), a row a release that
//             went live, written by the train as it ships
//             (tools/release/release_live.sh): no Vercel token here. Which
//             one this deployment is, the page says from /version.json.
//   crons     tools/deploy.sh's five, each with its last runs: cron_runs
//             (cron_runs_of) for the pick, the OMR, the sweep and the beta's
//             daily round; canary_runs for the canary.
//   health    Supabase's sign-in, database and storage, each asked once
//             (15 s at most between askings on an instance): 402 is the
//             organisation's spend cap or quota (exceed_cached_egress_quota,
//             2026-11-12), lifted at Supabase's Billing, never here.
//
// supabaseHealth also answers api/admin.js's gate when the sign-in service
// cannot be reached, so the owner is told why the console cannot open.

import { db, reach } from "./_db.js";

const DAY = 864e5;

/// The crons tools/deploy.sh sets on the project: its path, its schedule
/// (UTC), what it does, where its runs are kept, and how long it may go
/// between runs before the console says it is late.
export const CRONS = [
  { path: "/api/share/feature", when: "00:07 daily", what: "The gallery's front: this week's pick, today's featured model and set",
    job: "gallery_feature", every: DAY },
  { path: "/api/share/sweep", when: "04:17 daily", what: "Files no published model owns, and photos' files whose photo is gone",
    job: "share_sweep", every: DAY },
  { path: "/api/otp/canary", when: "04:47 daily", what: "A sign-in code sent and read back, sign-up still shut",
    job: "canary", every: DAY },
  { path: "/api/plans/beta-daily", when: "05:07 daily", what: "The beta's daily round, and feedback's sweep with it",
    job: "beta_daily", every: DAY },
  { path: "/api/share/omr", when: "05:37 Mondays", what: "What LDraw's Official Model Repository has that the library has not",
    job: "omr_watch", every: 7 * DAY },
];

const project = () => String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));

// ---------------------------------------------------------------------------
// The backend's health.

const PARTS = {
  auth: { name: "Sign-in (Supabase Auth)", path: "/auth/v1/health", key: "publishable" },
  rest: { name: "Database (Supabase REST)", path: "/rest/v1/canary_runs?select=id&limit=1", key: "secret" },
  storage: { name: "Files (Supabase Storage)", path: "/storage/v1/bucket", key: "secret" },
};
const BILLING = "Supabase's dashboard: your organization, Billing (the spend cap and the plan's quotas)";
let lastHealth = null;

/// One part asked: {ok, status, ms, restricted, said}.
async function probe(part) {
  const key = part.key === "secret" ? process.env.SUPABASE_SECRET_KEY : process.env.SUPABASE_PUBLISHABLE_KEY;
  const headers = { apikey: key || "" };
  if (part.key === "secret") headers.authorization = `Bearer ${key}`;
  const at = Date.now();
  try {
    const reply = await reach(`health GET ${part.path.split("?")[0]}`, 6, `${project()}${part.path}`, { headers });
    const text = reply.ok ? "" : await reply.text().catch(() => "");
    let said = "";
    try {
      said = String(JSON.parse(text)?.message || JSON.parse(text)?.msg || "");
    } catch {
      said = text;
    }
    said = said.replace(/\s+/g, " ").trim().slice(0, 300);
    return { ok: reply.ok, status: reply.status, ms: Date.now() - at,
      restricted: reply.status === 402 || /restricted|spend cap|quota/i.test(said), said: reply.ok ? null : said || null };
  } catch (trouble) {
    return { ok: false, status: null, ms: Date.now() - at, restricted: false,
      said: String(trouble?.message || trouble).slice(0, 200) };
  }
}

/// Supabase's three parts as this deployment reaches them, and in one line
/// what is wrong and where it is fixed: {ok, at, parts: {auth, rest,
/// storage}, restricted, fix}. Asked at most every 15 s an instance.
export async function supabaseHealth({ fresh = false } = {}) {
  if (!fresh && lastHealth && Date.now() - Date.parse(lastHealth.at) < 15000) return lastHealth;
  if (!project()) return { ok: false, at: new Date().toISOString(), parts: {}, restricted: false, fix: "SUPABASE_URL is not set here" };
  const names = Object.keys(PARTS);
  const asked = await Promise.all(names.map((name) => probe(PARTS[name])));
  const parts = Object.fromEntries(names.map((name, at) => [name, { name: PARTS[name].name, ...asked[at] }]));
  const restricted = asked.some((one) => one.restricted);
  const down = names.filter((name) => !parts[name].ok);
  const first = parts[down[0]];
  lastHealth = {
    ok: down.length === 0,
    at: new Date().toISOString(),
    parts,
    restricted,
    // What to do, said once for every part that is down.
    fix: !down.length ? null : restricted
      ? `Supabase is refusing this project (${first.status}${first.said ? `: ${first.said}` : ""}). Lift it at ${BILLING}.`
      : `Supabase's ${down.map((name) => PARTS[name].name).join(", ")} ${down.length === 1 ? "is" : "are"} not answering`
        + ` (${first.status ?? "no answer"}${first.said ? `: ${first.said}` : ""}): see status.supabase.com and the project's logs.`,
  };
  return lastHealth;
}

// ---------------------------------------------------------------------------
// Crons and the canary.

/// The last [most] runs of [job]: [] before it was ever kept, null when the
/// runs cannot be read.
async function runsOf(job, most) {
  if (job === "canary") {
    const rows = await db(`canary_runs?select=at,ok,host,checks,left_behind,mailed&order=at.desc&limit=${most}`);
    return rows.map((one) => ({ at: one.at, finished_at: one.at, outcome: one.ok ? "done" : "failed", holder: one.host || null,
      said: { failed: (one.checks || []).filter((check) => check && check.ok === false)
        .map((check) => `(${check.check}) ${check.what}`).slice(0, 6), left_behind: (one.left_behind || []).length,
      mailed: one.mailed || "" } }));
  }
  const rows = await db("rpc/cron_runs_of", { method: "POST", body: { job, most } });
  return (rows || []).map((one) => ({ at: one.started_at, finished_at: one.finished_at, outcome: one.outcome,
    holder: one.holder, said: one.said || {} }));
}

/// Each cron with its last runs and how it stands: ok, failed (its last
/// run), late (none in more than half again its period), running, never
/// (nothing kept of it yet).
export async function cronsRead(most = 5, now = Date.now()) {
  return Promise.all(CRONS.map(async (cron) => {
    let runs = null;
    try {
      runs = await runsOf(cron.job, most);
    } catch (trouble) {
      if (!notYet(trouble)) console.error(`console: cron ${cron.job}: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
    const last = runs?.[0] || null;
    const ended = runs?.find((one) => one.outcome && one.outcome !== "locked") || null;
    let state = "never";
    if (runs === null) state = "unknown";
    else if (last && !last.outcome) state = "running";
    else if (ended?.outcome === "failed") state = "failed";
    else if (last && now - Date.parse(last.at) > cron.every * 1.5) state = "late";
    else if (last) state = "ok";
    return { ...cron, state, runs };
  }));
}

// ---------------------------------------------------------------------------
// Releases.

/// The releases that went live, the latest first: null before console2.sql.
export async function releasesRead(most = 20) {
  try {
    return (await db("rpc/site_releases_list", { method: "POST", body: { p_limit: most } })) || [];
  } catch (trouble) {
    if (notYet(trouble)) return null;
    throw trouble;
  }
}

/// GET /api/admin?op=site: {releases, crons, health}.
export async function siteRead() {
  const [releases, crons, health] = await Promise.all([
    releasesRead(30).catch((trouble) => ({ error: String(trouble?.message || trouble).slice(0, 160) })),
    cronsRead(7),
    supabaseHealth({ fresh: true }),
  ]);
  return { releases: Array.isArray(releases) || releases === null ? releases : null,
    releases_error: releases?.error || null, crons, health };
}

/// What the Overview says of the site: the live release (the latest kept),
/// the crons that failed or are late, and the backend's health.
export async function siteSummary() {
  const [releases, crons, health] = await Promise.all([
    releasesRead(1).catch(() => null), cronsRead(1), supabaseHealth()]);
  return {
    live: releases?.[0] || null,
    kept: releases !== null,
    crons: crons.filter((one) => one.state === "failed" || one.state === "late")
      .map((one) => ({ path: one.path, job: one.job, state: one.state, at: one.runs?.[0]?.at || null })),
    health,
  };
}
