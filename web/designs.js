// Your models, as a designer (2026-10-19, supabase/designers.sql): how each
// model you shared is doing, for you alone. The last 30 days' opens of its
// page, builds finished, remixes and comments, the same in all since it was
// shared, and who built it, from the photos people posted ("I built it").
//
// On your own profile (/u/<you>: #designs-mine, which this fills only when
// the server says the page is yours) and on Account (/profile, which calls
// showDesigns). Asked with your sign-in, from /api/people?op=designs
// (api/_designers.js), which answers nobody else with anything of yours and
// is never kept by the CDN; the page the CDN keeps has none of it.
//
// Against last month (insights2 and i2fix, 2026-11-22;
// supabase/designer_period_2.sql): when the server sends `period`, each
// model's views, builds finished, likes, saves, comments and remixes in the
// last 30 whole UTC days (ending yesterday) beside the 30 before, with the
// change (up, down, none before, no change) where both were counted in full, and
// otherwise from which day it was counted; the last 8 weeks as a chart from
// the first week counted (the console's: one series, a hairline grid, a tip
// on hover and focus, and its numbers as a table), each model's weeks as a
// line, and the models sorted by any of it. Without it, as before.
//
// Everything is put on the page as text, in the page's language (say: a
// person's page in German at /de/u/<you>).
import { call, signedIn } from "/account.js";
import { counted, number as said, say, setPhoto, sharpPhotos } from "/card.js";

const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const LOCALE = globalThis.brickworksLang?.code && globalThis.brickworksLang.code !== "en" ? globalThis.brickworksLang.code : "en-GB";
const DATE = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const number = (n) => said(Number(n) || 0);
/// Where the page's language's copies are: "/de" on a German page.
const AT = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? `/${globalThis.brickworksLang.code}` : "";

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

function link(href, text, className = "") {
  const a = make("a", className, text);
  a.href = href;
  return a;
}

/// One count: the last 30 days, large, and in all beneath.
function tile(kind, recent, ever, one, many, lead = false) {
  const li = make("li", lead ? "lead" : "", make("b", "", number(recent)), " ",
    make("span", "", Number(recent) === 1 ? one : many), make("small", "", say("{n} in all", { n: number(ever) })));
  li.dataset.earned = kind;
  return li;
}

/// What one model is: in the gallery or by link, credited or not, Tested.
function whatItIs(model) {
  const words = [model.listed ? say("In the gallery") : say("Shared by link")];
  if (!model.credited) words.push(say("without your name"));
  if (model.tested) words.push(`✓ ${say("Tested")}`);
  if (model.test) words.push(say("a test model"));
  return words.join(" · ");
}

function numbers(model) {
  const box = make("dl", "design-numbers");
  for (const [kind, label] of [["opens", say("Opens")], ["builds", say("Builds finished")], ["remixes", say("Remixes")],
    ["comments", say("Comments")]]) {
    const dd = make("dd", "", make("b", "", number(model[kind])), make("small", "", say("{n} in all", { n: number(model[`${kind}_ever`]) })));
    dd.dataset.kind = kind;
    box.append(make("div", "", make("dt", "", label), dd));
  }
  return box;
}

/// Who built it: the photos people posted of their builds, with their names.
function builders(model) {
  const photos = (model.photos || []).filter((one) => ID.test(String(one.id)));
  if (!photos.length) return null;
  // Inside the model's row, not at the page's edge: inset.
  const strip = make("div", "build-strip scroller inset");
  strip.setAttribute("role", "group");
  strip.setAttribute("aria-label", say("Builds of {name}", { name: model.name }));
  for (const one of photos) {
    const picture = document.createElement("img");
    picture.alt = say("A build of {name}", { name: model.name });
    picture.width = Number(one.width) || 1;
    picture.height = Number(one.height) || 1;
    picture.loading = "lazy";
    picture.decoding = "async";
    setPhoto(picture, one, "builders");
    const who = one.by && HANDLE.test(String(one.by.handle)) ? link(`${AT}/u/${one.by.handle}`, String(one.by.name))
      : make("span", "", say("A builder with no profile"));
    const figure = make("figure", "build", link(`${AT}/m/${model.id}#photo-${one.id}`, picture),
      make("figcaption", "", one.words ? make("q", "", String(one.words)) : null, who));
    figure.dataset.photo = one.id;
    strip.append(figure);
  }
  const more = Number(model.photos_count) - photos.length;
  return make("div", "design-builders",
    make("p", "", say("Who built it: {people} posted {photos}", { people: counted(model.builders, "person", "people"),
      photos: counted(model.photos_count, "photo") }),
    more > 0 ? make("span", "", " (", link(`${AT}/m/${model.id}#builds`, say("{n} more on its page", { n: number(more) })), ")") : null),
    strip);
}

