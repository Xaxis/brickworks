// Signing in from a test, without an inbox.
//
// Everyone who uses Brickworks signs in with a code sent to their email
// (2026-10-11), and a browser test has no inbox. A flow about that sign-in
// itself mints the code the way api/otp.js does — Supabase's admin
// generate_link, which returns the code and sends nothing — and types it
// into the app like a person (account_flow.mjs, people_flow.mjs,
// first_steps_flow.mjs, oauth_flow.mjs). Every other flow only needs a
// signed-in account, and gets one here: a session handed to the app as a
// returning visitor's browser would have kept it (browser.mjs).
//
// That session is signed in by password, not by redeeming a code
// (2026-10-23). Redeeming is Supabase's verify, limited for each machine
// (by its IP address) to 30 in five minutes after a burst of 30, and every
// page of every flow redeemed one: m156's preview held on eight checks, each "the code would
// not redeem: 429", once the day's batteries, unit previews and relays had
// spent it. Now a test account is made by the admin API, which has no
// limit, with a password worked out from the secret key, and signed in by
// the password grant, which counts against the token limit renewals use
// (150 in five minutes, after a burst of 30). Passwords go only on Resend
// test addresses, which no one can receive mail at; any other address,
// the owner's above all, is signed in by its code as before.
//
// Only the signing in is a shortcut, and it needs SUPABASE_SECRET_KEY, so
// it runs only where .env is. Nothing in production is weakened for it.
//
//   set -a; . ./.env; set +a
//
// The tests sign in as one test account, at a Resend test address that
// accepts mail and delivers it nowhere, so a code that is sent costs no
// one an inbox and no sender a bounce. BW_TEST_EMAIL picks another.

