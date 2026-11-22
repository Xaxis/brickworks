// What the landing page (index.html) fills from the site's own answers.
//
// At once, in the first screen (landing, 2026-11-22):
// - #shelf, real models with their pictures: Top (Trending once a week
//   has enough), New and the real sets in 3D, each a tab of one row of
//   cards. The shown tab's cards are in the page as served (tools/web/
//   home_shelf.mjs, at the deploy), asked again once the page is in; each
//   other tab is asked the first time it is opened, its skeletons holding
//   the row; what changed goes in a card for a card, its picture decoded
//   first, so nothing moves. A page with no cards in it (a checkout's own, or a
//   deploy that could read nothing) fills the tab from the answer, its
//   skeletons holding the row's place, or takes the shelf away when
//   fewer than FEWEST could come;
// - #challenge, this month's challenge with its days left (and where it
//   runs in rounds, which round and how long it has), or the next one
//   told, from /api/share?op=shelves, which says this week's pick too:
//   the first card of the first tab, marked;
// - #find, the search: its suggestions' script (web/home-find.js) asked for
//   once the field is used, and "/" puts the cursor in it.
//
// Under the first screen, as each nears it, a screen and a half ahead, so
// a visitor who never scrolls fetches none of it:
// - #talk-latest, the latest in Talk (unit talk, /api/people?op=talk_latest),
//   shown only once it answers with LEAST threads, and only while its place
//   is under the window;
// - #beta, while the beta is open: why to join, and the way in that fits
//   whoever reads it (web/betabar.js says what the server does);
// - #sets, four of the LDraw library's biggest sets with a 3D model, as
//   /library orders them by Most parts, each a link to its page.
//
// Each says how it ended on <html> (data-shelf-live, data-challenge,
// data-talk, data-sets), which tools/web/landing_check.mjs waits on.
import { signedIn } from "/account.js";
import { counted, escapeHtml, langAt, modelCard, number, pictureOf, quietPage, say } from "/card.js";
import { toast } from "/kit.js";

const MODEL = /^[A-Za-z0-9]{10}$/;
const SET = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
// As tools/web/home_shelf.mjs: the cards a tab shows, and the fewest worth a tab.
const CARDS = 10;
const FEWEST = 4;
const LEAST = 3;
const SETS = 4;
const html = document.documentElement;

