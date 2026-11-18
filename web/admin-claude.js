// Claude in the owner's console (adminclaude, 2026-11-18; docs/ADMIN_CLAUDE.md,
// api/_claude.js): Claude › Settings, where the owner's own Anthropic key is
// checked and kept (on the server alone: this page is only ever told its
// last four characters), the model chosen from the ones that key may use,
// the effort and the month's cap in dollars; and Claude itself, one
// conversation in a panel beside every section, open on Social, which reads
// what the console reads and writes nothing but drafts on the social desk.
//
// The desk's own asks are here too, put into the desk from this file: Suggest
// a post beside Write's community, Suggest a reply on each thing that came
// in, Improve on each draft, and the desk's Overview. Each answer streams
// in as it is written; each draft Claude keeps lands among the desk's
// drafts, marked by Claude, for the owner to edit and send, or not.
//
// The conversation is kept in this tab (sessionStorage) and sent back with
// each ask, as the server handed it over; a turn that did not end whole
// (stopped, refused, cut off) is left out of it. Everything is put on the
// page as text, never as markup: what came in was written by strangers, and
// Claude's words are not markup either.
import { signedIn, token } from "/account.js";
import { $, TESTS, adminJson, ago, day, make, say } from "/admin-kit.js";
import { extras, open as openDraft, reread as rereadDesk } from "/admin-social.js";

// Docked beside the page at this width and wider; over it, closed until
// asked for, below.
const DOCK_AT = 1100;
const MOST = 8000;
const POOL = TESTS ? ".tests" : "";
const DOCK_KEY = "brickworks.admin.claude.dock";
const CHAT_KEY = `brickworks.admin.claude.chat${POOL}`;
const TOOL_WORDS = {
  social_inbox: "Read the inbox", social_thread: "Read the thread", social_sends: "Read the drafts and sends",
  social_overview: "Read the desk's results", social_rules: "Read the community's rules", whats_new: "Read what is new",
  make_draft: "Kept a draft", people_counts: "Read the sign-up counts", plans_read: "Read the plans", mail_health: "Read the mail's health",
  site_health: "Read the site's health", feedback_list: "Read the feedback",
};
const EFFORT_WORDS = { low: "Low", medium: "Medium", high: "High (suits most asks)", xhigh: "Extra high", max: "Most" };
const MONTH = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });

let claude = null;
let models = null;
let modelsSaid = "";
let started = false;
let section = "overview";
let busy = null;
// The conversation as the API keeps it, and what the panel shows of it.
let chat = { model: null, history: [], shown: [] };

const money = (n) => {
  const value = Number(n) || 0;
  return value > 0 && value < 0.01 ? `$${value.toFixed(4)}` : `$${value.toLocaleString("en", { minimumFractionDigits: 2,
    maximumFractionDigits: 2 })}`;
};
const monthOf = (id) => (/^\d{4}-\d{2}$/.test(String(id || "")) ? MONTH.format(new Date(`${id}-01T00:00:00Z`)) : "this month");
const nameOf = (id) => models?.find((one) => one.id === id)?.name || id;
const length = (text) => [...String(text || "").normalize("NFC")].length;
const excerpt = (words, most = 90) => (words.length > most ? `${words.slice(0, most - 1)}…` : words);

