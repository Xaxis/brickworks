// Your lists, at /lists (web/lists.html, lists1, docs/LISTS.md): the sets
// you own, the sets you want, the models you saved and lists of your own,
// one at a time beside all of them (a rail on a wide screen, a dropdown on
// a phone), the list in the address (?list=owned|want|saved|<id>), so a
// reload or a link opens it again.
//
// What a list holds is its cards (web/card.js), each with Own or Save and
// the lists on it (web/keep.js) as everywhere. Here a list is also made,
// edited (its name, words, cover and who sees it), shared, deleted (with
// Undo: it goes only once the toast has), downloaded as a CSV, put in its
// own order (drag a card, or its arrows), and its items selected a few at
// a time to copy, move or take out. Sets come in by number or from a file:
// for the sets you own, a Rebrickable or Brickset CSV or a BrickLink XML,
// read by My collection as the app's import is (api/collection.js); for a
// list, the set numbers in any such file.
//
// Every word a person typed (a list's name and description) goes on the
// page as text, never markup.
import { askToSignIn, call, signedIn, token } from "/account.js";
import { counted, iconHtml, langAt, modelCard, number, say, told } from "/card.js";
import { forget } from "/keep.js";
import { toast } from "/kit.js";
import { openShare, sheetFor } from "/share-sheet.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const BUILT_IN = ["owned", "want", "saved"];
// The most a list's own order is changed over: every item is read first,
// since an order names them all.
const MOST_ORDERED = 960;

// What the person has (op=lists), the list shown and what of it is drawn.
let mine = null;
let current = "owned";
let shown = null;
let items = [];
let selecting = false;
const selected = new Set();
// Lists deleted and not yet gone: their Undo still in the toast.
const going = new Map();

function make(tag, className, text) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  if (text !== undefined) made.textContent = text;
  return made;
}

/// Said in the page's line, and in the toast where it can be undone.
function tell(words, undo = null) {
  const said = $("said");
  said.textContent = "";
  setTimeout(() => { said.textContent = String(words); }, 40);
  if (undo) toast(words, { undo });
}

const trouble = (answer, otherwise) => (answer.status === 401 ? say("Sign in again: we email you a code, no password.")
  : answer.status === 429 ? say("That is a lot in a short time: try again in an hour.")
    : told(answer.body?.error, otherwise || say("That did not go through: try again in a moment.")));

// ---------------------------------------------------------------------------
// Which list.

function listAsked() {
  const asked = new URLSearchParams(location.search).get("list") || "owned";
  return BUILT_IN.includes(asked) || ID.test(asked) ? asked : "owned";
}

function hrefOf(id) {
  return `${langAt()}/lists${id === "owned" ? "" : `?list=${encodeURIComponent(id)}`}`;
}

/// The person's own list [id], as op=lists gave it.
const ownList = (id) => mine?.lists.find((list) => list.id === id) || null;
const wishlist = () => mine?.lists.find((list) => list.kind === "want") || null;

/// What a list is called where it is listed.
function nameOf(id) {
  if (id === "owned") return say("I own");
  if (id === "want") return say("I want");
  if (id === "saved") return say("Saved models");
  return ownList(id)?.name || "";
}

function countOf(id) {
  if (id === "owned") return mine.owned.sets;
  if (id === "want") return wishlist()?.count ?? 0;
  if (id === "saved") return mine.saved.models;
  return ownList(id)?.count ?? 0;
}

/// The rail of lists, and the dropdown a phone has in its place.
function drawRail() {
  const entry = (id, note = "") => {
    const li = make("li");
    const link = make("a", "", "");
    link.href = hrefOf(id);
    link.dataset.rail = id;
    if (id === current) link.setAttribute("aria-current", "page");
    link.append(make("span", "rail-name", nameOf(id)));
    if (note) link.append(make("small", "rail-note", note));
    const n = countOf(id);
    if (n) link.append(make("span", "n", number(n)));
    li.append(link);
    return li;
  };
  $("rail-built").replaceChildren(entry("owned"), entry("want"), entry("saved"));
  const own = mine.lists.filter((list) => list.kind !== "want" && !going.has(list.id));
  $("rail-mine").replaceChildren(...own.map((list) => entry(list.id, list.down ? say("taken down") : list.public ? say("public") : "")));
  $("rail-mine-h").hidden = !own.length;
  const pick = $("pick");
  pick.replaceChildren();
  const option = (id) => {
    const made = make("option", "", `${nameOf(id)}${countOf(id) ? ` (${number(countOf(id))})` : ""}`);
    made.value = id;
    made.selected = id === current;
    return made;
  };
  pick.append(option("owned"), option("want"), option("saved"));
  if (own.length) {
    const group = make("optgroup");
    group.label = say("Your own lists");
    group.append(...own.map((list) => option(list.id)));
    pick.append(group);
  }
}

function go(id, { push = true } = {}) {
  current = id;
  if (push) history.pushState({ list: id }, "", hrefOf(id));
  selecting = false;
  selected.clear();
  drawRail();
  loadList();
}

