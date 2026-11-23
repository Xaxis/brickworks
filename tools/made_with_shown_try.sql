-- What supabase/made_with_shown.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/made_with_shown.sql --dry --try=tools/made_with_shown_try.sql --table=shared_models
--
-- One made-up account, made and gone with the transaction, 13 or over at a
-- Resend test address, so every model here is a test model. Each statement
-- is on one line: the dry run splits at a semicolon that ends a line.
--
--   Claude Quiet  its app said assistant, its owner said nothing: not shown
--   Claude Said   its app said assistant, its owner chose to show it
--   Old Tagged    tagged ai-designed, its app said nothing, not shown
--   Hand Built    its app said hand
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000c2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'made-shown-try@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000c2', true)->>'over_13' as over_13;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, tags, made_with) values ('ShownTry01', '00000000-0000-4000-8000-0000000000c2', 'Shown Try Claude Quiet', 'Try', 10, 100, true, now(), true, '{}', 'assistant'), ('ShownTry02', '00000000-0000-4000-8000-0000000000c2', 'Shown Try Claude Said', 'Try', 10, 100, true, now(), true, '{}', 'assistant'), ('ShownTry03', '00000000-0000-4000-8000-0000000000c2', 'Shown Try Old Tagged', 'Try', 10, 100, true, now(), true, '{ai-designed}', null), ('ShownTry04', '00000000-0000-4000-8000-0000000000c2', 'Shown Try Hand Built', 'Try', 10, 100, true, now(), true, '{}', 'hand');
update public.shared_models set made_with_shown = true where id = 'ShownTry02';
-- Every model before this is not shown: the column's default.
select count(*) filter (where made_with_shown) as shown, count(*) as models from public.shared_models where id not like 'ShownTry%';
-- The card carries whether it is shown.
select c->>'name' as name, coalesce(c->>'made_with', '(none)') as made_with, c->>'made_with_shown' as shown from (select public.directory_card(m) as c from public.shared_models m where m.id like 'ShownTry%' order by m.id) x;
-- The filter: With the assistant only the one shown; Hand-built every other.
select string_agg(c->>'name', ', ' order by c->>'name') as "with the assistant" from public.gallery_models('{"tests": true, "made": "assistant", "words": "shown:* & try:*"}'::jsonb) c;
select string_agg(c->>'name', ', ' order by c->>'name') as "by hand" from public.gallery_models('{"tests": true, "made": "hand", "words": "shown:* & try:*"}'::jsonb) c;
-- Nobody but the server: the column granted to no client.
select has_column_privilege('anon', 'public.shared_models', 'made_with_shown', 'select') as anon_reads, has_column_privilege('authenticated', 'public.shared_models', 'made_with_shown', 'select') as authenticated_reads, has_column_privilege('authenticated', 'public.shared_models', 'made_with_shown', 'update') as authenticated_writes, has_column_privilege('service_role', 'public.shared_models', 'made_with_shown', 'update') as server_writes;
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('gallery_models', 'directory_card') order by p.proname;
select coalesce(string_agg(line, '; '), 'nothing') as "what a client can reach (client_exposure)" from jsonb_array_elements_text(public.client_exposure()->'bad') line;
-- With no made filter, the list is as it was: gallery_models against directory_models on the real tables.
select q::text as asked, (select coalesce(jsonb_agg(c - 'made_with' - 'made_with_shown'), '[]') from public.gallery_models(q) c) = (select coalesce(jsonb_agg(c - 'made_with' - 'made_with_shown'), '[]') from public.directory_models(q) c) as "the same as directory_models" from (values ('{}'::jsonb), ('{"tests": true}'), ('{"sort": "top"}'), ('{"words": "castle:*"}')) v(q);
