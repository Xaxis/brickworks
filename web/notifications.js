// /notifications (2026-10-22, docs/SOCIAL.md U7, supabase/notifications.sql):
// what happened to your models, from /api/people?op=notifications, one
// group a model with its picture, the newest group first: comments, photos
// of builds, remixes, likes as a number a day (never who), a challenge's
// end; each level of an achievement you reached, in a group of their own
// with the award in the picture's place, its link your profile's
// Achievements tab; and a challenge opening, its last two days and who won
// it, a group a challenge with a brick in the picture's place, its link
// the challenge's page; and what the site's owner announced, a group each
// (supabase/announce.sql), its link counted when followed. Each group is
// drawn by web/notice-view.js. Opening the page clears the count on your avatar (the
// server marks it seen). A group stays marked unread until it is opened,
// by any of its links, or Mark all read.
//
// Every word is put on the page as text; an avatar is the kit's, which
// escapes its own.
import { askToSignIn, call, signOut, signedIn, token } from "/account.js";
import { showFeedCount, showTabCounts } from "/follow.js";
import { say, told } from "/card.js";
import { group } from "/notice-view.js";

const $ = (id) => document.getElementById(id);
// The language the server says each line in (?lang=, api/_notifications.js
// noticeSaid).
const LANG = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? `&lang=${globalThis.brickworksLang.code}` : "";

/// Its model's group (or the achievements', a challenge's or an announcement's) opened: read up to now, here at
/// once and on the server, which a link followed straight away does not
/// wait for.
async function read(group, clicked = false) {
  // An announcement's own link followed is counted once (a click), read or not.
  const telling = "announcement" in group.dataset;
  const counted = telling && clicked && !("clicked" in group.dataset);
  if (!group.classList.contains("unread") && !counted) return;
  if (counted) group.dataset.clicked = "";
  group.classList.remove("unread");
  group.querySelector(".dot")?.remove();
  for (const line of group.querySelectorAll(".unread")) line.classList.remove("unread");
  const access = await token().catch(() => null);
  if (!access) return;
  fetch("/api/people?op=notifications_read", { method: "POST", keepalive: true,
    headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
    body: JSON.stringify("achievements" in group.dataset ? { achievements: true }
      : telling ? { announcement: Number(group.dataset.announcement), ...(counted ? { clicked: true } : {}) }
      : group.dataset.challenge ? { challenge: Number(group.dataset.challenge) }
      : group.dataset.talk ? { talk: Number(group.dataset.talk) } : { model: group.dataset.model }) })
    .catch(() => null);
  allRead();
}

function allRead() {
  const left = document.querySelectorAll("#groups .notice.unread").length;
  $("all-read").hidden = left === 0;
}

/// [one] group drawn, its links reading it as they are followed.
function groupOf(one, i = 0) {
  const item = group(one, i);
  const opened = (event) => {
    const link = event.target.closest("a");
    if (link) read(item, item.dataset.own !== undefined && link.getAttribute("href") === item.dataset.own);
  };
  item.addEventListener("click", opened);
  item.addEventListener("auxclick", opened);
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
  const answer = await call(`/api/people?op=notifications${LANG}`);
  if (answer.status === 401) {
    signOut();
    return load();
  }
  $("loading").hidden = true;
  $("signed-in").hidden = false;
  if (answer.status !== 200) {
    $("said").textContent = told(answer.body.error, say("Brickworks could not show your notifications just now. Try again in a minute."));
    document.documentElement.dataset.notifications = "failed";
    return;
  }
  const groups = Array.isArray(answer.body.groups) ? answer.body.groups : [];
  $("groups").replaceChildren(...groups.map(groupOf));
  $("empty").hidden = groups.length > 0 || answer.body.ready === false;
  $("not-yet").hidden = answer.body.ready !== false;
  allRead();
  // Opened: the count on the avatar is what is left, the feed's.
  showTabCounts(await showFeedCount().catch(() => null));
  document.documentElement.dataset.notifications = "ready";
}

$("sign-in").addEventListener("click", () => askToSignIn());
// Signed in by any dialog on this page (its own Sign in, the header's):
// drawn for them, where they are (signinux, 2026-11-13).
addEventListener("brickworks:signed-in-done", () => {
  if (document.documentElement.dataset.notifications === "signed-out") load();
});
$("all-read").addEventListener("click", async () => {
  const focused = document.activeElement === $("all-read");
  $("all-read").disabled = true;
  const answer = await call("/api/people?op=notifications_read", { method: "POST", body: { all: true } }).catch(() => null);
  $("all-read").disabled = false;
  if (!answer || answer.status !== 200) {
    $("said").textContent = told(answer?.body?.error, say("That did not work just now. Try again in a minute."));
    return;
  }
  for (const one of document.querySelectorAll("#groups .notice.unread")) {
    one.classList.remove("unread");
    one.querySelector(".dot")?.remove();
    for (const row of one.querySelectorAll(".unread")) row.classList.remove("unread");
  }
  // The button goes with what it did: said, and the keyboard's focus on
  // the page's title rather than lost with it.
  const title = document.querySelector(".page-head h1");
  if (title && focused) {
    title.tabIndex = -1;
    title.focus();
  }
  allRead();
  $("said").textContent = say("All read.");
  showTabCounts(await showFeedCount().catch(() => null));
});
// Back to the list from a model: what was opened is shown read.
addEventListener("pageshow", (event) => {
  if (event.persisted) load();
});

load();
