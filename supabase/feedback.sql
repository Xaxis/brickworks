-- Feedback, from anywhere, and the beta's testers marked (beta374,
-- 2026-10-30).
--
-- The owner: "start working on beta tester features and feedback system".
-- A person sends a report from the app (Help, Send feedback) or the site
-- (the footer's Send feedback, or the account menu): a bug, an idea or a
-- question, a few words, and what they chose to attach: a picture (the
-- app's own view of the window, or the page), and with their consent the
-- app's version and platform, the open model as a file and the app's last
-- log lines (api/_feedback.js). Signed in, the account is the sender and
-- its address is never copied here; signed out, they give an address to
-- be answered at. The owner reads each on /admin, marks where it stands,
-- keeps a private note and answers by email from the beta's address; the
-- sender sees their own reports, where each stands and the answers, on
-- /settings.
--
--   feedback          one a report: what was said, what was attached (the
--                     files themselves in the private bucket 'feedback',
--                     named <id>/picture.<png|jpg> and <id>/model.mpd), the
--                     log lines in the row, whether the sender was a beta
--                     tester when they sent it, and where it stands (new,
--                     seen, planned, fixed, wont_fix) with the owner's note
--   feedback_replies  every answer the owner sent: the words, who, when,
--                     whether the email went (sent, dry for a test inbox
--                     where the server has no mail key, failed) and
--                     Resend's id. Kept with the report, shown to its sender.
--   feedback_tries    the rate: one row a report sent, by account or, signed
--                     out, by a key made from where it came from (an HMAC
--                     with the server's secret, as plan_interest_tries) and
--                     by the address given. Kept a day. No IP address is
--                     kept anywhere.
--
-- A tester is an account whose beta application was approved (beta.sql's
-- beta_applications.status): beta_tester says so, for the report's mark
-- and for the early features only testers see (api/_early.js).
--
-- A report from an account goes with the account (on delete cascade), its
-- files first (api/account.js, from feedback_files_of). One sent signed
-- out, and one closed (fixed or won't fix), is erased a year after it was
-- last changed (feedback_sweep, run by the beta's daily cron), its files
-- with it. Test reports (Resend test addresses: the site's checks) go
-- after a day.
--
-- Only the server touches any of it (api/_feedback.js, with the secret
-- key), through the functions below, each security definer and granted to
-- the service role alone. Row security on, no policy, and every grant on
-- the tables taken back, the service role's too.
--
-- Needs beta.sql (beta_applications, beta_inbox). Only additions: three
-- new tables, a private bucket and new functions. Nothing that exists is
-- changed. Applying it again changes nothing.

create table if not exists public.feedback (
    id          bigint      generated always as identity primary key,
    account     uuid        references auth.users (id) on delete cascade,
    email       text        constraint feedback_email check (email is null or (char_length(email) between 3 and 254
                                                              and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')),
    kind        text        not null constraint feedback_kind check (kind in ('bug', 'idea', 'question')),
    words       text        not null constraint feedback_words check (char_length(words) between 1 and 4000),
    source      text        not null constraint feedback_source check (source in ('site', 'app')),
    page        text        constraint feedback_page check (char_length(page) <= 300),
    details     jsonb       not null default '{}'::jsonb
        constraint feedback_details check (jsonb_typeof(details) = 'object' and octet_length(details::text) <= 4000),
    log         text        constraint feedback_log check (char_length(log) <= 20000),
    picture     text        constraint feedback_picture check (picture ~ '^[0-9]{1,18}/picture\.(png|jpg)$'),
    model       text        constraint feedback_model check (model ~ '^[0-9]{1,18}/model\.mpd$'),
    beta        boolean     not null default false,
    test        boolean     not null default false,
    status      text        not null default 'new'
        constraint feedback_status check (status in ('new', 'seen', 'planned', 'fixed', 'wont_fix')),
    note        text        constraint feedback_note check (char_length(note) <= 2000),
    at          timestamptz not null default now(),
    changed_at  timestamptz not null default now(),
    -- Signed in: the account, never its address. Signed out: the address.
    constraint feedback_who check ((account is null) <> (email is null))
);
create index if not exists feedback_listed on public.feedback (test, status, at desc);
create index if not exists feedback_account on public.feedback (account, at desc);

create table if not exists public.feedback_replies (
    id        bigint      generated always as identity primary key,
    feedback  bigint      not null references public.feedback (id) on delete cascade,
    words     text        not null constraint feedback_replies_words check (char_length(words) between 1 and 4000),
    by_email  text        not null constraint feedback_replies_by check (char_length(by_email) between 3 and 320),
    mail      text        not null constraint feedback_replies_mail check (mail in ('sent', 'dry', 'failed')),
    sent_id   text        constraint feedback_replies_sent_id check (sent_id ~ '^[A-Za-z0-9_-]{1,100}$'),
    at        timestamptz not null default now()
);
create index if not exists feedback_replies_of on public.feedback_replies (feedback, at);

create table if not exists public.feedback_tries (
    id   bigint      generated always as identity primary key,
    who  text        not null constraint feedback_tries_who check (char_length(who) between 1 and 300),
    at   timestamptz not null default now()
);
create index if not exists feedback_tries_recent on public.feedback_tries (who, at desc);

alter table public.feedback enable row level security;
alter table public.feedback_replies enable row level security;
alter table public.feedback_tries enable row level security;
revoke all on public.feedback from public, anon, authenticated, service_role;
revoke all on public.feedback_replies from public, anon, authenticated, service_role;
revoke all on public.feedback_tries from public, anon, authenticated, service_role;

-- The pictures and models sent with reports: private, read only by the
-- server with the secret key and shown only to the owner (/api/admin
-- ?op=feedback_file). At most 1.5 MB a file; api/_feedback.js holds the
-- same cap before anything is stored.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('feedback', 'feedback', false, 1572864, array['image/png', 'image/jpeg', 'text/plain'])
on conflict (id) do nothing;

-- Whether [p_account] is a beta tester: its application approved.
create or replace function public.beta_tester(p_account uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_account is not null and exists (
        select 1 from public.beta_applications a where a.account = p_account and a.status = 'approved')
$$;

-- A report as its sender sees it: no note, no address, no log; the answers.
create or replace function public.feedback_own_view(f public.feedback)
returns jsonb
language sql
stable
set search_path = ''
as $$
    select jsonb_build_object(
        'id', f.id, 'kind', f.kind, 'words', f.words, 'source', f.source, 'page', f.page, 'beta', f.beta,
        'status', f.status, 'at', f.at, 'changed_at', f.changed_at,
        'picture', f.picture is not null, 'model', f.model is not null,
        'replies', coalesce((select jsonb_agg(jsonb_build_object('words', r.words, 'at', r.at) order by r.at, r.id)
                               from public.feedback_replies r where r.feedback = f.id), '[]'::jsonb))
$$;

-- A report as the owner sees it: everything, with the address it is
-- answered at (the account's now, or the one given) and every answer.
create or replace function public.feedback_owner_view(f public.feedback)
returns jsonb
language sql
stable
set search_path = ''
as $$
    select jsonb_build_object(
        'id', f.id, 'kind', f.kind, 'words', f.words, 'source', f.source, 'page', f.page, 'details', f.details,
        'log', f.log, 'picture', f.picture, 'model', f.model, 'beta', f.beta, 'test', f.test,
        'status', f.status, 'note', f.note, 'at', f.at, 'changed_at', f.changed_at,
        'account', f.account, 'signed_in', f.account is not null,
        'email', coalesce(f.email, (select u.email from auth.users u where u.id = f.account)),
        'replies', coalesce((select jsonb_agg(jsonb_build_object('words', r.words, 'by', r.by_email, 'mail', r.mail,
                                                                 'sent_id', r.sent_id, 'at', r.at) order by r.at, r.id)
                               from public.feedback_replies r where r.feedback = f.id), '[]'::jsonb))
$$;

-- A report, as the server checked it (api/_feedback.js reportOf), from
-- [p_account] or, signed out, from [p_email], sent from [p_place] (a key,
-- never an address). {refused: 'nobody' | 'busy'} or {id, beta, test}.
-- The rate, counted here so a refusal costs nothing more: an account ten
-- an hour; signed out, five an hour from one place, three to one inbox,
-- and sixty an hour from everyone signed out together. Tries older than a
-- day go.
create or replace function public.feedback_send(p_account uuid, p_email text, p_kind text, p_words text,
    p_source text, p_page text, p_details jsonb, p_log text, p_place text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    address text;
    keys text[];
    made public.feedback%rowtype;
begin
    delete from public.feedback_tries t where t.at < now() - interval '1 day';
    if p_account is not null then
        select u.email into address from auth.users u where u.id = p_account;
        if not found then
            return jsonb_build_object('refused', 'nobody');
        end if;
        keys := array['account:' || p_account::text];
        if (select count(*) from public.feedback_tries t
             where t.who = keys[1] and t.at >= now() - interval '1 hour') >= 10 then
            return jsonb_build_object('refused', 'busy');
        end if;
    else
        address := lower(btrim(coalesce(p_email, '')));
        keys := array['place:' || coalesce(p_place, ''), 'inbox:' || public.beta_inbox(address), 'signed_out'];
        if (select count(*) from public.feedback_tries t
             where t.who = keys[1] and t.at >= now() - interval '1 hour') >= 5
           or (select count(*) from public.feedback_tries t
                where t.who = keys[2] and t.at >= now() - interval '1 hour') >= 3
           or (select count(*) from public.feedback_tries t
                where t.who = keys[3] and t.at >= now() - interval '1 hour') >= 60 then
            return jsonb_build_object('refused', 'busy');
        end if;
    end if;
    insert into public.feedback_tries (who) select unnest(keys);
    insert into public.feedback (account, email, kind, words, source, page, details, log, beta, test)
    values (p_account, case when p_account is null then address end, p_kind, p_words, p_source, nullif(p_page, ''),
            coalesce(p_details, '{}'::jsonb), nullif(p_log, ''), public.beta_tester(p_account),
            lower(coalesce(address, '')) ~ '@resend\.dev$')
    returning * into made;
    return jsonb_build_object('id', made.id, 'beta', made.beta, 'test', made.test);
end;
$$;

-- The files stored for report [p_id] once they are in the bucket: its
-- picture's name and its model's (null: none). True when the report is there.
create or replace function public.feedback_files(p_id bigint, p_picture text, p_model text)
returns boolean
language sql
security definer
set search_path = ''
as $$
    with done as (
        update public.feedback f set picture = p_picture, model = p_model where f.id = p_id returning 1
    )
    select exists (select 1 from done)
$$;

-- [p_account]'s own reports, newest first, with where each stands and the
-- answers: {reports, beta}.
create or replace function public.feedback_mine(p_account uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object(
        'beta', public.beta_tester(p_account),
        'reports', coalesce((select jsonb_agg(public.feedback_own_view(f) order by f.at desc, f.id desc)
                               from public.feedback f
                              where f.id in (select x.id from public.feedback x where x.account = p_account
                                              order by x.at desc, x.id desc limit 200)), '[]'::jsonb))
$$;

-- The owner's inbox: reports of [p_kind] ('bug', 'idea', 'question', null
-- for all), from testers or not [p_beta] (null for both), standing at
-- [p_status] (null for all; 'open' for new, seen and planned), the checks'
-- own for [p_tests] (theirs alone), newest first, at most [p_limit] (1 to
-- 500); and how many stand at each status, of every kind.
create or replace function public.feedback_inbox(p_kind text, p_beta boolean, p_status text, p_tests boolean,
    p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    with mine as (
        select f.status, f.beta from public.feedback f where f.test = coalesce(p_tests, false)
    ), listed as (
        select f.id from public.feedback f
         where f.test = coalesce(p_tests, false)
           and (p_kind is null or f.kind = p_kind)
           and (p_beta is null or f.beta = p_beta)
           and (p_status is null or f.status = p_status
                or (p_status = 'open' and f.status in ('new', 'seen', 'planned')))
         order by f.at desc, f.id desc
         limit greatest(1, least(coalesce(p_limit, 200), 500))
    )
    select jsonb_build_object(
        'counts', (select jsonb_build_object(
                       'new', count(*) filter (where status = 'new'),
                       'seen', count(*) filter (where status = 'seen'),
                       'planned', count(*) filter (where status = 'planned'),
                       'fixed', count(*) filter (where status = 'fixed'),
                       'wont_fix', count(*) filter (where status = 'wont_fix'),
                       'beta', count(*) filter (where beta),
                       'all', count(*)) from mine),
        'reports', coalesce((select jsonb_agg(public.feedback_owner_view(f) order by f.at desc, f.id desc)
                               from public.feedback f where f.id in (select l.id from listed l)), '[]'::jsonb))
$$;

-- Report [p_id] as the owner sees it, or null.
create or replace function public.feedback_one(p_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select public.feedback_owner_view(f) from public.feedback f where f.id = p_id
$$;

-- Where report [p_id] stands, [p_status] (null: as it was), and the
-- owner's note, [p_note] (null: as it was; '' takes it away). The report
-- as the owner sees it, or {refused: 'none'}.
create or replace function public.feedback_triage(p_id bigint, p_status text, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    f public.feedback%rowtype;
begin
    update public.feedback x
       set status = coalesce(p_status, x.status),
           note = case when p_note is null then x.note else nullif(p_note, '') end,
           changed_at = case when p_status is not null and p_status <> x.status then now() else x.changed_at end
     where x.id = p_id
    returning * into f;
    if not found then
        return jsonb_build_object('refused', 'none');
    end if;
    return public.feedback_owner_view(f);
end;
$$;

-- An answer to report [p_id], as sent ([p_mail], Resend's [p_sent_id]):
-- kept, and a new report marked seen. The report as the owner sees it, or
-- {refused: 'none'}.
create or replace function public.feedback_reply(p_id bigint, p_words text, p_by text, p_mail text, p_sent_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    f public.feedback%rowtype;
begin
    select * into f from public.feedback x where x.id = p_id for update;
    if not found then
        return jsonb_build_object('refused', 'none');
    end if;
    insert into public.feedback_replies (feedback, words, by_email, mail, sent_id)
    values (p_id, p_words, p_by, p_mail, p_sent_id);
    update public.feedback x set status = case when x.status = 'new' then 'seen' else x.status end,
                                 changed_at = now()
     where x.id = p_id
    returning * into f;
    return public.feedback_owner_view(f);
end;
$$;

-- The names of the files [p_account]'s reports keep in the bucket, so
-- deleting the account deletes them first: [name].
create or replace function public.feedback_files_of(p_account uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(n), '[]'::jsonb) from (
        select f.picture as n from public.feedback f where f.account = p_account and f.picture is not null
        union all
        select f.model from public.feedback f where f.account = p_account and f.model is not null
    ) x
$$;

-- Reports erased: one sent signed out, or closed (fixed or won't fix), a
-- year after it last changed; the checks' own after a day. {erased, files:
-- [the names of their files, for the server to delete]}.
create or replace function public.feedback_sweep()
returns jsonb
language sql
security definer
set search_path = ''
as $$
    with gone as (
        delete from public.feedback f
         where (f.test and f.at < now() - interval '1 day')
            or ((f.account is null or f.status in ('fixed', 'wont_fix')) and f.changed_at < now() - interval '365 days')
        returning f.picture, f.model
    )
    select jsonb_build_object(
        'erased', (select count(*) from gone),
        'files', coalesce((select jsonb_agg(n) from (select picture as n from gone where picture is not null
                                                    union all
                                                    select model from gone where model is not null) x), '[]'::jsonb))
$$;

revoke all on function public.beta_tester(uuid) from public, anon, authenticated;
revoke all on function public.feedback_own_view(public.feedback) from public, anon, authenticated;
revoke all on function public.feedback_owner_view(public.feedback) from public, anon, authenticated;
revoke all on function public.feedback_send(uuid, text, text, text, text, text, jsonb, text, text)
    from public, anon, authenticated;
revoke all on function public.feedback_files(bigint, text, text) from public, anon, authenticated;
revoke all on function public.feedback_mine(uuid) from public, anon, authenticated;
revoke all on function public.feedback_inbox(text, boolean, text, boolean, integer) from public, anon, authenticated;
revoke all on function public.feedback_one(bigint) from public, anon, authenticated;
revoke all on function public.feedback_triage(bigint, text, text) from public, anon, authenticated;
revoke all on function public.feedback_reply(bigint, text, text, text, text) from public, anon, authenticated;
revoke all on function public.feedback_files_of(uuid) from public, anon, authenticated;
revoke all on function public.feedback_sweep() from public, anon, authenticated;
grant execute on function public.beta_tester(uuid) to service_role;
grant execute on function public.feedback_send(uuid, text, text, text, text, text, jsonb, text, text) to service_role;
grant execute on function public.feedback_files(bigint, text, text) to service_role;
grant execute on function public.feedback_mine(uuid) to service_role;
grant execute on function public.feedback_inbox(text, boolean, text, boolean, integer) to service_role;
grant execute on function public.feedback_one(bigint) to service_role;
grant execute on function public.feedback_triage(bigint, text, text) to service_role;
grant execute on function public.feedback_reply(bigint, text, text, text, text) to service_role;
grant execute on function public.feedback_files_of(uuid) to service_role;
grant execute on function public.feedback_sweep() to service_role;

notify pgrst, 'reload schema';
