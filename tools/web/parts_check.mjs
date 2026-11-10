// A model page's parts list against the app's (site278): for each file the
// app's parts list was taken of (src/dev/parts_page_probe.gd writes them),
// the page's own list of the same file (api/_parts.js), lot by lot, and the
// three exports word for word: BrickLink's, Rebrickable's, and each file of
// LEGO's Pick a Brick list with what it leaves off (sitepickabrick). And each lot's picture (site304): the page
// draws it (web/part-pictures.js) from the geometry it names (mesh), which
// must be the app's own for the part, here in assets/generated/parts, read
// by the page's reader (web/lbm.js) into triangles, with a surface in the
// lot's colour (16) or, a sticker's, its own; a part the file carries has
// none and keeps its swatch. And with --names, each lot's names in each
// language as the page says them (api/_parts.js namesOf, from the names in
// DIR, part_names_<code>.json as src/dev/write_part_names.gd writes them)
// against the app's.
//
//   node tools/web/parts_check.mjs --app=APP.json [--names=DIR]
//
// APP.json: {path: {pieces, lots: [[part, colour, count, name, bricklink id,
// bricklink colour, rebrickable id, rebrickable colour, element, custom,
// mesh]], xml, csv, pab: {files, lines, pieces, left_out, left_out_pieces,
// over, stand_ins} (ShopLists.pick_a_brick), <code>: [[its tile's name in
// that language, the English one the tile falls back to, its colour's and its
// kind's, "" for none]]}}.
// Prints the two totals and lots side by side, every lot that differs, and
// exits 1 when any does.
import { existsSync, readFileSync } from "node:fs";
import { inventoryOf, namesOf, paletteOf, partsTable, pickABrick, rebrickableCsv, useNames, wantedList } from "../../api/_parts.js";
import { INHERIT, parseLbm } from "../../web/lbm.js";

const appFile = (process.argv.find((a) => a.startsWith("--app=")) || "").slice(6);
if (!appFile) {
  console.error("parts_check: name the app's lists, --app=APP.json");
  process.exit(2);
}
const app = JSON.parse(readFileSync(appFile, "utf8"));
const namesDir = (process.argv.find((a) => a.startsWith("--names=")) || "").slice(8);
const languages = {};
for (const code of namesDir ? ["de", "fr", "es"] : []) {
  languages[code] = useNames(code, JSON.parse(readFileSync(`${namesDir}/part_names_${code}.json`, "utf8")));
}
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
  // LEGO's Pick a Brick list: each file byte for byte, and what it leaves
  // off (lots with no element number, their pieces) and past 999, the app's.
  const made = pickABrick(page);
  const pab = { files: made.files, lines: made.lines, pieces: made.pieces, left_out: made.missing.length,
    left_out_pieces: made.missing.reduce((n, lot) => n + lot.count, 0), over: made.over, stand_ins: made.stand_ins };
  const pabDiffers = Object.keys(pab).filter((key) => JSON.stringify(pab[key]) !== JSON.stringify(theirs.pab?.[key]));
  if (pabDiffers.includes("files")) {
    const app = theirs.pab?.files || [];
    for (let n = 0; n < Math.max(app.length, pab.files.length); n += 1) {
      const a = (app[n] ?? "").split("\r\n");
      const b = (pab.files[n] ?? "").split("\r\n");
      const at = a.findIndex((line, i) => line !== b[i]);
      if (at >= 0 || a.length !== b.length) {
        differing.push(`    Pick a Brick file ${n + 1}, line ${at >= 0 ? at + 1 : Math.min(a.length, b.length) + 1}: app ${JSON.stringify(a[at >= 0 ? at : b.length] ?? null)}\n            page ${JSON.stringify(b[at >= 0 ? at : a.length] ?? null)}`);
        break;
      }
    }
  }
  for (const key of pabDiffers.filter((one) => one !== "files")) {
    differing.push(`    Pick a Brick ${key}: app ${JSON.stringify(theirs.pab?.[key] ?? null)}, page ${JSON.stringify(pab[key])}`);
  }
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
  // Each lot's names as the page says them in each language, the app's: a
  // part the page names in it, as the app's tile does; one it leaves in
  // English, one the tile leaves so too. Except a part the file carries,
  // which the page names as its maker did (the site's names are the
  // catalogue's): its colour and kind only.
  const naming = [];
  let said = 0;
  for (const [code, names] of Object.entries(languages)) {
    page.lots.forEach((lot, at) => {
      const words = namesOf(lot, names);
      const [tile, english, colour, kind] = (app[path][code] || [])[at] || [];
      const mine = [lot.custom ? tile : words.said || english, words.colour_said || "", words.category_said || ""];
      if (JSON.stringify(mine) !== JSON.stringify([tile, colour, kind])) {
        naming.push(`    lot ${at + 1} ${lot.part} in ${code}: app ${JSON.stringify([tile, colour, kind])}\n            page ${JSON.stringify(mine)}`);
      } else if (words.said) said += 1;
    });
  }
  const name = path.split("/").pop();
  console.log(`${name.padEnd(20)} ${String(theirs.pieces).padStart(11)} ${String(page.pieces).padStart(12)} `
    + `${String(theirs.lots.length).padStart(10)} ${String(page.lots.length).padStart(10)} ${String(differing.length).padStart(11)}`
    + `   wanted list ${xml ? "same" : "DIFFERS"}, Rebrickable CSV ${csv ? "same" : "DIFFERS"}, `
    + `Pick a Brick ${pabDiffers.length ? `DIFFERS (${pabDiffers.join(", ")})` : "same"} (${pab.files.length} `
    + `${pab.files.length === 1 ? "file" : "files"}, ${pab.lines} lines, ${pab.pieces} pieces; ${pab.left_out} lots, `
    + `${pab.left_out_pieces} pieces with no element left off; ${Object.keys(pab.over).length} past 999), `
    + `${drawable} pictures from the app's geometry, ${page.lots.filter((lot) => lot.custom).length} swatches${pictures.length ? `, ${pictures.length} WRONG` : ""}`
    + (namesDir ? `, ${said} names said as the app says them in ${Object.keys(languages).join("/")}${naming.length ? `, ${naming.length} DIFFER` : ""}` : ""));
  for (const line of [...differing, ...pictures, ...naming].slice(0, 8)) console.log(line);
  if (differing.length || pictures.length || naming.length || theirs.pieces !== page.pieces || !xml || !csv
    || pabDiffers.length) failed += 1;
}
console.log(failed ? `parts_check: ${failed} FAILED` : "parts_check: every list is the app's, lot by lot");
process.exit(failed ? 1 : 0);
