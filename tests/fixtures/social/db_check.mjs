// supabase/social.sql in a Postgres of its own (tests/fixtures/beta/pg.mjs),
// applied twice: what the database itself keeps of the social desk. No role
// a page or a visitor has reaches any table; the server's does; a send past
// a draft is refused without the owner's press; a token goes with its
// account. What tests/test_social.py asks.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/social/db_check.mjs
import { startPostgres } from "../beta/pg.mjs";

const out = {};
const db = await startPostgres({ also: ["supabase/social.sql", "supabase/social.sql"] });
/// [sql] as [role]: "ok", or the database's words.
async function as(role, sql) {
  const client = await db.connect();
  try {
    await client.query("begin");
    await client.query(`set local role ${role}`);
    await client.query(sql);
    await client.query("rollback");
    return "ok";
  } catch (trouble) {
    await client.query("rollback").catch(() => {});
    return String(trouble?.message || trouble).slice(0, 160);
  } finally {
    client.release?.();
    await client.end?.().catch(() => {});
  }
}
const refused = async (sql) => {
  try {
    await db.q(sql);
    return "kept";
  } catch (trouble) {
    return String(trouble?.constraint || trouble?.message || trouble);
  }
};
try {
  const TABLES = ["social_accounts", "social_tokens", "social_items", "social_sends", "social_results", "social_visits", "social_rules"];
  out.tables = (await db.q("select relname, relrowsecurity from pg_class where relname like 'social_%' and relkind = 'r' order by relname"))
    .map((one) => `${one.relname}:${one.relrowsecurity}`);
  out.policies = Number(await db.one("select count(*) from pg_policies where tablename like 'social_%'"));
  out.reach = {};
  for (const table of TABLES) {
    out.reach[table] = [await as("anon", `select * from public.${table}`), await as("authenticated", `select * from public.${table}`),
      await as("service_role", `select * from public.${table}`)].map((said) => (said === "ok" ? "ok" : /permission denied/.test(said) ? "denied" : said));
  }
  out.fk_to_users = Number(await db.one(`select count(*) from pg_constraint c join pg_class r on r.oid = c.conrelid
    where r.relname like 'social_%' and c.contype = 'f' and c.confrelid = 'auth.users'::regclass`));
  const send = (status, extra = "") => `insert into public.social_sends (id, provider, kind, community, title, body, status${extra ? `, ${extra.split("=")[0]}` : ""})
    values ('${status.padEnd(10, "x").slice(0, 10)}', 'reddit', 'post', 'lego', 'A title', 'Words', '${status}'${extra ? `, ${extra.split("=")[1]}` : ""})`;
  out.draft = await refused(send("draft"));
  out.sent_unpressed = await refused(`insert into public.social_sends (id, provider, kind, community, title, status, sent_at, url)
    values ('sentnopres', 'reddit', 'post', 'lego', 't', 'sent', now(), 'https://www.reddit.com/r/lego/')`);
  out.scheduled_unpressed = await refused(`insert into public.social_sends (id, provider, kind, community, title, status, send_at)
    values ('schednopre', 'reddit', 'post', 'lego', 't', 'scheduled', now())`);
  out.scheduled_pressed = await refused(`insert into public.social_sends (id, provider, kind, community, title, status, send_at,
    pressed_at, pressed_by, pressed_hash, route) values ('schedpress', 'reddit', 'post', 'lego', 't', 'scheduled', now() + interval '1 hour',
    now(), 'owner@example.com', '${"a".repeat(64)}', 'api')`);
  out.draft_to_sent = await refused("update public.social_sends set status = 'sent', sent_at = now(), url = 'https://x.y/' where id = 'draftxxxxx'");
  out.reply_without_parent = await refused(`insert into public.social_sends (id, provider, kind, body) values ('replynopar', 'reddit', 'reply', 'x')`);
  out.post_with_parent = await refused(`insert into public.social_sends (id, provider, kind, parent, body) values ('postparent', 'reddit', 'post', 't1_a', 'x')`);
  out.bad_community = await refused(`insert into public.social_sends (id, provider, kind, community) values ('badcommuni', 'reddit', 'post', 'r/lego; drop')`);
  out.visit_bad_nonce = await refused("insert into public.social_visits (send, nonce) values ('draftxxxxx', 'NOT A NONCE')");
  out.visit = await refused("insert into public.social_visits (send, nonce, path, source) values ('draftxxxxx', 'abcdefgh1234', '/gallery', 'reddit')");
  out.visit_unknown_send = await refused("insert into public.social_visits (send, nonce) values ('nosuchsend', 'abcdefgh1234')");
  out.token_without_account = await refused("insert into public.social_tokens (provider, test, access_token) values ('reddit', false, 'a')");
  await db.q("insert into public.social_accounts (provider, handle, connected_by) values ('reddit', 'brickworks', 'owner@example.com')");
  await db.q("insert into public.social_tokens (provider, access_token, refresh_token) values ('reddit', 'a', 'r')");
  await db.q("delete from public.social_accounts where provider = 'reddit'");
  out.tokens_after_disconnect = Number(await db.one("select count(*) from public.social_tokens"));
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 1500);
} finally {
  await db.stop();
}
process.stdout.write(`${JSON.stringify(out)}\n`);
