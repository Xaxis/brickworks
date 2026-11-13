// What every part of the owner's console shares (admin.html, docs/ADMIN.md):
// /api/admin asked with the session in this browser (web/account.js), the
// page's elements made, times said, an act's button, and a table's search,
// filters and sort.
//
// Everything is put on the page as text, never as markup: almost every word
// the console shows was typed by somebody else.
import { call, signedIn } from "/account.js";

export const $ = (id) => document.getElementById(id);

/// /admin?tests=1: the site's checks' own accounts, models, applications,
/// reports and acts instead. Asked with every read and every act, so an
/// act done here is kept in the audit as a test's.
export const TESTS = new URLSearchParams(location.search).get("tests") === "1";

/// [tag] with [className] and what is [inside], each an element or text;
/// empty ones left out.
export function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "" && one !== false) made.append(one);
  return made;
}

/// A link to [href] that says [text].
export function link(href, text, className = "") {
  const a = make("a", className, text);
  a.href = href;
  return a;
}

const AT = new Intl.DateTimeFormat(undefined, { year: "numeric", month: "short", day: "numeric", hour: "2-digit",
  minute: "2-digit" });
const ON = new Intl.DateTimeFormat(undefined, { year: "numeric", month: "short", day: "numeric" });
const AT_TIME = new Intl.DateTimeFormat(undefined, { hour: "2-digit", minute: "2-digit" });
export const when = (iso) => (iso ? AT.format(new Date(iso)) : "—");
export const day = (iso) => (iso ? ON.format(new Date(iso)) : "");
export const clock = (iso) => (iso ? AT_TIME.format(new Date(iso)) : "");

/// A table's cell of when [iso] was: the day, and the time under it, so a
/// table's rows keep their width for what was said; sorted by [iso].
export function timeCell(row, iso) {
  const td = make("td", "when");
  if (iso) {
    td.append(day(iso), make("br"), make("small", "faint", clock(iso)));
    td.dataset.value = iso;
  } else td.textContent = "—";
  row.append(td);
  return td;
}

/// An email address as text that breaks after its @ when it must, never
/// inside a name.
export function address(text) {
  const made = document.createDocumentFragment();
  String(text).split(/(?<=@)/).forEach((part, at) => {
    if (at) made.append(document.createElement("wbr"));
    made.append(part);
  });
  return made;
}

/// A table row's act: [act]'s button at the size of a row of actions.
export const rowAct = (words, run) => act(words, run, "cta ghost small");

/// How long ago [iso] was, in a word or two ("3 minutes ago", "yesterday").
export function ago(iso) {
  if (!iso) return "never";
  const seconds = (Date.now() - Date.parse(iso)) / 1000;
  if (!Number.isFinite(seconds)) return "—";
  const said = new Intl.RelativeTimeFormat(undefined, { numeric: "auto" });
  for (const [size, unit] of [[31536000, "year"], [2592000, "month"], [86400, "day"], [3600, "hour"], [60, "minute"]]) {
    if (Math.abs(seconds) >= size) return said.format(-Math.round(seconds / size), unit);
  }
  return "just now";
}

export const count = (n) => (n === null || n === undefined ? "—" : Number(n).toLocaleString());

/// [text] said at [where] (an id or the element), in the warning colour when [bad].
export function say(where, text, bad = false) {
  const el = typeof where === "string" ? $(where) : where;
  if (!el) return;
  el.textContent = text;
  el.classList.toggle("bad", bad);
}

/// /api/admin?[query] asked with the sign-in, as JSON: {status, body}.
/// The checks' own when the page is (?tests=1).
export async function admin(query, { method = "GET", body } = {}) {
  if (!signedIn()) throw new Error("You are not signed in to Brickworks in this browser.");
  const asked = new URLSearchParams(query);
  if (TESTS && !asked.has("tests")) asked.set("tests", "1");
  return call(`/api/admin?${asked}`, { method, body });
}

/// The same, its body when it went (2xx), else what the server said, thrown.
export async function adminJson(query, options) {
  const reply = await admin(query, options);
  if (reply.status === 404 && reply.body?.error === "not found") throw new Error("This account cannot see this page.");
  if (reply.status < 200 || reply.status > 299) {
    throw new Error(reply.body?.error || `The server said ${reply.status}.`);
  }
  return reply.body;
}

