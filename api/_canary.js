// The daily canary of signing in, 2026-10-24.
//
// Since 2026-10-24 production's Supabase takes no public sign-up
// (disable_signup), holds an address unconfirmed until it answers ("Confirm
// email" on, mailer_autoconfirm off) and enrols no authenticator app (TOTP
// off). Every account is made here instead, by the admin API (api/otp.js).
// A setting turned back on in Supabase's dashboard says so nowhere, so once
// a day Vercel's cron asks /api/otp/canary, and this plays each part as
// somebody would, at Resend test addresses, which deliver nowhere:
//
//   (a) a public sign-up with the publishable key: refused as sign-up off
//       (signup_disabled), and no account left behind;
//   (b) an address made by the admin API and never confirmed: its password
//       refused until the address answers (email_not_confirmed), and the
//       public /otp, which would sign it up again and confirm it, refused;
//       still unconfirmed after;
//   (c) a new address given a code by api/otp.js's own mint and deliver,
//       the code redeemed: a session the site takes (api/_auth.js verify),
//       which enrols no authenticator app (mfa_totp_enroll_not_enabled).
//
// Each is judged by Supabase's own word for the setting, so a trigger that
// refuses the same call (supabase/no_new_ways_in.sql) cannot pass for it.
// Every account it makes is deleted whatever happens, and any an earlier
// run left (one cut off by its time limit) at the start of the next. Each
// run is a row of canary_runs (supabase/canary.sql), and a failed one is
// mailed to MASTER_EMAIL, once, saying which check failed and what came
// back. tools/web/canary_check.mjs runs the same checks from a checkout.

import { randomBytes } from "node:crypto";
import { verify } from "./_auth.js";
import { isCron } from "./_cron.js";
import { db } from "./_db.js";

const SENDER = "Brickworks <noreply@brickworks.diy>";
// Only these are ever deleted as left behind: a canary's own, by its address.
export const CANARY_ADDRESS = /^delivered\+canary-[abc]-\d+-[0-9a-f]+@resend\.dev$/;
// A run takes seconds; one older than this was cut off.
const STALE_MS = 15 * 60 * 1000;

export const CHECKS = {
  a: "a public sign-up is refused, and leaves no account",
  b: "an unconfirmed address cannot sign in",
  c: "a new address signs in by an emailed code",
  gone: "every account the canary made is gone",
};

