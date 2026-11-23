// This month's challenge, /challenge (challenge.html, supabase/challenges.sql),
// laid out as the best contest pages are (challengepage, 2026-11-13): a head
// with the theme, its status and a live countdown, its numbers, the rules as
// checks and one way in, Enter; the winners first once it ends; the entries
// as the gallery's cards, the two groups (built by hand, with the assistant)
// as tabs with their counts, each sorted and paged as every list of the site
// is (web/pager.js, the address saying each group's own page: ?hand-page=2,
// ?assistant-page=3; ?group= the tab, ?sort= the order); how it works; the
// next one told, and the challenges that ran as cards to their own pages
// (?id=N draws one of those as this one is). From /api/people?op=challenge.
//
// Signed in (web/account.js), each entry you may vote for has Vote on its
// card: one vote in each group, never for your own, for people 13 and over,
// asked once more before it counts, since it cannot be moved. Your own entry
// and your vote are marked on their cards. Enter opens a dialog of your
// models in the gallery (op=me), and enters the one chosen as a model's page
// does (op=enter), the server checking the rules; signed out, it asks you to
// sign in first.
//
// Judges and a fan vote (challengehonours): a challenge in rounds (c.rounds)
// takes entries to entries_until, then Brickworks or the guest judge named
// in the head (#judge) chooses a shortlist of up to five in each group,
// then everyone votes once in each group for the shortlist alone from
// votes_from. The head's badge, eyebrow and countdown follow the round, its
// days are listed under the countdown (#rounds), Enter is there only while
// entries come in, and a shortlisted card says so and leads its group.
//
// Two at a time (?pair=hand, ?pair=assistant; challengestudio, 2026-11-23):
// while votes may be cast, a group of two or more entries one may vote for
// is also shown as a pair side by side (one above the other on a phone),
// each turning in its own blind embed (/m/<id>/embed?blind=1&autoplay=1,
// api/share.js), with its name alone: no maker, no counts, no cards, on the
// whole page, so the choice is the models'. "This one" keeps the one liked
// more and brings the next beside it, until every entry has been seen;
// then Vote for it, asked once more as every vote is. A link over the
// cards opens it ("Compare them two at a time, in 3D"); See every entry
// goes back.
//
// Names and credits were typed by strangers, so every one goes on the page
// as text, never as markup; a link is built from a model's id alone. Its
// words are the page's language's (web/de/challenge.html and the others,
// tools/site_lang.py): the rules said from the rules themselves, each day
// as the language writes it, and what the server says through told().
import { askToSignIn, call, signedIn } from "/account.js";
import { brokenSaid, counted, iconHtml, langAt, modelCard, mosaicHtml, number, rulesSaid, say, told } from "/card.js";
import { PAGE_SIZE, pageAsked, pager } from "/pager.js";
import { openShare, sheetFor } from "/share-sheet.js";
import { startTabs } from "/tabs.js";

const $ = (id) => document.getElementById(id);

// Its parts as tabs (pagekit, web/tabs.js): each tab shown once a part of
// its panel is (the winners and the entries, how it works and what comes
// next, the past ones), as what follows shows and hides those parts. The
// tabs and their panels come in only with their first tab (the page has
// them hidden): shown empty while the challenge was asked for, they were
// pushed down the page as its head came in, 0.25 of the screen moved at
// 1280 (checkdrift, 2026-11-23).
const partTabs = startTabs($("page-tabs"));
const panels = document.querySelector("main .obj-panels");
function syncTabs() {
  let any = false;
  for (const tab of document.querySelectorAll('#page-tabs [role="tab"]')) {
    const panel = $(tab.getAttribute("aria-controls"));
    const empty = ![...(panel?.children || [])].some((one) => one.matches("section") && !one.hidden);
    if (tab.hidden !== empty) tab.hidden = empty;
    any ||= !empty;
  }
  if (panels && panels.hidden === any) panels.hidden = !any;
  partTabs?.refresh();
}
if (panels) new MutationObserver(syncTabs).observe(panels, { subtree: true, attributes: true, attributeFilter: ["hidden"] });
const root = document.documentElement;
const ID = /^[A-Za-z0-9]{10}$/;
const WAYS = ["hand", "assistant"];
const params = new URLSearchParams(location.search);
const tests = params.get("tests") === "1";
// One challenge of the past (or the next) by its number, else the one shown now.
const asked = /^[1-9][0-9]{0,15}$/.test(params.get("id") || "") ? params.get("id") : null;
const pageOf = (id) => `${langAt()}/challenge?id=${id}${tests ? "&tests=1" : ""}`;
const LOCALE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "en-GB";
const DAY = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const SHORT = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", timeZone: "UTC" });
/// A day's first moment, and the moment after its last: a challenge's days
/// are whole days in UTC, the last one included (challenges.sql challenge_today).
const startOf = (iso) => Date.parse(`${String(iso).slice(0, 10)}T00:00:00Z`);
const endOf = (iso) => startOf(iso) + 86400000;
const dayOf = (iso) => DAY.format(startOf(iso));
/// A challenge's days, said once each in the page's language: "1–30
/// November 2026", "28. September – 4. Oktober 2026".
const daysOf = (from, to) => DAY.formatRange(startOf(from), startOf(to));
/// A group's name, by its way (api/_challenges.js WAYS).
const wayName = (way) => (way === "assistant" ? say("Built with the assistant") : say("Built by hand"));
const all = (c) => (c.groups || []).flatMap((one) => (one.entries || []).filter((entry) => ID.test(String(entry.id))));
/// Where challenge [c] is: its state, or for one open in rounds its round
/// (entries, judging, vote).
const roundOf = (c) => (c.state === "open" && c.rounds ? c.round || "entries" : c.state);
/// Whether entries come in now, and whether votes may be cast now.
const entering = (c) => c.state === "open" && (!c.rounds || roundOf(c) === "entries");
const voting = (c) => c.state === "open" && (!c.rounds || roundOf(c) === "vote");
/// Whether [entry] may be voted for in [c]: in rounds, the shortlist alone.
const votable = (c, entry) => voting(c) && (!c.rounds || entry.shortlisted === true);

let state = null;
// The tab shown and the order, from the address until a press changes them.
let group = WAYS.includes(params.get("group")) ? params.get("group") : null;
let sort = ["newest", "oldest", "votes"].includes(params.get("sort")) ? params.get("sort") : null;
// The group shown two at a time, while it may be (pairable), from the address.
let pairWay = WAYS.includes(params.get("pair")) ? params.get("pair") : null;
// Each group's pair as it stands, by its way: the order the entries come
// in (orderSalt), the one kept, the one beside it, and how many have been seen.
const pairs = new Map();
// This browser's own order of the entries two at a time: each id hashed
// with a word kept here, made once, so no entry is always first for
// everybody and a reload shows the same pair. Start again makes a new one.
const ORDER_KEY = "brickworks.pair_order";
function orderSalt(fresh = false) {
  let kept = "";
  try { kept = fresh ? "" : localStorage.getItem(ORDER_KEY) || ""; } catch { /* storage refused: one a load */ }
  if (!kept) {
    kept = Math.random().toString(36).slice(2, 10);
    try { localStorage.setItem(ORDER_KEY, kept); } catch { /* as above */ }
  }
  return kept;
}
/// FNV-1a of [text]: an order that is the same for the same words.
const hashOf = (text) => {
  let hash = 2166136261;
  for (const ch of text) hash = Math.imul(hash ^ ch.codePointAt(0), 16777619);
  return hash >>> 0;
};
// Each group's pager, by its way: stopped and made again as the groups are
// drawn again (after a vote), showing the pages it showed.
const pagers = new Map();
let ticking = 0;

