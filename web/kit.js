// The site's kit, as strings and one behaviour (site.css "the kit",
// docs/DESIGN_SYSTEM.md): an avatar made from a handle, an icon from the
// sprite, an icon button that says its name and count, the toast, and the
// "more" menu closing on a click elsewhere. The avatar, the icons and the
// icon button are pure string functions made in web/card.js, which draws
// them on every card and which a deployment copies alone beside its
// functions, so a server page draws them as a browser does: passed on from
// here, so a page asks the kit for the whole kit.
export { ICONS, avatarHtml, avatarTone, iconButtonHtml, iconHtml } from "./card.js";

/// Says [words] in the toast at the foot of the screen ("Link copied"),
/// read out by a screen reader, and takes it away after a moment.
export function toast(words) {
  let said = document.querySelector("body > .toast");
  if (!said) {
    said = document.createElement("div");
    said.className = "toast";
    said.setAttribute("role", "status");
    said.setAttribute("aria-live", "polite");
    document.body.append(said);
  }
  said.textContent = String(words);
  said.classList.add("shown");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => said.classList.remove("shown"), 2400);
}

// An open "more" menu (details.more-menu) closes on a click outside it and
// on Escape, as a menu does; with no script it still opens and closes.
if (typeof document !== "undefined") {
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
