// The gallery, /gallery: the models people listed when they shared them,
// a page at a time from /api/share?op=list (api/share.js), searched,
// filtered and ordered as the controls say (docs/SOCIAL.md U3).
//
// Which models, in which order, are the tabs: Top (the default: builds
// finished, remixes and the Tested mark, supabase/discovery.sql; never
// views), over all time, this month or this week; New; and, signed in,
// Following, the models of the people you follow. The kinds are a row of
// pills; the rest (the order, the size, instructions, Technic, Tested,
// hand-built or with the assistant) is in Filters. The time windows,
// Following and Made are offered only when the list says it can answer
// them (supabase/gallery_tabs.sql applied).
//
// The question lives in the address (?q=castle&kind=space&sort=newest&...),
// put back with replaceState as it changes, so a search can be sent to
// somebody and a reload asks it again. The list is paged as every list of
// the site is (web/pager.js): Show more, the last page shown in the
// address (&page=3), Show earlier over a page opened by its address, the
// count and the numbered links, and Back putting the same pages and the
// card left where they were. A search waits for typing to stop; a filter
// asks at once; an answer that comes back after a newer question was
// asked is thrown away.
//
// The front of it, Top over all time with nothing asked, has this week's
// pick as its first card (/api/share?op=shelves): the one the daily cron
// kept for the week (api/_featured.js), worked out from the past seven
// days' builds, remixes and Tested marks while it has none, unless the
// site's owner chose one. After the first rows, its shelves: today's
// featured model and today's set from the LDraw library, as the cron kept
// them; what a signed-in
// person can build now, every part in their collection, and small builds,
// the Size filter's Small by Top builds, once there are three of them
// (D12: a shelf of one looks broken).
//
// Signed in (web/account.js has a sign-in kept in this browser), the list
// and the shelves are asked with mine=1 and the sign-in: each card says
// whether they like it, and how much of it their collection holds; Filters
// offers Parts I own. Their own, so never kept by the CDN. A like from a
// card counts at once; signed out, it asks them to sign in first.
//
// Names, credits and tags were typed by strangers, so every one goes on
// the page as text, never as markup (web/card.js escapes what it draws); a
// link is built from the model's id alone, and only an id that is one.
// Same origin throughout: the site's content security policy lets a page
// talk to itself and a short list of others.
//
// Each card is web/card.js's, the one every page of the site draws.
import { FIRST_SCREEN, counted, iconButtonHtml, likeName, modelCard, skeletonHtml } from "/card.js";
// The toast, and Filters closing on a click elsewhere as a "more" menu does.
import { toast } from "/kit.js";
// "/" to search, and the bar of filters kept under the header.
import { browseBar } from "/browse.js";
// The site's one way to page a list.
import { pageAsked, pager } from "/pager.js";

