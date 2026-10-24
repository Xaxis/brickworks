// People in the directory (2026-10-13): profiles, likes, favourites and
// collections. supabase/people.sql has the tables and the functions.
//
//   GET  ?op=me                   (session) the caller's profile, if they
//                                 made one, and their collections
//   POST ?op=profile              (session) {handle, name, bio?}: made, or
//                                 changed
//   GET  ?op=profile&handle=X     a profile as anyone sees it, with its first
//                                 page of models (&page=N for more), its
//                                 links, banner and pinned models
//   GET  ?op=page&handle=X        /u/X: the profile's page; &tab=builds,
//                                 &tab=collections or &tab=likes for those
//                                 tabs, &page=N for the models' (or the
//                                 likes') page N
//   GET  ?op=likes&handle=X&page=N  the models X liked, when X chose to
//                                 show them (supabase/avatars.sql)
//   GET  ?op=avatar&id=P          picture P, a person's own avatar, while
//                                 it may be shown
//   POST ?op=avatar               (session) {picture: base64, type}: the
//                                 caller's own picture as their avatar,
//                                 the square Edit profile cropped, at most
//                                 2 MB (api/_avatars.js)
//   POST ?op=avatar_remove        (session) that picture taken off: the
//                                 avatar made from the handle again
//   POST ?op=likes_choice         (session) {shows}: show on my profile the
//                                 models I liked
//   POST ?op=showcase             (session) {links?, banner?, pins?}: what
//                                 the caller's profile shows besides its
//                                 name: one or two https links, one of
//                                 their models' pictures across the top,
//                                 up to three of their models pinned
//                                 (supabase/profile_shows.sql)
//   GET  ?op=marks&id=X           (session) whether the caller likes and
//                                 keeps model X, and which of their lists
//                                 have it
//   POST ?op=like&id=X            (session) {on}: liked or not, and the count
//   POST ?op=favourite&id=X       (session) {on}: kept or not
//   GET  ?op=favourites&page=N    (session) what the caller keeps
//   POST ?op=collection           (session) {id?, name, description?,
//                                 public?}: a list made, or changed
//   POST ?op=uncollection&id=X    (session) a list deleted
//   POST ?op=collect              (session) {collection, model, on}
//   GET  ?op=collection&id=X      a list and a page of its models: public,
//                                 or the caller's own (&page=N)
//   GET  ?op=list_page&id=X       /c/X: a public list's page: its cover,
//                                 Follow, Share and its models
//   GET  ?op=list_follows&id=X    X's followers, and whether the caller
//                                 follows it and may (api/_lists.js)
//   POST ?op=list_follow          (session) {id, on}: follow a public list,
//                                 or let it go; what is put in it is then
//                                 in the caller's feed
//   POST ?op=report               {model | handle | collection | comment | photo,
//                                 reason, note?, contact?}: somebody saying
//                                 it should not be there, to the site's
//                                 owner (api/admin.js); signed in or not.
//                                 Emailed to them within the hour
//                                 (api/_trust.js sendDigest)
//   POST ?op=digest               the hourly knock (supabase/trust.sql's
//                                 cron job): this hour's one email of what
//                                 was reported, if it has not gone, and
//                                 the day's email of new comments to each
//                                 owner who asked for one. Needs no secret:
//                                 it can send nothing else
//   GET  ?op=comments&id=X&v=N    the comments on a model, and on its steps
//   POST ?op=comment, reply, comment_change, comments_open&id=X, mail
//                                 (session) a comment or a reply written, changed,
//                                 hidden or removed; comments on a model
//                                 turned on or off; the comments' email
//                                 chosen (api/_comments.js)
//   GET  ?op=photos&id=X          the photos of real builds of model X that
//                                 may be shown; with the session, also the
//                                 caller's own on it, and for its owner the
//                                 hidden ones (api/_builds.js)
//   GET  ?op=photo_file&id=P      photo P, the JPEG made from what was sent
//   POST ?op=photo_start          (session) {model, type, size}: where the
//                                 phone sends a photo of its build, at most
//                                 8 MB, straight to storage
//   POST ?op=photo                (session) {model, ticket, words?}: that
//                                 photo made safe and kept (api/_photo.js)
//   POST ?op=photo_hide           (session) {photo, on}: the model's owner
//                                 hides a photo on it, or shows it again
//   GET  ?op=follows&handle=X     X's counts, and whether the caller follows
//                                 them and may (api/_follows.js)
//   POST ?op=follow               (session) {handle, on}: follow, or let go
//   GET  ?op=following&handle=X   whom X follows, when they chose to show it
//   POST ?op=follow_choice        (session) {shows}: show whom I follow
//   GET  ?op=feed&before=ISO      (session) the caller's feed, newest first,
//                                 each row with its model's card; its first
//                                 page counts as the feed opened
//   GET  ?op=latest               the newest models, photos of builds and
//                                 designers to follow, for a feed with
//                                 nothing of its own (api/_follows.js)
//   GET  ?op=feed_count           (session) what is new: notifications and
//                                 the feed, apart and together, and who the
//                                 caller is, for the avatar in the header
//   GET  ?op=notifications        (session) what happened to the caller's
//                                 models, grouped by model; opening it
//                                 clears its count (api/_notifications.js)
//   POST ?op=notifications_read   (session) {model} or {all: true}: read
//   GET  ?op=designs              (session) the caller's own models' last 30
//                                 days: opens, builds finished, remixes,
//                                 comments, and who built them; &handle=X
//                                 only when X is theirs (api/_designers.js).
//                                 Never kept by the CDN
//   GET  ?op=challenge            /challenge: this month's challenge, its
//                                 rules, its entries in their two groups and
//                                 once it ended its winners; with the
//                                 session, whom the caller voted for
//   GET  ?op=challenge_entry&id=X (session) the challenge open now, for X's
//                                 own designer: whether X is in, and what its
//                                 rules say of X
//   POST ?op=enter, withdraw, vote  (session) a model entered or taken back,
//                                 a vote cast (api/_challenges.js)
//
// Challenges (2026-10-19, supabase/challenges.sql): one at a time, set by the
// site's owner on /admin, with rules the database checks on the stored
// model; a designer's page and a winning model's card say what it won.
//
// Designers (2026-10-19, supabase/designers.sql): a profile with models in
// the gallery is a designer's page, and leads with what those models
// earned: builds finished, remixes, Tested, comments, models, followers,
// each the sum of what its cards say; the models by Top builds, each card
// with its own builds, remixes and comments; and the photos other people
// posted of their builds of them. The designer, signed in, sees on their
// own page and on /profile how each of their models is doing, which
// nobody else is shown.
//
// Follows and the feed (2026-10-18, supabase/follows.sql): an account 13 or
// over follows a profile shown in public; a profile shows only how many
// follow it and how many it follows, and whom it follows only when its
// owner chose to show that. /feed is what concerns the caller, read from
// the tables that hold it, and Account counts what came since they last
// opened it. api/_follows.js has the rules.
//
// Real builds (2026-10-18, supabase/builds.sql): a photo of somebody's real
// build of a model, with a line, by an account 13 or over, at most three on
// a model; shown on the model's page and on their profile; hidden by the
// model's owner, reported like anything else ("photo"), and taken out by
// the site's owner with its file (api/admin.js). api/_builds.js has the
// rules, api/_photo.js how a photo is made safe.
//
// The ground rules (2026-10-18, supabase/trust.sql): a profile and a public
// collection need the age question answered 13 or over, and nothing of an
// account under 13 is shown as a profile. Refused here in words, and by
// the database again.
//
// Since the directory's moderation (supabase/moderation.sql): names are
// checked for abuse and for names somebody else owns (api/_names.js); each
// thing a person does is counted, so many an hour and a day (may_act); and
// an account the site's owner took out has no profile and no public list.
//
// A test account's models (api/share.js) are left out of a profile, a list
// and their counts unless asked for with tests=1, as the gallery's are; such
// an answer is never kept by the CDN (supabase/test_models.sql).
//
// The profile's page (2026-10-22, docs/SOCIAL.md U5, supabase/profile_shows.sql):
// a person-shaped page, the same for everybody it shows, the site's house
// account too. Their avatar (made from the handle, web/card.js avatarHtml),
// name, handle, words and links, one row of numbers (each said once there
// is one), Follow, Share and More; the models they pinned; then tabs, each a
// page of its own: Models (every one, page by page), Builds (photos of real
// builds, theirs and of their models) and Collections (each a card with its
// pictures). Never a list of who follows them. Until profile_shows.sql is
// applied it has no links, banner or pins, and is otherwise the same.
//
// A profile is by a name its owner chooses, never one made from their
// address, and lists only the models they listed and chose to be credited
// for: a model shared without a name is not tied to anybody here. Likes
// are counted on the model; favourites and private lists are their owner's
// alone, and a private list answers anybody else exactly as one that does
// not exist. Every word a person typed is checked here and escaped on every
// page that shows it.

