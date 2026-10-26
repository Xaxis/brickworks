// Following a person, and what is new for you (2026-10-18,
// supabase/follows.sql): the Follow button on a profile (/u/<handle>) and
// beside a model's designer (/m/<id>), and your account in the site's
// header.
//
// A button with data-follow="<handle>" is shown once the server says who
// is asking: Follow, or Following (pressed again, letting them go). Signed
// out, it asks to sign in first; an account that may not follow is told
// why, in the server's words, beside it. Following tells the person
// followed nothing, and there is no way to write to them from here. And a
// collection, the same (2026-10-24, supabase/collection_follows.sql): a
// button with data-follow-list="<id>" on its page (/c/<id>), what is put in
// it then in your feed; its owner is told nothing. A page of them (the
// collections directory's cards, /collections) asks how all of them stand
// at once.
//
// Your account in the header (2026-10-22, docs/SOCIAL.md U7, D10): Sign in
// (a[data-account]) until you are, and then your avatar, carrying how many
// new things there are for you, which opens the account menu: who you
// are, Your profile, Notifications and Your feed (each with what is new in
// it), Saved, Settings, the theme and Sign out. On a phone the header has
// no room for a fifth thing, so Menu becomes your avatar and holds the
// same. Which of the two it is is known in this browser at once
// (account.js keeps the session), and who you are and the counts from the
// last page, so it is drawn before anything is asked. Nothing is asked of
// the server for a visitor who is not signed in.
//
// Everything is put on the page as text.
import { askToSignIn, call, email, signOut, signedIn } from "/account.js";
import { avatarHtml } from "/kit.js";

const plural = (n, one, many = `${one}s`) => `${Number(n).toLocaleString("en-US")} ${n === 1 ? one : many}`;

// What a Follow button follows: a person by their handle, or a collection
// by its id; how to ask, the counts it changes on the page, and its words.
const FOLLOWS = {
  person: {
    asked: (handle) => `/api/people?op=follows&handle=${encodeURIComponent(handle)}`,
    sent: (handle, on) => ["/api/people?op=follow", { handle, on }],
    counted: (handle) => `[data-followers="${handle}"], .person[data-handle="${handle}"] [data-followers]`,
    signIn: "Sign in to follow people: we email you a code, no password.",
    titles: ["See what they share in your feed", "You follow them: press to stop"],
    followed: "What they share is in your feed now.",
  },
  list: {
    asked: (id) => `/api/people?op=list_follows&id=${encodeURIComponent(id)}`,
    sent: (id, on) => ["/api/people?op=list_follow", { id, on }],
    counted: (id) => `[data-list-followers="${id}"]`,
    signIn: "Sign in to follow collections: we email you a code, no password.",
    titles: ["See what is put in it in your feed", "You follow it: press to stop"],
    followed: "What is put in it is in your feed now.",
  },
};

/// One Follow button, made live: drawn from [known] when the page already
/// knows how it stands (the feed's designers to follow, none of whom you
/// follow yet), else as the server says.
export async function followButton(button, known = null) {
  const kind = button.dataset.followList ? FOLLOWS.list : FOLLOWS.person;
  const handle = button.dataset.followList || button.dataset.follow;
  const said = button.parentElement?.querySelector(".said") || null;
  const say = (words) => {
    if (said) said.textContent = words ? ` ${words}` : "";
  };
  let state = null;
  const draw = () => {
    button.textContent = state.you_follow ? "Following" : "Follow";
    button.setAttribute("aria-pressed", state.you_follow ? "true" : "false");
    button.title = kind.titles[state.you_follow ? 1 : 0];
    button.hidden = state.mine;
    // On your own page, Edit profile where Follow would be (docs/SOCIAL.md U6).
    const own = button.closest(".profile-head")?.querySelector("[data-edit-own]");
    if (own) own.hidden = !state.mine;
    for (const counted of document.querySelectorAll(kind.counted(handle))) {
      // A designer's page draws it as a tile, its number large
      // (api/people.js earnedHtml): kept so, the words beside it.
      const big = counted.querySelector("b");
      const words = counted.querySelector("span");
      // Said once there is one, as every count is.
      counted.hidden = !Number(state.followers);
      if (big && words) {
        big.textContent = Number(state.followers).toLocaleString("en-US");
        words.textContent = state.followers === 1 ? "follower" : "followers";
      } else {
        counted.textContent = plural(state.followers, "follower");
      }
    }
  };
  const ask = async () => {
    const answer = await call(kind.asked(handle));
    if (answer.status !== 200 || !answer.body.ready) return false;
    state = answer.body;
    draw();
    return true;
  };
  if (known) {
    state = { followers: 0, ...known };
    draw();
  } else if (!(await ask())) {
    return;
  }
  button.addEventListener("click", async () => {
    say("");
    if (!state.signed_in) {
      if (!(await askToSignIn(kind.signIn))) return;
      if (!(await ask())) return;
      if (state.mine || state.you_follow) return;
    }
    if (!state.you_follow && !state.may) {
      say(state.why_not);
      return;
    }
    button.disabled = true;
    const [where, body] = kind.sent(handle, !state.you_follow);
    const answer = await call(where, { method: "POST", body });
    button.disabled = false;
    if (answer.status !== 200) {
      say(answer.body.error || "That did not work just now. Try again in a minute.");
      return;
    }
    state = { ...state, ...answer.body };
    draw();
    say(state.you_follow ? kind.followed : "");
  });
}

