// Sign in with Google and GitHub, and the orangecheck account made around
// every sign-in (signin3, 2026-11-24, and its review's fixes), checked
// against the relay with Google, GitHub and orangecheck's Connect stood in
// for (tools/web/ways_stand_in.mjs) and the real project behind it:
//
//   set -a; . ./.env; set +a
//   OWNER=delivered+bw-ways-owner-$RANDOM@resend.dev
//   node tools/web/relay_server.mjs 11701 --ways-stand-in --owner=$OWNER &
//   node tools/web/ways_check.mjs --url=http://127.0.0.1:11701 --owner=$OWNER
//
//   1. A session minted at sign-in time counts as a sign-in for 15 minutes,
//      and no longer (api/_oc.js signedInJustNow); Google vouches for Gmail
//      and a Workspace address of its own hd alone (googleVouches).
//   2. A code's sign-in makes the person's orangecheck account once, with
//      their Brickworks id, consent and the address as verified; the next
//      sign-in reuses it. Six first requests at once ask Connect once (F6).
//   3. An account from before, with none, gets one at its next sign-in.
//   4. orangecheck down: the sign-in goes through all the same, and the
//      account is made at a sign-in a minute or more later.
//   5. Google: the redirect carries this deployment's client, the callback
//      address, "openid email", a fresh state, a nonce and an S256 PKCE
//      challenge, in a sealed HttpOnly cookie for its callback alone; a
//      start with no page challenge goes nowhere. The callback signs the
//      person with that address in to the same account a code signs them in
//      to, never a second, and hands the session over once, to the page's
//      own verifier alone (F1, F4). Its session is not a code's (F2). A
//      wrong state, a wrong verifier, an unverified address, an address
//      Google is not the authority for (F3), another site's then: each
//      refused or tamed.
//   6. GitHub: user:email, the primary verified address, a new account made
//      for a new one, its token handed back after; a noreply, unverified or
//      not plain ASCII address refused (F5). Its address goes to orangecheck
//      as unchecked (F2). To an account it has not signed in to, it asks a
//      code to the address first, then keeps GitHub's id (F3).
//   7. The desktop app: back to its loopback with a sealed code only its own
//      verifier opens, once; never at the page's take (F1); any other
//      address than 127.0.0.1 refused.
//   8. Unlinking: Google no longer signs in, a code still does, linked again
//      Google does. GitHub unlinked ends every session it started, this one
//      too (F2); unlinking during sign-ins leaves none of theirs alive (F7).
//   9. The owner's console: each one's keys and callback, its switch off and
//      on again (off, the button goes and /auth/<name> says so).
// Every account made is deleted at the end.
import { createHash, randomBytes } from "node:crypto";
import { codeFor, githubId, KEYS } from "./ways_stand_in.mjs";
import { deleteAccount, mintCode, mintSession } from "./session.mjs";
import { signedInJustNow } from "../../api/_oc.js";
import { googleVouches } from "../../api/_ways.js";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const site = arg("url", "http://127.0.0.1:11701").replace(/\/+$/, "");
const owner = arg("owner");
const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const secret = process.env.SUPABASE_SECRET_KEY || "";
let failed = 0;
const check = (what, ok, detail = "") => {
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${ok || !detail ? "" : `: ${String(detail).slice(0, 600)}`}`);
};
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-ways-${name}-${tag}@resend.dev`;
const made = [];
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
// Google, for a throwaway at resend.dev: as Google says it of a Workspace
// account of that domain, the only way Google vouches for it.
const workspace = (email) => ({ email, verified: true, hd: "resend.dev" });

async function call(path, { method = "GET", token = "", body, cookie = "" } = {}) {
  const reply = await fetch(`${site}${path}`, { method, redirect: "manual",
    headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...(body ? { "content-type": "application/json" } : {}),
      ...(cookie ? { cookie } : {}) }, body: body ? JSON.stringify(body) : undefined });
  const text = await reply.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: reply.status, json, location: reply.headers.get("location") || "", cookies: reply.headers.getSetCookie?.() || [] };
}

