// What the owner's console says of the site's data (/admin#data,
// api/_console_data.js), written beside /api/admin as it is packaged
// (tools/package_api.sh), from what the deploy was made with:
//
//   rebrickable  when each of Rebrickable's tables was last fetched
//                (vendor/rebrickable/*.csv.gz, tools/fetch_data.sh: at most
//                once a day, a condition of their grant)
//   catalogue    every set in it (assets/generated/set_catalog.json,
//                tools/set_catalog.py) and how many have their own picture
//                in our storage (tools/set_pictures.py), the rest without
//   pictures     when set_pictures last ran, and how many it made
//
//   node tools/web/data_facts.mjs OUT.json
//
// Never fails a deploy: what it cannot read it says is not known.
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";

const out = process.argv[2];
if (!out) {
  console.error("data_facts: name the file to write");
  process.exit(2);
}
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const at = (file) => {
  try {
    return statSync(file).mtime.toISOString();
  } catch {
    return null;
  }
};
const read = (file) => {
  try {
    return JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return null;
  }
};

const vendor = path.join(root, "vendor/rebrickable");
const tables = {};
if (existsSync(vendor)) {
  for (const name of readdirSync(vendor).filter((one) => one.endsWith(".csv.gz")).sort()) {
    tables[name.replace(/\.csv\.gz$/, "")] = at(path.join(vendor, name));
  }
}
const times = Object.values(tables).filter(Boolean).sort();

const catalogueFile = path.join(root, "assets/generated/set_catalog.json");
const catalogue = read(catalogueFile);
const sets = Array.isArray(catalogue?.sets) ? catalogue.sets : null;
// Each set is [number, name, year, theme, parts, minifigures, lots, photo].
const withPicture = sets ? sets.filter((one) => Array.isArray(one) && one[7] === 1).length : null;

const pictures = read(path.join(root, "assets/generated/set_pictures.json"));

const facts = {
  made: new Date().toISOString(),
  rebrickable: { tables, newest: times.at(-1) ?? null, oldest: times[0] ?? null },
  catalogue: sets ? { sets: sets.length, with_picture: withPicture, without_picture: sets.length - withPicture,
    made: at(catalogueFile) } : null,
  pictures: pictures ? { made: pictures.made ?? null, sets: Array.isArray(pictures.sets) ? pictures.sets.length : null } : null,
};
writeFileSync(out, `${JSON.stringify(facts)}\n`);
console.log(`data_facts: ${sets ? `${sets.length} sets, ${withPicture} with a picture` : "no set catalogue"}; `
  + `Rebrickable fetched ${facts.rebrickable.newest ? facts.rebrickable.newest.slice(0, 10) : "never here"}`);
