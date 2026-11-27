// What the home page (index.html) does: the feed, and what is around it.
//
// The feed (homefeed, 2026-11-23; docs/SOCIAL.md section 11), #stream: one
// stream of posts (web/home-feed.js draws each), new builds, Talk's threads
// with their latest reply, the month's challenge and its entries, the studio
// to try and builders to follow. Its first posts are in the page as served
// (tools/web/home_shelf.mjs, at the deploy); once the page is in and idle
// the same answers are asked again (FEEDS), each post there already says
// its counts as they are now (a like's, its comments', the newest thing
// said), a number for a number in its own room, and the rest go in under
// it, a page at a time with Show more. A page with no posts in it (a
// checkout's own) draws them all in its skeletons' place. Signed in (a
// sign-in kept here, <html data-signed>, web/theme.js), Share a build and
// the tabs For you (the stream, asked as them: their likes, nobody they
// blocked), Following (/api/people?op=feed, what the people they follow
// made) and New (everything newest first).
//
// Each build's post works in place: Like, Follow and a comment, each asking
// a visitor to sign in on the spot (web/account.js askToSignIn) and going on
// where they were; Share (the device's own share, else the link copied);
// the model turned in 3D in its picture's place (web/viewer3d.js, asked for
// only then) on a hover that stays, or a tap of 3D; and Try it here, the
// studio itself in its post (the app at /app?view=<id>, asked for only on
// the tap), with Open the whole studio, which takes the visitor to it.
//
// Around it, as before (landing, 2026-11-22):
// - #find, the search: its suggestions' script (web/home-find.js) asked for
//   once the field is used, and "/" puts the cursor in it;
// - #challenge, the challenge's post: its days left (and where it runs in
//   rounds, which round and how long it has), or the next one told;
// - #beta, while the beta is open, as its place nears;
// - #sets, four of the LDraw library's biggest sets with a 3D model.
//
// Each says how it ended on <html> (data-feed-live, data-feed-tab,
// data-challenge, data-sets), which tools/web/landing_check.mjs and
// tools/web/homefeed_check.mjs wait on.
import { askToSignIn, call, signedIn } from "/account.js";
import { appAt, counted, escapeHtml, iconButtonHtml, langAt, likeName, number, pictureOf, say, told } from "/card.js";
import { commentsInCard, replyInCard } from "/composer.js";
import { FIRST, compose, feedItem, keyOf, postHtml, postSkeletonHtml } from "/home-feed.js";
import { ago, toast } from "/kit.js";

const SET = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
const MODEL = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const SETS = 4;
// Posts put in at a time: the first page's, and each Show more's.
const PAGE = 12;
const html = document.documentElement;
// The checks' own pool where the address asks for it (?tests=1), as the gallery's and Talk's.
const TESTS = new URLSearchParams(location.search).get("tests") === "1" ? "&tests=1" : "";

/// What [path] answers as JSON, or null: a refusal is read too, since an
/// answer never read keeps the page busy. [mine]: asked with the sign-in
/// kept here (web/account.js call), for what is the person's own.
async function ask(path, { mine = false } = {}) {
  try {
    if (mine && signedIn()) {
      const answer = await call(path);
      return answer.status === 200 ? answer.body : null;
    }
    const reply = await fetch(path, { headers: { accept: "application/json" } });
    const body = await reply.json().catch(() => null);
    return reply.ok ? body : null;
  } catch {
    return null;
  }
}

/// Whether [img] has arrived and decoded.
async function drawn(img) {
  if (!img) return false;
  img.loading = "eager";
  try {
    await img.decode();
  } catch {
    return false;
  }
  return img.naturalWidth > 0;
}

// This week's pick and the challenge, asked once for both.
const shelves = ask(`/api/share?op=shelves${TESTS}`);

// ---------------------------------------------------------------------------
// The feed.

const stream = document.getElementById("stream");
const more = document.getElementById("feed-more");
const streamSaid = document.getElementById("stream-said");
const tabList = document.getElementById("feed-tabs");
const tabs = tabList ? [...tabList.querySelectorAll('[role="tab"]')] : [];
const served = stream?.dataset.stream === "served";
// The stream drawn again for somebody who just signed in, as them: a like
// they signed in for waits on it (like).
let signedInDraw = Promise.resolve();

/// What the stream is made of, for [tab], each answer kept by the CDN for
/// somebody signed out; signed in, the lists and the latest are asked as
/// them (mine=1), so a post says what they liked and leaves out whom they
/// blocked. [page] the lists' page.
function feeds(tab, page = 1) {
  const mine = signedIn();
  const as = mine ? "&mine=1" : "";
  return {
    top: ask(`/api/share?op=list&page=${page}&sort=top${as}${TESTS}`, { mine }),
    newest: ask(`/api/share?op=list&page=${page}&sort=newest${as}${TESTS}`, { mine }),
    shelves,
    challenge: page === 1 ? ask(`/api/people?op=challenge${TESTS}`) : null,
    talk: page === 1 ? ask(`/api/people?op=talk_latest&n=6&reply=1&talking=24${TESTS}`) : null,
    latest: page === 1 ? ask(`/api/people?op=latest${as}${TESTS}`, { mine }) : null,
  };
}

/// Every answer of [asked] (feeds'), once in.
async function answers(asked) {
  const keys = Object.keys(asked);
  const got = await Promise.all(keys.map((key) => asked[key]));
  return Object.fromEntries(keys.map((key, i) => [key, got[i]]));
}

/// The posts the stream holds, by what each is (home-feed.js keyOf).
function postKey(post) {
  const kind = post.dataset.kind;
  if (kind === "build" || kind === "try") return `${kind}:${post.dataset.id}`;
  if (kind === "talk") return `talk:${post.dataset.thread}`;
  if (kind === "photo") return `photo:${post.dataset.photo}`;
  return `${kind}:`;
}
const shownKeys = () => new Set([...stream.querySelectorAll(":scope > .post:not(.skeleton)")].map(postKey));

