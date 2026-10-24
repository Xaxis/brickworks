// Print a booklet the way a person would, and photograph its pages.
//
//   node tools/web/booklet_print.mjs BOOKLET.html OUT_DIR [--pages=1,2,5] [--shots-only]
//
// Writes OUT_DIR/a4.pdf and OUT_DIR/letter.pdf (printed by Chromium with
// the booklet's own print styles, landscape) and OUT_DIR/page-N.png for
// the pages asked for (all of them by default, up to 40), drawn on screen
// at the size the page is printed at. Then checks what printing must not
// lose: the page count is the booklet's, every page fits its sheet, and
// every picture decoded. --shots-only photographs the pages and prints
// nothing: the browser's own pictures of the pages, to hold the PDF that
// Brickworks writes itself against (tools/booklet_pdf_check.py --shots).
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { pathToFileURL } from "node:url";
import path from "node:path";

const [, , input, outDir, ...rest] = process.argv;
if (!input || !outDir) {
  console.error("usage: node tools/web/booklet_print.mjs BOOKLET.html OUT_DIR [--pages=1,2]");
  process.exit(2);
}
mkdirSync(outDir, { recursive: true });
const wanted = (rest.find((a) => a.startsWith("--pages=")) || "").slice(8)
  .split(",").filter(Boolean).map(Number);

const browser = await launch();
let failed = 0;
try {
  const page = await browser.newPage({ viewport: { width: 1100, height: 900 } });
  await page.goto(pathToFileURL(path.resolve(input)).href, { waitUntil: "load" });
  const facts = await page.evaluate(() => {
    const pages = [...document.querySelectorAll("section.page")];
    const images = [...document.images];
    return {
      pages: pages.length,
      broken: images.filter((i) => !i.complete || i.naturalWidth === 0).length,
      images: images.length,
    };
  });
  console.log(`${facts.pages} pages, ${facts.images} pictures, ${facts.broken} broken`);
  if (facts.broken > 0) failed++;

  for (const [name, format] of rest.includes("--shots-only") ? [] : [["a4", "A4"], ["letter", "Letter"]]) {
    const file = path.join(outDir, `${name}.pdf`);
    await page.emulateMedia({ media: "print" });
    await page.pdf({ path: file, format, landscape: true, printBackground: true,
      preferCSSPageSize: true });
    await page.emulateMedia({ media: "screen" });
    console.log(`wrote ${file}`);
  }

  // Each page on screen, at print size (3.78 px a millimetre), without
  // the toolbar that sticks to the top of the window.
  await page.setViewportSize({ width: 1060, height: 800 });
  await page.addStyleTag({ content: ".bar { display: none !important; }" });
  const count = facts.pages;
  const list = wanted.length ? wanted : Array.from({ length: Math.min(count, 40) }, (_, n) => n + 1);
  for (const n of list) {
    const section = page.locator(`section.page >> nth=${n - 1}`);
    if ((await section.count()) === 0) continue;
    await section.screenshot({ path: path.join(outDir, `page-${n}.png`) });
  }
  console.log(`photographed ${list.length} pages`);
} finally {
  await browser.close();
}
process.exit(failed ? 1 : 0);
