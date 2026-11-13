// The console's Gallery (admin.html #gallery/...): what visitors reported,
// the comments, what the gallery lists, this week's pick, the challenges,
// the Tested marks and the accounts taken out, from /api/admin's report,
// each with its acts beside it (api/admin.js).
//
// Names, notes and comments strangers wrote: text, never markup.
import { $, TESTS, address, adminJson, cell, emptyRow, make, post, resort, rowAct as act, say, sift, timeCell, when } from "/admin-kit.js";
import { token } from "/account.js";

// The token the page was last drawn with, for the photos it shows: renewing
// replaces the refresh token, so it is not renewed once per photo.
let drawnWith = "";

/// The gallery's report, asked and drawn; its counts back, for the nav.
export async function loadGallery() {
  drawnWith = await token();
  const data = await adminJson({});
  drawGallery(data);
  return counts(data);
}

export const counts = (data) => ({ reported: (data?.reports || []).length, listed: (data?.gallery || []).length,
  barred: (data?.barred || []).length });

/// After an act: the report again, and the nav's counts with it.
let onChange = () => {};
export function whenChanged(then) { onChange = then; }
const again = async () => { await loadGallery(); onChange(); };

function drawGallery(data) {
  const c = counts(data);
  $("tab-reported").textContent = c.reported ? String(c.reported) : "";
  $("tab-listed").textContent = c.listed ? String(c.listed) : "";
  $("tab-barred").textContent = c.barred ? String(c.barred) : "";
  drawListed(data);
  drawPicks(data.picks);
  drawChallenges(data.challenges);
  drawYear(data.challenges, data.year === true);
  drawTested(data.tested);
  drawReports(data.reports);
  drawComments(data.comments);
  drawBarred(data.barred);
  for (const box of document.querySelectorAll('[data-section="gallery"] [data-search]')) find(box);
  for (const table of document.querySelectorAll('[data-section="gallery"] table[data-sortable]')) resort(table);
}

/// The search over a tab's table, as typed.
function find(box) {
  const body = $(box.dataset.search);
  if (body) sift(body, box.value);
}
for (const box of document.querySelectorAll('[data-section="gallery"] [data-search]')) {
  box.addEventListener("input", () => find(box));
}

function modelCell(row, id, name) {
  const td = make("td", "about");
  td.append(make("a", "", name || id));
  td.firstChild.href = `/m/${encodeURIComponent(id)}`;
  row.append(td);
  return td;
}

// --- In the gallery ---------------------------------------------------------

function drawListed(data) {
  const listed = $("gallery");
  listed.replaceChildren();
  for (const model of data.gallery || []) {
    const row = make("tr");
    row.dataset.model = model.id;
    modelCell(row, model.id, model.name);
    cell(row, model.author ?? "nobody", model.author ? "" : "faint");
    cell(row, model.email ?? "—", model.email ? "" : "faint");
    cell(row, Number(model.parts).toLocaleString(), "n").dataset.value = String(model.parts);
    timeCell(row, model.listed_at);
    const acts = make("td", "acts");
    acts.append(act("Take out", () => (confirm(`Take "${model.name}" out of the gallery? Its owner will not be able to list it again.`)
      ? post({ op: "unlist", id: model.id }, "gallery-note", `"${model.name}" is out of the gallery.`, { after: again })
      : Promise.resolve(false))));
    if (data.picks) acts.append(pickButton(model.id, model.name));
    row.append(acts);
    listed.append(row);
  }
  say("gallery-note", data.gallery?.length ? "" : "Nothing is listed.");
}

// --- Tested -----------------------------------------------------------------

function drawTested(list) {
  const tested = $("tested");
  tested.replaceChildren();
  for (const mark of list || []) {
    const row = make("tr");
    modelCell(row, mark.model, mark.name);
    cell(row, String(mark.n), "n").dataset.value = String(mark.n);
    cell(row, String(mark.app));
    cell(row, Number(mark.parts).toLocaleString(), "n").dataset.value = String(mark.parts);
    cell(row, Number(mark.steps).toLocaleString(), "n").dataset.value = String(mark.steps);
    timeCell(row, mark.at);
    const acts = make("td", "acts");
    acts.append(act("Clear the mark", () => (confirm(`Clear the Tested mark of version ${mark.n}?`)
      ? post({ op: "untest", id: mark.model, v: mark.n }, "tested-note", "Cleared: it is not marked Tested anywhere now.",
        { after: again })
      : Promise.resolve(false))));
    row.append(acts);
    tested.append(row);
  }
  say("tested-note", list?.length ? "" : "Nothing is marked Tested.");
}

// --- Reported ---------------------------------------------------------------

