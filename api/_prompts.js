// A weekly quick build (2026-11-23, supabase/challenge_prompts.sql): a
// challenge of a new kind, a week long, with a brief and a template the
// house publishes, entered by publishing a copy of the template in the
// gallery, and at its end every entry stacked into one model.
//
//   GET  /api/people?op=prompt_of&model=X   the prompt open now whose
//                         template is X: {prompt: {id, title, brief,
//                         starts_on, ends_on, template, page, open}} or
//                         {prompt: null}. What the studio says under a copy
//                         of it, and the app's publish dialog asks.
//   GET  /api/people?op=challenge&id=N      for a prompt, its page
//                         (promptAnswer): the template's Start, the stack
//                         once made, every entry newest first
//   publishing (api/share.js) a copy of an open prompt's template in the
//                         gallery enters it (promptOnPublish), unless the
//                         publish says prompt_out, which takes it out
//   GET  /api/share/prompts                 (Vercel's cron, every hour;
//                         ?tests=1 for the flows' own pool) the house's part
//                         (runPrompts): each prompt's template, the house's
//                         two entries a week of the four it wrote, and the
//                         stack of a prompt that ended
//
// The house is Brickworks' own account (talk_house, handle brickworks). It
// publishes through the same publish every model goes through
// (api/share.js publishModel), dated when it does, credited "Brickworks",
// with a picture drawn here from the model's own parts (api/_flatlay.js
// drawModel), since no app drew one.

import { db } from "./_db.js";
import { cardOf } from "./_directory.js";

const ID = /^[A-Za-z0-9]{10}$/;
const n = (value) => Number(value) || 0;
const missing = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const rpc = (name, body) => db(`rpc/${name}`, { method: "POST", body });
const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", timeZone: "UTC" });
const dayOf = (iso) => DAY.format(new Date(`${String(iso).slice(0, 10)}T00:00:00Z`));

/// Where a prompt's page is.
export const pageOf = (origin, id, test = false) => `${origin}/challenge?id=${n(id)}${test ? "&tests=1" : ""}`;

/// Why a copy of an open prompt's template did not enter it, in words, as
/// the publish dialog says them (prompt_enter's refusals).
export const PROMPT_SAID = {
  under_13: "Quick builds are for people 13 and over, so this one is not entered. It is shared all the same.",
  not_asked: "Brickworks asks everyone one question first: sign in again to answer it, then publish again to enter.",
  barred: "This account was taken out of the gallery, so it cannot enter.",
  not_in_gallery: "Shown in the gallery with your name on it, it enters this week's quick build.",
  three: "Three of your models are in this week's quick build already: that is the most.",
};

// ---------------------------------------------------------------------------
// What a page and the app are told.

/// The open prompt whose template is [model], as the app is told it, or
/// null. Before supabase/challenge_prompts.sql, null.
export async function promptOf(origin, model) {
  if (!ID.test(String(model || ""))) return null;
  let row;
  try {
    row = await rpc("prompt_of", { model_id: model });
  } catch (trouble) {
    if (missing(trouble)) return null;
    throw trouble;
  }
  if (!row || !row.id) return null;
  return { id: n(row.id), title: String(row.title), brief: String(row.brief), starts_on: row.starts_on,
    ends_on: row.ends_on, template: row.template, open: true, page: pageOf(origin, row.id, row.test === true) };
}

/// GET ?op=prompt_of&model=X. Kept by the CDN a minute: a prompt's template
/// and days change only when the owner sets one.
export async function promptOfAnswer(request, response, { origin }) {
  const model = String(request.query?.model || "");
  if (!ID.test(model)) return response.status(400).json({ error: "name a model: ?model=<its link's id>" });
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=60, stale-while-revalidate=60");
  return response.status(200).json({ prompt: await promptOf(origin, model) });
}

