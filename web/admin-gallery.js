// The console's Gallery (admin.html #gallery/...): what the gallery lists,
// this week's pick and the Tested marks, each with its acts beside it
// (api/admin.js). And the report they come from (/api/admin's GET, its
// default), which Moderation (admin-moderation.js) and Challenges
// (admin-challenges.js) draw from too: asked once, drawn by each, and
// asked again after any act of theirs.
//
// Names, notes and comments strangers wrote: text, never markup.
import { $, adminJson, ask, cell, emptyRow, make, post, resort, rowAct as act, say, sift, timeCell, when } from "/admin-kit.js";
import { token } from "/account.js";

// The token the page was last drawn with, for the photos it shows: renewing
// replaces the refresh token, so it is not renewed once per photo.
let drawnWith = "";
export const tokenDrawnWith = () => drawnWith;

// Each section that draws from the report, in the order it was added.
const drawers = [drawGallery];
/// [draw](report) called each time the report is read.
export function onReport(draw) { drawers.push(draw); }

/// The report, asked and drawn by every section that shows it.
export async function loadReport() {
  drawnWith = await token();
  const data = await adminJson({});
  for (const draw of drawers) draw(data);
  for (const box of document.querySelectorAll("[data-search]")) find(box);
  for (const table of document.querySelectorAll('[data-section="gallery"] table[data-sortable], '
    + '[data-section="moderation"] table[data-sortable]')) resort(table);
  return data;
}
export const loadGallery = loadReport;

/// After an act: the report again, and the nav's counts with it.
let onChange = () => {};
export function whenChanged(then) { onChange = then; }
export const again = async () => { await loadReport(); onChange(); };

function drawGallery(data) {
  const listed = (data?.gallery || []).length;
  $("tab-listed").textContent = listed ? String(listed) : "";
  drawListed(data);
  drawPicks(data.picks);
  drawTested(data.tested);
}

/// The search over a tab's table, as typed.
function find(box) {
  const body = $(box.dataset.search);
  if (body) sift(body, box.value);
}
for (const box of document.querySelectorAll("[data-search]")) box.addEventListener("input", () => find(box));

export function modelCell(row, id, name) {
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
    acts.append(act("Take out", async () => (await ask({ title: `Take "${model.name}" out of the gallery?`,
      body: "Its owner will not be able to list it again.", yes: "Take it out", danger: true }))
      && post({ op: "unlist", id: model.id }, "gallery-note", `"${model.name}" is out of the gallery.`, { after: again })));
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
    acts.append(act("Clear the mark", async () => (await ask({ title: `Clear the Tested mark of version ${mark.n}?`,
      body: "It is not marked Tested anywhere after.", yes: "Clear the mark", danger: true }))
      && post({ op: "untest", id: mark.model, v: mark.n }, "tested-note", "Cleared: it is not marked Tested anywhere now.",
        { after: again })));
    row.append(acts);
    tested.append(row);
  }
  say("tested-note", list?.length ? "" : "Nothing is marked Tested.");
}

// --- This week's pick -------------------------------------------------------

/// Make it the pick (api/admin.js ?op=pick), for a week.
function pickButton(id, name) {
  return act("Make it the pick", async () => (await ask({ title: `Make "${name}" this week's pick?`,
    body: "Visitors see it as the pick for seven days.", yes: "Make it the pick" }))
    && post({ op: "pick", id, days: 7 }, "pick-note", `"${name}" is this week's pick.`, { after: again }));
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