// ---------------------------------------------------------------------------
// The list shown.

async function loadMine() {
  const answer = await call("/api/people?op=lists");
  if (answer.status !== 200) return answer;
  mine = answer.body;
  return answer;
}

async function loadList({ keep = false } = {}) {
  const asked = current;
  const pages = keep && shown ? shown.page : 1;
  const view = $("items");
  if (!keep) {
    view.setAttribute("aria-busy", "true");
    view.replaceChildren();
    $("empty").hidden = true;
    $("more").hidden = true;
  }
  let got = null;
  const all = [];
  for (let page = 1; page <= pages; page++) {
    const answer = await call(`/api/people?op=list_items&id=${encodeURIComponent(asked)}&page=${page}`);
    if (asked !== current) return;
    if (answer.status !== 200) {
      view.removeAttribute("aria-busy");
      if (answer.status === 404) {
        tell(say("That list is not yours, or is gone: here are the sets you own."));
        go("owned", { push: false });
        history.replaceState({ list: "owned" }, "", hrefOf("owned"));
        return;
      }
      tell(trouble(answer));
      return;
    }
    got = answer.body;
    all.push(...got.items);
  }
  shown = got;
  items = all;
  view.removeAttribute("aria-busy");
  drawHead();
  drawItems();
  // For the checks: the list drawn whole (tools/web/site_pages.mjs).
  document.documentElement.dataset.lists = "ready";
}

async function loadMore() {
  const button = $("more");
  button.disabled = true;
  const answer = await call(`/api/people?op=list_items&id=${encodeURIComponent(current)}&page=${shown.page + 1}`);
  button.disabled = false;
  if (answer.status !== 200) {
    tell(trouble(answer));
    return;
  }
  shown = { ...answer.body };
  const before = items.length;
  items.push(...answer.body.items);
  drawItems();
  // The keyboard on the first card that came.
  $("items").children[before]?.querySelector("a.open")?.focus();
}

/// Every item of the list read, for an order that names them all: false
/// when it is longer than an order is made over.
async function readAll() {
  while (shown.more) {
    if (items.length >= MOST_ORDERED) return false;
    const answer = await call(`/api/people?op=list_items&id=${encodeURIComponent(current)}&page=${shown.page + 1}`);
    if (answer.status !== 200) return false;
    shown = { ...answer.body };
    items.push(...answer.body.items);
  }
  return true;
}

function drawHead() {
  const own = ID.test(current) ? ownList(current) : null;
  const want = current === "want" ? wishlist() : null;
  const list = own || want;
  const kind = current === "owned" ? say("Your sets") : current === "want" ? say("Your wishlist")
    : current === "saved" ? say("For you alone") : say("Your list");
  $("view-kind").textContent = kind;
  $("view-h").textContent = current === "want" ? (want?.name || say("I want")) : nameOf(current);
  const about = current === "owned"
    ? say("Every set you own, from here and from My collection in the app: their parts count as yours wherever Brickworks says what you can build.")
    : current === "want" ? (want?.description || say("The sets you want. Make it public, and its link tells whoever gives you a present what to give."))
      : current === "saved" ? say("The models you saved from the gallery: only you see them.")
        : own?.description || "";
  $("view-about").textContent = about;
  $("view-about").hidden = !about;
  const meta = [];
  if (current === "owned") {
    meta.push(counted(mine.owned.sets, "set"));
    if (mine.owned.pieces) meta.push(counted(mine.owned.pieces, "part"));
  } else if (shown) {
    if (shown.sets) meta.push(counted(shown.sets, "set"));
    if (shown.models || !shown.sets) meta.push(counted(shown.models, "model"));
  }
  if (list) meta.push(list.down ? say("Taken down by Brickworks after a report: only you see it") : list.public ? say("Public") : say("Only you"));
  $("view-meta").textContent = meta.join(" · ");
  $("share").hidden = !(list && list.public && !list.down);
  $("edit").hidden = !list;
  $("import").hidden = current === "saved";
  $("download").hidden = current === "saved";
  $("order").hidden = !own;
  for (const button of $("order").querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(button.dataset.sort === (own?.sort || "added")));
  }
  const showsOwned = current === "owned";
  $("shows-owned").hidden = !showsOwned;
  if (showsOwned) {
    $("shows-owned-box").checked = Boolean(mine.owned.shown);
    $("shows-owned-note").textContent = mine.owned.shown && mine.profile
      ? say("On your profile's Sets tab.") : mine.profile ? say("Off: only you see them.") : say("Make your profile first.");
  }
  $("select").setAttribute("aria-pressed", String(selecting));
  $("select").hidden = !items.length && !selecting;
  drawBulk();
}

