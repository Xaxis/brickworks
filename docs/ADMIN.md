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
(console1), part B (console2, 2026-11-13) and part C (console3,
2026-11-13), after which everything the owner manages is in it but real
money, which stays at Admission, and secrets' values, which stay at Vercel.

## What there is to manage

### Everything, and where it is managed

console3's brief: "nothing the owner manages lives outside /admin, except
real money (at Admission) and secrets' values (in Vercel)." Each thing, where
it was managed before part C, and where it is since. **Outside** marks the
three that stay outside, each with why.

| What | Before part C | Since part C |
|---|---|---|
| Reports of models, comments, photos, profiles; takedown requests and counter-notices | Gallery's Reported tab | Moderation › Queue: one list of every kind, oldest first, one set of acts, sifted by kind and searched |
| Reports of lists (lists1) | Gallery › Reported, with Take the list down | Moderation › Queue as the kind List, with Take the list down |
| Comments, reported or not | Gallery's Comments tab | Moderation › Comments |
| Accounts taken out | Gallery's Taken out tab | Moderation › Taken out, with Let back in |
| Models taken out by fingerprint (barred_models) | nowhere but SQL | Moderation › Taken out, with Let back (`unbar_model`) |
| In the gallery, Tested marks | Gallery | Gallery, unchanged |
| This week's pick | Gallery | Gallery, unchanged (the gallery shows it) |
| Set a challenge, end one | Gallery's Challenges tab | Challenges, with a preview as visitors will see it |
| The year's plan of themes | Gallery's Challenges tab | Challenges, with each month's preview and the day visitors are told |
| A challenge's entries, groups, rule failures, results | its public page, or SQL | Challenges › its panel (`#challenges/N`) |
| A notice on every page | nothing: it would have been a deploy | Switches › The notice: set, cleared, its history, each act audited |
| site_settings (the beta's switch, any other key) | Beta for the beta; SQL for the rest | Switches › Settings: every key by scope; the beta's flipped there or in Beta, one act |
| Deployment variables | Vercel's dashboard | Switches › Variables: each by name, whether here, which of Vercel's environments, what it switches, where it is changed. Its value: **outside**, at Vercel |
| The crons | Site (part B), read only; running one meant curl with CRON_SECRET | Site, with Run now for the four safe ones (`run_cron`, audited); never the beta's round, which mails testers |
| Rebrickable's last fetch, set counts | tools/fetch_data.sh on the box | Data |
| Set pictures' coverage | tools/set_pictures.py's output | Data |
| What the OMR's look found | library_arrivals, by SQL | Data › What the weekly look found |
| Database size, its biggest tables, storage by bucket | Supabase's dashboard | Data › Usage (`admin_usage`) |
| Supabase's egress | Supabase's dashboard | **Outside**: Supabase's Management API has no token narrower than the whole organization's, which may also delete projects; Data says so and links to the usage page |
| An account's data, at its person's request | SQL by hand | People › the account › Export their data (JSON, audited) |
| An account deleted at its person's request | only by its person, in Settings | People › the account › Delete, its address typed again (audited; the same code as Settings' own, api/_erase.js) |
| An account signed out everywhere | Supabase's dashboard | People › the account › Sign out everywhere (audited) |
| An account's lists, comments, photos, challenge entries | each public page | People › the account |
| Finding anything | each section's own search | Find, in the console's bar: people, models, lists, reports, acts |
| Beta, feedback, plans' reading, mail, connector, releases, backend health, the audit | the console (parts A and B) | unchanged |
| Prices, trials, comps, promotions, refunds, payouts | Admission | **Outside**: real money stays the owner's yes at Admission; Plans reads it and links to each |
| Secrets' values (keys, signing secrets, CRON_SECRET) | Vercel, Resend, Supabase | **Outside**: never on a page; Switches names them and says where each is changed |
| Brickworks' own social accounts: what came in, posts and replies, their results (socialdesk) | each network's own site | Social: the inbox, Write with the community's rules, Sent and scheduled, Accounts (docs/SOCIAL_DESK.md). Posting on Reddit is by hand on Reddit's own page until Reddit grants API access: **outside** for that one press |
| Claude on the owner's own Anthropic key: the key, the model, the effort, the month's cap (adminclaude) | console.anthropic.com | Claude › Settings, and the panel beside every section; on Social, Suggest, Suggest a reply, Improve and Overview, each landing as a draft (docs/ADMIN_CLAUDE.md). The key is made, paid for and deleted at console.anthropic.com: **outside** for that |
| Mail to the owner about what happens: sign-ups, first models, feedback, plans and payments, server errors, Supabase near its quota, the social desk (ownernotify) | nowhere: only reports and comments mailed, always | Notifications: each kind on or off, at once or in the daily digest, the address, quiet hours, the cap an hour, Send a test, Pause all; Sent, every mail sent, held or folded (docs/OWNER_NOTIFY.md). Vercel's and Resend's use and Supabase's egress: **outside**, each said why on the page |
| Telling the site's people something: in their Notifications, by email to those who chose news (announce) | nowhere | Announcements: Write with its preview and reach, Sent and scheduled with reach, reads and clicks, Banner, Settings (the day's most) (docs/ANNOUNCE.md) |
| The notice's end, and whether a person hid it (announce) | nowhere: it showed until cleared | Switches › The notice: Ends at a day and time; Announcements › Banner says it. Hidden per person, on every device once signed in |

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
| `site` | GET | The live release and those before, each cron's last runs, Supabase's health (part B); each cron's Run now, or why not (part C) | site_releases_list, cron_runs_of, canary_runs, Supabase's auth, rest and storage |
| `switches` | GET | Part C adds every variable by name (never a value or its length), the settings, the notice and its history | site_env_list, site_settings_list, site_notice, site_notices_list |
| `data` | GET | The catalogue and Rebrickable's tables (written beside the function at deploy), the parts library's index, the OMR's finds and runs, the database's and storage's size, why egress is not read (part C) | `_data_facts.json` (tools/web/data_facts.mjs), the parts store, library_arrivals_in, cron_runs_of, admin_usage |
| `find` | GET `&q=` | Accounts, people, models, lists, reports and acts holding the words (part C) | auth users, admin_find, admin_audit_list |
| `challenge_view` | GET `&challenge=` | One challenge whole: its entries by group, those failing its rules, its winners, what visitors see (part C) | challenge_list, challenge_admin_entries |
| `unbar_model` | POST `&id=` | A model taken out let back (part C) | barred_models |
| `notice_set`, `notice_clear` | POST | The notice on every page of this deployment but the studio, or cleared (part C) | site_notice_set, site_notice_clear |
| `run_cron` | POST `&job=` | A safe cron run now at this deployment's own address with CRON_SECRET, on the server (part C) | the cron's own path |
| `export` | POST `&account=` | Every row of the account as JSON: at most 1000 a table, the rest counted; no secret column (part C) | auth user, admin_export |
| `delete_account` | POST `&account=` `{confirm, reason}` | The account deleted at its person's request, its address typed again; never the owner's (part C) | api/_erase.js: Admission, orangecheck, photos, pictures, feedback's files, auth |
| `sign_out` | POST `&account=` | Every sign-in session ended and every Claude let go (part C) | admin_sign_out |
| `social` | GET | The social desk whole: each network (connected, by what, what is missing by name), the inbox newest first, every send with its results over time and visits (socialdesk) | social_accounts, social_items, social_sends, social_results, social_visits |
| `social_rules` | GET `&provider= &community=` | A community's rules from the network (a day at most), with the owner's notes | social_rules, the network |
| `social_connect`, `social_connected`, `social_disconnect` | POST `{provider}` | Connect by OAuth (a signed state), the code taken for tokens kept here alone; Disconnect revokes and forgets them | social_accounts, social_tokens, the network |
| `social_sync`, `social_mark` | POST | What came in and how sent posts do, read now; read or unread here (never at the network) | social_items, social_results |
| `social_draft`, `social_drop`, `social_notes` | POST | A draft kept (the site's links tagged) or thrown away; notes on a community's rules | social_sends, social_rules |
| `notify` | GET `&mail=` | Notifications whole: each kind and its setting, the address in part, quiet hours, the digest, the hour's mails against the cap, what waits, the mails and Sent's rows; or one mail's words (ownernotify) | owner_notify_settings, owner_notify_events, owner_notify_mails, the audit |
| `notify_set` | POST `{tz?, quiet?, digest_at?, cap?, paused?, events?}` | A change of the settings, compared and set by its version | owner_notify_settings |
| `notify_address`, `notify_confirm` | POST `{address}`, `{code}` | Another address: a code mailed there, mail going to it once typed; `{address: ""}` back to the account's own | owner_notify_settings, Resend |
| `notify_test`, `notify_flush` | POST `{event?}` | A test of the whole or one kind (10 an hour); the cron's run now for this deployment (Check now) | owner_notify_mails, Resend |
| `announce` | GET | The desk: this deployment's announcements (a test one's only on a preview or ?tests=1) with reach, seen, read, clicked and mail by state; today's count and the most; the plans; the notice (announce) | announce_list, announce_day, site_settings, Admission's plans, site_notice |
| `announce_preview` | GET `&words=` | A draft drawn by the page's own code (api/_notifications.js noticeGroups), its reach and mail count now | announce_count |
| `announce_keep`, `announce_drop` | POST `{id?, title, body, link, audience, email}` | A draft kept (a scheduled one edited: a draft again, its press forgotten) or thrown away | announce_keep, announce_drop |
| `announce_send` | POST `{id, hash, changed_at, at?}` | The owner's press on the exact words and version seen: now, or at a quarter-hour up to 60 days on; two presses make one send; at most the day's most | announce_press, announce_mail_take, Resend's batch |
| `announce_unschedule`, `announce_withdraw` | POST `{id}` | A scheduled one back to the drafts; a sent one out of every list (mail sent stays sent) | announce_unschedule, announce_withdraw |
| `announce_edit` | POST `{id, changed_at, title, body, link, hash?}` | A sent one's words looked at, then changed on that look for all it reached, marked edited | announce_edit |
| `announce_limit` | POST `{most}` | The day's most, 1 to 20 (two until set) | site_settings `announce_limit` |
| `social_send`, `social_unschedule`, `social_posted` | POST `{id, hash, at?}` | The owner's press of Send or Schedule on the exact words the hash names; back to the drafts (a schedule, a hand-off not posted, or a send unsure whether it is up); a post made by hand or found up, its address kept | social_sends, the network |
| `claude`, `claude_models` | GET | Claude's settings (the key only as `sk-ant-…` and its last four, the model, effort, cap, this month's spend); the models the kept key may use, from Anthropic's Models API (adminclaude) | admin_claude_settings, admin_claude_month, Anthropic |
| `claude_key`, `claude_check`, `claude_forget`, `claude_settings` | POST | A key checked with Anthropic and kept sealed, checked again, deleted; the model, effort and monthly cap | admin_claude_settings, Anthropic |
| `claude_chat` | POST `{ask, text, target, section, history}` | One ask, its answer streamed (SSE): a question, or on the desk suggest, reply, improve or overview; read-only tools, and drafts its only write; audited itself | admin_claude_hold, admin_claude_settle, admin_claude_drafts, the desk's social_sends, Anthropic |

