// Build with what I own, its sums alone, with no database and no browser:
// what a model file needs (api/share.js checkModel), both sides spelled the
// one way (api/_owned.js keyed), which shard a set is in, and a pool made of
// loose parts and sets (poolOf).
//
//   node tools/web/owned_probe.mjs [--sets=DIR]
//
// --sets names the set inventories' folder (tools/collection_data.py's
// shards, assets/generated/sets in a checkout that has them) to check the
// shard sum against a real shard; without it that check is said and skipped.
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkModel } from "../../api/share.js";
import { deriveOwnedFacts, keyed, poolOf, resolvePart, shardOf } from "../../api/_owned.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
};
const sorted = (lots) => lots.map((lot) => (Array.isArray(lot) ? lot : [lot.part, lot.colour, lot.qty]).join(" "))
  .sort().join(", ");

console.log("what a model needs");
// A wall of a sub-model placed twice in red, each with two bricks of its
// colour and a fixed blue one; a sub-model it names and does not carry; a
// plate of its own; and a hose laid as segments, which is not one part.
const mpd = [
  "0 FILE main.ldr", "0 Owned probe", "0 Name: main.ldr",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 wall.ldr",
  "1 4 0 -72 0 1 0 0 0 1 0 0 0 1 wall.ldr",
  "1 14 0 -144 0 1 0 0 0 1 0 0 0 1 3020.dat",
  "1 0x2FF0000 40 -144 0 1 0 0 0 1 0 0 0 1 3024.dat",
  "1 0 0 -160 0 1 0 0 0 1 0 0 0 1 hose.ldr",
  "0 STEP",
  "0 NOFILE",
  "0 FILE wall.ldr", "0 Name: wall.ldr",
  "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "1 16 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "1 1 80 0 0 1 0 0 0 1 0 0 0 1 3003.dat",
  "0 NOFILE",
  "0 FILE hose.ldr", "0 Name: hose.ldr",
  ...Array.from({ length: 6 }, (_, n) => `1 16 0 ${-4 * n} 0 1 0 0 0 1 0 0 0 1 u9053.dat`),
  "0 NOFILE",
].join("\r\n");
const model = checkModel(mpd);
check(`counted ${model.parts} parts`, model.parts === 9);
check(`needs, through the walls in the colour each is placed in: ${sorted(model.needs)}`,
  sorted(model.needs) === sorted([["3001", 4, 4], ["3003", 1, 2], ["3020", 14, 1], ["3024", 0x2FF0000, 1]]));

console.log("spelled the one way");
const facts = { known: new Set(["3001", "3003", "3794a", "3794b", "4592c02", "73983"]), moved: new Map([["4592c02", "73983"]]),
  plain: new Map([[256, 0]]) };
check(`a moved number becomes the one it means today: 4592c02 is ${resolvePart("4592c02", facts)}`,
  resolvePart("4592c02", facts) === "73983");
const both = keyed([["3001", 4, 2], ["3001.dat", 4, 1], { part: "4592c02", colour: 256, qty: 1 },
  ["73983", 0, 1], ["prim/4-4cyli", 16, 3], ["3003", -1, 1], ["3003", 1, 0]], facts);
check(`the same lot once, a moved part and a rubber colour folded in, a primitive and nonsense left out: ${sorted(both)}`,
  sorted(both) === sorted([["3001", 4, 3], ["73983", 0, 2]]));
const moulds = keyed([["3794a", 15, 2], ["3794b", 15, 1], ["3626bp01", 14, 1]], { ...facts,
  known: new Set([...facts.known, "3626bp01"]) });
check(`another moulding stands in, as the app lets it: 3794a and 3794b are one; a print is only itself: ${sorted(moulds)}`,
  sorted(moulds) === sorted([["3794", 15, 3], ["3626bp01", 14, 1]]));
const none = { known: null, moved: new Map(), plain: new Map() };
check("with no catalogue to ask, every part is counted as named",
  sorted(keyed([["prim/4-4cyli", 16, 3]], none)) === "prim/4-4cyli 16 3");

