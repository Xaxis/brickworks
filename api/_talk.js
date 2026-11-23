// Talk, the builders' forum (2026-11-22, unit talk; supabase/talk.sql,
// docs/SOCIAL.md section 10). api/people.js answers the requests with
// these. Every page here is made by the server whole, so a search engine,
// a chat app's link card and a phone without the script read the talk
// itself; web/talk.js then draws it again as the signed-in reader sees it
// (their blocks, their own hidden posts) and does what they press.
//
//   GET  ?op=talk_page             /talk: the threads of every board, newest
//                                  talk first (pinned first), the boards, a
//                                  search, and the talk on models beside them;
//                                  &board=B /talk/b/<board>; &q=Q a search;
//                                  &before=ISO older threads
//   GET  ?op=talk_page&thread=N    /talk/t/<n>: a thread, its posts, the
//                                  models, steps, sets and challenges they
//                                  link drawn as cards, and its schema.org
//                                  DiscussionForumPosting
//   GET  ?op=talk_page&new=1       /talk/new: start a thread (&board=B,
//                                  &model=X: a Show and tell of model X)
//   GET  ?op=talk&board=B&q=Q&before=ISO   the threads as JSON
//   GET  ?op=talk_thread&id=N      a thread as the caller sees it, JSON; with
//                                  &html=1 its posts drawn, for web/talk.js
//   GET  ?op=talk_latest&n=4       the newest threads (&html=1 drawn), for
//                                  the homepage's Latest talk (#talk-latest)
//   GET  ?op=talk_rss[&board=B]    /talk.rss, /talk/b/<board>.rss: RSS 2.0
//   GET  ?op=talk_model&id=X       model X's Show and tell thread, if any
//   GET  ?op=talk_photo&id=P       /talk/p/<id>.jpg: a post's photo while the
//                                  post may be seen; &size=card its copy
//   POST ?op=talk_start            (session) {board, title, body, model?,
//                                  photo?}: a thread and its first post
//   POST ?op=talk_reply            (session) {thread, body, answers?, photo?}
//   POST ?op=talk_change           (session) {post, what: edit|remove, body?}
//   POST ?op=talk_follow           (session) {thread, on}
//   POST ?op=talk_read             (session) {thread}: read up to now
//   POST ?op=talk_photo_start      (session) {type, size}: where the photo is
//                                  sent, as a build's photo is (api/_builds.js)
//   POST ?op=report {post, reason, note?}  (api/people.js report, reportPost)
//
// A post is plain text, as a comment is. A link to this site's model, step,
// set or challenge is drawn as a card under the words; a link to a part on
// Rebrickable or BrickLink as the part's number; any other link stays the
// words it is and is never made a link, so Talk is no place to put one
// (the first thing a spammer wants). @handle names somebody, as in a
// comment. Never empty: the house (Brickworks' own account) writes the first
// threads, each once, dated when first written (HOUSE_THREADS); each
// month's challenge opens its own thread (talk_ensure); and the talk under
// the gallery's models is shown beside the threads.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import {
  SITE_LANGS, TESTS_CACHE, Unacceptable, asText, escapeHtml, inLanguage, sayHtml, siteChrome, siteWords, summary,
  testsAsked, visitorKey,
} from "./_directory.js";
import { namesTrouble } from "./_names.js";
import { storeRoot } from "./_omr_credit.js";
import { unnameable } from "./_blocks.js";
import { withFaces } from "./_faces.js";
import { PHOTOS, TICKET, UPLOADS, deleteFiles, getFile, putFile, signUpload } from "./_builds.js";
import { MAX_PHOTO_BYTES, PhotoTrouble, TYPES, cleanPhoto } from "./_photo.js";
import { avatarHtml, langAt, mentionPieces, mentionsIn, number, say } from "./_card.js";
import {
  ASK_EVERY_S, NOT_YET as ASKS_NOT_YET, askHtml, askOf, askRefused, asksOn, asksReady, pinLineHtml, placesAsked, withAsks,
} from "./_asks.js";

export const BOARDS = ["show", "help", "ideas", "challenges", "news"];
export const MOST_CHARACTERS = 4000;
export const MOST_TITLE = 120;
const PER_PAGE = 30;
const NOT_THERE = /: 404$/;
const NOT_YET = "Talk is not open on Brickworks yet.";
const SHARED_CACHE = "public, max-age=0, s-maxage=30, stale-while-revalidate=30";
const SITE_HOSTS = new Set(["brickworks.diy", "www.brickworks.diy"]);
const MODEL = /^[A-Za-z0-9]{10}$/;
const PHOTO = /^[A-Za-z0-9]{12}$/;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
// schema.org's types and RSS's head: code, never words to translate.
const PERSON = "Person";
const COMMENT = "Comment";
const RSS_HEAD = '<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" '
  + 'xmlns:dc="http://purl.org/dc/elements/1.1/">';

// What a refusal from talk.sql says, and its status.
export const WORDS = {
  sign_in: [401, "Sign in to write in Talk: we email you a code, no password. Anyone can read it."],
  ask_first: [422, "Brickworks asks everyone one question first. Sign in again, in the app or on "
    + "brickworks.diy, to answer it, then write your post."],
  under_13: [422, "Talk is for people 13 and over, so you can read it but not write in it."],
  barred: [403, "Brickworks took this account out of the gallery, so it cannot write in Talk."],
  banned: [403, "This account may not write in Talk for now."],
  board: [400, "Choose a board: Show and tell, Help, Ideas or Challenges."],
  news: [403, "Only Brickworks starts a thread in News. Reply to one, or start yours in another board."],
  title: [400, "A title is 3 to 120 characters on one line."],
  body: [400, "A post is 1 to 4,000 characters of plain text."],
  model: [403, "A Show and tell thread can be about one of your own shared models."],
  model_has: [409, "That model has its Show and tell thread already: add to it."],
  no_thread: [404, "That thread is not there any more."],
  no_post: [404, "That post is not there any more."],
  locked: [409, "This thread is locked: it takes no new posts."],
  blocked: [403, "You blocked somebody in this conversation, so you cannot post here."],
  blocked_by: [403, "You cannot post here."],
  not_yours: [403, "That post is somebody else's."],
  again: [409, "You posted those words a moment ago."],
  limit: [429, "That is a lot of posts in a short time: try again in an hour."],
  yours: [400, "That post is yours: edit it or remove it instead."],
};

function refused(code) {
  const [status, words] = WORDS[code] || [400, "That could not be done."];
  return new Unacceptable(words, status);
}

/// An rpc of talk.sql, or [missing]'s answer when the file is not applied.
async function call(name, body, missing) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || "")) && missing !== undefined) return missing();
    throw trouble;
  }
}
const notYet = () => {
  throw new Unacceptable(NOT_YET, 503);
};

async function account(request) {
  return (await verify(bearer(request), request)).sub;
}

/// The caller's account when they sent a sign-in, else null.
async function reader(request) {
  return bearer(request) ? account(request) : null;
}

const langOf = (query) => (SITE_LANGS.includes(String(query?.lang || "")) ? String(query.lang) : "en");
const bodyOf = (request) => (request.body && typeof request.body === "object" ? request.body : {});
const whole = (given) => {
  const n = Number(given);
  return Number.isSafeInteger(n) && n > 0 ? n : null;
};

// ---------------------------------------------------------------------------
// Pure: what somebody typed, made plain.

/// A post's words: {text} or {trouble} in words. Line ends kept (three or
/// more made two), every other unprintable character a space, runs of space
/// one, each line's end trimmed; 1 to 4,000 characters as the database
/// counts them; no word the gallery does not show (api/_names.js).
export function cleanPost(given) {
  if (typeof given !== "string") return { trouble: say("Say something first: a post is 1 to 4,000 characters.") };
  // Every space of Unicode's one space (an em space, a no-break or an
  // ideographic one, the BOM), and a line or paragraph separator a line end.
  const text = given.replace(/\r\n?|[\u2028\u2029]/g, "\n")
    .replace(/[\u0000-\u0009\u000b-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2060\u2066-\u2069]+/g, " ")
    .split("\n").map((line) => line.replace(/\s+/g, " ").trimEnd()).join("\n")
    .replace(/\n{3,}/g, "\n\n").trim();
  const length = [...text].length;
  if (length === 0) return { trouble: say("Say something first: a post is 1 to 4,000 characters.") };
  if (length > MOST_CHARACTERS) return { trouble: say("A post is at most 4,000 characters; that is {n}.", { n: number(length) }) };
  if (namesTrouble({ post: [text, "words"] })) return { trouble: say("Your post has a word in it Talk does not show: say it another way.") };
  return { text };
}

/// A thread's title: one line, 3 to 120 characters, checked as a post is.
export function cleanTitle(given) {
  if (typeof given !== "string") return { trouble: say("A title is 3 to 120 characters on one line.") };
  const text = given.replace(/[\u0000-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2060\u2066-\u2069]+/g, " ")
    .replace(/\s+/g, " ").trim();
  const length = [...text].length;
  if (length < 3 || length > MOST_TITLE) return { trouble: say("A title is 3 to 120 characters on one line.") };
  if (namesTrouble({ title: [text, "words"] })) return { trouble: say("Your title has a word in it Talk does not show: say it another way.") };
  return { text };
}