// ---------------------------------------------------------------------------
// Against the 30 days before.

const KINDS = ["views", "builds", "likes", "saves", "comments", "remixes"];
const WEEKS = 8;
/// Each window's whole UTC days (the server's period.days).
const DAYS = 30;
const DAY_MS = 86400000;
const MINUS = "−";
/// Each kind's heading, and its count's words for one and for more.
const NAMED = {
  views: () => [say("Views"), say("view"), say("views")],
  builds: () => [say("Builds finished"), say("build finished"), say("builds finished")],
  likes: () => [say("Likes"), say("like"), say("likes")],
  saves: () => [say("Saves"), say("save"), say("saves")],
  comments: () => [say("Comments"), say("comment"), say("comments")],
  remixes: () => [say("Remixes"), say("remix"), say("remixes")],
};
/// What each counts, said beside the numbers (supabase/designer_period_2.sql).
const MEANS = {
  views: () => say("Visitors who opened its page: each once a day, never a robot, your own visits too."),
  builds: () => say("Devices that reached its last step, each once, on the day it first did."),
  likes: () => say("People who like it now, on the day they liked it. Not yours; a like taken back is not counted."),
  saves: () => say("People who keep it in Saved or one of their lists, private ones included, each once, from the day they first did. Only how many, never who; not yours."),
  comments: () => say("Comments anybody can see on its page, on the day they were written. Not yours, and only since its link was last shared."),
  remixes: () => say("Remixes of it shared, on the day each was."),
};
const SHORT = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "short", timeZone: "UTC" });
/// A share without its sign: the page writes the sign itself, so every
/// minus on it is the one minus sign (U+2212), as the counts' are.
const PERCENT = new Intl.NumberFormat(globalThis.brickworksLang?.locale || "en-US",
  { style: "percent", maximumFractionDigits: 0 });
/// Under ten per cent, a tenth of one: +0.2%, not +0%.
const PERCENT_FINE = new Intl.NumberFormat(globalThis.brickworksLang?.locale || "en-US",
  { style: "percent", maximumFractionDigits: 1 });
const percent = (ratio) => `${ratio < 0 ? MINUS : "+"}${(Math.abs(ratio) < 0.1 ? PERCENT_FINE : PERCENT).format(Math.abs(ratio))}`;
/// A day the server named ("2026-11-22"), at its noon UTC, [plus] days on.
const dayAt = (day, plus = 0) => Date.parse(`${day}T12:00:00Z`) + plus * DAY_MS;
const short = (day, plus = 0) => SHORT.format(dayAt(day, plus));
/// The day [plus] days on from [day], as the server writes one.
const dayPlus = (day, plus) => new Date(dayAt(day, plus)).toISOString().slice(0, 10);

/// Whether [counts] were counted on every day of both windows: only then is
/// the last 30 days set against the 30 before. Views are kept by the day
/// only from a day in October 2026, and a model only from the day it was
/// shared; a change against days nobody counted would be made up.
const whole = (counts) => Number(counts?.now_days) >= DAYS && Number(counts?.before_days) >= DAYS;

