# The owner's console

console1, 2026-11-12. The owner: "dont you think you should have built a
cohesive admin interface (for me) with a highly organized ui/ux where I can
manage ALL aspects of our system?!"

Before this the owner's tools were three pages that did not know of each
other: /admin (accounts, the gallery, reports, comments, the pick, the
challenges, the Tested marks, the accounts taken out, feedback, one long
page), /beta-admin (the beta's testers and its months of Pro), and the
feedback inbox bolted onto /admin's foot. Nothing said what needed the owner
now, nothing kept what the owner had done, and the beta's switch was a
Vercel variable and a redeploy.

The console is one page, `/admin`, with a section for each part of the
site that is the owner's to look after. This file is its inventory (what
there is to manage, and where each part lives), what it learned from the
consoles people already know, its design, and what is in it: part A
(console1) and part B (console2, 2026-11-13).

## What there is to manage

### api/admin.js, every op

Every op is behind one check: the token verified, then its address against
`MASTER_EMAIL`. Anybody else gets 404, the same answer as a route that does
not exist; signed out, 401. Every POST is kept in the audit (below) before
it answers.

| Op | Method | What it does | Its tables or calls |
|---|---|---|---|
| (none) | GET | The old report: accounts, sign-ins, connectors, the mail sender, the gallery, reports, comments, accounts taken out, Tested marks, the pick, the challenges, the year | auth users, relay_tabs, shared_models, reports, comments, barred_accounts, share_tests, gallery_pick, challenge_list |
| `overview` | GET | What needs the owner and how things stand | auth users, counts of shared_models and reports, feedback_inbox, beta_queue, beta_testers_list, admin_mail_counts, admin_audit_list, the switches |
| `people` | GET | Every account: joined, last sign-in, plan, beta state, models, connectors, taken out | auth users, people, shared_models, relay_tabs, barred_accounts, beta_testers_list |
| `person` | GET `&account=` | One account whole: profile, models, connectors, beta, feedback, plan, every act on it | auth user, people, shared_models, relay_tabs, barred_accounts, beta_member, beta_status, feedback_mine, Admission's entitlement (read), admin_audit_list |
| `audit` | GET `&before= &act= &kind= &target= &q=` | The audit log, newest first, 50 a page | admin_audit_list |
| `switches` | GET | The beta (where its mode comes from), billing's mode, the mail sender, which outside services this deployment has a key for | site_settings, the deployment's variables (named, never their values) |
| `unlist` | POST `&id=` | A model out of the gallery for good; its file fingerprinted so no copy lists | shared_models, barred_models, reports |
| `bar` | POST `&id=` or `&account=` | An account out whole: every model out, no profile, no public collection | barred_accounts, shared_models, barred_models |
| `unbar` | POST `&account=` | Let back in: it can list again | barred_accounts |
| `dismiss` | POST `&report=` | A report let go | reports |
| `list_down` | POST `&id=` | A reported list taken down: private for good, kept for its owner with its name and words, its reports settled | model_collections, reports |
| `untest` | POST `&id= &v=` | A version's Tested mark cleared | share_tests |
| `uncomment` | POST `&comment=` | A comment off every page for good | admin_remove_comment, reports |
| `remove_photo` | POST `&photo=` | A build's photo out, its files deleted | build_photos, storage |
| `remove_avatar` | POST `&handle=` | A profile's picture out, its file deleted | people, storage |
| `pick`, `unpick` | POST | This week's pick chosen for N days, or ended | gallery_choose_pick, gallery_end_pick |
| `challenge`, `end_challenge` | POST | A challenge set, or ended today | challenge_set, challenge_end |
| `plan` | POST | A year of monthly themes | challenge_plan |
| `beta_decide` | POST `&account=` | An application approved (the next spot, a month of Pro) or declined; its email | beta_decide, beta_mail, Admission's comp |
| `beta_waitlist` | POST `&account=` | A new application put on the waitlist, with a note; no spot, no email | beta_waitlist |
| `beta_grant` | POST | Every month still to give, given (billing on) | beta_comps_due, Admission's comp |
| `beta_switch` | POST `{mode}` | The beta open or off, here (below) | site_setting_set |
| `beta`, `beta_testers` | GET | The applications by state, the testers | beta_queue, beta_testers_list |
| `feedback`, `feedback_file` | GET | The inbox, a report's picture or model | feedback_inbox, storage |
| `feedback_triage`, `feedback_reply` | POST | Where a report stands and the owner's note; an answer emailed | feedback_triage, feedback_reply, Resend |
| `photo` | GET | A reported photo, for the owner's eyes | storage |
| `plans` | GET | Plans and revenue, read from Admission (part B) | Admission's `/v1/plans` (ADMISSION_KEY), admission_customers, `/v1/owner/metrics` and `/v1/owner/events` (ADMISSION_READ_TOKEN) |
| `mail` | GET `&days=` | Every mail by kind and day and what became of each (part B) | admin_mail: mail_events, beta_mail, feedback_replies |
| `connector` | GET `&account=` | Each account's Claudes, tabs, conversations and tool calls (part B) | relay_tabs, relay_picks, oauth_grants, relay_call_days |
| `site` | GET | The live release and those before, each cron's last runs, Supabase's health (part B) | site_releases_list, cron_runs_of, canary_runs, Supabase's auth, rest and storage |