/// "how-do-i-join-two-plates": a thread's title in its address, for a
/// person and a search engine; the number alone finds it.
export function slugOf(title) {
  return String(title || "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60).replace(/-+$/, "");
}

/// A thread's own address: /talk/t/12/how-do-i-join-two-plates.
export const threadPath = (thread) => {
  const slug = slugOf(thread?.title);
  return `/talk/t/${Number(thread?.id) || 0}${slug ? `/${slug}` : ""}`;
};

const URL_IN = /\bhttps?:\/\/[^\s<>"'`]+/gi;

/// What a link in a post is: {href, kind, ...} for a page of this site
/// ([hosts]: brickworks.diy and the address the page is served at), {kind:
/// "part", part} for a part on Rebrickable or BrickLink, else null (the
/// words stay words). [href] is the link's path on this site, so a card
/// opens where the reader is. Pure.
export function linkOf(raw, hosts = SITE_HOSTS) {
  let url;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  const host = url.hostname.toLowerCase();
  if (host === "rebrickable.com" || host === "www.rebrickable.com") {
    const part = url.pathname.match(/^\/parts\/([A-Za-z0-9][A-Za-z0-9._-]{0,29})\/?/);
    return part ? { kind: "part", part: part[1] } : null;
  }
  if (host === "bricklink.com" || host === "www.bricklink.com") {
    const part = url.searchParams.get("P");
    return part && /^[A-Za-z0-9][A-Za-z0-9._-]{0,29}$/.test(part) ? { kind: "part", part } : null;
  }
  if (!hosts.has(host) || (url.protocol !== "https:" && url.protocol !== "http:")) return null;
  // "https://brickworks.diy//elsewhere.example": its path would be a link
  // to another site that looks like ours. Words, then.
  if (/^\/[/\\]/.test(url.pathname)) return null;
  const path = url.pathname.replace(/^\/(?:de|fr|es)(?=\/)/, "");
  const href = `${url.pathname}${url.search}${url.hash}`;
  const n = (given) => (/^[1-9][0-9]{0,8}$/.test(String(given || "")) ? Number(given) : null);
  let found = path.match(/^\/m\/([A-Za-z0-9]{10})(?:\/v\/([1-9][0-9]{0,5}))?\/?$/);
  if (found) {
    const step = n(url.searchParams.get("step"));
    // A version's own page (/m/X/v/N): its card is that version's, with its
    // picture, as a work in progress posts each one (api/_wip.js).
    const version = found[2] ? Number(found[2]) : null;
    return step ? { href, kind: "step", model: found[1], step }
      : { href, kind: "model", model: found[1], ...(version ? { version } : {}) };
  }
  if (path === "/app" && MODEL.test(url.searchParams.get("view") || "")) {
    const step = n(url.searchParams.get("step"));
    const model = url.searchParams.get("view");
    return step ? { href, kind: "step", model, step } : { href, kind: "model", model };
  }
  found = path.match(/^\/library\/set\/([A-Za-z0-9][A-Za-z0-9.-]{0,29})\/?$/);
  if (found) return { href, kind: "set", set: found[1] };
  if (path === "/challenge" || path === "/challenge/") {
    const id = n(url.searchParams.get("id"));
    return id ? { href, kind: "challenge", challenge: id } : { href, kind: "page" };
  }
  found = path.match(/^\/talk\/t\/([1-9][0-9]{0,11})(?:\/[a-z0-9-]*)?\/?$/);
  if (found) return { href, kind: "thread", thread: Number(found[1]) };
  return { href, kind: "page" };
}

/// [text] in pieces: {text} for words, {link, at} for a link of this site
/// or a part (linkOf), as typed in [at]. A link's last full stop, comma or
/// bracket is the sentence's, not the link's. Pure.
export function piecesOf(text, hosts = SITE_HOSTS) {
  const pieces = [];
  let from = 0;
  const words = String(text || "");
  for (const match of words.matchAll(URL_IN)) {
    let raw = match[0];
    for (;;) {
      const opened = (raw.match(/\(/g) || []).length;
      const closed = (raw.match(/\)/g) || []).length;
      if (/[.,;:!?\]}]$/.test(raw) || (raw.endsWith(")") && closed > opened)) raw = raw.slice(0, -1);
      else break;
    }
    const link = linkOf(raw, hosts);
    if (!link) continue;
    if (match.index > from) pieces.push({ text: words.slice(from, match.index) });
    pieces.push({ link, at: raw });
    from = match.index + raw.length;
  }
  if (from < words.length) pieces.push({ text: words.slice(from) });
  return pieces;
}

/// What a post links that is drawn as a card under it, each once, six at
/// most: models, steps, sets, challenges and parts.
export function embedsIn(text, hosts = SITE_HOSTS) {
  const seen = new Set();
  const out = [];
  for (const piece of piecesOf(text, hosts)) {
    const link = piece.link;
    if (!link || !["model", "step", "set", "challenge", "part"].includes(link.kind)) continue;
    const key = JSON.stringify([link.kind, link.model, link.step, link.set, link.challenge, link.part, link.version]);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(link);
    if (out.length === 6) break;
  }
  return out;
}

