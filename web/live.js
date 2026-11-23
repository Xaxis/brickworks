// Building now, at /live/<watch> (buildlive, 2026-11-23): a model watched
// as it is built in a Build together session its designer opened to
// watchers (api/together.js "Watching", docs/TOGETHER.md).
//
// The page opens on the show as it stands (op=watching, the same for every
// visitor and kept by the CDN for two seconds): the parts, the chat, who
// builds and how many watch. Then it hears each change as it is numbered,
// on the show's own channel of the database's Realtime, a part landing in
// the 3D view in the frame after it came (web/live3d.js, built from
// tools/viewer/live.js). Every message there is signed by the relay, and a
// message this page cannot check is dropped: anybody may say anything on a
// public channel, so only the relay's words change what is shown. What the
// page missed (a message lost, the tab asleep, a reconnect) it reads back by
// number (op=watch_ops), and it asks that every heard_ms anyway, which is
// also how it is counted among the watchers.
//
// Signed in: chat, as comments' rule has it (13 or over, not taken out of
// the gallery, nobody either of them blocked), and Ask to build; the
// designer may give a seat, and then Build with them now opens the session
// in the studio. Signed out it all reads the same, with Sign in to chat.
// Nothing here edits the model: the page holds the show's name, never the
// session's secret, and the relay refuses an edit by it.
//
// Every word goes on the page as text. window.brickworksLive is what a check
// reads (tools/web/live_flow.mjs): when each change came and was drawn.
import { askToSignIn, call, signedIn } from "/account.js";
import { langAt, say, told } from "/card.js";
import { openReport } from "/report.js";

const W = /\/live\/([A-Za-z0-9]{12})\/?$/.exec(location.pathname)?.[1] || "";
// The longest line the relay keeps (api/together.js CHAT_MOST).
const LINE_MOST = 280;
const TESTS = new URLSearchParams(location.search).get("tests") === "1" ? "&tests=1" : "";
const API = "/api/together";
const $ = (id) => document.getElementById(id);
const VIEWER_KEY = "brickworks.watcher";

const state = {
  w: W, seq: 0, bricks: new Map(), meshes: {}, colours: {}, names: {}, chat: [], people: [], watchers: 0, ended: false,
  closed: false, me: null, key: null, socket: null, view: null, verified: 0, dropped: 0, catching: null,
  // When each change was heard here and drawn, by its number (a check reads them).
  heard: {}, drawn: {}, errors: [], ready: false, channel: "",
};
window.brickworksLive = state;

/// This page's own name among the watchers: random, kept in this browser.
function viewer() {
  try {
    let name = localStorage.getItem(VIEWER_KEY);
    if (!/^[a-z0-9]{16}$/.test(String(name))) {
      name = Array.from(crypto.getRandomValues(new Uint8Array(16)), (b) => "abcdefghijklmnopqrstuvwxyz0123456789"[b % 36]).join("");
      localStorage.setItem(VIEWER_KEY, name);
    }
    return name;
  } catch {
    return "";
  }
}
const ME = viewer();

const counted = (n, one, many) => `${Number(n).toLocaleString(globalThis.brickworksLang?.locale || "en-US")} ${say(n === 1 ? one : many)}`;

function tell(words) {
  $("live-said").textContent = words;
  $("live-said").hidden = !words;
}

async function asked(op, body = null) {
  try {
    const reply = body === null
      ? await fetch(`${API}?op=${op}&w=${W}${TESTS}`, { headers: { accept: "application/json" } })
      : await fetch(`${API}?op=${op}`, { method: "POST", headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify(body) });
    return { status: reply.status, body: await reply.json().catch(() => null) };
  } catch (trouble) {
    return { status: 0, body: { error: trouble.message } };
  }
}

// -- what changed ---------------------------------------------------------------

/// [op] ({seq, who, changes}) put into what is shown.
function take(op, via) {
  if (!op || !Number.isInteger(op.seq) || op.seq <= state.seq) return false;
  const changes = op.changes || {};
  let parts = false;
  for (const [key, value] of Object.entries(changes)) {
    if (key.startsWith("~")) continue;
    parts = true;
    if (Array.isArray(value)) state.bricks.set(key, value);
    else state.bricks.delete(key);
  }
  if (typeof changes["~title"] === "string" && changes["~title"]) {
    $("live-title").textContent = changes["~title"];
  }
  const by = typeof changes["~by"] === "string" ? changes["~by"] : state.names[op.who] || say("A builder");
  if (typeof changes["~chat"] === "string") line({ who: op.who, by, text: changes["~chat"] });
  if (changes["~ask"] !== undefined) line({ who: op.who, by, text: say("asked to build"), kind: "ask" });
  if (typeof changes["~seat"] === "string") {
    const given = state.people.find((one) => one.who === changes["~seat"]);
    line({ who: changes["~seat"], by: state.names[changes["~seat"]] || given?.name || say("Somebody"), text: say("has a seat now"), kind: "seat" });
    if (state.me && changes["~seat"] === state.me.who) seated();
  }
  if (parts) state.heard[op.seq] = { at: Date.now(), via };
  return parts;
}

