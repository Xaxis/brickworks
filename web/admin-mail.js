// The console's Mail (admin.html #mail, console2): every mail Brickworks
// sends, by kind and day, and what became of each as Resend tells of it,
// beside what Brickworks kept as sent (/api/admin?op=mail,
// api/_console_mail.js). /admin?tests=1: the checks' own mail.
//
// Everything is put on the page as text, never as markup.
import { $, TESTS, adminJson, ago, cell, count, emptyRow, make, resort, say, segmented, sift, timeCell, when }
  from "/admin-kit.js";

export const KIND = { sign_in_code: "Sign-in code", beta: "Beta", feedback_answer: "Feedback answer", digest: "Digest",
  report_digest: "Reports, to you", canary_alarm: "Canary alarm, to you", sign_in_notice: "Sign-in notice", other: "Other" };
const YOURS = new Set(["report_digest", "canary_alarm"]);
const STATE = { delivered: "Delivered", bounced: "Bounced", complained: "Marked as spam", failed: "Failed",
  suppressed: "Suppressed", delivery_delayed: "Delayed", sent: "Sent", opened: "Opened", clicked: "Clicked" };
const KEPT = { dry: "Kept for a test inbox, not sent", failed: "Resend refused it", sent: "Sent" };
let days = 30;
const filters = { kind: "", state: "" };

/// What became of a mail, worst first: its state's word and whether it is trouble.
function fate(mail) {
  const states = new Set(mail.states || []);
  for (const bad of ["complained", "bounced", "failed", "suppressed"]) {
    if (states.has(bad)) return { key: bad, words: STATE[bad], trouble: true };
  }
  if (states.has("delivered")) return { key: "delivered", words: STATE.delivered, trouble: false };
  if (states.has("delivery_delayed")) return { key: "waiting", words: STATE.delivery_delayed, trouble: false };
  if (states.has("sent")) return { key: "waiting", words: "Sent, not delivered yet", trouble: false };
  if (mail.kept) return { key: mail.kept === "failed" ? "trouble" : "kept", words: KEPT[mail.kept] || mail.kept, trouble: mail.kept === "failed" };
  return { key: "waiting", words: "—", trouble: false };
}

function siftMail() {
  const keep = (row) => (!filters.kind || (filters.kind === "yours" ? YOURS.has(row.dataset.kind)
    : filters.kind === "digest" ? row.dataset.kind === "digest" : row.dataset.kind === filters.kind))
    && (!filters.state || row.dataset.fate === filters.state);
  const n = sift($("mail-list"), $("mail-q").value, keep);
  const all = [...$("mail-list").rows].filter((row) => !row.classList.contains("none")).length;
  say("mail-note", all ? `${n} of ${all} shown${TESTS ? ", the checks' own" : ""}.` : "");
}
$("mail-q").addEventListener("input", siftMail);
segmented(document.querySelector('[data-filter="mail-kind"]'), (value) => { filters.kind = value; siftMail(); });
segmented(document.querySelector('[data-filter="mail-state"]'), (value) => { filters.state = value; siftMail(); });
segmented(document.querySelector('[data-filter="mail-days"]'), (value) => {
  days = Number(value) || 30;
  loadMail().catch((problem) => say("mail-note", problem.message, true));
});

export async function loadMail() {
  const m = await adminJson({ op: "mail", days: String(days) });
  const facts = $("mail-setup");
  facts.replaceChildren();
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  fact("Sent as", m.key ? m.sender : `${m.sender}, but there is no mail key here: nothing is sent`);
  fact("Resend's word", !m.webhook ? "its webhook is not set up here (RESEND_WEBHOOK_SECRET): only what Brickworks kept as sent is shown"
    : m.heard ? `heard from ${ago(m.heard)} (${when(m.heard)})${m.checks_secret ? "; the checks' own secret: only test inboxes' mail is kept" : ""}`
      : "set up, and nothing heard yet");
  if (!m.ready) fact("Not kept yet", "supabase/console2.sql is not applied");
  const t = m.totals || {};
  $("n-mail-sent").textContent = m.ready ? count(t.sent) : "—";
  $("n-mail-delivered").textContent = m.ready ? count(t.delivered) : "—";
  $("n-mail-bounced").textContent = m.ready ? count(t.bounced) : "—";
  $("n-mail-complained").textContent = m.ready ? count(t.complained) : "—";
  $("n-mail-failed").textContent = m.ready ? count((t.delayed || 0) + (t.failed || 0)) : "—";
  say("n-mail-kept", m.ready ? `${count(t.kept_dry)} kept for a test inbox, ${count(t.kept_failed)} refused` : "");

  const daysBody = $("mail-days");
  daysBody.replaceChildren();
  for (const one of m.by_day || []) {
    const row = make("tr");
    cell(row, one.day, "line");
    cell(row, KIND[one.kind] || one.kind);
    for (const key of ["sent", "delivered", "bounced", "complained"]) {
      const n = Number(one[key]) || 0;
      cell(row, count(n), n ? (key === "bounced" || key === "complained" ? "n bad" : "n") : "n faint");
    }
    const late = (Number(one.delayed) || 0) + (Number(one.failed) || 0);
    cell(row, count(late), late ? "n bad" : "n faint");
    daysBody.append(row);
  }
  if (!daysBody.rows.length) emptyRow(daysBody, m.webhook ? `Resend has told of no mail in ${m.days} days.` : "Resend's webhook is not set up here.");

  const body = $("mail-list");
  body.replaceChildren();
  for (const mail of m.mails || []) {
    const row = make("tr");
    const f = fate(mail);
    row.dataset.kind = mail.kind || "other";
    row.dataset.fate = f.trouble ? "trouble" : f.key === "delivered" ? "delivered" : "waiting";
    if (mail.id) row.dataset.mail = mail.id;
    row.dataset.find = [mail.address, mail.subject, KIND[mail.kind]].filter(Boolean).join(" ");
    timeCell(row, mail.at);
    cell(row, KIND[mail.kind] || mail.kind || "—");
    const to = cell(row, mail.address || "—", "who");
    to.dataset.value = mail.address || "";
    cell(row, mail.subject || "—", mail.subject ? "about" : "about faint");
    const said = make("td");
    said.append(make("span", f.trouble ? "pill bad" : f.key === "delivered" ? "pill good" : "pill", f.words));
    if (mail.detail) said.append(make("br"), make("small", "faint", mail.detail));
    if (mail.kept && (mail.states || []).length) said.append(make("br"), make("small", "faint", `Brickworks kept it as ${mail.kept}`));
    if (mail.last_at && mail.last_at !== mail.at) said.title = `last heard ${when(mail.last_at)}`;
    row.append(said);
    body.append(row);
  }
  if (!body.rows.length) emptyRow(body, `No mail in ${m.days} days${TESTS ? " of the checks' own" : ""}.`);
  resort(body.closest("table"));
  siftMail();
  return m;
}
