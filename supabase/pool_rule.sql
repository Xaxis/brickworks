-- A kept pool says the rule it was counted by (kbfix, 2026-11-17; after
-- discovery.sql).
--
-- The gallery's Build with what I own keeps each person's pool
-- (collection_pools) and counts it again only when their collection
-- changes (api/_owned.js freshPool). keptbuilt changed what a pool is: a
-- copy marked Built leaves its parts out, and the parts marked missing come
-- off. A pool kept before that was counted by the older rule and would be
-- shown until the collection next changed. Now each kept pool says its rule
-- (api/_owned.js POOL_RULE), and one kept by an older rule is counted again.
--
--   collection_pools_kept.rule   the rule a pool was counted by: 1 the
--                     sets' parts (every pool kept before this file), 2 less
--                     the copies kept built and the parts marked missing
--
-- An older site keeps its pools with owned_keep_pool(account, lots,
-- unknown), which now writes rule 1, so a newer site counts them again; a
-- newer one with owned_keep_pool(account, lots, unknown, rule). Each finds
-- its own by its arguments' names. owned_pool_of says the rule.
--
-- Only additions: one column with a default, one function added, and two
-- replaced (discovery.sql's owned_keep_pool and owned_pool_of) with the same
-- arguments and answers, and the rule beside them. Nothing dropped.

alter table public.collection_pools_kept add column if not exists rule integer not null default 1
    check (rule between 1 and 1000);

-- What [account] has on hand, kept in place of what it had, counted by
-- [rule]: [lots] is [{part, colour, qty}], counted by api/_owned.js from the
-- collection it keeps; [unknown] its sets no inventory knows. {lots, pieces}.
create or replace function public.owned_keep_pool(account uuid, lots jsonb, unknown text[], rule integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    kept public.collection_pools_kept;
begin
    if account is null or jsonb_typeof(lots) <> 'array' or rule is null then
        raise exception 'brickworks: a pool is an account, a list and a rule' using errcode = '22023';
    end if;
    delete from public.collection_pools p where p.owner = account;
    insert into public.collection_pools (owner, part, colour, qty)
    select account, x.part, x.colour, least(sum(x.qty), 1000000000)
      from jsonb_to_recordset(lots) as x(part text, colour integer, qty bigint)
     group by x.part, x.colour;
    insert into public.collection_pools_kept (owner, lots, pieces, unknown, rule, at)
    select account, count(*), coalesce(sum(p.qty), 0), coalesce(unknown, '{}'), rule, now()
      from public.collection_pools p where p.owner = account
    on conflict on constraint collection_pools_kept_pkey do update
       set lots = excluded.lots, pieces = excluded.pieces, unknown = excluded.unknown, rule = excluded.rule,
           at = excluded.at
    returning * into kept;
    return jsonb_build_object('lots', kept.lots, 'pieces', kept.pieces);
end;
$$;

-- The older site's: the same, counted by rule 1.
create or replace function public.owned_keep_pool(account uuid, lots jsonb, unknown text[] default '{}')
returns jsonb
language sql
security definer
set search_path = public
as $$
    select public.owned_keep_pool(account, lots, unknown, 1)
$$;

-- What [account]'s pool is: {lots, pieces, unknown, rule, at}, or null.
create or replace function public.owned_pool_of(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('lots', k.lots, 'pieces', k.pieces, 'unknown', to_jsonb(k.unknown), 'rule', k.rule,
                              'at', k.at)
      from public.collection_pools_kept k where k.owner = account
$$;

revoke all on function public.owned_keep_pool(uuid, jsonb, text[], integer) from public, anon, authenticated;
grant execute on function public.owned_keep_pool(uuid, jsonb, text[], integer) to service_role;
revoke all on function public.owned_keep_pool(uuid, jsonb, text[]) from public, anon, authenticated;
grant execute on function public.owned_keep_pool(uuid, jsonb, text[]) to service_role;
revoke all on function public.owned_pool_of(uuid) from public, anon, authenticated;
grant execute on function public.owned_pool_of(uuid) to service_role;
