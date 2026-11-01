// What the window says is shown is drawn, in a real browser: the build
// animation, a See inside cut moved up, and the booklet's step pictures,
// each counted off the picture.
//
//   node tools/web/drawn_flow.mjs --dir=build/web --out=shots/drawn                a local export, served here
//   BW_BYPASS=… node tools/web/drawn_flow.mjs --url=<preview>/app --out=shots/drawn
//   --size=1400x900 for another window (default 1280x720); --only=build,streamed,cut,booklet
//
// In a browser a count of instances raised in place, the new slots written
// into the buffer already drawn from, was now and then never drawn: the
// timeline at step 4 said "4 of 9 bricks" over a view with none
// (BrickWorld.draw_first, timeline4). The build animation, the cut moved
// and the booklet's pictures raise counts the same way. The model is nine
// 2 x 4 bricks stacked, red and yellow in turn, a step each, so the bricks
// drawn are the runs of red and yellow down the column of the picture that
// holds the most of them, however the picture is framed.
//
//   build    the assistant on, a made-up key taken and the brief answered
//            here, in the browser, with the nine bricks (assistant_flow's
//            --recorded way; nothing leaves the browser, costs nothing), the
//            design's stream dropped so it is asked for again and laid
//            whole: the model goes up as the build animation plays, and
//            once it ends all nine are drawn. --runs times (3), each a page
//            of its own.
//   streamed the same, streamed: the bricks go down as they are written,
//            and all nine are drawn once the design is in. --runs times.
//   cut      the nine opened through Open… > From a file, the toolbar's
//            cut, then the slider clicked from low to high --moves times
//            (5): each time the bricks below the plane are drawn, and the
//            one it goes through, as the plane's height says.
//   booklet  Instructions, the booklet in its tab: step N's picture holds
//            N bricks, for every step.
//
// Pictures in --out. Fails, exiting 1, on a count that is wrong, a step
// that does not happen, or a script error in the console. No model is
// called and nothing is signed in to.
import { controlsWith, launch, openColumnFor } from "./browser.mjs";
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = resolve(String(args.out || "shots/drawn"));
mkdirSync(out, { recursive: true });
const [width, height] = String(args.size || "1280x720").split("x").map(Number);
const tag = `${width}x${height}`;
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const only = new Set(String(args.only || "build,streamed,cut,booklet").split(","));
const runs = Number(args.runs || 3);
const moves = Number(args.moves || 5);

// Nine 2 x 4 bricks stacked, red (4) and yellow (14) in turn, a step each.
const COLOURS = [4, 14, 4, 14, 4, 14, 4, 14, 4];
const nine = resolve(out, "drawn_nine.ldr");
writeFileSync(nine, ["0 Nine bricks", "0 Name: drawn_nine.ldr", "0 Author: drawn_flow",
  ...COLOURS.flatMap((c, n) => [`1 ${c} 0 ${-24 * n} 0 1 0 0 0 1 0 0 0 1 3001.dat`, "0 STEP"])]
  .join("\n") + "\n");
// The same as a design the assistant submits: y in plates, up.
const DESIGN = { name: "Nine bricks", description: "Nine 2 x 4 bricks, red and yellow in turn.",
  bricks: COLOURS.map((color, n) => ({ part: "3001", color, x: 0, y: 3 * n, z: 0, rot: 0 })) };