Part B's four are reads: not kept in the audit, like the other GETs; part
C's reads are not either, and each of its POSTs is. `api/otp.js` takes one
more op that is not the owner's: `POST ?op=mail_event`, Resend's word on
each mail (below); `api/plans.js` one public read, `GET ?op=notice`, the
notice of the deployment it is asked on (a minute at the CDN), and
since ownernotify `POST ?op=notify_off`, a mail's one-click "turn this off"
(signed by the pool's own key, 404 otherwise) and `GET ?op=owner_notify`,
the notifications' cron.

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
- `api/_console_switches.js`, `_console_data.js`, `_console_people.js`,
  `_console_challenges.js`: part C's; `api/_erase.js` an account's
  deletion, shared by Settings' Delete account and the console's.

### The deployment's switches (process.env)

Read by the API; each set in Vercel per environment (tools/deploy.sh).
Since part C, Switches lists each by name with whether this deployment has
it and which of Vercel's environments do (`site_env`, written by the
release train's `tools/release/env_names.sh` from `vercel env ls`, names and
environments only), and flags one Vercel has that nothing reads.

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
| `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET` | The social desk's Reddit app (a web app): none can be made since Reddit closed new API apps on 2026-10-31, so posts go by hand (docs/SOCIAL_DESK.md) |
| `CLAUDE_KEY_SECRET` | Seals the owner's Anthropic key at rest (AES-256-GCM; 32 characters or more, `openssl rand -base64 48`). Production only, marked Sensitive, never in the box's .env; the key is opened only on brickworks.diy. Without it no key is kept and Claude › Settings says so; changed, the kept key no longer opens and is pasted again (docs/ADMIN_CLAUDE.md) |
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
| `/api/plans/owner-notify` | every 5 minutes | The owner's notifications: errors, Supabase's size and health (hourly) and the desk's tables looked at; then what waits mailed by the owner's rules (docs/OWNER_NOTIFY.md). Noted when it mailed, failed, ran by hand, or first after midnight; when the database refuses, one alarm a day without it |
| `/api/plans/announce-due` | 8, 23, 38 and 53 past each hour | Announcements whose time came, each only as pressed (words changed since: held, and why written on it); then their mail, a few batches a round. Noted when it sent, mailed, failed or ran by hand |
| `/api/plans/social-due` | every 15 minutes | The social desk: scheduled sends whose time came, each only as pressed; then each connected account's inbox and results. Noted when it sent, failed, ran by hand, or first after midnight |

