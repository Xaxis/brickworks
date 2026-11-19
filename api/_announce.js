// Announcements: the owner tells the site's people something (announce,
// 2026-11-18; docs/ANNOUNCE.md, docs/ADMIN.md, /admin › Announcements;
// supabase/announce.sql). The owner: "users have a notifications page; me
// in my admin panel should be able to send or trigger notifications".
//
// An announcement is a title, plain words and an optional link (this site's
// path, or https), for an audience: everyone, a plan, the beta's testers,
// people who signed up since a day, people who published, or one person by
// handle. It is written once, a row of its own, and each person it was sent
// to sees it on their Notifications page, through the rows that page and the
// avatar's count are read from (notification_rows), so it is counted, listed
// and marked read the way everything else there is (api/_notifications.js).
//
// Nothing goes without the owner's own press on its exact words: the review
// shows the words and their hash, the server's, and the press carries the
// hash and the version it was pressed on. Words changed since are refused;
// two presses make one send (the second finds it gone); a scheduled one
// edited is a draft again, its press forgotten (the social desk's pattern,
// api/_social.js). At most N go on one UTC day, N the owner's (Settings).
//
// On a preview, and with ?tests=1, every announcement is a test one: it
// reaches only the checks' own accounts (an address at resend.dev) and is
// never mailed. A preview shares the live database, so nothing written on one
// ever reaches a real person.
//
// Email, only when the announcement asks for it and only to those who asked
// for news by email (Settings › Email, off until they turn it on): a hundred
// a request through Resend's batch, paced well under its limit, each with a
// one-click unsubscribe (RFC 8058: List-Unsubscribe and List-Unsubscribe-Post)
// and the same link in its words. Sent by the cron (/api/plans/announce-due)
// and, for the first few hundred, at once after Send. The Resend team is
// shared: it also sends every site's sign-in codes, job.rip's among them.
// So news mail has a most a day, the owner's (200 until set), and a quota
// Resend says is used up stops it until the next UTC day; each take comes
// at least 1.1 s after the one before, from any instance, and not in the
// 1.5 s after this site's own code was asked for (supabase/announce2.sql).
// Only the site sends it (brickworks.diy): a preview's unreviewed code
// never mails, and its cron sends only the checks' own announcements.
//
//   GET  /api/admin?op=announce                 the desk: announcements, today's count, the limit
//   GET  /api/admin?op=announce_preview         a draft as people will see it, and who it reaches
//   POST /api/admin?op=announce_keep            a draft kept (a scheduled one edited: a draft again)
//   POST /api/admin?op=announce_send            the press: now, or at a time
//   POST /api/admin?op=announce_unschedule      a scheduled one back to the drafts
//   POST /api/admin?op=announce_edit            a sent one's words changed, marked edited
//   POST /api/admin?op=announce_withdraw        a sent one taken out of every list
//   POST /api/admin?op=announce_drop            a draft thrown away
//   POST /api/admin?op=announce_limit           the day's most
//   POST /api/admin?op=announce_mail_most       the most news mails a day
//   POST /api/admin?op=announce_mail_address    the postal address at a news mail's foot
//   GET  /api/plans?op=announce_due             the cron: what is due, and mail
//   POST /api/plans?op=notice_hide              (session) the site's notice hidden for this person
//   GET  /api/plans?op=notice_hidden&id=N       (session) whether they hid it
//   GET  /api/people?op=me                      .news: whether they asked for news by email
//   POST /api/people?op=news                    (session) {news: true | false}
//   POST /api/people?op=news_unsubscribe        a mail's one-click unsubscribe (a, t)
//   GET  /api/people?op=news_unsubscribe        the same opened in a browser: to Settings, whose
//                                               Unsubscribe button asks (a scanner that opens it changes nothing)

import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { scopeOf, setSetting, settingOf } from "./_settings.js";
import { admission, billingMode } from "./_billing.js";
import { framedMail, siteOrigin } from "./_beta.js";
import { cronNoted, isCron } from "./_cron.js";
import { noticeGroups } from "./_notifications.js";

const DAY = 864e5;
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const NOT_YET = "Not open yet: supabase/announce.sql is not applied.";
export const MOST_TITLE = 120;
export const MOST_BODY = 1000;
export const MOST_LINK = 500;
/// The day's most until the owner sets it (Settings).
export const MOST_A_DAY = 2;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const SENDER = "Brickworks <noreply@brickworks.diy>";
/// A batch is Resend's most (100); one at a time, at least 1.1 s apart from
/// any instance, as the take paces them (supabase/announce2.sql): Resend's
/// limit is per team, and the team sends for other sites too.
export const BATCH = 100;
/// A round's most batches: the cron's, and the one at once after Send.
const ROUND = 8;
const AT_ONCE = 2;
/// The most news mails a day until the owner sets it, and the most they may.
export const NEWS_A_DAY = 200;
export const MOST_NEWS_A_DAY = 10000;
/// The longest postal address a mail's foot shows (site_settings keeps 200).
export const MOST_ADDRESS = 200;
/// Resend's words for a quota used up: news stops until the next UTC day.
const QUOTA = /^(daily|monthly)_quota_exceeded$/;

/// The words a request carried, parsed.
function bodyOf(request) {
  if (typeof request.body !== "string") return request.body && typeof request.body === "object" ? request.body : {};
  try {
    return JSON.parse(request.body) || {};
  } catch {
    return {};
  }
}

