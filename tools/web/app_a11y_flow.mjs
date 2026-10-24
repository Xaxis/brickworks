// The app's accessibility in a real browser: Interface size on a laptop and
// on a phone, and whether a screen reader there hears the app at all.
//
//   node tools/web/app_a11y_flow.mjs --url=<preview>/app --bypass=… --out=DIR
//   node tools/web/app_a11y_flow.mjs --url=http://127.0.0.1:9063/ --out=shots/app_a11y
//
// At 1280 x 800 by the mouse, then at 390 x 844 at 3x by a finger (the phone
// layout, PhoneShell): Settings (the comma key), Interface size chosen from
// its list as a person chooses it (the list opened, the arrows, Return), at
// 150% and at 85%, and back to 100%. Each time the app is bigger or smaller
// than before (a control's size on the page), and every control the app
// tells the page about (window.brickworksControls, each with its size) is
// wholly inside the window: nothing off the edge. Pictures in --out.
//
// And the question docs/COMPETITIVE.md item 14 left open: does AccessKit
// reach a screen reader in the WebAssembly build? Chromium's own
// accessibility tree (what a screen reader is given) is read, and the app's
// controls looked for by the names the desktop's screen reader says ("New,
// Ctrl+N"). Godot 4.7 builds AccessKit for Windows, macOS and Linux only
// (platform/web has no accessibility driver), so the answer expected is no:
// the tree is the page's canvas and nothing in it. It is printed either
// way, and fails only if the tree cannot be read.
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
const out = resolve(String(args.out || "shots/app_a11y"));
mkdirSync(out, { recursive: true });

let failures = 0;
const t0 = Date.now();
const check = (line, passed) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failures += 1;
  return passed;
};

// Settings, Interface size: the rows of its list, top down (ShellPrefs).
const SIZES = ["85%", "100%", "115%", "130%", "150%"];

const browser = await launch();

for (const phone of [false, true]) {
  const width = phone ? 390 : 1280;
  const height = phone ? 844 : 800;
  console.log(`\n${width} x ${height}${phone ? " at 3x, by a finger" : ", by the mouse"}`);
  const context = await browser.newContext(phone
    ? { viewport: { width, height }, deviceScaleFactor: 3, isMobile: true, hasTouch: true }
    : { viewport: { width, height } });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
  });
  const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
  const where = async (name, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const at = (await controls())[name];
      if (at) return at;
      await page.waitForTimeout(250);
    }
    return null;
  };
  const hit = async (at) => {
    if (phone) await page.touchscreen.tap(at.x, at.y);
    else await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(800);
  };
  const picture = (what) => page.screenshot({ path: `${out}/${width}_${what}.png`, timeout: 120000 })
    .catch((e) => console.log(`  --    no picture ${what}: ${String(e).split("\n")[0]}`));
  const mark = phone ? "phone_parts" : "open";

  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  check("the app came up", Boolean(await where(mark, 400)));
  await page.waitForTimeout(Number(args.load || 8000));

  if (!phone) {
    const cdp = await context.newCDPSession(page);
    const tree = await cdp.send("Accessibility.getFullAXTree").catch(() => null);
    const nodes = tree && tree.nodes ? tree.nodes : [];
    const named = nodes.map((n) => (n.name && n.name.value) || "").filter(Boolean);
    const app = named.filter((n) => /^(New, Ctrl\+N|Search parts|Select, V|View cube|Status)$/.test(n));
    check(`the browser's accessibility tree read: ${nodes.length} nodes`, nodes.length > 0);
    console.log(`  --    a screen reader in the browser hears the app's controls: ${app.length ? "yes" : "no"}`
      + ` (${app.length} of them in the tree; its names: ${JSON.stringify(named.slice(0, 8))})`);
  }

  // Settings, then Interface size chosen from its list.
  const choose = async (size) => {
    let choice = null;
    for (let tries = 0; tries < 40 && !choice; tries++) {
      if (tries === 8) {
        const view = (await controls()).view;
        if (view) await hit(view);
      }
      if (tries % 8 === 0) await page.keyboard.press("Comma");
      await page.waitForTimeout(500);
      choice = (await controls()).interface_size;
    }
    if (!check(`Settings open, its Interface size on the screen`, Boolean(choice))) return false;
    await hit(choice);
    for (let n = 0; n <= SIZES.indexOf(size); n++) {
      await page.keyboard.press("ArrowDown");
      await page.waitForTimeout(150);
    }
    await page.keyboard.press("Enter");
    await page.waitForTimeout(3000);
    const done = await where("settings_done", 10);
    if (done) await hit(done);
    await page.waitForTimeout(2500);
    return true;
  };

  const sized = {};
  for (const size of ["150%", "85%"]) {
    if (!(await choose(size))) continue;
    const now = await controls();
    const shown = Object.entries(now);
    const off = shown.filter(([, at]) => at.x - at.w / 2 < -1 || at.x + at.w / 2 > width + 1
      || at.y - at.h / 2 < -1 || at.y + at.h / 2 > height + 1);
    sized[size] = now[mark] ? now[mark].h : 0;
    await picture(size.replace("%", ""));
    check(`at ${size}, ${shown.length} controls on the page, none off the window`
      + (off.length ? `: ${off.slice(0, 5).map(([name, at]) => `${name} ${JSON.stringify(at)}`).join(", ")}` : ""),
    shown.length > 5 && off.length === 0);
  }
  check(`150% is bigger than 85% (${mark} ${sized["150%"]} px tall, then ${sized["85%"]})`,
    sized["150%"] > sized["85%"]);
  await choose("100%");
  check(`no script error${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""}`, errors.length === 0);
  await context.close();
}

await browser.close();
console.log(failures ? `\napp a11y flow: ${failures} FAILED` : "\napp a11y flow: all passed");
process.exit(failures ? 1 : 0);
