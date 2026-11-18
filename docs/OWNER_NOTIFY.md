# The owner's notifications

The owner asked on 2026-11-18: "I should be receiving notifications (via
email) for pertinent things that happen in the system like user sign ups,
and that should all be configurable." They live at **/admin ›
Notifications**, which only the owner can open (docs/ADMIN.md).

Every source below was read on 2026-11-18. **primary** means the product's
own docs. **unconfirmed** means no source said it either way.

## What the owner's other services mail them

### Stripe (behind Admission)

- Account mail to the owner and team: a successful payment, a dispute, an
  elevated-risk payment, an application fee, Connect's risk requirements, a
  teammate's mention. Each teammate turns each off for themselves under
  Communication preferences. No digest, no thresholds, no quiet hours.
  <https://support.stripe.com/questions/set-up-account-email-notifications>
  (primary).
- A plan bought, changed or cancelled, or a payment failed, mailed to the
  *owner*: not in that list (unconfirmed). Stripe's own failed-payment,
  trial-ending and renewal mails go to the *customer*, each on or off.
  <https://docs.stripe.com/billing/revenue-recovery/customer-emails> (primary).
- So the site tells of plans itself, from Admission's signed webhook, which
  already reaches `api/plans.js`.

### Supabase

- Mail when the organization goes **over** its quota (to the billing
  address), and before Fair Use restrictions. No percentage thresholds: the
  cost-control page says the Spend Cap gives no "notifications when certain
  costs are reached".
  <https://supabase.com/docs/guides/platform/cost-control>,
  <https://supabase.com/docs/guides/platform/billing-faq> (primary).
- No digest, quiet hours or per-event switches (unconfirmed). Supabase's
  advice is to look at the usage page by hand.
- On 2026-11-12 the project was restricted for egress before anyone knew it
  was near (docs/ADMIN.md, Data). Hence the site's own "Supabase near its
  quota", at the owner's percentage, and an alarm that goes even when the
  database refuses.

### Vercel

- Deployment failed and ready, usage and error anomalies, usage increased
  and limit reached, domains, team requests, a failed invoice; web and mail
  on by default, per person and per type; critical ones cannot have every
  channel off. A mail is not sent if the notification was already read on
  the web. <https://vercel.com/docs/notifications> (primary).
- Spend Management (Pro): alerts at 50%, 75% and 100% by default, checked
  every few minutes. <https://vercel.com/docs/spend-management> (primary).
- Monitors (Observability Plus) run every 5 minutes to 2 hours, with an
  "only if metric >=" floor. <https://vercel.com/docs/alerts/configure-alerts>
  (primary).
- Batching: only "Domain Misconfigured" is batched; schema errors at most
  once an hour. No digest, no quiet hours (unconfirmed).

### Plausible

- Weekly and monthly reports at a fixed time; a traffic spike alert
  (current visitors, default 10) and a drop alert, **each at most 2 mails a
  site in 24 hours**. No quiet hours.
  <https://plausible.io/docs/email-reports>,
  <https://plausible.io/docs/traffic-spikes> (primary).

### Resend (the sender)

- An `Idempotency-Key` header makes a send once per key for 24 hours:
  <https://resend.com/docs/dashboard/emails/idempotency-keys> (primary). The
  alarm uses it, so a cron that runs again sends one alarm a day.
- One-click unsubscribe is RFC 8058: `List-Unsubscribe` with an HTTPS
  address and `List-Unsubscribe-Post: List-Unsubscribe=One-Click`, which the
  mail app POSTs. <https://www.rfc-editor.org/rfc/rfc8058> (primary).

### What none of them do, and this does

- **Quiet hours** that hold mail and send it as one when they end.
- **At once or a daily digest, per kind**, at the owner's time in their
  time zone.
- **A cap an hour** with what is past it folded into one "And N more" mail.
- **Batching of one kind**: a burst of sign-ups is one mail.
- **Pause all**, and **Send a test** of the whole or of one kind.
- **One place** for events from every service, with the record of every
  mail sent, held or folded.

## What mails the owner