/// A post's words as HTML: escaped, its lines kept (the page's pre-wrap),
/// each @handle it named ([mentions]) a link to them, each link of this
/// site a link, any other link the words it is. Pure.
export function bodyHtml(text, mentions = [], hosts = SITE_HOSTS) {
  let out = "";
  for (const piece of piecesOf(text, hosts)) {
    if (piece.link && piece.link.href) {
      out += `<a href="${escapeHtml(piece.link.href)}">${escapeHtml(piece.at)}</a>`;
      continue;
    }
    if (piece.link) {
      out += escapeHtml(piece.at);
      continue;
    }
    for (const bit of mentionPieces(piece.text, mentions)) {
      out += typeof bit === "string" ? escapeHtml(bit)
        : `<a class="mention" href="${langAt()}/u/${encodeURIComponent(bit.handle)}" title="${escapeHtml(bit.name)}">${escapeHtml(bit.at)}</a>`;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Pure: words and pieces of a page.

/// A board's name and what it is for, in the page's language.
export function boardSaid(board) {
  if (board === "show") return { name: say("Show and tell"), about: say("Models you built, photos of real builds and work in progress.") };
  if (board === "help") return { name: say("Help"), about: say("How to build something, the studio, parts and colours.") };
  if (board === "ideas") return { name: say("Ideas"), about: say("Ideas for models, and for Brickworks itself.") };
  if (board === "challenges") return { name: say("Challenges"), about: say("Each month’s challenge has its own thread: ask, show progress, cheer.") };
  if (board === "news") return { name: say("News"), about: say("What is new on Brickworks, from the team.") };
  return { name: say("Latest"), about: say("Every board, newest talk first.") };
}

/// When, as a forum says it: just now, minutes and hours ago, yesterday,
/// then the day. [now] in ms.
export function whenSaid(iso, now = Date.now()) {
  const at = Date.parse(iso || "");
  if (!Number.isFinite(at)) return "";
  const minutes = Math.floor((now - at) / 60000);
  if (minutes < 1) return say("just now");
  if (minutes < 60) return say("{n} min ago", { n: minutes });
  if (minutes < 24 * 60) return say("{n} h ago", { n: Math.floor(minutes / 60) });
  if (minutes < 48 * 60) return say("yesterday");
  const locale = globalThis.brickworksLang?.locale || "en-GB";
  const sameYear = new Date(at).getUTCFullYear() === new Date(now).getUTCFullYear();
  return new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", ...(sameYear ? {} : { year: "numeric" }),
    timeZone: "UTC" }).format(at);
}

const timeHtml = (iso, now) => {
  const at = Date.parse(iso || "");
  return Number.isFinite(at) ? `<time datetime="${new Date(at).toISOString()}">${escapeHtml(whenSaid(iso, now))}</time>` : "";
};

/// A person's name, a link to their page when they have one.
const whoHtml = (who) => (who && who.handle
  ? `<a href="${langAt()}/u/${encodeURIComponent(who.handle)}">${escapeHtml(who.name || who.handle)}</a>`
  : `<b>${escapeHtml(say("A builder"))}</b>`);

/// A model's small picture, as its card shows it.
const modelPicture = (model) => {
  if (!model || !MODEL.test(model.id || "")) return "";
  const version = Date.parse(model.updated_at || "") || 0;
  return model.has_thumb ? `/m/${model.id}.webp?v=${version.toString(36)}` : model.has_image ? `/m/${model.id}.png` : "";
};

/// One row of a list of threads: its title (a link), its board, pinned and
/// locked, its first words, who started it, its replies and its last word.
export function threadRowHtml(thread, { now = Date.now(), board = null } = {}) {
  const at = langAt();
  const pills = [
    thread.pinned ? `<span class="pill">${asText(say("Pinned"))}</span>` : "",
    thread.locked ? `<span class="pill">${asText(say("Locked"))}</span>` : "",
    board ? "" : `<a class="pill" href="${at}/talk/b/${thread.board}">${asText(boardSaid(thread.board).name)}</a>`,
    thread.unread ? `<span class="pill new">${asText(say("New"))}</span>` : "",
  ].filter(Boolean).join(" ");
  const picture = modelPicture(thread.model) || (thread.photo && PHOTO.test(thread.photo.id || "") ? `/talk/p/${thread.photo.id}.card.jpg` : "");
  const replies = Number(thread.replies) || 0;
  const last = thread.last_by && replies ? ` · ${sayHtml("last from {who}", { who: escapeHtml(thread.last_by.name || "") })}` : "";
  return `<li class="talk-row${thread.pinned ? " pinned" : ""}" data-thread="${Number(thread.id)}">`
    + `${picture ? `<img class="talk-row-picture" src="${escapeHtml(picture)}" alt="" loading="lazy" width="96" height="72">` : ""}`
    + `<div class="talk-row-main"><h3 class="talk-row-title"><a href="${at}${threadPath(thread)}">${escapeHtml(thread.title)}</a></h3>`
    + `${pills ? `<p class="pills">${pills}</p>` : ""}`
    + `${thread.said ? `<p class="talk-row-said">${escapeHtml(summary(thread.said, 160))}</p>` : ""}`
    + `<p class="talk-row-meta">${sayHtml("{who} started it", { who: whoHtml(thread.by) })} · ${timeHtml(thread.at, now)}`
    + ` · <span class="talk-replies">${escapeHtml(replies === 1 ? say("1 reply") : say("{n} replies", { n: number(replies) }))}</span>`
    + `${last}${replies ? ` ${timeHtml(thread.last_at, now)}` : ""}</p></div></li>`;
}

/// The cards under a post, for what it links ([embeds], embedsIn), each
/// as [found] has it: a model's or a step's with its picture and name, a
/// set's and a challenge's by their names, a part by its number.
export function embedsHtml(embeds, found = {}) {
  const at = langAt();
  const items = [];
  for (const one of embeds || []) {
    if (one.kind === "model" || one.kind === "step") {
      const model = found.models?.get(one.model);
      if (!model) continue;
      // A version's card shows that version's small picture (api/share.js
      // op=thumb with n, its big one where none was kept).
      const version = one.kind === "model" && one.version ? Number(one.version) : null;
      const picture = version ? `/m/${model.id}/v/${version}.webp` : modelPicture(model);
      const line = one.kind === "step" ? say("Step {n}: open it in the viewer", { n: number(one.step) })
        : version ? say("Version {n}: open it", { n: number(version) })
        : model.author ? say("by {name}", { name: model.author }) : say("A model in the gallery");
      const opens = one.kind === "step" ? one.href : version ? `${at}/m/${model.id}/v/${version}` : `${at}/m/${model.id}`;
      items.push(`<li class="talk-embed ${one.kind}${version ? " version" : ""}"><a href="${escapeHtml(opens)}">`
        + `${picture ? `<img src="${escapeHtml(picture)}" alt="" loading="lazy" width="120" height="90">` : ""}`
        + `<span><b>${escapeHtml(model.name || say("A model"))}</b><small>${escapeHtml(line)}</small></span></a></li>`);
    } else if (one.kind === "set") {
      items.push(`<li class="talk-embed set"><a href="${at}/library/set/${encodeURIComponent(one.set)}">`
        + `<span><b>${escapeHtml(say("Set {set}", { set: one.set }))}</b><small>${escapeHtml(say("Its page in the library"))}</small></span></a></li>`);
    } else if (one.kind === "challenge") {
      const challenge = found.challenges?.get(one.challenge);
      if (!challenge) continue;
      items.push(`<li class="talk-embed challenge"><a href="${escapeHtml(one.href)}">`
        + `<span><b>${escapeHtml(challenge.title)}</b><small>${escapeHtml(say("The month’s challenge"))}</small></span></a></li>`);
    } else if (one.kind === "part") {
      items.push(`<li class="talk-embed part"><span><b>${escapeHtml(say("Part {part}", { part: one.part }))}</b>`
        + `<small>${escapeHtml(say("Its number, as Rebrickable and BrickLink list it"))}</small></span></li>`);
    }
  }
  return items.length ? `<ul class="talk-embeds">${items.join("")}</ul>` : "";
}

/// One post: its writer's avatar and name (a link), Official on the
/// house's, Started it on the starter's replies, when, the post it answers,
/// its words, its photo, the cards of what it links, and what the reader
/// may do, drawn hidden until web/talk.js wires each.
export function postHtml(post, { posts = new Map(), found = {}, hosts = SITE_HOSTS, now = Date.now(), signedIn = false, locked = false } = {}) {
  const who = post.handle ? { handle: post.handle, name: post.by || post.handle } : null;
  const head = [whoHtml(who)];
  if (post.by_house) head.push(`<span class="pill designer">${asText(say("Official"))}</span>`);
  else if (post.by_starter && !post.first) head.push(`<span class="pill designer">${asText(say("Started the thread"))}</span>`);
  head.push(`<a class="talk-when" href="#post-${Number(post.id)}">${timeHtml(post.at, now)}</a>`
    + `${post.edited_at ? ` · ${asText(say("edited"))}` : ""}`);
  const answered = post.answers ? posts.get(Number(post.answers)) : null;
  const photo = post.photo && PHOTO.test(post.photo.id || "") ? post.photo : null;
  const name = post.by || say("A builder");
  const acts = [];
  if (!locked) acts.push(`<button type="button" class="link" data-act="reply" aria-label="${asText(say("Reply to {name}", { name }))}">${asText(say("Reply"))}</button>`);
  if (post.mine) {
    if (!locked) acts.push(`<button type="button" class="link" data-act="edit">${asText(say("Edit"))}</button>`);
    acts.push(`<button type="button" class="link" data-act="remove">${asText(say("Remove"))}</button>`);
  } else {
    acts.push(`<button type="button" class="link" data-act="report">${asText(say("Report"))}</button>`);
    if (signedIn && post.handle && !post.by_house) acts.push(`<button type="button" class="link" data-act="block">${asText(say("Block"))}</button>`);
  }
  const hidden = post.hidden ? `<p class="note">${asText(post.hidden_by === "reports"
    ? say("Hidden while the site’s owner looks at what was reported: only you see it.")
    : say("Hidden by the site’s owner: only you see it."))}</p>` : "";
  return `<li class="comment talk-post${post.by_starter ? " by-owner" : ""}${post.hidden ? " hidden-one" : ""}${post.pin ? " on-part" : ""}" id="post-${Number(post.id)}"`
    + ` data-post="${Number(post.id)}"${post.handle ? ` data-handle="${escapeHtml(post.handle)}"` : ""} data-name="${escapeHtml(name)}"${post.mine ? " data-mine" : ""}>`
    + avatarHtml({ handle: post.handle || "", name, picture: post.picture || "" })
    + `<div class="comment-main"><p class="comment-head">${head.join(" ")}</p>`
    + `${answered ? `<p class="talk-answers"><a href="#post-${Number(answered.id)}">${asText(say("Answering {name}", { name: answered.by || say("a builder") }))}</a></p>` : ""}`
    + pinLineHtml(post)
    + `<p class="comment-body">${bodyHtml(post.body, post.mentions || [], hosts)}</p>`
    + `${photo ? `<figure class="talk-photo"><a href="/talk/p/${photo.id}.jpg"><img src="/talk/p/${photo.id}.card.jpg" loading="lazy"`
      + `${photo.width && photo.height ? ` width="${Number(photo.width)}" height="${Number(photo.height)}"` : ""}`
      + ` alt="${asText(say("A photo {name} posted", { name }))}"></a></figure>` : ""}`
    + embedsHtml(post.embeds || [], found)
    + hidden
    + `<p class="comment-acts" data-acts hidden>${acts.join("")}</p></div></li>`;
}

/// The posts of a thread page ([page], talk_thread_page's), drawn.
export function postsHtml(page, { found = {}, hosts = SITE_HOSTS, now = Date.now(), signedIn = false } = {}) {
  const posts = new Map((page.posts || []).map((one) => [Number(one.id), one]));
  const locked = page.thread?.locked === true;
  return (page.posts || []).map((post) => postHtml(post, { posts, found, hosts, now, signedIn, locked })).join("");
}

/// The talk under the gallery's models (talk_talking's rows): each a line
/// to the comment on its model's page. With none, the newest models, each
/// a way to start some.
export function talkingHtml(rows, models = [], now = Date.now()) {
  const at = langAt();
  if (rows.length) {
    return `<ol class="talk-talking">${rows.map((one) => {
      const picture = modelPicture({ id: one.model, has_thumb: one.has_thumb, has_image: one.has_image, updated_at: one.updated_at });
      return `<li><a href="${at}/m/${encodeURIComponent(one.model)}#comment-${Number(one.comment)}">`
        + `${picture ? `<img src="${escapeHtml(picture)}" alt="" loading="lazy" width="64" height="48">` : ""}`
        + `<span><b>${escapeHtml(one.by?.name || say("A builder"))}</b> ${escapeHtml(say("on {name}", { name: one.name || say("a model") }))}`
        + `<q>${escapeHtml(summary(one.said, 120))}</q><small>${escapeHtml(whenSaid(one.at, now))}</small></span></a></li>`;
    }).join("")}</ol>`;
  }
  if (!models.length) return `<p class="note">${asText(say("What builders say under the gallery’s models shows here."))}</p>`;
  return `<p class="note">${asText(say("Nobody has said anything under a model yet. Open one and be the first:"))}</p>`
    + `<ol class="talk-talking">${models.map((one) => {
      const picture = modelPicture(one);
      return `<li><a href="${at}/m/${encodeURIComponent(one.id)}#comments">`
        + `${picture ? `<img src="${escapeHtml(picture)}" alt="" loading="lazy" width="64" height="48">` : ""}`
        + `<span><b>${escapeHtml(one.name)}</b><small>${escapeHtml(one.author ? say("by {name}", { name: one.author }) : say("A model in the gallery"))}</small></span></a></li>`;
    }).join("")}</ol>`;
}

/// The boards as tabs: Latest, then each board with its count.
export function boardsHtml(board, counts = {}, tests = false) {
  const at = langAt();
  const query = tests ? "?tests=1" : "";
  const tab = (id, href) => {
    const n = id ? Number(counts[id]) || 0 : 0;
    return `<a href="${href}${query}"${board === id ? ' aria-current="page"' : ""}>${asText(boardSaid(id).name)}`
      + `${n ? ` <span class="n">${escapeHtml(number(n))}</span>` : ""}</a>`;
  };
  return `<nav class="tabs talk-boards" aria-label="${asText(say("Boards"))}">${tab(null, `${at}/talk`)}`
    + `${BOARDS.map((id) => tab(id, `${at}/talk/b/${id}`)).join("")}</nav>`;
}

/// A thread's schema.org DiscussionForumPosting (Google's forum results):
/// its headline, first post, writer, date, replies as comments, and the
/// model it shows. Escaped for a <script> block.
export function threadSchema(page, origin, url) {
  const thread = page.thread || {};
  const posts = page.posts || [];
  const first = posts.find((one) => one.first) || null;
  const person = (one) => ({ "@type": PERSON, name: one.by || say("A builder"),
    ...(one.handle ? { url: `${origin}/u/${encodeURIComponent(one.handle)}` } : {}) });
  const replies = posts.filter((one) => !one.first);
  const data = {
    "@context": "https://schema.org",
    "@type": "DiscussionForumPosting",
    "@id": url,
    url,
    headline: thread.title,
    text: first ? first.body : thread.said || thread.title,
    datePublished: thread.at,
    ...(first?.edited_at ? { dateModified: first.edited_at } : {}),
    author: first ? person(first) : { "@type": PERSON, name: thread.by?.name || say("A builder") },
    isPartOf: { "@type": "CollectionPage", name: boardSaid(thread.board).name, url: `${origin}/talk/b/${thread.board}` },
    interactionStatistic: { "@type": "InteractionCounter", interactionType: "https://schema.org/CommentAction",
      userInteractionCount: replies.length },
    ...(first?.photo && PHOTO.test(first.photo.id || "") ? { image: `${origin}/talk/p/${first.photo.id}.jpg` } : {}),
    ...(thread.model?.id ? { sharedContent: { "@type": "WebPage", url: `${origin}/m/${thread.model.id}`, headline: thread.model.name } } : {}),
    comment: replies.slice(0, 100).map((one) => ({ "@type": COMMENT, url: `${url}#post-${Number(one.id)}`, text: one.body,
      datePublished: one.at, author: person(one) })),
  };
  return JSON.stringify(data).replace(/</g, "\\u003c");
}

const rssText = (text) => String(text ?? "").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "")
  .replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));

