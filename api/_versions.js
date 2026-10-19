// What changed between two versions of a shared model, worked out from the
// two files (2026-10-18, supabase/versions.sql).
//
// Publishing a model again makes its next version and keeps the one before
// (api/share.js). What a version says about itself is read here from the
// model it replaced and the model it is, never typed: the parts added and
// taken away, by part and colour; the steps added, taken away or changed,
// by number; and the first step that is not as it was, which is what keeps
// a builder's place (src/assembly/build_steps.gd): somebody on step 5 of
// the old one is still right on the new one if nothing up to step 5 moved.
//
// The steps are the pages a builder turns, which the app works out when it
// shares a model and carries in its text (src/net/shared_pages.gd): a
// "0 !BRICKWORKS PAGES" line with the model's fingerprint, how many parts
// it puts down and in what order, and a "0 !BRICKWORKS PAGE" line a step
// naming which of those parts it adds. Here the file is put down as the app
// puts it down (LdrModel.flatten: the model, its sub-models placed in it,
// colour 16 taken from what places it), and that order checked against the
// one the steps were counted in — the same number of parts, the same part
// and colour at each — before a step is read as those parts. A file whose
// steps were not carried (an old link, a model past 1.9 MB, one written by
// hand) has its parts compared and not its steps, and says so.
//
// Everything here is pure: text in, facts out.

import { createHash } from "node:crypto";
import { COLOUR_NAMES } from "./_colours.js";

const HEAD = "0 !BRICKWORKS PAGES ";
const PAGE = "0 !BRICKWORKS PAGE ";
const PAGE_MARK = "0 !BRICKWORKS PAGE";
// How many lots of each and how many step numbers a version keeps: what
// a page says is short, and a row stays small whatever was done.
const MOST_LOTS = 40;
const MOST_STEPS = 400;

const sha256 = (text) => createHash("sha256").update(text, "utf8").digest("hex");
// What Godot's strip_edges takes off a line: control characters and spaces.
const strip = (text) => text.replace(/^[\u0000- ]+|[\u0000- ]+$/g, "");

/// The model's text as its carried steps are matched to it
/// (SharedPages.fingerprint): its lines trimmed, blank ones and the steps'
/// own lines left out.
export function fingerprint(text) {
  const kept = [];
  for (const line of String(text).split("\n")) {
    const trimmed = strip(line);
    if (trimmed === "" || trimmed.startsWith(PAGE_MARK)) continue;
    kept.push(trimmed);
  }
  return sha256(kept.join("\n"));
}

/// A file's name as a reference to it is looked up (LdrModel._key).
function keyOf(name) {
  let text = strip(String(name).replace(/\\/g, "/")).toLowerCase();
  text = text.slice(text.lastIndexOf("/") + 1);
  for (const suffix of [".ldr", ".dat", ".mpd"]) {
    if (text.endsWith(suffix)) return text.slice(0, -suffix.length);
  }
  return text;
}

/// A colour as LdrModel reads one: a number, or 0x2RRGGBB kept as the number
/// it is; null for one it cannot read.
function colourOf(token) {
  if (/^-?\d+$/.test(token)) return Number(token);
  if (/^0x2[0-9a-f]{6}$/i.test(token)) return parseInt(token.slice(2), 16);
  return null;
}

/// The file's sub-models and parts, as LdrModel.parse reads them: {main,
/// subs: Map(key -> placements)}, each placement {part, colour, m} with m
/// LDraw's twelve numbers.
function read(text) {
  const subs = new Map();
  const declared = new Map();
  let main = { key: "model", placements: [] };
  subs.set("model", main);
  let current = main;
  let first = true;
  let inData = false;
  let header = 0;
  for (const raw of String(text).replace(/^﻿/, "").split("\n")) {
    const line = strip(raw);
    if (inData) {
      if (line.startsWith("0 !:")) continue;
      inData = false;
    }
    if (line === "") continue;
    const tokens = line.split(/\s+/);
    if (tokens[0] === "0") {
      const keyword = (tokens[1] || "").toUpperCase();
      if (keyword === "!DATA") {
        inData = true;
      } else if (keyword === "FILE") {
        const key = keyOf(tokens.slice(2).join(" "));
        current = { key, placements: [] };
        subs.set(key, current);
        header = 0;
        if (first) {
          subs.delete("model");
          main = current;
          first = false;
        }
      } else if (keyword === "!LDRAW_ORG" && header < 16 && /part/i.test(line)) {
        declared.set(current.key, true);
      }
      header += 1;
      continue;
    }
    header += 1;
    if (tokens[0] !== "1" || tokens.length < 15) continue;
    const colour = colourOf(tokens[1]);
    const m = tokens.slice(2, 14).map(Number);
    if (colour === null || m.some((n) => !Number.isFinite(n))) continue;
    current.placements.push({ part: keyOf(tokens.slice(14).join(" ")), colour, m });
  }
  // A section that says it is a part is a part, not an assembly to open.
  for (const key of declared.keys()) if (key !== main.key) subs.delete(key);
  return { main, subs };
}

