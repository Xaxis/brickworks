// Comments on a shared model, and on one step of it (2026-10-18,
// supabase/comments.sql). api/people.js answers the requests with these.
//
//   GET  ?op=comments&id=X&v=N    the comments on model X, oldest first,
//                                 each saying its step and version as it
//                                 is shown on version N (the newest when
//                                 none is asked), the comment it answers
//                                 (parent: a reply, 2026-10-22), and what
//                                 the caller may do (with a session:
//                                 whether they may write, and why not in
//                                 words); replies: true once replies.sql
//                                 is applied
//   POST ?op=comment              (session) {model, version, step?, body}:
//                                 a comment on the model, or on that step
//                                 of that version
//   POST ?op=reply                (session) {id, body}: a reply to comment
//                                 id, on its step and version; to a reply,
//                                 in its thread (supabase/replies.sql)
//   POST ?op=comment_change       (session) {id, what, body?}: its author
//                                 edits it (edit, with body) or removes it
//                                 (remove); the model's owner hides it or
//                                 shows it again (hide, show)
//   POST ?op=comments_open&id=X   (session) {open}: its owner turns
//                                 comments on model X on or off
//   POST ?op=mail                 (session) {comments, models, versions,
//                                 photos, remixes}, any of them: whether to
//                                 email the caller, at most once a day, of
//                                 new comments on their models and of their
//                                 feed's rows of each kind (supabase/
//                                 follows.sql). Each off until they say
//                                 (/profile)
//
// Who may write is the database's to say (comment_trouble), and it says
// it again whatever writes (its trigger): a signed-in account that
// answered the age question 13 or over, not taken out of the gallery, on
// a model open to comments; 10 an hour and 50 a day (may_act). What only
// this side can do is checked here first: the words a stranger may not be
// shown (api/_names.js), and the text made plain — line ends kept,
// anything else unprintable taken out. Nothing anybody wrote is ever put
// on a page as markup: the pages set it as text.
//
// A comment on a step belongs to the version it was written on. Shown on
// another version, it is on the same step there only while no version
// between changed that step or one before it (share_versions'
// first_changed, which keeps a builder's place the same way): otherwise
// it is still listed, and says which step of which version it was about,
// but is on no step of this one.
//
// Until comments.sql is applied its functions are not there (404): the
// list says there are none and comments are not open yet, and nothing
// can be written. Everything else works as before. Until replies.sql is,
// the list says replies: false and a reply is refused as not open yet.
//
// A reply is a comment, under every rule of one (the same limits count
// it); it lives under its comment and is shown only where that is.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { withFaces } from "./_faces.js";
import { Unacceptable, count } from "./_directory.js";
import { namesTrouble } from "./_names.js";
import { feedSaid } from "./_follows.js";

export const MOST_CHARACTERS = 1000;
// How often, as comments.sql counts it (may_act): [an hour, a day].
export const LIMITS = { comment: [10, 50], edit: [20, 100], hide: [60, 300], settings: [30, 100] };
const ID = /^[A-Za-z0-9]{10}$/;
const VERSION = /^[1-9][0-9]{0,5}$/;
const NOT_THERE = /: 404$/;
const NOT_YET = "Comments are not open on Brickworks yet.";
const REPLIES_NOT_YET = "Replies are not open on Brickworks yet: add a comment of your own.";

// What a refusal from comments.sql says, and its status.
export const WORDS = {
  sign_in: [401, "Sign in to add a comment: we email you a code, no password. Anyone can read them."],
  ask_first: [422, "Brickworks asks everyone one question first. Sign in again, in the app or on "
    + "brickworks.diy, to answer it, then add your comment."],
  under_13: [422, "Comments are for people 13 and over, so you can read them here but not add one. "
    + "Building, your models and sharing by link are all yours."],
  barred: [403, "Brickworks took this account out of the gallery, so it cannot add comments."],
  closed: [409, "Comments are off on this model."],
  no_model: [404, "There is no shared model at that link."],
  no_version: [404, "That model has no such version."],
  no_step: [400, "That version has no such step."],
  body: [400, "A comment is 1 to 1,000 characters of plain text."],
  limit: [429, "That is a lot of comments in a short time: try again in an hour."],
  no_comment: [404, "That comment is not there any more, so it cannot be answered."],
  not_yours: [403, "That comment is somebody else's."],
  not_owner: [403, "Only the model's builder can do that."],
};

