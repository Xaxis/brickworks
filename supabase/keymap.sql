-- The app's keys on the account, 2026-10-30 (docs/APP_UX.md A11).
--
-- The app has presets of keys after the program a person comes from
-- (BrickLink Studio's, Mecabricks', LDCad's) and lets any key be set in its
-- keys sheet. The keys are kept on the device (src/ui/shell_prefs.gd) and,
-- for somebody signed in, here, so a new browser or computer has them once
-- they sign in (src/account/keymap_sync.gd, GET and POST
-- /api/account?op=keys).
--
--   profiles.keys   {preset, own, at}: the preset (brickworks, studio,
--                   mecabricks or ldcad), the keys set over it (a command's
--                   name and its key as Godot writes one), and when, in
--                   seconds, for the newer of the device's and the
--                   account's to win; null, never set
--
-- One row an account (schema.sql's profiles), so deleting the account
-- deletes it (profiles.id references auth.users on delete cascade). Only
-- the server reads or writes it, with the secret key: profiles has no
-- update policy for anybody else, and none is added. api/account.js checks
-- what it is sent before keeping it.
--
-- Only an addition: one column, empty. Nothing is changed, dropped or
-- renamed. Until it is applied the API answers null, never set, and keeps
-- the keys on the device only.

alter table public.profiles add column if not exists keys jsonb;

comment on column public.profiles.keys is
    'The app''s keys this account set: {preset, own, at}; null, never set. '
    'Kept by /api/account?op=keys.';