function stored(where, name) {
  try {
    return where.getItem(name);
  } catch {
    return null;
  }
}
function store(where, name, value) {
  try {
    if (value === null) where.removeItem(name);
    else where.setItem(name, value);
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Claude › Settings.

/// GET op=claude, and the models the kept key may use: the section drawn.
export async function loadClaude() {
  claude = await adminJson({ op: "claude" });
  models = null;
  modelsSaid = "";
  if (claude.ready && claude.key) {
    try {
      models = (await adminJson({ op: "claude_models" })).models;
    } catch (problem) {
      modelsSaid = problem.message;
    }
  }
  drawSettings();
  drawDock();
}

function drawSettings() {
  const c = claude;
  const not = $("claude-not-yet");
  not.hidden = c.ready;
  not.textContent = c.ready ? "" : `${c.said} Nothing can be kept here until it is applied.`;
  $("claude-stand-in").hidden = !c.stand_in;
  const noSecret = c.ready && !c.secret?.set;
  const secret = $("claude-secret");
  secret.hidden = !noSecret;
  secret.textContent = noSecret ? `To keep a key, this deployment needs ${c.secret.name}: a random string of at least 32 characters `
    + "(openssl rand -base64 48), added in Vercel › Settings › Environment Variables for Production and Preview, then a redeploy. The key is "
    + "sealed with it, so the database alone opens nothing. Switches lists it." : "";
  const key = c.key;
  $("claude-key-shown").textContent = key ? `Kept: ${key.shown}, since ${day(key.set_at)}. Checked ${ago(key.checked_at)}: ${key.said || "—"}`
    : "No key yet.";
  $("claude-key-l").firstChild.textContent = key ? "Another key, to use instead " : "Anthropic API key ";
  $("claude-key-keep").textContent = key ? "Check and use it" : "Check and keep";
  $("claude-check").hidden = !key;
  $("claude-forget").hidden = !key;
  for (const control of $("claude-key-form").elements) control.disabled = !c.ready || noSecret;
  // A key is forgotten without the secret; it is checked only with it.
  $("claude-forget").disabled = !c.ready;

  const pick = $("claude-model");
  const list = models?.length ? models : [{ id: c.model, name: c.model, efforts: c.efforts, price: c.price }];
  pick.replaceChildren(...list.map((one) => {
    const option = make("option", "", one.name === one.id ? one.id : `${one.name} (${one.id})`);
    option.value = one.id;
    return option;
  }));
  pick.value = list.some((one) => one.id === c.model) ? c.model : list[0].id;
  efforts();
  $("claude-cap").value = Number(c.cap_usd).toFixed(2);
  say("claude-models-said", !key ? "With a key kept, the models it may use are listed here, newest first."
    : modelsSaid ? `The models could not be read: ${modelsSaid}` : models ? `${models.length} model${models.length === 1 ? "" : "s"} your key `
      + "may use that think as the console asks (adaptive thinking), newest first." : "", Boolean(modelsSaid));
  for (const control of $("claude-settings-form").elements) control.disabled = !c.ready;
  drawMonth();
}

/// The chosen model's efforts, its price, and the effort kept when it has it.
function efforts() {
  const chosen = $("claude-model").value;
  const one = models?.find((each) => each.id === chosen);
  const levels = one?.efforts?.length ? one.efforts : claude.efforts;
  const was = $("claude-effort").value || claude.effort;
  $("claude-effort").replaceChildren(...levels.map((level) => {
    const option = make("option", "", EFFORT_WORDS[level] || level);
    option.value = level;
    return option;
  }));
  $("claude-effort").value = levels.includes(was) ? was : levels.includes("high") ? "high" : levels.at(-1);
  const price = one?.price || (chosen === claude.model ? claude.price : null);
  $("claude-price").textContent = !price ? ""
    : `${nameOf(chosen)}: ${money(price.input)} a million tokens in, ${money(price.output)} out, ${money(price.cache_read)} read from the cache.`
      + (price.known ? "" : " Its price is not in the console's table, so the cap counts it at the dearest model's.");
}

function drawMonth() {
  const month = claude.month;
  const cap = Number(claude.cap_usd) || 0;
  const meter = $("claude-meter");
  if (!month) {
    $("claude-month").textContent = claude.ready ? "" : "Nothing spent: not open yet.";
    meter.hidden = true;
    return;
  }
  const spent = Number(month.spent) || 0;
  const held = Number(month.held) || 0;
  $("claude-month").textContent = `${monthOf(month.month)}: ${money(spent)} spent of ${money(cap)}, in ${Number(month.calls) || 0} `
    + `call${Number(month.calls) === 1 ? "" : "s"} to Anthropic${held > 0 ? `, and ${money(held)} held for answers still coming` : ""}. `
    + "Counted from each answer's own usage; at the cap Claude stops until next month or a higher cap.";
  meter.hidden = false;
  meter.max = cap || 1;
  meter.high = (cap || 1) * 0.8;
  meter.value = Math.min(spent, cap || 1);
}

$("claude-model").addEventListener("change", efforts);

$("claude-key-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const field = $("claude-key");
  const key = field.value.trim();
  if (!key) return say("claude-key-note", "Paste the key first.", true);
  const button = $("claude-key-keep");
  button.disabled = true;
  say("claude-key-note", "Checking it with Anthropic…");
  try {
    const done = await adminJson({ op: "claude_key" }, { method: "POST", body: { key } });
    field.value = "";
    claude = done.claude;
    await loadClaude();
    say("claude-key-note", `Kept: ${claude.key?.shown}. ${claude.key?.said || ""}`);
  } catch (problem) {
    say("claude-key-note", problem.message, true);
  } finally {
    button.disabled = false;
  }
});

$("claude-check").addEventListener("click", async () => {
  const button = $("claude-check");
  button.disabled = true;
  say("claude-key-note", "Checking it with Anthropic…");
  try {
    const done = await adminJson({ op: "claude_check" }, { method: "POST", body: {} });
    await loadClaude();
    say("claude-key-note", done.claude?.key?.said || "Checked.", done.outcome === "refused");
  } catch (problem) {
    say("claude-key-note", problem.message, true);
  } finally {
    button.disabled = false;
  }
});

$("claude-forget").addEventListener("click", async () => {
  if (!confirm(`Forget ${claude.key?.shown}? It is deleted from the server, and Claude stops until you paste a key again. `
    + "The key itself still works at Anthropic until you delete it there.")) return;
  const button = $("claude-forget");
  button.disabled = true;
  try {
    await adminJson({ op: "claude_forget" }, { method: "POST", body: {} });
    await loadClaude();
    say("claude-key-note", "Forgotten: no key is kept now.");
  } catch (problem) {
    say("claude-key-note", problem.message, true);
  } finally {
    button.disabled = false;
  }
});

$("claude-settings-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const body = { model: $("claude-model").value, effort: $("claude-effort").value, cap_usd: $("claude-cap").value.trim() };
  const button = form.querySelector("button[type=submit]");
  button.disabled = true;
  try {
    const done = await adminJson({ op: "claude_settings" }, { method: "POST", body });
    claude = done.claude;
    drawSettings();
    drawDock();
    say("claude-settings-note", `Kept: ${nameOf(claude.model)}, effort ${claude.effort}, ${money(claude.cap_usd)} a month.`);
  } catch (problem) {
    say("claude-settings-note", problem.message, true);
  } finally {
    button.disabled = false;
  }
});

