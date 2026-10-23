// Challenges (2026-10-19, supabase/challenges.sql): one building challenge
// at a time, with rules the site checks.
//
//   GET  ?op=challenge            /challenge's: the challenge shown now (open,
//                                 or the next, or the last that ended with
//                                 entries), its rules in words, its entries
//                                 as gallery cards in their two groups, and
//                                 once it ended, the votes and the winners.
//                                 With the sign-in, also the caller's: whom
//                                 they voted for in each group, and whether
//                                 they may vote. Kept by the CDN only when
//                                 asked without a sign-in.
//   GET  ?op=challenge_entry&id=X (session) for a model's page: the
//                                 challenge open now, whether X is in it, and
//                                 what its rules say of X. Only X's owner is
//                                 told anything.
//   POST ?op=enter                (session) {model, way}: X entered, built by
//                                 hand or with the assistant; refused in words
//                                 that name each rule it breaks (422)
//   POST ?op=withdraw             (session) {model}: the entry taken back
//   POST ?op=vote                 (session) {challenge, model}: one vote in
//                                 the model's group
//
// The rules are the database's (challenge_enter, challenge_vote), checked on
// the model as it is stored; what is here is the words. A test account's
// models enter only a test challenge, and it votes only in one: the flows'
// own, which only a page asked with tests=1 shows.

import { bearer, isTestAccount, verify } from "./_auth.js";
import { COLOUR_NAMES } from "./_colours.js";
import { db } from "./_db.js";
import { withFaces } from "./_faces.js";
import { TESTS_CACHE, Unacceptable, cardOf, testsAsked } from "./_directory.js";

const ID = /^[A-Za-z0-9]{10}$/;
export const WAYS = { hand: "Built by hand", assistant: "Built with the assistant" };
/// What /challenge's answer may be kept for, asked without a sign-in.
export const PAGE_CACHE = "public, max-age=0, s-maxage=30, stale-while-revalidate=30";

const missing = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const n = (value) => Number(value) || 0;
const count = (value, one, many = `${one}s`) => `${n(value).toLocaleString("en-US")} ${n(value) === 1 ? one : many}`;
const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
export const dayOf = (iso) => DAY.format(new Date(`${String(iso).slice(0, 10)}T00:00:00Z`));
const colourOf = (code) => COLOUR_NAMES[code] || `colour ${code}`;

const ASK_FIRST = "Brickworks asks everyone one question first. Sign in again, in the app or on brickworks.diy, "
  + "to answer it, then try this again.";

/// Why an entry was refused, in words, with its status.
const ENTER_SAID = {
  no_model: [404, "There is no shared model at that link."],
  not_yours: [403, "Only the designer who shared a model can enter it."],
  under_13: [422, "Challenges are for people 13 and over, so this account cannot enter one. Building, your models "
    + "and sharing them by link are yours all the same."],
  not_asked: [422, ASK_FIRST],
  barred: [422, "This account was taken out of the gallery, so it cannot enter a challenge."],
  not_in_gallery: [422, "Only a model in the gallery with your name on it can enter: share it again with "
    + "Show it in the gallery ticked and your name on it."],
  no_challenge: [409, "No challenge is open just now."],
  entered: [409, "It is in this challenge already."],
  three: [409, "Three of your models are in this challenge already: that is the most."],
};

/// Why a vote was refused, in words, with its status.
const VOTE_SAID = {
  not_open: [409, "Voting is not open in that challenge."],
  under_13: [422, "Voting is for people 13 and over, so this account cannot vote. The entries are here to look at "
    + "all the same."],
  not_asked: [422, ASK_FIRST],
  barred: [422, "This account was taken out of the gallery, so it cannot vote."],
  no_entry: [404, "That model is not in this challenge."],
  own: [422, "You cannot vote for your own model."],
  breaks: [422, "That entry no longer keeps the challenge's rules, so it cannot be voted for."],
  voted: [409, "You have voted in this group already: one vote in each."],
};