const cookieNamed = (cookies, name) => cookies.find((one) => one.startsWith(`${name}=`)) || "";
const valueOf = (cookie) => cookie.split(";")[0];
const sessionIdOf = (jwt) => {
  try {
    return JSON.parse(Buffer.from(String(jwt).split(".")[1], "base64url").toString()).session_id || "";
  } catch {
    return "";
  }
};

async function stand() {
  return (await call("/__ways/state")).json;
}

async function rpc(name, body) {
  const reply = await fetch(`${SB}/rest/v1/rpc/${name}`, { method: "POST",
    headers: { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" }, body: JSON.stringify(body) });
  return reply.ok ? reply.json() : { error: reply.status };
}

const connectedOf = (account) => rpc("oc_connected_of", { account });

async function record(account) {
  const reply = await fetch(`${SB}/auth/v1/admin/users/${account}`, { headers: { apikey: secret, authorization: `Bearer ${secret}` } });
  return reply.ok ? (await reply.json()).app_metadata || {} : null;
}

async function renews(refresh) {
  const reply = await fetch(`${SB}/auth/v1/token?grant_type=refresh_token`, { method: "POST",
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" }, body: JSON.stringify({ refresh_token: refresh }) });
  return reply.ok;
}

/// A sign-in by [email]'s password (the checks' grant for a Resend test
/// address): a session, the account made and its age answered.
async function signIn(email, { age = true } = {}) {
  if (!made.includes(email)) made.push(email);
  const minted = await mintSession(email, { age });
  return { token: minted.access_token, refresh: minted.kept.refresh_token, account: minted.kept.user_id };
}

/// A sign-in by a code to [email], minted and redeemed as the dialog's is:
/// amr otp, as an emailed code's session is. The account made first.
async function codeSignIn(email) {
  await signIn(email);
  const code = await mintCode(email, { welcome: false });
  const reply = await fetch(`${SB}/auth/v1/verify`, { method: "POST",
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
    body: JSON.stringify({ type: "email", email, token: code }) });
  const body = await reply.json().catch(() => ({}));
  if (!body.access_token) throw new Error(`the code would not redeem: ${reply.status}`);
  return { token: body.access_token, refresh: body.refresh_token, account: body.user?.id };
}

/// What Connect was asked for [account] once [ms] have passed for the
/// server's after-answer work.
async function provisionsOf(account, ms = 4000) {
  await wait(ms);
  return (await stand()).provisions.filter((one) => one.user_id === account);
}

/// A whole sign-in with [name] as [who], from /auth/<name>, as the page
/// makes it: its own verifier, whose challenge goes as take=, given back at
/// way_take. {start, back, take, took, verifier}, each the server's answer.
async function viaWay(name, who, { then = "/gallery?x=1", app = null, tamper = null, taking = true } = {}) {
  const verifier = b64url(randomBytes(32));
  const query = new URLSearchParams({ then, ...(app || { take: challengeOf(verifier) }) });
  const start = await call(`/auth/${name}?${query}`);
  const startCookie = cookieNamed(start.cookies, `bw_way_${name}`);
  for (const one of [who.email, ...((who.emails || []).map((e) => e.email))]) if (one && !made.includes(one.toLowerCase())) made.push(one.toLowerCase());
  if (start.status !== 302 || !/^https:\/\//.test(start.location)) return { start };
  let code = codeFor(start.location, who);
  let state = new URL(start.location).searchParams.get("state");
  if (tamper === "state") state = `${state}x`;
  if (tamper === "verifier") code = codeFor(start.location.replace(/code_challenge=[^&]+/, `code_challenge=${"A".repeat(43)}`), who);
  const back = await call(`/auth/callback/${name}?${new URLSearchParams({ code, state })}`, { cookie: valueOf(startCookie) });
  const take = cookieNamed(back.cookies, "bw_way_take");
  const took = take && taking ? await call("/api/otp?op=way_take", { method: "POST", cookie: valueOf(take), body: { code_verifier: verifier } }) : null;
  return { start, startCookie, back, take, took, verifier, bind: cookieNamed(back.cookies, "bw_way_bind") };
}

try {
  // 1.
  const now = Date.now();
  check("1. a sign-in a minute ago is a sign-in; one 20 minutes ago, or none, is not",
    signedInJustNow({ amr: [{ method: "otp", timestamp: now / 1000 - 60 }] }, now)
    && !signedInJustNow({ amr: [{ method: "otp", timestamp: now / 1000 - 1200 }] }, now) && !signedInJustNow({}, now));
  check("1. Google vouches for Gmail, Googlemail and a Workspace address of its own hd; not Outlook, another hd, none, a subdomain",
    googleVouches("a@gmail.com") && googleVouches("a@googlemail.com") && googleVouches("a@corp.example", "corp.example")
    && !googleVouches("a@outlook.com") && !googleVouches("a@corp.example", "other.example") && !googleVouches("a@corp.example", "")
    && !googleVouches("a@sub.corp.example", "corp.example"));

  const offered = await call("/api/account");
  check("the deployment offers Google and GitHub, and says signing in makes the orangecheck account",
    offered.json?.ways?.google === true && offered.json?.ways?.github === true && offered.json?.orangecheck?.connect === true,
    JSON.stringify({ ways: offered.json?.ways, orangecheck: offered.json?.orangecheck }));

  // 2.
  const a = address("a");
  const first = await codeSignIn(a);
  const said = await call("/api/account", { token: first.token });
  let asked = await provisionsOf(first.account);
  const row = await connectedOf(first.account);
  check("2. signed in by a code: one ask of Connect, with the Brickworks id, consent and the address as verified, its id kept",
    said.status === 200 && asked.length === 1 && asked[0].consent === true && asked[0].email === a && asked[0].email_verified === true
    && /^did:oc:[0-9a-f]{32}$/.test(row?.did || ""), `${said.status} ${JSON.stringify(asked)} ${JSON.stringify(row)}`);
  const codeStatus = await call("/api/orangecheck?op=status", { token: first.token });
  check("2. a code's session is fresh, as linking orangecheck asks", codeStatus.json?.fresh === true, JSON.stringify(codeStatus.json));
  await call("/api/account", { token: first.token });
  const second = await signIn(a);
  await call("/api/account", { token: second.token });
  asked = await provisionsOf(first.account);
  const status = await call("/api/orangecheck?op=status", { token: second.token });
  check("2. the page read again, and a second sign-in: no second ask, the same orangecheck account, and status says it",
    asked.length === 1 && second.account === first.account && status.json?.made?.did === row?.did, `${asked.length} ${JSON.stringify(status.json)}`);
  const six = address("six");
  const sixIn = await codeSignIn(six);
  const sixSaid = await Promise.all(Array.from({ length: 6 }, () => call("/api/account", { token: sixIn.token })));
  const sixAsked = await provisionsOf(sixIn.account, 5000);
  check("2. six first requests of a sign-in at once: Connect asked once (F6)", sixSaid.every((one) => one.status === 200)
    && sixAsked.length === 1, `${sixSaid.map((one) => one.status)} ${sixAsked.length} asks`);

  // 3.
  const b = address("b");
  const before = await signIn(b);
  const none = await connectedOf(before.account);
  const next = await signIn(b);
  await call("/api/account", { token: next.token });
  const later = await provisionsOf(before.account);
  const rowB = await connectedOf(before.account);
  check("3. an account from before with none (never read by the site) gets one at its next sign-in",
    none === null && later.length === 1 && Boolean(rowB?.did), `${JSON.stringify(none)} ${later.length} ${JSON.stringify(rowB)}`);

  // 4.
  await call("/__ways/oc", { method: "POST", body: { mode: "down" } });
  const c = address("c");
  const down = await signIn(c);
  const downSaid = await call("/api/account", { token: down.token });
  const me = await call("/api/people?op=me", { token: down.token });
  const downAsked = await provisionsOf(down.account);
  const downRow = await connectedOf(down.account);
  check("4. orangecheck down: signed in all the same, its one ask failed, no id kept",
    downSaid.status === 200 && me.status === 200 && downAsked.length === 1 && downAsked[0].mode === "down" && !downRow?.did,
    `${downSaid.status} ${me.status} ${JSON.stringify(downAsked)} ${JSON.stringify(downRow)}`);
  const googleDown = await viaWay("google", workspace(c));
  check("4. and a sign-in with Google, orangecheck down, signs in too", googleDown.took?.status === 200
    && googleDown.took.json?.user?.id === down.account, JSON.stringify(googleDown.took));
  await call("/__ways/oc", { method: "POST", body: { mode: "up" } });
  console.log("  --    a minute for the ask to be due again");
  await wait(62000);
  const up = await signIn(c);
  const upSaid = await call("/api/account", { token: up.token });
  // The ask runs after the answer: given ten seconds on a loaded box.
  let upAsked = [];
  for (let n = 0; n < 10 && !(upAsked.length >= 2); n += 1) upAsked = await provisionsOf(down.account, 1000);
  const upRow = await connectedOf(down.account);
  check("4. orangecheck back: a sign-in a minute later makes it", upAsked.length >= 2 && upAsked.at(-1).mode === "up" && Boolean(upRow?.did),
    `${upSaid.status} ${JSON.stringify(upSaid.json?.age)} ${JSON.stringify(upAsked)} ${JSON.stringify(upRow)}`);

  // 5.
  const google = await viaWay("google", workspace(a), { taking: false });
  const to = new URL(google.start.location);
  const p = to.searchParams;
  check("5. Google: to its sign-in with this deployment's client, the callback here, openid email, a state, a nonce, S256 PKCE",
    to.origin + to.pathname === "https://accounts.google.com/o/oauth2/v2/auth" && p.get("client_id") === KEYS.GOOGLE_CLIENT_ID
    && p.get("redirect_uri") === `${site}/auth/callback/google` && p.get("response_type") === "code" && p.get("scope") === "openid email"
    && /^[A-Za-z0-9_-]{22}$/.test(p.get("state") || "") && /^[A-Za-z0-9_-]{22}$/.test(p.get("nonce") || "")
    && /^[A-Za-z0-9_-]{43}$/.test(p.get("code_challenge") || "") && p.get("code_challenge_method") === "S256"
    && p.get("code_challenge") !== challengeOf(google.verifier), google.start.location);
  check("5. what it carries is sealed, HttpOnly, SameSite=Lax, for the callback alone, ten minutes",
    /HttpOnly/.test(google.startCookie) && /SameSite=Lax/.test(google.startCookie) && /Path=\/auth\/callback\/google;/.test(google.startCookie)
    && /Max-Age=600/.test(google.startCookie) && !google.startCookie.includes(p.get("state")), google.startCookie);
  const pageChallenge = challengeOf(google.verifier);
  check("5. the callback goes back to /profile with where they were and the page's challenge, the session in a cookie, the start's cleared",
    google.back.status === 302 && google.back.location === `/profile?${new URLSearchParams({ then: "/gallery?x=1", with: "google", take: pageChallenge })}`
    && /Path=\/api\/otp;/.test(google.take) && /HttpOnly/.test(google.take) && /Max-Age=120/.test(google.take)
    && google.back.cookies.some((one) => one.startsWith("bw_way_google=;") && /Max-Age=0/.test(one)), JSON.stringify(google.back));
  const noVerifier = await call("/api/otp?op=way_take", { method: "POST", cookie: valueOf(google.take) });
  const wrongVerifier = await call("/api/otp?op=way_take", { method: "POST", cookie: valueOf(google.take),
    body: { code_verifier: b64url(randomBytes(32)) } });
  const taken = await call("/api/otp?op=way_take", { method: "POST", cookie: valueOf(google.take), body: { code_verifier: google.verifier } });
  const replayed = await call("/api/otp?op=way_take", { method: "POST", cookie: valueOf(google.take), body: { code_verifier: google.verifier } });
  check("5. the cookie alone, or with another verifier, opens nothing; with the page's own it does, once (F1, F4)",
    noVerifier.status === 410 && wrongVerifier.status === 410 && taken.status === 200 && replayed.status === 410,
    `${noVerifier.status} ${wrongVerifier.status} ${taken.status} ${replayed.status}`);
  check("5. the same address a code signs in: the same account, never a second", taken.json?.user?.id === first.account
    && taken.json?.new_account === false && taken.json?.with === "google" && taken.json?.access_token,
    JSON.stringify({ ...taken.json, access_token: undefined, refresh_token: undefined }));
  const noTake = await call(`/auth/google?${new URLSearchParams({ then: "/gallery" })}`);
  check("5. a start with no page challenge goes nowhere near Google", noTake.status === 302 && /failed=again/.test(noTake.location)
    && !/accounts\.google/.test(noTake.location), noTake.location);
  const took = await call("/api/otp?op=way_take", { method: "POST", body: { code_verifier: google.verifier } });
  check("5. with nothing to take, way_take says so", took.status === 410 && /took too long/.test(took.json?.error || ""), JSON.stringify(took));
  const googleToken = taken.json?.access_token;
  await call("/api/account", { token: googleToken });
  check("5. signed in with Google, its orangecheck account is the one it had: no second ask",
    (await provisionsOf(first.account)).length === 1);
  const googleStatus = await call("/api/orangecheck?op=status", { token: googleToken });
  check("5. a Google session is not a code just emailed: not fresh, so linking orangecheck asks for a code (F2)",
    googleStatus.status === 200 && googleStatus.json?.fresh === false, JSON.stringify(googleStatus.json));
  const ways = await call("/api/otp?op=ways", { token: googleToken });
  check("5. Settings: a code, and Google, sign this account in; GitHub not yet", ways.json?.code === true && ways.json?.google === "on"
    && ways.json?.github === "never", JSON.stringify(ways.json));
  const badState = await viaWay("google", workspace(a), { tamper: "state" });
  check("5. a state not its own: refused, to sign in again", badState.back.status === 302 && /failed=again/.test(badState.back.location)
    && !badState.take, badState.back.location);
  const badVerifier = await viaWay("google", workspace(a), { tamper: "verifier" });
  check("5. a code for another PKCE challenge: Google refuses it, and so does the sign-in", /failed=failed/.test(badVerifier.back.location)
    && !badVerifier.take, badVerifier.back.location);
  const unverified = await viaWay("google", { email: address("unverified"), verified: false });
  check("5. an address Google has not verified: refused in words, no account made", /failed=unverified/.test(unverified.back.location)
    && !unverified.take, unverified.back.location);
  const outlook = await viaWay("google", { email: address("nohd"), verified: true });
  const otherHd = await viaWay("google", { email: address("otherhd"), verified: true, hd: "other.example" });
  const toCode = await viaWay("google", { email: a, verified: true });
  check("5. an address Google is not the authority for (no hd, another hd): refused as unvouched, even the code's own (F3)",
    [outlook, otherHd, toCode].every((one) => /failed=vouch/.test(one.back.location) && !one.take), `${outlook.back.location} ${otherHd.back.location} ${toCode.back.location}`);
  const elsewhere = await viaWay("google", workspace(a), { then: "//evil.example/x", taking: false });
  check("5. another site's address to go back to: back to this site's home",
    elsewhere.back.location === `/profile?${new URLSearchParams({ then: "/", with: "google", take: challengeOf(elsewhere.verifier) })}`,
    elsewhere.back.location);

  // 6.
  const d = address("d");
  const hub = await viaWay("github", { email: d, verified: true }, { then: "/settings" });
  const hubTo = new URL(hub.start.location);
  check("6. GitHub: to its sign-in with this client, the callback, user:email, a state, S256 PKCE", hubTo.origin + hubTo.pathname
    === "https://github.com/login/oauth/authorize" && hubTo.searchParams.get("client_id") === KEYS.GITHUB_CLIENT_ID
    && hubTo.searchParams.get("redirect_uri") === `${site}/auth/callback/github` && hubTo.searchParams.get("scope") === "user:email"
    && hubTo.searchParams.get("code_challenge_method") === "S256", hub.start.location);
  const hubAccount = hub.took?.json?.user?.id;
  check("6. a new address: a new account, signed in, GitHub's id kept with it", hub.took?.status === 200 && hub.took.json?.new_account === true
    && hub.took.json?.user?.email === d && (await record(hubAccount))?.way_github_id === String(githubId(d)),
    JSON.stringify({ ...hub.took?.json, access_token: undefined, refresh_token: undefined }));
  await wait(1500);
  check("6. GitHub's token handed back once the address was read", (await stand()).revoked.length >= 1);
  const hubToken = hub.took?.json?.access_token;
  await call("/api/account", { token: hubToken });
  check("6. its age not answered yet: no orangecheck account asked for", (await provisionsOf(hubAccount, 2500)).length === 0);
  const aged = await call("/api/account?op=age", { method: "POST", token: hubToken, body: { month: 1, year: new Date().getUTCFullYear() - 30 } });
  const hubAsked = await provisionsOf(hubAccount);
  check("6. answered over 13: its orangecheck account made, the GitHub address sent as one orangecheck has to check (F2)", aged.status === 200
    && hubAsked.length === 1 && hubAsked[0].email === d && hubAsked[0].email_verified === false, `${aged.status} ${JSON.stringify(hubAsked)}`);
  const hubStatus = await call("/api/orangecheck?op=status", { token: hubToken });
  check("6. a GitHub session is not fresh either (F2)", hubStatus.json?.fresh === false, JSON.stringify(hubStatus.json));
  const noreply = await viaWay("github", { emails: [{ email: "12345+someone@users.noreply.github.com", primary: true, verified: true }] });
  check("6. a GitHub noreply address: refused", /failed=unverified/.test(noreply.back.location), noreply.back.location);
  const unverifiedHub = await viaWay("github", { emails: [{ email: address("hubunv"), primary: true, verified: false },
    { email: address("hubother"), primary: false, verified: true }] });
  check("6. a primary address GitHub has not verified: refused, not another one taken", /failed=unverified/.test(unverifiedHub.back.location),
    unverifiedHub.back.location);
  const k = address("kelvin");
  const kIn = await signIn(k);
  const kelvin = await viaWay("github", { email: k.replace("kelvin", "Kelvin"), verified: true });
  check("6. an address with a letter that lowercases into ASCII (U+212A): refused, never the plain address's account (F5)",
    /failed=unverified/.test(kelvin.back.location) && !kelvin.take && Boolean(kIn.account), kelvin.back.location);
  const e = address("e");
  const eCode = await signIn(e);
  const eHub = await viaWay("github", { email: e, verified: true }, { then: "/settings" });
  check("6. GitHub to an account a code made: nothing handed out, a code asked first, GitHub's id waiting sealed (F3)",
    eHub.back.location === `/profile?${new URLSearchParams({ "sign-in": "", then: "/settings", with: "github", failed: "confirm" })}`
    && !eHub.take && /Path=\/api\/otp;/.test(eHub.bind) && /HttpOnly/.test(eHub.bind) && /Max-Age=900/.test(eHub.bind)
    && !(await record(eCode.account))?.way_github, `${eHub.back.location} ${eHub.bind.slice(0, 40)}`);
  const stale = await call("/api/otp?op=way_bind", { method: "POST", token: eCode.token, cookie: valueOf(eHub.bind) });
  const stranger = await call("/api/otp?op=way_bind", { method: "POST", token: second.token, cookie: valueOf(eHub.bind) });
  const eFresh = await codeSignIn(e);
  const bound = await call("/api/otp?op=way_bind", { method: "POST", token: eFresh.token, cookie: valueOf(eHub.bind) });
  const boundAgain = await call("/api/otp?op=way_bind", { method: "POST", token: eFresh.token, cookie: valueOf(eHub.bind) });
  check("6. kept only for that account, after a code just now: a password's session 403, another account's 410, the code's 200, once",
    stale.status === 403 && stale.json?.fresh === false && stranger.status === 410 && bound.status === 200 && boundAgain.status === 410
    && (await record(eCode.account))?.way_github_id === String(githubId(e)), `${stale.status} ${stranger.status} ${bound.status} ${boundAgain.status}`);
  const eAgain = await viaWay("github", { email: e, verified: true });
  const eOther = await viaWay("github", { email: e, verified: true, id: githubId(e) + 1 });
  check("6. then GitHub signs it in; another GitHub account with the same address asks a code again",
    eAgain.took?.json?.user?.id === eCode.account && /failed=confirm/.test(eOther.back.location) && !eOther.take,
    `${eAgain.back.location} ${eOther.back.location}`);

  // 7.
  const verifier = b64url(randomBytes(32));
  const challenge = challengeOf(verifier);
  const loop = "http://127.0.0.1:45678/oc/callback";
  const app = await viaWay("github", { email: d, verified: true }, { app: { app: loop, state: "appstate12345", code_challenge: challenge } });
  const home = new URL(app.back.location || "http://x/");
  const appCode = home.searchParams.get("code") || "";
  const asTake = await call("/api/otp?op=way_take", { method: "POST", cookie: `bw_way_take=${appCode}`, body: { code_verifier: verifier } });
  const wrong = await call("/api/otp?op=way_app", { method: "POST", body: { code: appCode, code_verifier: b64url(randomBytes(32)) } });
  const right = await call("/api/otp?op=way_app", { method: "POST", body: { code: appCode, code_verifier: verifier } });
  const twice = await call("/api/otp?op=way_app", { method: "POST", body: { code: appCode, code_verifier: verifier } });
  check("7. the app: back to its loopback with its state and a sealed code; only its own verifier opens it, once (F4)",
    home.origin + home.pathname === loop && home.searchParams.get("state") === "appstate12345" && !app.take
    && wrong.status === 410 && right.status === 200 && right.json?.user?.id === hubAccount && twice.status === 410,
    `${app.back.location.slice(0, 80)} ${wrong.status} ${right.status} ${twice.status}`);
  check("7. the app's code sent as the page's cookie, even with its verifier: refused (F1)", asTake.status === 410, String(asTake.status));
  const notLoop = await call(`/auth/github?${new URLSearchParams({ app: "https://evil.example/cb", state: "appstate12345", code_challenge: challenge })}`);
  check("7. any app address but 127.0.0.1: refused", notLoop.status === 422, String(notLoop.status));

  // 8.
  const off = await call("/api/otp?op=ways", { method: "POST", token: second.token, body: { with: "google", on: false } });
  const refused = await viaWay("google", workspace(a));
  const code = await signIn(a);
  check("8. Google unlinked: it no longer signs this account in, a code still does", off.json?.google === "off"
    && /failed=unlinked/.test(refused.back.location) && !refused.take && code.account === first.account,
    `${JSON.stringify(off.json)} ${refused.back.location}`);
  const on = await call("/api/otp?op=ways", { method: "POST", token: code.token, body: { with: "google", on: true } });
  const again = await viaWay("google", workspace(a));
  check("8. linked again: Google signs it in", on.json?.google === "never" && again.took?.json?.user?.id === first.account,
    `${JSON.stringify(on.json)} ${again.back.location}`);
  // d: two GitHub sessions (the page's, hub, and the app's, right), then unlinked from a code's.
  const dCode = await signIn(d);
  const dOff = await call("/api/otp?op=ways", { method: "POST", token: dCode.token, body: { with: "github", on: false } });
  await wait(6000);
  const [hubMe, appMe, codeMe] = await Promise.all([hubToken, right.json?.access_token, dCode.token]
    .map((token) => call("/api/people?op=me", { token })));
  const [hubRenews, appRenews] = await Promise.all([renews(hub.took?.json?.refresh_token), renews(right.json?.refresh_token)]);
  check("8. GitHub unlinked: every session it started ends, renewals too; the code's signs on (F2)", dOff.json?.github === "off"
    && !dOff.json?.signed_out && hubMe.status === 401 && appMe.status === 401 && !hubRenews && !appRenews && codeMe.status === 200,
    `${JSON.stringify(dOff.json)} ${hubMe.status} ${appMe.status} ${hubRenews} ${appRenews} ${codeMe.status}`);
  check("8. and its id goes with it: linked again, GitHub asks a code first", !(await record(dCode.account))?.way_github_id);
  // f: signed in with GitHub, and unlinking GitHub from that very session.
  const f = address("f");
  const fHub = await viaWay("github", { email: f, verified: true });
  const fOff = await call("/api/otp?op=ways", { method: "POST", token: fHub.took?.json?.access_token, body: { with: "github", on: false } });
  const fMe = await call("/api/people?op=me", { token: fHub.took?.json?.access_token });
  check("8. unlinked from a session GitHub started: that one ends at once, and the answer says so", fOff.json?.signed_out === true
    && fMe.status === 401, `${JSON.stringify(fOff.json)} ${fMe.status}`);
  // g: GitHub sign-ins and an Unlink at once: none of their sessions is left (F7).
  const g = address("g");
  const gFirst = await viaWay("github", { email: g, verified: true });
  const gCode = await signIn(g);
  const racing = await Promise.all([
    ...Array.from({ length: 3 }, () => viaWay("github", { email: g, verified: true })),
    call("/api/otp?op=ways", { method: "POST", token: gCode.token, body: { with: "github", on: false } }),
  ]);
  const gOff = racing.pop();
  await wait(6000);
  const gSessions = [gFirst, ...racing].map((one) => one.took?.json).filter(Boolean);
  const gAlive = await Promise.all(gSessions.map(async (one) => (await call("/api/people?op=me", { token: one.access_token })).status === 200
    || await renews(one.refresh_token)));
  const gState = await call("/api/otp?op=ways", { token: gCode.token });
  check("8. three GitHub sign-ins racing an Unlink: it stays unlinked, and none of their sessions works or renews (F7)",
    gOff.json?.github === "off" && gState.json?.github === "off" && gAlive.every((alive) => !alive) && gSessions.length >= 1,
    `${gState.json?.github} ${gSessions.length} sessions, alive ${gAlive} ${racing.map((one) => one.back?.location?.slice(0, 60) || one.took?.status)}`);
  check("8. each session GitHub started was written down as GitHub's, and is gone with the Unlink",
    (await Promise.all(gSessions.map((one) => rpc("way_session_of", { session: sessionIdOf(one.access_token) })))).every((one) => one === null));

  // 9.
  if (owner) {
    made.push(owner);
    const boss = await mintSession(owner, { age: true });
    const switches = await call("/api/admin?op=switches", { token: boss.access_token });
    const listed = Object.fromEntries((switches.json?.ways || []).map((one) => [one.name, one]));
    check("9. the console: Google and GitHub, keys here, on, each with the callback to register",
      listed.google?.keys === true && listed.google?.on === true && listed.google?.callback === "https://brickworks.diy/auth/callback/google"
      && listed.github?.callback === "https://brickworks.diy/auth/callback/github"
      && ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET"]
        .every((name) => (switches.json?.variables || []).some((one) => one.name === name)), JSON.stringify(switches.json?.ways));
    const offNow = await call("/api/admin?op=sign_in_switch", { method: "POST", token: boss.access_token, body: { with: "google", on: false } });
    const gone = await call("/api/account");
    const startOff = await call(`/auth/google?then=/gallery&take=${challengeOf(b64url(randomBytes(32)))}`);
    check("9. switched off: not offered, and /auth/google says so", offNow.status === 200 && gone.json?.ways?.google === false
      && /failed=off/.test(startOff.location), `${offNow.status} ${JSON.stringify(gone.json?.ways)} ${startOff.location}`);
    const onNow = await call("/api/admin?op=sign_in_switch", { method: "POST", token: boss.access_token, body: { with: "google", on: true } });
    check("9. switched on again: offered", onNow.status === 200 && (await call("/api/account")).json?.ways?.google === true, String(onNow.status));
    const nobody = await call("/api/admin?op=sign_in_switch", { method: "POST", token: code.token, body: { with: "google", on: false } });
    check("9. anybody else: not found", nobody.status === 404, String(nobody.status));
  }
} catch (trouble) {
  check("the check finished", false, String(trouble?.stack || trouble).slice(0, 600));
} finally {
  await call("/__ways/oc", { method: "POST", body: { mode: "up" } }).catch(() => null);
  for (const email of made) await deleteAccount(email).catch(() => false);
}
console.log(`ways_check: ${failed ? `${failed} failed` : "all passed"}`);
process.exit(failed ? 1 : 0);
