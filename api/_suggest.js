// A suggested edit (suggestedit, 2026-11-23; docs/PLAN.md row 5): a
// remixer sends their change back, and the designer takes all of it or
// part, in the studio, as a pull request is taken.
//
// What changed is said by the file, not by the parts it draws: a model's
// sub-models are its own sections, a step is where its lines stand, and a
// designer takes a change into their own file with every line of theirs
// that it does not touch kept as they wrote it (their comments, their
// LPub metas, their header). So both files are read here a section at a
// time (FILE to NOFILE, or the one file), each section's part lines
// matched in that section's own coordinates by the rules the app's
// Compare matches a model by (src/parts/model_diff.gd, and
// api/_remix_changes.js on the site), one more for a part swapped for
// another where it stood, and each line's step read against an alignment
// of the two files' steps:
//
//   1. the same part in the same colour, under NEAR LDU from where it was
//      and turned the same way, is unchanged;
//   2. of the rest, the same part where one stood, turned the same way, in
//      another colour, was recoloured;
//   3. of the rest, the same part in the same colour anywhere else was
//      moved or turned, as many as there are of it on both sides, each
//      paired with the nearest;
//   4. of the rest, another part where one stood was swapped for it;
//   5. what is left was added, or taken away.
//
// The steps of the two sections are aligned as two sequences are, each
// pair of steps weighed by how many matched lines stand in both: so a step
// put in the middle moves no part, and a part matched in a step other than
// the one its step is aligned with was moved to another step (restepped).
// A sub-model only the remix has comes with the first line taken that
// places it; one only the designer's has goes once nothing places it.
//
// Taking ([mergeSuggestion]) is that list applied to the designer's lines:
// a line taken away goes with the metas bound to it, a line changed is the
// remix's line in its place, a line added goes into its step after the
// last of that step's lines in the same bracket (an LPub callout, a LeoCAD
// group, a copy built in the step) or at the step's end, and a step only
// the remix has is put in where it stands among the aligned ones. Taking
// every change gives the remix's model, part for part and step for step
// (tests/test_suggest.py, on real sets of the library). Pure.

import { afterFields, keyOf, MAIN_KEY, sectionKey } from "./_subfiles.js";

/// A part this near where it was, LDU, has not moved (ModelDiff.NEAR).
export const NEAR = 0.5;
/// ...and turned the same way when no axis of it is further than this off.
export const SAME_TURN = 0.01;
/// Moved parts of one part and colour are paired nearest first while there
/// are no more pairs than this to weigh; past it, in order along the model.
export const PAIRS_WEIGHED = 40000;
/// The kinds of change, in the order they are said.
export const KINDS = ["added", "removed", "moved", "recoloured", "swapped", "restepped"];
/// The most changes a suggestion lists: a remix that changed more is taken
/// whole or not at all.
export const MOST_LISTED = 5000;
/// The most places a sub-model's change is framed at.
const MOST_PLACES = 16;

const NUMBER = /^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/;
/// Metas that say something of the part line after them, and go with it.
const BOUND = /^0\s+(!BRICKWORKS\s+COPY\b|MLCAD\s+BTG\b|!LEOCAD\s+PIECE\b)/i;
const SPACE = /\s+/;

