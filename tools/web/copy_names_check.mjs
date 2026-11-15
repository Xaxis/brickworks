// The copies' names the site reads off a model's file (api/_parts.js roomOf's
// units, the AR view's and Export's GLB's assemblies): each copy's path of
// labels ("Car (copy 2)/Wing (copy 3)"), one a line, sorted. The app reads
// the same file the same way (LdrModel.flatten, Assemblies.label), the
// numbers a COPY line says of the copies inside its copy too (copyorder):
// src/dev/copyorder_probe.gd compares the two.
//
//   node tools/web/copy_names_check.mjs FILE
import { readFileSync } from "node:fs";
import { roomOf } from "../../api/_parts.js";

const file = process.argv[2];
if (!file) {
  console.error("copy_names_check: name a model file");
  process.exit(2);
}
const { units } = roomOf(readFileSync(file, "utf8"), "copy_names_check");
const paths = units.map(() => "");
const out = [];
for (let k = 1; k < units.length; k += 1) {
  const [label, parent] = units[k];
  paths[k] = parent > 0 ? `${paths[parent]}/${label}` : label;
  out.push(paths[k]);
}
out.sort();
for (const path of out) console.log(path);
