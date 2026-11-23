-- What supabase/challenge_studio.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/challenge_studio.sql --dry --try=tools/challenge_studio_try.sql --table=challenges
--
-- Test challenges only, made and gone with the transaction. Each statement is
-- on one line: the dry run splits at a semicolon that ends a line.
-- Any test challenge a flow left open is ended first: one at a time.
update public.challenges set ended_at = now() where test and ended_at is null and kind = 'month';
-- One open with a set of three lots, one open with no set, one that ended.
insert into public.challenges (title, brief, starts_on, ends_on, most_parts, set_number, set_name, tested, test) values ('Studio try set', 'Brief', current_date - 1, current_date + 5, 150, '31009-1', 'Studio try house', true, true);
insert into public.challenge_set_parts (challenge, part, colour, qty) select id, x.part, x.colour, x.qty from public.challenges, (values ('3001', 4, 6), ('3003', 1, 2), ('2357', 15, 4)) x(part, colour, qty) where title = 'Studio try set';
-- The set's lots as kept, in part and colour order, and counted.
select public.challenge_set_lots((select id from public.challenges where title = 'Studio try set')) as lots, jsonb_array_length(public.challenge_set_lots((select id from public.challenges where title = 'Studio try set'))) as "how many";
-- An open challenge with no set says [], an ended one and one that never was say nothing.
update public.challenges set ended_at = now() where title = 'Studio try set';
insert into public.challenges (title, brief, starts_on, ends_on, most_parts, test) values ('Studio try plain', 'Brief', current_date - 1, current_date + 5, 150, true);
select public.challenge_set_lots((select id from public.challenges where title = 'Studio try plain')) as "no set", public.challenge_set_lots((select id from public.challenges where title = 'Studio try set')) is null as "ended says nothing", public.challenge_set_lots(-1) is null as "none says nothing";
-- Only the server may call it.
select has_function_privilege('anon', 'public.challenge_set_lots(bigint)', 'execute') as anon, has_function_privilege('authenticated', 'public.challenge_set_lots(bigint)', 'execute') as authenticated, has_function_privilege('service_role', 'public.challenge_set_lots(bigint)', 'execute') as service_role;