const roundAway = (v) => (v < 0 ? -Math.round(-v) : Math.round(v));
const cellOf = (o) => [roundAway(o[0]), roundAway(o[1]), roundAway(o[2])];
const distance2 = (p, q) => (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2;

/// Whether two turns are the same: each axis (a column) within SAME_TURN.
function sameTurn(a, b) {
  for (let c = 0; c < 3; c += 1) {
    if (Math.hypot(a[c] - b[c], a[3 + c] - b[3 + c], a[6 + c] - b[6 + c]) > SAME_TURN) return false;
  }
  return true;
}

/// A colour token as a number where it is one, else as written.
function colourOf(token) {
  if (/^[+-]?\d+$/.test(token)) return Number(token);
  if (/^0x2[0-9a-f]{6}$/i.test(token)) return parseInt(token.slice(2), 16);
  return token;
}

/// The bracket a meta line opens or closes, by its words before BEGIN or
/// END ("!LPUB CALLOUT", "MLCAD SKIP", "!LEOCAD GROUP"): {open, key}, or null.
function bracketOf(tokens) {
  if (tokens.length < 3) return null;
  const upper = tokens.map((t) => t.toUpperCase());
  for (let k = 2; k < upper.length; k += 1) {
    const word = upper[k];
    const begin = word === "BEGIN" || word.endsWith("_BEGIN");
    const end = word === "END" || word.endsWith("_END");
    if (!begin && !end) continue;
    const stem = word.replace(/_?(BEGIN|END)$/, "");
    const key = [upper[1], ...upper.slice(2, k), stem].filter(Boolean).join(" ");
    return { open: begin, key };
  }
  // An MLCad SKIP is said in one word after MLCAD.
  if (upper[1] === "MLCAD" && /_(BEGIN|END)$/.test(upper[2] || "")) {
    return { open: upper[2].endsWith("_BEGIN"), key: `MLCAD ${upper[2].replace(/_(BEGIN|END)$/, "")}` };
  }
  return null;
}

/// [text] as its lines and its sections: {bom, crlf, lines, sections: Map
/// key -> section, order: [keys], preamble}, each section {key, name, from
/// (its FILE line, or 0), to (past its last line), end (where a line put at
/// its end goes: before its NOFILE and the blank lines before it), parts,
/// steps: [{end}], refs: Set of the keys its lines place}. Each part {i (its
/// line), step, ctx (the brackets open at it, and the copy it is built in),
/// key (what it places, keyOf), colour, o, b, bound: [lines of the metas
/// bound to it]}.
export function readFile(text) {
  let raw = String(text ?? "");
  const bom = raw.startsWith("﻿");
  if (bom) raw = raw.slice(1);
  const lines = raw.split("\n");
  const crlf = lines.filter((line) => line.endsWith("\r")).length * 2 > lines.length;
  const starts = [];
  for (let i = 0; i < lines.length; i += 1) {
    const tokens = lines[i].trim().split(SPACE);
    if (tokens[0] === "0" && tokens.length >= 2 && /^(FILE|NOFILE|!DATA)$/i.test(tokens[1])) {
      starts.push({ i, word: tokens[1].toUpperCase() });
    }
  }
  const sections = new Map();
  const order = [];
  const blocks = new Map();
  const spans = [];
  if (!starts.some((one) => one.word === "FILE")) {
    spans.push({ key: MAIN_KEY, name: "", from: 0, to: lines.length, first: 0 });
  } else {
    for (let s = 0; s < starts.length; s += 1) {
      const { i, word } = starts[s];
      if (word !== "FILE") continue;
      const next = starts.slice(s + 1).find(() => true);
      const to = next ? (next.word === "NOFILE" ? next.i + 1 : next.i) : lines.length;
      const name = afterFields(lines[i], 2);
      spans.push({ key: sectionKey(name, blocks), name, from: i, to, first: i + 1 });
    }
  }
  for (const span of spans) {
    const section = { key: span.key, name: span.name, from: span.from, to: span.to, end: span.to,
      parts: [], steps: [], refs: new Set() };
    // A line put at its end goes before its NOFILE and the blank lines
    // before that, so the section stays one block.
    let end = span.to;
    if (end > span.first && /^0\s+NOFILE\b/i.test(lines[end - 1].trim())) end -= 1;
    while (end > span.first && lines[end - 1].trim() === "") end -= 1;
    section.end = end;
    let step = 0;
    const stack = [];
    let within = "";
    const ctxNow = () => `${stack.join("/")}|${within}`;
    for (let i = span.first; i < span.to; i += 1) {
      const line = lines[i].trim();
      if (line === "") continue;
      const tokens = line.split(SPACE);
      if (tokens[0] === "0") {
        if (tokens.length < 2) continue;
        const word = tokens[1].toUpperCase();
        if (word === "STEP" || word === "ROTSTEP") {
          section.steps.push({ end: i, ctx: ctxNow() });
          step += 1;
          within = "";
          continue;
        }
        if (word === "!BRICKWORKS" && (tokens[2] || "").toUpperCase() === "IN") {
          within = tokens.slice(3).join(" ");
          continue;
        }
        const bracket = bracketOf(tokens);
        if (bracket?.open) stack.push(bracket.key);
        else if (bracket) {
          const at = stack.lastIndexOf(bracket.key);
          if (at >= 0) stack.splice(at, 1);
        }
        continue;
      }
      if (tokens[0] !== "1" || tokens.length < 15) continue;
      if (!tokens.slice(2, 14).every((t) => NUMBER.test(t))) continue;
      const numbers = tokens.slice(2, 14).map(Number);
      const key = keyOf(afterFields(lines[i], 14));
      const bound = [];
      for (let j = i - 1; j >= span.first && BOUND.test(lines[j].trim()); j -= 1) bound.unshift(j);
      section.parts.push({ i, step, ctx: ctxNow(), key, colour: colourOf(tokens[1]),
        o: numbers.slice(0, 3), b: numbers.slice(3, 12), bound });
      section.refs.add(key);
    }
    // The last step, ended by the section's end rather than a STEP line.
    section.steps.push({ end: -1, ctx: ctxNow() });
    sections.set(section.key, section);
    order.push(section.key);
  }
  return { bom, crlf, lines, sections, order, files: starts.some((one) => one.word === "FILE") };
}

// ---------------------------------------------------------------------------
// Matching one section's lines with the other's.

const keyed = (part, cell, sameColour) => (sameColour ? `${part.key}|${part.colour}|${cell.join("|")}` : `${part.key}|${cell.join("|")}`);

function findIn(at, key, was, part, sameColour) {
  for (const n of at.get(key) || []) {
    const other = was[n];
    if (!other) continue;
    if ((other.colour === part.colour) !== sameColour) continue;
    if (Math.sqrt(distance2(other.o, part.o)) < NEAR && sameTurn(other.b, part.b)) return n;
  }
  return -1;
}

function pairInPlace(was, now, sameColour) {
  const at = new Map();
  was.forEach((part, n) => {
    if (!part) return;
    const key = keyed(part, cellOf(part.o), sameColour);
    if (!at.has(key)) at.set(key, []);
    at.get(key).push(n);
  });
  const pairs = [];
  now.forEach((part, m) => {
    if (!part) return;
    const cell = cellOf(part.o);
    let found = findIn(at, keyed(part, cell, sameColour), was, part, sameColour);
    for (let d = 0; found < 0 && d < 27; d += 1) {
      if (d === 13) continue;
      const near = [cell[0] + (d % 3) - 1, cell[1] + (Math.floor(d / 3) % 3) - 1, cell[2] + Math.floor(d / 9) - 1];
      found = findIn(at, keyed(part, near, sameColour), was, part, sameColour);
    }
    if (found >= 0) {
      pairs.push([was[found], part]);
      was[found] = null;
      now[m] = null;
    }
  });
  return pairs;
}

function along(parts, of) {
  return of.map((n) => [parts[n].o[0], parts[n].o[2], parts[n].o[1], n])
    .sort((a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2] || a[3] - b[3]).map((one) => one[3]);
}

/// Of what is left, pairs whose [group] key is the same, nearest first; past
/// PAIRS_WEIGHED, in order along the model. [within] limits a pair's
/// distance (Infinity for none).
function pairNearest(was, now, group, within = Infinity) {
  const groups = new Map();
  was.forEach((part, n) => {
    if (!part) return;
    const key = group(part);
    if (!groups.has(key)) groups.set(key, [[], []]);
    groups.get(key)[0].push(n);
  });
  now.forEach((part, m) => {
    if (!part) return;
    const found = groups.get(group(part));
    if (found) found[1].push(m);
  });
  const out = [];
  for (const [olds, news] of groups.values()) {
    if (olds.length === 0 || news.length === 0) continue;
    if (olds.length * news.length <= PAIRS_WEIGHED) {
      const weighed = [];
      for (const n of olds) {
        for (const m of news) {
          const d = distance2(was[n].o, now[m].o);
          if (d < within * within) weighed.push([d, n, m]);
        }
      }
      weighed.sort((a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2]);
      for (const [, n, m] of weighed) {
        if (was[n] && now[m]) {
          out.push([was[n], now[m]]);
          was[n] = null;
          now[m] = null;
        }
      }
    } else if (within === Infinity) {
      const oldsAlong = along(was, olds);
      const newsAlong = along(now, news);
      for (let k = 0; k < Math.min(oldsAlong.length, newsAlong.length); k += 1) {
        out.push([was[oldsAlong[k]], now[newsAlong[k]]]);
        was[oldsAlong[k]] = null;
        now[newsAlong[k]] = null;
      }
    }
  }
  return out;
}

/// The two sections' steps aligned, as two sequences are: [weights] counts
/// the matched lines of each pair of steps ("mine|theirs" -> n). The most
/// matched lines first, and of the alignings that match as many, the one
/// that aligns the most steps: so a step emptied in one (its parts taken
/// away, or moved to the next) is still the same step as the other's, and
/// the steps after it keep their numbers, while a step put in among them
/// with only new parts in it is aligned with none. Returns {mine: theirs
/// step -> mine step, theirs: mine step -> theirs step}.
function alignSteps(mineSteps, theirsSteps, weights) {
  const rows = mineSteps + 1;
  const cols = theirsSteps + 1;
  // A matched line outweighs every step aligned: each pair of steps aligned
  // counts 1, each line matched in it K.
  const K = Math.min(mineSteps, theirsSteps) + 1;
  const gain = (i, j) => (weights.get(`${i}|${j}`) || 0) * K + 1;
  const score = new Float64Array(rows * cols);
  for (let i = 1; i < rows; i += 1) {
    for (let j = 1; j < cols; j += 1) {
      score[i * cols + j] = Math.max(score[(i - 1) * cols + j - 1] + gain(i - 1, j - 1),
        score[(i - 1) * cols + j], score[i * cols + j - 1]);
    }
  }
  const mine = new Map();
  const theirs = new Map();
  let i = mineSteps;
  let j = theirsSteps;
  while (i > 0 && j > 0) {
    const here = score[i * cols + j];
    if (here === score[(i - 1) * cols + j - 1] + gain(i - 1, j - 1)) {
      mine.set(j - 1, i - 1);
      theirs.set(i - 1, j - 1);
      i -= 1;
      j -= 1;
    } else if (here === score[(i - 1) * cols + j]) {
      i -= 1;
    } else {
      j -= 1;
    }
  }
  return { mine, theirs };
}

/// What changed in one section, [a] the designer's and [b] the remix's
/// (either null for a section only the other has): {pairs, changes, align}.
function sectionChanges(a, b) {
  const was = (a?.parts || []).slice();
  const now = (b?.parts || []).slice();
  const changes = [];
  const pairs = [];
  for (const [x, y] of pairInPlace(was, now, true)) pairs.push({ kind: "", was: x, now: y });
  for (const [x, y] of pairInPlace(was, now, false)) pairs.push({ kind: "recoloured", was: x, now: y });
  for (const [x, y] of pairNearest(was, now, (part) => `${part.key}|${part.colour}`)) {
    pairs.push({ kind: "moved", was: x, now: y, turned: !sameTurn(x.b, y.b) });
  }
  for (const [x, y] of pairNearest(was, now, () => "", NEAR)) pairs.push({ kind: "swapped", was: x, now: y });
  const weights = new Map();
  for (const pair of pairs) {
    const key = `${pair.was.step}|${pair.now.step}`;
    weights.set(key, (weights.get(key) || 0) + 1);
  }
  const align = alignSteps(a ? a.steps.length : 0, b ? b.steps.length : 0, weights);
  for (const pair of pairs) {
    const restepped = align.theirs.get(pair.was.step) !== pair.now.step;
    if (!pair.kind && !restepped) continue;
    changes.push({ kind: pair.kind || "restepped", was: pair.was, now: pair.now, restepped, turned: pair.turned === true });
  }
  for (const part of now) if (part) changes.push({ kind: "added", was: null, now: part, restepped: false, turned: false });
  for (const part of was) if (part) changes.push({ kind: "removed", was: part, now: null, restepped: false, turned: false });
  return { changes, align };
}

// ---------------------------------------------------------------------------
// Where each section stands in the model, for the studio to frame a change.

const IDENTITY = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1];

