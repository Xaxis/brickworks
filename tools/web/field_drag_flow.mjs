// A finger's drag begun on a text field scrolls the list round it, in the
// web build on a phone, as a drag begun beside the fields does.
//
//   node tools/web/field_drag_flow.mjs --url=<preview>/app --bypass=… --out=DIR
//   node tools/web/field_drag_flow.mjs --url=http://127.0.0.1:9063/ --out=shots/field_drag
//
// uifix (2026-10-31): a field took a finger's press for itself, so its list
// never heard a drag begin: the assistant's drawer at 844 x 390 could not
// be scrolled from its key field, and a panel full of fields only from the
// gaps between them (field_drag_probe has the app's every container).
//
// At 844 x 390, and at 390 x 844 at Interface size 150%, three device
// pixels to the point, by touch (CDP touch events, as a phone's): the
// assistant's drawer, then Settings, AI, "another AI on your own key" (which
// takes the drawer's key field away). In each list that scrolls there:
//   a drag begun beside the fields moves the list (the measure's own
//   check), and a drag begun on a field moves it as far back, the field
//   with it; no field is being typed in after it (the app's own audit,
//   window.brickworksPhone.typing);
//   a tap on the field has it typed in;
//   a hold before a drag along it leaves the list where it was.
// A list with nothing to scroll at a size is said, and passes; at least
// one must scroll. Then the parts: a drag begun on a tile's "+N" (what is
// folded under it) moves the bin with the finger, as one begun on the tile
// does (uifix: it moved nothing, the "+N" took the finger's press for
// itself). Pictures in --out.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:9063/");
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(String(args.out || "shots/field_drag"));
mkdirSync(out, { recursive: true });

let failures = 0;
let scrolled = 0;
const t0 = Date.now();
const check = (line, passed) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failures += 1;
  return passed;
};

const browser = await launch();

