// Screenshot a page of the site without deploying it first.
//
//   node tools/web/page_shot.mjs --file=web/index.html --out=shots/landing.png
//       [--width=1280 --height=900] [--full] [--scheme=dark|light]
//   node tools/web/page_shot.mjs --file=web/index.html --out=shots/landing.png --full \
//       --sizes=390x844,1280x900,1920x1080
//
// --sizes takes a picture at each size in one run, written beside --out with
// the width in its name (landing-390.png, ...): a phone, a laptop and a big
// screen are where a page is judged, and on a busy machine one run waits for
// its turn once.
//
// The page is served from its own directory over http (static_server.mjs),
// since its stylesheet and pictures are named from the root. For the
// changelog, which tools/site.py fills in, put the site together first:
//   python3 tools/site.py /tmp/site && node tools/web/page_shot.mjs --file=/tmp/site/changelog.html …
import { launch } from "./browser.mjs";
import { basename, dirname, resolve } from "node:path";
import { serveDir } from "./static_server.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));

const file = resolve(args.file);
const sizes = args.sizes
  ? String(args.sizes).split(",").map((s) => s.split("x").map(Number))
  : [[Number(args.width || 1280), Number(args.height || 900)]];
const site = await serveDir(dirname(file));
const browser = await launch({ signedOut: true });  // a page of the site, not the app
for (const [width, height] of sizes) {
  const page = await browser.newPage({ viewport: { width, height }, colorScheme: args.scheme || "dark" });
  await page.goto(`${site.url}/${basename(file)}`, { waitUntil: "load" });
  // Every lazy picture in first: a full-page shot does not scroll, so the
  // ones below the fold would otherwise come out as empty frames.
  await page.evaluate(async () => {
    for (const img of document.querySelectorAll("img[loading=lazy]")) img.loading = "eager";
    await Promise.all([...document.images].map((img) => img.decode().catch(() => {})));
  });
  await page.waitForTimeout(700);
  const out = args.sizes ? String(args.out).replace(/(\.png)?$/, `-${width}.png`) : args.out;
  await page.screenshot({ path: out, fullPage: args.full !== undefined, timeout: 120000 });
  await page.close();
  console.log(`wrote ${out}`);
}
await browser.close();
site.close();
