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
// somebody and a reload asks it again; and so does how many pages are
// shown (&page=3). The next page comes as the end of the list nears the
// screen, three times, then only by Show more, which gives the footer
// back (D5). A card opened is kept in the history's state, so Back from
// its page asks the same pages again and puts that card where it was. A
// search waits for typing to stop; a filter asks at once; an answer that
// comes back after a newer question was asked is thrown away.
//
// The front of it, Top over all time with nothing asked, has this week's
// pick as its first card (/api/share?op=shelves): worked out from the
// past seven days' builds, remixes and Tested marks unless the site's
// owner chose one. After the first rows, its shelves: what a signed-in
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
import { FIRST_SCREEN, counted, iconButtonHtml, likeName, modelCard } from "/card.js";
// The toast, and Filters closing on a click elsewhere as a "more" menu does.
import { toast } from "/kit.js";

(function () {
  "use strict";

  const ID = /^[A-Za-z0-9]{10}$/;
  const $ = (id) => document.getElementById(id);
  const feed = $("feed");
  const grid = $("models");
  const more = $("more");
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
  // Which page was asked last, and how many the end of the list fetched
  // by itself: three, then Show more.
  const AUTO = 3;
  let page = 0;
  let auto = 0;
  let hasMore = false;
  // What the front's shelves are, once asked: null until then.
  let front = null;
  let weights = null;
  // The site's sign-in (web/account.js) while this browser has one: the
  // list and the shelves are then asked with it, and mine=1.
  let own = null;
  let asking = 0;
  let loading = false;
  let filled = false;
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

  /// The question the controls ask, as a query string: for the list
  /// (sort always said, the list's own default being newest), or for the
  /// address (Top left out, the page's default, and how many pages). With
  /// [over], as it would be with those changed: a tab's own address.
  function question({ address = false, over = {} } = {}) {
    const at = { kind, tag, following, sort: order(), window: chosen(windowed), page, ...over };
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

  /// How many filters are on, on the Filters button, and the tag as a chip.
  function sayFilters() {
    let on = [chosen(size), chosen(made), instructions.checked, technic.checked, tested.checked].filter(Boolean).length;
    if (!["top", "newest"].includes(order())) on += 1;
    const n = $("filters-said");
    n.textContent = on ? String(on) : "";
    n.hidden = !on;
    $("filters").querySelector("summary").setAttribute("aria-label", on ? `Filters, ${on} on` : "Filters");
    const chips = $("chips");
    chips.replaceChildren();
    if (tag) {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.className = "pill tag";
      chip.textContent = `${tag} ×`;
      chip.setAttribute("aria-label", `Stop filtering by the tag ${tag}`);
      chip.addEventListener("click", () => { tag = ""; ask(); });
      chips.append(chip);
    }
    chips.hidden = !tag;
  }

  /// A card of the list, its like a button; [eager] for the first screen's.
  const card = (model, eager = false) => modelCard(model, { like: true, eager });

  /// The shelves, drawn from [front]: the pick as the first card and the
  /// shelves after the first rows, on the gallery's front alone.
  function drawShelves() {
    const shown = atFront();
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
      mark.textContent = "This week’s pick";
      marks.prepend(mark);
      const why = document.createElement("p");
      why.className = "why";
      why.textContent = whyPicked(pick);
      picked.querySelector(".by").after(why);
      holder.append(picked);
      // Not twice on one screen: the pick leads, the list goes on without it.
      grid.querySelector(`.model[data-id="${pick.model.id}"]`)?.remove();
    }
    // A shelf of one or two looks broken: three at least (D12).
    $("small").hidden = small.length < 3;
    $("small-models").replaceChildren(...(small.length < 3 ? [] : small.map(card)));
    $("small-all").hidden = !(front && front.small && front.small.more);
    // What they can build now: signed in, every part in their collection.
    const signedIn = Boolean(shown && front && "mine" in front);
    const pool = signedIn ? front.mine : null;
    const ready = pool && front.ready ? (front.ready.models || []).filter((m) => m && ID.test(String(m.id))) : [];
    $("ready").hidden = !signedIn;
    $("ready-models").replaceChildren(...ready.map(card));
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
    shelves.hidden = ($("small").hidden && $("ready").hidden) || grid.children.length === 0;
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

  /// The next page of the list ([fresh]: the first, in place of what is
  /// shown), drawn once [hold] (the shelves, on the first) has come too.
  /// Resolves once it is drawn.
  async function next(fresh, hold = null) {
    const mine = ++asking;
    loading = true;
    more.disabled = true;
    const asked = question();
    asked.set("page", String(fresh ? 1 : page + 1));
    try {
      const reply = await askApi(`/api/share?op=list&${asked}`);
      // An address that asks what the list does not know (a kind that is
      // not one, say, Parts I own signed out, or Following before it can
      // be answered): the whole gallery instead, and the address put right.
      if ((reply.status === 400 || reply.status === 401) && !filled && [...question({ address: true }).keys()]
        .some((key) => key !== "tests")) {
        for (const select of [size, sort, made, windowed]) select.dataset.wanted = "";
        q.value = "";
        instructions.checked = technic.checked = tested.checked = false;
        kind = tag = "";
        following = false;
        page = 0;
        history.replaceState(null, "", tests ? "/gallery?tests=1" : "/gallery");
        return next(true);
      }
      if (reply.status !== 200) throw new Error(String(reply.status));
      const data = reply.body;
      if (mine !== asking) return;
      if (hold) {
        await hold;
        if (mine !== asking) return;
      }
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
      if (data.score) weights = data.score;
      if (fresh) grid.replaceChildren();
      page = Number(data.page) || (fresh ? 1 : page + 1);
      // A card once: the front's pick leads, and a page that shifted
      // while it was read does not repeat one.
      const pick = !$("pick").hidden && front && front.pick && front.pick.model ? String(front.pick.model.id) : "";
      if (fresh) listed.clear();
      for (const model of data.models || []) {
        const id = String(model && model.id);
        if (!ID.test(id)) continue;
        listed.set(id, model);
        if (id === pick || grid.querySelector(`.model[data-id="${id}"]`)) continue;
        grid.append(card(model, fresh && grid.children.length < FIRST_SCREEN));
      }
      hasMore = Boolean(data.more);
      $("loading").hidden = true;
      $("broken").hidden = true;
      sayNone();
      $("found").textContent = grid.children.length
        ? `${counted(grid.children.length, "model")}${data.more ? ", more below" : ""}` : "";
      more.hidden = !hasMore;
      drawTabs();
      sayFilters();
      sayScore();
      drawShelves();
      if (hold) sayChallenge();
      history.replaceState(history.state, "", addressOf());
      document.documentElement.dataset.gallery = "ready";
      document.documentElement.dataset.pages = String(page);
    } catch {
      if (mine !== asking) return;
      for (const bones of grid.querySelectorAll(".skeleton")) bones.remove();
      $("loading").hidden = true;
      $("broken").hidden = false;
      document.documentElement.dataset.gallery = "broken";
    } finally {
      if (mine === asking) {
        loading = false;
        more.disabled = false;
      }
    }
  }

  /// Ask again from the first page, with the address saying what was asked.
  function ask() {
    page = 0;
    auto = 0;
    history.replaceState(null, "", addressOf());
    sayFilters();
    drawTabs();
    drawShelves();
    sayScore();
    document.documentElement.dataset.gallery = "asking";
    return next(true);
  }

  /// The next page by itself as the end of the list nears the screen, the
  /// first three times; then Show more stays for a person to press.
  function nearEnd() {
    if (loading || !hasMore || more.hidden || auto >= AUTO) return;
    const box = more.getBoundingClientRect();
    if (box.top > innerHeight + 600) return;
    auto += 1;
    document.documentElement.dataset.auto = String(auto);
    next(false).then(nearEnd);
  }

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
      return;
    }
    // A card opened (its page, or its designer's): kept, so Back puts it
    // where it was.
    const link = event.target.closest("a[href]");
    const opened = link && link.closest(".model");
    if (opened && ID.test(String(opened.dataset.id))) {
      history.replaceState({ card: opened.dataset.id, top: Math.round(opened.getBoundingClientRect().top) }, "", addressOf());
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
  // How many pages the address shows: asked again, in order.
  const pages = Math.min(Math.max(Number.parseInt(given.get("page") || "1", 10) || 1, 1), 20);
  // Where the card opened last was, for Back.
  const back = history.state && ID.test(String(history.state.card)) ? history.state : null;
  if ("scrollRestoration" in history) history.scrollRestoration = "manual";

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
  more.addEventListener("click", () => next(false));
  addEventListener("scroll", nearEnd, { passive: true });
  addEventListener("resize", nearEnd, { passive: true });
  sayFilters();
  drawTabs();

  // Signed in or not, before the first question: a module of the site's,
  // asked for only when this browser keeps a sign-in. Then the pages the
  // address shows, and the card Back came to, where it was.
  (async () => {
    try {
      const account = await import("/account.js");
      if (account.signedIn()) own = account;
    } catch {
      own = null;
    }
    drawTabs();
    const shelvesAsked = askShelves({ draw: false });
    await next(true, shelvesAsked);
    while (page < pages && hasMore) await next(false);
    auto = Math.min(AUTO, page - 1);
    if (back) {
      // The pick and the shelves move the cards after them: drawn first.
      if (atFront()) await shelvesAsked;
      const card = document.querySelector(`#feed .model[data-id="${back.card}"]`);
      // At once, not the page's smooth scroll (site.css), which a person
      // coming back would watch run down the list.
      if (card) scrollTo({ top: Math.max(0, scrollY + card.getBoundingClientRect().top - (Number(back.top) || 0)), behavior: "instant" });
      document.documentElement.dataset.back = card ? back.card : "lost";
    }
    nearEnd();
  })();
})();