/// The rules a challenge has, in words: "At most 200 parts", ...
export function rulesSaid(rules) {
  const said = [];
  if (rules?.most_parts) said.push(`At most ${count(rules.most_parts, "part")}`);
  if (rules?.set_number) {
    said.push(`Only parts of set ${rules.set_number}${rules.set_name ? `, ${rules.set_name}` : ""}: no more of each, `
      + "in its colour, than the set has");
  }
  if (rules?.tested) said.push("Marked Tested: it stands at every step, and every part is made in its colour");
  return said;
}

/// The rules [check] (challenge_check) says a model breaks, each in words:
/// [{rule, said}].
export function brokenSaid(check) {
  const broken = [];
  if (check?.parts && !check.parts.ok) {
    broken.push({ rule: "parts", said: `It has ${count(check.parts.has, "part")}: this challenge allows at most `
      + `${n(check.parts.most).toLocaleString("en-US")}.` });
  }
  if (check?.set && !check.set.ok) {
    const set = `set ${check.set.number}${check.set.name ? ` (${check.set.name})` : ""}`;
    if (!check.set.counted) {
      broken.push({ rule: "set", said: `Its parts have not been counted yet, so they cannot be held to ${set}: `
        + "share it again from the app, then enter it." });
    } else {
      const lots = (check.set.short || []).slice(0, 5).map((one) => `${one.part} in ${colourOf(one.colour)} `
        + `(it needs ${n(one.need)}, the set has ${n(one.have)})`);
      const more = n(check.set.short_lots) - lots.length;
      broken.push({ rule: "set", said: `${count(check.set.short_lots, "of its parts is", "of its parts are")} not in `
        + `${set}, or not as many: ${lots.join("; ")}${more > 0 ? `; and ${more} more` : ""}.` });
    }
  }
  if (check?.tested && !check.tested.ok) {
    broken.push({ rule: "tested", said: "Its newest version is not marked Tested: the app tests a model as it is "
      + "shared (it stands at every step, every part made in its colour)." });
  }
  return broken;
}

/// The caller, from their sign-in: {account, test}.
async function caller(request) {
  const claims = await verify(bearer(request), request);
  return { account: claims.sub, test: isTestAccount(claims) };
}

const body = (request) => (request.body && typeof request.body === "object" ? request.body : {});

/// A challenge as the pages are given it.
function challengeOf(origin, page, wins = new Map()) {
  const entries = (page.entries || []).filter((one) => one && ID.test(String(one.model || "")) && one.card);
  const won = new Map((page.winners || []).map((one) => [`${one.way}/${one.model}`, n(one.votes)]));
  const entryOf = (one) => ({ ...cardOf(origin, one.card), way: one.way, entered_at: one.at, keeps: one.keeps === true,
    votes: one.votes === null || one.votes === undefined ? null : n(one.votes),
    winner: won.has(`${one.way}/${one.model}`), won: wins.get(one.model) || [] });
  return {
    id: n(page.id), title: String(page.title), brief: String(page.brief), starts_on: page.starts_on, ends_on: page.ends_on,
    state: page.state, test: page.test === true, settled: page.settled === true,
    rules: { most_parts: page.rules?.most_parts ?? null,
      set: page.rules?.set_number ? { number: page.rules.set_number, name: page.rules.set_name ?? null } : null,
      tested: page.rules?.tested === true },
    rules_said: rulesSaid(page.rules),
    days_said: `${dayOf(page.starts_on)} to ${dayOf(page.ends_on)}`,
    groups: Object.entries(WAYS).map(([way, label]) => ({ way, label,
      entries: entries.filter((one) => one.way === way).map(entryOf) })),
    winners: (page.winners || []).map((one) => ({ way: one.way, label: WAYS[one.way] || one.way, model: one.model,
      votes: n(one.votes) })),
  };
}

/// The challenge page's facts, settling a challenge that has ended and was
/// not yet (challenge_settle): {ready, page}.
async function pageOf(tests) {
  let page;
  try {
    page = await db("rpc/challenge_page", { method: "POST", body: { tests } });
  } catch (trouble) {
    if (missing(trouble)) return { ready: false, page: null };
    throw trouble;
  }
  if (page && page.state === "ended" && !page.settled) {
    await db("rpc/challenge_settle", { method: "POST", body: { challenge_id: page.id } });
    page = await db("rpc/challenge_page", { method: "POST", body: { tests } });
  }
  return { ready: true, page };
}

