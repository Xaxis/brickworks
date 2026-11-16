// The console's Challenges (admin.html #challenges, console3): the one
// running, with its entries, groups, what breaks its rules and, once it has
// ended, its winners; the ones to come, the year's plan; and every one
// before, each opened whole at #challenges/<id> (api/admin.js
// ?op=challenge_view, api/_console_challenges.js). Set, end and plan are
// part A's acts (api/admin.js challenge, end_challenge, plan), each with a
// preview of what visitors will see: the challenge's head as /challenge
// draws it, its rules in the page's own words (web/card.js rulesSaid), and
// the year's themes with the day each is told. Drawn from the report the
// Gallery asks (admin-gallery.js loadReport).
//
// Titles and briefs go on the page as text.
import { $, TESTS, adminJson, ago, cell, emptyRow, make, post, rowAct as act, say, segmented, when } from "/admin-kit.js";
import { again, onReport } from "/admin-gallery.js";
import { rulesSaid } from "/card.js";

const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
const dayOf = (iso) => DAY.format(new Date(`${String(iso).slice(0, 10)}T00:00:00Z`));
const today = () => new Date().toISOString().slice(0, 10);
const daysBetween = (from, to) => Math.round((Date.parse(`${String(to).slice(0, 10)}T00:00:00Z`)
  - Date.parse(`${String(from).slice(0, 10)}T00:00:00Z`)) / 86400000) + 1;
/// What is left of a challenge running, today counted: "12 days left", "its
/// last day" (never "1 days" or "0 days left"); past its end, which only a
/// row not yet read again can be, said so.
const leftSaid = (ends) => {
  const left = daysBetween(today(), ends);
  return left > 1 ? `${left} days left` : left === 1 ? "its last day" : `past its last day, ${dayOf(ends)}`;
};
const toPage = (href, text) => { const a = make("a", "", text); a.href = href; return a; };

/// A challenge's rules in the console's short words.
function rulesShort(rules) {
  const said = [];
  if (rules?.most_parts) said.push(`at most ${Number(rules.most_parts).toLocaleString()} parts`);
  if (rules?.set_number) said.push(`set ${rules.set_number}${rules.set_name ? `, ${rules.set_name}` : ""}`);
  if (rules?.tested) said.push("Tested");
  return said;
}

// --- The one running --------------------------------------------------------

/// The line over the list: the one running, else the next to come.
function drawNow(list) {
  const mine = (list || []).filter((one) => Boolean(one.test) === TESTS);
  const open = mine.find((one) => one.state === "open");
  const next = mine.filter((one) => one.state === "upcoming").sort((a, b) => String(a.starts_on).localeCompare(String(b.starts_on)))[0];
  const one = open || next;
  const h = $("challenge-now-h");
  if (list === null || list === undefined) {
    say("challenge-now-h", "Not open yet: supabase/challenges.sql is not applied.");
    say("challenge-now-said", "");
    return;
  }
  if (!one) {
    // The checks' own (?tests=1) are apart from the site's, which the list
    // below shows beside them.
    say("challenge-now-h", TESTS ? "None of the checks' own is running, and none is set to come"
      : "No challenge is running, and none is set to come");
    say("challenge-now-said", TESTS ? "The site's own are listed below with theirs; a check's is marked a test's."
      : "Set one below, or a year of themes. Visitors see the last one's results until then.");
    return;
  }
  h.replaceChildren(open ? "Running: " : "Next: ", toPage(`#challenges/${one.id}`, one.title));
  const entered = (Number(one.entries?.hand) || 0) + (Number(one.entries?.assistant) || 0);
  const voted = (Number(one.votes?.hand) || 0) + (Number(one.votes?.assistant) || 0);
  say("challenge-now-said", open
    ? `${dayOf(one.starts_on)} to ${dayOf(one.ends_on)}, ${leftSaid(one.ends_on)}. ${entered} `
      + `${entered === 1 ? "entry" : "entries"} (${Number(one.entries?.hand) || 0} by hand, ${Number(one.entries?.assistant) || 0} `
      + `with the assistant), ${voted} ${voted === 1 ? "vote" : "votes"}. Open it for each entry and what breaks its rules.`
    : `Opens ${dayOf(one.starts_on)}, runs to ${dayOf(one.ends_on)}${one.announced_at && Date.parse(one.announced_at) > Date.now()
      ? `; visitors are told of it from ${dayOf(one.announced_at)}` : "; visitors know of it now"}.`);
}

