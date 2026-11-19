// The owner's notifications (ownernotify, 2026-11-18; docs/OWNER_NOTIFY.md,
// docs/ADMIN.md, supabase/owner_notify.sql): mail to the site's owner about
// what happens on it, set in /admin › Notifications.
//
// What happens is raised where it happens, as one row each (raise): a new
// account (api/otp.js, api/orangecheck.js), a first model published
// (api/share.js), feedback sent (api/_feedback.js), Admission's word of a plan
// or a payment (api/plans.js's webhook). What is a reading rather than an act
// is looked at by the cron each time it runs (flush): server errors over the
// owner's number in an hour (api/_noted.js keeps each), the database or
// storage over the owner's share of its quota, Supabase refusing the
// project, and the social desk's tables (what came in; a scheduled post that
// went, failed, may be up, or is due by hand), read and never written, so the
// desk's own files are not touched.
//
// The cron (/api/plans/owner-notify, every five minutes, api/plans.js) then
// mails what waits, one mail an event kind, by these rules:
//
// - Each kind on or off, and "at once" or "in the daily digest", which goes
//   at the owner's time in their time zone.
// - A kind waits while its events still come (GAP), at most MOST_WAIT: a
//   burst of sign-ups is one mail, never one each.
// - At most [cap] mails in any hour. Past it, the rest wait and go as one
//   mail ("And 37 more"), the hour's last, when the hour allows.
// - Quiet hours: nothing goes; what came is held, and goes as one mail when
//   they end. The digest waits for them too.
// - Pause all: nothing is mailed, nor kept to be mailed later.
//
// Every mail sent, held or folded is written to the console's audit (actor
// "notifications", kind "notification"), which Notifications › Sent reads.
//
// Two pools, as the console keeps everywhere: the checks' own (?tests=1)
// mail only Resend's test inbox (an address at resend.dev), never the owner.
// The site's own pool (brickworks.diy, not a test) mails from the start, with
// each kind's default; any other (a preview's, the checks') mails nobody
// until its settings are saved.
//
// Mail goes through Resend from brickworks.diy with the site's own sending
// key (RESEND_API_KEY), never a key that can read or administer. Each mail
// links to its place in the console and to a one-click "turn this off",
// signed with the pool's own key (owner_notify_settings.off_key), which
// /admin acts on (api/plans.js ?op=notify_off when the owner is signed out).

import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from "node:crypto";
import { afterHow } from "./_after.js";
import { AuthError } from "./_auth.js";
import { db, dbConfigured, dbCount } from "./_db.js";
import { scopeOf } from "./_settings.js";

export const NOT_APPLIED = "Notifications' tables are not in the database yet: supabase/owner_notify.sql is to be applied.";
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));

/// Where the checks' own mail goes: Resend's test inbox, read by nobody.
export const TEST_INBOX = "delivered+brickworks-tests@resend.dev";
const TEST_ADDRESS = /@resend\.dev$/i;
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
/// Typed or pasted words with their zero-width characters taken out and any
/// space at either end (a pasted address or code often carries them).
const typed = (value) => String(value ?? "").normalize("NFKC").replace(/[\u200B-\u200D\u2060\uFEFF]/g, "").trim();
const SENDER = "Brickworks <noreply@brickworks.diy>";
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const MINUTE = 60000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const GB = 1024 ** 3;

/// A kind waits while its events still come: until none came for GAP, and
/// never longer than MOST_WAIT after its first.
export const GAP = 2 * MINUTE;
export const MOST_WAIT = 10 * MINUTE;
/// Items listed in a mail; the rest counted, with a link to them all.
export const LISTED = 10;
/// A mail that failed is tried again this many times, then given up.
export const TRIES = 3;
/// The owner's Send a test, at most this many an hour.
export const TESTS_AN_HOUR = 10;
/// Codes mailed to another address, at most this many an hour, counted as
/// tests are (onreview: they had no limit).
export const CODES_AN_HOUR = 5;

/// Every kind of event, as the console lists it and the mail says it.
export const EVENTS = Object.freeze({
  signup: { name: "A new sign-up", says: "Who made an account, and how they came: the site that sent them, or a link's tags.",
    one: "new sign-up", many: "new sign-ups", section: "people", on: true, when: "now" },
  first_model: { name: "A first model published", says: "Someone's first model, shared at its link or listed in the gallery.",
    one: "first model published", many: "first models published", section: "gallery", on: true, when: "now" },
  feedback: { name: "A bug report or feedback", says: "What was sent with Send feedback, on the site or in the studio.",
    one: "bug report or feedback", many: "bug reports and feedback", section: "feedback", on: true, when: "now" },
  plan: { name: "Plans and payments", says: "A plan bought, changed or cancelled, or a payment that failed, as Admission tells the site.",
    one: "plan or payment", many: "plans and payments", section: "plans", on: true, when: "now" },
  errors: { name: "Server errors", says: "Answers of 500 or over from the site's functions, past your number in an hour. At most one mail an hour.",
    one: "server errors alert", many: "server errors alerts", section: "site", on: true, when: "now",
    threshold: { min: 1, max: 100000, value: 20, unit: "errors in an hour" } },
  quota: { name: "Supabase near its quota", says: "The database or storage past your share of its quota, or Supabase refusing the project. "
    + "Looked at hourly; at most once a day each.", one: "Supabase alert", many: "Supabase alerts", section: "data", on: true, when: "now",
    threshold: { min: 10, max: 100, value: 80, unit: "% of the quota" },
    sizes: { database_gb: { min: 0.1, max: 100000, value: 8, unit: "GB database" },
      storage_gb: { min: 0.1, max: 1000000, value: 100, unit: "GB storage" } } },
  social: { name: "Social: what came in", says: "New replies, mentions and messages on the social desk's accounts.",
    one: "new on the social desk", many: "new on the social desk", section: "social/inbox", on: true, when: "digest" },
  social_send: { name: "Social: a scheduled post", says: "A scheduled post that went, failed or may be up, and one whose time came to post by hand.",
    one: "scheduled post", many: "scheduled posts", section: "social/sent", on: true, when: "now" },
});

/// Which kinds go first when the hour's cap leaves room for only some.
const FIRST = ["errors", "quota", "plan", "social_send", "feedback", "signup", "first_model", "social"];

/// What the owner asked for that no key here can read, each with why and
/// where it is watched instead.
export const NOT_HERE = Object.freeze([
  { id: "vercel", name: "Vercel's use near its limit", why: "Vercel tells its usage only through its API with an account token, "
    + "which the site does not hold. Vercel mails its own spend alerts (50%, 75% and 100% by default): set them in the team's "
    + "Settings › Billing.", href: "https://vercel.com/docs/spend-management" },
  { id: "resend", name: "Resend's use near its limit", why: "The site's Resend key can only send, and the Resend team's quota is "
    + "shared with other products, so the site cannot say how near it is. A send Resend refuses for its quota shows in Mail.",
    href: "https://resend.com/settings/usage" },
  { id: "egress", name: "Supabase's egress", why: "Supabase tells egress only through its Management API, whose tokens reach every "
    + "project of the organization (Data says why). Supabase refusing the project, which is what egress over its quota does, "
    + "is mailed under Supabase near its quota.", href: "https://supabase.com/dashboard/org/_/usage" },
  { id: "release", name: "A release held or a deploy failed", why: "The release tools do not tell the site yet; they would need "
    + "nothing new but a line in the train that writes an event." },
]);

// ---------------------------------------------------------------------------
// The owner's choices.

const zoneKnown = (zone) => {
  if (typeof zone !== "string" || zone.length > 64) return false;
  try {
    new Intl.DateTimeFormat("en", { timeZone: zone });
    return true;
  } catch {
    return false;
  }
};
const within = (given, { min, max, value }) => (typeof given === "number" && Number.isFinite(given) && given >= min && given <= max
  ? given : value);

/// [row]'s settings whole, each missing or broken one at its default, for
/// [pool] ({scope, test}). saved: the owner saved them here (notify_set);
/// active: whether this pool mails at all, which only that, or being the
/// site's own pool, makes so. A row made for a test, an address's code or
/// a mail's off link is not a saving (onreview: a preview's test made its
/// pool mail the owner on Check now).
export function settingsOf(row, pool) {
  const given = row?.settings && typeof row.settings === "object" && !Array.isArray(row.settings) ? row.settings : {};
  const quiet = given.quiet && typeof given.quiet === "object" ? given.quiet : {};
  const settings = {
    tz: zoneKnown(given.tz) ? given.tz : "UTC",
    quiet: { on: quiet.on === true, from: TIME.test(quiet.from) ? quiet.from : "22:00", to: TIME.test(quiet.to) ? quiet.to : "07:00" },
    digest_at: TIME.test(given.digest_at) ? given.digest_at : "08:00",
    cap: Number.isInteger(given.cap) && given.cap >= 1 && given.cap <= 60 ? given.cap : 6,
    paused: given.paused === true,
    saved: given.saved === true,
    events: {},
  };
  for (const [name, one] of Object.entries(EVENTS)) {
    const mine = given.events?.[name] && typeof given.events[name] === "object" ? given.events[name] : {};
    const event = { on: typeof mine.on === "boolean" ? mine.on : one.on, when: mine.when === "now" || mine.when === "digest" ? mine.when
      : one.when };
    if (one.threshold) event.threshold = within(mine.threshold, one.threshold);
    for (const [size, range] of Object.entries(one.sizes || {})) event[size] = within(mine[size], range);
    settings.events[name] = event;
  }
  settings.active = settings.saved || (pool.scope === "live" && !pool.test);
  return settings;
}

