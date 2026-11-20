// Blocking a person (2026-11-19, supabase/block.sql, docs/SOCIAL.md section
// 9). api/people.js answers the requests with these, and the gallery, the
// feed, comments and notifications ask them what to leave out.
//
//   GET  ?op=blocks              (session) whom the caller blocked, newest
//                                first: [{handle, name, picture, at}]; theirs
//                                alone, never kept by the CDN
//   POST ?op=block               (session) {handle, on}: block them (on:
//                                true) or unblock them (false); the same
//                                answer for a block already there
//
// Who blocked whom is the server's alone: the table is no client's to read
// (row security, every client role revoked). A person blocked (B) is never
// told: nothing here answers B with whether somebody blocked them, a
// refusal B meets says only that it cannot be done (WORDS.cannot_*), and the
// person who blocked (A) is told plainly why, since they did it.
//
// Until block.sql is applied its functions are not there (404): nothing is
// hidden, a block says it is not open yet, and the rest works as before.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { withFaces } from "./_faces.js";
import { Unacceptable } from "./_directory.js";

const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const ID = /^[A-Za-z0-9]{10}$/;
const NOT_THERE = /: 404$/;
export const NOT_YET = "Blocking is not open on Brickworks yet.";

/// What each refusal says, and its status. The cannot_ ones are what the
/// person blocked meets: true, and the same whoever's doing it is.
export const WORDS = {
  sign_in: [401, "Sign in to block somebody: we email you a code, no password."],
  nobody: [404, "Nobody here has that handle."],
  yourself: [409, "That is you: you cannot block yourself."],
  limit: [429, "That is a lot of blocking in a short time: try again in an hour."],
  most: [409, "You have blocked 1,000 people, the most there can be: unblock somebody first."],
  // To the person who blocked: what they did, and where to undo it.
  you_follow: [409, "You blocked them. Unblock them in Settings › Blocked people to follow them."],
  you_comment: [409, "You blocked this model’s designer. Unblock them in Settings › Blocked people to comment here."],
  you_reply: [409, "You blocked somebody in this conversation. Unblock them in Settings › Blocked people to reply here."],
  you_photo: [409, "You blocked this model’s designer. Unblock them in Settings › Blocked people to post a photo here."],
  you_list: [409, "You blocked whoever made this collection. Unblock them in Settings › Blocked people to follow it."],
  you_like: [409, "You blocked this model’s designer. Unblock them in Settings › Blocked people to like it."],
  you_remix: [409, "You blocked this model’s designer. Unblock them in Settings › Blocked people to remix it."],
  you_collect: [409, "You blocked this model’s designer. Unblock them in Settings › Blocked people to put it in a collection."],
  // To the person blocked: only that it cannot be done.
  cannot_follow: [403, "You can’t follow this profile."],
  cannot_comment: [403, "You can’t comment on this model."],
  cannot_reply: [403, "You can’t reply to this comment."],
  cannot_photo: [403, "You can’t post a photo of a build on this model."],
  cannot_list: [403, "You can’t follow this collection."],
  cannot_like: [403, "You can’t like this model."],
  // 409, not 403, as the publish's other refusals: the app answers a 403
  // (somebody else's link) by publishing again at a new link.
  cannot_remix: [409, "You can’t remix this model."],
  cannot_collect: [403, "You can’t put this model in a collection."],
};

export function refused(code) {
  const [status, words] = WORDS[code] || [400, "That could not be done."];
  return new Unacceptable(words, status);
}

/// An rpc of block.sql, or [missing]'s answer when the file is not applied.
async function call(name, body, missing) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || "")) && missing !== undefined) return missing();
    throw trouble;
  }
}

const who = async (request) => (bearer(request) ? (await verify(bearer(request), request)).sub : null);

/// A handle as given, or "" for one that cannot be anybody's.
export function handleOf(given) {
  // Pasted from a page, a handle may carry zero-width characters: dropped.
  const handle = String(given ?? "").replace(/[\u200b-\u200d\u2060\ufeff]/g, "").trim().toLowerCase();
  return HANDLE.test(handle) && !handle.includes("--") ? handle : "";
}

// ---------------------------------------------------------------------------
// What [account] blocked, for leaving it out.

/// Whom [account] blocked: [{handle, name, at}], the newest first; [] for
/// nobody signed in, or before block.sql.
export async function blockedBy(account) {
  if (!account) return [];
  const said = await call("block_list", { account }, () => []);
  return Array.isArray(said) ? said.filter((one) => HANDLE.test(String(one?.handle || ""))) : [];
}

/// The handles [account] blocked, as a Set (empty: nobody, or before the file).
export async function blockedHandles(account) {
  return new Set((await blockedBy(account)).map((one) => one.handle));
}

/// Of [ids], the models whose owner [account] blocked, as a Set: what
/// leaves their gallery, shelves, search and feed. Asked only for somebody
/// signed in; empty before the file.
export async function blockedModels(account, ids) {
  const wanted = [...new Set((ids || []).map(String))].filter((id) => ID.test(id));
  if (!account || !wanted.length) return new Set();
  const said = await call("block_models", { viewer: account, ids: wanted }, () => []);
  return new Set(Array.isArray(said) ? said.map(String) : []);
}

/// [cards] without those [gone] (a Set of ids) or by one of [handles] (a
/// Set): a card's own designer (by.handle) said as one they blocked. Pure.
export function withoutBlocked(cards, gone, handles = new Set()) {
  return (cards || []).filter((card) => card && !gone.has(String(card.id)) && !handles.has(String(card.by?.handle || "")));
}

