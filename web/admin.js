// The owner's console (admin.html, docs/ADMIN.md): the session in this
// browser (web/account.js), /api/admin asked with it, and each section
// drawn when it is opened. This file is the console itself: its gate, its
// sections and their addresses, the Overview, People with an account's
// panel, and the Audit log. The Gallery is admin-gallery.js, the Beta
// admin-beta.js, Feedback admin-feedback.js.
//
// Everything is put on the page as text, never as markup: the addresses,
// names and words are what people typed.
import { email as signedInAs } from "/account.js";
import { $, TESTS, act, adminJson, ago, cell, count, day, emptyRow, make, post, resort, rowAct, say, segmented, sift, sortable, timeCell,
  when }
  from "/admin-kit.js";
import { keepInView, loadGallery, whenChanged as galleryChanged } from "/admin-gallery.js";
import { loadBeta, whenChanged as betaChanged } from "/admin-beta.js";
import { loadFeedback } from "/admin-feedback.js";
// Its tables scroll as every scroller on the site does; it has no kit.
import "/scroller.js";

const SECTIONS = ["overview", "people", "gallery", "beta", "feedback", "audit"];
const TABS = { gallery: ["reported", "comments", "listed", "pick", "challenges", "tested", "barred"],
  beta: ["applications", "testers"] };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/// Where the address points: {section, tab, account, asked}.
function route() {
  const hash = location.hash.slice(1);
  if (/^report-\d+$/.test(hash)) return { section: "gallery", tab: "reported", asked: hash };
  if (/^comment-\d+$/.test(hash)) return { section: "gallery", tab: "comments", asked: hash };
  if (/^feedback(-\d+)?$/.test(hash)) return { section: "feedback" };
  const [section, rest = ""] = hash.split("/");
  if (section === "people") return { section, account: UUID.test(rest) ? rest.toLowerCase() : null };
  if (TABS[section]) return { section, tab: TABS[section].includes(rest) ? rest : TABS[section][0] };
  return { section: SECTIONS.includes(section) ? section : "overview" };
}

// Each section read once it is first opened, and again on Refresh.
const loaders = {
  overview: () => loadOverview(),
  people: () => loadPeople(),
  gallery: () => loadGallery(),
  beta: () => loadBeta(),
  feedback: () => loadFeedback(),
  audit: () => loadAudit(),
};
const loaded = new Set();

async function show() {
  const at = route();
  for (const part of document.querySelectorAll("[data-section]")) part.hidden = part.dataset.section !== at.section;
  for (const go of document.querySelectorAll("[data-go]")) {
    if (go.dataset.go === at.section) go.setAttribute("aria-current", "true");
    else go.removeAttribute("aria-current");
  }
  const part = document.querySelector(`[data-section="${at.section}"]`);
  if (at.tab) {
    for (const tab of part.querySelectorAll("[data-tab]")) tab.hidden = tab.dataset.tab !== at.tab;
    for (const to of part.querySelectorAll("[data-tab-link]")) {
      if (to.dataset.tabLink === at.tab) to.setAttribute("aria-current", "true");
      else to.removeAttribute("aria-current");
    }
  }
  document.title = `${part.querySelector("h2")?.textContent || "Console"} · Console · Brickworks`;
  if (!loaded.has(at.section)) {
    loaded.add(at.section);
    await loaders[at.section]().catch((problem) => {
      loaded.delete(at.section);
      say("note", problem.message, true);
    });
  }
  if (at.asked && !show.kept) {
    const row = document.getElementById(at.asked);
    if (row) {
      show.kept = true;
      keepInView(row);
    }
  }
  if (at.section === "people") await person(at.account);
}

// ---------------------------------------------------------------------------
// The gate: the overview answers only the owner.

async function start() {
  try {
    await loadOverview();
    loaded.add("overview");
  } catch (problem) {
    $("view").classList.add("hide");
    $("view").hidden = true;
    $("gate").hidden = false;
    say("gate-note", problem.message, true);
    return;
  }
  $("gate").hidden = true;
  $("view").classList.remove("hide");
  $("view").hidden = false;
  $("meta-who").textContent = `Signed in as ${signedInAs() || "the owner"}${TESTS ? " · the checks' own (?tests=1)" : ""}`;
  addEventListener("hashchange", show);
  await show();
  say("note", `Updated ${new Date().toLocaleTimeString()}`);
}

