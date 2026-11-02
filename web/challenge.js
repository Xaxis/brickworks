// This month's challenge, /challenge (challenge.html, supabase/challenges.sql):
// the brief, the rules, the days, and the entries as the gallery's cards in
// their two groups, built by hand and with the assistant, from
// /api/people?op=challenge. Signed in (web/account.js), each entry has a vote
// button: one vote in each group, never for your own, for people 13 and over.
// When it ends, the winners first, and each entry's votes. Under it, the next
// one told and the challenges that ran with their winners (?id=N draws one of
// those as this one is, its entries and its winners). Each group's entries
// are paged as every list of the site is (web/pager.js), the address saying
// each group's own page (?hand-page=2, ?assistant-page=3).
//
// Names and credits were typed by strangers, so every one goes on the page
// as text, never as markup; a link is built from a model's id alone. Its
// words are the page's language's (web/de/challenge.html and the others,
// tools/site_lang.py): the rules said from the rules themselves, each day
// as the language writes it, and what the server says through told().
import { askToSignIn, call, signedIn } from "/account.js";
import { counted, langAt, modelCard, rulesSaid, say, told } from "/card.js";
import { PAGE_SIZE, pageAsked, pager } from "/pager.js";
import { openShare, sheetFor } from "/share-sheet.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const tests = new URLSearchParams(location.search).get("tests") === "1";
// One challenge of the past (or the next) by its number, else the one shown now.
const asked = /^[1-9][0-9]{0,15}$/.test(new URLSearchParams(location.search).get("id") || "")
  ? new URLSearchParams(location.search).get("id") : null;
const pageOf = (id) => `${langAt()}/challenge?id=${id}${tests ? "&tests=1" : ""}`;
const LOCALE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "en-GB";
const DAY = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const dateOf = (iso) => new Date(`${String(iso).slice(0, 10)}T00:00:00Z`);
const dayOf = (iso) => DAY.format(dateOf(iso));
/// A challenge's days, said once each in the page's language: "1–30
/// November 2026", "28. September – 4. Oktober 2026".
const daysOf = (from, to) => DAY.formatRange(dateOf(from), dateOf(to));
/// A group's name, by its way (api/_challenges.js WAYS).
const wayName = (way) => (way === "assistant" ? say("Built with the assistant") : say("Built by hand"));
/// What a winner's card says: "Winner, built by hand · 3 votes".
const winnerSaid = (way, votes) => say(way === "assistant" ? "Winner, built with the assistant · {votes}" : "Winner, built by hand · {votes}",
  { votes: counted(votes, "vote") });
let state = null;
// Each group's pager, by its way: stopped and made again as the groups are
// drawn again (after a vote), showing the pages it showed.
const pagers = new Map();

const tell = (text) => { $("said").textContent = text; };

/// An entry's card, the gallery's own (web/card.js), with what the
/// challenge says of it under its numbers, and a button under it when there
/// is one.
function card(model, lines, action) {
  const box = document.createElement("div");
  box.className = "kept";
  box.dataset.entry = model.id;
  box.dataset.way = model.way || "";
  const link = modelCard(model);
  const words = link.querySelector(".words");
  for (const text of lines.filter(Boolean)) {
    const line = document.createElement("small");
    line.className = "challenge-said";
    line.textContent = text;
    words.append(line);
  }
  box.append(link);
  if (action) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "cta ghost small";
    button.textContent = action.label;
    button.disabled = Boolean(action.disabled);
    if (action.pressed !== undefined) button.setAttribute("aria-pressed", String(action.pressed));
    if (action.run) button.addEventListener("click", () => action.run(button));
    box.append(button);
  }
  return box;
}

/// The vote button an entry has, for whoever is looking: none once it ended.
function voteOf(c, entry) {
  if (c.state !== "open") return null;
  const you = state.you;
  if (!you) return { label: say("Vote for it"), run: () => signInToVote() };
  if (!you.may_vote) return null;
  if ((you.entries || []).includes(entry.id)) return { label: say("Your entry"), disabled: true };
  if (!entry.keeps) return null;
  const voted = you.voted?.[entry.way];
  if (voted === entry.id) return { label: say("Your vote"), disabled: true, pressed: true };
  if (voted) return { label: say("You voted in this group"), disabled: true, pressed: false };
  return { label: say("Vote for it"), pressed: false, run: (button) => castVote(c, entry, button) };
}