// ---------------------------------------------------------------------------
// The panel: docked beside the page when there is room, over it when not.

const wide = matchMedia(`(width >= ${DOCK_AT}px)`);
const dock = $("claude-dock");
const toggle = $("claude-toggle");
let openedHere = false;

function shouldOpen() {
  if (!wide.matches) return openedHere;
  const chosen = stored(localStorage, DOCK_KEY);
  return chosen ? chosen === "open" : section === "social";
}

function place(open, { focus = false } = {}) {
  dock.hidden = !open;
  dock.classList.toggle("over", !wide.matches);
  document.body.classList.toggle("claude-docked", open && wide.matches);
  toggle.setAttribute("aria-expanded", String(open));
  if (open && focus) $("claude-q").focus();
  if (open) scrollLog();
}

function setOpen(open, { focus = false, chosen = true } = {}) {
  openedHere = open;
  if (chosen && wide.matches) store(localStorage, DOCK_KEY, open ? "open" : "closed");
  place(open, { focus });
  if (!open && focus) toggle.focus();
}

toggle.addEventListener("click", () => setOpen(dock.hidden, { focus: true }));
$("claude-close").addEventListener("click", () => setOpen(false, { focus: true }));
dock.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !event.defaultPrevented) {
    event.preventDefault();
    setOpen(false, { focus: true });
  }
});
wide.addEventListener("change", () => place(shouldOpen()));
addEventListener("hashchange", () => {
  const now = location.hash.slice(1).split("/")[0] || "overview";
  if (now === section) return;
  section = now;
  if (started) place(shouldOpen());
  drawDeskAsks();
});

