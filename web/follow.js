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
// it), Saved, Settings, Send feedback (and for a beta tester the beta
// hub), the theme and Sign out. On a phone the header has
// no room for a fifth thing, so Menu becomes your avatar and holds the
// same. Which of the two it is is known in this browser at once
// (account.js keeps the session), and who you are and the counts from the
// last page, so it is drawn before anything is asked. Nothing is asked of
// the server for a visitor who is not signed in.
//
// More like a designer (2026-10-30, docs/SOCIAL.md section 7, item 9): on a
// person's page, a section with data-alike="<handle>" is filled with up to
// six designers whose work is closest to theirs (api/_alike.js), each a
// row with Follow in place, never you nor anybody you follow already;
// shown only when somebody is close.
//
// Everything is put on the page as text.
import { askToSignIn, call, email, madeUp, signOut, signedIn } from "/account.js";
import { earlyOn } from "/early.js";
import { avatarHtml } from "/kit.js";

// A follow sent and not yet answered, kept for this tab until it is
// (web295): Follow is drawn at once and the server answers 260-390 ms
// later, so the next page (Your feed, pressed at once) could be opened
// first, and leaving a page dropped what it was still asking. The next
// page sends it again (a follow says on or off, so twice is once), and
// what reads follows waits for the answer (followsSent): the feed is never
// drawn without whom you just followed.
const SENT = "brickworks.follows-sent";
// How long one is sent again for: long after any answer would have come.
const SENT_FOR_MS = 60 * 1000;
// This page's, on their way: each a promise of the server's answer.
const sending = new Map();

const sentKept = () => {
  try {
    const kept = JSON.parse(sessionStorage.getItem(SENT) || "[]");
    return Array.isArray(kept) ? kept.filter((one) => one && one.who === email() && Date.now() - one.at < SENT_FOR_MS) : [];
  } catch {
    return [];
  }
};
const keepSent = (list) => {
  try {
    if (list.length) sessionStorage.setItem(SENT, JSON.stringify(list));
    else sessionStorage.removeItem(SENT);
  } catch {
    // Not kept: this page still waits on its own.
  }
};

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

/// Follows [id] (a "person" or a "list", as [named] says) or lets them go,
/// as [on] says: the server's answer, {status, body}. Kept for this tab
/// until it is answered, and sent so that leaving the page does not drop it.
function send(named, id, on) {
  const key = `${named}:${id}`;
  const at = Date.now();
  keepSent([...sentKept().filter((one) => one.key !== key), { key, named, id, on, at, who: email() }]);
  const [where, body] = FOLLOWS[named].sent(id, on);
  const answer = call(where, { method: "POST", body, keepalive: true }).catch(() => ({ status: 0, body: {} }))
    .then((said) => {
      keepSent(sentKept().filter((one) => !(one.key === key && one.at === at)));
      if (sending.get(key) === answer) sending.delete(key);
      return said;
    });
  sending.set(key, answer);
  return answer;
}

/// Once every follow this tab sent is answered: one an earlier page was
/// left before it heard back is sent again first. What draws follows as the
/// server has them (the feed, a Follow button, the count on your avatar)
/// asks after this.
export async function followsSent() {
  for (const one of sentKept()) if (!sending.has(one.key) && FOLLOWS[one.named]) send(one.named, one.id, one.on);
  await Promise.all(sending.values());
}

/// One Follow button, made live: drawn from [known] when the page already
/// knows how it stands (the feed's designers to follow, none of whom you
/// follow yet), else as the server says.
export async function followButton(button, known = null) {
  const named = button.dataset.followList ? "list" : "person";
  const kind = FOLLOWS[named];
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
    await followsSent();
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
    // Drawn at once, as a card's like is, then as the server says; back as
    // it was, and why, if it refuses. Waiting on it took 260-390 ms (site273).
    const was = state;
    const on = !state.you_follow;
    state = { ...state, you_follow: on, followers: Math.max(0, (Number(state.followers) || 0) + (on ? 1 : -1)) };
    draw();
    button.disabled = true;
    const answer = await send(named, handle, on);
    button.disabled = false;
    if (answer.status !== 200) {
      state = was;
      draw();
      say(answer.body.error || "That did not work just now. Try again in a minute.");
      return;
    }
    state = { ...state, ...answer.body };
    draw();
    say(state.you_follow ? kind.followed : "");
  });
}

