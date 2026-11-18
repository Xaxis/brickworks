// supabase/admin_claude.sql in a Postgres of its own (tests/fixtures/beta/pg.mjs),
// after social.sql, applied twice: what the database itself keeps of the
// console's Claude. No role a page or a visitor has reaches a table or a
// function; the server's does; the key is kept sealed or not at all; the
// month's holds never pass the cap, even asked at once; a hold cut off is
// counted whole after six minutes; a draft's mark goes with its draft. What
// tests/test_adminclaude.py asks.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/adminclaude/db_check.mjs
import { startPostgres } from "../beta/pg.mjs";

const out = {};
const db = await startPostgres({ also: ["supabase/social.sql", "supabase/admin_claude.sql", "supabase/admin_claude.sql"] });
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
    return /permission denied/.test(String(trouble?.message)) ? "denied" : String(trouble?.message || trouble).slice(0, 160);
  } finally {
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
const SEALED = `v1.${"A".repeat(60)}`;
try {
  const TABLES = ["admin_claude_settings", "admin_claude_holds", "admin_claude_drafts"];
  out.tables = (await db.q("select relname, relrowsecurity from pg_class where relname like 'admin_claude_%' and relkind = 'r' order by relname"))
    .map((one) => `${one.relname}:${one.relrowsecurity}`);
  out.policies = Number(await db.one("select count(*) from pg_policies where tablename like 'admin_claude_%'"));
  out.reach = {};
  for (const table of TABLES) {
    out.reach[table] = [await as("anon", `select * from public.${table}`), await as("authenticated", `select * from public.${table}`),
      await as("service_role", `select * from public.${table}`)];
  }
  out.functions = {};
  for (const call of ["admin_claude_month(true)", "admin_claude_hold(true, 'claude-opus-5-5', 0.01, 1)",
    "admin_claude_settle('00000000-0000-4000-8000-000000000000', 0)"]) {
    out.functions[call.split("(")[0]] = [await as("anon", `select public.${call}`), await as("authenticated", `select public.${call}`),
      await as("service_role", `select public.${call}`)];
  }
  // The key: sealed, with its last four, or neither.
  out.settings = {
    plain_key: await refused("insert into public.admin_claude_settings (test, key_sealed, key_last4) values (true, 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789abcdefghij', 'ghij')"),
    sealed_alone: await refused(`insert into public.admin_claude_settings (test, key_sealed) values (true, '${SEALED}')`),
    bad_model: await refused("insert into public.admin_claude_settings (test, model) values (true, 'gpt-5')"),
    bad_effort: await refused("insert into public.admin_claude_settings (test, effort) values (true, 'ultra')"),
    no_cap: await refused("insert into public.admin_claude_settings (test, cap_usd) values (true, 0)"),
    whole: await refused(`insert into public.admin_claude_settings (test, key_sealed, key_last4, cap_usd) values (true, '${SEALED}', 'AAAA', 1)`),
  };
  out.defaults = await db.q("select model, effort, cap_usd::text from public.admin_claude_settings where test");
  // Holds against a cap of $1.00.
  const hold = async (amount, test = true) => (await db.q("select public.admin_claude_hold($1, 'claude-opus-5-5', $2, 1) as got",
    [test, amount]))[0].got;
  const month = async (test = true) => (await db.q("select public.admin_claude_month($1) as got", [test]))[0].got;
  const a = await hold(0.6);
  const b = await hold(0.6);
  out.holds = { first: a.ok, second: b.ok, second_said: { spent: b.spent, held: b.held }, month: await month() };
  const settled = (await db.q("select public.admin_claude_settle($1, 0.25) as got", [a.id]))[0].got;
  const again = (await db.q("select public.admin_claude_settle($1, 0.9) as got", [a.id]))[0].got;
  out.settle = { after: settled, twice: again, cost: (await db.q("select cost_usd::text from public.admin_claude_holds where id = $1", [a.id]))[0].cost_usd };
  const c = await hold(0.6);
  out.after_settle = c.ok;
  // A hold its call never settled: counted whole after six minutes.
  await db.q("update public.admin_claude_holds set made_at = now() - interval '7 minutes' where id = $1", [c.id]);
  out.stale = await month();
  out.other_pool = await month(false);
  // Many asked at once: the cap still holds.
  await db.q("delete from public.admin_claude_holds where test = false");
  const many = await Promise.all(Array.from({ length: 12 }, async () => {
    const client = await db.connect();
    try {
      return (await client.query("select public.admin_claude_hold(false, 'claude-opus-5-5', 0.3, 1) as got")).rows[0].got.ok;
    } finally {
      await client.end?.().catch(() => {});
    }
  }));
  out.at_once = { kept: many.filter(Boolean).length, month: await month(false) };
  out.bad_amount = await refused("select public.admin_claude_hold(true, 'claude-opus-5-5', -1, 1)");
  // A draft's mark goes with its draft.
  await db.q("insert into public.social_sends (id, provider, kind, community, title, body, status) values ('claudedraf', 'reddit', 'post', 'lego', 't', 'b', 'draft')");
  out.mark = await refused("insert into public.admin_claude_drafts (send, test, model, ask) values ('claudedraf', true, 'claude-opus-5-5', 'suggest')");
  out.mark_bad_ask = await refused("insert into public.admin_claude_drafts (send, test, model, ask) values ('claudedraf', true, 'claude-opus-5-5', 'send')");
  out.mark_no_send = await refused("insert into public.admin_claude_drafts (send, test, model, ask) values ('nosuchsend', true, 'claude-opus-5-5', 'chat')");
  await db.q("delete from public.social_sends where id = 'claudedraf'");
  out.mark_after_drop = Number(await db.one("select count(*) from public.admin_claude_drafts"));
  out.fk_to_users = Number(await db.one(`select count(*) from pg_constraint c join pg_class r on r.oid = c.conrelid
    where r.relname like 'admin_claude_%' and c.contype = 'f' and c.confrelid = 'auth.users'::regclass`));
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 1500);
} finally {
  await db.stop();
}
process.stdout.write(`${JSON.stringify(out)}\n`);
