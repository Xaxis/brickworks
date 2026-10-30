// The LDraw library, /library (library333): every model of a real set the
// app's Library opens, a page of 24 at a time from /api/share?op=library
// (api/_library.js), searched, filtered and ordered as the controls say,
// as the gallery is (web/gallery.js), and as the app's Library searches
// (ModelLibrary.search): every word in a set's name, number, theme or who
// modelled it.
//
// The question lives in the address (?q=castle&theme=Town&sort=oldest),
// put back with replaceState as it changes, so a search can be sent to
// somebody and a reload asks it again. The list is paged as every list of
// the site is (web/pager.js): Show more, the last page shown in the
// address (&page=3), Show earlier over a page opened by its address, the
// count and the numbered links (up to the last of 1,200 pages), and Back
// putting the same pages and the card left where they were. A search
// waits for typing to stop; a filter asks at once; an answer that comes
// back after a newer question was asked is thrown away.
//
// Every name goes on the page as text (web/card.js escapes what it draws),
// and a link is made from a set's id alone, and only an id that is one.
//
// Every set in the catalogue (sets364, api/_sets.js): the list says so by
// its years and its themes' own themes, and the Filters menu then has four
// more, each a <select> like its own: the theme inside the one chosen
// (#sub), a year in the decade (#year), only those with a 3D model
// (#model) and minifigures (#figs). Each is taken from the page where it
// has one by that id, and made at the end of the menu where not.
import { FIRST_SCREEN, counted, modelCard, skeletonHtml } from "/card.js";
// Filters closing on a click elsewhere, as a "more" menu does.
import "/kit.js";
// "/" to search, and the bar of filters kept under the header, as the gallery's.
import { browseBar } from "/browse.js";
// The site's one way to page a list.
import { pageAsked, pager } from "/pager.js";