/// Two placements one inside the other: [x y z a b c d e f g h i].
function compose(outer, inner) {
  const [x, y, z, a, b, c, d, e, f, g, h, i] = outer;
  const [u, v, w, ...r] = inner;
  return [
    x + a * u + b * v + c * w, y + d * u + e * v + f * w, z + g * u + h * v + i * w,
    a * r[0] + b * r[3] + c * r[6], a * r[1] + b * r[4] + c * r[7], a * r[2] + b * r[5] + c * r[8],
    d * r[0] + e * r[3] + f * r[6], d * r[1] + e * r[4] + f * r[7], d * r[2] + e * r[5] + f * r[8],
    g * r[0] + h * r[3] + i * r[6], g * r[1] + h * r[4] + i * r[7], g * r[2] + h * r[5] + i * r[8],
  ];
}

const IDENTITY = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1];
const round = (n, places) => {
  const said = n.toFixed(places);
  return /^-0\.?0*$/.test(said) ? said.slice(1) : said;
};

/// Every part the file puts down, in the order the app puts them down
/// (LdrModel.flatten): [{part, colour, key}], key being the part, its
/// colour and where it stands, to the hundredth of an LDU.
export function partsOf(text) {
  const { main, subs } = read(text);
  const out = [];
  const visit = (sub, at, colour, depth, visiting) => {
    if (depth > 32 || visiting.has(sub.key)) return;
    visiting.add(sub.key);
    for (const one of sub.placements) {
      const placed = compose(at, one.m);
      const resolved = one.colour === 16 ? colour : one.colour;
      const nested = subs.get(one.part);
      if (nested && nested !== sub) {
        visit(nested, placed, resolved, depth + 1, new Set(visiting));
        continue;
      }
      out.push({ part: one.part, colour: resolved,
        key: `${one.part}:${resolved}@${placed.slice(0, 3).map((n) => round(n, 2)).join(",")}`
          + `/${placed.slice(3).map((n) => round(n, 4)).join(",")}` });
    }
    visiting.delete(sub.key);
  };
  visit(main, IDENTITY, 0, 0, new Set());
  return out;
}

/// The steps the file carries, each a list of the keys of the parts it
/// adds (partsOf), or null when it carries none or they are not for this
/// text and this order of its parts.
export function stepsOf(text, parts = partsOf(text)) {
  const at = String(text).indexOf(HEAD);
  if (at < 0) return null;
  const lines = String(text).slice(at).split("\n").map(strip);
  let head;
  try {
    head = JSON.parse(lines[0].slice(HEAD.length - 1).trim());
  } catch {
    return null;
  }
  if (!head || head.v !== 1 || head.model !== fingerprint(text)) return null;
  if (head.parts !== parts.length) return null;
  if (head.order !== sha256(parts.map((p) => `${p.part}:${p.colour}`).join("|"))) return null;
  const steps = [];
  for (const line of lines.slice(1)) {
    if (!line.startsWith(PAGE.trim())) continue;
    let said;
    try {
      said = JSON.parse(line.slice(PAGE.trim().length).trim());
    } catch {
      return null;
    }
    if (!said || !Array.isArray(said.b)) return null;
    const keys = [];
    for (const n of said.b) {
      if (!Number.isInteger(n) || n < 0 || n >= parts.length) return null;
      keys.push(parts[n].key);
    }
    steps.push(keys);
  }
  return steps.length === head.steps ? steps : null;
}