Part B's four are reads: not kept in the audit, like the other GETs.
`api/otp.js` takes one more op that is not the owner's: `POST
?op=mail_event`, Resend's word on each mail (below).

### The owner's other ops

- `api/_beta.js`: `betaMode` (the one place the beta's mode is read),
  `betaSwitch`, the queue, decide, waitlist, grant, testers. Public:
  `/api/plans?op=beta`, `beta_spots`, `beta_join`, `beta_leave`, `beta_hub`.
- `api/_feedback.js`: inbox, file, triage, reply.
- `api/_featured.js`: the pick worked out and chosen.
- `api/_challenges.js`: the challenges and their pages.
- `api/_tested.js`: the Tested mark kept and cleared.
- `api/_trust.js`: reports and takedown requests; the owner's email of new
  reports, which links each to `/admin#report-N`.
- `api/_console_plans.js`, `_console_mail.js`, `_console_connector.js`,
  `_console_site.js`: part B's reads; `_console_mail.js` also Resend's
  webhook.

### The deployment's switches (process.env)

Read by the API; each set in Vercel per environment (tools/deploy.sh).

| Variable | What it switches |
|---|---|
| `MASTER_EMAIL` | Who the owner is |
| `BRICKWORKS_BETA` | The beta, `open` or off: now the fallback to the console's switch |
| `BRICKWORKS_BILLING` | Plans: `off`, `test` or `live` (an `adm_` key's mode). Shown in the console, never changed there |
| `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_PUBLISHABLE_KEY` | The database and sign-in |
| `RESEND_API_KEY`, `EMAIL_FROM`, `EMAIL_FROM_FALLBACK`, `BETA_REPLY_TO`, `REPORT_MAIL`, `COMMENT_MAIL` | Mail: the key, the sender, a borrowed sender while the domain was unverified, where answers go, the owner's report and comment mail |
| `ADMISSION_URL`, `ADMISSION_KEY`, `ADMISSION_WEBHOOK_SECRET` | Plans and payments (Admission) |
| `ADMISSION_READ_TOKEN` | An owner read token limited to Brickworks (Admission's Access), for Plans' revenue and Admission's record; none on production yet |
| `RESEND_WEBHOOK_SECRET` | The signing secret of Resend's webhook, for Mail (tools/web/resend_webhook.sh); a unit's preview has the checks' own |
| `OC_PROJECT_KEY`, `OC_SIGNING_SECRET`, `OC_CONNECT_KEY`, `OC_ME_ORIGIN`, `OC_ISSUER`, `OC_AUDIENCE` | Sign in with orangecheck |
| `CRON_SECRET` | The crons' own key |
| `VIEW_SECRET`, `PARTS_URL`, `PUBLIC_ORIGIN` | Shared views, the parts' host, the site's address |
| `VERCEL_ENV`, `VERCEL_URL`, `VERCEL_AUTOMATION_BYPASS_SECRET` | Vercel's own |

### The crons (tools/deploy.sh, kept in cron_runs)

The pick and the OMR watch kept their runs in `cron_runs` before; since
part B the sweep and the beta's round do too (`cronNoted`, api/_cron.js,
through `cron_noted`), and the canary's are its own `canary_runs`.

| Path | When (UTC) | What |
|---|---|---|
| `/api/share/sweep` | 04:17 daily | Files no published model owns, and photos' files whose photo is gone |
| `/api/otp/canary` | 04:47 daily | A sign-in code sent and read back |
| `/api/share/feature` | 00:07 daily | The gallery's front: this week's pick, today's featured model and set |
| `/api/share/omr` | 05:37 Mondays | What LDraw's Official Model Repository has that the library has not |
| `/api/plans/beta-daily` | 05:07 daily | The beta's daily round, and feedback's sweep with it |

### Outside services

Supabase (database, sign-in, storage), Vercel (hosting, deployments,
crons), Resend (mail), Admission (plans and payments, over Stripe),
orangecheck (sign-in), Rebrickable (sets, daily), the relay (the Claude
connector's sessions, in relay_tabs), Overlook (visit counts, never on
/admin).

## What the best consoles do

- **Stripe's dashboard**: a home of what needs you (disputes, failed
  payments) over the numbers that matter today; a list per object
  (payments, customers) with search, filters as chips and sortable columns;
  a row opens the object whole on its own page, every event on it below;
  the developer log of every request. Test mode a switch, its data apart.
