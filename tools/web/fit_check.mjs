// Does the whole app fit the page, at every screen density?
//
//   node tools/web/fit_check.mjs --url=http://127.0.0.1:8743/index.html --out=shots/fit
//   node tools/web/fit_check.mjs --url=<preview>/app --quick --bypass=…   (what deploy.sh runs)
//
// At two device pixels to the point the app laid out 800 units of
// interface where it needs about 1270: the toolbar ran off at "He…" and
// the assistant panel was off the page, on every Retina screen. This
// opens the app at desktop sizes at 1x, 2x and 3x, a small laptop window
// and a phone both ways, and asks where the app's own controls are
// (window.brickworksControls, centres in CSS pixels): every one shown
// must be inside the page, the toolbar's last button included.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

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

// width, height, ratio, and the controls that must be on the page there.
// On a narrow screen the panels are drawers and start closed, so only the
// toolbar is asked for.
const ALL = [
  [1400, 900, 1, ["model_name", "new", "save", "clear", "key_field", "use_key"]],
  [1400, 900, 2, ["model_name", "new", "save", "clear", "key_field", "use_key"]],
  [1280, 800, 2, ["model_name", "new", "save", "clear", "key_field", "use_key"]],
  [1920, 1080, 2, ["model_name", "new", "save", "clear", "key_field", "use_key"]],
  [1440, 900, 3, ["model_name", "new", "save", "clear", "key_field", "use_key"]],
  [1100, 760, 2, ["model_name", "new", "save", "clear"]],
  [390, 844, 3, ["new", "save"]],
  [844, 390, 3, ["new", "save"]],
];
// The deploy's: the density that broke, and a phone.
const CASES = args.quick ? ALL.filter(([w, , r]) => (w === 1400 && r === 2) || w === 390) : ALL;

const browser = await launch();
let failed = 0;
for (const [width, height, ratio, wanted] of CASES) {
  const label = `${width}x${height}@${ratio}x`;
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: ratio });
  const page = await context.newPage();
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  let where = null;
  for (let n = 0; n < 600; n++) {
    where = await page.evaluate(() => window.brickworksControls || null);
    if (where && where.save) break;
    await page.waitForTimeout(500);
  }
  await page.waitForTimeout(3000);
  where = await page.evaluate(() => window.brickworksControls || {});
  const outside = [];
  for (const name of wanted) {
    const at = where[name];
    if (!at) {
      // Clear is published from 2026-10-10; a build before that says nothing of it.
      if (name === "clear" && !("clear" in where)) continue;
      outside.push(`${name} not shown`);
      continue;
    }
    if (at.x < 0 || at.x > width || at.y < 0 || at.y > height) outside.push(`${name} at ${at.x},${at.y}`);
  }
  // A large canvas drawn in software can take longer than a screenshot's
  // default wait; the picture is evidence, not the check.
  await page.screenshot({ path: `${out}/${label}.png`, timeout: 120000 }).catch(() => {});
  const ok = outside.length === 0;
  if (!ok) failed++;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${label}: ${ok ? `every control on the page (${wanted.join(", ")})` : outside.join("; ")}`);
  await context.close();
}
await browser.close();
console.log(failed ? `${failed} failed` : "the app fits the page at every size and density");
process.exit(failed ? 1 : 0);
