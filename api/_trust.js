// The ground rules' server half (2026-10-18, supabase/trust.sql): the age
// question, the under-13 rule as the API says it, and the email that tells
// the site's owner what was reported.
//
// The age. Asked once of every account (api/account.js), as the month and
// year of birth; worked out here into whether that is 13 or over, and only
// that is kept, with when (answer_age). The date goes no further than the
// request it came in: never to the database, never to a log.
//
// An account under 13 may build, keep its models and share them by link.
// It may not have anything public: a model in the gallery, a profile, a
// public collection, a name credited on a link. publicTrouble says so in
// words, for api/share.js and api/people.js to refuse with before the
// database refuses too (its triggers). Something new in public needs the
// question answered 13 or over; an account not asked yet is asked first.
//
// The reports. Each report is in an email to the owner within the hour, at
// most one an hour (claim_report_digest keeps the count), to the address
// api/admin.js lets in (MASTER_EMAIL), from the sender sign-in codes come
// from (api/otp.js). A report about a test account's things, or made by
// one, is a dry run: the email is rendered and recorded beside its digest,
// and never sent to anybody.
//
// Until trust.sql is applied, its functions are not there (404): nobody is
// asked, nothing is refused that was not refused before, and no digest is
// made. The API keeps working as it did.

import { db } from "./_db.js";

const NOT_THERE = /: 404$/;
let saidMissing = false;

/// Whether the database said the function is not there: trust.sql not applied.
function missing(trouble) {
  if (!NOT_THERE.test(String(trouble?.message || ""))) return false;
  if (!saidMissing) {
    saidMissing = true;
    console.error("trust: supabase/trust.sql is not applied here; no age is asked and no report is emailed");
  }
  return true;
}

// ---------------------------------------------------------------------------
// The age.

/// The month and year of birth, as sent, checked: {month, year}, or
/// {trouble} in words. Never kept and never logged.
export function birthOf(body, now = new Date()) {
  const month = Number(body?.month);
  const year = Number(body?.year);
  if (!Number.isInteger(month) || month < 1 || month > 12) return { trouble: "Choose the month you were born in." };
  const thisYear = now.getUTCFullYear();
  if (!Number.isInteger(year) || year > thisYear || year < thisYear - 120) {
    return { trouble: "Type the year you were born, as four digits." };
  }
  if (year === thisYear && month > now.getUTCMonth() + 1) return { trouble: "That month has not come yet." };
  return { month, year };
}

/// Whether someone born in [month] of [year] is 13 or over now. Only the
/// month is asked, so a birthday this month counts as had.
export function thirteenOrOver(month, year, now = new Date()) {
  const months = (now.getUTCFullYear() - year) * 12 + (now.getUTCMonth() + 1 - month);
  return months >= 13 * 12;
}

/// What the database keeps of [account]'s age: {ready, ask, over_13,
/// asked_at}. ready false: trust.sql is not applied, and nothing is asked.
export async function ageOf(account) {
  try {
    const age = await db("rpc/age_of", { method: "POST", body: { account } });
    return {
      ready: true,
      ask: age?.ask === true,
      over_13: typeof age?.over_13 === "boolean" ? age.over_13 : null,
      asked_at: age?.asked_at ?? null,
    };
  } catch (trouble) {
    if (missing(trouble)) return { ready: false, ask: false, over_13: null, asked_at: null };
    throw trouble;
  }
}

/// The answer, kept as 13 or over or not. An account already answered
/// keeps the answer it gave: what comes back is that.
export async function answerAge(account, atLeast13) {
  const age = await db("rpc/answer_age", { method: "POST", body: { account, at_least_13: atLeast13 } });
  return { ready: true, ask: age?.ask === true,
    over_13: typeof age?.over_13 === "boolean" ? age.over_13 : null, asked_at: age?.asked_at ?? null };
}

const ASK_FIRST = "Brickworks asks everyone one question first. Sign in again, in the app or on "
  + "brickworks.diy, to answer it, then try this again.";

