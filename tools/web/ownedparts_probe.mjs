// What you own and what a model needs that you lack (ownedparts), its sums
// alone, on real data, with no database and no browser: a model's Parts
// list (api/_parts.js inventoryOf, the list its page shows and downloads)
// less what a collection holds (api/_owned.js poolOf, sets by their real
// inventories times how many of each, and loose parts), as the Parts tab's
// What you're missing counts it (missingOf), checked against a count made
// here from the raw rows by key; the three shops' lists of only those
// (wantedList, rebrickableCsv, pickABrick) read back; and the card's line
// (web/card.js ownedLine) at its edges.
//
//   node tools/web/ownedparts_probe.mjs [--out=DIR]
//
// Real data: LDraw's Official Model Repository files of three sets
// (vendor/omr/files) placed as sub-assemblies of bigger models, and
// Rebrickable's inventories of them (assets/generated/sets, the shards the
// site reads). A model's file and a set's inventory are not the same list
// (the OMR draws a sticker or a hose its own way, the inventory counts a
// part the file leaves out), so owning the set leaves what differs short:
// the count here sees it the same way, from the rows themselves.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { missingOf, ownedKey, poolOf, shardOf } from "../../api/_owned.js";
import { inventoryOf, partsTable, pickABrick, rebrickableCsv, wantedList } from "../../api/_parts.js";
import { ownedLine } from "../../web/card.js";
import { applyOp } from "../../api/collection.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const out = args.out ? path.resolve(String(args.out)) : null;
if (out) mkdirSync(out, { recursive: true });
let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};

const shards = path.join(root, "assets/generated/sets");
const omr = path.join(root, "vendor/omr/files");
if (!existsSync(shards) || !existsSync(omr) || !partsTable()) {
  console.log("ownedparts_probe: needs assets/generated (sets, catalogue) and vendor/omr in this checkout");
  process.exit(2);
}
const readShard = (n) => JSON.parse(readFileSync(path.join(shards, `${String(n).padStart(3, "0")}.json`), "utf8"));
const inventoryRows = (set) => readShard(shardOf(set)).sets[set.toLowerCase()];
const omrText = (set) => readFileSync(path.join(omr, `${set}.mpd`), "utf8");
const firstFile = (text) => /^0 FILE (.+?)\s*$/m.exec(text)[1];

/// A model of [placed] OMR sets, each [n] times side by side, and [loose]
/// part lines of its own ([part, colour, n]), as one MPD.
function modelOf(placed, loose = []) {
  const main = ["0 FILE main.ldr", "0 Ownedparts probe", "0 Name: main.ldr", "0 Author: Brickworks"];
  let x = 0;
  for (const [set, n] of placed) {
    for (let k = 0; k < n; k++) main.push(`1 16 ${(x += 400)} 0 0 1 0 0 0 1 0 0 0 1 ${firstFile(omrText(set))}`);
  }
  for (const [part, colour, n] of loose) {
    for (let k = 0; k < n; k++) main.push(`1 ${colour} ${(x += 40)} -200 0 1 0 0 0 1 0 0 0 1 ${part}.dat`);
  }
  main.push("0 NOFILE");
  return [main.join("\r\n"), ...placed.map(([set]) => omrText(set))].join("\r\n");
}

/// What a collection of [sets] ([set, qty]) and loose [parts] holds, as a
/// person's pool is counted (poolOf, the gallery's): key -> qty.
async function heldOf(sets, parts = []) {
  const pool = await poolOf({ sets: sets.map(([set, qty]) => ({ set, qty, spares: false, src: "hand" })),
    parts: parts.map(([part, colour, qty]) => ({ part, colour, qty })) }, async (n) => readShard(n));
  return new Map(pool.lots.map((lot) => [`${lot.part}/${lot.colour}`, lot.qty]));
}