$("again").addEventListener("click", async () => {
  const at = route().section;
  $("again").disabled = true;
  try {
    await Promise.all([loadOverview(), at === "overview" ? null : loaders[at]()]);
    if (at === "people" && route().account) await person(route().account, true);
    say("note", `Updated ${new Date().toLocaleTimeString()}`);
  } catch (problem) {
    say("note", problem.message, true);
  } finally {
    $("again").disabled = false;
  }
});

// After an act elsewhere, the overview's counts again, and the sections
// that show the same things read afresh when next opened.
async function changed(except) {
  for (const one of ["people", "audit", "gallery", "beta"]) if (one !== except) loaded.delete(one);
  await loadOverview().catch(() => null);
}
galleryChanged(() => changed("gallery"));
betaChanged(() => changed("beta"));

// ---------------------------------------------------------------------------
// The Overview.

function badge(id, n) {
  const el = $(id);
  el.hidden = !n;
  el.textContent = n ? String(n) : "";
}

async function loadOverview() {
  const o = await adminJson({ op: "overview" });
  const needs = [];
  const need = (n, words, href, warn = false) => { if (n) needs.push({ n, words, href, warn }); };
  need(o.reports?.open, o.reports?.open === 1 ? "report open" : "reports open", "#gallery/reported", true);
  need(o.beta?.applications?.new, o.beta?.applications?.new === 1 ? "application for a month of Pro" : "applications for a month of Pro",
    "#beta/applications");
  need(o.feedback?.new, o.feedback?.new === 1 ? "feedback report unread" : "feedback reports unread", "#feedback");
  need(o.beta?.applications?.pending, o.beta?.applications?.pending === 1 ? "month of Pro still to give" : "months of Pro still to give",
    "#beta/applications");
  const failed = (o.mail?.beta?.failed || 0) + (o.mail?.answers?.failed || 0);
  // Where each is said: a feedback answer's on its report, a beta mail's on its application.
  need(failed, failed === 1 ? "email that did not go this week" : "emails that did not go this week",
    o.mail?.answers?.failed ? "#feedback" : "#beta/applications", true);
  if (o.switches?.mail?.borrowing) needs.push({ n: "!", words: `Sign-in codes go out as ${o.switches.mail.borrowing}, a borrowed sender`, warn: true });
  $("needs").replaceChildren(...needs.map((one) => {
    const to = make(one.href ? "a" : "div", "", make("b", "", String(one.n)), make("span", "", one.words));
    if (one.href) to.href = one.href;
    return make("li", one.warn ? "warn" : "", to);
  }));
  say("needs-said", needs.length ? "What is waiting on you, each a press from where it is done." : "Nothing needs you now.");
  badge("nav-gallery", o.reports?.open);
  badge("nav-beta", o.beta?.applications?.new);
  badge("nav-feedback", o.feedback?.new);

  const a = o.accounts || {};
  $("n-accounts").textContent = count(a.all);
  say("n-accounts-said", TESTS ? "the checks' own" : "");
  $("n-joined-day").textContent = count(a.joined_day);
  say("n-joined-week", `${count(a.joined_week)} in 7 days`);
  $("n-week").textContent = count(a.signed_in_week);
  const pool = o.beta?.pool;
  $("n-ov-testers").textContent = o.beta?.testers === null || o.beta?.testers === undefined ? "—" : count(o.beta.testers);
  say("n-ov-months", pool ? `${pool.given} of ${pool.cap} months given` : "");
  $("n-published").textContent = count(o.models?.published);
  say("n-published-said", `${count(o.models?.listed)} in the gallery, ${count(o.models?.published_week)} this week`);
  $("n-reports").textContent = count(o.reports?.open);
  $("n-feedback").textContent = o.feedback ? count(o.feedback.new) : "—";
  const sent = o.mail ? (o.mail.beta?.sent || 0) + (o.mail.answers?.sent || 0) : null;
  $("n-mail").textContent = count(sent);
  say("n-mail-said", o.mail ? `${failed} did not go; ${(o.mail.beta?.dry || 0) + (o.mail.answers?.dry || 0)} kept for a test inbox. `
    + "Delivered and bounced: Resend's to say." : "Not counted yet: supabase/console.sql is not applied.");
  say("stands-said", TESTS ? "The site's checks' own accounts, models and mail (?tests=1)." : "");

  drawSwitches(o.switches);
  drawLatest(o.audit);
  return o;
}

