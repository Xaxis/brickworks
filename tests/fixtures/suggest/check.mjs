// Each class of edit a remixer makes, made to real sets of the library, then
// taken whole and in part (api/_suggest.js; tests/test_suggest.py).
//
//   node tests/fixtures/suggest/check.mjs vendor/omr/files/6054-1.mpd ...
//
// For each set: the edits are made to its own lines (an edit knows the line
// it made), the remix is every edit at once, and what each subset of them
// gives is the set with only those made. Then the remix is compared with
// the set and taken: whole, each edit alone, and every change ticked one by
// one; each result is read again and held to the model it should be, part
// for part (part, colour, place, turn) and step for step, section by
// section. Prints one JSON line: {sets: {file: {...}}}.

import { readFileSync } from "node:fs";
import { basename } from "node:path";
import { mergeSuggestion, readFile, suggestionChanges } from "../../../api/_suggest.js";
import { MAIN_KEY } from "../../../api/_subfiles.js";

const round = (v, by) => Math.round(v * by) / by + 0;

/// A model as the parts each section places, step by step: {key: [sorted
/// "part|colour|x|y|z|a..i|step"]}, the sections the model's own places
/// (any depth), the model's own under MAIN_KEY whatever it is named.
export function modelOf(text) {
  const file = readFile(text);
  const out = {};
  const queue = [file.order[0]];
  const seen = new Set(queue);
  while (queue.length) {
    const key = queue.shift();
    const section = file.sections.get(key);
    out[key] = section.parts.map((p) => [p.key, p.colour, ...p.o.map((v) => round(v, 100)),
      ...p.b.map((v) => round(v, 1000)), p.step].join("|")).sort();
    for (const ref of section.refs) {
      if (file.sections.has(ref) && !seen.has(ref)) {
        seen.add(ref);
        queue.push(ref);
      }
    }
  }
  return out;
}

/// Two models (modelOf) the same, whatever order their sections are in.
const sorted = (model) => Object.fromEntries(Object.entries(model).sort(([x], [y]) => (x < y ? -1 : x > y ? 1 : 0)));
const same = (a, b) => JSON.stringify(sorted(a)) === JSON.stringify(sorted(b));

/// What differs between two models (modelOf), said briefly.
function difference(a, b) {
  const said = [];
  for (const key of new Set([...Object.keys(a), ...Object.keys(b)])) {
    const x = new Set(a[key] || []);
    const y = new Set(b[key] || []);
    const only = (p, q) => [...p].filter((one) => !q.has(one)).slice(0, 3);
    if (!same(a[key], b[key])) said.push({ section: key, got: only(x, y), want: only(y, x) });
  }
  return said.slice(0, 4);
}

// ---------------------------------------------------------------------------
// The edits, each to lines of the set as it is (their indexes never move:
// a line is taken out or has lines put after it, and joined at the end).

const PART = /^\s*1\s/;

function partLine(text) {
  const tokens = text.trim().split(/\s+/);
  return { tokens, ref: tokens.slice(14).join(" ") };
}

/// The lines of [text] with [edits] made: each edit {drop: [i], set: {i:
/// line}, after: {i: [lines]}}.
export function made(lines, edits) {
  const drop = new Set();
  const set = new Map();
  const after = new Map();
  for (const edit of edits) {
    for (const i of edit.drop || []) drop.add(i);
    for (const [i, line] of Object.entries(edit.set || {})) set.set(Number(i), line);
    for (const [i, more] of Object.entries(edit.after || {})) {
      if (!after.has(Number(i))) after.set(Number(i), []);
      after.get(Number(i)).push(...more);
    }
  }
  const out = [];
  if (after.has(-1)) out.push(...after.get(-1));
  lines.forEach((line, i) => {
    if (!drop.has(i)) out.push(set.has(i) ? set.get(i) : line);
    if (after.has(i)) out.push(...after.get(i));
  });
  return out.join("\n");
}