/// The count made here from the raw rows, by key, with nothing of
/// missingOf's: what the model's list needs of each key, less what the
/// set inventories' rows (times the copies owned) and the loose rows hold
/// of it, never below none. key -> short.
function rawShort(inventory, sets, parts) {
  const need = new Map();
  for (const lot of inventory.lots) {
    const key = lot.custom ? "" : ownedKey(lot.part, lot.colour);
    if (key) need.set(key, (need.get(key) || 0) + lot.count);
  }
  const own = new Map();
  const add = (part, colour, n) => {
    const key = ownedKey(part, colour);
    if (key) own.set(key, (own.get(key) || 0) + n);
  };
  for (const [set, qty] of sets) for (const [part, colour, n] of inventoryRows(set).p) add(part, colour, n * qty);
  for (const [part, colour, n] of parts) add(part, colour, n);
  const short = new Map();
  for (const [key, n] of need) if (n > (own.get(key) || 0)) short.set(key, n - (own.get(key) || 0));
  return short;
}

/// The BrickLink XML's items, read back: [{id, colour, qty, remarks}].
const xmlItems = (text) => [...text.matchAll(/<ITEM>([\s\S]*?)<\/ITEM>/g)].map(([, item]) => ({
  type: /<ITEMTYPE>(.*?)<\/ITEMTYPE>/.exec(item)?.[1], id: /<ITEMID>(.*?)<\/ITEMID>/.exec(item)?.[1],
  colour: Number(/<COLOR>(.*?)<\/COLOR>/.exec(item)?.[1]), qty: Number(/<MINQTY>(.*?)<\/MINQTY>/.exec(item)?.[1]) }));

const findings = [];
const MODELS = [
  { name: "a harbour of 6541-1 with the 6596-1 speed boat set as a sub-assembly, own 6596-1",
    placed: [["6541-1", 1], ["6596-1", 1]], loose: [["3001", 4, 6]], own: [["6596-1", 1]], parts: [] },
  { name: "two 6596-1 sets in one model, own 6596-1 twice and six red 2 x 4 bricks",
    placed: [["6596-1", 2]], loose: [["3001", 4, 6], ["3794b", 15, 3]], own: [["6596-1", 2]], parts: [["3001", 4, 6], ["3794a", 15, 1]] },
  { name: "three 6660-1 sets and a 6596-1, own 6660-1 once and 6541-1 (not in it)",
    placed: [["6660-1", 3], ["6596-1", 1]], loose: [], own: [["6660-1", 1], ["6541-1", 1]], parts: [] },
];

