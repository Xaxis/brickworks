// The gallery, /gallery: the models people listed when they shared them,
// a page at a time from /api/share?op=list (api/share.js), searched,
// filtered and sorted as the controls say.
//
// The question lives in the address (?q=castle&kind=space&sort=views&...),
// put back with replaceState as it changes, so a search can be sent to
// somebody and a reload asks it again. A search waits for typing to stop;
// a filter asks at once; an answer that comes back after a newer question
// was asked is thrown away.
//
// Names, credits and tags were typed by strangers, so every one goes on
// the page as text (textContent), never as markup; a link is built from
// the model's id alone, and only an id that is one. Same origin
// throughout: the site's content security policy lets a page talk to
// itself and a short list of others.
(function () {
  "use strict";

  const ID = /^[A-Za-z0-9]{10}$/;
  const $ = (id) => document.getElementById(id);
  const grid = $("models");
  const more = $("more");
  const form = $("finder");
  const q = $("q");
  const kind = $("kind");
  const size = $("size");
  const sort = $("sort");
  const instructions = $("instructions");
  const technic = $("technic");
  let page = 0;
  let asking = 0;
  let tag = "";
  let filled = false;

  function counted(n, one, many) {
    const value = Number(n) || 0;
    return `${value.toLocaleString("en-US")} ${value === 1 ? one : many || `${one}s`}`;
  }

  function card(model) {
    const link = document.createElement("a");
    link.className = "model";
    link.href = `/m/${model.id}`;
    link.dataset.id = model.id;
    const frame = document.createElement("div");
    frame.className = "frame";
    // The small picture when there is one, a few KB, and the big one
    // when not: a page of cards is quick on a phone.
    const version = typeof model.thumb === "string" ? (model.thumb.split("?v=")[1] || "") : "";
    const picture = model.thumb ? `/m/${model.id}.webp${/^[a-z0-9]+$/.test(version) ? `?v=${version}` : ""}`
      : model.image ? `/m/${model.id}.png` : "";
    if (picture) {
      const img = document.createElement("img");
      img.src = picture;
      img.alt = String(model.name);
      img.width = 1200;
      img.height = 630;
      img.loading = "lazy";
      img.decoding = "async";
      frame.append(img);
    } else {
      frame.classList.add("none");
      frame.textContent = "No picture";
    }
    const words = document.createElement("div");
    words.className = "words";
    const name = document.createElement("b");
    name.textContent = String(model.name);
    name.title = String(model.name);
    const about = document.createElement("span");
    const parts = counted(model.parts, "part");
    about.textContent = model.author ? `${parts}, by ${model.author}` : parts;
    const numbers = document.createElement("small");
    const said = [counted(model.views, "view")];
    if (Number(model.likes)) said.push(counted(model.likes, "like"));
    if (Number(model.remixes)) said.push(counted(model.remixes, "remix", "remixes"));
    numbers.textContent = said.join(" · ");
    words.append(name, about, numbers);
    link.append(frame, words);
    return link;
  }

  /// What a select says: until the first answer fills it in, what the
  /// address asked of it.
  const chosen = (select) => (filled ? select.value : select.dataset.wanted || "");

  /// The question the controls ask, as the list's query string.
  function question() {
    const asked = new URLSearchParams();
    const words = q.value.trim().slice(0, 100);
    if (words) asked.set("q", words);
    if (chosen(kind)) asked.set("kind", chosen(kind));
    if (chosen(size)) asked.set("size", chosen(size));
    if (instructions.checked) asked.set("instructions", "1");
    if (technic.checked) asked.set("technic", "1");
    if (tag) asked.set("tag", tag);
    if (chosen(sort) && chosen(sort) !== "newest") asked.set("sort", chosen(sort));
    return asked;
  }

  function fill(select, options) {
    const keep = select.dataset.wanted || select.value || "";
    select.dataset.wanted = "";
    for (const option of options || []) {
      if ([...select.options].some((o) => o.value === option.id)) continue;
      const item = document.createElement("option");
      item.value = String(option.id);
      item.textContent = String(option.label);
      select.append(item);
    }
    if ([...select.options].some((o) => o.value === keep)) select.value = keep;
  }

  /// What the filters say, on the folded line, and the tag as a chip.
  function sayFilters() {
    const said = [];
    if (kind.value) said.push(kind.options[kind.selectedIndex].textContent);
    if (size.value) said.push(size.options[size.selectedIndex].textContent.split(",")[0]);
    if (instructions.checked) said.push("instructions");
    if (technic.checked) said.push("Technic");
    $("filters-said").textContent = said.join(", ");
    const chips = $("chips");
    chips.replaceChildren();
    if (tag) {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.textContent = `#${tag} ×`;
      chip.setAttribute("aria-label", `Stop filtering by the tag ${tag}`);
      chip.addEventListener("click", () => { tag = ""; ask(); });
      chips.append(chip);
    }
  }

  async function next(fresh) {
    const mine = ++asking;
    more.disabled = true;
    const asked = question();
    asked.set("page", String(fresh ? 1 : page + 1));
    try {
      const reply = await fetch(`/api/share?op=list&${asked}`, { headers: { accept: "application/json" } });
      // An address that asks what the list does not know (a kind that is
      // not one, say): the whole gallery instead, and the address put right.
      if (reply.status === 400 && !filled && [...question().keys()].length) {
        for (const select of [kind, size, sort]) select.dataset.wanted = "";
        q.value = "";
        instructions.checked = technic.checked = false;
        tag = "";
        history.replaceState(null, "", "/gallery");
        return next(true);
      }
      if (!reply.ok) throw new Error(String(reply.status));
      const data = await reply.json();
      if (mine !== asking) return;
      if (!filled) {
        fill(kind, data.kinds);
        fill(size, data.sizes);
        fill(sort, data.sorts);
        filled = true;
        sayFilters();
      }
      if (fresh) grid.replaceChildren();
      page = Number(data.page) || (fresh ? 1 : page + 1);
      for (const model of data.models || []) {
        if (model && ID.test(String(model.id))) grid.append(card(model));
      }
      const searching = [...question().keys()].some((key) => key !== "sort");
      $("loading").hidden = true;
      $("broken").hidden = true;
      $("empty").hidden = grid.children.length > 0 || searching;
      $("nothing").hidden = grid.children.length > 0 || !searching;
      $("found").textContent = grid.children.length
        ? `${counted(grid.children.length, "model")}${data.more ? ", more below" : ""}`
        : "";
      more.hidden = !data.more;
      document.documentElement.dataset.gallery = "ready";
    } catch {
      if (mine !== asking) return;
      $("loading").hidden = true;
      $("broken").hidden = false;
      document.documentElement.dataset.gallery = "broken";
    } finally {
      if (mine === asking) more.disabled = false;
    }
  }

  /// Ask again from the first page, with the address saying what was asked.
  function ask() {
    const asked = question();
    const query = asked.toString();
    history.replaceState(null, "", query ? `/gallery?${query}` : "/gallery");
    sayFilters();
    document.documentElement.dataset.gallery = "asking";
    next(true);
  }

  // The question the address asks, put in the controls before the first
  // answer: kind, size and sort are filled in when the list says what
  // they may be, so what is wanted waits on the select.
  const given = new URLSearchParams(location.search);
  q.value = (given.get("q") || "").slice(0, 100);
  for (const [select, name] of [[kind, "kind"], [size, "size"], [sort, "sort"]]) {
    select.dataset.wanted = given.get(name) || "";
  }
  instructions.checked = given.get("instructions") === "1";
  technic.checked = given.get("technic") === "1";
  tag = (given.get("tag") || "").slice(0, 24);
  // Open on a screen with room for them, folded on a phone.
  if (window.matchMedia && window.matchMedia("(min-width: 760px)").matches) $("filters").open = true;
  if (given.get("kind") || given.get("size") || instructions.checked || technic.checked) $("filters").open = true;

  let typing = 0;
  q.addEventListener("input", () => {
    clearTimeout(typing);
    typing = setTimeout(ask, 350);
  });
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    clearTimeout(typing);
    ask();
  });
  for (const control of [kind, size, sort, instructions, technic]) control.addEventListener("change", ask);
  $("clear").addEventListener("click", () => {
    q.value = "";
    kind.value = "";
    size.value = "";
    instructions.checked = false;
    technic.checked = false;
    tag = "";
    ask();
  });
  more.addEventListener("click", () => next(false));
  sayFilters();
  next(true);
})();
