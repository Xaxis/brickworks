// What a session hears from in_view in a real browser, while a person has the
// timeline at step 4 of 9, a part in hand turned once with its ghost over the
// baseplate, and a reference picture laid; and that asking changes nothing.
//
//   set -a; . ./.env; set +a
//   node tools/web/in_view_flow.mjs --dir=build/web --out=shots/in_view            a local export, served here
//   BW_BYPASS=… node tools/web/in_view_flow.mjs --url=<preview>/app --out=shots/in_view
//   --size=1400x900 for another window (default 1280x720)
//
// in_view (src/net/hand_tools.gd, HandTools.in_view) is the read-only tool a
// session doing a person's CAD work calls to see what the person sees and it
// did not: the step the timeline is at, the part in their hand and where its
// ghost is, and the picture they build over. src/dev/mcpcad_probe.gd proves it
// on the desktop with the state set by code; this sets it as a person does,
// by the mouse and keys, in the web build:
//
//   1. The connector's private address, off the clipboard, called as Claude
//      calls it (freeze_check.mjs has how): in_view is in tools/list.
//   2. A model of nine 2 x 4 bricks, each a step of the author's (the shape
//      mcpcad_probe writes), opened through Open… > From a file, the page's
//      own file chooser answered.
//   3. Make › Reference picture…, by Find a command (Ctrl+/): the page's file
//      chooser takes tests/fixtures/photos/3039.jpg, laid on the floor; Esc
//      puts its settings away.
//   4. The toolbar's Timeline, and Next until "Step 4 of 9": the picture of
//      the view holds the red of step 1's brick and the yellow of step 3's.
//      Then --again times (default 4) the Timeline shut, opened again and
//      Next pressed three times, each the moment the caption changes, and
//      the picture read again. A count raised in place was, now and then,
//      never drawn in a browser: the caption said "Step 4 of 9 · 4 of 9
//      bricks" and the view showed the baseplate and the picture alone
//      (BrickWorld.draw_first). The scene was right in every such run; only
//      the picture showed it.
//   5. 3004 typed in the bin's search and its tile clicked: Brick 1 x 2 in
//      hand, the Place tool; the pointer rested over the baseplate beside the
//      stack until a ghost shows there; R turns it a quarter (its ghost's
//      pose turns).
//   6. look_at_model, then in_view twice, then look_at_model again (after a
//      first look, which alone carries the working method). in_view
//      has to say "at step 4 of 9", "In their hand: Brick 1 x 2 (3004)",
//      "rot 1", "its ghost under the pointer takes ... where a click puts it
//      down", "on the floor" and the picture's file name, with a picture
//      block; both its answers are the same, and so are look_at_model's; and
//      the page is as it was: parts, the timeline, the part in hand and its
//      ghost, the picture.
//
// Pictures of the window in that state in --out, named by the size, and
// in_view's text. No model is called; costs nothing. Fails, exiting 1, on any
// check that does not hold or a script error in the console.
import { controlsWith, launch, openColumnFor, withJobs } from "./browser.mjs";
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = resolve(String(args.out || "shots/in_view"));
mkdirSync(out, { recursive: true });
const [width, height] = String(args.size || "1280x720").split("x").map(Number);
const tag = `${width}x${height}`;
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const photo = resolve("tests/fixtures/photos/3039.jpg");

