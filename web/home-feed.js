// The home's feed (homefeed, 2026-11-23; docs/SOCIAL.md section 11): what
// builders make and say, one stream of cards, each a way into the studio.
//
// Pure: it draws and orders, and touches no page, so the deploy writes the
// first cards into the page with it under node (tools/web/home_shelf.mjs)
// and web/landing.js draws the rest with it in the browser, the same cards
// both ways. Every word anybody typed goes in as text (card.js escapeHtml);
// a link is built from an id or a handle that is one, never from an
// address an answer gave.
//
// A card is one of:
//   build      a model shared to the gallery: who made it with Follow, its
//              picture (a 3D turn on hover or tap, web/landing.js), its name,
//              how it was made (each a link to that feature's docs page), its
//              like, comments and share, the studio's own verbs (Open in the
//              studio, Remix, Build it, Parts), and the newest two things
//              said of it, with a comment made in the card (web/composer.js)
//   talk       a thread of Talk: who started it, on which board, its first
//              words and its latest reply, with a reply made in the card
//   challenge  the month's challenge, its days left and its entries
//   try        the studio itself, a model on it, opened in the card on a tap
//   people     builders to follow
//   photo      a photo of a real build of a model
import {
  avatarHtml, counted, escapeHtml, iconButtonHtml, iconHtml, langAt, likeName, madeOf, motionWords, number, photoSrc, pictureOf, say,
} from "./card.js";

/// The cards the deploy writes into the page: a laptop's first two rows of
/// three, a phone's first three screens. The rest come from the answers.
export const FIRST = 6;
/// Of those, the pictures asked for at once: the first only (home_shelf.mjs
/// EAGER, landing 2026-11-22: with four, a laptop's first paint was 726 ms later).
export const EAGER = 1;

const MODEL = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const PHOTO = /^[A-Za-z0-9]{10}$/;
const BOARD = /^(?:show|help|ideas|challenges|news)$/;
const THREAD_PATH = /^\/talk\/t\/[1-9][0-9]{0,11}(?:\/[a-z0-9-]{1,80})?$/;

/// The boards' names, as Talk says them (api/_talk.js boardSaid).
const BOARDS = { show: "Show and tell", help: "Help", ideas: "Ideas", challenges: "Challenges", news: "News" };

/// How a model was made, and what it does, as the feed says it: each a
/// small pill to the docs page of the feature that made it so, so a card
/// says what the studio did as well as what the builder did.
export const MADE_DOCS = {
  assistant: ["Designed with the assistant", "/docs/ai"],
  brickify: ["Made with Brickify", "/docs/art-and-brickify"],
  hand: ["Built by hand", "/docs/placing-parts"],
  moves: ["/docs/joints-and-mechanisms"],
  steps: ["/docs/instructions"],
};

/// "22 Nov": a day as the page's language writes it, the same however late
/// the page is read (a time ago would be stale on a page kept by the CDN).
function dayOf(iso) {
  const at = Date.parse(String(iso || ""));
  if (!Number.isFinite(at)) return "";
  const code = globalThis.brickworksLang?.code;
  const locale = code && code !== "en" ? code : "en-GB";
  try {
    return new Intl.DateTimeFormat(locale, { day: "numeric", month: "short", timeZone: "UTC" }).format(at);
  } catch {
    return "";
  }
}

const timeHtml = (iso) => {
  const day = dayOf(iso);
  return day ? `<time datetime="${escapeHtml(String(iso))}">${escapeHtml(day)}</time>` : "";
};

/// A person as a card names them: {handle, name, picture} when the handle is one.
const personOf = (by) => (by && typeof by === "object" && HANDLE.test(String(by.handle || ""))
  ? { handle: String(by.handle), name: String(by.name || by.handle), picture: String(by.picture || "") } : null);

