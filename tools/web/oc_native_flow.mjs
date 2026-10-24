// Sign in with orangecheck on the desktop, all the way, on orangecheck's
// test stack (2026-10-24, unit oc237): the app's real form and listener
// (src/dev/oc_native_probe.gd, headless), a real Chromium signed in to the
// test stack as a new throwaway Bitcoin key, and api/orangecheck.js
// ?op=native on this machine (tools/web/relay_server.mjs, at the test
// project's development origin). Never the live project: orangecheck offers
// apps' sign-in to test projects alone, and a release takes no test key.
//
//   npm install --prefix /tmp/bip322 @orangecheck/bip322@1.1.2     once; not a dependency here
//   set -a; . ./.env; set +a
//   BIP322_MODULE=/tmp/bip322/node_modules/@orangecheck/bip322/dist/index.mjs \
//   OC_TEST_SECRET_FILE=<the test project's signing secret, a JSON file orangecheck gave> \
//     node tools/web/oc_native_flow.mjs --keys=oc_throwaways.txt
//
//   1. The app: its form offers Sign in with orangecheck, a press prints the
//      authorize link, Chromium opens it and presses Continue, the browser
//      comes back to the app's listener with a code, the app posts it, and
//      is signed in as a new account (oc_native_probe's own checks).
//   2. As the app, from here, against the same server, each refused: the
//      same code twice, a verifier its challenge was not made from (and
//      the right one after it), a redirect_uri other than the one it was
//      given for, and a code whose token is for another audience (a second
//      server, at another origin). And the same orangecheck id signs in to
//      the account the app made.
// The throwaway's address and orangecheck id, and the Brickworks account it
// made (deleted at the end), are added to --keys for orangecheck to purge.
// One line a check, then "oc_native_flow: N passed, M failed".
//
// The test project it was proven on in oc237 (pk_test_WlwvYN8n055vuMCm) was
// deleted by orangecheck once the live project was proven (2026-10-24);
// OC_TEST_PROJECT, OC_TEST_AUTH and OC_TEST_ME name another.
//
// --url=https://brickworks.diy (m167): the same against a deployment and
// orangecheck's own live project, as /api/account offers them (ochk.io, the
// project, the audience): no servers here and no secret, the app and this
// flow both posting to the deployment's ?op=native. The case of another
// audience, which needs a server of our own, is the test stack's alone.
//
//   BIP322_MODULE=... node tools/web/oc_native_flow.mjs --url=https://brickworks.diy --keys=oc_throwaways.txt

import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { appendFileSync, readFileSync } from "node:fs";
import http from "node:http";
import { createInterface } from "node:readline";
import { launch } from "./browser.mjs";

const LIVE = (process.argv.find((a) => a.startsWith("--url=")) || "").slice(6).replace(/\/+$/, "");
const offer = LIVE ? (await (await fetch(`${LIVE}/api/account`)).json().catch(() => ({}))).orangecheck?.native : null;
if (LIVE && !offer) {
  console.error(`oc_native_flow: ${LIVE} offers the desktop no Sign in with orangecheck`);
  process.exit(2);
}
const PROJECT = LIVE ? offer.project : process.env.OC_TEST_PROJECT || "pk_test_WlwvYN8n055vuMCm";
const AUTH = LIVE ? offer.auth : process.env.OC_TEST_AUTH || "https://oc-www-test.vercel.app";
const ME = process.env.OC_TEST_ME || "https://oc-me-test.vercel.app";
// The test project's development origin, which its tokens are bound to;
// or the deployment's own audience.
const PORT = 8790;
const AUD = LIVE ? offer.audience : `http://127.0.0.1:${PORT}`;
// Where the app, and this flow as the app, post their codes.
const SITE = LIVE || AUD;
// Another origin, for a server whose audience is not the token's.
const OTHER = 9051;
// Where the browser comes back to for the codes asked from here, listened
// at here as the app listens.
const BACK = 9052;
const ROOT = new URL("../..", import.meta.url).pathname;
const keys = (process.argv.find((a) => a.startsWith("--keys=")) || "--keys=oc_throwaways.txt").slice(7);

if (!process.env.BIP322_MODULE || (!LIVE && !process.env.OC_TEST_SECRET_FILE) || !process.env.SUPABASE_SECRET_KEY) {
  console.error("oc_native_flow: BIP322_MODULE, OC_TEST_SECRET_FILE (but with --url) and .env's SUPABASE_* are needed");
  process.exit(2);
}
const said = LIVE ? {} : JSON.parse(readFileSync(process.env.OC_TEST_SECRET_FILE, "utf8"));
const SECRET = said.signing_secret ?? said.secret;
const { addressFromPrivateKey, signMessage } = await import(process.env.BIP322_MODULE);
const SB = process.env.SUPABASE_URL.replace(/\/+$/, "");
const ADMIN = { apikey: process.env.SUPABASE_SECRET_KEY, authorization: `Bearer ${process.env.SUPABASE_SECRET_KEY}` };