function drawReports(list) {
  const reports = $("reports");
  reports.replaceChildren();
  for (const report of list || []) {
    const row = make("tr");
    // Where the owner's email of reports links each one (api/_trust.js).
    if (Number.isInteger(report.id)) row.id = `report-${report.id}`;
    timeCell(row, report.at);
    const about = make("td", "about");
    const to = make("a");
    if (report.comment) {
      // A comment: its words, and the model it is on.
      to.href = `/m/${encodeURIComponent(report.model)}#comment-${encodeURIComponent(report.comment.id)}`;
      to.textContent = `A comment on ${report.name ?? report.model}`;
    } else if (report.photo) {
      // A photo of a build (supabase/builds.sql): the photo itself, asked for
      // with the owner's sign-in, since it may be hidden from everybody else.
      row.dataset.photo = report.photo.id;
      to.href = `/m/${encodeURIComponent(report.model)}#photo-${encodeURIComponent(report.photo.id)}`;
      to.textContent = `A photo of a build of ${report.name ?? report.model}`;
      const said = [report.photo.words ? `“${report.photo.words}”` : "", report.photo.hidden ? "hidden by the model's owner" : "",
        report.photo.email ? `posted by ${report.photo.email}` : ""].filter(Boolean).join(" · ");
      if (said) about.append(make("small", "faint photo-said", said), make("br"));
      if (!report.photo.removed) about.prepend(photoOf(report.photo.id), make("br"));
    } else if (report.model) {
      to.href = `/m/${encodeURIComponent(report.model)}`;
      to.textContent = report.name ?? report.model;
    } else if (report.handle) {
      to.href = `/u/${encodeURIComponent(report.handle)}`;
      to.textContent = `@${report.handle}`;
      // The picture the profile shows as its avatar, if one of its own
      // (supabase/avatars.sql), to look at before taking it out.
      if (/^\/api\/people\?op=avatar&id=[A-Za-z0-9]{10}$/.test(String(report.picture || ""))) {
        const img = make("img", "reported-photo reported-avatar");
        img.alt = "The picture this profile shows as its avatar";
        img.width = 96;
        img.height = 96;
        img.src = report.picture;
        row.dataset.picture = report.handle;
        about.append(img, make("br"));
      }
    } else {
      to.href = `/c/${encodeURIComponent(report.collection)}`;
      to.textContent = `collection ${report.collection}`;
    }
    about.append(to);
    if (report.comment && report.comment.body) about.append(make("br"), make("q", "comment-said", report.comment.body));
    row.append(about);
    cell(row, report.reason);
    cell(row, report.note ?? "—", report.note ? "said" : "faint");
    // Whose it is, and the way the reporter gave to reach them.
    const who = cell(row, report.email ? address(report.email) : "nobody's", report.email ? "who" : "who faint");
    who.dataset.value = report.email ?? "";
    if (report.contact) who.append(make("br"), make("small", "faint", "Reach them: ", address(report.contact)));
    const acts = make("td", "acts");
    const go = (query, said, ask) => act(said[0], () => (!ask || confirm(ask)
      ? post(query, "reports-note", said[1], { after: again }) : Promise.resolve(false)));
    if (report.comment) {
      acts.append(go({ op: "uncomment", comment: report.comment.id }, ["Remove the comment", "The comment is removed."],
        "Take this comment off its page for good?"));
    } else if (report.photo) {
      acts.append(go({ op: "remove_photo", photo: report.photo.id }, ["Take the photo out", "The photo is out, and its file deleted."],
        "Take this photo out? Its file is deleted, and it is shown nowhere again."));
    } else if (report.handle && report.picture) {
      acts.append(go({ op: "remove_avatar", handle: report.handle }, ["Take the picture out", "The picture is out, and its file deleted."],
        "Take this profile's picture out? Its file is deleted, and its avatar is made from its handle again."));
    } else if (report.model) {
      acts.append(go({ op: "unlist", id: report.model }, ["Take out", "Taken out."], "Take this model out of the gallery for good?"));
      acts.append(go({ op: "bar", id: report.model }, ["Take out the account", "The account is out."],
        "Take every model of this account out of the gallery, and keep them out?"));
    }
    acts.append(go({ op: "dismiss", report: report.id }, ["Let it go", "Let go."]));
    row.append(acts);
    reports.append(row);
  }
  say("reports-note", list?.length ? "" : "Nothing is reported.");
  // Opened from that email: the report it named, marked (and put in view
  // once the tab shows: shown()).
  if (/^#report-\d+$/.test(location.hash)) {
    const named = document.getElementById(location.hash.slice(1));
    if (named) named.classList.add("asked");
    else say("reports-note", "The report that email named is no longer open: it was settled.");
  }
}

