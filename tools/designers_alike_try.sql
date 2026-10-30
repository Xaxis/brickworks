-- What supabase/designers_alike.sql does, tried inside the rolled-back transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/designers_alike.sql --dry --try=tools/designers_alike_try.sql --table=model_needs
--
-- After the live files (trust, follows, moderation, test_models, discovery), which the project has. Made-up
-- accounts, made and gone with the transaction: Ada designs, and the others are measured against her. Ben uses
-- five of her six parts and one of his own; Cy one of them and three of his own; Di none. Fay uses all six but was
-- taken out; Gus's model is not listed; Hal's is listed without his name. Flo and Fin follow Ada; Flo follows Cy and
-- Di too, Fin Cy; Fox follows Ada and Di but was taken out. Every model a test model. Each statement is on one
-- line: the dry run splits at a semicolon that ends a line.
-- How long it takes on the real tables, before anything is made here: for the owner with the most listed models.
create function pg_temp.timed(account uuid, tests boolean) returns text language plpgsql as $$ declare t0 timestamptz; n integer; begin t0 := clock_timestamp(); select count(*) into n from public.designers_alike(account, tests); return format('%s rows in %s ms', n, round(extract(epoch from clock_timestamp() - t0) * 1000, 1)); end $$;
select (select count(*) from public.shared_models m where m.owner = b.owner and m.listed) as listed, pg_temp.timed(b.owner, false) as "the busiest designer" from (select owner from public.shared_models where listed group by owner order by count(*) desc limit 1) b;
insert into auth.users (id, instance_id, aud, role, email) select ('00000000-0000-4000-8000-0000000000e' || n)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alike-' || n || '@resend.dev' from generate_series(1, 9) n;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alike-flo@resend.dev'), ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alike-fin@resend.dev'), ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alike-fox@resend.dev');
select count(*) filter (where (public.answer_age(id, true)->>'over_13')::boolean) as "13 or over" from auth.users where email like 'alike-%@resend.dev';
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000e1', 'alike-try-ada', 'Ada'), ('00000000-0000-4000-8000-0000000000e2', 'alike-try-ben', 'Ben'), ('00000000-0000-4000-8000-0000000000e3', 'alike-try-cy', 'Cy'), ('00000000-0000-4000-8000-0000000000e4', 'alike-try-di', 'Di');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published) values ('AlikeTr001', '00000000-0000-4000-8000-0000000000e1', 'Ada keep', 'Ada', 4, 100, true, now(), true, true), ('AlikeTr002', '00000000-0000-4000-8000-0000000000e1', 'Ada gate', 'Ada', 2, 100, true, now(), true, true), ('AlikeTr003', '00000000-0000-4000-8000-0000000000e2', 'Ben wall', 'Ben', 6, 100, true, now(), true, true), ('AlikeTr004', '00000000-0000-4000-8000-0000000000e3', 'Cy rover', 'Cy', 4, 100, true, now(), true, true), ('AlikeTr005', '00000000-0000-4000-8000-0000000000e4', 'Di boat', 'Di', 1, 100, true, now(), true, true), ('AlikeTr006', '00000000-0000-4000-8000-0000000000e6', 'Fay keep', 'Fay', 6, 100, true, now(), true, true), ('AlikeTr007', '00000000-0000-4000-8000-0000000000e7', 'Gus keep', 'Gus', 6, 100, false, null, true, true), ('AlikeTr008', '00000000-0000-4000-8000-0000000000e8', 'Hal keep', null, 6, 100, true, now(), true, true);
-- Ada's six parts, the keep's in two colours each: colours aside, still six.
insert into public.model_needs (model, part, colour, qty) select 'AlikeTr001', p, c, 1 from unnest(array['alike-1', 'alike-2', 'alike-3', 'alike-4']) p cross join unnest(array[1, 4]) c;
insert into public.model_needs (model, part, colour, qty) select 'AlikeTr002', p, 15, 2 from unnest(array['alike-5', 'alike-6']) p;
insert into public.model_needs (model, part, colour, qty) select 'AlikeTr003', p, 7, 1 from unnest(array['alike-1', 'alike-2', 'alike-3', 'alike-4', 'alike-5', 'alike-ben']) p;
insert into public.model_needs (model, part, colour, qty) select 'AlikeTr004', p, 7, 1 from unnest(array['alike-1', 'alike-cy1', 'alike-cy2', 'alike-cy3']) p;
insert into public.model_needs (model, part, colour, qty) values ('AlikeTr005', 'alike-di', 7, 1);
insert into public.model_needs (model, part, colour, qty) select m, p, 7, 1 from unnest(array['AlikeTr006', 'AlikeTr007', 'AlikeTr008']) m cross join unnest(array['alike-1', 'alike-2', 'alike-3', 'alike-4', 'alike-5', 'alike-6']) p;
insert into public.follows (follower, followed) values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e1'), ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e3'), ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e4'), ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000e1'), ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000e3'), ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-4000-8000-0000000000e1'), ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-4000-8000-0000000000e4');
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000000e6', 'alike try'), ('00000000-0000-4000-8000-0000000000f3', 'alike try');
-- Ben 5 of 7 (0.714), Cy 1 of 9 (0.111) with two followers in common, Di none but one follower (Fox, taken out, not counted). Not Ada, Fay, Gus or Hal.
select p.handle, round(a.parts, 3) as parts, a.common from public.designers_alike('00000000-0000-4000-8000-0000000000e1', true) a join public.people p on p.account = a.account where p.handle like 'alike-try-%' order by a.parts desc, a.common desc;
select count(*) as "anybody else of the try's" from public.designers_alike('00000000-0000-4000-8000-0000000000e1', true) a where a.account::text like '00000000-0000-4000-8000-0000000000%' and a.account not in ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000e4');
-- A visitor's answer, without test models: none of the try's.
select count(*) as "test models without tests" from public.designers_alike('00000000-0000-4000-8000-0000000000e1', false) a where a.account::text like '00000000-0000-4000-8000-0000000000%';
-- Measured from Cy: Ada and Ben share one part with him, Ada 1 of 9, Ben 1 of 9; Flo and Fin follow Ada too.
select p.handle, round(a.parts, 3) as parts, a.common from public.designers_alike('00000000-0000-4000-8000-0000000000e3', true) a join public.people p on p.account = a.account where p.handle like 'alike-try-%' order by a.parts desc, a.common desc, p.handle;
-- Somebody with nothing in the gallery is like nobody, by parts; nobody follows them.
select count(*) as "for an account with no models" from public.designers_alike('00000000-0000-4000-8000-0000000000e9', true);
-- At scale: 2,000 more designers of three models each, 40 parts a model from a pool of 1,500, and 1,000 followers of Ada who each follow 20 of them.
insert into auth.users (id, instance_id, aud, role, email) select ('00000000-0000-4000-9000-' || lpad(to_hex(g), 12, '0'))::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alike-scale-' || g || '@resend.dev' from generate_series(1, 3000) g;
update public.profiles set over_13 = true, age_asked_at = now() where email like 'alike-scale-%@resend.dev';
insert into public.people (account, handle, name) select ('00000000-0000-4000-9000-' || lpad(to_hex(g), 12, '0'))::uuid, 'alike-scale-' || g, 'Scale ' || g from generate_series(1, 2000) g;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published) select 'AlikeS' || lpad(((g - 1) * 3 + k)::text, 4, '0'), ('00000000-0000-4000-9000-' || lpad(to_hex(g), 12, '0'))::uuid, 'Scale', 'Scale', 40, 100, true, now(), true, true from generate_series(1, 2000) g cross join generate_series(1, 3) k;
insert into public.model_needs (model, part, colour, qty) select m.id, 'alike-s' || ((abs(hashtext(m.id)) + j * 37) % 1500), 7, 1 from public.shared_models m cross join generate_series(1, 40) j where m.id like 'AlikeS%' on conflict do nothing;
insert into public.model_needs (model, part, colour, qty) select 'AlikeTr001', 'alike-s' || j, 7, 1 from generate_series(1, 60) j;
insert into public.follows (follower, followed) select ('00000000-0000-4000-9000-' || lpad(to_hex(2000 + f), 12, '0'))::uuid, '00000000-0000-4000-8000-0000000000e1' from generate_series(1, 1000) f;
insert into public.follows (follower, followed) select ('00000000-0000-4000-9000-' || lpad(to_hex(2000 + f), 12, '0'))::uuid, ('00000000-0000-4000-9000-' || lpad(to_hex(1 + (f * 7 + k * 101) % 2000), 12, '0'))::uuid from generate_series(1, 1000) f cross join generate_series(1, 20) k on conflict do nothing;
analyze public.model_needs;
analyze public.follows;
select (select count(*) from public.model_needs where model like 'AlikeS%') as "needs", (select count(*) from public.follows where follower::text like '00000000-0000-4000-9000-%') as "follows", pg_temp.timed('00000000-0000-4000-8000-0000000000e1', true) as "Ada among 2,000 designers";
select count(*) as "rows", max(a.common) as "most followers in common", round(max(a.parts), 3) as "most parts" from public.designers_alike('00000000-0000-4000-8000-0000000000e1', true) a;
-- Nobody but the server runs it.
select r.rolname from pg_proc p cross join (values ('anon'), ('authenticated')) r(rolname) where p.pronamespace = 'public'::regnamespace and p.proname = 'designers_alike' and has_function_privilege(r.rolname, p.oid, 'execute');
select has_function_privilege('service_role', 'public.designers_alike(uuid, boolean)', 'execute') as "the service role runs it", (select prosecdef from pg_proc where oid = 'public.designers_alike(uuid, boolean)'::regprocedure) as "security definer"