async function signInToVote() {
  if (await askToSignIn("Sign in to vote: we email you a code, no password.")) await load();
}

async function castVote(c, entry, button) {
  button.disabled = true;
  const answer = await call("/api/people?op=vote", { method: "POST", body: { challenge: c.id, model: entry.id } });
  if (answer.status !== 200) {
    button.disabled = false;
    return tell(told(answer.body.error, say("That vote did not go just now. Try again in a minute.")));
  }
  await load();
  tell(say(entry.way === "assistant" ? "Your vote is for “{name}”, built with the assistant." : "Your vote is for “{name}”, built by hand.",
    { name: entry.name }));
}

/// The next challenge told, under the one shown: its theme and its days.
function drawNext(next) {
  $("next").hidden = !next;
  if (!next) return;
  $("next").dataset.next = String(next.id);
  $("next-title").textContent = next.title;
  $("next-days").textContent = say("Opens on {from}, until {to}", { from: dayOf(next.starts_on), to: dayOf(next.ends_on) });
  $("next-brief").textContent = next.brief;
}

/// The challenges that ran, the last first: each its name (a link to its
/// own page), its days and how many entered, and its winners as the
/// gallery's cards.
function drawPast(past) {
  $("past").hidden = !past.length;
  $("past-list").replaceChildren(...past.map((one) => {
    const item = document.createElement("article");
    item.className = "past-one";
    item.dataset.past = String(one.id);
    const head = document.createElement("h3");
    const link = document.createElement("a");
    link.href = pageOf(one.id);
    link.textContent = one.title;
    head.append(link);
    const days = document.createElement("p");
    days.className = "note";
    days.textContent = `${daysOf(one.starts_on, one.ends_on)}${one.entries ? ` · ${counted(one.entries, "entry", "entries")}` : ""}`;
    item.append(head, days);
    const won = (one.winners || []).filter((w) => ID.test(String(w.id)));
    if (won.length) {
      const grid = document.createElement("div");
      grid.className = "models";
      grid.append(...won.map((w) => card(w, [winnerSaid(w.way, w.votes)])));
      item.append(grid);
    } else {
      const none = document.createElement("p");
      none.className = "note";
      none.textContent = one.entries ? say("Nobody won: no entry had a vote.") : say("Nobody entered.");
      item.append(none);
    }
    return item;
  }));
}

