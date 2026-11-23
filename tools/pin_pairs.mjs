// The version pairs a pin is held to (partpins, docs/MASTERPLAN.md row 6's
// bar): on real models, a part pinned on one version, and the next made by
// each kind of edit a designer makes to that part (move, recolour, remove,
// add another beside, swap for another part), each pin then placed on the
// next version by the rule every page and the app keep (web/card.js
// pinPlace). Written as tests/fixtures/pins/pairs.json, which
// tests/test_partpins.py holds to the truth of each edit (never on a wrong
// part; a moved part's pin follows it) and src/dev/partpins_probe.gd to the
// app's port of the rule (src/net/pin_place.gd), case by case.
//
//   node tools/pin_pairs.mjs            write it
//   node tools/pin_pairs.mjs --check    exit 1 if it is not what this writes
//
// Each case: {name, kind, pin, bricks, want, truth}. [bricks] ({part, colour,
// at, turn}) are the next
// version's parts within 64 LDU of the pin (the rule reads none further
// off: PIN.near + PIN.slack, and a neighbour within PIN.near), [want] what
// pinPlace says of them, {index, moved} or null, and [truth] the part the
// edit left that the pin was made on ({index} into bricks), or null where
// the edit took it away (removed, recoloured, swapped).
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { placesOf } from "../api/_parts.js";
import { PIN, pinOf, pinPlace } from "../web/card.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "tests/fixtures/pins/pairs.json");
const MODELS = ["house", "castle", "lighthouse", "corner_shop", "orrery"];
const KINDS = ["move", "recolour", "remove", "beside", "swap"];
// Each kind on four parts of each of five models: 20 pairs a kind.
const EACH = 4;
const AROUND = 64;

// A small sure sequence, so the file is the same every time.
function random(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}
const apart = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

/// The file's lines, and which line each part placed once is on.
function linesOf(text) {
  return text.replace(/\r\n?/g, "\n").split("\n");
}

/// [lines] with line [at] (an index into them) changed by [edit].
function edited(lines, at, edit) {
  const out = [...lines];
  const words = out[at].trim().split(/\s+/);
  if (edit.kind === "move") {
    for (let k = 0; k < 3; k += 1) words[2 + k] = String(Number(words[2 + k]) + edit.by[k]);
    out[at] = words.join(" ");
  } else if (edit.kind === "recolour") {
    words[1] = String(edit.colour);
    out[at] = words.join(" ");
  } else if (edit.kind === "remove") {
    out.splice(at, 1);
  } else if (edit.kind === "beside") {
    const copy = [...words];
    for (let k = 0; k < 3; k += 1) copy[2 + k] = String(Number(copy[2 + k]) + edit.by[k]);
    out.splice(at + 1, 0, copy.join(" "));
  } else if (edit.kind === "swap") {
    words[14] = edit.part;
    out[at] = [...words.slice(0, 14), edit.part].join(" ");
  }
  return out;
}

/// The index into [lines] of the line placing [one] ({section, line}).
function indexOf(lines, one) {
  let section = "";
  let inSection = 0;
  for (let i = 0; i < lines.length; i += 1) {
    inSection += 1;
    const words = lines[i].trim().split(/\s+/);
    if (words[0] === "0" && /^FILE$/i.test(words[1] || "")) {
      section = lines[i].trim().replace(/^0\s+FILE\s+/i, "");
      inSection = 0;
    }
    if (section === one.section && inSection === one.line) return i;
  }
  return -1;
}

/// A step [rand] picks of [size] LDU along x or z, or a plate's along y.
function stepOf(rand, most) {
  const along = Math.floor(rand() * 3);
  const size = along === 1 ? 8 : [10, 20][Math.floor(rand() * 2)];
  const by = [0, 0, 0];
  by[along] = (rand() < 0.5 ? -1 : 1) * Math.min(size, most);
  return by;
}

export function pairs() {
  const cases = [];
  for (const [m, name] of MODELS.entries()) {
    const text = readFileSync(join(ROOT, "models", `${name}.ldr`), "utf8");
    const lines = linesOf(text);
    const places = placesOf(text);
    // Parts placed once (a part of a sub-model used twice is two places of
    // one line: an edit to its line moves both).
    const uses = new Map();
    for (const one of places) uses.set(`${one.section}\n${one.line}`, (uses.get(`${one.section}\n${one.line}`) || 0) + 1);
    const once = places.map((one, i) => i).filter((i) => uses.get(`${places[i].section}\n${places[i].line}`) === 1);
    const otherParts = [...new Set(places.map((one) => one.part))];
    for (const [k, kind] of KINDS.entries()) {
      const rand = random(1000 * m + 100 * k + 7);
      let made = 0;
      for (let tries = 0; made < EACH && tries < 400; tries += 1) {
        const index = once[Math.floor(rand() * once.length)];
        const one = places[index];
        const at = indexOf(lines, one);
        if (at < 0) continue;
        const pin = pinOf(places, index);
        let edit = { kind };
        if (kind === "move" || kind === "beside") {
          edit.by = stepOf(rand, PIN.reach);
          // Never onto a place another part stands: no two parts are in one place.
          const to = one.at.map((v, j) => v + edit.by[j]);
          if (places.some((other) => apart(other.at, to) <= PIN.slack)) continue;
        } else if (kind === "recolour") {
          edit.colour = one.colour === 4 ? 1 : 4;
        } else if (kind === "swap") {
          const others = otherParts.filter((part) => part !== one.part);
          if (!others.length) continue;
          edit.part = `${others[Math.floor(rand() * others.length)]}.dat`;
        }
        const next = edited(lines, at, edit).join("\n");
        const after = placesOf(next);
        // The part the pin was made on, where the edit left it.
        let truth = null;
        if (kind === "move" || kind === "beside") {
          truth = after.findIndex((b) => b.section === one.section && b.line === one.line);
          if (truth < 0) throw new Error(`${name}: the edited part is not where its line is`);
        }
        // What the rule reads: the next version's parts round the pin.
        const kept = after.map((b, i) => i).filter((i) => apart(after[i].at, pin.at) <= AROUND);
        const bricks = kept.map((i) => ({ part: after[i].part, colour: after[i].colour, at: after[i].at, turn: after[i].turn }));
        const want = pinPlace(pin, bricks);
        cases.push({ name: `${name} ${kind} ${made + 1}`, kind, pin, bricks, want,
          truth: truth === null ? null : { index: kept.indexOf(truth) } });
        made += 1;
      }
      if (made < EACH) throw new Error(`${name}: only ${made} ${kind} pairs`);
    }
  }
  return cases;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const said = `${JSON.stringify(pairs(), null, 0).replace(/\},\{"name"/g, '},\n{"name"')}\n`;
  if (process.argv.includes("--check")) {
    let was = "";
    try {
      was = readFileSync(OUT, "utf8");
    } catch {
      was = "";
    }
    if (was !== said) {
      console.error("pin_pairs: tests/fixtures/pins/pairs.json is not what tools/pin_pairs.mjs writes: run it");
      process.exit(1);
    }
    console.log("pin_pairs: up to date");
  } else {
    mkdirSync(dirname(OUT), { recursive: true });
    writeFileSync(OUT, said);
    console.log(`pin_pairs: ${said.split("\n").length - 1} pairs in tests/fixtures/pins/pairs.json`);
  }
}
