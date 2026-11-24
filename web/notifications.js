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
// Reply in place (socialloop, 2026-11-24), as GitHub's and Flickr's inbox
// have it: a line that tells of a comment, a reply or a mention, on a model
// or in Talk, has Reply under it, the composer of everywhere opened there
// (web/composer.js); posted, it is in the comment's thread on the model's
// page at once, and the line says Replied, with the way to it.
//
// Every word is put on the page as text; an avatar is the kit's, which
// escapes its own.
import { askToSignIn, call, signOut, signedIn, token } from "/account.js";
import { showFeedCount, showTabCounts } from "/follow.js";
import { langAt, say, told } from "/card.js";
import { group } from "/notice-view.js";
import { iconButtonHtml, iconHtml, toast } from "/kit.js";

const $ = (id) => document.getElementById(id);
/// Which list is shown: the inbox, or what was marked done.
let view = new URLSearchParams(location.search).get("view") === "done" ? "done" : "inbox";
/// Whether this account can mark done and mute (the answer's chosen).
let choosing = false;
/// The kinds the aside's Show offers, each a row's kinds (api/_notifications.js
/// noticeSaid); "all", or none of them, shows every row.
const KINDS = {
  comments: ["comment", "reply", "talk_reply"],
  remixes: ["remix", "suggestion", "suggestion_taken"],
  builds: ["photo"],
  mentions: ["mention", "talk_mention"],
  achievements: ["achievement"],
};
/// Which of them the list shows (?kind=).
let kind = Object.hasOwn(KINDS, new URLSearchParams(location.search).get("kind") || "") ? new URLSearchParams(location.search).get("kind") : "all";
/// Every group drawn: the list's, and your achievements' card in the aside.
const drawn = (more = "") => document.querySelectorAll(`ol.notices .notice${more}`);
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
  const left = drawn(".unread").length;
  $("all-read").hidden = left === 0 || view !== "inbox";
  $("all-done").hidden = !choosing || view !== "inbox" || !drawn().length;
  const none = !document.querySelector("#groups .notice");
  if (none && document.documentElement.dataset.notifications === "ready") {
    $("empty").hidden = view !== "inbox";
    $("empty-done").hidden = view !== "done";
  }
}

/// The list as the aside's Show says: each group's rows of that kind, a group
/// with none of them left out, and how many groups each kind has. Your
/// achievements are a card in the aside, or in the list, every level of them,
/// when Show says Achievements: one group, moved, never drawn twice.
function shown() {
  const card = document.querySelector("ol.notices .notice[data-achievements]");
  if (card && kind === "achievements" && card.parentElement !== $("groups")) $("groups").prepend(card);
  if (card && kind !== "achievements" && card.parentElement !== $("achievements")) $("achievements").append(card);
  $("achieved").hidden = !card || kind === "achievements";
  const every = [...drawn()];
  const groups = [...$("groups").children];
  const wanted = KINDS[kind] || null;
  let left = 0;
  for (const item of groups) {
    let any = !wanted;
    for (const row of item.querySelectorAll(".lines > li")) {
      row.hidden = Boolean(wanted) && !wanted.includes(row.dataset.kind);
      any ||= !row.hidden;
    }
    item.hidden = !any;
    if (any) left += 1;
  }
  for (const link of $("kinds").querySelectorAll("[data-kind]")) {
    const of = KINDS[link.dataset.kind];
    const count = of ? every.filter((item) => [...item.querySelectorAll(".lines > li")].some((row) => of.includes(row.dataset.kind))).length
      : every.filter((item) => item !== card).length;
    if (link.dataset.kind === kind) link.setAttribute("aria-current", "true");
    else link.removeAttribute("aria-current");
    const n = link.querySelector(".n");
    n.textContent = String(count);
    n.hidden = count === 0;
  }
  $("no-kind").hidden = !wanted || left > 0 || groups.length === 0;
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
  const into = next?.querySelector(".row-act [data-done], .row-act summary, .row-title a") || document.querySelector(".page-head h1");
  item.remove();
  shown();
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
    manage.href = `${langAt()}/settings#muted-part`;
    manage.textContent = say("What you hear of, and where");
    list.append(mute, manage);
    more.append(summary, list);
    acts.append(more);
  }
  return acts.childElementCount ? acts : null;
}

/// The lines answered where they are read (socialloop, 2026-11-24), as
/// GitHub's and Flickr's are: a comment, a reply or a mention on a model,
/// and a post or a mention in Talk.
const ANSWERED = new Set(["comment", "reply", "mention", "talk_reply", "talk_mention"]);

