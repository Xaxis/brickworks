-- orangecheck Connect, an account deleted while orangecheck is still making
-- one for it (2026-10-24, unit oc237; orangecheck's review of step 4, L2),
-- beside supabase/orangecheck_merge_connect.sql.
--
-- A tick of the box asks orangecheck Connect for an account (api/_oc.js
-- provision): oc_connect_asked writes the row, then orangecheck is asked.
-- Deleting the Brickworks account meanwhile asked orangecheck to delete one
-- that was not made yet ("unknown_user"), deleted the account and the row
-- with it, and the answer that came after made an orangecheck account
-- nothing here knew of, which nobody could ever delete. Now:
--
--   oc_connect_leaving  what deleting asks first (api/account.js), in place
--                       of oc_connected_of: the row, as that answers it,
--                       marked as leaving before orangecheck is asked.
--   oc_connect_kept     what provision asks once orangecheck has answered,
--                       in place of oc_connect_made: the id kept, and true;
--                       or false when the row is gone (the account deleted)
--                       or marked leaving since this ask, and then the
--                       caller deletes what orangecheck made.
--
-- Both take the row's lock, so whichever comes second sees the first: kept
-- first, and the deletion finds the id and has orangecheck delete it; the
-- mark first, and provision does. A tick after a deletion that was held
-- (orangecheck down) asks again, later than the mark, so it is kept.
--
-- Only additions: a column and two functions, each security definer and
-- granted to the service role alone, as the rest of oc_connected's. The
-- release before this one goes on calling oc_connected_of and
-- oc_connect_made, which are as they were. Applying it again changes
-- nothing.

alter table public.oc_connected add column if not exists leaving_at timestamptz;

-- [account] being deleted: {did, asked_at, made_at} as oc_connected_of
-- answers, marked leaving; or null when Connect was never asked for it.
create or replace function public.oc_connect_leaving(account uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
    update public.oc_connected c set leaving_at = now()
     where c.account = oc_connect_leaving.account
    returning jsonb_build_object('did', c.did_oc, 'asked_at', c.asked_at, 'made_at', c.made_at)
$$;

-- What orangecheck made for [account], [did], kept: true; false when the
-- account is gone, or was marked leaving since Connect was asked for it,
-- and nothing is kept.
create or replace function public.oc_connect_kept(account uuid, did text)
returns boolean
language sql
security definer
set search_path = public
as $$
    with kept as (
        update public.oc_connected c set did_oc = oc_connect_kept.did, made_at = now()
         where c.account = oc_connect_kept.account
           and (c.leaving_at is null or c.leaving_at < c.asked_at)
        returning 1
    )
    select exists (select 1 from kept)
$$;

revoke all on function public.oc_connect_leaving(uuid) from public, anon, authenticated;
revoke all on function public.oc_connect_kept(uuid, text) from public, anon, authenticated;
grant execute on function public.oc_connect_leaving(uuid) to service_role;
grant execute on function public.oc_connect_kept(uuid, text) to service_role;