/// How many of each part in each colour: "part:colour" -> count.
function lots(keys) {
  const counted = new Map();
  for (const key of keys) {
    const lot = key.slice(0, key.indexOf("@"));
    counted.set(lot, (counted.get(lot) || 0) + 1);
  }
  return counted;
}

/// What [a] has more of than [b], as [{part, colour, count}], most first.
function more(a, b) {
  const out = [];
  for (const [lot, n] of a) {
    const extra = n - (b.get(lot) || 0);
    if (extra <= 0) continue;
    const cut = lot.lastIndexOf(":");
    out.push({ part: lot.slice(0, cut), colour: Number(lot.slice(cut + 1)), count: extra });
  }
  return out.sort((x, y) => y.count - x.count || x.part.localeCompare(y.part) || x.colour - y.colour);
}

const sameSteps = (a, b) => a.length === b.length && [...a].sort().join("\n") === [...b].sort().join("\n");

/// What changed from the model in [before] to the one in [after]:
///
///   added, removed   [{part, colour, count}]: by part and colour, over the
///                    whole model
///   added_in         the steps of the new one the added parts go in
///   removed_from     the steps of the old one the removed parts were in
///   steps_added      new steps past the old last one, by number
///   steps_removed    old steps past the new last one
///   steps_changed    steps both have that are not as they were
///   first            the first step that differs, or null for none
///   compared         whether the steps could be compared at all
///   parts, steps     the new one's counts
export function changesBetween(before, after) {
  const was = partsOf(before);
  const now = partsOf(after);
  const added = more(lots(now.map((p) => p.key)), lots(was.map((p) => p.key)));
  const removed = more(lots(was.map((p) => p.key)), lots(now.map((p) => p.key)));
  const oldSteps = stepsOf(before, was);
  const newSteps = stepsOf(after, now);
  const changes = {
    added: added.slice(0, MOST_LOTS), removed: removed.slice(0, MOST_LOTS),
    added_count: added.reduce((n, lot) => n + lot.count, 0),
    removed_count: removed.reduce((n, lot) => n + lot.count, 0),
    added_in: [], removed_from: [], steps_added: [], steps_removed: [], steps_changed: [],
    first: null, compared: Boolean(oldSteps && newSteps),
    parts: now.length, steps: newSteps ? newSteps.length : null,
  };
  if (!changes.compared) {
    // Nothing to say which step a change is in: from the first, to be safe,
    // unless nothing put down changed at all.
    const same = was.length === now.length && sameSteps(was.map((p) => p.key), now.map((p) => p.key));
    changes.first = same ? null : 1;
    return changes;
  }
  const isAdded = new Set(added.map((lot) => `${lot.part}:${lot.colour}`));
  const isRemoved = new Set(removed.map((lot) => `${lot.part}:${lot.colour}`));
  const both = Math.min(oldSteps.length, newSteps.length);
  for (let n = 0; n < Math.max(oldSteps.length, newSteps.length); n += 1) {
    const then = n < oldSteps.length ? oldSteps[n] : [];
    const thereNow = n < newSteps.length ? newSteps[n] : [];
    if (n < both && sameSteps(then, thereNow)) continue;
    if (changes.first === null) changes.first = n + 1;
    if (n >= oldSteps.length) changes.steps_added.push(n + 1);
    else if (n >= newSteps.length) changes.steps_removed.push(n + 1);
    else changes.steps_changed.push(n + 1);
    const gained = more(lots(thereNow), lots(then));
    const lost = more(lots(then), lots(thereNow));
    if (gained.some((lot) => isAdded.has(`${lot.part}:${lot.colour}`))) changes.added_in.push(n + 1);
    if (lost.some((lot) => isRemoved.has(`${lot.part}:${lot.colour}`))) changes.removed_from.push(n + 1);
  }
  for (const list of ["added_in", "removed_from", "steps_added", "steps_removed", "steps_changed"]) {
    changes[list] = changes[list].slice(0, MOST_STEPS);
  }
  return changes;
}