/// Their avatar and name, each a link to their profile, and a line about
/// what they did; Follow beside them where [follow].
function headHtml(by, line, { follow = false, author = "" } = {}) {
  const who = personOf(by);
  const at = langAt();
  const face = who ? `<a class="face" href="${at}/u/${escapeHtml(who.handle)}" tabindex="-1" aria-hidden="true">`
    + `${avatarHtml(who)}</a>` : `<span class="face">${avatarHtml({ name: author || "?" })}</span>`;
  const name = who ? `<a class="who" href="${at}/u/${escapeHtml(who.handle)}">${escapeHtml(who.name)}</a>`
    : `<span class="who">${escapeHtml(author || say("A builder"))}</span>`;
  const button = follow && who ? `<button type="button" class="cta ghost small follow" data-follow="${escapeHtml(who.handle)}" `
    + `data-follow-name="${escapeHtml(who.name)}" aria-pressed="false">${escapeHtml(say("Follow"))}</button>` : "";
  return `<header class="post-head">${face}<p class="post-who">${name}<span class="post-line">${line}</span></p>${button}</header>`;
}

/// The pills that say how [model] was made and what it does: two at most,
/// how it was made first.
export function madeHtml(model) {
  const pills = [];
  const made = madeOf(model);
  const [words, docs] = MADE_DOCS[made.by === "brickify" ? "brickify" : made.way] || MADE_DOCS.hand;
  pills.push(`<a class="pill" href="${docs}" data-made="${escapeHtml(made.by === "brickify" ? "brickify" : made.way)}">${escapeHtml(say(words))}</a>`);
  const motions = Array.isArray(model.motions) ? model.motions.filter((one) => typeof one === "string" && one) : [];
  const moves = Array.isArray(model.moves) ? model.moves.filter((one) => typeof one === "string" && one) : [];
  if (motions.length || moves.length) {
    pills.push(`<a class="pill" href="${MADE_DOCS.moves[0]}" data-made="moves">${escapeHtml(`${say("Moves:")} `
      + `${motions.length ? motionWords(motions, 2) : moves.slice(0, 2).map((word) => say(word)).join(", ")}`)}</a>`);
  } else if (Number(model.steps) > 1) {
    pills.push(`<a class="pill" href="${MADE_DOCS.steps[0]}" data-made="steps">${escapeHtml(counted(Number(model.steps), "step"))}</a>`);
  }
  return `<p class="post-made">${pills.join("")}</p>`;
}

/// One thing somebody said, as a card or a row shows it (web/composer.js
/// puts in what is posted there the same way): their face and name, a
/// link to them, and their words, one line in the card's room. [one]
/// {by, name, said, id}: [by] {handle, name, picture} when they have a
/// page, else [name]. [pending] posted here, not yet answered; [reply] a
/// reply under a comment.
export function saidLineHtml(one, { pending = false, reply = false } = {}) {
  const words = typeof one?.said === "string" ? one.said.trim() : "";
  if (!words) return "";
  const who = personOf(one.by);
  const name = who ? `<a class="who" href="${langAt()}/u/${escapeHtml(who.handle)}">${escapeHtml(who.name)}</a>`
    : `<b class="who">${escapeHtml(String(one.name || say("A builder")))}</b>`;
  const id = Number.isSafeInteger(Number(one.id)) && Number(one.id) > 0 ? ` data-line="${Number(one.id)}"` : "";
  return `<li class="said-line${pending ? " pending" : ""}${reply ? " reply" : ""}"${id}>${avatarHtml(who || { name: String(one.name || "?") }, { size: "small" })}`
    + `<p>${name} <span lang="">${escapeHtml(words)}</span>${pending ? ` <small class="said-wait">${escapeHtml(say("Posting…"))}</small>` : ""}</p></li>`;
}

/// What was said of a model ([said], talk_talking's, newest first): its
/// newest two, oldest of them first, its room held for two whatever comes,
/// "n more" of its [count] comments (opened in the card, web/composer.js),
/// and the way to say something there.
function saidHtml(id, said, count) {
  const lines = (Array.isArray(said) ? said : said ? [said] : []).filter((one) => personOf(one?.by) && typeof one.said === "string"
    && one.said.trim()).slice(0, 2).reverse();
  const rest = Math.max(0, (Number(count) || 0) - lines.length);
  const room = lines.length
    ? `<ol class="said-lines" aria-label="${escapeHtml(say("Comments"))}">${lines.map((one) => saidLineHtml({ ...one, id: one.comment })).join("")}</ol>`
    : `<ol class="said-lines" aria-label="${escapeHtml(say("Comments"))}" hidden></ol><p class="said-none">${escapeHtml(say("Nothing said yet. Say the first thing."))}</p>`;
  return `<div class="post-talk"><div class="said-room">${room}</div><p class="said-acts">`
    + `<button type="button" class="post-say" data-say="${escapeHtml(id)}" aria-expanded="false">${escapeHtml(say("Add a comment"))}</button>`
    + `<button type="button" class="said-more" data-more="${escapeHtml(id)}" aria-expanded="false"${rest ? "" : " hidden"}>`
    + `${escapeHtml(say("{n} more", { n: number(rest) }))}</button></p></div>`;
}