let version = null;
async function drawSwitches(set) {
  const facts = $("switches");
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  facts.replaceChildren();
  if (!set) return fact("Switches", "could not be read just now");
  const beta = set.beta;
  const toBeta = make("a", "", beta.mode === "open" ? "open" : "off");
  toBeta.href = "#beta";
  fact("The beta", toBeta, beta.source === "console" ? `, set from the console ${ago(beta.set_at)} by ${beta.set_by}`
    : `, as the project says (BRICKWORKS_BETA)`);
  fact("Billing", `${set.billing?.mode || "—"}: changed only outside the console`);
  fact("Sign-in mail", set.mail?.key ? `sent as ${set.mail.sender}` : "no mail key here: codes and answers are not sent",
    set.mail?.borrowing ? `; borrowing ${set.mail.borrowing}` : "");
  if (set.mail?.reply_to) fact("Answers go to", set.mail.reply_to);
  const services = set.services || {};
  const NAMES = { database: "the database", mail: "mail (Resend)", admission: "plans (Admission)", orangecheck: "orangecheck",
    crons: "the crons" };
  const have = Object.keys(NAMES).filter((one) => services[one]).map((one) => NAMES[one]);
  const lack = Object.keys(NAMES).filter((one) => !services[one]).map((one) => NAMES[one]);
  fact("Keys here", have.length ? have.join(", ") : "none", lack.length ? `; none for ${lack.join(", ")}` : "");
  version ||= await fetch("/version.json", { cache: "no-store" }).then((reply) => (reply.ok ? reply.json() : null)).catch(() => null);
  fact("This site", version ? `commit ${version.commit}, deployed ${when(version.deployed)} (${ago(version.deployed)})` : "—");
  say("meta-build", version ? `Commit ${version.commit}, deployed ${ago(version.deployed)}` : "");
}

// ---------------------------------------------------------------------------
// The audit's words.

const OPS = { unlist: "Took a model out", bar: "Took an account out", unbar: "Let an account back in", dismiss: "Let a report go",
  untest: "Cleared a Tested mark", uncomment: "Removed a comment", remove_photo: "Took a photo out",
  remove_avatar: "Took a profile's picture out", pick: "Made a model the pick", unpick: "Ended a pick",
  challenge: "Set a challenge", end_challenge: "Ended a challenge", plan: "Set a year of themes",
  beta_decide: "Decided an application", beta_waitlist: "Put an application on the waitlist",
  beta_grant: "Gave the months still to give", beta_switch: "Flipped the beta", feedback_triage: "Marked feedback",
  feedback_reply: "Answered feedback" };

function opSaid(row) {
  const asked = row.detail?.asked || {};
  if (row.op === "beta_decide" && asked.decision) return asked.decision === "approve" ? "Approved an application" : "Declined an application";
  if (row.op === "beta_switch" && asked.mode) return asked.mode === "open" ? "Opened the beta" : "Turned the beta off";
  return OPS[row.op] || row.op;
}

/// What an act was on, as a link where it has a place.
function targetOf(row) {
  const t = String(row.target ?? "");
  const to = (href, text) => { const a = make("a", "", text); a.href = href; return a; };
  switch (row.target_kind) {
    case "account": return UUID.test(t) ? to(`#people/${t}`, row.email || t) : row.email || t;
    case "model": return to(`/m/${encodeURIComponent(t)}`, t);
    case "report": return to(`#report-${encodeURIComponent(t)}`, `report ${t}`);
    case "comment": return to(`#comment-${encodeURIComponent(t)}`, `comment ${t}`);
    case "feedback": return to(`#feedback-${encodeURIComponent(t)}`, `feedback #${t}`);
    case "profile": return to(`/u/${encodeURIComponent(t)}`, `@${t}`);
    case "setting": return t === "beta" ? `the beta, on ${row.scope === "live" ? "brickworks.diy" : row.scope}` : t;
    case "challenge": return `challenge ${t}`;
    case "photo": return `photo ${t}`;
    case "pick": return `pick ${t}`;
    default: return t || "—";
  }
}

function outcome(row) {
  const ok = row.status >= 200 && row.status < 300;
  return make("span", ok ? "pill good" : "pill", ok ? "Done" : `Refused, ${row.status}${row.said ? `: ${row.said}` : ""}`);
}

