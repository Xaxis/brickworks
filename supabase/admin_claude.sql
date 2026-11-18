-- Claude in the owner's console (adminclaude, 2026-11-18; docs/ADMIN_CLAUDE.md,
-- docs/ADMIN.md): the owner's own Anthropic key, their choice of model and
-- effort, and a monthly cap in dollars the server keeps to.
--
--   admin_claude_settings  one row a pool: the key, sealed (AES-256-GCM with
--                          CLAUDE_KEY_SECRET, which only the deployment has,
--                          so this row alone opens nothing), its last four
--                          characters to show, when it was last checked and
--                          what Anthropic said; the model, the effort and the
--                          month's cap
--   admin_claude_holds     each call to Anthropic: what it may cost at most,
--                          held before it is made, and what it did cost, read
--                          from its answer's usage. The month's spend is the
--                          settled costs, and a hold its function never
--                          settled (cut off) counted whole after six minutes
--   admin_claude_drafts    the social desk's drafts Claude made, marked "by
--                          Claude" on the desk; a draft dropped takes its mark
--
-- Two pools, as the console keeps everywhere: test = true is the checks' own
-- (/admin?tests=1), whose Anthropic is the stand-in (api/_claude_mock.js).
--
-- Nothing names an account of the site, so no export reaches it. Only the
-- server touches it, with the secret key: row security on, no policy, and
-- every grant taken back from the roles a page or a visitor has. The month's
-- holds are taken one at a time (an advisory lock), so two tabs asking at once
-- cannot both pass the cap.
--
-- Only additions: new tables and new functions. Nothing that exists is
-- changed or dropped. Applying it again changes nothing.

create table if not exists public.admin_claude_settings (
    test           boolean     primary key,
    key_sealed     text        constraint admin_claude_settings_key check (key_sealed is null
                                   or (key_sealed ~ '^v1\.[A-Za-z0-9_-]+$' and char_length(key_sealed) between 43 and 1203)),
    key_last4      text        constraint admin_claude_settings_last4 check (key_last4 is null or key_last4 ~ '^[A-Za-z0-9_-]{4}$'),
    key_set_at     timestamptz,
    key_checked_at timestamptz,
    key_said       text        constraint admin_claude_settings_said check (char_length(key_said) <= 300),
    model          text        not null default 'claude-opus-5-5'
                               constraint admin_claude_settings_model check (model ~ '^claude-[a-z0-9.-]{1,60}$'),
    effort         text        not null default 'high'
                               constraint admin_claude_settings_effort check (effort in ('low', 'medium', 'high', 'xhigh', 'max')),
    cap_usd        numeric(8, 2) not null default 25
                               constraint admin_claude_settings_cap check (cap_usd > 0 and cap_usd <= 10000),
    changed_at     timestamptz not null default now(),
    changed_by     text        constraint admin_claude_settings_by check (char_length(changed_by) <= 320),
    constraint admin_claude_settings_sealed_whole check ((key_sealed is null) = (key_last4 is null))
);

create table if not exists public.admin_claude_holds (
    id         uuid          primary key default gen_random_uuid(),
    test       boolean       not null default false,
    month      text          not null constraint admin_claude_holds_month check (month ~ '^[0-9]{4}-[0-9]{2}$'),
    model      text          not null constraint admin_claude_holds_model check (model ~ '^claude-[a-z0-9.-]{1,60}$'),
    held_usd   numeric(12, 6) not null constraint admin_claude_holds_held check (held_usd >= 0 and held_usd <= 10000),
    cost_usd   numeric(12, 6) constraint admin_claude_holds_cost check (cost_usd is null or (cost_usd >= 0 and cost_usd <= 10000)),
    made_at    timestamptz   not null default now(),
    settled_at timestamptz,
    constraint admin_claude_holds_settled check ((settled_at is null) = (cost_usd is null))
);
create index if not exists admin_claude_holds_month on public.admin_claude_holds (test, month);

create table if not exists public.admin_claude_drafts (
    send    text        primary key references public.social_sends (id) on delete cascade,
    test    boolean     not null default false,
    model   text        not null constraint admin_claude_drafts_model check (model ~ '^claude-[a-z0-9.-]{1,60}$'),
    ask     text        not null constraint admin_claude_drafts_ask check (ask in ('chat', 'suggest', 'reply', 'improve', 'overview')),
    made_at timestamptz not null default now()
);

