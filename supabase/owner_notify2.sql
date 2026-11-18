-- The owner's notifications, second (onfix, 2026-11-18; docs/OWNER_NOTIFY.md,
-- supabase/owner_notify.sql): the day the old rows were last pruned, kept as
-- the digest's day is, so the prune runs at the first run of each UTC day
-- (api/_notify.js pruneDue). Before it the prune ran only when the cron's
-- run landed at 03:00-03:04 UTC, and a day it missed was never pruned.
--
-- Until this is applied the code prunes in the hour from 03:00 UTC, as
-- before but on every run of that hour; nothing else waits on it.
--
-- Only an addition: one column, null until the first prune writes it.
-- Applying it again changes nothing.

alter table public.owner_notify_settings add column if not exists pruned_on date;

notify pgrst, 'reload schema';