function compose(p, c) {
  const [x, y, z, a, b, cc, d, e, f, g, h, k] = p;
  const [cx, cy, cz, ca, cb, c3, cd, ce, cf, cg, ch, ck] = c;
  return [
    a * cx + b * cy + cc * cz + x, d * cx + e * cy + f * cz + y, g * cx + h * cy + k * cz + z,
    a * ca + b * cd + cc * cg, a * cb + b * ce + cc * ch, a * c3 + b * cf + cc * ck,
    d * ca + e * cd + f * cg, d * cb + e * ce + f * ch, d * c3 + e * cf + f * ck,
    g * ca + h * cd + k * cg, g * cb + h * ce + k * ch, g * c3 + h * cf + k * ck,
  ];
}

/// Each section's places in the model, from its own section: key -> [m],
/// at most MOST_PLACES each.
function placesOf(file) {
  const places = new Map([[file.order[0], [IDENTITY]]]);
  const queue = [file.order[0]];
  for (let n = 0; n < queue.length && n < 4096; n += 1) {
    const key = queue[n];
    const section = file.sections.get(key);
    for (const at of places.get(key)) {
      for (const part of section.parts) {
        if (!file.sections.has(part.key) || part.key === key) continue;
        const list = places.get(part.key) || [];
        if (list.length >= MOST_PLACES) continue;
        if (!places.has(part.key)) {
          places.set(part.key, list);
          queue.push(part.key);
        }
        list.push(compose(at, [...part.o, ...part.b]));
      }
    }
  }
  return places;
}

