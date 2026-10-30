// Feedback, from anywhere (beta374, 2026-10-30; supabase/feedback.sql
// says how it is kept).
//
// The owner: "start working on beta tester features and feedback system".
// A report is a bug, an idea or a question, a few words, and what the
// person chose to attach, each shown to them before it goes and each
// removable: a picture (the app's own capture of its window, or the page
// on the site), and with their consent the app's version and platform (or
// the browser's size), the open model as a file, and the app's last log
// lines. Signed in, the account sends it; signed out, an address to answer
// is asked for. A beta tester's report is marked beta by the database.
//
// Routes (ops of existing API files: Vercel's plan stops at 12 functions):
//
//   POST /api/plans?op=feedback   {kind, words, email (signed out), source,
//                                 page, details, log, picture: {type, data
//                                 (base64)}, model: {name, text}}: 200 {id,
//                                 beta, attached, said}; 422 with why, 429
//                                 too many in an hour, 401 a sign-in that
//                                 has ended, 503 before feedback.sql
//   GET  /api/plans?op=feedback   signed in: {reports, beta}, your own, each
//                                 with where it stands and the answers
//   GET  /api/admin?op=feedback[&kind=K][&beta=1|0][&status=S][&tests=1]
//                                 the owner's inbox (api/admin.js gates it)
//   GET  /api/admin?op=feedback_file&id=N&file=picture|model
//   POST /api/admin?op=feedback_triage&id=N   {status, note}
//   POST /api/admin?op=feedback_reply&id=N    {words}: emailed, from
//                                 BETA_REPLY_TO when it is set, and kept
//
// The files go to the private bucket 'feedback' with the secret key, after
// the report is kept: one that does not go leaves the report without it,
// and the answer says so. The whole request is at most Vercel's 4.5 MB, so
// a picture and a model are each at most MOST.picture and MOST.model.
import { AuthError, bearer, verify } from "./_auth.js";
import { framedMail, Refusal, resend, siteOrigin } from "./_beta.js";
import { db, dbConfigured } from "./_db.js";

export const KINDS = Object.freeze({ bug: "Something is wrong", idea: "An idea", question: "A question" });
export const SOURCES = ["site", "app"];
export const STATUSES = ["new", "seen", "planned", "fixed", "wont_fix"];
export const MOST = Object.freeze({ words: 4000, page: 300, log: 20000, note: 2000, reply: 4000, email: 254,
  detail: 200, details: 20, picture: 1_500_000, model: 1_500_000 });
const BUCKET = "feedback";
const PICTURES = Object.freeze({ "image/png": "png", "image/jpeg": "jpg" });
const ADDRESS = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// Words with nothing in them that lays text out or hides it, as _beta.js.
const UNSEEN = /[\u0000-\u0008\u000b-\u001f\u007f​-‏‪-‮⁠-⁩﻿]/g;
const line = (raw) => String(raw ?? "").replace(UNSEEN, " ").replace(/\s+/g, " ").trim();
const lines = (raw) => String(raw ?? "").replace(/\r\n?/g, "\n").replace(UNSEEN, " ").split("\n")
  .map((one) => one.replace(/[ \t]+/g, " ").trimEnd()).join("\n").replace(/\n{3,}/g, "\n\n").trim();

/// A picture as sent ({type, data: base64}), checked by its first bytes:
/// {type, bytes}. Null for none; a Refusal for one that is not a PNG or a
/// JPEG, or is too big.
export function pictureOf(raw) {
  if (raw === undefined || raw === null || raw === "") return null;
  if (typeof raw !== "object" || typeof raw.data !== "string" || !PICTURES[raw.type]) {
    throw new Refusal(422, "The picture is a PNG or a JPEG.");
  }
  const bytes = Buffer.from(raw.data.replace(/^data:[^,]*,/, ""), "base64");
  if (bytes.length > MOST.picture) {
    throw new Refusal(422, `The picture is at most ${MOST.picture / 1e6} MB; that one is ${(bytes.length / 1e6).toFixed(1)} MB.`);
  }
  const png = bytes.length > 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  const jpeg = bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const type = png ? "image/png" : jpeg ? "image/jpeg" : "";
  if (!type) throw new Refusal(422, "The picture is a PNG or a JPEG.");
  return { type, bytes };
}