function refused(code) {
  const [status, words] = WORDS[code] || [400, "That could not be done."];
  return new Unacceptable(words, status);
}

/// An rpc of comments.sql, or [missing]'s answer when the file is not applied.
async function call(name, body, missing) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || "")) && missing !== undefined) return missing();
    throw trouble;
  }
}
const notYet = () => {
  throw new Unacceptable(NOT_YET, 503);
};

async function account(request) {
  return (await verify(bearer(request))).sub;
}

// ---------------------------------------------------------------------------
// Pure: what a comment says, and where it shows.

/// What somebody typed, made plain: {text}, or {trouble} in words. Line
/// ends kept (three or more made two), every other unprintable character
/// a space, runs of space one, each line's end trimmed; 1 to 1,000
/// characters as the database counts them; no word the gallery does not
/// show.
export function cleanComment(given) {
  if (typeof given !== "string") return { trouble: "A comment is text." };
  const text = given.replace(/\r\n?/g, "\n")
    .replace(/[\u0000-\u0009\u000b-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ")
    .split("\n").map((line) => line.replace(/[  ]+/g, " ").trimEnd()).join("\n")
    .replace(/\n{3,}/g, "\n\n").trim();
  const length = [...text].length;
  if (length === 0) return { trouble: "Say something first: a comment is 1 to 1,000 characters." };
  if (length > MOST_CHARACTERS) {
    return { trouble: `A comment is at most 1,000 characters; that is ${length.toLocaleString("en-US")}.` };
  }
  const words = namesTrouble({ "Your comment": [text, "words"] });
  if (words) return { trouble: words };
  return { text };
}

/// The step of version [asked] that [comment] ({version, step}) is on, or
/// null: one on the whole model, or on a step that a version between the
/// two changed (or one before it), or that [asked] does not have.
/// [versions] are the link's, [{n, steps, first_changed}].
export function stepIn(comment, asked, versions) {
  const step = comment.step;
  if (step === null || step === undefined) return null;
  const known = new Map(versions.map((one) => [one.n, one]));
  if (comment.version !== asked) {
    const low = Math.min(comment.version, asked);
    const high = Math.max(comment.version, asked);
    for (let n = low + 1; n <= high; n += 1) {
      const one = known.get(n);
      if (!one) return null;
      if (one.first_changed !== null && one.first_changed !== undefined && one.first_changed <= step) return null;
    }
  }
  const steps = known.get(asked)?.steps;
  if (steps && step > steps) return null;
  return step;
}

/// Where it was said, in words: "on step 7 of version 2", "on version 2"
/// for the whole model, and ", an older version" after either when a newer
/// one is out.
export function saidWhere(comment, newest) {
  const where = comment.step ? `on step ${comment.step} of version ${comment.version}` : `on version ${comment.version}`;
  return comment.version < newest ? `${where}, an older version` : where;
}

/// A comment as an answer gives it, shown on version [asked].
export function commentSaid(comment, asked, newest, versions) {
  return {
    id: comment.id, version: comment.version, step: comment.step ?? null,
    on_step: stepIn(comment, asked, versions), body: comment.body, at: comment.at,
    edited_at: comment.edited_at ?? null, by: comment.by ?? null, handle: comment.handle ?? null,
    by_owner: comment.by_owner === true, mine: comment.mine === true, hidden: comment.hidden === true,
    older: comment.version < newest, said: saidWhere(comment, newest),
    parent: Number.isInteger(comment.parent) ? comment.parent : null,
  };
}

// ---------------------------------------------------------------------------
// The requests.

/// The link's versions as comments need them: [{n, steps, first_changed}],
/// newest first. A link with none is its version 1.
async function versionsOf(id) {
  const rows = await db(`share_versions?model=eq.${id}&select=n,steps,first_changed&order=n.desc&limit=100`);
  return rows.length ? rows.map((one) => ({ n: one.n, steps: one.steps ?? null, first_changed: one.first_changed ?? null }))
    : [{ n: 1, steps: null, first_changed: null }];
}

/// What [who] may do on [id]: {signed_in, may_write, why_not, owner}.
async function youOn(id, who, owner) {
  if (!who) return { signed_in: false, may_write: false, why_not: WORDS.sign_in[1], owner: false };
  const trouble = await call("comment_trouble", { account: who, model_id: id }, () => "not_yet");
  if (trouble === "not_yet") return { signed_in: true, may_write: false, why_not: NOT_YET, owner };
  return { signed_in: true, may_write: !trouble, why_not: trouble ? WORDS[trouble]?.[1] || "" : "", owner };
}

export async function listComments(request, response) {
  const who = bearer(request) ? await account(request) : null;
  response.setHeader("Cache-Control", who ? "private, no-store" : "no-store");
  const id = String(request.query?.id || "");
  if (!ID.test(id)) throw new Unacceptable("name a link: ?id=<ten characters>");
  const given = request.query?.v;
  if (given !== undefined && given !== "" && !VERSION.test(String(given))) {
    throw new Unacceptable("v is a version's number, from 1");
  }
  const on = await call("comments_on", { model_id: id, asker: who }, () => ({ missing: true }));
  if (on && on.missing) {
    return response.status(200).json({ model: id, ready: false, open: false, comments: [], version: 1, newest: 1,
      you: { signed_in: Boolean(who), may_write: false, why_not: NOT_YET, owner: false } });
  }
  if (!on) throw refused("no_model");
  const versions = await versionsOf(id);
  const newest = versions[0].n;
  const asked = given ? Number(given) : newest;
  if (!versions.some((one) => one.n === asked)) throw refused("no_version");
  const comments = (on.comments || []).map((one) => commentSaid(one, asked, newest, versions));
  return response.status(200).json(await withFaces({ model: id, ready: true, version: asked, newest, open: on.open === true,
    replies: on.threads === true, count: comments.length, comments, you: await youOn(id, who, on.owner === true) }));
}

/// A new comment. Its model's owner, if they asked to be emailed and no
/// email has gone to them today, is told now (sendCommentDigests); a
/// test's is a dry run, said back as told.
export async function addComment(request, response, { origin }) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const id = String(body.model || "");
  if (!ID.test(id)) throw new Unacceptable("name the model: model, its link's ten characters");
  const version = body.version === undefined || body.version === null ? null : Number(body.version);
  if (!Number.isInteger(version) || version < 1 || version > 100000) {
    throw new Unacceptable("say which version it is on: version, a number from 1");
  }
  const step = body.step === undefined || body.step === null || body.step === "" ? null : Number(body.step);
  if (step !== null && (!Number.isInteger(step) || step < 1 || step > 200000)) {
    throw new Unacceptable("step is a step's number, from 1, or none for the whole model");
  }
  const { text, trouble } = cleanComment(body.body);
  if (trouble) throw new Unacceptable(trouble);
  const made = await call("add_comment", { account: who, model_id: id, at_version: version, at_step: step, said: text },
    notYet);
  if (made?.refused) throw refused(made.refused);
  const versions = await versionsOf(id);
  const comment = commentSaid(made.comment, version, versions[0].n, versions);
  let told = { state: "none" };
  try {
    if (made.owner && made.owner !== who) {
      const sent = await sendCommentDigests({ origin, owner: made.owner });
      if (sent.digests[0]) told = { state: sent.digests[0].state, id: sent.digests[0].id };
    }
  } catch (problem) {
    // Kept, and told in the next: no reason to say the comment did not go.
    console.error(`comments: digest: ${String(problem?.message || problem).slice(0, 160)}`);
  }
  return response.status(201).json({ comment, ...(told.state === "dry" ? { told } : {}) });
}

/// A reply to a comment (supabase/replies.sql): on its comment's model,
/// version and step. The model's owner is told as of a comment
/// (sendCommentDigests); whoever is in the thread, by their notifications.
export async function addReply(request, response, { origin }) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const id = Number(body.id);
  if (!Number.isInteger(id) || id < 1) throw new Unacceptable("name the comment it answers: id, a number");
  const { text, trouble } = cleanComment(body.body);
  if (trouble) throw new Unacceptable(trouble);
  const made = await call("add_reply", { account: who, comment_id: id, said: text }, () => {
    throw new Unacceptable(REPLIES_NOT_YET, 503);
  });
  if (made?.refused) throw refused(made.refused);
  // As said on its own version, as a comment written there is.
  const versions = await versionsOf(made.model);
  const comment = commentSaid(made.comment, made.comment.version, versions[0].n, versions);
  let told = { state: "none" };
  try {
    if (made.owner && made.owner !== who) {
      const sent = await sendCommentDigests({ origin, owner: made.owner });
      if (sent.digests[0]) told = { state: sent.digests[0].state, id: sent.digests[0].id };
    }
  } catch (problem) {
    console.error(`comments: digest: ${String(problem?.message || problem).slice(0, 160)}`);
  }
  return response.status(201).json({ comment, ...(told.state === "dry" ? { told } : {}) });
}