function emptySaid() {
  if (current === "owned") {
    return [say("No sets yet. Tap Own on any set, or bring yours in from Rebrickable, BrickLink or Brickset with Add sets."),
      [`${langAt()}/library`, say("Browse the sets")]];
  }
  if (current === "want") return [say("Nothing wanted yet. Tap Want on a set’s page, or tick I want it in a set’s lists."), [`${langAt()}/library`, say("Browse the sets")]];
  if (current === "saved") return [say("No saved models yet. Tap Save on a model in the gallery."), [`${langAt()}/gallery`, say("See the gallery")]];
  return [say("Nothing in it yet. Add sets and models from their cards (the arrow beside Own or Save), or sets by number with Add sets."),
    [`${langAt()}/library`, say("Browse the sets")]];
}

function drawItems() {
  const view = $("items");
  const own = ID.test(current) ? ownList(current) : null;
  const ordering = Boolean(own && own.sort === "manual");
  view.classList.toggle("selecting", selecting);
  view.classList.toggle("ordering", ordering && !selecting);
  view.replaceChildren(...items.map((item, at) => cardOf(item, at, ordering)));
  $("more").hidden = !shown?.more;
  const empty = $("empty");
  empty.hidden = items.length > 0;
  if (!items.length) {
    const [words, [href, label]] = emptySaid();
    const link = make("a", "cta ghost", label);
    link.href = href;
    const actions = make("div", "actions");
    actions.append(link);
    empty.replaceChildren(make("p", "", words), actions);
  }
  $("select").hidden = !items.length && !selecting;
}

function cardOf(item, at, ordering) {
  const card = modelCard(item.card, { keep: true });
  card.dataset.key = item.key;
  const frame = card.querySelector(".frame");
  const name = String(item.card.name || "");
  if (selecting) {
    const pick = make("label", "pick");
    const box = make("input");
    box.type = "checkbox";
    box.checked = selected.has(item.key);
    box.setAttribute("aria-label", name ? say("Select {name}", { name }) : say("Select it"));
    box.addEventListener("change", () => {
      if (box.checked) selected.add(item.key);
      else selected.delete(item.key);
      card.classList.toggle("picked", box.checked);
      drawBulk();
    });
    pick.append(box);
    card.classList.toggle("picked", box.checked);
    card.append(pick);
  } else if (ordering) {
    card.draggable = true;
    const moves = make("div", "moves");
    const earlier = make("button", "icon-btn small");
    earlier.type = "button";
    earlier.innerHTML = iconHtml("back");
    earlier.setAttribute("aria-label", name ? say("Move {name} earlier", { name }) : say("Move it earlier"));
    earlier.disabled = at === 0;
    earlier.addEventListener("click", () => moveTo(item.key, at - 1, "earlier"));
    const later = make("button", "icon-btn small");
    later.type = "button";
    later.innerHTML = iconHtml("next");
    later.setAttribute("aria-label", name ? say("Move {name} later", { name }) : say("Move it later"));
    later.disabled = at === items.length - 1 && !shown?.more;
    later.addEventListener("click", () => moveTo(item.key, at + 1, "later"));
    moves.append(earlier, later);
    frame.append(moves);
  }
  return card;
}

// ---------------------------------------------------------------------------
// The order.

let ordered = null;

async function chooseSort(sort) {
  const own = ownList(current);
  if (!own || own.sort === sort) return;
  if (sort === "manual") {
    if (!(await readAll())) {
      tell(say("This list is too long to put in your own order here: it stays newest first."));
      return;
    }
    const answer = await call("/api/people?op=list_order", { method: "POST", body: { id: own.id, order: items.map((item) => item.key) } });
    if (answer.status !== 200) {
      tell(trouble(answer));
      return;
    }
    own.sort = "manual";
    tell(say("In your own order: drag a card, or use its arrows."));
  } else {
    const answer = await call("/api/people?op=list_order", { method: "POST", body: { id: own.id, sort: "added" } });
    if (answer.status !== 200) {
      tell(trouble(answer));
      return;
    }
    own.sort = "added";
    tell(say("Newest first."));
    await loadList();
    return;
  }
  drawHead();
  drawItems();
}

/// [key] to place [to] in the list, its order sent a moment later (a few
/// moves at once are one), and said.
async function moveTo(key, to, how = "") {
  if (!(await readAll())) {
    tell(say("This list is too long to put in your own order here: it stays newest first."));
    return;
  }
  const from = items.findIndex((item) => item.key === key);
  if (from < 0 || to < 0 || to >= items.length || from === to) return;
  const before = items.map((item) => item.key);
  const [item] = items.splice(from, 1);
  items.splice(to, 0, item);
  drawItems();
  // The keyboard stays on the arrow pressed, on the card where it went.
  const card = $("items").querySelector(`[data-key="${CSS.escape(key)}"]`);
  const button = card?.querySelector(how === "earlier" ? ".moves button:first-child" : ".moves button:last-child");
  (button && !button.disabled ? button : card?.querySelector(".moves button:not(:disabled)"))?.focus();
  const name = String(item.card.name || "");
  sendOrder(name ? say("{name} moved to {n} of {all}.", { name, n: number(to + 1), all: number(items.length) })
    : say("Moved to {n} of {all}.", { n: number(to + 1), all: number(items.length) }), before);
}