/// [items] as posts, ready to put in: each a post element, its picture not
/// yet asked for unless [eager].
function postsOf(items, { eager = 0 } = {}) {
  const made = document.createElement("template");
  made.innerHTML = items.map((item, i) => postHtml(item, { eager: i < eager })).join("");
  return [...made.content.children];
}

/// A post already in the page, told what is so now: its like (pressed for
/// whoever likes it, and its count), its comments' count, and the newest
/// thing said of it. Each in the room it has, so nothing moves.
function freshen(post, item) {
  if (item.kind !== "build") return;
  const model = item.model;
  const like = post.querySelector("[data-like]");
  if (like) drawLike(like, model.liked === true, Number(model.likes) || 0, String(model.name || ""));
  const comments = post.querySelector(".post-acts [data-say]");
  if (comments) {
    const made = document.createElement("template");
    made.innerHTML = iconButtonHtml({ icon: "comment", name: say("Comments on {name}", { name: String(model.name || "") }),
      count: model.comments, one: "comment", small: true });
    const fresh = made.content.firstElementChild;
    comments.setAttribute("aria-label", fresh.getAttribute("aria-label"));
    comments.replaceChildren(...fresh.childNodes);
  }
  // What was said, and "n more", where nobody is saying something there.
  const talk = post.querySelector(".post-talk");
  if (talk && !talk.__said) {
    const fresh = postsOf([item])[0]?.querySelector(".post-talk");
    if (fresh && fresh.innerHTML !== talk.innerHTML) talk.replaceWith(fresh);
  }
}

/// The times in [root]'s posts said as a time ago, in the page's language.
function sayWhen(root) {
  for (const time of root.querySelectorAll(".post time[datetime]")) {
    const said = ago(time.dateTime);
    if (said) time.textContent = said;
  }
}

// What the stream is showing: which tab, which of its lists' pages has been
// asked, and what is left of what was asked, to put in with Show more.
let tab = "foryou";
let page = 1;
let waiting = [];
let ended = false;
// Which draw is current: one begun since (another tab, a sign-in) makes an
// older one's answers stale, and they are dropped.
let run = 0;

/// Puts in up to PAGE of what is waiting, under what is there, and says
/// whether there is more.
function putIn() {
  const items = waiting.splice(0, PAGE);
  const posts = postsOf(items);
  stream.append(...posts);
  sayWhen(stream);
  liven(posts);
  more.hidden = waiting.length === 0 && ended;
  return posts.length;
}

/// The stream for [tab] from what the server says now. On the page's first
/// draw, the posts the page was served with stay where they are, told
/// their counts; the rest go in after them. Otherwise (a tab chosen, a
/// sign-in) what is there makes way for the new.
async function draw({ first = false, kept = false } = {}) {
  const mine = ++run;
  page = 1;
  ended = false;
  stream.setAttribute("aria-busy", "true");
  streamSaid.textContent = "";
  let items;
  if (tab === "following") {
    items = await following(mine);
  } else {
    const got = await answers(feeds(tab, 1));
    if (mine !== run) return;
    items = compose(got, { tab });
    ended = !(got.top?.more || got.newest?.more);
  }
  if (mine !== run || items === null) return;
  // Kept too after a sign-in: what they were doing in a post (a comment
  // typed, a like) stays where it is, the post told what is so for them.
  const keep = (first && served) || kept;
  if (keep) {
    // Told what is so now, each served post that is still in the stream.
    const byKey = new Map(items.map((item) => [keyOf(item), item]));
    for (const post of stream.querySelectorAll(":scope > .post:not(.skeleton)")) {
      const item = byKey.get(postKey(post));
      if (item) freshen(post, item);
    }
    const shown = shownKeys();
    waiting = items.filter((item) => !shown.has(keyOf(item)));
    html.dataset.feedLive = items.length ? "same" : "none";
    sayWhen(stream);
    liven([...stream.querySelectorAll(":scope > .post")]);
  } else {
    waiting = items;
    // A first page whose pictures are in before it goes in: drawn whole.
    const head = postsOf(waiting.slice(0, Math.min(FIRST, waiting.length)), { eager: first ? 1 : 0 });
    if (first) await Promise.all(head.slice(0, 3).map((post) => drawn(post.querySelector(".post-pic img")).catch(() => false)));
    if (mine !== run) return;
    stream.replaceChildren();
    html.dataset.feedLive = items.length ? "changed" : "none";
  }
  if (!keep) putIn();
  else if (stream.children.length < PAGE) putIn();
  more.hidden = waiting.length === 0 && ended;
  if (!stream.querySelector(".post:not(.skeleton)")) {
    stream.replaceChildren();
    streamSaid.textContent = tab === "following"
      ? say("Nothing from the people you follow yet. Follow builders from their posts, and what they make comes here.")
      : say("Brickworks could not show the feed just now. Try again in a minute.");
  } else if (tab === "following" && !followOthers) {
    // Their own posts alone (a newcomer's first build): under them, how
    // the tab fills.
    streamSaid.textContent = say("Nothing from the people you follow yet. Follow builders from their posts, and what they make comes here.");
  }
  stream.setAttribute("aria-busy", "false");
  html.dataset.feedTab = tab;
  challenge();
}

