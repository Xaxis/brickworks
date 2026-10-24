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

import { createHmac } from "node:crypto";

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
    const listed = await (await fetch(`${p.url}/auth/v1/admin/users?page=1&per_page=1000`, { headers: admin })).json();
    const shared = (listed.users || []).find((u) => (u.email || "").toLowerCase() === SHARED_EMAIL);
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
  const listed = await (await fetch(`${p.url}/auth/v1/admin/users?page=1&per_page=1000`, {
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` },
  })).json();
  const user = (listed.users || []).find((u) => (u.email || "").toLowerCase() === email.toLowerCase());
  if (!user) return false;
  const gone = await fetch(`${p.url}/auth/v1/admin/users/${user.id}`, {
    method: "DELETE",
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` },
  });
  return gone.ok;
}
