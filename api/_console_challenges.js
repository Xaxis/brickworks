// The owner's console, part C (console3, 2026-11-13; docs/ADMIN.md): one
// challenge whole, for Challenges (/admin#challenges/<id>).
//
//   challengeView   GET ?op=challenge_view&challenge=N[&tests=1]: the
//                   challenge as the console lists it (challenge_list), its
//                   entries in their two groups (by hand, with the
//                   assistant), each with its model, whose it is, when it
//                   came, its votes and whether it keeps the rules today,
//                   and where it does not, what failed (console3.sql
//                   challenge_admin_entries); the winners once it has
//                   ended; and what visitors see of it now (the same answer
//                   /challenge?id=N draws from, challenge_page_at), or when
//                   they will first see it
//
//   challengeRounds     POST ?op=challenge_rounds {challenge, entries_until,
//                       votes_from, judge_name, judge_handle, cover}: its
//                       rounds (entries, then the judges' shortlist, then a
//                       fan vote), the guest judge named on its page and
//                       its cover picture, all given each time
//                       (supabase/challenge_rounds.sql challenge_rounds_set)
//   challengeShortlist  POST ?op=shortlist {challenge, models}: the
//                       shortlist, up to five in each group, all at once,
//                       while the judges choose (challenge_shortlist_set)
//
// Setting, ending and planning are part A's acts (api/admin.js).

import { db } from "./_db.js";
import { allUsers } from "./_console.js";

