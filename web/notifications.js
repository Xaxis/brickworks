// /notifications (2026-10-22, docs/SOCIAL.md U7, supabase/notifications.sql):
// what happened to your models, from /api/people?op=notifications, one
// group a model with its picture, the newest group first: comments, photos
// of builds, remixes, likes as a number a day (never who), a challenge's
// end; each level of an achievement you reached, in a group of their own
// with the award in the picture's place, its link your profile's
// Achievements tab; and a challenge opening, its last two days and who won
// it, a group a challenge with a brick in the picture's place, its link
// the challenge's page. Opening the page clears the count on your avatar (the
// server marks it seen). A group stays marked unread until it is opened,
// by any of its links, or Mark all read.
//
// Every word is put on the page as text; an avatar is the kit's, which
// escapes its own.
import { askToSignIn, call, signOut, signedIn, token } from "/account.js";
import { showFeedCount, showTabCounts } from "/follow.js";
import { ago, avatarHtml, iconHtml } from "/kit.js";

const $ = (id) => document.getElementById(id);

/// Only the site's own addresses: what the server made from ids.
function here(link) {
  try {
    const url = new URL(String(link || ""), location.origin);
    return url.origin === location.origin ? url.pathname + url.search + url.hash : "/notifications";
  } catch {
    return "/notifications";
  }
}

const parsed = (html) => {
  const made = document.createElement("template");
  made.innerHTML = html;
  return made.content.firstElementChild;
};

/// Its model's group (or the achievements', or a challenge's) opened: read up to now, here at
/// once and on the server, which a link followed straight away does not
/// wait for.
async function read(group) {
  if (!group.classList.contains("unread")) return;
  group.classList.remove("unread");
  group.querySelector(".dot")?.remove();
  for (const line of group.querySelectorAll(".unread")) line.classList.remove("unread");
  const access = await token().catch(() => null);
  if (!access) return;
  fetch("/api/people?op=notifications_read", { method: "POST", keepalive: true,
    headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
    body: JSON.stringify("achievements" in group.dataset ? { achievements: true }
      : group.dataset.challenge ? { challenge: Number(group.dataset.challenge) } : { model: group.dataset.model }) })
    .catch(() => null);
  allRead();
}

function allRead() {
  const left = document.querySelectorAll("#groups .notice.unread").length;
  $("all-read").hidden = left === 0;
}

function line(one) {
  const item = document.createElement("li");
  item.dataset.kind = String(one.kind || "");
  if (one.unread) item.classList.add("unread");
  const link = document.createElement("a");
  link.href = here(one.link);
  if (one.by && one.by.handle) {
    link.append(parsed(avatarHtml({ handle: one.by.handle, name: one.by.name, picture: one.by.picture }, { size: "small" })));
  }
  else link.append(parsed(iconHtml(["result", "achievement", "challenge_won"].includes(one.kind) ? "award"
    : ["challenge_open", "challenge_closing"].includes(one.kind) ? "build" : one.kind === "likes" ? "like" : "comment")));
  const words = document.createElement("span");
  words.className = "what";
  if (one.who) {
    const who = document.createElement("b");
    who.textContent = String(one.who);
    words.append(who, " ");
  }
  words.append(String(one.did || ""));
  if (one.new) {
    const tag = document.createElement("span");
    tag.className = "pill new";
    tag.textContent = "New";
    words.append(" ", tag);
  }
  if (one.said) {
    const said = document.createElement("q");
    said.textContent = String(one.said);
    words.append(said);
  }
  const at = document.createElement("time");
  at.dateTime = String(one.at || "");
  at.textContent = ago(one.at);
  words.append(at);
  link.append(words);
  item.append(link);
  return item;
}