/// How [counts] moved: up, down, new (none in the 30 days before), none
/// (the same, nought included); or short: either window counted for under
/// 30 days, so no change is said.
function changeOf(counts) {
  if (!whole(counts)) return "short";
  const now = Number(counts?.now) || 0;
  const before = Number(counts?.before) || 0;
  if (now === before) return "none";
  if (!before) return "new";
  return now > before ? "up" : "down";
}

/// The change, in words and marked: "▲ +12 (+40%)", "▼ −3 (−20%)",
/// "▲ +12 (none before)", No change; or, counted for under 30 days of either
/// window, "Counted since 22 Oct" with no arrow and no per cent.
function changeSaid(counts) {
  const how = changeOf(counts);
  const now = Number(counts?.now) || 0;
  const before = Number(counts?.before) || 0;
  const mark = make("small", `change ${how}`);
  mark.dataset.change = how;
  if (how === "short") mark.append(counts?.from ? say("Counted since {day}", { day: short(counts.from) }) : say("Not counted yet"));
  else if (how === "none") mark.append(say("No change"));
  else {
    const arrow = make("span", "", how === "down" ? "▼" : "▲");
    arrow.setAttribute("aria-hidden", "true");
    mark.append(arrow, ` ${how === "down" ? MINUS : "+"}${number(Math.abs(now - before))} `
      + `(${how === "new" ? say("none before") : percent((now - before) / before)})`);
  }
  return mark;
}

/// One kind's counts as the page keeps them for the checks: data-now and the rest.
function marked(element, kind, counts) {
  element.dataset.kind = kind;
  element.dataset.now = String(Number(counts.now) || 0);
  element.dataset.before = String(Number(counts.before) || 0);
  element.dataset.ever = String(Number(counts.ever) || 0);
  element.dataset.from = counts.from || "";
  element.dataset.nowDays = String(Number(counts.now_days) || 0);
  element.dataset.beforeDays = String(Number(counts.before_days) || 0);
  element.dataset.change = changeOf(counts);
  return element;
}

/// A total: the last 30 days large, the change, the 30 before and in all.
function periodTile(kind, counts, lead) {
  const [, one, many] = NAMED[kind]();
  const li = make("li", lead ? "lead" : "", make("b", "", number(counts.now)), " ",
    make("span", "", Number(counts.now) === 1 ? one : many), changeSaid(counts),
    make("small", "", say("{n} the 30 days before", { n: number(counts.before) })),
    make("small", "", say("{n} in all", { n: number(counts.ever) })));
  marked(li, kind, counts).dataset.earned = kind;
  return li;
}

/// A model's six numbers, each as a total's.
function periodNumbers(model) {
  const box = make("dl", "design-numbers period");
  for (const kind of KINDS) {
    const counts = model.period[kind];
    const dd = marked(make("dd", "", make("b", "", number(counts.now)), changeSaid(counts),
      make("small", "", say("{n} the 30 days before", { n: number(counts.before) })),
      make("small", "", say("{n} in all", { n: number(counts.ever) }))), kind, counts);
    box.append(make("div", "", make("dt", "", NAMED[kind]()[0]), dd));
  }
  return box;
}

const SVG = "http://www.w3.org/2000/svg";
function svg(tag, attrs = {}) {
  const made = document.createElementNS(SVG, tag);
  for (const [key, value] of Object.entries(attrs)) made.setAttribute(key, String(value));
  return made;
}

/// The weeks of [weeks] that were counted, from the first: a week wholly
/// before counting began is null from the server, and is not drawn at all
/// (never as nought). [first] is where they begin among the 8, or -1.
function countedWeeks(weeks) {
  const first = weeks.findIndex((value) => value !== null && value !== undefined);
  return { first, values: first < 0 ? [] : weeks.slice(first).map((value) => Number(value) || 0) };
}

