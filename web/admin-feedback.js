// The owner's feedback inbox, on /admin (#feedback; admin.html): every
// report, newest first, filtered by what it is, where it stands and whether a
// beta tester sent it; each with its words, who sent it, what came with it
// (the picture shown, the model to download, the details and the log), where
// it stands and a private note to change, and the answers, with one to send
// (api/_feedback.js through /api/admin). /admin?tests=1: the site's checks'
// own reports instead.
//
// Everything is put on the page as text, never as markup: every word here
// was typed by somebody else.
import { signedIn, token } from "/account.js";

const $ = (id) => document.getElementById(id);
const TESTS = new URLSearchParams(location.search).get("tests") === "1";
const KINDS = { bug: "Bug", idea: "Idea", question: "Question" };
const STANDS = { new: "New", seen: "Seen", planned: "Planned", fixed: "Fixed", wont_fix: "Won’t fix" };
const filters = { kind: "", status: "open", beta: "" };
let replyFrom = null;

const when = (iso) => (iso ? new Date(iso).toLocaleString(undefined, { year: "numeric", month: "short", day: "numeric",
  hour: "2-digit", minute: "2-digit" }) : "");

function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

async function ask(path, { method = "GET", body } = {}) {
  if (!signedIn()) throw new Error("You are not signed in to Brickworks in this browser.");
  const access = await token();
  if (!access) throw new Error("Your sign-in has ended. Sign in to Brickworks again.");
  const headers = { authorization: `Bearer ${access}` };
  if (body !== undefined) headers["content-type"] = "application/json";
  return fetch(path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
}

async function askJson(path, options) {
  const reply = await ask(path, options);
  const said = await reply.json().catch(() => ({}));
  if (!reply.ok) throw new Error(said.error || `The server said ${reply.status}.`);
  return said;
}

/// A report's file, fetched with the sign-in: a picture shown in the card, a
/// model downloaded.
async function file(report, which, button) {
  button.disabled = true;
  try {
    const reply = await ask(`/api/admin?op=feedback_file&id=${report.id}&file=${which}`);
    if (!reply.ok) throw new Error((await reply.json().catch(() => ({}))).error || `The server said ${reply.status}.`);
    const blob = await reply.blob();
    const url = URL.createObjectURL(blob);
    if (which === "picture") {
      const picture = make("img", "picture");
      picture.alt = `The picture sent with report ${report.id}`;
      picture.src = url;
      button.replaceWith(picture);
      return;
    }
    const link = make("a");
    link.href = url;
    link.download = `report-${report.id}.mpd`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
    button.disabled = false;
  } catch (trouble) {
    button.disabled = false;
    button.textContent = trouble.message;
  }
}

/// One report's card.
function card(report) {
  const item = make("li");
  item.id = `feedback-${report.id}`;
  item.dataset.report = String(report.id);
  item.dataset.status = report.status;
  const marks = make("p", "marks", make("span", "pill", KINDS[report.kind] || report.kind),
    report.beta ? make("span", "pill new", "Beta tester") : null, make("span", "pill", STANDS[report.status]),
    make("span", "", `${report.email || "no address"}${report.signed_in ? "" : " (signed out)"}`),
    make("small", "faint", `${when(report.at)} · ${report.source === "app" ? "the app" : "the site"}`
      + `${report.page ? `, ${report.page}` : ""} · #${report.id}`));
  item.append(marks, make("p", "words", report.words));

  const details = Object.entries(report.details || {});
  if (details.length) {
    const list = make("dl");
    for (const [name, value] of details) list.append(make("dt", "", name.replace(/_/g, " ")), make("dd", "", String(value)));
    item.append(list);
  }
  const files = make("div", "row");
  if (report.picture) {
    const show = make("button", "", "Show the picture");
    show.type = "button";
    show.dataset.act = "picture";
    show.addEventListener("click", () => file(report, "picture", show));
    files.append(show);
  }
  if (report.model) {
    const get = make("button", "", "Download the model");
    get.type = "button";
    get.dataset.act = "model";
    get.addEventListener("click", () => file(report, "model", get));
    files.append(get);
  }
  if (files.childElementCount) item.append(files);
  if (report.log) {
    const log = make("details", "", make("summary", "", `The app’s log, ${report.log.split("\n").length} lines`),
      make("pre", "", report.log));
    item.append(log);
  }
  for (const answer of report.replies || []) {
    item.append(make("div", "answer", make("small", "faint", `${when(answer.at)}, ${answer.by}, `
      + `${{ sent: "emailed", dry: "kept (a test inbox: no mail here)", failed: "not emailed" }[answer.mail] || answer.mail}`),
    make("br"), answer.words));
  }

  // Where it stands, and the note.
  const triage = make("form");
  const stands = make("select");
  stands.setAttribute("aria-label", `Where report ${report.id} stands`);
  for (const [value, words] of Object.entries(STANDS)) {
    const option = make("option", "", words);
    option.value = value;
    option.selected = value === report.status;
    stands.append(option);
  }
  const note = make("textarea");
  note.rows = 2;
  note.maxLength = 2000;
  note.value = report.note || "";
  note.placeholder = "A note for you alone";
  note.setAttribute("aria-label", `Your note on report ${report.id}`);
  const save = make("button", "", "Save");
  save.type = "submit";
  const saved = make("span", "note");
  saved.setAttribute("role", "status");
  triage.append(make("div", "row", stands, save, saved), note);
  triage.addEventListener("submit", async (event) => {
    event.preventDefault();
    save.disabled = true;
    try {
      const said = await askJson(`/api/admin?op=feedback_triage&id=${report.id}`, { method: "POST",
        body: { status: stands.value, note: note.value } });
      item.replaceWith(card(said.report));
      $(`feedback-${report.id}`)?.querySelector("form span.note")?.append("Saved.");
    } catch (trouble) {
      saved.textContent = trouble.message;
      save.disabled = false;
    }
  });

  // An answer, emailed.
  const reply = make("form");
  const words = make("textarea");
  words.rows = 3;
  words.maxLength = 4000;
  words.required = true;
  words.placeholder = report.email ? `Your answer to ${report.email}` : "Your answer";
  words.setAttribute("aria-label", `Your answer to report ${report.id}`);
  const send = make("button", "", "Send the answer");
  send.type = "submit";
  const sent = make("span", "note");
  sent.setAttribute("role", "status");
  reply.append(words, make("div", "row", send, sent));
  reply.addEventListener("submit", async (event) => {
    event.preventDefault();
    send.disabled = true;
    sent.textContent = "Sending…";
    try {
      const said = await askJson(`/api/admin?op=feedback_reply&id=${report.id}`, { method: "POST", body: { words: words.value } });
      const fresh = card(said.report);
      item.replaceWith(fresh);
      fresh.querySelectorAll("form span.note")[1]?.append({ sent: "Emailed.", dry: "Kept: a test inbox, and no mail here.",
        failed: "Kept, but the email did not go." }[said.mail] || "");
    } catch (trouble) {
      sent.textContent = trouble.message;
      send.disabled = false;
    }
  });
  item.append(triage, reply);
  return item;
}

async function load() {
  const query = new URLSearchParams({ op: "feedback" });
  for (const [name, value] of Object.entries(filters)) if (value) query.set(name, value);
  if (TESTS) query.set("tests", "1");
  const note = $("fb-note");
  note.textContent = "Looking…";
  try {
    const said = await askJson(`/api/admin?${query}`);
    replyFrom = said.reply_to;
    $("fb-from").textContent = said.mail ? (replyFrom ? `, answering to ${replyFrom}` : "") : " (no mail key here: kept, not sent)";
    const counts = said.counts || {};
    note.textContent = `${said.reports.length} shown. Of ${counts.all ?? 0}${TESTS ? " of the checks’" : ""}: `
      + `${counts.new ?? 0} new, ${counts.seen ?? 0} seen, ${counts.planned ?? 0} planned, ${counts.fixed ?? 0} fixed, `
      + `${counts.wont_fix ?? 0} won’t fix; ${counts.beta ?? 0} from testers.`;
    $("fb-list").replaceChildren(...said.reports.map(card));
    if (location.hash.startsWith("#feedback-")) document.querySelector(location.hash)?.scrollIntoView({ block: "start" });
  } catch (trouble) {
    note.textContent = trouble.message;
  }
}

for (const group of document.querySelectorAll("#fb-filters [data-filter]")) {
  group.addEventListener("click", (event) => {
    const button = event.target.closest("button[data-value]");
    if (!button) return;
    for (const other of group.querySelectorAll("button")) other.setAttribute("aria-pressed", String(other === button));
    filters[group.dataset.filter] = button.dataset.value;
    load();
  });
}
load();
