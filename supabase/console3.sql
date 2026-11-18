-- The owner's console, part C (console3, 2026-11-13; docs/ADMIN.md): what
-- /admin reads and does that nothing kept or allowed before.
--
--   site_notices   a short notice on every page of the site (maintenance, an
--                  announcement), set and cleared from the console: its words
--                  in English and, only where the owner typed them, German,
--                  French and Spanish; its tone (info or warn); who set it and
--                  when, who cleared it and when. One showing a scope at a
--                  time ("live" for brickworks.diy, else a deployment's own
--                  host), so a preview's check never posts on the site. Every
--                  notice is kept, cleared ones too.
--   site_env       the deployment's variables by name and the environments
--                  Vercel has each in (production, preview, development),
--                  never a value, written by the release train as it ships
--                  (tools/release/env_names.sh: vercel env ls), so no
--                  Vercel token is in the site's own environment.
--
-- And the functions the console reads and acts by:
--   site_notice, site_notice_set, site_notice_clear, site_notices_list
--   site_settings_list  every switch kept, each scope's (console.sql's table)
--   site_env_note, site_env_list
--   admin_usage       the database's size, its biggest tables, and storage
--                     bucket by bucket (files and bytes), read from the
--                     catalogue and storage.objects
--   admin_sign_out    every sign-in session of one account ended (its rows in
--                     auth.sessions, and their refresh tokens with them), and
--                     every Claude it let in to the connector (oauth_grants)
--   admin_export      every row of every table that names one account, found
--                     from the catalogue's foreign keys to auth.users, so a
--                     table added later is in it with nothing changed here;
--                     what keeps sign-ins safe (hashes, challenges) left out
--   admin_find        people, models, lists and reports that hold some words
--   admin_person_more an account's comments and challenge entries, for its panel
--   challenge_admin_entries  a challenge's entries with their votes, and
--                     whether each keeps its rules, with what failed
--
-- Only the server touches any of it (the secret key), through functions that
-- are security definer and granted to the service role alone. Row security
-- on the new tables, no policy; their grants taken back from every role.
--
-- Only additions: two new tables and new functions. Needs console.sql. Reads
-- auth.sessions and storage.objects, which Supabase has; every part that
-- reads a table another file makes (oauth_grants, model_collections,
-- reports...) says nothing of it when that table is not there. Nothing that
-- exists is changed or dropped. Applying it again changes nothing.

create table if not exists public.site_notices (
    id         bigint      generated always as identity primary key,
    scope      text        not null constraint site_notices_scope check (scope ~ '^[a-z0-9.:-]{1,200}$'),
    -- English always; another language only as the owner typed it. A check
    -- passes on null, so each part says false rather than nothing.
    words      jsonb       not null constraint site_notices_words check (coalesce(
                   jsonb_typeof(words) = 'object'
                   and jsonb_typeof(words -> 'en') = 'string'
                   and char_length(words ->> 'en') between 1 and 300
                   and (words - array['en', 'de', 'fr', 'es']) = '{}'::jsonb
                   and coalesce(jsonb_typeof(words -> 'de'), 'string') = 'string'
                   and coalesce(jsonb_typeof(words -> 'fr'), 'string') = 'string'
                   and coalesce(jsonb_typeof(words -> 'es'), 'string') = 'string'
                   and coalesce(char_length(words ->> 'de'), 1) between 1 and 300
                   and coalesce(char_length(words ->> 'fr'), 1) between 1 and 300
                   and coalesce(char_length(words ->> 'es'), 1) between 1 and 300, false)),
    tone       text        not null default 'info' constraint site_notices_tone check (tone in ('info', 'warn')),
    set_by     text        not null constraint site_notices_set_by check (char_length(set_by) between 1 and 320),
    set_at     timestamptz not null default now(),
    cleared_by text        constraint site_notices_cleared_by check (char_length(cleared_by) <= 320),
    cleared_at timestamptz,
    constraint site_notices_cleared check ((cleared_at is null) = (cleared_by is null))
);
create unique index if not exists site_notices_showing on public.site_notices (scope) where cleared_at is null;
create index if not exists site_notices_newest on public.site_notices (scope, id desc);

create table if not exists public.site_env (
    name         text        primary key constraint site_env_name check (name ~ '^[A-Z][A-Z0-9_]{0,63}$'),
    environments text[]      not null default '{}' constraint site_env_environments check (
                     environments <@ array['production', 'preview', 'development']::text[]),
    noted_at     timestamptz not null default now()
);