const tell = (text) => { $("said").textContent = text; };
/// One of the sprite's icons as an element (web/card.js iconHtml).
const iconHtmlNode = (name) => {
  const holder = document.createElement("template");
  holder.innerHTML = iconHtml(name);
  return holder.content.firstElementChild;
};
/// [into] with [words] (said) in it, each {name} in them the node
/// [parts][name]: a name a stranger typed goes in as text, where the
/// language puts it.
function sayInto(into, words, parts) {
  for (const piece of words.split(/(\{\w+\})/)) {
    const name = /^\{(\w+)\}$/.exec(piece)?.[1];
    if (piece) into.append(name && parts[name] ? parts[name] : piece);
  }
  return into;
}
const el = (name, className = "", text = "") => {
  const made = document.createElement(name);
  if (className) made.className = className;
  if (text) made.textContent = text;
  return made;
};

/// The address with [changes] in it (null takes one out), kept without a reload.
function address(changes) {
  const at = new URL(location.href);
  for (const [name, value] of Object.entries(changes)) {
    if (value === null) at.searchParams.delete(name);
    else at.searchParams.set(name, value);
  }
  history.replaceState(history.state, "", at.pathname + at.search + at.hash);
}

// ---------------------------------------------------------------------------
// The head: status, countdown, numbers, the way in.

/// The countdown to [target]: days, hours, minutes and seconds, each in its
/// box, and the whole said once to a screen reader in its label, in
/// [words](time). At nought
/// the challenge is asked again: it opened, or it ended.
function countdown(target, words) {
  clearInterval(ticking);
  const box = $("countdown");
  const units = { days: [say("day"), say("days")], hours: [say("hour"), say("hours")], minutes: [say("min"), say("min")],
    seconds: [say("sec"), say("sec")] };
  const draw = () => {
    const left = Math.max(0, target - Date.now());
    const parts = { days: Math.floor(left / 86400000), hours: Math.floor(left / 3600000) % 24,
      minutes: Math.floor(left / 60000) % 60, seconds: Math.floor(left / 1000) % 60 };
    for (const [unit, n] of Object.entries(parts)) {
      const cell = box.querySelector(`[data-unit="${unit}"]`);
      cell.textContent = unit === "days" ? number(n) : String(n).padStart(2, "0");
      cell.nextElementSibling.textContent = units[unit][n === 1 ? 0 : 1];
    }
    const time = parts.days ? `${counted(parts.days, "day")}, ${counted(parts.hours, "hour")}`
      : `${counted(parts.hours, "hour")}, ${counted(parts.minutes, "minute")}`;
    box.setAttribute("aria-label", words(time));
    if (!left) {
      clearInterval(ticking);
      setTimeout(load, 1500);
    }
  };
  draw();
  box.hidden = false;
  ticking = setInterval(draw, 1000);
}

/// The numbers that matter, each hidden at none: entries, designers, and
/// once it ended the votes counted.
function numbers(c) {
  const entries = all(c);
  const designers = new Set(entries.map((one) => one.by?.handle || one.author || one.id)).size;
  const votes = entries.reduce((sum, one) => sum + (Number(one.votes) || 0), 0);
  const list = $("numbers");
  const items = [[entries.length, "entry", "entries", "entries"], [designers, "designer", "designers", "designers"],
    [c.state === "ended" ? votes : 0, "vote", "votes", "votes"]].filter(([n]) => n > 0).map(([n, one, many, what]) => {
    const item = el("li");
    item.dataset.number = what;
    item.append(el("b", "", number(n)), " ", el("span", "", say(n === 1 ? one : many)));
    return item;
  });
  if (!items.length && entering(c)) {
    const item = el("li");
    item.dataset.number = "none";
    item.append(el("span", "", say("No entries yet: be the first.")));
    items.push(item);
  }
  list.replaceChildren(...items);
  list.hidden = !items.length;
}

/// Who chooses the shortlist, in the head: the guest judge named, with a
/// link to their profile while it is shown, else Brickworks.
function drawJudge(c) {
  const line = $("judge");
  line.replaceChildren();
  line.hidden = !c.rounds;
  if (!c.rounds) return;
  const judge = c.judge?.name ? el(c.judge.handle ? "a" : "b", "", c.judge.name) : null;
  if (judge && c.judge.handle) judge.href = `${langAt()}/u/${encodeURIComponent(c.judge.handle)}`;
  if (judge) {
    sayInto(line, c.state === "ended" || c.shortlisted ? say("Shortlist chosen by guest judge {judge}")
      : say("Guest judge {judge} chooses the shortlist"), { judge });
  } else {
    line.textContent = c.state === "ended" || c.shortlisted ? say("Shortlist chosen by Brickworks") : say("Brickworks chooses the shortlist");
  }
}

/// The rounds under the countdown: entries, the judges' shortlist and the
/// fan vote, each with its days, the one it is in marked.
function drawRounds(c) {
  const list = $("rounds");
  list.hidden = !c.rounds;
  if (!c.rounds) return list.replaceChildren();
  const round = roundOf(c);
  const dayAfter = (iso) => new Date(startOf(iso) + 86400000).toISOString().slice(0, 10);
  const lastJudged = new Date(startOf(c.votes_from) - 86400000).toISOString().slice(0, 10);
  const steps = [
    ["entries", say("Entries"), daysOf(c.starts_on, c.entries_until)],
    ["judging", say("The judges’ shortlist"), c.shortlisted ? say("Out now") : dayAfter(c.entries_until) <= lastJudged
      ? daysOf(dayAfter(c.entries_until), lastJudged) : say("Before the fan vote")],
    ["vote", say("Fan vote"), daysOf(c.votes_from, c.ends_on)],
  ];
  list.replaceChildren(...steps.map(([step, name, when]) => {
    const item = el("li");
    item.dataset.round = step;
    if (step === round) item.setAttribute("aria-current", "step");
    item.append(el("b", "", name), el("span", "", when));
    return item;
  }));
}

