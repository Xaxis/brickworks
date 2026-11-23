// The tabs of an object's page (pagekit, 2026-11-23; docs/DESIGN_SYSTEM.md
// "An object's page"): a model's, a set's, a profile's, a challenge's and a
// Talk thread's, one pattern. The owner, 23 Nov, on a model's page whose
// "tabs" were jump links down one 3,800 px page: "somehow you need to
// drastically improve the ui/ux patterns used ... across the entire site".
//
// The server draws `.tabs.obj-tabs[role=tablist]`, each tab an
// `a[role=tab]` whose href is its panel's key (#comments) and whose
// aria-controls names its panel, a `[role=tabpanel]` of the page; the
// chosen one aria-selected, every other panel `hidden`. Here:
//
// - a tab chosen shows its panel alone, and the address says its key
//   (history.pushState), so a link to /m/X#comments opens on Comments and
//   Back goes back a tab; the first tab is the address with no key;
// - the page stays where it is, unless the tabs were above the screen:
//   then they come to its top, so the panel is read from its start;
// - Left and Right (and Home, End) move along the tabs, choosing as they
//   go, as a tablist does (the panels are on the page already); the chosen
//   tab is the one Tab reaches, the panel the next stop;
// - an address naming something inside a panel (#comment-12, #photo-x, or a
//   key a tab answers to as well, data-also="about") opens that panel, and
//   any link on the page to one does, wherever it is;
// - with no script, every tab is a link to its panel and site.css shows the
//   panel the address names (:target), so the page still works.
//
// A row of tabs that are pages of their own (a profile's ?tab=) is a nav of
// links in the same look, with no script: each is reached by Tab.
//
//   import { startTabs } from "/tabs.js";
//   const tabs = startTabs(document.querySelector(".obj-tabs"));
//   tabs.show("builds");            // from a button elsewhere on the page
//   panel.addEventListener("tab:shown", ...)  // fired on a panel as it shows

