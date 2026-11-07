// /feed (2026-10-18, supabase/follows.sql): what the people the signed-in
// account follows made, and what was put in the collections it follows
// (supabase/collection_follows.sql), newest first, from /api/people?op=feed. What
// happened to your own models is Notifications (2026-10-22,
// web/notifications.js), a tab beside it. Opening the feed is what clears
// its count (the server marks the first page as seen).
//
// A feed you look at (docs/SOCIAL.md U9): each row a post, who did it (their
// avatar, a link to their profile) and what, then the thing itself: the
// gallery's card of the model (web/card.js), a new version's note above
// it, or the photo of a build. The new ones since the feed was last opened
// are marked New.
//
// Signed out, following nobody, or followed people who made nothing in 90
// days: Latest on Brickworks, the newest models in the gallery and photos
// of real builds, from /api/people?op=latest. And beside the feed, or under
// it on a phone, designers to follow by Top builds of their models, each
// with Follow (web/follow.js): followed, they fill the feed on the next
// load.
//
// Every word is put on the page as text; a card and an avatar are the kit's,
// which escape their own. The page's words are in its language (web/card.js
// say), and so is each post's line, said by the server (?lang=,
// api/_follows.js feedSaid); what people wrote as they wrote it.
import { askToSignIn, call, signOut, signedIn } from "/account.js";
import { followsSent, personRow, showFeedCount, showTabCounts } from "/follow.js";
import { ago, avatarHtml } from "/kit.js";
import { FIRST_SCREEN, langAt, modelCard, say, setPhoto, sharpPhotos, told } from "/card.js";

const $ = (id) => document.getElementById(id);
// The language the server says each post's line in.
const LANG = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? `&lang=${globalThis.brickworksLang.code}` : "";
// How many designers it suggests.
const SUGGESTED = 5;
// A photo's id (api/_builds.js): its picture is drawn from it alone.
const ID = /^[A-Za-z0-9]{10}$/;
let oldest = null;
// Which load the page is drawing: one begun since (signed in from the
// dialog, say) makes an older one's answers stale, and they are dropped.
let run = 0;

/// Only the site's own addresses: what the server made from ids, a page
/// with a copy in the page's language opening it (/de/m/<id>).
function here(link, otherwise = `${langAt()}/feed`) {
  try {
    const url = new URL(String(link || ""), location.origin);
    if (url.origin !== location.origin) return otherwise;
    const copied = /^\/(?:[muc]\/|(?:challenge|profile|collections)(?=\/?$))/.test(url.pathname);
    return (copied ? langAt() : "") + url.pathname + url.search + url.hash;
  } catch {
    return otherwise;
  }
}

const parsed = (html) => {
  const made = document.createElement("template");
  made.innerHTML = html;
  return made.content.firstElementChild;
};

/// A link to a person's profile around [inner], or [inner] alone without one.
function toProfile(by, inner, attrs = {}) {
  if (!by || !by.handle) return inner;
  const link = document.createElement("a");
  link.href = `${langAt()}/u/${encodeURIComponent(by.handle)}`;
  for (const [name, value] of Object.entries(attrs)) link.setAttribute(name, value);
  link.append(inner);
  return link;
}

/// The photo of a build, as a post shows it: the picture, a link to it on
/// its model's page, and which model it is a build of.
function photoFigure(one, eager = false) {
  const figure = document.createElement("figure");
  figure.className = "feed-photo";
  const link = document.createElement("a");
  link.href = here(one.link);
  const img = document.createElement("img");
  img.alt = say("A build of {name}", { name: String(one.name || say("a model")) });
  if (one.photo.width && one.photo.height) {
    img.width = Number(one.photo.width);
    img.height = Number(one.photo.height);
  }
  img.loading = eager ? "eager" : "lazy";
  if (eager) img.fetchPriority = "high";
  img.decoding = "async";
  setPhoto(img, one.photo, "feed");
  link.append(img);
  const caption = document.createElement("figcaption");
  const model = document.createElement("a");
  model.href = here(`/m/${encodeURIComponent(String(one.model || ""))}`);
  model.textContent = String(one.name || say("a model"));
  sayInto(caption, say("A build of {name}"), { name: model });
  figure.append(link, caption);
  return figure;
}

/// [said], a sentence in the page's language, into [into]: each {name} in
/// it [parts]'s element or words.
function sayInto(into, said, parts) {
  for (const piece of said.split(/(\{\w+\})/)) {
    const name = /^\{(\w+)\}$/.exec(piece)?.[1];
    if (piece) into.append(name && name in parts ? parts[name] : piece);
  }
  return into;
}

