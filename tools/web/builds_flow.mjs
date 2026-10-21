// Real builds, in real browsers: a build finished in the step player counted
// once per device, and "I built it" photos made safe, shown, hidden by the
// model's owner, reported and taken out (supabase/builds.sql).
//
//   tools/export.sh web
//   node --env-file=.env tools/web/relay_server.mjs 9104 --static=build/web \
//     --hold=model_builds,build_photos,report_photos --trust-stand-in &
//   node --env-file=.env tools/web/builds_flow.mjs --url=http://127.0.0.1:9104 --out=shots/builds
//
// Until builds.sql (and trust.sql) are applied, the local relay holds the new
// tables and the two storage buckets in memory (--hold, held_tables.mjs) and
// answers the age question's functions (--trust-stand-in); everything else
// is the real project: the accounts, the models' rows and files, the reports.
// Against a deployment (a preview: BW_BYPASS=$VERCEL_BYPASS) what is kept is
// read from the project itself with the secret key, this flow's rows and
// files only.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/builds_flow.mjs --url=<preview> --out=DIR
//
//   1. A throwaway owner lists a model of three steps. On a phone-sized page
//      (390 x 844, touch) a visitor opens its viewer, presses Build it and
//      Next to the last step: the app sends one finish and the model is
//      built once. Back and Next onto the last step again, and the page
//      reloaded and the last step reached again, send nothing more and the
//      count stays at one. The model's page says "1 built", its gallery card
//      too, and Most built puts it ahead of every card built less. A
//      robot's finish is not counted, nor the same device's twice; the
//      desktop app's is.
//   2. A builder (13 or over, with a profile) adds a photo from the model's
//      page: a JPEG drawn here with Exif in it — GPS, a phone's make, which
//      way up it was held — and a comment. What comes back from the server
//      has none of it, read from its bytes: JFIF and the picture, no Exif,
//      no comment, no GPS, turned upright as the phone held it. The
//      original is gone from storage. The photo is in the strip and on the
//      builder's profile.
//   3. An account that said it is under 13 is refused, in words.
//   4. The model's owner hides the photo: gone from the strip and from its
//      address for everybody else; shown again.
//   5. A visitor reports the photo from its Report it; the site's owner
//      (MASTER_EMAIL, signed in as the tests are, no email sent) sees it on
//      the admin page with the photo, and takes it out: its file is deleted
//      from storage and it is shown nowhere.
//
// Pictures in --out. The throwaway accounts are deleted at the end with
// everything of theirs, their models taken down first.
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { placed } from "./gallery_order.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:9104").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/builds"));
mkdirSync(out, { recursive: true });
// A preview is behind Vercel's protection: every request to it, the pages'
// too, says the bypass. Without it the listing was Vercel's 401 and the
// viewer its sign-in page (m81).
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const secret = { apikey: process.env.SUPABASE_SECRET_KEY || "", authorization: `Bearer ${process.env.SUPABASE_SECRET_KEY || ""}` };
// The local relay holds builds.sql's tables (/__held); a deployment has none.
const local = (await fetch(`${site}/__held/model_builds`, { headers }).catch(() => null))?.ok === true;
// The relay stands in for trust.sql's functions: ages are answered there too.
if (local) process.env.BW_STAND_IN = process.env.BW_STAND_IN || site;
// The app: the relay serves this checkout's build/web; a deployment has its own.
const withApp = !args["no-app"] && (!local || existsSync(path.join(root, "build/web/index.html")));
const { decode, encode } = await import(path.join(root, "api/_jpeg.js"));
const rand = randomBytes(4).toString("hex");
const owner = `delivered+bw-builds-owner-${rand}@resend.dev`;
const builder = `delivered+bw-builds-builder-${rand}@resend.dev`;
const young = `delivered+bw-builds-young-${rand}@resend.dev`;
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${rand}`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

// --- a model and a photo, made here --------------------------------------------

/// Three 2 x 4 bricks stacked, one a step.
function stack(name) {
  const lines = [`0 ${name}`, `0 Name: ${name.toLowerCase().replace(/\s+/g, "_")}.ldr`, "0 Author: Builds Flow", ""];
  [0, -24, -48].forEach((y, n) => {
    lines.push(`1 ${[4, 1, 14][n]} 0 ${y} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  });
  return `${lines.join("\r\n")}\r\n`;
}

