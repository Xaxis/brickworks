// A Supabase, and Resend, in memory, wrong in the ways the sign-in canary
// (api/_canary.js) looks for: for tools/web/canary_check.mjs --stand-in,
// which proves each check fails when its setting is off. A fetch for this
// process alone; nothing leaves it, and any address it does not stand in
// for throws.
//
// The faults, any together:
//   signupOpen          public sign-up on, Supabase confirming an address
//                       itself (as on 2026-10-23): a sign-up makes a
//                       confirmed account and a session, and the public
//                       /otp signs an unconfirmed address up and confirms it
//   unconfirmedSignsIn  an unconfirmed address's password signs it in
//   codeRefused         every code redeemed is refused
//   totpOn              a session can enrol an authenticator app
//   undeletable         no account can be deleted
//   resendDown          Resend refuses every mail
//   recordDown          the run's record cannot be written

import { generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";

export const STAND_IN = "https://supabase.stand-in.invalid";
// One signing key for the process: api/_auth.js keeps the keys it read for
// ten minutes, whichever stand-in is asked next.
const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
const jwk = { ...publicKey.export({ format: "jwk" }), kid: "stand-in", alg: "ES256", use: "sig" };

export function standIn(faults = {}) {
  const users = new Map();
  const codes = new Map();
  const mail = [];
  const rows = [];

  const json = (status, body) => new Response(body === null ? null : JSON.stringify(body),
    { status, headers: { "content-type": "application/json" } });
  const refused = (status, code, msg) => json(status, { code: status, error_code: code, msg });
  const now = () => new Date().toISOString();
  const shown = ({ password, ...user }) => user;
  const byEmail = (email) => [...users.values()].find((one) => one.email === String(email || "").toLowerCase());
  function make(email, confirmed, password = null, createdAt = now()) {
    const user = { id: randomUUID(), email: String(email).toLowerCase(), email_confirmed_at: confirmed ? now() : null,
      last_sign_in_at: null, created_at: createdAt, password };
    users.set(user.id, user);
    return user;
  }
  const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  function session(user, method) {
    user.last_sign_in_at = now();
    const at = Math.floor(Date.now() / 1000);
    const signed = `${b64({ alg: "ES256", kid: "stand-in", typ: "JWT" })}.${b64({ iss: `${STAND_IN}/auth/v1`,
      aud: "authenticated", sub: user.id, email: user.email, exp: at + 3600, amr: [{ method, timestamp: at }],
      session_id: randomUUID() })}`;
    const signature = sign("sha256", Buffer.from(signed), { key: privateKey, dsaEncoding: "ieee-p1363" });
    return { access_token: `${signed}.${signature.toString("base64url")}`, refresh_token: randomBytes(8).toString("hex"),
      user: shown(user) };
  }
  function bearerOf(headers) {
    const token = String(headers?.authorization || "").replace(/^Bearer /, "");
    try {
      return users.get(JSON.parse(Buffer.from(token.split(".")[1], "base64url")).sub) || null;
    } catch {
      return null;
    }
  }

  async function fetchStandIn(input, init = {}) {
    const url = new URL(String(input?.url || input));
    const method = init.method || "GET";
    const body = init.body ? JSON.parse(init.body) : {};
    if (url.origin === "https://api.resend.com") {
      mail.push(body);
      return faults.resendDown ? json(500, { message: "stood in: Resend down" }) : json(200, { id: `stand-in-${mail.length}` });
    }
    if (url.origin !== STAND_IN) throw new Error(`canary stand-in: nothing leaves this process (${url.origin})`);
    const path = url.pathname;
    const one = /^\/auth\/v1\/admin\/users\/([0-9a-f-]+)$/.exec(path);
    if (path === "/auth/v1/.well-known/jwks.json") return json(200, { keys: [jwk] });
    if (path === "/auth/v1/admin/users" && method === "GET") {
      const filter = String(url.searchParams.get("filter") || "").toLowerCase();
      return json(200, { users: [...users.values()].filter((user) => user.email.includes(filter)).map(shown), aud: "authenticated" });
    }
    if (path === "/auth/v1/admin/users" && method === "POST") {
      if (byEmail(body.email)) return refused(422, "email_exists", "A user with this email address has already been registered");
      return json(200, shown(make(body.email, body.email_confirm === true, body.password || null)));
    }
    if (one && method === "DELETE") {
      if (faults.undeletable) return refused(500, "unexpected_failure", "Database error deleting user");
      users.delete(one[1]);
      return json(200, {});
    }
    if (path === "/auth/v1/admin/generate_link") {
      const user = byEmail(body.email);
      if (!user) return refused(422, "signup_disabled", "Signups not allowed for this instance");
      const code = String(Math.floor(100000 + Math.random() * 900000));
      codes.set(user.email, code);
      return json(200, { email_otp: code, action_link: "stood in", verification_type: "magiclink" });
    }
    if (path === "/auth/v1/signup") {
      if (!faults.signupOpen) return refused(422, "signup_disabled", "Signups not allowed for this instance");
      return json(200, session(byEmail(body.email) || make(body.email, true, body.password), "password"));
    }
    if (path === "/auth/v1/token" && url.searchParams.get("grant_type") === "password") {
      const user = byEmail(body.email);
      if (!user || !user.password || user.password !== body.password) return refused(400, "invalid_credentials", "Invalid login credentials");
      if (!user.email_confirmed_at && !faults.unconfirmedSignsIn) return refused(400, "email_not_confirmed", "Email not confirmed");
      return json(200, session(user, "password"));
    }
    if (path === "/auth/v1/otp") {
      // As GoTrue: an address with no confirmed account goes through sign-up.
      const user = byEmail(body.email);
      if (!user?.email_confirmed_at) {
        if (!faults.signupOpen) return refused(422, "signup_disabled", "Signups not allowed for this instance");
        (user || make(body.email, false)).email_confirmed_at = now();
      }
      return json(200, {});
    }
    if (path === "/auth/v1/verify") {
      const user = byEmail(body.email);
      if (faults.codeRefused || !user || codes.get(user.email) !== body.token) {
        return refused(403, "otp_expired", "Token has expired or is invalid");
      }
      codes.delete(user.email);
      user.email_confirmed_at ||= now();
      return json(200, session(user, "otp"));
    }
    if (path === "/auth/v1/factors") {
      if (!bearerOf(init.headers)) return refused(401, "no_authorization", "This endpoint requires a valid Bearer token");
      if (!faults.totpOn) return refused(422, "mfa_totp_enroll_not_enabled", "MFA enroll is disabled for TOTP");
      return json(200, { id: randomUUID(), type: "totp" });
    }
    if (path === "/auth/v1/logout") return json(204, null);
    if (path === "/rest/v1/canary_runs" && method === "POST") {
      if (faults.recordDown) return json(404, { code: "PGRST205", message: "stood in: no such table" });
      rows.push(body);
      return new Response(null, { status: 201 });
    }
    throw new Error(`canary stand-in: not stood in for: ${method} ${path}`);
  }

  return { fetch: fetchStandIn, users, mail, rows, make };
}
