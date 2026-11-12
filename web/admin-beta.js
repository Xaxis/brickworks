// The console's Beta (admin.html #beta, #beta/applications, #beta/testers):
// its switch, the months of Pro and who asked for one, and everybody who
// joined. /api/admin?op=switches, ?op=beta and ?op=beta_testers asked with
// the session in this browser; each application decided with
// ?op=beta_decide or put on the waitlist with ?op=beta_waitlist; the beta
// flipped with ?op=beta_switch, for this deployment alone (api/_beta.js
// betaSwitch). /beta-admin, the page this was, redirects here.
//
// Every word is put on the page as text, never as markup: the answers are
// what people typed.
import { $, TESTS, act, admin, adminJson, cell, day, make, resort, say, segmented, sift, when } from "/admin-kit.js";

const AI = { claude: "Claude", chatgpt: "ChatGPT", own_key: "Their own API key", not_sure: "Not sure yet" };
const BACKGROUND = { new: "New to both", lego: "Builds LEGO® models", cad: "Uses CAD", both: "Both" };
const STATUS = { new: "New", waitlist: "Waitlist", approved: "Approved", declined: "Declined" };
const STATE = { tester: "Tester", left: "Left", not_now: "Not now" };
const VIA = { welcome: "the welcome at sign-up", app: "the app's welcome at sign-up", settings: "Settings",
  app_settings: "the app's Account", home: "the homepage", hub: "the beta hub", beta: "the beta page", bar: "the beta bar",
  application: "an application", site: "the site" };
// Each tester as listed, by account: a month's application says whether it left.
let members = new Map();
let status = "new";
let testersShown = "";
let onChange = () => {};
export function whenChanged(then) { onChange = then; }

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
    ...(members.get(app.account)?.state === "left" ? [[`Left the beta on ${day(members.get(app.account).said_at)}`, true]] : []),
  ];
}

// --- The switch -------------------------------------------------------------

/// The beta's switch, as this deployment has it ([set] from ?op=switches),
/// and the places left ([pool] from ?op=beta).
function drawSwitch(set, pool) {
  const beta = set?.beta;
  $("beta-mode").textContent = beta ? (beta.mode === "open" ? "open" : "off") : "—";
  const where = beta?.scope === "live" ? "brickworks.diy" : beta?.scope ? `this deployment (${beta.scope})` : "here";
  const places = pool ? ` ${pool.left} of ${pool.cap} months of Pro left to give.` : "";
  say("beta-switch-said", !beta ? "The switch could not be read just now."
    : beta.source === "console"
      ? `Set ${beta.mode === "open" ? "open" : "off"} from the console by ${beta.set_by || "the owner"}, ${when(beta.set_at)}, for ${where}`
        + ` alone. The project says ${beta.project}.${places}`
      : `As the project says (BRICKWORKS_BETA ${beta.project}): nothing set from the console for ${where}.${places}`);
  for (const button of $("beta-switch").querySelectorAll("button")) {
    button.setAttribute("aria-pressed", String(beta?.mode === button.dataset.beta));
    button.disabled = !beta?.ready;
  }
  if (beta && !beta.ready) say("beta-switch-note", "The switch is not open yet: supabase/console.sql is not applied.");
  const billing = set?.billing?.mode;
  say("billing-said", billing ? `Billing is ${billing}${billing === "off" ? ": no plan is sold, and the months wait for Pro" : ""}. `
    + "It is changed only outside the console (BRICKWORKS_BILLING): real money is a yes of yours, not a button." : "");
}

for (const button of $("beta-switch").querySelectorAll("button")) {
  button.addEventListener("click", async () => {
    const mode = button.dataset.beta;
    if (button.getAttribute("aria-pressed") === "true") return;
    const asked = mode === "off"
      ? "Turn the beta off here? /beta says it is coming soon, and nobody can join until it is open again. Testers stay testers."
      : "Open the beta here? /beta takes sign-ups again, and new accounts are welcomed to it.";
    if (!confirm(asked)) return;
    for (const one of $("beta-switch").querySelectorAll("button")) one.disabled = true;
    say("beta-switch-note", mode === "off" ? "Turning it off…" : "Opening it…");
    try {
      const said = await adminJson({ op: "beta_switch" }, { method: "POST", body: { mode } });
      await loadBeta();
      say("beta-switch-note", `The beta is ${said.beta.mode === "open" ? "open" : "off"} here${said.was ? `, was ${said.was}` : ""}.`
        + " Other tabs and pages follow within a minute.");
      onChange();
    } catch (problem) {
      say("beta-switch-note", problem.message, true);
      for (const one of $("beta-switch").querySelectorAll("button")) one.disabled = false;
    }
  });
}

// --- The testers ------------------------------------------------------------