for (const one of MODELS) {
  console.log(one.name);
  const text = modelOf(one.placed, one.loose);
  const inventory = inventoryOf(text);
  const held = await heldOf(one.own, one.parts);
  const short = missingOf(inventory, held);
  const raw = rawShort(inventory, one.own, one.parts);
  // missingOf's lots short of each key, summed, against the raw count.
  const byKey = new Map();
  for (const lot of short.missing) {
    const key = ownedKey(lot.part, lot.colour);
    byKey.set(key, (byKey.get(key) || 0) + lot.count);
  }
  const keys = new Set([...byKey.keys(), ...raw.keys()]);
  const wrong = [...keys].filter((key) => (byKey.get(key) || 0) !== (raw.get(key) || 0));
  const shortBy = short.missing.reduce((n, lot) => n + lot.count, 0);
  check(`${inventory.pieces} parts in ${inventory.lots.length} lots: missing ${shortBy} in ${short.missing.length} lots, `
    + `by key the raw rows' count (${raw.size} keys short), ${wrong.length} wrong${wrong.length ? `: ${wrong.slice(0, 5).join(", ")}` : ""}`,
  wrong.length === 0);
  check(`have + missing is every part counted: ${short.have} + ${shortBy} = ${short.pieces}`, short.have + shortBy === short.pieces);
  check(`no lot is short more than it has, and each says need and have: ${short.missing.every((lot) => lot.count >= 1
    && lot.count <= lot.need && lot.have === lot.need - lot.count)}`,
  short.missing.every((lot) => lot.count >= 1 && lot.count <= lot.need && lot.have === lot.need - lot.count));
  const whole = inventory.lots.length - short.missing.length - short.left.lots;
  check(`lots had whole ${short.whole} + short ${short.missing.length} + not counted ${short.left.lots} = ${inventory.lots.length}`,
    short.whole === whole && short.left.keys.length === short.left.lots);
  // The shops' lists of only those.
  const lots = { pieces: shortBy, lots: short.missing };
  const xml = wantedList(lots);
  const items = xmlItems(xml.text);
  const listed = short.missing.filter((lot) => !lot.custom && (lot.stand_in ? lot.stand_in.bricklink : lot.bricklink_colour) >= 0);
  const xmlRight = items.length === listed.length && items.every((item, n) => item.type === "P"
    && item.id === listed[n].bricklink && item.colour === (listed[n].stand_in ? listed[n].stand_in.bricklink : listed[n].bricklink_colour)
    && item.qty === listed[n].count);
  check(`BrickLink XML parses: ${items.length} items, each the lot's BrickLink number, colour and count short; `
    + `${xml.left_out} left out with no BrickLink colour`, xmlRight && items.length + xml.left_out === short.missing.length
    && /^<INVENTORY>\n[\s\S]*<\/INVENTORY>\n$/.test(xml.text));
  const csv = rebrickableCsv(lots).text.trim().split("\n");
  check(`Rebrickable CSV: ${csv.length - 1} rows of Part,Color,Quantity`, csv[0] === "Part,Color,Quantity"
    && csv.slice(1).every((row) => /^[^,]+,-?\d+,[1-9]\d*$/.test(row)));
  const pab = pickABrick(lots);
  const pabRows = pab.files.flatMap((file) => file.split("\r\n").slice(1)).map((row) => row.split(","));
  const elements = new Map();
  for (const lot of short.missing) {
    const element = lot.stand_in ? lot.stand_in.element : lot.element;
    if (!lot.custom && element) elements.set(element, (elements.get(element) || 0) + lot.count);
  }
  const pabRight = pabRows.length === elements.size && pabRows.every(([element, qty]) => elements.get(element) === Number(qty)
    || (elements.get(element) > 999 && Number(qty) === 999));
  check(`Pick a Brick: ${pabRows.length} elements, each a LEGO element number known for a lot short (Rebrickable's elements), `
    + `${pab.missing.length} lots with none left off and said`, pabRight && pab.files.every((file) => file.startsWith("elementId,quantity\r\n")));
  findings.push({ model: one.name, pieces: short.pieces, have: short.have, missing_parts: shortBy, missing_lots: short.missing.length,
    whole: short.whole, not_counted: short.left, wrong: wrong.length, bricklink_items: items.length, bricklink_left_out: xml.left_out,
    pickabrick_lines: pabRows.length, pickabrick_left_out: pab.missing.length });
  if (out) {
    const base = path.join(out, one.placed.map(([set, n]) => `${set}x${n}`).join("+"));
    writeFileSync(`${base}.missing-bricklink.xml`, xml.text);
    writeFileSync(`${base}.missing-pickabrick.csv`, pab.files.join("\r\n\r\n"));
  }
}

console.log("owning more copies than a model has, and owning none");
{
  const inventory = inventoryOf(modelOf([["6660-1", 1]]));
  const once = missingOf(inventory, await heldOf([["6660-1", 1]]));
  const twice = missingOf(inventory, await heldOf([["6660-1", 2]]));
  const none = missingOf(inventory, new Map());
  check(`two copies hold no more of a model of one than its parts: missing ${twice.missing.length} lots, as one copy's ${once.missing.length}`
    + ` less what a second copy covers`, twice.missing.length <= once.missing.length && twice.have >= once.have);
  check(`none owned: every counted lot missing (${none.missing.length} of ${none.lots}), have 0`, none.have === 0
    && none.missing.length === none.lots && none.whole === 0);
}

