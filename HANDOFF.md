# Handoff

Written 2026-10-09 for a fresh session. Everything below is committed,
pushed and live; nothing is half-finished.

## The goal

Designs as good as a set LEGO would actually release, with no
architectural ceiling on size. The owner's words: a real set may be four
thousand pieces or more, so do not design to a target number. And, from
the same day: keep planning ahead, refine the vision, and update the
website when something is worth showing.

`docs/ROADMAP.md` is the plan and is the **first thing to read**: the
product end to end, the gap as one number, what is solved, and the levers
ranked by evidence.

## Where it stands

- Pushed, live at **brickworks.diy**. Confirm with
  `curl -sI "https://brickworks.diy/app?v=$(date +%s)" | grep -i location`
  against `git log --oneline -3`; a docs-only commit does not earn a
  deploy, and the stamp only says `-dirty` for a change to something that
  ships.
- Full suite: `tools/check.sh` (it queues itself on the machine's `heavy`
  pool). Above a load of about 12 the on-screen checks starve and report
  TIMED OUT, which proves nothing either way: rerun that one alone under
  `heavy` with `xvfb-run` (see `tools/check.sh` for the command).
- On the landing page and shipped as `models/castle.ldr`: castle run 24,
  **2,438 parts, 121 shapes, 83 used once or twice, 13 colours**, 53% its
  main colour, 15% big pieces — the first castle whose walls read as a
  real set's (two greys, masonry bricks, bonded). A real set that size
  has 262 shapes, so it is thin for its size; run 19 (1,329 parts, 113
  shapes, 16 colours) is closer to its own size's norm.

## What the owner found, 2026-10-09 evening

"The AI assistant doesn't work at all, and the UI/UX is not well thought
out." Reproduced in a real browser against the live site: the assistant
**did** work — four answers from Anthropic in ninety seconds — and showed
nothing for all ninety: one line of small grey text, the example car still
on the baseplate, and a bad key reported as "invalid x-api-key". No check
had ever pressed Build. Fixed and proven the same way
(`tools/web/assistant_flow.mjs`): a run card with a clock, the current step,
the steps done, what to expect (measured: a small house takes 11 minutes
and $2.40 at high, 4 minutes and $0.72 at medium) and Stop; the example car
cleared for a first design; errors in plain words with the key form back
for a refused key; the key form explaining the assistant first; no renderer
stats on the status line; a grouped toolbar with Clear asking first.
**Before calling anything on the web done, run assistant_flow against it.**

## Designing with Claude: the two ways, and one decision that is yours

- **Your Claude plan, through a connector** (built 2026-10-09). The tab gets a
  private address; the person adds it to Claude (claude.ai or the Claude app as
  a custom connector, or `claude mcp add --transport http`) and asks Claude to
  build. Claude is the client on their own plan; Brickworks never sees a login
  or a key and never calls a model. That is ordinary use of Anthropic's apps,
  and needs no approval. Relay: `api/mcp.js` + `supabase/relay.sql`; tab side
  `src/net/claude_connector.gd`, `src/ui/connector_form.gd`.
  First real use from claude.ai (2026-10-10) found the tab answers nothing
  while it is out of view — a browser pauses it, and the person is in
  claude.ai. The relay now answers the handshake and tool list itself, the
  page reports going out of view, Claude is told to ask for the tab rather
  than told it is closed, and a dropped call is handed out again. The address
  is kept on the device, so it is added to Claude once.
- **Your own API key**, checked when pasted, kept in the browser or for the
  visit only, sent only to Anthropic, behind a content security policy.
- **Owner's decision, still open:** the desktop's in-app "My Claude" starts the
  person's Claude Code headless from inside Brickworks. Anthropic's Claude Code
  legal page says running Claude Code in a product requires accepting the
  Commercial Terms, and the Agent SDK page asks for approval before a product
  offers claude.ai login or rate limits (quotes in Reelwright's
  `docs/design/claude-plan.md`). Reelwright keeps its equivalent opt-in and off
  by default until its owner has both. Brickworks' "My Claude" is a checkbox,
  off by default; turning it on by default needs the owner to accept the
  Commercial Terms and ask Anthropic. The connector does not have this question.
- **The site says so** (2026-10-09): brickworks.diy leads with the two ways as
  numbered steps, then the castle, what the app does, and "What Brickworks never
  sees" (key, login, relay, models — each claim traceable to the code). Its
  pictures are made, not taken by hand: `tools/web/app_shot.mjs` for the app,
  `tools/web/make_share.mjs` for the link card.
- **Vercel's environment, after accounts went:** the relay reads
  `SUPABASE_URL` and `SUPABASE_SECRET_KEY`, so they stay. Nothing reads
  `ANTHROPIC_API_KEY` any more; removing it from the project is yours to do
  (`vercel env rm ANTHROPIC_API_KEY production`), and leaves no key of ours
  anywhere a request can reach.

## What the work found

- **The levers that moved runs**, each measured: detailing per assembly;
  sending a pass back once when the assembly or the whole model is on
  the tail of real sets (thin shapes, few one-off pieces, one colour, big
  pieces); telling passes the parts real sets of the kind use; and
  **worked examples**, which move a design where a part list does not —
  told the window frames by number for three runs a fire station used
  none, shown one window it used twenty-four and went from a plateau of
  62-70 shapes to 87 (run 23). The run table is in `docs/ROADMAP.md`.
- **Pieces too big, and invisible in every picture.** A real set is 10%
  pieces as big as a 2 x 4 brick; every castle was 39-56%. `fill` now lays
  courses in short bricks on a running bond (run 21: 17%), can put a second
  colour through them (`mix_color`, real castle walls 9-19%) and lay some
  as masonry facing out (`masonry`). The renderer draws the seam between
  bricks now, desktop and web, so all of that can be seen.
