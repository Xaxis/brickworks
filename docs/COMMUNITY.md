# Community rules, and where each is enforced

brickworks.diy has share links, a gallery, profiles, likes, remixes,
collections, comments, photos of real builds, follows and a feed,
designers' pages, and a monthly challenge. These
are the ground rules it stands on (2026-10-18), and the code that keeps each.
The pages people read are `web/terms.html` (/terms) and
`web/guidelines.html` (/guidelines); every site page's footer links both,
and the app's Share panel says "Publishing means you agree to the
guidelines" beside Publish (`src/ui/share_panel.gd`). Not legal advice:
the pages say what the site does.

## For the owner to fill in

- `web/terms.html` `#operator`: the operator's legal name and a contact
  address (marked "To be filled in by the site’s owner").
- `web/takedown.html` `#agent`: the DMCA designated agent's name, postal
  address, phone and email, once registered at
  https://www.copyright.gov/dmca-directory/ (nothing is registered by the
  code).
- `supabase/trust.sql` is applied at a release, by the owner
  (`tools/apply_sql.mjs supabase/trust.sql`); until then nobody is asked
  their age, nothing new is refused, and no report is emailed.
- `supabase/comments.sql` after it, before the code that reads it is
  deployed (`api/admin.js` reads `reports.comment`); until then the model
  pages and the app show no comments and say they are not open yet.
- `supabase/follows.sql` after the rest (it reads trust, comments, builds
  and versions); until then a profile shows no Follow and no counts, /feed
  says it is not open yet, Account has no count, and the day's email is
  of comments only.
- `supabase/discovery.sql` after builds.sql and tested.sql (it reads
  `model_builds` and the Tested mark); until then Sort › Top builds lists
  newest first, the gallery's front has no pick (Small builds is there, the
  newest first), the admin page says This week's pick is not open yet, and
  a signed-in person's gallery has no shares and no You can build now. Then
  once, `node --env-file=.env tools/web/needs_backfill.mjs` (`--dry` first
  reads only), which counts what the models published before it need; a
  model published after is counted as it is published.
- `supabase/designers.sql` after discovery.sql (it reads the tables of
  builds, comments, tested, trust and follows); until then a profile is as
  before (no tiles, its models newest first), and the designer's own
  numbers say "not open on Brickworks yet". Opens are counted by the day
  from the moment it is applied.
- `supabase/challenges.sql` after designers.sql (it reads `model_needs`,
  the Tested mark, `gallery_shows`, `directory_card` and trust's and
  moderation's rules); until then /challenge says there is no challenge,
  the admin page says Challenges are not open yet, a model's page offers no
  entry, and no card says it won.

## The rules

| Rule | Said on | Enforced by |
|---|---|---|
| Credit: a remix keeps its link to what it came from | /guidelines | `api/share.js` keeps `remixed_from` across republishes; the model's page names it |
| The three licences, and what a remix may be | /guidelines, Share panel | `api/share.js`: a remix of CC BY-SA is CC BY-SA (422), a remix of all-rights-reserved is not listed (422) |
| No copying passed off as yours | /guidelines, /takedown | Report and takedown → admin page Take out: unlisted, barred, and the file's fingerprint barred at every link (`api/admin.js`, `barred_models`) |
| No personal photos of children; no personal information | /guidelines, the photo form ("Photos show the build, not people") | Reported and taken out by the owner (admin page), a build photo with its file. A photo's metadata (where, when, what phone) is never kept: `api/_photo.js`. Faces are not detected automatically |
| AI designer and Brickify designs labelled | /guidelines | The builder's to say, by tag (`ai-designed`, `brickify`) and in About it. Not yet marked by the app itself |
| LEGO® only as an adjective, with the disclaimer | /guidelines, /terms, every footer | `tests/test_trademarks.py` for the site's own words; names people type checked by `api/_names.js` |
| What gets a model or an account taken out | /guidelines | The owner, on the admin page: Take out, Take out the account (`api/admin.js`) |

## The age question

Asked once of every account, at its first sign-in after `trust.sql`: on the
site by `web/account.js` (after a sign-in, and on /profile), in the app by
`src/ui/sign_in_gate.gd` (the sign-in screen stays up for it after a code
is typed; a returning visitor is let in at once, and an account from before
the question has the screen back up to ask it, once). Neutral, as
the FTC's COPPA guidance asks: the month and year of birth, the same for
everyone, and nothing about 13 until after the answer. `POST
/api/account?op=age` turns the date into 13-or-over (`api/_trust.js`,
a birthday this month counts as had) and lets the date go; the database
keeps `profiles.over_13` and `profiles.age_asked_at` only. An answer stands:
a second try changes nothing. An answer under 13 is asked again a year
later, so somebody who has turned 13 can say so.

Under 13, an account builds, keeps its models and shares them by link like
anyone. It may not have, and the server refuses in words (422) before the
database refuses too:

| Public thing | API | Database |
|---|---|---|
| A model listed in the gallery | `api/share.js` publish | trigger `trust_guard_model` on `shared_models` |
| A name credited on a link | `api/share.js` publish | the same trigger |
| A profile: handle, name, bio | `api/people.js` `?op=profile` | trigger `trust_guard_person` on `people` |
| A public collection | `api/people.js` `?op=collection` | trigger `trust_guard_collection` on `model_collections` |
| A comment | `api/_comments.js` (`comment_trouble`) | trigger `comments_guard` on `model_comments` |
| A photo of a real build | `api/people.js` `?op=photo_start` and `?op=photo` | trigger `build_photos_guard` on `build_photos` (`supabase/builds.sql`) |
| Following somebody (a follow is counted in public) | `api/people.js` `?op=follow` (`api/_follows.js`) | trigger `follows_guard` on `follows` (`supabase/follows.sql`) |
| Entering a challenge, or voting in one | `api/people.js` `?op=enter`, `?op=vote` (`api/_challenges.js`) | `challenge_enter`, `challenge_vote` (`supabase/challenges.sql`), the only way into their tables |

Something new in public needs the question answered 13 or over: an account
not asked yet is told to answer it first. What an account had in public
before it answered stays until it answers; answered under 13, its listed
models leave the gallery and its public collections go private
(`answer_age`), nothing is deleted, and a profile it had is no longer shown
(`shown_publicly`, `profile_page`, `directory_card`).

## Comments

On a model's page (`/m/<id>`, drawn by `web/model-page.js` from
`GET /api/people?op=comments`) and on each step in the viewer and the step
player (`src/ui/step_comments.gd`), since 2026-10-18
(`supabase/comments.sql`, `api/_comments.js`).