function group(one, i = 0) {
  const item = document.createElement("li");
  item.className = `notice${one.unread ? " unread" : ""}`;
  item.dataset.model = String(one.model || "");
  if (one.achievements) item.dataset.achievements = "";
  if (one.challenge) item.dataset.challenge = String(Number(one.challenge) || "");
  const picture = document.createElement("a");
  picture.className = one.achievements ? "pic award" : one.challenge ? "pic challenge" : "pic";
  picture.href = here(one.link);
  picture.tabIndex = -1;
  picture.setAttribute("aria-hidden", "true");
  if (one.picture) {
    const img = document.createElement("img");
    img.src = here(one.picture);
    img.alt = "";
    img.width = 1200;
    img.height = 630;
    // The first screen's asked at once.
    img.loading = i < 4 ? "eager" : "lazy";
    img.decoding = "async";
    picture.append(img);
  }
  if (one.achievements) picture.append(parsed(iconHtml("award")));
  if (one.challenge) picture.append(parsed(iconHtml("build")));
  const body = document.createElement("div");
  body.className = "body";
  const title = document.createElement("h2");
  const name = document.createElement("a");
  name.href = here(one.link);
  name.textContent = String(one.name || "Your model");
  title.append(name);
  if (one.unread) {
    const dot = document.createElement("span");
    dot.className = "dot";
    dot.title = "Not opened yet";
    const words = document.createElement("span");
    words.className = "visually-hidden";
    words.textContent = "Not opened yet";
    dot.append(words);
    title.append(dot);
  }
  const lines = document.createElement("ul");
  lines.className = "lines";
  for (const row of one.rows || []) lines.append(line(row));
  body.append(title, lines);
  item.append(picture, body);
  item.addEventListener("click", (event) => {
    if (event.target.closest("a")) read(item);
  });
  item.addEventListener("auxclick", (event) => {
    if (event.target.closest("a")) read(item);
  });
  return item;
}

// Signed in, the skeleton (notifications.html #loading) holds the list's
// place while it is asked, and the list is drawn whole when it comes.
async function load() {
  if (!signedIn()) {
    $("loading").hidden = true;
    $("signed-out").hidden = false;
    $("signed-in").hidden = true;
    document.documentElement.dataset.notifications = "signed-out";
    return;
  }
  $("signed-out").hidden = true;
  const answer = await call("/api/people?op=notifications");
  if (answer.status === 401) {
    signOut();
    return load();
  }
  $("loading").hidden = true;
  $("signed-in").hidden = false;
  if (answer.status !== 200) {
    $("said").textContent = answer.body.error || "Brickworks could not show your notifications just now. Try again in a minute.";
    document.documentElement.dataset.notifications = "failed";
    return;
  }
  const groups = Array.isArray(answer.body.groups) ? answer.body.groups : [];
  $("groups").replaceChildren(...groups.map(group));
  $("empty").hidden = groups.length > 0 || answer.body.ready === false;
  $("not-yet").hidden = answer.body.ready !== false;
  allRead();
  // Opened: the count on the avatar is what is left, the feed's.
  showTabCounts(await showFeedCount().catch(() => null));
  document.documentElement.dataset.notifications = "ready";
}

$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn()) load();
});
$("all-read").addEventListener("click", async () => {
  const focused = document.activeElement === $("all-read");
  $("all-read").disabled = true;
  const answer = await call("/api/people?op=notifications_read", { method: "POST", body: { all: true } }).catch(() => null);
  $("all-read").disabled = false;
  if (!answer || answer.status !== 200) {
    $("said").textContent = answer?.body?.error || "That did not work just now. Try again in a minute.";
    return;
  }
  for (const one of document.querySelectorAll("#groups .notice.unread")) {
    one.classList.remove("unread");
    one.querySelector(".dot")?.remove();
    for (const row of one.querySelectorAll(".unread")) row.classList.remove("unread");
  }
  // The button goes with what it did: said, and the keyboard's focus on
  // the page's title rather than lost with it.
  const title = document.querySelector(".notices-head h1");
  if (title && focused) {
    title.tabIndex = -1;
    title.focus();
  }
  allRead();
  $("said").textContent = "All read.";
  showTabCounts(await showFeedCount().catch(() => null));
});
// Back to the list from a model: what was opened is shown read.
addEventListener("pageshow", (event) => {
  if (event.persisted) load();
});

load();
