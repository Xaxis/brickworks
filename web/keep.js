// Own, want, save and your lists, one tap from anywhere a set or a model is
// shown (lists1, 2026-11-13, docs/LISTS.md): every [data-keep] on the page,
// a card's split button (web/card.js keepHtml) or a set page's bar
// (api/_sets.js), whatever draws it and whenever (a page of cards drawn
// later is seen as it arrives).
//
//   [data-keep-main]  Own a set (one copy; again: none) or Save a model,
//                     pressed while it is so, with how many once more
//                     than one; at once, and a toast that can undo it
//   [data-keep-want]  want a set (the wishlist), the set page's
//   [data-keep-more]  the lists: a panel of boxes, I own (and how many),
//                     I want, Saved, each list of yours, and a new one
//                     made there; each box saved as it is ticked
//
// Every page draws them the same for everybody (a CDN keeps the pages), so
// what the person has is asked here, a page's worth at once
// (api/_mylists.js op=keeps), and pressed. Signed out, a tap asks them to
// sign in (web/account.js askToSignIn) and then does what they tapped for.
//
// I own is My collection (api/collection.js op "own", held to the count
// the person saw: what another device changed is said, never undone);
// I want, Saved and the lists are api/_mylists.js op=keep. A name a person
// typed goes on the page as text, never markup.
import { askToSignIn, call, signedIn } from "/account.js";
import { told } from "/card.js";
import { iconHtml, say, toast } from "/kit.js";

// What the person has of each item asked: "set:10497-1" -> {own, sure,
// wanted, saved, lists: Set of list ids}. own is what is shown, sure what
// the server last said (a tap still on its way is the difference).
const known = new Map();
// Their lists, as the last answer had them, their wishlist's id apart.
let lists = [];
let wishlist = null;
// What a taking out took, "key list" -> {at, position}: put back into that
// list again, it goes back where it was (op=keep's back), so an Undo or a
// box ticked again leaves the list as it was (review of lists1).
const away = new Map();
// How many of a set the panel's I own it took down from, set -> count: ticked
// again, it goes back to that count, and the server puts back those very
// copies, their source and their marks (api/collection.js op own).
const ownedBefore = new Map();
// Items seen on the page and not yet asked, and the asks on their way.
const waiting = new Set();
const asking = new Map();
// One change at a time for each item, in the order tapped.
const chains = new Map();

const KEY = /^(set:[a-z0-9][a-z0-9._]{0,24}-[0-9]{1,3}|model:[A-Za-z0-9]{10})$/;
const isSet = (key) => key.startsWith("set:");
const blank = () => ({ own: 0, sure: 0, wanted: false, saved: false, lists: new Set() });

// ---------------------------------------------------------------------------
// What the person has.

/// Every item on the page not asked yet, asked in one go a moment later.
function see(root = document) {
  const holders = [...(root.matches?.("[data-keep]") ? [root] : []), ...root.querySelectorAll("[data-keep]")];
  for (const holder of holders) {
    const key = holder.dataset.keep || "";
    if (!KEY.test(key)) continue;
    if (known.has(key)) paint(holder);
    else waiting.add(key);
  }
  if (waiting.size && signedIn()) {
    clearTimeout(see.timer);
    see.timer = setTimeout(() => ask([...waiting]), 40);
  }
}

/// [keys] asked of the server, 60 sets and 60 models at a time.
async function ask(keys) {
  for (const key of keys) waiting.delete(key);
  if (!keys.length) return;
  const sets = keys.filter(isSet).map((key) => key.slice(4));
  const models = keys.filter((key) => !isSet(key)).map((key) => key.slice(6));
  const asks = [];
  for (let at = 0; at < Math.max(sets.length, models.length, 1); at += 60) {
    asks.push(askSome(sets.slice(at, at + 60), models.slice(at, at + 60)));
  }
  await Promise.all(asks);
}

