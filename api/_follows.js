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
//                                 newest first, each row with its words,
//                                 its link, its model's card and a photo's
//                                 picture; the first page counts as the
//                                 feed opened, which clears its count, and
//                                 says whom the caller follows
//   GET  ?op=latest               anybody: the newest models in the gallery,
//                                 the newest photos of real builds of them,
//                                 and designers to follow, by Top builds
//                                 (what the feed shows when it has nothing
//                                 of its own, docs/SOCIAL.md U9)
//
// Since supabase/notifications.sql the feed is what the people you follow
// made; what happened to your own models is Notifications, and the count
// is api/_notifications.js's.
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
import { SCORE, TESTS_CACHE, Unacceptable, cardOf, testsAsked } from "./_directory.js";
import { photosWhere } from "./_builds.js";
import { shownPublicly } from "./_trust.js";

const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const ID = /^[A-Za-z0-9]{10}$/;
const NOT_THERE = /: 404$/;
// Kept briefly by the CDN, as the gallery's list is.
const SHARED_CACHE = "public, max-age=0, s-maxage=30, stale-while-revalidate=30";
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
/// name; [after] the rest of the line, if any (only a challenge's, which no
/// email tells of); [said] their words, if any; [link] the thing itself.
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
  if (row.kind === "challenge") {
    return { ...base, did: "entered",
      after: `in the challenge “${quoted(row.title || "this month’s challenge", 80)}”, built ${row.way === "assistant"
        ? "with the assistant" : "by hand"}`, link: `${origin}/m/${row.model}` };
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

/// Whom [account] follows, for them alone and whatever they chose to show:
/// [{handle, name}], the newest first; null before supabase/account.sql.
async function followingMine(account) {
  const said = await call("follow_list_mine", { account }, () => null);
  return Array.isArray(said) ? said : null;
}

/// ?op=following&handle=X: whom X follows, when they show it. With no
/// handle and a sign-in: whom you follow, for you alone (your account
/// page), never kept by the CDN.
export async function getFollowing(request, response) {
  const handle = handleOf(request.query?.handle);
  if (!handle && !request.query?.handle) {
    response.setHeader("Cache-Control", "private, no-store");
    const asker = await who(request);
    if (!asker) throw refused("sign_in");
    // Before account.sql: not the list, only that it is not there yet
    // (ready: false), and the page says how many from follow_state.
    const mine = await followingMine(asker);
    return response.status(200).json({ mine: true, ready: mine !== null, following: mine || [] });
  }
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=30, stale-while-revalidate=30");
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
  // The first page is the feed opened: the count clears. What the people
  // you follow made (supabase/notifications.sql follow_page); before that
  // file, the feed of before, with your models' news in it too.
  const asked = { viewer: asker, before, size: 30, mark: before === null };
  const page = await call("follow_page", asked, () => call("feed_of", asked, () => ({ missing: true })));
  if (page && page.missing) return response.status(200).json({ ready: false, rows: [], more: false, seen_at: null });
  const seen = page?.seen_at ? Date.parse(page.seen_at) : null;
  const found = page?.rows || [];
  // What each row shows (docs/SOCIAL.md U9): its model's card, a photo's
  // picture; and, with the first page, whom the caller follows, so the page
  // knows a feed empty for want of anybody followed and leaves them out of
  // the designers it suggests.
  const [cards, photos, following] = await Promise.all([
    cardsOf(found.map((row) => row.model), origin),
    photosOf(found.filter((row) => row.kind === "photo").map((row) => row.photo), origin),
    before === null ? followingMine(asker) : null,
  ]);
  const rows = found.map((row) => ({ ...feedSaid(row, origin), model: row.model,
    new: seen === null || Date.parse(row.at) > seen, card: cards.get(row.model) || null,
    ...(row.kind === "photo" ? { photo: photos.get(row.photo) || null } : {}) }));
  return response.status(200).json({ ready: true, rows, more: page?.more === true, seen_at: page?.seen_at ?? null,
    ...(before === null ? { following: following ? following.map((one) => one.handle) : null } : {}) });
}

/// The cards of the models [ids], as the gallery gives them: id -> card.
/// directory_card read as a column of shared_models (PostgREST takes a
/// function of the row as one), so a feed's card is the gallery's to the
/// letter. Only models still up.
async function cardsOf(ids, origin) {
  const wanted = [...new Set(ids.map(String))].filter((id) => ID.test(id));
  if (!wanted.length) return new Map();
  const rows = await db(`shared_models?id=in.(${wanted.join(",")})&published=is.true&barred=is.false&select=card:directory_card`);
  return new Map(rows.filter((row) => row.card && row.card.id).map((row) => [row.card.id, cardOf(origin, row.card)]));
}

/// The pictures of the photos [ids] a feed has rows of (follow_rows shows
/// only what may be shown): id -> {id, url, width, height}.
async function photosOf(ids, origin) {
  const wanted = [...new Set(ids.map(String))].filter((id) => ID.test(id));
  if (!wanted.length) return new Map();
  const rows = await db(`build_photos?id=in.(${wanted.join(",")})&select=id,width,height`);
  return new Map(rows.map((row) => [row.id, { id: row.id, url: `${origin}/api/people?op=photo_file&id=${row.id}`,
    width: Number(row.width) || null, height: Number(row.height) || null }]));
}

// ---------------------------------------------------------------------------
// Latest on Brickworks: the feed for somebody signed out, following nobody,
// or followed people who made nothing in 90 days (docs/SOCIAL.md U9, D12).

/// How many of each it shows: models, photos, designers.
export const LATEST = { models: 8, photos: 6, designers: 8 };
// How many of Top builds' first models the designers are read from: the
// list's one page, its most.
const TOP_READ = 49;

/// Designers to follow, from the cards of Top builds' list: each credited
/// designer whose profile is shown in public (a card's by, which only such
/// a one has: D1), most first by what their models earned as Top builds
/// weighs it (a build finished, a remix, the Tested mark), then by builds,
/// then the newest listed. Each: {handle, name, score, builds, models:
/// [{id, name}], their best first}. Pure.
export function designersFrom(cards, most = LATEST.designers) {
  const by = new Map();
  for (const card of cards) {
    const handle = String(card?.by?.handle || "");
    if (!HANDLE.test(handle)) continue;
    const one = by.get(handle) || { handle, name: quoted(card.by.name || handle, 40), score: 0, builds: 0, newest: 0, models: [] };
    const builds = Number(card.builds) || 0;
    one.score += builds * SCORE.builds + (Number(card.remixes) || 0) * SCORE.remixes + (card.tested === true ? SCORE.tested : 0);
    one.builds += builds;
    one.newest = Math.max(one.newest, Date.parse(card.listed_at || "") || 0);
    one.models.push({ id: String(card.id), name: quoted(card.name, 80) });
    by.set(handle, one);
  }
  return [...by.values()].sort((a, b) => b.score - a.score || b.builds - a.builds || b.newest - a.newest)
    .slice(0, most).map(({ newest, ...one }) => one);
}

/// The gallery's list asked [query]: gallery_models, or directory_models
/// before supabase/gallery_tabs.sql.
const listed = (query) => call("gallery_models", { query }, () => db("rpc/directory_models", { method: "POST", body: { query } }));

/// The newest photos of real builds of models in the gallery, of builders
/// shown in public, at most [most]: as a profile's builds give them.
async function newestPhotos(origin, tests, most) {
  const photos = await photosWhere("hidden_at=is.null", shownPublicly, { limit: most * 2 });
  const ids = [...new Set(photos.map((one) => one.model))].filter((id) => ID.test(String(id)));
  const models = ids.length ? await db(`shared_models?id=in.(${ids.join(",")})&published=is.true&listed=is.true`
    + "&barred=is.false&select=id,name,test") : [];
  const names = new Map(models.filter((one) => tests || !one.test).map((one) => [one.id, one.name]));
  return photos.filter((one) => names.has(one.model)).slice(0, most).map((one) => ({ id: one.id, model: one.model,
    model_name: quoted(names.get(one.model), 80), words: one.words ? quoted(one.words, 140) : null,
    width: Number(one.width) || null, height: Number(one.height) || null, at: one.at,
    by: one.by ? { handle: one.by.handle, name: quoted(one.by.name, 40) } : null,
    url: `${origin}/api/people?op=photo_file&id=${one.id}`, page: `${origin}/m/${one.model}#photo-${one.id}` }));
}

/// ?op=latest: {models, photos, designers}, the same for everybody, so
/// kept by the CDN; asked with tests=1 (a probe), test models too, never
/// kept.
export async function latest(request, response, { origin }) {
  const tests = testsAsked(request.query || {});
  const flag = tests ? { tests: true } : {};
  const [newest, top, photos] = await Promise.all([
    listed({ sort: "newest", size: LATEST.models, skip: 0, ...flag }),
    listed({ sort: "top", size: TOP_READ, skip: 0, ...flag }),
    newestPhotos(origin, tests, LATEST.photos),
  ]);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : SHARED_CACHE);
  return response.status(200).json({ models: (newest || []).slice(0, LATEST.models).map((row) => cardOf(origin, row)),
    photos, designers: designersFrom((top || []).map((row) => cardOf(origin, row))) });
}
