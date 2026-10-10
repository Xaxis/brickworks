// A model keeps its name across a reload, and New begins another, in a real browser.
//
//   node tools/web/project_flow.mjs --url=https://brickworks.diy/app --out=shots/project
//
// The owner, in the web app: "there literally isnt a way to start a new
// project file. And when the app loads it loads the last project (which is
// fine) but it still says "Untitled" even though the project was saved and
// has a name!" So this names the model on the baseplate by typing, saves it,
// reloads the page, and reads the name back from the tab's title, which the
// app sets from the name field; then presses New and reads it again.
//
// The bar is drawn inside the canvas, so it is driven by position, the way
// assistant_flow.mjs is: the app publishes where its controls are
// (window.brickworksControls).
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/project";
const NAME = "Flow Tower";
mkdirSync(out, { recursive: true });

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
const page = await context.newPage();
const problems = [];
page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}

async function controlAt(name) {
  for (let tries = 0; tries < 600; tries++) {
    const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/missing_${name}.png` });
  throw new Error(`the app never showed its ${name} control`);
}

async function titleBecomes(wanted, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    if ((await page.title()) === wanted) return true;
    await page.waitForTimeout(500);
  }
  return false;
}

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
await controlAt("model_name");
// The example on the baseplate is something to save; give the parts a
// moment to arrive so the save is of the whole of it.
await page.waitForTimeout(8000);

// Name it by typing, as a person does.
const field = await controlAt("model_name");
await page.mouse.click(field.x, field.y);
await page.keyboard.press("Control+A");
await page.keyboard.type(NAME);
await page.keyboard.press("Enter");
check(`typing a name puts it in the tab: "${await page.title()}"`,
  await titleBecomes(`${NAME} — Brickworks`, 10));
const save = await controlAt("save");
await page.mouse.click(save.x, save.y);
// Past the autosave's settling time, so what reloads is what was saved.
await page.waitForTimeout(6000);
await page.screenshot({ path: `${out}/1_saved.png` });

await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
await controlAt("model_name");
check(`reloaded, the model is still called ${NAME}: "${await page.title()}"`,
  await titleBecomes(`${NAME} — Brickworks`, 120));
await page.screenshot({ path: `${out}/2_reloaded.png` });

// Saved and unchanged, so New begins at once.
const fresh = await controlAt("new");
await page.mouse.click(fresh.x, fresh.y);
check(`New begins an Untitled model: "${await page.title()}"`,
  await titleBecomes("Untitled — Brickworks", 20));
await page.waitForTimeout(1500);
await page.screenshot({ path: `${out}/3_new.png` });

check(`the page raised no errors${problems.length ? ": " + problems[0] : ""}`,
  problems.length === 0);
await browser.close();
console.log(failed ? `${failed} failed` : "a model keeps its name across a reload, and New begins another");
process.exit(failed ? 1 : 0);
