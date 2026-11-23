// What a remix changed from the model it was copied from (remixdiff,
// 2026-11-23; docs/MASTERPLAN.md unit 7): the parts added, taken away,
// moved or turned, and recoloured, counted once as the remix is published
// and kept with it (supabase/remix_changes.sql), never worked out as a page
// is viewed.
//
// Printables writes "remixed from" and counts a model's remixes; it holds
// files it cannot read, so it can say no more. Brickworks holds both files
// and the app's Compare already says what changed between two saves, part
// by part (src/parts/model_diff.gd). This is that Compare, here: both files
// read as the app reads a file (api/_parts.js comparedParts), and the
// parts matched by part, colour and place by the same four rules, in the
// same order, at the same distances:
//
//   1. the same part in the same colour, under NEAR LDU from where it was
//      and turned the same way, is unchanged;
//   2. of the rest, the same part where one stood, turned the same way, in
//      another colour, was recoloured;
//   3. of the rest, the same part in the same colour anywhere else was
//      moved or turned, as many as there are of it on both sides, each
//      paired with the nearest;
//   4. what is left was added, or taken away.
//
// A place is the app's (its +Y up: LDraw's y and z turned over), so a part
// is looked up in the same whole-LDU cell the app looks it up in. Pure but
// for the tables _parts.js reads.
//
// What is kept of it ([remixChanges]): the four counts and both sides'
// parts; and for the remix's page's 3D view, which of the remix's parts
// changed, by their index in its packing (sceneOf), as runs, and the parts
// taken away packed as a scene of their own, drawn as ghosts over it.

import { comparedParts, sceneOf, sceneTable, partsTable, currentTable } from "./_parts.js";
import { counted, number, say } from "./_card.js";

/// A part this near where it was, LDU, has not moved (ModelDiff.NEAR).
export const NEAR = 0.5;
/// ...and turned the same way when no axis of it is further than this off.
export const SAME_TURN = 0.01;
/// Moved parts of one part and colour are paired nearest first while there
/// are no more pairs than this to weigh; past it, in order along the model.
export const PAIRS_WEIGHED = 40000;
/// The kinds, in the order they are said.
export const KINDS = ["added", "removed", "moved", "recoloured"];
/// The most ghosts a remix's 3D view draws: past it, the count is said and
/// the parts are not drawn.
export const MOST_GHOSTS = 5000;

/// Godot's round(): half away from zero.
const roundAway = (v) => (v < 0 ? -Math.round(-v) : Math.round(v));

/// A part of one side: where it stands in the app's axes, and its turn's
/// three axes (each the same distance from another's as in LDraw's).
function sided(one, index) {
  const m = one.m;
  return { part: one.part, colour: one.colour, index, scene: one.scene,
    o: [m[0], -m[1], -m[2]], b: [m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]] };
}

