// The beta's page (beta.html), its hub: the way in that fits whoever reads
// it, the months of Pro left, what is new this week, and for a tester what
// to try, what we know is wrong and their early features. What the server says comes
// from web/betabar.js (GET /api/plans?op=beta), which also joins and opens
// Report a bug; this week's releases from changelog.json (tools/site.py);
// a tester's parts from GET /api/plans?op=beta_hub (api/_early.js), and
// their "tell us about you" (betajoin) from GET /api/plans?op=beta's
// application. Off, the page says the beta is coming soon and offers no
// way in. Every word goes on the page as text, never as markup.
import { askToSignIn, call, signedIn } from "/account.js";
import { betaState, joinBeta, reportBug } from "/betabar.js";
import { langAt, number, say, told } from "/card.js";
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
  if (heard.tester) about();
  else if (aboutAsked) {
    aboutAsked = false;
    $("about").hidden = true;
  }
}

// -- what is new ------------------------------------------------------------

// What is new, asked once: its drawing, which a landing on #about waits for.
let newsAsked = null;

/// One release as a card: its name, its date, the heads of its notes as
/// written (in English), and a link to all of it on the changelog.
function release(one) {
  const card = document.createElement("li");
  card.className = "card";
  const head = document.createElement("h3");
  head.textContent = one.version ? `Brickworks ${one.version}` : say("On the web now");
  const when = document.createElement("p");
  when.textContent = one.date ? day(one.date) : say("In the app at brickworks.diy/app now; the desktop app is coming soon");
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

function news() {
  newsAsked ||= drawNews();
  return newsAsked;
}

async function drawNews() {
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

// A tester's parts, asked once they are a tester: their drawing, which a
// landing on #about waits for; asked again at the next draw if it failed.
let testersAsked = null;
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

function testers() {
  testersAsked ||= drawTesters().then((drawn) => {
    if (!drawn) testersAsked = null;
  });
  return testersAsked;
}

async function drawTesters() {
  const { status, body } = await call("/api/plans?op=beta_hub").catch(() => ({ status: 0, body: {} }));
  if (status !== 200) return false;
  const lists = { try: body.new || [], known: (body.known || []).map((one) => ({ ...one, where: "" })), early: body.early || [] };
  for (const [id, cards] of Object.entries(lists)) {
    $(id).replaceChildren(...cards.map(card));
    $(id).hidden = !cards.length;
  }
  for (const id of ["known", "early"]) $(`${id}-h`).hidden = !lists[id].length;
  document.querySelector("#testers .note").hidden = !lists.known.length;
  $("testers").hidden = !Object.values(lists).some((cards) => cards.length);
  return true;
}

// -- tell us about you (a tester's) -------------------------------------------
// The month of Pro's application, after joining and never a gate to it
// (betajoin): the form, or where it stands (POST and GET
// /api/plans?op=beta, api/_beta.js). A tester agreed to the terms and the
// emails when it joined, so neither is asked here.

let aboutAsked = false;
let aboutLanded = false;
const PANELS = ["apply-wait", "apply-form", "apply-status"];
// The form's own least, as the server's (api/_beta.js LEAST_BUILD).
const LEAST_BUILD = 20;

/// Only [id] of the panel's parts shown: swapped in one frame.
function show(id) {
  for (const one of PANELS) $(one).hidden = one !== id;
}

/// Where an application stands, in words: [title, line, more].
function standing(app, cap) {
  if (app.status === "approved" && app.early) {
    return [say("You are a tester"), say("Your account was made before 29 October 2026, so it has Pro already, free and "
      + "with no end date. You did not need one of the spots."), ""];
  }
  if (app.status === "approved") {
    const month = app.comp === "granted" && app.month_ends_at
      ? say("Your month of Pro runs from {from} to {to}.", { from: day(app.month_starts_at), to: day(app.month_ends_at) })
      : say("Your month of Pro starts the day Pro launches, and runs 30 days from then. We will email you when it starts.");
    return [say("You are in: spot {spot} of {cap}", { spot: app.spot, cap }), month,
      say("When it ends you are back on Free: nothing is charged, and nothing is deleted.")];
  }
  if (app.status === "waitlist") {
    return [say("On the waitlist"), say("You applied on {day}, after all {cap} spots were taken. If we open more, your "
      + "application is read with the others.", { day: day(app.applied_at), cap }), ""];
  }
  if (app.status === "declined") {
    return [say("Not this time"), say("We could not offer you a spot this time. You may apply again from {day}.",
      { day: day(app.may_apply_again_at) }), ""];
  }
  return [say("Applied"), say("You applied on {day}. We read every application ourselves, and will email you once we "
    + "have decided.", { day: day(app.applied_at) }), app.early ? say("Your account was made before 29 October 2026, so "
    + "it has Pro already, free and with no end date; you would not take one of the spots.") : ""];
}

/// The section as [answer] (op=beta's) has it: where the application
/// stands, or the form, again once a decline's wait is over.
function drawAbout(answer) {
  const app = answer.application || null;
  const again = app?.status === "declined" && Date.parse(app.may_apply_again_at || "") <= Date.now();
  if (app && !again) {
    const [title, said, more] = standing(app, answer.pool?.cap ?? answer.spots?.cap ?? 100);
    $("status-h").textContent = title;
    $("status-said").textContent = said;
    $("status-more").textContent = more;
    $("status-more").hidden = !more;
    show("apply-status");
  } else {
    $("apply-was").hidden = !again;
    $("apply-was").textContent = again ? say("Your last application was declined. You may apply again now.") : "";
    show("apply-form");
  }
  // Come from a link to /beta#about (the welcome, Settings, the beta's
  // emails): the section was hidden as the page loaded, so the browser
  // could not go there; it does now, once, after what is new and a
  // tester's parts above it are drawn. Gone there before them, the page
  // was pushed down under the reader by what they added: the hub's lists
  // put the section 1297 px down at 1280, its title focused off the
  // window (beta_flow on a preview, betaon 2026-11-10).
  if (location.hash === "#about" && !aboutLanded) {
    aboutLanded = true;
    const now = () => requestAnimationFrame(() => {
      $("about").scrollIntoView({ block: "start" });
      $("about-h").focus({ preventScroll: true });
    });
    Promise.allSettled([newsAsked, testersAsked]).then(() => {
      if (document.readyState === "complete") now();
      else addEventListener("load", now, { once: true });
    });
  }
}

async function about() {
  if (aboutAsked) return;
  aboutAsked = true;
  $("about").hidden = false;
  const { status, body } = await call("/api/plans?op=beta").catch(() => ({ status: 0, body: {} }));
  if (status !== 200 || body?.beta !== "open" || body.tester !== true) {
    aboutAsked = false;
    $("about").hidden = true;
    return;
  }
  drawAbout(body);
}

/// What the form says, or a line saying what to fix first: [body, why, field].
function filled() {
  const build = $("f-build").value.trim();
  if (build.length < LEAST_BUILD) {
    return [null, say("Say what you would build, in a sentence or two: at least {n} characters.", { n: LEAST_BUILD }), "f-build"];
  }
  if (!$("f-ai").value) return [null, say("Choose which AI you use."), "f-ai"];
  if (!$("f-background").value) return [null, say("Choose your LEGO® or CAD background."), "f-background"];
  return [{ build, ai: $("f-ai").value, background: $("f-background").value, background_line: $("f-line").value,
    link: $("f-link").value }, "", ""];
}

$("apply-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const said = $("apply-said");
  const [body, why, field] = filled();
  if (!body) {
    said.textContent = why;
    $(field).focus();
    return;
  }
  const button = $("apply-send");
  button.disabled = true;
  said.textContent = say("Sending…");
  try {
    let reply = await call("/api/plans?op=beta", { method: "POST", body });
    if (reply.status === 401 && (await askToSignIn("Sign in again to tell us about you."))) {
      reply = await call("/api/plans?op=beta", { method: "POST", body });
    }
    if (reply.status === 200) {
      said.textContent = "";
      drawAbout(reply.body);
      $("status-h").focus();
      return;
    }
    said.textContent = told(reply.body?.error, say("That did not go just now. Try again in a minute."));
    if (reply.status === 409) {
      aboutAsked = false;
      about();
    }
  } catch {
    said.textContent = say("That did not go just now. Try again in a minute.");
  } finally {
    button.disabled = false;
  }
});

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