/// A person to follow, as a row (site.css .person-row): their avatar and
/// their name, each a link to their profile, a line about them ([words]),
/// and Follow, drawn at once from [known], how the page already knows it
/// stands (followButton). The feed's designers to follow, and More like.
export function personRow(one, words, known) {
  const item = document.createElement("li");
  item.className = "person-row";
  item.dataset.handle = one.handle;
  const toProfile = (inner, attrs = {}) => {
    const link = document.createElement("a");
    link.href = `/u/${encodeURIComponent(one.handle)}`;
    for (const [name, value] of Object.entries(attrs)) link.setAttribute(name, value);
    link.append(inner);
    return link;
  };
  const face = document.createElement("template");
  face.innerHTML = avatarHtml({ handle: one.handle, name: one.name, picture: one.picture });
  item.append(toProfile(face.content.firstElementChild, { tabindex: "-1", "aria-hidden": "true", class: "face" }));
  const names = document.createElement("div");
  names.className = "names";
  const name = document.createElement("b");
  name.textContent = String(one.name || one.handle);
  const line = document.createElement("small");
  line.textContent = words || `@${one.handle}`;
  names.append(toProfile(name), line);
  const button = document.createElement("button");
  button.type = "button";
  button.className = "cta ghost small follow";
  button.dataset.follow = one.handle;
  button.textContent = "Follow";
  const told = document.createElement("span");
  told.className = "said";
  told.setAttribute("role", "status");
  item.append(names, button, told);
  followButton(button, known).catch(() => null);
  return item;
}

const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;

/// More like the designer whose page this is: [box] (data-alike, their
/// handle) filled with whom the API finds closest, as you may be shown
/// them, and shown once there is one. html[data-alike] says how it went.
async function showAlike(box) {
  const tests = new URLSearchParams(location.search).get("tests") === "1" ? "&tests=1" : "";
  // A follow just sent from another page is in the answer.
  await followsSent();
  const answer = await call(`/api/people?op=alike&handle=${encodeURIComponent(box.dataset.alike)}${tests}`)
    .catch(() => null);
  const designers = answer && answer.status === 200 && Array.isArray(answer.body.designers)
    ? answer.body.designers.filter((one) => one && HANDLE.test(String(one.handle))) : [];
  box.querySelector(".people-list").replaceChildren(...designers.map((one) => personRow(one, String(one.said || ""),
    { you_follow: false, mine: false, signed_in: signedIn(), may: true, why_not: "", ...(one.follow || {}) })));
  box.hidden = designers.length === 0;
  document.documentElement.dataset.alike = !answer || answer.status !== 200 ? "broken" : designers.length ? "shown" : "none";
}

