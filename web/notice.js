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
// in this browser; a new one shows.
//
// The words are put on the page as text.
import { iconHtml, say } from "/card.js";

const KEPT = "brickworks.notice";
const HIDDEN = "brickworks.notice.hidden";
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

/// The notice's words in the page's language where the owner typed them.
function wordsOf(notice) {
  const lang = String(root.lang || "en").slice(0, 2);
  const words = notice?.words || {};
  return typeof words[lang] === "string" && words[lang] ? words[lang] : String(words.en || "");
}

let shown = null;

/// [notice] shown, or none when it is null or hidden here.
function draw(notice) {
  const hidden = read(HIDDEN);
  const words = notice ? wordsOf(notice) : "";
  const want = notice && words && Number(hidden) !== Number(notice.id) ? notice : null;
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
  const notice = heard?.notice && heard.notice.id ? { id: heard.notice.id, words: heard.notice.words, tone: heard.notice.tone } : null;
  write(KEPT, notice);
  // A hidden one cleared: nothing to keep hidden.
  if (!notice) write(HIDDEN, null);
  draw(notice);
}

draw(read(KEPT));
ask();