/// The edits one of each class, on [text]'s lines, none on a line another
/// uses: [{name, edit}]. Each line written in the file's own ends.
export function editsOf(text) {
  const file = readFile(text);
  const lines = file.lines;
  const cr = file.crlf ? "\r" : "";
  const used = new Set();
  // Parts, not sub-models, nor parts whose line carries bound metas: of the
  // section placed in the model that has the most of them (a set whose own
  // section places only its sub-models is edited in its biggest).
  const placed = new Set(Object.keys(modelOf(text)));
  // And each the only one of its part in its colour in its section, so the
  // change it makes is said of it and of no twin of it.
  const plainOf = (s) => {
    const twins = new Map();
    for (const p of s.parts) twins.set(`${p.key}|${p.colour}`, (twins.get(`${p.key}|${p.colour}`) || 0) + 1);
    return s.parts.filter((p) => !file.sections.has(p.key) && p.bound.length === 0 && twins.get(`${p.key}|${p.colour}`) === 1);
  };
  const main = file.order.map((key) => file.sections.get(key)).filter((s) => placed.has(s.key))
    .sort((x, y) => plainOf(y).length - plainOf(x).length || file.order.indexOf(x.key) - file.order.indexOf(y.key))[0];
  const plain = plainOf(main);
  const steps = main.steps.length;
  const middle = Math.floor(steps / 2);
  const pick = (want) => {
    const found = plain.find((p) => !used.has(p.i) && want(p));
    if (found) used.add(found.i);
    return found;
  };
  const near = (p) => Math.abs(p.step - middle);
  plain.sort((x, y) => near(x) - near(y) || x.i - y.i);
  const edits = [];
  // A part put in, or swapped in, is one the section has none of, so it is
  // never taken for one of its own moved there.
  const fresh = ["3001.dat", "3003.dat", "3005.dat", "3009.dat", "3010.dat", "3622.dat", "3008.dat", "3007.dat",
    "3004.dat", "3006.dat", "3002.dat", "2357.dat", "3754.dat", "2465.dat", "3027.dat", "3029.dat", "3958.dat",
    "6215.dat", "4201.dat", "4202.dat", "3033.dat", "3031.dat", "3030.dat", "3032.dat", "3036.dat", "41539.dat"]
    .filter((ref) => !main.refs.has(ref));
  const swapped = () => fresh[0];
  const line = (p, tokens) => tokens.join(" ") + cr;
  const at = (p) => partLine(lines[p.i]).tokens;
  // Added: a 2 x 4 brick far off, after a part of the middle step.
  const host = pick(() => true);
  if (host) {
    edits.push({ name: "add", kind: "added",
      edit: { after: { [host.i]: [`1 14 ${9000 + host.i} -24 ${9000 - host.i} 1 0 0 0 1 0 0 0 1 ${fresh[1]}${cr}`] } } });
  }
  const gone = pick(() => true);
  if (gone) edits.push({ name: "remove", kind: "removed", edit: { drop: [gone.i] } });
  const moved = pick(() => true);
  if (moved) {
    const tokens = at(moved);
    tokens[2] = String(Number(tokens[2]) + 40);
    edits.push({ name: "move", kind: "moved", edit: { set: { [moved.i]: line(moved, tokens) } } });
  }
  const painted = pick(() => true);
  if (painted) {
    const tokens = at(painted);
    tokens[1] = tokens[1] === "4" ? "1" : "4";
    edits.push({ name: "recolour", kind: "recoloured", edit: { set: { [painted.i]: line(painted, tokens) } } });
  }
  const swap = pick(() => true);
  if (swap) {
    const tokens = at(swap);
    const ref = swapped();
    edits.push({ name: "swap", kind: "swapped", edit: { set: { [swap.i]: line(swap, [...tokens.slice(0, 14), ref]) } } });
  }
  // Another step: a part of a step that has a next one, put at that one's end.
  if (steps > 2) {
    const later = pick((p) => p.step < steps - 2 && main.steps[p.step + 1].end >= 0);
    if (later) {
      const end = main.steps[later.step + 1].end;
      edits.push({ name: "step", kind: "restepped", edit: { drop: [later.i], after: { [end - 1]: [lines[later.i]] } } });
    }
    // A step of its own, put in after the middle step, with a part in it.
    const stepEnd = main.steps[middle].end;
    if (stepEnd >= 0) {
      edits.push({ name: "new_step", kind: "added",
        edit: { after: { [stepEnd]: [`1 2 ${7000 + stepEnd} -48 0 1 0 0 0 1 0 0 0 1 ${fresh[2]}${cr}`, `0 STEP${cr}`] } } });
    }
  }
  // Inside a sub-model: one of its parts moved.
  const sub = file.order.slice(1).map((key) => file.sections.get(key))
    .find((s) => s !== main && placed.has(s.key) && plainOf(s).length > 0);
  if (sub) {
    const p = plainOf(sub)[0];
    const tokens = partLine(lines[p.i]).tokens;
    tokens[4] = String(Number(tokens[4]) - 20);
    used.add(p.i);
    edits.push({ name: "in_sub_model", kind: "moved", edit: { set: { [p.i]: tokens.join(" ") + cr } } });
  }
  // A sub-model of its own, placed in the model's own section.
  const anchor = pick(() => true);
  if (anchor) {
    const last = lines.length - 1 - [...lines].reverse().findIndex((one) => one.trim() !== "");
    const head = file.files ? [] : null;
    const section = [`0 FILE suggest wing.ldr${cr}`, `0 A wing${cr}`, `1 15 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat${cr}`,
      `1 15 0 -8 0 1 0 0 0 1 0 0 0 1 3022.dat${cr}`, `0 NOFILE${cr}`];
    if (head) {
      edits.push({ name: "sub_model", kind: "added", edit: {
        after: { [anchor.i]: [`1 16 ${5000 + anchor.i} -100 0 1 0 0 0 1 0 0 0 1 suggest wing.ldr${cr}`], [last]: section } } });
    }
  }
  return { edits, lines };
}

