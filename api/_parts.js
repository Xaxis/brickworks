// A shared model's parts list (2026-10-26, site278): what a builder would
// have to buy, read from the stored .mpd here, so every model already shared
// has one without its owner publishing again.
//
// It is the app's own list (src/assembly/inventory.gd Inventory.of, as
// count_of_text reads a file), so the page and the app say one count and the
// same lots: sub-models expanded, a colour 16 part in the colour it is placed
// in; a sticker counted; a hose, a tube, a flexible axle or a string a
// Brickworks file lays as segments counted once, as the straight part nearest
// its length (Flex.real_part); an LDCad hose (`0 !LDCAD GENERATED`) one
// flexible part of its own (CustomParts' skin), its end pieces as themselves;
// a part the file carries counted as a made one; and a ~ piece LDraw draws a
// bigger part with, a primitive placed in the model and a reference to
// nothing known, none. A lot is a part in a colour.
//
// What it needs of the catalogue, every part's name and kind, LDraw's moves,
// the shops' numbers and each colour's, is a table (deriveTable), written
// beside the share function at deploy as _parts_table.json
// (tools/web/part_facts.mjs) and worked out of assets/generated in a checkout,
// so the two cannot say different things.
//
// The exports are the two the app makes (src/assembly/shop_lists.gd): a
// BrickLink wanted list (BrickLink's XML: ITEMTYPE, ITEMID, COLOR, MINQTY in
// <INVENTORY>) and a Rebrickable parts list (its CSV import: Part, Color,
// Quantity), a lot left off where the shop has no number for its colour, and
// a made part, which no shop sells.

import { existsSync, readFileSync } from "node:fs";

let table = null;

/// The catalogue's facts this list needs, read once: from _parts_table.json
/// beside this file in a deployment, or out of the catalogue in a checkout.
/// Null where there are neither.
export function partsTable() {
  if (table) return table;
  const beside = new URL("./_parts_table.json", import.meta.url);
  if (existsSync(beside)) {
    table = JSON.parse(readFileSync(beside, "utf8"));
    return table;
  }
  const at = (name) => new URL(`../assets/generated/${name}`, import.meta.url);
  if (existsSync(at("catalogue.json")) && existsSync(at("colors.json"))) {
    const elements = existsSync(at("elements.json")) ? JSON.parse(readFileSync(at("elements.json"), "utf8")) : {};
    table = deriveTable(JSON.parse(readFileSync(at("catalogue.json"), "utf8")),
      JSON.parse(readFileSync(at("colors.json"), "utf8")), elements);
    return table;
  }
  return null;
}

/// A table named by hand (a check run where the checkout has no catalogue).
export function useTable(given) {
  table = given;
  return table;
}

/// The flexible parts a Brickworks file lays as pieces (Flex.KINDS): each
/// kind's pieces, how it is measured and the name of the part it is sold as.
const KINDS = {
  ribbed_hose: { family: "pitched", real: "Technic Ribbed Hose", segment: "71944k02", end: "71944k01", pitch: 6.25, tip: 2.5 },
  pneumatic_tube: { family: "scaled", real: "Technic Pneumatic Tube", middle: "71533k03", end: "71533k02", native: 1.0, along: "y" },
  flex_hose: { family: "scaled", real: "Technic Flex-System Hose", middle: "77", end: "u9053", native: 1.0, along: "y" },
  flex_axle: { family: "scaled", real: "Technic Axle Flexible 26", middle: "u9012", native: 360.0, along: "x",
    ends: ["u9011", "u9010"], rigid: [60.0, 116.0], overlap: 10.0 },
  string: { family: "pitched", real: "String Braided", segment: "71149k02", end: "71149k01", pitch: 6.0, along: "x" },
  chain: { family: "links", link: "3711" },
  tread: { family: "links", link: "3873" },
};
const PIECE_KIND = new Map();
for (const [kind, spec] of Object.entries(KINDS)) {
  for (const key of ["segment", "end", "middle", "link"]) if (spec[key]) PIECE_KIND.set(spec[key], kind);
  for (const part of spec.ends || []) PIECE_KIND.set(part, kind);
}

