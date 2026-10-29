// Claude, as the client, driving a Brickworks tab: the connector relay.
//
// Someone on a Claude plan adds Brickworks to Claude as a connector
// (claude.ai or the Claude apps, or Claude Code), then asks Claude to build
// something. Claude sends MCP requests here; a Brickworks tab of theirs
// collects them, answers them with the same code that serves the desktop's
// MCP tools (CommandSocket), and posts the answers back. This endpoint only
// carries messages between the two. It never sees an API key or a Claude
// login, and it never calls a model: Claude is the client, on the person's
// own plan, which is ordinary use of Anthropic's products.
//
// Two ways in (2026-10-11):
//
//   https://brickworks.diy/api/mcp          one address for everybody.
//       Claude signs in to it with OAuth (api/oauth.js): asked with no
//       token, this answers 401 and names where to sign in, Claude sends
//       the person to Brickworks to sign in and allow it, and is given a
//       token for their account. Each call goes to one of that account's
//       open tabs, on any device — which one is below ("Several tabs").
//       The app opens claude.ai's "Add custom connector" with this
//       address filled in.
//   https://brickworks.diy/api/mcp?t=<token>  one tab's private address,
//       made by the tab and pasted into Claude by hand: the way from
//       2026-10-09, kept working for everyone who added one.
//
// Routes, all POST to this one function:
//   /api/mcp                  an MCP request from Claude signed in to an
//                             account ("Authorization: Bearer <token>")
//   /api/mcp?t=T              an MCP request from Claude (Streamable HTTP,
//                             JSON responses, stateless)
//   /api/mcp?t=T&op=hello     the tab switches on: its answers to initialize
//                             and tools/list, and which page load it is (?i=).
//                             Signed in: it carries the person's session
//                             ("Authorization: Bearer …"), and the account
//                             it names becomes the connector's owner
//   /api/mcp?t=T&op=next      the tab asks for work; waits up to ~25 s
//   /api/mcp?t=T&op=answer    the tab answers request ?id=
//   /api/mcp?t=T&op=state     the page is alive, and in or out of view
//                             (?visible=0|1): sent by the page itself every
//                             ten seconds and whenever it goes in or out of
//                             view, whatever the app is busy with
//   /api/mcp?t=T&op=close     the tab stops listening, or the page has gone
//   /api/mcp?t=T&op=chats     which Claude chats work in this tab
//   /api/mcp?t=T&op=keep&chat=C  the person keeps chat C in this tab; any
//                             other chat working in it is moved off
//
// Every tab listens on its own token's channel, either way; a call for an
// account is put on the channel of that account's tab.
//
// Several tabs (2026-10-13). One account often has more than one tab open,
// each on a model of its own — in one browser, or on two computers. Each
// tab is its own connector now (its token is kept with the tab's own
// working state, src/parts/tab_session.gd), registered with a short id and
// its model's name (&tab=, and &model= with every word that it is alive),
// and which tab a session's calls go to is exact:
//
//   tabs         a tool of the relay's: the account's open tabs, by id,
//                model, in view or not, and when the person last used each
//   select_tab   another: this session's calls go to that tab from now on
//   target       an argument every tool takes: this call, in that tab
//
// A session stays with the tab it chose (relay_picks, keyed by the
// Mcp-Session-Id this hands out at initialize, or by the connection for a
// client that sends none) — so the person clicking into another tab while
// Claude works does not split the work between two models. If that tab
// closes, the next call says so and does nothing, rather than carrying on
// in another model. Every answer begins by naming the tab and model it
// acted on (the tab says which in the answer's _meta).
//
// Two chats, two tabs (2026-10-17). The owner: "two brickworks studio tabs
// open with separate projects, and two claude.ai tabs open, how does the
// user map a given claude session to the right tab so they dont
// interfere". A new chat's first call went to the tab used most recently,
// which is often the tab another chat is building in (the person clicked
// into it to watch), and the two chats then edited one model. Now:
//
//   - A chat that has not chosen, with one tab open, works in it (and is
//     told when another chat works there too).
//   - With several open, its first call that would change a model does
//     nothing and is answered with the tabs, which chat holds each and
//     since when, and how to choose. A call that only looks goes ahead in
//     the most recent tab no other chat holds, says which, and binds
//     nothing.
//   - A tab is chosen by its id or its model's name ("the castle tab"):
//     select_tab, or target on a call, which also binds a chat that had
//     not chosen. A chat started from a tab (the app's "New chat for this
//     tab") opens with a first message naming it, so its first call does.
//   - The tab is told which chats work in it (brickworks/chats, and the
//     chat on every call's _meta) and shows them; with two, the person
//     keeps one (op=keep), and the other's next call is told it was moved
//     off and does nothing until it chooses a tab again.
//   - A resumed chat is a new chat here (2026-10-19). Claude Code starts a
//     new session when a chat resumes and sends nothing that says it is the
//     same chat: a new Mcp-Session-Id, no conversation id, no close of the
//     old one (measured with Claude Code 2.1.303, claude -p --resume). So
//     it chooses its tab again, and the tab's undo (AppTools._undo) takes
//     what it did before as another chat's. A chat's first choice says so
//     (RESUMED) where the account has another chat's pick, as a resumed
//     chat's old self always leaves one.
//
// A browser stops drawing a tab it is not showing, and the app runs on
// drawing. While the connector is on the page now keeps the app running
// out of view (src/net/claude_connector.gd), and says every ten seconds
// that it is alive. So a tab is open while its page says so, in view or
// not: judging it by the app's requests for work called a tab "not open"
// while it built a large design, and while it woke from being out of
// view, and Claude told the person Brickworks was not connected while it
// plainly was. Only a page that has stopped altogether — closed, or a
// browser that froze it anyway — is not; a call then says which. Claude
// adds a connector and lists its tools from claude.ai's settings, so
// those are answered here, from what the tab sent when it switched on.
//
// The tools change with the build (2026-10-13). A conversation lists them
// once, when it connects, and a tab reloaded into a newer build says hello
// with other ones; the conversation went on with the old list for good,
// since this said listChanged: false. Now it says true, and remembers which
// list each conversation was given (relay_lists, by the key its tab is
// picked by). The first call after the tab it works in said hello with
// another list is answered as an event stream with
// notifications/tools/list_changed ahead of the answer — Streamable HTTP
// lets a server send its own messages before the answer to a POST — and a
// client that supports it lists the tools again. A client that takes JSON
// alone is told in words, at the end of that call's answer. Once each time.
// There is no stream to say it in between calls: a stateless function
// holds no connection open (GET is refused).
//
// A tab's token is long, random, made in the tab, and never stored: the
// queue (supabase/relay.sql) is keyed by its SHA-256. Anyone holding a
// private address can build in that tab, which is what the address is
// for, and no more.
//
// And a connector belongs to an account. Everyone who uses Brickworks
// signs in, and only a signed-in tab can switch a connector on: op=hello
// carries the session's access token, verified here as api/_auth.js
// verifies every token, and relay_tabs records whose connector it is
// (owner). An address one account switched on cannot be switched on by
// another, and a tab that never said hello while signed in is handed no
// work. That owner is what a call signed in to an account is routed by.
//
// The model, shown beside a call (2026-10-14). A client that shows a
// server's own pages inline (MCP Apps: claude.ai, the Claude apps) is
// handed one, a viewer of the model (api/_viewer.js): resources/list and
// resources/read are answered here, without the tab, and the tools whose
// answer is the model as it now stands name it in their _meta. Such a
// client's calls to those tools ask the tab for the viewer's share of the
// answer — the parts count, the model packed and a picture, in the
// answer's _meta — and no other client's do, so what any other client sees
// is what it saw before.
//
// And the page asks for what it shows itself (2026-10-15), since a host
// need not hand it _meta and most of claude.ai's sessions do not say they
// show pages: through the host, tools/call to the viewer's own tools, which
// a session that shows pages is listed with _meta.ui.visibility ["app"] so
// its model is never given them, or resources/read of brickworks://viewer/…
// from a host that will not call a tool its model was not given. Either
// goes to the session's tab as a call of the viewer's, answered at once.
//
// Needs SUPABASE_URL and SUPABASE_SECRET_KEY on the project, and
// SUPABASE_PUBLISHABLE_KEY for accounts.

