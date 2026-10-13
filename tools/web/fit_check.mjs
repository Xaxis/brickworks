// Does the whole app fit the page, at every screen density, with the model
// left clear?
//
//   node tools/web/fit_check.mjs --url=http://127.0.0.1:8743/index.html --out=shots/fit
//   node tools/web/fit_check.mjs --url=<preview>/app --quick --bypass=…   (what deploy.sh runs)
//
// At two device pixels to the point the app laid out 800 units of
// interface where it needs about 1270: the toolbar ran off at "He…" and
// the assistant panel was off the page, on every Retina screen. This
// opens the app at desktop sizes at 1x, 2x and 3x, laptop windows and a
// phone both ways, and asks where the app's own controls are
// (window.brickworksControls, centres in CSS pixels): every one shown
// must be inside the page, the toolbar's last button included.
//
// And at each size, the model's part of the window is sampled: nothing
// but the view cube may be over it. The model tree and the properties
// floated over the model's top corners, so a click meant for a part
// landed on a panel, and at 1100 x 700 the panels left no room to build.
// A build that publishes its layout (window.brickworksLayout, asked for
// with window.brickworksAskLayout) says which points of a 12 x 8 grid over
// the model a click would not reach it at, and every panel's rectangle; a
// build from before says only where its controls' centres are, so the
// model's rectangle is worked out from the rails and the toolbar, and any
// control of the model tree, the properties or the sub-assembly banner
// with its centre inside it is a panel over the model. In a laptop's
// window the model must also keep 60% of the width.
//
// A page whose app never came up is a failure of its own, said as one: "the
// app did not start in N s (load L)", after arrival_check's five minutes
// (START_MS; --start=<s> for fewer). A production deploy failed at load 80
// with nothing at all on the page at one size, reported as every control
// "not shown", on a build a rerun passed at every size. Up is the app
// publishing its controls; the layout checks after it are as strict as ever.
// --throttle=<n> slows each page's CPU n times (Chromium's
// Emulation.setCPUThrottlingRate), to see a slow start reported as one.
import { launch, START_MS } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { loadavg } from "node:os";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/fit";
// A preview sits behind Vercel's login: the bypass goes in the first
// address only, which sets a cookie for that domain alone.
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });
const startWithin = args.start ? Number(args.start) * 1000 : START_MS;
const throttle = Number(args.throttle || 1);

// width, height, ratio, the controls that must be on the page there, and
// the least share of the page's width the model keeps (0: not asked).
//
// A window under the design width (1600 units across) has room beside the
// model for one column, and a first visit shows the assistant's, with the
// parts bin folded to its rail: the key field is asked for at every
// desktop size, and both rails where one column shows. On a phone the
// panels are drawers and start closed. Phones were asked only for New and
// Save while the toolbar, a thousand units in one row, pushed Clear and
// the assistant's rail off the side of every phone: there the assistant
// could not be opened at all.
const BOTH = ["model_name", "new", "save", "clear", "key_field", "use_key"];
const ONE = ["model_name", "new", "save", "clear", "key_field", "use_key", "parts_rail",
  "assistant_rail"];
const PHONE = ["new", "save", "clear", "parts_rail", "assistant_rail"];
const ALL = [
  [1600, 900, 1, BOTH, 0],
  [1920, 1080, 2, BOTH, 0],
  [1400, 900, 1, ONE, 0.6],
  [1400, 900, 2, ONE, 0.6],
  [1280, 800, 2, ONE, 0.6],
  [1440, 900, 2, ONE, 0.6],
  [1440, 900, 3, ONE, 0.6],
  [1280, 720, 1, ONE, 0.6],
  [1100, 700, 1, ONE, 0.6],
  [1100, 760, 2, ONE, 0.6],
  [390, 844, 3, PHONE, 0],
  [844, 390, 3, PHONE, 0],
];
// Names a build from before they were published says nothing of.
const RAILS = ["parts_rail", "assistant_rail"];
// The controls of panels that must never be over the model, for a build
// that publishes only centres.
const PANEL_CONTROLS = ["outliner", "outliner_tree", "properties", "prop_x", "prop_y", "prop_z",
  "prop_turn", "assembly_done"];
// The deploy's: the density that broke, a laptop, and a phone.
const CASES = args.quick
  ? ALL.filter(([w, h, r]) => (w === 1400 && r === 2) || (w === 1100 && h === 700) || w === 390)
  : ALL;

const inside = (r, x, y) => x > r[0] && x < r[0] + r[2] && y > r[1] && y < r[1] + r[3];
// How much of b lies over a, ignoring a pixel's rounding along a shared edge.
const overlap = (a, b) => {
  const across = Math.min(a[0] + a[2], b[0] + b[2]) - Math.max(a[0], b[0]);
  const down = Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]);
  return across > 2 && down > 2 ? across * down : 0;
};

// The layout as the build publishes it, or null from a build that does not.
async function layoutOf(page) {
  await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
  for (let n = 0; n < 24; n++) {
    const layout = await page.evaluate(() => window.brickworksLayout || null);
    if (layout) return layout;
    await page.waitForTimeout(250);
  }
  return null;
}

