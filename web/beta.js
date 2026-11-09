// The beta's page (beta.html), its hub: the way in that fits whoever reads
// it, the months of Pro left, what is new this week, and for a tester what
// to try, what we know is wrong and their early features. What the server says comes
// from web/betabar.js (GET /api/plans?op=beta), which also joins and opens
// Report a bug; this week's releases from changelog.json (tools/site.py);
// a tester's parts from GET /api/plans?op=beta_hub (api/_early.js). Off,
// the page says the beta is coming soon and offers no way in. Every word
// goes on the page as text, never as markup.
import { call, signedIn } from "/account.js";
import { betaState, joinBeta, reportBug } from "/betabar.js";
import { langAt, number, say } from "/card.js";
import { toast } from "/kit.js";

const $ = (id) => document.getElementById(id);
// A date as the page's language writes one: "30 October 2026".
const LOCALE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "en-GB";
const DAY = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const day = (iso) => (Number.isFinite(Date.parse(iso || "")) ? DAY.format(new Date(iso)) : "");
const english = (globalThis.brickworksLang?.code || "en") === "en";
// This week's: a release made in the last seven days, and what is on the
// web in none yet. With none this week, the newest.
const WEEK = 7 * 24 * 60 * 60 * 1000;

/// The line under the title.
function lineOf(heard) {
  if (heard.beta === "off") return say("Coming soon: the beta opens here shortly.");
  if (heard.beta !== "open") return say("The beta could not be read just now. Try again in a minute.");
  if (heard.tester) {
    return heard.joined_at ? say("You’ve been a tester since {day}. Thank you!", { day: day(heard.joined_at) })
      : say("You’re a tester. Thank you!");
  }
  if (heard.left > 0) return say("{left} of {cap} free months of Pro left", { left: number(heard.left), cap: number(heard.cap) });
  return say("All {cap} months of Pro are given. Joining stays open.", { cap: number(heard.cap) });
}

let focused = false;

/// The page as [heard] has it.
function draw(heard) {
  const open = heard.beta === "open";
  for (const one of document.querySelectorAll("[data-when]")) one.hidden = one.dataset.when !== (open ? "open" : "off");
  $("spots").textContent = lineOf(heard);
  const visitor = !open ? "" : heard.tester ? "tester" : signedIn() ? "in" : "out";
  for (const row of document.querySelectorAll("#beta-acts > [data-visitor]")) row.hidden = row.dataset.visitor !== visitor;
  document.documentElement.dataset.betaPage = visitor || heard.beta;
  // Come from the bar's Join (/beta#beta-acts): its button, ready to press.
  // Not before the page has loaded: the browser's own move to #beta-acts,
  // which is not focusable, clears the focus as it scrolls there.
  if (location.hash === "#beta-acts" && !focused && (visitor === "out" || visitor === "in")) {
    focused = true;
    const button = document.querySelector(`#beta-acts > [data-visitor="${visitor}"] [data-beta-join]`);
    const now = () => requestAnimationFrame(() => {
      const free = !document.activeElement || document.activeElement === document.body;
      if (button && free && !button.closest("[hidden]")) button.focus();
    });
    if (document.readyState === "complete") now();
    else addEventListener("load", now, { once: true });
  }
  if (open) news();
  if (heard.tester) testers();
}

// -- what is new ------------------------------------------------------------

let newsAsked = false;

/// One release as a card: its name, its date, the heads of its notes as
/// written (in English), and a link to all of it on the changelog.
function release(one) {
  const card = document.createElement("li");
  card.className = "card";
  const head = document.createElement("h3");
  head.textContent = one.version ? `Brickworks ${one.version}` : say("On the web now");
  const when = document.createElement("p");
  when.textContent = one.date ? day(one.date) : say("In the app at brickworks.diy/app, and in the next desktop release");
  const heads = document.createElement("ul");
  if (!english) heads.lang = "en";
  for (const words of one.heads || []) {
    const item = document.createElement("li");
    item.textContent = String(words);
    heads.append(item);
  }
  const more = document.createElement("a");
  more.className = "more";
  more.href = `${langAt()}/changelog#${encodeURIComponent(one.anchor)}`;
  more.textContent = one.more > 0 ? say("And {n} more: read it all", { n: number(one.more) }) : say("Read it all");
  card.append(head, when, heads, more);
  return card;
}