**Who may write.** A signed-in account that answered the age question 13
or over (`trust_may_go_public`), not taken out of the gallery
(`is_barred`), on a published model whose owner has not turned comments
off, which is not taken out itself, and whose owner is not under 13:
strangers do not write to a child, and such a model says only that
comments are off. Anybody reads them, signed in or not. Each refusal is in
words, said where the box would be: no account ("Sign in to add a
comment…", with a way to), not asked yet, under 13 ("Comments are for
people 13 and over, so you can read them here but not add one…"), barred,
comments off.

**What.** 1 to 1,000 characters of plain text, on the model or on one step
of the version shown, which it then names ("on step 7 of version 2", and
", an older version" when a newer one is out). Line ends are kept; nothing
else unprintable. A link is shown as the words it is, never as a link.
Words the gallery does not show are refused (`api/_names.js`, the abuse
list: a comment may name a set or a film, as a description may). A
comment on a step of an older version shows on that step of a newer one
only while no version between changed that step or one before it
(`first_changed`), as a builder's place is kept.

**Limits** (`may_act`, counted in the database): 10 comments an hour and
50 a day for one account; 20 edits an hour, 100 a day; a model's owner
hides or shows 60 an hour, 300 a day, and turns comments on or off 30 an
hour, 100 a day.

**Moderation.** Its author may remove theirs. The model's owner may hide a
comment on their model (it stays, seen only by them and its author, marked)
or show it again, and turn comments off on it, or on again; what was said
stays. Anybody may report a comment with Report it beside it, through the
same report as anything else (`reports.comment`, with its model): it
reaches the owner's email within the hour, named as a comment with its
first words and a link to it. The admin page lists the newest comments and
every one reported, and Remove takes one off every page for good and
settles its reports; taking a model or an account out settles what was
reported about the model, not about the comments on it. Nothing is
deleted: removed and hidden are times kept on the row. A comment by an
account taken out of the gallery, or by one under 13, is not shown.

**Telling a model's owner.** At most one email a day, from the sign-in
codes' sender, of new comments on their models: off by default, because the
trust unit kept no email preferences, until the owner turns it on on
/profile (`mail_choices`). The first comment after a quiet day goes at
once; the rest wait for the next day's, sent by a comment or by the hourly
knock (`POST /api/people?op=digest`). A test account's is a dry run,
rendered and recorded in `comment_digests` (state `dry`) and never sent.
`COMMENT_MAIL=off` sends nothing to anybody.

## Follows and the feed

`supabase/follows.sql` (2026-10-18), the rules in `api/_follows.js`, the
button in `web/follow.js`, the feed in `web/feed.html` and `web/feed.js`.

**Who may follow, and whom.** A signed-in account that said it is 13 or
over (`trust_may_go_public`) and was not taken out of the gallery
(`is_barred`) may follow somebody whose profile is shown in public (13 or
over, not taken out), not themselves. A follow is counted in public, so an
account under 13, or one not asked yet, may not follow at all: refused in
words beside the button ("Following people is for people 13 and over…",
422) and by the trigger. At most 60 follows an hour and 300 a day
(`may_act`, `follow`); letting somebody go is not counted. Follow is on
every profile (`/u/<handle>`) and beside "Shared by" on a model's page.

**Following is not a way to reach anybody.** Nobody is told they were
followed, no feed row says who followed whom, and there is no message of
any kind. What a follow does is put what that person shares in the
follower's own feed.

**Who sees whom: counts, not lists.** A profile shows "N followers" and
"following N", counted only between accounts shown in public. Nobody's
followers are ever listed, to anybody, the person themselves included.
Whom somebody follows is listed on their profile only when they chose to
show it (/profile, "Show on my profile whom I follow", off until ticked;
`feed_marks.shows_follows`), and then only people who are themselves shown
in public. The tables are the server's alone, not even the service role
reads them directly: only the functions answer, and only as counts or that
chosen list.

**The feed** (`/feed`, signed in): newest first, the last 90 days, each row
a link to the thing:

| Row | When | Not shown |
|---|---|---|
| A new model | listed in the gallery by somebody you follow, and credited to them | one shared by link, or without their name (a model shared without a name is tied to nobody, so a follow never reveals it); a remix of yours, which is said once, as a remix |
| A new version | of one of those, published after it was listed | |
| A photo of a real build | on your model, or by somebody you follow of a model in the gallery | hidden by the model's owner, taken out, on a model taken out |
| A comment | on your model, in this life of its link | hidden by you, removed |
| A remix | of your model, listed in the gallery; whose, only when credited | |
| An entry in a challenge | a model in the gallery, credited to somebody you follow, entered in a challenge ("… entered “…” in the challenge “…”, built by hand"; `supabase/challenges.sql`) | one in a test challenge, but in a test account's feed |

Nothing by an account taken out or under 13, and a test account's models
only in a test account's feed. Built from the tables that hold each thing
(`feed_rows`), not copied into a feed table: read in 3 to 5 ms on the
project's own data in the dry run.

**The count on Account.** The site's header (every page, and on Menu at a
phone's width) and the app's Account (the bar, and a line in its panel
with Open your feed) show how many rows came since the account last opened
its feed, at most 99 (`feed_count`); it leads to /feed while there is
something. Opening the feed (its first page) marks it seen and the count
clears; the rows that came since the last opening are marked New. The app
asks when somebody signs in, when Account opens, when the window comes back
to the front, and every five minutes.

**In the day's email.** The comments' email (below, at most one a day)
can tell of new models, new versions, photos and remixes too, one choice
each on /profile, every one off until ticked (`mail_choices.models`,
`versions`, `photos`, `remixes`). It tells what came since the last email
that went, or since the choice was made; a test account's is a dry run.

## Discovery: a gallery that rewards designs that build

`supabase/discovery.sql` (2026-10-19), the weights in `api/_directory.js`
(`SCORE`), the front's shelves in `web/gallery.js`, the owner's choice in
`api/admin.js` and `web/admin.js`, what models need and people own in
`api/_owned.js`.

**Top builds.** A sort beside Most built, by a score worked out in the
database so the gallery pages by it (`gallery_score`): a build finished
counts 3, a remix 2, the Tested mark 5. Views count for nothing, so a
model is not lifted by being looked at; ties go to more builds, then the
newest. The page says so under Sort while it is chosen. A build is the
device count builds.sql keeps (once per device, never a robot's), a remix
is one published from it, and the mark is its newest version's.

**This week's pick**, at the top of the gallery's front (nothing searched
or filtered), worked out from the past seven days: the best score of the
week, counting the builds finished and the remixes listed in those seven
days, and the Tested mark (`gallery_week`). A model is a candidate only
when something in the week says it builds: a build finished, a remix
listed, or it was listed that week and is Tested, so a quiet week has no
pick rather than last month's. Its card says why ("Built twice this
week", "New this week, and Tested"). The site's owner can choose another
on `/admin` (Make it the pick, beside any model in the gallery or among
the week's best five) for seven days, and End it to go back to the one
worked out; the newest choice still in the gallery wins, and its card
says "Chosen by Brickworks". A choice is kept in `gallery_picks`, which
no key reads directly. A test account's model is never a visitor's pick.

**Small builds**: a shelf on the front of the gallery's own Small size,
under 200 parts, by Top builds, with See every small build
(`/gallery?size=small&sort=top`) when there are more than eight. Why 200
and not 150: on 2026-10-19 the gallery's seven models were 187, 350, 494,
774, 1,037, 2,438 and 9,541 parts. At 150 the shelf would be empty; the one
small model sits alone below a gap to 350, and the Size filter already
calls under 200 Small, so the shelf and the filter mean one thing.

**Build with what I own.** For a signed-in person with a collection
(`/api/collection`, the app's Build › My collection…), every card in the
gallery says how much of the model they own already ("✓ You have every
part", "You have 1 of its 3 parts · 33%"), Sort has Parts I own (the
largest share first, ties to more parts held), and the front has You can
build now: the models every part of which is in their collection, by Top
builds. Counted by part and colour, as the app's one-model check counts
them (`src/collection/collection.gd`): a part by the number it means today
(LDraw's moves), a colour by the one a shop files it under (Rubber Black
is Black), another moulding of a part standing in for it (3794a for
3794b), their sets through the sets' inventories (the app's own
shards), spares when they said they kept them; a part nobody can own (a
primitive drawn into a model, a sub-model a file names and does not
carry) is left out, and a flexible part laid as segments too. Both sides
are counted once and kept, so the gallery is one join in the database: a
model's needs as it is published (`model_needs`), a person's pool the
first time the gallery is asked for it after their collection changed
(`collection_pools`). What a person owns is never shown to anybody else:
the shares are only ever asked with their own sign-in (`mine=1`), the
CDN never keeps such an answer, and the tables are read only through the
functions. What the app's own check does that this does not: a part in
another colour, or two smaller ones, offered as a swap, which the share
never counts; and the app lets a lettered moulding stand in for the plain
number but not the plain number for a lettered one, where the gallery
lets either stand in for the other. A set no inventory has is said on the shelf, and
its parts are not counted.

**What it costs.** In the dry run (`tools/discovery_try.sql`), on a
gallery of 5,000 listed models with 20,000 builds over 30 days, 1,000
remixes and 500 Tested, made and rolled back inside it: Top builds 161 ms
for its first page and 173 ms for page 81; Most built and newest 50 ms;
the small shelf 19 ms; the week's best ten 103 ms; the pick 101 ms. On
the project's own seven models: 4 to 7 ms, 4 to 6 ms, 2 ms. Every
question builds.sql's list knew is answered the same, card for card and
in order (16 on the project's models, 6 on the big gallery, deep pages
among them). With every model of
that gallery needing 60 lots (300,000 rows) and a collection of 2,000,
5,000 and 20,000 lots (the most a collection holds), best of three in
each of two runs on the shared database: Parts I own 123 to 132, 158 to
160 and 343 to 367 ms for its first page; You can build now 82 to 141, 120
to 189 and 322 to 420 ms; any other sort with each card's share 80 to 88
ms whatever the collection's size (a page's shares are counted after the
page is cut); keeping the pool 33 to 35, 88 to 91 and 364 to 543 ms, once
per change. The cost is the join of the whole pool with every model's
needs; keeping each person's shares as the pool is kept is the next step
if a gallery of thousands makes it slow. The list's deep pages
were made cheaper too: builds.sql's directory_models made a card for every
model a page skipped (page 81 of Top builds took 665 ms that way); the
page is now cut before its cards are made. The CDN keeps both answers 30
seconds, as the list.

## Designers: what a designer's models earned

`supabase/designers.sql` (2026-10-19), the API in `api/_designers.js`, the
page in `api/people.js` (`profilePage`, `earnedHtml`, `cardHtml` with
`earned`), the designer's own numbers in `web/designs.js`.

**A designer's page.** A profile with a model in the gallery
(`/u/<handle>`) is a designer's: it says Designer, not Builder, and leads
with what those models earned, as tiles: builds finished and remixes first
(marked, as the gallery's Top builds weighs them), then Tested, comments,
models in the gallery and followers. Each number is the sum of what the
cards below it say, so the page never claims more than its models show:

| Number | Counted as |
|---|---|
| Builds finished | `model_stats.builds`: once per device that reached the last step, never a robot's, as every card and Top builds count them |
| Remixes | published remixes of it, by link or listed, as the card counts them |
| Tested | its newest version marked Tested |
| Comments | on its page in this life of its link, shown to a visitor (not hidden, not removed, by an account shown in public), and not the designer's own: an answer to a comment is not one earned (`designer_said`) |
| Models | listed and credited, as the profile lists them |

The models follow by Top builds, the most built first, and each card says
its own "3 built · 1 remix · 1 comment", then likes, and its Tested mark;
never its views. Under the tiles: the model to start with, the first by Top
builds once somebody built it ("Start with their most built: …, 3 builds
finished, Tested", with Build it, which opens it in the viewer), and the
photos other people posted of their builds of these models (Built by
others), each saying whose build it is. A builder's own photos of their own
models are not among them. Likes and whom they follow stay as a line under
the tiles. A profile with nothing in the gallery is as before.

What a builder can do there (follow, report) is unchanged. A build is
counted by device and nobody's account is kept with it, so a designer's
own finish on their own device counts once, as it does everywhere else.

**For the designer alone.** Signed in, on their own page (How your models
are doing, under the follow line) and on Account (`/profile`, Your models,
as a designer): every model they published, in the gallery or by link,
credited or not, each with the last 30 days and in all since it was
shared:

- opens: visitors who opened its page, each once a day, never a robot
  (`count_view`'s count, kept by the day in `model_opens`);
- builds finished, remixes and comments, counted as on the page above;
- who built it: the photos people posted of their builds ("I built it"),
  up to six, each with its builder's name and a link to their profile.

The busiest first (opens, then builds). Opens are kept by the day from the
day the file is applied (with what `model_views` still held, today's and
yesterday's); until 30 days have passed the panel says from when, and "in
all" is the count since the model was shared.

**Nobody else sees it, and no cache keeps it.** The page the CDN keeps
(`/u/<handle>`, 30 seconds) is the same bytes for everybody and carries none
of it: `#designs-mine` is empty and hidden, and `web/designs.js` fills it
only when `GET /api/people?op=designs&handle=<the page's>` answers that the
page is the caller's own (asked by anybody else it answers `{"mine":
false}` and nothing more). The account asked for is the one the sign-in
proves; nothing in the request can name another. Every answer, a refusal
included, is `Cache-Control: private, no-store`. In the database the
numbers come only from `designer_mine`, granted to the service role alone;
`model_opens` is read by no key, the service role's included.

**What it costs.** In the dry run (`tools/designers_try.sql`), on the live
project's own data, the owner with the most models (seven): the page 1.5
to 3.2 ms and the designer's own numbers 3.9 to 6.1 ms, in two runs. On a
designer made inside it, 303 models with 30 days of opens on each (9,000
rows), 3,000 builds, 600 comments and 300 photos by twenty people and 100
remixes, best of three: the page 21 to 31 ms and their own numbers 46 to
59 ms (185 KB of JSON). Who is shown
in public is asked once a person, not once a comment or photo: asked of
every one, the two took 110 to 250 ms.
## Play: what moves, on its link and on its card

`supabase/play.sql` (2026-10-19), the words in `src/assembly/playable.gd`
and `api/_directory.js` (`MOVES`), the card in `web/gallery.js`, the
viewer's play in `src/ui/share_view.gd` and `src/main.gd`
(docs/MECHANISMS.md §21).

Nobody can play with a model on Rebrickable. On its Brickworks link
anybody can take hold of what moves and move it as it was built: steer
the wheels by the steering wheel, swing the boom, open the doors, turn
the gearbox by its input, on the editor's own joints, stops and
couplings. Nothing is kept: the link's model never changes, and Reset
puts it back.

**What moves, on the card.** The app works out what moves as the model
is published, from the joints a drag would use (`Playable.read`), and
sends the words with it: steering, turntable, boom, doors, gears,
pneumatics, actuator, rack. api/share.js takes those and no others, each
once, and keeps them with the model's row (`shared_models.moves`). The
gallery's card says them ("Moves: steering, boom"), and so does the
list a session reads (`gallery`, below). A model published before, or
from an app before this, has none until it is published again.

**Technic or mechanism** now takes a model whose moves name a mechanism
(any word but doors, `moves_mechanism`) as well as one whose parts are
Technic (`technic`, as before). A house whose doors open is not a
mechanism; a small racer with a working steering of few Technic parts
is.

**For a session.** The gallery tool (`src/net/gallery_tool.gd`) offers the
gallery's own sorts (Top builds and Most built; Parts I own only with the
person's own sign-in, `mine=1`, and refused with what to do when nobody is
signed in), the front (`shelves=true`: this week's pick and why, the small
builds, and what the person can build now), and says on each model how
many built it, what moves in it and whether it is Tested.

**What it costs.** In the dry run (`tools/play_try.sql`, on the live
project inside a transaction rolled back): the column added to every row
as an empty list (8 models), a word the app does not say and nine words
refused, the cards saying what moves, Technic or mechanism finding the
racer by its steering and the crane by its parts but not the house by
its doors, a visitor's list of test models empty, the functions the
service role's alone; Technic or mechanism's first page 4.2 ms.

## Challenges: one a month, with rules the site checks

`supabase/challenges.sql` (2026-10-19), the words in `api/_challenges.js`,
the owner's form in `api/admin.js` and `web/admin.js`, the page in
`web/challenge.html` and `web/challenge.js`, the entry on a model's page in
`web/model-page.js`.

**Setting one.** The site's owner, on `/admin` (This month's challenge): a
title (80 characters), a brief (600), the first and the last day (date
inputs; whole days in UTC, the last included, at most 63), and up to three
rules, each a tick: at most N parts; only the parts of one official set,
by its number (6075 is 6075-1), its inventory read as a collection's sets
are (`api/_owned.js`, its spares too, since they come in the box) and kept
with the challenge, spelled as a model's needs are; and marked Tested. One
at a time: another with a day of these is refused, naming it ("One at a
time: … has a day of these"), and End it now closes one today.

**Entering.** On a model's page its designer, signed in, has "Enter this
month's challenge" under Like and Favourite, and nobody else is told
anything (`?op=challenge_entry` answers `{"mine": false}`). It opens a
dialog with the rules and a choice, By hand or With the assistant: the two
are shown and judged apart. The database checks every rule on the model as
it is stored (`challenge_check`): its parts as its card counts them, what it
needs (`model_needs`, counted when it was shared) part by part and colour by
colour against the set's, and its newest version's Tested mark. A refusal
names each rule it breaks, in words: "It has 40 parts: this challenge
allows at most 30", "1 of its parts is not in set 6075-2 (Castle), or not
as many: 3004 in Red (it needs 12, the set has 0)", "Its newest version is
not marked Tested". Only a model in the gallery with its designer's name on
it (one shared without a name is tied to nobody), at most three of a
designer's, each once. Take it out, on its page, takes the entry and its
votes back while the challenge runs.

**Voting.** On `/challenge`, each entry is the gallery's card with Vote for
it (signed out, it asks to sign in). One vote in each group, never for your
own, and a vote stands. The votes are not shown while it runs, so nobody
votes for what is winning; they are counted when it ends. An entry whose
newer version breaks a rule says "No longer keeps the rules" and is not
voted for, nor counted.

**Winning.** When it ends (its last day passes, or the owner ends it), the
first time anything asks for it its winners are kept (`challenge_settle`,
`challenge_winners`), so a winner stays one whatever comes after: in each
group the entry with the most votes still counted (its model in the
gallery, its designer shown in public, keeping the rules; a vote by an
account taken out or under 13 not counted), a tie to the one entered
first, and none with no vote at all. `/challenge` then shows the winners
first and every entry's votes; the winner's designer page has Challenges
won (`api/people.js`, each with its model, the challenge and its votes),
and the model's card there and in the gallery says "Won “…”, by hand"
(`challenge_wins`, asked for a page of cards at once).

**Who.** Entering and voting are for accounts that said they are 13 or over
and were not taken out (`trust_may_go_public`, `is_barred`), refused in
words beside the button or in the dialog ("Challenges are for people 13 and
over…", "Voting is for people 13 and over…"). Nothing about a person is
shown but what their card already shows; whom somebody voted for is told
only to them (`challenge_mine`, with their own sign-in, `private,
no-store`). The tables are read and written only through the functions,
each granted to the service role alone.

**The gallery's front** says it in one line under its heading ("This
month's challenge: …, open until 31 October. Enter a model of yours, or
vote."), or the next one, from `?op=shelves`. **The feed** tells whoever
follows a designer when they enter ("Ada entered “The house” in the
challenge “…”, built by hand"), a link to the model: `challenges.sql`
replaces follows.sql's `feed_rows` with one kind more and every other row
as it was (`tools/sql_compare.mjs` reads every feed before and after). The
Account count counts it; the daily email does not tell of it.

**Tests.** A test account's models enter only a test challenge, and it
votes only in one: the flows' own, set on `/admin?tests=1` and shown only
to a page asked with `tests=1`, one at a time among themselves.

**What it costs.** In the dry run (`tools/challenges_try.sql`), on a month
of 600 entries by 300 designers, each model needing 40 lots against a set
of 400, and 600 votes, best of three in each of two runs on the shared
database: the page 330 to 540 ms (each entry's card made and its rules
checked again), one entry's check 1.8 ms, a vote 1.5 to 3.9 ms, whom one
voted for 0.5 ms, an entry 1.5 ms, settling the month 130 to 355 ms, once.
The CDN keeps a visitor's page 30 seconds; a signed-in one asks each time,
so a month of hundreds of entries is where keeping each entry's check, as
it is entered, is the next step.

## Reports reaching the owner

A report (`api/people.js` `?op=report`, from the Report button or
/takedown) is emailed to the owner (`MASTER_EMAIL`, the address the admin
page lets in) from the sign-in codes' sender (Resend, `EMAIL_FROM`) within
the hour, and at most one email an hour of the clock: the first report in a
quiet hour goes at once; later ones that hour wait for the next, sent by
the next report or by the database's hourly knock (pg_cron at a minute past
each hour, `POST /api/people?op=digest`, which can send nothing but that).
Each report in the email links its row on the admin page
(`/admin#report-<id>`, marked and scrolled to). The reporter and their
contact stay on the admin page. `supabase/trust.sql`
(`claim_report_digest`, `finish_report_digest`, `report_digests`) keeps
the count; a digest that fails is retried in the next.

A report about a test account's model, profile or collection (a Resend
test address), or made by one, is never emailed: it is in its own stream,
rendered and recorded in `report_digests` (state `dry`) for the flows to
read. `REPORT_MAIL=off` on a server sends nothing to anybody.

## Real builds: builds finished, and photos of them

`supabase/builds.sql` (2026-10-18), applied after `trust.sql` and
`tested.sql`; the rules in `api/_builds.js`, the photos made safe in
`api/_photo.js`.

**A build finished.** Reaching a model's last step in the step player or
the viewer's timeline, from the step before (not a jump to the end, not
opening on the finished model), counts the model as built, once per device
(`src/main.gd`, `SharedModels.built`). No account, nothing about anybody:
the device makes itself a random key and keeps it (localStorage on the web,
`user://built_once.cfg` on the desktop), and the server keeps an HMAC of
the model and that key (`model_builds`), never the key. Robots are not
counted, as views are not: a browser's own request from the site's page, or
the desktop app by its user agent. "N built" is on the model's page, its
gallery card and the viewer; the gallery sorts by Most built.

**Photos: who may post.** A signed-in account that said it is 13 or over
(`trust_may_go_public`; one not asked yet is asked first), on a published
model that was not taken out. At most three photos an account on a model
(one taken out does not count), and at most 12 an hour and 40 a day
(`may_act`, `photo`). A line of text with it, optional, at most 140
characters, checked as names are (`api/_names.js`). The form says, in a
line, "Photos show the build, not people".

**Photos: what is kept.** JPEG, PNG or WebP, at most 8 MB, at most 40
megapixels; the phone sends it straight to the `build-photo-uploads`
bucket, to a path of the account's own the server signed for that one
upload (a function takes no body over 4.5 MB). The server then reads it and
decodes it to its pixels: JPEG with jpeg-js (`api/_jpeg.js`), PNG with its
own decoder over Node's zlib, every chunk's CRC checked, WebP with
libwebp in WebAssembly (`api/_webp.js`). A file that does not decode
completely is not a picture, and is refused. From the pixels alone it makes
a new JPEG, at most 1,600 pixels on its long side, turned the way the phone
was held (the one thing read from Exif, Orientation): the new file has its
JFIF header and the picture and nothing else, so no GPS, no time, no
phone, no comment, no thumbnail, no XMP survives (the encoder writes no
other segment). That is kept as `build-photos/<photo id>.jpg`; the original
is deleted at once whatever came of it, and the daily sweep deletes any
original left an hour old. Neither bucket is readable by any key a page
has: a photo is served by `api/people.js ?op=photo_file` only while it may
be shown.

**Photos: where they are shown.** The model's page, as a strip of builds
under "Built by people", and the builder's profile under "Built" (photos
on models in the gallery). Not shown: a photo its model's owner hid, one
the site's owner took out, one on a model taken down or taken out, one by
an account taken out or under 13.

**Photos: moderation.** The model's owner hides a photo on their own model
(Hide on it; Show it again among the hidden, which only they see). Anyone
can report a photo with its own Report it (the report flow above, target
`photo`): the report is about the photo's model as far as `reports`'
check goes, and `report_photos` says which photo; it goes in the hourly
email, named as a photo, and in the poster's dry-run stream when that is
a test account. The admin page shows the photo, hidden or not, and Take
the photo out marks it removed, deletes its file from storage (that one
file, nothing else), and settles its reports.

**The daily email to a designer** is the comments unit's (at most one a
day, to an owner who chose it: `claim_comment_digest`). Since
`supabase/follows.sql` it is claimed when a comment or a chosen feed row
waits, and new photos of their models are in it when they chose photos
(the feed above). "Built N times since yesterday" is not in it yet.

## Takedowns

/takedown sends a claim as a report, with the statements a copyright
notice needs for a copy of somebody's work (a signature, good faith,
accuracy on pain of perjury); a counter-notice for a model taken out by
mistake (`counter: true`, which may name a model already barred; its note
says "Counter-notice"), passed on by the owner to whoever asked; and a
marked place for the DMCA agent. Putting a model back after a
counter-notice is by hand for now (`shared_models.barred`).