/// A model as sent ({name, text}): an LDraw file's text, at most
/// MOST.model. Null for none.
export function modelOf(raw) {
  if (raw === undefined || raw === null || raw === "") return null;
  if (typeof raw !== "object" || typeof raw.text !== "string") throw new Refusal(422, "The model is an LDraw file's text.");
  const text = raw.text.replace(/\r\n?/g, "\n");
  if (Buffer.byteLength(text) > MOST.model) {
    throw new Refusal(422, `The model is at most ${MOST.model / 1e6} MB as a file; that one is ${(Buffer.byteLength(text) / 1e6).toFixed(1)} MB.`);
  }
  // LDraw: every line is empty, or starts with its type, 0 to 5.
  if (!text.trim() || text.split("\n").some((one) => one.trim() && !/^\s*[0-5](\s|$)/.test(one))) {
    throw new Refusal(422, "The model is an LDraw file's text.");
  }
  return { name: line(raw.name).slice(0, 120) || "model", text };
}

/// What the person consented to send about where they are, kept small: at
/// most MOST.details names (a-z and _) with words, numbers or yes/no.
export function detailsOf(raw) {
  if (raw === undefined || raw === null) return {};
  if (typeof raw !== "object" || Array.isArray(raw)) throw new Refusal(422, "The details are names and words.");
  const out = {};
  for (const [name, value] of Object.entries(raw).slice(0, MOST.details)) {
    if (!/^[a-z][a-z0-9_]{0,39}$/.test(name)) continue;
    // An empty one says nothing, and would be an empty row in the inbox.
    if (typeof value === "string") {
      const words = line(value).slice(0, MOST.detail);
      if (words) out[name] = words;
    } else if (typeof value === "number" && Number.isFinite(value)) out[name] = value;
    else if (typeof value === "boolean") out[name] = value;
  }
  return out;
}

/// What a POST to /api/plans?op=feedback asks, checked at the edge, or a
/// Refusal in words a person can act on. [signedIn]: no address is asked.
export function reportOf(body, { signedIn }) {
  if (!body || typeof body !== "object") throw new Refusal(422, "Say what happened, or what you would like.");
  const kind = String(body.kind || "");
  if (!KINDS[kind]) throw new Refusal(422, "Choose what it is: something wrong, an idea or a question.");
  if (typeof body.words !== "string") throw new Refusal(422, "Say what happened, or what you would like.");
  const words = lines(body.words);
  if (words.length < 3) throw new Refusal(422, "Say what happened, or what you would like.");
  if (words.length > MOST.words) throw new Refusal(422, `At most ${MOST.words} characters; that is ${words.length}.`);
  let email = null;
  if (!signedIn) {
    email = line(body.email).toLowerCase();
    if (!email) throw new Refusal(422, "Give an email address, so we can answer you.");
    if (email.length > MOST.email || !ADDRESS.test(email)) throw new Refusal(422, "That email address does not look right.");
  }
  const source = SOURCES.includes(body.source) ? body.source : "site";
  const page = line(body.page).slice(0, MOST.page);
  if (body.log !== undefined && body.log !== null && typeof body.log !== "string") {
    throw new Refusal(422, "The log is lines of text.");
  }
  // The last of the log, where there is more than is kept.
  const log = lines(body.log || "").slice(-MOST.log);
  const model = modelOf(body.model);
  const details = detailsOf(body.details);
  if (model) details.model_name = model.name;
  return { kind, words, email, source, page, details, log, picture: pictureOf(body.picture), model };
}

const say = (response, status, error, extra = {}) => response.status(status).json({ error, ...extra });
/// PostgREST answers 404 for a function that is not there: before feedback.sql.
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const NOT_YET = "Feedback is not open here yet. Try again soon.";

