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
  # What a model is based on (docs/SOCIAL.md section 7, item 5,
  # supabase/model_bases.sql): its designer says it in a dialog, a set
  # built from and work elsewhere changed; its page credits each, its
  # structured data and JSON say them, the set's page lists it; a wrong
  # set or link said in words, somebody else refused; taken away, gone.
  # Before the file, nothing offered and a list refused in words.
  # Throwaway accounts, deleted after with their model.
  [based_on]="tools/web/based_on_flow.mjs --url=$P --out=$S/${TAG}_based_on"
  # The collections directory (W12, supabase/collection_directory.sql):
  # /collections lists a throwaway designer's public collection as a card
  # with its cover, name, owner, model count and Follow; her private one
  # never; Follow from the card at 390 px dark; most followed; 390 and 1280
  # px in both themes; made private, gone. Throwaway accounts, deleted after.
  [collections]="tools/web/collections_flow.mjs --url=$P --out=$S/${TAG}_collections"
  # Notifications apart from the feed (docs/SOCIAL.md U7): your avatar in
  # the header with what is new, its menu (Menu at 390 px); a comment, a
  # photo and ten likes on a throwaway designer's model as one group with
  # its picture, the likes one row naming nobody; opened, the count gone;
  # a group read once opened, Mark all read; the feed apart; signed out at
  # both widths; once supabase/achievements.sql is applied, the levels
  # reached as a group of their own, its row opening /profile's
  # Achievements tab, read once opened. Throwaway accounts, deleted after;
  # before and after each file (it reads which from the answers).
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
  # voted in its two groups, ended and won, the winners told to a voter in
  # Notifications, and its link's own head: API routes only, with the bypass
  # (supabase/challenges.sql, supabase/challenge_notices.sql).
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
  # The documentation at /docs (tools/docs_site.py): every page answers with
  # its own title, every link and #fragment on it resolves, light and dark
  # at 390 and 1400 with nothing sideways, search finds "fresh eyes" and
  # "Build together" and goes there, the pages list folds on a phone, and
  # what is on this page follows the reading.
  [docs]="tools/web/docs_flow.mjs --url=$P --out=$S/${TAG}_docs"
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
  # paged by Show more alone (web/pager.js), never by itself; Back to the
  # same card; the empty gallery; and api/share.js before and after
  # supabase/gallery_tabs.sql.
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
  # The LDraw library on the site (library333): /library at 390 and 1400 px,
  # light and dark, the whole shelf with every card's cover, number and
  # modeller; found by a set's number, 10179, and by a theme's pill; the
  # Millennium Falcon's page from its card, its cover, its modeller credited
  # with LDraw's page and CC BY 2.0, its facts, its parts with our pictures,
  # Share; and Open in Brickworks opening 106-1 in the app. The store's own
  # index and files: no account, no database.
  [library_site]="tools/web/library_site_flow.mjs --url=$P --out=$S/${TAG}_library_site"
  # The site's one pager (web/pager.js, site357) on the LDraw library and a
  # person's models: the count and numbered links, Show more from the
  # keyboard to the first new card, a press kept while its page is on its
  # way (#81), ?page=3 opened afresh with Show earlier, Back to the same
  # pages and card, and the pager's fit at 390. The live database's lists.
  [paging]="tools/web/paging_flow.mjs --url=$P --out=$S/${TAG}_paging"
  # Every set in the catalogue a page (sets364, api/_sets.js): /library's
  # whole catalogue found by number and filtered (3D, theme and year); a set
  # with no model (10497-1) with its picture drawn from its parts, its parts
  # list with our pictures, its weight and first paint; one with a model
  # (10179-1) and that model's page linking back; Parts you own for a
  # throwaway account with three of its lots, and its wanted list; Open its
  # parts in Brickworks landing in the app's bin; and the sets' sitemaps.
  [sets_flow]="tools/web/sets_flow.mjs --url=$P --out=$S/${TAG}_sets_flow"
  # local only: download_check.mjs's gated half (a Free click refused with
  # the way to Pro, a Pro click sent to the route's address). Every
  # deployment answers "not gated" until the owner turns billing on (U8),
  # so there it checks the public links, as before.
  [download]="tools/web/download_check.mjs --url=$P/download"
  # Plans, coming soon (web/plans.html, supabase/plan_interest.sql): the page
  # at 390 and 1400, light and dark; its form refusing a bad address, then a
  # Resend test address's entry kept, sent again and changed, not added, and
  # taken off; read in the table with the secret key, and forgotten at the
  # end. No account is made. Fails until plan_interest.sql is applied.
  [plans]="tools/web/plans_flow.mjs --url=$P --out=$S/${TAG}_plans"
  # Paying for Pro (docs/PLANS.md U3): on a deployment with plans off, as
  # every release's is, that none of it answers or shows (no Plan row on
  # /settings, nothing asked of plans, each POST the interest form's). On a
  # unit's preview deployed with tools/deploy.sh --unit --billing-stand-in,
  # the step before Checkout and Checkout, the portal and the webhook. A
  # throwaway account, closed at the end.
  [billing]="tools/web/billing_flow.mjs --url=$P --out=$S/${TAG}_billing"
  # The beta (api/_beta.js, supabase/beta.sql): on a deployment with the
  # beta off, as every release's is, /beta says Coming soon with no form and
  # no count and the API refuses an application. On a unit's preview from
  # tools/deploy.sh --unit --billing-stand-in --beta-open: signed out sent
  # to sign in; a throwaway applies once from the form at 390; the owner's
  # queue shows its signals and approves it, the next spot and its month
  # given in Admission's test mode; the emails kept (delivered where there
  # is a mail key); a decline; two approvals at once at 99 given make one
  # spot 100; deleting the account erases its application. The checks' own
  # pool of spots, never the 100. Throwaway accounts, deleted after.
  [beta]="tools/web/beta_flow.mjs --url=$P --out=$S/${TAG}_beta"
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
  # local only: relay_timing.mjs. A measure with no verdict: what a call
  # through the relay costs when the tab answers at once, median and p90
  # (relay338). It runs against a preview too; run it after a change to
  # the relay's queue (its header says how).
  [people]="tools/web/people_flow.mjs --url=$P --out=$S/${TAG}_people"
  # A person's page (/u/<handle>, docs/SOCIAL.md U5): a throwaway designer
  # lists two models and chooses links, a banner and pins (op=showcase, its
  # refusals whether or not supabase/profile_shows.sql is applied, "not open
  # yet" until it is); her page at 390 and 1280, light and dark, signed out
  # and in: avatar, numbers with no count of none, links ugc nofollow,
  # pins, tabs; what she earned as she lists, is Tested, posts a build and
  # is built ten times (levels once supabase/achievements.sql is applied,
  # which the answer says). The account deleted after, and its row of
  # profile_shows.
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
  # ChatGPT connecting, stood in for (docs/PROVIDERS.md P1): discovery, its
  # real client document named on the sign-in page and its code refused
  # without its signature; a client holding its own key signs in with a
  # signed assertion, lists the tools in the form OpenAI takes, and calls
  # one into a throwaway account's tab; Claude's list as before. The page
  # at 390 and 1280, light and dark, in a browser. The account deleted after.
  [chatgpt]="tools/web/chatgpt_flow.mjs --url=$P $B --out=$S/${TAG}_chatgpt"
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
  # The app on a tablet, built for a finger: the phone's layout laid out
  # wide, a small house built by touch at 768 x 1024, 1024 x 768 and
  # 1024 x 1366 (two to the point) and each turned round after, every
  # target 44 points or more and no text under 12, the parts panel kept
  # open beside the model.
  [tablet]="tools/web/tablet_flow.mjs --url=$P/app $B --out=$S/${TAG}_tablet_web"
  # Every dialog More opens, by a finger, at 390 x 844 and 430 x 932 (three
  # to the point) and 768 x 1024 and 1024 x 768 (two): Save as typed above
  # the keyboard, a saved model renamed and deleted, a version opened, Share
  # published by link, a setting changed, Build together started, a 3D model
  # and an LDraw model exported, Find, the booklet's Save as PDF, the model
  # tree and the properties, a library set opened in its own tab, a picture
  # rendered, a minifigure built and stood on the baseplate, the rest opened
  # and closed, and last the test account signed out, each audited as
  # the phone's is (every target 44 points or more, no text under 12, nothing
  # off the screen or under the keyboard). A size a check: the four in one
  # ran past a check's 45 minutes on a loaded box.
  [dialogs]="tools/web/dialogs_flow.mjs --url=$P/app $B --sizes=390x844 --out=$S/${TAG}_dialogs_web"
  [dialogs_430]="tools/web/dialogs_flow.mjs --url=$P/app $B --sizes=430x932 --out=$S/${TAG}_dialogs_430_web"
  [dialogs_768]="tools/web/dialogs_flow.mjs --url=$P/app $B --sizes=768x1024 --out=$S/${TAG}_dialogs_768_web"
  [dialogs_1024]="tools/web/dialogs_flow.mjs --url=$P/app $B --sizes=1024x768 --out=$S/${TAG}_dialogs_1024_web"
  # local only: desktop_same.mjs. It compares a build's desktop at 1280 x 800,
  # by a mouse, with a base build's to the pixel, and a preview has no base
  # build beside it: run it on two local exports.
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
  # and was usable at 28.7 s); and 3039, which comes with the parts fetched
  # after the start (index.parts.bin), taken from the bin as soon as it is
  # usable, in hand with its ghost within 6 s of the click, as a part the
  # build carries is (a part of them asked for early waits for them, 15 s
  # at most): alone, below.
  [load]="tools/web/load_check.mjs --url=$P/app $B --runs=3 --max-bytes=20 --max-interactive=28 --pick=3039 --max-pick=6 --out=$S/${TAG}_load"
  # Render's first open in a fresh browser, every frame timed: alone, below.
  [render_open]="tools/web/render_open_check.mjs --url=$P/app --out=$S/${TAG}_render_open"
  # File, Render…: Quick and Good pictures, a 24-frame turntable, Best
  # cancelled, and a crane's own motion from Animation framed on what moves
  # (docs/MOTIONS.md), each downloaded and decoded; the page's longest wait
  # held to twice the app's own: alone, below.
  [render]="tools/web/render_flow.mjs --url=$P/app $B --out=$S/${TAG}_render_web"
  # Render's Product look under Compatibility: a black wall behind clear
  # glass and a white one behind trans red, drawn on each backdrop, each
  # picture not flat, the red glass red and the black wall dark
  # through the clear (docs/RENDERING.md, section 5b): alone, below.
  [product_render]="tools/web/product_render_flow.mjs --url=$P/app $B --out=$S/${TAG}_product_render_web"
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
  local name="$1" solo="${2:-}" t0 lock
  t0=$(date +%s)
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
  # The dialogs checks use every dialog's main action at their size, about
  # 2,600 s at load 40: dialogs_1024 ran out at 2,700 (fig257, 2026-10-25).
  local limit=2700
  case "$name" in dialogs*) limit=3600 ;; esac
  "$H" $solo timeout "$limit" node ${CMD[$name]} > "$S/${TAG}_$name.log" 2>&1 {lock}>&-
  local code=$?
  # heavy --solo says the load it began at, after how long, and beside what.
  local began; began=$(sed -n 's/^heavy: solo //p' "$S/${TAG}_$name.log" | head -1)
  [ -n "$solo" ] && echo "$name began ${began:-with no word from heavy}" >> "$S/${TAG}_calm.log"
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
# together measures how fast a change crosses between two browsers: with
# placing beside it its plain p95 read 1,123 ms against 516-864 alone
# (2026-10-24).
SOLO=" idle arrival progress cursor render_open render product_render grab share_steps frames play discovery oc together load "
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
# (2026-10-19). Each runs as heavy --solo: it waits until none of the
# project's other jobs holds a slot, bar long ones (a bench run), and none
# queued after the first of them starts until the last ends. Waiting for
# the load to fall instead held m214 ten minutes while four agents' deploys
# and flows kept it at 13-42 (2026-10-30). After BOX_HEAVY_SOLO_WAIT
# (600 s) it runs anyway. The load each began at, and beside what, goes in
# TAG_calm.log, to read beside a timing failure.
for n in $ALONE; do run "$n" --solo; done
echo "done" >> "$S/$TAG.out"