import { createHash, createHmac, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import { hostname } from "node:os";

// The shared test account, which every flow's pages are signed in as.
const SHARED_EMAIL = "delivered+brickworks-tests@resend.dev";
export const TEST_EMAIL = process.env.BW_TEST_EMAIL || SHARED_EMAIL;
// Where the app keeps its session in the browser (src/account/account.gd).
export const STORAGE_KEY = "brickworks.session";

function project() {
  const url = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const key = process.env.SUPABASE_PUBLISHABLE_KEY || "";
  return url && secret && key ? { url, secret, key } : null;
}

/// Whether this machine can sign a test in at all.
export function canSignIn() {
  return project() !== null;
}

/// A sign-in code for [email], made the way api/otp.js makes one and sent
/// nowhere. Making it replaces any code sent before.
export async function mintCode(email = TEST_EMAIL) {
  const p = project();
  if (!p) throw new Error("no SUPABASE_URL / SUPABASE_SECRET_KEY / SUPABASE_PUBLISHABLE_KEY — source .env");
  const headers = { apikey: p.secret, authorization: `Bearer ${p.secret}`, "content-type": "application/json" };
  // The account made first, by the admin API (422 when it is there
  // already), as api/otp.js makes it.
  await fetch(`${p.url}/auth/v1/admin/users`, { method: "POST", headers, body: JSON.stringify({ email, email_confirm: true }) });
  const reply = await fetch(`${p.url}/auth/v1/admin/generate_link`, {
    method: "POST", headers, body: JSON.stringify({ type: "magiclink", email }),
  });
  const body = await reply.json().catch(() => ({}));
  const code = body.email_otp || body.properties?.email_otp;
  if (!code) throw new Error(`no code minted: ${reply.status}`);
  return code;
}

/// The age question (supabase/trust.sql) answered 13 or over for a test's
/// account, so a flow that lists or makes a profile is not asked first:
/// in the database once trust.sql is applied there, and in the local
/// server's stand-in for it when BW_STAND_IN names one
/// (tools/web/trust_stand_in.mjs). Never for the owner's own account,
/// whose answer is theirs to give. Quiet when neither is there.
export async function answerAge(userId, email, atLeast13 = true) {
  const p = project();
  if (!p || !userId) return;
  const master = String(process.env.MASTER_EMAIL || "").trim().toLowerCase();
  if (master && String(email || "").toLowerCase() === master) return;
  await fetch(`${p.url}/rest/v1/rpc/answer_age`, {
    method: "POST",
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}`, "content-type": "application/json" },
    body: JSON.stringify({ account: userId, at_least_13: atLeast13 }),
  }).catch(() => null);
  const standIn = String(process.env.BW_STAND_IN || "").replace(/\/+$/, "");
  if (standIn) {
    await fetch(`${standIn}/__stand_in/age`, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ account: userId, at_least_13: atLeast13 }),
    }).catch(() => null);
  }
}

/// A whole session for [email], as the app keeps one: signed in by
/// password at a Resend test address, by its code anywhere else. Its age
/// is answered 13 or over (answerAge), unless { age: false } says leave it
/// to be asked, as the age flow does.
export async function mintSession(email = TEST_EMAIL, { age = true } = {}) {
  const p = project();
  if (!p) throw new Error("no SUPABASE_URL / SUPABASE_SECRET_KEY / SUPABASE_PUBLISHABLE_KEY — source .env");
  const body = (isTestAddress(email) && await passwordSession(p, email)) || await codeSession(p, email);
  if (age) await answerAge(body.user?.id, body.user?.email || email);
  return {
    access_token: body.access_token,
    kept: {
      refresh_token: body.refresh_token,
      email: body.user?.email || email,
      user_id: body.user?.id || "",
      url: p.url,
      key: p.key,
    },
  };
}

const isTestAddress = (email) => /@resend\.dev$/i.test(String(email || "").trim());

/// The password a test account signs in with: worked out from the secret
/// key, so every run that can mint knows it and none keeps it anywhere.
const passwordOf = (p, email) =>
  `${createHmac("sha256", p.secret).update(`brickworks test session ${email.toLowerCase()}`).digest("base64url")}-Aa1`;

/// A session by the password grant, the account made first if it is new;
/// or null for an account made some other way (by a code, before
/// 2026-10-23, or by the sign-in dialog earlier in the same flow), which
/// is then signed in by its code. A password is never put on such an
/// account: setting one signs out every session it has, which would sign
/// out the flow's own page. The shared test account alone is given its
/// password, once, the first time it has none.
async function passwordSession(p, email) {
  const password = passwordOf(p, email);
  const admin = { apikey: p.secret, authorization: `Bearer ${p.secret}`, "content-type": "application/json" };
  // 422 when the address has an account already.
  const made = await fetch(`${p.url}/auth/v1/admin/users`, {
    method: "POST", headers: admin, body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!made.ok && made.status !== 422) return null;
  const grant = () => patiently("the password grant", () => fetch(`${p.url}/auth/v1/token?grant_type=password`, {
    method: "POST", headers: { apikey: p.key, "content-type": "application/json" }, body: JSON.stringify({ email, password }),
  }));
  let reply = await grant();
  if (reply.status === 400 && !made.ok && email.toLowerCase() === SHARED_EMAIL) {
    const shared = (await users(p).catch(() => [])).find((u) => (u.email || "").toLowerCase() === SHARED_EMAIL);
    if (shared) {
      await fetch(`${p.url}/auth/v1/admin/users/${shared.id}`, { method: "PUT", headers: admin, body: JSON.stringify({ password }) });
      reply = await grant();
    }
  }
  const body = await reply.json().catch(() => ({}));
  if (body.refresh_token) return body;
  if (reply.status !== 400) console.error(`  (the password grant answered ${reply.status}: signing ${email} in by a code instead)`);
  return null;
}

/// A session by a code minted and redeemed, as the app redeems one.
///
/// Flows run two at a time sign in the one test account, and minting a
/// code replaces the last: one flow's code was refused (403) because the
/// other minted between its mint and its redeem, and three checks failed
/// behind the sign-in screen (2026-10-13). So a refused code is minted
/// again, after a wait that differs between the two.
async function codeSession(p, email) {
  let reply = null;
  let body = {};
  for (let attempt = 1; attempt <= 5; attempt++) {
    const code = await mintCode(email);
    reply = await patiently("redeeming a code", () => fetch(`${p.url}/auth/v1/verify`, {
      method: "POST",
      headers: { apikey: p.key, "content-type": "application/json" },
      body: JSON.stringify({ type: "email", email, token: code }),
    }));
    body = await reply.json();
    if (body.refresh_token || reply.status !== 403) break;
    await new Promise((done) => setTimeout(done, 400 + Math.random() * 1600 * attempt));
  }
  if (!body.refresh_token) throw new Error(`the code would not redeem: ${reply.status}`);
  return body;
}

/// [ask]'s reply, asked again while the sign-in service answers 429, each
/// wait longer than the last, for about two minutes in all, and saying so:
/// a battery that has spent a limit waits for it rather than failing every
/// check behind it.
async function patiently(what, ask) {
  let waited = 0;
  for (let attempt = 1; ; attempt++) {
    const reply = await ask();
    if (reply.status !== 429 || waited >= 120) return reply;
    const wait = Math.min(30, 2 ** attempt) * (0.75 + Math.random() / 2);
    console.error(`  (the sign-in service is rate limiting ${what} (429): waiting ${Math.round(wait)} s, then asking again)`);
    await new Promise((done) => setTimeout(done, wait * 1000));
    waited += wait;
  }
}

/// Put a session where the app keeps one, in every page this context
/// opens — once: a reload must find what the app itself kept since, which
/// is a renewed token, not this one again.
export async function signInContext(context, email = TEST_EMAIL) {
  const { kept } = await mintSession(email);
  await context.addInitScript(([name, value]) => {
    try {
      if (!localStorage.getItem(name)) localStorage.setItem(name, value);
    } catch {}
  }, [STORAGE_KEY, JSON.stringify(kept)]);
  return kept;
}

/// An account and everything of it gone: for the throwaway ones a test
/// makes. Never the shared test account.
export async function deleteAccount(email) {
  const p = project();
  if (!p || !email || email === TEST_EMAIL) return false;
  const user = (await users(p).catch(() => [])).find((u) => (u.email || "").toLowerCase() === email.toLowerCase());
  return user ? removed(p, user) : false;
}

async function removed(p, user) {
  const gone = await fetch(`${p.url}/auth/v1/admin/users/${user.id}`, {
    method: "DELETE",
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` },
  }).catch(() => null);
  return Boolean(gone?.ok);
}

