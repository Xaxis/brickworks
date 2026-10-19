// The "Tested" mark on a shared model (2026-10-18, supabase/tested.sql).
//
// The app works out four tests as a model is published, where the model
// and the part library are (src/assembly/tested.gd): it stands at every one
// of the steps the share carries; no part of a step is put down in the air
// or hidden behind what is already built; every part is made in its colour;
// nothing is loose. This server cannot run any of them: it has no library,
// no geometry and no physics. So it keeps what the app says, marked as the
// app's own finding with the version of the app that made it, and never
// more than that:
//
//   - the finding is of exactly the file published: it names the file's
//     fingerprint (modelHash), and one that names another file is not kept;
//   - and of the steps that file carries: its count must be the count the
//     file's own 0 !BRICKWORKS PAGES line says, and a file without them has
//     nothing to be tested on;
//   - each test is a yes or a no with the app's reason, checked for shape
//     and size here; whether it passed is worked out here from the four, and
//     never taken from the caller;
//   - what a stranger is shown of a pass is said here, in the site's own
//     words, and never the app's: a forged reason has nowhere to be shown
//     but to the account that sent it;
//   - and the site's owner can clear a mark (api/admin.js ?op=untest), after
//     which it is shown nowhere.
//
// A failing mark is a note to the designer, not a public shame: only its
// owner is told which test failed and why (?op=mine, ?op=tested). Everyone
// else sees a model that passed marked Tested, and any other model as it
// was before there was a mark.

import { modelHash } from "./_directory.js";

export const TESTS = ["stands", "steps", "parts", "whole"];
// The app's version, as project.godot has it: 0.3.0, or 0.3.0-dev.
const APP = /^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,6}([-+.][0-9A-Za-z.-]{1,40})?$/;
const HASH = /^[0-9a-f]{64}$/;
const MOST_WHY = 300;
const PAGES = /^0\s+!BRICKWORKS\s+PAGES\s+(\{.*\})\s*$/m;

/// What each test says to a stranger once passed, in the site's words.
export const SAID = {
  stands: "Stands at every step",
  steps: "every step reachable",
  parts: "every part made in its colour",
  whole: "nothing loose",
};
/// And what each failure is called, to its owner.
const FAILED = {
  stands: "It does not stand at every step",
  steps: "A step is not reachable",
  parts: "A part is not made in its colour",
  whole: "Something is loose",
};

const isCount = (n) => Number.isInteger(n) && n >= 1 && n <= 200000;

/// One line of the app's words, printable, at most MOST_WHY long.
function cleanWhy(given) {
  if (typeof given !== "string") return "";
  return given.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, MOST_WHY).trim();
}

/// How many steps [text] carries (SharedPages' head line), or 0 for none.
export function carriedSteps(text) {
  const found = PAGES.exec(String(text || ""));
  if (!found) return 0;
  try {
    const head = JSON.parse(found[1]);
    return isCount(head?.steps) ? head.steps : 0;
  } catch {
    return 0;
  }
}

/// The app's finding for [text], checked: {row} to keep, {refused: why}
/// when it is not one to keep, or null when none was sent. Never throws: a
/// finding that cannot be kept never stops the model being published.
export function checkTested(given, text) {
  if (given === undefined || given === null) return null;
  if (typeof given !== "object" || Array.isArray(given)) return { refused: "the finding is not one" };
  if (given.v !== 1) return { refused: "the finding is of a kind this server does not know" };
  if (typeof given.app !== "string" || !APP.test(given.app)) return { refused: "the finding does not say which app made it" };
  if (typeof given.model !== "string" || !HASH.test(given.model)) return { refused: "the finding does not name its file" };
  if (given.model !== modelHash(text)) return { refused: "the finding is of another file" };
  const carried = carriedSteps(text);
  if (!carried) return { refused: "the file carries no steps to have been tested on" };
  if (given.steps !== carried) return { refused: "the finding is of other steps than the file carries" };
  if (!isCount(given.parts)) return { refused: "the finding does not say how many parts it tested" };
  const tests = given.tests;
  if (!tests || typeof tests !== "object" || Array.isArray(tests)
      || Object.keys(tests).sort().join(",") !== [...TESTS].sort().join(",")) {
    return { refused: "the finding is not the four tests" };
  }
  const kept = {};
  for (const name of TESTS) {
    const one = tests[name];
    const why = cleanWhy(one?.why);
    if (!one || typeof one !== "object" || typeof one.ok !== "boolean" || !why) {
      return { refused: `the finding's ${name} test is not a yes or a no with its reason` };
    }
    kept[name] = { ok: one.ok, why };
  }
  return {
    row: { by: "app", app: given.app, file_hash: given.model, parts: given.parts, steps: given.steps,
      tests: kept, passed: TESTS.every((name) => kept[name].ok) },
  };
}

/// What anybody is shown of a version's mark: only a pass, never cleared,
/// in the site's own words. Null for anything else, which is shown as no
/// mark at all.
export function publicMark(row) {
  if (!row || row.passed !== true || row.cleared_at) return null;
  const said = TESTS.map((name) => SAID[name]);
  return { tested: true, by: "app", app: row.app, at: row.at ?? null, steps: row.steps, parts: row.parts,
    said, line: said.join(" · ") };
}

/// What the model's owner is told of it: every test, and why.
export function ownerMark(row) {
  if (!row) return null;
  return { passed: row.passed === true && !row.cleared_at, by: "app", app: row.app, at: row.at ?? null,
    steps: row.steps, parts: row.parts, n: row.n ?? null,
    tests: Object.fromEntries(TESTS.map((name) => [name, {
      ok: row.tests?.[name]?.ok === true, why: String(row.tests?.[name]?.why || ""),
      said: row.tests?.[name]?.ok === true ? SAID[name] : FAILED[name] }])),
    cleared: Boolean(row.cleared_at), cleared_why: row.cleared_why ?? null };
}

/// A version's mark as kept, or null: read with the secret key, so only for
/// a row already read as published, or for its owner. Null too while the
/// table is not there yet, so pages go on working before tested.sql.
export async function markOf(db, id, n) {
  try {
    const rows = await db(`share_tests?model=eq.${id}&n=eq.${n}&select=n,at,app,parts,steps,tests,passed,`
      + "cleared_at,cleared_why");
    return rows[0] || null;
  } catch {
    return null;
  }
}