- **Glass and doors sit in their frames** where real sets seat them
  (`Assistant.NESTS`, measured over the model repository). Nothing can be
  laid on a 60596 door frame yet: its notched top studs are not stud
  primitives, so the parts pipeline keeps them as solid. The fix belongs
  in `tools/ldraw/connectivity.py` and a sub-build.
- **Real sets as a source.** LDraw's model repository serves one `.mpd`
  per set. Its sub-model names rank what real sets repeat (roof, door,
  seat, lamp, window, tree, furniture); nine of its sub-models are now
  techniques, credited in `docs/ATTRIBUTION.md`. Of 162 small real
  sub-models the checker now passes 110; the rest are its false positives
  (`tools/omr.py harvest`, `src/dev/harvest_probe.gd`). Support is walked
  out from the ground, so a part hung under an overhang holds.
  `tools/layout.py` measures how a model stands against real ones.
- **The 4 x 4 corner-round brick was recommended on a stale number.**
  Every castle built ~200 of it; real castle sets since 2010 use at most
  eight. The prompt now says round is a choice.

## Desktop releases

Linux, macOS and Windows builds are cut on a cadence, put on GitHub Releases
and offered at brickworks.diy/download.html. `docs/RELEASING.md` is the
whole cycle: when to cut one, the seven commands, what done looks like, and
what the owner has to provide before macOS and Windows stop asking on first
launch (an Apple Developer ID with an App Store Connect key; a Windows
code-signing service). `VERSION` is the version; `tools/release.py version`
says whether everything agrees with it.

## What is next

1. Read run 24 (the castle with everything): did the passes recolour its
   walls, and does it use the window and the new techniques?
2. The checker's false positives: clips on bars and hollow studs. The
   parts pipeline records no bar connector at all; recognising bars and
   hollow studs in `tools/ldraw/connectivity.py`, then a sub-build, lets
   real sets' lanterns, flags and railings through.
3. Roofs, from the 32 real roof sub-models that pass.
4. The door frame's notched studs (see above).
5. Proportion: towers over walls, against more real castles.

## Gotchas that will cost you hours

- **Commits are authored as the user, always.** `git -c user.name=Xaxis
  -c user.email=william.neeley@gmail.com commit -F <msgfile>`. Vercel
  seat-checks the author and a wrong one fails the deploy *silently*. No
  assistant attribution of any kind, ever.
- **The machine is shared and coordinated.** One GPU lease for every
  project (`~/.claude/claude-core/bin/gpu`), a pool of CPU slots for
  heavy jobs (`~/.claude/claude-core/bin/heavy`). The `godot` on the path
  renders in software unless `GODOT_GPU=1`, and then it queues for the
  lease. The suite queues itself; run software renders under `heavy`; take the GPU
  only for seconds (a screenshot), never for a design run. Browsers stay
  on SwiftShader (`tools/web/browser.mjs`).
- **No display.** `tools/check.sh` and `tools/design.py` give themselves
  Xvfb. Anything new that drives the app needs the same, or it hangs.
- **Never kill by `ps | grep`.** `tools/running.py <pattern>` finds a run
  and `--stop` ends it. Stopping `design.py` can orphan its Godot child;
  check with `ps` for your own `--out` path afterwards. Do not touch
  anything under `/mnt/Projects/Reelwright`.
- **Read a design run's output after it ends.** `--out` is rewritten on
  every build. A run prints its progress per assembly and, last, what it
  spent.
- **A Godot script error does not end a probe; it sits there idle.** A
  probe that hangs at ~1% CPU has probably hit one. `tools/check.sh`
  bounds each probe and reads the output for `SCRIPT ERROR`.
- **No GDScript string is greppable in a `.pck`.** To prove code shipped,
  use the stamp: `/` 308s to `/b/<sha>/`. Packed JSON *is* greppable.
- **Rebrickable may be downloaded at most once a day**, enforced in
  `tools/fetch_data.sh`. `themes` was added to its tables this session.
- **Before deploying after any geometry change**, run
  `python3 tools/storage_parts.py --check` and confirm `to upload: 0`.

## Where things are

| | |
|---|---|
| The plan | `docs/ROADMAP.md` |
| How to prove anything works | `.claude/skills/verify/` (start at `SKILL.md`) |
| The whole check suite | `tools/check.sh` (6-20 min, queues on `heavy`) |
| The design loop and its prompt | `src/ai/assistant.gd` |
| Detailing per assembly | `Assistant._detail_next`, `src/dev/detail_probe.gd` |
| Count a model against real sets | `tools/texture.py model.ldr --brief "..."` |
| How a model stands, against real sets | `tools/layout.py model.ldr` |
| Real sets as models: fetch, rank, harvest | `tools/omr.py`, then `src/dev/harvest_probe.gd` |
| Real-set data, joined to LDraw | `tools/rebrickable.py` |
| Catalogue build | `tools/refresh_catalogue.py` |
| Drive a real design | `tools/design.py "a brief" --out m.ldr` |
| Deploy | `tools/deploy.sh --prod` |
| Desktop releases: version, build, smoke, publish | `tools/release.py`, the cycle in `docs/RELEASING.md` |
| The download page | `web/download.html`, fed by `web/releases.json` |

## Cleanup state

Verified at handoff: no uncommitted changes, no processes left running by
this session, live build matches the last code commit. Scratch work lived
in the session scratchpad under `/tmp`, which is disposable.