## Proving it

- `tools/trust_trial.sql`, run inside `tools/apply_sql.mjs --dry` with
  `supabase/trust.sql`: every refusal and permission, the answer that
  stands, what goes private, the streams and the one-an-hour limit, and the
  knock, all rolled back.
- `tools/web/age_flow.mjs` and `tools/web/digest_flow.mjs`, in a real
  browser against `tools/web/relay_server.mjs --trust-stand-in` (which
  answers trust.sql's functions in memory until the file is applied;
  `BW_STAND_IN` lets `session.mjs` answer for test accounts) or a
  deployment once it is.
- `tools/builds_try.sql`, run inside `tools/apply_sql.mjs --dry` after
  `trust.sql`, `tested.sql` and `builds.sql`: a finish once per device,
  the card's builds and Most built, the three-photo limit, under 13 and
  not asked refused, a removed photo, a report about a photo and its
  stream, the buckets, all rolled back.
- `tools/web/builds_flow.mjs`, against `tools/web/relay_server.mjs
  --hold=model_builds,build_photos,report_photos --trust-stand-in`: a
  finish on a phone counted once, a photo with GPS in it given back with
  no metadata (read from its bytes), under 13 refused, the owner hiding
  it, a report reaching the admin page and the file deleted.
- `tools/comments_trial.sql`, run inside a dry run of `trust.sql` and
  `comments.sql` together: every refusal (no account, under 13, not asked,
  barred, a child's model, comments off, the limit, whatever writes), the
  owner's hide and off, the author's edit and removal, a report's stream
  and digest, the admin's removal, and the day's one email, all rolled
  back.
- `tools/web/comments_flow.mjs` against `relay_server.mjs --hold=model_comments
  --trust-stand-in` (`tools/web/comments_stand_in.mjs` answers comments.sql's
  functions and `reports.comment` in memory): the site and the app on a
  phone-sized page, a visitor, an account under 13, the owner, a report
  reaching the admin page.
- `tools/follows_try.sql`, run inside `tools/apply_sql.mjs --dry` with
  `supabase/follows.sql` after the live files: who may follow and be
  followed (yourself, under 13, not asked, no profile, nobody signed in,
  written directly), counts as a visitor and as each, the list only once
  chosen, the feed's rows and what each leaves out, paging, the count
  before and after opening, the limit, the email's choices and its feed
  told once, an account taken out, the grants, and how long a feed takes,
  all rolled back.
- `tools/discovery_try.sql`, run inside `tools/apply_sql.mjs --dry` with
  `supabase/discovery.sql` after the live files: the score's weights, Top
  builds' order and its paging (two at a time, nothing twice, and three
  pages of 25 the same as one list on the big gallery), Most built and
  newest as before, small builds, a visitor's list without test models,
  the week's candidates and what is not one, the pick worked out, chosen,
  passed over when it leaves the gallery, ended and run out, refusals (not
  in the gallery, nobody's, 0 or 32 days, 40 written directly), an account
  taken out, the grants, and the timings above, all rolled back.
  `tests/test_discovery.py` holds the page's weights to the SQL's and the
  stand-in's, discovery.sql's directory_models to every filter and sort of
  builds.sql's, Parts I own to a collection's own sign-in, and the new
  tables to no key at all. `tools/web/owned_probe.mjs` checks the sums
  alone: a file's needs through its sub-models in the colour each is
  placed in, both sides spelled one way, the shard a set is in, a pool of
  sets and loose parts.
- `tools/web/discovery_flow.mjs` against `relay_server.mjs
  --hold=gallery_picks` (`tools/web/discovery_stand_in.mjs` answers
  discovery.sql's functions in memory over the live project's models and
  builds) or a deployment: four test models built and one Tested, Top
  builds' order on the list and the page, the front's pick and small
  builds signed out and signed in at 1280 and 390 px, the owner choosing
  the pick on /admin and ending it, a model by link only refused; and a
  collection with a real set in it: each card's share, Parts I own, You
  can build now at 1280 and 390 px, refused signed out, and nothing of it
  for somebody with no collection.
- `tools/designers_try.sql`, run inside `tools/apply_sql.mjs --dry` with
  `supabase/designers.sql` after the live files: `count_view` answering the
  same with the trigger and without it, opens by the day and the last 30
  (and 7) of them, a designer's page as anybody sees it with and without
  tests (models, builds, remixes, comments, Tested, photos by others) and
  each number the same as profile_page's and the sum of directory_models'
  cards, the comments the same as the model's page shows less the owner's,
  the designer's own numbers and nobody else's, days held to 1 to 90, an
  account taken out and one under 13, what model_views held counted in
  once, the grants, and the timings above, all rolled back.
  `tests/test_designers.py` holds the file to additions alone, the cards'
  definitions, the band's and the cards' order, the own numbers to the
  caller's sign-in and `private, no-store`, and the cached page to none
  of them.
- `tools/web/designers_flow.mjs` against `relay_server.mjs
  --hold=model_opens` (`tools/web/designers_stand_in.mjs` answers
  designers.sql's two functions over the live project's tables) or a
  deployment through its API alone: a designer's page signed out, signed
  in as somebody else and as the designer, at 1280 and 390 px; the tiles
  the sums of the cards, the castle first, no views; the designer's own
  numbers on their page and on Account and nobody else's; and every answer
  of them `private, no-store`, never from the CDN, the same address
  answering each their own.
- `tools/challenges_try.sql`, run inside `tools/apply_sql.mjs --dry` with
  `supabase/challenges.sql` after the live files: setting one (refused when
  past, a set with no parts, a day shared, too long), the rules checked
  (parts, a set lot short and by how many, Tested, a model never counted),
  every refusal to enter and to vote (somebody else's, by link, without a
  name, under 13, not asked, taken out, a test model in a challenge that
  is not one, three, twice, one's own, a breaking newer version), the page
  with no votes while it runs, taking back, the winners and a tie, the
  wins for a page and the cards, the grants, the timings above, and the
  gallery's own answers (`directory_models`, `designer_page`,
  `gallery_pick`) the same before and after, all rolled back.
  `tests/test_challenges.py` holds the file to additions alone, the rules to
  the database, the account to the sign-in, and the flow to the API.
- `tools/web/challenges_flow.mjs` against `relay_server.mjs
  --hold=challenges` (`tools/web/challenges_stand_in.mjs` holds the tables
  in memory and answers the functions over the live project's models) or a
  deployment through its API alone: the owner setting one on `/admin` with
  three rules, a second refused; entering from a model's page at 390 px,
  each broken rule named; `/challenge` signed out, signed in, under 13 and
  for a designer at 1280 and 390 px in light and dark; votes, their
  refusals, ending it on `/admin`, the winners, the designer page and the
  cards.
- `tools/web/follows_flow.mjs` against `relay_server.mjs
  --hold=follows,model_comments,build_photos,report_photos --trust-stand-in`
  (`tools/web/follows_stand_in.mjs` answers follows.sql's functions in
  memory, and the comments stand-in's day's email asks it for the feed): a
  follow from a profile, a new model and a new version in the feed, a
  comment and a photo counted on Account (the site at 1280 and 390 px, and
  the app) and cleared by opening the feed, an account under 13 refused,
  counts but no lists until chosen, and the email's dry run with the feed
  in it.
