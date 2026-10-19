# Community rules, and where each is enforced

brickworks.diy has share links, a gallery, profiles, likes, remixes,
collections and photos of real builds, and is about to have comments. These
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
| A photo of a real build | `api/people.js` `?op=photo_start` and `?op=photo` | trigger `build_photos_guard` on `build_photos` (`supabase/builds.sql`) |
| Comments | (to come) | (to come: the same rule) |

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

**The daily email to a designer** about new builds of their models does
not exist yet: the comments unit has not made one. When it does, "built N
times since yesterday" and the new photos belong in it.

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