function sendOrder(words, before) {
  clearTimeout(ordered?.timer);
  const was = ordered?.before || before;
  ordered = { before: was, timer: setTimeout(async () => {
    const id = current;
    const order = items.map((item) => item.key);
    ordered = null;
    const answer = await call("/api/people?op=list_order", { method: "POST", body: { id, order } });
    if (answer.status !== 200) {
      tell(trouble(answer));
      await loadList();
      return;
    }
    tell(words, async () => {
      const back = await call("/api/people?op=list_order", { method: "POST", body: { id, order: was } });
      if (back.status !== 200) {
        tell(trouble(back));
        return;
      }
      if (current === id) await loadList();
      tell(say("Put back as it was."));
    });
  }, 500) };
}

// Dragged: a card dropped on another goes before it (after it when it came
// from before it, as a list drags).
let dragged = null;
function wireDrag() {
  const view = $("items");
  view.addEventListener("dragstart", (event) => {
    const card = event.target.closest?.(".model[data-key]");
    if (!card || !view.classList.contains("ordering")) return;
    dragged = card.dataset.key;
    card.classList.add("dragging");
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", dragged);
  });
  view.addEventListener("dragover", (event) => {
    if (!dragged) return;
    const card = event.target.closest?.(".model[data-key]");
    if (!card) return;
    event.preventDefault();
    for (const one of view.querySelectorAll(".drop-here")) if (one !== card) one.classList.remove("drop-here");
    card.classList.toggle("drop-here", card.dataset.key !== dragged);
  });
  view.addEventListener("drop", (event) => {
    const card = event.target.closest?.(".model[data-key]");
    if (!dragged || !card) return;
    event.preventDefault();
    const to = items.findIndex((item) => item.key === card.dataset.key);
    const key = dragged;
    dragged = null;
    moveTo(key, to);
  });
  view.addEventListener("dragend", () => {
    dragged = null;
    for (const one of view.querySelectorAll(".dragging, .drop-here")) one.classList.remove("dragging", "drop-here");
  });
}

// ---------------------------------------------------------------------------
// A few at once.

function drawBulk() {
  const bar = $("bulk");
  bar.hidden = !selecting;
  if (!selecting) return;
  const n = selected.size;
  $("bulk-n").textContent = n ? say("{n} selected", { n: number(n) }) : say("Select what to copy, move or take out");
  const to = $("bulk-to");
  const chosen = to.value;
  to.replaceChildren();
  const option = (id, words) => {
    const made = make("option", "", words);
    made.value = id;
    return made;
  };
  for (const id of ["owned", "want", "saved"]) if (id !== current) to.append(option(id, nameOf(id)));
  for (const list of mine.lists) if (list.kind !== "want" && list.id !== current && !going.has(list.id)) to.append(option(list.id, list.name));
  if ([...to.options].some((one) => one.value === chosen)) to.value = chosen;
  for (const id of ["bulk-copy", "bulk-move", "bulk-remove"]) $(id).disabled = n === 0;
  // Out of the sets you own is taking them out, not a move.
  $("bulk-move").hidden = current === "owned";
  $("bulk-all").textContent = n === items.length && items.length ? say("Select none") : say("Select all");
}

const setsOf = (keys) => keys.filter((key) => key.startsWith("set:"));
const modelsOf = (keys) => keys.filter((key) => key.startsWith("model:"));

/// The sets [keys] owned: once each that is not owned yet (from My
/// collection's count now, which keep.js asks), or [counts] (set -> how
/// many) where given. The sets it changed, with what each was.
async function ownSets(keys, counts = null) {
  const changed = [];
  // How many of each is owned now, 60 at a time (op=keeps asks no more).
  const now = new Map();
  for (let at = 0; at < keys.length; at += 60) {
    const asked = await call(`/api/people?op=keeps&sets=${encodeURIComponent(keys.slice(at, at + 60).map((key) => key.slice(4)).join(","))}`);
    if (asked.status !== 200) return { changed, trouble: trouble(asked) };
    for (const [set, had] of Object.entries(asked.body?.sets || {})) now.set(set, Number(had.own) || 0);
  }
  for (const key of keys) {
    const set = key.slice(4);
    const was = now.get(set) || 0;
    const qty = counts ? counts.get(key) ?? 0 : Math.max(1, was);
    if (qty === was) continue;
    const answer = await call("/api/collection", { method: "POST", body: { op: "own", set, was, qty,
      id: `lists-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}` } });
    if (answer.status !== 200) return { changed, trouble: trouble(answer) };
    changed.push([key, was]);
  }
  return { changed, trouble: "" };
}

