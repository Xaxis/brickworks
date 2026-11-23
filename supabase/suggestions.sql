-- Suggested edits, 2026-11-23 (suggestedit; docs/PLAN.md row 5): a
-- remixer sends their change back, and the designer takes all of it or
-- part, in the studio, as a pull request is taken.
--
-- A remix's page says what it changed from the model it came from
-- (remix_changes.sql). Its maker may now send that change to the model's
-- designer: the designer hears of it in their Notifications at once (the
-- bell on every page and in the app), opens it in the studio as Compare
-- (/app?suggestion=<id>), and takes the whole change or the parts of it
-- they tick (api/_suggest.js). Nothing is taken until they tap Take; the
-- version they then publish names the remixer in its Versions and on the
-- model's page, and the remixer hears that it was taken.
--
-- Only additions, applied after shared_models.sql, versions.sql,
-- follows.sql (feed_who), block.sql (block_between) and notifications.sql
-- (notification_marks_of): one table, its indexes, and five functions. No
-- existing row, column or function is changed, and nothing is dropped.
-- Notifications' own functions are not replaced: api/_notifications.js
-- joins suggestion_notices' rows into notification_list's and
-- suggestion_new_count into notification_counts' count, read by the same
-- marks.
--
--   model_suggestions   one row per change sent:
--     id                its number, in /app?suggestion=<id>
--     model             the designer's model it is sent to
--     remix             the remix it is the change of (its remixed_from is
--                       model); both go with their model
--     remix_n           which version of the remix was sent
--     model_n           which version of the model it was compared with
--     by_account        who sent it: the remix's owner
--     designer          the model's owner when it was sent
--     note              what the remixer says of it, if anything
--     counts            what it changes, kind by kind (api/_suggest.js
--                       KINDS: added, removed, moved, recoloured, swapped,
--                       restepped)
--     status            open, taken, declined, or withdrawn (by the
--                       remixer, or by sending it again: the open one is
--                       brought up to date instead, one open a remix)
--     taken_n           the designer's version that took it
--     taken             what was taken, kind by kind
--     whole             whether all of it was taken
--     test              the checks' pool: a test account's to a test
--                       account's only
--     at                when it was sent (or sent again)
--     closed_at         when it was taken, declined or withdrawn
--
-- Who may do what: only the server, with the secret key. api/share.js
-- sends one for the remix's owner (suggestion_send, which refuses all it
-- must), reads one for its designer or its sender, closes one for its
-- designer, and marks it taken as the designer's publish names it. No key
-- a page has may read or write it: no grant, no policy.
--
-- Apply it before the code that uses it is deployed? Either order works:
-- the code before it never reads this table, and the code after it offers
-- no Send until the table answers (a missing table or function is caught).

create table if not exists public.model_suggestions (
    id          bigint generated always as identity primary key,
    model       text not null references public.shared_models (id) on delete cascade,
    remix       text not null references public.shared_models (id) on delete cascade,
    remix_n     integer not null check (remix_n >= 1),
    model_n     integer not null check (model_n >= 1),
    by_account  uuid not null references auth.users (id) on delete cascade,
    designer    uuid not null references auth.users (id) on delete cascade,
    note        text check (note is null or char_length(note) between 1 and 500),
    counts      jsonb not null default '{}'::jsonb,
    status      text not null default 'open' check (status in ('open', 'taken', 'declined', 'withdrawn')),
    taken_n     integer check (taken_n is null or taken_n >= 1),
    taken       jsonb,
    whole       boolean,
    test        boolean not null default false,
    at          timestamptz not null default now(),
    closed_at   timestamptz,
    check (model <> remix),
    check ((status = 'open') = (closed_at is null)),
    check ((status = 'taken') = (taken_n is not null))
);

alter table public.model_suggestions enable row level security;
revoke all on public.model_suggestions from public, anon, authenticated;
grant select, insert, update, delete on public.model_suggestions to service_role;

-- One open change a remix: sending it again brings that one up to date.
create unique index if not exists model_suggestions_open on public.model_suggestions (remix) where status = 'open';
-- A model's, its designer's and its sender's, newest first.
create index if not exists model_suggestions_model on public.model_suggestions (model, at desc);
create index if not exists model_suggestions_designer on public.model_suggestions (designer, at desc);
create index if not exists model_suggestions_by on public.model_suggestions (by_account, at desc);

-- How many changes one account may send in an hour.
create or replace function public.suggestion_hourly()
returns integer
language sql
immutable
as $$ select 20 $$;