/// What the table holds, from the catalogue, the colours and the elements
/// (assets/generated): every part as [name, category index, flags (1: a
/// Flexible_Section), moved to, BrickLink's number, Rebrickable's number],
/// trailing blanks left off; every colour as [name, hex, LEGO's name,
/// Rebrickable's number, BrickLink's number, plain code]; the element to
/// order for each part in a plain colour; and the straight parts each
/// flexible kind is sold as, shortest first (Flex.lengths_of).
export function deriveTable(catalogue, colours, elements = {}) {
  const categories = [];
  const categoryOf = new Map();
  const parts = {};
  const shop = (part, name) => {
    const prefix = `${name} `;
    const word = (part.keywords || []).find((one) => one.startsWith(prefix) && one.split(" ").length === 2);
    return word ? word.split(" ")[1] : "";
  };
  for (const part of catalogue.parts || []) {
    const category = String(part.category || "");
    if (!categoryOf.has(category)) {
      categoryOf.set(category, categories.length);
      categories.push(category);
    }
    const row = [String(part.name || ""), categoryOf.get(category),
      String(part.kind || "").includes("Flexible_Section") ? 1 : 0, String(part.moved_to || ""),
      shop(part, "BrickLink"), shop(part, "Rebrickable")];
    while (row.length > 2 && (row[row.length - 1] === "" || row[row.length - 1] === 0)) row.pop();
    parts[String(part.id)] = row;
  }
  const colourRows = {};
  for (const colour of Array.isArray(colours) ? colours : []) {
    const hex = (colour.rgb || [255, 0, 255]).map((n) => Number(n).toString(16).padStart(2, "0")).join("");
    colourRows[colour.code] = [String(colour.name || ""), hex, String(colour.lego_name || ""),
      Number.isInteger(colour.rebrickable_id) ? colour.rebrickable_id : -1,
      Number.isInteger(colour.bricklink) ? colour.bricklink : -1,
      Number.isInteger(colour.plain_code) ? colour.plain_code : colour.code];
  }
  const flex = {};
  for (const [kind, spec] of Object.entries(KINDS)) {
    if (spec.family === "links") continue;
    const found = [];
    for (const part of catalogue.parts || []) {
      const name = String(part.name || "");
      if (!name.startsWith(spec.real) || part.moved_to || name.startsWith("~") || name.includes("Bulges")
        || name.includes("Segment")) continue;
      if (kind === "pneumatic_tube" && !String(part.id).endsWith("-f1")) continue;
      if (kind === "string" && !name.includes("End Studs")) continue;
      found.push([String(part.id), Math.max(...(part.size_ldu || [0, 0, 0]).map(Number))]);
    }
    found.sort((a, b) => (Math.abs(a[1] - b[1]) > 1e-5 ? a[1] - b[1] : a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
    flex[kind] = found;
  }
  return { categories, parts, colours: colourRows, elements: elements.pairs || {}, flex };
}

// ---------------------------------------------------------------------------
// The file, read as the app reads it (LdrModel.parse).

/// A reference's or a FILE's name as the other finds it: no folder, no
/// extension, lower case (LdrModel._key).
function keyOf(name) {
  let text = String(name).replace(/\\/g, "/").trim().toLowerCase();
  text = text.slice(text.lastIndexOf("/") + 1);
  for (const suffix of [".ldr", ".dat", ".mpd"]) {
    if (text.endsWith(suffix)) return text.slice(0, -suffix.length);
  }
  return text;
}

const fileOf = (path) => path.slice(path.lastIndexOf("/") + 1);
const baseOf = (name) => (name.lastIndexOf(".") > 0 ? name.slice(0, name.lastIndexOf(".")) : name);

/// A colour token: a palette number, or 0x2RRGGBB kept as the number it is;
/// null for one nobody can read (LdrModel._colour).
function colourOf(token) {
  if (/^[+-]?\d+$/.test(token)) return Number(token);
  if (/^0x2[0-9a-f]{6}$/i.test(token)) return parseInt(token.slice(2), 16);
  return null;
}

const NUMBER = /^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/;

const declaresPart = (lines) => lines.slice(0, 16)
  .some((raw) => raw.trim().startsWith("0 !LDRAW_ORG") && raw.trim().toLowerCase().includes("part"));

/// [text] as its sub-models, the parts it carries and its LDCad-generated
/// sections: {main, submodels: key -> {name, title, placements}, carried:
/// file name -> text, sections: name -> text, generated: Set of keys}.
function parse(text) {
  const submodels = new Map();
  const implicit = { name: "model", title: "", placements: [] };
  submodels.set("model", implicit);
  let main = implicit;
  let current = implicit;
  let firstFile = true;
  let section = "";
  const sections = new Map();
  let inData = false;
  const generated = new Set();
  let author = "";
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (inData) {
      if (line.startsWith("0 !:")) continue;
      inData = false;
    }
    if (line.startsWith("0 !DATA ") || line.startsWith("0 !DATA\t")) {
      section = "";
      inData = true;
      continue;
    }
    const spaced = line.split(" ").filter(Boolean);
    const fileLine = spaced.length >= 2 && spaced[0] === "0" && /^(FILE|NOFILE|!DATA)$/i.test(spaced[1]);
    if (section && !fileLine) sections.get(section).push(raw.replace(/\r$/, ""));
    if (line === "") continue;
    const tokens = line.split(/\s+/);
    if (tokens[0] === "0") {
      if (tokens.length < 2) continue;
      const keyword = tokens[1].toUpperCase();
      if (keyword === "NOFILE") section = "";
      if (keyword === "FILE") {
        const name = tokens.slice(2).join(" ").trim();
        section = name.toLowerCase();
        sections.set(section, []);
        current = { name, title: "", placements: [] };
        submodels.set(keyOf(name), current);
        if (firstFile) {
          main = current;
          submodels.delete("model");
          if (keyOf(name) === "model") submodels.set("model", current);
          firstFile = false;
        }
      } else if (keyword === "STEP" || keyword === "ROTSTEP") {
        // Steps say nothing of what is in it.
      } else if (keyword === "!LDCAD" && tokens[2] === "GENERATED" && !generated.has(keyOf(current.name))) {
        generated.add(keyOf(current.name));
      } else if (keyword === "AUTHOR:" && !author) {
        author = tokens.slice(2).join(" ");
      } else if (!current.title && current.placements.length === 0 && !keyword.startsWith("!") && keyword !== "BFC"
        && keyword !== "NAME:" && keyword !== "NOFILE" && !tokens[1].startsWith("//")) {
        current.title = tokens.slice(1).join(" ").trim();
      }
      continue;
    }
    if (tokens[0] !== "1" || tokens.length < 15) continue;
    const colour = colourOf(tokens[1]);
    if (colour === null) continue;
    if (!tokens.slice(2, 14).every((t) => NUMBER.test(t))) continue;
    const numbers = tokens.slice(2, 14).map(Number);
    let part = fileOf(tokens.slice(14).join(" ").trim().replace(/\\/g, "/").toLowerCase());
    if (part.endsWith(".dat") || part.endsWith(".ldr")) part = part.slice(0, -4);
    current.placements.push({ part, colour, m: numbers });
  }
  const carried = new Map();
  const texts = new Map();
  for (const [name, lines] of sections) {
    if (name === main.name.toLowerCase()) continue;
    texts.set(name, lines.join("\n").trim() + "\n");
    if (!declaresPart(lines)) continue;
    const key = name.endsWith(".dat") ? name : `${name}.dat`;
    carried.set(fileOf(key.replace(/\\/g, "/")), texts.get(name));
    submodels.delete(keyOf(name));
  }
  return { main, submodels, carried, sections: texts, generated };
}

// ---------------------------------------------------------------------------
// The catalogue, as the app's library answers it.

function makeLibrary(given) {
  const custom = new Map();     // id -> {name, category, custom: true}
  const info = (id) => {
    const made = custom.get(id);
    if (made) return made;
    const row = given.parts[id];
    if (!row) return null;
    return { name: row[0], category: given.categories[row[1]] || "", flexible: row[2] === 1,
      moved: row[3] || "", bricklink: row[4] || "", rebrickable: row[5] || "", custom: false };
  };
  const has = (id) => custom.has(id) || Object.prototype.hasOwnProperty.call(given.parts, id);
  /// The number a part means today (PartLibrary.resolve).
  const resolve = (id) => {
    let at = id;
    for (let hop = 0; hop < 8; hop += 1) {
      const one = info(at);
      if (!one || !one.moved || !has(one.moved)) return at;
      at = one.moved;
    }
    return at;
  };
  const colour = (code) => {
    const row = given.colours[code];
    return row ? { name: row[0], hex: row[1], lego: row[2], rebrickable: row[3], bricklink: row[4], plain: row[5] }
      : { name: `Unknown ${code}`, hex: "ff00ff", lego: "", rebrickable: -1, bricklink: -1, plain: code };
  };
  return { custom, info, has, resolve, colour };
}

/// Whether a part is a piece a builder takes out of the box (Inventory.is_piece).
function isPiece(library, id) {
  if (PIECE_KIND.has(id)) return true;
  const info = library.info(library.resolve(id));
  if (!info) return true;
  if (info.category === "Sticker") return true;
  if (info.flexible) return false;
  return !info.name.startsWith("~") || Boolean(info.moved) || info.name.includes("(Obsolete)");
}

/// The parts the file carries join the library, and each LDCad-generated
/// hose becomes one flexible part in its sub-model (CustomParts.take_into).
function takeInto(library, model) {
  // The skins first, judged against the library as it was.
  const pieces = new Map();
  const piece = (key, depth = 0) => {
    if (pieces.has(key)) return pieces.get(key);
    let found = false;
    if (library.has(key) || model.carried.has(`${key}.dat`)) found = true;
    else if (model.generated.has(key) && model.submodels.has(key)) found = true;
    else if (model.submodels.has(key) && depth < 16) {
      pieces.set(key, false);
      found = model.submodels.get(key).placements.some((one) => piece(keyOf(one.part), depth + 1));
    }
    pieces.set(key, found);
    return found;
  };
  const skins = [];
  for (const key of model.generated) {
    const sub = model.submodels.get(key);
    if (!sub) continue;
    const body = model.sections.get(sub.name.toLowerCase()) || "";
    let faces = 0;
    for (const raw of body.split("\n")) {
      const line = raw.trim();
      if (!line) continue;
      const kind = line.length === 1 || line[1] === " " || line[1] === "\t" ? line[0] : "";
      if (kind === "1") {
        const words = line.replace(/\t/g, " ").split(" ").filter(Boolean);
        if (words.length < 15) continue;
        if (piece(keyOf(words.slice(14).join(" ")))) continue;
        faces += 1;
      } else if (kind === "3" || kind === "4") faces += 1;
    }
    if (faces > 0) skins.push([key, sub]);
  }
  // The carried parts not the catalogue's own.
  for (const [fileName, text] of model.carried) {
    const id = baseOf(fileName);
    const known = library.info(id);
    if (known && !known.custom) continue;
    if (id.startsWith("bl_")) {
      const plain = library.info(id.slice(3));
      if (plain && !plain.custom) continue;
    }
    let name = "";
    for (const raw of text.split("\n")) {
      const line = raw.trim();
      if (!line) continue;
      if (line.startsWith("0")) name = line.slice(1).trim();
      break;
    }
    const named = library.info(name.trim());
    if (named && !named.custom && name.trim() !== id) name = named.name;
    library.custom.set(id, { name, category: text.includes("\n0 !CATEGORY Flexible\n") ? "Flexible" : "Custom",
      flexible: false, moved: "", bricklink: "", rebrickable: "", custom: true });
  }
  for (const [key, sub] of skins) {
    const id = `${key}-flex`;
    const title = sub.title || keyOf(sub.name);
    library.custom.set(id, { name: `${title} (flexible)`, category: "Flexible", flexible: false, moved: "",
      bricklink: "", rebrickable: "", custom: true });
    sub.placements = [...sub.placements.filter((one) => piece(keyOf(one.part))),
      { part: id, colour: 16, m: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1] }];
  }
}