/// [keys] into list [to] ("want", "saved" or an id), or out ([on] false),
/// 200 at a time.
async function keepAll(to, keys, on, from = null) {
  const wanted = to === "saved" ? modelsOf(keys) : keys;
  for (let at = 0; at < wanted.length; at += 200) {
    const answer = await call("/api/people?op=keep", { method: "POST",
      body: { list: to, items: wanted.slice(at, at + 200), on, ...(from ? { from } : {}) } });
    if (answer.status !== 200) return trouble(answer);
  }
  return "";
}

async function bulk(how) {
  const keys = [...selected];
  if (!keys.length) return;
  const to = $("bulk-to").value;
  const toName = nameOf(to);
  const buttons = ["bulk-copy", "bulk-move", "bulk-remove"].map($);
  for (const button of buttons) button.disabled = true;
  let said = "";
  let undo = null;
  const n = number(keys.length);
  if (how === "remove") {
    if (current === "owned") {
      const counts = new Map(items.filter((item) => keys.includes(item.key)).map((item) => [item.key, 0]));
      const { changed, trouble: why } = await ownSets(keys, counts);
      said = why || say("{n} taken out of the sets you own.", { n });
      if (changed.length) undo = async () => { await ownSets(changed.map(([key]) => key), new Map(changed)); await refresh(); tell(say("Put back.")); };
    } else {
      const from = current;
      const why = await keepAll(from, keys, false);
      said = why || say("{n} taken out of {list}.", { n, list: nameOf(from) });
      if (!why) undo = async () => { await keepAll(from, keys, true); await refresh(); tell(say("Put back.")); };
    }
  } else if (to === "owned") {
    const sets = setsOf(keys);
    const { changed, trouble: why } = await ownSets(sets);
    said = why || (sets.length ? say("{n} in the sets you own.", { n: number(sets.length) }) : say("Only sets are owned: no set was selected."));
    if (changed.length) undo = async () => { await ownSets(changed.map(([key]) => key), new Map(changed)); await refresh(); tell(say("Put back.")); };
    if (!why && how === "move" && sets.length) {
      const out = await keepAll(current, sets, false);
      if (out) said = out;
    }
  } else {
    const kept = to === "saved" ? modelsOf(keys) : keys;
    if (!kept.length) {
      said = say("Saved keeps models: no model was selected.");
    } else {
      // Moved: in the one, then out of the other (op=keep's from, where
      // both are lists; Saved is taken out of, or put in, apart).
      const from = how === "move" ? current : null;
      const apart = Boolean(from && (from === "saved" || to === "saved"));
      let why = await keepAll(to, kept, true, from && !apart ? from : null);
      if (!why && apart) why = await keepAll(from, kept, false);
      said = why || (how === "move" ? say("{n} moved to {list}.", { n: number(kept.length), list: toName })
        : say("{n} copied to {list}.", { n: number(kept.length), list: toName }));
      if (!why) {
        undo = async () => {
          await keepAll(to, kept, false);
          if (from) await keepAll(from, kept, true);
          await refresh();
          tell(say("Put back."));
        };
      }
    }
  }
  selected.clear();
  forget(keys);
  await refresh();
  tell(said, undo);
}

async function refresh() {
  await loadMine();
  drawRail();
  await loadList({ keep: true });
}

// ---------------------------------------------------------------------------
// Dialogs: a new list, a list's own settings, sets brought in.

function dialogOf(title, className = "") {
  const dialog = make("dialog", `lists-dialog ${className}`.trim());
  const h = make("h2", "", title);
  h.id = `lists-dialog-h-${Date.now().toString(36)}`;
  dialog.setAttribute("aria-labelledby", h.id);
  const form = make("form");
  const said = make("p", "said");
  said.setAttribute("role", "status");
  dialog.append(h, form);
  dialog.addEventListener("close", () => dialog.remove());
  document.body.append(dialog);
  return { dialog, form, said };
}

function field(labelText, input, note = "") {
  const label = make("label", "", labelText);
  if (note) label.append(make("small", "", note));
  label.append(input);
  return label;
}

function buttonsOf(primary, ...rest) {
  const actions = make("div", "actions");
  const send = make("button", "cta", primary);
  send.type = "submit";
  actions.append(send, ...rest);
  return { actions, send };
}

function cancelButton(dialog) {
  const button = make("button", "cta ghost", say("Cancel"));
  button.type = "button";
  button.addEventListener("click", () => dialog.close());
  return button;
}

function nameField(value = "") {
  const input = make("input");
  input.type = "text";
  input.name = "name";
  input.required = true;
  input.maxLength = 80;
  input.autocomplete = "off";
  input.value = value;
  return input;
}

function wordsField(value = "") {
  const area = make("textarea");
  area.name = "description";
  area.rows = 3;
  area.maxLength = 500;
  area.value = value || "";
  return area;
}

function publicChoice(on, words, disabled = false) {
  const label = make("label", "choice");
  const box = make("input");
  box.type = "checkbox";
  box.name = "public";
  box.checked = on;
  box.disabled = disabled;
  label.append(box, make("span", "", words));
  return { label, box };
}