-- Send the change of remix [p_remix] (version [p_remix_n]) to the model it
-- came from, compared with that model's version [p_model_n], for [p_by]:
-- {id, again} (again: the remix's open one brought up to date), or
-- {refused: why}: not_yours, not_a_remix, gone (either is not published),
-- own (the model is the sender's own), blocked (either way), pools (a
-- test account's and a real one's), hourly (too many this hour).
create or replace function public.suggestion_send(p_remix text, p_by uuid, p_remix_n integer, p_model_n integer,
                                                  p_note text default null, p_counts jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    remixed public.shared_models%rowtype;
    original public.shared_models%rowtype;
    kept bigint;
    v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
    if p_remix is null or p_by is null or p_remix_n is null or p_model_n is null or p_remix_n < 1 or p_model_n < 1 then
        return jsonb_build_object('refused', 'asked');
    end if;
    select * into remixed from public.shared_models m where m.id = p_remix;
    if not found or not remixed.published then
        return jsonb_build_object('refused', 'gone');
    end if;
    if remixed.owner <> p_by then
        return jsonb_build_object('refused', 'not_yours');
    end if;
    if remixed.remixed_from is null then
        return jsonb_build_object('refused', 'not_a_remix');
    end if;
    select * into original from public.shared_models m where m.id = remixed.remixed_from;
    if not found or not original.published then
        return jsonb_build_object('refused', 'gone');
    end if;
    if original.owner = p_by then
        return jsonb_build_object('refused', 'own');
    end if;
    if public.block_between(p_by, original.owner) is not null then
        return jsonb_build_object('refused', 'blocked');
    end if;
    if coalesce(remixed.test, false) <> coalesce(original.test, false) then
        return jsonb_build_object('refused', 'pools');
    end if;
    if v_note is not null and char_length(v_note) > 500 then
        v_note := left(v_note, 500);
    end if;
    -- Sent again: the open one, up to date, and heard of again.
    update public.model_suggestions s
       set remix_n = p_remix_n, model_n = p_model_n, note = v_note, counts = coalesce(p_counts, '{}'::jsonb), at = now()
     where s.remix = p_remix and s.status = 'open' and s.model = original.id
    returning s.id into kept;
    if kept is not null then
        return jsonb_build_object('id', kept, 'again', true);
    end if;
    -- An open one to another model (the remix's line moved): withdrawn.
    update public.model_suggestions s set status = 'withdrawn', closed_at = now()
     where s.remix = p_remix and s.status = 'open';
    if (select count(*) from public.model_suggestions s
         where s.by_account = p_by and s.at > now() - interval '1 hour') >= public.suggestion_hourly() then
        return jsonb_build_object('refused', 'hourly');
    end if;
    insert into public.model_suggestions (model, remix, remix_n, model_n, by_account, designer, note, counts, test)
    values (original.id, p_remix, p_remix_n, p_model_n, p_by, original.owner, v_note, coalesce(p_counts, '{}'::jsonb),
            coalesce(remixed.test, false))
    returning id into kept;
    return jsonb_build_object('id', kept, 'again', false);
end;
$$;

-- What [viewer] hears of suggested changes from after [since]: as
-- notification_list's rows ({kind, at, on, model, ...}), newest first, at
-- most 200. To a designer, each change sent to their model (kind
-- 'suggestion', under that model, [of_name] its name); to its sender, each
-- change of theirs that was taken (kind 'suggestion_taken', under their
-- remix, [of_name], with the model that took it, [of] and [name]). Nothing
-- whose model or remix is no longer published, nor across a block.
create or replace function public.suggestion_notices(viewer uuid, since timestamptz default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(r.row order by r.at desc), '[]'::jsonb)
      from (select x.at, x.row from (
              select s.at, jsonb_build_object('kind', 'suggestion', 'at', s.at, 'on', s.model, 'model', s.model,
                       'suggestion', s.id, 'remix', s.remix, 'name', r.name, 'of_name', m.name,
                       'by', public.feed_who(s.by_account),
                       'counts', s.counts, 'note', s.note, 'status', s.status, 'test', s.test) as row
                from public.model_suggestions s
                join public.shared_models m on m.id = s.model and m.published
                join public.shared_models r on r.id = s.remix and r.published
               where s.designer = viewer and m.owner = viewer and s.status <> 'withdrawn'
                 and s.at > coalesce(since, now() - interval '90 days')
                 and public.block_between(viewer, s.by_account) is null
              union all
              select s.closed_at, jsonb_build_object('kind', 'suggestion_taken', 'at', s.closed_at, 'on', s.remix,
                       'model', s.remix, 'of', s.model, 'suggestion', s.id, 'name', m.name, 'of_name', r.name,
                       'by', public.feed_who(s.designer), 'taken', s.taken, 'whole', s.whole, 'n', s.taken_n,
                       'test', s.test) as row
                from public.model_suggestions s
                join public.shared_models m on m.id = s.model and m.published
                join public.shared_models r on r.id = s.remix and r.published
               where s.by_account = viewer and r.owner = viewer and s.status = 'taken'
                 and s.closed_at > coalesce(since, now() - interval '90 days')
                 and public.block_between(viewer, s.designer) is null
            ) x
            order by x.at desc
            limit 200) r
     where viewer is not null
$$;

-- How many of suggestion_notices' rows came since [viewer] last opened
-- their notifications (notification_marks_of's seen_at), at most 99, as
-- notification_counts counts its own.
create or replace function public.suggestion_new_count(viewer uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select least(jsonb_array_length(public.suggestion_notices(viewer,
               greatest(coalesce((select k.seen_at from public.notification_marks_of(viewer) k), '-infinity'),
                        now() - interval '90 days'))), 99)
     where viewer is not null
$$;

-- The changes of model [p_model] that [viewer] may see: {open: the ones
-- not yet taken or declined, for its designer only (null for anybody
-- else), taken: every one its versions took, with whom each names}.
create or replace function public.suggestion_list(p_model text, viewer uuid default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'open', case when m.owner = viewer then coalesce((
            select jsonb_agg(jsonb_build_object('id', s.id, 'remix', s.remix, 'name', r.name, 'remix_n', s.remix_n,
                     'model_n', s.model_n, 'by', public.feed_who(s.by_account), 'note', s.note, 'counts', s.counts,
                     'at', s.at) order by s.at desc)
              from public.model_suggestions s
              join public.shared_models r on r.id = s.remix and r.published
             where s.model = m.id and s.status = 'open' and public.block_between(viewer, s.by_account) is null),
            '[]'::jsonb) end,
        'taken', coalesce((
            select jsonb_agg(jsonb_build_object('id', s.id, 'n', s.taken_n, 'remix', s.remix, 'name', r.name,
                     'by', public.feed_who(s.by_account), 'taken', s.taken, 'whole', s.whole, 'at', s.closed_at)
                     order by s.taken_n desc, s.id desc)
              from public.model_suggestions s
              join public.shared_models r on r.id = s.remix
             where s.model = m.id and s.status = 'taken'), '[]'::jsonb))
      from public.shared_models m
     where m.id = p_model
$$;

-- Close suggestion [p_id] for [p_account]: its designer takes it, as
-- version [p_n] of their model is published with it ('taken', with what
-- was taken, [p_taken], and [p_whole]), or declines it ('declined'); its
-- sender withdraws it ('withdrawn'). {closed: true, by, remix, model}, or
-- {refused: why}: none (no such one open for them), asked.
create or replace function public.suggestion_close(p_id bigint, p_account uuid, p_status text,
                                                   p_n integer default null, p_taken jsonb default null,
                                                   p_whole boolean default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    one public.model_suggestions%rowtype;
begin
    if p_id is null or p_account is null or p_status not in ('taken', 'declined', 'withdrawn')
       or (p_status = 'taken' and (p_n is null or p_n < 1)) then
        return jsonb_build_object('refused', 'asked');
    end if;
    select * into one from public.model_suggestions s where s.id = p_id for update;
    if not found or one.status <> 'open'
       or (p_status in ('taken', 'declined') and (one.designer <> p_account
           or not exists (select 1 from public.shared_models m where m.id = one.model and m.owner = p_account)))
       or (p_status = 'withdrawn' and one.by_account <> p_account) then
        return jsonb_build_object('refused', 'none');
    end if;
    update public.model_suggestions s
       set status = p_status, closed_at = now(),
           taken_n = case when p_status = 'taken' then p_n end,
           taken = case when p_status = 'taken' then coalesce(p_taken, '{}'::jsonb) end,
           whole = case when p_status = 'taken' then coalesce(p_whole, false) end
     where s.id = p_id;
    return jsonb_build_object('closed', true, 'by', one.by_account, 'remix', one.remix, 'model', one.model);
end;
$$;

revoke all on function public.suggestion_hourly() from public, anon, authenticated;
grant execute on function public.suggestion_hourly() to service_role;
revoke all on function public.suggestion_send(text, uuid, integer, integer, text, jsonb) from public, anon, authenticated;
grant execute on function public.suggestion_send(text, uuid, integer, integer, text, jsonb) to service_role;
revoke all on function public.suggestion_notices(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.suggestion_notices(uuid, timestamptz) to service_role;
revoke all on function public.suggestion_new_count(uuid) from public, anon, authenticated;
grant execute on function public.suggestion_new_count(uuid) to service_role;
revoke all on function public.suggestion_list(text, uuid) from public, anon, authenticated;
grant execute on function public.suggestion_list(text, uuid) to service_role;
revoke all on function public.suggestion_close(bigint, uuid, text, integer, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.suggestion_close(bigint, uuid, text, integer, jsonb, boolean) to service_role;
