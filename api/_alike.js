// More like a designer (2026-10-30, docs/SOCIAL.md section 7, item 9): on a
// person's page (/u/<handle>), up to six designers whose work is closest to
// theirs, each with Follow in place (web/follow.js). api/people.js answers
// ?op=alike&handle=X with designersAlike.
//
// Closeness is what their models in the gallery share: the themes (a
// model's kind; "Something else" is no theme), the tags (not ai-designed
// and brickify, which say how a model was made, not what it is of), and
// the parts, colours aside: of the parts either designer uses, the share
// both use (supabase/designers_alike.sql, which alone may read what each
// model needs). Each theme and each tag in common counts one, and the
// parts up to three, all of them in common. One theme or tag in common is
// close, or a third of their parts; a few of the same bricks, which every
// model has, are not. Between equals, the one more of the person's
// followers also follow comes first, then the same order every visit.
//
// Never the person, nor whoever asks, nor anybody they follow already;
// only a profile that may be followed (follows.sql follow_state: shown in
// public, 13 or over, not taken out) with a model in the gallery in its own
// name. Who follows whom only orders the list, and is never said (D1).
//
// Until designers_alike.sql is applied the parts and the followers in
// common are not known: closeness is the themes and the tags alone.

import { db } from "./_db.js";
import { ASSISTANT_TAGS, kindLabel } from "./_directory.js";
import { followsOf } from "./_follows.js";

export const ALIKE_MOST = 6;
// The parts all in common count as three themes or tags would.
export const PARTS_WEIGHT = 3;
// A third of their parts in common is close on its own.
export const PARTS_CLOSE = 1 / 3;
// How many of the closest are looked at to find six to show: those the
// asker follows, and any whose profile is not shown, are passed over.
const LOOKED_AT = 24;
const NOT_THERE = /: 404$/;
const TAG = /^[\p{L}\p{N}][\p{L}\p{N} -]{0,23}$/u;

/// A designer's themes: their kinds, "other" being none.
const themesOf = (kinds) => [...new Set((kinds || []).map(String).filter((kind) => kindLabel(kind) && kind !== "other"))];
/// A designer's subjects: their tags, less the two that say how it was made.
const subjectsOf = (tags) => [...new Set((tags || []).map(String).filter((tag) => TAG.test(tag) && !ASSISTANT_TAGS.includes(tag)))];

/// The designers closest to one. [mine]: {kinds, tags} of their models;
/// [theirs]: each other designer, {id, kinds, tags, parts, common}, parts
/// being the share of parts in common (0 to 1) and common their followers
/// in common; one met twice is one, with what both said. Closest first,
/// [most] at most, each with only what they share ({kinds, tags}) and how
/// close ({close}). Pure.
export function closestDesigners(mine, theirs, { most = ALIKE_MOST } = {}) {
  const kinds = new Set(themesOf(mine.kinds));
  const tags = new Set(subjectsOf(mine.tags));
  const each = new Map();
  for (const one of theirs || []) {
    const id = String(one?.id || "");
    if (!id) continue;
    const was = each.get(id) || { id, kinds: [], tags: [], parts: 0, common: 0 };
    each.set(id, { ...one, id, kinds: [...was.kinds, ...(one.kinds || [])], tags: [...was.tags, ...(one.tags || [])],
      parts: Math.max(was.parts, Math.min(1, Math.max(0, Number(one.parts) || 0))),
      common: Math.max(was.common, Math.floor(Number(one.common) || 0)) });
  }
  return [...each.values()].map((one) => {
    const shared = { kinds: themesOf(one.kinds).filter((kind) => kinds.has(kind)).sort(),
      tags: subjectsOf(one.tags).filter((tag) => tags.has(tag)).sort() };
    return { ...one, ...shared, close: shared.kinds.length + shared.tags.length + PARTS_WEIGHT * one.parts };
  }).filter((one) => one.kinds.length + one.tags.length > 0 || one.parts >= PARTS_CLOSE)
    .sort((a, b) => b.close - a.close || b.common - a.common || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
    .slice(0, most);
}

/// What a designer shares with the person, in a line under their name: the
/// themes by name, then up to three tags (not one a theme's name says
/// already: "castle" after Castles and fantasy), then the parts when a
/// third or more are the same. Pure.
export function alikeSaid({ kinds = [], tags = [], parts = 0 }) {
  const themes = kinds.map(kindLabel).filter(Boolean);
  const named = (tag) => kinds.includes(tag) || themes.some((theme) => theme.toLowerCase().includes(tag.toLowerCase()));
  const said = [themes.join(", "), tags.filter((tag) => !named(tag)).slice(0, 3).join(", "),
    parts >= PARTS_CLOSE ? "many of the same parts" : ""].filter(Boolean).join(" · ");
  return said ? said[0].toUpperCase() + said.slice(1) : "";
}

/// The gallery's rule for a designer's own models, as a PostgREST filter:
/// published, listed, not taken out, in their own name; a test model only
/// for a probe ([tests]).
const listed = (tests) => `published=is.true&listed=is.true&barred=is.false&author=not.is.null${tests ? "" : "&test=is.false"}`;

/// The parts and the followers in common with [account]'s, from
/// designers_alike.sql: [{id, parts, common}], none before it is applied.
async function partsAndFollowers(account, tests) {
  try {
    const rows = await db("rpc/designers_alike", { method: "POST", body: { wanted: account, tests } });
    return (rows || []).map((row) => ({ id: String(row.account), parts: Number(row.parts) || 0, common: Number(row.common) || 0 }));
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || ""))) return [];
    throw trouble;
  }
}