// The model's rectangle from the centres an older build publishes: from
// the parts rail to the assistant's, and from the toolbar down as far
// below the model's middle as the toolbar is above it. A little larger
// than the model's own, never smaller.
function viewFromCentres(where) {
  const view = where.view, left = where.parts_rail, right = where.assistant_rail;
  if (!view || !left || !right) return null;
  const tops = ["new", "open", "save"].map((n) => where[n] && where[n].y).filter(Number.isFinite);
  if (!tops.length) return null;
  const half = view.y - Math.max(...tops);
  return [left.x, view.y - half, right.x - left.x, half * 2];
}

// Wait for the app to come up and lay out its toolbar, until a deadline:
// the controls it publishes, or null if it never published any. A page busy
// starting can keep a question waiting, so none waits past the deadline.
async function started(page, until) {
  let where = null;
  while (Date.now() < until) {
    // A question left waiting is dropped with the page; a page that went
    // somewhere else meanwhile has nothing to say yet.
    const asked = page.evaluate(() => window.brickworksControls || null).catch(() => null);
    const now = await Promise.race([asked,
      new Promise((done) => setTimeout(() => done(undefined), Math.max(until - Date.now(), 0)))]);
    if (now === undefined) break;
    where = now || where;
    if (where && where.save) break;
    await page.waitForTimeout(500);
  }
  return where;
}

const browser = await launch();
let failed = 0;
let unstarted = 0;
for (const [width, height, ratio, wanted, share] of CASES) {
  const label = `${width}x${height}@${ratio}x`;
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: ratio });
  const page = await context.newPage();
  if (throttle > 1) {
    const cdp = await context.newCDPSession(page);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: throttle });
  }
  const opened = Date.now();
  let trouble = "";
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: startWithin })
    .catch((error) => { trouble = `: ${error.message.split("\n")[0]}`; });
  const up = trouble ? null : await started(page, opened + startWithin);
  const waited = Math.round((Date.now() - opened) / 1000);
  if (!up) {
    await page.screenshot({ path: `${out}/${label}.png`, timeout: 30000 }).catch(() => {});
    failed++;
    unstarted++;
    console.log(`  FAIL  ${label}: the app did not start in ${waited} s (load ${loadavg()[0].toFixed(0)})${trouble}`);
    await context.close();
    continue;
  }
  await page.waitForTimeout(3000);
  const where = await page.evaluate(() => window.brickworksControls || {});
  const outside = [];
  // Up, but signed out: the sign-in screen is all there is.
  if (where.signin_email && !where.save) outside.push("the sign-in screen is up (is .env sourced?)");
  for (const name of wanted) {
    const at = where[name];
    if (!at) {
      // Clear is published from 2026-10-10; a build before that says nothing of it.
      if (name === "clear" && !("clear" in where)) continue;
      // The rails are published from 2026-10-11, both or neither.
      if (RAILS.includes(name) && !RAILS.some((rail) => rail in where)) continue;
      outside.push(`${name} not shown`);
      continue;
    }
    if (at.x < 0 || at.x > width || at.y < 0 || at.y > height) outside.push(`${name} at ${at.x},${at.y}`);
  }

  // The model's part of the window, and what is over it.
  const over = [];
  const layout = await layoutOf(page);
  const view = layout ? layout.view : viewFromCentres(where);
  if (!view) {
    over.push("the model's part of the window is not published");
  } else {
    if (layout) {
      for (const point of layout.covered) over.push(`${point.by} at ${point.x},${point.y}`);
      for (const [name, rect] of Object.entries(layout.panels)) {
        if (name === "cube") continue;
        const area = overlap(rect, view);
        if (area > 0) over.push(`${name} [${rect}] over ${area} px² of the model`);
      }
    }
    // Both kinds of build: no control of a floating panel inside it.
    for (const name of PANEL_CONTROLS) {
      const at = where[name];
      if (at && inside(view, at.x, at.y)) over.push(`${name} at ${at.x},${at.y}`);
    }
    if (share > 0 && view[2] < width * share) {
      over.push(`the model keeps ${Math.round((100 * view[2]) / width)}% of the width, under ${share * 100}%`);
    }
  }
  // A large canvas drawn in software can take longer than a screenshot's
  // default wait; the picture is evidence, not the check.
  await page.screenshot({ path: `${out}/${label}.png`, timeout: 120000 }).catch(() => {});
  const fits = outside.length === 0;
  const clear = over.length === 0;
  if (!fits || !clear) failed++;
  console.log(`  ${fits ? "ok  " : "FAIL"}  ${label}: ${fits ? `every control on the page (${wanted.join(", ")})` : outside.join("; ")}, up in ${waited} s`);
  const said = view ? `model [${view}]${layout ? `, ${layout.samples} points, columns ${layout.columns}` : " (from centres)"}` : "";
  const kept = view ? `, ${Math.round((100 * view[2]) / width)}% of the width` : "";
  console.log(`  ${clear ? "ok  " : "FAIL"}  ${label}: ${clear ? `nothing over the model (${said}${kept})` : `${over.slice(0, 6).join("; ")}${over.length > 6 ? `; and ${over.length - 6} more` : ""} (${said})`}`);
  await context.close();
}
await browser.close();
// 2 when the only failures are sizes the app never started at.
const misfits = failed - unstarted;
const said = [misfits ? `${misfits} failed` : "", unstarted ? `the app did not start at ${unstarted} size(s)` : ""];
console.log(failed ? said.filter(Boolean).join("; ") : "the app fits the page at every size and density, the model clear");
process.exit(misfits ? 1 : unstarted ? 2 : 0);
