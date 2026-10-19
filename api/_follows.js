// Following a person, and the feed (2026-10-18, supabase/follows.sql).
// api/people.js answers the requests with these.
//
//   GET  ?op=follows&handle=X     X's counts (followers, following), and
//                                 with the session whether the caller
//                                 follows them, and may (why not, in words)
//   POST ?op=follow               (session) {handle, on}: follow X, or let
//                                 them go
//   GET  ?op=following&handle=X   whom X follows, when they chose to show
//                                 it; nobody's followers, ever
//   POST ?op=follow_choice        (session) {shows}: whether the caller's
//                                 profile shows whom they follow
//   GET  ?op=feed&before=ISO      (session) a page of the caller's feed,
//                                 newest first, each row with its words and
//                                 its link; the first page counts as the
//                                 feed opened, which clears the count
//   GET  ?op=feed_count           (session) {count}: rows since the feed was
//                                 last opened, at most 99, for Account
//
// Who may follow and who may be followed is the database's to say
// (follow_trouble), and its trigger says it again whatever writes: an
// account 13 or over, not taken out, following a profile shown in public,
// 60 an hour and 300 a day (may_act). Following tells the person followed
// nothing and opens no way to write to them. Who follows whom is answered
// only as counts; a list only of whom somebody chose to show.
//
// Until follows.sql is applied its functions are not there (404): a
// profile shows no counts and no Follow, the feed says it is not open yet,
// and the count is nothing. Everything else works as before.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { Unacceptable } from "./_directory.js";

const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const NOT_THERE = /: 404$/;
export const NOT_YET = "Following and the feed are not open on Brickworks yet.";

// What a refusal from follows.sql says, and its status.
export const WORDS = {
  sign_in: [401, "Sign in to follow people: we email you a code, no password."],
  nobody: [404, "Nobody here has that handle."],
  yourself: [409, "That is you."],
  barred: [403, "Brickworks took this account out of the gallery, so it cannot follow anybody."],
  ask_first: [422, "Brickworks asks everyone one question first. Sign in again, in the app or on "
    + "brickworks.diy, to answer it, then follow."],
  under_13: [422, "Following people is for people 13 and over, because a follow is counted in public. "
    + "Building, your models and sharing by link are all yours."],
  limit: [429, "That is a lot of following in a short time: try again in an hour."],
};

function refused(code) {
  const [status, words] = WORDS[code] || [400, "That could not be done."];
  return new Unacceptable(words, status);
}

/// An rpc of follows.sql, or [missing]'s answer when the file is not applied.
async function call(name, body, missing) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || "")) && missing !== undefined) return missing();
    throw trouble;
  }
}

const who = async (request) => (bearer(request) ? (await verify(bearer(request))).sub : null);
const handleOf = (given) => {
  const handle = String(given ?? "").trim().toLowerCase();
  return HANDLE.test(handle) && !handle.includes("--") ? handle : "";
};

// ---------------------------------------------------------------------------
// Pure: what a feed row says, and where it goes.