/// The designers alike [person] ({account, handle, name}), as [asker] (an
/// account, or null) may be shown them: [{handle, name, said, kinds, tags,
/// follow}], follow being how the asker stands with each, as
/// ?op=follows says it (followsOf), so Follow is drawn at once. None for a
/// person with no model in the gallery: there is no work to be like.
export async function designersAlike(person, asker, tests) {
  const mine = await db(`shared_models?owner=eq.${person.account}&${listed(tests)}&select=kind,tags&limit=500`);
  if (!mine.length) return [];
  const kinds = themesOf(mine.map((row) => row.kind));
  const tags = subjectsOf(mine.flatMap((row) => row.tags || []));
  const any = [kinds.length ? `kind.in.(${kinds.join(",")})` : "", tags.length ? `tags.ov.{${tags.map((tag) => `"${tag}"`).join(",")}}` : ""]
    .filter(Boolean).join(",");
  const [overlap, measured] = await Promise.all([
    any ? db(`shared_models?owner=neq.${person.account}&${listed(tests)}&or=(${encodeURIComponent(any)})`
      + "&select=owner,kind,tags&limit=2000") : [],
    partsAndFollowers(person.account, tests),
  ]);
  const closest = closestDesigners({ kinds, tags }, [
    ...overlap.map((row) => ({ id: String(row.owner), kinds: [row.kind], tags: row.tags || [] })),
    ...measured,
  ], { most: LOOKED_AT }).filter((one) => one.id !== person.account && one.id !== asker);
  if (!closest.length) return [];
  const people = await db(`people?account=in.(${closest.map((one) => one.id).join(",")})&select=account,handle,name`);
  const named = new Map(people.map((one) => [one.account, one]));
  const out = [];
  // In the order of closeness, a few at a time, until six may be shown.
  const waiting = closest.filter((one) => named.has(one.id));
  while (out.length < ALIKE_MOST && waiting.length) {
    const batch = waiting.splice(0, ALIKE_MOST - out.length + 2);
    const states = await Promise.all(batch.map((one) => followsOf(named.get(one.id).handle, asker)));
    batch.forEach((one, i) => {
      const state = states[i];
      if (!state || !state.ready || state.mine || state.you_follow || out.length >= ALIKE_MOST) return;
      const who = named.get(one.id);
      out.push({ handle: who.handle, name: who.name, said: alikeSaid(one), kinds: one.kinds, tags: one.tags,
        follow: { you_follow: false, mine: false, followers: state.followers, may: state.may, why_not: state.why_not,
          signed_in: Boolean(asker) } });
    });
  }
  return out;
}
