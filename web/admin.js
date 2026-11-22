// The owner's console (admin.html, docs/ADMIN.md): the session in this
// browser (web/account.js), /api/admin asked with it, and each section
// drawn when it is opened. This file is the console itself: its gate, its
// sections and their addresses, the Overview, People with an account's
// panel, and the Audit log. The Gallery is admin-gallery.js, the Beta
// admin-beta.js, Feedback admin-feedback.js; part B (console2) Plans
// admin-plans.js, Mail admin-mail.js, Connector admin-connector.js (and an
// account's panel at #connector/<account>), Site admin-site.js; part C
// (console3) Moderation admin-moderation.js, Challenges admin-challenges.js
// (and one challenge's panel at #challenges/<id>), Data admin-data.js,
// Switches admin-switches.js, and here an account's Export, Sign out
// everywhere and Delete, and the bar's Find. Claude, its Settings and the
// panel beside every section, is admin-claude.js (adminclaude).
// Notifications (ownernotify) is admin-notify.js, and a mail's one-click
// "turn this off" lands here before the gate. Announcements is
// admin-announce.js, asked only once its section is opened.
//
// Everything is put on the page as text, never as markup: the addresses,
// names and words are what people typed.
import { askToSignIn, email as signedInAs, signedIn } from "/account.js";
import { $, TESTS, act, adminJson, ago, cell, count, day, emptyRow, make, post, resort, rowAct, say, segmented, sift, sortable, timeCell,
  when }
  from "/admin-kit.js";
import { keepInView, loadReport, whenChanged as galleryChanged } from "/admin-gallery.js";
import "/admin-moderation.js";
import { challengeOf } from "/admin-challenges.js";
import { loadData } from "/admin-data.js";
import { TABS as ANALYTICS_TABS, loadAnalytics } from "/admin-analytics.js";
import { loadSwitches, whenChanged as switchesChanged } from "/admin-switches.js";
import { loadBeta, whenChanged as betaChanged } from "/admin-beta.js";
import { loadFeedback } from "/admin-feedback.js";
import { loadPlans } from "/admin-plans.js";
import { loadMail } from "/admin-mail.js";
import { connectorOf, loadConnector } from "/admin-connector.js";
import { loadSite, releaseOf, versionOf } from "/admin-site.js";
import { loadSocial, whenChanged as socialChanged } from "/admin-social.js";
import { loadClaude, startClaude } from "/admin-claude.js";
import { loadNotify, offFromLink, whenChanged as notifyChanged } from "/admin-notify.js";
// Its tables scroll as every scroller on the site does; it has no kit.
import "/scroller.js";

const SECTIONS = ["overview", "analytics", "people", "moderation", "talk", "gallery", "challenges", "beta", "feedback", "social", "announcements",
  "plans", "mail", "notifications", "connector", "site", "data", "switches", "claude", "audit"];
const TABS = { moderation: ["queue", "comments", "barred"], talk: ["reports", "threads", "bans"], gallery: ["listed", "pick", "tested"], beta: ["applications", "testers"],
  social: ["inbox", "write", "sent", "accounts"], analytics: ANALYTICS_TABS, notifications: ["settings", "sent"],
  announcements: ["write", "sent", "banner", "settings"] };
// The sections drawn from the one report (admin-gallery.js loadReport).
const REPORTED = ["moderation", "gallery", "challenges"];
// Where the Gallery's tabs went (console3): their old addresses still land.
const MOVED = { "gallery/reported": "moderation/queue", "gallery/comments": "moderation/comments", "gallery/barred": "moderation/barred",
  "gallery/challenges": "challenges" };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/// Where the address points: {section, tab, account, asked}.
function route() {
  let hash = location.hash.slice(1);
  if (MOVED[hash]) {
    hash = MOVED[hash];
    history.replaceState(null, "", `${location.pathname}${location.search}#${hash}`);
  }
  if (/^report-\d+$/.test(hash)) return { section: "moderation", tab: "queue", asked: hash };
  if (/^comment-\d+$/.test(hash)) return { section: "moderation", tab: "comments", asked: hash };
  if (/^feedback(-\d+)?$/.test(hash)) return { section: "feedback" };
  const [section, rest = ""] = hash.split("/");
  if (section === "people" || section === "connector") return { section, account: UUID.test(rest) ? rest.toLowerCase() : null };
  if (section === "challenges") return { section, challenge: /^\d{1,12}$/.test(rest) ? Number(rest) : null };
  if (TABS[section]) return { section, tab: TABS[section].includes(rest) ? rest : TABS[section][0] };
  return { section: SECTIONS.includes(section) ? section : "overview" };
}