import { randomBytes } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { originOf } from "./_oauth.js";
import {
  TESTS_CACHE, Unacceptable, cardOf, count, escapeHtml, siteChrome, testsAsked, visitorKey,
} from "./_directory.js";
import { handleTrouble, namesTrouble } from "./_names.js";
import { publicTrouble, sendDigest, shownPublicly } from "./_trust.js";
import { PICTURE_CACHE } from "./_photo.js";
import {
  BuildRefusal, MAX_WORDS, hidePhoto, keepPhoto, photoFile, photoRow, photosWhere, reportPhoto, startPhoto,
} from "./_builds.js";
import {
  addComment, addReply, changeComment, chooseMail, commentModel, listComments, mailChoice, sendCommentDigests,
  setCommentsOpen,
} from "./_comments.js";
import {
  feed, follow, followChoice, followChoiceOf, followingOf, followsOf, getFollowing, getFollows, latest,
} from "./_follows.js";
import { feedCount, notifications, notificationsRead } from "./_notifications.js";
import { coversOf, getListFollows, listCardHtml, listFollow, listFollowsOf, mosaicHtml } from "./_lists.js";
import { designerOf, designs } from "./_designers.js";
import {
  AvatarRefusal, avatarFile, avatarOf, avatarSaid, chooseLikes, dropAvatar, keepAvatar, likedRows, likesChoiceOf,
  likesCount,
} from "./_avatars.js";
import { withFaces } from "./_faces.js";
// The one model card, the browser's too (web/card.js): the page needs no
// script to show its models.
import { cardHtml } from "./_card.js";
// The kit, made in the card's file: an avatar made from a handle, the
// icons and an icon button, drawn as a browser draws them.
import { avatarHtml, iconButtonHtml, iconHtml } from "./_card.js";
import { challenge, challengeEntry, enter, vote, winsBy, withWins, withdraw, wonSaid } from "./_challenges.js";

const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
export const PER_PAGE = 24;
const MOST_PAGES = 400;
export const MOST_LISTS = 50;
export const MOST_IN_A_LIST = 500;
export const MOST_FAVOURITES = 2000;
// How often a person may do each thing: [an hour, a day].
export const LIMITS = { profile: [20, 60], like: [300, 2000], favourite: [300, 2000],
  collection: [20, 60], collect: [300, 3000], report: [6, 20], photo: [12, 40], photo_hide: [60, 300],
  showcase: [20, 60], avatar: [12, 40], likes_choice: [20, 60] };
// What a profile shows besides its name (supabase/profile_shows.sql).
export const MOST_LINKS = 2;
export const MOST_PINS = 3;
const REASONS = new Set(["spam", "offensive", "sexual", "violent", "copied", "trademark", "personal", "other"]);

class Refusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function newId() {
  let id = "";
  for (const byte of randomBytes(10)) id += ALPHABET[byte % ALPHABET.length];
  return id;
}

/// One printable line, its runs of space made one, cut to its limit.
function cleanLine(given, limit) {
  if (typeof given !== "string") return "";
  return given.replace(/[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ")
    .replace(/\s+/g, " ").trim().slice(0, limit).trim();
}

/// A few lines: printable, blank lines made one, at most [limit]; null for none.
function cleanLines(given, limit, what) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string") throw new Refusal(`${what} is text`);
  const text = given.replace(/\r\n?/g, "\n")
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ")
    .split("\n").map((line) => line.replace(/\s+/g, " ").trim()).join("\n")
    .replace(/\n{3,}/g, "\n\n").trim();
  if (text.length > limit) throw new Refusal(`${what} is at most ${limit} characters; that is ${text.length}`);
  return text || null;
}

async function signedIn(request) {
  const claims = await verify(bearer(request), request);
  return claims.sub;
}

/// Once more of [act] by [who] (an account, or a visitor's key), or 429.
async function counted(who, act) {
  const [hour, day] = LIMITS[act];
  const allowed = await db("rpc/may_act", { method: "POST", body: { actor: who, act, per_hour: hour, per_day: day } });
  if (allowed !== true) throw new Refusal(`that is a lot of that in a short time: try again in an hour`, 429);
}

/// Names checked for what the gallery does not show (api/_names.js).
function checkNames(said) {
  const trouble = namesTrouble(said);
  if (trouble) throw new Refusal(trouble);
}

/// A model anybody with its link may see: {id, listed}, or null.
async function publishedModel(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`shared_models?id=eq.${id}&published=is.true&barred=is.false&select=id,listed`);
  return rows[0] || null;
}

/// A profile anybody may see: none for an account the site's owner took
/// out of the gallery, nor for one under 13.
async function personOf(handle) {
  if (!HANDLE.test(handle || "")) return null;
  const rows = await db(`people?handle=eq.${handle}&select=account,handle,name,bio,created_at`);
  if (!rows[0]) return null;
  return (await shownPublicly(rows[0].account)) ? rows[0] : null;
}

function pageOf(query) {
  const page = Number(query.page ?? 1);
  if (!Number.isInteger(page) || page < 1 || page > MOST_PAGES) {
    throw new Refusal(`page is a whole number from 1 to ${MOST_PAGES}`);
  }
  return page;
}

/// A page of models from directory_models, as cards.
async function models(origin, asked, page) {
  const rows = await db("rpc/directory_models", { method: "POST",
    body: { query: { ...asked, size: PER_PAGE + 1, skip: (page - 1) * PER_PAGE } } });
  return { page, per_page: PER_PAGE, more: rows.length > PER_PAGE,
    models: rows.slice(0, PER_PAGE).map((row) => cardOf(origin, row)) };
}

// ---------------------------------------------------------------------------
// What a profile shows besides its name (supabase/profile_shows.sql).

const NOT_THERE = /: 404$/;
export const SHOWCASE_NOT_YET = "Links, a banner and pinned models are not open on Brickworks yet.";
// A link as profile_shows keeps one: https, a host with a dot, no password.
const LINK = /^https:\/\/[^/?#@\s]+\.[^/?#@\s]+([/?#]\S*)?$/;

/// What [account]'s profile shows: {ready, links, banner, pins}, as kept;
/// ready false, and nothing, before profile_shows.sql is applied.
async function showsOf(account) {
  try {
    const row = (await db(`profile_shows?account=eq.${account}&select=links,banner,pins`))[0] || {};
    return { ready: true, links: (Array.isArray(row.links) ? row.links : []).filter((one) => LINK.test(String(one))),
      banner: ID.test(String(row.banner || "")) ? row.banner : null,
      pins: (Array.isArray(row.pins) ? row.pins : []).filter((one) => ID.test(String(one))) };
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || ""))) return { ready: false, links: [], banner: null, pins: [] };
    throw trouble;
  }
}

/// A link as a profile shows it: its domain and path, "flickr.com/photos/robin".
export function linkSaid(href) {
  const url = new URL(href);
  const said = `${url.hostname.replace(/^www\./, "")}${`${url.pathname}${url.search}`.replace(/\/$/, "")}`;
  return said.length > 48 ? `${said.slice(0, 47)}…` : said;
}

/// A link somebody typed, as kept: https, with "https://" put first when
/// they left it off; or a refusal in words.
export function cleanLink(given) {
  if (typeof given !== "string") throw new Refusal("a link is text");
  const text = given.trim();
  let url;
  try {
    url = new URL(/^[a-z][a-z0-9+.-]*:/i.test(text) ? text : `https://${text}`);
  } catch {
    throw new Refusal(`“${text.slice(0, 60)}” is not a web address`);
  }
  if (url.protocol !== "https:") throw new Refusal("a link is a web address starting https://");
  if (url.username || url.password) throw new Refusal("a link carries no name or password");
  url.hash = "";
  const href = url.href;
  if (href.length > 200) throw new Refusal("a link is at most 200 characters");
  if (!LINK.test(href)) throw new Refusal(`“${text.slice(0, 60)}” is not a web address`);
  return href;
}

/// Of [ids], those that are [account]'s own and may be on their profile:
/// published, listed, credited to them, not taken out, and a test model's
/// only when [tests]. id -> {id, has_image}.
async function ownShown(account, ids, tests = false) {
  const wanted = [...new Set(ids.filter((id) => ID.test(String(id))))];
  if (!wanted.length) return new Map();
  const rows = await db(`shared_models?id=in.(${wanted.join(",")})&owner=eq.${account}&published=is.true`
    + "&listed=is.true&barred=is.false&author=not.is.null&select=id,has_image,test");
  return new Map(rows.filter((row) => tests || !row.test).map((row) => [row.id, row]));
}