/// The ids of the changes [made] alone accounts for: those of its kind on
/// the lines it touched, on either side.
function idsFor(changes, edit, before, after) {
  return changes.filter((change) => change.kind === edit.kind && touches(change, edit, before, after)).map((c) => c.id);
}

function touches(change, edit, beforeLines, afterText) {
  const mineLines = new Set([...(edit.edit.drop || []), ...Object.keys(edit.edit.set || {}).map(Number)]);
  if (change.was && mineLines.has(change.was.line - 1)) return true;
  if (change.now) {
    const text = afterText[change.now.line - 1].replace(/\r$/, "");
    const added = [...Object.values(edit.edit.after || {}).flat(), ...Object.values(edit.edit.set || {})].map((l) => l.replace(/\r$/, ""));
    if (added.includes(text) && change.kind !== "restepped") return true;
    if (change.kind === "restepped" && (edit.edit.drop || []).some((i) => beforeLines[i].replace(/\r$/, "") === text)) return true;
  }
  return false;
}

/// Each set's edits made, compared and taken: {sets: {file: {...}}}.
export function checkSets(paths) {
const report = { sets: {} };
for (const path of paths) {
  const mine = readFileSync(path, "utf8");
  const { edits, lines } = editsOf(mine);
  const theirs = made(lines, edits.map((one) => one.edit));
  const theirsLines = theirs.split("\n");
  const said = suggestionChanges(mine, theirs);
  const want = modelOf(theirs);
  const result = { edits: edits.map((one) => one.name), counts: said.counts, listed: said.changes.length, faults: [] };
  const fault = (what, detail) => result.faults.push({ what, ...detail });
  // Each edit is the one change of its kind it makes.
  const kinds = {};
  for (const one of edits) kinds[one.kind] = (kinds[one.kind] || 0) + 1;
  for (const [kind, n] of Object.entries(said.counts)) if ((kinds[kind] || 0) !== n) fault("count", { kind, got: n, want: kinds[kind] || 0 });
  // Nothing taken: the designer's file, byte for byte.
  if (mergeSuggestion(mine, theirs, []).text !== mine) fault("nothing taken changed the file", {});
  // Whole.
  const whole = mergeSuggestion(mine, theirs, "all");
  if (!same(modelOf(whole.text), want)) fault("whole", { diff: difference(modelOf(whole.text), want) });
  if (suggestionChanges(whole.text, theirs).changes.length) fault("whole leaves changes", { left: suggestionChanges(whole.text, theirs).counts });
  // Every change ticked, as the list has them, is the whole.
  const ticked = mergeSuggestion(mine, theirs, said.changes.map((c) => c.id));
  if (!same(modelOf(ticked.text), want)) fault("every change ticked", { diff: difference(modelOf(ticked.text), want) });
  // Each edit alone.
  result.alone = {};
  for (const one of edits) {
    const ids = idsFor(said.changes, one, lines, theirsLines);
    const got = mergeSuggestion(mine, theirs, ids);
    const expected = modelOf(made(lines, [one.edit]));
    const ok = ids.length > 0 && same(modelOf(got.text), expected);
    result.alone[one.name] = { ids: ids.length, ok };
    if (!ok) fault(`${one.name} alone`, { ids, diff: difference(modelOf(got.text), expected) });
  }
  // All but each edit: the rest taken, that one left.
  result.but = {};
  for (const one of edits) {
    const ids = said.changes.map((c) => c.id).filter((id) => !idsFor(said.changes, one, lines, theirsLines).includes(id));
    const got = mergeSuggestion(mine, theirs, ids);
    const expected = modelOf(made(lines, edits.filter((other) => other !== one).map((other) => other.edit)));
    const ok = same(modelOf(got.text), expected);
    result.but[one.name] = ok;
    if (!ok) fault(`all but ${one.name}`, { diff: difference(modelOf(got.text), expected) });
  }
  report.sets[basename(path)] = result;
}
return report;
}

if (import.meta.url === new URL(`file://${process.argv[1]}`).href) console.log(JSON.stringify(checkSets(process.argv.slice(2))));