function drawLatest(rows) {
  const list = $("latest");
  list.replaceChildren(...(rows || []).map((row) => {
    const on = targetOf(row);
    return make("li", "", make("span", "", `${opSaid(row)}: `, on), make("small", "", `${when(row.at)} · ${row.actor}`), outcome(row));
  }));
  $("latest-none").hidden = Boolean(rows?.length);
  if (rows === null) say("latest-none", "Not kept yet: supabase/console.sql is not applied.");
}

// ---------------------------------------------------------------------------
// The Audit log.

let auditRows = [];
let auditTimer = 0;

$("audit-act").append(...Object.entries(OPS).map(([op, words]) => new Option(words, op)));
$("audit-act").addEventListener("change", () => loadAudit());
$("audit-q").addEventListener("input", () => {
  clearTimeout(auditTimer);
  auditTimer = setTimeout(() => loadAudit(), 300);
});
$("audit-more").addEventListener("click", () => loadAudit(auditRows.at(-1)?.id));

async function loadAudit(before = null) {
  const query = { op: "audit" };
  if ($("audit-act").value) query.act = $("audit-act").value;
  if ($("audit-q").value.trim()) query.q = $("audit-q").value.trim();
  if (before) query.before = String(before);
  const listed = await adminJson(query);
  const body = $("audit");
  if (!before) {
    body.replaceChildren();
    auditRows = [];
  }
  auditRows.push(...listed.rows);
  for (const row of listed.rows) {
    const tr = make("tr");
    tr.dataset.audit = String(row.id);
    tr.dataset.op = row.op;
    timeCell(tr, row.at);
    cell(tr, opSaid(row));
    cell(tr, targetOf(row), "about");
    cell(tr, outcome(row));
    cell(tr, row.actor);
    const acts = make("td", "acts");
    acts.append(rowAct("Details", async () => { openAct(row); return false; }));
    tr.append(acts);
    body.append(tr);
  }
  $("audit-more").hidden = !listed.more;
  const none = $("audit-none");
  none.hidden = listed.ready !== false && auditRows.length > 0;
  none.textContent = listed.ready === false ? "Not kept yet: supabase/console.sql is not applied."
    : query.act || query.q ? "No act like that." : "Nothing done from the console yet.";
  say("audit-note", auditRows.length ? `${auditRows.length} shown${TESTS ? ", the checks' own" : ""}.` : "");
}

/// An act's panel: everything kept of it.
function openAct(row) {
  const facts = make("dl", "facts");
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  fact("When", when(row.at));
  fact("What", `${opSaid(row)} (${row.op})`);
  fact("On", targetOf(row));
  fact("Outcome", outcome(row));
  fact("By", row.actor);
  fact("Where", row.scope === "live" ? "brickworks.diy" : row.scope || "—");
  if (row.test) fact("A test's", "yes: done on the checks' own");
  for (const [part, words] of [["asked", "Asked"], ["said", "Answered"]]) {
    for (const [name, value] of Object.entries(row.detail?.[part] || {})) fact(`${words}: ${name.replace(/_/g, " ")}`, String(value));
  }
  openSheet(`Act ${row.id}`, facts);
}

// ---------------------------------------------------------------------------
// People.

let peopleShown = "";

function siftPeople() {
  const keep = {
    "": () => true,
    tester: (row) => row.dataset.beta === "tester",
    models: (row) => Number(row.dataset.models) > 0,
    connector: (row) => Number(row.dataset.connectors) > 0,
    barred: (row) => row.dataset.barred === "yes",
  }[peopleShown];
  const n = sift($("people"), $("people-q").value, keep);
  say("people-note", `${n} of ${$("people").rows.length} shown.`);
}
$("people-q").addEventListener("input", siftPeople);
segmented(document.querySelector('[data-filter="people"]'), (value) => { peopleShown = value; siftPeople(); });

const BETA = { tester: "Tester", left: "Left", not_now: "Not now" };

