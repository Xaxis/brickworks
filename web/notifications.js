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
// Done (inbox, 2026-11-23; supabase/notification_prefs.sql), as GitHub's
// inbox has it: a group's Done, or Mark all done, takes it out of the count
// and the list to the Done view (?view=done) until something new about it
// comes, with Undo in the toast; More › Mute this model stops everything
// about a model, here, by push and by email, until it is unmuted (here's
// Undo, the model's page, or Settings › Notifications).
//
// Every word is put on the page as text; an avatar is the kit's, which
// escapes its own.
import { askToSignIn, call, signOut, signedIn, token } from "/account.js";
import { showFeedCount, showTabCounts } from "/follow.js";
import { say, told } from "/card.js";
import { group } from "/notice-view.js";
import { iconButtonHtml, iconHtml, toast } from "/kit.js";

const $ = (id) => document.getElementById(id);
/// Which list is shown: the inbox, or what was marked done.
let view = new URLSearchParams(location.search).get("view") === "done" ? "done" : "inbox";
/// Whether this account can mark done and mute (the answer's chosen).
let choosing = false;
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
  $("all-read").hidden = left === 0 || view !== "inbox";
  $("all-done").hidden = !choosing || view !== "inbox" || !document.querySelector("#groups .notice");
  const none = !document.querySelector("#groups .notice");
  if (none && document.documentElement.dataset.notifications === "ready") {
    $("empty").hidden = view !== "inbox";
    $("empty-done").hidden = view !== "done";
  }
}

const parsed = (html) => {
  const made = document.createElement("template");
  made.innerHTML = html;
  return made.content.firstElementChild;
};

/// The count on the avatar and the tabs, asked again after a change.
const recount = async () => showTabCounts(await showFeedCount().catch(() => null));

/// [item] gone from the list, the keyboard's focus on the next group's
/// first control (or the previous, or the page's title) rather than lost.
function goneFrom(item) {
  const next = item.nextElementSibling || item.previousElementSibling;
  const into = next?.querySelector(".notice-top [data-done], .notice-top summary, h2 a") || document.querySelector(".notices-head h1");
  item.remove();
  if (into) {
    if (into.tagName === "H1") into.tabIndex = -1;
    into.focus({ preventScroll: false });
  }
  allRead();
}

/// POST op=notifications_done: [body] its {group | all, at, undo}.
const doneCall = (body) => call("/api/people?op=notifications_done", { method: "POST", body }).catch(() => null);

/// A group's own Done, and More with Mute this model (a model's group).
function actsOf(one, item) {
  if (!choosing) return null;
  const acts = document.createElement("div");
  acts.className = "acts";
  if (view === "inbox" && one.key && one.at) {
    const done = parsed(iconButtonHtml({ icon: "check", name: say("Done"), small: true, attrs: "data-done" }));
    done.title = say("Done: out of your count, into Done");
    done.addEventListener("click", async () => {
      done.disabled = true;
      const answer = await doneCall({ group: one.key, at: one.at });
      if (!answer || answer.status !== 200) {
        done.disabled = false;
        $("said").textContent = told(answer?.body?.error, say("That did not work just now. Try again in a minute."));
        return;
      }
      const before = answer.body.before ?? null;
      goneFrom(item);
      recount();
      toast(say("Done: {name}", { name: String(one.name || "") }), { action: { label: say("Undo"), run: async () => {
        const back = await doneCall({ group: one.key, at: before, undo: true });
        if (back && back.status === 200) load();
      } } });
    });
    acts.append(done);
  }
  if (one.model) {
    const more = document.createElement("details");
    more.className = "more-menu end";
    const summary = document.createElement("summary");
    summary.className = "icon-btn small";
    summary.setAttribute("aria-label", say("More"));
    summary.title = say("More");
    summary.append(parsed(iconHtml("more")));
    const list = document.createElement("div");
    list.className = "menu-list";
    const mute = document.createElement("button");
    mute.type = "button";
    mute.dataset.mute = one.model;
    mute.textContent = say("Mute this model");
    mute.addEventListener("click", async () => {
      more.open = false;
      const answer = await call("/api/people?op=notification_mute", { method: "POST", body: { model: one.model, on: true } })
        .catch(() => null);
      if (!answer || answer.status !== 200) {
        $("said").textContent = told(answer?.body?.error, say("That did not work just now. Try again in a minute."));
        return;
      }
      // Every group of it goes (a model has one), the count with them.
      for (const other of document.querySelectorAll("#groups .notice")) if (other !== item && other.dataset.model === one.model) other.remove();
      goneFrom(item);
      recount();
      toast(say("Muted: {name}", { name: String(one.name || "") }), { action: { label: say("Undo"), run: async () => {
        const back = await call("/api/people?op=notification_mute", { method: "POST", body: { model: one.model, on: false } })
          .catch(() => null);
        if (back && back.status === 200) load();
      } } });
    });
    const manage = document.createElement("a");
    manage.href = "/settings#muted-part";
    manage.textContent = say("What you hear of, and where");
    list.append(mute, manage);
    more.append(summary, list);
    acts.append(more);
  }
  return acts.childElementCount ? acts : null;
}

