-- The beta: 100 testers, each given a month of Pro, 2026-10-29 (beta361).
--
-- The owner: "a 'beta tester' signup that lightly vets people so that we
-- can say have a 'beta promotion' where say the first 100 beta/user
-- signups get a free month". A signed-in person applies once, on /beta
-- (web/beta.html, api/plans.js ?op=beta); the owner reads each application
-- with what the server found about it (web/beta-admin.html, api/admin.js
-- ?op=beta) and approves or declines it. An approval takes the next of the
-- 100 spots, and its month of Pro is given at Admission (api/_beta.js).
--
--   beta_pools         how many spots a pool has (cap) and how many are
--                      given: 'beta', the 100, and 'test', the site's own
--                      checks' (accounts at resend.dev), so no check ever
--                      takes a real spot. A spot given is spent: an
--                      approved tester who deletes their account does not
--                      give theirs back.
--   beta_applications  one an account (deleted with it): what the form
--                      said, what the server found (signals), where it
--                      stands (new, waitlist, approved, declined), its spot
--                      and its month. A declined one may be made again
--                      after 30 days, and is erased 90 days after it was
--                      declined (beta_sweep).
--   beta_decisions     every approval and decline: who, when, the note.
--   beta_mail          every email the beta sent an account: its kind,
--                      whether it went (sent, dry for a test inbox where
--                      this server has no mail key, failed), Resend's id.
--
-- Spots are given in approval order by one step, under the pool's row
-- lock: every decision of a pool waits for the one before it, then
-- "given = given + 1 where given < cap". Two approvals at once at 99 give
-- spot 100 to one and refuse the other; nothing passes the cap (a check),
-- and no two share a spot (a unique constraint). When the last spot goes,
-- the pool's new applications are moved to the waitlist, and one made
-- after it starts there: the owner widens the pool by raising its cap.
--
-- An account made before 29 October 2026 (midnight in California, 07:00
-- UTC) has Pro with no end date already (web/plans.html). It may join as a
-- tester, and is approved without a spot: early, never one of the 100.
--
-- Its email address is never copied here: the server reads it from the
-- account when it writes, so an application can never outlive or
-- disagree with its account. No IP address is kept.
--
-- Only the server touches any of it (api/_beta.js, with the secret key),
-- through the functions below, each security definer and granted to the
-- service role alone. Row security on, no policy, and every grant on the
-- tables taken back, the service role's too (client_exposure() stays
-- empty).
--
-- Only additions: four new tables and new functions. Nothing that exists
-- is changed. Applying it again changes nothing.

create table if not exists public.beta_pools (
    pool   text    primary key constraint beta_pools_pool check (pool in ('beta', 'test')),
    cap    integer not null constraint beta_pools_cap check (cap between 0 and 1000),
    given  integer not null default 0,
    constraint beta_pools_given check (given between 0 and cap)
);
insert into public.beta_pools (pool, cap) values ('beta', 100), ('test', 100) on conflict (pool) do nothing;