async function loadPeople() {
  const listed = await adminJson({ op: "people" });
  const body = $("people");
  body.replaceChildren();
  for (const one of listed.people) {
    const row = make("tr");
    row.dataset.account = one.id;
    row.dataset.beta = one.beta?.state || "";
    row.dataset.models = String(one.models);
    row.dataset.connectors = String(one.connectors);
    row.dataset.barred = one.barred ? "yes" : "no";
    row.dataset.find = [one.email, one.handle, one.name].filter(Boolean).join(" ");
    const who = make("th");
    who.scope = "row";
    const to = make("a", "", one.email || "no address");
    to.href = `#people/${one.id}`;
    who.append(to);
    if (one.owner) who.append(" ", make("span", "badge accent", "You"));
    if (one.barred) who.append(" ", make("span", "badge", "Taken out"));
    if (one.handle) who.append(make("br"), make("small", "faint", `@${one.handle}${one.name ? ` · ${one.name}` : ""}`));
    who.dataset.value = one.email || "";
    row.append(who);
    cell(row, day(one.joined)).dataset.value = one.joined || "";
    const seen = cell(row, one.last_sign_in ? ago(one.last_sign_in) : "never", one.last_sign_in ? "" : "faint");
    seen.dataset.value = one.last_sign_in || "";
    if (one.last_sign_in) seen.title = when(one.last_sign_in);
    cell(row, make("span", "", one.plan?.name || "—", one.plan?.said ? make("small", "faint", ` · ${one.plan.said}`) : ""));
    const app = one.beta?.application;
    cell(row, one.beta ? `${BETA[one.beta.state] || one.beta.state}${app ? `; month ${app.status}` : ""}` : "—", one.beta ? "" : "faint");
    const models = cell(row, one.models ? `${one.models}${one.listed ? ` (${one.listed} listed)` : ""}` : "—", one.models ? "n" : "n faint");
    models.dataset.value = String(one.models);
    const tabs = cell(row, one.connectors ? String(one.connectors) : "—", one.connectors ? "n" : "n faint");
    tabs.dataset.value = String(one.connectors);
    if (one.connector_seen) tabs.title = `last heard ${when(one.connector_seen)}`;
    body.append(row);
  }
  if (!listed.people.length) emptyRow(body, "Nobody yet.");
  resort(body.closest("table"));
  siftPeople();
  say("people-said", `${TESTS ? "The site's checks' own accounts (?tests=1). " : ""}Everyone with an account, newest sign-in `
    + `first. Open one for all of it.${listed.beta_known ? "" : " The beta's states are not known here yet."}`);
}