function askSome(sets, models) {
  const keys = [...sets.map((set) => `set:${set}`), ...models.map((id) => `model:${id}`)];
  const asked = (async () => {
    const answer = await call(`/api/people?op=keeps&sets=${encodeURIComponent(sets.join(","))}`
      + `&models=${encodeURIComponent(models.join(","))}`);
    if (answer.status !== 200 || !answer.body) return false;
    learnLists(answer.body.lists, answer.body.want);
    for (const [set, had] of Object.entries(answer.body.sets || {})) {
      const one = known.get(`set:${set}`) || blank();
      if (!chains.has(`set:${set}`)) one.own = Number(had.own) || 0;
      one.sure = Number(had.own) || 0;
      one.lists = new Set((had.lists || []).filter((id) => id !== wishlist));
      one.wanted = Boolean(wishlist && (had.lists || []).includes(wishlist));
      known.set(`set:${set}`, one);
    }
    for (const [id, had] of Object.entries(answer.body.models || {})) {
      const one = known.get(`model:${id}`) || blank();
      one.saved = Boolean(had.saved);
      one.lists = new Set((had.lists || []).filter((list) => list !== wishlist));
      one.wanted = Boolean(wishlist && (had.lists || []).includes(wishlist));
      known.set(`model:${id}`, one);
    }
    for (const key of keys) paintAll(key);
    return true;
  })();
  for (const key of keys) asking.set(key, asked);
  asked.finally(() => { for (const key of keys) if (asking.get(key) === asked) asking.delete(key); });
  return asked;
}

function learnLists(given, want) {
  if (!Array.isArray(given)) return;
  wishlist = typeof want === "string" ? want : null;
  lists = given.filter((list) => list && list.kind !== "want");
}

/// What the person has of [key], asked now if it is not known.
async function knownOf(key) {
  if (!known.has(key)) {
    await (asking.get(key) || askSome(isSet(key) ? [key.slice(4)] : [], isSet(key) ? [] : [key.slice(6)]));
  }
  return known.get(key) || null;
}

/// Signed in, or asked to: true once they are, with what they have of
/// every item on the page asked again for the account they signed in with.
async function signIn(why) {
  if (signedIn()) return true;
  if (!(await askToSignIn(why))) return false;
  known.clear();
  for (const holder of document.querySelectorAll("[data-keep]")) if (KEY.test(holder.dataset.keep)) waiting.add(holder.dataset.keep);
  await ask([...waiting]);
  return true;
}

// ---------------------------------------------------------------------------
// Drawing what is so.

function paintAll(key) {
  for (const holder of document.querySelectorAll(`[data-keep="${CSS.escape(key)}"]`)) paint(holder);
  if (open && open.key === key) open.draw();
}

function paint(holder) {
  const key = holder.dataset.keep;
  const one = known.get(key);
  if (!one) return;
  const set = isSet(key);
  // Each button's words stay as they are (its name, a toggle's): pressed
  // says it is so, and its icon and edge show it.
  const main = holder.querySelector("[data-keep-main]");
  if (main) {
    const on = set ? one.own > 0 : one.saved;
    main.setAttribute("aria-pressed", String(on));
    const n = main.querySelector(".n");
    if (n) {
      n.hidden = !(set && one.own > 1);
      n.textContent = set && one.own > 1 ? `×${one.own}` : "";
    }
  }
  const want = holder.querySelector("[data-keep-want]");
  if (want) want.setAttribute("aria-pressed", String(one.wanted));
  const more = holder.querySelector("[data-keep-more]");
  if (more) {
    // In a list (on a card, or wanted): a dot on the lists' button, and
    // its description says in how many.
    const count = one.lists.size + (want ? 0 : one.wanted ? 1 : 0);
    more.toggleAttribute("data-in", count > 0);
    if (count) more.setAttribute("aria-description", count === 1 ? say("In 1 list") : say("In {n} lists", { n: count }));
    else more.removeAttribute("aria-description");
  }
}

// ---------------------------------------------------------------------------
// Changes: shown at once, sent in order, put back when refused.

/// [work] after every change of [key] before it.
function inTurn(key, work) {
  const before = chains.get(key) || Promise.resolve();
  const next = before.then(work, work);
  chains.set(key, next);
  next.finally(() => { if (chains.get(key) === next) chains.delete(key); });
  return next;
}

/// What a refusal says, in the person's words where it has some.
function trouble(answer, fallback) {
  if (answer.status === 401) return say("Sign in again to keep it: we email you a code, no password.");
  if (answer.status === 429) return say("That is a lot in a short time: try again in an hour.");
  return told(answer.body?.error, fallback || say("That did not go through: try again in a moment."));
}

