// Every set's parts by part and colour, for /api/share to count what a model
// is an alternate build of as it is published (api/_alts.js, altbuilds):
// written from the sets' shards (tools/collection_data.py) and the set
// catalogue (tools/set_catalog.py: which numbers are not sets), in the
// spelling the catalogue's facts give (api/_owned.js), which tools/deploy.sh
// puts beside the share function as _alt_index.bin.
//
//   node tools/web/alt_index.mjs OUT.bin [--facts=_part_facts.json]
//
// --facts: the facts the function itself will read (tools/package_api.sh
// passes the ones it packs), so both sides are spelled by one set of facts.
// Fails with fewer than 10,000 sets or 20,000 parts and colours, which is
// not the shards.
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { indexFrom, notSetsOf, packIndex, unpackIndex } from "../../api/_alts.js";
import { ownedFacts, useFacts } from "../../api/_owned.js";

const out = process.argv.slice(2).find((a) => !a.startsWith("--"));
if (!out) {
  console.error("alt_index: name the file to write");
  process.exit(2);
}
const named = (process.argv.find((a) => a.startsWith("--facts=")) || "").slice(8);
const facts = named ? useFacts(JSON.parse(readFileSync(named, "utf8"))) : ownedFacts();
const dir = "assets/generated/sets/";
const shards = readdirSync(dir).filter((name) => /^\d{3}\.json$/.test(name)).sort()
  .map((name) => JSON.parse(readFileSync(`${dir}${name}`, "utf8")));
const skip = notSetsOf(JSON.parse(readFileSync("assets/generated/set_catalog.json", "utf8")));
const began = performance.now();
const index = indexFrom(shards, facts, skip);
const bytes = packIndex(index);
// Read back as the function reads it, so a file that cannot be is never shipped.
const back = unpackIndex(bytes);
if (index.sets.length < 10000 || index.keys.size < 20000 || !back || back.sets.length !== index.sets.length
    || back.keys.size !== index.keys.size) {
  console.error(`alt_index: ${index.sets.length} sets and ${index.keys.size} parts and colours from ${shards.length} shards, `
    + "which is not the shards");
  process.exit(1);
}
writeFileSync(out, bytes);
console.log(`alt_index: ${index.sets.length} sets (${skip.size} database sets left out), ${index.keys.size} parts and colours, `
  + `${(bytes.length / 1048576).toFixed(1)} MB, in ${((performance.now() - began) / 1000).toFixed(1)} s`);
