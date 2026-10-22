// The site's theme: System, Light or Dark (2026-10-22, docs/SOCIAL.md U1).
// In every page's <head>, not deferred (tools/site_shell.py, api/_directory.js
// siteChrome), so the chosen theme is set before anything is drawn and the
// page never flashes the other. site.css keys its light set on
// <html data-theme>; System leaves it off and follows the computer.
//
// The choice is kept in this browser (localStorage, a preference, not
// tracking: /privacy), applied in every open tab at once, and, signed in,
// on the account (web/theme-account.js, loaded only then). The buttons are
// any [data-theme-choice] on the page: the footer's, Menu's and Settings'.
(() => {
  const KEY = "brickworks.theme";
  const BAR = { dark: "#0e1013", light: "#f4f5f7" };
  const root = document.documentElement;
  const chosen = () => {
    try {
      const kept = localStorage.getItem(KEY);
      return kept === "light" || kept === "dark" ? kept : "system";
    } catch {
      return "system";
    }
  };
  const apply = (theme) => {
    if (theme === "system") root.removeAttribute("data-theme");
    else root.setAttribute("data-theme", theme);
    // The browser's bar: each line its own theme's colour under System,
    // both the chosen one's otherwise.
    for (const bar of document.querySelectorAll('meta[name="theme-color"]')) {
      bar.content = BAR[theme === "system" ? (/light/.test(bar.media) ? "light" : "dark") : theme];
    }
    for (const button of document.querySelectorAll("[data-theme-choice]")) {
      button.setAttribute("aria-pressed", String(button.dataset.themeChoice === theme));
    }
  };
  // quiet: from the account, so not sent back to it.
  const choose = (theme, quiet = false) => {
    try {
      localStorage.setItem(KEY, theme);
    } catch {
      // A browser that keeps nothing: this page only.
    }
    apply(theme);
    if (!quiet) document.dispatchEvent(new CustomEvent("brickworks:theme", { detail: theme }));
  };
  const picked = () => {
    try {
      return localStorage.getItem(KEY) !== null;
    } catch {
      return false;
    }
  };
  window.brickworksTheme = { chosen, choose, picked };
  apply(chosen());
  addEventListener("storage", (event) => {
    if (event.key === KEY) apply(chosen());
  });
  document.addEventListener("click", (event) => {
    const button = event.target instanceof Element && event.target.closest("[data-theme-choice]");
    if (button) choose(button.dataset.themeChoice);
  });
  // Signed in (web/account.js keeps the session there): the account's.
  const follow = () => import("/theme-account.js").then((account) => account.follow()).catch(() => null);
  addEventListener("brickworks:signed-in", follow);
  document.addEventListener("DOMContentLoaded", () => {
    apply(chosen());
    try {
      if (localStorage.getItem("brickworks.session")) follow();
    } catch {
      // Nothing kept: nobody is signed in here.
    }
  });
})();
