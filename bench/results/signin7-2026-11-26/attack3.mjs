// signreview3 (2026-11-25): what signin5 (cb7956146) opened, against a relay of that tree with
// Google, GitHub and Connect stood in for (tools/web/ways_stand_in.mjs) and the real Supabase
// project behind it, plus a second relay with orangecheck's keys made up (nothing reaches
// orangecheck: only tokens that are not one are sent). Throwaway accounts only, all deleted.
//
//   --r    the stand-in relay, its owner a throwaway O3 (--owner)
//   --roc  the relay with OC_* made up, for orangecheck's count
//   --owner  O3's address
//   --only   sections, default S,N,W,T,O,K,V
//
// Sections (each prints "  ok"/"  FINDING"/"  --" lines):
//   V. networkOf: one /64 of a campus is one network; a /48 or /56 of one person is many.
//   S. the start seal spent (SR2): six callbacks at once with one seal; a callback that fails
//      after the spend, and the person's next try; a seal's URL without its cookie.
//   N. counting only vouched identities: 30 throwaway GitHub identities on one network shut
//      the 31st person out; that person's refused tries use up their own account's count.
//   W. SR1 again: an approve just after the Unlink, while the session is still read as alive,
//      leaves a code with no way on it, and its connection outlives the Unlink.
//   T. way_on after a token write: a code traded twice, an Unlink between approve and token,
//      token exchanges racing an Unlink, refreshes racing an Unlink.
//   O. orangecheck's network count comes before the token: junk from one network, and from one
//      /64, shuts out a real sign-in there with no orangecheck account.
//   K. the owner's console from a Claude connection's token approved by the owner's session.
// Supabase verifies spent from this box: about 11 (S 3, W 1, T 6, N/O/K/V 0), paced.
import { createHash, randomBytes } from "node:crypto";
import { codeFor } from "../../../tools/web/ways_stand_in.mjs";
import { deleteAccount, mintSession } from "../../../tools/web/session.mjs";
import { networkOf } from "../../../api/_ways.js";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const R = arg("r").replace(/\/+$/, "");
const ROC = arg("roc").replace(/\/+$/, "");
const OWNER = arg("owner");
const ONLY = arg("only", "V,S,N,W,T,O,K").split(",");
const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-sr3-${name}-${tag}@resend.dev`;
const made = [];
let findings = 0;
const say = (kind, what, detail = "") => {
  if (kind === "FINDING") findings += 1;
  console.log(`  ${kind.padEnd(7)} ${what}${detail ? `: ${String(detail).slice(0, 900)}` : ""}`);
};
const holds = (ok, what, detail = "") => say(ok ? "ok" : "FAIL", what, detail);
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
const sha = (text) => createHash("sha256").update(text).digest("hex");
const network = () => `198.19.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;
const qs = (o) => new URLSearchParams(o).toString();
const failedOf = (one) => new URL(one?.back?.location || one?.location || "/", "http://x").searchParams.get("failed")
  || (one?.session ? "signed-in" : one?.back?.cookies?.some((c) => c.startsWith("bw_way_take=")) ? "handed" : "?");

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
  return { status: reply.status, json, text, location: reply.headers.get("location") || "", cookies: reply.headers.getSetCookie?.() || [] };
}
const cookieNamed = (cookies, name) => (cookies.find((one) => one.startsWith(`${name}=`)) || "").split(";")[0];

async function start(site, name, from) {
  const verifier = b64url(randomBytes(32));
  const st = await call(site, `/auth/${name}?${qs({ then: "/gallery", take: challengeOf(verifier) })}`, { from });
  return { st, verifier, cookie: cookieNamed(st.cookies, `bw_way_${name}`), state: st.location.startsWith("https://")
    ? new URL(st.location).searchParams.get("state") : "" };
}
const back = (site, name, { cookie, state, code, from }) => call(site, `/auth/callback/${name}?${qs({ code, state })}`, { cookie, from });
async function take(site, reply, verifier, from) {
  const cookie = cookieNamed(reply.cookies, "bw_way_take");
  if (!cookie) return null;
  const took = await call(site, "/api/otp?op=way_take", { method: "POST", cookie, body: { code_verifier: verifier }, from });
  return took.json?.access_token ? took.json : null;
}
/// A whole sign-in with [name] as [who] at [site], as the page makes it.
async function viaWay(site, name, who, { from = network() } = {}) {
  const s = await start(site, name, from);
  if (s.st.status !== 302 || !s.state) return { start: s.st };
  const reply = await back(site, name, { cookie: s.cookie, state: s.state, code: codeFor(s.st.location, who), from });
  return { start: s.st, back: reply, session: await take(site, reply, s.verifier, from) };
}
const serviceGet = (path) => fetch(`${SB}/rest/v1/${path}`, { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } })
  .then((r) => r.json());
