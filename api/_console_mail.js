// The console's Mail section (/admin#mail, docs/ADMIN.md, console2): every
// mail Brickworks sends, by kind and day, and what became of each.
//
// Why a webhook: production's RESEND_API_KEY may only send ("This API key
// is restricted to only send emails", GET /emails, 2026-11-12), and a key
// that can read is a full-access key of the Resend team, which other
// products share: never put in a deployment. So Resend tells us instead.
// Its webhook (registered by tools/web/resend_webhook.sh) POSTs each event
// to /api/otp?op=mail_event, signed as Svix signs (svix-id, svix-timestamp,
// svix-signature over "<id>.<timestamp>.<body>" with RESEND_WEBHOOK_SECRET),
// and mailEventRoute keeps it in mail_events (supabase/console2.sql):
// sent, delivered, delayed, bounced, complained, failed. The team's other
// products' mail comes to the same webhook and is let go unread: only mail
// from brickworks.diy is kept.
//
// What kind of mail each is: the kind tag each send carries (otp.js
// sign_in_code, _beta.js beta and feedback_answer, _comments.js digest,
// _trust.js report_digest, _canary.js canary_alarm, orangecheck.js
// sign_in_notice), else read from its subject, for mail sent before the
// tags.
//
// A unit's preview has the checks' own secret (STAND_IN_MAIL_SECRET,
// tools/deploy.sh --unit), which is nobody's real one: there only mail to
// Resend's test inboxes is kept, so a check can play Resend's part and
// nothing else can be put in the owner's list.
//
// mailRead (GET /api/admin?op=mail) reads it back with what Brickworks kept
// as sent itself (beta_mail, feedback_replies: admin_mail), one list.

import { createHmac, timingSafeEqual } from "node:crypto";
import { db } from "./_db.js";
import { rawOf } from "./_raw.js";

/// The checks' own signing secret: a test's, nobody's real one.
export const STAND_IN_MAIL_SECRET = "whsec_YnJpY2t3b3JrcyBjaGVja3MgbWFpbCBzdGFuZC1pbiwgbm9ib2R5IHMgcmVhbCBvbmU=";
const TOLERANCE_S = 300;
const OURS = /^brickworks\.diy$/i;
const TEST_INBOX = /@resend\.dev$/i;

/// Resend's event types, as mail_events keeps them.
const TYPES = {
  "email.sent": "sent", "email.delivered": "delivered", "email.delivery_delayed": "delivery_delayed",
  "email.bounced": "bounced", "email.complained": "complained", "email.failed": "failed",
  "email.suppressed": "suppressed", "email.opened": "opened", "email.clicked": "clicked", "email.scheduled": "scheduled",
};

/// Each kind by its subject, for mail that carries no kind tag.
const SUBJECTS = [
  [/is your Brickworks sign-in code$/i, "sign_in_code"],
  [/^Brickworks sign-in check failed/i, "canary_alarm"],
  [/^Brickworks: (a report|\d+ reports) to look at/i, "report_digest"],
  [/^Brickworks: .*(comment|in your feed)/i, "digest"],
  [/Brickworks beta|Brickworks Pro/i, "beta"],
  [/^About your Brickworks /i, "feedback_answer"],
  [/orangecheck .*signs you in to Brickworks/i, "sign_in_notice"],
];
export const KINDS = ["sign_in_code", "beta", "feedback_answer", "digest", "report_digest", "canary_alarm",
  "sign_in_notice", "other"];

/// What kind of mail [data] (an event's data) is about.
export function kindOf(data) {
  const tags = data?.tags;
  let tagged = "";
  if (Array.isArray(tags)) tagged = String(tags.find((tag) => tag?.name === "kind")?.value || "");
  else if (tags && typeof tags === "object") tagged = String(tags.kind || "");
  if (KINDS.includes(tagged)) return tagged;
  const subject = String(data?.subject || "");
  return SUBJECTS.find(([pattern]) => pattern.test(subject))?.[1] || "other";
}

/// Whether [header] (svix-signature: "v1,<base64> v1,<base64>") signs
/// "<id>.<timestamp>.<raw>" under [secret] (whsec_<base64>), within five
/// minutes of [now].
export function signedBy(secret, { id, timestamp, header }, raw, now = Date.now()) {
  const t = Number(timestamp);
  if (!id || !Number.isInteger(t) || Math.abs(now / 1000 - t) > TOLERANCE_S) return false;
  let key;
  try {
    key = Buffer.from(String(secret).replace(/^whsec_/, ""), "base64");
  } catch {
    return false;
  }
  if (!key.length) return false;
  const want = createHmac("sha256", key).update(`${id}.${timestamp}.${raw}`).digest();
  let found = false;
  for (const part of String(header || "").split(" ")) {
    const [version, given] = part.split(",");
    if (version !== "v1" || !given) continue;
    const got = Buffer.from(given, "base64");
    if (got.length === want.length && timingSafeEqual(got, want)) found = true;
  }
  return found;
}

