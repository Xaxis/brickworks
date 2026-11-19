-- Blocking a person, 2026-11-19 (blockauthor, docs/SOCIAL.md section 9).
--
-- A model's owner could hide a comment, and nothing stopped a person. Now
-- anybody signed in may block somebody from their profile's More menu or a
-- comment's row; Settings › Blocked people lists them, each with Unblock.
-- What a block does, for the person who blocks (A) and the one blocked (B):
--
--   follows   between them end both ways, of each other and of each
--             other's collections, and neither may follow the other or
--             their collections again while it stands (triggers on follows
--             and collection_follows say it whatever writes). Unblocking brings none of them back, as on X and
--             Instagram.
--   comments  B's comments and replies on A's models are hidden from
--             everybody but B, who sees them as before; B may not comment
--             on A's models, reply to A's comments, or post a photo of a
--             build on A's models (triggers on model_comments and
--             build_photos). A is told why on B's models; B is told only
--             that it cannot be done, never that A blocked them.
--   A's view  B's models leave A's gallery, shelves, search and feed, B's
--             comments anywhere are hidden from A, and nothing B does
--             reaches A's notifications or their count (api/_blocks.js).
--   B         is told nothing: no notification, no mark on B's own pages.
--             A's public pages stay public, as they are to anybody signed
--             out, so hiding them from B would protect nobody and tell B.
--
-- Unblocking takes the row out: B's models and comments come back where
-- they were.
--
-- Only the server reads it, through these functions; nobody's blocks are
-- anybody else's to read. Row security is on, the table is revoked from
-- every client role, and its one policy (a person's own rows) holds even
-- if a grant were ever added by mistake. The site's owner sees how many
-- people blocked an account (/admin › People, block_count_against), never
-- who; an account's export (api/_console_people.js) leaves out who blocked
-- it, as it leaves out who follows it, so a person never learns it there.
--
-- Additive: one new table, new functions and four new triggers; nothing
-- that was here is altered. Until it is applied, api/_blocks.js finds no
-- functions (404): nothing is hidden, Block says it is not open yet, and
-- everything else works as before.

-- ---------------------------------------------------------------------------
-- The table.

create table if not exists public.blocks (
    blocker  uuid not null references auth.users (id) on delete cascade,
    blocked  uuid not null references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (blocker, blocked),
    check (blocker <> blocked)
);
create index if not exists blocks_blocked on public.blocks (blocked, blocker);

alter table public.blocks enable row level security;
revoke all on public.blocks from public, anon, authenticated, service_role;

do $$
begin
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'blocks'
                    and policyname = 'blocks_own_only') then
        create policy blocks_own_only on public.blocks for select to authenticated
            using (blocker = (select auth.uid()));
    end if;
end;
$$;

-- How many people one account may block: a list past this is not one a
-- person keeps by hand.
create or replace function public.block_most()
returns integer
language sql
immutable
as $$ select 1000 $$;

-- ---------------------------------------------------------------------------
-- Between two accounts.