/// A model's weeks of [kind] as a line on the 8 weeks' scale, from the
/// first week counted, the newest marked; its numbers said for a screen
/// reader.
function weeksLine(model, kind) {
  const { first, values } = countedWeeks(model.period[kind].weeks);
  const [name] = NAMED[kind]();
  const line = make("div", "design-weeks", make("span", "", say("{kind} by week", { kind: name })));
  line.dataset.kind = kind;
  line.dataset.weeks = values.join(",");
  if (!values.length) {
    line.append(make("small", "", say("Not counted yet")));
    return line;
  }
  const w = 120;
  const h = 28;
  const most = Math.max(1, ...values);
  const x = (at) => ((first + at) / (WEEKS - 1)) * (w - 6) + 3;
  const y = (v) => h - 3 - (v / most) * (h - 6);
  const shape = svg("svg", { viewBox: `0 0 ${w} ${h}`, width: w, height: h, role: "img",
    "aria-label": say("{kind} by week, the oldest first: {numbers}", { kind: name, numbers: values.map(number).join(", ") }) });
  if (values.length > 1) shape.append(svg("polyline", { points: values.map((v, at) => `${x(at)},${y(v)}`).join(" "), class: "line" }));
  shape.append(svg("circle", { cx: x(values.length - 1), cy: y(values.at(-1)), r: 3, class: "dot" }));
  line.append(shape);
  return line;
}

/// A clean top for an axis that reaches [most], and its ticks (as the
/// console's): whole numbers only, since every count is one.
function ticksOf(most) {
  if (most <= 0) return [0, 1];
  const step = 10 ** Math.floor(Math.log10(most));
  const nice = [1, 2, 2.5, 5, 10].map((k) => k * step).filter(Number.isInteger).find((s) => most / s <= 4) || step * 10;
  const top = Math.ceil(most / nice) * nice;
  const out = [];
  for (let at = 0; at <= top; at += nice) out.push(at);
  return out;
}

/// Week [at] (0 the oldest of the 8) of [period], in words: "28 Sep to
/// 4 Oct"; a week counting began in, from that day.
function weekSaid(period, at, from = null) {
  const first = dayPlus(period.weeks_from, 7 * at);
  return say("{from} to {to}", { from: short(from && from > first ? from : first), to: short(period.weeks_from, 7 * at + 6) });
}

// The chart's width followed, let go when it is made again.
let watching = null;