function bodyOf(request) {
  if (typeof request.body !== "string") return request.body || {};
  try {
    return JSON.parse(request.body);
  } catch {
    return {};
  }
}

// ---------------------------------------------------------------------------
// The bucket, with the secret key.

function project() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

function storageHeaders(extra = {}) {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, ...extra };
}

async function putFile(name, bytes, type) {
  const answer = await fetch(`${project()}/storage/v1/object/${BUCKET}/${name}`, {
    method: "POST", headers: storageHeaders({ "content-type": type, "x-upsert": "true", "cache-control": "no-store" }),
    body: bytes, signal: AbortSignal.timeout(30000) });
  if (!answer.ok) throw new Error(`storage POST ${BUCKET}: ${answer.status}`);
}

async function getFile(name) {
  const answer = await fetch(`${project()}/storage/v1/object/${BUCKET}/${name}`, {
    headers: storageHeaders(), signal: AbortSignal.timeout(30000) });
  if (answer.status === 400 || answer.status === 404) return null;
  if (!answer.ok) throw new Error(`storage GET ${BUCKET}: ${answer.status}`);
  return Buffer.from(await answer.arrayBuffer());
}

/// Exactly these files of the bucket, and nothing else.
export async function deleteFeedbackFiles(names) {
  for (let at = 0; at < names.length; at += 100) {
    const answer = await fetch(`${project()}/storage/v1/object/${BUCKET}`, {
      method: "DELETE", headers: storageHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ prefixes: names.slice(at, at + 100) }), signal: AbortSignal.timeout(20000) });
    if (!answer.ok) throw new Error(`storage DELETE ${BUCKET}: ${answer.status}`);
  }
}

// ---------------------------------------------------------------------------
// Sending, and your own.

/// GET or POST /api/plans?op=feedback. [place]: where it came from, as a
/// key only this server can make (api/plans.js placeOf), never the address.
export async function feedbackRoute(request, response, place) {
  response.setHeader("Cache-Control", "no-store");
  if (!["GET", "POST"].includes(request.method)) return say(response, 405, "GET your own, or POST a report");
  if (!dbConfigured()) return say(response, 503, NOT_YET);
  let claims = null;
  if (bearer(request)) {
    try {
      claims = await verify(bearer(request), request);
    } catch (trouble) {
      if (!(trouble instanceof AuthError)) throw trouble;
      return say(response, trouble.status, "Your sign-in has ended. Sign in again to send this.");
    }
  }
  try {
    if (request.method === "GET") {
      if (!claims) return say(response, 401, "Sign in to see your reports.");
      return response.status(200).json(await db("rpc/feedback_mine", { method: "POST", body: { p_account: claims.sub } }));
    }
    return await send(request, response, claims, place);
  } catch (trouble) {
    if (trouble instanceof Refusal) return say(response, trouble.status, trouble.message, trouble.extra);
    console.error(`feedback: ${String(trouble?.message || trouble).slice(0, 160)}`);
    if (notYet(trouble)) return say(response, 503, NOT_YET);
    return say(response, 503, "That did not go just now. Try again in a minute.");
  }
}

