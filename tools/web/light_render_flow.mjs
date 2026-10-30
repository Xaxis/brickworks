// File, Render… lit by a photographed place in a real browser: the light
// the web build does not carry in the pack its start waits for, fetched the
// first time a picture is lit by it (WebPacks, tools/web/pck_split.py).
//
//   python3 tools/web/serve.py build/web 9463 --parts assets/generated/parts --delay 0 --compressed --cached &
//   node tools/web/light_render_flow.mjs --url=http://127.0.0.1:9463/index.html --out=DIR [--against=OTHER.png]
//   node tools/web/light_render_flow.mjs --url=https://<preview>.vercel.app/app/index.html --bypass=$VERCEL_BYPASS --out=DIR
//
// Opens the render dialog on the example car, chooses Softbox studio
// (photographed), Quick and 720p, renders, and keeps the PNG. Fails if no
// PNG of 1280x720 comes, if a build that keeps the light apart did not
// fetch and write it (window.brickworksPacks.hdri) or the dialog never said
// it was fetching it, or if a script error reaches the console. With
// --against, the picture must be the one another build drew of the same
// (a build whose pack was whole, before the light was kept apart): no
// channel of any pixel more than --tolerance apart (default 24 of 255) and
// all of them within 1 of 255 on average. Leaves OUT/light.png, the
// dialog's screenshots and OUT/light.json.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:9463/index.html";
// A preview is behind Vercel's protection: the bypass, once, as a cookie.
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = path.resolve(args.out || "shots/light_render_web");
const tolerance = Number(args.tolerance || 24);
mkdirSync(out, { recursive: true });

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|ERROR:/.test(m.text())) errors.push(m.text().slice(0, 200));
});
let failed = 0;
const facts = {};
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};

async function where(name, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = await page.evaluate((k) => (window.brickworksControls || {})[k], name);
    if (at) return at;
    await page.waitForTimeout(500);
  }
  return null;
}
async function press(name) {
  const at = await where(name);
  if (!at) throw new Error(`no ${name} on the page`);
  await page.mouse.click(at.x, at.y);
  // The app tells the page where its controls are twice a second.
  await page.waitForTimeout(1100);
}
const state = () => page.evaluate(() => window.brickworksRender || {});
const hdri = () => page.evaluate(() => (window.brickworksPacks || {}).hdri || null);