/// Where a part line stands in the model, in the app's axes (+Y up), at
/// each of its section's places.
function standsAt(part, places) {
  return (places || []).map((m) => {
    const p = compose(m, [...part.o, ...part.b]);
    return [p[0], -p[1], -p[2]].map((v) => Math.round(v * 100) / 100);
  });
}

// ---------------------------------------------------------------------------
// The list.

/// The id a change goes by: its kind, its section and its lines on either
/// side, the same each time the two files are compared.
const idOf = (kind, key, was, now) => `${kind}:${key === MAIN_KEY ? "" : key}:${was ? was.i + 1 : ""}:${now ? now.i + 1 : ""}`;

/// Each sub-model only [theirs] has that [key]'s placing brings, with those
/// it places in turn: [keys], in the remix's order.
function bringsOf(key, mine, theirs) {
  const out = [];
  const seen = new Set();
  const visit = (k) => {
    if (seen.has(k) || mine.sections.has(k) || !theirs.sections.has(k)) return;
    seen.add(k);
    out.push(k);
    for (const ref of theirs.sections.get(k).refs) visit(ref);
  };
  visit(key);
  return out.sort((x, y) => theirs.order.indexOf(x) - theirs.order.indexOf(y));
}

/// Every section, the designer's and the remix's matched by name (the
/// model's own with the model's own, whatever each is named): [{key, a, b}],
/// the remix's sections only it has that something places among them.
function sectionsOf(mine, theirs) {
  const out = [];
  const mainA = mine.sections.get(mine.order[0]);
  const mainB = theirs.sections.get(theirs.order[0]);
  out.push({ key: MAIN_KEY, a: mainA, b: mainB });
  for (const key of mine.order.slice(1)) out.push({ key, a: mine.sections.get(key), b: theirs.sections.get(key) || null });
  for (const key of theirs.order.slice(1)) if (!mine.sections.has(key)) out.push({ key, a: null, b: theirs.sections.get(key) });
  return out;
}

