-- Comments pinned to a part, 2026-11-23 (partpins, docs/MASTERPLAN.md row 6).
--
-- A comment sat under the model, and its designer had to find the brick it
-- meant. Now somebody looking at a shared model in 3D (its page's view, or
-- the app's viewer) can press a part and say something about that part: a
-- pin. A pin is a comment, kept in model_comments with every rule of one
-- (comments.sql, replies.sql, comment_mentions.sql, block.sql): who may
-- write, how often (a pin counts as a comment: 10 an hour, 50 a day), what
-- (1 to 1,000 characters of plain text), mentions, reports, blocks, Hide,
-- Remove and comments off. What it adds is where:
--
--   model_comments.pin          the part, as the file of the comment's
--                               version had it: {part, colour, at, turn,
--                               section, line, near, full, with}. [at] is
--                               where the part stood (LDraw's coordinates,
--                               LDU), [turn] how it was turned (nine
--                               numbers), [section] and [line] the line that
--                               placed it, [near] where the others of its
--                               number and colour stood within 24 LDU of it
--                               (at most 48; full false when there were
--                               more), [with] the other parts standing where
--                               it stood (a window's glass in its frame). The
--                               server works it out from the version's own
--                               file (api/_comments.js); nothing a page
--                               says of a part is kept but its number,
--                               colour and place, which it checks against
--                               the file. Null for a comment on no part, and
--                               always for a reply, which is on its
--                               comment's part.
--   model_comments.resolved_at  when the model's owner said it was done with
--                               (Resolve, in the studio), or null. Shown to
--                               everybody as resolved, folded away; opened
--                               again by its owner as easily.
--
-- Which part of another version a pin is on is worked out by whoever shows
-- it, from that version's parts, by one rule (web/card.js pinPlace,
-- src/net/pin_place.gd): nothing here moves a pin, and nothing written is
-- changed by a new version.
--
-- Functions replaced, each as replies.sql left it but for what is said
-- beside it:
--
--   comment_as    says pin and resolved_at
--   comments_on   says pins: true, so the API knows a pin can be written
--
-- And new: pin_shaped (what a place must be, for the check and add_pin),
-- add_pin (a comment and its part, in one), resolve_pin (the
-- model's owner: done with, or not), comment_pins_of (which of some
-- comments are pins, for the notifications and the day's email, which say
-- "on a part"), and a trigger that keeps a pin as it was written.
--
-- Who may touch what is as it was: the server, through the functions, each
-- security definer and granted to the service role alone. Only additions,
-- applied after comments.sql and replies.sql (it replaces two of
-- replies.sql's functions; supabase/later.tsv says so, and
-- tools/apply_sql.mjs refuses replies.sql applied again alone): two
-- nullable columns and their check and index, functions, a trigger. No row
-- is changed, nothing dropped or renamed. Apply it before the code that
-- writes pins is deployed; until then the API says pins: false and the
-- pages and the app offer none.

-- ---------------------------------------------------------------------------
-- The columns.

-- A place as a pin keeps one: an object of at most 8,000 bytes, with its
-- part's number (text), colour (a number) and where it stood (three
-- numbers). False, never null, for anything else, a key missing included.
create or replace function public.pin_shaped(place jsonb)
returns boolean
language sql
immutable
set search_path = public
as $$
    select coalesce(case when jsonb_typeof(place) = 'object' and jsonb_typeof(place -> 'at') = 'array' then
        octet_length(place::text) <= 8000
        and jsonb_typeof(place -> 'part') = 'string' and jsonb_typeof(place -> 'colour') = 'number'
        and jsonb_array_length(place -> 'at') = 3
        and jsonb_typeof(place -> 'at' -> 0) = 'number' and jsonb_typeof(place -> 'at' -> 1) = 'number'
        and jsonb_typeof(place -> 'at' -> 2) = 'number'
    end, false)
$$;

alter table public.model_comments
    add column if not exists pin jsonb,
    add column if not exists resolved_at timestamptz;
do $$
begin
    if not exists (select 1 from pg_constraint
                    where conname = 'model_comments_pin_shape' and conrelid = 'public.model_comments'::regclass) then
        alter table public.model_comments
            add constraint model_comments_pin_shape check (pin is null or public.pin_shaped(pin));
    end if;
    if not exists (select 1 from pg_constraint
                    where conname = 'model_comments_resolved_pinned' and conrelid = 'public.model_comments'::regclass) then
        alter table public.model_comments
            add constraint model_comments_resolved_pinned check (resolved_at is null or pin is not null);
    end if;
end
$$;
-- A model's pins, open first: what the studio's list asks for.
create index if not exists model_comments_pins on public.model_comments (model, at) where pin is not null;

-- ---------------------------------------------------------------------------
-- A pin stays as it was written: set once, on a comment of its own (never a
-- reply), whatever writes.

create or replace function public.comment_pins_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'INSERT' and new.pin is not null and new.parent is not null then
        raise exception 'brickworks: a reply is on its comment''s part'
            using errcode = 'P0001', hint = 'comments:pin';
    end if;
    if tg_op = 'UPDATE' and new.pin is distinct from old.pin
       and (old.pin is not null or new.parent is not null or old.at < now() - interval '5 minutes') then
        raise exception 'brickworks: a pin stays on the part it was made on'
            using errcode = 'P0001', hint = 'comments:pin';
    end if;
    return new;
end;
$$;
create or replace trigger comment_pins_guard
    before insert or update on public.model_comments
    for each row execute function public.comment_pins_guard();

-- ---------------------------------------------------------------------------
-- What a comment says.

