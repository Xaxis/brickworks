// A build party on two real phones (docs/APP_UX5.md, unit 5 buildparty):
// one shared model, built by two people at once, each on their own phone,
// with no account.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/buildparty_flow.mjs --build=build/web --port=9921 --out=DIR
//   BW_BYPASS=… node tools/web/buildparty_flow.mjs --url=<a preview> --out=DIR
//
// --build serves the export here with the deployment's functions
// (tools/web/relay_server.mjs --static), the build party's tables held in
// memory (--hold=together_sessions,together_ops,together_people) as
// supabase/together.sql makes them; --url uses a deployment's, where
// together.sql is applied. Either way the car (models/car.ldr, 61 parts) is
// published from a throwaway probe account (a Resend test address, so the
// gallery never lists it), taken down and the account deleted at the end.
// Neither phone signs in.
//
// Two Chromium contexts on SwiftShader, each a phone: 390 x 844, touch.
//
//   1. Phone A opens the link: Build together, Start a build. 2 taps, and
//      a code.
//   2. Phone B opens the link: Build together, the code typed, Join. 2 taps.
//      Both cards name both phones.
//   3. A: Start building. Both phones' Build it opens on their own share:
//      the two shares apart, all 61 parts once between them.
//   4. A part done on A shows on B within 2 s, and one done on B on A
//      (each read from what the other page says, twice a second).
//   5. B leaves mid-build (Close, Leave the build) and joins again (Join,
//      the code kept): its seat, and its page and part, back.
//   6. A goes to its end: it waits, saying for B, Next held. B goes to its
//      end: both are shown the joining step within 2 s, every part on show.
//
// Red on a build without it: no Build together on the link's viewer.
// Pictures of both phones in --out. Exit 1 on any failure.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession } from "./session.mjs";
import { spawn } from "node:child_process";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const out = path.resolve(String(args.out || "shots/buildparty_flow"));
mkdirSync(out, { recursive: true });
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const headers = bypass ? { "x-vercel-protection-bypass": bypass } : {};
const PARTS = 61;
const CROSS_MS = 2000;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const say = (what) => console.log(`  --    ${what}`);

let site = String(args.url || "").replace(/\/$/, "");
let server = null;
if (args.build) {
  const port = Number(args.port || 9921);
  server = spawn("node", [path.join(here, "relay_server.mjs"), String(port), `--static=${path.resolve(String(args.build))}`,
    "--hold=together_sessions,together_ops,together_people"], { stdio: ["ignore", "pipe", "inherit"], env: process.env });
  await new Promise((done, fail) => {
    server.stdout.on("data", (chunk) => { if (/functions on http/.test(String(chunk))) done(); });
    server.on("exit", (code) => fail(new Error(`relay_server ended (${code})`)));
  });
  site = `http://127.0.0.1:${port}`;
}
if (!site) throw new Error("--build=DIR or --url=<deployment>");

const probe = `delivered+bw-buildparty-${randomBytes(4).toString("hex")}@resend.dev`;
let token = "";
let link = "";

const share = (page) => page.evaluate(() => window.brickworksShare || {}).catch(() => ({}));
const party = async (page) => ((await share(page)).view || {}).party || {};
const build = async (page) => (await share(page)).build || {};

async function until(page, test, what, seconds = 120, arg = null, every = 50) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(every);
  }
}

const where = (page, name, seconds = 120) =>
  until(page, (n) => (window.brickworksControls || {})[n], `${name} on the page`, seconds, name, 100);

async function tap(page, name, seconds = 120) {
  const at = await where(page, name, seconds);
  await page.touchscreen.tap(at.x, at.y);
}

async function shot(page, name) {
  await page.screenshot({ path: path.join(out, name), timeout: 120000 })
    .catch((trouble) => say(`no picture ${name}: ${String(trouble).split("\n")[0]}`));
}

// A phone's own chip as the other phone shows it: "Ana 3 of 30".
const chipOf = (chips, name) => (chips || []).find((one) => String(one).startsWith(name)) || "";
const doneIn = (chip) => Number((/ (\d+) of \d+$/.exec(chip) || [0, -1])[1]);

