// supabase/announce.sql held in a Postgres of this machine's own
// (tests/fixtures/announce/world.mjs), after the console's files, for
// proving the console's Announcements, the Notifications page, Settings'
// news and the site's notice in a real browser before the file is applied:
//
//   grep -E '^(SUPABASE_URL|SUPABASE_SECRET_KEY|SUPABASE_PUBLISHABLE_KEY|MASTER_EMAIL)=' .env > $SCRATCH/flow.env
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js PG_BIN=<postgres's bin> NEWS_UNSUB_SECRET=<made up> \
//     node --env-file=$SCRATCH/flow.env tools/web/relay_server.mjs 10701 --hold=announce
//   node --env-file=$SCRATCH/flow.env tools/web/announce_flow.mjs --url=http://127.0.0.1:10701 --out=DIR
//
// Never the whole .env (anfix, 2026-11-18): with its mail key and cron
// secret this machine's server could mail and run the site's crons, and a
// local flow with it once deleted the project's own test rows.
//
// As feedback_stand_in.mjs does, nothing is written again in JavaScript:
// every announce_*, announcement_*, news_*, site_notice*, site_setting*
// and admin_audit_* function the server asks is the file's own, answered by
// that Postgres, so the console's acts, its settings and its audit are held
// here, apart from the project's. An account a function names is copied
// from the project's auth.users (and its handle from people) the first time,
// so the real sign-ins work over it and an audience finds it.
//
// What a person's Notifications are made of is the project's, with what
// this Postgres holds for them joined in as announce.sql's notification_rows
// joins it (union all): notification_list's rows and notification_counts'
// count each get the person's announcements of the last 90 days, those
// since their seen mark counted. The SQL itself is proven on the project's
// own, rolled back (tools/announce_try.sql); this is for the code around it.
//
// What is held is at /__held/announcements, on this machine only.
import { announceWorld } from "../../tests/fixtures/announce/world.mjs";

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const RPC = /\/rest\/v1\/rpc\/([a-z_]+)$/;
const HERE = /^(announce_[a-z_]*|announcement_[a-z_]*|news_[a-z_]*|site_notice[a-z_]*|site_setting[a-z_]*|admin_audit_[a-z_]*)$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const DAY = 864e5;

let db = null;
let inner = null;
const copied = new Set();

const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
const asServer = { apikey: SECRET, authorization: `Bearer ${SECRET}` };

/// The account [id] in the held auth.users and people, as the project has it.
async function copyAccount(id) {
  if (!UUID.test(String(id || "")) || copied.has(id)) return;
  const reply = await inner(`${SUPABASE}/auth/v1/admin/users/${id}`, { headers: asServer });
  if (!reply.ok) return;
  const user = await reply.json();
  await db.q(`insert into auth.users (id, email, created_at, email_confirmed_at, last_sign_in_at) values ($1, $2, $3, $4, $5)
    on conflict (id) do nothing`, [user.id, user.email, user.created_at, user.email_confirmed_at, user.last_sign_in_at]);
  const person = await inner(`${SUPABASE}/rest/v1/people?account=eq.${id}&select=account,handle,name`, { headers: asServer })
    .then((r) => (r.ok ? r.json() : []), () => []);
  if (person[0]?.handle) {
    await db.q("insert into public.people (account, handle, name) values ($1, $2, $3) on conflict do nothing",
      [id, person[0].handle, person[0].name ?? null]);
  }
  copied.add(id);
}

/// Every account a call names, copied before it is answered.
async function copyNamed(body) {
  for (const key of ["p_account", "viewer", "p_by_account"]) if (UUID.test(String(body?.[key] || ""))) await copyAccount(body[key]);
}

/// [viewer]'s announcements since [since], as notification_rows gives them.
async function mine(viewer, since) {
  await copyAccount(viewer);
  const rows = await db.q("select kind, at, model, item from public.announcement_rows($1, $2, now())", [viewer, since]);
  return rows.map((row) => ({ kind: row.kind, at: new Date(row.at).toISOString(), on: row.model, ...row.item }));
}

async function real(name, body) {
  const reply = await inner(`${SUPABASE}/rest/v1/rpc/${name}`, { method: "POST",
    headers: { ...asServer, "content-type": "application/json" }, body: JSON.stringify(body) });
  return { reply, said: reply.ok ? await reply.json() : null };
}

export async function hold() {
  if (inner) return;
  db = await announceWorld();
  inner = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const where = String(url);
    const rpc = where.startsWith(SUPABASE) ? RPC.exec(where.split("?")[0]) : null;
    if (!rpc) return inner(url, init);
    let body = {};
    try {
      body = init.body ? JSON.parse(init.body) : {};
    } catch {
      body = {};
    }
    if (HERE.test(rpc[1])) {
      await copyNamed(body);
      try {
        return json(200, await db.call(rpc[1], body));
      } catch (trouble) {
        return json(/does not exist/.test(String(trouble.message)) ? 404 : 400, { message: String(trouble.message) });
      }
    }
    // The person's Notifications: the project's, and theirs from here.
    if (rpc[1] === "notification_list" && UUID.test(String(body.viewer || ""))) {
      const { reply, said } = await real("notification_list", body);
      if (!reply.ok || !said) return reply;
      const theirs = await mine(body.viewer, new Date(Date.now() - 90 * DAY).toISOString());
      said.rows = [...(said.rows || []), ...theirs].sort((a, b) => Date.parse(b.at) - Date.parse(a.at)).slice(0, 200);
      return json(200, said);
    }
    if (rpc[1] === "notification_counts" && UUID.test(String(body.viewer || ""))) {
      const { reply, said } = await real("notification_counts", body);
      if (!reply.ok || !said) return reply;
      const marks = (await real("notification_list", { viewer: body.viewer, mark: false })).said;
      const from = Math.max(Date.parse(marks?.seen_at || "") || 0, Date.now() - 90 * DAY);
      const theirs = await mine(body.viewer, new Date(from).toISOString());
      return json(200, { ...said, notifications: Math.min(99, (Number(said.notifications) || 0) + theirs.length) });
    }
    return inner(url, init);
  };
  const stop = async () => {
    await db.stop().catch(() => {});
    process.exit(0);
  };
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
  console.log("announce.sql held here, in a Postgres of this machine's own, with the console's files under it");
}

/// What is held now, for a check to read (/__held/announcements).
export async function rowsOf(name) {
  if (name !== "announcements" || !db) return null;
  return {
    announcements: await db.q("select id::int as id, test, title, status, reach, email, edited_at is not null as edited from public.announcements order by id"),
    reads: await db.q("select announcement::int as announcement, account, read_at is not null as read, clicked_at is not null as clicked "
      + "from public.announcement_reads order by 1, 2"),
    mails: await db.q("select announcement::int as announcement, account, state from public.announcement_mails order by 1, 2"),
    news: await db.q("select account, news, via from public.news_mail order by 1"),
    hides: await db.q("select account, notice::int as notice from public.site_notice_hides order by 1, 2"),
    notices: await db.q("select id::int as id, scope, words, ends_at, cleared_at from public.site_notices order by id"),
  };
}