/// What the owner asked to change ([body]), checked and laid over [current]:
/// the settings to keep. A refusal says why, in words.
export function changed(body, current) {
  const refuse = (words) => { throw new AuthError(words, 400); };
  const next = JSON.parse(JSON.stringify({ ...current, active: undefined }));
  delete next.active;
  if (!body || typeof body !== "object" || Array.isArray(body)) refuse("Send the settings to change as JSON.");
  if ("tz" in body) {
    if (!zoneKnown(body.tz)) refuse("That is not a time zone this server knows, as Europe/London is.");
    next.tz = body.tz;
  }
  if ("quiet" in body) {
    const quiet = body.quiet;
    if (!quiet || typeof quiet !== "object") refuse("Quiet hours are {on, from, to}.");
    const on = "on" in quiet ? quiet.on : next.quiet.on;
    const from = "from" in quiet ? quiet.from : next.quiet.from;
    const to = "to" in quiet ? quiet.to : next.quiet.to;
    if (typeof on !== "boolean") refuse("Quiet hours are on or off.");
    if (!TIME.test(String(from)) || !TIME.test(String(to))) refuse("Quiet hours start and end at a time of day, as 22:00.");
    if (on && from === to) refuse("Quiet hours need a start and an end that differ.");
    next.quiet = { on, from, to };
  }
  if ("digest_at" in body) {
    if (!TIME.test(String(body.digest_at))) refuse("The digest goes at a time of day, as 08:00.");
    next.digest_at = body.digest_at;
  }
  if ("cap" in body) {
    if (!Number.isInteger(body.cap) || body.cap < 1 || body.cap > 60) refuse("At most 1 to 60 mails an hour.");
    next.cap = body.cap;
  }
  if ("paused" in body) {
    if (typeof body.paused !== "boolean") refuse("Pause all is on or off.");
    next.paused = body.paused;
  }
  if ("events" in body) {
    if (!body.events || typeof body.events !== "object" || Array.isArray(body.events)) refuse("events is {name: {on, when}}.");
    for (const [name, asked] of Object.entries(body.events)) {
      const one = Object.hasOwn(EVENTS, name) ? EVENTS[name] : null;
      if (!one) refuse(`There is no notification called ${String(name).slice(0, 40)}.`);
      if (!asked || typeof asked !== "object") refuse(`${one.name}: send {on, when}.`);
      const event = next.events[name];
      if ("on" in asked) {
        if (typeof asked.on !== "boolean") refuse(`${one.name}: on or off.`);
        event.on = asked.on;
      }
      if ("when" in asked) {
        if (asked.when !== "now" && asked.when !== "digest") refuse(`${one.name}: at once or in the daily digest.`);
        event.when = asked.when;
      }
      const ranges = { ...(one.threshold ? { threshold: one.threshold } : {}), ...(one.sizes || {}) };
      for (const [field, range] of Object.entries(ranges)) {
        if (!(field in asked)) continue;
        const value = asked[field];
        if (typeof value !== "number" || !Number.isFinite(value) || value < range.min || value > range.max) {
          refuse(`${one.name}: ${range.unit} is a number from ${range.min} to ${range.max.toLocaleString("en")}.`);
        }
        event[field] = value;
      }
      for (const field of Object.keys(asked)) {
        if (!["on", "when", ...Object.keys(ranges)].includes(field)) refuse(`${one.name}: nothing called ${String(field).slice(0, 40)}.`);
      }
    }
  }
  for (const field of Object.keys(body)) {
    if (!["tz", "quiet", "digest_at", "cap", "paused", "events"].includes(field)) {
      refuse(`There is no setting called ${String(field).slice(0, 40)}.`);
    }
  }
  // Saved by the owner: this pool mails from now on (settingsOf).
  next.saved = true;
  return next;
}

/// The day before [date] ("YYYY-MM-DD"), by the calendar.
const dayBefore = (date) => new Date(Date.parse(`${date}T00:00:00Z`) - DAY).toISOString().slice(0, 10);

/// When [settings]' digest goes: at its time, or, when that is inside quiet
/// hours, as they end. {at, held_until, said}.
export function digestTime(settings) {
  const held = quietAt(settings, settings.digest_at) ? settings.quiet.to : null;
  return { at: settings.digest_at, held_until: held,
    said: held ? `sent at ${held} when quiet hours end` : `sent at ${settings.digest_at}` };
}

/// The day and the time of day [now] is in [zone]: {date, hhmm}.
export function localOf(now, zone) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit",
    day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).formatToParts(new Date(now))
    .map((part) => [part.type, part.value]));
  return { date: `${parts.year}-${parts.month}-${parts.day}`, hhmm: `${parts.hour}:${parts.minute}` };
}

/// Whether [hhmm] is in [settings]' quiet hours, which may run past midnight.
export function quietAt(settings, hhmm) {
  const { on, from, to } = settings.quiet;
  if (!on || from === to) return false;
  return from < to ? hhmm >= from && hhmm < to : hhmm >= from || hhmm < to;
}

/// An address shown in part: "wi•••@example.com".
export function inPart(address) {
  const [name, domain] = String(address || "").split("@");
  if (!name || !domain) return "—";
  return `${name.slice(0, name.length > 2 ? 2 : 1)}•••@${domain}`;
}

/// The owner's own verified address: the console's gate's (api/_auth.js isMaster).
const accountAddress = (pool) => (pool.test ? TEST_INBOX : String(process.env.MASTER_EMAIL || "").trim().toLowerCase());
const addressOf = (row, pool) => row?.address || accountAddress(pool);

/// The pool [request] acts on: this deployment's, the checks' own on ?tests=1.
export const poolOf = (request, tests = String(request?.query?.tests || "") === "1") => ({ scope: scopeOf(request), test: tests });

/// The address a pool's links are on: brickworks.diy for the site's own, a
/// preview's own host for its (never PUBLIC_ORIGIN, which on a preview is live's).
export function originFor(scope) {
  if (scope === "live") return String(process.env.PUBLIC_ORIGIN || "").replace(/\/+$/, "") || "https://brickworks.diy";
  return /^(?:127\.0\.0\.1|localhost)(?::\d{1,5})?$/.test(scope) ? `http://${scope}` : `https://${scope}`;
}

const enc = encodeURIComponent;
const where = (pool) => `scope=eq.${enc(pool.scope)}&test=eq.${pool.test}`;

async function rowOf(pool) {
  const rows = await db(`owner_notify_settings?${where(pool)}&select=*`);
  return Array.isArray(rows) && rows.length ? rows[0] : null;
}

const stored = (settings) => {
  const { active, ...kept } = settings;
  return kept;
};

/// [pool]'s row changed by [change] (row, settings) => {settings?, ...columns}
/// as one write: read, changed, and written only when nobody wrote it
/// between (its version), else read and changed again. Two of the owner's
/// presses at once, a mail's off link and the cron's digest each keep what
/// the other changed. [by]: who, when the settings change. The row written.
async function writeRow(pool, change, by = null) {
  for (let tries = 0; tries < 6; tries += 1) {
    const row = await rowOf(pool);
    const asked = await change(row, settingsOf(row, pool));
    const { settings, ...columns } = asked;
    const body = { ...columns, ...(settings ? { settings: stored(settings) } : {}),
      ...(settings || by ? { set_by: String(by || "notifications").slice(0, 320), set_at: new Date().toISOString() } : {}) };
    if (!row) {
      try {
        await db("owner_notify_settings", { method: "POST", prefer: "return=minimal",
          body: { scope: pool.scope, test: pool.test, settings: {}, ...body, version: 1 } });
        return await rowOf(pool);
      } catch (trouble) {
        if (/: 409$/.test(String(trouble?.message || ""))) continue;
        throw trouble;
      }
    }
    const written = await db(`owner_notify_settings?${where(pool)}&version=eq.${Number(row.version) || 0}`, { method: "PATCH",
      prefer: "return=representation", body: { ...body, version: (Number(row.version) || 0) + 1 } });
    if (Array.isArray(written) && written.length) return written[0];
  }
  throw new AuthError("The settings changed under this change six times running: try again.", 409);
}

/// [pool]'s row, made with the defaults when there is none (its key for the
/// one-click links is made with it).
async function rowMade(pool) {
  const row = await rowOf(pool);
  return row || writeRow(pool, (there) => (there ? {} : { settings: settingsOf(null, pool) }));
}

