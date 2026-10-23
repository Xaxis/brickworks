// Notifications apart from the feed (2026-10-22, docs/SOCIAL.md U7,
// supabase/notifications.sql). api/people.js answers the requests with
// these.
//
//   GET  ?op=notifications       (session) what happened to the caller's
//                                models in the last 90 days, grouped by
//                                model, the newest group first, each row
//                                with its words and its link; opening it
//                                clears the count on the avatar
//   POST ?op=notifications_read  (session) {model}: that model's read, as
//                                its group is opened; {all: true}: Mark all
//                                read
//   GET  ?op=feed_count          (session) {count, notifications, feed, me}:
//                                what is new for the avatar (the two
//                                together, as the app's Account says it),
//                                each apart for the account menu, and who
//                                the caller is, for their avatar
//
// A comment, a photo of a build, a remix, likes (a number a model a day,
// never who) and a challenge's end; and since replies.sql, a reply to your
// comment, or after yours in its thread, on anybody's model, grouped under
// that model. Nothing says who followed you: a
// follow tells nobody anything (supabase/follows.sql).
//
// Until notifications.sql is applied its functions are not there (404),
// and what the feed tells of your models is read from the feed of before
// (feed_of), likes from model_likes, and the feed's marks are the only
// ones: opening Notifications opens that feed, and what was seen is read.
// A challenge's end needs the file.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { withFaces } from "./_faces.js";
import { Unacceptable } from "./_directory.js";
import { pictureOf } from "./_card.js";

const NOT_THERE = /: 404$/;
const ID = /^[A-Za-z0-9]{10}$/;
const DAY = 864e5;

/// An rpc, or [missing]'s answer when its file is not applied.
async function call(name, body, missing) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || "")) && missing !== undefined) return missing();
    throw trouble;
  }
}

const who = async (request) => (bearer(request) ? (await verify(bearer(request))).sub : null);