/// [a] then [b], as LDraw's twelve numbers: x y z and a row-major 3 x 3.
function compose(a, b) {
  const out = new Array(12);
  for (let r = 0; r < 3; r += 1) {
    out[r] = a[r] + a[3 + r * 3] * b[0] + a[4 + r * 3] * b[1] + a[5 + r * 3] * b[2];
    for (let c = 0; c < 3; c += 1) {
      out[3 + r * 3 + c] = a[3 + r * 3] * b[3 + c] + a[4 + r * 3] * b[6 + c] + a[5 + r * 3] * b[9 + c];
    }
  }
  return out;
}
const IDENTITY = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1];

/// Every part placed, through the sub-models (LdrModel.flatten): {part,
/// colour, m, unit}, [unit] the copy of the sub-model it is placed in.
function flatten(model, library) {
  const out = [];
  let copies = 0;
  const inline = (sub, at, colour, visiting, depth, unit) => {
    const key = keyOf(sub.name);
    if (depth > 32 || visiting.has(key)) return;
    const inside = new Set(visiting).add(key);
    for (const one of sub.placements) {
      const nested = model.submodels.get(keyOf(one.part));
      const placedIn = one.colour === 16 ? colour : one.colour;
      if (nested && !library.has(one.part)) {
        copies += 1;
        inline(nested, compose(at, one.m), placedIn, inside, depth + 1, `${copies}`);
        continue;
      }
      out.push({ part: one.part, colour: placedIn, m: compose(at, one.m), unit });
    }
  };
  if (model.main) inline(model.main, IDENTITY, 0, new Set(), 0, "");
  return out;
}

