// Share a model you made, from its file, in real browsers (bringyours,
// 2026-11-20): /share-model, web/share-model.js, web/studio-io.js.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/share_model_flow.mjs --url=<deployment> --out=DIR
//   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 10840 &
//   node tools/web/share_model_flow.mjs --url=http://127.0.0.1:10840 --out=DIR
//
// The run's own throwaway account (browser.mjs ownAccount), deleted with
// what it shared when the run ends; a second, answered under 13, made and
// deleted here. docs/SOCIAL.md round 8's bar, each clause:
//
//   1, 2. A 353-part LDraw .mpd at 1280x800, and the same model as a
//      locked Studio .io (BOM, CRLF, "0 FILE x.io", Studio's password, as a
//      2021 file is) on a 390x844 phone: file chosen to its live /m/<id>
//      page within 60 s and 120 s, with one tap (Share it) after choosing.
//   3. Its parts list (/m/<id>/parts.json pieces) and its row's count are
//      the server's own count of the file (api/share.js checkModel).
//   4. Its steps are the file's (checkModel's steps, and the page says so).
//      It is version 1, with its link picture, page picture and card.
//   5. An LDD .lxf: Open the app, one tap, and nothing sent.
//   6. A picture called .ldr, prose, an empty file, a file with no parts, a
//      zip with no model: each refused in words naming it, nothing sent;
//      a file the server refuses (a line LDraw has no type for): its words
//      shown, the form kept.
//   7. Signed out, Share it asks to sign in first and sends nothing; an
//      account answered under 13 is refused in words and nothing is kept.
//   And Studio's files read in the page: 2021's (PKWARE), AES-256's, and
//   2025's with a Part Designer part, which is shared too.
// Pictures of each state at 1280, 768 and 390 in light and dark in --out.
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { checkModel } from "../../api/share.js";
import { execFileSync } from "node:child_process";
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("share_model_flow: --url=<a deployment> [--out=DIR]");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const out = path.resolve(String(args.out || "shots/share_model"));
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const BAR = { desktop: 60, phone: 120 };

const fails = [];
const ok = (yes, what) => {
  console.log(`${yes ? "PASS" : "FAIL"} ${what}`);
  if (!yes) fails.push(what);
  return yes;
};

// ---------------------------------------------------------------------------
// The files a person might choose.

const files = path.join(out, "files");
rmSync(files, { recursive: true, force: true });
mkdirSync(files, { recursive: true });
const at = (name) => path.join(files, name);
const rocket = readFileSync(path.join(root, "models/three_core_rocket.ldr"), "utf8");
const rocketBody = rocket.split(/\r?\n/).filter((line) => !/^0\s+(?:Name:|Author:)/.test(line)).slice(1).join("\n");
writeFileSync(at("three_core_rocket.mpd"), `0 FILE three_core_rocket.ldr\n${rocket}`);
// Studio 2.2's way: a zip locked with its one password, model.ldr with a
// byte-order mark and Windows line ends, named for the file, Untitled.
const studio = `﻿${["0 FILE rocket.io", "0 Untitled Model", "0 Name:  rocket", "0 Author:  ", rocketBody].join("\r\n")}`;
const zipDir = path.join(files, "io");
mkdirSync(zipDir, { recursive: true });
writeFileSync(path.join(zipDir, "model.ldr"), studio);
writeFileSync(path.join(zipDir, "model2.ldr"), studio);
writeFileSync(path.join(zipDir, ".info"), "{}");
execFileSync("zip", ["-q", "-X", "-P", "soho0909", at("rocket.io"), "model.ldr", "model2.ldr", ".info"], { cwd: zipDir, stdio: "ignore" });
copyFileSync(path.join(root, "web/favicon-32.png"), at("picture.ldr"));
writeFileSync(at("notes.txt"), "Shopping list\nmilk\nbread\n");
writeFileSync(at("empty.ldr"), "");
writeFileSync(at("title_only.ldr"), "0 Just a title\n0 Name: title_only.ldr\n0 STEP\n");
copyFileSync(path.join(root, "tests/fixtures/studio/libarchive_aes256.zip"), at("no_model.io"));
writeFileSync(at("wrong_line.ldr"), "0 Wrong line\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\nhello there\n");
copyFileSync(path.join(root, "src/dev/fixtures/49311_test.lxf"), at("model.lxf"));
const STUDIO_FIXTURES = path.join(root, "tests/fixtures/studio");