- **Vercel's dashboard**: a project's overview (the live deployment, since
  when, its commit), then tabs; the deployment list filterable by state;
  every change to settings in an audit log (Teams), each entry who, what,
  when.
- **Supabase Studio**: a left rail of sections, each a table browser:
  search, filter, sort, and a side panel to read or edit one row without
  leaving the list.
- **Shopify admin**: a left rail with counts of what waits (orders to
  fulfil); lists with saved views as tabs (All, Unfulfilled, Unpaid) and a
  search over them; bulk acts; a timeline on every order and customer of
  what was done to it and by whom.
- **Discourse admin**: a dashboard of what needs moderating (the review
  queue with its count in the nav), users with filters (new, suspended,
  staff), a user's page with everything about them and the acts on them
  (suspend, silence), and the staff action log of every act, filterable by
  act and by who.

What the console takes from them: a left list of sections with counts of
what waits; an Overview that leads with what needs the owner, then how
things stand; each section a table with search, filters as a segmented
control, sortable columns and a detail panel; the acts beside what they
act on; an address for every view; the checks' data apart (Stripe's test
mode is the console's `?tests=1`); and an audit log of every act, refusals
too, filterable by act, kept for good.

## The design

One page, `/admin` (web/admin.html), bare as the app's own pages are: its
own bar (the mark, the owner, Refresh), a left list of sections from 900
px (a row of pills on a phone), and the section beside it.

| Section | Address | What it holds | Acts |
|---|---|---|---|
| Overview | `#overview` | Needs you now (reports open, applications new, feedback unread, the borrowed sender); how things stand (accounts, sign-ups today and this week, signed in this week, testers of 100, models published, reports open, feedback unread, mail sent and failed, the live release and since when); the switches; the latest acts | Each card goes where it is done |
| People | `#people`, `#people/<account>` | Every account: address, handle, joined, last sign-in, plan, beta, models, connectors, taken out. Search; Everyone, Testers, With models, With a connector, Taken out | A row opens the account whole in a panel: Take out the account, Let back in, its models, its acts |
| Gallery | `#gallery/reported`, `comments`, `listed`, `pick`, `challenges`, `tested`, `barred` | Reported, Comments, In the gallery, This week's pick, Challenges, Tested, Taken out | Take out, Take out the account, Remove the comment, Take the photo or the picture out, Take the list down, Let it go, Make it the pick, End, Set a challenge, Set the year, End it now, Clear the mark, Let back in |
| Beta | `#beta`, `#beta/applications`, `#beta/testers` | The beta's switch and its places left, billing's mode; the months of Pro (spots given and left, new, waitlist, still to give), the applications by state; the testers | Open or Off; Approve, Waitlist, Decline with a note; Grant pending months |
| Feedback | `#feedback`, `#feedback-N` | The inbox, by kind, where it stands and from whom | Where it stands, a note, an answer emailed |
| Plans and revenue | `#plans` | Billing's mode and keys; MRR, paying, comps, customers; the plans and what each includes; the customers and their plans; revenue by month; Admission's record | None: each part links to where it is changed at admission.sh |
| Mail | `#mail` | Who sends and whether Resend's word comes; sent, delivered, bounced, spam, failed in 7, 30 or 90 days; by day and kind; every mail with its address, subject and what became of it | Filter by kind and fate, search |
| Connector | `#connector`, `#connector/<account>` | Working now, tabs on, calls today; each account's Claudes, tabs, conversations, calls in 30 days, last call; the conversations live and lately | None: read only; an account's panel, from People too |
| Site | `#site` | The live release and since when; Supabase's auth, rest and storage; each cron's last runs; the releases before with their units | None |
| Audit log | `#audit` | Every act: when, what, on what, the outcome, by whom | Filter by act, search |

