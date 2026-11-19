// The console's Analytics (admin.html #analytics, insights 2026-11-18;
// docs/ANALYTICS.md): how the site and the studio are used, from
// /api/admin?op=analytics (api/_analytics.js, supabase/analytics.sql). One
// read draws every tab; the filters above them read again.
//
// The section's tabs, filters and charts are made here, at import, so
// admin.html keeps only its heading. Charts follow the dataviz method: one
// series each (no colour to tell apart), thin marks, a hairline grid, a
// tooltip on hover and focus, and every chart a table too. Every number's
// name links to what it means (the Definitions tab).
//
// Everything is put on the page as text, never as markup.
import { $, adminJson, count, day, make, say } from "/admin-kit.js";

export const TABS = ["overview", "funnels", "retention", "pages", "studio", "sources", "speed", "errors", "claude", "definitions"];
const TAB_NAMES = { overview: "Overview", funnels: "Funnels", retention: "Retention", pages: "Pages", studio: "The studio",
  sources: "Sources", speed: "Speed", errors: "Errors", claude: "Claude", definitions: "Definitions" };
// What the studio has, so what is never used shows: its tools
// (src/ui/edit_verbs.gd MODES) and the panels web/tally.js watches (PANELS).
export const TOOLS = ["select", "place", "move", "rotate", "hinge", "connect", "clone", "paint", "hide", "delete", "orbit", "pan", "zoom"];
export const PANELS = ["parts", "assistant", "properties", "palette", "app_menu", "page_editor", "saved_models", "versions", "feedback",
  "split_view", "see_inside", "xray", "step_playback", "reference", "minifig", "simulate", "render"];

// What every number means: the Definitions tab, and where each name links.
export const TERMS = {
  people: ["People", "In a table: the people who did it, a day at a time, added up over the days (person-days), so somebody who did it on three days counts three. On one day a signed-in account counts once, on however many devices; a signed-out visit counts once, as nothing ties two of them together."],
  visits: ["Visits", "A visit is one browser tab's time on the site and in the studio, ended by 30 minutes away. Pages opened in the same tab are one visit."],
  visitors: ["Visitors", "People on a day: a signed-in account once, a signed-out visit once (nothing ties two of them together). Added up over the days, so somebody back on three days counts three times, as daily counters such as Plausible's do."],
  signups: ["Sign-ups", "Accounts made in the range, from the accounts themselves, not from what was counted: the plan filter narrows them, the device and language filters do not."],
  builders: ["Active builders", "People who put down at least one part in the studio on a day, added up over the days as visitors are."],
  published: ["Published", "Models published to the gallery in the range, from the gallery itself, by accounts the plan filter keeps (the device and language filters do not narrow them)."],
  calls: ["Claude calls", "Tool calls a person's Claude made through the connector, each counted once whatever it answered."],
  funnel_accounts: ["Sign-up funnel", "Of the accounts made in the range: how many have since put down a part in the studio, saved a model, and published one. A step counts whenever it happened, before the range's end or after."],
  funnel_visits: ["Visit funnel", "Of the visits in the range: how many opened the studio, put down a part, saved a model, and were signed in. Each visit once, at its furthest."],
  retention: ["Retention", "Accounts by the week (Monday to Sunday, UTC) they signed up, and the share of them active in each week after: in the studio, on the site signed in, or through Claude. Week 0 is the week they joined."],
  tool: ["Tools", "Each time a tool was picked in the studio, how long it stayed picked in all, and by how many people."],
  panel: ["Panels and dialogs", "Each time a panel or dialog opened, and by how many people."],
  press: ["Controls pressed", "Each press or tap on a named control in the studio (a button, a field, a tab), by its name in the app's code."],
  command: ["Commands", "Commands run from the command palette (Ctrl K), by name; a part searched for there is find_part."],
  run: ["Runs", "Simulate, Render, booklets and Building together: how many ran, how many worked (Simulate with nothing wrong said, a render with a file made), and how long they took."],
  leave: ["Where visits stopped", "Each visit's last act: the page, tool, panel, press or run it did last. A visit counts where it stopped."],
  never: ["Never used", "Tools and panels the studio has that nobody used in the range: a tool counts however it was picked (a press, a key, the palette or Claude), and a panel however it opened. And controls shown at least once (since counting began) that nobody pressed with a pointer or finger in the range, and whose tool or command nobody used either. Keys, shortcuts and Claude's own uses of a control are not seen as presses, so a control on that list may still be used that way."],
  milestone: ["Firsts", "How long after the studio came up (its own start mark) the first part was put down and the first model saved, in the visits that did."],
  view: ["Pages", "Pages opened, by kind: a model's page is /m/:id, never which model. An address the site did not make is /other."],
  act: ["Site acts", "What people did that the site's API wrote: a like, a comment, a follow, an entry, a sign-in code, by the API's name and op. Failed is an answer of 400 or more."],
  channel: ["Channels", "Where a visit came from: search, social (a post's link or a social site), AI (an assistant's answer), email, paid, another site (referral), or direct (none of these)."],
  source: ["Sources", "The site that linked to the visit's first page, or its utm_source, by name only."],
  campaign: ["Campaigns", "A link's utm_campaign. The social desk's own posts are bw- and the post's id, joined here with what was posted."],
  load: ["Load times", "As the browser timed them. On the site, one visit in four: LCP (the largest thing drawn), FCP (the first thing drawn), TTFB (the first byte), INP (the slowest answer to a press) and CLS (how far things jumped, ×1000). In the studio, every visit: each start mark from the page's start (studio_ui is the studio ready to use)."],
  frames: ["Frame times", "How long the studio's frames took, three seconds at a time (a minute in, then every five minutes): each sample's middle frame and its 95th percentile."],
  error: ["Errors", "Where an error happened, never what it said: a site script's file and line, or the studio's script and line (res://…gd)."],
  call: ["Claude's tools", "Each tool a person's Claude called through the connector: how often, by how many people, how many failed (an error, or an answer marked as one) and how long the round trip took."],
  p50: ["p50, p75, p95", "Percentiles: half of the times were at most p50, three in four at most p75, nineteen in twenty at most p95. Over many days, each day's percentile weighted by its count."],
  test: ["The checks' own", "With ?tests=1 the console shows only what the site's own checks sent, kept apart from people's."],
};