function newList() {
  const { dialog, form, said } = dialogOf(say("New list"));
  const name = nameField();
  name.placeholder = say("Castles, To build, Gifts for Sam");
  const words = wordsField();
  const shownTo = publicChoice(false, say("Public: on your profile and in the gallery’s lists, for anyone with its link"));
  const { actions, send } = buttonsOf(say("Make it"), cancelButton(dialog));
  form.append(field(say("Name"), name), field(say("What it is"), words, say("Optional")), shownTo.label, said, actions);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    send.disabled = true;
    const answer = await call("/api/people?op=collection", { method: "POST",
      body: { name: name.value.trim(), description: words.value.trim() || null, public: shownTo.box.checked } });
    send.disabled = false;
    if (answer.status !== 200) {
      said.textContent = trouble(answer, say("That list was not made: try again in a moment."));
      return;
    }
    dialog.close();
    await loadMine();
    go(answer.body.id);
    tell(say("Made {list}. Add to it from any set’s or model’s card: the arrow beside Own or Save.", { list: answer.body.name }));
  });
  dialog.showModal();
  name.focus();
}

function editList() {
  const list = current === "want" ? wishlist() : ownList(current);
  if (!list) return;
  const { dialog, form, said } = dialogOf(list.kind === "want" ? say("Your wishlist") : say("Edit list"));
  const name = nameField(list.name);
  const words = wordsField(list.description);
  const shownTo = publicChoice(list.public, list.kind === "want"
    ? say("Public: anyone with its link sees what you want, and it is on your profile")
    : say("Public: on your profile and in the gallery’s lists, for anyone with its link"), list.down);
  const rows = [field(say("Name"), name), field(say("What it is"), words, say("Optional")), shownTo.label];
  if (list.down) rows.push(make("p", "note", say("Brickworks took its name or description down after a report, so it stays private: it is still yours, with everything in it.")));
  // Its cover: what it leads with, one of what is in it.
  const cover = make("select");
  cover.name = "cover";
  const first = make("option", "", say("Its first four"));
  first.value = "";
  cover.append(first);
  for (const item of items.slice(0, 96)) {
    const option = make("option", "", String(item.card.name || item.key));
    option.value = item.key;
    option.selected = item.key === list.cover;
    cover.append(option);
  }
  if (items.length) rows.push(field(say("Cover"), cover));
  const remove = make("button", "cta ghost danger", say("Delete list"));
  remove.type = "button";
  if (list.kind === "want") remove.hidden = true;
  const { actions, send } = buttonsOf(say("Save"), cancelButton(dialog), remove);
  form.append(...rows, said, actions);
  remove.addEventListener("click", () => {
    dialog.close();
    deleteList(list);
  });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    send.disabled = true;
    const body = { id: list.id, name: name.value.trim(), description: words.value.trim() || null };
    if (!list.down) body.public = shownTo.box.checked;
    if (items.length && cover.value !== (list.cover || "")) body.cover = cover.value || null;
    const answer = await call("/api/people?op=collection", { method: "POST", body });
    send.disabled = false;
    if (answer.status !== 200) {
      said.textContent = trouble(answer, say("That was not saved: try again in a moment."));
      return;
    }
    dialog.close();
    await refresh();
    tell(answer.body.public ? say("Saved: it is public.") : say("Saved: only you see it."));
  });
  dialog.showModal();
  name.focus();
}

/// [list] deleted once its toast is gone: until then Undo keeps it.
function deleteList(list) {
  const timer = setTimeout(() => dropNow(list.id), 9000);
  going.set(list.id, timer);
  tell(say("Deleted {list}.", { list: list.name }), () => {
    clearTimeout(going.get(list.id));
    going.delete(list.id);
    drawRail();
    go(list.id);
    tell(say("{list} is back.", { list: list.name }));
  });
  go("owned");
}

async function dropNow(id, { keepalive = false } = {}) {
  if (!going.has(id)) return;
  going.delete(id);
  const answer = await call(`/api/people?op=uncollection&id=${encodeURIComponent(id)}`, { method: "POST", body: {}, keepalive });
  if (keepalive) return;
  if (answer.status !== 200) {
    tell(trouble(answer));
    return;
  }
  await loadMine();
  drawRail();
}