/// A message on the channel, or an answer read back: its parts' looks, its
/// names, then its changes in order; read back from the relay if it skips
/// a number.
function takeAll(said, via) {
  Object.assign(state.meshes, said.meshes || {});
  Object.assign(state.colours, said.colours || {});
  Object.assign(state.names, said.names || {});
  let parts = false;
  if (Number.isInteger(said.from) && said.from > state.seq + 1) {
    catchUp();
    return;
  }
  for (const op of said.ops || []) parts = take(op, via) || parts;
  const to = Number.isInteger(said.to) ? said.to : Number.isInteger(said.seq) ? said.seq : state.seq;
  state.seq = Math.max(state.seq, to);
  if (Number.isInteger(said.watchers)) watchers(said.watchers);
  if (said.ended || said.closed) end(said.ended ? "ended" : "closed");
  if (said.more) catchUp();
  if (parts) draw();
}

/// The changes after the last one here, read back from the relay; and this
/// page counted among the watchers.
function catchUp() {
  if (state.catching) return state.catching;
  state.catching = (async () => {
    for (let round = 0; round < 20; round++) {
      const got = await asked("watch_ops", { w: W, after: state.seq, viewer: ME });
      if (got.status !== 200 || !got.body) return;
      takeAll({ ...got.body, from: undefined }, "read");
      if (!got.body.more) return;
    }
  })().finally(() => { state.catching = null; });
  return state.catching;
}

// -- drawing ------------------------------------------------------------------

let drawQueued = false;
function draw() {
  if (drawQueued) return;
  drawQueued = true;
  requestAnimationFrame(() => {
    drawQueued = false;
    const count = state.bricks.size;
    $("live-stage").dataset.parts = String(count);
    if (!state.view) return;
    state.view.show(state.bricks, state.meshes, state.colours);
    const now = Date.now();
    for (const seq of Object.keys(state.heard)) if (!state.drawn[seq]) state.drawn[seq] = now;
    if (count === 0) tell(say("Nothing on the baseplate yet. Parts show here as they go down."));
    else if ($("live-said").textContent && !state.ended) tell("");
  });
}

async function startView(root) {
  let made;
  try {
    made = await import("/live3d.js");
  } catch (trouble) {
    state.errors.push(String(trouble?.message || trouble));
    tell(say("This browser could not load the 3D view. The chat still works."));
    return;
  }
  if (!made.webglWorks()) {
    tell(say("This browser cannot draw in 3D. The chat still works."));
    return;
  }
  const stage = $("live-stage");
  state.view = new made.LiveView(stage, { root, errors: state.errors,
    still: matchMedia("(prefers-reduced-motion: reduce)").matches, touchAction: () => "none" });
  try {
    state.view.start();
  } catch (trouble) {
    state.view = null;
    tell(say("This browser would not draw it ({why})", { why: trouble.message }));
    return;
  }
  new ResizeObserver(() => state.view?.size()).observe(stage);
  draw();
}

// -- the channel ----------------------------------------------------------------

function bytesOf(text) {
  const raw = atob(String(text).replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(String(text).length / 4) * 4, "="));
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

/// The relay's key, which a message must be signed with to be taken; null
/// where this browser cannot check one (then the page reads every change
/// back instead, a little later).
async function keyOf(raw) {
  try {
    return await crypto.subtle.importKey("raw", bytesOf(raw), { name: "Ed25519" }, false, ["verify"]);
  } catch {
    return null;
  }
}

async function heard(payload) {
  if (!payload || typeof payload.d !== "string" || typeof payload.sig !== "string" || !state.key) return;
  let good = false;
  try {
    good = await crypto.subtle.verify({ name: "Ed25519" }, state.key, bytesOf(payload.sig), new TextEncoder().encode(payload.d));
  } catch {
    good = false;
  }
  if (!good) {
    state.dropped += 1;
    return;
  }
  let said;
  try { said = JSON.parse(payload.d); } catch { return; }
  if (said?.w !== W) {
    state.dropped += 1;
    return;
  }
  state.verified += 1;
  takeAll(said, "told");
}

