-- The owner's notifications (ownernotify, 2026-11-18; docs/OWNER_NOTIFY.md,
-- docs/ADMIN.md): mail to the site's owner about what happens on it, each
-- kind of event on or off, at once or in a daily digest, with quiet hours, a
-- cap an hour and a pause, set in /admin › Notifications.
--
--   owner_notify_settings  what the owner chose, one row a deployment (scope:
--                          "live" for brickworks.diy, else a preview's host)
--                          and pool (test = the checks' own): the address
--                          when it is not the account's own (and one waiting
--                          on its code), quiet hours, the digest's time, the
--                          cap, the pause, each event's choice; and the key
--                          the one-click "turn this off" links are signed
--                          with
--   owner_notify_events    each thing that happened, kept once by its own key
--                          (an account, a report, an Admission event, an
--                          hour), and where it stands: new, held for quiet
--                          hours, capped for the hour, waiting for the
--                          digest, mailed, or not to be mailed (off, paused)
--   owner_notify_mails     each mail sent, failed or written to a test inbox:
--                          its subject and words, to whom (in part), how many
--                          events it carried
--   owner_notify_errors    each answer of 500 or over any function gave, for
--                          the errors-an-hour threshold; kept two days
--
-- Two pools, as the console keeps everywhere: test = true is the checks' own
-- (/admin?tests=1), whose mail goes to Resend's test inbox and never to the
-- owner.
--
-- owner_notify_events.account names the account an event was about (a
-- sign-up, a first model), with no foreign key: an account's deletion
-- (api/_erase.js) deletes its events by it, and an export never reaches them.
-- Only the server touches any of it, with the secret key: row security on, no
-- policy, and every grant taken back from the roles a page or a visitor has.
--
-- Only additions: new tables. Nothing that exists is changed or dropped.
-- Applying it again changes nothing.

create table if not exists public.owner_notify_settings (
    scope           text        not null constraint owner_notify_settings_scope check (scope ~ '^[a-z0-9.:-]{1,200}$'),
    test            boolean     not null default false,
    -- {tz, quiet: {on, from, to}, digest_at, cap, paused, events: {name: {on, when, threshold?, ...}}}:
    -- read and checked by api/_notify.js, which fills in what is missing.
    settings        jsonb       not null default '{}'::jsonb constraint owner_notify_settings_settings
                        check (jsonb_typeof(settings) = 'object' and pg_column_size(settings) <= 16384),
    -- null: the owner's own verified account address.
    address         text        constraint owner_notify_settings_address
                        check (address ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and char_length(address) <= 320),
    -- Another address asked for, until the code mailed to it is typed back.
    pending_address text        constraint owner_notify_settings_pending_address
                        check (pending_address ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and char_length(pending_address) <= 320),
    pending_code    text        constraint owner_notify_settings_pending_code check (pending_code ~ '^[0-9a-f]{64}$'),
    pending_until   timestamptz,
    pending_tries   smallint    not null default 0 constraint owner_notify_settings_pending_tries check (pending_tries between 0 and 10),
    -- What the one-click links to turn an event off are signed with, made
    -- here and never shown.
    off_key         text        not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
                        constraint owner_notify_settings_off_key check (off_key ~ '^[0-9a-f]{64}$'),
    -- The owner's own day (in their time zone) the digest last went, or was
    -- found with nothing to say.
    digest_on       date,
    set_by          text        constraint owner_notify_settings_set_by check (char_length(set_by) <= 320),
    set_at          timestamptz not null default now(),
    -- One more each write: a write names the version it read, so two at
    -- once (two presses, a mail's off link, the cron's digest) never lose
    -- what the other changed (api/_notify.js writeRow).
    version         integer     not null default 0 constraint owner_notify_settings_version check (version >= 0),
    primary key (scope, test),
    constraint owner_notify_settings_pending check ((pending_address is null) = (pending_code is null))
);

create table if not exists public.owner_notify_mails (
    id        text        primary key constraint owner_notify_mails_id check (id ~ '^[a-z0-9]{12}$'),
    scope     text        not null constraint owner_notify_mails_scope check (scope ~ '^[a-z0-9.:-]{1,200}$'),
    test      boolean     not null default false,
    at        timestamptz not null default now(),
    -- now: one kind's events; digest: the day's; fold: what the hour's cap or
    -- quiet hours held, in one; test: the owner's Send a test; confirm: a new
    -- address's code (its code never kept here); alarm: Supabase refusing,
    -- sent without the database.
    kind      text        not null constraint owner_notify_mails_kind
                  check (kind in ('now', 'digest', 'fold', 'test', 'confirm', 'alarm')),
    event     text        constraint owner_notify_mails_event check (event ~ '^[a-z_]{1,40}$'),
    subject   text        not null constraint owner_notify_mails_subject check (char_length(subject) between 1 and 300),
    body      text        not null default '' constraint owner_notify_mails_body check (char_length(body) <= 8000),
    events    integer     not null default 0 constraint owner_notify_mails_events check (events >= 0),
    -- The address in part (wi•••@example.com), never whole.
    sent_to   text        not null constraint owner_notify_mails_sent_to check (char_length(sent_to) between 1 and 320),
    state     text        not null constraint owner_notify_mails_state check (state in ('sent', 'dry', 'failed')),
    resend_id text        constraint owner_notify_mails_resend_id check (char_length(resend_id) <= 100),
    said      text        constraint owner_notify_mails_said check (char_length(said) <= 300)
);

create table if not exists public.owner_notify_events (
    id         bigint      generated always as identity primary key,
    scope      text        not null constraint owner_notify_events_scope check (scope ~ '^[a-z0-9.:-]{1,200}$'),
    test       boolean     not null default false,
    event      text        not null constraint owner_notify_events_event
                   check (event in ('signup', 'first_model', 'feedback', 'plan', 'errors', 'quota', 'social', 'social_send')),
    key        text        not null constraint owner_notify_events_key check (char_length(key) between 1 and 200),
    account    uuid,
    at         timestamptz not null default now(),
    detail     jsonb       not null default '{}'::jsonb constraint owner_notify_events_detail
                   check (jsonb_typeof(detail) = 'object' and pg_column_size(detail) <= 4096),
    state      text        not null default 'new' constraint owner_notify_events_state
                   check (state in ('new', 'held', 'capped', 'digest', 'sending', 'mailed', 'off', 'paused', 'failed')),
    mail       text        references public.owner_notify_mails (id) on delete set null,
    tries      smallint    not null default 0 constraint owner_notify_events_tries check (tries between 0 and 10),
    changed_at timestamptz not null default now(),
    constraint owner_notify_events_once unique (scope, test, event, key)
);

create index if not exists owner_notify_events_waiting on public.owner_notify_events (scope, test, state, at);
create index if not exists owner_notify_events_account on public.owner_notify_events (account) where account is not null;
create index if not exists owner_notify_mails_recent on public.owner_notify_mails (scope, test, at desc);

create table if not exists public.owner_notify_errors (
    id     bigint      generated always as identity primary key,
    scope  text        not null constraint owner_notify_errors_scope check (scope ~ '^[a-z0-9.:-]{1,200}$'),
    at     timestamptz not null default now(),
    fn     text        not null constraint owner_notify_errors_fn check (fn ~ '^[a-z_]{1,20}$'),
    op     text        constraint owner_notify_errors_op check (char_length(op) <= 40),
    status smallint    not null constraint owner_notify_errors_status check (status between 500 and 599)
);

create index if not exists owner_notify_errors_recent on public.owner_notify_errors (scope, at);

alter table public.owner_notify_settings enable row level security;
alter table public.owner_notify_mails enable row level security;
alter table public.owner_notify_events enable row level security;
alter table public.owner_notify_errors enable row level security;

revoke all on public.owner_notify_settings from public, anon, authenticated;
revoke all on public.owner_notify_mails from public, anon, authenticated;
revoke all on public.owner_notify_events from public, anon, authenticated;
revoke all on public.owner_notify_errors from public, anon, authenticated;

grant select, insert, update, delete on public.owner_notify_settings to service_role;
grant select, insert, update, delete on public.owner_notify_mails to service_role;
grant select, insert, update, delete on public.owner_notify_events to service_role;
grant select, insert, update, delete on public.owner_notify_errors to service_role;

notify pgrst, 'reload schema';
