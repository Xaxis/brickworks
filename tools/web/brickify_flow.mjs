// Brickify a 3D model in a real browser: an OBJ brought in through the
// page's own file chooser, its size typed in, Brickify pressed, and the
// model placed as a sub-assembly named after the file.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/brickify_flow.mjs --url=https://<a preview>/app --out=shots/brickify_web
//   node tools/web/brickify_flow.mjs --url=http://127.0.0.1:8147/index.html --out=…   (a local export)
//
// Presses I (a key is a press a browser lets open its file chooser), answers
// the chooser with tests/fixtures/brickify/bunny.obj, photographs the panel
// with the bunny turning in it, types 30 into the size box, presses
// Brickify and waits for it to land. It fails if a control never appears,
// no chooser comes up, the bunny does not arrive as the sub-assembly
// "bunny#1" holding every part placed (window.brickworksState.tree), it is
// not all selected, or a script error reaches the console. The web build
// works it out on a worker (BrickifyDialog), so the page goes on drawing
// meanwhile: the frames are timed while it works.
//
// Then what to do with it, from the panel that stays up once it is down:
// BrickLink and Rebrickable pressed, each list downloaded and its pieces
// counted against the build's, and Booklet pressed, its tab read for its
// pages of steps (its own steps, a course a step) and two of them
// photographed. --after=no leaves those out.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

// Until the booklet in the tab is whole, or ms have gone: it is written in
// as it is drawn (BookletOut, 2026-10-23), its first pages read while the
// rest are drawn, and whole once the app closes the document. Its first
// page is not the booklet: read then, it has no parts pages. Says whether
// it came whole.
async function bookletWhole(tab, ms) {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    const state = await tab.evaluate(() => document.readyState).catch(() => "");
    if (state === "complete") return true;
    await tab.waitForTimeout(2000);
  }
  return false;
}

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
// A preview sits behind Vercel's login; with BW_BYPASS the first load
// carries the bypass and sets its cookie, so the pack and the parts answer.
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/brickify_web";
mkdirSync(out, { recursive: true });
const model = resolve(args.model || "tests/fixtures/brickify/bunny.obj");
const studs = String(args.studs || 30);
// The sub-assembly is named after the file; --least is how few parts it may
// come to, --says a phrase its status line must have too ("on a stand").
const name = model.split("/").pop().replace(/\.[^.]+$/, "");
const least = Number(args.least || 300);
const says = args.says ? new RegExp(String(args.says)) : null;

const browser = await launch();
const errors = [];
const said = [];
const t0 = Date.now();
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
// Choosers are caught by a listener there from the start (studio_flow.mjs
// says why).
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil/i.test(m.text())) errors.push(m.text().slice(0, 300));
});

const controls = () => page.evaluate(() => window.brickworksControls || {});
const state = () => page.evaluate(() => window.brickworksState || null);
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 120000 });
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function until(test, seconds, what) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await page.waitForTimeout(500);
  }
  await shot(`never_${what.replace(/\W+/g, "_")}.png`);
  return false;
}
async function where(name, seconds = 120) {
  if (!(await until(async () => Boolean((await controls())[name]), seconds, name))) {
    throw new Error(`the app never showed "${name}"`);
  }
  return (await controls())[name];
}
async function click(name) {
  const at = await where(name);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
ok(await until(async () => Boolean((await controls()).open), 400, "app"), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));

// I, with the pointer over the model so the key goes to the canvas; tried
// again if no chooser came, since the app reads a key at its next frame and
// a software frame can take seconds.
const view = await where("view");
let chooser = null;
for (let n = 0; n < 3 && !chooser; n++) {
  page.choosers.length = 0;
  await page.mouse.move(view.x, view.y);
  await page.keyboard.press("Control+i");
  for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
  chooser = page.choosers.shift() || null;
}
ok(Boolean(chooser), "I brings up the page's file chooser");
if (chooser) await chooser.setFiles(model);
const panel = await until(async () => Boolean((await controls()).brickify_go), 120, "panel");
ok(panel, `the Brickify panel comes up for ${model.split("/").pop()}`);
await page.waitForTimeout(6000);
await shot("1_panel.png");

// Typed as a person types it: the box's text cleared first. Control+A did
// not always select it in a browser, the digits went after the old ones,
// and "2430" was taken as the largest size, 64: the fox was laid at 64
// studs, not 24, and its checks passed on what that said (2026-10-17).
const box = await where("brickify_studs");
const typed = Number(studs);
for (let attempt = 0; attempt < 3 && (await state())?.brickify_studs !== typed; attempt++) {
  await page.mouse.click(box.x, box.y);
  await page.keyboard.press("End");
  for (let n = 0; n < 6; n++) await page.keyboard.press("Backspace");
  await page.keyboard.type(studs, { delay: 60 });
  await page.keyboard.press("Enter");
  await page.waitForTimeout(2000);
}
ok((await state())?.brickify_studs === typed,
  `the size typed in is the size: ${(await state())?.brickify_studs} studs, asked ${typed}`);
await shot("2_sized.png");