### Outside services

Supabase (database, sign-in, storage), Vercel (hosting, deployments,
crons), Resend (mail), Admission (plans and payments, over Stripe),
orangecheck (sign-in), Rebrickable (sets, daily), the relay (the Claude
connector's sessions, in relay_tabs), Overlook (visit counts, never on
/admin), Reddit (the social desk, once an app exists; by hand until then).

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
| Overview | `#overview` | Needs you now (reports open, applications new, feedback unread, the borrowed sender, a failed or late cron, Supabase refusing, the OMR's finds, no challenge ahead, a notice showing); how things stand (accounts, sign-ups today and this week, signed in this week, testers of 100, models published, reports open, feedback unread, mail sent and failed, the live release and since when); the switches; the latest acts | Each card goes where it is done |
| People | `#people`, `#people/<account>` | Every account: address, handle, joined, last sign-in, plan, beta, models, connectors, taken out. Search; Everyone, Testers, With models, With a connector, Taken out | A row opens the account whole in a panel: Take out the account, Let back in, its models, its acts |
| Moderation | `#moderation/queue`, `comments`, `barred` | The one queue of every report, oldest first, by kind; Comments; Taken out, accounts and models | Take out, Take out the account, Take it down, Let the model back, Remove the comment, Take the photo or the picture out, Take the list down, Let it go, Let back in |
| Gallery | `#gallery/listed`, `pick`, `tested` | In the gallery, This week's pick, Tested | Take out, Make it the pick, End, Clear the mark |
| Challenges | `#challenges`, `#challenges/<id>` | The running one; every challenge by state; a challenge whole in a panel (entries by group, rule failures, winners); the set form and the year's plan, each with its preview | Set a challenge, Set the year, End it now |
| Beta | `#beta`, `#beta/applications`, `#beta/testers` | The beta's switch and its places left, billing's mode; the months of Pro (spots given and left, new, waitlist, still to give), the applications by state; the testers | Open or Off; Approve, Waitlist, Decline with a note; Grant pending months |
| Feedback | `#feedback`, `#feedback-N` | The inbox, by kind, where it stands and from whom | Where it stands, a note, an answer emailed |
| Social | `#social/inbox`, `write`, `sent`, `accounts` | Replies, mentions and messages; a post or a reply with the community's rules beside it, and drafts; what was sent and waits, with score, comments and visits over time; each network, connected or not, and what each still to come costs | Check now, Mark read, Reply…, Keep the draft, Review and send… (Send now, Schedule), Unschedule, Post it on Reddit…, Connect, Disconnect |
| Claude | `#claude`, and the panel beside every section | Settings: the key (only its last four), the model from the key's own list, the effort, the monthly cap and this month's spend. The panel: one conversation, streamed, with what each answer read and cost | Check and keep, Check key, Forget key, Keep; Ask, Stop, New chat; on Social: Suggest a post, Suggest a reply, Improve, Overview by Claude |
| Notifications | `#notifications/settings`, `sent` | What mails the owner: each kind, at once or the digest, its number where it has one; the address; quiet hours, the digest's time, the time zone, the cap; what is not mailed from here and why. Sent: every mail sent, held or folded and every change, with its words | Send a test (of all, or one kind), Check now, Use another address, Pause all |
| Plans and revenue | `#plans` | Billing's mode and keys; MRR, paying, comps, customers; the plans and what each includes; the customers and their plans; revenue by month; Admission's record | None: each part links to where it is changed at admission.sh |
| Mail | `#mail` | Who sends and whether Resend's word comes; sent, delivered, bounced, spam, failed in 7, 30 or 90 days; by day and kind; every mail with its address, subject and what became of it | Filter by kind and fate, search |
| Connector | `#connector`, `#connector/<account>` | Working now, tabs on, calls today; each account's Claudes, tabs, conversations, calls in 30 days, last call; the conversations live and lately | None: read only; an account's panel, from People too |
| Site | `#site` | The live release and since when; Supabase's auth, rest and storage; each cron's last runs; the releases before with their units | Run now, on the four safe crons |
| Data | `#data` | The set catalogue and its pictures, Rebrickable's tables, the parts library's index, what the OMR's look found, the database and storage by bucket, why egress is read at Supabase | None |
| Switches | `#switches` | The notice with its preview and history; the settings by scope; every deployment variable by name | Show the notice, Clear it; the beta's switch |
| Audit log | `#audit` | Every act: when, what, on what, the outcome, by whom | Filter by act, search |

The bar holds Find: one search over people, models, lists, reports and the
audit, its results grouped, each going where it is managed.

A reported list (a list of sets and models, or a wishlist) shows in
Moderation's queue, kind List, with its name and words as the owner typed them, whether it is
public, and its owner's address. **Take the list down** makes it private
for good: its page and its place in the directory go at once, its owner
still sees it on Your lists marked *taken down*, and it cannot be made
public again (`model_collections.taken_down_at`, docs/LISTS.md).

The old addresses land: `/beta-admin` redirects to `/admin#beta` (and
`?tests=1` with it), `#report-N` opens Moderation's queue with that report
marked, `#comment-N` Comments with that comment, `#feedback-N` that report;
part A's `#gallery/reported`, `#gallery/comments`, `#gallery/barred` and
`#gallery/challenges` are replaced by their new addresses as they open.

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
  conversation that called within 10 minutes in a tab heard within three.
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

## Part C: in the console now

Moderation, Challenges, Data and Switches; Run now in Site; People's
export, sign-out and delete; Find; the notice on every page. Every new op
is one of api/admin.js (still 12 functions), behind part A's gate: 401
signed out, 404 to anybody else, closed when the gate cannot tell. Reads are
not audited; every POST is, refusals too. The tables are additive
(`supabase/console3.sql`): `site_notices` and `site_env`, each reached only
through functions the server alone may call.

- **Moderation** (web/admin-moderation.js): the default report's reports,
  oldest first (api/admin.js asks `order=at.asc`), each by its kind
  (`reportKind`: model, comment, photo, profile, list, takedown,
  counter-notice). A kind is one entry of `KINDS`: its name, what its row
  says and the acts it has besides Let it go, which every report has; an
  unknown kind is drawn plainly, with Let it go. The acts are part A's
  (`unlist`, `bar`, `uncomment`, `remove_photo`, `remove_avatar`,
  `dismiss`), now in one place. Taken out lists the accounts and, new, the
  models barred by fingerprint, each let back with `unbar_model`.
- **Lists' reports** (lists1, merged into console3 before it was ready):
  `report()` in api/admin.js gives a reported list's name, words, state and
  owner as `report.list`, and `KINDS.list` in web/admin-moderation.js draws
  them and offers **Take the list down** (`list_down`) while the list is
  still shown. console3_flow reports a throwaway's list and takes it down.
  An account's export finds its tables by their key to auth.users, so lists
  come with it unasked.
- **Challenges** (web/admin-challenges.js, api/_console_challenges.js): the
  one running and every challenge, from the default report; a challenge's
  panel reads `challenge_admin_entries` (entries with their models' parts,
  grouped by hand and assistant, each that fails the rules marked) and
  says what visitors see now. Set, End and the year are the existing ops
  (`challenge`, `end_challenge`, `plan`); the forms preview the card as
  /challenge will show it, and each month of the plan with the day it is
  told (a month before it opens). This week's pick stays in Gallery.
- **Data** (api/_console_data.js): the catalogue and Rebrickable's tables as
  the deploy found them (`tools/web/data_facts.mjs` writes
  `_data_facts.json` beside the function: sets, with and without a
  picture, each table's fetch time), flagged when older than a week;
  the parts store's index; `library_arrivals` and the OMR's runs; and
  `admin_usage` (the database's size, its 15 biggest tables, each bucket's
  files and bytes from `storage.objects`). Egress is not read: Supabase's
  Management API has no read-only or project-only token, so the only key
  that reads it could delete the organization's projects. The section says
  so and links to the organization's usage page.
- **Switches** (api/_console_switches.js): the notice (below); every
  `site_settings` key by scope, the beta's flipped here with Beta's own act;
  every variable the code reads, by name, with whether this deployment has
  it (`process.env`, a yes or no), which of production and preview have it
  (`site_env`), what it switches and where it is changed, a link to Vercel
  for most. Never a value, never its length. One Vercel has that the code
  does not read is named so it can be taken out.
- **The notice** (web/notice.js, site.css `.site-notice`): set and cleared in
  Switches (`notice_set`, `notice_clear`, audited), one at a time a
  deployment (a preview's is its own, never brickworks.diy's), every one
  kept. Its English is needed, and German, French and Spanish shown only
  where the owner typed them: no machine translation. web/theme.js loads it
  on every page but an embed's card and the connector's consent page; it
  floats at the window's foot (above the beta's bar on a phone) so nothing
  in the page moves, is drawn at once from the last one heard and asked
  again (`/api/plans?op=notice`, a minute at the CDN), and its × hides that
  notice in that browser. info or warn, in the site's tokens.
- **Run now** (Site): `run_cron` calls the cron's own path at this
  deployment's own address (brickworks.diy, this project's previews,
  this deployment, a test's loopback; never PUBLIC_ORIGIN, which on a
  preview is live's) with CRON_SECRET on the server, waits up to four
  minutes, and the run is written down as by-hand. Only the front's choice,
  the OMR's look, the sweep and the canary, each safe to run twice; never
  the beta's daily round, which mails testers. One Run now of a cron at a
  time: a second asked while it runs (two tabs) is refused with 409 and
  never reaches the cron, held by the crons' own lock (`cron_begin`) under
  `run_now_<job>`, which lapses after five minutes if the function is cut
  off.
- **People, finished** (api/_console_people.js): an account's panel lists its
  lists, comments, photos and challenge entries (`admin_person_more`).
  Export downloads every row the account owns (`admin_export`: each table
  with a key to auth.users found in the catalogue, at most 1000 rows a
  table with the rest counted, a value over 8 KB named by its size, never a
  secret column, nor oauth_codes, oc_sessions or the audit). Who follows
  the account is counted (`followers`), never named: a follow is its
  follower's act. The hidden columns are never read, so a busy connector
  account exports in a fraction of a second (console3b.sql, after the
  review, 2026-11-15). The file holds the owner's own notes on the person
  (feedback, beta application and decision notes, signals), and the
  console says so. Sign out
  everywhere ends its sessions and its Claudes' grants (`admin_sign_out`);
  a token already given lasts its hour. Delete, at its person's request:
  the dialog says it is irreversible and what goes; the button wakes only
  once its address is typed again, and the server checks it too; never the
  owner's own; the same deletion as Settings' (api/_erase.js); the audit
  keeps its address, since the account is nowhere else afterwards.
- **Find** (the bar): from two characters, `admin_find` (people, models,
  lists, reports by their words) with the accounts' addresses and the
  audit's acts; the checks' own on `?tests=1`. Arrow keys and Escape.
- **Needs you now** gathers every queue and failure: reports, applications,
  feedback, the borrowed sender, a failed or late cron, Supabase refusing,
  the OMR's finds to look at, no challenge set ahead (or the last ending
  within a week), and a notice showing.