/// The Following tab's posts: what the people the person follows made,
/// newest first (/api/people?op=feed, as /feed shows it, which marks it
/// seen), from [before] (the last post's time) for Show more; null when the
/// draw went stale.
let followBefore = null;
// Whether Following's first page had anybody's posts but the person's own.
let followOthers = true;
async function following(mine, before = null) {
  // A Follow pressed a moment ago is shown pressed at once, its answer
  // still coming: asked before it, the tab said nobody was followed
  // (checkdrift, 2026-11-23, Follow then Following at once).
  if (followModule) await (await followModule).followsSettled().catch(() => null);
  const lang = langAt() ? `&lang=${langAt().slice(1)}` : "";
  const answer = await call(`/api/people?op=feed${lang}${before ? `&before=${encodeURIComponent(before)}` : ""}`).catch(() => null);
  if (mine !== run) return null;
  if (!answer || answer.status !== 200) {
    streamSaid.textContent = told(answer?.body?.error, say("Brickworks could not show your feed just now. Try again in a minute."));
    return [];
  }
  const rows = Array.isArray(answer.body.rows) ? answer.body.rows : [];
  ended = !answer.body.more || !rows.length;
  followBefore = rows.length ? rows[rows.length - 1].at : null;
  // Their own posts come too (supabase/feed_self.sql); with nobody else's
  // among them, the tab still says how to fill it.
  if (!before) followOthers = rows.some((row) => row?.mine !== true);
  // A model shared and then given a new version is one post, its newest.
  const seen = before ? shownKeys() : new Set();
  return rows.map(feedItem).filter((item) => {
    if (!item || seen.has(keyOf(item))) return false;
    seen.add(keyOf(item));
    return true;
  });
}

/// Show more: what was asked and not shown yet, then the lists' next page,
/// mixed as the first was.
async function showMore() {
  if (waiting.length) {
    putIn();
    return;
  }
  if (ended) {
    more.hidden = true;
    return;
  }
  const mine = run;
  more.setAttribute("aria-busy", "true");
  if (tab === "following") {
    waiting = (await following(mine, followBefore)) || [];
    more.removeAttribute("aria-busy");
    if (mine !== run) return;
    if (waiting.length) putIn();
    more.hidden = waiting.length === 0 && ended;
    return;
  }
  page += 1;
  const got = await answers(feeds(tab, page));
  more.removeAttribute("aria-busy");
  if (mine !== run) return;
  ended = !(got.top?.more || got.newest?.more);
  waiting = compose(got, { tab, skip: shownKeys() });
  if (!waiting.length) {
    ended = true;
    more.hidden = true;
    return;
  }
  putIn();
}

/// [chosen] shown: its tab pressed, and the stream drawn for it.
function choose(chosen, { focus = false } = {}) {
  for (const one of tabs) {
    const on = one === chosen;
    one.setAttribute("aria-selected", String(on));
    one.tabIndex = on ? 0 : -1;
  }
  if (focus) chosen.focus();
  tab = chosen.dataset.tab;
  stream.innerHTML = Array.from({ length: 3 }, postSkeletonHtml).join("");
  draw();
}

if (stream) {
  tabList?.addEventListener("click", (event) => {
    const one = event.target instanceof Element ? event.target.closest('[role="tab"]') : null;
    if (one && one.getAttribute("aria-selected") !== "true") choose(one);
  });
  // The arrows, Home and End move along the tabs, and show each.
  tabList?.addEventListener("keydown", (event) => {
    const at = tabs.indexOf(document.activeElement);
    if (at < 0) return;
    const to = { ArrowRight: at + 1, ArrowLeft: at - 1, Home: 0, End: tabs.length - 1 }[event.key];
    if (to === undefined) return;
    event.preventDefault();
    choose(tabs[(to + tabs.length) % tabs.length], { focus: true });
  });
  more.addEventListener("click", () => showMore());
  // The page's own posts first: asked again once the page is in and idle.
  const again = () => draw({ first: true });
  if (served) (window.requestIdleCallback || ((work) => setTimeout(work, 200)))(again, { timeout: 3000 });
  else again();
  // Signed in or out, here or in another part of the page: drawn for them.
  addEventListener("brickworks:signed-in", () => {
    // The visitor's band gives way to the search row (318 px to 76 at
    // 1280): the post somebody signed in from, liked or commented on, kept
    // where it is on the screen, not 242 px up and off it (checkdrift,
    // 2026-11-23). With the dialog over the page, the browser's own
    // anchoring does not hold it.
    const held = [...stream.querySelectorAll(":scope > .post")].find((post) => post.getBoundingClientRect().bottom > 0);
    const was = held?.getBoundingClientRect().top;
    html.dataset.signed = "in";
    if (held && held.isConnected) scrollBy(0, held.getBoundingClientRect().top - was);
    signedInDraw = draw({ kept: tab === "foryou" }).catch(() => null);
  });
  addEventListener("brickworks:signed-out", () => {
    delete html.dataset.signed;
    if (tab !== "foryou" && tabs[0]) choose(tabs[0]);
    else draw();
  });
}

// --- in each post -----------------------------------------------------------

/// [button], a post's like, drawn as [liked] with [likes].
function drawLike(button, liked, likes, name) {
  const made = document.createElement("template");
  made.innerHTML = iconButtonHtml({ icon: "like", name: likeName(name), count: likes, one: "like", pressed: liked, small: true });
  const fresh = made.content.firstElementChild;
  button.setAttribute("aria-pressed", fresh.getAttribute("aria-pressed"));
  button.setAttribute("aria-label", fresh.getAttribute("aria-label"));
  button.replaceChildren(...fresh.childNodes);
}

const nameOf = (post) => post?.querySelector(".post-title a")?.textContent || "";