for (const [width, height, size] of [[844, 390, "100%"], [390, 844, "150%"]]) {
  console.log(`\n${width} x ${height} at 3x, by a finger, at ${size}`);
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 3,
    isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
  });
  const cdp = await context.newCDPSession(page);
  const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
  const where = async (name, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const at = (await controls())[name];
      if (at) return at;
      await page.waitForTimeout(250);
    }
    return null;
  };
  // Where [name] stands once it has stood still: the page is told a
  // control only where it stood at the telling before.
  const still = async (name, seconds = 15) => {
    let at = await where(name, seconds);
    for (let n = 0; at && n < seconds * 2; n++) {
      await page.waitForTimeout(500);
      const again = (await controls())[name];
      if (again && again.x === at.x && again.y === at.y) return again;
      at = again || at;
    }
    return at;
  };
  const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
    touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
  const tap = async (at) => {
    await page.touchscreen.tap(at.x, at.y);
    await page.waitForTimeout(800);
  };
  // A finger down at [a], [hold] ms still, drawn to [b], held still 400 ms
  // so the list does not glide on, and lifted.
  const drag = async (a, b, hold = 0) => {
    await touch("touchStart", [a]);
    if (hold) await page.waitForTimeout(hold);
    for (let n = 1; n <= 16; n++) {
      await touch("touchMove", [{ x: a.x + (b.x - a.x) * n / 16, y: a.y + (b.y - a.y) * n / 16 }]);
      await page.waitForTimeout(30);
    }
    await page.waitForTimeout(400);
    await touch("touchEnd", []);
    await page.waitForTimeout(1200);
  };
  const ask = async () => {
    await page.evaluate(() => { window.brickworksPhone = null; window.brickworksAskPhone = true; });
    for (let n = 0; n < 40; n++) {
      await page.waitForTimeout(250);
      const told = await page.evaluate(() => window.brickworksPhone);
      if (told) return told;
    }
    return null;
  };
  const picture = (what) => page.screenshot({ path: `${out}/${width}_${height}_${what}.png`, timeout: 120000 })
    .catch((e) => console.log(`  --    no picture ${what}: ${String(e).split("\n")[0]}`));
  const inside = (box, p) => p.x >= box[0] && p.x <= box[0] + box[2] && p.y >= box[1] && p.y <= box[1] + box[3];

  // A place in [holder] under none of the app's targets, near [x] first.
  const gapIn = async (holder, x) => {
    const told = await ask();
    const targets = told ? told.targets : [];
    const xs = [x, holder[0] + holder[2] * 0.5, holder[0] + 24].filter((v) => v !== undefined);
    const ys = [0.5, 0.35, 0.65, 0.25, 0.75].map((k) => holder[1] + holder[3] * k);
    for (const gx of xs) {
      for (const y of ys) {
        const p = { x: gx, y };
        if (inside(holder, p) && !targets.some((t) => inside(t.box, p))) return p;
      }
    }
    return null;
  };
  // The box [at]'s holder is in: as wide as it, as tall as the drawer or
  // sheet whose targets it is among, as the audit tells them; else the
  // screen's height.
  const holderOf = async (at) => {
    const told = await ask();
    const targets = told ? told.targets : [];
    const mine = targets.find((t) => inside(t.box, at));
    const kin = mine && mine.in ? targets.filter((t) => t.in === mine.in && !t.off) : [];
    if (kin.length < 2) return [at.x - at.w / 2, 0, at.w, height];
    const top = Math.max(0, Math.min(...kin.map((t) => t.box[1])));
    const foot = Math.min(height, Math.max(...kin.map((t) => t.box[1] + t.box[3])));
    return [at.x - at.w / 2, top, at.w, foot - top];
  };
  // [name] brought onto the screen as a finger brings it: the list in
  // [holder] dragged up by a gap until the page is told it.
  const bring = async (name, holder) => {
    for (let n = 0; n < 6; n++) {
      const at = (await controls())[name];
      if (at && !at.clipped && at.y + (at.h || 0) / 2 <= height) return still(name);
      const gap = await gapIn(holder);
      if (!gap) return null;
      await drag(gap, { x: gap.x, y: gap.y - height * 0.25 });
    }
    return still(name, 5);
  };
  // A list round [field] (named to the page), dragged beside its fields and
  // then by the field: [holder] is the box the list is in, as the audit's
  // frames or the field's own column say.
  const list = async (what, field, holder) => {
    const at = await still(field);
    if (!check(`${what}: the field "${field}" is on the screen`, Boolean(at))) return;
    // Beside the fields: in the field's column, under no target.
    const gap = await gapIn(holder, at.x);
    if (!check(`${what}: a place beside the fields to drag by`, Boolean(gap))) return;
    // Up by a third of the screen, where the list goes on down; down, where
    // it stands at its foot already.
    let by = 0;
    let moved = null;
    let beside = 0;
    for (const way of [-1, 1]) {
      by = way * Math.round(height * 0.3);
      const from = await still(field);
      await drag(gap, { x: gap.x, y: gap.y + by });
      moved = await still(field);
      beside = moved && from ? moved.y - from.y : 0;
      if (Math.abs(beside) >= 8) break;
    }
    if (Math.abs(beside) < 8) {
      console.log(`  --    ${what}: nothing to scroll at this size (a drag beside the fields moved "${field}" ${beside})`);
      return;
    }
    scrolled += 1;
    check(`${what}: a drag beside the fields moves the list (${beside} points; the finger went ${by})`,
      Math.sign(beside) === Math.sign(by));
    await picture(`${what.replace(/\W+/g, "_")}_beside`);
    // Back down, by the field this time: as far as it went up.
    const from = moved;
    await drag({ x: from.x, y: from.y }, { x: from.x, y: from.y - by });
    const back = await still(field);
    const went = back ? back.y - from.y : 0;
    await picture(`${what.replace(/\W+/g, "_")}_by_the_field`);
    const after = await ask();
    const typing = after && after.typing && after.typing.length ? after.typing : null;
    check(`${what}: a drag begun on "${field}" moves the list back with the finger (${went} points of ${-beside}),`
      + ` nothing typed in (${typing ? `typing in ${JSON.stringify(typing)}` : "none"})`,
      Math.abs(went + beside) <= Math.max(12, Math.abs(beside) * 0.2) && !typing);
    // A tap on it: it is typed in.
    const now = await still(field);
    await tap(now);
    const tapped = await ask();
    const into = tapped && tapped.typing && tapped.typing.length ? tapped.typing : null;
    const into_it = into && inside([into[0] - 2, into[1] - 2, into[2] + 4, into[3] + 4], now);
    if (holder.dialog) {
      check(`${what}: a tap on "${field}" has it typed in (${into ? JSON.stringify(into) : "nothing typed in"})`,
        Boolean(into_it));
    }
    // Held, then drawn along: the list stays where it was.
    const held = await still(field);
    await drag({ x: held.x - held.w / 3, y: held.y }, { x: held.x + held.w / 3, y: held.y }, 700);
    const stayed = await still(field);
    check(`${what}: held, then drawn along "${field}": the list stays (${stayed ? stayed.y - held.y : "?"} points)`,
      Boolean(stayed) && Math.abs(stayed.y - held.y) <= 4);
    await picture(`${what.replace(/\W+/g, "_")}_held`);
  };

  // Settings open, as the comma key opens it.
  const settings = async () => {
    let opened = null;
    for (let tries = 0; tries < 24 && !opened; tries++) {
      if (tries % 8 === 0) await page.keyboard.press("Comma");
      await page.waitForTimeout(500);
      opened = (await controls()).ai_settings;
    }
    return opened;
  };
  const frameOf = async (pattern) => {
    const told = await ask();
    const frame = told && (told.frames || []).find((f) => pattern.test(f.name));
    return frame ? frame.box : [0, 0, width, height];
  };

  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  check("the app came up", Boolean(await where("phone_parts", 400)));
  await page.waitForTimeout(Number(args.load || 8000));

  // Interface size, chosen from its list as a person chooses it.
  if (size !== "100%") {
    if (check("Settings open", Boolean(await settings()))) {
      const choice = await bring("interface_size", await frameOf(/settings/i));
      if (check(`Settings: Interface size on the screen`, Boolean(choice))) {
        await tap(choice);
        for (let n = 0; n <= ["85%", "100%", "115%", "130%", "150%"].indexOf(size); n++) {
          await page.keyboard.press("ArrowDown");
          await page.waitForTimeout(150);
        }
        await page.keyboard.press("Enter");
        await page.waitForTimeout(3000);
      }
      const done = await where("settings_done", 5);
      if (done) await tap(await still("settings_done"));
      await page.waitForTimeout(2500);
    }
  }

  // The assistant, shown; open as its drawer, or by its button in the top
  // bar where the screen has no room for a drawer beside the model.
  const offer = await where("offer_show", 5);
  if (offer) {
    await tap(offer);
    await page.waitForTimeout(1500);
    await page.keyboard.press("Escape");
  }
  let key = await still("key_field", 8);
  if (!key) {
    const button = await where("phone_assistant", 5);
    if (button) await tap(button);
    key = await still("key_field", 15);
  }
  if (key) key = await bring("key_field", await holderOf(key));
  await picture("assistant");
  if (check("the assistant is open, its key field on the screen", Boolean(key))) {
    await list("the assistant", "key_field", await holderOf(key));
  }

  // Settings, AI, on your own key; in the app afresh, for the key field
  // held has the keys, and a comma typed there opens nothing.
  await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
  check("the app came up again", Boolean(await where("phone_parts", 400)));
  await page.waitForTimeout(Number(args.load || 8000));
  if (check("Settings open, its AI row there", Boolean(await settings()))) {
    const row = await bring("ai_settings", await frameOf(/settings/i));
    if (row) await tap(row);
    const box = await frameOf(/settings/i);
    box.dialog = true;
    const who = await bring("ai_who_key", box);
    if (check("Settings, AI: \"another AI on your own key\" on the screen", Boolean(who))) {
      await tap(who);
      await picture("settings_ai");
      const field = await bring("ai_key", box);
      if (field) await list("Settings, AI", "ai_key", box);
      else check("Settings, AI: its key field on the screen", false);
    }
  }
  // The parts, in the app afresh: a tile's "+N" brought up the bin by a drag
  // on its tile, which scrolls it before and after, then a drag begun on the
  // "+N" back down, which moves it with the finger, its tile and the bin with
  // it. The bin's foot is where its line of words begins ("Showing ..."):
  // a "+N" under it is clipped, and a finger there is on the words.
  await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
  check("the app came up a third time", Boolean(await where("phone_parts", 400)));
  await page.waitForTimeout(Number(args.load || 8000));
  await tap(await still("phone_parts"));
  await page.waitForTimeout(2500);
  const bin = async () => {
    const told = await ask();
    const words = (told ? told.texts : []).find((t) => /^Showing /.test(t.text || ""));
    const foot = words ? words.box[1] : height;
    const badges = (told ? told.targets : []).filter((t) => /^\+\d+$/.test(t.text || "") && !t.off
      && t.box[1] >= 0 && t.box[1] < foot).sort((a, b) => a.box[1] - b.box[1] || a.box[0] - b.box[0]);
    return { foot, badges };
  };
  const centre = (t) => ({ x: t.box[0] + t.box[2] / 2, y: t.box[1] + t.box[3] / 2 });
  let { foot, badges: shown } = await bin();
  await picture("parts");
  if (check(`the parts: a tile's "+N" in the bin (${shown.length})`, shown.length > 0)) {
    const text = shown[0].text;
    const near = (list, was) => list.filter((t) => t.text === text)
      .sort((a, b) => Math.abs(a.box[0] - was.box[0]) - Math.abs(b.box[0] - was.box[0]))[0];
    // Up by its tile, above the "+N", to a third of the way down to the foot.
    const first = shown[0];
    const up = Math.round(first.box[1] - foot * 0.35);
    if (up > 8) {
      const on = { x: centre(first).x, y: first.box[1] - 12 };
      await drag(on, { x: on.x, y: on.y - up });
    }
    ({ foot, badges: shown } = await bin());
    const badge = near(shown, first);
    const room = badge ? Math.floor(foot - (badge.box[1] + badge.box[3]) - 8) : 0;
    if (check(`the parts: "${text}" wholly above the bin's foot (${badge ? badge.box[1] + badge.box[3] : "?"} of ${Math.round(foot)})`,
      Boolean(badge) && room >= 24)) {
      const by = Math.min(Math.round(height * 0.2), room, Math.max(up, 0));
      const at = centre(badge);
      await drag(at, { x: at.x, y: at.y + by });
      await picture("parts_by_the_badge");
      const after = near((await bin()).badges, badge);
      const went = after ? after.box[1] - badge.box[1] : 0;
      check(`the parts: a drag begun on "${text}" moves the bin with the finger (${went} points; the finger went ${by})`,
        by >= 8 && Math.abs(went - by) <= Math.max(6, by * 0.2));
    }
  }
  check(`no script error${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""}`, errors.length === 0);
  await context.close();
}

await browser.close();
check(`a list scrolled at one size at least (${scrolled})`, scrolled > 0);
console.log(failures ? `\nfield drag flow: ${failures} FAILED` : "\nfield drag flow: all passed");
process.exit(failures ? 1 : 0);