// --- Every challenge --------------------------------------------------------

let shownChallenges = "now";

function siftChallenges() {
  for (const row of $("challenges").rows) {
    if (!row.dataset.state) continue;
    row.hidden = shownChallenges === "now" ? row.dataset.state === "ended" : shownChallenges === "ended" ? row.dataset.state !== "ended" : false;
  }
  const shown = [...$("challenges").rows].filter((row) => row.dataset.state && !row.hidden).length;
  const all = [...$("challenges").rows].filter((row) => row.dataset.state).length;
  if (all) say("challenges-note", shown ? "" : shownChallenges === "now" ? "None running or to come: see Ended." : "None ended yet.");
}
segmented(document.querySelector('[data-filter="challenges"]'), (value) => { shownChallenges = value; siftChallenges(); });

/// The challenges, the ones not yet ended first and then the ended ones,
/// the one that ended last first (supabase/challenge_list_order.sql), each
/// with its entries, votes and winners, and End it now on one not ended.
function drawChallenges(list) {
  const rows = $("challenges");
  rows.replaceChildren();
  $("challenge-form").hidden = list === null;
  if (list === null || list === undefined) {
    say("challenge-note", "");
    emptyRow(rows, "Not open yet: supabase/challenges.sql is not applied.");
    return;
  }
  for (const one of list) {
    const row = make("tr");
    row.dataset.challenge = String(one.id);
    row.dataset.state = one.state;
    const title = make("td", "about");
    title.append(toPage(`#challenges/${one.id}`, one.title), one.test ? " (a test's)" : "");
    row.append(title);
    cell(row, `${dayOf(one.starts_on)} to ${dayOf(one.ends_on)}`);
    const rules = rulesShort(one.rules);
    cell(row, rules.join("; ") || "none", rules.length ? "said" : "faint");
    // One to come is told to visitors from its announced_at (a year's themes,
    // supabase/challenge_year.sql), or at once.
    const told = one.state === "upcoming" && one.announced_at && Date.parse(one.announced_at) > Date.now()
      ? `, told from ${dayOf(one.announced_at)}` : "";
    cell(row, one.state === "open" ? "open" : one.state === "upcoming" ? `to come${told}` : "ended");
    // Each count once there is one: a challenge to come has none yet.
    for (const way of ["hand", "assistant"]) {
      const [entered, votes] = [Number(one.entries?.[way]) || 0, Number(one.votes?.[way]) || 0];
      cell(row, entered ? `${entered} in${votes ? `, ${votes} ${votes === 1 ? "vote" : "votes"}` : ""}` : "—", entered ? "n" : "n faint");
    }
    const won = make("td", "about");
    for (const w of one.winners || []) {
      if (won.childElementCount) won.append(make("br"));
      won.append(toPage(`/m/${encodeURIComponent(w.model)}`, w.name || w.model), ` (${w.way === "hand" ? "by hand" : "assistant"}, ${w.votes})`);
    }
    if (!won.childElementCount) {
      won.textContent = one.state === "ended" ? (one.settled ? "none" : "counted when shown") : "—";
      won.classList.add("faint");
    }
    row.append(won);
    const acts = make("td", "acts");
    if (one.state !== "ended") {
      // What visitors will see, said before it is done.
      acts.append(act("End it now", () => (confirm(`End "${one.title}" now? No more entries or votes. Visitors will see it as `
        + "ended today, with the most voted in each group as its winners.")
        ? post({ op: "end_challenge", challenge: one.id }, "challenges-note", `"${one.title}" has ended.`, { after: again })
        : Promise.resolve(false))));
    }
    row.append(acts);
    rows.append(row);
  }
  if (!list.length) emptyRow(rows, "None set yet.");
  siftChallenges();
}