const expected = checkModel(rocket);
console.log(`  (the rocket: the server counts ${expected.parts} parts, ${expected.steps} steps of its own: ${expected.ownSteps})`);

// ---------------------------------------------------------------------------
// Helpers.


async function api(pathname) {
  const reply = await fetch(site + pathname, { headers }).catch(() => null);
  if (!reply) return { status: 0, body: null, type: "" };
  const type = reply.headers.get("content-type") || "";
  const body = type.includes("json") ? await reply.json().catch(() => null) : null;
  return { status: reply.status, body, type };
}

/// A picture as it is served: its status, size, kind by its bytes, and a
/// hash to tell two apart.
async function picture(pathname) {
  let reply = await fetch(site + pathname, { headers }).catch(() => null);
  if (!reply || reply.status >= 500) {
    await new Promise((done) => setTimeout(done, 3000));
    reply = await fetch(site + pathname, { headers }).catch(() => null);
  }
  const bytes = reply && reply.status === 200 ? Buffer.from(await reply.arrayBuffer()) : Buffer.alloc(0);
  return { status: reply?.status ?? 0, size: bytes.length,
    png: bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
    webp: bytes.subarray(0, 4).toString("latin1") === "RIFF" && bytes.subarray(8, 12).toString("latin1") === "WEBP",
    hash: createHash("sha1").update(bytes).digest("hex") };
}

/// Every POST the page sends to /api/share, with its answer's status.
function posts(page) {
  const sent = [];
  page.on("response", (response) => {
    const request = response.request();
    if (request.method() === "POST" && new URL(request.url()).pathname === "/api/share") {
      sent.push({ op: new URL(request.url()).searchParams.get("op") || "publish", status: response.status() });
    }
  });
  return sent;
}

/// A picture of the page; how long it took, in milliseconds.
async function shot(page, name) {
  const begun = Date.now();
  await page.screenshot({ path: path.join(out, `${name}.png`), fullPage: false }).catch(() => {});
  return Date.now() - begun;
}

async function choose(page, name, from = files) {
  await page.setInputFiles("#file", path.join(from, name));
}

/// What the page says of a file refused, once it says it.
async function refusal(page) {
  await page.waitForSelector("#refused:not([hidden])", { timeout: 15000 }).catch(() => null);
  return (await page.locator("#refused").textContent().catch(() => "")) || "";
}

