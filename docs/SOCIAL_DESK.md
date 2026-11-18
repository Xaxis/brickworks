# The social desk

The owner asked on 2026-11-18 for /admin to handle Brickworks' social media:
messages, posts and responses. Reddit comes first. X, Facebook and Instagram
must be addable later without a rewrite. The desk lives at **/admin › Social**,
which only the owner can open (docs/ADMIN.md).

Every source below was read on 2026-11-18. **primary** means the network's own
docs, help or terms. **secondary** means a vendor, a blog or the news.
**unconfirmed** means no primary source could be checked.

## What the owner needs to know first

**Reddit takes no new API apps.** Reddit's help-center changelog of
2026-10-08 gives the dates:

- **31 October 2026:** "New requests for public API access will no longer be
  accepted."
- **12 January 2027:** "API access removal begins for apps and users that
  haven't registered or responded to Reddit's outreach."
- **March 2027:** "Remaining public API access ends."

Source: <https://support.reddithelp.com/hc/en-us/articles/54353370049684> (primary).
The 2026-11-10 changelog says the same:
<https://support.reddithelp.com/hc/en-us/articles/55472297340308> (primary).

Even before that date there was no self-serve key. Since late 2025 every app
has needed Reddit's explicit approval, and use for a business needs its
written approval. Sources: the Responsible Builder Policy,
<https://support.reddithelp.com/hc/en-us/articles/42728983564564> (primary),
and the Developer Terms §4.1, <https://redditinc.com/policies/developer-terms>
(primary).

So **there is nothing for the owner to click today** that would give the desk
a Reddit app. The desk does two things instead.

1. **It posts by hand.** The page says so wherever it matters.
   1. The owner copies the words (Copy the words comes first), and opens
      Reddit's own submit page. The desk puts the title and words in its
      address (`submit?title=…&selftext=true&text=…`). No Reddit page documents
      those parameters, and a 2025 r/help thread says new Reddit does not fill
      the text from them, so the page says Reddit *may* fill them and to paste
      the words where a box is empty.
   2. Words too long for the address go without it. Reddit's submit page
      answered a 6,363-character address and refused a 12,363-character one
      with 414 URI Too Long (read 2026-11-18,
      `bench/results/sdreview-2026-11-18/reddit_url_length.txt`), so above
      6,000 characters the page opens with the title alone. The sheet says so
      before the press.
   3. The owner presses Post there, and pastes the post's own address back
      into the desk (a Share link or redd.it link is refused: it names no post).
   4. From then on, the visits it brings are counted. Its score and comments
      are read only through a connected account, so by hand there is none:
      Reddit's public JSON answers 403 to a server
      (`bench/results/sdreview-2026-11-18/reddit_public_rules_json_403.txt`).

   This is what Postpone moved to when it lost its access on 2025-11-30
   (below).

2. **It is ready for the API.** The whole API path (connect, inbox, reply,
   post, schedule, results) is built and proven against a stand-in Reddit
   (`api/_social_mock.js`) that keeps Reddit's rules for a client. Should
   Brickworks ever get a written agreement with Reddit, the owner does this:
   1. On reddit.com/prefs/apps, signed in as Brickworks' own account, press
      **create another app…**.
   2. Choose **web app**. Name: Brickworks. About URL: `https://brickworks.diy`.
      Redirect URI: `https://brickworks.diy/admin?connected=reddit`.
   3. Press **create app**. The client id is the short string under the app's
      name; the secret is the one labelled "secret".
   4. In Vercel › brickworks › Settings › Environment Variables, add
      `REDDIT_CLIENT_ID` and `REDDIT_CLIENT_SECRET` to Production.
   5. Redeploy, open /admin › Social › Accounts, and press **Connect Reddit**.

   Until then the Accounts tab names both variables as missing, says why, and
   keeps Connect asleep. The historic click path is from
   <https://www.redditapis.com/blogs/how-to-get-reddit-api-key-2026>
   (secondary); the names `client_id` and `client_secret` are from
   <https://github.com/reddit-archive/reddit/wiki/OAuth2> (primary, archived).

## What the desk promises

