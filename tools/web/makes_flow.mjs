// Show your build (makes), in real browsers: a photo of a real build posted
// from the last step of Build it, the step player's own end card, at 390 x 844
// on a touch screen and at 1280 x 800 with a mouse; signed out, the sign-in
// asked in place and the photo kept through it.
//
//   tools/export.sh web
//   node --env-file=.env tools/web/relay_server.mjs 11350 --static=build/web \
//     --hold=model_builds,build_photos,report_photos --trust-stand-in &
//   node --env-file=.env tools/web/makes_flow.mjs --url=http://127.0.0.1:11350 --out=shots/makes_web
//
// The relay holds builds.sql's tables and buckets as builds_flow.mjs has it;
// the accounts, the model and its notifications are the real project's.
//
//   1. A throwaway designer lists a model of three steps; a throwaway
//      builder, signed in, opens its viewer at each size, Build it and Next
//      to the last step: the end card says how many have built it and offers
//      Show your build. Show your build brings up the page's file chooser;
//      a JPEG with Exif in it (GPS, a phone's make, turned a quarter) chosen,
//      a line typed, and Post: three taps from the last step. The card says
//      "Posted: on the model's page" with its link; what the server gives
//      back has no Exif and stands upright, its card copy at most 480 px
//      wide; the model's page shows it first in its Builds strip and the
//      designer's notifications have it as a photo, each within 60 s of
//      Post. Ten more Back and Next onto the last step at each size: still
//      one finish counted for the device (twenty in all).
//   2. At 1280, a file that is not a picture is refused in words, nothing
//      sent.
//   3. At 390, signed out: Post asks for the sign-in over the step player,
//      still on the last step. The page reloaded while it is up, as
//      orangecheck's sign-in comes back to it: the last step again, the photo
//      and the words still on the card. Signed in by an emailed code typed
//      in the app's own form: back on the card as it was, and Post posts it.
//
// Pictures in --out. Every account is deleted at the end, the model taken
// down first.
import { clickStill, launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:11350").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/makes_web"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const local = (await fetch(`${site}/__held/model_builds`, { headers }).catch(() => null))?.ok === true;
if (local) process.env.BW_STAND_IN = process.env.BW_STAND_IN || site;
const { decode, encode } = await import(path.join(root, "api/_jpeg.js"));
const rand = randomBytes(4).toString("hex");
const designer = `delivered+bw-makes-designer-${rand}@resend.dev`;
const builder = `delivered+bw-makes-builder-${rand}@resend.dev`;
const outsider = `delivered+bw-makes-outsider-${rand}@resend.dev`;
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${rand}`;
const NOT_A_PHOTO = "That is not a JPEG, a PNG or a WebP photo.";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const timings = {};

// --- a model and a photo, made here --------------------------------------------

function stack(name) {
  const lines = [`0 ${name}`, `0 Name: ${name.toLowerCase().replace(/\s+/g, "_")}.ldr`, "0 Author: Makes Flow", ""];
  [0, -24, -48].forEach((y, n) => {
    lines.push(`1 ${[4, 1, 14][n]} 0 ${y} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  });
  return `${lines.join("\r\n")}\r\n`;
}

/// 960 x 640: a red brick on blue, a yellow mark at the top left.
function drawn() {
  const width = 960;
  const height = 640;
  const data = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const at = (y * width + x) * 4;
      const brick = x > 200 && x < 760 && y > 260 && y < 520;
      const mark = x < 140 && y < 140;
      const [r, g, b] = mark ? [250, 220, 0] : brick ? [200, 24, 32] : [40, 90, 160];
      data[at] = r; data[at + 1] = g; data[at + 2] = b; data[at + 3] = 255;
    }
  }
  return { width, height, data };
}

