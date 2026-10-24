-- Following a collection, and the collections a model is in, 2026-10-24
-- (docs/SOCIAL.md U11, collections first-class).
--
-- A public collection (people.sql's model_collections) was a page nobody
-- could come back to but by its link. Now a person may follow one (Follow
-- on /c/<id>), as Sketchfab's collections are subscribed to and Pinterest's
-- boards followed ([SK-P]), and /feed shows what is put in it:
--
--   collection   a model put in a public collection they follow, listed in
--                the gallery: the model's card, and whose collection, as a
--                post ("Robin added Wizard's Tower to Castles")
--
-- And a model's page says how many public collections it is in, linked to
-- them, as Printables' Collections tab counts them ([PR-C]).
--
-- The rules are follows.sql's, whatever asks:
--
--   Who may follow   a signed-in account that said it is 13 or over
--                    (trust_may_go_public), not taken out of the gallery
--                    (is_barred). A follow is counted in public, so an
--                    account under 13, or one not asked yet, may not.
--   What may be      a public collection whose owner said they are 13 or
--   followed         over and is shown in public, not one's own. Made
--                    private, or its owner taken out, it is followed by
--                    nobody: nothing of it is counted or in a feed, and
--                    the follows wait, as a person's do, until it is shown
--                    again. Deleted, its follows go with it.
--   How often        follows.sql's limits, counted together with following
--                    people: 60 an hour and 300 a day (may_act 'follow').
--                    Letting one go is not counted.
--   Who sees whom    only a count: N followers, on the collection's page.
--                    Never a list of who follows it, and its owner is told
--                    nothing.
--
-- The feed rows are read from the tables that hold them
-- (model_collection_items, model_collections, shared_models) with what
-- their pages show and hide: a model listed in the gallery and not taken
-- out; a test account's collection or model only in a test account's
-- feed. Nothing is copied into a feed table. Not in the day's email,
-- which reads feed_rows: its choices are unchanged.
--
--   collection_follows   who follows which collection, and since when
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, may read or write the new table
-- directly.
--
-- Only additions, applied after people.sql, follows.sql, trust.sql,
-- test_models.sql and notifications.sql (it reads their tables and
-- functions): one new table, deleted with its follower's account and with
-- its collection, a trigger that refuses, new functions, and one function
-- replaced:
--
--   follow_rows   supersedes notifications.sql's (the live one: no later
--                 file replaces it). The same rows, and the collections
--                 followed (list_rows). follow_page and notification_counts
--                 read it, so the feed and the count on the avatar have
--                 them. Applying notifications.sql again alone would take
--                 them out: tools/apply_sql.mjs refuses it, unless
--                 --again=supabase/collection_follows.sql.
--
-- No existing row is changed, nothing dropped or renamed. Until code that
-- writes a follow is deployed nobody follows a collection, so the replaced
-- function answers exactly what it did.

-- ---------------------------------------------------------------------------
-- The table.

create table if not exists public.collection_follows (
    follower    uuid not null references auth.users (id) on delete cascade,
    collection  text not null references public.model_collections (id) on delete cascade,
    at          timestamptz not null default now(),
    primary key (follower, collection)
);
create index if not exists collection_follows_collection on public.collection_follows (collection, at desc);

alter table public.collection_follows enable row level security;
revoke all on public.collection_follows from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Following.

-- Whether [list] may be followed: public, its owner 13 or over by their
-- own answer and shown in public.
create or replace function public.list_may_be_followed(list text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (select 1 from public.model_collections c
                    where c.id = list_may_be_followed.list and c.public
                      and public.trust_may_go_public(c.owner) and public.shown_publicly(c.owner))
$$;

-- Why [account] may not follow [list], or null when it may: sign_in,
-- nobody, yourself, barred, ask_first, under_13, as follow_trouble's.
create or replace function public.list_follow_trouble(account uuid, list text)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select case
        when account is null then 'sign_in'
        when list is null or not public.list_may_be_followed(list) then 'nobody'
        when exists (select 1 from public.model_collections c
                      where c.id = list_follow_trouble.list and c.owner = account) then 'yourself'
        when public.is_barred(account) then 'barred'
        when (select p.over_13 from public.profiles p where p.id = account) is null then 'ask_first'
        when not public.trust_may_go_public(account) then 'under_13'
        end
$$;

-- The refusals, whatever writes.
create or replace function public.collection_follows_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text := public.list_follow_trouble(new.follower, new.collection);
begin
    if trouble in ('ask_first', 'under_13') then
        raise exception 'brickworks: following is for accounts 13 or over'
            using errcode = 'P0001', hint = 'collection_follows:age';
    elsif trouble = 'barred' then
        raise exception 'brickworks: this account was taken out of the gallery'
            using errcode = 'P0001', hint = 'collection_follows:barred';
    elsif trouble is not null then
        raise exception 'brickworks: only a public collection, not your own, can be followed'
            using errcode = 'P0001', hint = 'collection_follows:nobody';
    end if;
    return new;
end;
$$;
create or replace trigger collection_follows_guard
    before insert or update on public.collection_follows
    for each row execute function public.collection_follows_guard();
revoke all on function public.collection_follows_guard() from public, anon, authenticated;

-- [list]'s follows as [asker] sees them: {id, followers, you_follow, mine,
-- trouble}. Counted only of accounts shown in public. Null for a
-- collection nobody may follow.
create or replace function public.list_follow_state(asker uuid, list text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', c.id,
        'followers', (select count(*) from public.collection_follows f
                       where f.collection = c.id
                         and public.trust_may_go_public(f.follower) and public.shown_publicly(f.follower)),
        'you_follow', asker is not null and exists (select 1 from public.collection_follows f
                                                     where f.follower = asker and f.collection = c.id),
        'mine', asker is not null and asker = c.owner,
        'trouble', public.list_follow_trouble(asker, c.id))
      from public.model_collections c
     where c.id = list_follow_state.list and public.list_may_be_followed(c.id)
