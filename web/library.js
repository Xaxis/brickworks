// The LDraw library, /library (library333): every model of a real set the
// app's Library opens, a page of 24 at a time from /api/share?op=library
// (api/_library.js), searched, filtered and ordered as the controls say,
// as the gallery is (web/gallery.js), and as the app's Library searches
// (ModelLibrary.search): every word in a set's name, number, theme or who
// modelled it.
//
// The question lives in the address (?q=castle&theme=Town&sort=oldest),
// put back with replaceState as it changes, so a search can be sent to
// somebody and a reload asks it again; and so does how many pages are
// shown (&page=3). The next page comes as the end of the list nears the
// screen, three times, then only by Show more, which gives the footer
// back. A card opened is kept in the history's state, so Back from its
// page asks the same pages again and puts that card where it was. A search
// waits for typing to stop; a filter asks at once; an answer that comes
// back after a newer question was asked is thrown away.
//
// Every name goes on the page as text (web/card.js escapes what it draws),
// and a link is made from a set's id alone, and only an id that is one.
import { FIRST_SCREEN, counted, modelCard } from "/card.js";
// Filters closing on a click elsewhere, as a "more" menu does.
import "/kit.js";
// "/" to search, and the bar of filters kept under the header, as the gallery's.
import { browseBar } from "/browse.js";