/// Exif as a phone writes it: its make, turned a quarter (6), and a GPS place.
function exif() {
  const u16 = (n) => [n & 255, n >> 8];
  const u32 = (n) => [n & 255, (n >> 8) & 255, (n >> 16) & 255, (n >>> 24) & 255];
  const make = Buffer.from("FlowPhone Maker\0", "latin1");
  const ifd0 = 8;
  const gps = ifd0 + 2 + 3 * 12 + 4;
  let dataAt = gps + 2 + 4 * 12 + 4;
  const data = [];
  const place = (bytes) => { const at = dataAt; data.push(...bytes); dataAt += bytes.length; return at; };
  const makeAt = place([...make]);
  const rational = (parts) => parts.flatMap(([n, d]) => [...u32(n), ...u32(d)]);
  const latAt = place(rational([[61, 1], [13, 1], [45, 10]]));
  const lonAt = place(rational([[149, 1], [54, 1], [225, 100]]));
  const tiff = [...Buffer.from("II", "latin1"), ...u16(42), ...u32(ifd0)];
  const entries0 = [[0x010f, 2, make.length, makeAt], [0x0112, 3, 1, 6], [0x8825, 4, 1, gps]];
  tiff.push(...u16(entries0.length));
  for (const [tag, type, n, value] of entries0) tiff.push(...u16(tag), ...u16(type), ...u32(n), ...(type === 3 ? [...u16(value), 0, 0] : u32(value)));
  tiff.push(...u32(0));
  const gpsEntries = [[1, 2, 2, [78, 0, 0, 0]], [2, 5, 3, u32(latAt)], [3, 2, 2, [87, 0, 0, 0]], [4, 5, 3, u32(lonAt)]];
  tiff.push(...u16(gpsEntries.length));
  for (const [tag, type, n, value] of gpsEntries) tiff.push(...u16(tag), ...u16(type), ...u32(n), ...value);
  tiff.push(...u32(0), ...data);
  return Buffer.concat([Buffer.from("Exif\0\0", "latin1"), Buffer.from(tiff)]);
}

const segment = (marker, body) => Buffer.concat([Buffer.from([0xff, marker, (body.length + 2) >> 8, (body.length + 2) & 255]), body]);

/// A JPEG's markers up to its picture: "e0", "e1", "fe"...
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

const picture = drawn();
const plain = encode(picture, 90).data;
const original = Buffer.concat([plain.subarray(0, 2), segment(0xe1, exif()), plain.subarray(2)]);
const photoFile = path.join(out, "build_with_gps.jpg");
writeFileSync(photoFile, original);
const notesFile = path.join(out, "notes.jpg");
writeFileSync(notesFile, "these are words, not a photo\n");
check(`the photo to send has Exif in it, GPS and a phone's make (${markers(original).join(",")})`,
  markers(original).includes("e1") && original.includes(Buffer.from("FlowPhone")));

// --- helpers -------------------------------------------------------------------

const browser = await launch({ signedOut: true });

async function context({ as = null, phone = false } = {}) {
  const made = await browser.newContext({ userAgent: PERSON, extraHTTPHeaders: headers,
    ...(phone ? { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true }
      : { viewport: { width: 1280, height: 800 } }) });
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
  page.choosers = [];
  page.on("filechooser", (chooser) => page.choosers.push(chooser));
}

async function until(page, test, what, seconds = 240, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(250);
  }
}

const build = (page) => page.evaluate(() => (window.brickworksShare || {}).build || {});
const controls = (page) => page.evaluate(() => window.brickworksControls || {});
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

/// A finger's tap on a phone, a click elsewhere, where the app says the
/// control is once it rests (clickStill).
function press(page, name, seconds = 60) {
  return clickStill(page, name, { seconds, shots: out,
    act: page.touch ? (at) => page.touchscreen.tap(at.x, at.y) : (at) => page.mouse.click(at.x, at.y) });
}

