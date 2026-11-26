// signin6: signreview3's R1 loop (attack3.mjs X) made stricter. An intruder holds a person's
// Google session and approves Claude connections from it in a loop, one every 150 ms, from a
// second before the person's Unlink until 6 s after it answers. X traded only a code it found
// with no way; here every code the loop got is traded, once the Unlink has answered, and every
// token so got is tried (tools/list and a refresh) 6 s later. Each round is a new throwaway.
//
//   set -a; . ./.env; set +a
//   node bench/results/signin6-2026-11-25/r1loop.mjs --r=http://127.0.0.1:12117 [--rounds=10]
//
// Prints a line a round and "r1loop: N of M rounds kept a connection; T codes traded". Throwaways
// (delivered+bw-si6-r1-*@resend.dev) are deleted at the end. Supabase verifies spent: one a
// round (Google's sign-in), paced 10 s apart.
import { createHash, randomBytes } from "node:crypto";
import { codeFor } from "../../../tools/web/ways_stand_in.mjs";
import { deleteAccount, mintSession } from "../../../tools/web/session.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const R = arg("r").replace(/\/+$/, "");
const ROUNDS = Number(arg("rounds", "10"));
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-si6-r1-${name}-${tag}@resend.dev`;
const made = [];
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
const network = () => `198.19.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;
const qs = (o) => new URLSearchParams(o).toString();

async function call(path, { method = "GET", token = "", body, cookie = "", from = "", form, headers = {} } = {}) {
  const sent = { ...headers, ...(token ? { authorization: `Bearer ${token}` } : {}), ...(cookie ? { cookie } : {}),
    ...(from ? { "x-forwarded-for": from } : {}) };
  let payload;
  if (form) { sent["content-type"] = "application/x-www-form-urlencoded"; payload = new URLSearchParams(form).toString(); }
  else if (body !== undefined) { sent["content-type"] = "application/json"; payload = JSON.stringify(body); }
  const reply = await fetch(`${R}${path}`, { method, redirect: "manual", headers: sent, body: payload });
  const text = await reply.text();
  let json = null;
  try {
    json = (reply.headers.get("content-type") || "").startsWith("text/event-stream")
      ? text.split("\n").filter((l) => l.startsWith("data:")).map((l) => JSON.parse(l.slice(5))).find((m) => m.id !== undefined) || null
      : text ? JSON.parse(text) : null;
  } catch { json = null; }
  return { status: reply.status, json, text, location: reply.headers.get("location") || "", cookies: reply.headers.getSetCookie?.() || [] };
}
const cookieNamed = (cookies, name) => (cookies.find((one) => one.startsWith(`${name}=`)) || "").split(";")[0];

/// A whole Google sign-in as [who], as the page makes it: its session, or null.
async function viaGoogle(who) {
  const from = network();
  const verifier = b64url(randomBytes(32));
  const st = await call(`/auth/google?${qs({ then: "/gallery", take: challengeOf(verifier) })}`, { from });
  if (st.status !== 302 || !st.location.startsWith("https://")) return null;
  const state = new URL(st.location).searchParams.get("state");
  const back = await call(`/auth/callback/google?${qs({ code: codeFor(st.location, who), state })}`,
    { cookie: cookieNamed(st.cookies, "bw_way_google"), from });
  const take = cookieNamed(back.cookies, "bw_way_take");
  if (!take) return null;
  const took = await call("/api/otp?op=way_take", { method: "POST", cookie: take, body: { code_verifier: verifier }, from });
  return took.json?.access_token ? took.json : null;
}

