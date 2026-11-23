// The loop for a range, as JSON, through the console's own op (GET
// /api/admin?op=loop, api/_loop.js; docs/ANALYTICS.md "The loop"), so a
// unit's report can quote its step before and after a deploy.
//
//   node tools/loop_read.mjs [--days=30 | --from=YYYY-MM-DD --to=YYYY-MM-DD] [--plan=all] [--tests]
//                            [--port=11390] [--env=.env] [--out=FILE]
//
// Read as docs/SOCIAL.md's siteplan8 read the live numbers: api/admin.js run
// here by tools/web/relay_server.mjs against the live database, its
// MASTER_EMAIL the checks' shared test account (tools/web/session.mjs
// TEST_EMAIL), whose session is minted, so the owner is never signed in.
// The relay is given only SUPABASE_URL, SUPABASE_SECRET_KEY and
// SUPABASE_PUBLISHABLE_KEY from the env file (never its other keys), and
// VIEW_SECRET only if this shell has one. It reads; nothing is written but
// the session's sign-in.
//
// What a local read cannot know, it says (in "said"): without VIEW_SECRET
// (kept only in Vercel) no account's hash is joined to its id, so Heard
// back, what the social tables keep and Claude's days read 0; and with the
// relay's MASTER_EMAIL the checks' account, the owner's own days are not
// left out. Before supabase/loop_funnel.sql is applied it answers
// {ready: false}.

import { spawn } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || `--${name}=${fallback}`).slice(name.length + 3);
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const iso = (ms) => new Date(ms).toISOString().slice(0, 10);

const port = Number(arg("port", "11390"));
const days = Number(arg("days", "30"));
const to = DAY.test(arg("to")) ? arg("to") : iso(Date.now());
const from = DAY.test(arg("from")) ? arg("from") : iso(Date.parse(`${to}T00:00:00Z`) - (Math.max(1, days) - 1) * 86400000);
const plan = arg("plan");
const tests = process.argv.includes("--tests");
const envFile = arg("env", join(ROOT, ".env"));
const outFile = arg("out");

// Only the three keys the read needs, never the rest of the file.
const KEEP = ["SUPABASE_URL", "SUPABASE_SECRET_KEY", "SUPABASE_PUBLISHABLE_KEY"];
const given = {};
for (const line of readFileSync(envFile, "utf8").split("\n")) {
  const found = /^\s*([A-Z_]+)\s*=\s*(.*)\s*$/.exec(line);
  if (found && KEEP.includes(found[1])) given[found[1]] = found[2].replace(/^(['"])(.*)\1$/, "$2");
}
for (const key of KEEP) {
  if (!given[key]) {
    console.error(`loop_read: ${envFile} has no ${key}`);
    process.exit(2);
  }
  process.env[key] = given[key];
}
const { TEST_EMAIL, mintSession } = await import("./web/session.mjs");

const relayEnv = { PATH: process.env.PATH, HOME: process.env.HOME, ...given, MASTER_EMAIL: TEST_EMAIL };
if (process.env.VIEW_SECRET) relayEnv.VIEW_SECRET = process.env.VIEW_SECRET;
const relay = spawn(process.execPath, [join(ROOT, "tools/web/relay_server.mjs"), String(port)], { cwd: ROOT, env: relayEnv,
  stdio: ["ignore", "pipe", "pipe"], detached: false });
let relayLog = "";
relay.stdout.on("data", (chunk) => { relayLog += chunk; });
relay.stderr.on("data", (chunk) => { relayLog += chunk; });
const base = `http://127.0.0.1:${port}`;

let code = 0;
try {
  // The relay up: the console answers a signed-out ask with 401.
  for (let tries = 0; ; tries += 1) {
    try {
      if ((await fetch(`${base}/api/admin?op=loop`)).status === 401) break;
    } catch {
      // Not listening yet.
    }
    if (tries > 150 || relay.exitCode !== null) throw new Error(`the relay did not come up on ${port}: ${relayLog.slice(-400)}`);
    await new Promise((done) => setTimeout(done, 200));
  }
  const session = await mintSession(TEST_EMAIL);
  const query = new URLSearchParams({ op: "loop", from, to });
  if (plan) query.set("plan", plan);
  if (tests) query.set("tests", "1");
  const began = Date.now();
  const reply = await fetch(`${base}/api/admin?${query}`, { headers: { authorization: `Bearer ${session.access_token}` } });
  const ms = Date.now() - began;
  const body = await reply.json().catch(() => ({}));
  if (!reply.ok) throw new Error(`?op=loop answered ${reply.status}: ${JSON.stringify(body).slice(0, 300)}`);
  const said = [];
  if (body.ready === false) said.push("supabase/loop_funnel.sql is not applied to this database: there is no loop to read yet");
  if (body.hashed === false) {
    said.push("no VIEW_SECRET here: no account's hash is joined to its id, so heard_back, the kept shares and Claude's days read 0");
  }
  said.push("the relay's MASTER_EMAIL is the checks' account: the owner's own days are not left out");
  const out = { read: { from, to, plan: plan || "!owner", tests, ms, at: new Date().toISOString() }, said, ...body };
  const text = `${JSON.stringify(out, null, 1)}\n`;
  if (outFile) writeFileSync(outFile, text);
  process.stdout.write(text);
} catch (trouble) {
  console.error(`loop_read: ${trouble?.message || trouble}`);
  code = 1;
} finally {
  relay.kill("SIGTERM");
}
process.exit(code);
