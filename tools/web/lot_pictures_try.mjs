// A model's lot pictures (api/_lot_pictures.js) drawn here, from this
// checkout's parts (assets/generated/parts), as the server draws them for
// /m/X/v/N/parts.png: to look at, and for src/dev/lot_pictures_test.gd.
//
//   node tools/web/lot_pictures_try.mjs MODEL.ldr OUT.png
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { inventoryOf, paletteOf, partsTable } from "../../api/_parts.js";
import { indexOf, lotSheet, withGeometry } from "../../api/_lot_pictures.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const [file, out] = process.argv.slice(2);
if (!file || !out) {
  console.error("lot_pictures_try: MODEL.ldr OUT.png");
  process.exit(2);
}
const table = partsTable();
const began = performance.now();
const { lots } = inventoryOf(readFileSync(file, "utf8"), table);
const given = await withGeometry(lots, async (mesh) => {
  const at = join(ROOT, "assets/generated/parts", `${mesh}.lbm`);
  return existsSync(at) ? readFileSync(at) : null;
});
const { png, drawn } = lotSheet(given, paletteOf(table), "local");
writeFileSync(out, png);
console.log(`lot_pictures_try: ${lots.length} lots, ${drawn} drawn, ${indexOf(png).lots.length} in the index, `
  + `${(png.length / 1024).toFixed(0)} KB, ${Math.round(performance.now() - began)} ms`);