create table if not exists public.beta_applications (
    account          uuid        primary key references auth.users (id) on delete cascade,
    pool             text        not null references public.beta_pools (pool),
    status           text        not null default 'new'
        constraint beta_applications_status check (status in ('new', 'waitlist', 'approved', 'declined')),
    build            text        not null constraint beta_applications_build check (char_length(build) between 20 and 800),
    ai               text        not null
        constraint beta_applications_ai check (ai in ('claude', 'chatgpt', 'own_key', 'not_sure')),
    background       text        not null
        constraint beta_applications_background check (background in ('new', 'lego', 'cad', 'both')),
    background_line  text        not null default ''
        constraint beta_applications_background_line check (char_length(background_line) <= 160),
    link             text
        constraint beta_applications_link check (link is null or (char_length(link) between 12 and 300 and link ~ '^https://')),
    terms            text        not null constraint beta_applications_terms check (terms ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
    signals          jsonb       not null default '{}'::jsonb
        constraint beta_applications_signals check (jsonb_typeof(signals) = 'object' and octet_length(signals::text) <= 4000),
    early            boolean     not null default false,
    applied_at       timestamptz not null default now(),
    decided_at       timestamptz,
    decided_by       text        constraint beta_applications_decided_by check (char_length(decided_by) <= 320),
    note             text        constraint beta_applications_note check (char_length(note) <= 500),
    spot             integer     constraint beta_applications_spot check (spot between 1 and 1000),
    comp             text        not null default 'none'
        constraint beta_applications_comp check (comp in ('none', 'pending', 'granted')),
    comp_said        text        constraint beta_applications_comp_said check (char_length(comp_said) <= 300),
    month_starts_at  timestamptz,
    month_ends_at    timestamptz,
    reminded_at      timestamptz,
    constraint beta_applications_spot_once unique (pool, spot),
    constraint beta_applications_spot_approved check (spot is null or status = 'approved'),
    constraint beta_applications_early_spot check (not early or spot is null),
    constraint beta_applications_month check (month_ends_at is null or month_ends_at > month_starts_at)
);
create index if not exists beta_applications_queue on public.beta_applications (pool, status, applied_at);

create table if not exists public.beta_decisions (
    id        bigint      generated always as identity primary key,
    account   uuid        not null references auth.users (id) on delete cascade,
    decision  text        not null constraint beta_decisions_decision check (decision in ('approved', 'declined')),
    note      text        constraint beta_decisions_note check (char_length(note) <= 500),
    by_email  text        not null constraint beta_decisions_by check (char_length(by_email) between 3 and 320),
    at        timestamptz not null default now()
);
create index if not exists beta_decisions_account on public.beta_decisions (account, at);

create table if not exists public.beta_mail (
    id       bigint      generated always as identity primary key,
    account  uuid        not null references auth.users (id) on delete cascade,
    kind     text        not null
        constraint beta_mail_kind check (kind in ('received', 'approved', 'declined', 'started', 'reminder')),
    state    text        not null constraint beta_mail_state check (state in ('sent', 'dry', 'failed')),
    sent_id  text        constraint beta_mail_sent_id check (sent_id ~ '^[A-Za-z0-9_-]{1,100}$'),
    subject  text        not null constraint beta_mail_subject check (char_length(subject) between 1 and 200),
    at       timestamptz not null default now()
);
create index if not exists beta_mail_account on public.beta_mail (account, at);

alter table public.beta_pools enable row level security;
alter table public.beta_applications enable row level security;
alter table public.beta_decisions enable row level security;
alter table public.beta_mail enable row level security;
revoke all on public.beta_pools from public, anon, authenticated, service_role;
revoke all on public.beta_applications from public, anon, authenticated, service_role;
revoke all on public.beta_decisions from public, anon, authenticated, service_role;
revoke all on public.beta_mail from public, anon, authenticated, service_role;

-- An address as one inbox has it: lower case, its +tag gone, and for
-- Gmail its dots too (googlemail.com is gmail.com), so two accounts at one
-- inbox are found out.
create or replace function public.beta_inbox(p_email text)
returns text
language sql
immutable
set search_path = ''
as $$
    select case when split_part(e, '@', 2) in ('gmail.com', 'googlemail.com')
                then replace(split_part(split_part(e, '@', 1), '+', 1), '.', '') || '@gmail.com'
                else split_part(split_part(e, '@', 1), '+', 1) || '@' || split_part(e, '@', 2) end
      from (select lower(btrim(coalesce(p_email, ''))) as e) x
$$;

-- Whether an account made at [p_made] is one of those with Pro and no end
-- date (web/plans.html): made before 29 October 2026, in California.
create or replace function public.beta_early(p_made timestamptz)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select p_made < timestamptz '2026-10-29 07:00:00+00'
$$;

-- A pool's spots: {pool, cap, given, left}.
create or replace function public.beta_pool_view(p_pool text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object('pool', p.pool, 'cap', p.cap, 'given', p.given, 'left', greatest(p.cap - p.given, 0))
      from public.beta_pools p where p.pool = p_pool
$$;

-- What [p_account] sees of its own application: no note, no signals.
create or replace function public.beta_own_view(a public.beta_applications)
returns jsonb
language sql
stable
set search_path = ''
as $$
    select jsonb_build_object(
        'status', a.status, 'pool', a.pool, 'early', a.early, 'spot', a.spot, 'applied_at', a.applied_at,
        'decided_at', a.decided_at, 'comp', a.comp, 'month_starts_at', a.month_starts_at,
        'month_ends_at', a.month_ends_at,
        'may_apply_again_at', case when a.status = 'declined' then a.decided_at + interval '30 days' end)
$$;

-- Where [p_account] stands: {pool (theirs, or the 100 for nobody), early
-- (made before 29 October 2026), test, application (null for none)}.
create or replace function public.beta_status(p_account uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    u record;
    a public.beta_applications%rowtype;
    pool_name text := 'beta';
begin
    if p_account is null then
        return jsonb_build_object('pool', public.beta_pool_view('beta'), 'early', false, 'test', false,
                                  'application', null);
    end if;
    select x.email, x.created_at into u from auth.users x where x.id = p_account;
    if not found then
        return jsonb_build_object('pool', public.beta_pool_view('beta'), 'early', false, 'test', false,
                                  'application', null);
    end if;
    if lower(coalesce(u.email, '')) ~ '@resend\.dev$' then
        pool_name := 'test';
    end if;
    select * into a from public.beta_applications x where x.account = p_account;
    return jsonb_build_object('pool', public.beta_pool_view(pool_name), 'early', public.beta_early(u.created_at),
                              'test', pool_name = 'test',
                              'application', case when found then public.beta_own_view(a) end);
end;
$$;

-- An application from [p_account], as the server checked it (api/_beta.js
-- applicationOf). {refused: 'nobody' | 'applied' | 'too_soon', status} or
-- beta_status with the application made: 'new', or 'waitlist' when its
-- pool's spots are all given (an early account never waits: it takes no
-- spot). A declined application is made again only 30 days after it was
-- declined, in place of the old one.
create or replace function public.beta_apply(p_account uuid, p_build text, p_ai text, p_background text,
    p_background_line text, p_link text, p_terms text, p_signals jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    u record;
    p public.beta_pools%rowtype;
    was public.beta_applications%rowtype;
    pool_name text := 'beta';
    is_early boolean;
begin
    select x.email, x.created_at into u from auth.users x where x.id = p_account;
    if not found then
        return jsonb_build_object('refused', 'nobody');
    end if;
    if lower(coalesce(u.email, '')) ~ '@resend\.dev$' then
        pool_name := 'test';
    end if;
    -- In turn with every decision of the pool, so an application made as the
    -- last spot goes is waitlisted with the others.
    select * into p from public.beta_pools x where x.pool = pool_name for update;
    select * into was from public.beta_applications x where x.account = p_account for update;
    if found then
        if was.status <> 'declined' then
            return jsonb_build_object('refused', 'applied', 'status', was.status);
        end if;
        if was.decided_at > now() - interval '30 days' then
            return jsonb_build_object('refused', 'too_soon', 'status', was.status,
                                      'may_apply_again_at', was.decided_at + interval '30 days');
        end if;
        delete from public.beta_applications x where x.account = p_account;
    end if;
    is_early := public.beta_early(u.created_at);
    insert into public.beta_applications (account, pool, status, build, ai, background, background_line, link,
                                          terms, signals, early)
    values (p_account, pool_name,
            case when not is_early and p.given >= p.cap then 'waitlist' else 'new' end,
            p_build, p_ai, p_background, coalesce(p_background_line, ''), nullif(p_link, ''), p_terms,
            coalesce(p_signals, '{}'::jsonb), is_early);
    return public.beta_status(p_account);
end;
$$;

-- The owner's queue: the pool's counts and its applications of [p_status]
-- ('new', 'waitlist', 'approved', 'declined', or null for all), the test
-- pool's for [p_tests], at most [p_limit] (1 to 500): new first, oldest
-- first; approved by spot. Each with its account's address and what is
-- read of the account now: its address confirmed, its age, its models
-- kept and shared, how many other accounts read as the same inbox and how
-- many of those applied, and the decisions made on it.
create or replace function public.beta_queue(p_status text, p_tests boolean, p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    with pool as (select case when p_tests then 'test' else 'beta' end as name),
    listed as (
        select a.*, u.email, u.created_at as made_at, u.email_confirmed_at, u.last_sign_in_at,
               row_number() over (order by case a.status when 'new' then 0 when 'waitlist' then 1
                                                         when 'approved' then 2 else 3 end,
                                           case when a.status = 'approved' then a.spot end nulls last,
                                           case when a.status in ('new', 'waitlist') then a.applied_at end asc,
                                           a.decided_at desc nulls last, a.account) as place
          from public.beta_applications a
          join auth.users u on u.id = a.account
         where a.pool = (select name from pool)
           and (p_status is null or a.status = p_status)
         order by place
         limit greatest(1, least(coalesce(p_limit, 200), 500))
    )
    select jsonb_build_object(
        'pool', public.beta_pool_view((select name from pool)),
        'counts', (select jsonb_build_object(
                       'new', count(*) filter (where status = 'new'),
                       'waitlist', count(*) filter (where status = 'waitlist'),
                       'approved', count(*) filter (where status = 'approved'),
                       'declined', count(*) filter (where status = 'declined'),
                       'early', count(*) filter (where early and status = 'approved'),
                       'pending', count(*) filter (where comp = 'pending'))
                     from public.beta_applications where pool = (select name from pool)),
        'applications', coalesce((select jsonb_agg(jsonb_build_object(
            'account', l.account, 'email', l.email, 'status', l.status, 'early', l.early, 'spot', l.spot,
            'build', l.build, 'ai', l.ai, 'background', l.background, 'background_line', l.background_line,
            'link', l.link, 'terms', l.terms, 'signals', l.signals, 'applied_at', l.applied_at,
            'decided_at', l.decided_at, 'decided_by', l.decided_by, 'note', l.note, 'comp', l.comp,
            'comp_said', l.comp_said, 'month_starts_at', l.month_starts_at, 'month_ends_at', l.month_ends_at,
            'facts', jsonb_build_object(
                'confirmed', l.email_confirmed_at is not null and l.last_sign_in_at is not null
                             and lower(coalesce(l.email, '')) !~ '@oc\.brickworks\.diy$',
                'made_at', l.made_at,
                'age_days', floor(extract(epoch from now() - l.made_at) / 86400)::integer,
                'models_kept', (select count(*) from public.account_models m where m.owner = l.account),
                'models_shared', (select count(*) from public.shared_models s where s.owner = l.account),
                'same_inbox', (select count(*) from auth.users o
                                where o.id <> l.account and public.beta_inbox(o.email) = public.beta_inbox(l.email)),
                'same_inbox_applied', (select count(*) from auth.users o join public.beta_applications b on b.account = o.id
                                        where o.id <> l.account and public.beta_inbox(o.email) = public.beta_inbox(l.email))),
            'decisions', coalesce((select jsonb_agg(jsonb_build_object('decision', d.decision, 'note', d.note,
                                                                      'by', d.by_email, 'at', d.at) order by d.at)
                                     from public.beta_decisions d where d.account = l.account), '[]'::jsonb))
            order by l.place)
            from listed l), '[]'::jsonb))
$$;

-- The owner's decision on [p_account]'s application: 'approve' or
-- 'decline', with [p_note] and who decided ([p_by], the owner's address).
-- Every decision of a pool in turn, under its row's lock. Approved, an
-- account takes the pool's next spot (none when early), its month
-- 'pending' until Admission gives it (beta_comp_note); with none left it
-- is refused, {refused: 'full'}, and the pool's new applications go to the
-- waitlist, as they do when the last spot is taken. Approving one approved
-- already, or declining one declined, changes nothing ({again: true}); an
-- approved one is never declined ({refused: 'approved'}). Else
-- {application, pool, email, test, again}.
create or replace function public.beta_decide(p_account uuid, p_decision text, p_note text, p_by text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    pool_name text;
    p public.beta_pools%rowtype;
    a public.beta_applications%rowtype;
    n integer;
    who text;
    note_said text := nullif(btrim(coalesce(p_note, '')), '');
begin
    if p_decision not in ('approve', 'decline') then
        raise exception 'beta: approve or decline';
    end if;
    select x.pool into pool_name from public.beta_applications x where x.account = p_account;
    if not found then
        return jsonb_build_object('refused', 'none');
    end if;
    select * into p from public.beta_pools x where x.pool = pool_name for update;
    select * into a from public.beta_applications x where x.account = p_account for update;
    if not found then
        return jsonb_build_object('refused', 'none');
    end if;
    select x.email into who from auth.users x where x.id = p_account;
    if p_decision = 'approve' then
        if a.status = 'approved' then
            return jsonb_build_object('again', true, 'application', public.beta_own_view(a),
                                      'pool', public.beta_pool_view(pool_name), 'email', who, 'test', pool_name = 'test');
        end if;
        if a.early then
            update public.beta_applications x
               set status = 'approved', decided_at = now(), decided_by = p_by, note = note_said
             where x.account = p_account returning * into a;
        else
            -- The one step that gives a spot: the next, and never past the cap.
            update public.beta_pools x set given = x.given + 1
             where x.pool = pool_name and x.given < x.cap returning x.given into n;
            if n is null then
                update public.beta_applications x set status = 'waitlist'
                 where x.pool = pool_name and x.status = 'new' and not x.early;
                return jsonb_build_object('refused', 'full', 'pool', public.beta_pool_view(pool_name));
            end if;
            update public.beta_applications x
               set status = 'approved', spot = n, comp = 'pending', comp_said = null, decided_at = now(),
                   decided_by = p_by, note = note_said
             where x.account = p_account returning * into a;
            if n >= p.cap then
                update public.beta_applications x set status = 'waitlist'
                 where x.pool = pool_name and x.status = 'new' and not x.early;
            end if;
        end if;
        insert into public.beta_decisions (account, decision, note, by_email) values (p_account, 'approved', note_said, p_by);
    else
        if a.status = 'approved' then
            return jsonb_build_object('refused', 'approved', 'application', public.beta_own_view(a));
        end if;
        if a.status = 'declined' then
            return jsonb_build_object('again', true, 'application', public.beta_own_view(a),
                                      'pool', public.beta_pool_view(pool_name), 'email', who, 'test', pool_name = 'test');
        end if;
        update public.beta_applications x
           set status = 'declined', decided_at = now(), decided_by = p_by, note = note_said
         where x.account = p_account returning * into a;
        insert into public.beta_decisions (account, decision, note, by_email) values (p_account, 'declined', note_said, p_by);
    end if;
    return jsonb_build_object('again', false, 'application', public.beta_own_view(a),
                              'pool', public.beta_pool_view(pool_name), 'email', who, 'test', pool_name = 'test');
end;
$$;

-- What Admission did with an approved account's month: 'granted' from
-- [p_starts] to [p_ends], or still 'pending' (until Pro opens, or what
-- Admission said, [p_said], for the owner's queue). A month granted is
-- never made pending again. The application as its owner sees it, or
-- null when there is no approved one.
create or replace function public.beta_comp_note(p_account uuid, p_comp text, p_starts timestamptz,
    p_ends timestamptz, p_said text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    a public.beta_applications%rowtype;
begin
    if p_comp not in ('pending', 'granted') then
        raise exception 'beta: pending or granted';
    end if;
    update public.beta_applications x
       set comp = p_comp,
           comp_said = left(nullif(btrim(coalesce(p_said, '')), ''), 300),
           month_starts_at = case when p_comp = 'granted' then p_starts end,
           month_ends_at = case when p_comp = 'granted' then p_ends end
     where x.account = p_account and x.status = 'approved' and not x.early and x.comp <> 'granted'
     returning * into a;
    if not found then
        select * into a from public.beta_applications x where x.account = p_account and x.status = 'approved';
        if not found then
            return null;
        end if;
    end if;
    return public.beta_own_view(a);
end;
$$;

-- The approved accounts of [p_pool] whose month is still to be given, in
-- spot order, with their addresses: [{account, email, spot}].
create or replace function public.beta_comps_due(p_pool text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(jsonb_build_object('account', a.account, 'email', u.email, 'spot', a.spot)
                              order by a.spot), '[]'::jsonb)
      from public.beta_applications a join auth.users u on u.id = a.account
     where a.pool = p_pool and a.status = 'approved' and not a.early and a.comp = 'pending'
$$;

-- An email the beta sent [p_account], kept: its kind, whether it went, and
-- Resend's id for it.
create or replace function public.beta_mail_note(p_account uuid, p_kind text, p_state text, p_sent_id text,
    p_subject text)
returns void
language sql
security definer
set search_path = ''
as $$
    insert into public.beta_mail (account, kind, state, sent_id, subject)
    select p_account, p_kind, p_state, nullif(p_sent_id, ''), left(p_subject, 200)
     where exists (select 1 from auth.users u where u.id = p_account)
$$;

-- The emails kept for [p_account], newest first: what a check reads.
create or replace function public.beta_mail_of(p_account uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(jsonb_build_object('kind', m.kind, 'state', m.state, 'sent_id', m.sent_id,
                                                 'subject', m.subject, 'at', m.at) order by m.at desc, m.id desc),
                    '[]'::jsonb)
      from public.beta_mail m where m.account = p_account
$$;

-- The months that end within three days and have not been reminded, each
-- marked reminded as it is taken, so two runs at once never send one
-- twice: [{account, email, spot, test, month_ends_at}].
create or replace function public.beta_reminders_due()
returns jsonb
language sql
security definer
set search_path = ''
as $$
    with due as (
        update public.beta_applications a set reminded_at = now()
         where a.status = 'approved' and a.comp = 'granted' and a.reminded_at is null
           and a.month_ends_at > now() and a.month_ends_at <= now() + interval '3 days'
        returning a.account, a.spot, a.pool, a.month_ends_at
    )
    select coalesce(jsonb_agg(jsonb_build_object('account', d.account, 'email', u.email, 'spot', d.spot,
                                                 'test', d.pool = 'test', 'month_ends_at', d.month_ends_at)), '[]'::jsonb)
      from due d join auth.users u on u.id = d.account
$$;

-- Declined applications erased 90 days after they were declined, with
-- their decisions and emails; and what is left of an account that has no
-- application any more, once 90 days old. How many applications went.
create or replace function public.beta_sweep()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    gone integer;
begin
    with old as (
        delete from public.beta_applications a
         where a.status = 'declined' and a.decided_at < now() - interval '90 days'
        returning a.account
    ), decisions as (
        delete from public.beta_decisions d where d.account in (select account from old)
    ), mail as (
        delete from public.beta_mail m where m.account in (select account from old)
    )
    select count(*) into gone from old;
    delete from public.beta_decisions d
     where d.at < now() - interval '90 days'
       and not exists (select 1 from public.beta_applications a where a.account = d.account);
    delete from public.beta_mail m
     where m.at < now() - interval '90 days'
       and not exists (select 1 from public.beta_applications a where a.account = m.account);
    return gone;
end;
$$;

-- The site's checks' own pool set to [p_given] spots given (0 to its cap),
-- and any test application holding a spot past it let go of it, so a check
-- can start from where it needs to (tools/web/beta_flow.mjs). The 'test'
-- pool only, ever.
create or replace function public.beta_test_pool(p_given integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform 1 from public.beta_pools x where x.pool = 'test' for update;
    delete from public.beta_applications a where a.pool = 'test' and a.spot > p_given;
    update public.beta_pools x set given = p_given where x.pool = 'test';
    return public.beta_pool_view('test');
end;
$$;

revoke all on function public.beta_inbox(text) from public, anon, authenticated;
revoke all on function public.beta_early(timestamptz) from public, anon, authenticated;
revoke all on function public.beta_pool_view(text) from public, anon, authenticated;
revoke all on function public.beta_own_view(public.beta_applications) from public, anon, authenticated;
revoke all on function public.beta_status(uuid) from public, anon, authenticated;
revoke all on function public.beta_apply(uuid, text, text, text, text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.beta_queue(text, boolean, integer) from public, anon, authenticated;
revoke all on function public.beta_decide(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.beta_comp_note(uuid, text, timestamptz, timestamptz, text) from public, anon, authenticated;
revoke all on function public.beta_comps_due(text) from public, anon, authenticated;
revoke all on function public.beta_mail_note(uuid, text, text, text, text) from public, anon, authenticated;
revoke all on function public.beta_mail_of(uuid) from public, anon, authenticated;
revoke all on function public.beta_reminders_due() from public, anon, authenticated;
revoke all on function public.beta_sweep() from public, anon, authenticated;
revoke all on function public.beta_test_pool(integer) from public, anon, authenticated;
grant execute on function public.beta_status(uuid) to service_role;
grant execute on function public.beta_apply(uuid, text, text, text, text, text, text, jsonb) to service_role;
grant execute on function public.beta_queue(text, boolean, integer) to service_role;
grant execute on function public.beta_decide(uuid, text, text, text) to service_role;
grant execute on function public.beta_comp_note(uuid, text, timestamptz, timestamptz, text) to service_role;
grant execute on function public.beta_comps_due(text) to service_role;
grant execute on function public.beta_mail_note(uuid, text, text, text, text) to service_role;
grant execute on function public.beta_mail_of(uuid) to service_role;
grant execute on function public.beta_reminders_due() to service_role;
grant execute on function public.beta_sweep() to service_role;
grant execute on function public.beta_test_pool(integer) to service_role;

notify pgrst, 'reload schema';
