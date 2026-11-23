// The studio's first screen for somebody signed in (studiostart, docs/PLAN.md
// row 1, src/ui/studio_start.gd), in a real browser against a deployment or a
// local relay: in place of the example car, it shows their models, the week's
// quick build, what came back on their models and the gallery; a pin pressed
// lights its part; a pin written while the studio is open shows within a
// minute.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 11750 --static=build/web --hold=pins &
//   node tools/web/studiostart_flow.mjs --url=http://127.0.0.1:11750 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/studiostart_flow.mjs --url=<preview> --out=DIR
//
// Two throwaway accounts at Resend test addresses, deleted at the end with
// their models: a builder, with three models kept with their account (one of
// them published), and a commenter, who pins a comment on a part of the
// published one and writes another. Never the site's owner; never
// brickworks.diy.
//
//   1. Before: /app as it opens for a check's browser (no ?start), as every
//      studio opened before this: the example car, then their model. Pictures.
//   2. /app?start at 1280 x 800 and 390 x 844, dark and light: never the
//      example car on the way (its title read every 250 ms from the load); the
//      first screen with three real things or more within the studio's open
//      time + 1 s (Main._first_open_ms to StudioStart.filled_ms). Pictures.
//   3. The pin pressed: their model opens and the pin's part is selected,
//      within 1 s of the press.
//   4. A pin written by the commenter while the studio is open: shown on its
//      part, and in the notice, within 60 s, unasked.
//   5. A gallery search pressed: a copy of their own on the baseplate.
//
// Pictures and summary.json in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { gzipSync } from "node:zlib";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { placesOf } from "../../api/_parts.js";
import { pinOf } from "../../web/card.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:11750").replace(/\/+$/, "").replace(/\/app$/, "");
if (/(^|\.)brickworks\.diy$/i.test(new URL(site).hostname)) throw new Error("studiostart_flow: never against brickworks.diy");
const out = path.resolve(String(args.out || "shots/studiostart"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const builderEmail = `delivered+bw-studiostart-builder-${rand}@resend.dev`;
const writerEmail = `delivered+bw-studiostart-writer-${rand}@resend.dev`;
const BUILDER = `bwss-builder-${rand}`;
const WRITER = `bwss-writer-${rand}`;
const OPEN_S = 300;
const SIZES = [{ name: "1280", width: 1280, height: 800, touch: false }, { name: "390", width: 390, height: 844, touch: true }];

let failed = 0;
const check = (what, ok, detail = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${detail ? ` (${detail})` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const summary = { site, opens: [], pin: {}, new_pin: {}, copy: {} };

const browser = await launch({ signedOut: true });

async function context(as, { width = 1280, height = 800, touch = false, scheme = "dark" } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, colorScheme: scheme,
    ...(touch ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await made.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(250);
  }
}

// The title and the pins are told in window.brickworksShare, the rest in
// window.brickworksState (Main._tell_page): read as one.
const state = (page) => page.evaluate(() => ({ ...(window.brickworksShare || {}), ...(window.brickworksState || {}) }))
  .catch(() => ({}));

/// Pressed where the app says the control is (window.brickworksControls).
async function press(page, name, touch) {
  const at = await until(page, (n) => (window.brickworksControls || {})[n], `the control ${name}`, 20, name);
  if (touch) await page.touchscreen.tap(at.x, at.y);
  else await page.mouse.click(at.x, at.y);
}

const text = (name, title) => `${readFileSync(path.join(root, "models", `${name}.ldr`), "utf8").replace(/^0 [^\r\n]*/, `0 ${title}`)
  .replace(/\s+$/, "")}\r\n0 // studiostart flow ${rand}\r\n`;

/// A model kept with [who]'s account, as the app's save sends one (CloudModels._send).
const keep = (who, name, model) => api("/api/models", { method: "POST", token: who.access_token,
  body: { name, base: 0, model: gzipSync(Buffer.from(model, "utf8")).toString("base64") } });

let builder = null;
let writer = null;
try {
  console.log("a builder with three models, one published, and a commenter");
  builder = await mintSession(builderEmail);
  writer = await mintSession(writerEmail);
  for (const [who, handle, name] of [[builder, BUILDER, "Start Builder"], [writer, WRITER, "Start Writer"]]) {
    const made = await api("/api/people?op=profile", { method: "POST", token: who.access_token, body: { handle, name } });
    check(`/u/${handle}`, made.status === 200, String(made.status));
  }
  const towerName = `Start Tower ${rand}`;
  const tower = text("tower", towerName);
  const published = await api("/api/share", { method: "POST", token: builder.access_token, body: { name: towerName, model: tower } });
  const id = published.body.id || "";
  check(`the tower published at /m/${id}`, published.status === 201 && /^[A-Za-z0-9]{10}$/.test(id), String(published.status));
  // Its copy in their models carries its link, as the app's publish writes it.
  const linked = tower.replace(/^(0 [^\r\n]*\r?\n)/, `$10 !BRICKWORKS SHARE ${id}\r\n`);
  for (const [name, model] of [["Start Racer", text("car", "Start Racer")], ["Start House", text("house", "Start House")],
    [towerName, linked]]) {
    const kept = await keep(builder, name, model);
    check(`“${name}” kept with their account`, kept.status === 200 || kept.status === 201, `${kept.status} ${kept.body.error || ""}`);
    await new Promise((done) => setTimeout(done, 1100));
  }
  const places = placesOf(tower);
  const pinAt = async (index, words) => api("/api/people?op=pin", { method: "POST", token: writer.access_token,
    body: { model: id, version: 1, step: null, body: words, part: pinOf(places, index) } });
  const first = await pinAt(Math.floor(places.length / 2), "This brick wants a slope on top of it.");
  check("the commenter pins a comment on a part of the tower", first.status === 201, `${first.status} ${first.body.error || ""}`);
  const plain = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 1, step: null, body: "Lovely tower: how tall is it in bricks?" } });
  check("and writes another, on no part", plain.status === 201, `${plain.status} ${plain.body.error || ""}`);
  const asked = await api("/api/people?op=studio_start", { token: builder.access_token });
  const came = asked.body.came || [];
  check(`?op=studio_start tells the builder what came back: ${came.map((one) => `${one.kind}${one.pinned ? " (on a part)" : ""}`).join(", ")}`,
    asked.status === 200 && came.some((one) => one.pinned && one.comment === first.body.comment?.id) && came.length >= 2,
    `${asked.status} ${asked.body.error || ""}; prompt ${asked.body.prompt ? asked.body.prompt.title : "none"}`);
  const count = await api("/api/people?op=feed_count", { token: builder.access_token });
  summary.count_before = count.body.count;

  console.log("1. before: the studio as it opens for a check's browser (no ?start)");
  for (const size of SIZES) {
    const made = await context(builder, size);
    const page = await made.newPage();
    listen(page, `before ${size.name}`);
    await page.goto(`${site}/app`, { waitUntil: "load" });
    await until(page, () => (window.brickworksState || {}).bricks > 0, "the studio up with a model", OPEN_S);
    await page.waitForTimeout(4000);
    const seen = await state(page);
    await shot(page, `before_${size.name}.png`);
    console.log(`  --    before at ${size.name}: “${seen.title}”, ${seen.bricks} parts, first screen ${seen.studio_start?.shown ? "shown" : "not shown"}`);
    await made.close();
  }

  console.log("2. /app?start: their own first screen, never the example car");
  // Each browser is first a device they have not used: their models come
  // from the account, Continue listing them as its list answers. Then the
  // same browser again, as a person comes back to it: the bar (three real
  // things within a second of the studio being up) is that visit's.
  let pinPage = null;
  let pinContext = null;
  const watch = async (page, label) => {
    const loaded = Date.now();
    let shownAt = 0;
    let car = false;
    const titles = new Set();
    const end = Date.now() + OPEN_S * 1000;
    for (;;) {
      const now = await state(page);
      if (now.title) titles.add(String(now.title));
      const start = now.studio_start || {};
      car = car || start.car === true;
      if (start.shown && start.real >= 3 && start.asked !== "asking" && start.found > 0) { shownAt = Date.now(); break; }
      if (Date.now() > end) break;
      await page.waitForTimeout(250);
    }
    const start = (await state(page)).studio_start || {};
    return { label, start, shownAt, car, titles: [...titles], wall_ms: shownAt ? shownAt - loaded : null };
  };
  for (const size of SIZES) {
    for (const scheme of ["dark", "light"]) {
      const made = await context(builder, { ...size, scheme });
      const page = await made.newPage();
      listen(page, `start ${size.name} ${scheme}`);
      await page.goto(`${site}/app?start`, { waitUntil: "load" });
      const first = await watch(page, "a new device");
      const fs = first.start;
      console.log(`  --    ${size.name} ${scheme}, a new device: ${fs.real} real things (${fs.continue} models listed), `
        + `${fs.after_open_ms} ms after the studio was up`);
      check(`${size.name} ${scheme}, a new device: never the example car`, !first.car, first.titles.join(" / "));
      // Their models brought here and kept, then the same browser again.
      await until(page, () => ((window.brickworksState || {}).studio_start || {}).here >= 3, "their models here", 120)
        .catch(() => null);
      await page.waitForTimeout(3000);
      await page.reload({ waitUntil: "load" });
      const again = await watch(page, "back again");
      const start = again.start;
      await page.waitForTimeout(1500);
      await shot(page, `after_${size.name}_${scheme}.png`);
      summary.opens.push({ size: size.name, scheme, new_device_ms: fs.after_open_ms, new_device_real: fs.real,
        after_open_ms: start.after_open_ms, real: start.real, continue: start.continue, came: start.came, pins: start.pins,
        prompt: start.prompt, found: start.found, titles: again.titles, wall_ms: again.wall_ms });
      check(`${size.name} ${scheme}, back again: the first screen, ${start.real} real things (${start.continue} models, `
        + `${start.came} came back, ${start.prompt ? "the week's build, " : ""}${start.found} from the gallery), `
        + `${start.after_open_ms} ms after the studio was up`,
        Boolean(again.shownAt) && start.real >= 3 && start.after_open_ms >= 0 && start.after_open_ms <= 1000);
      check(`${size.name} ${scheme}, back again: never the example car`, !again.car, again.titles.join(" / "));
      if (size.name === "1280" && scheme === "dark") {
        pinPage = page;
        pinContext = made;
      } else await made.close();
    }
  }

  console.log("3. the pin pressed lights its part");
  if (pinPage) {
    const start = (await state(pinPage)).studio_start || {};
    const row = (start.items || []).findIndex((one) => one.pinned);
    if (check("the pin is listed as one on a part", row >= 0, JSON.stringify(start.items))) {
      const comment = start.items[row].comment;
      const pressed = Date.now();
      await press(pinPage, `start_came_${row}`, false);
      const lit = await until(pinPage, (comment) => {
        const s = { ...(window.brickworksShare || {}), ...(window.brickworksState || {}) };
        const pins = s.pins || {};
        const one = (pins.pins || []).find((p) => p.id === comment);
        return one && one.brick && pins.lit === one.brick ? { brick: one.brick, title: s.title, at: Date.now() } : null;
      }, "the pin's part lit", 30, comment).catch(() => null);
      summary.pin = { ms: lit ? lit.at - pressed : null, title: lit?.title };
      check(`the pin pressed opens “${lit?.title}” with its part selected in ${lit ? lit.at - pressed : "-"} ms`,
        Boolean(lit) && lit.at - pressed <= 1000);
      await pinPage.waitForTimeout(800);
      await shot(pinPage, "pin_lit_1280.png");

      console.log("4. a pin written while the studio is open");
      const before = ((await state(pinPage)).pins || {}).pins?.length || 0;
      const second = await pinAt(0, "And this one could be a different colour.");
      check("the commenter pins another", second.status === 201, `${second.status} ${second.body.error || ""}`);
      const wrote = Date.now();
      const shown = await until(pinPage, (was) => {
        const pins = ({ ...(window.brickworksShare || {}), ...(window.brickworksState || {}) }).pins || {};
        return (pins.pins || []).length > was && pins.notice ? { notice: pins.notice, at: Date.now() } : null;
      }, "the new pin in the open studio", 75, before).catch(() => null);
      summary.new_pin = { ms: shown ? shown.at - wrote : null, notice: shown?.notice };
      check(`the new pin shows in the open studio, unasked, in ${shown ? Math.round((shown.at - wrote) / 1000) : "-"} s: “${shown?.notice}”`,
        Boolean(shown) && shown.at - wrote <= 60000);
      await shot(pinPage, "new_pin_1280.png");
    }
    await pinContext.close();
  }

  console.log("5. a gallery model opened as a copy of their own");
  {
    const made = await context(builder, SIZES[0]);
    const page = await made.newPage();
    listen(page, "copy");
    await page.goto(`${site}/app?start`, { waitUntil: "load" });
    await until(page, () => ((window.brickworksState || {}).studio_start || {}).found > 0, "the gallery's first page", OPEN_S);
    const was = (await state(page)).title;
    await press(page, "start_found_0", false);
    const copied = await until(page, (was) => {
      const s = { ...(window.brickworksShare || {}), ...(window.brickworksState || {}) };
      return s.title && s.title !== was && !(s.studio_start || {}).shown && s.bricks > 0 ? { title: s.title, bricks: s.bricks } : null;
    }, "the copy on the baseplate", 120, was).catch(() => null);
    summary.copy = copied || {};
    check(`a gallery model pressed: “${copied?.title}” on the baseplate, ${copied?.bricks} parts`, Boolean(copied));
    await shot(page, "copy_1280.png");
    await made.close();
  }
  const after = await api("/api/people?op=feed_count", { token: builder.access_token });
  check(`the avatar's count is left as it was by the first screen (${summary.count_before} then ${after.body.count})`,
    Number(after.body.count) >= Number(summary.count_before));
} catch (trouble) {
  check(`the flow ran to its end: ${String(trouble?.message || trouble).split("\n")[0]}`, false);
} finally {
  for (const email of [builderEmail, writerEmail]) await deleteAccount(email).catch(() => {});
  await browser.close().catch(() => {});
}
for (const line of errors.slice(0, 12)) console.log(`  --    ${line}`);
summary.errors = errors;
summary.failed = failed;
writeFileSync(path.join(out, "summary.json"), JSON.stringify(summary, null, 2));
console.log(failed ? `\n${failed} FAILED` : "\nthe studio's first screen: every check passed");
process.exit(failed ? 1 : 0);