/// Every account the project has, the admin list a page of 1,000 at a time.
async function users(p) {
  const all = [];
  for (let page = 1; ; page++) {
    const reply = await fetch(`${p.url}/auth/v1/admin/users?page=${page}&per_page=1000`, {
      headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` },
    });
    if (!reply.ok) throw new Error(`the admin list of accounts answered ${reply.status}`);
    const listed = (await reply.json()).users || [];
    all.push(...listed);
    if (listed.length < 1000) return all;
  }
}

// An account of the run's own.
//
// Brickworks limits what one account does in a short time (api/share.js
// may_publish: 20 publishes an hour, 60 a day), and the shared test account
// is one account. The four dialogs checks publish, and every unit's preview
// and every train ran them, all as that account: from 2026-11-08 19:47Z
// each was refused Share ("you have published a lot in a short time"). A
// flow that spends such a limit signs in as an account of its own instead,
// launch({ ownAccount: true }) (browser.mjs): at a Resend test address,
// made and signed in by its password as the shared one is
// (passwordSession), and deleted with everything of it when the run closes
// its browser or is stopped (SIGINT, SIGTERM, SIGHUP). A run killed outright
// leaves it behind, and the next run's sweep deletes it: the address names
// the machine, the process and when that process started, so a run on the
// same machine deletes one whose process has ended, and any run one over a
// day old. Only these: other flows' throwaways are theirs to delete.
const RUN_ADDRESS = /^delivered\+bw-flowrun-([0-9a-f]{6})-(\d+)-(\d+)-[0-9a-f]+@resend\.dev$/i;
const DAY_MS = 24 * 60 * 60 * 1000;
const MACHINE = createHash("sha256").update(hostname()).digest("hex").slice(0, 6);

/// When process [pid] started, in clock ticks since boot (the 22nd field
/// of /proc/PID/stat), so another process given the same pid later is not
/// taken for it; null when it has ended, or where there is no /proc.
function started(pid) {
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, "utf8");
    return stat.slice(stat.lastIndexOf(")") + 2).split(" ")[19] || null;
  } catch {
    return null;
  }
}

function running(pid, start) {
  if (start !== "0") return started(pid) === start;
  try {
    process.kill(Number(pid), 0);
    return true;
  } catch (trouble) {
    return trouble.code === "EPERM";
  }
}

/// The address of an account of process [pid]'s own, on this machine.
export function runAddress(pid = process.pid) {
  return `delivered+bw-flowrun-${MACHINE}-${pid}-${started(pid) || "0"}-${randomBytes(3).toString("hex")}@resend.dev`;
}

/// Whether [user] is a run's own account its run left behind: made on this
/// machine for a process that has ended, or made anywhere over a day ago.
export function leftBehind(user, now = Date.now()) {
  const named = RUN_ADDRESS.exec(String(user?.email || ""));
  if (!named) return false;
  const made = Date.parse(String(user.created_at || ""));
  if (Number.isFinite(made) && now - made > DAY_MS) return true;
  return named[1] === MACHINE && !running(named[2], named[3]);
}

let own = null;

/// This run's own account's address, once earlier runs' left-behind ones
/// are deleted. The account is made by its first sign-in (mintSession) and
/// deleted by endOwnAccount, or when the run is stopped.
export async function ownAccount() {
  if (own) return own.email;
  const p = project();
  if (!p) throw new Error("no SUPABASE_URL / SUPABASE_SECRET_KEY / SUPABASE_PUBLISHABLE_KEY — source .env");
  try {
    let swept = 0;
    for (const user of await users(p)) if (leftBehind(user) && await removed(p, user)) swept += 1;
    if (swept) console.log(`  (deleted ${swept} account(s) of earlier runs, left behind when they were killed)`);
  } catch (trouble) {
    console.log(`  (earlier runs' accounts not swept: ${trouble.message})`);
  }
  own = { email: runAddress(), ended: null };
  for (const [signal, code] of [["SIGINT", 130], ["SIGHUP", 129], ["SIGTERM", 143]]) {
    process.once(signal, () => {
      setTimeout(() => process.exit(code), 20000).unref();
      endOwnAccount().finally(() => process.exit(code));
    });
  }
  return own.email;
}

/// This run's own account deleted, with everything of it; once, however
/// often asked.
export function endOwnAccount() {
  if (!own) return Promise.resolve(false);
  own.ended ||= deleteAccount(own.email).then((gone) => {
    console.log(`  (this run's own account ${gone ? "deleted" : "not deleted: the next run's sweep will"}, ${own.email})`);
    return gone;
  });
  return own.ended;
}