async function news() {
  if (newsAsked) return;
  newsAsked = true;
  const list = $("news");
  let releases = [];
  try {
    const reply = await fetch("/changelog.json", { headers: { accept: "application/json" } });
    releases = reply.ok ? ((await reply.json())?.releases || []) : [];
  } catch {
    releases = [];
  }
  releases = releases.filter((one) => one && /^(?:web|v[\w.-]+)$/.test(String(one.anchor)) && Array.isArray(one.heads));
  const week = releases.filter((one) => !one.date || Date.now() - Date.parse(one.date) <= WEEK);
  const shown = (week.length ? week : releases).slice(0, 2);
  if (!shown.length) {
    const none = document.createElement("li");
    none.className = "state";
    none.textContent = say("Nothing new could be read just now. The changelog has every release.");
    list.replaceChildren(none);
    return;
  }
  list.replaceChildren(...shown.map(release));
}

// -- a tester's -------------------------------------------------------------

let testersAsked = false;
const WHERE = { site: () => say("On the site"), app: () => say("In the app"), both: () => say("In the app and on the site") };
// A page of the site with a copy in the page's language opens it (/library
// as /de/library); the docs have none.
const ledTo = (href) => (/^\/(?:library|gallery|feedback|settings|plans)(?=[/?#]|$)/.test(href) ? `${langAt()}${href}` : href);

/// One card, of what is known or early: its title and words as we wrote
/// them, in English (lang="en"), and where it is, in the page's language.
function card({ title, words, where, href }) {
  const item = document.createElement("li");
  item.className = "card";
  const head = document.createElement("h3");
  head.textContent = title;
  head.lang = "en";
  const said = document.createElement("p");
  said.textContent = words;
  said.lang = "en";
  item.append(head, said);
  if (href) {
    const link = document.createElement("a");
    link.className = "pill";
    link.href = ledTo(href);
    link.textContent = WHERE[where] ? say("{where}: open it", { where: WHERE[where]() }) : say("Open it");
    item.append(link);
  } else if (WHERE[where]) {
    const pill = document.createElement("span");
    pill.className = "pill";
    pill.textContent = WHERE[where]();
    item.append(pill);
  }
  return item;
}

async function testers() {
  if (testersAsked) return;
  testersAsked = true;
  const { status, body } = await call("/api/plans?op=beta_hub").catch(() => ({ status: 0, body: {} }));
  if (status !== 200) {
    testersAsked = false;
    return;
  }
  const lists = { try: body.new || [], known: (body.known || []).map((one) => ({ ...one, where: "" })), early: body.early || [] };
  for (const [id, cards] of Object.entries(lists)) {
    $(id).replaceChildren(...cards.map(card));
    $(id).hidden = !cards.length;
  }
  for (const id of ["known", "early"]) $(`${id}-h`).hidden = !lists[id].length;
  document.querySelector("#testers .note").hidden = !lists.known.length;
  $("testers").hidden = !Object.values(lists).some((cards) => cards.length);
}

// -- presses ----------------------------------------------------------------

document.getElementById("main").addEventListener("click", async (event) => {
  const pressed = event.target instanceof Element ? event.target.closest("[data-beta-join], [data-beta-report]") : null;
  if (!pressed) return;
  if (pressed.matches("[data-beta-report]")) {
    reportBug("hub");
    return;
  }
  pressed.disabled = true;
  try {
    const now = await joinBeta("hub");
    if (now) draw(now);
    if (now?.tester) toast(say("You’re a tester. Thank you!"));
  } catch (trouble) {
    toast(trouble.message);
  } finally {
    pressed.disabled = false;
  }
});

addEventListener("brickworks:beta", () => betaState().then(draw));
addEventListener("brickworks:signed-in", () => betaState({ fresh: true }).then(draw));
betaState().then(draw);