/// The one-click "turn [event] off" key for [pool], signed with its row's key.
export function offToken(row, pool, event) {
  return createHmac("sha256", String(row?.off_key || "")).update(`off|${pool.scope}|${pool.test ? 1 : 0}|${event}`).digest("hex")
    .slice(0, 32);
}
const same = (a, b) => {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && timingSafeEqual(x, y);
};

// ---------------------------------------------------------------------------
// Raising: one row an event, kept once by its key. Never throws, and never
// keeps what raised it waiting long: an act's answer does not wait on this.

const clip = (given, most = 300) => String(given ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, most);

/// [detail] with every string clipped and the whole small enough to keep.
function small(detail) {
  const out = {};
  for (const [name, value] of Object.entries(detail || {})) {
    if (value === undefined || value === null) continue;
    if (typeof value === "string") out[name] = clip(value, 300);
    else if (typeof value === "number" || typeof value === "boolean") out[name] = value;
    else if (typeof value === "object") out[name] = JSON.parse(JSON.stringify(value, (key, inner) => (typeof inner === "string"
      ? clip(inner, 200) : inner)));
  }
  return JSON.stringify(out).length <= 3000 ? out : Object.fromEntries(Object.entries(out).filter(([, value]) => typeof value !== "object"));
}

/// [rows] ({event, scope, test, key, account?, detail}) kept, each once.
async function keepEvents(rows) {
  if (!rows.length) return 0;
  await db("owner_notify_events?on_conflict=scope,test,event,key", { method: "POST",
    prefer: "resolution=ignore-duplicates,return=minimal", seconds: 5,
    body: rows.map((one) => ({ scope: one.scope, test: Boolean(one.test), event: one.event, key: clip(one.key, 200),
      account: one.account || null, detail: small(one.detail) })) });
  return rows.length;
}

