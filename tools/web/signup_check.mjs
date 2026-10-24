// Can somebody make a Brickworks account at an address they cannot read?
//
//   set -a; . ./.env; set +a
//   node tools/web/signup_check.mjs [--url=https://brickworks.diy]
//
// The only way in is a code sent to the address (api/otp.js), and every
// account is made on the server, by the admin users API: api/otp.js (then
// its code by the admin generate_link, since 2026-10-24), orangecheck's
// sign-in and the test sessions. None of them needs Supabase's public
// sign-up. Yet on
// 2026-10-23 it was open with "Confirm email" off (mailer_autoconfirm): a
// POST to /auth/v1/signup with an address and a password made a confirmed
// account at any address not yet used, and handed back a session the site
// took as signed in. Somebody could take an address before its owner came,
// and keep the password after they did. The public /otp likewise made a
// confirmed account for any address it was given.
//
// So the project's auth settings must be (Supabase dashboard,
// Authentication; or the Management API, PATCH /v1/projects/{ref}/config/auth):
//   disable_signup      true   Sign In / Providers: "Allow new users to sign up" off
//   mailer_autoconfirm  false  Email provider: "Confirm email" on
// with anonymous sign-ins, phone and every other provider off, and the
// email provider on (it is what the code and the test sessions' password
// grant go through). GoTrue asks disable_signup only in its public
// /signup, which /otp signs a new address up through: the admin API that
// makes every real account does not ask it (internal/api/mail.go and
// admin.go, v2.197.0).
//
// This reads the public settings, then plays the stranger at Resend test
// addresses, which deliver nowhere: a sign-up with a password, the public
// /otp asked to make an account, an anonymous sign-in, a wallet's. Each
// must be refused, with no account left behind. Then the ways in that must still
// work: a first sign-in by a code minted as api/otp.js mints one, a
// returning one, and an account made by the admin API signed in by its
// password, as the test sessions are. With --url, the site's /api/account
// is asked whether the first sign-in is signed in and asked its age.
//
// Every account it makes is deleted, and checked gone. Exits 1 on any FAIL.
import { randomBytes } from "node:crypto";
import { deleteAccount, mintCode } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = args.url ? String(args.url).replace(/\/+$/, "") : "";
const url = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const key = process.env.SUPABASE_PUBLISHABLE_KEY || "";
const secret = process.env.SUPABASE_SECRET_KEY || "";
if (!url || !key || !secret) {
  console.error("no SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY — source .env");
  process.exit(2);
}
const visitor = { apikey: key, "content-type": "application/json" };
const admin = { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" };

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

const tag = randomBytes(4).toString("hex");
const address = (what) => `delivered+signup-check-${what}-${tag}@resend.dev`;
const made = [];
const fresh = (what) => {
  const email = address(what);
  made.push(email);
  return email;
};

async function auth(path, { method = "POST", headers = visitor, body } = {}) {
  const reply = await fetch(`${url}/auth/v1${path}`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}
const said = (r) => `${r.status} ${r.body.error_code || r.body.code || ""}`.trim();

async function accountOf(email) {
  const listed = await auth("/admin/users?page=1&per_page=1000", { method: "GET", headers: admin });
  return (listed.body.users || []).find((u) => (u.email || "").toLowerCase() === email) || null;
}

async function redeem(email) {
  return auth("/verify", { body: { type: "email", email, token: await mintCode(email) } });
}

try {
  console.log("the project's auth settings");
  const settings = (await auth("/settings", { method: "GET" })).body;
  const others = Object.entries(settings.external || {}).filter(([name, on]) => on && name !== "email");
  check(settings.disable_signup === true, `public sign-up is off (disable_signup: ${settings.disable_signup})`);
  check(settings.mailer_autoconfirm === false,
    `an address must answer before an account is confirmed (mailer_autoconfirm: ${settings.mailer_autoconfirm})`);
  check(others.length === 0, `no way in but email (also on: ${others.map(([name]) => name).join(", ") || "none"})`);
  check(settings.external?.email === true, "the email provider is on, for the code");

  console.log("a stranger, at addresses they cannot read");
  const stranger = fresh("signup");
  const signup = await auth("/signup", { body: { email: stranger, password: `${randomBytes(18).toString("base64url")}-Aa1` } });
  check(signup.status >= 400 && !signup.body.access_token, `a sign-up with a password is refused (${said(signup)})`);
  check(!(await accountOf(stranger)), "and makes no account");

  const asked = fresh("otp");
  const otp = await auth("/otp", { body: { email: asked, create_user: true } });
  check(otp.status >= 400, `the public /otp makes no account for a new address (${said(otp)})`);
  check(!(await accountOf(asked)), "and none is there");

  const anonymous = await auth("/signup", { body: {} });
  if (anonymous.body.user?.id) await auth(`/admin/users/${anonymous.body.user.id}`, { method: "DELETE", headers: admin });
  check(anonymous.status >= 400 && !anonymous.body.access_token, `an anonymous sign-in is refused (${said(anonymous)})`);

  // Not in the public settings, so asked: a wallet's signature is a way in
  // with no address at all.
  const wallets = [];
  for (const chain of ["solana", "ethereum"]) {
    wallets.push(await auth("/token?grant_type=web3", { body: { chain, message: "x", signature: "x" } }));
  }
  check(wallets.every((w) => w.body.error_code === "web3_provider_disabled"),
    `a wallet sign-in is off (${wallets.map(said).join(", ")})`);

  console.log("the ways in");
  const person = fresh("first");
  const first = await redeem(person);
  check(Boolean(first.body.refresh_token) && first.body.user?.email === person,
    `a first sign-in by a code, minted as api/otp.js mints it, makes the account (${said(first)})`);
  if (site && first.body.access_token) {
    const headers = { authorization: `Bearer ${first.body.access_token}` };
    if (process.env.BW_BYPASS) headers["x-vercel-protection-bypass"] = process.env.BW_BYPASS;
    const reply = await fetch(`${site}/api/account`, { headers });
    const account = await reply.json().catch(() => ({}));
    check(account.signed_in === true && account.master === false, `${site} takes it as signed in (${reply.status})`);
    check(account.age === undefined || account.age.ask === true, "and asks its age first");
  }
  const again = await redeem(person);
  check(Boolean(again.body.refresh_token) && again.body.user?.id === first.body.user?.id,
    `a returning sign-in by a code reaches the same account (${said(again)})`);

  const tester = fresh("admin");
  const password = `${randomBytes(18).toString("base64url")}-Aa1`;
  const created = await auth("/admin/users", { headers: admin, body: { email: tester, password, email_confirm: true } });
  const grant = await auth("/token?grant_type=password", { body: { email: tester, password } });
  check(created.status === 200 && Boolean(grant.body.refresh_token),
    `an account the admin API makes signs in by its password (${created.status}, ${said(grant)})`);
} finally {
  for (const email of made) await deleteAccount(email);
  const left = [];
  for (const email of made) if (await accountOf(email)) left.push(email);
  check(left.length === 0, `every account made here is gone${left.length ? `: ${left.join(", ")} left` : ""}`);
}

console.log(failures ? `${failures} FAIL` : "all ok");
process.exit(failures ? 1 : 0);