/// Whether this request's announcements are the checks' own: with ?tests=1,
/// and always anywhere but brickworks.diy, since a preview shares its database.
export const testsOf = (request) => String(request.query?.tests || "") === "1" || scopeOf(request) !== "live";

/// [b]'s [key] as words: "" when it is not there, refused when it is
/// anything but a string (a list kept as "x,y" is never the owner's words).
function field(b, key) {
  const given = b?.[key];
  if (given === undefined || given === null) return "";
  if (typeof given !== "string") throw new AuthError(`${key} is to be words, not ${Array.isArray(given) ? "a list" : typeof given}.`, 400);
  return given;
}

/// [given] as the owner meant it: one form of each letter (NFC), every
/// space the keyboard can make a plain one, the invisible ones (zero-width,
/// joiners, a byte-order mark) gone, line ends as \n, control characters
/// out; [one] puts it on one line.
export function plain(given, one = false) {
  const words = String(given ?? "").normalize("NFC")
    .replace(/[\u200b-\u200d\u2060\ufeff\u00ad]/g, "")
    .replace(/[\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000]/g, " ")
    .replace(/\r\n?|[\u2028\u2029\u0085]/g, "\n")
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "");
  if (one) return words.replace(/\s+/g, " ").trim();
  return words.split("\n").map((line) => line.replace(/[ \t]+/g, " ").trim()).join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

const lengthOf = (words) => [...words].length;

/// An announcement's words checked, never cut: {title, body, link}, or
/// refused (400) with what is wrong.
export function wordsOf(b) {
  const title = plain(field(b, "title"), true);
  const body = plain(field(b, "body"));
  const link = linkOf(field(b, "link"));
  if (!title) throw new AuthError("Give it a title.", 400);
  if (lengthOf(title) > MOST_TITLE) throw new AuthError(`The title is ${lengthOf(title)} characters: at most ${MOST_TITLE}.`, 400);
  if (lengthOf(body) > MOST_BODY) throw new AuthError(`The words are ${lengthOf(body)} characters: at most ${MOST_BODY}.`, 400);
  return { title, body, link };
}

