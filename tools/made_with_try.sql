-- What supabase/made_with.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/made_with.sql --dry --try=tools/made_with_try.sql --table=shared_models
--
-- One made-up account, made and gone with the transaction, 13 or over at a
-- Resend test address, so every model here is a test model, which only a
-- list asked with tests shows. Each statement is on one line: the dry run
-- splits at a semicolon that ends a line.
--
--   Hand Tagged  tagged ai-designed, and its app said hand: hand-built
--   Claude Plain no tags, and its app said assistant: with the assistant
--   Brickified   no tags, and its app said brickify: with the assistant
--   Old Tagged   tagged ai-designed, its app said nothing: with the assistant, by its tag
--   Old Plain    no tags, its app said nothing: hand-built, as before
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'made-with-try@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000c1', true)->>'over_13' as over_13;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, tags, made_with) values ('MadeTry001', '00000000-0000-4000-8000-0000000000c1', 'Made Try Hand Tagged', 'Try', 10, 100, true, now(), true, '{ai-designed}', 'hand'), ('MadeTry002', '00000000-0000-4000-8000-0000000000c1', 'Made Try Claude Plain', 'Try', 10, 100, true, now(), true, '{}', 'assistant'), ('MadeTry003', '00000000-0000-4000-8000-0000000000c1', 'Made Try Brickified', 'Try', 10, 100, true, now(), true, '{}', 'brickify'), ('MadeTry004', '00000000-0000-4000-8000-0000000000c1', 'Made Try Old Tagged', 'Try', 10, 100, true, now(), true, '{ai-designed}', null), ('MadeTry005', '00000000-0000-4000-8000-0000000000c1', 'Made Try Old Plain', 'Try', 10, 100, true, now(), true, '{}', null);
-- The card says what the app said, and nothing where it said nothing.
select c->>'name' as name, coalesce(c->>'made_with', '(none)') as made_with, c->'tags' as tags from (select public.directory_card(m) as c from public.shared_models m where m.id like 'MadeTry%' order by m.id) x;
-- The filter: the app first, the tags where it said nothing.
select string_agg(c->>'name', ', ' order by c->>'name') as "with the assistant" from public.gallery_models('{"tests": true, "made": "assistant", "words": "made:* & try:*"}'::jsonb) c;
select string_agg(c->>'name', ', ' order by c->>'name') as "by hand" from public.gallery_models('{"tests": true, "made": "hand", "words": "made:* & try:*"}'::jsonb) c;
-- Anything else is refused by the column itself.
create function pg_temp.refused(v text) returns text language plpgsql as $$ begin update public.shared_models set made_with = v where id = 'MadeTry005'; return 'kept: ' || v; exception when check_violation then return 'refused: ' || v; end $$;
select pg_temp.refused('robots') as robots, pg_temp.refused('assistant') as assistant;
-- Nobody but the server: the column granted to no client, the functions the service role's alone.
select has_column_privilege('anon', 'public.shared_models', 'made_with', 'select') as anon_reads, has_column_privilege('authenticated', 'public.shared_models', 'made_with', 'select') as authenticated_reads, has_column_privilege('authenticated', 'public.shared_models', 'made_with', 'update') as authenticated_writes, has_column_privilege('service_role', 'public.shared_models', 'made_with', 'update') as service_role_writes;
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('gallery_models', 'directory_card') order by p.proname;
select coalesce(string_agg(line, '; '), 'nothing') as "what a client can reach (client_exposure)" from jsonb_array_elements_text(public.client_exposure()->'bad') line;
-- With no made filter, the list is as it was: gallery_models against directory_models on the real tables.
select q::text as asked, (select coalesce(jsonb_agg(c - 'made_with'), '[]') from public.gallery_models(q) c) = (select coalesce(jsonb_agg(c - 'made_with'), '[]') from public.directory_models(q) c) as "the same as directory_models" from (values ('{}'::jsonb), ('{"tests": true}'), ('{"sort": "top"}'), ('{"sort": "builds"}'), ('{"technic": true}'), ('{"words": "castle:*"}')) v(q)