/// A picture of a brick, drawn: 960 x 640, a yellow mark at its top left.
function drawn() {
  const width = 960;
  const height = 640;
  const data = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const at = (y * width + x) * 4;
      const brick = x > 200 && x < 760 && y > 260 && y < 520;
      const stud = y > 200 && y <= 260 && [260, 400, 540, 680].some((c) => Math.abs(x - c) < 40);
      const mark = x < 140 && y < 140;
      const [r, g, b] = mark ? [250, 220, 0] : brick || stud ? [200, 24, 32] : [40, 90, 160];
      data[at] = r; data[at + 1] = g; data[at + 2] = b; data[at + 3] = 255;
    }
  }
  return { width, height, data };
}

/// Exif as a phone writes it: its make, which way up it was held (6: turned
/// a quarter), and where it was, in a GPS directory: 61°13'4.5" N, 149°54'2.25" W.
function exif() {
  const entries0 = [];
  const data = [];
  const tiff = [];
  const u16 = (n) => [n & 255, n >> 8];
  const u32 = (n) => [n & 255, (n >> 8) & 255, (n >> 16) & 255, (n >>> 24) & 255];
  const make = Buffer.from("FlowPhone Maker\0", "latin1");
  // IFD0: 3 entries at 8; GPS IFD after it; then the data.
  const ifd0 = 8;
  const ifd0Size = 2 + 3 * 12 + 4;
  const gps = ifd0 + ifd0Size;
  const gpsSize = 2 + 4 * 12 + 4;
  let dataAt = gps + gpsSize;
  const place = (bytes) => { const at = dataAt; data.push(...bytes); dataAt += bytes.length; return at; };
  const makeAt = place([...make]);
  const rational = (parts) => parts.flatMap(([n, d]) => [...u32(n), ...u32(d)]);
  const latAt = place(rational([[61, 1], [13, 1], [45, 10]]));
  const lonAt = place(rational([[149, 1], [54, 1], [225, 100]]));
  entries0.push([0x010f, 2, make.length, makeAt], [0x0112, 3, 1, 6], [0x8825, 4, 1, gps]);
  tiff.push(...Buffer.from("II", "latin1"), ...u16(42), ...u32(ifd0));
  tiff.push(...u16(entries0.length));
  for (const [tag, type, n, value] of entries0) tiff.push(...u16(tag), ...u16(type), ...u32(n), ...(type === 3 ? [...u16(value), 0, 0] : u32(value)));
  tiff.push(...u32(0));
  const gpsEntries = [[1, 2, 2, [78, 0, 0, 0]], [2, 5, 3, u32(latAt)], [3, 2, 2, [87, 0, 0, 0]], [4, 5, 3, u32(lonAt)]];
  tiff.push(...u16(gpsEntries.length));
  for (const [tag, type, n, value] of gpsEntries) tiff.push(...u16(tag), ...u16(type), ...u32(n), ...value);
  tiff.push(...u32(0), ...data);
  return Buffer.concat([Buffer.from("Exif\0\0", "latin1"), Buffer.from(tiff)]);
}

/// A segment: marker, length, body.
const segment = (marker, body) => Buffer.concat([Buffer.from([0xff, marker, (body.length + 2) >> 8, (body.length + 2) & 255]), body]);

/// A JPEG's markers up to its picture, in order: "e0", "e1", "fe"...
function markers(bytes) {
  const found = [];
  let at = 2;
  while (at + 4 <= bytes.length && bytes[at] === 0xff) {
    const marker = bytes[at + 1];
    found.push(marker.toString(16));
    if (marker === 0xda) break;
    at += 2 + bytes.readUInt16BE(at + 2);
  }
  return found;
}