import { createHash, randomBytes } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { challenge, clientLabel, grantOf, isClaude, originOf, resourceOf } from "./_oauth.js";
import {
  ASK_VIEWS, EXTENSION, VIEWER_ONLY, asRead, asksViews, isViewerOnly, partRead, sessionFor, sessionShows,
  showsApps, viewerAsked, viewerListed, viewerPart, viewerRead, withPartsRoot, withViewer,
} from "./_viewer.js";

const TOKEN = /^[A-Za-z0-9_-]{40,96}$/;
const INSTANCE = /^[A-Za-z0-9_-]{8,40}$/;
// A tab's id (TabSession.SHAPE), and the session id handed to Claude.
const TAB_ID = /^[a-z2-9]{4,12}$/;
const SESSION = /^[A-Za-z0-9_-]{16,128}$/;
// A pick made for a connection rather than a session is a conversation's
// only for so long: a client that sends no session id starts the next
// conversation with the tab used most recently, not yesterday's.
const CONNECTION_PICK_MS = 2 * 60 * 60 * 1000;
// How long a chat that has said nothing still holds the tab it works in:
// another chat is kept out of it unless chosen, and the tab shows it.
const HELD_MS = 30 * 60 * 1000;
// A chat's pick, as the tab and the lists read it.
const PICK = "key,channel,picked_at,called_at,did,moved_at";
// How long Claude's request waits for the tab, and how long the tab's ask
// for work waits for Claude. Both well inside the function's 300 s.
// Long, because a large submit_design is checked and built in the tab: three
// Orthanc runs of 2,700-2,900 parts timed out at a shorter limit, and a
// design that times out gets rebuilt coarser to beat the clock.
const ANSWER_WAIT_MS = 240_000;
const WORK_WAIT_MS = 25_000;
const POLL_MS = 350;
// A page that has said nothing in this long — no request for work and no
// word that it is alive, which it sends every ten seconds — has stopped.
const TAB_GONE_MS = 45_000;
// How long a call waits for a stopped tab out of view to come back, and
// for any tab to take a call at all, before Claude is told why not.
const HIDDEN_WAIT_MS = 20_000;
const UNTAKEN_MS = 30_000;
const PROTOCOL = "2025-06-18";
// What this server does, said at initialize: the tool list can change
// (below), and it serves the model's viewer, a resource, to a client that
// shows such pages.
const CAPABILITIES = { tools: { listChanged: true }, resources: {}, extensions: { [EXTENSION]: {} } };

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

function channelOf(token) {
  return createHash("sha256").update(token).digest("hex");
}

// When a tab was last used, from how many seconds ago its page says.
function usedFrom(value) {
  const seconds = Number(value);
  if (value === undefined || value === "" || !Number.isFinite(seconds) || seconds < 0) return null;
  return new Date(Date.now() - Math.min(seconds, 30 * 86400) * 1000).toISOString();
}

// What a tab says its model is called, kept short.
function modelFrom(value) {
  return typeof value === "string" ? value.slice(0, 120) : null;
}

// The Streamable HTTP session Claude was given at initialize, if it sends one.
function sessionOf(request) {
  const said = String(request.headers?.["mcp-session-id"] || "");
  return SESSION.test(said) ? said : null;
}