/// Called once the gate opens (admin.js): the panel offered, and open
/// where it opens by itself.
export async function startClaude(at) {
  section = at || "overview";
  started = true;
  toggle.hidden = false;
  restore();
  place(shouldOpen());
  if (!claude) await loadClaude().catch((problem) => say("claude-said", problem.message, true));
  drawDeskAsks();
}

function drawDock() {
  if (!claude) return;
  const said = !claude.ready ? claude.said
    : !claude.key ? "No key yet."
      : `${nameOf(claude.model)}, effort ${claude.effort}. ${claude.month ? `${money(claude.month.spent)} of ${money(claude.cap_usd)} `
        + `spent in ${monthOf(claude.month.month)}.` : ""}${claude.stand_in ? " The checks' stand-in answers here." : ""}`;
  say("claude-said", said, !claude.ready);
  const how = $("claude-how");
  how.replaceChildren();
  if (!claude.ready) how.append("Claude opens once supabase/admin_claude.sql is applied.");
  else if (!claude.key) {
    const to = make("a", "", "Claude › Settings");
    to.href = "#claude";
    how.append("Paste your Anthropic API key in ", to, " to start. It is kept on the server alone.");
  }
  how.hidden = !how.childNodes.length;
  if (chat.model && chat.model !== claude.model && !busy && chat.shown.length) newChat(`A new chat: the model is now ${nameOf(claude.model)}.`);
  drawDeskAsks();
}

// ---------------------------------------------------------------------------
// The conversation.

const log = $("claude-log");
const scrollLog = () => { log.scrollTop = log.scrollHeight; };

function restore() {
  try {
    const kept = JSON.parse(stored(sessionStorage, CHAT_KEY) || "null");
    if (kept && Array.isArray(kept.history) && Array.isArray(kept.shown)) chat = kept;
  } catch {
    chat = { model: null, history: [], shown: [] };
  }
  log.replaceChildren(...chat.shown.map(drawEntry));
  drawEmpty();
}

function save() {
  if (!store(sessionStorage, CHAT_KEY, JSON.stringify(chat))) {
    // Too long to keep in this tab: what it shows is kept, the rest of the
    // conversation lives until the page is left.
    store(sessionStorage, CHAT_KEY, null);
  }
}

function newChat(why = "") {
  chat = { model: null, history: [], shown: [] };
  log.replaceChildren();
  if (why) add({ who: "note", text: why });
  save();
  drawEmpty();
}

$("claude-new").addEventListener("click", () => {
  if (busy) busy.abort();
  newChat();
  $("claude-q").focus();
});

function drawEmpty() {
  const empty = !log.childElementCount;
  $("claude-empty").hidden = !empty;
}

/// One entry of the conversation as the panel shows it.
function drawEntry(entry) {
  if (entry.who === "note") return make("p", "claude-note", entry.text);
  const box = make("article", `claude-msg ${entry.who}${entry.out ? " out" : ""}`);
  box.append(make("h3", "who", entry.who === "you" ? "You" : "Claude"));
  if (entry.who === "you") {
    box.append(make("p", "", entry.text));
    if (entry.out) box.append(make("p", "claude-note", "Left out of the conversation: this turn did not end whole."));
    return box;
  }
  for (const part of entry.parts) box.append(drawPart(part));
  if (entry.foot) box.append(make("p", "claude-foot", entry.foot));
  return box;
}

