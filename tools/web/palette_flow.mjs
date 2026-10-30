// Find a command by keys alone, in a browser (CommandPalette, appux371 A9):
// Ctrl+/ opens the box over the model, "ren" puts Render… first, Return
// opens Render; opened again, Render is first as the last one run; a
// command that cannot be used now (Mirror, with nothing selected) is listed
// and says why, and Return runs nothing; Escape puts the box away and the
// keys go back to the model.
//
//   node tools/web/palette_flow.mjs --url=<preview>/app --bypass=… [--out=shots/palette_web]
//   node tools/web/palette_flow.mjs --url=http://127.0.0.1:8761/index.html
//
// At 1280 x 800. The page is told what the box shows
// (window.brickworksState.palette: open, typed, rows, lit, why); every act
// is a key press, the first after the canvas has the keys. Pictures in
// --out; it fails if a step does not happen or a script error is thrown.
import { launch, START_MS } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/palette_web";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}

async function until(page, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await page.waitForTimeout(500);
  }
  return false;
}

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const thrown = [];
page.on("pageerror", (error) => thrown.push(String(error)));
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
const controls = () => page.evaluate(() => window.brickworksControls || {});
const state = () => page.evaluate(() => window.brickworksState || {});
const box = async () => (await state()).palette || {};

if (check("the app comes up", await until(page, async () => Boolean((await controls()).app_menu),
  START_MS / 1000))) {
  // A model on the baseplate, so Render can be used: the first visit's
  // build, or the model left there.
  check("a model is on the baseplate", await until(page, async () => {
    const now = await state();
    return now.bricks > 0 && now.awaited === 0;
  }, 120));
  await page.focus("canvas");
  await page.keyboard.press("Control+Slash");
  const opened = await until(page, async () => (await box()).open === true, 20);
  check("Ctrl+/ opens Find a command", opened);
  await page.keyboard.type("ren", { delay: 120 });
  check("\"ren\" puts Render… first", await until(page, async () => {
    const now = await box();
    return now.typed === "ren" && (now.rows || [])[0] === "render";
  }, 20));
  await page.screenshot({ path: `${out}/typed.png` });
  await page.keyboard.press("Enter");
  check("Return opens Render, and the box is gone", await until(page, async () =>
    Boolean((await controls()).render_close) && !(await box()).open, 30));
  await page.screenshot({ path: `${out}/render.png` });
  const close = (await controls()).render_close;
  if (close) await page.mouse.click(close.x, close.y);
  await until(page, async () => !(await controls()).render_close, 20);

  // Nothing selected: Mirror is there, says why, and runs nothing.
  await page.focus("canvas");
  await page.keyboard.press("Escape");
  await page.keyboard.press("Control+Slash");
  await until(page, async () => (await box()).open === true, 20);
  check("opened again, Render is first, the last one run",
    await until(page, async () => ((await box()).rows || [])[0] === "render", 10));
  await page.keyboard.type("mirror", { delay: 120 });
  const greyed = await until(page, async () => (await box()).lit === "mirror", 20);
  const said = (await box()).why || "";
  check(`with nothing selected Mirror is listed, saying why ("${said}")`, greyed && said.length > 0);
  await page.screenshot({ path: `${out}/greyed.png` });
  await page.keyboard.press("Enter");
  await page.waitForTimeout(1500);
  const after = await state();
  const stayed = after.palette || {};
  await page.screenshot({ path: `${out}/greyed_return.png` });
  check(`...and Return there runs nothing: the box stays (open ${stayed.open}, lit ${stayed.lit}, `
    + `carrying ${after.carrying})`, stayed.open === true && after.carrying === false);
  await page.keyboard.press("Backspace");
  check("...with the keys still in it (Backspace: \"mirro\")",
    await until(page, async () => (await box()).typed === "mirro", 10));
  await page.keyboard.press("Escape");
  check("Escape puts it away", await until(page, async () => !(await box()).open, 10));
}
check(`no script error thrown${thrown.length ? ": " + thrown.slice(0, 3).join(" | ") : ""}`, thrown.length === 0);
await browser.close();
console.log(failed ? `palette flow: ${failed} checks failed` : "palette flow: all checks passed");
process.exit(failed ? 1 : 0);