/// A model of the gallery as a post. [eager] its picture asked for at once;
/// [said] the newest comment on it; [line] what its builder did, said
/// (shared it, its week's pick, entered it); [pick] this week's pick.
export function buildPostHtml(model, { eager = false, said = null, line = "", pick = false } = {}) {
  const id = String(model.id);
  if (!MODEL.test(id)) return "";
  const name = String(model.name || say("A model"));
  const at = langAt();
  const picture = pictureOf(model);
  const page = `${at}/m/${id}`;
  const marks = [];
  if (pick) marks.push(`<span class="pill new">${escapeHtml(say("Week’s pick"))}</span>`);
  if (model.tested === true) marks.push(`<span class="pill good tested">✓ ${escapeHtml(say("Tested"))}</span>`);
  const what = line || say("shared a build");
  const when = timeHtml(model.listed_at);
  const image = picture
    ? `<img src="${escapeHtml(picture)}" alt="${escapeHtml(name)}" width="480" height="360" ${eager
      ? 'loading="eager" fetchpriority="high"' : 'loading="lazy"'} decoding="async">`
    : `<span class="none">${escapeHtml(say("No picture"))}</span>`;
  const by = personOf(model.by);
  const credit = by ? by.name : String(model.author || "");
  const acts = [
    iconButtonHtml({ icon: "like", name: likeName(name), count: model.likes, one: "like", pressed: model.liked === true, small: true,
      attrs: `data-like="${id}"` }),
    iconButtonHtml({ icon: "comment", name: say("Comments on {name}", { name }), count: model.comments, one: "comment", small: true,
      attrs: `data-say="${id}" aria-expanded="false"` }),
    iconButtonHtml({ icon: "share", name: say("Share {name}", { name }), small: true, attrs: `data-share="${id}" data-name="${escapeHtml(name)}"` }),
  ].join("");
  const parts = Number(model.parts) ? `<span class="post-size">${escapeHtml(counted(Number(model.parts), "part"))}</span>` : "";
  // The studio's own verbs: the model in the studio as it is; a copy of it
  // as yours to change, whose page will say whose it was (api/share.js
  // remixed_from); its steps one at a time with real bricks; its parts, to
  // list and to buy (the model's page's Parts: BrickLink, Rebrickable, Pick
  // a Brick).
  const verbs = `<p class="post-verbs">`
    + `<a class="cta small" href="/app?view=${id}" data-verb="open">${escapeHtml(say("Open in the studio"))}</a>`
    + `<a class="cta ghost small" href="/app?copy=${id}" data-verb="remix" title="${escapeHtml(credit
      ? say("A copy of it in the studio, yours to change; its page will say it came from {name}’s", { name: credit })
      : say("A copy of it in the studio, yours to change"))}">${escapeHtml(say("Remix"))}</a>`
    + `<a class="cta ghost small" href="/app?view=${id}&amp;build" data-verb="build" title="${escapeHtml(say("Build it with real bricks, one step at a time"))}">${escapeHtml(say("Build it"))}</a>`
    + `<a class="cta ghost small" href="${page}#parts" data-verb="parts" title="${escapeHtml(say("Its parts, to list and to buy"))}">${escapeHtml(say("Parts"))}</a></p>`;
  return `<article class="post build" data-kind="build" data-id="${id}"${pick ? ' data-pick="yes"' : ""} aria-labelledby="post-${id}">`
    + headHtml(model.by, `${escapeHtml(what)}${when ? ` · ${when}` : ""}`, { follow: true, author: String(model.author || "") })
    + `<div class="post-pic"><a class="pic" href="${page}" tabindex="-1" aria-hidden="true" data-scene="/m/${id}/scene.json">${image}</a>`
    + `${marks.length ? `<div class="marks">${marks.join("")}</div>` : ""}`
    + `<button type="button" class="icon-btn small turn" data-turn="${id}" aria-label="${escapeHtml(say("Turn {name} in 3D", { name }))}">`
    + `<span class="word" aria-hidden="true">3D</span></button></div>`
    + `<div class="post-words"><h3 class="post-title" id="post-${id}"><a href="${page}">${escapeHtml(name)}</a></h3>`
    + madeHtml(model)
    + `<div class="post-acts">${acts}${parts}</div>${verbs}${saidHtml(id, said, model.comments)}</div></article>`;
}

