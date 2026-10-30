// supabase/feedback.sql, with beta.sql under it, held in a Postgres of this
// machine's own (tests/fixtures/beta/pg.mjs), for proving the API, the pages
// and the app before the file is applied to the project.
//
//   set -a; . ./.env; set +a
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js PG_BIN=<postgres's bin> \
//   BRICKWORKS_BETA=open MASTER_EMAIL=delivered+bw-feedback-owner@resend.dev \
//     node tools/web/relay_server.mjs 9060 --static=build/web --hold=feedback
//
// Unlike the other stand-ins, nothing is written again in JavaScript: the
// files themselves answer, as PostgREST would call them. Every beta_* and
// feedback_* function the server asks goes to that Postgres, so the beta's
// applications and decisions are held here too, apart from the project's,
// and the project's own spots are never touched. An account a function
// names is copied from the project's auth.users (its id, address and when
// it was made) the first time, so the real sign-ins work over it. The
// private bucket 'feedback' is held in memory.
//
// MASTER_EMAIL set to a test address on the server's command line makes
// that account the owner of this server's /admin, so a check never signs in
// as the site's real owner (tools/web/feedback_flow.mjs --owner).
//
// What is held is at /__held/feedback, on this machine only.
import { startPostgres } from "../../tests/fixtures/beta/pg.mjs";

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const RPC = new RegExp(`^${SUPABASE.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/rest/v1/rpc/((?:beta|feedback)_[a-z_]+)$`);
const BUCKET = `${SUPABASE}/storage/v1/object/feedback`;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

let db = null;
let inner = null;
const copied = new Set();
const files = new Map();

/// The account [id] in the held auth.users, as the project has it.
async function copyAccount(id) {
  if (!UUID.test(String(id || "")) || copied.has(id)) return;
  const reply = await inner(`${SUPABASE}/auth/v1/admin/users/${id}`, {
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  if (!reply.ok) return;
  const user = await reply.json();
  await db.q(`insert into auth.users (id, email, created_at, email_confirmed_at, last_sign_in_at) values ($1, $2, $3, $4, $5)
    on conflict (id) do nothing`, [user.id, user.email, user.created_at, user.email_confirmed_at, user.last_sign_in_at]);
  copied.add(id);
}

const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

export async function hold() {
  if (inner) return;
  db = await startPostgres({ also: ["supabase/feedback.sql"] });
  inner = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const where = String(url);
    const rpc = RPC.exec(where.split("?")[0]);
    if (rpc) {
      let body = {};
      try {
        body = init.body ? JSON.parse(init.body) : {};
      } catch {
        body = {};
      }
      if (body.p_account) await copyAccount(body.p_account);
      try {
        return json(200, await db.rpc(rpc[1], body));
      } catch (trouble) {
        return json(400, { message: String(trouble.message) });
      }
    }
    if (where === BUCKET || where.startsWith(`${BUCKET}/`)) {
      const name = decodeURIComponent(where.slice(BUCKET.length + 1));
      const method = String(init.method || "GET").toUpperCase();
      if (method === "POST") {
        files.set(name, { type: new Headers(init.headers).get("content-type"), bytes: Buffer.from(init.body) });
        return json(200, { Key: `feedback/${name}` });
      }
      if (method === "DELETE") {
        for (const one of JSON.parse(String(init.body || "{}")).prefixes || []) files.delete(one);
        return json(200, []);
      }
      const kept = files.get(name);
      return kept ? new Response(kept.bytes, { status: 200, headers: { "content-type": kept.type } }) : json(404, {});
    }
    // The account's own deletion deletes its reports by cascade, here too.
    const gone = /\/auth\/v1\/admin\/users\/([0-9a-f-]{36})$/.exec(where);
    if (gone && String(init.method || "").toUpperCase() === "DELETE") {
      await db.q("delete from auth.users where id = $1", [gone[1]]);
      copied.delete(gone[1]);
    }
    return inner(url, init);
  };
  const stop = async () => {
    await db.stop().catch(() => {});
    process.exit(0);
  };
  process.once("SIGINT", stop);
  process.once("SIGTERM", stop);
  console.log("feedback.sql and beta.sql held here, in a Postgres of this machine's own; the 'feedback' bucket in memory");
}

/// What is held now, for a check to read (/__held/feedback).
export async function rowsOf(name) {
  if (name !== "feedback" || !db) return null;
  return {
    // Ids as numbers, as the API gives them (node's pg reads a bigint as text).
    reports: await db.q("select id::int as id, account, email, kind, words, source, page, beta, test, status, note, picture, "
      + "model, char_length(log) as log from public.feedback order by id"),
    replies: await db.q("select feedback::int as feedback, words, mail from public.feedback_replies order by id"),
    files: [...files.entries()].map(([name, kept]) => ({ name, type: kept.type, size: kept.bytes.length })),
  };
}
