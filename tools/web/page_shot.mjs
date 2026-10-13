// Screenshot a page of the site without deploying it first.
//
//   node tools/web/page_shot.mjs --file=web/index.html --out=shots/landing.png
//       [--width=1280 --height=900] [--full] [--scheme=dark|light]
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
const site = await serveDir(dirname(file));
const browser = await launch({ signedOut: true });  // a page of the site, not the app
const page = await browser.newPage({
  viewport: { width: Number(args.width || 1280), height: Number(args.height || 900) },
  colorScheme: args.scheme || "dark",
});
await page.goto(`${site.url}/${basename(file)}`, { waitUntil: "load" });
// Every lazy picture in first: a full-page shot does not scroll, so the
// ones below the fold would otherwise come out as empty frames.
await page.evaluate(async () => {
  for (const img of document.querySelectorAll("img[loading=lazy]")) img.loading = "eager";
  await Promise.all([...document.images].map((img) => img.decode().catch(() => {})));
});
await page.waitForTimeout(700);
await page.screenshot({ path: args.out, fullPage: args.full !== undefined });
await browser.close();
site.close();
console.log(`wrote ${args.out}`);
