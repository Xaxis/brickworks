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
// Read only: setting, ending and planning are part A's acts (api/admin.js).

import { db } from "./_db.js";
import { allUsers } from "./_console.js";

const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));

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
  const [entries, page, users] = await Promise.all([
    db("rpc/challenge_admin_entries", { method: "POST", body: { p_challenge: id } }).catch((t) => (notYet(t) ? null : Promise.reject(t))),
    db("rpc/challenge_page_at", { method: "POST", body: { challenge_id: id, tests } }).catch((t) => (notYet(t) ? undefined : Promise.reject(t))),
    allUsers().catch(() => []),
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
  return {
    ready: true,
    challenge: one,
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