Proven by `tests/test_console3.py` (console3.sql against a real Postgres:
the notice, the variables, usage, sign-out, the export's caps and secrets,
Find, nothing reachable but by the server; and api/admin.js's new ops: the
gate, reads unaudited and writes audited, Run now's address and one at a
time, the typed deletion (untyped, mistyped, the owner's own, twice), an
export of an account with nothing and of the sets in its lists, a notice
of markup kept as typed, the switches holding no value) and, on a
deployment, `tools/web/console3_flow.mjs` (preview check `console3`, run
alone): the gate on every new op; a throwaway's report and its list's in
the one queue, the list taken down; Challenges' previews and panel; Data's
and Switches' real rows with no value in the page; Find; the front's
choice run now and its run written down, and refused when asked twice at
once; the notice (its words written as markup) set, seen signed out in
English and German as words, nothing run, and dismissed, then cleared
(never on brickworks.diy); an export downloaded, a throwaway signed out
everywhere and another deleted by its typed address and found in the
audit; each section at 390 and 1280, light and dark.

## Social (socialdesk): in the console now

The owner's own accounts on the networks, Reddit first (docs/SOCIAL_DESK.md
has the research, the sources and the choices for X, Facebook and
Instagram). Reddit closed new API apps on 2026-10-31, so the desk posts by
hand: Send opens Reddit's own page with the words, the owner presses Post
there and pastes the address back. The API path is built and proven against
a stand-in (`api/_social_mock.js`), and turns on with `REDDIT_CLIENT_ID` and
`REDDIT_CLIENT_SECRET` should Reddit ever grant access.

