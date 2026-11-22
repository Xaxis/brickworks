// supabase/talk.sql held in a Postgres of this machine's own
// (tests/fixtures/talk/world.mjs), for proving Talk's pages, its API, the
// console's Talk and a person's Notifications in a real browser before the
// file is applied:
//
//   grep -E '^(SUPABASE_URL|SUPABASE_SECRET_KEY|SUPABASE_PUBLISHABLE_KEY)=' .env > $SCRATCH/flow.env
//   echo MASTER_EMAIL=<a throwaway at resend.dev> >> $SCRATCH/flow.env
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js PG_BIN=<postgres's bin> \
//     node --env-file=$SCRATCH/flow.env tools/web/relay_server.mjs 11170 --hold=talk
//   node --env-file=$SCRATCH/flow.env tools/web/talk_flow.mjs --url=http://127.0.0.1:11170 --out=DIR
//
// Never the whole .env, and never the owner's address as MASTER_EMAIL: the
// console here is a throwaway's, so no check signs in as the owner.
//
// As announce_stand_in.mjs does, nothing is written again in JavaScript:
// every talk_* and admin_audit_* function the server asks is the file's
// own, answered by that Postgres, so Talk, its console acts and their
// audit are held here, apart from the project's. What talk.sql reads of
// the project is copied in as it is named: an account (auth.users, its
// handle and its age answer), a handle somebody mentions, a model a thread
// is about, the challenges (challenge_list), and a block as the project's
// block_person makes it (the project's blocks are read only through its
// functions). When the project's test pool has no challenge open today, a
// test one of this month is held here, so its thread is made.
//
// A person's Notifications are the project's, with what this Postgres
// holds for them joined in as talk.sql's notification_rows joins it:
// notification_list's rows and notification_counts' count each get the
// person's Talk rows of the last 90 days, those since their seen mark
// counted. The SQL itself is proven on the project's own, rolled back
// (tools/talk_try.sql); this is for the code around it.
//
// What is held is at /__held/talk, on this machine only.
import { talkWorld } from "../../tests/fixtures/talk/world.mjs";

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const RPC = /\/rest\/v1\/rpc\/([a-z_]+)$/;
const HERE = /^(talk_[a-z_]*|admin_audit_[a-z_]*)$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const MODEL = /^[A-Za-z0-9]{10}$/;
const DAY = 864e5;

let db = null;
let inner = null;
const copied = new Set();
const models = new Set();
let challengesAt = 0;

const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
const asServer = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
const rest = (path) => inner(`${SUPABASE}/rest/v1/${path}`, { headers: asServer }).then((r) => (r.ok ? r.json() : []), () => []);

async function real(name, body) {
  const reply = await inner(`${SUPABASE}/rest/v1/rpc/${name}`, { method: "POST",
    headers: { ...asServer, "content-type": "application/json" }, body: JSON.stringify(body) });
  return { reply, said: reply.ok ? await reply.clone().json() : null };
}

/// The account [id] in the held auth.users, people and profiles, as the
/// project has it (its age answered or not, taken out or not).
async function copyAccount(id) {
  if (!UUID.test(String(id || "")) || copied.has(id)) return;
  const reply = await inner(`${SUPABASE}/auth/v1/admin/users/${id}`, { headers: asServer });
  if (!reply.ok) return;
  const user = await reply.json();
  await db.q(`insert into auth.users (id, email, created_at, email_confirmed_at, last_sign_in_at) values ($1, $2, $3, $4, $5)
    on conflict (id) do nothing`, [user.id, user.email, user.created_at, user.email_confirmed_at, user.last_sign_in_at]);
  const [person] = await rest(`people?account=eq.${id}&select=account,handle,name`);
  if (person?.handle) {
    await db.q("insert into public.people (account, handle, name) values ($1, $2, $3) on conflict (account) do update set handle = $2, name = $3",
      [id, person.handle, person.name ?? null]);
  }
  const [profile] = await rest(`profiles?id=eq.${id}&select=id,over_13`);
  if (profile) await db.q("insert into public.profiles (id, over_13) values ($1, $2) on conflict (id) do update set over_13 = $2", [id, profile.over_13]);
  const barred = await rest(`barred_accounts?account=eq.${id}&select=account`);
  if (barred.length) await db.q("insert into public.barred_accounts (account) values ($1) on conflict do nothing", [id]);
  copied.add(id);
}

/// Each of [handles]' accounts, as copyAccount copies one.
async function copyHandles(handles) {
  const wanted = [...new Set((Array.isArray(handles) ? handles : []).map(String))].filter((one) => HANDLE.test(one));
  if (!wanted.length) return;
  for (const person of await rest(`people?handle=in.(${wanted.join(",")})&select=account`)) await copyAccount(person.account);
}