const CALLBACK = "https://claude.ai/api/mcp/auth_callback";
let clientId = "";
async function client() {
  if (clientId) return clientId;
  const reg = await call("/oauth/register", { method: "POST", body: { client_name: "signin6's R1 loop", redirect_uris: [CALLBACK],
    token_endpoint_auth_method: "none", grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] } });
  clientId = reg.json?.client_id || "";
  return clientId;
}
async function approve(token) {
  const verifier = b64url(randomBytes(32));
  const got = await call("/api/oauth?op=approve", { method: "POST", token, body: { response_type: "code", client_id: await client(),
    redirect_uri: CALLBACK, code_challenge: challengeOf(verifier), code_challenge_method: "S256", state: "r1", resource: `${R}/api/mcp`,
    scope: "build" } });
  return { status: got.status, code: got.json?.redirect ? new URL(got.json.redirect).searchParams.get("code") : null, verifier };
}
const trade = ({ code, verifier }) => call("/oauth/token", { method: "POST", form: { grant_type: "authorization_code", code,
  redirect_uri: CALLBACK, client_id: clientId, code_verifier: verifier, resource: `${R}/api/mcp` } });
const refresh = (bwr) => call("/oauth/token", { method: "POST", form: { grant_type: "refresh_token", refresh_token: bwr,
  client_id: clientId, resource: `${R}/api/mcp` } });
const tools = (access) => call("/api/mcp", { method: "POST", token: access, headers: { accept: "application/json, text/event-stream" },
  body: { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} } });

let kept = 0;
let tradedAll = 0;
let codesAll = 0;
let afterAll = 0;
try {
  for (let round = 1; round <= ROUNDS; round += 1) {
    if (round > 1) await wait(10000);
    const p = address(`loop${round}`);
    made.push(p);
    const own = await mintSession(p, { age: true });
    const g = await viaGoogle({ email: p, verified: true, hd: "resend.dev" });
    if (!g) throw new Error(`round ${round}: Google did not sign the person in`);
    await client();
    let stop = false;
    const tries = [];
    const loop = (async () => {
      while (!stop) {
        const a = await approve(g.access_token);
        tries.push({ ...a, at: Date.now() });
        await wait(150);
      }
    })();
    await wait(1000);
    const sent = Date.now();
    const un = await call("/api/otp?op=ways", { method: "POST", token: own.access_token, body: { with: "google", on: false } });
    const answered = Date.now();
    await wait(6000);
    stop = true;
    await loop;
    const codes = tries.filter((t) => t.code);
    const after = codes.filter((t) => t.at > answered);
    const traded = [];
    for (const c of codes) traded.push(await trade(c));
    const issued = traded.filter((t) => t.status === 200);
    await wait(6000);
    let lists = 0;
    let renews = 0;
    for (const t of issued) {
      if ((await tools(t.json.access_token)).status === 200) lists += 1;
      if ((await refresh(t.json.refresh_token)).status === 200) renews += 1;
    }
    const statuses = (list) => Object.entries(list.reduce((n, one) => ({ ...n, [one.status]: (n[one.status] || 0) + 1 }), {}))
      .map(([s, n]) => `${s}x${n}`).join(" ");
    if (lists || renews) kept += 1;
    tradedAll += issued.length;
    codesAll += codes.length;
    afterAll += after.length;
    console.log(`  ${lists || renews || issued.length ? "FINDING" : "ok     "} round ${round}: Unlink ${un.status} in ${answered - sent} ms; `
      + `${tries.length} approves (${statuses(tries)}), ${codes.length} gave a code, ${after.length} after the Unlink answered; `
      + `every code traded: ${statuses(traded) || "none to trade"}; 6 s on, of ${issued.length} issued, tools/list ${lists}, refresh ${renews}`);
  }
} catch (trouble) {
  console.log(`  FAIL    the loop finished: ${String(trouble?.stack || trouble).slice(0, 600)}`);
  kept = -1;
} finally {
  let left = 0;
  for (const email of made) if (!(await deleteAccount(email).catch(() => false))) left += 1;
  console.log(`  --      accounts made: ${made.length}, deleted (or never made): ${made.length - left}`);
}
console.log(`r1loop: ${kept} of ${ROUNDS} rounds kept a connection; ${tradedAll} codes traded of ${codesAll} made `
  + `(${afterAll} made after the Unlink answered)`);
process.exit(kept === 0 && tradedAll === 0 ? 0 : 1);