// --- One challenge whole (#challenges/<id>) ---------------------------------

const WAY = { hand: "Built by hand", assistant: "Built with the assistant" };

/// One challenge whole, for the panel: {title, parts}.
export async function challengeOf(id) {
  const one = await adminJson({ op: "challenge_view", challenge: String(id) });
  if (one.ready === false) return { title: "Not open yet", parts: [make("p", "note", "supabase/challenges.sql is not applied.")] };
  const c = one.challenge;
  const parts = [];
  const facts = make("dl", "facts");
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  fact("Days", `${dayOf(c.starts_on)} to ${dayOf(c.ends_on)}${c.state === "open" ? `, ${leftSaid(c.ends_on)}` : ""}`);
  fact("State", c.state === "open" ? "open" : c.state === "upcoming" ? "to come" : `ended${c.ended_at ? ` ${when(c.ended_at)}` : ""}`);
  fact("The brief", c.brief || "—");
  fact("Rules", rulesShort(c.rules).join("; ") || "none but its brief");
  const v = one.visitors;
  fact("Visitors", v.shown ? make("span", "", `see it as ${v.state === "open" ? "open" : v.state === "upcoming" ? "to come" : "ended"}`
    + `${v.entries ? `, with ${v.entries} ${v.entries === 1 ? "entry" : "entries"}` : ""}: `, toPage(v.page, "its page"))
    : `${v.said}${v.told_from ? `, from ${dayOf(v.told_from)}` : ""}`);
  if (c.test) fact("A test's", "set by the site's checks");
  parts.push(facts);
  if (c.winners?.length) {
    parts.push(make("div", "part", make("h3", "", "Winners"), make("ul", "entries", ...c.winners.map((w) => make("li", "",
      toPage(`/m/${encodeURIComponent(w.model)}`, w.name || w.model), make("small", "", `${WAY[w.way] || w.way}, ${w.votes} `
      + `${w.votes === 1 ? "vote" : "votes"}`))))));
  } else if (c.state === "ended") {
    parts.push(make("p", "note", c.settled ? "No winners: nothing was voted for." : "Its winners are counted when it is next shown."));
  }
  const groups = make("div", "groups");
  for (const way of ["hand", "assistant"]) {
    const list = one.groups?.[way] || [];
    const box = make("div", "part", make("h3", "", `${WAY[way]} (${list.length})`));
    if (!list.length) {
      box.append(make("p", "note", one.entries_ready ? "No entries." : "Not read: supabase/console3.sql is not applied."));
    } else {
      box.append(make("ol", "entries", ...list.map((entry) => {
        const li = make("li", entry.keeps ? "" : "fails", toPage(`/m/${encodeURIComponent(entry.model)}`, entry.name || entry.model),
          make("small", "", `${entry.votes} ${entry.votes === 1 ? "vote" : "votes"} · ${entry.parts === null ? "parts not counted"
            : `${Number(entry.parts).toLocaleString()} parts`} · ${entry.email || "nobody's"} · ${ago(entry.at)}`
            + `${entry.shown ? "" : " · not in the gallery"}`));
        if (!entry.keeps) li.append(make("span", "failed", `Breaks its rules: ${entry.failed.join("; ")}`));
        return li;
      })));
    }
    groups.append(box);
  }
  parts.push(groups);
  if (one.failing) parts.unshift(make("p", "note bad", `${one.failing} ${one.failing === 1 ? "entry breaks" : "entries break"} its rules today.`));
  if (c.state !== "ended") {
    const said = make("p", "note");
    said.setAttribute("role", "status");
    parts.push(make("div", "part", make("div", "acts-row", act("End it now", () => (confirm(`End "${c.title}" now? No more entries `
      + "or votes. Visitors will see it as ended today, with the most voted in each group as its winners.")
      ? post({ op: "end_challenge", challenge: c.id }, said, `"${c.title}" has ended.`, { after: again })
      : Promise.resolve(false)))), said));
  }
  return { title: c.title, parts };
}