/// A prompt's page ([row], prompt_page_at's) as /challenge?id=N draws it.
/// Pure.
export function promptShown(origin, row) {
  const card = (one) => (one && one.id ? cardOf(origin, one) : null);
  const entries = (row.entries || []).filter((one) => one && ID.test(String(one.model || "")) && one.card)
    .map((one) => ({ ...cardOf(origin, one.card), way: one.way, entered_at: one.at }));
  const template = card(row.template);
  return {
    kind: "prompt", id: n(row.id), title: String(row.title), brief: String(row.brief), starts_on: row.starts_on,
    ends_on: row.ends_on, ended_on: row.ended_on, state: row.state, test: row.test === true,
    days_said: `${dayOf(row.starts_on)} to ${dayOf(row.ends_on)}`,
    template, start: template ? `/app?copy=${template.id}` : null,
    stack: card(row.stack), entries, makers: n(row.makers),
  };
}

/// Prompt [id]'s page, or null for no such prompt (a month's challenge, one
/// not open yet, a test one unasked). Before challenge_prompts.sql, null.
export async function promptAnswer(origin, id, tests) {
  try {
    const row = await rpc("prompt_page_at", { challenge_id: id, tests });
    return row && row.id ? promptShown(origin, row) : null;
  } catch (trouble) {
    if (missing(trouble)) return null;
    throw trouble;
  }
}

/// The prompt open now in [tests]'s pool, as the hub and the home name it:
/// {id, title, brief, ends_on, page, start, entries} or null.
export async function promptNow(origin, tests) {
  let rows;
  try {
    rows = await rpc("prompt_list", { tests });
  } catch (trouble) {
    if (missing(trouble)) return null;
    throw trouble;
  }
  const open = (Array.isArray(rows) ? rows : []).find((one) => one && one.state === "open" && (tests || !one.test));
  if (!open) return null;
  return { id: n(open.id), title: String(open.title), brief: String(open.brief), starts_on: open.starts_on,
    ends_on: open.ends_on, page: pageOf(origin, open.id, open.test === true),
    start: ID.test(String(open.template || "")) ? `/app?copy=${open.template}` : null, entries: n(open.entries) };
}

/// The prompts, each id to {title, template, test}: what a notice of one
/// needs to say Start (api/_notifications.js). The site's own always, and
/// with [tests] the checks' beside them, so a run of test ones never pushes
/// a real week out of prompt_list's 24. An empty map before the file.
export async function promptsById(tests) {
  const found = new Map();
  try {
    const lists = await Promise.all([rpc("prompt_list", { tests: false }), tests ? rpc("prompt_list", { tests: true }) : []]);
    for (const one of lists.flatMap((list) => list || [])) {
      if (one && one.id) found.set(n(one.id), { title: String(one.title), template: one.template || null, test: one.test === true });
    }
  } catch (trouble) {
    if (!missing(trouble)) throw trouble;
  }
  return found;
}

// ---------------------------------------------------------------------------
// Entered as it is published.