// Each section read once it is first opened, and again on Refresh.
const loaders = {
  overview: () => loadOverview(),
  analytics: () => loadAnalytics(),
  people: () => loadPeople(),
  moderation: () => loadReport(),
  talk: () => import("/admin-talk.js").then((part) => part.loadTalk()),
  gallery: () => loadReport(),
  challenges: () => loadReport(),
  beta: () => loadBeta(),
  feedback: () => loadFeedback(),
  social: () => loadSocial(),
  announcements: () => import("/admin-announce.js").then((part) => part.loadAnnouncements()),
  plans: () => loadPlans(),
  mail: () => loadMail(),
  notifications: () => loadNotify(),
  connector: () => loadConnector(),
  site: () => loadSite(),
  data: () => loadData(),
  switches: () => loadSwitches(),
  claude: () => loadClaude(),
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
      if (to.dataset.tabLink !== at.tab) to.removeAttribute("aria-current");
      else {
        to.setAttribute("aria-current", "true");
        // Tabs wider than the window (a phone's) scroll sideways: the current one into sight (inreview L7).
        const [tab, strip] = [to.getBoundingClientRect(), to.parentElement.getBoundingClientRect()];
        if (tab.left < strip.left || tab.right > strip.right) to.parentElement.scrollLeft += tab.left - strip.left - (strip.width - tab.width) / 2;
      }
    }
  }
  document.title = `${part.querySelector("h2")?.textContent || "Console"} · Console · Brickworks`;
  let went = true;
  if (!loaded.has(at.section)) {
    // One read draws Moderation, the Gallery and Challenges together.
    const together = REPORTED.includes(at.section) ? REPORTED : [at.section];
    for (const one of together) loaded.add(one);
    went = await loaders[at.section]().then(() => true, (problem) => {
      for (const one of together) loaded.delete(one);
      say("note", problem.message, true);
      return problem;
    });
    failedIn(part, went === true ? "" : went.message);
  }
  if (at.asked && !show.kept) {
    const row = document.getElementById(at.asked);
    if (row) {
      show.kept = true;
      keepInView(row);
    }
  }
  if (at.section === "people") await person(at.account);
  if (at.section === "connector") await connectorPanel(at.account);
  if (at.section === "challenges") await challengePanel(at.challenge);
  return went === true;
}

/// A section whose read failed says so in its own place, under its title:
/// it drew nothing else, and the header's note is soon "Updated" again
/// (rel-m298: Connector read nothing on the design check, said nowhere).
function failedIn(part, words) {
  let line = part.querySelector(":scope > p[data-failed]");
  if (!words) return line?.remove();
  if (!line) {
    line = make("p", "note bad");
    line.dataset.failed = "";
    line.setAttribute("role", "alert");
    (part.querySelector(":scope > .lead") || part.firstElementChild).after(line);
  }
  line.textContent = `This section could not be read: ${words}`;
}

// ---------------------------------------------------------------------------
// The gate: the overview answers only the owner.

// Shut: the gate shown, with Sign in in the bar while nobody is.
function gate(words, bad = true) {
  $("view").classList.add("hide");
  $("view").hidden = true;
  $("gate").hidden = false;
  say("gate-note", words, bad);
  $("sign-in").hidden = signedIn();
  $("again").hidden = !signedIn();
  $("meta-who").textContent = "Owner console";
}

async function start() {
  // A mail's one-click "turn this off": done first, whoever is signed in.
  const off = await offFromLink();
  try {
    await loadOverview();
    loaded.add("overview");
  } catch (problem) {
    // A link that turned its kind off is said as done, not as a fault.
    gate(off ? `${off.words}${off.ok ? " Sign in with the owner's account to change the rest." : ""}` : problem.message, !off?.ok);
    return;
  }
  $("gate").hidden = true;
  $("sign-in").hidden = true;
  $("again").hidden = false;
  $("view").classList.remove("hide");
  $("view").hidden = false;
  $("find").hidden = false;
  $("meta-who").textContent = `Signed in as ${signedInAs() || "the owner"}${TESTS ? " · the checks' own (?tests=1)" : ""}`;
  addEventListener("hashchange", show);
  startClaude(route().section);
  if (await show()) say("note", `Updated ${new Date().toLocaleTimeString()}`);
  if (off) say("notify-acted", off.words, !off.ok);
}

