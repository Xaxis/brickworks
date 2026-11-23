// What you hear of, and where, as tests/test_inbox.py runs it: api/people.js's
// ?op=notifications, notification_prefs, notifications_done and
// notification_mute behind tests/fixtures/push_world.mjs (Supabase in memory,
// and the push services), with supabase/notification_prefs.sql's functions
// stood in for as its dry run proved them (bench/results/inbox-2026-11-23):
// one row an account of the kinds here, pushed and emailed, the models
// muted and what was done. notification_list hands back [rows] as the
// database has them; the API does the rest, which is what is tested.
//
//   const w = await inboxWorld({ rows });
//   await w.people("GET", { op: "notifications" }, undefined, await w.signIn(ADA));

import { pushWorld } from "./push_world.mjs";
import { SUPABASE_URL } from "./billing/world.mjs";

export const KINDS = ["comment", "reply", "mention", "photo", "remix", "likes", "talk", "challenge", "result", "achievement",
  "news"];
const AS_KIND = { talk_mention: "mention", talk_reply: "talk", challenge_open: "challenge", challenge_closing: "challenge",
  challenge_won: "result", announcement: "news" };

/// One row of every kind notification_rows has (fourteen), a minute apart,
/// newest first, each about its own group.
export function everyKind(now = Date.now()) {
  const at = (n) => new Date(now - n * 60000).toISOString();
  const by = { handle: "bob-try", name: "Bob" };
  return [
    { kind: "comment", on: "CommentM01", model: "CommentM01", name: "Comment tower", comment: 1, said: "Lovely", by },
    { kind: "reply", on: "ReplyMod01", model: "ReplyMod01", name: "Reply barn", comment: 2, parent: 1, said: "Yes", by },
    { kind: "mention", on: "MentionM01", model: "MentionM01", name: "Mention mill", comment: 3, said: "@ada look", by },
    { kind: "talk_mention", thread: 7, post: 71, title: "Mention thread", said: "@ada", by },
    { kind: "photo", on: "PhotoMod01", model: "PhotoMod01", name: "Photo shed", photo: "PhOtO1", words: "Built", yours: true, by },
    { kind: "remix", on: "RemixMod01", model: "RemixOf001", of: "RemixMod01", name: "Remix boat", of_name: "Remix ship", by },
    { kind: "likes", on: "LikesMod01", model: "LikesMod01", name: "Likes castle", likes: 3, day: at(7).slice(0, 10) },
    { kind: "talk_reply", thread: 8, post: 81, title: "Followed thread", said: "And then", by },
    { kind: "challenge_open", challenge: 5, title: "Open one", ends_on: "2026-12-01" },
    { kind: "challenge_closing", challenge: 6, title: "Closing one", ends_on: "2026-12-02" },
    { kind: "result", on: "ResultMd01", model: "ResultMd01", name: "Result rover", challenge: 9, title: "Entered one",
      won: true, way: "hand", votes: 4 },
    { kind: "challenge_won", challenge: 10, title: "Voted one", picked: true },
    { kind: "achievement", track: "listed", level: 1, of: 3, reached: 1 },
    { kind: "announcement", announcement: 4, title: "News one", said: "Something new" },
  ].map((row, n) => ({ ...row, at: at(n + 1) }));
}

export async function inboxWorld({ rows = everyKind(), sqlApplied = true } = {}) {
  const p = await pushWorld({});
  const self = Object.assign(p, {
    rows,
    /// notification_prefs, by account: {here, push, email, muted, done, done_all}, as the SQL keeps it.
    prefs: new Map(),
    /// Each notification_list asked: its mark.
    listMarks: [],
  });
  const theirs = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const fn = url.origin === SUPABASE_URL && /^\/rest\/v1\/rpc\/(\w+)$/.exec(url.pathname)?.[1];
    const reply = (body, status = 200) => new Response(JSON.stringify(body), { status });
    const a = JSON.parse(String(init.body || "{}"));
    const of = (viewer) => {
      const kept = self.prefs.get(viewer);
      return { kept: Boolean(kept), here: kept?.here ?? KINDS, push: kept?.push ?? ["reply", "mention"], email: kept?.email ?? [],
        muted: kept?.muted ?? [], done: kept?.done ?? {}, done_all: kept?.done_all ?? null };
    };
    const row = (viewer) => {
      if (!self.prefs.has(viewer)) self.prefs.set(viewer, { here: null, push: null, email: null, muted: [], done: {}, done_all: null });
      return self.prefs.get(viewer);
    };
    if (fn === "notification_list") {
      self.listMarks.push(a.mark);
      return reply({ rows: self.rows, models: {}, seen_at: null, read_at: null, reads: {} });
    }
    if (fn === "achievement_mark") return reply(0);
    if (["notification_prefs_of", "notification_choose", "notification_mute", "notification_done", "notification_count_kept"]
      .includes(fn) && !sqlApplied) return reply({ message: "Could not find the function" }, 404);
    if (fn === "notification_prefs_of") return reply(of(a.viewer));
    if (fn === "notification_choose") {
      const kept = row(a.viewer);
      const now = of(a.viewer)[a.p_channel];
      kept[a.p_channel] = a.p_on ? [...new Set([...now, a.p_kind])].sort() : now.filter((k) => k !== a.p_kind);
      return reply(of(a.viewer));
    }
    if (fn === "notification_mute") {
      const kept = row(a.viewer);
      kept.muted = a.p_on ? [...new Set([...kept.muted, a.p_model])] : kept.muted.filter((m) => m !== a.p_model);
      return reply({ muted: kept.muted.includes(a.p_model), count: kept.muted.length });
    }
    if (fn === "notification_done") {
      const kept = row(a.viewer);
      const before = a.p_group === null ? kept.done_all : kept.done[a.p_group] ?? null;
      const mark = a.p_undo ? a.p_at : [before, a.p_at].filter(Boolean).sort().pop();
      if (a.p_group === null) kept.done_all = mark;
      else if (mark === null) delete kept.done[a.p_group];
      else kept.done[a.p_group] = mark;
      return reply({ group: a.p_group, at: mark, before });
    }
    if (fn === "notification_count_kept") {
      if (!self.prefs.has(a.viewer)) return reply(null);
      const kept = of(a.viewer);
      const marks = (r) => Math.max(Date.parse(kept.done_all || "") || -Infinity,
        Date.parse(kept.done[groupOf(r)] || "") || -Infinity);
      return reply(self.rows.filter((r) => kept.here.includes(AS_KIND[r.kind] || r.kind) && !kept.muted.includes(r.on || "")
        && Date.parse(r.at) > marks(r)).length);
    }
    if (fn === "notification_counts") return reply({ notifications: self.rows.length, feed: 0 });
    return theirs(input, init);
  };
  return self;
}

/// notification_group's key for [r].
export function groupOf(r) {
  if (r.kind === "achievement") return "achievements";
  if (["challenge_open", "challenge_closing", "challenge_won"].includes(r.kind)) return `challenge-${r.challenge}`;
  if (r.kind === "announcement") return `announcement-${r.announcement}`;
  if (r.kind === "talk_reply" || r.kind === "talk_mention") return `talk-${r.thread}`;
  return r.on || "";
}
