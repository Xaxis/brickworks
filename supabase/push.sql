-- Push: your notifications on your phone or computer, within the minute,
-- on each device you turned them on for (homescreen, 2026-11-22;
-- docs/SOCIAL.md, the units' rank 4; api/_push.js sends).
--
--   push_subscriptions   one row a device: a browser's push endpoint and
--                        its two keys, whose account it is, the address it
--                        was turned on at (links open there) and the
--                        language its pushes are said in. A device is one
--                        account's: turned on by another, it moves.
--   push_due             the accounts with something to push: marked by
--                        the triggers below as a row they hear of is written,
--                        taken by push_take.
--   push_sent            what was pushed, each notification once (two days).
--
-- Notifications are not rows of their own: notification_rows reads them
-- from comments, mentions, build photos, remixes and challenges as the
-- page is opened. So each of those tables gets a trigger that marks whoever
-- may hear of a new row due (only those with a device, and never the one
-- who wrote it), and push_take reads each one's new rows from
-- notification_rows itself, the page's own, so every rule of what is shown
-- holds for a push too. A mark too many costs a read that finds nothing.
--
-- Marked, the database knocks on the live site (pg_net, POST
-- /api/people?op=push_send), which sends at once; pg_cron knocks each
-- minute while anybody is due, in case a knock was lost. Without pg_net
-- and pg_cron nothing knocks, and a push goes only from a comment made
-- through the site (api/_comments.js). Nothing here can fail a write: a
-- trigger's trouble is a warning in the log.
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables. Every
-- row goes with its account (on delete cascade): deleting the account
-- deletes its devices.
--
-- Only additions, applied after announce.sql (notification_rows as it is
-- now), replies.sql (model_comments.parent), comment_mentions.sql,
-- builds.sql, gallery.sql (shared_models.remixed_from) and challenges.sql:
-- three new tables, new functions, five new triggers and a pg_cron job.
-- No existing row is changed, no function replaced, nothing dropped or
-- renamed.

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.push_subscriptions (
    endpoint  text primary key check (char_length(endpoint) between 12 and 1000 and endpoint like 'https://%'),
    account   uuid not null references auth.users (id) on delete cascade,
    p256dh    text not null check (p256dh ~ '^[A-Za-z0-9_-]{86,88}={0,2}$'),
    auth      text not null check (auth ~ '^[A-Za-z0-9_-]{21,24}={0,2}$'),
    origin    text not null check (origin ~ '^https?://[a-z0-9.:-]{1,200}$'),
    lang      text not null default 'en' check (lang in ('en', 'de', 'fr', 'es')),
    made_at   timestamptz not null default now()
);
create index if not exists push_subscriptions_account on public.push_subscriptions (account);

create table if not exists public.push_due (
    account  uuid primary key references auth.users (id) on delete cascade,
    at       timestamptz not null default now()
);

create table if not exists public.push_sent (
    account  uuid not null references auth.users (id) on delete cascade,
    key      text not null check (char_length(key) <= 200),
    at       timestamptz not null default now(),
    primary key (account, key)
);
create index if not exists push_sent_at on public.push_sent (at);

alter table public.push_subscriptions enable row level security;
alter table public.push_due enable row level security;
alter table public.push_sent enable row level security;
revoke all on public.push_subscriptions from public, anon, authenticated, service_role;
revoke all on public.push_due from public, anon, authenticated, service_role;
revoke all on public.push_sent from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Devices.

-- [p_endpoint] on for [p_account]: {on, devices}. At most 20 devices an
-- account, the newest; one turned on again keeps when it was first turned
-- on, unless it was another account's.
create or replace function public.push_subscribe(p_account uuid, p_endpoint text, p_p256dh text, p_auth text,
                                                 p_origin text, p_lang text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_account is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    insert into public.push_subscriptions as s (endpoint, account, p256dh, auth, origin, lang)
    values (p_endpoint, p_account, p_p256dh, p_auth, p_origin, coalesce(p_lang, 'en'))
    on conflict (endpoint) do update
       set account = excluded.account, p256dh = excluded.p256dh, auth = excluded.auth, origin = excluded.origin,
           lang = excluded.lang, made_at = case when s.account = excluded.account then s.made_at else now() end;
    delete from public.push_subscriptions s
     where s.account = p_account
       and s.endpoint in (select x.endpoint from public.push_subscriptions x where x.account = p_account
                           order by x.made_at desc offset 20);
    return jsonb_build_object('on', true,
        'devices', (select count(*) from public.push_subscriptions s where s.account = p_account));
end;
$$;

-- [p_endpoint] off for [p_account]: {on: false, devices}.
create or replace function public.push_unsubscribe(p_account uuid, p_endpoint text)
returns jsonb
language sql
security definer
set search_path = public
as $$
    with gone as (
        delete from public.push_subscriptions s where s.account = p_account and s.endpoint = p_endpoint returning 1)
    select jsonb_build_object('on', false,
        'devices', (select count(*) from public.push_subscriptions s
                     where s.account = p_account and s.endpoint <> p_endpoint))
$$;

-- Whether [p_endpoint] is on for [p_account]: {on, devices}.
create or replace function public.push_subscribed(p_account uuid, p_endpoint text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'on', exists (select 1 from public.push_subscriptions s where s.account = p_account and s.endpoint = p_endpoint),
        'devices', (select count(*) from public.push_subscriptions s where s.account = p_account))
$$;

-- A device its push service says is gone (404 or 410), deleted.
create or replace function public.push_gone(p_endpoint text)
returns jsonb
language sql
security definer
set search_path = public
as $$
    with gone as (delete from public.push_subscriptions s where s.endpoint = p_endpoint returning 1)
    select jsonb_build_object('gone', (select count(*) from gone))
$$;

-- ---------------------------------------------------------------------------
-- Marking who is due, and knocking.

-- A knock on the live site, which sends what is due. Nothing without pg_net.
create or replace function public.push_knock()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if to_regnamespace('net') is not null then
        perform net.http_post(url := 'https://brickworks.diy/api/people?op=push_send', body := '{}'::jsonb);
    end if;
exception when others then
    raise warning 'push_knock: %', sqlerrm;
end;
$$;

-- Of [accounts], those with a device marked due, and a knock if any was not.
create or replace function public.push_mark(accounts uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    marked integer;
begin
    insert into public.push_due (account)
    select distinct s.account from public.push_subscriptions s where s.account = any (accounts)
    on conflict (account) do nothing;
    get diagnostics marked = row_count;
    if marked > 0 then
        perform public.push_knock();
    end if;
exception when others then
    raise warning 'push_mark: %', sqlerrm;
end;
$$;

-- A comment or a reply: the model's owner, and everybody in its thread.
create or replace function public.push_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.push_mark(array(
        select x.account from (
            select m.owner as account from public.shared_models m where m.id = new.model
            union
            select o.author from public.model_comments o
             where new.parent is not null and (o.id = new.parent or o.parent = new.parent)) x
         where x.account <> new.author));
    return null;
exception when others then
    raise warning 'push_on_comment: %', sqlerrm;
    return null;
end;
$$;

-- Named in a comment.
create or replace function public.push_on_mention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.push_mark(array[new.account]);
    return null;
exception when others then
    raise warning 'push_on_mention: %', sqlerrm;
    return null;
end;
$$;

-- A photo of a build: the model's owner.
create or replace function public.push_on_photo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.push_mark(array(
        select m.owner from public.shared_models m where m.id = new.model and m.owner <> new.account));
    return null;
exception when others then
    raise warning 'push_on_photo: %', sqlerrm;
    return null;
end;
$$;

-- A remix listed in the gallery: the owner of the model it remixes.
create or replace function public.push_on_remix()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.remixed_from is not null and new.published and new.listed and new.listed_at is not null
       and (tg_op = 'INSERT' or old.listed_at is distinct from new.listed_at or old.listed is distinct from new.listed) then
        perform public.push_mark(array(
            select o.owner from public.shared_models o where o.id = new.remixed_from and o.owner <> new.owner));
    end if;
    return null;
exception when others then
    raise warning 'push_on_remix: %', sqlerrm;
    return null;
end;
$$;

-- A challenge settled: everybody who entered it.
create or replace function public.push_on_settled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if old.settled_at is null and new.settled_at is not null then
        perform public.push_mark(array(select distinct e.owner from public.challenge_entries e where e.challenge = new.id));
    end if;
    return null;
exception when others then
    raise warning 'push_on_settled: %', sqlerrm;
    return null;
end;
$$;

drop trigger if exists push_on_comment on public.model_comments;
create trigger push_on_comment after insert on public.model_comments
    for each row execute function public.push_on_comment();
drop trigger if exists push_on_mention on public.comment_mentions;
create trigger push_on_mention after insert on public.comment_mentions
    for each row execute function public.push_on_mention();
drop trigger if exists push_on_photo on public.build_photos;
create trigger push_on_photo after insert on public.build_photos
    for each row execute function public.push_on_photo();
drop trigger if exists push_on_remix on public.shared_models;
create trigger push_on_remix after insert or update of listed_at, listed, published on public.shared_models
    for each row execute function public.push_on_remix();
drop trigger if exists push_on_settled on public.challenges;
create trigger push_on_settled after update of settled_at on public.challenges
    for each row execute function public.push_on_settled();

-- ---------------------------------------------------------------------------
-- Taking what is due.

-- Up to [p_most] due accounts taken, each with its new notifications of
-- the kinds pushed and its devices: [{account, rows, devices}], a row as
-- notification_list says one ({kind, at, on, ...item}), a device
-- {endpoint, p256dh, auth, origin, lang, made_at}. New is not pushed
-- before, after the account's first device was turned on, and in the last
-- half hour. Taken is pushed: what is returned is not returned again.
create or replace function public.push_take(p_most integer default 25)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    taken uuid[];
    one uuid;
    since timestamptz;
    fresh jsonb;
    result jsonb := '[]'::jsonb;
begin
    delete from public.push_sent s where s.at < now() - interval '2 days';
    with picked as (
        select d.account from public.push_due d order by d.at
         limit least(greatest(coalesce(p_most, 25), 1), 100) for update skip locked),
    gone as (
        delete from public.push_due d using picked p where d.account = p.account returning d.account)
    select coalesce(array_agg(g.account), '{}') into taken from gone g;
    foreach one in array taken loop
        begin
            select min(s.made_at) into since from public.push_subscriptions s where s.account = one;
            continue when since is null;
            with rows as (
                select distinct on (k.key) k.key, r.kind, r.at, r.model, r.item
                  from public.notification_rows(one, greatest(since, now() - interval '30 minutes'), now()) r
                 cross join lateral (select left(r.kind || ':' || coalesce(r.item->>'comment', r.item->>'photo',
                                         r.item->>'challenge', '') || ':' || coalesce(r.item->>'model', r.model, ''), 200) as key) k
                 where r.kind in ('comment', 'reply', 'mention', 'photo', 'remix', 'result')
                 order by k.key, r.at desc),
            kept as (
                insert into public.push_sent (account, key)
                select one, w.key from rows w
                on conflict (account, key) do nothing
                returning push_sent.key)
            select coalesce(jsonb_agg(jsonb_build_object('kind', w.kind, 'at', w.at, 'on', w.model) || w.item
                                      order by w.at desc), '[]'::jsonb)
              into fresh
              from rows w join kept k on k.key = w.key;
            if jsonb_array_length(fresh) > 0 then
                result := result || jsonb_build_array(jsonb_build_object('account', one, 'rows', fresh,
                    'devices', (select coalesce(jsonb_agg(jsonb_build_object('endpoint', s.endpoint, 'p256dh', s.p256dh,
                                    'auth', s.auth, 'origin', s.origin, 'lang', s.lang, 'made_at', s.made_at)), '[]'::jsonb)
                                  from public.push_subscriptions s where s.account = one)));
            end if;
        exception when others then
            raise warning 'push_take: %', sqlerrm;
        end;
    end loop;
    return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone, and only what the server calls.

revoke all on function public.push_subscribe(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.push_subscribe(uuid, text, text, text, text, text) to service_role;
revoke all on function public.push_unsubscribe(uuid, text) from public, anon, authenticated;
grant execute on function public.push_unsubscribe(uuid, text) to service_role;
revoke all on function public.push_subscribed(uuid, text) from public, anon, authenticated;
grant execute on function public.push_subscribed(uuid, text) to service_role;
revoke all on function public.push_gone(text) from public, anon, authenticated;
grant execute on function public.push_gone(text) to service_role;
revoke all on function public.push_take(integer) from public, anon, authenticated;
grant execute on function public.push_take(integer) to service_role;
revoke all on function public.push_knock() from public, anon, authenticated, service_role;
revoke all on function public.push_mark(uuid[]) from public, anon, authenticated, service_role;
revoke all on function public.push_on_comment() from public, anon, authenticated, service_role;
revoke all on function public.push_on_mention() from public, anon, authenticated, service_role;
revoke all on function public.push_on_photo() from public, anon, authenticated, service_role;
revoke all on function public.push_on_remix() from public, anon, authenticated, service_role;
revoke all on function public.push_on_settled() from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The minute's knock, while anybody is due: where pg_cron and pg_net are
-- installed (trust.sql installs them where Supabase offers them).
do $knock$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron')
       and exists (select 1 from pg_extension where extname = 'pg_net') then
        perform cron.schedule('brickworks-push', '* * * * *',
            $job$select public.push_knock() where exists (select 1 from public.push_due)$job$);
    end if;
end
$knock$;

notify pgrst, 'reload schema';