export async function changeComment(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const id = Number(body.id);
  if (!Number.isInteger(id) || id < 1) throw new Unacceptable("name the comment: id, a number");
  const what = String(body.what || "");
  if (!["edit", "remove", "hide", "show"].includes(what)) throw new Unacceptable("what is edit, remove, hide or show");
  let text = null;
  if (what === "edit") {
    const clean = cleanComment(body.body);
    if (clean.trouble) throw new Unacceptable(clean.trouble);
    text = clean.text;
  }
  const changed = await call("change_comment", { account: who, comment_id: id, what, said: text }, notYet);
  if (changed?.refused) throw refused(changed.refused);
  // As said on its own version: a page that shows it on another asks the
  // list again.
  const one = changed.comment;
  return response.status(200).json({ removed: changed.removed === true,
    comment: commentSaid(one, one.version, one.version, [{ n: one.version, steps: null, first_changed: null }]) });
}

export async function setCommentsOpen(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const id = String(request.query?.id || "");
  if (!ID.test(id)) throw new Unacceptable("name a link: ?id=<ten characters>");
  const open = request.body?.open;
  if (typeof open !== "boolean") throw new Unacceptable("say open: true or open: false");
  const set = await call("set_comments", { account: who, model_id: id, open }, notYet);
  if (set?.refused) throw refused(set.refused);
  return response.status(200).json({ id, open: set.open === true });
}