$("again").addEventListener("click", async () => {
  const at = route().section;
  $("again").disabled = true;
  try {
    const part = document.querySelector(`[data-section="${at}"]`);
    await Promise.all([loadOverview(), at === "overview" ? null : loaders[at]().then(() => failedIn(part, ""), (problem) => {
      failedIn(part, problem.message);
      throw problem;
    })]);
    if (at === "people" && route().account) await person(route().account, true);
    if (at === "connector" && route().account) await connectorPanel(route().account, true);
    if (at === "challenges" && route().challenge) await challengePanel(route().challenge, true);
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
  for (const one of ["people", "audit", "beta", "switches", ...(except === "gallery" ? [] : REPORTED)]) if (one !== except) loaded.delete(one);
  await loadOverview().catch(() => null);
}
galleryChanged(() => changed("gallery"));
betaChanged(() => changed("beta"));
switchesChanged(() => changed("switches"));
socialChanged(() => changed("social"));
notifyChanged(() => loaded.delete("audit"));

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
  need(o.reports?.open, o.reports?.open === 1 ? "report open" : "reports open", "#moderation/queue", true);
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
  // The backend first: when Supabase refuses, nothing else here is right.
  const health = o.site?.health;
  if (health && !health.ok) needs.unshift({ n: "!", words: health.fix, href: "#site", warn: true });
  for (const cron of o.site?.crons || []) {
    needs.push({ n: "!", words: `${cron.path} ${cron.state === "late" ? "has not run when it should have" : "failed"}`
      + `${cron.at ? `, last ${ago(cron.at)}` : ""}`, href: "#site", warn: true });
  }
  const trouble = (o.delivery?.bounced || 0) + (o.delivery?.complained || 0);
  need(trouble, trouble === 1 ? "email bounced or marked as spam this week" : "emails bounced or marked as spam this week", "#mail", true);
  // Part C (console3): what the OMR's look found, a challenge to set, the notice showing.
  need(o.library?.found, o.library?.found === 1 ? "model found at LDraw's repository, to look at" : "models found at LDraw's repository, to look at",
    "#data");
  const ch = o.challenges;
  if (ch && !ch.open && !ch.upcoming) {
    needs.push({ n: "!", words: TESTS ? "None of the checks' own challenges is running or set to come"
      : "No challenge is running or set to come", href: "#challenges" });
  }
  else if (ch && ch.through && Date.parse(`${ch.through}T00:00:00Z`) - Date.now() < 7 * 86400000) {
    needs.push({ n: "!", words: `The last challenge set ends ${day(`${ch.through}T00:00:00Z`)}: set the next`, href: "#challenges" });
  }
  // The social desk (socialdesk): what came in unread, and what waits on your press at the network.
  const social = o.social;
  need(social?.due, social?.due === 1 ? "post waiting on you at Reddit" : "posts waiting on you at Reddit", "#social/sent", true);
  need(social?.failed, social?.failed === 1 ? "social post that did not go" : "social posts that did not go", "#social/sent", true);
  need(social?.unread, social?.unread === 1 ? "reply, mention or message unread" : "replies, mentions and messages unread", "#social/inbox");
  if (o.notice) needs.push({ n: "!", words: `A notice is on every page, since ${ago(o.notice.set_at)}: “${String(o.notice.words?.en || "").slice(0, 80)}”`,
    href: "#switches" });
  $("needs").replaceChildren(...needs.map((one) => {
    const to = make(one.href ? "a" : "div", "", make("b", "", String(one.n)), make("span", "", one.words));
    if (one.href) to.href = one.href;
    return make("li", one.warn ? "warn" : "", to);
  }));
  say("needs-said", needs.length ? "What is waiting on you, each a press from where it is done." : "Nothing needs you now.");
  badge("nav-moderation", o.reports?.open);
  badge("nav-data", o.library?.found);
  badge("nav-beta", o.beta?.applications?.new);
  badge("nav-feedback", o.feedback?.new);
  badge("nav-social", (social?.unread || 0) + (social?.due || 0) + (social?.failed || 0));
  badge("nav-mail", trouble);
  badge("nav-site", (health && !health.ok ? 1 : 0) + (o.site?.crons?.length || 0));

  const a = o.accounts || {};
  $("n-accounts").textContent = count(a.all);
  say("n-accounts-said", o.accounts === null ? "could not be read just now" : TESTS ? "the checks' own" : "");
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
  const d = o.delivery;
  say("n-mail-said", o.mail ? `${failed} did not go; ${(o.mail.beta?.dry || 0) + (o.mail.answers?.dry || 0)} kept for a test inbox. `
    + (d?.heard ? `Resend: ${count(d.delivered)} delivered, ${count(d.bounced)} bounced this week.` : "Delivered and bounced: in Mail, once Resend's webhook reaches here.")
    : "Not counted yet: supabase/console.sql is not applied.");
  drawRelease(o.site);
  say("stands-said", TESTS ? "The site's checks' own accounts, models and mail (?tests=1)." : "");

  drawSwitches(o.switches);
  drawLatest(o.audit);
  return o;
}

/// The live release, in the Overview's numbers: the latest written down,
/// and whether this deployment is it.
async function drawRelease(site) {
  const live = site?.live || null;
  const v = await versionOf();
  $("n-release").textContent = live ? live.tag : "—";
  const mine = live && releaseOf([live], v?.commit);
  say("n-release-said", live ? `since ${when(live.live_at)}${mine ? "" : v ? `; this is commit ${v.commit}` : ""}`
    : site?.kept === false ? "not kept yet: supabase/console2.sql" : "none written down yet");
}

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
  const NAMES = { database: "the database", mail: "mail (Resend)", mail_events: "Resend's webhook", admission: "plans (Admission)",
    admission_read: "Admission's read token", orangecheck: "orangecheck", crons: "the crons" };
  const have = Object.keys(NAMES).filter((one) => services[one]).map((one) => NAMES[one]);
  const lack = Object.keys(NAMES).filter((one) => !services[one]).map((one) => NAMES[one]);
  fact("Keys here", have.length ? have.join(", ") : "none", lack.length ? `; none for ${lack.join(", ")}` : "");
  const version = await versionOf();
  fact("This site", version ? `commit ${version.commit}, deployed ${when(version.deployed)} (${ago(version.deployed)})` : "—");
  say("meta-build", version ? `Commit ${version.commit}, deployed ${ago(version.deployed)}` : "");
}

