-- Brickworks accounts.
--
-- Two things live here and nothing else: who someone is, and how much of
-- the design assistant they have used this month.
--
-- There is deliberately no table of models. Saving a build is a free-tier
-- feature and free tier has no account, so builds are files on the
-- player's own disk (desktop) or in their browser (web). Putting them in
-- a server database would mean the thing everybody can do depends on the
-- thing only some people have, which is backwards.

-- Who. One row per account, created by a trigger so it cannot drift out
-- of step with auth.users.
create table if not exists public.profiles (
    id          uuid primary key references auth.users on delete cascade,
    email       text,
    tier        text not null default 'builder',
    created_at  timestamptz not null default now(),
    constraint profiles_tier_known check (tier in ('builder', 'pro'))
);

comment on column public.profiles.tier is
    'builder: the assistant, at the standard monthly budget. pro: a '
    'larger budget. Anonymous visitors have no row at all — they get '
    'the whole builder and no assistant.';

alter table public.profiles enable row level security;

-- A signed-in player may read their own profile and nothing else. There
-- is no update policy on purpose: tier is not the player''s to set.
drop policy if exists profiles_read_own on public.profiles;
create policy profiles_read_own on public.profiles
    for select using (auth.uid() = id);

-- How much. One row per account per month; the month is the first of it
-- so the primary key does the bucketing.
create table if not exists public.assistant_usage (
    user_id  uuid not null references auth.users on delete cascade,
    month    date not null,
    designs  integer not null default 0,
    primary key (user_id, month)
);

alter table public.assistant_usage enable row level security;

drop policy if exists assistant_usage_read_own on public.assistant_usage;
create policy assistant_usage_read_own on public.assistant_usage
    for select using (auth.uid() = user_id);

-- Give every new account a profile. Without this a player could sign up
-- successfully and then have no tier, which reads to the app as "not
-- allowed" — a silent failure at the worst moment.
create or replace function public.on_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email)
    values (new.id, new.email)
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists profiles_from_auth_users on auth.users;
create trigger profiles_from_auth_users
    after insert on auth.users
    for each row execute function public.on_auth_user_created();

-- Spend one design against this month''s budget, and say whether it was
-- allowed. Counting and checking have to happen together: two requests
-- arriving at once would both read the same count and both decide they
-- were under budget, and the account would quietly run over. So the
-- insert does the check in the same statement, and the row lock that the
-- upsert takes is what serialises them.
create or replace function public.claim_design(account uuid, budget integer)
returns table (allowed boolean, used integer, budget_out integer)
language plpgsql
security definer
set search_path = public
as $$
declare
    this_month date := date_trunc('month', now())::date;
    spent integer;
begin
    insert into public.assistant_usage (user_id, month, designs)
    values (account, this_month, 1)
    on conflict (user_id, month) do update
        set designs = public.assistant_usage.designs + 1
        where public.assistant_usage.designs < budget
    returning designs into spent;

    if spent is null then
        -- The update was refused by its where clause: already at budget.
        -- RETURN QUERY appends to the result set and carries on, so this
        -- needs its own RETURN after it. Without one the function hands
        -- back a refusal followed by an approval, and a caller reading
        -- only the first row is the only reason that looks like it works.
        select designs into spent
        from public.assistant_usage
        where user_id = account and month = this_month;
        return query select false, coalesce(spent, budget), budget;
        return;
    end if;

    return query select true, spent, budget;
end;
$$;

revoke all on function public.claim_design(uuid, integer) from public, anon, authenticated;
