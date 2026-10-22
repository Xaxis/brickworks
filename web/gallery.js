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
// The front of it, with nothing searched or filtered, has two shelves
// first (/api/share?op=shelves, supabase/discovery.sql): this week's pick,
// worked out from the past seven days' builds, remixes and Tested marks
// unless the site's owner chose one, and small builds, the Size filter's
// Small by Top builds, with a way to all of them. Top builds says how it
// weighs them, from the numbers the list sends (score).
//
// Signed in (web/account.js has a sign-in kept in this browser), the list
// and the shelves are asked with mine=1 and the sign-in: each card says how
// much of it the person's collection holds, by part and colour; the front
// has what they can build now, every part theirs; and Sort has Parts I own.
// Their own, so never kept by the CDN. Signed out, none of it is asked.
//
// Names, credits and tags were typed by strangers, so every one goes on
// the page as text (textContent), never as markup; a link is built from
// the model's id alone, and only an id that is one. Same origin
// throughout: the site's content security policy lets a page talk to
// itself and a short list of others.
//
// Each card is web/card.js's, the one every page of the site draws.
import { counted, modelCard as card } from "/card.js";

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
  const tested = $("tested");
  const shelves = $("shelves");
  let page = 0;
  // What the front's shelves are, once asked: null until then.
  let front = null;
  let weights = null;
  // The site's sign-in (web/account.js) while this browser has one: the
  // list and the shelves are then asked with it, and mine=1.
  let own = null;
  let asking = 0;
  let tag = "";
  let filled = false;
  // A probe's own models are tests, which the list leaves out unless asked
  // (api/share.js): an address with tests=1 asks, and keeps asking.
  const tests = new URLSearchParams(location.search).get("tests") === "1";

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

  /// The shelves, drawn from [front]: shown only on the gallery's front,
  /// nothing searched and nothing filtered.
  function drawShelves() {
    const searching = [...question().keys()].some((key) => key !== "sort" && key !== "tests");
    const pick = front && front.pick && front.pick.model && ID.test(String(front.pick.model.id)) ? front.pick : null;
    const small = front && front.small ? (front.small.models || []).filter((m) => m && ID.test(String(m.id))) : [];
    $("pick").hidden = !pick;
    const holder = $("pick-card");
    holder.replaceChildren();
    if (pick) {
      const made = card(pick.model);
      made.classList.add("pick-card");
      const why = document.createElement("p");
      why.className = "why";
      why.textContent = whyPicked(pick);
      made.querySelector(".words").append(why);
      made.dataset.chosen = pick.chosen ? "yes" : "no";
      holder.append(made);
    }
    $("small").hidden = small.length === 0;
    const row = $("small-models");
    row.replaceChildren(...small.map(card));
    $("small-all").hidden = !(front && front.small && front.small.more);
    // What they can build now: signed in, every part in their collection.
    const signedIn = Boolean(front && "mine" in front);
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
        + "Parts I own, under Sort, shows what is closest.";
    } else {
      said.textContent = `Every part of these is in your collection of ${counted(pool.pieces, "part")}: the most `
        + "built and remixed first.";
    }
    if (pool && pool.unknown) {
      said.textContent += ` ${counted(pool.unknown, "set")} of yours ${pool.unknown === 1 ? "has" : "have"} no `
        + "parts list here, so what is in them is not counted.";
    }
    shelves.hidden = searching || (!pick && small.length === 0 && !signedIn);
    $("all-h").hidden = shelves.hidden;
  }

  /// How Top builds weighs, said under the order while it is chosen.
  function sayScore() {
    const line = $("score-said");
    const w = weights;
    line.hidden = !(w && chosen(sort) === "top");
    if (w) {
      line.textContent = `Top builds: a build finished counts ${w.builds}, a remix ${w.remixes} and the `
        + `Tested mark ${w.tested}. Views count for nothing.`;
    }
  }

  /// This month's challenge, in one line under the page's heading: the one
  /// open now, or the next to open (supabase/challenges.sql).
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
  async function askShelves() {
    try {
      const reply = await askApi(`/api/share?op=shelves${tests ? "&tests=1" : ""}`);
      if (reply.status !== 200) throw new Error(String(reply.status));
      front = reply.body;
      if (front.score) weights = front.score;
    } catch {
      front = null;
    }
    drawShelves();
    sayScore();
    sayChallenge();
    document.documentElement.dataset.shelves = front ? "ready" : "broken";
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
    if (tested.checked) asked.set("tested", "1");
    if (tag) asked.set("tag", tag);
    if (chosen(sort) && chosen(sort) !== "newest") asked.set("sort", chosen(sort));
    if (tests) asked.set("tests", "1");
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
    if (tested.checked) said.push("Tested");
    $("filters-said").textContent = said.join(", ");
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
  }

  async function next(fresh) {
    const mine = ++asking;
    more.disabled = true;
    const asked = question();
    asked.set("page", String(fresh ? 1 : page + 1));
    try {
      const reply = await askApi(`/api/share?op=list&${asked}`);
      // An address that asks what the list does not know (a kind that is
      // not one, say, or Parts I own signed out): the whole gallery
      // instead, and the address put right.
      if ((reply.status === 400 || reply.status === 401) && !filled && [...question().keys()].length) {
        for (const select of [kind, size, sort]) select.dataset.wanted = "";
        q.value = "";
        instructions.checked = technic.checked = tested.checked = false;
        tag = "";
        history.replaceState(null, "", tests ? "/gallery?tests=1" : "/gallery");
        return next(true);
      }
      if (reply.status !== 200) throw new Error(String(reply.status));
      const data = reply.body;
      if (mine !== asking) return;
      if (!filled) {
        fill(kind, data.kinds);
        fill(size, data.sizes);
        fill(sort, data.sorts);
        filled = true;
        sayFilters();
      }
      if (data.score) weights = data.score;
      sayScore();
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
    drawShelves();
    sayScore();
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
  tested.checked = given.get("tested") === "1";
  tag = (given.get("tag") || "").slice(0, 24);
  // Open on a screen with room for them, folded on a phone.
  if (window.matchMedia && window.matchMedia("(min-width: 760px)").matches) $("filters").open = true;
  if (given.get("kind") || given.get("size") || instructions.checked || technic.checked || tested.checked) {
    $("filters").open = true;
  }

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
  for (const control of [kind, size, sort, instructions, technic, tested]) control.addEventListener("change", ask);
  $("clear").addEventListener("click", () => {
    q.value = "";
    kind.value = "";
    size.value = "";
    instructions.checked = false;
    technic.checked = false;
    tested.checked = false;
    tag = "";
    ask();
  });
  more.addEventListener("click", () => next(false));
  sayFilters();
  // Signed in or not, before the first question: a module of the site's,
  // asked for only when this browser keeps a sign-in.
  (async () => {
    try {
      const account = await import("/account.js");
      if (account.signedIn()) own = account;
    } catch {
      own = null;
    }
    next(true);
    askShelves();
  })();
})();
