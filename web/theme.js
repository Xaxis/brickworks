// The theme a person chose (System, Light or Dark), set before the page is
// drawn: a plain script in every page's <head> (docs/DESIGN_SYSTEM.md,
// "Themes"). Kept in this browser, followed by every open tab, and signed
// in on the account too (web/theme-account.js). Any [data-theme-choice]
// button chooses.
(() => {
  const KEY = "brickworks.theme";
  const BAR = { dark: "#0b0c0e", light: "#fbfbfa" };
  const root = document.documentElement;
  const read = (key) => {
    try {
      return localStorage.getItem(key);
    } catch {
      return null;
    }
  };
  const chosen = () => (read(KEY) === "light" || read(KEY) === "dark" ? read(KEY) : "system");
  const apply = (theme) => {
    if (theme === "system") root.removeAttribute("data-theme");
    else root.setAttribute("data-theme", theme);
    // The browser's bar: each line its own theme's under System.
    for (const bar of document.querySelectorAll('meta[name="theme-color"]')) {
      bar.content = BAR[theme === "system" ? (/light/.test(bar.media) ? "light" : "dark") : theme];
    }
    for (const button of document.querySelectorAll("[data-theme-choice]")) {
      button.setAttribute("aria-pressed", String(button.dataset.themeChoice === theme));
    }
  };
  // quiet: the account's own, not sent back to it.
  const choose = (theme, quiet = false) => {
    try {
      localStorage.setItem(KEY, theme);
    } catch {}
    apply(theme);
    if (!quiet) document.dispatchEvent(new CustomEvent("brickworks:theme", { detail: theme }));
  };
  window.brickworksTheme = { chosen, choose, picked: () => read(KEY) !== null };
  apply(chosen());
  addEventListener("storage", (event) => event.key === KEY && apply(chosen()));
  document.addEventListener("click", (event) => {
    const button = event.target instanceof Element && event.target.closest("[data-theme-choice]");
    if (button) choose(button.dataset.themeChoice);
  });
  const follow = () => import("/theme-account.js").then((account) => account.follow()).catch(() => null);
  addEventListener("brickworks:signed-in", follow);
  document.addEventListener("DOMContentLoaded", () => {
    apply(chosen());
    // An embed's card (/m/<id>/embed) follows the choice and never asks the
    // account: it is somebody else's page's, and may reach nothing else.
    if (read("brickworks.session") && !root.hasAttribute("data-embed")) follow();
  });
})();