-- 'blocked' when [account] blocked [other], 'blocked_by' when [other]
-- blocked [account], null when neither (or either is nobody). Who blocked
-- whom is for the server: the API never tells B 'blocked_by'.
create or replace function public.block_between(account uuid, other uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select case
        when block_between.account is null or block_between.other is null or block_between.account = block_between.other then null
        when exists (select 1 from public.blocks k where k.blocker = block_between.account and k.blocked = block_between.other) then 'blocked'
        when exists (select 1 from public.blocks k where k.blocker = block_between.other and k.blocked = block_between.account) then 'blocked_by'
        end
$$;

-- How [account] stands with whoever a write of theirs would reach on
-- [model_id] (its owner) or under comment [comment_id] (its author, and
-- its thread's first comment's), as block_between says it: 'blocked' when
-- [account] blocked any of them, else 'blocked_by' when any blocked
-- [account], else null. With no model given, the comment's.
create or replace function public.block_on(account uuid, model_id text default null, comment_id bigint default null)
returns text
language sql
stable
security definer
set search_path = public
as $$
    with others as (
        select s.owner as other from public.shared_models s
         where s.id = coalesce(model_id, (select k.model from public.model_comments k where k.id = comment_id))
        union
        select k.author from public.model_comments k where k.id = comment_id
        union
        select t.author from public.model_comments k join public.model_comments t on t.id = k.parent
         where k.id = comment_id)
    select case
        when block_on.account is null then null
        when exists (select 1 from others o join public.blocks b on b.blocker = block_on.account and b.blocked = o.other) then 'blocked'
        when exists (select 1 from others o join public.blocks b on b.blocker = o.other and b.blocked = block_on.account) then 'blocked_by'
        end
$$;

-- Of [handles], those [account] may not name in a comment: whoever they
-- blocked or who blocked them. An @handle of one stays words, nobody told.
create or replace function public.block_named(account uuid, handles text[])
returns text[]
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(array_agg(p.handle), '{}')
      from public.people p
     where p.handle = any(coalesce(block_named.handles, '{}'))
       and public.block_between(block_named.account, p.account) is not null
$$;

-- ---------------------------------------------------------------------------
-- Blocking, unblocking, and the list.

-- [account] blocks the person with [wanted]'s handle (blocking true), or
-- unblocks them (false): {handle, name, blocked, at}, or {refused}: sign_in,
-- nobody, yourself, limit (60 an hour, 300 a day), most (block_most). The
-- same answer for a block already there, and nothing counted twice.
-- Blocking ends every follow between them, both ways, of each other and of
-- each other's collections.
create or replace function public.block_person(account uuid, wanted text, blocking boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    whom uuid;
    whom_handle text;
    whom_name text;
begin
    if blocking is null then
        raise exception 'brickworks: say whether to block' using errcode = '22023';
    end if;
    if account is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    select p.account, p.handle, p.name into whom, whom_handle, whom_name
      from public.people p where p.handle = lower(wanted);
    if whom is null then
        return jsonb_build_object('refused', 'nobody');
    end if;
    if whom = account then
        return jsonb_build_object('refused', 'yourself');
    end if;
    if blocking then
        if not exists (select 1 from public.blocks k where k.blocker = account and k.blocked = whom) then
            if (select count(*) from public.blocks k where k.blocker = account) >= public.block_most() then
                return jsonb_build_object('refused', 'most');
            end if;
            if not public.may_act(account::text, 'block', 60, 300) then
                return jsonb_build_object('refused', 'limit');
            end if;
            insert into public.blocks (blocker, blocked) values (account, whom)
            on conflict on constraint blocks_pkey do nothing;
        end if;
        delete from public.follows f
         where (f.follower = account and f.followed = whom) or (f.follower = whom and f.followed = account);
        delete from public.collection_follows c
         where (c.follower = account and c.collection in (select l.id from public.model_collections l where l.owner = whom))
            or (c.follower = whom and c.collection in (select l.id from public.model_collections l where l.owner = account));
    else
        delete from public.blocks k where k.blocker = account and k.blocked = whom;
    end if;
    return jsonb_build_object('handle', whom_handle, 'name', whom_name,
        'blocked', exists (select 1 from public.blocks k where k.blocker = account and k.blocked = whom),
        'at', (select k.at from public.blocks k where k.blocker = account and k.blocked = whom));
end;
$$;

-- Whom [account] blocked: [{handle, name, at}], the newest first. Only
-- their own: the API asks it with the caller's account and nobody else's.
create or replace function public.block_list(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('handle', p.handle, 'name', p.name, 'at', k.at)
                              order by k.at desc), '[]'::jsonb)
      from public.blocks k
      join public.people p on p.account = k.blocked
     where k.blocker = block_list.account
$$;

-- Of the models [ids], those whose owner [viewer] blocked: what leaves
-- their gallery, shelves, search and feed. Nothing for nobody signed in.
create or replace function public.block_models(viewer uuid, ids text[])
returns text[]
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(array_agg(s.id), '{}')
      from public.shared_models s
      join public.blocks k on k.blocker = viewer and k.blocked = s.owner
     where viewer is not null and s.id = any(coalesce(ids, '{}'))
$$;

-- The comments on [model_id] hidden from [viewer] (null: signed out):
-- those whose author the model's owner blocked, from everybody but their
-- author; and those whose author [viewer] blocked, from [viewer]. A
-- comment's replies go with it (api/_blocks.js leaves out a reply whose
-- comment is not shown).
create or replace function public.block_hidden(model_id text, viewer uuid default null)
returns bigint[]
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(array_agg(k.id), '{}')
      from public.model_comments k
      join public.shared_models s on s.id = k.model
     where k.model = model_id and k.removed_at is null
       and (viewer is null or k.author <> viewer)
       and (exists (select 1 from public.blocks b where b.blocker = s.owner and b.blocked = k.author)
            or (viewer is not null and exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = k.author)))
$$;

