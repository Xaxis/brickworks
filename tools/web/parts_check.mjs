// A model page's parts list against the app's (site278): for each file the
// app's parts list was taken of (src/dev/parts_page_probe.gd writes them),
// the page's own list of the same file (api/_parts.js), lot by lot, and the
// two exports word for word. And each lot's picture (site304): the page
// draws it (web/part-pictures.js) from the geometry it names (mesh), which
// must be the app's own for the part, here in assets/generated/parts, read
// by the page's reader (web/lbm.js) into triangles, with a surface in the
// lot's colour (16) or, a sticker's, its own; a part the file carries has
// none and keeps its swatch.
//
//   node tools/web/parts_check.mjs --app=APP.json
//
// APP.json: {path: {pieces, lots: [[part, colour, count, name, bricklink id,
// bricklink colour, rebrickable id, rebrickable colour, element, custom,
// mesh]], xml, csv}}. Prints the two totals and lots side by side, every lot
// that differs, and exits 1 when any does.
import { existsSync, readFileSync } from "node:fs";
import { inventoryOf, paletteOf, partsTable, rebrickableCsv, wantedList } from "../../api/_parts.js";
import { INHERIT, parseLbm } from "../../web/lbm.js";

const appFile = (process.argv.find((a) => a.startsWith("--app=")) || "").slice(6);
if (!appFile) {
  console.error("parts_check: name the app's lists, --app=APP.json");
  process.exit(2);
}
const app = JSON.parse(readFileSync(appFile, "utf8"));
const table = partsTable();
if (!table) {
  console.error("parts_check: no parts table (assets/generated/catalogue.json)");
  process.exit(2);
}
const palette = paletteOf(table);
let failed = 0;
console.log("model                 app pieces  page pieces   app lots  page lots   differing");
for (const [path, theirs] of Object.entries(app)) {
  const page = inventoryOf(readFileSync(path, "utf8"), table);
  const mine = page.lots.map((lot) => [lot.part, lot.colour, lot.count, lot.name, lot.bricklink,
    lot.bricklink_colour, lot.rebrickable, lot.rebrickable_colour, lot.element, lot.custom]);
  const differing = [];
  for (let at = 0; at < Math.max(mine.length, theirs.lots.length); at += 1) {
    const a = JSON.stringify(theirs.lots[at]?.slice(0, 10) ?? null);
    const b = JSON.stringify(mine[at] ?? null);
    if (a !== b) differing.push(`    lot ${at + 1}: app ${a}\n            page ${b}`);
  }
  const xml = wantedList(page).text === theirs.xml;
  const csv = rebrickableCsv(page).text === theirs.csv;
  // The pictures: each lot the app has geometry for, drawn from the same.
  const pictures = [];
  let drawable = 0;
  page.lots.forEach((lot, at) => {
    const app = theirs.lots[at]?.[10] ?? "";
    if (lot.custom) {
      if (lot.mesh) pictures.push(`    lot ${at + 1} ${lot.part}: a part the file carries, named geometry ${lot.mesh}`);
      return;
    }
    if (lot.mesh !== app) return pictures.push(`    lot ${at + 1} ${lot.part}: the page draws ${lot.mesh || "nothing"}, the app ${app || "nothing"}`);
    const file = new URL(`../../assets/generated/parts/${lot.mesh}.lbm`, import.meta.url);
    if (!existsSync(file)) return pictures.push(`    lot ${at + 1} ${lot.part}: no geometry ${lot.mesh}.lbm`);
    let part;
    try {
      const bytes = readFileSync(file);
      part = parseLbm(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
    } catch (trouble) {
      return pictures.push(`    lot ${at + 1} ${lot.part}: ${lot.mesh}.lbm does not read: ${trouble.message}`);
    }
    const triangles = part.surfaces.reduce((n, one) => n + one.index.length / 3, 0);
    const inks = new Set(part.surfaces.filter((one) => one.index.length).map((one) => one.colour));
    const coloured = inks.has(INHERIT) || [...inks].every((code) => palette[code]);
    if (!triangles || !coloured) {
      return pictures.push(`    lot ${at + 1} ${lot.part}: ${triangles} triangles, surfaces in ${[...inks].join(", ")}`);
    }
    drawable += 1;
  });
  const name = path.split("/").pop();
  console.log(`${name.padEnd(20)} ${String(theirs.pieces).padStart(11)} ${String(page.pieces).padStart(12)} `
    + `${String(theirs.lots.length).padStart(10)} ${String(page.lots.length).padStart(10)} ${String(differing.length).padStart(11)}`
    + `   wanted list ${xml ? "same" : "DIFFERS"}, Rebrickable CSV ${csv ? "same" : "DIFFERS"}, `
    + `${drawable} pictures from the app's geometry, ${page.lots.filter((lot) => lot.custom).length} swatches${pictures.length ? `, ${pictures.length} WRONG` : ""}`);
  for (const line of [...differing, ...pictures].slice(0, 8)) console.log(line);
  if (differing.length || pictures.length || theirs.pieces !== page.pieces || !xml || !csv) failed += 1;
}
console.log(failed ? `parts_check: ${failed} FAILED` : "parts_check: every list is the app's, lot by lot");
process.exit(failed ? 1 : 0);
