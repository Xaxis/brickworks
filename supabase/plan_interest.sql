-- Who would use a paid plan, 2026-10-28: the interest form on /plans.
--
-- brickworks.diy/plans shows Free, Plus and Creator, the paid two coming
-- soon (the pricing research, price274: a pricing page and an interest
-- form before any billing). Nothing takes money. A person who would use
-- Plus or Creator leaves an email address, the plan, monthly or yearly,
-- and a line if they like (api/plans.js); the owner writes to them once,
-- when that plan opens, and reads only the counts until then
-- (tools/plan_interest.py).
--
--   plan_interest        one row an address a plan: a second entry for the
--                        same plan changes the first (monthly or yearly,
--                        its line, and when), never adds a row
--   plan_interest_tries  the rate of entries from one place, as oc_attempts
--                        is for orangecheck: a key made from the address
--                        the entry came from (an HMAC with the server's
--                        secret, api/plans.js), never the address, kept a
--                        day
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables
-- directly: a visitor adds an entry through /api/plans and reads none.
--
--   plan_interest_may      whether the place an entry or a request to
--                          forget came from may send another
--   plan_interest_note     an entry kept: 'added', or 'changed' when the
--                          address had one for that plan
--   plan_interest_counts   how many a plan and a billing, Resend's test
--                          addresses (the checks') apart; no address
--   plan_interest_of       what is kept for one address, to answer its
--                          owner (the privacy page)
--   plan_interest_forget   an address's entries deleted: by the form, when
--                          whoever has the address asks (/plans, "Take my
--                          email off"), and by the owner
--
-- Only additions: two new tables, an index and five new functions. Nothing
-- that exists is changed. Applying it again changes nothing.

create table if not exists public.plan_interest (
    email      text        not null
        constraint plan_interest_email check (email = lower(email) and length(email) <= 320
            and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    plan       text        not null constraint plan_interest_plan check (plan in ('plus', 'creator')),
    billing    text        not null constraint plan_interest_billing check (billing in ('monthly', 'yearly')),
    note       text        not null default '' constraint plan_interest_note check (length(note) <= 200),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (email, plan)
);

create table if not exists public.plan_interest_tries (
    id  bigserial   primary key,
    who text        not null,
    at  timestamptz not null default now()
);
create index if not exists plan_interest_tries_recent on public.plan_interest_tries (who, at desc);

alter table public.plan_interest enable row level security;
alter table public.plan_interest_tries enable row level security;
revoke all on public.plan_interest from public, anon, authenticated, service_role;
revoke all on public.plan_interest_tries from public, anon, authenticated, service_role;
revoke all on sequence public.plan_interest_tries_id_seq from public, anon, authenticated, service_role;

-- Whether the place [p_who] may send another entry, or ask for one gone:
-- at most [per_who] in [window_minutes], generous enough that a person
-- trying both plans, or fixing a typo, is never refused. Counted here, so
-- a refusal costs nothing more. Tries older than a day go.
create or replace function public.plan_interest_may(p_who text, per_who integer default 10,
    window_minutes integer default 60)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    tried integer;
begin
    delete from public.plan_interest_tries where at < now() - interval '1 day';
    select count(*) into tried from public.plan_interest_tries
     where who = coalesce(p_who, '') and at >= now() - make_interval(mins => window_minutes);
    if tried >= per_who then
        return false;
    end if;
    insert into public.plan_interest_tries (who) values (coalesce(p_who, ''));
    return true;
end;
$$;

-- [p_email]'s entry for [p_plan]: 'added', or 'changed' when it had one,
-- which is then the new one (monthly or yearly, its line, and when). The
-- API checked all four; the table's checks hold them again.
create or replace function public.plan_interest_note(p_email text, p_plan text, p_billing text, p_note text)
returns text
language sql
security definer
set search_path = public
as $$
    insert into public.plan_interest as i (email, plan, billing, note)
         values (p_email, p_plan, p_billing, coalesce(p_note, ''))
    on conflict (email, plan) do update
        set billing = excluded.billing, note = excluded.note, updated_at = now()
    -- A row the insert made has no xmax; one the conflict updated has.
    returning case when i.xmax = 0 then 'added' else 'changed' end;
$$;

-- How many would use each plan, monthly or yearly: people, and apart from
-- them Resend's test addresses (@resend.dev), which the site's checks use.
create or replace function public.plan_interest_counts()
returns table (plan text, billing text, people bigint, tests bigint)
language sql
stable
security definer
set search_path = public
as $$
    select i.plan, i.billing,
           count(*) filter (where i.email !~ '@resend\.dev$'),
           count(*) filter (where i.email ~ '@resend\.dev$')
      from public.plan_interest i
     group by i.plan, i.billing
     order by i.plan, i.billing;
$$;

-- Everything kept for [p_email], for its owner who asks what is kept.
create or replace function public.plan_interest_of(p_email text)
returns table (plan text, billing text, note text, created_at timestamptz, updated_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
    select i.plan, i.billing, i.note, i.created_at, i.updated_at
      from public.plan_interest i
     where i.email = lower(trim(p_email))
     order by i.plan;
$$;

-- [p_email]'s entries deleted, for its owner who asks: how many went.
create or replace function public.plan_interest_forget(p_email text)
returns integer
language sql
security definer
set search_path = public
as $$
    with gone as (delete from public.plan_interest where email = lower(trim(p_email)) returning 1)
    select count(*)::integer from gone;
$$;

revoke all on function public.plan_interest_may(text, integer, integer) from public, anon, authenticated;
revoke all on function public.plan_interest_note(text, text, text, text) from public, anon, authenticated;
revoke all on function public.plan_interest_counts() from public, anon, authenticated;
revoke all on function public.plan_interest_of(text) from public, anon, authenticated;
revoke all on function public.plan_interest_forget(text) from public, anon, authenticated;
grant execute on function public.plan_interest_may(text, integer, integer) to service_role;
grant execute on function public.plan_interest_note(text, text, text, text) to service_role;
grant execute on function public.plan_interest_counts() to service_role;
grant execute on function public.plan_interest_of(text) to service_role;
grant execute on function public.plan_interest_forget(text) to service_role;