/// [event] happened: kept to be mailed. True when it was kept (or was already).
export async function raise(event, { scope = "live", test = false, key, account = null, detail = {} } = {}) {
  if (!dbConfigured() || !Object.hasOwn(EVENTS, event) || !key) return false;
  try {
    await keepEvents([{ event, scope: /^[a-z0-9.:-]{1,200}$/.test(scope) ? scope : "unknown", test, key, account, detail }]);
    return true;
  } catch (trouble) {
    if (!notYet(trouble)) console.error(`notify: ${event} not kept: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return false;
  }
}

/// How a person came, as the page they signed up on told it (web/theme.js):
/// the site that sent them and a link's utm_ tags, each checked; null else.
export function cameOf(given) {
  if (!given || typeof given !== "object" || Array.isArray(given)) return null;
  const out = {};
  for (const name of ["source", "medium", "campaign"]) {
    const value = String(given[name] ?? "").trim();
    if (/^[A-Za-z0-9 ._+-]{1,60}$/.test(value)) out[name] = value;
  }
  const referrer = String(given.referrer ?? "").trim().toLowerCase();
  if (/^[a-z0-9.-]{1,100}$/.test(referrer) && referrer.includes(".")) out.referrer = referrer;
  return Object.keys(out).length ? out : null;
}

/// A new account (api/otp.js mint, api/orangecheck.js): raised for its pool.
/// Never its address: the privacy page promises it signs the person in and
/// nothing else. Its handle, once it has one, is read as the mail is made.
export function raiseSignup({ account, email, came = null, scope = "live", via = "code" }) {
  return raise("signup", { scope, test: TEST_ADDRESS.test(String(email || "")), key: account, account,
    detail: { came: cameOf(came), via } });
}

// ---------------------------------------------------------------------------
// What the cron looks at: readings rather than acts.

/// Server errors in the hour before [now] past the owner's number: one
/// alert, at most one an hour.
async function lookErrors(pool, settings, now) {
  const errors = settings.events.errors;
  if (!errors.on) return;
  const since = new Date(now - HOUR).toISOString();
  const count = await dbCount(`owner_notify_errors?scope=eq.${enc(pool.scope)}&at=gte.${since}`);
  if (count < errors.threshold) return;
  const told = await db(`owner_notify_events?${where(pool)}&event=eq.errors&at=gte.${since}&select=id&limit=1`);
  if (told.length) return;
  const rows = await db(`owner_notify_errors?scope=eq.${enc(pool.scope)}&at=gte.${since}&select=fn,op,status&limit=1000`);
  const by = new Map();
  for (const one of rows) by.set(`${one.fn}${one.op ? ` ${one.op}` : ""}`, (by.get(`${one.fn}${one.op ? ` ${one.op}` : ""}`) || 0) + 1);
  const top = [...by].sort((a, b) => b[1] - a[1]).slice(0, 5).map(([what, n]) => ({ what, n }));
  await raise("errors", { ...pool, key: `errors:${new Date(now).toISOString().slice(0, 13)}`,
    detail: { count, threshold: errors.threshold, since, top } });
}

/// The database and storage against the owner's share of their quota, and
/// whether Supabase refuses the project: hourly (the first run of each
/// hour), or when the owner asks (Check now). At most once a day each.
async function lookQuota(pool, settings, now, force) {
  const quota = settings.events.quota;
  if (!quota.on || (!force && new Date(now).getUTCMinutes() >= 5)) return;
  const day = new Date(now).toISOString().slice(0, 10);
  const usage = await db("rpc/admin_usage", { method: "POST", body: {} }).catch(() => null);
  const over = (what, bytes, size) => {
    const percent = Math.round((bytes / (size * GB)) * 1000) / 10;
    if (!(percent >= quota.threshold)) return null;
    return { event: "quota", ...pool, key: `${what}:${day}`, detail: { what, bytes, quota_gb: size, percent, threshold: quota.threshold } };
  };
  const raised = [];
  if (usage && Number.isFinite(Number(usage.database))) raised.push(over("database", Number(usage.database), quota.database_gb));
  if (usage && Array.isArray(usage.buckets)) {
    raised.push(over("storage", usage.buckets.reduce((sum, one) => sum + (Number(one.bytes) || 0), 0), quota.storage_gb));
  }
  const { supabaseHealth } = await import("./_console_site.js");
  const health = await supabaseHealth({ fresh: true }).catch(() => null);
  if (health && !health.ok) {
    raised.push({ event: "quota", ...pool, key: `refusing:${day}`, detail: { what: health.restricted ? "restricted" : "down",
      said: clip(health.fix, 280) } });
  }
  await keepEvents(raised.filter(Boolean));
}

/// The social desk's tables, read: what came in the last day, and the
/// scheduled posts that went, failed, may be up, or whose time came to post
/// by hand. Kept once each by its key, so reading again changes nothing.
async function lookSocial(pool, settings, now) {
  const since = new Date(now - DAY).toISOString();
  const read = (path) => db(path).catch((trouble) => (notYet(trouble) ? [] : Promise.reject(trouble)));
  const raised = [];
  if (settings.events.social.on) {
    const items = await read(`social_items?test=eq.${pool.test}&seen_at=gte.${since}&select=provider,external_id,kind,detail,`
      + "author,subject,body,url,community&order=seen_at.asc&limit=200");
    for (const one of items) {
      raised.push({ event: "social", ...pool, key: `${one.provider}:${one.external_id}`, detail: { provider: one.provider,
        kind: one.kind, detail: one.detail, author: one.author, community: one.community, subject: one.subject,
        words: clip(one.body, 160), url: /^https:\/\//.test(String(one.url || "")) ? one.url : null } });
    }
  }
  if (settings.events.social_send.on) {
    const columns = "select=id,kind,status,route,community,title,body,url,said,send_at,changed_at";
    const [moved, byHand] = await Promise.all([
      read(`social_sends?test=eq.${pool.test}&status=in.(sent,failed,sending)&changed_at=gte.${since}&${columns}&limit=200`),
      read(`social_sends?test=eq.${pool.test}&status=eq.scheduled&route=eq.by_hand&${columns}&limit=200`),
    ]);
    for (const one of [...moved, ...byHand]) {
      if (!one.send_at) continue;
      const unsure = one.status === "sending" && (String(one.said || "").startsWith("Unsure: ")
        || now - Date.parse(one.changed_at) > 5 * MINUTE);
      const how = one.status === "sent" ? "went" : one.status === "failed" ? "failed" : unsure ? "unsure"
        : one.status === "scheduled" && Date.parse(one.send_at) <= now ? "due" : null;
      if (!how) continue;
      raised.push({ event: "social_send", ...pool, key: `${one.id}:${how}`, detail: { id: one.id, how, kind: one.kind,
        community: one.community, title: clip(one.title || one.body, 120), url: /^https:\/\//.test(String(one.url || "")) ? one.url : null,
        said: one.status === "failed" ? clip(one.said, 200) : null } });
    }
  }
  await keepEvents(raised);
}

// ---------------------------------------------------------------------------
// The mail: each event a line and a link; one mail a kind, a digest, a fold.

const LABEL = { bug: "Bug report", idea: "Idea", question: "Question" };
const SEND_HOW = { went: "went", failed: "did not go", unsure: "may be up, or not: look on the network", due: "is due: post it by hand" };

/// How [came] reads: "from reddit.com, utm reddit / social / launch".
function cameSaid(came) {
  if (!came) return "";
  const tags = [came.source, came.medium, came.campaign].filter(Boolean).join(" / ");
  return [came.referrer ? `from ${came.referrer}` : "", tags ? `tags ${tags}` : ""].filter(Boolean).join(", ");
}

const quoted = (words, most = 90) => {
  const text = clip(words, 2000);
  return `“${text.length > most ? `${text.slice(0, most - 1)}…` : text}”`;
};

/// [one] event as a line of the mail and its link. [ctx]: {origin, admin(hash)}.
function lineOf(one, ctx) {
  const d = one.detail || {};
  const who = d.handle ? `@${d.handle}` : one.event === "signup" ? "Someone new" : d.email || "Someone";
  switch (one.event) {
    case "signup": {
      const came = cameSaid(d.came);
      const how = d.via === "orangecheck" ? " with orangecheck" : "";
      const yet = d.signed_in === false ? " (no code typed yet)" : "";
      return { text: `${who} signed up${how}${came ? `, ${came}` : ", nothing said of how they came"}${yet}`,
        link: one.account ? ctx.admin(`people/${one.account}`) : ctx.admin("people") };
    }
    case "first_model":
      return { text: `${who} published their first model, ${quoted(d.name, 60)}${d.parts ? ` (${d.parts} parts)` : ""}, `
        + `${d.listed ? "in the gallery" : "at its link"}`, link: d.id ? `${ctx.origin}/m/${enc(d.id)}` : ctx.admin("gallery") };
    case "feedback": {
      // The account by its handle, laid in as the mail is made (named), or
      // signed out: never an address, even in part (docs/OWNER_NOTIFY.md).
      const from = d.handle ? `@${d.handle}` : one.account ? "someone signed in, with no handle yet" : "someone signed out";
      return { text: `${LABEL[d.kind] || "Feedback"}${d.beta ? " from a tester" : ""} from ${from}: ${quoted(d.words)}`,
        link: d.id ? ctx.admin(`feedback-${d.id}`) : ctx.admin("feedback") };
    }
    case "plan": {
      const plan = d.plan ? `${String(d.plan).replace(/^./, (c) => c.toUpperCase())}` : "a plan";
      const said = d.how === "bought" ? `bought ${plan}${d.interval ? ` (${d.interval}ly)` : ""}`
        : d.how === "failed" ? `a payment failed (${plan})`
          : d.how === "grace" ? "a payment failed and the grace ran out: back to Free"
            : d.how === "cancelling" ? `cancelled ${plan}${d.ends ? `: it ends ${String(d.ends).slice(0, 10)}` : ""}`
              : d.how === "ended" ? `${plan} ended` : `changed to ${plan}`;
      return { text: `${who}: ${said}`, link: one.account ? ctx.admin(`people/${one.account}`) : ctx.admin("plans") };
    }
    case "errors": {
      const top = Array.isArray(d.top) && d.top.length ? `; most from ${d.top.slice(0, 3).map((t) => `${t.what} (${t.n})`).join(", ")}` : "";
      return { text: `${d.count} server errors in the last hour, past your ${d.threshold}${top}`, link: ctx.admin("site") };
    }
    case "quota":
      if (d.what === "restricted" || d.what === "down") {
        return { text: d.what === "restricted" ? `Supabase is refusing the project: ${d.said || "lift it at the organization's Billing"}`
          : `Supabase is not answering: ${d.said || "see status.supabase.com"}`, link: ctx.admin("site") };
      }
      return { text: `The ${d.what} is at ${d.percent}% of its ${d.quota_gb} GB (your line: ${d.threshold}%)`, link: ctx.admin("data") };
    case "social":
      return { text: `${d.kind === "message" ? "A message" : d.kind === "mention" ? "A mention" : "A reply"} from `
        + `${d.author ? `u/${d.author}` : "someone"}${d.community ? ` in r/${d.community}` : ""}: ${quoted(d.words || d.subject)}`,
      link: d.url || ctx.admin("social/inbox") };
    case "social_send":
      return { text: `Your scheduled ${d.kind === "reply" ? "reply" : "post"}${d.community ? ` to r/${d.community}` : ""}, `
        + `${quoted(d.title, 60)}, ${SEND_HOW[d.how] || d.how}${d.said ? `: ${d.said}` : ""}`,
      link: d.how === "went" && d.url ? d.url : ctx.admin("social/sent") };
    default:
      return { text: one.event, link: ctx.admin("notifications") };
  }
}

/// A one-kind mail's subject.
function subjectOf(event, items, ctx) {
  const one = EVENTS[event];
  if (items.length > 1) return `${items.length} ${one.many}`;
  const d = items[0].detail || {};
  switch (event) {
    case "signup": return d.handle ? `New sign-up: @${d.handle}` : "A new sign-up";
    case "first_model": return `First model published: ${quoted(d.name, 50)}`;
    case "feedback": return `${LABEL[d.kind] || "Feedback"}: ${quoted(d.words, 50)}`;
    case "errors": return `Server errors: ${d.count} in an hour`;
    case "quota": return d.what === "restricted" ? "Supabase is refusing the project" : d.what === "down" ? "Supabase is not answering"
      : `Supabase: the ${d.what} at ${d.percent}%`;
    case "social_send": return `Scheduled ${d.kind === "reply" ? "reply" : "post"} ${SEND_HOW[d.how]?.split(":")[0] || d.how}`;
    default: return lineOf(items[0], ctx).text.slice(0, 120);
  }
}

const escape = (text) => String(text ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;",
  "'": "&#39;" })[c]);

/// A mail of [groups] ([{event, items}]): its subject, words and HTML.
/// [title] heads it; [offs] are the kinds it offers to turn off.
function render({ subject, title, groups, ctx, foot }) {
  const text = [title, ""];
  const html = [];
  for (const group of groups) {
    const one = EVENTS[group.event];
    const listed = group.items.slice(0, LISTED).map((item) => lineOf(item, ctx));
    const more = group.items.length - listed.length;
    const section = ctx.admin(one.section);
    if (groups.length > 1) text.push(`${group.items.length} ${group.items.length === 1 ? one.one : one.many}`);
    for (const line of listed) text.push(`- ${line.text}`, `  ${line.link}`);
    if (more > 0) text.push(`- and ${more} more: ${section}`);
    text.push(`Turn off "${one.name}": ${ctx.off(group.event)}`, "");
    html.push(`${groups.length > 1 ? `<h2 style="font-size:16px;margin:20px 0 8px">${escape(`${group.items.length} `
      + `${group.items.length === 1 ? one.one : one.many}`)}</h2>` : ""}
<ul style="padding:0;margin:0 0 8px;list-style:none">
${listed.map((line) => `  <li style="margin:0 0 10px;padding:10px 12px;border:1px solid #e3e5e8;border-radius:10px"><a href="${escape(line.link)}" style="color:#14181d;text-decoration:none">${escape(line.text)}</a></li>`).join("\n")}
${more > 0 ? `  <li style="margin:0 0 10px"><a href="${escape(section)}">And ${more} more, in the console</a></li>` : ""}
</ul>
<p style="margin:0 0 8px;font-size:14px"><a href="${escape(section)}">Open in the console</a> · <a href="${escape(ctx.off(group.event))}" style="color:#5b6472">Turn off “${escape(one.name)}”</a></p>`);
  }
  if (foot) text.push(foot, "");
  text.push(`What mails you, and when: ${ctx.admin("notifications")}`, `To ${ctx.to}${ctx.test ? " (the checks' own)" : ""}`);
  const page = `<!doctype html>
<div style="font:16px/1.5 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;color:#14181d;max-width:560px;margin:0 auto;padding:20px 16px;background:#ffffff">
<p style="margin:0 0 4px;font-size:13px;color:#5b6472">Brickworks · notifications${ctx.test ? " · the checks' own" : ""}</p>
<h1 style="font-size:19px;line-height:1.3;margin:0 0 16px">${escape(title)}</h1>
${html.join("\n")}
${foot ? `<p style="margin:16px 0 0;font-size:14px;color:#5b6472">${escape(foot)}</p>` : ""}
<p style="margin:24px 0 0;font-size:13px;color:#5b6472"><a href="${escape(ctx.admin("notifications"))}" style="color:#5b6472">What mails you, and when</a> · to ${escape(ctx.to)}</p>
</div>`;
  return { subject: clip(subject, 200), text: text.join("\n"), html: page };
}

// ---------------------------------------------------------------------------
// Sending, and keeping what was sent.

/// [mail] sent to [to] through Resend with the site's own sending key:
/// {state: sent | dry | failed, id, said}. dry: to a test inbox from a
/// deployment with no key (a unit's preview). Never throws.
async function deliver(to, mail) {
  const key = process.env.RESEND_API_KEY;
  if (!to || !EMAIL.test(to)) return { state: "failed", said: "No address to send to: MASTER_EMAIL is not set here." };
  if (!key) {
    return TEST_ADDRESS.test(to) ? { state: "dry", said: "No mail key here: kept as Resend's test inbox would have had it." }
      : { state: "failed", said: "This deployment has no RESEND_API_KEY, so it sends no mail." };
  }
  try {
    const reply = await fetch("https://api.resend.com/emails", {
      method: "POST",
      // An alarm's key: Resend sends one mail a key in 24 hours, however
      // often it is asked (its idempotency keys).
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json",
        ...(mail.once ? { "Idempotency-Key": mail.once } : {}) },
      body: JSON.stringify({ from: process.env.EMAIL_FROM || SENDER, to: [to], subject: mail.subject, text: mail.text, html: mail.html,
        // A one-kind mail's "turn this off" as the mail app's own button
        // (RFC 8058: List-Unsubscribe with List-Unsubscribe-Post).
        ...(mail.headers ? { headers: mail.headers } : {}),
        // What kind of mail it is, in Resend's word of it (/admin#mail).
        tags: [{ name: "kind", value: "owner_notify" }] }),
      signal: AbortSignal.timeout(10000),
    });
    const said = await reply.json().catch(() => ({}));
    if (reply.ok && typeof said?.id === "string") return { state: "sent", id: said.id };
    return { state: "failed", said: clip(`Resend said ${reply.status}${said?.message ? `: ${said.message}` : ""}`, 280) };
  } catch (trouble) {
    return { state: "failed", said: clip(`Resend was not reached: ${trouble?.message || trouble}`, 280) };
  }
}

/// The console's audit of a mail: actor "notifications", kind "notification".
async function audit(pool, op, target, said, status = 200, refusal = null) {
  try {
    await db("rpc/admin_audit_note", { method: "POST", body: { p_actor: "notifications", p_account: null, p_op: op,
      p_kind: "notification", p_target: clip(target, 200), p_detail: { asked: {}, said }, p_status: status,
      p_said: refusal ? clip(refusal, 300) : null, p_test: pool.test, p_scope: pool.scope } });
  } catch (trouble) {
    if (!notYet(trouble)) console.error(`notify: audit: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
}

const newId = () => Array.from(randomBytes(12), (byte) => "abcdefghijklmnopqrstuvwxyz0123456789"[byte % 36]).join("");

/// [ids] moved from [from] to [change] when they are still in [from]: the
/// rows moved, so two runs at once never both take one.
async function move(ids, from, change) {
  if (!ids.length) return [];
  const rows = [];
  for (let at = 0; at < ids.length; at += 100) {
    const moved = await db(`owner_notify_events?id=in.(${ids.slice(at, at + 100).join(",")})&state=eq.${from}`, { method: "PATCH",
      prefer: "return=representation", body: { ...change, changed_at: new Date().toISOString() } });
    if (Array.isArray(moved)) rows.push(...moved);
  }
  return rows;
}

/// One mail of [events] (already taken: state sending) sent and kept: the
/// mail's row, the events mailed (or back to wait, or given up after
/// TRIES), and the audit. {id, kind, event, subject, state, events}.
async function sendKept(pool, row, { kind, event = null, mail, events, ctx }) {
  const to = addressOf(row, pool);
  const went = await deliver(to, mail);
  const id = newId();
  const ok = went.state !== "failed";
  let kept = false;
  try {
    await db("owner_notify_mails", { method: "POST", body: { id, scope: pool.scope, test: pool.test, at: new Date().toISOString(), kind,
      event, subject: clip(mail.subject, 300), body: mail.text.slice(0, 8000), events: events.length, sent_to: inPart(to),
      state: went.state, resend_id: went.id || null, said: went.said ? clip(went.said, 300) : null } });
    kept = true;
  } catch (trouble) {
    console.error(`notify: a mail not kept: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  const ids = events.map((one) => one.id);
  // Mailed either way: a mail not kept is still not sent twice.
  if (ok) await move(ids, "sending", { state: "mailed", mail: kept ? id : null });
  else {
    const last = events.filter((one) => (one.tries || 0) + 1 >= TRIES).map((one) => one.id);
    const again = events.filter((one) => (one.tries || 0) + 1 < TRIES);
    await move(last, "sending", { state: "failed", tries: TRIES });
    for (const one of again) await move([one.id], "sending", { state: "capped", tries: (one.tries || 0) + 1 });
  }
  await audit(pool, ok ? (kind === "fold" ? "notify_folded" : "notify_sent") : "notify_failed", event || kind,
    { mail: id, kind, events: events.length, to: inPart(to), state: went.state },
    ok ? 200 : 502, ok ? null : went.said);
  return { id, kind, event, subject: mail.subject, state: went.state, events: events.length, said: went.said || null };
}

/// The handles, and whether each has signed in, of the accounts [events]
/// name: laid into their detail for the mail's lines. Best effort.
async function named(events) {
  const accounts = [...new Set(events.map((one) => one.account).filter(Boolean))].slice(0, 50);
  if (!accounts.length) return events;
  const handles = new Map();
  try {
    for (const one of await db(`people?account=in.(${accounts.join(",")})&select=account,handle`)) handles.set(one.account, one.handle);
  } catch { /* no profile read: the address in part says who */ }
  const signedIn = new Map();
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY;
  await Promise.all(events.filter((one) => one.event === "signup" && one.account).slice(0, LISTED).map(async (one) => {
    try {
      const reply = await fetch(`${base}/auth/v1/admin/users/${one.account}`, { headers: { apikey: key, authorization: `Bearer ${key}` },
        signal: AbortSignal.timeout(5000) });
      if (reply.ok) signedIn.set(one.account, Boolean((await reply.json())?.last_sign_in_at));
    } catch { /* unknown: said as nothing */ }
  }));
  return events.map((one) => ({ ...one, detail: { ...one.detail, ...(handles.get(one.account) ? { handle: handles.get(one.account) } : {}),
    ...(signedIn.has(one.account) ? { signed_in: signedIn.get(one.account) } : {}) } }));
}

/// The links of [pool]'s mail: the console's (the checks' own on ?tests=1),
/// and each kind's one-click off.
function contextOf(pool, row) {
  const origin = originFor(pool.scope);
  return {
    origin,
    test: pool.test,
    to: inPart(addressOf(row, pool)),
    admin: (hash) => `${origin}/admin${pool.test ? "?tests=1" : ""}#${hash}`,
    off: (event) => `${origin}/admin${pool.test ? "?tests=1" : ""}#notifications/off/${event}/${pool.test ? "t" : "r"}/`
      + `${offToken(row, pool, event)}`,
    // The same, as a mail app's one-click POST (RFC 8058).
    unsubscribe: (event) => ({ "List-Unsubscribe": `<${origin}/api/plans?op=notify_off&event=${event}&pool=${pool.test ? "t" : "r"}`
      + `&token=${offToken(row, pool, event)}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" }),
  };
}

const countOf = (groups) => groups.map((group) => `${group.items.length} ${group.items.length === 1 ? EVENTS[group.event].one
  : EVENTS[group.event].many}`).join(", ");
const byKind = (events) => FIRST.filter((name) => events.some((one) => one.event === name))
  .map((name) => ({ event: name, items: events.filter((one) => one.event === name) }));

// ---------------------------------------------------------------------------
// The run: what waits, decided and mailed.

/// [pool]'s events mailed as its settings say, at [now]. [force] (the
/// owner's Check now): the readings looked at now, and nothing waits for
/// its kind's burst to end. {state, mails, held, capped, digest, ...}.
export async function flush(pool, { now = Date.now(), force = false } = {}) {
  let row = await rowOf(pool);
  const settings = settingsOf(row, pool);
  const out = { pool: `${pool.scope}${pool.test ? " (the checks' own)" : ""}`, active: settings.active, paused: settings.paused,
    mails: [], held: 0, capped: 0, digest: 0, off: 0 };
  if (settings.active && !settings.paused) {
    if (!row) row = await rowMade(pool);
    // Each look on its own: one that fails leaves the others, and the mail.
    for (const look of [() => lookErrors(pool, settings, now), () => lookQuota(pool, settings, now, force),
      () => lookSocial(pool, settings, now)]) {
      await look().catch((trouble) => console.error(`notify: a look failed: ${String(trouble?.message || trouble).slice(0, 160)}`));
    }
  }
  // A run cut off mid-send leaves events "sending": after ten minutes they wait again.
  const stuck = await db(`owner_notify_events?${where(pool)}&state=eq.sending&changed_at=lt.${new Date(now - 10 * MINUTE).toISOString()}`
    + "&select=id&limit=500");
  await move(stuck.map((one) => one.id), "sending", { state: "capped" });

  const waiting = await db(`owner_notify_events?${where(pool)}&state=in.(new,held,capped)&select=id,event,key,account,at,detail,state,tries`
    + "&order=at.asc&limit=500");
  // Each new one decided: not mailed (paused, off), for the digest, or to go.
  const fresh = waiting.filter((one) => one.state === "new");
  const decide = (one) => (!settings.active || settings.paused ? "paused" : !settings.events[one.event]?.on ? "off"
    : settings.events[one.event].when === "digest" ? "digest" : "go");
  for (const state of ["paused", "off", "digest"]) {
    const moved = await move(fresh.filter((one) => decide(one) === state).map((one) => one.id), "new", { state });
    if (state === "digest") out.digest += moved.length;
    if (state === "off") out.off += moved.length;
  }
  if (!settings.active || settings.paused) return { ...out, state: settings.paused ? "paused" : "not set here" };

  const local = localOf(now, settings.tz);
  const ready = fresh.filter((one) => decide(one) === "go");
  const held = waiting.filter((one) => one.state === "held");
  const capped = waiting.filter((one) => one.state === "capped");
  if (quietAt(settings, local.hhmm)) {
    const moved = await move(ready.map((one) => one.id), "new", { state: "held" });
    if (moved.length) {
      await audit(pool, "notify_held", "quiet hours", { events: moved.length, until: settings.quiet.to,
        kinds: countOf(byKind(moved)) });
    }
    return { ...out, held: moved.length, state: `quiet until ${settings.quiet.to}` };
  }

  // A kind still arriving waits, unless it has waited MOST_WAIT already.
  const groups = byKind(ready).filter((group) => {
    const first = Date.parse(group.items[0].at);
    const last = Date.parse(group.items[group.items.length - 1].at);
    return force || now - last >= GAP || now - first >= MOST_WAIT;
  });
  const since = new Date(now - HOUR).toISOString();
  const lastHour = await db(`owner_notify_mails?${where(pool)}&at=gte.${since}&kind=in.(now,digest,fold)&state=in.(sent,dry)&select=id`);
  let room = settings.cap - lastHour.length;
  const ctx = contextOf(pool, row);
  let fold = [...held, ...capped];
  if (room <= 0) {
    const moved = await move(groups.flatMap((group) => group.items.map((one) => one.id)), "new", { state: "capped" });
    if (moved.length) {
      await audit(pool, "notify_held", "the hour's cap", { events: moved.length, cap: settings.cap, kinds: countOf(byKind(moved)) });
    }
    return { ...out, capped: moved.length, state: `the hour's ${settings.cap} mails are sent` };
  }
  const alone = [...groups];
  while (alone.length && alone.length + (fold.length ? 1 : 0) > room) fold = [...fold, ...alone.pop().items];

  for (const group of alone) {
    const taken = await move(group.items.map((one) => one.id), "new", { state: "sending" });
    if (!taken.length) continue;
    const items = await named(taken);
    const mail = { ...render({ subject: subjectOf(group.event, items, ctx), title: subjectOf(group.event, items, ctx),
      groups: [{ event: group.event, items }], ctx }), headers: ctx.unsubscribe(group.event) };
    out.mails.push(await sendKept(pool, row, { kind: "now", event: group.event, mail, events: taken, ctx }));
    room -= 1;
  }
  if (fold.length && room > 0) {
    const taken = [];
    for (const state of ["new", "held", "capped"]) {
      taken.push(...await move(fold.filter((one) => one.state === state).map((one) => one.id), state, { state: "sending" }));
    }
    if (taken.length) {
      const items = await named(taken.sort((a, b) => Date.parse(a.at) - Date.parse(b.at)));
      const quiet = held.length > 0;
      const groupsOf = byKind(items);
      // "And N more" follows a mail: this run's, the hour's, or one an
      // earlier hour's cap held these past. Alone, it is the hour's own
      // (onreview C: at a cap of 1 the hour's first was "And 2 more").
      const follows = out.mails.length > 0 || lastHour.length > 0 || capped.length > 0;
      const title = quiet ? `While quiet hours were on: ${countOf(groupsOf)}`
        : follows ? `And ${items.length} more: ${countOf(groupsOf)}` : `This hour: ${countOf(groupsOf)}`;
      const most = `At most ${settings.cap} ${settings.cap === 1 ? "mail" : "mails"} an hour`;
      const foot = quiet ? "Held while your quiet hours were on, and sent as they ended."
        : follows ? `${most}: what came past them is here, in one.` : `${most}: what came is here, in one.`;
      out.mails.push(await sendKept(pool, row, { kind: "fold", mail: render({ subject: title, title, groups: groupsOf, ctx, foot }),
        events: taken, ctx }));
      room -= 1;
    }
  }

  // The day's digest, once a day: that of the last day whose time has come
  // (today's once it is past, else yesterday's), sent once quiet hours
  // allow, so a time inside quiet hours goes as they end (onreview A: 23:00
  // inside 22:00-07:00 never went, its events kept to the 90-day prune). A
  // pool's first is today's: before it there was no day to tell of.
  const due = local.hhmm >= settings.digest_at ? local.date : dayBefore(local.date);
  const last = row?.digest_on ? String(row.digest_on).slice(0, 10) : null;
  if (!last && due !== local.date) await writeRow(pool, () => ({ digest_on: due }));
  else if (!last || last < due) {
    if (room <= 0) return { ...out, state: "the digest waits for the hour's cap" };
    const day = await db(`owner_notify_events?${where(pool)}&state=eq.digest&select=id,event,key,account,at,detail,state,tries`
      + "&order=at.asc&limit=1000");
    const taken = await move(day.map((one) => one.id), "digest", { state: "sending" });
    if (taken.length) {
      const items = await named(taken);
      const groupsOf = byKind(items);
      const title = `Your Brickworks day: ${countOf(groupsOf)}`;
      const when = digestTime(settings);
      out.mails.push(await sendKept(pool, row, { kind: "digest", mail: render({ subject: title, title, groups: groupsOf, ctx,
        foot: `Your daily digest, at ${settings.digest_at} (${settings.tz})${when.held_until ? `, ${when.said}` : ""}.` }),
      events: taken, ctx }));
    }
    await writeRow(pool, () => ({ digest_on: due }));
  }
  return { ...out, state: "done" };
}

/// What was asked to be mailed, kept no longer than needed: a test's events
/// a week, the rest and the mails 90 days (as the privacy page says of
/// how a person came), the errors two days.
async function prune(now) {
  const before = (ms) => new Date(now - ms).toISOString();
  await db(`owner_notify_events?test=eq.true&at=lt.${before(7 * DAY)}`, { method: "DELETE" });
  await db(`owner_notify_events?at=lt.${before(90 * DAY)}`, { method: "DELETE" });
  await db(`owner_notify_mails?at=lt.${before(90 * DAY)}`, { method: "DELETE" });
  await db(`owner_notify_errors?at=lt.${before(2 * DAY)}`, { method: "DELETE" });
}

/// The old rows pruned once a UTC day, by the first run of it: the day kept
/// in [scope]'s own pool's row (pruned_on, supabase/owner_notify2.sql), as
/// the digest's is. A run that missed 03:00-03:04 UTC missed the day
/// (onreview). Before that file, or with no row, any run in the hour from
/// 03:00 UTC prunes, as each prune of a pruned table deletes nothing. Whether
/// it pruned.
async function pruneDue(now, scope) {
  const day = new Date(now).toISOString().slice(0, 10);
  const pool = { scope, test: false };
  const row = await rowOf(pool);
  if (row && "pruned_on" in row) {
    if (String(row.pruned_on || "").slice(0, 10) >= day) return false;
    await prune(now);
    await writeRow(pool, () => ({ pruned_on: day }));
    return true;
  }
  if (new Date(now).getUTCHours() !== 3) return false;
  await prune(now);
  return true;
}

/// The cron's run: [scope]'s two pools (brickworks.diy's, from Vercel's
/// cron), and once a day the old rows.
export async function notifyDue({ now = Date.now(), scope = "live" } = {}) {
  const runs = [];
  for (const test of [false, true]) runs.push(await flush({ scope, test }, { now }));
  const pruned = await pruneDue(now, scope);
  const mails = runs.flatMap((one) => one.mails);
  return { outcome: mails.length ? `${mails.filter((one) => one.state !== "failed").length} mailed, `
    + `${mails.filter((one) => one.state === "failed").length} failed` : "nothing to mail",
  sent: mails.filter((one) => one.state !== "failed").length, failed: mails.filter((one) => one.state === "failed").length,
  pools: runs.map((one) => `${one.pool}: ${one.state}`), pruned };
}

// ---------------------------------------------------------------------------
// The console's ops (api/admin.js, after its owner check).

const bodyOf = (request) => {
  if (typeof request.body !== "string") return request.body && typeof request.body === "object" ? request.body : {};
  try {
    return JSON.parse(request.body) || {};
  } catch {
    return {};
  }
};

/// [read], or NOT_APPLIED's 503 when the file is not applied.
async function applied(read) {
  try {
    return await read();
  } catch (trouble) {
    if (notYet(trouble)) throw new AuthError(NOT_APPLIED, 503);
    throw trouble;
  }
}

/// The samples a test of each kind mails, as its real one would.
const SAMPLES = {
  signup: [{ account: null, detail: { handle: "ada", came: { referrer: "www.reddit.com", source: "reddit",
    campaign: "launch" }, signed_in: true } }],
  first_model: [{ detail: { handle: "ada", name: "Lighthouse on the rocks", parts: 412, listed: true } }],
  feedback: [{ detail: { kind: "bug", handle: "ada", words: "The bin forgets my parts after a reload." } }],
  plan: [{ detail: { handle: "ada", how: "bought", plan: "pro", interval: "month" } }],
  errors: [{ detail: { count: 34, threshold: 20, top: [{ what: "share publish", n: 30 }, { what: "people feed_count", n: 4 }] } }],
  quota: [{ detail: { what: "database", percent: 83.4, quota_gb: 8, threshold: 80 } }],
  social: [{ detail: { kind: "reply", author: "brickfan", community: "lego", words: "Does it export to LDraw?" } }],
  social_send: [{ detail: { how: "went", kind: "post", community: "lego", title: "A free LEGO CAD in the browser" } }],
};

/// GET /api/admin?op=notify[&mail=ID][&tests=1]: everything the section
/// shows, or one mail's words.
export async function notifyRead(request, tests) {
  const pool = poolOf(request, tests);
  const mailId = String(request.query?.mail || "");
  if (mailId) {
    if (!/^[a-z0-9]{12}$/.test(mailId)) throw new AuthError("name a mail: ?mail=<its id>", 400);
    const rows = await applied(() => db(`owner_notify_mails?id=eq.${mailId}&${where(pool)}&select=*`));
    if (!rows.length) throw new AuthError("no such mail", 404);
    return { mail: rows[0] };
  }
  const catalog = Object.entries(EVENTS).map(([id, one]) => ({ id, name: one.name, says: one.says, threshold: one.threshold || null,
    sizes: one.sizes || null, default: { on: one.on, when: one.when } }));
  const base = { scope: pool.scope, test: pool.test, catalog, not_here: NOT_HERE, mail_key: Boolean(process.env.RESEND_API_KEY),
    cron: "every five minutes, on brickworks.diy", after: afterHow() };
  let row;
  try {
    row = await rowOf(pool);
  } catch (trouble) {
    if (notYet(trouble)) return { ...base, applied: false, said: NOT_APPLIED, settings: settingsOf(null, pool) };
    throw trouble;
  }
  const settings = settingsOf(row, pool);
  const now = Date.now();
  const local = localOf(now, settings.tz);
  const count = (state) => dbCount(`owner_notify_events?${where(pool)}&state=eq.${state}`).catch(() => null);
  const { auditOf } = await import("./_console.js");
  const [recent, mails, lastHour, held, capped, digest, fresh, sent] = await Promise.all([
    db(`owner_notify_events?${where(pool)}&select=id,event,account,at,detail,state,mail&order=at.desc&limit=30`),
    db(`owner_notify_mails?${where(pool)}&select=id,at,kind,event,subject,events,sent_to,state,said&order=at.desc&limit=50`),
    db(`owner_notify_mails?${where(pool)}&at=gte.${new Date(now - HOUR).toISOString()}&kind=in.(now,digest,fold)&state=in.(sent,dry)`
      + "&select=id"),
    count("held"), count("capped"), count("digest"), count("new"),
    auditOf({ tests: pool.test, kind: "notification", limit: 50 }).catch(() => null),
  ]);
  const ctx = contextOf(pool, row);
  return {
    ...base, applied: true, active: settings.active, set: settings.saved, set_at: row?.set_at || null, version: Number(row?.version) || 0,
    settings: { ...settings, active: undefined },
    address: { to: inPart(addressOf(row, pool)), own: !row?.address, account: inPart(accountAddress(pool)),
      pending: row?.pending_address ? inPart(row.pending_address) : null, pending_until: row?.pending_until || null },
    local: { ...local, tz: settings.tz }, quiet_now: quietAt(settings, local.hhmm),
    hour: { sent: lastHour.length, cap: settings.cap },
    digest: { ...digestTime(settings), last: row?.digest_on || null },
    waiting: { new: fresh, held, capped, digest },
    recent: recent.map((one) => ({ id: one.id, at: one.at, event: one.event, state: one.state, mail: one.mail,
      said: lineOf(one, ctx).text })),
    mails,
    // This deployment's own: the audit lists every deployment's acts of a pool.
    sent: sent?.rows ? sent.rows.filter((one) => one.scope === pool.scope) : null,
  };
}

/// POST op=notify_set {tz?, quiet?, digest_at?, cap?, paused?, events?}.
export async function notifySet(request, response, claims) {
  const pool = poolOf(request);
  await applied(() => rowOf(pool));
  const row = await writeRow(pool, (_, now) => ({ settings: changed(bodyOf(request), now) }), claims?.email);
  const settings = settingsOf(row, pool);
  // version: the row's after this write, so a page with two changes in
  // flight shows the one written last whichever answer comes last.
  return response.status(200).json({ settings: { ...settings, active: undefined }, active: true, scope: pool.scope,
    version: Number(row?.version) || 0, digest: { ...digestTime(settings), last: row?.digest_on || null },
    value: clip(JSON.stringify(bodyOf(request)), 120) });
}

/// POST op=notify_address {address}: another address, once the code mailed
/// to it is typed back (notify_confirm); empty, or the account's own: back
/// to the account's. The checks' own go only to Resend's test inbox.
export async function notifyAddress(request, response, claims) {
  const pool = poolOf(request);
  await applied(() => rowOf(pool));
  const asked = typed(bodyOf(request).address).toLowerCase();
  const own = accountAddress(pool);
  // Nothing waiting on a code any more, and mail where it was asked.
  const settled = (address) => ({ address, pending_address: null, pending_code: null, pending_until: null, pending_tries: 0 });
  if (!asked || asked === own) {
    await writeRow(pool, (row, settings) => ({ ...(row ? {} : { settings }), ...settled(null) }), claims?.email);
    return response.status(200).json({ to: inPart(own), own: true });
  }
  if (asked.length > 320 || !EMAIL.test(asked)) throw new AuthError("That is not an email address.", 400);
  if (pool.test && !TEST_ADDRESS.test(asked)) {
    throw new AuthError("The checks' own mail goes only to Resend's test inbox: an address at resend.dev.", 400);
  }
  const codes = await db(`owner_notify_mails?${where(pool)}&kind=eq.confirm&at=gte.${new Date(Date.now() - HOUR).toISOString()}`
    + "&select=id");
  if (codes.length >= CODES_AN_HOUR) throw new AuthError(`${CODES_AN_HOUR} codes an hour at most: try again later.`, 429);
  const made = await rowMade(pool);
  const code = String(randomInt(0, 1000000)).padStart(6, "0");
  const until = new Date(Date.now() + 30 * MINUTE).toISOString();
  await writeRow(pool, () => ({ pending_address: asked, pending_code: createHash("sha256").update(`${made.off_key}|${code}`)
    .digest("hex"), pending_until: until, pending_tries: 0 }), claims?.email);
  const words = `Your code to have Brickworks' notifications mailed here: ${code}\n\nType it in the console, under Notifications, `
    + `within 30 minutes. If you did not ask for this, nothing changes: mail stays where it was.`;
  const mail = { subject: `${code} is your code for Brickworks' notifications`, text: words,
    html: `<!doctype html><div style="font:16px/1.5 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;max-width:520px;margin:0 auto;padding:20px 16px"><p>Your code to have Brickworks' notifications mailed here:</p><p style="font-size:30px;font-weight:700;letter-spacing:.12em">${code}</p><p style="color:#5b6472">Type it in the console, under Notifications, within 30 minutes. If you did not ask for this, nothing changes.</p></div>` };
  const went = await deliver(asked, mail);
  const id = newId();
  await db("owner_notify_mails", { method: "POST", body: { id, scope: pool.scope, test: pool.test, at: new Date().toISOString(),
    kind: "confirm", subject: "A code for a new address (kept without it)", body: words.replace(code, "••••••"), events: 0,
    sent_to: inPart(asked), state: went.state, resend_id: went.id || null, said: went.said ? clip(went.said, 300) : null } })
    .catch(() => null);
  await audit(pool, went.state === "failed" ? "notify_failed" : "notify_sent", "a new address's code",
    { mail: id, kind: "confirm", to: inPart(asked), state: went.state }, went.state === "failed" ? 502 : 200, went.said);
  if (went.state === "failed") throw new AuthError(`The code did not go: ${went.said}`, 502);
  return response.status(200).json({ pending: inPart(asked), until, to: inPart(addressOf(made, pool)) });
}

/// POST op=notify_confirm {code}: the code mailed to the new address.
export async function notifyConfirm(request, response, claims) {
  const pool = poolOf(request);
  const row = await applied(() => rowOf(pool));
  const code = typed(bodyOf(request).code).replace(/[\s-]+/g, "");
  if (!/^\d{6}$/.test(code)) throw new AuthError("The code is six digits.", 400);
  if (!row?.pending_address) throw new AuthError("No address is waiting on a code.", 409);
  if (Date.parse(row.pending_until) < Date.now()) throw new AuthError("That code has run out: ask for another.", 409);
  if (row.pending_tries >= 5) throw new AuthError("Too many tries: ask for another code.", 409);
  if (!same(createHash("sha256").update(`${row.off_key}|${code}`).digest("hex"), row.pending_code)) {
    // Counted against the code it was typed for, never another asked since.
    await writeRow(pool, (now) => (now?.pending_code === row.pending_code ? { pending_tries: Math.min(10, now.pending_tries + 1) } : {}));
    throw new AuthError("That is not the code.", 400);
  }
  const kept = await writeRow(pool, (now) => {
    if (now?.pending_code !== row.pending_code) throw new AuthError("Another code was asked for since: type that one.", 409);
    return { address: now.pending_address, pending_address: null, pending_code: null, pending_until: null, pending_tries: 0 };
  }, claims?.email);
  return response.status(200).json({ to: inPart(kept.address), own: false });
}

/// POST op=notify_test {event?}: a test mailed now to the pool's address,
/// past the pause, quiet hours and the hour's cap; with [event], that kind's
/// mail as it will look, from a made-up sample.
export async function notifyTest(request, response) {
  const pool = poolOf(request);
  // No kind (absent, null, false or "") is a test of the whole.
  const asked = bodyOf(request).event ? String(bodyOf(request).event) : "";
  if (asked && !Object.hasOwn(EVENTS, asked)) throw new AuthError(`There is no notification called ${asked.slice(0, 40)}.`, 400);
  const settings = settingsOf(await applied(() => rowOf(pool)), pool);
  const row = await rowMade(pool);
  const recent = await db(`owner_notify_mails?${where(pool)}&kind=eq.test&at=gte.${new Date(Date.now() - HOUR).toISOString()}&select=id`);
  if (recent.length >= TESTS_AN_HOUR) throw new AuthError(`${TESTS_AN_HOUR} tests an hour at most: try again later.`, 429);
  const ctx = contextOf(pool, row);
  const mail = asked
    ? render({ subject: `[Test] ${subjectOf(asked, SAMPLES[asked].map((one) => ({ event: asked, ...one })), ctx)}`,
      title: `A test: this is how “${EVENTS[asked].name}” will look`, groups: [{ event: asked, items: SAMPLES[asked]
        .map((one) => ({ event: asked, ...one })) }], ctx, foot: "Made up for the test: nobody did this." })
    : render({ subject: "A test from Brickworks' notifications", title: "Notifications reach you here", groups: [], ctx,
      foot: `Mail about the site comes to this address${settings.paused ? ", once you take off Pause all" : ""}.` });
  const sent = await sendKept(pool, row, { kind: "test", event: asked || null, mail, events: [], ctx });
  if (sent.state === "failed") throw new AuthError(`The test did not go: ${sent.said}`, 502);
  return response.status(200).json({ outcome: sent.state, to: inPart(addressOf(row, pool)), subject: sent.subject, mail: sent.id });
}

/// POST op=notify_flush: the cron's run, now, for this deployment's pool:
/// the readings looked at and nothing waiting for its burst to end.
export async function notifyFlush(request, response) {
  const pool = poolOf(request);
  const out = await applied(() => flush(pool, { force: true }));
  return response.status(200).json({ outcome: out.state, mails: out.mails.length, held: out.held, capped: out.capped,
    digest: out.digest, sent: out.mails.map((one) => ({ subject: one.subject, state: one.state })) });
}

// ---------------------------------------------------------------------------
// The one-click link, and the cron (api/plans.js).

/// POST /api/plans?op=notify_off {event, pool: r | t, token}: [event] turned
/// off for this deployment's pool by a mail's one-click link (the console's
/// page, the owner signed in or not), or by the mail app's own button, which
/// posts the same in the address (RFC 8058). Anything not signed by the
/// pool's key: 404, as anybody else gets from the console.
export async function notifyOffRoute(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (request.method !== "POST") return response.status(405).json({ error: "POST" });
  const posted = bodyOf(request);
  const given = (name) => String((typeof posted[name] === "string" ? posted[name] : request.query?.[name]) ?? "");
  const event = given("event");
  const test = given("pool") === "t" ? true : given("pool") === "r" ? false : null;
  const token = given("token");
  const nothing = () => response.status(404).json({ error: "not found" });
  if (!Object.hasOwn(EVENTS, event) || test === null || !/^[0-9a-f]{32}$/.test(token) || !dbConfigured()) return nothing();
  const pool = { scope: scopeOf(request), test };
  let row;
  try {
    row = await rowOf(pool);
  } catch {
    return nothing();
  }
  if (!row || !same(offToken(row, pool, event), token)) return nothing();
  await writeRow(pool, (_, now) => {
    now.events[event].on = false;
    return { settings: now };
  }, "a one-click link in a mail");
  await audit(pool, "notify_off", event, { event, by: "the mail's one-click link" });
  return response.status(200).json({ event, name: EVENTS[event].name, off: true });
}

// What the run could not read: an alarm sent without the database.
let alarmedOn = "";

/// Supabase refusing the project, or not answering, when the cron's run
/// could not read its own tables: so nothing here can say what the owner
/// chose, nor count what was sent. One mail to the owner's own address, at
/// most one a day: this instance remembers the day, and Resend sends one
/// mail a key in 24 hours whichever instance asks. Null when Supabase
/// answers (the run failed for another reason, in the cron's record).
export async function alarm({ now = Date.now() } = {}) {
  const { supabaseHealth } = await import("./_console_site.js");
  const health = await supabaseHealth({ fresh: true }).catch(() => null);
  if (!health || health.ok) return null;
  const day = new Date(now).toISOString().slice(0, 10);
  if (alarmedOn === day) return { state: "already today" };
  const origin = originFor("live");
  const what = health.restricted ? "Supabase is refusing the project" : "Supabase is not answering";
  const words = [what, "", clip(health.fix || "", 400), "", `Where it shows: ${origin}/admin#site`, "",
    "Sent without your notification settings, which are in the database it could not read. At most one of these a day."];
  const mail = { subject: what, text: words.join("\n"), once: `owner-notify-alarm-${day}`,
    html: `<!doctype html><div style="font:16px/1.5 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;color:#14181d;max-width:560px;margin:0 auto;padding:20px 16px;background:#ffffff"><p style="margin:0 0 4px;font-size:13px;color:#5b6472">Brickworks · notifications</p><h1 style="font-size:19px;line-height:1.3;margin:0 0 16px">${escape(what)}</h1><p>${escape(health.fix || "")}</p><p><a href="${escape(`${origin}/admin#site`)}">Open Site in the console</a></p><p style="margin:16px 0 0;font-size:14px;color:#5b6472">Sent without your notification settings, which are in the database it could not read. At most one of these a day.</p></div>` };
  const went = await deliver(accountAddress({ scope: "live", test: false }), mail);
  if (went.state !== "failed") alarmedOn = day;
  return { state: went.state, said: went.said || null };
}

/// GET /api/plans?op=owner_notify: Vercel's cron (/api/plans/owner-notify,
/// every five minutes), with CRON_SECRET. Its runs written down when it
/// mailed or failed, or at the day's first run, so Site sees it alive
/// without a row every five minutes.
export async function notifyDueRoute(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const { cronNoted, isCron } = await import("./_cron.js");
  if (!isCron(request)) return response.status(401).json({ error: "the owner's notifications are the cron's" });
  const started = new Date().toISOString();
  // Vercel's cron runs brickworks.diy's; a run by hand (the console's Run
  // now, a check) only its own deployment's, so a preview never mails, nor
  // takes, what the site's own pool holds.
  const fromVercel = /^vercel-cron\b/.test(String(request.headers?.["user-agent"] || ""));
  let out;
  try {
    out = await notifyDue({ scope: fromVercel ? "live" : scopeOf(request) });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(200).json({ outcome: "not_applied", said: NOT_APPLIED });
    const said = String(trouble?.message || trouble).slice(0, 200);
    console.error(`notify: due: ${said}`);
    // The database itself refusing: told to the owner without it (the site's own run only).
    const alarmed = fromVercel ? await alarm().catch(() => null) : null;
    await cronNoted(request, "owner_notify", started, "failed", { error: said }).catch(() => null);
    return response.status(500).json({ error: "the owner's notifications stopped", ...(alarmed ? { alarm: alarmed.state } : {}) });
  }
  const now = new Date();
  if (out.sent || out.failed || (now.getUTCHours() === 0 && now.getUTCMinutes() < 5)
    || !/^vercel-cron\b/.test(String(request.headers?.["user-agent"] || ""))) {
    await cronNoted(request, "owner_notify", started, out.failed ? "failed" : "done", { outcome: out.outcome });
  }
  return response.status(200).json(out);
}