/// What challenges [models] won, by model: Map id -> [{title, way, ends_on}].
/// Empty before challenges.sql.
export async function winsOf(models, tests = false) {
  const ids = [...new Set((models || []).filter((id) => ID.test(String(id || ""))))];
  if (!ids.length) return new Map();
  let rows;
  try {
    rows = await db("rpc/challenge_wins", { method: "POST", body: { models: ids, tests } });
  } catch (trouble) {
    if (missing(trouble)) return new Map();
    throw trouble;
  }
  const out = new Map();
  for (const row of rows || []) {
    if (!ID.test(String(row?.model || ""))) continue;
    if (!out.has(row.model)) out.set(row.model, []);
    out.get(row.model).push({ challenge: n(row.challenge), title: String(row.title), way: row.way, ends_on: row.ends_on,
      votes: n(row.votes) });
  }
  return out;
}

/// What a designer's models won: [{challenge, title, way, ends_on, model,
/// name, votes}], newest first. Empty before challenges.sql.
export async function winsBy(account, tests = false) {
  try {
    return ((await db("rpc/challenge_wins", { method: "POST", body: { owner: account, tests } })) || [])
      .filter((row) => ID.test(String(row?.model || "")));
  } catch (trouble) {
    if (missing(trouble)) return [];
    throw trouble;
  }
}

/// Cards with what each won (card.won: [{title, way, ...}]), for a list.
export async function withWins(cards, tests = false) {
  const wins = await winsOf(cards.map((card) => card.id), tests).catch(() => new Map());
  return cards.map((card) => (wins.has(card.id) ? { ...card, won: wins.get(card.id) } : card));
}

/// A card's line for a win: "Won “Small houses”, by hand".
export const wonSaid = (win) => `Won “${win.title}”${win.way === "assistant" ? ", with the assistant" : ", by hand"}`;

/// The gallery front's line: the challenge open now, or the next to open,
/// for anybody; null when there is none (or before challenges.sql).
export async function challengeLine(tests = false) {
  const row = await db("rpc/challenge_shown", { method: "POST", body: { tests } }).catch(() => null);
  if (!row || !row.id) return null;
  const today = new Date().toISOString().slice(0, 10);
  const state = row.ended_at || String(row.ends_on) < today ? "ended" : String(row.starts_on) > today ? "upcoming" : "open";
  if (state === "ended") return null;
  return { title: String(row.title), state, starts_on: row.starts_on, ends_on: row.ends_on,
    days_said: `${dayOf(row.starts_on)} to ${dayOf(row.ends_on)}` };
}

/// GET ?op=challenge.
export async function challenge(request, response, { origin }) {
  const tests = testsAsked(request.query || {});
  const who = bearer(request) ? await caller(request) : null;
  response.setHeader("Cache-Control", who || tests ? TESTS_CACHE : PAGE_CACHE);
  const { ready, page } = await pageOf(tests);
  if (!ready) return response.status(200).json({ ready: false, challenge: null });
  if (!page) return response.status(200).json({ ready: true, challenge: null, ...(who ? { you: { signed_in: true } } : {}) });
  const wins = await winsOf((page.entries || []).map((one) => one.model), tests);
  const shown = challengeOf(origin, page, wins);
  let you = null;
  if (who) {
    const mine = await db("rpc/challenge_mine", { method: "POST", body: { account: who.account, challenge_id: shown.id } });
    const open = shown.state === "open";
    const kind = shown.test === who.test;
    you = { signed_in: true, voted: { hand: mine?.voted?.hand ?? null, assistant: mine?.voted?.assistant ?? null },
      entries: mine?.entries || [], may_vote: open && kind && mine?.may_vote === true,
      why_not: !open ? (shown.state === "upcoming" ? "Voting opens with the challenge." : "Voting has closed.")
        : !kind ? "A test account votes only in a test challenge."
          : mine?.under_13 ? VOTE_SAID.under_13[1] : mine?.may_vote !== true ? ASK_FIRST : null };
  }
  return response.status(200).json(await withFaces({ ready: true, challenge: shown, ...(you ? { you } : {}) }));
}