const RAMP_LIGHT = ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95"];
const RAMP_DARK = ["#184f95", "#1c5cab", "#256abf", "#3987e5", "#6da7ec", "#9ec5f4"];

const LOOK = `
.insights { --viz-1: #3987e5; --viz-muted: #6b717c; --viz-grid: rgba(255, 255, 255, 0.07); --viz-axis: rgba(255, 255, 255, 0.2); }
:root[data-theme="light"] .insights { --viz-1: #2a78d6; --viz-muted: #9aa0a8; --viz-grid: rgba(17, 19, 23, 0.07); --viz-axis: rgba(17, 19, 23, 0.25); }
@media (prefers-color-scheme: light) { :root:not([data-theme]) .insights { --viz-1: #2a78d6; --viz-muted: #9aa0a8;
  --viz-grid: rgba(17, 19, 23, 0.07); --viz-axis: rgba(17, 19, 23, 0.25); } }
.insights.reading [data-tab] { opacity: 0.55; transition: opacity 120ms; }
.insights .filters { display: flex; flex-wrap: wrap; gap: var(--s-2) var(--s-3); align-items: end; margin: 0 0 var(--s-5); }
.insights .filters label { display: grid; gap: 2px; font-size: var(--t-tiny); color: var(--ink-faint); }
.insights .filters select, .insights .filters input { min-width: 0; }
.insights .filters .dates { display: flex; gap: var(--s-2); }
.insights .filters .dates input { width: 9.5em; }
.insights .stats { grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); }
.insights .stat svg { display: block; width: 100%; height: 28px; margin-top: var(--s-2); }
.insights a.term { color: inherit; text-decoration: underline dotted; text-underline-offset: 3px; text-decoration-thickness: 1px; }
.insights figure { margin: 0 0 var(--s-6); }
.insights figcaption { display: flex; flex-wrap: wrap; gap: var(--s-2); justify-content: space-between; align-items: baseline;
  margin: 0 0 var(--s-2); font-weight: 600; }
.insights figcaption small { font-weight: 400; color: var(--ink-faint); }
.insights .plot { position: relative; padding: var(--s-3); border: 1px solid var(--line); border-radius: var(--radius); background: var(--panel); }
.insights .plot svg { display: block; width: 100%; overflow: visible; }
.insights .plot text { fill: var(--ink-faint); font-size: 11px; font-variant-numeric: tabular-nums; }
.insights .plot .grid { stroke: var(--viz-grid); stroke-width: 1; }
.insights .plot .base { stroke: var(--viz-axis); stroke-width: 1; }
.insights .plot .bar { fill: var(--viz-1); }
.insights .plot .hit { fill: transparent; outline: none; }
.insights .plot .hit:hover + .bar, .insights .plot .hit:focus-visible + .bar { fill-opacity: 0.75; }
.insights .plot .hit:focus-visible { stroke: var(--ink); stroke-width: 1; }
.insights .tip { position: absolute; z-index: 5; pointer-events: none; padding: 6px 10px; border: 1px solid var(--line-strong);
  border-radius: var(--r-2, 8px); background: var(--panel); box-shadow: var(--shadow); font-size: var(--t-tiny); white-space: nowrap; }
.insights .tip b { display: block; font-size: var(--t-small); color: var(--ink); font-variant-numeric: tabular-nums; }
.insights .tip span { color: var(--ink-soft); }
.insights details.as-table { margin-top: var(--s-2); font-size: var(--t-small); }
.insights details.as-table summary { cursor: pointer; color: var(--ink-soft); }
.insights .meter { display: flex; align-items: center; gap: var(--s-2); min-width: 120px; }
.insights .meter i { display: block; height: 8px; min-width: 2px; border-radius: 0 4px 4px 0; background: var(--viz-1); }
.insights .meter span { font-variant-numeric: tabular-nums; color: var(--ink); }
.insights td.name { overflow-wrap: anywhere; min-width: 120px; max-width: 320px; font-family: var(--mono, ui-monospace, monospace); font-size: var(--t-tiny); color: var(--ink); }
.insights .heat td.cell { text-align: center; font-variant-numeric: tabular-nums; min-width: 3.2em; border-left: 2px solid var(--panel); }
.insights .never { display: flex; flex-wrap: wrap; gap: var(--s-2); margin: 0 0 var(--s-5); padding: 0; list-style: none; }
.insights .never li { padding: 2px 10px; border: 1px solid var(--line-strong); border-radius: 999px; font-size: var(--t-tiny);
  font-family: var(--mono, ui-monospace, monospace); overflow-wrap: anywhere; }
.insights .grid2 { display: grid; gap: var(--s-6) var(--s-6); grid-template-columns: minmax(0, 1fr); }
@media (width >= 1100px) { .insights .grid2 { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
.insights .grid2 > * { min-width: 0; }
.insights .grid2 .part + .part { margin-top: 0; }
.insights dl.defs { display: grid; gap: var(--s-2) var(--s-5); margin: 0; }
@media (width >= 700px) { .insights dl.defs { grid-template-columns: 13em minmax(0, 1fr); } }
.insights dl.defs dt { font-weight: 600; scroll-margin-top: 96px; }
.insights dl.defs dd { margin: 0 0 var(--s-2); color: var(--ink-soft); max-width: 75ch; }
.insights dl.defs dt.lit { color: var(--accent-ink, var(--ink)); }
.insights .pill.ok { color: var(--green, #0ca30c); border-color: currentColor; }
.insights .pill.mid { color: var(--ink); border-color: #fab219; }
.insights .pill.bad { color: var(--bad); border-color: var(--bad); }
`;