function drawPart(part) {
  if (part.text !== undefined) return make("p", "", part.text);
  if (part.tool) {
    const line = make("p", `claude-tool${part.tool.ok ? "" : " refused"}`, TOOL_WORDS[part.tool.name] || part.tool.name);
    if (!part.tool.ok && part.tool.said) line.append(make("small", "", ` refused: ${part.tool.said}`));
    return line;
  }
  if (part.draft) return draftCard(part.draft);
  if (part.notice) return make("p", "claude-note", part.notice);
  if (part.error) {
    const line = make("p", "claude-note bad", part.error);
    if (part.cap) {
      const to = make("a", "", "Claude › Settings");
      to.href = "#claude";
      line.append(" Raise the cap in ", to, ".");
    }
    return line;
  }
  return make("p", "");
}

function draftCard({ send, note }) {
  const card = make("div", "claude-draft");
  const where = send.community ? ` for r/${send.community}` : send.parent ? " to the thread" : "";
  card.append(make("p", "", make("b", "", `A ${send.kind === "reply" ? "reply" : "post"}${where}, kept as a draft`),
    " · marked by Claude · nothing is sent"));
  const words = make("div", "words");
  if (send.title) words.append(make("b", "", send.title));
  words.append(excerpt(send.body || send.link || "", 600));
  card.append(words);
  if (note) card.append(make("p", "claude-note", note));
  const button = make("button", "cta ghost small", "Open it in Write");
  button.type = "button";
  button.addEventListener("click", () => {
    // Words the owner has in Write are theirs: opening the draft over them
    // asks first, and says how to keep them.
    const form = $("social-form").elements;
    const theirs = [form.title?.value, form.body?.value].map((value) => String(value || "").trim());
    const same = theirs[0] === String(send.title || "").trim() && theirs[1] === String(send.body || "").trim();
    if ((theirs[0] || theirs[1]) && !same
      && !confirm("Write holds other words. Open Claude's draft in their place? To keep yours, press Keep the draft in Write first.")) return;
    if (!wide.matches) setOpen(false, { chosen: false });
    openDraft(send);
  });
  card.append(button);
  return card;
}

function add(entry) {
  chat.shown.push(entry);
  const drawn = drawEntry(entry);
  log.append(drawn);
  drawEmpty();
  scrollLog();
  return drawn;
}

/// The answer's events, as the server writes them (api/_claude.js).
async function* events(body) {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let kept = "";
  for (;;) {
    const { value, done } = await reader.read();
    kept += decoder.decode(value || new Uint8Array(), { stream: !done }).replace(/\r\n/g, "\n");
    let at;
    while ((at = kept.indexOf("\n\n")) >= 0) {
      const block = kept.slice(0, at);
      kept = kept.slice(at + 2);
      let name = "message";
      const data = [];
      for (const line of block.split("\n")) {
        if (line.startsWith("event:")) name = line.slice(6).trim();
        else if (line.startsWith("data:")) data.push(line.slice(5).replace(/^ /, ""));
      }
      if (!data.length) continue;
      try {
        yield { name, data: JSON.parse(data.join("\n")) };
      } catch {
        // Not one of the server's events.
      }
    }
    if (done) return;
  }
}

