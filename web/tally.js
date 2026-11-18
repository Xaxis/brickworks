// How the site and the studio are used, counted (insights, 2026-11-18;
// docs/ANALYTICS.md, the page /counting; /admin › Analytics reads it).
//
// Loaded after the first screen: by web/theme.js on every site page once
// the page has loaded and gone idle, and by the studio's shell
// (src/boot/shell.html) once the studio is up. It does nothing at all, not
// even look, unless this browser may be counted (web/counting.js): not
// with Do Not Track or GPC, not after a no, not in a driven browser that
// did not ask, and not before a yes where one is asked first.
//
// A visit is this tab's time here, ended by 30 minutes away: a random id
// in the tab's session storage, which the site and the studio share. What
// goes, every 15 seconds while something happened and when the tab is
// hidden or left (one request each, counts added up):
//
//   the site    a page's template (/m/:id, never the id), what the visit
//               came from (the referrer's host, utm_*), an act that wrote
//               (an API's name and op: people.like, share.comment), a
//               sign-in; one visit in four, the page's own timings (LCP,
//               FCP, TTFB, CLS, INP).
//   the studio  the tool in use and for how long, a panel or dialog
//               opened, a named control pressed, a command run from the
//               palette, a part put down and a model saved (counts only),
//               the first of each and how long after the studio came up,
//               a Simulate, Render, booklet or Together run (how long, and
//               whether it went), the start's own timings, frame times a
//               few seconds at a time, and the controls shown.
//   both        an error's place (a file and line, never its words), the
//               last act, the kind of device, browser and system, the
//               page's language, the account's id when signed in (the
//               server keeps only a keyed hash of it).
//
// Never what a model holds, a part's number, words typed, a file's name, an
// address, anything from the page's text.

import { counting, countingState } from "/counting.js";

const ENDPOINT = "/api/plans?op=tally";
const VISIT = "brickworks.visit";
const AWAY_MS = 30 * 60 * 1000;
const EVERY_MS = 15000;
const studio = Boolean(window.brickworksBoot) || /^\/(?:app|b\/[0-9a-f]{7,40})\/?/.test(location.pathname);
const surface = studio ? "studio" : "site";

// ---------------------------------------------------------------------------
// Names: only what code names, made safe for a row.