// ---------------------------------------------------------------------------
// Words.

const ms = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n)) return "—";
  if (n < 1000) return `${Math.round(n)} ms`;
  if (n < 60000) return `${(n / 1000).toFixed(n < 10000 ? 2 : 1)} s`;
  if (n < 3600000) return `${Math.round(n / 60000)} min`;
  return `${Math.floor(n / 3600000)} h ${Math.round((n % 3600000) / 60000)} min`;
};
const share = (part, whole) => (whole > 0 ? `${Math.round((100 * part) / whole)}%` : "—");
const compact = (n) => (n >= 10000 ? `${(n / 1000).toFixed(n >= 100000 ? 0 : 1)}K` : count(n));

/// [text] as a link to what [key] means.
function term(key, text = TERMS[key]?.[0] || key) {
  const a = make("a", "term", text);
  a.href = "#analytics/definitions";
  a.dataset.term = key;
  return a;
}

// ---------------------------------------------------------------------------
// The section, made once.

const part = document.querySelector('[data-section="analytics"]');
const STORE = "brickworks.admin.analytics";
let asked = { range: "30", from: "", to: "", plan: "", device: "", lang: "", signed: "" };
try {
  asked = { ...asked, ...JSON.parse(sessionStorage.getItem(STORE) || "{}") };
} catch {
  // A tab that keeps nothing starts at the last 30 days.
}
let data = null;
const panes = {};

function select(id, label, options) {
  const box = make("select");
  box.id = id;
  for (const [value, words] of options) {
    const option = make("option", "", words);
    option.value = value;
    box.append(option);
  }
  return make("label", "", label, box);
}

function build() {
  if (!part || part.dataset.built) return;
  part.dataset.built = "1";
  part.classList.add("insights");
  const look = make("style");
  look.textContent = LOOK;
  document.head.append(look);
  const notYet = make("p", "note bad");
  notYet.id = "an-not-yet";
  notYet.setAttribute("role", "alert");
  notYet.hidden = true;
  const tabs = make("nav", "tabs scroller");
  tabs.setAttribute("aria-label", "Analytics");
  for (const tab of TABS) {
    const a = make("a", "", TAB_NAMES[tab]);
    a.href = `#analytics/${tab}`;
    a.dataset.tabLink = tab;
    tabs.append(a);
  }
  const filters = make("div", "filters");
  filters.setAttribute("role", "group");
  filters.setAttribute("aria-label", "What to count");
  const dates = make("div", "dates");
  const from = make("input");
  from.type = "date";
  from.id = "an-from";
  from.setAttribute("aria-label", "From");
  const to = make("input");
  to.type = "date";
  to.id = "an-to";
  to.setAttribute("aria-label", "To");
  dates.append(from, to);
  filters.append(
    select("an-range", "Range", [["1", "Today"], ["7", "Last 7 days"], ["30", "Last 30 days"], ["90", "Last 90 days"],
      ["365", "Last year"], ["custom", "From, to"]]),
    make("label", "", "Days (UTC)", dates),
    select("an-plan", "Plan", [["", "Everyone but you"], ["all", "Everyone"], ["free", "Free"], ["tester", "Beta testers"],
      ["pro", "Pro"], ["none", "Signed out"], ["owner", "You"]]),
    select("an-device", "Device", [["", "Every device"], ["desktop", "Desktop"], ["phone", "Phone"], ["tablet", "Tablet"]]),
    select("an-lang", "Language", [["", "Every language"], ["en", "English"], ["de", "Deutsch"], ["fr", "Français"], ["es", "Español"]]),
    select("an-signed", "Signed in", [["", "Signed in or not"], ["yes", "Signed in"], ["no", "Signed out"]]),
  );
  const said = make("p", "note");
  said.id = "an-said";
  said.setAttribute("role", "status");
  part.append(notYet, tabs, filters, said);
  for (const tab of TABS) {
    const pane = make("div");
    pane.dataset.tab = tab;
    pane.hidden = true;
    panes[tab] = pane;
    part.append(pane);
  }
  const tip = make("div", "tip");
  tip.id = "an-tip";
  tip.hidden = true;
  tip.setAttribute("aria-hidden", "true");
  part.append(tip);

  for (const id of ["an-range", "an-plan", "an-device", "an-lang", "an-signed"]) $(id).addEventListener("change", changed);
  for (const id of ["an-from", "an-to"]) $(id).addEventListener("change", () => {
    $("an-range").value = "custom";
    changed();
  });
  // A number's name: its definition shown and lit.
  part.addEventListener("click", (event) => {
    const a = event.target.closest("a.term");
    if (!a) return;
    const key = a.dataset.term;
    setTimeout(() => lightTerm(key), 30);
  });
  drawFilters();
  drawDefinitions();
  // The heatmap's steps are the theme's own: drawn again when it changes.
  new MutationObserver(() => data && drawRetention()).observe(document.documentElement, { attributes: true,
    attributeFilter: ["data-theme"] });
}