/// One ask: [kind] chat, suggest, reply, improve or overview, with what it
/// is about; [label] what the conversation shows the owner asked.
async function ask(kind, { text = "", target = {}, label = text } = {}) {
  if (busy) return false;
  if (!started) return false;
  if (!wide.matches || dock.hidden) setOpen(true, { chosen: wide.matches });
  if (!claude?.ready || !claude.key) {
    add({ who: "note", text: !claude?.ready ? "Claude is not open yet: supabase/admin_claude.sql is not applied."
      : "No key yet: paste your Anthropic API key in Claude › Settings first." });
    save();
    return false;
  }
  busy = new AbortController();
  const asking = busy;
  if (chat.model && chat.model !== claude.model) newChat(`A new chat: the model is now ${nameOf(claude.model)}.`);
  const you = { who: "you", text: label };
  const youDrawn = add(you);
  const answer = { who: "claude", parts: [], foot: "" };
  const box = add(answer);
  box.setAttribute("aria-busy", "true");
  let paragraph = null;
  let partNow = null;
  const put = (part) => {
    answer.parts.push(part);
    box.append(drawPart(part));
    paragraph = null;
    partNow = null;
    scrollLog();
  };
  holdAsk(true);
  let ended = null;
  try {
    const access = await token();
    if (!access || !signedIn()) throw new Error("You are not signed in to Brickworks in this browser.");
    const reply = await fetch(`/api/admin?op=claude_chat${TESTS ? "&tests=1" : ""}`, { method: "POST", signal: asking.signal,
      headers: { authorization: `Bearer ${access}`, "content-type": "application/json", accept: "text/event-stream" },
      body: JSON.stringify({ ask: kind, text, target, section, history: chat.history }) });
    if (!reply.ok || !/text\/event-stream/.test(reply.headers.get("content-type") || "")) {
      const said = await reply.json().catch(() => null);
      throw new Error(reply.status === 404 ? "This account cannot see this page." : said?.error || `The server said ${reply.status}.`);
    }
    for await (const { name, data } of events(reply.body)) {
      if (name === "text") {
        if (!paragraph) {
          partNow = { text: "" };
          answer.parts.push(partNow);
          paragraph = make("p", "");
          paragraph.append(document.createTextNode(""));
          box.append(paragraph);
        }
        partNow.text += data.text;
        paragraph.firstChild.appendData(data.text);
        scrollLog();
      } else if (name === "tool") put({ tool: { name: data.name, ok: data.ok, said: data.said || null } });
      else if (name === "draft") {
        put({ draft: { send: data.send, note: data.note || "" } });
        rereadDesk().catch(() => null);
      } else if (name === "notice") put({ notice: data.said });
      else if (name === "error") put({ error: data.said, cap: Boolean(data.cap) });
      else if (name === "done") ended = data;
    }
    if (!ended) throw new Error("The answer broke off before it ended: ask again.");
  } catch (problem) {
    if (asking.signal.aborted) put({ notice: "Stopped." });
    else put({ error: problem.message });
  } finally {
    if (ended?.append?.length) {
      chat.history.push(...ended.append);
      chat.model = ended.model;
    } else {
      you.out = true;
      youDrawn.append(make("p", "claude-note", "Left out of the conversation: this turn did not end whole."));
    }
    if (ended) {
      const u = ended.usage || {};
      answer.foot = `${money(ended.cost_usd)} · ${Number(u.in || 0).toLocaleString("en")} tokens in, ${Number(u.out || 0).toLocaleString("en")} `
        + `out${u.cache_read ? `, ${Number(u.cache_read).toLocaleString("en")} read from the cache` : ""}`
        + (ended.served && ended.served !== ended.model ? ` · answered by ${ended.served} (Anthropic's fallback)` : "");
      box.append(make("p", "claude-foot", answer.foot));
      if (ended.month && claude) {
        claude.month = ended.month;
        drawDock();
        drawMonth();
      }
    }
    box.removeAttribute("aria-busy");
    busy = null;
    holdAsk(false);
    save();
    scrollLog();
  }
  return true;
}

function holdAsk(held) {
  $("claude-send").disabled = held;
  $("claude-stop").hidden = !held;
  $("claude-q").setAttribute("aria-busy", String(held));
  for (const button of document.querySelectorAll("[data-claude-ask]")) button.disabled = held;
}

