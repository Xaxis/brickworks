// signreview4 (2026-11-26): what signin6 (689c8e54d) opened, against relays of that tree with Google,
// GitHub and Connect stood in for (tools/web/ways_stand_in.mjs), the real Supabase project behind them,
// and fault4.mjs between each relay and what it asks. Throwaway accounts only, all deleted.
//
//   --r       the stand-in relay (fault4 preloaded, its rules file --rules), its owner a throwaway (--owner)
//   --roc     a relay with orangecheck's keys made up and its hosts answered by fault4 (log --roclog)
//   --only    sections, default L,B,C,D,F
//
// Sections (each prints "  ok"/"  FINDING"/"  --" lines):
//   L. Link again from a session the Unlink has just ended: an intruder holding the person's Google
//      session watches the person's ways, and the moment Google reads "off" sends Link again with that
//      same session, still read as signed in for up to 5 s. Then signs in with Google again.
//   B. Supabase's verify out (429) while one person tries: each try spends one of their 10, so once it
//      is back they are refused as too often.
//   C. Faults on what hands out authority: the live session read slow past 15 s, or refused by the
//      pooler (session handed over, the console, Unlink's "you"); the exchange's reply lost after the
//      database wrote it, or refused. Each must refuse, and the person must get in once it clears.
//   D. Sessions ending: a sign-out of the approving session (a code's, a Google one), then Unlink, then
//      the account deleted: what each connection does; and a code whose session signs out before it is
//      traded.
//   F. orangecheck's app sign-in (?op=native) with made-up codes from one network: how many reach
//      orangecheck's token endpoint (signin5 counted the network before; signin6 counts nothing there).
// Supabase verifies spent from this box: about 14 (L 6, B 0, C 5, D 3, F 0), paced.
import { createHash, randomBytes } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { codeFor } from "../../../tools/web/ways_stand_in.mjs";
import { deleteAccount, mintSession } from "../../../tools/web/session.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const R = arg("r").replace(/\/+$/, "");
const ROC = arg("roc").replace(/\/+$/, "");
const RULES = arg("rules");
const ROCLOG = arg("roclog");
const OWNER = arg("owner");
const ONLY = arg("only", "L,B,C,D,F").split(",");
const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const PUB = process.env.SUPABASE_PUBLISHABLE_KEY || "";
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-sr4-${name}-${tag}@resend.dev`;
const made = [];
let findings = 0;
const say = (kind, what, detail = "") => {
  if (kind === "FINDING") findings += 1;
  console.log(`  ${kind.padEnd(7)} ${what}${detail ? `: ${String(detail).slice(0, 1200)}` : ""}`);
};
const holds = (ok, what, detail = "") => say(ok ? "ok" : "FAIL", what, detail);
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
const network = () => `198.18.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;
const qs = (o) => new URLSearchParams(o).toString();
const rules = (value) => writeFileSync(RULES, JSON.stringify(value || {}));
const failedOf = (one) => new URL(one?.back?.location || one?.location || "/", "http://x").searchParams.get("failed")
  || (one?.session ? "signed-in" : one?.taken ? `take ${one.taken.status}` : one?.back?.cookies?.some((c) => c.startsWith("bw_way_take=")) ? "handed" : "?");

async function call(site, path, { method = "GET", token = "", body, cookie = "", from = "", form, headers = {} } = {}) {
  const sent = { ...headers, ...(token ? { authorization: `Bearer ${token}` } : {}), ...(cookie ? { cookie } : {}),
    ...(from ? { "x-forwarded-for": from } : {}) };
  let payload;
  if (form) { sent["content-type"] = "application/x-www-form-urlencoded"; payload = new URLSearchParams(form).toString(); }
  else if (body !== undefined) { sent["content-type"] = "application/json"; payload = JSON.stringify(body); }
  const at = Date.now();
  const reply = await fetch(`${site}${path}`, { method, redirect: "manual", headers: sent, body: payload });
  const text = await reply.text();
  let json = null;
  try {
    json = (reply.headers.get("content-type") || "").startsWith("text/event-stream")
      ? text.split("\n").filter((l) => l.startsWith("data:")).map((l) => JSON.parse(l.slice(5))).find((m) => m.id !== undefined) || null
      : text ? JSON.parse(text) : null;
  } catch { json = null; }
  return { status: reply.status, json, text, ms: Date.now() - at, location: reply.headers.get("location") || "",
    cookies: reply.headers.getSetCookie?.() || [] };
}
const cookieNamed = (cookies, name) => (cookies.find((one) => one.startsWith(`${name}=`)) || "").split(";")[0];