/// A link as it is kept: null for none; a path on this site (/gallery), or
/// an https address; anything else refused with words.
export function linkOf(given) {
  const typed = plain(given, true);
  if (!typed) return null;
  if (lengthOf(typed) > MOST_LINK) throw new AuthError(`The link is ${lengthOf(typed)} characters: at most ${MOST_LINK}.`, 400);
  if (/[\s<>"]/.test(typed)) throw new AuthError("A link has no spaces, < > or \" in it.", 400);
  if (typed.startsWith("/")) {
    if (/^\/[/\\]/.test(typed)) throw new AuthError("A link on this site starts with one /: /gallery, /challenge.", 400);
    return typed;
  }
  let url;
  try {
    url = new URL(typed);
  } catch {
    throw new AuthError("A link is a path on this site (/gallery) or an address starting https://.", 400);
  }
  if (url.protocol !== "https:" || !url.hostname) {
    throw new AuthError("A link is a path on this site (/gallery) or an address starting https://.", 400);
  }
  if (url.username || url.password) throw new AuthError("A link with a name or a password in it is refused.", 400);
  const kept = url.href;
  if (lengthOf(kept) > MOST_LINK || /[\s<>"]/.test(kept)) throw new AuthError("That link cannot be kept as it is.", 400);
  return kept;
}

/// The plans the audience may name, while billing is on: [{key, name,
/// default}], or null while it is off (every account has every feature).
async function plansOf() {
  if (billingMode() === "off") return null;
  try {
    const catalog = await admission().plans();
    return (catalog?.plans || []).filter((one) => one?.key && one.status !== "retired")
      .map((one) => ({ key: String(one.key), name: String(one.name || one.key), default: one.isDefault === true }));
  } catch {
    return [];
  }
}

/// Who it is for, as typed: one of the six, checked, as it is kept.
export async function audienceOf(given, now = Date.now()) {
  if (!given || typeof given !== "object" || Array.isArray(given)) throw new AuthError("Choose who it is for.", 400);
  const kind = typeof given.kind === "string" ? given.kind : "";
  if (kind === "everyone" || kind === "beta" || kind === "published") return { kind };
  if (kind === "since") {
    const at = typeof given.since === "string" ? Date.parse(given.since) : NaN;
    if (!Number.isFinite(at)) throw new AuthError("Choose the day they signed up from.", 400);
    if (at > now) throw new AuthError("That day has not come yet: nobody has signed up since.", 400);
    if (at < Date.parse("2024-01-01T00:00:00Z")) throw new AuthError("Brickworks had nobody before 2024: choose a later day.", 400);
    return { kind, since: new Date(at).toISOString() };
  }
  if (kind === "person") {
    const handle = plain(typeof given.handle === "string" ? given.handle : "", true).toLowerCase().replace(/^@/, "");
    if (!HANDLE.test(handle) || handle.includes("--")) throw new AuthError("Name the person by their handle, as in brickworks.diy/u/handle.", 400);
    return { kind, handle };
  }
  if (kind === "plan") {
    const plans = await plansOf();
    if (plans === null) throw new AuthError("Billing is off here: every account has every feature, so there is no plan to choose.", 400);
    const plan = plans.find((one) => one.key === given.plan);
    if (!plan) throw new AuthError("Choose one of the plans Admission lists.", 400);
    return { kind, plan: plan.key, mode: billingMode() === "live" ? "live" : "test", default: plan.default };
  }
  throw new AuthError("Choose who it is for: everyone, a plan, the beta's testers, those who signed up since a day, "
    + "those who published, or one person.", 400);
}

/// The hash of what goes, exactly: what a press is on.
export function hashOf(row) {
  return createHash("sha256").update(JSON.stringify([row.test === true, row.title ?? "", row.body ?? "", row.link ?? null,
    row.audience ?? null, row.email === true])).digest("hex");
}

/// An rpc of announce.sql's, its absence said once, the same way.
async function rpc(name, body) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (notYet(trouble)) throw new AuthError(NOT_YET, 503);
    throw trouble;
  }
}

/// An announcement as the console shows it: its row with the hash a press is on.
function view(row) {
  return row ? { ...row, hash: hashOf(row) } : null;
}

async function oneOf(id, tests) {
  if (!Number.isSafeInteger(id) || id < 1) throw new AuthError("Say which announcement, by its number.", 400);
  const row = await rpc("announce_one", { p_id: id, p_test: tests });
  if (!row) throw new AuthError("There is no such announcement here.", 404);
  return row;
}

const REFUSED = {
  nobody: [404, "There is no such announcement here."],
  gone: [409, "It has gone already: look under Sent."],
  changed: [409, "It changed since you looked: look at it again, then press."],
  pressed: [409, "These are not the words that were pressed: it was not sent."],
  sign_in: [401, "Sign in first."],
};
function refusal(said) {
  const [status, words] = REFUSED[said?.refused] || [409, "That did not go."];
  return new AuthError(words, status);
}

/// What the day's limit says, refused.
const limitWords = (said) => `Today's most is ${said.most} (${said.sent} sent, ${said.scheduled} scheduled for today). `
  + "Schedule it for another day, or raise the most under Settings.";

/// The owner's most a day for this site: a whole number, 1 to 20.
async function mostOf(request) {
  const kept = await settingOf("announce_limit", request).catch(() => null);
  const n = Number(kept?.value);
  return { most: Number.isInteger(n) && n >= 1 && n <= 20 ? n : MOST_A_DAY, set_by: kept?.set_by ?? null, set_at: kept?.set_at ?? null };
}

/// How the audience reads, for the audit and the console's lists.
export function audienceSaid(audience) {
  switch (audience?.kind) {
    case "everyone": return "everyone";
    case "plan": return `on ${audience.plan}`;
    case "beta": return "the beta's testers";
    case "since": return `signed up since ${String(audience.since || "").slice(0, 10)}`;
    case "published": return "who published";
    case "person": return `@${audience.handle}`;
    default: return "nobody";
  }
}

// ---------------------------------------------------------------------------
// The console's reads.

/// GET /api/admin?op=announce.
export async function announceRead(request) {
  const tests = testsOf(request);
  const scope = scopeOf(request);
  let list;
  try {
    // A test one's of this deployment only, as its day's count is.
    list = await db("rpc/announce_list", { method: "POST", body: { p_test: tests, p_limit: 100, p_scope: tests ? scope : null } });
  } catch (trouble) {
    if (notYet(trouble)) return { ready: false, said: NOT_YET, test: tests, scope };
    throw trouble;
  }
  const [most, today, plans, banner, news, address] = await Promise.all([
    mostOf(request),
    rpc("announce_day", { p_test: tests, p_day: new Date().toISOString(), p_scope: tests ? scope : null }),
    plansOf(),
    db("rpc/site_notice", { method: "POST", body: { p_scope: scope } }).catch(() => null),
    // Before announce2.sql: no most, no stop, said so.
    db("rpc/news_mail_state", { method: "POST", body: { p_scope: scope } }).catch(() => null),
    addressOf(scope),
  ]);
  return { ready: true, test: tests, scope, preview: scope !== "live", ...most, today, plans, billing: billingMode(),
    banner, mail: mailReady(), mail_missing: mailMissing(), news_mail: news, address, announcements: (list || []).map(view) };
}

/// A draft as its people will see it, from the same code their page is
/// drawn by: {group, count, mail}, or {refused} with the words of what is
/// wrong (a preview is asked as the owner types, so it never fails).
async function looked(b, tests) {
  const words = wordsOf(b);
  const row = { kind: "announcement", at: new Date().toISOString(), on: null, announcement: Number(b.id) || 0,
    title: words.title, said: words.body, link: words.link, edited: false, read: false };
  const { groups } = noticeGroups({ rows: [row], seen_at: null, read_at: null }, "");
  let count = null;
  let refused = null;
  try {
    const audience = await audienceOf(b.audience);
    count = await rpc("announce_count", { p_audience: audience, p_test: tests });
  } catch (trouble) {
    if (!(trouble instanceof AuthError) || trouble.status >= 500) throw trouble;
    refused = trouble.message;
  }
  return { group: groups[0] || null, words, count: count ? Number(count.count) || 0 : null,
    mail: count && b.email === true ? Number(count.mail) || 0 : 0, refused };
}

/// GET /api/admin?op=announce_preview&words=<json>.
export async function announcePreview(request) {
  let b = {};
  try {
    b = JSON.parse(String(request.query?.words || "{}")) || {};
  } catch {
    throw new AuthError("words is to be JSON.", 400);
  }
  try {
    return { test: testsOf(request), ...(await looked(b, testsOf(request))) };
  } catch (trouble) {
    if (trouble instanceof AuthError && trouble.status === 400) return { test: testsOf(request), refused: trouble.message, group: null, count: null };
    throw trouble;
  }
}

// ---------------------------------------------------------------------------
// The owner's acts.

/// POST op=announce_keep {id?, title, body, link, audience, email}: kept as
/// a draft; a scheduled one is a draft again (outcome unscheduled).
export async function announceKeep(request, response, claims) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const words = wordsOf(b);
  const audience = await audienceOf(b.audience);
  if (b.email !== undefined && b.email !== null && typeof b.email !== "boolean") throw new AuthError("email is true or false.", 400);
  const id = b.id === undefined || b.id === null || b.id === "" ? null : Number(b.id);
  if (id !== null && (!Number.isSafeInteger(id) || id < 1)) throw new AuthError("Say which announcement, by its number.", 400);
  const said = await rpc("announce_keep", { p_id: id, p_test: tests, p_title: words.title, p_body: words.body, p_link: words.link,
    p_audience: audience, p_email: tests ? false : b.email === true, p_by: String(claims?.email || "the owner").slice(0, 320),
    p_scope: tests ? scopeOf(request) : null });
  if (said?.refused) throw refusal(said);
  const row = said.announcement;
  return response.status(200).json({ outcome: said.was === "scheduled" ? "unscheduled" : id ? "kept" : "made",
    announcement: view(row), test: tests, audience_said: audienceSaid(audience), was: said.was ?? null });
}

