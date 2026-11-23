// The weekly quick build's pictures for the docs' world (tools/web/docs_world.mjs):
// a template and the house's two Habitat entries, drawn as the hourly run
// draws them (api/_flatlay.js drawModel), as PNGs into OUT, for
// docs-site/pictures/files/ (made WebP there at the cards' 480x360).
//
//   node tools/prompt_pictures.mjs OUT
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { drawModel, pngOf } from "../api/_flatlay.js";
import { paletteOf, partsTable, placedOf } from "../api/_parts.js";
import { houseEntry, templateText } from "../api/_prompts.js";

const out = process.argv[2];
if (!out) {
  console.error("usage: node tools/prompt_pictures.mjs OUT");
  process.exit(2);
}
mkdirSync(out, { recursive: true });
const table = partsTable();
const palette = paletteOf(table);
const parts = new URL("../assets/generated/parts/", import.meta.url);
const placed = (text) => placedOf(text, table).map((one) => {
  const at = new URL(`${one.mesh}.lbm`, parts);
  const bytes = existsSync(at) ? readFileSync(at) : null;
  return { ...one, bytes: bytes ? bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length) : null };
});
const draw = (name, text) => {
  writeFileSync(`${out}/${name}.png`, pngOf(drawModel(placed(text), palette, { width: 960, height: 720 })));
  console.log(`${out}/${name}.png`);
};
draw("DocsTmpl01", templateText({ seed: "habitat", title: "Habitat", brief: "A home for one minifigure." }));
draw("DocsHab001", houseEntry("habitat", 0).text);
draw("DocsHab002", houseEntry("habitat", 1).text);
