// A key set in the keys sheet, in a browser, kept over a reload (APP_UX
// A11): the keys as the page gives them to the web build, and the keys kept
// where the web build keeps its settings (src/ui/keymap.gd, ShellPrefs; the
// desktop's own check, a restart, is src/dev/keys_probe.gd).
//
//   python3 tools/web/serve.py build/web 8871 --parts assets/generated/parts --delay 0 &
//   node tools/web/keys_flow.mjs --url=http://127.0.0.1:8871/ --out=DIR
//   node tools/web/keys_flow.mjs --url=<preview>/app --bypass=… --out=DIR
//
// F1 opens the sheet; "paint" typed in its box finds the Paint tool's row;
// a click on its key, then Shift-B, sets it. Shift-B takes the Paint tool.
// The page is loaded again, and Shift-B takes the Paint tool still.
//
// A key set signed in is kept on the account too (api/account.js ?op=keys),
// so the page is signed in to a throwaway account of its own, deleted after
// with its keys. On the flows' shared test account one run's Shift-B was
// there for every other flow (rel-m222, 2026-10-30), and putting the keys
// back before and after was not enough: rel-m249 ran this flow on
// brickworks.diy and on its preview at once, each put the shared keys back
// while the other's Shift-B was on them, and both failed with nothing wrong
// in the app (2026-11-02). A browser of its own, signed in to the same
// account, must find the key.
import { askApp, launch } from "./browser.mjs";
import { canSignIn, deleteAccount, mintSession, signInContext } from "./session.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8871/";
const out = args.out || "shots/keys_web";
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

const site = url.replace(/\/app\/?(\?.*)?$/, "").replace(/\/$/, "");
const email = canSignIn() ? `delivered+bwkeys${Date.now()}@resend.dev` : "";
const session = email ? await mintSession(email).catch(() => null) : null;
// The account's keys. Null where there is no account to ask (a local
// server has no /api).
async function accountKeys() {
  if (!session) return null;
  const bypass = args.bypass ? `&x-vercel-protection-bypass=${args.bypass}` : "";
  try {
    const answer = await fetch(`${site}/api/account?op=keys${bypass}`, {
      headers: { Authorization: `Bearer ${session.access_token}` },
    });
    if (answer.status === 404) return null;
    return answer.ok ? await answer.json() : { status: answer.status };
  } catch {
    return null;
  }
}
const before = await accountKeys();
if (before !== null) ok(!before.status && before.keys === null, `a new account keeps no keys (${JSON.stringify(before)})`);

const browser = await launch({ signedOut: true });
const errors = [];
// The engine's own errors; a missing file the local server has not (an
// /api route) is not the app's.
function listen(one) {
  one.on("console", (m) => {
    if (/SCRIPT ERROR|USER SCRIPT ERROR|Uncaught/.test(m.text())) errors.push(m.text());
  });
  one.on("pageerror", (e) => errors.push(String(e)));
}
// A page of its own browser, signed in to the flow's account.
async function browserOfItsOwn() {
  const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  if (session) await signInContext(context, email);
  const one = await context.newPage();
  one.on("close", () => context.close().catch(() => {}));
  listen(one);
  return one;
}
let page = await browserOfItsOwn();

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
// Every word the window shows (main.gd words_shown): the canvas has none a
// page can read.
async function words() {
  return (await askApp(page, "Words")) || [];
}
async function until(test, seconds = 20) {
  for (let n = 0; n < seconds * 4; n++) {
    const now = await state();
    if (test(now)) return now;
    await wait(250);
  }
  return state();
}
// The app up, and the pointer over the model's view, where a tool's key is
// a person's.
async function started() {
  await controlAt("model_name");
  await wait(6000);
  const view = await controlAt("view");
  await page.mouse.move(view.x - 120, view.y + 80, { steps: 4 });
  await page.keyboard.press("Escape");
  await until((s) => s.mode === "select");
}
// Shift-B pressed over the view: the tool it takes, and back to Select.
async function shiftB() {
  await page.keyboard.press("Shift+KeyB");
  const now = await until((s) => s.mode === "paint", 10);
  await page.keyboard.press("Escape");
  await until((s) => s.mode === "select", 10);
  return now.mode;
}

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  await started();
  ok(await shiftB() !== "paint", "Shift-B takes no tool before it is set");

  await page.keyboard.press("F1");
  const find = await controlAt("keys_find", 20);
  await page.mouse.click(find.x, find.y);
  await page.keyboard.type("paint", { delay: 60 });
  await wait(1000);
  const chip = await controlAt("key_mode_paint", 20);
  ok(chip.y > 0 && chip.y < 900, `F1, "paint": the Paint tool's key in sight (${chip.x}, ${chip.y})`);
  await page.mouse.click(chip.x, chip.y);
  await wait(800);
  let said = await words();
  ok(said.some((w) => w.startsWith("Press the key for Paint tool")),
    `a click on it asks for a key: ${JSON.stringify(said.find((w) => w.startsWith("Press")) || "nothing")}`);
  await page.keyboard.press("Shift+KeyB");
  await wait(800);
  said = await words();
  ok(said.includes("Paint tool is now shift-B."),
    `Shift-B sets it: ${JSON.stringify(said.find((w) => w.startsWith("Paint tool")) || "nothing")}`);
  await page.screenshot({ path: `${out}/keys_set.png` });
  const done = await controlAt("settings_done", 20);
  await page.mouse.click(done.x, done.y);
  await wait(800);
  ok(await shiftB() === "paint", "Shift-B takes the Paint tool");

  // The browser keeps what the app wrote a moment after it wrote it.
  await wait(3000);
  await page.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  await page.evaluate(() => { window.brickworksControls = {}; window.brickworksState = {}; });
  await started();
  ok(await shiftB() === "paint", "the page loaded again: Shift-B takes the Paint tool still");
  await page.keyboard.press("F1");
  const again = await controlAt("keys_find", 20);
  await page.mouse.click(again.x, again.y);
  await page.keyboard.type("paint", { delay: 60 });
  await wait(1000);
  said = await words();
  ok(said.includes("B") && said.includes("the Paint tool: click a part to paint it"), "...and the sheet's Paint tool row says B");
  await page.screenshot({ path: `${out}/keys_after_reload.png` });

  // Kept on the account as well: a browser of its own, signed in to the same
  // account and with nothing of this one's, has the key too.
  if (before !== null) {
    let kept = null;
    for (let n = 0; n < 20 && !kept?.keys?.own?.mode_paint; n++) {
      kept = await accountKeys();
      await wait(500);
    }
    ok(Boolean(kept?.keys?.own?.mode_paint), `the account keeps it (${JSON.stringify(kept?.keys?.own ?? kept)})`);
    await page.close();
    page = await browserOfItsOwn();
    await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
    await started();
    ok(await shiftB() === "paint", "a browser of its own, signed in to the account: Shift-B takes the Paint tool");
  }
  ok(errors.length === 0, `no script error in the console${errors.length ? `: ${errors[0]}` : ""}`);
} finally {
  await browser.close();
  if (session) {
    const gone = await deleteAccount(email).catch(() => false);
    ok(gone, `the throwaway account is deleted (${email})`);
  }
}
console.log(`\nkeys (web): ${failed === 0 ? "every check passed" : `${failed} FAILED`}`);
process.exit(failed === 0 ? 0 : 1);
