# Capacity before an ad push

webstart11, 2026-11-18. What breaks first if ads send people to
brickworks.diy, with today's numbers and where each came from. All were
read without changing anything: Vercel's billing and project reads, the
read-only `admin_usage` that `/admin#data` shows, and first visits already
measured on disk. No browser was run for this page.

## The answer, short

- **At 1,000 clicks a day nothing goes down. It costs money.** Vercel's
  data transfer is first: the team uses about 830 GB of its 1 TB a cycle,
  mostly our own tests, so about 300 first visits a day use the rest.
  Past it, 1,000 clicks a day bills about $50 a month, and 10,000 a day
  about $750, on Vercel's per-GB price.
- **Sign-in breaks first for groups, not for crowds.** One address (a
  school, an office, a phone carrier's shared address) gets 20 codes per
  15 minutes from our own limit, then 30 redeemed per 5 minutes from
  Supabase's. 100 sign-ups an hour from different places hits nothing.
- **orangecheck sign-ins share one bucket.** Our server redeems them at
  Supabase from Vercel's address, so all of them may share one IP's limit:
  30 at once, then one every 10 seconds (360 an hour). At 1,000 sign-ups an
  hour this is the first thing that fails.
- **Sign-in mail shares one Resend team with about nine other products.**
  10 sends a second and one monthly quota for all of them. 1,000 sign-ups
  an hour, kept up for a day, uses about half of a 50,000-mail month.
- **Supabase egress is not the limit from ad traffic.** A first visit
  draws 0.35 MB from Supabase. 10,000 clicks a day is 105 GB a month,
  under the 250 GB cached-egress quota. But the organization had drawn
  about 1,100 GB by 2026-11-12 with its other products. If the spend cap
  goes back on, Brickworks goes down with them, whatever Brickworks does.
- **Monthly active users:** Supabase Pro includes 100,000. Everyone must
  sign in to use the studio, so 10,000 clicks a day with a third signing
  up reaches it in a month. Past it, each extra user costs $0.00325.

What could not be read without the owner: the organization's egress and
active users this cycle, and whether the spend cap is on (Supabase's
Management API, whose token reaches every project); the Resend team's plan
tier, month-to-date sends and overage setting (only the team's full-access
key can read them); and any Vercel spend-management pause (the dashboard).

## 1. Supabase egress

Supabase counts two kinds, each with its own quota and price. **Cached**
egress is what its CDN serves on a hit: here, the part geometry and the
model library in the `parts` bucket (both answered `cf-cache-status: HIT`
today). **Uncached** egress is everything else: the database through
PostgREST, sign-in, storage misses. Only bytes Supabase sends count.

What a visit draws from Supabase, from load_check's per-file lists:

| | From Supabase | Measured on |
|---|---|---|
| First visit to /app, cold | 0.21-0.33 MB in 28-33 requests: the start scene's part files (about 11 KB each) and a token, 2 KB | brickworks.diy, 4 cold loads, 2026-11-16 (`bench/results/webstart10-2026-11-16/lever_live/*_live/load.json`); 0.34 MB on the rel-m305, m307 and m308 previews (`bench/results/release-out/rel-m30*_pv_load/load.json`) |
| Signing up | under 20 KB, estimated: the code asked (`/api/otp`), redeemed (a 2 KB session), the age answer | not measured; `api/otp.js`, `api/account.js` |
| A return, studio opened from the cache | 1.5-2 KB: a token renewal. 26-31 part files came from the browser's cache | the same 4 live runs, warm |
| A save | a few hundred bytes back from the database (`/api/models`) | `api/models.js` |
| Opening the gallery | up to 0.35 MB (a 16 KB list and 24 pictures of about 13 KB), and only when Vercel's cache misses: the list is kept 30 s, each picture 10 min | one live read of `/api/share?op=list` and a picture; `api/share.js` |
| Each part placed for the first time | about 11 KB, then kept a year by the browser | the 31 start files averaged 10.7 KB |
| File, Open, Library | the index, 0.53 MB uncompressed, kept 5 min; then the model, 0.6 MB (10001-1) to 36 MB (8466-1) | read of the bucket's headers today |

So plan on **0.35 MB a first visit** with sign-up, and **0.7 MB a returning
builder** (30 new parts, a gallery that missed every cache, a few saves).
Add 0.5 MB plus the set's file for one who opens the library.

| | The quota | First visits it fits | Returning builders it fits |
|---|---|---|---|
| Cached egress | 250 GB a month, then $0.03 a GB | about 700,000 | about 350,000 |
| Uncached egress | 250 GB a month, then $0.09 a GB | over 10 million (about 20 KB each) | over 1 million |
| 1,000 clicks a day | 10.5 GB a month of first visits | | |
| 10,000 clicks a day | 105 GB a month of first visits, about $3 if all of it is over quota | | |

Those fits assume Brickworks has the quota to itself. It does not: the
quota is the organization's. On 2026-11-12 the organization had drawn about
1,100 GB of cached egress against its quota and every product in it
answered 402. Brickworks drew about 180 GB of that, mostly set pages
re-reading whole `.mpd` files; that was fixed (d731b1a87, a week's cache).
The spend cap was removed that night, so egress past the quota is now
billed, not refused. Today's project size, from `admin_usage`: database
537 MB of 8 GB, storage 7.5 GB of 100 GB, 154 accounts.

Sources: [Supabase pricing](https://supabase.com/pricing),
[egress](https://supabase.com/docs/guides/platform/manage-your-usage/egress),
[spend cap](https://supabase.com/docs/guides/platform/cost-control).

## 2. Sign-in rate limits

Every visitor signs in before the studio can be used (`src/ui/sign_in_gate.gd`).
Here is each step, who calls it, and whose limit it spends:

| Step | Called by | Limit | Whose bucket |
|---|---|---|---|
| Ask for a code (`/api/otp`) | the visitor, to our function | ours: 4 an address, 20 an IP, per 15 min (`may_ask_for_code`) | the visitor's IP (`x-forwarded-for`) |
| Make the account and mint the code | our function, Supabase's admin API with the secret key | none found; admin calls from this box were never limited | none |
| Send the code | our function, to Resend | 10 requests a second; one monthly quota | the whole Resend team |
| Redeem the code (`/auth/v1/verify`) | the visitor's browser, at Supabase | 30 per 5 min, 30 at once | the visitor's IP |
| orangecheck sign-in (`/auth/v1/verify`) | our function (`api/orangecheck.js`), at Supabase | 30 per 5 min, 30 at once | Vercel's outgoing address, shared |
| Renew a session (`/auth/v1/token`) | the visitor's browser | 150 per 5 min, 30 at once | the visitor's IP |

Supabase's own sign-in mail (2 an hour without custom mail) is never used:
`generate_link` mints the code and sends nothing, and Resend sends it.

Resend: brickworks.diy sends from the team that holds about nine other
products' domains (`docs/ADMIN.md`, Mail). That team is at its 10-domain
cap, which is the Pro plan: 50,000 mails a month for $20 or 100,000 for $35,
no daily limit, $0.90 per 1,000 over when pay-as-you-go is on. Past the
quota without it, every send answers 429 `monthly_quota_exceeded` for every
product on the team. In the last 24 hours Brickworks asked for 56 codes, 51
of them to Resend's test inbox (`otp_requests`, kept a day). `api/otp.js`
sends once: a 429 from Resend tells the person "We could not send the email
just now".

| Sign-ups in one hour | What it hits first |
|---|---|
| 100, from different places | nothing. 0.03 sends a second against 10; Supabase limits are per visitor |
| 100, 25 from one school's address | our 20 codes per 15 min: the 21st is told to try again after a time, up to 15 min later |
| 1,000, from different places | orangecheck sign-ins, if more than about 30 come at once or 360 in the hour: they answer busy. Email codes still pass (0.28 a second) |
| 1,000 an hour, kept up a day | 24,000 codes: about half a 50,000 month in a day, shared with the other products |

Sources: [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits),
[Resend quotas and limits](https://resend.com/docs/knowledge-base/account-quotas-and-limits),
[Resend pricing](https://resend.com/pricing). The per-IP figures match
what this box measured on 2026-10-23.

## 3. Vercel

The team is on Pro (`GET /v2/teams`), billing cycle 2026-10-21 to 11-21.
The project runs Fluid compute in iad1 (`GET /v9/projects`). There is no
`vercel.json`: `tools/deploy.sh` writes the routes and functions. Usage is
the team's billing record (`GET /v1/billing/charges`), up to 11-16:

| | Pro's limit | This project |
|---|---|---|
| Functions | no cap a deployment | 12 (`api/*.js`, `tools/package_api.sh`) |
| Routes | 2,048 a deployment | about 116 (`tools/deploy.sh`) |
| Longest run | 300 s by default, 800 s at most | 300 s set on each |
| Memory | 2 GB by default, 4 GB at most | the default |
| Concurrency | scales with demand (no figure published) | |
| A request or answer's body | 4.5 MB | |
| Fast Data Transfer | 1 TB a cycle, then $0.15 a GB in the US, up to $0.20 elsewhere | team 723 GB this cycle, Brickworks 619 GB of it |
| CDN requests | 10 million a cycle, then $2 a million | team 17.6 million (past it), Brickworks 9.3 million |
| Function invocations | $0.60 a million | team 7.1 million, Brickworks 2.7 million |

The 1 TB and 10 million are the team's own billing items (`GET /v2/teams`).

A first visit takes 16.9 MB from Vercel in 15 files: the engine's wasm
6.9 MB, the data pack 5.0 MB, the carried parts 2.6 MB, the engine's pack
2.3 MB, and small ones. It makes 8 function calls (`/api/account` 3 times,
`/api/models` 3 times, `/api/people`, `/api/collection`), and signing up
adds `/api/otp` and `/api/account`. A return takes 1-5 KB from Vercel and
the same 8-9 calls. (phonetruth's own count said 9 MB on Chromium: it
leaves out what the engine's worker fetches.)

| Clicks a day | Data transfer a month | CDN requests | Calls | Cost past the included |
|---|---|---|---|---|
| 1,000 | 507 GB | 0.7 million | 0.3 million | about $50 (with tests, 1.34 TB) |
| 10,000 | 5.1 TB | 7.2 million | 3.3 million | about $750 on per-GB pricing |

At today's pace the team ends a cycle near 830 GB, so about 10,000 first
visits a cycle fit before transfer is billed. 86% of the team's transfer
is this project, most likely our own tests and release checks: only 154
accounts exist. Vercel's Flat Rate CDN replaces the per-GB price with a
tier; the team's 17.6 million requests already need the $100 tier (50
million requests, 50 TB). Its terms exclude sites whose bandwidth is mostly
file downloads, so the owner should confirm a 17 MB app counts as an app.

Sources: [Vercel limits](https://vercel.com/docs/limits),
[functions limits](https://vercel.com/docs/functions/limitations),
[Pro plan](https://vercel.com/docs/plans/pro-plan),
[iad1 prices](https://vercel.com/docs/pricing/regional-pricing/iad1),
[Flat Rate CDN](https://vercel.com/docs/pricing/flat-rate-cdn).

## 4. A phone's first visit

webstart12, 2026-11-19. What a visitor's own device runs out of first, in
pairs at the same moment against pre261 (docs/PHONE.md, "What the first
screen compiles and never runs").

- **An iPhone's memory.** The page's Wasm memory peaks while the first
  screen's scripts compile, and a page never gives it back: 432 MB, where
  an iPhone reliably gives about 300. On an iPhone or iPad it now peaks at
  360 MB, compiled a cycle at a time, and starts sooner (WebKit as an
  iPhone 13: working 19.4 → 17.3 s). Still over 300: some iPhones will
  refuse it (the memory warning in `/admin#switches` › Phones says so).
- **A slow phone's CPU.** At a quarter of this box's speed on Fast 4G a
  first visit is working in about 57 s, 22.5 s of it the scripts' compile.
  Code the start never runs is 23% of that compile, so no deferral gets
  the phase near 12 s; only less code the start runs does.

## What to do before an ad push

In order. The first two are the owner's: money, and the owner's sign-in.

1. **Read the Supabase organization's usage** (Dashboard, the
   organization, Usage): cached and uncached egress and active users this
   cycle. Decide the spend cap knowingly: on, any product can take every
   product down; off, the overage is billed.
2. **Read the Resend team's plan and month's sends**, and turn on
   pay-as-you-go overage, or give brickworks.diy a team of its own, so one
   product's mail cannot stop another's sign-in.
3. **Take our tests off Vercel's transfer**, as partsmirror took them off
   Supabase: load checks and flows read the build from a local copy. That
   is up to 619 GB a cycle back, room for about 36,000 first visits.
4. **Choose Vercel's CDN pricing** for the expected traffic (per GB, or
   the $100 Flat Rate tier) and set a spend alert at that figure.
5. **Give orangecheck sign-ins their own bucket**: send the visitor's
   address as `Sb-Forwarded-For` (it needs the secret key and forwarding
   turned on for the project). A unit's change, `api/orangecheck.js`.
6. **Send a code again once when Resend answers 429**, after a second
   (`api/otp.js` sends once today).
7. **Decide the per-address code limit** for shared networks: 20 per 15
   minutes stops a class of 25. The 4 an address stays.
8. **Watch it live**: `/admin#site` shows Supabase answering 402, and
   `/admin#mail` counts codes once Resend's webhook is turned on (still
   pending).