// Who you are and what is new, from the last page, so the next is drawn at
// once: {email, me: {handle, name}, count, notifications, feed}.
const KEPT = "brickworks.me";
const keptState = () => {
  try {
    const kept = JSON.parse(sessionStorage.getItem(KEPT) || "null");
    return kept && kept.email === email() ? kept : null;
  } catch {
    return null;
  }
};
const keepState = (state) => {
  try {
    sessionStorage.setItem(KEPT, JSON.stringify(state));
  } catch {
    // Asked again on the next page.
  }
};
const shown = (n) => (n > 98 ? "99+" : String(n));

/// A count in the header: on the avatar, on Menu, beside a menu's link.
function badge(n, label = "") {
  const said = document.createElement("span");
  said.className = "count";
  said.textContent = shown(n);
  if (label) said.setAttribute("aria-label", label);
  else said.setAttribute("aria-hidden", "true");
  return said;
}

function avatarOf(state, size) {
  const made = document.createElement("template");
  made.innerHTML = avatarHtml({ handle: state.me?.handle || "", name: state.me?.name || state.email || "?",
    picture: state.me?.picture || "" }, { size });
  return made.content.firstElementChild;
}

/// What the account menu holds: who you are, your places with their
/// counts, and (once, at its end) the theme and Sign out.
function accountPart(state) {
  const part = document.createElement("div");
  part.className = "account-part";
  const whoIs = document.createElement("p");
  whoIs.className = "menu-who";
  const words = document.createElement("span");
  const name = document.createElement("b");
  name.textContent = state.me?.name || "Signed in";
  const handle = document.createElement("small");
  handle.textContent = state.me?.handle ? `@${state.me.handle}` : state.email || "";
  words.append(name, handle);
  whoIs.append(avatarOf(state, ""), words);
  const places = document.createElement("nav");
  places.setAttribute("aria-label", "Your account");
  const counted = { "/notifications": state.notifications, "/feed": state.feed };
  for (const [href, words, data] of [["/profile", "Your profile", "profile"], ["/notifications", "Notifications", "notifications"],
    ["/feed", "Your feed", "feed"], ["/profile?tab=saved", "Saved", "saved"], ["/settings", "Settings", "settings"]]) {
    const link = document.createElement("a");
    link.href = href;
    link.dataset.place = data;
    link.append(words);
    const n = Number(counted[href]) || 0;
    if (n > 0) link.append(" ", badge(n, `${n} new`));
    if (location.pathname === href) link.setAttribute("aria-current", "page");
    places.append(link);
  }
  part.append(whoIs, places);
  return part;
}

function signOutButton() {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "sign-out";
  button.dataset.signOut = "";
  button.textContent = "Sign out";
  button.addEventListener("click", () => {
    signOut();
    location.reload();
  });
  return button;
}

/// The theme's three buttons, as the footer has them, pressed as chosen.
function themeChoice() {
  const footer = document.querySelector(".site-foot .theme-choice");
  if (!footer) return null;
  const copy = footer.cloneNode(true);
  const chosen = window.brickworksTheme?.chosen?.() || "system";
  for (const button of copy.querySelectorAll("[data-theme-choice]")) {
    button.setAttribute("aria-pressed", String(button.dataset.themeChoice === chosen));
  }
  return copy;
}

function drawSignedOut() {
  for (const link of document.querySelectorAll(".site-head a[data-account]")) {
    link.hidden = false;
    link.textContent = "Sign in";
    link.href = "/profile";
  }
  for (const made of document.querySelectorAll(".site-head .account-menu, .site-head .account-part, .site-head .menu .sign-out")) made.remove();
  for (const menu of document.querySelectorAll(".site-head .menu summary")) {
    menu.classList.remove("account-btn");
    menu.replaceChildren("Menu");
    menu.removeAttribute("aria-label");
  }
}

