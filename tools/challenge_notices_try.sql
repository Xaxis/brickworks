-- What supabase/challenge_notices.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/achievements.sql --again=supabase/challenge_notices.sql \
--       --dry --try=tools/challenge_notices_try.sql --table=challenge_reads
--
-- (achievements.sql first, as it is applied, if it is not yet.) Made-up accounts, made and gone with the
-- transaction, all but Gus at a Resend test address (test accounts, who hear only of test challenges): Cara votes,
-- Dan enters, Eve said she is under 13, Finn signed up yesterday, Gus is not a test account, Hal is out of the
-- gallery. Each statement is on one line: the dry run splits at a semicolon that ends a line. Inside one
-- transaction now() never moves. Only the challenges made here (titled "CN ...") are read back.
insert into auth.users (id, instance_id, aud, role, email, created_at) values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cn-cara@resend.dev', now() - interval '60 days'), ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cn-dan@resend.dev', now() - interval '60 days'), ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cn-eve@resend.dev', now() - interval '60 days'), ('00000000-0000-4000-8000-0000000000f4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cn-finn@resend.dev', public.challenge_today()::timestamp at time zone 'utc' - interval '23 hours'), ('00000000-0000-4000-8000-0000000000f5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cn-gus@brickworks.invalid', now() - interval '60 days'), ('00000000-0000-4000-8000-0000000000f6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cn-hal@resend.dev', now() - interval '60 days');
select public.answer_age('00000000-0000-4000-8000-0000000000f1', true)->>'over_13' as cara, public.answer_age('00000000-0000-4000-8000-0000000000f2', true)->>'over_13' as dan, public.answer_age('00000000-0000-4000-8000-0000000000f3', false)->>'over_13' as eve, public.answer_age('00000000-0000-4000-8000-0000000000f4', true)->>'over_13' as finn, public.answer_age('00000000-0000-4000-8000-0000000000f5', true)->>'over_13' as gus, public.answer_age('00000000-0000-4000-8000-0000000000f6', true)->>'over_13' as hal;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000f2', 'cn-try-dan', 'Dan Enters');
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000000f6', 'challenge notices try');
-- The challenges, days in UTC: A open now, in its last two days; B ended a fortnight ago and settled yesterday; C ended early, the day after it opened; D not yet open; E open five days but told only an hour ago; F open, and not a test challenge.
insert into public.challenges (title, brief, starts_on, ends_on, test) values ('CN A open now', 'Build a boat.', public.challenge_today() - 3, public.challenge_today() + 1, true), ('CN B settled', 'Build a bridge.', public.challenge_today() - 20, public.challenge_today() - 14, true), ('CN D later', 'Build a tower.', public.challenge_today() + 5, public.challenge_today() + 12, true), ('CN F everyone', 'Build a train.', public.challenge_today() - 2, public.challenge_today() + 10, false);
insert into public.challenges (title, brief, starts_on, ends_on, test, ended_at) values ('CN C ended early', 'Build a crane.', public.challenge_today() - 3, public.challenge_today() + 1, true, (public.challenge_today() - 2)::timestamp at time zone 'utc' + interval '1 hour');
insert into public.challenges (title, brief, starts_on, ends_on, test, announced_at) values ('CN E told late', 'Build a mill.', public.challenge_today() - 5, public.challenge_today() + 6, true, now() - interval '1 hour');
-- Dan entered A and B; Cara voted in B for his entry, which won.
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published) values ('CnTry00001', '00000000-0000-4000-8000-0000000000f2', 'CN boat', 'Dan Enters', 40, 100, true, now(), true, true), ('CnTry00002', '00000000-0000-4000-8000-0000000000f2', 'CN bridge', 'Dan Enters', 40, 100, true, now(), true, true);
insert into public.challenge_entries (challenge, model, owner, way) values ((select id from public.challenges where title = 'CN A open now'), 'CnTry00001', '00000000-0000-4000-8000-0000000000f2', 'hand'), ((select id from public.challenges where title = 'CN B settled'), 'CnTry00002', '00000000-0000-4000-8000-0000000000f2', 'hand');
insert into public.challenge_votes (challenge, way, voter, model) values ((select id from public.challenges where title = 'CN B settled'), 'hand', '00000000-0000-4000-8000-0000000000f1', 'CnTry00002');
insert into public.challenge_winners (challenge, way, model, owner, votes) values ((select id from public.challenges where title = 'CN B settled'), 'hand', 'CnTry00002', '00000000-0000-4000-8000-0000000000f2', 1);
update public.challenges set settled_at = now() - interval '1 day' where title = 'CN B settled';
-- Cara hears of A opening and of its last two days, B's too and who won it (her pick), C opening (not its last days: it ended), E as it was told; nothing of D or F.
select n.item->>'title' as title, n.kind, n.model, n.at = (public.challenge_today() - 3)::timestamp at time zone 'utc' as "at A's first day", n.item->>'picked' as picked, n.item->>'read' as read from public.notification_rows('00000000-0000-4000-8000-0000000000f1', now() - interval '90 days', now()) n where n.item->>'title' like 'CN %' order by n.item->>'title', n.kind;
-- Dan entered A and B: no reminder for either, and B's outcome as his 'result', under his model.
select n.item->>'title' as title, n.kind, n.model from public.notification_rows('00000000-0000-4000-8000-0000000000f2', now() - interval '90 days', now()) n where n.item->>'title' like 'CN %' order by n.item->>'title', n.kind;
-- Finn, signed up yesterday: only what came after (A's last two days, E told).
select string_agg((n.item->>'title') || ' ' || n.kind, ', ' order by n.item->>'title', n.kind) as "finn hears" from public.notification_rows('00000000-0000-4000-8000-0000000000f4', now() - interval '90 days', now()) n where n.item->>'title' like 'CN %';
-- Gus, not a test account, hears of F alone; Eve (under 13) and Hal (out of the gallery) of none.
select (select string_agg((n.item->>'title') || ' ' || n.kind, ', ' order by n.item->>'title', n.kind) from public.notification_rows('00000000-0000-4000-8000-0000000000f5', now() - interval '90 days', now()) n where n.item->>'title' like 'CN %') as "gus hears", (select count(*) from public.notification_rows('00000000-0000-4000-8000-0000000000f3', now() - interval '90 days', now()) n where n.item->>'title' like 'CN %') as eve, (select count(*) from public.notification_rows('00000000-0000-4000-8000-0000000000f6', now() - interval '90 days', now()) n where n.item->>'title' like 'CN %') as hal;
-- In her list as new, on no model, and counted.
select public.notification_counts('00000000-0000-4000-8000-0000000000f1') as counts, (select count(*) from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000000f1')->'rows') r where r->>'kind' like 'challenge_%' and r->>'title' like 'CN %' and r->>'on' is null) as "listed, on nothing";
-- She opens A's group: A's read, the others not; no such challenge, or nobody signed in, is refused.
select public.challenge_read('00000000-0000-4000-8000-0000000000f1', (select id from public.challenges where title = 'CN A open now')) as "read", public.challenge_read('00000000-0000-4000-8000-0000000000f1', -1) as "no such", public.challenge_read(null, (select id from public.challenges where title = 'CN A open now')) as "nobody";
select n.item->>'title' as title, n.kind, n.item->>'read' as read from public.notification_rows('00000000-0000-4000-8000-0000000000f1', now() - interval '90 days', now()) n where n.item->>'title' like 'CN %' order by n.item->>'title', n.kind;
-- Read again (a later visit) moves the mark, still one row.
select public.challenge_read('00000000-0000-4000-8000-0000000000f1', (select id from public.challenges where title = 'CN A open now')) as "read again", (select count(*) from public.challenge_reads where account = '00000000-0000-4000-8000-0000000000f1') as "rows";
-- A deleted challenge, or account, takes what was read with it.
delete from public.challenges where title = 'CN A open now';
select count(*) as "hers left after A went" from public.challenge_reads where account = '00000000-0000-4000-8000-0000000000f1';
delete from auth.users where id = '00000000-0000-4000-8000-0000000000f1';
-- Nobody but the server runs any of it, or reads the table.
select r.rolname, p.proname from pg_proc p cross join (values ('anon'), ('authenticated')) r(rolname) where p.pronamespace = 'public'::regnamespace and p.proname in ('challenge_read', 'notification_rows') and has_function_privilege(r.rolname, p.oid, 'execute');
select count(*) as "the service role runs" from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('challenge_read', 'notification_rows') and has_function_privilege('service_role', p.oid, 'execute');
select has_table_privilege('anon', 'public.challenge_reads', 'select') as anon_reads, has_table_privilege('authenticated', 'public.challenge_reads', 'select') as signed_in_reads, has_table_privilege('service_role', 'public.challenge_reads', 'select') as service_reads, (select relrowsecurity from pg_class where oid = 'public.challenge_reads'::regclass) as row_security