function rpcError(id, code, message) {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

// Whether Claude takes an event stream for its answer, as the spec asks
// every client to.
function streams(request) {
  return String(request.headers?.accept || "").includes("text/event-stream");
}

// Which tools a tab serves, in short: compared, never shown. The tab's own
// list, before the relay adds its own tools to it (toolsWithTabs).
function listOf(tools) {
  return createHash("sha256").update(JSON.stringify(Array.isArray(tools) ? tools : [])).digest("hex").slice(0, 24);
}

const LIST_CHANGED = { jsonrpc: "2.0", method: "notifications/tools/list_changed" };
const CHANGED_WORDS =
  "Brickworks has been updated since this conversation listed its tools, and its tools have changed. " +
  "List them again to see the new ones. If they do not appear, a new conversation has them; failing " +
  "that, the person disconnects and connects Brickworks on its page in Claude (Customize, Connectors, " +
  "Brickworks), or in Claude Code runs /mcp and Reconnect. Not Disconnect Claude in Brickworks: that " +
  "ends the connection, and they have to connect it and allow it again.";

// Whether this conversation is to be told that its tools have changed: the
// tab it works in serves another list than the one it was last given, and
// it has not been told of that list yet. Remembered on the way, so it is
// told once.
async function toBeTold(key, served) {
  const rows = await db(`relay_lists?key=eq.${encodeURIComponent(key)}&select=listed,told`);
  const row = rows && rows[0];
  if (!row || row.listed === served || row.told === served) return false;
  await db(`relay_lists?key=eq.${encodeURIComponent(key)}`, {
    method: "PATCH", body: { told: served, at: new Date().toISOString() },
  });
  return true;
}

// The list a conversation has just been given (initialize, tools/list).
async function listGiven(key, served) {
  await db("relay_lists", {
    method: "POST",
    body: { key, listed: served, told: served, at: new Date().toISOString() },
    prefer: "resolution=merge-duplicates",
  });
}

// The answer to a request, and, when [changed], the word that the tools
// have changed: ahead of it in an event stream, or in its words.
function answerWith(response, body, changed, stream) {
  if (!changed || !body || body.id === undefined || body.id === null) {
    return response.status(200).json(body);
  }
  if (stream) {
    const event = (message) => `event: message\ndata: ${JSON.stringify(message)}\n\n`;
    response.setHeader("content-type", "text/event-stream");
    return response.status(200).end(event(LIST_CHANGED) + event(body));
  }
  const content = body.result && Array.isArray(body.result.content) ? body.result.content : null;
  if (content) content.push({ type: "text", text: CHANGED_WORDS });
  return response.status(200).json(body);
}

// What Claude is told when the tab is not there to answer. In words, since
// a person reads it through Claude.
function toolTrouble(id, text) {
  return { jsonrpc: "2.0", id, result: { isError: true, content: [{ type: "text", text }] } };
}

// A tab whose assistant is off (Settings, Assistant (AI)) holds its
// connector off and is not open to Claude, so these say how to turn it on:
// a first visit builds by hand.
const NOT_OPEN =
  "The Brickworks tab this connector belongs to is not open, or its " +
  "assistant or its Claude connector is off. Ask the person to turn the " +
  "assistant on — Settings, Assistant, or open brickworks.diy/app?assistant=on — " +
  "sign in, and switch on the connector under \"Or with your Claude plan\", " +
  "on the same browser they set it up in, so the address is the one this " +
  "connector uses. Then try again.";

// The same, for Claude signed in to an account: any of its tabs will do.
const notOpenFor = (origin) =>
  "No Brickworks tab is open with its assistant on for the account this " +
  "connector is signed in to. Ask the person to open Brickworks, signed in " +
  "with the email address they connected Claude with, and turn the assistant " +
  `on — Settings, Assistant, or open ${origin.replace(/^https?:\/\//, "")}/app?assistant=on — ` +
  "Claude finds the tab by itself, on any computer; if its panel says Claude is " +
  "\"switched off in this tab\", they turn on the switch beside \"Or with your Claude plan\". " +
  "Nothing needs disconnecting. Then try again.";

const HIDDEN =
  "The Brickworks tab is open, but this browser has paused it out of view, " +
  "so it cannot build until it is shown again. Ask the person to bring the " +
  "Brickworks tab into view for a moment — it carries on by itself — then " +
  "call again.";

// A tab's row, without its hello: that is the app's whole guidance and
// tool list, read only when it is what is wanted (helloOf).
const TAB = "channel,seen_at,instance,visible,open,owner,tab,model,used_at";

async function tabOf(channel) {
  const rows = await db(`relay_tabs?channel=eq.${channel}&select=${TAB}`);
  return rows && rows.length ? rows[0] : null;
}

async function helloOf(channel) {
  const rows = await db(`relay_tabs?channel=eq.${channel}&select=hello`);
  return rows && rows.length ? rows[0].hello : null;
}

// "closed", "hidden" or "ready". Alive is ready, in view or not; a page
// that has stopped is "hidden" when it was last out of view, which is a
// browser that paused it, and "closed" when it was in view. A tab no
// signed-in page has switched on is closed whatever it says: it is handed
// no work, so a call waiting for it would wait four minutes for nothing.
function stateOf(tab) {
  if (!tab || !tab.open || !tab.owner) return "closed";
  if (Date.now() - Date.parse(tab.seen_at) <= TAB_GONE_MS) return "ready";
  return tab.visible ? "closed" : "hidden";
}

// What a tab is called to Claude: the id it registered with, or, for a
// page from before tabs had ids, the start of its channel.
function idOf(tab) {
  return (tab && (tab.tab || String(tab.channel || "").slice(0, 6))) || "?";
}

function modelOf(tab, answered) {
  const said = answered && typeof answered === "string" ? answered : (tab && tab.model) || "";
  return said ? `“${said}”` : "an unnamed model";
}

// When the person last used it, as a number to sort by.
function usedAt(tab) {
  return Date.parse(tab.used_at || "") || Date.parse(tab.seen_at || "") || 0;
}

function ago(when) {
  const s = Math.max(0, Math.round((Date.now() - when) / 1000));
  if (s < 20) return "just now";
  if (s < 90) return `${s} s ago`;
  if (s < 5400) return `${Math.round(s / 60)} min ago`;
  if (s < 129600) return `${Math.round(s / 3600)} h ago`;
  return `${Math.round(s / 86400)} days ago`;
}

// The tab the person used most recently: one answering before one paused.
function lastUsed(tabs) {
  const live = tabs.filter((tab) => stateOf(tab) !== "closed");
  live.sort((a, b) => (stateOf(b) === "ready") - (stateOf(a) === "ready") || usedAt(b) - usedAt(a));
  return live[0] || null;
}

// A chat, to the tab: a short name for its session that says nothing of it.
function chatOf(key) {
  return createHash("sha256").update(String(key)).digest("hex").slice(0, 8);
}

// When a chat last did anything in its tab: its last call, or its choice.
function lastOf(pick) {
  return Math.max(Date.parse(pick.called_at || "") || 0, Date.parse(pick.picked_at || "") || 0);
}

// A chat still working in its tab: not moved off it, and heard from lately.
function holds(pick) {
  return Boolean(pick && pick.channel && !pick.moved_at && Date.now() - lastOf(pick) < HELD_MS);
}

// The chats other than [key] working in [tab], most recent first.
function heldBy(tab, picks, key) {
  return (picks || []).filter((one) => one.channel === tab.channel && one.key !== key && holds(one))
    .sort((a, b) => lastOf(b) - lastOf(a));
}

function minutes(since) {
  const m = Math.max(0, Math.round((Date.now() - since) / 60000));
  return m < 1 ? "under a minute" : m < 90 ? `${m} min` : `${Math.round(m / 60)} h`;
}

// Other chats in a tab, in words: "another chat has been working in it for
// 25 min, last call 1 min ago".
function heldWords(others) {
  if (!others.length) return "";
  const first = others[0];
  const who = others.length === 1 ? "another chat has" : `${others.length} other chats have`;
  return `${who} been working in it for ${minutes(Date.parse(first.picked_at) || lastOf(first))}, `
    + `last call ${ago(lastOf(first))}`;
}

// The open tabs, one line each, newest use first, with which chat holds each.
// Two tabs each saying "another chat" read as one chat in both, and a new
// chat told the person so (tabwalk, 2026-10-19): a chat works in one tab at
// a time, which is said when more than one tab has a chat in it.
function listing(tabs, current, picks = [], key = null) {
  const live = tabs.filter((tab) => stateOf(tab) !== "closed")
    .sort((a, b) => usedAt(b) - usedAt(a));
  const held = live.filter((tab) => heldBy(tab, picks, key).length).length;
  return live.map((tab) => {
    const where = stateOf(tab) === "hidden"
      ? "paused out of view by the browser"
      : tab.visible ? "in view" : "out of view";
    const mine = current && tab.channel === current.channel ? " — this chat's" : "";
    const others = heldWords(heldBy(tab, picks, key));
    return `- ${idOf(tab)}: ${modelOf(tab)}, ${where}, used ${ago(usedAt(tab))}${mine}${others ? ` — ${others}` : ""}`;
  }).join("\n") + (held > 1 ? "\nA chat works in one tab at a time, so the chats in these tabs are different chats." : "");
}

// The line every answer starts with: which tab and model it acted on, that
// there are others when there are, and that another chat works in this one.
function header(tab, answered, tabs, picks = [], key = null) {
  const others = tabs.filter((one) => stateOf(one) !== "closed" && one.channel !== tab.channel).length;
  const shared = heldBy(tab, picks, key);
  return `Tab ${idOf(tab)}, ${modelOf(tab, answered)}.`
    + (others ? ` ${others} other tab${others === 1 ? " is" : "s are"} open; tabs lists them.` : "")
    + (shared.length ? ` Careful: ${heldWords(shared)}, on this same model; the tab shows both chats `
      + "and the person can keep one." : "");
}

function withHeader(answer, tab, tabs, picks = [], key = null, more = "") {
  const result = answer && answer.result;
  if (!result || typeof result !== "object") return answer;
  const meta = result._meta && typeof result._meta === "object" ? result._meta : {};
  const content = Array.isArray(result.content) ? result.content : [];
  const said = header(tab, meta["brickworks/model"], tabs, picks, key) + (more ? ` ${more}` : "");
  result.content = [{ type: "text", text: said }, ...content];
  return answer;
}

// A tab named by a person or by Claude: its id, or its model's name ("the
// castle tab", "Castle", "castle"). Exactly one open tab, or every one that
// would do, for Claude to be shown.
function plain(words) {
  return String(words || "").toLowerCase().replace(/[“”"'‘’`]/g, " ")
    .replace(/^\s*the\s+/, "").replace(/\s+tab\s*$/, "").replace(/\s+/g, " ").trim();
}

function named(tabs, said) {
  const live = tabs.filter((tab) => stateOf(tab) !== "closed");
  const wanted = plain(said);
  if (!wanted) return { tab: null, matches: [] };
  const byId = live.filter((tab) => idOf(tab) === wanted);
  if (byId.length === 1) return { tab: byId[0], matches: byId };
  const exact = live.filter((tab) => tab.model && plain(tab.model) === wanted);
  if (exact.length) return { tab: exact.length === 1 ? exact[0] : null, matches: exact };
  const part = wanted.length >= 2 ? live.filter((tab) => tab.model && plain(tab.model).includes(wanted)) : [];
  return { tab: part.length === 1 ? part[0] : null, matches: part };
}

// Why a name chose no tab, in words, with the open ones.
function notNamed(said, found, tabs, current, picks, key) {
  const which = found.matches.length > 1
    ? `${found.matches.length} open tabs match “${said}”, so nothing was done. Name one by its id:`
    : `No open tab is called “${said}”, so nothing was done. Open now:`;
  return `${which}\n${listing(found.matches.length > 1 ? found.matches : tabs, current, picks, key)}`;
}

// Tools the relay answers itself, about the tabs; and the argument every
// tool of the app's gains, saying which tab to do it in.
const TARGET = {
  type: "string",
  description: "Which Brickworks tab to do this in: its id (such as k7qd) or its model's name " +
    "(such as castle). With more than one tab open, pass it on every call: it keeps this chat " +
    "in its own tab even when another chat shares this connection.",
};
const RELAY_TOOLS = [
  {
    name: "tabs",
    description: "The Brickworks tabs open for this account, each with its id, its model's " +
      "name, whether it is in view, when the person last used it and whether another chat " +
      "is working in it, and which one this chat's calls go to. Call it when the person has " +
      "more than one tab open, or when an answer names a tab or model you did not expect.",
    inputSchema: { type: "object", properties: {} },
    // As the app's own tools carry theirs (CommandSocket.HINTS): neither of
    // these changes any model, or anything but which tab this session uses.
    annotations: { title: "List the open tabs", readOnlyHint: true, openWorldHint: false },
  },
  {
    name: "select_tab",
    description: "Work in this Brickworks tab from now on: its id (such as k7qd) or its " +
      "model's name (such as castle), as tabs lists them. Call it first when the person names " +
      "a tab or a model, or opens the chat with one. To do one call elsewhere, pass target on " +
      "that call instead.",
    inputSchema: {
      type: "object",
      properties: { tab: { type: "string", description: "The tab's id, or its model's name." } },
      required: ["tab"],
    },
    annotations: { title: "Work in another tab", readOnlyHint: true, openWorldHint: false },
  },
];

// [schema] with every array saying what its items are: an array that does
// not is refused by OpenAI's function calling ("array schema missing
// items"), and the app's attach.align is one (a direction word or a
// vector, either). {} is anything, which is what it already meant.
function itemsSaid(schema) {
  if (Array.isArray(schema)) return schema.map(itemsSaid);
  if (!schema || typeof schema !== "object") return schema;
  const out = {};
  for (const [key, value] of Object.entries(schema)) {
    out[key] = key === "properties" && value && typeof value === "object" && !Array.isArray(value)
      ? Object.fromEntries(Object.entries(value).map(([name, one]) => [name, itemsSaid(one)]))
      : ["items", "additionalProperties", "anyOf", "oneOf", "allOf", "not"].includes(key) ? itemsSaid(value) : value;
  }
  if (out.type === "array" && out.items === undefined) out.items = {};
  return out;
}

// What a client other than Claude's is given (ChatGPT, 2026-10-29): the
// same tools, in the JSON Schema OpenAI's function calling takes, and with
// all three of the hints OpenAI asks every tool to state ("set readOnlyHint,
// destructiveHint, and openWorldHint to explicit boolean values"): a tool
// that only looks destroys nothing. Claude is given the list as it always
// was, word for word.
function portable(tool) {
  const hints = tool.annotations && typeof tool.annotations === "object" ? tool.annotations : {};
  return {
    ...tool,
    inputSchema: itemsSaid(tool.inputSchema),
    annotations: hints.readOnlyHint === true && hints.destructiveHint === undefined
      ? { ...hints, destructiveHint: false } : hints,
  };
}

// [shows]: the session's client shows pages, and is given the viewer's
// own tools too, for its page alone. [claude]: the client is one of
// Claude's, which is given the list exactly as it always was; any other is
// given it portable.
export function toolsWithTabs(tools, shows = false, claude = true) {
  const own = (Array.isArray(tools) ? tools : []).map((tool) => {
    const schema = tool && tool.inputSchema && typeof tool.inputSchema === "object" ? tool.inputSchema : {};
    return withViewer({
      ...tool,
      inputSchema: { type: "object", ...schema, properties: { ...(schema.properties || {}), target: TARGET } },
    });
  });
  const all = [...own, ...RELAY_TOOLS, ...(shows ? VIEWER_ONLY : [])];
  return claude ? all : all.map(portable);
}

// Which tab a session is working in (relay_picks): set by its first call
// and by select_tab; dropped once that tab has closed and it has been told.
async function pickOf(key) {
  if (!key) return null;
  const rows = await db(`relay_picks?key=eq.${encodeURIComponent(key)}&select=${PICK}`);
  const row = rows && rows[0];
  if (!row) return null;
  if (key.startsWith("connection:") && Date.now() - Date.parse(row.picked_at) > CONNECTION_PICK_MS) return null;
  return row;
}

// Every chat's pick for an account, for the lists to say which chat holds
// which tab.
async function picksOf(owner) {
  if (!owner) return [];
  return await db(`relay_picks?owner=eq.${owner}&select=${PICK}&order=picked_at.desc&limit=50`) || [];
}

// [key] works in [channel] from now on, and both tabs it touches are told.
async function pick(key, owner, channel, was = null) {
  if (!key) return;
  await db("relay_picks", {
    method: "POST",
    body: { key, owner, channel, picked_at: new Date().toISOString(), moved_at: null },
    prefer: "resolution=merge-duplicates",
  });
  await tellChats(channel);
  if (was && was !== channel) await tellChats(was);
}

async function unpick(key) {
  if (key) await db(`relay_picks?key=eq.${encodeURIComponent(key)}`, { method: "DELETE" });
}

// A chat's call, kept with its pick: when, and which tool.
async function noteCall(key, name) {
  if (!key || !name) return;
  await db(`relay_picks?key=eq.${encodeURIComponent(key)}`, {
    method: "PATCH", body: { called_at: new Date().toISOString(), did: String(name).slice(0, 60) },
  });
}

// The chats working in a tab, as the tab is shown them: a short name each,
// since when, its last call and what that was. None of a session's own id.
async function chatsIn(channel) {
  const rows = await db(`relay_picks?channel=eq.${channel}&select=${PICK}&order=picked_at.asc&limit=20`) || [];
  return rows.filter(holds).map((one) => ({
    chat: chatOf(one.key), since: one.picked_at, last: new Date(lastOf(one)).toISOString(),
    did: one.called_at ? one.did || "" : "",
  }));
}

// Tells the tab which chats work in it now: a notification, which it shows.
async function tellChats(channel) {
  if (!channel) return;
  await db("relay", {
    method: "POST",
    body: { channel, request: { jsonrpc: "2.0", method: "brickworks/chats", params: { chats: await chatsIn(channel) } } },
  });
}

// Where Claude's requests go. Two ways in:
//
//   one tab     an address with a token in it (?t=), made by one tab:
//               that tab, and no other — the way since 2026-10-09, kept
//               for everyone who added such an address
//   an account  Claude signed in with OAuth (api/oauth.js), at the one
//               address everybody adds: the account's tabs, on any device,
//               chosen between as the head of this file says
//
// Each says which tabs there are, what to answer the handshake and the
// tool list with, what to tell Claude when there is no tab, and what the
// list of tools each conversation was given is kept by (listKey): its
// session, or, for a client that sends none, its connection or address.
function oneTab(channel, session) {
  return {
    shows: sessionShows(session),
    // A tab's own address is pasted into Claude: its list as it always was.
    claude: true,
    tabs: async () => {
      const tab = await tabOf(channel);
      return tab ? [tab] : [];
    },
    hello: async (tab) => (tab ? await helloOf(tab.channel) : await helloOf(channel)),
    notOpen: NOT_OPEN,
    key: null,
    listKey: session ? `session:${session}` : `address:${channel}`,
    owner: null,
    picks: async () => [],
    used: async () => {},
  };
}

function accountTabs(grant, origin, session) {
  return {
    shows: sessionShows(session),
    // Which app signed in (api/oauth.js): Claude's are given the tool list
    // as they always were, any other (ChatGPT) the portable one.
    claude: isClaude(clientLabel(grant)),
    async tabs() {
      return await db(`relay_tabs?owner=eq.${grant.owner}&open=is.true`
        + `&select=${TAB}&order=seen_at.desc&limit=20`) || [];
    },
    // The handshake and the tool list are the app's, the same for every
    // account: from the tab if there is one, else from the last tab of this
    // account to switch on, else from somebody's — so Claude can add the
    // connector before the person has opened Brickworks at all. Somebody's
    // is the fullest of the latest few, so a test's one-tool tab is never
    // what a person's Claude is shown.
    async hello(tab) {
      const its = tab ? await helloOf(tab.channel) : null;
      if (its) return its;
      const own = await db(`relay_tabs?owner=eq.${grant.owner}&hello=not.is.null`
        + "&select=hello&order=seen_at.desc&limit=1");
      if (own && own.length) return own[0].hello;
      const recent = await db("relay_tabs?hello=not.is.null&owner=not.is.null"
        + "&select=channel,tools:hello->tools&order=seen_at.desc&limit=20") || [];
      const count = (row) => (Array.isArray(row.tools) ? row.tools.length : 0);
      const fullest = recent.sort((a, b) => count(b) - count(a))[0];
      return fullest ? await helloOf(fullest.channel) : null;
    },
    notOpen: notOpenFor(origin),
    // This conversation's pick when Claude sends the session id it was
    // given, and the connection's when it sends none.
    key: session ? `session:${session}` : `connection:${grant.id}`,
    listKey: session ? `session:${session}` : `connection:${grant.id}`,
    owner: grant.owner,
    picks: async () => await picksOf(grant.owner),
    // What the account panel shows of the connection: when Claude last
    // used it, what it called itself, and the tab it builds in.
    async used(message, tab) {
      const change = {};
      if (!grant.used_at || Date.now() - Date.parse(grant.used_at) > 60_000) {
        change.used_at = new Date().toISOString();
      }
      const info = message.method === "initialize" ? message.params?.clientInfo : null;
      if (info && typeof info === "object") {
        const said = {
          name: String(info.name || "").slice(0, 80),
          version: String(info.version || "").slice(0, 40),
        };
        if (JSON.stringify(said) !== JSON.stringify(grant.client_info || {})) change.client_info = said;
      }
      if (tab && message.method === "tools/call" && tab.channel !== grant.channel) {
        change.channel = tab.channel;
      }
      if (Object.keys(change).length) {
        Object.assign(grant, change);
        await db(`oauth_grants?id=eq.${grant.id}`, { method: "PATCH", body: change });
      }
    },
  };
}

// Lets the tab show that Claude has reached it, for the requests answered
// here without it. A notification: the tab answers nothing.
async function tellTab(channel, asked) {
  await db("relay", {
    method: "POST",
    body: { channel, request: { jsonrpc: "2.0", method: "brickworks/claude_here", params: { asked } } },
  });
}

function text(id, words, isError = false) {
  return { jsonrpc: "2.0", id, result: { isError, content: [{ type: "text", text: words }] } };
}

// The relay's own tools: the list of tabs, and choosing one.
async function relayTool(where, message, response) {
  const id = message.id;
  const name = message.params?.name;
  const tabs = await where.tabs();
  const live = tabs.filter((tab) => stateOf(tab) !== "closed");
  const picks = await where.picks();
  const picked = await pickOf(where.key);
  const mine = picked && !picked.moved_at ? live.find((tab) => tab.channel === picked.channel) : null;
  if (!live.length) return response.status(200).json(text(id, where.notOpen, true));
  if (name === "tabs") {
    const count = live.length === 1 ? "One Brickworks tab is open" : `${live.length} Brickworks tabs are open`;
    const moved = picked && picked.moved_at ? live.find((tab) => tab.channel === picked.channel) : null;
    const goes = mine ? `This chat's calls go to ${idOf(mine)}.`
      : moved ? `The person moved this chat off ${idOf(moved)} to keep another chat there; `
        + "ask them which tab to work in, then call select_tab."
      : live.length === 1 || !where.key ? `This chat's calls go to ${idOf(live[0])}, the only one open.`
      : "This chat has not chosen a tab: its first change waits for one. Ask the person which, "
        + "unless they have said, and call select_tab with its id or its model's name.";
    return response.status(200).json(text(id, `${count}:\n${listing(tabs, mine, picks, where.key)}\n${goes}`
      + (live.length > 1 && mine
        ? " Pass target on a call to do it in another tab, or call select_tab to move this chat there."
        : "")));
  }
  const wanted = String(message.params?.arguments?.tab || "").trim();
  const found = named(tabs, wanted);
  const chosen = found.tab;
  if (!chosen) {
    return response.status(200).json(text(id, notNamed(wanted, found, tabs, mine, picks, where.key), true));
  }
  if (!where.key) {
    return response.status(200).json(text(id, `This connector's address reaches one tab, `
      + `${idOf(chosen)} (${modelOf(chosen)}), and its calls go there already.`));
  }
  await pick(where.key, where.owner, chosen.channel, picked ? picked.channel : null);
  const resumed = picked ? "" : resumedWords(picks, where.key);
  return response.status(200).json(text(id, `${header(chosen, null, tabs, picks, where.key)} This chat's calls `
    + `go to tab ${idOf(chosen)} now, on ${modelOf(chosen)}.`
    + (live.length > 1 ? ` ${SAY_TARGET(chosen)}` : "") + (resumed ? ` ${resumed}` : "")));
}

// Claude's apps can share one connection between chats (one Mcp-Session-Id
// for two conversations is reported of claude.ai, claudeissues.com/issue/
// 41836, 2026), and nothing then tells the two apart here. A chat that names
// its tab on every call stays in it whatever another chat chooses.
const SAY_TARGET = (tab) => `While more than one tab is open, pass target: "${idOf(tab)}" on every `
  + "call in this chat too, so it stays here even if another chat shares this connection.";

// A session's tab has closed: said once, with nothing done, and the
// session let go of it, so its next call without a choice is treated as a
// new chat's: in the one tab left, or, with several, after it chooses.
async function closedSaying(where, tab, tabs, taken = false) {
  await unpick(where.key);
  const live = tabs.filter((one) => one.channel !== tab.channel && stateOf(one) !== "closed");
  return `The tab this chat was working in, ${idOf(tab)}${tab.model ? ` (${modelOf(tab)})` : ""}, `
    + (taken ? "closed before it answered, so whether it was done is not known. "
      : "has closed, so nothing was done. ")
    + (live.length > 1
      ? `Open now:\n${listing(live, null, await where.picks(), where.key)}\nAsk the person which tab to `
        + "work in, then call select_tab with its id or its model's name, or pass target."
      : live.length === 1
        ? `One tab is open: ${idOf(live[0])} (${modelOf(live[0])}); a call goes there unless you choose.`
        : where.notOpen);
}

// A resumed chat is a new one to the relay ("Two chats, two tabs"), told so
// on its first choice: said where the account has another chat's pick,
// since a resumed chat's earlier self always leaves one.
const RESUMED = "If this chat was resumed from an earlier one, Brickworks counts it as a new chat: "
  + "it chooses its tab again, and it cannot undo what it did before the resume (the person can, "
  + "with Undo in the tab).";

function resumedWords(picks, key) {
  return key && (picks || []).some((one) => one.key !== key) ? RESUMED : "";
}

// A new chat with several tabs open and none chosen: nothing done, and how
// to choose. The person may have said; else Claude asks.
function chooseFirst(tabs, picks, key) {
  const live = tabs.filter((tab) => stateOf(tab) !== "closed");
  const resumed = resumedWords(picks, key);
  return `Nothing was done: ${live.length} Brickworks tabs are open and this chat has not chosen one. `
    + `Open now:\n${listing(tabs, null, picks, key)}\n`
    + "If the person named a tab or a model, call select_tab with its id or its model's name "
    + "(such as select_tab \"castle\"), or pass target on this call; otherwise ask them which tab "
    + "this chat is for. Then make this call again." + (resumed ? ` ${resumed}` : "");
}

// The person kept another chat in the tab this one worked in.
function movedOff(tab, tabs, picks, key) {
  return `The person moved this chat off tab ${idOf(tab)} (${modelOf(tab)}) to keep another chat `
    + "working there, so nothing was done. Open now:\n"
    + `${listing(tabs, null, picks, key)}\nAsk the person which tab this chat should work in `
    + "(they can open a new one for it), then call select_tab with its id or its model's name.";
}

// Whether a tool only looks: the tab says so in its list (readOnlyHint).
function looksOnly(hello, name) {
  if (isViewerOnly(name)) return true;
  const tools = hello && Array.isArray(hello.tools) ? hello.tools : [];
  const tool = tools.find((one) => one && one.name === name);
  return Boolean(tool && tool.annotations && tool.annotations.readOnlyHint === true);
}

// Claude's side: put the request in the queue and wait for the tab.
async function fromClaude(where, message, response, sessionToGive = null, stream = false) {
  if (Array.isArray(message)) {
    return response.status(200).json(rpcError(null, -32600, "batches are not supported"));
  }
  if (!message || typeof message !== "object" || message.jsonrpc !== "2.0") {
    return response.status(400).json(rpcError(null, -32600, "not a JSON-RPC request"));
  }
  // A notification wants no answer, and the tab needs none of them.
  if (message.id === undefined || message.id === null) {
    return response.status(202).end();
  }
  const id = message.id;
  // Claude Code's first request, before initialize: server/discover, of a
  // newer protocol (2026-07-28) whose sessions have no initialize, and so no
  // session id to keep a chat in its tab by. This speaks the older one, so
  // the method is not found, said here without waking the tab, and Claude
  // goes on to initialize (measured with Claude Code 2.1.303). It was put to
  // the tab like a call, a round trip for every chat that connected.
  if (message.method === "server/discover") {
    return response.status(200).json(rpcError(id, -32601, "Method not found"));
  }
  // A host reading what the viewer would otherwise call for: that call,
  // made in the session's tab and answered as a read.
  let readFor = "";
  if (message.method === "resources/read") {
    const asked = viewerAsked(message.params?.uri);
    if (asked) {
      readFor = String(message.params.uri);
      message = { ...message, method: "tools/call", params: { name: asked.name, arguments: asked.arguments } };
    }
  }
  const calling = message.method === "tools/call";
  const name = calling ? String(message.params?.name || "") : "";
  // The card's own call: no header, and never the one that hears the tools
  // have changed, which is Claude's to hear.
  const viewerCall = calling && isViewerOnly(name);
  // The model's viewer, served here: the tab need not be open to read it.
  if (["resources/list", "resources/read", "resources/templates/list"].includes(message.method)) {
    await where.used(message, null);
    if (message.method === "resources/list") {
      return response.status(200).json({ jsonrpc: "2.0", id, result: { resources: [viewerListed()] } });
    }
    if (message.method === "resources/templates/list") {
      return response.status(200).json({ jsonrpc: "2.0", id, result: { resourceTemplates: [] } });
    }
    const uri = String(message.params?.uri || "");
    const part = viewerPart(uri);
    if (part) {
      const geometry = await partRead(part, uri);
      return response.status(200).json(geometry ? { jsonrpc: "2.0", id, result: geometry }
        : rpcError(id, -32002, `no part geometry ${part}`));
    }
    const read = viewerRead(uri);
    return response.status(200).json(read ? { jsonrpc: "2.0", id, result: read }
      : rpcError(id, -32002, `no resource ${uri.slice(0, 200)}`));
  }
  if (calling && RELAY_TOOLS.some((tool) => tool.name === name)) {
    await where.used(message, null);
    return await relayTool(where, message, response);
  }
  const tabs = await where.tabs();
  const live = tabs.filter((one) => stateOf(one) !== "closed");

  // Which tab: the one named on this call, else the one this chat works
  // in, else — for a chat that has chosen none — the only one open, or,
  // with several, none until it chooses (a look goes ahead in the most
  // recent tab no other chat holds). See "Two chats, two tabs" above.
  let tab = null;
  let picks = [];
  // Said after the header: where a look went before this chat chose.
  let note = "";
  // The tab this chat works in, once this call is placed.
  let home = null;
  if (calling) {
    const given = message.params?.arguments;
    const args = given && typeof given === "object" && !Array.isArray(given) ? { ...given } : {};
    const target = typeof args.target === "string" ? args.target.trim() : "";
    delete args.target;
    message = { ...message, params: { ...message.params, arguments: args } };
    // A client that shows the viewer: the tab adds what it shows, to the
    // answer of a call that became a job too once it has ended (job).
    if (asksViews(name) && (where.shows || showsApps(message))) {
      const meta = message.params._meta && typeof message.params._meta === "object" ? message.params._meta : {};
      message.params._meta = { ...meta, [ASK_VIEWS]: true };
    }
    const picked = await pickOf(where.key);
    picks = await where.picks();
    home = picked && !picked.moved_at ? picked : null;
    const refuse = async (words) => {
      await where.used(message, null);
      return response.status(200).json(text(id, words, true));
    };
    if (target) {
      const found = named(tabs, target);
      tab = found.tab;
      if (!tab) {
        return await refuse(live.length ? notNamed(target, found, tabs, null, picks, where.key) : where.notOpen);
      }
      // Named, by a chat that had not chosen or was moved off: its tab now.
      if (where.key && !viewerCall && !home) {
        await pick(where.key, where.owner, tab.channel, picked ? picked.channel : null);
        home = { key: where.key, channel: tab.channel, picked_at: new Date().toISOString() };
        if (!picked) note = resumedWords(picks, where.key);
      }
    } else if (home) {
      tab = tabs.find((one) => one.channel === home.channel) || await tabOf(home.channel);
      if (!tab || stateOf(tab) === "closed") {
        return await refuse(await closedSaying(where, tab || { channel: home.channel }, tabs));
      }
    } else if (picked && picked.moved_at && !viewerCall) {
      const was = tabs.find((one) => one.channel === picked.channel) || { channel: picked.channel };
      return await refuse(movedOff(was, tabs, picks, where.key));
    } else if (!where.key || live.length <= 1) {
      tab = lastUsed(tabs);
      if (tab && where.key && !viewerCall) {
        await pick(where.key, where.owner, tab.channel, picked ? picked.channel : null);
        home = { key: where.key, channel: tab.channel, picked_at: new Date().toISOString() };
        if (!picked) note = resumedWords(picks, where.key);
      }
    } else if (viewerCall || looksOnly(await where.hello(lastUsed(tabs)), name)) {
      const free = live.filter((one) => !heldBy(one, picks, where.key).length);
      tab = lastUsed(free.length ? free : live);
      note = `This chat has not chosen a tab, so this look was made in ${idOf(tab)}, the tab used most `
        + `recently${free.length ? " that no other chat is working in" : ""}. Before changing anything, `
        + "call select_tab with a tab's id or its model's name.";
    } else {
      return await refuse(chooseFirst(tabs, picks, where.key));
    }
    // The tab is told which chat this is, in the chat's own tab or one it
    // named, and the chat's pick keeps its last call in its own.
    const own = Boolean(home && tab && home.channel === tab.channel);
    if (where.key && !viewerCall && tab && (own || target)) {
      const meta = message.params._meta && typeof message.params._meta === "object" ? message.params._meta : {};
      message.params._meta = { ...meta,
        "brickworks/chat": { chat: chatOf(where.key), since: own ? home.picked_at : new Date().toISOString() } };
      if (own) await noteCall(where.key, name);
    }
  } else {
    // The handshake and the list from the tab this session works in, so the
    // tools it is given are the ones its calls reach.
    const picked = await pickOf(where.key);
    tab = (picked && live.find((one) => one.channel === picked.channel)) || lastUsed(tabs);
  }
  const hello = await where.hello(tab);

  // Which tools this conversation was given, and whether it is to be told
  // they have changed: on any answer that can carry the word, which for a
  // client taking JSON alone is a call's.
  const served = hello ? listOf(hello.tools) : "";
  let changed = false;
  if (served && where.listKey) {
    if (["initialize", "tools/list"].includes(message.method)) {
      await listGiven(where.listKey, served);
    } else if ((calling || stream) && !viewerCall) {
      changed = await toBeTold(where.listKey, served);
    }
  }
  const send = (answer) => {
    const rooted = withPartsRoot(answer);
    return answerWith(response, readFor ? asRead(rooted, readFor) : rooted, changed, stream);
  };

  // The handshake and the tool list, from what the tab sent when it
  // switched on: answered whether or not the tab is awake to answer.
  if (hello && ["initialize", "tools/list", "ping"].includes(message.method)) {
    await where.used(message, null);
    if (tab && tab.open) await tellTab(tab.channel, message.method);
    if (message.method === "ping") {
      return send({ jsonrpc: "2.0", id, result: {} });
    }
    if (message.method === "tools/list") {
      return send({ jsonrpc: "2.0", id, result: { tools: toolsWithTabs(hello.tools, where.shows, where.claude) } });
    }
    if (sessionToGive) response.setHeader("mcp-session-id", sessionToGive);
    return send({
      jsonrpc: "2.0", id,
      result: {
        protocolVersion: message.params?.protocolVersion || PROTOCOL,
        capabilities: CAPABILITIES,
        serverInfo: { name: "brickworks", version: "1" },
        instructions: hello.instructions || "",
      },
    });
  }

  let state = stateOf(tab);
  if (state === "hidden" && calling) {
    // Often only a moment: they have gone to look at the tab.
    const until = Date.now() + HIDDEN_WAIT_MS;
    while (state === "hidden" && Date.now() < until) {
      await sleep(1000);
      tab = await tabOf(tab.channel);
      state = stateOf(tab);
    }
    if (state === "hidden") {
      return send(toolTrouble(id, `${header(tab, null, tabs)} ${HIDDEN}`));
    }
  }
  if (state !== "ready") {
    await where.used(message, null);
    // Enough to be added as a connector with the tab closed; nothing that
    // pretends the tab is there.
    if (message.method === "initialize") {
      if (sessionToGive) response.setHeader("mcp-session-id", sessionToGive);
      return send({
        jsonrpc: "2.0", id,
        result: {
          protocolVersion: message.params?.protocolVersion || PROTOCOL,
          capabilities: CAPABILITIES,
          serverInfo: { name: "brickworks", version: "1" },
          instructions: where.notOpen,
        },
      });
    }
    if (message.method === "ping") {
      return send({ jsonrpc: "2.0", id, result: {} });
    }
    if (calling) {
      return send(toolTrouble(id, where.notOpen));
    }
    return send(rpcError(id, -32000, where.notOpen));
  }
  await where.used(message, tab);

  const channel = tab.channel;
  const [row] = await db("relay", {
    method: "POST",
    body: { channel, request: message },
    prefer: "return=representation",
  });
  const asked = Date.now();
  const until = asked + ANSWER_WAIT_MS;
  let checked = asked;
  while (Date.now() < until) {
    await sleep(POLL_MS);
    const [done] = await db(`relay?id=eq.${row.id}&select=response,taken_at`);
    if (done && done.response) {
      await db(`relay?id=eq.${row.id}`, { method: "DELETE" });
      return send(calling && !viewerCall ? withHeader(done.response, tab, tabs, picks, where.key, note) : done.response);
    }
    // The page has said it is closing, or, not taken at all, has stopped
    // since: say so now rather than at the end of four minutes.
    if (done && Date.now() - checked > 5_000) {
      checked = Date.now();
      const row_ = await tabOf(channel);
      const now = stateOf(row_);
      const shut = row_ && row_.open === false;
      if (shut || (now !== "ready" && !done.taken_at && Date.now() - asked > UNTAKEN_MS)) {
        await db(`relay?id=eq.${row.id}`, { method: "DELETE" });
        if (calling && now === "closed") {
          return send(text(id,
            await closedSaying(where, row_ || tab, tabs, Boolean(done.taken_at)), true));
        }
        const why = now === "hidden" ? HIDDEN : where.notOpen;
        return send(calling
          ? toolTrouble(id, `${header(tab, null, tabs)} ${why}`) : rpcError(id, -32000, why));
      }
    }
  }
  // Gone, so that a tab waking later does not do what Claude has stopped
  // waiting for and may be about to ask for again.
  await db(`relay?id=eq.${row.id}`, { method: "DELETE" });
  return send(calling
    ? toolTrouble(id, `${header(tab, null, tabs)} The Brickworks tab did not answer in time. If it is ` +
        "out of view, ask the person to bring it into view; then try again.")
    : rpcError(id, -32000, "the Brickworks tab did not answer in time"));
}

// Claude signed in with OAuth, at the address with no token in it. With
// no token, or one that does not do, the answer is a 401 naming where to
// sign in (the protected resource metadata), which is what starts Claude's
// sign-in; with one, the call goes to the account's tab.
async function forAccount(request, response) {
  const origin = originOf(request);
  // Browser-based MCP clients read the challenge across origins.
  response.setHeader("access-control-allow-origin", "*");
  response.setHeader("access-control-expose-headers", "www-authenticate, mcp-session-id");
  if (request.method === "OPTIONS") {
    return response.status(204)
      .setHeader("access-control-allow-headers",
        "authorization, content-type, mcp-protocol-version, mcp-session-id")
      .setHeader("access-control-allow-methods", "POST, GET, DELETE, OPTIONS")
      .end();
  }
  const presented = bearer(request);
  const grant = presented ? await grantOf(presented, resourceOf(origin)) : null;
  if (!grant) {
    response.setHeader("www-authenticate", presented
      ? challenge(origin, "the token is unknown, expired, or its connection was disconnected")
      : challenge(origin));
    return response.status(401).json({
      error: presented ? "invalid_token" : "unauthorized",
      error_description: "Sign in to Brickworks: Claude asks you to when you add this address as a connector.",
    });
  }
  // A connection approved while signed in with orangecheck, which cannot
  // be vouched for just now (api/_oauth.js): a moment's wait, not a sign-in.
  if (grant.unsure) {
    return response.status(503).setHeader("retry-after", "30").json({
      error: "temporarily_unavailable",
      error_description: "Brickworks could not check this connection's orangecheck sign-in just now. Try again in a minute.",
    });
  }
  if (request.method === "GET") return response.status(405).setHeader("allow", "POST").end();
  if (request.method === "DELETE") return response.status(204).end();
  if (request.method !== "POST") return response.status(405).end();
  // A session id for each conversation, handed out at initialize: what
  // keeps one conversation's calls in the tab it chose (relay_picks).
  const session = sessionOf(request);
  const give = request.body && request.body.method === "initialize" && !session
    ? sessionFor(showsApps(request.body), randomBytes(24).toString("base64url")) : null;
  return await fromClaude(accountTabs(grant, origin, session || give), request.body, response, give, streams(request));
}

// The tab switching on: what it would answer to initialize and tools/list,
// and which page load it is. The latest page load to switch on is the one
// that listens; an older one asking for work is told it has been replaced.
//
// Only while signed in. The session's access token comes with it and is
// verified before anything is written; the account it names becomes the
// connector's owner, and an address another account owns is refused.
async function helloFromTab(channel, instance, request, response) {
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    const status = trouble instanceof AuthError ? trouble.status : 401;
    return response.status(status).json({
      error: "sign in to Brickworks to connect Claude",
      reason: trouble.message,
    });
  }
  const body = request.body;
  if (!body || typeof body !== "object" || !Array.isArray(body.tools)) {
    return response.status(400).json({ error: "hello needs tools" });
  }
  const tab = await tabOf(channel);
  if (tab && tab.owner && tab.owner !== claims.sub) {
    return response.status(403).json({
      error: "this connector address belongs to another Brickworks account",
    });
  }
  // Which tab it is, to Claude: its id and its model's name.
  const id = String(request.query?.tab || "");
  await db("relay_tabs", {
    method: "POST",
    body: {
      channel, seen_at: new Date().toISOString(), instance, visible: true, open: true,
      owner: claims.sub,
      hello: { instructions: String(body.instructions || ""), tools: body.tools },
      tab: TAB_ID.test(id) ? id : null,
      model: modelFrom(body.model),
      used_at: usedFrom(request.query?.used) || new Date().toISOString(),
    },
    prefer: "resolution=merge-duplicates",
  });
  return response.status(204).end();
}

// The tab's side: say it is listening, then take the next request.
async function nextForTab(channel, instance, request, response) {
  const tab = await tabOf(channel);
  if (instance && tab && tab.instance && tab.instance !== instance) {
    return response.status(409).json({ error: "another page took over this connector" });
  }
  // Work goes only to a connector a signed-in page switched on. Without
  // this, the check on hello would be one a page could step round by
  // never saying hello.
  if (!tab || !tab.owner) {
    return response.status(401).json({
      error: "switch the connector on while signed in to Brickworks",
    });
  }
  const seen = { channel, seen_at: new Date().toISOString(), open: true };
  const used = usedFrom(request.query?.used);
  const model = modelFrom(request.query?.model);
  if (used) seen.used_at = used;
  if (model !== null) seen.model = model;
  await db("relay_tabs", {
    method: "POST",
    body: seen,
    prefer: "resolution=merge-duplicates",
  });
  if (Math.random() < 0.05) await db("rpc/relay_sweep", { method: "POST", body: {} });
  const until = Date.now() + WORK_WAIT_MS;
  while (Date.now() < until) {
    const taken = await db("rpc/relay_take", { method: "POST", body: { p_channel: channel } });
    if (taken && taken.length > 0) {
      const { id, request } = taken[0];
      // The page said it was closing while this ask was waiting: the call
      // goes back, for Claude to be told, not to a page that has gone.
      const still = await tabOf(channel);
      if (!still || still.open === false) {
        await db(`relay?id=eq.${id}`, { method: "PATCH", body: { taken_at: null } });
        return response.status(204).end();
      }
      // A notification is delivered once and wants no answer, so it is
      // not left to be handed out again.
      if (request.id === undefined || request.id === null) {
        await db(`relay?id=eq.${id}`, { method: "DELETE" });
      }
      return response.status(200).json({ id, request });
    }
    await sleep(POLL_MS);
  }
  return response.status(204).end();
}

export default async function handler(request, response) {
  response.setHeader("cache-control", "no-store");
  if (!dbConfigured()) {
    return response.status(503).json({ error: "the connector is not configured on this deployment" });
  }
  const token = String(request.query?.t || "");
  if (token === "") {
    try {
      return await forAccount(request, response);
    } catch (trouble) {
      return response.status(502).json({ error: String(trouble.message || trouble) });
    }
  }
  if (!TOKEN.test(token)) {
    return response.status(404).json({ error: "no such connector" });
  }
  // Streamable HTTP's server-to-client stream, which a stateless server
  // does not offer.
  if (request.method === "GET") {
    return response.status(405).setHeader("allow", "POST").end();
  }
  if (request.method === "DELETE") return response.status(204).end();
  if (request.method !== "POST") return response.status(405).end();

  const channel = channelOf(token);
  const op = String(request.query?.op || "");
  const instance = INSTANCE.test(String(request.query?.i || "")) ? String(request.query.i) : null;
  // Only the page load that is listening may say it is out of view or gone.
  const mine = instance ? `&or=(instance.is.null,instance.eq.${instance})` : "";
  try {
    if (op === "") {
      // A session id here too, for the list of tools each conversation was
      // given; the tab is the address's either way.
      const session = sessionOf(request);
      const give = request.body && request.body.method === "initialize" && !session
        ? sessionFor(showsApps(request.body), randomBytes(24).toString("base64url")) : null;
      return await fromClaude(oneTab(channel, session || give), request.body, response, give, streams(request));
    }
    if (op === "hello") {
      if (!instance) return response.status(400).json({ error: "hello needs ?i=" });
      return await helloFromTab(channel, instance, request, response);
    }
    if (op === "next") return await nextForTab(channel, instance, request, response);
    if (op === "state") {
      // Also the page's word that it is alive, so it counts as seen; and
      // when it was last used, and what its model is called now.
      const said = { visible: String(request.query?.visible) !== "0", seen_at: new Date().toISOString() };
      const used = usedFrom(request.query?.used);
      const model = modelFrom(request.query?.model);
      if (used) said.used_at = used;
      if (model !== null) said.model = model;
      await db(`relay_tabs?channel=eq.${channel}${mine}`, { method: "PATCH", body: said });
      return response.status(204).end();
    }
    if (op === "answer") {
      const id = Number(request.query?.id);
      const answer = request.body;
      if (!Number.isInteger(id) || !answer || typeof answer !== "object") {
        return response.status(400).json({ error: "answer what?" });
      }
      await db(`relay?id=eq.${id}&channel=eq.${channel}`, {
        method: "PATCH",
        body: { response: answer, answered_at: new Date().toISOString() },
      });
      // The model's name as the call left it: a call can begin, open or
      // name one, and the list of tabs should say so at once.
      const named = modelFrom(answer.result?._meta?.["brickworks/model"]);
      if (named !== null) {
        await db(`relay_tabs?channel=eq.${channel}`, { method: "PATCH", body: { model: named } });
      }
      return response.status(204).end();
    }
    // Which chats work in this tab, for it to show (also sent to it as
    // brickworks/chats whenever a chat chooses it or leaves it).
    if (op === "chats") {
      return response.status(200).json({ chats: await chatsIn(channel) });
    }
    // The person keeps one chat in this tab: every other chat working in it
    // is moved off, and its next call is told so and does nothing.
    if (op === "keep") {
      const kept = String(request.query?.chat || "");
      if (!/^[0-9a-f]{8}$/.test(kept)) return response.status(400).json({ error: "keep which chat?" });
      const rows = await db(`relay_picks?channel=eq.${channel}&select=${PICK}`) || [];
      if (!rows.some((one) => chatOf(one.key) === kept && holds(one))) {
        return response.status(404).json({ error: "that chat is not working in this tab", chats: await chatsIn(channel) });
      }
      const moved = rows.filter((one) => chatOf(one.key) !== kept && holds(one));
      for (const one of moved) {
        await db(`relay_picks?key=eq.${encodeURIComponent(one.key)}`, {
          method: "PATCH", body: { moved_at: new Date().toISOString() },
        });
      }
      return response.status(200).json({ moved: moved.length, chats: await chatsIn(channel) });
    }
    if (op === "close") {
      // Kept, for its hello: Claude can still list the tools, and a call
      // is told the tab is shut.
      await db(`relay_tabs?channel=eq.${channel}${mine}`, {
        method: "PATCH",
        body: { open: false },
      });
      return response.status(204).end();
    }
    return response.status(400).json({ error: `no op ${op}` });
  } catch (trouble) {
    return response.status(502).json({ error: String(trouble.message || trouble) });
  }
}