let backoff = 1000;
function listen(channel) {
  if (!channel?.url || !channel.key || !channel.topic || state.ended) return;
  let socket;
  try {
    socket = new WebSocket(`${channel.url}?apikey=${encodeURIComponent(channel.key)}&vsn=1.0.0`);
  } catch {
    return;
  }
  state.socket = socket;
  const topic = `realtime:${channel.topic}`;
  let ref = 1;
  let beat = null;
  socket.addEventListener("open", () => {
    socket.send(JSON.stringify({ topic, event: "phx_join", ref: String(ref++), join_ref: "1",
      payload: { config: { broadcast: { self: false, ack: false }, presence: { key: "" }, postgres_changes: [], private: false } } }));
    beat = setInterval(() => socket.readyState === 1 && socket.send(JSON.stringify({ topic: "phoenix", event: "heartbeat",
      payload: {}, ref: String(ref++) })), 25_000);
  });
  socket.addEventListener("message", (event) => {
    let said;
    try { said = JSON.parse(String(event.data)); } catch { return; }
    if (said?.topic !== topic) return;
    if (said.event === "phx_reply" && said.ref === "1") {
      state.channel = said.payload?.status === "ok" ? "joined" : "refused";
      backoff = 1000;
      // Whatever was said before it listened.
      catchUp();
    } else if (said.event === "broadcast" && said.payload?.event === channel.event) {
      heard(said.payload.payload);
    }
  });
  socket.addEventListener("close", () => {
    clearInterval(beat);
    state.channel = "closed";
    if (state.socket !== socket || state.ended) return;
    setTimeout(() => listen(channel), backoff);
    backoff = Math.min(backoff * 2, 30_000);
  });
}

// -- the chat -------------------------------------------------------------------

function line({ who, by, text, kind = "chat" }) {
  const item = document.createElement("li");
  item.className = kind;
  const name = document.createElement("b");
  name.textContent = by;
  item.append(name, " ", document.createTextNode(text));
  if (who && state.people.some((one) => one.who === who && one.owner)) item.classList.add("designer");
  const list = $("live-chat");
  const atEnd = list.scrollHeight - list.scrollTop - list.clientHeight < 40;
  list.append(item);
  while (list.children.length > 200) list.firstChild.remove();
  if (atEnd) list.scrollTop = list.scrollHeight;
}

function builders() {
  const names = state.people.map((one) => one.owner ? say("{name} (designer)", { name: one.name }) : one.name);
  $("live-builders").textContent = names.length ? say("Building: {names}", { names: names.join(", ") }) : "";
}

function watchers(n) {
  state.watchers = n;
  $("live-watchers").textContent = counted(n, "watching", "watching");
}

async function me() {
  if (!signedIn()) {
    $("live-say").hidden = true;
    $("live-ask").hidden = state.ended;
    $("live-note").textContent = say("Sign in to chat and to ask to build.");
    return;
  }
  const got = await call(`${API}?op=watch_me`, { method: "POST", body: { w: W } });
  if (got.status !== 200 || !got.body) return;
  state.me = got.body;
  $("live-say").hidden = Boolean(got.body.chat) || state.ended;
  $("live-note").textContent = got.body.chat || "";
  $("live-ask").hidden = got.body.owner || got.body.seated || got.body.removed || state.ended;
  if (got.body.owner) $("live-note").textContent = say("It is your build: you chat with the watchers from the studio’s Build together.");
  if (got.body.seated) seated();
}

async function seated() {
  const got = await call(`${API}?op=watch_seat`, { method: "POST", body: { w: W } });
  if (got.status !== 200 || !got.body?.seated || !got.body.link) return;
  const go = $("live-seat");
  go.href = got.body.link;
  go.hidden = false;
  $("live-ask").hidden = true;
  $("live-note").textContent = say("The designer gave you a seat. Build with them now opens the build in the studio.");
}

$("live-say").addEventListener("submit", async (event) => {
  event.preventDefault();
  const field = $("live-text");
  const text = field.value.trim();
  if (!text) return;
  // Too long is said, never cut: the field has no maxlength, which a paste
  // would have cut short without a word.
  const length = [...text].length;
  if (length > LINE_MOST) {
    $("live-note").textContent = say("A line is at most {most} characters; this one has {n}.", { most: LINE_MOST, n: length });
    return;
  }
  field.disabled = true;
  const got = await call(`${API}?op=watch_say`, { method: "POST", body: { w: W, text } });
  field.disabled = false;
  if (got.status === 200) {
    field.value = "";
    $("live-note").textContent = "";
    // Shown as the relay numbers it, from the channel; read back meanwhile.
    catchUp();
  } else {
    $("live-note").textContent = told(got.body?.error, say("That did not send. Try again in a moment."));
  }
  field.focus();
});

