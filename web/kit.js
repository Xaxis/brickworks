// The site's kit, as strings and one behaviour (site.css "the kit",
// docs/DESIGN_SYSTEM.md): an avatar made from a handle, an icon from the
// sprite, an icon button that says its name and count, the toast, and the
// "more" menu closing on a click elsewhere. The avatar, the icons and the
// icon button are pure string functions made in web/card.js, which draws
// them on every card and which a deployment copies alone beside its
// functions, so a server page draws them as a browser does: passed on from
// here, so a page asks the kit for the whole kit. And every scroller on the
// page (web/scroller.js), and the page's words in its language (say).
export { ICONS, avatarHtml, avatarTone, awardsHtml, iconButtonHtml, iconHtml, number, say } from "./card.js";
import { say } from "./card.js";
import { toastRegion } from "./toast.js";
import "./scroller.js";
// The toast, and with an action the snackbar (web/toast.js).
export { toast } from "./toast.js";

// In the page's language (web/theme.js), English as en-GB writes a date.
const LANG = globalThis.document?.documentElement.lang || "en";
const AGO = new Intl.RelativeTimeFormat(LANG, { numeric: "auto" });
const DATE = new Intl.DateTimeFormat(LANG === "en" ? "en-GB" : LANG, { day: "numeric", month: "short" });

/// When something happened, as a feed or a notification says it: "just
/// now", "5 minutes ago", "yesterday", "3 Oct"; "" for no time.
export function ago(iso) {
  const at = Date.parse(String(iso || ""));
  if (!Number.isFinite(at)) return "";
  const minutes = Math.round((at - Date.now()) / 60000);
  if (minutes > -1) return say("just now");
  if (minutes > -60) return AGO.format(minutes, "minute");
  if (minutes > -24 * 60) return AGO.format(Math.round(minutes / 60), "hour");
  if (minutes > -7 * 24 * 60) return AGO.format(Math.round(minutes / 1440), "day");
  return DATE.format(at);
}

// An open "more" menu (details.more-menu) closes on a click outside it and
// on Escape, as a menu does; with no script it still opens and closes.
//
// And a button pressed from the keyboard keeps the keyboard. Many of the
// site's buttons are disabled while what they asked is done (a like, a
// follow, Send), and the browser moves the focus of a disabled button to
// the page itself: a person on the keyboard pressed Like, and was left at
// the top of the page with nothing said, and Enter again did nothing. So
// the button pressed is given its focus back once it is enabled, if
// nothing else took it meanwhile, and a screen reader says it again with
// what it now says ("Like Watchtower, 13 likes, pressed").
//
// And a dialog (the site's <dialog>, opened with showModal) keeps the
// keyboard while it is open: Tab from its last control comes round to its
// first, and Shift+Tab the other way, rather than out into the browser.
// Closed, the focus goes back to what had it when the dialog took it: an
// ask over /admin's sheet back into the sheet, not to what opened the
// sheet. When that is gone or hidden (Report it, in a More menu that closed
// behind it), to the button that opened what held it; when it is held
// (disabled) while what it asked is done, once it is let go; so a person on
// the keyboard is never left on the page's body.
if (typeof document !== "undefined") {
  const free = () => !document.activeElement || document.activeElement === document.body;
  // Drawn, and not shut away: in an inert part, or folded in a closed
  // <details> (its summary is not).
  const folded = (el) => {
    const shut = el.closest("details:not([open])");
    return Boolean(shut) && !(el.localName === "summary" && el.parentElement === shut);
  };
  const shown = (el) => el.isConnected && el.getClientRects().length > 0 && !el.closest("[inert]") && !folded(el);
  let waiting = null;
  let before = null;
  // What had the focus as each open dialog took it, and what has it now.
  const openers = new WeakMap();
  let last = null;
  new MutationObserver((changes) => {
    for (const { target, attributeName } of changes) {
      if (attributeName === "open") {
        if (target.localName !== "dialog" || target.open) continue;
        const opener = openers.get(target) || before;
        openers.delete(target);
        // Lost: on the page's body, or still on a button of the dialog
        // that closed, where the browser left it when what had the focus
        // before was held (an act's button, disabled while it asks).
        if (!free() && !target.contains(document.activeElement)) continue;
        // Where it was, else what opened the menu it was in.
        const back = opener && (shown(opener) ? opener : opener.closest("details")?.querySelector(":scope > summary"));
        if (!back || !shown(back)) continue;
        if (back.disabled) waiting = back;
        else back.focus({ preventScroll: true });
        continue;
      }
      if (target.disabled && target === document.activeElement) waiting = target;
      else if (!target.disabled && target === waiting) {
        waiting = null;
        if (free() && shown(target)) target.focus({ preventScroll: true });
      }
    }
  }).observe(document.documentElement, { attributes: true, attributeFilter: ["disabled", "open"], subtree: true });
  document.addEventListener("focusin", (event) => {
    const into = event.target.closest?.("dialog");
    if (!into) before = event.target;
    else if (!openers.has(into) && last && !into.contains(last)) openers.set(into, last);
    last = event.target;
  });
  // The stops Tab makes in [dialog], a group of radio buttons as one.
  const group = (el) => (el.type === "radio" && el.name ? `radio ${el.name}` : el);
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Tab" || event.defaultPrevented) return;
    // The one on top: an ask over a sheet is the ask.
    const modals = [...document.querySelectorAll("dialog[open]")].filter((one) => one.matches(":modal"));
    const dialog = modals.find((one) => one.contains(document.activeElement)) || modals.at(-1);
    if (!dialog) return;
    const stops = [...dialog.querySelectorAll("a[href], button, input, select, textarea, summary, [tabindex]")]
      .filter((el) => el.tabIndex >= 0 && !el.disabled && el.type !== "hidden" && shown(el)
        && getComputedStyle(el).visibility !== "hidden");
    if (!stops.length) return;
    const now = group(document.activeElement);
    const [first, last] = [stops[0], stops[stops.length - 1]];
    const out = !dialog.contains(document.activeElement);
    if (event.shiftKey ? (out || now === group(first)) : (out || now === group(last))) {
      event.preventDefault();
      const to = event.shiftKey ? last : first;
      // A group of radio buttons is entered at its chosen one.
      const chosen = to.type === "radio" && to.name ? dialog.querySelector(`input[type=radio][name="${CSS.escape(to.name)}"]:checked`) : null;
      (chosen || to).focus();
    }
  });
  if (document.body) toastRegion();
  else document.addEventListener("DOMContentLoaded", toastRegion, { once: true });

  const close = (except) => {
    for (const open of document.querySelectorAll("details.more-menu[open]")) if (open !== except) open.open = false;
  };
  document.addEventListener("click", (event) => close(event.target.closest?.("details.more-menu")));
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    const open = document.querySelector("details.more-menu[open]");
    if (!open) return;
    open.open = false;
    open.querySelector("summary")?.focus();
  });
}

