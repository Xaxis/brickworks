// Sign in with Google and GitHub, and the orangecheck account made around
// every sign-in (signin3, 2026-11-24), checked against the relay with
// Google, GitHub and orangecheck's Connect stood in for
// (tools/web/ways_stand_in.mjs) and the real project behind it:
//
//   set -a; . ./.env; set +a
//   OWNER=delivered+bw-ways-owner-$RANDOM@resend.dev
//   node tools/web/relay_server.mjs 11701 --ways-stand-in --owner=$OWNER &
//   node tools/web/ways_check.mjs --url=http://127.0.0.1:11701 --owner=$OWNER
//
//   1. A session minted at sign-in time counts as a sign-in for 15 minutes,
//      and no longer (api/_oc.js signedInJustNow).
//   2. A sign-in makes the person's orangecheck account once, with their
//      Brickworks id and consent; the next sign-in reuses it.
//   3. An account from before, with none, gets one at its next sign-in.
//   4. orangecheck down: the sign-in goes through all the same, and the
//      account is made at a sign-in a minute or more later.
//   5. Google: the redirect carries this deployment's client, the callback
//      address, "openid email", a fresh state, a nonce and an S256 PKCE
//      challenge, in a sealed HttpOnly cookie for its callback alone; the
//      callback signs the person with that address in to the same account
//      a code signs them in to, never a second, and hands the page the
//      session once, back where they were. A wrong state, a wrong verifier,
//      an unverified address, another site's then: each refused or tamed.
//   6. GitHub: user:email, the primary verified address, a new account made
//      for a new one, its token handed back after; a noreply or unverified
//      address refused. The age answered over 13 makes its orangecheck
//      account.
//   7. Unlinking Google: Google no longer signs in to the account, a code
//      still does; linked again, Google does.
//   8. The desktop app: back to its loopback with a sealed code only its own
//      verifier opens; any other address than 127.0.0.1 refused.
//   9. The owner's console: each one's keys and callback, its switch off and
//      on again (off, the button goes and /auth/<name> says so).
// Every account made is deleted at the end.
import { createHash, randomBytes } from "node:crypto";
import { codeFor, KEYS } from "./ways_stand_in.mjs";
import { deleteAccount, mintSession } from "./session.mjs";
import { signedInJustNow } from "../../api/_oc.js";

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

async function stand() {
  return (await call("/__ways/state")).json;
}