/// What [person]'s page shows of what they chose: {links: [{href, said}],
/// banner: id of a model of theirs with a picture, or null, pins: cards},
/// each only while it may be shown.
async function showcaseOf(origin, person, shows, tests) {
  const shown = await ownShown(person.account, [...shows.pins, ...(shows.banner ? [shows.banner] : [])], tests);
  const pins = (await Promise.all(shows.pins.filter((id) => shown.has(id)).map((id) =>
    db("rpc/directory_model", { method: "POST", body: { model_id: id } }).catch(() => null))))
    .filter((row) => row && ID.test(String(row.id))).map((row) => cardOf(origin, row));
  return { links: shows.links.map((href) => ({ href, said: linkSaid(href) })),
    banner: shows.banner && shown.get(shows.banner)?.has_image ? shows.banner : null,
    pins: await withWins(pins, tests) };
}

/// POST ?op=showcase: what the caller's profile shows besides its name.
/// Each of links, banner and pins is changed when given and kept when not.
async function saveShowcase(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const changed = {};
  if (body.links !== undefined) {
    if (!Array.isArray(body.links)) throw new Refusal("links is a list of web addresses");
    const links = body.links.filter((one) => typeof one !== "string" || one.trim()).map(cleanLink);
    if (links.length > MOST_LINKS) throw new Refusal(`a profile shows at most ${MOST_LINKS} links`);
    checkNames({ "A link": [links.map(linkSaid), "words"] });
    changed.links = [...new Set(links)];
  }
  if (body.pins !== undefined) {
    if (!Array.isArray(body.pins) || body.pins.some((id) => !ID.test(String(id)))) {
      throw new Refusal("pins is a list of your models' ids");
    }
    const pins = [...new Set(body.pins.map(String))];
    if (pins.length > MOST_PINS) throw new Refusal(`pin at most ${MOST_PINS} models`);
    changed.pins = pins;
  }
  if (body.banner !== undefined) {
    if (body.banner !== null && body.banner !== "" && !ID.test(String(body.banner))) {
      throw new Refusal("the banner is one of your models, by its id, or none");
    }
    changed.banner = body.banner ? String(body.banner) : null;
  }
  const chosen = [...(changed.pins || []), ...(changed.banner ? [changed.banner] : [])];
  // Their own, in the gallery with their name: a test account's own test
  // models too, which only a page asked with tests=1 shows.
  const theirs = await ownShown(account, chosen, true);
  const notTheirs = chosen.find((id) => !theirs.has(id));
  if (notTheirs) throw new Refusal("pin and choose only your own models in the gallery, shown with your name", 422);
  if (changed.banner && !theirs.get(changed.banner).has_image) throw new Refusal("that model has no picture to show", 422);
  const person = (await db(`people?account=eq.${account}&select=handle`))[0];
  if (!person) throw new Refusal("make your profile first: a name and a handle", 409);
  const young = await publicTrouble(account, { profile: true });
  if (young) throw new Refusal(young, 422);
  await counted(account, "showcase");
  try {
    await db("profile_shows?on_conflict=account", { method: "POST",
      body: { account, ...changed, updated_at: new Date().toISOString() }, prefer: "resolution=merge-duplicates" });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || ""))) throw new Unacceptable(SHOWCASE_NOT_YET, 503);
    throw trouble;
  }
  const shows = await showsOf(account);
  return response.status(200).json({ links: shows.links, banner: shows.banner, pins: shows.pins,
    url: `${originOf(request)}/u/${person.handle}` });
}

// ---------------------------------------------------------------------------
// Profiles.

async function me(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signedIn(request);
  const [people, lists, mail, follows, shows, theirs, avatar, likes] = await Promise.all([
    db(`people?account=eq.${account}&select=handle,name,bio,created_at`),
    db(`model_collections?owner=eq.${account}&select=id,name,description,public,updated_at&order=updated_at.desc`),
    mailChoice(account),
    followChoiceOf(account),
    showsOf(account),
    // What they may pin or put across the top: their models in the gallery
    // with their name, newest first.
    db(`shared_models?owner=eq.${account}&published=is.true&listed=is.true&barred=is.false&author=not.is.null`
      + "&select=id,name,has_image&order=listed_at.desc&limit=200"),
    avatarOf(account),
    likesChoiceOf(account),
  ]);
  const counts = await Promise.all(lists.map((list) =>
    db("rpc/collection_count", { method: "POST", body: { list: list.id, private: true } })));
  const said = avatarSaid(avatar);
  return response.status(200).json({
    profile: people[0] ? { ...people[0], ...(said.picture ? { picture: said.picture } : {}) } : null,
    // Their own picture as their avatar, and whether their profile shows
    // the models they liked (supabase/avatars.sql).
    avatar: said,
    likes,
    collections: lists.map((list, at) => ({ ...list, count: Number(counts[at]) || 0 })),
    // What is emailed: comments on their models and the feed's kinds, once
    // a day, each when chosen.
    mail,
    // Whether their profile shows whom they follow (supabase/follows.sql).
    follows,
    // What their profile shows besides its name (supabase/profile_shows.sql),
    // and the models they may choose from for it.
    showcase: { ...shows, models: theirs.filter((one) => ID.test(String(one.id)))
      .map((one) => ({ id: one.id, name: one.name, picture: one.has_image === true })) },
  });
}

async function saveProfile(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const handle = String(body.handle ?? "").trim().toLowerCase();
  if (!HANDLE.test(handle) || handle.includes("--")) {
    throw new Refusal("a handle is 3 to 24 letters, digits and single hyphens, starting and ending "
      + "with a letter or a digit");
  }
  const handleSaid = handleTrouble(handle);
  if (handleSaid) throw new Refusal(handleSaid, 409);
  const name = cleanLine(body.name, 40);
  if (!name) throw new Refusal("give the name to show on your profile: whatever you like to be called here");
  const bio = cleanLines(body.bio, 300, "what you say about yourself");
  checkNames({ "That name": [name, "name"], "What you say about yourself": [bio, "words"] });
  const young = await publicTrouble(account, { profile: true });
  if (young) throw new Refusal(young, 422);
  await counted(account, "profile");
  const now = new Date().toISOString();
  try {
    const rows = await db("people?on_conflict=account", { method: "POST",
      body: { account, handle, name, bio, updated_at: now },
      prefer: "resolution=merge-duplicates,return=representation" });
    const saved = rows[0] || {};
    return response.status(200).json({ handle: saved.handle, name: saved.name, bio: saved.bio,
      url: `${originOf(request)}/u/${saved.handle}` });
  } catch (trouble) {
    if (/: 409$/.test(trouble.message)) throw new Refusal("somebody already has that handle: choose another", 409);
    throw trouble;
  }
}

async function profile(request, response) {
  const handle = String(request.query?.handle || "").toLowerCase();
  const tests = testsAsked(request.query);
  const person = await personOf(handle);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : "no-cache");
  if (!person) return response.status(404).json({ error: "nobody has that handle" });
  const origin = originOf(request);
  const [page, about, built, follows, designer, shows, liked] = await Promise.all([
    models(origin, { owner: person.account, tests, sort: "top" }, pageOf(request.query || {})),
    db("rpc/profile_page", { method: "POST", body: { wanted: handle, tests } }),
    builtBy(origin, person, tests),
    followsOf(handle),
    designerOf(originOf(request), handle, tests),
    showsOf(person.account),
    likedShown(person.account, tests),
  ]);
  // What their models earned (supabase/designers.sql), and each card's
  // comments beside its builds and remixes, and what it won: the same
  // cards as the page's, for its Show more.
  const earned = designer && designer.ready ? designer : null;
  const cards = (await withWins(page.models, tests))
    .map((card) => (earned ? { ...card, comments: earned.cards[card.id]?.comments ?? 0 } : card));
  const showcase = await showcaseOf(origin, person, shows, tests);
  return response.status(200).json(await withFaces({ handle: person.handle, name: person.name, bio: person.bio,
    since: person.created_at, models_count: about?.models ?? 0, likes: about?.likes ?? 0,
    // How many models they liked, when they chose to show which: else null.
    liked_count: liked,
    followers: follows?.followers ?? 0, following: follows?.following ?? 0,
    designer: earned ? { models: earned.models, builds: earned.builds, remixes: earned.remixes,
      comments: earned.comments, tested: earned.tested, likes: earned.likes, builders: earned.builders,
      followers: follows?.followers ?? 0, photos: earned.photos } : null,
    collections: about?.collections ?? [], built, url: `${origin}/u/${person.handle}`,
    links: showcase.links, banner: showcase.banner, pins: showcase.pins, ...page, models: cards }));
}

/// How many models [account] liked, when they chose to show which (and
/// avatars.sql is applied); else null, and no Likes tab.
async function likedShown(account, tests) {
  const choice = await likesChoiceOf(account).catch(() => ({ ready: false }));
  return choice.ready && choice.shows_likes ? likesCount(account, tests).catch(() => null) : null;
}

