// The gallery, one page to browse (web/gallery.html; browse, 2026-11-02,
// the owner: "one is just a tab in another... they should be like filters
// too, not loading actual separate pages"): the models (Top, New and
// Following, web/models.js), photos of real builds (web/builds.js),
// collections (web/collections.js) and every real set (web/library.js),
// each a tab that switches in place, as Printables' and Thingiverse's
// Models, Makes and Collections are tabs of one page to browse.
//
// One search box, which searches the tab it is on and keeps its words from
// tab to tab; one bar of filters, showing the tab's own (gallery.html
// data-list, said by <html data-tab>); one grid, #models, and one pager
// (web/pager.js), made again for each list as it is switched to. Each tab
// is at the address its own page had (/gallery, /gallery?sort=newest,
// /gallery?following=1, /builds, /collections, /library, in German /de/...),
// so a tab is a link to send and to reload: a press on it, or on any link
// of the page to one of those addresses, asks its list here and puts its
// address with history.pushState; Back and Forward ask the tab of the
// address they come to, and its pages and the card left in view where they
// were (web/pager.js keeps them with the address, and is told where the
// page was each time it stops scrolling). A filter or a search asks again
// in place, the address put back with replaceState. A search waits for
// typing to stop; a filter asks at once; an answer that comes back after a
// newer question was asked is thrown away.
//
// The page says where it is on <html>: data-tab, which tab, and
// data-browse, "asking", "ready" or "broken"; each list says its own too
// (data-gallery, data-library, data-builds, data-collections), and
// data-pages the pages shown.
import { FIRST_SCREEN, langAt, say, skeletonHtml } from "/card.js";
import { pageAsked, pager } from "/pager.js";
import { modelsList } from "/models.js";
import { setsList } from "/library.js";
import { buildsList } from "/builds.js";
import { collectionsList } from "/collections.js";