// ---------------------------------------------------------------------------
// The audit's words.

const OPS = { unlist: "Took a model out", bar: "Took an account out", unbar: "Let an account back in", dismiss: "Let a report go",
  untest: "Cleared a Tested mark", uncomment: "Removed a comment", remove_photo: "Took a photo out", talk_act: "Moderated Talk",
  remove_avatar: "Took a profile's picture out", pick: "Made a model the pick", unpick: "Ended a pick",
  challenge: "Set a challenge", end_challenge: "Ended a challenge", plan: "Set a year of themes",
  beta_decide: "Decided an application", beta_waitlist: "Put an application on the waitlist",
  beta_grant: "Gave the months still to give", beta_switch: "Flipped the beta", feedback_triage: "Marked feedback",
  feedback_reply: "Answered feedback", unbar_model: "Let a model back", notice_set: "Set the site's notice",
  notice_clear: "Cleared the site's notice", phone_rules: "Set the numbers a phone is warned by",
  phone_engine: "Set which engine iPhones and iPads start", run_cron: "Ran a cron now", export: "Exported an account's data",
  delete_account: "Deleted an account", sign_out: "Signed an account out everywhere",
  social_connect: "Started connecting a network", social_connected: "Connected a network", social_disconnect: "Disconnected a network",
  social_sync: "Looked at the networks now", social_mark: "Marked what came in", social_draft: "Kept a social draft",
  social_drop: "Threw a social draft away", social_send: "Pressed Send on a social post", social_unschedule: "Unscheduled a social post",
  social_posted: "Marked a social post posted by hand", social_notes: "Kept notes on a community's rules",
  notify_set: "Changed the notifications", notify_address: "Asked for another notifications address",
  notify_confirm: "Confirmed a notifications address", notify_test: "Sent a test notification", notify_flush: "Checked notifications now",
  notify_sent: "Mailed you a notification", notify_folded: "Mailed you several notifications in one",
  notify_held: "Held notifications", notify_failed: "Could not mail a notification", notify_off: "Turned a notification off by its link" };

function opSaid(row) {
  const asked = row.detail?.asked || {};
  if (row.op === "beta_decide" && asked.decision) return asked.decision === "approve" ? "Approved an application" : "Declined an application";
  if (row.op === "beta_switch" && asked.mode) return asked.mode === "open" ? "Opened the beta" : "Turned the beta off";
  if (row.op === "phone_engine" && asked.on) return asked.on === "true" ? "Gave iPhones and iPads the engine without threads"
    : "Gave iPhones and iPads the threaded engine";
  return OPS[row.op] || row.op;
}

/// What an act was on, as a link where it has a place.
function targetOf(row) {
  const t = String(row.target ?? "");
  const to = (href, text) => { const a = make("a", "", text); a.href = href; return a; };
  switch (row.target_kind) {
    // A deleted account's address is only in what its act kept (detail.said.email).
    case "account": return UUID.test(t) && row.email ? to(`#people/${t}`, row.email) : row.detail?.said?.email || row.email || t;
    case "model": return to(`/m/${encodeURIComponent(t)}`, t);
    case "report": return to(`#report-${encodeURIComponent(t)}`, `report ${t}`);
    case "comment": return to(`#comment-${encodeURIComponent(t)}`, `comment ${t}`);
    case "feedback": return to(`#feedback-${encodeURIComponent(t)}`, `feedback #${t}`);
    case "profile": return to(`/u/${encodeURIComponent(t)}`, `@${t}`);
    case "setting": return t === "beta" || t === "notice" ? `the ${t === "beta" ? "beta" : "notice"}, on ${row.scope === "live"
      ? "brickworks.diy" : row.scope}` : t;
    case "cron": return to("#site", `the cron ${t}`);
    case "challenge": return `challenge ${t}`;
    case "photo": return `photo ${t}`;
    case "talk_thread": return to(`/talk/t/${encodeURIComponent(t)}`, `thread ${t}`);
    case "talk_post": return to("#talk/reports", `Talk post ${t}`);
    case "pick": return `pick ${t}`;
    case "social": return to("#social/accounts", t === "reddit" ? "Reddit" : t || "the networks");
    case "send": return to("#social/sent", `social post ${t}`);
    case "notification": return to("#notifications/sent", t || "notifications");
    default: return t || "—";
  }
}

