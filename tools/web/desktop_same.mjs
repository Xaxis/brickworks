// The desktop with a mouse, the same to the pixel on two builds: a change
// made for touch (the phone's layout, a tablet's) must leave it as it was.
// Each build is opened at 1280 x 800, one device pixel to the point, no
// touch, and shot as it is ready, with the parts searched for "3001", and
// with the File menu open; the base is shot twice, so a difference that is
// only the measure's own shows as such. Fails on any pixel different.
//
//   python3 tools/web/serve.py <base build> 8810 --parts assets/generated/parts --delay 0 &
//   python3 tools/web/serve.py build/web 8811 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/desktop_same.mjs --base=http://127.0.0.1:8810/ --url=http://127.0.0.1:8811/ --out=DIR
//
// Local only (tools/release/preview_checks.sh): it needs a build of the
// base served beside the one being checked.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.base || "");
const url = String(args.url || "");
const out = String(args.out || "shots/desktop_same");
const [width, height] = String(args.size || "1280x800").split("x").map(Number);
if (!base || !url) {
  console.log("usage: desktop_same.mjs --base=URL --url=URL [--out=DIR] [--size=1280x800]");
  process.exit(2);
}
mkdirSync(out, { recursive: true });

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};

const STEPS = ["ready", "searched", "file_menu"];
const browser = await launch();

// Every step's picture of one build, by name.
async function shoot(at, label) {
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
  const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
  const where = async (name, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const found = (await controls())[name];
      if (found) return found;
      await page.waitForTimeout(250);
    }
    return null;
  };
  // Still: the same picture twice running, a second apart.
  const settled = async (name) => {
    let last = null;
    for (let n = 0; n < 20; n++) {
      await page.waitForTimeout(1000);
      const now = await page.screenshot();
      if (last && now.equals(last)) break;
      last = now;
    }
    const path = `${out}/${label}_${name}.png`;
    await page.screenshot({ path });
    return path;
  };
  const shots = {};
  await page.goto(at, { waitUntil: "domcontentloaded", timeout: 180000 });
  for (let n = 0; n < 1200; n++) {
    const s = await state();
    if ((s.awaited || 0) === 0 && s.mode) break;
    await page.waitForTimeout(250);
  }
  await where("part search", 120);
  shots.ready = await settled("ready");
  const search = await where("part search");
  if (search) {
    await page.mouse.click(search.x, search.y);
    await page.keyboard.type("3001", { delay: 40 });
    await where("first part", 20);
    await page.mouse.move(width / 2, height / 2);
  }
  shots.searched = await settled("searched");
  const file = await where("menu_file", 10);
  if (file) await page.mouse.click(file.x, file.y);
  shots.file_menu = await settled("file_menu");
  await context.close();
  return shots;
}

// How many pixels two pictures differ in, counted in a page.
async function differ(a, b) {
  const page = await browser.newPage();
  const count = await page.evaluate(async ([one, two]) => {
    const load = (src) => new Promise((done) => { const i = new Image(); i.onload = () => done(i); i.src = src; });
    const [x, y] = await Promise.all([load(one), load(two)]);
    if (x.width !== y.width || x.height !== y.height) return -1;
    const read = (img) => {
      const c = document.createElement("canvas");
      c.width = img.width; c.height = img.height;
      const g = c.getContext("2d");
      g.drawImage(img, 0, 0);
      return g.getImageData(0, 0, img.width, img.height).data;
    };
    const p = read(x); const q = read(y);
    let n = 0;
    for (let i = 0; i < p.length; i += 4) {
      if (p[i] !== q[i] || p[i + 1] !== q[i + 1] || p[i + 2] !== q[i + 2] || p[i + 3] !== q[i + 3]) n += 1;
    }
    return n;
  }, [a, b].map((path) => `data:image/png;base64,${readFileSync(path).toString("base64")}`));
  await page.close();
  return count;
}

try {
  console.log(`the desktop at ${width} x ${height}, by a mouse`);
  const first = await shoot(base, "base");
  const again = await shoot(base, "base_again");
  const mine = await shoot(url, "branch");
  for (const step of STEPS) {
    const noise = await differ(first[step], again[step]);
    const changed = await differ(first[step], mine[step]);
    check(`${step}: ${changed} pixels different from the base (the base against itself: ${noise})`,
      changed === 0);
  }
} finally {
  await browser.close();
}
console.log(failed ? `\n${failed} checks failed` : "\nthe desktop is the same to the pixel");
process.exit(failed ? 1 : 0);