// Who you are and what is new, from the last page, so the next is drawn at
// once: {email, me, count, notifications, feed}. me is {handle, name,
// picture}, null for an account with no profile, and undefined until the
// server has said. Kept in this browser, not only this tab: a new tab or
// the next visit, with nothing kept, drew the address's letter until the
// server answered with the name's (avatar368). Forgotten at Sign out
// (account.js).
const KEPT = "brickworks.me";
const keptState = () => {
  try {
    const kept = JSON.parse(localStorage.getItem(KEPT) || "null");
    return kept && kept.email === email() ? kept : null;
  } catch {
    return null;
  }
};
const keepState = (state) => {
  try {
    localStorage.setItem(KEPT, JSON.stringify(state));
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

// Your address, as the header may show it: an orangecheck account's is made
// up (account.js madeUp), never to be shown as theirs.
const addressOf = (state) => (madeUp(state.email) ? "" : state.email || "");

/// Your avatar: your profile's, the address's letter only for an account
/// with no profile, and a blank circle until the server has said which.
function avatarOf(state, size) {
  const { me } = state;
  const made = document.createElement("template");
  made.innerHTML = avatarHtml(me === undefined ? {} : me ? { handle: me.handle, name: me.name, picture: me.picture }
    : { name: addressOf(state) }, { size });
  return made.content.firstElementChild;
}

/// A bar where words will be, until the server has said them.
function bone(kind) {
  const bar = document.createElement("span");
  bar.className = `bone ${kind}`;
  return bar;
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
  const handle = document.createElement("small");
  if (state.me === undefined) {
    name.append(bone("wide"));
    handle.append(bone("short"));
  } else {
    name.textContent = state.me?.name || "Signed in";
    handle.textContent = state.me?.handle ? `@${state.me.handle}` : addressOf(state);
  }
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
  // Send feedback (web/feedback.js, opened below), and for a beta tester
  // the beta hub (an early feature: web/early.js), added once the server
  // has said.
  const feedback = document.createElement("a");
  feedback.href = "/feedback";
  feedback.dataset.feedback = "";
  feedback.dataset.place = "feedback";
  feedback.append("Send feedback");
  places.append(feedback);
  earlyOn("beta_hub").then((on) => {
    if (!on || places.querySelector('[data-place="beta-hub"]')) return;
    const hub = document.createElement("a");
    hub.href = "/beta-hub";
    hub.dataset.place = "beta-hub";
    hub.append("Beta hub");
    if (location.pathname === "/beta-hub") hub.setAttribute("aria-current", "page");
    feedback.before(hub);
  }).catch(() => null);
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
  const kept = keptState() || { email: email(), me: undefined, count: 0, notifications: null, feed: null };
  drawSignedIn(kept);
  if (!ask) return kept;
  await followsSent();
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
  await followsSent();
  const ids = [...new Set(buttons.map((button) => button.dataset.followList))];
  const answer = await call(`/api/people?op=list_follows&ids=${ids.map(encodeURIComponent).join(",")}`).catch(() => null);
  const follows = answer && answer.status === 200 && answer.body && answer.body.follows;
  for (const button of buttons) {
    if (!follows) followButton(button).catch(() => null);
    else if (follows[button.dataset.followList]?.ready) followButton(button, follows[button.dataset.followList]).catch(() => null);
  }
}

for (const button of document.querySelectorAll("button[data-follow]")) followButton(button).catch(() => null);
for (const box of document.querySelectorAll("[data-alike]")) showAlike(box).catch(() => null);
/// Collections' Follow buttons: all asked at once when there are several.
function followAll(buttons) {
  if (buttons.length > 1) followLists(buttons).catch(() => null);
  else for (const button of buttons) followButton(button).catch(() => null);
}
followAll([...document.querySelectorAll("button[data-follow-list]")]);
// A page of cards put on the page later (web/pager.js): theirs too.
document.addEventListener("pager:drawn", (event) => {
  followAll((event.detail?.items || []).flatMap((one) => [...one.querySelectorAll("button[data-follow-list]")]));
});
// /feed and /notifications ask once they have opened (web/feed.js,
// web/notifications.js), so their own count is cleared first.
showFeedCount({ ask: !["/feed", "/notifications"].includes(location.pathname) }).catch(() => null);

// Send feedback (web/feedback.js): the footer's link, the account menu's
// and /feedback's buttons, each a[data-feedback] or button[data-feedback]
// ("bug", "idea" or "question" chooses it first). Loaded when pressed, not
// before; a click meant for a new tab still opens /feedback there.
document.addEventListener("click", (event) => {
  const asked = event.target instanceof Element ? event.target.closest("[data-feedback]") : null;
  if (!asked || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey
    || event.altKey) return;
  event.preventDefault();
  asked.closest("details")?.removeAttribute("open");
  import("/feedback.js").then(({ openFeedback }) => openFeedback({ kind: asked.dataset.feedback || "" }))
    .catch(() => { location.href = "/feedback"; });
});
addEventListener("brickworks:signed-in", () => showFeedCount().catch(() => null));