/// A like from a post: counted at once, then as the server counts it; a
/// visitor is asked to sign in first, there and then.
async function like(button) {
  const id = button.dataset.like;
  if (!MODEL.test(id)) return;
  if (!signedIn()) {
    if (!(await askToSignIn("Sign in to like it: we email you a code, no password."))) return;
    // Signed in, the stream is drawn again as them: the like goes on the
    // post as drawn then, or a draw answered before it would take it off
    // the screen (checkdrift, 2026-11-23, once First steps stopped holding
    // it back); and liked before, it stays liked, not taken back.
    await signedInDraw;
    button = stream.querySelector(`[data-like="${id}"]`) || button;
    if (button.getAttribute("aria-pressed") === "true") return;
  }
  const name = nameOf(button.closest(".post"));
  const was = button.getAttribute("aria-pressed") === "true";
  const count = Number(button.querySelector(".n")?.textContent.replace(/\D/g, "")) || 0;
  const all = [...stream.querySelectorAll(`[data-like="${id}"]`)];
  for (const one of all) drawLike(one, !was, Math.max(0, count + (was ? -1 : 1)), name);
  // Every post of the model waits on the one answer: a press on its other
  // post while it goes would send the other way, the answers in any order.
  for (const one of all) one.disabled = true;
  const answer = await call(`/api/people?op=like&id=${id}`, { method: "POST", body: { on: !was } }).catch(() => ({ status: 0, body: {} }));
  for (const one of all) one.disabled = false;
  if (answer.status === 200) {
    for (const one of all) drawLike(one, answer.body.liked === true, Number(answer.body.likes) || 0, name);
    return;
  }
  for (const one of all) drawLike(one, was, count, name);
  toast(told(answer.body?.error, say("That did not work just now. Try again.")));
}

/// The link to [id]'s page, shared with the device's own share where it has
/// one, else copied.
async function share(button) {
  const id = button.dataset.share;
  if (!MODEL.test(id)) return;
  const url = `${location.origin}${langAt()}/m/${id}`;
  const name = button.dataset.name || nameOf(button.closest(".post"));
  if (navigator.share) {
    try {
      await navigator.share({ title: name, url });
      return;
    } catch (trouble) {
      if (trouble?.name === "AbortError") return;
    }
  }
  try {
    await navigator.clipboard.writeText(url);
    toast(say("Link copied"));
  } catch {
    toast(url);
  }
}

/// What a post's comment and reply buttons open: the composer in the post
/// (web/composer.js), the same as under a row of Talk and on the full pages.
function talkIn(pressed) {
  const post = pressed.closest(".post");
  if (!post) return;
  if (pressed.matches("[data-reply-thread]")) {
    const lang = langAt() ? langAt().slice(1) : "";
    replyInCard(post, Number(pressed.dataset.replyThread), { opener: pressed, tests: TESTS, lang });
  } else if (pressed.matches("[data-more]") && MODEL.test(pressed.dataset.more)) {
    commentsInCard(post, pressed.dataset.more, { all: true, tests: TESTS });
  } else if (MODEL.test(pressed.dataset.say)) {
    commentsInCard(post, pressed.dataset.say, { opener: pressed, tests: TESTS });
  }
}

// The people the stream's Follow buttons follow, each asked once: a page of
// posts by one builder asks about them once, not once a post.
const follows = new Map();
let followModule = null;

/// Each Follow of [posts] made live (web/follow.js followButton), drawn as
/// the server has it for whoever is signed in; signed out, Follow, which
/// asks them to sign in on the spot.
async function liven(posts) {
  const buttons = posts.flatMap((post) => [...post.querySelectorAll("button[data-follow]")]).filter((one) => !one.dataset.live);
  if (!buttons.length) return;
  followModule ||= import("/follow.js");
  const { followButton } = await followModule;
  for (const button of buttons) {
    const handle = button.dataset.follow;
    if (!HANDLE.test(handle)) continue;
    button.dataset.live = "yes";
    if (!signedIn()) {
      followButton(button, { you_follow: false, mine: false, signed_in: false, may: true, why_not: "" });
      continue;
    }
    if (!follows.has(handle)) follows.set(handle, ask(`/api/people?op=follows&handle=${encodeURIComponent(handle)}`, { mine: true }));
    follows.get(handle).then((state) => (state && state.ready ? followButton(button, state) : followButton(button)));
  }
}

// --- the model in 3D, in its picture's place --------------------------------

let turning = null;
let styled = false;

/// [post]'s model turned in 3D over its picture (web/viewer3d.js, three.js
/// and all, asked for only now; its looks web/view3d.css), turning on its
/// own until taken hold of. [how] what asked: "hover" closes it again when
/// the pointer leaves.
function turn(post, how) {
  const pic = post.querySelector(".post-pic");
  const link = pic?.querySelector("a.pic");
  if (!link || !link.dataset.scene) return;
  if (turning?.post === post) return;
  closeTurn();
  if (!styled) {
    styled = true;
    const sheet = document.createElement("link");
    sheet.rel = "stylesheet";
    sheet.href = "/view3d.css";
    document.head.append(sheet);
  }
  pic.classList.add("showcase");
  const name = nameOf(post) || say("The model");
  const shell = document.createElement("div");
  shell.className = "view3d";
  shell.dataset.state = "loading";
  shell.dataset.how = how === "hover" ? "mouse" : how;
  shell.setAttribute("aria-busy", "true");
  shell.innerHTML = '<div class="stage" tabindex="0" role="application"></div>'
    + '<div class="view3d-bar" aria-hidden="true"><span></span></div><p class="view3d-said" role="status"></p>';
  shell.querySelector(".stage").setAttribute("aria-roledescription", say("3D view"));
  shell.querySelector(".stage").setAttribute("aria-label", say("{name} in 3D", { name }));
  shell.querySelector(".view3d-said").textContent = say("Getting the model in 3D…");
  pic.append(shell);
  const button = pic.querySelector("[data-turn]");
  button?.setAttribute("aria-pressed", "true");
  const asked = Math.round(performance.now());
  const id = post.dataset.id;
  const view = import("/viewer3d.js")
    .then((made) => made.open3d(shell, { scene: link.dataset.scene, name, app: appAt(`view=${id}`), how: how === "hover" ? "mouse" : how,
      look: "app", spin: true, timings: { asked }, closed: () => { if (turning?.shell === shell) closeTurn(); } }))
    .catch(() => {
      shell.dataset.state = "failed";
      shell.querySelector(".view3d-said").textContent = say("The 3D view could not load. The picture is still here; try again in a moment.");
      setTimeout(() => { if (turning?.shell === shell) closeTurn(); }, 4000);
      return null;
    });
  turning = { post, shell, view, how };
  html.dataset.feedTurn = id;
}

