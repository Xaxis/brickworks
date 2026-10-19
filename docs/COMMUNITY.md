# Community rules, and where each is enforced

brickworks.diy has share links, a gallery, profiles, likes, remixes and
collections, and is about to have comments and photos of real builds. These
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
`src/ui/sign_in_gate.gd` (the sign-in screen stays up for it). Neutral, as
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
| Comments and build photos | (to come) | (to come: the same rule) |

Something new in public needs the question answered 13 or over: an account
not asked yet is told to answer it first. What an account had in public
before it answered stays until it answers; answered under 13, its listed
models leave the gallery and its public collections go private
(`answer_age`), nothing is deleted, and a profile it had is no longer shown
(`shown_publicly`, `profile_page`, `directory_card`).

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
