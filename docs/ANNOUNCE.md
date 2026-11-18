# Announcements: telling the site's people something

The owner (2026-11-18): "users have a notifications page; me in my admin panel should be able to
send or trigger notifications ... we want to make sure we can completely manage every pertinent
aspect." This page covers how four products tell their users things, read on 2026-11-18, and what
Brickworks does as a result. The code is `api/_announce.js`, `web/admin-announce.js`,
`web/notice-view.js` and `supabase/announce.sql`. The console is /admin › Announcements
(docs/ADMIN.md).

## How others do it

**Intercom** has four in-product channels:
- Chats in its Messenger.
- Posts, "full-screen announcements displayed inside your product".
- Banners.
- Product Tours.

Sources: [FAQ](https://www.intercom.com/help/en/articles/8771588-chats-posts-and-banners-faqs),
[tours](https://www.intercom.com/help/en/articles/2900885-product-tours-explained).

- **Banners** sit at the top or bottom of the page. They can have a dismiss button, and "dismissals
  are permanent and stored server-side", so a dismissal follows the person to every device. A banner
  can have a start and an end. Outside those times it is not shown
  ([banner](https://www.intercom.com/help/en/articles/4557393-how-to-create-a-banner-message)).
- **Audiences** come in two kinds. A *dynamic* audience is whoever matches now and in the future. A
  *fixed* audience is only those who match now. Neither can be changed once the message is live
  ([audiences](https://www.intercom.com/help/en/articles/3467924-dynamic-and-fixed-audiences)).
- **News** is a feed inside the Messenger that people pull. Intercom reports how many opened,
  clicked and reacted to each item
  ([News](https://www.intercom.com/help/en/articles/6362267-getting-started-with-news)).
- **Email** goes to subscription lists. A marketing list must be opt-in, and "not choosing opt-in
  will result in compliance breach"
  ([subscriptions](https://www.intercom.com/help/en/articles/5181083-manage-multiple-email-lists-with-granular-subscriptions)).
  Intercom supports RFC 8058's one-click unsubscribe
  ([Google/Yahoo guide](https://www.intercom.com/help/en/articles/8806794-your-guide-to-google-yahoo-s-new-requirements-for-email-senders)).

**Discord** tells its users things in several ways:
- **Official Messages** arrive as DMs from "Discord Updates" with an OFFICIAL badge. Nobody can reply
  to them, and urgent ones also pop up in the app
  ([Official Messages](https://support.discord.com/hc/en-us/articles/360036118732-Discord-Official-Messages)).
- **Announcement channels** are for servers. A post can be published to every follower, at most 10
  times an hour, and an edit reaches the followers too
  ([FAQ](https://support.discord.com/hc/en-us/articles/360032008192-Announcement-Channel-FAQ)).
- **Email** comes in categories, Announcements & Updates among them, each chosen in Settings. Every
  mail can unsubscribe
  ([email settings](https://support.discord.com/hc/en-us/articles/4408820335767-How-can-I-manage-my-email-notifications-settings)).
- **A banner that outstayed its maintenance.** Discord's own patch notes record fixing a "scheduled
  maintenance banner ... [that] would stick around long after the maintenance date had passed"
  ([patch notes 2026-04-06](https://discord.com/blog/discord-patch-notes-april-6-2026)).

**GitHub** has three relevant tools:
- **Banners**, on Enterprise only. Each banner either has an expiry date, can be dismissed, or both:
  "Announcements must either have an expiration date, be user dismissible, or both"
  ([org banner](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/creating-an-announcement-banner-for-your-organization)).
  The API takes `expires_at` and `user_dismissible`
  ([REST](https://docs.github.com/en/enterprise-server@latest/rest/enterprise-admin/announcement)).
- **The inbox** at /notifications. It keeps items for three months
  ([configuring](https://docs.github.com/en/subscriptions-and-notifications/get-started/configuring-notifications)).
- **Marketing email**, kept apart from notification email and chosen by topic
  ([marketing](https://docs.github.com/en/subscriptions-and-notifications/how-tos/managing-marketing-emails-from-github)).

**Linear** delivers everything into one Inbox ([Inbox](https://linear.app/docs/inbox)).
- By default, email gathers notifications into digests, sent only for what is still unread.
- Each type can be turned on or off per channel, "changelogs ... and other communications" among
  them ([Notifications](https://linear.app/docs/notifications)).
- Since 2023 its mail has carried unsubscribe metadata
  ([changelog](https://linear.app/changelog/page/10)).

**What the mail rules require:**
- **One-click unsubscribe.** RFC 8058 asks for a `List-Unsubscribe` header with one HTTPS address,
  carrying a token that is hard to forge, and `List-Unsubscribe-Post: List-Unsubscribe=One-Click`
  ([RFC 8058](https://www.rfc-editor.org/rfc/rfc8058)). Since February 2024, bulk mail must have both
  headers and accept the POST
  ([Resend](https://resend.com/docs/dashboard/emails/add-unsubscribe-to-transactional-emails)).
- **Resend's limits.** Its batch endpoint takes up to 100 mails a call
  ([batch](https://resend.com/docs/api-reference/emails/send-batch-emails)). Its default limit is 10
  requests a second per team, shared by every key
  ([rate limit](https://resend.com/docs/api-reference/rate-limit)).

## What fits a small CAD community

Brickworks has a few hundred people, one owner, and a Notifications page they already use.

1. **In-app first, in the inbox they already have.** As with Linear and GitHub, an announcement is a
   group on the person's Notifications page, counted on their avatar and read the usual way. There
   is no new feed or popup.
   - Each announcement is one row. Who it reached is fixed as it goes, like Intercom's *fixed*
     audience: someone who signs up afterwards does not get last month's news. This also makes the
     reach count honest.
   - Who it reached is one row of `announcement_to` per person, written by the same statement as
     the send; its reach is the count of those rows. A person's Notifications read their own rows
     by account; the mail walks them by announcement.
   - Each person's read and click is one row of `announcement_reads`. The console's list reads only
     `announcement_counts`, kept as reads, clicks and mails happen: never a row per person.
2. **Audiences anyone can reason about:** everyone; a plan; the beta's testers; people who signed up
   since a day; people who published; one person by handle. The count shows before sending.
3. **The owner's own press on the exact words.** The review shows exactly what goes out and to whom,
   and the press carries the hash of those words.
   - Words changed since then are refused.
   - Two presses make one send.
   - An edit to a scheduled one makes it a draft again (the social desk's rule).
4. **A daily limit the owner sets** (two until changed). Discord caps announcements at 10 an hour;
   for a small community, a day's count is the right unit.
5. **Edits and withdrawals are honest.** An edit shows "edited", as Discord edits reach followers. A
   withdrawal takes it out of every list. Mail already sent stays sent, and the console says so.
6. **The banner always ends, and a person can dismiss it.** This follows Discord's stuck banner and
   GitHub's rule.
   - The site notice can carry an end time, and nothing shows after it.
   - Anyone can hide it. When signed in, the dismissal is kept server-side, as Intercom does, so it
     holds on every device.
   - A new notice is shown again, even to people who hid the last one.
7. **Email only for those who asked.** It is a "Brickworks news" choice in Settings › Email, off
   until turned on.
   - Each mail is optional per announcement, and in-app is the default.
   - It is sent through Resend from brickworks.diy, 100 to a batch, at most one request every
     1.1 s, and never within 1.5 s of a sign-in code Brickworks sent. That stays well under the
     team's 10 a second. Other sites on the same Resend team send codes too, and those cannot be
     known here; the 10 a second leaves room for them.
   - At most a number of news mails a day, which the owner sets in /admin › Announcements (200
     until changed, Resend's free daily quota being 100). It is counted inside the take, so two
     crons together cannot pass it.
   - When Resend answers 429 for its daily or monthly quota, news mail stops until the next UTC
     day, and the console says so in words. Sign-in codes come first.
   - Barred accounts are never mailed, and are in no audience but "one person".
   - The mail can carry a postal address the owner sets in /admin › Announcements (CAN-SPAM asks
     for one in commercial mail).
   - The link in the mail asks before it unsubscribes: Settings shows an Unsubscribe button. The
     RFC 8058 POST stays one-click, since a mail program sends it only when the person asks.
   - Each mail carries RFC 8058 headers and the same link in its words.
   - Someone who turns news on after an announcement went out is not mailed that older one.
8. **The checks never reach a real person.** On a preview, or with ?tests=1, every announcement is a
   test one:
   - it reaches only the checks' own accounts at resend.dev;
   - it is never mailed;
   - it counts against that deployment's own daily limit and list.
   - The cron on any host but brickworks.diy (a preview, a machine's own server) sends only test
     ones and mails nobody; the site's own wait for the live cron.

**Not built, on purpose:**
- **Popups and full-screen posts.** They interrupt building.
- **Dynamic audiences.** They make "reached" a moving number.
- **Per-topic email lists.** There is one kind of news. Add topics if a second kind ever appears.

## The bar it is held to

These pass against `supabase/announce.sql` and `supabase/announce2.sql` in a Postgres of the
test's own:
- `tests/test_announce.py` and `tests/fixtures/announce/api_check.mjs`;
- the same SQL on the project, rolled back: `tools/announce_try.sql` and `tools/announce2_try.sql`
  with `tools/apply_sql.mjs --dry`;
- the review's `bench/results/anreview-2026-11-18/tools/attack.mjs --scale=50000` (50,000 accounts,
  one announcement to all): a person's rows under 3 ms, the console's list under 50 ms (anfix: 1.9
  ms and 2.3 ms, from 23-33 ms and 905 ms).

These pass in a real browser:
- `tools/web/announce_flow.mjs`;
- before the file is applied, with `node tools/web/relay_server.mjs PORT --hold=announce`
  (`tools/web/announce_stand_in.mjs`).

## After the review (`supabase/announce2.sql`)

The review (anreview, 2026-11-18) found these before anyone was reached; anfix fixed each:
- **A hidden notice drawn for a moment** on a second browser. The avatar's count (`feed_count`) now
  carries the ids of the notices the person hid, and the notice waits for it before drawing. No
  request is added.
- **Every person's row read by every list.** Who it reached was an array on the announcement,
  read whole by each Notifications page and the console. It is now `announcement_to`, with
  `announcement_counts` for the console. `recipients` is no longer written: new sends keep it
  empty, and old ones keep what they had, copied once into `announcement_to`. Nothing is dropped.
- **No daily most for news mail**, no stop on Resend's quota, and a pace that shared the second
  with sign-in codes: see 7 above.
- **A run that found a send already gone** counted as a failed cron. It is now skipped, with no
  audit note.
- **A preview's cron could mail the site's own announcements.** Off brickworks.diy it sends only
  test ones and mails nobody.
- **Barred accounts** were in audiences and mail. They no longer are.
- **The mail link unsubscribed on a visit**, as link scanners make. It now asks.
- **The unsubscribe token was signed with the database key.** It is now signed with its own
  `NEWS_UNSUB_SECRET`; tokens already sent still verify with the old key. The lead sets
  `NEWS_UNSUB_SECRET` in Vercel (production and preview) when this ships. Without it, no news
  mail goes out, and the console says what is missing.
- **No postal address** in the mail: the owner can now set one.

`announce2.sql` only adds tables and replaces functions with the same arguments; applying it before
or after the site's deploy is safe in either order (the server reads its new answers as absent until
it is applied).
