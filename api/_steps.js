// How many steps a model has, as a person building it is told (steps206,
// 2026-10-23).
//
// A step is what the booklet numbers: the step player's "Step 12 of 87",
// the booklet's cover "502 pieces · 87 steps", the Tested mark's "Stands at
// every one of its 87 steps". A sub-assembly built on the side, in a box
// beside the step it goes on in as a real booklet builds one, is built in
// steps of its own inside that step ("Earth, 3 of 6"), and those are said
// apart: "12 sub-assemblies built on the side, in 64 steps of their own".
// Every step either kind is a page the step player turns to, and a comment
// or a version's changes name a step by that page (supabase/comments.sql).
//
// They are counted from the steps the app worked out when it shared the
// model and carried in its text (src/net/shared_pages.gd), the very steps
// its step player and booklet show, by the rule the app counts them by
// (Instructions.count). Before, this counted the 0 STEP lines of the file's
// first model: the castle's page said 65 steps where it has 399, as its
// sub-models' steps were not counted and its steps were worked out anew;
// the orrery's said 5 where it has 87.
//
// Pure: text in, a count out.

import { fingerprint } from "./_versions.js";

const HEAD = /^0\s+!BRICKWORKS\s+PAGES\s+(\{.*\})\s*$/m;
const PAGE = /^0\s+!BRICKWORKS\s+PAGE\s+(\{.*\})\s*$/;

/// The steps of the model in [text]: {steps, side, builds, pages} — steps
/// the booklet numbers, steps building sub-assemblies on the side, how many
/// sub-assemblies, and every page — or null when the file does not carry
/// steps the app would show (an old link, a model past 1.9 MB, a file
/// written elsewhere): the app works those out as it opens it, and nothing
/// here can. A file whose own steps are its builder's, all in one model,
/// has those steps, one a page, as the app shows them; [own] says whether
/// they are (checkModel's ownSteps), [oneModel] that it places no model of
/// its own.
export function stepCount(text, { own = false, oneModel = false, steps = 0 } = {}) {
  // Carried, and for this very text (SharedPages.count reads them alike):
  // the steps the app plays when it opens it.
  const found = HEAD.exec(String(text || ""));
  if (found) {
    let head;
    try {
      head = JSON.parse(found[1]);
    } catch {
      return null;
    }
    if (!head || head.v !== 1 || head.model !== fingerprint(text)) return null;
    const numbers = new Set();
    const boxes = new Set();
    let side = 0;
    let pages = 0;
    for (const line of String(text).slice(found.index).split("\n")) {
      const page = PAGE.exec(line.trim());
      if (!page) continue;
      let said;
      try {
        said = JSON.parse(page[1]);
      } catch {
        return null;
      }
      pages += 1;
      // A callout's step: [callout, its step in it from 1, how many]; 0 on
      // the step that puts the finished sub-assembly on. Two put on in one
      // of the author's steps are two pages of one number, as the booklet
      // numbers them: "Step 14 of 14 · minifig 2, put on".
      const callout = Array.isArray(said?.c) && said.c.length === 3 ? said.c : null;
      if (callout && Number(callout[1]) > 0) {
        side += 1;
        boxes.add(Number(callout[0]));
      } else {
        numbers.add(Number(said?.n));
      }
    }
    if (pages !== head.steps || !numbers.size) return null;
    return { steps: numbers.size, side, builds: boxes.size, pages };
  }
  if (own && oneModel && steps > 0) return { steps, side: 0, builds: 0, pages: steps };
  return null;
}

/// "1,234 steps".
const counted = (n, one, many = `${one}s`) => `${Number(n).toLocaleString("en-US")} ${n === 1 ? one : many}`;

/// [count]'s steps in words: "87 steps".
export function stepsSaid(count) {
  return counted(count.steps, "step");
}

/// And what is built on the side, in words: "12 sub-assemblies built on the
/// side, in 64 steps of their own"; "" for none.
export function sideSaid(count) {
  if (!count.side) return "";
  return `${counted(count.builds, "sub-assembly", "sub-assemblies")} built on the side, in `
    + `${counted(count.side, "step")} of ${count.builds === 1 ? "its" : "their"} own`;
}

/// Both, as one sentence's words: "87 steps, and 12 sub-assemblies built on
/// the side in 64 steps of their own" (Instructions.count_words).
export function countSaid(count) {
  const side = sideSaid(count);
  return side ? `${stepsSaid(count)}, and ${side.replace(" side, in ", " side in ")}` : stepsSaid(count);
}