(function () {
  "use strict";

  const ID = /^[A-Za-z0-9]{10}$/;
  // A set of the LDraw library's (api/_library.js SET_ID).
  const SET_ID = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
  const $ = (id) => document.getElementById(id);
  const feed = $("feed");
  const grid = $("models");
  const form = $("finder");
  const q = $("q");
  const sort = $("sort");
  const size = $("size");
  const made = $("made");
  const windowed = $("window");
  const instructions = $("instructions");
  const technic = $("technic");
  const tested = $("tested");
  const shelves = $("shelves");
  // What the front's shelves are, once asked: null until then.
  let front = null;
  let weights = null;
  // The site's sign-in (web/account.js) while this browser has one: the
  // list and the shelves are then asked with it, and mine=1.
  let own = null;
  let filled = false;
  // The shelves, which the first page waits for (askShelves).
  let hold = null;
  // Whether the front's pick is one of the first page's, drawn in its own
  // place and not again in the list's.
  let pickTaken = false;
  // What the list said it can answer: Following, Made and Top's windows.
  let offers = { following: false, made: false, windows: false };
  // The question's own words, beside the controls that hold the rest.
  let kind = "";
  let tag = "";
  let following = false;
  // The list's own word on each of its models (whether they like it, how
  // much of it their collection holds), for the pick, which leads the list
  // in its place.
  const listed = new Map();
  // A probe's own models are tests, which the list leaves out unless asked
  // (api/share.js): an address with tests=1 asks, and keeps asking.
  const tests = new URLSearchParams(location.search).get("tests") === "1";
  // The orders this page offers; Most viewed is not one (D6: views never
  // rank), though the list still answers it for the app.
  const ORDERS = ["top", "newest", "likes", "builds", "remixes", "owned"];

  /// [path] of the site's API as JSON: with the sign-in and mine=1 while
  /// there is one, and once more without when the sign-in has ended.
  async function askApi(path) {
    if (own) {
      const answer = await own.call(`${path}&mine=1`).catch(() => null);
      if (answer && answer.status !== 401) return answer;
      own = null;
    }
    const reply = await fetch(path, { headers: { accept: "application/json" } });
    return { status: reply.status, body: await reply.json().catch(() => ({})) };
  }

  /// "once", "twice", "5 times".
  const times = (n) => (n === 1 ? "once" : n === 2 ? "twice" : `${Number(n).toLocaleString("en-US")} times`);

  /// Why the pick is the pick, in a line: what its week was, or that the
  /// site's owner chose it.
  function whyPicked(pick) {
    const week = pick.week || {};
    const said = [];
    if (week.builds) said.push(`built ${times(week.builds)} this week`);
    if (week.remixes) said.push(`remixed ${times(week.remixes)} this week`);
    if (!said.length && week.tested) said.push("new this week, and Tested");
    const line = said.join(", ");
    if (pick.chosen) return line ? `Chosen by Brickworks · ${line}` : "Chosen by Brickworks";
    return line ? line[0].toUpperCase() + line.slice(1) : "";
  }

  /// What a select says: until the first answer fills it in, what the
  /// address asked of it.
  const chosen = (select) => (filled ? select.value : select.dataset.wanted || "");
  const order = () => chosen(sort) || "top";

  /// Whether anything is asked beyond which models and their order.
  function searching() {
    return Boolean(q.value.trim() || kind || tag || chosen(size) || chosen(made)
      || instructions.checked || technic.checked || tested.checked);
  }

  /// The front: Top over all time, everybody's, nothing asked.
  const atFront = () => order() === "top" && !following && !chosen(windowed) && !searching();

  // The list's pages (web/pager.js), made once the functions it calls are.
  let paged = null;
  const shownPage = () => (paged ? paged.state.last : 1);

  /// The question the controls ask, as a query string: for the list
  /// (sort always said, the list's own default being newest), or for the
  /// address (Top left out, the page's default, and the last page shown).
  /// With [over], as it would be with those changed: a tab's own address.
  function question({ address = false, over = {} } = {}) {
    const at = { kind, tag, following, sort: order(), window: chosen(windowed), page: shownPage(), ...over };
    const asked = new URLSearchParams();
    const words = q.value.trim().slice(0, 100);
    if (words) asked.set("q", words);
    if (at.kind) asked.set("kind", at.kind);
    if (chosen(size)) asked.set("size", chosen(size));
    if (chosen(made)) asked.set("made", chosen(made));
    if (instructions.checked) asked.set("instructions", "1");
    if (technic.checked) asked.set("technic", "1");
    if (tested.checked) asked.set("tested", "1");
    if (at.tag) asked.set("tag", at.tag);
    if (at.following) asked.set("following", "1");
    if (!address || at.sort !== "top") asked.set("sort", at.sort);
    if (at.sort === "top" && at.window) asked.set("window", at.window);
    if (address && at.page > 1) asked.set("page", String(at.page));
    if (tests) asked.set("tests", "1");
    return asked;
  }

  /// The address of what is asked now, or with [over] changed.
  function addressOf(over = {}) {
    const query = question({ address: true, over }).toString();
    return query ? `/gallery?${query}` : "/gallery";
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

  /// The tabs, Top's window and the kinds as the question has them, and
  /// each tab's address, so it can be opened in a new tab or sent.
  function drawTabs() {
    const now = following ? "following" : order() === "top" ? "top" : order() === "newest" ? "new" : "";
    for (const tab of document.querySelectorAll("#tabs [data-tab]")) {
      const which = tab.dataset.tab;
      if (which === now) tab.setAttribute("aria-current", "page");
      else tab.removeAttribute("aria-current");
      tab.href = addressOf({ following: which === "following", sort: which === "top" ? "top" : "newest",
        window: "", page: 1 });
    }
    $("tabs").querySelector('[data-tab="following"]').hidden = !(own && offers.following);
    $("window-label").hidden = !(offers.windows && order() === "top");
    $("made-label").hidden = !offers.made;
    for (const pill of document.querySelectorAll("#kinds [data-kind]")) {
      pill.setAttribute("aria-pressed", String(pill.dataset.kind === kind));
    }
  }

  /// The kinds as pills, once the list says what they are.
  function fillKinds(kinds) {
    const row = $("kinds");
    for (const one of kinds || []) {
      if (row.querySelector(`[data-kind="${CSS.escape(String(one.id))}"]`)) continue;
      const pill = document.createElement("button");
      pill.type = "button";
      pill.className = "pill";
      pill.dataset.kind = String(one.id);
      pill.textContent = String(one.label);
      pill.setAttribute("aria-pressed", "false");
      row.append(pill);
    }
  }

  /// What each select now says, in its own words ("Small (under 200
  /// parts)"), or "" for its first choice; until the list has filled it
  /// in, what the address asked of it, so its chip is there from the first
  /// frame and only its words change.
  const saidBy = (select) => (!filled ? select.dataset.wanted || ""
    : chosen(select) && select.selectedIndex > 0 ? select.options[select.selectedIndex].textContent : "");

  /// How many filters are on, on the Filters button, and each as a chip
  /// to let go of: the tag, an order other than the tabs', a size, how it
  /// was made and each box ticked; Clear all once there are two.
  function sayFilters() {
    let on = [chosen(size), chosen(made), instructions.checked, technic.checked, tested.checked].filter(Boolean).length;
    if (!["top", "newest"].includes(order())) on += 1;
    const n = $("filters-said");
    n.textContent = on ? String(on) : "";
    n.hidden = !on;
    $("filters").querySelector("summary").setAttribute("aria-label", on ? `Filters, ${on} on` : "Filters");
    const chips = $("chips");
    const kept = chips.contains(document.activeElement) ? [...chips.children].indexOf(document.activeElement) : -1;
    chips.replaceChildren();
    const chip = (words, said, drop, kind = "pill") => {
      const one = document.createElement("button");
      one.type = "button";
      one.className = kind;
      one.textContent = `${words} ×`;
      one.setAttribute("aria-label", said);
      one.addEventListener("click", drop);
      chips.append(one);
    };
    if (tag) chip(tag, `Stop filtering by the tag ${tag}`, () => { tag = ""; ask(); }, "pill tag");
    if (!["top", "newest"].includes(order())) {
      const words = saidBy(sort) || order();
      chip(words, `Stop ordering by ${words}`, () => { sort.value = "top"; ask(); });
    }
    for (const [select, what] of [[size, "size"], [made, "how it was made"]]) {
      const words = saidBy(select);
      if (words) chip(words, `Stop filtering by ${what}: ${words}`, () => { select.value = ""; ask(); });
    }
    for (const [box, words] of [[instructions, "Has instructions"], [technic, "Technic or mechanism"], [tested, "Tested only"]]) {
      if (box.checked) chip(words, `Stop filtering by ${words}`, () => { box.checked = false; ask(); });
    }
    if (chips.children.length > 1) {
      const all = document.createElement("button");
      all.type = "button";
      all.className = "link";
      all.textContent = "Clear all";
      all.addEventListener("click", () => {
        for (const select of [size, made]) select.value = "";
        if (!["top", "newest"].includes(sort.value)) sort.value = "top";
        instructions.checked = technic.checked = tested.checked = false;
        tag = "";
        ask();
      });
      chips.append(all);
    }
    chips.hidden = !chips.children.length;
    // A chip let go of: the focus on what took its place, never the body.
    if (kept >= 0) (chips.children[Math.min(kept, chips.children.length - 1)] || q).focus();
  }

  /// A card of the list, its like a button; [eager] for the first screen's.
  const card = (model, eager = false) => modelCard(model, { like: true, eager });

  /// The shelves, drawn from [front]: the pick as the first card and the
  /// shelves after the first rows, on the gallery's front alone.
  function drawShelves() {
    // The front's first page alone: a page opened by its address has none.
    const shown = atFront() && (!paged || paged.state.first <= 1);
    const pick = shown && front && front.pick && front.pick.model && ID.test(String(front.pick.model.id)) ? front.pick : null;
    const small = shown && front && front.small ? (front.small.models || []).filter((m) => m && ID.test(String(m.id))) : [];
    $("pick").hidden = !pick;
    const holder = $("pick-card");
    holder.replaceChildren();
    if (pick) {
      const picked = card({ ...pick.model, ...(listed.get(String(pick.model.id)) || {}) }, true);
      picked.classList.add("pick-card");
      picked.dataset.chosen = pick.chosen ? "yes" : "no";
      const frame = picked.querySelector(".frame");
      const marks = frame.querySelector(".marks") || frame.appendChild(document.createElement("div"));
      marks.className = "marks";
      const mark = document.createElement("span");
      mark.className = "pill new";
      // Short: one row of marks over a phone's card, 12% of its picture at most.
      mark.textContent = "Week’s pick";
      marks.prepend(mark);
      const why = document.createElement("p");
      why.className = "why";
      why.textContent = whyPicked(pick);
      picked.querySelector(".by").after(why);
      holder.append(picked);
      // Not twice on one screen: the pick leads, the list goes on without it.
      grid.querySelector(`.model[data-id="${pick.model.id}"]`)?.remove();
    }
    // Today's featured model and set (api/_featured.js), each marked as
    // the pick is, and why: the featured model's in the API's words
    // (featuredSaid: only what is true of it), the set's its theme and
    // decade. A set is nobody's to like: its card has no like.
    const spot = shown && front ? [["featured", front.featured, ID, "Featured today"],
      ["library", front.library, SET_ID, "LDraw library"]]
      .filter(([, one, valid]) => one && one.model && valid.test(String(one.model.id))) : [];
    $("spotlight").hidden = spot.length === 0;
    $("spotlight-models").replaceChildren(...spot.map(([slot, one, , label]) => {
      const drawn = slot === "featured" ? card({ ...one.model, ...(listed.get(String(one.model.id)) || {}) })
        : modelCard(one.model);
      drawn.dataset.slot = slot;
      const frame = drawn.querySelector(".frame");
      const marks = frame.querySelector(".marks") || frame.appendChild(document.createElement("div"));
      marks.className = "marks";
      const mark = document.createElement("span");
      mark.className = "pill new";
      mark.textContent = label;
      marks.prepend(mark);
      const said = slot === "featured" ? String(one.said || "") : [one.why?.theme, one.why?.decade].filter(Boolean).join(", ");
      if (said) {
        const why = document.createElement("p");
        why.className = "why";
        why.textContent = said;
        (drawn.querySelector(".by") || drawn.querySelector(".words"))?.after(why);
      }
      return drawn;
    }));
    // A shelf of one or two looks broken: three at least (D12).
    $("small").hidden = small.length < 3;
    // Lazy, under the first rows: map's index is no [eager] (it made seven
    // of the eight eager, far under the first screen).
    $("small-models").replaceChildren(...(small.length < 3 ? [] : small.map((one) => card(one))));
    $("small-all").hidden = !(front && front.small && front.small.more);
    // What they can build now: signed in, every part in their collection.
    const signedIn = Boolean(shown && front && "mine" in front);
    const pool = signedIn ? front.mine : null;
    const ready = pool && front.ready ? (front.ready.models || []).filter((m) => m && ID.test(String(m.id))) : [];
    $("ready").hidden = !signedIn;
    $("ready-models").replaceChildren(...ready.map((one) => card(one)));
    $("ready-models").hidden = ready.length === 0;
    $("ready-all").hidden = !pool;
    const said = $("ready-said");
    if (!pool) {
      said.textContent = "Tell Brickworks what you own (in the app, Build › My collection…) and this "
        + "shows what in the gallery you can build with it.";
    } else if (!ready.length) {
      said.textContent = `Nothing in the gallery is all in your collection of ${counted(pool.pieces, "part")} yet. `
        + "Parts I own, in Filters, shows what is closest.";
    } else {
      said.textContent = `Every part of these is in your collection of ${counted(pool.pieces, "part")}: the most `
        + "built and remixed first.";
    }
    if (pool && pool.unknown) {
      said.textContent += ` ${counted(pool.unknown, "set")} of yours ${pool.unknown === 1 ? "has" : "have"} no `
        + "parts list here, so what is in them is not counted.";
    }
    // Nothing listed at all: the empty gallery says so, with no shelf.
    shelves.hidden = ($("small").hidden && $("ready").hidden && $("spotlight").hidden) || grid.children.length === 0;
    feed.dataset.front = !shown ? "" : pick ? "pick" : "plain";
  }

  /// How Top builds weighs, said under the list while it is chosen.
  function sayScore() {
    const line = $("score-said");
    const w = weights;
    line.hidden = !(w && order() === "top" && grid.children.length);
    if (w) {
      line.textContent = `Top builds: a build finished counts ${w.builds}, a remix ${w.remixes} and the `
        + `Tested mark ${w.tested}. Views count for nothing.`;
    }
  }

  /// This month's challenge, in one line under the question: the one open
  /// now, or the next to open (supabase/challenges.sql).
  function sayChallenge() {
    const line = $("challenge-line");
    const challenge = front && front.challenge;
    line.hidden = !challenge;
    line.replaceChildren();
    if (!challenge) return;
    const day = (iso) => new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", timeZone: "UTC" })
      .format(new Date(`${String(iso).slice(0, 10)}T00:00:00Z`));
    const link = document.createElement("a");
    link.href = tests ? "/challenge?tests=1" : "/challenge";
    link.textContent = String(challenge.title);
    if (challenge.state === "open") {
      line.append("This month’s challenge: ", link, `, open until ${day(challenge.ends_on)}. Enter a model of yours, or vote.`);
    } else {
      line.append("The next challenge: ", link, `, opens on ${day(challenge.starts_on)}.`);
    }
  }

  /// The front's shelves, asked once; drawn whenever the question changes.
  /// [draw]: false when the first page is waiting on them, to draw the pick,
  /// the challenge and the cards in one frame: each drawn as it came moved
  /// the others (the pick put in before the cards pushed every card on).
  async function askShelves({ draw = true } = {}) {
    try {
      const reply = await askApi(`/api/share?op=shelves${tests ? "&tests=1" : ""}`);
      if (reply.status !== 200) throw new Error(String(reply.status));
      front = reply.body;
      if (front.score) weights = front.score;
    } catch {
      front = null;
    }
    document.documentElement.dataset.shelves = front ? "ready" : "broken";
    if (!draw) return;
    drawShelves();
    sayScore();
    sayChallenge();
  }

  /// What an empty answer says: nothing listed at all, nothing matching,
  /// or a tab or a window with nothing in it yet, with the way on.
  function sayNone() {
    const none = grid.children.length === 0 && $("pick").hidden;
    const quiet = !searching() && (following || Boolean(chosen(windowed)));
    $("empty").hidden = !none || searching() || quiet;
    $("nothing").hidden = !none || !searching();
    $("quiet").hidden = !none || !quiet;
    if (none && quiet) {
      const go = $("quiet-go");
      if (following) {
        $("quiet-said").textContent = "Nobody you follow has listed a model yet. Follow a designer from "
          + "their page or from beside one of their models, and what they list comes here.";
        go.textContent = "See Top";
        go.href = addressOf({ following: false, sort: "top", window: "", page: 1 });
        go.dataset.go = "top";
      } else {
        const span = windowed.options[windowed.selectedIndex]?.textContent.toLowerCase() || "lately";
        $("quiet-said").textContent = `Nothing was built or remixed here ${span} yet. A model joins Top `
          + "when somebody builds it to its last step, remixes it, or it is Tested.";
        go.textContent = "See all time";
        go.href = addressOf({ window: "", page: 1 });
        go.dataset.go = "all";
      }
    }
  }

  /// The address asked what the list does not know (a kind that is not
  /// one, say, Parts I own signed out, or Following before it can be
  /// answered): the whole gallery instead, and the address put right.
  class Unknown extends Error {}

  /// Page [n] of the list as cards, once the shelves the first page waits
  /// for have come too, so the pick, the challenge and the cards are drawn
  /// in one frame (each drawn as it came moved the others).
  async function load(n) {
    const asked = question();
    asked.set("page", String(n));
    const reply = await askApi(`/api/share?op=list&${asked}`);
    if ((reply.status === 400 || reply.status === 401) && !filled && [...question({ address: true }).keys()]
      .some((key) => !["tests", "page"].includes(key))) throw new Unknown();
    if (reply.status !== 200) throw new Error(String(reply.status));
    if (hold) await hold;
    const data = reply.body;
    // As many pictures asked for at once as the first screen shows at this
    // width, when this page is the first drawn: the places of what it
    // replaces (its skeletons, at first) that are on it. Twelve left the
    // third row lazy at 1920.
    const first = document.documentElement.dataset.gallery !== "ready";
    const eager = first ? [...grid.children].filter((one) => one.getBoundingClientRect().top < innerHeight).length
      || FIRST_SCREEN : 0;
    // A card once: the front's pick leads, and the list goes on without it.
    const pick = n === 1 && atFront() && front && front.pick && front.pick.model ? String(front.pick.model.id) : "";
    const items = [];
    if (n === 1) pickTaken = false;
    for (const model of data.models || []) {
      const id = String(model && model.id);
      if (!ID.test(id)) continue;
      listed.set(id, model);
      if (id !== pick) items.push(card(model, items.length < eager));
      else pickTaken = true;
    }
    return { items, more: Boolean(data.more), data };
  }

  /// What the page says once a page of the list is drawn: on the first,
  /// the controls the list offers, the tabs, the shelves and the challenge.
  function drawn({ answer, fresh }) {
    const data = answer.data || {};
    if (fresh) {
      offers = { following: data.following === true, made: Array.isArray(data.mades),
        windows: Array.isArray(data.windows) };
      if (!filled) {
        fillKinds(data.kinds);
        fill(size, data.sizes);
        fill(sort, (data.sorts || []).filter((one) => ORDERS.includes(one.id)));
        fill(made, data.mades);
        fill(windowed, data.windows);
        filled = true;
      }
    }
    if (data.score) weights = data.score;
    $("loading").hidden = true;
    $("broken").hidden = true;
    sayNone();
    if (fresh) {
      $("found").textContent = grid.children.length
        ? `${counted(grid.children.length, "model")}${data.more ? ", more below" : ""}` : "";
    }
    drawTabs();
    sayFilters();
    sayScore();
    drawShelves();
    if (hold) {
      hold = null;
      sayChallenge();
    }
    document.documentElement.dataset.gallery = "ready";
    // The pages shown, as the address says the last of them.
    document.documentElement.dataset.pages = String(paged.state.last);
  }

  /// A page that did not come: the first, said in place of the list, with
  /// Retry (Show more's own says so in its place, web/pager.js).
  function failed({ fresh, trouble }) {
    if (trouble instanceof Unknown) {
      for (const select of [size, sort, made, windowed]) select.dataset.wanted = "";
      q.value = "";
      instructions.checked = technic.checked = tested.checked = false;
      kind = tag = "";
      following = false;
      history.replaceState(null, "", tests ? "/gallery?tests=1" : "/gallery");
      paged.restart(1);
      return;
    }
    if (!fresh) return;
    for (const bones of grid.querySelectorAll(".skeleton")) bones.remove();
    $("loading").hidden = true;
    $("broken").hidden = false;
    document.documentElement.dataset.gallery = "broken";
  }

  /// Ask again from the first page, with the address saying what was asked.
  function ask() {
    history.replaceState(null, "", addressOf({ page: 1 }));
    sayFilters();
    drawTabs();
    drawShelves();
    sayScore();
    document.documentElement.dataset.gallery = "asking";
    return paged.restart(1);
  }

  paged = pager({ list: grid, load, href: (n) => addressOf({ page: n }), noun: ["model", "models"], drawn, failed,
    counted: () => grid.querySelectorAll(".model").length + (pickTaken && paged.state.first <= 1 && !$("pick").hidden ? 1 : 0),
    skeleton: () => {
      const made = document.createElement("template");
      made.innerHTML = skeletonHtml();
      return made.content.firstElementChild;
    } });

  // --- a like from a card ---------------------------------------------------

  /// Every like button of model [id] on the page (the pick, the list, a
  /// shelf), drawn as [liked] with [likes].
  function drawLike(id, liked, likes) {
    for (const button of document.querySelectorAll(`[data-like="${id}"]`)) {
      const made = document.createElement("template");
      const name = button.closest(".model")?.querySelector("a.open")?.textContent || "";
      made.innerHTML = iconButtonHtml({ icon: "like", name: likeName(name), count: likes, one: "like", pressed: liked,
        small: true, attrs: `data-like="${id}"` });
      const fresh = made.content.firstElementChild;
      button.setAttribute("aria-pressed", fresh.getAttribute("aria-pressed"));
      button.setAttribute("aria-label", fresh.getAttribute("aria-label"));
      button.replaceChildren(...fresh.childNodes);
    }
  }

  async function like(button) {
    const id = button.dataset.like;
    if (!ID.test(id)) return;
    if (!own) {
      const account = await import("/account.js");
      if (!account.signedIn() && !(await account.askToSignIn("Sign in to like it: we email you a code, no password."))) return;
      own = account;
    }
    const was = button.getAttribute("aria-pressed") === "true";
    const count = Number(button.querySelector(".n")?.textContent.replace(/,/g, "")) || 0;
    // At once, then as the server counts it.
    drawLike(id, !was, Math.max(0, count + (was ? -1 : 1)));
    button.disabled = true;
    const answer = await own.call(`/api/people?op=like&id=${id}`, { method: "POST", body: { on: !was } })
      .catch(() => ({ status: 0, body: {} }));
    button.disabled = false;
    if (answer.status === 200) {
      drawLike(id, answer.body.liked === true, Number(answer.body.likes) || 0);
      return;
    }
    drawLike(id, was, count);
    toast(answer.body && answer.body.error ? String(answer.body.error) : "That did not work just now. Try again.");
  }

  feed.addEventListener("click", (event) => {
    const button = event.target.closest("[data-like]");
    if (button) {
      event.preventDefault();
      like(button);
    }
  });

  // --- the controls ---------------------------------------------------------

  for (const tab of document.querySelectorAll("#tabs [data-tab]")) {
    tab.addEventListener("click", (event) => {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      const which = tab.dataset.tab;
      following = which === "following";
      sort.value = sort.dataset.wanted = which === "top" ? "top" : "newest";
      windowed.value = windowed.dataset.wanted = "";
      ask();
    });
  }
  $("quiet-go").addEventListener("click", (event) => {
    event.preventDefault();
    if (event.currentTarget.dataset.go === "top") {
      following = false;
      sort.value = sort.dataset.wanted = "top";
    }
    windowed.value = windowed.dataset.wanted = "";
    ask();
  });
  $("kinds").addEventListener("click", (event) => {
    const pill = event.target.closest("[data-kind]");
    if (!pill) return;
    kind = pill.dataset.kind;
    ask();
  });

  // The question the address asks, put in the controls before the first
  // answer: what the selects may hold is filled in when the list says, so
  // what is wanted waits on the select.
  const given = new URLSearchParams(location.search);
  q.value = (given.get("q") || "").slice(0, 100);
  const askedSort = given.get("sort") || "top";
  sort.dataset.wanted = ORDERS.includes(askedSort) ? askedSort : "top";
  for (const [select, name] of [[size, "size"], [made, "made"], [windowed, "window"]]) {
    select.dataset.wanted = given.get(name) || "";
  }
  instructions.checked = given.get("instructions") === "1";
  technic.checked = given.get("technic") === "1";
  tested.checked = given.get("tested") === "1";
  kind = (given.get("kind") || "").slice(0, 24);
  tag = (given.get("tag") || "").slice(0, 24);
  following = given.get("following") === "1";

  let typing = 0;
  q.addEventListener("input", () => {
    clearTimeout(typing);
    typing = setTimeout(ask, 200);
  });
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    clearTimeout(typing);
    ask();
  });
  for (const control of [sort, size, made, windowed, instructions, technic, tested]) control.addEventListener("change", ask);
  $("filters-clear").addEventListener("click", () => {
    for (const select of [size, made]) select.value = "";
    if (!["top", "newest"].includes(sort.value)) sort.value = "top";
    instructions.checked = technic.checked = tested.checked = false;
    ask();
  });
  $("clear").addEventListener("click", () => {
    q.value = "";
    for (const select of [size, made]) select.value = "";
    instructions.checked = technic.checked = tested.checked = false;
    kind = tag = "";
    ask();
  });
  // "/" to search, the bar of filters' edge once stuck, the kinds' fade.
  browseBar({ search: q, above: document.querySelector(".gallery-bar"), bar: $("toolbar"), row: $("kinds") });
  sayFilters();
  drawTabs();

  $("retry").addEventListener("click", () => {
    $("broken").hidden = true;
    $("loading").hidden = false;
    document.documentElement.dataset.gallery = "asking";
    paged.start(shownPage(), { restore: false });
  });

  // Signed in or not, before the first question: a module of the site's,
  // asked for only when this browser keeps a sign-in. Then the page the
  // address shows (and, Back, the pages before it that were shown, and
  // the card left where it was: web/pager.js).
  (async () => {
    try {
      const account = await import("/account.js");
      if (account.signedIn()) own = account;
    } catch {
      own = null;
    }
    drawTabs();
    hold = askShelves({ draw: false });
    await paged.start(pageAsked(location.search));
  })();
})();