/// POST op=announce_send {id, hash, changed_at, at?}: the owner's press on
/// the words whose hash they saw, as they were when they saw them; now, or
/// at [at] (a minute to 60 days ahead).
export async function announceSend(request, response, claims) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const row = await oneOf(Number(b.id), tests);
  const hash = field(b, "hash");
  if (!["draft", "scheduled"].includes(row.status)) throw new AuthError(REFUSED.gone[1], 409);
  if (hash !== hashOf(row)) {
    throw new AuthError("These are not the words you pressed Send on: they changed since. Look again and press Send.", 409);
  }
  const changed = field(b, "changed_at");
  if (!changed) throw new AuthError("Say which version you pressed on (changed_at).", 400);
  let at = null;
  const when = field(b, "at");
  if (when) {
    const t = Date.parse(when);
    if (!Number.isFinite(t) || t < Date.now() + 60000 || t > Date.now() + 60 * DAY) {
      throw new AuthError("Schedule it at least a minute from now and within 60 days.", 400);
    }
    at = new Date(t).toISOString();
  }
  const reach = await rpc("announce_count", { p_audience: row.audience, p_test: tests });
  if (!at && !(Number(reach?.count) > 0)) throw new AuthError(`Nobody is ${audienceSaid(row.audience)} now: there is nobody to send it to.`, 409);
  const { most } = await mostOf(request);
  const said = await rpc("announce_press", { p_id: row.id, p_test: tests, p_changed: changed,
    p_by: String(claims?.email || "the owner").slice(0, 320), p_hash: hash, p_at: at, p_most: most });
  if (said?.refused === "limit") throw new AuthError(limitWords(said), 409);
  if (said?.refused) throw refusal(said);
  const after = said.announcement;
  let mail = null;
  if (!at && after.email && !after.test) mail = await mailRound(after.id, AT_ONCE).catch(() => null);
  return response.status(200).json({ outcome: at ? "scheduled" : "sent", announcement: view(after), reach: after.reach ?? null,
    test: tests, audience_said: audienceSaid(after.audience), mail });
}

/// POST op=announce_unschedule {id}.
export async function announceUnschedule(request, response) {
  const tests = testsOf(request);
  const row = await oneOf(Number(bodyOf(request).id), tests);
  const said = await rpc("announce_unschedule", { p_id: row.id, p_test: tests, p_said: null });
  if (said?.refused) throw refusal(said);
  return response.status(200).json({ outcome: "unscheduled", announcement: view(said.announcement), test: tests });
}

/// POST op=announce_edit {id, changed_at, title, body, link, hash?}: a sent
/// one's words changed. Without [hash]: what it would be, and the hash of
/// that, changing nothing; with it, changed for everybody, marked edited.
export async function announceEdit(request, response) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const row = await oneOf(Number(b.id), tests);
  if (row.status !== "sent") throw new AuthError("Only one that was sent is edited: change a draft and keep it.", 409);
  const words = wordsOf(b);
  const next = { ...row, ...words };
  const hash = field(b, "hash");
  if (!hash) {
    const { groups } = noticeGroups({ rows: [{ kind: "announcement", at: row.sent_at, on: null, announcement: row.id,
      title: words.title, said: words.body, link: words.link, edited: true, read: false }], seen_at: null, read_at: null }, "");
    return response.status(200).json({ outcome: "looked", hash: hashOf(next), group: groups[0] || null, test: tests });
  }
  if (hash !== hashOf(next)) throw new AuthError("These are not the words you looked at: look again, then press.", 409);
  const said = await rpc("announce_edit", { p_id: row.id, p_test: tests, p_changed: field(b, "changed_at") || null,
    p_title: words.title, p_body: words.body, p_link: words.link });
  if (said?.refused) throw refusal(said);
  return response.status(200).json({ outcome: "edited", announcement: view(said.announcement), test: tests });
}