// The bricks a picture draws: down the column that holds the most red and
// yellow, the runs of each, a run of one colour however often other pixels
// (ink, studs' shadows) break it. Run in a page, on its own canvas.
const COUNT = `(data, w, h) => {
  const kind = (i) => {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    if (r > 110 && g < 60 && b < 60) return 1;
    // Not the orange (213, 144, 50) a booklet draws round the step's new part.
    if (r > 170 && g > 140 && b < 90 && g >= 0.75 * r) return 2;
    return 0;
  };
  const per = new Array(w).fill(0);
  let red = 0, yellow = 0;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const k = kind((y * w + x) * 4);
    if (k) per[x]++;
    if (k === 1) red++;
    if (k === 2) yellow++;
  }
  let best = 0;
  for (let x = 1; x < w; x++) if (per[x] > per[best]) best = x;
  // Down a column: its runs of one colour, the specks under 3 px dropped,
  // then those of one colour next to each other made one.
  const down = (x) => {
    const runs = [];
    for (let y = 0; y < h; y++) {
      const k = kind((y * w + x) * 4);
      if (!k) continue;
      if (runs.length && runs[runs.length - 1][0] === k && runs[runs.length - 1][2] === y - 1) {
        runs[runs.length - 1][1]++;
        runs[runs.length - 1][2] = y;
      } else runs.push([k, 1, y]);
    }
    let bricks = 0, last = 0;
    for (const [k, length] of runs) {
      if (length < 3 || k === last) continue;
      bricks++;
      last = k;
    }
    return bricks;
  };
  let bricks = 0;
  for (const x of [best - 4, best - 2, best, best + 2, best + 4]) {
    if (x >= 0 && x < w && per[best] > 0) bricks = Math.max(bricks, down(x));
  }
  return { bricks, red, yellow, column: best };
}`;

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
  const port = await freePort();
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${args.dir || "build/web"}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  url = `http://127.0.0.1:${port}/`;
}
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;

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