// Said to an account under 13, politely, for each thing it may not have.
const UNDER_13 = {
  listing: "The gallery is for people 13 and over, so this model cannot be listed there. It is "
    + "shared at its link all the same: publish it without listing it.",
  credit: "A name is shown on a link only for people 13 and over: share it without one.",
  profile: "Public profiles are for people 13 and over, so this account does not have one. "
    + "Building, your models and sharing by link are all yours.",
  collection: "Public collections are for people 13 and over. Keep this one private: it is still "
    + "yours to fill and use.",
};

/// Why [account] may not have the public things [wanted] names, or null
/// when it may. Each of listing, profile, collection and credit is true
/// for one it is about to make public (that needs the question answered
/// 13 or over), "kept" for one it already had and keeps (that needs only
/// not being under 13), or false. A credit is always "kept": an account
/// not asked yet may credit a link as before. As the database's triggers.
export async function publicTrouble(account, wanted) {
  const asked = Object.keys(wanted).filter((what) => wanted[what]);
  if (asked.length === 0) return null;
  const age = await ageOf(account);
  if (!age.ready) return null;
  for (const what of ["listing", "profile", "collection", "credit"]) {
    if (!asked.includes(what)) continue;
    if (age.over_13 === false) return UNDER_13[what];
    if (wanted[what] === true && what !== "credit" && age.over_13 !== true) return ASK_FIRST;
  }
  return null;
}

/// Whether a visitor may be shown [account]'s profile: not taken out of
/// the gallery, not under 13. Before trust.sql, the first only.
export async function shownPublicly(account) {
  try {
    return (await db("rpc/shown_publicly", { method: "POST", body: { account } })) === true;
  } catch (trouble) {
    if (!missing(trouble)) throw trouble;
    return (await db("rpc/is_barred", { method: "POST", body: { account } })) !== true;
  }
}

// ---------------------------------------------------------------------------
// The reports, emailed.

// What each reason is called on the report dialog (web/report.js).
const REASONS = {
  spam: "Spam, or not a model",
  offensive: "Hateful, abusive or offensive",
  sexual: "Sexual",
  violent: "Violent or cruel",
  copied: "Somebody else's work, copied",
  trademark: "Uses a name or a mark somebody else owns",
  personal: "Somebody's personal information",
  other: "Something else",
};

const SENDER = "Brickworks <noreply@brickworks.diy>";

const escape = (text) => String(text ?? "").replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

