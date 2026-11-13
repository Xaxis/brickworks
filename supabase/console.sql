-- The owner's console (console1, 2026-11-12; docs/ADMIN.md): what /admin
-- keeps of its own.
--
-- The owner: "a cohesive admin interface (for me) with a highly organized
-- ui/ux where I can manage ALL aspects of our system". Two things the
-- console needs that nothing kept before:
--
--   site_settings  a switch the owner flips from the console, one row a
--                  name and a scope: 'live' (brickworks.diy) or one
--                  deployment's own address, so a preview's check flips
--                  its preview and never the site. No row: the project's
--                  setting (the beta's is BRICKWORKS_BETA, api/_beta.js
--                  betaMode, which reads this and nothing else does).
--   admin_audit    every act of the owner's from the console (api/admin.js),
--                  one row each, whatever came of it: who (the address and
--                  the account), what (the op), on what (a model, an
--                  account, a report, a comment...), when, what was asked,
--                  the answer's status and, refused, why. A test's act
--                  (?tests=1, or on a test account) is marked, and the
--                  console shows those only when asked.
--
-- And one act the queue lacked: an application put on the waitlist by
-- hand (beta_waitlist), from New only, with a note; no spot, no email.
-- Approve and Decline (beta.sql beta_decide) work from the waitlist as
-- from New. It is kept in the audit, since beta_decisions holds approvals
-- and declines alone.
--
-- Only the server touches any of it (api/admin.js and api/_beta.js, with
-- the secret key), through the functions below, each security definer and
-- granted to the service role alone. Row security on, no policy, and every
-- grant on the tables taken back, the service role's too (client_exposure()
-- stays empty).
--
-- And what mail was kept as sent (admin_mail_counts), for the Overview.
--
-- Only additions: two new tables and new functions. Needs beta.sql (for
-- beta_waitlist) and feedback.sql (admin_mail_counts). Nothing that
-- exists is changed. Applying it again changes nothing.

create table if not exists public.site_settings (
    name    text        not null constraint site_settings_name check (name ~ '^[a-z_]{1,40}$'),
    scope   text        not null constraint site_settings_scope check (scope ~ '^[a-z0-9.:-]{1,200}$'),
    value   text        not null constraint site_settings_value check (char_length(value) between 1 and 200),
    set_by  text        not null constraint site_settings_set_by check (char_length(set_by) between 1 and 320),
    set_at  timestamptz not null default now(),
    primary key (name, scope)
);

create table if not exists public.admin_audit (
    id             bigint      generated always as identity primary key,
    at             timestamptz not null default now(),
    actor          text        not null constraint admin_audit_actor check (char_length(actor) between 1 and 320),
    actor_account  uuid        references auth.users (id) on delete set null,
    op             text        not null constraint admin_audit_op check (op ~ '^[a-z_]{1,40}$'),
    target_kind    text        constraint admin_audit_target_kind check (target_kind ~ '^[a-z_]{1,24}$'),
    target         text        constraint admin_audit_target check (char_length(target) between 1 and 200),
    detail         jsonb       not null default '{}'::jsonb
        constraint admin_audit_detail check (jsonb_typeof(detail) = 'object' and octet_length(detail::text) <= 4000),
    status         integer     not null constraint admin_audit_status check (status between 100 and 599),
    said           text        constraint admin_audit_said check (char_length(said) <= 300),
    test           boolean     not null default false,
    scope          text        not null default 'live' constraint admin_audit_scope check (scope ~ '^[a-z0-9.:-]{1,200}$')
);
create index if not exists admin_audit_newest on public.admin_audit (test, id desc);
create index if not exists admin_audit_on on public.admin_audit (target_kind, target, id desc);

alter table public.site_settings enable row level security;
alter table public.admin_audit enable row level security;
revoke all on public.site_settings from public, anon, authenticated, service_role;
revoke all on public.admin_audit from public, anon, authenticated, service_role;

