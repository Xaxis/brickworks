// A throwaway account with Claude Code signed in to it, for a design run
// through the connector relay as the owner's are (tools/bench/realset.py
// --via relay), and its removal after.
//
//   node --env-file=.env tools/web/relay_account.mjs open --origin=http://127.0.0.1:8920
//   node --env-file=.env tools/web/relay_account.mjs close --user=<id>
//
// open prints one line of JSON: the session as the app keeps it (kept: put
// at user://session.json, a returning visitor's), the account's id, and a
// Claude Code token for the relay at --origin, as `claude mcp login`
// leaves one (tabwalk_flow.mjs). The address is a Resend test one, which
// no one receives mail at. close deletes the account; Supabase is
// production, so every open is closed.
//
//   node --env-file=.env tools/web/relay_account.mjs review [--origin=https://brickworks.diy]
//
// review is the one account that is kept: the one an app directory's
// reviewers sign in as (docs/directory/claude.md), on /review with its
// password, a Resend test address's (api/_auth.js isTestAccount). The
// password is .env's BW_REVIEW_PASSWORD, made and written there the first
// time and never printed; the account is made, or given that password
// again, and its age answered. It prints what open prints, the token only
// with --origin.
import { answerAge, mintSession } from "./session.mjs";
import { createHash, randomBytes } from "node:crypto";
import { appendFileSync, readFileSync } from "node:fs";

const REVIEW_EMAIL = "delivered+claude-review@resend.dev";

const [what, ...rest] = process.argv.slice(2);
const args = Object.fromEntries(rest.map((a) => {
  const [k, ...v] = a.replace(/^--/, "").split("=");
  return [k, v.join("=") || true];
}));

async function claudeCodeToken(origin, access) {
  const client = "https://claude.ai/oauth/claude-code-client-metadata";
  const back = "http://127.0.0.1:47321/callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${origin}/api/oauth?op=approve`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${access}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "realset",
      resource: `${origin}/api/mcp` }),
  })).json();
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) throw new Error(`no code: ${JSON.stringify(yes)}`);
  const tokens = await (await fetch(`${origin}/oauth/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back,
      client_id: client, code_verifier: verifier, resource: `${origin}/api/mcp` }).toString(),
  })).json();
  if (!String(tokens.access_token || "").startsWith("bwa_")) throw new Error(`no token: ${JSON.stringify(tokens)}`);
  return tokens.access_token;
}

async function close(user) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  if (!base || !secret || !user) return false;
  return (await fetch(`${base}/auth/v1/admin/users/${user}`, {
    method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` },
  }).catch(() => ({ ok: false }))).ok;
}

/// The review account signed in by its password, made first if it is new,
/// and the password set again if it is not the one .env holds.
async function review() {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const key = process.env.SUPABASE_PUBLISHABLE_KEY || "";
  if (!base || !secret || !key) throw new Error("no SUPABASE_URL / SUPABASE_SECRET_KEY / SUPABASE_PUBLISHABLE_KEY: --env-file=.env");
  let password = process.env.BW_REVIEW_PASSWORD || "";
  if (!password) {
    password = `${randomBytes(18).toString("base64url")}-Aa1`;
    const env = new URL("../../.env", import.meta.url);
    const was = readFileSync(env, "utf8");
    appendFileSync(env, `${was.endsWith("\n") ? "" : "\n"}BW_REVIEW_PASSWORD=${password}\n`);
    console.error("  (a password made for the review account: .env BW_REVIEW_PASSWORD)");
  }
  const admin = { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" };
  const made = await fetch(`${base}/auth/v1/admin/users`, {
    method: "POST", headers: admin, body: JSON.stringify({ email: REVIEW_EMAIL, password, email_confirm: true }),
  });
  if (!made.ok && made.status !== 422) throw new Error(`the review account was not made: ${made.status}`);
  const grant = () => fetch(`${base}/auth/v1/token?grant_type=password`, {
    method: "POST", headers: { apikey: key, "content-type": "application/json" },
    body: JSON.stringify({ email: REVIEW_EMAIL, password }),
  });
  let reply = await grant();
  if (reply.status === 400 && !made.ok) {
    const listed = await (await fetch(`${base}/auth/v1/admin/users?page=1&per_page=50&filter=${encodeURIComponent(REVIEW_EMAIL)}`,
      { headers: admin })).json();
    const account = (listed.users || []).find((u) => (u.email || "").toLowerCase() === REVIEW_EMAIL);
    if (!account) throw new Error("the review account is there and is not");
    // Signs out its sessions, a reviewer's too: only when .env's changed.
    await fetch(`${base}/auth/v1/admin/users/${account.id}`, { method: "PUT", headers: admin, body: JSON.stringify({ password }) });
    reply = await grant();
  }
  const body = await reply.json().catch(() => ({}));
  if (!body.refresh_token) throw new Error(`the review account would not sign in: ${reply.status}`);
  await answerAge(body.user?.id, REVIEW_EMAIL);
  return {
    access_token: body.access_token,
    kept: { refresh_token: body.refresh_token, email: REVIEW_EMAIL, user_id: body.user?.id || "", url: base, key },
  };
}

if (what === "review") {
  const origin = String(args.origin || "").replace(/\/+$/, "");
  const signed = await review();
  const token = origin ? await claudeCodeToken(origin, signed.access_token) : undefined;
  console.log(JSON.stringify({ user: signed.kept.user_id, email: REVIEW_EMAIL, kept: signed.kept, token }));
} else if (what === "open") {
  const origin = String(args.origin || "").replace(/\/+$/, "");
  if (!origin) throw new Error("--origin=http://127.0.0.1:PORT, the relay");
  const minted = await mintSession(`delivered+bwrealset${randomBytes(4).toString("hex")}@resend.dev`);
  try {
    const token = await claudeCodeToken(origin, minted.access_token);
    console.log(JSON.stringify({ user: minted.kept.user_id, email: minted.kept.email, kept: minted.kept, token }));
  } catch (trouble) {
    await close(minted.kept.user_id);
    throw trouble;
  }
} else if (what === "close") {
  const gone = await close(String(args.user || ""));
  console.log(gone ? "deleted" : "NOT deleted");
  process.exit(gone ? 0 : 1);
} else {
  console.error("usage: relay_account.mjs open --origin=URL | close --user=ID | review [--origin=URL]");
  process.exit(2);
}
