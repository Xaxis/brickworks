// The console's Notifications (admin.html #notifications, ownernotify,
// 2026-11-18): what mails the owner about the site, and when; and every mail
// sent, held or folded (/api/admin?op=notify, api/_notify.js,
// docs/OWNER_NOTIFY.md). /admin?tests=1: the checks' own, mailed only to
// Resend's test inbox.
//
// A mail's one-click "turn this off" lands here (#notifications/off/...):
// acted on at once, signed in or not, by its own signed key (offFromLink).
//
// Everything is put on the page as text, never as markup.
import { $, TESTS, adminJson, ago, cell, count, emptyRow, link, make, post, say, timeCell, when } from "/admin-kit.js";

let state = null;
let onChange = () => {};
export function whenChanged(then) { onChange = then; }

const OPS = { notify_sent: "Mailed", notify_folded: "Mailed, several in one", notify_held: "Held", notify_failed: "Not sent",
  notify_off: "Turned off by a mail's link", notify_set: "You changed the settings", notify_address: "You asked for another address",
  notify_confirm: "You confirmed an address", notify_test: "You sent a test", notify_flush: "You pressed Check now" };
const KINDS = { now: "at once", digest: "the daily digest", fold: "several in one", test: "a test", confirm: "an address's code",
  alarm: "an alarm" };
const STATES = { sent: "Sent", dry: "Kept as the test inbox would have it", failed: "Not sent" };

const nameOf = (event) => state?.catalog?.find((one) => one.id === event)?.name || event;