/// Every model's [kind] added up, a column a week from the first week
/// counted, with its table.
function chartOf(period, kind) {
  watching?.disconnect();
  const [name, one, many] = NAMED[kind]();
  const counts = period.totals[kind];
  const { first, values } = countedWeeks(counts.weeks);
  const figure = make("figure", "period-chart");
  figure.dataset.kind = kind;
  figure.dataset.first = String(first);
  const caption = make("figcaption", "", make("span", "", say("{kind} by week, all your models", { kind: name })));
  figure.append(caption);
  if (!values.length) {
    figure.append(make("p", "note", say("Nothing counted yet: a day is counted once it ends, at midnight UTC.")));
    return figure;
  }
  caption.append(make("small", "", say("{from} to {to}, UTC", { from: short(counts.from && counts.from > dayPlus(period.weeks_from, 7 * first)
    ? counts.from : dayPlus(period.weeks_from, 7 * first)), to: short(period.til) })));
  const plot = make("div", "plot");
  figure.append(plot);
  const tip = make("div", "tip");
  tip.hidden = true;
  const words = (at) => `${number(values[at])} ${values[at] === 1 ? one : many}`;
  const saidWeek = (at) => weekSaid(period, first + at, counts.from);
  const tipAt = (target, at) => {
    tip.replaceChildren(make("b", "", words(at)), make("span", "", saidWeek(at)));
    tip.hidden = false;
    const box = plot.getBoundingClientRect();
    const bar = target.getBoundingClientRect();
    tip.style.left = `${Math.min(Math.max(0, bar.left - box.left + bar.width / 2 - tip.offsetWidth / 2), box.width - tip.offsetWidth)}px`;
    tip.style.top = `${bar.top - box.top - tip.offsetHeight + 8}px`;
  };
  // The week a key is on: the chart's one Tab stop; the arrows, Home and End move it.
  let lit = values.length - 1;
  const draw = () => {
    const w = Math.max(240, plot.clientWidth - 24);
    const h = 150;
    const left = 40;
    const bottom = 20;
    const ticks = ticksOf(Math.max(0, ...values));
    const top = ticks.at(-1) || 1;
    const y = (v) => h - (v / top) * (h - 8);
    const shape = svg("svg", { viewBox: `0 0 ${w} ${h + bottom}`, role: "group",
      "aria-label": say("{kind} by week, a column a week; the arrow keys go from week to week", { kind: name }) });
    for (const t of ticks) {
      shape.append(svg("line", { x1: left, x2: w, y1: y(t), y2: y(t), class: t === 0 ? "base" : "grid" }));
      const label = svg("text", { x: left - 6, y: y(t) + 4, "text-anchor": "end" });
      label.textContent = number(t);
      shape.append(label);
    }
    const slot = (w - left) / values.length;
    const width = Math.max(2, Math.min(40, slot - 8));
    const hits = [];
    values.forEach((value, at) => {
      const hit = svg("rect", { x: left + at * slot, y: 0, width: slot, height: h, class: "hit", tabindex: at === lit ? 0 : -1,
        role: "img", "aria-label": `${saidWeek(at)}: ${words(at)}` });
      hits.push(hit);
      hit.addEventListener("keydown", (event) => {
        const to = { ArrowLeft: at - 1, ArrowDown: at - 1, ArrowRight: at + 1, ArrowUp: at + 1, Home: 0, End: values.length - 1 }[event.key];
        if (to === undefined) return;
        event.preventDefault();
        lit = Math.max(0, Math.min(values.length - 1, to));
        hits.forEach((other, n) => other.setAttribute("tabindex", n === lit ? "0" : "-1"));
        hits[lit].focus();
      });
      hit.addEventListener("pointerenter", () => tipAt(hit, at));
      hit.addEventListener("focus", () => tipAt(hit, at));
      hit.addEventListener("pointerleave", () => { tip.hidden = true; });
      hit.addEventListener("blur", () => { tip.hidden = true; });
      shape.append(hit);
      const x = left + at * slot + (slot - width) / 2;
      if (value > 0) {
        const height = Math.max(1, h - y(value));
        const r = Math.min(4, width / 2, height);
        // Rounded at its top, square at the baseline.
        shape.append(svg("path", { class: "bar", d: `M${x},${h} v${-(height - r)} q0,${-r} ${r},${-r} h${width - 2 * r} `
          + `q${r},0 ${r},${r} v${height - r} z` }));
      } else shape.append(svg("g"));
      // Each week's first day counted under it; every other one, the newest kept, where they would touch.
      if (slot >= 52 || (values.length - 1 - at) % 2 === 0) {
        const label = svg("text", { x: left + at * slot + slot / 2, y: h + 15, "text-anchor": "middle" });
        const begins = dayPlus(period.weeks_from, 7 * (first + at));
        label.textContent = short(counts.from && counts.from > begins ? counts.from : begins);
        shape.append(label);
      }
    });
    plot.replaceChildren(shape, tip);
  };
  watching = new ResizeObserver(() => draw());
  watching.observe(plot);
  // Its numbers as words, for anybody: a screen reader's and a reader's.
  const table = make("table", "",
    make("thead", "", make("tr", "", make("th", "", say("Week")), make("th", "n", name))),
    make("tbody", "", ...values.map((value, at) => make("tr", "", make("td", "", saidWeek(at)), make("td", "n", number(value))))));
  for (const th of table.querySelectorAll("th")) th.scope = "col";
  const holder = make("div", "table", table);
  holder.setAttribute("role", "region");
  holder.setAttribute("aria-label", say("{kind} by week, as a table", { kind: name }));
  holder.tabIndex = 0;
  figure.append(make("details", "as-table", make("summary", "", say("As a table")), holder));
  return figure;
}

