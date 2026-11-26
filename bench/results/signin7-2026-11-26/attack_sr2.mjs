// signreview2 (2026-11-24): attacks on signin4 (bf517bcbb), against two relays of
// that tree with Google, GitHub and Connect stood in for (tools/web/ways_stand_in.mjs)
// and the real Supabase project behind them. Throwaway accounts only, all deleted.
//
//   --r1  a relay whose owner is a throwaway O1 (X is a person there)
//   --r2  a relay whose owner is X (MASTER_EMAIL=X)
//   --x   X's address: delivered+bw-sr2-kx-<tag>@resend.dev (it has a k, for the Kelvin case)
//
// Sections (each prints "  ok"/"  FINDING"/"  --" lines; FINDING is a hole, ok is a holding):
//   A. F8: a GitHub session X had before X's address was the owner's; its refresh; the
//      owner's address by Google and GitHub in caps and with U+212A; the code's session.
//   B. F9 turned on others: one network's starts, and one start cookie replayed at the
//      callback, lock a second person on that network out before Google or GitHub is asked.
//   C. Unlink and Claude's connector: a connection approved from a GitHub session outlives
//      the Unlink that ended that session, and still reaches the person's tab.
//   D. The new functions and tables from the browser's keys (anon, a signed-in person), and
//      ?op=ways asked about another account.
// Supabase verifies spent from this box: 4 (A 2, C 1, D 0, B 0), so the box's bucket is spared.
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { codeFor } from "../../../tools/web/ways_stand_in.mjs";
import { deleteAccount, mintCode, mintSession } from "../../../tools/web/session.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const R1 = arg("r1").replace(/\/+$/, "");
const R2 = arg("r2").replace(/\/+$/, "");
const X = arg("x");
// --only=A,B: the sections to run (C and D always run; D reads C's account).
const ONLY = arg("only", "A,B").split(",");
const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const ANON = process.env.SUPABASE_PUBLISHABLE_KEY || "";
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-sr2-${name}-${tag}@resend.dev`;
const made = [X];
let findings = 0;
const say = (kind, what, detail = "") => {
  if (kind === "FINDING") findings += 1;
  console.log(`  ${kind.padEnd(7)} ${what}${detail ? `: ${String(detail).slice(0, 700)}` : ""}`);
};
const holds = (ok, what, detail = "") => say(ok ? "ok" : "FAIL", what, ok ? "" : detail);
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
const network = () => `198.19.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;
const sessionIdOf = (jwt) => {
  try { return JSON.parse(Buffer.from(String(jwt).split(".")[1], "base64url").toString()).session_id || ""; } catch { return ""; }
};

async function call(site, path, { method = "GET", token = "", body, cookie = "", from = "", form, headers = {} } = {}) {
  const sent = { ...headers, ...(token ? { authorization: `Bearer ${token}` } : {}), ...(cookie ? { cookie } : {}),
    ...(from ? { "x-forwarded-for": from } : {}) };
  let payload;
  if (form) { sent["content-type"] = "application/x-www-form-urlencoded"; payload = new URLSearchParams(form).toString(); }
  else if (body !== undefined) { sent["content-type"] = "application/json"; payload = JSON.stringify(body); }
  const reply = await fetch(`${site}${path}`, { method, redirect: "manual", headers: sent, body: payload });
  const text = await reply.text();
  let json = null;
  try {
    json = (reply.headers.get("content-type") || "").startsWith("text/event-stream")
      ? text.split("\n").filter((l) => l.startsWith("data:")).map((l) => JSON.parse(l.slice(5))).find((m) => m.id !== undefined) || null
      : text ? JSON.parse(text) : null;
  } catch { json = null; }
  return { status: reply.status, json, text, location: reply.headers.get("location") || "", cookies: reply.headers.getSetCookie?.() || [],
    headers: reply.headers };
}
const cookieNamed = (cookies, name) => (cookies.find((one) => one.startsWith(`${name}=`)) || "").split(";")[0];

