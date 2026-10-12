-- Claude, signed in to a Brickworks account: the connector's OAuth, 2026-10-11.
--
-- Until now each browser made its own connector address with a secret in
-- it (/api/mcp?t=…, supabase/relay.sql), and the person copied it into
-- Claude by hand. Now there is one address for everybody,
-- https://brickworks.diy/api/mcp, and Claude signs in to it the way MCP
-- says a client signs in to a server (OAuth 2.1 with PKCE): Claude
-- registers itself, sends the person to Brickworks to sign in with their
-- email code and allow it, and is handed a token that names their
-- account. The relay (api/mcp.js) sends each call on to whichever of
-- that account's tabs is open, on any device. api/oauth.js is the
-- authorization server; this is what it keeps.
--
--   oauth_clients  who may ask: Claude (claude.ai and the Claude apps) and
--                  Claude Code, which name themselves by the address of a
--                  document describing them, read and kept here; or a
--                  client that registered itself. Its name and the exact
--                  addresses it may be sent back to. Anyone may register
--                  (that is what dynamic registration is), so a client
--                  nobody signed in with goes after a day.
--   oauth_codes    a person said yes: a code for one client, one return
--                  address and one PKCE challenge, good once, for two
--                  minutes.
--   oauth_grants   a connection: this account allowed this client. What
--                  the account panel lists and "Disconnect" deletes, which
--                  takes every token of it with it.
--   oauth_tokens   the tokens a connection holds, by SHA-256 only — never
--                  the token. Access tokens last an hour; a refresh token
--                  is good until it is used, and is then replaced.
--
-- Additive only: four new tables and two functions. Nothing that exists
-- is changed. Only the server reaches them — row level security on with
-- no policies, and the publishable key's roles refused outright.

create table if not exists public.oauth_clients (
  client_id     text        primary key check (length(client_id) between 16 and 512),
  client_name   text        check (length(client_name) <= 200),
  redirect_uris text[]      not null check (cardinality(redirect_uris) between 1 and 10),
  -- none: a public client (Claude Code, a native app), which proves itself
  -- with PKCE alone. client_secret_post / client_secret_basic: one that
  -- asked for a secret, kept here only as its SHA-256.
  auth_method   text        not null default 'none'
                check (auth_method in ('none', 'client_secret_post', 'client_secret_basic')),
  secret_hash   text        check (secret_hash ~ '^[0-9a-f]{64}$'),
  -- A client whose id is the address of its own description (a Client ID
  -- Metadata Document: Claude's is https://claude.ai/oauth/mcp-oauth-
  -- client-metadata): when that was last read. Null for one that
  -- registered here.
  fetched_at    timestamptz,
  created_at    timestamptz not null default now(),
  used_at       timestamptz
);

create table if not exists public.oauth_codes (
  hash           text        primary key check (hash ~ '^[0-9a-f]{64}$'),
  client_id      text        not null references public.oauth_clients (client_id) on delete cascade,
  owner          uuid        not null references auth.users (id) on delete cascade,
  redirect_uri   text        not null,
  code_challenge text        not null check (code_challenge ~ '^[A-Za-z0-9_-]{43}$'),
  resource       text        not null,
  scope          text,
  expires_at     timestamptz not null,
  created_at     timestamptz not null default now()
);

create table if not exists public.oauth_grants (
  id           uuid        primary key default gen_random_uuid(),
  owner        uuid        not null references auth.users (id) on delete cascade,
  client_id    text        not null references public.oauth_clients (client_id) on delete cascade,
  -- Kept with the connection, so the panel can say which Claude it is
  -- after the client row has gone.
  client_name  text,
  redirect_uri text,
  resource     text        not null,
  scope        text,
  -- What the client called itself when it first said hello (MCP's
  -- clientInfo), and the tab it last built in, so a conversation stays
  -- in one tab while that tab is open.
  client_info  jsonb,
  channel      text        check (channel ~ '^[0-9a-f]{64}$'),
  created_at   timestamptz not null default now(),
  used_at      timestamptz
);
create index if not exists oauth_grants_owner on public.oauth_grants (owner);

create table if not exists public.oauth_tokens (
  hash        text        primary key check (hash ~ '^[0-9a-f]{64}$'),
  grant_id    uuid        not null references public.oauth_grants (id) on delete cascade,
  kind        text        not null check (kind in ('access', 'refresh')),
  expires_at  timestamptz not null,
  -- A refresh token, once it has been traded for a new pair. Presented
  -- again within a few seconds that is a client retrying; later, it is a
  -- copy in somebody else's hands, and the whole connection is ended.
  replaced_at timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists oauth_tokens_grant on public.oauth_tokens (grant_id);

alter table public.oauth_clients enable row level security;
alter table public.oauth_codes   enable row level security;
alter table public.oauth_grants  enable row level security;
alter table public.oauth_tokens  enable row level security;
revoke all on public.oauth_clients, public.oauth_codes, public.oauth_grants,
  public.oauth_tokens from anon, authenticated;

-- What has run out. Called now and then by api/oauth.js.
create or replace function public.oauth_sweep()
returns void
language sql
as $$
  delete from public.oauth_codes  where expires_at < now();
  delete from public.oauth_tokens where expires_at < now()
                                     or replaced_at < now() - interval '1 day';
  -- Registered and never used to sign anyone in.
  delete from public.oauth_clients c
   where c.used_at is null
     and c.created_at < now() - interval '1 day'
     and not exists (select 1 from public.oauth_grants g where g.client_id = c.client_id);
$$;

revoke all on function public.oauth_sweep() from public, anon, authenticated;
grant execute on function public.oauth_sweep() to service_role;