- **The press.** Nothing leaves without the owner's press of Send on the
  exact words the sheet shows: the press carries the server's hash of them,
  words changed since are refused (409), and the database refuses a row past
  a draft without a press (`social_sends_pressed`). A scheduled send goes at
  its time only if its words still match. Nothing votes, edits, deletes or
  marks read at a network.
- **Tokens** are in `social_tokens`, which only the server's role reads; never
  in an answer, a page, a log or an address. Disconnect revokes them.
- **Visits.** The site's links are tagged as a draft is kept
  (`utm_campaign=bw-<send>`); web/theme.js tells `social_visit` of a landing
  once, then takes the tags out of the address.
- **The ops** are api/admin.js's `social*` (still 12 functions) behind the
  gate: 401 signed out, 404 to anybody else; every POST audited. The cron
  and the visit are api/plans.js's `social_due` and `social_visit`.
- **The tables** are `supabase/social.sql` (additive; row security on, no
  policy, nothing granted but to the server; nothing refers to an account,
  so no export reaches them). Before it is applied the section says so and
  every write answers 503.

Proven by `tests/test_social.py` (the handlers against held tables and the
stand-in; social.sql in a Postgres of its own) and, on a deployment,
`tools/web/socialdesk_flow.mjs` (preview check `socialdesk`).