/// How an act came out, in a pill; a refusal's words go beside it
/// (refusal), where they wrap: in the pill, which never wraps, a long one
/// pushed a phone's page sideways (console2, 2026-11-13).
function outcome(row) {
  const ok = row.status >= 200 && row.status < 300;
  const pill = make("span", ok ? "pill good" : "pill", ok ? "Done" : `Refused, ${row.status}`);
  if (!ok && row.said) pill.title = row.said;
  return pill;
}
const refusal = (row) => ((row.status >= 200 && row.status < 300) || !row.said ? "" : make("small", "why faint", row.said));

function drawLatest(rows) {
  const list = $("latest");
  list.replaceChildren(...(rows || []).map((row) => {
    const on = targetOf(row);
    return make("li", "", make("span", "", `${opSaid(row)}: `, on), make("small", "", `${when(row.at)} · ${row.actor}`), outcome(row),
      refusal(row));
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
    const why = refusal(row);
    cell(tr, why ? make("span", "", outcome(row), make("br"), why) : outcome(row));
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
  fact("Outcome", outcome(row), row.said && !(row.status >= 200 && row.status < 300) ? ` ${row.said}` : "");
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
    cell(row, day(one.joined), "line").dataset.value = one.joined || "";
    const seen = cell(row, one.last_sign_in ? ago(one.last_sign_in) : "never", one.last_sign_in ? "line" : "line faint");
    seen.dataset.value = one.last_sign_in || "";
    if (one.last_sign_in) seen.title = when(one.last_sign_in);
    cell(row, make("span", "", one.plan?.name || "—", one.plan?.said ? make("small", "faint", ` · ${one.plan.said}`) : ""));
    const app = one.beta?.application;
    cell(row, one.beta ? `${BETA[one.beta.state] || one.beta.state}${app ? `; month ${app.status}` : ""}` : "—", one.beta ? "" : "faint");
    const models = cell(row, one.models ? `${one.models}${one.listed ? ` (${one.listed} listed)` : ""}` : "—", one.models ? "n line" : "n faint");
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
  // Already open on this account's own panel; its connector's is another.
  if (!again && $("sheet").open && $("sheet").dataset.kind === "person" && $("sheet").dataset.account === account) return;
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
  const toConnector = make("a", "", one.connectors.length || one.claudes?.length ? "its sessions" : "none");
  toConnector.href = `#connector/${account}`;
  fact("Connector", one.connectors.length ? `${one.connectors.length} ${one.connectors.length === 1 ? "tab" : "tabs"}, last heard `
    + `${ago(one.connectors.map((c) => c.seen_at).sort().at(-1))}; ` : "", one.claudes?.length ? `${one.claudes.length} `
    + `${one.claudes.length === 1 ? "Claude" : "Claudes"} let in; ` : "", toConnector);
  if (one.barred) fact("Taken out", `${when(one.barred.at)}${one.barred.reason ? `: ${one.barred.reason}` : ""}`);
  // How many people blocked it (supabase/block.sql), never who: read only.
  if (Number.isInteger(one.blocked_by)) {
    fact("Blocked by", one.blocked_by === 0 ? "nobody" : one.blocked_by === 1 ? "1 person" : `${one.blocked_by} people`);
  }
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
      return make("li", "", to, make("small", "faint", `${Number(m.parts).toLocaleString()} ${Number(m.parts) === 1 ? "part" : "parts"} · ${state}`
        + ` · ${day(m.created_at)}`));
    })));
  } else {
    models.append(make("p", "note", "None shared."));
  }
  parts.push(models);

  // Their lists, comments, photos and challenge entries (console3).
  const listed = (title, list, line, none) => {
    if (list === null || list === undefined) return;
    const box = make("div", "part", make("h3", "", `${title} (${list.length})`));
    box.append(list.length ? make("ul", "models-of", ...list.map(line)) : make("p", "note", none));
    parts.push(box);
  };
  const linkTo = (href, text) => { const a = make("a", "", text); a.href = href; return a; };
  listed("Lists", one.lists, (l) => make("li", "", linkTo(`/c/${encodeURIComponent(l.id)}`, l.name || l.id),
    make("small", "faint", `${l.public ? "public" : "private"} · ${day(l.updated_at)}`)), "None.");
  listed("Comments", one.comments, (c) => make("li", "", linkTo(`/m/${encodeURIComponent(c.model)}#comment-${c.id}`, c.body),
    make("small", "faint", `${c.state} · ${day(c.at)}`)), "None.");
  listed("Photos of builds", one.photos, (f) => make("li", "", linkTo(`/m/${encodeURIComponent(f.model)}#photo-${encodeURIComponent(f.id)}`,
    f.words || `a photo of ${f.model}`), make("small", "faint", `${f.state} · ${day(f.at)}`)), "None.");
  listed("Challenge entries", one.entries, (e) => make("li", "", linkTo(`#challenges/${e.challenge}`, e.title || `challenge ${e.challenge}`),
    make("small", "faint", `${e.name || e.model} · ${e.way === "hand" ? "by hand" : "with the assistant"} · ${day(e.at)}`)), "None.");

  if (one.feedback.length) {
    parts.push(make("div", "part", make("h3", "", `Feedback (${one.feedback.length})`), make("ul", "models-of",
      ...one.feedback.map((f) => {
        const to = make("a", "", `#${f.id} ${f.kind}`);
        to.href = `#feedback-${f.id}`;
        return make("li", "", to, make("small", "faint", `${f.status} · ${day(f.at)} · ${f.words}`));
      }))));
  }

  parts.push(dataActs(one, account));

  const acts = make("div", "part", make("h3", "", "Acts on this account"));
  if (one.audit?.length) {
    acts.append(make("ul", "acts-list", ...one.audit.map((row) => make("li", "", make("span", "", opSaid(row)),
      make("small", "", `${when(row.at)} · ${row.actor}`), outcome(row), refusal(row)))));
  } else {
    acts.append(make("p", "note", one.audit === null ? "Not kept yet: supabase/console.sql is not applied." : "None yet."));
  }
  parts.push(acts);
  openSheet(one.email || "no address", parts, { kind: "person", account });
}

