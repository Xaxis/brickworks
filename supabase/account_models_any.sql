-- A save for a plan that keeps any number of models, 2026-11-03 (golive).
-- An addition to account_models.sql.
--
-- Pro, a comp of Pro and the owner keep every model with the account
-- (Admission's saved_models unlimited, api/_billing.js mostModels), so
-- save_account_model's 500 models and 64 MB in all would make /plans's
-- "Unlimited" untrue. This is save_account_model without those totals.
-- What stays: each model at most 4 MB as stored (the table's own check;
-- api/models.js holds it at 32 MB of LDraw too), and a guard against a
-- script, not a person: no more than 1,000 models or 256 MB saved in one
-- hour. Past it the save is refused 'models: too fast', which api/models.js
-- answers 429 and the app sends again later. A 10,000-part set is about
-- 400 KB stored, so 256 MB is more than 600 of the largest sets an hour.
--
--   save_account_model_any(owner, name, base, model, raw_bytes, parts, sum)
--       as save_account_model, with no account totals.
--
-- Under the same lock as save_account_model, one per account, held to the
-- end of the transaction: the hour's count is what is there when this
-- save writes, and a save of either kind waits for the other.
--
-- Asked only while plans are on (BRICKWORKS_BILLING) and Admission says
-- the account's plan keeps any number; plans off, Free, and a plan not
-- known still go through save_account_model and its totals. Until this
-- file is applied, a Pro save is kept within the totals, and the log says
-- so.
--
-- Who may do what: the server alone (api/models.js, with the secret key),
-- as account_models.sql. Every grant to anon, authenticated and PUBLIC
-- taken back; client_exposure() stays empty.
--
-- Only additions: one function. Applying it again changes nothing.

create or replace function public.save_account_model_any(
    p_owner uuid, p_name text, p_base integer, p_model text,
    p_raw_bytes integer, p_parts integer, p_sum text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    hour_models constant integer := 1000;
    hour_bytes constant bigint := 256 * 1024 * 1024;
    there public.account_models%rowtype;
    had boolean;
    recent_count integer;
    recent_bytes bigint;
    free text;
    tail text;
    n integer;
begin
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('account_models ' || p_owner::text, 0));
    select * into there from public.account_models where owner = p_owner and name = p_name;
    had := found;
    if had and there.sum = p_sum then
        return jsonb_build_object('name', there.name, 'version', there.version, 'same', true);
    end if;
    select count(*), coalesce(sum(octet_length(m.model)), 0) into recent_count, recent_bytes
      from public.account_models m
     where m.owner = p_owner and m.saved_at > pg_catalog.now() - interval '1 hour';
    if recent_count + 1 > hour_models or recent_bytes + octet_length(p_model) > hour_bytes then
        raise exception 'models: too fast';
    end if;
    if had and there.version = p_base then
        update public.account_models
           set version = there.version + 1, model = p_model, raw_bytes = p_raw_bytes,
               parts = p_parts, sum = p_sum, saved_at = pg_catalog.now()
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
    insert into public.account_models (owner, name, version, model, raw_bytes, parts, sum)
    values (p_owner, free, 1, p_model, p_raw_bytes, p_parts, p_sum);
    return jsonb_build_object('name', free, 'version', 1)
        || case when had then jsonb_build_object('conflict', free) else '{}'::jsonb end;
end;
$$;

revoke all on function public.save_account_model_any(uuid, text, integer, text, integer, integer, text)
    from public, anon, authenticated;
grant execute on function public.save_account_model_any(uuid, text, integer, text, integer, integer, text)
    to service_role;

notify pgrst, 'reload schema';