/// POST op=announce_withdraw {id}: gone from every person's Notifications.
export async function announceWithdraw(request, response, claims) {
  const tests = testsOf(request);
  const row = await oneOf(Number(bodyOf(request).id), tests);
  const said = await rpc("announce_withdraw", { p_id: row.id, p_test: tests, p_by: String(claims?.email || "the owner").slice(0, 320) });
  if (said?.refused) throw refusal(said);
  return response.status(200).json({ outcome: "withdrawn", announcement: view(said.announcement), reach: row.reach ?? null, test: tests });
}

/// POST op=announce_drop {id}: a draft thrown away.
export async function announceDrop(request, response) {
  const tests = testsOf(request);
  const row = await oneOf(Number(bodyOf(request).id), tests);
  const said = await rpc("announce_drop", { p_id: row.id, p_test: tests });
  if (said?.refused) throw refusal(said);
  return response.status(200).json({ outcome: "dropped", removed: row.id, test: tests });
}

/// POST op=announce_limit {most}: at most this many a UTC day, 1 to 20.
export async function announceLimit(request, response, claims) {
  const most = bodyOf(request).most;
  if (!Number.isInteger(most) || most < 1 || most > 20) throw new AuthError("The most a day is a whole number from 1 to 20.", 400);
  const made = await setSetting("announce_limit", String(most), request, claims?.email);
  return response.status(200).json({ value: Number(made.value), scope: made.scope, was: made.was ?? null, test: testsOf(request) });
}

/// POST op=announce_mail_most {most}: at most this many news mails a UTC
/// day, 0 to 10,000 (0: none). Counted from the mail kept today, inside the
/// take (announce2.sql), so no round, instance or retry goes past it.
export async function announceMailMost(request, response, claims) {
  const most = bodyOf(request).most;
  if (!Number.isInteger(most) || most < 0 || most > MOST_NEWS_A_DAY) {
    throw new AuthError(`The most news mails a day is a whole number from 0 to ${MOST_NEWS_A_DAY.toLocaleString("en-US")}.`, 400);
  }
  const made = await setSetting("news_mail_most", String(most), request, claims?.email);
  return response.status(200).json({ value: Number(made.value), scope: made.scope, was: made.was ?? null, test: testsOf(request) });
}

/// POST op=announce_mail_address {address}: the postal address a news
/// mail's foot shows, up to four lines; "" for none.
export async function announceMailAddress(request, response, claims) {
  const typed = field(bodyOf(request), "address");
  const address = plain(typed).split("\n").map((line) => line.trim()).filter(Boolean).join("\n");
  if (lengthOf(address) > MOST_ADDRESS) throw new AuthError(`The address is ${lengthOf(address)} characters: at most ${MOST_ADDRESS}.`, 400);
  if (address.split("\n").length > 4) throw new AuthError("An address is at most four lines.", 400);
  // site_settings keeps no empty value: none is kept as one space.
  const made = await setSetting("news_mail_address", address || " ", request, claims?.email);
  return response.status(200).json({ value: made.value.trim(), scope: made.scope, was: made.was?.trim() ?? null, test: testsOf(request) });
}

/// The postal address the owner gave for [scope]'s news mail, or "".
async function addressOf(scope) {
  const kept = await db("rpc/site_setting", { method: "POST", body: { p_name: "news_mail_address", p_scope: scope } }).catch(() => null);
  return String(kept?.value || "").trim();
}

// ---------------------------------------------------------------------------
// The cron: what is due, and mail.

/// One run: each scheduled one whose time came sent, if its words are still
/// those pressed; then the mail of those sent, a round of batches. Only the
/// site (brickworks.diy) sends the site's own and mails: anywhere else (a
/// preview's code, which nobody reviewed yet, or this machine) it sends
/// only the checks' own announcements, and mails nobody.
export async function announceDue(request) {
  const live = scopeOf(request) === "live";
  let due;
  try {
    due = await db("rpc/announce_due", { method: "POST", body: {} });
  } catch (trouble) {
    if (notYet(trouble)) return { outcome: "not_applied", sent: 0, held: 0, mailed: 0 };
    throw trouble;
  }
  let sent = 0;
  let held = 0;
  for (const row of due || []) {
    if (!live && row.test !== true) continue;
    const ok = row.pressed_hash && row.pressed_hash === hashOf(row);
    // The day's limit was counted as it was pressed (scheduled ones count).
    const said = ok ? await db("rpc/announce_press", { method: "POST", body: { p_id: row.id, p_test: row.test,
      p_changed: row.changed_at, p_by: "the schedule", p_hash: row.pressed_hash, p_at: null, p_most: 1000 } }) : { refused: "pressed" };
    if (said?.announcement?.status === "sent") {
      sent += 1;
      await noted(request, "announce_send", row, 200, { outcome: "sent", reach: said.announcement.reach });
    } else if (said?.refused === "gone") {
      // Another run, at the same moment, sent it: nothing to do or say.
      continue;
    } else {
      held += 1;
      const why = said?.refused === "pressed" ? "Its words are not those pressed: not sent." : "It could not be sent at its time.";
      await db("rpc/announce_unschedule", { method: "POST", body: { p_id: row.id, p_test: row.test, p_said: why } }).catch(() => null);
      await noted(request, "announce_send", row, 409, { outcome: "held", refused: said?.refused || "failed" }, why);
    }
  }
  let mailed = 0;
  let batches = 0;
  const mailing = live ? await db("rpc/announce_mail_due", { method: "POST", body: {} }).catch(() => []) : [];
  let stopped = null;
  for (const id of mailing || []) {
    if (batches >= ROUND) break;
    const round = await mailRound(Number(id), ROUND - batches);
    mailed += round.sent;
    batches += round.batches;
    // Resend's quota is used: no other announcement's mail is tried today.
    if (round.stopped) {
      stopped = round.stopped;
      break;
    }
  }
  const outcome = sent || held || mailed ? `${sent} sent, ${held} held, ${mailed} mailed` : "nothing due";
  return { outcome: stopped ? `${outcome}; news mail stopped until ${stopped.until} (${stopped.why})` : outcome,
    sent, held, mailed, ...(stopped ? { stopped } : {}) };
}