/// Model [id], as the project lists it, with its owner.
async function copyModel(id) {
  if (!MODEL.test(String(id || "")) || models.has(id)) return;
  const [model] = await rest(`shared_models?id=eq.${id}&select=id,owner,name,published,barred,listed,test,has_image,has_thumb,updated_at`);
  if (!model) return;
  await copyAccount(model.owner);
  await db.q(`insert into public.shared_models (id, owner, name, published, barred, listed, test, has_image, has_thumb, updated_at)
    values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) on conflict (id) do nothing`,
  [model.id, model.owner, model.name, model.published, model.barred, model.listed, model.test, model.has_image, model.has_thumb, model.updated_at]);
  models.add(id);
}

/// The project's challenges (challenge_list, the test pool's too), at most
/// once a minute; and a test one of this month when none is open today.
async function copyChallenges() {
  if (Date.now() - challengesAt < 60e3) return;
  challengesAt = Date.now();
  const { said } = await real("challenge_list", { tests: true });
  for (const one of Array.isArray(said) ? said : []) {
    await db.q(`insert into public.challenges (id, title, brief, starts_on, ends_on, test, ended_at) values ($1, $2, $3, $4, $5, $6, $7)
      on conflict (id) do update set title = $2, brief = $3, starts_on = $4, ends_on = $5, test = $6, ended_at = $7`,
    [one.id, one.title, one.brief, one.starts_on, one.ends_on, one.test === true, one.ended_at]);
  }
  await db.q(`insert into public.challenges (id, title, brief, starts_on, ends_on, test)
    select 990001, 'Talk check: tiny towns', 'Build a town that fits on a 16 by 16 plate.',
           date_trunc('month', now() at time zone 'utc')::date, (date_trunc('month', now() at time zone 'utc') + interval '1 month - 1 day')::date, true
     where not exists (select 1 from public.challenges c where c.test and c.ended_at is null
                        and c.starts_on <= (now() at time zone 'utc')::date and c.ends_on >= (now() at time zone 'utc')::date)
    on conflict (id) do nothing`);
}

/// Everything a call names, copied before it is answered.
async function copyNamed(name, body) {
  for (const key of ["account", "viewer", "p_account"]) if (UUID.test(String(body?.[key] || ""))) await copyAccount(body[key]);
  if (name === "talk_mention") await copyHandles(body.handles);
  if (MODEL.test(String(body?.p_model || ""))) await copyModel(body.p_model);
  if (name === "talk_ensure" || name === "talk_seed" || name === "talk_threads_of") await copyChallenges();
  if (name === "talk_ensure" || name === "talk_seed") for (const one of await rest("people?handle=eq.brickworks&select=account")) await copyAccount(one.account);
}

/// [viewer]'s Talk rows since [since], as notification_rows gives them.
async function mine(viewer, since) {
  await copyAccount(viewer);
  const rows = await db.q("select kind, at, model, item from public.talk_notice_rows($1, $2, now())", [viewer, since]);
  return rows.map((row) => ({ kind: row.kind, at: new Date(row.at).toISOString(), on: row.model, ...row.item }));
}

export async function hold() {
  if (inner) return;
  db = await talkWorld();
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
      await copyNamed(rpc[1], body);
      try {
        return json(200, await db.call(rpc[1], body));
      } catch (trouble) {
        return json(/does not exist/.test(String(trouble.message)) ? 404 : 400, { message: String(trouble.message) });
      }
    }
    // A block as the project makes it, then the same here: Talk reads it.
    if (rpc[1] === "block_person" && UUID.test(String(body.account || ""))) {
      const { reply, said } = await real("block_person", body);
      if (reply.ok && said && !said.refused) {
        await copyAccount(body.account);
        await copyHandles([body.wanted]);
        const [other] = await db.q("select account from public.people where handle = $1", [String(body.wanted || "")]);
        if (other && body.blocking) {
          await db.q("insert into public.blocks (blocker, blocked) values ($1, $2) on conflict do nothing", [body.account, other.account]);
        } else if (other) {
          await db.q("delete from public.blocks where blocker = $1 and blocked = $2", [body.account, other.account]);
        }
      }
      return reply;
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
  console.log("talk.sql held here, in a Postgres of this machine's own, with the console's files under it");
}

/// What is held now, for a check to read (/__held/talk).
export async function rowsOf(name) {
  if (name !== "talk" || !db) return null;
  return {
    threads: await db.q(`select id::int as id, board, title, author, test, locked_at is not null as locked, pinned_at is not null as pinned, hidden_at is not null as hidden,
      removed_at is not null as removed, model, challenge::int as challenge, seed from public.talk_threads order by id`),
    posts: await db.q(`select id::int as id, thread::int as thread, author, first, hidden_at is not null as hidden,
      removed_at is not null as removed, answers::int as answers, left(body, 80) as said from public.talk_posts order by id`),
    mentions: await db.q("select post::int as post, account from public.talk_mentions order by 1, 2"),
    reports: await db.q("select post::int as post, reporter, reason, resolved_at is not null as resolved from public.talk_reports order by 1"),
    follows: await db.q("select account, thread::int as thread from public.talk_follows order by 2, 1"),
    bans: await db.q("select account, until from public.talk_bans order by 1"),
    blocks: await db.q("select blocker, blocked from public.blocks order by 1, 2"),
    audit: await db.q("select * from public.admin_audit order by 1 desc limit 20").catch(() => []),
  };
}
