// The site's kit, as strings and one behaviour (site.css "the kit",
// docs/DESIGN_SYSTEM.md): an avatar made from a handle, an icon from the
// sprite, an icon button that says its name and count, the toast, and the
// "more" menu closing on a click elsewhere. Pure string functions, like
// web/card.js, so a server page can draw them as a browser does.
import { escapeHtml } from "./card.js";

/// Which of the eight avatar tiles a handle has (1-8): the same every time
/// and on every page, spread evenly (FNV-1a of the handle).
export function avatarTone(handle) {
  let hash = 0x811c9dc5;
  for (const c of String(handle || "").toLowerCase()) {
    hash ^= c.codePointAt(0);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return (hash % 8) + 1;
}

/// A person's avatar: their picture when they have one, else a tile in
/// their handle's colour with the first letter of their name. Never a
/// figure's likeness (docs/TRADEMARKS.md, docs/SOCIAL.md D11). [size] is
/// "small", "", "big" or "huge"; it is decoration beside their name, so
/// hidden from a screen reader.
export function avatarHtml({ handle = "", name = "", picture = "" } = {}, { size = "", id = "" } = {}) {
  const letter = [...String(name || handle || "?").trim()][0] || "?";
  const classes = ["avatar", size, `c${avatarTone(handle || name)}`].filter(Boolean).join(" ");
  return `<span class="${classes}"${id ? ` id="${escapeHtml(id)}"` : ""} aria-hidden="true">${picture
    ? `<img src="${escapeHtml(picture)}" alt="" loading="lazy" decoding="async">` : escapeHtml(letter)}</span>`;
}

/// The icons there are (web/icons.svg).
export const ICONS = ["like", "save", "share", "comment", "more", "build"];

/// An icon from the sprite, in the words' colour.
export function iconHtml(name) {
  if (!ICONS.includes(name)) throw new Error(`no icon named ${name}`);
  return `<svg class="icon" aria-hidden="true" focusable="false"><use href="/icons.svg#${name}"></use></svg>`;
}

/// An icon button: its icon and its count beside it once there is one,
/// its name and count its label ("Like, 12 likes"; "Like" at none). A
/// toggle ([pressed] true or false) is aria-pressed.
export function iconButtonHtml({ icon, name, count = 0, one = "", many = "", pressed = null, small = false, attrs = "" }) {
  const n = Number(count) || 0;
  const said = n ? `${name}, ${n.toLocaleString("en-US")} ${n === 1 ? one : many || `${one}s`}` : name;
  return `<button type="button" class="icon-btn${small ? " small" : ""}" aria-label="${escapeHtml(said)}"`
    + `${pressed === null ? "" : ` aria-pressed="${pressed ? "true" : "false"}"`}${attrs ? ` ${attrs}` : ""}>`
    + `${iconHtml(icon)}${n ? `<span class="n" aria-hidden="true">${escapeHtml(n.toLocaleString("en-US"))}</span>` : ""}</button>`;
}

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