| Kind | Raised where | Default | Notes |
|---|---|---|---|
| A new sign-up | api/otp.js (the account made as its first code is asked for), api/orangecheck.js | on, at once | The handle, and how they came: the referring site or a link's `utm_` tags. web/theme.js reads them on the visit's first page that has them and keeps them for that tab alone (sessionStorage, gone when it closes), so a page or two later, or in the studio, they are still known. They are sent only with a sign-in code asked for in that tab: the site's form (web/account.js, web/authorize.js) or the studio's (src/account/account.gd) |
| A first model published | api/share.js | on, at once | Its name, parts, whether listed, a link |
| A bug report or feedback | api/_feedback.js | on, at once | Its kind and first words, from `@handle`, "someone signed in, with no handle yet" or "someone signed out", never an address; a link to Feedback |
| Plans and payments | api/plans.js, Admission's signed webhook | on, at once | Bought, changed, cancelling, cancelled, a failed payment; renewals are not mailed |
| Server errors | api/_noted.js around each of the 12 functions | on, at once, 20 an hour | One row per 5xx; at most one mail an hour |
| Supabase near its quota | the cron, hourly: `admin_usage`, Supabase's health | on, at once, 80% of 8 GB database, 100 GB storage | At most once a day each; Supabase refusing the project too |
| Social: what came in | the cron reads social_items | on, daily digest | Replies, mentions, messages |
| Social: a scheduled post | the cron reads social_sends | on, at once | Went, failed, may be up, or due by hand |

The social desk's tables are only read, so its files are not changed.

**Not mailed from here**, each with why, as the page lists them:

- Vercel's use near its limit: the site holds no account token. Vercel's
  own spend alerts cover it.
- Resend's use near its limit: the site's key can only send.
- Supabase's egress: only the Management API tells it, and its tokens reach
  the whole organization. Supabase *refusing* the project is mailed.
- A release held or a deploy failed: the release tools do not tell the site
  yet.

## The rules (api/_notify.js)

- **Nobody waits for it.** Each raise, and each 5xx's row, runs after the
  answer has gone (api/_after.js). On Vercel the request's own `waitUntil`
  keeps the function alive for it. That is the one Vercel's Node runtime
  keeps at `globalThis[Symbol.for("@vercel/request-context")]`, read as
  `@vercel/functions` reads it, with no dependency added. Anywhere else the
  work runs on its own, and nothing waits on it past 1.5 s (`BOUND`). A
  first model is told apart by asking for one other model of its owner,
  never by a count. The page's Settings say which way this deployment runs
  it (`after`).
- **Each kind** on or off, and at once or in the daily digest (default
  08:00 UTC).
- **Batching.** A kind waits until none of it came for 2 minutes (`GAP`), and
  never more than 10 minutes after its first (`MOST_WAIT`). Ten items are
  listed; the rest are counted, with a link to them all.
- **The cap** (default 6 mails an hour, 1 to 60). Mails at once, digests and
  folds count; tests and address codes do not. Past it, the rest wait and go
  as one mail, the hour's last, in order of weight: errors, quota, plans,
  scheduled posts, feedback, sign-ups, first models, social. It is titled
  "And N more" after the hour's other mails, and "This hour: ..." when it
  is the hour's only one (a cap of 1).
- **Quiet hours** (off by default; 22:00 to 07:00 when on). Nothing goes. What
  came is held and goes as one mail when they end. The digest waits too.
- **The digest's day.** Each run works out which day's digest is due: today's
  once the owner's clock is past the digest's time, otherwise yesterday's.
  It sends that day's digest unless it was sent already or quiet hours are
  on. So a digest set inside quiet hours (23:00 in 22:00 to 07:00) goes as
  they end, once a day. A time the clock skips when it springs forward goes
  at the first moment after it, and a time that comes twice when it falls
  back goes once. The page says so: "sent at 07:00 when quiet hours end".
  A pool's first digest is the first day its time comes.
- **Old rows pruned** (a test's events past a week, the rest and the mails
  past 90 days, errors past two): at the
  first run of each UTC day, whenever it comes, by the day kept in
  `pruned_on` (supabase/owner_notify2.sql). Until that file is applied, they
  are pruned on every run in the hour from 03:00 UTC.
- **Pause all.** Nothing is mailed, nor kept to mail later.
- **A failed send** is tried again, 3 times at most, then marked Not sent.
  The Sent tab and the console's badge show it.
- **The alarm.** When the cron cannot reach the database (Supabase
  refusing), it mails the owner's account address once a day through
  Resend's idempotency key, with no settings to read. Only on brickworks.diy.

## Mail

- From `Brickworks <noreply@brickworks.diy>` with the site's sending key
  (`RESEND_API_KEY`), never a full-access key.
- Plain text, short lines, readable on a phone: what happened, a link to its
  place in /admin, and a one-click "turn this off" link.
- The off link is signed with the pool's own key (`off_key`). Opened, it is
  acted on at once, signed in or not, and its key is taken out of the
  address. The same link is `List-Unsubscribe`, so a mail app's own button
  works (RFC 8058).
- No account's address is put in a mail: the handle, or "Someone new".

## Settings