// The language a person reads the site in: English, German,
// French or Spanish, the app's four (src/ui/language.gd). The one they
// chose (the footer's Language, or the app's Settings, which keeps it here
// too), else the first of their browser's languages the site has (as its
// Accept-Language says them), else English. An English page with a copy
// in that language (tools/site_lang.py, at /de/...) gives way to it before
// it is drawn; a copy reached by its own address stays itself unless
// another was chosen. Every
// link into the app carries the language (/app?lang=de), so a German
// visitor opens a German app. And a page's scripts say their words in the
// page's language: window.brickworksLang.say, from the words
// tools/site_lang.py put in the copy (#site-words).
(() => {
  const KEY = "brickworks.lang";
  const CODES = ["en", "de", "fr", "es"];
  const root = document.documentElement;
  const kept = () => {
    try {
      const code = localStorage.getItem(KEY);
      return CODES.includes(code) ? code : null;
    } catch {
      return null;
    }
  };
  const browser = () => (navigator.languages || [navigator.language || ""])
    .map((tag) => String(tag).slice(0, 2).toLowerCase()).find((code) => CODES.includes(code)) || null;
  const page = CODES.includes(root.lang.slice(0, 2)) ? root.lang.slice(0, 2) : "en";
  const chosen = () => kept() || browser() || "en";
  // This page in [code], where it has a copy in it: its address here. The
  // page not found (404.html, data-missing) answers every address there is
  // nothing at, so its copy is the same address in the language, /de/<it>,
  // which answers with the copy's (tools/deploy.sh).
  const copyIn = (code) => {
    if (root.hasAttribute("data-missing")) {
      const rest = location.pathname.replace(/^\/(?:de|fr|es)(?=\/|$)/, "") || "/";
      return code === "en" ? rest : `/${code}${rest === "/" ? "" : rest}`;
    }
    const link = document.querySelector(`link[rel="alternate"][hreflang="${code}"]`);
    return link ? new URL(link.href).pathname : null;
  };
  // A link that asks for a language (?lang=en: a copy's link to the English
  // text that binds, tools/site_lang.py) is shown in it, this once.
  const asked = new URLSearchParams(location.search).get("lang");
  const wanted = (CODES.includes(asked) ? asked : null) || kept() || (page === "en" ? browser() : null);
  const copy = wanted && wanted !== page ? copyIn(wanted) : null;
  if (copy && copy !== location.pathname) location.replace(copy + location.search + location.hash);
  let words = null;
  // [english] as this page says it, each {name} in it filled from [values].
  const say = (english, values = {}) => {
    if (!words) {
      try {
        words = JSON.parse(document.getElementById("site-words")?.textContent || "{}");
      } catch {
        words = {};
      }
    }
    return String(words[english] ?? english).replace(/\{(\w+)\}/g, (all, name) => (name in values ? String(values[name]) : all));
  };
  // The app's language, as the address into it says it: only once a
  // language is chosen or is not English, so the app's own choice stands
  // for somebody who never made one here.
  const carried = () => kept() || (page !== "en" ? page : browser() !== "en" ? browser() : null);
  const carry = () => {
    const code = carried();
    if (!code) return;
    for (const link of document.querySelectorAll('a[href^="/app"]')) {
      const to = new URL(link.href);
      if (to.pathname !== "/app") continue;
      to.searchParams.set("lang", code);
      link.href = to.pathname + to.search + to.hash;
    }
  };
  const choose = (code) => {
    if (!CODES.includes(code)) return;
    try {
      localStorage.setItem(KEY, code);
    } catch {}
    const copy = copyIn(code);
    // Without a language the address asked for, which would send it back.
    const query = new URLSearchParams(location.search);
    query.delete("lang");
    const search = query.toString() ? `?${query}` : "";
    if (code !== page && copy) location.assign(copy + search + location.hash);
    else carry();
  };
  window.brickworksLang = {
    code: page, chosen, choose, say,
    // The language a link into the app asks for, as carry() gives the
    // page's own: web/card.js appAt gives a link drawn later the same.
    app: carried,
    locale: page === "en" ? "en-US" : page,
    number: (n) => Number(n).toLocaleString(page === "en" ? "en-US" : page),
  };
  document.addEventListener("DOMContentLoaded", () => {
    carry();
    // The choice kept, as the theme's shows its own; on a page with no copy
    // in it (still English) that is the language the app opens in.
    for (const choice of document.querySelectorAll("select[data-lang-choice]")) choice.value = kept() || page;
  });
  document.addEventListener("change", (event) => {
    const choice = event.target instanceof Element && event.target.closest("select[data-lang-choice]");
    if (choice) choose(choice.value);
  });
})();

// Signed in here (homefeed): a kept sign-in ("brickworks.session") marks
// <html data-signed="in"> before the first frame, so the home's feed drawn
// for them moves nothing. Who, and whether it holds, are account.js's.
(() => {
  try {
    const kept = JSON.parse(localStorage.getItem("brickworks.session") || "null");
    if (kept && kept.refresh_token) document.documentElement.dataset.signed = "in";
  } catch {
    // Nothing kept, or storage refused: signed out.
  }
})();