function lightTerm(key) {
  const dt = document.getElementById(`def-${key}`);
  if (!dt) return;
  for (const one of part.querySelectorAll("dt.lit")) one.classList.remove("lit");
  dt.classList.add("lit");
  dt.scrollIntoView({ block: "start" });
  dt.focus({ preventScroll: true });
}

const isoDay = (date) => date.toISOString().slice(0, 10);

/// The range asked, as days: {from, to}.
function rangeOf() {
  const today = new Date();
  if (asked.range === "custom" && asked.from && asked.to) return { from: asked.from, to: asked.to };
  const days = Number(asked.range) || 30;
  return { from: isoDay(new Date(today.getTime() - (days - 1) * 86400000)), to: isoDay(today) };
}

function drawFilters() {
  const { from, to } = rangeOf();
  $("an-range").value = asked.range;
  $("an-from").value = from;
  $("an-to").value = to;
  $("an-plan").value = asked.plan;
  $("an-device").value = asked.device;
  $("an-lang").value = asked.lang;
  $("an-signed").value = asked.signed;
}

function changed() {
  asked = { range: $("an-range").value, from: $("an-from").value, to: $("an-to").value, plan: $("an-plan").value,
    device: $("an-device").value, lang: $("an-lang").value, signed: $("an-signed").value };
  if (asked.range !== "custom") {
    const { from, to } = rangeOf();
    asked.from = from;
    asked.to = to;
  }
  try {
    sessionStorage.setItem(STORE, JSON.stringify(asked));
  } catch {
    // Kept for this page only.
  }
  drawFilters();
  read().catch((problem) => say("an-said", problem.message, true));
}

async function read() {
  const { from, to } = rangeOf();
  const query = { op: "analytics", from, to };
  for (const key of ["plan", "device", "lang", "signed"]) if (asked[key]) query[key] = asked[key];
  part.classList.add("reading");
  say("an-said", "Reading…");
  try {
    data = await adminJson(query);
  } finally {
    part.classList.remove("reading");
  }
  draw();
}

/// The section's loader (web/admin.js): made, then read.
export async function loadAnalytics() {
  build();
  await read();
}

// ---------------------------------------------------------------------------
// Charts.

const SVG = "http://www.w3.org/2000/svg";
function svg(tag, attrs = {}) {
  const made = document.createElementNS(SVG, tag);
  for (const [key, value] of Object.entries(attrs)) made.setAttribute(key, String(value));
  return made;
}

/// A sparkline of [values]: the line in the quiet hue, the last day in the series'.
function spark(values) {
  const w = 160;
  const h = 28;
  const most = Math.max(1, ...values);
  const shape = svg("svg", { viewBox: `0 0 ${w} ${h}`, preserveAspectRatio: "none", "aria-hidden": "true" });
  if (values.length < 2) return shape;
  const x = (at) => (at / (values.length - 1)) * (w - 6) + 3;
  const y = (v) => h - 3 - (v / most) * (h - 6);
  shape.append(svg("polyline", { points: values.map((v, at) => `${x(at)},${y(v)}`).join(" "), fill: "none",
    stroke: "var(--viz-muted)", "stroke-width": 2, "stroke-linejoin": "round", "stroke-linecap": "round",
    "vector-effect": "non-scaling-stroke" }));
  shape.append(svg("circle", { cx: x(values.length - 1), cy: y(values.at(-1)), r: 3, fill: "var(--viz-1)" }));
  return shape;
}

/// A clean top for an axis that reaches [most], and its ticks.
function ticksOf(most) {
  if (most <= 0) return [0, 1];
  const step = 10 ** Math.floor(Math.log10(most));
  const nice = [1, 2, 2.5, 5, 10].map((k) => k * step).find((s) => most / s <= 4) || step * 10;
  const top = Math.ceil(most / nice) * nice;
  const out = [];
  for (let at = 0; at <= top + 1e-9; at += nice) out.push(Math.round(at * 100) / 100);
  return out;
}

function tipAt(event, words, value) {
  const tip = $("an-tip");
  tip.replaceChildren(make("b", "", value), make("span", "", words));
  tip.hidden = false;
  const box = part.getBoundingClientRect();
  const at = event.target.getBoundingClientRect();
  const left = Math.min(Math.max(0, at.left - box.left + at.width / 2 - tip.offsetWidth / 2), box.width - tip.offsetWidth);
  tip.style.left = `${left}px`;
  tip.style.top = `${at.top - box.top - tip.offsetHeight - 6}px`;
}
const tipGone = () => {
  const tip = $("an-tip");
  if (tip) tip.hidden = true;
};

