# Analytics: how the site and the studio are used

The owner, 2026-11-18: "detailed analytics across the site so I can track
and see how users are using every aspect of the site and the studio".
/admin › Analytics answers it from Brickworks' own counts (insights): visits
and where they came from, the way from a visit to a published model,
retention by the week people joined, every tool, panel and control of the
studio ranked (and what nobody uses), where visits stop, Claude's tool
calls, real load and frame times by device, and errors. Nothing a person
made or typed is ever counted, and nobody who said no.

## What the best tools show (research, 2026-11-18)

Each checked at its own documentation on the day.

| | Funnels | Retention by cohort | Paths | Feature use | Web vitals |
|---|---|---|---|---|---|
| Plausible | conversion and drop-off per step, by source, page or device ([funnel-analysis](https://plausible.io/docs/funnel-analysis)) | not offered: "not designed for user-level retention or behavioral cohorts" ([for-saas](https://plausible.io/for-saas), seen in a search, not fetched) | User Journeys, Business plan ([user-journeys](https://plausible.io/docs/user-journeys)) | custom-event goals ([custom-event-goals](https://plausible.io/docs/custom-event-goals)) | an added script sends LCP, INP and CLS as ratings from about 1 load in 10; the share of good, needs-work and poor per page, no times ([core-web-vitals](https://plausible.io/docs/core-web-vitals)) |
| PostHog | step conversion and drop-off ([funnels](https://posthog.com/docs/product-analytics/funnels)) | a starting event, then who returns in later periods ([retention](https://posthog.com/docs/product-analytics/retention)) | journeys and where people get stuck ([paths](https://posthog.com/docs/product-analytics/paths)) | Trends, features side by side ([trends](https://posthog.com/docs/product-analytics/trends/overview)) | FCP, LCP, INP, CLS captured as `$web_vitals` ([web-vitals](https://posthog.com/docs/web-analytics/web-vitals)) |
| Mixpanel | conversion within a window, and drop-off ([funnels](https://docs.mixpanel.com/docs/reports/funnels/funnels-overview)) | ([retention](https://docs.mixpanel.com/docs/reports/retention)) | Flows, before or after an event ([flows](https://docs.mixpanel.com/docs/reports/flows)) | Insights: counts, people, breakdowns ([insights](https://docs.mixpanel.com/docs/reports/insights)) | none of its own found |
| Amplitude | ordered steps, conversion, drop-off ([funnel](https://amplitude.com/docs/analytics/charts/funnel-analysis/funnel-analysis-build)) | returns after a starting event ([retention](https://amplitude.com/docs/analytics/charts/retention-analysis/retention-analysis-build)) | Journeys ([journeys](https://amplitude.com/docs/analytics/charts/journeys)) | Event Segmentation ([segmentation](https://amplitude.com/docs/analytics/charts/event-segmentation)) | INP, FCP, LCP, CLS with `autocapture.webVitals` (a release note: [web-vitals](https://amplitude.com/releases/web-vitals-metrics-collection)) |

"Good" at the 75th percentile is LCP 2.5 s or less, INP 200 ms or less and
CLS 0.1 or less ([web.dev/articles/vitals](https://web.dev/articles/vitals)).
Global Privacy Control is `navigator.globalPrivacyControl` and the
`Sec-GPC` header ([w3.org/TR/gpc](https://www.w3.org/TR/gpc/), a working
draft of 2026-09-24). France's CNIL lets audience measurement go without
consent only under conditions it lists ([sheet n°16](https://www.cnil.fr/en/sheet-ndeg16-use-analytics-your-websites-and-applications),
which answered 503 on the day: its conditions were read only in others'
summaries, so nothing here leans on that exemption).

### What the site already loads: Overlook

Every site page but `/m/`, `/u/`, `/c/`, `/oauth/` and `/admin` loads
`/ov/s.js`, the owner's own Overlook visit counter (a copy kept by
`tools/web/overlook_copy.sh`, sending to overlook.technology). Overlook
shows a site's visitors, pages, sources, places, devices, its own events
and web vitals, cookieless, on Overlook's own pages
(`~/Projects/overlook.technology/docs/analytics.md`). It cannot answer this
ask: it never sees the studio, a model's, a profile's or a challenge's page,
it knows no accounts (so no sign-up funnel and no retention), and its API
(`/api/v1`: projects, health, deploys, alerts, activity, costs) has no read
of analytics at all, so the console cannot show its numbers. It counts
browsers sending GPC (its site setting, off by default since 2026-10-17).

### The choice: both

Overlook stays, unchanged, for the site's audience at a glance on Overlook.
Brickworks counts the product itself, first-party, in its own Supabase: one
product's questions answered better than a general tool can, because the
counter knows what the studio's panels, tools and runs are called, which
account is whose (as a hash), and the social desk's posts. Against the four:

- **Funnels** of accounts (signed up, put down a part, saved, published)
  and of visits (visited, opened the studio, a part, a save, signed in),
  each step with its share of the first and of the step before.
- **Retention** by the week accounts signed up, 12 weeks on, from the
  studio, the site and Claude's calls together (Plausible has none).
- **Paths** as where visits stopped: each visit's last act, ranked. A full
  path explorer is not built; the last act is what the ask named.
- **Feature use**: every tool (picked, and for how long), panel, dialog,
  control and palette command of the studio, by times and people, and the
  ones never used in the range, which no general tool can know.
- **Speed**: the site's LCP, INP, CLS, FCP and TTFB as times (p50, p75,
  p95) with the good/poor rating at p75, and the studio's own start marks
  and frame times, by device and browser.
- **Claude**: each connector tool's calls, people, failures and time.

## What is counted

`web/tally.js`, loaded after the first screen (web/theme.js, once the page
has loaded and gone idle; the studio's shell, 2 s after it is up), sends a
beacon every 15 s while something happened, and when the tab is hidden or
left, to `POST /api/plans?op=tally`. Counts are added up in the page, so a
beacon is one request with at most 80 rows.

| Kind | Where | Name | How often |
|---|---|---|---|
| view | site | the page's template: `/m/:id`, `/u/:handle`, `/c/:id`, `/library/set/:n`, else its canonical path, else `/other` | each page |
| act | site | an API write: `people.like`, `people.comment`, `people.follow`, `people.challenge_entry`, `account.signed_in`…; failed when it answered 400 or more | each |
| load | site | `site_lcp`, `site_inp`, `site_cls` (×1000), `site_fcp`, `site_ttfb` | 1 visit in 4 |
| load | studio | each start mark (`studio_compiled`… `studio_ui`) and `studio_ttfb` | each start |
| milestone | studio | `studio`, `first_part`, `first_save`: ms after the studio came up | once a visit |
| tool | studio | the tool picked (`select`, `paint`…), with the time it stayed picked | each pick |
| panel | studio | a panel or dialog opened (`parts`, `assistant`, `saved_models`, `simulate`, `render`…) | each opening |
| press | studio | a named control pressed (the app's own control names) | each press |
| command | studio | a palette command run; a part searched for there is `find_part` | each |
| part, save | studio | `placed`, `model`: counts only | each |
| run | studio | `simulate`, `render_<kind>`, `booklet`, `together`: how long, and whether it went | each run |
| frames | studio | `frame_ms`, `frame_p95_ms` over 3 s | a minute in, then every 5 minutes, 8 at most |
| error | both | `js:<file>:<line>`, `js:rejection`, `gd:<script>:<line>`: a place, never the words | 10 places a page at most |
| call | mcp | a connector tool's name, whether it went, how long (api/mcp.js, server side) | each call |

With each visit go its first page, where it came from (the channel, the
referrer's host or `utm_source`, `utm_medium`, `utm_campaign`; the social
desk's `bw-<post>` joins its post), the kind of device, browser and system,
the page's language, its seconds and its last act. When signed in, the
beacon carries the page's own sign-in token (the site's, or the one the
studio's own requests to /api/ carry), and the server takes the account
only from that token once it checks out (`verify`, as every signed-in op);
a beacon's own word for whose it is counts for nothing. The server keeps
the account only as an HMAC of the id under `VIEW_SECRET` with a prefix of
its own (24 hex characters), and the token is let go: rows cannot be joined
to anything outside the database, and the console makes the same hash to
join them to sign-ups. A visit's account is set once, never changed. The
studio's controls shown (their names) are kept once each, so a control
nobody presses shows as never used.

**Only names the code has.** A beacon is the browser's word, and anybody
can send one, so the server keeps a name only when the code that counts it
names it: the site's pages and its API ops, the studio's tools, panels,
palette commands, runs and named controls, a script of the site's or the
studio's for an error, and the connector's tools for a call.
`tools/insights_names.py` reads them from the code into
`api/_insights_names.js` (`--check` says when it is behind; a test runs
it). A name made up is dropped before it reaches the database, so it is
never a row, a line in the console, or a share of the day's cap. Each kind
has its most a beacon (20 views, 200 presses, 60 commands…): one beacon
cannot make a press a million.

**Never pressed** leaves out a control whose tool was picked or whose
palette command ran. Keys, shortcuts and Claude's own presses are not seen,
so a control used only that way shows as never pressed.

**Not counted yet: items chosen from the studio's own menus.** The page sees
the menu bar's presses and the palette's commands, but an item chosen in a
Godot menu never reaches the web bridge; counting those needs a line in the
app's menu handler (a Godot change, left for its own unit).

## Privacy

- **Never kept:** a model or anything in it, a part's number, words typed,
  a file's name, an email address, an IP address, a page's id, the
  referrer's path. Every name is checked twice: in the page (`nameOf`:
  a-z 0-9 `_:/#.-`, 60 long, nothing with an `@`) and again in the database
  (`insights_take` refuses any other name).
- **A visit** is a random id in the tab's session storage, gone when the
  tab closes, and new after 30 minutes away.
- **Asked first** where the law wants a yes (the EU, the EEA with its
  outermost regions, the UK, Switzerland): the browser's time zone says so
  in the page, and Vercel's country header on the server, which drops a
  beacon from there without the yes; the header is read and let go. A clock
  that names no place (UTC, `Etc/*`, GMT) asks first, as Europe's does. The
  ask is a card at the window's foot on a site page (never the studio),
  with Yes, No and Ask me later. It comes first in the Tab order, Escape
  closes it unanswered, and focus goes back where it was or to the page's
  next stop.
- **Never counted:** a browser sending Do Not Track or GPC (checked in the
  page and again on the server's headers), anyone who said No or turned it
  off in Settings › Privacy (kept in this browser), and a browser a program
  drives (`navigator.webdriver`) unless a check asked to be counted. A no
  costs no request: theme.js and the studio's shell check all four before
  fetching tally.js or counting.js (`window.brickworksCountingNo`).
- **The social desk's `social_visit`** follows the same choice: never sent
  under Do Not Track, GPC or a No; where a yes comes first, only once it is
  given on that landing page. A check's driven browser still sends it.
- **A connector tool call** is counted by the server (its tool, whether it
  went, how long), never with an account: a person's choice not to be
  counted lives in their browser, and a call does not come from there.
- **Kept 30 days** as sent; each day's totals after (`insights_days`), with
  the day an account first put down a part and saved, and which days it was
  active, by its hash. Deleting an account deletes its rows there and then
  (`api/_erase.js`, `insights_forget_account`); the daily run deletes any a
  deleted account left, whatever else is kept, unless that day's listing of
  accounts failed (none, or much shorter than the last: `insights_gone`).
- **Said plainly** at `/counting` (de, fr, es), linked from the privacy
  page's visit section and from Settings' choice.
- **The checks' own** are kept apart (`test`), read with `?tests=1`, as the
  console's other sections do: anything not sent to brickworks.diy or
  www.brickworks.diy (every Vercel deployment is a production one, so a
  preview is told by its host), anything any deployment but production
  sent, a test account's (`@resend.dev`, the checks' own), and a beacon a
  check marked. The same holds for a tool call. Every row kept before
  `supabase/analytics2.sql` is marked a check's: none came from
  brickworks.diy.

## Cost

Each beacon is one call of `api/plans` and one `insights_take`, whose
answer is a number; a signed-in one's token is checked as every signed-in
op's is (`verify`: the keys, cached, and one read of the session). Measured on a preview (tools/web/insights_flow.mjs,
2026-11-18): a site page's beacon is 320–490 bytes with 1–5 rows; the
studio's first is 1.9 kB with 92 (its view, its start's timings and the
controls it shows, which are kept once a name, not once a visit), later
ones a few hundred bytes. On a studio of 3,000 controls the largest is
2.0 kB, and no turn of the counter takes over 6 ms
(tests/fixtures/insights/frame_check.mjs). At 500 visits a day, a third of
them in the studio:

| | A day | Why |
|---|---|---|
| Beacons | 3,000–20,000 | a site visit sends 2 or 3; a studio hour at most 240, only while something happened |
| Rows kept | about 15,000 | a site visit 5–8, a studio visit about 30 (counts are added up per beacon) |
| Database size | about 70 MB at 30 days, then about 0.4 MB a day of totals | 450,000 rows of about 150 bytes |
| Supabase egress | about 2–6 MB, and about 0.2 MB a console read | the beacons' answers are a few bytes each; the read answers totals only |

Caps hold it whatever comes (`insights_caps`): 80 rows a beacon, each kind
at its most a beacon, 1,500 rows a visit, 400 control names a beacon (each
new name a row of the day's), and 200,000 rows a day. Past 150,000 a new
signed-out visit is kept one in 8, by its id, and counted at a weight of 8,
so a busy day goes on being counted and the console says how many were
sampled; past 200,000 no new visit is kept, and the console says how many
were turned away. A tool call has a budget of its own (50,000 a day), so a
flood of beacons cannot blind the connector's counts. One address may send
40 beacons at once and one more each 4 s after, and start 60 visits an hour
(the route, in memory: it slows a script, not a person).

The console's read sums the totals and today's raw rows in the database and
sends back only the sums, each list its top 25 or 50 by count (`names`
says how many there were); no raw row ever leaves it. However the beacons
were made up, the read is at most 113 kB (every list full and 401 days:
days 38 kB, studio use 46 kB, speed 12 kB, sources 10 kB, never pressed
8 kB; db_attacks case F, 2026-11-18). Vercel's cron rolls up each day that
is over at 03:27 UTC (`/api/plans/tally-daily`), one day a call so a
backlog never times out the next, and forgets what is past 30 days; it rolls
a day once, and a read never writes.

## The console: /admin › Analytics

Owner only (401 signed out, 404 to anybody else, as every op).
`web/admin-analytics.js` makes the section; `GET /api/admin?op=analytics`
reads it (`from`, `to` as days UTC, at most 400 apart; `plan`: everyone but
the owner unless asked, `all`, `free`, `tester`, `pro`, `owner`, `none`;
`device`; `lang`; `signed`).

- **Overview:** visitors, visits, sign-ups, active builders, published and
  Claude calls, each with its sparkline, and visitors and sign-ups a day.
  A visitor is a person once a day, on every device and language they used
  (the totals are kept over all of each as well as by each); People in the
  tables is person-days.
- **Funnels**, **Retention** (a heatmap, a share in each cell),
  **Pages** (views by template and the site's acts), **The studio** (firsts,
  tools, panels, commands, runs, controls, where visits stopped, never
  used), **Sources** (channels, sources, the desk's campaigns with their
  posts), **Speed**, **Errors**, **Claude**.
- **Definitions:** what each number means; every number's name in the
  section links to its own.

Charts follow the dataviz method: one series each in one blue (#2a78d6
light, #3987e5 dark, both validated against the console's panels), thin
marks, a hairline grid, a tooltip on hover and focus, and each chart as a
table too. Each chart is one Tab stop, the arrow keys moving between its
days; on a phone the tab strip keeps the open tab in view. Before `supabase/analytics.sql` is applied the section says so
and the beacon's route keeps nothing.

## Where it lives

`web/counting.js` (may this browser be counted), `web/counting-ask.js`
(the ask, Settings' choice), `web/tally.js` (the counter), `web/counting.html`
(`/counting`), `api/_analytics.js` (the route, the read, the cron, a tool
call's count), `api/_insights_names.js` (the names it keeps, made by
`tools/insights_names.py`), `supabase/analytics.sql` and
`supabase/analytics2.sql` (additive; every table with row security on and
nothing granted, its functions the server's alone; analytics2 is the
review's fixes, dry-run in `tools/analytics2_try.sql`),
`web/admin-analytics.js`. Proven by `tests/test_insights.py` (with
`tests/fixtures/insights/attacks_check.mjs`, the review's attacks, and
`tests/test_insights_page.py`) and, on a deployment,
`tools/web/insights_flow.mjs` (preview check `insights`).

## The review (2026-11-18)

An independent review (bench/results/inreview-2026-11-18/report.md) found 3
High, 7 Medium and 7 Low faults before it went live; all are fixed (infix):
previews and live checks wrote people's tool-call rows (H1); the owner's
read and the never-pressed names had no bound (H2); six forged accounts
stopped account deletion for good (H3); a beacon's account was never
checked, so anyone could add activity to anyone's (M1); one beacon counted
800,000 likes (M2); the day's cap blinded the rest of the day (M3); a tool
call was counted under the account whatever it chose (M4); the ask was hard
to use by keyboard (M5); "never used" counted only pointer presses (M6);
visitors and People were wrong across devices (M7); a beacon's body was
never measured (L1); the desk's `social_visit` and the counter's scripts
went under Do Not Track, GPC and No (L2, L3); clocks that name no place
never asked (L4); a backlog of flooded days never rolled up (L5); relayed
tool calls never said whether they went (L6); and the charts were 60 Tab
stops, the open tab out of view on a phone (L7).