A reported list (a list of sets and models, or a wishlist) shows in
Reported with its name and words as the owner typed them, whether it is
public, and its owner's address. **Take the list down** makes it private
for good: its page and its place in the directory go at once, its owner
still sees it on Your lists marked *taken down*, and it cannot be made
public again (`model_collections.taken_down_at`, docs/LISTS.md).

The old addresses land: `/beta-admin` redirects to `/admin#beta` (and
`?tests=1` with it), `#report-N` opens Reported with that report marked,
`#comment-N` Comments with that comment, `#feedback-N` that report.

Every word a person typed is put on the page as text, never as markup. The
page follows docs/DESIGN_SYSTEM.md: the site's controls, tables
(`.table`), tabs, segmented controls, pills, badges and stats, the site's
light and dark, and a phone's width.

### The beta's switch

`betaMode(request)` (api/_beta.js) is still the one place the beta's mode is
read. It asks `site_settings` for `beta` in this deployment's scope first:
`live` for brickworks.diy and www, else the deployment's own host. A value
there wins; with none, `BRICKWORKS_BETA` decides, as before. The console's
Open and Off set it (`?op=beta_switch`, kept in the audit), and only for
the deployment the console is on: flipped on a preview, brickworks.diy
does not follow. Read at most every 15 seconds per instance
(api/_settings.js), so a flip is seen everywhere within that, plus
`beta_spots`'s 60 seconds at the CDN.

### The audit