const standIn = (site) => fetch(`${site}/__ways/state`).then((r) => r.json());

// Claude's connector, as a client of anyone's making (RFC 7591).
const CALLBACK = "https://claude.ai/api/mcp/auth_callback";
let clientId = "";
async function client(site) {
  if (clientId) return clientId;
  const reg = await call(site, "/oauth/register", { method: "POST", body: { client_name: "signreview3's client", redirect_uris: [CALLBACK],
    token_endpoint_auth_method: "none", grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] } });
  clientId = reg.json?.client_id || "";
  return clientId;
}
async function approve(site, token) {
  const verifier = b64url(randomBytes(32));
  const params = { response_type: "code", client_id: await client(site), redirect_uri: CALLBACK, code_challenge: challengeOf(verifier),
    code_challenge_method: "S256", state: "s3", resource: `${site}/api/mcp`, scope: "build" };
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
const unlink = (site, token, name, on = false) => call(site, "/api/otp?op=ways", { method: "POST", token, body: { with: name, on } });
const ours = async (site, token) => {
  const listed = await call(site, "/api/oauth?op=connections", { token });
  return Array.isArray(listed.json?.connections) ? listed.json.connections.length : -1;
};
/// What a set of tokens can still do after an Unlink: [{access, refresh}] → how many list tools or renew.
async function standing(site, pairs) {
  let lists = 0;
  let renews = 0;
  for (const pair of pairs) {
    if (pair.access && (await mcp(site, pair.access)).status === 200) lists += 1;
    if (pair.refresh && (await refresh(site, pair.refresh)).status === 200) renews += 1;
  }
  return { lists, renews };
}

try {
  // ------------------------------------------------------------------ V
  if (ONLY.includes("V")) {
    console.log("V. what networkOf counts as one network (api/_ways.js)");
    const key = (ip) => networkOf({ headers: { "x-forwarded-for": ip } });
    const campus = ["2001:db8:aa:1::5", "2001:db8:aa:1:ffff:ffff:ffff:fffe", "2001:0DB8:00AA:0001:0:0:0:9"].map(key);
    holds(new Set(campus).size === 1, `V1. three devices on one campus /64: one network (${campus[0]})`, campus.join(" "));
    const home56 = new Set(Array.from({ length: 256 }, (_, n) => key(`2001:db8:bb:${(0x1200 + n).toString(16)}::1`)));
    const one48 = new Set(Array.from({ length: 65536 }, (_, n) => key(`2001:db8:cc:${n.toString(16)}::1`)));
    console.log(`  --      V2. one home's /56 (the usual delegation) counts as ${home56.size} networks; one /48 (a free tunnel's) as ${one48.size}`);
    const v4 = [key("203.0.113.5, 10.0.0.1"), key("::ffff:203.0.113.5"), key(" 203.0.113.5")];
    holds(new Set(v4).size === 1, `V3. IPv4: the first of x-forwarded-for, mapped or not: ${v4[0]}`, v4.join(" "));
  }

  // ------------------------------------------------------------------ S
  if (ONLY.includes("S")) {
    console.log("S. the start seal, spent at its callback (SR2)");
    // S1: six callbacks at once, one seal and one code.
    {
      const from = network();
      const who = { email: address("race"), verified: true, hd: "resend.dev" };
      made.push(who.email);
      const s = await start(R, "google", from);
      const before = (await standIn(R)).tokens;
      const code = codeFor(s.st.location, who);
      const backs = await Promise.all(Array.from({ length: 6 }, () => back(R, "google", { cookie: s.cookie, state: s.state, code, from })));
      const asked = (await standIn(R)).tokens - before;
      const handed = backs.filter((b) => cookieNamed(b.cookies, "bw_way_take"));
      const again = backs.filter((b) => /failed=again/.test(b.location)).length;
      const session = handed[0] ? await take(R, handed[0], s.verifier, from) : null;
      holds(handed.length === 1 && again === 5 && asked === 1 && session,
        "S1. six callbacks at once with one start's cookie: one signed in, five refused before Google was asked",
        `handed ${handed.length}, again ${again}, Google asked ${asked}, taken ${Boolean(session)}: ${backs.map((b) => b.location.slice(0, 60)).join(" | ")}`);
    }
    await wait(10000);
    // S2: a callback that fails after the spend (Google refuses its code), then the same seal again, then a new start.
    {
      const from = network();
      const who = { email: address("retry"), verified: true, hd: "resend.dev" };
      made.push(who.email);
      const s = await start(R, "google", from);
      const first = await back(R, "google", { cookie: s.cookie, state: s.state, code: "not-a-code-google-gave", from });
      const second = await back(R, "google", { cookie: s.cookie, state: s.state, code: codeFor(s.st.location, who), from });
      const t0 = Date.now();
      const next = await viaWay(R, "google", who, { from });
      holds(/failed=failed/.test(first.location) && /failed=again/.test(second.location) && next.session,
        "S2. a callback that fails after its seal is spent: that seal is done (again), and the person's next press signs in at once",
        `first ${first.location.slice(0, 80)}; the same seal ${second.location.slice(0, 80)}; a new start ${failedOf(next)} in ${Date.now() - t0} ms`);
    }
    await wait(10000);
    // S3: someone with the callback's URL alone (code and state), with no cookie or their own start's.
    {
      const from = network();
      const who = { email: address("url"), verified: true, hd: "resend.dev" };
      made.push(who.email);
      const s = await start(R, "google", from);
      const code = codeFor(s.st.location, who);
      const bare = await back(R, "google", { cookie: "", state: s.state, code, from: network() });
      const theirs = await start(R, "google", network());
      const crossed = await back(R, "google", { cookie: theirs.cookie, state: s.state, code, from: network() });
      const own = await back(R, "google", { cookie: s.cookie, state: s.state, code, from });
      const session = await take(R, own, s.verifier, from);
      holds(/failed=again/.test(bare.location) && /failed=again/.test(crossed.location) && session,
        "S3. the callback's URL without its cookie, or with someone else's start: refused and nothing spent; the person's own goes through",
        `bare ${bare.location.slice(0, 70)}; crossed ${crossed.location.slice(0, 70)}; own ${own.location.slice(0, 70)}`);
    }
  }

  // ------------------------------------------------------------------ N
  if (ONLY.includes("N")) {
    console.log("N. counting only vouched identities: 30 per network");
    // An address with an account already: a GitHub identity there is refused as confirm after both counts, and nothing
    // is minted, so this section spends no verify. Six GitHub accounts, five sign-ins each, from one network.
    const y = address("ylock");
    made.push(y);
    await mintSession(y, { age: true });
    const office = network();
    const base = 1_900_000_000 + (randomBytes(2).readUInt16BE(0) * 100);
    const tries = [];
    for (let k = 0; k < 6; k += 1) {
      for (let j = 0; j < 5; j += 1) tries.push(failedOf(await viaWay(R, "github", { email: y, verified: true, id: base + k }, { from: office })));
    }
    const counts = tries.reduce((m, f) => ({ ...m, [f]: (m[f] || 0) + 1 }), {});
    const v = address("nvictim");
    made.push(v);
    const victim = await viaWay(R, "github", { email: v, verified: true, id: base + 50 }, { from: office });
    const victimMade = await fetch(`${SB}/auth/v1/admin/users?${qs({ filter: v, per_page: "5" })}`,
      { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } }).then((r) => r.json()).then((j) => (j.users || []).length);
    const elsewhere = await viaWay(R, "github", { email: y, verified: true, id: base + 7 }, { from: network() });
    say(failedOf(victim) === "often" ? "FINDING" : "ok",
      "N1. six throwaway GitHub accounts, five sign-ins each from one network (each refused, nothing minted): the next person "
      + "there, a new one, is shut out of Google and GitHub for 15 minutes; elsewhere is not",
      `the 30: ${JSON.stringify(counts)}; the person: ${failedOf(victim)}, account made ${victimMade}; another network: ${failedOf(elsewhere)}`);
    // N2: the person tries four times more there, then goes home.
    const more = [];
    for (let n = 0; n < 4; n += 1) more.push(failedOf(await viaWay(R, "github", { email: v, verified: true, id: base + 50 }, { from: office })));
    const home = await viaWay(R, "github", { email: v, verified: true, id: base + 50 }, { from: network() });
    say(failedOf(home) === "often" ? "FINDING" : "ok",
      "N2. that person's five refused tries on the shut network count against their own GitHub account (counted first, never "
      + "taken back): at home, on a network nobody used, they are refused too",
      `there: ${more.join(",")}; at home: ${failedOf(home)}`);
    if (home.session) made.push(v);
  }

  // ------------------------------------------------------------------ W
  if (ONLY.includes("W")) {
    console.log("W. SR1 again: an approve as the Unlink lands");
    const ROUNDS = Number(arg("rounds", "3"));
    let through = 0;
    for (let round = 1; round <= ROUNDS; round += 1) {
    if (round > 1) await wait(10000);
    const p = address(`bypass${round}`);
    made.push(p);
    const own = await mintSession(p, { age: true });
    const g = await viaWay(R, "google", { email: p, verified: true, hd: "resend.dev" });
    if (!g.session) throw new Error(`W: Google did not sign p in: ${failedOf(g)}`);
    const S = g.session.access_token;
    await client(R);
    const a0 = await approve(R, S);
    const t = Date.now();
    const un = await unlink(R, own.access_token, "google");
    // Asked again at once, as a loop of approves would be (one every 200 ms) until one goes through or 5 s pass.
    let a1 = await approve(R, S);
    while (!a1.code && Date.now() - t < 5000) {
      await wait(200);
      a1 = await approve(R, S);
    }
    const gap = Date.now() - t;
    const rows = await serviceGet(`oauth_codes?select=hash,way&hash=in.(${[a0.code, a1.code].filter(Boolean).map(sha).join(",")})`);
    const wayOfCode = (code) => (Array.isArray(rows) ? rows.find((r) => r.hash === sha(code || "")) : null);
    const t0 = a0.code ? await trade(R, a0) : null;
    const t1 = a1.code ? await trade(R, a1) : null;
    await wait(6000);
    const sAfter = await call(R, "/api/people?op=me", { token: S });
    const now = await standing(R, [{ access: t1?.json?.access_token, refresh: t1?.json?.refresh_token }]);
    const listed = await ours(R, own.access_token);
    console.log(`  --      round ${round}: the Unlink (from the person's own session): ${un.status} ${JSON.stringify(un.json)}; the approve after it, `
      + `${gap} ms on: ${a1.status} ${a1.code ? "" : a1.text}; codes before/after: ${JSON.stringify(wayOfCode(a0.code))} / ${JSON.stringify(wayOfCode(a1.code))}`);
    if (now.lists && now.renews) through += 1;
    say(now.lists && now.renews ? "FINDING" : "ok",
      `W1. round ${round}: Google's session, still read as signed in for up to 5 s (SESSION_HELD_MS), approves a connection just after the `
      + "Unlink: the code carries no way (way_sessions went with the session), so it is traded, works and renews after the Unlink",
      `the code from before: ${t0?.status} ${t0?.json?.error || ""}; after: ${t1?.status}; Google's session now ${sAfter.status}; `
      + `6 s on, tools/list ${now.lists ? 200 : "refused"}, refresh ${now.renews ? 200 : "refused"}; Settings lists ${listed} connection(s)`);
    }
    console.log(`  --      W: ${through} of ${ROUNDS} rounds kept a connection past the Unlink`);
  }

  // ------------------------------------------------------------------ X
  // W as an intruder would run it: approves in a loop, one every 150 ms, from before the Unlink until 6 s after it
  // answers, so it no longer matters how long the Unlink takes. Every code made is read (its way), and the first with
  // none is traded.
  if (ONLY.includes("X")) {
    console.log("X. SR1 again, the intruder's loop of approves across the Unlink");
    const ROUNDS = Number(arg("rounds", "2"));
    let through = 0;
    for (let round = 1; round <= ROUNDS; round += 1) {
      if (round > 1) await wait(10000);
      const p = address(`loop${round}`);
      made.push(p);
      const own = await mintSession(p, { age: true });
      const g = await viaWay(R, "google", { email: p, verified: true, hd: "resend.dev" });
      if (!g.session) throw new Error(`X: Google did not sign p in: ${failedOf(g)}`);
      const S = g.session.access_token;
      await client(R);
      let stop = false;
      const codes = [];
      const loop = (async () => {
        while (!stop) {
          const a = await approve(R, S);
          codes.push({ ...a, at: Date.now() });
          await wait(150);
        }
      })();
      await wait(1000);
      const sent = Date.now();
      const un = await unlink(R, own.access_token, "google");
      const answered = Date.now();
      await wait(6000);
      stop = true;
      await loop;
      const made1 = codes.filter((c) => c.code);
      const rows = made1.length ? await serviceGet(`oauth_codes?select=hash,way&hash=in.(${made1.map((c) => sha(c.code)).join(",")})`) : [];
      const left = new Map((Array.isArray(rows) ? rows : []).map((r) => [r.hash, r.way]));
      const after = made1.filter((c) => c.at > answered);
      const unmarked = made1.filter((c) => left.has(sha(c.code)) && left.get(sha(c.code)) === null);
      const lastOk = made1.length ? made1[made1.length - 1].at - answered : null;
      const traded = unmarked[0] ? await trade(R, unmarked[0]) : null;
      await wait(6000);
      const now = await standing(R, [{ access: traded?.json?.access_token, refresh: traded?.json?.refresh_token }]);
      if (now.lists && now.renews) through += 1;
      say(now.lists && now.renews ? "FINDING" : "ok",
        `X1. round ${round}: a loop of approves from Google's session across the Unlink: codes made after it carry no way, and one traded outlives it`,
        `Unlink ${un.status} in ${answered - sent} ms; ${codes.length} approves, ${made1.length} gave a code, ${after.length} of them after the Unlink `
        + `answered (the last ${lastOk} ms after); left in oauth_codes: ${left.size}, with no way: ${unmarked.length}; traded ${traded?.status}; `
        + `6 s on, tools/list ${now.lists ? 200 : "refused"}, refresh ${now.renews ? 200 : "refused"}`);
    }
    console.log(`  --      X: ${through} of ${ROUNDS} rounds kept a connection past the Unlink`);
  }

  // ------------------------------------------------------------------ T
  if (ONLY.includes("T")) {
    console.log("T. way_on after a token write");
    const p = address("tok");
    made.push(p);
    const own = await mintSession(p, { age: true });
    let g = await viaWay(R, "google", { email: p, verified: true, hd: "resend.dev" });
    if (!g.session) throw new Error(`T: Google did not sign p in: ${failedOf(g)}`);
    await client(R);
    // T1: a code traded twice at once, then a third time.
    const c1 = await approve(R, g.session.access_token);
    const both = await Promise.all([trade(R, c1), trade(R, c1)]);
    const third = await trade(R, c1);
    const won = both.filter((b) => b.status === 200);
    holds(won.length === 1 && third.status === 400, "T1. a code traded twice at once: one connection; the third try refused",
      `${both.map((b) => `${b.status} ${b.json?.error || ""}`).join(", ")}; third ${third.status}`);
    // T2: an Unlink between approve and token.
    const c2 = await approve(R, g.session.access_token);
    await unlink(R, own.access_token, "google");
    const t2 = await trade(R, c2);
    await wait(6000);
    const t1Now = await standing(R, [{ access: won[0]?.json?.access_token, refresh: won[0]?.json?.refresh_token }]);
    holds(t2.status === 400 && !t1Now.lists && !t1Now.renews,
      "T2. an Unlink between approve and token: the code refused; T1's connection lists no tools and renews no more",
      `${t2.status} ${t2.json?.error || ""}; T1's: ${JSON.stringify(t1Now)}`);
    // T3: token exchanges racing an Unlink, at three offsets.
    for (const offset of [0, 40, 150]) {
      await unlink(R, own.access_token, "google", true);
      await wait(8000);
      g = await viaWay(R, "google", { email: p, verified: true, hd: "resend.dev" });
      if (!g.session) throw new Error(`T3: Google did not sign p in again: ${failedOf(g)}`);
      const codes = [];
      for (let n = 0; n < 8; n += 1) codes.push(await approve(R, g.session.access_token));
      const [traded] = await Promise.all([Promise.all(codes.map((c) => trade(R, c))),
        wait(offset).then(() => unlink(R, own.access_token, "google"))]);
      await wait(6000);
      const pairs = traded.filter((r) => r.status === 200).map((r) => ({ access: r.json.access_token, refresh: r.json.refresh_token }));
      const left = await standing(R, pairs);
      holds(!left.lists && !left.renews && (await ours(R, own.access_token)) === 0,
        `T3. eight token exchanges racing an Unlink sent ${offset} ms in: none outlives it`,
        `${traded.map((r) => r.status).join(",")}; of the ${pairs.length} issued, list ${left.lists}, renew ${left.renews}`);
      console.log(`  --      T3 at ${offset} ms: ${traded.map((r) => `${r.status}${r.json?.error ? ` ${r.json.error}` : ""}`).join(", ")}`);
    }
    // T5: refreshes racing an Unlink.
    await unlink(R, own.access_token, "google", true);
    await wait(8000);
    g = await viaWay(R, "google", { email: p, verified: true, hd: "resend.dev" });
    const c5 = await approve(R, g.session.access_token);
    const t5 = await trade(R, c5);
    const [renewed] = await Promise.all([Promise.all(Array.from({ length: 4 }, () => refresh(R, t5.json.refresh_token))),
      wait(20).then(() => unlink(R, own.access_token, "google"))]);
    await wait(6000);
    const pairs5 = [{ access: t5.json.access_token, refresh: t5.json.refresh_token },
      ...renewed.filter((r) => r.status === 200).map((r) => ({ access: r.json.access_token, refresh: r.json.refresh_token }))];
    const left5 = await standing(R, pairs5);
    holds(!left5.lists && !left5.renews, "T5. four refreshes racing an Unlink: no token of that connection works after",
      `refreshes ${renewed.map((r) => r.status).join(",")}; of ${pairs5.length} pairs, list ${left5.lists}, renew ${left5.renews}`);
  }

  // ------------------------------------------------------------------ O
  if (ONLY.includes("O")) {
    console.log("O. orangecheck's network count, before its token is looked at");
    const signin = (from) => call(ROC, "/api/orangecheck?op=signin", { method: "POST", from, body: { token: "not-an-orangecheck-token" } });
    const lab = network();
    const firsts = [];
    for (let n = 0; n < 20; n += 1) firsts.push((await signin(lab)).status);
    const next = await signin(lab);
    const other = await signin(network());
    say(next.status === 429 ? "FINDING" : "ok",
      "O1. twenty POSTs of a token that is no one's, from one network with no orangecheck account: the next sign-in there, a "
      + "real one included (it is counted before its token is read), is refused for 15 minutes",
      `the 20: ${[...new Set(firsts)].join(",")}; the next: ${next.status} ${next.json?.error || ""}; another network: ${other.status}`);
    const p64 = `2001:db8:${randomBytes(2).toString("hex")}:${randomBytes(2).toString("hex")}`;
    const in64 = [];
    for (let n = 1; n <= 20; n += 1) in64.push((await signin(`${p64}::${n.toString(16)}`)).status);
    const last = await signin(`${p64}:1234:5678:9abc:def0`);
    say(last.status === 429 ? "FINDING" : "ok",
      "O2. the same from twenty addresses of one /64 (a campus or an office Wi-Fi): every other device on it is refused",
      `the 20: ${[...new Set(in64)].join(",")}; another device of that /64: ${last.status}`);
  }

  // ------------------------------------------------------------------ K
  if (ONLY.includes("K")) {
    console.log("K. the owner's console and a Claude connection");
    if (!made.includes(OWNER)) made.push(OWNER);
    const o = await mintSession(OWNER, { age: true });
    const opens = await call(R, "/api/admin?op=switches", { token: o.access_token });
    await client(R);
    const c = await approve(R, o.access_token);
    const t = await trade(R, c);
    const viaConnection = await call(R, "/api/admin?op=switches", { token: t.json?.access_token || "" });
    holds(opens.status === 200 && t.status === 200 && [401, 403, 404].includes(viaConnection.status),
      "K1. a connection approved by the owner's own session: its token does not open the console",
      `the owner's session ${opens.status}; the connection's token ${viaConnection.status} ${viaConnection.text.slice(0, 100)}`);
  }
} catch (trouble) {
  say("FAIL", "the attack finished", String(trouble?.stack || trouble).slice(0, 900));
} finally {
  let left = 0;
  for (const email of made) if (!(await deleteAccount(email).catch(() => false))) left += 1;
  console.log(`  --      accounts named: ${made.length}, deleted (or never made): ${made.length - left}`);
}
console.log(`attack3: ${findings} finding line(s)`);