/// A page of the models [person] liked, as cards: only when they chose to
/// show them; null when they did not.
async function likedPage(origin, person, page, tests) {
  if ((await likedShown(person.account, tests)) === null) return null;
  const { rows, more } = await likedRows(person.account, { size: PER_PAGE, skip: (page - 1) * PER_PAGE, tests });
  return { page, per_page: PER_PAGE, more, models: rows.map((row) => cardOf(origin, row)) };
}

/// GET ?op=likes&handle=X&page=N: the models X liked, when X shows them.
async function likes(request, response) {
  const handle = String(request.query?.handle || "").toLowerCase();
  const tests = testsAsked(request.query);
  const person = await personOf(handle);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : "no-cache");
  if (!person) return response.status(404).json({ error: "nobody has that handle" });
  const page = await likedPage(originOf(request), person, pageOf(request.query || {}), tests);
  if (!page) return response.status(404).json({ error: "they do not show the models they liked" });
  return response.status(200).json(await withFaces({ handle: person.handle, ...page,
    models: await withWins(page.models, tests) }));
}

/// POST ?op=likes_choice {shows}: whether the caller's profile shows the
/// models they liked. Off until they turn it on.
async function saveLikesChoice(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const shows = request.body?.shows;
  if (typeof shows !== "boolean") throw new Refusal("say shows: true or shows: false");
  const person = (await db(`people?account=eq.${account}&select=handle`))[0];
  if (!person) throw new Refusal("make your profile first: a name and a handle", 409);
  const young = await publicTrouble(account, { profile: true });
  if (young) throw new Refusal(young, 422);
  await counted(account, "likes_choice");
  return response.status(200).json(await chooseLikes(account, shows));
}

// ---------------------------------------------------------------------------
// Your own picture as your avatar (api/_avatars.js).

/// POST ?op=avatar {picture, type}: the square Edit profile cropped, kept
/// as the caller's avatar.
async function saveAvatar(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const kept = await keepAvatar(account, body.picture, String(body.type || ""), async () => {
    const person = (await db(`people?account=eq.${account}&select=handle`))[0];
    if (!person) throw new Refusal("make your profile first: a name and a handle", 409);
    const young = await publicTrouble(account, { profile: true });
    if (young) throw new Refusal(young, 422);
    await counted(account, "avatar");
  });
  return response.status(200).json(kept);
}

/// POST ?op=avatar_remove: the caller's own picture taken off.
async function dropOwnAvatar(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  await counted(account, "avatar");
  return response.status(200).json(await dropAvatar(account));
}

/// GET ?op=avatar&id=P: a person's own picture, while it may be shown.
async function avatarServe(request, response) {
  const file = await avatarFile(String(request.query?.id || ""), shownPublicly);
  if (!file) return response.status(404).setHeader("Cache-Control", "no-store").end("");
  response.setHeader("Content-Type", "image/jpeg");
  response.setHeader("X-Content-Type-Options", "nosniff");
  // Kept at the CDN for PICTURE_KEPT seconds, never stale, so a picture
  // taken out or taken off is gone from every cache that soon. A new
  // picture has a new address.
  response.setHeader("Cache-Control", PICTURE_CACHE);
  return response.status(200).end(file);
}

// ---------------------------------------------------------------------------
// Likes, favourites and lists.

async function marks(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signedIn(request);
  const id = String(request.query?.id || "");
  if (!ID.test(id)) throw new Refusal("name a link: ?id=<ten characters>");
  const [liked, kept, lists, holding] = await Promise.all([
    db(`model_likes?model=eq.${id}&account=eq.${account}&select=model`),
    db(`model_favourites?model=eq.${id}&account=eq.${account}&select=model`),
    db(`model_collections?owner=eq.${account}&select=id,name,public&order=updated_at.desc`),
    db(`model_collection_items?model=eq.${id}&select=collection`),
  ]);
  const has = new Set(holding.map((row) => row.collection));
  return response.status(200).json({ liked: liked.length > 0, favourite: kept.length > 0,
    collections: lists.map((list) => ({ ...list, has: has.has(list.id) })) });
}

async function toggle(request, response, table) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const id = String(request.query?.id || "");
  const on = request.body?.on;
  if (typeof on !== "boolean") throw new Refusal("say on: true or on: false");
  if (!(await publishedModel(id))) throw new Refusal("there is no shared model at that link", 404);
  await counted(account, table === "model_likes" ? "like" : "favourite");
  if (on) {
    if (table === "model_favourites") {
      const kept = await db(`model_favourites?account=eq.${account}&select=model&limit=${MOST_FAVOURITES + 1}`);
      if (kept.length >= MOST_FAVOURITES) throw new Refusal(`you keep ${MOST_FAVOURITES} already: let one go first`, 409);
    }
    await db(`${table}?on_conflict=model,account`, { method: "POST", body: { model: id, account },
      prefer: "resolution=ignore-duplicates" });
  } else {
    await db(`${table}?model=eq.${id}&account=eq.${account}`, { method: "DELETE" });
  }
  if (table === "model_likes") {
    const stats = await db(`model_stats?model=eq.${id}&select=likes`);
    return response.status(200).json({ id, liked: on, likes: Number(stats[0]?.likes) || 0 });
  }
  return response.status(200).json({ id, favourite: on });
}

async function favourites(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signedIn(request);
  return response.status(200).json(await withFaces(await models(originOf(request),
    { favourites: account, private: true, sort: "added" }, pageOf(request.query || {}))));
}

/// A list, as its owner or anybody may see it: {id, name, description,
/// public, owner, by, count, all}, or null when the asker may not. Its
/// counts have test models in them only when asked for (tests).
async function listFor(id, account, tests = false) {
  if (!ID.test(id || "")) return null;
  const list = await db("rpc/collection_page", { method: "POST", body: { list: id, tests } });
  if (!list || typeof list !== "object") return null;
  if (!list.public && list.owner !== account) return null;
  return list;
}

async function ownList(id, account) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`model_collections?id=eq.${id}&owner=eq.${account}&select=id,name,public`);
  return rows[0] || null;
}

async function saveList(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const name = cleanLine(body.name, 80);
  if (!name) throw new Refusal("give the list a name");
  const description = cleanLines(body.description, 500, "a list's description");
  if (body.public !== undefined && typeof body.public !== "boolean") throw new Refusal("public is true or false");
  checkNames({ "The collection's name": [name, "name"], "Its description": [description, "words"] });
  let id = body.id === undefined || body.id === null || body.id === "" ? "" : String(body.id);
  const was = id ? await ownList(id, account) : null;
  if (id && !was) throw new Refusal("there is no list of yours at that id", 404);
  // Public, newly or still: the age rule (api/_trust.js).
  const young = await publicTrouble(account, { collection: body.public === true
    ? (was && was.public ? "kept" : true) : body.public === undefined && was?.public ? "kept" : false });
  if (young) throw new Refusal(young, 422);
  await counted(account, "collection");
  const now = new Date().toISOString();
  if (id) {
    const changed = { name, description, updated_at: now };
    if (body.public !== undefined) changed.public = body.public;
    await db(`model_collections?id=eq.${id}&owner=eq.${account}`, { method: "PATCH", body: changed });
  } else {
    const lists = await db(`model_collections?owner=eq.${account}&select=id&limit=${MOST_LISTS + 1}`);
    if (lists.length >= MOST_LISTS) throw new Refusal(`you have ${MOST_LISTS} lists already: delete one first`, 409);
    id = newId();
    await db("model_collections", { method: "POST",
      body: { id, owner: account, name, description, public: body.public === true, updated_at: now } });
  }
  const saved = await listFor(id, account);
  return response.status(200).json({ id, name: saved.name, description: saved.description,
    public: saved.public, count: saved.all, url: `${originOf(request)}/c/${id}` });
}

async function dropList(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const id = String(request.query?.id || "");
  if (!(await ownList(id, account))) throw new Refusal("there is no list of yours at that id", 404);
  await db(`model_collections?id=eq.${id}&owner=eq.${account}`, { method: "DELETE" });
  return response.status(200).json({ id, deleted: true });
}

async function collect(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const list = await ownList(String(body.collection || ""), account);
  if (!list) throw new Refusal("there is no list of yours at that id", 404);
  const model = String(body.model || "");
  if (typeof body.on !== "boolean") throw new Refusal("say on: true or on: false");
  await counted(account, "collect");
  if (body.on) {
    if (!(await publishedModel(model))) throw new Refusal("there is no shared model at that link", 404);
    const held = await db(`model_collection_items?collection=eq.${list.id}&select=model&limit=${MOST_IN_A_LIST + 1}`);
    if (held.length >= MOST_IN_A_LIST) throw new Refusal(`a list holds ${MOST_IN_A_LIST} models at most`, 409);
    await db("model_collection_items?on_conflict=collection,model", { method: "POST",
      body: { collection: list.id, model }, prefer: "resolution=ignore-duplicates" });
  } else {
    if (!ID.test(model)) throw new Refusal("name a model by its link's id");
    await db(`model_collection_items?collection=eq.${list.id}&model=eq.${model}`, { method: "DELETE" });
  }
  await db(`model_collections?id=eq.${list.id}`, { method: "PATCH", body: { updated_at: new Date().toISOString() } });
  return response.status(200).json({ collection: list.id, model, has: body.on });
}