/// Where a JPEG's Exif says it was, read back: "61°13'4.5\"N 149°54'2.25\"W", or "".
function whereFrom(bytes) {
  const at = bytes.indexOf(Buffer.from("Exif\0\0", "latin1"));
  if (at < 0) return "";
  const t = bytes.subarray(at + 6);
  const u16 = (o) => t.readUInt16LE(o);
  const u32 = (o) => t.readUInt32LE(o);
  const ifd = u32(4);
  let gps = 0;
  for (let n = 0; n < u16(ifd); n += 1) if (u16(ifd + 2 + n * 12) === 0x8825) gps = u32(ifd + 2 + n * 12 + 8);
  if (!gps) return "";
  const said = {};
  for (let n = 0; n < u16(gps); n += 1) {
    const e = gps + 2 + n * 12;
    const tag = u16(e);
    if (tag === 1 || tag === 3) said[tag] = String.fromCharCode(t[e + 8]);
    if (tag === 2 || tag === 4) {
      const o = u32(e + 8);
      said[tag] = [0, 1, 2].map((k) => u32(o + k * 8) / u32(o + k * 8 + 4));
    }
  }
  const dms = (v) => `${v[0]}°${v[1]}'${v[2]}"`;
  return said[2] ? `${dms(said[2])}${said[1]} ${dms(said[4])}${said[3]}` : "";
}

const picture = drawn();
const plain = encode(picture, 90).data;
const original = Buffer.concat([plain.subarray(0, 2), segment(0xe1, exif()),
  segment(0xfe, Buffer.from("taken at 12 Flow Street, GPS 61.2179 -149.9006", "latin1")), plain.subarray(2)]);
const photoFile = path.join(out, "build_with_gps.jpg");
writeFileSync(photoFile, original);
const was = whereFrom(original);
check(`the photo to send has Exif, GPS and a comment in it: ${was}, ${markers(original).join(",")}`,
  /61°13'4.5"N 149°54'2.25"W/.test(was) && markers(original).includes("e1") && markers(original).includes("fe")
  && original.includes(Buffer.from("FlowPhone")));

// --- helpers -------------------------------------------------------------------

const browser = await launch({ signedOut: true });

async function context({ as = null, phone = false } = {}) {
  const made = await browser.newContext({ userAgent: PERSON, extraHTTPHeaders: headers,
    ...(phone ? { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true }
      : { viewport: { width: 1280, height: 900 } }) });
  if (as) {
    const { kept } = await mintSession(as);
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(kept)]);
  }
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

async function until(page, test, what, seconds = 240, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}

const controls = (page) => page.evaluate(() => window.brickworksControls || {});

