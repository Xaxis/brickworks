// The console's Connector (admin.html #connector, #connector/<account>,
// console2): each account's Claude connector, live and lately: the Claudes
// it let in, its tabs, its conversations and their tool calls
// (/api/admin?op=connector, api/_console_connector.js). Read only: no act
// here, ever. /admin?tests=1: the checks' own accounts.
//
// Everything is put on the page as text, never as markup.
import { $, TESTS, adminJson, ago, cell, count, emptyRow, link, make, resort, say, segmented, sift, timeCell, when }
  from "/admin-kit.js";

export const STATE = { working: "Working now", on: "Tab on", added: "No tab on", tab: "No tab on, no Claude let in", none: "—" };
let shown = "";
let listed = null;

function siftAccounts() {
  const n = sift($("cx-accounts"), $("cx-q").value, (row) => !shown || row.dataset.state === shown
    || (shown === "added" && row.dataset.state === "tab"));
  const all = [...$("cx-accounts").rows].filter((row) => !row.classList.contains("none")).length;
  say("cx-note", all ? `${n} of ${all} shown${TESTS ? ", the checks' own" : ""}.` : "");
}
$("cx-q").addEventListener("input", siftAccounts);
segmented(document.querySelector('[data-filter="connector"]'), (value) => { shown = value; siftAccounts(); });

const pill = (state) => make("span", state === "working" ? "pill good" : state === "on" ? "pill new" : "pill", STATE[state] || state);
const tabSaid = (s) => (s.tab ? `${s.tab}${s.model ? ` · ${s.model}` : ""}` : "a tab now closed");

export async function loadConnector() {
  listed = await adminJson({ op: "connector" });
  const accounts = listed.accounts || [];
  $("n-cx-working").textContent = count(accounts.filter((one) => one.state === "working").length);
  $("n-cx-tabs").textContent = count(accounts.reduce((n, one) => n + one.live_tabs, 0));
  $("n-cx-today").textContent = listed.days_kept ? count(accounts.reduce((n, one) => n + one.calls.today, 0)) : "—";
  say("n-cx-week", listed.days_kept ? `${count(accounts.reduce((n, one) => n + one.calls.week, 0))} in 7 days`
    : "not counted yet: supabase/console2.sql is not applied");
  $("n-cx-accounts").textContent = count(accounts.length);

  const body = $("cx-accounts");
  body.replaceChildren();
  for (const one of accounts) {
    const row = make("tr");
    row.dataset.account = one.account;
    row.dataset.state = one.state;
    row.dataset.find = [one.email, ...one.tabs.map((t) => `${t.tab || ""} ${t.model || ""}`), one.last?.tool,
      ...one.claudes.map((c) => c.name)].filter(Boolean).join(" ");
    const who = make("th");
    who.scope = "row";
    who.append(link(`#connector/${one.account}`, one.email || one.account));
    who.dataset.value = one.email || "";
    row.append(who);
    cell(row, pill(one.state)).dataset.value = one.state;
    cell(row, String(one.claudes.length), one.claudes.length ? "n" : "n faint").dataset.value = String(one.claudes.length);
    const tabs = cell(row, one.tabs.length ? `${one.live_tabs} of ${one.tabs.length} on` : "—", one.tabs.length ? "n line" : "n faint");
    tabs.dataset.value = String(one.live_tabs);
    cell(row, String(one.sessions.length), one.sessions.length ? "n" : "n faint").dataset.value = String(one.sessions.length);
    cell(row, listed.days_kept ? count(one.calls.month) : "—", one.calls.month ? "n" : "n faint").dataset.value = String(one.calls.month);
    const last = cell(row, one.last ? make("span", "", ago(one.last.at), one.last.tool ? make("br") : "",
      one.last.tool ? make("small", "faint", one.last.tool) : "") : "never", one.last ? "line" : "line faint");
    last.dataset.value = one.last?.at || "";
    if (one.last) last.title = when(one.last.at);
    body.append(row);
  }
  if (!accounts.length) emptyRow(body, TESTS ? "None of the checks' own accounts has a connector." : "Nobody has added the connector yet.");
  resort(body.closest("table"));
  siftAccounts();

  const sessions = $("cx-sessions");
  sessions.replaceChildren();
  for (const s of listed.sessions || []) {
    const row = make("tr");
    row.dataset.chat = s.chat;
    row.dataset.account = s.account;
    timeCell(row, s.last_call || s.since);
    cell(row, link(`#connector/${s.account}`, s.email || s.account), "who");
    cell(row, make("span", "", s.chat, make("br"), make("small", "faint", s.way === "connection" ? "by its connection" : "by its session")));
    cell(row, make("span", "", tabSaid(s), s.tool ? make("br") : "", s.tool ? make("small", "faint", `last: ${s.tool}`) : ""), "about");
    cell(row, s.calls === null ? "—" : count(s.calls), "n");
    cell(row, make("span", s.live ? "pill good" : "pill", s.live ? "Working now" : s.moved ? "Moved out" : `Lately, ${ago(s.last_call || s.since)}`));
    sessions.append(row);
  }
  if (!sessions.rows.length) emptyRow(sessions, "No conversation is working in a tab now or lately.");
  return listed;
}

/// One account's connector whole, for the panel: {title, parts}.
export async function connectorOf(account) {
  const one = (await adminJson({ op: "connector", account })).accounts?.[0];
  const parts = [];
  if (!one) {
    parts.push(make("p", "note", "This account has never let a Claude in or switched a tab on."),
      make("p", "note", link(`#people/${account}`, "Its account in People")));
    return { title: "No connector", parts };
  }
  const facts = make("dl", "facts");
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  fact("State", pill(one.state));
  fact("Tool calls", `${count(one.calls.today)} today, ${count(one.calls.week)} in 7 days, ${count(one.calls.month)} in 30`);
  fact("Last call", one.last ? `${when(one.last.at)} (${ago(one.last.at)})${one.last.tool ? `: ${one.last.tool}` : ""}` : "never");
  fact("Account", link(`#people/${one.account}`, "in People"));
  parts.push(facts);
  const list = (title, rows, none) => make("div", "part", make("h3", "", title),
    rows.length ? make("ul", "models-of", ...rows) : make("p", "note", none));
  parts.push(list(`Claudes let in (${one.claudes.length})`, one.claudes.map((c) => make("li", "", make("span", "", c.name),
    make("small", "faint", `since ${when(c.since)}${c.used_at ? ` · last used ${ago(c.used_at)}` : ""}`))), "None: its tabs answer only by their own address."));
  parts.push(list(`Tabs (${one.tabs.length})`, one.tabs.map((t) => make("li", "", make("span", "", t.tab || "a tab", t.model ? ` · ${t.model}` : ""),
    make("small", "faint", `${t.live ? "on now" : t.open ? "quiet" : "closed"} · heard ${ago(t.seen_at)}`))), "None switched on."));
  parts.push(list(`Conversations (${one.sessions.length})`, one.sessions.map((s) => make("li", "", make("span", "", s.chat, ` in ${tabSaid(s)}`),
    make("small", "faint", `${s.calls === null ? "" : `${count(s.calls)} calls · `}${s.last_call ? `last ${ago(s.last_call)}${s.tool ? `, ${s.tool}` : ""}`
      : `since ${ago(s.since)}, no call yet`}${s.live ? " · working now" : ""}`))), "None working in a tab now."));
  parts.push(make("p", "note", "Read only: the person ends a conversation or a connector from their own Settings and Claude."));
  return { title: one.email || one.account, parts };
}
