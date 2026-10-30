// The beta's applications, for the owner (beta-admin.html): /api/admin?op=beta
// asked with the session in this browser (web/account.js), drawn, and each
// decided with ?op=beta_decide. Every word is put on the page as text,
// never as markup: the answers are what people typed.
import { call, signedIn } from "/account.js";

const $ = (id) => document.getElementById(id);
const TESTS = new URLSearchParams(location.search).get("tests") === "1";
const AI = { claude: "Claude", chatgpt: "ChatGPT", own_key: "Their own API key", not_sure: "Not sure yet" };
const BACKGROUND = { new: "New to both", lego: "Builds LEGO® models", cad: "Uses CAD", both: "Both" };
const STATUS = { new: "New", waitlist: "Waitlist", approved: "Approved", declined: "Declined" };
const when = (iso) => (iso ? new Date(iso).toLocaleString(undefined, { year: "numeric", month: "short", day: "numeric",
  hour: "2-digit", minute: "2-digit" }) : "");
const day = (iso) => (iso ? new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" }) : "");
let status = "new";

function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

/// What was read of an application, each [words, flagged].
function signalsOf(app) {
  const f = app.facts || {};
  const s = app.signals || {};
  const issues = s.quality?.issues || [];
  const n = (k, one, many) => `${k} ${k === 1 ? one : many}`;
  return [
    [f.confirmed ? "Email confirmed: signed in with a code sent to it" : "Email not confirmed", !f.confirmed],
    [`Account ${n(f.age_days ?? 0, "day", "days")} old`, (f.age_days ?? 0) < 1],
    [s.disposable ? `Disposable email domain: ${s.domain}` : `Email domain: ${s.domain || "?"}`, s.disposable === true],
    [f.same_inbox ? `Same inbox as ${n(f.same_inbox, "other account", "other accounts")} (${f.same_inbox_applied} applied)`
      : "No other account at this inbox", (f.same_inbox_applied ?? 0) > 0],
    [f.models_kept || f.models_shared ? `Has used the app: ${n(f.models_kept, "model", "models")} kept, ${f.models_shared} shared`
      : "Has not kept or shared a model yet", !(f.models_kept || f.models_shared)],
    [issues.length ? `The form: ${issues.join(", ")}` : `The form: ${n(s.quality?.words ?? 0, "word", "words")}, nothing odd`,
      issues.length > 0],
    ...(app.early ? [["Account from before 29 October 2026: has Pro already, takes no spot", false]] : []),
  ];
}

function row(list, term, ...value) {
  list.append(make("dt", "", term), make("dd", "", ...value));
}

function card(app) {
  const item = make("li", "card app");
  const pill = make("span", app.status === "approved" ? "pill good" : app.status === "new" ? "pill new" : "pill",
    STATUS[app.status] + (app.spot ? ` · spot ${app.spot}` : ""));
  item.append(make("div", "top", make("h2", "", app.email || app.account), pill));
  const facts = make("dl");
  row(facts, "Applied", when(app.applied_at));
  row(facts, "Would build", app.build);
  row(facts, "Uses", AI[app.ai] || app.ai);
  row(facts, "Background", BACKGROUND[app.background] || app.background, app.background_line ? `: ${app.background_line}` : "");
  if (app.link) {
    const link = make("a", "", app.link);
    link.href = app.link;
    link.rel = "noopener noreferrer nofollow ugc";
    link.target = "_blank";
    row(facts, "Link", link);
  }
  const signals = make("ul", "signals");
  for (const [words, flagged] of signalsOf(app)) signals.append(make("li", flagged ? "flag" : "", flagged ? `Check: ${words}` : words));
  row(facts, "Read of it", signals);
  if (app.status === "approved" && !app.early) {
    row(facts, "Month", app.comp === "granted"
      ? `Given: ${day(app.month_starts_at)} to ${day(app.month_ends_at)}`
      : `Still to give${app.comp_said ? `: ${app.comp_said}` : ""}`);
  }
  for (const one of app.decisions || []) {
    row(facts, one.decision === "approved" ? "Approved" : "Declined", `by ${one.by}, ${when(one.at)}${one.note ? `: ${one.note}` : ""}`);
  }
  item.append(facts);
  if (app.status !== "approved") item.append(decideForm(app));
  return item;
}

function decideForm(app) {
  const form = make("form");
  const label = make("label", "", "A note, for you ", make("small", "", "optional: kept with the decision"));
  const note = make("input");
  note.maxLength = 500;
  note.name = "note";
  label.append(note);
  const approve = make("button", "cta small", "Approve");
  approve.type = "button";
  const decline = make("button", "cta ghost small", "Decline");
  decline.type = "button";
  approve.setAttribute("aria-label", `Approve ${app.email}`);
  decline.setAttribute("aria-label", `Decline ${app.email}`);
  const said = make("p", "said");
  said.setAttribute("role", "status");
  form.append(label, make("div", "actions", approve, ...(app.status === "declined" ? [] : [decline])), said);
  form.addEventListener("submit", (event) => event.preventDefault());
  const decide = async (decision) => {
    approve.disabled = decline.disabled = true;
    said.textContent = decision === "approve" ? "Approving…" : "Declining…";
    const reply = await call(`/api/admin?op=beta_decide&account=${encodeURIComponent(app.account)}`,
      { method: "POST", body: { decision, note: note.value } }).catch(() => null);
    if (reply?.status === 200) {
      $("said").textContent = decision === "approve"
        ? `${app.email}: approved${reply.body.application?.spot ? `, spot ${reply.body.application.spot}` : ", no spot (early)"}`
          + `${reply.body.month?.said ? `. ${reply.body.month.said}` : ""}; email ${reply.body.mail}.`
        : `${app.email}: declined; email ${reply.body.mail}.`;
      return load();
    }
    said.textContent = reply?.body?.error || "That did not go just now. Try again.";
    approve.disabled = decline.disabled = false;
    if (reply?.status === 409) load();
  };
  approve.addEventListener("click", () => decide("approve"));
  decline.addEventListener("click", () => decide("decline"));
  return form;
}

async function load() {
  const query = new URLSearchParams({ op: "beta", ...(status ? { status } : {}), ...(TESTS ? { tests: "1" } : {}) });
  const reply = await call(`/api/admin?${query}`).catch(() => null);
  if (!reply || reply.status !== 200) {
    $("gate").hidden = false;
    $("view").hidden = true;
    $("gate-note").textContent = reply?.status === 404 ? "This account cannot see this page."
      : reply?.body?.error || "The applications could not be read just now.";
    return;
  }
  const q = reply.body;
  $("n-given").textContent = `${q.pool.given} of ${q.pool.cap}`;
  $("n-left").textContent = String(q.pool.left);
  $("n-new").textContent = String(q.counts.new);
  $("n-waitlist").textContent = String(q.counts.waitlist);
  $("n-pending").textContent = String(q.counts.pending);
  $("months").textContent = `${TESTS ? "The site's checks' own pool (?tests=1). " : ""}The beta is ${q.beta === "open"
    ? "open" : "off: /beta says it is coming soon"}. Billing is ${q.months.billing}: a month is given ${TESTS ? q.months.test
    : q.months.live}.`;
  $("grant").hidden = q.months.billing === "off";
  const list = $("apps");
  list.replaceChildren(...q.applications.map(card));
  $("empty").hidden = q.applications.length > 0;
  $("gate").hidden = true;
  $("view").hidden = false;
}

for (const button of document.querySelectorAll("[data-status]")) {
  button.addEventListener("click", () => {
    status = button.dataset.status;
    for (const one of document.querySelectorAll("[data-status]")) one.setAttribute("aria-pressed", String(one === button));
    load();
  });
}
$("grant").addEventListener("click", async () => {
  $("grant").disabled = true;
  $("said").textContent = "Giving the months still to give…";
  const reply = await call("/api/admin?op=beta_grant", { method: "POST" }).catch(() => null);
  $("said").textContent = reply?.status === 200
    ? `Given: ${reply.body.granted}; still to give: ${reply.body.pending}${reply.body.said?.length ? ` (${reply.body.said.join(" ")})` : ""}.`
    : reply?.body?.error || "That did not go just now. Try again.";
  $("grant").disabled = false;
  load();
});

if (!signedIn()) {
  $("gate-note").textContent = "You are not signed in to Brickworks in this browser.";
} else {
  load();
}