/// [text] in quotes as the page's language writes them: “Tower”, „Tower“.
const quoted = (text) => say("“{text}”", { text });

function row(one, eager = false) {
  const item = document.createElement("li");
  item.className = `feed-row${one.new ? " new" : ""}`;
  item.dataset.kind = String(one.kind || "");
  // Who did it, and what.
  const head = document.createElement("div");
  head.className = "post-head";
  const face = one.by && one.by.handle ? parsed(avatarHtml({ handle: one.by.handle, name: one.by.name, picture: one.by.picture })) : null;
  if (face) head.append(toProfile(one.by, face, { tabindex: "-1", "aria-hidden": "true", class: "face" }));
  const what = document.createElement("p");
  what.className = "what";
  const who = document.createElement("b");
  who.textContent = String(one.who || say("A builder"));
  const name = document.createElement("a");
  name.className = "go";
  name.href = here(one.link);
  name.textContent = quoted(String(one.name || ""));
  // The line as the server said it, each link where the language puts it;
  // put in a collection you follow: which, to its page.
  const parts = { who: toProfile(one.by, who, { class: "who" }), name, of: quoted(String(one.of || "")),
    title: quoted(String(one.title || "")) };
  if (one.list && one.list.name) {
    parts.list = document.createElement("a");
    parts.list.className = "list";
    parts.list.href = here(one.list.link);
    parts.list.textContent = quoted(String(one.list.name));
  }
  sayInto(what, String(one.line || "{who} {name}"), parts);
  if (one.new) {
    const tag = document.createElement("span");
    tag.className = "pill new";
    tag.textContent = say("New");
    what.append(" ", tag);
  }
  const words = document.createElement("div");
  words.className = "words";
  words.append(what);
  const said = ago(one.at);
  if (said) {
    const at = document.createElement("time");
    at.dateTime = String(one.at);
    at.textContent = said;
    words.append(at);
  }
  head.append(words);
  item.append(head);
  // What they said of it: a version's note, a photo's words.
  if (one.said) {
    const quote = document.createElement("q");
    quote.textContent = String(one.said);
    item.append(quote);
  }
  // The thing: the photo of the build, or the model's card.
  if (one.kind === "photo" && one.photo && ID.test(String(one.photo.id))) item.append(photoFigure(one, eager));
  else if (one.card) item.append(modelCard(one.card, { eager }));
  return item;
}

/// A designer to follow: their avatar, their name (to their profile), the
/// models of theirs that earned most, and Follow.
function person(one) {
  const models = Array.isArray(one.models) ? one.models.slice(0, 2).map((model) => String(model.name)) : [];
  return personRow(one, models.join(" · "), { you_follow: false, mine: false, signed_in: signedIn(), may: true, why_not: "" });
}

/// A photo of a build in Latest, as a profile's builds show one.
function buildFigure(one) {
  const figure = document.createElement("figure");
  figure.className = "build";
  const link = document.createElement("a");
  link.href = here(one.page);
  const img = document.createElement("img");
  img.alt = say("A build of {name}", { name: String(one.model_name || say("a model")) });
  img.width = Number(one.width) || 1;
  img.height = Number(one.height) || 1;
  img.loading = "lazy";
  img.decoding = "async";
  setPhoto(img, one, "columns");
  link.append(img);
  const caption = document.createElement("figcaption");
  if (one.words) {
    const quote = document.createElement("q");
    quote.textContent = String(one.words);
    caption.append(quote);
  }
  const model = document.createElement("a");
  model.href = here(`/m/${encodeURIComponent(String(one.model || ""))}`);
  model.textContent = String(one.model_name || say("a model"));
  caption.append(model);
  if (one.by && one.by.handle) {
    const who = document.createElement("a");
    who.href = `${langAt()}/u/${encodeURIComponent(one.by.handle)}`;
    who.textContent = String(one.by.name || one.by.handle);
    sayInto(caption, say(", built by {who}"), { who });
  }
  figure.append(link, caption);
  return figure;
}