/// What the remix [theirs] changed from the designer's [mine] (both texts),
/// as the studio lists it: {changes: [{id, kind, section (a sub-model's
/// name, "" for the model's own), part, colour, was: {line, step, at}, now:
/// {line, step, at}, restepped, turned, brings: [sub-model names]}], counts:
/// {added, removed, moved, recoloured, swapped, restepped}, sections:
/// {added: [names], removed: [names]}, listed: whether every change is
/// listed (past MOST_LISTED only the counts are)}. A step is said from 1.
export function suggestionChanges(mineText, theirsText) {
  return listed(readFile(mineText), readFile(theirsText)).said;
}

function listed(mine, theirs) {
  const placesA = placesOf(mine);
  const placesB = placesOf(theirs);
  const all = [];
  const aligns = new Map();
  for (const { key, a, b } of sectionsOf(mine, theirs)) {
    // A sub-model only one side has: what it holds is not a change of its
    // own, but comes or goes with what places it.
    if (!a || !b) continue;
    const { changes, align } = sectionChanges(a, b);
    aligns.set(key, align);
    for (const change of changes) all.push({ key, ...change });
  }
  const counts = Object.fromEntries(KINDS.map((kind) => [kind, 0]));
  for (const change of all) counts[change.kind] += 1;
  const order = (change) => (change.now || change.was).i;
  all.sort((x, y) => KINDS.indexOf(x.kind) - KINDS.indexOf(y.kind) || (x.key === y.key ? 0 : x.key < y.key ? -1 : 1)
    || order(x) - order(y));
  const name = (key, file) => (key === MAIN_KEY ? "" : file.sections.get(key)?.name || key);
  const side = (part, places) => (part ? { line: part.i + 1, step: part.step + 1, at: standsAt(part, places) } : null);
  const changes = all.length > MOST_LISTED ? [] : all.map((change) => {
    const part = change.now || change.was;
    const brings = change.now ? bringsOf(change.now.key, mine, theirs) : [];
    return { id: idOf(change.kind, change.key, change.was, change.now), kind: change.kind,
      section: name(change.key, change.b ? theirs : mine) || name(change.key, mine) || name(change.key, theirs),
      part: part.key.replace(/\.(dat|ldr|mpd)$/, ""), colour: part.colour,
      was: side(change.was, placesA.get(change.key)), now: side(change.now, placesB.get(change.key)),
      ...(change.was && change.now && change.was.colour !== change.now.colour ? { from_colour: change.was.colour } : {}),
      ...(change.kind === "swapped" ? { from_part: change.was.key.replace(/\.(dat|ldr|mpd)$/, "") } : {}),
      restepped: change.restepped, turned: change.turned, brings: brings.map((k) => theirs.sections.get(k).name) };
  });
  const sections = {
    added: theirs.order.slice(1).filter((key) => !mine.sections.has(key)).map((key) => theirs.sections.get(key).name),
    removed: mine.order.slice(1).filter((key) => !theirs.sections.has(key)).map((key) => mine.sections.get(key).name),
  };
  return { all, aligns, said: { changes, counts, sections, listed: all.length <= MOST_LISTED, total: all.length } };
}