// --- What visitors will see -------------------------------------------------

/// The set form's challenge as /challenge will draw its head.
function previewSet() {
  const form = $("challenge-form");
  const box = $("challenge-preview");
  const starts = dateOf(form, "starts_on");
  const ends = dateOf(form, "ends_on");
  const open = starts && starts <= today();
  const rules = rulesSaid({ most_parts: form.has_most.checked ? Number(form.most_parts.value) : null,
    set_number: form.has_set.checked && form.set_number.value.trim() ? form.set_number.value.trim() : null, set_name: null,
    tested: form.tested.checked });
  const title = form.elements.title.value.trim();
  const brief = form.elements.brief.value.trim();
  box.replaceChildren(
    make("span", `badge ${open ? "good" : "accent"}`, open ? "Open" : "Opens soon"),
    make("p", "eyebrow", open ? "This month’s challenge" : "The next challenge"),
    make("h4", title ? "" : "faint", title || "Its title"),
    make("p", brief ? "" : "faint", brief || "Its brief: what to build, in a line or two."),
    rules.length ? make("ul", "", ...rules.map((one) => make("li", "", one))) : make("p", "faint", "No rules but its brief."),
    make("p", "faint", starts && ends ? `${dayOf(starts)} to ${dayOf(ends)}, ${daysBetween(starts, ends)} days${open ? "" : `; visitors `
      + "know of it as soon as it is set"}` : "Its days: choose them."));
}

/// The year form's themes, each with the day visitors are told of it.
function previewYear() {
  const list = $("year-preview");
  const themes = [...document.querySelectorAll("#year-months fieldset")].map((set) => ({ month: set.dataset.month,
    title: set.querySelector("input").value.trim(), brief: set.querySelector("textarea").value.trim(),
    said: set.querySelector("legend").textContent })).filter((one) => one.title || one.brief);
  list.replaceChildren(...themes.map((one) => {
    const first = new Date(`${one.month}-01T00:00:00Z`);
    const last = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0));
    // A month before it opens (api/admin.js plan: lead_days 31), or now.
    const told = new Date(Math.max(Date.now(), first.getTime() - 31 * 86400000));
    return make("li", "", make("b", one.title ? "" : "faint", one.title || `${one.said}: its title`),
      make("span", one.brief ? "" : "faint", one.brief || "Its brief."),
      make("small", "", `${dayOf(first.toISOString())} to ${dayOf(last.toISOString())}; told to visitors from `
        + `${told.getTime() <= Date.now() + 60000 ? "the moment it is set" : dayOf(told.toISOString())}`));
  }));
  $("year-preview-none").hidden = themes.length > 0;
}

$("challenge-form").addEventListener("input", previewSet);
$("challenge-form").addEventListener("change", previewSet);
$("year-form").addEventListener("input", previewYear);
$("year-form").addEventListener("change", previewYear);

onReport((data) => {
  drawNow(data.challenges);
  drawChallenges(data.challenges);
  drawYear(data.challenges, data.year === true);
  previewSet();
  previewYear();
});

/// Whether a challenge is running or set to come, for the Overview.
export const challengeAhead = (list) => (list || []).some((one) => Boolean(one.test) === TESTS && one.state !== "ended");

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
  "November", "December"];
/// A month in a date's dropdown, short as the console writes its dates
/// ("15 Nov 2026"): a long name ("September", 133 px) was cut short in a
/// day's month dropdown, at 1280 beside its preview and at 390 ("Novemt").
const MONTH_SHORT = Array.from({ length: 12 }, (_, at) => new Intl.DateTimeFormat("en-GB", { month: "short", timeZone: "UTC" })
  .format(Date.UTC(2000, at, 1)));

