-- Comments on a shared model, and on a single step of it, 2026-10-18.
--
-- A builder halfway through a shared model had nowhere to say "this part
-- goes under, not over", or to thank its designer. Now anybody may read
-- what was said about a model on its page (/m/<id>) and on each step in
-- the viewer and the step player, and an account that may go public
-- (trust.sql) may say something: about the model, or about one step of
-- the version it is looking at. Comments are the first place on
-- brickworks.diy where strangers write to each other, so the ground rules
-- come with them, here, whatever asks:
--
--   Who may write  a signed-in account that answered the age question 13
--                  or over (trust_may_go_public), not taken out of the
--                  gallery (is_barred), on a published model whose owner
--                  has not turned comments off, which is not taken out of
--                  the gallery itself, and whose owner is not under 13
--                  (strangers do not write to a child: a model of an
--                  account kept private is closed, and says only that
--                  comments are off).
--   How often      10 an hour and 50 a day for one account; 20 edits an
--                  hour and 100 a day; 60 hides an hour and 300 a day for
--                  a model's owner (may_act, moderation.sql).
--   What           1 to 1,000 characters of plain text: no markup, no
--                  control characters but a line's end. A link typed is
--                  shown as the words it is, never as a link. Words the
--                  gallery does not show are refused by the API first
--                  (api/_names.js), which the database cannot read.
--   Moderation     the author may edit or remove their own; the model's
--                  owner may hide one on their model, or show it again,
--                  and turn comments off on it, or on again; anybody may
--                  report one (reports.comment), which reaches the site's
--                  owner by email within the hour as any report does; the
--                  site's owner removes one from the admin page. Nothing
--                  is deleted: removed and hidden are times kept on the
--                  row. A comment by an account taken out of the gallery,
--                  or by one that said it is under 13, is not shown.
--
--   model_comments     one row a comment: its model, the version it was
--                      written on, the step of that version or none (the
--                      whole model), its author, its words, and when it
--                      was written, edited, hidden by the model's owner,
--                      and removed (by its author or by the site's owner)
--   comment_settings   a model's owner's choice: comments on or off
--   mail_choices       what an account wants emailed: comments on its
--                      models, at most once a day. Off by default: trust.sql
--                      keeps no email preferences, so nobody is emailed a
--                      comment until they say so (/profile)
--   comment_digests    each such email: whose, when, how it went, how
--                      many comments; for a test's, the email as rendered,
--                      and never sent (a dry run, as report_digests)
--   reports.comment    which comment a report is about. Its model is the
--                      comment's, so a report names one thing as before
--                      (moderation.sql's check) and is about the comment
--
-- A comment belongs to this life of its link: a model taken down and
-- shared again starts at version 1 again, and what was said about the
-- one before is kept but not shown (comments_on reads from the first
-- version's time).
--
-- Who may touch what: only the server, and only through the functions
-- here, each security definer and granted to the service role alone. No
-- key a page has, and not the service role itself, may read or write the
-- new tables directly; the trigger refuses a comment that breaks the
-- rules whatever writes it.
--
-- Only additions, applied after trust.sql (it reads trust_may_go_public
-- and replaces two of its functions, the same but for comments): new
-- tables, a column on reports and an index, functions, a trigger. No
-- existing row is changed, nothing is dropped or renamed. Apply it before
-- the code that reads it is deployed: api/admin.js reads reports.comment.

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.comment_digests (
    id        bigserial primary key,
    owner     uuid not null references auth.users (id) on delete cascade,
    at        timestamptz not null default now(),
    state     text not null default 'sending' check (state in ('sending', 'sent', 'failed', 'dry')),
    comments  integer not null default 0 check (comments >= 0),
    -- As rendered, for a test's dry run only: what went to an owner is in
    -- their inbox, and is not kept twice.
    subject   text check (subject is null or char_length(subject) <= 300),
    body      text check (body is null or char_length(body) <= 100000),
    html      text check (html is null or char_length(html) <= 200000)
);
create index if not exists comment_digests_owner on public.comment_digests (owner, at desc);

create table if not exists public.model_comments (
    id          bigserial primary key,
    model       text not null references public.shared_models (id) on delete cascade,
    version     integer not null check (version between 1 and 100000),
    step        integer check (step is null or step between 1 and 200000),
    author      uuid not null references auth.users (id) on delete cascade,
    body        text not null check (char_length(body) between 1 and 1000
                    and body ~ '[^[:space:]]' and body !~ '[\x01-\x09\x0b-\x1f\x7f]'),
    at          timestamptz not null default now(),
    edited_at   timestamptz check (edited_at is null or edited_at >= at),
    hidden_at   timestamptz,
    removed_at  timestamptz,
    removed_by  text check (removed_by is null or removed_by in ('author', 'admin')),
    -- Which email told the model's owner of it.
    digest      bigint references public.comment_digests (id) on delete set null,
    check ((removed_at is null) = (removed_by is null))
);
create index if not exists model_comments_model on public.model_comments (model, at);
create index if not exists model_comments_author on public.model_comments (author, at desc);
create index if not exists model_comments_waiting on public.model_comments (model) where digest is null and removed_at is null;

create table if not exists public.comment_settings (
    model  text primary key references public.shared_models (id) on delete cascade,
    open   boolean not null default true,
    at     timestamptz not null default now()
);

create table if not exists public.mail_choices (
    account   uuid primary key references auth.users (id) on delete cascade,
    comments  boolean not null default false,
    at        timestamptz not null default now()
);

alter table public.model_comments enable row level security;
alter table public.comment_settings enable row level security;
alter table public.mail_choices enable row level security;
alter table public.comment_digests enable row level security;
revoke all on public.model_comments from public, anon, authenticated, service_role;
revoke all on public.comment_settings from public, anon, authenticated, service_role;
revoke all on public.mail_choices from public, anon, authenticated, service_role;
revoke all on public.comment_digests from public, anon, authenticated, service_role;
revoke all on sequence public.model_comments_id_seq from public, anon, authenticated, service_role;
revoke all on sequence public.comment_digests_id_seq from public, anon, authenticated, service_role;

-- A report about a comment: the comment, and its model as the thing named.
alter table public.reports
    add column if not exists comment bigint references public.model_comments (id) on delete cascade;
do $$
begin
    if not exists (select 1 from pg_constraint
                    where conname = 'reports_comment_has_model' and conrelid = 'public.reports'::regclass) then
        alter table public.reports
            add constraint reports_comment_has_model check (comment is null or model is not null);
    end if;
end
$$;
create index if not exists reports_comment on public.reports (comment) where comment is not null;

-- ---------------------------------------------------------------------------
-- Who may write.

-- Why [account] may not comment on [model_id], or null when it may:
-- sign_in, no_model, barred, ask_first, under_13, closed. The API says
-- each in words (api/_comments.js).
create or replace function public.comment_trouble(account uuid, model_id text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    m public.shared_models;
begin
    if account is null then
        return 'sign_in';
    end if;
    select * into m from public.shared_models s where s.id = model_id;
    if not found or not m.published then
        return 'no_model';
    end if;
    if public.is_barred(account) then
        return 'barred';
    end if;
    if (select p.over_13 from public.profiles p where p.id = account) is null then
        return 'ask_first';
    end if;
    if not public.trust_may_go_public(account) then
        return 'under_13';
    end if;
    if m.barred or public.is_barred(m.owner) or public.trust_kept_private(m.owner)
       or exists (select 1 from public.comment_settings c where c.model = model_id and not c.open) then
        return 'closed';
    end if;
    return null;
end;
$$;

-- Whether a model takes comments now, whoever asks.
create or replace function public.comments_open(model_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce((
        select m.published and not m.barred and not public.is_barred(m.owner)
               and not public.trust_kept_private(m.owner)
               and coalesce((select c.open from public.comment_settings c where c.model = m.id), true)
          from public.shared_models m where m.id = model_id), false)
$$;

-- The refusals, whatever writes: a comment needs an author who may go
-- public and is not barred, on a model open to comments.
create or replace function public.comments_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'INSERT' or new.body is distinct from old.body then
        if not public.trust_may_go_public(new.author) then
            raise exception 'brickworks: comments are for accounts 13 or over'
                using errcode = 'P0001', hint = 'comments:age';
        end if;
        if public.is_barred(new.author) then
            raise exception 'brickworks: this account was taken out of the gallery'
                using errcode = 'P0001', hint = 'comments:barred';
        end if;
        if not public.comments_open(new.model) then
            raise exception 'brickworks: comments are off on this model'
                using errcode = 'P0001', hint = 'comments:closed';
        end if;
    end if;
    return new;
end;
$$;
create or replace trigger comments_guard
    before insert or update on public.model_comments
    for each row execute function public.comments_guard();
revoke all on function public.comments_guard() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- What a comment says, and to whom.

-- A comment as an answer gives it, to [asker]: never its author's
-- account, only the name and handle of their profile if they have one,
-- whether it is theirs, whether it is the model's owner's, and whether it
-- is hidden (which only its author and the model's owner are shown).
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
        'by', p.name, 'handle', p.handle)
      from (select 1) as one
      left join public.people p on p.account = c.author
$$;

-- What a model's page and its viewer show: {open, owner, comments}, the
-- comments oldest first, at most the newest 500. Hidden ones only to
-- their author and the model's owner; removed ones, and those of an
-- account barred or under 13, to nobody. Null for a model not published.
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
    select coalesce(jsonb_agg(public.comment_as(c, asker, m.owner) order by c.at, c.id), '[]'::jsonb)
      into listed
      from public.model_comments c
     where c.id in (select k.id from public.model_comments k
                     where k.model = model_id and k.removed_at is null
                       and (since is null or k.at >= since)
                       and (k.hidden_at is null or (asker is not null and (k.author = asker or m.owner = asker)))
                       and public.shown_publicly(k.author)
                     order by k.at desc, k.id desc
                     limit 500);
    return jsonb_build_object('open', public.comments_open(model_id),
        'owner', asker is not null and asker = m.owner, 'comments', listed);
end;
$$;

-- The model a comment anybody may report is on, or null.
create or replace function public.comment_model(comment_id bigint)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select c.model from public.model_comments c
      join public.shared_models m on m.id = c.model and m.published
     where c.id = comment_id and c.removed_at is null
$$;

-- ---------------------------------------------------------------------------
-- Writing, and changing what was written.

-- A comment from [account] on [model_id], on [at_version] and on step
-- [at_step] of it or on the whole model (null): {comment} as comment_as
-- gives it, or {refused} with comment_trouble's reasons and no_version,
-- no_step, body (not 1 to 1,000 characters of plain text) and limit (10
-- an hour, 50 a day).
create or replace function public.add_comment(
    account uuid, model_id text, at_version integer, at_step integer, said text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text := public.comment_trouble(account, model_id);
    steps_then integer;
    owner_of uuid;
    made public.model_comments;
begin
    if trouble is not null then
        return jsonb_build_object('refused', trouble);
    end if;
    select v.steps into steps_then from public.share_versions v where v.model = model_id and v.n = at_version;
    if not found then
        -- A link shared before its versions were kept is its version 1.
        if at_version = 1 and not exists (select 1 from public.share_versions v where v.model = model_id) then
            select s.steps into steps_then from public.shared_models s where s.id = model_id;
        else
            return jsonb_build_object('refused', 'no_version');
        end if;
    end if;
    if at_step is not null and (at_step < 1 or (steps_then is not null and at_step > steps_then)) then
        return jsonb_build_object('refused', 'no_step');
    end if;
    if said is null or char_length(said) not between 1 and 1000 or said !~ '[^[:space:]]'
       or said ~ '[\x01-\x09\x0b-\x1f\x7f]' then
        return jsonb_build_object('refused', 'body');
    end if;
    if not public.may_act(account::text, 'comment', 10, 50) then
        return jsonb_build_object('refused', 'limit');
    end if;
    insert into public.model_comments (model, version, step, author, body)
    values (model_id, at_version, at_step, account, said)
    returning * into made;
    select s.owner into owner_of from public.shared_models s where s.id = model_id;
    return jsonb_build_object('comment', public.comment_as(made, account, owner_of), 'owner', owner_of);
end;
$$;

-- A comment changed: its author edits it (what = 'edit', with [said]) or
-- removes it ('remove'); the model's owner hides it ('hide') or shows it
-- again ('show'). {comment}, or {refused}: no_comment, not_yours,
-- not_owner, body, limit, or comment_trouble's for an edit.
create or replace function public.change_comment(
    account uuid, comment_id bigint, what text, said text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.model_comments;
    owner_of uuid;
    trouble text;
begin
    select * into c from public.model_comments k where k.id = comment_id and k.removed_at is null;
    if not found or account is null then
        return jsonb_build_object('refused', 'no_comment');
    end if;
    select s.owner into owner_of from public.shared_models s where s.id = c.model;
    if what in ('edit', 'remove') and c.author <> account then
        return jsonb_build_object('refused', 'not_yours');
    end if;
    if what in ('hide', 'show') and owner_of is distinct from account then
        return jsonb_build_object('refused', 'not_owner');
    end if;
    if what = 'edit' then
        trouble := public.comment_trouble(account, c.model);
        if trouble is not null then
            return jsonb_build_object('refused', trouble);
        end if;
        if said is null or char_length(said) not between 1 and 1000 or said !~ '[^[:space:]]'
           or said ~ '[\x01-\x09\x0b-\x1f\x7f]' then
            return jsonb_build_object('refused', 'body');
        end if;
        if not public.may_act(account::text, 'comment_edit', 20, 100) then
            return jsonb_build_object('refused', 'limit');
        end if;
        update public.model_comments set body = said, edited_at = now() where id = c.id returning * into c;
    elsif what = 'remove' then
        update public.model_comments set removed_at = now(), removed_by = 'author' where id = c.id returning * into c;
    elsif what in ('hide', 'show') then
        if not public.may_act(account::text, 'comment_hide', 60, 300) then
            return jsonb_build_object('refused', 'limit');
        end if;
        update public.model_comments set hidden_at = case when what = 'hide' then coalesce(hidden_at, now()) end
         where id = c.id returning * into c;
    else
        raise exception 'brickworks: edit, remove, hide or show' using errcode = '22023';
    end if;
    return jsonb_build_object('comment', public.comment_as(c, account, owner_of),
        'removed', c.removed_at is not null);
end;
$$;

-- Comments on or off on a model, by its owner: {open}, or {refused}:
-- not_owner, limit (30 an hour, 100 a day).
create or replace function public.set_comments(account uuid, model_id text, open boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if open is null then
        raise exception 'brickworks: say whether comments are open' using errcode = '22023';
    end if;
    if account is null or not exists (select 1 from public.shared_models s where s.id = model_id and s.owner = account) then
        return jsonb_build_object('refused', 'not_owner');
    end if;
    if not public.may_act(account::text, 'comment_settings', 30, 100) then
        return jsonb_build_object('refused', 'limit');
    end if;
    insert into public.comment_settings (model, open, at) values (model_id, set_comments.open, now())
    on conflict on constraint comment_settings_pkey do update set open = excluded.open, at = excluded.at;
    return jsonb_build_object('open', public.comments_open(model_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- The site's owner.

-- Comments for the admin page: those named, or the newest 200, removed
-- ones too (marked), with their model's name and their author's account
-- and handle.
create or replace function public.admin_comments(wanted bigint[] default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
               'id', c.id, 'model', c.model, 'name', m.name, 'version', c.version, 'step', c.step,
               'body', c.body, 'at', c.at, 'edited_at', c.edited_at, 'hidden_at', c.hidden_at,
               'removed_at', c.removed_at, 'removed_by', c.removed_by, 'author', c.author,
               'handle', p.handle) order by c.at desc), '[]'::jsonb)
      from (select * from public.model_comments k
             where wanted is null or k.id = any (wanted)
             order by k.at desc limit 200) c
      join public.shared_models m on m.id = c.model
      left join public.people p on p.account = c.author
$$;

-- Removed by the site's owner: kept, and shown to nobody.
create or replace function public.admin_remove_comment(comment_id bigint)
returns boolean
language sql
security definer
set search_path = public
as $$
    with done as (
        update public.model_comments set removed_at = coalesce(removed_at, now()),
               removed_by = coalesce(removed_by, 'admin')
         where id = comment_id
        returning 1)
    select exists (select 1 from done)
$$;

-- ---------------------------------------------------------------------------
-- Telling a model's owner, at most once a day.

-- What [account] wants emailed: {comments}. With [comments] given, that
-- is kept first. Off until they say.
create or replace function public.mail_choice(account uuid, comments boolean default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if comments is not null then
        insert into public.mail_choices (account, comments, at) values (mail_choice.account, mail_choice.comments, now())
        on conflict on constraint mail_choices_pkey do update set comments = excluded.comments, at = excluded.at;
    end if;
    return jsonb_build_object('comments', coalesce(
        (select m.comments from public.mail_choices m where m.account = mail_choice.account), false));
end;
$$;

-- Start the emails that are due: to [for_owner] (whose model was just
-- commented on), or to every owner who chose them. One a day at most for
-- each, of the comments on their published models since they chose,
-- not their own, not hidden or removed, that no email has told them of
-- (or one that failed, or never finished). [{digest, owner, email, test,
-- more, comments: [{id, model, name, version, step, body, at, by}]}],
-- up to 50 owners and 50 comments each; empty when none is due.
create or replace function public.claim_comment_digest(for_owner uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    who record;
    ids bigint[];
    waiting integer;
    made bigint;
    due jsonb := '[]'::jsonb;
begin
    for who in
        select c.account, c.at as since from public.mail_choices c
         where c.comments and (for_owner is null or c.account = for_owner)
         order by c.account limit 50
    loop
        perform pg_advisory_xact_lock(hashtext('comment_digest:' || who.account::text));
        if exists (select 1 from public.comment_digests d
                    where d.owner = who.account and d.state <> 'failed'
                      and d.at > now() - interval '1 day') then
            continue;
        end if;
        select array_agg(w.id order by w.at), count(*)::integer into ids, waiting
          from (select k.id, k.at from public.model_comments k
                  join public.shared_models m on m.id = k.model and m.published and m.owner = who.account
                  left join public.comment_digests d on d.id = k.digest
                 where k.removed_at is null and k.hidden_at is null and k.author <> who.account
                   and k.at >= who.since
                   and (k.digest is null or d.state = 'failed'
                        or (d.state = 'sending' and d.at < now() - interval '15 minutes'))
                   and public.shown_publicly(k.author)) w;
        if ids is null then
            continue;
        end if;
        ids := ids[1:50];
        insert into public.comment_digests (owner, comments) values (who.account, array_length(ids, 1))
        returning id into made;
        update public.model_comments set digest = made where id = any (ids);
        due := due || jsonb_build_array(jsonb_build_object(
            'digest', made, 'owner', who.account,
            'email', (select u.email from auth.users u where u.id = who.account),
            'test', public.trust_is_test_account(who.account),
            'more', waiting - array_length(ids, 1),
            'comments', (select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'model', k.model, 'name', m.name, 'version', k.version, 'step', k.step,
                    'body', k.body, 'at', k.at, 'by', p.name) order by k.at)
                  from public.model_comments k
                  join public.shared_models m on m.id = k.model
                  left join public.people p on p.account = k.author
                 where k.id = any (ids))));
    end loop;
    return due;
end;
$$;

-- How an email went: sent, failed (its comments go in the next), or dry
-- (a test's, rendered and never sent, kept with what it would have said).
create or replace function public.finish_comment_digest(
    one bigint, outcome text, said_subject text default null,
    said_body text default null, said_html text default null)
returns boolean
language sql
security definer
set search_path = public
as $$
    with done as (
        update public.comment_digests
           set state = outcome,
               subject = case when outcome = 'dry' then left(said_subject, 300) end,
               body = case when outcome = 'dry' then left(said_body, 100000) end,
               html = case when outcome = 'dry' then left(said_html, 200000) end
         where id = one and state = 'sending' and outcome in ('sent', 'failed', 'dry')
        returning 1)
    select exists (select 1 from done)
$$;

-- A test's dry run, read back by the browser flow: the digest as kept.
create or replace function public.comment_digest_kept(one bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('id', d.id, 'owner', d.owner, 'state', d.state, 'comments', d.comments,
               'subject', d.subject, 'body', d.body)
      from public.comment_digests d
     where d.id = one and public.trust_is_test_account(d.owner)
$$;

-- ---------------------------------------------------------------------------
-- Reports about a comment, as trust.sql made them, and the comment in them.

-- The stream, as trust.sql's, and a test's for a comment a test account
-- wrote.
create or replace function public.report_stream(r public.reports)
returns text
language sql
stable
security definer
set search_path = public
as $$
    with whose as (
        select coalesce(
            (select m.owner from public.shared_models m where m.id = r.model),
            (select c.owner from public.model_collections c where c.id = r.collection),
            (select p.account from public.people p where p.handle = r.handle)) as owner,
            (select k.author from public.model_comments k where k.id = r.comment) as writer)
    select case
        when w.owner is null and r.handle is not null then null
        when w.owner is not null and public.trust_is_test_account(w.owner) then 'test:' || w.owner::text
        when w.writer is not null and public.trust_is_test_account(w.writer) then 'test:' || w.writer::text
        when r.reporter is not null and public.trust_is_test_account(r.reporter) then 'test:' || r.reporter::text
        else 'owner' end
      from whose w
$$;

-- A digest, as trust.sql's, with the comment a report is about and its
-- first words.
create or replace function public.claim_report_digest(wanted text default 'owner', report bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    stream_of text := wanted;
    ids bigint[];
    waiting integer;
    made bigint;
begin
    if report is not null then
        select public.report_stream(r) into stream_of from public.reports r where r.id = report;
    end if;
    if stream_of is null or not (stream_of = 'owner' or stream_of ~ '^test:[0-9a-f-]{36}$') then
        return null;
    end if;
    perform pg_advisory_xact_lock(hashtext('report_digest:' || stream_of));
    if exists (select 1 from public.report_digests d
                where d.stream = stream_of and d.state <> 'failed'
                  and d.at >= date_trunc('hour', now())) then
        return null;
    end if;
    select array_agg(id order by at), count(*)::integer into ids, waiting
      from (select r.id, r.at
              from public.reports r
              left join public.report_digests d on d.id = r.digest
             where r.resolved_at is null
               and (r.digest is null or d.state = 'failed'
                    or (d.state = 'sending' and d.at < now() - interval '15 minutes'))
               and public.report_stream(r) = stream_of) w;
    if ids is null then
        return null;
    end if;
    ids := ids[1:100];
    insert into public.report_digests (stream, reports)
    values (stream_of, coalesce(array_length(ids, 1), 0))
    returning id into made;
    update public.reports set digest = made where id = any (ids);
    return jsonb_build_object(
        'digest', made,
        'stream', stream_of,
        'more', waiting - coalesce(array_length(ids, 1), 0),
        'reports', (
            select jsonb_agg(jsonb_build_object(
                       'id', r.id, 'at', r.at, 'reason', r.reason, 'note', r.note,
                       'model', r.model, 'handle', r.handle, 'collection', r.collection,
                       'comment', r.comment, 'said', left(k.body, 240),
                       'name', coalesce(m.name, c.name, p.name))
                       order by r.at)
              from public.reports r
              left join public.shared_models m on m.id = r.model
              left join public.model_collections c on c.id = r.collection
              left join public.people p on p.handle = r.handle
              left join public.model_comments k on k.id = r.comment
             where r.id = any (ids)));
end;
$$;

revoke all on function public.comment_trouble(uuid, text) from public, anon, authenticated;
grant execute on function public.comment_trouble(uuid, text) to service_role;
revoke all on function public.comments_open(text) from public, anon, authenticated;
grant execute on function public.comments_open(text) to service_role;
revoke all on function public.comment_as(public.model_comments, uuid, uuid) from public, anon, authenticated;
grant execute on function public.comment_as(public.model_comments, uuid, uuid) to service_role;
revoke all on function public.comments_on(text, uuid) from public, anon, authenticated;
grant execute on function public.comments_on(text, uuid) to service_role;
revoke all on function public.comment_model(bigint) from public, anon, authenticated;
grant execute on function public.comment_model(bigint) to service_role;
revoke all on function public.add_comment(uuid, text, integer, integer, text) from public, anon, authenticated;
grant execute on function public.add_comment(uuid, text, integer, integer, text) to service_role;
revoke all on function public.change_comment(uuid, bigint, text, text) from public, anon, authenticated;
grant execute on function public.change_comment(uuid, bigint, text, text) to service_role;
revoke all on function public.set_comments(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.set_comments(uuid, text, boolean) to service_role;
revoke all on function public.admin_comments(bigint[]) from public, anon, authenticated;
grant execute on function public.admin_comments(bigint[]) to service_role;
revoke all on function public.admin_remove_comment(bigint) from public, anon, authenticated;
grant execute on function public.admin_remove_comment(bigint) to service_role;
revoke all on function public.mail_choice(uuid, boolean) from public, anon, authenticated;
grant execute on function public.mail_choice(uuid, boolean) to service_role;
revoke all on function public.claim_comment_digest(uuid) from public, anon, authenticated;
grant execute on function public.claim_comment_digest(uuid) to service_role;
revoke all on function public.finish_comment_digest(bigint, text, text, text, text) from public, anon, authenticated;
grant execute on function public.finish_comment_digest(bigint, text, text, text, text) to service_role;
revoke all on function public.comment_digest_kept(bigint) from public, anon, authenticated;
grant execute on function public.comment_digest_kept(bigint) to service_role;
revoke all on function public.report_stream(public.reports) from public, anon, authenticated;
grant execute on function public.report_stream(public.reports) to service_role;
revoke all on function public.claim_report_digest(text, bigint) from public, anon, authenticated;
grant execute on function public.claim_report_digest(text, bigint) to service_role;