/// Latest on Brickworks and designers to follow, leaving out [skip] (the
/// handles of whom you follow, and you). [withLatest]: the feed has
/// nothing of its own to show, so the latest is shown in its place.
async function suggest(mine, { withLatest, skip = new Set() }) {
  const tests = new URLSearchParams(location.search).get("tests") === "1" ? "&tests=1" : "";
  const answer = await call(`/api/people?op=latest${tests}`).catch(() => null);
  if (mine !== run || !answer || answer.status !== 200) return;
  const designers = (Array.isArray(answer.body.designers) ? answer.body.designers : [])
    .filter((one) => one && one.handle && !skip.has(one.handle)).slice(0, SUGGESTED);
  $("people").replaceChildren(...designers.map(person));
  $("designers").hidden = designers.length === 0;
  $("layout").classList.toggle("with-rail", designers.length > 0);
  if (!withLatest) return;
  const models = Array.isArray(answer.body.models) ? answer.body.models : [];
  const photos = Array.isArray(answer.body.photos) ? answer.body.photos : [];
  $("latest-models").replaceChildren(...models.map((one, i) => modelCard(one, { eager: i < FIRST_SCREEN })));
  $("latest-photos").replaceChildren(...photos.filter((one) => one && ID.test(String(one.id))).map(buildFigure));
  sharpPhotos($("latest-photos"));
  $("latest-photos").hidden = $("photos-title").hidden = photos.length === 0;
  $("latest").hidden = models.length === 0 && photos.length === 0;
}

async function page(mine) {
  const first = oldest === null;
  // A follow pressed a moment ago, here or on the page before, is answered
  // first: the feed is asked as it is then, never without them (web295).
  if (first) await followsSent();
  if (mine !== run) return;
  const answer = await call(`/api/people?op=feed${oldest ? `&before=${encodeURIComponent(oldest)}` : ""}${LANG}`);
  if (mine !== run) return;
  if (answer.status === 401) {
    signOut();
    return load();
  }
  if (answer.status !== 200) {
    $("said").textContent = told(answer.body.error, say("Brickworks could not show your feed just now. Try again in a minute."));
    document.documentElement.dataset.feed = "failed";
    return;
  }
  if (answer.body.ready === false) {
    $("not-yet").hidden = false;
    document.documentElement.dataset.feed = "not-yet";
    return;
  }
  const rows = Array.isArray(answer.body.rows) ? answer.body.rows : [];
  // The first two posts are the first screen's: their pictures asked first.
  for (const [i, one] of rows.entries()) $("rows").append(row(one, first && i < 2));
  sharpPhotos($("rows"));
  if (rows.length) oldest = rows[rows.length - 1].at;
  $("older-line").hidden = !answer.body.more;
  // Opened: what was counted is seen now; Notifications' is what is left.
  const state = await showFeedCount().catch(() => null);
  if (mine !== run) return;
  showTabCounts(state);
  if (first) {
    const following = Array.isArray(answer.body.following) ? answer.body.following : null;
    const empty = $("rows").children.length === 0;
    $("layout").classList.toggle("posts", !empty);
    $("nobody").hidden = !(empty && following !== null && following.length === 0);
    $("quiet").hidden = !(empty && $("nobody").hidden);
    const skip = new Set([...(following || []), ...(state?.me?.handle ? [state.me.handle] : [])]);
    await suggest(mine, { withLatest: empty, skip });
  }
  if (mine === run) document.documentElement.dataset.feed = "ready";
}

// The skeleton (feed.html #loading) holds the page's place while the feed
// and the designers to follow are asked, and the page is drawn whole once
// they have come: each part drawn as it came moved the others, and the
// rail coming in beside the posts narrowed them (site273, /feed 0.31-0.52).
async function load() {
  const mine = ++run;
  $("loading").hidden = false;
  $("layout").hidden = true;
  for (const id of ["signed-out", "nobody", "quiet", "not-yet", "latest", "designers"]) $(id).hidden = true;
  $("rows").replaceChildren();
  $("layout").classList.remove("posts");
  $("older-line").hidden = true;
  $("said").textContent = "";
  oldest = null;
  const out = !signedIn();
  if (out) {
    $("signed-out").hidden = false;
    await suggest(mine, { withLatest: true });
  } else {
    await page(mine);
  }
  if (mine !== run) return;
  $("loading").hidden = true;
  $("layout").hidden = false;
  if (out) document.documentElement.dataset.feed = "signed-out";
}

// Signed in, here or from a Follow among the designers, the page is drawn
// again as it is for them (brickworks:signed-in, below).
$("sign-in").addEventListener("click", () => askToSignIn());
$("older").addEventListener("click", async () => {
  $("older").disabled = true;
  await page(run);
  $("older").disabled = false;
});
addEventListener("brickworks:signed-in", () => load());

load();