/// A list and a page of it. Its owner, signed in, sees every published
/// model in it; anybody else, if it is public, the listed ones.
async function collection(request, response) {
  let account = null;
  if (bearer(request)) account = await signedIn(request);
  const tests = testsAsked(request.query);
  response.setHeader("Cache-Control", account ? "private, no-store" : tests ? TESTS_CACHE : "no-cache");
  const id = String(request.query?.id || "");
  const list = await listFor(id, account, tests);
  if (!list) return response.status(404).json({ error: "there is no list at that id" });
  const mine = list.owner === account;
  const origin = originOf(request);
  const page = await models(origin, { collection: id, private: mine, sort: "added", tests },
    pageOf(request.query || {}));
  return response.status(200).json(await withFaces({ id, name: list.name, description: list.description, public: list.public,
    by: list.by, count: mine ? list.all : list.count, mine, url: `${origin}/c/${id}`, ...page }));
}

// ---------------------------------------------------------------------------
// Reports.

/// What somebody says should not be in the gallery: a model, a profile, a
/// public collection or a comment, a reason, a note and a way to reach
/// them, kept for the site's owner. Signed in or not; counted by the
/// account, or by the visitor's key for the day when there is none. A
/// comment's report names its model too (supabase/comments.sql).
async function report(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const body = request.body && typeof request.body === "object" ? request.body : {};
  let account = null;
  if (bearer(request)) account = await signedIn(request);
  const named = ["model", "handle", "collection", "comment", "photo"].filter((key) => body[key] !== undefined && body[key] !== "");
  if (named.length !== 1) throw new Refusal("name one thing: a model, a profile's handle, a collection, a comment or a photo");
  const target = {};
  // A counter-notice (web/takedown.html): about a model, which may be out
  // of the gallery already, with a way to reach whoever sends it.
  const counter = body.counter === true;
  if (counter && named[0] !== "model") throw new Refusal("a counter-notice is about a model: give its link");
  if (counter && !cleanLine(body.contact, 200)) throw new Refusal("a counter-notice needs a way to reach you");
  if (named[0] === "model") {
    const there = counter
      ? ID.test(String(body.model)) && (await db(`shared_models?id=eq.${String(body.model)}&select=id`)).length > 0
      : await publishedModel(String(body.model));
    if (!there) throw new Refusal("there is no shared model at that link", 404);
    target.model = String(body.model);
  } else if (named[0] === "comment") {
    const comment = Number(body.comment);
    const model = await commentModel(comment);
    if (!model) throw new Refusal("there is no such comment", 404);
    target.model = model;
    target.comment = comment;
  } else if (named[0] === "photo") {
    // A photo of a build: about its model as far as the reports' own check
    // goes, and report_photos says which photo.
    const photo = await photoRow(String(body.photo));
    if (!photo || photo.removed_at || photo.hidden_at || !(await publishedModel(photo.model))) {
      throw new Refusal("there is no photo at that id", 404);
    }
    target.model = photo.model;
    target.photo = photo.id;
  } else if (named[0] === "handle") {
    const person = await personOf(String(body.handle).toLowerCase());
    if (!person) throw new Refusal("nobody has that handle", 404);
    target.handle = person.handle;
  } else {
    const list = await listFor(String(body.collection), account);
    if (!list) throw new Refusal("there is no list at that id", 404);
    target.collection = list.id;
  }
  const reason = counter ? "other" : String(body.reason || "");
  if (!REASONS.has(reason)) throw new Refusal(`a reason is one of ${[...REASONS].join(", ")}`);
  let note = cleanLines(body.note, 1000, "a note");
  if (counter && !/^Counter-notice\b/.test(note || "")) note = `Counter-notice. ${note || ""}`.trim().slice(0, 1000);
  const contact = cleanLine(body.contact, 200) || null;
  const visitor = account ? null : visitorKey(request, "report");
  await counted(account || visitor, "report");
  const { photo: aboutPhoto, ...about } = target;
  const made = await db("reports", { method: "POST", body: { ...about, reason, note, contact: contact && contact.length >= 3 ? contact : null,
    reporter: account, visitor }, prefer: "return=representation" });
  if (aboutPhoto && Array.isArray(made) && made[0]?.id) await reportPhoto(made[0].id, aboutPhoto);
  // To the owner, by email, if this hour has not had its one (a test's,
  // rendered and recorded only). A digest that does not go is no reason
  // to tell the person their report did not: it is kept, and goes next.
  let digest = { state: "none" };
  try {
    if (Array.isArray(made) && made[0]?.id) digest = await sendDigest({ origin: originOf(request), report: made[0].id });
  } catch (trouble) {
    console.error(`people: report digest: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  return response.status(200).json({ reported: true, ...(digest.state === "dry"
    ? { digest: { state: "dry", id: digest.digest, reports: digest.reports } } : {}) });
}

/// The hourly knock: this hour's email of the owner's reports, if any
/// wait and it has not gone, and the day's email of new comments to each
/// model's owner who asked for one and has not had it today. Anybody may
/// knock; nothing else can be sent.
async function knock(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const origin = originOf(request);
  const sent = await sendDigest({ origin });
  let comments = [];
  try {
    comments = (await sendCommentDigests({ origin })).digests;
  } catch (trouble) {
    console.error(`people: comment digests: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  return response.status(200).json({ state: sent.state, reports: sent.reports || 0,
    comments: comments.map((one) => one.state) });
}

// ---------------------------------------------------------------------------
// Photos of real builds (api/_builds.js).

/// Said of a photo to anybody: never whose account it is, only the name
/// they show, if they made a profile.
export function photoSaid(origin, photo) {
  return { id: photo.id, model: photo.model, words: photo.words, width: photo.width, height: photo.height,
    at: photo.at, by: photo.by, url: `${origin}/api/people?op=photo_file&id=${photo.id}`,
    page: `${origin}/m/${photo.model}#photo-${photo.id}`, ...(photo.hidden ? { hidden: true } : {}) };
}

/// The age rule for a photo, in words, before the database's.
const oldEnough = (account) => async () => {
  const young = await publicTrouble(account, { photo: true });
  if (young) throw new Refusal(young, 422);
};

/// The model a photo is of: published, not taken out; with its owner.
async function photoModel(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`shared_models?id=eq.${id}&published=is.true&barred=is.false&select=id,owner,listed`);
  return rows[0] || null;
}

async function photoStart(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const model = await photoModel(String(body.model || ""));
  if (!model) throw new Refusal("there is no shared model at that link", 404);
  const started = await startPhoto(account, model.id, { type: String(body.type || ""), size: Number(body.size) },
    async () => {
      await oldEnough(account)();
      await counted(account, "photo");
    });
  return response.status(200).json(started);
}

async function photoKeep(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const model = await photoModel(String(body.model || ""));
  if (!model) throw new Refusal("there is no shared model at that link", 404);
  const words = cleanLine(body.words, MAX_WORDS) || null;
  checkNames({ "What you say about it": [words, "words"] });
  const kept = await keepPhoto(account, model.id, String(body.ticket || ""), words, oldEnough(account));
  const origin = originOf(request);
  return response.status(201).json(photoSaid(origin, { ...kept, model: model.id, at: new Date().toISOString(),
    by: (await db(`people?account=eq.${account}&select=handle,name`))[0] || null }));
}

/// The photos of a model that may be shown; signed in, the caller's own on
/// it (how many more they may add) and, for its owner, the hidden ones.
async function photos(request, response) {
  const model = await photoModel(String(request.query?.id || ""));
  let account = null;
  if (bearer(request)) account = await signedIn(request);
  response.setHeader("Cache-Control", account ? "private, no-store" : "public, max-age=0, s-maxage=30, stale-while-revalidate=30");
  if (!model) return response.status(404).json({ error: "there is no shared model at that link" });
  const owner = account !== null && model.owner === account;
  const origin = originOf(request);
  const shown = await photosWhere(`model=eq.${model.id}`, shownPublicly, { hidden: owner });
  const mine = account ? await photosWhere(`model=eq.${model.id}&account=eq.${account}`, async () => true,
    { hidden: true, limit: 3 }) : [];
  return response.status(200).json(await withFaces({ model: model.id, owner, photos: shown.map((one) => photoSaid(origin, one)),
    mine: mine.map((one) => photoSaid(origin, one)), left: account ? Math.max(0, 3 - mine.length) : null }));
}

async function photoServe(request, response) {
  const file = await photoFile(String(request.query?.id || ""), shownPublicly);
  if (!file) return response.status(404).setHeader("Cache-Control", "no-store").end("");
  response.setHeader("Content-Type", "image/jpeg");
  response.setHeader("X-Content-Type-Options", "nosniff");
  // Kept at the CDN for PICTURE_KEPT seconds, never stale, so a photo
  // hidden or taken out is gone from every cache that soon.
  response.setHeader("Cache-Control", PICTURE_CACHE);
  return response.status(200).end(file);
}

async function photoHide(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  if (typeof body.on !== "boolean") throw new Refusal("say on: true or on: false");
  await counted(account, "photo_hide");
  return response.status(200).json(await hidePhoto(account, String(body.photo || ""), body.on));
}

/// What [person] built that may be shown: their photos on models in the
/// gallery (a test model's only when asked for), each with its model's name.
async function builtBy(origin, person, tests) {
  const built = await photosWhere(`account=eq.${person.account}`, shownPublicly);
  const ids = [...new Set(built.map((one) => one.model))];
  const models = ids.length ? await db(`shared_models?id=in.(${ids.join(",")})&published=is.true&barred=is.false`
    + "&listed=is.true&select=id,name,test") : [];
  const named = new Map(models.filter((one) => tests || !one.test).map((one) => [one.id, one.name]));
  return built.filter((one) => named.has(one.model))
    .map((one) => ({ ...photoSaid(origin, one), model_name: named.get(one.model) }));
}

// ---------------------------------------------------------------------------
// The pages.

/// Its policy: itself, and the sign-in service for a report made signed in
/// (web/report.js, web/account.js).
function pageCsp() {
  let signIn = "";
  try {
    signIn = new URL(process.env.SUPABASE_URL || "").origin;
  } catch {
    signIn = "";
  }
  return "default-src 'none'; script-src 'self'; img-src 'self'; style-src 'self' 'unsafe-inline'; "
    + `connect-src 'self'${signIn ? ` ${signIn}` : ""}; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`;
}

function html(response, status, body, { tests = false } = {}) {
  response.setHeader("Content-Type", "text/html; charset=utf-8");
  response.setHeader("Content-Security-Policy", pageCsp());
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  // Kept briefly by the CDN, as a model's page is (api/share.js SHARED_CACHE);
  // never a page with test models on it.
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : "public, max-age=0, s-maxage=30, stale-while-revalidate=30");
  return response.status(status).end(body);
}

