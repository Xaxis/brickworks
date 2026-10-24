-- Deleting a saved model kept with an account, and how much an account
-- keeps, 2026-10-24 (lib219). Additions to account_models.sql.
--
-- A model could be saved with the account and never taken away: an
-- account that reached 500 models or 64 MB could not keep another, and
-- nothing the person did would make room. Now a model deleted in the app
-- is deleted here too (api/models.js, src/account/cloud_models.gd), and a
-- rename is a delete of the old name and a save under the new.
--
--   delete_account_model(owner, name, version)
--       {name, deleted} when the account had that version and now has
--       none; {name, gone} when it had none; {name, kept: <version>} when
--       a newer version was saved since, in another browser or on another
--       device: that save is kept, never deleted unseen, and comes back to
--       the browser that deleted it as a model of its own.
--   account_models_kept(owner)
--       {models, bytes}: how many the account keeps and how much, as
--       stored, which save_account_model holds at 500 and 64 MB.
--
-- Under the same lock as save_account_model, one per account: a delete
-- and a save at once are one after the other, so a save is never answered
-- as kept while a delete takes the row from under it.
--
-- Who may do what: the server alone (api/models.js, with the secret key),
-- as account_models.sql. Every grant to anon, authenticated and PUBLIC
-- taken back; client_exposure() stays empty.
--
-- Only additions: two functions. Applying it again changes nothing. Until
-- it is applied, api/models.js answers a delete 503, and the app keeps the
-- delete and asks again at its next look.

create or replace function public.delete_account_model(p_owner uuid, p_name text, p_version integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    there public.account_models%rowtype;
begin
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('account_models ' || p_owner::text, 0));
    select * into there from public.account_models m where m.owner = p_owner and m.name = p_name;
    if not found then
        return jsonb_build_object('name', p_name, 'gone', true);
    end if;
    if there.version <> p_version then
        return jsonb_build_object('name', p_name, 'kept', there.version);
    end if;
    delete from public.account_models m where m.owner = p_owner and m.name = p_name;
    return jsonb_build_object('name', p_name, 'deleted', true);
end;
$$;

revoke all on function public.delete_account_model(uuid, text, integer) from public, anon, authenticated;
grant execute on function public.delete_account_model(uuid, text, integer) to service_role;

create or replace function public.account_models_kept(p_owner uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object('models', count(*), 'bytes', coalesce(sum(octet_length(m.model)), 0))
      from public.account_models m where m.owner = p_owner;
$$;

revoke all on function public.account_models_kept(uuid) from public, anon, authenticated;
grant execute on function public.account_models_kept(uuid) to service_role;

notify pgrst, 'reload schema';