// Two PNGs compared in a page of their own: the largest difference of any
// channel of any pixel, and the mean, out of 255.
async function compare(one, other) {
  const blank = await context.newPage();
  const b64 = (file) => `data:image/png;base64,${readFileSync(file).toString("base64")}`;
  const result = await blank.evaluate(async ([a, b]) => {
    const pixels = async (src) => {
      const image = new Image();
      image.src = src;
      await image.decode();
      const canvas = document.createElement("canvas");
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      const drawn = canvas.getContext("2d");
      drawn.drawImage(image, 0, 0);
      return { w: canvas.width, h: canvas.height, data: drawn.getImageData(0, 0, canvas.width, canvas.height).data };
    };
    const x = await pixels(a);
    const y = await pixels(b);
    if (x.w !== y.w || x.h !== y.h) return { size: false };
    let most = 0;
    let sum = 0;
    for (let n = 0; n < x.data.length; n++) {
      const d = Math.abs(x.data[n] - y.data[n]);
      most = Math.max(most, d);
      sum += d;
    }
    return { size: true, most, mean: sum / x.data.length };
  }, [b64(one), b64(other)]);
  await blank.close();
  return result;
}

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  const until = Date.now() + 300000;
  while (!(await page.evaluate(() => Boolean((window.brickworksControls || {}).tool_render)))) {
    if (Date.now() > until) throw new Error("the toolbar's Render never appeared");
    await page.waitForTimeout(1000);
  }
  // The example car's parts arrive over the network after the toolbar does.
  await page.waitForTimeout(Number(args.load || 20000));
  facts.light_before = await hdri();

  await press("tool_render");
  check("the toolbar's Render opens the dialog", Boolean(await where("render_picture", 30)));
  await press("render_quick");
  await press("render_size_720p");
  // Every state the dialog tells the page from here on, kept as it is told:
  // the light is fetched for the draft drawn once it is chosen, in a tenth
  // of a second from a local export, between two looks at the page.
  await page.evaluate(() => {
    let told = window.brickworksRender;
    const words = window.__lightWords = [];
    Object.defineProperty(window, "brickworksRender", {
      configurable: true,
      get() { return told; },
      set(value) { told = value; if (value && value.words) words.push(value.words); },
    });
  });
  // The light: its list opened, and the first photographed place, Softbox
  // studio, clicked in it. The list opens under the button, a row each 25
  // px at this size, the window's own light first (0_light_list.png); the
  // keys did not move in it.
  const light = await where("render_light");
  await press("render_light");
  await page.screenshot({ path: path.join(out, "0_light_list.png"), timeout: 120000 });
  await page.mouse.click(light.x, light.y + 27 + 25);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(out, "1_light_chosen.png"), timeout: 120000 });

  // Rendered, the dialog's words watched for what it waited on, with those
  // told since the light was chosen.
  const said = new Set();
  const download = page.waitForEvent("download", { timeout: 10 * 60000 }).catch(() => null);
  const started = Date.now();
  await press("render_picture");
  let seen = null;
  let began = false;
  for (let n = 0; n < 1200; n++) {
    seen = await state();
    if (seen.words) said.add(seen.words);
    began = began || seen.working === "picture";
    if (!began && n > 120) break;
    if (began && seen.working === "") break;
    await page.waitForTimeout(250);
  }
  const got = await download;
  facts.seconds = Math.round((Date.now() - started) / 1000);
  for (const words of await page.evaluate(() => window.__lightWords || [])) said.add(words);
  facts.said = [...said];
  facts.light_after = await hdri();
  await page.screenshot({ path: path.join(out, "2_rendered.png"), timeout: 120000 });
  let file = null;
  if (got) {
    file = path.join(out, "light.png");
    await got.saveAs(file);
  }
  const bytes = file ? readFileSync(file) : null;
  const size = bytes && bytes.slice(1, 4).toString() === "PNG"
    ? { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) } : null;
  check(`Quick, lit by Softbox studio, downloads a PNG at 1280x720 (${size ? `${size.width}x${size.height}` : "none"}, ${facts.seconds} s)`,
    size && size.width === 1280 && size.height === 720);

  // A build that keeps the light apart fetched it for this, and said so.
  const apart = await page.evaluate(() => Boolean(window.brickworksPacks));
  facts.apart = apart;
  if (apart) {
    const light = facts.light_after || {};
    check(`the light was not fetched before it was wanted (${JSON.stringify(facts.light_before)})`, !facts.light_before);
    check(`then fetched and written (${light.files || 0} files, asked ${Math.round(light.asked || 0)} ms, written ${Math.round(light.written || 0)} ms)`,
      light.written > 0 && light.files > 0 && !light.gave_up);
    check(`the dialog said it was fetching it (${facts.said.join(" | ")})`,
      facts.said.some((words) => /photographed light/.test(words)));
  } else {
    console.log("  (a build whose pack is whole: the light was in it)");
  }
  if (args.against && file) {
    const diff = await compare(file, path.resolve(args.against));
    facts.against = diff;
    check(`the same picture as ${args.against} (largest difference ${diff.most}, mean ${diff.mean !== undefined ? diff.mean.toFixed(3) : "-"} of 255)`,
      diff.size && diff.most <= tolerance && diff.mean <= 1);
  }
  await press("render_close");
} catch (error) {
  check(String(error), false);
} finally {
  check(`no script errors (${errors.length})`, errors.length === 0);
  for (const e of errors.slice(0, 5)) console.log(`      ${e}`);
  writeFileSync(path.join(out, "light.json"), JSON.stringify(facts, null, 1));
  await browser.close();
}
console.log(failed ? `light render: ${failed} FAILED` : "light render: all passed");
process.exit(failed ? 1 : 0);
