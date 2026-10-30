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
// as text, never as markup; a link is built from a model's id alone.
import { askToSignIn, call, signedIn } from "/account.js";
import { counted, modelCard } from "/card.js";
import { PAGE_SIZE, pageAsked, pager } from "/pager.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const tests = new URLSearchParams(location.search).get("tests") === "1";
// One challenge of the past (or the next) by its number, else the one shown now.
const asked = /^[1-9][0-9]{0,15}$/.test(new URLSearchParams(location.search).get("id") || "")
  ? new URLSearchParams(location.search).get("id") : null;
const pageOf = (id) => `/challenge?id=${id}${tests ? "&tests=1" : ""}`;
const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const dayOf = (iso) => DAY.format(new Date(`${String(iso).slice(0, 10)}T00:00:00Z`));
let state = null;
// Each group's pager, by its way: stopped and made again as the groups are
// drawn again (after a vote), showing the pages it showed.
const pagers = new Map();

const say = (text) => { $("said").textContent = text; };

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
  if (!you) return { label: "Vote for it", run: () => signInToVote() };
  if (!you.may_vote) return null;
  if ((you.entries || []).includes(entry.id)) return { label: "Your entry", disabled: true };
  if (!entry.keeps) return null;
  const voted = you.voted?.[entry.way];
  if (voted === entry.id) return { label: "Your vote", disabled: true, pressed: true };
  if (voted) return { label: "You voted in this group", disabled: true, pressed: false };
  return { label: "Vote for it", pressed: false, run: (button) => castVote(c, entry, button) };
}

async function signInToVote() {
  if (await askToSignIn("Sign in to vote: we email you a code, no password.")) await load();
}

async function castVote(c, entry, button) {
  button.disabled = true;
  const answer = await call("/api/people?op=vote", { method: "POST", body: { challenge: c.id, model: entry.id } });
  if (answer.status !== 200) {
    button.disabled = false;
    return say(answer.body.error || "That vote did not go just now. Try again in a minute.");
  }
  await load();
  say(`Your vote is for “${entry.name}”, ${c.groups.find((g) => g.way === entry.way)?.label.toLowerCase()}.`);
}

/// The next challenge told, under the one shown: its theme and its days.
function drawNext(next) {
  $("next").hidden = !next;
  if (!next) return;
  $("next").dataset.next = String(next.id);
  $("next-title").textContent = next.title;
  $("next-days").textContent = `Opens on ${dayOf(next.starts_on)}, until ${dayOf(next.ends_on)}`;
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
    days.textContent = `${one.days_said}${one.entries ? ` · ${counted(one.entries, "entry", "entries")}` : ""}`;
    item.append(head, days);
    const won = (one.winners || []).filter((w) => ID.test(String(w.id)));
    if (won.length) {
      const grid = document.createElement("div");
      grid.className = "models";
      grid.append(...won.map((w) => card(w, [`Winner, ${w.label.toLowerCase()} · ${counted(w.votes, "vote")}`])));
      item.append(grid);
    } else {
      const none = document.createElement("p");
      none.className = "note";
      none.textContent = one.entries ? "Nobody won: no entry had a vote." : "Nobody entered.";
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
  $("eyebrow").textContent = c.state === "open" ? "This month’s challenge" : c.state === "upcoming" ? "The next challenge"
    : asked ? "A past challenge" : "The last challenge";
  $("title").textContent = c.title;
  document.title = `${c.title} · a Brickworks challenge`;
  $("days").textContent = c.state === "open" ? `Open from ${dayOf(c.starts_on)} to ${dayOf(c.ends_on)}, the last day included`
    : c.state === "upcoming" ? `Opens on ${dayOf(c.starts_on)}, until ${dayOf(c.ends_on)}`
      : `Ran from ${dayOf(c.starts_on)} to ${dayOf(c.ends_on)}: it has ended`;
  $("brief").textContent = c.brief;
  const rules = $("rules");
  rules.replaceChildren(...(c.rules_said || []).map((text) => {
    const item = document.createElement("li");
    item.textContent = text;
    return item;
  }));
  $("no-rules").hidden = (c.rules_said || []).length > 0;
  $("rules-part").hidden = false;
  $("how").hidden = c.state !== "open" && (c.state === "ended" || Boolean(asked));

  const entries = new Map();
  for (const group of c.groups || []) for (const one of group.entries || []) entries.set(`${one.way}/${one.id}`, one);
  // The winners, once it ended and was counted.
  const won = (c.winners || []).map((w) => ({ w, entry: entries.get(`${w.way}/${w.model}`) })).filter((x) => x.entry);
  $("winners").hidden = c.state !== "ended";
  $("winner-cards").replaceChildren(...won.map(({ w, entry }) => card(entry,
    [`Winner, ${w.label.toLowerCase()} · ${counted(w.votes, "vote")}`])));
  if (c.state === "ended" && !won.length) {
    const none = document.createElement("p");
    none.className = "note";
    none.textContent = "Nobody won: no entry had a vote.";
    $("winner-cards").replaceChildren(none);
  }

  for (const group of c.groups || []) {
    const section = document.createElement("section");
    section.id = `group-${group.way}`;
    section.setAttribute("aria-labelledby", `group-${group.way}-h`);
    const head = document.createElement("h2");
    head.id = `group-${group.way}-h`;
    head.textContent = group.label;
    const note = document.createElement("p");
    note.className = "note";
    const n = (group.entries || []).length;
    note.textContent = !n ? (c.state === "upcoming" ? "Entries open with the challenge." : "Nobody has entered in this group yet.")
      : c.state === "ended" ? `${counted(n, "entry", "entries")}, the most voted first.`
        : `${counted(n, "entry", "entries")}, the first entered first. Votes are counted when it ends.`;
    section.append(head, note);
    const grid = document.createElement("div");
    grid.className = "models wide";
    grid.id = `entries-${group.way}`;
    const entries = (group.entries || []).filter((one) => ID.test(String(one.id)));
    const drawEntry = (entry) => {
      const lines = [];
      if (entry.winner) lines.push("Winner");
      // A count is said once there is one: never "0 votes".
      if (c.state === "ended" && Number(entry.votes)) lines.push(counted(entry.votes, "vote"));
      if (c.state !== "ended" && !entry.keeps) lines.push("No longer keeps the rules: a newer version broke one");
      for (const win of entry.won || []) if (win.challenge !== c.id) lines.push(`Won “${win.title}”`);
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
  if (c.state === "open" && state.you && !state.you.may_vote && state.you.why_not) {
    const why = document.createElement("p");
    why.className = "note why-not";
    why.textContent = state.you.why_not;
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
      $("none").textContent = "There is no challenge at that number to show: it may be one still to come.";
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
