// A colour key in a browser (APP_UX2 keys3): the selection painted a
// favourite colour in one key and taken back by one undo, and the model's
// most used colour on Ctrl-Shift-1, with the keys as a browser gives them to
// the web build (Shift-2 arrives as "@" or '"', its place on the keyboard
// Digit2). The desktop's own check is src/dev/keys3_probe.gd.
//
//   python3 tools/web/serve.py build/web 8871 --parts assets/generated/parts --delay 0 &
//   node tools/web/colour_keys_flow.mjs --url=http://127.0.0.1:8871/ --out=DIR
//   node tools/web/colour_keys_flow.mjs --url=<preview>/app --bypass=… --out=DIR
//
// Signed out: the favourites are the app's own, favourite 2 Light Bluish
// Grey (71), and the model the sample car.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8871/";
const out = args.out || "shots/colour_keys_web";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

let failed = 0;
const ok = (passed, line) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}`);
  if (!passed) failed += 1;
  return passed;
};

const browser = await launch();
const errors = [];
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER SCRIPT ERROR|Uncaught/.test(m.text())) errors.push(m.text());
});
page.on("pageerror", (e) => errors.push(String(e)));

const wait = (ms) => page.waitForTimeout(ms);
const state = () => page.evaluate(() => window.brickworksState || {});
async function controlAt(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate(() => window.brickworksControls || {});
    if (where && where[name]) return where[name];
    await wait(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
async function until(test, seconds = 20) {
  for (let n = 0; n < seconds * 4; n++) {
    const now = await state();
    if (test(now)) return now;
    await wait(250);
  }
  return state();
}
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
await controlAt("model_name");
await until((s) => s.bricks > 2 && s.awaited === 0, 120);
await wait(6000);
const view = await controlAt("view");
await page.mouse.move(view.x - 120, view.y + 80, { steps: 4 });
await page.keyboard.press("Escape");
await until((s) => s.mode === "select");

await page.keyboard.press("Control+a");
const chosen = await until((s) => s.selected > 2);
const was = chosen.selected_colours || [];
ok(chosen.selected >= 3, `Ctrl+A selects the model's ${chosen.selected} parts (${JSON.stringify(was)})`);

await page.keyboard.press("Shift+Digit2");
const painted = await until((s) => (s.selected_colours || []).every((c) => c === 71) && !same(s.selected_colours, was), 10);
ok((painted.selected_colours || []).length === was.length && painted.selected_colours.every((c) => c === 71),
  `Shift-2 paints them all favourite 2, Light Bluish Grey, in one key (${JSON.stringify(painted.selected_colours)})`);
await wait(1500);
await page.screenshot({ path: `${out}/painted.png` });

await page.keyboard.press("Control+z");
const undone = await until((s) => same(s.selected_colours, was), 10);
ok(same(undone.selected_colours, was), `one Ctrl+Z takes it all back (${JSON.stringify(undone.selected_colours)})`);

// The model's most used colour, counted from the sample the page opens with
// (models/car.ldr) as ColourKeys.most_used counts: brickworksState gives
// only the first few parts' colours.
const counts = {};
const lines = readFileSync("models/car.ldr", "utf8").split("\n").filter((l) => /^1\s/.test(l));
for (const line of lines) {
  const c = Number(line.split(/\s+/)[1]);
  if (c !== 16 && c !== 24) counts[c] = (counts[c] || 0) + 1;
}
const most = Number(Object.keys(counts).sort((a, b) => counts[b] - counts[a] || a - b)[0]);
ok(chosen.selected === lines.length, `the page opened the sample car, ${lines.length} parts, its most used colour ${most} (${counts[most]} of them)`);
await page.keyboard.press("Control+Shift+Digit1");
const used = await until((s) => (s.selected_colours || []).every((c) => c === most) && !same(s.selected_colours, was), 10);
ok((used.selected_colours || []).every((c) => c === most) && !same(used.selected_colours, was),
  `Ctrl-Shift-1 paints them the model's most used colour, ${most} (${JSON.stringify(used.selected_colours)})`);
await page.keyboard.press("Control+z");
const back = await until((s) => same(s.selected_colours, was), 10);
ok(same(back.selected_colours, was), `...and one Ctrl+Z takes that back (${JSON.stringify(back.selected_colours)})`);
ok(page.url().split("#")[0] === first.split("#")[0] || page.url().startsWith(url),
  `the page is the app still, not a browser tab's (${page.url()})`);
ok(errors.length === 0, `no script error in the console${errors.length ? `: ${errors[0]}` : ""}`);

await browser.close();
console.log(`\ncolour keys (web): ${failed === 0 ? "every check passed" : `${failed} FAILED`}`);
process.exit(failed === 0 ? 0 : 1);
