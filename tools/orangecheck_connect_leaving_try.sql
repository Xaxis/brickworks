-- What supabase/orangecheck_connect_leaving.sql does, tried inside the
-- rolled-back transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/orangecheck_connect_leaving.sql --dry \
--     --try=tools/orangecheck_connect_leaving_try.sql --table=oc_connected
--
-- Made-up accounts, made and gone with the transaction: Ann, Ben, Cy and
-- Di. now() is the transaction's one time throughout, so a later ask is
-- written as one by hand. Each statement is on one line: the dry run splits
-- at a semicolon that ends a line.
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
-- Ben again: a deletion that was held, then a new tick later than the mark: kept, true.
update public.oc_connected set leaving_at = now() - interval '1 hour', asked_at = now() - interval '2 hours' where account = '00000000-0000-4000-8000-0000000000f2';
select public.oc_connect_asked('00000000-0000-4000-8000-0000000000f2');
select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f2', 'did:oc:' || repeat('b', 32)) as ben_ticked_again_kept;
-- Di: never asked: leaving is null, kept is false.
select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f4') is null as di_never_asked, public.oc_connect_kept('00000000-0000-4000-8000-0000000000f4', 'did:oc:' || repeat('d', 32)) = false as di_not_kept;
-- The old calls are as they were: oc_connect_made writes, oc_connected_of reads.
select public.oc_connect_made('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('e', 32));
select public.oc_connected_of('00000000-0000-4000-8000-0000000000f1')->>'did' = 'did:oc:' || repeat('e', 32) as old_made_still_writes;
-- Only the service role may ask.
set local role anon;
select pg_temp.tries($q$select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1')$q$) as anon_leaving, pg_temp.tries($q$select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('a', 32))$q$) as anon_kept;
reset role;
set local role authenticated;
select pg_temp.tries($q$select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1')$q$) as user_leaving, pg_temp.tries($q$select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('a', 32))$q$) as user_kept;
reset role;
set local role service_role;
select pg_temp.tries($q$select public.oc_connect_leaving('00000000-0000-4000-8000-0000000000f1')$q$) as service_leaving, pg_temp.tries($q$select public.oc_connect_kept('00000000-0000-4000-8000-0000000000f1', 'did:oc:' || repeat('a', 32))$q$) as service_kept, pg_temp.tries('select * from public.oc_connected') as service_reads_table;
reset role;