/// What is done with an account's data at its person's request (console3):
/// Export (a JSON file of every row of it), Sign out everywhere, and Delete,
/// behind its address typed again; each kept in the audit.
function dataActs(one, account) {
  const box = make("div", "part", make("h3", "", "At their request"));
  const said = make("p", "note");
  said.setAttribute("role", "status");
  const row = make("div", "acts-row");
  row.append(act("Export their data", async () => {
    say(said, "Gathering every row of the account…");
    try {
      const data = await adminJson({ op: "export", account }, { method: "POST" });
      const file = new Blob([`${JSON.stringify(data, null, 2)}\n`], { type: "application/json" });
      const link = make("a");
      link.href = URL.createObjectURL(file);
      link.download = `brickworks-${String(one.email || account).replace(/[^A-Za-z0-9._-]+/g, "_")}-${new Date().toISOString().slice(0, 10)}.json`;
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(link.href), 60000);
      const more = Object.entries(data.more || {});
      say(said, `Exported ${data.rows} rows from ${Object.keys(data.tables || {}).length} tables, as ${link.download}.${more.length
        ? ` Over a thousand in ${more.map(([name, n]) => `${name} (${n})`).join(", ")}: the newest thousand of each.` : ""}`
        + " It holds your own private notes on them too, where there are any (feedback.note, beta_applications.note and "
        + "signals, beta_decisions.note): read it before you send it on.");
      loaded.delete("audit");
      return false;
    } catch (problem) {
      say(said, problem.message, true);
      return false;
    }
  }, "cta ghost small"));
  if (!one.owner) {
    row.append(act("Sign out everywhere", () => (confirm(`Sign ${one.email || "this account"} out on every device, and end every `
      + "Claude it let in? A page it has open keeps working until its sign-in would renew, within the hour; then it asks to sign in.")
      ? post({ op: "sign_out", account }, said, (a) => `Signed out: ${a.sessions ?? 0} ${a.sessions === 1 ? "sign-in" : "sign-ins"} ended, `
        + `${a.claudes ?? 0} ${a.claudes === 1 ? "Claude" : "Claudes"} let go.`, { after: () => { loaded.delete("audit"); } })
      : Promise.resolve(false)), "cta ghost small"));
  }
  box.append(row, said);
  if (one.owner) {
    box.append(make("p", "note", "Your own account holds this console: it is not signed out or deleted from here."));
    return box;
  }
  // Delete, as Settings' own Delete account: what goes, that it cannot be
  // undone, and the address typed again before the button wakes.
  const zone = make("details", "danger-zone");
  const summary = make("summary", "cta ghost small", "Delete this account…");
  const form = make("form");
  const typed = make("input");
  typed.type = "email";
  typed.autocomplete = "off";
  typed.spellcheck = false;
  typed.id = "delete-confirm";
  const why = make("input");
  why.maxLength = 200;
  why.id = "delete-why";
  const go = make("button", "cta ghost danger", "Delete the account");
  go.type = "submit";
  go.disabled = true;
  const done = make("p", "note");
  done.setAttribute("role", "status");
  form.append(
    make("p", "", "Only at its person's request. Its models come out of the gallery and their links stop working; its profile, "
      + "favourites, lists, comments, follows, photos, the sets it owns and its AI apps' connections are deleted with it, exactly as "
      + "when they delete it themselves. "),
    make("p", "", make("b", "", "This is irreversible: nothing of it can be brought back.")),
    make("label", "", `Type ${one.email || "its address"} to confirm`, typed),
    make("label", "", "Why ", make("small", "", "for the audit"), why),
    make("div", "row", go), done);
  const matches = () => typed.value.trim().toLowerCase() === String(one.email || "").trim().toLowerCase() && Boolean(one.email);
  typed.addEventListener("input", () => { go.disabled = !matches(); });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!matches()) return;
    go.disabled = true;
    say(done, "Deleting…");
    try {
      const gone = await adminJson({ op: "delete_account", account }, { method: "POST",
        body: { confirm: typed.value.trim(), reason: why.value.trim() } });
      for (const one of ["people", "audit", ...REPORTED]) loaded.delete(one);
      closeSheet();
      await Promise.all([loadPeople(), loadOverview()]).catch(() => null);
      say("people-note", `Deleted ${gone.email}: ${gone.photos ?? 0} photos and ${gone.avatars ?? 0} pictures with it. Kept in the audit.`);
    } catch (problem) {
      say(done, problem.message, true);
      go.disabled = !matches();
    }
  });
  zone.append(summary, form);
  box.append(zone);
  return box;
}

