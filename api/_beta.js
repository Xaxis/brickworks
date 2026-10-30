// The beta: 100 testers, each given a month of Pro (beta361, 2026-10-29;
// supabase/beta.sql says how the spots are kept).
//
// The owner: "a 'beta tester' signup that lightly vets people so that we
// can say have a 'beta promotion' where say the first 100 beta/user
// signups get a free month". A month of Pro is 30 days of models kept
// with the account without a limit (Free keeps 25) and the desktop app.
//
// BRICKWORKS_BETA is the switch, read here (betaMode) and nowhere else:
// "open" takes applications on /beta; anything else (unset, production's
// until the owner says) is off, and /beta says it is coming, asks nothing
// of the database and takes nothing. The owner's queue and the daily run
// work either way: approved testers keep their month whatever the switch.
//
// Routes (each an op of an API file: Vercel's plan stops at 12 functions):
//
//   GET  /api/plans?op=beta        {beta: off} or {beta: open, pool, early,
//                                  test, application}: the spots left and,
//                                  signed in, where your application stands
//   POST /api/plans?op=beta        signed in, the form (applicationOf): 200
//                                  with the same, 401 signed out, 403 off,
//                                  409 applied already, 422 with why
//   GET  /api/plans?op=beta_spots  {beta: off} or {beta: open, cap, left}:
//                                  signed out, cached a minute, for the
//                                  pricing and home pages' callouts
//   GET  /api/plans?op=beta_daily  Vercel's cron (/api/plans/beta-daily):
//                                  months given that wait for Admission,
//                                  reminders three days before a month
//                                  ends, declined ones past 90 days erased,
//                                  and feedback's reports past their time
//                                  (api/_feedback.js sweepFeedback)
//   GET  /api/admin?op=beta        the owner's queue (api/admin.js gates it)
//   POST /api/admin?op=beta_decide&account=U   {decision, note}
//   POST /api/admin?op=beta_grant  every month still to give, given
//
// The vetting is light, and only ever advice: the server works out what
// the owner reads beside each application (signalsOf here, and what the
// database reads of the account in beta_queue) and decides nothing on it.
// No IP address is kept.
//
// The month is given at Admission (ADR-0015), by the product's own key,
// reason "beta", once per account ever: approveMonth, the one place. A real
// tester's month is given at approval while BRICKWORKS_BILLING is live; off
// or test, it waits, pending, and is given when Pro launches (grantDue,
// run by the daily cron or the owner's Grant pending months, and safe to
// run again). The checks' testers (accounts at resend.dev) are given
// theirs in Admission's test mode, so the call is proven there and never
// takes a live comp.
import { AdmissionError, AdmissionUnavailable } from "./_admission.js";
import { AuthError, bearer, verify } from "./_auth.js";
import { admission, billingMode } from "./_billing.js";
import { isCron } from "./_cron.js";
import { db, dbConfigured } from "./_db.js";
import { EARLY, KNOWN, NEW } from "./_early.js";

/// "open" or "off".
export function betaMode(env = process.env) {
  return String(env.BRICKWORKS_BETA || "").trim().toLowerCase() === "open" ? "open" : "off";
}

/// The version of the beta's terms an application agrees to (web/terms.html#beta).
export const TERMS = "2026-10-29";
export const DAYS = 30;
export const AI = Object.freeze({ claude: "Claude", chatgpt: "ChatGPT", own_key: "My own API key", not_sure: "Not sure yet" });
export const BACKGROUND = Object.freeze({ new: "New to both", lego: "I build LEGO® models", cad: "I use CAD",
  both: "Both" });
export const MOST = Object.freeze({ build: 800, line: 160, link: 300, note: 500 });
export const LEAST_BUILD = 20;
const ORANGECHECK_ADDRESS = /@oc\.brickworks\.diy$/i;
const DAY_MS = 86_400_000;

