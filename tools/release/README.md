# Releasing Brickworks

A unit an agent reports ready goes live within the hour, through these
scripts. Logs go to `$RELEASE_OUT` (default `$TMPDIR/brickworks-release`).

```sh
tools/release/release_wt.sh merge20 <main sha>        # a staging worktree that can deploy
MERGE_GATES=ship tools/release/merge_unit.sh <worktree> <sha> "Merge …" # each ready unit, as the user
#   on CONFLICTS: resolve, git add, then
tools/release/merge_finish.sh <worktree> "Merge …"
# the unit's affected probes (featuremap affected), then:
tools/release/ship.sh <worktree> <tag> site io …       # preview, its checks, then production
```

Or all of that in one command, queued behind the release before it:

```sh
tools/release/train.sh stage rel-m219 stage219 --after rel-m218 \
  --checks "io gallery" --units "unit1 unit2" --title "…"   # every headless probe
#   --probes "grab fits" names exactly those; --probes none --why "…" runs none
tools/release/train.sh status                  # what is live since when, what is in flight, ETAs
tools/release/train.sh hold rel-m219 "why"     # train.sh release rel-m219 lifts it
tools/release/train.sh reship rel-m219 io      # a stopped one again, from its worktree
tools/release/train.sh reship rel-m219 --accept progress "why"  # past a check failing on brickworks.diy too
```

`reship TAG [--probes "..."] CHECK...` is for a train that stopped after its
ship began, on a check gone stale or a timing probe under load: commit the
fix in `.claude/worktrees/TAG`, then reship. It ships that worktree with the
checks named, on the preview already made when only checks or release tools
changed since (`SHIP_REUSE`), beside the probes that did not pass (or those
`--probes` names), and keeps the train's own record: a release staged
`--after TAG` waits for it to serve. rel-m227 and rel-m228 were shipped by
hand instead, and the hand ship left rel-m227's train saying stopped, which
the release after it then stopped on (2026-10-31).

`--accept CHECK "REASON"` (at `reship`, or at `stage`) ships past a check
that fails on brickworks.diy too, as the same script: its run there after
the preview (below) failed, and its script has not changed since the build
brickworks.diy serves. One that passes there, or did not run there, is
refused: its failure is the release's own. The train's log, its status and
the release's merge message name the check, the reason, and both failure
lines (`<tag>_accepted`). At `reship` the merge's message is written again,
every tree as it was, so the preview is made afresh (about 17 minutes); at
`stage`, where the lead already knows the check fails on brickworks.diy, it
costs nothing. rel-m249's progress failed on its preview and worse on
brickworks.diy (295 ms against 158), on a booklet delay the release did not
touch, and the lead could ship past it only by reshipping with `site` alone,
which recorded nothing (2026-11-02).