/// After [owner]'s publish of [id], a copy of [remixedFrom]: entered in the
/// prompt open now whose template that is, or taken out of it when [out]
/// (the publish dialog's one tap). {id, title, entered, page, said?} for a
/// copy of an open prompt's template, else null: nothing to say. Never
/// stops a publish: a prompt that cannot be read is said as not entered.
export async function promptOnPublish(origin, owner, id, remixedFrom, out) {
  if (!remixedFrom) return null;
  try {
    const prompt = await rpc("prompt_of", { model_id: remixedFrom });
    if (!prompt || !prompt.id) return null;
    const page = pageOf(origin, prompt.id, prompt.test === true);
    const base = { id: n(prompt.id), title: String(prompt.title), ends_on: prompt.ends_on, page };
    if (out) {
      await rpc("prompt_withdraw", { account: owner, model_id: id });
      return { ...base, entered: false, kept_out: true };
    }
    const said = await rpc("prompt_enter", { account: owner, model_id: id });
    if (said && said.entered === true) return { ...base, entered: true, ...(said.already ? { already: true } : {}) };
    const why = String(said?.refused || "");
    return { ...base, entered: false, refused: why, said: PROMPT_SAID[why] || "It was not entered just now." };
  } catch (trouble) {
    if (missing(trouble)) return null;
    console.error(`prompts: entering ${id}: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return null;
  }
}

// ---------------------------------------------------------------------------
// The house's models: each prompt's template, and its two entries a week
// for the prompts it wrote, laid on the 8x8 plate a stud at a time.

/// The plate a template is: LDraw's 8x8 plate, its colour each prompt's.
export const PLATE = "41539.dat";
/// Each part the house lays: [studs across x, studs across z, plates tall].
const SIZE = {
  "3001": [4, 2, 3], "3003": [2, 2, 3], "3004": [2, 1, 3], "3005": [1, 1, 3], "3008": [8, 1, 3], "3009": [6, 1, 3],
  "3010": [4, 1, 3], "3622": [3, 1, 3], "2453b": [1, 1, 15], "3062b": [1, 1, 3], "3941": [2, 2, 3], "4589": [1, 1, 3],
  "3020": [4, 2, 1], "3022": [2, 2, 1], "3023": [2, 1, 1], "3024": [1, 1, 1], "3031": [4, 4, 1], "3034": [8, 2, 1],
  "3460": [8, 1, 1], "3666": [6, 1, 1], "3710": [4, 1, 1], "6141": [1, 1, 1], "3068b": [2, 2, 1], "3069b": [2, 1, 1],
  "3070b": [1, 1, 1], "98138": [1, 1, 1],
};
/// A part turned a quarter round, across the plate's other way.
const TURNED = "0 0 1 0 1 0 -1 0 0";
const STRAIGHT = "1 0 0 0 1 0 0 0 1";

/// One part's LDraw line: [part] in [colour], its corner on the plate's stud
/// [x] (0 to 7, left to right) and [z] (0 to 7, back to front: LDraw's
/// front is -Z), its foot [level] plates above the plate's top, [turned] a
/// quarter round. Pure.
export function laid(part, colour, x, z, level, turned = false) {
  const [w0, d0, tall] = SIZE[part];
  const [w, d] = turned ? [d0, w0] : [w0, d0];
  const at = (cell, span) => -80 + (cell + span / 2) * 20;
  const y = -(level * 8) - tall * 8;
  return `1 ${colour} ${at(x, w)} ${y} ${-at(z, d)} ${turned ? TURNED : STRAIGHT} ${part}.dat`;
}

/// The house's four prompts (challenge_prompts.sql's seeds): each one's
/// plate colour and its two entries, as [part, colour, x, z, level, turned].
export const HOUSE = {
  habitat: { plate: 2, entries: [
    { name: "Reading nook", about: "A corner to read in: a shelf of books, a lamp, a bed under the eaves.", parts: [
      ["3008", 19, 0, 0, 0], ["3008", 28, 0, 0, 3], ["3008", 19, 0, 0, 6], ["3008", 28, 0, 0, 9],
      ["3009", 19, 0, 1, 0, true], ["3009", 28, 0, 1, 3, true], ["3009", 19, 0, 1, 6, true], ["3009", 28, 0, 1, 9, true],
      ["3010", 70, 2, 1, 0], ["3005", 4, 2, 1, 3], ["3005", 1, 3, 1, 3], ["3005", 14, 4, 1, 3], ["3005", 2, 5, 1, 3],
      ["3010", 70, 2, 1, 6], ["3005", 0, 1, 1, 0], ["3005", 0, 1, 1, 3], ["6141", 14, 1, 1, 6],
      ["3001", 70, 4, 5, 0], ["3020", 15, 4, 5, 3], ["3069b", 4, 4, 5, 4], ["3069b", 4, 4, 6, 4],
      ["4589", 2, 7, 1, 0], ["4589", 2, 7, 1, 3], ["3068b", 19, 2, 3, 0],
      ["3034", 70, 0, 0, 12], ["3666", 70, 0, 2, 12, true]] },
    { name: "Garden shed", about: "A red-roofed shed with a door left open, a path of stones, a tree and flowers.", parts: [
      ["3010", 15, 4, 0, 0], ["3010", 15, 4, 0, 3], ["3010", 15, 4, 0, 6],
      ["3622", 15, 7, 1, 0, true], ["3622", 15, 7, 1, 3, true], ["3622", 15, 7, 1, 6, true],
      ["3004", 15, 4, 1, 0, true], ["3004", 15, 4, 1, 3, true], ["3004", 15, 4, 1, 6, true],
      ["3005", 15, 4, 3, 0], ["3005", 15, 4, 3, 3], ["3622", 15, 4, 3, 6],
      ["3031", 4, 4, 0, 9], ["3022", 4, 5, 1, 10],
      ["3068b", 71, 5, 4, 0], ["3068b", 72, 5, 6, 0],
      ["2453b", 6, 1, 4, 0], ["3003", 2, 0, 3, 15], ["4589", 2, 0, 3, 18], ["4589", 2, 1, 4, 18],
      ["6141", 4, 0, 6, 0], ["6141", 14, 1, 7, 0], ["6141", 1, 2, 6, 0], ["4589", 2, 2, 1, 0], ["4589", 2, 1, 1, 0]] },
  ] },
  "snowed-in": { plate: 15, entries: [
    { name: "Cabin porch", about: "A log cabin under the snow, its lantern lit on the porch, a snowman and a pine.", parts: [
      ["3008", 70, 0, 0, 0], ["3008", 70, 0, 0, 3], ["3008", 70, 0, 0, 6], ["3008", 70, 0, 0, 9],
      ["3004", 70, 0, 1, 0, true], ["3004", 70, 0, 1, 3, true], ["3004", 70, 0, 1, 6, true], ["3004", 70, 0, 1, 9, true],
      ["3004", 70, 7, 1, 0, true], ["3004", 70, 7, 1, 3, true], ["3004", 70, 7, 1, 6, true], ["3004", 70, 7, 1, 9, true],
      ["3004", 70, 1, 2, 0], ["3004", 70, 1, 2, 3], ["3004", 70, 1, 2, 6],
      ["3004", 70, 5, 2, 0], ["3004", 70, 5, 2, 3], ["3004", 70, 5, 2, 6], ["3009", 70, 1, 2, 9],
      ["3034", 15, 0, 0, 12], ["3460", 15, 0, 2, 12],
      ["3034", 70, 0, 3, 0], ["3062b", 14, 2, 3, 1],
      ["3941", 15, 5, 5, 0], ["3062b", 15, 5, 5, 3], ["6141", 0, 5, 5, 6],
      ["3062b", 6, 1, 6, 0], ["3022", 288, 0, 5, 3], ["3003", 288, 0, 5, 4], ["4589", 288, 0, 5, 7]] },
    { name: "Frozen pond", about: "A pond frozen hard between two pines, a lamp post and a red sled.", parts: [
      ["3068b", 43, 2, 2, 0], ["3068b", 43, 4, 2, 0], ["3068b", 43, 2, 4, 0], ["3068b", 43, 4, 4, 0],
      ["3005", 6, 1, 1, 0], ["3003", 288, 0, 0, 3], ["3003", 288, 0, 0, 6], ["4589", 288, 0, 0, 9],
      ["3005", 6, 6, 1, 0], ["3003", 288, 6, 0, 3], ["3022", 15, 6, 0, 6], ["4589", 288, 7, 0, 7],
      ["2453b", 0, 6, 6, 0], ["3062b", 14, 6, 6, 15], ["6141", 0, 6, 6, 18],
      ["3023", 4, 1, 7, 0], ["3069b", 70, 1, 6, 0],
      ["3062b", 15, 0, 4, 0], ["6141", 15, 1, 4, 0], ["3062b", 15, 7, 3, 0]] },
  ] },
  workshop: { plate: 71, entries: [
    { name: "Toymaker's bench", about: "A bench of half-made toys under a shelf of finished ones, and a train to try.", parts: [
      ["3008", 28, 0, 0, 0], ["3008", 28, 0, 0, 3], ["3008", 28, 0, 0, 6], ["3008", 28, 0, 0, 9],
      ["3005", 70, 1, 2, 0], ["3005", 70, 4, 2, 0], ["3005", 70, 1, 3, 0], ["3005", 70, 4, 3, 0],
      ["3020", 70, 1, 2, 3], ["3069b", 0, 2, 2, 4], ["6141", 4, 1, 3, 4], ["3062b", 14, 4, 3, 4],
      ["3005", 70, 1, 1, 0], ["3005", 70, 1, 1, 3], ["3005", 70, 4, 1, 0], ["3005", 70, 4, 1, 3],
      ["3710", 70, 1, 1, 6], ["3005", 4, 2, 1, 7], ["3005", 1, 3, 1, 7],
      ["3003", 4, 5, 5, 0], ["3062b", 0, 6, 5, 3], ["3004", 14, 5, 7, 0], ["3062b", 70, 2, 5, 0]] },
    { name: "Robot lab", about: "A robot standing by for its first test, beside the desk that wrote its code.", parts: [
      ["3008", 72, 0, 0, 0], ["3008", 72, 0, 0, 3], ["3008", 72, 0, 0, 6],
      ["3010", 72, 1, 1, 0], ["3710", 0, 1, 1, 3], ["3004", 1, 2, 1, 4],
      ["3005", 71, 5, 4, 0], ["3005", 71, 6, 4, 0], ["3003", 15, 5, 4, 3], ["3022", 0, 5, 4, 6],
      ["3004", 71, 5, 4, 7], ["98138", 36, 5, 4, 10], ["98138", 36, 6, 4, 10],
      ["3068b", 72, 2, 5, 0], ["3004", 4, 0, 6, 0], ["3069b", 14, 0, 7, 0]] },
  ] },
  "gift-box": { plate: 19, entries: [
    { name: "Teddy in a box", about: "A red box with a yellow ribbon, opened on a teddy bear.", parts: [
      ["3008", 4, 0, 0, 0], ["3008", 4, 0, 0, 3], ["3008", 4, 0, 7, 0], ["3008", 4, 0, 7, 3],
      ["3009", 4, 0, 1, 0, true], ["3009", 4, 0, 1, 3, true], ["3009", 4, 7, 1, 0, true], ["3009", 4, 7, 1, 3, true],
      ["3460", 14, 0, 0, 6], ["3460", 14, 0, 7, 6], ["3666", 14, 0, 1, 6, true], ["3666", 14, 7, 1, 6, true],
      ["3003", 28, 3, 3, 0], ["3003", 28, 3, 3, 3], ["3062b", 28, 3, 3, 6], ["3062b", 28, 4, 3, 6]] },
    { name: "Train set in a box", about: "A blue box with a white ribbon, opened on a little red engine.", parts: [
      ["3008", 1, 0, 0, 0], ["3008", 1, 0, 0, 3], ["3008", 1, 0, 7, 0], ["3008", 1, 0, 7, 3],
      ["3009", 1, 0, 1, 0, true], ["3009", 1, 0, 1, 3, true], ["3009", 1, 7, 1, 0, true], ["3009", 1, 7, 1, 3, true],
      ["3460", 15, 0, 0, 6], ["3460", 15, 0, 7, 6], ["3666", 15, 0, 1, 6, true], ["3666", 15, 7, 1, 6, true],
      ["3020", 0, 2, 3, 0], ["3003", 4, 2, 3, 1], ["3062b", 0, 5, 3, 1], ["3005", 4, 4, 4, 1], ["3062b", 15, 0, 0, 7]] },
  ] },
};

/// The words a file of the house's starts with. Pure.
function headOf(title, file, words) {
  return [`0 ${title}`, `0 Name: ${file}`, "0 Author: Brickworks", ...words.map((line) => `0 // ${line}`)];
}

/// A file name for [words]: lower case, hyphens, at most 40. Pure.
export const slugOf = (words, fallback = "model") =>
  String(words || "").toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40)
  || fallback;

/// Prompt [prompt]'s template: its brief, and the 8x8 plate. Pure.
export function templateText(prompt) {
  const colour = HOUSE[prompt.seed]?.plate ?? 19;
  return [...headOf(`${prompt.title}: the template`, `${slugOf(prompt.title)}-template.ldr`,
    [String(prompt.brief).replace(/\s+/g, " "), "Brickworks' quick build of the week: build on the plate and publish "
      + "it in the gallery to enter."]),
  `1 ${colour} 0 0 0 ${STRAIGHT} ${PLATE}`, "0 STEP", ""].join("\n");
}

/// The house's entry [k] (0 or 1) of the prompt seeded [seed]: the template's
/// plate and what the house laid on it, a step a course. Null for none. Pure.
export function houseEntry(seed, k) {
  const house = HOUSE[seed];
  const entry = house?.entries?.[k];
  if (!entry) return null;
  const lines = [...headOf(entry.name, `${slugOf(entry.name)}.ldr`, [entry.about]),
    `1 ${house.plate} 0 0 0 ${STRAIGHT} ${PLATE}`, "0 STEP"];
  const levels = [...new Set(entry.parts.map((one) => one[4]))].sort((a, b) => a - b);
  for (const level of levels) {
    for (const one of entry.parts.filter((part) => part[4] === level)) lines.push(laid(...one));
    lines.push("0 STEP");
  }
  return { name: entry.name, about: entry.about, text: `${lines.join("\n")}\n` };
}

// ---------------------------------------------------------------------------
// The stack: every entry's file put into one model.

/// [text]'s files: [{name, lines}], the first its main model (named "" when
/// the file has no 0 FILE line). Pure.
export function sectionsOf(text) {
  const out = [];
  let current = null;
  for (const raw of String(text).replace(/^﻿/, "").split(/\r?\n/)) {
    const line = raw.trimEnd();
    const file = /^\s*0\s+FILE\s+(.+)$/i.exec(line);
    if (file) {
      current = { name: file[1].trim(), lines: [] };
      out.push(current);
      continue;
    }
    if (/^\s*0\s+NOFILE\s*$/i.test(line)) {
      current = null;
      continue;
    }
    if (!current) {
      if (out.length) continue;
      current = { name: "", lines: [] };
      out.push(current);
    }
    current.lines.push(line);
  }
  return out.filter((one) => one.lines.some((line) => line.trim()));
}

/// [lines] with each part or sub-model line's file renamed by [renamed] (a
/// lower-cased name to the new one), every other word of it as it was.
function moved(lines, renamed) {
  return lines.map((line) => {
    const fields = /^(\s*1(?:\s+\S+){13}\s+)(.+?)\s*$/.exec(line);
    const to = fields && renamed.get(fields[2].toLowerCase());
    return to ? `${fields[1]}${to}` : line;
  });
}

/// A stack's file: [entries] ([{model, name, author, handle, text, low,
/// high}], the tower's foot first; low and high the LDraw y of the entry's
/// highest and lowest point, from its parts' own geometry) each a sub-model
/// of its own, credited to its maker, laid one on the next as habitats are
/// stacked: each foot on the studs of the one below. [prompt] {title,
/// starts_on, ends_on}. {text, placed: [{model, file, dy}]}. Pure.
export function stackText(prompt, entries, origin = "https://brickworks.diy") {
  const title = `${prompt.title}: the stack`;
  const main = `${slugOf(prompt.title)}-stack.ldr`;
  const credits = entries.map((one, k) => `${k + 1}. ${one.name} by ${one.author || "a builder"}`
    + `${one.handle ? ` (@${one.handle})` : ""}, ${origin}/m/${one.model}`);
  const head = [`0 FILE ${main}`, ...headOf(title, main,
    [`Every entry of Brickworks' quick build "${prompt.title}", ${dayOf(prompt.starts_on)} to ${dayOf(prompt.ends_on)}, `
      + "one on the next: each its own sub-model, credited to its maker.", ...credits])];
  const body = [];
  const files = [];
  const placed = [];
  let dy = 0;
  let top = null;
  entries.forEach((one, k) => {
    const prefix = `e${String(k + 1).padStart(2, "0")}-`;
    const sections = sectionsOf(one.text);
    if (!sections.length) return;
    const renamed = new Map();
    sections.forEach((section, at) => {
      const name = at === 0 ? `${prefix}${slugOf(one.name, "entry")}.ldr` : `${prefix}${section.name}`;
      if (section.name) renamed.set(section.name.toLowerCase(), name);
      section.file = name;
    });
    // Its foot on the studs of the one below: a plate's underside takes
    // the 4 LDU of the studs it sits on.
    if (top !== null) dy = top + 4 - one.high;
    top = one.low + dy;
    placed.push({ model: one.model, file: sections[0].file, dy });
    body.push(`1 16 0 ${+dy.toFixed(4)} 0 ${STRAIGHT} ${sections[0].file}`, "0 STEP");
    sections.forEach((section, at) => {
      const own = at === 0
        ? section.lines.filter((line, i) => !(i === 0 && /^\s*0\s+(?!\S+:|!|\/\/|STEP\b|ROTSTEP\b)/i.test(line))
          && !/^\s*0\s+(Name|Author):/i.test(line))
        : section.lines;
      const said = at === 0 ? [...headOf(one.name, section.file, [])]
        .map((line) => (line === "0 Author: Brickworks" ? `0 Author: ${one.author || "a builder"}${one.handle ? ` (@${one.handle})` : ""}` : line))
        .concat(`0 // ${origin}/m/${one.model}`) : [];
      files.push(`0 FILE ${section.file}`, ...said, ...moved(own, renamed), "0 NOFILE");
    });
  });
  return { text: `${[...head, ...body, "0 NOFILE", ...files].join("\n")}\n`, placed };
}

/// The LDraw y of [placed]'s highest and lowest points ([{m, corners}]:
/// its LDraw matrix and the corners of its part's box in the part's own
/// LDraw frame): {low, high}, low the highest point (LDraw's y grows down).
/// Each part's box turned as it is placed; one with no geometry left out.
/// Pure.
export function heightOf(placed) {
  let low = Infinity;
  let high = -Infinity;
  for (const one of placed) {
    if (!one.corners) continue;
    const { m } = one;
    for (const [x, y, z] of one.corners) {
      const wy = m[1] + m[6] * x + m[7] * y + m[8] * z;
      low = Math.min(low, wy);
      high = Math.max(high, wy);
    }
  }
  return Number.isFinite(low) ? { low, high } : { low: 0, high: 0 };
}

// ---------------------------------------------------------------------------
// The house's part, every hour.

const JOB = "prompts";
const LEASE_SECONDS = 600;

/// What is due in [tests]'s pool, done: each prompt's template published by
/// the house; the two entries of the prompts it wrote, published as copies
/// of the template (so they enter as anybody's do); and each ended prompt's
/// stack. [publishAs]({body, test}) publishes as the house and answers the
/// publish's own answer; [readModel](id) a published model's file;
/// [measure](text) its {low, high}; [picture](text) its PNG as base64 or
/// null. {outcome, did: [...]} under the cron's lock.
export async function runPrompts({ tests = false, holder = "cron", publishAs, readModel, measure, picture,
  origin = "https://brickworks.diy" }) {
  let begun;
  try {
    begun = await rpc("cron_begin", { job: JOB, holder, seconds: LEASE_SECONDS });
  } catch (trouble) {
    if (missing(trouble)) return { outcome: "not_ready", did: [] };
    throw trouble;
  }
  if (!begun || begun.locked !== false) return { outcome: "locked", did: [] };
  const did = [];
  try {
    let due = [];
    try {
      due = (await rpc("prompt_house_due", { tests })) || [];
    } catch (trouble) {
      if (!missing(trouble)) throw trouble;
    }
    for (const prompt of due) {
      if (!prompt || !prompt.id) continue;
      // Its template first: the entries are its copies.
      if (!ID.test(String(prompt.template || ""))) {
        const text = templateText(prompt);
        const made = await publishAs({ test: tests, body: { name: `${prompt.title}: the template`, author: "Brickworks",
          model: text, listed: false, licence: "cc-by-4.0", made_with: "hand", image: await picture(text),
          description: `${prompt.brief}\n\nThis week's quick build on Brickworks: open it in the studio, build on `
            + "the plate and publish it in the gallery to enter." } });
        if (!made?.id) throw new Error(`the template of ${prompt.id} was not published`);
        await rpc("prompt_template_set", { challenge_id: prompt.id, model_id: made.id });
        prompt.template = made.id;
        did.push({ prompt: n(prompt.id), template: made.id });
      }
      if (prompt.state === "open" && HOUSE[prompt.seed]) {
        for (let k = n(prompt.have); k < 2; k += 1) {
          const entry = houseEntry(prompt.seed, k);
          if (!entry) break;
          const made = await publishAs({ test: tests, body: { name: entry.name, author: "Brickworks", model: entry.text,
            listed: true, remixed_from: prompt.template, licence: "cc-by-4.0", made_with: "assistant",
            image: await picture(entry.text), tags: ["quick-build"],
            description: `${entry.about}\n\nThe house's entry for this week's quick build, ${prompt.title}. `
              + "Designed by Claude for Brickworks." } });
          did.push({ prompt: n(prompt.id), entry: made?.id || null, entered: made?.prompt?.entered === true });
        }
      }
      if (prompt.state === "ended" && Array.isArray(prompt.entries) && prompt.entries.length) {
        const entries = [];
        for (const one of prompt.entries) {
          const text = await readModel(one.model);
          if (!text) continue;
          entries.push({ ...one, text, ...(await measure(text)) });
        }
        if (!entries.length) continue;
        const { text } = stackText(prompt, entries, origin);
        const makers = new Set(entries.map((one) => one.handle || one.author)).size;
        const made = await publishAs({ test: tests, body: { name: `${prompt.title}: the stack`, author: "Brickworks",
          model: text, listed: true, licence: "cc-by-4.0", made_with: "hand", image: await picture(text),
          tags: ["quick-build", "stack"],
          description: `Every entry of the week's quick build, ${prompt.title}: ${entries.length} `
            + `${entries.length === 1 ? "model" : "models"} by ${makers} ${makers === 1 ? "builder" : "builders"}, `
            + "one on the next, each its own sub-model credited to its maker. Open it to turn it, or build it." } });
        if (!made?.id) throw new Error(`the stack of ${prompt.id} was not published`);
        const kept = await rpc("prompt_stack_set", { challenge_id: prompt.id, model_id: made.id });
        did.push({ prompt: n(prompt.id), stack: made.id, entries: entries.length, kept: kept?.kept === true });
      }
    }
    const outcome = did.length ? "done" : "unchanged";
    await rpc("cron_end", { run: begun.run, holder, outcome, said: { tests, did } });
    return { outcome, did };
  } catch (trouble) {
    await rpc("cron_end", { run: begun.run, holder, outcome: "failed",
      said: { tests, did, error: String(trouble?.message || trouble).slice(0, 300) } }).catch(() => null);
    throw trouble;
  }
}