/// One challenge whole, in the panel: when the address names one.
async function challengePanel(id, again = false) {
  if (!id) {
    if ($("sheet").open && $("sheet").dataset.kind === "challenge") $("sheet").close();
    return;
  }
  if (!again && $("sheet").open && $("sheet").dataset.kind === "challenge" && $("sheet").dataset.account === String(id)) return;
  openSheet("Looking…", make("p", "note", "Reading the challenge…"), { kind: "challenge", account: String(id) });
  try {
    const { title, parts } = await challengeOf(id);
    openSheet(title, parts, { kind: "challenge", account: String(id) });
  } catch (problem) {
    openSheet("Not read", make("p", "note bad", problem.message), { kind: "challenge", account: String(id) });
  }
}

/// An account's connector whole, in the panel: when the address names one.
async function connectorPanel(account, again = false) {
  if (!account) {
    if ($("sheet").open && $("sheet").dataset.kind === "connector") $("sheet").close();
    return;
  }
  if (!again && $("sheet").open && $("sheet").dataset.kind === "connector" && $("sheet").dataset.account === account) return;
  openSheet("Looking…", make("p", "note", "Reading the connector…"), { kind: "connector", account });
  try {
    const { title, parts } = await connectorOf(account);
    openSheet(title, parts, { kind: "connector", account });
  } catch (problem) {
    openSheet("Not read", make("p", "note bad", problem.message), { kind: "connector", account });
  }
}

/// After an act on an account: the list, the counts and its panel again,
/// saying what came of it.
async function afterPerson(account, told) {
  for (const one of ["audit", ...REPORTED]) loaded.delete(one);
  await Promise.all([loadPeople(), loadOverview()]);
  await person(account, true, told);
}

// ---------------------------------------------------------------------------
// Find anything (console3): the bar's search across people, models, lists,
// reports and the audit (/api/admin?op=find), each a press from its place.

let findTimer = 0;
let findAsked = 0;

/// The results shown or not; shown, the status says how many, read out
/// by a screen reader (the box's own description), and the down arrow
/// goes into them.
function findShown(open) {
  $("find-list").hidden = !open;
  if (!open) return say("find-said", "");
  const n = $("find-list").querySelectorAll("a").length;
  say("find-said", n ? `${n} found: the down arrow goes to them.` : $("find-list").textContent);
}

