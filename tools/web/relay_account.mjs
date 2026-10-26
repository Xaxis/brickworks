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
import { mintSession } from "./session.mjs";
import { createHash, randomBytes } from "node:crypto";

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

if (what === "open") {
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
  console.error("usage: relay_account.mjs open --origin=URL | close --user=ID");
  process.exit(2);
}
