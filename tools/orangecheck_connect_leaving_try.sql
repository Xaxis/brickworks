-- What supabase/orangecheck_connect_leaving.sql does, tried inside the
-- rolled-back transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/orangecheck_connect_leaving.sql --dry \
--     --try=tools/orangecheck_connect_leaving_try.sql --table=oc_connected
--
-- Made-up accounts, made and gone with the transaction: Ann, Ben, Cy, Di,
-- Eve, Gus and Kim. now() is the transaction's one time throughout, so a
-- mark 16 minutes old is written as one by hand. Each statement is on one
-- line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated, service_role;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-ann@example.invalid'), ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-ben@example.invalid'), ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-cy@example.invalid'), ('00000000-0000-4000-8000-0000000000f4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-di@example.invalid');
select public.oc_connect_asked('00000000-0000-4000-8000-0000000000f1'), public.oc_connect_asked('00000000-0000-4000-8000-0000000000f2'), public.oc_connect_asked('00000000-0000-4000-8000-0000000000f3');
-- Ann: orangecheck answers, nothing is leaving: kept, true, and the id is there. (A function's own writes are seen by the next statement, not its own.)
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('a', 32)) as ann_kept;
select public.oc_connected_of('00000000-0000-4000-8000-0000000000f1')->>'did' = 'did:oc:' || repeat('a', 32) as ann_did_there;
-- Ann deleted after: leaving answers as oc_connected_of does, with the id to delete at orangecheck.
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1') - 'asked_at' - 'made_at' = public.oc_connected_of('00000000-0000-4000-8000-0000000000f1') - 'asked_at' - 'made_at' as leaving_answers_as_connected_of, public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1')->>'did' = 'did:oc:' || repeat('a', 32) as leaving_has_ann_did;
-- Ben: the deletion's mark first, orangecheck's answer after: not kept, false, and no id written.
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f2') ->> 'did' is null as ben_leaving_no_did_yet;
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f2', 'did:oc:' || repeat('b', 32)) = false as ben_not_kept, public.oc_connected_of('00000000-0000-4000-8000-0000000000f2')->>'did' is null as ben_no_did;
-- Cy: the account deleted while orangecheck was asked (the row goes with it): not kept, false.
delete from auth.users where id = '00000000-0000-4000-8000-0000000000f3';
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f3', 'did:oc:' || repeat('c', 32)) = false as cy_gone_not_kept, public.oc_connected_of('00000000-0000-4000-8000-0000000000f3') is null as cy_row_gone;
-- Ben again: his deletion held (orangecheck down), and the mark stands: a new tick within 15 minutes is not kept; once the mark is 16 minutes old it has lapsed, and a tick is kept, his row his.
select public.oc_connect_asked('00000000-0000-4000-8000-0000000000f2');
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f2', 'did:oc:' || repeat('b', 32)) = false as ben_within_15_minutes_not_kept;
update public.oc_connected set leaving_at = now() - interval '16 minutes' where account = '00000000-0000-4000-8000-0000000000f2';
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f2', 'did:oc:' || repeat('b', 32)) as ben_lapsed_kept;
select public.oc_connected_of('00000000-0000-4000-8000-0000000000f2')->>'did' = 'did:oc:' || repeat('b', 32) as ben_row_kept;
-- Di: never asked: her mark reads null (twice), a row of the mark alone is written, which oc_connected_of reads as never asked, and nothing is kept for her.
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f4') is null as di_never_asked;
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f4') is null as di_marked_again_still_never_asked, (select count(*) from public.oc_connected where account = '00000000-0000-4000-8000-0000000000f4') = 1 as di_mark_row_written;
select public.oc_connected_of('00000000-0000-4000-8000-0000000000f4') is null as di_reads_never_asked, public.oc_connect_kept('00000000-0000-4000-8000-0000000000f4', 'did:oc:' || repeat('d', 32)) = false as di_not_kept;
-- Eve, site-attest's race (bw237/l2_race.mjs): (a) the deletion marks her before any row; (b) a first tick asks, writing the row; (c) orangecheck answers: not kept; (d) the account deleted, the row with it.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000f5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-eve@example.invalid');
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f5') is null as eve_a_mark_reads_never_asked;
select public.oc_connect_asked('00000000-0000-4000-8000-0000000000f5');
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f5', 'did:oc:' || repeat('f', 32)) = false as eve_c_answer_not_kept;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000f5';
select public.oc_connected_of('00000000-0000-4000-8000-0000000000f5') is null as eve_d_row_gone;
-- site-attest's R1, Gus (never ticked): two deletions at once, A and B, each marks; B fails and does nothing more; a first tick asks; orangecheck answers: not kept, so provision deletes it; A goes through, the row with the account.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000f6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-gus@example.invalid'), ('00000000-0000-4000-8000-0000000000f7', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-kim@example.invalid');
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f6') is null as gus_a_marks;
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f6') is null as gus_b_marks;
select public.oc_connect_asked('00000000-0000-4000-8000-0000000000f6');
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f6', 'did:oc:' || repeat('6', 32)) = false as gus_tick_not_kept;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000f6';
select (select count(*) from public.oc_connected where account = '00000000-0000-4000-8000-0000000000f6') = 0 as gus_row_gone;
-- R1b, Kim (ticked before): A marks and has her old one deleted, B marks, B fails, a tick asks, orangecheck answers a new one: not kept.
select public.oc_connect_asked('00000000-0000-4000-8000-0000000000f7');
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f7', 'did:oc:' || repeat('7', 32)) as kim_first_kept;
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f7') ->> 'did' = 'did:oc:' || repeat('7', 32) as kim_a_marks_and_finds_her_old_one;
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f7') ->> 'did' is not null as kim_b_marks;
select public.oc_connect_asked('00000000-0000-4000-8000-0000000000f7');
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f7', 'did:oc:' || repeat('8', 32)) = false as kim_new_tick_not_kept;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000f7';
-- The old calls are as they were: oc_connect_made writes, oc_connected_of reads.
select public.oc_connect_made('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('e', 32));
select public.oc_connected_of('00000000-0000-4000-8000-0000000000f1')->>'did' = 'did:oc:' || repeat('e', 32) as old_made_still_writes;
-- Only the service role may ask.
set local role anon;
select pg_temp.tries($q$select public.oc_connected_of('00000000-0000-4000-8000-0000000000f1')$q$) as anon_connected_of, pg_temp.tries($q$select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1')$q$) as anon_leaving, pg_temp.tries($q$select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('a', 32))$q$) as anon_kept;
reset role;
set local role authenticated;
select pg_temp.tries($q$select public.oc_connected_of('00000000-0000-4000-8000-0000000000f1')$q$) as user_connected_of, pg_temp.tries($q$select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1')$q$) as user_leaving, pg_temp.tries($q$select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('a', 32))$q$) as user_kept;
reset role;
set local role service_role;
select pg_temp.tries($q$select public.oc_connected_of('00000000-0000-4000-8000-0000000000f1')$q$) as service_connected_of, pg_temp.tries($q$select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1')$q$) as service_leaving, pg_temp.tries($q$select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('a', 32))$q$) as service_kept, pg_temp.tries('select * from public.oc_connected') as service_reads_table;
reset role;