## Claude (adminclaude): in the console now

Claude on the owner's own Anthropic key, with their choice of model and
effort, beside every section (docs/ADMIN_CLAUDE.md has the whole of it).

- **The key** is pasted in Claude › Settings, checked with Anthropic's Models
  API, sealed (AES-256-GCM under `CLAUDE_KEY_SECRET`) and kept in
  `admin_claude_settings`, which only the server's role reads. No answer,
  page, log or audit row holds it: the page is told `sk-ant-…` and its last
  four. It is opened, and Anthropic asked with it, only on brickworks.diy:
  a preview or this box says "Claude uses your key only on brickworks.diy.
  Checks use ?tests=1." Forget key deletes it, and says to revoke it at
  console.anthropic.com.
- **The model** is chosen from the models the key may use (the live list,
  those with adaptive thinking and a price the cap can count),
  `claude-opus-5-5` until chosen; the effort with it.
- **The cap.** A monthly cap in dollars, kept by the server: before each call
  it holds the most the call may cost, every attempt a fallback may make
  included (`admin_claude_hold`, one at a time), and settles it from the
  answer's own usage, never above the hold. At the cap Claude stops and
  says what is spent and what an answer still running holds.
- **What it may do.** Read what the console reads (social: inbox, threads,
  drafts and sends with results, visits by tag, each community's rules;
  people: counts and growth, never an address; plans; mail health; site and
  backend health; feedback), and write one thing: a draft on the social
  desk, marked "by Claude". It never sends, posts, replies, schedules,
  deletes, mails, or changes a plan or a switch. What came in from Reddit
  and feedback reaches it as quoted, untrusted data.