export class Refusal extends Error {
  constructor(status, message, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

// Words with nothing in them that lays text out or hides it: control
// characters and the marks that turn text around or join it unseen.
const UNSEEN = /[\u0000-\u0008\u000b-\u001f\u007f​-‏‪-‮⁠-⁩﻿]/g;

/// One line: its runs of space one space.
function line(raw) {
  return String(raw ?? "").replace(UNSEEN, " ").replace(/\s+/g, " ").trim();
}

/// A few lines: each line's runs of space one, at most one empty line between.
function lines(raw) {
  return String(raw ?? "").replace(/\r\n?/g, "\n").replace(UNSEEN, " ").split("\n")
    .map((one) => one.replace(/[ \t]+/g, " ").trim()).join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

/// A link someone gave, as kept: https, a host with a dot, no password,
/// at most MOST.link. Null for none; a Refusal for one that is not a link.
export function linkOf(raw) {
  const given = line(raw);
  if (given === "") return null;
  const said = "The link is a web address starting https://, like https://rebrickable.com/users/you/mocs/.";
  const written = /^[a-z][a-z0-9+.-]*:/i.test(given) ? given : `https://${given}`;
  let url;
  try {
    url = new URL(written);
  } catch {
    throw new Refusal(422, said);
  }
  if (url.protocol !== "https:" || url.username || url.password || !/^[a-z0-9.-]+\.[a-z]{2,}$/i.test(url.hostname)) {
    throw new Refusal(422, said);
  }
  const href = url.href;
  if (href.length > MOST.link) throw new Refusal(422, `The link is at most ${MOST.link} characters; that one is ${href.length}.`);
  return href;
}

/// What a POST to /api/plans?op=beta asks, checked at the edge: {build,
/// ai, background, background_line, link}, or a Refusal in words a
/// person can act on.
export function applicationOf(body) {
  if (!body || typeof body !== "object") throw new Refusal(422, "Fill in the form.");
  for (const field of ["build", "background_line", "link"]) {
    if (body[field] !== undefined && body[field] !== null && typeof body[field] !== "string") {
      throw new Refusal(422, "The form's answers are words.");
    }
  }
  const build = lines(body.build);
  if (build.length < LEAST_BUILD) {
    throw new Refusal(422, `Say what you would build, in a sentence or two: at least ${LEAST_BUILD} characters.`);
  }
  if (build.length > MOST.build) {
    throw new Refusal(422, `What you would build is at most ${MOST.build} characters; that is ${build.length}.`);
  }
  const ai = String(body.ai || "");
  if (!Object.hasOwn(AI, ai)) throw new Refusal(422, "Choose which AI you use: Claude, ChatGPT, your own key, or not sure.");
  const background = String(body.background || "");
  if (!Object.hasOwn(BACKGROUND, background)) throw new Refusal(422, "Choose your LEGO® or CAD background.");
  const backgroundLine = line(body.background_line);
  if (backgroundLine.length > MOST.line) {
    throw new Refusal(422, `The line about your background is at most ${MOST.line} characters; that is ${backgroundLine.length}.`);
  }
  const link = linkOf(body.link);
  if (body.terms !== true) throw new Refusal(422, "Tick the box to agree to the beta's terms.");
  if (body.emails !== true) throw new Refusal(422, "Tick the box to agree that we email you about the beta.");
  return { build, ai, background, background_line: backgroundLine, link };
}

/// Domains that hand out addresses that last minutes or hours: a small
/// list of the common ones, never complete. Advice to the owner, never a
/// refusal: somebody can have a reason.
export const DISPOSABLE = new Set([
  "10minutemail.com", "10minutemail.net", "20minutemail.com", "33mail.com", "anonaddy.me", "burnermail.io",
  "byom.de", "discard.email", "dispostable.com", "dropmail.me", "emailondeck.com", "fakeinbox.com", "fakemail.net",
  "getairmail.com", "getnada.com", "guerrillamail.biz", "guerrillamail.com", "guerrillamail.de", "guerrillamail.info",
  "guerrillamail.net", "guerrillamail.org", "guerrillamailblock.com", "harakirimail.com", "inboxkitten.com",
  "incognitomail.org", "jetable.org", "mail.tm", "mail-temp.com", "mailcatch.com", "maildrop.cc", "mailinator.com",
  "mailinator.net", "mailnesia.com", "mailpoof.com", "mintemail.com", "moakt.com", "mohmal.com", "mytemp.email",
  "nada.email", "sharklasers.com", "spam4.me", "spamgourmet.com", "spambox.us", "temp-mail.io", "temp-mail.org",
  "tempail.com", "tempinbox.com", "tempmail.dev", "tempmail.net", "tempmailo.com", "tempr.email", "throwawaymail.com",
  "trashmail.com", "trashmail.de", "trashmail.net", "yopmail.com", "yopmail.fr", "yopmail.net",
]);

export function domainOf(email) {
  return String(email || "").trim().toLowerCase().split("@").pop() || "";
}

/// Whether [email] is at a disposable domain, or a subdomain of one.
export function disposable(email) {
  const domain = domainOf(email);
  return [...DISPOSABLE].some((one) => domain === one || domain.endsWith(`.${one}`));
}

const MASH = /(asdf|qwer|zxcv|hjkl|jkl;|uiop|sdfg|dfgh|fghj|ghjk)/i;
const FILLER = /\b(lorem ipsum|test(ing)?|asdf|idk|nothing|n\/?a|none|stuff|things|whatever|blah)\b/i;

/// What the owner should know about how the form was filled in: {words,
/// issues}, each issue a few words. Junk is guessed, never decided.
export function qualityOf(app) {
  const build = String(app?.build || "");
  const words = build.toLowerCase().match(/[\p{L}\p{N}]+(?:['’][\p{L}]+)?/gu) || [];
  const distinct = new Set(words);
  const letters = (build.match(/\p{L}/gu) || []).length;
  const issues = [];
  if (words.length < 5) issues.push("very short");
  if (distinct.size > 0 && words.length >= 6 && distinct.size / words.length < 0.4) issues.push("the same words again and again");
  if (/(.)\1{4,}/u.test(build)) issues.push("a character repeated");
  if (MASH.test(build)) issues.push("keyboard mashing");
  if (build.length > 0 && letters / build.length < 0.5) issues.push("mostly not letters");
  if (words.length > 0 && words.length <= 8 && FILLER.test(build)) issues.push("filler words");
  if (/https?:\/\//i.test(build) && words.length < 12) issues.push("mostly a link");
  if (words.some((word) => word.length > 30 && !/^https?/.test(word))) issues.push("a very long word");
  return { words: words.length, issues };
}

/// What the server works out about an application as it is made, kept
/// with it for the owner: the domain, whether it is a disposable one, and
/// the form's quality. What changes with time (the account's age, its
/// models, another account at the same inbox) the database reads when
/// the owner looks (supabase/beta.sql beta_queue).
export function signalsOf(app, email) {
  return { domain: domainOf(email), disposable: disposable(email), quality: qualityOf(app) };
}

// ---------------------------------------------------------------------------
// The emails.

const SENDER = "Brickworks <noreply@brickworks.diy>";
const TEST_INBOX = /@resend\.dev$/i;
const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });

/// "29 October 2026", in UTC.
export function dayOf(iso) {
  const at = Date.parse(iso || "");
  return Number.isFinite(at) ? DAY.format(new Date(at)) : "";
}

const escape = (text) => String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;",
  "'": "&#39;" })[c]);

/// The site's address, for links in an email: production's, never a
/// preview's, so a person is never sent to one.
export function siteOrigin(env = process.env) {
  return String(env.PUBLIC_ORIGIN || "").replace(/\/+$/, "") || "https://brickworks.diy";
}

const WHAT = "30 days of Pro: any number of models kept with your account (Free keeps 25), and the desktop app for "
  + "Windows, macOS and Linux, which works with your AI exactly as the web app does, and with Claude Code too.";
const AFTER = "When the month ends you are back on Free. Nothing is charged, no card is asked for, and nothing is "
  + "deleted. If you have more than 25 models kept with your account then, you keep every one of them, but cannot "
  + "add new ones until you are under 25.";
const ASK = "What we ask: use it for real, on things you want to build, and tell us honestly what works and what does not.";

/// Each email the beta sends, as {subject, paragraphs, action}: [kind]
/// "received", "approved", "declined", "started" or "reminder", with
/// [data] (spot, cap, early, waitlist, starts, ends, again_at).
function wordsOf(kind, data, origin) {
  const spot = data.spot ? `spot ${data.spot} of ${data.cap || 100}` : "";
  const month = data.starts && data.ends ? `Your month runs from ${dayOf(data.starts)} to ${dayOf(data.ends)}.` : "";
  if (kind === "received") {
    return {
      subject: "We have your Brickworks beta application",
      paragraphs: [
        "Thank you for applying to the Brickworks beta. We read every application ourselves, and will email you "
          + "once we have decided.",
        ...(data.early ? ["Your account was made before 29 October 2026, so it has Pro already, free and with no end "
          + "date. You can still join as a tester; you would not take one of the 100 spots."] : []),
        ...(data.waitlist ? ["All 100 spots are taken just now, so your application is on the waitlist. If we open "
          + "more, it is read with the others."] : []),
        `What you told us is kept with your account and deleted with it: ${origin}/privacy#beta.`,
      ],
      action: { label: "See your application", href: `${origin}/beta#apply` },
    };
  }
  if (kind === "approved" && data.early) {
    return {
      subject: "You're in the Brickworks beta",
      paragraphs: [
        "You are a Brickworks beta tester. Your account was made before 29 October 2026, so it has Pro already, free "
          + "and with no end date, and you did not need one of the 100 spots.",
        ASK,
      ],
      action: { label: "Open Brickworks", href: `${origin}/app` },
    };
  }
  if (kind === "approved") {
    return {
      subject: `You're in: ${spot} in the Brickworks beta`,
      paragraphs: [
        `You have ${spot} in the Brickworks beta. What you get: ${WHAT}`,
        month || "Your month starts the day Pro launches, and runs 30 days from then. We will email you when it starts.",
        ASK,
        AFTER,
      ],
      action: month ? { label: "Download the desktop app", href: `${origin}/download` }
        : { label: "Open Brickworks", href: `${origin}/app` },
    };
  }
  if (kind === "started") {
    return {
      subject: "Your month of Brickworks Pro has started",
      paragraphs: [`Pro has launched, and your beta month with it (${spot}). ${month}`, `What you get: ${WHAT}`, AFTER],
      action: { label: "Download the desktop app", href: `${origin}/download` },
    };
  }
  if (kind === "reminder") {
    return {
      subject: "Three days left of your Brickworks beta month",
      paragraphs: [
        `Your month of Pro ends on ${dayOf(data.ends)}. Thank you for testing Brickworks.`,
        AFTER,
        `To keep Pro after it, it is $8 a month or $80 a year: ${origin}/plans. You do not have to do anything to go back to Free.`,
      ],
      action: { label: "See the plans", href: `${origin}/plans` },
    };
  }
  if (kind === "declined") {
    return {
      subject: "About your Brickworks beta application",
      paragraphs: [
        "Thank you for applying to the Brickworks beta. We cannot offer you a spot this time.",
        `Brickworks stays free in your browser, and you are welcome to apply again from ${dayOf(data.again_at)}.`,
      ],
      action: { label: "Open Brickworks", href: `${origin}/app` },
    };
  }
  throw new TypeError(`no beta email "${kind}"`);
}

/// The email of [kind], plain and in the site's look: {subject, text, html}.
export function renderMail(kind, data = {}, origin = siteOrigin(), replyTo = "") {
  return framedMail(wordsOf(kind, data, origin), origin, replyTo);
}

/// [words] ({subject, paragraphs, action: {label, href}}) as an email, plain
/// and in the site's look: {subject, text, html}. The feedback's answers
/// are written in it too (api/_feedback.js).
export function framedMail(words, origin = siteOrigin(), replyTo = "") {
  const paragraphs = [...words.paragraphs, ...(replyTo ? ["Reply to this email any time: it reaches us."] : [])];
  const text = [...paragraphs, "", `${words.action.label}: ${words.action.href}`, "", "Brickworks", origin].join("\n\n")
    .replace(/\n{3,}/g, "\n\n");
  const html = `<!doctype html>
<div style="background:#fbfbfa;padding:24px 12px">
<div style="font:16px/1.6 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;color:#14181d;max-width:520px;margin:0 auto;background:#ffffff;border:1px solid #e3e5e8;border-radius:14px;padding:28px 24px">
  <p style="margin:0 0 20px;font-weight:700;font-size:15px"><span style="display:inline-block;width:12px;height:12px;border-radius:3px;background:#ffcf00;margin-right:8px;vertical-align:-1px"></span>Brickworks</p>
  ${paragraphs.map((one) => `<p style="margin:0 0 16px;white-space:pre-line">${escape(one)}</p>`).join("\n  ")}
  <p style="margin:24px 0 8px"><a href="${escape(words.action.href)}" style="display:inline-block;background:#ffcf00;color:#14181d;font-weight:650;text-decoration:none;border-radius:10px;padding:11px 18px">${escape(words.action.label)}</a></p>
</div>
<p style="font:13px/1.5 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;color:#5b6472;max-width:520px;margin:12px auto 0;text-align:center">Brickworks · <a href="${escape(origin)}" style="color:#5b6472">${escape(origin.replace(/^https?:\/\//, ""))}</a></p>
</div>`;
  return { subject: words.subject, text, html };
}

/// [mail] ({subject, text, html}) sent to [email] through Resend, answers to
/// BETA_REPLY_TO when it is set: {state, id}: "sent" with Resend's id; "dry"
/// to a test inbox where this server has no mail key (a unit's preview:
/// tools/deploy.sh --unit), as it would have gone; "failed" otherwise, and
/// always for an orangecheck account's made-up address. Never throws.
export async function resend(email, mail, what = "email") {
  const replyTo = String(process.env.BETA_REPLY_TO || "").trim();
  const key = process.env.RESEND_API_KEY;
  if (!email || ORANGECHECK_ADDRESS.test(email)) return { state: "failed", id: null };
  if (!key) return { state: TEST_INBOX.test(email) ? "dry" : "failed", id: null };
  try {
    const reply = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ from: process.env.EMAIL_FROM || SENDER, to: [email], subject: mail.subject,
        text: mail.text, html: mail.html, ...(replyTo ? { reply_to: replyTo } : {}) }),
      signal: AbortSignal.timeout(10000),
    });
    const said = await reply.json().catch(() => ({}));
    if (reply.ok && typeof said?.id === "string") return { state: "sent", id: said.id };
    console.error(`beta: Resend refused the ${what}: ${reply.status}`);
  } catch (trouble) {
    console.error(`beta: the ${what} did not go: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  return { state: "failed", id: null };
}

/// The email of [kind] sent to [to] ({account, email}), and kept
/// (beta_mail), as resend says it went. Never throws.
export async function sendMail(kind, to, data) {
  const replyTo = String(process.env.BETA_REPLY_TO || "").trim();
  const mail = renderMail(kind, data, siteOrigin(), replyTo);
  const { state, id } = await resend(to?.email, mail, `${kind} email`);
  try {
    await db("rpc/beta_mail_note", { method: "POST", body: { p_account: to.account, p_kind: kind, p_state: state,
      p_sent_id: id, p_subject: mail.subject } });
  } catch (trouble) {
    console.error(`beta: the ${kind} email was not kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
  return { state, id, subject: mail.subject };
}

// ---------------------------------------------------------------------------
// The month, at Admission.

/// The billing mode a pool's months are given in: the 100's live, the
/// checks' test.
const modeOf = (test) => (test ? "test" : "live");

/// What the owner's queue says of an account whose beta month Admission
/// gave once already and which has ended or was revoked.
export const GIVEN_ONCE = "Admission gave this account its beta month once already, and it has ended or was revoked: "
  + "one reason gives one month, ever. To give another, comp it by hand in Admission.";

/// What the owner's queue says when Admission did not give a month.
export function compSaid(trouble) {
  if (trouble instanceof AdmissionError && trouble.code === "api_comps_off") {
    return "Admission refused: Brickworks' key may not comp yet. Set Brickworks' API comps limit (100) in "
      + "Admission, then Grant pending months.";
  }
  if (trouble instanceof AdmissionError && trouble.code === "api_comps_full") {
    return "Admission refused: Brickworks' API comps limit is reached. Raise it in Admission, then Grant pending months.";
  }
  if (trouble instanceof AdmissionUnavailable) return "Admission could not be reached. Grant pending months tries again.";
  if (trouble instanceof AdmissionError) {
    return `Admission refused: ${trouble.code} (${trouble.status}). Grant pending months tries again.`;
  }
  return "The month was not given just now. Grant pending months tries again.";
}

/// The month of Pro for an approved tester [who] ({account, test}): given
/// at Admission now when billing is in the pool's mode, else left
/// pending to start when Pro launches. Kept either way (beta_comp_note).
/// {comp: "granted", starts, ends} or {comp: "pending", said}. The one
/// place Brickworks comps anybody.
export async function approveMonth(who, now = Date.now()) {
  const want = modeOf(who.test);
  const a = billingMode() === want ? admission() : null;
  let kept;
  if (!a) {
    kept = { comp: "pending", said: who.test ? "Given in Admission's test mode, on a deployment with billing test."
      : "Starts when Pro launches." };
  } else {
    try {
      const c = await a.comp({ customerId: who.account, reason: "beta", plan: "pro", days: DAYS });
      const until = c?.plan?.source === "override" && c.plan.until ? Date.parse(c.plan.until) : NaN;
      if (Number.isFinite(until) && until > now) {
        // Admission's until is when it made the comp and 30 days: a repeat
        // answers the first one, so its start is read from its end.
        kept = { comp: "granted", starts: new Date(until - DAYS * DAY_MS).toISOString(), ends: new Date(until).toISOString() };
      } else {
        // A repeat of a comp that has ended or was revoked: Admission gives
        // one a reason, ever, and changes nothing. Said, never taken for a month.
        kept = { comp: "pending", said: GIVEN_ONCE };
      }
    } catch (trouble) {
      console.error(`beta: comp: ${trouble?.code || trouble?.name || "error"}: ${String(trouble?.message || trouble).slice(0, 120)}`);
      kept = { comp: "pending", said: compSaid(trouble) };
    }
  }
  await db("rpc/beta_comp_note", { method: "POST", body: { p_account: who.account, p_comp: kept.comp,
    p_starts: kept.starts ?? null, p_ends: kept.ends ?? null, p_said: kept.said ?? null } });
  return kept;
}

const pause = (ms) => new Promise((done) => setTimeout(done, ms));

/// Every month still to give in this deployment's billing mode, given,
/// each tester mailed that theirs has started: what the release runs once
/// Pro launches, the daily cron, and the owner's Grant pending months.
/// Running it again gives nothing twice (Admission answers a reason once,
/// and a month granted is never pending again). {mode, granted, pending,
/// said}; null while billing is off.
export async function grantDue() {
  const mode = billingMode();
  if (mode === "off") return null;
  const test = mode === "test";
  const due = await db("rpc/beta_comps_due", { method: "POST", body: { p_pool: test ? "test" : "beta" } });
  const done = { mode, granted: 0, pending: 0, said: [] };
  for (const one of Array.isArray(due) ? due : []) {
    const kept = await approveMonth({ account: one.account, test });
    if (kept.comp === "granted") {
      done.granted += 1;
      await sendMail("started", { account: one.account, email: one.email }, { spot: one.spot, starts: kept.starts,
        ends: kept.ends });
      // Resend takes a few emails a second.
      await pause(600);
    } else {
      done.pending += 1;
      if (!done.said.includes(kept.said)) done.said.push(kept.said);
    }
  }
  return done;
}

/// Reminders three days before a month ends, each sent once.
async function remind() {
  const due = await db("rpc/beta_reminders_due", { method: "POST", body: {} });
  let sent = 0;
  for (const one of Array.isArray(due) ? due : []) {
    const said = await sendMail("reminder", { account: one.account, email: one.email }, { spot: one.spot,
      ends: one.month_ends_at });
    if (said.state !== "failed") sent += 1;
    await pause(600);
  }
  return sent;
}

// ---------------------------------------------------------------------------
// The routes.

const say = (response, status, error, extra = {}) => response.status(status).json({ error, ...extra });

/// PostgREST answers 404 for a function that is not there: before beta.sql.
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));

