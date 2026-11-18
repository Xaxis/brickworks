-- The owner's social desk (socialdesk, 2026-11-18; docs/SOCIAL_DESK.md,
-- docs/ADMIN.md): Brickworks' own accounts on Reddit first, and X, Facebook
-- and Instagram later, run from /admin › Social. One model for every network:
--
--   social_accounts  each network connected by its API: whose account, since
--                    when, by whom, its last look for what came in
--   social_tokens    that connection's keys (OAuth access and refresh
--                    tokens), the server's alone: no page and no log is ever
--                    given them, and Disconnect deletes the row
--   social_items     what came in: replies to our posts and comments,
--                    mentions found by search, private messages; each read
--                    or not, with its address at the network
--   social_sends     what the owner writes: a post to a community or a reply
--                    to an item, from a draft to sent. Nothing leaves until
--                    the owner presses Send (or Schedule) on its exact words:
--                    the press is kept with a hash of those words, and the
--                    database refuses any row past a draft without one
--   social_results   a sent post's score and comments over time, as the
--                    network said them
--   social_visits    the visits a sent post brought to brickworks.diy: each
--                    landing with its utm_campaign (bw-<send id>), counted
--                    once by the browser's own random nonce
--   social_rules     a community's rules as the network said them, kept a
--                    day, and the owner's own notes on them
--
-- Two pools, as the console keeps everywhere: test = true is the checks' own
-- (/admin?tests=1, against the mock Reddit in api/_social_mock.js), never
-- shown with the owner's.
--
-- No table names an account of the site (no foreign key to auth.users), so
-- an account's export (admin_export) never reaches any of it. Only the
-- server touches it, with the secret key: row security on, no policy, and
-- every grant taken back from the roles a page or a visitor has.
--
-- Only additions: new tables. Nothing that exists is changed or dropped.
-- Applying it again changes nothing.

create table if not exists public.social_accounts (
    provider     text        not null constraint social_accounts_provider check (provider in ('reddit', 'x', 'facebook', 'instagram')),
    test         boolean     not null default false,
    handle       text        not null constraint social_accounts_handle check (char_length(handle) between 1 and 100),
    external_id  text        constraint social_accounts_external_id check (char_length(external_id) <= 100),
    scopes       text        not null default '' constraint social_accounts_scopes check (char_length(scopes) <= 1000),
    connected_by text        not null constraint social_accounts_connected_by check (char_length(connected_by) between 1 and 320),
    connected_at timestamptz not null default now(),
    synced_at    timestamptz,
    sync_said    text        constraint social_accounts_sync_said check (char_length(sync_said) <= 500),
    primary key (provider, test)
);

create table if not exists public.social_tokens (
    provider      text        not null,
    test          boolean     not null default false,
    access_token  text        not null constraint social_tokens_access check (char_length(access_token) between 1 and 4000),
    refresh_token text        constraint social_tokens_refresh check (char_length(refresh_token) <= 4000),
    expires_at    timestamptz,
    changed_at    timestamptz not null default now(),
    primary key (provider, test),
    constraint social_tokens_account foreign key (provider, test)
        references public.social_accounts (provider, test) on delete cascade
);

create table if not exists public.social_items (
    provider    text        not null constraint social_items_provider check (provider in ('reddit', 'x', 'facebook', 'instagram')),
    test        boolean     not null default false,
    external_id text        not null constraint social_items_external_id check (char_length(external_id) between 1 and 100),
    kind        text        not null constraint social_items_kind check (kind in ('reply', 'mention', 'message')),
    -- What the network called it: comment_reply, post_reply,
    -- username_mention, search, message.
    detail      text        not null default '' constraint social_items_detail check (char_length(detail) <= 40),
    author      text        constraint social_items_author check (char_length(author) <= 100),
    subject     text        constraint social_items_subject check (char_length(subject) <= 300),
    body        text        not null default '' constraint social_items_body check (char_length(body) <= 10000),
    url         text        constraint social_items_url check (url ~ '^https://'),
    community   text        constraint social_items_community check (char_length(community) <= 100),
    thread      text        constraint social_items_thread check (char_length(thread) <= 300),
    made_at     timestamptz not null,
    seen_at     timestamptz not null default now(),
    read_at     timestamptz,
    primary key (provider, test, external_id)
);
create index if not exists social_items_newest on public.social_items (test, made_at desc);