/// The flexible items a Brickworks file lays (Flex.items_among): each copy
/// of a sub-model whose parts are all one kind's pieces. unit -> {kind, bricks}.
function itemsAmong(bricks) {
  const found = new Map();
  const notItems = new Set();
  for (const brick of bricks) {
    const kind = PIECE_KIND.get(brick.part);
    if (!kind || !brick.unit) continue;
    const item = found.get(brick.unit);
    if (!item) found.set(brick.unit, { kind, bricks: [brick] });
    else {
      if (item.kind !== kind) notItems.add(brick.unit);
      item.bricks.push(brick);
    }
  }
  if (!found.size) return found;
  for (const brick of bricks) {
    if (!PIECE_KIND.has(brick.part) && brick.unit && found.has(brick.unit)) notItems.add(brick.unit);
  }
  for (const unit of notItems) found.delete(unit);
  return found;
}

/// How long an item is along its pieces (Flex.item_length).
function itemLength(kind, bricks) {
  const spec = KINDS[kind];
  let run = 0;
  if (spec.family === "scaled") {
    for (const brick of bricks) {
      if (brick.part !== spec.middle) continue;
      const m = brick.m;
      const column = spec.along === "x" ? [m[3], m[6], m[9]] : [m[4], m[7], m[10]];
      run += Math.hypot(...column) * spec.native;
    }
    if (spec.ends) run += spec.rigid[0] + spec.rigid[1] - spec.overlap * 2;
  } else if (spec.family === "pitched") {
    const segments = bricks.filter((brick) => brick.part === spec.segment).length;
    run = kind === "string" ? segments * spec.pitch + 28 : (segments + 1) * spec.pitch + spec.tip * 2;
  }
  return run;
}

