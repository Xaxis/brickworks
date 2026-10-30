-- How many models a plan keeps with an account, 2026-10-29 (savecap360).
-- An addition to account_models.sql.
--
-- Free keeps 25 models with the account and Pro any number (Admission's
-- saved_models, api/_billing.js mostModels); the 500 models and 64 MB of
-- save_account_model stay the most anybody keeps. Only a model new to the
-- account counts: a save over one it has, or the same model again, never
-- does, and a model deleted makes room at once, since the count is what
-- the table holds. Nothing is ever deleted to make room.
--
--   save_account_model_within(owner, name, base, model, raw_bytes,
--                             parts, sum, most)
--       save_account_model, then: when that kept a model new to the
--       account (its version 1, not one kept already) and the account now
--       has more than [most], raises 'models: plan' (P0001), and the
--       transaction takes the save back.
--
-- Under save_account_model's lock, one per account, held to the end of
-- the transaction: the count is what is there when this save writes, so
-- no script of saves at once gets past the plan either.
--
-- Asked only while plans are on (BRICKWORKS_BILLING) and the account's
-- plan has a limit; with plans off api/models.js calls save_account_model
-- as before. Until this file is applied a save with a limit is kept
-- without one, and the log says so.
--
-- Who may do what: the server alone (api/models.js, with the secret key),
-- as account_models.sql. Every grant to anon, authenticated and PUBLIC
-- taken back; client_exposure() stays empty.
--
-- Only additions: one function. Applying it again changes nothing.

create or replace function public.save_account_model_within(
    p_owner uuid, p_name text, p_base integer, p_model text,
    p_raw_bytes integer, p_parts integer, p_sum text, p_most integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    kept jsonb;
    n integer;
begin
    kept := public.save_account_model(p_owner, p_name, p_base, p_model, p_raw_bytes, p_parts, p_sum);
    if p_most is not null and (kept ->> 'version')::integer = 1
       and not coalesce((kept ->> 'same')::boolean, false) then
        select count(*) into n from public.account_models m where m.owner = p_owner;
        if n > p_most then
            raise exception 'models: plan';
        end if;
    end if;
    return kept;
end;
$$;

revoke all on function public.save_account_model_within(uuid, text, integer, text, integer, integer, text, integer)
    from public, anon, authenticated;
grant execute on function public.save_account_model_within(uuid, text, integer, text, integer, integer, text, integer)
    to service_role;

notify pgrst, 'reload schema';
