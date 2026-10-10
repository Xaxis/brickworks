-- The Claude connector's relay, 2026-10-09.
--
-- Someone on a Claude plan adds their open Brickworks tab to Claude as a
-- connector: a private address with a token in it. Claude sends MCP
-- requests there (api/mcp.js); the tab collects them, answers them with the
-- same code that serves the desktop's MCP tools, and sends the answers
-- back. Serverless functions share nothing between calls, so the messages
-- wait here for the few seconds in between.
--
-- What is never here: an API key, a Claude login, a token. A channel is the
-- SHA-256 of the tab's token, so the address that drives a tab cannot be
-- read back out of this table. Rows go after ten minutes.
--
-- Only the server reaches these: row level security is on with no
-- policies, and the publishable key's roles are refused outright.

create table if not exists public.relay (
  id          bigint generated always as identity primary key,
  channel     text        not null check (channel ~ '^[0-9a-f]{64}$'),
  request     jsonb       not null,
  response    jsonb,
  taken_at    timestamptz,
  answered_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists relay_waiting on public.relay (channel, id)
  where taken_at is null;

-- When each tab last asked for work, so Claude is told at once that the
-- tab is closed rather than waiting out a timeout.
create table if not exists public.relay_tabs (
  channel text        primary key check (channel ~ '^[0-9a-f]{64}$'),
  seen_at timestamptz not null default now()
);

alter table public.relay      enable row level security;
alter table public.relay_tabs enable row level security;
revoke all on public.relay, public.relay_tabs from anon, authenticated;

-- Hand the oldest waiting request on a channel to the tab, once. Skip
-- locked, so two polls from one tab (a reload mid-wait) cannot both take it.
create or replace function public.relay_take(p_channel text)
returns table (id bigint, request jsonb)
language sql
as $$
  update public.relay r
     set taken_at = now()
   where r.id = (
     select w.id from public.relay w
      where w.channel = p_channel
        and w.taken_at is null
        and w.created_at > now() - interval '3 minutes'
      order by w.id
      for update skip locked
      limit 1)
  returning r.id, r.request;
$$;

create or replace function public.relay_sweep()
returns void
language sql
as $$
  delete from public.relay      where created_at < now() - interval '10 minutes';
  delete from public.relay_tabs where seen_at    < now() - interval '1 day';
$$;

revoke all on function public.relay_take(text), public.relay_sweep()
  from public, anon, authenticated;
-- Revoking from public takes them from the server's own role too, which
-- had them only through public.
grant execute on function public.relay_take(text), public.relay_sweep()
  to service_role;