function drawHead(c) {
  const open = c.state === "open";
  const ended = c.state === "ended";
  const round = roundOf(c);
  $("crumbs").hidden = !asked;
  $("crumb").textContent = c.title;
  const status = $("status");
  status.hidden = false;
  status.className = `badge ${open ? "good" : ended ? "" : "accent"}`.trim();
  status.textContent = round === "entries" && c.rounds ? say("Entries open") : round === "judging" ? say("Judging")
    : round === "vote" ? say("Fan vote") : open ? say("Open") : ended ? say("Ended") : say("Opens soon");
  $("eyebrow").textContent = open ? say("This month’s challenge") : c.state === "upcoming" ? say("The next challenge")
    : asked ? say("A past challenge") : say("The last challenge");
  $("title").textContent = c.title;
  document.title = say("{title} · a Brickworks challenge", { title: c.title });
  $("brief").textContent = c.brief;
  drawJudge(c);
  // Said from the rules themselves (web/card.js rulesSaid), as the model's
  // page says them, not as the server wrote them.
  const said = rulesSaid({ most_parts: c.rules?.most_parts, set_number: c.rules?.set?.number, set_name: c.rules?.set?.name,
    tested: c.rules?.tested });
  $("rules").replaceChildren(...said.map((text) => el("li", "", text)));
  $("rules").hidden = !said.length;
  $("no-rules").hidden = said.length > 0;
  $("rules-part").hidden = false;

  // The way in: Enter while entries come in; before it opens, the app.
  $("enter").hidden = !entering(c);
  $("enter-note").hidden = !entering(c);
  $("start").hidden = c.state !== "upcoming";
  $("to-hub").hidden = !asked;
  $("to-hub").href = `${langAt()}/challenge${tests ? "?tests=1" : ""}`;
  // Share: its own page, which stays this challenge's after the next opens.
  const at = { from: dayOf(c.starts_on), to: dayOf(c.ends_on) };
  $("share").hidden = false;
  $("share").onclick = () => openShare(sheetFor({ url: `${location.origin}${pageOf(c.id)}`, name: c.title,
    text: c.state === "upcoming" ? say("{title}: a Brickworks building challenge, opens {from}", { title: c.title, ...at })
      : say("{title}: a Brickworks building challenge, {from} to {to}", { title: c.title, ...at }),
    about: ended ? say("Its link opens this challenge: its brief, its entries and its winners.")
      : say("Its link opens this challenge: its brief, its rules and how to enter.") }));

  // Where it stands: a countdown to its end, or to its start, and how far
  // through its days it is; once ended, what came of it.
  clearInterval(ticking);
  $("countdown").hidden = true;
  $("clock-h").textContent = round === "entries" && c.rounds ? say("Entries close in") : round === "judging"
    ? (startOf(c.votes_from) > Date.now() ? say("Fan vote opens in") : say("The judges are choosing"))
    : round === "vote" ? say("Fan vote ends in") : open ? say("Ends in") : ended ? say("Final results") : say("Opens in");
  const days = daysOf(c.starts_on, c.ends_on);
  const reach = $("reach");
  reach.hidden = !open;
  drawRounds(c);
  if (open && c.rounds && round !== "vote") {
    const total = Math.round((endOf(c.ends_on) - startOf(c.starts_on)) / 86400000);
    const today = Math.min(total, Math.floor((Date.now() - startOf(c.starts_on)) / 86400000) + 1);
    $("days").textContent = say("{days} · day {day} of {total}", { days, day: number(today), total: number(total) });
    reach.firstElementChild.style.width = `${Math.max(2, Math.min(100, (today / total) * 100)).toFixed(1)}%`;
    if (round === "entries") countdown(endOf(c.entries_until), (time) => say("Entries close in {time}", { time }));
    else if (startOf(c.votes_from) > Date.now()) countdown(startOf(c.votes_from), (time) => say("Fan vote opens in {time}", { time }));
  } else if (open) {
    const total = Math.round((endOf(c.ends_on) - startOf(c.starts_on)) / 86400000);
    const today = Math.min(total, Math.floor((Date.now() - startOf(c.starts_on)) / 86400000) + 1);
    $("days").textContent = say("{days} · day {day} of {total}", { days, day: number(today), total: number(total) });
    reach.firstElementChild.style.width = `${Math.max(2, Math.min(100, (today / total) * 100)).toFixed(1)}%`;
    countdown(endOf(c.ends_on), (time) => (c.rounds ? say("Fan vote ends in {time}", { time }) : say("Ends in {time}", { time })));
  } else if (c.state === "upcoming") {
    $("days").textContent = days;
    countdown(startOf(c.starts_on), (time) => say("Opens in {time}", { time }));
  } else {
    $("days").textContent = say("Ran {days}", { days });
  }
  numbers(c);
}

// ---------------------------------------------------------------------------
// Entering: one of your models in the gallery, by hand or with the assistant.

async function enter() {
  if (!signedIn()) {
    if (!(await askToSignIn(say("Sign in to enter: we email you a code, no password.")))) return;
    await load();
    if (state?.challenge?.state !== "open") return;
  }
  const me = await call("/api/people?op=me").catch(() => null);
  enterDialog(state.challenge, me && me.status === 200 ? (me.body.showcase?.models || []).filter((one) => ID.test(String(one.id))) : null);
}

/// The dialog: your models in the gallery to choose from, how it was built,
/// and Enter it; the server checks the rules on the model as it is stored
/// and says which it breaks. [models] null: they did not come.
function enterDialog(c, models) {
  const dialog = el("dialog", "report enter-pick");
  const title = el("h2", "", say("Enter “{title}”", { title: c.title }));
  title.id = "enter-pick-title";
  dialog.setAttribute("aria-labelledby", title.id);
  const lede = el("p");
  const end = () => {
    dialog.close();
    dialog.remove();
  };
  const close = el("button", "cta ghost", say("Cancel"));
  close.type = "button";
  close.addEventListener("click", end);
  dialog.addEventListener("cancel", end);
  dialog.addEventListener("close", () => dialog.remove());
  const mine = state.you?.entries || [];
  const row = el("div", "actions");
  if (!models) {
    lede.textContent = say("Your models did not load just now. Try again in a minute.");
    row.append(close);
    dialog.append(title, lede, row);
  } else if (mine.length >= 3) {
    lede.textContent = say("You have three models in it already: that is the most.");
    row.append(close);
    dialog.append(title, lede, row);
  } else if (!models.length) {
    lede.textContent = say("You have no model in the gallery with your name on it yet. Build one in the app, share it with Show it in the gallery ticked, then enter it here.");
    const app = el("a", "cta", say("Open the app"));
    app.href = "/app";
    row.append(app, close);
    dialog.append(title, lede, row);
  } else {
    lede.textContent = say("Choose one of your models in the gallery. Brickworks checks the rules on it as you shared it.");
    const form = el("form");
    const picks = el("fieldset", "picks");
    picks.append(el("legend", "", say("Your models")));
    const list = el("div", "pick-list");
    for (const model of models) {
      const label = el("label", "pick");
      const input = el("input");
      Object.assign(input, { type: "radio", name: "model", value: model.id, required: true });
      const picture = el("span", "pic");
      if (model.picture) {
        const img = el("img");
        Object.assign(img, { src: `/m/${model.id}.png`, alt: "", width: 64, height: 48, loading: "lazy", decoding: "async" });
        picture.append(img);
      }
      const name = el("span", "name", model.name);
      label.append(input, picture, name);
      if (mine.includes(model.id)) {
        input.disabled = true;
        label.append(el("small", "", say("In it already")));
      }
      list.append(label);
    }
    picks.append(list);
    const ways = el("fieldset", "ways");
    ways.append(el("legend", "", say("How did you build it? The two are judged apart.")));
    for (const [value, words] of [["hand", say("By hand")], ["assistant", say("With the assistant")]]) {
      const choice = el("label", "choice");
      const input = el("input");
      Object.assign(input, { type: "radio", name: "way", value, required: true });
      choice.append(input, document.createTextNode(` ${words}`));
      ways.append(choice);
    }
    const status = el("div", "said");
    status.setAttribute("role", "status");
    const send = el("button", "cta", say("Enter it"));
    send.type = "submit";
    row.append(send, close);
    form.append(picks, ways, row, status);
    dialog.append(title, lede, form);
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const model = form.querySelector('input[name="model"]:checked')?.value;
      const way = form.querySelector('input[name="way"]:checked')?.value;
      if (!model || !way) return;
      send.disabled = true;
      status.textContent = say("Checking it against the rules…");
      const answer = await call("/api/people?op=enter", { method: "POST", body: { model, way } });
      send.disabled = false;
      if (answer.status !== 201) {
        status.replaceChildren();
        const broken = answer.body.check ? brokenSaid(answer.body.check)
          : (answer.body.broken || []).map((one) => ({ ...one, said: told(one.said) }));
        if (broken.length) {
          status.append(say("It does not keep the rules yet:"));
          const items = el("ul");
          for (const one of broken) {
            const item = el("li", "", one.said);
            item.dataset.rule = one.rule;
            items.append(item);
          }
          status.append(items);
        } else {
          status.textContent = told(answer.body.error, say("That did not go just now. Try again in a minute."));
        }
        root.dataset.challengeRefused = answer.body.refused || "error";
        return;
      }
      group = way;
      await load();
      const done = el("button", "cta", say("Close"));
      done.type = "button";
      done.addEventListener("click", end);
      form.remove();
      lede.textContent = c.rounds ? (way === "assistant"
        ? say("It is in, built with the assistant. Once entries close, the judges choose the shortlist that everyone votes for.")
        : say("It is in, built by hand. Once entries close, the judges choose the shortlist that everyone votes for."))
        : way === "assistant" ? say("It is in, built with the assistant. People signed in vote until the challenge ends.")
          : say("It is in, built by hand. People signed in vote until the challenge ends.");
      dialog.append(done);
      done.focus();
      root.dataset.challengeEntered = model;
    });
  }
  document.body.append(dialog);
  dialog.showModal();
}