$("claude-stop").addEventListener("click", () => busy?.abort());

const field = $("claude-q");
function counted() {
  const n = length(field.value.trim());
  const over = n > MOST;
  $("claude-q-n").textContent = `${n.toLocaleString("en")} / ${MOST.toLocaleString("en")}`;
  $("claude-q-n").classList.toggle("bad", over);
  return n;
}
field.addEventListener("input", counted);
field.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" || event.shiftKey || event.isComposing || event.altKey || event.ctrlKey || event.metaKey) return;
  event.preventDefault();
  if (!event.repeat) $("claude-ask").requestSubmit();
});
$("claude-ask").addEventListener("submit", (event) => {
  event.preventDefault();
  if (busy) return;
  const text = field.value.trim();
  const n = counted();
  if (!text) return say("claude-ask-said", "Write what you want to ask first.", true);
  if (n > MOST) {
    return say("claude-ask-said", `Your message is ${n.toLocaleString("en")} characters: ${MOST.toLocaleString("en")} at most. `
      + "Shorten it and ask again.", true);
  }
  say("claude-ask-said", "");
  field.value = "";
  counted();
  ask("chat", { text });
});

// ---------------------------------------------------------------------------
// On the desk: its own asks, put in beside what they act on.

const deskButton = (words, run, className = "cta ghost small") => {
  const button = make("button", className, words);
  button.type = "button";
  button.dataset.claudeAsk = "";
  button.disabled = Boolean(busy);
  button.addEventListener("click", run);
  return button;
};

// Suggest, beside Write's community.
const suggest = deskButton("Suggest a post", () => {
  const community = String($("social-community").value || "").trim().replace(/^\/?r\//i, "");
  if (!/^[A-Za-z0-9_]{2,21}$/.test(community)) {
    say("social-rules-said", "Name the community to suggest a post for (r/lego), then press Suggest a post.", true);
    $("social-community").focus();
    return;
  }
  ask("suggest", { target: { community }, label: `Suggest a post for r/${community}.` });
}, "ghost");
suggest.id = "claude-suggest";
suggest.hidden = true;
$("social-rules-get").after(suggest);

// The desk's overview, under its title.
const overview = make("div", "claude-desk-row");
overview.hidden = true;
overview.append(deskButton("Overview by Claude", () => ask("overview", {
  label: "An overview of the desk: what came in, what worked, and what to post next and when." })),
make("span", "note", "What came in, what worked, and what to post next and when. Claude writes only drafts; you send."));
$("social-not-yet").after(overview);

extras.item = (one, acts) => {
  if (!claude?.ready || !/^t[134]_[A-Za-z0-9]{1,20}$/.test(String(one.external_id || ""))) return;
  acts.append(deskButton("Suggest a reply", () => ask("reply", { target: { parent: one.external_id },
    label: `Suggest a reply to ${one.author ? `u/${one.author}` : "this"}: “${excerpt(String(one.body || one.subject || ""))}”` })));
};
extras.draft = (one, row) => {
  if (one.by_claude) {
    const text = row.querySelector("td.text");
    text?.prepend(make("span", "badge accent claude-mark", "by Claude"), " ");
  }
  if (!claude?.ready || !/^[a-z0-9]{10}$/.test(String(one.id || ""))) return;
  row.querySelector("td.acts")?.append(deskButton("Improve", () => ask("improve", { target: { draft: one.id },
    label: `Improve the draft “${excerpt(String(one.title || one.body || ""))}”.` })));
};

function drawDeskAsks() {
  const ready = Boolean(started && claude?.ready);
  suggest.hidden = !ready;
  overview.hidden = !ready;
  // The rows drawn before Claude was read get their asks now.
  if (ready && !drawDeskAsks.drawn && document.querySelector("#inbox tr, #drafts tr")) {
    drawDeskAsks.drawn = true;
    rereadDesk().catch(() => null);
  }
}