/// The set numbers in [text]: typed ("10497, 6080-1") or a file's
/// (Rebrickable's Set Number, Brickset's Number and Variant, BrickLink's
/// <ITEMID> of type S), each once.
function setNumbersIn(text) {
  const found = [];
  const source = String(text || "");
  if (/<INVENTORY>/i.test(source)) {
    for (const item of source.matchAll(/<ITEM>([\s\S]*?)<\/ITEM>/gi)) {
      if (!/<ITEMTYPE>\s*S\s*<\/ITEMTYPE>/i.test(item[1])) continue;
      const id = /<ITEMID>\s*([^<\s]+)\s*<\/ITEMID>/i.exec(item[1]);
      if (id) found.push(id[1]);
    }
  } else {
    const lines = source.split(/\r?\n/);
    const head = (lines[0] || "").toLowerCase().split(",").map((one) => one.replace(/^"|"$/g, "").trim());
    const at = head.findIndex((one) => ["set number", "set_num", "number", "set"].includes(one));
    const variant = head.indexOf("variant");
    if (at >= 0 && head.length > 1) {
      for (const line of lines.slice(1)) {
        const cells = line.split(",").map((one) => one.replace(/^"|"$/g, "").trim());
        if (!cells[at]) continue;
        found.push(variant >= 0 && cells[variant] && !/-\d+$/.test(cells[at]) ? `${cells[at]}-${cells[variant]}` : cells[at]);
      }
    } else {
      found.push(...source.split(/[\s,;]+/).filter((one) => /^[0-9a-z][0-9a-z._-]*$/i.test(one)));
    }
  }
  return [...new Set(found.map((one) => (/-\d{1,3}$/.test(one) ? one : `${one}-1`).toLowerCase()))].slice(0, 2000);
}

/// What a file is, from its first line: BrickLink's XML, Brickset's CSV
/// (Number with QtyOwned, Own or Want) or Rebrickable's.
function kindOf(text) {
  if (/^\s*(<\?xml|<INVENTORY)/i.test(text)) return "bricklink_xml";
  const head = (text.split(/\r?\n/)[0] || "").toLowerCase();
  if (/(^|,)"?number"?(,|$)/.test(head) && /qtyowned|(^|,)"?own"?(,|$)|(^|,)"?want"?(,|$)|setid/.test(head)) return "brickset_csv";
  return "rebrickable_csv";
}

function importSets() {
  const owned = current === "owned";
  const { dialog, form, said } = dialogOf(owned ? say("Add sets you own") : say("Add sets to {list}", { list: nameOf(current) }));
  const intro = make("p", "", owned
    ? say("From a file Rebrickable, BrickLink or Brickset made of your sets, or typed by number. Their parts count as yours, as in My collection.")
    : say("Typed by number, or from a file of sets: Rebrickable’s, BrickLink’s or Brickset’s."));
  const typed = make("textarea");
  typed.rows = 3;
  typed.placeholder = say("10497, 6080, 75192-1");
  const file = make("input");
  file.type = "file";
  file.accept = ".csv,.xml,text/csv,text/xml,application/xml";
  const rows = [intro, field(say("Set numbers"), typed, say("Commas or spaces between them")), field(say("Or a file"), file)];
  let replace = null;
  if (owned) {
    const choice = make("label", "choice");
    replace = make("input");
    replace.type = "checkbox";
    choice.append(replace, make("span", "", say("It replaces what that site's file brought in before (else it is added)")));
    rows.push(choice);
  }
  const { actions, send } = buttonsOf(say("Add them"), cancelButton(dialog));
  form.append(...rows, said, actions);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const text = file.files?.[0] ? await file.files[0].text() : "";
    if (!text && !typed.value.trim()) {
      said.textContent = say("Type a set number or choose a file.");
      return;
    }
    send.disabled = true;
    said.textContent = say("Adding…");
    let words = "";
    if (owned) {
      const body = text ? { from: kindOf(text), text, mode: replace?.checked ? "replace" : "add" }
        : { from: "sets", text: typed.value, mode: "add" };
      const answer = await call("/api/collection", { method: "POST", body });
      if (answer.status !== 200) {
        send.disabled = false;
        said.textContent = trouble(answer, say("Nothing was added: try again in a moment."));
        return;
      }
      const got = answer.body.imported || {};
      words = got.lots ? say("Added {sets} and {lots} of loose parts.", { sets: counted(got.sets, "set"), lots: counted(got.lots, "lot") })
        : say("Added {sets}.", { sets: counted(got.sets || 0, "set") });
      // Brickset marks the sets wanted too: those go on the wishlist.
      const wanted = Array.isArray(answer.body.wanted) ? answer.body.wanted : [];
      if (wanted.length) {
        const why = await keepAll("want", wanted.map((set) => `set:${set}`), true);
        words += ` ${why || say("And {sets} on your wishlist.", { sets: counted(wanted.length, "set") })}`;
      }
    } else {
      const sets = setNumbersIn(text || typed.value);
      if (!sets.length) {
        send.disabled = false;
        said.textContent = say("No set number in that.");
        return;
      }
      const why = await keepAll(current, sets.map((set) => `set:${set}`), true);
      if (why) {
        send.disabled = false;
        said.textContent = why;
        return;
      }
      words = say("Added {sets} to {list}.", { sets: counted(sets.length, "set"), list: nameOf(current) });
    }
    dialog.close();
    forget();
    await refresh();
    tell(words);
  });
  dialog.showModal();
  typed.focus();
}