// A page of the app's own, with what it says to the console kept.
async function app(name) {
  const context = await browser.newContext({ viewport: { width, height } });
  const page = await context.newPage();
  page.choosers = [];
  page.on("filechooser", (c) => page.choosers.push(c));
  page.on("pageerror", (e) => errors.push(`${name}: ${String(e).slice(0, 200)}`));
  writeFileSync(`${out}/console_${name}_${tag}.log`, "");
  page.on("console", (m) => {
    appendFileSync(`${out}/console_${name}_${tag}.log`, `${((Date.now() - t0) / 1000).toFixed(1)}s ${m.text()}\n`);
    if (/SCRIPT ERROR|USER ERROR|Parse Error/.test(m.text())) errors.push(`${name}: ${m.text().slice(0, 300)}`);
  });
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  return { context, page };
}
const state = async (page) => (await page.evaluate(() => window.brickworksState || {})) || {};
async function until(page, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    const s = await state(page);
    if (test(s)) return s;
    await page.waitForTimeout(500);
  }
  return null;
}
async function where(page, name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = ((await page.evaluate(() => window.brickworksControls || {})) || {})[name];
    if (at) return at;
    if (n % 10 === 6) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/never_${name}_${tag}.png`, timeout: 180000 }).catch(() => {});
  throw new Error(`the app never showed "${name}"`);
}
async function press(page, name, ms = 1500) {
  const at = await where(page, name);
  await page.mouse.click(at.x, at.y);
  if (ms) await page.waitForTimeout(ms);
}

// The bricks drawn in the model's part of the window, from a picture of it.
async function drawn(page, name) {
  const png = await page.screenshot({ path: `${out}/${name}_${tag}.png`, timeout: 180000 });
  await page.evaluate(() => { window.brickworksAskLayout = true; });
  await page.waitForTimeout(1500);
  const view = ((await page.evaluate(() => window.brickworksLayout)) || {}).view || [0, 0, width, height];
  const reader = await browser.newPage();
  const counted = await reader.evaluate(async ([src, v, count]) => {
    const image = await new Promise((done) => { const i = new Image(); i.onload = () => done(i); i.src = src; });
    const canvas = document.createElement("canvas");
    canvas.width = image.width;
    canvas.height = image.height;
    const g = canvas.getContext("2d");
    g.drawImage(image, 0, 0);
    return eval(count)(g.getImageData(v[0], v[1], v[2], v[3]).data, v[2], v[3]);
  }, [`data:image/png;base64,${png.toString("base64")}`, view, COUNT]);
  await reader.close();
  console.log(`        ${name}: ${counted.bricks} bricks (${counted.red} px red, ${counted.yellow} yellow), ${out}/${name}_${tag}.png`);
  return counted;
}

// Open… > From a file, answered with a file, as in_view_flow opens one.
async function open(page, file) {
  const at = await where(page, "open", 400);
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let w = 0; w < 60 && !page.choosers.length; w++) await page.waitForTimeout(500);
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return Boolean(await until(page, (s) => s.bricks === 9 && s.awaited === 0, 240));
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up for Open… > From a file");
}

// Anthropic, answered in the browser: the key's check, the design as one
// submit_design, and anything after it a word that ends the turn. [drop]:
// the design's stream dropped, so the app asks again without one and gets
// the design whole.
function recordedBrain(page, drop) {
  const asked = [];
  let designed = false;
  const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "*",
    "access-control-allow-methods": "GET, POST, OPTIONS" };
  const sse = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
  const reply = (id, model, block, stop) => {
    const content = block.input
      ? { type: "tool_use", id: `${id}_0`, name: "submit_design", input: {} }
      : { type: "text", text: "" };
    const delta = block.input
      ? { type: "input_json_delta", partial_json: JSON.stringify(block.input) }
      : { type: "text_delta", text: block.text };
    const usage = { input_tokens: 2000, output_tokens: 400 };
    return sse([
      { type: "message_start", message: { id, type: "message", role: "assistant", model, content: [],
        stop_reason: null, usage: { input_tokens: 2000, output_tokens: 1 } } },
      { type: "content_block_start", index: 0, content_block: content },
      { type: "content_block_delta", index: 0, delta },
      { type: "content_block_stop", index: 0 },
      { type: "message_delta", delta: { stop_reason: stop, stop_sequence: null }, usage },
      { type: "message_stop" },
    ]);
  };
  page.route(/^https:\/\/api\.anthropic\.com\//, (route) => {
    const request = route.request();
    if (request.method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
    if (request.url().includes("/v1/models")) {
      return route.fulfill({ status: 200, headers: { ...cors, "content-type": "application/json" },
        body: JSON.stringify({ data: [{ type: "model", id: "claude-opus-5-5" }], has_more: false }) });
    }
    const body = JSON.parse(request.postData() || "{}");
    asked.push((body.messages || []).length);
    asked.at = Date.now();
    if (!designed && drop && body.stream) return route.abort("connectionreset");
    const design = !designed;
    designed = true;
    // Which request the design answered, so a check waits for the one after
    // it: the design laid and its result sent back.
    if (design) asked.design = asked.length;
    if (!body.stream) {
      const content = design
        ? [{ type: "tool_use", id: "msg_design_0", name: "submit_design", input: DESIGN }]
        : [{ type: "text", text: "Nine bricks, red and yellow in turn." }];
      return route.fulfill({ status: 200, headers: { ...cors, "content-type": "application/json" },
        body: JSON.stringify({ id: `msg_${asked.length}`, type: "message", role: "assistant", model: body.model,
          content, stop_reason: design ? "tool_use" : "end_turn", stop_sequence: null,
          usage: { input_tokens: 2000, output_tokens: 400 } }) });
    }
    const text = design
      ? reply("msg_design", body.model, { input: DESIGN }, "tool_use")
      : reply(`msg_${asked.length}`, body.model, { text: "Nine bricks, red and yellow in turn." }, "end_turn");
    return route.fulfill({ status: 200, headers: { ...cors, "content-type": "text/event-stream" }, body: text });
  });
  return asked;
}

// The assistant's design, then whole. [again]: its stream dropped and the
// answer asked for again, laid at once, which is when the app's own design
// goes up as the build animation; streamed, the bricks go down as they are
// written instead, a sketch the finished design keeps (Assistant._apply), and
// nothing is left to animate.
async function build(run, again) {
  const name = `build_${again ? "again" : "streamed"}_${run}`;
  const { context, page } = await app(name);
  try {
    const asked = recordedBrain(page, again);
    await where(page, "open", 400);
    await page.waitForTimeout(Number(args.load || 8000));
    await press(page, "key_field");
    await page.keyboard.type(`sk-ant-api03-drawnflow${"0".repeat(80)}`, { delay: 5 });
    await press(page, "use_key");
    await where(page, "brief", 120);
    // One design, not three sketches to choose from: Sketch first starts
    // ticked.
    if (((await page.evaluate(() => window.brickworksControls || {})) || {}).sketch_first) {
      await press(page, "sketch_first", 1000);
    }
    await press(page, "brief", 800);
    await page.keyboard.type("nine 2 x 4 bricks stacked, red and yellow in turn", { delay: 10 });
    // Every state the app writes, kept in the page: the animation is 2 s by
    // the wall clock, which in software is two or three frames, between
    // which a poll from here can miss it.
    await page.evaluate(() => {
      window.drawnSeen = [];
      let last = null;
      setInterval(() => {
        const s = window.brickworksState;
        if (s && s !== last) window.drawnSeen.push({ now: s.now, bricks: s.bricks, playing: !!s.playing });
        last = s;
      }, 10);
    });
    await press(page, "build", 0);
    // Not by the count alone: a first visit's example car counts too, until
    // the design takes it off the baseplate, and the app's surface pass then
    // lays its own proposal on the top, in the top's colour, and asks again.
    // Done is the design answered, its result asked about and nothing asked
    // for 5 s.
    const built = await until(page, (s) => asked.design && asked.length > asked.design
      && Date.now() - asked.at > 5000 && s.bricks >= 9 && s.playing === false, 300);
    const states = await page.evaluate(() => window.drawnSeen);
    const playing = states.filter((s) => s.playing);
    console.log(`        ${name}: ${states.length} states written, playing in ${playing.length}`
      + `${playing.length ? ` (${playing.map((s) => s.now).join(", ")} ms)` : ""}`);
    await page.waitForTimeout(3000);
    const seen = await drawn(page, `${name}_after`);
    const how = again
      ? `asked again after the stream dropped, the design went up ${playing.length ? "as the build animation played" : "WITHOUT the build animation"}`
      : "streamed, the design went down as it was written";
    ok((!again || playing.length > 0) && Boolean(built) && seen.bricks === 9,
      `${how}, and then ${seen.bricks} of 9 bricks are drawn (run ${run}, ${asked.length} request(s) answered)`);
  } finally {
    await context.close();
  }
}

// The cut moved up the stack a click at a time, and the booklet.
async function cutAndBooklet() {
  const { context, page } = await app("cut");
  try {
    await where(page, "open", 400);
    await where(page, "view", 120);
    await page.waitForTimeout(Number(args.load || 8000));
    ok(await open(page, nine), `the nine bricks open through Open… > From a file: ${(await state(page)).bricks} parts`);
    await page.waitForTimeout(3000);
    const whole = await drawn(page, "cut_0_whole");
    ok(whole.bricks === 9, `all nine drawn before the cut: ${whole.bricks}`);
    if (only.has("cut")) {
      await press(page, "tool_cut");
      const on = await until(page, (s) => s.cut && s.cut.on, 120);
      ok(Boolean(on) && on.cut.axis === 1, `the toolbar's cut is on, across the stack (axis ${on ? on.cut.axis : "?"}, at ${on ? Math.round(on.cut.at) : "?"})`);
      await page.waitForTimeout(3000);
      const slider = await where(page, "cut_slider");
      // From near the foot of its track to near its top, a click a move:
      // each puts the plane higher, so each raises the counts drawn.
      let right = 0;
      for (let n = 0; n < moves; n++) {
        const x = Math.round(slider.x - slider.w * 0.4 + (slider.w * 0.8 * n) / Math.max(1, moves - 1));
        const before = (await state(page)).cut.at;
        await page.mouse.move(x, slider.y, { steps: 2 });
        await page.mouse.click(x, slider.y);
        const moved = await until(page, (s) => s.cut && Math.abs(s.cut.at - before) > 0.5, 30);
        const at = (moved || (await state(page))).cut.at;
        await page.waitForTimeout(3000);
        const seen = await drawn(page, `cut_${n + 1}_at_${Math.round(at)}`);
        // Wholly below the plane, and the one it goes through, which may
        // show too little of itself to count.
        const below = Math.max(0, Math.min(9, Math.floor(at / 24)));
        const through = Math.max(0, Math.min(9, Math.ceil(at / 24)));
        const fits = seen.bricks >= below && seen.bricks <= through;
        if (fits) right++;
        console.log(`        cut at ${at.toFixed(1)}: ${below} wholly below, ${through} with the one it goes through; ${seen.bricks} drawn ${fits ? "" : "WRONG"}`);
      }
      ok(right === moves, `the cut moved up ${moves} times: the bricks below it drawn ${right} times of ${moves}`);
      await press(page, "tool_cut");
      await until(page, (s) => s.cut && !s.cut.on, 60);
    }
    if (only.has("booklet")) await booklet(page, context);
  } finally {
    await context.close();
  }
}