/// A thread of Talk as a post (talk_latest's, with &reply=1): who started
/// it and where, its title and first words, and its latest reply.
export function talkPostHtml(thread) {
  const n = Number(thread?.id);
  if (!Number.isSafeInteger(n) || n < 1 || !BOARD.test(String(thread.board || ""))) return "";
  const at = langAt();
  const path = THREAD_PATH.test(String(thread.path || "")) ? thread.path : `/talk/t/${n}`;
  const board = `<a class="pill" href="${at}/talk/b/${thread.board}">${escapeHtml(say(BOARDS[thread.board]))}</a>`;
  const line = `${escapeHtml(say("started a thread in"))} ${board}${thread.at ? ` · ${timeHtml(thread.at)}` : ""}`;
  const replies = Number(thread.replies) || 0;
  const reply = thread.reply && typeof thread.reply.said === "string" ? thread.reply : null;
  const latest = reply && saidLineHtml(reply)
    ? `<ol class="said-lines" aria-label="${escapeHtml(say("Replies"))}">${saidLineHtml(reply)}</ol>`
    : `<ol class="said-lines" aria-label="${escapeHtml(say("Replies"))}" hidden></ol><p class="said-none">${escapeHtml(say("No replies yet. Be the first to answer."))}</p>`;
  const link = `${at}${escapeHtml(path)}`;
  // Reply opens the composer in the post (web/composer.js replyInCard); its
  // address, the thread's own box, is where it goes without a script. The
  // count is the way to the whole thread.
  return `<article class="post talk" data-kind="talk" data-thread="${n}" aria-labelledby="thread-${n}">`
    + headHtml(thread.by, line)
    + `<div class="post-words"><h3 class="post-title" id="thread-${n}"><a href="${link}">${escapeHtml(String(thread.title || ""))}</a></h3>`
    + `${thread.said ? `<p class="post-text">${escapeHtml(String(thread.said))}</p>` : ""}<div class="said-room">${latest}</div>`
    + `<div class="post-acts"><a class="tally" href="${link}" data-replies="${replies}">${iconHtml("comment")}<span>${escapeHtml(replies === 1 ? say("1 reply")
      : say("{n} replies", { n: number(replies) }))}</span></a>`
    + `<a class="cta ghost small" href="${link}#reply" data-reply-thread="${n}" aria-expanded="false">${escapeHtml(say("Reply"))}</a></div></div></article>`;
}

/// "1–30 November" in the page's language.
export function daysOf(from, to) {
  const day = (iso) => new Date(`${iso}T12:00:00Z`);
  const code = globalThis.brickworksLang?.code;
  try {
    return new Intl.DateTimeFormat(code && code !== "en" ? code : "en-GB", { day: "numeric", month: "long", timeZone: "UTC" })
      .formatRange(day(from), day(to));
  } catch {
    return "";
  }
}