async function connectedOf(account) {
  const reply = await fetch(`${SB}/rest/v1/rpc/oc_connected_of`, { method: "POST",
    headers: { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" }, body: JSON.stringify({ account }) });
  return reply.ok ? reply.json() : { error: reply.status };
}

/// A sign-in by [email]'s code (the checks' password grant, as a code is,
/// for a Resend test address): a fresh session.
async function signIn(email, { age = true } = {}) {
  if (!made.includes(email)) made.push(email);
  const minted = await mintSession(email, { age });
  return { token: minted.access_token, account: minted.kept.user_id };
}

/// What Connect was asked for [account] once [ms] have passed for the
/// server's after-answer work.
async function provisionsOf(account, ms = 4000) {
  await wait(ms);
  return (await stand()).provisions.filter((one) => one.user_id === account);
}

/// A whole sign-in with [name] as [who], from /auth/<name>: {start,
/// back, took}, each the server's answer.
async function viaWay(name, who, { then = "/gallery?x=1", app = null, tamper = null } = {}) {
  const query = new URLSearchParams({ then, ...(app || {}) });
  const start = await call(`/auth/${name}?${query}`);
  const startCookie = cookieNamed(start.cookies, `bw_way_${name}`);
  if (start.status !== 302 || !/^https:\/\//.test(start.location)) return { start };
  let code = codeFor(start.location, who);
  let state = new URL(start.location).searchParams.get("state");
  if (tamper === "state") state = `${state}x`;
  if (tamper === "verifier") code = codeFor(start.location.replace(/code_challenge=[^&]+/, `code_challenge=${"A".repeat(43)}`), who);
  const back = await call(`/auth/callback/${name}?${new URLSearchParams({ code, state })}`, { cookie: valueOf(startCookie) });
  const take = cookieNamed(back.cookies, "bw_way_take");
  const took = take ? await call("/api/otp?op=way_take", { method: "POST", cookie: valueOf(take) }) : null;
  return { start, startCookie, back, take, took };
}

try {
  // 1.
  const now = Date.now();
  check("1. a sign-in a minute ago is a sign-in; one 20 minutes ago, or none, is not",
    signedInJustNow({ amr: [{ method: "otp", timestamp: now / 1000 - 60 }] }, now)
    && !signedInJustNow({ amr: [{ method: "otp", timestamp: now / 1000 - 1200 }] }, now) && !signedInJustNow({}, now));

  const offered = await call("/api/account");
  check("the deployment offers Google and GitHub, and says signing in makes the orangecheck account",
    offered.json?.ways?.google === true && offered.json?.ways?.github === true && offered.json?.orangecheck?.connect === true,
    JSON.stringify({ ways: offered.json?.ways, orangecheck: offered.json?.orangecheck }));

  // 2.
  const a = address("a");
  const first = await signIn(a);
  const said = await call("/api/account", { token: first.token });
  let asked = await provisionsOf(first.account);
  const row = await connectedOf(first.account);
  check("2. signed in by code: one ask of Connect, with the Brickworks id and consent, and its id kept with the account",
    said.status === 200 && asked.length === 1 && asked[0].consent === true && /^did:oc:[0-9a-f]{32}$/.test(row?.did || ""),
    `${said.status} ${JSON.stringify(asked)} ${JSON.stringify(row)}`);
  await call("/api/account", { token: first.token });
  const second = await signIn(a);
  await call("/api/account", { token: second.token });
  asked = await provisionsOf(first.account);
  const status = await call("/api/orangecheck?op=status", { token: second.token });
  check("2. the page read again, and a second sign-in: no second ask, the same orangecheck account, and status says it",
    asked.length === 1 && second.account === first.account && status.json?.made?.did === row?.did, `${asked.length} ${JSON.stringify(status.json)}`);

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
  const googleDown = await viaWay("google", { email: c, verified: true });
  check("4. and a sign-in with Google, orangecheck down, signs in too", googleDown.took?.status === 200
    && googleDown.took.json?.user?.id === down.account, JSON.stringify(googleDown.took));
  await call("/__ways/oc", { method: "POST", body: { mode: "up" } });
  console.log("  --    a minute for the ask to be due again");
  await wait(62000);
  const up = await signIn(c);
  await call("/api/account", { token: up.token });
  const upAsked = await provisionsOf(down.account);
  const upRow = await connectedOf(down.account);
  check("4. orangecheck back: a sign-in a minute later makes it", upAsked.length >= 2 && upAsked.at(-1).mode === "up" && Boolean(upRow?.did),
    `${JSON.stringify(upAsked)} ${JSON.stringify(upRow)}`);

  // 5.
  const google = await viaWay("google", { email: a, verified: true });
  const to = new URL(google.start.location);
  const p = to.searchParams;
  check("5. Google: to its sign-in with this deployment's client, the callback here, openid email, a state, a nonce, S256 PKCE",
    to.origin + to.pathname === "https://accounts.google.com/o/oauth2/v2/auth" && p.get("client_id") === KEYS.GOOGLE_CLIENT_ID
    && p.get("redirect_uri") === `${site}/auth/callback/google` && p.get("response_type") === "code" && p.get("scope") === "openid email"
    && /^[A-Za-z0-9_-]{22}$/.test(p.get("state") || "") && /^[A-Za-z0-9_-]{22}$/.test(p.get("nonce") || "")
    && /^[A-Za-z0-9_-]{43}$/.test(p.get("code_challenge") || "") && p.get("code_challenge_method") === "S256",
    google.start.location);
  check("5. what it carries is sealed, HttpOnly, SameSite=Lax, for the callback alone, ten minutes",
    /HttpOnly/.test(google.startCookie) && /SameSite=Lax/.test(google.startCookie) && /Path=\/auth\/callback\/google;/.test(google.startCookie)
    && /Max-Age=600/.test(google.startCookie) && !google.startCookie.includes(p.get("state")), google.startCookie);
  check("5. the callback goes back to /profile with where they were, the session handed over once, the start's cookie cleared",
    google.back.status === 302 && google.back.location === `/profile?${new URLSearchParams({ then: "/gallery?x=1", with: "google" })}`
    && /Path=\/api\/otp;/.test(google.take) && /HttpOnly/.test(google.take) && /Max-Age=120/.test(google.take)
    && google.back.cookies.some((one) => one.startsWith("bw_way_google=;") && /Max-Age=0/.test(one)), JSON.stringify(google.back));
  check("5. the same address a code signs in: the same account, never a second", google.took?.status === 200
    && google.took.json?.user?.id === first.account && google.took.json?.new_account === false && google.took.json?.with === "google"
    && google.took.json?.access_token, JSON.stringify({ ...google.took?.json, access_token: undefined, refresh_token: undefined }));
  const took = await call("/api/otp?op=way_take", { method: "POST" });
  check("5. with nothing to take, way_take says so", took.status === 410 && /took too long/.test(took.json?.error || ""), JSON.stringify(took));
  await call("/api/account", { token: google.took?.json?.access_token });
  check("5. signed in with Google, its orangecheck account is the one it had: no second ask",
    (await provisionsOf(first.account)).length === 1);
  const ways = await call("/api/otp?op=ways", { token: google.took?.json?.access_token });
  check("5. Settings: a code, and Google, sign this account in; GitHub not yet", ways.json?.code === true && ways.json?.google === "on"
    && ways.json?.github === "never", JSON.stringify(ways.json));
  const badState = await viaWay("google", { email: a, verified: true }, { tamper: "state" });
  check("5. a state not its own: refused, to sign in again", badState.back.status === 302 && /failed=again/.test(badState.back.location)
    && !badState.take, badState.back.location);
  const badVerifier = await viaWay("google", { email: a, verified: true }, { tamper: "verifier" });
  check("5. a code for another PKCE challenge: Google refuses it, and so does the sign-in", /failed=failed/.test(badVerifier.back.location)
    && !badVerifier.take, badVerifier.back.location);
  const unverified = await viaWay("google", { email: address("unverified"), verified: false });
  check("5. an address Google has not verified: refused in words, no account made", /failed=unverified/.test(unverified.back.location)
    && !unverified.take, unverified.back.location);
  const elsewhere = await viaWay("google", { email: a, verified: true }, { then: "//evil.example/x" });
  check("5. another site's address to go back to: back to this site's home", elsewhere.back.location === "/profile?then=%2F&with=google",
    elsewhere.back.location);

  // 6.
  const d = address("d");
  made.push(d);
  const hub = await viaWay("github", { email: d, verified: true }, { then: "/settings" });
  const hubTo = new URL(hub.start.location);
  check("6. GitHub: to its sign-in with this client, the callback, user:email, a state, S256 PKCE", hubTo.origin + hubTo.pathname
    === "https://github.com/login/oauth/authorize" && hubTo.searchParams.get("client_id") === KEYS.GITHUB_CLIENT_ID
    && hubTo.searchParams.get("redirect_uri") === `${site}/auth/callback/github` && hubTo.searchParams.get("scope") === "user:email"
    && hubTo.searchParams.get("code_challenge_method") === "S256", hub.start.location);
  check("6. a new address: a new account, signed in", hub.took?.status === 200 && hub.took.json?.new_account === true
    && hub.took.json?.user?.email === d, JSON.stringify({ ...hub.took?.json, access_token: undefined, refresh_token: undefined }));
  await wait(1500);
  check("6. GitHub's token handed back once the address was read", (await stand()).revoked.length >= 1);
  const hubToken = hub.took?.json?.access_token;
  const hubAccount = hub.took?.json?.user?.id;
  await call("/api/account", { token: hubToken });
  check("6. its age not answered yet: no orangecheck account asked for", (await provisionsOf(hubAccount, 2500)).length === 0);
  const aged = await call("/api/account?op=age", { method: "POST", token: hubToken, body: { month: 1, year: new Date().getUTCFullYear() - 30 } });
  const hubAsked = await provisionsOf(hubAccount);
  check("6. answered over 13: its orangecheck account made, the GitHub address sent as verified", aged.status === 200
    && hubAsked.length === 1 && hubAsked[0].email === d && hubAsked[0].email_verified === true, `${aged.status} ${JSON.stringify(hubAsked)}`);
  const noreply = await viaWay("github", { emails: [{ email: "12345+someone@users.noreply.github.com", primary: true, verified: true }] });
  check("6. a GitHub noreply address: refused", /failed=unverified/.test(noreply.back.location), noreply.back.location);
  const unverifiedHub = await viaWay("github", { emails: [{ email: address("hubunv"), primary: true, verified: false },
    { email: address("hubother"), primary: false, verified: true }] });
  check("6. a primary address GitHub has not verified: refused, not another one taken", /failed=unverified/.test(unverifiedHub.back.location),
    unverifiedHub.back.location);

  // 7.
  const off = await call("/api/otp?op=ways", { method: "POST", token: second.token, body: { with: "google", on: false } });
  const refused = await viaWay("google", { email: a, verified: true });
  const code = await signIn(a);
  check("7. Google unlinked: it no longer signs this account in, a code still does", off.json?.google === "off"
    && /failed=unlinked/.test(refused.back.location) && !refused.take && code.account === first.account,
    `${JSON.stringify(off.json)} ${refused.back.location}`);
  const on = await call("/api/otp?op=ways", { method: "POST", token: code.token, body: { with: "google", on: true } });
  const again = await viaWay("google", { email: a, verified: true });
  check("7. linked again: Google signs it in", on.json?.google === "never" && again.took?.json?.user?.id === first.account,
    `${JSON.stringify(on.json)} ${again.back.location}`);

  // 8.
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const loop = "http://127.0.0.1:45678/oc/callback";
  const app = await viaWay("github", { email: d, verified: true }, { app: { app: loop, state: "appstate12345", code_challenge: challenge } });
  const home = new URL(app.back.location || "http://x/");
  const appCode = home.searchParams.get("code") || "";
  const wrong = await call("/api/otp?op=way_app", { method: "POST", body: { code: appCode, code_verifier: randomBytes(32).toString("base64url") } });
  const right = await call("/api/otp?op=way_app", { method: "POST", body: { code: appCode, code_verifier: verifier } });
  check("8. the app: back to its loopback with its state and a sealed code; only its own verifier opens it",
    home.origin + home.pathname === loop && home.searchParams.get("state") === "appstate12345" && !app.take
    && wrong.status === 410 && right.status === 200 && right.json?.user?.id === hubAccount, `${app.back.location.slice(0, 80)} ${wrong.status} ${right.status}`);
  const notLoop = await call(`/auth/github?${new URLSearchParams({ app: "https://evil.example/cb", state: "appstate12345", code_challenge: challenge })}`);
  check("8. any app address but 127.0.0.1: refused", notLoop.status === 422, String(notLoop.status));

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
    const startOff = await call("/auth/google?then=/gallery");
    check("9. switched off: not offered, and /auth/google says so", offNow.status === 200 && gone.json?.ways?.google === false
      && /failed=off/.test(startOff.location), `${offNow.status} ${JSON.stringify(gone.json?.ways)} ${startOff.location}`);
    const onNow = await call("/api/admin?op=sign_in_switch", { method: "POST", token: boss.access_token, body: { with: "google", on: true } });
    check("9. switched on again: offered", onNow.status === 200 && (await call("/api/account")).json?.ways?.google === true, String(onNow.status));
    const nobody = await call("/api/admin?op=sign_in_switch", { method: "POST", token: second.token, body: { with: "google", on: false } });
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