/// A button that says [words] and runs [run] when pressed, held while it
/// runs: pressed again only when [run] answers false (it did not go).
export function act(words, run, className = "") {
  const button = make("button", className, words);
  button.type = "button";
  button.addEventListener("click", async () => {
    button.disabled = true;
    const done = await run().catch(() => false);
    if (!done) button.disabled = false;
  });
  return button;
}

/// One of the owner's acts (POST /api/admin?[query], with [body]), said at
/// [where] in [said]'s words (or what said(answer) gives), then [after]:
/// true when it went.
export async function post(query, where, said, { body, after } = {}) {
  try {
    const answer = await adminJson(query, { method: "POST", body });
    if (after) await after(answer);
    say(where, typeof said === "function" ? said(answer) : said);
    return true;
  } catch (problem) {
    say(where, problem.message, true);
    return false;
  }
}

/// A row's cell of [text], with [className].
export function cell(row, text, className = "") {
  const td = make("td", className);
  if (text instanceof Node) td.append(text);
  else td.textContent = text ?? "";
  row.append(td);
  return td;
}

// ---------------------------------------------------------------------------
// A table's tools: search, a filter, and sort by a column.

/// A table's rows shown where they hold every word of [query] (each row's
/// words in its data-find, else its text) and [keep] says so; the number
/// shown back.
export function sift(tbody, query, keep = () => true) {
  const words = String(query || "").toLowerCase().split(/\s+/).filter(Boolean);
  let shown = 0;
  for (const row of tbody.rows) {
    const text = (row.dataset.find || row.textContent).toLowerCase();
    const show = keep(row) && words.every((word) => text.includes(word));
    row.hidden = !show;
    if (show) shown += 1;
  }
  return shown;
}

/// Each sortable header of [table] (th[data-sort] = text, number or time)
/// sorts its rows by that column when pressed, and again the other way;
/// aria-sort says which. A cell's data-value is what it sorts by, else its
/// text.
export function sortable(table) {
  const heads = [...table.tHead.rows[0].cells];
  heads.forEach((th, at) => {
    const kind = th.dataset.sort;
    if (!kind) return;
    const words = th.textContent.trim();
    const button = make("button", "link sort", words);
    button.type = "button";
    th.replaceChildren(button);
    button.addEventListener("click", () => {
      const down = th.getAttribute("aria-sort") !== "descending";
      for (const other of heads) other.removeAttribute("aria-sort");
      th.setAttribute("aria-sort", down ? "descending" : "ascending");
      sortRows(table, at, kind, down);
    });
  });
}

/// [table]'s rows in the order its header's aria-sort says: kept after a
/// redraw.
export function resort(table) {
  const heads = [...table.tHead.rows[0].cells];
  const at = heads.findIndex((th) => th.hasAttribute("aria-sort"));
  if (at < 0 || !heads[at].dataset.sort) return;
  sortRows(table, at, heads[at].dataset.sort, heads[at].getAttribute("aria-sort") === "descending");
}

function sortRows(table, at, kind, down) {
  const body = table.tBodies[0];
  const valueOf = (row) => {
    const td = row.cells[at];
    const raw = td?.dataset.value ?? td?.textContent.trim() ?? "";
    if (kind === "number") return Number(raw) || 0;
    if (kind === "time") return Date.parse(raw) || 0;
    return raw.toLowerCase();
  };
  const rows = [...body.rows].filter((row) => row.cells.length > 1);
  rows.sort((a, b) => {
    const [x, y] = [valueOf(a), valueOf(b)];
    const order = x < y ? -1 : x > y ? 1 : 0;
    return down ? -order : order;
  });
  body.append(...rows);
}

/// A segmented control ([data-filter] group of buttons with data-value or
/// data-status): pressing one presses it alone and calls [then] with its value.
export function segmented(group, then) {
  group.addEventListener("click", (event) => {
    const button = event.target.closest("button");
    if (!button || !group.contains(button)) return;
    for (const other of group.querySelectorAll("button")) other.setAttribute("aria-pressed", String(other === button));
    then(button.dataset.value ?? button.dataset.status ?? "");
  });
}

/// A table row that says [text] across every column, for none or not yet.
export function emptyRow(tbody, text) {
  const row = make("tr", "none");
  const td = make("td", "faint", text);
  td.colSpan = tbody.closest("table")?.tHead?.rows[0]?.cells.length || 1;
  row.append(td);
  tbody.append(row);
}