let passed = 0;
let failed = 0;
const redact = (text) => String(text).replace(/eyJ[\w-]+\.[\w-]+\.[\w-]*/g, "[token]");
function check(name, ok, note = "") {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`${ok ? "pass" : "FAIL"} ${name}${note ? `: ${redact(note)}` : ""}`);
}

/// This machine's deployment functions, as on the test project: its key and
/// secret and orangecheck's test hosts, and never Connect's key or a mail
/// key.
function server(port) {
  const env = { ...process.env, OC_PROJECT_KEY: PROJECT, OC_SIGNING_SECRET: SECRET, OC_AUDIENCE: `http://127.0.0.1:${port}`,
    OC_ISSUER: AUTH, OC_ME_ORIGIN: ME };
  for (const name of ["OC_CONNECT_KEY", "RESEND_API_KEY", "VERCEL_ENV"]) delete env[name];
  const child = spawn(process.execPath, [`${ROOT}tools/web/relay_server.mjs`, String(port)], { env, stdio: ["ignore", "pipe", "pipe"] });
  child.stderr.on("data", (chunk) => process.stderr.write(redact(chunk)));
  return new Promise((ready, no) => {
    const lines = createInterface({ input: child.stdout });
    lines.on("line", (line) => { if (line.includes(`127.0.0.1:${port}/api/`)) ready(child); });
    child.on("exit", (code) => no(new Error(`relay_server ${port} exited ${code}`)));
  });
}