console.log("parts nobody owns on their own");
// As Collection.ownable: a set's own model drew its hose segment by segment
// and its stickers one by one, and measured short of the set that holds the
// hose and the sheet.
const derived = deriveOwnedFacts({ parts: [
  { id: "3001", name: "Brick  2 x  4", category: "Brick", kind: "Part" },
  { id: "3815", name: "~Minifig Hips (Obsolete)", category: "Obsolete", kind: "Part" },
  { id: "4073", name: "~Moved to 6141", category: "Moved", kind: "Part", moved_to: "6141" },
  { id: "756", name: "~Hose Flexible Segment Center Section", category: "Hose", kind: "Part" },
  { id: "30104k02", name: "Minifig Chain Link", category: "Minifig Accessory", kind: "Part Flexible_Section" },
  { id: "821410b", name: "Sticker  1.6 x  3.5", category: "Sticker", kind: "Part" },
  { id: "71533k03", name: "~Technic Pneumatic Tube Segment", category: "Technic", kind: "Part Flexible_Section" },
  { id: "166", name: "~Moved to 71533k03", category: "Moved", kind: "Part", moved_to: "71533k03" },
] }, []);
check(`a sticker, a link, a ~ piece and a number moved to one are not owned alone; an obsolete or moved number is: ${derived.known.join(", ")}`,
  derived.known.join(",") === "3001,3815,4073");
const catalogueFile = path.join(root, "assets/generated/catalogue.json");
if (existsSync(catalogueFile)) {
  const real = deriveOwnedFacts(JSON.parse(readFileSync(catalogueFile, "utf8")), []);
  const held = new Set(real.known);
  check(`...and in the catalogue: 756 ${held.has("756")}, 30104k02 ${held.has("30104k02")}, 166 ${held.has("166")}, `
    + `3815 ${held.has("3815")}, 4073 ${held.has("4073")}, 3001 ${held.has("3001")}`,
    !held.has("756") && !held.has("30104k02") && !held.has("166") && held.has("3815") && held.has("4073")
    && held.has("3001"));
}

console.log("sets through their inventories");
const sets = args.sets ? String(args.sets) : path.join(root, "assets/generated/sets");
const shard = path.join(sets, "000.json");
if (existsSync(shard)) {
  const inside = Object.keys(JSON.parse(readFileSync(shard, "utf8")).sets || {}).slice(0, 5);
  check(`shardOf agrees with the app's on the sets of shard 000 (${inside.join(", ")})`,
    inside.length > 0 && inside.every((set) => shardOf(set) === 0));
} else {
  console.log(`  --    no shards at ${sets}: the shard sum is checked against the app's own number below`);
}
// SetInventories.shard_of("10760-1") is 0: the set is in shard 000.
check(`10760-1 is in shard ${shardOf("10760-1")}`, shardOf("10760-1") === 0);
const fake = new Map([[shardOf("1-1"), { sets: { "1-1": { n: "Probe set", p: [["3001", 4, 2], ["3003", 1, 1]], s: [["3003", 1, 1]] } } }]]);
const reads = [];
const pool = await poolOf({ sets: [{ set: "1-1", qty: 2, spares: true }, { set: "99999999-1", qty: 1, spares: false }],
  parts: [{ part: "3001", colour: 4, qty: 1 }] }, async (n) => { reads.push(n); return fake.get(n) || null; });
check(`two of a set with its spares, and a loose brick: ${sorted(pool.lots)}`,
  sorted(pool.lots) === sorted([["3001", 4, 5], ["3003", 1, 4]]));
check(`a set no inventory has is said, not guessed: ${pool.unknown.join(", ")}`, pool.unknown.join(",") === "99999999-1");
check(`each shard read once (${reads.length})`, reads.length === new Set(reads).size);

console.log(failed ? `${failed} FAILED, ${passed} passed` : `owned_probe: ${passed} checks, all ok`);
process.exit(failed ? 1 : 0);