/// GET ?op=challenge_entry&id=X: for X's own designer, the challenge open
/// now and X in it; for anybody else, {mine: false}.
export async function challengeEntry(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const who = await caller(request);
  const id = String(request.query?.id || "");
  if (!ID.test(id)) throw new Unacceptable("name a link: ?id=<ten characters>");
  const rows = await db(`shared_models?id=eq.${id}&published=is.true&select=id,owner,listed,author,barred`);
  const model = rows[0];
  if (!model || model.owner !== who.account) return response.status(200).json({ mine: false });
  let said;
  try {
    said = await db("rpc/challenge_for_model", { method: "POST", body: { account: who.account, model_id: id } });
  } catch (trouble) {
    if (missing(trouble)) return response.status(200).json({ mine: true, ready: false, challenge: null });
    throw trouble;
  }
  if (!said?.challenge) return response.status(200).json({ mine: true, ready: true, challenge: null });
  const c = said.challenge;
  return response.status(200).json({ mine: true, ready: true,
    challenge: { id: n(c.id), title: String(c.title), starts_on: c.starts_on, ends_on: c.ends_on,
      days_said: `${dayOf(c.starts_on)} to ${dayOf(c.ends_on)}`, rules_said: rulesSaid(c.rules) },
    entry: said.entry ? { way: said.entry.way, label: WAYS[said.entry.way], at: said.entry.at } : null,
    entries: n(said.entries), in_gallery: model.listed === true && model.author !== null && model.barred !== true,
    keeps: said.check?.ok === true, broken: brokenSaid(said.check) });
}

/// POST ?op=enter {model, way}.
export async function enter(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await caller(request);
  const given = body(request);
  const model = String(given.model || "");
  const way = String(given.way || "");
  if (!ID.test(model)) throw new Unacceptable("name a model by its link's id");
  if (!(way in WAYS)) throw new Unacceptable("say how it was built: way is hand or assistant");
  const said = await db("rpc/challenge_enter", { method: "POST", body: { account: who.account, model_id: model, way } });
  if (said?.entered) {
    return response.status(201).json({ entered: true, challenge: n(said.challenge), title: String(said.title), way,
      label: WAYS[way] });
  }
  if (said?.refused === "rules") {
    const broken = brokenSaid(said.check);
    return response.status(422).json({ error: `It does not keep this challenge's rules. ${broken.map((one) => one.said).join(" ")}`,
      refused: "rules", broken });
  }
  const [status, words] = ENTER_SAID[said?.refused] || [409, "It cannot enter just now."];
  return response.status(status).json({ error: words, refused: said?.refused ?? null });
}

/// POST ?op=withdraw {model}.
export async function withdraw(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await caller(request);
  const model = String(body(request).model || "");
  if (!ID.test(model)) throw new Unacceptable("name a model by its link's id");
  const gone = await db("rpc/challenge_withdraw", { method: "POST", body: { account: who.account, model_id: model } });
  if (gone !== true) return response.status(404).json({ error: "It is not in a challenge that is open." });
  return response.status(200).json({ model, withdrawn: true });
}

/// POST ?op=vote {challenge, model}.
export async function vote(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await caller(request);
  const given = body(request);
  const model = String(given.model || "");
  const id = Number(given.challenge);
  if (!ID.test(model)) throw new Unacceptable("name a model by its link's id");
  if (!Number.isInteger(id) || id < 1) throw new Unacceptable("name the challenge by its number");
  const said = await db("rpc/challenge_vote", { method: "POST",
    body: { account: who.account, challenge_id: id, model_id: model, tests: who.test } });
  if (said?.voted) return response.status(200).json({ voted: true, way: said.way, model: said.model });
  const [status, words] = VOTE_SAID[said?.refused] || [409, "That vote did not count."];
  return response.status(status).json({ error: words, refused: said?.refused ?? null, ...(said?.model ? { model: said.model } : {}) });
}