/// [rows] (a feed's, or notifications') without those by somebody in
/// [handles] or about a model in [gone]. Pure.
export function rowsWithout(rows, handles, gone = new Set()) {
  return (rows || []).filter((row) => !handles.has(String(row?.by?.handle || "")) && !gone.has(String(row?.model || "")));
}

/// [comments] as [viewer] may see them on a model: without the ids in
/// [hidden] (block_hidden's), nor any reply whose comment is not shown, so
/// a thread goes with its comment. Pure.
export function commentsShown(comments, hidden) {
  if (!hidden.size) return comments;
  const kept = comments.filter((one) => !hidden.has(Number(one.id)));
  const shown = new Set(kept.filter((one) => !one.parent).map((one) => Number(one.id)));
  return kept.filter((one) => !one.parent || shown.has(Number(one.parent)));
}

/// The comments on [model] hidden from [viewer] (null: signed out), as a
/// Set of ids; empty before the file.
export async function hiddenComments(model, viewer) {
  if (!ID.test(String(model || ""))) return new Set();
  const said = await call("block_hidden", { model_id: model, viewer: viewer || null }, () => []);
  return new Set(Array.isArray(said) ? said.map(Number) : []);
}

// ---------------------------------------------------------------------------
// How two stand, for a write.

/// How [account] stands with whoever a write on [model] or under comment
/// [comment] would reach: "blocked" (they blocked one), "blocked_by" (one
/// blocked them) or null; null before the file.
export async function standing(account, { model = null, comment = null } = {}) {
  if (!account) return null;
  const said = await call("block_on", { account, model_id: model && ID.test(String(model)) ? String(model) : null,
    comment_id: Number.isSafeInteger(comment) && comment > 0 ? comment : null }, () => null);
  return said === "blocked" || said === "blocked_by" ? said : null;
}

/// How [account] stands with the person with [handle]: "blocked",
/// "blocked_by" or null. Never said to the person blocked as such.
export async function standingWith(account, handle) {
  const wanted = handleOf(handle);
  if (!account || !wanted) return null;
  const person = await db(`people?handle=eq.${wanted}&select=account`);
  return standingBetween(account, person[0]?.account || null);
}

/// How [account] stands with the account [other] (an id): as standing says.
export async function standingBetween(account, other) {
  if (!account || !other || account === other) return null;
  const said = await call("block_between", { account, other }, () => null);
  return said === "blocked" || said === "blocked_by" ? said : null;
}

/// Throws the refusal for a write of [kind] (follow, comment, reply,
/// photo, list, like, remix, collect) when [state] (standing's) stands in
/// its way. Pure.
export function refuseFor(state, kind) {
  if (state === "blocked") throw refused(`you_${kind}`);
  if (state === "blocked_by") throw refused(`cannot_${kind}`);
}

/// Of [handles] a comment by [account] names, those it may not name (they
/// blocked [account], or [account] blocked them), as a Set; empty before
/// the file or when it cannot be asked: the comment is kept whatever this
/// says, and names nobody it may not.
export async function unnameable(account, handles) {
  if (!account || !handles?.length) return new Set();
  try {
    const said = await call("block_named", { account, handles }, () => []);
    return new Set(Array.isArray(said) ? said.map(String) : []);
  } catch (problem) {
    console.error(`blocks: named: ${String(problem?.message || problem).slice(0, 160)}`);
    return new Set(handles);
  }
}

/// [account]'s new counts without what their blocks leave out of the lists
/// ({notifications, feed}, each to 99, block.sql block_counts), to use in
/// place of the counts as they are; null for somebody who blocked nobody,
/// before the file, or when it cannot be read: the counts as they are.
export async function blockCounts(account) {
  try {
    const said = await call("block_counts", { viewer: account }, () => null);
    return said && typeof said === "object"
      ? { notifications: Number(said.notifications) || 0, feed: Number(said.feed) || 0 } : null;
  } catch (problem) {
    console.error(`blocks: counts: ${String(problem?.message || problem).slice(0, 160)}`);
    return null;
  }
}

// ---------------------------------------------------------------------------
// The requests.

/// GET ?op=blocks: whom the caller blocked.
export async function getBlocks(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await who(request);
  if (!account) throw refused("sign_in");
  let people;
  let ready = true;
  try {
    people = await db("rpc/block_list", { method: "POST", body: { account } });
  } catch (trouble) {
    if (!NOT_THERE.test(String(trouble?.message || ""))) throw trouble;
    people = [];
    ready = false;
  }
  const list = (Array.isArray(people) ? people : []).filter((one) => HANDLE.test(String(one?.handle || "")))
    .map((one) => ({ handle: one.handle, name: String(one.name || one.handle), at: one.at || null }));
  return response.status(200).json(await withFaces({ ready, people: list }));
}

/// POST ?op=block {handle, on}: the caller blocks them, or unblocks them.
export async function setBlock(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await who(request);
  if (!account) throw refused("sign_in");
  const body = request.body && typeof request.body === "object" ? request.body : {};
  if (typeof body.on !== "boolean") throw new Unacceptable("say on: true to block, or on: false to unblock");
  if (typeof body.handle !== "string" || !body.handle.trim()) throw new Unacceptable("say whom: handle, their profile's handle");
  const handle = handleOf(body.handle);
  if (!handle) throw refused("nobody");
  const said = await call("block_person", { account, wanted: handle, blocking: body.on }, () => ({ missing: true }));
  if (said?.missing) throw new Unacceptable(NOT_YET, 503);
  if (!said || said.refused) throw refused(said?.refused || "nobody");
  return response.status(200).json({ handle: said.handle, name: said.name, blocked: said.blocked === true, at: said.at || null });
}