$$;

-- [account] follows [list] (on), or lets it go (off): list_follow_state as
-- it is then, or {refused} with list_follow_trouble's reasons and limit
-- (follows.sql's, counted with following people).
create or replace function public.list_follow(account uuid, list text, following boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text;
begin
    if following is null then
        raise exception 'brickworks: say whether to follow' using errcode = '22023';
    end if;
    if following then
        trouble := public.list_follow_trouble(account, list);
        if trouble is not null then
            return jsonb_build_object('refused', trouble);
        end if;
        if not exists (select 1 from public.collection_follows f
                        where f.follower = account and f.collection = list_follow.list) then
            if not public.may_act(account::text, 'follow', 60, 300) then
                return jsonb_build_object('refused', 'limit');
            end if;
            insert into public.collection_follows (follower, collection) values (account, list_follow.list)
            on conflict on constraint collection_follows_pkey do nothing;
        end if;
    else
        if account is null then
            return jsonb_build_object('refused', 'sign_in');
        end if;
        delete from public.collection_follows f where f.follower = account and f.collection = list_follow.list;
    end if;
    return coalesce(public.list_follow_state(account, list), jsonb_build_object('refused', 'nobody'));
end;
$$;

-- ---------------------------------------------------------------------------
-- The feed.

-- What was put in the collections [viewer] follows, from after [since] up
-- to [until], as feed_rows' (kind, at, item): a model in the gallery, put
-- in a collection that may be followed, not the viewer's own; a test
-- account's collection or model only in a test account's feed.
create or replace function public.list_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    with tests as (
        select public.trust_is_test_account(viewer) as ok)
    select 'collection'::text, i.at,
           jsonb_build_object('model', m.id, 'name', m.name, 'parts', m.parts,
                              'collection', c.id, 'list_name', c.name, 'by', public.feed_who(c.owner))
      from public.collection_follows f
      join public.model_collections c on c.id = f.collection
      join public.model_collection_items i on i.collection = c.id
      join public.shared_models m on m.id = i.model
     cross join tests t
     where f.follower = viewer and c.owner <> viewer
       and public.list_may_be_followed(c.id)
       and (not public.trust_is_test_account(c.owner) or t.ok)
       and m.published and m.listed and not m.barred
       and (not m.test or t.ok)
       and i.at > since and i.at <= until
$$;

-- What the people and the collections [viewer] follows made, from after
-- [since] up to [until]: notifications.sql's follow_rows (feed_rows without
-- what notification_rows tells), and list_rows.
create or replace function public.follow_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    select f.kind, f.at, f.item
      from public.feed_rows(viewer, since, until) f
     where f.kind in ('model', 'version', 'challenge')
        or (f.kind = 'photo' and not (f.item->>'yours')::boolean)
    union all
    select l.kind, l.at, l.item
      from public.list_rows(viewer, since, until) l
$$;

-- ---------------------------------------------------------------------------
-- The collections a model is in.

-- The public collections [model] is in, as its page says them: {count,
-- lists: [{id, name, count, by}]}, the one it was put in last first, at
-- most [most] (1 to 48) of them. Only while the model is in the gallery,
-- which is when a collection's page shows it; only collections whose
-- owner is shown in public; a test account's only with [tests] (a test
-- model's own page). [count] is of the collections' models as their pages
-- count them; [by] their owner's profile, if they made one.
create or replace function public.model_lists(model text, tests boolean default false, most integer default 12)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with shown as (
        select c.id, c.name, c.owner, i.at
          from public.model_collection_items i
          join public.model_collections c on c.id = i.collection
          join public.shared_models m on m.id = i.model
         where i.model = model_lists.model and c.public
           and m.published and m.listed and not m.barred
           and public.shown_publicly(c.owner)
           and (model_lists.tests or not public.trust_is_test_account(c.owner)))
    select jsonb_build_object(
        'count', (select count(*) from shown),
        'lists', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'id', s.id, 'name', s.name,
                       'count', public.collection_count(s.id, false, model_lists.tests),
                       'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                                from public.people p where p.account = s.owner))
                   order by s.at desc, s.id)
              from (select * from shown order by shown.at desc, shown.id
                     limit least(greatest(coalesce(model_lists.most, 12), 1), 48)) s), '[]'::jsonb))
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.list_may_be_followed(text) from public, anon, authenticated;
grant execute on function public.list_may_be_followed(text) to service_role;
revoke all on function public.list_follow_trouble(uuid, text) from public, anon, authenticated;
grant execute on function public.list_follow_trouble(uuid, text) to service_role;
revoke all on function public.list_follow_state(uuid, text) from public, anon, authenticated;
grant execute on function public.list_follow_state(uuid, text) to service_role;
revoke all on function public.list_follow(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.list_follow(uuid, text, boolean) to service_role;
revoke all on function public.list_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.list_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.follow_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.follow_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.model_lists(text, boolean, integer) from public, anon, authenticated;
grant execute on function public.model_lists(text, boolean, integer) to service_role;

notify pgrst, 'reload schema';