/// A reported photo, small, fetched with the owner's sign-in and shown from
/// memory (a blob: address, which this page's policy allows).
function photoOf(id) {
  const img = make("img", "reported-photo");
  img.alt = "The reported photo";
  img.width = 160;
  (async () => {
    try {
      const reply = await fetch(`/api/admin?op=photo&photo=${encodeURIComponent(id)}`,
        { headers: { authorization: `Bearer ${drawnWith}` } });
      if (!reply.ok) throw new Error(String(reply.status));
      img.src = URL.createObjectURL(await reply.blob());
    } catch {
      img.alt = "The photo could not be shown";
    }
  })();
  return img;
}

// --- Comments ---------------------------------------------------------------

function drawComments(list) {
  const comments = $("comments");
  comments.replaceChildren();
  for (const one of list || []) {
    const row = make("tr");
    row.id = `comment-${one.id}`;
    timeCell(row, one.at);
    const on = make("td", "about");
    const to = make("a", "", one.name ?? one.model);
    to.href = `/m/${encodeURIComponent(one.model)}#comment-${encodeURIComponent(one.id)}`;
    on.append(to, `${one.step ? `, step ${one.step} of version ${one.version}` : `, version ${one.version}`}${one.parent ? ", a reply" : ""}`);
    row.append(on);
    cell(row, one.body, "said");
    cell(row, one.handle ? `@${one.handle}` : one.email ?? "—", one.handle || one.email ? "" : "faint");
    cell(row, one.removed ? `removed by ${one.removed_by === "admin" ? "you" : "its author"}`
      : one.hidden ? "hidden by its builder" : one.edited_at ? "edited" : "shown", one.removed ? "faint" : "");
    const acts = make("td", "acts");
    if (!one.removed) {
      acts.append(act("Remove", () => (confirm("Take this comment off its page for good?")
        ? post({ op: "uncomment", comment: one.id }, "comments-note", "Removed.", { after: again }) : Promise.resolve(false))));
    }
    row.append(acts);
    comments.append(row);
  }
  say("comments-note", list?.length ? "" : "Nobody has commented yet.");
  if (/^#comment-\d+$/.test(location.hash)) document.getElementById(location.hash.slice(1))?.classList.add("asked");
}

// --- Taken out --------------------------------------------------------------

function drawBarred(list) {
  const barred = $("barred");
  barred.replaceChildren();
  for (const one of list || []) {
    const row = make("tr");
    row.dataset.account = one.account;
    const who = make("td");
    const to = make("a", "", one.email ?? one.account);
    to.href = `#people/${one.account}`;
    who.append(to);
    row.append(who);
    timeCell(row, one.at);
    cell(row, one.reason ?? "—", one.reason ? "" : "faint");
    const acts = make("td", "acts");
    acts.append(act("Let back in", () => post({ op: "unbar", account: one.account }, "barred-note", "Let back in.", { after: again })));
    row.append(acts);
    barred.append(row);
  }
  say("barred-note", list?.length ? "" : "Nobody is taken out.");
}

// --- This week's pick -------------------------------------------------------

/// Make it the pick (api/admin.js ?op=pick), for a week.
function pickButton(id, name) {
  return act("Make it the pick", () => (confirm(`Make "${name}" this week's pick, for seven days?`)
    ? post({ op: "pick", id, days: 7 }, "pick-note", `"${name}" is this week's pick.`, { after: again })
    : Promise.resolve(false)));
}

/// This week's pick: what visitors see now, the choices still open, and
/// the week worked out.
function drawPicks(picks) {
  const now = $("pick-now");
  now.replaceChildren();
  const said = make("span");
  if (!picks) {
    said.className = "note";
    said.textContent = "Not open yet: supabase/discovery.sql is not applied.";
    now.append(said);
  } else if (!picks.now || !picks.now.model) {
    said.textContent = "No pick this week: nothing in the gallery was built, remixed or listed Tested in the past seven days.";
    now.append(said);
  } else {
    const to = make("a", "", picks.now.model.name);
    to.href = `/m/${encodeURIComponent(picks.now.model.id)}`;
    const week = picks.now.week || {};
    said.textContent = picks.now.chosen ? ` — chosen, until ${when(picks.now.until)}` : ` — worked out: built ${
      week.builds || 0} this week, remixed ${week.remixes || 0}${week.tested ? ", Tested" : ""} (score ${week.score || 0})`;
    now.append(make("b", "", "Visitors see "), to, said);
    now.dataset.model = picks.now.model.id;
    now.dataset.chosen = picks.now.chosen ? "yes" : "no";
  }
  const choices = $("choices");
  choices.replaceChildren();
  for (const one of picks?.choices || []) {
    const row = make("tr");
    row.dataset.pick = String(one.pick);
    row.dataset.model = String(one.model);
    modelCell(row, one.model, one.name);
    cell(row, when(one.chosen_at));
    cell(row, when(one.until));
    cell(row, one.shown ? "yes" : one.test ? "no: a test account's" : "no: not in the gallery now", one.shown ? "" : "faint");
    const acts = make("td", "acts");
    acts.append(act("End", () => post({ op: "unpick", pick: one.pick }, "pick-note", "Ended: back to the pick worked out.",
      { after: again })));
    row.append(acts);
    choices.append(row);
  }
  const week = $("week");
  week.replaceChildren();
  for (const one of picks?.week || []) {
    if (!one.model) continue;
    const row = make("tr");
    modelCell(row, one.model.id, one.model.name);
    cell(row, String(one.week?.builds ?? 0), "n");
    cell(row, String(one.week?.remixes ?? 0), "n");
    cell(row, one.week?.tested ? "yes" : "no", one.week?.tested ? "" : "faint");
    cell(row, String(one.week?.score ?? 0), "n");
    const acts = make("td", "acts");
    acts.append(pickButton(one.model.id, one.model.name));
    row.append(acts);
    week.append(row);
  }
  if (picks && !(picks.choices || []).length) emptyRow(choices, "None chosen.");
  if (picks && !(picks.week || []).length) emptyRow(week, "Nothing in the past seven days to work one out from.");
}

// --- Challenges -------------------------------------------------------------

const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
const dayOf = (iso) => DAY.format(new Date(`${String(iso).slice(0, 10)}T00:00:00Z`));

/// The challenges, the ones not yet ended first and then the ended ones,
/// the one that ended last first (supabase/challenge_list_order.sql), each
/// with its entries, votes and winners, and End it now on one not ended.
function drawChallenges(list) {
  const rows = $("challenges");
  rows.replaceChildren();
  const form = $("challenge-form");
  form.hidden = list === null;
  if (list === null || list === undefined) {
    say("challenge-note", "");
    emptyRow(rows, "Not open yet: supabase/challenges.sql is not applied.");
    return;
  }
  for (const one of list) {
    const row = make("tr");
    row.dataset.challenge = String(one.id);
    row.dataset.state = one.state;
    cell(row, `${one.title}${one.test ? " (a test's)" : ""}`, "about");
    cell(row, `${dayOf(one.starts_on)} to ${dayOf(one.ends_on)}`);
    const rules = [];
    if (one.rules?.most_parts) rules.push(`at most ${Number(one.rules.most_parts).toLocaleString()} parts`);
    if (one.rules?.set_number) rules.push(`set ${one.rules.set_number}${one.rules.set_name ? `, ${one.rules.set_name}` : ""}`);
    if (one.rules?.tested) rules.push("Tested");
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
      const to = make("a", "", w.name || w.model);
      to.href = `/m/${encodeURIComponent(w.model)}`;
      if (won.childElementCount) won.append(make("br"));
      won.append(to, ` (${w.way === "hand" ? "by hand" : "assistant"}, ${w.votes})`);
    }
    if (!won.childElementCount) {
      won.textContent = one.state === "ended" ? (one.settled ? "none" : "counted when shown") : "—";
      won.classList.add("faint");
    }
    row.append(won);
    const acts = make("td", "acts");
    if (one.state !== "ended") {
      acts.append(act("End it now", () => (confirm(`End "${one.title}" now? No more entries or votes.`)
        ? post({ op: "end_challenge", challenge: one.id }, "challenge-note", `"${one.title}" has ended.`, { after: again })
        : Promise.resolve(false))));
    }
    row.append(acts);
    rows.append(row);
  }
  if (!list.length) emptyRow(rows, "None set yet.");
}

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
  "November", "December"];

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
      choose("month", "Month", MONTHS.map((name, at) => [at + 1, name])),
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

// The report an email named, kept in view while the page above it settles:
// pictures and sections that came in after it was centred pushed it out of
// view (digest_flow, 2026-10-19). Only until the person scrolls themselves.
export function keepInView(row) {
  row.scrollIntoView({ block: "center" });
  let mine = true;
  const observer = new ResizeObserver(() => { if (mine) row.scrollIntoView({ block: "center" }); });
  const stop = () => { mine = false; observer.disconnect(); };
  observer.observe(document.body);
  for (const kind of ["wheel", "touchstart", "keydown", "mousedown"]) {
    addEventListener(kind, stop, { once: true, passive: true });
  }
  setTimeout(stop, 10000);
}