async function find() {
  const q = $("find-q").value.trim();
  const asked = ++findAsked;
  if (q.length < 2) return findShown(false);
  let found;
  try {
    found = await adminJson({ op: "find", q });
  } catch (problem) {
    found = { error: problem.message };
  }
  if (asked !== findAsked) return;
  const list = $("find-list");
  list.replaceChildren();
  const to = (href, text, small) => {
    const a = make("a", "", make("span", "", text), small ? make("small", "", small) : "");
    a.href = href;
    if (!href.startsWith("#")) a.target = "_blank";
    return a;
  };
  const group = (title, items) => {
    if (!items.length) return;
    list.append(make("h3", "", title), ...items);
  };
  if (found.error) {
    list.append(make("p", "state", found.error));
  } else {
    const accounts = new Map();
    for (const one of found.accounts) accounts.set(one.id, to(`#people/${one.id}`, one.email || one.id,
      one.last_sign_in ? `last signed in ${ago(one.last_sign_in)}` : "never signed in"));
    for (const one of found.people) {
      if (!accounts.has(one.account)) accounts.set(one.account, to(`#people/${one.account}`, `@${one.handle}${one.name ? ` · ${one.name}` : ""}`,
        one.email || ""));
    }
    group("People", [...accounts.values()]);
    group("Models", found.models.map((one) => to(`/m/${encodeURIComponent(one.id)}`, one.name || one.id,
      `${one.state}${one.email ? ` · ${one.email}` : ""}`)));
    group("Lists", found.lists.map((one) => to(`/c/${encodeURIComponent(one.id)}`, one.name || one.id,
      `${one.public ? "public" : "private"}${one.email ? ` · ${one.email}` : ""}`)));
    group("Reports", found.reports.map((one) => to(one.open ? `#report-${one.id}` : `#audit`, `${one.reason}: ${one.about}`,
      `${one.open ? "open" : `settled${one.resolution ? `, ${one.resolution}` : ""}`} · ${day(one.at)}${one.note ? ` · ${one.note}` : ""}`)));
    group("Acts", found.acts.map((one) => {
      const a = to("#audit", opSaid(one), `${when(one.at)} · ${one.target_kind ? `${one.target_kind} ` : ""}${one.email || one.target || ""}`);
      a.addEventListener("click", (event) => { event.preventDefault(); findShown(false); openAct(one); });
      return a;
    }));
    if (!list.childElementCount) list.append(make("p", "state", `Nothing holds “${found.query}”${TESTS ? " among the checks' own" : ""}.`));
  }
  findShown(true);
}

$("find").addEventListener("submit", (event) => { event.preventDefault(); clearTimeout(findTimer); find(); });
$("find-q").addEventListener("input", () => {
  clearTimeout(findTimer);
  findTimer = setTimeout(find, 250);
});
$("find-q").addEventListener("keydown", (event) => {
  if (event.key === "ArrowDown") {
    event.preventDefault();
    $("find-list").querySelector("a")?.focus();
  } else if (event.key === "Escape") {
    findShown(false);
  }
});
$("find-list").addEventListener("keydown", (event) => {
  const links = [...$("find-list").querySelectorAll("a")];
  const at = links.indexOf(document.activeElement);
  if (event.key === "ArrowDown" || event.key === "ArrowUp") {
    event.preventDefault();
    const next = links[at + (event.key === "ArrowDown" ? 1 : -1)];
    if (next) next.focus();
    else if (event.key === "ArrowUp") $("find-q").focus();
  } else if (event.key === "Escape") {
    findShown(false);
    $("find-q").focus();
  }
});
$("find-list").addEventListener("click", (event) => { if (event.target.closest("a[href^='#']")) findShown(false); });
document.addEventListener("click", (event) => { if (!$("find").contains(event.target)) findShown(false); });
$("find-q").addEventListener("focus", () => { if ($("find-list").childElementCount && $("find-q").value.trim().length > 1) findShown(true); });

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

/// Closed, an account's or a challenge's address goes back to the list's, at
/// once as it closes. Not on its close event: that comes a task later, and an
/// address set in between (a link, a script) was put back to the list's then,
/// so the panel it asked for never opened (console2_flow's Escape then
/// #people/C, 15 times in 20 in a page of its own; console3, 2026-11-14).
function listAddress() {
  const kind = $("sheet").dataset.kind;
  const at = route();
  const list = (kind === "person" && at.account) ? "people" : (kind === "connector" && at.account) ? "connector"
    : (kind === "challenge" && at.challenge) ? "challenges" : "";
  if (list) history.replaceState(null, "", `${location.pathname}${location.search}#${list}`);
}
function closeSheet() {
  listAddress();
  $("sheet").close();
}
$("sheet-close").addEventListener("click", closeSheet);
$("sheet").addEventListener("click", (event) => { if (event.target === $("sheet")) closeSheet(); });
// Escape (and a phone's back): its cancel comes at once, before the close.
$("sheet").addEventListener("cancel", listAddress);
$("sheet").addEventListener("close", () => { $("sheet").dataset.account = ""; });

for (const table of document.querySelectorAll("table[data-sortable]")) sortable(table);

// Signing in here, in place (sifix, 2026-11-15, the owner: sign-in must just
// work where you are): the bar's Sign in and the gate's open the site's
// sign-in dialog over the console, and signed in it opens, still on /admin
// and the section asked for. Their /profile?sign-in is for a click meant
// for a new tab. Signed in or out in another tab (web/account.js), the
// console follows: opened, or shut behind its gate.
for (const link of [$("sign-in"), $("gate-sign-in")]) {
  link.addEventListener("click", (event) => {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    askToSignIn().catch(() => { location.href = link.href; });
  });
}
addEventListener("brickworks:signed-in-done", () => start());
addEventListener("brickworks:signed-out", (event) => {
  event.preventDefault();
  loaded.clear();
  gate("You are not signed in to Brickworks in this browser.");
});
start();