/// The audit's line for what the schedule did on the owner's behalf.
async function noted(request, op, row, status, said, words = null) {
  await db("rpc/admin_audit_note", { method: "POST", body: { p_actor: "the schedule", p_account: null, p_op: op,
    p_kind: "announcement", p_target: String(row.id), p_detail: { asked: { title: String(row.title || "").slice(0, 200) }, said },
    p_status: status, p_said: words, p_test: row.test === true, p_scope: scopeOf(request) } }).catch(() => null);
}

/// GET /api/plans?op=announce_due: Vercel's cron (/api/plans/announce-due,
/// four times an hour), with CRON_SECRET; written down when it did
/// something, and at the day's first run.
export async function announceDueRoute(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the announcements' schedule is the cron's" });
  const started = new Date().toISOString();
  let out;
  try {
    out = await announceDue(request);
  } catch (trouble) {
    const said = String(trouble?.message || trouble).slice(0, 200);
    console.error(`announce: due: ${said}`);
    await cronNoted(request, "announce_due", started, "failed", { error: said });
    return response.status(500).json({ error: "the due announcements stopped" });
  }
  const now = new Date();
  if (out.sent || out.held || out.mailed || (now.getUTCHours() === 0 && now.getUTCMinutes() < 15)
    || !/^vercel-cron\b/.test(String(request.headers?.["user-agent"] || ""))) {
    await cronNoted(request, "announce_due", started, out.held ? "failed" : "done", { outcome: out.outcome });
  }
  return response.status(200).json(out);
}

// ---------------------------------------------------------------------------
// Mail.

/// The key an unsubscribe link is signed with: a secret of its own
/// (NEWS_UNSUB_SECRET, set in Vercel), so no other key's rotation or leak
/// touches it. Until it is set nothing is mailed (mailReady).
const signing = () => process.env.NEWS_UNSUB_SECRET || "";
/// The key the first links were signed with (announce, SUPABASE_SECRET_KEY):
/// only ever checked, for a link already sent, never signed with again.
const signedBefore = () => (process.env.SUPABASE_SECRET_KEY ? `news-unsubscribe:${process.env.SUPABASE_SECRET_KEY}` : "");
const tokenWith = (key, account) => createHmac("sha256", key).update(String(account)).digest("base64url").slice(0, 32);

/// [account]'s unsubscribe token: only this server makes it, and it names
/// nothing but the account.
export function unsubscribeToken(account) {
  const key = signing();
  if (!key) throw new Error("NEWS_UNSUB_SECRET is not set: no unsubscribe link can be made");
  return tokenWith(key, account);
}

function tokenHolds(account, token) {
  if (!UUID.test(String(account)) || typeof token !== "string") return false;
  const given = Buffer.from(token);
  return [signing(), signedBefore()].filter(Boolean).some((key) => {
    const want = Buffer.from(tokenWith(key, account));
    return want.length === given.length && timingSafeEqual(want, given);
  });
}

/// What this deployment lacks to mail news: [] when it can.
export function mailMissing() {
  return [["RESEND_API_KEY", "a mail key"], ["NEWS_UNSUB_SECRET", "its unsubscribe secret"]]
    .filter(([name]) => !process.env[name]).map(([name, words]) => ({ name, words }));
}
const mailReady = () => mailMissing().length === 0;

/// Where [account] unsubscribes: the mail client's one click (POST, RFC
/// 8058), and the page a person opens from the mail's words.
export function unsubscribeLinks(account, origin = siteOrigin()) {
  const t = unsubscribeToken(account);
  return { post: `${origin}/api/people?op=news_unsubscribe&a=${account}&t=${t}`,
    page: `${origin}/settings?unsubscribe=${account}.${t}#email-part` };
}