(function () {
  "use strict";

  const ID = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
  const $ = (id) => document.getElementById(id);
  const grid = $("models");
  const more = $("more");
  const q = $("q");
  const sort = $("sort");
  const size = $("size");
  const decade = $("decade");
  const AUTO = 3;
  let page = 0;
  let auto = 0;
  let pages = 1;
  let asking = 0;
  let loading = false;
  let filled = false;
  let theme = "";
  // Every set there is, once the first answer says.
  let every = 0;

  /// What a select says: until the first answer fills it in, what the
  /// address asked of it.
  const chosen = (select) => (filled ? select.value : select.dataset.wanted || "");

  /// The question the controls ask, as a query string; for the address,
  /// the order left out when it is the default, and how many pages.
  function question({ address = false } = {}) {
    const asked = new URLSearchParams();
    const words = q.value.trim().slice(0, 100);
    if (words) asked.set("q", words);
    if (theme) asked.set("theme", theme);
    if (chosen(decade)) asked.set("decade", chosen(decade));
    if (chosen(size)) asked.set("size", chosen(size));
    const order = chosen(sort) || "newest";
    if (!address || order !== "newest") asked.set("sort", order);
    if (address && page > 1) asked.set("page", String(page));
    return asked;
  }

  function addressOf() {
    const query = question({ address: true }).toString();
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
    const on = [chosen(size), chosen(decade), chosen(sort) && chosen(sort) !== "newest"].filter(Boolean).length;
    const n = $("filters-said");
    n.textContent = on ? String(on) : "";
    n.hidden = !on;
    $("filters").querySelector("summary").setAttribute("aria-label", on ? `Filters, ${on} on` : "Filters");
  }

  const searching = () => Boolean(q.value.trim() || theme || chosen(size) || chosen(decade));

  // Show more's press while a page that came by itself waits to be drawn,
  // or is still on its way (pressed): it is drawn as soon as it is here
  // (gallery.js).
  let release = null;
  let pressed = false;

  /// Resolves once the end of the list is under the screen, so a page put
  /// there moves only what is out of sight, or once Show more is pressed
  /// (gallery.js outOfSight).
  function outOfSight() {
    const under = () => grid.getBoundingClientRect().bottom > innerHeight;
    if (pressed || under()) return Promise.resolve();
    return new Promise((done) => {
      const look = () => { if (under()) release(); };
      release = () => {
        removeEventListener("scroll", look);
        release = null;
        done();
      };
      addEventListener("scroll", look, { passive: true });
    });
  }

  /// The next page of the list ([fresh]: the first, in place of what is
  /// shown); [byItself] (not asked for by a press) drawn once out of sight.
  async function next(fresh, byItself = false) {
    const mine = ++asking;
    if (release) release();
    loading = true;
    pressed = false;
    more.disabled = !byItself;
    const asked = question();
    asked.set("page", String(fresh ? 1 : page + 1));
    try {
      const reply = await fetch(`/api/share?op=library&${asked}`, { headers: { accept: "application/json" } });
      if (reply.status !== 200) throw new Error(String(reply.status));
      const data = await reply.json();
      if (mine !== asking) return;
      if (byItself) {
        await outOfSight();
        if (mine !== asking) return;
      }
      if (!filled) {
        fillThemes(data.themes);
        fill(sort, Object.entries(data.sorts || {}));
        fill(size, Object.entries(data.sizes || {}));
        fill(decade, (data.decades || []).map((one) => [one, one]));
        filled = true;
      }
      every = Number(data.of) || every;
      // As many pictures asked for at once as the first screen shows.
      const eager = fresh ? [...grid.children].filter((one) => one.getBoundingClientRect().top < innerHeight).length
        || FIRST_SCREEN : 0;
      if (fresh) grid.replaceChildren();
      page = Number(data.page) || (fresh ? 1 : page + 1);
      pages = Number(data.pages) || 1;
      for (const model of data.models || []) {
        const id = String(model && model.id);
        if (!ID.test(id) || grid.querySelector(`.model[data-id="${id}"]`)) continue;
        grid.append(modelCard(model, { eager: grid.children.length < eager }));
      }
      const total = Number(data.total) || 0;
      $("found-said").textContent = !total ? "" : searching()
        ? `${counted(total, "set")} of ${every.toLocaleString("en-US")}` : counted(total, "set");
      $("loading").hidden = true;
      $("broken").hidden = true;
      $("nothing").hidden = grid.children.length > 0;
      more.hidden = page >= pages;
      drawThemes();
      sayFilters();
      history.replaceState(history.state, "", addressOf());
      document.documentElement.dataset.library = "ready";
      document.documentElement.dataset.pages = String(page);
    } catch {
      if (mine !== asking) return;
      for (const bones of grid.querySelectorAll(".skeleton")) bones.remove();
      $("loading").hidden = true;
      $("broken").hidden = false;
      document.documentElement.dataset.library = "broken";
    } finally {
      if (mine === asking) {
        loading = false;
        more.disabled = false;
      }
    }
  }

  /// Ask again from the first page.
  function ask() {
    page = 0;
    auto = 0;
    history.replaceState(null, "", addressOf());
    sayFilters();
    drawThemes();
    document.documentElement.dataset.library = "asking";
    return next(true);
  }

  /// The next page by itself as the end of the list comes within a screen
  /// of the window, the first three times; then Show more.
  function nearEnd() {
    if (loading || page >= pages || more.hidden || auto >= AUTO) return;
    if (more.getBoundingClientRect().top > innerHeight * 2) return;
    auto += 1;
    next(false, true).then(nearEnd);
  }

  // A card opened: kept, so Back puts it where it was.
  grid.addEventListener("click", (event) => {
    const opened = event.target.closest("a[href]")?.closest(".model");
    if (opened && ID.test(String(opened.dataset.id))) {
      history.replaceState({ card: opened.dataset.id, top: Math.round(opened.getBoundingClientRect().top) }, "", addressOf());
    }
  });
  $("themes").addEventListener("click", (event) => {
    const pill = event.target.closest("[data-pick]");
    if (!pill) return;
    theme = pill.dataset.pick;
    ask();
  });

  // The question the address asks, put in the controls before the first
  // answer: what the selects may hold is filled in when the list says.
  const given = new URLSearchParams(location.search);
  q.value = (given.get("q") || "").slice(0, 100);
  for (const [select, name] of [[sort, "sort"], [size, "size"], [decade, "decade"]]) {
    select.dataset.wanted = given.get(name) || "";
  }
  theme = (given.get("theme") || "").slice(0, 200);
  const shown = Math.min(Math.max(Number.parseInt(given.get("page") || "1", 10) || 1, 1), 20);
  const back = history.state && ID.test(String(history.state.card)) ? history.state : null;
  if ("scrollRestoration" in history) history.scrollRestoration = "manual";

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
    sort.value = "newest";
    ask();
  });
  $("clear").addEventListener("click", () => {
    q.value = "";
    size.value = decade.value = "";
    theme = "";
    ask();
  });
  more.addEventListener("click", () => {
    if (release) release();
    else if (loading) pressed = true;
    else next(false);
  });
  browseBar({ search: q, above: document.querySelector(".library-bar"), bar: $("toolbar"), row: $("themes") });
  addEventListener("scroll", nearEnd, { passive: true });
  addEventListener("resize", nearEnd, { passive: true });
  sayFilters();

  // The pages the address shows, then the card Back came to, where it was.
  (async () => {
    await next(true);
    while (page < shown && page < pages) await next(false);
    auto = Math.min(AUTO, page - 1);
    if (back) {
      const card = document.querySelector(`#models .model[data-id="${back.card}"]`);
      if (card) scrollTo({ top: Math.max(0, scrollY + card.getBoundingClientRect().top - (Number(back.top) || 0)), behavior: "instant" });
      document.documentElement.dataset.back = card ? back.card : "lost";
    }
    nearEnd();
  })();
})();