async function claimsOf(request) {
  if (!bearer(request)) return null;
  return verify(bearer(request), request);
}

/// GET or POST /api/plans?op=beta.
export async function betaRoute(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const mode = betaMode();
  if (request.method === "GET" && mode === "off") return response.status(200).json({ beta: "off" });
  if (request.method === "POST" && mode === "off") return say(response, 403, "The beta is not open yet.", { beta: "off" });
  if (!["GET", "POST"].includes(request.method)) return say(response, 405, "GET, or POST the form signed in");
  if (!dbConfigured()) return say(response, 503, "The beta is not open here yet.");
  let claims = null;
  try {
    claims = await claimsOf(request);
  } catch (trouble) {
    if (!(trouble instanceof AuthError)) throw trouble;
    // A sign-in that has ended reads as signed out; applying needs one.
    if (request.method === "POST") return say(response, trouble.status, trouble.message);
  }
  try {
    if (request.method === "GET") {
      const status = await db("rpc/beta_status", { method: "POST", body: { p_account: claims?.sub ?? null } });
      return response.status(200).json({ beta: "open", signed_in: Boolean(claims), ...status });
    }
    if (!claims) return say(response, 401, "Sign in to apply.");
    return await apply(request, response, claims);
  } catch (trouble) {
    if (trouble instanceof Refusal) return say(response, trouble.status, trouble.message, trouble.extra);
    console.error(`beta: ${String(trouble?.message || trouble).slice(0, 160)}`);
    if (notYet(trouble)) return say(response, 503, "The beta is not open here yet.");
    return say(response, 503, "That did not go just now. Try again in a minute.");
  }
}