function closeTurn() {
  if (!turning) return;
  const { post, shell, view } = turning;
  turning = null;
  view.then((one) => one && one.close()).catch(() => null);
  shell.remove();
  post.querySelector("[data-turn]")?.setAttribute("aria-pressed", "false");
  delete html.dataset.feedTurn;
}

// A pointer resting on a picture for a moment turns it; leaving puts the
// picture back. A finger taps 3D. Somebody who asked for less motion is
// never shown it unasked.
const stillPlease = matchMedia("(prefers-reduced-motion: reduce)").matches;
const finePointer = matchMedia("(hover: hover) and (pointer: fine)").matches;
let resting = null;
if (stream && finePointer && !stillPlease) {
  stream.addEventListener("pointerover", (event) => {
    const pic = event.target instanceof Element ? event.target.closest(".post.build .post-pic") : null;
    if (!pic || event.pointerType !== "mouse") return;
    const post = pic.closest(".post");
    if (turning?.post === post) return;
    clearTimeout(resting);
    resting = setTimeout(() => turn(post, "hover"), 700);
  });
  stream.addEventListener("pointerout", (event) => {
    const pic = event.target instanceof Element ? event.target.closest(".post.build .post-pic") : null;
    if (!pic || (event.relatedTarget instanceof Node && pic.contains(event.relatedTarget))) return;
    clearTimeout(resting);
    if (turning?.post === pic.closest(".post") && turning.how === "hover") closeTurn();
  });
}

// --- the studio, in the feed ------------------------------------------------

/// The studio itself in [post]'s picture's place, on the visitor's tap: the
/// app at /app?view=<id>, the model to turn, play with and build step by
/// step; its Open in Brickworks, and the post's Open the whole studio, take
/// the whole window to the studio with it (/app?copy=<id>). Nothing of the
/// app is asked for before the tap. The page is not cross-origin isolated
/// (its sign-in popups), so the studio here starts the engine without
/// threads (src/boot/shell.html), which deploy.sh frames for the site's own
/// pages only.
function tryHere(button) {
  const post = button.closest(".post");
  const stage = post?.querySelector("[data-try-stage]");
  const id = button.dataset.try;
  if (!stage || !MODEL.test(id) || stage.querySelector("iframe")) return;
  stage.dataset.state = "loading";
  const said = document.createElement("p");
  said.className = "try-said";
  said.setAttribute("role", "status");
  said.textContent = say("Opening the studio…");
  const frame = document.createElement("iframe");
  frame.title = say("The Brickworks studio, with {name}", { name: nameOf(post) || say("a model") });
  frame.src = appAt(`view=${id}`);
  frame.allow = "fullscreen; clipboard-write";
  frame.setAttribute("allowfullscreen", "");
  // The studio's ways out (Open in Brickworks, the newest version) take the
  // whole window (src/main.gd WHOLE_WINDOW), not this frame.
  frame.addEventListener("load", () => {
    stage.dataset.state = "ready";
    html.dataset.feedTry = "open";
  }, { once: true });
  stage.append(frame, said);
  html.dataset.feedTry = "loading";
}

if (stream) {
  stream.addEventListener("click", (event) => {
    const at = event.target instanceof Element ? event.target : null;
    const pressed = at?.closest("[data-like], [data-say], [data-more], [data-reply-thread], [data-share], [data-turn], [data-try]");
    if (!pressed || pressed.disabled) return;
    // A new tab or window asked for (a middle press, Ctrl): the thread's own page.
    if (pressed.matches("a[data-reply-thread]") && (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0)) return;
    event.preventDefault();
    if (pressed.matches("[data-like]")) like(pressed);
    else if (pressed.matches("[data-say], [data-more], [data-reply-thread]")) talkIn(pressed);
    else if (pressed.matches("[data-share]")) share(pressed);
    else if (pressed.matches("[data-turn]")) {
      const post = pressed.closest(".post");
      if (turning?.post === post) closeTurn();
      else turn(post, event.detail === 0 ? "key" : event.pointerType || "touch");
    } else if (pressed.matches("[data-try]")) tryHere(pressed);
  });
  addEventListener("keydown", (event) => {
    if (event.key === "Escape" && turning) closeTurn();
  });
}

// ---------------------------------------------------------------------------
// The search: "/" puts the cursor in it, as in the gallery; its suggestions
// once it is used.

const find = document.getElementById("find");
const findField = document.getElementById("find-q");
if (find && findField) {
  let started = null;
  const start = () => {
    started ||= import("/home-find.js").then(({ findAsYouType }) => findAsYouType(find, findField)).catch(() => null);
  };
  findField.addEventListener("focus", start, { once: true });
  findField.addEventListener("pointerdown", start, { once: true });
  addEventListener("keydown", (event) => {
    if (event.key !== "/" || event.ctrlKey || event.metaKey || event.altKey) return;
    const at = event.target instanceof Element ? event.target : null;
    if (at && at.closest("input, textarea, select, [contenteditable], dialog[open]")) return;
    event.preventDefault();
    findField.focus();
  });
}

// ---------------------------------------------------------------------------
// The challenge.

/// "1–30 November" in the page's language.
function days(from, to) {
  const at = (day) => new Date(`${day}T12:00:00Z`);
  const locale = globalThis.brickworksLang?.locale || "en-GB";
  try {
    return new Intl.DateTimeFormat(locale === "en-US" ? "en-GB" : locale, { day: "numeric", month: "long", timeZone: "UTC" })
      .formatRange(at(from), at(to));
  } catch {
    return "";
  }
}

