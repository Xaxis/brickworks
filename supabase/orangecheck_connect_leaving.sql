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
--   oc_connect_leaving  what deleting asks first (api/account.js): the row
--                       as oc_connected_of answers it when Connect was asked
--                       for the account, or null when it never was; and the
--                       account marked as leaving either way. With no row
--                       yet, a row of the mark alone is written (asked_at
--                       '-infinity': never asked), so a first tick that
--                       starts while the deletion goes on is caught too
--                       (site-attest's race: the mark found no row, the
--                       tick wrote one, its answer was kept, and the account
--                       went with the row).
--   oc_connect_kept     what provision asks once orangecheck has answered:
--                       the id kept, and true, only while the account has
--                       no mark of the last 15 minutes; false when it has,
--                       or its row is gone (the account deleted), and the
--                       caller deletes what orangecheck made.
--   oc_connected_of     null for a row of the mark alone, as for no row:
--                       Connect was never asked (replacing
--                       orangecheck_merge_connect.sql's, which answered such
--                       a row as asked, with no id).
--
-- A mark is never taken off; it lapses. Two deletions of one account at
-- once (a double submit) share it, so one that fails must not lift the mark
-- the other still relies on (site-attest's R1: a tick between was kept, and
-- the deletion that went through orphaned what it made). Fifteen minutes
-- is longer than a deletion can run (api/account.js); after one that
-- failed, a tick in those minutes deletes what it makes, which fails safe.
-- Each takes the row's lock, so whichever comes second sees the first.
--
-- Only additions: a column and functions, each security definer and
-- granted to the service role alone, as the rest of oc_connected's. The
-- first version of this file (a mark updating a row only if there was one,
-- kept comparing the mark with the ask) is replaced in place; a second,
-- never applied, took marks off with oc_connect_stays, which is gone.
-- Applying it again changes nothing.

alter table public.oc_connected add column if not exists leaving_at timestamptz;

-- [account] being deleted: {did, asked_at, made_at} as oc_connected_of
-- answers, when Connect was asked for it; null when it never was. Marked
-- as leaving either way.
create or replace function public.oc_connect_leaving(account uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
    insert into public.oc_connected as c (account, asked_at, leaving_at)
        values (oc_connect_leaving.account, '-infinity', now())
        on conflict (account) do update set leaving_at = now()
    returning case when c.asked_at = '-infinity' then null
        else jsonb_build_object('did', c.did_oc, 'asked_at', c.asked_at, 'made_at', c.made_at) end
$$;

-- What orangecheck made for [account], [did], kept: true; false when the
-- account is gone or was marked as leaving in the last 15 minutes, and
-- nothing is kept.
create or replace function public.oc_connect_kept(account uuid, did text)
returns boolean
language sql
security definer
set search_path = public
as $$
    with kept as (
        update public.oc_connected c set did_oc = oc_connect_kept.did, made_at = now()
         where c.account = oc_connect_kept.account
           and (c.leaving_at is null or c.leaving_at < now() - interval '15 minutes')
        returning 1
    )
    select exists (select 1 from kept)
$$;

-- Whether Connect was ever asked for [account]: {did, asked_at, made_at},
-- or null, for a row of a deletion's mark alone too.
create or replace function public.oc_connected_of(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('did', c.did_oc, 'asked_at', c.asked_at, 'made_at', c.made_at)
      from public.oc_connected c where c.account = oc_connected_of.account and c.asked_at <> '-infinity'
$$;

revoke all on function public.oc_connect_leaving(uuid) from public, anon, authenticated;
revoke all on function public.oc_connect_kept(uuid, text) from public, anon, authenticated;
revoke all on function public.oc_connected_of(uuid) from public, anon, authenticated;
grant execute on function public.oc_connect_leaving(uuid) to service_role;
grant execute on function public.oc_connect_kept(uuid, text) to service_role;
grant execute on function public.oc_connected_of(uuid) to service_role;