const quoted = (text, most) => {
  const line = String(text ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim();
  return line.length > most ? `${line.slice(0, most - 1)}…` : line;
};

/// A feed row as a person reads it, the same on the page and in the email:
/// {kind, at, who, did, name, said, link, by}. [who] is the name of whoever
/// did it (or "A builder", with no profile); [did] what, up to the model's
/// name; [said] their words, if any; [link] the thing itself.
export function feedSaid(row, origin = "") {
  const name = quoted(row.name || "a model", 80);
  const by = row.by && row.by.handle ? { handle: row.by.handle, name: quoted(row.by.name, 40),
    url: `${origin}/u/${row.by.handle}` } : null;
  const base = { kind: row.kind, at: row.at, who: by ? by.name : "A builder", by, name, said: "" };
  if (row.kind === "model") {
    return { ...base, did: "shared a new model", link: `${origin}/m/${row.model}` };
  }
  if (row.kind === "version") {
    return { ...base, did: `shared version ${Number(row.version)} of`, said: quoted(row.note, 280),
      link: `${origin}/m/${row.model}/v/${Number(row.version)}` };
  }
  if (row.kind === "photo") {
    return { ...base, did: row.yours ? "posted a photo of their build of your model" : "posted a photo of their build of",
      said: quoted(row.words, 140), link: `${origin}/m/${row.model}#photo-${row.photo}` };
  }
  if (row.kind === "comment") {
    const where = row.step ? `step ${Number(row.step)} of your model` : "your model";
    return { ...base, did: `commented on ${where}`, said: quoted(row.said, 240),
      link: `${origin}/m/${row.model}#comment-${row.comment}` };
  }
  if (row.kind === "remix") {
    return { ...base, did: `remixed your model “${quoted(row.of_name || "a model", 80)}” as`,
      link: `${origin}/m/${row.model}` };
  }
  return { ...base, did: "did something with", link: `${origin}/m/${row.model}` };
}

// ---------------------------------------------------------------------------
// Following.

/// [handle]'s follows as [asker] sees them: {ready, followers, following,
/// shows, you_follow, mine, may, why_not}, or null for nobody shown.
export async function followsOf(handle, asker = null) {
  const state = await call("follow_state", { asker, wanted: handle }, () => ({ missing: true }));
  if (state && state.missing) return { ready: false, followers: 0, following: 0, shows: false, you_follow: false,
    mine: false, may: false, why_not: NOT_YET };
  return state ? stateSaid(state) : null;
}

/// follow_state's answer, as the pages are given it.
function stateSaid(state) {
  const trouble = state.trouble || null;
  return { ready: true, followers: Number(state.followers) || 0, following: Number(state.following) || 0,
    shows: state.shows === true, you_follow: state.you_follow === true, mine: state.mine === true,
    may: !trouble, why_not: trouble ? WORDS[trouble]?.[1] || "" : "" };
}

/// Whom [handle] follows, when they chose to show it: [{handle, name}];
/// empty otherwise, or before the file is applied.
export async function followingOf(handle) {
  const said = await call("follow_list", { wanted: handle }, () => null);
  return said && said.shows === true && Array.isArray(said.people) ? said.people : [];
}

export async function getFollows(request, response) {
  const asker = await who(request);
  response.setHeader("Cache-Control", "private, no-store");
  const handle = handleOf(request.query?.handle);
  if (!handle) throw refused("nobody");
  const state = await followsOf(handle, asker);
  if (!state) throw refused("nobody");
  return response.status(200).json({ handle, ...state, signed_in: Boolean(asker) });
}

export async function follow(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const asker = await who(request);
  if (!asker) throw refused("sign_in");
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const handle = handleOf(body.handle);
  if (!handle) throw refused("nobody");
  if (typeof body.on !== "boolean") throw new Unacceptable("say on: true or on: false");
  const said = await call("follow_person", { account: asker, wanted: handle, following: body.on },
    () => ({ missing: true }));
  if (said && said.missing) throw new Unacceptable(NOT_YET, 503);
  if (!said || said.refused) throw refused(said?.refused || "nobody");
  return response.status(200).json({ handle, ...stateSaid(said), signed_in: true });
}

export async function getFollowing(request, response) {
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=30, stale-while-revalidate=30");
  const handle = handleOf(request.query?.handle);
  if (!handle) throw refused("nobody");
  return response.status(200).json({ handle, following: await followingOf(handle) });
}

export async function followChoice(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const asker = await who(request);
  if (!asker) throw refused("sign_in");
  const given = request.body?.shows;
  if (given !== undefined && typeof given !== "boolean") throw new Unacceptable("say shows: true or shows: false");
  const said = await call("follow_choice", { account: asker, shows: given ?? null }, () => ({ missing: true }));
  if (said && said.missing) throw new Unacceptable(NOT_YET, 503);
  return response.status(200).json({ shows_follows: said?.shows_follows === true });
}

/// What the caller chose of follows, for /profile: {ready, shows_follows}.
export async function followChoiceOf(account) {
  const said = await call("follow_choice", { account, shows: null }, () => ({ missing: true }));
  return { ready: !said?.missing, shows_follows: said?.shows_follows === true };
}

// ---------------------------------------------------------------------------
// The feed.

export async function feed(request, response, { origin }) {
  response.setHeader("Cache-Control", "private, no-store");
  const asker = await who(request);
  if (!asker) throw new Unacceptable("Sign in to see your feed: we email you a code, no password.", 401);
  const given = request.query?.before;
  let before = null;
  if (given !== undefined && given !== "") {
    // As the row gave it, to the microsecond: made a millisecond's time, a
    // row in the same millisecond as the last one shown would be skipped.
    before = String(given);
    if (!/^[0-9][0-9T:.+\-Z ]{9,39}$/.test(before) || !Number.isFinite(Date.parse(before))) {
      throw new Unacceptable("before is a time, as a row of the feed gives it");
    }
  }
  // The first page is the feed opened: the count clears.
  const page = await call("feed_of", { viewer: asker, before, size: 30, mark: before === null },
    () => ({ missing: true }));
  if (page && page.missing) return response.status(200).json({ ready: false, rows: [], more: false, seen_at: null });
  const seen = page?.seen_at ? Date.parse(page.seen_at) : null;
  const rows = (page?.rows || []).map((row) => ({ ...feedSaid(row, origin), model: row.model,
    new: seen === null || Date.parse(row.at) > seen }));
  return response.status(200).json({ ready: true, rows, more: page?.more === true, seen_at: page?.seen_at ?? null });
}

export async function feedCount(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const asker = await who(request);
  if (!asker) return response.status(200).json({ count: 0, signed_in: false });
  const count = await call("feed_count", { viewer: asker }, () => null);
  return response.status(200).json({ count: Number(count) || 0, signed_in: true, ready: count !== null });
}
