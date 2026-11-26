-- The blocks table's leftover row policy taken away, 2026-11-26 (greenreds).
--
-- supabase/block.sql (2026-11-19) made blocks_own_only, a select policy for
-- authenticated on public.blocks, after no_client_access.sql had dropped
-- every such policy and made the rule that the keys a page holds reach
-- nothing in public. The same file revokes every privilege on the table from
-- anon and authenticated, so the policy has never let anyone read a row: a
-- policy only narrows what a grant allows, and there is none. But
-- client_exposure() lists every policy for a page's roles as reach, rightly,
-- since a grant made later would open the rows the policy names, and
-- orangecheck_check's N1 has failed on this one line since it was applied.
--
-- Nothing reads blocks through it: every route asks as the server
-- (api/_db.js), whose role row security does not stop. block.sql no longer
-- makes it. Only this one policy goes; applying it again changes nothing.

drop policy if exists blocks_own_only on public.blocks;