/// An account whole, in the panel: when the address names one. [told]:
/// what the act that drew it again came to.
async function person(account, again = false, told = "") {
  if (!account) {
    if ($("sheet").open && $("sheet").dataset.kind === "person") $("sheet").close();
    return;
  }
  if (!again && $("sheet").open && $("sheet").dataset.account === account) return;
  openSheet("Looking…", make("p", "note", "Reading the account…"), { kind: "person", account });
  let one;
  try {
    one = await adminJson({ op: "person", account });
  } catch (problem) {
    return openSheet("No such account", make("p", "note bad", problem.message), { kind: "person", account });
  }
  const parts = [];
  const facts = make("dl", "facts");
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  fact("Joined", when(one.joined));
  fact("Last signed in", one.last_sign_in ? `${when(one.last_sign_in)} (${ago(one.last_sign_in)})` : "never");
  fact("Signs in with", `${one.signs_in_with || "—"}${one.confirmed ? "" : ", address not confirmed"}`);
  if (one.profile?.handle) {
    const to = make("a", "", `@${one.profile.handle}`);
    to.href = `/u/${encodeURIComponent(one.profile.handle)}`;
    fact("Profile", to, one.profile.name ? ` · ${one.profile.name}` : "");
  } else {
    fact("Profile", "none");
  }
  const plan = one.plan || {};
  fact("Plan", plan.name ? `${plan.name}${plan.said ? ` (${plan.said})` : ""}`
    : `${plan.plan || plan.standing || "—"}${plan.subscription?.status ? `, ${plan.subscription.status}` : ""}`, ` · billing ${one.billing}`);
  const b = one.beta;
  fact("Beta", b ? `${BETA[b.state] || b.state || "—"}${b.joined_at ? ` since ${day(b.joined_at)}` : ""}${b.application
    ? `; month ${b.application.status}${b.application.spot ? `, spot ${b.application.spot}` : ""}` : ""}` : "—");
  fact("Connectors", one.connectors.length ? `${one.connectors.length}, last heard ${ago(one.connectors.map((c) => c.seen_at).sort().at(-1))}` : "none");
  if (one.barred) fact("Taken out", `${when(one.barred.at)}${one.barred.reason ? `: ${one.barred.reason}` : ""}`);
  if (one.test) fact("A test's", "an account of the site's checks (resend.dev)");
  parts.push(facts);

  // Take out the account, or let it back in.
  const doing = make("div", "part");
  const said = make("p", "note", told);
  said.setAttribute("role", "status");
  if (!one.owner) {
    if (one.barred) {
      doing.append(make("div", "row", act("Let back in", () => post({ op: "unbar", account }, said, "Let back in.",
        { after: () => afterPerson(account, "Let back in: they can list again.") }))));
    } else {
      const reason = make("input");
      reason.name = "reason";
      reason.maxLength = 200;
      const form = make("form", "console-form", make("label", "", "Why ", make("small", "", "for you; kept with it"), reason));
      form.append(make("div", "row", act("Take out the account", () => (confirm(`Take every model of ${one.email} out of the gallery, `
        + "and keep them out? Their profile and public collections go too.")
        ? post({ op: "bar", account }, said, "The account is out.", { body: { reason: reason.value },
          after: () => afterPerson(account, "The account is out: none of its models is listed.") })
        : Promise.resolve(false)), "cta ghost small")));
      form.addEventListener("submit", (event) => event.preventDefault());
      doing.append(form);
    }
    doing.append(said);
    parts.push(doing);
  }

  // Their models.
  const models = make("div", "part", make("h3", "", `Models (${one.models.length})`));
  if (one.models.length) {
    models.append(make("ul", "models-of", ...one.models.map((m) => {
      const to = make("a", "", m.name || m.id);
      to.href = `/m/${encodeURIComponent(m.id)}`;
      const state = m.barred ? "taken out" : m.listed ? "in the gallery" : m.published ? "published" : "not published";
      return make("li", "", to, make("small", "faint", `${Number(m.parts).toLocaleString()} parts · ${state} · ${day(m.created_at)}`));
    })));
  } else {
    models.append(make("p", "note", "None shared."));
  }
  parts.push(models);

  if (one.feedback.length) {
    parts.push(make("div", "part", make("h3", "", `Feedback (${one.feedback.length})`), make("ul", "models-of",
      ...one.feedback.map((f) => {
        const to = make("a", "", `#${f.id} ${f.kind}`);
        to.href = `#feedback-${f.id}`;
        return make("li", "", to, make("small", "faint", `${f.status} · ${day(f.at)} · ${f.words}`));
      }))));
  }

  const acts = make("div", "part", make("h3", "", "Acts on this account"));
  if (one.audit?.length) {
    acts.append(make("ul", "acts-list", ...one.audit.map((row) => make("li", "", make("span", "", opSaid(row)),
      make("small", "", `${when(row.at)} · ${row.actor}`), outcome(row)))));
  } else {
    acts.append(make("p", "note", one.audit === null ? "Not kept yet: supabase/console.sql is not applied." : "None yet."));
  }
  parts.push(acts);
  openSheet(one.email || "no address", parts, { kind: "person", account });
}

/// After an act on an account: the list, the counts and its panel again,
/// saying what came of it.
async function afterPerson(account, told) {
  loaded.delete("gallery");
  loaded.delete("audit");
  await Promise.all([loadPeople(), loadOverview()]);
  await person(account, true, told);
}

// ---------------------------------------------------------------------------
// The panel (dialog.sheet): an account or an act, over the list it is in.

function openSheet(title, body, { kind = "act", account = "" } = {}) {
  const sheet = $("sheet");
  $("sheet-title").textContent = title;
  $("sheet-body").replaceChildren(...[body].flat());
  sheet.dataset.kind = kind;
  sheet.dataset.account = account;
  if (!sheet.open) sheet.showModal();
}

$("sheet-close").addEventListener("click", () => $("sheet").close());
$("sheet").addEventListener("click", (event) => { if (event.target === $("sheet")) $("sheet").close(); });
$("sheet").addEventListener("close", () => {
  // Closed, an account's address goes back to the list's.
  if ($("sheet").dataset.kind === "person" && route().account) history.replaceState(null, "", `${location.pathname}${location.search}#people`);
  $("sheet").dataset.account = "";
});

for (const table of document.querySelectorAll("table[data-sortable]")) sortable(table);
start();
