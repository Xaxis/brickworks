// The site's kit, as strings and one behaviour (site.css "the kit",
// docs/DESIGN_SYSTEM.md): an avatar made from a handle, an icon from the
// sprite, an icon button that says its name and count, the toast, and the
// "more" menu closing on a click elsewhere. The avatar, the icons and the
// icon button are pure string functions made in web/card.js, which draws
// them on every card and which a deployment copies alone beside its
// functions, so a server page draws them as a browser does: passed on from
// here, so a page asks the kit for the whole kit.
export { ICONS, avatarHtml, avatarTone, awardsHtml, iconButtonHtml, iconHtml } from "./card.js";

const AGO = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
const DATE = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });

/// When something happened, as a feed or a notification says it: "just
/// now", "5 minutes ago", "yesterday", "3 Oct"; "" for no time.
export function ago(iso) {
  const at = Date.parse(String(iso || ""));
  if (!Number.isFinite(at)) return "";
  const minutes = Math.round((at - Date.now()) / 60000);
  if (minutes > -1) return "just now";
  if (minutes > -60) return AGO.format(minutes, "minute");
  if (minutes > -24 * 60) return AGO.format(Math.round(minutes / 60), "hour");
  if (minutes > -7 * 24 * 60) return AGO.format(Math.round(minutes / 1440), "day");
  return DATE.format(at);
}

/// Says [words] in the toast at the foot of the screen ("Link copied"),
/// read out by a screen reader, and takes it away after a moment. A screen
/// reader reads a live region's change, not a region that arrives already
/// saying something, so the toast is on the page empty from the first, and
/// its words are put in a moment later; the same words twice are said twice.
export function toast(words) {
  const said = toastRegion();
  said.textContent = "";
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => {
    said.textContent = String(words);
    said.classList.add("shown");
    toast.timer = setTimeout(() => said.classList.remove("shown"), 2400);
  }, 60);
}

function toastRegion() {
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
// Closed, the focus goes back where it was; when that is gone or hidden
// (Report it, in a More menu that closed behind it), to the button that
// opened what held it, so a person on the keyboard is never left on the
// page's body.
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
  new MutationObserver((changes) => {
    for (const { target, attributeName } of changes) {
      if (attributeName === "open") {
        if (target.localName === "dialog" && !target.open && free()) {
          // Where it was, else what opened the menu it was in.
          const back = before && (shown(before) ? before : before.closest("details")?.querySelector(":scope > summary"));
          if (back && shown(back)) back.focus({ preventScroll: true });
        }
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
    if (!event.target.closest?.("dialog")) before = event.target;
  });
  // The stops Tab makes in [dialog], a group of radio buttons as one.
  const group = (el) => (el.type === "radio" && el.name ? `radio ${el.name}` : el);
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Tab" || event.defaultPrevented) return;
    const dialog = [...document.querySelectorAll("dialog[open]")].find((one) => one.matches(":modal"));
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