alter table public.admin_claude_settings enable row level security;
alter table public.admin_claude_holds enable row level security;
alter table public.admin_claude_drafts enable row level security;

revoke all on public.admin_claude_settings from public, anon, authenticated;
revoke all on public.admin_claude_holds from public, anon, authenticated;
revoke all on public.admin_claude_drafts from public, anon, authenticated;

grant select, insert, update, delete on public.admin_claude_settings to service_role;
grant select, insert, update, delete on public.admin_claude_holds to service_role;
grant select, insert, update, delete on public.admin_claude_drafts to service_role;

-- The month as the cap counts it: the calendar month in UTC.
create or replace function public.admin_claude_month_of(p_at timestamptz)
returns text
language sql
immutable
set search_path = ''
as $$
    select to_char(p_at at time zone 'utc', 'YYYY-MM')
$$;

-- [p_test]'s month so far: {month, spent, held, calls}. Spent is every
-- settled cost, and every hold left unsettled six minutes (its function was
-- cut off: what it spent is not known, so all it held is counted); held is
-- what calls still running may cost.
create or replace function public.admin_claude_month(p_test boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object(
        'month', public.admin_claude_month_of(now()),
        'spent', coalesce(sum(case when h.settled_at is not null then h.cost_usd
                                   when h.made_at < now() - interval '6 minutes' then h.held_usd else 0 end), 0),
        'held', coalesce(sum(case when h.settled_at is null and h.made_at >= now() - interval '6 minutes' then h.held_usd
                                  else 0 end), 0),
        'calls', count(*))
    from public.admin_claude_holds h
    where h.test = coalesce(p_test, false) and h.month = public.admin_claude_month_of(now())
$$;

-- One call's most, held against [p_cap] for [p_test]'s month: {ok, id,
-- spent, held} when what is spent and held with it stays within the cap,
-- {ok: false, spent, held} when it would not. One at a time.
create or replace function public.admin_claude_hold(p_test boolean, p_model text, p_amount numeric, p_cap numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    now_month jsonb;
    made uuid;
begin
    if p_amount is null or p_amount < 0 or p_cap is null or p_cap <= 0 then
        raise exception 'admin_claude_hold: an amount and a cap';
    end if;
    perform pg_advisory_xact_lock(hashtext('admin_claude_hold'), case when coalesce(p_test, false) then 1 else 0 end);
    now_month := public.admin_claude_month(p_test);
    if (now_month ->> 'spent')::numeric + (now_month ->> 'held')::numeric + p_amount > p_cap then
        return jsonb_build_object('ok', false, 'spent', now_month -> 'spent', 'held', now_month -> 'held');
    end if;
    insert into public.admin_claude_holds (test, month, model, held_usd)
    values (coalesce(p_test, false), now_month ->> 'month', p_model, p_amount)
    returning id into made;
    return jsonb_build_object('ok', true, 'id', made, 'spent', now_month -> 'spent', 'held', now_month -> 'held');
end
$$;

-- Hold [p_id] settled at what its call cost, read from its answer: the month
-- after. A hold settled already is left as it was.
create or replace function public.admin_claude_settle(p_id uuid, p_cost numeric)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    pool boolean;
begin
    update public.admin_claude_holds set cost_usd = greatest(coalesce(p_cost, 0), 0), settled_at = now()
    where id = p_id and settled_at is null
    returning test into pool;
    if pool is null then
        select test into pool from public.admin_claude_holds where id = p_id;
    end if;
    return public.admin_claude_month(coalesce(pool, false));
end
$$;

revoke all on function public.admin_claude_month_of(timestamptz) from public, anon, authenticated;
revoke all on function public.admin_claude_month(boolean) from public, anon, authenticated;
revoke all on function public.admin_claude_hold(boolean, text, numeric, numeric) from public, anon, authenticated;
revoke all on function public.admin_claude_settle(uuid, numeric) from public, anon, authenticated;
grant execute on function public.admin_claude_month_of(timestamptz) to service_role;
grant execute on function public.admin_claude_month(boolean) to service_role;
grant execute on function public.admin_claude_hold(boolean, text, numeric, numeric) to service_role;
grant execute on function public.admin_claude_settle(uuid, numeric) to service_role;

notify pgrst, 'reload schema';
