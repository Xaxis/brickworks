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
  numbered steps, then the castle, what the app does, and "What Brickworks
  keeps, and what it never sees" (since 2026-10-11 the email address first,
  then key, login, relay, models — each claim traceable to the code). Its
  pictures are made, not taken by hand: `tools/web/app_shot.mjs` for the app,
  `tools/web/make_share.mjs` for the link card.
- **Vercel's environment:** accounts and the relay read `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `RESEND_API_KEY`,
  `EMAIL_FROM`, `EMAIL_FROM_FALLBACK` and `MASTER_EMAIL`, all set for
  production and preview. Nothing reads `ANTHROPIC_API_KEY` any more;
  removing it from the project is yours to do (`vercel env rm
  ANTHROPIC_API_KEY production`), and leaves no key of ours anywhere a
  request can reach.

## Accounts: everyone signs in (2026-10-11)

The owner asked for "the comprehensive account system requiring users to
create/login to an account just using our OTP signin system", correlated
with the MCP, and that nobody use the platform without one. Built on the
email-code sign-in removed on 2026-10-09 (its tables never left Supabase).
The recipe and every check are in `.claude/skills/verify/features/account.md`.

- **What a person sees.** The app, web or desktop, opens on a sign-in
  screen over the dimmed builder (`src/ui/sign_in_gate.gd`): an address,
  "Email me a code", the code, signed in. No password and no separate
  sign-up. A reload or restart renews the kept session; the desktop stays
  signed in offline. Account on the toolbar (`src/ui/account_panel.gd`)
  says who, and signs out. Nothing in the builder takes a click or a key
  while the screen is up.
- **The MCP correlation.** A Claude connector belongs to the account that
  switched it on: the tab's hello to `api/mcp.js` carries the session,
  verified against Supabase's keys, and `relay_tabs.owner` records it. An
  address another account owns is refused (403); a tab with no owner gets
  no work and counts as closed. The admin page lists connectors per
  account. Connectors that follow the person, with OAuth on the connector
  itself, were built the same day: "Connecting Claude", below.
- **Decisions you may want to change.** (1) The gate is a client gate;
  the server enforces accounts where it serves something (the relay).
  `/api/account`'s `parts_url` stays open because builds already out ask it
  and the parts bucket is public. (2) Probes, headless runs and command
  lines that render, export or design and quit are never asked to sign in
  (`Main._gate_wanted`); a window opened with `--mcp` is. A checkout signs
  a machine in with `src/dev/sign_in.gd` (needs `.env`). (3) Sessions last
  until signed out; Sign out ends only this device's session. (4) A
  deployment answering `enabled: false` (no Supabase configured) asks
  nobody to sign in; one that cannot be reached at all shows "Cannot reach
  Brickworks" with Try again, unless a session was kept. (5) The admin page
  (`/admin.html`, MASTER_EMAIL only, read-only) uses the app's session in
  that browser rather than a sign-in of its own. (6) Sign-in codes are rate
  limited per address and per network address, kept a day.
- **Proven 2026-10-11, not yet in production.** `account_probe` (26
  checks) and `connector_probe` against the real functions
  (`tools/web/relay_server.mjs`) and database; `gate_probe` in a window,
  offline in the suite and live through the real form; the full suite on
  the branch merged with main; and on preview `2f3391d` in a real browser:
  `account_flow.mjs` (first visit gated, a code really emailed, a wrong code
  refused, signed in, still signed in after a reload, admin page refused,
  Account and Sign out; with `--master`, the owner's admin page listing the
  accounts), plus `connector_flow`, `assistant_flow`, `check.mjs` and the
  full `fit_check`, all signed in through `tools/web/browser.mjs`. Pictures:
  `shots/account/`, `shots/signin/` (gitignored). After the production
  deploy, run `account_flow.mjs` against brickworks.diy.