/// Each of the form's days as three dropdowns, day, month and year (this
/// one and the next), the way the site asks every date (site.css
/// fieldset.date): each named [date]_day, [date]_month, [date]_year.
function dateDropdowns() {
  const year = new Date().getUTCFullYear();
  for (const set of document.querySelectorAll("#challenge-form fieldset.date")) {
    const date = set.dataset.date;
    const words = set.querySelector("legend").textContent;
    const choose = (part, said, choices) => {
      const label = make("label");
      const select = make("select");
      select.name = `${date}_${part}`;
      select.required = true;
      // Chosen until a choice is made: else the browser chooses the first.
      const none = new Option(said, "", true, true);
      none.disabled = true;
      none.hidden = true;
      select.append(none, ...choices.map(([value, text]) => new Option(text, String(value))));
      label.append(make("span", "visually-hidden", `${words}: ${said.toLowerCase()}`), select);
      return label;
    };
    set.querySelector(".dropdowns").replaceChildren(
      choose("day", "Day", Array.from({ length: 31 }, (_, at) => [at + 1, String(at + 1)])),
      choose("month", "Month", MONTH_SHORT.map((name, at) => [at + 1, name])),
      choose("year", "Year", [[year, String(year)], [year + 1, String(year + 1)]]));
  }
}

/// [date]'s dropdowns as YYYY-MM-DD, or "" while one is not chosen; a day
/// the month does not have (31 April) is null.
function dateOf(form, date) {
  const [d, month, year] = ["day", "month", "year"].map((part) => Number(form.elements[`${date}_${part}`].value));
  if (!d || !month || !year) return "";
  const made = new Date(Date.UTC(year, month - 1, d));
  if (made.getUTCDate() !== d) return null;
  return made.toISOString().slice(0, 10);
}

function setDate(form, date, at) {
  form.elements[`${date}_day`].value = String(at.getUTCDate());
  form.elements[`${date}_month`].value = String(at.getUTCMonth() + 1);
  form.elements[`${date}_year`].value = String(at.getUTCFullYear());
}

/// The form's first day today and its last the month's last, until changed.
function datesFirst() {
  const form = $("challenge-form");
  const now = new Date();
  if (!dateOf(form, "starts_on")) setDate(form, "starts_on", now);
  if (!dateOf(form, "ends_on")) setDate(form, "ends_on", new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0)));
}

// A year of themes (supabase/challenge_year.sql): from a first month, twelve
// rows, each its month's title and brief; the empty ones skipped.

const MONTH_SAID = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });

/// The year's first month, as [year, month]: the form's, or the month after
/// the last day of any challenge not ended, else next month.
function yearFrom(list) {
  const form = $("year-form");
  const month = Number(form.elements.year_from_month?.value);
  const year = Number(form.elements.year_from_year?.value);
  if (month && year) return [year, month];
  const last = (list || []).filter((one) => !one.test === !TESTS && one.state !== "ended").map((one) => String(one.ends_on).slice(0, 10))
    .sort().pop();
  const after = last ? new Date(`${last}T00:00:00Z`) : new Date();
  return [after.getUTCFullYear() + (after.getUTCMonth() === 11 ? 1 : 0), (after.getUTCMonth() + 1) % 12 + 1];
}

/// The twelve months' rows, from [year]-[month], each its words kept when
/// the first month changes.
function yearRows([year, month]) {
  const box = $("year-months");
  const kept = [...box.querySelectorAll("fieldset")].map((set) => ({
    title: set.querySelector("input").value, brief: set.querySelector("textarea").value }));
  box.replaceChildren(...Array.from({ length: 12 }, (_, at) => {
    const first = new Date(Date.UTC(year, month - 1 + at, 1));
    const set = make("fieldset");
    set.dataset.month = first.toISOString().slice(0, 7);
    const input = make("input");
    input.name = `theme_${at}_title`;
    input.maxLength = 80;
    input.value = kept[at]?.title || "";
    const area = make("textarea");
    area.name = `theme_${at}_brief`;
    area.maxLength = 600;
    area.rows = 2;
    area.value = kept[at]?.brief || "";
    set.append(make("legend", "", MONTH_SAID.format(first)), make("label", "", "Title", input),
      make("label", "", "The brief", area));
    return set;
  }));
}