const cellOf = (o) => [roundAway(o[0]), roundAway(o[1]), roundAway(o[2])];
const distance2 = (p, q) => (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2;

/// Whether two turns are the same: each axis (a column) within SAME_TURN.
function sameTurn(a, b) {
  for (let c = 0; c < 3; c += 1) {
    if (Math.hypot(a[c] - b[c], a[3 + c] - b[3 + c], a[6 + c] - b[6 + c]) > SAME_TURN) return false;
  }
  return true;
}

const keyOf = (part, cell, sameColour) => (sameColour ? `${part.part}|${part.colour}|${cell.join("|")}` : `${part.part}|${cell.join("|")}`);

/// The index in [was] of a part under [key] that [part] stands where,
/// turned as, and in the colour asked: -1 for none (ModelDiff._find_in).
function findIn(at, key, was, part, sameColour) {
  for (const n of at.get(key) || []) {
    const other = was[n];
    if (!other) continue;
    if ((other.colour === part.colour) !== sameColour) continue;
    if (Math.sqrt(distance2(other.o, part.o)) < NEAR && sameTurn(other.b, part.b)) return n;
  }
  return -1;
}

/// Pairs a part of [was] with one of [now] of the same part, where it stood
/// and turned the same way: in the same colour, or in another. Each pair
/// taken out of both lists (ModelDiff._pair_in_place).
function pairInPlace(was, now, sameColour) {
  const at = new Map();
  was.forEach((part, n) => {
    if (!part) return;
    const key = keyOf(part, cellOf(part.o), sameColour);
    if (!at.has(key)) at.set(key, []);
    at.get(key).push(n);
  });
  const pairs = [];
  now.forEach((part, m) => {
    if (!part) return;
    const cell = cellOf(part.o);
    let found = findIn(at, keyOf(part, cell, sameColour), was, part, sameColour);
    if (found < 0) {
      for (const dx of [-1, 0, 1]) {
        for (const dy of [-1, 0, 1]) {
          for (const dz of [-1, 0, 1]) {
            if (found < 0 && (dx !== 0 || dy !== 0 || dz !== 0)) {
              found = findIn(at, keyOf(part, [cell[0] + dx, cell[1] + dy, cell[2] + dz], sameColour), was, part, sameColour);
            }
          }
        }
      }
    }
    if (found >= 0) {
      pairs.push([was[found], part]);
      was[found] = null;
      now[m] = null;
    }
  });
  return pairs;
}

/// The indexes [of] into [parts] in order along x, then z, then y.
function along(parts, of) {
  return of.map((n) => [parts[n].o[0], parts[n].o[2], parts[n].o[1], n])
    .sort((a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2] || a[3] - b[3]).map((one) => one[3]);
}

/// Of what is left, each part of [was] paired with one of [now] of the same
/// part and colour, nearest first, as many as both sides have
/// (ModelDiff._pair_anywhere).
function pairAnywhere(was, now) {
  const groups = new Map();
  was.forEach((part, n) => {
    if (!part) return;
    const key = `${part.part}|${part.colour}`;
    if (!groups.has(key)) groups.set(key, [[], []]);
    groups.get(key)[0].push(n);
  });
  now.forEach((part, m) => {
    if (!part) return;
    const group = groups.get(`${part.part}|${part.colour}`);
    if (group) group[1].push(m);
  });
  const out = [];
  for (const [olds, news] of groups.values()) {
    if (olds.length === 0 || news.length === 0) continue;
    if (olds.length * news.length <= PAIRS_WEIGHED) {
      const weighed = [];
      for (const n of olds) for (const m of news) weighed.push([distance2(was[n].o, now[m].o), n, m]);
      weighed.sort((a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2]);
      for (const [, n, m] of weighed) {
        if (was[n] && now[m]) {
          out.push([was[n], now[m]]);
          was[n] = null;
          now[m] = null;
        }
      }
    } else {
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

/// What changed from [was] to [now], each comparedParts' list: {counts:
/// {added, removed, moved, recoloured}, turned (of the moved, how many
/// turned), parts_was, parts_now, now: index into now -> kind, was: the
/// indexes into was taken away} (ModelDiff.between).
export function diffParts(was, now) {
  const left = was.map(sided);
  const right = now.map(sided);
  pairInPlace(left, right, true);
  const kinds = new Map();
  for (const [, part] of pairInPlace(left, right, false)) kinds.set(part.index, "recoloured");
  let turned = 0;
  for (const [before, part] of pairAnywhere(left, right)) {
    kinds.set(part.index, "moved");
    if (!sameTurn(before.b, part.b)) turned += 1;
  }
  for (const part of right) if (part) kinds.set(part.index, "added");
  const removed = left.filter(Boolean).map((part) => part.index);
  const counts = { added: 0, removed: removed.length, moved: 0, recoloured: 0 };
  for (const kind of kinds.values()) counts[kind] += 1;
  return { counts, turned, parts_was: was.length, parts_now: now.length, now: kinds, was: removed };
}

/// Sorted indexes as runs, [[first, how many], ...]: a remix's added parts
/// are mostly lines in a row of its file, so its page's 3D view is told
/// them in a few numbers.
export function runsOf(indexes) {
  const sorted = [...new Set(indexes)].filter((n) => Number.isInteger(n) && n >= 0).sort((a, b) => a - b);
  const runs = [];
  for (const n of sorted) {
    const last = runs[runs.length - 1];
    if (last && n === last[0] + last[1]) last[1] += 1;
    else runs.push([n, 1]);
  }
  return runs;
}

/// The indexes runs say (runsOf), at most [most] of them.
export function fromRuns(runs, most = 1e6) {
  const out = [];
  for (const run of Array.isArray(runs) ? runs : []) {
    if (!Array.isArray(run) || !Number.isInteger(run[0]) || !Number.isInteger(run[1]) || run[0] < 0 || run[1] < 1) continue;
    for (let k = 0; k < run[1] && out.length < most; k += 1) out.push(run[0] + k);
  }
  return out;
}

/// What remix [after] changed from [before], its original's version, as
/// kept with the remix: {counts, turned, parts_was, parts_now, shown}, where
/// [shown] is for its page's 3D view: {count: how many parts the remix's
/// packing has (a page whose scene has another count was packed by another
/// catalogue, and offers no What changed), added, moved, recoloured: the
/// remix's parts of each kind as runs of their packing's indexes, ghosts:
/// how many were taken away, and ghost: those packed as a scene of their own
/// with no root (the answer gives it the store's), or null past MOST_GHOSTS
/// or with none}. Null where there is no parts table to read with.
export function remixChanges(before, after, given = partsTable(), table = sceneTable(), current = currentTable()) {
  const was = comparedParts(before, given, table, current);
  const now = comparedParts(after, given, table, current);
  if (!was || !now) return null;
  const diff = diffParts(was, now);
  const lit = { added: [], moved: [], recoloured: [] };
  for (const [index, kind] of diff.now) {
    const scene = now[index].scene;
    if (scene >= 0) lit[kind].push(scene);
  }
  const taken = diff.was.map((index) => was[index].scene).filter((scene) => scene >= 0);
  const ghost = taken.length && taken.length <= MOST_GHOSTS && table
    ? sceneOf(before, "", "remix:ghosts", given, table, new Set(taken)) : null;
  const count = now.reduce((n, one) => n + (one.scene >= 0 ? 1 : 0), 0);
  return { counts: diff.counts, turned: diff.turned, parts_was: diff.parts_was, parts_now: diff.parts_now,
    shown: { count, added: runsOf(lit.added), moved: runsOf(lit.moved), recoloured: runsOf(lit.recoloured),
      ghosts: taken.length, ghost } };
}

/// The four counts as kept, read back at this edge: null for anything not
/// of the shape remixChanges makes.
export function readCounts(given) {
  if (!given || typeof given !== "object") return null;
  const out = {};
  for (const kind of KINDS) {
    const n = given[kind];
    if (!Number.isInteger(n) || n < 0) return null;
    out[kind] = n;
  }
  return out;
}

/// What a remix changed, as its page and its card say it: "42 parts added,
/// 8 taken away, 3 recoloured, 5 moved"; "no parts changed" for none; ""
/// for counts not known. The first clause counts parts, the rest numbers,
/// in the page's language.
export function changeLine(given) {
  const counts = readCounts(given);
  if (!counts) return "";
  // Each said whole, so every language has its own (tools/site_lang.py).
  const first = { added: (parts) => say("{parts} added", { parts }), removed: (parts) => say("{parts} taken away", { parts }),
    recoloured: (parts) => say("{parts} recoloured", { parts }), moved: (parts) => say("{parts} moved", { parts }) };
  const rest = { added: (n) => say("{n} added", { n }), removed: (n) => say("{n} taken away", { n }),
    recoloured: (n) => say("{n} recoloured", { n }), moved: (n) => say("{n} moved", { n }) };
  const clauses = [];
  for (const kind of ["added", "removed", "recoloured", "moved"]) {
    if (!counts[kind]) continue;
    clauses.push(clauses.length === 0 ? first[kind](counted(counts[kind], "part")) : rest[kind](number(counts[kind])));
  }
  return clauses.length ? clauses.join(", ") : say("no parts changed");
}