// The beta (betahome): while open, a strip at every page's top (betabar.js)
// with Report a bug and Join, and the landing page's Open beta. What the
// site last said of it is kept here ("brickworks.beta"): open in the last
// day, <html data-beta="open"> is set before anything is drawn, so what is
// held for it is in place at the first frame; off in the last ten minutes,
// the bar's script is not asked for. The bar's own room at the top
// (<html data-betabar>, site.css) is decided here, before the first frame,
// and never after but by the person's own act (betabar.js), so the strip
// moves nothing as it comes (pagebar) and never goes once drawn: unless its
// × hid it here, a page the server makes holds it as that page says the
// beta is (<meta name="brickworks-beta">, api/_settings.js sayBeta), unless
// what was heard here is newer (a page the CDN kept); any other holds it
// unless the beta was last heard off, so a first visit holds it as for the
// open beta. A set's page on a phone held it, then let it go half a second
// in, as the server said off (checkdrift, 2026-11-23). Never on an embed's
// card or the connector's consent page.
(() => {
  const root = document.documentElement;
  if (root.hasAttribute("data-embed") || /^\/(?:(?:de|fr|es)\/)?oauth\//.test(location.pathname)) return;
  let heard = null;
  try {
    heard = JSON.parse(localStorage.getItem("brickworks.beta") || "null");
  } catch {
    heard = null;
  }
  const page = document.querySelector('meta[name="brickworks-beta"]');
  const said = page && (!heard || Number(page.dataset.at || 0) >= Number(heard.at || 0)) ? page.content : "";
  const age = Date.now() - Number(heard?.at || 0);
  if (said === "open" || (!said && heard?.beta === "open" && age < 86400000)) root.dataset.beta = "open";
  if (said === "off" || (!said && heard?.beta === "off" && age < 600000)) {
    // Said for the page's own scripts (web/landing.js), which then ask nothing.
    window.brickworksBeta = "off";
    return;
  }
  // As web/betabar.js barShown reads it: "off", or a day's hiding not ended.
  let hidden = null;
  try {
    hidden = JSON.parse(localStorage.getItem("brickworks.betabar.hidden") || "null");
  } catch {
    hidden = null;
  }
  const shown = !(hidden === "off" || (typeof hidden === "number" && hidden > Date.now()));
  if (shown && (said === "open" || (!said && heard?.beta !== "off"))) root.dataset.betabar = "held";
  // Not loaded (offline), the room held for it goes.
  const load = () => import("/betabar.js").catch(() => { delete root.dataset.betabar; });
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", load);
  else load();
})();

// The site's notice (console3, 2026-11-13): what the owner set in the
// console, on every page (web/notice.js), floating at the window's foot;
// not on an embed's card or the connector's consent page either.
(() => {
  if (document.documentElement.hasAttribute("data-embed") || /^\/(?:(?:de|fr|es)\/)?oauth\//.test(location.pathname)) return;
  const load = () => import("/notice.js").catch(() => null);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", load);
  else load();
})();

// The site installed, and this device's notifications (homescreen,
// 2026-11-22): web/push.js, on every page but an embed's card and the
// connector's consent page. The browser's offer to install is held here,
// from the first moment, so its own bar never shows: push.js offers it
// from a second visit, never the first.
(() => {
  if (document.documentElement.hasAttribute("data-embed") || /^\/(?:(?:de|fr|es)\/)?oauth\//.test(location.pathname)) return;
  addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    window.brickworksInstall = event;
  });
  // Only once the page has loaded: a first visit waits on nothing of it.
  const load = () => import("/push.js").catch(() => null);
  if (document.readyState === "complete") load();
  else addEventListener("load", load, { once: true });
})();

// Whether counting is said no to here, as web/counting.js's countingState
// has it, its cheap half: [driven] a browser a program drives that did not
// ask to be counted (a check's) is a no too. Read before the counter is
// fetched, so a no costs no request at all (inreview L3), and before the
// social desk's visit is told (L2).
window.brickworksCountingNo = (driven = true) => {
  const kept = (key) => {
    try {
      return localStorage.getItem(key);
    } catch {
      return null;
    }
  };
  const dnt = String(navigator.doNotTrack ?? window.doNotTrack ?? navigator.msDoNotTrack ?? "");
  return dnt === "1" || dnt === "yes" || navigator.globalPrivacyControl === true || kept("brickworks.counting") === "no"
    || (driven && navigator.webdriver === true && kept("brickworks.counting.check") !== "1");
};

// How the site is used, counted (insights, 2026-11-18; web/tally.js,
// /counting): asked for once the page has loaded and gone idle, never on an
// embed's card, the connector's consent page or the console, and never
// where the browser or the person said no (web/counting.js).
(() => {
  if (document.documentElement.hasAttribute("data-embed") || /^\/(?:(?:de|fr|es)\/)?(?:oauth\/|admin)/.test(location.pathname)) return;
  if (window.brickworksCountingNo()) return;
  const idle = (then) => (window.requestIdleCallback ? requestIdleCallback(then, { timeout: 4000 }) : setTimeout(then, 1500));
  const load = () => idle(() => import("/tally.js").catch(() => null));
  if (document.readyState === "complete") load();
  else addEventListener("load", load, { once: true });
})();

// How this visit came, for the owner's mail of a new sign-up (ownernotify,
// 2026-11-18; api/_notify.js): the site that sent the visitor, and a link's
// utm_ tags, read before they are taken out of the address below. The
// visit's first that says anything is kept for this tab alone
// (sessionStorage, gone when it closes), so a page or two later, or in the
// studio, it is still known (onfix); never sent but with a sign-in code
// asked for in this tab (web/account.js, web/authorize.js,
// src/account/account.gd).
(() => {
  try {
    const KEY = "brickworks.came";
    // Each may throw (a browser that keeps nothing for the tab, a referrer
    // that is no address): then that is not known, and the rest still is.
    const safely = (act) => {
      try {
        return act(globalThis.sessionStorage);
      } catch {
        return null;
      }
    };
    let came = safely((store) => JSON.parse(store?.getItem(KEY) || "null"));
    if (!came || typeof came !== "object" || Array.isArray(came)) {
      came = {};
      const params = new URLSearchParams(location.search);
      for (const name of ["source", "medium", "campaign"]) {
        const value = String(params.get(`utm_${name}`) || "").trim();
        if (/^[A-Za-z0-9 ._+-]{1,60}$/.test(value)) came[name] = value;
      }
      const from = safely(() => (document.referrer ? new URL(document.referrer).hostname.toLowerCase() : "")) || "";
      if (from && from !== location.hostname && !/(^|\.)brickworks\.diy$/.test(from)) came.referrer = from.slice(0, 100);
      if (Object.keys(came).length) safely((store) => store?.setItem(KEY, JSON.stringify(came)));
    }
    if (Object.keys(came).length) globalThis.brickworksCame = Object.freeze(came);
  } catch {
    // Nothing known of how they came: the mail says so.
  }
})();

// A visit a post from the owner's social desk brought (socialdesk,
// 2026-11-18; api/_social.js, /admin › Social): the desk tags the site's
// links in what it sends with utm_campaign=bw-<send id>. The landing is told
// once, with a random number of its own so it is counted once, and nothing
// else about the visitor; once the page has loaded (the visit counter has
// read the address too) the tags are taken out of the address, so a reload
// or a link copied from it does not count again.
//
// It is a count, so it keeps to /counting (inreview L2): never with Do Not
// Track or GPC, or after a No; where a yes comes first (web/counting.js,
// fetched for such a landing only), only once it is given on this page. A
// check's driven browser is told, as the desk's own flow lands one.
(() => {
  try {
    const params = new URLSearchParams(location.search);
    const campaign = params.get("utm_campaign") || "";
    if (!/^bw-[a-z0-9]{10}$/.test(campaign)) return;
    const nonce = Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => (byte % 36).toString(36)).join("");
    const body = JSON.stringify({ campaign, nonce, path: location.pathname, source: params.get("utm_source") || "" });
    const tell = () => {
      const told = navigator.sendBeacon && navigator.sendBeacon("/api/plans?op=social_visit", new Blob([body], { type: "application/json" }));
      if (!told) {
        fetch("/api/plans?op=social_visit", { method: "POST", headers: { "content-type": "application/json" }, body, keepalive: true })
          .catch(() => null);
      }
    };
    let said = null;
    try {
      said = localStorage.getItem("brickworks.counting");
    } catch {
      said = null;
    }
    if (window.brickworksCountingNo(false)) {
      // Not told.
    } else if (said === "yes") tell();
    else {
      import("/counting.js").then((counting) => {
        if (counting.countingState() !== "ask") tell();
        else addEventListener("brickworks:counting", (event) => { if (event.detail?.on) tell(); }, { once: true });
      }).catch(() => null);
    }
    const untag = () => {
      const now = new URLSearchParams(location.search);
      for (const key of [...now.keys()]) if (key.startsWith("utm_")) now.delete(key);
      const rest = now.toString();
      history.replaceState(history.state, "", `${location.pathname}${rest ? `?${rest}` : ""}${location.hash}`);
    };
    if (document.readyState === "complete") untag();
    else addEventListener("load", untag, { once: true });
  } catch {
    // A browser without these counts nothing; the page is as it was.
  }
})();