/// GET /api/plans?op=beta_hub: a tester's (an account whose application was
/// approved, supabase/feedback.sql beta_tester): what is new to try, what
/// is known to be wrong, and the early features (api/_early.js). 401 signed
/// out, 403 for anyone else, whatever the switch: testers keep their hub.
export async function betaHub(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!dbConfigured()) return say(response, 503, "The beta hub is not open here yet.");
  let claims = null;
  try {
    claims = await claimsOf(request);
  } catch (trouble) {
    if (!(trouble instanceof AuthError)) throw trouble;
    return say(response, trouble.status, trouble.message);
  }
  if (!claims) return say(response, 401, "Sign in to see the beta hub.");
  try {
    const tester = await db("rpc/beta_tester", { method: "POST", body: { p_account: claims.sub } });
    if (tester !== true) return say(response, 403, "The beta hub is for beta testers.", { tester: false });
    return response.status(200).json({ tester: true, early: EARLY, new: NEW, known: KNOWN });
  } catch (trouble) {
    console.error(`beta: hub: ${String(trouble?.message || trouble).slice(0, 120)}`);
    if (notYet(trouble)) return say(response, 503, "The beta hub is not open here yet.");
    return say(response, 503, "That did not go just now. Try again in a minute.");
  }
}

/// GET /api/plans?op=beta_spots: whether the beta is open and how many of
/// the 100 spots are left, for any page (pricing, home) to show or not.
/// Nobody's sign-in is read and nothing about an applicant is said, so it
/// may be kept a minute by any cache.
export async function betaSpots(request, response) {
  response.setHeader("Cache-Control", "public, max-age=60, s-maxage=60, stale-while-revalidate=300");
  if (betaMode() === "off" || !dbConfigured()) return response.status(200).json({ beta: "off" });
  try {
    const { pool } = await db("rpc/beta_status", { method: "POST", body: { p_account: null } });
    return response.status(200).json({ beta: "open", cap: pool.cap, left: pool.left });
  } catch (trouble) {
    console.error(`beta: spots: ${String(trouble?.message || trouble).slice(0, 120)}`);
    response.setHeader("Cache-Control", "no-store");
    return response.status(503).json({ beta: "unknown" });
  }
}

