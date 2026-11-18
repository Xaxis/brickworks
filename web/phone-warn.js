// A phone told before the studio opens a model too big for it (phonetruth,
// 2026-11-18; docs/PHONE.md). On a model's page and a set's (web/model-page.js
// loads this on both), a link into the studio with this model in it
// (/app?view=, ?copy=, ?library=, the picture's and the buttons') asks first
// on a phone when the model has more parts than phone_parts: "About N parts:
// on a phone this may close the tab". Open it anyway goes on to the link; Not
// now or Escape stays on the page. The picture itself, when it opens the 3D
// view in its place (web/start3d.js), opens no studio and is not asked
// about; that view's own way into the studio is. phone_parts is the
// console's (/admin#switches, Phones; /api/plans?op=phone, api/_phone.js),
// asked once a phone opens the page, and PHONE_PARTS until it answers.
//
// A phone is a touch screen with no fine pointer whose shorter side is under
// 600 px, as the studio's loader judges one (src/boot/shell.html). A
// computer, a tablet, a model under the number, a page that says no count
// and a click with a key held (a new tab, as any link) are never asked.
import { number, say } from "/card.js";

/// api/_phone.js's measured default, until the site's own number comes.
export const PHONE_PARTS = 2500;

/// Whether this is a phone: touch only, and narrow whichever way it is held.
export function isPhone() {
  try {
    return matchMedia("(pointer: coarse)").matches && !matchMedia("(any-pointer: fine)").matches
      && Math.min(screen.width, screen.height) < 600;
  } catch {
    return false;
  }
}

const MODEL_LINK = /^\/app\?(?:.*&)?(?:view|copy|library)=/;

/// Every link into the studio with this page's model in it, under [root],
/// asked about first on a phone when the model is past the number.
export function guardPhoneOpens(root = document) {
  const counted = root.querySelector("a.picture[data-parts]");
  const parts = Number(counted?.dataset.parts) || 0;
  if (!parts || !isPhone()) return;
  let most = PHONE_PARTS;
  let heard = false;
  const hearing = fetch("/api/plans?op=phone").then((reply) => (reply.ok ? reply.json() : null)).then((rules) => {
    const told = Number(rules?.phone_parts);
    if (Number.isInteger(told) && told > 0) most = told;
  }).catch(() => { /* the measured default stands */ }).finally(() => { heard = true; });
  root.addEventListener("click", (event) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const link = event.target instanceof Element ? event.target.closest("a[href]") : null;
    // The picture as start3d made it a button, and the dialog's own way on.
    if (!link || link.getAttribute("role") === "button" || link.dataset.phoneWarned) return;
    const at = new URL(link.href, location.href);
    if (at.origin !== location.origin || !MODEL_LINK.test(`${at.pathname}${at.search}`)) return;
    if (heard && parts <= most) return;
    event.preventDefault();
    event.stopPropagation();
    const name = root.querySelector("h1")?.textContent?.trim() || "";
    if (heard) {
      ask(parts, name, at.href);
      return;
    }
    // A press before the owner's number came: it is waited on (two seconds
    // at most, then the measured one), and the same choice made with it.
    document.documentElement.dataset.phoneWarnWaited = "1";
    Promise.race([hearing, new Promise((done) => { setTimeout(done, 2000); })]).then(() => {
      if (parts > most) ask(parts, name, at.href);
      else location.assign(at.href);
    });
  }, true);
}

/// "About N parts", near enough to read at a glance: 9,429 is about 9,400.
const about = (parts) => number(parts < 1000 ? parts : Math.round(parts / 100) * 100);

function ask(parts, name, href) {
  document.querySelector("dialog.phone-warn")?.remove();
  const dialog = document.createElement("dialog");
  dialog.className = "phone-warn";
  const title = document.createElement("h2");
  title.id = "phone-warn-title";
  title.textContent = say("A big model for a phone");
  dialog.setAttribute("aria-labelledby", title.id);
  const lede = document.createElement("p");
  lede.id = "phone-warn-said";
  dialog.setAttribute("aria-describedby", lede.id);
  lede.textContent = say("About {parts} parts: on a phone this may close the tab. A phone gives a tab much less memory "
    + "than a computer does, and a model this big can use it all.", { parts: about(parts) });
  const named = document.createElement("p");
  named.className = "note";
  if (name) named.textContent = say("{name} opens as it should on a computer.", { name });
  const actions = document.createElement("div");
  actions.className = "actions";
  const stay = document.createElement("button");
  stay.type = "button";
  stay.className = "cta";
  stay.textContent = say("Not now");
  stay.addEventListener("click", () => dialog.close("stay"));
  const go = document.createElement("a");
  go.className = "cta ghost";
  go.href = href;
  go.dataset.phoneWarned = "open";
  go.textContent = say("Open it anyway");
  go.addEventListener("click", () => {
    document.documentElement.dataset.phoneWarn = "opened";
  });
  actions.append(stay, go);
  dialog.append(title, lede, ...(name ? [named] : []), actions);
  dialog.addEventListener("close", () => {
    document.documentElement.dataset.phoneWarn = "stayed";
    dialog.remove();
  });
  document.body.append(dialog);
  document.documentElement.dataset.phoneWarn = "asked";
  document.documentElement.dataset.phoneWarnParts = String(parts);
  dialog.showModal();
  stay.focus();
}