const DAY_MS = 86400000;
/// Whole days from now to the end of [day] (UTC, the day counted), at least 1.
const daysTo = (day) => Math.max(1, Math.ceil((Date.parse(`${day}T00:00:00Z`) + DAY_MS - Date.now()) / DAY_MS));
/// "10 days left", "Last day": what is left of a stretch ending on [day].
const leftSaid = (day) => (daysTo(day) === 1 ? say("Last day") : say("{n} days left", { n: number(daysTo(day)) }));

/// The challenge open now as the home page says it: [badge, left, go], by
/// its round where it runs in rounds (entries, the judges choosing, the fan
/// vote), each with how long it has.
function standing(c) {
  const today = new Date().toISOString().slice(0, 10);
  if (c.entries_until && c.votes_from) {
    if (today <= c.entries_until) {
      return [say("Entries open"), daysTo(c.entries_until) === 1 ? say("Entries close today")
        : say("Entries close in {n} days", { n: number(daysTo(c.entries_until)) }), say("Enter the challenge")];
    }
    if (today >= c.votes_from && c.shortlisted) return [say("Fan vote"), leftSaid(c.ends_on), say("Vote for your favourite")];
    return [say("Judging"), say("The judges are choosing"), say("See the entries")];
  }
  return [say("This month"), leftSaid(c.ends_on), say("Enter the challenge")];
}

/// This month's challenge (GET /api/share?op=shelves, the gallery front's
/// own answer): its name, brief and days (in the page as served, said
/// again here in case it changed since), its days left, and the way in;
/// between challenges the next one told. Its name and brief are its
/// makers' words, as written. A test challenge is never shown here.
async function challenge() {
  const tile = document.getElementById("challenge");
  if (!tile) return;
  const answer = await shelves;
  // A tab pressed while this was asked drew the stream again and took this
  // post away: that draw says it again of its own post (sitewalk3,
  // 2026-11-26: New pressed as the home came threw "Cannot set properties
  // of null" here).
  if (!tile.isConnected) return;
  const part = (id) => tile.querySelector(`#${id}`);
  const c = answer?.challenge && !answer.challenge.test && ["open", "upcoming"].includes(answer.challenge.state) ? answer.challenge : null;
  html.dataset.challenge = c ? (c.state === "open" ? "open" : "next") : "none";
  if (!c) return;
  const open = c.state === "open";
  const [badge, left, go] = open ? standing(c) : [say("Coming next"), say("Opens {day}", { day: days(c.starts_on, c.starts_on) }), ""];
  part("challenge-when").textContent = badge;
  const leftBadge = part("challenge-left");
  leftBadge.textContent = left;
  leftBadge.hidden = false;
  const name = part("challenge-h");
  name.textContent = String(c.title || "");
  name.lang = "en";
  const brief = part("challenge-brief");
  if (c.brief) {
    brief.textContent = String(c.brief);
    brief.lang = "en";
  }
  // Its days in place of the line held for them, so nothing under it moves.
  const span = days(c.starts_on, c.ends_on);
  if (span) part("challenge-days").textContent = span;
  const link = part("challenge-go");
  if (go) link.textContent = go;
  if (c.id) link.href = `${langAt()}/challenge`;
}
// Once now for a post the page was served with, and again each time the
// stream is drawn (draw), which may put the challenge's post in.
challenge();

// ---------------------------------------------------------------------------
// Under the first screen.

/// [show] what goes in just above [place] once [place]'s top is out of the
/// window, under it or scrolled past, now or after a scroll, so what it puts
/// in moves nothing in view (docs/DESIGN_SYSTEM.md, Out of sight). Under the
/// window only, it never came on a screen tall enough to show [place] at the
/// top: at 1280 x 900 or 1920 x 1080 the band under the shelf stayed hidden
/// however far down a person read (landfix, 2026-11-22). Put in above, the
/// page is scrolled on by what came in, where the browser does not itself.
function whenOut(place, show) {
  const top = () => place.getBoundingClientRect().top;
  const now = () => {
    const before = place ? top() : innerHeight;
    if (before > 0 && before < innerHeight) return false;
    removeEventListener("scroll", now);
    show();
    if (before <= 0) {
      const moved = top() - before;
      if (moved) scrollBy(0, moved);
    }
    return true;
  };
  if (!now()) addEventListener("scroll", now, { passive: true });
}