// Nine 2 x 4 bricks stacked, each a step of the author's: mcpcad_probe's
// _nine_steps, written here for the page's file chooser to take.
const nine = resolve(out, "in_view_nine_steps.ldr");
{
  const lines = ["0 Nine steps", "0 Name: in_view_nine_steps.ldr", "0 Author: in_view_flow"];
  for (let n = 0; n < 9; n++) {
    lines.push(`1 ${[4, 1, 14, 2][n % 4]} 0 ${-24 * n} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  }
  writeFileSync(nine, lines.join("\n") + "\n");
}

// A port nobody is using, for a local export.
async function freePort() {
  return new Promise((done) => {
    const s = createServer();
    s.listen(0, "127.0.0.1", () => { const { port } = s.address(); s.close(() => done(port)); });
  });
}

let server = null;
let url = args.url;
if (!url) {
  const dir = args.dir || "build/web";
  const port = await freePort();
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${dir}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  url = `http://127.0.0.1:${port}/`;
}

const t0 = Date.now();
const said = [];
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};
const errors = [];

const browser = await launch();
const finish = async (code) => {
  await browser.close().catch(() => {});
  if (server) server.kill();
  process.exit(code);
};
const context = await browser.newContext({ viewport: { width, height } });
await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(url).origin });
const page = await context.newPage();
const choosers = [];
page.on("filechooser", (chooser) => choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
writeFileSync(`${out}/console_${tag}.log`, "");
page.on("console", (m) => {
  appendFileSync(`${out}/console_${tag}.log`, `${((Date.now() - t0) / 1000).toFixed(1)}s ${m.text()}\n`);
  if (/SCRIPT ERROR|USER ERROR|Parse Error/.test(m.text())) errors.push(m.text().slice(0, 300));
});

const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 180000 });
    console.log(`        picture: ${out}/${name}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function until(test, seconds) {
  let now = await state();
  for (let n = 0; n < seconds * 2; n++) {
    if (test(now)) return now;
    await page.waitForTimeout(500);
    now = await state();
  }
  return test(now) ? now : null;
}
// A state told after now: the page is told twice a second at most.
async function fresh(ms = 450) {
  const before = (await state()).now || 0;
  for (let n = 0; n < 60; n++) {
    await page.waitForTimeout(150);
    const s = await state();
    if ((s.now || 0) - before >= ms) return s;
  }
  return state();
}
async function where(name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name.replace(/\W/g, "_")}_${tag}.png`);
  throw new Error(`the app never showed "${name}"`);
}
async function press(name, ms = 1500) {
  const at = await where(name);
  await page.mouse.click(at.x, at.y);
  if (ms) await page.waitForTimeout(ms);
}
const caption = async () => ((await state()).timeline || {}).caption || "";
// A picture of the window at a stage on the way, with where the view is
// (the camera's turn, tilt, distance and what it looks at): the timeline's
// Next frames each step's new parts, as the step player shows its page.
async function stage(name) {
  const v = (await fresh()).view || {};
  const r = (n) => Math.round(Number(n || 0) * 10) / 10;
  console.log(`        view at ${name}: yaw ${r(v.yaw)}, pitch ${r(v.pitch)}, distance ${r(v.distance)}, `
    + `looking at ${(v.focus || []).map(r).join(" ")}`);
  await shot(`stage_${name}_${tag}.png`);
}

// The view as drawn, its pixels of the red of step 1's brick and the yellow
// of step 3's counted (the window's picture decoded in a page of its own).
async function bricksDrawn(name) {
  const png = await page.screenshot({ path: `${out}/${name}`, timeout: 180000 });
  await page.evaluate(() => { window.brickworksAskLayout = true; });
  await page.waitForTimeout(1500);
  const view = ((await page.evaluate(() => window.brickworksLayout)) || {}).view || [0, 0, width, height];
  const reader = await browser.newPage();
  const counted = await reader.evaluate(async ([src, v]) => {
    const image = await new Promise((done) => { const i = new Image(); i.onload = () => done(i); i.src = src; });
    const canvas = document.createElement("canvas");
    canvas.width = image.width;
    canvas.height = image.height;
    const g = canvas.getContext("2d");
    g.drawImage(image, 0, 0);
    const d = g.getImageData(v[0], v[1], v[2], v[3]).data;
    let red = 0;
    let yellow = 0;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i] > 110 && d[i + 1] < 50 && d[i + 2] < 50) red++;
      if (d[i] > 170 && d[i + 1] > 140 && d[i + 2] < 90) yellow++;
    }
    return { red, yellow };
  }, [`data:image/png;base64,${png.toString("base64")}`, view]);
  await reader.close();
  console.log(`        picture: ${out}/${name}`);
  return { ...counted, drawn: counted.red > 50 && counted.yellow > 50 };
}

// Open… > From a file, answered with a file, as steps_flow.mjs opens one.
async function open(file) {
  const at = await where("open");
  for (let n = 0; n < 3; n++) {
    choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && choosers.length === 0; wait++) await page.waitForTimeout(500);
    const picker = choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return;
    }
    await shot(`no_picker_${n}_${tag}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up for Open… > From a file");
}

// Make › Reference picture…, by Find a command, as palette_flow.mjs finds one:
// the page's own file chooser answered with the photo.
async function layReference(file) {
  for (let n = 0; n < 3; n++) {
    choosers.length = 0;
    await page.focus("canvas");
    await page.keyboard.press("Control+Slash");
    const opened = await until((s) => (s.palette || {}).open === true, 20);
    if (!opened) {
      await shot(`no_palette_${n}_${tag}.png`);
      continue;
    }
    await page.keyboard.type("reference picture", { delay: 80 });
    const found = await until((s) => ((s.palette || {}).rows || [])[0] === "reference", 20);
    if (!found) {
      console.log(`        Find a command lists ${JSON.stringify(((await state()).palette || {}).rows)}`);
      await page.keyboard.press("Escape");
      await page.waitForTimeout(1500);
      continue;
    }
    await page.keyboard.press("Enter");
    for (let wait = 0; wait < 60 && choosers.length === 0; wait++) await page.waitForTimeout(500);
    const picker = choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return true;
    }
    await shot(`no_reference_picker_${n}_${tag}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  return false;
}