/// RSS 2.0 of [threads] (a board's, or every board's when [board] is
/// null): each thread's title, link, first words, writer, board and day.
export function rssOf(threads, { origin, board = null, lang = "en" }) {
  const said = boardSaid(board);
  const at = lang === "en" ? "" : `/${lang}`;
  const page = `${origin}${at}/talk${board ? `/b/${board}` : ""}`;
  const items = threads.map((one) => {
    const link = `${origin}${at}${threadPath(one)}`;
    return `<item><title>${rssText(one.title)}</title><link>${rssText(link)}</link><guid isPermaLink="true">${rssText(link)}</guid>`
      + `<pubDate>${new Date(Date.parse(one.at) || 0).toUTCString()}</pubDate>`
      + `<dc:creator>${rssText(one.by?.name || say("A builder"))}</dc:creator><category>${rssText(boardSaid(one.board).name)}</category>`
      + `<description>${rssText(summary(one.said || "", 400))}</description></item>`;
  });
  return `${RSS_HEAD}`
    + `<channel><title>${rssText(board ? say("Brickworks Talk: {board}", { board: said.name }) : say("Brickworks Talk"))}</title>`
    + `<link>${rssText(page)}</link><description>${rssText(said.about)}</description><language>${lang}</language>`
    + `<atom:link href="${rssText(`${origin}${at}/talk${board ? `/b/${board}` : ""}.rss`)}" rel="self" type="application/rss+xml"/>`
    + `${items.join("")}</channel></rss>\n`;
}

// ---------------------------------------------------------------------------
// The house's first threads: real ones, by Brickworks' own account, each
// written once (talk_seed), dated the moment Talk is first read with them.
// Never in a test's pool unless a test asks, never by anybody made up.

export const HOUSE_THREADS = [
  { seed: "welcome", board: "news", title: "Welcome to Talk",
    said: "Talk is where builders on Brickworks talk about anything, not only under one model.\n\n"
      + "Show and tell: a model you built, a photo of a real build, something half done.\n"
      + "Help: how to build something, how the studio works, which part does what.\n"
      + "Ideas: for models, and for Brickworks itself.\n"
      + "Challenges: each month's challenge has its own thread.\n"
      + "News: what is new on Brickworks, from us.\n\n"
      + "Paste a link to a model, a step of one, a set or the challenge and it shows as a card. "
      + "Write @ and somebody's handle to tell them. Be kind, keep it about building, and report anything that "
      + "should not be here: https://brickworks.diy/guidelines\n\n"
      + "Say hello below: what do you build, and what are you building now?" },
  { seed: "how-to-ask", board: "help", title: "How to ask for help (and get an answer fast)",
    said: "A few things make a question easy to answer:\n\n"
      + "1. Share the model and paste its link here. A link to the step you are stuck on is even better: open it "
      + "in the viewer at that step and copy the address.\n"
      + "2. Say what you want it to do, and what it does instead.\n"
      + "3. Add a photo if it is a real build.\n"
      + "4. Say whether you are in the app on a computer, a phone or the web.\n\n"
      + "When somebody answers, a reply saying what worked helps the next person with the same question." },
  { seed: "building-now", board: "show", title: "What are you building this week?",
    said: "One thread for whatever is on your table or your screen right now, finished or not. "
      + "Paste a link to the model, add a photo, say what is giving you trouble." },
  { seed: "ideas-for-brickworks", board: "ideas", title: "What should Brickworks do next?",
    said: "Tell us what you would like the studio or the site to do, and what gets in your way. "
      + "We read every post here, and the changelog says what came of them: https://brickworks.diy/changelog" },
  { seed: "news-lists", board: "news", title: "New on the website: Own, Want and your lists",
    said: "Every set in the library, every set's page and every model in the gallery now has one control: Own (a set) "
      + "or Save (a model), with Undo, and a chevron for I want it, how many you own, and lists of your own that hold "
      + "sets and models together. Your lists, in the account menu, orders them, moves things between them and makes "
      + "them public with a page to share. You can bring in sets from Rebrickable, BrickLink or Brickset too.\n\n"
      + "Everything else that changed is in the changelog: https://brickworks.diy/changelog" },
];

const seeded = new Map();