function bodyOf(request) {
  if (typeof request.body !== "string") return request.body || {};
  try {
    return JSON.parse(request.body);
  } catch {
    return {};
  }
}

async function apply(request, response, claims) {
  const email = String(claims.email || "").trim().toLowerCase();
  if (!email || ORANGECHECK_ADDRESS.test(email)) {
    throw new Refusal(422, "Your account signs in with orangecheck and has no email address we can write to. Sign in "
      + "with your email to apply.");
  }
  if (claims.email_verified === false) throw new Refusal(403, "Confirm your email address first: sign in with a code.");
  const app = applicationOf(bodyOf(request));
  const made = await db("rpc/beta_apply", { method: "POST", body: { p_account: claims.sub, p_build: app.build,
    p_ai: app.ai, p_background: app.background, p_background_line: app.background_line, p_link: app.link ?? "",
    p_terms: TERMS, p_signals: signalsOf(app, email) } });
  if (made?.refused === "applied") {
    throw new Refusal(409, "You have applied already: one application an account.", { status: made.status });
  }
  if (made?.refused === "too_soon") {
    throw new Refusal(409, `You may apply again from ${dayOf(made.may_apply_again_at)}.`,
      { may_apply_again_at: made.may_apply_again_at });
  }
  if (!made?.application) throw new Error("beta_apply made nothing");
  const mail = await sendMail("received", { account: claims.sub, email }, { early: made.application.early,
    waitlist: made.application.status === "waitlist" });
  return response.status(200).json({ beta: "open", signed_in: true, ...made, mail: mail.state });
}

