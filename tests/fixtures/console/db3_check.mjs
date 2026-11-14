// supabase/console3.sql itself, in pg.mjs's Postgres after the files it
// reads: what tests/test_console3.py asks of it. Supabase's own parts it
// reads (auth.sessions, storage.objects) and the site's tables it finds in
// (people, model_collections, reports) are stood in for, with the columns
// it reads.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/console/db3_check.mjs
//
// Prints one JSON object, each finding by name.
import { readFileSync } from "node:fs";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS3, STAND_INS } from "./needs3.mjs";

const db = await startPostgres({ also: NEEDS3 });
db.rpc = async (name, args = {}) => {
  const names = Object.keys(args);
  const sql = `select public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`;
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
  const rows = await db.q(sql, values);
  return rows[0].answer;
};
const refused = (promise) => promise.then(() => "kept", (t) => String(t.message).slice(0, 160));
const out = {};
try {
  await db.q(STAND_INS);
  const sql = readFileSync(new URL("../../../supabase/console3.sql", import.meta.url), "utf8");
  await db.q(sql);
  // Applied again, nothing changes and nothing fails.
  await db.q(sql);
  out.again = "ok";

  // The notice: one showing a scope, set in place of the one before, cleared.
  const live = "live";
  const preview = "brickworks-abc-xaxis-projects.vercel.app";
  out.none = await db.rpc("site_notice", { p_scope: live });
  out.first = await db.rpc("site_notice_set", { p_scope: live, p_words: { en: "Down for upkeep at 02:00 UTC." }, p_tone: "warn",
    p_by: "owner@example.com" });
  out.second = await db.rpc("site_notice_set", { p_scope: live, p_words: { en: "Back up.", de: "Wieder da." }, p_tone: "info",
    p_by: "owner@example.com" });
  out.showing = await db.rpc("site_notice", { p_scope: live });
  out.preview_none = await db.rpc("site_notice", { p_scope: preview });
  out.bad_words = {
    no_english: await refused(db.rpc("site_notice_set", { p_scope: preview, p_words: { de: "Nur Deutsch" }, p_tone: "info", p_by: "o" })),
    empty: await refused(db.rpc("site_notice_set", { p_scope: preview, p_words: {}, p_tone: "info", p_by: "o" })),
    other_language: await refused(db.rpc("site_notice_set", { p_scope: preview, p_words: { en: "Hi", it: "Ciao" }, p_tone: "info", p_by: "o" })),
    too_long: await refused(db.rpc("site_notice_set", { p_scope: preview, p_words: { en: "x".repeat(301) }, p_tone: "info", p_by: "o" })),
    not_text: await refused(db.rpc("site_notice_set", { p_scope: preview, p_words: { en: "Hi", fr: 3 }, p_tone: "info", p_by: "o" })),
    tone: await refused(db.rpc("site_notice_set", { p_scope: preview, p_words: { en: "Hi" }, p_tone: "loud", p_by: "o" })),
  };
  out.preview_after_bad = await db.rpc("site_notice", { p_scope: preview });
  out.cleared = await db.rpc("site_notice_clear", { p_scope: live, p_by: "owner@example.com" });
  out.cleared_again = await db.rpc("site_notice_clear", { p_scope: live, p_by: "owner@example.com" });
  out.after_clear = await db.rpc("site_notice", { p_scope: live });
  out.history = await db.rpc("site_notices_list", { p_scope: live, p_limit: 10 });

  // The variables as Vercel lists them: kept, and a name gone let go.
  out.env_kept = await db.rpc("site_env_note", { p_vars: [{ name: "MASTER_EMAIL", environments: ["production", "preview"] },
    { name: "OLD_ONE", environments: ["production"] }, { name: "CRON_SECRET", environments: ["preview", "production", "preview"] }] });
  out.env_again = await db.rpc("site_env_note", { p_vars: [{ name: "MASTER_EMAIL", environments: ["production", "preview"] },
    { name: "CRON_SECRET", environments: ["production"] }] });
  out.env = await db.rpc("site_env_list", {});
  out.env_bad = await refused(db.rpc("site_env_note", { p_vars: [{ name: "lower_case", environments: [] }] }));
  out.env_bad_where = await refused(db.rpc("site_env_note", { p_vars: [{ name: "X", environments: ["staging"] }] }));

  // Usage: the database, its biggest tables, storage by bucket.
  await db.q(`insert into storage.objects (bucket_id, name, metadata) values ('parts', 'sets/card/6080-1.webp', '{"size": 1000}'),
    ('parts', 'sets/card/6081-1.webp', '{"size": 2000}'), ('shared-models', 'AbCdEfGhIj.mpd', '{"size": 500}'),
    ('shared-models', 'odd', '{"size": "lots"}')`);
  out.usage = await db.rpc("admin_usage", {});

  // One account: its sessions and Claudes ended; its rows found by the catalogue.
  const ada = await db.user("ada@example.com");
  const bob = await db.user("bob@example.com");
  await db.q("insert into auth.sessions (id, user_id) values (gen_random_uuid(), $1), (gen_random_uuid(), $1), (gen_random_uuid(), $2)", [ada, bob]);
  await db.q("insert into auth.refresh_tokens (token, session_id) select 'rt-' || id, id from auth.sessions");
  await db.q("insert into public.oauth_clients (client_id, client_name, redirect_uris) values ('https://claude.ai/oauth/x', 'Claude', "
    + "array['https://claude.ai/cb'])");
  await db.q(`insert into public.oauth_grants (owner, client_id, client_name, redirect_uri, resource, scope, channel)
    values ($1, 'https://claude.ai/oauth/x', 'Claude', 'https://claude.ai/cb', 'https://brickworks.diy/api/mcp', 'mcp', repeat('c', 64))`, [ada]);
  out.signed_out = await db.rpc("admin_sign_out", { p_account: ada });
  out.left = (await db.q(`select (select count(*)::int from auth.sessions where user_id = $1) as ada_sessions,
    (select count(*)::int from auth.sessions where user_id = $2) as bob_sessions,
    (select count(*)::int from auth.refresh_tokens) as refresh_tokens,
    (select count(*)::int from public.oauth_grants where owner = $1) as ada_claudes`, [ada, bob]))[0];
  out.signed_out_again = await db.rpc("admin_sign_out", { p_account: ada });

  await db.q("insert into public.shared_models (owner, id) values ($1, 'AdaModel01'), ($2, 'BobModel01')", [ada, bob]);
  await db.q("insert into public.people (account, handle, name) values ($1, 'ada-builds', 'Ada'), ($2, 'bob', 'Bob')", [ada, bob]);
  await db.q("insert into public.model_collections (id, owner, name, public) values ('AdaList001', $1, 'Castles I love', true)", [ada]);
  await db.q("insert into public.model_collection_items (collection, model) values ('AdaList001', 'BobModel01')");
  await db.q(`insert into public.oauth_grants (owner, client_id, client_name, redirect_uri, resource, scope, channel)
    values ($1, 'https://claude.ai/oauth/x', 'Claude', 'https://claude.ai/cb', 'https://brickworks.diy/api/mcp', 'mcp', repeat('d', 64))`, [ada]);
  await db.q("insert into public.reports (model, reason, note, contact, reporter) values ('BobModel01', 'spam', 'It is an advert', null, $1)", [ada]);
  // A thousand and two connector tabs, each with its 20 KB tool list: the
  // first 1000 given, the count said, the lists named by their size only.
  await db.q(`insert into public.relay_tabs (channel, owner, hello)
    select encode(sha256(convert_to('tab' || n, 'utf8')), 'hex'), $1, jsonb_build_object('tools', repeat('x', 20000))
      from generate_series(1, 1002) n`, [ada]);
  out.export = await db.rpc("admin_export", { p_account: ada });

  // Find anything.
  out.find_handle = await db.rpc("admin_find", { p_query: "ada", p_tests: false });
  out.find_list = await db.rpc("admin_find", { p_query: "castles", p_tests: false });
  out.find_report = await db.rpc("admin_find", { p_query: "advert", p_tests: false });
  out.find_wild = await db.rpc("admin_find", { p_query: "%", p_tests: false });
  out.find_short = await db.rpc("admin_find", { p_query: "a", p_tests: false });

  // Nothing reachable but by the server.
  out.grants = await db.q(`select c.relname, c.relrowsecurity as rls,
      has_table_privilege('anon', c.oid, 'select') as anon, has_table_privilege('authenticated', c.oid, 'select') as signed_in,
      has_table_privilege('service_role', c.oid, 'select') as server
      from pg_class c where c.relname in ('site_notices', 'site_env') and c.relnamespace = 'public'::regnamespace order by 1`);
  out.functions = await db.q(`select p.proname, p.prosecdef as definer, has_function_privilege('anon', p.oid, 'execute') as anon,
      has_function_privilege('authenticated', p.oid, 'execute') as signed_in,
      has_function_privilege('service_role', p.oid, 'execute') as server
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname in ('site_notice', 'site_notice_set', 'site_notice_clear', 'site_notices_list',
        'site_env_note', 'site_env_list', 'admin_usage', 'admin_sign_out', 'admin_export', 'admin_find') order by 1`);
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 2000);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