/// The house's threads and each open challenge's, in [tests]'s pool: at
/// most every ten minutes an instance. Production writes the real pool's
/// (a preview never dates them early); a test asks for its own.
async function houseWrites(tests) {
  if (!tests && process.env.VERCEL_ENV !== "production") return;
  const last = seeded.get(tests) || 0;
  if (Date.now() - last < 600000) return;
  seeded.set(tests, Date.now());
  try {
    await call("talk_ensure", { p_tests: tests }, () => 0);
    for (const one of HOUSE_THREADS) {
      await call("talk_seed", { p_seed: one.seed, p_board: one.board, p_title: one.title, p_said: one.said, p_test: tests }, () => null);
    }
  } catch (trouble) {
    seeded.delete(tests);
    console.error(`talk: house: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
}

// ---------------------------------------------------------------------------
// What the pages need from the database.

/// The models, steps' models and challenges [posts] link, looked up once
/// for the page: {models: Map id -> row, challenges: Map id -> row}.
async function foundFor(posts, hosts, tests) {
  const models = new Set();
  const challenges = new Set();
  for (const post of posts) {
    post.embeds = embedsIn(post.body, hosts);
    for (const one of post.embeds) {
      if (one.model) models.add(one.model);
      if (one.challenge) challenges.add(one.challenge);
    }
  }
  const found = { models: new Map(), challenges: new Map() };
  const ids = [...models].filter((id) => MODEL.test(id)).slice(0, 60);
  if (ids.length) {
    const rows = await db(`shared_models?id=in.(${ids.join(",")})&published=is.true&barred=is.false`
      + "&select=id,name,author,has_image,has_thumb,updated_at").catch(() => []);
    for (const row of rows) found.models.set(row.id, row);
  }
  const numbers = [...challenges].slice(0, 20);
  // Through challenges.sql's own list: its table is no client's to read,
  // the server's key included.
  if (numbers.length) {
    const rows = await call("challenge_list", { tests }, () => []).catch(() => []);
    for (const row of Array.isArray(rows) ? rows : []) {
      if (numbers.map(Number).includes(Number(row.id)) && (tests || !row.test)) found.challenges.set(Number(row.id), row);
    }
  }
  return found;
}

/// Whom each of [posts] named, put on each as [mentions].
async function withMentions(posts) {
  const asked = posts.filter((one) => String(one.body || "").includes("@")).map((one) => Number(one.id));
  if (!asked.length) return posts;
  const rows = await call("talk_mentions_of", { post_ids: asked }, () => []).catch(() => []);
  const named = new Map();
  for (const row of Array.isArray(rows) ? rows : []) {
    named.set(Number(row.post), [...(named.get(Number(row.post)) || []), { handle: row.handle, name: row.name }]);
  }
  for (const post of posts) if (named.has(Number(post.id))) post.mentions = named.get(Number(post.id));
  return posts;
}

/// The hosts whose links are this site's: brickworks.diy, and the address
/// the request came to (a preview, a local relay).
function hostsOf(origin) {
  const hosts = new Set(SITE_HOSTS);
  try {
    hosts.add(new URL(origin).hostname.toLowerCase());
  } catch {
    // brickworks.diy's alone.
  }
  return hosts;
}

/// The thread page's data for [viewer]: talk_thread_page's, its posts'
/// mentions, the faces and what they link; null when it is not there.
async function threadFor(id, tests, viewer, origin) {
  const page = await call("talk_thread_page", { p_thread: id, p_tests: tests, viewer }, () => ({ missing: true }));
  if (!page || page.missing) return page;
  // An ask's (talk_asks.sql): the step asked about, and each answer's part.
  await withAsks(page);
  await withMentions(page.posts || []);
  const faced = await withFaces(page);
  const hosts = hostsOf(origin);
  return { page: faced, hosts, found: await foundFor(faced.posts || [], hosts, tests) };
}

// ---------------------------------------------------------------------------
// The pages.

function talkCsp() {
  let signIn = "";
  try {
    signIn = new URL(process.env.SUPABASE_URL || "").origin;
  } catch {
    signIn = "";
  }
  // An ask's 3D view (api/_asks.js) reads each part's geometry from the
  // parts store, as a model page's does.
  let store = "";
  try {
    store = new URL(storeRoot()).origin;
  } catch {
    store = "";
  }
  const others = [...new Set([signIn, store].filter(Boolean))].map((one) => ` ${one}`).join("");
  // A search is a form sent here (form-action 'self'); the photo is sent to
  // storage, which the sign-in service's origin is.
  return "default-src 'none'; script-src 'self'; img-src 'self' blob:; style-src 'self' 'unsafe-inline'; "
    + `connect-src 'self'${others}; base-uri 'none'; form-action 'self'; frame-ancestors 'none'`;
}

function sendPage(response, status, body, tests) {
  response.setHeader("Content-Type", "text/html; charset=utf-8");
  response.setHeader("Content-Security-Policy", talkCsp());
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : SHARED_CACHE);
  return response.status(status).end(body);
}

/// A page of Talk in [lang]: the site's header and footer, its head, [main].
function talkShell(origin, { title, about, path, lang, words, robots = "", main, image = "", schema = "", rss = "" }) {
  const { header, footer, head } = siteChrome(lang);
  const copy = (code) => `${origin}${["en", "x-default"].includes(code) ? "" : `/${code}`}${path}`;
  const url = copy(lang);
  const alternates = ["en", ...SITE_LANGS, "x-default"].map((code) =>
    `<link rel="alternate" hreflang="${code}" href="${escapeHtml(copy(code))}">`).join("\n");
  const picture = image || `${origin}/share.png`;
  const scriptWords = words ? `<script type="application/json" id="site-words">${JSON.stringify(words).replace(/</g, "\\u003c")}</script>\n` : "";
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(about)}">
${robots ? `<meta name="robots" content="${robots}">\n` : ""}<link rel="canonical" href="${escapeHtml(url)}">
${alternates}
${rss ? `<link rel="alternate" type="application/rss+xml" title="${escapeHtml(rss.title)}" href="${escapeHtml(`${lang === "en" ? "" : `/${lang}`}${rss.href}`)}">\n` : ""}<meta property="og:type" content="website">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(about)}">
<meta property="og:url" content="${escapeHtml(url)}">
<meta property="og:image" content="${escapeHtml(picture)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(about)}">
<meta name="twitter:image" content="${escapeHtml(picture)}">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
${schema ? `<script type="application/ld+json">${schema}</script>\n` : ""}${scriptWords}${head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<link rel="stylesheet" href="/talk.css">
${main.includes("data-ask") ? '<link rel="stylesheet" href="/view3d.css">\n' : ""}<script src="/talk.js" type="module"></script>
</head>
<body>
<a class="skip" href="#main">${asText(say("Skip to content"))}</a>
${header}
<main id="main">
${main}
</main>
${footer}
</body>
</html>`;
}

/// /talk and /talk/b/<board>: the threads, the boards, a search, and the
/// talk on the models beside them.
export function listPageHtml({ board, q, before, listed, counts, talking, models, tests, now = Date.now() }) {
  const at = langAt();
  const said = boardSaid(board);
  const query = tests ? "&tests=1" : "";
  const threads = listed.threads || [];
  const older = listed.more && threads.length
    ? `<p class="talk-more"><a class="cta ghost" href="${at}/talk${board ? `/b/${board}` : ""}?before=${encodeURIComponent(threads[threads.length - 1].last_at)}`
      + `${q ? `&q=${encodeURIComponent(q)}` : ""}${query}">${asText(say("Older threads"))}</a></p>` : "";
  const empty = q ? `<p class="talk-empty">${sayHtml("Nothing in Talk says {words}. Try fewer words, or start a thread about it.", { words: `“${escapeHtml(q)}”` })}</p>`
    : before ? `<p class="talk-empty">${asText(say("No older threads."))}</p>`
    : `<p class="talk-empty">${asText(say("Nothing here yet. Start the first thread: people who follow this board will see it."))}</p>`;
  const start = `${at}/talk/new${board && board !== "news" ? `?board=${board}` : ""}`;
  return `<div class="wrap talk-page" data-talk="list"${board ? ` data-board="${board}"` : ""}>
<header class="talk-head">
<p class="talk-crumbs">${board ? `<a href="${at}/talk">${asText(say("Talk"))}</a> ›` : ""}</p>
<h1>${asText(board ? said.name : say("Talk"))}</h1>
<p class="lede">${asText(board ? said.about : say("Show what you built, ask for help, share ideas and talk about the month’s challenge with other builders."))}</p>
<div class="actions talk-tools">
<a class="cta" href="${start}" data-start>${asText(say("Start a thread"))}</a>
<form class="talk-search" role="search" action="${at}/talk" method="get">
<label class="visually-hidden" for="talk-q">${asText(say("Search Talk"))}</label>
<input id="talk-q" type="search" name="q" maxlength="200" value="${escapeHtml(q || "")}" placeholder="${asText(say("Search Talk"))}">
${tests ? '<input type="hidden" name="tests" value="1">' : ""}<button class="cta ghost" type="submit">${asText(say("Search"))}</button>
</form>
</div>
</header>
${boardsHtml(board, counts, tests)}
<div class="talk-layout">
<section class="talk-threads" aria-labelledby="talk-threads-title">
<h2 class="visually-hidden" id="talk-threads-title">${asText(q ? say("Threads that say it") : say("Threads"))}</h2>
${q ? `<p class="talk-searched">${sayHtml("Threads that say {words}", { words: `“${escapeHtml(q)}”` })} · <a href="${at}/talk${board ? `/b/${board}` : ""}${tests ? "?tests=1" : ""}">${asText(say("Clear the search"))}</a></p>` : ""}
${threads.length ? `<ol class="talk-list" id="talk-list">${threads.map((one) => threadRowHtml(one, { now, board })).join("")}</ol>` : empty}
${older}
</section>
<aside class="talk-aside">
<section aria-labelledby="talk-on-models">
<h2 id="talk-on-models">${asText(say("On the models"))}</h2>
${talkingHtml(talking, models, now)}
</section>
<section aria-labelledby="talk-boards-title">
<h2 id="talk-boards-title">${asText(say("The boards"))}</h2>
<dl class="talk-board-list">${BOARDS.map((id) => `<dt><a href="${at}/talk/b/${id}">${asText(boardSaid(id).name)}</a></dt><dd>${asText(boardSaid(id).about)}</dd>`).join("")}</dl>
<p class="note"><a href="${at}/guidelines">${asText(say("Community guidelines"))}</a> · <a href="/talk${board ? `/b/${board}` : ""}.rss">${asText(say("RSS feed"))}</a></p>
</section>
</aside>
</div>
</div>`;
}

/// /talk/t/<n>: the thread, its posts, and the box to reply.
/// An ask's thread's answers on parts, numbered in the thread's order, as
/// its 3D view numbers them (web/talk.js): [{id, n, pin, version}].
export function answersOnParts(page) {
  const version = page?.thread?.ask?.version || 1;
  return (page?.posts || []).filter((one) => one.pin).map((one, i) => ({ id: Number(one.id), n: i + 1, pin: one.pin, version,
    said: String(one.body || "").slice(0, 140), by: one.by || "" }));
}

/// What the thread's 3D view starts from, as JSON inside the page: its ask
/// and the answers on parts, "<" written so no word closes the script.
const askData = (page) => JSON.stringify({ ask: page.thread.ask, pins: answersOnParts(page) }).replace(/</g, "\\u003c");

export function threadPageHtml({ page, found, hosts, tests, now = Date.now() }) {
  const at = langAt();
  const thread = page.thread;
  const said = boardSaid(thread.board);
  const replies = (page.posts || []).filter((one) => !one.first).length;
  const pills = [
    thread.pinned ? `<span class="pill">${asText(say("Pinned"))}</span>` : "",
    thread.locked ? `<span class="pill">${asText(say("Locked"))}</span>` : "",
  ].filter(Boolean).join(" ");
  const model = thread.model?.id ? `<a class="talk-model" href="${at}/m/${encodeURIComponent(thread.model.id)}">`
    + `${modelPicture(thread.model) ? `<img src="${escapeHtml(modelPicture(thread.model))}" alt="" width="160" height="120">` : ""}`
    + `<span><small>${asText(say("The model"))}</small><b>${escapeHtml(thread.model.name || "")}</b></span></a>` : "";
  const challenge = thread.challenge?.id ? `<p class="talk-challenge"><a class="cta ghost" href="${at}/challenge?id=${Number(thread.challenge.id)}${thread.challenge.test ? "&tests=1" : ""}">`
    + `${asText(say("See the challenge, enter and vote"))}</a></p>` : "";
  return `<div class="wrap talk-page" data-talk="thread" data-thread="${Number(thread.id)}" data-board="${thread.board}"${thread.locked ? " data-locked" : ""}${tests ? " data-tests" : ""}>
<p class="talk-crumbs"><a href="${at}/talk${tests ? "?tests=1" : ""}">${asText(say("Talk"))}</a> › <a href="${at}/talk/b/${thread.board}${tests ? "?tests=1" : ""}">${asText(said.name)}</a></p>
<header class="talk-thread-head">
<h1>${escapeHtml(thread.title)}</h1>
<p class="talk-row-meta">${pills ? `${pills} ` : ""}${sayHtml("{who} started it", { who: whoHtml(thread.by) })} · ${timeHtml(thread.at, now)} · <span class="talk-replies">${escapeHtml(replies === 1 ? say("1 reply") : say("{n} replies", { n: number(replies) }))}</span></p>
${model}${challenge}
${askHtml(thread.ask)}${thread.ask?.model ? `<script type="application/json" id="talk-ask-data">${askData(page)}</script>` : ""}
<div class="actions"><button class="cta ghost small" type="button" data-follow aria-pressed="false" hidden>${asText(say("Follow"))}</button>
<span class="note talk-follow-said" data-follow-said hidden></span></div>
</header>
<ol class="comment-list talk-posts" id="talk-posts">${postsHtml(page, { found, hosts, now })}</ol>
<p class="note" data-blocked-some hidden>${asText(say("Some posts here are by people you blocked, so they are not shown."))}</p>
<section class="talk-reply" id="reply" aria-labelledby="talk-reply-title">
<h2 id="talk-reply-title">${asText(say("Reply"))}</h2>
${thread.locked ? `<p class="note">${asText(say("This thread is locked: it takes no new posts."))}</p>` : `<form class="comment-new talk-form" data-reply-form hidden>
<p class="talk-answering" data-answering hidden><span></span> <button type="button" class="cta ghost small" data-act="unanswer">${asText(say("Not an answer to them"))}</button></p>
${thread.ask?.model ? `<p class="talk-answering talk-on-part-chosen" data-on-part hidden><span></span> <button type="button" class="cta ghost small" data-act="off-part">${asText(say("Not on a part"))}</button></p>` : ""}
<label for="talk-reply-words">${asText(say("Your reply"))}</label>
<textarea id="talk-reply-words" name="body" rows="5" required data-most="4000"></textarea>
<p class="note">${asText(say("Plain text. A link to a model, a step, a set or a challenge on Brickworks shows as a card; @handle tells somebody."))}</p>
<p class="talk-photo-chosen" data-photo-chosen hidden></p>
<div class="actions"><button class="cta" type="submit">${asText(say("Post the reply"))}</button>
<label class="cta ghost talk-photo-pick">${asText(say("Add a photo"))}<input type="file" accept="image/jpeg,image/png,image/webp" data-photo hidden></label>
<span class="said" role="status" data-said></span></div>
</form>
<div class="talk-signin" data-signin><p>${asText(say("Sign in to reply: we email you a code, no password. Anyone can read Talk."))}</p>
<button class="cta" type="button" data-act="sign-in" hidden>${asText(say("Sign in to reply"))}</button></div>`}
</section>
</div>`;
}

/// /talk/new: the form to start a thread, [board] chosen and [model] (one
/// of the caller's, checked when it is sent) its Show and tell.
export function newPageHtml({ board, model }) {
  const at = langAt();
  const chosen = BOARDS.includes(board) && board !== "news" ? board : "";
  return `<div class="wrap talk-page talk-new" data-talk="new">
<p class="talk-crumbs"><a href="${at}/talk">${asText(say("Talk"))}</a> ›</p>
<h1>${asText(say("Start a thread"))}</h1>
<form class="talk-form talk-start" data-start-form hidden>
<fieldset class="talk-board-pick"><legend>${asText(say("Board"))}</legend>
${BOARDS.filter((id) => id !== "news").map((id) => `<label class="choice"><input type="radio" name="board" value="${id}" required${(model ? id === "show" : id === chosen) ? " checked" : ""}> <b>${asText(boardSaid(id).name)}</b> <small>${asText(boardSaid(id).about)}</small></label>`).join("\n")}
</fieldset>
${model ? `<p class="talk-about-model" data-model="${escapeHtml(model.id)}">${sayHtml("About your model {name}", { name: `<a href="${at}/m/${encodeURIComponent(model.id)}">${escapeHtml(model.name)}</a>` })}</p>` : ""}
<label for="talk-title">${asText(say("Title"))}</label>
<input id="talk-title" name="title" type="text" required data-most="120" value="${model ? escapeHtml(model.name) : ""}">
<label for="talk-words">${asText(say("What you want to say"))}</label>
<textarea id="talk-words" name="body" rows="8" required data-most="4000"></textarea>
<p class="note">${asText(say("Plain text. A link to a model, a step, a set or a challenge on Brickworks shows as a card; @handle tells somebody."))}</p>
<p class="talk-photo-chosen" data-photo-chosen hidden></p>
<div class="actions"><button class="cta" type="submit">${asText(say("Start the thread"))}</button>
<label class="cta ghost talk-photo-pick">${asText(say("Add a photo"))}<input type="file" accept="image/jpeg,image/png,image/webp" data-photo hidden></label>
<a class="cta ghost" href="${at}/talk">${asText(say("Cancel"))}</a>
<span class="said" role="status" data-said></span></div>
</form>
<div class="talk-signin" data-signin><p>${asText(say("Sign in to start a thread: we email you a code, no password. Anyone can read Talk."))}</p>
<button class="cta" type="button" data-act="sign-in" hidden>${asText(say("Sign in to start a thread"))}</button></div>
<section class="talk-how" aria-labelledby="talk-how-title">
<h2 id="talk-how-title">${asText(say("Before you post"))}</h2>
<ul>
<li>${asText(say("Search first: somebody may have asked it already."))}</li>
<li>${asText(say("Say what you built or what you are stuck on, and paste the model’s link."))}</li>
<li>${asText(say("Be kind and keep it about building. Links to other sites show as words, never as links."))}</li>
<li>${sayHtml("The {guidelines} apply here as everywhere on Brickworks.", { guidelines: `<a href="${at}/guidelines">${asText(say("community guidelines"))}</a>` })}</li>
</ul>
</section>
</div>`;
}

function missingHtml(lang) {
  const at = lang === "en" ? "" : `/${lang}`;
  return `<div class="wrap gone talk-page"><h1>${asText(say("That thread is not here"))}</h1>
<p class="lede">${asText(say("The address may be mistyped, or the thread was removed."))}</p>
<div class="actions"><a class="cta" href="${at}/talk">${asText(say("See what people are talking about"))}</a></div></div>`;
}

/// GET ?op=talk_page: /talk, /talk/b/<board>, /talk/t/<n> and /talk/new,
/// in the language asked (/de/talk ...).
export async function talkPage(request, response, { origin }) {
  const query = request.query || {};
  const tests = testsAsked(query);
  const lang = langOf(query);
  const words = lang === "en" ? null : siteWords(lang);
  const at = lang === "en" ? "" : `/${lang}`;
  const now = Date.now();
  const draw = (fn) => inLanguage(lang, words, fn);
  if (query.new !== undefined) {
    const id = String(query.model || "");
    const model = MODEL.test(id) ? (await db(`shared_models?id=eq.${id}&published=is.true&barred=is.false&select=id,name`).catch(() => []))[0] || null : null;
    const board = String(query.board || "");
    return sendPage(response, 200, draw(() => talkShell(origin, { title: say("Start a thread · Brickworks Talk"),
      about: say("Start a thread in Talk, the forum of Brickworks’ builders."), path: "/talk/new", lang, words, robots: "noindex",
      main: newPageHtml({ board, model }) })), tests);
  }
  const thread = whole(query.thread);
  if (query.thread !== undefined) {
    const got = thread ? await threadFor(thread, tests, null, origin) : null;
    if (got && got.missing) return sendPage(response, 503, draw(() => talkShell(origin, { title: say("Talk · Brickworks"), about: NOT_YET,
      path: "/talk", lang, words, robots: "noindex", main: `<div class="wrap gone"><h1>${asText(say(NOT_YET))}</h1></div>` })), tests);
    if (!got) {
      return sendPage(response, 404, draw(() => talkShell(origin, { title: say("That thread is not here · Brickworks Talk"),
        about: say("A thread in Talk, the forum of Brickworks’ builders."), path: "/talk", lang, words, robots: "noindex",
        main: missingHtml(lang) })), tests);
    }
    const { page, found, hosts } = got;
    const path = threadPath(page.thread);
    const first = (page.posts || []).find((one) => one.first);
    const image = first?.photo && PHOTO.test(first.photo.id || "") ? `${origin}/talk/p/${first.photo.id}.jpg`
      : page.thread.model?.id ? `${origin}${modelPicture(page.thread.model) || "/share.png"}` : "";
    return sendPage(response, 200, draw(() => talkShell(origin, {
      title: say("{title} · Brickworks Talk", { title: page.thread.title }),
      about: summary(first?.body || page.thread.title, 200), path, lang, words, image,
      robots: tests || page.thread.hidden ? "noindex" : "",
      schema: threadSchema(page, origin, `${origin}${at}${path}`),
      rss: { title: say("Brickworks Talk: {board}", { board: boardSaid(page.thread.board).name }), href: `/talk/b/${page.thread.board}.rss` },
      main: threadPageHtml({ page, found, hosts, tests, now }) })), tests);
  }
  const board = query.board === undefined || query.board === "" ? null : String(query.board);
  if (board !== null && !BOARDS.includes(board)) {
    return sendPage(response, 404, draw(() => talkShell(origin, { title: say("Talk · Brickworks"), about: say("Talk, the forum of Brickworks’ builders."),
      path: "/talk", lang, words, robots: "noindex", main: missingHtml(lang) })), tests);
  }
  const q = String(query.q || "").replace(/\s+/g, " ").trim().slice(0, 200);
  const before = Date.parse(String(query.before || "")) ? new Date(Date.parse(String(query.before))).toISOString() : null;
  await houseWrites(tests);
  const [listed, counts, talking, models] = await Promise.all([
    call("talk_threads_of", { p_board: board, p_tests: tests, viewer: null, p_before: before, p_limit: PER_PAGE, p_q: q || null },
      () => ({ missing: true })),
    call("talk_board_counts", { p_tests: tests }, () => ({})).catch(() => ({})),
    call("talk_talking", { p_tests: tests, viewer: null, p_limit: 8 }, () => []).catch(() => []),
    db(`shared_models?listed=is.true&published=is.true&barred=is.false&test=is.${tests}&order=listed_at.desc&limit=4`
      + "&select=id,name,author,has_image,has_thumb,updated_at").catch(() => []),
  ]);
  if (listed && listed.missing) {
    return sendPage(response, 503, draw(() => talkShell(origin, { title: say("Talk · Brickworks"), about: NOT_YET, path: "/talk", lang, words,
      robots: "noindex", main: `<div class="wrap gone"><h1>${asText(say(NOT_YET))}</h1></div>` })), tests);
  }
  const faced = await withFaces({ listed, talking });
  const said = boardSaid(board);
  const path = board ? `/talk/b/${board}` : "/talk";
  return sendPage(response, 200, draw(() => talkShell(origin, {
    title: board ? say("{board} · Brickworks Talk", { board: said.name }) : say("Talk · the Brickworks builders’ forum"),
    about: board ? said.about : say("Show what you built, ask for help, share ideas and talk about the month’s challenge with other builders."),
    path, lang, words, robots: tests || q || before ? "noindex" : "",
    rss: { title: board ? say("Brickworks Talk: {board}", { board: said.name }) : say("Brickworks Talk"), href: `${path}.rss` },
    main: listPageHtml({ board, q, before, listed: faced.listed, counts, talking: Array.isArray(faced.talking) ? faced.talking : [],
      models: Array.isArray(models) ? models : [], tests, now }) })), tests);
}

// ---------------------------------------------------------------------------
// The answers in JSON.

/// GET ?op=talk: the threads as JSON, as the caller sees them.
export async function talkList(request, response) {
  const query = request.query || {};
  const tests = testsAsked(query);
  const viewer = await reader(request);
  response.setHeader("Cache-Control", viewer || tests ? "private, no-store" : SHARED_CACHE);
  const board = query.board === undefined || query.board === "" ? null : String(query.board);
  if (board !== null && !BOARDS.includes(board)) throw new Unacceptable(`board is one of ${BOARDS.join(", ")}`);
  const q = String(query.q || "").replace(/\s+/g, " ").trim().slice(0, 200);
  const before = Date.parse(String(query.before || "")) ? new Date(Date.parse(String(query.before))).toISOString() : null;
  await houseWrites(tests);
  const listed = await call("talk_threads_of", { p_board: board, p_tests: tests, viewer, p_before: before, p_limit: PER_PAGE,
    p_q: q || null }, notYet);
  return response.status(200).json(await withFaces({ board, q, threads: listed.threads || [], more: listed.more === true }));
}

/// GET ?op=talk_thread&id=N: the thread as the caller sees it; with html=1
/// its posts drawn in the language asked, for web/talk.js.
export async function talkThread(request, response, { origin }) {
  const query = request.query || {};
  const tests = testsAsked(query);
  const viewer = await reader(request);
  response.setHeader("Cache-Control", "private, no-store");
  const id = whole(query.id);
  if (!id) throw new Unacceptable("name a thread: ?id=<number>");
  const got = await threadFor(id, tests, viewer, origin);
  if (got && got.missing) notYet();
  if (!got) throw refused("no_thread");
  const { page, found, hosts } = got;
  const you = { signed_in: Boolean(viewer), ...(page.you || {}) };
  const trouble = you.trouble && you.trouble !== "sign_in" ? WORDS[you.trouble]?.[1] || "" : "";
  const standing = you.standing ? WORDS[you.standing]?.[1] || "" : "";
  you.may_write = Boolean(viewer) && !you.trouble && !you.standing && you.pool !== false && !page.thread.locked;
  you.why_not = trouble || standing || (you.pool === false ? WORDS.no_thread[1] : "");
  if (String(query.html || "") === "1") {
    const lang = langOf(query);
    const html = inLanguage(lang, lang === "en" ? null : siteWords(lang), () => postsHtml(page, { found, hosts, signedIn: Boolean(viewer) }));
    // The words of the caller's own posts as they typed them, for Edit.
    const mine = (page.posts || []).filter((one) => one.mine).map((one) => ({ id: one.id, body: one.body }));
    return response.status(200).json({ thread: page.thread, html, count: (page.posts || []).length, blocked_some: page.blocked_some === true,
      you, mine, pins: answersOnParts(page) });
  }
  return response.status(200).json({ thread: page.thread, posts: page.posts || [], blocked_some: page.blocked_some === true, you });
}

/// The newest post of [thread] that is not its first, as the home's feed
/// shows a thread's latest reply (homefeed, 2026-11-23): {by, said, at},
/// its words cut to 200 characters; null for none, or when it cannot be
/// read. As the thread's page shows it to somebody signed out.
async function lastReply(thread, tests) {
  if (!(Number(thread.replies) > 0)) return null;
  const page = await call("talk_thread_page", { p_thread: Number(thread.id), p_tests: tests, viewer: null }, () => null)
    .catch(() => null);
  const posts = Array.isArray(page?.posts) ? page.posts.filter((one) => one && !one.first && !one.hidden && one.body) : [];
  const last = posts[posts.length - 1];
  if (!last) return null;
  return { by: last.handle ? { handle: String(last.handle), name: String(last.by || last.handle) } : null,
    said: summary(String(last.body), 200), at: last.at };
}

/// GET ?op=talk_latest&n=4: the newest threads of every board; &html=1
/// drawn in the language asked. With &reply=1 (the home's feed, homefeed,
/// 2026-11-23) each thread also carries its address (path) and its latest
/// reply (reply, lastReply's); with &talking=N as well the newest N comments
/// on the gallery's models (talking, talk_talking's), which the feed's cards
/// show under their models. Signed out, kept by the CDN.
export async function talkLatest(request, response) {
  const query = request.query || {};
  const tests = testsAsked(query);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : SHARED_CACHE);
  const n = Math.min(8, Math.max(1, whole(query.n) || 4));
  await houseWrites(tests);
  const listed = await call("talk_threads_of", { p_board: null, p_tests: tests, viewer: null, p_before: null, p_limit: n, p_q: null },
    () => ({ threads: [], missing: true }));
  if (String(query.reply || "") === "1" && String(query.html || "") !== "1") {
    const asked = Math.min(24, whole(query.talking) || 0);
    const [replies, talking] = await Promise.all([
      Promise.all((listed.threads || []).map((one) => lastReply(one, tests))),
      asked ? call("talk_talking", { p_tests: tests, viewer: null, p_limit: asked }, () => []).catch(() => []) : []]);
    const faced = await withFaces({ threads: (listed.threads || []).map((one, i) => ({ ...one, path: threadPath(one), reply: replies[i] })),
      talking: Array.isArray(talking) ? talking : [] });
    return response.status(200).json({ ready: !listed.missing, threads: faced.threads, talking: faced.talking });
  }
  const threads = (await withFaces({ threads: listed.threads || [] })).threads;
  if (String(query.html || "") === "1") {
    const lang = langOf(query);
    const now = Date.now();
    const html = inLanguage(lang, lang === "en" ? null : siteWords(lang), () => (threads.length
      ? `<ol class="talk-list talk-strip-list">${threads.map((one) => threadRowHtml(one, { now })).join("")}</ol>` : ""));
    return response.status(200).json({ ready: !listed.missing, count: threads.length, html });
  }
  return response.status(200).json({ ready: !listed.missing, threads });
}

/// GET ?op=talk_rss[&board=B]: RSS 2.0 of the newest threads.
export async function talkRss(request, response, { origin }) {
  const query = request.query || {};
  const tests = testsAsked(query);
  const board = query.board === undefined || query.board === "" ? null : String(query.board);
  if (board !== null && !BOARDS.includes(board)) throw new Unacceptable(`board is one of ${BOARDS.join(", ")}`);
  const lang = langOf(query);
  await houseWrites(tests);
  const listed = await call("talk_threads_of", { p_board: board, p_tests: tests, viewer: null, p_before: null, p_limit: 30, p_q: null }, notYet);
  // Newest first by when each began: a feed's item is its thread.
  const threads = [...(listed.threads || [])].sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
  response.setHeader("Content-Type", "application/rss+xml; charset=utf-8");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : "public, max-age=0, s-maxage=300, stale-while-revalidate=300");
  return response.status(200).end(inLanguage(lang, lang === "en" ? null : siteWords(lang), () => rssOf(threads, { origin, board, lang })));
}

