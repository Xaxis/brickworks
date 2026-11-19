-- What supabase/block.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/block.sql --dry \
--       --try=tools/block_try.sql --table=blocks
--
-- Made-up accounts, made and gone with the transaction: Ada (A) designs a
-- tower; Bob (B) follows her, she follows him back, he comments on it and
-- Cy (C) answers him; Ada blocks Bob. Each statement is on one line: the
-- dry run splits at a semicolon that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-00000000b1a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'block-ada@resend.dev'), ('00000000-0000-4000-8000-00000000b1b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'block-bob@resend.dev'), ('00000000-0000-4000-8000-00000000b1c3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'block-cy@resend.dev');
select public.answer_age('00000000-0000-4000-8000-00000000b1a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-00000000b1b2', true)->>'over_13' as bob, public.answer_age('00000000-0000-4000-8000-00000000b1c3', true)->>'over_13' as cy;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-00000000b1a1', 'block-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-00000000b1b2', 'block-try-bob', 'Bob Try'), ('00000000-0000-4000-8000-00000000b1c3', 'block-try-cy', 'Cy Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('BlockTry01', '00000000-0000-4000-8000-00000000b1a1', 'Try tower', 'Ada Try', 12, 100, true, now() - interval '3 days', true, now() - interval '3 days', true), ('BlockTry02', '00000000-0000-4000-8000-00000000b1b2', 'Try shed', 'Bob Try', 8, 100, true, now() - interval '2 days', true, now() - interval '2 days', true);
insert into public.share_versions (model, n, at, parts, bytes, steps) values ('BlockTry01', 1, now() - interval '3 days', 12, 100, 6), ('BlockTry02', 1, now() - interval '2 days', 8, 100, 4);
select public.follow_person('00000000-0000-4000-8000-00000000b1b2', 'block-try-ada', true)->>'you_follow' as "Bob follows Ada", public.follow_person('00000000-0000-4000-8000-00000000b1a1', 'block-try-bob', true)->>'you_follow' as "Ada follows Bob";
select public.add_comment('00000000-0000-4000-8000-00000000b1b2', 'BlockTry01', 1, null, 'Try: Bob on the tower')->'comment'->>'id' is not null as "Bob comments", public.add_comment('00000000-0000-4000-8000-00000000b1c3', 'BlockTry01', 1, null, 'Try: Cy on the tower')->'comment'->>'id' is not null as "Cy comments";
select public.add_reply('00000000-0000-4000-8000-00000000b1c3', (select id from public.model_comments where body = 'Try: Bob on the tower'), 'Try: Cy answers Bob')->'comment'->>'parent' is not null as "Cy answers Bob";
-- The refusals, in order: nobody signed in, nobody by that handle, yourself.
select public.block_person(null, 'block-try-bob', true) as "signed out", public.block_person('00000000-0000-4000-8000-00000000b1a1', 'block-try-nobody', true) as nobody, public.block_person('00000000-0000-4000-8000-00000000b1a1', 'block-try-ada', true) as yourself;
-- Ada blocks Bob, twice: the same answer, one row.
select public.block_person('00000000-0000-4000-8000-00000000b1a1', 'Block-Try-Bob', true) - 'at' as "Ada blocks Bob";
select public.block_person('00000000-0000-4000-8000-00000000b1a1', 'block-try-bob', true) - 'at' as "and again";
select (select count(*) from public.blocks where blocker = '00000000-0000-4000-8000-00000000b1a1') as rows;
-- The follows ended both ways; neither may follow again (Bob's refused by the trigger whatever writes).
select (select count(*) from public.follows where follower in ('00000000-0000-4000-8000-00000000b1a1', '00000000-0000-4000-8000-00000000b1b2') and followed in ('00000000-0000-4000-8000-00000000b1a1', '00000000-0000-4000-8000-00000000b1b2')) as "follows left";
create temp table said (what text, how text);
do $$ begin perform public.follow_person('00000000-0000-4000-8000-00000000b1b2', 'block-try-ada', true); insert into said values ('Bob follows Ada again', 'kept'); exception when others then insert into said values ('Bob follows Ada again', sqlerrm); end $$;
do $$ begin perform public.follow_person('00000000-0000-4000-8000-00000000b1a1', 'block-try-bob', true); insert into said values ('Ada follows Bob again', 'kept'); exception when others then insert into said values ('Ada follows Bob again', sqlerrm); end $$;
do $$ begin perform public.add_comment('00000000-0000-4000-8000-00000000b1b2', 'BlockTry01', 1, null, 'Try: Bob again'); insert into said values ('Bob comments on the tower', 'kept'); exception when others then insert into said values ('Bob comments on the tower', sqlerrm); end $$;
do $$ begin perform public.add_reply('00000000-0000-4000-8000-00000000b1b2', (select id from public.model_comments where body = 'Try: Cy on the tower'), 'Try: Bob answers Cy'); insert into said values ('Bob answers Cy on the tower', 'kept'); exception when others then insert into said values ('Bob answers Cy on the tower', sqlerrm); end $$;
do $$ begin perform public.add_comment('00000000-0000-4000-8000-00000000b1c3', 'BlockTry02', 1, null, 'Try: Cy on the shed'); insert into said values ('Cy comments on the shed', 'kept'); exception when others then insert into said values ('Cy comments on the shed', sqlerrm); end $$;
insert into public.model_collections (id, owner, name, public) values ('BlockTryL1', '00000000-0000-4000-8000-00000000b1a1', 'Try list', true);
do $$ begin perform public.list_follow('00000000-0000-4000-8000-00000000b1b2', 'BlockTryL1', true); insert into said values ('Bob follows Ada''s list', 'kept'); exception when others then insert into said values ('Bob follows Ada''s list', sqlerrm); end $$;
select * from said;
-- How each stands, as the API asks it.
select public.block_between('00000000-0000-4000-8000-00000000b1a1', '00000000-0000-4000-8000-00000000b1b2') as "Ada with Bob", public.block_between('00000000-0000-4000-8000-00000000b1b2', '00000000-0000-4000-8000-00000000b1a1') as "Bob with Ada", public.block_between('00000000-0000-4000-8000-00000000b1c3', '00000000-0000-4000-8000-00000000b1a1') as "Cy with Ada";
select public.block_on('00000000-0000-4000-8000-00000000b1b2', 'BlockTry01') as "Bob on the tower", public.block_on('00000000-0000-4000-8000-00000000b1a1', 'BlockTry02') as "Ada on the shed", public.block_on('00000000-0000-4000-8000-00000000b1c3', 'BlockTry01') as "Cy on the tower", public.block_on('00000000-0000-4000-8000-00000000b1b2', null, (select id from public.model_comments where body = 'Try: Cy answers Bob')) as "Bob under Cy's reply";
select public.block_named('00000000-0000-4000-8000-00000000b1b2', array['block-try-ada', 'block-try-cy']) as "Bob may not name", public.block_named('00000000-0000-4000-8000-00000000b1c3', array['block-try-ada', 'block-try-bob']) as "Cy may not name";
-- Hidden: Bob's comment from Cy, Ada and signed out; not from Bob. Cy's reply goes with it in the API.
select public.block_hidden('BlockTry01') = array[(select id from public.model_comments where body = 'Try: Bob on the tower')] as "signed out: Bob's", public.block_hidden('BlockTry01', '00000000-0000-4000-8000-00000000b1c3') = array[(select id from public.model_comments where body = 'Try: Bob on the tower')] as "Cy: Bob's", public.block_hidden('BlockTry01', '00000000-0000-4000-8000-00000000b1a1') = array[(select id from public.model_comments where body = 'Try: Bob on the tower')] as "Ada: Bob's", public.block_hidden('BlockTry01', '00000000-0000-4000-8000-00000000b1b2') as "Bob: none";
select public.block_models('00000000-0000-4000-8000-00000000b1a1', array['BlockTry01', 'BlockTry02']) as "Ada's gallery loses", public.block_models('00000000-0000-4000-8000-00000000b1b2', array['BlockTry01', 'BlockTry02']) as "Bob's loses", public.block_models(null, array['BlockTry02']) as "signed out loses";
select r->>'handle' as handle, r->>'name' as name from jsonb_array_elements(public.block_list('00000000-0000-4000-8000-00000000b1a1')) r;
select public.block_list('00000000-0000-4000-8000-00000000b1b2') as "Bob's list", public.block_count_against('00000000-0000-4000-8000-00000000b1b2') as "Bob blocked by", public.block_count_against('00000000-0000-4000-8000-00000000b1a1') as "Ada blocked by";
select public.block_counts('00000000-0000-4000-8000-00000000b1a1') as "Ada's counts off", public.block_counts('00000000-0000-4000-8000-00000000b1c3') as "Cy's";
-- Ada's notifications: Bob's comment is among the rows block_counts takes off (the API leaves it out of the list).
select r->>'kind' as kind, r->'by'->>'handle' as by from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-00000000b1a1')->'rows') r;
-- Unblocked: no row, the follows not back, and Bob may follow and comment again.
select public.block_person('00000000-0000-4000-8000-00000000b1a1', 'block-try-bob', false) - 'at' as "Ada unblocks Bob";
select public.block_hidden('BlockTry01') as "hidden now", public.block_list('00000000-0000-4000-8000-00000000b1a1') as "Ada's list now", (select count(*) from public.follows where follower = '00000000-0000-4000-8000-00000000b1b2' and followed = '00000000-0000-4000-8000-00000000b1a1') as "Bob's follow back";
select public.follow_person('00000000-0000-4000-8000-00000000b1b2', 'block-try-ada', true)->>'you_follow' as "Bob follows again", public.add_comment('00000000-0000-4000-8000-00000000b1b2', 'BlockTry01', 1, null, 'Try: Bob back')->'comment'->>'id' is not null as "Bob comments again"
