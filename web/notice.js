// The site's notice (console3, 2026-11-13): what the owner set in the
// console (/admin#switches, api/_console_switches.js) shown on every page,
// as a card floating at the window's foot that moves nothing in the page
// (docs/DESIGN_SYSTEM.md, Site notice; Steady loads), until its × hides it.
// web/theme.js asks for it on every page but an embed's card and the
// connector's consent page, as it asks for the beta's bar.
//
// Its words are the page's language's where the owner typed them (German,
// French, Spanish), else English: never a machine's translation. The last
// one heard is kept in this browser, so the next page shows it at once, and
// asked again (/api/plans?op=notice, kept a minute by the CDN): a notice
// cleared goes, a new one comes. Hidden by its ×, that notice stays hidden
// in this browser; a new one shows. Signed in, it is hidden for the person
// too (api/_announce.js noticeHide), in every browser of theirs: before it
// is drawn on any page, the avatar's count says which notices they hid
// (op=feed_count's notice_hidden, asked by web/follow.js on every page with
// the header's account), so a browser that showed it before stops at its
// next page, and one that never did shows it not even for a moment; on a
// page without the header, or a server from before supabase/announce2.sql,
// the page asks of its own (op=notice_hidden) (anfix, 2026-11-18). And it
// goes by itself at its end, the owner's choice (supabase/announce.sql),
// from a page left open too.
//
// The words are put on the page as text.
import { iconHtml, say } from "/card.js";

const KEPT = "brickworks.notice";
const HIDDEN = "brickworks.notice.hidden";
// How long a notice waits for the avatar's count before it asks of its own.
const COUNT_WAIT_MS = 4000;
const root = document.documentElement;

function read(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || "null");
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // A browser that keeps nothing asks again on the next page.
  }
}

const pageLang = () => String(root.lang || "en").slice(0, 2);

/// The notice's words in the page's language where the owner typed them,
/// else in English: {words, lang}.
function wordsOf(notice) {
  const lang = pageLang();
  const words = notice?.words || {};
  return typeof words[lang] === "string" && words[lang] ? { words: words[lang], lang } : { words: String(words.en || ""), lang: "en" };
}

let shown = null;
let ending = 0;

/// Whether [notice]'s end has come.
const ended = (notice) => Boolean(notice?.ends_at) && Date.parse(notice.ends_at) <= Date.now();

/// The person signed in in this browser, if one is, as account.js keeps
/// them: asked of it only once there is a notice to show.
const account = () => import("/account.js").catch(() => null);

/// [notice] hidden for the person signed in, in every browser of theirs.
async function hideForThem(notice) {
  const kept = await account();
  if (!kept?.signedIn()) return;
  kept.call("/api/plans?op=notice_hide", { method: "POST", body: { id: Number(notice.id) }, keepalive: true }).catch(() => null);
}

/// Whether the person signed in hid [notice], in any browser: on every page,
/// never kept, since they may hide it elsewhere at any moment. False signed
/// out; null when it could not be known (shown, as before they could hide
/// it for themselves).
async function hiddenByThem(notice) {
  const kept = await account();
  if (!kept?.signedIn()) return false;
  // The avatar's count, which this page asks anyway (web/follow.js).
  if (document.querySelector(".site-head a[data-account]") && kept.feedCountHeard) {
    const heard = await kept.feedCountHeard(COUNT_WAIT_MS);
    if (Array.isArray(heard?.notice_hidden)) return heard.notice_hidden.map(Number).includes(Number(notice.id));
  }
  const answer = await kept.call(`/api/plans?op=notice_hidden&id=${Number(notice.id)}`).catch(() => null);
  if (!answer || answer.status !== 200) return null;
  return answer.body?.hidden === true;
}

let showing = 0;

/// [notice] shown once it is known the person did not hide it (signed out:
/// at once), so it never shows only to go again.
async function show(notice) {
  const mine = ++showing;
  if (notice && !ended(notice) && Number(read(HIDDEN)) !== Number(notice.id)) {
    const hid = await hiddenByThem(notice);
    // A newer notice heard while this one was asked about: that one's.
    if (mine !== showing) return;
    if (hid === true) write(HIDDEN, notice.id);
  }
  draw(notice);
}

/// [notice] shown, or none when it is null, hidden here, or past its end.
function draw(notice) {
  const hidden = read(HIDDEN);
  const { words, lang } = notice ? wordsOf(notice) : { words: "", lang: "en" };
  const want = notice && words && !ended(notice) && Number(hidden) !== Number(notice.id) ? notice : null;
  clearTimeout(ending);
  // At its end it goes, from a page left open too.
  if (want?.ends_at) ending = setTimeout(() => draw(want), Math.min(Math.max(0, Date.parse(want.ends_at) - Date.now()) + 250, 2 ** 31 - 1));
  if (shown && (!want || shown.dataset.id !== String(want.id) || shown.querySelector(".words").textContent !== words)) {
    shown.remove();
    shown = null;
    delete root.dataset.notice;
  }
  if (!want || shown) return;
  const card = document.createElement("aside");
  card.className = `site-notice${want.tone === "warn" ? " warn" : ""}`;
  card.dataset.id = String(want.id);
  card.setAttribute("aria-label", say("Site notice"));
  const text = document.createElement("p");
  text.className = "words";
  text.textContent = words;
  // Its own direction (an Arabic or Hebrew notice reads right to left), and
  // English named as English where it stands in on a German, French or
  // Spanish page, so a screen reader speaks it as English.
  text.dir = "auto";
  if (lang !== pageLang()) text.lang = lang;
  const close = document.createElement("button");
  close.type = "button";
  close.className = "icon-btn small";
  close.setAttribute("aria-label", say("Close"));
  close.innerHTML = iconHtml("close");
  close.addEventListener("click", () => {
    write(HIDDEN, want.id);
    card.remove();
    shown = null;
    delete root.dataset.notice;
    hideForThem(want);
  });
  card.append(text, close);
  document.body.append(card);
  shown = card;
  root.dataset.notice = want.tone === "warn" ? "warn" : "info";
  // Risen in after the page is drawn, as the beta's bar is.
  requestAnimationFrame(() => requestAnimationFrame(() => card.classList.add("shown")));
}

async function ask() {
  let heard;
  try {
    const reply = await fetch("/api/plans?op=notice", { headers: { accept: "application/json" } });
    if (!reply.ok) return;
    heard = await reply.json();
  } catch {
    return;
  }
  const notice = heard?.notice && heard.notice.id ? { id: heard.notice.id, words: heard.notice.words, tone: heard.notice.tone,
    ends_at: heard.notice.ends_at ?? null } : null;
  write(KEPT, notice);
  // A hidden one cleared: nothing to keep hidden.
  if (!notice) write(HIDDEN, null);
  show(notice);
}

show(read(KEPT));
ask();