- **The audit.** Each ask is one row (op `claude_chat`, kind `claude`): the
  model and the one that answered, effort, calls, tokens in and out, cache
  reads and writes, cost, the tools used, the drafts made, how it ended.
  Never the key, never the words.
- **The tables** are `supabase/admin_claude.sql` (additive; row security on,
  no policy, nothing granted but to the server; nothing refers to an
  account). Before it is applied, Claude says so and keeps nothing.

Proven by `tests/test_adminclaude.py` (the handlers against held tables and
the stand-in Anthropic, `api/_claude_mock.js`; admin_claude.sql in a
Postgres of its own) and, on a deployment, `tools/web/adminclaude_flow.mjs`
(preview check `adminclaude`).

## Notifications (ownernotify): in the console now

Mail to the owner about what happens on the site, set at **/admin ›
Notifications** (docs/OWNER_NOTIFY.md has the research, the sources and the
rules).

- **What mails.** A new sign-up (its handle and how they came), a first
  model published, a bug report or feedback, a plan bought, changed or
  cancelled or a payment failed, server errors past the owner's number in an
  hour, Supabase past the owner's share of its quota or refusing the
  project, the social desk's replies, mentions and messages, and a scheduled
  post that went, failed, may be up or is due by hand. Each on or off, at
  once or in the daily digest.
