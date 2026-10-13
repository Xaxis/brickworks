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
create index if not exists relay_unanswered on public.relay (channel, id)
  where answered_at is null;

-- When each tab last asked for work, so Claude is told at once that the
-- tab is closed rather than waiting out a timeout.
create table if not exists public.relay_tabs (
  channel text        primary key check (channel ~ '^[0-9a-f]{64}$'),
  seen_at timestamptz not null default now()
);

-- 2026-10-10, after the first real use from claude.ai. Claude's call was
-- taken by a tab the person had switched away from; a browser stops
-- drawing a tab it is not showing, the engine runs on drawing, so the call
-- waited, timed out in the tab and was lost, and the panel never moved.
--
--   hello     the tab's own answers to initialize and tools/list, sent when
--             it switches on, so Claude can add and list the connector
--             while the tab is asleep or shut — only a tool call needs it
--   instance  which page load is listening: the latest one to switch on;
--             any older one is told it has been replaced
--   visible   what the page last said about being on screen, so Claude can
--             be told to ask for the tab to be brought into view
--   open      false once the page has gone; the row is kept for its hello
alter table public.relay_tabs add column if not exists hello    jsonb;
alter table public.relay_tabs add column if not exists instance text;
alter table public.relay_tabs add column if not exists visible  boolean not null default true;
alter table public.relay_tabs add column if not exists open     boolean not null default true;

-- 2026-10-11: everyone who uses Brickworks signs in, and a connector
-- belongs to the account that switched it on. api/mcp.js verifies the
-- session that comes with op=hello and writes its account here; an address
-- another account owns is refused, and a tab with no owner is handed no
-- work. Rows from before have none, and count as switched off until a
-- signed-in page says hello again. Gone with the account.
alter table public.relay_tabs add column if not exists owner uuid
  references auth.users (id) on delete cascade;
create index if not exists relay_tabs_owner on public.relay_tabs (owner);

-- 2026-10-13: several tabs of one account, each a connector of its own.
-- A tab keeps its token with its own working state now, so every tab is a
-- row here, and Claude chooses between them (api/mcp.js):
--
--   tab       the tab's short id (src/parts/tab_session.gd), what Claude
--             calls it by: the tabs tool lists it, select_tab and target
--             take it
--   model     the name of the model open in it, as the page last said
--   used_at   when the person last used it: a session's first call goes
--             to the tab used most recently
alter table public.relay_tabs add column if not exists tab     text
  check (tab ~ '^[a-z2-9]{4,12}$');
alter table public.relay_tabs add column if not exists model   text;
alter table public.relay_tabs add column if not exists used_at timestamptz;

-- Which tab each Claude session is working in, so its calls stay in one
-- model: by the Mcp-Session-Id the relay hands out at initialize
-- ("session:<id>"), or by the connection for a client that sends none
-- ("connection:<grant id>"). Set by a session's first call and by
-- select_tab; gone once that tab has closed and the session was told.
create table if not exists public.relay_picks (
  key       text        primary key,
  owner     uuid        references auth.users (id) on delete cascade,
  channel   text        not null check (channel ~ '^[0-9a-f]{64}$'),
  picked_at timestamptz not null default now()
);

-- 2026-10-13: which tools each Claude conversation was given, by the same
-- key as its pick (or "address:<channel>" for a tab's own address with no
-- session), so that when the tab it works in says hello with other tools —
-- reloaded into a newer build — the conversation is told so, once
-- (api/mcp.js, notifications/tools/list_changed). A list is a short hash
-- of the tab's tools, never the tools.
--
--   listed  the list it was last given (initialize, tools/list)
--   told    the list it was last told had changed to
create table if not exists public.relay_lists (
  key    text        primary key,
  listed text        not null,
  told   text,
  at     timestamptz not null default now()
);

alter table public.relay       enable row level security;
alter table public.relay_tabs  enable row level security;
alter table public.relay_picks enable row level security;
alter table public.relay_lists enable row level security;
revoke all on public.relay, public.relay_tabs, public.relay_picks, public.relay_lists
  from anon, authenticated;

-- Hand the oldest waiting request on a channel to the tab. Skip locked, so
-- two polls cannot both take it at once.
--
-- Also one taken more than two seconds ago and still not answered. A tab
-- works through one request at a time and asks for the next only when it
-- has answered, so a tab asking again with one outstanding has dropped it
-- — it was asleep in the background when it arrived — and is given it
-- again rather than leaving Claude waiting on an answer nobody will send.
create or replace function public.relay_take(p_channel text)
returns table (id bigint, request jsonb)
language sql
as $$
  update public.relay r
     set taken_at = now()
   where r.id = (
     select w.id from public.relay w
      where w.channel = p_channel
        and w.answered_at is null
        and (w.taken_at is null or w.taken_at < now() - interval '2 seconds')
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
  -- Kept a month, for its hello: a connector added once lists its tools
  -- on any later visit, and a call tells the person to open the tab.
  delete from public.relay_tabs where seen_at    < now() - interval '30 days';
  delete from public.relay_picks where picked_at < now() - interval '30 days';
  delete from public.relay_lists where at        < now() - interval '30 days';
$$;

revoke all on function public.relay_take(text), public.relay_sweep()
  from public, anon, authenticated;
-- Revoking from public takes them from the server's own role too, which
-- had them only through public.
grant execute on function public.relay_take(text), public.relay_sweep()
  to service_role;
