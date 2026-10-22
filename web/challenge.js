// This month's challenge, /challenge (challenge.html, supabase/challenges.sql):
// the brief, the rules, the days, and the entries as the gallery's cards in
// their two groups, built by hand and with the assistant, from
// /api/people?op=challenge. Signed in (web/account.js), each entry has a vote
// button: one vote in each group, never for your own, for people 13 and over.
// When it ends, the winners first, and each entry's votes.
//
// Names and credits were typed by strangers, so every one goes on the page
// as text, never as markup; a link is built from a model's id alone.
import { askToSignIn, call, signedIn } from "/account.js";
import { counted, modelCard } from "/card.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const tests = new URLSearchParams(location.search).get("tests") === "1";
const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const dayOf = (iso) => DAY.format(new Date(`${String(iso).slice(0, 10)}T00:00:00Z`));
let state = null;

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

function draw() {
  const c = state.challenge;
  $("loading").hidden = true;
  $("none").hidden = Boolean(c);
  for (const id of ["rules-part", "how", "winners"]) $(id).hidden = true;
  $("groups").replaceChildren();
  if (!c) {
    document.documentElement.dataset.challenge = state.ready === false ? "not-yet" : "none";
    return;
  }
  $("eyebrow").textContent = c.state === "open" ? "This month’s challenge" : c.state === "upcoming" ? "The next challenge"
    : "The last challenge";
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
  $("how").hidden = c.state === "ended";

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
    for (const entry of (group.entries || []).filter((one) => ID.test(String(one.id)))) {
      const lines = [];
      if (entry.winner) lines.push("Winner");
      // A count is said once there is one: never "0 votes".
      if (c.state === "ended" && Number(entry.votes)) lines.push(counted(entry.votes, "vote"));
      if (c.state !== "ended" && !entry.keeps) lines.push("No longer keeps the rules: a newer version broke one");
      for (const win of entry.won || []) if (win.challenge !== c.id) lines.push(`Won “${win.title}”`);
      grid.append(card(entry, lines, voteOf(c, entry)));
    }
    if (n) section.append(grid);
    $("groups").append(section);
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
  const path = `/api/people?op=challenge${tests ? "&tests=1" : ""}`;
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