/// The kinds the daily email can tell of: comments on the caller's models
/// (comments.sql), and since follows.sql the feed's (api/_follows.js).
export const MAIL_KINDS = ["comments", "models", "versions", "photos", "remixes"];

/// What the caller wants emailed: {comments, models, versions, photos,
/// remixes, ready, kinds}. All off until they say. [chosen] ({kind: true or
/// false}) is kept first. Before follows.sql only comments can be chosen
/// (kinds false), and before comments.sql nothing (ready false).
export async function mailChoice(who, chosen = null) {
  const asked = chosen && Object.keys(chosen).length ? chosen : null;
  const kinds = await call("mail_kinds", { account: who, chosen: asked }, () => null);
  if (kinds) return { ...Object.fromEntries(MAIL_KINDS.map((kind) => [kind, kinds[kind] === true])), ready: true, kinds: true };
  if (asked && Object.keys(asked).some((kind) => kind !== "comments")) {
    throw new Unacceptable("Email of the feed is not open on Brickworks yet.", 503);
  }
  const said = await call("mail_choice", { account: who, comments: asked ? asked.comments : null },
    () => ({ comments: false, missing: true }));
  return { ...Object.fromEntries(MAIL_KINDS.map((kind) => [kind, kind === "comments" && said?.comments === true])),
    ready: !said?.missing, kinds: false };
}