(function () {
  "use strict";

  const ID = /^[a-z]{2,8}-[A-Za-z0-9._-]{1,120}$/;
  const $ = (id) => document.getElementById(id);
  const grid = $("models");
  const q = $("q");
  const sort = $("sort");
  // The order a list is in unless asked (api/_sets.js FIRST_SORT): sets built in 3D first.
  const FIRST_SORT = "built";
  const size = $("size");
  const decade = $("decade");
  let filled = false;
  // The list's pages (web/pager.js), made once the functions it calls are.
  let paged = null;
  let theme = "";
  // Every set there is, once the first answer says.
  let every = 0;
  // The catalogue's own filters, once the list says it has them: name -> select.
  const extra = {};
  // The themes inside each top theme, as the list says them.
  let inner = new Map();
  // What the address asked of them, until they are made.
  const wanted = {};
  const MORE = [["sub", "Inside the theme", "Any"], ["year", "Year", "Any year in the decade"],
    ["model", "3D model", "With or without"], ["figs", "Minifigures", "With or without"]];
  const pick = (name) => (extra[name] ? (filled ? extra[name].value : extra[name].dataset.wanted || "") : wanted[name] || "");

  /// What a select says: until the first answer fills it in, what the
  /// address asked of it.
  const chosen = (select) => (filled ? select.value : select.dataset.wanted || "");

  /// The question the controls ask, as a query string; for the address,
  /// the order left out when it is the default, and page [page].
  function question({ address = false, page = paged ? paged.state.last : 1 } = {}) {
    const asked = new URLSearchParams();
    const words = q.value.trim().slice(0, 100);
    if (words) asked.set("q", words);
    if (theme) asked.set("theme", pick("sub") ? `${theme} > ${pick("sub")}` : theme);
    if (chosen(decade)) asked.set("decade", chosen(decade));
    // A year only in the decade chosen: another decade chosen since leaves it.
    const decadeOf = (year) => `${String(year).slice(0, 3)}0s`;
    for (const name of ["year", "model", "figs"]) {
      if (pick(name) && !(name === "year" && decadeOf(pick(name)) !== chosen(decade))) asked.set(name, pick(name));
    }
    if (chosen(size)) asked.set("size", chosen(size));
    const order = chosen(sort) || FIRST_SORT;
    if (!address || order !== FIRST_SORT) asked.set("sort", order);
    if (address && page > 1) asked.set("page", String(page));
    return asked;
  }

  function addressOf(page) {
    const query = question({ address: true, page }).toString();
    return query ? `/library?${query}` : "/library";
  }

  function fill(select, options) {
    const keep = select.dataset.wanted || select.value || "";
    select.dataset.wanted = "";
    for (const [value, label] of options) {
      if ([...select.options].some((o) => o.value === value)) continue;
      const item = document.createElement("option");
      item.value = String(value);
      item.textContent = String(label);
      select.append(item);
    }
    if ([...select.options].some((o) => o.value === keep)) select.value = keep;
  }

  /// One of the catalogue's filters: the page's own select by that id, or
  /// one made at the end of the Filters menu as its others are.
  function moreFilter([name, label, any]) {
    let select = $(name);
    if (!select) {
      const menu = $("filters").querySelector(".menu-list");
      const holder = document.createElement("label");
      holder.append(`${label} `);
      select = document.createElement("select");
      select.id = name;
      select.name = name;
      select.setAttribute("form", "finder");
      holder.append(select);
      menu.insertBefore(holder, menu.querySelector(".actions"));
    }
    if (!select.options.length) {
      const first = document.createElement("option");
      first.value = "";
      first.textContent = any;
      select.append(first);
    }
    select.dataset.wanted = wanted[name] || "";
    select.addEventListener("change", ask);
    extra[name] = select;
  }

  /// The theme inside the one chosen, and the years of the decade chosen:
  /// what each may hold follows the other filters.
  function fillMore(years) {
    if (extra.sub) {
      const keep = extra.sub.dataset.wanted || extra.sub.value;
      extra.sub.dataset.wanted = "";
      extra.sub.replaceChildren(extra.sub.options[0]);
      for (const one of inner.get(theme) || []) extra.sub.append(new Option(`${one.name} (${one.n})`, one.name));
      extra.sub.value = [...extra.sub.options].some((o) => o.value === keep) ? keep : "";
      extra.sub.disabled = extra.sub.options.length < 2;
    }
    if (extra.year) {
      const keep = extra.year.dataset.wanted || extra.year.value;
      extra.year.dataset.wanted = "";
      const from = Number(String(chosen(decade)).slice(0, 4));
      extra.year.replaceChildren(extra.year.options[0]);
      for (const year of years.filter((one) => from && one >= from && one < from + 10)) extra.year.append(new Option(String(year), String(year)));
      extra.year.value = [...extra.year.options].some((o) => o.value === keep) ? keep : "";
      extra.year.disabled = extra.year.options.length < 2;
    }
  }
  let years = [];

  /// The themes as pills, once the list says what they are, each with how
  /// many sets it has on hover.
  function fillThemes(themes) {
    const row = $("themes");
    for (const one of themes || []) {
      const name = String(one.name);
      if (row.querySelector(`[data-pick="${CSS.escape(name)}"]`)) continue;
      const pill = document.createElement("button");
      pill.type = "button";
      pill.className = "pill";
      pill.dataset.pick = name;
      pill.textContent = name;
      pill.title = counted(Number(one.n) || 0, "set");
      pill.setAttribute("aria-pressed", "false");
      row.append(pill);
    }
  }

  function drawThemes() {
    for (const pill of document.querySelectorAll("#themes [data-pick]")) {
      pill.setAttribute("aria-pressed", String(pill.dataset.pick === theme));
    }
  }

  /// How many filters are on, on the Filters button.
  function sayFilters() {
    const on = [chosen(size), chosen(decade), chosen(sort) && chosen(sort) !== FIRST_SORT, ...MORE.map(([name]) => pick(name))]
      .filter(Boolean).length;
    const n = $("filters-said");
    n.textContent = on ? String(on) : "";
    n.hidden = !on;
    $("filters").querySelector("summary").setAttribute("aria-label", on ? `Filters, ${on} on` : "Filters");
  }

  const searching = () => Boolean(q.value.trim() || theme || chosen(size) || chosen(decade) || MORE.some(([name]) => pick(name)));

  const tests = new URLSearchParams(location.search).get("tests") === "1";

  /// Page [n] of the list as cards.
  async function load(n) {
    const asked = question();
    asked.set("page", String(n));
    // The OMR's arrivals staged for the lead to let out, which only a list
    // asked with tests shows (api/share.js), as the gallery asks its own.
    if (tests) asked.set("tests", "1");
    const reply = await fetch(`/api/share?op=library&${asked}`, { headers: { accept: "application/json" } });
    if (reply.status !== 200) throw new Error(String(reply.status));
    const data = await reply.json();
    // A page past the end is answered with the last: none, so the pager
    // opens the first and puts the address right.
    if (Number.isFinite(data.page) && data.page !== n) return { items: [], pages: Number(data.pages) || 1, data };
    // As many pictures asked for at once as the first screen shows, when
    // this page is the first drawn.
    const eager = document.documentElement.dataset.library !== "ready"
      ? [...grid.children].filter((one) => one.getBoundingClientRect().top < innerHeight).length || FIRST_SCREEN : 0;
    const items = (data.models || []).filter((model) => ID.test(String(model && model.id)))
      .map((model, i) => modelCard(model, { eager: i < eager }));
    return { items, pages: Number(data.pages) || 1, total: Number(data.total) || 0, data };
  }

  /// What the page says once a page of the list is drawn.
  function drawn({ answer, fresh }) {
    const data = answer.data || {};
    if (!filled) {
      // The catalogue's (api/_sets.js): its own filters, made once.
      if (Array.isArray(data.years)) {
        years = data.years.map(Number);
        inner = new Map((data.themes || []).map((one) => [String(one.name), Array.isArray(one.sub) ? one.sub : []]));
        for (const one of MORE) moreFilter(one);
        fill(extra.model, [["3d", "Only with a 3D model"]]);
        fill(extra.figs, [["with", "With minifigures"], ["none", "Without"]]);
      }
      fillThemes(data.themes);
      fill(sort, Object.entries(data.sorts || {}));
      fill(size, Object.entries(data.sizes || {}));
      fill(decade, (data.decades || []).map((one) => [one, one]));
      filled = true;
    }
    every = Number(data.of) || every;
    fillMore(years);
    if (fresh) {
      const total = Number(data.total) || 0;
      $("found-said").textContent = !total ? "" : searching()
        ? `${counted(total, "set")} of ${every.toLocaleString("en-US")}` : counted(total, "set");
    }
    $("loading").hidden = true;
    $("broken").hidden = true;
    $("nothing").hidden = grid.children.length > 0;
    drawThemes();
    sayFilters();
    document.documentElement.dataset.library = "ready";
    document.documentElement.dataset.pages = String(paged.state.last);
  }

  /// The first page that did not come: said in place of the list, with Retry.
  function failed({ fresh }) {
    if (!fresh) return;
    for (const bones of grid.querySelectorAll(".skeleton")) bones.remove();
    $("loading").hidden = true;
    $("broken").hidden = false;
    document.documentElement.dataset.library = "broken";
  }

  /// Ask again from the first page.
  function ask() {
    history.replaceState(null, "", addressOf(1));
    sayFilters();
    drawThemes();
    document.documentElement.dataset.library = "asking";
    return paged.restart(1);
  }

  paged = pager({ list: grid, load, href: addressOf, noun: ["set", "sets"], drawn, failed,
    skeleton: () => {
      const made = document.createElement("template");
      made.innerHTML = skeletonHtml();
      return made.content.firstElementChild;
    } });

  $("themes").addEventListener("click", (event) => {
    const pill = event.target.closest("[data-pick]");
    if (!pill) return;
    theme = pill.dataset.pick;
    if (extra.sub) extra.sub.value = "";
    ask();
  });

  // The question the address asks, put in the controls before the first
  // answer: what the selects may hold is filled in when the list says.
  const given = new URLSearchParams(location.search);
  q.value = (given.get("q") || "").slice(0, 100);
  for (const [select, name] of [[sort, "sort"], [size, "size"], [decade, "decade"]]) {
    select.dataset.wanted = given.get(name) || "";
  }
  // A theme inside a theme is asked as its path: "Star Wars > Ultimate Collector Series".
  [theme, wanted.sub = ""] = (given.get("theme") || "").slice(0, 300).split(" > ").map((one) => one.trim());
  for (const name of ["year", "model", "figs"]) wanted[name] = given.get(name) || "";

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
  for (const control of [sort, size, decade]) control.addEventListener("change", ask);
  $("filters-clear").addEventListener("click", () => {
    size.value = decade.value = "";
    for (const select of Object.values(extra)) select.value = "";
    sort.value = FIRST_SORT;
    ask();
  });
  $("clear").addEventListener("click", () => {
    q.value = "";
    size.value = decade.value = "";
    for (const select of Object.values(extra)) select.value = "";
    theme = "";
    ask();
  });
  browseBar({ search: q, above: document.querySelector(".library-bar"), bar: $("toolbar") });
  $("retry").addEventListener("click", () => {
    $("broken").hidden = true;
    $("loading").hidden = false;
    document.documentElement.dataset.library = "asking";
    paged.start(paged.state.last || 1, { restore: false });
  });
  sayFilters();

  // The page the address shows (and, Back, the pages before it that were
  // shown, and the card left where it was: web/pager.js).
  paged.start(pageAsked(location.search));
})();