// ---------------------------------------------------------------------------
// Voting: once in each group, asked once more since it cannot be moved.

/// Asks before a vote counts: resolves true to cast it.
function confirmVote(entry) {
  return new Promise((done) => {
    const dialog = el("dialog", "report vote-confirm");
    const title = el("h2", "", say("Vote for “{name}”?", { name: entry.name }));
    title.id = "vote-confirm-title";
    dialog.setAttribute("aria-labelledby", title.id);
    const lede = el("p", "", say(entry.way === "assistant"
      ? "You have one vote in Built with the assistant. Once cast it cannot be moved to another entry."
      : "You have one vote in Built by hand. Once cast it cannot be moved to another entry."));
    const row = el("div", "actions");
    const yes = el("button", "cta", say("Vote"));
    yes.type = "button";
    const no = el("button", "cta ghost", say("Cancel"));
    no.type = "button";
    row.append(yes, no);
    dialog.append(title, lede, row);
    let answered = false;
    const end = (cast) => {
      if (answered) return;
      answered = true;
      dialog.close();
      dialog.remove();
      done(cast);
    };
    yes.addEventListener("click", () => end(true));
    no.addEventListener("click", () => end(false));
    dialog.addEventListener("cancel", () => end(false));
    document.body.append(dialog);
    dialog.showModal();
    yes.focus();
  });
}

async function signInToVote() {
  // Signed in, brickworks:signed-in-done (below) draws the votes for them.
  await askToSignIn(say("Sign in to vote: we email you a code, no password."));
}

// Signed in here by any way (the header's Sign in too; signinux,
// 2026-11-14): the challenge drawn as it stands for them, their entries
// and votes, where they are.
addEventListener("brickworks:signed-in-done", () => load());

/// The vote, drawn at once and then as the server says: refused, it is
/// drawn back as it was and says why.
async function castVote(c, entry) {
  if (!(await confirmVote(entry))) return;
  const you = state.you;
  you.voted = { ...(you.voted || {}), [entry.way]: entry.id };
  drawVotes(c, entry.id);
  const answer = await call("/api/people?op=vote", { method: "POST", body: { challenge: c.id, model: entry.id } });
  if (answer.status !== 200) {
    you.voted = { ...you.voted, [entry.way]: answer.body?.model && answer.body.refused === "voted" ? answer.body.model : null };
    drawVotes(c);
    return tell(told(answer.body.error, say("That vote did not go just now. Try again in a minute.")));
  }
  tell(say(entry.way === "assistant" ? "Your vote is for “{name}”, built with the assistant." : "Your vote is for “{name}”, built by hand.",
    { name: entry.name }));
}

// ---------------------------------------------------------------------------
// The entries.

/// What an entry's card says under its name, for whoever is looking: its
/// marks (the winner, your vote, your entry), its votes once counted, and
/// Vote where you may.
function voteLine(c, entry) {
  const line = el("div", "vote-line");
  const you = state.you;
  const voted = you?.voted?.[entry.way];
  const badge = (className, words, icon = "") => {
    const made = el("span", `badge ${className}`.trim());
    if (icon) made.insertAdjacentHTML("afterbegin", iconHtml(icon));
    made.append(words);
    return made;
  };
  if (c.state === "ended") {
    if (entry.winner) line.append(badge("accent winner", say("Winner"), "award"));
    else if (entry.shortlisted) line.append(badge("shortlisted", say("Shortlisted"), "award"));
    // A count is said once there is one: never "0 votes".
    if (Number(entry.votes)) line.append(el("small", "votes", counted(entry.votes, "vote")));
    if (voted === entry.id) line.append(badge("voted", say("Your vote"), "check"));
    return line;
  }
  if (c.state !== "open") return line;
  if (entry.shortlisted && c.shortlisted) line.append(badge("accent shortlisted", say("Shortlisted"), "award"));
  if (!entry.keeps) line.append(el("small", "broken", say("No longer keeps the rules: a newer version broke one")));
  if ((you?.entries || []).includes(entry.id)) {
    line.append(badge("mine", say("Your entry")));
    return line;
  }
  if (voted === entry.id) {
    line.append(badge("accent voted", say("Your vote"), "check"));
    return line;
  }
  const may = !you || (you.may_vote && !voted);
  if (may && entry.keeps && votable(c, entry)) {
    const button = el("button", "cta ghost small vote");
    button.type = "button";
    button.insertAdjacentHTML("afterbegin", iconHtml("check"));
    button.append(say("Vote"));
    button.setAttribute("aria-label", say("Vote for “{name}”", { name: entry.name }));
    button.addEventListener("click", () => (you ? castVote(c, entry) : signInToVote()));
    line.append(button);
  }
  return line;
}

/// An entry's card, the gallery's own (web/card.js), with its vote line at
/// its foot. What it won in this challenge is said by its Winner mark, not
/// again among what it won.
function entryCard(c, entry) {
  const card = modelCard({ ...entry, won: (entry.won || []).filter((win) => win.challenge !== c.id) });
  card.dataset.entry = entry.id;
  card.dataset.way = entry.way || "";
  const line = voteLine(c, entry);
  if (line.childElementCount) card.querySelector(".words").append(line);
  if (line.querySelector(".voted")) card.classList.add("voted");
  if (line.querySelector(".mine")) card.classList.add("mine");
  if (entry.winner) card.classList.add("won");
  if (entry.shortlisted && (c.shortlisted || c.state === "ended")) card.classList.add("shortlisted");
  return card;
}

/// The order asked for, or the one that suits the challenge: the newest
/// first while it runs, the most voted once it ended.
function orderOf(c) {
  const ended = c.state === "ended";
  if (sort === "votes" && ended) return "votes";
  if (sort === "newest" || sort === "oldest") return sort;
  return ended ? "votes" : "newest";
}

/// [entries] in [order]; in a challenge whose shortlist is out
/// ([shortlisted]), the shortlist first.
function sorted(entries, order, shortlisted = false) {
  const at = (one) => Date.parse(one.entered_at || "") || 0;
  const listed = (one) => (shortlisted && one.shortlisted ? 0 : 1);
  return [...entries].sort((a, b) => listed(a) - listed(b) || (order === "votes" ? (Number(b.votes) || 0) - (Number(a.votes) || 0) || at(a) - at(b)
    : order === "oldest" ? at(a) - at(b) : at(b) - at(a)) || (a.id < b.id ? -1 : 1));
}

/// Which group to show: the one asked for, else the first with entries.
function groupOf(c) {
  const counts = Object.fromEntries((c.groups || []).map((one) => [one.way, (one.entries || []).length]));
  if (group && group in counts) return group;
  return WAYS.find((way) => counts[way] > 0) || "hand";
}

