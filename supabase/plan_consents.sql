-- What someone agreed to before paying for Pro, 2026-10-29.
--
-- The step before Stripe Checkout (web/plan.js, api/plans.js ?op=checkout)
-- says the price and how often it is charged, that it renews at it until
-- cancelled, how to cancel and who sells it, beside a box nobody ticks but
-- the person (docs/PLANS.md M7, Bookwright's ADR-0014 decision 6). The
-- server refuses Checkout without it, and keeps the agreement first: the
-- laws on automatic renewal ask that it can be shown later, for three
-- years, so it is kept four, past the account's deletion.
--
--   plan_consents  one row an agreement: the account's id (no address),
--                  when, the plan, month or year, the price in cents and
--                  its currency, and the terms as they were said. The
--                  last 50 of an account; none older than four years.
--
-- Only the server touches it, through the one function here, security
-- definer and granted to the service role alone:
--
--   plan_consent_note  an agreement kept
--
-- Only additions: one new table, an index and one new function. Nothing
-- that exists is changed. Applying it again changes nothing.

create table if not exists public.plan_consents (
    id               bigint      generated always as identity primary key,
    account          uuid        not null,
    agreed_at        timestamptz not null default now(),
    plan             text        not null constraint plan_consents_plan check (plan ~ '^[a-z][a-z0-9_]{0,31}$'),
    billing_interval text        not null constraint plan_consents_interval check (billing_interval in ('month', 'year')),
    amount           integer     not null constraint plan_consents_amount check (amount >= 0),
    currency         text        not null constraint plan_consents_currency check (currency ~ '^[a-z]{3}$'),
    terms            text        not null constraint plan_consents_terms check (length(terms) between 1 and 1000)
);
create index if not exists plan_consents_account on public.plan_consents (account, agreed_at desc);

alter table public.plan_consents enable row level security;
revoke all on public.plan_consents from public, anon, authenticated, service_role;

-- [p_user] agreed just now to [p_plan] renewing at [p_amount] of
-- [p_currency] each [p_interval], in the words [p_terms]. Kept: the last 50
-- of an account, and nothing past four years.
create or replace function public.plan_consent_note(p_user uuid, p_plan text, p_interval text, p_amount integer,
    p_currency text, p_terms text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.plan_consents (account, plan, billing_interval, amount, currency, terms)
    values (p_user, p_plan, p_interval, p_amount, p_currency, p_terms);
    delete from public.plan_consents c
    where c.account = p_user
      and c.id not in (select k.id from public.plan_consents k where k.account = p_user
                       order by k.agreed_at desc, k.id desc limit 50);
    delete from public.plan_consents where agreed_at < now() - interval '4 years';
end;
$$;

revoke all on function public.plan_consent_note(uuid, text, text, integer, text, text) from public, anon, authenticated;
grant execute on function public.plan_consent_note(uuid, text, text, integer, text, text) to service_role;