// Instructions: step N's picture holds N bricks.
async function booklet(page, context) {
  const at = (await controlsWith(page, ["instructions"])).instructions || await where(page, "instructions");
  const opened = context.waitForEvent("page", { timeout: 60000 });
  await page.mouse.click(at.x, at.y);
  const tab = await opened.catch(() => null);
  if (!ok(tab !== null, "Instructions opens the booklet's tab")) return;
  tab.on("pageerror", (e) => errors.push(`booklet: ${String(e).slice(0, 200)}`));
  // Written in as it is drawn, and whole once the app closes the document
  // (booklet_flow's bookletWhole).
  const started = Date.now();
  let whole = false;
  while (!whole && Date.now() - started < Number(args.wait || 600) * 1000) {
    whole = (await tab.evaluate(() => document.readyState).catch(() => "")) === "complete";
    if (!whole) await tab.waitForTimeout(2000);
  }
  ok(whole, `...and the booklet comes whole in ${Math.round((Date.now() - started) / 1000)} s`);
  const counted = await tab.evaluate(async (count) => {
    const read = eval(count);
    const out = [];
    for (const img of document.querySelectorAll('img[alt^="Step "]')) {
      if (!img.complete) await new Promise((done) => { img.onload = done; img.onerror = done; });
      const canvas = document.createElement("canvas");
      canvas.width = img.naturalWidth;
      canvas.height = img.naturalHeight;
      const g = canvas.getContext("2d");
      g.drawImage(img, 0, 0);
      const seen = read(g.getImageData(0, 0, canvas.width, canvas.height).data, canvas.width, canvas.height);
      out.push({ step: Number(img.alt.replace(/\D+/g, "")), png: canvas.toDataURL("image/png"), ...seen });
    }
    return out;
  }, COUNT).catch((e) => [{ step: 0, bricks: -1, error: String(e).slice(0, 200) }]);
  await tab.screenshot({ path: `${out}/booklet_${tag}.png`, fullPage: true, timeout: 180000 }).catch(() => {});
  let right = 0;
  for (const one of counted) {
    const fits = one.bricks === one.step;
    if (fits) right++;
    const file = `${out}/booklet_step_${one.step}_${tag}.png`;
    if (one.png) writeFileSync(file, Buffer.from(one.png.split(",")[1], "base64"));
    console.log(`        booklet step ${one.step}: ${one.bricks} bricks (${one.red} px red, ${one.yellow} yellow) ${fits ? "" : "WRONG"} ${file}`);
  }
  ok(counted.length === 9 && right === 9,
    `the booklet's ${counted.length} step pictures each hold the step's bricks: ${right} of ${counted.length}`);
}

try {
  if (only.has("cut") || only.has("booklet")) await cutAndBooklet();
  if (only.has("build")) for (let run = 1; run <= runs; run++) await build(run, true);
  if (only.has("streamed")) for (let run = 1; run <= runs; run++) await build(run, false);
} catch (e) {
  ok(false, `the flow stopped: ${String(e && e.message || e).split("\n")[0]}`);
}
for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
ok(errors.length === 0, `no script error reached the console${errors.length ? ` (${errors.length})` : ""}`);
const failed = said.filter((l) => l.includes("FAIL")).length;
writeFileSync(`${out}/result_${tag}.txt`, said.join("\n") + "\n");
console.log(failed
  ? `drawn flow at ${tag}: ${failed} problem(s); pictures in ${out}`
  : `drawn flow at ${tag}: the build animation, the cut moved and the booklet draw what they say; pictures in ${out}`);
await finish(failed ? 1 : 0);