/// What [path] answers as JSON, or null: a refusal is read too, since an
/// answer never read keeps the page busy.
async function ask(path) {
  try {
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
const shelves = ask("/api/share?op=shelves");

// ---------------------------------------------------------------------------
// The shelf.

const shelf = document.getElementById("shelf");
const tabs = shelf ? [...shelf.querySelectorAll('[role="tab"]')] : [];
const panelOf = (tab) => document.getElementById(tab.getAttribute("aria-controls"));
const served = shelf?.dataset.shelf === "served";

/// The cards of a list's [answer] a tab may show: real ones with pictures.
const showable = (answer) => (answer?.models || [])
  .filter((m) => m && (MODEL.test(String(m.id)) || SET.test(String(m.id))) && pictureOf(m));

/// What a card shows, to tell whether a card in its place shows the same:
/// its model, its picture (as the server names it, data-from where the
/// deploy copied it) and whether it is marked the week's pick.
function shownAs(card) {
  const img = card.querySelector("img");
  return `${card.dataset.id}|${img?.dataset.from || img?.getAttribute("src") || ""}|${card.dataset.pick ? "pick" : ""}`;
}

/// [panel]'s cards as the server has them now: its list, and on the first
/// tab this week's pick first. Each card that shows what one there does is
/// kept as it is; the rest are made and put in only once every new one's
/// picture has decoded. Fewer than FEWEST leaves what is there; a panel
/// that had only skeletons, and gets none, takes the shelf away.
async function fill(panel) {
  if (panel.dataset.live) return;
  panel.dataset.live = "asking";
  const [answer, front] = await Promise.all([ask(panel.dataset.ask), shelves]);
  const first = panel === panelOf(tabs.find((tab) => !tab.hidden) || tabs[0]);
  const pick = first && !panel.id.endsWith("-sets") && MODEL.test(String(front?.pick?.model?.id || "")) && pictureOf(front.pick.model)
    ? front.pick.model : null;
  const models = [...(pick ? [pick] : []), ...showable(answer).filter((m) => m.id !== pick?.id)].slice(0, CARDS);
  const had = [...panel.querySelectorAll(":scope > .model")];
  const byShown = new Map(had.map((card) => [shownAs(card), card]));
  const want = models.map((m, i) => `${m.id}|${pictureOf(m)}|${i === 0 && pick ? "pick" : ""}`);
  if (models.length < FEWEST || want.join() === had.map(shownAs).join()) {
    panel.dataset.live = models.length < FEWEST ? "short" : "same";
    if (!had.length && shelf) shelf.hidden = true;
    return;
  }
  const cards = await Promise.all(models.map(async (m, i) => {
    const kept = byShown.get(want[i]);
    if (kept) return kept;
    const card = modelCard(m, { pick: i === 0 && Boolean(pick) });
    return (await drawn(card.querySelector("img"))) ? card : null;
  }));
  const done = cards.filter(Boolean);
  if (done.length < FEWEST) {
    panel.dataset.live = "short";
    if (!had.length && shelf) shelf.hidden = true;
    return;
  }
  panel.replaceChildren(...done);
  panel.dataset.live = "changed";
  quietPage();
}

/// [tab] shown: its panel, See all to its list, and its cards asked again.
function choose(tab, { focus = false } = {}) {
  for (const one of tabs) {
    const on = one === tab;
    one.setAttribute("aria-selected", String(on));
    one.tabIndex = on ? 0 : -1;
    panelOf(one).hidden = !on;
  }
  const panel = panelOf(tab);
  const all = document.getElementById("shelf-all");
  if (all && panel.dataset.all) all.href = `${langAt()}${panel.dataset.all}`;
  if (focus) tab.focus();
  // A tab opened with only its markers in it (every tab but the one shown
  // first, and all of a checkout's own page): its skeletons hold the row
  // until its cards come.
  if (!panel.querySelector(".model, .skeleton-card")) {
    panel.innerHTML = Array.from({ length: 6 }, () => '<div class="skeleton-card skeleton" aria-hidden="true"><div class="frame"></div>'
      + '<div class="words"><span class="bone wide"></span><span class="bone"></span><span class="bone short"></span><span class="bone tiny"></span></div></div>').join("");
  }
  return fill(panel);
}

if (shelf) {
  const list = shelf.querySelector('[role="tablist"]');
  list.addEventListener("click", (event) => {
    const tab = event.target instanceof Element ? event.target.closest('[role="tab"]') : null;
    if (tab) choose(tab);
  });
  // The arrows, Home and End move along the tabs shown, and show each.
  list.addEventListener("keydown", (event) => {
    const shown = tabs.filter((tab) => !tab.hidden);
    const at = shown.indexOf(document.activeElement);
    if (at < 0) return;
    const to = { ArrowRight: at + 1, ArrowLeft: at - 1, Home: 0, End: shown.length - 1 }[event.key];
    if (to === undefined) return;
    event.preventDefault();
    choose(shown[(to + shown.length) % shown.length], { focus: true });
  });
  const first = tabs.find((tab) => tab.getAttribute("aria-selected") === "true") || tabs.find((tab) => !tab.hidden);
  // The page's own cards first: asked again once the page is in and idle.
  const again = () => fill(panelOf(first)).then(() => { html.dataset.shelfLive = panelOf(first).dataset.live || "none"; });
  if (served) (window.requestIdleCallback || ((work) => setTimeout(work, 200)))(again, { timeout: 3000 });
  else again();
  // Own and your lists on a set's card (web/keep.js), as a page of them asks.
  if (shelf.querySelector("[data-keep]")) import("/keep.js").catch(() => null);
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
  const c = answer?.challenge && !answer.challenge.test && ["open", "upcoming"].includes(answer.challenge.state) ? answer.challenge : null;
  html.dataset.challenge = c ? (c.state === "open" ? "open" : "next") : "none";
  if (!c) return;
  const open = c.state === "open";
  const [badge, left, go] = open ? standing(c) : [say("Coming next"), say("Opens {day}", { day: days(c.starts_on, c.starts_on) }), ""];
  document.getElementById("challenge-when").textContent = badge;
  const leftBadge = document.getElementById("challenge-left");
  leftBadge.textContent = left;
  leftBadge.hidden = false;
  const name = document.getElementById("challenge-h");
  name.textContent = String(c.title || "");
  name.lang = "en";
  const brief = document.getElementById("challenge-brief");
  if (c.brief) {
    brief.textContent = String(c.brief);
    brief.lang = "en";
  }
  // Its days in place of the line held for them, so nothing under it moves.
  const span = days(c.starts_on, c.ends_on);
  if (span) document.getElementById("challenge-days").textContent = span;
  const link = document.getElementById("challenge-go");
  if (go) link.textContent = go;
  if (c.id) link.href = `${langAt()}/challenge`;
}
challenge();

// ---------------------------------------------------------------------------
// Under the first screen.

/// [show] once [place] is under the window, now or once it is again after
/// a scroll, so what it puts in moves nothing in view (docs/DESIGN_SYSTEM.md,
/// Out of sight).
function whenUnder(place, show) {
  const under = () => !place || place.getBoundingClientRect().top >= innerHeight;
  const now = () => {
    if (!under()) return false;
    removeEventListener("scroll", now);
    show();
    return true;
  };
  if (!now()) addEventListener("scroll", now, { passive: true });
}

/// The latest in Talk (unit talk: GET /api/people?op=talk_latest&html=1,
/// {count, html}, its rows drawn on the server as Talk's own, every word
/// typed in them escaped there): shown once LEAST threads come, never an
/// empty box; a site without Talk, or with too little, leaves it hidden.
async function talk() {
  const band = document.getElementById("talk-latest");
  const list = band?.querySelector("[data-talk-strip]");
  if (!band || !list) return;
  // Asked only on a site that has Talk, which the header links to once it
  // is in (web/_shell.html): before, the ask would answer 400 and log an
  // error on every visit (tools/web/site_check.mjs).
  if (!document.querySelector('.site-head a[href$="/talk"]')) {
    html.dataset.talk = "none";
    return;
  }
  const code = langAt().slice(1);
  // The checks' own pool where the address asks for it (?tests=1), as Talk's pages.
  const tests = new URLSearchParams(location.search).get("tests") === "1";
  const answer = await ask(`/api/people?op=talk_latest&n=${Number(band.dataset.n) || 4}&html=1${code ? `&lang=${code}` : ""}`
    + (tests ? "&tests=1" : ""));
  const count = typeof answer?.html === "string" ? Number(answer.count) || 0 : 0;
  html.dataset.talk = count >= LEAST ? String(count) : "none";
  if (count < LEAST) return;
  list.innerHTML = answer.html;
  band.dataset.filled = String(count);
  // Its link only now: a page with no Talk links nowhere it would 404.
  document.getElementById("talk-all")?.setAttribute("href", `${langAt()}/talk`);
  whenUnder(band.nextElementSibling, () => { band.hidden = false; });
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
  whenUnder(band.nextElementSibling, () => { html.dataset.beta = "open"; });
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

// The talk's place is hidden until it has talk, so the section under it says when it nears.
near("community", talk);
// The sets' own tile, not the section it ends: the shorter home page has
// #why within a screen and a half of the top, so its four pictures (139 KB
// with their list) came with the first screen, which shows none of them.
near("sets", sets);