const project = () => String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const visitor = () => ({ apikey: process.env.SUPABASE_PUBLISHABLE_KEY || "", "content-type": "application/json" });
function server() {
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  return { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" };
}

async function auth(path, { method = "POST", headers = visitor(), body } = {}) {
  const reply = await fetch(`${project()}/auth/v1${path}`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(10000),
  });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

/// What Supabase answered, fit for a mail: its status, error code and
/// message, and whether it handed out a session. Never the session.
function said(reply) {
  const words = String(reply.body.msg || reply.body.message || reply.body.error_description || "").slice(0, 120);
  return [reply.status, reply.body.error_code, words, reply.body.access_token ? "(and a session)" : ""]
    .filter(Boolean).join(" ");
}

const passwordFor = () => `${randomBytes(18).toString("base64url")}-Aa1`;

async function accountAt(email) {
  const listed = await auth(`/admin/users?page=1&per_page=50&filter=${encodeURIComponent(email)}`,
    { method: "GET", headers: server() });
  return (listed.body.users || []).find((one) => String(one.email || "").toLowerCase() === email) || null;
}

async function remove(email) {
  const account = await accountAt(email);
  if (account) await auth(`/admin/users/${account.id}`, { method: "DELETE", headers: server() });
}

/// The accounts canaries made more than STALE_MS ago, deleted: what a run
/// cut off before its end left. Says how many.
async function sweepStale() {
  const listed = await auth(`/admin/users?page=1&per_page=1000&filter=${encodeURIComponent("+canary-")}`,
    { method: "GET", headers: server() });
  const stale = (listed.body.users || []).filter((one) => CANARY_ADDRESS.test(String(one.email || ""))
    && Date.now() - Date.parse(one.created_at || 0) > STALE_MS);
  for (const one of stale) await auth(`/admin/users/${one.id}`, { method: "DELETE", headers: server() });
  return stale.length;
}

/// The three checks, against the Supabase this deployment is given.
/// [ways] are api/otp.js's own mint and deliver, so (c) makes and sends a
/// code exactly as a sign-in does. [askSite], when given, is asked of (c)'s
/// session too: {ok, said}, a deployment's /api/account, from a checkout.
/// Resolves {ok, checks: [{check, ok, what, said}], made, left, stale}, the
/// addresses it made and those it could not delete; never throws.
export async function canary({ mint, deliver }, { askSite = null } = {}) {
  const checks = [];
  const step = (check, ok, what, answer) => checks.push({ check, ok: Boolean(ok), what, said: String(answer) });
  const made = [];
  const fresh = (check) => {
    const email = `delivered+canary-${check}-${Date.now()}-${randomBytes(3).toString("hex")}@resend.dev`;
    made.push(email);
    return email;
  };
  const guarded = async (check, run) => {
    try {
      await run();
    } catch (trouble) {
      step(check, false, "it ran to its end", `threw: ${String(trouble?.message || trouble).slice(0, 160)}`);
    }
  };

  let result = null;
  let stale = 0;
  try {
    stale = await sweepStale();
  } catch {
    // Left for the next run, and its own accounts still go below.
  }
  try {
    await guarded("a", async () => {
      const email = fresh("a");
      const signup = await auth("/signup", { body: { email, password: passwordFor() } });
      step("a", signup.body.error_code === "signup_disabled" && !signup.body.access_token,
        "a public sign-up with a password is refused, sign-up being off", said(signup));
      const left = await accountAt(email);
      step("a", !left, "and it leaves no account",
        left ? `an account is there, ${left.email_confirmed_at ? "confirmed" : "unconfirmed"}` : "none");
    });

    await guarded("b", async () => {
      const email = fresh("b");
      const password = passwordFor();
      const created = await auth("/admin/users", { headers: server(), body: { email, password, email_confirm: false } });
      step("b", created.status === 200 && !created.body.email_confirmed_at,
        "an address made by the admin API, unconfirmed", said(created));
      if (created.status !== 200) return;
      const grant = await auth("/token?grant_type=password", { body: { email, password } });
      step("b", grant.body.error_code === "email_not_confirmed" && !grant.body.access_token,
        "its password signs it in to nothing until the address answers", said(grant));
      const otp = await auth("/otp", { body: { email, create_user: false } });
      step("b", otp.body.error_code === "signup_disabled",
        "the public /otp, which would sign it up again and confirm it, is refused", said(otp));
      const after = await accountAt(email);
      step("b", after && !after.email_confirmed_at && !after.last_sign_in_at, "and it is still unconfirmed, never signed in",
        after ? `confirmed ${after.email_confirmed_at || "no"}, signed in ${after.last_sign_in_at || "never"}` : "it is gone");
    });

    await guarded("c", async () => {
      const email = fresh("c");
      const code = await mint(email);
      step("c", Boolean(code), "a new address is given a code, as api/otp.js mints one", code ? "a code" : "no code");
      if (!code) return;
      const sent = await deliver(email, code);
      step("c", sent === true, "and it is sent, as api/otp.js sends one",
        !sent ? "not delivered" : process.env.RESEND_API_KEY ? "sent through Resend" : "no mail key here: a test inbox takes it as sent");
      const redeemed = await auth("/verify", { body: { type: "email", email, token: code } });
      const access = redeemed.body.access_token;
      step("c", Boolean(access && redeemed.body.refresh_token) && redeemed.body.user?.email === email,
        "the code redeemed signs the address in", said(redeemed));
      if (!access) return;
      const bearer = { ...visitor(), authorization: `Bearer ${access}` };
      try {
        const claims = await verify(access);
        const amr = (claims.amr || []).map((one) => one?.method).join(",");
        step("c", claims.email === email && amr === "otp", "a session the site takes as signed in, by a code",
          `${claims.email === email ? "its address" : "another address"}, amr ${amr || "none"}`);
      } catch (refused) {
        step("c", false, "a session the site takes as signed in, by a code", `refused: ${refused.message}`);
      }
      if (askSite) {
        const asked = await askSite(access);
        step("c", asked.ok, "and the deployment asked takes it as signed in", asked.said);
      }
      const factor = await auth("/factors", { headers: bearer, body: { factor_type: "totp", friendly_name: "canary" } });
      step("c", factor.body.error_code === "mfa_totp_enroll_not_enabled",
        "it enrols no authenticator app, TOTP being off", said(factor));
      await auth("/logout", { headers: bearer }).catch(() => null);
    });
  } finally {
    const left = [];
    for (const email of made) {
      try {
        await remove(email);
        if (await accountAt(email)) left.push(email);
      } catch {
        left.push(email);
      }
    }
    step("gone", left.length === 0, "every account it made is deleted", left.length ? `left: ${left.join(", ")}` : `${made.length} made, none left`);
    result = { ok: checks.every((one) => one.ok), checks, made, left, stale };
  }
  return result;
}

/// The owner told of a failed run, once: which checks failed and what each
/// got back. "sent", "failed: <why>", or "skipped: <why>" where this
/// deployment has no mail key (a unit's preview) or no owner.
async function tellOwner(result, host) {
  const to = String(process.env.MASTER_EMAIL || "").trim();
  const key = process.env.RESEND_API_KEY;
  if (!key) return "skipped: no RESEND_API_KEY here";
  if (!to) return "skipped: no MASTER_EMAIL here";
  const failed = result.checks.filter((one) => !one.ok);
  const letters = [...new Set(failed.map((one) => one.check))];
  const lines = [
    `The daily check of signing in to Brickworks failed on ${host || "a deployment"} at ${new Date().toISOString()}.`,
    "",
    ...letters.flatMap((check) => [
      `(${check}) ${CHECKS[check]}: FAILED`,
      ...failed.filter((one) => one.check === check).map((one) => `    ${one.what}\n      got: ${one.said}`),
      "",
    ]),
    result.left.length ? `Accounts it could not delete: ${result.left.join(", ")}` : "Every account it made was deleted.",
    "Each run is a row of public.canary_runs in Supabase (api/_canary.js says what each check plays).",
  ];
  try {
    const reply = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({
        from: process.env.EMAIL_FROM || SENDER, to: [to],
        subject: `Brickworks sign-in check failed: ${letters.map((check) => `(${check})`).join(" ")}`,
        text: lines.join("\n"),
      }),
      signal: AbortSignal.timeout(10000),
    });
    if (!reply.ok) console.error(`canary: Resend refused the owner's mail: ${reply.status}`);
    return reply.ok ? "sent" : `failed: Resend ${reply.status}`;
  } catch (trouble) {
    return `failed: ${String(trouble?.message || trouble).slice(0, 120)}`;
  }
}

/// GET /api/otp/canary, Vercel's cron's alone: the checks run, the owner
/// told of a failure, the run recorded. 200 when every check held, 500
/// when one did not, so the cron's own log shows it too.
export async function canaryRoute(request, response, ways) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the canary is the cron's" });
  const result = await canary(ways);
  const host = String(request.headers?.host || process.env.VERCEL_URL || "").slice(0, 200);
  const mailed = result.ok ? "none" : await tellOwner(result, host);
  let recorded = true;
  try {
    await db("canary_runs", { method: "POST", prefer: "return=minimal", body: {
      ok: result.ok, host, checks: result.checks, left_behind: result.left, stale: result.stale, mailed } });
  } catch (trouble) {
    recorded = false;
    console.error(`canary: the run was not recorded: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
  if (!result.ok) console.error(`canary: failed: ${result.checks.filter((one) => !one.ok).map((one) => `(${one.check}) ${one.what}: ${one.said}`).join("; ")}`);
  return response.status(result.ok ? 200 : 500).json({ ...result, host, mailed, recorded });
}