create table if not exists public.social_sends (
    id           text        primary key constraint social_sends_id check (id ~ '^[a-z0-9]{10}$'),
    provider     text        not null constraint social_sends_provider check (provider in ('reddit', 'x', 'facebook', 'instagram')),
    test         boolean     not null default false,
    kind         text        not null constraint social_sends_kind check (kind in ('post', 'reply')),
    community    text        constraint social_sends_community check (community ~ '^[A-Za-z0-9_]{2,21}$'),
    parent       text        constraint social_sends_parent check (char_length(parent) between 1 and 100),
    title        text        not null default '' constraint social_sends_title check (char_length(title) <= 300),
    body         text        not null default '' constraint social_sends_body check (char_length(body) <= 40000),
    link         text        constraint social_sends_link check (link ~ '^https?://' and char_length(link) <= 2000),
    status       text        not null default 'draft' constraint social_sends_status check (
                     status in ('draft', 'scheduled', 'sending', 'handed', 'sent', 'failed')),
    -- How it leaves: by the network's API, or by hand (the network's own
    -- page opened with the words, and the owner presses Post there).
    route        text        constraint social_sends_route check (route in ('api', 'by_hand')),
    pressed_at   timestamptz,
    pressed_by   text        constraint social_sends_pressed_by check (char_length(pressed_by) between 1 and 320),
    pressed_hash text        constraint social_sends_pressed_hash check (pressed_hash ~ '^[0-9a-f]{64}$'),
    send_at      timestamptz,
    sent_at      timestamptz,
    external_id  text        constraint social_sends_external_id check (char_length(external_id) <= 100),
    url          text        constraint social_sends_url check (url ~ '^https://' and char_length(url) <= 1000),
    said         text        constraint social_sends_said check (char_length(said) <= 500),
    made_at      timestamptz not null default now(),
    changed_at   timestamptz not null default now(),
    -- A reply answers something; a post goes somewhere once it is past a draft.
    constraint social_sends_parent_kind check ((kind = 'reply') = (parent is not null)),
    constraint social_sends_where check (status = 'draft' or kind = 'reply' or community is not null),
    -- Past a draft only by the owner's press, its words' hash and its route kept.
    constraint social_sends_pressed check (status = 'draft'
        or (pressed_at is not null and pressed_by is not null and pressed_hash is not null and route is not null)),
    constraint social_sends_scheduled check (status <> 'scheduled' or send_at is not null),
    constraint social_sends_sent check (status <> 'sent' or (sent_at is not null and url is not null))
);
create index if not exists social_sends_newest on public.social_sends (test, changed_at desc);
create index if not exists social_sends_due on public.social_sends (send_at) where status = 'scheduled';

create table if not exists public.social_results (
    send     text        not null references public.social_sends (id) on delete cascade,
    at       timestamptz not null default now(),
    score    integer,
    comments integer     constraint social_results_comments check (comments >= 0),
    ratio    real        constraint social_results_ratio check (ratio between 0 and 1),
    primary key (send, at)
);

create table if not exists public.social_visits (
    send   text        not null references public.social_sends (id) on delete cascade,
    nonce  text        not null constraint social_visits_nonce check (nonce ~ '^[a-z0-9]{8,24}$'),
    at     timestamptz not null default now(),
    path   text        not null default '/' constraint social_visits_path check (path ~ '^/' and char_length(path) <= 300),
    source text        constraint social_visits_source check (source ~ '^[a-z0-9_.-]{1,40}$'),
    primary key (send, nonce)
);

create table if not exists public.social_rules (
    provider  text        not null constraint social_rules_provider check (provider in ('reddit', 'x', 'facebook', 'instagram')),
    test      boolean     not null default false,
    community text        not null constraint social_rules_community check (community ~ '^[A-Za-z0-9_]{2,21}$'),
    rules     jsonb       constraint social_rules_rules check (rules is null or (jsonb_typeof(rules) = 'object'
                  and pg_column_size(rules) <= 65536)),
    read_at   timestamptz,
    notes     text        constraint social_rules_notes check (char_length(notes) <= 4000),
    noted_at  timestamptz,
    primary key (provider, test, community)
);

alter table public.social_accounts enable row level security;
alter table public.social_tokens enable row level security;
alter table public.social_items enable row level security;
alter table public.social_sends enable row level security;
alter table public.social_results enable row level security;
alter table public.social_visits enable row level security;
alter table public.social_rules enable row level security;

revoke all on public.social_accounts from public, anon, authenticated;
revoke all on public.social_tokens from public, anon, authenticated;
revoke all on public.social_items from public, anon, authenticated;
revoke all on public.social_sends from public, anon, authenticated;
revoke all on public.social_results from public, anon, authenticated;
revoke all on public.social_visits from public, anon, authenticated;
revoke all on public.social_rules from public, anon, authenticated;

grant select, insert, update, delete on public.social_accounts to service_role;
grant select, insert, update, delete on public.social_tokens to service_role;
grant select, insert, update, delete on public.social_items to service_role;
grant select, insert, update, delete on public.social_sends to service_role;
grant select, insert, update, delete on public.social_results to service_role;
grant select, insert, update, delete on public.social_visits to service_role;
grant select, insert, update, delete on public.social_rules to service_role;