/// Every half hour of a day, as a select's choices.
function times(select) {
  if (select.options.length) return;
  for (let minutes = 0; minutes < 24 * 60; minutes += 30) {
    const value = `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
    select.append(new Option(value, value));
  }
}
/// The select set to [value], with it added when it is not a half hour.
function choose(select, value) {
  if (![...select.options].some((one) => one.value === value)) select.append(new Option(value, value));
  select.value = value;
}

function zones(select, current) {
  if (!select.options.length) {
    const all = typeof Intl.supportedValuesOf === "function" ? Intl.supportedValuesOf("timeZone") : [];
    for (const zone of ["UTC", ...all.filter((one) => one !== "UTC")]) select.append(new Option(zone.replaceAll("_", " "), zone));
  }
  choose(select, current);
}

/// One of the owner's changes saved: [body] (notify_set), said at [where].
/// Two in flight at once (a field left by a press on another) may answer
/// in either order: an answer older than the settings shown is not drawn
/// over them (the row's version, api/_notify.js notifySet).
function save(body, where, said) {
  return post({ op: "notify_set" }, where, said, { body, after: (answer) => {
    if (Number(answer.version) < Number(state.version || 0)) return;
    state = { ...state, settings: answer.settings, digest: answer.digest || state.digest, version: answer.version, active: true,
      set: true };
    drawState();
    onChange();
  } });
}

// ---------------------------------------------------------------------------
// The kinds of event, a row each.

function drawEvents() {
  const list = $("notify-events");
  list.replaceChildren();
  for (const one of state.catalog) {
    const mine = state.settings.events[one.id];
    const li = make("li", "card");
    li.dataset.event = one.id;
    // What a press on this row says, said on the row: on a phone the list is taller than the screen.
    const said = make("p", "said");
    said.id = `notify-said-${one.id}`;
    said.setAttribute("role", "status");
    const box = make("input");
    box.type = "checkbox";
    box.checked = mine.on;
    box.id = `notify-on-${one.id}`;
    box.dataset.on = one.id;
    box.addEventListener("change", () => save({ events: { [one.id]: { on: box.checked } } }, said.id,
      `${one.name}: ${box.checked ? "on" : "off"}.`).then((went) => { if (!went) box.checked = !box.checked; }));
    const words = make("span", "", make("b", "", one.name), make("small", "", one.says));
    const choice = make("label", "choice", box, words);
    const row = make("div", "row");
    const timing = make("div", "segmented");
    timing.setAttribute("role", "group");
    timing.setAttribute("aria-label", `When: ${one.name}`);
    for (const [value, label] of [["now", "At once"], ["digest", "Daily digest"]]) {
      const button = make("button", "", label);
      button.type = "button";
      button.dataset.value = value;
      button.setAttribute("aria-pressed", String(mine.when === value));
      button.addEventListener("click", async () => {
        if (button.getAttribute("aria-pressed") === "true") return;
        const went = await save({ events: { [one.id]: { when: value } } }, said.id,
          `${one.name}: ${value === "now" ? "at once" : "in the daily digest"}.`);
        if (went) for (const other of timing.querySelectorAll("button")) other.setAttribute("aria-pressed", String(other === button));
      });
      timing.append(button);
    }
    row.append(timing);
    const numbers = { ...(one.threshold ? { threshold: one.threshold } : {}), ...(one.sizes || {}) };
    if (Object.keys(numbers).length) li.classList.add("numbers");
    for (const [field, range] of Object.entries(numbers)) {
      const input = make("input");
      input.type = "number";
      input.min = String(range.min);
      input.max = String(range.max);
      input.step = field === "threshold" ? "1" : "any";
      input.inputMode = field === "threshold" ? "numeric" : "decimal";
      input.value = String(mine[field]);
      input.dataset.field = field;
      input.addEventListener("change", () => {
        const value = Number(input.value);
        if (!input.value || !Number.isFinite(value) || value < range.min || value > range.max) {
          say(said.id, `${one.name}: ${range.unit} is a number from ${range.min} to ${range.max.toLocaleString()}.`, true);
          input.value = String(state.settings.events[one.id][field]);
          return;
        }
        save({ events: { [one.id]: { [field]: value } } }, said.id, `${one.name}: ${value} ${range.unit}.`)
          .then((went) => { if (!went) input.value = String(state.settings.events[one.id][field]); });
      });
      row.append(make("label", "number", input, range.unit));
    }
    const test = make("button", "cta ghost small", "Send a test");
    test.type = "button";
    test.setAttribute("aria-label", `Send a test of “${one.name}”`);
    test.addEventListener("click", () => sendTest(test, one.id));
    row.append(test);
    li.append(choice, row, said);
    list.append(li);
  }
}

// ---------------------------------------------------------------------------
// The headline, the address and the rest of the settings.

/// ", sent at 07:00 when quiet hours end" when the digest's time is inside
/// quiet hours, as the server says (api/_notify.js digestTime); else "".
const heldDigest = () => (state?.digest?.held_until ? `, ${state.digest.said}` : "");

function drawState() {
  const s = state.settings;
  const missing = [];
  if (!state.mail_key) missing.push("RESEND_API_KEY (Vercel › Settings › Environment Variables): this deployment sends no mail");
  if (state.address?.account === "—" && !TESTS) missing.push("MASTER_EMAIL: the owner's address is not set here");
  let headline;
  if (!state.applied) headline = "Not ready here";
  else if (s.paused) headline = "Paused: nothing is mailed";
  else if (!state.active) headline = TESTS ? "The checks' own: off until a setting is saved" : "Off here until a setting is saved";
  else if (state.quiet_now) headline = `Quiet hours until ${s.quiet.to}: mail is held`;
  else headline = `Mailing ${state.address.to}`;
  say("notify-headline", headline);
  const parts = [];
  if (state.applied && state.active && !s.paused) {
    parts.push(`${state.hour.sent} of ${state.hour.cap} mails in the last hour.`);
    parts.push(`The digest at ${s.digest_at} (${s.tz})${heldDigest()}${state.digest.last ? `, last on ${state.digest.last}` : ""}.`);
  }
  if (state.scope !== "live") {
    parts.push(`This deployment (${state.scope}) is not brickworks.diy: it mails only what happens here, and only once a setting is saved.`);
  }
  parts.push(`Sent by the cron every five minutes on brickworks.diy; Check now runs it here, now.`);
  if (missing.length) parts.push(`Set ${missing.join("; and ")}.`);
  say("notify-said", parts.join(" "), missing.length > 0);
  for (const id of ["notify-test", "notify-flush"]) $(id).disabled = !state.applied;

  // Where.
  const a = state.address || {};
  $("notify-to").textContent = a.to || "—";
  say("notify-to-said", a.own ? `your account's own${TESTS ? ": Resend's test inbox" : ""}` : "another address you confirmed");
  // Shown too while a code waits: pressed, the code is dropped and mail stays here.
  $("notify-own").hidden = a.own !== false && !a.pending;
  $("notify-confirm").hidden = !a.pending;
  say("notify-pending", a.pending || "—");
  $("notify-paused").checked = s.paused;
  $("notify-quiet-on").checked = s.quiet.on;
  for (const id of ["notify-quiet-from", "notify-quiet-to", "notify-digest-at"]) times($(id));
  choose($("notify-quiet-from"), s.quiet.from);
  choose($("notify-quiet-to"), s.quiet.to);
  choose($("notify-digest-at"), s.digest_at);
  zones($("notify-tz"), s.tz);
  $("notify-cap").value = String(s.cap);
  for (const field of $("notify-form").querySelectorAll("input, select, button")) field.disabled = !state.applied;
  $("tab-notify-failed").textContent = "";
  const failed = (state.mails || []).filter((one) => one.state === "failed").length;
  if (failed) $("tab-notify-failed").textContent = String(failed);
  const badge = $("nav-notifications");
  badge.hidden = !failed;
  badge.textContent = failed ? String(failed) : "";
}

$("notify-paused").addEventListener("change", () => {
  const on = $("notify-paused").checked;
  save({ paused: on }, "notify-form-said", on ? "Paused: nothing is mailed, nor kept." : "Mailing again.")
    .then((went) => { if (!went) $("notify-paused").checked = !on; });
});
$("notify-quiet-on").addEventListener("change", () => {
  const on = $("notify-quiet-on").checked;
  save({ quiet: { on, from: $("notify-quiet-from").value, to: $("notify-quiet-to").value } }, "notify-form-said",
    on ? `Quiet from ${$("notify-quiet-from").value} until ${$("notify-quiet-to").value}.` : "No quiet hours.")
    .then((went) => { if (!went) $("notify-quiet-on").checked = !on; });
});
for (const id of ["notify-quiet-from", "notify-quiet-to"]) {
  $(id).addEventListener("change", () => save({ quiet: { from: $("notify-quiet-from").value, to: $("notify-quiet-to").value } },
    "notify-form-said", `Quiet hours from ${$("notify-quiet-from").value} until ${$("notify-quiet-to").value}.`)
    .then((went) => { if (!went) drawState(); }));
}
$("notify-digest-at").addEventListener("change", () => save({ digest_at: $("notify-digest-at").value }, "notify-form-said",
  (answer) => `The digest goes at ${answer.settings.digest_at}${heldDigest()}.`).then((went) => { if (!went) drawState(); }));
$("notify-tz").addEventListener("change", () => save({ tz: $("notify-tz").value }, "notify-form-said",
  `Times are in ${$("notify-tz").value.replaceAll("_", " ")}.`).then((went) => { if (!went) drawState(); }));
$("notify-cap").addEventListener("change", () => {
  const cap = Number($("notify-cap").value);
  if (!Number.isInteger(cap) || cap < 1 || cap > 60) {
    say("notify-form-said", "At most 1 to 60 mails an hour.", true);
    $("notify-cap").value = String(state.settings.cap);
    return;
  }
  save({ cap }, "notify-form-said", `At most ${cap} ${cap === 1 ? "mail" : "mails"} an hour.`).then((went) => { if (!went) drawState(); });
});
// Enter in a field is a change, never the form sent.
$("notify-form").addEventListener("submit", (event) => event.preventDefault());

$("notify-other").addEventListener("click", () => {
  $("notify-new").hidden = false;
  $("notify-new-address").focus();
});
$("notify-send-code").addEventListener("click", async () => {
  const address = $("notify-new-address").value.trim();
  if (!address) return say("notify-address-said", "Type the address first.", true);
  $("notify-send-code").disabled = true;
  const went = await post({ op: "notify_address" }, "notify-address-said",
    (answer) => `A code went to ${answer.pending}. Type it below within 30 minutes; mail goes to ${answer.to} until then.`,
    { body: { address }, after: (answer) => { state.address = { ...state.address, pending: answer.pending }; } });
  $("notify-send-code").disabled = false;
  if (went) {
    $("notify-new").hidden = true;
    // The code's field, and Back to my account's address to drop it.
    drawState();
    $("notify-code").focus();
  }
});
$("notify-confirm-code").addEventListener("click", async () => {
  const code = $("notify-code").value.trim();
  $("notify-confirm-code").disabled = true;
  const went = await post({ op: "notify_confirm" }, "notify-address-said", (answer) => `Mail goes to ${answer.to} from now.`,
    { body: { code }, after: (answer) => { state.address = { ...state.address, to: answer.to, own: false, pending: null }; } });
  $("notify-confirm-code").disabled = false;
  if (went) {
    $("notify-code").value = "";
    drawState();
  }
});
$("notify-code").addEventListener("keydown", (event) => { if (event.key === "Enter") $("notify-confirm-code").click(); });
$("notify-new-address").addEventListener("keydown", (event) => { if (event.key === "Enter") $("notify-send-code").click(); });
$("notify-own").addEventListener("click", async () => {
  $("notify-own").disabled = true;
  const went = await post({ op: "notify_address" }, "notify-address-said", (answer) => `Mail goes to ${answer.to}, your account's own.`,
    { body: { address: "" }, after: (answer) => { state.address = { ...state.address, to: answer.to, own: true, pending: null }; } });
  $("notify-own").disabled = false;
  if (went) drawState();
});

/// A test of the whole, said in the card at the top, or of one kind, said on its row.
async function sendTest(button, event = "") {
  button.disabled = true;
  const where = event ? `notify-said-${event}` : "notify-acted";
  await post({ op: "notify_test" }, where, (answer) => `${answer.outcome === "dry"
    ? "Kept as Resend's test inbox would have it" : "Sent"}: “${answer.subject}”, to ${answer.to}.`,
  { body: event ? { event } : {}, after: () => loadNotify({ rows: false }) });
  button.disabled = false;
}
$("notify-test").addEventListener("click", () => sendTest($("notify-test")));
$("notify-flush").addEventListener("click", async () => {
  $("notify-flush").disabled = true;
  await post({ op: "notify_flush" }, "notify-acted", (answer) => (answer.mails ? `${answer.mails} ${answer.mails === 1 ? "mail" : "mails"}: `
    + `${answer.sent.map((one) => `“${one.subject}” (${STATES[one.state] || one.state})`).join(", ")}.`
    : `Nothing to mail now (${answer.outcome}).`), { after: () => loadNotify({ rows: false }) });
  $("notify-flush").disabled = false;
});

function drawNotHere() {
  $("notify-not-here").replaceChildren(...(state.not_here || []).map((one) => make("li", "",
    make("span", "", make("b", "", one.name)), make("small", "why", one.why, one.href ? " " : "",
      one.href ? link(one.href, "Where it is") : ""))));
}

// ---------------------------------------------------------------------------
// Sent: the audit's rows of notifications, with each mail's words.

/// A change of the settings, as the audit keeps it (its JSON, cut at 120
/// characters), in words; as it is when it was cut.
function changeOf(value) {
  let asked;
  try {
    asked = JSON.parse(value);
  } catch {
    return value;
  }
  const bits = [];
  for (const [id, mine] of Object.entries(asked.events || {})) {
    const what = [];
    if ("on" in mine) what.push(mine.on ? "on" : "off");
    if ("when" in mine) what.push(mine.when === "now" ? "at once" : "in the daily digest");
    const kind = state?.catalog?.find((one) => one.id === id);
    for (const [field, number] of Object.entries(mine)) {
      if (["on", "when"].includes(field)) continue;
      const range = field === "threshold" ? kind?.threshold : kind?.sizes?.[field];
      what.push(range ? `${number} ${range.unit}` : `${field} ${number}`);
    }
    bits.push(`${nameOf(id)}: ${what.join(", ")}`);
  }
  if ("paused" in asked) bits.push(asked.paused ? "Pause all" : "mailing again");
  if (asked.quiet) bits.push(`quiet hours${"on" in asked.quiet ? ` ${asked.quiet.on ? "on" : "off"}` : ""}`
    + `${asked.quiet.from ? ` from ${asked.quiet.from}` : ""}${asked.quiet.to ? ` until ${asked.quiet.to}` : ""}`);
  if (asked.digest_at) bits.push(`the digest at ${asked.digest_at}`);
  if (asked.tz) bits.push(`times in ${asked.tz.replaceAll("_", " ")}`);
  if ("cap" in asked) bits.push(`at most ${asked.cap} an hour`);
  return bits.join("; ") || value;
}

function saidOf(row) {
  const said = row.detail?.said || {};
  const mail = state.mails?.find((one) => one.id === said.mail);
  const bits = [];
  if (mail) bits.push(`“${mail.subject}”`);
  if (said.kind && KINDS[said.kind]) bits.push(KINDS[said.kind]);
  if (said.events) bits.push(`${said.events} ${Number(said.events) === 1 ? "event" : "events"}`);
  if (said.kinds) bits.push(said.kinds);
  if (said.until) bits.push(`until ${/T/.test(said.until) ? when(said.until) : said.until}`);
  if (said.cap) bits.push(`the hour's cap of ${said.cap}`);
  if (said.to) bits.push(`to ${said.to}`);
  if (said.state && STATES[said.state] && row.op !== "notify_failed") bits.push(STATES[said.state]);
  if (row.op === "notify_set" && said.value) bits.push(changeOf(said.value));
  if (row.op === "notify_off" && said.by) bits.push(said.by);
  return bits.join(" · ") || "—";
}

function drawSent() {
  const body = $("notify-sent");
  body.replaceChildren();
  const rows = state.sent || (state.mails || []).map((one) => ({ at: one.at, op: one.state === "failed" ? "notify_failed"
    : one.kind === "fold" ? "notify_folded" : "notify_sent", target: one.event || one.kind, status: one.state === "failed" ? 502 : 200,
  said: one.said, detail: { said: { mail: one.id, kind: one.kind, events: one.events, to: one.sent_to, state: one.state } } }));
  for (const one of rows) {
    const row = make("tr");
    timeCell(row, one.at).dataset.label = "When";
    // notify_address with no code's time is the address put back to the account's own.
    const home = one.op === "notify_address" && one.status === 200 && !one.detail?.said?.until;
    cell(row, home ? "You put mail back to your account's address" : OPS[one.op] || one.op).dataset.label = "What";
    cell(row, nameOf(one.target) || "—").dataset.label = "Of";
    cell(row, saidOf(one), "text").dataset.label = "Said";
    const ok = one.status >= 200 && one.status < 300;
    // A mail that did not go is Not sent; a change of yours refused is Refused.
    const fault = one.op === "notify_failed" ? "Not sent" : "Refused";
    const outcome = cell(row, make("span", ok ? "pill good" : "pill bad", ok ? "Done" : fault));
    outcome.dataset.label = "Outcome";
    if (!ok && one.said) outcome.append(" ", make("small", "why faint", one.said));
    const acts = cell(row, "", "acts");
    const mailId = one.detail?.said?.mail;
    if (mailId && state.mails?.some((m) => m.id === mailId)) {
      const read = make("button", "cta ghost small", "Read it");
      read.type = "button";
      read.addEventListener("click", () => readMail(mailId));
      acts.append(read);
    }
    body.append(row);
  }
  if (!body.rows.length) emptyRow(body, state.applied ? "Nothing mailed yet." : "Nothing kept here yet.");
  const w = state.waiting || {};
  $("n-notify-hour").textContent = state.applied ? count(state.hour?.sent) : "—";
  say("n-notify-cap", state.applied ? `at most ${state.hour?.cap} an hour` : "");
  $("n-notify-held").textContent = state.applied ? count(w.held) : "—";
  $("n-notify-capped").textContent = state.applied ? count(w.capped) : "—";
  $("n-notify-digest").textContent = state.applied ? count(w.digest) : "—";
  say("n-notify-digest-at", state.applied ? `at ${state.settings.digest_at}${heldDigest()}` : "");
  say("notify-sent-note", state.sent === null && state.applied ? "The audit is not kept here yet (supabase/console.sql): the mails "
    + "themselves are shown." : "");
}

async function readMail(id) {
  const { mail } = await adminJson({ op: "notify", mail: id }).catch((problem) => {
    say("notify-sent-note", problem.message, true);
    return {};
  });
  if (!mail) return;
  $("notify-mail").hidden = false;
  say("notify-mail-subject", mail.subject);
  say("notify-mail-said", `${when(mail.at)} (${ago(mail.at)}) · ${KINDS[mail.kind] || mail.kind} · to ${mail.sent_to} · `
    + `${STATES[mail.state] || mail.state}${mail.said ? `: ${mail.said}` : ""}`);
  $("notify-mail-body").textContent = mail.body || "(Its words are not kept: the account it was about was deleted.)";
  $("notify-mail-subject").focus();
}

/// The section read and drawn; after a test or Check now the kinds' rows are
/// left as they are (nothing of them changed), so focus stays on the press.
export async function loadNotify({ rows = true } = {}) {
  state = await adminJson({ op: "notify" });
  const off = $("notify-not-yet");
  off.hidden = state.applied !== false;
  off.textContent = state.applied === false ? state.said : "";
  drawState();
  if (rows || !$("notify-events").children.length) drawEvents();
  drawNotHere();
  drawSent();
}

// ---------------------------------------------------------------------------
// A mail's one-click "turn this off".

const OFF = /^#notifications\/off\/([a-z_]{1,40})\/([rt])\/([0-9a-f]{32})$/;

/// The address's one-click link acted on: what it did, in words, or null
/// when the address is no such link. The address is put back to the
/// section's own at once, so the link's key stays out of the history.
export async function offFromLink() {
  const found = OFF.exec(location.hash);
  if (!found) return null;
  const [, event, pool, token] = found;
  history.replaceState(null, "", `${location.pathname}${location.search}#notifications/settings`);
  try {
    const reply = await fetch("/api/plans?op=notify_off", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ event, pool, token }) });
    const said = await reply.json().catch(() => ({}));
    if (reply.ok) return { ok: true, words: `“${said.name}” mails are off. Turn them back on here, under What mails you.` };
    return { ok: false, words: reply.status === 404 ? "That link turns nothing off: it is not this site's, or its settings were made again."
      : `That did not go just now (${reply.status}). Try the link again in a minute.` };
  } catch {
    return { ok: false, words: "That did not go just now. Try the link again in a minute." };
  }
}