const quoted = (text, most) => {
  const line = String(text ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim();
  return line.length > most ? `${line.slice(0, most - 1)}…` : line;
};

// ---------------------------------------------------------------------------
// Pure: what a notification says, and how they are grouped.

/// "today", "yesterday" or "on 3 October", for a day as YYYY-MM-DD (UTC).
export function dayWords(day, now = Date.now()) {
  const at = Date.parse(`${day}T00:00:00Z`);
  if (!Number.isFinite(at)) return "";
  const today = Math.floor(now / DAY) * DAY;
  if (at === today) return "today";
  if (at === today - DAY) return "yesterday";
  return `on ${new Date(at).toLocaleDateString("en-GB", { day: "numeric", month: "long", timeZone: "UTC" })}`;
}

/// One notification as a person reads it: {kind, at, who, by, did, said,
/// link}. [who] is whoever did it (null for likes and a challenge's end,
/// which name nobody); [did] the rest of the line; [said] their words.
export function noticeSaid(row, origin = "", now = Date.now()) {
  const by = row.by && row.by.handle ? { handle: row.by.handle, name: quoted(row.by.name, 40) } : null;
  const model = ID.test(String(row.model || "")) ? row.model : "";
  const base = { kind: row.kind, at: row.at, who: by ? by.name : null, by, said: "" };
  const onStep = row.step ? ` on step ${Number(row.step)}` : "";
  if (row.kind === "comment") {
    // A reply to somebody else's comment on your model is a comment on it.
    return { ...base, who: base.who || "A builder", did: row.parent ? `replied to a comment${onStep}` : `commented${onStep}`,
      said: quoted(row.said, 240), link: `${origin}/m/${model}#comment-${Number(row.comment)}` };
  }
  if (row.kind === "reply") {
    return { ...base, who: base.who || "A builder",
      did: row.yours === false ? `replied to a comment you answered${onStep}` : `replied to your comment${onStep}`,
      said: quoted(row.said, 240), link: `${origin}/m/${model}#comment-${Number(row.comment)}` };
  }
  if (row.kind === "photo") {
    return { ...base, who: base.who || "A builder", did: "posted a photo of their build", said: quoted(row.words, 140),
      link: `${origin}/m/${model}#photo-${String(row.photo || "").replace(/[^A-Za-z0-9]/g, "")}` };
  }
  if (row.kind === "remix") {
    return { ...base, who: base.who || "Somebody", did: `remixed it as “${quoted(row.name || "a model", 80)}”`,
      link: `${origin}/m/${model}` };
  }
  if (row.kind === "likes") {
    const n = Number(row.likes) || 0;
    return { ...base, did: `${n.toLocaleString("en-US")} new ${n === 1 ? "like" : "likes"} ${dayWords(row.day, now)}`.trim(),
      link: `${origin}/m/${model}` };
  }
  if (row.kind === "result") {
    const title = quoted(row.title || "the challenge", 80);
    const way = row.way === "assistant" ? "with the assistant" : "by hand";
    const votes = Number(row.votes) || 0;
    return row.won === true
      ? { ...base, did: `won “${title}” among the models built ${way}, with ${votes.toLocaleString("en-US")} ${votes === 1 ? "vote" : "votes"}`,
        link: `${origin}/challenge` }
      : { ...base, did: `“${title}” has ended: see who won`, link: `${origin}/challenge` };
  }
  return { ...base, did: "something happened", link: `${origin}/m/${model}` };
}

/// The rows of notification_list, grouped by the model they are about,
/// the newest group first and each group's rows newest first:
/// {groups: [{model, name, picture, link, at, new, unread, rows}], unread,
/// fresh}. A row is new when it came after the list was last opened
/// ([seen_at]; never opened, all are), and unread until its model's group
/// was opened after it ([reads]) or everything was marked read ([read_at]).
export function noticeGroups(page, origin = "", now = Date.now()) {
  const rows = Array.isArray(page?.rows) ? page.rows : [];
  const models = page?.models && typeof page.models === "object" ? page.models : {};
  const reads = page?.reads && typeof page.reads === "object" ? page.reads : {};
  const seen = page?.seen_at ? Date.parse(page.seen_at) : null;
  const allRead = page?.read_at ? Date.parse(page.read_at) : -Infinity;
  const groups = new Map();
  let unread = 0;
  let fresh = 0;
  for (const row of rows) {
    const on = String(row.on || "");
    if (!ID.test(on)) continue;
    const at = Date.parse(row.at);
    const readTo = Math.max(allRead, reads[on] ? Date.parse(reads[on]) : -Infinity);
    const said = { ...noticeSaid(row, origin, now), new: seen === null || at > seen, unread: at > readTo };
    if (said.unread) unread += 1;
    if (said.new) fresh += 1;
    if (!groups.has(on)) {
      const card = models[on] || {};
      const version = Date.parse(card.updated_at || "") || 0;
      groups.set(on, { model: on, name: quoted(card.name || row.of_name || row.name || "Your model", 80),
        picture: pictureOf({ id: on, image: card.has_image === true,
          thumb: card.has_thumb === true ? `${origin}/m/${on}.webp?v=${version.toString(36)}` : null }),
        link: `${origin}/m/${on}`, at: row.at, new: false, unread: false, rows: [] });
    }
    const group = groups.get(on);
    group.rows.push(said);
    group.new ||= said.new;
    group.unread ||= said.unread;
  }
  return { groups: [...groups.values()], unread, fresh };
}

// ---------------------------------------------------------------------------
// Before notifications.sql: the same rows, from the feed of before.

/// notification_list's answer, made from feed_of's rows of the caller's
/// own models and model_likes, the feed's seen_at its only mark.
async function listBefore(viewer, mark) {
  const page = await call("feed_of", { viewer, before: null, size: 50, mark }, () => null);
  if (!page) return null;
  const rows = (page.rows || [])
    .filter((row) => row.kind === "comment" || row.kind === "remix" || (row.kind === "photo" && row.yours === true))
    .map((row) => ({ ...row, on: row.kind === "remix" ? row.of : row.model }));
  const mine = await db(`shared_models?owner=eq.${viewer}&published=is.true&barred=is.false`
    + "&select=id,name,has_image,has_thumb,updated_at&order=updated_at.desc&limit=200");
  const since = new Date(Date.now() - 90 * DAY).toISOString();
  const likes = mine.length ? await db(`model_likes?model=in.(${mine.map((one) => one.id).join(",")})`
    + `&account=neq.${viewer}&at=gt.${since}&select=model,at&order=at.desc&limit=2000`) : [];
  const days = new Map();
  for (const like of likes) {
    const key = `${like.model} ${like.at.slice(0, 10)}`;
    const day = days.get(key) || { kind: "likes", at: like.at, on: like.model, model: like.model, likes: 0, day: like.at.slice(0, 10) };
    day.likes += 1;
    if (like.at > day.at) day.at = like.at;
    days.set(key, day);
  }
  const all = [...rows, ...days.values()].sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
  const models = Object.fromEntries(mine.map((one) => [one.id, one]));
  // Read is seen: the feed's opening is the only mark there is.
  return { rows: all.slice(0, 200), models, seen_at: page.seen_at ?? null, read_at: page.seen_at ?? null, reads: {},
    before: true };
}

// ---------------------------------------------------------------------------
// The requests.

export async function notifications(request, response, { origin }) {
  response.setHeader("Cache-Control", "private, no-store");
  const asker = await who(request);
  if (!asker) throw new Unacceptable("Sign in to see what happened to your models: we email you a code, no password.", 401);
  // Opened: what was counted is seen now.
  const page = await call("notification_list", { viewer: asker, mark: true }, () => ({ missing: true }));
  const read = page && page.missing ? await listBefore(asker, true) : page;
  if (!read) return response.status(200).json({ ready: false, groups: [], unread: 0, fresh: 0, kept: false });
  return response.status(200).json(await withFaces({ ready: true, kept: !read.before, seen_at: read.seen_at ?? null,
    ...noticeGroups(read, origin) }));
}

export async function notificationsRead(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const asker = await who(request);
  if (!asker) throw new Unacceptable("Sign in first: we email you a code, no password.", 401);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const model = body.all === true ? null : String(body.model ?? "");
  if (model !== null && !ID.test(model)) throw new Unacceptable("say which model, or all: true");
  const said = await call("notification_read", { viewer: asker, model }, () => ({ missing: true }));
  if (said && said.missing) {
    // Nothing is kept as read before the file; all read is the feed opened.
    if (model === null) await call("feed_of", { viewer: asker, before: null, size: 1, mark: true }, () => null);
    return response.status(200).json({ read: model === null, kept: false });
  }
  if (said?.refused) throw new Unacceptable("That is not one of your models.", 404);
  return response.status(200).json({ read: true, kept: true });
}

/// What is new for [asker]: {count, notifications, feed}; before the file,
/// the feed's count alone, as count, and null for each apart.
export async function newCounts(asker) {
  const both = await call("notification_counts", { viewer: asker }, () => ({ missing: true }));
  if (both && !both.missing) {
    const notices = Number(both.notifications) || 0;
    const feed = Number(both.feed) || 0;
    return { count: Math.min(notices + feed, 99), notifications: notices, feed, ready: true };
  }
  const count = await call("feed_count", { viewer: asker }, () => null);
  return { count: Number(count) || 0, notifications: null, feed: null, ready: count !== null };
}

export async function feedCount(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const asker = await who(request);
  if (!asker) return response.status(200).json({ count: 0, signed_in: false });
  const [counts, people] = await Promise.all([newCounts(asker),
    db(`people?account=eq.${asker}&select=handle,name`).catch(() => [])]);
  const person = people[0] || null;
  // Their own picture, for the avatar in the header (api/_faces.js).
  return response.status(200).json(await withFaces({ ...counts, signed_in: true,
    me: person ? { handle: person.handle, name: person.name } : null }));
}