console.log("a model of no parts, and one of 4,000");
{
  const empty = missingOf({ pieces: 0, lots: [] }, new Map());
  check("no parts: nothing to have, nothing missing", empty.pieces === 0 && empty.missing.length === 0 && empty.lots === 0);
  const big = [];
  for (let n = 0; n < 4000; n++) big.push(`1 ${[4, 1, 14, 15, 0, 2, 71, 72][n % 8]} ${n * 20} 0 0 1 0 0 0 1 0 0 0 1 ${["3001", "3003", "3004", "3010", "3020", "3022", "3023", "3024", "3062b", "3070b"][n % 10]}.dat`);
  const text = ["0 FILE main.ldr", "0 Name: main.ldr", ...big, "0 NOFILE"].join("\r\n");
  let at = performance.now();
  const inventory = inventoryOf(text);
  const listed = performance.now() - at;
  const held = await heldOf([["6541-1", 3], ["6596-1", 2]], [["3001", 4, 200]]);
  at = performance.now();
  const short = missingOf(inventory, held);
  const counted = performance.now() - at;
  at = performance.now();
  const lots = { pieces: 0, lots: short.missing };
  wantedList(lots);
  pickABrick(lots);
  const listsMade = performance.now() - at;
  check(`4,000 parts (${inventory.lots.length} lots): listed in ${listed.toFixed(0)} ms, what is missing counted in `
    + `${counted.toFixed(1)} ms, the shops' lists in ${listsMade.toFixed(1)} ms`, inventory.pieces === 4000 && counted < 50 && listsMade < 50);
  findings.push({ model: "4,000 parts", lots: inventory.lots.length, list_ms: Math.round(listed), missing_ms: Number(counted.toFixed(1)),
    shops_ms: Number(listsMade.toFixed(1)) });
}

console.log("how many of a set: the own op (api/collection.js applyOp) at its edges");
{
  const have = (owned) => ({ sets: owned ? [{ set: "6596-1", qty: owned, spares: false, src: "hand" }] : [], parts: [], recent: [] });
  const tried = (owned, qty, was = owned) => {
    try {
      const done = applyOp(have(owned), { op: "own", set: "6596-1", was, qty });
      const kept = (done.next?.sets || have(owned).sets).filter((one) => one.set === "6596-1").reduce((n, one) => n + one.qty, 0);
      return { status: 200, owned: done.done?.owned, kept };
    } catch (trouble) {
      return { status: trouble?.status || 500, said: String(trouble?.message || trouble) };
    }
  };
  const cases = [[0, 1, 200], [1, 2, 200], [2, 99, 200], [2, 100, 400], [2, -1, 400], [2, "x", 400], [2, 2.5, 400],
    [3, 0, 200], [2, 3, 409, 1]];
  for (const [owned, qty, want, was] of cases) {
    const got = tried(owned, qty, was ?? owned);
    check(`owning ${owned}, ${JSON.stringify(qty)} asked${was !== undefined ? ` seeing ${was}` : ""}: ${got.status}`
      + `${got.status === 200 ? `, ${got.kept} kept` : ` "${(got.said || "").slice(0, 70)}"`}`,
    got.status === want && (want !== 200 || got.kept === qty));
  }
  // Owned past the bar before it (an import of many copies): taken down
  // still, never refused for being over it.
  const over = tried(120, 119);
  check(`owning 120 (an import), 119 asked: ${over.status}, ${over.kept} kept`, over.status === 200 && over.kept === 119);
}

console.log("the card's line");
const lines = [[{ have: 0, pieces: 10 }, ""], [{ have: 4, pieces: 10 }, ""], [{ have: 5, pieces: 10 }, "You have 50%"],
  [{ have: 87, pieces: 100 }, "You have 87%"], [{ have: 999, pieces: 1000 }, "You have 99%"],
  [{ have: 1000, pieces: 1000 }, "✓ You have every part"], [{ have: 1, pieces: 0 }, ""], [{ have: null, pieces: null }, ""],
  [null, ""], [{ have: 1, pieces: 3 }, ""], [{ have: 2, pieces: 3 }, "You have 66%"]];
for (const [owned, said] of lines) {
  check(`${JSON.stringify(owned)}: ${JSON.stringify(ownedLine(owned))}`, ownedLine(owned) === said);
}

if (out) writeFileSync(path.join(out, "ownedparts_probe.json"), `${JSON.stringify({ passed, failed, findings }, null, 1)}\n`);
console.log(`ownedparts_probe: ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