/// The header for somebody signed in: [state] is who and what is new.
function drawSignedIn(state) {
  const n = Number(state.count) || 0;
  const label = n ? `Your account, ${n} new` : "Your account";
  for (const link of document.querySelectorAll(".site-head a[data-account]")) {
    link.hidden = true;
    link.textContent = "Account";
  }
  // On a laptop: the avatar, after where Sign in was, opening the menu.
  for (const nav of document.querySelectorAll(".site-head .nav")) {
    const where = nav.querySelector("a[data-account]");
    if (!where) continue;
    let menu = nav.querySelector(".account-menu");
    if (!menu) {
      menu = document.createElement("details");
      menu.className = "more-menu end account-menu";
      where.after(menu);
    }
    const open = menu.open;
    const summary = document.createElement("summary");
    summary.className = "account-btn";
    summary.setAttribute("aria-label", label);
    summary.append(avatarOf(state, ""));
    if (n) summary.append(badge(n));
    const list = document.createElement("div");
    list.className = "menu-list";
    list.append(accountPart(state), ...[themeChoice()].filter(Boolean), signOutButton());
    menu.replaceChildren(summary, list);
    menu.open = open;
  }
  // On a phone: Menu is the avatar, and holds the same.
  for (const menu of document.querySelectorAll(".site-head .menu")) {
    const summary = menu.querySelector("summary");
    summary.classList.add("account-btn");
    summary.replaceChildren(avatarOf(state, ""));
    if (n) summary.append(badge(n));
    summary.setAttribute("aria-label", n ? `Menu and your account, ${n} new` : "Menu and your account");
    const list = menu.querySelector(".menu-list");
    list.querySelector(".account-part")?.remove();
    list.querySelector(".sign-out")?.remove();
    list.querySelector("nav")?.after(accountPart(state));
    list.append(signOutButton());
  }
}

/// Your account in the header, and what is new for you: {count,
/// notifications, feed}, or null signed out. [ask]: false on the two pages
/// that clear a count, which ask once they have opened.
export async function showFeedCount({ ask = true } = {}) {
  if (!document.querySelector(".site-head a[data-account]")) return null;
  if (!signedIn()) {
    drawSignedOut();
    return null;
  }
  const kept = keptState() || { email: email(), me: null, count: 0, notifications: null, feed: null };
  drawSignedIn(kept);
  if (!ask) return kept;
  const answer = await call("/api/people?op=feed_count").catch(() => null);
  if (!answer || answer.status !== 200 || answer.body.signed_in === false) return kept;
  const state = { email: email(), me: answer.body.me || null, count: Number(answer.body.count) || 0,
    notifications: answer.body.notifications ?? null, feed: answer.body.feed ?? null };
  keepState(state);
  drawSignedIn(state);
  return state;
}

/// The tabs of /notifications and /feed: what is new in each, said once
/// there is some ([data-count] in each tab).
export function showTabCounts(state) {
  for (const where of document.querySelectorAll(".tabs [data-count]")) {
    const n = Number(state?.[where.dataset.count]) || 0;
    where.hidden = n === 0;
    where.textContent = n === 0 ? "" : n > 98 ? "99+" : String(n);
  }
}

/// A page of collections' cards, each with its Follow (/collections): how
/// each stands asked once for all of them, not once a card. A server from
/// before that answer is asked a card at a time, as before.
async function followLists(buttons) {
  const ids = [...new Set(buttons.map((button) => button.dataset.followList))];
  const answer = await call(`/api/people?op=list_follows&ids=${ids.map(encodeURIComponent).join(",")}`).catch(() => null);
  const follows = answer && answer.status === 200 && answer.body && answer.body.follows;
  for (const button of buttons) {
    if (!follows) followButton(button).catch(() => null);
    else if (follows[button.dataset.followList]?.ready) followButton(button, follows[button.dataset.followList]).catch(() => null);
  }
}

for (const button of document.querySelectorAll("button[data-follow]")) followButton(button).catch(() => null);
const listButtons = [...document.querySelectorAll("button[data-follow-list]")];
if (listButtons.length > 1) followLists(listButtons).catch(() => null);
else for (const button of listButtons) followButton(button).catch(() => null);
// /feed and /notifications ask once they have opened (web/feed.js,
// web/notifications.js), so their own count is cleared first.
showFeedCount({ ask: !["/feed", "/notifications"].includes(location.pathname) }).catch(() => null);
addEventListener("brickworks:signed-in", () => showFeedCount().catch(() => null));