The train waits detached until `rel-m218_lead.out` says `SHIP: deploy:
brickworks.diy serves`, never on rel-m218's process: its live checks after
that touch only the live site. It stops if rel-m218 held, failed or never
began, and gives up at its deadline (`TRAIN_WAIT`, 6 hours). Then
`release_wt.sh` from origin/main, `merge_unit.sh` of the branch's tip
then (in the spec's `tip`; a commit to the branch after it waits for the
next release) as `Merge: <title>` with `MERGE_GATES=ship`, a tree dirty or
mid-merge refused, `check.sh --lists`, then the probes and `ship.sh` side
by side. The probes run four at a time (`TRAIN_PROBES_AT_ONCE`; one failing
beside others runs again alone before it counts, and its exit and its FAIL
lines both count) at the release's priority, in a process group of their
own. `ship.sh` makes its gates, preview and checks meanwhile, and moves main
only once `<tag>.probes` is gone, every probe passed: it says `running
PID: NAMES` until then, or `failed: NAMES`, and a failure stops the ship
before main moves (the checks under way end as they would; none more
begins). One after the other, rel-m226's 35 probes took 50 minutes and its
ship an hour more, while the GPU the probes wait for sat idle through the
ship (2026-10-30). The ship promotes the very preview its checks passed.
A check that fails on the preview, and alone after it, runs on
brickworks.diy as it is, after the preview's battery and as a unit's check
would (`ship.sh`, `SHIP_STALE`: no release's priority at the lock or for a
slot), and `status` says which already fail there: people, stale since
achievements, held rel-m226 two hours on. Every check named used to run
there from the moment the train was staged, beside the preview's battery:
rel-m249's 74 there ran 10 hours of checks at load 43 on 24 cores, four of
its preview's checks held for the load, and its preview's checks waited
3.0 hours for the lock behind them (2026-11-02). Once brickworks.diy serves the
release's sha, it retires the release's worktree and each unit's whose HEAD
is on main and which holds no file git does not track (`retire_wt.sh`). Its
spec is a file each in `bench/results/release-out/<tag>.train/` (branch,
after, checks, probes, units, title, deadline), each read only when its step
comes: a unit merged into the branch meanwhile brings its checks by an edit
of `checks`. Staging adds to the checks named every one `flows_for.py` (the
branch's, on its own tree) finds for what the branch changed since it left
main, or since the merge of it the release before ships, and says which it
added: rel-m237's hand-picked list missed model_view (2026-11-02).

Named no `--probes`, it runs every probe `tools/suite/headless.txt` lists
in the branch's own tree, as `check.sh` reads it; windowed.txt's are the
suite's, and out.txt's skip themselves. Staging says how many (`probes: all
209 headless (103 windowed left to the suite)`), `<tag>.train/probes` holds
them and `probes.why` why, and the log and `status` say it again.
`--probes "a b"` names exactly those; `--probes none --why "…"` runs none
and says why, and `--probes ""` is refused. Staged with `--probes ""`
every time, no release ran a probe from v0.15.0 to rel-m256, and eight went
red on main unseen until desktop016's whole-suite run held desktop 0.16.0
(2026-11-04). All 209 took 19m30s four at a time on this box at load 4 to
8 (22m12s with each failure again alone), on rel-m256's merge, and failed
the six headless ones of the eight. That is well under the preview's
battery, about two hours from the ship's start (rel-m256's, 14:56Z to
17:09Z), so the whole list costs the release no time. Picked by what
`featuremap affected` reaches it would have caught three of the six: its
GDScript graph follows `res://` paths alone, and a probe that uses a class
by its `class_name` is never reached (a change to
`src/assembly/instructions.gd` reached none of the 32 probes that use
`Instructions`). Since claude-core e6df180 it follows class names and
autoloads, and the verify config names `src/dev/*_probe.gd` as tests, so
that change lists all eight. Trains still run the whole list: it costs
nothing beside the battery.

Its log is `<tag>_train.out`, its result `<tag>.train/result`,
and a train that stops before the ship writes `<tag>.gave_up` as
`ship_after.sh` does, so the release staged behind it stops too. It runs
from a copy of itself: a release fast-forwards the main checkout, this
script with it, and bash reads a script as it goes. `kill -- -PID` (status
names the pid) stops a train and what it runs. Restaging a tag that
stopped clears its worktree and branch when they hold nothing but its merge,
and refuses when they hold a fix of their own. The lead wrote a chain like
this by hand for each release from rel-m214 to m218, a promote job beside
it, and another to retire worktrees afterwards; a held merge left one
release's tree half-merged (rel-m214), and a retire after a held preview
took rel-m196's worktree (2026-10-28).

`status` is for the owner as much as the lead. First what brickworks.diy
serves, which release that is and since when (the end of its deploy), and
how long a ship takes from begun to served (the median of the last five:
when `<tag>_lead.out` was made to when `<tag>_prod.log` was last written).
Then each release in flight, a train or a ship begun by hand: its step,
its checks passed of all, and when it should serve. A ship under way serves
about a median ship after it began; one not yet shipping, no sooner than
the release before it serves and a ship after that. The ETAs need a file
system that keeps when a file was made (`stat %W`); without one they are
left out.

And before a unit says ready, from its own worktree:

```sh
RELEASE_OUT=<its scratch>/out tools/release/unit_preview.sh <worktree> [check…]
```

What each one guards against, all learned the hard way on 2026-10-13:

- `merge_unit.sh` merges with `--no-commit` as the user. It takes either
  side of the generated files (`tools/mcp_tools.json`, the feature map) and
  writes them again, and it unions doc conflicts (`resolve_docs.py`). A
  unit begun before a version was cut has its changelog entries put under
  `[Unreleased]` (`changelog_merge.py`), where git would merge them into the
  released section. After
  the merge it re-imports, so new `class_name`s resolve, then runs the
  parse gate, then rewrites the tool list when `src/net` or `src/ai`
  changed.
- A new probe goes on a line of its own in `tools/suite/headless.txt`,
  `windowed.txt` or `out.txt` (with why after its `#`), never in
  `tools/check.sh`. The suite's lists were arrays there, every unit appended
  to the same last line, and four merges on 2026-10-22 were that conflict
  settled by hand. The files merge a probe at a time
  (`tools/merge_lists.py`, `merge=lists` in `.gitattributes`): both sides'
  new lines are kept, a line one side edits is kept once, the side merged in
  winning if both did, and one taken out stays out. A plain union kept an
  edited line twice (steps_kept, 62d9de65 and fe6808ae). The driver is in the
  main checkout's `.git/config`, and `merge_unit.sh` passes it on its merge;
  a merge with neither stops on a conflict. `merge_unit.sh` then runs
  `tools/check.sh --lists`, which fails a merge that leaves a probe in no
  list, or one listed twice, or out and run both.
  `tools/check.sh --dry-run` prints every command the suite would run.
- `parse_gate.sh` parses every GDScript file the merge changed. Two units
  each added a `"dome"` key to one dictionary, git merged both without a
  conflict, and Godot could not parse `assistant.gd`. The tool-list probe
  hung on it rather than failing.
- Probes may run at once in one checkout (`tools/probe.sh`, so
  `run_probes.sh` too): none writes `.godot`. A class list older than the
  scripts is what fails them, every script naming a class it lacks: a
  `.godot` copied from another worktree, or kept across a merge, checkout
  or bisect. surface108's three probes failed with 9,377 errors,
  `"BestOfTwo" not declared`, put down to running at once; one probe alone
  on that list fails the same (2026-10-22). `probe.sh` imports first when
  the list is behind (`tools/fresh_import.sh`, one import a checkout under
  `.godot/import.lock`) and refuses (exit 2) when an import cannot fix it;
  the parse gate imports whenever it is behind, not only when it is missing.
- `preview_checks.sh` runs the named browser checks, `PC_AT_ONCE` at a
  time (3). Timing
  checks (idle, arrival, progress, cursor) run alone: beside a heavy flow,
  idle drew 4 frames for 7 moves, against 16 alone. An unknown name fails,
  where it used to run bare node and "pass". The script runs from a copy
  of itself, so editing it mid-battery cannot break the run. `frames`
  (`cad_frames.mjs --gate`, alone too) holds what a frame costs the app on
  75969-1: each press of the timeline's Next and an orbit's frames under
  200 ms of the app's own work, select all under 400. No check held that:
  the grab's drag
  handles took a step from 75 ms to 6.7 s, and m61 shipped with it
  (docs/CADTASK.md, section 6).
- The merge scripts hold a lock (`.git/worktrees/<name>/merging`) until their
  last gate is done, and `ship.sh` refuses a worktree that has one. m26 was
  shipped as soon as its merge commit appeared, while the tool-list check
  was still running (2026-10-14).
- `ship.sh` fails closed: every check named must report `exit=0`, and a
  battery that wrote no results holds the release. It used to look only for
  a failed line, so when the checks could not even start (a relative
  worktree path) m31 went on to deploy production unchecked (2026-10-15).
- `RELEASE_OUT=<folder> ship_after.sh <prev-tag> <worktree> <tag> <check…>`
  queues a release behind the one before it: it waits for that release's
  result (`<prev>.done`), ships only if it shipped, and writes its own. `-` for none before. A
  waiter written by hand found the release before by its command line, its
  own grep hid it, and m43's ship went at once (2026-10-17).
