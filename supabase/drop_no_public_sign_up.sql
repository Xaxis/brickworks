-- The public sign-up trigger dropped, 2026-10-24.
--
-- supabase/no_new_ways_in.sql refused, as its making committed, the account
-- a public sign-up made, by the one mark only such an account carried: its
-- user data says phone_verified. That stood in for a setting nothing here
-- could reach, and a mark Supabase writes by habit is no rule: a GoTrue that
-- stops writing it lets a stranger's sign-up through, and one that starts
-- writing it for the accounts we make turns everybody away. Since
-- 2026-10-24 ~09:55Z Supabase takes no public sign-up at all
-- (disable_signup), and the daily canary (api/_canary.js, its check (a))
-- holds that by trying one. So the trigger goes.
--
-- The rest of no_new_ways_in.sql stays: no password or new address on a
-- person's account, no sign-in by password but a test account's
-- (auth.mfa_amr_claims), no second factor. tools/drop_no_public_sign_up_try.sql
-- shows each still refusing, in a dry run:
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs \
--     supabase/drop_no_public_sign_up.sql --dry --try=tools/drop_no_public_sign_up_try.sql --table=canary_runs
--
-- Only our own trigger and function taken away; applying it again changes
-- nothing.

drop trigger if exists no_public_sign_up on auth.users;
drop function if exists public.auth_users_no_public_sign_up();
