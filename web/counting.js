// Whether this browser may be counted (insights, 2026-11-18; docs/ANALYTICS.md,
// /counting): read by web/tally.js before it does anything, by the ask
// (web/counting-ask.js) and by Settings' choice. No imports: the studio's
// page loads it too.
//
// Nothing is counted, and nothing asked, when the browser says Do Not Track
// or Global Privacy Control (navigator.globalPrivacyControl, W3C GPC), when
// the person turned it off (Settings, or "No" to the ask), or in a browser a
// check drives (navigator.webdriver) unless the check asked to be counted.
// Where the law wants a yes first (the EU, the EEA, the UK, Switzerland: the
// browser's time zone says so here, the server's country header there),
// nothing is counted until the person says yes. A clock that names no place
// (UTC, Etc/*) is asked too.
//
// web/theme.js and src/boot/shell.html repeat this file's cheap no (Do Not
// Track, GPC, a No kept, a driven browser that did not ask) before they
// fetch the counter at all: change one, change them.

const KEY = "brickworks.counting";
const CHECK = "brickworks.counting.check";

function kept(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

/// Whether the browser's own settings ask not to be tracked.
export function browserSaysNo() {
  const dnt = String(navigator.doNotTrack ?? window.doNotTrack ?? navigator.msDoNotTrack ?? "");
  return dnt === "1" || dnt === "yes" || navigator.globalPrivacyControl === true;
}

// Time zones where a yes is asked first: Europe's, and the EU's islands and
// regions on other continents' clocks.
const ASKED_ZONES = new Set(["Atlantic/Canary", "Atlantic/Madeira", "Atlantic/Azores", "Atlantic/Reykjavik", "Atlantic/Faroe",
  "Atlantic/Jan_Mayen", "Arctic/Longyearbyen", "Africa/Ceuta", "America/Guadeloupe", "America/Martinique", "America/Cayenne",
  "America/St_Barthelemy", "America/Marigot", "Indian/Reunion", "Indian/Mayotte", "Asia/Nicosia", "Asia/Famagusta"]);
// A clock that names no place (UTC, GMT, Etc/GMT+1, none at all) could be
// anywhere, the EU too: a yes comes first there as well (inreview L4).
const NOWHERE = /^(?:Etc\/.*|UTC|UCT|GMT.*|Universal|Zulu|Greenwich)?$/;

/// Whether this browser's clock is one where a yes comes first.
export function asksFirst(zone = undefined) {
  if (zone === undefined) {
    try {
      zone = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
    } catch {
      return true;
    }
  }
  zone = String(zone ?? "");
  return NOWHERE.test(zone) || zone.startsWith("Europe/") || ASKED_ZONES.has(zone);
}

/// Where this browser stands: "browser" (DNT or GPC), "off" (said no),
/// "check" (a driven browser that did not ask), "ask" (a yes is needed and
/// not given), "yes" (said yes) or "on" (counted, never asked).
export function countingState() {
  if (browserSaysNo()) return "browser";
  const said = kept(KEY);
  if (said === "no") return "off";
  if (navigator.webdriver === true && kept(CHECK) !== "1") return "check";
  if (said === "yes") return "yes";
  return asksFirst() ? "ask" : "on";
}

/// Whether a beacon may go now.
export const counting = () => ["yes", "on"].includes(countingState());

/// The person's own choice, kept in this browser; told to the page's
/// counter at once (brickworks:counting).
export function setCounting(on) {
  try {
    localStorage.setItem(KEY, on ? "yes" : "no");
  } catch {
    // A browser that keeps nothing asks again on its next page.
  }
  dispatchEvent(new CustomEvent("brickworks:counting", { detail: { on: Boolean(on) } }));
}
