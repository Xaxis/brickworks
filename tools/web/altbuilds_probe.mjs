// What altbuilds counts (api/_alts.js), measured on real models and real
// sets: the LDraw library's 1,500-odd models (vendor/omr/files) against the
// sets' shards of this checkout. No network, no database.
//
//   node tools/web/altbuilds_probe.mjs OUT_DIR [--library=library/index.json]
//
// Writes into OUT_DIR:
//   pairs.json      20 (model, set) pairs and what the count says each set
//                   holds of each model, part and colour by part and colour,
//                   for src/dev/altbuilds_probe.gd to hold to the app's own
//                   Collection check (the same file, a Collection holding
//                   that one set): the share must be the same, part for part
//   precision.json  50 pairs the count calls an alternate (every part from
//                   one set, or from a group), each with the set's and the
//                   model's own lines, for tools/altbuilds_check.py to check
//                   from the files with a reader of its own
//   recall.txt      every model the Library says is another model of a set
//                   (its index's alternate_of), and whether the count finds
//                   it as its set's: the set's page lists it
//   timing.txt      the count's time on models of 800 to 1,200 pieces (a
//                   publish counts after its answer: api/share.js), p50,
//                   p95, the most, and the index's read from its bytes
// Exits 1 when a measure cannot be made (no shards, no library).
import { existsSync, readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
import { MOST_GROUP, SHOWN_SHARE, altIndex, altsOf, countRows, packIndex, shareOf, unpackIndex } from "../../api/_alts.js";
import { keyed } from "../../api/_owned.js";
import { checkModel } from "../../api/share.js";

const out = process.argv.slice(2).find((a) => !a.startsWith("--"));
if (!out) {
  console.error("altbuilds_probe: name the folder to write into");
  process.exit(2);
}
mkdirSync(out, { recursive: true });
const DIR = "vendor/omr/files";
// The Library's index (tools/library_build.py's library/index.json): named,
// or its last build's.
const INDEX = [(process.argv.find((a) => a.startsWith("--library=")) || "").slice(10),
  "bench/results/library-2026-10-26/library/index.json"].find((path) => path && existsSync(path));
if (!existsSync(DIR)) {
  console.error(`altbuilds_probe: no ${DIR}`);
  process.exit(1);
}
let t0 = performance.now();
const built = altIndex();
const built_ms = performance.now() - t0;
const bytes = packIndex(built);
t0 = performance.now();
const index = unpackIndex(bytes);
const read_ms = performance.now() - t0;
console.log(`index: ${index.sets.length} sets, ${index.keys.size} parts and colours; worked out in ${built_ms.toFixed(0)} ms, `
  + `${(bytes.length / 1048576).toFixed(1)} MB, read back in ${read_ms.toFixed(0)} ms`);

const files = readdirSync(DIR).filter((name) => /\.(mpd|ldr)$/i.test(name)).sort();
const models = [];
for (const file of files) {
  let lots;
  try {
    lots = keyed(checkModel(readFileSync(`${DIR}/${file}`, "utf8")).needs);
  } catch {
    continue;
  }
  if (!lots.length) continue;
  const set = file.replace(/\.(mpd|ldr)$/i, "").split("_")[0].toLowerCase();
  const began = performance.now();
  const counted = altsOf(lots, index);
  const ms = performance.now() - began;
  models.push({ file, set, lots, counted, ms });
}
console.log(`${models.length} library models counted`);

// --- 20 pairs for the app's Collection check -----------------------------------
// Chosen to cover what a count can be: every part from the set, most of
// it, a group's member, little of it, and a set with another mould or a
// moved number among what it holds; the first of each in file order.
const pick = [];
const take = (why, test, most) => {
  for (const one of models) {
    if (pick.filter((p) => p.why === why).length >= most) break;
    if (pick.some((p) => p.file === one.file)) continue;
    const set = test(one);
    if (set) pick.push({ why, file: one.file, set });
  }
};
take("every part from it", (m) => (m.counted.best && m.counted.best.have >= m.counted.pieces ? m.counted.best.set : null), 5);
take("most of it", (m) => (m.counted.best && m.counted.best.have < m.counted.pieces
  && m.counted.best.have >= SHOWN_SHARE * m.counted.pieces ? m.counted.best.set : null), 5);
take("one of a group", (m) => (m.counted.group ? m.counted.group[m.counted.group.length - 1].set : null), 5);
take("little of it", (m) => {
  const own = shareOf(m.lots, m.set, index);
  return own && own.have < 0.5 * own.pieces ? own.set : null;
}, 5);
const pairs = pick.map((one) => {
  const model = models.find((m) => m.file === one.file);
  const share = shareOf(model.lots, one.set, index, { every: true });
  return { why: one.why, file: one.file, set: share.set, pieces: share.pieces, have: share.have,
    lots: share.lots.map((lot) => [lot.part, lot.colour, lot.need, lot.have]) };
});
writeFileSync(`${out}/pairs.json`, JSON.stringify({ pairs }, null, 1));
console.log(`pairs.json: ${pairs.length} pairs (${[...new Set(pairs.map((p) => p.why))].map((why) => `${pairs.filter((p) => p.why === why).length} ${why}`).join(", ")})`);

// --- 50 pairs called alternates, for the check from the files ----------------
const called = [];
for (const m of models) {
  if (m.counted.best && m.counted.best.have >= m.counted.pieces) called.push({ file: m.file, sets: [m.counted.best.set], how: "whole" });
}
const groups = models.filter((m) => m.counted.group).map((m) => ({ file: m.file, sets: m.counted.group.map((g) => g.set), how: "group" }));
// Every one, spread over the files: 25 of each where there are.
const spread = (list, n) => list.filter((_, at) => at % Math.max(1, Math.floor(list.length / n)) === 0).slice(0, n);
const precision = [...spread(called, 25), ...spread(groups, 50 - Math.min(25, called.length))].slice(0, 50);
writeFileSync(`${out}/precision.json`, JSON.stringify({ pairs: precision }, null, 1));
console.log(`precision.json: ${precision.length} pairs (${precision.filter((p) => p.how === "whole").length} every part from one set, `
  + `${precision.filter((p) => p.how === "group").length} from a group of up to ${MOST_GROUP}); ${called.length} library models are `
  + `whole from one set and ${groups.length} from a group`);

// --- Recall: the Library's other models of a set ------------------------------
const lines = [];
if (INDEX) {
  const entries = JSON.parse(readFileSync(INDEX, "utf8")).models.filter((m) => m && m.alternate_of);
  let found = 0;
  let foundWord = 0;
  let counted = 0;
  for (const entry of entries) {
    const file = String(entry.file).replace(/^library\/omr\//, "");
    const model = models.find((m) => m.file === file);
    if (!model) {
      lines.push(`--  ${entry.id}: not counted (no needs in its file)`);
      continue;
    }
    counted += 1;
    const set = String(entry.alternate_of).toLowerCase();
    // As the publish keeps it, the count alone, then with the Library's word.
    const alone = countRows(model.lots, index).rows;
    const listed = alone.some((row) => row.set === set && ["whole", "group", "best"].includes(row.role));
    const word = countRows(model.lots, index, { library: { set: entry.set, alternate_of: entry.alternate_of } }).rows;
    const listedWord = word.some((row) => row.set === set);
    const own = shareOf(model.lots, set, index);
    found += listed ? 1 : 0;
    foundWord += listedWord ? 1 : 0;
    lines.push(`${listed ? "ok" : "--"}  ${entry.id}: ${own ? `${own.have}/${own.pieces}` : "no such set"} from ${set}; `
      + `counted: ${alone.map((row) => `${row.role} ${row.set} ${row.have}`).join(", ") || "none"}`);
  }
  lines.unshift(`The Library's ${entries.length} other models of a set (alternate_of), ${counted} with parts: the count alone `
    + `lists ${found} on their set's page (every part from it, one of a group, or ${Math.round(SHOWN_SHARE * 100)}% or more), `
    + `and with the Library's word, as a library model published is counted, ${foundWord}.`);
  console.log(lines[0]);
} else {
  lines.push("no library index here (bench/results/library-2026-10-26/library/index.json): recall not measured");
}
writeFileSync(`${out}/recall.txt`, `${lines.join("\n")}\n`);

// --- Timing --------------------------------------------------------------------
const sized = models.filter((m) => m.counted.pieces >= 800 && m.counted.pieces <= 1200);
// Each counted again 5 times, warm, the times kept.
const times = [];
for (const m of sized) {
  for (let k = 0; k < 5; k += 1) {
    const began = performance.now();
    altsOf(m.lots, index);
    times.push(performance.now() - began);
  }
}
times.sort((a, b) => a - b);
const at = (q) => times[Math.min(times.length - 1, Math.floor(q * times.length))];
const all = models.map((m) => m.ms).sort((a, b) => a - b);
const timing = `${sized.length} library models of 800 to 1,200 pieces, each counted 5 times: p50 ${at(0.5).toFixed(1)} ms, `
  + `p95 ${at(0.95).toFixed(1)} ms, most ${times[times.length - 1].toFixed(1)} ms. Every model once (${all.length}): p95 `
  + `${all[Math.floor(0.95 * all.length)].toFixed(1)} ms, most ${all[all.length - 1].toFixed(1)} ms. The index read from its `
  + `${(bytes.length / 1048576).toFixed(1)} MB in ${read_ms.toFixed(0)} ms, once a function instance.`;
writeFileSync(`${out}/timing.txt`, `${timing}\n`);
console.log(timing);