/// [text] as a row's name: lower case, a-z 0-9 _ : / # . - only (accents
/// and zero-width marks taken off, spaces as _), runs of digits as # unless
/// [digits] (an error's line, a page's own address, a link's utm_*), at
/// most 60 long; "" when nothing is left, and for anything with an @ in it
/// (an email address in a link's utm_source is never kept, even mangled).
export function nameOf(text, digits = false) {
  if (String(text ?? "").includes("@")) return "";
  const plain = String(text ?? "").trim().toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f\u200b-\u200f\u2060\ufeff]/g, "")
    .replace(/\s+/g, "_");
  return (digits ? plain : plain.replace(/[0-9]+/g, "#")).replace(/[^a-z0-9_:/#.-]/g, "").slice(0, 60);
}

const LANGS = /^\/(de|fr|es)(?=\/|$)/;
// The pages with an id in their address, as templates: each pattern, and
// its name in the rows (names, never links: tools/site_lang.py's check of
// a script's links reads a quoted page address as one).
const TEMPLATE_NAMES = "/m/:id/v/:n /m/:id /u/:handle /c/:id /library/set/:n /library/:id /app".split(" ");
const TEMPLATES = [/^\/m\/[A-Za-z0-9]{10}\/v\/\d+\/?$/, /^\/m\/[A-Za-z0-9]{10}\/?$/, /^\/u\/[a-z0-9-]{3,24}\/?$/,
  /^\/c\/[A-Za-z0-9]{10}\/?$/, /^\/library\/set\/[^/]+\/?$/, /^\/library\/[a-z]{2,8}-[^/]+\/?$/,
  /^\/(?:app|b\/[0-9a-f]{7,40})(?:\/.*)?$/].map((pattern, at) => [pattern, TEMPLATE_NAMES[at]]);

/// This page's address as a template, and its language: an id never, and
/// an address the site did not make (a 404's) as /other. A page names
/// itself by its canonical link, which the site writes.
export function pageOf(path = location.pathname, canonical = document.querySelector('link[rel="canonical"]')?.href,
  said = document.documentElement.lang) {
  const lang = (LANGS.exec(path) || [])[1] || (["de", "fr", "es"].includes(String(said || "").slice(0, 2)) ? String(said).slice(0, 2) : "en");
  const bare = path.replace(LANGS, "") || "/";
  for (const [pattern, name] of TEMPLATES) if (pattern.test(bare)) return { name, lang };
  let named = "/other";
  try {
    if (canonical) named = new URL(canonical).pathname.replace(LANGS, "").replace(/\/$/, "") || "/";
  } catch {
    named = "/other";
  }
  return { name: /^\/[a-z0-9_/.-]{0,79}$/.test(named) ? named : "/other", lang };
}

// ---------------------------------------------------------------------------
// The visit.

function sessionRead() {
  try {
    return JSON.parse(sessionStorage.getItem(VISIT) || "null");
  } catch {
    return null;
  }
}

function sessionWrite(value) {
  try {
    sessionStorage.setItem(VISIT, JSON.stringify(value));
  } catch {
    // A tab that keeps nothing makes a visit a page.
  }
}

const SEARCH = /(^|\.)(google\.[a-z.]+|bing\.com|duckduckgo\.com|yahoo\.[a-z.]+|yandex\.[a-z.]+|ecosia\.org|baidu\.com|startpage\.com|qwant\.com|search\.brave\.com|kagi\.com)$/;
const SOCIAL = /(^|\.)(reddit\.com|redd\.it|facebook\.com|fb\.com|instagram\.com|x\.com|twitter\.com|t\.co|youtube\.com|youtu\.be|tiktok\.com|pinterest\.[a-z.]+|linkedin\.com|lnkd\.in|bsky\.app|threads\.net|mastodon\.[a-z.]+|discord\.com|discord\.gg|news\.ycombinator\.com|tumblr\.com|flickr\.com|whatsapp\.com|t\.me|vk\.com|eurobricks\.com|brickset\.com|rebrickable\.com|bricklink\.com)$/;
const AI = /(^|\.)(chatgpt\.com|chat\.openai\.com|perplexity\.ai|claude\.ai|gemini\.google\.com|copilot\.microsoft\.com|you\.com|phind\.com|poe\.com|chat\.mistral\.ai|deepseek\.com)$/;
const MAIL = /(^|\.)(mail\.google\.com|outlook\.live\.com|outlook\.office\.com|outlook\.office365\.com|mail\.yahoo\.com|mail\.proton\.me)$/;

/// Where a visit came from: its channel, source, medium and campaign, from
/// the landing's utm_* (as it was before web/theme.js took them out) and
/// the referrer's host. Only names: never the referrer's path.
export function cameFrom(landing = location.href, referrer = document.referrer) {
  let params = new URLSearchParams();
  try {
    params = new URL(landing).searchParams;
  } catch {
    // An address that does not read is direct.
  }
  let host = "";
  try {
    host = referrer ? new URL(referrer).hostname.toLowerCase().replace(/^www\./, "") : "";
  } catch {
    host = "";
  }
  if (host === location.hostname.replace(/^www\./, "")) host = "";
  // Digits kept: the social desk's campaigns are bw- and a post's id.
  const medium = nameOf(params.get("utm_medium"), true).replace(/[:/#]/g, "").slice(0, 40);
  const campaign = nameOf(params.get("utm_campaign"), true).replace(/[:/#]/g, "");
  const source = nameOf(params.get("utm_source"), true).replace(/[:/#]/g, "") || nameOf(host, true).replace(/[:/#]/g, "");
  let channel = "direct";
  if (/^(cpc|ppc|paid|paidsearch|paid_social|display|cpm|ads?)$/.test(medium)) channel = "paid";
  else if (/^(email|newsletter|e-mail|mail)$/.test(medium) || MAIL.test(host)) channel = "email";
  else if (/^bw-[a-z0-9]{10}$/.test(campaign) || /^(social|social-media|social_media)$/.test(medium)) channel = "social";
  else if (AI.test(host) || /^(chatgpt|perplexity|claude|gemini|copilot)/.test(source)) channel = "ai";
  else if (SEARCH.test(host)) channel = "search";
  else if (SOCIAL.test(host)) channel = "social";
  else if (host) channel = "referral";
  else if (source) channel = "referral";
  return { channel, source: source || null, medium: medium || null, campaign: campaign || null };
}

/// The kind of device, browser and system, from the browser's own words.
export function deviceOf(ua = navigator.userAgent, touch = navigator.maxTouchPoints || 0,
  short = Math.min(screen.width || 0, screen.height || 0)) {
  const ipad = /iPad/.test(ua) || (/Macintosh/.test(ua) && touch > 1);
  const os = /Windows/.test(ua) ? "windows" : ipad || /iPhone|iPod/.test(ua) ? "ios" : /Android/.test(ua) ? "android"
    : /CrOS/.test(ua) ? "chromeos" : /Mac OS X|Macintosh/.test(ua) ? "macos" : /Linux/.test(ua) ? "linux" : "other";
  const browser = /Edg\//.test(ua) ? "edge" : /OPR\/|Opera/.test(ua) ? "opera" : /SamsungBrowser/.test(ua) ? "samsung"
    : /Firefox\/|FxiOS/.test(ua) ? "firefox" : /Chrome\/|CriOS/.test(ua) ? "chrome" : /Safari\//.test(ua) ? "safari" : "other";
  const device = ipad || /Tablet/.test(ua) || (/Android/.test(ua) && !/Mobile/.test(ua)) ? "tablet"
    : /Mobi|iPhone|iPod|Android/.test(ua) || (touch > 0 && short > 0 && short < 600) ? "phone" : "desktop";
  return { device, browser, os };
}

/// This tab's visit, a new one after 30 minutes away: {id, at, about}.
function visitNow() {
  const now = Date.now();
  const had = sessionRead();
  if (had && /^[a-z0-9]{16}$/.test(had.id || "") && now - Number(had.at || 0) < AWAY_MS && had.about) {
    had.at = now;
    sessionWrite(had);
    return had;
  }
  const id = Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => (byte % 36).toString(36)).join("");
  const navigation = performance.getEntriesByType?.("navigation")?.[0];
  const { lang } = pageOf();
  const about = { landing: pageOf().name, ...cameFrom(navigation?.name || location.href), ...deviceOf(), lang };
  const visit = { id, at: now, about };
  sessionWrite(visit);
  return visit;
}

// ---------------------------------------------------------------------------
// What happened, queued.

let queue = new Map();
let singles = [];
let seenNew = [];
let lastAct = "";
let lastSent = "";
let visibleSince = document.visibilityState === "visible" ? Date.now() : 0;
let secondsHeld = 0;

/// [kind] [name] counted: added up within a beacon (n, and ms for a time).
function count(kind, name, { n = 1, ms = null, ok = null, digits = false } = {}) {
  const safe = nameOf(name, digits);
  if (!safe) return;
  const key = `${kind}|${safe}|${ok}`;
  const had = queue.get(key);
  if (had) {
    had[3] += n;
    if (ms !== null) had[4] = (had[4] || 0) + ms;
  } else {
    queue.set(key, [surface, kind, safe, n, ms, ok]);
  }
}

/// One row of its own: a run, a first, a timing.
function one(kind, name, ms, ok = null) {
  const safe = nameOf(name, true);
  if (!safe || singles.length > 60) return;
  singles.push([surface, kind, safe, 1, Number.isFinite(ms) ? Math.max(0, Math.round(ms * 10) / 10) : null, ok]);
}

const acted = (kind, name, digits = false) => {
  const safe = nameOf(name, digits);
  if (safe) lastAct = `${kind}:${safe}`.slice(0, 60);
};

/// The seconds this page was shown, added up to now.
function holdSeconds() {
  if (visibleSince) secondsHeld += (Date.now() - visibleSince) / 1000;
  visibleSince = document.visibilityState === "visible" ? Date.now() : 0;
}

/// The signed-in account's id, for the server to hash: from the session
/// the site and the studio keep (web/account.js, src/account/account.gd).
function whoIs() {
  try {
    const id = JSON.parse(localStorage.getItem("brickworks.session") || "null")?.user_id;
    return /^[0-9a-f-]{36}$/i.test(String(id || "")) ? String(id) : null;
  } catch {
    return null;
  }
}

/// Everything queued sent, as one beacon; [leaving]: by sendBeacon.
function send(leaving = false) {
  if (!counting()) {
    queue = new Map();
    singles = [];
    return;
  }
  holdSeconds();
  const counted = [...queue.values()].slice(0, 80);
  const events = [...counted, ...singles.slice(0, 80 - counted.length)];
  // Only seconds: told when leaving, or once a minute's worth is held.
  const quiet = !events.length && !seenNew.length && lastAct === lastSent;
  if (quiet && (secondsHeld < 1 || (!leaving && secondsHeld < 60))) return;
  const seconds = Math.floor(secondsHeld);
  secondsHeld -= seconds;
  queue = new Map();
  singles = singles.slice(80 - counted.length);
  const visit = visitNow();
  const body = JSON.stringify({ v: visit.id, about: { ...visit.about, studio, last: lastAct || undefined },
    e: events, seen: seenNew.splice(0, 400), seconds, who: whoIs(),
    consent: countingState() === "yes" ? true : undefined, check: navigator.webdriver === true ? true : undefined });
  lastSent = lastAct;
  try {
    if (leaving && navigator.sendBeacon && navigator.sendBeacon(ENDPOINT, new Blob([body], { type: "application/json" }))) return;
    fetch(ENDPOINT, { method: "POST", headers: { "content-type": "application/json" }, body, keepalive: true, credentials: "omit" })
      .catch(() => null);
  } catch {
    // Not counted: never the page's trouble.
  }
}

// ---------------------------------------------------------------------------
// The site.

/// A page seen, once per address (a page that changes its address counts
/// the new one).
let pageSeen = "";
function viewed() {
  const { name } = pageOf();
  if (name === pageSeen) return;
  pageSeen = name;
  count("view", name, { digits: true });
  acted("view", name, true);
}

// The APIs whose writes are a person's acts, and the ops that are the
// counter's own or the page's machinery.
const ACTS = new Set(["share", "people", "collection", "models", "account", "plans", "otp", "orangecheck"]);
const NOT_ACTS = new Set(["tally", "social_visit", "notice", "feed_count", "seen", "me"]);

/// The page's own fetch, watched for writes to the site's API: their name
/// and op, whether they went, never what they sent or got.
function watchActs() {
  const before = window.fetch;
  if (typeof before !== "function" || before.brickworksTally) return;
  const watched = function (input, init) {
    const answer = before.apply(this, arguments);
    try {
      const method = String(init?.method || (input instanceof Request ? input.method : "GET")).toUpperCase();
      if (method !== "GET" && method !== "HEAD") {
        const url = new URL(input instanceof Request ? input.url : String(input), location.href);
        const fn = (/^\/api\/([a-z_]+)$/.exec(url.pathname) || [])[1];
        const op = url.searchParams.get("op") || method.toLowerCase();
        if (url.origin === location.origin && fn && ACTS.has(fn) && !NOT_ACTS.has(op)) {
          const name = `${fn}.${op}`;
          answer.then((reply) => {
            count("act", name, { ok: reply.ok });
            acted("act", name);
          }, () => count("act", name, { ok: false }));
        }
      }
    } catch {
      // A request this cannot read is not counted.
    }
    return answer;
  };
  watched.brickworksTally = true;
  window.fetch = watched;
}

/// The page's own timings, one visit in four: Largest Contentful Paint,
/// First Contentful Paint, time to first byte, layout shift (x1000) and the
/// slowest interaction (INP's measure), as the browser timed them.
function siteTimings(visitId) {
  if (parseInt(visitId.slice(-1), 36) % 4 !== 0 || !("PerformanceObserver" in window)) return () => {};
  let lcp = null;
  let cls = 0;
  let inp = null;
  const watch = (type, take, extra = {}) => {
    try {
      new PerformanceObserver((list) => list.getEntries().forEach(take)).observe({ type, buffered: true, ...extra });
    } catch {
      // A browser without it gives none.
    }
  };
  watch("largest-contentful-paint", (entry) => { lcp = entry.startTime; });
  watch("layout-shift", (entry) => { if (!entry.hadRecentInput) cls += entry.value; });
  watch("event", (entry) => { if (entry.interactionId) inp = Math.max(inp || 0, entry.duration); }, { durationThreshold: 40 });
  let told = false;
  return () => {
    if (told) return;
    told = true;
    const navigation = performance.getEntriesByType("navigation")[0];
    const fcp = performance.getEntriesByName("first-contentful-paint")[0];
    if (navigation) one("load", "site_ttfb", navigation.responseStart);
    if (fcp) one("load", "site_fcp", fcp.startTime);
    if (lcp !== null) one("load", "site_lcp", lcp);
    one("load", "site_cls", cls * 1000);
    if (inp !== null) one("load", "site_inp", inp);
  };
}

// ---------------------------------------------------------------------------
// The studio, read from what it tells the page (src/main.gd _tell_page and
// the panels' own): nothing in it changes.

// Each panel or dialog, and how its being open shows.
const PANELS = {
  parts: (s) => s.columns?.parts, assistant: (s) => s.columns?.assistant, properties: (s) => s.columns?.properties,
  palette: (s) => s.palette?.open, app_menu: (s) => (s.app_menu || []).length > 0,
  page_editor: (s) => s.page_editor && Object.keys(s.page_editor).length > 0, saved_models: (s) => s.saved_models?.open,
  versions: (s) => s.storage?.versions?.open, feedback: (s) => s.feedback?.open, split_view: (s) => s.split,
  see_inside: (s) => s.cut?.on, xray: (s) => s.xray > 0, step_playback: (s) => s.playing, reference: (s) => s.reference?.shown,
  minifig: (s) => Boolean(s.bench && Object.keys(s.bench).length), simulate: () => window.brickworksSimulate?.open,
  render: () => window.brickworksRender?.open,
};
const RUN_MS = 6 * 3600 * 1000;

function watchStudio() {
  const boot = window.brickworksBoot || {};
  const since = Number(boot.ui || boot.ready || performance.now());
  for (const mark of ["compiled", "made", "ready", "data", "catalogue", "ui"]) {
    if (Number.isFinite(boot[mark])) one("load", `studio_${mark}`, boot[mark]);
  }
  const navigation = performance.getEntriesByType("navigation")[0];
  if (navigation) one("load", "studio_ttfb", navigation.responseStart);
  one("milestone", "studio", since);
  let tool = "";
  let toolSince = performance.now();
  const open = {};
  let put = undefined;
  let parts = 0;
  let saves = 0;
  let simulating = null;
  let rendering = null;
  let booklet = null;
  let together = null;
  let controls = {};
  const shown = new Set();

  // A part put down or a model saved: counted, the first timed from when
  // the studio came up.
  const firstOf = (what) => one("milestone", `first_${what}`, performance.now() - since);
  const wrote = window.brickworksWrote;
  if (typeof wrote === "function" && !wrote.brickworksTally) {
    const watching = function (path) {
      if (/^user:\/\/models\//.test(String(path || ""))) {
        count("save", "model");
        acted("save", "model");
        if (saves++ === 0) firstOf("save");
      }
      return wrote.apply(this, arguments);
    };
    watching.brickworksTally = true;
    window.brickworksWrote = watching;
  }

  const tick = () => {
    const s = window.brickworksState;
    if (!s || typeof s !== "object") return;
    const mode = typeof s.mode === "string" ? s.mode : "";
    const now = performance.now();
    if (mode !== tool) {
      if (tool) count("tool", tool, { ms: Math.min(now - toolSince, RUN_MS) });
      tool = mode;
      toolSince = now;
      if (mode) acted("tool", mode);
    }
    for (const [panel, isOpen] of Object.entries(PANELS)) {
      let now = false;
      try {
        now = Boolean(isOpen(s));
      } catch {
        now = false;
      }
      if (now && !open[panel]) {
        count("panel", panel);
        acted("panel", panel);
      }
      open[panel] = now;
    }
    const putId = s.put && typeof s.put === "object" ? s.put.id : null;
    if (put === undefined) put = putId;
    else if (putId !== null && putId !== put) {
      put = putId;
      count("part", "placed");
      acted("part", "placed");
      if (parts++ === 0) firstOf("part");
    }
    // Runs: how long, and whether they went.
    const sim = window.brickworksSimulate;
    if (sim?.playing && !simulating) simulating = now;
    else if (simulating && !sim?.playing) {
      one("run", "simulate", now - simulating, !String(sim?.trouble || ""));
      acted("run", "simulate");
      simulating = null;
    }
    const render = window.brickworksRender;
    if (render?.working && !rendering) rendering = now;
    else if (rendering && !render?.working) {
      one("run", `render${render?.kind ? `_${render.kind}` : ""}`, now - rendering, Boolean(render?.bytes || render?.frames));
      acted("run", "render");
      rendering = null;
    }
    if (window.brickworksBooklet && !booklet) booklet = now;
    else if (booklet && !window.brickworksBooklet) {
      one("run", "booklet", now - booklet);
      acted("run", "booklet");
      booklet = null;
    }
    const room = window.brickworksTogether;
    if (room?.live && !together) {
      together = now;
      acted("run", "together");
    } else if (together && !room?.live) {
      one("run", "together", now - together, true);
      together = null;
    }
    // The controls shown, each once a page.
    controls = window.brickworksControls && typeof window.brickworksControls === "object" ? window.brickworksControls : {};
    for (const name of Object.keys(controls)) {
      if (shown.has(name)) continue;
      shown.add(name);
      const safe = nameOf(name);
      if (safe && !seenNew.includes(safe) && seenNew.length < 400) seenNew.push(safe);
    }
  };

  // A press: the smallest named control under the finger or pointer.
  addEventListener("pointerdown", (event) => {
    if (!event.isTrusted) return;
    const canvas = document.querySelector("canvas");
    const box = canvas ? canvas.getBoundingClientRect() : { left: 0, top: 0 };
    const x = event.clientX - box.left;
    const y = event.clientY - box.top;
    let best = "";
    let area = Infinity;
    for (const [name, at] of Object.entries(controls)) {
      if (!at || !Number.isFinite(at.w) || !Number.isFinite(at.h)) continue;
      if (Math.abs(x - at.x) <= at.w / 2 && Math.abs(y - at.y) <= at.h / 2 && at.w * at.h < area) {
        best = name;
        area = at.w * at.h;
      }
    }
    if (best) {
      count("press", best);
      acted("press", best);
    }
  }, { capture: true, passive: true });
  // A command run from the palette: the one lit when Enter went down.
  addEventListener("keydown", (event) => {
    if (event.key !== "Enter" || !event.isTrusted) return;
    const palette = window.brickworksState?.palette;
    if (!palette?.open || !palette.lit) return;
    const lit = String(palette.lit);
    const name = /^[a-z0-9_]+$/.test(lit) ? lit : "find_part";
    count("command", name);
    acted("command", name);
  }, { capture: true, passive: true });

  tick();
  setInterval(() => {
    if (document.visibilityState === "visible") tick();
  }, 1000);
  // Frames, a few seconds at a time: 60 s in, then every five minutes.
  let samples = 0;
  const sample = () => {
    if (document.visibilityState !== "visible" || samples >= 8) return;
    samples += 1;
    const gaps = [];
    let last = 0;
    const until = performance.now() + 3000;
    const step = (at) => {
      if (last) gaps.push(at - last);
      last = at;
      if (at < until && document.visibilityState === "visible") requestAnimationFrame(step);
      else if (gaps.length > 10) {
        gaps.sort((a, b) => a - b);
        one("frames", "frame_ms", gaps[Math.floor(gaps.length / 2)]);
        one("frames", "frame_p95_ms", gaps[Math.floor(gaps.length * 0.95)]);
      }
    };
    requestAnimationFrame(step);
  };
  setTimeout(sample, 60000);
  setInterval(sample, 300000);
  return () => {
    if (tool) count("tool", tool, { ms: Math.min(performance.now() - toolSince, RUN_MS) });
    toolSince = performance.now();
  };
}

// ---------------------------------------------------------------------------
// Errors: where, never what they said.

function watchErrors() {
  let told = 0;
  const places = new Set();
  // At most ten places a page, each counted however often it comes.
  const place = (where) => {
    if (told > 500) return;
    told += 1;
    const safe = nameOf(where, true);
    if (!places.has(safe) && places.size >= 10) return;
    places.add(safe);
    count("error", safe, { digits: true });
  };
  addEventListener("error", (event) => {
    if (!(event instanceof ErrorEvent)) return;
    let file = "external";
    try {
      const url = new URL(event.filename || "", location.href);
      if (url.origin === location.origin) file = url.pathname.split("/").pop() || "page";
    } catch {
      file = "page";
    }
    place(`js:${file}:${event.lineno || 0}`);
  });
  addEventListener("unhandledrejection", () => place("js:rejection"));
  if (!studio) return;
  // The engine's errors come out through console.error with the script's
  // place: "res://src/main.gd:120".
  const before = console.error;
  if (before.brickworksTally) return;
  const watched = function (...args) {
    try {
      const found = /res:\/\/([A-Za-z0-9_/.-]+\.gd):(\d+)/.exec(typeof args[0] === "string" ? args[0] : "");
      if (found) place(`gd:${found[1]}:${found[2]}`);
    } catch {
      // Never in the way of what is being said.
    }
    return before.apply(this, args);
  };
  watched.brickworksTally = true;
  console.error = watched;
}

// ---------------------------------------------------------------------------
// Start, once a page.

function start() {
  if (window.brickworksTallying) return;
  window.brickworksTallying = true;
  const visit = visitNow();
  watchErrors();
  watchActs();
  let timings = () => {};
  let stopTool = () => {};
  if (studio) {
    count("view", "/app");
    acted("view", "/app");
    stopTool = watchStudio();
  } else {
    viewed();
    timings = siteTimings(visit.id);
    addEventListener("popstate", viewed);
    for (const method of ["pushState", "replaceState"]) {
      const before = history[method];
      history[method] = function () {
        const out = before.apply(this, arguments);
        setTimeout(viewed, 0);
        return out;
      };
    }
    addEventListener("brickworks:signed-in", () => {
      count("act", "account.signed_in", { ok: true });
      acted("act", "account.signed_in");
    });
  }
  setInterval(() => {
    if (queue.size || singles.length || seenNew.length || lastAct !== lastSent) send(false);
  }, EVERY_MS);
  const leave = () => {
    stopTool();
    timings();
    send(true);
  };
  addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") leave();
    else visibleSince = Date.now();
  });
  addEventListener("pagehide", leave);
  if (!studio) setTimeout(() => { timings(); send(false); }, EVERY_MS);
}

const state = countingState();
if (state === "yes" || state === "on") start();
else if (state === "ask") {
  // Asked on a site page, never in the studio; counted from the yes on.
  addEventListener("brickworks:counting", (event) => { if (event.detail?.on) start(); }, { once: true });
  if (!studio) import("/counting-ask.js").then((ask) => ask.ask()).catch(() => null);
}