const before = (await state())?.bricks || 0;
await click("brickify_go");
// The frames while it works: a worker does the work, so they keep coming.
const frames = await page.evaluate(() => new Promise((done) => {
  const times = [];
  let last = performance.now();
  const tick = (now) => {
    times.push(now - last);
    last = now;
    if (times.length < 20) requestAnimationFrame(tick);
    else done(times);
  };
  requestAnimationFrame(tick);
}));
const longest = Math.round(Math.max(...frames));
const landed = await until(async () => {
  const s = await state();
  return s && s.tree && s.tree[`${name}#1`] && !(await controls()).brickify_go;
}, 600, "landed");
const s = await state();
// The tree lists each sub-assembly's own parts by number, "3001,3004". A
// first visit's example car, untouched, is taken off to make room, so then
// the model is everything on the baseplate. Its side panels are sub-assemblies
// inside it ("bunny#1/bunny left panel 1#1"), built on the side in its booklet.
const top = `${name}#1`;
const paths = Object.keys(s?.tree || {}).filter((p) => p === top || p.startsWith(`${top}/`));
const inside = paths.reduce((sum, p) => sum + String(s.tree[p] || "").split(",").filter(Boolean).length, 0);
const all = s?.bricks || 0;
ok(landed && inside > least && (inside === all || all - before === inside),
  `it lands as the sub-assembly ${top}: ${inside} parts in it, ${paths.length - 1} side panels inside it, ${all} on the baseplate (${before} before)`);
ok(s?.selected === inside, `all of it selected, to move or turn: ${s?.selected}`);
// What the status line said: buildable in one piece, every part it needed here.
const summary = String(s?.brickified || "");
ok(/buildable in one piece/.test(summary) && !/never arrived/.test(summary) && (!says || says.test(summary)),
  `it says: "${summary}"`);
ok(true, `frames while it worked: the longest ${longest} ms of ${frames.length}`);
await page.waitForTimeout(8000);
await shot("3_placed_selected.png");

// What to do with it, a press each, from the panel that stays up.
if (args.after !== "no") {
  const after = await until(async () => Boolean((await controls()).brickify_bricklink), 60, "after");
  ok(after, "the panel stays up once it is down, with Booklet, BrickLink and Rebrickable");
  if (after) {
    for (const [control, kind] of [["brickify_bricklink", "xml"], ["brickify_rebrickable", "csv"]]) {
      const coming = page.waitForEvent("download", { timeout: 90000 }).catch(() => null);
      await click(control);
      const download = await coming;
      let text = "";
      let file = "no download";
      if (download) {
        file = download.suggestedFilename();
        await download.saveAs(`${out}/${file}`);
        text = readFileSync(`${out}/${file}`, "utf8");
      }
      const pieces = kind === "xml"
        ? [...text.matchAll(/<MINQTY>(\d+)<\/MINQTY>/g)].reduce((sum, m) => sum + Number(m[1]), 0)
        : text.trim().split("\n").slice(1).reduce((sum, row) => sum + Number(row.split(",")[2] || 0), 0);
      ok(pieces === inside, `${control.replace("brickify_", "")}, pressed: ${file}, ${pieces} pieces for its ${inside}`);
    }
    const steps = Number((summary.match(/(\d+) steps? by courses/) || [])[1] || 0);
    ok(steps > 1, `its own steps, by courses: ${steps}`);
    const opened = page.context().waitForEvent("page", { timeout: 60000 }).catch(() => null);
    await click("brickify_booklet");
    const tab = await opened;
    ok(Boolean(tab), "Booklet, pressed, opens a tab");
    if (tab) {
      const started = Date.now();
      let pages = 0;
      while (Date.now() - started < Number(args.wait || 900) * 1000) {
        pages = await tab.evaluate(() => document.querySelectorAll("section.page.steps").length)
          .catch(() => 0);
        if (pages > 0) break;
        await tab.waitForTimeout(3000);
      }
      ok(await bookletWhole(tab, Math.max(0, Number(args.wait || 900) * 1000 - (Date.now() - started))),
        `its booklet is whole (${Math.round((Date.now() - started) / 1000)} s)`);
      pages = await tab.evaluate(() => document.querySelectorAll("section.page.steps").length)
        .catch(() => 0);
      const numbers = await tab.evaluate(() => new Set([...document.querySelectorAll("section.page.steps")]
        .map((p) => (p.getAttribute("data-steps") || "").split(" ").filter(Boolean)).flat()).size)
        .catch(() => 0);
      ok(pages > 0 && numbers >= steps,
        `its booklet arrives in the tab in ${Math.round((Date.now() - started) / 1000)} s: ${pages} pages of steps holding ${numbers} steps, for its ${steps}`);
      for (const n of [1, Math.max(2, Math.floor(pages / 2))]) {
        const section = tab.locator(`section.page.steps >> nth=${n - 1}`);
        if ((await section.count().catch(() => 0)) > 0) {
          await section.screenshot({ path: `${out}/5_booklet_steps_${n}.png`, timeout: 120000 })
            .catch(() => {});
        }
      }
      await tab.close().catch(() => {});
    }
  }
}
await page.mouse.move(view.x, view.y);
await page.keyboard.press("Escape");
await page.waitForTimeout(8000);
await shot("4_placed.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `brickify flow: ${failed} problem(s); screenshots in ${out}`
  : `brickify flow: an OBJ brought in, sized, brickified and placed as a sub-assembly; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