alter table public.site_notices enable row level security;
alter table public.site_env enable row level security;
revoke all on public.site_notices from public, anon, authenticated, service_role;
revoke all on public.site_env from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The notice.

-- The notice showing in [p_scope]: {id, words, tone, set_by, set_at}, or null.
-- REPLACED LATER: announce.sql replaces this function (a notice's end).
-- Apply announce.sql again right after this file: tools/apply_sql.mjs
-- refuses it alone, unless --again=supabase/announce.sql.
create or replace function public.site_notice(p_scope text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object('id', n.id, 'words', n.words, 'tone', n.tone, 'set_by', n.set_by, 'set_at', n.set_at)
      from public.site_notices n
     where n.scope = p_scope and n.cleared_at is null
$$;

-- A notice set in [p_scope], in place of the one showing (cleared by the same
-- hand): {notice, was}. The words are checked by the table.
create or replace function public.site_notice_set(p_scope text, p_words jsonb, p_tone text, p_by text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    before bigint;
    made public.site_notices%rowtype;
begin
    update public.site_notices set cleared_at = now(), cleared_by = p_by
     where scope = p_scope and cleared_at is null
    returning id into before;
    insert into public.site_notices (scope, words, tone, set_by)
    values (p_scope, p_words, coalesce(p_tone, 'info'), p_by)
    returning * into made;
    return jsonb_build_object('notice', jsonb_build_object('id', made.id, 'words', made.words, 'tone', made.tone,
        'set_by', made.set_by, 'set_at', made.set_at), 'was', before);
end;
$$;

-- The notice showing in [p_scope] cleared: {cleared: its id, or null when none showed}.
create or replace function public.site_notice_clear(p_scope text, p_by text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    gone bigint;
begin
    update public.site_notices set cleared_at = now(), cleared_by = p_by
     where scope = p_scope and cleared_at is null
    returning id into gone;
    return jsonb_build_object('cleared', gone);
end;
$$;

-- The notices of [p_scope], the newest first: what was said, when and by whom.
-- REPLACED LATER: announce.sql replaces this function (a notice's end).
-- Apply announce.sql again right after this file: tools/apply_sql.mjs
-- refuses it alone, unless --again=supabase/announce.sql.
create or replace function public.site_notices_list(p_scope text, p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'words', n.words, 'tone', n.tone, 'set_by', n.set_by,
               'set_at', n.set_at, 'cleared_by', n.cleared_by, 'cleared_at', n.cleared_at) order by n.id desc), '[]'::jsonb)
      from (select * from public.site_notices where scope = p_scope order by id desc
             limit greatest(1, least(coalesce(p_limit, 10), 50))) n
$$;

-- Every switch kept in site_settings (console.sql), each scope's, by name:
-- [{name, scope, value, set_by, set_at}].
create or replace function public.site_settings_list()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(jsonb_build_object('name', s.name, 'scope', s.scope, 'value', s.value, 'set_by', s.set_by,
               'set_at', s.set_at) order by s.name, s.scope), '[]'::jsonb)
      from (select * from public.site_settings order by name, scope limit 500) s
$$;

-- ---------------------------------------------------------------------------
-- The deployment's variables, as Vercel lists them (names and environments).

-- [p_vars] ([{name, environments}]) as Vercel lists them now: each kept, and
-- a name Vercel no longer has let go. The count kept.
create or replace function public.site_env_note(p_vars jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    kept integer;
begin
    if jsonb_typeof(p_vars) <> 'array' or jsonb_array_length(p_vars) > 300 then
        raise exception 'site_env_note: a list of at most 300 variables';
    end if;
    insert into public.site_env (name, environments, noted_at)
    select distinct on (v ->> 'name') v ->> 'name',
           coalesce((select array_agg(distinct e order by e) from jsonb_array_elements_text(v -> 'environments') e), '{}'),
           now()
      from jsonb_array_elements(p_vars) v
     order by v ->> 'name'
    on conflict (name) do update set environments = excluded.environments, noted_at = excluded.noted_at;
    get diagnostics kept = row_count;
    delete from public.site_env
     where name not in (select v ->> 'name' from jsonb_array_elements(p_vars) v);
    return kept;
end;
$$;

-- Every variable Vercel was last heard to have: {vars: [{name, environments}], noted_at}.
create or replace function public.site_env_list()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object(
        'vars', coalesce(jsonb_agg(jsonb_build_object('name', e.name, 'environments', to_jsonb(e.environments)) order by e.name),
                         '[]'::jsonb),
        'noted_at', max(e.noted_at))
      from public.site_env e
$$;

-- ---------------------------------------------------------------------------
-- What the project uses: the database and its storage.

-- {database: bytes, tables: [{name, bytes, rows}] (the fifteen biggest of
-- public), buckets: [{bucket, files, bytes}] or null without storage, at}.
create or replace function public.admin_usage()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    tables jsonb;
    buckets jsonb;
begin
    select coalesce(jsonb_agg(jsonb_build_object('name', t.relname, 'bytes', t.bytes, 'rows', t.reltuples) order by t.bytes desc),
                    '[]'::jsonb)
      into tables
      from (select c.relname, pg_catalog.pg_total_relation_size(c.oid) as bytes, greatest(c.reltuples, 0)::bigint as reltuples
              from pg_catalog.pg_class c
             where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
             order by 2 desc
             limit 15) t;
    begin
        execute $q$
            select coalesce(jsonb_agg(jsonb_build_object('bucket', b.bucket_id, 'files', b.files, 'bytes', b.bytes)
                       order by b.bytes desc), '[]'::jsonb)
              from (select o.bucket_id, count(*) as files,
                           coalesce(sum(case when (o.metadata ->> 'size') ~ '^\d{1,18}$' then (o.metadata ->> 'size')::bigint end), 0) as bytes
                      from storage.objects o
                     group by o.bucket_id) b
        $q$ into buckets;
    exception when undefined_table or undefined_column or insufficient_privilege then
        buckets := null;
    end;
    return jsonb_build_object('database', pg_catalog.pg_database_size(pg_catalog.current_database()), 'tables', tables,
        'buckets', buckets, 'at', now());
end;
$$;

-- ---------------------------------------------------------------------------
-- One account: signed out everywhere, and all of its rows.

-- Every sign-in session of [p_account] ended (auth.sessions, whose refresh
-- tokens go with them, so nothing renews), and every Claude it let in to the
-- connector (oauth_grants, whose tokens go with them): {sessions, claudes}.
-- A token already handed out lasts until it runs out, within the hour.
create or replace function public.admin_sign_out(p_account uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    sessions integer := 0;
    claudes integer := 0;
begin
    begin
        execute 'delete from auth.sessions where user_id = $1' using p_account;
        get diagnostics sessions = row_count;
    exception when undefined_table then
        sessions := null;
    end;
    begin
        execute 'delete from public.oauth_grants where owner = $1' using p_account;
        get diagnostics claudes = row_count;
    exception when undefined_table then
        claudes := null;
    end;
    return jsonb_build_object('sessions', sessions, 'claudes', claudes);
end;
$$;

-- Every row of [p_account] in every table of public with a foreign key to
-- auth.users ("table" or "table.column" when a table has two), at most
-- 1000 a table, and the items of its lists:
-- {tables: {name: [rows]}, more: {name: rows in all, where over 1000}, at}.
-- Never what keeps a sign-in safe: oauth_codes, oc_sessions and the audit are
-- left out, and every column named as a secret is (hash, rh, code_challenge,
-- channel, secret, token). A value over 8 KB is the app's own working state,
-- not something the person wrote (a connector tab's tool list is 110 KB, and
-- an account of the checks has a thousand of them): it is given as
-- {"not_exported": its bytes}, so the download stays one a browser can hold.
create or replace function public.admin_export(p_account uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    found record;
    rows jsonb;
    named text;
    total bigint;
    out jsonb := '{}'::jsonb;
    more jsonb := '{}'::jsonb;
    hidden constant text[] := array['hash', 'rh', 'code_challenge', 'channel', 'secret', 'token'];
begin
    for found in
        select c.conrelid::regclass::text as tbl, rel.relname, a.attname as col,
               count(*) over (partition by c.conrelid) as columns
          from pg_catalog.pg_constraint c
          join pg_catalog.pg_class rel on rel.oid = c.conrelid
          join pg_catalog.pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
         where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and cardinality(c.conkey) = 1
           and rel.relnamespace = 'public'::regnamespace
           and rel.relname not in ('oauth_codes', 'oc_sessions', 'admin_audit')
         order by rel.relname, a.attname
    loop
        named := case when found.columns > 1 then found.relname || '.' || found.col else found.relname end;
        execute format('select count(*) from %s where %I = $1', found.tbl, found.col) into total using p_account;
        if total = 0 then
            continue;
        end if;
        execute format('select coalesce(jsonb_agg((select coalesce(jsonb_object_agg(f.key, case when octet_length(f.value::text) > 8192 '
                       || 'then jsonb_build_object(''not_exported'', octet_length(f.value::text)) else f.value end), ''{}''::jsonb) '
                       || 'from jsonb_each(to_jsonb(t) - $2) f)), ''[]''::jsonb) from (select * from %s where %I = $1 limit 1000) t',
                       found.tbl, found.col)
           into rows using p_account, hidden;
        out := out || jsonb_build_object(named, rows);
        if total > 1000 then
            more := more || jsonb_build_object(named, total);
        end if;
    end loop;
    begin
        execute 'select coalesce(jsonb_agg(to_jsonb(i)), ''[]''::jsonb) from (select i.* from public.model_collection_items i '
             || 'join public.model_collections c on c.id = i.collection where c.owner = $1 limit 1000) i'
           into rows using p_account;
        if jsonb_array_length(rows) > 0 then
            out := out || jsonb_build_object('model_collection_items', rows);
        end if;
    exception when undefined_table or undefined_column then
        null;
    end;
    return jsonb_build_object('tables', out, 'more', more, 'at', now());
end;
$$;

-- What an account's panel shows that the server cannot read directly (the
-- comments' and the challenges' tables are reached only through functions):
-- {comments: its newest fifty, entries: its challenge entries with each
-- challenge's title}; each null where its table is not there.
create or replace function public.admin_person_more(p_account uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    comments jsonb;
    entries jsonb;
begin
    begin
        execute $q$
            select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'model', c.model, 'body', left(c.body, 280), 'at', c.at,
                       'hidden_at', c.hidden_at, 'removed_at', c.removed_at, 'removed_by', c.removed_by) order by c.at desc), '[]'::jsonb)
              from (select * from public.model_comments where author = $1 order by at desc limit 50) c
        $q$ into comments using p_account;
    exception when undefined_table or undefined_column then
        comments := null;
    end;
    begin
        execute $q$
            select coalesce(jsonb_agg(jsonb_build_object('challenge', e.challenge, 'title', ch.title, 'ends_on', ch.ends_on,
                       'model', e.model, 'name', m.name, 'way', e.way, 'at', e.at) order by e.at desc), '[]'::jsonb)
              from (select * from public.challenge_entries where owner = $1 order by at desc limit 50) e
              left join public.challenges ch on ch.id = e.challenge
              left join public.shared_models m on m.id = e.model
        $q$ into entries using p_account;
    exception when undefined_table or undefined_column then
        entries := null;
    end;
    return jsonb_build_object('comments', comments, 'entries', entries);
end;
$$;

-- ---------------------------------------------------------------------------
-- A challenge's entries, for the owner.

-- Every entry of challenge [p_challenge], by way then as entered: its model's
-- name, parts and whether the gallery shows it, whose it is, its votes,
-- whether it keeps the rules today (challenge_keeps) and, where it does not,
-- what the check found (challenge_check). Null before challenges.sql.
create or replace function public.challenge_admin_entries(p_challenge bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    out jsonb;
begin
    execute $q$
        select coalesce(jsonb_agg(jsonb_build_object('model', e.model, 'owner', e.owner, 'way', e.way, 'at', e.at,
                   'votes', (select count(*) from public.challenge_votes v where v.challenge = e.challenge and v.model = e.model),
                   'keeps', k.keeps,
                   'check', case when k.keeps is false then public.challenge_check(e.challenge, e.model) end,
                   'name', m.name, 'parts', m.parts, 'listed', m.listed, 'barred', m.barred)
                   order by e.way desc, e.at), '[]'::jsonb)
          from public.challenge_entries e
          left join public.shared_models m on m.id = e.model
          left join lateral (select x.keeps from public.challenge_keeps(e.challenge, array[e.model]) x limit 1) k on true
         where e.challenge = $1
    $q$ into out using p_challenge;
    return out;
exception when undefined_table or undefined_function or undefined_column then
    return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Find anything.

-- People (handle, name), models (name, link), lists (name) and reports (what
-- was said, the link or handle reported) holding [p_query], ten of each, the
-- checks' own for [p_tests]: {people, models, lists, reports}. A part whose
-- table is not there is [].
create or replace function public.admin_find(p_query text, p_tests boolean)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    q text := '%' || replace(replace(replace(left(coalesce(p_query, ''), 100), '\', '\\'), '%', '\%'), '_', '\_') || '%';
    exact text := left(coalesce(p_query, ''), 100);
    found jsonb := jsonb_build_object('people', '[]'::jsonb, 'models', '[]'::jsonb, 'lists', '[]'::jsonb, 'reports', '[]'::jsonb);
    rows jsonb;
begin
    if char_length(trim(coalesce(p_query, ''))) < 2 then
        return found;
    end if;
    begin
        execute 'select coalesce(jsonb_agg(x), ''[]''::jsonb) from (select p.account, p.handle, p.name from public.people p '
             || 'where p.handle ilike $1 or p.name ilike $1 order by p.handle limit 10) x'
           into rows using q;
        found := found || jsonb_build_object('people', rows);
    exception when undefined_table or undefined_column then
        null;
    end;
    begin
        execute 'select coalesce(jsonb_agg(x), ''[]''::jsonb) from (select m.id, m.name, m.owner, m.listed, m.published, m.barred '
             || 'from public.shared_models m where (m.name ilike $1 or m.id = $2) and m.test is not distinct from $3 '
             || 'order by m.created_at desc limit 10) x'
           into rows using q, exact, coalesce(p_tests, false);
        found := found || jsonb_build_object('models', rows);
    exception when undefined_table or undefined_column then
        null;
    end;
    begin
        execute 'select coalesce(jsonb_agg(x), ''[]''::jsonb) from (select c.id, c.name, c.owner, c.public '
             || 'from public.model_collections c where c.name ilike $1 or c.id = $2 order by c.updated_at desc limit 10) x'
           into rows using q, exact;
        found := found || jsonb_build_object('lists', rows);
    exception when undefined_table or undefined_column then
        null;
    end;
    begin
        execute 'select coalesce(jsonb_agg(x), ''[]''::jsonb) from (select r.id, r.at, r.reason, r.note, r.model, r.handle, '
             || 'r.collection, r.resolved_at, r.resolution from public.reports r where r.note ilike $1 or r.contact ilike $1 '
             || 'or r.model = $2 or r.handle = lower($2) or r.collection = $2 order by r.id desc limit 10) x'
           into rows using q, exact;
        found := found || jsonb_build_object('reports', rows);
    exception when undefined_table or undefined_column then
        null;
    end;
    return found;
end;
$$;

revoke all on function public.site_notice(text) from public, anon, authenticated;
revoke all on function public.site_notice_set(text, jsonb, text, text) from public, anon, authenticated;
revoke all on function public.site_notice_clear(text, text) from public, anon, authenticated;
revoke all on function public.site_notices_list(text, integer) from public, anon, authenticated;
revoke all on function public.site_settings_list() from public, anon, authenticated;
revoke all on function public.site_env_note(jsonb) from public, anon, authenticated;
revoke all on function public.site_env_list() from public, anon, authenticated;
revoke all on function public.admin_usage() from public, anon, authenticated;
revoke all on function public.admin_sign_out(uuid) from public, anon, authenticated;
revoke all on function public.admin_export(uuid) from public, anon, authenticated;
revoke all on function public.admin_find(text, boolean) from public, anon, authenticated;
revoke all on function public.challenge_admin_entries(bigint) from public, anon, authenticated;
revoke all on function public.admin_person_more(uuid) from public, anon, authenticated;
grant execute on function public.site_notice(text) to service_role;
grant execute on function public.site_notice_set(text, jsonb, text, text) to service_role;
grant execute on function public.site_notice_clear(text, text) to service_role;
grant execute on function public.site_notices_list(text, integer) to service_role;
grant execute on function public.site_settings_list() to service_role;
grant execute on function public.site_env_note(jsonb) to service_role;
grant execute on function public.site_env_list() to service_role;
grant execute on function public.admin_usage() to service_role;
grant execute on function public.admin_sign_out(uuid) to service_role;
grant execute on function public.admin_export(uuid) to service_role;
grant execute on function public.admin_find(text, boolean) to service_role;
grant execute on function public.challenge_admin_entries(bigint) to service_role;
grant execute on function public.admin_person_more(uuid) to service_role;

notify pgrst, 'reload schema';
