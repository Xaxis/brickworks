-- What supabase/builds.sql does, tried inside the rolled-back transaction of
-- a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   cat supabase/trust.sql supabase/tested.sql supabase/builds.sql > /tmp/builds_dry.sql   (until those two are applied)
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs /tmp/builds_dry.sql --dry --try=tools/builds_try.sql --table=build_photos
--
-- Three made-up accounts at Resend test addresses (made and gone with the
-- transaction): one 13 or over, one under 13, one never asked. Each
-- statement is on one line: the dry run splits at a semicolon that ends a
-- line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'builds-grown@resend.dev'), ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'builds-young@resend.dev'), ('00000000-0000-4000-8000-0000000000b3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'builds-unasked@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000b1', true) as "13 or over", public.answer_age('00000000-0000-4000-8000-0000000000b2', false) as "under 13";
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test) values ('BuildTry01', '00000000-0000-4000-8000-0000000000b1', 'Try tower', 'Try Grown', 3, 100, true, now(), true), ('BuildTry02', '00000000-0000-4000-8000-0000000000b1', 'Try wall', 'Try Grown', 3, 100, true, now() - interval '1 minute', true);
insert into public.shared_models (id, owner, name, parts, bytes, published) values ('BuildTry03', '00000000-0000-4000-8000-0000000000b1', 'Try taken down', 3, 100, false);
-- Builds finished: once per device, only of a published model.
select public.count_build('BuildTry01', repeat('a', 32)) as "a device finishes it", public.count_build('BuildTry01', repeat('a', 32)) as "the same device again", public.count_build('BuildTry01', repeat('b', 32)) as "another device", public.count_build('BuildTry03', repeat('a', 32)) as "a model taken down";
select pg_temp.tries($q$select public.count_build('BuildTry02', 'not a key')$q$) as "a key that is not one";
select model, builds, views from public.model_stats where model like 'BuildTry%' order by model;
-- Its card says so, and the gallery's Most built puts it first; the card keeps the Tested mark and the credit rule.
select c->>'id' as id, c->>'builds' as builds, c ? 'tested' as "has tested", c ? 'by' as "has by" from public.directory_models('{"tests": true, "sort": "builds", "size": 2}'::jsonb) c;
select (public.directory_model('BuildTry01'))->>'builds' as "its page's builds";
-- Photos: 13 or over yes, three at most; under 13 and never asked, no.
select pg_temp.tries($q$insert into public.build_photos (id, model, account, words, width, height, bytes, was) values ('PhotoTry01', 'BuildTry01', '00000000-0000-4000-8000-0000000000b1', 'Built it in an afternoon', 1600, 1200, 200000, 'jpeg')$q$) as "13 or over: a photo";
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry02', 'BuildTry01', '00000000-0000-4000-8000-0000000000b1', 1600, 1200, 200000, 'png'), ('PhotoTry03', 'BuildTry01', '00000000-0000-4000-8000-0000000000b1', 1600, 1200, 200000, 'webp')$q$) as "13 or over: a second and a third";
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry04', 'BuildTry01', '00000000-0000-4000-8000-0000000000b1', 1600, 1200, 200000, 'jpeg')$q$) as "13 or over: a fourth of one model";
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry05', 'BuildTry02', '00000000-0000-4000-8000-0000000000b1', 1600, 1200, 200000, 'jpeg')$q$) as "13 or over: one of another model";
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry06', 'BuildTry01', '00000000-0000-4000-8000-0000000000b2', 1600, 1200, 200000, 'jpeg')$q$) as "under 13: a photo";
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry07', 'BuildTry01', '00000000-0000-4000-8000-0000000000b3', 1600, 1200, 200000, 'jpeg')$q$) as "never asked: a photo";
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry08', 'BuildTry02', '00000000-0000-4000-8000-0000000000b1', 4000, 3000, 200000, 'jpeg')$q$) as "a photo bigger than one made";
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry09', 'BuildTry02', '00000000-0000-4000-8000-0000000000b1', 1600, 1200, 200000, 'gif')$q$) as "a photo from a GIF";
-- Taken out by the site's owner: no longer counted against the three.
update public.build_photos set removed_at = now(), removed_why = 'Reported' where id = 'PhotoTry03';
select pg_temp.tries($q$insert into public.build_photos (id, model, account, width, height, bytes, was) values ('PhotoTry10', 'BuildTry01', '00000000-0000-4000-8000-0000000000b1', 1600, 1200, 200000, 'jpeg')$q$) as "one taken out, then another";
-- Hidden by the model's owner: kept, and still counted.
update public.build_photos set hidden_at = now() where id = 'PhotoTry02';
select id, hidden_at is not null as hidden, removed_at is not null as removed from public.build_photos where id like 'PhotoTry%' order by id;
-- A report about a photo: about its model as reports' check wants, and which photo; its stream the poster's, a test account's; its digest names the photo.
insert into public.reports (model, reason, note) values ('BuildTry01', 'personal', 'Try: a face in the photo');
insert into public.report_photos (report, photo) select max(id), 'PhotoTry01' from public.reports where note = 'Try: a face in the photo';
select public.report_stream(r) = 'test:00000000-0000-4000-8000-0000000000b1' as "its stream is the poster's" from public.reports r where note = 'Try: a face in the photo';
select (d->'reports'->0->>'photo') as "the digest names the photo", d->>'stream' as stream from public.claim_report_digest('test:00000000-0000-4000-8000-0000000000b1') d;
select pg_temp.tries($q$with r as (insert into public.reports (model, reason) values ('BuildTry01', 'spam') returning id) insert into public.report_photos (report, photo) select id, 'NoSuchPho1' from r$q$) as "a report about a photo that is not there";
-- The buckets: private, and what each takes.
select id, public, file_size_limit, allowed_mime_types from storage.buckets where id in ('build-photo-uploads', 'build-photos') order by id;
-- Nobody but the server: no grant to a page's keys on the new tables.
select table_name, string_agg(distinct grantee, ', ') as grantees from information_schema.role_table_grants where table_schema = 'public' and table_name in ('model_builds', 'build_photos', 'report_photos') and grantee in ('anon', 'authenticated') group by table_name;
select relname, relrowsecurity from pg_class where relname in ('model_builds', 'build_photos', 'report_photos') order by relname