// What in_view must leave as it found: everything the page is told of the
// model, the timeline, the hand and the picture.
async function snapshot() {
  const s = await fresh();
  const reference = { ...(s.reference || {}) };
  return JSON.stringify({
    bricks: s.bricks, parts: s.parts, timeline: s.timeline, held: s.held, colour: s.colour,
    mode: s.mode, carrying: s.carrying, selected: s.selected, selection: s.selection,
    ghost_pose: s.ghost_pose, can_place: s.can_place, reference,
  });
}

async function run() {
  await page.goto(bypass
    ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
    : url, { waitUntil: "domcontentloaded", timeout: 180000 });
  ok(Boolean(await where("open", 400)), `the app came up at ${tag}`);
  await where("view", 120);
  await page.waitForTimeout(Number(args.load || 10000));

  // 1. The connector's private address, as freeze_check.mjs reads it.
  await openColumnFor(page, "connector_private");
  if ((await controlsWith(page, ["connector_private"])).connector_private) {
    await press("connector_private");
    await press("claude_here");
    await page.waitForTimeout(1500);
    await press("connector_private_copy");
  } else {
    await press("connect_claude");
    await page.waitForTimeout(1500);
    await press("connector_copy");
  }
  await page.waitForTimeout(1500);
  const address = await page.evaluate(() => navigator.clipboard.readText()).catch(() => "");
  if (!ok(address.includes("/api/mcp"), `the connector's private address is on the clipboard (${address.slice(0, 60)}…)`)) {
    await shot(`no_address_${tag}.png`);
    await finish(1);
  }
  let sent = 0;
  async function send(method, params) {
    sent += 1;
    const headers = { "content-type": "application/json", accept: "application/json, text/event-stream" };
    if (bypass) headers["x-vercel-protection-bypass"] = bypass;
    const answer = await fetch(address, {
      method: "POST", headers,
      body: JSON.stringify({ jsonrpc: "2.0", id: sent, method, params }),
    });
    return answer.json();
  }
  const claude = withJobs(send);
  await claude("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "in_view_flow", version: "1" } });
  const listed = await claude("tools/list", {});
  const names = (listed.result?.tools || []).map((t) => t.name);
  ok(names.includes("in_view"), `tools/list has in_view (${names.length} tools)`);
  const call = async (name, input = {}) => {
    const answer = await claude("tools/call", { name, arguments: input });
    const content = answer.result?.content || [];
    return { text: content.filter((c) => c.type === "text").map((c) => c.text).join("\n"),
      pictures: content.filter((c) => c.type === "image").length, error: answer.error || answer.result?.isError };
  };
  // A sitting's first answer carries the working method ahead of the tool's
  // own words (ClaudeConnector._taught), once: a look first, as a session
  // begins, so the looks either side of in_view are answered alike.
  await call("look_at_model");

  // 2. The model, nine steps of the author's.
  let note = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    await open(nine);
    note = await until((s) => /^opened \d+ parts/.test(s.said || ""), 240);
    console.log(`        the status bar: "${note ? note.said : (await state()).said}"`);
    if (note && !/arriving/.test(note.said)) break;
    await page.waitForTimeout(20000);
  }
  const opened = await until((s) => s.bricks === 9 && s.awaited === 0, 60);
  ok(Boolean(opened), `the nine-step model opened through Open… > From a file: ${(await state()).bricks} parts`);
  await page.waitForTimeout(3000);
  await stage("1_opened");

  // 3. The reference picture, laid on the floor.
  const laid = await layReference(photo);
  const picture = await until((s) => (s.reference || {}).name === "3039.jpg" && (s.reference || {}).shown, 60);
  ok(laid && Boolean(picture), `Make › Reference picture… takes 3039.jpg through the page's file chooser: `
    + `${JSON.stringify(Object.fromEntries(Object.entries((await state()).reference || {}).filter(([k]) => k !== "picture")))}`);
  if ((await state()).reference?.settings) {
    await page.keyboard.press("Escape");
    await until((s) => !(s.reference || {}).settings, 15);
  }
  ok(!(await state()).reference?.settings, "Esc puts its settings away");
  await stage("2_picture");

  // 4. The timeline, at step 4 of 9.
  await press("tool_timeline");
  const up = await until((s) => /^Step \d+ of 9/.test((s.timeline || {}).caption || ""), 60);
  console.log(`        the timeline came up: "${await caption()}" (${up ? up.timeline.order : "no timeline"})`);
  for (let n = 0; n < 12 && !/^Step 4 of 9/.test(await caption()); n++) {
    const at = Number((/^Step (\d+)/.exec(await caption()) || [])[1] || 0);
    await press(at > 4 ? "steps_back" : "steps_next");
  }
  ok(/^Step 4 of 9/.test(await caption()), `Next to step 4: "${await caption()}"`);
  await stage("3_step_4");
  await page.waitForTimeout(1500);
  let seen = await bricksDrawn(`stage_3_step_4_drawn_${tag}.png`);
  ok(seen.drawn, `...and its bricks are drawn: ${seen.red} px of step 1's red, ${seen.yellow} of step 3's yellow`);
  const again = Number(args.again ?? 4);
  let drawnAgain = 0;
  for (let n = 1; n <= again; n++) {
    await press("tool_timeline");
    await until((s) => !(s.timeline || {}).caption, 30);
    await press("tool_timeline", 0);
    await until((s) => /^Step 1 of 9/.test((s.timeline || {}).caption || ""), 60);
    for (let k = 0; k < 6 && !/^Step 4 of 9/.test(await caption()); k++) {
      const was = await caption();
      await press("steps_next", 0);
      await until((s) => ((s.timeline || {}).caption || "") !== was, 20);
    }
    const at = await caption();
    await page.waitForTimeout(3000);
    seen = await bricksDrawn(`stage_3_again_${n}_${tag}.png`);
    console.log(`        opened again ${n}: "${at}", ${seen.red} px red, ${seen.yellow} yellow`);
    if (/^Step 4 of 9/.test(at) && seen.drawn) drawnAgain++;
  }
  ok(drawnAgain === again, `opened again ${again} times, Next at once to step 4: its bricks drawn ${drawnAgain} times of ${again}`);

  // 5. A Brick 1 x 2 in hand, over the baseplate, turned once.
  await openColumnFor(page, "part search");
  const box = await where("part search", 60);
  await page.mouse.click(box.x, box.y);
  await page.keyboard.press("Control+a");
  await page.waitForTimeout(150);
  await page.keyboard.type("3004", { delay: 40 });
  await until((s) => (s.found || [])[0] === "3004", 30);
  const tile = await where("first part", 30);
  await page.mouse.click(tile.x, tile.y);
  const held = await until((s) => s.mode === "place" && s.held === "3004", 30);
  ok(Boolean(held), `its tile puts 3004 in hand with the Place tool (held ${(await state()).held}, ${(await state()).mode})`);
  ok(/^Step 4 of 9/.test(await caption()), `and the timeline stays at step 4: "${await caption()}"`);
  await stage("4_held");
  seen = await bricksDrawn(`stage_4_held_drawn_${tag}.png`);
  ok(seen.drawn, `...its bricks drawn still: ${seen.red} px of red, ${seen.yellow} of yellow`);

  // The pointer over the baseplate beside the stack, rested until a ghost
  // shows on the floor (the world's y is up; a 1 x 2 on the floor stands
  // lower than one on the stack's fourth brick).
  await page.evaluate(() => { window.brickworksAskLayout = true; });
  await page.waitForTimeout(1500);
  const layout = (await page.evaluate(() => window.brickworksLayout)) || {};
  const view = layout.view || [0, 0, width, height];
  const middle = [view[0] + view[2] / 2, view[1] + view[3] / 2];
  const offsets = [[0.28, 0.2], [-0.28, 0.2], [0.3, 0.05], [-0.3, 0.05], [0.2, 0.32], [-0.2, 0.32], [0.38, 0.28], [-0.38, 0.28]];
  let aim = null;
  let tried = [];
  for (const [dx, dy] of offsets) {
    const x = Math.round(middle[0] + dx * view[2]);
    const y = Math.round(middle[1] + dy * view[3]);
    await page.mouse.move(x - 6, y - 4, { steps: 2 });
    await page.mouse.move(x, y, { steps: 3 });
    await page.waitForTimeout(800);
    const s = await fresh();
    tried.push(`${x},${y}: ${s.ghost ? s.ghost.join(" ") : "no ghost"}`);
    if (s.ghost && s.ghost[1] < 30 && s.can_place) {
      aim = { x, y, ghost: s.ghost };
      break;
    }
  }
  ok(Boolean(aim), `the pointer rests over the baseplate and the ghost shows there (${aim ? `${aim.x}, ${aim.y}: ghost at ${aim.ghost.join(" ")}` : tried.join("; ")})`);
  const unturned = (await fresh()).ghost_pose;
  await page.keyboard.press("r");
  const turned = await until((s) => s.ghost_pose && unturned
    && JSON.stringify(s.ghost_pose.slice(3)) !== JSON.stringify(unturned.slice(3)), 20);
  ok(Boolean(turned) && (await state()).held === "3004",
    `R turns it a quarter: its ghost's pose turns (${unturned ? unturned.slice(3).join(" ") : "none"} → ${turned ? turned.ghost_pose.slice(3).join(" ") : "unchanged"})`);
  await page.waitForTimeout(3000);
  await shot(`in_view_${tag}.png`);

  // 6. Asked, twice, with look_at_model either side.
  const lookBefore = await call("look_at_model");
  const before = await snapshot();
  const first = await call("in_view");
  const middleState = await snapshot();
  const second = await call("in_view");
  const after = await snapshot();
  const lookAfter = await call("look_at_model");
  writeFileSync(`${out}/in_view_${tag}.txt`, first.text + "\n");
  console.log("        in_view said:");
  for (const line of first.text.split("\n")) console.log(`          ${line}`);
  const text = first.text;
  const hand = (text.split("\n").find((l) => l.includes("In their hand")) || "");
  ok(!first.error && text.includes("at step 4 of 9"), "in_view says the step: at step 4 of 9");
  ok(hand.includes("In their hand: Brick 1 x 2 (3004)") && hand.includes("the Place tool"),
    "...the part in hand: Brick 1 x 2 (3004), with the Place tool");
  ok(/its studs up, rot 1\b/.test(hand), "...which way it points: its studs up, rot 1");
  ok(/its ghost under the pointer takes x -?[\d.]+ to -?[\d.]+, z -?[\d.]+ to -?[\d.]+, y 0 to 3 plates, where a click puts it down/.test(hand),
    "...the span its ghost takes, on the floor, where a click puts it down");
  ok(/The reference picture: 3039\.jpg, on the floor, [\d.]+ x [\d.]+ studs/.test(text) && first.pictures === 1,
    `...and the reference picture, 3039.jpg on the floor, with its picture (${first.pictures} picture block)`);
  ok(second.text === first.text, "asked again, it says the same");
  ok(before === middleState && middleState === after,
    "...and asking changed nothing: the parts, the timeline, the part in hand and its ghost, the picture");
  if (before !== after) {
    console.log(`        before: ${before}`);
    console.log(`        after:  ${after}`);
  }
  writeFileSync(`${out}/look_before_${tag}.txt`, lookBefore.text + "\n");
  writeFileSync(`${out}/look_after_${tag}.txt`, lookAfter.text + "\n");
  ok(Boolean(lookBefore.text) && lookBefore.text === lookAfter.text,
    `look_at_model says the same before and after (${lookBefore.text.length} characters)`);
  if (lookBefore.text !== lookAfter.text) {
    const one = lookBefore.text.split("\n");
    const other = lookAfter.text.split("\n");
    for (let n = 0; n < Math.max(one.length, other.length); n++) {
      if (one[n] === other[n]) continue;
      console.log(`        before: ${one[n]}`);
      console.log(`        after:  ${other[n]}`);
    }
  }
  await shot(`in_view_after_${tag}.png`);

}

// A step that throws (a control that never shows, a picker that never comes)
// is a failure, said as one, with the relay put away.
try {
  await run();
} catch (e) {
  ok(false, `the flow stopped: ${String(e && e.message || e).split("\n")[0]}`);
  await shot(`stopped_${tag}.png`);
}
for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
ok(errors.length === 0, `no script error reached the console${errors.length ? ` (${errors.length})` : ""}`);
const failed = said.filter((l) => l.includes("FAIL")).length;
writeFileSync(`${out}/result_${tag}.txt`, said.join("\n") + "\n");
console.log(failed
  ? `in_view flow at ${tag}: ${failed} problem(s); pictures in ${out}`
  : `in_view flow at ${tag}: step 4 of 9, the part in hand turned with its ghost, and the picture laid, said as the person sees them, and nothing changed; pictures in ${out}`);
await finish(failed ? 1 : 0);
