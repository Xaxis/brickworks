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

// The language a person reads the site in (2026-11-01): English, German,
// French or Spanish, the app's four (src/ui/language.gd). The one they
// chose (the footer's Language, or the app's Settings, which keeps it here
// too), else the first of their browser's languages the site has (as its
// Accept-Language says them), else English. An English page with a copy
// in that language (tools/site_lang.py: the landing page and the download
// page, at /de, /de/download...) gives way to it before it is drawn; a copy
// reached by its own address stays itself unless another was chosen. Every
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
  // This page in [code], where it has a copy in it: its address here.
  const copyIn = (code) => {
    const link = document.querySelector(`link[rel="alternate"][hreflang="${code}"]`);
    return link ? new URL(link.href).pathname : null;
  };
  const wanted = kept() || (page === "en" ? browser() : null);
  if (wanted && wanted !== page && copyIn(wanted)) {
    location.replace(copyIn(wanted) + location.search + location.hash);
  }
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
    if (code !== page && copy) location.assign(copy + location.search + location.hash);
    else carry();
  };
  window.brickworksLang = {
    code: page, chosen, choose, say,
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