/// The part a shop sells an item as: its kind's straight part nearest its
/// length (Flex.real_part); "" for a chain or a tread, sold as its links.
function realPart(given, kind, bricks) {
  if (KINDS[kind].family === "links") return "";
  const run = itemLength(kind, bricks);
  let found = "";
  let nearest = Infinity;
  for (const [id, length] of given.flex[kind] || []) {
    const off = Math.abs(length - run);
    if (off < nearest) {
      nearest = off;
      found = id;
    }
  }
  return found;
}

/// The number a shop lists a part under (PartLibrary.shop_part): the one
/// LDraw records for it, else LDraw's own less a formed shape's "-f1".
function shopPart(info, id, which) {
  if (info && info[which]) return info[which];
  const formed = id.lastIndexOf("-f");
  if (formed > 0 && /^\d+$/.test(id.slice(formed + 2))) return id.slice(0, formed);
  return id;
}

const tidy = (raw) => String(raw).trim().replace(/ {2,}/g, " ");

/// The parts list of a model file: {pieces, lots}, each lot {part, name,
/// category, colour, colour_name, hex, lego_colour, count, element, custom,
/// bricklink, bricklink_colour, rebrickable, rebrickable_colour}, ordered as
/// the app orders its list: by how many of a part there are, its colours
/// together. [given] is partsTable()'s.
export function inventoryOf(text, given = partsTable()) {
  if (!given) throw new Error("there is no parts table here");
  const model = parse(String(text).replace(/^﻿/, ""));
  const library = makeLibrary(given);
  takeInto(library, model);
  const bricks = [];
  for (const placed of flatten(model, library)) {
    const studio = placed.part.startsWith("bl_") && !library.has(placed.part) && library.has(placed.part.slice(3))
      ? placed.part.slice(3) : placed.part;
    const part = library.resolve(studio);
    if (!library.has(part)) continue;
    bricks.push({ ...placed, part });
  }
  const lots = [];
  const byKey = new Map();
  let pieces = 0;
  const add = (part, code) => {
    const key = `${part}:${code}`;
    let lot = byKey.get(key);
    if (!lot) {
      const info = library.info(part);
      const colour = library.colour(code);
      const plain = library.colour(colour.plain);
      let element = given.elements[`${part}/${colour.plain}`] || "";
      // Cloth is listed by its flat number (PartLibrary.element_for).
      if (!element && info && info.name.includes("(Formed") && /c\d\d$/.test(part)) {
        element = given.elements[`${part.slice(0, -3)}/${colour.plain}`] || "";
      }
      lot = {
        part, name: tidy(info ? info.name : part) + (info && info.custom ? " (custom element)" : ""),
        category: info ? info.category : "", colour: code, colour_name: colour.name, hex: colour.hex,
        lego_colour: plain.lego, count: 0, element, custom: Boolean(info && info.custom),
        bricklink: shopPart(info, part, "bricklink"), bricklink_colour: plain.bricklink,
        rebrickable: shopPart(info, part, "rebrickable"), rebrickable_colour: plain.rebrickable,
      };
      byKey.set(key, lot);
      lots.push(lot);
    }
    lot.count += 1;
    pieces += 1;
  };
  const inItems = new Set();
  for (const item of itemsAmong(bricks).values()) {
    const real = realPart(given, item.kind, item.bricks);
    if (!real) continue;
    const tally = new Map();
    for (const brick of item.bricks) tally.set(brick.colour, (tally.get(brick.colour) || 0) + 1);
    let colour = item.bricks[0].colour;
    for (const [code, n] of tally) if (n > tally.get(colour)) colour = code;
    add(real, colour);
    for (const brick of item.bricks) inItems.add(brick);
  }
  for (const brick of bricks) {
    if (inItems.has(brick) || !isPiece(library, brick.part)) continue;
    add(brick.part, brick.colour);
  }
  const perPart = new Map();
  for (const lot of lots) perPart.set(lot.part, (perPart.get(lot.part) || 0) + lot.count);
  const before = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
  lots.sort((a, b) => perPart.get(b.part) - perPart.get(a.part)
    || (a.part !== b.part ? (a.name !== b.name ? before(a.name, b.name) : before(a.part, b.part)) : 0)
    || b.count - a.count || before(a.colour_name, b.colour_name));
  return { pieces, lots };
}

