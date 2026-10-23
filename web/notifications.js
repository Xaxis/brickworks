// /notifications (2026-10-22, docs/SOCIAL.md U7, supabase/notifications.sql):
// what happened to your models, from /api/people?op=notifications, one
// group a model with its picture, the newest group first: comments, photos
// of builds, remixes, likes as a number a day (never who), a challenge's
// end. Opening the page clears the count on your avatar (the server marks
// it seen). A group stays marked unread until it is opened, by any of its
// links, or Mark all read.
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

/// Its model's group opened: read up to now, here at once and on the
/// server, which a link followed straight away does not wait for.
async function read(group) {
  if (!group.classList.contains("unread")) return;
  group.classList.remove("unread");
  group.querySelector(".dot")?.remove();
  for (const line of group.querySelectorAll(".unread")) line.classList.remove("unread");
  const access = await token().catch(() => null);
  if (!access) return;
  fetch("/api/people?op=notifications_read", { method: "POST", keepalive: true,
    headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
    body: JSON.stringify({ model: group.dataset.model }) }).catch(() => null);
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
  else link.append(parsed(iconHtml(one.kind === "result" ? "award" : one.kind === "likes" ? "like" : "comment")));
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

function group(one) {
  const item = document.createElement("li");
  item.className = `notice${one.unread ? " unread" : ""}`;
  item.dataset.model = String(one.model || "");
  const picture = document.createElement("a");
  picture.className = "pic";
  picture.href = here(one.link);
  picture.tabIndex = -1;
  picture.setAttribute("aria-hidden", "true");
  if (one.picture) {
    const img = document.createElement("img");
    img.src = here(one.picture);
    img.alt = "";
    img.loading = "lazy";
    img.decoding = "async";
    picture.append(img);
  }
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

async function load() {
  $("loading").hidden = true;
  if (!signedIn()) {
    $("signed-out").hidden = false;
    $("signed-in").hidden = true;
    document.documentElement.dataset.notifications = "signed-out";
    return;
  }
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  const answer = await call("/api/people?op=notifications");
  if (answer.status === 401) {
    signOut();
    return load();
  }
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
  allRead();
  showTabCounts(await showFeedCount().catch(() => null));
});
// Back to the list from a model: what was opened is shown read.
addEventListener("pageshow", (event) => {
  if (event.persisted) load();
});

load();
