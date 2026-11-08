-- What supabase/collection_ops.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/collection_ops.sql --dry --try=tools/collection_ops_try.sql
--
-- A made-up account at a Resend test address, made and gone with the
-- transaction. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-00000000c011', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'collops-try@resend.dev');
-- A row made as the live api makes one (an upsert of sets, parts and updated_at): a rev of its own, no ids remembered.
insert into public.collections (owner, sets, parts, updated_at) values ('00000000-0000-4000-8000-00000000c011', '[{"set": "6020-1", "qty": 1, "spares": false}]', '[{"part": "3001", "colour": 4, "qty": 5}]', now()) on conflict (owner) do update set sets = excluded.sets, parts = excluded.parts, updated_at = excluded.updated_at returning rev > 0 as "made: a rev past 0", recent as recent;
-- The new api's write, held to the rev it read: it lands, and the rev moves on.
update public.collections set parts = '[{"part": "3001", "colour": 4, "qty": 5, "src": "hand"}]', recent = '["try-request-1"]' where owner = '00000000-0000-4000-8000-00000000c011' and rev = (select rev from public.collections where owner = '00000000-0000-4000-8000-00000000c011') returning rev, recent;
-- The live api's upsert after it: the rev moves on again, the ids remembered stay.
insert into public.collections (owner, sets, parts, updated_at) values ('00000000-0000-4000-8000-00000000c011', '[]', '[{"part": "3001", "colour": 4, "qty": 6}]', now()) on conflict (owner) do update set sets = excluded.sets, parts = excluded.parts, updated_at = excluded.updated_at returning rev, recent;
-- A write held to a rev an earlier read had: nothing changed (0 rows).
update public.collections set parts = '[]' where owner = '00000000-0000-4000-8000-00000000c011' and rev = 1 returning rev;
select count(*) as "rows a stale rev changed" from public.collections where owner = '00000000-0000-4000-8000-00000000c011' and parts = '[]';
-- Taken out and made again: a rev no read before ever had.
delete from public.collections where owner = '00000000-0000-4000-8000-00000000c011';
insert into public.collections (owner) values ('00000000-0000-4000-8000-00000000c011') returning rev > (select last_value - 1 from public.collections_rev) as "a fresh rev", recent;
-- Rows kept before: rev 0 until their next write; none is null.
select count(*) filter (where rev is null) as "null revs", count(*) filter (where recent is null) as "null recents" from public.collections;
-- The trigger's function and the sequence are nobody's to call.
select has_function_privilege('anon', 'public.collections_next_rev()', 'execute') as anon_fn, has_function_privilege('authenticated', 'public.collections_next_rev()', 'execute') as authenticated_fn, has_sequence_privilege('anon', 'public.collections_rev', 'usage') as anon_seq, has_sequence_privilege('authenticated', 'public.collections_rev', 'usage') as authenticated_seq