async function send(request, response, claims, place) {
  const report = reportOf(bodyOf(request), { signedIn: Boolean(claims) });
  const kept = await db("rpc/feedback_send", { method: "POST", body: { p_account: claims?.sub ?? null,
    p_email: report.email, p_kind: report.kind, p_words: report.words, p_source: report.source, p_page: report.page,
    p_details: report.details, p_log: report.log, p_place: place || "" } });
  if (kept?.refused === "busy") return say(response, 429, "That is a lot of reports in an hour. Try again later.");
  if (kept?.refused === "nobody") return say(response, 401, "Sign in again to send this.");
  const id = Number(kept?.id);
  if (!Number.isSafeInteger(id)) throw new Error("feedback_send said no id");
  const attached = {};
  const names = { picture: null, model: null };
  for (const [what, name, bytes, type] of [
    ["picture", report.picture && `${id}/picture.${PICTURES[report.picture.type]}`, report.picture?.bytes, report.picture?.type],
    ["model", report.model && `${id}/model.mpd`, report.model && Buffer.from(report.model.text), "text/plain"],
  ]) {
    if (!name) continue;
    try {
      await putFile(name, bytes, type);
      names[what] = name;
      attached[what] = true;
    } catch (trouble) {
      console.error(`feedback: ${what} not stored: ${String(trouble?.message || trouble).slice(0, 120)}`);
      attached[what] = false;
    }
  }
  if (names.picture || names.model) {
    await db("rpc/feedback_files", { method: "POST", body: { p_id: id, p_picture: names.picture, p_model: names.model } });
  }
  const lost = Object.entries(attached).filter(([, went]) => !went).map(([what]) => what);
  const said = `Thank you. We read every report ourselves${claims ? "; this one is on your settings page, with "
    + "where it stands and our answer" : ", and answer by email"}.${lost.length ? ` The ${lost.join(" and the ")} did `
    + "not go with it." : ""}`;
  return response.status(200).json({ id, beta: kept.beta === true, attached, said });
}

// ---------------------------------------------------------------------------
// The owner's inbox (api/admin.js, after its owner check).

/// GET /api/admin?op=feedback[&kind=K][&beta=1|0][&status=S|open][&tests=1].
export async function feedbackInbox(request, response) {
  const query = request.query || {};
  const kind = String(query.kind || "");
  if (kind && !KINDS[kind]) return say(response, 400, "kind is bug, idea or question");
  const status = String(query.status || "");
  if (status && status !== "open" && !STATUSES.includes(status)) {
    return say(response, 400, "status is open, new, seen, planned, fixed or wont_fix");
  }
  const beta = String(query.beta ?? "");
  try {
    const inbox = await db("rpc/feedback_inbox", { method: "POST", body: { p_kind: kind || null,
      p_beta: beta === "1" ? true : beta === "0" ? false : null, p_status: status || null,
      p_tests: String(query.tests || "") === "1", p_limit: 300 } });
    const replyTo = String(process.env.BETA_REPLY_TO || "").trim();
    return response.status(200).json({ ...inbox, reply_to: replyTo || null, mail: Boolean(process.env.RESEND_API_KEY) });
  } catch (trouble) {
    if (notYet(trouble)) return say(response, 503, "Not open yet: supabase/feedback.sql is not applied.");
    throw trouble;
  }
}

const idOf = (request) => {
  const id = Number(String(request.query?.id || ""));
  return Number.isSafeInteger(id) && id > 0 ? id : null;
};

async function one(id) {
  try {
    return await db("rpc/feedback_one", { method: "POST", body: { p_id: id } });
  } catch (trouble) {
    if (notYet(trouble)) throw new AuthError("Not open yet: supabase/feedback.sql is not applied.", 503);
    throw trouble;
  }
}

/// GET /api/admin?op=feedback_file&id=N&file=picture|model: the file, to
/// the owner alone (the page fetches it with the sign-in and shows it).
export async function feedbackFile(request, response) {
  const id = idOf(request);
  const which = String(request.query?.file || "");
  if (!id || !["picture", "model"].includes(which)) return say(response, 400, "name a report and a file: ?id=N&file=picture|model");
  const report = await one(id);
  const name = report?.[which];
  if (!name) return say(response, 404, "That report has no such file.");
  const bytes = await getFile(name);
  if (!bytes) return say(response, 404, "That file is not in storage.");
  response.setHeader("Content-Type", which === "model" ? "text/plain; charset=utf-8"
    : name.endsWith(".png") ? "image/png" : "image/jpeg");
  response.setHeader("X-Content-Type-Options", "nosniff");
  if (which === "model") {
    const named = String(report.details?.model_name || "model").replace(/[^A-Za-z0-9 ._-]/g, "").slice(0, 80) || "model";
    response.setHeader("Content-Disposition", `attachment; filename="report-${id}-${named.replace(/\.(mpd|ldr)$/i, "")}.mpd"`);
  }
  return response.status(200).end(bytes);
}

