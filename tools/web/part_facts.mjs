// Which parts are Technic and which make a model move, for /api/share to
// count when a model is published (api/_directory.js partFacts), written
// from the catalogue the app is built with; and, for Build with what I own
// (api/_owned.js ownedFacts), every part number the catalogue has, the ones
// LDraw moved to another, and each colour's plain code, from the colours.
//
//   node tools/web/part_facts.mjs OUT.json [--catalogue=assets/generated/catalogue.json]
//       [--colours=assets/generated/colors.json] [--parts=PARTS.json]
//
// --parts writes a shared model's parts list's table too (api/_parts.js
// deriveTable, with assets/generated/elements.json beside the catalogue):
// every part's name, kind and shop numbers and every colour's, which
// tools/deploy.sh puts beside the share function as _parts_table.json.
//
// tools/deploy.sh writes it beside the share function as _part_facts.json:
// the catalogue is 15 MB and a function reads this in a millisecond. In a
// checkout the function works the same facts out of the catalogue itself,
// with the same derivePartFacts, so the two cannot say different things.
import { readFileSync, writeFileSync } from "node:fs";
import { derivePartFacts } from "../../api/_directory.js";
import { deriveOwnedFacts } from "../../api/_owned.js";
import { deriveTable } from "../../api/_parts.js";
import { existsSync } from "node:fs";
import path from "node:path";

const out = process.argv.slice(2).find((a) => !a.startsWith("--"));
const catalogue = (process.argv.find((a) => a.startsWith("--catalogue=")) || "--catalogue=assets/generated/catalogue.json").slice(12);
if (!out) {
  console.error("part_facts: name the file to write");
  process.exit(2);
}
const colours = (process.argv.find((a) => a.startsWith("--colours=")) || "--colours=assets/generated/colors.json").slice(10);
const read = JSON.parse(readFileSync(catalogue, "utf8"));
const facts = derivePartFacts(read);
const owned = deriveOwnedFacts(read, JSON.parse(readFileSync(colours, "utf8")));
if (facts.technic.length < 500 || facts.mechanism.length < 50) {
  console.error(`part_facts: the catalogue gave ${facts.technic.length} Technic parts and `
    + `${facts.mechanism.length} that move, which is not the catalogue`);
  process.exit(1);
}
if (owned.known.length < 10000 || Object.keys(owned.plain).length < 1) {
  console.error(`part_facts: the catalogue gave ${owned.known.length} parts and the colours `
    + `${Object.keys(owned.plain).length} plain codes, which is not them`);
  process.exit(1);
}
writeFileSync(out, JSON.stringify({ ...facts, ...owned }));
console.log(`part facts: ${facts.technic.length} Technic parts, ${facts.mechanism.length} that make a model move, `
  + `${owned.known.length} parts, ${Object.keys(owned.moved).length} moved, ${Object.keys(owned.plain).length} plain colours`);
const partsOut = (process.argv.find((a) => a.startsWith("--parts=")) || "").slice(8);
if (partsOut) {
  const elements = path.join(path.dirname(catalogue), "elements.json");
  const table = deriveTable(read, JSON.parse(readFileSync(colours, "utf8")),
    existsSync(elements) ? JSON.parse(readFileSync(elements, "utf8")) : {});
  if (Object.keys(table.parts).length < 10000 || !(table.flex.ribbed_hose || []).length) {
    console.error(`part_facts: the parts table has ${Object.keys(table.parts).length} parts, which is not the catalogue`);
    process.exit(1);
  }
  const text = JSON.stringify(table);
  writeFileSync(partsOut, text);
  console.log(`parts table: ${Object.keys(table.parts).length} parts, ${Object.keys(table.colours).length} colours, `
    + `${Object.keys(table.elements).length} elements, ${(text.length / 1048576).toFixed(2)} MB`);
}