/// The line over the cards: what you may do in the group shown.
function voteSaid(c, way) {
  const line = $("vote-said");
  line.replaceChildren();
  const you = state.you;
  const voted = you?.voted?.[way];
  const entry = voted ? all(c).find((one) => one.id === voted) : null;
  if (c.state === "open" && c.rounds && roundOf(c) !== "vote") {
    line.textContent = roundOf(c) === "entries"
      ? say("Entries close on {close}. Then the judges choose up to five in each group, and from {vote} everyone votes for the shortlist.",
        { close: dayOf(c.entries_until), vote: dayOf(c.votes_from) })
      : c.shortlisted ? say("The judges have chosen their shortlist. The fan vote opens on {vote}.", { vote: dayOf(c.votes_from) })
        : say("Entries have closed, and the judges are choosing their shortlist. The fan vote opens on {vote}.", { vote: dayOf(c.votes_from) });
  } else if (c.state === "open") {
    if (!you) line.textContent = c.rounds ? say("The fan vote: everyone signed in and 13 or over has one vote in each group, for the shortlist. Votes stay hidden until it ends.")
      : say("Everyone signed in and 13 or over has one vote in each group. Votes stay hidden until it ends.");
    else if (entry) {
      // The words in a span of their own, beside the tick, one sentence.
      const said = el("span", "said");
      sayInto(said, say("Your vote in this group is for “{name}”. Votes stay hidden until it ends."), { name: el("b", "", entry.name) });
      line.append(iconHtmlNode("check"), said);
      line.classList.add("done");
    } else if (you.may_vote) line.textContent = say("You have one vote in this group. Votes stay hidden until it ends.");
  } else if (c.state === "ended" && orderOf(c) === "votes" && all(c).length) {
    line.textContent = say("The most voted first: the votes were counted when it ended.");
  }
  if (!entry) line.classList.remove("done");
  line.hidden = !line.textContent;
  // Two at a time, where the group has two to compare and no vote yet.
  const go = $("pair-go");
  go.hidden = !pairable(c, way) || Boolean(voted);
  $("pair-link").href = `${location.pathname}?${pairAddress(way)}`;
  $("pair-link").dataset.way = way;
}

// ---------------------------------------------------------------------------
// Two at a time.

/// The entries of group [way] one may vote for now, never one's own: the
/// ones a pair is made of.
function pairEntries(c, way) {
  const mine = state.you?.entries || [];
  return ((c.groups || []).find((one) => one.way === way)?.entries || [])
    .filter((entry) => ID.test(String(entry.id)) && entry.keeps && votable(c, entry) && !mine.includes(entry.id));
}

/// Whether group [way] of [c] may be shown two at a time: while votes are
/// cast, with two to compare.
const pairable = (c, way) => voting(c) && pairEntries(c, way).length >= 2;

/// The address of group [way] two at a time: this page's, with ?pair=.
function pairAddress(way) {
  const at = new URLSearchParams(location.search);
  for (const name of ["pair", "group", "sort", "hand-page", "assistant-page"]) at.delete(name);
  at.set("pair", way);
  return at.toString();
}

/// Group [way]'s pair as it stands, made when first asked: its entries in
/// this browser's order (orderSalt).
function pairOf(c, way) {
  const entries = pairEntries(c, way);
  let pair = pairs.get(way);
  const ids = entries.map((entry) => entry.id);
  if (!pair || pair.order.some((id) => !ids.includes(id)) || ids.some((id) => !pair.order.includes(id))) {
    const salt = orderSalt();
    const order = [...ids].sort((a, b) => hashOf(salt + a) - hashOf(salt + b) || (a < b ? -1 : 1));
    pair = { order, two: [order[0], order[1]], seen: 2, chosen: null };
    pairs.set(way, pair);
  }
  return { pair, byId: new Map(entries.map((entry) => [entry.id, entry])) };
}

/// One side of the pair: [entry] turning in its blind embed, its name, and
/// This one. [side] 0 or 1, the left (the top on a phone) or the right.
function pairSide(c, way, entry, side, done) {
  const box = el("figure", "pair-one");
  box.dataset.entry = entry.id;
  box.dataset.side = String(side);
  const frame = el("div", "pair-frame");
  const embed = el("iframe");
  embed.src = `${langAt()}/m/${entry.id}/embed?blind=1&autoplay=1`;
  embed.title = say("{name}, turning in 3D", { name: entry.name });
  embed.loading = "lazy";
  embed.setAttribute("allow", "fullscreen");
  frame.append(embed);
  const words = el("figcaption", "pair-words");
  words.append(el("b", "pair-name", entry.name));
  if (!done) {
    const keep = el("button", "cta small pair-keep", say("This one"));
    keep.type = "button";
    keep.setAttribute("aria-label", say("I like “{name}” more", { name: entry.name }));
    keep.addEventListener("click", () => keepOne(c, way, side));
    words.append(keep);
  }
  box.append(frame, words);
  return box;
}

/// [side] liked more: it stays, and the next entry not yet seen comes
/// beside it; with none left, it is the one chosen, to vote for.
function keepOne(c, way, side) {
  const { pair } = pairOf(c, way);
  const kept = pair.two[side];
  if (pair.seen < pair.order.length) {
    const next = pair.order[pair.seen];
    pair.seen += 1;
    pair.two = side === 0 ? [kept, next] : [next, kept];
    drawPair(c, side === 0 ? 1 : 0);
  } else {
    pair.chosen = kept;
    drawPair(c, -1);
  }
}

/// Group [pairWay] two at a time, in #pair over the tabs, in place of the
/// cards: nothing on the page names a maker or counts anything. [fresh]
/// the side just brought in (its This one takes the keyboard), -1 for the
/// one chosen (its Vote does).
function drawPair(c, fresh = null) {
  const way = pairWay;
  $("entries").hidden = false;
  $("sort").hidden = true;
  $("groups").replaceChildren();
  $("groups").hidden = true;
  $("vote-said").hidden = true;
  $("pair-go").hidden = true;
  for (const one of pagers.values()) one.stop();
  pagers.clear();
  const tabs = $("group-tabs");
  const both = (c.groups || []).filter((one) => pairable(c, one.way));
  tabs.replaceChildren(...both.map((one) => {
    const tab = el("button");
    Object.assign(tab, { type: "button", id: `tab-${one.way}` });
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-selected", String(one.way === way));
    tab.setAttribute("aria-controls", "pair");
    tab.tabIndex = one.way === way ? 0 : -1;
    tab.dataset.way = one.way;
    tab.append(wayName(one.way));
    tab.addEventListener("click", () => choose(c, one.way));
    return tab;
  }));
  tabs.hidden = both.length < 2;
  $("pair").setAttribute("aria-labelledby", `tab-${way}`);
  $("pair").hidden = false;
  $("pair-back").href = `${location.pathname}?${(() => {
    const at = new URLSearchParams(location.search);
    at.delete("pair");
    if (way !== "hand") at.set("group", way);
    return at.toString();
  })()}`.replace(/\?$/, "");
  const { pair, byId } = pairOf(c, way);
  const voted = state.you?.voted?.[way];
  const said = $("pair-said");
  const two = $("pair-two");
  if (voted) {
    // A vote cast here, or before: said, and nothing more to choose.
    const entry = all(c).find((one) => one.id === voted);
    said.replaceChildren();
    sayInto(said, say("Your vote in this group is for “{name}”. Votes stay hidden until it ends."),
      { name: el("b", "", entry ? entry.name : "") });
    two.replaceChildren(...(byId.get(voted) ? [pairSide(c, way, byId.get(voted), 0, true)] : []));
    two.dataset.state = "voted";
    $("pair-vote").hidden = true;
    return;
  }
  if (pair.chosen) {
    const entry = byId.get(pair.chosen);
    said.replaceChildren();
    sayInto(said, say("Of all {n} you like “{name}” most."), { n: number(pair.order.length), name: el("b", "", entry.name) });
    two.replaceChildren(pairSide(c, way, entry, 0, true));
    two.dataset.state = "chosen";
    const vote = $("pair-vote");
    vote.hidden = false;
    vote.textContent = say("Vote for “{name}”", { name: entry.name });
    vote.onclick = () => (state.you ? (state.you.may_vote ? castVote(c, { ...entry, way }) : tell(told(state.you.why_not,
      say("You cannot vote in this challenge.")))) : signInToVote());
    $("pair-again").hidden = false;
    if (fresh === -1) vote.focus({ preventScroll: true });
    return;
  }
  said.textContent = say("{seen} of {n}: press This one under the one you like more. It stays, and the next comes beside it.",
    { seen: number(pair.seen), n: number(pair.order.length) });
  two.dataset.state = "choosing";
  $("pair-vote").hidden = true;
  $("pair-again").hidden = pair.seen <= 2;
  // The side that stays is left in the page as it is, turning where it
  // was (a frame taken out and put back would load again); only the new
  // one is drawn.
  const now = [...two.querySelectorAll(".pair-one")];
  if (fresh !== null && fresh >= 0 && now.length === 2 && now[1 - fresh].dataset.entry === pair.two[1 - fresh]) {
    const made = pairSide(c, way, byId.get(pair.two[fresh]), fresh, false);
    now[fresh].replaceWith(made);
    made.querySelector(".pair-keep")?.focus({ preventScroll: true });
  } else {
    two.replaceChildren(...pair.two.map((id, side) => pairSide(c, way, byId.get(id), side, false)));
  }
}