// ---------------------------------------------------------------------------
// Taking it.

/// Where a line the remix has in its step [j] of section [key] goes in the
/// designer's: {before: line index, newStep: null} into an aligned step, or
/// {after: the step it follows, newStep: j} for a step only the remix has.
function placeFor(part, a, align) {
  const i = align.mine.get(part.step);
  if (i !== undefined) {
    // After the last of the step's lines in the same brackets; else at the
    // step's end, where that is in the same brackets; else before the
    // step's first line in none; else at its end.
    const inStep = a.parts.filter((p) => p.step === i);
    const same = inStep.filter((p) => p.ctx === part.ctx).slice(-1)[0];
    if (same) return { before: same.i + 1, newStep: null };
    if (a.steps[i].ctx === part.ctx) return { before: stepEnd(a, i), newStep: null };
    const bare = inStep.find((p) => p.ctx === "|");
    if (part.ctx === "|" && bare) return { before: bare.bound.length ? bare.bound[0] : bare.i, newStep: null };
    return { before: stepEnd(a, i), newStep: null };
  }
  // A step of the remix's own: after the aligned step before it.
  let prior = -1;
  for (let j = part.step - 1; j >= 0; j -= 1) {
    if (align.mine.has(j)) {
      prior = align.mine.get(j);
      break;
    }
  }
  return { after: prior, newStep: part.step };
}

