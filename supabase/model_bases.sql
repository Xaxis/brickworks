-- What a model is based on, 2026-10-30 (docs/SOCIAL.md section 7, item 5).
--
-- A remix names the model it was copied from, when that was shared here.
-- Nothing else could be credited: a model built from the parts of a LEGO
-- set (Rebrickable's "alternate build", the way most MOCs start), a set
-- changed, or work found elsewhere, with its author and its licence. Now
-- a model's designer says, up to three of them:
--
--   model_bases     (model, n, how, set_number | url, title, author,
--                   licence): what [model] is based on, [n] 1 to 3 in the
--                   order its designer gave. [how] 'alternate' (built from
--                   a set's parts; a set only), 'changed' (the set, or the
--                   work, changed), 'inspired'. A set by its number, whose
--                   page is /library/set/<number>; a work elsewhere by its
--                   https address, its title, and if known its author and
--                   licence, said as its designer wrote them.
--
--   model_bases_put(account, model_id, bases)   its designer's list, whole:
--                   [] takes them all away. {bases: n} or {refused: ...}.
--   model_bases_of(model_ids)                   the lists of those models
--   set_based(set_number, tests)                the models in the gallery
--                   based on a set, as gallery cards, the newest first: a
--                   set's page lists them
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the table.
--
-- Only additions: one table, deleted with its model, an index, and
-- functions. No row of another table is changed, nothing dropped or
-- renamed. Applied after discovery.sql (gallery_shows), moderation.sql
-- (is_barred), trust.sql and whichever file made directory_card last.
--
-- Applied by the lead:
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/model_bases.sql --table=model_bases
--
-- tried first, rolled back, with what tools/model_bases_try.sql asks:
--
--   ... node tools/apply_sql.mjs supabase/model_bases.sql --dry \
--         --try=tools/model_bases_try.sql --table=model_bases

-- ---------------------------------------------------------------------------
-- The table.

create table if not exists public.model_bases (
    model       text not null references public.shared_models (id) on delete cascade,
    n           smallint not null check (n between 1 and 3),
    how         text not null check (how in ('alternate', 'changed', 'inspired')),
    set_number  text check (set_number is null or set_number ~ '^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$'),
    url         text check (url is null or (char_length(url) <= 300 and url ~ '^https://[^[:space:]<>"]+$')),
    title       text check (title is null or char_length(title) between 1 and 120),
    author      text check (author is null or char_length(author) between 1 and 80),
    licence     text check (licence is null or char_length(licence) between 1 and 60),
    at          timestamptz not null default now(),
    primary key (model, n),
    -- A set, or a work elsewhere with its title; an alternate build is of a set.
    check ((set_number is null) <> (url is null)),
    check (url is null or title is not null),
    check (how <> 'alternate' or set_number is not null),
    check (set_number is null or (title is null and author is null and licence is null))
);
create index if not exists model_bases_set on public.model_bases (lower(set_number)) where set_number is not null;

alter table public.model_bases enable row level security;
revoke all on public.model_bases from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Said by its designer, read by its page and a set's.

-- [account]'s model [model_id] is based on [bases], an array of at most
-- three {how, set} or {how, url, title, author?, licence?}, in that order:
-- the whole list, [] for none. {bases: n}, or {refused: no_model |
-- not_yours | under_13 | barred | too_many | not_a_base}.
create or replace function public.model_bases_put(account uuid, model_id text, bases jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    one jsonb;
    at_n integer := 0;
begin
    select * into m from public.shared_models s where s.id = model_bases_put.model_id;
    if not found or not m.published then
        return jsonb_build_object('refused', 'no_model');
    end if;
    if account is null or m.owner <> model_bases_put.account then
        return jsonb_build_object('refused', 'not_yours');
    end if;
    if public.trust_kept_private(model_bases_put.account) then
        return jsonb_build_object('refused', 'under_13');
    end if;
    if public.is_barred(model_bases_put.account) or m.barred then
        return jsonb_build_object('refused', 'barred');
    end if;
    if jsonb_typeof(bases) is distinct from 'array' then
        return jsonb_build_object('refused', 'not_a_base');
    end if;
    if jsonb_array_length(bases) > 3 then
        return jsonb_build_object('refused', 'too_many');
    end if;
    delete from public.model_bases b where b.model = m.id;
    for one in select x from jsonb_array_elements(bases) x loop
        at_n := at_n + 1;
        begin
            insert into public.model_bases (model, n, how, set_number, url, title, author, licence)
            values (m.id, at_n, one->>'how', nullif(btrim(one->>'set'), ''), nullif(btrim(one->>'url'), ''),
                    nullif(btrim(regexp_replace(one->>'title', '\s+', ' ', 'g')), ''),
                    nullif(btrim(regexp_replace(one->>'author', '\s+', ' ', 'g')), ''),
                    nullif(btrim(regexp_replace(one->>'licence', '\s+', ' ', 'g')), ''));
        exception when check_violation or not_null_violation then
            raise exception 'brickworks: not a base: %', one using errcode = '22023';
        end;
    end loop;
    return jsonb_build_object('bases', at_n);
end;
$$;

-- What each of [model_ids] is based on: (model, n, how, set_number, url,
-- title, author, licence), in its designer's order.
create or replace function public.model_bases_of(model_ids text[])
returns table (model text, n smallint, how text, set_number text, url text, title text, author text, licence text)
language sql
stable
security definer
set search_path = public
as $$
    select b.model, b.n, b.how, b.set_number, b.url, b.title, b.author, b.licence
      from public.model_bases b
     where b.model = any (model_ids)
     order by b.model, b.n
$$;

-- The models in the gallery based on set [set_number] (as the gallery
-- shows them: a test one only with [tests]), as gallery cards with how
-- each is based on it, the newest first, at most 24.
create or replace function public.set_based(set_number text, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(public.directory_card(t.m) || jsonb_build_object('based', t.how)
                              order by t.listed_at desc nulls last, t.id), '[]'::jsonb)
      from (select m, m.id, m.listed_at, b.how
              from (select distinct on (x.model) x.model, x.how from public.model_bases x
                     where lower(x.set_number) = lower(set_based.set_number)
                     order by x.model, x.n) b
              join public.shared_models m on m.id = b.model
             where public.gallery_shows(m, set_based.tests)
             order by m.listed_at desc nulls last, m.id
             limit 24) t
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.model_bases_put(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.model_bases_put(uuid, text, jsonb) to service_role;
revoke all on function public.model_bases_of(text[]) from public, anon, authenticated;
grant execute on function public.model_bases_of(text[]) to service_role;
revoke all on function public.set_based(text, boolean) from public, anon, authenticated;
grant execute on function public.set_based(text, boolean) to service_role;