- **Never a flood.** One mail a kind for a burst (2 minutes quiet, 10 at
  most); at most the cap an hour, the rest in one "And N more"; quiet hours
  hold mail and send it as one when they end; Pause all.
- **Mail** through Resend from brickworks.diy with the site's sending key:
  plain, a link to the right section, and a one-click off link (and
  `List-Unsubscribe`, RFC 8058). A deployment without `RESEND_API_KEY`
  says so on the page.
- **Where.** The owner's account address, shown in part, or another once its
  code is typed. A preview mails nobody until its settings are saved; the
  checks' own (`?tests=1`) only Resend's test inbox.
- **The record.** Every mail sent, held or folded is in the audit (actor
  `notifications`) and under Notifications › Sent, with its words.
- **The ops** are api/admin.js's `notify*` (still 12 functions) behind the
  gate: 401 signed out, 404 to anybody else; every POST audited. The cron
  and the off link are api/plans.js's `owner_notify` and `notify_off`.
  Each 5xx is kept by api/_noted.js, around every function.
- **The tables** are `supabase/owner_notify.sql` (additive; row security on,
  no policy, nothing granted but to the server). Before it is applied the
  section says so and every change answers 503.

Proven by `tests/test_owner_notify.py` (each event by its real path against
held tables and a stand-in Resend; the SQL in a Postgres of its own) and,
on a deployment, `tools/web/ownernotify_flow.mjs` (preview check
`ownernotify`).

## Announcements (announce): in the console now

The owner tells the site's people something (docs/ANNOUNCE.md has the
research and the choices). /admin › Announcements has four tabs:

- **Write.** A title, plain words and an optional link (a page here, or
  https). The audience is one of: everyone; a plan; the beta's testers;
  people who signed up since a day; people who published; one person by
  handle. Beside it is the announcement as it will show on their
  Notifications page and in their account menu, drawn by the page's own
  code in a shadow root with the site's styles, and how many it reaches
  now. Review and send shows the same again, with Send now, or a day and a
  quarter-hour to Schedule.
- **Sent and scheduled.** Each announcement's reach (fixed as it went),
  seen, read, clicked and mail, and its state. A scheduled one can be
  changed (a draft again) or unscheduled. A sent one can be edited for
  everyone (look first, then change; it says edited) or withdrawn.
- **Banner.** The site notice: whether it shows, until when, and its words.
  It is set under Switches, with its end.
- **Settings.** The day's most, and today's count.

How it behaves:

- **The press.** Nothing goes without the owner's press on the exact words.
  The press carries the server's hash and the version seen, so words changed
  since are refused (409). A scheduled one goes at its time only if its
  words still match. Two presses make one send. An edit unschedules.
- **Delivery.** One row per announcement, its recipients fixed as it goes.
  Each person's Notifications reads it through `notification_rows`, so the
  avatar's count, the page and the menu show it, and opening it marks it
  read (`announcement_reads`, one row each, with any click).
- **Email.** Only to people who chose Brickworks news in Settings › Email
  before it went. Choosing news is off until turned on. Each mail has
  List-Unsubscribe and List-Unsubscribe-Post (RFC 8058) and a link in its
  words; both go to `/api/people?op=news_unsubscribe`. Resend's batch takes
  100 at a time, 1.1 s apart, each batch with its own idempotency key; a 429
  or 5xx is retried once, later.
- **The checks' pool.** On a preview, and with ?tests=1, every announcement
  is a test one. It reaches only the checks' accounts at resend.dev, is
  never mailed, and counts against that deployment's own most and list.
- **The gate.** The ops are api/admin.js's `announce*` (still 12
  functions): 401 signed out, 404 to anybody else, and every POST is
  audited. The cron is api/plans.js's `announce_due`; the notice's per-person
  hide is `notice_hide` and `notice_hidden`; news is api/people.js's `news`
  and `news_unsubscribe`.
- **The tables.** `supabase/announce.sql` is additive: five tables and the
  notice's `ends_at`. Row security is on, with no policy and no grant, even
  to the server's role, so every read and write goes through its functions.
  Before it is applied the section says so, its buttons are off, and
  Settings hides the news choice.

Proven by `tests/test_announce.py` (`tests/fixtures/announce/api_check.mjs`:
the handlers against announce.sql in a Postgres of its own, a mocked
Resend), `tools/announce_try.sql` on the project rolled back, and in a
browser by `tools/web/announce_flow.mjs` (preview check `announce`; locally
before the file with `--hold=announce`).