/// A whole sign-in with [name] as [who] at [site], as the page makes it.
async function viaWay(site, name, who, { from = network() } = {}) {
  const verifier = b64url(randomBytes(32));
  const start = await call(site, `/auth/${name}?${new URLSearchParams({ then: "/gallery", take: challengeOf(verifier) })}`, { from });
  const startCookie = cookieNamed(start.cookies, `bw_way_${name}`);
  if (start.status !== 302 || !/^https:\/\//.test(start.location)) return { start };
  const code = codeFor(start.location, who);
  const state = new URL(start.location).searchParams.get("state");
  const back = await call(site, `/auth/callback/${name}?${new URLSearchParams({ code, state })}`, { cookie: startCookie, from });
  const take = cookieNamed(back.cookies, "bw_way_take");
  const took = take ? await call(site, "/api/otp?op=way_take", { method: "POST", cookie: take, body: { code_verifier: verifier }, from }) : null;
  return { start, back, took, session: took?.json?.access_token ? took.json : null };
}

/// A sign-in by a code to [email], redeemed as the dialog does (amr otp). One verify.
async function codeSignIn(email) {
  if (!made.includes(email)) made.push(email);
  await mintSession(email, { age: true });
  const code = await mintCode(email, { welcome: false });
  const reply = await fetch(`${SB}/auth/v1/verify`, { method: "POST", headers: { apikey: ANON, "content-type": "application/json" },
    body: JSON.stringify({ type: "email", email, token: code }) });
  const body = await reply.json().catch(() => ({}));
  if (!body.access_token) throw new Error(`the code would not redeem: ${reply.status}`);
  return body;
}

async function renewed(refresh) {
  const reply = await fetch(`${SB}/auth/v1/token?grant_type=refresh_token`, { method: "POST",
    headers: { apikey: ANON, "content-type": "application/json" }, body: JSON.stringify({ refresh_token: refresh }) });
  return reply.ok ? reply.json() : { status: reply.status };
}

async function rpcAs(key, bearerToken, name, body) {
  const reply = await fetch(`${SB}/rest/v1/rpc/${name}`, { method: "POST",
    headers: { apikey: key, ...(bearerToken ? { authorization: `Bearer ${bearerToken}` } : {}), "content-type": "application/json" },
    body: JSON.stringify(body) });
  const text = await reply.text();
  let code = "";
  try { code = JSON.parse(text)?.code || ""; } catch { /* not json */ }
  return { status: reply.status, code, text: text.slice(0, 160) };
}
const serverRpc = (name, body) => fetch(`${SB}/rest/v1/rpc/${name}`, { method: "POST",
  headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" }, body: JSON.stringify(body) })
  .then((r) => r.json());

const where = (one) => (one?.back?.location || one?.start?.location || "").slice(0, 140);

try {
  // ------------------------------------------------------------------ A
  if (ONLY.includes("A")) {
  console.log("A. the owner's console (F8)");
  // X is a person on R1: GitHub makes X's account and signs it in (bound: made).
  const xHub = await viaWay(R1, "github", { email: X, verified: true });
  holds(Boolean(xHub.session), "A0. on R1, where X is nobody special, GitHub signs X in (a new account)", where(xHub));
  if (xHub.session) {
    const asHub = await call(R2, "/api/admin?op=switches", { token: xHub.session.access_token });
    holds(asHub.status === 403 && asHub.json?.code_only === true,
      "A1. X's address made the owner's (R2): the GitHub session X had from before is refused by the console (403 code_only)",
      `${asHub.status} ${asHub.text.slice(0, 160)}`);
    const fresh = await renewed(xHub.session.refresh_token);
    const asRenewed = fresh.access_token ? await call(R2, "/api/admin?op=switches", { token: fresh.access_token }) : null;
    holds(fresh.access_token && sessionIdOf(fresh.access_token) === sessionIdOf(xHub.session.access_token) && asRenewed?.status === 403,
      "A2. that session renewed (a new access token, the same session): refused too", `${JSON.stringify(fresh).slice(0, 120)} ${asRenewed?.status}`);
  }
  const kelvin = X.replace("k", "K");
  const tries = [
    ["github", { email: X, verified: true }, "GitHub, X"],
    ["github", { email: X.toUpperCase(), verified: true }, "GitHub, X in capitals"],
    ["github", { email: ` ${X} `, verified: true }, "GitHub, X with spaces"],
    ["github", { email: kelvin, verified: true }, "GitHub, X with U+212A for k"],
    ["google", { email: X, verified: true, hd: "resend.dev" }, "Google (Workspace hd), X"],
    ["google", { email: X.toUpperCase(), verified: true, hd: "resend.dev" }, "Google, X in capitals"],
  ];
  for (const [name, who, what] of tries) {
    const one = await viaWay(R2, name, who);
    holds(!one.session && /failed=(code_only|unverified)/.test(one.back?.location || ""), `A3. on R2, ${what}: refused, nothing handed out`,
      where(one));
    console.log(`  --      ${what}: ${where(one)}`);
  }
  const xCode = await codeSignIn(X);
  const asCode = await call(R2, "/api/admin?op=switches", { token: xCode.access_token });
  const ownWays = await call(R2, "/api/otp?op=ways", { token: xCode.access_token });
  holds(asCode.status === 200 && ownWays.json?.offered?.google === false && ownWays.json?.offered?.github === false,
    "A4. X's code session opens R2's console; Settings offers X neither way", `${asCode.status} ${JSON.stringify(ownWays.json)}`);
  // The owner links GitHub again from Settings (the route still takes it): GitHub still refused.
  const relink = await call(R2, "/api/otp?op=ways", { method: "POST", token: xCode.access_token, body: { with: "github", on: true } });
  const after = await viaWay(R2, "github", { email: X, verified: true });
  holds(relink.status === 200 && !after.session && /failed=code_only/.test(after.back?.location || ""),
    "A5. the owner presses Link again on GitHub: GitHub still refused for the owner", `${relink.status} ${where(after)}`);
  }

  // ------------------------------------------------------------------ B
  if (ONLY.includes("B")) {
  console.log("B. a throttle turned on others (F9)");
  const office = network();
  const fresh = () => new URLSearchParams({ then: "/", take: challengeOf(b64url(randomBytes(32))) });
  let started = 0;
  for (let n = 0; n < 30; n += 1) {
    const one = await call(R1, `/auth/github?${fresh()}`, { from: office });
    if (one.status === 302 && one.location.startsWith("https://github.com/")) started += 1;
  }
  const victimStart = await call(R1, `/auth/google?${fresh()}`, { from: office });
  const victimApp = await call(R1, `/auth/github?${new URLSearchParams({ app: "http://127.0.0.1:53123/oc/callback", state: "victimstate1",
    code_challenge: challengeOf(b64url(randomBytes(32))) })}`, { from: office });
  const elsewhere = await call(R1, `/auth/google?${fresh()}`, { from: network() });
  say(/failed=often/.test(victimStart.location) ? "FINDING" : "ok",
    `B1. ${started} bare starts from one network (no Google or GitHub account, no code: only GET /auth/github?take=<any 43 letters>) `
    + "lock everyone else on it out of starting Google, GitHub and the app's GitHub for 15 minutes",
    `victim's Google start: ${victimStart.location.slice(0, 90)}; the app's: ${victimApp.location.slice(0, 90)}; another network: ${elsewhere.location.slice(0, 40)}`);
  // One start, its cookie replayed at the callback with a made-up code: each counted as a way back.
  const nat = network();
  const one = await call(R1, `/auth/github?${fresh()}`, { from: nat });
  const cookie = cookieNamed(one.cookies, "bw_way_github");
  const state = new URL(one.location).searchParams.get("state");
  const replays = [];
  for (let n = 0; n < 10; n += 1) {
    replays.push((await call(R1, `/auth/callback/github?${new URLSearchParams({ code: `junk${n}`, state })}`, { cookie, from: nat })).location);
  }
  const victim = address("natvictim");
  made.push(victim);
  const victimIn = await viaWay(R1, "github", { email: victim, verified: true }, { from: nat });
  const victimMade = await fetch(`${SB}/auth/v1/admin/users?${new URLSearchParams({ filter: victim, per_page: "5" })}`,
    { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } }).then((r) => r.json()).then((j) => (j.users || []).length);
  say(/failed=often/.test(victimIn.back?.location || "") ? "FINDING" : "ok",
    "B2. one start cookie, replayed 10 times at the callback with made-up codes (the server never spends it), "
    + "uses up that network's 10 ways back: the next person there with a real GitHub sign-in is refused before GitHub is asked",
    `replays: ${[...new Set(replays.map((l) => new URL(l, "http://x").searchParams.get("failed")))].join(",")}; `
    + `the person's: ${where(victimIn)}; their account made: ${victimMade}`);
  }

  // ------------------------------------------------------------------ C
  console.log("C. Unlink and Claude's connector");
  const y = address("conn");
  made.push(y);
  const yHub = await viaWay(R1, "github", { email: y, verified: true });
  if (!yHub.session) throw new Error(`C: GitHub did not sign y in: ${where(yHub)}`);
  const hubToken = yHub.session.access_token;
  const CALLBACK = "https://claude.ai/api/mcp/auth_callback";
  const reg = await call(R1, "/oauth/register", { method: "POST", body: { client_name: "someone's own client", redirect_uris: [CALLBACK],
    token_endpoint_auth_method: "none", grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] } });
  const clientId = reg.json?.client_id;
  const verifier = b64url(randomBytes(32));
  const params = { response_type: "code", client_id: clientId, redirect_uri: CALLBACK, code_challenge: challengeOf(verifier),
    code_challenge_method: "S256", state: "s1", resource: `${R1}/api/mcp`, scope: "build" };
  const approved = await call(R1, "/api/oauth?op=approve", { method: "POST", token: hubToken, body: params });
  const code = approved.json?.redirect ? new URL(approved.json.redirect).searchParams.get("code") : null;
  const tokens = await call(R1, "/oauth/token", { method: "POST", form: { grant_type: "authorization_code", code, redirect_uri: CALLBACK,
    client_id: clientId, code_verifier: verifier, resource: `${R1}/api/mcp` } });
  const bwa = tokens.json?.access_token;
  const bwr = tokens.json?.refresh_token;
  const mcp = (token, method, p = {}, id = 1) => call(R1, "/api/mcp", { method: "POST", token,
    headers: { accept: "application/json, text/event-stream" }, body: { jsonrpc: "2.0", id, method, params: p } });
  const before = await mcp(bwa, "tools/list", {}, 1);
  holds(reg.status === 201 && /^bwa_/.test(bwa || "") && before.status === 200,
    "C0. signed in with GitHub, a client of anyone's making (RFC 7591) is approved with no code asked, and its token works",
    `${reg.status} ${approved.status} ${tokens.status} ${before.status}`);
  const unlink = await call(R1, "/api/otp?op=ways", { method: "POST", token: hubToken, body: { with: "github", on: false } });
  await wait(6000);
  const hubAfter = await call(R1, "/api/people?op=me", { token: hubToken });
  const hubRenew = await renewed(yHub.session.refresh_token);
  holds(unlink.status === 200 && unlink.json?.signed_out === true && hubAfter.status === 401 && !hubRenew.access_token,
    "C1. Unlink GitHub: GitHub's session ended, its refresh refused", `${unlink.status} ${JSON.stringify(unlink.json)} ${hubAfter.status} ${JSON.stringify(hubRenew).slice(0, 80)}`);
  const listed = await mcp(bwa, "tools/list", {}, 2);
  const rotated = await call(R1, "/oauth/token", { method: "POST", form: { grant_type: "refresh_token", refresh_token: bwr, client_id: clientId,
    resource: `${R1}/api/mcp` } });
  // The person comes back by code, and switches the connector on in their tab, for their own Claude.
  const ySelf = await mintSession(y, { age: true });
  const tab = `/api/mcp?t=${b64url(randomBytes(32))}&i=signreview2tab`;
  const hello = await call(R1, `${tab}&op=hello`, { method: "POST", token: ySelf.access_token,
    body: { instructions: "the person's own tab", tools: [{ name: "search_parts", description: "", inputSchema: {} }] } });
  const asked = mcp(rotated.json?.access_token || bwa, "tools/call", { name: "search_parts", arguments: { query: "after unlink" } }, 3);
  let taken = null;
  for (let n = 0; n < 6 && !taken; n += 1) {
    const next = await call(R1, `${tab}&op=next`, { method: "POST" });
    if (next.json?.request?.method === "tools/call") taken = next.json;
  }
  if (taken) {
    await call(R1, `${tab}&op=answer&id=${taken.id}`, { method: "POST",
      body: { jsonrpc: "2.0", id: taken.request.id, result: { content: [{ type: "text", text: "answered" }] } } });
  }
  const answer = await asked.catch(() => null);
  await call(R1, `${tab}&op=close`, { method: "POST" }).catch(() => null);
  const listedInSettings = await call(R1, "/api/oauth?op=connections", { token: ySelf.access_token });
  console.log(`  --      the call's answer reached the connector: ${(answer?.json?.result?.content || []).some((b) => /answered/.test(b.text || ""))}; `
    + `Settings lists the connection: ${JSON.stringify(listedInSettings.json).includes("someone's own client")} (${listedInSettings.status})`);
  const survived = listed.status === 200 && rotated.status === 200;
  say(survived ? "FINDING" : "ok",
    "C2. after that Unlink, the connection approved from GitHub's session still works, renews, and reaches the person's own tab",
    `tools/list ${listed.status}; refresh ${rotated.status} (${/^bwr_/.test(rotated.json?.refresh_token || "") ? "a new pair" : "none"}); `
    + `the person's tab on (${hello.status}) was handed the call: ${taken?.request?.params?.arguments?.query === "after unlink"}`);

  // ------------------------------------------------------------------ D
  console.log("D. the new functions and tables from the browser's keys");
  const z = address("authed");
  made.push(z);
  const zSession = await mintSession(z, { age: true });
  const someone = randomUUID();
  const calls = [
    ["way_links_of", { account: someone }], ["way_set", { account: someone, way: "google", turned_on: false }],
    ["way_bind", { account: someone, way: "github", provider_id: "1" }],
    ["way_signed_in", { session: randomUUID(), account: someone, way: "google", provider_id: null, bind: false }],
    ["way_may_try", { try_key: "sr2", per: 0, window_minutes: 15 }],
  ];
  for (const [name, body] of calls) {
    const anon = await rpcAs(ANON, null, name, body);
    const authed = await rpcAs(ANON, zSession.access_token, name, body);
    holds([401, 403, 404].includes(anon.status) && [401, 403, 404].includes(authed.status),
      `D1. rpc/${name}: anon ${anon.status} ${anon.code}, signed in ${authed.status} ${authed.code}`, `${anon.text} | ${authed.text}`);
  }
  for (const table of ["way_links", "way_attempts", "way_sessions"]) {
    const anon = await fetch(`${SB}/rest/v1/${table}?select=*&limit=1`, { headers: { apikey: ANON } });
    const authed = await fetch(`${SB}/rest/v1/${table}?select=*&limit=1`, { headers: { apikey: ANON, authorization: `Bearer ${zSession.access_token}` } });
    const [a, b] = [await anon.text(), await authed.text()];
    holds(!(anon.ok && a.startsWith("[{")) && !(authed.ok && b.startsWith("[{")), `D2. ${table}: anon ${anon.status}, signed in ${authed.status}, no rows`,
      `${a.slice(0, 100)} | ${b.slice(0, 100)}`);
  }
  const yAccount = ySelf.kept.user_id;
  const peek = await call(R1, `/api/otp?op=ways&account=${yAccount}`, { token: zSession.access_token });
  const poke = await call(R1, "/api/otp?op=ways", { method: "POST", token: zSession.access_token,
    body: { with: "google", on: false, account: yAccount, sub: yAccount } });
  const yLinks = await serverRpc("way_links_of", { account: yAccount });
  const zLinks = await serverRpc("way_links_of", { account: zSession.kept.user_id });
  holds(peek.json?.github === "never" && yLinks?.github?.state === "off" && !yLinks?.google && zLinks?.google?.state === "off",
    "D3. ?op=ways naming another account reads and changes only the caller's own", `${JSON.stringify(peek.json)} ${poke.status} ${JSON.stringify(yLinks)} ${JSON.stringify(zLinks)}`);
} catch (trouble) {
  say("FAIL", "the attack finished", String(trouble?.stack || trouble).slice(0, 600));
} finally {
  let left = 0;
  for (const email of made) if (!(await deleteAccount(email).catch(() => false))) left += 1;
  console.log(`  --      accounts made: ${made.length}, deleted (or never made): ${made.length - left}`);
}
console.log(`attack: ${findings} finding line(s)`);