/// A version's changes as stored, read back at this edge: anything not of
/// the shape changesBetween makes is no changes at all.
export function readChanges(given) {
  if (!given || typeof given !== "object") return null;
  const numbers = (list) => (Array.isArray(list) ? list.filter((n) => Number.isInteger(n) && n > 0) : []);
  const lotsOf = (list) => (Array.isArray(list) ? list.filter((lot) => lot && typeof lot.part === "string"
    && Number.isInteger(lot.colour) && Number.isInteger(lot.count) && lot.count > 0) : []);
  return {
    added: lotsOf(given.added), removed: lotsOf(given.removed),
    added_count: Number.isInteger(given.added_count) ? given.added_count : 0,
    removed_count: Number.isInteger(given.removed_count) ? given.removed_count : 0,
    added_in: numbers(given.added_in), removed_from: numbers(given.removed_from),
    steps_added: numbers(given.steps_added), steps_removed: numbers(given.steps_removed),
    steps_changed: numbers(given.steps_changed),
    first: Number.isInteger(given.first) && given.first > 0 ? given.first : null,
    compared: given.compared === true,
    parts: Number.isInteger(given.parts) ? given.parts : null,
    steps: Number.isInteger(given.steps) ? given.steps : null,
  };
}

/// Step numbers said as a person says them: "step 3", "steps 12–13",
/// "steps 2, 5 and 9–11"; past four runs, how many more.
export function stepsSaid(numbers) {
  const sorted = [...new Set(numbers)].sort((a, b) => a - b);
  if (sorted.length === 0) return "";
  const runs = [];
  for (const n of sorted) {
    const last = runs[runs.length - 1];
    if (last && n === last[1] + 1) last[1] = n;
    else runs.push([n, n]);
  }
  const said = runs.slice(0, 4).map(([a, b]) => (a === b ? `${a}` : `${a}–${b}`));
  const rest = runs.slice(4).reduce((n, [a, b]) => n + b - a + 1, 0);
  if (rest > 0) said.push(`${rest} more`);
  const words = said.length === 1 ? said[0] : `${said.slice(0, -1).join(", ")} and ${said[said.length - 1]}`;
  return `${sorted.length === 1 ? "step" : "steps"} ${words}`;
}

const partsWord = (n) => `${n.toLocaleString("en-US")} part${n === 1 ? "" : "s"}`;
const sameList = (a, b) => a.length === b.length && a.every((n, k) => n === b[k]);

/// What a version says it changed, short: "Version 3: 4 parts added in
/// steps 12–13; step 7 changed." Version 1 says nothing.
export function saidOf(n, given) {
  const changes = readChanges(given);
  if (!(n > 1) || !changes) return "";
  const { added_count: plus, removed_count: minus, compared } = changes;
  const gone = new Set(changes.steps_removed);
  // Parts taken from a step that is itself gone are said by that step.
  const removedFrom = changes.removed_from.filter((k) => !gone.has(k));
  const where = (list, word) => (compared && list.length ? ` ${word} ${stepsSaid(list)}` : "");
  const clauses = [];
  if (plus && minus && sameList(changes.added_in, removedFrom)) {
    clauses.push(`${partsWord(plus)} added and ${minus.toLocaleString("en-US")} removed`
      + where(changes.added_in, "in"));
  } else {
    if (plus) clauses.push(`${partsWord(plus)} added${where(changes.added_in, "in")}`);
    if (minus) clauses.push(`${partsWord(minus)} removed${where(removedFrom, "from")}`);
  }
  if (compared) {
    const named = new Set([...changes.added_in, ...removedFrom]);
    const fresh = changes.steps_added.filter((k) => !named.has(k));
    const changed = changes.steps_changed.filter((k) => !named.has(k));
    if (fresh.length) clauses.push(`${stepsSaid(fresh)} added`);
    if (changes.steps_removed.length) clauses.push(`${stepsSaid(changes.steps_removed)} taken out`);
    if (changed.length) clauses.push(`${stepsSaid(changed)} changed`);
  } else if (changes.first !== null) {
    clauses.push("its steps could not be compared");
  }
  if (clauses.length === 0) return `Version ${n}: no parts or steps changed.`;
  return `Version ${n}: ${clauses.join("; ")}.`;
}

/// A lot as a page says it: "2 × 3001 in Red".
export function lotSaid(lot) {
  const colour = COLOUR_NAMES[lot.colour] || (lot.colour >= 0x2000000
    ? `#${(lot.colour & 0xffffff).toString(16).padStart(6, "0")}` : `colour ${lot.colour}`);
  return `${lot.count} × ${lot.part} in ${colour}`;
}