- **Database, applied to the live project 2026-10-11, additive only:**
  `alter table public.relay_tabs add column if not exists owner uuid
  references auth.users (id) on delete cascade` and the index
  `relay_tabs_owner` (`supabase/relay.sql`). Nothing else changed; the
  account tables and `may_ask_for_code` were already there.
- **Yours to do: the sender.** Codes go out, but from
  `EMAIL_FROM_FALLBACK` (another product's verified domain), because
  brickworks.diy is not verified at Resend and the key here is send-only.
  To fix it: a Resend API key with domain access, add brickworks.diy in
  Resend, put the DNS records it gives you at Namecheap, wait for
  "verified", then set the new key as `RESEND_API_KEY` on the Vercel
  project and remove `EMAIL_FROM_FALLBACK`. The admin page shows a warning
  while codes go out under the borrowed sender.

## Connecting Claude: one click, one address, OAuth (2026-10-11)

The owner: "why are you making it so hard to connect the studio to claude?
… formulate users unique link and it opens up the claude.ai page". Built
on what claude.ai documents (`docs/CONNECTING.md`, every claim sourced):

- **The one click.** claude.ai has a documented install link that opens
  *Add custom connector* with the name and address filled in. **Connect
  Claude** in the assistant panel (and in Account) opens it, puts the
  address on the clipboard, switches the tab on, and says the three steps
  (Add then Connect; sign in and Allow; come back). Claude Code gets the
  command to copy (`claude mcp add --transport http brickworks
  https://brickworks.diy/api/mcp`, then `/mcp`); the Claude desktop app
  shows what was added on claude.ai. No link can skip claude.ai's own
  confirmation, and none exists for Claude Code or the desktop app.
- **One address for everybody, signed in with OAuth.** Not a per-user
  link: a per-user secret in a URL is what we had, and what claude.ai's
  docs advise against. `https://brickworks.diy/api/mcp` answers 401 and
  names its metadata; Claude identifies itself by its published client
  document (claude.ai's and Claude Code's are both accepted, so neither
  registers), sends the person to `/oauth/authorize` — the same email-code
  sign-in, or just Allow if the app is signed in in that browser — and
  gets a token for their account. Calls go to that account's open tab on
  any device. `api/oauth.js`, `supabase/oauth.sql`, `web/authorize.html`.
- **Real Claude Code** (2.1.296) chose the published-identity path by
  itself: PKCE S256, a random loopback port, `scope=build offline_access`,
  the RFC 8707 resource.
- **Private addresses keep working** (`?t=…`), folded under "Private
  address".
- **Database, applied to the live project 2026-10-11, additive only:**
  `supabase/oauth.sql` — tables `oauth_clients`, `oauth_codes`,
  `oauth_grants`, `oauth_tokens` (row security on, no policies, public
  roles revoked), their indexes, and the function `oauth_sweep()`. Nothing
  existing was changed. Applied through Supabase's IPv4 pooler
  (`aws-0-us-east-1.pooler.supabase.com:5432`, user `postgres.<ref>`): the
  direct host is IPv6-only and this machine has no IPv6.
- **Decisions you may want to change.** (1) Signing out of one device
  does not disconnect Claude from the account (Claude's connection is not
  that device's); Disconnect Claude in Account does, everywhere at once.
  (2) Once Claude is connected, every tab the person signs in to listens
  by itself unless they switch it off there. (3) Access tokens last an
  hour, refresh tokens rotate and last 90 days unused; a refresh token
  replayed outside a 30 s grace ends its connection. (4) Anyone may
  register a client (that is what dynamic registration is); unused ones
  are swept after a day.
- **Yours to do, optionally:** list Brickworks in Anthropic's Connectors
  Directory (`claude.ai/directory/manage`, needs Anthropic's review) — it
  would make Brickworks findable inside Claude with a permanent Connect
  page. Not needed for any of the above.

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

1. **Orthanc, the owner's yardstick** (`docs/ROADMAP.md`, "Beyond variety:
   beauty"). Run 13 used `add_rooms` unprompted: eight furnished storeys,
   figures in the rooms, 80 shapes and 22 colours (the fantasy median is 23),
   but its faces were plain prism sections. Since then the prism dresses its
   faces by default and the checker accepts real joints (clips, hinges,
   hollow studs, turntables), so angled techniques can pass. Run 14 is the
   first with all of it. A master-level Orthanc goes on the homepage (task #29).
2. **Desktop 0.1.0 is out** (2026-10-10): checked by the release workflow on
   Linux, macOS (Apple silicon and Intel) and Windows, then published from that
   draft; brickworks.diy/download.html offers it. Next release by the cadence in
   `docs/RELEASING.md`.
3. **Merged 2026-10-10:** the minifigure builder (`src/minifig/`, M or the
   Minifig button; `add_minifig` for the assistant), the custom element maker
   (Make a part… in the bin; `src/parts/element_maker.gd`, `part_forge.gd`),
   59 real-set worked examples (`show_technique`), desktop releases
   (`tools/release.py`, `docs/RELEASING.md`, `web/download.html`), a model's
   name kept across a restart plus New, and the lighting fix (no white
   slopes). Still out: control icons and context cursors (an agent's
   worktree). Desktop signing waits on the owner: an Apple Developer ID and a
   Windows code-signing certificate (`docs/RELEASING.md`).
4. **Round joints need the catalogue rebuilt.** The checker forgives a clip
   on a bar, a bar in a hollow stud, a hinge and a turntable's top on its
   base, inside the round only (`Joints.rounds`, `joints_probe`): of 880 real
   sub-models 617 pass where 564 did, and the first angled worked example is
   in (`corner on a turntable`). Those joints are records in each part's
   `.lbm`, and the shipped catalogue predates them, so until the 17,539 parts
   that have them are rebuilt the checker forgives none and `joints_probe` and
   `techniques_probe` fail (`.claude/skills/verify/features/pipeline.md`).
   Next on the same corpus: handles whose opening the cover fills, and 75937.
5. Roofs, from the 32 real roof sub-models that pass.

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
- **The parts catalogue was rebuilt on 2026-10-10** with shafts and bores for
  the checker's round joints; the one before is at `assets/generated.prev`
  until it is clearly not needed. A rebuild is `tools/build_meshes.py --out
  <new dir>` in a uv venv with numpy and scipy (well over an hour), then
  `tools/refresh_catalogue.py` with that dir in place, the suite against it,
  a rename into place, and `tools/storage_parts.py` for the web.
- **Probes share this machine's real desktop user data** (`~/.local/share/
  godot/app_userdata/Brickworks/`). A run with `--script` no longer keeps the
  autosave (it did, and the desktop app reopened whatever the last probe
  left); a probe about the autosave turns `store.keeps` on and puts the file
  back, as `project_probe` does. Saved models and connector files there are
  still shared. The owner works in the browser, whose storage is apart.
- **On the web a save is durable only once IndexedDB has it.** The engine
  syncs `user://` behind its own back; at a load of eighty that took 44 s, and
  a reload before then reopens the older autosave.
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
| Accounts: sign-in screen, session, panel | `src/ui/sign_in_gate.gd`, `src/account/account.gd`, `src/ui/account_panel.gd` |
| Accounts: the server | `api/otp.js`, `api/account.js`, `api/admin.js`, `api/_auth.js`, `supabase/schema.sql` |
| Sign a checkout's machine in | `godot --headless --path . --script src/dev/sign_in.gd -- you@example.com` |
| Signing in, proven in a browser | `tools/web/account_flow.mjs` (and every flow starts signed in: `tools/web/browser.mjs`) |
| Desktop releases: version, build, smoke, publish | `tools/release.py`, the cycle in `docs/RELEASING.md` |
| The download page | `web/download.html`, fed by `web/releases.json` |

## Cleanup state

Verified at handoff: no uncommitted changes, no processes left running by
this session, live build matches the last code commit. Scratch work lived
in the session scratchpad under `/tmp`, which is disposable.