async function download() {
  const button = $("download");
  button.disabled = true;
  const reply = await fetchCsv(current);
  button.disabled = false;
  if (!reply.ok) {
    tell(reply.words);
    return;
  }
  const link = make("a");
  link.href = URL.createObjectURL(reply.blob);
  link.download = reply.name;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(link.href), 4000);
  tell(say("Downloaded {file}.", { file: reply.name }));
}

async function fetchCsv(id) {
  const access = await token();
  const reply = await fetch(`/api/people?op=list_csv&id=${encodeURIComponent(id)}`, { headers: access ? { authorization: `Bearer ${access}` } : {} });
  if (!reply.ok) {
    let body = null;
    try {
      body = await reply.json();
    } catch {
      body = null;
    }
    return { ok: false, words: trouble({ status: reply.status, body }) };
  }
  const named = /filename="([^"]+)"/.exec(reply.headers.get("content-disposition") || "");
  return { ok: true, blob: await reply.blob(), name: named ? named[1] : "brickworks-list.csv" };
}

function share() {
  const list = current === "want" ? wishlist() : ownList(current);
  if (!list || !list.public) return;
  const url = `${location.origin}${langAt()}/c/${list.id}`;
  const sheet = sheetFor({ url, name: list.name,
    text: list.kind === "want" ? say("{name}: a wishlist on Brickworks", { name: list.name }) : say("{name} on Brickworks", { name: list.name }),
    about: list.kind === "want" ? say("Its link opens this wishlist: the sets they want, to give or to know.")
      : say("Its link opens this list: what is in it, and who made it.") });
  openShare(sheet);
}

async function showOwned(box) {
  box.disabled = true;
  const answer = await call("/api/people?op=owned_choice", { method: "POST", body: { shows: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    tell(trouble(answer));
    return;
  }
  mine.owned.shown = answer.body.shows;
  drawHead();
  tell(answer.body.shows ? say("The sets you own are on your profile's Sets tab.") : say("The sets you own are off your profile."));
}

// ---------------------------------------------------------------------------

function wire() {
  $("rail").addEventListener("click", (event) => {
    const link = event.target.closest("a[data-rail]");
    if (!link || event.metaKey || event.ctrlKey || event.shiftKey || event.button) return;
    event.preventDefault();
    go(link.dataset.rail);
    $("view-h").setAttribute("tabindex", "-1");
    $("view-h").focus();
  });
  $("pick").addEventListener("change", () => go($("pick").value));
  $("new-list").addEventListener("click", newList);
  $("new-list-pick").addEventListener("click", newList);
  $("edit").addEventListener("click", editList);
  $("share").addEventListener("click", share);
  $("import").addEventListener("click", importSets);
  $("download").addEventListener("click", download);
  $("more").addEventListener("click", loadMore);
  $("shows-owned-box").addEventListener("change", (event) => showOwned(event.target));
  $("order").addEventListener("click", (event) => {
    const button = event.target.closest("button[data-sort]");
    if (button) chooseSort(button.dataset.sort);
  });
  $("select").addEventListener("click", () => {
    selecting = !selecting;
    selected.clear();
    drawHead();
    drawItems();
    if (selecting) $("items").querySelector(".pick input")?.focus();
  });
  $("bulk-all").addEventListener("click", () => {
    if (selected.size === items.length) selected.clear();
    else for (const item of items) selected.add(item.key);
    drawItems();
    drawBulk();
  });
  $("bulk-copy").addEventListener("click", () => bulk("copy"));
  $("bulk-move").addEventListener("click", () => bulk("move"));
  $("bulk-remove").addEventListener("click", () => bulk("remove"));
  wireDrag();
  addEventListener("popstate", () => go(listAsked(), { push: false }));
  // A list deleted with its Undo still up goes as the page is left.
  addEventListener("pagehide", () => { for (const id of [...going.keys()]) dropNow(id, { keepalive: true }); });
}

async function start() {
  $("loading").hidden = false;
  if (!signedIn()) {
    $("loading").hidden = true;
    $("signed-out").hidden = false;
    document.documentElement.dataset.lists = "signed-out";
    $("sign-in").addEventListener("click", async () => {
      if (await askToSignIn("Sign in to keep your lists: we email you a code, no password.")) location.reload();
    }, { once: true });
    return;
  }
  const answer = await loadMine();
  $("loading").hidden = true;
  if (answer.status !== 200) {
    $("signed-out").hidden = answer.status !== 401;
    document.documentElement.dataset.lists = answer.status === 401 ? "signed-out" : "failed";
    if (answer.status === 401) {
      $("sign-in").addEventListener("click", async () => {
        if (await askToSignIn("Sign in again to see your lists: we email you a code, no password.")) location.reload();
      }, { once: true });
    } else {
      const said = make("p", "state", trouble(answer));
      $("loading").after(said);
    }
    return;
  }
  $("signed-in").hidden = false;
  current = listAsked();
  if (ID.test(current) && !ownList(current)) current = "owned";
  wire();
  drawRail();
  await loadList();
}

start();
