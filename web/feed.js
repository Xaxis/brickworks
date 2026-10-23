// /feed (2026-10-18, supabase/follows.sql): what the people the signed-in
// account follows made, newest first, from /api/people?op=feed. What
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
// which escape their own.
import { askToSignIn, call, signOut, signedIn } from "/account.js";
import { followButton, showFeedCount, showTabCounts } from "/follow.js";
import { ago, avatarHtml } from "/kit.js";
import { modelCard } from "/card.js";

const $ = (id) => document.getElementById(id);
// How many designers it suggests.
const SUGGESTED = 5;
let oldest = null;
// Which load the page is drawing: one begun since (signed in from the
// dialog, say) makes an older one's answers stale, and they are dropped.
let run = 0;

/// Only the site's own addresses: what the server made from ids.
function here(link, otherwise = "/feed") {
  try {
    const url = new URL(String(link || ""), location.origin);
    return url.origin === location.origin ? url.pathname + url.search + url.hash : otherwise;
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
  link.href = `/u/${encodeURIComponent(by.handle)}`;
  for (const [name, value] of Object.entries(attrs)) link.setAttribute(name, value);
  link.append(inner);
  return link;
}

/// The photo of a build, as a post shows it: the picture, a link to it on
/// its model's page, and which model it is a build of.
function photoFigure(one) {
  const figure = document.createElement("figure");
  figure.className = "feed-photo";
  const link = document.createElement("a");
  link.href = here(one.link);
  const img = document.createElement("img");
  img.src = here(one.photo.url, "");
  img.alt = `A build of ${String(one.name || "a model")}`;
  if (one.photo.width && one.photo.height) {
    img.width = Number(one.photo.width);
    img.height = Number(one.photo.height);
  }
  img.loading = "lazy";
  img.decoding = "async";
  link.append(img);
  const caption = document.createElement("figcaption");
  const model = document.createElement("a");
  model.href = here(`/m/${encodeURIComponent(String(one.model || ""))}`);
  model.textContent = String(one.name || "a model");
  caption.append("A build of ", model);
  figure.append(link, caption);
  return figure;
}

function row(one) {
  const item = document.createElement("li");
  item.className = `feed-row${one.new ? " new" : ""}`;
  item.dataset.kind = String(one.kind || "");
  // Who did it, and what.
  const head = document.createElement("div");
  head.className = "post-head";
  const face = one.by && one.by.handle ? parsed(avatarHtml({ handle: one.by.handle, name: one.by.name })) : null;
  if (face) head.append(toProfile(one.by, face, { tabindex: "-1", "aria-hidden": "true", class: "face" }));
  const what = document.createElement("p");
  what.className = "what";
  const who = document.createElement("b");
  who.textContent = String(one.who || "A builder");
  const name = document.createElement("a");
  name.className = "go";
  name.href = here(one.link);
  name.textContent = `“${String(one.name || "")}”`;
  what.append(toProfile(one.by, who, { class: "who" }), ` ${String(one.did || "")} `, name);
  if (one.after) what.append(` ${String(one.after)}`);
  if (one.new) {
    const tag = document.createElement("span");
    tag.className = "pill new";
    tag.textContent = "New";
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
  if (one.kind === "photo" && one.photo && one.photo.url) item.append(photoFigure(one));
  else if (one.card) item.append(modelCard(one.card));
  return item;
}

/// A designer to follow: their avatar, their name (to their profile), the
/// models of theirs that earned most, and Follow.
function person(one) {
  const item = document.createElement("li");
  item.className = "person-row";
  item.dataset.handle = one.handle;
  item.append(toProfile(one, parsed(avatarHtml({ handle: one.handle, name: one.name })),
    { tabindex: "-1", "aria-hidden": "true", class: "face" }));
  const names = document.createElement("div");
  names.className = "names";
  const name = document.createElement("b");
  name.textContent = String(one.name || one.handle);
  const made = document.createElement("small");
  const models = Array.isArray(one.models) ? one.models.slice(0, 2).map((model) => String(model.name)) : [];
  made.textContent = models.length ? models.join(" · ") : `@${one.handle}`;
  names.append(toProfile(one, name), made);
  const button = document.createElement("button");
  button.type = "button";
  button.className = "cta ghost small follow";
  button.dataset.follow = one.handle;
  button.textContent = "Follow";
  const told = document.createElement("span");
  told.className = "said";
  told.setAttribute("role", "status");
  item.append(names, button, told);
  followButton(button, { you_follow: false, mine: false, signed_in: signedIn(), may: true, why_not: "" }).catch(() => null);
  return item;
}

/// A photo of a build in Latest, as a profile's builds show one.
function buildFigure(one) {
  const figure = document.createElement("figure");
  figure.className = "build";
  const link = document.createElement("a");
  link.href = here(one.page);
  const img = document.createElement("img");
  img.src = here(one.url, "");
  img.alt = `A build of ${String(one.model_name || "a model")}`;
  img.width = Number(one.width) || 1;
  img.height = Number(one.height) || 1;
  img.loading = "lazy";
  img.decoding = "async";
  link.append(img);
  const caption = document.createElement("figcaption");
  if (one.words) {
    const quote = document.createElement("q");
    quote.textContent = String(one.words);
    caption.append(quote);
  }
  const model = document.createElement("a");
  model.href = here(`/m/${encodeURIComponent(String(one.model || ""))}`);
  model.textContent = String(one.model_name || "a model");
  caption.append(model);
  if (one.by && one.by.handle) {
    const who = document.createElement("a");
    who.href = `/u/${encodeURIComponent(one.by.handle)}`;
    who.textContent = String(one.by.name || one.by.handle);
    caption.append(", built by ", who);
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
  $("latest-models").replaceChildren(...models.map((one) => modelCard(one)));
  $("latest-photos").replaceChildren(...photos.map(buildFigure));
  $("latest-photos").hidden = $("photos-title").hidden = photos.length === 0;
  $("latest").hidden = models.length === 0 && photos.length === 0;
}

async function page(mine) {
  const first = oldest === null;
  const answer = await call(`/api/people?op=feed${oldest ? `&before=${encodeURIComponent(oldest)}` : ""}`);
  if (mine !== run) return;
  if (answer.status === 401) {
    signOut();
    return load();
  }
  if (answer.status !== 200) {
    $("said").textContent = answer.body.error || "Brickworks could not show your feed just now. Try again in a minute.";
    document.documentElement.dataset.feed = "failed";
    return;
  }
  if (answer.body.ready === false) {
    $("not-yet").hidden = false;
    document.documentElement.dataset.feed = "not-yet";
    return;
  }
  const rows = Array.isArray(answer.body.rows) ? answer.body.rows : [];
  for (const one of rows) $("rows").append(row(one));
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
  document.documentElement.dataset.feed = "ready";
}

async function load() {
  const mine = ++run;
  $("loading").hidden = true;
  $("layout").hidden = false;
  for (const id of ["signed-out", "nobody", "quiet", "not-yet", "latest", "designers"]) $(id).hidden = true;
  $("rows").replaceChildren();
  $("layout").classList.remove("posts");
  $("older-line").hidden = true;
  $("said").textContent = "";
  oldest = null;
  if (!signedIn()) {
    $("signed-out").hidden = false;
    await suggest(mine, { withLatest: true });
    if (mine === run) document.documentElement.dataset.feed = "signed-out";
    return;
  }
  await page(mine);
}

// Signed in, here or from a Follow among the designers, the page is drawn
// again as it is for them (brickworks:signed-in, below).
$("sign-in").addEventListener("click", () => askToSignIn("Sign in with your email address: we send you a code, no password."));
$("older").addEventListener("click", async () => {
  $("older").disabled = true;
  await page(run);
  $("older").disabled = false;
});
addEventListener("brickworks:signed-in", () => load());

load();