/// Group [way]'s pair from the start, in a new order.
function pairAgain(c) {
  orderSalt(true);
  pairs.delete(pairWay);
  drawPair(c);
}

/// The entries drawn again after a vote: two at a time, or as cards.
function drawVotes(c, focus = "") {
  if (pairWay) drawPair(c);
  else drawEntries(c, focus);
}

/// The tabs, the sort, the line over the cards and both groups, each with
/// its pager, the one chosen shown. [focus]: an entry whose card takes the
/// keyboard after.
function drawEntries(c, focus = "") {
  const way = groupOf(c);
  const order = orderOf(c);
  const shown = new Map([...pagers].map(([one, paged]) => [one, { first: paged.state.first, last: paged.state.last }]));
  for (const one of pagers.values()) one.stop();
  pagers.clear();
  $("entries").hidden = false;
  $("pair").hidden = true;
  $("groups").hidden = false;
  $("group-tabs").hidden = false;

  // The two groups as tabs, each with its count (none said at nought).
  const tabs = $("group-tabs");
  const focused = tabs.contains(document.activeElement);
  tabs.replaceChildren(...(c.groups || []).map((one) => {
    const tab = el("button");
    Object.assign(tab, { type: "button", id: `tab-${one.way}` });
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-selected", String(one.way === way));
    tab.setAttribute("aria-controls", `group-${one.way}`);
    tab.tabIndex = one.way === way ? 0 : -1;
    tab.dataset.way = one.way;
    tab.append(wayName(one.way));
    const n = (one.entries || []).length;
    if (n) tab.append(" ", el("span", "n", number(n)));
    tab.addEventListener("click", () => choose(c, one.way));
    return tab;
  }));
  if (focused) tabs.querySelector('[aria-selected="true"]')?.focus();

  // The order: the newest or the oldest first while it runs, the most
  // voted or the newest once it ended; only where there are two to order.
  const sorts = c.state === "ended" ? [["votes", say("Most votes")], ["newest", say("Newest")]]
    : [["newest", say("Newest")], ["oldest", say("Oldest")]];
  const sortBox = $("sort");
  sortBox.replaceChildren(...sorts.map(([value, words]) => {
    const button = el("button", "", words);
    button.type = "button";
    button.dataset.sort = value;
    button.setAttribute("aria-pressed", String(value === order));
    button.addEventListener("click", () => {
      if (value === order) return;
      sort = value;
      address({ sort: value === (c.state === "ended" ? "votes" : "newest") ? null : value, "hand-page": null, "assistant-page": null });
      pagers.clear();
      drawEntries(c);
      $("sort").querySelector(`[data-sort="${value}"]`)?.focus();
    });
    return button;
  }));
  sortBox.hidden = all(c).length < 2 || c.state === "upcoming";

  voteSaid(c, way);
  const groups = $("groups");
  groups.replaceChildren();
  // Why this account has no Vote, said once over the entries.
  if (voting(c) && state.you?.why_not && !state.you.may_vote) {
    groups.append(el("p", "callout why-not", told(state.you.why_not)));
  }
  for (const one of c.groups || []) {
    const panel = el("div", "group");
    panel.id = `group-${one.way}`;
    panel.dataset.way = one.way;
    panel.setAttribute("role", "tabpanel");
    panel.setAttribute("aria-labelledby", `tab-${one.way}`);
    panel.hidden = one.way !== way;
    groups.append(panel);
    const entries = sorted((one.entries || []).filter((entry) => ID.test(String(entry.id))), order,
      c.rounds && (c.shortlisted || c.state === "ended"));
    if (!entries.length) {
      const empty = el("div", "state");
      empty.append(el("p", "", c.state === "upcoming" ? say("Entries open with the challenge, on {day}.", { day: dayOf(c.starts_on) })
        : c.state === "ended" ? say("Nobody entered in this group.")
          : entering(c) ? say("Nobody has entered in this group yet. Be the first.") : say("Nobody entered in this group.")));
      if (entering(c)) {
        const go = el("button", "cta ghost small", say("Enter a model"));
        go.type = "button";
        go.addEventListener("click", enter);
        empty.append(go);
      }
      panel.append(empty);
      continue;
    }
    const grid = el("div", "models entries");
    grid.id = `entries-${one.way}`;
    panel.append(grid);
    // Both groups drawn, the one not chosen in its hidden panel: a tab
    // shows it at once, and a find in the page or a reader of the page's
    // HTML meets every entry.
    const param = `${one.way}-page`;
    const paged = pager({ list: grid, param, noun: ["entry", "entries"], key: (item) => item.dataset.entry || "",
      load: async (page) => ({ items: entries.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE).map((entry) => entryCard(c, entry)),
        total: entries.length, pages: Math.max(1, Math.ceil(entries.length / PAGE_SIZE)) }) });
    pagers.set(one.way, paged);
    const was = shown.get(one.way);
    paged.start(was && was.last ? was.last : pageAsked(location.search, param), was && was.last ? { from: was.first, restore: false } : {})
      .then(() => {
        if (focus) grid.querySelector(`[data-entry="${CSS.escape(focus)}"] a.open`)?.focus({ preventScroll: true });
      });
  }
}

/// Shows group [way]: its tab chosen and its panel, both already drawn.
function choose(c, way) {
  if (pairWay) {
    group = way;
    pairWay = way;
    address({ pair: way, group: way === "hand" ? null : way });
    drawPair(c);
    $(`tab-${way}`)?.focus();
    return;
  }
  group = way;
  address({ group: way === "hand" ? null : way });
  for (const tab of $("group-tabs").querySelectorAll('[role="tab"]')) {
    const chosen = tab.dataset.way === way;
    tab.setAttribute("aria-selected", String(chosen));
    tab.tabIndex = chosen ? 0 : -1;
  }
  for (const panel of $("groups").querySelectorAll(".group")) panel.hidden = panel.dataset.way !== way;
  voteSaid(c, way);
  $(`tab-${way}`)?.focus();
}

// The tabs by the keyboard, as a tab list is: the arrows, Home and End.
$("group-tabs").addEventListener("keydown", (event) => {
  const tabs = [...$("group-tabs").querySelectorAll('[role="tab"]')];
  const at = tabs.indexOf(document.activeElement);
  if (at < 0 || !state?.challenge) return;
  const to = { ArrowRight: at + 1, ArrowLeft: at - 1, Home: 0, End: tabs.length - 1 }[event.key];
  if (to === undefined) return;
  event.preventDefault();
  choose(state.challenge, tabs[(to + tabs.length) % tabs.length].dataset.way);
});

// ---------------------------------------------------------------------------
// The winners, the next one and the ones that ran.