/// The line a part put at the end of step [i] goes before: its STEP line,
/// or for the last step the section's end.
function stepEnd(a, i) {
  const end = a.steps[i]?.end;
  return end !== undefined && end >= 0 ? end : a.end;
}

/// The designer's [mineText] with the changes of the remix [theirsText]
/// named in [take] taken: "all", or ids ([suggestionChanges]). {text,
/// taken: {kind: n}, missing: [ids not among the changes]}. Taking nothing
/// gives the designer's text back as it was, byte for byte.
export function mergeSuggestion(mineText, theirsText, take) {
  const mine = readFile(mineText);
  const theirs = readFile(theirsText);
  const { all, aligns } = listed(mine, theirs);
  const wanted = take === "all" ? null : new Set(Array.isArray(take) ? take.map(String) : []);
  const chosen = [];
  const found = new Set();
  for (const change of all) {
    const id = idOf(change.kind, change.key, change.was, change.now);
    if (wanted && !wanted.has(id)) continue;
    found.add(id);
    chosen.push(change);
  }
  const missing = wanted ? [...wanted].filter((id) => !found.has(id)) : [];
  const taken = Object.fromEntries(KINDS.map((kind) => [kind, 0]));
  if (chosen.length === 0) return { text: String(mineText ?? ""), taken, missing };

  const eol = (line) => {
    const bare = line.replace(/\r$/, "");
    return mine.crlf ? `${bare}\r` : bare;
  };
  const unit = (file, part) => [...part.bound, part.i].map((i) => eol(file.lines[i]));
  const drop = new Set();
  const replace = new Map();
  // Lines put in at a line of the designer's, before it, in three orders:
  // a step of the remix's own that opens there (after a STEP line), then
  // lines into the step there, then a step of the remix's own that follows
  // a last step with no STEP line of its own. index -> [lines] each.
  const opening = new Map();
  const into = new Map();
  const closing = new Map();
  const put = (map, at, lines) => {
    if (!map.has(at)) map.set(at, []);
    map.get(at).push(...lines);
  };
  // Steps only the remix has, by section: key -> Map(after step -> Map(j -> [lines])).
  const newSteps = new Map();
  const brought = new Set();
  for (const change of chosen) {
    taken[change.kind] += 1;
    const a = mine.sections.get(change.key);
    if (change.now) for (const key of bringsOf(change.now.key, mine, theirs)) brought.add(key);
    if (change.kind === "removed") {
      for (const i of [...change.was.bound, change.was.i]) drop.add(i);
      continue;
    }
    if (change.was && !change.restepped) {
      // Changed where it stands in the designer's: the remix's line there.
      for (const i of change.was.bound) drop.add(i);
      replace.set(change.was.i, unit(theirs, change.now));
      continue;
    }
    // Added, or moved to another step: the remix's line where its step is.
    if (change.was) for (const i of [...change.was.bound, change.was.i]) drop.add(i);
    const place = placeFor(change.now, a, aligns.get(change.key));
    if (place.newStep === null) {
      put(into, place.before, unit(theirs, change.now));
      continue;
    }
    if (!newSteps.has(change.key)) newSteps.set(change.key, new Map());
    const afters = newSteps.get(change.key);
    if (!afters.has(place.after)) afters.set(place.after, new Map());
    const steps = afters.get(place.after);
    if (!steps.has(place.newStep)) steps.set(place.newStep, []);
    steps.get(place.newStep).push(...unit(theirs, change.now));
  }
  // The steps only the remix has, each put in after the step it follows,
  // in its own order, each ended by a STEP line of its own.
  const opened = new Map();
  for (const [key, afters] of newSteps) {
    const a = mine.sections.get(key);
    for (const [prior, steps] of afters) {
      const lines = [];
      for (const j of [...steps.keys()].sort((x, y) => x - y)) lines.push(...steps.get(j), eol("0 STEP"));
      if (prior < 0) {
        // Before the section's first step: before its first part line, or
        // at its end when it has none.
        const first = a.parts.length ? Math.min(...a.parts.map((p) => (p.bound.length ? p.bound[0] : p.i))) : a.end;
        put(opening, first, lines);
        opened.set(`${key}|0`, true);
      } else if (a.steps[prior].end >= 0) {
        put(opening, a.steps[prior].end + 1, lines);
        opened.set(`${key}|${prior + 1}`, true);
      } else {
        put(closing, a.end, [eol("0 STEP"), ...lines.slice(0, -1)]);
      }
    }
  }
  // A step of the designer's that the remix has none of, emptied of its
  // parts by what was taken and given none, is no step: its STEP line goes.
  for (const [key, align] of aligns) {
    const a = mine.sections.get(key);
    const left = new Map();
    for (const p of a.parts) if (!drop.has(p.i)) left.set(p.step, (left.get(p.step) || 0) + 1);
    const had = new Set(a.parts.map((p) => p.step));
    for (const at of into.keys()) {
      if (at < a.from || at > a.end) continue;
      const step = a.steps.findIndex((s) => s.end >= at || s.end < 0);
      left.set(step, (left.get(step) || 0) + 1);
    }
    for (let i = 0; i < a.steps.length; i += 1) {
      if (align.theirs.has(i) || !had.has(i) || left.get(i) || opened.has(`${key}|${i}`)) continue;
      const end = a.steps[i].end;
      if (end >= 0) drop.add(end);
      else if (i > 0 && a.steps[i - 1].end >= 0 && !opened.has(`${key}|${i - 1}`)) drop.add(a.steps[i - 1].end);
    }
  }

  const out = [];
  const lines = mine.lines;
  for (let i = 0; i <= lines.length; i += 1) {
    for (const map of [opening, into, closing]) if (map.has(i)) out.push(...map.get(i));
    if (i === lines.length || drop.has(i)) continue;
    out.push(replace.has(i) ? replace.get(i).join("\n") : lines[i]);
  }
  // The sub-models only the remix has that a line taken places, at the
  // end, in the remix's order; a file of one model is made one of
  // sections for them, its model the first.
  if (brought.size) {
    const keys = [...brought].sort((x, y) => theirs.order.indexOf(x) - theirs.order.indexOf(y));
    const tail = [];
    for (const key of keys) {
      const section = theirs.sections.get(key);
      tail.push(...theirs.lines.slice(section.from, section.to).map(eol));
      while (tail.length && tail[tail.length - 1].trim() === "") tail.pop();
      if (!/^0\s+NOFILE\b/i.test(tail[tail.length - 1]?.trim() || "")) tail.push(eol("0 NOFILE"));
    }
    while (out.length && out[out.length - 1].trim() === "") out.pop();
    if (!mine.files) {
      const main = theirs.sections.get(theirs.order[0]);
      out.unshift(eol(`0 FILE ${main?.name || "model.ldr"}`));
    }
    if (!/^0\s+NOFILE\b/i.test(out[out.length - 1]?.trim() || "")) out.push(eol("0 NOFILE"));
    out.push(...tail, "");
  }
  // A sub-model of the designer's that the remix has none of, which no
  // line places once the change is taken, goes, and so on down.
  let text = out.join("\n");
  for (let round = 0; round < 8; round += 1) {
    const after = readFile(text);
    const gone = [];
    for (const key of mine.order.slice(1)) {
      if (theirs.sections.has(key) || !after.sections.has(key)) continue;
      const placed = [...after.sections.values()].some((s) => s.key !== key && s.refs.has(key));
      const wasPlaced = [...mine.sections.values()].some((s) => s.key !== key && s.refs.has(key));
      if (!placed && wasPlaced) gone.push(after.sections.get(key));
    }
    if (!gone.length) break;
    const cut = new Set();
    for (const section of gone) for (let i = section.from; i < section.to; i += 1) cut.add(i);
    text = after.lines.filter((_, i) => !cut.has(i)).join("\n");
  }
  return { text: (mine.bom ? "﻿" : "") + text, taken, missing };
}

/// A suggestion's counts as kept and said: the kinds with any, in order.
export function countsOf(given) {
  const out = {};
  for (const kind of KINDS) {
    const n = given?.[kind];
    out[kind] = Number.isInteger(n) && n >= 0 ? n : 0;
  }
  return out;
}