/// One printable line of what someone typed, cut short for an email.
function short(text, most) {
  const line = String(text ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim();
  return line.length > most ? `${line.slice(0, most - 1)}…` : line;
}

/// What a report is about, in words, and where it is. A comment's names
/// its model, and goes to the comment on the model's page
/// (supabase/comments.sql).
function about(report, origin) {
  if (report.comment) {
    return { what: `a comment${report.said ? ` (“${short(report.said, 120)}”)` : ""} on the model `
      + `“${short(report.name || "", 80)}”`, where: `${origin}/m/${report.model}#comment-${report.comment}` };
  }
  if (report.model) {
    return { what: report.name ? `the model “${short(report.name, 80)}”` : "a model",
      where: `${origin}/m/${report.model}` };
  }
  if (report.handle) {
    return { what: `the profile @${report.handle}`, where: `${origin}/u/${report.handle}` };
  }
  return { what: report.name ? `the collection “${short(report.name, 80)}”` : "a collection",
    where: `${origin}/c/${report.collection}` };
}

/// The email for a digest ({digest, reports, more}): {subject, text,
/// html}. Each report says what it is about, why, the first words of its
/// note, and links to its row on the admin page. Who reported it and how
/// to reach them stay on the admin page.
export function renderDigest(digest, origin) {
  const reports = Array.isArray(digest?.reports) ? digest.reports : [];
  const n = reports.length;
  const more = Number(digest?.more) || 0;
  const subject = n === 1 ? "Brickworks: a report to look at" : `Brickworks: ${n} reports to look at`;
  const admin = `${origin}/admin`;
  const items = reports.map((report) => {
    const { what, where } = about(report, origin);
    return { reason: REASONS[report.reason] || report.reason, what, where,
      note: report.note ? short(report.note, 240) : "", link: `${admin}#report-${report.id}`,
      at: new Date(report.at).toUTCString().replace(/:\d\d GMT$/, " UTC") };
  });
  const since = n === 1 ? "A report arrived on Brickworks." : `${n} reports arrived on Brickworks.`;
  const behind = more ? `${more} more wait behind these, for the next email.` : "";
  const text = [since, "",
    ...items.flatMap((item, at) => [
      `${at + 1}. ${item.reason}: ${item.what}`,
      `   ${item.at}`,
      ...(item.note ? [`   “${item.note}”`] : []),
      `   On the admin page: ${item.link}`,
      `   The page reported: ${item.where}`, ""]),
    ...(behind ? [behind, ""] : []),
    `Everything open is on the admin page: ${admin}`,
    "One email an hour at most: reports that arrive within the hour come in the next."].join("\n");
  const html = `<!doctype html>
<div style="font:15px/1.55 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;color:#14181d;max-width:560px;margin:0 auto;padding:24px 20px">
  <p style="margin:0 0 16px;font-size:14px;color:#5b6472">Brickworks</p>
  <p style="margin:0 0 18px">${escape(since)}</p>
  ${items.map((item) => `<div style="margin:0 0 16px;padding:12px 14px;border:1px solid #d9dee5;border-radius:8px">
    <p style="margin:0 0 4px"><b>${escape(item.reason)}</b>: ${escape(item.what)}</p>
    <p style="margin:0 0 6px;color:#5b6472;font-size:13px">${escape(item.at)}</p>
    ${item.note ? `<p style="margin:0 0 8px">“${escape(item.note)}”</p>` : ""}
    <p style="margin:0"><a href="${escape(item.link)}">Open it on the admin page</a> · <a href="${escape(item.where)}" style="color:#5b6472">the page reported</a></p>
  </div>`).join("\n  ")}
  ${behind ? `<p style="margin:0 0 12px">${escape(behind)}</p>` : ""}
  <p style="margin:0 0 6px"><a href="${escape(admin)}">Everything open, on the admin page</a></p>
  <p style="margin:0;color:#97a0ae;font-size:13px">One email an hour at most: reports that arrive within the hour come in the next.</p>
</div>`;
  return { subject, text, html };
}

/// Send what waits in a stream, if this hour has not had its email:
/// "owner", or the stream of [report] (the one just made). {state} is
/// none (nothing to send, or not this hour), sent, failed (its reports go
/// in the next), or dry (a test's: rendered and recorded, never sent).
/// Never to anybody but MASTER_EMAIL; REPORT_MAIL=off sends nothing at all
/// to anybody, and leaves the owner's reports for a server that can.
export async function sendDigest({ origin, stream = "owner", report = null }) {
  let digest;
  try {
    digest = await db("rpc/claim_report_digest", { method: "POST",
      body: { wanted: stream, report } });
  } catch (trouble) {
    if (missing(trouble)) return { state: "none" };
    throw trouble;
  }
  if (!digest || typeof digest !== "object" || !digest.digest) return { state: "none" };
  const email = renderDigest(digest, origin);
  const count = Array.isArray(digest.reports) ? digest.reports.length : 0;
  const finish = (outcome) => db("rpc/finish_report_digest", { method: "POST", body: {
    one: digest.digest, outcome, said_subject: email.subject, said_body: email.text, said_html: email.html } });
  if (String(digest.stream).startsWith("test:")) {
    await finish("dry");
    return { state: "dry", digest: digest.digest, reports: count, subject: email.subject };
  }
  const to = (process.env.MASTER_EMAIL || "").trim();
  const key = process.env.RESEND_API_KEY;
  if (!to || !key || process.env.REPORT_MAIL === "off") {
    await finish("failed");
    return { state: "failed", reports: count };
  }
  let sent = false;
  try {
    const reply = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ from: process.env.EMAIL_FROM || SENDER, to: [to],
        subject: email.subject, html: email.html, text: email.text }),
      signal: AbortSignal.timeout(10000),
    });
    sent = reply.ok;
    if (!sent) console.error(`trust: Resend refused the report digest: ${reply.status}`);
  } catch (trouble) {
    console.error(`trust: the report digest did not go: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  await finish(sent ? "sent" : "failed");
  return { state: sent ? "sent" : "failed", reports: count };
}