/// The winners once it ended and was counted: one in each group, each its
/// card under what it won, lit in the accent.
function drawWinners(c) {
  const section = $("winners");
  section.hidden = c.state !== "ended";
  if (section.hidden) return;
  const entries = new Map(all(c).map((one) => [`${one.way}/${one.id}`, one]));
  const won = (c.winners || []).map((w) => ({ w, entry: entries.get(`${w.way}/${w.model}`) })).filter((x) => x.entry);
  if (!won.length) {
    $("winner-cards").replaceChildren(el("p", "state", all(c).length ? say("Nobody won: no entry had a vote.") : say("Nobody entered.")));
    return;
  }
  $("winner-cards").replaceChildren(...won.map(({ w, entry }) => {
    const box = el("div", "winner");
    box.dataset.way = w.way;
    box.dataset.entry = entry.id;
    const head = el("p", "winner-h");
    const glyph = el("span", "glyph");
    glyph.insertAdjacentHTML("afterbegin", iconHtml("award"));
    const words = el("span", "words");
    words.append(el("b", "", say(w.way === "assistant" ? "Winner, built with the assistant" : "Winner, built by hand")));
    if (Number(w.votes)) words.append(el("small", "", counted(w.votes, "vote")));
    head.append(glyph, words);
    const card = modelCard({ ...entry, won: [] });
    card.dataset.entry = entry.id;
    box.append(head, card);
    return box;
  }));
}

/// The next challenge told, under the one shown: its theme and its days.
function drawNext(next) {
  $("next").hidden = !next;
  if (!next) return;
  $("next").dataset.next = String(next.id);
  $("next-when").textContent = say("Opens {day}", { day: SHORT.format(startOf(next.starts_on)) });
  $("next-title").textContent = next.title;
  $("next-days").textContent = say("Opens on {from}, until {to}", { from: dayOf(next.starts_on), to: dayOf(next.ends_on) });
  $("next-brief").textContent = next.brief;
}

/// The challenges that ran, the last first, each a card to its own page:
/// its winners' pictures, its name, its days and how many entered, and who won.
function drawPast(past) {
  $("past").hidden = !past.length;
  $("past-list").replaceChildren(...past.map((one) => {
    const item = el("article", "model past-card");
    item.dataset.past = String(one.id);
    const won = (one.winners || []).filter((w) => ID.test(String(w.id)));
    const frame = el("div", "frame");
    const pictures = won.filter((w) => w.image).map((w) => `/m/${w.id}.png`).slice(0, 4);
    if (pictures.length) frame.innerHTML = mosaicHtml(pictures);
    else {
      frame.classList.add("none");
      frame.insertAdjacentHTML("afterbegin", iconHtml("award"));
    }
    const words = el("div", "words");
    const head = el("h3");
    const link = el("a", "open", one.title);
    link.href = pageOf(one.id);
    head.append(link);
    const days = el("p", "note", `${daysOf(one.starts_on, one.ends_on)}${one.entries ? ` · ${counted(one.entries, "entry", "entries")}` : ""}`);
    words.append(head, days);
    const who = el("p", "past-won");
    if (won.length) {
      for (const w of won) {
        const line = el("span");
        line.dataset.entry = w.id;
        // The words in a span of their own: the line lays the award and
        // them side by side, and the words run on as one sentence.
        const said = el("span", "said");
        sayInto(said, say(w.way === "assistant" ? "“{name}” by {who}, with the assistant" : "“{name}” by {who}, by hand"),
          { name: el("b", "", w.name), who: el("span", "who", w.by?.name || w.author || say("a designer")) });
        line.append(iconHtmlNode("award"), said);
        who.append(line);
      }
    } else {
      who.textContent = one.entries ? say("Nobody won: no entry had a vote.") : say("Nobody entered.");
    }
    words.append(who);
    item.append(frame, words);
    return item;
  }));
}

// ---------------------------------------------------------------------------

/// What is said when there is no challenge to show: [kind] none, gone or broken.
function drawEmpty(kind) {
  clearInterval(ticking);
  $("status").hidden = true;
  $("countdown").hidden = true;
  $("reach").hidden = true;
  $("numbers").hidden = true;
  $("rules-part").hidden = true;
  for (const id of ["enter", "enter-note", "share"]) $(id).hidden = true;
  $("brief").replaceChildren();
  $("days").replaceChildren();
  $("start").hidden = kind !== "none";
  $("to-hub").hidden = kind !== "gone";
  $("to-hub").href = `${langAt()}/challenge${tests ? "?tests=1" : ""}`;
  $("clock").hidden = true;
  root.dataset.clock = "none";
  if (kind === "none") {
    $("title").textContent = say("No challenge just now");
    $("brief").textContent = say("A new theme is set here every month. Until the next one, build something in the app, or look back at the challenges that ran.");
  } else if (kind === "gone") {
    $("title").textContent = say("No challenge at that number");
    $("brief").textContent = say("There is no challenge at that number to show: it may be one still to come.");
  } else {
    $("brief").textContent = say("The challenge did not load just now. Try again in a minute.");
  }
  // Never a dead end: when it did not load, Try again in the head.
  $("again").hidden = kind !== "broken";
}

// ---------------------------------------------------------------------------
// A weekly quick build (api/_prompts.js): a brief, a template that Start
// opens in the studio, every entry newest first, and once it ends the stack
// of them all. No rules, no vote.

/// The hub's panel for this week's quick build ([week], the answer's
/// prompt_now), or none.
function drawWeek(week) {
  $("week").hidden = !week;
  if (!week) return;
  const page = pageOf(week.id);
  $("week-title").textContent = week.title;
  $("week-title").href = page;
  $("week-brief").textContent = week.brief;
  $("week-days").textContent = say("Until {day}", { day: SHORT.format(startOf(week.ends_on)) });
  $("week-count").textContent = week.entries ? counted(week.entries, "entry", "entries") : say("Be the first to publish one.");
  $("week-start").hidden = !week.start;
  if (week.start) $("week-start").href = week.start;
  $("week-see").href = page;
}

/// [card] (modelCard's) with its picture a way into the model in 3D, in its
/// place, on a tap (web/start3d.js, as the embed's): the 3D code and looks
/// asked for only then.
function turning(card, entry) {
  const img = card.querySelector(".frame > img");
  if (!img) return card;
  const picture = document.createElement("a");
  picture.className = "picture";
  picture.href = `/app?view=${entry.id}`;
  picture.dataset.scene = `/m/${entry.id}/scene.json`;
  picture.setAttribute("aria-label", say("View {name} in 3D", { name: entry.name }));
  img.replaceWith(picture);
  picture.append(img);
  const go = (event) => {
    if (event.metaKey || event.ctrlKey || event.shiftKey) return;
    event.preventDefault();
    for (const kind of ["click", "pointerdown"]) picture.removeEventListener(kind, go);
    if (!document.querySelector('link[href="/view3d.css"]')) {
      document.head.append(Object.assign(document.createElement("link"), { rel: "stylesheet", href: "/view3d.css" }));
    }
    import("/start3d.js").then(({ start3d }) => start3d(picture).open("tap")).catch(() => { location.href = picture.href; });
  };
  picture.addEventListener("click", go);
  return card;
}