/// [one] group drawn, its links reading it as they are followed.
function groupOf(one, i = 0) {
  const item = group(one, i, { acts: actsOf });
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
  const answer = await call(`/api/people?op=notifications${LANG}${view === "done" ? "&view=done" : ""}`);
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
  choosing = answer.body.chosen === true;
  const groups = Array.isArray(answer.body.groups) ? answer.body.groups : [];
  $("groups").replaceChildren(...groups.map(groupOf));
  $("empty").hidden = groups.length > 0 || answer.body.ready === false || view !== "inbox";
  $("empty-done").hidden = groups.length > 0 || view !== "done";
  $("not-yet").hidden = answer.body.ready !== false;
  // Inbox and Done, once this account can mark done.
  $("views").hidden = !choosing;
  for (const button of $("views").querySelectorAll("[data-view]")) button.setAttribute("aria-pressed", String(button.dataset.view === view));
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
  const title = document.querySelector(".notices-head h1");
  if (title && focused) {
    title.tabIndex = -1;
    title.focus();
  }
  allRead();
  $("said").textContent = say("All read.");
  showTabCounts(await showFeedCount().catch(() => null));
});
// Mark all done: everything shown, up to its newest, with Undo.
$("all-done").addEventListener("click", async () => {
  const newest = [...document.querySelectorAll("#groups .notice")].map((one) => one.dataset.at).filter(Boolean).sort().pop();
  if (!newest) return;
  $("all-done").disabled = true;
  const answer = await doneCall({ all: true, at: newest });
  $("all-done").disabled = false;
  if (!answer || answer.status !== 200) {
    $("said").textContent = told(answer?.body?.error, say("That did not work just now. Try again in a minute."));
    return;
  }
  const before = answer.body.before ?? null;
  $("groups").replaceChildren();
  const title = document.querySelector(".notices-head h1");
  title.tabIndex = -1;
  title.focus();
  allRead();
  recount();
  toast(say("All done."), { action: { label: say("Undo"), run: async () => {
    const back = await doneCall({ all: true, at: before, undo: true });
    if (back && back.status === 200) load();
  } } });
});
// Inbox or Done: the list asked again, the address saying which.
for (const button of $("views").querySelectorAll("[data-view]")) {
  button.addEventListener("click", () => {
    if (button.dataset.view === view) return;
    view = button.dataset.view === "done" ? "done" : "inbox";
    const url = new URL(location.href);
    if (view === "done") url.searchParams.set("view", "done");
    else url.searchParams.delete("view");
    history.replaceState(null, "", url);
    load();
  });
}
// Back to the list from a model: what was opened is shown read.
addEventListener("pageshow", (event) => {
  if (event.persisted) load();
});

load();
