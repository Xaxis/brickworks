// The theme a person chose (System, Light or Dark), set before the page is
// drawn: a plain script in every page's <head> (docs/DESIGN_SYSTEM.md,
// "Themes"). Kept in this browser, followed by every open tab, and signed
// in on the account too (web/theme-account.js). Any [data-theme-choice]
// button chooses.
(() => {
  const KEY = "brickworks.theme";
  const BAR = { dark: "#0e1013", light: "#f4f5f7" };
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
    if (read("brickworks.session")) follow();
  });
})();