/// A quick build's page ([p], the answer's prompt).
function drawPrompt(p) {
  clearInterval(ticking);
  const open = p.state === "open";
  const coming = p.state === "upcoming";
  root.dataset.year = "no";
  for (const id of ["winners", "entries", "how", "next", "past", "week", "rules-part", "enter", "enter-note", "again"]) $(id).hidden = true;
  $("crumbs").hidden = false;
  $("crumb").textContent = p.title;
  const status = $("status");
  status.hidden = false;
  status.className = `badge ${open ? "good" : coming ? "accent" : ""}`.trim();
  status.textContent = open ? say("Open") : coming ? say("Opens soon") : say("Ended");
  $("eyebrow").textContent = open ? say("This week’s quick build") : coming ? say("The next quick build") : say("A past quick build");
  $("title").textContent = p.title;
  document.title = say("{title} · a Brickworks quick build", { title: p.title });
  $("brief").textContent = p.brief;
  // The way in: the template, a copy of it in the studio.
  $("start").hidden = !open || !p.start;
  if (p.start) $("start").href = p.start;
  $("start").textContent = say("Start");
  $("to-hub").hidden = false;
  $("to-hub").href = `${langAt()}/challenge${tests ? "?tests=1" : ""}`;
  $("share").hidden = false;
  const at = { from: dayOf(p.starts_on), to: dayOf(p.ends_on) };
  $("share").onclick = () => openShare(sheetFor({ url: `${location.origin}${pageOf(p.id)}`, name: p.title,
    text: say("{title}: Brickworks' quick build of the week, {from} to {to}", { title: p.title, ...at }),
    about: say("Its link opens this quick build: its brief, its template to start from, and every entry.") }));
  // Where it stands: a countdown to its end, or the days it ran.
  $("clock").hidden = false;
  $("countdown").hidden = true;
  $("rounds").hidden = true;
  $("numbers").hidden = true;
  $("clock-h").textContent = open ? say("Ends in") : coming ? say("Opens in") : say("Ran");
  const days = daysOf(p.starts_on, p.ends_on);
  $("reach").hidden = !open;
  if (open) {
    const total = Math.round((endOf(p.ends_on) - startOf(p.starts_on)) / 86400000);
    const today = Math.min(total, Math.floor((Date.now() - startOf(p.starts_on)) / 86400000) + 1);
    $("days").textContent = say("{days} · day {day} of {total}", { days, day: number(today), total: number(total) });
    $("reach").firstElementChild.style.width = `${Math.max(2, Math.min(100, (today / total) * 100)).toFixed(1)}%`;
    countdown(endOf(p.ends_on), (time) => say("Ends in {time}", { time }));
  } else if (coming) {
    $("days").textContent = days;
    countdown(startOf(p.starts_on), (time) => say("Opens in {time}", { time }));
  } else {
    $("days").textContent = say("Ran {days}", { days });
  }
  // The stack, once made.
  $("stack").hidden = !p.stack;
  $("stack-card").replaceChildren(...(p.stack ? [turning(modelCard(p.stack, { eager: true }), p.stack)] : []));
  // Every entry, newest first; never empty: the template's Start.
  const entries = Array.isArray(p.entries) ? p.entries : [];
  $("prompt-entries").hidden = coming;
  $("prompt-count").textContent = entries.length
    ? say("{entries} by {makers}", { entries: counted(entries.length, "entry", "entries"), makers: counted(p.makers || 1, "builder") })
    : "";
  $("prompt-cards").replaceChildren(...entries.map((entry, i) => turning(modelCard(entry, { eager: i < 4 }), entry)));
  $("prompt-empty").hidden = entries.length > 0 || !open || !p.start;
  if (p.start) $("prompt-empty-start").href = p.start;
  $("prompt-how").hidden = !open && !coming;
  root.dataset.challenge = `prompt-${p.state}`;
  root.dataset.clock = open ? "counting" : "ended";
}

function draw() {
  if (state.prompt) return drawPrompt(state.prompt);
  for (const id of ["stack", "prompt-entries", "prompt-how"]) $(id).hidden = true;
  const c = state.challenge;
  // Two at a time while it may be; asked for when it may not (the vote
  // ended, one entry left), the cards, and the address says so.
  if (pairWay && !(c && pairable(c, pairWay))) {
    pairWay = null;
    address({ pair: null });
  }
  // Two at a time, nothing drawn that names a maker or counts: the week's
  // quick build, the next and the ones that ran are not drawn.
  const blind = Boolean(pairWay);
  drawWeek(asked || blind ? null : state.prompt_now || null);
  root.dataset.year = state.year ? "yes" : "no";
  drawNext(asked || blind ? null : state.next || null);
  drawPast(asked || blind ? [] : state.past || []);
  $("again").hidden = true;
  if (!c) {
    for (const id of ["winners", "entries", "how"]) $(id).hidden = true;
    drawEmpty("none");
    root.dataset.challenge = state.ready === false ? "not-yet" : "none";
    return;
  }
  $("clock").hidden = false;
  drawHead(c);
  if (pairWay) {
    // Nor the cards, the winners or the numbers.
    for (const id of ["winners", "how", "numbers"]) $(id).hidden = true;
    $("numbers").replaceChildren();
    $("winner-cards").replaceChildren();
    $("week-count").textContent = "";
    drawPair(c);
    root.dataset.challenge = c.state;
    root.dataset.clock = "counting";
    root.dataset.pair = pairWay;
    return;
  }
  delete root.dataset.pair;
  drawWinners(c);
  drawEntries(c);
  $("how").hidden = c.state === "ended";
  root.dataset.challenge = c.state;
  root.dataset.clock = c.state === "ended" ? "ended" : "counting";
}

async function load() {
  const path = `/api/people?op=challenge${asked ? `&id=${asked}` : ""}${tests ? "&tests=1" : ""}`;
  try {
    let answer;
    if (signedIn()) {
      answer = await call(path);
      // A sign-in that has ended: as a visitor.
      if (answer.status === 401) answer = null;
    }
    if (!answer) {
      const reply = await fetch(path, { headers: { accept: "application/json" } });
      answer = { status: reply.status, body: await reply.json().catch(() => ({})) };
    }
    if (answer.status === 404 && asked) {
      for (const id of ["winners", "entries", "how", "next", "past", "week", "stack", "prompt-entries", "prompt-how"]) $(id).hidden = true;
      drawEmpty("gone");
      root.dataset.challenge = "gone";
      return;
    }
    if (answer.status !== 200) throw new Error(String(answer.status));
    state = answer.body;
    draw();
  } catch {
    if (state?.challenge || state?.prompt) return tell(say("The challenge did not load just now. Try again in a minute."));
    for (const id of ["winners", "entries", "how", "next", "past", "week", "stack", "prompt-entries", "prompt-how"]) $(id).hidden = true;
    drawEmpty("broken");
    root.dataset.challenge = "broken";
  }
}

$("enter").addEventListener("click", enter);
$("pair-again").addEventListener("click", () => state?.challenge && pairAgain(state.challenge));
$("pair-link").addEventListener("click", (event) => {
  if (!state?.challenge || event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
  event.preventDefault();
  pairWay = $("pair-link").dataset.way || groupOf(state.challenge);
  history.pushState(history.state, "", `${location.pathname}?${pairAddress(pairWay)}`);
  draw();
  $("entries").scrollIntoView({ block: "start" });
  $("pair-said").focus({ preventScroll: true });
});
$("pair-back").addEventListener("click", (event) => {
  if (!state?.challenge || event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
  event.preventDefault();
  pairWay = null;
  history.pushState(history.state, "", $("pair-back").getAttribute("href"));
  draw();
  $("entries").scrollIntoView({ block: "start" });
});
// Back and Forward between the cards and two at a time.
addEventListener("popstate", () => {
  const now = new URLSearchParams(location.search).get("pair");
  pairWay = WAYS.includes(now) ? now : null;
  if (state?.challenge) draw();
});
// The head is held unseen until it is drawn (challenge.html): an answer that
// is slow to come shows it as it stands after five seconds.
setTimeout(() => { if (!root.dataset.challenge) root.dataset.challenge = "loading"; }, 5000);
$("again").addEventListener("click", () => {
  root.dataset.challenge = "loading";
  $("again").hidden = true;
  load();
});
load();
