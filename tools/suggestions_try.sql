-- What supabase/suggestions.sql does, tried inside the rolled-back transaction of a
-- dry run on the live database: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/suggestions.sql --dry --try=tools/suggestions_try.sql --table=model_suggestions
--
-- Two of the checks' accounts (a designer and a remixer), a model of the designer's and
-- the remixer's remix of it, both in the checks' pool, made here: the change sent, sent
-- again, heard of at once by the designer (their notices and their count), listed for
-- them and for nobody else, refused where it must be, taken as a version, and heard of
-- by the remixer.
create temporary table try_people on commit drop as
  select u.id, row_number() over (order by u.created_at) as n
    from auth.users u join public.shared_models m on m.owner = u.id and m.test
   group by u.id, u.created_at order by u.created_at limit 2;
select count(*) as accounts from try_people;
insert into public.shared_models (id, owner, name, parts, bytes, published, test)
  select 'SugTryOrig', id, 'Try original', 10, 100, true, true from try_people where n = 1;
insert into public.shared_models (id, owner, name, parts, bytes, published, test, remixed_from)
  select 'SugTryRmx1', id, 'Try remix', 12, 120, true, true, 'SugTryOrig' from try_people where n = 2;
insert into public.shared_models (id, owner, name, parts, bytes, published, test, remixed_from)
  select 'SugTryOwn1', id, 'Try own remix', 12, 120, true, true, 'SugTryOrig' from try_people where n = 1;
-- Sent: a new one, then the same again (brought up to date, one open).
select public.suggestion_send('SugTryRmx1', (select id from try_people where n = 2), 1, 1, '  Wider wheels  ', '{"added":2,"moved":1}') as sent;
select public.suggestion_send('SugTryRmx1', (select id from try_people where n = 2), 2, 1, 'Wider wheels, and a roof', '{"added":3,"moved":1}') as sent_again;
select count(*) as open_rows, max(remix_n) as remix_n, max(note) as note from public.model_suggestions where remix = 'SugTryRmx1' and status = 'open';
-- Refused: not the sender's remix, a remix of one's own model, no remix at all.
select public.suggestion_send('SugTryRmx1', (select id from try_people where n = 1), 1, 1) as not_yours;
select public.suggestion_send('SugTryOwn1', (select id from try_people where n = 1), 1, 1) as own;
select public.suggestion_send('SugTryOrig', (select id from try_people where n = 1), 1, 1) as not_a_remix;
-- The designer hears of it at once, the remixer not yet; the count is the designer's.
select jsonb_array_length(public.suggestion_notices((select id from try_people where n = 1))) as designer_rows,
       public.suggestion_notices((select id from try_people where n = 1)) -> 0 ->> 'kind' as designer_kind,
       public.suggestion_notices((select id from try_people where n = 1)) -> 0 ->> 'on' as designer_on,
       jsonb_array_length(public.suggestion_notices((select id from try_people where n = 2))) as remixer_rows,
       public.suggestion_new_count((select id from try_people where n = 1)) as designer_count;
-- Listed open for the designer, for nobody else.
select public.suggestion_list('SugTryOrig', (select id from try_people where n = 1)) -> 'open' -> 0 ->> 'note' as open_for_designer,
       public.suggestion_list('SugTryOrig', (select id from try_people where n = 2)) -> 'open' as open_for_remixer,
       public.suggestion_list('SugTryOrig', null) -> 'open' as open_for_anybody;
-- Taken: not by the remixer, then by the designer as their version 2; once only.
select public.suggestion_close((select id from public.model_suggestions where remix = 'SugTryRmx1' and status = 'open'),
       (select id from try_people where n = 2), 'taken', 2, '{"added":3}', false) as taken_by_remixer;
select public.suggestion_close((select id from public.model_suggestions where remix = 'SugTryRmx1' and status = 'open'),
       (select id from try_people where n = 1), 'taken', 2, '{"added":3}', false) as taken;
select public.suggestion_close((select max(id) from public.model_suggestions where remix = 'SugTryRmx1'),
       (select id from try_people where n = 1), 'declined') as taken_again;
-- The remixer hears it was taken; the credit is listed for anybody, with its version.
select public.suggestion_notices((select id from try_people where n = 2)) -> 0 ->> 'kind' as remixer_kind,
       public.suggestion_notices((select id from try_people where n = 2)) -> 0 ->> 'n' as remixer_n,
       public.suggestion_list('SugTryOrig', null) -> 'taken' -> 0 ->> 'n' as credited_version,
       public.suggestion_list('SugTryOrig', null) -> 'taken' -> 0 -> 'taken' as credited_taken;
-- Sent again after it was taken: a new one.
select public.suggestion_send('SugTryRmx1', (select id from try_people where n = 2), 3, 2) as sent_after_taken;
select status, count(*) from public.model_suggestions where remix = 'SugTryRmx1' group by status order by status;
