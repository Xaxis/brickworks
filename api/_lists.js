// Collections first-class (2026-10-24, supabase/collection_follows.sql,
// docs/SOCIAL.md U11): a public collection's cover, made of its models'
// pictures; following one, so what is put in it is in your feed; and the
// collections a model is in, which its page counts and links.
//
//   GET  ?op=list_follows&id=X   X's followers, and with the session whether
//                                the caller follows it, and may (why not, in
//                                words)
//   POST ?op=list_follow         (session) {id, on}: follow collection X, or
//                                let it go
//
// api/people.js answers the requests with these and draws a collection's
// page; api/share.js asks listsOf for a model's page.
//
// Who may follow and what may be followed is the database's to say
// (list_follow_trouble), and its trigger says it again whatever writes:
// follows.sql's rules, an account 13 or over, not taken out, following a
// public collection not its own, counted with following people (60 an hour,
// 300 a day). Its owner is told nothing; nobody's follows are listed.
//
// Until collection_follows.sql is applied its functions are not there
// (404): a collection's page shows no Follow and no count, a model's page
// no collections, and everything else is as before.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { Unacceptable, count, escapeHtml } from "./_directory.js";
import { pictureOf } from "./_card.js";

const ID = /^[A-Za-z0-9]{10}$/;
const NOT_THERE = /: 404$/;
export const NOT_YET = "Following collections is not open on Brickworks yet.";
/// How many of the collections a model is in its page shows as cards.
export const LISTS_SHOWN = 12;

// What a refusal from collection_follows.sql says, and its status.
export const WORDS = {
  sign_in: [401, "Sign in to follow collections: we email you a code, no password."],
  nobody: [404, "There is no public collection here to follow."],
  yourself: [409, "That is your own collection."],
  barred: [403, "Brickworks took this account out of the gallery, so it cannot follow anything."],
  ask_first: [422, "Brickworks asks everyone one question first. Sign in again, in the app or on "
    + "brickworks.diy, to answer it, then follow."],
  under_13: [422, "Following is for people 13 and over, because a follow is counted in public. "
    + "Building, your models and sharing by link are all yours."],
  limit: [429, "That is a lot of following in a short time: try again in an hour."],
};

function refused(code) {
  const [status, words] = WORDS[code] || [400, "That could not be done."];
  return new Unacceptable(words, status);
}

/// An rpc of collection_follows.sql, or [missing]'s answer when the file is
/// not applied.
async function call(name, body, missing) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || ""))) return missing();
    throw trouble;
  }
}

const who = async (request) => (bearer(request) ? (await verify(bearer(request), request)).sub : null);
const idOf = (given) => (ID.test(String(given ?? "")) ? String(given) : "");

/// list_follow_state's answer, as the pages are given it.
function stateSaid(state) {
  const trouble = state.trouble || null;
  return { ready: true, followers: Number(state.followers) || 0, you_follow: state.you_follow === true,
    mine: state.mine === true, may: !trouble, why_not: trouble ? WORDS[trouble]?.[1] || "" : "" };
}

/// Collection [id]'s follows as [asker] sees them: {ready, followers,
/// you_follow, mine, may, why_not}; ready false before the file is
/// applied; null for a collection nobody may follow.
export async function listFollowsOf(id, asker = null) {
  const state = await call("list_follow_state", { asker, list: id }, () => ({ missing: true }));
  if (state && state.missing) return { ready: false, followers: 0, you_follow: false, mine: false, may: false, why_not: NOT_YET };
  return state && typeof state === "object" ? stateSaid(state) : null;
}

export async function getListFollows(request, response) {
  const asker = await who(request);
  response.setHeader("Cache-Control", "private, no-store");
  const id = idOf(request.query?.id);
  if (!id) throw refused("nobody");
  const state = await listFollowsOf(id, asker);
  if (!state) throw refused("nobody");
  return response.status(200).json({ id, ...state, signed_in: Boolean(asker) });
}

export async function listFollow(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const asker = await who(request);
  if (!asker) throw refused("sign_in");
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const id = idOf(body.id);
  if (!id) throw refused("nobody");
  if (typeof body.on !== "boolean") throw new Unacceptable("say on: true or on: false");
  const said = await call("list_follow", { account: asker, list: id, following: body.on }, () => ({ missing: true }));
  if (said && said.missing) throw new Unacceptable(NOT_YET, 503);
  if (!said || said.refused) throw refused(said?.refused || "nobody");
  return response.status(200).json({ id, ...stateSaid(said), signed_in: true });
}

// ---------------------------------------------------------------------------
// The collections a model is in.

/// The public collections model [id] is in: {count, lists: [{id, name,
/// count, by}]}, the one it was put in last first; with [tests] (a test
/// model's own page) a test account's too. Nothing before the file is
/// applied, or when the database does not answer: the page is drawn
/// without them, never refused.
export async function listsOf(id, tests = false) {
  const none = { count: 0, lists: [] };
  const said = await call("model_lists", { model: id, tests, most: LISTS_SHOWN }, () => none).catch(() => none);
  if (!said || typeof said !== "object") return none;
  const lists = (Array.isArray(said.lists) ? said.lists : []).filter((list) => ID.test(String(list?.id)));
  return { count: Math.max(Number(said.count) || 0, lists.length), lists };
}

// ---------------------------------------------------------------------------
// A collection's cover.

/// The pictures on each public collection's cover: up to four of its models
/// in the gallery, the newest put in first. id -> [picture].
export async function coversOf(lists, tests) {
  const shown = lists.filter((list) => ID.test(String(list.id))).slice(0, 24);
  const items = await Promise.all(shown.map((list) =>
    db(`model_collection_items?collection=eq.${list.id}&select=model&order=at.desc&limit=12`).catch(() => [])));
  const ids = [...new Set(items.flat().map((row) => row.model).filter((id) => ID.test(String(id))))];
  const rows = ids.length ? await db(`shared_models?id=in.(${ids.join(",")})&published=is.true&listed=is.true`
    + "&barred=is.false&select=id,has_image,has_thumb,updated_at,test") : [];
  const pictures = new Map(rows.filter((row) => tests || !row.test)
    .map((row) => [row.id, pictureOf({ id: row.id, thumb: row.has_thumb ? `?v=${(Date.parse(row.updated_at || "") || 0).toString(36)}` : null,
      image: row.has_image })]));
  return new Map(shown.map((list, at) => [list.id, items[at].map((row) => pictures.get(row.model)).filter(Boolean).slice(0, 4)]));
}

/// A cover: up to four pictures kept wide, or what it waits for.
export function mosaicHtml(pictures) {
  return `<div class="mosaic n${pictures.length}">${pictures.length ? pictures.map((src) =>
    `<img src="${escapeHtml(src)}" alt="" width="1200" height="630" loading="lazy" decoding="async">`).join("")
    : "<span>No pictures yet</span>"}</div>`;
}

/// A public collection as a card: its cover, its name, how many; and whose,
/// with [by] (a model's page, where the collections are anybody's).
export function listCardHtml(list, covers, { by = false } = {}) {
  const whose = by && list.by && list.by.name ? ` · ${escapeHtml(list.by.name)}` : "";
  return `<a class="list-card" href="/c/${escapeHtml(list.id)}" data-id="${escapeHtml(list.id)}">`
    + mosaicHtml(covers.get(list.id) || [])
    + `<div class="words"><b>${escapeHtml(list.name)}</b><span>${escapeHtml(count(list.count, "model"))}${whose}</span></div></a>`;
}
