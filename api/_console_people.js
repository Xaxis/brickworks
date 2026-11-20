// The owner's console, part C (console3, 2026-11-13; docs/ADMIN.md): People
// finished, and the console's search.
//
//   personMore      what an account's panel adds to part A's: its lists, its
//                   comments, its build photos, its challenge entries
//   exportAccount   POST ?op=export&account=U: every row of the account
//                   (supabase/console3.sql admin_export: each table with a
//                   foreign key to auth.users, so a table added later is in
//                   it, and the sets in its lists; at most 1000 a table, a value over 8 KB named by
//                   its size) and its sign-in's own facts, as JSON for the
//                   owner to send on at the person's request; kept in the
//                   audit
//   deleteAccount   POST ?op=delete_account&account=U {confirm, reason}: the
//                   account deleted on its person's request, exactly as they
//                   would delete it themselves (api/_erase.js), with its
//                   address typed again; never the owner's; irreversible
//   signOut         POST ?op=sign_out&account=U: every session of it ended,
//                   and every Claude it let in (admin_sign_out)
//   findRead        GET ?op=find&q=W: accounts, people, models, lists,
//                   reports and acts that hold W
//
// api/admin.js asks these behind its owner check, the acts through audited().

import { isMaster } from "./_auth.js";
import { db, reach } from "./_db.js";
import { erase } from "./_erase.js";
import { allUsers, auditOf, isTestAddress } from "./_console.js";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const known = (promise) => Promise.resolve(promise).catch((trouble) => {
  if (!notYet(trouble) && !/: 400$/.test(String(trouble?.message || ""))) {
    console.error(`console: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  return null;
});

function project() {
  return (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// The account's sign-in record as Supabase keeps it, or null.
async function userOf(account) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  const reply = await reach("server GET user", 10, `${project()}/auth/v1/admin/users/${account}`,
    { headers: { apikey: secret, authorization: `Bearer ${secret}` } });
  if (reply.status === 404) return null;
  if (!reply.ok) throw new Error(`server GET user: ${reply.status}`);
  const user = await reply.json();
  return user?.id ? user : null;
}

const accountOf = (request) => String(request.query?.account || "").toLowerCase();

// ---------------------------------------------------------------------------
// The panel's more.

/// An account's lists, comments, photos and challenge entries, newest first;
/// each null where its table is not there. And how many people blocked it
/// (supabase/block.sql), never who: read only, for the owner to weigh
/// beside its reports.
export async function personMore(account) {
  const [lists, photos, more, blockedBy] = await Promise.all([
    known(db(`model_collections?owner=eq.${account}&select=id,name,public,updated_at&order=updated_at.desc&limit=50`)),
    known(db(`build_photos?account=eq.${account}&select=id,model,words,at,hidden_at,removed_at&order=at.desc&limit=50`)),
    // The comments' and challenges' tables are the server's through functions alone.
    known(db("rpc/admin_person_more", { method: "POST", body: { p_account: account } })),
    known(db("rpc/block_count_against", { method: "POST", body: { p_account: account } })),
  ]);
  const comments = more?.comments ?? null;
  const entries = more?.entries ?? null;
  return {
    lists: lists && lists.map((one) => ({ id: one.id, name: one.name, public: one.public === true, updated_at: one.updated_at })),
    comments: comments && comments.map((one) => ({ id: one.id, model: one.model, body: String(one.body || "").slice(0, 280),
      at: one.at, state: one.removed_at ? `removed by ${one.removed_by === "admin" ? "you" : "its author"}` : one.hidden_at
        ? "hidden by the model's builder" : "shown" })),
    photos: photos && photos.map((one) => ({ id: one.id, model: one.model, words: one.words ?? null, at: one.at,
      state: one.removed_at ? "taken out" : one.hidden_at ? "hidden" : "shown" })),
    entries,
    blocked_by: Number.isInteger(blockedBy) ? blockedBy : null,
  };
}

// ---------------------------------------------------------------------------
// Export, delete, sign out.

/// POST ?op=export&account=U: {account, email, exported_at, sign_in, tables, followers, more, counts, rows}.
export async function exportAccount(request, response) {
  const account = accountOf(request);
  if (!UUID.test(account)) return response.status(400).json({ error: "name an account: ?account=<id>" });
  const user = await userOf(account);
  if (!user) return response.status(404).json({ error: "no such account" });
  let rows;
  try {
    rows = await db("rpc/admin_export", { method: "POST", body: { p_account: account } });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(503).json({ error: "Not open yet: supabase/console3.sql is not applied." });
    throw trouble;
  }
  const tables = rows?.tables || {};
  const more = rows?.more || {};
  // Who follows this account is the follower's private act, not this
  // account's data: the export says how many, never whose account it is.
  const followers = more["follows.followed"] ?? (tables["follows.followed"] || []).length;
  delete tables["follows.followed"];
  delete more["follows.followed"];
  // Who blocked this account is theirs alone, and it is never told: the
  // export says nothing of it, not even how many (supabase/block.sql). Whom
  // it blocked is its own, and stays (blocks.blocker).
  delete tables["blocks.blocked"];
  delete more["blocks.blocked"];
  // The sets in its lists (lists1's collection_sets, its own sets among
  // them): keyed to a list, not to the account, so admin_export's search by
  // key to auth.users does not find them.
  const lists = (tables.model_collections || []).map((one) => String(one.id)).filter((id) => /^[A-Za-z0-9]{10}$/.test(id));
  const sets = [];
  for (let at = 0; at < lists.length && sets.length < 1000; at += 100) {
    try {
      sets.push(...((await db(`collection_sets?collection=in.(${lists.slice(at, at + 100).join(",")})&select=*&limit=1000`)) || []));
    } catch (trouble) {
      if (notYet(trouble)) break;
      throw trouble;
    }
  }
  if (sets.length) tables.collection_sets = sets.slice(0, 1000);
  return response.status(200).json({
    account,
    email: user.email || null,
    exported_at: new Date().toISOString(),
    // What Supabase keeps of the sign-in, never a secret of it.
    sign_in: { email: user.email || null, created_at: user.created_at || null, last_sign_in_at: user.last_sign_in_at || null,
      confirmed_at: user.email_confirmed_at || user.confirmed_at || null, providers: user.app_metadata?.providers || null },
    tables,
    followers,
    // Where a table has more than the 1000 rows given, how many it has in all.
    more,
    counts: Object.fromEntries(Object.entries(tables).map(([name, list]) => [name, list.length])),
    rows: Object.values(tables).reduce((n, list) => n + list.length, 0),
  });
}

/// POST ?op=delete_account&account=U {confirm: its address, reason}.
export async function deleteAccount(request, response, claims) {
  const account = accountOf(request);
  if (!UUID.test(account)) return response.status(400).json({ error: "name an account: ?account=<id>" });
  const user = await userOf(account);
  if (!user) return response.status(404).json({ error: "no such account" });
  const address = String(user.email || "").trim().toLowerCase();
  if (isMaster({ email: user.email }) || account === claims.sub) {
    return response.status(403).json({ error: "The owner's account holds this console and is not deleted from here." });
  }
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const typed = String(body.confirm || "").trim().toLowerCase();
  if (!address || typed !== address) {
    return response.status(422).json({ error: "Type the account's address exactly as it signs in with it to delete it." });
  }
  const gone = await erase(account);
  return response.status(gone.status).json({ account, email: address, ...gone.body });
}

/// POST ?op=sign_out&account=U: {account, sessions, claudes}.
export async function signOut(request, response) {
  const account = accountOf(request);
  if (!UUID.test(account)) return response.status(400).json({ error: "name an account: ?account=<id>" });
  if (!(await userOf(account))) return response.status(404).json({ error: "no such account" });
  let ended;
  try {
    ended = await db("rpc/admin_sign_out", { method: "POST", body: { p_account: account } });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(503).json({ error: "Not open yet: supabase/console3.sql is not applied." });
    throw trouble;
  }
  return response.status(200).json({ account, sessions: ended?.sessions ?? null, claudes: ended?.claudes ?? null });
}

// ---------------------------------------------------------------------------
// Find anything.

/// GET ?op=find&q=W[&tests=1]: {query, accounts, people, models, lists, reports, acts}.
export async function findRead(query, tests) {
  const q = String(query || "").replace(/[\u0000-\u001f\u007f]+/g, " ").trim().slice(0, 100);
  const none = { query: q, accounts: [], people: [], models: [], lists: [], reports: [], acts: [] };
  if (q.length < 2) return none;
  const [users, found, acts] = await Promise.all([
    known(allUsers()),
    known(db("rpc/admin_find", { method: "POST", body: { p_query: q, p_tests: tests } })),
    known(auditOf({ tests, query: q, limit: 8 })),
  ]);
  const emails = new Map((users || []).map((user) => [user.id, user.email || null]));
  const lower = q.toLowerCase();
  const mine = (account) => isTestAddress(emails.get(account)) === tests;
  return {
    query: q,
    accounts: (users || []).filter((user) => isTestAddress(user.email) === tests
      && (String(user.email || "").toLowerCase().includes(lower) || user.id === lower))
      .slice(0, 10).map((user) => ({ id: user.id, email: user.email || null, last_sign_in: user.last_sign_in_at || null })),
    people: (found?.people || []).filter((one) => mine(one.account))
      .map((one) => ({ account: one.account, handle: one.handle, name: one.name ?? null, email: emails.get(one.account) || null })),
    models: (found?.models || []).map((one) => ({ id: one.id, name: one.name, email: emails.get(one.owner) || null,
      state: one.barred ? "taken out" : one.listed ? "in the gallery" : one.published ? "published" : "not published" })),
    lists: (found?.lists || []).filter((one) => mine(one.owner))
      .map((one) => ({ id: one.id, name: one.name, public: one.public === true, email: emails.get(one.owner) || null })),
    reports: (found?.reports || []).map((one) => ({ id: one.id, at: one.at, reason: one.reason, note: one.note ?? null,
      about: one.model ? `/m/${one.model}` : one.handle ? `@${one.handle}` : one.collection ? `list ${one.collection}` : "—",
      open: !one.resolved_at, resolution: one.resolution ?? null })),
    acts: (acts?.rows || []).map((row) => ({ id: row.id, at: row.at, op: row.op, target_kind: row.target_kind, target: row.target,
      status: row.status, email: row.email ?? null })),
    ready: found !== null,
  };
}
