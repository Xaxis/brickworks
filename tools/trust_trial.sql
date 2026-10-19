-- What supabase/trust.sql does, tried inside the rolled-back transaction of
-- a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/trust.sql --dry --try=tools/trust_trial.sql --table=profiles
--
-- Three made-up accounts at Resend test addresses (made and gone with the
-- transaction): one that says it is under 13, one 13 or over, one never
-- asked. Each statement is on one line: the dry run splits at a semicolon
-- that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-young@resend.dev'), ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-grown@resend.dev'), ('00000000-0000-4000-8000-0000000000a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-unasked@resend.dev');
-- Never asked: ask, and nothing public allowed yet.
select public.age_of('00000000-0000-4000-8000-0000000000a1') as "a new account";
-- Under 13, then a second try with another answer: the first stands.
select public.answer_age('00000000-0000-4000-8000-0000000000a1', false) as "answered under 13";
select public.answer_age('00000000-0000-4000-8000-0000000000a1', true) as "answered again, 13 or over";
select public.answer_age('00000000-0000-4000-8000-0000000000a2', true) as "the other, 13 or over";
-- No birth date anywhere: what profiles keeps of the three.
select email, over_13, age_asked_at is not null as asked from public.profiles where id::text like '00000000-0000-4000-8000-0000000000a%' order by email;
-- Under 13: a link shared, unlisted and uncredited, is fine; listed, credited, a profile or a public list is not.
select pg_temp.tries($q$insert into public.shared_models (id, owner, name, parts, bytes) values ('TrialYng01', '00000000-0000-4000-8000-0000000000a1', 'Trial house', 1, 10)$q$) as "under 13: share by link";
select pg_temp.tries($q$update public.shared_models set listed = true, listed_at = now() where id = 'TrialYng01'$q$) as "under 13: list it";
select pg_temp.tries($q$insert into public.shared_models (id, owner, name, parts, bytes, listed, listed_at) values ('TrialYng02', '00000000-0000-4000-8000-0000000000a1', 'Trial shed', 1, 10, true, now())$q$) as "under 13: share listed";
select pg_temp.tries($q$update public.shared_models set author = 'Trial Child' where id = 'TrialYng01'$q$) as "under 13: credit a name";
select pg_temp.tries($q$insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000a1', 'trial-young', 'Trial Young')$q$) as "under 13: a profile";
select pg_temp.tries($q$insert into public.model_collections (id, owner, name) values ('TrialYngC1', '00000000-0000-4000-8000-0000000000a1', 'Mine')$q$) as "under 13: a private list";
select pg_temp.tries($q$update public.model_collections set public = true where id = 'TrialYngC1'$q$) as "under 13: make it public";
-- 13 or over: all of it.
select pg_temp.tries($q$insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at) values ('TrialOld01', '00000000-0000-4000-8000-0000000000a2', 'Trial tower', 'Trial Grown', 1, 10, true, now())$q$) as "13 or over: share listed and credited";
select pg_temp.tries($q$insert into public.people (account, handle, name, bio) values ('00000000-0000-4000-8000-0000000000a2', 'trial-grown', 'Trial Grown', 'Builds towers')$q$) as "13 or over: a profile";
select pg_temp.tries($q$insert into public.model_collections (id, owner, name, public) values ('TrialOldC1', '00000000-0000-4000-8000-0000000000a2', 'Towers', true)$q$) as "13 or over: a public list";
-- Never asked: by link yes; nothing new in public until it answers.
select pg_temp.tries($q$insert into public.shared_models (id, owner, name, author, parts, bytes) values ('TrialUna01', '00000000-0000-4000-8000-0000000000a3', 'Trial wall', 'Trial Unasked', 1, 10)$q$) as "not asked: share by link, credited";
select pg_temp.tries($q$update public.shared_models set listed = true, listed_at = now() where id = 'TrialUna01'$q$) as "not asked: list it";
select pg_temp.tries($q$insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000a3', 'trial-unasked', 'Trial Unasked')$q$) as "not asked: a profile";
-- Listed before it answered, then answered under 13: out of the gallery, its list private, nothing deleted.
select pg_temp.tries($q$update public.profiles set over_13 = true, age_asked_at = now() where id = '00000000-0000-4000-8000-0000000000a3'$q$) as "(made 13 or over for a moment)";
select pg_temp.tries($q$update public.shared_models set listed = true, listed_at = now() where id = 'TrialUna01'$q$) as "listed while 13 or over";
select pg_temp.tries($q$insert into public.model_collections (id, owner, name, public) values ('TrialUnaC1', '00000000-0000-4000-8000-0000000000a3', 'Walls', true)$q$) as "a public list while 13 or over";
select pg_temp.tries($q$update public.profiles set over_13 = null, age_asked_at = null where id = '00000000-0000-4000-8000-0000000000a3'$q$) as "(and back to not asked)";
select public.answer_age('00000000-0000-4000-8000-0000000000a3', false) as "then answered under 13";
select id, listed, author from public.shared_models where id = 'TrialUna01';
select id, public from public.model_collections where id = 'TrialUnaC1';
-- What is shown of whom.
select public.shown_publicly('00000000-0000-4000-8000-0000000000a1') as "shown: under 13", public.shown_publicly('00000000-0000-4000-8000-0000000000a2') as "shown: 13 or over";
select public.profile_page('trial-grown', true) is not null as "13 or over's profile page";
-- Reports: one about the 13-or-over test account's model goes in its own test stream, dry; a second that hour waits.
insert into public.reports (model, reason, note) values ('TrialOld01', 'copied', 'Trial: my tower');
select public.report_stream(r) as stream from public.reports r where r.model = 'TrialOld01';
select public.claim_report_digest('owner', (select max(id) from public.reports where model = 'TrialOld01')) as "first report: a digest";
insert into public.reports (model, reason, note) values ('TrialOld01', 'spam', 'Trial: again');
select public.claim_report_digest('owner', (select max(id) from public.reports where model = 'TrialOld01')) as "second report the same hour: waits";
select public.finish_report_digest((select max(id) from public.report_digests where stream = 'test:00000000-0000-4000-8000-0000000000a2'), 'dry', 'Brickworks: 1 report', 'text', '<p>html</p>') as "recorded dry";
select stream, state, reports, subject is not null as kept_subject from public.report_digests where stream like 'test:%0000a2';
-- Of the owner's stream: no test report is ever in it.
select public.claim_report_digest('owner') ->> 'reports' as "owner's stream now";
-- The knock.
select jobname, schedule, command from cron.job where jobname = 'brickworks-report-digest';
-- What a new column holds for the accounts already there: nothing yet.
select count(*) filter (where over_13 is null) as not_asked, count(*) filter (where over_13 is not null) as answered from public.profiles where id::text not like '00000000-0000-4000-8000-0000000000a%'