- A result is only the latest attempt's: a waiter that gives up writes
  `<tag>.gave_up`, never `<tag>.done`, and a tag queued or begun clears
  both (its log before is kept as `<tag>_ship.prev.log`). m177's first
  waiter gave up when m175 held and wrote `m177.done` = 1; m177 shipped
  later, and m178's waiter read that 1 while m177's checks ran, and held
  (2026-10-26).
- `ship.sh` writes `<tag>.done` itself as it ends, begun by hand or queued,
  and no waiter reads a log for a result. m181's promote, begun by hand,
  cleared `m181.done`; m182's waiter fell back to the held battery's
  `exit=1` ending `m181_ship.log`, and held while the promote ran
  (2026-10-26).
- Every release runs `site` and `frames` whether they are named or not:
  `frames` holds a big model's step, orbit and select all to the app's own
  work per frame, after a feature that ran twice a second left a step at
  6 s while every named check passed.
- To hold releases, write a reason to `$RELEASE_OUT/HOLD` (all) or
  `$RELEASE_OUT/<tag>.hold` (one): a queued release waits, and one already
  shipping stops before main moves. Remove the file to let them go. Killing
  a queued waiter does not stop a ship it already started.
- `ship.sh` runs each check that failed in its battery once more, alone,
  before it holds, every one whatever else failed, and one that wrote no
  line for the first time. Timing checks (frames, play, progress, placing,
  grab) get no second go: alone they would pass what the load showed.
  rel-m249's progress, a timing check, kept keys, library, model_page and
  together from theirs, and the lead reshipped them by hand (2026-11-02).
  Its last line names what still fails: `SHIP: held, failed on the
  preview: X Y (failing on brickworks.diy too: X)`.
- `SHIP_REUSE=1 ship.sh <worktree> <tag> <check…>` reuses the preview that
  tag made, only if it was made from the same commit (`<tag>_preview.sha`),
  and runs the named checks on it again; each must still pass. A timing
  check failed at load 75-95 and held m33 twice on 2026-10-16; the only way
  on was a fresh deploy and every check again. Rerun the one that failed,
  alone, when the load allows, then promote with it.
- `timing_ab.sh <base-wt> <new-wt> <rounds> <out> -- <flow…>` tells a
  timing failure's cause: the change, or the load. It serves both builds'
  `build/web` and runs the flow on each in turn, so the load weighs on both
  alike. m142's phone drag failed its preview twice; the live m141 failed
  the same bar 2 runs in 3 beside it (2026-10-22).
- `ship.sh` runs the merge gates itself, once for every unit merged, under
  the release's priority: the parse gate on every GDScript file changed since
  main, and the tool list against the app. Run per merge without priority,
  each gate waited 30 to 70 minutes for a slot at load 50 (2026-10-16).
  `MERGE_GATES=ship` has `merge_unit.sh` leave them to it; without it the
  merge still runs them, as before.
- `ci_gate.sh` is the first of those gates: what GitHub's `check.yml` ran
  on every push. One version in `VERSION`, `project.godot` and
  `CHANGELOG.md` (`tools/release.py version`); the Python suite as
  `tools/check.sh` runs it (pytest, else `tools/minitest.py`); and
  `shellcheck -S warning tools/*.sh tools/release/*.sh` (these scripts
  too, which CI never linted), where shellcheck is installed (where
  it is not, the gate says so and goes on: koalaman's v0.10.0 static
  binary goes in `~/.local/bin`). CI was red from 2026-10-13 to 10-26 and
  nobody read it: a quoting warning in `describe_snippets.sh`, then a test
  that needed `colors.json`, which CI never had. A check that only reports
  is not read, so this one holds the release before main moves, and the
  workflow runs by hand only, since a private repository pays for each
  minute. It takes 80 to 120 s in its slot at load 40, nearly all of it
  the suite.