export async function chooseMail(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const who = await account(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const chosen = {};
  for (const [kind, on] of Object.entries(body)) {
    if (!MAIL_KINDS.includes(kind)) throw new Unacceptable(`say any of ${MAIL_KINDS.join(", ")}, each true or false`);
    if (typeof on !== "boolean") throw new Unacceptable(`say ${kind}: true or ${kind}: false`);
    chosen[kind] = on;
  }
  if (Object.keys(chosen).length === 0) throw new Unacceptable("say comments: true or comments: false");
  const said = await mailChoice(who, chosen);
  if (!said.ready) throw new Unacceptable(NOT_YET, 503);
  return response.status(200).json(Object.fromEntries(MAIL_KINDS.map((kind) => [kind, said[kind]])));
}

/// The model a comment anybody may report is on, or null.
export async function commentModel(id) {
  if (!Number.isInteger(id) || id < 1) return null;
  return call("comment_model", { comment_id: id }, () => null);
}

// ---------------------------------------------------------------------------
// Telling a model's owner, at most once a day.

const SENDER = "Brickworks <noreply@brickworks.diy>";
const escape = (text) => String(text ?? "").replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
function short(text, most) {
  const line = String(text ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim();
  return line.length > most ? `${line.slice(0, most - 1)}…` : line;
}

/// The email for a digest ({comments, more, feed, feed_more}): {subject,
/// text, html}. Each comment's model, where it was said, by whom, its first
/// words, and a link to it on the model's page; then each row of the feed
/// of the kinds chosen (follows.sql), in the words the feed says it, with
/// its link.
export function renderCommentDigest(digest, origin) {
  const comments = Array.isArray(digest?.comments) ? digest.comments : [];
  const feed = (Array.isArray(digest?.feed) ? digest.feed : []).map((row) => feedSaid(row, origin));
  const n = comments.length;
  const m = feed.length;
  const more = Number(digest?.more) || 0;
  const feedMore = Number(digest?.feed_more) || 0;
  const things = (k) => (k === 1 ? "something new" : `${k} new things`);
  const subject = m === 0
    ? (n === 1 ? "Brickworks: a comment on your model" : `Brickworks: ${n} comments on your models`)
    : n === 0 ? `Brickworks: ${things(m)} in your feed`
      : `Brickworks: ${count(n, "comment")} on your models, and ${things(m)} in your feed`;
  const items = comments.map((one) => ({
    name: short(one.name || "your model", 80),
    where: one.step ? `step ${one.step} of version ${one.version}` : `version ${one.version}`,
    by: one.by ? short(one.by, 40) : "a builder",
    body: short(one.body, 280),
    link: `${origin}/m/${one.model}#comment-${one.id}`,
  }));
  const since = n === 0 ? "" : n === 1 ? "Somebody commented on a model you shared." : `${count(n, "comment")} on models you shared.`;
  const behind = more ? `${more} more wait for tomorrow's email.` : "";
  const feedHead = m === 0 ? "" : "In your feed since the last email:";
  const feedBehind = feedMore ? `${feedMore} more are in your feed: ${origin}/feed` : "";
  const off = `You asked for these at ${origin}/profile, at most one a day. Turn them off there.`;
  const line = (row) => `${row.who} ${row.did} “${row.name}”${row.said ? `: “${row.said}”` : ""}`;
  const text = [...(since ? [since, ""] : []),
    ...items.flatMap((item, at) => [`${at + 1}. “${item.name}”, on ${item.where}, by ${item.by}:`,
      `   “${item.body}”`, `   ${item.link}`, ""]),
    ...(behind ? [behind, ""] : []),
    ...(feedHead ? [feedHead, ""] : []),
    ...feed.flatMap((row) => [`- ${line(row)}`, `  ${row.link}`, ""]),
    ...(feedBehind ? [feedBehind, ""] : []), off].join("\n");
  const html = `<!doctype html>
<div style="font:15px/1.55 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;color:#14181d;max-width:560px;margin:0 auto;padding:24px 20px">
  <p style="margin:0 0 16px;font-size:14px;color:#5b6472">Brickworks</p>
  ${since ? `<p style="margin:0 0 18px">${escape(since)}</p>` : ""}
  ${items.map((item) => `<div style="margin:0 0 16px;padding:12px 14px;border:1px solid #d9dee5;border-radius:8px">
    <p style="margin:0 0 4px"><b>${escape(item.name)}</b>, on ${escape(item.where)}, by ${escape(item.by)}</p>
    <p style="margin:0 0 8px">“${escape(item.body)}”</p>
    <p style="margin:0"><a href="${escape(item.link)}">See it on the model's page</a></p>
  </div>`).join("\n  ")}
  ${behind ? `<p style="margin:0 0 12px">${escape(behind)}</p>` : ""}
  ${feedHead ? `<p style="margin:8px 0 12px"><b>${escape(feedHead)}</b></p>` : ""}
  ${feed.map((row) => `<div style="margin:0 0 12px;padding:10px 14px;border:1px solid #d9dee5;border-radius:8px">
    <p style="margin:0 0 4px">${escape(row.who)} ${escape(row.did)} <b>${escape(row.name)}</b></p>
    ${row.said ? `<p style="margin:0 0 6px">“${escape(row.said)}”</p>` : ""}
    <p style="margin:0"><a href="${escape(row.link)}">See it</a></p>
  </div>`).join("\n  ")}
  ${feedBehind ? `<p style="margin:0 0 12px">${escape(feedBehind)}</p>` : ""}
  <p style="margin:0;color:#97a0ae;font-size:13px">${escape(off)}</p>
</div>`;
  return { subject, text, html };
}

/// Send the emails that are due: to [owner], or to every owner who chose
/// them (the hourly knock). A test account's is a dry run: rendered,
/// recorded, never sent. COMMENT_MAIL=off sends nothing to anybody, and
/// leaves what waits for a server that can. {digests: [{id, owner,
/// state}]}.
export async function sendCommentDigests({ origin, owner = null }) {
  const due = await call("claim_comment_digest", { for_owner: owner }, () => []);
  const done = [];
  for (const digest of Array.isArray(due) ? due : []) {
    const email = renderCommentDigest(digest, origin);
    const finish = (outcome) => db("rpc/finish_comment_digest", { method: "POST", body: {
      one: digest.digest, outcome, said_subject: email.subject, said_body: email.text, said_html: email.html } });
    if (digest.test === true || /@resend\.dev$/i.test(String(digest.email || ""))) {
      await finish("dry");
      done.push({ id: digest.digest, owner: digest.owner, state: "dry" });
      continue;
    }
    const key = process.env.RESEND_API_KEY;
    if (!digest.email || !key || process.env.COMMENT_MAIL === "off") {
      await finish("failed");
      done.push({ id: digest.digest, owner: digest.owner, state: "failed" });
      continue;
    }
    let sent = false;
    try {
      const reply = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
        body: JSON.stringify({ from: process.env.EMAIL_FROM || SENDER, to: [digest.email],
          subject: email.subject, html: email.html, text: email.text }),
        signal: AbortSignal.timeout(10000),
      });
      sent = reply.ok;
      if (!sent) console.error(`comments: Resend refused a digest: ${reply.status}`);
    } catch (problem) {
      console.error(`comments: a digest did not go: ${String(problem?.message || problem).slice(0, 160)}`);
    }
    await finish(sent ? "sent" : "failed");
    done.push({ id: digest.digest, owner: digest.owner, state: sent ? "sent" : "failed" });
  }
  return { digests: done };
}
