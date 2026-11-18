// /admin › Announcements' API (api/_announce.js through api/admin.js,
// api/people.js and api/plans.js) against supabase/announce.sql itself, in
// world.mjs's Postgres: what tests/test_announce.py asks of it. Functions
// are answered by the real files, as PostgREST calls them, each on a
// connection of its own so a double press is two at once; auth's accounts
// are that Postgres's, every one made up here; Resend is a stand-in that
// keeps what it was given, so nobody is mailed.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/announce/api_check.mjs
//
// Prints one JSON object, each finding by name.
import { createHmac } from "node:crypto";
import { Readable } from "node:stream";
import { askAdmin, askPlans, SUPABASE_URL, world } from "../billing/world.mjs";
import { announceWorld } from "./world.mjs";

const db = await announceWorld();
const out = {};

/// One request through api/[route].js's handler, as Vercel makes one:
/// {status, json, location}.
async function ask(route, { method = "GET", query = {}, headers = {}, body } = {}) {
  const { default: handle } = await import(`../../../api/${route}.js`);
  let status = 0;
  let json = null;
  let location = null;
  const response = {
    setHeader: (name, value) => {
      if (name.toLowerCase() === "location") location = value;
      return response;
    },
    status: (s) => { status = s; return response; },
    json: (b) => { json = b; return response; },
    end: () => response,
  };
  const request = body === undefined ? { method, query, headers }
    : Object.assign(Readable.from([Buffer.from(JSON.stringify(body))]), { method, query, headers, body });
  await handle(request, response);
  return { status, json, location };
}
const askPeople = (asked) => ask("people", asked);

const n = async (sql, args = []) => Number((await db.q(sql, args))[0].n);
// Who it was put before: its rows of announcement_to (announce2.sql), the
// one place that says so since; recipients is left empty.
const recipients = async (id) => (await db.q("select account::text as a from public.announcement_to where announcement = $1 order by 1",
  [id])).map((row) => row.a).sort();

