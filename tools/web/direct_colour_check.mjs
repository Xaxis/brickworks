// What the site makes of a model's direct colours (0x2RRGGBB), for
// src/dev/direct_colour_probe.gd to hold against the app's: the colour each
// direct code stands in as on a shop's list (api/_parts.js standIn, the app's
// PartLibrary.catalogue_nearest), for the codes given and for a grid of
// colours across the cube; and the file's parts list as the model page has
// it (inventoryOf), with its BrickLink wanted list and Rebrickable CSV.
//
//   node tools/web/direct_colour_check.mjs FILE.ldr
//
// Prints one JSON object: {grid: {code: stand-in}, lots: [{part, colour,
// colour_name, hex, element, stand_in}], wanted: {text, left_out,
// stand_ins}, rebrickable: {text, left_out, stand_ins}}. Exits 2 when there
// is no parts table here.
import { readFileSync } from "node:fs";
import { inventoryOf, partsTable, rebrickableCsv, standIn, wantedList } from "../../api/_parts.js";

const file = process.argv[2];
if (!file || !partsTable()) {
  console.error("direct_colour_check: name a model file, in a checkout with assets/generated");
  process.exit(2);
}
const grid = {};
// Eight steps a channel, ends included, and the file's own three.
const steps = [0, 36, 73, 109, 146, 182, 219, 255];
for (const r of steps) for (const g of steps) for (const b of steps) {
  const code = 0x2000000 | (r << 16) | (g << 8) | b;
  grid[code] = standIn(code);
}
const parts = inventoryOf(readFileSync(file, "utf8"));
for (const lot of parts.lots) if (lot.colour >= 0x2000000) grid[lot.colour] = standIn(lot.colour);
const wanted = wantedList(parts);
const rebrickable = rebrickableCsv(parts);
console.log(JSON.stringify({
  grid,
  lots: parts.lots.map((lot) => ({ part: lot.part, colour: lot.colour, colour_name: lot.colour_name, hex: lot.hex,
    element: lot.element, stand_in: lot.stand_in })),
  wanted: { text: wanted.text, left_out: wanted.left_out, stand_ins: wanted.stand_ins },
  rebrickable: { text: rebrickable.text, left_out: rebrickable.left_out, stand_ins: rebrickable.stand_ins },
}));