$("live-ask").addEventListener("click", async () => {
  if (!signedIn()) {
    if (!(await askToSignIn(say("ask to build")))) return;
    await me();
    if ($("live-ask").hidden) return;
  }
  const button = $("live-ask");
  button.disabled = true;
  const got = await call(`${API}?op=watch_ask`, { method: "POST", body: { w: W } });
  if (got.status === 200 && got.body?.seated) {
    seated();
  } else if (got.status === 200) {
    button.textContent = say("Asked");
    $("live-note").textContent = say("Asked. The designer sees it in the studio and can give you a seat.");
    catchUp();
    return;
  } else {
    $("live-note").textContent = told(got.body?.error, say("That did not send. Try again in a moment."));
  }
  button.disabled = false;
});

$("live-share").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(location.origin + location.pathname);
    $("live-share").textContent = say("Copied");
  } catch {
    $("live-share").textContent = location.origin + location.pathname;
  }
});

// -- the show --------------------------------------------------------------------

function end(how) {
  if (state.ended) return;
  state.ended = true;
  state.closed = how === "closed";
  $("live-badge").classList.add("over");
  $("live-state").textContent = how === "closed" ? say("No longer open to watchers") : say("This build has ended");
  $("live-ended-words").textContent = how === "closed" ? say("The designer closed this build to watchers.")
    : say("This build has ended.");
  $("live-ended").hidden = false;
  $("live-say").hidden = true;
  $("live-ask").hidden = true;
  tell("");
  const socket = state.socket;
  state.socket = null;
  try { socket?.close(); } catch {}
}

async function open() {
  if (!W) {
    tell(say("That is not the address of a build."));
    return;
  }
  const got = await asked("watching");
  if (got.status !== 200 || !got.body) {
    $("live-state").textContent = say("No such build");
    $("live-badge").classList.add("over");
    tell(got.status === 404 ? say("There is no build at this address. It may have ended a while ago.")
      : say("Brickworks could not open this build just now. Try again in a minute."));
    return;
  }
  const show = got.body;
  document.title = say("{title}, building now · Brickworks", { title: show.title || say("A build") });
  $("live-title").textContent = show.title || say("A build");
  if (show.designer?.handle) {
    const by = $("live-by");
    by.replaceChildren(document.createTextNode(say("by") + " "));
    const link = document.createElement("a");
    link.href = `${langAt()}/u/${show.designer.handle}`;
    link.textContent = show.designer.name || show.designer.handle;
    by.append(link);
    $("live-designer-link").href = link.href;
    $("live-ended-designer").href = link.href;
    $("live-ended-designer").hidden = false;
    $("live-more").hidden = false;
    $("live-report").hidden = false;
    $("live-report").addEventListener("click", () => openReport({ handle: show.designer.handle }, say("this build")));
  }
  if (show.model) {
    $("live-ended-model").href = `/m/${show.model}#log`;
    $("live-ended-model").hidden = false;
  }
  state.people = show.people || [];
  for (const one of state.people) state.names[one.who] = one.name;
  builders();
  for (const said of show.chat || []) line({ who: said.who, by: said.by || state.names[said.who] || say("A builder"), text: said.text });
  state.meshes = show.meshes || {};
  state.colours = show.colours || {};
  for (const [uid, ...value] of show.bricks || []) state.bricks.set(uid, value);
  state.seq = Number(show.seq) || 0;
  watchers(Number(show.watchers) || 0);
  state.ready = true;
  if (show.ended || show.closed) {
    end(show.ended ? "ended" : "closed");
  }
  await startView(show.root || "");
  draw();
  if (state.ended) return;
  me();
  state.key = show.verify ? await keyOf(show.verify) : null;
  if (state.key) listen(show.channel);
  catchUp();
  // Counted among the watchers, and anything missed read back: as often as
  // the relay asks while the channel is heard, and every 1.5 s while it is
  // not (no Ed25519 in this browser to check a message, the channel refused,
  // or reconnecting), the page's only way to hear then.
  const often = Number(show.heard_ms) || 20_000;
  let asked = Date.now();
  const tick = setInterval(() => {
    if (state.ended) return clearInterval(tick);
    const hearing = Boolean(state.key) && state.channel === "joined";
    if (hearing && (Date.now() - asked < often || document.visibilityState !== "visible")) return;
    asked = Date.now();
    catchUp();
  }, 1500);
  document.addEventListener("visibilitychange", () => document.visibilityState === "visible" && catchUp());
}

open();