const made = [];
const servers = [];
let browser;
let throwaway = null;
try {
  if (!LIVE) servers.push(await server(PORT), await server(OTHER));
  console.log(`against ${SITE}: orangecheck at ${AUTH}, project ${PROJECT}, audience ${AUD}`);

  // A throwaway orangecheck account at orangecheck's sign-in host: a new
  // key, signed in there as orangecheck's own sign-in page does, its
  // session put in the browser for that host.
  const key = randomBytes(32);
  const address = addressFromPrivateKey(key, "p2wpkh");
  const same = { origin: AUTH, "sec-fetch-site": "same-origin" };
  const challenge = await (await fetch(`${AUTH}/api/challenge?addr=${address}&audience=${encodeURIComponent("https://ochk.io")}&purpose=login`,
    { headers: same })).json();
  const signedIn = await fetch(`${AUTH}/api/auth/signin`, { method: "POST", headers: { ...same, "content-type": "application/json" },
    body: JSON.stringify({ message: challenge.message, signature: signMessage(address, challenge.message, key),
      expectedNonce: challenge.nonce, expectedAudience: "https://ochk.io", expectedPurpose: "login" }) });
  const session = signedIn.headers.getSetCookie().find((one) => /^oc_session=ey/.test(one))?.split(";")[0].slice("oc_session=".length);
  if (!session) throw new Error(`the throwaway did not sign in at ${AUTH}: ${signedIn.status}`);
  const did = JSON.parse(Buffer.from(session.split(".")[1], "base64url").toString()).did_oc;
  throwaway = { address, did };
  console.log(`throwaway ${address} ${did}`);
  appendFileSync(keys, `${new Date().toISOString()} oc_native_flow ${AUTH} address ${address} did ${did}\n`);

  browser = await launch({ signedOut: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  await context.addCookies([{ name: "oc_session", value: session, domain: new URL(AUTH).hostname, path: "/", secure: true,
    httpOnly: true, sameSite: "None" }]);
  /// orangecheck's authorize page at [url], Continue pressed as the person.
  const consent = async (url) => {
    const page = await context.newPage();
    await page.goto(url);
    await page.getByRole("button", { name: "Continue" }).click({ timeout: 30000 });
    return page;
  };

  // 1. The app.
  const probe = spawn(`${ROOT}tools/probe.sh`, ["oc_native_probe"], { env: { ...process.env, BRICKWORKS_API: SITE }, stdio: ["ignore", "pipe", "pipe"] });
  const out = [];
  createInterface({ input: probe.stderr }).on("line", (line) => out.push(line));
  let account = null;
  const linked = new Promise((found, no) => {
    createInterface({ input: probe.stdout }).on("line", (line) => {
      out.push(line);
      if (/^(pass|FAIL) /.test(line)) console.log(`  app: ${line}`);
      if (line.startsWith("LINK ")) found(line.slice(5));
      const named = line.match(/^ACCOUNT (\S+) (\S+)$/);
      if (named) account = { id: named[1], email: named[2] };
    });
    probe.on("exit", () => no(new Error(`the probe ended without a link: ${out.slice(-5).join(" | ")}`)));
  });
  const ended = new Promise((done) => probe.on("exit", (code) => done(code)));
  const link = await linked;
  const page = await consent(link);
  await page.waitForURL(/^http:\/\/127\.0\.0\.1:\d+\/oc\/callback\?/, { timeout: 30000 });
  const shown = await page.locator("body").innerText();
  check("the browser came back to the app's own listener, which says to go back to Brickworks", /Back to Brickworks/.test(shown), shown);
  await page.close();
  const code = await Promise.race([ended, new Promise((done) => setTimeout(() => done("timeout"), 180000))]);
  if (account) made.push(account.id);
  check("the app signed in end to end, every check of the probe passed", code === 0 && Boolean(account),
    `exit ${code}, ${out.filter((line) => line.startsWith("FAIL")).join("; ")}`);

  // 2. As the app, from here.
  const askCode = async () => {
    const verifier = randomBytes(32).toString("base64url");
    const state = randomBytes(16).toString("base64url");
    const redirect = `http://127.0.0.1:${BACK}/oc/callback`;
    const query = new URLSearchParams({ project: PROJECT, redirect_uri: redirect, state, audience: AUD,
      code_challenge: createHash("sha256").update(verifier).digest("base64url"), code_challenge_method: "S256" });
    let back = null;
    const listener = http.createServer((request, reply) => {
      const asked = new URL(request.url, `http://127.0.0.1:${BACK}`);
      if (asked.pathname === "/oc/callback" && asked.searchParams.get("state") === state) back = asked;
      reply.writeHead(200, { "content-type": "text/html" }).end("<p>back</p>");
    });
    await new Promise((done) => listener.listen(BACK, "127.0.0.1", done));
    const at = await consent(`${AUTH}/native/authorize?${query}`);
    for (let i = 0; i < 60 && !back; i += 1) await at.waitForTimeout(500);
    await at.close();
    listener.closeAllConnections();
    await new Promise((done) => listener.close(done));
    if (!back || back.searchParams.get("state") !== state || !back.searchParams.get("code")) throw new Error(`no code came back: ${back}`);
    return { code: back.searchParams.get("code"), code_verifier: verifier, redirect_uri: redirect };
  };
  const post = async (body, at = SITE) => {
    const reply = await fetch(`${at}/api/orangecheck?op=native`, { method: "POST",
      headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
    return { status: reply.status, body: await reply.json().catch(() => ({})) };
  };
  const refused = (answer) => answer.status === 401 && typeof answer.body.error === "string";

  const first = await askCode();
  const signs = await post(first);
  if (signs.body.user?.id && !made.includes(signs.body.user.id)) made.push(signs.body.user.id);
  check("a code traded from here signs in, to the account the app made for the same orangecheck id", signs.status === 200
    && signs.body.orangecheck?.did === did && signs.body.user?.id === account?.id, `${signs.status} ${signs.body.error || ""}`);
  const twice = await post(first);
  check("the same code again is refused", refused(twice), `${twice.status} ${twice.body.error || ""}`);

  const second = await askCode();
  const wrongVerifier = await post({ ...second, code_verifier: randomBytes(32).toString("base64url") });
  check("a verifier its challenge was not made from is refused", refused(wrongVerifier), `${wrongVerifier.status} ${wrongVerifier.body.error || ""}`);
  const rightAfter = await post(second);
  check("...and the code is spent by it: the right verifier after is refused", refused(rightAfter), `${rightAfter.status} ${rightAfter.body.error || ""}`);

  const third = await askCode();
  const otherRedirect = await post({ ...third, redirect_uri: `http://127.0.0.1:${BACK + 1}/oc/callback` });
  check("a redirect_uri other than the one the code was given for is refused", refused(otherRedirect),
    `${otherRedirect.status} ${otherRedirect.body.error || ""}`);

  if (!LIVE) {
    const fourth = await askCode();
    const otherAudience = await post(fourth, `http://127.0.0.1:${OTHER}`);
    check(`a code whose token is for ${AUD}, traded by a server whose audience is http://127.0.0.1:${OTHER}, is refused`,
      refused(otherAudience), `${otherAudience.status} ${otherAudience.body.error || ""}`);
  }
} catch (trouble) {
  check("the run finished", false, String(trouble?.stack || trouble).slice(0, 400));
} finally {
  await browser?.close().catch(() => {});
  for (const child of servers) child.kill();
  let gone = 0;
  for (const id of made) {
    const reply = await fetch(`${SB}/auth/v1/admin/users/${id}`, { method: "DELETE", headers: ADMIN });
    if (reply.ok || reply.status === 404) gone += 1;
    appendFileSync(keys, `${new Date().toISOString()} oc_native_flow brickworks account ${id} for ${throwaway?.did} (deleted: ${reply.status})\n`);
  }
  console.log(`oc_native_flow: ${made.length} Brickworks accounts made, ${gone} deleted`);
  console.log(`oc_native_flow: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}
