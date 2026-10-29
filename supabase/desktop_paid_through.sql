-- The last day each account had the desktop app, 2026-10-29.
--
-- The paid desktop (docs/PLANS.md §4, unit U6): a desktop build runs when
-- the account's paid_through is on or after the day that build was
-- released, so every version released while somebody paid stays theirs.
-- Admission says what an account has now; once a subscription has ended it
-- no longer says until when it was paid. So the server keeps the largest
-- day it has seen per account here (api/_desktop.js), and a new machine
-- after a lapse still knows it.
--
--   desktop_paid_through  one row an account: the day, and when it was
--                         last moved on. Nothing else. Deleting the account
--                         deletes it.
--
-- Only the server touches it, through the two functions here, each
-- security definer and granted to the service role alone:
--
--   desktop_paid_through_get  the account's day as 'YYYY-MM-DD', or null
--   desktop_paid_through_put  the day kept, only ever moved later
--
-- Only additions: one new table and two new functions. Nothing that exists
-- is changed. Applying it again changes nothing.

create table if not exists public.desktop_paid_through (
    user_id    uuid        primary key references auth.users (id) on delete cascade,
    day        date        not null,
    updated_at timestamptz not null default now()
);

alter table public.desktop_paid_through enable row level security;
revoke all on public.desktop_paid_through from public, anon, authenticated, service_role;

-- The day kept for [p_user], or null when there is none.
create or replace function public.desktop_paid_through_get(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select to_char(d.day, 'YYYY-MM-DD') from public.desktop_paid_through d where d.user_id = p_user;
$$;

-- [p_day] kept for [p_user], unless a later day already is: the day only
-- ever moves on.
create or replace function public.desktop_paid_through_put(p_user uuid, p_day date)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.desktop_paid_through as d (user_id, day) values (p_user, p_day)
    on conflict (user_id) do update set day = excluded.day, updated_at = now()
        where d.day < excluded.day;
$$;

revoke all on function public.desktop_paid_through_get(uuid) from public, anon, authenticated;
revoke all on function public.desktop_paid_through_put(uuid, date) from public, anon, authenticated;
grant execute on function public.desktop_paid_through_get(uuid) to service_role;
grant execute on function public.desktop_paid_through_put(uuid, date) to service_role;
