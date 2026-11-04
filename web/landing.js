// What the landing page (index.html) fills from the site's own answers as
// each part nears the screen, a screen and a half ahead, so it is in by
// the time it is read, and a visitor who never scrolls fetches none of it:
//
// - #made, its first model in 3D in its picture's place (web/start3d.js,
//   its looks in web/view3d.css), both asked for as the section nears;
// - #sets, four of the LDraw library's biggest sets with a 3D model, as
//   /library orders them by Most parts, each a link to its page;
// - #challenge, this month's challenge, or the next one told;
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
import { collectionCard, counted, escapeHtml, langAt, modelCard, pictureOf, say } from "/card.js";

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

/// This month's challenge (GET /api/people?op=challenge): its name, brief,
/// days and entries, and Enter; between challenges the next one told.
/// Its name and brief are Brickworks' own words, in English as written.
async function challenge() {
  const tile = document.getElementById("challenge");
  if (!tile) return;
  const answer = await ask("/api/people?op=challenge");
  const now = answer?.challenge && answer.challenge.state === "open" && !answer.challenge.test ? answer.challenge : null;
  const next = !now && answer?.next && !answer.next.test ? answer.next : null;
  const shown = now || next;
  html.dataset.challenge = now ? "open" : next ? "next" : "none";
  if (!shown) return;
  const entries = now ? (now.groups || []).reduce((n, group) => n + (group.entries || []).length, 0) : 0;
  const line = [days(shown.starts_on, shown.ends_on), entries ? counted(entries, "entry", "entries") : ""].filter(Boolean).join(" · ");
  document.getElementById("challenge-when").textContent = say(now ? "This month" : "Coming next");
  const name = document.getElementById("challenge-h");
  name.textContent = String(shown.title || "");
  name.lang = "en";
  const brief = document.getElementById("challenge-brief");
  brief.textContent = String(shown.brief || "");
  brief.lang = "en";
  const when = document.getElementById("challenge-days");
  when.textContent = line;
  when.hidden = !line;
  if (now) document.getElementById("challenge-go").textContent = say("Enter the challenge");
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

// The beta's line under the last offer, only while it is open
// (GET /api/plans?op=beta_spots: {beta: "open", left} or anything else).
async function beta() {
  const line = document.getElementById("beta");
  if (!line) return;
  const body = await ask("/api/plans?op=beta_spots");
  if (body?.beta === "open") line.hidden = false;
}
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
near("community", () => {
  challenge();
  top();
});