const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^@?[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/i;
const body = (request) => (request.body && typeof request.body === "object" ? request.body : {});
/// One line of words, its controls taken out and its spaces made one (a
/// zero-width one too); null when nothing is left.
const line = (given) => String(given ?? "").normalize("NFKC").replace(/[\u0000-\u001f\u007f-\u009f\u00ad\u061c\u180e\u200b-\u200f\u2028-\u202f\u2060-\u206f\ufeff]+/g, " ")
  .replace(/\s+/g, " ").trim() || null;

/// Why the rounds were refused, in words (challenge_rounds_set).
const ROUNDS_SAID = {
  no_challenge: [404, "There is no challenge by that number."],
  ended: [409, "It has ended: its rounds, judge and cover stay as they were."],
  days: [422, "Give both days or neither: the last day of entries on or after its first day, and the fan vote's first day after it and on or before its last."],
  voting: [409, "The fan vote is open: its days stay as they are. The judge and the cover may still change."],
  votes: [409, "Votes are already in: rounds are set before anybody votes, so every vote is for the shortlist."],
  shortlisted: [409, "A shortlist is out: clear it before entries open again or it runs in one round."],
  no_judge: [422, "No profile shown in public has that handle. Leave it empty to name the judge without a link."],
  judge_name: [422, "Name the judge in at most 60 characters."],
  cover: [422, "The cover must be a model in the gallery: give its link's ten characters."],
};

/// Why the shortlist was refused, in words (challenge_shortlist_set).
const SHORTLIST_SAID = {
  no_challenge: [404, "There is no challenge by that number."],
  not_rounds: [409, "It runs in one round: set its rounds first, with the day entries close."],
  entries_open: [409, "Entries are still coming in: the shortlist is chosen once they close."],
  voting: [409, "The fan vote is open: the shortlist stays as it is."],
  ended: [409, "It has ended."],
  too_many: [422, "At most five in each group."],
  not_entry: [422, "One of those is not an entry shown in it."],
  breaks: [422, "One of those no longer keeps the rules."],
};

/// POST ?op=challenge_rounds: challenge N's rounds, guest judge and cover.
export async function challengeRounds(request, response) {
  const given = body(request);
  const id = Number(request.query?.challenge ?? given.challenge);
  if (!Number.isInteger(id) || id < 1) return response.status(400).json({ error: "name a challenge: ?challenge=<number>" });
  const day = (value) => (value === null || value === undefined || value === "" ? null : String(value));
  const [entriesUntil, votesFrom] = [day(given.entries_until), day(given.votes_from)];
  for (const value of [entriesUntil, votesFrom]) {
    if (value !== null && !(DATE.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`))
      && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value)) {
      return response.status(422).json({ error: "A day is on the calendar, as YYYY-MM-DD.", refused: "days" });
    }
  }
  const judgeName = line(given.judge_name);
  // Over the limit is refused in words, never cut (the field has no maxLength).
  if (judgeName && [...judgeName].length > 60) return response.status(422).json({ error: ROUNDS_SAID.judge_name[1], refused: "judge_name" });
  const handle = line(given.judge_handle);
  if (handle && !HANDLE.test(handle)) return response.status(422).json({ error: ROUNDS_SAID.no_judge[1], refused: "no_judge" });
  const cover = line(given.cover);
  if (cover && !ID.test(cover)) return response.status(422).json({ error: ROUNDS_SAID.cover[1], refused: "cover" });
  let made;
  try {
    made = await db("rpc/challenge_rounds_set", { method: "POST", body: { challenge_id: id, entries_until: entriesUntil,
      votes_from: votesFrom, judge_name: judgeName, judge_handle: handle ? handle.replace(/^@/, "").toLowerCase() : null,
      cover_model: cover } });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(503).json({ error: "Rounds are not open yet: supabase/challenge_rounds.sql is not applied." });
    throw trouble;
  }
  if (made?.refused) {
    const [status, words] = ROUNDS_SAID[made.refused] || [409, "Not set."];
    return response.status(status).json({ error: words, refused: made.refused });
  }
  return response.status(200).json({ challenge: id, rounds: made?.rounds ?? null });
}

/// POST ?op=shortlist: challenge N's shortlist, all at once.
export async function challengeShortlist(request, response) {
  const given = body(request);
  const id = Number(request.query?.challenge ?? given.challenge);
  if (!Number.isInteger(id) || id < 1) return response.status(400).json({ error: "name a challenge: ?challenge=<number>" });
  if (!Array.isArray(given.models) || given.models.length > 50 || !given.models.every((one) => ID.test(String(one)))) {
    return response.status(422).json({ error: "Give the shortlist as models, each its link's ten characters: at most five in each group." });
  }
  let made;
  try {
    made = await db("rpc/challenge_shortlist_set", { method: "POST", body: { challenge_id: id, models: given.models.map(String) } });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(503).json({ error: "Rounds are not open yet: supabase/challenge_rounds.sql is not applied." });
    throw trouble;
  }
  if (made?.refused) {
    const [status, words] = SHORTLIST_SAID[made.refused] || [409, "Not set."];
    return response.status(status).json({ error: words, refused: made.refused, ...(made.model ? { model: made.model } : {}),
      ...(made.way ? { way: made.way } : {}) });
  }
  return response.status(200).json({ challenge: id, shortlist: made?.shortlist || [], round: made?.round ?? null });
}

/// What failed of an entry's rules, in words, from challenge_check.
export function failedOf(check) {
  if (!check || check.ok !== false) return [];
  const said = [];
  if (check.parts && check.parts.ok === false) said.push(`${check.parts.has} parts, over the ${check.parts.most} allowed`);
  if (check.set && check.set.ok === false) {
    said.push(`${check.set.short_lots ?? (check.set.short || []).length} lots not in set ${check.set.number}`
      + `${(check.set.short || []).length ? ` (${check.set.short.slice(0, 3).map((one) => `${one.part} in ${one.colour}: ${one.need} for ${one.have}`).join("; ")})` : ""}`);
  }
  if (check.tested && check.tested.ok === false) said.push("not marked Tested");
  return said.length ? said : ["the rules, as the check says"];
}

/// One challenge whole, or null when there is none by that number.
export async function challengeView(id, tests) {
  let listed;
  try {
    listed = (await db("rpc/challenge_list", { method: "POST", body: { tests } })) || [];
  } catch (trouble) {
    if (notYet(trouble)) return { ready: false };
    throw trouble;
  }
  const one = listed.find((c) => Number(c.id) === id);
  if (!one) return null;
  const [entries, page, users, rounds] = await Promise.all([
    db("rpc/challenge_admin_entries", { method: "POST", body: { p_challenge: id } }).catch((t) => (notYet(t) ? null : Promise.reject(t))),
    db("rpc/challenge_page_at", { method: "POST", body: { challenge_id: id, tests } }).catch((t) => (notYet(t) ? undefined : Promise.reject(t))),
    allUsers().catch(() => []),
    // Its rounds, judge, shortlist and cover (supabase/challenge_rounds.sql); null before it.
    db("rpc/challenge_rounds_of", { method: "POST", body: { challenge_id: id } }).catch((t) => (notYet(t) ? null : Promise.reject(t))),
  ]);
  const emails = new Map(users.map((user) => [user.id, user.email || null]));
  const groups = { hand: [], assistant: [] };
  for (const entry of entries || []) {
    (groups[entry.way] || (groups[entry.way] = [])).push({ model: entry.model, name: entry.name ?? null, parts: entry.parts ?? null,
      email: emails.get(entry.owner) || null, at: entry.at, votes: Number(entry.votes) || 0, keeps: entry.keeps !== false,
      failed: entry.keeps === false ? failedOf(entry.check) : [], shown: entry.listed === true && entry.barred !== true });
  }
  for (const list of Object.values(groups)) list.sort((a, b) => b.votes - a.votes || String(a.at).localeCompare(String(b.at)));
  // What visitors see: the page /challenge?id=N draws, or when it opens to them.
  const told = one.announced_at && Date.parse(one.announced_at) > Date.now() ? one.announced_at : null;
  const shown = page && typeof page === "object" ? page : null;
  const onList = new Set((rounds?.shortlist || []).map((entry) => entry.model));
  for (const list of Object.values(groups)) for (const entry of list) entry.shortlisted = onList.has(entry.model);
  return {
    ready: true,
    challenge: one,
    rounds_ready: rounds !== null,
    rounds: rounds ? { rounds: rounds.rounds === true, entries_until: rounds.entries_until ?? null, votes_from: rounds.votes_from ?? null,
      round: rounds.round ?? null, shortlisted_at: rounds.shortlisted_at ?? null, judge: rounds.judge ?? null,
      cover: rounds.cover?.id ? { id: rounds.cover.id, name: rounds.cover.name ?? null } : null } : null,
    entries_ready: entries !== null,
    groups,
    failing: Object.values(groups).flat().filter((entry) => !entry.keeps).length,
    visitors: {
      shown: Boolean(shown),
      told_from: told,
      state: shown?.state ?? one.state,
      entries: shown ? (shown.groups || []).reduce((n, g) => n + (g.entries || []).length, 0) : 0,
      page: `/challenge?id=${id}${one.test ? "&tests=1" : ""}`,
      said: shown ? "" : one.test && !tests ? "a test's: only the checks see it"
        : told ? "not told to visitors yet" : one.state === "ended" ? "ended before it opened" : "not shown to visitors",
    },
  };
}
