// Sign out everywhere, then every older token refused (smalls5, 2026-11-18).
//
// c3review (bench/results/c3review-2026-11-15/c3attack.mjs, S) found that
// after /admin's Sign out everywhere a person's access token went on
// working on the site's API until it ran out, up to an hour: the sessions
// were gone from Supabase, but api/_auth.js checked only the signature.
// This signs a throwaway account in at a Resend test address, uses its
// token on routes the app and the site call, signs it out everywhere as
// /admin does (rpc/admin_sign_out, which /api/admin?op=sign_out calls, by
// the secret key: the owner's account is never signed in to here), and
// asks the same routes again with the old token, at once; then signs in
// again and asks with the new one. The account is deleted at the end.
//
//   set -a; . /mnt/Projects/brickworks/.env; set +a
//   node tools/web/signed_out_check.mjs <preview or https://brickworks.diy>
//
// Each line is ok or FAIL; the exit code is the number of FAILs. A token is
// read by each instance at most once in api/_auth.js's SESSION_HELD_MS
// (5 s), so the old token is left unused for longer than that before the
// sign-out: what is asked after it is what an instance first reads then.
import { deleteAccount, mintSession } from "./session.mjs";
import { randomBytes } from "node:crypto";

const site = String(process.argv[2] || "").replace(/\/+$/, "");
if (!/^https:\/\/(brickworks-[a-z0-9-]+-xaxis-projects\.vercel\.app|brickworks\.diy)$/.test(site)) {
  console.error("signed_out_check: a preview of this project, or https://brickworks.diy");
  process.exit(2);
}
const bypass = process.env.VERCEL_BYPASS || process.env.BW_BYPASS || "";
const base = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET) {
  console.error("signed_out_check: source .env first (SUPABASE_URL, SUPABASE_SECRET_KEY)");
  process.exit(2);
}
const address = `delivered+bw-signedout-${randomBytes(4).toString("hex")}@resend.dev`;
const wait = (ms) => new Promise((done) => setTimeout(done, ms));

// Routes the app and the site call signed in, each read or a write that
// keeps nothing of anyone's but the throwaway's.
const ROUTES = [
  ["app", "GET", "/api/models"],
  ["app", "GET", "/api/collection"],
  ["app", "GET", "/api/account?op=keys"],
  ["app", "POST", "/api/account?op=theme", { theme: "dark" }],
  ["site", "GET", "/api/people?op=me"],
  ["site", "GET", "/api/account?op=theme"],
  ["site", "GET", "/api/people?op=favourites&page=1"],
  ["site", "POST", "/api/people?op=likes_choice", { shows: false }],
];

async function ask([, method, pathname, body], token) {
  const headers = { ...base, authorization: `Bearer ${token}` };
  if (body !== undefined) headers["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}`,
    { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let error = null;
  try { error = JSON.parse(text).error ?? null; } catch { /* not JSON */ }
  return { status: reply.status, error };
}

let failed = 0;
const row = (what, expected, got, ok) => {
  if (!ok) failed += 1;
  console.log(`${ok ? "ok  " : "FAIL"}  ${what}: expected ${expected}, got ${got}`);
};
const accepted = (status) => status < 500 && status !== 401 && status !== 403;

try {
  const before = await mintSession(address, { welcome: false });
  const old = before.access_token;
  const account = before.kept.user_id;
  console.log(`note  ${site}: throwaway ${address} (${account})`);
  const first = [];
  for (const route of ROUTES) {
    const got = await ask(route, old);
    first.push(got.status);
    row(`${route[0]} ${route[1]} ${route[2]} before`, "accepted", got.status, accepted(got.status));
  }
  await wait(6000);
  const out = await fetch(`${SUPABASE}/rest/v1/rpc/admin_sign_out`, {
    method: "POST", headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: JSON.stringify({ p_account: account }) });
  const ended = await out.json().catch(() => null);
  row("Sign out everywhere (admin_sign_out)", "sessions >= 1", `${out.status} ${JSON.stringify(ended)}`,
    out.ok && ended?.sessions >= 1);
  const at = Date.now();
  for (const route of ROUTES) {
    const got = await ask(route, old);
    row(`${route[0]} ${route[1]} ${route[2]} with the old token, ${((Date.now() - at) / 1000).toFixed(1)} s after`,
      "401", `${got.status} ${JSON.stringify(got.error)}`, got.status === 401);
  }
  const after = await mintSession(address, { age: false, welcome: false });
  for (const [i, route] of ROUTES.entries()) {
    const got = await ask(route, after.access_token);
    row(`${route[0]} ${route[1]} ${route[2]} with a token from after`, `${first[i]} (as before)`, got.status,
      got.status === first[i]);
  }
} catch (trouble) {
  row("the run", "no error", String(trouble?.stack || trouble).slice(0, 300), false);
} finally {
  const gone = await deleteAccount(address).catch(() => false);
  console.log(`note  throwaway deleted: ${gone}`);
}
console.log(failed ? `signed_out_check: ${failed} FAILED` : "signed_out_check: all ok");
process.exit(failed);
