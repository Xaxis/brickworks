-- The site's theme on the account, 2026-10-22 (docs/SOCIAL.md U1, D8).
--
-- brickworks.diy has a light and a dark theme, and a choice of System,
-- Light or Dark at the foot of every page, on Menu and in Settings. The
-- choice is kept in the browser (web/theme.js) and, for somebody signed in,
-- here, so a new browser follows them once they sign in
-- (web/theme-account.js, GET and POST /api/account?op=theme).
--
--   profiles.theme   'system', 'light' or 'dark'; null: never chosen
--                    (every account until it chooses), which reads as
--                    System, and an account with none takes the choice the
--                    browser it signs in on already has
--
-- One row an account (schema.sql's profiles), so deleting the account
-- deletes it (profiles.id references auth.users on delete cascade). Only
-- the server reads or writes it, with the secret key: profiles has no
-- update policy for anybody else, and none is added.
--
-- Only an addition: one column, empty. Nothing is changed, dropped or
-- renamed. Until it is applied the API answers "system", never chosen,
-- and keeps the choice in the browser only.

alter table public.profiles add column if not exists theme text
    check (theme in ('system', 'light', 'dark'));

comment on column public.profiles.theme is
    'The site''s theme this account chose: system, light or dark; null, '
    'never chosen (System). Kept by /api/account?op=theme.';