`admin_audit` (supabase/console.sql): one row an act, written before the
act's answer goes back, whatever came of it. Its columns: `at`, `actor`
(the owner's address), `actor_account`, `op`, `target_kind` and `target`
(a model, an account, a report, a comment, a photo, a profile, a pick, a
challenge, a setting, feedback), `detail` (what was asked and what was
answered, clipped), `status`, `said` (a refusal's words), `test` (the
checks' own, on `?tests=1` or a test account's pool) and `scope` (the
deployment). Nobody but the server reaches it; `admin_audit_list` pages it
newest first and filters it.

### How the owner gets there

The account menu (the avatar's menu on a laptop, Menu on a phone) has
Admin at its foot above Sign out, with a gauge icon, for the owner alone
(bugbar, 2026-11-13: "for me and me only there should be a link to the
admin page from the top nav dropdown menu"). The menu draws it from
`GET /api/people?op=feed_count`, the header's "who you are" on every page,
which adds `admin: true` when `isMaster(claims)` (api/_auth.js: the
verified address is `MASTER_EMAIL`) and has no `admin` key at all for
anybody else, never `false`. It is kept with the rest of "who you are" in
`localStorage["brickworks.me"]`, so the next page draws it at once, and
forgotten at Sign out. Nothing else tells anyone the console exists:
`op=me` is unchanged, and api/admin.js still answers anybody else 404 and
signed out 401. Proven by `tests/test_menu_admin.py` (the real handler:
the owner told; another account, an unverified claim to the owner's
address and nobody signed in without the key) and `console_flow.mjs`
section 11 (both menus, as the owner and as a throwaway, and signed out).

## Part A: in the console now

Overview, People, Gallery, Beta (with its switch), Feedback, the Audit log;
billing's mode shown, never changed (real money stays the owner's yes,
outside the console).

Proven by `tests/test_console.py` (the gate, every read and every act kept,
console.sql against a real Postgres) and, on a deployment,
`tools/web/console_flow.mjs` (preview check `console`, run alone): the
owner's session minted, never signed in; throwaways at resend.dev acted on
in every section on the checks' own (`?tests=1`); the switch turned off on
that deployment alone and open again; every act found in the audit; every
section at 390 and 1280, light and dark.

## Part B: in the console now

Plans and revenue, Mail, Connector and Site, each a GET op of api/admin.js
(Vercel's 12 functions are all used; nothing is a function of its own),
behind part A's gate, read only. The tables are additive
(`supabase/console2.sql`): `mail_events`, `site_releases`,
`relay_call_days`, a `calls` column on `relay_picks`, and functions only the
server may call.

- **Plans and revenue** (api/_console_plans.js): billing off, as on
  production, the section says so and nothing is asked of Admission. On,
  the plans and what each includes come from `/v1/plans` with the product
  key, and the customers and comps from Admission's own answers kept in
  `admission_snapshots` (one database read, no call an account). Revenue by
  month, MRR and Admission's record need an owner read token limited to
  Brickworks (`ADMISSION_READ_TOKEN`, ADR-0014: `/v1/owner/metrics`,
  `/v1/owner/events`), which production does not have; the section says
  where it is made (admission.sh/access). Prices, trials, comps and
  promotions stay the owner's at Admission, linked from each part.
- **Mail** (api/_console_mail.js): production's `RESEND_API_KEY` may only
  send (`GET /emails` answers 401 restricted_api_key, 2026-11-12), and a
  key that can read is the full-access key of the Resend team, which nine
  other products share: never put in a deployment. So Resend tells us: its
  webhook POSTs each event (sent, delivered, delayed, bounced, complained,
  failed, suppressed) to `/api/otp?op=mail_event`, an op of an existing
  file, verified as Svix signs (HMAC-SHA256 of id, timestamp and body with
  `RESEND_WEBHOOK_SECRET`, five minutes either way) and kept once by its
  event id in `mail_events`, a year. The team's other products' mail reaches
  the same webhook and is let go unread: only mail from brickworks.diy is
  kept. Each send carries its kind as a Resend tag (sign_in_code, beta,
  feedback_answer, digest, report_digest, canary_alarm, sign_in_notice);
  older mail is told by its subject. Shown beside `beta_mail` and
  `feedback_replies`, one row a mail. `tools/web/resend_webhook.sh` sets the
  webhook up on that team, with its key given in the shell for that run
  alone, once a release with the op is live; a unit's preview has the
  checks' own public secret, which keeps only mail to resend.dev.
- **Connector** (api/_console_connector.js): every account that let a
  Claude in (`oauth_grants`) or switched a tab on (`relay_tabs`), with its
  conversations (`relay_picks`: which tab each works in, its last call and
  tool, its count of calls) and its calls by day (`relay_call_days`, counted
  by `relay_call_note` from api/mcp.js's noteCall). Working now is a
  conversation that called within 30 minutes in a tab heard within three.
  `#connector/<account>` is an account's panel, linked from People's.
  Nothing here ends or changes a session.
- **Site** (api/_console_site.js): the release train writes each release
  as brickworks.diy serves it (`tools/release/release_live.sh` from ship.sh:
  the tag, the commit, its title and units into `site_releases`), so no
  Vercel token is in production's env; this deployment's commit comes from
  `/version.json`. Each cron's last five runs and whether it failed or is
  late (no run in half again its period); the canary's last answer with
  each check that failed. Supabase's auth, rest and storage asked at most
  every 15 seconds an instance: a 402 or a restriction shows under the
  Overview's Needs you now with where it is lifted (Supabase's dashboard,
  the organization's Billing), and a sign-in Supabase refuses answers 503
  with the same words. The Overview also shows the live release, a failed
  or late cron and the week's bounces and complaints.

Proven by `tests/test_console2.py` (console2.sql and the four ops and the
webhook against a real Postgres: the gate, Resend's signature, each read)
and, on a deployment, `tools/web/console2_flow.mjs` (preview check
`console2`): the gate; Resend played with the deployment's secret, a
delivered and a bounced mail shown with why; a throwaway's tab, Claude and
two calls in Connector and its panel; Site's live release, crons and
health; Plans as billing is there; every section at 390 and 1280, light and
dark.

Still to do: the webhook made at Resend and its secret in production's env
(`tools/web/resend_webhook.sh`, after the release), and an
`ADMISSION_READ_TOKEN` for production's revenue once billing is on.