/// POST /api/admin?op=feedback_triage&id=N {status, note}: where it
/// stands, and the owner's own note, which its sender never sees.
export async function feedbackTriage(request, response) {
  const id = idOf(request);
  if (!id) return say(response, 400, "name a report: ?id=N");
  const body = bodyOf(request);
  const status = body.status === undefined || body.status === null ? null : String(body.status);
  if (status !== null && !STATUSES.includes(status)) return say(response, 422, "new, seen, planned, fixed or wont_fix");
  const note = body.note === undefined || body.note === null ? null : lines(body.note);
  if (note !== null && note.length > MOST.note) return say(response, 422, `The note is at most ${MOST.note} characters.`);
  let said;
  try {
    said = await db("rpc/feedback_triage", { method: "POST", body: { p_id: id, p_status: status, p_note: note } });
  } catch (trouble) {
    if (notYet(trouble)) return say(response, 503, "Not open yet: supabase/feedback.sql is not applied.");
    throw trouble;
  }
  if (said?.refused === "none") return say(response, 404, "There is no such report.");
  return response.status(200).json({ report: said });
}

/// The answer to [report] as an email: the owner's words, then what they
/// said, and where to see it.
export function replyMail(report, words, origin = siteOrigin(), replyTo = "") {
  const theirs = report.words.length > 600 ? `${report.words.slice(0, 600)}…` : report.words;
  const what = { bug: "report", idea: "idea", question: "question" }[report.kind] || "report";
  return framedMail({
    subject: `About your Brickworks ${what}`,
    paragraphs: [words, `You wrote, on ${new Date(report.at).toUTCString().slice(5, 16)}:\n${theirs}`],
    action: report.signed_in ? { label: "See your reports", href: `${origin}/settings#feedback` }
      : { label: "Open Brickworks", href: `${origin}/app` },
  }, origin, replyTo);
}

/// POST /api/admin?op=feedback_reply&id=N {words}: emailed to the person
/// and kept with the report, which they see on their settings page.
export async function feedbackReply(request, response, claims) {
  const id = idOf(request);
  if (!id) return say(response, 400, "name a report: ?id=N");
  const words = lines(bodyOf(request).words);
  if (words.length < 2) return say(response, 422, "Write the answer.");
  if (words.length > MOST.reply) return say(response, 422, `The answer is at most ${MOST.reply} characters.`);
  const report = await one(id);
  if (!report) return say(response, 404, "There is no such report.");
  const replyTo = String(process.env.BETA_REPLY_TO || "").trim();
  const mail = replyMail(report, words, siteOrigin(), replyTo);
  const sent = await resend(report.email, mail, "feedback answer");
  const said = await db("rpc/feedback_reply", { method: "POST", body: { p_id: id, p_words: words,
    p_by: String(claims?.email || "the owner").slice(0, 320), p_mail: sent.state, p_sent_id: sent.id } });
  return response.status(200).json({ report: said, mail: sent.state, subject: mail.subject });
}

// ---------------------------------------------------------------------------
// The daily run and an account's deletion.

/// Reports past their time erased, and their files (supabase/feedback.sql
/// feedback_sweep): {erased, files}. Run by the beta's daily cron.
export async function sweepFeedback() {
  const swept = await db("rpc/feedback_sweep", { method: "POST", body: {} });
  const files = Array.isArray(swept?.files) ? swept.files : [];
  if (files.length) await deleteFeedbackFiles(files);
  return { erased: Number(swept?.erased) || 0, files: files.length };
}

/// The files of [account]'s reports deleted, before the account (and with
/// it its reports) is: how many. Nothing before feedback.sql.
export async function deleteFeedbackOf(account) {
  if (!UUID.test(String(account || ""))) return 0;
  let names = [];
  try {
    names = await db("rpc/feedback_files_of", { method: "POST", body: { p_account: account } });
  } catch (trouble) {
    if (notYet(trouble)) return 0;
    throw trouble;
  }
  if (Array.isArray(names) && names.length) await deleteFeedbackFiles(names);
  return Array.isArray(names) ? names.length : 0;
}
