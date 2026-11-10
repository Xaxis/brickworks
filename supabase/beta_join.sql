-- Joining the beta is a step of signing up (betajoin, 2026-11-09).
--
-- The owner: "signup for beta testing (which should probably just be part
-- of the main signup flow)". While the beta is open, a new account sees one
-- short welcome right after its code is accepted, on the site and in the
-- app: Join the beta testers, or Not now. Joining is instant: the account
-- is a tester at once, with no approval, and may leave again from Settings
-- in one press. The month of Pro is unchanged (beta.sql): the first 100,
-- each approved by the owner from the queue, given at Admission when
-- billing is live. The application form becomes "tell us about you" after
-- joining (web/beta.html): optional, never a gate to being a tester.
--
--   beta_testers   one row an account that has answered (deleted with it):
--                  'tester' (joined, and when, from where, under which
--                  version of the beta's terms), 'not_now' (said no to the
--                  welcome and never joined) or 'left' (joined, then left).
--                  No row: never asked, or asked and not answered.
--
-- A tester is an account whose row says 'tester'; an account with no row
-- whose application was approved is one too, as it was before this file
-- (feedback.sql's beta_tester, replaced here: supabase/later.tsv). Every
-- application made before this file that was not declined is a tester from
-- it on: under the old way an application asked to be one.
--
-- The welcome is due (beta_member's welcome) for an account with no row, no
-- application, made in the last seven days: an existing account joins from
-- Settings, the homepage or the beta hub instead. The server adds whether
-- the beta is open (api/_beta.js betaMode).
--
-- Only the server touches any of it (api/_beta.js, with the secret key),
-- through the functions below, each security definer and granted to the
-- service role alone. Row security on, no policy, and every grant on the
-- table taken back (client_exposure() stays empty).
--
-- Only additions: a new table and new functions, and beta_tester replaced
-- with one that says yes to every account it said yes to before. Needs
-- beta.sql. Applying it again changes nothing.

create table if not exists public.beta_testers (
    account    uuid        primary key references auth.users (id) on delete cascade,
    state      text        not null constraint beta_testers_state check (state in ('tester', 'not_now', 'left')),
    joined_at  timestamptz,
    via        text        not null default 'site' constraint beta_testers_via check (via ~ '^[a-z_]{1,16}$'),
    terms      text        constraint beta_testers_terms check (terms ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
    said_at    timestamptz not null default now(),
    constraint beta_testers_joined check (state = 'not_now' or (joined_at is not null and terms is not null))
);
create index if not exists beta_testers_listed on public.beta_testers (state, joined_at);

alter table public.beta_testers enable row level security;
revoke all on public.beta_testers from public, anon, authenticated, service_role;

-- Every application not declined was a request to be a tester: a tester
-- from here, since it applied, under the terms it agreed to.
insert into public.beta_testers (account, state, joined_at, via, terms, said_at)
select a.account, 'tester', a.applied_at, 'application', a.terms, a.applied_at
  from public.beta_applications a
 where a.status <> 'declined'
on conflict (account) do nothing;

-- Whether [p_account] is a beta tester: its row says so, or, with no row,
-- its application was approved (an approval from before this file).
create or replace function public.beta_tester(p_account uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_account is not null and coalesce(
        (select t.state = 'tester' from public.beta_testers t where t.account = p_account),
        exists (select 1 from public.beta_applications a where a.account = p_account and a.status = 'approved'))
$$;

-- Where [p_account] stands with the beta's testers: {tester, state
-- ('tester', 'not_now', 'left', or null for no answer), joined_at (a
-- tester's, else null), via, welcome (the welcome is due: no answer, no
-- application, made in the last seven days)}.
create or replace function public.beta_member(p_account uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce((
        select jsonb_build_object(
            'tester', public.beta_tester(u.id),
            'state', coalesce(t.state, case when a.status = 'approved' then 'tester' end),
            'joined_at', case when t.state = 'tester' then t.joined_at
                              when t.account is null and a.status = 'approved' then a.applied_at end,
            'via', case when t.state = 'tester' then t.via end,
            'welcome', t.account is null and a.account is null and u.created_at > now() - interval '7 days')
          from auth.users u
          left join public.beta_testers t on t.account = u.id
          left join public.beta_applications a on a.account = u.id
         where u.id = p_account),
        jsonb_build_object('tester', false, 'state', null, 'joined_at', null, 'via', null, 'welcome', false))
$$;

-- [p_account] made a tester, now, from [p_via] (where the press was: the
-- welcome on the site or in the app, Settings, the homepage, the beta hub),
-- under the beta's terms of [p_terms]. Joining again changes nothing; a
-- tester who left joins again from now. {refused: 'nobody'} or beta_member.
create or replace function public.beta_join(p_account uuid, p_via text, p_terms text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not exists (select 1 from auth.users u where u.id = p_account) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    insert into public.beta_testers as t (account, state, joined_at, via, terms, said_at)
    values (p_account, 'tester', now(), p_via, p_terms, now())
    on conflict (account) do update
       set state = 'tester',
           joined_at = case when t.state = 'tester' then t.joined_at else now() end,
           via = case when t.state = 'tester' then t.via else excluded.via end,
           terms = case when t.state = 'tester' then t.terms else excluded.terms end,
           said_at = case when t.state = 'tester' then t.said_at else now() end;
    return public.beta_member(p_account);
end;
$$;

-- [p_account] not a tester: a tester leaves ('left'), anybody else has said
-- Not now ('not_now'), and the welcome is never due again. An application
-- and its month are left as they are: leaving changes nothing about money.
-- {refused: 'nobody'} or beta_member.
create or replace function public.beta_leave(p_account uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    was boolean;
begin
    if not exists (select 1 from auth.users u where u.id = p_account) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    was := public.beta_tester(p_account);
    insert into public.beta_testers as t (account, state, joined_at, via, terms, said_at)
    select p_account, case when was then 'left' else 'not_now' end,
           case when was then coalesce(x.joined_at, a.applied_at) end,
           coalesce(x.via, case when a.account is not null then 'application' else 'site' end),
           case when was then coalesce(x.terms, a.terms) end, now()
      from (select 1) one
      left join public.beta_testers x on x.account = p_account
      left join public.beta_applications a on a.account = p_account
    on conflict (account) do update
       set state = case when t.state = 'tester' then 'left' else t.state end,
           said_at = case when t.state = 'tester' then now() else t.said_at end;
    return public.beta_member(p_account);
end;
$$;

-- The owner's list of the testers of the 100's pool, or the checks'
-- (accounts at resend.dev) for [p_tests]: {counts: {testers, not_now, left,
-- welcome, application}, testers: [{account, email, state, joined_at, via,
-- said_at, made_at, application: {status, spot, comp} or null}]}, at most
-- [p_limit] (1 to 1000), testers first by when they joined, newest first,
-- then those who left, then those who said Not now.
create or replace function public.beta_testers_list(p_tests boolean, p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    with rows as (
        select t.*, u.email, u.created_at as made_at,
               a.status as app_status, a.spot as app_spot, a.comp as app_comp
          from public.beta_testers t
          join auth.users u on u.id = t.account
          left join public.beta_applications a on a.account = t.account
         where (lower(coalesce(u.email, '')) ~ '@resend\.dev$') = coalesce(p_tests, false)
    ), listed as (
        select r.*, row_number() over (order by case r.state when 'tester' then 0 when 'left' then 1 else 2 end,
                                                r.joined_at desc nulls last, r.said_at desc, r.account) as place
          from rows r
    )
    select jsonb_build_object(
        'counts', jsonb_build_object(
            'testers', (select count(*) from rows where state = 'tester'),
            'left', (select count(*) from rows where state = 'left'),
            'not_now', (select count(*) from rows where state = 'not_now'),
            'welcome', (select count(*) from rows where state = 'tester' and via in ('welcome', 'app')),
            'application', (select count(*) from rows where state = 'tester' and app_status is not null)),
        'testers', coalesce((select jsonb_agg(jsonb_build_object(
            'account', l.account, 'email', l.email, 'state', l.state, 'joined_at', l.joined_at, 'via', l.via,
            'said_at', l.said_at, 'made_at', l.made_at,
            'application', case when l.app_status is not null then jsonb_build_object('status', l.app_status,
                                    'spot', l.app_spot, 'comp', l.app_comp) end) order by l.place)
            from listed l where l.place <= greatest(1, least(coalesce(p_limit, 500), 1000))), '[]'::jsonb))
$$;

revoke all on function public.beta_tester(uuid) from public, anon, authenticated;
revoke all on function public.beta_member(uuid) from public, anon, authenticated;
revoke all on function public.beta_join(uuid, text, text) from public, anon, authenticated;
revoke all on function public.beta_leave(uuid) from public, anon, authenticated;
revoke all on function public.beta_testers_list(boolean, integer) from public, anon, authenticated;
grant execute on function public.beta_tester(uuid) to service_role;
grant execute on function public.beta_member(uuid) to service_role;
grant execute on function public.beta_join(uuid, text, text) to service_role;
grant execute on function public.beta_leave(uuid) to service_role;
grant execute on function public.beta_testers_list(boolean, integer) to service_role;

notify pgrst, 'reload schema';
