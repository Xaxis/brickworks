#!/usr/bin/env bash
# preview_checks.sh ORIGIN WORKTREE TAG [NAME...] : chosen browser checks
# against a preview, two at a time; all of them when no names are given.
# Results: $S/TAG.out, one line a check; logs $S/TAG_NAME.log.
# Run from a copy: bash reads a script as it goes, so an edit made while a
# battery ran broke it at line 55 and the timing checks never ran.
if [ -z "${PC_COPY:-}" ]; then
  copy=$(mktemp "${TMPDIR:-/tmp}/preview_checks.XXXXXX.sh"); cp "$0" "$copy"
  RELEASE_HERE=$(cd "$(dirname "$0")" && pwd) PC_COPY=1 exec bash "$copy" "$@"
fi
P="$1"; WT="$2"; TAG="$3"; shift 3
cd "$WT" || exit 1
S=${RELEASE_OUT:-${TMPDIR:-/tmp}/brickworks-release}; mkdir -p "$S"
R=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
set -a; . "$R/.env"; set +a
H=~/.claude/claude-core/bin/heavy
export BW_BYPASS="$VERCEL_BYPASS"; B="--bypass=$VERCEL_BYPASS"
declare -A CMD=(
  [art]="tools/web/art_flow.mjs --url=$P/app $B --out=$S/${TAG}_art_web"
  [io]="tools/web/io_flow.mjs --url=$P/app $B --out=$S/${TAG}_io_web"
  [steps]="tools/web/steps_flow.mjs --url=$P/app $B --out=$S/${TAG}_steps_web"
  [floor]="tools/web/floor_flow.mjs --url=$P/app $B --out=$S/${TAG}_floor_web"
  [outline]="tools/web/outline_check.mjs --url=$P/app $B"
  [knowledge]="tools/web/knowledge_check.mjs --url=$P/app $B"
  [arrival]="tools/web/arrival_check.mjs --url=$P/app"
  [idle]="tools/web/idle_check.mjs --url=$P/app"
  [cursor]="tools/web/cursor_check.mjs --url=$P/app $B"
  [share_flow]="tools/web/share_flow.mjs --url=$P/app --out=$S/${TAG}_share_web"
  [versions]="tools/web/versions_flow.mjs --url=$P --out=$S/${TAG}_versions"
  [age]="tools/web/age_flow.mjs --url=$P --out=$S/${TAG}_age"
  # Sign in with orangecheck (2026-10-23), making nobody an orangecheck
  # account: the button and its words in the sign-in dialog at 390 and 1280,
  # light and dark; orangecheck's window opened from the click and closed,
  # a blocked one said in words; the site's pages able to hear the window
  # and /app still isolated; the server refusing nothing, junk and a GET.
  # A finished sign-in is tools/web/oc_live_flow.mjs, on brickworks.diy.
  [oc]="tools/web/oc_flow.mjs --url=$P --out=$S/${TAG}_oc"
  # local only: oc_live_flow.mjs. It signs in with a new throwaway Bitcoin
  # key through orangecheck's real window, which makes a real orangecheck
  # account each run (the lead purges them), and orangecheck vouches for
  # sessions only on the verified domain: it runs on brickworks.diy after a
  # release, never on a preview.
  # local only: oc_native_flow.mjs. The desktop's Sign in with orangecheck
  # (?op=native, 2026-10-24) on orangecheck's test stack: the app's probe,
  # a real Chromium and a throwaway orangecheck account, against this
  # machine's functions at the test project's development origin. orangecheck
  # offers apps' sign-in to test projects alone, and no deployment has a test
  # key, so it cannot run on a preview.
  # Comments and their replies (docs/SOCIAL.md U8): threads newest first,
  # the step pill into the viewer, the box for a visitor (sending signs in),
  # under 13 and comments off refused; a reply under its comment, its
  # writer told in Notifications, hidden with its comment, gone with it when
  # the site's owner removes it; then the app's step player. Throwaway
  # accounts, deleted after; before supabase/replies.sql, that nobody is
  # offered Reply (it reads which from the answer).
  [comments]="tools/web/comments_flow.mjs --url=$P --out=$S/${TAG}_comments"
  [tested]="tools/web/tested_flow.mjs --url=$P --out=$S/${TAG}_tested"
  [digest]="tools/web/digest_flow.mjs --url=$P --out=$S/${TAG}_digest"
  [builds]="tools/web/builds_flow.mjs --url=$P --out=$S/${TAG}_builds"
  [follows]="tools/web/follows_flow.mjs --url=$P --out=$S/${TAG}_follows"
  # Following a collection (docs/SOCIAL.md U11, supabase/collection_follows.sql):
  # Follow on its page and its count; a model put in it in the follower's
  # feed, counted on the avatar; the model's page "In 1 collection", linked
  # to a card with its cover; let go; under 13 refused in words; made
  # private, gone. Throwaway accounts, deleted after with their model and
  # collection.
  [list_follows]="tools/web/list_follows_flow.mjs --url=$P --out=$S/${TAG}_list_follows"
  # Notifications apart from the feed (docs/SOCIAL.md U7): your avatar in
  # the header with what is new, its menu (Menu at 390 px); a comment, a
  # photo and ten likes on a throwaway designer's model as one group with
  # its picture, the likes one row naming nobody; opened, the count gone;
  # a group read once opened, Mark all read; the feed apart; signed out at
  # both widths. Throwaway accounts, deleted after; before and after
  # supabase/notifications.sql (it reads which from the answer).
  [notifications]="tools/web/notifications_flow.mjs --url=$P --out=$S/${TAG}_notifications"
  # A feed you look at (docs/SOCIAL.md U9): /feed signed out and following
  # nobody shows Latest on Brickworks (the newest models as the gallery's
  # cards, every picture drawn) and designers to follow by Top builds; a
  # follow from the suggestions, and the next load is the designer's new
  # model, version and photo of a build as posts, each with its picture,
  # at 390 and 1280, light and dark; latest kept by the CDN, never with
  # tests=1. Throwaway accounts, deleted after with their models.
  [feed]="tools/web/feed_flow.mjs --url=$P --out=$S/${TAG}_feed"
  # First steps (docs/SOCIAL.md U10): a first visit at 390 and 1280 meets a
  # designer to follow; a first sign-in from the feed's dialog answers the
  # age question, makes a profile in First steps (the handle made from the
  # name), chooses a kind, follows the designer and lands on a filled feed;
  # one signed in elsewhere meets them on /profile and reaches a filled feed
  # in four taps. Throwaway accounts, deleted after with their model.
  [first_steps]="tools/web/first_steps_flow.mjs --url=$P --out=$S/${TAG}_first_steps"
  # Top builds, this week's pick and small builds, and the owner's choice of
  # the pick on /admin: API routes only, with the bypass (supabase/discovery.sql).
  [discovery]="tools/web/discovery_flow.mjs --url=$P --out=$S/${TAG}_discovery"
  # A designer's page (what their models earned) and their own numbers, for
  # them alone and never cached: API routes only, with the bypass
  # (supabase/designers.sql).
  [designers]="tools/web/designers_flow.mjs --url=$P --out=$S/${TAG}_designers"
  # The monthly challenge: set on /admin?tests=1 (a test one, which no
  # visitor sees), entered from a model's page with each broken rule named,
  # voted in its two groups, ended and won: API routes only, with the bypass
  # (supabase/challenges.sql).
  [challenges]="tools/web/challenges_flow.mjs --url=$P --out=$S/${TAG}_challenges"
  # Play in a shared model's view: 8808-1's steering turned by its wheel,
  # by the mouse at 1280 px and a finger at 390, and Reset; the drag's own
  # frames held to 36 ms on average on a CPU; and 1484-1 with motions of its
  # own, each played by its button and taken back, Reset, and its page
  # saying what it does.
  # Published from a throwaway account, deleted after; API routes only,
  # with the bypass (supabase/play.sql's and motions.sql's card when they
  # are applied).
  [play]="tools/web/play_flow.mjs --url=$P --publish --out=$S/${TAG}_play"
  [booklet]="tools/web/booklet_flow.mjs --url=$P/app --out=$S/${TAG}_booklet_web"
  # The booklet edited by hand: a set's steps turned, zoomed, paged, merged
  # and undone by the timeline's buttons and keys, a page laid out by the
  # mouse (a picture dragged onto the margin, a parts list's corner, words
  # and a picture added); its booklet and file say so.
  [booklet_edit]="tools/web/booklet_edit_flow.mjs --url=$P/app $B --model=$R/vendor/omr/files/106-1.mpd --out=$S/${TAG}_booklet_edit_web"
  [flex_pose]="tools/web/flex_pose_flow.mjs --url=$P/app $B --out=$S/${TAG}_flex_pose_web"
  [grab]="tools/web/grab_flow.mjs --url=$P/app $B --out=$S/${TAG}_grab_web"
  # The grab crane opened while every part fetched fails twice first (cut,
  # 503: Playwright's route), all 29 down; a part no pack carries answered
  # 404, asked once and said once in the status bar (PartLibrary.RETRY_AFTER).
  [fetch_retry]="tools/web/fetch_retry_flow.mjs --url=$P/app $B --out=$S/${TAG}_fetch_retry_web"
  [progress]="tools/web/progress_check.mjs --url=$P/app"
  [share_probe]="tools/web/share_probe.mjs --url=$P"
  [site]="tools/web/site_check.mjs --url=$P"
  # Every page and dialog, each visible control judged against the design
  # system's tokens (web/site.css, docs/DESIGN_SYSTEM.md); the API answered
  # by its stand-in, so no account is made.
  [design]="tools/web/design_flow.mjs --url=$P --out=$S/${TAG}_design"
  # Every page and dialog design visits (tools/web/site_pages.mjs), judged
  # by axe-core (tools/web/axe-core, vendored): no serious or critical
  # finding at 390 and 1280, light and dark, signed out and in; and every
  # control's name in the browser's accessibility tree meaningful, the key
  # pages' controls there by name. The API answered by the stand-in.
  [a11y]="tools/web/a11y_flow.mjs --url=$P --out=$S/${TAG}_a11y"
  # The journeys by keyboard alone (Tab, Enter, Escape; Space on a
  # checkbox): the gallery to a model, Like, Save, Share, a comment and a
  # reply, Report it's dialog, Follow, the account menu to Notifications
  # and Mark all read, Edit profile's dialog, Settings, Sign in's dialog and
  # the download; each stop's focus shown, the focus never lost, dialogs
  # keeping it and giving it back. The deployment's pages and scripts, the
  # API and the stand-in's model answered here.
  [keyboard]="tools/web/keyboard_flow.mjs --url=$P --out=$S/${TAG}_keyboard"
  # The gallery as a person uses it (docs/SOCIAL.md U3): at 390 the first
  # card's picture within 330 px, at 1280 four whole cards; Top, New and
  # Following, Top over this week, a kind and Made; a like from a card;
  # endless three times then Show more; Back to the same card; the empty
  # gallery; and api/share.js before and after supabase/gallery_tabs.sql.
  # The deployment's pages, the API answered by the stand-in's crowd.
  [gallery]="tools/web/gallery_flow.mjs --url=$P --out=$S/${TAG}_gallery"
  # local only: card_check.mjs. It compares the cards the checkout's api/
  # makes with those its web/card.js draws in a browser, both from the same
  # stand-in data; a deployment's cards come from the same file (deploy.sh
  # copies web/card.js into each function), and [design] judges them there.
  # The theme (web/theme.js): System, Light and Dark chosen in the footer,
  # on Menu at 390 and from another tab for /admin and the Claude sign-in,
  # on every kind of page at 390 and 1280: at once, kept across a reload and
  # a new tab, every frame of a load in the chosen theme, the browser bar's
  # colour following. Signed out; theme_account adds the account's memory
  # (a throwaway account, deleted after), once supabase/theme.sql is applied.
  [theme]="tools/web/theme_flow.mjs --url=$P --out=$S/${TAG}_theme"
  [theme_account]="tools/web/theme_flow.mjs --url=$P --account --only=home --widths=1280 --out=$S/${TAG}_theme_account"
  # A model's page (docs/SOCIAL.md U4), the gallery's first model: the
  # picture, name, designer and action bar on a phone's first screen, the
  # column beside the picture on a laptop as the page scrolls; Like, Save,
  # Share, Comment, I built it and More named with their counts, never 0;
  # Share's link and toast, and the share sheet where there is one; Save's
  # lists, Favourites first; More's embed code; More by and Similar only
  # with three cards. Signed in, the API answered by the stand-in.
  [model_page]="tools/web/model_page_flow.mjs --url=$P --out=$S/${TAG}_model_page"
  [download]="tools/web/download_check.mjs --url=$P/download"
  [tabs]="tools/web/tabs_flow.mjs --url=$P/app --out=$S/${TAG}_tabs"
  # Two chats, two tabs: the relay's rules alone, then the app in two tabs.
  [tabpair_probe]="tools/web/tabpair_probe.mjs --url=$P"
  [tabpair]="tools/web/tabpair_flow.mjs --url=$P/app --out=$S/${TAG}_tabpair"
  # Build together (docs/TOGETHER.md): the server's half from three accounts
  # in seconds (numbering, refusals, the time a change takes), then two
  # browsers and the desktop app in one session: joined by the link, 50
  # edits interleaved and byte-identical after, each undo its own, a
  # stranger refused, the owner ending it. Needs supabase/together.sql.
  [together_probe]="tools/web/together_probe.mjs --url=$P"
  [together]="tools/web/together_flow.mjs --url=$P --out=$S/${TAG}_together"
  # local only: together_timing.mjs. A measure with no verdict: where the
  # time of a change goes, stage by stage, as the model grows richer; the
  # flow above holds the bar (docs/TOGETHER.md).
  # File > New tab: a second tab on an empty model of its own, kept across
  # a reload, the first tab untouched (src/parts/tab_session.gd).
  [newtab]="tools/web/newtab_flow.mjs --url=$P/app --out=$S/${TAG}_newtab"
  # File > Library…: an LDraw set and a community model each opened in a tab
  # of its own, the first tab untouched; the library and the gallery played
  # from tests/fixtures/library by Playwright's route (src/ui/library_dialog.gd).
  [library]="tools/web/library_flow.mjs --url=$P/app --out=$S/${TAG}_library"
  # A set's ?library= typed into a tab with work not saved asks first; and the
  # Boutique Hotel (3,164 parts) from the deployment's store, timed from its
  # tab's start to a first picture and fully open (walk180 A8).
  [library_tab]="tools/web/library_tab_flow.mjs --url=$P/app $B --out=$S/${TAG}_library_tab"
  # My collection in a real browser: a throwaway account imports a parts
  # export, adds a set, reads what is short and ranks what it can build;
  # the account and its collection are deleted after (tools/web/collection_flow.mjs).
  [collection]="tools/web/collection_flow.mjs --url=$P/app --out=$S/${TAG}_collection"
  # local only: tabwalk_flow.mjs. Real Claude Code sessions on the
  # subscription build in two tabs at once: about 15 minutes and the plan's
  # quota a run, and Claude's answers vary, so a release cannot wait on it.
  # tabpair above holds the same rules with scripted chats. Run it by hand
  # after a change to the relay's tabs or the connector (its header says how).
  [people]="tools/web/people_flow.mjs --url=$P --out=$S/${TAG}_people"
  # A person's page (/u/<handle>, docs/SOCIAL.md U5): a throwaway designer
  # lists two models and chooses links, a banner and pins (op=showcase, its
  # refusals whether or not supabase/profile_shows.sql is applied, "not open
  # yet" until it is); her page at 390 and 1280, light and dark, signed out
  # and in: avatar, numbers with no count of none, links ugc nofollow,
  # pins, tabs. The account deleted after, and its row of profile_shows.
  [profile]="tools/web/profile_flow.mjs --url=$P --out=$S/${TAG}_profile"
  # Your account as your profile (docs/SOCIAL.md U6): a throwaway Ada who
  # set all the old account page could (her name, words, links, banner and
  # pins, a favourite, a collection, her emails, whom she follows shown)
  # finds it on /profile, her page's head and tabs, and in Edit profile; a
  # name changed there shows with no reload and nothing else changes;
  # Saved, Sets and Insights; /settings has every row with her choices;
  # Bea with no profile makes one in two fields; Ada deletes her account
  # from Settings and every row of hers goes. 390 and 1280 px, light and
  # dark, signed in and out; the throwaway accounts deleted after.
  [account_page]="tools/web/account_page_flow.mjs --url=$P --out=$S/${TAG}_account_page"
  # Your own picture as your avatar, and your likes on your profile
  # (docs/SOCIAL.md D11, U5, U6; supabase/avatars.sql): throwaway Ada and
  # Bob. Before the file, every avatar the tile, Edit profile offering no
  # picture, and a picture or Likes "not open yet"; once applied, Ada crops
  # a picture to a circle in Edit profile and it is on her page, her card,
  # her model, her comment, Bob's feed and her header; the refusals; her
  # Likes tab shown and hidden from Settings; the owner takes it out on
  # /admin; she takes another off herself; deleting her account deletes its
  # file. 390 and 1280 px, light and dark; the accounts deleted after.
  [avatar]="tools/web/avatar_flow.mjs --url=$P --out=$S/${TAG}_avatar"
  [moderation]="tools/web/moderation_flow.mjs --url=$P --out=$S/${TAG}_moderation"
  [reload]="tools/web/reload_flow.mjs --url=$P/app $B --out=$S/${TAG}_reload"
  [keep]="tools/web/keep_flow.mjs --url=$P/app $B --out=$S/${TAG}_keep"
  # A signed-in person's models kept with their account (supabase/account_models.sql):
  # saved in one browser and opened from File, Open in a fresh one with the
  # same parts; two saves of one version both kept ("Cloud House 2"), one
  # made offline; renamed and deleted from File, Open in one browser and so
  # in the other, a change made there while it was deleted kept, and Undo
  # (account_models_delete.sql); an account near and at its limit saying
  # so after a save, with Delete old models; saved signed out with nothing
  # sent, and Save on an unnamed model asking its name; then the throwaway
  # accounts deleted, and their rows with them.
  [cloud_library]="tools/web/cloud_library_flow.mjs --url=$P/app $B --out=$S/${TAG}_cloud_library"
  # Signing in as a person does: a first visit's sign-in screen, an emailed
  # code typed (minted, sent nowhere), a reload still signed in, Account
  # saying who, the admin page refused, and Sign out; a throwaway account.
  [account]="tools/web/account_flow.mjs --url=$P/app --out=$S/${TAG}_account"
  [decor]="tools/web/decor_flow.mjs --url=$P/app --out=$S/${TAG}_decor"
  [model_view]="tools/web/model_view_check.mjs --url=$P/app --out=$S/${TAG}_model_view"
  # ext-apps' basic-host, built: BW_APP_HOST names its examples/basic-host.
  # The host is kept in the main checkout (bench/data, git-ignored); a
  # session's shell that set BW_APP_HOST did not outlive it, and the check
  # ran with no host at all (2026-10-19).
  [app_host]="tools/web/app_host_check.mjs --url=$P/app --host=${BW_APP_HOST:-$R/bench/data/ext-apps-host/basic-host} --out=$S/${TAG}_app_host"
  [focus]="tools/web/focus_check.mjs --url=$P/app $B --out=$S/${TAG}_focus"
  [list_changed]="tools/web/list_changed_check.mjs --url=$P $B"
  [noai]="tools/web/noai_flow.mjs --url=$P/app --relay $B --out=$S/${TAG}_noai"
  [oauth]="tools/web/oauth_flow.mjs --url=$P/app $B"
  # local only: signup_check.mjs. It asks the Supabase project, not a
  # deployment, whether anybody can make an account without the code:
  # public sign-up off, confirmation on (account.md). canary below holds
  # the same settings by behaviour on every preview.
  # The daily sign-in canary (api/_canary.js), from here and as the
  # deployment's own run (/api/otp/canary, with CRON_SECRET): a public
  # sign-up refused, an unconfirmed address signing in by no way, a new
  # address signing in by a code api/otp.js made and enrolling no second
  # factor; the run recorded. Throwaway accounts at Resend test addresses,
  # deleted and checked gone.
  [canary]="tools/web/canary_check.mjs --url=$P --route"
  [technic]="tools/web/technic_flow.mjs --url=$P/app $B --out=$S/${TAG}_technic"
  [assembly]="tools/web/assembly_flow.mjs --url=$P/app $B --out=$S/${TAG}_assembly_web"
  [sections]="tools/web/sections_flow.mjs --url=$P/app $B --out=$S/${TAG}_sections_web"
  [placing]="tools/web/placing_flow.mjs --url=$P/app $B --out=$S/${TAG}_placing_web"
  # The parts bin's Techniques and its camera, at 1280 and on a phone at
  # 390: a worked construction held whole, put down and undone, and a photo
  # of a 3001 to Brickognize, live, with Brick 2 x 4 first. Brickognize is
  # a third party, so it is not in ORDER: run when the bin changes.
  [bin]="tools/web/bin_flow.mjs --url=$P/app $B --out=$S/${TAG}_bin_web"
  # The app's accessibility in a browser (docs/COMPETITIVE.md item 14):
  # Settings, Interface size at 150% and 85% at 1280 and on a phone at 390,
  # every control the page is told of inside the window; and whether a
  # screen reader in the browser hears the app (Godot builds no AccessKit
  # for the web, so no: printed either way). Run when the app's interface
  # changes.
  [app_a11y]="tools/web/app_a11y_flow.mjs --url=$P/app $B --out=$S/${TAG}_app_a11y"
  # The app on a phone, built for a finger: a small house built by touch at
  # 390 x 844 and 430 x 932 (three to the point), every target 44 points or
  # more and no text under 12, the parts sheet swiped, a part's actions by a
  # held finger, two fingers turning the view.
  [phone]="tools/web/phone_flow.mjs --url=$P/app $B --out=$S/${TAG}_phone_web"
  [flex_skin]="tools/web/flex_skin_flow.mjs --url=$P/app $B --out=$S/${TAG}_flex_skin_web $R/vendor/omr/files/8202-1.mpd"
  # A set's carried parts drawn from LDraw's own subparts, fetched from the
  # parts bucket as it opens (tools/storage_ldraw.py must have run).
  [carried]="tools/web/carried_flow.mjs --url=$P/app $B --label=preview --out=$S/${TAG}_carried_web $R/vendor/omr/files/21321-1.mpd"
  [brickify]="tools/web/brickify_flow.mjs --url=$P/app --out=$S/${TAG}_brickify_web"
  [brickify_fox]="tools/web/brickify_flow.mjs --url=$P/app --model=tests/fixtures/brickify/fox.obj --studs=24 --least=60 --says=on.a.stand --out=$S/${TAG}_brickify_fox_web"
  # Every kind of file Brickify reads (PLY, 3MF, VOX, FBX, an OBJ with a
  # picture and no .mtl) through the page's chooser, read as the desktop reads it.
  [mesh_formats]="tools/web/mesh_formats_flow.mjs --url=$P/app --out=$S/${TAG}_mesh_formats_web"
  # What a frame costs the app on a big model (75969-1, 925 parts): each press
  # of the timeline's Next and an orbit's frames held to 200 ms of the app's
  # own work, select all to 400 (cad_frames --gate). steps_flow checks what
  # a step shows, not
  # what it costs: the grab's drag handles, found twice a second, took a step
  # from 75 ms to 6.7 s and every check passed (CADTASK.md, section 6).
  [frames]="tools/web/cad_frames.mjs --url=$P/app $B --gate --arrive=300 --only=orbit,select_all,step --out=$S/${TAG}_frames_web $R/vendor/omr/files/75969-1.mpd"
  # A first visit to /app on broadband (20 Mbps, 40 ms), three cold loads in
  # browsers of their own: each file as sent (its encoding and cache header),
  # the bytes and the time until the parts bin is usable, the network and the
  # main thread apart, held to ceilings (load250: the live m167 sent 30.9 MB
  # and was usable at 28.7 s): alone, below.
  [load]="tools/web/load_check.mjs --url=$P/app $B --runs=3 --max-bytes=LOAD_MB --max-interactive=LOAD_S --out=$S/${TAG}_load"
  # Render's first open in a fresh browser, every frame timed: alone, below.
  [render_open]="tools/web/render_open_check.mjs --url=$P/app --out=$S/${TAG}_render_open"
  # File, Render…: Quick and Good pictures, a 24-frame turntable, Best
  # cancelled, and a crane's own motion from Animation framed on what moves
  # (docs/MOTIONS.md), each downloaded and decoded; the page's longest wait
  # held to twice the app's own: alone, below.
  [render]="tools/web/render_flow.mjs --url=$P/app $B --out=$S/${TAG}_render_web"
  # Build it from a shared link on a slowed phone: each page turn timed, and
  # the first step's arrival; publishes from a throwaway account, deleted after.
  # A shared link built on a throttled phone: every step and turn timed and
  # said; until the steps are carried with the link (sharesteps, round 2),
  # the first step takes 9-12 s, so the times are said, not held to a bar.
  [share_steps]="tools/web/share_steps_flow.mjs --url=$P --publish --report-only --sizes=300,1000 --out=$S/${TAG}_share_steps"
)
ORDER="art io steps floor outline knowledge arrival idle cursor share_flow booklet booklet_edit flex_pose grab progress share_probe site design a11y keyboard theme model_page gallery download frames load"
NAMES="${*:-$ORDER}"
# The checks that write the live database, which every preview and the
# relay share with production: each flow that makes a throwaway account and
# deletes it after (session.mjs's deleteAccount, or the admin API's users),
# and all it does as that account between. Two runs at once collided on
# 2026-10-22: 429s in profile, and another run's model took discovery's
# pick. So each takes one lock for the whole machine, whichever battery it
# is in (a release's, a unit's unit_preview.sh): a file in the repository's
# git folder, which every worktree shares. live-db.log beside it says who
# took it and left it, and when.
LIVE_DB="$(git rev-parse --path-format=absolute --git-common-dir)/live-db"
live() { grep -qE 'deleteAccount\(|auth/v1/admin/users' "${CMD[$1]%% *}" 2>/dev/null; }
run() {
  local name="$1" t0=$(date +%s) lock
  # A name not in the map ran bare node, which exits 0 at once: technic
  # "passed" in 0 s without running (2026-10-13).
  if [ -z "${CMD[$name]:-}" ]; then echo "$name exit=127 fails=1 0s :: FAIL no such check" >> "$S/$TAG.out"; return; fi
  # Held for the check's run only, and never by what it starts: a browser
  # left behind would hold the database from every other run.
  exec {lock}>>"$LIVE_DB.lock"
  if live "$name"; then
    if ! flock -w "${LIVE_WAIT:-3600}" "$lock"; then
      echo "$name exit=75 fails=1 $(( $(date +%s) - t0 ))s :: FAIL the live database stayed busy (LIVE_WAIT, an hour): $(tail -1 "$LIVE_DB.log")" >> "$S/$TAG.out"
      exec {lock}>&-; return
    fi
    echo "$(date '+%F %T') took $TAG $name after $(( $(date +%s) - t0 ))s" >> "$LIVE_DB.log"
  fi
  # The limit is on the check, inside heavy: around heavy it counted the wait
  # for a slot, and at load 50 tabs and keep ran out queued, never run.
  "$H" timeout 2700 node ${CMD[$name]} > "$S/${TAG}_$name.log" 2>&1 {lock}>&-
  local code=$?
  live "$name" && echo "$(date '+%F %T') left $TAG $name exit=$code" >> "$LIVE_DB.log"
  exec {lock}>&-
  echo "$name exit=$code fails=$(grep -c 'FAIL' "$S/${TAG}_$name.log") $(( $(date +%s) - t0 ))s :: $(grep -vE '^\s*$' "$S/${TAG}_$name.log" | tail -1 | cut -c1-200)" >> "$S/$TAG.out"
}
: > "$S/$TAG.out"
# Timing checks run alone: beside a heavy flow, idle's ghost drew 4 or 6
# frames for 7 moves, and 16 every time alone (2026-10-13). grab times the
# page's longest wait in a drag: paired, the four-bar's read 551 ms (m54).
# frames holds the app's own work a frame on 75969-1 (200 ms, select all 400).
# discovery works out the week's pick from every test model built this week:
# paired with designers, whose castle was built three times, it took the
# pick and the small builds shelf (2026-10-19). It alone needs the top
# spots of the gallery's front; a flow that lists a model beside another
# judges its own model's place by what was listed before it
# (tools/web/gallery_order.mjs), as share_flow and share_probe failed to
# when each wanted its model first (m115, m122).
# oc drives orangecheck's real window: beside another browser on a loaded
# box its close stalled in m162's and m164's batteries and never alone, so
# orangecheck asked that popup checks not run side by side (2026-10-24).
SOLO=" idle arrival progress cursor render_open render grab share_steps frames play discovery oc load "
PAIRED=""; ALONE=""
for n in $NAMES; do case "$SOLO" in *" $n "*) ALONE="$ALONE $n";; *) PAIRED="$PAIRED $n";; esac; done
# Two at a time, a slot taking the next check as soon as it is free. Two
# live checks side by side would take turns at the lock while the other
# slot sat idle, so a slot takes a live one only when the other is not
# running one, or nothing else is left. The live checks, one after
# another, then set the phase's length. On the times m146's checks took:
# 31 minutes, against the 37 its pairs took, each waiting for its longer
# half; on m144's, which had more live ones, 44 against 38.
wet=(); dry=(); declare -A slot=()
for n in $PAIRED; do if live "$n"; then wet+=("$n"); else dry+=("$n"); fi; done
while :; do
  while [ ${#slot[@]} -lt 2 ]; do
    busy=""; for p in "${!slot[@]}"; do live "${slot[$p]}" && busy=1; done
    if [ ${#wet[@]} -gt 0 ] && { [ -z "$busy" ] || [ ${#dry[@]} -eq 0 ]; }; then n=${wet[0]}; wet=("${wet[@]:1}")
    elif [ ${#dry[@]} -gt 0 ]; then n=${dry[0]}; dry=("${dry[@]:1}")
    else break; fi
    run "$n" & slot[$!]=$n
  done
  [ ${#slot[@]} -gt 0 ] || break
  ended=""; wait -n -p ended; [ -n "$ended" ] || break
  unset "slot[$ended]"
done
# Timing checks measure the app's own work, which still slows when the box is
# busy: m87's play and m98's grab held at load 20-42 and passed alone at 3-10
# (2026-10-19). Each waits for the one-minute load to fall under CALM_LOAD,
# from one budget of CALM_WAIT seconds for the whole battery, so a busy box
# delays a release by minutes, never hours; then it runs anyway. The load
# each began at goes in TAG_calm.log, to read beside a timing failure.
calm_left=${CALM_WAIT:-900}
calm() {
  local load waited=0
  while :; do
    load=$(cut -d' ' -f1 /proc/loadavg)
    awk -v l="$load" -v c="${CALM_LOAD:-12}" 'BEGIN { exit !(l < c) }' && break
    [ "$calm_left" -le 0 ] && break
    sleep 15; waited=$((waited + 15)); calm_left=$((calm_left - 15))
  done
  echo "$1 began at load $load after ${waited}s" >> "$S/${TAG}_calm.log"
}
for n in $ALONE; do calm "$n"; run "$n"; done
echo done >> "$S/$TAG.out"