/// GET ?op=talk_model&id=X: model X's Show and tell thread, or null.
export async function talkModel(request, response) {
  const query = request.query || {};
  const tests = testsAsked(query);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : SHARED_CACHE);
  const id = String(query.id || "");
  if (!MODEL.test(id)) throw new Unacceptable("name a model: ?id=<ten characters>");
  const thread = await call("talk_model_thread", { p_model: id, p_tests: tests }, () => null);
  return response.status(200).json({ model: id, thread: thread && thread.id ? { ...thread, path: threadPath(thread) } : null });
}

// ---------------------------------------------------------------------------
// Writing.

/// Whom [text] (post [id] by [who]) names, told: [{handle, name}].
async function mention(who, id, text) {
  const named = mentionsIn(text).slice(0, 12);
  const barred = named.length ? await unnameable(who, named) : new Set();
  const handles = named.filter((handle) => !barred.has(handle));
  if (!handles.length) return [];
  try {
    const said = await call("talk_mention", { account: who, p_post: id, handles }, () => null);
    return Array.isArray(said?.mentioned) ? said.mentioned.map((one) => ({ handle: String(one.handle), name: String(one.name) })) : [];
  } catch (problem) {
    console.error(`talk: mentions: ${String(problem?.message || problem).slice(0, 160)}`);
    return [];
  }
}