const escaped = (text) => String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/// The mail of announcement [row] to [account]: its words, its link, how to
/// stop them, with the one-click headers, and the owner's postal address at
/// its foot when they gave one (/admin › Announcements › Settings).
export function announceMail(row, account, origin = siteOrigin(), address = "") {
  const links = unsubscribeLinks(account, origin);
  const link = row.link ? (row.link.startsWith("/") ? `${origin}${row.link}` : row.link) : `${origin}/notifications`;
  const mail = framedMail({ subject: row.title, paragraphs: [row.title, ...(row.body ? [row.body] : [])],
    action: { label: row.link ? "Open it" : "See it on Brickworks", href: link } }, origin);
  const why = "You get this because you asked for news from Brickworks by email (Settings, Email).";
  const lines = String(address || "").split("\n").map((line) => line.trim()).filter(Boolean);
  const foot = "font:13px/1.5 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;color:#5b6472;max-width:520px;"
    + "margin:8px auto 0;text-align:center";
  const html = mail.html.replace(/<\/div>\s*$/, `<p style="${foot}">${why} <a href="${links.page.replace(/&/g, "&amp;")}"`
    + ` style="color:#5b6472">Unsubscribe</a></p>\n${lines.length ? `<p style="${foot}">${lines.map(escaped).join("<br>")}</p>\n` : ""}</div>`);
  return { subject: row.title, text: `${mail.text}\n\n${why}\nUnsubscribe: ${links.page}\n${lines.length ? `\n${lines.join("\n")}\n` : ""}`,
    html, headers: { "List-Unsubscribe": `<${links.post}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" } };
}

/// The start of the next UTC day after [now].
const nextUtcDay = (now = Date.now()) => {
  const at = new Date(now);
  return new Date(Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), at.getUTCDate() + 1));
};

/// Up to [most] batches of announcement [id]'s mail sent: {sent, failed,
/// batches, stopped?}. Never throws on Resend's answer; each mail's state
/// kept. A quota Resend says is used up stops news mail until the next UTC
/// day ([stopped]); being too fast, or down, leaves the batch for a later
/// round.
export async function mailRound(id, most = ROUND) {
  const out = { sent: 0, failed: 0, batches: 0 };
  const row = await db("rpc/announce_one", { method: "POST", body: { p_id: id, p_test: false } }).catch(() => null);
  if (!row || row.status !== "sent" || !row.email || row.test) return out;
  // No key or no unsubscribe secret here: nobody is taken, so the mail goes
  // once both are set.
  const key = process.env.RESEND_API_KEY;
  if (!mailReady()) return { ...out, said: `no ${mailMissing().map((one) => one.name).join(" or ")} here` };
  const address = await addressOf("live");
  // The words in the key too: a batch Resend refused, taken again after an
  // edit, is new mail to it, never the same request with another body.
  const words = createHash("sha256").update(JSON.stringify([row.title, row.body, row.link])).digest("hex");
  for (let batch = 0; batch < most; batch += 1) {
    const taken = await db("rpc/announce_mail_take", { method: "POST", body: { p_id: id, p_limit: BATCH } });
    if (!Array.isArray(taken) || taken.length === 0) break;
    out.batches += 1;
    let results;
    {
      const mails = taken.map((one) => ({ from: process.env.EMAIL_FROM || SENDER, to: [one.email],
        ...announceMail(row, one.account, siteOrigin(), address), tags: [{ name: "kind", value: "announcement" }] }));
      const ids = createHash("sha256").update(`${words}:${taken.map((one) => one.account).join(",")}`).digest("hex").slice(0, 32);
      let reply = null;
      let said = null;
      try {
        reply = await fetch("https://api.resend.com/emails/batch", { method: "POST",
          headers: { authorization: `Bearer ${key}`, "content-type": "application/json", "idempotency-key": `announce-${id}-${ids}` },
          body: JSON.stringify(mails), signal: AbortSignal.timeout(20000) });
        said = await reply.json().catch(() => null);
      } catch (trouble) {
        console.error(`announce: mail ${id}: ${String(trouble?.message || trouble).slice(0, 120)}`);
      }
      const given = Array.isArray(said?.data) ? said.data : [];
      if (reply?.ok && given.length === taken.length) {
        results = taken.map((one, at) => ({ account: one.account, state: "sent",
          sent_id: /^[A-Za-z0-9_-]{1,100}$/.test(String(given[at]?.id || "")) ? given[at].id : null }));
      } else if (!reply || reply.status === 429 || reply.status >= 500) {
        // Refused before it took any: taken again by a later round.
        await db("rpc/announce_mail_done", { method: "POST", body: { p_id: id,
          p_results: taken.map((one) => ({ account: one.account, state: "again" })) } });
        const quota = reply?.status === 429 ? String(said?.name || said?.type || "") : "";
        if (QUOTA.test(quota)) {
          // The team's quota is used: news waits for the next UTC day, so
          // what is left of it goes to the sign-in codes.
          const until = nextUtcDay();
          await db("rpc/announce_mail_stop", { method: "POST", body: { p_until: until.toISOString(), p_why: quota } }).catch(() => null);
          out.stopped = { until: until.toISOString(), why: quota };
          console.error(`announce: mail ${id}: Resend said ${quota}; news mail stops until ${until.toISOString()}`);
        } else {
          console.error(`announce: mail ${id}: Resend said ${reply ? reply.status : "nothing"}; again later`);
        }
        break;
      } else {
        console.error(`announce: mail ${id}: Resend refused the batch: ${reply.status}`);
        results = taken.map((one) => ({ account: one.account, state: "failed", sent_id: null }));
      }
    }
    await db("rpc/announce_mail_done", { method: "POST", body: { p_id: id, p_results: results } });
    for (const one of results) out[one.state === "sent" ? "sent" : "failed"] += 1;
  }
  return out;
}

// ---------------------------------------------------------------------------
// A person's side: their news by email, and the site's notice hidden.

const accountOf = async (request) => {
  const access = bearer(request);
  if (!access) throw new AuthError("Sign in first: we email you a code, no password.", 401);
  return (await verify(access, request)).sub;
};

/// Whether [account] asked for news by email: {news, ready}; ready false
/// before announce.sql, and the choice is not offered.
export async function newsOf(account) {
  try {
    const said = await db("rpc/news_choice", { method: "POST", body: { p_account: account } });
    return { news: said?.news === true, ready: true };
  } catch (trouble) {
    if (notYet(trouble)) return { news: false, ready: false };
    throw trouble;
  }
}

/// POST /api/people?op=news {news: true | false}.
export async function chooseNews(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await accountOf(request);
  const news = bodyOf(request).news;
  if (typeof news !== "boolean") throw new AuthError("say news: true or news: false", 400);
  const said = await rpc("news_choice", { p_account: account, p_news: news, p_via: "settings" });
  if (said?.refused) throw new AuthError("Sign in again first.", 401);
  return response.status(200).json({ news: said.news === true });
}

/// The account and token an unsubscribe carries: in the address (the mail
/// client's one click) or the body (Settings, which asks for the person).
function unsubscribeOf(request) {
  const b = bodyOf(request);
  const q = request.query || {};
  const a = String(q.a ?? b.a ?? "").toLowerCase();
  const t = String(q.t ?? b.t ?? "");
  return { a, t };
}

/// POST /api/people?op=news_unsubscribe (a, t): no more news by email, at
/// once, with no sign-in and no redirect (RFC 8058). GET (the same link
/// opened in a browser) goes to Settings, which asks with a POST: a link
/// checker that only looks never unsubscribes anybody.
export async function newsUnsubscribe(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const { a, t } = unsubscribeOf(request);
  if (request.method === "GET" || request.method === "HEAD") {
    const to = tokenHolds(a, t) ? `/settings?unsubscribe=${a}.${t}#email-part` : "/settings#email-part";
    return response.status(303).setHeader("Location", to).end();
  }
  if (!tokenHolds(a, t)) return response.status(400).json({ error: "This unsubscribe link is not one of ours, or it was cut short." });
  const said = await rpc("news_choice", { p_account: a, p_news: false, p_via: "unsubscribe" });
  if (said?.refused) return response.status(404).json({ error: "That account is not here any more: it gets no mail." });
  return response.status(200).json({ news: false, unsubscribed: true });
}

/// [act] answered as the site's other routes are: a refusal in its words
/// and status, anything else said once and answered 502.
const answered = (act) => async (request, response) => {
  try {
    return await act(request, response);
  } catch (trouble) {
    if (trouble instanceof AuthError) return response.status(trouble.status).json({ error: trouble.message });
    console.error(`announce: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return response.status(502).json({ error: "That did not go just now. Try again in a minute." });
  }
};

/// POST /api/plans?op=notice_hide {id}: the site's notice hidden for this
/// person, in every browser they sign in on.
export const noticeHide = answered(async (request, response) => {
  response.setHeader("Cache-Control", "no-store");
  const account = await accountOf(request);
  const id = Number(bodyOf(request).id);
  if (!Number.isSafeInteger(id) || id < 1) throw new AuthError("say which notice: {id}", 400);
  const said = await rpc("site_notice_hide", { p_account: account, p_id: id });
  if (said?.refused) throw new AuthError("There is no such notice.", 404);
  return response.status(200).json({ hidden: true });
});

/// GET /api/plans?op=notice_hidden&id=N: whether this person hid it.
export const noticeHidden = answered(async (request, response) => {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await accountOf(request);
  const id = Number(request.query?.id);
  if (!Number.isSafeInteger(id) || id < 1) throw new AuthError("say which notice: ?id=N", 400);
  return response.status(200).json({ hidden: (await rpc("site_notice_hidden", { p_account: account, p_id: id })) === true });
});

/// A notice's end as the owner chose it: an ISO time a minute to a year
/// ahead, null for none, refused (400) otherwise.
export function noticeEnds(given, now = Date.now()) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string") throw new AuthError("ends is a time, as words.", 400);
  const at = Date.parse(given);
  if (!Number.isFinite(at)) throw new AuthError("Its end is not a time.", 400);
  if (at < now + 60000) throw new AuthError("Its end is to be at least a minute from now.", 400);
  if (at > now + 366 * DAY) throw new AuthError("Its end is to be within a year.", 400);
  return new Date(at).toISOString();
}

/// Notice [id] in [scope] ends at [ends] (null: until cleared): {ends_at},
/// or {ends_at: null, ends_said} before announce.sql.
export async function setNoticeEnds(scope, id, ends) {
  try {
    const said = await db("rpc/site_notice_ends", { method: "POST", body: { p_scope: scope, p_id: id, p_ends: ends } });
    if (said?.refused) return { ends_at: null, ends_said: said.refused === "past" ? "Its end had passed: it shows until cleared." : "It was not kept." };
    // One way of writing a time, whatever zone the database answered in.
    return { ends_at: said?.ends_at ? new Date(said.ends_at).toISOString() : null };
  } catch (trouble) {
    if (notYet(trouble)) return { ends_at: null, ends_said: "Its end is not kept yet: supabase/announce.sql is not applied." };
    throw trouble;
  }
}
