// The scroller's behaviour (docs/DESIGN_SYSTEM.md "Scroller", site.css
// "the scroller"): every .scroller, .tabs, .table and docs .code > pre on
// the page, those there at load and those a page draws later. As each
// scrolls, changes size or is filled, three things are kept true:
//
//   its data-more says which sides have more ("start", "end", "start
//     end"), and site.css fades those edges out;
//   a row of items (a .scroller that is not a box) has Previous and Next
//     after it, tied to its two ends, each hidden at its own end, which
//     scroll a page of items; site.css shows them to a mouse alone;
//   one that overflows with nothing inside to focus takes the focus
//     itself (tabindex="0"), so the keyboard reaches and scrolls it, and
//     gives it back once it fits.
//
// web/kit.js loads it on every page that has the kit; a page without the
// kit imports it itself (/admin).
import { iconHtml } from "./card.js";

const SCROLLERS = ".scroller, .tabs, .table, .code > pre";
const FOCUSABLE = "a[href], button, input, select, textarea, summary, [tabindex]";

/// Each scroller started: its Previous and Next, if it has them.
const started = new WeakMap();
let named = 0;

/// The row's name, said after Previous and Next: its aria-label, or the
/// words of what labels it.
function nameOf(el) {
  const by = (el.getAttribute("aria-labelledby") || "").split(/\s+/).filter(Boolean)
    .map((id) => document.getElementById(id)?.textContent.trim().replace(/\s+/g, " ") || "").join(" ");
  return (el.getAttribute("aria-label") || by).trim();
}

/// Previous and Next for [el], put after it (an anchored element comes
/// after its anchor) and tied to its ends by its anchor name.
function buttonsFor(el) {
  named += 1;
  const anchor = `--scroller-${named}`;
  el.style.setProperty("anchor-name", anchor);
  const name = nameOf(el);
  const make = (way, words, icon) => {
    const button = document.createElement("button");
    button.type = "button";
    // Its own names: a bare "next" was also the model page's rows
    // (section.next), whose top margin it took, and a flow counting
    // the page's last row of cards found this button (rel-m218).
    button.className = `icon-btn small scroller-go scroller-${way}`;
    button.setAttribute("aria-label", name ? `${words}: ${name}` : words);
    button.innerHTML = iconHtml(icon);
    button.hidden = true;
    button.style.setProperty("position-anchor", anchor);
    button.addEventListener("click", () => turn(el, way === "back" ? -1 : 1));
    return button;
  };
  const go = [make("back", "Previous", "back"), make("next", "Next", "next")];
  el.after(...go);
  return go;
}

/// Scrolls [el] a page of items on ([way] 1) or back (-1): on, the first
/// item not wholly in view comes to rest first; back, the first in view
/// goes to the far end. What is in view is the row less its scroll-padding,
/// where Previous and Next and the fades are.
function turn(el, way) {
  const style = getComputedStyle(el);
  const before = parseFloat(style.scrollPaddingLeft) || 0;
  const after = parseFloat(style.scrollPaddingRight) || 0;
  const view = el.clientWidth - before - after;
  const box = el.getBoundingClientRect();
  // Where the row is scrolled to when an item rests at the start.
  const rest = (item) => item.getBoundingClientRect().left - box.left - el.clientLeft + el.scrollLeft - before;
  const items = [...el.children].filter((item) => item.getClientRects().length);
  const at = el.scrollLeft;
  let to;
  if (way > 0) {
    const cut = items.find((item) => rest(item) + item.getBoundingClientRect().width > at + view + 1);
    to = cut ? rest(cut) : Infinity;
    if (to <= at + 1) to = at + view;
  } else {
    const first = items.find((item) => rest(item) >= at - view - 1);
    to = first ? rest(first) : 0;
    if (to >= at - 1) to = at - view;
  }
  el.scrollTo({ left: Math.max(0, Math.min(el.scrollWidth - el.clientWidth, to)) });
}

/// Says what [el] has more of, shows its Previous and Next as it does, and
/// gives it the focus while it overflows with nothing inside to take it.
function measure(el) {
  const go = started.get(el);
  if (!go) return;
  const most = el.scrollWidth - el.clientWidth;
  const back = most > 1 && el.scrollLeft > 1;
  const on = most > 1 && el.scrollLeft < most - 1;
  const more = [back && "start", on && "end"].filter(Boolean).join(" ");
  if (more !== (el.getAttribute("data-more") || "")) {
    if (more) el.setAttribute("data-more", more);
    else el.removeAttribute("data-more");
  }
  if (go.length) {
    const had = go.find((button) => button === document.activeElement);
    go[0].hidden = !back;
    go[1].hidden = !on;
    // Pressed to its end, it hides: the focus goes to the other, or into
    // the row, never to the page's body.
    if (had?.hidden) (go.find((button) => !button.hidden) || el.querySelector(FOCUSABLE))?.focus({ preventScroll: true });
  }
  if (most > 1 && !el.hasAttribute("tabindex") && !el.querySelector(FOCUSABLE)) {
    el.tabIndex = 0;
    el.setAttribute("data-focus-given", "");
  } else if (most <= 1 && el.hasAttribute("data-focus-given")) {
    el.removeAttribute("tabindex");
    el.removeAttribute("data-focus-given");
  }
}

const queued = new Set();
function later(el) {
  if (!queued.size) {
    requestAnimationFrame(() => {
      for (const one of queued) measure(one);
      queued.clear();
    });
  }
  queued.add(el);
}

if (typeof document !== "undefined" && "ResizeObserver" in window) {
  const sized = new ResizeObserver((entries) => {
    for (const entry of entries) later(entry.target);
  });
  // What is in it changed: cards put in, a tab's count, a pill's words.
  const filled = new MutationObserver((changes) => {
    for (const change of changes) {
      const el = change.target.closest?.(SCROLLERS) || change.target.parentElement?.closest(SCROLLERS);
      if (el && started.has(el)) later(el);
    }
  });
  const start = (el) => {
    if (started.has(el)) return;
    started.set(el, el.matches(".scroller:not(.card)") ? buttonsFor(el) : []);
    sized.observe(el);
    filled.observe(el, { childList: true, subtree: true, characterData: true });
    later(el);
  };
  document.addEventListener("scroll", (event) => {
    if (started.has(event.target)) later(event.target);
  }, { capture: true, passive: true });
  for (const el of document.querySelectorAll(SCROLLERS)) start(el);
  new MutationObserver((changes) => {
    for (const change of changes) {
      for (const node of change.addedNodes) {
        if (node.nodeType !== 1) continue;
        if (node.matches(SCROLLERS)) start(node);
        for (const el of node.querySelectorAll(SCROLLERS)) start(el);
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true });
  // The site's own faces come after the first layout, and change a row's width.
  document.fonts?.ready.then(() => {
    for (const el of document.querySelectorAll(SCROLLERS)) if (started.has(el)) later(el);
  });
}
