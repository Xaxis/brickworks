# Community rules, and where each is enforced

brickworks.diy has share links, a gallery, profiles, likes, remixes,
collections and comments, and is about to have photos of real builds. These
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

## The rules

| Rule | Said on | Enforced by |
|---|---|---|
| Credit: a remix keeps its link to what it came from | /guidelines | `api/share.js` keeps `remixed_from` across republishes; the model's page names it |
| The three licences, and what a remix may be | /guidelines, Share panel | `api/share.js`: a remix of CC BY-SA is CC BY-SA (422), a remix of all-rights-reserved is not listed (422) |
| No copying passed off as yours | /guidelines, /takedown | Report and takedown → admin page Take out: unlisted, barred, and the file's fingerprint barred at every link (`api/admin.js`, `barred_models`) |
| No personal photos of children; no personal information | /guidelines | Reported and taken out by the owner (admin page). Not detected automatically |
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
| Build photos | (to come) | (to come: the same rule) |

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