const domainOf = (from) => (/@([^>\s]+)>?\s*$/.exec(String(from || ""))?.[1] || "").toLowerCase();
const clip = (given, most) => String(given ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim()
  .slice(0, most) || null;

/// POST /api/otp?op=mail_event: one of Resend's events, verified, and kept
/// when it is about Brickworks' mail. 200 for whatever is let go, so Resend
/// does not send it again; 401 unsigned; 404 where no secret is set.
export async function mailEventRoute(request, response) {
  const secret = String(process.env.RESEND_WEBHOOK_SECRET || "").trim();
  if (!secret) return response.status(404).json({ error: "This deployment takes no mail events." });
  const raw = await rawOf(request);
  const headers = request.headers || {};
  const signature = { id: String(headers["svix-id"] || ""), timestamp: String(headers["svix-timestamp"] || ""),
    header: String(headers["svix-signature"] || "") };
  if (raw === null || !signedBy(secret, signature, raw)) return response.status(401).json({ error: "That is not from Resend." });
  let event;
  try {
    event = JSON.parse(raw);
  } catch {
    return response.status(400).json({ error: "That is not JSON." });
  }
  const type = TYPES[String(event?.type || "")];
  const data = event?.data || {};
  if (!type) return response.status(200).json({ kept: false, why: "not about a mail" });
  if (!OURS.test(domainOf(data.from))) return response.status(200).json({ kept: false, why: "not Brickworks' mail" });
  const to = (Array.isArray(data.to) ? data.to : [data.to]).map((one) => String(one || "").trim()).filter(Boolean);
  const test = to.length > 0 && to.every((one) => TEST_INBOX.test(one));
  if (secret === STAND_IN_MAIL_SECRET && !test) {
    return response.status(200).json({ kept: false, why: "a checks' deployment keeps only mail to Resend's test inboxes" });
  }
  const emailId = String(data.email_id || "");
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(emailId) || !/^[A-Za-z0-9_.:-]{1,120}$/.test(signature.id)) {
    return response.status(400).json({ error: "That event names no mail." });
  }
  const at = Number.isNaN(Date.parse(event.created_at)) ? new Date().toISOString() : new Date(event.created_at).toISOString();
  const detail = type === "bounced" ? [data.bounce?.type, data.bounce?.subType, data.bounce?.message].filter(Boolean).join(": ")
    : type === "failed" ? data.failed?.reason : type === "suppressed" ? data.suppressed?.message || data.suppressed?.type : null;
  const kept = await db("rpc/mail_event_keep", { method: "POST", body: { p_event: signature.id, p_email: emailId, p_type: type,
    p_at: at, p_address: clip(to[0], 320), p_subject: clip(data.subject, 300), p_kind: kindOf(data), p_detail: clip(detail, 500),
    p_test: test } });
  return response.status(200).json({ kept: kept === true, again: kept === false, type });
}

// ---------------------------------------------------------------------------
// The section.

/// GET /api/admin?op=mail[&days=N][&tests=1]: {ready, webhook, mails,
/// by_day, totals, heard}. Each mail once: Resend's word of it, with what
/// Brickworks kept as sent beside it (by Resend's id), and the kept ones
/// Resend never told of (a test inbox's dry run, a refusal, or before the
/// webhook).
export async function mailRead(request, tests = false) {
  const days = Math.max(1, Math.min(365, Number(request.query?.days) || 30));
  const set = {
    webhook: Boolean(String(process.env.RESEND_WEBHOOK_SECRET || "").trim()),
    checks_secret: String(process.env.RESEND_WEBHOOK_SECRET || "").trim() === STAND_IN_MAIL_SECRET,
    key: Boolean(process.env.RESEND_API_KEY),
    sender: process.env.EMAIL_FROM || "Brickworks <noreply@brickworks.diy>",
  };
  let got;
  try {
    got = await db("rpc/admin_mail", { method: "POST", body: { p_days: days, p_tests: tests, p_limit: 500 } });
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return { ready: false, tests, days, ...set, mails: [], by_day: [], heard: null };
    throw trouble;
  }
  const kept = new Map();
  for (const one of got.kept || []) if (one.sent_id) kept.set(one.sent_id, one);
  const mails = (got.mails || []).map((one) => {
    const ours = kept.get(one.email_id);
    kept.delete(one.email_id);
    return { id: one.email_id, kind: one.kind === "other" && ours ? ours.kind : one.kind, address: one.address,
      subject: one.subject || ours?.subject || null, at: one.at, last_at: one.last_at, states: one.states || [],
      detail: one.detail || null, kept: ours ? ours.state : null, what: ours?.what || null };
  });
  for (const one of got.kept || []) {
    if (one.sent_id && !kept.has(one.sent_id)) continue;
    mails.push({ id: one.sent_id || null, kind: one.kind, address: one.address, subject: one.subject, at: one.at,
      last_at: one.at, states: [], detail: null, kept: one.state, what: one.what || null });
  }
  mails.sort((a, b) => String(b.at).localeCompare(String(a.at)));
  const totals = { sent: 0, delivered: 0, delayed: 0, bounced: 0, complained: 0, failed: 0 };
  for (const day of got.by_day || []) for (const key of Object.keys(totals)) totals[key] += Number(day[key]) || 0;
  totals.kept_dry = (got.kept || []).filter((one) => one.state === "dry").length;
  totals.kept_failed = (got.kept || []).filter((one) => one.state === "failed").length;
  return { ready: true, tests, days, ...set, mails, more: got.more === true, by_day: got.by_day || [], totals,
    heard: got.heard || null };
}

/// The week's bounces and complaints, for the Overview: null before
/// console2.sql.
export async function mailTrouble(tests = false) {
  try {
    const got = await db("rpc/admin_mail", { method: "POST", body: { p_days: 7, p_tests: tests, p_limit: 1 } });
    const sum = (key) => (got.by_day || []).reduce((n, day) => n + (Number(day[key]) || 0), 0);
    return { bounced: sum("bounced"), complained: sum("complained"), failed: sum("failed"), sent: sum("sent"),
      delivered: sum("delivered"), heard: got.heard || null };
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return null;
    throw trouble;
  }
}