/// The orders a designer can put their models in, by the kind chosen; ties
/// kept in the server's order.
const SORTS = {
  most: (a, b) => b.now - a.now,
  gaining: (a, b) => (b.now - b.before) - (a.now - a.before) || b.now - a.now,
  fading: (a, b) => (a.now - a.before) - (b.now - b.before) || b.before - a.before,
  ever: (a, b) => b.ever - a.ever,
};
/// The orders that set a model against its 30 days before: a model counted
/// for under 30 days of either window is left out of them, and comes after
/// the rest, most in the last 30 days first.
const AGAINST = new Set(["gaining", "fading"]);

/// A labelled dropdown of [options] ([value, words]).
function choice(id, words, options) {
  const select = make("select");
  select.id = id;
  for (const [value, said] of options) {
    const option = make("option", "", said);
    option.value = value;
    select.append(option);
  }
  const label = make("label", "", words, select);
  label.htmlFor = id;
  return { label, select };
}

/// What each number counts, and the days.
function meaning(period) {
  const list = make("dl", "period-means");
  for (const kind of KINDS) list.append(make("dt", "", NAMED[kind]()[0]), make("dd", "", MEANS[kind]()));
  list.append(make("dt", "", say("The days")), make("dd", "", say("The last 30 days are the 30 whole days ending yesterday; "
    + "the 30 days before are the 30 before those; a week is 7 days, the newest ending yesterday. Days begin at midnight UTC, "
    + "and today is counted once it ends.")));
  list.append(make("dt", "", say("Counted since")), make("dd", "", say("A change is shown only where both 30 days were counted "
    + "in full. Where either was not, the number says from which day it was counted instead, and its model is left out of "
    + "Gaining and Fading: a model is counted from the day it was shared, and views have been kept by the day only since {day}.",
  { day: DATE.format(dayAt(period.views_from || period.today)) })));
  return make("details", "qa period-what", make("summary", "", say("What each number counts")), make("div", "", list));
}

/// Draw [models] against the 30 days before, into [box] after [title] and [only].
function drawPeriod(box, title, only, period, models) {
  const t = period.totals;
  const days = make("p", "period-days", say("The last 30 days, {from} to {to}, beside the 30 before, {before} to {last}.",
    { from: short(period.now_from), to: short(period.til), before: short(period.before_from), last: short(period.before_til) }));
  const totals = make("ul", "earned mine-totals period",
    ...KINDS.map((kind, at) => periodTile(kind, t[kind], at < 2)));
  totals.setAttribute("aria-label", say("All your models, the last 30 days"));
  const kindChoice = choice(`${box.id || "designs"}-kind`, say("Numbers of"), KINDS.map((kind) => [kind, NAMED[kind]()[0]]));
  const sortChoice = choice(`${box.id || "designs"}-sort`, say("Sort models by"), [["most", say("Most in the last 30 days")],
    ["gaining", say("Gaining the most")], ["fading", say("Fading the most")], ["ever", say("Most in all")]]);
  const controls = make("form", "period-controls", kindChoice.label, sortChoice.label);
  controls.addEventListener("submit", (event) => event.preventDefault());
  const rows = models.map((model) => {
    const item = row(model);
    item.querySelector(".design-numbers").after(weeksLine(model, "views"));
    return { model, item };
  });
  const list = make("ol", "design-rows", ...rows.map((one) => one.item));
  // Under Gaining and Fading: which models were left out of the order, and why.
  const left = make("p", "note period-left");
  left.setAttribute("role", "status");
  left.hidden = true;
  let chart = chartOf(period, "views");
  // Each row moved only where it is not already, and each word written only
  // where it changes: a row the browser is given again it styles and lays
  // out again, and appending all 50 for every choice made a choice cost
  // 60 ms on a loaded box (designer_period, nightly 2026-11-24).
  const set = (node, key, value) => { if (node.dataset[key] !== value) node.dataset[key] = value; };
  const place = (wanted) => {
    let at = list.firstElementChild;
    for (const item of wanted) {
      if (item === at) at = at.nextElementSibling;
      else list.insertBefore(item, at);
    }
  };
  const order = () => {
    const kind = kindChoice.select.value;
    const how = sortChoice.select.value;
    const against = AGAINST.has(how);
    const by = (sort) => (a, b) => sort(a.model.period[kind], b.model.period[kind]);
    const compared = rows.filter((one) => !against || whole(one.model.period[kind]));
    const out = against ? rows.filter((one) => !whole(one.model.period[kind])) : [];
    for (const one of rows) set(one.item, "compared", String(!out.includes(one)));
    set(list, "kind", kind);
    set(list, "sort", how);
    place([...compared.slice().sort(by(SORTS[how] || SORTS.most)).map((one) => one.item),
      ...out.slice().sort(by(SORTS.most)).map((one) => one.item)]);
    if (left.hidden !== !out.length) left.hidden = !out.length;
    const words = !out.length ? ""
      : compared.length ? say("Not compared, so last: {n} counted for under 30 days of either window.", { n: number(out.length) })
        : say("None is compared yet: no model was counted for all 60 days. They are in order of the most in the last 30 days.");
    if (left.textContent !== words) left.textContent = words;
  };
  kindChoice.select.addEventListener("change", () => {
    const kind = kindChoice.select.value;
    const made = chartOf(period, kind);
    chart.replaceWith(made);
    chart = made;
    for (const one of rows) one.item.querySelector(".design-weeks").replaceWith(weeksLine(one.model, kind));
    order();
  });
  sortChoice.select.addEventListener("change", order);
  order();
  box.replaceChildren(title, only, days, totals, controls, chart, meaning(period), left, list);
  return list;
}

