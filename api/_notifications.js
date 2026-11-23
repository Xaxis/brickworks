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
//                                its group is opened; {achievements: true}:
//                                the achievements' group read; {challenge}:
//                                that challenge's; {talk}: that thread of
//                                Talk's, read up to now; {announcement,
//                                clicked?}: that announcement's, its link followed or
//                                not; {all: true}: Mark all read
//   GET  ?op=feed_count          (session) {count, notifications, feed, me}:
//                                what is new for the avatar (the two
//                                together, as the app's Account says it),
//                                each apart for the account menu, and who
//                                the caller is, for their avatar; and
//                                notice_hidden, the ids of the site's
//                                notices they hid (supabase/announce2.sql),
//                                so every browser they use stops showing
//                                one at its next page (web/notice.js)
//
// A comment, a photo of a build, a remix, likes (a number a model a day,
// never who) and a challenge's end; and since replies.sql, a reply to your
// comment, or after yours in its thread, on anybody's model, grouped under
// that model. Since achievements.sql, each level of an achievement you
// reached, in a group of their own: a level is written down as the
// avatar's count is asked for (achievement_mark), so a page opened after
// it is reached tells it. Since challenge_notices.sql, a challenge
// opening, its last two days (not once you entered it) and, if you voted
// in it, who won, in a group a challenge. Since comment_mentions.sql, a
// comment or reply that names you (@your-handle), under its model, unless
// you hear of it already as its designer or in its thread. Since
// announce.sql, what the site's owner announced to you (/admin ›
// Announcements, api/_announce.js), each in a group of its own, until it is
// withdrawn. Since talk.sql, a post in a thread of Talk you follow (yours,
// or one you posted in) and a post there that names you, in a group a
// thread, read as the thread is opened. Nothing says
// who followed you: a follow tells nobody anything (supabase/follows.sql).
// Nothing by somebody you blocked (supabase/block.sql): their rows leave
// the list and the count on your avatar (api/_blocks.js).
//
// Until notifications.sql is applied its functions are not there (404),
// and what the feed tells of your models is read from the feed of before
// (feed_of), likes from model_likes, and the feed's marks are the only
// ones: opening Notifications opens that feed, and what was seen is read.
// A challenge's end needs the file.

import { bearer, isMaster, verify } from "./_auth.js";
import { db, dbAll, orUnknown } from "./_db.js";
import { promptNow, promptsById } from "./_prompts.js";
import { withFaces } from "./_faces.js";
import { scopeOf } from "./_settings.js";
import { Unacceptable, inLanguage, siteWords, testsAsked } from "./_directory.js";
import { counted, levelName, pictureOf, say } from "./_card.js";
import { blockCounts, blockedHandles, blockedModels, rowsWithout } from "./_blocks.js";
import { pinnedAmong } from "./_comments.js";

/// The kinds a pin is told by: a comment on your model, and a mention.
export const PINNABLE = new Set(["comment", "mention"]);

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

/// The levels [viewer] reached written down (supabase/achievements.sql),
/// so what is counted and listed next tells them; nothing before the file.
const marked = (viewer) => call("achievement_mark", { viewer }, () => 0);

const who = async (request) => (bearer(request) ? (await verify(bearer(request), request)).sub : null);