export function startTabs(list) {
  if (!list || list.dataset.started) return list?.tabs || null;
  list.dataset.started = "yes";
  const all = () => [...list.querySelectorAll('[role="tab"]')];
  const shown = () => all().filter((tab) => !tab.hidden);
  const keyOf = (tab) => tab.getAttribute("aria-controls") || "";
  const panelOf = (tab) => document.getElementById(keyOf(tab));
  const local = (tab) => Boolean(panelOf(tab));
  const first = () => shown().find(local) || null;
  // Tabs a page's script fills in later (a challenge's) may all be hidden
  // yet: it calls refresh() once it has shown them.
  if (!all().some(local)) return null;
  // Chosen by the reader (a press, a key, Back): a tab that shows later
  // never takes over from what they chose.
  let touched = false;
  // The script has the panels now: the :target rule of the page with no
  // script stops applying (site.css .obj-panels[data-tabs]).
  const holder = list.closest(".obj-panels") || list.parentElement;
  holder?.setAttribute("data-tabs", "on");

  /// The tab [key] names: its own, one it answers to too, or the one whose
  /// panel holds the element of that id; and that element.
  function named(key) {
    if (!key) return null;
    const tab = shown().find((one) => local(one) && (keyOf(one) === key || (one.dataset.also || "").split(" ").includes(key)));
    if (tab) return { tab, inside: null };
    const found = document.getElementById(key);
    const panel = found?.closest('[role="tabpanel"]');
    const holding = panel && shown().find((one) => panelOf(one) === panel);
    return holding ? { tab: holding, inside: found === panel ? null : found } : null;
  }
  const hashKey = () => {
    try {
      return decodeURIComponent(location.hash.slice(1));
    } catch {
      return "";
    }
  };

  /// [tab] chosen: its panel alone shown, it the one Tab reaches.
  function mark(tab) {
    for (const one of all()) {
      if (!local(one)) continue;
      const on = one === tab;
      one.setAttribute("aria-selected", String(on));
      one.tabIndex = on ? 0 : -1;
      const panel = panelOf(one);
      if (panel.hidden === on) {
        panel.hidden = !on;
        if (on) panel.dispatchEvent(new CustomEvent("tab:shown", { bubbles: true, detail: { key: keyOf(one) } }));
      }
    }
    // On a phone the row scrolls inside itself: the chosen tab in view.
    if (tab.offsetLeft < list.scrollLeft || tab.offsetLeft + tab.offsetWidth > list.scrollLeft + list.clientWidth) {
      list.scrollLeft = Math.max(0, tab.offsetLeft - 16);
    }
  }

  /// The tabs at the top of the screen, if they were above it.
  function bringUp() {
    const top = list.getBoundingClientRect().top;
    const header = parseFloat(getComputedStyle(document.documentElement).scrollPaddingTop) || 0;
    if (top < header) list.scrollIntoView({ block: "start" });
  }

  function show(key, { push = false, focus = false } = {}) {
    const asked = typeof key === "string" ? named(key) : { tab: key, inside: null };
    const tab = asked?.tab || first();
    if (!tab) return null;
    mark(tab);
    if (push) {
      const hash = tab === first() ? "" : `#${keyOf(tab)}`;
      if (location.hash !== hash) history.pushState({ tab: keyOf(tab) }, "", `${location.pathname}${location.search}${hash}`);
    }
    if (focus) tab.focus();
    return asked;
  }

  list.addEventListener("click", (event) => {
    const tab = event.target.closest('[role="tab"]');
    if (!tab || !local(tab) || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    touched = true;
    show(tab, { push: true });
    bringUp();
  });
  list.addEventListener("keydown", (event) => {
    const tabs = shown().filter(local);
    const at = tabs.indexOf(document.activeElement);
    if (at < 0) return;
    const to = { ArrowRight: at + 1, ArrowLeft: at - 1, Home: 0, End: tabs.length - 1 }[event.key];
    if (to === undefined) return;
    event.preventDefault();
    const tab = tabs[(to + tabs.length) % tabs.length];
    touched = true;
    show(tab, { push: true, focus: true });
  });

  // Back and Forward, and a link anywhere on the page to a panel or to
  // something in one (a fact's #versions, a comment's #comment-12).
  // An address naming nothing in the tabs (Skip to content's #main) leaves
  // them as they are.
  const fromAddress = (scroll) => {
    const key = hashKey();
    const asked = key ? named(key) : { tab: first(), inside: null };
    if (!asked?.tab) return;
    touched = true;
    show(asked.tab);
    if (!scroll) return;
    if (asked.inside) asked.inside.scrollIntoView({ block: "center" });
    else bringUp();
  };
  addEventListener("popstate", () => fromAddress(false));
  addEventListener("hashchange", () => fromAddress(true));
  // Opened at a key: the server drew the first tab chosen.
  const asked = named(hashKey());
  if (asked) {
    show(asked.tab);
    // The browser found the element before the script hid the others:
    // where it was, it still is.
    if (asked.inside) requestAnimationFrame(() => asked.inside.scrollIntoView({ block: "center" }));
  } else {
    const drawn = shown().find((one) => local(one) && one.getAttribute("aria-selected") === "true") || first();
    if (drawn) mark(drawn);
  }
  const chosen = () => shown().find((one) => local(one) && one.getAttribute("aria-selected") === "true") || null;
  /// After the page's script hid or showed tabs: a chosen tab gone hidden
  /// gives way to the first; until the reader chooses, the one the address
  /// names, once it shows.
  function refresh() {
    const named_ = named(hashKey());
    if (!touched && named_ && named_.tab !== chosen()) return show(named_.tab);
    if (!chosen()) return show(first());
    return null;
  }
  list.tabs = { show: (key, options) => show(key, { push: true, ...options }), shown: () => keyOf(chosen() || first() || list),
    refresh };
  return list.tabs;
}
