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

-- Spend one design against this month's budget, and say whether it was
-- allowed.
--
-- A design is a conversation, not a request. The assistant looks parts
-- up, checks whether what it proposed holds together and repairs it when
-- it does not, so one small lighthouse is six round trips and a hard
-- model is forty. Counting requests looked right until a single build
-- ate six of a sixty-a-month budget, which would have made the number on
-- the landing page wrong by a factor of eight.
--
-- So the caller passes an id for the conversation and every turn of it
-- claims against that id. The first turn inserts and costs one; the rest
-- conflict on the primary key and cost nothing. The id comes from the
-- client and could be made up, but the account is still the limit and
-- the turn cap below is still the ceiling, so the worst a forged id buys
-- is one design counted twice.
create table if not exists public.assistant_designs (
    user_id    uuid not null references auth.users on delete cascade,
    month      date not null,
    design_id  text not null,
    turns      integer not null default 1,
    started_at timestamptz not null default now(),
    primary key (user_id, month, design_id)
);

alter table public.assistant_designs enable row level security;

drop policy if exists assistant_designs_read_own on public.assistant_designs;
create policy assistant_designs_read_own on public.assistant_designs
    for select using (auth.uid() = user_id);

drop function if exists public.claim_design(uuid, integer);

create or replace function public.claim_design(
    account uuid, budget integer, design text default null)
returns table (allowed boolean, used integer, budget_out integer)
language plpgsql
security definer
set search_path = public
as $$
declare
    this_month date := date_trunc('month', now())::date;
    conversation text := coalesce(nullif(design, ''), gen_random_uuid()::text);
    -- The app stops itself at 45 turns. This is the same ceiling where a
    -- modified client cannot reach it, with room above so an honest run
    -- never meets it.
    max_turns constant integer := 60;
    spent integer;
    turn integer;
begin
    insert into public.assistant_designs (user_id, month, design_id)
    values (account, this_month, conversation)
    on conflict (user_id, month, design_id) do update
        set turns = public.assistant_designs.turns + 1
    returning turns into turn;

    -- Already under way: another turn of a design that has been paid
    -- for, so only the turn cap applies.
    if turn > 1 then
        select designs into spent
        from public.assistant_usage
        where user_id = account and month = this_month;
        return query select turn <= max_turns, coalesce(spent, 0), budget;
        return;
    end if;

    -- A new conversation. Counting and checking have to happen together:
    -- two requests arriving at once would both read the same count and
    -- both decide they were under budget, and the account would quietly
    -- run over. So the insert does the check in the same statement, and
    -- the row lock that the upsert takes is what serialises them.
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
        -- Leave no paid-for row behind for a design that was refused, or
        -- retrying it would let the whole conversation through free.
        delete from public.assistant_designs
        where user_id = account and month = this_month
          and design_id = conversation;
        return query select false, coalesce(spent, budget), budget;
        return;
    end if;

    return query select true, spent, budget;
end;
$$;

revoke all on function public.claim_design(uuid, integer, text) from public, anon, authenticated;