async function start(site, name, from) {
  const verifier = b64url(randomBytes(32));
  const st = await call(site, `/auth/${name}?${qs({ then: "/gallery", take: challengeOf(verifier) })}`, { from });
  return { st, verifier, cookie: cookieNamed(st.cookies, `bw_way_${name}`), state: st.location.startsWith("https://")
    ? new URL(st.location).searchParams.get("state") : "" };
}
const back = (site, name, { cookie, state, code, from }) => call(site, `/auth/callback/${name}?${qs({ code, state })}`, { cookie, from });
async function takeRaw(site, reply, verifier, from) {
  const cookie = cookieNamed(reply.cookies, "bw_way_take");
  if (!cookie) return null;
  return call(site, "/api/otp?op=way_take", { method: "POST", cookie, body: { code_verifier: verifier }, from });
}
/// A whole sign-in with [name] as [who] at [site], as the page makes it; [before] runs between the
/// callback and the take (to set a fault there).
async function viaWay(site, name, who, { from = network(), before = null } = {}) {
  const s = await start(site, name, from);
  if (s.st.status !== 302 || !s.state) return { start: s.st };
  const reply = await back(site, name, { cookie: s.cookie, state: s.state, code: codeFor(s.st.location, who), from });
  if (before) await before();
  const taken = await takeRaw(site, reply, s.verifier, from);
  return { start: s.st, back: reply, taken, session: taken?.json?.access_token ? taken.json : null };
}
const googleOf = (email) => ({ email, verified: true, hd: "resend.dev" });

// Claude's connector, as a client of anyone's making (RFC 7591).
const CALLBACK = "https://claude.ai/api/mcp/auth_callback";
let clientId = "";
async function client(site) {
  if (clientId) return clientId;
  const reg = await call(site, "/oauth/register", { method: "POST", body: { client_name: "signreview4's client", redirect_uris: [CALLBACK],
    token_endpoint_auth_method: "none", grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] } });
  clientId = reg.json?.client_id || "";
  return clientId;
}
async function approve(site, token) {
  const verifier = b64url(randomBytes(32));
  const params = { response_type: "code", client_id: await client(site), redirect_uri: CALLBACK, code_challenge: challengeOf(verifier),
    code_challenge_method: "S256", state: "s4", resource: `${site}/api/mcp`, scope: "build" };
  const got = await call(site, "/api/oauth?op=approve", { method: "POST", token, body: params });
  const code = got.json?.redirect ? new URL(got.json.redirect).searchParams.get("code") : null;
  return { status: got.status, code, verifier, text: got.text.slice(0, 200) };
}
const trade = (site, { code, verifier }) => call(site, "/oauth/token", { method: "POST", form: { grant_type: "authorization_code", code,
  redirect_uri: CALLBACK, client_id: clientId, code_verifier: verifier, resource: `${site}/api/mcp` } });
const refresh = (site, bwr) => call(site, "/oauth/token", { method: "POST", form: { grant_type: "refresh_token", refresh_token: bwr,
  client_id: clientId, resource: `${site}/api/mcp` } });
const mcp = (site, token) => call(site, "/api/mcp", { method: "POST", token, headers: { accept: "application/json, text/event-stream" },
  body: { jsonrpc: "2.0", id: 1, method: "tools/list", params: {} } });
const ways = (site, token, name, on) => call(site, "/api/otp?op=ways", { method: "POST", token, body: { with: name, on } });
const waysOf = (site, token) => call(site, "/api/otp?op=ways", { token });
const connections = async (site, token) => {
  const listed = await call(site, "/api/oauth?op=connections", { token });
  return Array.isArray(listed.json?.connections) ? listed.json.connections.length : -1;
};
/// Supabase's own sign-out of one session (what the app's Sign out asks), with its access token.
const signOut = (token) => fetch(`${SB}/auth/v1/logout?scope=local`, { method: "POST",
  headers: { apikey: PUB, authorization: `Bearer ${token}` } }).then((r) => r.status);