/// The month's challenge as a post (/api/share?op=shelves's, or /api/people
/// ?op=challenge's with its entries): its name and brief as its maker wrote
/// them (English), its days, up to four entries' pictures, and the way in.
/// Its badges and line keep their ids, which web/landing.js says again with
/// the days left once it has asked.
export function challengePostHtml(c, entries = []) {
  if (!c || !c.title) return "";
  const at = langAt();
  const shown = entries.filter((one) => one && MODEL.test(String(one.id)) && pictureOf(one)).slice(0, 4);
  const span = c.starts_on && c.ends_on ? daysOf(c.starts_on, c.ends_on) : "";
  const strip = shown.length
    ? `<ul class="post-entries" aria-label="${escapeHtml(say("Entries"))}">${shown.map((one) => `<li><a href="${at}/m/${one.id}">`
      + `<img src="${escapeHtml(pictureOf(one))}" alt="${escapeHtml(String(one.name || ""))}" width="160" height="120" loading="lazy" decoding="async"></a></li>`).join("")}</ul>`
    : `<p class="post-entries none">${escapeHtml(say("No entries yet: yours could be the first."))}</p>`;
  return `<article class="post challenge" id="challenge" data-kind="challenge" aria-labelledby="challenge-h">`
    + `<div class="post-words"><p class="badges"><span class="badge accent" id="challenge-when">${escapeHtml(say("This month"))}</span>`
    + `<span class="badge good" id="challenge-left" hidden></span></p>`
    + `<p class="eyebrow">${escapeHtml(say("The month’s challenge"))}</p>`
    + `<h3 class="post-title" id="challenge-h" lang="en">${escapeHtml(String(c.title))}</h3>`
    + `${c.brief ? `<p id="challenge-brief" lang="en">${escapeHtml(String(c.brief))}</p>` : `<p id="challenge-brief"></p>`}`
    + `<p class="note" id="challenge-days">${escapeHtml(span)}</p>${strip}`
    + `<p class="go-on"><a class="cta small" href="${at}/challenge" id="challenge-go">${escapeHtml(say("Enter the challenge"))}</a>`
    + `<a class="cta ghost small" href="${at}/challenge#entries">${escapeHtml(say("See the entries"))}</a></p></div></article>`;
}

/// The studio itself in the stream: [model] on it, opened in the card on a
/// tap (web/landing.js, the app at /app?view=<id>, asked for only then).
export function tryPostHtml(model) {
  const id = String(model?.id || "");
  if (!MODEL.test(id)) return "";
  const name = String(model.name || say("A model"));
  const picture = pictureOf(model);
  return `<article class="post try" data-kind="try" data-id="${id}" aria-labelledby="try-h">`
    + `<header class="post-head"><span class="face glyph" aria-hidden="true">${iconHtml("spark")}</span>`
    + `<p class="post-who"><span class="who">${escapeHtml(say("The studio"))}</span><span class="post-line">${escapeHtml(say("in your browser, nothing to install"))}</span></p></header>`
    + `<div class="post-pic try-stage" data-try-stage>${picture ? `<img src="${escapeHtml(picture)}" alt="${escapeHtml(name)}" width="480" height="360" loading="lazy" decoding="async">` : ""}`
    + `<button type="button" class="cta try-go" data-try="${id}">${iconHtml("play")}<span>${escapeHtml(say("Try it here"))}</span></button></div>`
    + `<div class="post-words"><h3 class="post-title" id="try-h">${escapeHtml(say("Try the studio, right here"))}</h3>`
    + `<p class="post-text">${escapeHtml(say("{name}, in the real studio: turn it, play what moves and build it step by step. Then make it yours in the whole studio.", { name }))}</p>`
    + `<p class="post-verbs"><a class="cta small" href="/app?copy=${id}" data-try-open="${id}">${escapeHtml(say("Open the whole studio"))}</a>`
    + `<a class="cta ghost small" href="/docs/first-model">${escapeHtml(say("How to start"))}</a></p></div></article>`;
}

/// Builders to follow, as a post: each their avatar, name and Follow.
export function peoplePostHtml(designers) {
  const people = (designers || []).map(personOf).filter(Boolean).slice(0, 4);
  if (!people.length) return "";
  const at = langAt();
  return `<article class="post people" data-kind="people" aria-labelledby="people-h">`
    + `<div class="post-words"><h3 class="post-title" id="people-h">${escapeHtml(say("Builders to follow"))}</h3>`
    + `<ul class="post-people">${people.map((one) => `<li>${avatarHtml(one, { size: "small" })}`
      + `<a class="who" href="${at}/u/${escapeHtml(one.handle)}">${escapeHtml(one.name)}</a>`
      + `<button type="button" class="cta ghost small follow" data-follow="${escapeHtml(one.handle)}" data-follow-name="${escapeHtml(one.name)}" aria-pressed="false">${escapeHtml(say("Follow"))}</button></li>`).join("")}</ul>`
    + `<p class="note">${escapeHtml(say("Follow a builder and what they make comes to your feed."))}</p></div></article>`;
}