function head(origin, { title, about, url, image, robots = "", mine = false, share = false }) {
  return `<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(about)}">
${robots ? `<meta name="robots" content="${robots}">\n` : ""}${url ? `<link rel="canonical" href="${escapeHtml(url)}">\n` : ""}<meta property="og:type" content="profile">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(about)}">
${url ? `<meta property="og:url" content="${escapeHtml(url)}">\n` : ""}<meta property="og:image" content="${escapeHtml(image || `${origin}/share.png`)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(about)}">
<meta name="twitter:image" content="${escapeHtml(image || `${origin}/share.png`)}">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
${siteChrome().head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/report.js" type="module"></script>
<script src="/follow.js" type="module"></script>${mine ? `
<script src="/designs.js" type="module"></script>` : ""}${mine || share ? `
<script src="/person.js" type="module"></script>` : ""}`;
}

function page(origin, { title, about, url, image, robots, main, mine = false, share = false }) {
  const { header, footer } = siteChrome();
  return `<!doctype html>
<html lang="en">
<head>
${head(origin, { title, about, url, image, robots, mine, share })}
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
${header}
<main id="main">
${main}
</main>
${footer}
</body>
</html>`;
}

function missingPage(origin, what) {
  return page(origin, { title: `${what} — Brickworks`, about: "A page of the Brickworks gallery.", robots: "noindex",
    main: `<div class="wrap gone"><h1>${escapeHtml(what)}</h1>
  <p class="lede">The address may be mistyped, or what was here has gone.</p>
  <div class="actions"><a class="cta" href="/gallery">See the gallery</a></div></div>` });
}

const SINCE = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });
const SINCE_DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });

/// A count is said once there is one: never "0 likes" (docs/SOCIAL.md).
/// Kept on the page, hidden, where web/follow.js counts it again.
const zero = (n) => (Number(n) ? "" : " hidden");

/// The row of numbers under a person's name: what their work earned and who
/// follows them, one kind of number, each said once there is one. Builds
/// finished of their models and remixes first, as the gallery's Top builds
/// weighs them. Each is the sum of what the cards say. Followers is
/// [data-followers], which web/follow.js counts again once somebody follows.
function numbersHtml(earned, about, follows) {
  const stat = (kind, n, one, many, extra = "") => `<li data-stat="${kind}"${extra}${zero(n)}>`
    + `<b>${escapeHtml((Number(n) || 0).toLocaleString("en-US"))}</b> <span>${escapeHtml(Number(n) === 1 ? one : many)}</span></li>`;
  const ready = follows && follows.ready;
  return `<ul class="numbers" aria-label="Their numbers">`
    + stat("builds", earned?.builds, "build finished", "builds finished")
    + stat("remixes", earned?.remixes, "remix", "remixes")
    + stat("models", earned ? earned.models : about?.models, "model", "models")
    + stat("likes", earned ? earned.likes : about?.likes, "like", "likes")
    + (ready ? stat("followers", follows.followers, "follower", "followers", " data-followers") : "")
    + (ready ? stat("following", follows.following, "following", "following") : "")
    + "</ul>";
}

/// A set of photos of real builds: [photos] each with its model's name;
/// [by] says who built each, for the photos of a designer's models. Any
/// shape, so in columns (docs/SOCIAL.md D4).
function stripHtml(photos, { by = false } = {}) {
  return photos.map((one) => `<figure class="build" id="photo-${one.id}"><a href="/m/${one.model}#photo-${one.id}">`
    + `<img src="/api/people?op=photo_file&amp;id=${one.id}" alt="${escapeHtml(`A build of ${one.model_name}`)}" `
    + `width="${Number(one.width) || 1}" height="${Number(one.height) || 1}" loading="lazy" decoding="async"></a>`
    + `<figcaption>${one.words ? `<q>${escapeHtml(one.words)}</q>` : ""}<a href="/m/${one.model}">${escapeHtml(one.model_name)}</a>`
    + `${by ? `, built by ${one.by ? `<a href="/u/${escapeHtml(one.by.handle)}">${escapeHtml(one.by.name)}</a>` : "a builder"}` : ""}`
    + "</figcaption></figure>").join("");
}

/// A profile's tabs, each a page of its own (?tab=): its work, its builds,
/// its lists, and the models they liked when they chose to show them, each
/// with its count once there is one.
const TABS = [["models", "Models"], ["builds", "Builds"], ["collections", "Collections"], ["likes", "Likes"]];