- **The address.** The owner's account address by default, shown in part
  (`ow•••@example.com`). Another is used only once the code mailed to it is
  typed (6 digits, 30 minutes, 5 tries). At most 5 codes are mailed an hour,
  counted from the Sent record as tests are. Back to my account's address
  drops a code still waiting.
- **Quiet hours**, the digest's time, the time zone, the cap. Each change is
  saved as it is made. When two are in flight at once, their answers may
  come back in either order, so the page shows the one written last, by the
  row's `version`.
- **Send a test**, of the whole or of one kind, at most 10 an hour.
- **Check now** runs the cron for this deployment now.
- **Pause all.**

## Pools: where each deployment's mail goes

The console's two pools, as everywhere in it:

- **The site's own** (brickworks.diy, not `?tests=1`): mails from the start,
  with each kind's default.
- **Any other deployment** (a preview): mails nobody until its settings are
  saved (Save, a kind's switch, Pause, the time and the cap), and only what
  happens there. Send a test, an address code or Check now there leave it
  off: the saved settings carry `saved: true`, and nothing else turns a
  pool on.
- **The checks' own** (`?tests=1`): only Resend's test inbox
  (`delivered+brickworks-tests@resend.dev`), and another address only at
  resend.dev. Never the owner.

The cron at `/api/plans/owner-notify` runs every five minutes. Run by
Vercel's cron it looks at brickworks.diy's pool. Run by hand (CRON_SECRET)
it looks only at the deployment it is asked on, so a preview's never
touches the site's.

## The record

Every mail sent, held or folded, and every change of a setting, is written
to the console's audit (actor `notifications`, kind `notification`).
Notifications › Sent lists them with each mail's words (Read it), the
mails in the last hour against the cap, and what waits: held, past the cap,
for the digest.

An account deleted at its person's request takes its events with it, and
the words of each mail that told of it; the mail stays in the record as
"About an account since deleted".

## The tables (supabase/owner_notify.sql, supabase/owner_notify2.sql)

Additive: four tables, row security on, no policies, nothing granted but to
the server's role. Nothing refers to `auth.users`. owner_notify2.sql adds
one nullable column, `pruned_on`; its dry run against the live project is in
bench/results/onfix-2026-11-18/owner_notify2.dry.txt.

- `owner_notify_settings`: one row a pool. The settings, the address and a
  waiting code (its hash), the off key, the last digest's day, the last
  prune's day (`pruned_on`), and a `version` every write compares and
  sets.
- `owner_notify_events`: one row an event, once by its key, through `new`,
  `held`, `capped`, `digest`, `sending`, `mailed`, `off`, `paused`, `failed`.
- `owner_notify_mails`: each mail, its words, to whom (in part) and what
  became of it.
- `owner_notify_errors`: each 5xx, by function and op.

Before the file is applied the section says so, a change answers 503, and
nothing else on the site notices.

## How it is proven

- `tests/test_owner_notify.py` runs `tests/fixtures/owner_notify/api_check.mjs`:
  each event raised by its real path (api/otp.js, api/share.js,
  api/_feedback.js, Admission's signed webhook, a 5xx through api/_noted.js,
  the cron's looks at Supabase's size and the desk's tables) against held
  tables and a stand-in Resend. It checks every rule above: a burst as one,
  10 minutes at most, the digest once a day, a digest inside quiet hours
  across both of 2027's clock changes in Europe/London, quiet hours, the cap
  and the fold (and its title at a cap of 1), pause, off, the one-click
  links, tests (and a preview's test leaving its pool off), another address
  and its 5 codes an hour, Resend failing 3 times, the erase, the cron on a
  preview, the alarm, the prune once a day, and that only resend.dev
  addresses are mailed. With the tables hung, every raising path answers in
  under 300 ms and its event lands once they answer. On a stand-in of
  Vercel's request context, the work is handed to its `waitUntil`. The orangecheck sign-up's raise is the
  same call and is read, not run: it needs orangecheck's own keys.
- `tests/fixtures/owner_notify/db_check.mjs` applies the SQL twice to a
  Postgres of its own: no role but the server's reaches a table, and each
  check refuses in its own name. It then applies owner_notify2.sql twice
  over the rows already there, which keeps them all.
- `tools/web/account_flow.mjs` (preview check `account`) starts on the
  landing page from another site's tagged link, goes into the studio, and
  checks that the code the studio asks for says how the visit came.
- `tools/web/ownernotify_flow.mjs` (preview check `ownernotify`) uses the
  page as the owner does, in the checks' pool, at 1280 and 430, light and
  dark. It refuses brickworks.diy.
