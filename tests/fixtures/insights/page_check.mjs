// What the site's pages ask before they count (infix, 2026-11-18;
// inreview L2, L3, L4), in node: web/counting.js's clocks, and web/theme.js
// run whole against a stand-in page, once a browser state, to see what it
// fetches for the counter and whether it tells the social desk of a visit
// from its post. What tests/test_insights_page.py asks of them.
//
//   node tests/fixtures/insights/page_check.mjs
//
// Prints one JSON object, each finding by name.
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const web = new URL("../../../web/", import.meta.url);
const here = mkdtempSync(join(tmpdir(), "page-check-"));
writeFileSync(join(here, "counting.mjs"), readFileSync(new URL("counting.js", web), "utf8"));

// A page: its storage, its browser's flags and clock, and what it asked for.
const page = { kept: {}, imports: [], beacons: [], fetched: [], zone: "America/New_York" };
// Each visit its own window: nothing one heard reaches the next.
const realIntl = Intl;
globalThis.window = globalThis;
globalThis.addEventListener = (...given) => page.events.addEventListener(...given);
globalThis.removeEventListener = (...given) => page.events.removeEventListener(...given);
globalThis.dispatchEvent = (event) => page.events.dispatchEvent(event);
globalThis.localStorage = { getItem: (key) => (key in page.kept ? page.kept[key] : null),
  setItem: (key, value) => { page.kept[key] = String(value); }, removeItem: (key) => { delete page.kept[key]; } };
globalThis.sessionStorage = { getItem: () => null, setItem: () => {} };
globalThis.Intl = { ...realIntl, DateTimeFormat: function () {
  return { resolvedOptions: () => ({ timeZone: page.zone }) };
} };
globalThis.matchMedia = () => ({ matches: false, addEventListener() {} });
globalThis.requestIdleCallback = (then) => setTimeout(then, 0);
globalThis.history = { state: null, replaceState: () => {} };
globalThis.fetch = async (url) => {
  page.fetched.push(String(url));
  return new Response("", { status: 204 });
};
const counting = await import(pathToFileURL(join(here, "counting.mjs")).href);
const THEME = readFileSync(new URL("theme.js", web), "utf8").replaceAll("import(", "__imp(");
const wait = (ms) => new Promise((done) => setTimeout(done, ms));

/// web/theme.js run once on [path] with [kept] stored, [flags] on the
/// browser and the clock [zone]: what it fetched and told.
async function visit({ path = "/gallery", search = "", kept = {}, flags = {}, zone = "America/New_York", then = null } = {}) {
  Object.assign(page, { kept: { ...kept }, imports: [], beacons: [], fetched: [], zone, events: new EventTarget() });
  const nav = { languages: ["en-US"], language: "en-US", doNotTrack: null, globalPrivacyControl: undefined, webdriver: false,
    sendBeacon: (url) => {
      page.beacons.push(String(url));
      return true;
    }, ...flags };
  Object.defineProperty(globalThis, "navigator", { value: nav, configurable: true, writable: true });
  globalThis.location = { pathname: path, search, hash: "", href: `https://brickworks.diy${path}${search}`,
    replace: () => {}, assign: () => {} };
  const root = { lang: "en", dataset: {}, hasAttribute: () => false, setAttribute() {}, removeAttribute() {} };
  globalThis.document = { documentElement: root, readyState: "complete", querySelector: () => null, querySelectorAll: () => [],
    getElementById: () => null, addEventListener() {}, dispatchEvent() {} };
  globalThis.__imp = async (name) => {
    page.imports.push(name);
    return name === "/counting.js" ? counting : {};
  };
  new Function(THEME)();
  await wait(30);
  if (then) {
    then();
    await wait(30);
  }
  return { imports: [...page.imports].sort(), beacons: page.beacons.length, fetched: page.fetched.length,
    tally: page.imports.includes("/tally.js"), counting_js: page.imports.includes("/counting.js") };
}

const out = {};
// L4: a clock that names no place asks first, as Europe's do.
out.zones = Object.fromEntries(["UTC", "Etc/UTC", "Etc/GMT+5", "Etc/GMT-1", "GMT", "Universal", "Zulu", "", "Europe/Berlin",
  "Europe/Mariehamn", "Indian/Reunion", "America/Guadeloupe", "America/Martinique", "America/Cayenne", "Indian/Mayotte",
  "America/Marigot", "Atlantic/Canary", "America/New_York", "America/Anchorage", "Asia/Tokyo", "Australia/Sydney",
  "America/Sao_Paulo"].map((zone) => [zone || "(none)", counting.asksFirst(zone)]));
page.zone = "UTC";
out.utc_state = counting.countingState();

// L3: the counter not even fetched where the answer is no; L2: the desk's visit not told.
const CHECK = { "brickworks.counting.check": "1" };
const DESK = "?utm_source=reddit&utm_medium=social&utm_campaign=bw-abcdefghij";
const states = {
  counted: { kept: CHECK },
  dnt: { kept: CHECK, flags: { doNotTrack: "1" } },
  gpc: { kept: CHECK, flags: { globalPrivacyControl: true } },
  said_no: { kept: { ...CHECK, "brickworks.counting": "no" } },
  driven: { flags: { webdriver: true } },
  driven_asked: { kept: CHECK, flags: { webdriver: true } },
  berlin: { kept: CHECK, zone: "Europe/Berlin" },
  utc: { kept: CHECK, zone: "UTC" },
  console: { kept: CHECK, path: "/admin" },
};
out.loads = {};
for (const [name, state] of Object.entries(states)) out.loads[name] = await visit(state);
out.desk = {};
for (const [name, state] of Object.entries({ counted: states.counted, dnt: states.dnt, gpc: states.gpc, said_no: states.said_no,
  driven: states.driven, said_yes: { kept: { "brickworks.counting": "yes" } }, berlin: states.berlin })) {
  out.desk[name] = await visit({ ...state, search: DESK });
}
// Where a yes comes first: told only once it is given, on this page.
out.desk.berlin_then_yes = await visit({ ...states.berlin, search: DESK, then: () => counting.setCounting(true) });
out.desk.berlin_then_no = await visit({ ...states.berlin, search: DESK, then: () => counting.setCounting(false) });
out.desk.untagged = await visit({ ...states.counted, search: "?utm_campaign=spring" });
process.stdout.write(`${JSON.stringify(out)}\n`);
process.exit(0);