const photoName = (id) => `talk-${id}.jpg`;
const photoCard = (id) => `talk-${id}.card.jpg`;

function newPhotoId() {
  const bytes = new Uint8Array(12);
  globalThis.crypto.getRandomValues(bytes);
  return [...bytes].map((byte) => ALPHABET[byte % ALPHABET.length]).join("");
}

/// The photo [ticket] [who] sent (talk_photo_start), made safe and kept
/// beside the build photos as talk-<id>.jpg and its card's copy: {id,
/// width, height}. The original is deleted however it goes.
async function keepPhoto(who, ticket) {
  if (!TICKET.test(String(ticket || ""))) throw new Unacceptable("That is not a photo this server asked for.");
  const original = `${who}/${ticket}`;
  try {
    const sent = await getFile(UPLOADS, original);
    if (!sent) throw new Unacceptable("The photo did not arrive: send it again.", 404);
    const declared = { jpg: "image/jpeg", png: "image/png", webp: "image/webp" }[ticket.split(".").pop()];
    let made;
    try {
      made = await cleanPhoto(sent, declared);
    } catch (trouble) {
      if (trouble instanceof PhotoTrouble) throw new Unacceptable(trouble.message, trouble.status);
      throw trouble;
    }
    const id = newPhotoId();
    await putFile(PHOTOS, photoName(id), made.bytes, "image/jpeg");
    await putFile(PHOTOS, photoCard(id), made.card.bytes, "image/jpeg").catch((trouble) =>
      console.error(`talk: the card copy of ${id} was not kept: ${String(trouble?.message || trouble).slice(0, 120)}`));
    return { id, width: made.width, height: made.height };
  } finally {
    await deleteFiles(UPLOADS, [original]).catch((trouble) =>
      console.error(`talk: the original was not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`));
  }
}

/// The files of [ids], Talk's photos: deleted, as a post that goes takes
/// its photo with it. Never fails what called it.
export async function dropPhotos(ids) {
  const names = (ids || []).filter((id) => PHOTO.test(String(id || ""))).flatMap((id) => [photoName(id), photoCard(id)]);
  if (!names.length) return;
  await deleteFiles(PHOTOS, names).catch((trouble) =>
    console.error(`talk: photos not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`));
}

/// Why [who] may not write now, refused in words, or nothing.
async function mayWrite(who) {
  const trouble = await call("talk_trouble", { account: who }, notYet);
  if (trouble) throw refused(trouble);
}

/// POST ?op=talk_photo_start: where the phone sends a photo, at most 8 MB.
export async function talkPhotoStart(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = bodyOf(request);
  const type = String(body.type || "");
  const size = Number(body.size);
  if (!TYPES[type]) throw new Unacceptable("A photo is a JPEG, a PNG or a WebP.", 415);
  if (!Number.isInteger(size) || size < 1) throw new Unacceptable("say how big the photo is, in bytes");
  if (size > MAX_PHOTO_BYTES) throw new Unacceptable("That photo is too big: at most 8 MB, please.", 413);
  await mayWrite(who);
  const allowed = await db("rpc/may_act", { method: "POST", body: { actor: who, act: "talk_photo", per_hour: 12, per_day: 40 } });
  if (allowed !== true) throw refused("limit");
  const ticket = `${[...globalThis.crypto.getRandomValues(new Uint8Array(16))].map((b) => b.toString(16).padStart(2, "0")).join("")}`
    + `.${{ "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" }[type]}`;
  const upload = await signUpload(`${who}/${ticket}`);
  return response.status(200).json({ upload, ticket, type, most: MAX_PHOTO_BYTES, key: process.env.SUPABASE_PUBLISHABLE_KEY || "" });
}

/// What a write answers with: the post drawn, in the language asked.
function drawn(request, post, thread, found, hosts) {
  const lang = langOf(request.query);
  return inLanguage(lang, lang === "en" ? null : siteWords(lang),
    () => postHtml(post, { found, hosts, signedIn: true, locked: thread?.locked === true }));
}