async function tap(page, name, seconds = 60) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const at = (await controls(page))[name];
    if (at) {
      await page.touchscreen.tap(at.x, at.y);
      return at;
    }
    if (Date.now() > end) throw new Error(`no ${name} on the page`);
    await page.waitForTimeout(500);
  }
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(token, pathname, body, method = "POST", extra = {}) {
  const reply = await fetch(`${site}${pathname}`, { method,
    headers: { ...headers, "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}), ...extra },
    body: method === "GET" ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

/// On a deployment the model's page and a photo's file are kept at the CDN
/// for 30 s and served stale for 30 more (SHARED_CACHE, photoServe): a photo
/// added, hidden or taken out shows there within a minute, as promised, not
/// at once. [test] asked again every 5 s for up to 90 s (once on the local
/// relay, which keeps nothing): {value, waited} with waited in seconds.
async function fresh(test) {
  const began = Date.now();
  for (;;) {
    const value = await test();
    const waited = Math.round((Date.now() - began) / 1000);
    if (value || local || waited >= 90) return { value, waited };
    await new Promise((done) => setTimeout(done, 5000));
  }
}
const photoStatus = async (one) => (await fetch(`${site}/api/people?op=photo_file&id=${one}`, { headers })).status;

const builds = async (id) => (await api(null, `/api/share?id=${id}`, null, "GET")).body.builds;
/// The rows of [table] whose [column] is [value]: held by the local relay, or
/// the project's, read with the secret key.
async function held(table, column, value) {
  if (local) return (await (await fetch(`${site}/__held/${table}`)).json()).filter((row) => row[column] === value);
  const reply = await fetch(`${SUPABASE}/rest/v1/${table}?${column}=eq.${encodeURIComponent(value)}&select=*`, { headers: secret });
  if (!reply.ok) throw new Error(`${table}: ${reply.status}`);
  return reply.json();
}

/// The files in [bucket] whose names begin with [prefix], {name, bytes}: held
/// by the local relay, or listed from the project's storage.
async function stored(bucket, prefix) {
  if (local) return (await (await fetch(`${site}/__held_storage/list/${bucket}`)).json()).filter((file) => file.name.startsWith(prefix));
  const folder = prefix.includes("/") ? prefix.slice(0, prefix.lastIndexOf("/")) : "";
  const search = prefix.slice(folder ? folder.length + 1 : 0);
  const reply = await fetch(`${SUPABASE}/storage/v1/object/list/${bucket}`, { method: "POST",
    headers: { ...secret, "content-type": "application/json" }, body: JSON.stringify({ prefix: folder, search, limit: 1000 }) });
  if (!reply.ok) throw new Error(`storage ${bucket}: ${reply.status}`);
  return (await reply.json()).filter((one) => one.id).map((one) => ({ name: folder ? `${folder}/${one.name}` : one.name,
    bytes: one.metadata?.size })).filter((file) => file.name.startsWith(prefix));
}

let ownerToken = "";
let id = "";
let photo = "";
try {
  console.log("a model of three steps, listed");
  ownerToken = (await mintSession(owner)).access_token;
  const made = await api(ownerToken, "/api/share", { name: `Builds Flow Tower ${rand}`, model: stack("Builds Flow Tower"), listed: true });
  id = made.body.id || "";
  check(`listed at /m/${id}`, made.status === 201 && Boolean(id));

  // --- 1. a finish, counted once -------------------------------------------------
  if (withApp) {
    console.log("finished on a phone, once");
    const phone = await context({ phone: true });
    const page = await phone.newPage();
    listen(page, "phone");
    await page.goto(`${site}/app?view=${id}`, { waitUntil: "domcontentloaded", timeout: 180000 });
    await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", "the viewer", 600);
    await tap(page, "view_build");
    await until(page, () => ((window.brickworksShare || {}).build || {}).open === true, "the step player", 60);
    const last = (await page.evaluate(() => window.brickworksShare.build)).last;
    for (let n = 1; n <= last; n += 1) {
      await tap(page, "build_next");
      await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, `page ${n}`, 60, n);
    }
    const sent = await until(page, () => {
      const b = ((window.brickworksShare || {}).view || {}).built;
      return b && b.counted ? b : null;
    }, "the finish sent", 60).catch(() => ({}));
    const once = await builds(id);
    check(`Next to the last step (${last}) sends one finish, and the model is built once (${JSON.stringify(sent)}, ${once})`,
      sent.sent === 1 && sent.counted === true && once === 1);
    await shot(page, "1_phone_last_step.png");
    await tap(page, "build_back");
    await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, "back a page", 60, last - 1);
    await tap(page, "build_next");
    await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, "the last page again", 60, last);
    await page.waitForTimeout(3000);
    let again = await page.evaluate(() => window.brickworksShare.view.built);
    check(`Back and Next onto the last step again sends nothing more (${again.sent} sent), still built once (${await builds(id)})`,
      again.sent === 1 && (await builds(id)) === 1);
    // Opened again in the same browser (the address bar says /m/<id> by
    // now, the link's page): what this device kept is all it has.
    await page.goto(`${site}/app?view=${id}`, { waitUntil: "domcontentloaded", timeout: 180000 });
    await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", "the viewer again", 600);
    // A link left in the step player opens straight on its kept page.
    await page.waitForTimeout(3000);
    if (!(await page.evaluate(() => ((window.brickworksShare || {}).build || {}).open === true))) await tap(page, "view_build");
    await until(page, () => ((window.brickworksShare || {}).build || {}).open === true, "the step player again", 60);
    const at = (await page.evaluate(() => window.brickworksShare.build)).page;
    if (at === last) {
      await tap(page, "build_back");
      await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, "back after the reload", 60, last - 1);
    }
    for (let n = (at === last ? last - 1 : at) + 1; n <= last; n += 1) {
      await tap(page, "build_next");
      await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, `page ${n} after the reload`, 60, n);
    }
    await page.waitForTimeout(3000);
    again = await page.evaluate(() => window.brickworksShare.view.built);
    const still = await builds(id);
    check(`reloaded and finished again on the same phone: nothing sent (${again.sent}), counted kept (${again.counted}), still 1 built (${still})`,
      again.sent === 0 && again.counted === true && still === 1);
    await phone.close();
  } else {
    console.log("  --    no build/web here: the phone's finish is not driven (--no-app, or export the web build)");
    const device = randomBytes(16).toString("hex");
    const one = await api(null, `/api/share?op=built&id=${id}`, { device }, "POST", { "user-agent": PERSON, "sec-fetch-site": "same-origin" });
    check(`a person's finish counts (${JSON.stringify(one.body)})`, one.body.counted === true && one.body.builds === 1);
  }
  const robot = await api(null, `/api/share?op=built&id=${id}`, { device: randomBytes(16).toString("hex") }, "POST",
    { "user-agent": "curl/8.5.0" });
  check(`a robot's finish is not counted (${JSON.stringify(robot.body)})`, robot.status === 200 && robot.body.counted === false
    && robot.body.builds === 1);
  const bad = await api(null, `/api/share?op=built&id=${id}`, { device: "not a key" }, "POST",
    { "user-agent": PERSON, "sec-fetch-site": "same-origin" });
  check(`a key that is not one is refused (${bad.status})`, bad.status === 400);
  const rows = await held("model_builds", "model", id);
  check(`what is kept is a key per device, not the device's own (${rows.map((row) => row.device.slice(0, 8)).join(", ")})`,
    rows.length === 1 && /^[0-9a-f]{32}$/.test(rows[0].device));

  console.log("its page and its card say so");
  const visitorContext = await context();
  const visitor = await visitorContext.newPage();
  listen(visitor, "visitor");
  await visitor.goto(`${site}/m/${id}`, { waitUntil: "load" });
  const said = await visitor.evaluate(() => document.querySelector('[data-count="builds"]')?.textContent || "");
  check(`the model's page says "${said}"`, said === "1 built");
  // When each card was listed, from the list the page drew it from (a card
  // does not say): Most built ties by it, newest first.
  const answers = [];
  visitor.on("response", (reply) => {
    if (reply.url().includes("/api/share?op=list")) answers.push(reply.json().catch(() => ({})));
  });
  await visitor.goto(`${site}/gallery?tests=1&sort=builds`, { waitUntil: "load" });
  await until(visitor, () => document.documentElement.dataset.gallery === "ready", "the gallery", 60);
  const card = await visitor.evaluate((one) => {
    // The list's cards, not the front's shelves above it (the pick, small builds).
    const mine = document.querySelector(`#models a.model[data-id="${one}"]`);
    return { cards: [...document.querySelectorAll("#models a.model")].map((a) => ({ id: a.dataset.id, builds: a.dataset.builds })),
      said: mine?.querySelector("small")?.textContent || "",
      sorts: [...document.querySelectorAll("#sort option")].map((o) => o.textContent) };
  }, id);
  const listed = new Map((await Promise.all(answers)).flatMap((one) => one.models || [])
    .map((model) => [model.id, model.listed_at]));
  // Ahead of every card built less, and of as many built and listed before
  // it; another flow's test model built more, or as often and listed
  // later, while the release runs two at once (preview_checks.sh), may be
  // ahead of it.
  const stands = placed(card.cards.map((one) => ({ ...one, listed_at: listed.get(one.id) || null })), id, { by: "builds" });
  check(`its card says "${card.said}", and Most built puts it ${stands.said}`, /1 built/.test(card.said) && stands.ok
    && card.sorts.includes("Most built"));
  await shot(visitor, "2_gallery_most_built.png");
  const desk = await api(null, `/api/share?op=built&id=${id}`, { device: randomBytes(16).toString("hex") }, "POST",
    { "user-agent": "Brickworks/0.3.0 (desktop)" });
  check(`the desktop app's finish counts (${JSON.stringify(desk.body)})`, desk.body.counted === true && desk.body.builds === 2);

  // --- 2. a photo, made safe -----------------------------------------------------
  console.log("a photo of a real build, from the model's page");
  const builderSession = await mintSession(builder);
  const handle = `bw-builder-${rand}`;
  const profile = await api(builderSession.access_token, "/api/people?op=profile", { handle, name: "Flow Builder" });
  check(`the builder has a profile, @${handle}`, profile.status === 200);
  const builderContext = await context({ as: builder });
  const page = await builderContext.newPage();
  listen(page, "builder");
  await page.goto(`${site}/m/${id}#builds`, { waitUntil: "load" });
  await until(page, () => document.documentElement.dataset.buildPhotos, "the builds section ready", 60);
  const line = await page.evaluate(() => document.querySelector(".build-form .note")?.textContent || "");
  check(`the form says, in a line: "${line}"`, /Photos show the build, not people/.test(line));
  await page.click("[data-add-build]");
  await page.setInputFiles('.build-form input[type="file"]', photoFile);
  await page.fill('.build-form input[name="words"]', "Built it on the kitchen table, one swap in step 2");
  await page.click('.build-form button[type="submit"]');
  photo = await until(page, () => document.documentElement.dataset.buildPhoto, "the photo kept", 120).catch(() => "");
  const told = await page.evaluate(() => document.querySelector(".build-said")?.textContent || document.querySelector(".build-form .said")?.textContent);
  check(`kept as photo ${photo}: "${told}"`, /^[A-Za-z0-9]{10}$/.test(photo || ""));
  await shot(page, "3_photo_added.png");
  const back = Buffer.from(await (await fetch(`${site}/api/people?op=photo_file&id=${photo}`, { headers })).arrayBuffer());
  writeFileSync(path.join(out, "served.jpg"), back);
  const seen = decode(back, { useTArray: true });
  const corner = [...seen.data.subarray(((0) * seen.width + seen.width - 8) * 4, ((0) * seen.width + seen.width - 8) * 4 + 3)];
  check(`what the server gives back has no metadata, from its bytes: markers ${markers(back).join(",")}, `
    + `no Exif, no comment, no GPS, no make (${whereFrom(back) || "nowhere"})`,
    markers(back).join(",") === "e0,db,c0,c4,da" && !back.includes(Buffer.from("Exif")) && !back.includes(Buffer.from("GPS"))
    && !back.includes(Buffer.from("FlowPhone")) && !back.includes(Buffer.from("Flow Street")) && whereFrom(back) === "");
  check(`...turned upright as the phone was held: ${seen.width} x ${seen.height}, the mark now at the top right (${corner.join("/")})`,
    seen.height > seen.width && corner[0] > 200 && corner[1] > 180 && corner[2] < 80);
  const uploads = await stored("build-photo-uploads", `${builderSession.kept.user_id}/`);
  check(`the original is gone from storage (${uploads.length} of the builder's left in the uploads bucket)`, uploads.length === 0);
  const kept = await stored("build-photos", `${photo}.jpg`);
  check(`what is kept is build-photos/${photo}.jpg, ${kept[0]?.bytes} bytes`, kept.length === 1);
  const { value: strip, waited: stripWaited } = await fresh(async () => {
    await visitor.goto(`${site}/m/${id}`, { waitUntil: "load" });
    return visitor.evaluate((one) => {
      const figure = document.getElementById(`photo-${one}`);
      return figure ? { words: figure.querySelector("q")?.textContent, by: figure.querySelector(".by")?.textContent,
        loaded: figure.querySelector("img")?.complete && figure.querySelector("img")?.naturalWidth > 0 } : null;
    }, photo);
  });
  check(`the model's page shows it in the strip: "${strip?.words}", ${strip?.by} (after ${stripWaited} s)`, strip
    && /kitchen table/.test(strip.words) && /Flow Builder/.test(strip.by));
  await shot(visitor, "4_strip.png");
  await visitor.goto(`${site}/u/${handle}?tests=1`, { waitUntil: "load" });
  const onProfile = await visitor.evaluate((one) => Boolean(document.getElementById(`photo-${one}`)), photo);
  check("...and the builder's profile, under Built", onProfile);
  await shot(visitor, "5_profile_built.png");
  const more = [];
  for (let n = 0; n < 3; n += 1) {
    const start = await api(builderSession.access_token, "/api/people?op=photo_start", { model: id, type: "image/jpeg", size: plain.length });
    if (start.status !== 200) { more.push(start.status); break; }
    await fetch(start.body.upload, { method: "PUT", headers: { "content-type": "image/jpeg" }, body: plain });
    more.push((await api(builderSession.access_token, "/api/people?op=photo", { model: id, ticket: start.body.ticket })).status);
  }
  check(`three photos a model at most: a second and a third kept, a fourth refused (${more.join(", ")})`,
    more.join(",") === "201,201,409");
  const notPicture = await api(builderSession.access_token, "/api/people?op=photo_start", { model: id, type: "image/gif", size: 100 });
  check(`a GIF is refused before anything is sent (${notPicture.status})`, notPicture.status === 415);

  // --- 3. under 13 ----------------------------------------------------------------
  console.log("an account that said it is under 13");
  const youngSession = await mintSession(young, { age: false });
  await answerAge(youngSession.kept.user_id, young, false);
  const youngContext = await context({ as: young });
  const child = await youngContext.newPage();
  listen(child, "young");
  await child.goto(`${site}/m/${id}`, { waitUntil: "load" });
  await until(child, () => document.documentElement.dataset.buildPhotos, "the builds section", 60);
  await child.click("[data-add-build]");
  await child.setInputFiles('.build-form input[type="file"]', photoFile);
  await child.click('.build-form button[type="submit"]');
  const refused = await until(child, () => {
    const t = document.querySelector(".build-form .said")?.textContent || "";
    return /13/.test(t) ? t : null;
  }, "the refusal", 60).catch(() => "");
  check(`refused, in words: "${refused}"`, /Photos of builds are shown in public, so they are for people 13 and over/.test(refused));
  check("...and nothing was sent to storage", (await stored("build-photo-uploads", `${youngSession.kept.user_id}/`)).length === 0);
  await shot(child, "6_under_13_refused.png");
  await youngContext.close();

  // --- 4. the owner hides it --------------------------------------------------------
  console.log("the model's owner hides it");
  const ownerContext = await context({ as: owner });
  const desk2 = await ownerContext.newPage();
  listen(desk2, "owner");
  await fresh(async () => {
    await desk2.goto(`${site}/m/${id}`, { waitUntil: "load" });
    await until(desk2, () => document.documentElement.dataset.buildPhotos === "owner", "the owner's tools", 60);
    return desk2.evaluate((one) => Boolean(document.querySelector(`[data-hide="${one}"]`)), photo);
  });
  await desk2.click(`[data-hide="${photo}"]`);
  await until(desk2, (one) => document.documentElement.dataset.buildHidden === one, "hidden", 30, photo);
  const { value: gone, waited: goneWaited } = await fresh(async () => {
    const status = await photoStatus(photo);
    await visitor.goto(`${site}/m/${id}`, { waitUntil: "load" });
    const strip = await visitor.evaluate((one) => !document.getElementById(`photo-${one}`), photo);
    return status === 404 && strip ? { status, strip } : null;
  });
  check(`hidden: not in the strip for anybody else, not at its address (${gone ? "404" : "still shown"}, after ${goneWaited} s)`,
    Boolean(gone));
  await desk2.reload({ waitUntil: "load" });
  await until(desk2, () => document.documentElement.dataset.buildPhotos === "owner", "the owner's tools again", 60);
  const listedHidden = await desk2.evaluate((one) => Boolean(document.querySelector(`[data-show="${one}"]`)), photo);
  check("its owner sees it among the hidden, with Show it again", listedHidden);
  await shot(desk2, "7_owner_hidden.png");
  await desk2.click(`[data-show="${photo}"]`);
  await until(desk2, () => document.documentElement.dataset.buildHidden === "", "shown again", 30);
  const { value: shownAgain, waited: shownWaited } = await fresh(async () => (await photoStatus(photo)) === 200);
  check(`shown again (${shownAgain ? 200 : "not yet"}, after ${shownWaited} s)`, shownAgain);
  const stranger = await api(builderSession.access_token, "/api/people?op=photo_hide", { photo, on: true });
  check(`nobody but the model's owner may hide it (${stranger.status})`, stranger.status === 403);
  await ownerContext.close();

  // --- 5. reported, and taken out -----------------------------------------------------
  console.log("reported, and taken out by the site's owner");
  await fresh(async () => {
    await visitor.goto(`${site}/m/${id}`, { waitUntil: "load" });
    return visitor.evaluate((one) => Boolean(document.querySelector(`[data-report-photo="${one}"]`)), photo);
  });
  await visitor.click(`[data-report-photo="${photo}"]`);
  await visitor.check('dialog.report input[value="personal"]');
  await visitor.fill("dialog.report textarea", "Builds flow: a test report of a test photo");
  await visitor.click('dialog.report button[type="submit"]');
  await until(visitor, () => /Thank you/.test(document.querySelector("dialog.report")?.textContent || ""), "the report sent", 30);
  check("a visitor reports the photo from its Report it", true);
  const linked = await held("report_photos", "photo", photo);
  check(`...which is kept as a report about that photo (report ${linked[0]?.report})`, linked.length === 1);
  await visitorContext.close();
  const master = await mintSession(process.env.MASTER_EMAIL);
  const admin = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  await admin.addInitScript(([name, value]) => { try { localStorage.setItem(name, value); } catch {} },
    [STORAGE_KEY, JSON.stringify(master.kept)]);
  const desk3 = await admin.newPage();
  listen(desk3, "admin");
  desk3.on("dialog", (dialog) => dialog.accept());
  await desk3.goto(`${site}/admin`, { waitUntil: "load" });
  const row = await until(desk3, (one) => {
    const tr = document.querySelector(`#reports tr[data-photo="${one}"]`);
    const img = tr?.querySelector("img.reported-photo");
    return tr && img && img.complete && img.naturalWidth > 0 ? tr.innerText : null;
  }, "the report on the admin page", 60, photo).catch(() => "");
  check(`the admin page shows the report with the photo: "${row.replace(/\s+/g, " ").slice(0, 90)}"`, /A photo of a build/.test(row));
  await shot(desk3, "8_admin_photo_report.png");
  await desk3.click(`#reports tr[data-photo="${photo}"] button:has-text("Take the photo out")`);
  await until(desk3, (one) => !document.querySelector(`#reports tr[data-photo="${one}"]`), "taken out", 30, photo).catch(() => null);
  const afterFiles = [];
  for (const one of await held("build_photos", "model", id)) {
    afterFiles.push(...(await stored("build-photos", `${one.id}.jpg`)).map((file) => file.name));
  }
  const rowAfter = (await held("build_photos", "id", photo))[0];
  const servedAfter = { status: (await fresh(async () => (await photoStatus(photo)) === 404)).value ? 404 : 200 };
  check(`taken out: its file deleted from storage (${afterFiles.includes(`${photo}.jpg`) ? "still there" : "gone"}), `
    + `the others kept (${afterFiles.length}), marked removed, shown nowhere (${servedAfter.status})`,
    !afterFiles.includes(`${photo}.jpg`) && afterFiles.length === 2 && Boolean(rowAfter?.removed_at) && servedAfter.status === 404);
  await admin.close();
  await builderContext.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (id && ownerToken) await api(ownerToken, `/api/share?op=unpublish&id=${id}`, {}).catch(() => {});
  await browser.close();
  for (const one of [owner, builder, young]) await deleteAccount(one).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "a build finished counts once per device, and a photo of it is made safe, shown, hidden, reported and taken out");
process.exit(failed ? 1 : 0);