/// A connection's standing now: tools/list and a refresh, the refresh's new tokens kept.
async function standingOf(site, pair) {
  const listed = pair.access ? (await mcp(site, pair.access)).status : 0;
  const renewed = pair.refresh ? await refresh(site, pair.refresh) : null;
  if (renewed?.status === 200) Object.assign(pair, { access: renewed.json.access_token, refresh: renewed.json.refresh_token });
  return `tools/list ${listed}, refresh ${renewed?.status ?? "-"}`;
}

try {
  rules({});
  // ------------------------------------------------------------------ L
  if (ONLY.includes("L")) {
    console.log("L. Link again, from the session the Unlink has just ended");
    const ROUNDS = Number(arg("rounds", "3"));
    let undone = 0;
    for (let round = 1; round <= ROUNDS; round += 1) {
      if (round > 1) await wait(10000);
      const p = address(`relink${round}`);
      made.push(p);
      const own = await mintSession(p, { age: true });
      const g = await viaWay(R, "google", googleOf(p));
      if (!g.session) throw new Error(`L: Google did not sign the intruder in: ${failedOf(g)}`);
      const S = g.session.access_token;
      let stop = false;
      let watched = 0;
      let relinked = null;
      const loop = (async () => {
        while (!stop) {
          const seen = await waysOf(R, S);
          watched += 1;
          if (!relinked && seen.status === 200 && seen.json?.google === "off") {
            const on = await ways(R, S, "google", true);
            relinked = { at: Date.now(), status: on.status, text: on.text.slice(0, 160) };
          }
          await wait(150);
        }
      })();
      await wait(1500);
      const sent = Date.now();
      const un = await ways(R, own.access_token, "google", false);
      const answered = Date.now();
      await wait(6000);
      stop = true;
      await loop;
      const state = (await waysOf(R, own.access_token)).json?.google;
      const sNow = (await waysOf(R, S)).status;
      const again = await viaWay(R, "google", googleOf(p));
      const back2 = Boolean(again.session);
      if (back2) undone += 1;
      say(back2 ? "FINDING" : "ok",
        `L1. round ${round}: the intruder's Google session, ended by the Unlink but still read as signed in, sends Link again; `
        + "Google then signs the intruder in again",
        `Unlink ${un.status} ${JSON.stringify(un.json)} in ${answered - sent} ms; the intruder's watch ${watched} reads; `
        + `Link again ${relinked ? `${relinked.status} ${relinked.at - answered} ms after the Unlink answered ${relinked.text}` : "never sent (google never read off)"}; `
        + `Google for the person now: ${state}; the old session now ${sNow}; Google again: ${failedOf(again)}`);
    }
    console.log(`  --      L: ${undone} of ${ROUNDS} Unlinks undone by the session they ended`);
  }

  // ------------------------------------------------------------------ B
  if (ONLY.includes("B")) {
    console.log("B. Supabase's verify out while one person tries Google");
    await wait(5000);
    const q = address("busy");
    made.push(q);
    rules({ verify429: true });
    const tries = [];
    for (let n = 0; n < 10; n += 1) tries.push(failedOf(await viaWay(R, "google", googleOf(q))));
    rules({});
    const next = await viaWay(R, "google", googleOf(q));
    say(failedOf(next) === "often" ? "FINDING" : "ok",
      "B1. ten tries while Supabase's verify answers 429 (nothing minted, \"busy\" each time): each spent one of the person's ten, "
      + "so when verify is back they are refused as too often for up to 15 minutes",
      `while out: ${[...new Set(tries)].map((f) => `${f} x${tries.filter((t) => t === f).length}`).join(", ")}; once back: ${failedOf(next)}`);
  }

  // ------------------------------------------------------------------ C
  if (ONLY.includes("C")) {
    console.log("C. faults on what hands out authority");
    await wait(10000);
    const p = address("fault");
    made.push(p);
    const own = await mintSession(p, { age: true });
    // C1, C2: the session handed over (way_take) while session_standing is slow, then refused.
    for (const [name, fault] of [["slow 16 s", { slow: { "rpc/session_standing": 16000 } }], ["the pooler's 503", { fail: { "rpc/session_standing": 503 } }]]) {
      const g = await viaWay(R, "google", googleOf(p), { before: async () => rules(fault) });
      rules({});
      holds(!g.session && g.taken && g.taken.status >= 500,
        `C1. Google's session handed over while session_standing is ${name}: refused, nothing handed over`,
        `take ${g.taken?.status} in ${g.taken?.ms} ms: ${g.taken?.text?.slice(0, 120)}`);
    }
    const good = await viaWay(R, "google", googleOf(p));
    holds(Boolean(good.session), "C2. once it clears, the person's next Google sign-in goes through (nobody is stuck)", failedOf(good));
    const S = good.session?.access_token || "";
    // C3: the console, for the relay's owner.
    if (OWNER) {
      if (!made.includes(OWNER)) made.push(OWNER);
      const o = await mintSession(OWNER, { age: true });
      const seen = [];
      for (const fault of [{ fail: { "rpc/session_standing": 503 } }, { slow: { "rpc/session_standing": 16000 } }, {}]) {
        rules(fault);
        const r = await call(R, "/api/admin?op=switches", { token: o.access_token });
        seen.push(`${Object.keys(fault)[0] || "none"} ${r.status} (${r.ms} ms)`);
      }
      rules({});
      holds(/^fail 503/.test(seen[0]) && /^slow 503/.test(seen[1]) && /^none 200/.test(seen[2]),
        "C3. the owner's console while session_standing fails, then is slow past 15 s: 503 each, and 200 once it clears", seen.join("; "));
    }
    // C4: Unlink while session_standing fails: nothing unlinked, and it works once it clears.
    rules({ fail: { "rpc/session_standing": 503 } });
    const unFail = await ways(R, own.access_token, "google", false);
    rules({});
    const stillOn = (await waysOf(R, own.access_token)).json?.google;
    holds(unFail.status >= 500 && stillOn === "on", "C4. Unlink while session_standing fails: refused (5xx), Google left on",
      `${unFail.status} ${unFail.text.slice(0, 100)}; Google now ${stillOn}`);
    // C5: the exchange's reply lost after the database wrote the connection; C6: the exchange refused by the pooler.
    await client(R);
    const before = await connections(R, own.access_token);
    const c5 = await approve(R, S);
    rules({ dropAfter: ["rpc/oauth_code_grant"] });
    const lost = await trade(R, c5);
    rules({});
    const retry = await trade(R, c5);
    const after = await connections(R, own.access_token);
    say(lost.status === 200 || retry.status === 200 ? "FAIL" : "ok",
      "C5. the exchange's reply lost after oauth_code_grant ran: Claude is told 5xx and gets no tokens; the code cannot be traded again",
      `lost ${lost.status} ${lost.json?.error || ""}; again ${retry.status} ${retry.json?.error || ""}; connections ${before} -> ${after} `
      + "(a written connection nobody holds a token of)");
    const c6 = await approve(R, S);
    rules({ fail: { "rpc/oauth_code_grant": 503 } });
    const refusedEx = await trade(R, c6);
    rules({});
    const c7 = await approve(R, S);
    const fresh = await trade(R, c7);
    const listedNow = fresh.status === 200 ? (await mcp(R, fresh.json.access_token)).status : 0;
    holds(refusedEx.status >= 500 && fresh.status === 200 && listedNow === 200,
      "C6. the exchange refused by the pooler: 5xx, nothing handed out; the person's next Connect works (nobody is stuck)",
      `refused ${refusedEx.status}; next ${fresh.status}, tools/list ${listedNow}`);
    // The written connection from C5 (no tokens anyone has) goes with Google's Unlink, as every Google one does.
    const un = await ways(R, own.access_token, "google", false);
    await wait(6000);
    const pair = { access: fresh.json?.access_token, refresh: fresh.json?.refresh_token };
    holds(un.status === 200 && (await connections(R, own.access_token)) === before,
      "C7. Unlink then ends every connection Google's session approved, the one written behind a lost reply included",
      `Unlink ${un.status}; connections now ${await connections(R, own.access_token)}; C6's: ${await standingOf(R, pair)}`);
  }

  // ------------------------------------------------------------------ D
  if (ONLY.includes("D")) {
    console.log("D. sessions ending under their connections");
    await wait(10000);
    const p = address("ends");
    made.push(p);
    await client(R);
    // D1: a code's session approves, then signs out.
    const own = await mintSession(p, { age: true });
    const c1 = await approve(R, own.access_token);
    const t1 = await trade(R, c1);
    const pair1 = { access: t1.json?.access_token, refresh: t1.json?.refresh_token };
    const out1 = await signOut(own.access_token);
    await wait(6000);
    console.log(`  --      D1. a code's session approves a connection (${t1.status}), then signs out (${out1}): the connection: `
      + `${await standingOf(R, pair1)} (it outlives a sign-out, as approving_session.sql says it should)`);
    // D2: Google's session approves, signs out; then Unlink.
    const own2 = await mintSession(p, { age: true });
    const g = await viaWay(R, "google", googleOf(p));
    if (!g.session) throw new Error(`D: Google did not sign in: ${failedOf(g)}`);
    const c2 = await approve(R, g.session.access_token);
    const t2 = await trade(R, c2);
    const pair2 = { access: t2.json?.access_token, refresh: t2.json?.refresh_token };
    const out2 = await signOut(g.session.access_token);
    await wait(6000);
    const afterOut = await standingOf(R, pair2);
    const un = await ways(R, own2.access_token, "google", false);
    await wait(6000);
    const afterUn = await standingOf(R, pair2);
    holds(/refresh 200/.test(afterOut) && /tools\/list 401, refresh 400/.test(afterUn),
      "D2. Google's session approves, then signs out: the connection lives on as Google's, and Unlink still ends it",
      `trade ${t2.status}; sign-out ${out2}; after it: ${afterOut}; Unlink ${un.status}; after it: ${afterUn}`);
    // D3: a code made, its session signed out before the exchange.
    await ways(R, own2.access_token, "google", true);
    await wait(8000);
    const g3 = await viaWay(R, "google", googleOf(p));
    const c3 = g3.session ? await approve(R, g3.session.access_token) : { code: null };
    const out3 = g3.session ? await signOut(g3.session.access_token) : 0;
    const t3 = c3.code ? await trade(R, c3) : { status: 0 };
    holds(c3.code && t3.status === 400, "D3. a code whose session signs out before the exchange: refused (it went with the session)",
      `approve ${c3.status}, sign-out ${out3}, trade ${t3.status} ${t3.json?.error || ""} ${t3.json?.error_description || ""}`);
    // D4: the account deleted under D1's connection.
    const gone = await deleteAccount(p).catch(() => false);
    await wait(6000);
    holds(gone && /tools\/list 401, refresh 400/.test(await standingOf(R, pair1)),
      "D4. the account deleted: D1's connection lists nothing and renews no more", `deleted ${gone}`);
  }

  // ------------------------------------------------------------------ F
  if (ONLY.includes("F") && ROC) {
    console.log("F. orangecheck's app sign-in with made-up codes (nothing counted before orangecheck is asked)");
    const count = () => (ROCLOG ? readFileSync(ROCLOG, "utf8").split("\n").filter((l) => / oc .*\/api\/auth\/native\/token/.test(l)).length : -1);
    const before = count();
    const from = network();
    const answers = [];
    for (let n = 0; n < 40; n += 1) {
      const r = await call(ROC, "/api/orangecheck?op=native", { method: "POST", from, body: {
        code: b64url(randomBytes(24)), code_verifier: b64url(randomBytes(40)), redirect_uri: "http://127.0.0.1:53682/callback" } });
      answers.push(r.status);
    }
    const asked = count() - before;
    say(asked >= 40 ? "FINDING" : "ok",
      "F1. forty POSTs of ?op=native with made-up codes, one network, no account: each one makes this server call orangecheck's "
      + "token endpoint with Brickworks' project key; nothing bounds it",
      `answers ${[...new Set(answers)].map((s) => `${s} x${answers.filter((a) => a === s).length}`).join(", ")}; orangecheck's token endpoint asked ${asked} times`);
  }
} catch (trouble) {
  say("FAIL", "the attack finished", String(trouble?.stack || trouble).slice(0, 900));
} finally {
  if (RULES) rules({});
  let left = 0;
  for (const email of made) if (!(await deleteAccount(email).catch(() => false))) left += 1;
  console.log(`  --      accounts named: ${made.length}, deleted now (or gone before): ${made.length - left}`);
}
console.log(`attack4: ${findings} finding line(s)`);