/// A photo of a real build as a post (/api/people?op=latest's photos): who
/// built it, the photo, and the model it is a build of.
export function photoPostHtml(photo) {
  const id = String(photo?.id || "");
  if (!PHOTO.test(id) || !MODEL.test(String(photo.model || ""))) return "";
  const at = langAt();
  const model = String(photo.model_name || say("a model"));
  const width = Number(photo.width) || 4;
  const height = Number(photo.height) || 3;
  return `<article class="post photo" data-kind="photo" data-photo="${id}" aria-labelledby="photo-${id}">`
    + headHtml(photo.by, `${escapeHtml(say("built it for real"))}${photo.at ? ` · ${timeHtml(photo.at)}` : ""}`, { follow: true })
    + `<div class="post-pic"><a class="pic" href="${at}/m/${escapeHtml(String(photo.model))}#photo-${id}" tabindex="-1" aria-hidden="true">`
    + `<img src="${escapeHtml(photoSrc(id, { card: true }))}" alt="${escapeHtml(say("A build of {name}", { name: model }))}" width="${width}" height="${height}" loading="lazy" decoding="async"></a></div>`
    + `<div class="post-words"><h3 class="post-title" id="photo-${id}"><a href="${at}/m/${escapeHtml(String(photo.model))}#photo-${id}">`
    + `${escapeHtml(say("A build of {name}", { name: model }))}</a></h3>`
    + `${photo.words ? `<p class="post-text">${escapeHtml(String(photo.words))}</p>` : ""}`
    + `<p class="post-verbs"><a class="cta small" href="/app?view=${escapeHtml(String(photo.model))}&amp;build">${escapeHtml(say("Build it too"))}</a></p></div></article>`;
}

/// One item of the stream as HTML.
export function postHtml(item, { eager = false } = {}) {
  if (item.kind === "build") return buildPostHtml(item.model, { eager, said: item.said, line: item.line, pick: item.pick });
  if (item.kind === "talk") return talkPostHtml(item.thread);
  if (item.kind === "challenge") return challengePostHtml(item.challenge, item.entries);
  if (item.kind === "try") return tryPostHtml(item.model);
  if (item.kind === "people") return peoplePostHtml(item.designers);
  if (item.kind === "photo") return photoPostHtml(item.photo);
  return "";
}

/// What an item is, to tell two apart: its kind and its id.
export const keyOf = (item) => `${item.kind}:${item.kind === "build" || item.kind === "try" ? item.model?.id
  : item.kind === "talk" ? item.thread?.id : item.kind === "photo" ? item.photo?.id : ""}`;

/// The models of a list's [answer] the feed may show: real ones with pictures.
export const showable = (answer) => (Array.isArray(answer?.models) ? answer.models : [])
  .filter((m) => m && MODEL.test(String(m.id)) && pictureOf(m));

/// The order For you takes, signed out or in: models first and most, the
/// challenge third, then a thread, the studio to try, and so on; what has
/// nothing to give is passed over, and what is left of the models after.
const FOR_YOU = ["build", "build", "challenge", "build", "talk", "try", "build", "build", "talk", "people", "photo",
  "build", "build", "talk", "build", "photo", "build", "talk", "build", "build", "photo", "build"];