/// What happened with a tester, in a line.
function testerSaid(one) {
  if (one.state === "not_now") return `Said Not now, ${day(one.said_at)}`;
  return `${one.state === "left" ? `Left ${day(one.said_at)}; joined` : "Joined"} ${day(one.joined_at)} from ${VIA[one.via] || one.via}`;
}

function monthSaid(app) {
  if (!app) return "told us nothing yet";
  if (app.status === "approved") {
    return `approved${app.spot ? `, spot ${app.spot}` : ""} (${app.comp === "granted" ? "given" : "still to give"})`;
  }
  return STATUS[app.status]?.toLowerCase() || app.status;
}

function testerRow(one) {
  const row = make("tr", "tester");
  row.dataset.state = one.state;
  row.dataset.account = one.account;
  const who = make("th");
  who.scope = "row";
  const to = make("a", "", one.email || one.account);
  to.href = `#people/${one.account}`;
  who.append(to);
  row.append(who);
  cell(row, make("span", one.state === "tester" ? "pill good" : "pill", STATE[one.state] || one.state));
  const joined = cell(row, day(one.joined_at || one.said_at));
  joined.dataset.value = one.joined_at || one.said_at || "";
  cell(row, testerSaid(one));
  cell(row, monthSaid(one.application), one.application ? "" : "faint");
  return row;
}

function siftTesters() {
  sift($("testers"), $("testers-q").value, (row) => !testersShown || row.dataset.state === testersShown);
}

/// The testers, drawn; false when they could not be read.
async function loadTesters() {
  const reply = await admin({ op: "beta_testers" }).catch(() => null);
  if (!reply || reply.status !== 200) {
    members = new Map();
    $("testers").replaceChildren();
    $("testers-empty").hidden = true;
    say("testers-said", reply?.body?.error || "The testers could not be read just now.", true);
    for (const id of ["n-testers", "n-welcome", "n-left", "n-not-now"]) $(id).textContent = "—";
    return reply?.status !== 404;
  }
  const t = reply.body;
  members = new Map(t.testers.map((one) => [one.account, one]));
  $("n-testers").textContent = String(t.counts.testers);
  $("n-welcome").textContent = String(t.counts.welcome);
  $("n-left").textContent = String(t.counts.left);
  $("n-not-now").textContent = String(t.counts.not_now);
  $("tab-testers").textContent = t.counts.testers ? String(t.counts.testers) : "";
  say("testers-said", `${TESTS ? "The site's checks' own accounts (?tests=1). " : ""}Newest first, then who left, `
    + `then who said Not now. ${t.counts.application} of the ${t.counts.testers} told us about themselves.`);
  $("testers").replaceChildren(...t.testers.map(testerRow));
  $("testers-empty").hidden = t.testers.length > 0;
  resort($("testers").closest("table"));
  siftTesters();
  return true;
}

$("testers-q").addEventListener("input", siftTesters);
segmented(document.querySelector('[data-filter="testers"]'), (value) => { testersShown = value; siftTesters(); });

// --- The applications -------------------------------------------------------

function row(list, term, ...value) {
  list.append(make("dt", "", term), make("dd", "", ...value));
}