// ---------------------------------------------------------------------------
// The shops' lists (ShopLists).

const xml = (text) => String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/// A BrickLink wanted list, to upload under Wanted › Upload: {text, lots,
/// left_out}. A made part and a colour BrickLink has no number known for are
/// left off, never guessed.
export function wantedList(inventory) {
  const lines = ["<INVENTORY>"];
  let left = 0;
  for (const lot of inventory.lots) {
    if (lot.custom || lot.bricklink_colour < 0) {
      left += 1;
      continue;
    }
    lines.push("  <ITEM>", "    <ITEMTYPE>P</ITEMTYPE>", `    <ITEMID>${xml(lot.bricklink)}</ITEMID>`,
      `    <COLOR>${lot.bricklink_colour}</COLOR>`, `    <MINQTY>${lot.count}</MINQTY>`, "  </ITEM>");
  }
  lines.push("</INVENTORY>");
  return { text: `${lines.join("\n")}\n`, lots: inventory.lots.length - left, left_out: left };
}

/// Rebrickable's parts-list import: Part, Color, Quantity, in its numbers.
export function rebrickableCsv(inventory) {
  const rows = ["Part,Color,Quantity"];
  let left = 0;
  for (const lot of inventory.lots) {
    if (lot.custom || lot.rebrickable_colour < 0) {
      left += 1;
      continue;
    }
    const part = /[",\n]/.test(lot.rebrickable) ? `"${lot.rebrickable.replace(/"/g, '""')}"` : lot.rebrickable;
    rows.push(`${part},${lot.rebrickable_colour},${lot.count}`);
  }
  return { text: `${rows.join("\n")}\n`, lots: inventory.lots.length - left, left_out: left };
}

/// Where a lot's picture is: Rebrickable's photo of the element where there
/// is one to order, else its render of the part in the colour, which is the
/// picture its own parts lists show. "" for a made part, which it has none of.
export function pictureOf(lot) {
  if (lot.custom) return "";
  if (lot.element) return `https://cdn.rebrickable.com/media/parts/elements/${lot.element}.jpg`;
  if (lot.rebrickable_colour < 0) return "";
  return `https://cdn.rebrickable.com/media/parts/ldraw/${lot.rebrickable_colour}/${encodeURIComponent(lot.rebrickable)}.png`;
}
