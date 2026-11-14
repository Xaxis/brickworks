// The toast (docs/DESIGN_SYSTEM.md, Toast; site.css .toast): one line at the
// foot of the screen that says what just happened ("Link copied"), read out
// by a screen reader and gone in a moment. With an action it is a snackbar,
// as Material's and Gmail's are: what was just done, where to change it
// again, and Undo; it stays while it is pointed at or holds the keyboard,
// and Escape puts it away (bugbar, 2026-11-13: the beta bar's ×).
//
// Nothing happens on loading this: web/kit.js passes it on and puts the
// empty region on the page at load, and web/betabar.js, which every page
// loads (the console's too, which has no kit), imports it alone.

const PLAIN_MS = 2400;
// Long enough to read a sentence and reach Undo (WCAG 2.2.1), and again
// after the pointer or the keyboard leaves it.
const ACTION_MS = 8000;
const AGAIN_MS = 4000;

let timer = 0;
// The toast with an action now on the screen: its end, which puts it away.
let ending = null;

/// The toast's region. On the page empty from the first: a screen reader
/// reads a live region's change, not a region that arrives saying
/// something, so the words are put in a moment after it is there.
export function toastRegion() {
  let said = document.querySelector("body > .toast");
  if (!said) {
    said = document.createElement("div");
    said.className = "toast";
    said.setAttribute("role", "status");
    said.setAttribute("aria-live", "polite");
    document.body.append(said);
  }
  return said;
}

/// Says [words] in the toast ("Link copied") and takes it away after a
/// moment; the same words twice are said twice. With [action] ({label,
/// run}), a button beside the words, which runs it and puts the toast away;
/// [words] may then hold elements (a link) as well as text, [focus] gives
/// the button the keyboard, and [back] is where the keyboard goes when the
/// toast goes without it being pressed.
export function toast(words, { action = null, focus = false, back = null } = {}) {
  const said = toastRegion();
  ending?.(false);
  clearTimeout(timer);
  said.replaceChildren();
  said.classList.remove("act");
  timer = setTimeout(() => {
    if (!action) {
      said.textContent = String(words);
      said.classList.add("shown");
      timer = setTimeout(() => said.classList.remove("shown"), PLAIN_MS);
      return;
    }
    const text = document.createElement("span");
    text.className = "words";
    text.append(...(Array.isArray(words) ? words : [words]));
    const button = document.createElement("button");
    button.type = "button";
    button.className = "toast-act";
    button.textContent = action.label;
    said.append(text, button);
    said.classList.add("act", "shown");
    const heard = new AbortController();
    const on = { signal: heard.signal };
    const end = (pressed) => {
      if (ending !== end) return;
      ending = null;
      heard.abort();
      clearTimeout(timer);
      const held = said.contains(document.activeElement);
      said.classList.remove("shown");
      button.tabIndex = -1;
      // Gone from the keyboard's way once it has faded.
      setTimeout(() => {
        if (!ending && !said.classList.contains("shown")) {
          said.replaceChildren();
          said.classList.remove("act");
        }
      }, 250);
      if (!pressed && held && back?.isConnected) back.focus({ preventScroll: true });
    };
    ending = end;
    const later = (ms) => {
      clearTimeout(timer);
      timer = setTimeout(() => end(false), ms);
    };
    const holding = () => said.matches(":hover") || said.contains(document.activeElement);
    button.addEventListener("click", () => {
      end(true);
      action.run();
    }, on);
    said.addEventListener("pointerenter", () => clearTimeout(timer), on);
    said.addEventListener("focusin", () => clearTimeout(timer), on);
    said.addEventListener("pointerleave", () => holding() || later(AGAIN_MS), on);
    said.addEventListener("focusout", (event) => said.contains(event.relatedTarget) || holding() || later(AGAIN_MS), on);
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && said.contains(document.activeElement)) end(false);
    }, on);
    later(ACTION_MS);
    if (focus) button.focus({ preventScroll: true });
  }, 60);
}