function card(app) {
  const item = make("li", "card app");
  item.dataset.account = app.account;
  item.dataset.status = app.status;
  const pill = make("span", app.status === "approved" ? "pill good" : app.status === "new" ? "pill new" : "pill",
    STATUS[app.status] + (app.spot ? ` · spot ${app.spot}` : ""));
  const name = make("a", "", app.email || app.account);
  name.href = `#people/${app.account}`;
  item.append(make("div", "top", make("h3", "", name), pill));
  const facts = make("dl");
  row(facts, "Applied", when(app.applied_at));
  row(facts, "Would build", app.build);
  row(facts, "Uses", AI[app.ai] || app.ai);
  row(facts, "Background", BACKGROUND[app.background] || app.background, app.background_line ? `: ${app.background_line}` : "");
  if (app.link) {
    const to = make("a", "", app.link);
    to.href = app.link;
    to.rel = "noopener noreferrer nofollow ugc";
    to.target = "_blank";
    row(facts, "Link", to);
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
  // Put on the waitlist by hand (beta_waitlist) rather than by a full pool.
  if (app.status === "waitlist" && app.decided_by) {
    row(facts, "Waitlisted", `by ${app.decided_by}${app.note ? `: ${app.note}` : ""}`);
  }
  item.append(facts);
  if (app.status !== "approved") item.append(decideForm(app));
  item.dataset.find = item.textContent;
  return item;
}

function decideForm(app) {
  const form = make("form");
  const note = make("input");
  note.maxLength = 500;
  note.name = "note";
  const label = make("label", "", "A note, for you ", make("small", "", "optional: kept with the decision"), note);
  const said = make("p", "said");
  said.setAttribute("role", "status");
  const buttons = [];
  const decide = (op, decision) => async () => {
    for (const one of buttons) one.disabled = true;
    said.textContent = { approve: "Approving…", decline: "Declining…", waitlist: "Putting it on the waitlist…" }[decision];
    const reply = await admin({ op, account: app.account }, { method: "POST",
      body: op === "beta_decide" ? { decision, note: note.value } : { note: note.value } }).catch(() => null);
    if (reply?.status === 200) {
      $("said").textContent = decision === "approve"
        ? `${app.email}: approved${reply.body.application?.spot ? `, spot ${reply.body.application.spot}` : ", no spot (early)"}`
          + `${reply.body.month?.said ? `. ${reply.body.month.said}` : ""}; email ${reply.body.mail}.`
        : decision === "decline" ? `${app.email}: declined; email ${reply.body.mail}.`
          : `${app.email}: on the waitlist. No email: they hear when it is decided.`;
      await loadBeta();
      onChange();
      return true;
    }
    said.textContent = reply?.body?.error || "That did not go just now. Try again.";
    if (reply?.status === 409) loadBeta();
    return false;
  };
  const approve = act("Approve", decide("beta_decide", "approve"), "cta small");
  approve.setAttribute("aria-label", `Approve ${app.email}`);
  buttons.push(approve);
  if (app.status === "new") {
    const wait = act("Waitlist", decide("beta_waitlist", "waitlist"), "cta ghost small");
    wait.setAttribute("aria-label", `Waitlist ${app.email}`);
    buttons.push(wait);
  }
  if (app.status !== "declined") {
    const decline = act("Decline", decide("beta_decide", "decline"), "cta ghost small");
    decline.setAttribute("aria-label", `Decline ${app.email}`);
    buttons.push(decline);
  }
  form.append(label, make("div", "actions", ...buttons), said);
  form.addEventListener("submit", (event) => event.preventDefault());
  return form;
}

function siftApps() {
  const words = $("apps-q").value.toLowerCase().split(/\s+/).filter(Boolean);
  let shown = 0;
  for (const item of $("apps").children) {
    const show = words.every((word) => (item.dataset.find || "").toLowerCase().includes(word));
    item.hidden = !show;
    if (show) shown += 1;
  }
  $("empty").hidden = shown > 0;
}

/// The Beta section, read and drawn: its switch, the queue and the testers.
/// Its counts back, for the nav.
export async function loadBeta() {
  const query = { op: "beta", ...(status ? { status } : {}) };
  const [reply, set] = await Promise.all([admin(query), adminJson({ op: "switches" }).catch(() => null), loadTesters()]);
  if (reply.status !== 200) {
    if (reply.status === 404 && reply.body?.error === "not found") throw new Error("This account cannot see this page.");
    drawSwitch(set, null);
    say("months", reply.body?.error || "The applications could not be read just now.", true);
    $("apps").replaceChildren();
    return null;
  }
  const q = reply.body;
  drawSwitch(set, q.pool);
  $("n-given").textContent = `${q.pool.given} of ${q.pool.cap}`;
  $("n-spots-left").textContent = String(q.pool.left);
  $("n-new").textContent = String(q.counts.new);
  $("n-waitlist").textContent = String(q.counts.waitlist);
  $("n-pending").textContent = String(q.counts.pending);
  $("tab-applications").textContent = q.counts.new ? String(q.counts.new) : "";
  say("months", `${TESTS ? "The site's checks' own pool (?tests=1). " : ""}The beta is ${q.beta === "open"
    ? "open" : "off: /beta says it is coming soon"}. Billing is ${q.months.billing}: a month is given ${TESTS ? q.months.test
    : q.months.live}.`);
  $("grant").hidden = q.months.billing === "off";
  $("apps").replaceChildren(...q.applications.map(card));
  siftApps();
  return { new: q.counts.new };
}

segmented(document.querySelector('[data-filter="applications"]'), (value) => { status = value; loadBeta(); });
$("apps-q").addEventListener("input", siftApps);
$("grant").addEventListener("click", async () => {
  $("grant").disabled = true;
  $("said").textContent = "Giving the months still to give…";
  const reply = await admin({ op: "beta_grant" }, { method: "POST" }).catch(() => null);
  $("said").textContent = reply?.status === 200
    ? `Given: ${reply.body.granted}; still to give: ${reply.body.pending}${reply.body.said?.length ? ` (${reply.body.said.join(" ")})` : ""}.`
    : reply?.body?.error || "That did not go just now. Try again.";
  $("grant").disabled = false;
  await loadBeta();
  onChange();
});
