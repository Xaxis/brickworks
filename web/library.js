// The gallery's Sets: every real set (library333, sets364), its tab at
// /library (web/gallery.html, which switches between its lists,
// web/gallery.js), a page of 24 at a time from /api/share?op=library
// (api/_library.js, api/_sets.js), searched, filtered and ordered as the
// controls say, and as the app's Library searches (ModelLibrary.search):
// every word in a set's name, number, theme or who modelled it.
//
// The question lives in the address (/library?q=castle&theme=Town&sort=oldest),
// so a search can be sent to somebody and a reload asks it again; gallery.js
// puts it there and pages the list (web/pager.js), up to the last of 1,200
// pages.
//
// Words typed are read as api/_search.js reads them, misspelt or run
// together, and the list is then in best match order ("Best match" in the
// Order filter) unless the person chose another order; the line over the
// list says what a misspelling was taken to mean, or that no set has every
// word and these are the nearest (search, 2026-10-30).
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
import { counted, langAt, modelCard, number, say, themeSaid } from "/card.js";

const ID = /^[a-z]{2,8}-[A-Za-z0-9._-]{1,120}$/;
const $ = (id) => document.getElementById(id);

/// The sets' list, as gallery.js [page] switches to it: {q, grid, tests,
/// ask(), state(), eager()}.
export function setsList(page) {
  const { q, grid, tests } = page;
  const sort = $("set-sort");
  // The order a list is in unless asked (api/_sets.js FIRST_SORT): sets built
  // in 3D first; and with words typed, best match (MATCH_SORT).
  const FIRST_SORT = "built";
  const MATCH_SORT = "match";
  // The order the person chose, "" for the default.
  let ownSort = "";
  const typed = () => Boolean(q.value.trim());
  const defaultSort = () => (typed() ? MATCH_SORT : FIRST_SORT);
  /// The order asked: the person's own, but best match only with words typed.
  const order = () => (ownSort && !(ownSort === MATCH_SORT && !typed()) ? ownSort : defaultSort());
  const size = $("set-size");
  const decade = $("decade");
  let filled = false;
  let theme = "";
  // Every set there is, once the first answer says.
  let every = 0;
  // The catalogue's own filters, once the list says it has them: name -> select.
  const extra = {};
  // The themes inside each top theme, as the list says them.
  let inner = new Map();
  // What the address asked of them, until they are made.
  const wanted = {};
  const MORE = [["sub", say("Inside the theme"), say("Any")], ["year", say("Year"), say("Any year in the decade")],
    ["model", say("3D model"), say("With or without")], ["figs", say("Minifigures"), say("With or without")]];
  // What one says: what the address asked of it until the list has filled
  // it in (fillMore, fill), then its value.
  const pick = (name) => (extra[name] ? extra[name].dataset.wanted || extra[name].value : wanted[name] || "");

  /// What a select says: until the first answer fills it in, what the
  /// address asked of it.
  const chosen = (select) => (filled ? select.value : select.dataset.wanted || "");

  /// The question the controls ask, as a query string; for the address,
  /// the order left out when it is the default, and page [n].
  function question({ address = false, n = page.state()?.last || 1 } = {}) {
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
    if (!address || order() !== defaultSort()) asked.set("sort", order());
    if (address && n > 1) asked.set("page", String(n));
    // The OMR's arrivals staged for the lead to let out, which only a list
    // asked with tests shows (api/share.js), as the gallery asks its own.
    if (tests) asked.set("tests", "1");
    return asked;
  }

  /// Page [n]'s address: /de/library in German.
  function addressOf(n) {
    const query = question({ address: true, n }).toString();
    return `${langAt()}/library${query ? `?${query}` : ""}`;
  }

  function fill(select, options) {
    const keep = select.dataset.wanted || select.value || "";
    select.dataset.wanted = "";
    for (const [value, label] of options) {
      if ([...select.options].some((o) => o.value === value)) continue;
      const item = document.createElement("option");
      item.value = String(value);
      item.textContent = say(String(label));
      select.append(item);
    }
    if ([...select.options].some((o) => o.value === keep)) select.value = keep;
  }

  /// One of the catalogue's filters: the page's own select by that id, or
  /// one made at the end of the Filters menu as its others are.
  function moreFilter([name, label, any]) {
    let select = $(name);
    if (!select) {
      const menu = $("set-filters").querySelector(".menu-list");
      const holder = document.createElement("label");
      holder.append(`${label} `);
      select = document.createElement("select");
      select.id = name;
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
    select.addEventListener("change", () => {
      select.dataset.wanted = "";
      page.ask();
    });
    extra[name] = select;
  }

  /// The theme inside the one chosen, and the years of the decade chosen:
  /// what each may hold follows the other filters.
  function fillMore(years) {
    if (extra.sub) {
      const keep = extra.sub.dataset.wanted || extra.sub.value;
      extra.sub.dataset.wanted = "";
      extra.sub.replaceChildren(extra.sub.options[0]);
      for (const one of inner.get(theme) || []) extra.sub.append(new Option(`${themeSaid(one.name)} (${number(one.n)})`, one.name));
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
      pill.textContent = themeSaid(name);
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

  /// The Order filter as the list is ordered: Best match while words are
  /// typed, and not to be chosen with none.
  function showSort() {
    const best = [...sort.options].find((one) => one.value === MATCH_SORT);
    if (best) best.disabled = !typed();
    // Until the list says what orders there are, fill takes it from here.
    sort.dataset.wanted = filled ? "" : order();
    if ([...sort.options].some((one) => one.value === order())) sort.value = order();
  }

  /// How many filters are on, on the Filters button.
  function sayFilters() {
    const on = [chosen(size), chosen(decade), order() !== defaultSort(), ...MORE.map(([name]) => pick(name))]
      .filter(Boolean).length;
    const n = $("set-filters-said");
    n.textContent = on ? String(on) : "";
    n.hidden = !on;
    $("set-filters").querySelector("summary").setAttribute("aria-label", on ? say("Filters, {n} on", { n: on }) : say("Filters"));
  }

  const searching = () => Boolean(q.value.trim() || theme || chosen(size) || chosen(decade) || MORE.some(([name]) => pick(name)));

  /// Page [n] of the list as cards.
  async function load(n) {
    const asked = question();
    asked.set("page", String(n));
    const reply = await fetch(`/api/share?op=library&${asked}`, { headers: { accept: "application/json" } });
    if (reply.status !== 200) throw new Error(String(reply.status));
    const data = await reply.json();
    // A page past the end is answered with the last: none, so the pager
    // opens the first and puts the address right.
    if (Number.isFinite(data.page) && data.page !== n) return { items: [], pages: Number(data.pages) || 1, data };
    const eager = page.eager();
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
        fill(extra.model, [["3d", say("Only with a 3D model")]]);
        fill(extra.figs, [["with", say("With minifigures")], ["none", say("Without")]]);
      }
      fillThemes(data.themes);
      fill(sort, Object.entries(data.sorts || {}));
      showSort();
      fill(size, Object.entries(data.sizes || {}));
      fill(decade, (data.decades || []).map((one) => [one, one]));
      filled = true;
    }
    every = Number(data.of) || every;
    fillMore(years);
    if (fresh) {
      const total = Number(data.total) || 0;
      const many = !total ? "" : searching()
        ? say("{sets} of {every}", { sets: counted(total, "set"), every: number(every) }) : counted(total, "set");
      // What a misspelling was taken to mean, or that these are the nearest.
      const meant = typeof data.meant === "string" ? data.meant.slice(0, 100) : "";
      if (total && data.near === true) {
        $("found-said").replaceChildren(say("No set has every word you typed. The nearest: {sets}", { sets: many }));
      } else if (total && meant) {
        const words = document.createElement("strong");
        words.textContent = meant;
        $("found-said").replaceChildren(say("Showing sets for "), words, ` · ${many}`);
      } else {
        $("found-said").textContent = many;
      }
    }
    $("nothing").hidden = grid.children.length > 0;
    drawThemes();
    sayFilters();
    document.documentElement.dataset.library = "ready";
  }

  $("themes").addEventListener("click", (event) => {
    const pill = event.target.closest("[data-pick]");
    if (!pill) return;
    theme = pill.dataset.pick;
    if (extra.sub) extra.sub.value = "";
    page.ask();
  });
  q.addEventListener("input", () => {
    if (page.on() === "sets") showSort();
  });
  for (const control of [size, decade]) control.addEventListener("change", () => page.ask());
  sort.addEventListener("change", () => {
    ownSort = sort.value === defaultSort() ? "" : sort.value;
    page.ask();
  });
  $("set-filters-clear").addEventListener("click", () => {
    size.value = decade.value = "";
    for (const select of Object.values(extra)) select.value = "";
    ownSort = "";
    showSort();
    page.ask();
  });

  return {
    flag: "library",
    page: "library",
    noun: ["set", "sets"],
    tabs: ["sets"],
    tab: () => "sets",
    title: () => say("Sets · Every LEGO® set and its parts, in Brickworks"),
    search: () => ({ label: say("Search every set"), placeholder: say("Search sets by name, number or theme") }),
    /// The address's question, put in the controls before the answer:
    /// what the selects may hold is filled in when the list says.
    enter(given) {
      ownSort = given.get("sort") || "";
      for (const [select, name] of [[size, "size"], [decade, "decade"]]) {
        if (filled) select.value = given.get(name) || "";
        else select.dataset.wanted = given.get(name) || "";
      }
      // A theme inside a theme is asked as its path: "Star Wars > Ultimate Collector Series".
      [theme, wanted.sub = ""] = (given.get("theme") || "").slice(0, 300).split(" > ").map((one) => one.trim());
      for (const name of ["year", "model", "figs"]) wanted[name] = given.get(name) || "";
      // The theme inside and the year are filled in for the theme and the
      // decade asked once the list answers (fillMore): wanted till then.
      for (const [name, select] of Object.entries(extra)) {
        select.value = wanted[name] || "";
        if (name === "sub" || name === "year") select.dataset.wanted = wanted[name] || "";
      }
      showSort();
      drawThemes();
      sayFilters();
    },
    leave() {},
    href: addressOf,
    hrefOf: () => addressOf(1),
    asking() {
      showSort();
      sayFilters();
      drawThemes();
    },
    load,
    drawn,
    failed: () => false,
    searching,
    clear() {
      size.value = decade.value = "";
      for (const select of Object.values(extra)) select.value = "";
      theme = "";
      ownSort = "";
      showSort();
    },
  };
}