try {
  const w = await world({ billing: "test" });
  const fromWorld = globalThis.fetch;
  // Resend's batch endpoint: each batch kept, answered as [answers] says
  // next (200 with an id each, else that status, or {status, body}).
  const batches = [];
  const answers = [];
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    if (url.origin === "https://api.resend.com") {
      const next = answers.shift() || 200;
      const status = typeof next === "object" ? next.status : next;
      const mails = JSON.parse(String(init.body || "[]"));
      batches.push({ path: url.pathname, status, key: init.headers?.["idempotency-key"] || null, mails, at: Date.now() });
      return status === 200 ? new Response(JSON.stringify({ data: mails.map((_, at) => ({ id: `re_${batches.length}_${at}` })) }), { status })
        : new Response(JSON.stringify(typeof next === "object" ? next.body : { message: "stand-in refusal" }), { status });
    }
    const call = /^\/rest\/v1\/rpc\/([a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && call && !["oc_connect_leaving", "admission_snapshot_get", "admission_snapshot_put"].includes(call[1])) {
      try {
        return new Response(JSON.stringify(await db.call(call[1], JSON.parse(String(init.body || "{}")))), { status: 200 });
      } catch (trouble) {
        const missing = /does not exist/.test(String(trouble.message));
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: missing ? 404 : 400 });
      }
    }
    return fromWorld(input, init);
  };
  process.env.CRON_SECRET = "cron-key-for-this-test-only";
  process.env.RESEND_API_KEY = "re_stand_in_key_for_this_test";
  const DAY = 86400000;
  const ago = (days) => new Date(Date.now() - days * DAY).toISOString();
  // The site's own (not the checks' pool), and the checks' pool (@resend.dev).
  const ownerId = await db.user("owner@example.com", { made: ago(300) });
  const adaId = await db.user("ada@example.com", { made: ago(200) });
  const deeId = await db.user("dee@example.com", { made: ago(100) });
  const t1 = await db.user("an-t1@resend.dev", { made: ago(60) });
  const t2 = await db.user("an-t2@resend.dev", { made: ago(40) });
  const t3 = await db.user("an-t3@resend.dev", { made: ago(2) });
  for (const [id, handle] of [[adaId, "ada"], [deeId, "dee"], [t1, "tee-one"], [t2, "tee-two"], [t3, "tee-three"]]) {
    await db.q("insert into public.people (account, handle) values ($1, $2)", [id, handle]);
  }
  await db.q("insert into public.beta_testers (account, state, joined_at, terms) values ($1, 'tester', now(), '2026-10-01'), ($2, 'left', now(), '2026-10-01')",
    [t1, t2]);
  await db.q("insert into public.shared_models (owner, id) values ($1, 'AnModel001')", [t1]);
  await db.q("insert into public.admission_snapshots (key, value) values ($1, $2)",
    [`admission:v2:brickworks:test:c:${t1}`, JSON.stringify({ value: { plan: { key: "pro" } } })]);
  const owner = await w.signIn({ sub: ownerId, email: "owner@example.com" });
  const token = {};
  for (const [id, email] of [[adaId, "ada@example.com"], [deeId, "dee@example.com"], [t1, "an-t1@resend.dev"], [t2, "an-t2@resend.dev"],
    [t3, "an-t3@resend.dev"]]) token[id] = await w.signIn({ sub: id, email });
  const preview = "brickworks-abc123-xaxis-projects.vercel.app";
  const live = "brickworks.diy";
  const as = (who, host = preview) => ({ host, ...(who ? { authorization: `Bearer ${who}` } : {}) });
  const read = (query, host) => askAdmin({ query, headers: as(owner, host) });
  const act = (op, body, host) => askAdmin({ method: "POST", query: { op }, headers: as(owner, host), body });
  const auditCount = () => n("select count(*)::int as n from public.admin_audit");

  // --- The gate: 401 signed out, 404 to anybody but the owner, nothing kept.
  out.gate = {};
  for (const [op, method] of [["announce", "GET"], ["announce_preview", "GET"], ["announce_keep", "POST"], ["announce_send", "POST"],
    ["announce_unschedule", "POST"], ["announce_edit", "POST"], ["announce_withdraw", "POST"], ["announce_drop", "POST"],
    ["announce_limit", "POST"], ["announce_mail_most", "POST"], ["announce_mail_address", "POST"]]) {
    const query = { op, words: JSON.stringify({ title: "x", audience: { kind: "everyone" } }) };
    const body = { title: "A stranger's", body: "", audience: { kind: "everyone" }, id: 1, most: 5 };
    out.gate[op] = [(await askAdmin({ method, query, headers: as(null), body })).status,
      (await askAdmin({ method, query, headers: as(token[adaId]), body })).status];
  }
  out.gate_kept = { audit: await auditCount(), announcements: await n("select count(*)::int as n from public.announcements") };
  out.people_gate = {
    news: (await askPeople({ method: "POST", query: { op: "news" }, headers: as(null), body: { news: true } })).status,
    notice_hide: (await askPlans({ method: "POST", query: { op: "notice_hide" }, headers: as(null), body: { id: 1 } })).status,
    notice_hidden: (await askPlans({ query: { op: "notice_hidden", id: "1" }, headers: as(null) })).status,
    cron: (await askPlans({ query: { op: "announce_due" }, headers: as(null) })).status,
  };

  // --- The read.
  const first = await read({ op: "announce" });
  out.read = { status: first.status, ready: first.json?.ready, test: first.json?.test, most: first.json?.most,
    plans: (first.json?.plans || []).map((one) => one.key), mail: first.json?.mail };
  // The most a day raised for the checks below (the limit has its own check).
  out.limit_set = (await act("announce_limit", { most: 20 })).status;
  out.limit_live_set = (await act("announce_limit", { most: 20 }, live)).status;
  out.limit_refused = [(await act("announce_limit", { most: 0 })).json?.error, (await act("announce_limit", { most: 21 })).json?.error,
    (await act("announce_limit", { most: "5" })).json?.error];

  // --- Each audience: its count in the preview, and who it reaches, exactly.
  const want = {
    everyone: [t1, t2, t3], beta: [t1], since: [t3], published: [t1], person: [t2], plan_pro: [t1], plan_free: [t2, t3],
  };
  const audiences = {
    everyone: { kind: "everyone" }, beta: { kind: "beta" }, since: { kind: "since", since: ago(20) }, published: { kind: "published" },
    person: { kind: "person", handle: "@Tee-Two" }, plan_pro: { kind: "plan", plan: "pro" }, plan_free: { kind: "plan", plan: "free" },
  };
  out.audiences = {};
  for (const [name, audience] of Object.entries(audiences)) {
    const looked = await read({ op: "announce_preview", words: JSON.stringify({ title: `For ${name}`, body: "Line one\nLine two", audience }) });
    const kept = await act("announce_keep", { title: `For ${name}`, body: "Line one\nLine two", audience });
    const row = kept.json?.announcement;
    const sent = await act("announce_send", { id: row?.id, hash: row?.hash, changed_at: row?.changed_at });
    const got = await recipients(row?.id);
    // Each one's Notifications (announcement_rows, which notification_rows unions in) has it, and nobody else's.
    const has = [];
    for (const id of [ownerId, adaId, deeId, t1, t2, t3]) {
      const rows = await db.call("announcement_rows", { viewer: id, since: ago(1), until: new Date(Date.now() + 1000).toISOString() });
      if (rows.some((one) => Number(one.item.announcement) === Number(row?.id))) has.push(id);
    }
    out.audiences[name] = { count: looked.json?.count, refused: looked.json?.refused ?? null, kept: kept.status, sent: sent.status,
      outcome: sent.json?.outcome, reach: sent.json?.reach, exactly: JSON.stringify(got) === JSON.stringify([...want[name]].sort()),
      listed_exactly: JSON.stringify(has.sort()) === JSON.stringify([...want[name]].sort()), want: want[name].length };
  }
  // The site's own, never the checks' pool, and the other way about.
  const liveCount = await read({ op: "announce_preview", words: JSON.stringify({ title: "x", audience: { kind: "everyone" } }) }, live);
  out.live_everyone = { count: liveCount.json?.count, test: liveCount.json?.test };
  out.nobody = (await read({ op: "announce_preview", words: JSON.stringify({ title: "x", audience: { kind: "person", handle: "nobody-here" } }) }))
    .json?.count;
  out.bad_audience = [(await act("announce_keep", { title: "x", audience: { kind: "admins" } })).json?.error,
    (await act("announce_keep", { title: "x", audience: { kind: "since", since: new Date(Date.now() + DAY).toISOString() } })).json?.error,
    (await act("announce_keep", { title: "x", audience: { kind: "person", handle: "a b" } })).json?.error,
    (await act("announce_keep", { title: "x", audience: { kind: "plan", plan: "gold" } })).json?.error];
  out.send_to_nobody = await (async () => {
    const kept = (await act("announce_keep", { title: "To nobody", audience: { kind: "person", handle: "nobody-here" } })).json.announcement;
    const sent = await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at });
    await act("announce_drop", { id: kept.id });
    return { status: sent.status, error: sent.json?.error };
  })();

  // --- The press: two at once make one send; a second later finds it gone;
  // words changed since the look are refused.
  {
    const kept = (await act("announce_keep", { title: "Pressed twice", body: "", audience: { kind: "everyone" } })).json.announcement;
    const press = () => act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at });
    const [a, b] = await Promise.all([press(), press()]);
    const later = await press();
    out.double = { statuses: [a.status, b.status].sort(), later: later.status, later_said: later.json?.error,
      reach: (await db.q("select reach from public.announcements where id = $1", [kept.id]))[0].reach,
      sends_audited: await n("select count(*)::int as n from public.admin_audit where op = 'announce_send' and target = $1 and status = 200",
        [String(kept.id)]) };
    const draft = (await act("announce_keep", { title: "Looked at", audience: { kind: "everyone" } })).json.announcement;
    const changed = (await act("announce_keep", { id: draft.id, title: "Changed after the look", audience: { kind: "everyone" } })).json.announcement;
    const stale = await act("announce_send", { id: draft.id, hash: draft.hash, changed_at: draft.changed_at });
    const staleVersion = await act("announce_send", { id: draft.id, hash: changed.hash, changed_at: draft.changed_at });
    out.stale = { hash: stale.status, said: stale.json?.error, version: staleVersion.status, version_said: staleVersion.json?.error,
      still: (await db.q("select status from public.announcements where id = $1", [draft.id]))[0].status };
    await act("announce_drop", { id: draft.id });
  }

  // --- Scheduled, then changed: a draft again; scheduled again, it goes at
  // its time by the cron, as those words alone.
  {
    const kept = (await act("announce_keep", { title: "Later", body: "Soon", audience: { kind: "beta" } })).json.announcement;
    const at = new Date(Date.now() + 2 * 3600000).toISOString();
    const scheduled = await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at, at });
    const edited = await act("announce_keep", { id: kept.id, title: "Later, changed", body: "Soon", audience: { kind: "beta" } });
    const after = (await db.q("select status, send_at, pressed_hash from public.announcements where id = $1", [kept.id]))[0];
    const again = edited.json.announcement;
    const rescheduled = await act("announce_send", { id: again.id, hash: again.hash, changed_at: again.changed_at, at });
    await db.q("update public.announcements set send_at = now() - interval '1 minute' where id = $1", [kept.id]);
    const cron = await askPlans({ query: { op: "announce_due" }, headers: { host: live, authorization: `Bearer ${process.env.CRON_SECRET}` } });
    const done = (await db.q("select status, reach, title from public.announcements where id = $1", [kept.id]))[0];
    out.schedule = { scheduled: scheduled.json?.outcome, edited: edited.json?.outcome, after_edit: { status: after.status, send_at: after.send_at,
      pressed: after.pressed_hash }, rescheduled: rescheduled.json?.outcome, cron: cron.status, cron_sent: cron.json?.sent, done,
      audited: await n("select count(*)::int as n from public.admin_audit where op = 'announce_send' and target = $1 and actor = 'the schedule'",
        [String(kept.id)]) };
    // Words changed behind the press (not through the API): held, said, audited.
    const other = (await act("announce_keep", { title: "Tampered", audience: { kind: "beta" } })).json.announcement;
    await act("announce_send", { id: other.id, hash: other.hash, changed_at: other.changed_at, at });
    await db.q("update public.announcements set body = 'changed behind it', send_at = now() - interval '1 minute' where id = $1", [other.id]);
    const cron2 = await askPlans({ query: { op: "announce_due" }, headers: { host: live, authorization: `Bearer ${process.env.CRON_SECRET}` } });
    const heldRow = (await db.q("select status, said, reach from public.announcements where id = $1", [other.id]))[0];
    out.held = { cron: cron2.json?.held, status: heldRow.status, said: heldRow.said, reach: heldRow.reach,
      audited: await n("select count(*)::int as n from public.admin_audit where op = 'announce_send' and target = $1 and status = 409",
        [String(other.id)]) };
    // Unscheduled by hand: a draft.
    const third = (await act("announce_keep", { title: "Third", audience: { kind: "beta" } })).json.announcement;
    await act("announce_send", { id: third.id, hash: third.hash, changed_at: third.changed_at, at });
    const unscheduled = await act("announce_unschedule", { id: third.id });
    out.unschedule = { outcome: unscheduled.json?.outcome, status: (await db.q("select status from public.announcements where id = $1",
      [third.id]))[0].status };
    out.schedule_refused = [(await act("announce_send", { id: third.id, hash: (await read({ op: "announce" })).json.announcements
      .find((one) => one.id === third.id).hash, changed_at: unscheduled.json.announcement.changed_at,
      at: new Date(Date.now() + 61 * DAY).toISOString() })).json?.error];
    await act("announce_drop", { id: third.id });
    await act("announce_drop", { id: other.id });
  }

  // --- Read, clicked, edited and withdrawn, as the person's own page asks.
  {
    const kept = (await act("announce_keep", { title: "Read me", body: "Words", link: "/challenge", audience: { kind: "everyone" } })).json
      .announcement;
    await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at });
    const asRead = (who, body) => askPeople({ method: "POST", query: { op: "notifications_read" }, headers: as(token[who]), body });
    const r1 = await asRead(t1, { announcement: kept.id });
    const r2 = await asRead(t1, { announcement: kept.id, clicked: false });
    const before = (await read({ op: "announce" })).json.announcements.find((one) => one.id === kept.id);
    const r3 = await asRead(t2, { announcement: kept.id, clicked: true });
    const r4 = await asRead(t2, { announcement: kept.id, clicked: true });
    const stranger = await asRead(adaId, { announcement: kept.id });
    const wrong = await asRead(t1, { announcement: String(kept.id) });
    const listed = (await read({ op: "announce" })).json.announcements.find((one) => one.id === kept.id);
    out.reads = { statuses: [r1.status, r2.status, r3.status, r4.status], stranger: [stranger.status, stranger.json?.error], wrong: wrong.status,
      after_t1: { read: before.read, clicked: before.clicked }, after_all: { read: listed.read, clicked: listed.clicked, reach: listed.reach } };
    // Delivered the usual way: the person's group as the page draws it.
    const { noticeGroups } = await import("../../../api/_notifications.js");
    const rows = (await db.call("announcement_rows", { viewer: t3, since: ago(1), until: new Date(Date.now() + 1000).toISOString() }))
      .map((row) => ({ kind: row.kind, at: row.at, on: row.model, ...row.item }));
    const { groups } = noticeGroups({ rows, seen_at: null, read_at: null }, "https://brickworks.diy");
    const mine = groups.find((one) => one.announcement === kept.id);
    out.group = { name: mine?.name, link: mine?.link, unread: mine?.unread, who: mine?.rows?.[0]?.who, said: mine?.rows?.[0]?.said,
      line: mine?.rows?.[0]?.line };
    // Edited: looked at first, then changed for everybody, marked edited.
    const looked = await act("announce_edit", { id: kept.id, changed_at: listed.changed_at, title: "Read me (new time)", body: "Words", link: "/challenge" });
    const changed = await act("announce_edit", { id: kept.id, changed_at: listed.changed_at, title: "Read me (new time)", body: "Words",
      link: "/challenge", hash: looked.json?.hash });
    const wrongHash = await act("announce_edit", { id: kept.id, changed_at: changed.json?.announcement?.changed_at, title: "Again", body: "Words",
      link: "/challenge", hash: looked.json?.hash });
    const t1Rows = await db.call("announcement_rows", { viewer: t1, since: ago(1), until: new Date(Date.now() + 1000).toISOString() });
    const t1Row = t1Rows.find((one) => Number(one.item.announcement) === kept.id);
    out.edit = { looked: looked.json?.outcome, looked_edited: looked.json?.group?.rows?.[0]?.edited, changed: changed.json?.outcome,
      wrong_hash: wrongHash.status, title: t1Row?.item?.title, edited: t1Row?.item?.edited, still_read: t1Row?.item?.read };
    // Withdrawn: out of every list, said under Sent.
    const pulled = await act("announce_withdraw", { id: kept.id });
    const again = await act("announce_withdraw", { id: kept.id });
    let left = 0;
    for (const id of [t1, t2, t3]) {
      left += (await db.call("announcement_rows", { viewer: id, since: ago(1), until: new Date(Date.now() + 1000).toISOString() }))
        .filter((one) => Number(one.item.announcement) === kept.id).length;
    }
    const readAfter = await asRead(t1, { announcement: kept.id });
    out.withdraw = { outcome: pulled.json?.outcome, again: again.status, left, read_after: readAfter.status,
      listed: (await read({ op: "announce" })).json.announcements.find((one) => one.id === kept.id)?.status };
  }

  // --- The day's most: one more than the day has, then refused in words.
  {
    const today = (await read({ op: "announce" })).json.today;
    const most = Number(today.sent) + Number(today.scheduled) + 1;
    await act("announce_limit", { most });
    const one = (await act("announce_keep", { title: "Last today", audience: { kind: "beta" } })).json.announcement;
    const two = (await act("announce_keep", { title: "Over today's most", audience: { kind: "beta" } })).json.announcement;
    const s1 = await act("announce_send", { id: one.id, hash: one.hash, changed_at: one.changed_at });
    const s2 = await act("announce_send", { id: two.id, hash: two.hash, changed_at: two.changed_at });
    out.limit = { most, first: s1.status, second: s2.status, said: s2.json?.error,
      still_draft: (await db.q("select status from public.announcements where id = $1", [two.id]))[0].status };
    await act("announce_limit", { most: 20 });
    await act("announce_drop", { id: two.id });
    // Another preview's checks: their own day's count and their own list,
    // never this one's sends.
    const other = "brickworks-def456-xaxis-projects.vercel.app";
    const before = (await read({ op: "announce" }, other)).json;
    await act("announce_limit", { most: 1 }, other);
    const theirs = (await act("announce_keep", { title: "Another preview's", audience: { kind: "beta" } }, other)).json.announcement;
    const went = await act("announce_send", { id: theirs.id, hash: theirs.hash, changed_at: theirs.changed_at }, other);
    const after = (await read({ op: "announce" }, other)).json;
    const here = (await read({ op: "announce" })).json;
    out.scopes = { before: before.today, listed_before: before.announcements.length, went: went.status, after: after.today,
      listed_after: after.announcements.map((a) => a.title), here_lists_theirs: here.announcements.some((a) => a.id === theirs.id),
      here_today: here.today.sent };
  }

  // --- Words: over a limit refused in words and never cut; Unicode spaces
  // and invisible characters made plain; a false sent as absent.
  {
    const long = await act("announce_keep", { title: "x".repeat(121), audience: { kind: "everyone" } });
    const longBody = await act("announce_keep", { title: "Fine", body: "y".repeat(1001), audience: { kind: "everyone" } });
    const badLink = await act("announce_keep", { title: "Fine", link: "javascript:alert(1)", audience: { kind: "everyone" } });
    const twoSlash = await act("announce_keep", { title: "Fine", link: "//evil.example/x", audience: { kind: "everyone" } });
    const http = await act("announce_keep", { title: "Fine", link: "http://example.com/", audience: { kind: "everyone" } });
    const plain = await act("announce_keep", { title: `Hello\u200b\u00a0\u2003world\ufeff`, body: "One\u2028Two\r\n\r\n\r\n\r\nThree\u0007",
      audience: { kind: "everyone" }, email: false });
    const absent = await act("announce_keep", { title: "Hello world", body: "One\nTwo\n\nThree", audience: { kind: "everyone" } });
    out.words = { long: [long.status, long.json?.error], long_body: [longBody.status, longBody.json?.error], bad_link: badLink.json?.error,
      two_slash: twoSlash.json?.error, http: http.json?.error, title: plain.json?.announcement?.title, body: plain.json?.announcement?.body,
      email_false: plain.json?.announcement?.email, same_hash: plain.json?.announcement?.hash === absent.json?.announcement?.hash,
      kept_none_long: await n("select count(*)::int as n from public.announcements where char_length(title) > 120 or char_length(body) > 1000") };
    await act("announce_drop", { id: plain.json.announcement.id });
    await act("announce_drop", { id: absent.json.announcement.id });
    // Email is never on in the checks' pool.
    const pooled = await act("announce_keep", { title: "Mail?", audience: { kind: "everyone" }, email: true });
    out.pool_email = pooled.json?.announcement?.email;
    await act("announce_drop", { id: pooled.json.announcement.id });
  }

  // --- No unsubscribe secret of its own (NEWS_UNSUB_SECRET): nobody is
  // mailed, and the console says what is missing.
  {
    const said = (await read({ op: "announce" }, live)).json;
    out.no_secret = { mail: said?.mail, missing: (said?.mail_missing || []).map((one) => one.name), news_mail: said?.news_mail };
  }
  process.env.NEWS_UNSUB_SECRET = "news-unsub-secret-for-this-test-only";

  // --- News by email: off until chosen; only those who chose it are mailed,
  // in batches with one-click unsubscribe; the link stops them.
  {
    const choose = (who, body) => askPeople({ method: "POST", query: { op: "news" }, headers: as(token[who], live), body });
    const yes = await choose(adaId, { news: true });
    const notBool = await choose(deeId, { news: "true" });
    const absent = await choose(deeId, {});
    const defaults = await db.call("news_choice", { p_account: deeId });
    const kept = (await act("announce_keep", { title: "Big news", body: "Something new.", link: "/gallery", audience: { kind: "everyone" },
      email: true }, live)).json.announcement;
    const looked = await read({ op: "announce_preview", words: JSON.stringify({ title: "Big news", audience: { kind: "everyone" }, email: true }) }, live);
    const sent = await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at }, live);
    const mailed = batches.flatMap((one) => one.mails);
    const mail = mailed[0];
    const header = mail?.headers?.["List-Unsubscribe"] || "";
    const post = /^<(https:\/\/brickworks\.diy\/api\/people\?op=news_unsubscribe&a=([0-9a-f-]{36})&t=([A-Za-z0-9_-]+))>$/.exec(header);
    const round = await askPlans({ query: { op: "announce_due" }, headers: { host: live, authorization: `Bearer ${process.env.CRON_SECRET}` } });
    out.mail = { yes: yes.json, not_bool: notBool.status, absent: absent.status, dee_default: defaults?.news, count: looked.json?.count,
      mail_count: looked.json?.mail, sent: sent.json?.mail, batches: batches.length, to: mailed.map((one) => one.to).flat(),
      batch_path: batches[0]?.path, idempotent: /^announce-\d+-[0-9a-f]{32}$/.test(String(batches[0]?.key)),
      one_click: mail?.headers?.["List-Unsubscribe-Post"], header_ok: Boolean(post) && post[2] === adaId,
      page_link: /\/settings\?unsubscribe=[0-9a-f-]{36}\.[A-Za-z0-9_-]+#email-part/.test(mail?.html || "") && /Unsubscribe:/.test(mail?.text || ""),
      second_round_batches: batches.length, round_mailed: round.json?.mailed,
      states: (await read({ op: "announce" }, live)).json.announcements.find((one) => one.id === kept.id)?.mails };
    // The one click, as a mail client makes it: no sign-in, no redirect.
    const a = post?.[2];
    const t = post?.[3];
    const opened = await askPeople({ method: "GET", query: { op: "news_unsubscribe", a, t }, headers: { host: live } });
    const openedNews = (await db.call("news_choice", { p_account: adaId }))?.news;
    const bad = await askPeople({ method: "POST", query: { op: "news_unsubscribe", a, t: `${t.slice(0, -2)}xx` }, headers: { host: live } });
    const cut = await askPeople({ method: "POST", query: { op: "news_unsubscribe", a, t: t.slice(0, 10) }, headers: { host: live } });
    const badGet = await askPeople({ method: "GET", query: { op: "news_unsubscribe", a, t: "nope" }, headers: { host: live } });
    const clicked = await askPeople({ method: "POST", query: { op: "news_unsubscribe", a, t }, headers: { host: live } });
    // Settings' own POST, with the token in its body.
    const fromSettings = await askPeople({ method: "POST", query: { op: "news_unsubscribe" }, headers: { host: live }, body: { a, t } });
    const after = (await db.call("news_choice", { p_account: adaId }))?.news;
    const next = (await act("announce_keep", { title: "More news", audience: { kind: "everyone" }, email: true }, live)).json.announcement;
    const before = batches.length;
    const nextSent = await act("announce_send", { id: next.id, hash: next.hash, changed_at: next.changed_at }, live);
    out.unsubscribe = { opened: [opened.status, opened.location], news_after_open: openedNews, bad: bad.status, cut: cut.status,
      bad_get: badGet.location, clicked: clicked.json, settings: fromSettings.status, news: after, next_batches: batches.length - before,
      next_mail: nextSent.json?.mail };
    // Chosen after one went: not sent what came before.
    await choose(deeId, { news: true });
    const late = await askPlans({ query: { op: "announce_due" }, headers: { host: live, authorization: `Bearer ${process.env.CRON_SECRET}` } });
    out.chose_later = { mailed: late.json?.mailed, to_dee: batches.filter((one) => one.mails.some((m) => m.to.includes("dee@example.com"))).length };
    // Resend busy (429): nothing lost, nothing twice; the next round sends it.
    answers.push(429);
    const busy = (await act("announce_keep", { title: "Busy day", audience: { kind: "everyone" }, email: true }, live)).json.announcement;
    const busySent = await act("announce_send", { id: busy.id, hash: busy.hash, changed_at: busy.changed_at }, live);
    const busyStates = await db.q("select state, count(*)::int as n from public.announcement_mails where announcement = $1 group by state",
      [busy.id]);
    const retry = await askPlans({ query: { op: "announce_due" }, headers: { host: live, authorization: `Bearer ${process.env.CRON_SECRET}` } });
    const toDee = batches.filter((one) => one.mails.some((m) => m.to.includes("dee@example.com") && m.subject === "Busy day"));
    out.busy = { first: busySent.json?.mail, states_after_429: busyStates, retry_mailed: retry.json?.mailed, tries: toDee.map((one) => one.status),
      final: await db.q("select state, count(*)::int as n from public.announcement_mails where announcement = $1 group by state", [busy.id]) };
  }

  // --- The banner: its end, hidden per person on every device, gone at its end.
  {
    const ends = new Date(Date.now() + 2 * 3600000).toISOString();
    const set = await act("notice_set", { words: { en: "Upkeep at 02:00 UTC." }, tone: "warn", ends });
    const shown = await askPlans({ query: { op: "notice" }, headers: { host: preview } });
    const id = shown.json?.notice?.id;
    const hide = (who, body) => askPlans({ method: "POST", query: { op: "notice_hide" }, headers: as(token[who]), body });
    const hidden = (who, nid = id) => askPlans({ query: { op: "notice_hidden", id: String(nid) }, headers: as(token[who]) });
    const h1 = await hide(t1, { id });
    const h1again = await hide(t1, { id });
    const noSuch = await hide(t1, { id: 999999 });
    const wrongId = await hide(t1, { id: "x" });
    const t1Hid = (await hidden(t1)).json?.hidden;
    const t2Hid = (await hidden(t2)).json?.hidden;
    const past = await act("notice_set", { words: { en: "Ends already" }, tone: "info", ends: new Date(Date.now() - 60000).toISOString() });
    const far = await act("notice_set", { words: { en: "Ends far" }, tone: "info", ends: new Date(Date.now() + 400 * DAY).toISOString() });
    const notTime = await act("notice_set", { words: { en: "Ends never" }, tone: "info", ends: "soon" });
    const stillId = (await askPlans({ query: { op: "notice" }, headers: { host: preview } })).json?.notice?.id;
    const changed = await act("notice_set", { words: { en: "Upkeep moved to 03:00 UTC." }, tone: "warn" });
    const nextId = (await askPlans({ query: { op: "notice" }, headers: { host: preview } })).json?.notice?.id;
    const t1New = (await hidden(t1, nextId)).json?.hidden;
    const t1Old = (await hidden(t1, id)).json?.hidden;
    const withEnd = await act("notice_set", { words: { en: "Back soon." }, tone: "info", ends });
    const endId = (await askPlans({ query: { op: "notice" }, headers: { host: preview } })).json?.notice?.id;
    await db.q("update public.site_notices set ends_at = now() - interval '1 second' where id = $1", [endId]);
    const gone = (await askPlans({ query: { op: "notice" }, headers: { host: preview } })).json?.notice;
    const switches = (await read({ op: "switches" })).json;
    const same = (iso) => Boolean(iso) && Date.parse(iso) === Date.parse(ends);
    out.banner = { set: [set.status, same(set.json?.ends_at)], shown_ends: same(shown.json?.notice?.ends_at), hide: [h1.status, h1again.status],
      no_such: noSuch.status, wrong_id: wrongId.status, t1: t1Hid, t2: t2Hid,
      refused: [past.status, past.json?.error, far.status, far.json?.error, notTime.status, notTime.json?.error], unchanged: stillId === id,
      changed: changed.status, new_notice_hidden: t1New, old_still_hidden: t1Old, with_end: withEnd.status, gone_at_end: gone,
      history_ends: (switches?.notices || []).some((one) => one.id === endId && one.ends_at),
      audited: await n("select count(*)::int as n from public.admin_audit where op = 'notice_set' and status = 200") };
  }

  // --- The review's fixes (anfix, bench/results/anreview-2026-11-18).
  out.fix = {};
  const cron = (host = live) => askPlans({ query: { op: "announce_due" }, headers: { host, authorization: `Bearer ${process.env.CRON_SECRET}`,
    "user-agent": "vercel-cron/1.0" } });
  // M1: the avatar's count says which of the site's notices the person hid.
  {
    await act("notice_set", { words: { en: "Upkeep tonight." }, tone: "info" });
    const id = (await askPlans({ query: { op: "notice" }, headers: { host: preview } })).json?.notice?.id;
    const count = async (who, host = preview) => (await askPeople({ query: { op: "feed_count" }, headers: as(token[who], host) })).json;
    const before = await count(t2);
    await askPlans({ method: "POST", query: { op: "notice_hide" }, headers: as(token[t2]), body: { id } });
    const after = await count(t2);
    const other = await count(t3);
    const elsewhere = await count(t2, live);
    await act("notice_clear", {});
    out.fix.m1 = { id, before: before?.notice_hidden, after: after?.notice_hidden, other: other?.notice_hidden,
      elsewhere: elsewhere?.notice_hidden, cleared: (await count(t2))?.notice_hidden,
      signed_out: (await askPeople({ query: { op: "feed_count" }, headers: as(null) })).json };
  }
  // M2: who it reached is rows of announcement_to; recipients stays empty;
  // the list reads one row of counts an announcement.
  {
    const kept = (await act("announce_keep", { title: "Rows", audience: { kind: "everyone" } })).json.announcement;
    const sent = await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at });
    const row = (await db.q("select recipients, reach from public.announcements where id = $1", [kept.id]))[0];
    await askPeople({ method: "POST", query: { op: "notifications_read" }, headers: as(token[t1]), body: { announcement: kept.id, clicked: true } });
    await askPeople({ method: "POST", query: { op: "notifications_read" }, headers: as(token[t1]), body: { announcement: kept.id, clicked: true } });
    const listed = (await read({ op: "announce" })).json.announcements.find((one) => one.id === kept.id);
    const truth = (await db.q(`select count(*) filter (where read_at is not null)::int as reads, count(*) filter (where clicked_at is not null)::int as clicks
      from public.announcement_reads where announcement = $1`, [kept.id]))[0];
    const counted = (await db.q("select reads, clicks from public.announcement_counts where announcement = $1", [kept.id]))[0];
    const tables = (await db.q(`select array_agg(distinct t.relname order by t.relname) as t from pg_proc p, unnest(array['announcement_to',
      'announcement_reads','announcement_mails','announcement_counts']) t(relname) where p.proname = 'announce_list' and p.prosrc like '%' || t.relname || '%'`))[0].t;
    const sentAll = await n(`select count(*)::int as n from public.announcements a where a.status <> 'draft' and a.sent_at is not null
      and a.reach = (select count(*) from public.announcement_to t where t.announcement = a.id)`);
    const sentEvery = await n("select count(*)::int as n from public.announcements where sent_at is not null");
    out.fix.m2 = { reach: sent.json?.reach, to_rows: (await recipients(kept.id)).length, recipients: row.recipients, row_reach: row.reach,
      listed: { read: listed?.read, clicked: listed?.clicked, seen: listed?.seen ?? null, recipients: listed?.recipients ?? null }, truth, counted,
      list_reads: tables, reach_is_rows: sentAll === sentEvery, sent_every: sentEvery };
    await act("announce_drop", { id: kept.id }).catch(() => null);
  }
  // L3: a barred account is in no audience but "one person", and never mailed.
  {
    const gil = await db.user("gil@example.com", { made: ago(30) });
    await db.q("insert into public.people (account, handle) values ($1, 'gil')", [gil]);
    await db.q("insert into public.news_mail (account, news, at) values ($1, true, now() - interval '1 day')", [gil]);
    const before = (await read({ op: "announce_preview", words: JSON.stringify({ title: "x", audience: { kind: "everyone" }, email: true }) }, live)).json;
    await db.q("insert into public.barred_accounts (account) values ($1)", [gil]);
    const after = (await read({ op: "announce_preview", words: JSON.stringify({ title: "x", audience: { kind: "everyone" }, email: true }) }, live)).json;
    const one = (await read({ op: "announce_preview", words: JSON.stringify({ title: "x", audience: { kind: "person", handle: "gil" }, email: true }) }, live)).json;
    const kept = (await act("announce_keep", { title: "To Gil alone", audience: { kind: "person", handle: "gil" }, email: true }, live)).json.announcement;
    const from = batches.length;
    const sent = await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at }, live);
    await cron();
    out.fix.l3 = { everyone: [before.count, after.count], mail: [before.mail, after.mail], person: [one.count, one.mail], reach: sent.json?.reach,
      mailed_gil: batches.slice(from).some((b) => b.mails.some((m) => m.to.includes("gil@example.com"))),
      rows: (await db.call("announcement_rows", { viewer: gil, since: ago(1), until: new Date(Date.now() + 1000).toISOString() })).length };
  }
  // M3: news mail's most a day, counted inside the take; a quota Resend
  // names stops it until the next UTC day; each take paced.
  {
    const people = [];
    for (const name of ["hal", "ivy", "jo"]) {
      const id = await db.user(`${name}@example.com`, { made: ago(30) });
      await db.q("insert into public.news_mail (account, news, at) values ($1, true, now() - interval '1 day')", [id]);
      people.push(id);
    }
    const state0 = (await read({ op: "announce" }, live)).json.news_mail;
    const refused = [(await act("announce_mail_most", { most: -1 }, live)).status, (await act("announce_mail_most", { most: 10001 }, live)).status,
      (await act("announce_mail_most", { most: "5" }, live)).status];
    const today = Number(state0.today);
    const set = await act("announce_mail_most", { most: today + 1 }, live);
    const kept = (await act("announce_keep", { title: "Most a day", audience: { kind: "everyone" }, email: true }, live)).json.announcement;
    const from = batches.length;
    const sent = await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at }, live);
    const firstTo = batches.slice(from).flatMap((b) => b.mails.map((m) => m.to[0]));
    const again = await cron();
    const state1 = (await read({ op: "announce" }, live)).json.news_mail;
    await act("announce_mail_most", { most: 1000 }, live);
    // The team's daily quota used: Resend's 429 names it.
    answers.push({ status: 429, body: { statusCode: 429, name: "daily_quota_exceeded", message: "You have reached your daily email sending quota." } });
    const quotaFrom = batches.length;
    const quota = await cron();
    const stopped = (await read({ op: "announce" }, live)).json.news_mail;
    const afterStop = batches.length;
    const stillStopped = await cron();
    const states = await db.q("select state, count(*)::int as n from public.announcement_mails where announcement = $1 group by state order by 1", [kept.id]);
    const next = new Date();
    const midnight = Date.UTC(next.getUTCFullYear(), next.getUTCMonth(), next.getUTCDate() + 1);
    out.fix.m3 = { default_most: state0.most, refused, set: set.status, set_value: set.json?.value, first_mailed: sent.json?.mail?.sent,
      first_to: firstTo.length, cron_mailed: again.json?.mailed, today_at_most: state1.today === today + 1,
      quota_batches: batches.length - quotaFrom, quota_outcome: quota.json?.outcome, stopped: stopped.stopped,
      stopped_until_midnight: Date.parse(stopped.stopped?.until) === midnight, stopped_why: stopped.stopped?.why,
      batches_while_stopped: batches.length - afterStop, still: stillStopped.json?.mailed, states };
    // Stopped no more (as the next day): the rest go, paced.
    await db.q("delete from public.site_settings where name = 'news_mail_stopped'");
    const resumedFrom = batches.length;
    const resumed = await cron();
    out.fix.m3.resumed = resumed.json?.mailed;
    // Paced from any instance: two announcements' mail in one round go at
    // least 1.1 s apart; one after a sign-in code was asked for, 1.5 s after it.
    const waiting = async (name) => {
      const id = await db.user(`${name}@example.com`, { made: ago(30) });
      await db.q("insert into public.news_mail (account, news, at) values ($1, true, now() - interval '1 day')", [id]);
      await db.q("insert into public.people (account, handle) values ($1, $2)", [id, name]);
      const one = (await act("announce_keep", { title: `For ${name}`, audience: { kind: "person", handle: name }, email: true }, live)).json.announcement;
      answers.push(503);
      await act("announce_send", { id: one.id, hash: one.hash, changed_at: one.changed_at }, live);
      return one.id;
    };
    await waiting("pat");
    await waiting("quin");
    const paceFrom = batches.length;
    await cron();
    const round = batches.slice(paceFrom).map((b) => b.at);
    await waiting("rae");
    await db.q("insert into public.otp_requests (email) values ('someone@example.com')");
    const codeAt = Date.now();
    const codeFrom = batches.length;
    await cron();
    const afterCode = batches.slice(codeFrom).map((b) => b.at - codeAt);
    // Nobody to take: no wait at all.
    const t0 = Date.now();
    await db.call("announce_mail_take", { p_id: kept.id, p_limit: 1 });
    out.fix.pace = { round_batches: round.length, round_gaps_ms: round.slice(1).map((at, i) => at - round[i]), after_code_ms: afterCode,
      empty_take_ms: Date.now() - t0 };
  }
  // L1: two cron runs at once on one due announcement: one sends it, the
  // other says nothing; no hold in the audit, no failed run.
  {
    const kept = (await act("announce_keep", { title: "Overlap", audience: { kind: "everyone" } }, live)).json.announcement;
    const at = new Date(Date.now() + 2 * 3600000).toISOString();
    await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at, at }, live);
    await db.q("update public.announcements set send_at = now() - interval '1 minute' where id = $1", [kept.id]);
    const failedBefore = await n("select count(*)::int as n from public.cron_runs where job = 'announce_due' and outcome = 'failed'").catch(() => -1);
    const [c1, c2] = await Promise.all([cron(), cron()]);
    // The other run's view, made sure of: due as it was read, sent by then.
    const kept2 = (await act("announce_keep", { title: "Overlap, made sure", audience: { kind: "everyone" } }, live)).json.announcement;
    await act("announce_send", { id: kept2.id, hash: kept2.hash, changed_at: kept2.changed_at, at }, live);
    await db.q("update public.announcements set send_at = now() - interval '1 minute' where id = $1", [kept2.id]);
    const due = await db.call("announce_due", {});
    const row = due.find((one) => Number(one.id) === kept2.id);
    await db.call("announce_press", { p_id: row.id, p_test: false, p_changed: row.changed_at, p_by: "the schedule", p_hash: row.pressed_hash,
      p_at: null, p_most: 1000 });
    const { announceDue } = await import("../../../api/_announce.js");
    const before = await auditCount();
    const late = await (async () => {
      // announce_due as the second run read it, before the first sent it.
      const q = globalThis.fetch;
      globalThis.fetch = async (input, init = {}) => (/\/rpc\/announce_due$/.test(String(input))
        ? new Response(JSON.stringify([row]), { status: 200 }) : q(input, init));
      try {
        return await announceDue({ headers: { host: "www.brickworks.diy" } });
      } finally {
        globalThis.fetch = q;
      }
    })();
    out.fix.l1 = { runs: [c1.json?.held, c2.json?.held].sort(), sent: [c1.json?.sent, c2.json?.sent].sort(),
      status: (await db.q("select status from public.announcements where id = $1", [kept.id]))[0].status,
      held_audits: await n("select count(*)::int as n from public.admin_audit where op = 'announce_send' and target in ($1, $2) and status = 409",
        [String(kept.id), String(kept2.id)]),
      failed_runs: (await n("select count(*)::int as n from public.cron_runs where job = 'announce_due' and outcome = 'failed'").catch(() => -1))
        - failedBefore,
      late: { held: late.held, sent: late.sent }, late_audits: (await auditCount()) - before,
      still: (await db.q("select status from public.announcements where id = $1", [kept2.id]))[0].status };
  }
  // L2: off the site (a preview, this machine), the cron sends only the
  // checks' own and mails nobody.
  {
    const theirs = (await act("announce_keep", { title: "The site's, due", audience: { kind: "everyone" }, email: true }, live)).json.announcement;
    const at = new Date(Date.now() + 2 * 3600000).toISOString();
    await act("announce_send", { id: theirs.id, hash: theirs.hash, changed_at: theirs.changed_at, at }, live);
    const pool = (await act("announce_keep", { title: "The checks', due", audience: { kind: "everyone" } })).json.announcement;
    await act("announce_send", { id: pool.id, hash: pool.hash, changed_at: pool.changed_at, at });
    await db.q("update public.announcements set send_at = now() - interval '1 minute' where id = any($1)", [[theirs.id, pool.id]]);
    // Mail of a sent one waiting too, for someone who chose news.
    const kim = await db.user("kim@example.com", { made: ago(30) });
    await db.q("insert into public.news_mail (account, news, at) values ($1, true, now() - interval '1 day')", [kim]);
    await db.q("insert into public.people (account, handle) values ($1, 'kim')", [kim]);
    const w2 = (await act("announce_keep", { title: "Waiting mail", audience: { kind: "person", handle: "kim" }, email: true }, live)).json.announcement;
    // Sent with no mail at once: as a send whose round Resend refused.
    answers.push(503);
    await act("announce_send", { id: w2.id, hash: w2.hash, changed_at: w2.changed_at }, live);
    const status = (await db.q("select count(*)::int as n from public.announcement_mails where announcement = $1", [w2.id]))[0].n;
    const from = batches.length;
    const off = await cron(preview);
    const local = await cron("127.0.0.1:10751");
    const after = (await db.q("select id, status from public.announcements where id = any($1) order by id", [[theirs.id, pool.id]]));
    const offBatches = batches.length - from;
    const on = await cron();
    out.fix.l2 = { mails_waiting: status, off: { sent: off.json?.sent, mailed: off.json?.mailed, held: off.json?.held }, local: local.json?.sent,
      statuses: Object.fromEntries(after.map((one) => [Number(one.id) === theirs.id ? "site" : "checks", one.status])), off_batches: offBatches,
      on: { sent: on.json?.sent, mailed: on.json?.mailed },
      site_after_on: (await db.q("select status from public.announcements where id = $1", [theirs.id]))[0].status };
  }
  // L5: the link is signed with its own secret; one signed with the key
  // before it still holds; any other refused.
  {
    const lee = await db.user("lee@example.com", { made: ago(30) });
    await db.q("insert into public.news_mail (account, news, at) values ($1, true, now() - interval '1 day')", [lee]);
    const { unsubscribeToken } = await import("../../../api/_announce.js");
    const mine = unsubscribeToken(lee);
    const old = createHmac("sha256", `news-unsubscribe:${process.env.SUPABASE_SECRET_KEY}`).update(lee).digest("base64url").slice(0, 32);
    const other = createHmac("sha256", "some-other-key").update(lee).digest("base64url").slice(0, 32);
    const withSecret = createHmac("sha256", process.env.NEWS_UNSUB_SECRET).update(lee).digest("base64url").slice(0, 32);
    const post = (t) => askPeople({ method: "POST", query: { op: "news_unsubscribe", a: lee, t }, headers: { host: live } });
    const refusedOther = (await post(other)).status;
    const byOld = await post(old);
    await db.q("update public.news_mail set news = true where account = $1", [lee]);
    const byNew = await post(mine);
    out.fix.l5 = { own_secret: mine === withSecret, not_old: mine !== old, other: refusedOther, old: byOld.status, now: byNew.status,
      news: (await db.call("news_choice", { p_account: lee }))?.news };
  }
  // L6: the owner's postal address at the foot of each news mail.
  {
    const long = await act("announce_mail_address", { address: "x".repeat(201) }, live);
    const five = await act("announce_mail_address", { address: "a\nb\nc\nd\ne" }, live);
    const set = await act("announce_mail_address", { address: "Brickworks\n1 <Main> St\nSpringfield" }, live);
    const shown = (await read({ op: "announce" }, live)).json.address;
    const { announceMail } = await import("../../../api/_announce.js");
    const mail = announceMail({ title: "T", body: "B", link: null }, adaId, "https://brickworks.diy", shown);
    const bare = announceMail({ title: "T", body: "B", link: null }, adaId, "https://brickworks.diy", "");
    // As the round reads it: the next mail carries it.
    const mo = await db.user("mo@example.com", { made: ago(30) });
    await db.q("insert into public.news_mail (account, news, at) values ($1, true, now() - interval '1 day')", [mo]);
    await db.q("insert into public.people (account, handle) values ($1, 'moe')", [mo]);
    const kept = (await act("announce_keep", { title: "With an address", audience: { kind: "person", handle: "moe" }, email: true }, live)).json.announcement;
    const from = batches.length;
    await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at }, live);
    const sentMail = batches.slice(from).flatMap((b) => b.mails)[0];
    const cleared = await act("announce_mail_address", { address: "" }, live);
    out.fix.l6 = { long: long.status, five: five.status, set: set.status, shown, html: mail.html.includes("Brickworks<br>1 &lt;Main&gt; St<br>Springfield"),
      text: mail.text.includes("Brickworks\n1 <Main> St\nSpringfield"), bare: !bare.html.includes("Springfield") && !bare.text.includes("Springfield"),
      sent_has: Boolean(sentMail?.html.includes("Springfield")), cleared: [cleared.status, (await read({ op: "announce" }, live)).json.address] };
  }
  // A batch Resend refused, then the words edited: the next try is a new key.
  {
    const nia = await db.user("nia@example.com", { made: ago(30) });
    await db.q("insert into public.news_mail (account, news, at) values ($1, true, now() - interval '1 day')", [nia]);
    await db.q("insert into public.people (account, handle) values ($1, 'nia')", [nia]);
    const kept = (await act("announce_keep", { title: "Mail one", body: "first words", audience: { kind: "person", handle: "nia" }, email: true }, live)).json
      .announcement;
    answers.push(429);
    const from = batches.length;
    const sent = await act("announce_send", { id: kept.id, hash: kept.hash, changed_at: kept.changed_at }, live);
    const looked = await act("announce_edit", { id: kept.id, changed_at: sent.json.announcement.changed_at, title: "Mail one, corrected", body: "first words" }, live);
    await act("announce_edit", { id: kept.id, changed_at: sent.json.announcement.changed_at, title: "Mail one, corrected", body: "first words",
      hash: looked.json?.hash }, live);
    await cron();
    const tries = batches.slice(from).filter((b) => b.mails.some((m) => m.to.includes("nia@example.com")));
    out.fix.key_after_edit = { statuses: tries.map((b) => b.status), keys_differ: tries.length === 2 && tries[0].key !== tries[1].key,
      subjects: tries.map((b) => b.mails[0].subject) };
  }

  // --- The audit: every act the owner made, and what the schedule did.
  out.audit = Object.fromEntries((await db.q(`select op, count(*)::int as n from public.admin_audit where op like 'announce%'
    group by op order by op`)).map((row) => [row.op, row.n]));
  out.audit_targets = (await db.q(`select distinct target_kind from public.admin_audit where op like 'announce%' and target_kind is not null`))
    .map((row) => row.target_kind);
  out.audit_test = await n("select count(*)::int as n from public.admin_audit where op like 'announce%' and test and scope <> 'live'");
} catch (trouble) {
  out.error = String(trouble?.stack || trouble);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