/// A column a day of [points] ({day, value}), with [title] and what a
/// column is ([unit]); its table under it.
function columns(title, key, points, unit) {
  const figure = make("figure");
  const total = points.reduce((sum, p) => sum + p.value, 0);
  figure.append(make("figcaption", "", term(key, title), make("small", "", `${count(total)} in all`)));
  const plot = make("div", "plot");
  figure.append(plot);
  // The day a key is on: the chart's one Tab stop (inreview L7: a stop a
  // day made 60 of them on Overview); the arrow keys, Home and End move it.
  let lit = points.length - 1;
  const draw = () => {
    const w = Math.max(240, plot.clientWidth - 24);
    const h = 160;
    const left = 36;
    const bottom = 20;
    const ticks = ticksOf(Math.max(0, ...points.map((p) => p.value)));
    const top = ticks.at(-1) || 1;
    const shape = svg("svg", { viewBox: `0 0 ${w} ${h + bottom}`, role: "group",
      "aria-label": `${title}, a column a day, ${count(total)} in all; the arrow keys go from day to day` });
    const hits = [];
    const y = (v) => h - (v / top) * (h - 8);
    for (const t of ticks) {
      shape.append(svg("line", { x1: left, x2: w, y1: y(t), y2: y(t), class: t === 0 ? "base" : "grid" }));
      const label = svg("text", { x: left - 6, y: y(t) + 4, "text-anchor": "end" });
      label.textContent = compact(t);
      shape.append(label);
    }
    const slot = (w - left) / Math.max(1, points.length);
    const width = Math.max(1, Math.min(24, slot - 2));
    points.forEach((p, at) => {
      const x = left + at * slot + (slot - width) / 2;
      const hit = svg("rect", { x: left + at * slot, y: 0, width: slot, height: h, class: "hit", tabindex: at === lit ? 0 : -1,
        role: "img", "aria-label": `${day(`${p.day}T12:00:00Z`)}: ${count(p.value)} ${unit}` });
      hits.push(hit);
      hit.addEventListener("keydown", (event) => {
        const to = { ArrowLeft: at - 1, ArrowDown: at - 1, ArrowRight: at + 1, ArrowUp: at + 1, Home: 0, End: points.length - 1 }[event.key];
        if (to === undefined) return;
        event.preventDefault();
        lit = Math.max(0, Math.min(points.length - 1, to));
        hits.forEach((one, n) => one.setAttribute("tabindex", n === lit ? "0" : "-1"));
        hits[lit].focus();
      });
      const show = (event) => tipAt(event, day(`${p.day}T12:00:00Z`), `${count(p.value)} ${unit}`);
      hit.addEventListener("pointerenter", show);
      hit.addEventListener("focus", show);
      hit.addEventListener("pointerleave", tipGone);
      hit.addEventListener("blur", tipGone);
      shape.append(hit);
      if (p.value > 0) {
        const height = Math.max(1, h - y(p.value));
        const r = Math.min(4, width / 2, height);
        // Rounded at its data end, square at the baseline.
        shape.append(svg("path", { class: "bar", d: `M${x},${h} v${-(height - r)} q0,${-r} ${r},${-r} h${width - 2 * r} `
          + `q${r},0 ${r},${r} v${height - r} z` }));
      } else shape.append(svg("g"));
    });
    const labels = points.length > 1 ? [0, Math.floor((points.length - 1) / 2), points.length - 1] : [0];
    for (const at of [...new Set(labels)]) {
      const label = svg("text", { x: left + at * slot + slot / 2, y: h + 15, "text-anchor": at === 0 ? "start" : at === points.length - 1 ? "end" : "middle" });
      label.textContent = day(`${points[at].day}T12:00:00Z`);
      shape.append(label);
    }
    plot.replaceChildren(shape);
  };
  requestAnimationFrame(draw);
  const watch = new ResizeObserver(() => draw());
  watch.observe(plot);
  watching.push(watch);
  figure.append(asTable(["Day", unit], points.map((p) => [day(`${p.day}T12:00:00Z`), count(p.value)])));
  return figure;
}

/// A chart's table: [heads] and [rows] of text.
function asTable(heads, rows) {
  const details = make("details", "as-table");
  details.append(make("summary", "", "As a table"));
  const table = make("table");
  const head = make("tr");
  heads.forEach((words, at) => head.append(make("th", at ? "n" : "", words)));
  table.append(make("thead", "", head));
  const body = make("tbody");
  for (const row of rows) {
    const tr = make("tr");
    row.forEach((words, at) => tr.append(make("td", at ? "n" : "", words)));
    body.append(tr);
  }
  table.append(body);
  details.append(make("div", "table", table));
  return details;
}

/// A ranked table: [columns] [{head, key?, value(row), text?(row), bar?}],
/// [rows], with a bar beside the column marked bar. Empty: [none].
function ranked(title, key, columns, rows, none = "Nothing counted in this range.") {
  const section = make("div", "part");
  section.append(make("div", "lead", make("h3", "", term(key, title))));
  const table = make("table");
  const head = make("tr");
  for (const c of columns) {
    const th = make("th", c.n ? "n" : "", c.key ? term(c.key, c.head) : c.head);
    th.scope = "col";
    head.append(th);
  }
  table.append(make("thead", "", head));
  const body = make("tbody");
  const barred = columns.find((c) => c.bar);
  const most = barred ? Math.max(1, ...rows.map((r) => Number(barred.value(r)) || 0)) : 1;
  for (const row of rows) {
    const tr = make("tr");
    for (const c of columns) {
      const value = c.value(row);
      const text = c.text ? c.text(row) : typeof value === "number" ? count(value) : String(value ?? "—");
      if (c.bar) {
        const meter = make("div", "meter");
        const bar = make("i");
        bar.style.width = `${Math.round((100 * (Number(value) || 0)) / most)}%`;
        bar.style.maxWidth = "160px";
        meter.append(bar, make("span", "", text));
        const td = make("td", "", meter);
        td.dataset.value = String(value);
        tr.append(td);
      } else tr.append(make("td", c.n ? "n" : c.name ? "name" : "", text));
    }
    body.append(tr);
  }
  if (!rows.length) {
    const tr = make("tr", "none");
    const td = make("td", "faint", none);
    td.colSpan = columns.length;
    tr.append(td);
    body.append(tr);
  }
  table.append(body);
  const holder = make("div", "table", table);
  holder.tabIndex = 0;
  holder.setAttribute("role", "region");
  holder.setAttribute("aria-label", title);
  section.append(holder);
  return section;
}