/// Reply under each of [one]'s lines that can be answered ([item] drawn):
/// the composer of everywhere opened in place (web/composer.js
/// replyInCard), the reply going to the comment's thread on its model, or
/// to the thread in Talk. Posted, the line says so, with the way to the
/// reply on its page, and the group is read.
function repliesIn(one, item) {
  const lines = item.querySelectorAll(".lines > li");
  (one.rows || []).forEach((row, at) => {
    const line = lines[at];
    if (!line || !ANSWERED.has(row.kind)) return;
    const link = line.querySelector(":scope > a")?.getAttribute("href") || "";
    const comment = row.kind.startsWith("talk_") ? 0 : Number(/#comment-(\d+)$/.exec(link)?.[1]) || 0;
    const thread = row.kind.startsWith("talk_") ? Number(/\/talk\/t\/(\d+)/.exec(link)?.[1]) || 0 : 0;
    if (!comment && !thread) return;
    const acts = document.createElement("p");
    acts.className = "said-acts notice-acts";
    const reply = document.createElement("button");
    reply.type = "button";
    reply.className = "post-say";
    reply.textContent = say("Reply");
    reply.setAttribute("aria-label", say("Reply to {name}", { name: String(row.who || say("them")) }));
    reply.setAttribute("aria-expanded", "false");
    acts.append(reply);
    // The reply, once posted, shows under the line it answers, over Reply.
    const room = document.createElement("div");
    room.className = "said-room";
    line.append(room, acts);
    // The composer's script comes with the first Reply: the list draws
    // without it.
    reply.addEventListener("click", async () => (await import("/composer.js")).replyInCard(line, thread, {
      opener: reply, comment, after: acts,
      tests: /[?&]tests=1\b/.test(link) ? "&tests=1" : "", lang: LANG.slice(6),
      answered: (made) => {
        // The line says it was answered, the reply linked where it now is.
        const id = Number(made?.id) || 0;
        let said = line.querySelector(".answered");
        if (!said) {
          said = document.createElement("span");
          said.className = "pill good answered";
          said.textContent = say("Replied");
          // Beside what happened, before the words quoted.
          line.querySelector(".what q, .what time")?.before(" ", said);
        }
        const shown = line.querySelector(`.said-line[data-line="${id}"] p`);
        if (shown && id && !shown.querySelector(".said-see")) {
          const see = document.createElement("a");
          see.className = "said-see";
          see.href = link.replace(/#.*$/, "") + (comment ? `#comment-${id}` : `#post-${id}`);
          see.textContent = say("See your reply");
          shown.append(" ", see);
        }
        read(item);
      } }));
  });
}

/// [one] group drawn, its links reading it as they are followed.
function groupOf(one, i = 0) {
  const item = group(one, i, { acts: actsOf });
  repliesIn(one, item);
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
  const all = Array.isArray(answer.body.groups) ? answer.body.groups : [];
  // Your achievements are a card in the aside, the rest the list.
  const groups = all.filter((one) => !one.achievements);
  const achieved = all.filter((one) => one.achievements);
  $("groups").replaceChildren(...groups.map(groupOf));
  $("achievements").replaceChildren(...achieved.map(groupOf));
  $("achieved").hidden = achieved.length === 0;
  $("kinds").hidden = answer.body.ready === false;
  shown();
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
  for (const one of drawn(".unread")) {
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
// Mark all done: everything shown, up to its newest, with Undo.
$("all-done").addEventListener("click", async () => {
  const newest = [...drawn()].map((one) => one.dataset.at).filter(Boolean).sort().pop();
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
  $("achievements").replaceChildren();
  $("achieved").hidden = true;
  shown();
  const title = document.querySelector(".page-head h1");
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
// Show: the list's kinds, the address saying which.
for (const link of $("kinds").querySelectorAll("[data-kind]")) {
  link.addEventListener("click", (event) => {
    event.preventDefault();
    kind = Object.hasOwn(KINDS, link.dataset.kind) ? link.dataset.kind : "all";
    const url = new URL(location.href);
    if (kind === "all") url.searchParams.delete("kind");
    else url.searchParams.set("kind", kind);
    history.replaceState(null, "", url);
    shown();
  });
}
// Back to the list from a model: what was opened is shown read.
addEventListener("pageshow", (event) => {
  if (event.persisted) load();
});

load();