- **Nothing leaves without the owner's own press of Send on that exact text.**
  - The page saves the draft first. It then shows the words exactly as the
    server keeps them: the title, the link, the words, the community.
  - Send carries the server's hash of those words (sha256 over provider,
    kind, community, parent, title, body, link). If anything changed since
    the sheet opened, the server answers 409 and sends nothing.
  - The database holds the same line: a row past `draft` without
    `pressed_at`, `pressed_by`, `pressed_hash` and `route` is refused by
    `social_sends_pressed`.
- **Scheduling sends only what was pressed.**
  - Schedule is the same press, with a time.
  - The quarter-hourly cron sends a due row only if its words still hash to
    the press. Words edited after the press make the row a draft again.
  - A row whose words were changed behind the desk is marked failed, not sent.
- **No automatic posting, replying or voting, ever.**
  - The adapter has two writing calls: `/api/submit` and `/api/comment`.
  - It has no vote, no edit, no delete, no compose and no mark-read call;
    `tests/test_social.py` checks that.
  - `provider.send` is called in one place, `deliver()`, and only from the
    press and the due sends.
- **Tokens stay on the server.**
  - They are kept in `social_tokens`, which only the server's role reads.
  - They are never in an answer, a page, a log or an address; the tests and
    the flow search every answer, page, store and log line for them.
  - Disconnect revokes them at Reddit and deletes them here.
- **Only the owner.** Every op answers 401 signed out and 404 to any other
  account. That is the console's own answer: a 403 would tell a stranger the
  console exists. Every POST is kept in the audit log.

## Where it is in /admin

**/admin › Social**, with four tabs. The Overview's "Needs you now" counts
unread items, posts waiting on the owner at Reddit and failed posts, and the
section's badge sums them.

- **Inbox** (`#social/inbox`): replies to our posts and comments, username
  mentions, mentions found by search across Reddit, and private messages, in
  one list, newest first. Search; All, Unread, Replies, Mentions, Messages.
  Each item has Open on Reddit, Reply…, and Mark read or unread. Read and
  unread are kept here alone; nothing is marked at Reddit. Check now looks
  again; the cron looks every quarter of an hour.
- **Write** (`#social/write`): one form for a post or a reply.
  - Beside it are the community's rules: Reddit's own list, the members, what
    it takes, its "when you post" text and a link to its rules page, plus the
    owner's own notes on them, kept per community.
  - Below it are the drafts.
  - Links to brickworks.diy are tagged when the draft is kept.
  - "Review and send…" opens the sheet: the exact words, then Send now, or a
    day and a quarter-hour to Schedule.
- **Sent and scheduled** (`#social/sent`): every post and reply that went or
  waits. For each: its state, score, comments and the visits it brought, with
  Unschedule; Post it on Reddit…, Back to drafts and Drop (handed to the
  owner); Look again and Drop (failed); Is it up?… (unsure, below); and
  Details (its words, when and by whom it was pressed, its tag, its score
  over time, its visits by day). On a phone each row is a card.
- **A send is never sent twice.** Reddit's own no ("did not take the post")
  marks it "Did not go", and it may be pressed again. Anything less clear (a
  timeout, Reddit's 5xx, an answer that names no post, the row not written
  after) leaves it unsure: still "sending", never sent again on that press,
  by Send, an edit or a drop. So does a send cut off mid-request, five
  minutes on. Is it up?… links to the account's posts; the owner pastes its
  address if it is there, or takes it back to the drafts and presses Send
  afresh. The open sheet's Send now stays off once pressed.
- **A Reddit post is a link or words**, never both: the form refuses both
  rather than send one and drop the other. An edit after Schedule or a
  hand-off says it undid the press.
- **Accounts** (`#social/accounts`): Reddit (connected or not, what is
  missing and why, Connect, Check now, Disconnect), and X, Facebook and
  Instagram as "Not connected yet", each with what it needs and costs.

## Reddit, as read

### The API (for when access exists)

- **App types.** A *web app* is a server only you use and keeps its secret;
  it uses the code flow. A *script* is for your own account only. The desk is
  a web app: code flow with `duration=permanent`.
  <https://github.com/reddit-archive/reddit/wiki/OAuth2-App-Types> (primary,
  archived)