let requests = 0;
const requestId = () => `own-${Date.now().toString(36)}-${(requests++).toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

/// [key] (a set) owned [qty] times: shown now, then sent from the count the
/// server last said. Resolves true once it is so.
function own(key, qty) {
  const one = known.get(key) || blank();
  known.set(key, one);
  one.own = qty;
  paintAll(key);
  return inTurn(key, async () => {
    if (one.sure === qty) {
      one.own = one.sure;
      return true;
    }
    const answer = await call("/api/collection", { method: "POST",
      body: { op: "own", set: key.slice(4), was: one.sure, qty, id: requestId() } });
    if (answer.status === 200) {
      one.sure = Number(answer.body?.done?.owned ?? qty);
      // A later tap still on its way keeps what it shows.
      if (one.own === qty) one.own = one.sure;
      paintAll(key);
      return true;
    }
    if (answer.status === 409 && Number.isInteger(answer.body?.owned)) {
      one.sure = answer.body.owned;
      one.own = one.sure;
      paintAll(key);
      tell(one.sure ? say("That changed on another device: you own {n} now.", { n: one.sure })
        : say("That changed on another device: you own none now."));
      return false;
    }
    one.own = one.sure;
    paintAll(key);
    tell(trouble(answer));
    return false;
  });
}

/// [key] in [list] (an id of theirs, "want" or "saved") or out: shown now,
/// then sent. Resolves true once it is so.
function keepIn(key, list, on) {
  const one = known.get(key) || blank();
  known.set(key, one);
  const was = { wanted: one.wanted, saved: one.saved, lists: new Set(one.lists) };
  if (list === "want") one.wanted = on;
  else if (list === "saved") one.saved = on;
  else if (on) one.lists.add(list);
  else one.lists.delete(list);
  paintAll(key);
  const where = `${key} ${list}`;
  return inTurn(key, async () => {
    const back = on ? away.get(where) : null;
    const answer = await call("/api/people?op=keep", { method: "POST",
      body: { list, items: [key], on, ...(back ? { back: { [key]: back } } : {}) } });
    if (answer.status === 200) {
      const took = answer.body?.taken?.[key];
      if (!on && took) away.set(where, took);
      if (on) away.delete(where);
      const said = answer.body?.list;
      if (list === "want" && said && typeof said.id === "string") wishlist = said.id;
      if (said && typeof said === "object" && said.kind !== "want") {
        const at = lists.findIndex((row) => row.id === said.id);
        if (at >= 0) lists[at] = { ...lists[at], ...said };
      }
      return true;
    }
    Object.assign(one, { wanted: was.wanted, saved: was.saved, lists: was.lists });
    paintAll(key);
    tell(trouble(answer));
    return false;
  });
}

/// Said where the person is looking: in the open panel's line, else the
/// toast (a toast is behind a modal panel, docs/DESIGN_SYSTEM.md).
function tell(words, undo = null) {
  if (open) open.tell(words);
  else toast(words, undo ? undoing(undo) : {});
}

/// A toast's Undo (web/toast.js's action), which runs [run].
const undoing = (run) => ({ action: { label: say("Undo"), run } });

/// The item's name, as its holder says it, for what is said of it.
const nameOf = (holder) => String(holder.dataset.name || "").trim();

// ---------------------------------------------------------------------------
// The taps.

/// The press asks for what the button did not show ([button] pressed or
/// not), shown at once on every one of [key]'s buttons of its kind, even
/// before what the person has is known: the answer then decides.
function asked(key, button, kind) {
  const on = button?.getAttribute("aria-pressed") !== "true";
  if (!known.has(key)) shownAs(key, kind, on);
  return on;
}

/// Every one of [key]'s buttons of [kind] shown pressed or not, before
/// anything is known to paint from (a sign-in let go puts it back).
function shownAs(key, kind, on) {
  for (const holder of document.querySelectorAll(`[data-keep="${CSS.escape(key)}"]`)) {
    holder.querySelector(kind)?.setAttribute("aria-pressed", String(on));
  }
}

async function pressMain(holder) {
  const key = holder.dataset.keep;
  const set = isSet(key);
  const on = asked(key, holder.querySelector("[data-keep-main]"), "[data-keep-main]");
  if (!signedIn()) {
    const yes = await signIn(set ? "Sign in to keep the sets you own: we email you a code, no password."
      : "Sign in to save it: we email you a code, no password.");
    if (!yes) {
      shownAs(key, "[data-keep-main]", !on);
      paintAll(key);
      return;
    }
  }
  const one = (await knownOf(key)) || blank();
  // So already (on another device, or before they signed in): said, and
  // left so.
  if ((set ? one.own > 0 : one.saved) === on) {
    paintAll(key);
    if (on) toast(set ? say("You own it already: it is in your sets.") : say("It is saved already."));
    return;
  }
  const name = nameOf(holder);
  if (set) {
    const was = one.own;
    const qty = on ? 1 : 0;
    const done = await own(key, qty);
    if (!done) return;
    toast(qty ? (name ? say("{name} is in the sets you own.", { name }) : say("It is in the sets you own."))
      : (name ? say("{name} is out of the sets you own.", { name }) : say("It is out of the sets you own.")),
    undoing(() => own(key, was)));
  } else {
    const done = await keepIn(key, "saved", on);
    if (!done) return;
    toast(on ? say("Saved: it is on your profile's Saved, for you alone.") : say("No longer saved."),
      undoing(() => keepIn(key, "saved", !on)));
  }
}

async function pressWant(holder) {
  const key = holder.dataset.keep;
  const on = asked(key, holder.querySelector("[data-keep-want]"), "[data-keep-want]");
  if (!signedIn() && !(await signIn("Sign in to keep a wishlist: we email you a code, no password."))) {
    shownAs(key, "[data-keep-want]", !on);
    paintAll(key);
    return;
  }
  const one = (await knownOf(key)) || blank();
  if (one.wanted === on) {
    paintAll(key);
    if (on) toast(say("It is on your wishlist already."));
    return;
  }
  const done = await keepIn(key, "want", on);
  if (!done) return;
  toast(on ? say("On your wishlist.") : say("Off your wishlist."), undoing(() => keepIn(key, "want", !on)));
}

// ---------------------------------------------------------------------------
// The panel of lists: a dialog over the page, beside the button on a wide
// screen and a sheet from the foot on a phone.

let open = null;

async function pressMore(holder, button) {
  const key = holder.dataset.keep;
  if (!signedIn() && !(await signIn("Sign in to keep it in your lists: we email you a code, no password."))) return;
  await knownOf(key);
  panel(holder, button);
}

function make(tag, className, text) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  if (text !== undefined) made.textContent = text;
  return made;
}

function panel(holder, button) {
  open?.close();
  const key = holder.dataset.keep;
  const set = isSet(key);
  const name = nameOf(holder);
  const dialog = make("dialog", "keep-panel");
  const title = make("h2", "", name || (set ? say("This set") : say("This model")));
  title.id = "keep-panel-title";
  dialog.setAttribute("aria-labelledby", title.id);
  const shut = make("button", "icon-btn small shut");
  shut.type = "button";
  shut.setAttribute("aria-label", say("Close"));
  shut.innerHTML = iconHtml("close");
  const head = make("div", "keep-head");
  head.append(title, shut);
  const rows = make("div", "keep-rows");
  const mine = make("div", "keep-rows mine");
  const listsHead = make("h3", "", say("Your lists"));
  const said = make("p", "said");
  said.setAttribute("role", "status");
  const newButton = make("button", "link keep-new-open");
  newButton.type = "button";
  newButton.innerHTML = `${iconHtml("plus")}<span>${escapeText(say("New list…"))}</span>`;
  const form = make("form", "keep-new");
  form.hidden = true;
  const field = make("input");
  field.type = "text";
  field.name = "name";
  field.maxLength = 80;
  field.required = true;
  field.autocomplete = "off";
  field.setAttribute("aria-label", say("The new list's name"));
  field.placeholder = say("Name it: Castles, To build, Gifts");
  const shown = make("label", "choice");
  const publicBox = make("input");
  publicBox.type = "checkbox";
  shown.append(publicBox, make("span", "", say("Public: on your profile and in the gallery's lists")));
  const makeIt = make("button", "cta small", say("Make it"));
  makeIt.type = "submit";
  const cancel = make("button", "cta ghost small", say("Cancel"));
  cancel.type = "button";
  const formButtons = make("div", "keep-new-buttons");
  formButtons.append(makeIt, cancel);
  form.append(field, shown, formButtons);
  const manage = make("a", "keep-manage", say("Manage your lists"));
  manage.href = `${langPrefix()}/lists`;
  const foot = make("div", "keep-foot");
  foot.append(newButton, manage);
  dialog.append(head, rows, listsHead, mine, form, foot, said);

  /// A box that saves as it is ticked: [words], what it is ([note]), on.
  function row(words, note, on, change, id) {
    const label = make("label", "choice keep-row");
    if (id) label.dataset.keepList = id;
    const box = make("input");
    box.type = "checkbox";
    box.checked = on;
    box.addEventListener("change", () => change(box));
    const text = make("span", "keep-name", words);
    label.append(box, text);
    if (note) label.append(make("small", "", note));
    return label;
  }

  function draw() {
    const one = known.get(key) || blank();
    const focused = dialog.querySelector(":focus");
    const focusAt = focused?.closest("[data-row]")?.dataset.row || focused?.closest("[data-keep-list]")?.dataset.keepList || "";
    rows.replaceChildren();
    if (set) {
      const owning = row(say("I own it"), "", one.own > 0, (box) => {
        const before = one.own;
        if (!box.checked && before > 0) ownedBefore.set(key, before);
        const back = box.checked ? Math.max(1, before, ownedBefore.get(key) || 0) : 0;
        if (box.checked) ownedBefore.delete(key);
        own(key, back).then((done) => {
          if (done) tell(box.checked ? say("In the sets you own: its parts count as yours.") : say("Out of the sets you own."));
        });
      });
      const owningLine = make("div", "keep-line");
      owningLine.dataset.row = "own";
      owningLine.append(owning);
      if (one.own > 0) owningLine.append(stepper(one));
      const wanting = row(say("I want it"), say("your wishlist"), one.wanted, (box) => {
        keepIn(key, "want", box.checked).then((done) => {
          if (done) tell(box.checked ? say("On your wishlist.") : say("Off your wishlist."));
        });
      });
      wanting.dataset.row = "want";
      rows.append(owningLine, wanting);
    } else {
      const saving = row(say("Saved"), say("only you"), one.saved, (box) => {
        keepIn(key, "saved", box.checked).then((done) => {
          if (done) tell(box.checked ? say("Saved: it is on your profile's Saved, for you alone.") : say("No longer saved."));
        });
      });
      saving.dataset.row = "saved";
      rows.append(saving);
    }
    mine.replaceChildren();
    for (const list of lists) {
      const note = list.down ? say("taken down") : list.public ? say("public") : say("only you");
      mine.append(row(list.name, note, one.lists.has(list.id), (box) => {
        keepIn(key, list.id, box.checked).then((done) => {
          if (done) tell(box.checked ? say("In {list}.", { list: list.name }) : say("Out of {list}.", { list: list.name }));
        });
      }, list.id));
    }
    if (!lists.length) mine.append(make("p", "note", say("No lists of your own yet: make one for a theme, a shelf or what to build next.")));
    // The focus stays on the box it was on.
    if (focusAt) {
      const where = CSS.escape(focusAt);
      const again = focused?.matches("button") && focused.getAttribute("aria-label")
        ? dialog.querySelector(`[data-row="${where}"] button[aria-label="${CSS.escape(focused.getAttribute("aria-label"))}"]`)
        : dialog.querySelector(`[data-row="${where}"] input, [data-keep-list="${where}"] input`);
      again?.focus();
    }
  }

  /// How many: − n +, one copy more or fewer at a tap, none taking it out.
  function stepper(one) {
    const box = make("span", "keep-qty");
    const fewer = make("button", "icon-btn small", "−");
    fewer.type = "button";
    fewer.setAttribute("aria-label", say("One fewer"));
    const more = make("button", "icon-btn small");
    more.type = "button";
    more.innerHTML = iconHtml("plus");
    more.setAttribute("aria-label", say("One more"));
    const n = make("output", "", String(one.own));
    n.setAttribute("aria-label", say("How many you own"));
    fewer.addEventListener("click", (event) => {
      event.preventDefault();
      own(key, Math.max(0, one.own - 1)).then((done) => { if (done) tell(say("You own {n}.", { n: one.own })); });
    });
    more.addEventListener("click", (event) => {
      event.preventDefault();
      own(key, Math.min(999, one.own + 1)).then((done) => { if (done) tell(say("You own {n}.", { n: one.own })); });
    });
    box.append(fewer, n, more);
    return box;
  }

  newButton.addEventListener("click", () => {
    form.hidden = false;
    newButton.hidden = true;
    field.focus();
  });
  cancel.addEventListener("click", () => {
    form.hidden = true;
    newButton.hidden = false;
    field.value = "";
    newButton.focus();
  });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const listName = field.value.trim();
    if (!listName) return;
    makeIt.disabled = true;
    const answer = await call("/api/people?op=collection", { method: "POST", body: { name: listName, public: publicBox.checked } });
    makeIt.disabled = false;
    if (answer.status !== 200 || typeof answer.body?.id !== "string") {
      tell(trouble(answer, say("That list was not made: try again in a moment.")));
      return;
    }
    lists = [{ ...answer.body, sets: 0, models: 0 }, ...lists];
    field.value = "";
    publicBox.checked = false;
    form.hidden = true;
    newButton.hidden = false;
    draw();
    const done = await keepIn(key, answer.body.id, true);
    if (done) tell(say("Made {list}, with it in.", { list: answer.body.name }));
    dialog.querySelector(`[data-keep-list="${CSS.escape(answer.body.id)}"] input`)?.focus();
  });

  function place() {
    const phone = matchMedia("(width < 600px)").matches;
    dialog.classList.toggle("at-foot", phone);
    if (phone || !button?.isConnected) {
      dialog.style.removeProperty("top");
      dialog.style.removeProperty("left");
      return;
    }
    const at = button.getBoundingClientRect();
    const width = dialog.offsetWidth;
    const height = dialog.offsetHeight;
    const left = Math.max(16, Math.min(innerWidth - width - 16, at.right - width));
    const below = at.bottom + 6;
    const top = below + height <= innerHeight - 16 ? below : Math.max(16, at.top - 6 - height);
    dialog.style.left = `${Math.round(left)}px`;
    dialog.style.top = `${Math.round(top)}px`;
  }

  const state = {
    key, draw,
    tell(words) {
      said.textContent = "";
      setTimeout(() => { said.textContent = String(words); }, 40);
    },
    close() {
      if (dialog.open) dialog.close();
    },
  };
  open = state;
  shut.addEventListener("click", () => state.close());
  // A tap outside it, over the page, closes it.
  dialog.addEventListener("click", (event) => {
    if (event.target !== dialog) return;
    const box = dialog.getBoundingClientRect();
    if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) state.close();
  });
  // Beside its button: the window resized or the page scrolled under it
  // (not a scroll of its own lists) closes it.
  const away = (event) => {
    if (event?.target instanceof Node && dialog.contains(event.target)) return;
    if (!dialog.classList.contains("at-foot")) state.close();
  };
  dialog.addEventListener("close", () => {
    if (open === state) open = null;
    removeEventListener("resize", away);
    removeEventListener("scroll", away, true);
    button?.setAttribute("aria-expanded", "false");
    dialog.remove();
    if (button?.isConnected) button.focus();
  });
  draw();
  document.body.append(dialog);
  dialog.showModal();
  button?.setAttribute("aria-expanded", "true");
  place();
  addEventListener("resize", away);
  // A wheel or a scroll of the page moves the button from under it.
  setTimeout(() => addEventListener("scroll", away, true), 0);
  dialog.querySelector(".keep-rows input")?.focus();
}

function escapeText(text) {
  const holder = document.createElement("span");
  holder.textContent = text;
  return holder.innerHTML;
}

/// The page's language as its address has it ("/de"), so Manage your lists
/// stays in it.
function langPrefix() {
  const lang = document.documentElement.lang || "en";
  return lang !== "en" && location.pathname.startsWith(`/${lang}/`) ? `/${lang}` : "";
}

// ---------------------------------------------------------------------------

document.addEventListener("click", (event) => {
  const button = event.target.closest?.("[data-keep-main], [data-keep-want], [data-keep-more]");
  const holder = button?.closest("[data-keep]");
  if (!holder || !KEY.test(holder.dataset.keep || "")) return;
  event.preventDefault();
  event.stopPropagation();
  if (button.matches("[data-keep-main]")) pressMain(holder);
  else if (button.matches("[data-keep-want]")) pressWant(holder);
  else pressMore(holder, button);
});

see();
new MutationObserver((changes) => {
  for (const change of changes) {
    for (const node of change.addedNodes) {
      if (node.nodeType === 1 && (node.matches("[data-keep]") || node.querySelector("[data-keep]"))) {
        see(node);
      }
    }
  }
}).observe(document.body || document.documentElement, { childList: true, subtree: true });

/// For a page that changed what the person has itself (the Your lists
/// page): forget [keys], or everything, so they are asked again.
export function forget(keys = null) {
  if (keys) for (const key of keys) known.delete(key);
  else known.clear();
  see();
}
