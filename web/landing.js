// What the landing page (index.html) fills from the site's own answers as
// each part nears the screen, a screen and a half ahead, so it is in by
// the time it is read, and a visitor who never scrolls fetches none of it:
//
// - #beta, while the beta is open: why to join, and the way in that fits
//   whoever reads it (web/betabar.js says what the server does);
// - #made, its first model in 3D in its picture's place (web/start3d.js,
//   its looks in web/view3d.css), both asked for as the section nears;
// - #sets, four of the LDraw library's biggest sets with a 3D model, as
//   /library orders them by Most parts, each a link to its page;
// - #now, at once, under the app's picture: #challenge, this month's
//   challenge with its days left (and where it runs in rounds, which round
//   and how long it has), or the next one told; and #pick, This week's pick
//   from the gallery (challengehonours: both within the first two screens);
// - #top, the gallery's Top builds as the gallery orders them, then its
//   collections, each drawn as web/card.js draws every card.
//
// None may show a dead picture. So a card or a set goes in only once its
// picture has arrived and decoded, and the row only once three have (the
// sets: four); until then the row holds skeletons at a card's size
// (site.css .skeleton) and the sets their ground, so the page under them
// stays where it is. An answer that does not come takes #top away and
// leaves the sets' tile and the challenge's with their own words. Each says
// how it ended on <html> (data-strip, data-sets, data-challenge), which
// tools/web/landing_check.mjs waits on.
import { signedIn } from "/account.js";
import { collectionCard, counted, escapeHtml, langAt, modelCard, number, pictureOf, say } from "/card.js";
import { toast } from "/kit.js";

const GALLERY = /^[A-Za-z0-9]{10}$/;
const SET = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
const LIST = /^[A-Za-z0-9]{10}$/;
const MOST = 8;
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

/// [card] once its picture is in, or null.
const ready = async (card) => ((await drawn(card.querySelector("img"))) ? card : null);

/// The gallery's Top, less the models #made already shows, then its
/// collections: shown once three cards have their pictures, else taken away.
async function top() {
  const where = document.getElementById("top");
  const row = document.getElementById("top-models");
  if (!where || !row) return;
  const shown = new Set([...document.querySelectorAll("#made a[href]")]
    .map((a) => (/\/m\/([A-Za-z0-9]{10})$/.exec(a.getAttribute("href")) || [])[1]).filter(Boolean));
  const [listed, lists] = await Promise.all([ask("/api/share?op=list&page=1&sort=top"), ask("/api/people?op=collections")]);
  const models = (listed?.models || []).filter((m) => m && GALLERY.test(String(m.id)) && !shown.has(String(m.id)) && pictureOf(m))
    .slice(0, MOST);
  const collections = (lists?.collections || []).filter((c) => c && LIST.test(String(c.id)) && Array.isArray(c.covers) && c.covers.length)
    .slice(0, 2);
  const cards = [...models.map((m) => modelCard(m)), ...collections.map((c) => collectionCard(c))];
  const done = (await Promise.all(cards.map((card) => ready(card).catch(() => null)))).filter(Boolean);
  html.dataset.strip = done.length >= LEAST ? String(done.length) : "none";
  if (done.length < LEAST) {
    where.hidden = true;
    return;
  }
  row.replaceChildren(...done);
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

/// This month's challenge and This week's pick (GET /api/share?op=shelves,
/// the gallery front's own answer): the challenge's name, brief, days and
/// days left, and the way in; between challenges the next one told; and
/// the week's pick as a picture beside its name. Their names and briefs are
/// their makers' words, as written. A test challenge is never shown here.
async function now() {
  const tile = document.getElementById("challenge");
  if (!tile) return;
  const answer = await ask("/api/share?op=shelves");
  const c = answer?.challenge && !answer.challenge.test && ["open", "upcoming"].includes(answer.challenge.state) ? answer.challenge : null;
  html.dataset.challenge = c ? (c.state === "open" ? "open" : "next") : "none";
  if (c) {
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
  week(answer?.prompt_now || null);
  pick(answer?.pick?.model || null);
}

/// This week's quick build ([w], the answer's prompt_now: api/_prompts.js
/// promptNow), in its line under the month's: its name, to its page, where
/// Start is. None, the line keeps its own words. A test one never.
function week(w) {
  const line = document.getElementById("challenge-week");
  if (!line || !w || w.test || !/^[1-9][0-9]{0,15}$/.test(String(w.id))) return;
  const go = document.createElement("a");
  go.id = "challenge-week-go";
  go.href = `${langAt()}/challenge?id=${w.id}`;
  go.textContent = String(w.title || "");
  go.lang = "en";
  const [before, after = ""] = say("This week’s quick build: {title}").split("{title}");
  line.replaceChildren(before, go, after);
  html.dataset.week = "shown";
}

/// This week's pick: its picture, once it has arrived (never a dead one),
/// beside its name and its designer; none, the tile keeps its own words
/// and goes to the gallery.
async function pick(m) {
  html.dataset.pick = m && GALLERY.test(String(m.id)) ? "shown" : "none";
  if (!m || !GALLERY.test(String(m.id))) return;
  const link = document.getElementById("pick-go");
  link.href = `/m/${m.id}`;
  const name = document.getElementById("pick-name");
  name.textContent = String(m.name || "");
  name.translate = false;
  const by = m.by?.name || m.author || "";
  document.getElementById("pick-by").textContent = by ? say("by {who}", { who: by }) : "";
  link.setAttribute("aria-label", say("This week’s pick: {name}", { name: String(m.name || "") }));
  const src = pictureOf(m);
  if (!src) return;
  const img = document.getElementById("pick-img");
  img.src = src;
  img.alt = "";
  if (await drawn(img)) img.hidden = false;
}

/// The first model in 3D in its picture's place, its code and looks asked
/// for only now.
function view3d() {
  const picture = document.querySelector("#made .picture[data-scene]");
  if (!picture) return;
  const looks = Object.assign(document.createElement("link"), { rel: "stylesheet", href: "/view3d.css" });
  document.head.append(looks);
  import("/start3d.js").then(({ start3d }) => start3d(picture)).catch(() => { /* the picture stays the app's link */ });
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
/// once it is again, so nothing in view moves (docs/DESIGN_SYSTEM.md, Out of
/// sight). Off, it is not drawn; not heard, a held one stays as it was.
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
  const next = document.getElementById("made");
  const under = () => !next || next.getBoundingClientRect().top >= innerHeight;
  const show = () => {
    if (!under()) return false;
    html.dataset.beta = "open";
    removeEventListener("scroll", show);
    return true;
  };
  if (!show()) addEventListener("scroll", show, { passive: true });
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

// The 3D view's code once its picture is in the window: an opening
// screen that reaches the section does not ask for it.
near("made-lead", view3d, "0px");
near("why", sets);
// This month's challenge and This week's pick: at once, in the first two screens.
now();
near("community", top);