const quoted = (text, most) => {
  const line = String(text ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim();
  return line.length > most ? `${line.slice(0, most - 1)}…` : line;
};

// ---------------------------------------------------------------------------
// Pure: what a notification says, and how they are grouped.

/// "3 October", for a day as YYYY-MM-DD (UTC), as the language the
/// notices are said in writes it ("3. Oktober"); "" for none.
function dateWords(day) {
  const at = Date.parse(`${day}T00:00:00Z`);
  const code = globalThis.brickworksLang?.code;
  return Number.isFinite(at) ? new Date(at).toLocaleDateString(/^(?:de|fr|es)$/.test(code || "") ? code : "en-GB",
    { day: "numeric", month: "long", timeZone: "UTC" }) : "";
}

/// "today", "yesterday" or "on 3 October", for a day as YYYY-MM-DD (UTC).
export function dayWords(day, now = Date.now()) {
  const at = Date.parse(`${day}T00:00:00Z`);
  if (!Number.isFinite(at)) return "";
  const today = Math.floor(now / DAY) * DAY;
  if (at === today) return say("today");
  if (at === today - DAY) return say("yesterday");
  return say("on {day}", { day: dateWords(day) });
}

/// [text] in quotes as the language writes them: “Harbour”, „Harbour“.
const quote = (text) => say("“{text}”", { text });

/// What a challenge tells everybody who may enter it, or who voted in it.
const CHALLENGE = new Set(["challenge_open", "challenge_closing", "challenge_won"]);

/// An announcement's link: its own (a path on this site, or https), else
/// its place on the Notifications page.
const announcementLink = (row, origin) => {
  const link = String(row.link || "");
  if (/^https:\/\/[^\s/]+/.test(link)) return link;
  if (/^\/(?![/\\])/.test(link)) return `${origin}${link}`;
  return `${origin}/notifications#announcement-${Number(row.announcement) || 0}`;
};

/// An announcement's words as the owner wrote them: their lines kept.
const written = (text, most) => {
  const words = String(text ?? "").replace(/[\u0000-\u0009\u000b-\u001f\u007f]+/g, " ").replace(/[ ]{2,}/g, " ").trim();
  return words.length > most ? `${words.slice(0, most - 1)}…` : words;
};

/// A thread of Talk, at the post (api/_talk.js), a test one's as a test asks for it.
const talkLink = (row, origin) => `${origin}/talk/t/${Number(row.thread) || 0}${row.test === true ? "?tests=1" : ""}`
  + `#post-${Number(row.post) || 0}`;

/// A challenge's own page, a test one's as a test asks for it.
const challengeLink = (row, origin) =>
  `${origin}/challenge?id=${Number(row.challenge) || 0}${row.test === true ? "&tests=1" : ""}`;

/// One notification as a person reads it: {kind, at, who, by, said, link,
/// line}. [who] is whoever did it (null for likes and the challenges',
/// which name nobody); [said] their words; [line] the whole line, {who}
/// where whoever did it goes (web/notifications.js), in the language the
/// notices are asked in (?lang=, web/card.js say).
export function noticeSaid(row, origin = "", now = Date.now()) {
  const by = row.by && row.by.handle ? { handle: row.by.handle, name: quoted(row.by.name, 40) } : null;
  const model = ID.test(String(row.model || "")) ? row.model : "";
  const base = { kind: row.kind, at: row.at, who: by ? by.name : null, by, said: "" };
  const step = Number(row.step) || 0;
  // One of two sentences, on a step or not, its step said.
  const stepped = (on, off) => (step ? on.replace("{step}", String(step)) : off);
  if (row.kind === "comment") {
    // A reply to somebody else's comment on your model is a comment on it;
    // a pin (supabase/comment_pins.sql) is one on a part of it.
    return { ...base, who: base.who || say("A builder"), said: quoted(row.said, 240),
      link: `${origin}/m/${model}#comment-${Number(row.comment)}`, ...(row.pinned ? { pinned: true } : {}),
      line: row.parent ? stepped(say("{who} replied to a comment on step {step}"), say("{who} replied to a comment"))
        : row.pinned ? stepped(say("{who} commented on a part, step {step}"), say("{who} commented on a part"))
          : stepped(say("{who} commented on step {step}"), say("{who} commented")) };
  }
  if (row.kind === "reply") {
    return { ...base, who: base.who || say("A builder"), said: quoted(row.said, 240),
      link: `${origin}/m/${model}#comment-${Number(row.comment)}`,
      line: row.yours === false
        ? stepped(say("{who} replied to a comment you answered on step {step}"), say("{who} replied to a comment you answered"))
        : stepped(say("{who} replied to your comment on step {step}"), say("{who} replied to your comment")) };
  }
  if (row.kind === "mention") {
    // Named in a comment or a reply (supabase/comment_mentions.sql).
    return { ...base, who: base.who || say("A builder"), said: quoted(row.said, 240),
      link: `${origin}/m/${model}#comment-${Number(row.comment)}`,
      line: row.parent ? stepped(say("{who} mentioned you in a reply on step {step}"), say("{who} mentioned you in a reply"))
        : row.pinned ? stepped(say("{who} mentioned you in a comment on a part, step {step}"),
          say("{who} mentioned you in a comment on a part"))
          : stepped(say("{who} mentioned you in a comment on step {step}"), say("{who} mentioned you in a comment")) };
  }
  if (row.kind === "talk_reply" || row.kind === "talk_mention") {
    // In Talk (supabase/talk.sql): a post in a thread followed, or naming you.
    return { ...base, who: base.who || say("A builder"), said: quoted(row.said, 240), link: talkLink(row, origin),
      line: row.kind === "talk_mention" ? say("{who} mentioned you in Talk")
        : row.yours === true ? say("{who} replied in your thread") : say("{who} replied in a thread you follow") };
  }
  if (row.kind === "announcement") {
    // From the site's owner (supabase/announce.sql): its words, as written.
    return { ...base, who: "Brickworks", said: written(row.said, 1000), link: announcementLink(row, origin),
      edited: row.edited === true, line: row.edited === true ? say("From {who}, edited") : say("From {who}") };
  }
  if (row.kind === "photo") {
    return { ...base, who: base.who || say("A builder"), said: quoted(row.words, 140),
      link: `${origin}/m/${model}#photo-${String(row.photo || "").replace(/[^A-Za-z0-9]/g, "")}`,
      line: say("{who} posted a photo of their build") };
  }
  if (row.kind === "remix") {
    return { ...base, who: base.who || say("Somebody"), link: `${origin}/m/${model}`,
      line: say("{who} remixed it as {name}").replace("{name}", quote(quoted(row.name || say("a model"), 80))) };
  }
  if (row.kind === "likes") {
    return { ...base, link: `${origin}/m/${model}`,
      line: `${counted(Number(row.likes) || 0, "new like", "new likes")} ${dayWords(row.day, now)}`.trim() };
  }
  if (row.kind === "achievement") {
    const level = Number(row.level) || 0;
    return { ...base, who: say("You"), link: `${origin}/profile?tab=achievements`,
      line: say("{who} reached {name}, level {level} of {of}", { name: levelName(row.track, row.reached), level,
        of: Number(row.of) || level }) };
  }
  const title = quote(quoted(row.title || say("the challenge"), 80));
  if (CHALLENGE.has(row.kind) && row.prompt) {
    // A weekly quick build (api/_prompts.js): Start, not enter.
    const day = dateWords(row.ends_on);
    const line = row.kind === "challenge_closing"
      ? say("The last two days of this week's quick build, {title}: publish yours by the end of {day}", { title, day })
      : say("This week's quick build is {title}: start from its template, and publish by the end of {day}", { title, day });
    return { ...base, link: challengeLink(row, origin), line };
  }
  if (CHALLENGE.has(row.kind)) {
    const day = dateWords(row.ends_on);
    const line = row.kind === "challenge_open" ? say("{title} is open: enter by the end of {day}", { title, day })
      : row.kind === "challenge_closing" ? say("The last two days to enter {title}: it closes at the end of {day}", { title, day })
      : row.picked === true ? say("{title} has ended, and a model you voted for won", { title })
      : say("{title} has ended: see who won", { title });
    return { ...base, link: challengeLink(row, origin), line };
  }
  if (row.kind === "result") {
    const votes = counted(Number(row.votes) || 0, "vote");
    return { ...base, link: `${origin}/challenge`, line: row.won !== true ? say("{title} has ended: see who won", { title })
      : row.way === "assistant" ? say("won {title} among the models built with the assistant, with {votes}", { title, votes })
      : say("won {title} among the models built by hand, with {votes}", { title, votes }) };
  }
  return { ...base, link: `${origin}/m/${model}`, line: say("something happened") };
}

/// The rows of notification_list, grouped by the model they are about,
/// the newest group first and each group's rows newest first:
/// {groups: [{model, name, picture, link, at, new, unread, rows}], unread,
/// fresh}. A row is new when it came after the list was last opened
/// ([seen_at]; never opened, all are), and unread until its model's group
/// was opened after it ([reads]) or everything was marked read ([read_at]).
/// The levels reached are a group of their own, [achievements] true, and
/// each challenge's notices one too, [challenge] its id: no model and no
/// picture, each unread until it was opened (each row's [read]); and each
/// announcement too, [announcement] its id, named by its title.
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
    const levelled = row.kind === "achievement";
    const challenge = CHALLENGE.has(row.kind) ? Number(row.challenge) || 0 : 0;
    const told = row.kind === "announcement";
    const talk = row.kind === "talk_reply" || row.kind === "talk_mention" ? Number(row.thread) || 0 : 0;
    const on = levelled ? "achievements" : challenge ? `challenge-${challenge}` : told ? `announcement-${Number(row.announcement) || 0}`
      : talk ? `talk-${talk}` : String(row.on || "");
    if (!levelled && !challenge && !told && !talk && !ID.test(on)) continue;
    const at = Date.parse(row.at);
    const readTo = levelled || challenge || told || talk ? (row.read === true ? Infinity : allRead)
      : Math.max(allRead, reads[on] ? Date.parse(reads[on]) : -Infinity);
    const said = { ...noticeSaid(row, origin, now), new: seen === null || at > seen, unread: at > readTo };
    if (said.unread) unread += 1;
    if (said.new) fresh += 1;
    if (levelled && !groups.has(on)) {
      groups.set(on, { model: "", achievements: true, name: say("Your achievements"), picture: null,
        link: `${origin}/profile?tab=achievements`, at: row.at, new: false, unread: false, rows: [] });
    }
    if (challenge && !groups.has(on)) {
      // A weekly quick build's group starts the studio on its template.
      const template = row.prompt && ID.test(String(row.prompt.template || "")) ? row.prompt.template : "";
      groups.set(on, { model: "", challenge, name: say(row.prompt ? "Quick build: {title}" : "Challenge: {title}",
        { title: quoted(row.title || say("a challenge"), 80) }), picture: null,
        link: challengeLink(row, origin), ...(template ? { start: `${origin}/app?copy=${template}` } : {}),
        at: row.at, new: false, unread: false, rows: [] });
    }
    if (talk && !groups.has(on)) {
      groups.set(on, { model: "", talk, name: say("Talk: {title}", { title: quoted(row.title || say("a thread"), 100) }), picture: null,
        link: talkLink(row, origin).replace(/#.*$/, ""), at: row.at, new: false, unread: false, rows: [] });
    }
    if (told && !groups.has(on)) {
      groups.set(on, { model: "", announcement: Number(row.announcement) || 0, name: quoted(row.title || say("News"), 120),
        picture: null, link: announcementLink(row, origin), at: row.at, new: false, unread: false, rows: [] });
    }
    if (!groups.has(on)) {
      const card = models[on] || {};
      const version = Date.parse(card.updated_at || "") || 0;
      groups.set(on, { model: on, name: quoted(card.name || row.of_name || row.name || say("Your model"), 80),
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
export async function listBefore(viewer, mark) {
  const page = await call("feed_of", { viewer, before: null, size: 50, mark }, () => null);
  if (!page) return null;
  const rows = (page.rows || [])
    .filter((row) => row.kind === "comment" || row.kind === "remix" || (row.kind === "photo" && row.yours === true))
    .map((row) => ({ ...row, on: row.kind === "remix" ? row.of : row.model }));
  const mine = await db(`shared_models?owner=eq.${viewer}&published=is.true&barred=is.false`
    + "&select=id,name,has_image,has_thumb,updated_at&order=updated_at.desc&limit=200");
  const since = new Date(Date.now() - 90 * DAY).toISOString();
  // Every like, past PostgREST's page of 1,000: a read asked for 2,000
  // was given 1,000, and a day's count stopped short (lists1's review).
  const likes = mine.length ? await dbAll(`model_likes?model=in.(${mine.map((one) => one.id).join(",")})`
    + `&account=neq.${viewer}&at=gt.${since}&select=model,at`, "model,account") : [];
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
  // Opened: what was counted is seen now, with any level reached since.
  await marked(asker);
  const page = await call("notification_list", { viewer: asker, mark: true }, () => ({ missing: true }));
  const listed = page && page.missing ? await listBefore(asker, true) : page;
  if (!listed) return response.status(200).json({ ready: false, groups: [], unread: 0, fresh: 0, kept: false });
  // Nothing by anybody they blocked, nor about a model of theirs: a remix
  // of yours whose maker is unnamed, a reply on their model.
  const handles = await blockedHandles(asker);
  const gone = handles.size ? await blockedModels(asker, (listed.rows || []).map((row) => row?.model)) : new Set();
  const read = handles.size ? { ...listed, rows: rowsWithout(listed.rows, handles, gone) } : listed;
  // A comment on a part says so (api/_comments.js pinnedAmong).
  await pinnedAmong((read.rows || []).filter((row) => PINNABLE.has(row?.kind)));
  // Which challenges told of are weekly quick builds, and their templates.
  const prompts = (read.rows || []).some((row) => CHALLENGE.has(row?.kind))
    ? await orUnknown("prompts", promptsById(true)) : null;
  if (prompts && prompts.size) {
    read.rows = read.rows.map((row) => (CHALLENGE.has(row?.kind) && prompts.has(Number(row.challenge))
      ? { ...row, prompt: prompts.get(Number(row.challenge)) } : row));
  }
  // Each line in the language the page asks in (?lang=).
  const lang = String(request.query?.lang || "en");
  return response.status(200).json(await withFaces({ ready: true, kept: !read.before, seen_at: read.seen_at ?? null,
    ...inLanguage(lang, siteWords(lang), () => noticeGroups(read, origin)) }));
}

/// What the studio's first screen tells of what came back on a person's
/// models (src/ui/studio_start.gd): a comment (on a part or not), a photo
/// of a build, a remix.
const CAME = new Set(["comment", "photo", "remix"]);
/// The most it lists.
const CAME_MOST = 8;

/// GET ?op=studio_start (session): what the studio's first screen shows
/// beside the person's own models (studiostart, docs/PLAN.md row 1): what
/// came back on their models, newest first, each {kind, model, name,
/// picture, line, who, said, at, new, link, comment, pinned}, [model] the
/// one of theirs it is on and [comment] a comment's number, which the
/// studio lights the part of when [pinned]; and this week's quick build
/// (api/_prompts.js promptNow) as {prompt}, or null. Only read: nothing is
/// marked seen or read (the avatar's count stays until Notifications is
/// opened), and no level is written down. Nothing by anybody they blocked,
/// as Notifications says it.
export async function studioStart(request, response, { origin }) {
  response.setHeader("Cache-Control", "private, no-store");
  const asker = await who(request);
  if (!asker) throw new Unacceptable("Sign in to see what came back on your models: we email you a code, no password.", 401);
  const tests = testsAsked(request.query || {});
  const [page, week] = await Promise.all([
    call("notification_list", { viewer: asker, mark: false }, () => ({ missing: true })),
    orUnknown("prompts", promptNow(origin, tests)),
  ]);
  const listed = page && page.missing ? await listBefore(asker, false) : page;
  const prompt = week || null;
  if (!listed) return response.status(200).json({ ready: false, came: [], prompt });
  const rows = (listed.rows || []).filter((row) => CAME.has(row?.kind) && ID.test(String(row?.on || "")));
  const handles = await blockedHandles(asker);
  const gone = handles.size ? await blockedModels(asker, rows.map((row) => row?.model)) : new Set();
  const kept = handles.size ? rowsWithout(rows, handles, gone) : rows;
  await pinnedAmong(kept.filter((row) => PINNABLE.has(row?.kind)));
  const lang = String(request.query?.lang || "en");
  const came = inLanguage(lang, siteWords(lang), () => {
    const groups = noticeGroups({ ...listed, rows: kept.slice(0, CAME_MOST) }, origin).groups;
    return groups.flatMap((group) => group.rows.map((said, index) => ({ said, group, row: index })))
      .sort((a, b) => Date.parse(b.said.at) - Date.parse(a.said.at))
      .map(({ said, group }) => {
        const number = /#comment-(\d+)$/.exec(String(said.link || ""));
        return { kind: said.kind, model: group.model, name: group.name, picture: group.picture, line: said.line,
          who: said.who, said: said.said, at: said.at, new: said.new, link: said.link,
          comment: number ? Number(number[1]) : 0, pinned: said.pinned === true };
      });
  });
  return response.status(200).json(await withFaces({ ready: true, came, prompt }));
}

export async function notificationsRead(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const asker = await who(request);
  if (!asker) throw new Unacceptable("Sign in first: we email you a code, no password.", 401);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  if (body.achievements === true) {
    const said = await call("achievement_read", { viewer: asker }, () => ({ missing: true }));
    return response.status(200).json({ read: !said?.missing, kept: !said?.missing });
  }
  if (body.announcement !== undefined) {
    // Opened, and with [clicked] its link followed (supabase/announce.sql).
    if (!Number.isSafeInteger(body.announcement) || body.announcement < 1) throw new Unacceptable("say which announcement, by its number");
    if (body.clicked !== undefined && typeof body.clicked !== "boolean") throw new Unacceptable("clicked is true or false");
    const said = await call("announcement_read", { viewer: asker, p_id: body.announcement, p_clicked: body.clicked === true },
      () => ({ missing: true }));
    if (said?.refused) throw new Unacceptable("There is no such announcement for you.", 404);
    return response.status(200).json({ read: !said?.missing, kept: !said?.missing });
  }
  if (body.talk !== undefined) {
    // A thread of Talk opened: read up to now (supabase/talk.sql talk_read).
    if (!Number.isSafeInteger(body.talk) || body.talk < 1) throw new Unacceptable("say which thread, by its number");
    const said = await call("talk_read", { account: asker, p_thread: body.talk }, () => ({ missing: true }));
    return response.status(200).json({ read: said?.read === true, kept: !said?.missing });
  }
  if (body.challenge !== undefined) {
    if (!Number.isSafeInteger(body.challenge) || body.challenge < 1) throw new Unacceptable("say which challenge, by its number");
    const said = await call("challenge_read", { viewer: asker, challenge: body.challenge }, () => ({ missing: true }));
    if (said?.refused) throw new Unacceptable("There is no such challenge.", 404);
    return response.status(200).json({ read: !said?.missing, kept: !said?.missing });
  }
  const model = body.all === true ? null : String(body.model ?? "");
  if (model !== null && !ID.test(model)) throw new Unacceptable("say which model or challenge, achievements: true or all: true");
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
/// the feed's count alone, as count, and null for each apart. The feed's
/// counts only what came after each follow (supabase/follow_counts.sql): a
/// new follow's backlog counted, and a new account that followed the house
/// in First steps had 7 on its avatar at once (walk180, W7). The count of
/// before until that file is applied. A level reached is written down
/// first, so it is in the count at once.
export async function newCounts(asker) {
  const [both, since, barred] = await Promise.all([
    marked(asker).then(() => call("notification_counts", { viewer: asker }, () => ({ missing: true }))),
    call("feed_new_count", { viewer: asker }, () => null),
    // Counted again without what their blocks leave out of the lists
    // (supabase/block.sql), for somebody who blocked anybody.
    blockCounts(asker),
  ]);
  if (both && !both.missing) {
    const notices = barred ? barred.notifications : Number(both.notifications) || 0;
    const feed = barred ? barred.feed : since !== null && since !== undefined ? Number(since) || 0 : Number(both.feed) || 0;
    return { count: Math.min(notices + feed, 99), notifications: notices, feed, ready: true };
  }
  const count = await call("feed_count", { viewer: asker }, () => null);
  return { count: Number(count) || 0, notifications: null, feed: null, ready: count !== null };
}

export async function feedCount(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const claims = bearer(request) ? await verify(bearer(request), request) : null;
  const asker = claims?.sub || null;
  if (!asker) return response.status(200).json({ count: 0, signed_in: false });
  const [counts, people, hidden] = await Promise.all([newCounts(asker),
    db(`people?account=eq.${asker}&select=handle,name`).catch(() => []),
    // Never the count's trouble: without it, the page asks about a notice
    // itself (web/notice.js), as before announce2.sql.
    call("site_notice_hidden_ids", { p_account: asker, p_scope: scopeOf(request) }, () => null).catch(() => null)]);
  const person = people[0] || null;
  // Their own picture, for the avatar in the header (api/_faces.js). And
  // for the site's owner alone, admin: the account menu's way to /admin
  // (docs/ADMIN.md). Everybody else's answer has no such key, not even
  // false: api/admin.js answers them as if there were no console, and this
  // says nothing different (bugbar, 2026-11-13).
  return response.status(200).json(await withFaces({ ...counts, signed_in: true,
    me: person ? { handle: person.handle, name: person.name } : null, ...(isMaster(claims) ? { admin: true } : {}),
    ...(Array.isArray(hidden) ? { notice_hidden: hidden.filter((id) => Number.isSafeInteger(id) && id > 0) } : {}) }));
}