const browser = await launch({ signedOut: true });
const errors = [];
try {
  token = (await mintSession(probe)).access_token;
  const reply = await fetch(`${site}/api/share`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ name: "Party Car", model: readFileSync(path.join(root, "models/car.ldr"), "utf8") }),
  });
  const published = await reply.json().catch(() => ({}));
  if (!published.id) throw new Error(`publishing the car: ${reply.status} ${published.error || ""}`);
  link = published.id;
  console.log(`the car published as ${link} (${published.parts} parts), at ${site}`);

  const phone = async (label) => {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
      isMobile: true, hasTouch: true, extraHTTPHeaders: headers });
    const page = await context.newPage();
    page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error/.test(m.text())) errors.push(`${label}: ${m.text().slice(0, 220)}`);
    });
    await page.goto(`${site}/app?view=${link}`, { waitUntil: "domcontentloaded", timeout: 180000 });
    await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", `${label}: the link open`, 900, null, 250);
    return page;
  };

  console.log("\n1. phone A starts a build");
  const a = await phone("A");
  const offered = await where(a, "view_together", 120).catch(() => null);
  if (!check(`Build together on the link's viewer (${offered ? "offered" : "not there"})`, Boolean(offered))) {
    throw new Error("no Build together");
  }
  await shot(a, "a_1_link.png");
  await tap(a, "view_together");
  await tap(a, "party_start");
  const title = await until(a, () => {
    const said = ((window.brickworksShare || {}).view || {}).party || {};
    return /^Code: [A-Z0-9]{4}$/.test(said.title || "") ? said.title : null;
  }, "a code", 30);
  const code = title.slice(-4);
  check(`in a build in 2 taps, with no account: "${title}"`, code.length === 4);
  await shot(a, "a_2_code.png");

  console.log("\n2. phone B joins by it");
  const b = await phone("B");
  await tap(b, "view_together");
  await tap(b, "party_code");
  await b.keyboard.type(code.toLowerCase(), { delay: 40 });
  await shot(b, "b_1_code_typed.png");
  await tap(b, "party_join");
  const joinedAt = Date.now();
  const bothB = await until(b, () => ((((window.brickworksShare || {}).view || {}).party || {}).seats || []).length === 2,
    "B's card naming both", 30).catch(() => false);
  const bothA = await until(a, () => ((((window.brickworksShare || {}).view || {}).party || {}).seats || []).length === 2,
    "A's card naming both", 30).catch(() => false);
  const seen = Date.now() - joinedAt;
  check(`B in with 2 taps and the code typed; both cards name both, A's in ${seen} ms: ${JSON.stringify((await party(a)).seats)}`,
    bothA && bothB && seen < CROSS_MS + 1000);
  await shot(b, "b_2_joined.png");

  console.log("\n3. A deals it out");
  await tap(a, "party_deal");
  const dealtAt = Date.now();
  const openA = await until(a, () => {
    const said = (window.brickworksShare || {}).build || {};
    return said.open && (said.party || {}).on;
  }, "A's Build it on its share", 120).catch(() => false);
  const openB = await until(b, () => {
    const said = (window.brickworksShare || {}).build || {};
    return said.open && (said.party || {}).on;
  }, "B's Build it on its share", 120).catch(() => false);
  check(`both phones' Build it opens on their own share, with no press on B (${((Date.now() - dealtAt) / 1000).toFixed(1)} s)`,
    openA && openB);
  const shareA = (await build(a)).party_share || [];
  const shareB = (await build(b)).party_share || [];
  const both = new Set([...shareA, ...shareB]);
  const twice = shareA.filter((id) => shareB.includes(id)).length;
  check(`the car dealt in two: ${shareA.length} and ${shareB.length} parts, ${both.size} between them, ${twice} on both`,
    shareA.length > 0 && shareB.length > 0 && both.size === PARTS && twice === 0);
  await a.waitForTimeout(1500);
  await shot(a, "a_3_dealt.png");
  await shot(b, "b_3_dealt.png");

  console.log("\n4. a part done crosses in 2 s");
  for (const [from, to, name] of [[a, b, "A"], [b, a, "B"]]) {
    // What the phone has told it has done (its own seat, "me"), before and after one Next:
    // the cover shows the whole share, so the parts on show are no count of parts down.
    const doneOf = (state) => ((state.party_state?.seats || []).find((one) => one.me) || {}).done || 0;
    const before = doneOf(await build(from));
    await tap(from, "build_next");
    const tapped = Date.now();
    const mine = await until(from, (was) => {
      const seats = ((((window.brickworksShare || {}).build || {}).party_state || {}).seats) || [];
      const done = (seats.find((one) => one.me) || {}).done || 0;
      return done > was ? done : null;
    }, `${name}'s part down`, 20, before).catch(() => 0);
    const theirs = await until(to, ([who, wanted]) => {
      const chips = (((window.brickworksShare || {}).build || {}).party || {}).chips || [];
      const chip = chips.find((one) => String(one).startsWith(who) && !String(one).includes("(you)")) || "";
      const done = Number((/ (\d+) of \d+$/.exec(chip) || [0, -1])[1]);
      return done >= wanted ? chip : null;
    }, `${name}'s part on the other phone`, 10, [name === "A" ? "Builder 1" : "Builder 2", mine], 50).catch(() => "");
    const ms = Date.now() - tapped;
    check(`${name}'s Next: ${mine} of its parts down, on the other phone in ${ms} ms ("${theirs}")`,
      mine > before && Boolean(theirs) && ms < CROSS_MS);
  }
  await shot(b, "b_4_progress.png");

  console.log("\n5. B leaves and joins again");
  await tap(b, "build_next");
  await b.waitForTimeout(800);
  const place = await build(b);
  await tap(b, "build_close");
  await tap(b, "party_leave");
  const told = await until(a, () => ((((window.brickworksShare || {}).build || {}).party || {}).chips || [])
    .some((one) => /has left$/.test(String(one))), "A told B left", 10).catch(() => false);
  check(`B left: A is told within 10 s ("${chipOf((await build(a)).party?.chips, "Builder 2")}")`, Boolean(told));
  const kept = (await party(b)).code_typed || "";
  await shot(b, "b_5_left.png");
  await tap(b, "party_join");
  const backIn = await until(b, () => {
    const said = (window.brickworksShare || {}).build || {};
    return said.open && (said.party || {}).on;
  }, "B's Build it back", 120).catch(() => false);
  await b.waitForTimeout(1500);
  const back = await build(b);
  check(`Join with the code kept (${kept}): B's seat ${back.party_state?.seat}, page ${back.page} part ${back.part}`
    + ` (it was on ${place.page}, ${place.part}), its share the same`,
    backIn && kept.toUpperCase() === code && back.party_state?.seat === 2 && back.page === place.page && back.part === place.part
    && (back.party_share || []).length === shareB.length);

  console.log("\n6. both finish: the joining step");
  await a.keyboard.press("End");
  const waiting = await until(a, () => {
    const said = (window.brickworksShare || {}).build || {};
    return (said.party || {}).waiting ? said : null;
  }, "A waiting", 30).catch(() => null);
  check(`A at its end waits: "${waiting?.caption}", "${waiting?.note}", Next held`,
    Boolean(waiting) && waiting.caption === "Your part is built" && /^Waiting for Builder 2/.test(waiting.note || "")
    && waiting.party.next_held);
  await shot(a, "a_6_waiting.png");
  await b.keyboard.press("End");
  const ended = Date.now();
  const joinA = await until(a, () => (((window.brickworksShare || {}).build || {}).party || {}).joining,
    "A on the joining step", 10).catch(() => false);
  const msA = Date.now() - ended;
  const joinB = await until(b, () => (((window.brickworksShare || {}).build || {}).party || {}).joining,
    "B on the joining step", 10).catch(() => false);
  await a.waitForTimeout(1500);
  const lastA = await build(a);
  const lastB = await build(b);
  check(`both on the joining step, A within ${msA} ms of B's last: "${lastA.caption}" / "${lastB.caption}", `
    + `${lastA.shown} and ${lastB.shown} parts on show, nothing to pick up (${lastA.lots}, ${lastB.lots})`,
    joinA && joinB && msA < CROSS_MS && lastA.caption === "Put it together" && lastB.caption === "Put it together"
    && lastA.shown === PARTS && lastB.shown === PARTS && lastA.lots === 0 && lastB.lots === 0);
  await shot(a, "a_7_joining.png");
  await shot(b, "b_7_joining.png");
  check(`no script errors on either phone${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""}`, errors.length === 0);
} catch (trouble) {
  check(`the flow ran: ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  await browser.close();
  if (link) {
    await fetch(`${site}/api/share?op=unpublish&id=${link}`, { method: "POST",
      headers: { ...headers, authorization: `Bearer ${token}` } }).catch(() => {});
  }
  if (token) check(`the probe account deleted, and its link with it (${probe})`, await deleteAccount(probe));
  if (server) server.kill();
}
console.log(failed ? `\n${failed} FAILED` : "\ntwo phones built the car together, each its own share, and put it together");
process.exit(failed ? 1 : 0);