- **Endpoints.**
  - Authorize at `https://www.reddit.com/api/v1/authorize`.
  - Tokens from `https://www.reddit.com/api/v1/access_token`, with HTTP Basic
    auth of the client id and secret.
  - Revoke at `/api/v1/revoke_token`. Revoking the refresh token revokes its
    access tokens too.
  - Access tokens last an hour; a permanent grant adds a refresh token.
  - The API host is `oauth.reddit.com`.

  <https://github.com/reddit-archive/reddit/wiki/OAuth2> (primary, archived)
- **The desk's calls and the scopes they need.** Scopes:
  `identity history privatemessages read submit`. Scopes per endpoint are
  from the archived server source's `@require_oauth2_scope` (primary,
  archived; live behaviour unconfirmed).

  | Call | For |
  |---|---|
  | `/api/v1/me` | who connected |
  | `/message/inbox` | replies, mentions, messages |
  | `/search` | mentions across Reddit |
  | `/r/X/about/rules` and `/about` | the rules beside the box |
  | `/api/submit` | a post |
  | `/api/comment` | a reply to a comment, a post or a message |
  | `/api/info` | the score and comments over time |
- **Rate limits.** "100 queries per minute (QPM) per OAuth client id",
  averaged over 10 minutes, with `X-Ratelimit-*` headers. Unidentified traffic
  is blocked. The User-Agent must read
  `<platform>:<app ID>:<version string> (by /u/<reddit username>)`; the desk
  sends `web:diy.brickworks.desk:1.0 (by /u/<handle>)`. The Data API Wiki,
  <https://support.reddithelp.com/hc/en-us/articles/16160319875092> (primary)
- **Cost.**
  - No public price. Reddit "reserves the right to charge fees", and
    commercial use needs "a separate agreement": Data API Terms §3.1,
    <https://redditinc.com/policies/data-api-terms> (primary).
  - The 2023 figure of $0.24 per 1,000 calls was never re-published, so treat
    it as stale.
  - The desk's quarter-hourly look makes five calls (the inbox, three
    searches, the results), about 480 a day: far under the limit.
- **Builder rules the desk keeps.** From the Responsible Builder Policy
  (primary):
  - "App accounts should solely be used to perform app functions (no mixed
    use accounts)". So connect a Brickworks account, not a person's.
  - "Apps must not manipulate Reddit's features (e.g., voting, karma)".
  - "Apps must not engage in spamming activity through automated posts,
    comments, or direct messages".
  - No sending private messages to people who did not write first. The desk
    only answers messages that came in; it cannot start one.
- **Reddit's replacement, the Developer Platform (Devvit), is not a route.**
  Its apps post as a person only "on an explicit manual action", inside a
  community where the app is installed, and cannot vote. A brand posting into
  other people's communities is not what it is for.
  <https://developers.reddit.com/docs/capabilities/server/userActions> (primary)
- **The one shape check.** On 2026-11-18 the desk made one read-only call to
  `www.reddit.com/r/lego/about/rules.json` from this machine: **403**, an HTML
  page ("blocked by network security"). The research's eight calls had the
  same answer. So the stand-in's shapes come from the archived API source and
  wiki, not from a live answer. The adapter reads every field defensively: a
  missing one is null, never a crash.

### What gets an account banned

- **Reddit Rules**, Rule 2: "Abide by community rules. Participate
  authentically in communities where you have a personal interest, and do not
  spam". Rule 5: no deceptive impersonation.
  <https://redditinc.com/policies/reddit-rules> (primary)
- **Spam.** "Do not use Reddit for repeated or unsolicited mass engagement."
  <https://support.reddithelp.com/hc/en-us/articles/360043504051> (primary,
  edited 2026-10-30). Its examples:
  - "If your contributions to Reddit consist primarily of links to a
    business that you run";
  - "Mass-posting repetitive content for the purpose of exposure";
  - "Programming a bot that continuously promotes specific products";
  - "Using tools (e.g., bots, generative AI tools) that may … facilitate the
    proliferation of spam".
- **The 9:1 rule of thumb.** "only 1 out of every 10 of your submissions
  should be your own content". This is Reddiquette: users' guidance, not
  policy. <https://support.reddithelp.com/hc/en-us/articles/205926439>
  (primary)