-- A comment as an answer gives it, as replies.sql's, and its part (pin) and
-- when its pin was resolved (resolved_at), each null for none.
create or replace function public.comment_as(c public.model_comments, asker uuid, owner uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', c.id, 'version', c.version, 'step', c.step, 'body', c.body,
        'at', c.at, 'edited_at', c.edited_at,
        'hidden', c.hidden_at is not null,
        'mine', asker is not null and c.author = asker,
        'by_owner', c.author = owner,
        'by', p.name, 'handle', p.handle,
        'parent', c.parent,
        'pin', c.pin, 'resolved_at', c.resolved_at)
      from (select 1) as one
      left join public.people p on p.account = c.author
$$;

-- What a model's page and its viewer show, as replies.sql's, and pins: true,
-- so the API knows a pin can be written here.
create or replace function public.comments_on(model_id text, asker uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    since timestamptz;
    listed jsonb;
begin
    select * into m from public.shared_models s where s.id = model_id and s.published;
    if not found then
        return null;
    end if;
    -- This life of the link: from its first version, which a takedown and
    -- a share again begins anew.
    select min(v.at) into since from public.share_versions v where v.model = model_id;
    with seen as (
        select k.id, k.parent, k.at from public.model_comments k
         where k.model = model_id and k.removed_at is null
           and (since is null or k.at >= since)
           and (k.hidden_at is null or (asker is not null and (k.author = asker or m.owner = asker)))
           and public.shown_publicly(k.author)),
    threads as (
        select s.id from seen s where s.parent is null order by s.at desc, s.id desc limit 500)
    select coalesce(jsonb_agg(public.comment_as(c, asker, m.owner) order by c.at, c.id), '[]'::jsonb)
      into listed
      from public.model_comments c
     where c.id in (select s.id from seen s
                     where s.id in (select t.id from threads t) or s.parent in (select t.id from threads t));
    return jsonb_build_object('open', public.comments_open(model_id),
        'owner', asker is not null and asker = m.owner, 'comments', listed, 'threads', true, 'pins', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Writing one, and resolving one.

-- A comment from [account] on [model_id]'s version [at_version] (and step
-- [at_step], or none), on the part [place] says (api/_comments.js worked it
-- out from that version's file): {comment, owner} as add_comment gives
-- them, the comment with its pin, or {refused} with add_comment's reasons
-- and place (not a part's).
create or replace function public.add_pin(
    account uuid, model_id text, at_version integer, at_step integer, said text, place jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    made jsonb;
    c public.model_comments;
begin
    if not public.pin_shaped(place) then
        return jsonb_build_object('refused', 'place');
    end if;
    made := public.add_comment(account, model_id, at_version, at_step, said);
    if made ? 'refused' then
        return made;
    end if;
    update public.model_comments set pin = place where id = (made -> 'comment' ->> 'id')::bigint
    returning * into c;
    return jsonb_build_object('comment', public.comment_as(c, account, (made ->> 'owner')::uuid),
        'owner', made -> 'owner');
end;
$$;

-- The model's owner done with pin [comment_id] ([done] true), or not
-- ([done] false): {comment}, or {refused}: no_comment (none, removed, not a
-- pin), not_owner, limit (60 an hour, 300 a day, as hiding one).
create or replace function public.resolve_pin(account uuid, comment_id bigint, done boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.model_comments;
    owner_of uuid;
begin
    select * into c from public.model_comments k
     where k.id = comment_id and k.removed_at is null and k.pin is not null;
    if not found or account is null or done is null then
        return jsonb_build_object('refused', 'no_comment');
    end if;
    select s.owner into owner_of from public.shared_models s where s.id = c.model;
    if owner_of is distinct from account then
        return jsonb_build_object('refused', 'not_owner');
    end if;
    if not public.may_act(account::text, 'pin_resolve', 60, 300) then
        return jsonb_build_object('refused', 'limit');
    end if;
    update public.model_comments
       set resolved_at = case when done then coalesce(resolved_at, now()) end
     where id = c.id
    returning * into c;
    return jsonb_build_object('comment', public.comment_as(c, account, owner_of));
end;
$$;

-- Which of [comment_ids] are pins: [{comment, resolved}], one a pin. What
-- the notifications, a push and the day's email say "on a part" by.
create or replace function public.comment_pins_of(comment_ids bigint[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('comment', k.id, 'resolved', k.resolved_at is not null)
                    order by k.id), '[]'::jsonb)
      from public.model_comments k
     where k.id = any(comment_ids) and k.pin is not null
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.pin_shaped(jsonb) from public, anon, authenticated;
grant execute on function public.pin_shaped(jsonb) to service_role;
revoke all on function public.comment_pins_guard() from public, anon, authenticated;
revoke all on function public.comment_as(public.model_comments, uuid, uuid) from public, anon, authenticated;
grant execute on function public.comment_as(public.model_comments, uuid, uuid) to service_role;
revoke all on function public.comments_on(text, uuid) from public, anon, authenticated;
grant execute on function public.comments_on(text, uuid) to service_role;
revoke all on function public.add_pin(uuid, text, integer, integer, text, jsonb) from public, anon, authenticated;
grant execute on function public.add_pin(uuid, text, integer, integer, text, jsonb) to service_role;
revoke all on function public.resolve_pin(uuid, bigint, boolean) from public, anon, authenticated;
grant execute on function public.resolve_pin(uuid, bigint, boolean) to service_role;
revoke all on function public.comment_pins_of(bigint[]) from public, anon, authenticated;
grant execute on function public.comment_pins_of(bigint[]) to service_role;