-- What of [viewer]'s counts came from people they blocked: {notifications,
-- feed}, each how many of notification_counts' and feed_new_count's rows
-- (since the list was last opened, in the last 90 days) the API takes off
-- the avatar's count. Zero, and nothing read, for somebody who blocked
-- nobody. Notifications by who did it; the feed by the owner of a model
-- put in a collection they follow (they follow nobody they blocked).
create or replace function public.block_counts(viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select case when viewer is null or not exists (select 1 from public.blocks k where k.blocker = viewer)
        then jsonb_build_object('notifications', 0, 'feed', 0)
        else jsonb_build_object(
            'notifications', (select count(*)::integer from public.notification_rows(viewer,
                greatest(coalesce((select s.seen_at from public.notification_marks_of(viewer) s), '-infinity'),
                         now() - interval '90 days'), now()) r
                 where r.item->'by'->>'handle' in (select p.handle from public.blocks k
                                                     join public.people p on p.account = k.blocked
                                                    where k.blocker = viewer)),
            'feed', (select count(*)::integer from public.follow_rows(viewer,
                greatest(coalesce((select f.seen_at from public.feed_marks f where f.account = viewer), '-infinity'),
                         now() - interval '90 days'), now()) r
                 join public.collection_follows c on c.follower = viewer and c.collection = r.item->>'collection'
                 join public.shared_models s on s.id = r.item->>'model'
                 join public.blocks k on k.blocker = viewer and k.blocked = s.owner
                where r.kind = 'collection' and r.at > c.at))
        end
$$;

-- How many people blocked [p_account], for the owner's console (/admin ›
-- People); never who.
create or replace function public.block_count_against(p_account uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer from public.blocks k where k.blocked = p_account
$$;

-- ---------------------------------------------------------------------------
-- The refusals, whatever writes.

create or replace function public.blocks_guard_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.block_between(new.follower, new.followed) is not null then
        raise exception 'brickworks: this profile cannot be followed' using errcode = 'P0001', hint = 'follows:blocked';
    end if;
    return new;
end;
$$;
create or replace trigger blocks_guard_follow
    before insert or update on public.follows
    for each row execute function public.blocks_guard_follow();

create or replace function public.blocks_guard_collection_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.block_between(new.follower, (select l.owner from public.model_collections l where l.id = new.collection)) is not null then
        raise exception 'brickworks: this collection cannot be followed' using errcode = 'P0001', hint = 'follows:blocked';
    end if;
    return new;
end;
$$;
create or replace trigger blocks_guard_collection_follow
    before insert or update on public.collection_follows
    for each row execute function public.blocks_guard_collection_follow();

create or replace function public.blocks_guard_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    owner_of uuid;
    answered uuid;
begin
    select s.owner into owner_of from public.shared_models s where s.id = new.model;
    if public.block_between(new.author, owner_of) is not null then
        raise exception 'brickworks: this model cannot be commented on' using errcode = 'P0001', hint = 'comments:blocked';
    end if;
    if new.parent is not null then
        select k.author into answered from public.model_comments k where k.id = new.parent;
        if public.block_between(new.author, answered) is not null then
            raise exception 'brickworks: this comment cannot be answered' using errcode = 'P0001', hint = 'comments:blocked';
        end if;
    end if;
    return new;
end;
$$;
create or replace trigger blocks_guard_comment
    before insert on public.model_comments
    for each row execute function public.blocks_guard_comment();

create or replace function public.blocks_guard_photo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.block_between(new.account, (select s.owner from public.shared_models s where s.id = new.model)) is not null then
        raise exception 'brickworks: no photo can be added to this model' using errcode = 'P0001', hint = 'photos:blocked';
    end if;
    return new;
end;
$$;
create or replace trigger blocks_guard_photo
    before insert on public.build_photos
    for each row execute function public.blocks_guard_photo();

-- ---------------------------------------------------------------------------
-- Who may call what: the server alone.

revoke all on function public.block_most() from public, anon, authenticated;
grant execute on function public.block_most() to service_role;
revoke all on function public.block_between(uuid, uuid) from public, anon, authenticated;
grant execute on function public.block_between(uuid, uuid) to service_role;
revoke all on function public.block_on(uuid, text, bigint) from public, anon, authenticated;
grant execute on function public.block_on(uuid, text, bigint) to service_role;
revoke all on function public.block_named(uuid, text[]) from public, anon, authenticated;
grant execute on function public.block_named(uuid, text[]) to service_role;
revoke all on function public.block_person(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.block_person(uuid, text, boolean) to service_role;
revoke all on function public.block_list(uuid) from public, anon, authenticated;
grant execute on function public.block_list(uuid) to service_role;
revoke all on function public.block_models(uuid, text[]) from public, anon, authenticated;
grant execute on function public.block_models(uuid, text[]) to service_role;
revoke all on function public.block_hidden(text, uuid) from public, anon, authenticated;
grant execute on function public.block_hidden(text, uuid) to service_role;
revoke all on function public.block_counts(uuid) from public, anon, authenticated;
grant execute on function public.block_counts(uuid) to service_role;
revoke all on function public.block_count_against(uuid) from public, anon, authenticated;
grant execute on function public.block_count_against(uuid) to service_role;
revoke all on function public.blocks_guard_follow() from public, anon, authenticated;
revoke all on function public.blocks_guard_collection_follow() from public, anon, authenticated;
revoke all on function public.blocks_guard_comment() from public, anon, authenticated;
revoke all on function public.blocks_guard_photo() from public, anon, authenticated;

notify pgrst, 'reload schema';