// ---------------------------------------------------------------------------
// Ask and tell: the site's own dialog for a question before an act, and for
// a word after one (docs/DESIGN_SYSTEM.md "Ask"), never the browser's
// confirm() or alert(), which look like another program's and ask in its
// words (owner, 2026-11-23). The house dialog: showModal over the scrim,
// rising in over --motion-open, a sheet from the window's foot on a phone.
// An alertdialog named by its title and described by its line. Escape and a
// press beside it answer No; Enter answers what has the focus, so it
// confirms only from the confirm button. The focus goes back where it was
// (above).

let asks = 0;

/// [title] asked over the page, [body] under it: true when [yes] is
/// pressed; false for [no], Escape or a press beside it. [danger]: [yes]
/// cannot be undone (delete, remove, sign out everywhere), so it is the
/// danger button and the focus starts on [no], the safe choice. Words as the
/// page says them: say() them first.
export function ask({ title, body = "", yes = say("OK"), no = say("Cancel"), danger = false } = {}) {
  return answered(title, body, [[yes, true, danger ? "cta ghost danger" : "cta"], [no, false, "cta ghost"]], danger ? 1 : 0);
}

/// [title] told over the page, [body] under it, with one button ([ok]):
/// resolves once it is closed, by [ok], Escape or a press beside it.
export async function tell({ title, body = "", ok = say("OK") } = {}) {
  await answered(title, body, [[ok, true, "cta"]], 0);
}

function answered(title, body, buttons, start) {
  return new Promise((resolve) => {
    asks += 1;
    const dialog = document.createElement("dialog");
    dialog.className = "ask";
    dialog.setAttribute("role", "alertdialog");
    const head = document.createElement("h2");
    head.id = `ask-${asks}-title`;
    head.textContent = title;
    dialog.setAttribute("aria-labelledby", head.id);
    dialog.append(head);
    if (body) {
      const line = document.createElement("p");
      line.id = `ask-${asks}-body`;
      line.textContent = body;
      dialog.setAttribute("aria-describedby", line.id);
      dialog.append(line);
    }
    const row = document.createElement("div");
    row.className = "actions";
    let answer = false;
    for (const [words, value, className] of buttons) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = className;
      button.dataset.answer = value ? "yes" : "no";
      button.textContent = words;
      button.addEventListener("click", () => {
        answer = value;
        dialog.close();
      });
      row.append(button);
    }
    dialog.append(row);
    // Beside it, on the scrim: pressed and let go there, not a drag out of
    // its words, nor the second press of a double click on the button that
    // asked, which lands on the scrim the moment the ask is open.
    const beside = (event) => {
      const box = dialog.getBoundingClientRect();
      return event.target === dialog && (event.clientX < box.left || event.clientX > box.right
        || event.clientY < box.top || event.clientY > box.bottom);
    };
    const opened = performance.now();
    let down = false;
    dialog.addEventListener("pointerdown", (event) => { down = beside(event) && performance.now() - opened > 400; });
    dialog.addEventListener("click", (event) => {
      if (down && beside(event)) dialog.close();
      down = false;
    });
    dialog.addEventListener("close", () => {
      dialog.remove();
      resolve(answer);
    }, { once: true });
    document.body.append(dialog);
    dialog.showModal();
    row.children[start].focus();
  });
}