- **Flagged accounts and bans.** A flagged account's posts "may not display
  normally". Bans for spam are appealed at reddit.com/appeals. Domains can be
  suspended under the Builder Policy.
  <https://support.reddithelp.com/hc/en-us/articles/360045309012>,
  <https://support.reddithelp.com/hc/en-us/articles/360045734911> (primary)
- **New and low-karma accounts.** No site-wide age or karma threshold was
  found (unconfirmed). Each community's moderators set their own.

### The communities

Reddit refused every read from this machine, so each community's own rules
are **unconfirmed** here. That is why the desk puts the rules beside the box
and links to each rules page. The owner should read them signed in before a
first post, and keep notes on them in the desk.

- **r/lego**: exists, about 2.8 million members.
  <https://gummysearch.com/r/lego/> (secondary)
- **r/legodesign** and **r/LegoMOC**: listed by third parties, size and rules
  unconfirmed. A builders' blog advises a comment with the part count and a
  parts list with a MOC: <https://theearlofbricks.com/blog-studio-publish-moc/>
  (secondary).
- **LDraw has no subreddit of note.** Its community is its own forum,
  <https://forums.ldraw.org/>, whose "General LDraw.org Discussion" covers
  "any other Lego CAD related topic" (primary for LDraw). A post there is by
  hand; the desk does not reach it.
- **Rebrickable**, if a post links a MOC page there, bars links to
  clone-brand sites: <https://rebrickable.com/help/banned-sites/> (primary).

### What the owner should do on Reddit

Inferred from the rules above:

- Post from a Brickworks account, say it is ours, and take part beyond our
  own links.
- Keep our own links near one in ten of what the account posts.
- Never post the same thing to several communities.
- Reddit Pro is free and native. Its Trends watches keywords; its Performance
  shows views and upvote ratio. Both are worth having beside the desk.
  <https://www.business.reddit.com/pro> (primary)

## X, Facebook and Instagram: the owner's choice

Each is a later entry in `api/_social.js`'s `PROVIDERS`. The page already
shows each as "Not connected yet" with what it needs and costs. Adding one
is an adapter with the Reddit adapter's functions (authorizeUrl, exchange,
refresh, revoke, me, inbox, mentions, rulesOf, results, send, handOff,
thingOf), its stand-in for the tests, and its id in social.sql's provider
checks, which already allow it. No table changes.

| | X | Facebook Page | Instagram (professional) |
|---|---|---|---|
| What it costs | Pay per use, no plan: **$0.015** a post, **$0.20** a post with a link, **$0.01** a reply when summoned, $0.015 a DM, $0.005 a post read, $0.001 an owned read. A spending cap per cycle | No fee from Meta | No fee from Meta |
| A month of 30 posts | $6.00 with a link in each ($0.45 without); 1,000 mentions read $5.00 | $0 | $0 |
| What the owner sets up | An app at console.x.com, OAuth 2.0 with PKCE: `tweet.read tweet.write users.read dm.read dm.write offline.access`. No approval step | A Meta app with the owner as its admin and as the Page's admin. Standard Access covers accounts with a role on the app, but posting to the Page likely needs App Review for `pages_manage_posts` (unconfirmed: the Pages overview says every Page permission does), and posts reach the public only from a Live app | The same Meta app; the Instagram account professional and linked to the Page; `instagram_business_basic`, `instagram_business_content_publish`, `instagram_business_manage_comments`, `instagram_business_manage_messages` |
| What a brand can read | Mentions, replies, DMs | The Page's posts, comments and Messenger conversations | Comments, mentions, DMs |
| What it can send | Posts; replies only when the author summoned it (an @mention or a quote) since 2026-02-23; DMs. No likes, follows or quote-posts on self-serve | Posts, comment replies, messages within 24 h (7 days for a person replying by hand, the Human Agent tag) | Posts (at most 100 by API a day; one passage says 50), comment replies, DMs only after the person wrote first, within 24 h |
| Sources | <https://docs.x.com/x-api/getting-started/pricing>, <https://docs.x.com/changelog>, <https://docs.x.com/x-api/fundamentals/rate-limits> (primary) | <https://developers.facebook.com/docs/graph-api/overview/access-levels/>, <https://developers.facebook.com/docs/pages-api/overview/>, <https://developers.facebook.com/docs/messenger-platform/policy/policy-overview/> (primary) | <https://developers.facebook.com/docs/instagram-platform/content-publishing/>, its messaging API page (primary) |