// ---------------------------------------------------------------------------
// The tabs.

const used = (kind, surface) => (data?.used || []).filter((u) => u.kind === kind && (!surface || u.surface === surface));

// Each chart redrawn at its own width; let go when the charts are made again.
const watching = [];

function draw() {
  for (const watch of watching.splice(0)) watch.disconnect();
  const ready = data?.ready !== false;
  const notYet = $("an-not-yet");
  notYet.hidden = ready;
  notYet.textContent = ready ? "" : "Nothing is counted yet on this database: supabase/analytics.sql is not applied here.";
  const range = data?.range || {};
  const kept = range.kept_from ? ` Each count as sent is kept from ${day(`${range.kept_from}T12:00:00Z`)}; past it, each day's totals.` : "";
  say("an-said", ready ? `${day(`${data.from}T12:00:00Z`)} to ${day(`${data.to}T12:00:00Z`)} (UTC)${data.tests ? ", the checks' own" : ""}.${kept}`
    + `${data.hashed === false ? " This deployment has no VIEW_SECRET: accounts are not told apart." : ""}` : "");
  if (!ready) {
    for (const tab of TABS) if (tab !== "definitions") panes[tab].replaceChildren();
    return;
  }
  drawOverview();
  drawFunnels();
  drawRetention();
  drawPages();
  drawStudio();
  drawSources();
  drawSpeed();
  drawErrors();
  drawClaude();
}

function drawOverview() {
  const days = data.days || [];
  const sum = (key) => days.reduce((total, d) => total + (Number(d[key]) || 0), 0);
  const stats = make("div", "stats");
  for (const [key, field, words] of [["visitors", "visitors", "visitors"], ["visits", "visits", "visits"], ["signups", "signups", "sign-ups"],
    ["builders", "builders", "active builders"], ["published", "published", "published"], ["calls", "calls", "Claude calls"]]) {
    const total = sum(field);
    const stat = make("div", "stat");
    stat.dataset.stat = key;
    stat.append(make("b", "", term(key, compact(total))), make("span", "", term(key, words)),
      make("small", "", `${(total / Math.max(1, days.length)).toFixed(1)} a day`), spark(days.map((d) => Number(d[field]) || 0)));
    stats.append(stat);
  }
  panes.overview.replaceChildren(stats,
    columns("Visitors", "visitors", days.map((d) => ({ day: d.day, value: Number(d.visitors) || 0 })), "visitors"),
    columns("Sign-ups", "signups", days.map((d) => ({ day: d.day, value: Number(d.signups) || 0 })), "sign-ups"));
}

function funnel(title, key, steps) {
  const first = steps[0]?.[1] || 0;
  return ranked(title, key, [
    { head: "Step", value: (s) => s[0] },
    { head: "How many", value: (s) => s[1], bar: true, text: (s) => count(s[1]) },
    { head: "Of the first", n: true, value: (s) => share(s[1], first) },
    { head: "Of the step before", n: true, value: (s) => s[2] },
  ], steps.map((s, at) => [s[0], s[1], at ? share(s[1], steps[at - 1][1]) : "—"]));
}

function drawFunnels() {
  const f = data.funnel || {};
  const reach = f.reach || {};
  panes.funnels.replaceChildren(make("div", "grid2",
    funnel("Sign-up funnel", "funnel_accounts", [["Signed up", f.signups || 0], ["Put down a part", f.first_part || 0],
      ["Saved a model", f.first_save || 0], ["Published", f.published || 0]]),
    funnel("Visit funnel", "funnel_visits", [["Visited", reach.visit || 0], ["Opened the studio", reach.studio || 0],
      ["Put down a part", reach.part || 0], ["Saved a model", reach.save || 0], ["Signed in", reach.signed_in || 0]])));
}