/// [file] chosen and shared with one tap; how long to its page, and its id.
///
/// Its form's picture is taken while the page waits for the tap, and that
/// time is left out (said); a picture while it works ([working]) is taken
/// as it works, so it is counted in, as a slower share.
/// [twice]: Enter pressed twice in the name, as a quick hand does: one
/// share all the same.
async function shareOne(page, file, { from = files, phone = false, shotName = "", working = false, twice = false, bar = BAR.desktop,
  name = null } = {}) {
  const sent = posts(page);
  await page.goto(`${site}/share-model`, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.brickworksShare, null, { timeout: 30000 });
  const started = Date.now();
  let waiting = 0;
  // The page's own marks (chosen, read, share, published, drawn, done), read
  // as it goes, since its address changes at the end.
  let timings = {};
  const watch = setInterval(() => {
    page.evaluate(() => JSON.stringify(window.brickworksShare?.timings || {}))
      .then((said) => { timings = { ...timings, ...JSON.parse(said) }; }).catch(() => {});
  }, 250);
  await choose(page, file, from);
  await page.waitForSelector("#details:not([hidden])", { timeout: 20000 });
  const named = await page.inputValue("#name");
  if (name !== null) ok(named === name, `${file}: named "${named}" from the file (want "${name}")`);
  if (shotName) waiting += await shot(page, `${shotName}_details`);
  let taps = 0;
  if (twice) {
    await page.focus("#name");
    await page.keyboard.press("Enter");
    await page.keyboard.press("Enter");
  } else if (phone) await page.tap("#share"); else await page.click("#share");
  taps += 1;
  if (shotName && working) {
    await page.waitForSelector("#working:not([hidden])", { timeout: 15000 }).catch(() => null);
    await page.waitForFunction(() => window.brickworks3d?.state === "ready", null, { timeout: 90000 }).catch(() => null);
    await shot(page, `${shotName}_working`);
  }
  const arrived = await page.waitForURL(/\/m\/[A-Za-z0-9]{10}(?:[?#].*)?$/, { timeout: 240000, waitUntil: "domcontentloaded" })
    .then(() => true).catch(() => false);
  clearInterval(watch);
  const seconds = (Date.now() - started - waiting) / 1000;
  const id = arrived ? new URL(page.url()).pathname.split("/").pop() : "";
  const at = (from_, to) => (timings[from_] !== undefined && timings[to] !== undefined
    ? `${((timings[to] - timings[from_]) / 1000).toFixed(1)} s` : "?");
  const rest = timings.chosen !== undefined && timings.drawn !== undefined
    ? `${(seconds - (timings.drawn - timings.chosen - waiting) / 1000).toFixed(1)} s` : "?";
  console.log(`  (${file}: read ${at("chosen", "read")}, sent ${at("share", "published")}, drawn ${at("published", "drawn")}, `
    + `then put on its page and shown ${rest}; ${(waiting / 1000).toFixed(1)} s of the form's picture left out)`);
  const said = arrived ? "" : await page.evaluate(() => JSON.stringify(window.brickworksShare)).catch(() => "");
  ok(arrived, `${file}: its own page /m/${id} ${arrived ? `in ${seconds.toFixed(1)} s` : `never came (${said.slice(0, 300)})`}`);
  ok(arrived && seconds <= bar, `${file}: chosen to a live page in ${seconds.toFixed(1)} s, at most ${bar} s`);
  ok(taps <= 4, `${file}: ${taps} tap after choosing (Share it), at most 4`);
  if (shotName && arrived) {
    await page.waitForLoadState("load").catch(() => {});
    await shot(page, `${shotName}_page`);
  }
  console.log(`  (${file}: POSTs ${sent.map((one) => `${one.op} ${one.status}`).join(", ")})`);
  const ops = sent.filter((one) => ["publish", "unpublish"].includes(one.op)).map((one) => one.op).join(",");
  ok(!arrived || ops === "publish,unpublish,publish", `${file}: one share sent${twice ? " for Enter pressed twice" : ""} (${ops})`);
  return { id, seconds, taps };
}

/// The server's own word on [id] against the file's: its count, its parts
/// list, its steps, version 1 and its pictures.
async function judge(id, file, text) {
  const want = checkModel(text);
  const row = await api(`/api/share?id=${id}`);
  ok(row.status === 200, `${file}: /api/share?id=${id} answers 200 (${row.status})`);
  const body = row.body || {};
  ok(body.parts === want.parts, `${file}: the server counts ${body.parts} parts, the file's count is ${want.parts}`);
  const list = await api(`/m/${id}/parts.json`);
  ok(list.body?.pieces === want.parts, `${file}: its parts list has ${list.body?.pieces} pieces, the server's count ${want.parts}`);
  // The version's own steps (null for a file that lays out none), as the
  // server keeps them for its page.
  const versions = body.versions || [];
  const steps = versions[0] ? versions[0].steps : undefined;
  ok(steps === want.steps, `${file}: ${steps} steps, the file's own ${want.steps}`);
  ok(versions.length === 1 && versions[0]?.n === 1, `${file}: version 1 only (${versions.map((one) => one.n).join(",")})`);
  // Its three pictures: each is answered only when it was kept (api/share.js
  // answers 404 for a model without one), and the page's cut-out is its own,
  // not the link picture again.
  const image = await picture(`/m/${id}.png`);
  ok(image.png, `${file}: its link picture kept, a PNG (${image.status}, ${image.size} bytes)`);
  const card = await picture(`/m/${id}.webp`);
  ok(card.webp, `${file}: its gallery card kept, a WebP (${card.status}, ${card.size} bytes)`);
  const cutout = await picture(`/m/${id}.cutout.png`);
  ok(cutout.png && cutout.hash !== image.hash, `${file}: its page's cut-out kept, its own (${cutout.status}, ${cutout.size} bytes)`);
  return body;
}

// ---------------------------------------------------------------------------

mkdirSync(out, { recursive: true });
const browser = await launch({ ownAccount: true });
const signedOut = await launch({ signedOut: true });
const young = `delivered+bw-sharemodel-${randomBytes(4).toString("hex")}@resend.dev`;
const made = [];
try {
  // Desktop: the refusals, LDD, Studio's files, the server's refusal.
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 }, extraHTTPHeaders: headers });
  const page = await context.newPage();
  const sent = posts(page);
  await page.goto(`${site}/share-model`, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.brickworksShare, null, { timeout: 30000 });
  await shot(page, "1280_choose");
  for (const [file, words] of [["picture.ldr", /not text/], ["notes.txt", /not a model file/], ["empty.ldr", /empty/],
    ["title_only.ldr", /no parts/], ["no_model.io", /no model in it/]]) {
    await page.evaluate(() => { document.getElementById("refused").hidden = true; });
    await choose(page, file);
    const said = await refusal(page);
    ok(words.test(said) && said.includes(file), `${file} refused in words: "${said.trim().slice(0, 140)}"`);
  }
  await shot(page, "1280_refused");
  await choose(page, "model.lxf");
  await page.waitForSelector("#ldd:not([hidden])", { timeout: 10000 }).catch(() => null);
  const ldd = await page.locator("#ldd-open").getAttribute("href").catch(() => "");
  const lddShown = await page.locator("#ldd-open").isVisible().catch(() => false);
  ok(lddShown && /^(?:\/[a-z]{2})?\/app$/.test(ldd || ""), `model.lxf: Open the app, one tap (${ldd})`);
  await shot(page, "1280_lxf");
  for (const [file, name] of [["bay_2021.io", "bay_2021"], ["bay_aes.io", "bay_2021"], ["decor_2025.io", "decor_2025"], ["gatehouse_2025.io", "Gatehouse"]]) {
    await choose(page, file, STUDIO_FIXTURES);
    const shown = await page.waitForSelector("#details:not([hidden])", { timeout: 15000 }).then(() => true).catch(() => false);
    const named = shown ? await page.inputValue("#name") : "";
    const read = shown ? await page.locator("#read").textContent() : await refusal(page);
    ok(shown && named === name, `${file} read in the page: named "${named}" (${read.trim().slice(0, 120)})`);
    await page.click("#again");
  }
  // The form's own limits, as the server's (api/share.js): said in words
  // under the field, nothing sent; an invisible character is no name.
  await choose(page, "three_core_rocket.mpd");
  await page.waitForSelector("#details:not([hidden])", { timeout: 15000 });
  await page.fill("#name", "x".repeat(81));
  await page.click("#share");
  const longName = (await page.locator("#name-said:not([hidden])").textContent({ timeout: 5000 }).catch(() => "")) || "";
  ok(/80/.test(longName), `a name of 81 characters refused in words ("${longName.trim()}")`);
  await page.fill("#name", "\u200b \u2060");
  await page.click("#share");
  const blankName = (await page.locator("#name-said:not([hidden])").textContent({ timeout: 5000 }).catch(() => "")) || "";
  ok(blankName.trim().length > 5, `a name of invisible characters refused in words ("${blankName.trim()}")`);
  await page.fill("#name", "Rocket");
  await page.fill("#about", "y".repeat(1001));
  await page.click("#share");
  const longAbout = (await page.locator("#about-said:not([hidden])").textContent({ timeout: 5000 }).catch(() => "")) || "";
  ok(/1[,.\u00a0\u202f]?000/.test(longAbout), `words of 1001 characters refused in words ("${longAbout.trim()}")`);
  ok(sent.length === 0, `nothing sent for any of those (${sent.length} POSTs)`);
  await page.fill("#about", "");
  await choose(page, "wrong_line.ldr");
  await page.waitForSelector("#details:not([hidden])", { timeout: 15000 });
  await page.click("#share");
  await page.waitForSelector("#form-said:not([hidden])", { timeout: 60000 }).catch(() => null);
  const serverSaid = (await page.locator("#form-said").textContent().catch(() => "")) || "";
  ok(serverSaid.trim().length > 10 && await page.locator("#details").isVisible(),
    `a line LDraw has no type for: the server's words, the form kept ("${serverSaid.trim().slice(0, 140)}")`);
  ok(sent.every((one) => one.status >= 400), `and nothing kept (${sent.map((one) => one.status).join(",")})`);
  await shot(page, "1280_server_refused");
  await context.close();

  // Clauses 1-4 at 1280: the .mpd.
  const desk = await browser.newContext({ viewport: { width: 1280, height: 800 }, extraHTTPHeaders: headers });
  const deskPage = await desk.newPage();
  const one = await shareOne(deskPage, "three_core_rocket.mpd", { shotName: "1280_share", name: "A three-core heavy-lift rocket" });
  if (one.id) { made.push(one.id); await judge(one.id, "three_core_rocket.mpd", rocket); }
  const page3d = one.id ? await deskPage.locator("body").textContent().catch(() => "") : "";
  ok(!one.id || new RegExp(`${expected.steps}\\s+steps`).test(page3d), `three_core_rocket.mpd: its page says ${expected.steps} steps`);
  // A Studio 2025 file with a Part Designer part, shared.
  const custom = await shareOne(deskPage, "bay_2025.io", { from: STUDIO_FIXTURES, name: "bay_2025", shotName: "1280_bay", working: true, twice: true });
  if (custom.id) {
    made.push(custom.id);
    const { readStudioIo } = await import("../../web/studio-io.js");
    const read = await readStudioIo(readFileSync(path.join(STUDIO_FIXTURES, "bay_2025.io")));
    await judge(custom.id, "bay_2025.io", read.text);
  }
  await desk.close();

  // Clauses 1-4 on a phone: the locked Studio file.
  const phone = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
    extraHTTPHeaders: headers });
  const phonePage = await phone.newPage();
  const two = await shareOne(phonePage, "rocket.io", { phone: true, shotName: "390_share", bar: BAR.phone, name: "rocket" });
  if (two.id) { made.push(two.id); await judge(two.id, "rocket.io", studio); }
  await phone.close();

  // Clause 7: signed out, Share asks to sign in and sends nothing.
  const out1 = await signedOut.newContext({ viewport: { width: 1280, height: 800 }, extraHTTPHeaders: headers });
  const outPage = await out1.newPage();
  const outSent = posts(outPage);
  await outPage.goto(`${site}/share-model`, { waitUntil: "domcontentloaded" });
  await outPage.waitForFunction(() => window.brickworksShare, null, { timeout: 30000 });
  await choose(outPage, "three_core_rocket.mpd");
  await outPage.waitForSelector("#details:not([hidden])", { timeout: 15000 });
  await outPage.click("#share");
  const asked = await outPage.waitForSelector("dialog.sign-in[open]", { timeout: 15000 }).then(() => true).catch(() => false);
  ok(asked, "signed out: Share it asks to sign in first");
  await shot(outPage, "1280_signed_out");
  ok(outSent.length === 0, `signed out: nothing sent (${outSent.length} POSTs)`);
  await out1.close();

  // Clause 7: an account answered under 13.
  const minted = await mintSession(young, { age: false });
  await answerAge(minted.kept.user_id, young, false);
  const kid = await signedOut.newContext({ viewport: { width: 1280, height: 800 }, extraHTTPHeaders: headers });
  await kid.addInitScript(([name, value]) => { try { localStorage.setItem(name, value); } catch {} }, [STORAGE_KEY, JSON.stringify(minted.kept)]);
  const kidPage = await kid.newPage();
  const kidSent = posts(kidPage);
  await kidPage.goto(`${site}/share-model`, { waitUntil: "domcontentloaded" });
  await kidPage.waitForFunction(() => window.brickworksShare, null, { timeout: 30000 });
  await choose(kidPage, "three_core_rocket.mpd");
  await kidPage.waitForSelector("#details:not([hidden])", { timeout: 15000 });
  await kidPage.click("#share");
  const kidWords = await Promise.race([
    kidPage.waitForSelector("#form-said:not([hidden])", { timeout: 60000 }).then(() => kidPage.locator("#form-said").textContent()),
    kidPage.waitForSelector("dialog[open] .too-young, dialog[open] #age-refused", { timeout: 60000 }).then((el) => el.textContent()),
  ]).catch(() => "");
  ok(/13/.test(kidWords || ""), `under 13: refused in words ("${String(kidWords).trim().slice(0, 160)}")`);
  ok(!kidSent.some((one) => one.status < 300), `under 13: nothing kept (${kidSent.map((one) => one.status).join(",") || "nothing sent"})`);
  await shot(kidPage, "1280_under_13");
  await kid.close();

  // Each state's picture at 1280, 768 and 390, light and dark.
  for (const [width, height] of [[1280, 800], [768, 1024], [390, 844]]) {
    for (const scheme of ["light", "dark"]) {
      const look = await browser.newContext({ viewport: { width, height }, colorScheme: scheme, extraHTTPHeaders: headers,
        ...(width < 600 ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
      const lookPage = await look.newPage();
      await lookPage.goto(`${site}/share-model`, { waitUntil: "load" });
      await lookPage.waitForFunction(() => window.brickworksShare, null, { timeout: 30000 });
      await lookPage.screenshot({ path: path.join(out, `look_${width}_${scheme}_choose.png`) });
      await choose(lookPage, "three_core_rocket.mpd");
      await lookPage.waitForSelector("#details:not([hidden])", { timeout: 15000 });
      // In the window, as a person sees it (a whole-page picture of a phone
      // draws its controls as a mouse's).
      await lookPage.locator("#details").evaluate((form) => form.scrollIntoView({ block: "start" }));
      await lookPage.screenshot({ path: path.join(out, `look_${width}_${scheme}_details.png`) });
      const wide = await lookPage.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      ok(wide <= 0, `${width} ${scheme}: nothing wider than the window (${wide} px over)`);
      await lookPage.goto(`${site}/gallery`, { waitUntil: "load" });
      const yours = lookPage.locator(".gallery-head .share-yours");
      const box = await yours.boundingBox().catch(() => null);
      ok(Boolean(box) && box.width >= 44 && box.height >= 44 && box.x + box.width <= width,
        `${width} ${scheme}: the gallery's Share yours is on screen, ${box ? `${Math.round(box.width)}x${Math.round(box.height)}` : "missing"}`);
      await lookPage.screenshot({ path: path.join(out, `look_${width}_${scheme}_gallery.png`) });
      await look.close();
    }
  }
} catch (trouble) {
  ok(false, `the run stopped: ${trouble.stack || trouble}`);
} finally {
  await deleteAccount(young).catch(() => {});
  await signedOut.close().catch(() => {});
  await browser.close().catch(() => {});
}
writeFileSync(path.join(out, "result.json"), JSON.stringify({ made, fails }, null, 2));
console.log(fails.length ? `share_model_flow: FAIL (${fails.length}): ${fails.join("; ")}` : "share_model_flow: PASS");
process.exit(fails.length ? 1 : 0);