/// The stream from what the server said ([given]):
///   top, newest  lists' answers (/api/share?op=list)
///   shelves      /api/share?op=shelves (the week's pick, the challenge)
///   challenge    /api/people?op=challenge (the challenge and its entries)
///   talk         /api/people?op=talk_latest&reply=1&talking=N
///   latest       /api/people?op=latest (photos of builds, builders to follow)
/// [tab] "foryou" (signed out it is the one stream) or "new": everything
/// newest first, the challenge third. [skip] the keys already shown.
export function compose(given, { tab = "foryou", skip = new Set() } = {}) {
  const pickModel = given.shelves?.pick?.model;
  const pick = pickModel && MODEL.test(String(pickModel.id)) && pictureOf(pickModel) ? pickModel : null;
  // What was said under each model, newest first: its newest two comments.
  const said = new Map();
  for (const one of Array.isArray(given.talk?.talking) ? given.talk.talking : []) {
    if (!one || !MODEL.test(String(one.model)) || one.parent) continue;
    const of = said.get(one.model) || [];
    if (of.length < 2) said.set(one.model, [...of, one]);
  }
  const seen = new Set(skip);
  const take = (item) => {
    const key = keyOf(item);
    if (seen.has(key)) return null;
    seen.add(key);
    return item;
  };
  const top = showable(given.top);
  const newest = showable(given.newest);
  const build = (m, extra = {}) => ({ kind: "build", model: m, said: said.get(m.id) || null, ...extra });
  // Top and New in turn, the week's pick first.
  const builds = [];
  if (pick && tab === "foryou") builds.push(build(pick, { pick: true, line: say("this week’s pick") }));
  const lists = tab === "new" ? [newest, top] : [top, newest];
  for (let i = 0; i < Math.max(lists[0].length, lists[1].length); i += 1) {
    if (lists[0][i]) builds.push(build(lists[0][i]));
    if (tab !== "new" && lists[1][i]) builds.push(build(lists[1][i]));
  }
  const threads = (Array.isArray(given.talk?.threads) ? given.talk.threads : []).map((thread) => ({ kind: "talk", thread }));
  const photos = (Array.isArray(given.latest?.photos) ? given.latest.photos : []).map((photo) => ({ kind: "photo", photo }));
  const c = given.challenge?.challenge || given.shelves?.challenge || null;
  const live = c && !c.test && ["open", "upcoming"].includes(c.state) && c.title ? c : null;
  const entries = live && Array.isArray(live.groups) ? live.groups.flatMap((group) => group.entries || []) : [];
  const challenge = live ? [{ kind: "challenge", challenge: live, entries }] : [];
  const movers = [...top, ...newest].filter((m) => (m.motions || []).length || (m.moves || []).length);
  const tryModel = movers[0] || top[0] || newest[0] || pick;
  const trying = tryModel && tab === "foryou" ? [{ kind: "try", model: tryModel }] : [];
  const designers = Array.isArray(given.latest?.designers) ? given.latest.designers.filter((one) => personOf(one)) : [];
  const people = designers.length && tab === "foryou" ? [{ kind: "people", designers }] : [];
  const queues = { build: builds, talk: threads, challenge, try: trying, people, photo: photos };
  const items = [];
  const next = (kind) => {
    const queue = queues[kind];
    while (queue.length) {
      const item = take(queue.shift());
      if (item) return item;
    }
    return null;
  };
  if (tab === "new") {
    // Newest first by when each was made, the challenge third.
    const when = (item) => Date.parse(item.kind === "build" ? item.model.listed_at : item.kind === "talk"
      ? item.thread.last_at || item.thread.at : item.photo.at) || 0;
    const all = [...builds, ...threads, ...photos].sort((a, b) => when(b) - when(a));
    for (const item of all) if (take(item)) items.push(item);
    if (challenge.length && take(challenge[0])) items.splice(Math.min(2, items.length), 0, challenge[0]);
    return items;
  }
  for (const kind of FOR_YOU) {
    const item = next(kind);
    if (item) items.push(item);
  }
  for (const kind of ["build", "talk", "photo"]) {
    let item = next(kind);
    while (item) {
      items.push(item);
      item = next(kind);
    }
  }
  return items;
}

/// A row of the signed-in feed (/api/people?op=feed's, api/_follows.js) as
/// an item: a model or a version with its card, a photo of a build.
export function feedItem(row) {
  if (row?.kind === "photo" && row.photo && PHOTO.test(String(row.photo.id))) {
    return { kind: "photo", photo: { ...row.photo, model: row.model, model_name: row.name, by: row.by, at: row.at, words: row.said } };
  }
  if (row?.card && MODEL.test(String(row.card.id)) && pictureOf(row.card)) {
    return { kind: "build", model: { ...row.card, by: row.card.by || row.by }, line: row.kind === "version" ? say("shared a new version")
      : row.kind === "entry" ? say("entered the challenge") : say("shared a build") };
  }
  return null;
}