/// The year's form: its first month as two dropdowns, and its rows; hidden
/// with challenges.sql, and saying so before challenge_year.sql.
function drawYear(list, ready) {
  const form = $("year-form");
  form.hidden = list === null || list === undefined;
  $("year-not-yet").hidden = ready;
  form.querySelector('button[type="submit"]').disabled = !ready;
  const set = form.querySelector('fieldset[data-date="year_from"] .dropdowns');
  if (!set.childElementCount) {
    const [year, month] = yearFrom(list);
    const choose = (part, said, choices, value) => {
      const label = make("label");
      const select = make("select");
      select.name = `year_from_${part}`;
      select.append(...choices.map(([v, text]) => new Option(text, String(v), v === value, v === value)));
      select.addEventListener("change", () => yearRows(yearFrom(list)));
      label.append(make("span", "visually-hidden", `The first month: ${said.toLowerCase()}`), select);
      return label;
    };
    const now = new Date().getUTCFullYear();
    set.append(choose("month", "Month", MONTHS.map((name, at) => [at + 1, name]), month),
      choose("year", "Year", [[now, String(now)], [now + 1, String(now + 1)]], year));
    yearRows([year, month]);
  }
}

$("year-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const send = form.querySelector('button[type="submit"]');
  const themes = [...form.querySelectorAll("#year-months fieldset")].map((set) => ({ month: set.dataset.month,
    title: set.querySelector("input").value.trim(), brief: set.querySelector("textarea").value.trim(),
    said: set.querySelector("legend").textContent })).filter((one) => one.title || one.brief);
  if (!themes.length) return say("year-note", "Give at least one month a theme.", true);
  const half = themes.find((one) => !one.title || !one.brief);
  if (half) return say("year-note", `${half.said}: give it a title and a brief.`, true);
  send.disabled = true;
  try {
    const said = await adminJson({ op: "plan" }, { method: "POST",
      body: { themes: themes.map(({ month, title, brief }) => ({ month, title, brief })) } });
    for (const field of form.querySelectorAll("#year-months input, #year-months textarea")) field.value = "";
    await again();
    const planned = said.planned || [];
    say("year-note", `Set: ${planned.length} ${planned.length === 1 ? "theme" : "themes"}, from ${dayOf(planned[0].starts_on)} `
      + `to ${dayOf(planned[planned.length - 1].ends_on)}. Each is told a month before it opens.`);
  } catch (problem) {
    say("year-note", problem.message, true);
  } finally {
    send.disabled = false;
  }
});

$("challenge-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const send = form.querySelector('button[type="submit"]');
  const days = { starts_on: dateOf(form, "starts_on"), ends_on: dateOf(form, "ends_on") };
  const missing = Object.keys(days).find((date) => !days[date]);
  if (missing) {
    const words = form.querySelector(`fieldset[data-date="${missing}"] legend`).textContent.toLowerCase();
    const month = Number(form.elements[`${missing}_month`].value);
    const most = new Date(Date.UTC(Number(form.elements[`${missing}_year`].value), month, 0)).getUTCDate();
    return say("challenge-note", `The ${words} is not on the calendar: ${MONTHS[month - 1]} has ${most} days.`, true);
  }
  const body = { title: form.elements.title.value, brief: form.elements.brief.value, ...days, tested: form.tested.checked };
  if (form.has_most.checked) body.most_parts = Number(form.most_parts.value);
  if (form.has_set.checked) body.set_number = form.set_number.value;
  send.disabled = true;
  try {
    const said = await adminJson({ op: "challenge" }, { method: "POST", body });
    form.reset();
    datesFirst();
    await again();
    say("challenge-note", `Set, from ${dayOf(said.starts_on)} to ${dayOf(said.ends_on)}${said.set
      ? `, with set ${said.set.number} (${said.set.name}, ${said.set.lots} lots)` : ""}.`);
  } catch (problem) {
    say("challenge-note", problem.message, true);
  } finally {
    send.disabled = false;
  }
});
dateDropdowns();
datesFirst();