function draw() {
  const c = state.challenge;
  const shown = new Map([...pagers].map(([way, one]) => [way, { first: one.state.first, last: one.state.last }]));
  for (const one of pagers.values()) one.stop();
  pagers.clear();
  $("loading").hidden = true;
  $("none").hidden = Boolean(c);
  for (const id of ["rules-part", "how", "winners"]) $(id).hidden = true;
  $("groups").replaceChildren();
  document.documentElement.dataset.year = state.year ? "yes" : "no";
  drawNext(asked ? null : state.next || null);
  drawPast(asked ? [] : state.past || []);
  if (!c) {
    document.documentElement.dataset.challenge = state.ready === false ? "not-yet" : "none";
    return;
  }
  $("crumbs").hidden = !asked;
  $("crumb").textContent = c.title;
  $("eyebrow").textContent = c.state === "open" ? say("This month’s challenge") : c.state === "upcoming" ? say("The next challenge")
    : asked ? say("A past challenge") : say("The last challenge");
  $("title").textContent = c.title;
  document.title = say("{title} · a Brickworks challenge", { title: c.title });
  const at = { from: dayOf(c.starts_on), to: dayOf(c.ends_on) };
  $("days").textContent = c.state === "open" ? say("Open from {from} to {to}, the last day included", at)
    : c.state === "upcoming" ? say("Opens on {from}, until {to}", at) : say("Ran from {from} to {to}: it has ended", at);
  $("brief").textContent = c.brief;
  // Share: its own page, which stays this challenge's after the next opens.
  $("share").hidden = false;
  $("share").onclick = () => openShare(sheetFor({ url: `${location.origin}${pageOf(c.id)}`, name: c.title,
    text: c.state === "upcoming" ? say("{title}: a Brickworks building challenge, opens {from}", { title: c.title, ...at })
      : say("{title}: a Brickworks building challenge, {from} to {to}", { title: c.title, ...at }),
    about: c.state === "ended" ? say("Its link opens this challenge: its brief, its entries and its winners.")
      : say("Its link opens this challenge: its brief, its rules and how to enter.") }));
  // Said from the rules themselves (web/card.js rulesSaid), as the model's
  // page says them, not as the server wrote them.
  const said = rulesSaid({ most_parts: c.rules?.most_parts, set_number: c.rules?.set?.number, set_name: c.rules?.set?.name,
    tested: c.rules?.tested });
  const rules = $("rules");
  rules.replaceChildren(...said.map((text) => {
    const item = document.createElement("li");
    item.textContent = text;
    return item;
  }));
  $("no-rules").hidden = said.length > 0;
  $("rules-part").hidden = false;
  $("how").hidden = c.state !== "open" && (c.state === "ended" || Boolean(asked));

  const entries = new Map();
  for (const group of c.groups || []) for (const one of group.entries || []) entries.set(`${one.way}/${one.id}`, one);
  // The winners, once it ended and was counted.
  const won = (c.winners || []).map((w) => ({ w, entry: entries.get(`${w.way}/${w.model}`) })).filter((x) => x.entry);
  $("winners").hidden = c.state !== "ended";
  $("winner-cards").replaceChildren(...won.map(({ w, entry }) => card(entry, [winnerSaid(w.way, w.votes)])));
  if (c.state === "ended" && !won.length) {
    const none = document.createElement("p");
    none.className = "note";
    none.textContent = say("Nobody won: no entry had a vote.");
    $("winner-cards").replaceChildren(none);
  }

  for (const group of c.groups || []) {
    const section = document.createElement("section");
    section.id = `group-${group.way}`;
    section.setAttribute("aria-labelledby", `group-${group.way}-h`);
    const head = document.createElement("h2");
    head.id = `group-${group.way}-h`;
    head.textContent = wayName(group.way);
    const note = document.createElement("p");
    note.className = "note";
    const n = (group.entries || []).length;
    note.textContent = !n ? (c.state === "upcoming" ? say("Entries open with the challenge.") : say("Nobody has entered in this group yet."))
      : c.state === "ended" ? say("{entries}, the most voted first.", { entries: counted(n, "entry", "entries") })
        : say("{entries}, the first entered first. Votes are counted when it ends.", { entries: counted(n, "entry", "entries") });
    section.append(head, note);
    const grid = document.createElement("div");
    grid.className = "models wide";
    grid.id = `entries-${group.way}`;
    const entries = (group.entries || []).filter((one) => ID.test(String(one.id)));
    const drawEntry = (entry) => {
      const lines = [];
      if (entry.winner) lines.push(say("Winner"));
      // A count is said once there is one: never "0 votes".
      if (c.state === "ended" && Number(entry.votes)) lines.push(counted(entry.votes, "vote"));
      if (c.state !== "ended" && !entry.keeps) lines.push(say("No longer keeps the rules: a newer version broke one"));
      for (const win of entry.won || []) if (win.challenge !== c.id) lines.push(say("Won “{title}”", { title: win.title }));
      return card(entry, lines, voteOf(c, entry));
    };
    $("groups").append(section);
    if (n) {
      section.append(grid);
      const param = `${group.way}-page`;
      const paged = pager({ list: grid, param, noun: ["entry", "entries"], key: (item) => item.dataset.entry || "",
        load: async (page) => ({ items: entries.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE).map(drawEntry),
          total: entries.length, pages: Math.max(1, Math.ceil(entries.length / PAGE_SIZE)) }) });
      pagers.set(group.way, paged);
      const was = shown.get(group.way);
      paged.start(was && was.last ? was.last : pageAsked(location.search, param),
        was && was.last ? { from: was.first, restore: false } : {});
    }
  }
  // Why this account has no vote buttons, said once above the entries.
  if (c.state === "open" && state.you?.why_not && !state.you.may_vote) {
    const why = document.createElement("p");
    why.className = "note why-not";
    why.textContent = told(state.you.why_not);
    $("groups").prepend(why);
  }
  document.documentElement.dataset.challenge = c.state;
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
      $("loading").hidden = true;
      $("none").textContent = say("There is no challenge at that number to show: it may be one still to come.");
      $("none").hidden = false;
      document.documentElement.dataset.challenge = "gone";
      return;
    }
    if (answer.status !== 200) throw new Error(String(answer.status));
    state = answer.body;
    draw();
  } catch {
    $("loading").hidden = true;
    $("broken").hidden = false;
    document.documentElement.dataset.challenge = "broken";
  }
}

load();