async function api(token, pathname, body, method = "POST") {
  const reply = await fetch(`${site}${pathname}`, { method,
    headers: { ...headers, "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: method === "GET" ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

const builds = async (id) => (await api(null, `/api/share?id=${id}`, null, "GET")).body.builds;

/// The viewer of [id] opened, Build it pressed and Next to its last step.
async function toLastStep(page, id) {
  await page.goto(`${site}/app?view=${id}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", "the viewer", 600);
  await until(page, () => Boolean((window.brickworksControls || {}).steps_slider), "the timeline", 180);
  if (!(await build(page)).open) await press(page, "view_build");
  await until(page, () => ((window.brickworksShare || {}).build || {}).open === true, "the step player", 60);
  const { last } = await build(page);
  for (let n = (await build(page)).page; n < last; n += 1) {
    await press(page, "build_next");
    await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, `page ${n + 1}`, 60, n + 1);
  }
  return until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.make && b.make.shown && b.make.offer && b.make.builds >= 0 ? b : null;
  }, "the end card", 60);
}

/// [file] chosen in the chooser Show your build brought up; the card's state after.
async function choose(page, file, name = "make_show") {
  const before = page.choosers.length;
  await press(page, name);
  const end = Date.now() + 20000;
  while (page.choosers.length <= before && Date.now() < end) await page.waitForTimeout(200);
  const chooser = page.choosers[page.choosers.length - 1] || null;
  if (!check(`${name === "make_show" ? "Show your build" : "Another photo"} brings up the page's file chooser`,
    page.choosers.length > before && chooser !== null)) return {};
  const began = Date.now();
  await chooser.setFiles(file);
  const card = await until(page, () => {
    const m = ((window.brickworksShare || {}).build || {}).make || {};
    return m.state && m.state !== "reading" && (m.state === "chosen" || m.said) ? m : null;
  }, "the photo read", 60);
  timings.read_ms = Math.max(timings.read_ms || 0, Date.now() - began);
  return card;
}

/// The photo [one] as the server gives it back, and its card copy.
async function servedBack(one) {
  const big = Buffer.from(await (await fetch(`${site}/api/people?op=photo_file&id=${one}`, { headers })).arrayBuffer());
  const small = Buffer.from(await (await fetch(`${site}/api/people?op=photo_file&id=${one}&size=card`, { headers })).arrayBuffer());
  return { big, small };
}

/// Asked every 2 s until it answers or 60 s pass after [since]: {value, s}.
async function within60(since, test) {
  for (;;) {
    const value = await test().catch(() => null);
    const s = Math.round((Date.now() - since) / 100) / 10;
    if (value || s >= 60) return { value, s };
    await new Promise((done) => setTimeout(done, 2000));
  }
}

let designerToken = "";
let id = "";
const photos = [];
try {
  console.log("a model of three steps, listed by a throwaway designer");
  designerToken = (await mintSession(designer)).access_token;
  await api(designerToken, "/api/people?op=profile", { handle: `bw-makes-d-${rand}`, name: "Makes Designer" });
  const made = await api(designerToken, "/api/share", { name: `Makes Flow Tower ${rand}`, model: stack("Makes Flow Tower"), listed: true });
  id = made.body.id || "";
  check(`listed at /m/${id}`, made.status === 201 && Boolean(id));
  await api(designerToken, "/api/people?op=notifications", null, "GET");
  const builderSession = await mintSession(builder);
  await api(builderSession.access_token, "/api/people?op=profile", { handle: `bw-makes-b-${rand}`, name: "Makes Builder" });
  const viewerContext = await context();
  const visitor = await viewerContext.newPage();
  listen(visitor, "visitor");

  for (const size of [{ name: "390", phone: true }, { name: "1280", phone: false }]) {
    console.log(`\nat ${size.name}, signed in: the last step, Show your build, Post`);
    const ctx = await context({ as: builder, phone: size.phone });
    const page = await ctx.newPage();
    page.touch = size.phone;
    listen(page, size.name);
    const last = await toLastStep(page, id);
    check(`the last step (${last.page} of ${last.last}) says "${last.make.count}" and offers "${last.make.offer}", `
      + `${JSON.stringify(last.targets?.make_show)} points`,
    last.make.offer === "Show your build" && /people have built it|person has built it/.test(last.make.count)
      && last.targets?.make_show?.[0] >= 44 && last.targets?.make_show?.[1] >= 44);
    await page.waitForTimeout(1500);
    await shot(page, `${size.name}_1_last_step.png`);
    if (!size.phone) {
      const refused = await choose(page, notesFile);
      check(`a file that is not a picture: "${refused.said}", nothing chosen`, refused.said === NOT_A_PHOTO && refused.photo === 0);
    }
    let taps = 0;
    const card = await choose(page, photoFile);
    taps += 1;
    check(`the photo is on the card (${card.photo} bytes, ${card.type}, ${card.size?.join(" x ")} upright)`,
      card.state === "chosen" && card.photo === original.length && card.size?.[0] === 640 && card.size?.[1] === 960);
    await press(page, "make_words");
    taps += 1;
    await page.keyboard.type(`Built it at ${size.name}, one swap in step 2`, { delay: 20 });
    await page.waitForTimeout(800);
    await shot(page, `${size.name}_2_photo_chosen.png`);
    await press(page, "make_post");
    taps += 1;
    const posting = Date.now();
    const done = await until(page, () => {
      const m = ((window.brickworksShare || {}).build || {}).make || {};
      return m.state === "posted" || (m.state === "chosen" && m.said) ? m : null;
    }, "the photo posted", 120);
    timings[`post_${size.name}_ms`] = Date.now() - posting;
    const one = (String(done.url).match(/#photo-([A-Za-z0-9]+)/) || [])[1] || "";
    photos.push(one);
    check(`the card says "${done.posted}", a link to ${done.url}`, done.posted === "Posted: on the model's page" && Boolean(one));
    check(`from the last step to the photo posted: ${taps} taps (at most 3)`, taps <= 3);
    await page.waitForTimeout(1000);
    await shot(page, `${size.name}_3_posted.png`);
    if (one) {
      const { big, small } = await servedBack(one);
      writeFileSync(path.join(out, `${size.name}_served.jpg`), big);
      const seen = decode(big, { useTArray: true });
      const card480 = decode(small, { useTArray: true });
      check(`what the server gives back has no Exif (markers ${markers(big).join(",")}), no make, upright ${seen.width} x ${seen.height}`,
        !big.includes(Buffer.from("Exif")) && !big.includes(Buffer.from("FlowPhone")) && seen.height > seen.width);
      check(`its card copy is ${card480.width} x ${card480.height} (at most 480 wide), no Exif`,
        card480.width <= 480 && !small.includes(Buffer.from("Exif")));
      const strip = await within60(posting, async () => {
        await visitor.goto(`${site}/m/${id}`, { waitUntil: "load" });
        return visitor.evaluate((photo) => {
          const first = document.querySelector("#builds figure.build");
          return first?.id === `photo-${photo}` ? first.querySelector("q")?.textContent || "(no words)" : null;
        }, one);
      });
      timings[`page_${size.name}_s`] = strip.s;
      check(`the model's page shows it first in its Builds strip: "${strip.value}", ${strip.s} s after Post`, Boolean(strip.value) && strip.s <= 60);
      const bell = await within60(posting, async () => {
        const said = await api(designerToken, "/api/people?op=notifications", null, "GET");
        const group = (said.body.groups || []).find((g) => g.model === id);
        return group?.rows?.find((row) => row.kind === "photo") || null;
      });
      timings[`bell_${size.name}_s`] = bell.s;
      check(`the designer's notifications have it, a photo (${bell.value ? bell.value.line : "none"}), ${bell.s} s after Post`,
        Boolean(bell.value) && bell.s <= 60);
    }
    const counted = await builds(id);
    for (let n = 0; n < 10; n += 1) {
      await press(page, "build_back");
      await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, "back a page", 60, last.last - 1);
      await press(page, "build_next");
      await until(page, (k) => ((window.brickworksShare || {}).build || {}).page === k, "the last page", 60, last.last);
    }
    await page.waitForTimeout(2000);
    const sent = await page.evaluate(() => ((window.brickworksShare || {}).view || {}).built || {});
    const after = await builds(id);
    check(`ten more finishes on this device: ${sent.sent} sent in all, built ${counted} then ${after}`,
      sent.sent <= 1 && after === counted);
    const most = await build(page);
    timings[`turn_most_${size.name}_ms`] = most.turn_most_ms;
    await ctx.close();
  }

  console.log("\nat 390, signed out: the sign-in in place, the photo kept");
  const outsiderSession = await mintSession(outsider);
  await api(outsiderSession.access_token, "/api/people?op=profile", { handle: `bw-makes-o-${rand}`, name: "Makes Outsider" });
  const ctx = await context({ phone: true });
  const page = await ctx.newPage();
  page.touch = true;
  listen(page, "signed out");
  const last = await toLastStep(page, id);
  await choose(page, photoFile);
  await press(page, "make_words");
  await page.keyboard.type("Our first one", { delay: 20 });
  await press(page, "make_post");
  const asked = await until(page, () => ((window.brickworksShare || {}).build || {}).make_gate === true
    && Boolean((window.brickworksControls || {}).signin_email) && Boolean((window.brickworksControls || {}).signin_not_now),
  "the sign-in in place", 30).catch(() => false);
  const under = await build(page);
  check(`Post signed out asks for the sign-in in place, over the step player on its last step (${under.page} of ${under.last})`,
    asked && under.open && under.page === last.last);
  await page.waitForTimeout(800);
  await shot(page, "390_4_sign_in.png");
  await page.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", "the viewer again", 600);
  await until(page, () => Boolean(window.brickworksStepsReady), "the steps again", 180);
  await page.waitForTimeout(3000);
  if (!(await build(page)).open) await press(page, "view_build");
  const back = await until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.open && b.make && b.make.state === "chosen" ? b : null;
  }, "the photo back on the card", 120).catch(async () => build(page));
  check(`the page reloaded as a sign-in elsewhere brings it back: step ${back.page} of ${back.last}, the photo `
    + `(${back.make?.photo} bytes) and "${back.make?.words}" on the card`,
  back.page === back.last && back.make?.state === "chosen" && back.make?.photo > 0 && back.make?.words === "Our first one");
  await press(page, "make_post");
  await until(page, () => Boolean((window.brickworksControls || {}).signin_email), "the form", 30);
  await press(page, "signin_email");
  await page.keyboard.type(outsider, { delay: 10 });
  await press(page, "signin_send");
  await until(page, () => Boolean((window.brickworksControls || {}).signin_code), "the code boxes", 120);
  const code = await mintCode(outsider);
  await press(page, "signin_code");
  await page.keyboard.type(code, { delay: 30 });
  const signed = await until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.make_gate === false && b.make && /Signed in/.test(b.make.said || "") ? b : null;
  }, "signed in and back on the card", 120).catch(async () => build(page));
  check(`signed in: back on step ${signed.page} of ${signed.last}, "${signed.make?.said}", the photo still chosen`,
    signed.page === signed.last && signed.make?.state === "chosen" && signed.make?.photo > 0 && /Signed in/.test(signed.make?.said || ""));
  await shot(page, "390_5_signed_in.png");
  const posting = Date.now();
  await press(page, "make_post");
  const done = await until(page, () => {
    const m = ((window.brickworksShare || {}).build || {}).make || {};
    return m.state === "posted" || (m.state === "chosen" && m.said && !/Signed in|Sending|Making/.test(m.said)) ? m : null;
  }, "the photo posted", 120).catch(() => ({}));
  timings.post_signed_out_ms = Date.now() - posting;
  const one = (String(done.url || "").match(/#photo-([A-Za-z0-9]+)/) || [])[1] || "";
  photos.push(one);
  check(`one tap more and it is posted: "${done.posted || done.said}"`, done.state === "posted" && Boolean(one));
  await ctx.close();
  await viewerContext.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (id && designerToken) await api(designerToken, `/api/share?op=unpublish&id=${id}`, {}).catch(() => {});
  await browser.close();
  for (const one of [designer, builder, outsider]) await deleteAccount(one).catch(() => {});
}
console.log(`  --    timings ${JSON.stringify(timings)}`);
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "a build's photo is posted from its last step at 390 and 1280, signed in or not");
process.exit(failed ? 1 : 0);