(function () {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const root = document.documentElement;
  const grid = $("models");
  const q = $("q");
  const tabs = $("tabs");
  // A probe's own models are tests, which the lists leave out unless asked
  // (api/share.js): an address with tests=1 asks, and keeps asking.
  const tests = new URLSearchParams(location.search).get("tests") === "1";
  const SITE = "https://brickworks.diy";

  // The list shown, its pager, and whether a question is being asked anew.
  let on = null;
  let paged = null;

  const page = {
    q, grid, tests,
    /// Ask the list again from its first page, the address saying what is asked.
    ask,
    /// What the pager shows: {first, last, ...}.
    state: () => paged?.state,
    /// Which tab is shown.
    on: () => on?.tab(),
    /// How many pictures to ask for at once: as many as the first screen
    /// has places for while a list is asked anew (the skeletons, or the
    /// cards it replaces, that are on it), none for Show more's. Twelve
    /// left the third row lazy at 1920.
    eager: () => (root.dataset.browse === "ready" ? 0
      : [...grid.children].filter((one) => one.getBoundingClientRect().top < innerHeight).length || FIRST_SCREEN),
  };
  const models = modelsList(page);
  const lists = [models, setsList(page), buildsList(page), collectionsList(page)];
  // The language's prefix, /de, of the page's own address.
  const at = langAt();

  /// The list an address is: by its path, in the page's language or not
  /// (each list's page, its own path's name: "builds" for /builds).
  function listOf(url) {
    const path = url.pathname.replace(/^\/(?:de|fr|es)(?=\/)/, "").replace(/\/+$/, "");
    return lists.find((one) => `/${one.page}` === path) || null;
  }

  /// The page's head as the tab says: its title, its canonical link and
  /// its other languages', the search's words, the form's address.
  function drawHead() {
    document.title = on.title();
    const path = `/${on.page}`;
    const canonical = document.querySelector('link[rel="canonical"]');
    if (canonical) canonical.href = `${SITE}${at}${path}`;
    for (const link of document.querySelectorAll('link[rel="alternate"][hreflang]')) {
      const code = link.hreflang;
      link.href = `${SITE}${code === "en" || code === "x-default" ? "" : `/${code}`}${path}`;
    }
    const words = on.search();
    q.placeholder = words.placeholder;
    $("q-said").textContent = words.label;
    $("finder").action = `${at}${path}`;
    const nav = document.querySelector('[data-pager="models"]');
    nav.setAttribute("aria-label", say("Pages of {noun}", { noun: say(on.noun[1]) }));
  }

  /// The tabs: each its list's address as it would be asked now (the
  /// search's words kept: every list asks the one search box's), the one
  /// shown marked.
  function drawTabs() {
    const now = on.tab();
    for (const tab of tabs.querySelectorAll("[data-tab]")) {
      const which = tab.dataset.tab;
      tab.href = lists.find((one) => one.tabs.includes(which)).hrefOf(which);
      if (which === now) tab.setAttribute("aria-current", "page");
      else tab.removeAttribute("aria-current");
    }
  }

  /// An address as the history compares it: its path and its question.
  const here = (href) => {
    const url = new URL(href, location.href);
    return url.pathname + url.search;
  };

  /// What every list shares said again: nothing shown yet of the answer.
  function clearStates() {
    for (const id of ["empty", "builds-empty", "collections-empty", "nothing", "quiet", "broken"]) $(id).hidden = true;
    $("found").textContent = "";
    $("found-said").textContent = "";
  }

  /// The list of [url] shown, its question the address's: switched to in
  /// place, or asked again if it is the one shown. [push]: a new entry in
  /// the history; [restore]: the pages and the card left where Back found
  /// them (web/pager.js).
  function go(url, { push = false, restore = false } = {}) {
    const next = listOf(url);
    if (!next) return false;
    const given = url.searchParams;
    q.value = (given.get("q") || "").slice(0, 100);
    if (next !== on) {
      on?.leave();
      paged?.stop();
      if (on) delete root.dataset[on.flag];
      on = next;
      paged = pager({ list: grid, load: (n) => on.load(n), href: (n) => on.href(n), noun: on.noun, drawn, failed,
        counted: on.counted || null, skeleton });
    }
    on.enter(given);
    root.dataset.tab = on.tab();
    drawHead();
    drawTabs();
    clearStates();
    const n = pageAsked(url.search);
    if (push) {
      history.pushState(null, "", on.href(n));
      // Asked from further down than the tabs (a link under the list): the
      // list from its start, as a page opened is.
      if (tabs.getBoundingClientRect().bottom < 0) scrollTo({ top: 0, behavior: "instant" });
    }
    on.asking();
    asking();
    paged.start(n, { restore });
    return true;
  }

  /// The list asked again from its first page, with the address saying
  /// what is asked (a filter, a search, an order).
  function ask() {
    history.replaceState(null, "", on.href(1));
    on.asking();
    drawTabs();
    asking();
    return paged.restart(1);
  }

  function asking() {
    root.dataset.browse = "asking";
    root.dataset[on.flag] = "asking";
  }

  /// A card's stand-in while a page comes.
  function skeleton() {
    const made = document.createElement("template");
    made.innerHTML = skeletonHtml();
    return made.content.firstElementChild;
  }

  /// A page of the list drawn: what the list says of it, then the page.
  function drawn(shown) {
    $("loading").hidden = true;
    $("broken").hidden = true;
    on.drawn(shown);
    drawTabs();
    root.dataset.browse = "ready";
    // The pages shown, as the address says the last of them.
    root.dataset.pages = String(paged.state.last);
  }

  /// A page that did not come: the first, said in place of the list, with
  /// Retry (Show more's own says so in its place, web/pager.js).
  function failed({ fresh, trouble }) {
    if (on.failed({ fresh, trouble }) || !fresh) return;
    for (const bones of grid.querySelectorAll(".skeleton")) bones.remove();
    $("loading").hidden = true;
    $("broken").hidden = false;
    root.dataset.browse = "broken";
    root.dataset[on.flag] = "broken";
  }

  // --- the controls ---------------------------------------------------------

  // A tab, or any link of the page to one of the lists' addresses (Find a
  // model to build, Every small build, a quiet tab's way on): switched to
  // here. A press with a key held, or the middle button's, opens it as the
  // browser does.
  document.addEventListener("click", (event) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const link = event.target.closest?.("a[href]");
    if (!link || link.target || link.hasAttribute("download") || !$("main").contains(link) || link.closest(".pager, .pager-earlier")) return;
    const url = new URL(link.href, location.href);
    if (url.origin !== location.origin || !listOf(url)) return;
    event.preventDefault();
    if (here(url) !== here(location.href)) go(url, { push: true });
  });
  // Back and Forward: the tab of the address come to, its pages and the
  // card left where they were. A move within the page (#main) is none.
  addEventListener("popstate", () => {
    if (on && here(location.href) === here(on.href(paged.state.last || 1))) return;
    go(new URL(location.href), { restore: true });
  });
  // Where the page is, kept with its address each time it stops scrolling,
  // so Forward too comes back to it (web/pager.js remember).
  let still = 0;
  addEventListener("scroll", () => {
    clearTimeout(still);
    still = setTimeout(() => paged?.remember(), 200);
  }, { passive: true });

  let typing = 0;
  q.addEventListener("input", () => {
    clearTimeout(typing);
    typing = setTimeout(ask, 200);
  });
  $("finder").addEventListener("submit", (event) => {
    event.preventDefault();
    clearTimeout(typing);
    ask();
  });
  $("clear").addEventListener("click", () => {
    q.value = "";
    on.clear();
    ask();
  });
  $("retry").addEventListener("click", () => {
    $("broken").hidden = true;
    $("loading").hidden = false;
    asking();
    paged.start(paged.state.last || 1, { restore: false });
  });

  // "/" puts the cursor in the search, as on most sites with one, the field
  // saying so until it is used.
  addEventListener("keydown", (event) => {
    if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey || event.defaultPrevented) return;
    const focused = document.activeElement;
    if (focused && (focused.isContentEditable || /^(INPUT|SELECT|TEXTAREA)$/.test(focused.tagName) || focused.closest("dialog[open]"))) return;
    event.preventDefault();
    q.focus();
    q.select();
  });
  // The bar of filters, which stays under the header as the list scrolls,
  // has the header's edge under it once it is stuck: once the tabs over it
  // have gone under the header.
  if ("IntersectionObserver" in window) {
    const head = Math.round(document.querySelector(".site-head")?.getBoundingClientRect().height || 61);
    new IntersectionObserver(([seen]) => {
      $("toolbar").toggleAttribute("data-stuck", !seen.isIntersecting && seen.boundingClientRect.top < head);
    }, { rootMargin: `-${head}px 0px 0px 0px` }).observe(document.querySelector(".gallery-bar"));
  }

  // Signed in or not, before the first question: a module of the site's,
  // asked for only when this browser keeps a sign-in. Then the tab the
  // address shows (and, Back, the pages before it that were shown, and the
  // card left where it was: web/pager.js).
  (async () => {
    try {
      const account = await import("/account.js");
      if (account.signedIn()) models.signIn(account);
    } catch {
      models.signIn(null);
    }
    go(new URL(location.href), { restore: true });
  })();
})();