/// /u/X: a person's page, the same for everybody it shows, the house's
/// too. Their avatar, name, handle, words, links and numbers, Follow, Share
/// and More; the models they pinned; then a tab: Models (every one, page by
/// page, by Top builds), Builds (photos of their real builds, and other
/// people's of their models) or Collections (their public lists), the first
/// that has something unless one is asked for. Whom they follow, when they
/// chose to show it; never who follows them. The designer's own numbers are
/// not in it: web/designs.js asks for them with their sign-in and puts them
/// in #designs-mine, so this page, which the CDN keeps, is the same for
/// everybody.
async function profilePage(request, response) {
  const origin = originOf(request);
  const handle = String(request.query?.handle || "").toLowerCase();
  const tests = testsAsked(request.query);
  const person = await personOf(handle);
  if (!person) return html(response, 404, missingPage(origin, "Nobody here has that handle"), { tests });
  const asked = TABS.some(([id]) => id === request.query?.tab) ? String(request.query.tab) : "";
  const number = Number(request.query?.page ?? 1);
  const at = Number.isInteger(number) && number >= 1 && number <= MOST_PAGES ? number : 1;
  const [shown, about, built, follows, following, designer, wins, shows, liked] = await Promise.all([
    models(origin, { owner: person.account, tests, sort: "top" }, asked === "models" || !asked ? at : 1),
    db("rpc/profile_page", { method: "POST", body: { wanted: handle, tests } }),
    builtBy(origin, person, tests),
    followsOf(handle),
    followingOf(handle),
    designerOf(origin, handle, tests),
    winsBy(person.account, tests).catch(() => []),
    showsOf(person.account),
    likedShown(person.account, tests),
  ]);
  const showcase = await showcaseOf(origin, person, shows, tests);
  // Their picture, and the faces of whom they follow, in one lookup.
  await withFaces([person, following]);
  const url = `${origin}/u/${person.handle}`;
  const earned = designer && designer.ready && designer.models > 0 ? designer : null;
  const lists = (about?.collections || []).filter((list) => ID.test(String(list.id)));
  const theirs = earned ? earned.photos : [];
  const counts = { models: Number(about?.models) || 0, builds: built.length + theirs.length, collections: lists.length,
    likes: liked ?? 0 };
  // Likes only when they chose to show them: else no tab, and ?tab=likes
  // is any other profile's first tab.
  const tabs = TABS.filter(([id]) => id !== "likes" || liked !== null);
  // The tab asked for; else the first with something in it.
  const tab = (tabs.some(([id]) => id === asked) ? asked : "") || tabs.map(([id]) => id).find((id) => counts[id] > 0) || "models";
  const query = (more) => {
    const said = new URLSearchParams(more);
    if (tests) said.set("tests", "1");
    const text = said.toString();
    return text ? `?${text}` : "";
  };
  const name = escapeHtml(person.name);
  const since = Date.parse(person.created_at || "");

  // The head: who they are, what they said, where else they are, their
  // numbers, and what can be done here.
  const won = wins.map((win) => `<li data-won="${escapeHtml(win.model)}"><a class="pill new" href="/m/${escapeHtml(win.model)}"`
    + ` title="${escapeHtml(`${win.name}: ${count(win.votes, "vote")}`)}">${escapeHtml(wonSaid(win))}</a></li>`).join("");
  const links = showcase.links.map((link) => `<li><a href="${escapeHtml(link.href)}" rel="ugc nofollow noopener" target="_blank">`
    + `${escapeHtml(link.said)}</a></li>`).join("");
  const more = `<details class="more-menu end"><summary class="icon-btn" aria-label="More">${iconHtml("more")}</summary>`
    + `<div class="menu-list"><button type="button" data-report="this profile" data-report-handle="${escapeHtml(person.handle)}" hidden>`
    + "Report it</button><a href=\"/takedown\">Takedown requests</a></div></details>";
  // The banner is its model's picture with nothing behind the model, on
  // the theme's own ground as a card's is (web/directory.css); the server
  // gives the picture itself for a model published before cut-outs.
  const head = `${showcase.banner ? `<div class="banner"><img src="/m/${showcase.banner}.cutout.png" alt="" width="1200" height="630" decoding="async"></div>` : ""}
  <header class="profile-head">
    ${avatarHtml({ handle: person.handle, name: person.name, picture: person.picture }, { size: "huge" })}
    <div class="who">
      <h1>${name}</h1>
      <p class="handle">@${escapeHtml(person.handle)} · <span data-role>${earned ? "Designer" : "Builder"}</span>${Number.isFinite(since)
        ? ` · building here since ${SINCE.format(since)}` : ""}</p>
    </div>
    <div class="acts">
      ${follows && follows.ready ? `<p class="follow-line"><button type="button" class="cta ghost follow"
        data-follow="${escapeHtml(person.handle)}" hidden>Follow</button><span class="said" role="status"></span></p>
      <a class="cta ghost" href="/profile?edit=1" data-edit-own hidden>Edit profile</a>` : ""}
      ${iconButtonHtml({ icon: "share", name: "Share", attrs: `data-share="${escapeHtml(url)}" hidden` })}
      ${more}
    </div>
  </header>
  ${person.bio ? `<p class="bio">${escapeHtml(person.bio)}</p>` : ""}
  ${links ? `<ul class="links" aria-label="Elsewhere">${links}</ul>` : ""}
  ${numbersHtml(earned, about, follows)}
  ${won ? `<ul class="pills wins" aria-label="Challenges won">${won}</ul>` : ""}`;

  // Pinned: up to three of their models, in the order they chose.
  await withFaces(showcase.pins);
  const pinned = showcase.pins.length ? `<section class="pinned" aria-labelledby="pinned-h"><h2 id="pinned-h">Pinned</h2>
    <div class="models row">${showcase.pins.map((card) => cardHtml({ ...card, comments: earned?.cards[card.id]?.comments ?? 0 },
      { earned: Boolean(earned) })).join("")}</div></section>` : "";

  // The tab.
  let panel = "";
  if (tab === "models") {
    const cards = (await withWins(await withFaces(shown.models), tests))
      .map((card) => ({ ...card, comments: earned?.cards[card.id]?.comments ?? 0 }));
    const first = shown.page === 1 ? cards[0] : null;
    // The model to start with: the first by Top builds, once somebody built it.
    const start = earned && first && first.builds > 0 ? first : null;
    panel = cards.length ? `${start ? `<p class="start-with">Start with their most built:
      <a href="/m/${start.id}">${escapeHtml(start.name)}</a>, ${escapeHtml(count(start.builds, "build"))} finished${start.tested ? ", Tested" : ""}.
      <a class="cta small" href="/app?view=${start.id}&amp;build">Build it</a></p>` : ""}
    ${earned && counts.models > 1 && earned.builds + earned.remixes > 0 ? `<p class="note">Most built first: a build finished counts most, then a remix and the Tested mark.</p>` : ""}
    <div class="models" data-models data-page="${shown.page}">${cards.map((card) => cardHtml(card, { earned: Boolean(earned) })).join("")}</div>
    ${shown.more || shown.page > 1 ? `<p class="paging">${shown.more ? `<a class="cta ghost" data-more="${shown.page + 1}"
      href="/u/${escapeHtml(person.handle)}${escapeHtml(query({ tab: "models", page: shown.page + 1 }))}">Show more</a>` : ""}${shown.page > 1
      ? ` <a href="/u/${escapeHtml(person.handle)}${escapeHtml(query({ tab: "models" }))}">Back to the first</a>` : ""}</p>` : ""}`
      : `<p class="state">Nothing in the gallery yet. The models ${name} shares in the gallery with their name show here.</p>`;
  } else if (tab === "builds") {
    panel = counts.builds ? `${built.length ? `<section class="builds-made" aria-labelledby="built-h"><h2 id="built-h">Built by ${name}</h2>
      <p class="note">Photos of their real builds of models in the gallery.</p>
      <div class="build-grid">${stripHtml(built)}</div></section>` : ""}
    ${theirs.length ? `<section class="builds-of" aria-labelledby="built-of-h"><h2 id="built-of-h">Built by others</h2>
      <p class="note">${escapeHtml(earned.builders === 1 ? "One person" : `${earned.builders.toLocaleString("en-US")} people`)} posted photos of their real builds of ${name}’s models.</p>
      <div class="build-grid">${stripHtml(theirs, { by: true })}</div></section>` : ""}`
      : `<p class="state">No builds yet. Photos of real builds show here: the ones ${name} posts of what they built, and the ones other people post of ${name}’s models.</p>`;
  } else if (tab === "likes") {
    const page = await likedPage(origin, person, at, tests);
    const cards = page ? await withWins(await withFaces(page.models), tests) : [];
    panel = cards.length ? `<p class="note">${name} chose to show the models they liked, newest first.</p>
    <div class="models" data-models data-page="${page.page}">${cards.map((card) => cardHtml(card)).join("")}</div>
    ${page.more || page.page > 1 ? `<p class="paging">${page.more ? `<a class="cta ghost" data-more="${page.page + 1}"
      href="/u/${escapeHtml(person.handle)}${escapeHtml(query({ tab: "likes", page: page.page + 1 }))}">Show more</a>` : ""}${page.page > 1
      ? ` <a href="/u/${escapeHtml(person.handle)}${escapeHtml(query({ tab: "likes" }))}">Back to the first</a>` : ""}</p>` : ""}`
      : `<p class="state">No likes yet. The models ${name} likes in the gallery show here, as they chose.</p>`;
  } else {
    const covers = lists.length ? await coversOf(lists, tests) : new Map();
    panel = lists.length ? `<div class="list-cards">${lists.map((list) => listCardHtml(list, covers)).join("")}</div>`
      : `<p class="state">No collections yet. The lists of models ${name} makes public show here.</p>`;
  }
  const tabsHtml = `<nav class="tabs" aria-label="${name}’s work">${tabs.map(([id, label]) =>
    `<a href="/u/${escapeHtml(person.handle)}${escapeHtml(query({ tab: id }))}" data-tab="${id}"${id === tab ? ' aria-current="page"' : ""}>`
    + `${label}${counts[id] ? ` <span class="n">${escapeHtml(counts[id].toLocaleString("en-US"))}</span>` : ""}</a>`).join("")}</nav>`;

  const main = `<div class="wrap person profile${earned ? " designer" : ""}${showcase.banner ? " bannered" : ""}" data-handle="${escapeHtml(person.handle)}">
  ${head}
  <section class="designs" id="designs-mine" aria-label="Your models, as only you see them" hidden></section>
  ${pinned}
  <div class="work" id="work">
  ${tabsHtml}
  <div class="tab-panel" data-panel="${tab}">${panel}</div>
  </div>
  ${following.length ? `<section class="follows" aria-labelledby="follows-h"><h2 id="follows-h">Follows</h2>
    <p class="note">${name} chose to show whom they follow.</p>
    <ul class="pills">${following.map((one) => `<li><a class="pill" href="/u/${escapeHtml(one.handle)}">`
      + `${avatarHtml({ handle: one.handle, name: one.name, picture: one.picture }, { size: "small" })}${escapeHtml(one.name)}</a></li>`).join("")}</ul></section>` : ""}
</div>`;
  const told = earned
    ? `${count(earned.models, "model")} by ${person.name}, ${count(earned.builds, "build")} finished and ${count(earned.remixes, "remix", "remixes")}: designed in Brickworks.`
    : `${count(about?.models ?? 0, "model")} by ${person.name}, built in Brickworks and shared in its gallery.`;
  const picture = showcase.banner ? `${origin}/m/${showcase.banner}.png` : shown.models[0]?.image || "";
  return html(response, 200, page(origin, {
    title: `${person.name} (@${person.handle}) — ${earned ? "a designer in" : "models built in"} Brickworks`,
    about: person.bio ? person.bio.replace(/\s+/g, " ").slice(0, 160) : told,
    url, image: picture, main, mine: true,
  }), { tests });
}