/// The daily run, Vercel's cron's alone (GET /api/plans/beta-daily): months
/// to give when billing is on, reminders, and declined applications erased.
export async function betaDaily(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return say(response, 401, "the daily run is the cron's");
  if (!dbConfigured()) return say(response, 503, "no database here");
  const out = {};
  try {
    out.months = await grantDue();
    out.reminded = await remind();
    out.swept = await db("rpc/beta_sweep", { method: "POST", body: {} });
  } catch (trouble) {
    console.error(`beta: daily: ${String(trouble?.message || trouble).slice(0, 160)}`);
    if (notYet(trouble)) return response.status(200).json({ ...out, said: "beta.sql is not applied here" });
    return response.status(500).json({ ...out, error: "the daily run stopped" });
  }
  // And feedback's reports past their time (api/_feedback.js), on its own:
  // imported here, as it imports this file.
  try {
    out.feedback = await (await import("./_feedback.js")).sweepFeedback();
  } catch (trouble) {
    console.error(`beta: daily: feedback: ${String(trouble?.message || trouble).slice(0, 160)}`);
    out.feedback = notYet(trouble) ? "feedback.sql is not applied here" : "the sweep stopped";
  }
  return response.status(200).json(out);
}

// ---------------------------------------------------------------------------
// The owner's queue (api/admin.js, after its owner check).

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const STATUSES = ["new", "waitlist", "approved", "declined"];

