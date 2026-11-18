// The owner's console, part C (console3, 2026-11-13; docs/ADMIN.md): its
// Data section (/admin#data), and Run now beside each cron in Site.
//
//   dataRead   the catalogue as this deployment was made with it (written
//              beside this function at deploy, tools/web/data_facts.mjs:
//              when Rebrickable's tables were last fetched, how many sets,
//              how many with a picture of their own in our storage), the
//              library's index as the store has it now (a HEAD: when it was
//              last written, never its body, which costs egress), what the
//              weekly look at LDraw's OMR found (library_arrivals and its
//              last runs), and what the project uses: the database's size,
//              its biggest tables, storage bucket by bucket
//              (supabase/console3.sql admin_usage). Supabase's egress is not
//              read: its usage is only in its Management API, whose tokens
//              reach every project of the organization with every right,
//              too much to keep in a deployment; the section says where it
//              is read (Supabase's dashboard) instead.
//   runCron    POST ?op=run_cron&job=J: one of the crons run now, as Vercel
//              runs it (the address it was asked at, the site's own only;
//              CRON_SECRET, on the server; the key never reaches the page),
//              and what it said. The
//              safe ones only: the front's choice and the OMR's look (each
//              under its own lock, a second run the same day changes
//              nothing), the sweep (held at a quarter, as daily) and the
//              canary (a code to Resend's test inbox). Never the beta's
//              daily round, which mails testers. One at a time a cron: a
//              second asked while it runs is refused (409).

import { existsSync, readFileSync } from "node:fs";
import { db } from "./_db.js";
import { storeRoot } from "./_omr_credit.js";

const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));

/// The address this request came to, where a cron is run: only the site's
/// own (brickworks.diy, this project's previews, this deployment, a test's
/// loopback), so CRON_SECRET never goes anywhere else. PUBLIC_ORIGIN is not
/// read: on a preview it would run live's cron.
export function ownOrigin(request) {
  const headers = request?.headers || {};
  const host = String(headers["x-forwarded-host"] || headers.host || "").split(",")[0].trim().toLowerCase();
  const deployment = String(process.env.VERCEL_URL || "").toLowerCase();
  if (/^(?:127\.0\.0\.1|localhost)(?::\d{1,5})?$/.test(host)) return `http://${host}`;
  if (host === "brickworks.diy" || host === "www.brickworks.diy" || (deployment && host === deployment)
    || /^brickworks-[a-z0-9-]{1,80}-xaxis-projects\.vercel\.app$/.test(host)) return `https://${host}`;
  return null;
}

/// Each cron Run now may run: its path, and why it is safe.
export const RUNNABLE = {
  gallery_feature: { path: "/api/share/feature", said: "The front's choice: one a day, under its lock; again the same day changes nothing" },
  omr_watch: { path: "/api/share/omr", said: "The look at LDraw's OMR: a few pages, a second apart, under its lock" },
  share_sweep: { path: "/api/share/sweep", said: "Files no published model owns: never more than a quarter unasked" },
  canary: { path: "/api/otp/canary", said: "A sign-in code sent to Resend's test inbox and read back" },
  social_due: { path: "/api/plans/social-due", said: "Sends only what you pressed Schedule on whose time came, then reads "
    + "what came in" },
  owner_notify: { path: "/api/plans/owner-notify", said: "Mails you only what waits, as Notifications says: its quiet hours, "
    + "its cap and its digest's time" },
};
/// What is never run from here, and why.
export const NOT_RUNNABLE = {
  beta_daily: "The beta's daily round mails testers: it runs only at its time",
};

/// The table's own entry named [job], never one Object's prototype lends it
/// (?job=constructor, __proto__, hasOwnProperty): null.
const entry = (table, job) => (Object.hasOwn(table, job) ? table[job] : null);

/// Site's answer with each cron's Run now: why it is safe, or why it is not.
export function withRunNow(site) {
  return { ...site, crons: (site?.crons || []).map((cron) => ({ ...cron,
    run_now: entry(RUNNABLE, cron.job)?.said ?? null, run_not: entry(NOT_RUNNABLE, cron.job) })) };
}

/// The facts written beside this function at deploy, or null.
export function dataFacts() {
  for (const where of ["./_data_facts.json", "../build/data_facts.json"]) {
    const url = new URL(where, import.meta.url);
    try {
      if (existsSync(url)) return JSON.parse(readFileSync(url, "utf8"));
    } catch {
      return null;
    }
  }
  return null;
}

/// The library's index in the store: {at, bytes} from a HEAD, or null.
async function indexHead() {
  const root = storeRoot();
  if (!root) return null;
  const head = await fetch(`${root}library/index.json`, { method: "HEAD", signal: AbortSignal.timeout(10000) }).catch(() => null);
  if (!head || !head.ok) return { status: head ? head.status : 0 };
  const at = Date.parse(head.headers.get("last-modified") || "");
  const bytes = Number(head.headers.get("content-length"));
  return { at: Number.isFinite(at) ? new Date(at).toISOString() : null, bytes: Number.isFinite(bytes) ? bytes : null };
}

