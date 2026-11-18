-- What supabase/announce2.sql does, tried inside the rolled-back transaction
-- of a dry run, after the file: nothing here is kept. Made-up accounts, made
-- and gone with the transaction: Ada at Resend's test address (the checks'
-- pool); Dee and Eve at example.com (anybody else), both asking for news by
-- email, Eve barred. Only the made-up three are named in what is printed;
-- anybody else is only counted.
--
--   grep -E '^(SUPABASE_PROJECT_REF|SUPABASE_DB_PASSWORD|SUPABASE_POOLER)=' .env > $SCRATCH/db.env
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=$SCRATCH/db.env \
--     tools/apply_sql.mjs supabase/announce2.sql --dry --try=tools/announce2_try.sql --table=announcement_to
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line. Inside one transaction now() never moves.
create function pg_temp.who(account uuid) returns text language sql as $$ select case account when '00000000-0000-4000-8000-0000000ab001' then 'ada' when '00000000-0000-4000-8000-0000000ab004' then 'dee' when '00000000-0000-4000-8000-0000000ab005' then 'eve' end $$;
-- Copied once: who each sent one reached, as its rows (an account since deleted has none: its row would go with it), and its counts.
select (select count(*) from public.announcements where sent_at is not null) as sent, (select coalesce(sum(cardinality(recipients)), 0) from public.announcements where sent_at is not null) as recipients_before, (select count(*) from public.announcements a cross join lateral unnest(a.recipients) t(account) where a.sent_at is not null and exists (select 1 from auth.users u where u.id = t.account)) as recipients_still_accounts, (select count(*) from public.announcement_to) as rows_now, (select count(*) from public.announcement_counts) as counts_now;
-- Row security on, no policy, no grant to any role, the server's included.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname in ('announcement_to', 'announcement_counts') order by c.relname;
-- The functions: the server's alone, the counts' helper nobody's.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p where p.pronamespace = 'public'::regnamespace and (p.proname like 'announce%' or p.proname like 'news_mail_%' or p.proname = 'site_notice_hidden_ids') order by p.proname;
-- The made-up three.
insert into auth.users (id, instance_id, aud, role, email, created_at, email_confirmed_at) values ('00000000-0000-4000-8000-0000000ab001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'an2-try-ada@resend.dev', now() - interval '2 days', now()), ('00000000-0000-4000-8000-0000000ab004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'an2-try-dee@example.com', now() - interval '2 days', now()), ('00000000-0000-4000-8000-0000000ab005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'an2-try-eve@example.com', now() - interval '2 days', now());
select public.answer_age('00000000-0000-4000-8000-0000000ab004', true)->>'over_13' as dee, public.answer_age('00000000-0000-4000-8000-0000000ab005', true)->>'over_13' as eve;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000ab004', 'an2-try-dee', 'Dee Try'), ('00000000-0000-4000-8000-0000000ab005', 'an2-try-eve', 'Eve Try');
select public.news_choice('00000000-0000-4000-8000-0000000ab004', true, 'settings')->>'news' as dee, public.news_choice('00000000-0000-4000-8000-0000000ab005', true, 'settings')->>'news' as eve;
update public.news_mail set at = now() - interval '1 day' where account in ('00000000-0000-4000-8000-0000000ab004', '00000000-0000-4000-8000-0000000ab005');
insert into public.barred_accounts (account) values ('00000000-0000-4000-8000-0000000ab005');
-- Barred, Eve is in no audience but her own, and mailed by none.
select (select string_agg(pg_temp.who(a), ',' order by 1) from public.announce_audience('{"kind":"everyone"}', false) a where pg_temp.who(a) is not null) as everyone, (select string_agg(pg_temp.who(a), ',') from public.announce_audience('{"kind":"person","handle":"an2-try-eve"}', false) a) as eve_alone, public.announce_count('{"kind":"person","handle":"an2-try-eve"}', false) as eve_alone_count;
-- Sent to Dee: one row of announcement_to, written with the send; recipients kept empty; its reach the rows' count.
select (public.announce_keep(null, false, 'An2 try', 'Words', null, '{"kind":"person","handle":"an2-try-dee"}', true, 'an2-try')->'announcement'->>'id') as kept;
select (public.announce_press(a.id, false, a.changed_at, 'an2-try', repeat('a', 64), null, 1000)->'announcement'->>'status') as pressed from public.announcements a where a.title = 'An2 try' and a.pressed_by is null;
select a.status, a.reach, a.recipients, (select string_agg(pg_temp.who(t.account), ',') from public.announcement_to t where t.announcement = a.id) as rows_for, (select count(*) from public.announcement_counts c where c.announcement = a.id) as counts_row from public.announcements a where a.title = 'An2 try';
-- Dee's Notifications have it, read once and counted once; Eve's do not.
select (select count(*) from public.announcement_rows('00000000-0000-4000-8000-0000000ab004', now() - interval '1 hour', now() + interval '1 hour') r where r.item->>'title' = 'An2 try') as dee_has, (select count(*) from public.announcement_rows('00000000-0000-4000-8000-0000000ab005', now() - interval '1 hour', now() + interval '1 hour') r where r.item->>'title' = 'An2 try') as eve_has;
select public.announcement_read('00000000-0000-4000-8000-0000000ab004', a.id, true) as first, public.announcement_read('00000000-0000-4000-8000-0000000ab004', a.id, true) as again from public.announcements a where a.title = 'An2 try';
select x->>'read' as read, x->>'clicked' as clicked, x->'mails' as mails, x ? 'seen' as says_seen, x ? 'recipients' as says_recipients from jsonb_array_elements(public.announce_list(false, 200, null)) x where x->>'title' = 'An2 try';
-- The news mail's most and today, before the take.
select public.news_mail_state('live') - 'most_at' - 'most_by' as state;
-- The take: Dee alone (Eve is barred), written down as being sent; then answered.
select (select string_agg(pg_temp.who((m->>'account')::uuid), ',') from jsonb_array_elements(public.announce_mail_take(a.id, 100)) m) as taken from public.announcements a where a.title = 'An2 try';
select public.announce_mail_done(a.id, jsonb_build_array(jsonb_build_object('account', '00000000-0000-4000-8000-0000000ab004', 'state', 'sent', 'sent_id', 're_try'))) as kept from public.announcements a where a.title = 'An2 try';
select x->'mails' as mails from jsonb_array_elements(public.announce_list(false, 200, null)) x where x->>'title' = 'An2 try';
select (public.news_mail_state('live')->>'today')::int as today_after;
-- Stopped (as Resend's quota would stop it): the take gives nobody, and the console reads why.
select public.announce_mail_stop(now() + interval '1 hour', 'daily_quota_exceeded') ->> 'why' as stopped_for;
select public.news_mail_stopped()->>'why' as why, (select count(*) from public.announcement_mails m join public.announcements a on a.id = m.announcement where a.title = 'An2 try') as mails_before_take, jsonb_array_length(public.announce_mail_take((select id from public.announcements where title = 'An2 try'), 100)) as taken_while_stopped;
-- The notices Dee hid, as the avatar's count says them: none.
select public.site_notice_hidden_ids('00000000-0000-4000-8000-0000000ab004', 'live') as dee_hid;