function row(model) {
  const picture = model.thumb ? `/m/${model.id}.webp${/\?v=[a-z0-9]+$/.test(model.thumb) ? model.thumb.slice(model.thumb.indexOf("?")) : ""}`
    : model.image ? `/m/${model.id}.png` : "";
  const frame = make("a", `pic${picture ? "" : " none"}`);
  frame.href = `${AT}/m/${model.id}`;
  frame.tabIndex = -1;
  frame.setAttribute("aria-hidden", "true");
  if (picture) {
    const img = document.createElement("img");
    img.src = picture;
    img.alt = "";
    img.width = 1200;
    img.height = 630;
    img.loading = "lazy";
    frame.append(img);
  } else {
    frame.textContent = say("No picture");
  }
  const item = make("li", "design-row", frame, make("div", "design-main",
    make("h3", "", link(`${AT}/m/${model.id}`, String(model.name))), make("p", "design-meta", whatItIs(model)),
    model.period ? periodNumbers(model) : numbers(model), builders(model)));
  item.dataset.id = model.id;
  return item;
}

/// Fill [box] with the signed-in designer's own numbers. [handle]: asked
/// from that profile's page, and drawn only when it is theirs. Says what it
/// drew on document.documentElement.dataset.designs: ready, empty, not-yet,
/// not-mine, signed-out or trouble.
export async function showDesigns(box, { handle = null, heading = say("Your models, as a designer") } = {}) {
  const said = (state) => {
    document.documentElement.dataset.designs = state;
    return state;
  };
  if (!box) return said("none");
  if (!signedIn()) {
    box.hidden = true;
    return said("signed-out");
  }
  const asked = handle && HANDLE.test(handle) ? `&handle=${encodeURIComponent(handle)}` : "";
  const answer = await call(`/api/people?op=designs${asked}`).catch(() => null);
  if (!answer || answer.status !== 200) {
    box.hidden = Boolean(handle);
    box.replaceChildren(make("h2", "", heading),
      make("p", "note", answer?.body?.error ? say(String(answer.body.error)) : say("Your numbers could not be read just now.")));
    return said("trouble");
  }
  const mine = answer.body;
  if (!mine.mine) {
    box.hidden = true;
    box.replaceChildren();
    return said("not-mine");
  }
  const title = make("h2", "", heading);
  title.id = `${box.id || "designs"}-h`;
  box.setAttribute("aria-labelledby", title.id);
  const period = periodIn(mine);
  const only = make("p", "private", period ? say("Only you see this: it is read with your sign-in and never kept by the site’s cache.")
    : `${say("Only you see this: it is read with your sign-in and never kept by the site’s cache.")} `
    + say("The last {days} days, and in all since each model was shared.", { days: number(mine.days || 30) }));
  if (!mine.ready) {
    box.replaceChildren(title, make("p", "note", say("How your models are doing is not open on Brickworks yet.")));
    box.hidden = false;
    return said("not-yet");
  }
  const models = (mine.models || []).filter((one) => ID.test(String(one.id)));
  if (!models.length) {
    box.replaceChildren(title, only, make("p", "note", say("Nothing shared yet. Share a model from the app (Share, on its bar), "
      + "and how many open it, build it and remix it is here.")));
    box.hidden = false;
    return said("empty");
  }
  document.documentElement.dataset.period = period ? "ready" : "none";
  if (period) {
    const list = drawPeriod(box, title, only, period, models);
    box.hidden = false;
    eager(list);
    return said("ready");
  }
  const t = mine.totals || {};
  const totals = make("ul", "earned mine-totals",
    tile("opens", t.opens, t.opens_ever, say("open"), say("opens"), true),
    tile("builds", t.builds, t.builds_ever, say("build finished"), say("builds finished"), true),
    tile("remixes", t.remixes, t.remixes_ever, say("remix"), say("remixes")),
    tile("comments", t.comments, t.comments_ever, say("comment"), say("comments")));
  totals.setAttribute("aria-label", say("Your models, the last {days} days", { days: number(mine.days || 30) }));
  // Opens are kept by the day only from when designers.sql went in: before
  // that, only in all.
  const from = Date.parse(mine.counted_from || "");
  const since = Date.parse(mine.since || "");
  const counting = Number.isFinite(from) && Number.isFinite(since) && from > since
    ? make("p", "note", say("Opens are counted by the day from {day}; before that, only in all.", { day: DATE.format(from) })) : null;
  const list = make("ol", "design-rows", ...models.map(row));
  box.replaceChildren(title, only, totals, counting, list);
  box.hidden = false;
  eager(list);
  return said("ready");
}

