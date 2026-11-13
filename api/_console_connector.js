// The console's Connector section (/admin#connector, docs/ADMIN.md,
// console2): the Claude connector as each account uses it, live and lately.
// Read only: nothing here ends or changes anybody's connector or session.
//
// What the relay keeps (supabase/relay.sql, oauth.sql, console2.sql):
//
//   oauth_grants     a Claude (claude.ai, Claude Code, ...) the account let
//                    in: which, since when, last used
//   relay_tabs       each Brickworks tab switched on as a connector: the
//                    tab's short id, the model open in it, open or gone,
//                    last heard (a page says it is alive every ten seconds)
//   relay_picks      each Claude conversation and the tab it works in:
//                    since when, its last call and which tool, how many
//                    calls (relay_call_note); gone once its tab has closed
//   relay_call_days  each account's calls a day, kept after its
//                    conversations have gone
//
// A conversation is named as the tab names it (api/mcp.js chatOf): eight
// letters of a hash of its key, never the session's own id.

import { createHash } from "node:crypto";
import { db } from "./_db.js";
import { allUsers, isTestAddress } from "./_console.js";

const DAY = 864e5;
// As api/mcp.js has them: a page heard from in this long is there
// (TAB_LOST_MS), and a conversation that called in this long still holds its
// tab (HELD_MS).
const TAB_HEARD_MS = 180_000;
const HELD_MS = 30 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const chatOf = (key) => createHash("sha256").update(String(key)).digest("hex").slice(0, 8);
const notYet = (trouble) => /: (400|404)$/.test(String(trouble?.message || ""));

/// [path] read, or [fallback] when the table or column is not there yet
/// (console2.sql not applied).
async function readOr(path, fallback = null) {
  try {
    return await db(path);
  } catch (trouble) {
    if (notYet(trouble)) return fallback;
    throw trouble;
  }
}

/// GET /api/admin?op=connector[&account=U][&tests=1]: every account that
/// ever let a Claude in or switched a tab on (the checks' own for [tests]),
/// with its conversations; or one account's, whoever it is.
export async function connectorRead(tests = false, account = null, now = Date.now()) {
  if (account !== null && !UUID.test(account)) return null;
  const owner = account ? `&owner=eq.${account}` : "&owner=not.is.null";
  const since = new Date(now - 30 * DAY).toISOString().slice(0, 10);
  const [users, tabs, counted, grants, days] = await Promise.all([
    allUsers(),
    db(`relay_tabs?select=channel,owner,tab,model,open,visible,seen_at,used_at${owner}&order=seen_at.desc&limit=2000`),
    readOr(`relay_picks?select=key,owner,channel,picked_at,called_at,did,moved_at,calls${owner}&order=picked_at.desc&limit=2000`),
    db(`oauth_grants?select=owner,client_name,client_info,created_at,used_at${owner}&order=created_at.desc&limit=2000`),
    readOr(`relay_call_days?select=owner,day,calls,last_at,last_tool&day=gte.${since}${owner}&order=day.desc&limit=5000`),
  ]);
  // Before console2.sql there is no count of calls: the picks without it.
  const picks = counted ?? await db(`relay_picks?select=key,owner,channel,picked_at,called_at,did,moved_at${owner}`
    + "&order=picked_at.desc&limit=2000");
  const emails = new Map(users.map((user) => [user.id, user.email || null]));
  const tabOf = new Map(tabs.map((tab) => [tab.channel, tab]));
  const isLive = (tab) => Boolean(tab?.open) && now - Date.parse(tab.seen_at) < TAB_HEARD_MS;
  const accounts = new Map();
  const of = (id) => {
    if (!accounts.has(id)) {
      accounts.set(id, { account: id, email: emails.get(id) ?? null, claudes: [], tabs: [], sessions: [],
        calls: { today: 0, week: 0, month: 0 }, last: null });
    }
    return accounts.get(id);
  };
  for (const grant of grants) {
    of(grant.owner).claudes.push({ name: grant.client_name || grant.client_info?.name || "a Claude",
      client: grant.client_info?.name ? `${grant.client_info.name}${grant.client_info.version ? ` ${grant.client_info.version}` : ""}` : null,
      since: grant.created_at, used_at: grant.used_at || null });
  }
  for (const tab of tabs) {
    of(tab.owner).tabs.push({ tab: tab.tab || null, model: tab.model || null, open: Boolean(tab.open), live: isLive(tab),
      seen_at: tab.seen_at, used_at: tab.used_at || null, visible: tab.visible !== false });
  }
  for (const pick of picks) {
    if (!pick.owner) continue;
    const tab = tabOf.get(pick.channel);
    const last = pick.called_at || pick.picked_at;
    of(pick.owner).sessions.push({ chat: chatOf(pick.key), way: String(pick.key).split(":")[0], tab: tab?.tab || null,
      model: tab?.model || null, since: pick.picked_at, last_call: pick.called_at || null, tool: pick.called_at ? pick.did || null : null,
      calls: pick.calls ?? null, moved: Boolean(pick.moved_at),
      live: isLive(tab) && !pick.moved_at && now - Date.parse(last) < HELD_MS });
  }
  const today = new Date(now).toISOString().slice(0, 10);
  const weekAgo = new Date(now - 7 * DAY).toISOString().slice(0, 10);
  for (const day of days || []) {
    const one = of(day.owner);
    one.calls.month += day.calls;
    if (day.day > weekAgo) one.calls.week += day.calls;
    if (day.day === today) one.calls.today += day.calls;
    if (!one.last || day.last_at > one.last.at) one.last = { at: day.last_at, tool: day.last_tool || null };
  }
  const rows = [...accounts.values()]
    .filter((one) => account || isTestAddress(one.email) === tests)
    .map((one) => {
      for (const s of one.sessions) if (s.last_call && (!one.last || s.last_call > one.last.at)) one.last = { at: s.last_call, tool: s.tool };
      const live = one.sessions.filter((s) => s.live).length;
      const open = one.tabs.filter((tab) => tab.live).length;
      // Where it stands, in a word: a conversation working now, a tab on and
      // waiting, a Claude let in with no tab on, or a tab on with no Claude.
      const state = live ? "working" : open ? "on" : one.claudes.length ? "added" : one.tabs.length ? "tab" : "none";
      return { ...one, state, live_sessions: live, live_tabs: open };
    })
    .sort((a, b) => String(b.last?.at || b.tabs[0]?.seen_at || "").localeCompare(String(a.last?.at || a.tabs[0]?.seen_at || "")));
  return { tests, counted: counted !== null, days_kept: days !== null, accounts: rows,
    sessions: rows.flatMap((one) => one.sessions.map((s) => ({ ...s, account: one.account, email: one.email })))
      .sort((a, b) => String(b.last_call || b.since).localeCompare(String(a.last_call || a.since))) };
}