/// /c/X: a public list's page. A private one is not shown here to anybody;
/// its owner sees it on /profile. Its head as a playlist's or a board's
/// is (docs/SOCIAL.md U11): its cover, up to four of its models' pictures,
/// beside its name, whose it is, its words and numbers, Follow, Share and
/// More; then its models, the last put in first. How many follow it, never
/// who; Follow is shown by web/follow.js once it knows who is asking.
async function listPage(request, response) {
  const origin = originOf(request);
  const id = String(request.query?.id || "");
  const tests = testsAsked(request.query);
  const list = await listFor(id, null, tests);
  if (!list) return html(response, 404, missingPage(origin, "There is no collection here"), { tests });
  const [shown, covers, follows] = await Promise.all([
    withFaces(await models(origin, { collection: id, sort: "added", tests }, 1)),
    coversOf([list], tests),
    listFollowsOf(id).catch(() => null),
  ]);
  const url = `${origin}/c/${id}`;
  const by = list.by ? `<a href="/u/${escapeHtml(list.by.handle)}">${escapeHtml(list.by.name)}</a>` : "a Brickworks builder";
  const first = shown.models[0];
  const updated = Date.parse(list.updated_at || "");
  const stat = (kind, n, one, many, extra = "") => `<li data-stat="${kind}"${extra}${zero(n)}>`
    + `<b>${escapeHtml((Number(n) || 0).toLocaleString("en-US"))}</b> <span>${escapeHtml(Number(n) === 1 ? one : many)}</span></li>`;
  const ready = follows && follows.ready;
  const more = `<details class="more-menu end"><summary class="icon-btn" aria-label="More" title="More">${iconHtml("more")}</summary>`
    + `<div class="menu-list"><button type="button" data-report="this collection" data-report-collection="${id}" hidden>`
    + "Report it</button><a href=\"/takedown\">Takedown requests</a></div></details>";
  const main = `<div class="wrap person list" data-id="${id}">
  <header class="list-head">
    <div class="cover">${mosaicHtml(covers.get(id) || [])}</div>
    <div class="who">
      <p class="eyebrow">Collection</p>
      <h1>${escapeHtml(list.name)}</h1>
      <p class="handle">Collected by ${by}${Number.isFinite(updated) ? ` · updated ${SINCE_DAY.format(updated)}` : ""}</p>
      ${list.description ? `<p class="bio">${escapeHtml(list.description)}</p>` : ""}
      <ul class="numbers" aria-label="Its numbers">${stat("models", list.count, "model", "models")}${ready
        ? stat("followers", follows.followers, "follower", "followers", ` data-list-followers="${id}"`) : ""}</ul>
      <div class="acts">
        ${ready ? `<p class="follow-line"><button type="button" class="cta ghost follow" data-follow-list="${id}" hidden>Follow</button>`
          + `<span class="said" role="status"></span></p>` : ""}
        ${iconButtonHtml({ icon: "share", name: "Share", attrs: `data-share="${escapeHtml(url)}" hidden` })}
        ${more}
      </div>
    </div>
  </header>
  ${shown.models.length ? `<div class="models">${shown.models.map((card) => cardHtml(card)).join("")}</div>`
    : `<p class="state">Nothing in it is in the gallery just now. The models put in it show here once they are.</p>`}
</div>`;
  return html(response, 200, page(origin, {
    title: `${list.name} — a collection in the Brickworks gallery`,
    about: list.description ? list.description.replace(/\s+/g, " ").slice(0, 160)
      : `${count(list.count, "model")} built in Brickworks, collected by ${list.by ? list.by.name : "a builder"}.`,
    url, image: first && first.image ? first.image : "", main, share: true,
  }), { tests });
}

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response.status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }
  response.setHeader("Access-Control-Allow-Origin", "*");
  if (!dbConfigured()) return response.status(503).json({ error: "the directory is not set up on this deployment" });
  const op = String(request.query?.op || "");
  try {
    // HEAD as GET, its body left off by the server.
    if (request.method === "GET" || request.method === "HEAD") {
      if (op === "me") return await me(request, response);
      if (op === "profile") return await profile(request, response);
      if (op === "page") return await profilePage(request, response);
      if (op === "likes") return await likes(request, response);
      if (op === "avatar") return await avatarServe(request, response);
      if (op === "marks") return await marks(request, response);
      if (op === "favourites") return await favourites(request, response);
      if (op === "collection") return await collection(request, response);
      if (op === "list_page") return await listPage(request, response);
      if (op === "comments") return await listComments(request, response);
      if (op === "photos") return await photos(request, response);
      if (op === "photo_file") return await photoServe(request, response);
      if (op === "follows") return await getFollows(request, response);
      if (op === "list_follows") return await getListFollows(request, response);
      if (op === "following") return await getFollowing(request, response);
      if (op === "feed") return await feed(request, response, { origin: originOf(request) });
      if (op === "latest") return await latest(request, response, { origin: originOf(request) });
      if (op === "feed_count") return await feedCount(request, response);
      if (op === "notifications") return await notifications(request, response, { origin: "" });
      if (op === "designs") return await designs(request, response, { origin: originOf(request) });
      if (op === "challenge") return await challenge(request, response, { origin: originOf(request) });
      if (op === "challenge_entry") return await challengeEntry(request, response);
    } else if (request.method === "POST") {
      if (op === "photo_start") return await photoStart(request, response);
      if (op === "photo") return await photoKeep(request, response);
      if (op === "photo_hide") return await photoHide(request, response);
      if (op === "profile") return await saveProfile(request, response);
      if (op === "showcase") return await saveShowcase(request, response);
      if (op === "avatar") return await saveAvatar(request, response);
      if (op === "avatar_remove") return await dropOwnAvatar(request, response);
      if (op === "likes_choice") return await saveLikesChoice(request, response);
      if (op === "like") return await toggle(request, response, "model_likes");
      if (op === "favourite") return await toggle(request, response, "model_favourites");
      if (op === "collection") return await saveList(request, response);
      if (op === "uncollection") return await dropList(request, response);
      if (op === "collect") return await collect(request, response);
      if (op === "report") return await report(request, response);
      if (op === "digest") return await knock(request, response);
      if (op === "comment") return await addComment(request, response, { origin: originOf(request) });
      if (op === "reply") return await addReply(request, response, { origin: originOf(request) });
      if (op === "comment_change") return await changeComment(request, response);
      if (op === "comments_open") return await setCommentsOpen(request, response);
      if (op === "mail") return await chooseMail(request, response);
      if (op === "follow") return await follow(request, response);
      if (op === "list_follow") return await listFollow(request, response);
      if (op === "follow_choice") return await followChoice(request, response);
      if (op === "notifications_read") return await notificationsRead(request, response);
      if (op === "enter") return await enter(request, response);
      if (op === "withdraw") return await withdraw(request, response);
      if (op === "vote") return await vote(request, response);
    } else {
      return response.status(405).json({ error: "GET or POST" });
    }
    return response.status(400).json({ error: `unknown op ${op}` });
  } catch (trouble) {
    if (trouble instanceof AuthError || trouble instanceof Refusal || trouble instanceof Unacceptable
        || trouble instanceof BuildRefusal || trouble instanceof AvatarRefusal) {
      return response.status(trouble.status).json({ error: trouble.message });
    }
    console.error("people:", trouble.message);
    return response.status(502).json({ error: "Brickworks could not reach its storage just now. Try again in a minute." });
  }
}