/// The models' pictures on the first screen asked for at once: a lazy one
/// there came last (the first row at 1280 and 1920, site277). Which they are
/// is known once they are laid out. The builds' photos stay lazy, so each is
/// measured as it is drawn (web/card.js photoPicture).
function eager(list) {
  for (const img of list.querySelectorAll(".pic img")) {
    const at = img.getBoundingClientRect();
    if (at.top < innerHeight && at.bottom > 0) img.loading = "eager";
  }
  sharpPhotos(list);
}

/// The server's `period`, when it sent one whole: its days, and every
/// model's six kinds with the days each was counted (api/_designers.js
/// periodOf). Null otherwise: drawn as before.
function periodIn(mine) {
  const period = mine?.period;
  const day = /^\d{4}-\d{2}-\d{2}$/;
  if (!period || !["today", "til", "now_from", "before_from", "before_til", "weeks_from"]
    .every((key) => day.test(String(period[key] || "")))) return null;
  const complete = (counts) => counts && Array.isArray(counts.weeks) && counts.weeks.length === WEEKS
    && Number.isFinite(counts.now_days) && Number.isFinite(counts.before_days);
  if (!KINDS.every((kind) => complete(period.totals?.[kind]))) return null;
  if (!(mine.models || []).every((model) => !ID.test(String(model.id)) || KINDS.every((kind) => complete(model.period?.[kind])))) return null;
  return period;
}

// On a profile's page: drawn only when it is the signed-in designer's own.
const own = document.getElementById("designs-mine");
const page = own ? own.closest(".person[data-handle]") : null;
if (own && page) showDesigns(own, { handle: page.dataset.handle, heading: say("How your models are doing") });
