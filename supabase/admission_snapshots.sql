-- Admission's last answers, kept for when it cannot be reached, 2026-10-29.
--
-- Plans come from Admission (https://admission.sh, docs/PLANS.md, unit U1):
-- what an account's plan includes, how many Claude builds it has used, its
-- comps and its subscription. The server asks it through its client
-- (api/_admission.js, api/_billing.js), which keeps each answer as a
-- snapshot so that, while Admission cannot be reached, a paying person is
-- answered from their last one and never refused. Bookwright keeps them in
-- Redis and onon in Vercel KV; Brickworks has neither, so they go here.
--
--   admission_snapshots  one row a key the client names
--                        (admission:v2:brickworks:<test|live>:c:<user id>,
--                        and …:plans), its JSON as the client wrote it: the
--                        plan, each feature's numbers and the subscription's
--                        dates. No address, no name, nothing of Stripe's
--                        but a subscription's id. An erased customer's is
--                        written empty. Rows not written for 90 days go.
--
-- Only the server touches it, through the two functions here, each
-- security definer and granted to the service role alone:
--
--   admission_snapshot_get  the value under a key, or null
--   admission_snapshot_put  the value under a key written, or replaced
--
-- Only additions: one new table, an index and two new functions. Nothing
-- that exists is changed. Applying it again changes nothing.

create table if not exists public.admission_snapshots (
    key        text        primary key
        constraint admission_snapshots_key check (key like 'admission:v2:%' and length(key) <= 200),
    value      text        not null constraint admission_snapshots_value check (length(value) <= 100000),
    updated_at timestamptz not null default now()
);
create index if not exists admission_snapshots_old on public.admission_snapshots (updated_at);

alter table public.admission_snapshots enable row level security;
revoke all on public.admission_snapshots from public, anon, authenticated, service_role;

-- The value kept under [p_key], or null when there is none.
create or replace function public.admission_snapshot_get(p_key text)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select s.value from public.admission_snapshots s where s.key = p_key;
$$;

-- [p_value] kept under [p_key], over what was there. Snapshots outlive any
-- outage worth riding out, then go: rows not written for 90 days.
create or replace function public.admission_snapshot_put(p_key text, p_value text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.admission_snapshots where updated_at < now() - interval '90 days';
    insert into public.admission_snapshots as s (key, value) values (p_key, p_value)
    on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;

revoke all on function public.admission_snapshot_get(text) from public, anon, authenticated;
revoke all on function public.admission_snapshot_put(text, text) from public, anon, authenticated;
grant execute on function public.admission_snapshot_get(text) to service_role;
grant execute on function public.admission_snapshot_put(text, text) to service_role;