**The recommendation:**

1. **Facebook and Instagram next, together.** They are one Meta app, with no
   fee and no review for the owner's own Page and account. The desk's inbox,
   reply and post fit them as they are.
2. **X after them, with a cap.** X costs little at Brickworks' size (a few
   dollars a month), but a link costs 13 times a plain post. Put the link in
   the first reply, or accept $0.20 a post. Set X's spending cap to $10 a
   month at console.x.com. The desk would show each send's cost on its Send
   button.

## What the best tools do, and what the desk does better

| Tool | Reddit today | Price for one brand |
|---|---|---|
| Buffer | No Reddit among its 17 networks | $5–10 a channel a month |
| Hootsuite | Listening (with Talkwalker) and ads; no organic Reddit posting found | $99–399 a user a month |
| Later | No Reddit | $18.75–82.50 a month |
| Sprout Social | Official Reddit Data Partner: inbox, replies, scheduling with rule checks | $79–399 a seat a month |
| HubSpot | Reddit posts, rules shown, schedule, inbox of comments and mentions | Marketing Hub Professional $800 a month and $3,000 onboarding |
| Postpone | Lost its API access 2025-11-30; reminds you, you post in Reddit's app; inbox dropped | about $9–12 a month (unconfirmed) |
| Later for Reddit | Shuts 2027-01-01 | — |
| Reddit Pro | Native and free: Trends, Performance, scheduling only to your profile and communities you moderate | Free |