/// A cell's ink on [fill]: near-black on a light step, white on a dark one.
function inkOn(fill) {
  const [r, g, b] = [1, 3, 5].map((at) => parseInt(fill.slice(at, at + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.3 ? "#0b0b0b" : "#ffffff";
}
const lightNow = () => document.documentElement.dataset.theme === "light"
  || (!document.documentElement.dataset.theme && matchMedia("(prefers-color-scheme: light)").matches);

function drawRetention() {
  const rows = data.retention || [];
  const weeks = Math.min(12, Math.max(1, ...rows.map((r) => (r.back || []).length)));
  const table = make("table", "heat");
  const head = make("tr", "", make("th", "", "Week of"), make("th", "n", term("signups", "Signed up")));
  for (let at = 0; at < weeks; at += 1) head.append(make("th", "n", `Week ${at}`));
  table.append(make("thead", "", head));
  const body = make("tbody");
  const ramp = lightNow() ? RAMP_LIGHT : RAMP_DARK;
  for (const row of rows) {
    const tr = make("tr", "", make("td", "", day(`${row.week}T12:00:00Z`)), make("td", "n", count(row.size)));
    for (let at = 0; at < weeks; at += 1) {
      const back = (row.back || [])[at];
      const td = make("td", "cell");
      if (back === undefined) td.textContent = "";
      else {
        const part = row.size ? back / row.size : 0;
        const fill = ramp[Math.min(ramp.length - 1, Math.floor(part * ramp.length))];
        td.style.background = fill;
        td.style.color = inkOn(fill);
        td.textContent = share(back, row.size);
        td.title = `${count(back)} of ${count(row.size)} back in week ${at}`;
      }
      tr.append(td);
    }
    body.append(tr);
  }
  if (!rows.length) {
    const tr = make("tr", "none", make("td", "faint", "Nobody signed up in this range."));
    tr.firstChild.colSpan = weeks + 2;
    body.append(tr);
  }
  table.append(body);
  const holder = make("div", "table", table);
  holder.tabIndex = 0;
  holder.setAttribute("role", "region");
  holder.setAttribute("aria-label", "Retention by week");
  panes.retention.replaceChildren(make("div", "lead", make("h3", "", term("retention", "Retention by the week people signed up"))),
    make("p", "note", "Each cell: the share of that week's sign-ups active in that week since. Darker is more."), holder);
}

const cols = {
  name: { head: "Name", name: true, value: (u) => u.name },
  n: (head = "Times", key) => ({ head, key, value: (u) => Number(u.n) || 0, bar: true }),
  people: { head: "People", key: "people", n: true, value: (u) => Number(u.people) || 0 },
  visits: { head: "Visits", key: "visits", n: true, value: (u) => Number(u.visits) || 0 },
  failed: { head: "Failed", n: true, value: (u) => (u.failed ? `${count(u.failed)} (${share(u.failed, (u.ok || 0) + u.failed)})` : "0") },
  p50: { head: "p50", key: "p50", n: true, value: (u) => ms(u.p50) },
  p95: { head: "p95", key: "p50", n: true, value: (u) => ms(u.p95) },
  last: { head: "Last", n: true, value: (u) => (u.last ? day(`${u.last}T12:00:00Z`) : "—") },
};

function drawPages() {
  panes.pages.replaceChildren(make("div", "grid2",
    ranked("Pages", "view", [cols.name, cols.n("Opened"), cols.visits], used("view", "site")),
    ranked("Site acts", "act", [cols.name, cols.n(), cols.people, cols.failed], used("act", "site"))));
}

function drawStudio() {
  const tools = used("tool");
  const panels = used("panel");
  const presses = used("press");
  const neverTools = TOOLS.filter((t) => !tools.some((u) => u.name === t));
  const neverPanels = PANELS.filter((p) => !panels.some((u) => u.name === p));
  const pressed = new Set(presses.map((u) => u.name));
  // A control used another way than a press (inreview M6): its tool picked
  // (tool_mode_move is the tool move, however it was picked), or its command
  // run from the palette (tool_, phone_row_ and phone_quick_ name the
  // command they run, phone_ the phone's undo and redo).
  const ran = new Set(used("command").map((u) => u.name));
  const picked = new Set(tools.map((u) => u.name));
  const usedElse = (name) => {
    const command = (/^(?:tool_|phone_row_|phone_quick_|phone_)(.+)$/.exec(name) || [])[1];
    const mode = (/^mode_(.+)$/.exec(command || "") || [])[1];
    return Boolean(command && (ran.has(command) || (mode && picked.has(mode))));
  };
  const neverPressed = (data.seen || []).map((s) => s.name).filter((name) => !pressed.has(name) && !usedElse(name));
  const firsts = used("milestone");
  const never = make("div", "part", make("div", "lead", make("h3", "", term("never", "Never used in this range"))));
  for (const [words, list] of [["Tools", neverTools], ["Panels and dialogs", neverPanels], ["Controls shown, never pressed with a pointer or finger", neverPressed]]) {
    never.append(make("p", "note", `${words}: ${list.length ? count(list.length) : "none"}`));
    if (list.length) {
      const ul = make("ul", "never");
      for (const name of list.slice(0, 300)) ul.append(make("li", "", name));
      never.append(ul);
    }
  }
  panes.studio.replaceChildren(
    ranked("Firsts", "milestone", [{ head: "What", value: (u) => ({ studio: "The studio ready", first_part: "The first part",
      first_save: "The first save" })[u.name] || u.name }, { head: "Visits", key: "visits", n: true, value: (u) => Number(u.n) || 0 },
    cols.p50, { head: "p75", key: "p50", n: true, value: (u) => ms(u.p75) }, cols.p95], firsts),
    make("div", "grid2",
      ranked("Tools", "tool", [cols.name, cols.n("Picked"), { head: "Time in it", n: true, value: (u) => Number(u.ms_sum) || 0,
        text: (u) => ms(u.ms_sum) }, cols.people], tools),
      ranked("Panels and dialogs", "panel", [cols.name, cols.n("Opened"), cols.people], panels),
      ranked("Commands", "command", [cols.name, cols.n("Run"), cols.people], used("command")),
      ranked("Runs", "run", [cols.name, cols.n("Ran"), cols.failed, cols.p50, cols.p95], used("run")),
      ranked("Controls pressed", "press", [cols.name, cols.n("Pressed"), cols.people], presses.slice(0, 200)),
      ranked("Where visits stopped", "leave", [cols.name, cols.n("Visits")], used("leave").slice(0, 100))),
    never);
}

function drawSources() {
  const s = data.sources || {};
  panes.sources.replaceChildren(make("div", "grid2",
    ranked("Channels", "channel", [{ head: "Channel", value: (c) => c.channel }, { head: "Visits", key: "visits", value: (c) => Number(c.visits) || 0, bar: true },
      { head: "Sign-ups", key: "signups", n: true, value: (c) => Number(c.signups) || 0 }], s.channels || []),
    ranked("Sources", "source", [{ head: "Source", name: true, value: (c) => c.source }, { head: "Channel", value: (c) => c.channel },
      { head: "Visits", key: "visits", value: (c) => Number(c.visits) || 0, bar: true },
      { head: "Seconds a visit", n: true, value: (c) => count(c.seconds) }, { head: "Sign-ups", key: "signups", n: true, value: (c) => Number(c.signups) || 0 }],
    s.sources || [])),
  ranked("Campaigns", "campaign", [{ head: "Campaign", name: true, value: (c) => c.campaign },
    { head: "The post", value: (c) => (c.post ? [c.post.provider, c.post.community, c.post.title].filter(Boolean).join(" · ") : "—") },
    { head: "Visits", key: "visits", value: (c) => Number(c.visits) || 0, bar: true }, { head: "Sign-ups", key: "signups", n: true, value: (c) => Number(c.signups) || 0 }],
  s.campaigns || []));
}

// Good and poor at the 75th percentile (web.dev/articles/vitals).
const VITALS = { site_lcp: [2500, 4000], site_inp: [200, 500], site_cls: [100, 250], site_fcp: [1800, 3000], site_ttfb: [800, 1800] };

function rating(row) {
  const bounds = VITALS[row.name];
  if (!bounds || !Number.isFinite(Number(row.p75))) return make("span", "faint", "—");
  const [good, poor] = bounds;
  const p75 = Number(row.p75);
  const [cls, words] = p75 <= good ? ["ok", "✓ Good"] : p75 <= poor ? ["mid", "! Needs work"] : ["bad", "✕ Poor"];
  return make("span", `pill ${cls}`, words);
}

function drawSpeed() {
  const speed = data.speed || [];
  const shown = (row) => (row.name === "site_cls" ? (Number(row.p50) / 1000).toFixed(3) : ms(row.p50));
  const table = (title, key, rows, withRating) => ranked(title, key, [
    { head: "Measure", name: true, value: (r) => r.name }, { head: "Device", value: (r) => r.device || "—" },
    { head: "Browser", value: (r) => r.browser || "—" }, { head: "Timed", n: true, value: (r) => Number(r.n) || 0 },
    { head: "p50", key: "p50", n: true, value: (r) => shown(r) },
    { head: "p75", key: "p50", n: true, value: (r) => (r.name === "site_cls" ? (Number(r.p75) / 1000).toFixed(3) : ms(r.p75)) },
    { head: "p95", key: "p50", n: true, value: (r) => (r.name === "site_cls" ? (Number(r.p95) / 1000).toFixed(3) : ms(r.p95)) },
    ...(withRating ? [{ head: "At p75", value: (r) => r, text: () => "" }] : []),
  ], rows);
  const site = table("The site's pages", "load", speed.filter((r) => r.kind === "load" && r.name.startsWith("site_")), true);
  // The rating cell: a pill with its sign and its words, never colour alone.
  const ratedRows = speed.filter((r) => r.kind === "load" && r.name.startsWith("site_"));
  site.querySelectorAll("tbody tr:not(.none)").forEach((tr, at) => tr.lastElementChild.replaceChildren(rating(ratedRows[at])));
  panes.speed.replaceChildren(site,
    table("The studio's start", "load", speed.filter((r) => r.kind === "load" && r.name.startsWith("studio_")), false),
    table("The studio's frames", "frames", speed.filter((r) => r.kind === "frames"), false));
}

function drawErrors() {
  panes.errors.replaceChildren(ranked("Errors", "error", [cols.name, { head: "Where", value: (u) => u.surface }, cols.n("Times"),
    cols.visits, { head: "First", n: true, value: (u) => (u.first ? day(`${u.first}T12:00:00Z`) : "—") }, cols.last], used("error"),
  "No errors counted in this range."));
}

function drawClaude() {
  panes.claude.replaceChildren(ranked("Claude's tools", "call", [cols.name, cols.n("Calls"), cols.people, cols.failed, cols.p50, cols.p95],
    used("call", "mcp"), "No tool calls counted in this range."));
}

function drawDefinitions() {
  const dl = make("dl", "defs");
  for (const [key, [title, words]] of Object.entries(TERMS)) {
    const dt = make("dt", "", title);
    dt.id = `def-${key}`;
    dt.tabIndex = -1;
    dl.append(dt, make("dd", "", words));
  }
  panes.definitions.replaceChildren(make("div", "lead", make("h3", "", "What each number means")),
    make("p", "note", "How each is counted, and what is never counted, is in docs/ANALYTICS.md and on the site's own page, /counting."), dl);
}

build();