/// Four real sets, each its picture and a link to its page; the tile's
/// glyph and words stay when they do not all come.
async function sets() {
  const row = document.getElementById("sets-models");
  if (!row) return;
  const listed = await ask("/api/share?op=library&page=1&sort=largest&model=3d");
  const models = (listed?.models || []).filter((m) => m && SET.test(String(m.id)) && m.library?.model3d && pictureOf(m));
  const links = models.slice(0, SETS).map((m) => {
    const link = document.createElement("a");
    const page = /^\/library\/set\/[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/.test(String(m.library.page || ""))
      ? `${langAt()}${m.library.page}` : `/library/${m.id}`;
    link.href = page;
    link.dataset.model3d = "yes";
    link.innerHTML = `<img src="${escapeHtml(pictureOf(m))}" alt="${escapeHtml(m.name)}" width="400" height="300" decoding="async">`;
    return link;
  });
  const done = (await Promise.all(links.map(async (link) => ((await drawn(link.querySelector("img"))) ? link : null))))
    .filter(Boolean);
  html.dataset.sets = done.length === SETS ? String(SETS) : "none";
  if (done.length === SETS) row.replaceChildren(...done);
}

/// The beta's section (#beta) as [heard] has it: the way in for whoever
/// reads it, and the line under it.
function drawBeta(heard) {
  const visitor = heard.tester ? "tester" : signedIn() ? "in" : "out";
  for (const row of document.querySelectorAll("#beta-acts > [data-visitor]")) row.hidden = row.dataset.visitor !== visitor;
  const said = document.getElementById("beta-said");
  said.textContent = heard.tester ? say("You’re a tester. Thank you: your reports and our answers are in your account.")
    : heard.left > 0 ? say("The first {cap} testers we approve get a month of Pro, free: {spots} left.",
      { cap: number(heard.cap), spots: counted(heard.left, "spot") }) : "";
  html.dataset.betaHome = visitor;
}

// The beta's own script (web/betabar.js), asked for only while the beta
// may be open: web/theme.js says when this browser heard it off in the
// last ten minutes (window.brickworksBeta), and then nothing is.
const bar = () => import("/betabar.js");

/// The beta's section, while it is open (web/betabar.js). Held since the
/// first frame where this browser had heard so (<html data-beta>,
/// web/theme.js); else put in only while its place is under the window, or
/// once it is again, so nothing in view moves. Off, it is not drawn; not
/// heard, a held one stays as it was.
async function beta() {
  const band = document.getElementById("beta");
  if (!band) return;
  if (window.brickworksBeta === "off") {
    html.dataset.betaHome = "off";
    return;
  }
  const held = html.dataset.beta === "open";
  const heard = await (await bar()).betaState();
  if (heard.beta === "off") {
    html.dataset.betaHome = "off";
    return;
  }
  if (heard.beta !== "open") {
    if (held) drawBeta(heard);
    return;
  }
  drawBeta(heard);
  if (held) return;
  whenOut(band.nextElementSibling, () => { html.dataset.beta = "open"; });
}

document.getElementById("beta")?.addEventListener("click", async (event) => {
  const pressed = event.target instanceof Element ? event.target.closest("[data-beta-join], [data-beta-report]") : null;
  if (!pressed) return;
  if (pressed.matches("[data-beta-report]")) {
    (await bar()).reportBug("home");
    return;
  }
  pressed.disabled = true;
  try {
    const now = await (await bar()).joinBeta("home");
    if (now?.tester) toast(say("You’re a tester. Thank you!"));
  } catch (trouble) {
    toast(trouble.message);
  } finally {
    pressed.disabled = false;
  }
});
// Joined, signed in or out here or in another part of the page.
const again = (fresh) => bar().then((one) => one.betaState({ fresh })).then((heard) => heard.beta === "open" && drawBeta(heard));
addEventListener("brickworks:beta", () => again(false));
addEventListener("brickworks:signed-in", () => again(true));
beta();

/// [work] once [id] is [margin] from the window: a screen and a half, or in it.
function near(id, work, margin = "150% 0px") {
  const where = document.getElementById(id);
  if (!where) return;
  if (!("IntersectionObserver" in window)) {
    work();
    return;
  }
  const watch = new IntersectionObserver((seen) => {
    if (!seen.some((one) => one.isIntersecting)) return;
    watch.disconnect();
    work();
  }, { rootMargin: margin });
  watch.observe(where);
}

// The sets' own tile, not the section it ends: the shorter home page has
// #why within a screen and a half of the top, so its four pictures (139 KB
// with their list) came with the first screen, which shows none of them.
near("sets", sets);

// --- the hero: the studio at work --------------------------------------------

// The loop of the real studio over its poster (herostudio, 2026-11-26;
// tools/site/hero_capture.py makes both): asked for only once the page is in
// (its load), the browser idle and the loop in view, so its bytes never
// compete with the first screen's. The desktop's cut, or under 600 px the
// phone's, as the poster's <source> picks; AV1 where the browser plays it,
// else H.264. Muted, looping, inline, never with controls; the poster stays
// for someone who asked for less motion or to save data, and wherever the
// browser will not play it (it fades in only once it plays, so nothing
// moves). Its captions follow the loop (#hero-loop's data-cues-*), and
// Pause stops it and its captions until Play. Signed in, the band is not
// shown and none of it is asked for. <html data-hero>: what it came to
// (poster, still, loading, playing, paused, kept-failed), which
// tools/web/hero_check.mjs reads.
const heroLoop = document.getElementById("hero-loop");
const PHONE_CUT = matchMedia("(width < 600px)");
const CUE_WORDS = {
  drop: () => say("Drop a brick on the studs"),
  steps: () => say("Follow the steps"),
  render: () => say("Render it like a photo"),
};
function loopCan() {
  return !matchMedia("(prefers-reduced-motion: reduce)").matches && !navigator.connection?.saveData;
}
/// [seconds, [[from, word], ...]] from a data-cues-* value ("17.2;0:drop,5.1:steps").
function cuesOf(value) {
  const [seconds, words = ""] = String(value || "").split(";");
  const cues = words.split(",").filter(Boolean).map((cue) => cue.split(":")).map(([t, w]) => [Number(t), w])
    .filter(([t, w]) => Number.isFinite(t) && CUE_WORDS[w]);
  return [Number(seconds) || 0, cues];
}
function heroVideo() {
  const frame = heroLoop.querySelector(".loop-frame");
  const say1 = document.getElementById("loop-say");
  const stop = document.getElementById("loop-stop");
  const video = document.createElement("video");
  video.className = "loop-video";
  video.muted = true;
  video.defaultMuted = true;
  video.loop = true;
  video.playsInline = true;
  video.autoplay = true;
  video.preload = "auto";
  video.disablePictureInPicture = true;
  video.setAttribute("muted", "");
  video.setAttribute("playsinline", "");
  video.setAttribute("aria-hidden", "true");
  video.tabIndex = -1;
  let cut = "";
  let cues = [0, []];
  const pick = () => {
    const now = PHONE_CUT.matches ? "phone" : "desktop";
    if (now === cut) return;
    cut = now;
    cues = cuesOf(heroLoop.dataset[now === "phone" ? "cuesPhone" : "cuesDesktop"]);
    const av1 = video.canPlayType('video/mp4; codecs="av01.0.08M.08"');
    video.src = `/img/hero/studio-${cut}.${av1 ? "av1" : "h264"}.mp4`;
    video.dataset.cut = cut;
    if (!stop.hidden && stop.getAttribute("aria-pressed") === "true") return;
    video.play().catch(() => {});
  };
  // The caption of the moment: shown, changed, a little after each cue.
  let said = "";
  const caption = () => {
    const at = video.currentTime;
    let word = "";
    for (const [from, w] of cues[1]) if (at >= from) word = w;
    if (word === said) return;
    said = word;
    say1.classList.remove("shown");
    setTimeout(() => {
      if (said !== word) return;
      say1.textContent = word ? CUE_WORDS[word]() : "";
      say1.classList.toggle("shown", Boolean(word));
    }, 160);
  };
  video.addEventListener("timeupdate", caption);
  video.addEventListener("playing", () => {
    heroLoop.classList.add("live");
    stop.hidden = false;
    html.dataset.hero = "playing";
  });
  // A browser that said it plays AV1 and then cannot (no decoder after all)
  // is given the H.264 cut; one that plays neither keeps the poster.
  video.addEventListener("error", () => {
    if (video.src.endsWith(".av1.mp4")) {
      video.src = `/img/hero/studio-${cut}.h264.mp4`;
      video.play().catch(() => {});
      return;
    }
    html.dataset.hero = "kept-failed";
    heroLoop.classList.remove("live");
    video.remove();
  });
  // Signed in, the band is the search alone: the loop is not shown, so it stops.
  addEventListener("brickworks:signed-in", () => video.pause());
  addEventListener("brickworks:signed-out", () => {
    if (stop.getAttribute("aria-pressed") !== "true") video.play().catch(() => {});
  });
  stop.addEventListener("click", () => {
    const paused = stop.getAttribute("aria-pressed") !== "true";
    stop.setAttribute("aria-pressed", String(paused));
    if (paused) { video.pause(); html.dataset.hero = "paused"; } else video.play().catch(() => {});
  });
  PHONE_CUT.addEventListener("change", pick);
  frame.insertBefore(video, say1);
  pick();
}
function hero() {
  if (!heroLoop || heroLoop.offsetParent === null) return;
  if (!loopCan()) { html.dataset.hero = "still"; return; }
  html.dataset.hero = "loading";
  try { heroVideo(); } catch { html.dataset.hero = "kept-failed"; }
}
if (heroLoop) {
  html.dataset.hero = "poster";
  const idle = window.requestIdleCallback || ((work) => setTimeout(work, 300));
  const whenIn = () => idle(() => near("hero-loop", hero, "0px"), { timeout: 2500 });
  if (document.readyState === "complete") whenIn();
  else addEventListener("load", whenIn, { once: true });
}

// --- the studio, fetched ahead -------------------------------------------------
//
// Start building leads to the studio, whose start waits for its engine and
// its first pack before anything of it can run: 9.7 MB, 5.3 s of a desktop's
// first visit on broadband (webstart14, 2026-11-27, against live's preview).
// Fetched here once the page is in and the browser idle, they come from the
// browser's own cache when the visitor goes on, as on a return: the studio's
// page asks for those very addresses (the engine at its own /e/<hash>/, the
// pack under the release's /b/<sha>/, both kept for good), and this reads
// them from /app's own GODOT_CONFIG, so it never asks for other bytes. The
// data pack and the rest of the parts are not: they come while the studio's
// scripts compile, on a connection that can bring these.
//
// Not where it costs a visitor who never goes on: a connection that asks to
// save data or reads as slow, and a window a phone's width where the browser
// cannot say (WebKit has no navigator.connection), nor an iPhone or iPad,
// whose engine is the owner's switch's to choose (shell.html). As the
// browser's own prefetches, after the hero's loop has had its turn: at the
// lowest priority, and on through a click on Start building, where a fetch
// of this page's own was cut off with the page and the studio began again.
// <html data-studio-ahead>: skipped, fetching, fetched or failed.
const AHEAD_AFTER_MS = 3000;
function aheadSkipped() {
  const line = navigator.connection;
  if (line?.saveData) return "save-data";
  if (line && /(^|-)2g$|^3g$/.test(String(line.effectiveType || ""))) return "slow";
  if (!line && PHONE_CUT.matches) return "phone";
  const agent = navigator.userAgent || "";
  if (/iPhone|iPad|iPod/.test(agent) || (/Macintosh/.test(agent) && navigator.maxTouchPoints > 1)) return "apple";
  return "";
}
async function studioAhead() {
  const why = aheadSkipped();
  if (why) {
    html.dataset.studioAhead = `skipped ${why}`;
    return;
  }
  html.dataset.studioAhead = "fetching";
  try {
    const page = await fetch("/app", { credentials: "same-origin" }).then((answer) => (answer.ok ? answer.text() : ""));
    const found = /const GODOT_CONFIG = (\{[^\n]*\});/.exec(page);
    const config = found ? JSON.parse(found[1]) : null;
    const engine = typeof config?.engine === "string" ? config.engine : "";
    const build = typeof config?.executable === "string" ? config.executable : "";
    if (!engine.startsWith("/e/") || !build.startsWith("/b/")) {
      html.dataset.studioAhead = "skipped unplaced";
      return;
    }
    await Promise.all([`${engine}.js`, `${build}.pck`, `${engine}.wasm`].map((address) => new Promise((done, failed) => {
      const ahead = document.createElement("link");
      ahead.rel = "prefetch";
      ahead.href = address;
      ahead.onload = done;
      ahead.onerror = () => failed(new Error(address));
      document.head.append(ahead);
    })));
    html.dataset.studioAhead = "fetched";
  } catch {
    html.dataset.studioAhead = "failed";
  }
}
{
  const idle = window.requestIdleCallback || ((work) => setTimeout(work, 300));
  const whenIn = () => setTimeout(() => idle(studioAhead, { timeout: 4000 }), AHEAD_AFTER_MS);
  if (document.readyState === "complete") whenIn();
  else addEventListener("load", whenIn, { once: true });
}