/// GET /api/admin?op=data.
export async function dataRead() {
  const [index, arrivals, omr, usage] = await Promise.all([
    indexHead(),
    db("rpc/library_arrivals_in", { method: "POST", body: { state: null } }).catch((trouble) => (notYet(trouble) ? null : Promise.reject(trouble))),
    db("rpc/cron_runs_of", { method: "POST", body: { job: "omr_watch", most: 5 } }).catch(() => null),
    db("rpc/admin_usage", { method: "POST", body: {} }).catch((trouble) => (notYet(trouble) ? null : Promise.reject(trouble))),
  ]);
  const found = (arrivals || []).map((one) => ({ page: one.page, set_number: one.set_number ?? null, name: one.name ?? null,
    author: one.author ?? null, state: one.state, why: one.why ?? null, found_at: one.found_at ?? null, changed_at: one.changed_at ?? null }));
  const states = {};
  for (const one of found) states[one.state] = (states[one.state] || 0) + 1;
  return {
    facts: dataFacts(),
    index,
    omr: { arrivals: arrivals === null ? null : found.slice(-50).reverse(), states,
      runs: (omr || []).map((run) => ({ at: run.started_at, finished_at: run.finished_at, outcome: run.outcome, said: run.said ?? null })) },
    usage,
    egress: { read: false,
      why: "Supabase tells egress only through its Management API, whose access tokens reach every project of the "
        + "organization with every right: too much to keep in a deployment. Read it in Supabase's dashboard: the "
        + "organization's Usage.",
      href: "https://supabase.com/dashboard/org/_/usage" },
  };
}

/// POST /api/admin?op=run_cron&job=J.
export async function runCron(request, response) {
  const job = String(request.query?.job || "");
  const not = entry(NOT_RUNNABLE, job);
  if (not) return response.status(409).json({ error: `${not}.` });
  const cron = entry(RUNNABLE, job);
  if (!cron) return response.status(400).json({ error: `name a cron: ?job=${Object.keys(RUNNABLE).join(", ")}` });
  const secret = String(process.env.CRON_SECRET || "");
  if (!secret) return response.status(503).json({ error: "No CRON_SECRET here: the crons cannot be run from this deployment." });
  const origin = ownOrigin(request);
  if (!origin) return response.status(400).json({ error: "Run now runs only on the site's own address." });
  // One Run now of a cron at a time: a second asked while the first runs
  // (two tabs, two presses) is refused, never run beside it. The sweep and
  // the canary keep no lock of their own. The hold is the crons' own
  // (gallery_crons.sql cron_begin) under the console's name for the job, so
  // the cron's own lock is left to the cron; it lapses after five minutes,
  // longer than the wait below, if this function is cut off.
  let hold = null;
  try {
    hold = await db("rpc/cron_begin", { method: "POST", body: { job: `run_now_${job}`, holder: "console", seconds: 300 } });
  } catch (trouble) {
    if (!notYet(trouble)) throw trouble;
  }
  if (hold?.locked) {
    return response.status(409).json({ error: `${cron.path} is running already, from Run now: one at a time. Its run shows here when it ends.`,
      job, ran: false });
  }
  const bypass = process.env.VERCEL_AUTOMATION_BYPASS_SECRET;
  const started = Date.now();
  let outcome = "failed";
  let note = {};
  try {
    let answer;
    try {
      answer = await fetch(`${origin}${cron.path}`, { headers: { authorization: `Bearer ${secret}`, "user-agent": "brickworks-console",
        ...(bypass ? { "x-vercel-protection-bypass": bypass } : {}) }, signal: AbortSignal.timeout(240000) });
    } catch (trouble) {
      note = { error: String(trouble?.message || trouble).slice(0, 160) };
      return response.status(502).json({ error: `It did not answer: ${note.error}` });
    }
    const said = await answer.json().catch(() => null);
    const seconds = Math.round((Date.now() - started) / 100) / 10;
    if (!answer.ok) {
      note = { status: answer.status };
      return response.status(502).json({ error: `It answered ${answer.status}${said?.error ? `: ${String(said.error).slice(0, 200)}` : ""}.`,
        job, ran: false, seconds });
    }
    // What it said, short: the run's own record is in cron_runs (Site).
    const brief = said && typeof said === "object" ? JSON.stringify(said).slice(0, 600) : null;
    const ended = said?.outcome ?? said?.state ?? (said?.ok === false ? "failed" : "done");
    outcome = ended === "failed" ? "failed" : "done";
    note = { seconds, outcome: String(ended).slice(0, 40) };
    return response.status(200).json({ job, ran: true, seconds, said: brief, outcome: ended });
  } finally {
    if (hold?.run) {
      await db("rpc/cron_end", { method: "POST", body: { run: hold.run, holder: "console", outcome, said: note } }).catch(() => null);
    }
  }
}
