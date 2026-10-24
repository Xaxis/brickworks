-- A signed-in person's saved models, kept with their account as well as in
-- the browser, 2026-10-23 (walk180's A4).
--
-- On the web a model saved was in the site's storage in that browser and
-- nowhere else: another device, another browser, or the same one after it
-- cleared the site's storage, had none of them, and the app said "Your
-- account keeps no copy". Mecabricks keeps every model with the account.
-- Now each save of a signed-in person is sent here too (api/models.js,
-- src/account/cloud_models.gd), and every browser they sign in to puts the
-- account's models in File, Open. The browser's own copy stays as it is,
-- and works offline and signed out.
--
--   account_models   one row per saved model of an account:
--     owner          the account; its models go with it (on delete cascade),
--                    by whichever way it is deleted (api/account.js ?op=delete,
--                    an orangecheck account's too: both delete the auth user)
--     name           the model's name, as its file in the app is called
--                    (ModelStore._safe_name): one line, 1 to 60 characters
--     version        1 for its first save, one more for each save after
--     model          the .ldr as the app wrote it, gzipped, in base64
--     raw_bytes      its size before that
--     parts          its parts, as api/models.js counts them
--     sum            the SHA-256 of the .ldr, in hex: the same model saved
--                    again is not a new version
--     saved_at       when it was last saved
--
-- Never a save lost to another: a save says which version it was made
-- from (base), and only a save of the version that is there replaces it.
-- One made from an older version, in another tab, browser or device, is
-- kept beside it under a name of its own, "Castle 2" (as the app numbers
-- a name a saved model has, ModelStore._free_name), and both are in Open.
-- The same model saved again changes nothing.
--
-- How much an account may keep, held here in one transaction per account
-- (an advisory lock), so no script of requests at once can go past it:
-- 500 models and 64 MB as stored, and each model at most 4 MB as stored
-- (about 30 MB of LDraw before it is gzipped: a 10,000-part set is about
-- 2 MB, 400 KB stored).
--
-- Who may do what: only the server (api/models.js, with the secret key),
-- which names the caller's own rows after verifying the session. No key a
-- page holds may reach the table or run the function: row security on and
-- no policy, every grant to anon, authenticated and PUBLIC taken back
-- (supabase/no_client_access.sql's rule; client_exposure() stays empty).
--
-- Only additions: a table and a function. Applying it again changes
-- nothing. Apply it before the code that writes it is deployed: until it
-- is, api/models.js answers 503 and the app keeps its models in the
-- browser alone, as before.

create table if not exists public.account_models (
    owner       uuid not null references auth.users (id) on delete cascade,
    name        text not null,
    version     integer not null default 1,
    model       text not null,
    raw_bytes   integer not null,
    parts       integer not null default 0,
    sum         text not null,
    saved_at    timestamptz not null default now(),
    primary key (owner, name),
    constraint account_models_name check (
        char_length(name) between 1 and 60 and name = btrim(name)
        and name !~ '[[:cntrl:]/\\:*?"<>|]' and name not in ('.', '..')),
    constraint account_models_version check (version >= 1),
    constraint account_models_model check (octet_length(model) between 1 and 4194304),
    constraint account_models_raw check (raw_bytes between 0 and 33554432),
    constraint account_models_parts check (parts >= 0),
    constraint account_models_sum check (sum ~ '^[0-9a-f]{64}$')
);

comment on table public.account_models is
    'A signed-in person''s saved models, kept with their account as well as in '
    'the browser. Written only through api/models.js (save_account_model).';

alter table public.account_models enable row level security;
revoke all on table public.account_models from anon, authenticated, public;
grant all on table public.account_models to service_role;

-- A save: {name, version} as kept, with same when it was kept already and
-- conflict (the name it was saved as) when it was made from an older
-- version than the one there and so kept beside it, under [name] with a
-- number. Raises 'models: too many' or 'models: too big' (P0001) when the
-- account would go past what it may keep.
create or replace function public.save_account_model(
    p_owner uuid, p_name text, p_base integer, p_model text,
    p_raw_bytes integer, p_parts integer, p_sum text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    most_models constant integer := 500;
    most_bytes constant bigint := 64 * 1024 * 1024;
    there public.account_models%rowtype;
    had boolean;
    kept_count integer;
    kept_bytes bigint;
    free text;
    tail text;
    n integer;
begin
    -- One save of an account at a time: the count and the bytes below are
    -- what is there when this one writes.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('account_models ' || p_owner::text, 0));
    select * into there from public.account_models where owner = p_owner and name = p_name;
    had := found;
    if had and there.sum = p_sum then
        return jsonb_build_object('name', there.name, 'version', there.version, 'same', true);
    end if;
    select count(*), coalesce(sum(octet_length(m.model)), 0) into kept_count, kept_bytes
      from public.account_models m where m.owner = p_owner;
    if had and there.version = p_base then
        if kept_bytes - octet_length(there.model) + octet_length(p_model) > most_bytes then
            raise exception 'models: too big';
        end if;
        update public.account_models
           set version = there.version + 1, model = p_model, raw_bytes = p_raw_bytes,
               parts = p_parts, sum = p_sum, saved_at = now()
         where owner = p_owner and name = p_name;
        return jsonb_build_object('name', p_name, 'version', there.version + 1);
    end if;
    free := p_name;
    if had then
        -- Kept already beside it, from the same save made again: that one.
        select * into there from public.account_models m
         where m.owner = p_owner and m.sum = p_sum and left(m.name, char_length(p_name) + 1) = p_name || ' '
         order by m.saved_at desc limit 1;
        if found then
            return jsonb_build_object('name', there.name, 'version', there.version, 'same', true,
                                      'conflict', there.name);
        end if;
        n := 2;
        loop
            tail := ' ' || n;
            free := left(p_name, 60 - char_length(tail)) || tail;
            exit when not exists (select 1 from public.account_models m where m.owner = p_owner and m.name = free);
            n := n + 1;
            if n > 999 then
                raise exception 'models: too many';
            end if;
        end loop;
    end if;
    if kept_count + 1 > most_models then
        raise exception 'models: too many';
    end if;
    if kept_bytes + octet_length(p_model) > most_bytes then
        raise exception 'models: too big';
    end if;
    insert into public.account_models (owner, name, version, model, raw_bytes, parts, sum)
    values (p_owner, free, 1, p_model, p_raw_bytes, p_parts, p_sum);
    return jsonb_build_object('name', free, 'version', 1)
        || case when had then jsonb_build_object('conflict', free) else '{}'::jsonb end;
end;
$$;

revoke all on function public.save_account_model(uuid, text, integer, text, integer, integer, text)
    from public, anon, authenticated;
grant execute on function public.save_account_model(uuid, text, integer, text, integer, integer, text)
    to service_role;

notify pgrst, 'reload schema';