- `release_links.sh` holds a release before any of them, in about 30 s:
  every release page and file `web/releases.json` links to must answer a
  visitor, each file at its size (`tests/test_release_links.py`). A
  manifest naming a repository or a file that is not there yet cannot
  ship, and neither can one whose links a private source repository has
  broken (the releases' move to Xaxis/brickworks-releases, 2026-10-27).
- `ship.sh` hands over to the worktree's own `tools/release/ship.sh`, so a
  release runs its own scripts and knows its own checks. m87 was started
  from main's copy and held on "no such check" for the three it added
  (2026-10-19). `RELEASE_HERE` pins a copy on purpose.
- A timing check (the SOLO ones) runs as `heavy --solo`: it waits until none
  of the project's other jobs holds a slot, bar long ones held over
  `BOX_HEAVY_SOLO_WAIT` (600 s, a bench run), and none queued after the
  first of them starts until the last ends; after 600 s it runs anyway.
  `<tag>_calm.log` says the load each began at, after how long, and beside
  what. m87's play and m98's grab held at load 20-42 and passed alone at
  3-10 (2026-10-19). Waiting for the load to fall instead held m214 ten
  minutes while four agents' deploys and flows kept it at 13-42 (2026-10-30).
- `ship.sh` sends live the very preview its checks passed (`tools/deploy.sh
  --promote=URL`): the preview is a production build no domain points at
  yet, so that takes seconds, and it ends once brickworks.diy names the
  build (`SHIP: deploy: brickworks.diy serves <sha>`). `deploy.sh --promote`
  takes only a build of its checkout's own commit, by the preview's
  `version.json`, and ship.sh never a unit's preview (`--unit`, without
  production's secrets). Should the promotion not go, it deploys production
  afresh with `deploy.sh --prod`, as releases did before.
- `ship.sh` takes `BOX_HEAVY_PRIORITY` for the release only, and so do the
  train's own probes, which run beside it: heavy holds a project's ordinary
  jobs back while its priority job runs, so ordinary probes would wait out
  the ship. A unit's probe batches must not take it: it holds every other
  agent's work. After promoting, it waits 90 s for the CDN before checking
  the live site.

- `unit_preview.sh <worktree> [check…]` is how a unit proves its site
  change before it says ready. It deploys the worktree unpromoted
  (`tools/deploy.sh` without `--prod`, which Vercel makes as
  `--prod --skip-domain`: no domain points at it), then runs the checks
  `flows_for.py` names for what the unit changed since the commit it was
  made from (the later of its merge base with main and with a `rel-*`
  branch), or the checks named, and `site` always. One `pass` or `FAIL`
  line a check, and it exits 0 only when every one reported and passed.
  Its files are `$RELEASE_OUT/<branch>_unit_*`; `UNIT_REUSE=1` runs the
  checks again on the preview it last made from the same commit. It runs
  no merge gate, takes no release priority and never touches main. Its
  deploy and checks are ship.sh's own (`preview_lib.sh`). Four release
  previews held on 2026-10-22, about an hour each, and every time on a
  check: digest, moderation, share_flow, builds, share_probe and challenges
  read markup a unit had changed, and a smooth scroll was read mid-way.
  Its deploy is `tools/deploy.sh --unit`: as a production deployment
  (m112's queue) it would hold every production secret while it runs code
  nobody has reviewed, so `OC_SIGNING_SECRET` (orangecheck asked,
  2026-10-23) and `ANTHROPIC_API_KEY` (read by nothing) are set to nothing
  for it alone (`vercel deploy --env NAME=`). A release's preview and
  production keep both. The rest stay: every API needs
  `SUPABASE_SECRET_KEY`, share_probe runs the sweep with `CRON_SECRET`,
  and the preview's own email sign-in sends with `RESEND_API_KEY`.
- `flows_for.py` also names a changed flow's own checks, and the checks of
  every flow that imports a changed module in `tools/web` (`session.mjs`
  is nearly all of them).
- The checks that write the live database, every flow that makes a
  throwaway account and deletes it after, run `LIVE_DB_SLOTS` (3) at a
  time across the machine: `preview_checks.sh` holds one of the files
  `.git/live-db.slot.N` in the main checkout, under a shared hold of
  `.git/live-db.lock`, for each one's run, whichever battery it is in, and
  `.git/live-db.log` says who took it, after how long, which slot, and
  when they left. Two runs at once on 2026-10-22 got 429s in profile, and
  another run's model took discovery's pick; one at a time, rel-m254's 53
  held the lock for 3.1 hours and four units gave up behind it. Twelve of
  the longest held it 12 minutes three at a time on rel-m254's preview,
  and 44 one at a time, every one passing both ways and no sign-in
  answering 429 (2026-11-04). Each flow
  makes accounts of its own and judges its own models by id; sign-ins are
  by password, from a bucket of 30 at once and one every 2 s, which a
  battery draws on about 180 times (`session.mjs`). The checks that read
  what every account changes hold `.git/live-db.lock` alone (`ALONE_DB` in
  `preview_checks.sh`, each with its reason): discovery (the week's pick),
  first_steps (the top designers), challenges (the one test challenge),
  and beta where the beta is open (one test pool). In a battery a slot
  takes a live check first while fewer of the battery's than
  `LIVE_DB_SLOTS` run one, one held alone only when none runs, and the next
  check as soon as it is free. Between batteries a live check waits for a
  slot; `LIVE_WAIT` (an hour) bounds that, then the check fails. A
  release's checks go first: waiting, its battery leaves a ticket in
  `.git/live-db.release/`, and no other battery takes a slot while one is
  there. Within each line, a release's and the rest, only the first living
  ticket takes a slot, so one waiting to hold it alone is not passed by
  those that came after. flock serves no one in order, and a unit's A/B,
  taking the lock run after run, held rel-m232's arrival 24 minutes
  (2026-10-31). A train leaves a mark there, a file named for its pid
  holding its start time, from its start until its battery on the
  preview, with the checks run again alone, is done (`ship.sh` takes it
  away, `SHIP_LIVE_MARK`), so
  no unit begins a live check meanwhile: a run already in the lock cannot
  be taken back, and one begun while rel-m233 merged held its oauth 33
  minutes. Then units take it in their turn again, and the release's own
  checks on brickworks.diy wait theirs among them. Left for as long as the
  train ran, the file shut units out of the live database for all but an
  hour of the sixteen from rel-m247's staging to rel-m250's battery: 13
  unit checks gave up after an hour each, and the 15 that ran waited 7.5
  hours between them (2026-11-02).
- The checks that take no lock run side by side, in one battery and across
  two, signed in to the flows' shared test account (`tools/web/session.mjs`).
  None may change what that account keeps and then read it back: rel-m249's
  keys ran on its preview and on brickworks.diy a minute apart, each put
  the account's keys back while the other's were on it, and both failed
  with nothing wrong in the app. A flow that must, signs in to a throwaway
  account of its own and deletes it after, as `keys_flow.mjs` does since
  keysync (which makes it take the lock). Swept on 2026-11-02: of the rest,
  only `dialogs_flow.mjs` writes there, and only things of its own (a link
  it publishes and takes back, a session it starts and ends, its own page
  signed out), which no other run can undo.
- A unit's own run on the live site, an A/B or a diagnostic outside a
  battery, takes the lock only through `tools/release/live_db.sh [--alone]
  WHO CMD...`, which takes a slot by the same rule (all of it with
  `--alone`, for a run of an `ALONE_DB` check; `live_db_lib.sh`, which
  `preview_checks.sh` sources) and writes `.git/live-db.log` as WHO. hover's
  scratch script took it with a bare flock, gave way to no release, and
  held rel-m233's checks twice more, 33 and 38 minutes.

`tools/release/clean_worktrees.sh [--dry-run]` removes finished worktrees
and nothing else: never a locked one (the harness locks an agent's while it
runs), one with a process inside, one with uncommitted tracked edits, or one
whose branch is not on main. "Its commit is on main" alone also describes a
running agent that has not committed yet, and two agents lost their work to
a cleanup that checked only that (2026-10-16).

A mesh sub-build ships on the staging worktree's own copy of the
catalogue (`ln -sfn <copy> <worktree>/assets/generated`). Merge it into the
shared catalogue only after the release is live, with `tools/merge_subbuild.py`
and a backup first. Agents mid-run then never see the catalogue change
under them, and it never runs ahead of the code that reads it.