/// When months start here: at approval, or when Pro launches.
function monthsHere() {
  const mode = billingMode();
  return { billing: mode, live: mode === "live" ? "at approval" : "when Pro launches",
    test: mode === "test" ? "at approval" : "when billing is test" };
}

/// GET /api/admin?op=beta[&status=S][&tests=1].
export async function betaQueue(request, response) {
  const status = String(request.query?.status || "");
  if (status && !STATUSES.includes(status)) return say(response, 400, "status is new, waitlist, approved or declined");
  const tests = String(request.query?.tests || "") === "1";
  try {
    const queue = await db("rpc/beta_queue", { method: "POST", body: { p_status: status || null, p_tests: tests,
      p_limit: 500 } });
    return response.status(200).json({ beta: betaMode(), months: monthsHere(), tests, ...queue });
  } catch (trouble) {
    if (notYet(trouble)) return say(response, 503, "Not open yet: supabase/beta.sql is not applied.");
    throw trouble;
  }
}

/// POST /api/admin?op=beta_decide&account=U {decision: approve | decline,
/// note}: decided, then the month and the email.
export async function betaDecide(request, response, claims) {
  const account = String(request.query?.account || "");
  if (!UUID.test(account)) return say(response, 400, "name an application: ?account=<id>");
  const body = bodyOf(request);
  const decision = String(body?.decision || "");
  if (!["approve", "decline"].includes(decision)) return say(response, 422, "Approve or decline.");
  const note = line(body?.note).slice(0, MOST.note);
  let said;
  try {
    said = await db("rpc/beta_decide", { method: "POST", body: { p_account: account, p_decision: decision,
      p_note: note || null, p_by: String(claims.email || "the owner").slice(0, 320) } });
  } catch (trouble) {
    if (notYet(trouble)) return say(response, 503, "Not open yet: supabase/beta.sql is not applied.");
    throw trouble;
  }
  if (said?.refused === "none") return say(response, 404, "There is no such application.");
  if (said?.refused === "full") {
    return say(response, 409, `Every one of the ${said.pool?.cap ?? 100} spots is given: this application is on the `
      + "waitlist. Raise the pool's cap to approve more.", { pool: said.pool, refused: "full" });
  }
  if (said?.refused === "approved") return say(response, 409, "An approved tester is never declined.", { refused: "approved" });
  const app = said.application;
  const who = { account, email: said.email, test: said.test === true };
  const out = { decision, again: said.again === true, application: app, pool: said.pool };
  if (said.again) return response.status(200).json(out);
  if (decision === "approve") {
    if (!app.early) {
      out.month = await approveMonth(who);
      out.application = { ...app, comp: out.month.comp, month_starts_at: out.month.starts ?? null,
        month_ends_at: out.month.ends ?? null };
    }
    out.mail = (await sendMail("approved", who, { spot: app.spot, cap: said.pool?.cap, early: app.early,
      starts: out.month?.starts, ends: out.month?.ends })).state;
  } else {
    out.mail = (await sendMail("declined", who, { again_at: app.may_apply_again_at })).state;
  }
  return response.status(200).json(out);
}

/// POST /api/admin?op=beta_grant: every month still to give, given.
export async function betaGrant(request, response) {
  try {
    const done = await grantDue();
    if (!done) return say(response, 409, "Billing is off here: months are given when Pro launches.");
    return response.status(200).json(done);
  } catch (trouble) {
    if (notYet(trouble)) return say(response, 503, "Not open yet: supabase/beta.sql is not applied.");
    throw trouble;
  }
}
