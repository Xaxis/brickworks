// packaged_facts.mjs OUT ROUTE... : whether each packaged function (OUT/api/<route>.func, as
// tools/package_api.sh packages it) reads the catalogue's facts from its own folder: its own
// _owned.js imported, as the function imports it, and asked what the app's Collection.key_of
// would say. A function without them counts every part by the number it was written with
// (lb2check M2: /api/collection's 4073 was not 6141 in production). Exits 1 naming each one.
import { existsSync } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [out, ...routes] = process.argv.slice(2);
if (!out || !routes.length) {
  console.error("packaged_facts: name the folder and the routes packaged in it");
  process.exit(2);
}
const wrong = [];
let said = "";
for (const route of routes) {
  const fn = path.resolve(out, "api", `${route}.func`);
  const owned = path.join(fn, "_owned.js");
  if (!existsSync(owned)) {
    wrong.push(`${route}: no _owned.js beside it`);
    continue;
  }
  const { ownedFacts, plainColour, resolvePart } = await import(pathToFileURL(owned).href);
  const facts = ownedFacts();
  const moved = [...facts.moved].find(([, to]) => facts.known?.has(to));
  const plain = [...facts.plain][0];
  if (!facts.known || facts.known.size < 10000 || !moved || !plain) {
    wrong.push(`${route}: known ${facts.known ? facts.known.size : "none"}, moved ${facts.moved.size}, `
      + `plain ${facts.plain.size}${existsSync(path.join(fn, "_part_facts.json")) ? "" : " (no _part_facts.json)"}`);
    continue;
  }
  if (resolvePart(moved[0]) === moved[0] || plainColour(plain[0]) !== plain[1]) {
    wrong.push(`${route}: resolvePart(${moved[0]}) = ${resolvePart(moved[0])}, plainColour(${plain[0]}) = ${plainColour(plain[0])}`);
    continue;
  }
  said = `${facts.known.size} parts, ${facts.moved.size} moved (${moved[0]} is ${resolvePart(moved[0])}), `
    + `${facts.plain.size} plain colours (${plain[0]} is ${plain[1]})`;
}
if (wrong.length) {
  for (const one of wrong) console.log(`packaged facts: FAILED ${one}`);
  process.exit(1);
}
console.log(`packaged facts: ${routes.length} functions each read ${said}`);