-- [p_name] in [p_scope]: {value, set_by, set_at}, or null when it was never
-- set there (the project's setting stands).
create or replace function public.site_setting(p_name text, p_scope text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object('value', s.value, 'set_by', s.set_by, 'set_at', s.set_at)
      from public.site_settings s where s.name = p_name and s.scope = p_scope
$$;

-- [p_name] in [p_scope] set to [p_value] by [p_by]: {value, set_by, set_at,
-- was} (was: the value before, null for none).
create or replace function public.site_setting_set(p_name text, p_scope text, p_value text, p_by text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    before text;
    s public.site_settings%rowtype;
begin
    select x.value into before from public.site_settings x where x.name = p_name and x.scope = p_scope for update;
    insert into public.site_settings (name, scope, value, set_by) values (p_name, p_scope, p_value, p_by)
    on conflict (name, scope) do update set value = excluded.value, set_by = excluded.set_by, set_at = now()
    returning * into s;
    return jsonb_build_object('value', s.value, 'set_by', s.set_by, 'set_at', s.set_at, 'was', before);
end;
$$;

-- One act of the owner's kept: its id.
create or replace function public.admin_audit_note(p_actor text, p_account uuid, p_op text, p_kind text, p_target text,
                                                   p_detail jsonb, p_status integer, p_said text, p_test boolean,
                                                   p_scope text)
returns bigint
language sql
security definer
set search_path = ''
as $$
    insert into public.admin_audit (actor, actor_account, op, target_kind, target, detail, status, said, test, scope)
    values (left(p_actor, 320),
            (select u.id from auth.users u where u.id = p_account),
            p_op, nullif(p_kind, ''), nullif(left(p_target, 200), ''), coalesce(p_detail, '{}'::jsonb), p_status,
            nullif(left(p_said, 300), ''), coalesce(p_test, false), coalesce(nullif(p_scope, ''), 'live'))
    returning id
$$;

-- The acts kept, newest first: [p_limit] (1 to 200) before id [p_before]
-- (null: from the newest), the tests' for [p_tests] and the rest without,
-- only [p_op] when named, only those on [p_kind] [p_target] when named, and
-- only those whose op, target, actor or detail holds [p_query]. Each with
-- the address of the account it was on, when it was one.
-- {rows: [...], more: whether there are older ones}.
create or replace function public.admin_audit_list(p_before bigint, p_limit integer, p_tests boolean, p_op text,
                                                   p_kind text, p_target text, p_query text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    with wanted as (
        select a.*
          from public.admin_audit a
         where a.test = coalesce(p_tests, false)
           and (p_before is null or a.id < p_before)
           and (nullif(p_op, '') is null or a.op = p_op)
           and (nullif(p_kind, '') is null or a.target_kind = p_kind)
           and (nullif(p_target, '') is null or a.target = p_target)
           and (nullif(p_query, '') is null
                or position(lower(p_query) in lower(a.op || ' ' || coalesce(a.target, '') || ' ' || a.actor || ' '
                                                    || a.detail::text || ' ' || coalesce(a.said, ''))) > 0)
         order by a.id desc
         limit greatest(1, least(coalesce(p_limit, 50), 200)) + 1
    ), numbered as (
        select w.*, row_number() over (order by w.id desc) as place from wanted w
    )
    select jsonb_build_object(
        'rows', coalesce((select jsonb_agg(jsonb_build_object(
            'id', n.id, 'at', n.at, 'actor', n.actor, 'op', n.op, 'target_kind', n.target_kind, 'target', n.target,
            'detail', n.detail, 'status', n.status, 'said', n.said, 'test', n.test, 'scope', n.scope,
            'email', case when n.target_kind = 'account' then (select u.email from auth.users u where u.id::text = n.target) end)
            order by n.id desc)
            from numbered n where n.place <= greatest(1, least(coalesce(p_limit, 50), 200))), '[]'::jsonb),
        'more', (select count(*) from wanted) > greatest(1, least(coalesce(p_limit, 50), 200)))
$$;

-- [p_account]'s application put on the waitlist by hand, with [p_note], by
-- [p_by]: from New only. {application} as its owner sees it; or {refused:
-- 'none'} with no application, {refused: 'status', status} from any other.
create or replace function public.beta_waitlist(p_account uuid, p_note text, p_by text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    a public.beta_applications%rowtype;
    note_said text := nullif(btrim(coalesce(p_note, '')), '');
begin
    select * into a from public.beta_applications x where x.account = p_account for update;
    if not found then
        return jsonb_build_object('refused', 'none');
    end if;
    if a.status <> 'new' then
        return jsonb_build_object('refused', 'status', 'status', a.status);
    end if;
    update public.beta_applications x set status = 'waitlist', note = left(note_said, 500), decided_by = left(p_by, 320)
     where x.account = p_account returning * into a;
    return jsonb_build_object('application', public.beta_own_view(a), 'pool', public.beta_pool_view(a.pool),
                              'test', a.pool = 'test');
end;
$$;

-- The mail Brickworks kept a record of sending in the past [p_days] (1 to
-- 90): the beta's (beta_mail) and the answers to feedback (feedback_replies),
-- each by how it went (sent, dry: a test inbox with no key, failed), the
-- tests' for [p_tests] and the rest without. What Resend did with each after
-- (delivered, bounced) is Resend's to say (docs/ADMIN.md, Mail).
-- {days, beta: {sent, dry, failed}, answers: {sent, dry, failed}}.
create or replace function public.admin_mail_counts(p_days integer, p_tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    with since as (
        select now() - make_interval(days => greatest(1, least(coalesce(p_days, 7), 90))) as at
    ), beta as (
        select m.state from public.beta_mail m join auth.users u on u.id = m.account, since
         where m.at >= since.at and (lower(coalesce(u.email, '')) ~ '@resend\.dev$') = coalesce(p_tests, false)
    ), answers as (
        select r.mail as state from public.feedback_replies r join public.feedback f on f.id = r.feedback, since
         where r.at >= since.at and f.test = coalesce(p_tests, false)
    )
    select jsonb_build_object('days', greatest(1, least(coalesce(p_days, 7), 90)),
        'beta', jsonb_build_object('sent', (select count(*) from beta where state = 'sent'),
                                   'dry', (select count(*) from beta where state = 'dry'),
                                   'failed', (select count(*) from beta where state = 'failed')),
        'answers', jsonb_build_object('sent', (select count(*) from answers where state = 'sent'),
                                      'dry', (select count(*) from answers where state = 'dry'),
                                      'failed', (select count(*) from answers where state = 'failed')))
$$;

revoke all on function public.site_setting(text, text) from public, anon, authenticated;
revoke all on function public.site_setting_set(text, text, text, text) from public, anon, authenticated;
revoke all on function public.admin_audit_note(text, uuid, text, text, text, jsonb, integer, text, boolean, text)
    from public, anon, authenticated;
revoke all on function public.admin_audit_list(bigint, integer, boolean, text, text, text, text)
    from public, anon, authenticated;
revoke all on function public.beta_waitlist(uuid, text, text) from public, anon, authenticated;
revoke all on function public.admin_mail_counts(integer, boolean) from public, anon, authenticated;
grant execute on function public.site_setting(text, text) to service_role;
grant execute on function public.site_setting_set(text, text, text, text) to service_role;
grant execute on function public.admin_audit_note(text, uuid, text, text, text, jsonb, integer, text, boolean, text)
    to service_role;
grant execute on function public.admin_audit_list(bigint, integer, boolean, text, text, text, text) to service_role;
grant execute on function public.beta_waitlist(uuid, text, text) to service_role;
grant execute on function public.admin_mail_counts(integer, boolean) to service_role;

notify pgrst, 'reload schema';