/// POST ?op=talk_start: a thread and its first post.
export async function talkStart(request, response, { origin }) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = bodyOf(request);
  const board = String(body.board || "");
  if (!BOARDS.includes(board)) throw refused("board");
  const title = cleanTitle(body.title);
  if (title.trouble) throw new Unacceptable(title.trouble);
  const words = cleanPost(body.body);
  if (words.trouble) throw new Unacceptable(words.trouble);
  const model = body.model === undefined || body.model === null || body.model === "" ? null : String(body.model);
  if (model !== null && !MODEL.test(model)) throw new Unacceptable("model is a shared model's ten characters");
  await mayWrite(who);
  const photo = body.photo ? await keepPhoto(who, String(body.photo)) : null;
  const made = await call("talk_start", { account: who, p_board: board, p_title: title.text, p_said: words.text, p_model: model,
    p_photo: photo }, notYet).catch(async (trouble) => {
    if (photo) await dropPhotos([photo.id]);
    throw trouble;
  });
  if (made?.refused) {
    if (photo) await dropPhotos([photo.id]);
    if (made.refused === "model_has" && made.thread) {
      return response.status(409).json({ error: WORDS.model_has[1], thread: made.thread, path: `/talk/t/${Number(made.thread)}` });
    }
    throw refused(made.refused);
  }
  const post = made.post;
  const mentions = await mention(who, post.id, words.text);
  if (mentions.length) post.mentions = mentions;
  const hosts = hostsOf(origin);
  const found = await foundFor([post], hosts, made.thread?.test === true);
  return response.status(201).json({ thread: made.thread, post, path: threadPath(made.thread),
    html: drawn(request, await withFaces(post), made.thread, found, hosts) });
}

/// POST ?op=talk_reply: a post in a thread, answering one of its posts or not.
export async function talkReply(request, response, { origin }) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = bodyOf(request);
  const thread = whole(body.thread);
  if (!thread) throw new Unacceptable("name the thread: thread, a number");
  const answers = body.answers === undefined || body.answers === null || body.answers === "" ? null : whole(body.answers);
  if (body.answers && !answers) throw new Unacceptable("answers is a post's number");
  const words = cleanPost(body.body);
  if (words.trouble) throw new Unacceptable(words.trouble);
  await mayWrite(who);
  // On a part of an ask's model (talk_asks.sql): found in the asked
  // version's file, as a pin's part is, before anything is kept.
  let pin = null;
  if (body.part !== undefined && body.part !== null) {
    if (!(await asksReady())) throw new Unacceptable(ASKS_NOT_YET, 503);
    const ask = await askOf(thread);
    if (!ask?.model) throw askRefused("not_ask");
    [pin] = await placesAsked(ask.model, ask.version, [body.part]);
  }
  const photo = body.photo ? await keepPhoto(who, String(body.photo)) : null;
  const made = await call(pin ? "talk_pin_reply" : "talk_reply", { account: who, p_thread: thread, p_said: words.text,
    p_answers: answers, p_photo: photo, ...(pin ? { p_pin: pin } : {}) },
    notYet).catch(async (trouble) => {
    if (photo) await dropPhotos([photo.id]);
    throw trouble;
  });
  if (made?.refused) {
    if (photo) await dropPhotos([photo.id]);
    throw made.refused in WORDS ? refused(made.refused) : askRefused(made.refused);
  }
  const post = made.post;
  const mentions = await mention(who, post.id, words.text);
  if (mentions.length) post.mentions = mentions;
  const hosts = hostsOf(origin);
  const found = await foundFor([post], hosts, true);
  return response.status(201).json({ post, mentions, html: drawn(request, await withFaces(post), null, found, hosts) });
}

/// POST ?op=talk_ask: a Help thread about the step open in the studio, of
/// one of the caller's shared models (api/_asks.js).
export async function talkAsk(request, response, { origin }) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = bodyOf(request);
  const model = String(body.model || "");
  if (!MODEL.test(model)) throw new Unacceptable("name the model: model, its link's ten characters");
  const step = body.step === undefined || body.step === null || body.step === "" ? null : Number(body.step);
  if (step !== null && (!Number.isInteger(step) || step < 1 || step > 200000)) throw askRefused("step");
  const title = cleanTitle(body.title);
  if (title.trouble) throw new Unacceptable(title.trouble);
  const words = cleanPost(body.body);
  if (words.trouble) throw new Unacceptable(words.trouble);
  if (!(await asksReady())) throw new Unacceptable(ASKS_NOT_YET, 503);
  await mayWrite(who);
  const [own] = await db(`shared_models?id=eq.${model}&select=id,owner,published,barred`);
  if (!own || own.owner !== who || own.published === false || own.barred === true) throw askRefused("model");
  const versions = await db(`share_versions?model=eq.${model}&select=n&order=n.desc&limit=1`);
  const newest = Number(versions?.[0]?.n) || 1;
  const version = body.version === undefined || body.version === null ? newest : Number(body.version);
  if (!Number.isInteger(version) || version < 1 || version > newest) throw askRefused("no_version");
  const parts = await placesAsked(model, version, body.parts);
  const photo = body.photo ? await keepPhoto(who, String(body.photo)) : null;
  const made = await call("talk_ask", { account: who, p_model: model, p_version: version, p_step: step,
    p_parts: parts.length ? parts : null, p_title: title.text, p_said: words.text, p_photo: photo }, notYet)
    .catch(async (trouble) => {
      if (photo) await dropPhotos([photo.id]);
      throw trouble;
    });
  if (made?.refused) {
    if (photo) await dropPhotos([photo.id]);
    throw made.refused in WORDS ? refused(made.refused) : askRefused(made.refused);
  }
  const post = made.post;
  const mentions = await mention(who, post.id, words.text);
  if (mentions.length) post.mentions = mentions;
  const path = threadPath(made.thread);
  return response.status(201).json({ thread: made.thread, post, ask: made.ask, path, url: `${origin}${path}`, every: ASK_EVERY_S });
}

/// GET ?op=talk_asks&model=X: the caller's model's asks and their answers
/// on parts, for the studio (api/_asks.js asksOn), asked every ASK_EVERY_S.
export async function talkAsks(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const who = await account(request);
  const model = String(request.query?.model || "");
  if (!MODEL.test(model)) throw new Unacceptable("name the model: ?model=<its link's ten characters>");
  if (!(await asksReady())) return response.status(200).json({ asks: [], open: false, every: ASK_EVERY_S });
  const asks = await asksOn(model, who);
  if (asks === null) throw askRefused("model");
  return response.status(200).json({ asks, open: true, every: ASK_EVERY_S });
}

/// POST ?op=talk_change: its author edits a post or removes it.
export async function talkChange(request, response, { origin }) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = bodyOf(request);
  const id = whole(body.post);
  if (!id) throw new Unacceptable("name the post: post, a number");
  const what = String(body.what || "");
  if (what !== "edit" && what !== "remove") throw new Unacceptable("what is edit or remove");
  let text = null;
  if (what === "edit") {
    const words = cleanPost(body.body);
    if (words.trouble) throw new Unacceptable(words.trouble);
    text = words.text;
  }
  const made = await call("talk_change", { account: who, p_post: id, p_what: what, p_said: text }, notYet);
  if (made?.refused) throw refused(made.refused);
  const post = made.post;
  if (made.removed && post?.photo?.id) await dropPhotos([post.photo.id]);
  if (what === "edit") {
    const mentions = await mention(who, post.id, text);
    if (mentions.length) post.mentions = mentions;
  }
  const hosts = hostsOf(origin);
  const found = what === "edit" ? await foundFor([post], hosts, true) : {};
  return response.status(200).json({ post, removed: made.removed === true, thread_removed: made.thread_removed === true,
    ...(what === "edit" ? { html: drawn(request, await withFaces(post), null, found, hosts) } : {}) });
}

/// POST ?op=talk_follow: follow a thread, or stop.
export async function talkFollow(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = bodyOf(request);
  const thread = whole(body.thread);
  if (!thread || typeof body.on !== "boolean") throw new Unacceptable("name the thread, and on: true or false");
  const said = await call("talk_follow", { account: who, p_thread: thread, p_on: body.on }, notYet);
  if (said?.refused) throw refused(said.refused);
  return response.status(200).json({ thread, following: said.following === true });
}

/// POST ?op=talk_read: the thread read up to now (its notifications too).
export async function talkRead(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const thread = whole(bodyOf(request).thread);
  if (!thread) throw new Unacceptable("name the thread: thread, a number");
  const said = await call("talk_read", { account: who, p_thread: thread }, () => ({ read: false }));
  return response.status(200).json({ thread, read: said?.read === true });
}

/// POST ?op=report {post, reason, note?}: a post reported, signed in or
/// not ([account] null: counted by a visitor's key). Three people's hide it.
export async function reportPost(request, response, { account: who, reasons }) {
  const body = bodyOf(request);
  const post = whole(body.post);
  if (!post) throw new Unacceptable("name the post: post, a number", 400);
  const reason = String(body.reason || "");
  if (!reasons.has(reason)) throw new Unacceptable(`a reason is one of ${[...reasons].join(", ")}`);
  const note = typeof body.note === "string" ? body.note.replace(/[\u0000-\u0008\u000b-\u001f\u007f]+/g, " ").trim().slice(0, 1000) : "";
  const visitor = who ? null : visitorKey(request, "report");
  const said = await call("talk_report", { account: who, p_visitor: visitor, p_post: post, p_reason: reason, p_note: note || null }, notYet);
  if (said?.refused) throw refused(said.refused);
  return response.status(200).json({ reported: true, hidden: said.hidden === true });
}

/// GET ?op=talk_photo&id=P: a post's photo, while the post may be seen.
export async function talkPhoto(request, response) {
  const id = String(request.query?.id || "");
  if (!PHOTO.test(id)) throw new Unacceptable("name a photo: ?id=<twelve characters>");
  const shown = await call("talk_photo_shown", { p_photo: id }, () => false);
  const bytes = shown ? await getFile(PHOTOS, String(request.query?.size || "") === "card" ? photoCard(id) : photoName(id))
    || await getFile(PHOTOS, photoName(id)) : null;
  if (!bytes) {
    response.setHeader("Cache-Control", "no-store");
    throw new Unacceptable("That photo is not here.", 404);
  }
  response.setHeader("Content-Type", "image/jpeg");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=60");
  return response.status(200).end(bytes);
}

/// Every Talk photo [account] posted, by name, for its deletion
/// (api/_erase.js): their file names in build-photos.
export async function photosOfAccount(accountId) {
  const ids = await call("talk_photos_of", { account: accountId }, () => []);
  return (Array.isArray(ids) ? ids : []).filter((id) => PHOTO.test(String(id || ""))).flatMap((id) => [photoName(id), photoCard(id)]);
}
