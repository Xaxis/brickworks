// The ask, where the law wants a yes before counting (insights, 2026-11-18;
// web/counting.js, /counting): a card at the window's foot, at its left, so
// the site's notice keeps its right, moving nothing in the page. Asked on
// site pages only, never in the studio, and only once a browser has said
// neither. Its answer is kept in this browser and can be changed in
// Settings › Privacy, which this wires too (#counting-on).
//
// By keyboard (inreview M5): the card is the page's first stop, before the
// skip link, so it is reached at once and not after the whole page; Escape
// closes it unanswered, as its close button does (nothing counted, the next
// page asks again); and once it is gone focus goes back where it was before
// it came into the card, or, when it came from nowhere, on to the stop after
// the card, so the next Tab goes on through the page.
import { iconHtml, langAt, say } from "/card.js";
import { browserSaysNo, countingState, setCounting } from "/counting.js";

let card = null;
// What a key can stop on, in the page's order.
const STOPS = "a[href], button:not([disabled]), input:not([disabled]):not([type=hidden]), select:not([disabled]), "
  + "textarea:not([disabled]), [tabindex]:not([tabindex='-1'])";

// The site notice's card (web/site.css .site-notice), at the window's left
// so the notice keeps its right; over the notice on a phone, where both
// span the window. Its own class: nothing that reads the notice finds it.
const LOOK = `.count-ask { position: fixed; z-index: 55; left: var(--s-4); bottom: calc(var(--s-4) + env(safe-area-inset-bottom, 0px));
  display: flex; align-items: flex-start; gap: var(--s-2); width: min(420px, calc(100vw - 32px));
  padding: var(--s-3) var(--s-2) var(--s-3) var(--s-4); border: 1px solid var(--line-strong);
  border-left: 4px solid var(--accent-edge); border-radius: var(--r-3);
  background: color-mix(in srgb, var(--panel) 92%, transparent);
  backdrop-filter: saturate(1.6) blur(16px); -webkit-backdrop-filter: saturate(1.6) blur(16px);
  box-shadow: var(--highlight), var(--shadow); color: var(--ink); opacity: 0; transform: translateY(8px);
  transition: opacity var(--motion-open) var(--ease), transform var(--motion-open) var(--ease); }
.count-ask.shown { opacity: 1; transform: none; }
.count-ask .body { flex: 1 1 auto; min-width: 0; }
.count-ask .words { margin: 6px 0 0; font-size: var(--t-small); line-height: 1.5; overflow-wrap: anywhere; }
.count-ask .row { display: flex; flex-wrap: wrap; gap: var(--s-2); margin-top: var(--s-2); }
.count-ask .icon-btn.small { flex: none; border-color: transparent; background: transparent; color: var(--ink-soft); }
.count-ask .icon-btn.small:hover { background: var(--panel-hi); color: var(--ink); }
@media (width < 900px) { :root[data-betabar] .count-ask { bottom: calc(var(--s-4) + 64px + env(safe-area-inset-bottom, 0px)); } }
@media (width < 600px) { .count-ask { right: 0; left: 0; margin-inline: auto; }
  :root[data-notice] .count-ask { bottom: calc(var(--s-4) + 120px + env(safe-area-inset-bottom, 0px)); } }
@media (prefers-reduced-motion: reduce) { .count-ask { transition: none; } }`;

/// The ask shown, unless it is answered, shown already, or the browser said no.
export function ask() {
  if (card || countingState() !== "ask") return;
  if (!document.getElementById("count-ask-look")) {
    const look = document.createElement("style");
    look.id = "count-ask-look";
    look.textContent = LOOK;
    document.head.append(look);
  }
  card = document.createElement("aside");
  card.className = "count-ask";
  card.setAttribute("aria-label", say("Counting visits"));
  const words = document.createElement("p");
  words.className = "words";
  words.textContent = say("May Brickworks count how you use it? Never your models, what you type, your email address or your IP address.");
  const more = document.createElement("a");
  more.href = `${langAt()}/counting`;
  more.textContent = say("What is counted");
  words.append(" ", more);
  const yes = document.createElement("button");
  yes.type = "button";
  yes.className = "cta small";
  yes.textContent = say("Yes, count");
  const no = document.createElement("button");
  no.type = "button";
  no.className = "cta ghost small";
  no.textContent = say("No");
  const close = document.createElement("button");
  close.type = "button";
  close.className = "icon-btn small";
  close.setAttribute("aria-label", say("Ask me later"));
  close.innerHTML = iconHtml("close");
  // Where focus was before it came into the card.
  let before = null;
  card.addEventListener("focusin", (event) => {
    if (!before && event.relatedTarget instanceof HTMLElement && !card.contains(event.relatedTarget)) before = event.relatedTarget;
  });
  // [keyed]: answered by a key, so focus lands where a key can go on from.
  const answer = (on, keyed) => {
    if (on !== null) setCounting(on);
    const had = card.contains(document.activeElement);
    card.remove();
    card = null;
    if (!had) return;
    if (before?.isConnected && before !== document.body) before.focus({ preventScroll: true });
    else if (keyed) {
      const stop = [...document.body.querySelectorAll(STOPS)].find((el) => el.getClientRects().length || el.matches(".skip"));
      stop?.focus({ preventScroll: true });
    }
  };
  // A click by Enter or Space has no pointer (its detail is 0).
  yes.addEventListener("click", (event) => answer(true, event.detail === 0));
  no.addEventListener("click", (event) => answer(false, event.detail === 0));
  // Closed unanswered: nothing is counted, and the next page asks again.
  close.addEventListener("click", (event) => answer(null, event.detail === 0));
  card.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || event.defaultPrevented) return;
    event.preventDefault();
    answer(null, true);
  });
  const row = document.createElement("div");
  row.className = "row";
  row.append(yes, no);
  const body = document.createElement("div");
  body.className = "body";
  body.append(words, row);
  card.append(body, close);
  // First in the page, so first by Tab; it is fixed at the window's foot, so where it sits moves nothing.
  document.body.prepend(card);
  requestAnimationFrame(() => requestAnimationFrame(() => card?.classList.add("shown")));
}

/// Settings › Privacy: the choice, as this browser has it, and changed.
export function wireSetting(box = document.getElementById("counting-on"), said = document.getElementById("counting-said")) {
  if (!box) return;
  const draw = () => {
    const state = countingState();
    box.checked = state === "yes" || state === "on";
    box.disabled = state === "browser";
    if (said) {
      said.textContent = state === "browser"
        ? say("Your browser asks sites not to track it (Do Not Track or Global Privacy Control), so nothing is counted.")
        : state === "check" ? say("This browser is driven by a program, so nothing is counted.")
          : box.checked ? say("Counted in this browser.") : say("Not counted in this browser.");
    }
  };
  box.addEventListener("change", () => {
    if (browserSaysNo()) return draw();
    setCounting(box.checked);
    // The ask, if it is up, has its answer.
    card?.remove();
    card = null;
    draw();
  });
  draw();
}

if (document.getElementById("counting-on")) wireSetting();