Sources: <https://support.buffer.com/article/567-supported-channels>,
<https://buffer.com/pricing>, <https://www.hootsuite.com/plans>,
<https://www.business.reddit.com/solutions/data-partners-overview>,
<https://later.com/pricing/>, <https://sproutsocial.com/integrations/reddit/>,
<https://sproutsocial.com/pricing/>,
<https://knowledge.hubspot.com/social/create-and-publish-reddit-posts>,
<https://www.hubspot.com/pricing/marketing>,
<https://www.postpone.app/blog/changes-to-reddit-posting-in-postpone>,
<https://laterforreddit.com/news/2026/10/03/later-for-reddit-is-shutting-down/>
(each the vendor's own page, read 2026-11-18).

Where the desk matches the best, and where it does better:

- **The press, by the words.** No tool binds Send to the exact words
  reviewed. Approvals in Buffer, Hootsuite and Later are a paid tier, and
  approve a post, not its text.
- **The rules beside the box,** with the owner's own notes per community
  (as Sprout and HubSpot show rules).
- **Visits by post, free.** Every link to the site is tagged on its own, and
  each landing is counted once per visitor, by post and by day. Buffer gates
  custom UTM behind a paid plan; Reddit Pro has no link clicks.
- **Results over time:** score and comments every quarter of an hour, kept,
  beside the visits.
- **One audit** of every act: who pressed what, when.
- **Honest about Reddit.** By hand today, with the API proven and waiting.
  This is the model Postpone moved to, and the desk keeps the inbox the
  others dropped, for when access exists.
- **Not yet:** a frequency warning per community, and repeat protection
  (Postpone has both); Reddit Pro's views (no API). Both are small additions
  to the composer when wanted.

## How it is built

- **One model for every network** (`api/_social.js`): accounts, tokens, items
  (what came in), sends (drafts to sent), results over time, visits, and
  rules with notes. One adapter per network behind one interface; Reddit's is
  `api/_social_reddit.js`. The checks' pool (`?tests=1`) talks to the stand-in
  alone, so a check never reaches reddit.com.
- **The ops** are on api/admin.js (the deployment stays at 12 functions):
  `social`, `social_rules` (reads) and `social_connect`, `social_connected`,
  `social_disconnect`, `social_sync`, `social_mark`, `social_draft`,
  `social_drop`, `social_send`, `social_unschedule`, `social_posted`,
  `social_notes`. On api/plans.js are the cron's `social_due` (CRON_SECRET)
  and the public `social_visit` (always 204).
- **Connect** is OAuth's code flow.
  - The state is signed here (HMAC, ten minutes), so a code is taken back
    only for a connect the owner started.
  - Coming back, the page lifts the code and state from the address before
    anything else, so neither stays in the history.
- **The cron** `/api/plans/social-due` runs every 15 minutes (`*/15 * * * *`;
  tools/deploy.sh). It sends the due scheduled rows whose words still match
  their press, then reads each connected account's inbox, mentions and
  results. It notes a run in `cron_runs` when it sent, failed, was run by hand
  (Site › Run now), or at its first run after midnight UTC. A clean look is
  not noted, so the table does not grow by 96 rows a day.
- **UTM.** When a draft is kept, each link to brickworks.diy (or the console's
  own host) gets `utm_source=<network>&utm_medium=social&utm_campaign=bw-<send
  id>`; other links are left alone. web/theme.js, on every page, sees a
  campaign of that shape and tells `/api/plans?op=social_visit`. The server
  counts a visitor once a day a post, by a key only it can make from the
  address and browser (neither kept), never by a number the page sends, and at
  most 1,000 visits a post in any hour, so nobody can inflate them. The page
  then takes the tags out of the address, so a visitor sharing the page does
  not carry them on. A visit counts only for
  a send that went.
- **Tables** (`supabase/social.sql`, additive, unapplied until the lead
  applies it): `social_accounts`, `social_tokens`, `social_items`,
  `social_sends`, `social_results`, `social_visits`, `social_rules`.
  - Each has row security on, no policy, and every grant revoked from
    `public`, `anon` and `authenticated`; only `service_role` reaches them.
  - None refers to an account of the site, so an account's export never
    reaches them.
  - The dry run is `tools/social_try.sql`:
    `node --env-file=.env tools/apply_sql.mjs supabase/social.sql --dry --try=tools/social_try.sql`.
    It ran against the project on 2026-11-18 and was rolled back:
    `bench/results/socialdesk-2026-11-18/social_dry_run.txt`.
- **Before the file is applied**, the section says "The social desk's tables
  are not on this database yet (supabase/social.sql)". Every write answers
  503, and Accounts still shows each network's needs and costs.

## How it is proven

- `tests/test_social.py`:
  - `tests/fixtures/social/api_check.mjs` runs the real handlers, with the
    tables held in memory and the stand-in Reddit. It covers the gate on all
    13 ops, connect with a forged state refused, the inbox's three kinds once
    each, rules, drafts and their tags, the press (a wrong hash or changed
    words refused, nothing written to Reddit), send, send twice, schedule
    (too soon, the cron's key, early, due), words changed after the press, a
    row tampered behind the press, results and visits, disconnect, and the
    by-hand route. And the review's cases (sdreview, 2026-11-18): a link and
    words refused; Reddit's answer lost (one post, then unsure: Send, an edit
    and a drop refused; found up, or back to the drafts and sent once on a
    fresh press); Reddit's own no as "did not go"; a send cut off mid-request,
    unsure after five minutes; a long post's address; a handed post taken
    back or dropped; a comment's or Share link's address refused for a post;
    a reply to a message marked sent; wrong types; a title of emoji; and two
    visitors counted as two however many numbers the page sends. Every answer, log line and request path is searched for a
    token.
  - `tests/fixtures/social/db_check.mjs` applies social.sql twice to a
    Postgres of its own. It checks that no role but the server's reads any
    table, that the refusals hold, and that a token goes with its account.
- `tools/web/socialdesk_flow.mjs` (the preview check `socialdesk`) runs in a
  browser as the owner on `?tests=1`. It covers the gate; connect through
  the stand-in's consent; the inbox and its filters; a reply; a post with its
  rules, its draft, a refusal of words changed behind the open sheet, and
  Send; Schedule and Unschedule; the cron sending one due; results; a visit
  by the tagged link; disconnect; a post by hand; every tab at 390 and 1280,
  light and dark; and no token in any answer, page or storage. Before the
  file is applied it proves the gate and the "not yet" state.
