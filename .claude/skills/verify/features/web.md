# Web

The same app, in a browser, at brickworks.diy — plus the small server behind
it: where the parts are, signing in, the owner's account list, and the Claude
connector's relay. Everyone signs in (see [account](account.md)); the assistant
runs on the person's own key, sent only to Anthropic, or on their own Claude
plan with Claude as the client.

<!-- covers: api:GET /api/account, api:POST /api/mcp, cli:web build and deploy, cli:first visit load check, cli:browser check, cli:freeze check, cli:progress check, cli:arrival check, cli:redraw check, cli:idle check, api:GET/POST /api/share, cli:share probe, ui:shared model viewer, ui:shared model page and card, cli:share view probe, cli:share browser flow, ui:gallery page, cli:seed the gallery, ui:landing page, ui:changelog page, ui:404 page, ui:FAQ page, ui:compare page, cli:compare media, ui:privacy page, cli:put the website together, cli:site check, ui:build it step player, lib:build pages, cli:build steps probe, cli:step count probe, cli:build browser flow, cli:share steps browser flow, cli:versions browser flow, lib:versions of a shared model, lib:steps carried with a shared model, cli:share pages probe, lib:directory, lib:model kinds, cli:part facts, cli:list load test, api:GET/POST /api/people, ui:profile and collection pages, ui:collections directory, cli:collections browser flow, ui:your profile page, ui:model page action bar, ui:model page pictures and tabs, lib:site sign-in, cli:people browser flow, lib:names filter, ui:report it, ui:takedown page, cli:moderation browser flow, cli:tabs probe, ui:this tab and its claude chats, cli:two chats probe, cli:two chats browser flow, cli:two windows probe, ui:newer build banner, lib:newer build, cli:update probe, cli:reload browser flow, cli:list changed check, cli:page places probe, ui:open a tab by link, ui:terms and guidelines, ui:age question, cli:age browser flow, cli:report digest browser flow, lib:the Tested mark's four tests, cli:tested probe, lib:the Tested mark kept and shown, cli:tested browser flow, lib:real builds: finishes counted and photos of builds, lib:a build photo made safe, cli:builds browser flow, lib:comments on a shared model, ui:comments on a step, cli:comments browser flow, lib:follows and the feed, ui:your feed page, ui:follow a person and the count on Account, ui:the account menu, ui:the app's Account count, cli:follows browser flow, lib:notifications apart from the feed, ui:notifications page, cli:notifications browser flow, lib:latest on Brickworks and designers to follow, cli:feed browser flow, lib:Top builds and this week's pick, ui:the gallery's front shelves, ui:choosing this week's pick, lib:build with what I own, cli:needs backfill, cli:parts count backfill, cli:discovery browser flow, lib:designers' numbers, ui:a designer's page, ui:your models as a designer, cli:designers browser flow, cli:profile browser flow, cli:gallery browser flow, ui:play in a shared model, lib:what moves in a model, lib:what moves on a gallery card, cli:share play probe, cli:play browser flow, ui:design system, cli:design browser flow, cli:accessibility browser flow, cli:keyboard browser flow, ui:theme choice, cli:theme browser flow, cli:what a frame costs in a browser, lib:the monthly challenge's rules, ui:this month's challenge page, ui:enter this month's challenge, ui:setting the monthly challenge, cli:challenges browser flow, ui:component kit, ui:model card, cli:picture themes check, cli:card check, lib:more by and similar models, ui:a model's parts and its download, cli:parts page probe, cli:model page browser flow, ui:your settings page, cli:account page browser flow, lib:replies to a comment, ui:comment threads on a model page, ui:open a shared model at a step, cli:step link probe, ui:first steps after a first sign-in, lib:the house's profile, lib:who modelled a shared model, cli:first steps browser flow, ui:your own picture as your avatar, ui:likes on a profile, cli:avatar browser flow, lib:challenges between months, ui:achievements on a profile -->

## Sub-features

- `GET /api/account`: what the app asks first. Without a token, the same for
  everybody and cacheable: `{enabled, url, key, assistant: "own_key",
  parts_url, signed_in: false}` — `enabled` (accounts configured, so everyone
  signs in), `url` and `key` (the Supabase project and its publishable key,
  where codes are redeemed), and `parts_url`, the project's `PARTS_URL` (null
  means beside the app). With `Authorization: Bearer`, also `signed_in`,
  `email` and `master`, never cached. The client is `src/net/deployment.gd`;
  `main.gd` hands `parts_url` to `PartLibrary.remote_parts`, and on the web
  part fetches wait for it; `Account` reads the rest. The desktop asks
  brickworks.diy, or `BRICKWORKS_API` when set. `/api/otp` and `/api/admin`
  are in [account](account.md). **The person's own key never reaches the
  server** — there is nothing on it that could take one.
- `web build and deploy`: `tools/deploy.sh` exports the WebAssembly build, puts it
  under `/b/<sha>/`, serves its page at `/app` and then proves it in a browser. With
  `--prod` it ends only once brickworks.diy/app names the new sha: the domain
  lagged `vercel promote` by up to a minute, twice, and checks run on "done"
  measured the previous build. It first runs `tools/storage_parts.py`, which
  uploads any part mesh the catalogue names that object storage lacks, and
  fails the deploy if it cannot: the web build fetches meshes from there, and
  a catalogue of 2,376 rebuilt meshes once went live before they were up, so
  every long Technic beam failed to load. Proves it: the deploy log's "part
  meshes in object storage" line ends "to upload : 0".
  `--unit` (unit_preview.sh's) sets `OC_SIGNING_SECRET`, `OC_CONNECT_KEY`
  (orangecheck Connect's, 2026-10-24), `RESEND_API_KEY` and
  `ANTHROPIC_API_KEY` to nothing for that deployment alone, since it runs
  unreviewed code: its log says "a unit's preview, without ...", its
  `/api/account` says `orangecheck.connect` false, and
  `POST /api/orangecheck?op=signin` with `{}` there answers 503 "not set up
  here", where a release's preview answers 422 for the missing token.
  A release goes through `tools/release/` (README there): a staging
  worktree, each ready unit merged as the user with a parse gate, then
  `ship.sh WORKTREE TAG CHECK...` (preview, its browser checks, production,
  the live site). Checked by running it: `ship.sh` says `SHIP: brickworks.diy
  serves <sha>` and the live site check and share probe pass. A production
  deploy that fails, or a site that does not serve `/b/<sha>/` after it,
  fails the ship before the live checks (m174's deploy lost a size to a
  timed-out connection and its ship still said done 0, 2026-10-26).
- `what a first visit waits for` (load250, 2026-10-24): a browser taking
  brotli is sent the build as `tools/export.sh` compressed it, brotli 11
  (`deploy.sh` routes `index.wasm`, `index.pck`, `index.js` and
  `index.parts.bin` under `/b/<sha>/` to the `.br` beside each, with
  `Content-Encoding: br`, `Vary` and the file's own type; any other browser
  gets the file, compressed by Vercel as before, which sent 9.6 MB of wasm
  and 21 MB of pack where 11 makes 6.9 and 7.4). The web presets leave
  `src/dev/` out and keep scripts as plain binary tokens
  (`script_export_mode=1`), which brotli squeezes to 2.9 MB where Godot's
  own compressed tokens stayed 4.9. The pack carries the first screen's
  geometry alone (`tools/web_pack.py`: the sample car, the palette and the
  essentials, 48 meshes); the rest of the working set, 1,525 meshes, is
  `index.parts.bin` beside the build ("BWP1", web_pack.py's docstring),
  fetched by a worker of the page's once the engine and pack are in and
  written into the engine's files at `/later/` once it has started
  (`src/boot/shell.html`, "The rest of the parts"), where
  `PartLibrary._on_disk` reads it as it reads the pack, offline too; a part
  of it wanted before then is fetched from the store on its own. The page
  preloads the wasm and pack from its head. `window.brickworksLater` says
  when it was asked, came and was written, and how many files;
  `window.brickworksBoot` when each stage of the start was reached
  (`Main._boot_mark`: ready, catalogue, ui, model, on the page's clock).
  The bin's All listing ranks each part once before sorting
  (`PartsBin._sort_for`): the same order in 0.44 s natively, where it
  took 1.2.
- `first visit load check` (`tools/web/load_check.mjs`, `[load]` in
  preview_checks.sh, alone): three cold loads of `/app` on broadband (20
  Mbps, 40 ms), each in a browser on a profile of its own on disk, signed
  in: every file as sent with its encoding and cache header, and the
  medians of when the engine started, its first frame, when the bin was
  usable (its search and first tile told to the page, and `found`), when the
  build's last byte came (net), the main thread's CPU before then (Chrome's
  ThreadTime, which load does not stretch), and the bytes before it.
  `--profiles=broadband,slow --warm` for the full table; `--laps` prints
  every `brickworksBoot` mark. Exit 1 over `--max-bytes` or
  `--max-interactive`. Not a flow's incognito context: its cache keeps no
  file over a few MB, so a warm load there fetched the pack again; and the
  visit counter is blocked, not routed, since a route turns the cache off.
  Measured live m167 against load250's preview, three cold loads each
  taken in turn (2026-10-24, load 12-35): 31.1 MB before interactive
  against 17.0 (14.4 to start, the later parts 2.6 during it); net 14.5 s
  against 6.6; interactive 30.3 s against 20.2, the bin drawn 28.0 against
  17.7; the main thread 13.4 s on a CPU against 10.5. What is left is the
  start itself: from the engine's banner to `Main._ready` 4-7 s (scripts),
  the catalogue 1-2 s, the interface 2-3 s, then the frames on SwiftShader.
  `[load]` holds 20 MB and 28 s, and `--pick=3039 --max-pick=6`: a part of
  index.parts.bin taken from the bin as soon as it is usable, in hand with
  its ghost within 6 s of the click (a part of it asked for before it is
  written in waits for it, `PartLibrary._later_coming`, 15 s at most).
  After m168, five rounds by `tools/release/timing_ab.sh` with
  `load_check --warm --pick=3039` against live m168 and 6e3fb3f9's preview
  (2026-10-25, load 14-40), medians (ranges): cold 33.8 s (24.3-36.9)
  against 22.4 (17.4-24.8); warm 16.8 (9.6-20.2) against 11.0
  (10.4-18.0); the first pick 1.2 s (0.6-1.4) against 1.3 (0.6-2.2) cold
  and 0.3 (0.3-1.3) against 1.2 (0.7-1.6) warm, the later parts written
  0.1 s after the bin was first drawn in all ten, so no pick waited for
  them and none fetched 3039 alone.
- `POST /api/mcp` — the Claude connector relay: someone on a Claude plan adds
  Brickworks to Claude as a connector (claude.ai and the Claude apps, or
  `claude mcp add --transport http`), and asks Claude to build. **Two ways
  in** (2026-10-11): `https://brickworks.diy/api/mcp`, one address for
  everybody, which Claude signs in to with OAuth (`api/oauth.js`, see
  [account](account.md)) — each call then goes to that account's open tab on
  any device (`accountTabs`; which tab, exactly, is below; the handshake and
  tool list from that tab, else the account's last, else the fullest recent
  one, so Claude can add it before the app is opened) — and one tab's private
  address (`/api/mcp?t=<token>`), the way from 2026-10-09, still answered for
  everyone who added one (`oneTab`).
  **Several tabs, one account** (2026-10-13): each tab is a connector of its
  own (its token is kept in its own session, see [model-io](model-io.md), "a
  session per tab"; one token per browser had made a second tab take the
  connector from the first), registered with its short id and its model's name
  (`&tab=` on `op=hello`, `&model=` and `&used=` with `op=state` and
  `op=next`, the model as each answer left it from the answer's `_meta`;
  columns `tab`, `model`, `used_at` of `relay_tabs`). The relay answers two
  tools of its own beside the app's, and every tool of the app's takes one
  more argument (`toolsWithTabs`): `tabs` lists the open tabs (id, model, in
  view or not or paused, used how long ago, which one this session's calls go
  to); `select_tab` moves this session to another; `target` does one call in
  the tab named. With no choice, a session's first call went to the tab the
  person used most recently (the page counts presses and focus,
  `brickworksUsedAgo`; the desktop, the window having focus); since
  2026-10-17 that holds only with one tab open, and with several a change
  waits for a choice ("Two chats, two tabs", below). Once chosen the session
  stays there (`relay_picks`, keyed by the `Mcp-Session-Id` handed out at
  initialize, or by the connection for a client that sends none, for two
  hours), so the person clicking into another tab while Claude works does not
  split the work between two models. Every answer from a tab begins "Tab k7qd,
  “House”." and, when there are others, "2 other tabs are open; tabs lists
  them." A target no tab has, or a session's tab that has closed, is refused
  saying so with the open tabs listed, nothing done anywhere; told once, the
  session's next call goes to the tab used most recently, named.
  **`open a tab by link`** (2026-10-15, `src/boot/shell.html` `claimTab`):
  `/app?tab=<id>`, which Open in Brickworks in the model in Claude opens. Kept
  in this browser and not open, the page takes that session up (its model
  comes back); open in another tab of this browser, the page starts no engine,
  says "Your model is open in another Brickworks tab in this browser", and
  that tab is asked over `BroadcastChannel("brickworks-tabs")` to come forward
  (`window.focus()` where allowed; its title says "● Your model is here" for
  six seconds); kept nowhere here (another computer), the link opens
  Brickworks as `/app` does. Prove it in a browser: open `/app`, read
  `window.brickworksTab`, open `/app?tab=<it>` in a second page of the same
  context — that page has `window.brickworksElsewhere` set and no engine, and
  the first page's title flips; close the first, reload the second, and it
  takes the same id. The relay
  tables are in `supabase/relay.sql` (applied 2026-10-13). `src/dev/tabs_probe.gd`
  proves it (below). With no `t` and no good token: 401 and a
  `WWW-Authenticate` naming the protected resource metadata. Claude
  is the client, on the person's own plan; Brickworks never sees a login, a
  Claude token or a key, and never calls a model — Anthropic's terms allow exactly
  this (a product may not offer Claude.ai login or route plan credentials;
  an end user using Anthropic's own apps is ordinary use). The function only
  carries JSON-RPC between Claude and the tab through `supabase/relay.sql`
  (rows keyed by the token's SHA-256, swept after ten minutes, row security on
  with no policies, public keys refused). The tab answers with
  `CommandSocket.answer_rpc`, the code behind the desktop's MCP port, so tools
  added later reach Claude unchanged.
  **A browser pauses a tab it is not showing, and the person is in claude.ai
  while Claude works.** Found on the first real use (2026-10-10), and again by
  the owner the same night: Claude said Brickworks was not connected while it
  was, and a tab brought back into view did not resume. Three causes, all
  fixed: the relay judged a tab open only by the app's own requests for work,
  so a tab building a large design, or just woken, was "not open" after 45 s;
  a tab out of view stopped the app, so every call failed; and a request for
  work in flight as the page slept never completed, so the woken tab stayed
  deaf. Now, while the connector is on, the page keeps the app running out of
  view (`ClaudeConnector._watch_the_page`): the engine asks the page for each
  frame, and out of view the page gives it one from a worker's clock — one at
  a time, 33 ms after the last has run (a clock that ticked regardless ran
  frames back to back and starved the replies carrying the answers). The same
  worker sends `op=state` every ten seconds, which also counts as seen, so the
  relay judges a tab by its page: alive is ready, in view or not; a page that
  stopped altogether is "paused" if it was out of view and "not open" if not,
  and a call nobody takes says so after 30 s instead of four minutes. A
  request for work outstanding over 45 s is replaced (`STALLED_MS`). The tab
  still sends its initialize and tools/list answers when it switches on
  (`op=hello`) and the relay answers those itself; `op=close` goes by
  `sendBeacon`; a call taken and not answered is handed out again on the next
  ask; the newest page load to switch on (`&i=`) takes over and an older one
  gets 409. The address is kept with the tab's session (`ClaudeConnector._file`) and the
  connector resumes on load, so it is added to Claude once. The relay is the
  page's own site on the web, and on the desktop `Deployment.api_base()` — the
  live site or `BRICKWORKS_API`, the deployment the account signs in to (it was
  always the live site, so a desktop signed in to another deployment said
  hello to the live one with a session it could not know).
  **A connector belongs to an account** (2026-10-11): `op=hello` carries the
  session's access token (`ClaudeConnector._hello`, from `Account.access_token`)
  and is verified with `api/_auth.js` (Supabase's ES256 JWKS); without it, 401,
  and the tab switches off saying to sign in. The account becomes
  `relay_tabs.owner` (a column, `supabase/relay.sql`, applied to the live
  project 2026-10-11); an address another account owns gets 403, and the tab
  says to make a new address. `op=next` hands no work to a channel with no
  owner (401, and the tab says hello again), and a tab with no owner counts as
  closed to Claude, so rows from before the change read as switched off until
  a signed-in page switches them on. The tab resumes the connector only once
  somebody is signed in, and Sign out switches it off. The owner is what a
  call signed in to an account is routed by. Prove it: `node
  tools/web/relay_server.mjs 8790` (the real handlers, real queue, needs
  `.env`; it serves every route in `api/`) and `godot --headless --path .
  --script src/dev/connector_probe.gd -- 8790`: refused signed out (by the app
  and by the relay: hello without a token or with a made-up one 401, next for
  a tab that never said hello 401), signed in and switched on with the owner
  recorded, handshake, takeover, another account's hello 403, out of view and
  alive (answers), busy past the relay's patience with its page alive (not
  called closed — the owner's bug), a page frozen out of view (told paused, in
  under a minute), dropped and re-taken, closed, and off after Sign out; then the same through
  the account's address — Claude signed in with OAuth as the probe's account
  (registration, a code approved with the session, PKCE, tokens), its calls
  answered by the app's own tab with no address of the tab's ever given to
  Claude, a call told no tab is open once the tab is off, and refused after
  Disconnect. `tools/web/oauth_probe.mjs` covers the OAuth endpoints
  ([account](account.md)).
  **`tabs probe`** (`src/dev/tabs_probe.gd`, the same relay and `.env`, `--
  8790`): one throwaway account with three tabs open in one process (three of
  the app's own connectors, each with its own world, assistant, answering
  socket, tab id and model: House, Castle, Lighthouse) and Claude signed in
  with OAuth. All three switch on, none taking another's place; initialize
  hands out an `Mcp-Session-Id`; the tool list has `tabs` and `select_tab`
  and every app tool takes `target`; `tabs` lists the three with their
  models and says a first call goes to the tab used last (the probe says each
  tab's use as its page would, `op=state&used=`); the first call goes there
  and names it, and the session stays there when the person clicks into
  another; an edit with `target` lands in the house alone, read back from
  every tab's world and over the relay; a target no tab has is refused;
  `select_tab` moves the session; a second session keeps its own choice; and
  the lighthouse's tab switched off mid-session makes the next call say it has
  closed, with nothing done anywhere, and the call after go to the tab used
  last, named. Against the relay of before (`api/` as it was at cc5294e,
  served by that commit's `relay_server.mjs`, 2026-10-13) 25 of its 31 checks
  fail: no session id, no tabs tool, no names in the answers, and the edit
  meant for the house landed in the lighthouse. A headless app says nothing
  of being used (`ClaudeConnector._used_ago` is -1: a headless window claims
  focus, and every tab then looked used just now). A tab's long poll that
  takes a call as its page closes hands it back (`nextForTab`), and a call
  waiting on a tab that has said it closed is answered at once, not after
  four minutes. Real Claude Code went through the private address
  first (2026-10-09): `claude -p` with
  `--mcp-config` naming the address (type http), `--strict-mcp-config` and
  `--tools ""`, asked for a 2x4 brick's part number, initialized, listed,
  called `search_parts` in the tab and answered 3001. On a deployment,
  `tools/web/connector_flow.mjs` does it for the private address, as a person and as Claude: Private address, its switch
  and Copy in a real browser, the address off the clipboard, then initialize,
  tools/list and real calls through the deployed relay; then the page out of
  view with its frames stopped (a browser driven from a test never hides a
  page — Playwright launches Chromium never to — so an init script gates
  requestAnimationFrame the way a hidden tab's browser does; faked with
  document.hidden alone it passed while the real thing failed): a search and
  a design answered out of view, still answering after more than a minute,
  and at once back in view; then a reload, after which the same address
  answers with nothing pressed. Against the build before the fix it fails all
  four out-of-view checks.
- **Two chats, two tabs** (2026-10-17, `api/mcp.js` "Two chats, two tabs";
  `docs/CONNECTING.md` "Several tabs"). A chat that has chosen no tab, with
  several open, is answered "Nothing was done: 2 Brickworks tabs are open and
  this chat has not chosen one" before its first change, with the tabs, which
  chat holds each and for how long, and how to choose; a look (`readOnlyHint`
  in the tab's list, or the viewer's own) goes ahead in the most recent tab no
  other chat holds and says so, binding nothing. One tab open: it works there.
  `select_tab` and `target` take an id or a model's name ("the castle tab":
  `plain`, `named`; two matches are listed, never guessed), and a target binds
  a chat that had not chosen. Each chat's pick keeps `called_at`, `did` and
  `moved_at` (`relay_picks`, `supabase/relay.sql`, additive); a chat holds its
  tab for 30 min after its last call (`HELD_MS`). The tab is told its chats
  (`brickworks/chats`, sent when one chooses or leaves it; the chat on each
  call's `_meta` as `brickworks/chat`; `op=chats` as it switches on), and
  `op=keep&chat=` moves every other chat off: the other's next untargeted call
  is answered "The person moved this chat off tab …", nothing done, until it
  chooses. An answer in a tab another chat holds says "Careful: another chat
  has been working in it…". With more than one tab open, `select_tab`'s answer
  and `target`'s description ask Claude to pass `target` on every call
  (`SAY_TARGET`): claude.ai is reported to reuse one `Mcp-Session-Id` across
  chats, and two chats on one key are one chat here. Real Claude Code
  (`claude -p` with `--mcp-config` naming the local relay and a token,
  `--tools ""`, two at once, each told one stand-in tab's first message and to
  add a brick) called `select_tab` with its tab's id, then targeted every
  call, each building only in its own tab (2026-10-17; the run's log is in
  `bench/results/tabpair-2026-10-17/claude_pair2`). Undo per chat: each step a
  chat's call makes carries `by` (`CommandSocket.CHAT_KEY`, `_mark`), and the
  `undo` tool stops at a step another chat made, saying so
  (`AppTools._undo`, `AppTools.chat`).
- `this tab and its claude chats` (`src/ui/claude_tab_view.gd`, in Account's
  Claude part and the assistant panel's "Or with your Claude plan"; the
  toolbar's line from `ClaudeTabView.badge`, `ModelBar.show_claude_tab`):
  "This tab is k7qd (“Castle”). Say it to Claude to work here."; "No Claude
  chat is working in this tab." / "A Claude chat is working here: since 14:05,
  last: changed the model at 14:07." (a time of day, so nothing on it runs on
  a timer: `chat_probe`) / "2 Claude chats are working in this
  tab…" with Keep this one beside each (`ClaudeConnector.keep_chat`). New chat
  for this tab opens `https://claude.ai/new?q=` with
  `ClaudeConnector.first_message` ("Use my Brickworks tab k7qd (“Castle”) for
  this chat."), and copies it; the Claude app `claude://claude.ai/new?q=`
  (followed in place on the web, so no empty tab is left); Claude Code
  `claude-cli://open?q=` and the command line `claude "…"` to copy. The
  toolbar reads `Tab k7qd`, `Claude working · tab k7qd` or `2 Claude chats ·
  tab k7qd`, and opens Account. The page says it all in
  `window.brickworksClaude` (`tab`, `chats`, `badge`, `account_says`,
  `first_message`, `opened`).
- `two chats probe` (`tools/web/tabpair_probe.mjs`, `--url=` a local relay or
  a preview): two stand-in tabs (the relay's side of a tab only) and six
  sessions: a new chat stopped before its first change with
  neither tab asked anything, a look made and binding nothing, `select_tab
  "the castle tab"`, a target by id binding chat B, chat C told "Careful" in
  the held castle, the castle hearing two chats (`op=chats` and
  `brickworks/chats`), `op=keep` moving C off and C told so twice with the
  castle asked nothing, `select_tab "cast"` matching two and choosing
  neither, and two chats on one session each landing in its own tab by
  `target`; then a resumed chat (a new session, as Claude Code makes one on
  `--resume`) stopped and told it is a new chat here that cannot undo what it
  did before, as chat B's first choice is and chat A's, the account's first,
  is not, and `server/discover` answered "method not found" by the relay
  with no tab asked. 36 checks, seconds; deletes its throwaway account.
- `two windows probe` (`src/dev/tabpair_probe.gd -- 8790`): the desktop's side
  — two windows as two of the app's connectors in one process, each with its
  own world and socket and a fresh `TabSession` id: the three links and the
  command line name the window; a chat stopped, chat A in the castle by name
  and chat B in the truck by id, each model alone growing; each connector
  hears its chat and `ClaudeTabView.badge` says so; a third chat makes two,
  `keep_chat` moves it off, its next call changes nothing. 19 checks.
- `two chats browser flow` (`tools/web/tabpair_flow.mjs`): the app in two
  Chromium tabs of one throwaway account (house renamed Pair Castle, kart
  renamed Pair Truck), Claude signed in with OAuth, three sessions. Each
  toolbar reads `Tab <id>`; chat A's first change is stopped and neither model
  changes; Account's New chat for this tab in each tab opens
  `claude.ai/new?q=` (claude.ai is routed to a stub page, so no test reaches
  it) with that tab's first message, and the Claude app's and Claude Code's
  links name it, the page staying put; A chooses "the pair castle tab", B
  reads the truck's id off its first message and targets it, each change
  landing in its own page alone; each tab's toolbar and Account then name its
  one chat; C chooses the castle, whose toolbar says 2 Claude chats, C's
  `undo` leaves A's change standing, Keep this one beside A is pressed in
  Account, and C's next call is told it was moved
  off with the castle unchanged, A building on. Pictures `1_castle.png`,
  `1_truck.png`, `2_two_chats.png`, `3_kept.png`. In
  `tools/release/preview_checks.sh` as `tabpair` and `tabpair_probe`; both
  passed on preview brickworks-otcd0v1a2 (2026-10-17), with `tabs`,
  `list_changed` and `oauth`. And by real Claude in real tabs: on that
  preview, two tabs (Castle, Fire Truck) each pressed New chat for this tab,
  and two `claude -p` sessions run at once were each given its tab's first
  message and asked for a brick: each called `select_tab` with its own id,
  targeted every call after, and built in its own model alone (71→72,
  44→45), each toolbar reading `Claude working · tab <its id>`
  (`bench/results/tabpair-2026-10-17/claude_tabs`).
- `two real chats walk` (`tools/web/tabwalk_flow.mjs`, local only: it spends
  the Claude plan for about 15 minutes, marked so in `preview_checks.sh`).
  Start a local relay with the web export (`node --env-file=.env
  tools/web/relay_server.mjs 8920 --static=build/web`), then `node
  --env-file=.env tools/web/tabwalk_flow.mjs --url=http://127.0.0.1:8920/app
  --out=DIR`. One Chromium, one throwaway account with Claude Code signed in
  by OAuth; tab A emptied by File > New, tab B by File > New tab; each tab's
  New chat for this tab gives the first message. Two `claude -p` sessions on
  the subscription (stream-json in and out, Brickworks their only tools) are
  sent "<first message> Build a small house" and "... a small car" at once,
  then "change one small thing", then "Undo that change"; a third, told no
  tab, "Add a tree to my Brickworks model", then "The house tab." Checks:
  every answer each chat got names its own tab and never the other's; each
  tab's toolbar says one chat, different chats; both undos leave the stored
  model's parts as built; the third chat changes nothing and asks; the tree
  lands in A only, whose toolbar then says `2 Claude chats`; both tabs
  reloaded keep every part shown. Transcripts `chat1_house.jsonl`,
  `chat2_car.jsonl`, `chat3_tree.jsonl`, pictures `<stage>_<tab>.png` (and
  `_account.png`), `stages.json`. The first walk (2026-10-19) found a
  minifigure Claude stood up lost on reload (`CommandSocket.model_changed`).
- `progress check` (`tools/web/progress_check.mjs`, 2026-10-12): presses each
  slow thing in Chromium on SwiftShader and times it against the press's own
  time in the page. Judged, as the app's own work on a CPU (each engine
  frame and input handler's `tdur` in Chrome's trace, found by a stamp of
  the page's clock; 2026-10-22, since by the page's clock m145 and m146
  both failed at load 26-52): `said`, its work from the press through the
  frame the status bar's bar (`Working`) was begun in (`window.brickworksWork`'s
  first drawing less its `ms`), and `own`, its longest piece of work in one
  go (a press can be handled outside a frame, and Timeline's was). Said and
  not judged: `heard`, how long before the bar was drawn by the page's clock
  (a build without the bar is read by its page state, polled, and marked ~;
  on a busy box that frame waits seconds on the software drawing before it),
  `own`'s page-clock figure less WebGL or the slowest frame by the app's own
  clock (`brickworksState.slow`, labelled with what `Working` said), the
  longest engine frame callback (as `render_open_check` times them, WebGL
  calls included) and the longest the page ran no timer; the total; and that
  the bar is gone.
  That last is why the bar is not redrawn until the card has drawn its last
  change (`GpuFence`): every 250 ms regardless, as first written, Orthanc's
  timeline took 77 s instead of 8, software drawings of the whole tower
  queued up behind each other. The parts bin is timed until the page has gone
  quiet after it, since it opens at once and then draws its pictures (the
  quiet is the engine's frames, not the pictures: with them read back after
  the card's fence the next press can come while the bin is still drawing,
  and its bar then waits for the card too). Each time a picture read back
  holds the drawing (`GpuFence.finished`), the page is told when and for how
  long (`window.brickworksHolds`, [engine ms, ms held], the last 200): the
  parts bin's previews are drawn a screenful a frame
  (`PartThumbnails.STAGES`, 32), and after Orthanc opens in Chromium on
  SwiftShader at load 40, where a frame of it takes the card 12 to 14 s, the
  drawing was held until 53 s after the open eight at a time, and is until
  23 s (fences timed in the page, 2026-10-15). Each hold is one frame of the
  whole model drawn in software: a preview is drawn in a frame of the
  window. A first visit's car: the parts bin's first open,
  Instructions, Render, LEGO Art's Build of art_flow's galaxy at 48 across,
  Brickify of the bunny; then Orthanc opened from a file: Timeline, Save
  (the toolbar's), File > Export > LDraw (typed into the menus, as a person
  finds them; a space in a menu presses the item it is on, so only words), the toolbar's Select by > Same colour from one part, Shift-M Mirror
  and Shift-E of all of it, Tools > Check stability, Delete of all of it,
  Undo, and New's "Save, then start new" (`brickworksControls.new_save`; the
  owner's freeze, 2026-10-13; a build without that control is not
  measured, and plain New is then, as `--only=new` asks). The commands after
  Timeline are the ones `src/dev/command_probe.gd` found holding the window
  longest. Fails when one that should show the bar does not, or does over
  `--said` ms (150, `Working.SAY_FIRST_MS`) of its own work first, when
  Timeline, the booklet, Art or Brickify has work of its own over `--budget`
  ms (300) in one go, or a bar is left up. Six runs of m145's and m146's
  builds at load 26-52 did at most 82 ms before a bar and 241 ms in one go;
  CPU time stops growing with the load once all 24 threads are busy. An
  Export that worked out its file before beginning its bar failed with
  6,970 ms before it.
  `--model=FILE --parts=N` opens FILE (N parts) where Orthanc is opened:
  with `--only=timeline` and a model whose author's steps are taken out, the
  timeline's total is the planner's time in the browser
  (`Instructions.plan_paced`; planspeed, 2026-10-17, 76161 without its
  `STEP` lines, `bench/results/planspeed-2026-10-17/`).
  What the long frames at a job's end were, which no timer had caught
  (2026-10-15): Brickify put the whole bunny down in its last frame (its
  slice was asked before each part but spent only by putting them down); the
  hover asked whether a 170-part Brick Art panel under the pointer was a
  figure and threw the answer away (`Builder.takes`), the first such question
  building the figures' index in one go (`Minifig.index_paced` now, for the
  Timeline); and Brickify's bar came a second late because the pointer leaving
  a part let go of the outline's window-sized render targets in the frame of
  the press, and a browser waits for the card to finish before it makes new
  ones. `SelectionOutline._size_targets` now tells the RenderingServer a size
  of nothing, which frees them and makes none; let go of four seconds later
  instead, it was a frame drawn for nothing that held Mirror's press 2.7 to
  10.8 s on Orthanc (`outline_probe` checks the memory goes at once and no
  frame is drawn after). A frame
  that waits in WebGL is named by the call it waited in: wrap the context's
  methods and sum by name, as `instrument()` does by frame; `checkFramebufferStatus`
  is a render target made. `--report-only` prints
  the table for a build from before. Leaves `progress.json` and a picture
  after each press in `--out` (shots/progress).
- `GET/POST /api/share` (`api/share.js`, `supabase/shared_models.sql`, applied
  to the live project 2026-10-12): a model shared by link (2026-10-12). POST
  with a session publishes `{name, author?, model, image?, id?}` and answers
  `{id, url: <origin>/m/<id>, image, viewer, embed, parts}` (201; 200 and the
  same id when `id` is the caller's own, which also republishes a link taken
  down). Checked at the edge before anything is counted or stored: LDraw text
  only (every line one of the six line types and well formed, no control
  characters, at least one part, no sub-model inside itself), at most 2 MB
  (413), a PNG picture of at most 600 KB, a name; the part count is the
  server's own, through sub-models (`.dat` sections are parts, and so is a
  sub-model of nothing but one flexible part's segments, `FLEX_PIECES`, as the
  parts list counts it; `inventory_probe` runs `checkModel` on a file the app
  wrote). Refusals 415
  with the line that failed, 403 for another account's link, 404 for none, 401
  signed out, 429 past 20 publishes an hour or 60 a day for one account
  (`may_publish`, counted in Postgres). `POST ?op=unpublish&id=` (the owner):
  the row stays, unpublished, and both files are deleted. `GET ?id=` is the
  viewer's one request (name, author, parts and the `.mpd`, `no-store`); 410
  `unpublished: true` once taken down, 404 for a link that never was. `GET
  ?op=mine` (session): the account's links, and `credit`, whom Show who made
  it credits (`{name, handle}` of their profile shown in public, or null),
  which the app's Share panel offers. A credit is the profile: published by
  an account with one, `author` is kept as the profile's name whatever was
  sent; with none, a name made from the sign-in address (the app before
  m157 offered "Delivered+walk 180 Web") is refused 422. Every page and
  answer says the credit by the profile's current name (`creditName`): the
  licence line with its `@handle` link, the description, the JSON-LD author
  with the profile's url, the embed card and the viewer's `author`. `/m/<id>` (`op=page`) is the
  link's page: og/twitter tags (title, the part count and author, the picture),
  the picture and the way in, and `web/share-page.js` sends a person straight
  on to `/app?view=<id>`; its own CSP, not frameable. `/m/<id>.png`
  (`op=image`): the picture the app rendered, `Cross-Origin-Resource-Policy:
  cross-origin`. `/m/<id>.cutout.png` (`op=cutout`, 2026-10-24, docs/SOCIAL.md
  U15): the same with nothing behind the model, posted as `cutout`, which the
  page's picture shows on `--picture-ground`; the PNG itself for a model
  published without one (an app before, or every model before that day), and
  `/m/<id>/v/<n>.cutout.png` a version's, copied to `<id>.v<n>.cutout.png` on
  a republish, deleted with the rest; a republish with none deletes the old
  one. `made_with` (U16, `supabase/made_with.sql`, the server's alone): hand,
  assistant or brickify, as the app says (400 for anything else), kept by a
  PATCH of its own that never stops the publish (nothing before the file is
  applied) and answered as `made_with`; not said, it stays as it was.
  `share_probe` checks both. Every answer here was `no-cache` or `no-store` until the directory (now `SHARED_CACHE`, below): the picture was
  `public, max-age=60` until the probe on a preview found Vercel's CDN still
  serving it after the model was taken down. `/m/<id>/embed` (`op=embed`): a card for an iframe
  (`frame-ancestors *`) whose links each open a tab — the threaded engine
  cannot run in somebody else's page, which cannot be cross-origin isolated:
  its picture and name the model's page, **Build it** (`.cta.small`) the
  guided build at step 1 (`/app?view=<id>&build`, as the page's Build it),
  and View in 3D a quiet `a.link` to the viewer, hidden in a frame under
  400 px. `model_page_flow` step 15 holds the links at 560 px and the bar
  whole at 340 px; `share_probe` the links in the markup.
  **Who can do what:** a visitor's read asks, as the server, for a published
  row's public columns alone (`api/share.js` `publishedRow`; until oc205 it
  went through the publishable key and `shared_models_read_published`, and
  `supabase/no_client_access_models.sql` takes that away once oc205's release
  is live: the key a page holds then reaches nothing in the database,
  `supabase/no_client_access.sql`); the bucket `shared-models` is private with no policies, and the
  function reads a file with the secret key only after that read; every write
  is the function's, after the session is verified and the row found to be the
  caller's. Rows (and the publish log) go with the account. Its files cannot
  (Supabase refuses to delete storage objects from SQL), so Vercel's cron calls
  `/api/share/sweep` (`op=sweep`) at 04:17 UTC daily with `CRON_SECRET`, and it
  removes every file an hour old or more that no published row owns.
  **The gallery** (2026-10-13, `supabase/gallery.sql`, applied to the live
  project that day with `tools/apply_sql.mjs`: columns `listed` boolean not
  null default false, `listed_at`, `remixed_from` → `shared_models(id)` on
  delete set null, `barred` boolean not null default false; select granted on
  the first three to `anon` and `authenticated`, never `barred`; index
  `shared_models_gallery` on `(listed_at desc, id desc) where listed and
  published`; table `share_listings` and `may_list` (6 an hour, 20 a day,
  `service_role` only), as `share_publishes` and `may_publish`; no existing row
  changed). The POST also takes `listed` (true or false, else 400) and
  `remixed_from` (a link's id, else 400; one that is not there is stored as
  none; once said it is kept on a republish that does not say), and answers
  `listed`, `remixed_from` and `gallery`. Going into the gallery is counted
  (429 past the limit, before the publish is), staying in it is not;
  unpublishing takes a model out of it. `GET ?op=list&page=1..400` (400
  otherwise): the listed, published rows through the publishable key, newest
  listed first, 24 a page and `more`, each `{id, name, author, parts,
  listed_at, url, image}` (`image` null with no picture), `no-cache` then (`SHARED_CACHE` since the directory). `/m/<id>`
  says "Remixed from <a href=/m/X>title</a>" while X is published, and `GET
  ?id=` gives `remixed_from: {id, name, url}`. The site's owner takes a model
  out (`POST /api/admin?op=unlist&id=`, [account](account.md)): `listed` off
  and `barred` on, its link untouched; its owner listing it again is refused
  409 (not 403, which the app answers by publishing at a new link). A name is
  one printable line of at most 80 characters (the table's own check too),
  escaped by every page that shows it and put in as text by `gallery.js` and
  the admin page.
  **Test models** (2026-10-17, `supabase/test_models.sql`, applied to the live
  project that day with `tools/apply_sql.mjs`, dry-run first; the project has
  no migration table, so it is recorded here): column `test` boolean not null
  default false, never granted to the publishable key. A publish from a session
  at a Resend test address (`@resend.dev`, `isTestAccount` in `api/_auth.js`:
  every probe and flow signs in at one, nobody else can) writes `test: true`.
  No public list shows a test model: `directory_models` leaves them out
  unless the query says `tests` (or `private`, an owner's own view);
  `profile_page(wanted, tests)`, `collection_page(list, tests)` and
  `collection_count(list, private, tests)` are new forms beside the old,
  which are now those forms without tests; `sitemap_pages` never lists one,
  nor a profile or a collection with nothing else; a model's page lists a
  test remix only when it is a test itself (`directory_model`). `?tests=1` on
  `?op=list`, `/api/people?op=profile|collection`, `/u/<handle>` and
  `/c/<id>` (anything else but 0 or false: 400) shows them, answered
  `private, no-store` so the CDN never keeps it; the parameter is in the
  address the CDN keys on, so a visitor's list is never that answer. A test
  model's own page and link work as any other. Rows from before the release
  that marks them are all false: the live site shows that release's probe
  models until it ships.
  **The directory** (2026-10-13, `supabase/directory.sql`, applied to the
  live project that day with `tools/apply_sql.mjs`, dry-run first with
  `--dry --try=FILE`, which rolls back): columns `description` (1 to 1000
  characters), `tags` (`text[]`, at most 8 of 2 to 24 characters, lower case,
  `directory_tags_ok`), `licence` (`cc-by-4.0`, `cc-by-sa-4.0`,
  `all-rights-reserved`, or null for a model shared before there was a
  choice — its page says no licence was chosen), `kind`, `steps`,
  `own_steps`, `technic`, `has_thumb`, and `search`, a stored tsvector
  (`directory_words`: the name and tags A, the credit B, the description C,
  the 'simple' configuration); select granted on all but `search`; GIN
  indexes on `search` and `tags`, and indexes on `kind` and `remixed_from`;
  tables `model_stats` (views, likes per model) and `model_views` (a model, a
  day and a 32-hex visitor key, kept two days by the sweep), both closed to
  the publishable key; functions `count_view`, `directory_card`,
  `directory_models(query jsonb)` and `directory_model(model_id)`, all
  security definer and `service_role` only, each saying for itself that a
  model is listed, published and not barred; a private bucket
  `shared-thumbs` (WebP only, 64 KB), so `shared-models` was left as it was.
  No existing row was changed. The POST also takes `description`, `tags` (a
  list, or words between commas), `kind`, `licence` and `thumb` (base64 WebP),
  each refused 400 (415/413 for the picture) when it is not one, each kept as
  it was on a republish that does not say it, and answers them with `steps`,
  `own_steps` and `technic`, which the server counts from the file
  (`checkModel`: the main file's steps split by `0 STEP`/`0 ROTSTEP`; its
  builder's own when the file has steps and either `0 !BRICKWORKS
  AUTHORED_STEPS` or an `0 Author:` other than Brickworks; Technic or a
  mechanism when two or more parts make it move or a quarter of it, ten parts
  at least, is Technic, by `partFacts`). A version of a CC BY-SA model must be
  CC BY-SA, and one of an all-rights-reserved model cannot be listed: 422,
  never 403. `GET ?op=list` takes `q` (at most 100 characters; each word of
  two letters or more a prefix, a plural its singular, nothing but letters
  and digits reaching the query), `kind`, `size` (`small` under 200 parts,
  `medium` 200 to 999, `large` 1,000 or more), `instructions=1`,
  `technic=1`, `tag`, `sort` (`newest`, `views`, `likes`, `remixes`) and
  `page`, each 400 when it is not one, and answers the question as
  understood, `more`, the cards (`directory_card`: name, author, parts,
  kind, tags, licence, steps, `own_steps`, `technic`, `views`, `likes`,
  `remixes`, `url`, `image`, `thumb` as `/m/<id>.webp?v=<updated>`; never the
  owner or the description) and the `kinds`, `sizes` and `sorts` it knows.
  `POST ?op=seen&id=` counts a view of the page: once per visitor per day
  (an HMAC of the day, the model, the address and the browser, so nobody can
  be followed from one day or one model to the next), only for a browser's
  own fetch from this site (`sec-fetch-site: same-origin`) whose user agent
  is not a robot's, a link preview's, a command line's or a headless
  browser's; it answers `{counted}` and nothing else. `/m/<id>.webp`
  (`op=thumb`) is the small picture.
- `GET/POST /api/people` (`api/people.js`, `supabase/people.sql`, applied to
  the live project 2026-10-13 with `tools/apply_sql.mjs`, dry-run first; the
  first dry run found `public.profiles` already there — schema.sql's, a row
  per account with its address — so the profile is `public.people` and that
  table was left exactly as it was): tables `people` (account, handle 3 to 24
  of a-z 0-9 and single hyphens, name 1 to 40, bio up to 300),
  `model_likes`, `model_favourites`, `model_collections` (a 10-character id,
  name, description, public), `model_collection_items`; all closed to the
  publishable key; a trigger keeping `model_stats.likes`; `directory_card`
  answering `by` {handle, name} for a credited model whose sharer has a
  profile; `directory_models` taking `owner` (listed and credited only),
  `collection`, `favourites`, `private` (set by the API for its owner's own
  lists only, letting in models shared by link) and sort `added`;
  `profile_page`, `collection_page`, `collection_count`. Ops: `me`
  (session: profile or null — nothing is made from the address — and lists
  with counts), `profile` POST (handle lower-cased and checked, a few kept
  for the site 409, taken 409, name cleaned, bio cleaned), `profile` GET by
  handle (name, bio, since, models_count, likes, public lists, a page of
  models; never the account), `page` (`/u/<handle>`), `marks` (session:
  liked, favourite, each list and whether it has the model), `like` and
  `favourite` (session, `{on}` true or false else 400, a link that never was
  404, idempotent; a like answers the count), `favourites` (session, sort
  added), `collection` POST (made or changed, 50 a person), `uncollection`,
  `collect` (500 a list), `collection` GET (a private one answers anybody
  else 404, as none; anybody sees only listed models in a public one, its
  owner every published one), `list_page` (`/c/<id>`, public only). HEAD as
  GET. Pages made with the site's header and footer (`siteChrome`, `_site.html`
  beside the function too), cards server-made (`cardHtml`), no script.
- `profile and collection pages`: `/u/<handle>` (rebuilt 2026-10-22,
  docs/SOCIAL.md U5, `api/people.js` `profilePage`, `web/person.js`) — a
  person-shaped page, the same for everybody it shows (the house account
  too, no special case): a banner (`.banner`, one of their models' pictures,
  chosen: its cut-out, `/m/X.cutout.png`, on `--picture-ground` as a card's
  picture is, the PNG itself for a model published before cut-outs; also
  `/profile`'s `#banner-shown`) if any; the head (`header.profile-head`: `.avatar.huge` made from
  the handle by `web/card.js` `avatarHtml` through `api/_card.js`, `h1`,
  `@handle · [data-role] Designer|Builder · since`, Follow, Share
  `button[data-share]` (copies the link, "Link copied" toast; the share sheet
  on a touch screen), More `details.more-menu` with Report it); the bio;
  links (`ul.links`, https, `rel="ugc nofollow noopener"`, said as their
  domain); one row of numbers (`ul.numbers li[data-stat]`: builds,
  remixes, models, likes, followers `[data-followers]`, following, each
  `hidden` at none); wins as pills; Pinned (`.pinned .models.row`, up to
  three, their order); then `nav.tabs` Models · Builds · Collections, each
  a page of its own (`?tab=`; the default the first with something in it),
  a count `.n` once there is one, `.tab-panel[data-panel]`: Models 24 a page
  (`[data-models]`, Show more `a[data-more]` appends the next page from
  `?op=profile&page=N`, a link to `?page=N` with no script), Builds
  (`.builds-made`, `.builds-of`, photos in `.build-grid` columns),
  Collections (`a.list-card`, a `.mosaic` of up to four pictures); an empty
  tab says what goes there (`.state`); whom they follow (`section.follows`)
  only when they chose to show it, never their followers. Links, banner and
  pins: `supabase/profile_shows.sql` (one row an account, cascades from
  auth.users, 13+ by trust.sql's profile trigger; applied to the live
  project 2026-10-22 for m145 with `tools/apply_sql.mjs`, dry-run first, and
  recorded here as the project has no migration table; before it the page
  had none and `POST ?op=showcase` said 503 "not open yet", after checking
  what it is sent); chosen in Edit profile on `/profile`
  (`#showcase` in `#edit-dialog`, shown once `?op=me` says
  `showcase.ready`; a save sends only what was changed);
  `/c/<id>` — a public collection's name, "N models,
  collected by <their profile>", its description and its listed models in the
  order they were put there. Every word escaped; og tags and a canonical link.
- `your profile page` (`web/profile.html`, `web/profile.js`): `/profile`,
  noindex, titled Your profile (2026-10-22, docs/SOCIAL.md U6: your account
  as your profile). Signed out: one line of what an account gives, and Sign
  in (the dialog of `site sign-in`). Signed in with no profile: `#start`,
  the form's two fields (name, handle; `#save` says Make my profile), and
  the tabs Saved · Sets · Insights; under 13 the fields off and `#young`
  says why. With a profile: `#me`, the head `/u/<handle>` draws (banner,
  `.huge` avatar, `#title`, `#handle-line` "@handle · Designer/Builder ·
  building here since", `#bio-shown`, `#links-shown` ugc nofollow,
  `#numbers` with no count of none, `#pinned`), read from `?op=profile`
  with `tests=1` (only ever your own), and Edit profile (`#edit`), Settings
  (`#to-settings`), Share (`#share`: the share sheet on a phone, else the
  link copied and a toast) and More (`#view` your page as others see it,
  `#to-feed`). Then `#tabs`, each a `?tab=` of the address, drawn when
  first opened: Models (8 cards at a time, `#models-more`), Builds (yours
  and others' of your models), and, only yours, Saved (`#favourites` with
  Let it go, `#lists` the collections with Public, Save, Delete, Its page
  and What is in it, `#following`), Sets (`#owned-*`: `/api/collection`,
  `/api/share?op=shelves&mine=1`) and Insights (`#designs`, `designs.js`).
  Edit profile (`#edit-dialog`, or `/profile?edit=1` from Settings and
  from `[data-edit-own]` on your own `/u/<handle>`, which `web/follow.js`
  shows where Follow would be):
  avatar (made from the handle), name, handle, about you, two links, the
  banner and three pins; Save posts `?op=profile`, then `?op=showcase` with
  only what changed, and redraws the page with no reload.
- `your settings page` (`web/settings.html`, `web/settings.js`):
  `/settings`, noindex (the account page's settings until 2026-10-22).
  Signed out: Sign in. Signed in, one `.settings` panel: Profile (`#profile-line`,
  Edit profile to `/profile?edit=1`), Appearance (`#theme-part`), Email
  (`#who`, `#mail-comments` and `#mail-kinds`), Privacy (`#age-said`,
  `#shows-follows`), Claude (`/api/oauth?op=connections`, Disconnect with a
  confirm), Sign out, and Delete this account (`api/account.js ?op=delete`,
  their address typed to confirm: the files of their build photos and of
  photos of their models deleted, then the account, every row of theirs
  cascading; the site owner's refused). people_flow and account_page_flow
  delete their accounts this way; `documentElement.dataset.settings` says
  `ready` or `signed-out`.
- `model page action bar` (`web/model-page.js`, `api/share.js` `actionBar`,
  2026-10-22, docs/SOCIAL.md U4): on `/m/<id>`, `#marks.action-bar`, the
  kit's icon buttons drawn by the server: Like (`[data-mark="like"]`,
  aria-pressed, its count beside it and in its label, "Like, 96 likes"),
  Save (`[data-mark="save"]`, aria-expanded: `#save-panel` opens your lists,
  Favourites first as `label[data-list="favourites"]`, ticked when it is a
  favourite, then each collection, and a new one named and made with the
  model in it; `data-on` and the label "Saved" while it is in any),
  Share (`[data-share]`: `navigator.share` with the page's address where
  the browser has it, else the address copied and the toast "Link
  copied"), Comment (`[data-mark="comment"]`, its count set once the
  comments are listed, the ones everybody sees; to the comments, the box
  focused; hidden where comments are not open), I built it
  (`[data-mark="built"]`, the builds count; to Built by people, opening
  the photo form) and More (`details#more.more-menu`: Copy the embed code
  `[data-embed]`, Report it `[data-report]`, Takedown requests; for the
  model's owner, comments off or on and their numbers instead of Report).
  Like, Save and Comment signed out open the sign-in dialog first and go
  on once signed in. Never a count of none. The page's policy lets it
  reach the sign-in service (`SUPABASE_URL`) as well as itself.
- `more by and similar models` (`api/share.js` `nextOf`, 2026-10-22): the
  end of `/m/<id>`: `#more-by` (the designer's other listed, credited
  models, `directory_models` with `owner`, by Top builds) and `#similar`
  (`directory_models` by its kind and by each of its first three tags,
  ranked by tags shared, then kind, then Top builds; never what anybody
  looked at), each a `.models.row` of cards drawn only with three, six at
  most, and no card the page shows already (the model, its listed
  remixes, More by's); with neither row, `#from-gallery`, More in the
  gallery: the gallery's Top, however few, so the last screen always has
  another model to open. A test model's page offers test models too. A
  database error is no row, never a 500. No new SQL.
- `model page pictures and tabs` (`api/share.js` `mediaStrip`, `pageTabs`,
  `web/model-page.js` `startPictures`, `startTabs`, 2026-10-22,
  docs/SOCIAL.md U4): under the picture, `#pictures.media-strip`: the
  published picture first (`aria-current`), then its owner's own photos
  (`data-own`; build photos posted by the model's owner, through the same
  pipeline, so no new table), then photos of real builds, newest first,
  each a link to its figure under Builds; chosen, it is shown whole in the
  picture's place (`.picture.photo`), which stays the way into the viewer.
  With no photo the strip is drawn hidden, and shown to the model's owner
  alone with `[data-add-picture]` Add a picture, which opens the photo
  form (three an account on a model, as for any builder). Under it,
  `#page-tabs`, the kit's `.tabs`: About (`#about`: its words, tags and
  licence), Comments (counted once listed; hidden where comments are not
  open), Builds, Remixes and, with two or more, Versions, each with its
  count, never one of none; sticky under the header (`.loose`, with no
  ground, until it sticks), the part at the top marked `aria-current`, a
  tab chosen marked until the reader scrolls on. Nothing yet is one line
  and the way in: "Nobody has commented yet." and the box or Sign in to
  comment, "Nobody has built it yet. Built it? Add a photo of yours." and
  I built it, "Nobody has remixed it yet." with Open it in Brickworks.
  `tests/test_model_page.py` makes the stand-in's pages with the real
  handler (no browser): the rows, their order, the bar's names and counts,
  and the page drawn when `directory_models` answers 500. Since 2026-10-26
  (site277) the page is `.wrap.wide` (1,600 px): from 1200 px the column
  is 420 px and the picture the rest (1,140 x 598 at 1920); under 600 px
  the picture's frame is square (358 px tall at 390, 188 before) and
  `model-page.js` `fitPicture` reads the model's columns from a 120 px
  copy of the picture and draws it by `object-fit: contain` and a
  `transform` (no layout shift): cropped round the model when it is no
  wider than the square, else scaled until all of it is in, the picture's
  own sky and ground carried on above and below as the frame's
  background. A photo from the strip is shown whole as before. On the
  live models: the owl and the rocket at x1.9, the rover x1.25, the
  dragon (86% of the picture's width) x1.08.
- `a model's parts and its download` (`api/_parts.js`, `api/share.js`
  `partsSection`, `download`, `web/model-page.js` `startParts`, 2026-10-26,
  site278, docs/SOCIAL.md): on `/m/<id>`, a Parts tab (with the count) and
  `#parts`: "N parts in M lots", Colour · Kind (`[data-group]`), BrickLink
  XML and Rebrickable CSV (links that download), and `ul.lot-list`, asked
  for (`/m/<id>/parts.json`) as the section comes within 800 px of the
  screen or its tab is chosen, drawn into a `min-height` kept for its first
  12 rows of 60 px, `li.group` (a colour's or kind's swatch, name and
  count) over `li.lot` (picture, name, part and element number, colour,
  `× n`), Show all (`[data-all]`) for the rest; `<html data-parts="drawn">`
  once drawn. The list is the app's Inventory.of, ported (`inventoryOf`:
  sub-models expanded, a sticker counted, a Brickworks-laid hose once as
  the straight part nearest its length, an LDCad hose one flexible part,
  a carried part a custom element, a ~ piece, a primitive and a reference
  to nothing not), from the version's stored file, kept per instance by
  file; the facts pill and the tab say its count, so they agree with the
  app. `wantedList` and `rebrickableCsv` are `ShopLists`' two exports, a
  made part or an unnumbered colour left off and counted (`left_out` in the
  JSON). `?op=file` is the stored file as it is, `application/x-ldraw`,
  `attachment; filename="<name>.mpd"` (`-v<n>` for an older version);
  `?op=parts&as=json|xml|csv` likewise named; both signed out, kept by the
  CDN as the page (`SHARED_CACHE`), 404/410 as the viewer's answer. The
  table it needs (`partsTable`): `_parts_table.json` beside the function
  (deploy.sh, `part_facts.mjs --parts`, 4.0 MB with each part's geometry
  hash and each colour's alpha) or the checkout's `assets/generated`.
  Pictures (site304, `web/part-pictures.js`): each lot's `.pic` starts as
  its colour's swatch and, as the row comes within 300 px of the screen,
  the part is drawn over it on a `<canvas>` from the geometry the app
  draws it from (`lot.mesh`, fetched from `root`, the store, at most six
  at once; `web/lbm.js` reads it): WebGL off the page, orthographic from
  the app's parts bin's corner and lights, each surface in its colour
  (`colours`, every code's `rrggbb[aa]`; 16 the lot's), LDraw-style lines
  from each pixel's normal and depth, drawn at twice its pixels and scaled
  down, a few each frame within 8 ms. Kept by part and colour for the
  page's life, so Kind and back draw nothing again.
  `.pic[data-picture="drawn"]` once drawn, `"none"` where it keeps the
  swatch (a part the file carries, a failed fetch, no WebGL). No image is
  loaded: the policy's `img-src` stays `'self'`; `connect-src` names the
  store's origin (PARTS_URL, today the Supabase project already there).
  The module (`/part-pictures.js`) is asked for beside `parts.json`, so a
  visit that never nears the list loads neither, and the list is drawn
  without waiting for it: the pictures come over the swatches once it is
  here. On 10243-1 (393 lots, Parts clicked at load, the stand-in, five
  runs) the list is drawn in a median 46 ms at 1280 and 51 at 390 (42 and
  43 before; single runs 22-126 either way) and the first screen's
  pictures by 271 and 323 ms; scrolling Show all to the end draws 386 (7
  carried parts keep their swatches) with no frame over 100 ms (before:
  the one Show all frame, 88-92 ms). Download is `.side .actions a[download]`. Like and I
  built it are `.icon-btn.labelled` (their word in `.word`). Checked by
  `parts page probe` (against the app: each lot's geometry the app's own,
  read into triangles in its colour) and `model_page_flow` step 16 (the
  page, the files, the space kept, each lot's picture read pixel by pixel
  and the policy).
- `parts page probe`: `tools/probe.sh parts_page_probe` (headless, about a
  minute once its class list is current): opens 6040-1, 10243-1, 42080-1
  and 8880-1 in the app (or the files given after `--`), takes each one's
  `Inventory.of` and `ShopLists` exports, and runs
  `node tools/web/parts_check.mjs --app=<their JSON>`, which lists the same
  files with `api/_parts.js` and prints the app's and the page's pieces and
  lots side by side, every lot that differs, and whether each export is
  word for word the app's. Exits non-zero on any difference.
- `model page browser flow` (`tools/web/model_page_flow.mjs`, preview check
  `[model_page]`): below.
- `site sign-in` (`web/account.js`): the app's own session in this browser
  (`localStorage` `brickworks.session`), renewed when an access token kept for
  the tab (`sessionStorage`) has run out and put back for the app, once a
  page however many scripts ask (the header, the theme, the page; `/admin`
  too), and asked again after a wait when Supabase refuses it for the rate
  (429) or a 5xx; `challenges browser flow` counts each page's renewals; a dialog
  asking for an address, sending a code (`/api/otp`), and redeeming it with
  Supabase — so signing in on the site signs the app in, as
  `web/authorize.js` does; `call()` for the site's API with the token.
- `people browser flow` (`tools/web/people_flow.mjs`): below.
- **Moderation** (2026-10-13, `supabase/moderation.sql`, applied to the live
  project that day, dry-run first; additions only): tables `reports` (one of a
  model, a handle or a collection; a reason of spam, offensive, sexual,
  violent, copied, trademark, personal, other; a note up to 1000; a contact;
  the reporter's account or a visitor's day key; when it was settled and how),
  `barred_accounts`, `barred_models` (a file's SHA-256), `act_log` and
  `may_act(actor, act, per_hour, per_day)`; `is_barred`; `sitemap_pages`; and
  `directory_models`, `profile_page` and `collection_page` again, showing
  nothing of a barred account; all closed to the publishable key. What a
  person may do, an hour and a day (`LIMITS` in `api/people.js`): a profile
  saved 20/60, likes and favourites 300/2000, a collection made 20/60, models
  put in lists 300/3000, reports 6/20 (by the account, or signed out by the
  visitor's key); publishing and listing as before (`may_publish`,
  `may_list`). The daily sweep lets `act_log` rows older than a day go.
- `names filter` (`api/_names.js`): words compared with their disguises off
  (case, accents, doubled letters, digits and symbols for letters, letters
  spaced out), whole words with simple stems, so "Scunthorpe", "assassin",
  "Dickens" and "peacock" pass. Abuse refused anywhere (a title, a credit, a
  tag, a description, a handle, a profile's name or about-you, a
  collection's name or description); names somebody else owns — the LEGO
  Group's marks and the licensed names its sets are made under, run together
  too ("StarWars") — refused in a title, a credit, a tag, a handle, a
  profile's or a collection's name, but not in a description, which may say
  what inspired it; not the names of kinds of part (Technic, minifigure).
  Handles kept for the site itself (`RESERVED`). Refusals say what to do
  instead, the mark written as `docs/TRADEMARKS.md` asks.
- `report it` (`web/report.js`): Report it on a model's, a profile's and a
  collection's page (hidden until the script runs), a dialog with the
  reasons, a note, a way to reach the reporter, Send and thanks; signed in
  (`account.js`) or not. `POST /api/people?op=report` (one thing named, a
  reason that is one, 404 for what is not there, 429 past the limit).
  **Emailed to the owner** (2026-10-18, `api/_trust.js` `sendDigest`,
  `supabase/trust.sql`): to `MASTER_EMAIL` from the sign-in codes' sender,
  within the hour and at most one email an hour of the clock — the first
  report in a quiet hour at once, later ones in the next — each report
  linking `/admin#report-<id>` (marked and scrolled to on the admin page).
  The hourly send is `POST /api/people?op=digest` (needs no secret; the
  database's pg_cron knocks a minute past each hour). A report about or by a
  test account (`@resend.dev`) is its own stream, never sent: rendered and
  recorded in `report_digests` (state `dry`), and the report's answer says
  `digest: {state: "dry", id}`. `REPORT_MAIL=off` sends nothing.
- `takedown page` (`web/takedown.html`, `web/takedown.js`): `/takedown`, in the
  gallery's footer ("Press Report on its page, or see takedown requests"),
  every server-made page's footer with it and beside each Report it; says how,
  and has a form taking the page's address (a model's, a profile's or a
  collection's), what is wrong, what is theirs and how to reach them, sent as
  a report. For a copy of somebody's work it also asks a signature and the
  two statements a copyright notice needs (2026-10-18). A counter-notice
  form (`#counter`: the model's address, why it was a mistake, name,
  address and phone, email, the perjury and court statements) sends
  `counter: true`, which may name a model already taken out, as reason
  `other` with a note starting "Counter-notice". `#agent` is the DMCA
  designated agent's place, marked for the owner to fill in.
- `terms and guidelines` (`web/terms.html`, `web/guidelines.html`, 2026-10-18;
  `docs/COMMUNITY.md` says where each rule is enforced): `/terms` and
  `/guidelines`, linked from every site page's footer (and the 404's and the
  Claude sign-in page's), from the server-made pages through the gallery's
  footer, and from the Share panel beside Publish. `/terms` has the
  operator's line (`#operator`) marked for the owner to fill in.
- `age question` (`web/account.js` `askAgeIfAsked`, `src/ui/sign_in_gate.gd`,
  `api/account.js` `?op=age`, `api/_trust.js`, `supabase/trust.sql`): asked
  once, after a first sign-in, on the site and in the app — "When were you
  born?", month and year, nothing about 13 before the answer. Under 13 the
  server refuses (422, in words) a listing, a credit, a profile and a public
  collection, and the database's triggers refuse them again; an account not
  asked yet is told to answer first before anything new goes public.
- `age browser flow` (`tools/web/age_flow.mjs`) and `report digest browser
  flow` (`tools/web/digest_flow.mjs`): below.
- `design system` (`web/site.css`, `docs/DESIGN_SYSTEM.md`, 2026-10-19): the
  site's controls, in one place and both schemes: a field (every input,
  select, textarea and file picker, styled by element at zero specificity,
  so none is the browser's; a dropdown is the text box with its own arrow),
  a checkbox and radio (`label.choice`), the buttons the site uses (`.cta`,
  `.cta.ghost` and any bare button, `button.link`, `.small`, `.big`), the
  `dialog` (sign-in, age, report), a date (`fieldset.date`: day, month
  and year dropdowns, /admin's challenge days) and `.card`; tokens `--field`,
  `--control-h` 44, `--control-radius` 10. The copies in `web/directory.css`,
  `web/gallery.html`, `web/download.html`, `web/takedown.html`,
  `web/admin.html` and `web/authorize.html` are gone; the last two now link
  `/site.css`. The owner's example was the age question's bare month
  dropdown beside a full-size year box. Since 2026-10-20 also the shell (one
  header of four things and one footer, `web/_shell.html`,
  `tools/site_shell.py`), one type scale (`--t-*`) and rhythm (`--s-*`,
  `--page-top`, `--section`), the page template (`.page`, `.page-head`,
  `.prose`), the one model card (`.model`, in `.models`, `.models.compact`
  or `.models.row`), `.state`, `.subnav`, `.settings`/`.setting` and
  `.danger`. Since 2026-10-22 (docs/SOCIAL.md U2) only the token scale:
  every font size `var(--t-*)`, every corner `var(--r-*)` (or
  `--radius`, `--control-radius`, `0`, `50%`), every colour a token, in
  site.css, directory.css, each page's `<style>` and the embed's; tokens
  are made only in `:root`. And no count of none on a page ("0 likes",
  "following 0"): a count a press can change is on the page `hidden`.
  Since 2026-10-24 (copy252) `.table`, a table of facts in a named region
  that scrolls inside itself (the FAQ's dimensions, moved off its own
  copy), and `.table.wide`, /compare's field, whose row names stay in view
  as a phone scrolls it; design_flow and a11y_flow judge both on /faq and
  /compare. Since 2026-10-26 (site276) one size an h2 (`--t-h2`, now 22-26
  px) and an h3 (`--t-h3` 18) wherever it is, which `design_flow` fails
  otherwise (red on a planted `.prose h2 { font-size: var(--t-h3) }`);
  four breakpoints, 600/900/1200/1600, in range form (`width < 600px`);
  the header 44 px throughout (the regular `.cta`, Menu, the avatar's
  button; the mark's word wraps out of sight where there is no room, no
  389 px query) and from 600 px the laptop's; the footer's links and, under
  600, every `.segmented` button 44; a link alone on its line 30-32 px by
  padding (site.css "targets"). Measured with site273's scripts (copied to
  site276's scratch): `report.mjs --bars` over `measure.mjs` at 320, 390
  and 1280.
  Since 2026-10-26 (site275, docs/DESIGN_SYSTEM.md "Motion" and
  "Steady loads"): every control and card eases over `--motion` (150 ms),
  sinks on `:active`, a card lifts 2 px under a mouse, a dialog and a menu
  fade in (`--motion-open`), and none of it under reduced motion; `main`
  fills the window under the header (`--head-h`); a script's part starts
  as a skeleton (`.skeleton`, `.bone`, `.skeleton-card` from
  `web/card.js` `skeletonHtml`) and is drawn whole when its answers are in
  (the gallery's first page with its pick and challenge line, the landing
  strip, /profile, /settings, /feed, /notifications; each copy in a page's
  HTML is `skeletonHtml`'s, which `card_check` fails otherwise; the strip
  holds eight, as many as its cards, and a skeleton's designer line is two
  lines only on a card under 190 px, by a container query); the first screen's
  card pictures are `eager` + `fetchpriority="high"` (`cardHtml`'s
  `eager`, `FIRST_SCREEN` = 12 since site277's grid of up to six a row on
  the server's pages; the gallery counts the skeletons on its first
  screen, 18 at 1920, and `designs.js` makes a row's picture eager once it
  is laid out on the first screen; a collection's cover and first four
  collection cards, `api/_lists.js` `mosaicHtml`/`listCardHtml` `eager`;
  a model's strip's first five); a designer's own numbers on /u/ sit under
  the work; the gallery's challenge line is the grid's first row
  (`#feed > #challenge-line`), drawn with the cards; a model page's
  comments are held by `#comments-hold` (bones, the height of an empty
  section and its box) until drawn, its "I built it" box is shown from
  the server, and its owner's Add a picture sits over the picture
  (`.on-picture`) while there is no strip (`model_page_flow` accepts
  either place); Like on /m/ and Follow are drawn at once and roll back
  with why if refused. Measured with site273's scripts (CLS at load and after
  scrolling, the footer's bottom against the window's, lazy pictures in
  the first screen, every control's transition with and without reduced
  motion, an `:active` rule per kind, Like and Follow's time to draw).
- `model card` (`web/card.js`, 2026-10-22): one renderer, `cardHtml(model,
  {earned})`, a pure string function; `modelCard` parses it in the
  browser (gallery, landing strip, /profile), and the server's pages
  draw with it through `api/_card.js` (a pass-through in a checkout;
  `tools/deploy.sh` copies web/card.js over it in each function): /u/
  (earned on a designer's page), /c/, and a model's remixes on /m/ (in
  `.models.compact`; the `.mini` card is gone). Its picture is 4:3: since
  2026-10-24 the app's own 480 x 360, nothing behind the model, on the
  frame's `--picture-ground` (the theme's: a lit dark grey, or the light
  ground the app drew before), an older one the 1200 x 630 cut by
  `object-fit: cover`; Tested is a `.pill.good`. The Assistant or Brickify
  mark is `madeOf(model)`: `made_with` as the app said (`cardOf` passes it
  from `directory_card`), else the `ai-designed`/`brickify` tags; its title
  says which. `card_check` holds a hand-built model tagged ai-designed
  unmarked, an untagged one of Claude's marked (red on base). Since
  2026-10-26 (site277, from site273's review) the marks are one row
  (`.marks` one pill tall; a mark that does not fit is left off whole),
  and a mark 90% or more of a page's cards carry (four cards or more) is
  not shown: `quietMarks` names it on `<body data-quiet>`, the server's
  /u/, /c/ and /m/ pages as they are made, and in a browser again
  whenever cards come onto the page (a MutationObserver the first
  `modelCard` starts; the landing strip puts its cards in frames after it
  made them), before the page is drawn, and site.css
  hides it. The gallery's like (`like: true`) is over the picture's
  top-right corner; likes elsewhere, builds and comments are `.tally`s in
  `small.acts` on the designer's `.by` line; no card ends in a row of
  numbers. Titles 16 px at every width. `.models` is 2/3/4/5/6 a row at
  0/600/900/1200/1600 px; card pages are `.wrap.wide` (`--page-wide`
  1600 px, as the header and footer on every page). On the live gallery
  before: marks over 30.7% of a phone's picture in three rows, Tested and
  Assistant on 100% of the cards, 216 cards ending in a lone heart, a
  one-line card 348 px at 1280, 4 a row and 8 cards on the first screen
  at 1920, 2 a row and no header links at 768.
- `picture themes` (`tools/web/picture_themes.mjs`, 2026-10-24, U15): a
  model's card (found by a word in the gallery's search) and page at 390 and
  1280 in each theme, pictured, a corner of each measured on screen: dark in
  the dark theme (under 0.3), light in the light one; the card's picture
  4:3 and clear at its corners, the page's clear. `share_flow` runs it on its
  model; standalone `--url --id [--tests] [--old] --out`. On the live fox
  before U15: 0.83 and 0.93 bright in the dark theme, 480 x 252 opaque.
- `card check` (`tools/web/card_check.mjs`, local only): below.
- `component kit` (`web/kit.js`, `web/icons.svg`, site.css "the kit",
  2026-10-22): `.pill` (`a`/`button`/`summary.pill` 32 px; `.good`,
  `.new`, `.tag`; rows in `.pills`) for a model's facts and tags, its
  Tested mark, the gallery's tag filter (`#chips`), a comment's "its
  builder", the feed's New and whom you follow on /profile; `.tabs`;
  `.avatar` (`avatarHtml`: a tile of `--avatar-1..8` by FNV-1a of the
  handle, the first letter; sizes `.small`, `.big`, `.huge`), on /profile's
  head (`#initial`); `.icon` and `.icon-btn` (`iconButtonHtml`: label
  "Like, 12 likes", the count shown only when not zero, `aria-pressed` for
  a toggle); `toast()`; `details.more-menu` with the header's
  `.menu-list`, closed by a click elsewhere or Escape. `web/_kit.html` at
  `/_kit` (served by the stand-in, never deployed: tools/site.py skips
  "_" names) shows each.
- `design browser flow` (`tools/web/design_flow.mjs`, preview check
  `[design]`): every page and dialog, below. Its pages and the states it
  opens are `tools/web/site_pages.mjs`, shared with the accessibility flow.
- `accessibility browser flow` (`tools/web/a11y_flow.mjs`, preview check
  `[a11y]`) and `keyboard browser flow` (`tools/web/keyboard_flow.mjs`,
  `[keyboard]`): axe and the accessibility tree's names on every page,
  and the site's journeys by keyboard alone; below, "The site for
  everyone" (docs/DESIGN_SYSTEM.md "Accessibility").
- `theme choice` (2026-10-22, docs/SOCIAL.md U1): System, Light or Dark,
  a `.segmented` row of three buttons, the chosen one `aria-pressed` and
  edged in `--accent-edge` (the yellow in dark, `#a67c00` in light: the
  yellow was 1.33:1 there). In the footer of every page, on Menu at a
  phone's width (inside `details.menu`, under the links; the header keeps
  its four things) and in Settings › Appearance on /settings (`#theme-part`). The light
  set in `web/site.css` is keyed on `<html data-theme="light">` and, with
  no choice, on `prefers-color-scheme: light`; the two copies must be equal
  (`tests/test_site_contrast.py`, which also measures every text token on
  every surface at 4.5:1 and the edges at 3:1, in both themes, and that the
  browser bar's colours are the page's). `web/theme.js`, a plain script in
  every page's `<head>` before `site.css` (static pages by
  `tools/site_shell.py` from `web/_shell.html`, the server's by
  `siteChrome().head`), sets `data-theme` and the two `theme-color` lines
  from `localStorage["brickworks.theme"]` before the first paint, follows
  another tab's choice (`storage`), and handles any `[data-theme-choice]`
  button. Signed in it loads `web/theme-account.js`: once a tab it asks
  `GET /api/account?op=theme` (`{theme, chosen, ready}`) and applies the
  account's; an account with none takes the browser's; each choice goes
  `POST /api/account?op=theme {theme}` (`{theme, kept}`). Column
  `profiles.theme` (`supabase/theme.sql`, **not applied to the live
  project** until the lead applies it): before it, GET answers `system`,
  `ready: false` and POST `kept: false`, never an error. Deleted with the
  account (profiles cascades). /m/<id>/embed keeps following the system:
  it sits in somebody else's page and runs no script.
- `theme browser flow` (`tools/web/theme_flow.mjs`, preview checks
  `[theme]` and `[theme_account]`): below.
- `comments on a shared model` (`supabase/comments.sql`, `api/_comments.js`,
  `api/people.js`, 2026-10-18; **not applied to the live project**: the
  owner applies it at release, after `trust.sql` and before the deploy;
  `docs/COMMUNITY.md` "Comments" has the rules). `model_comments` (model,
  version, step or none, author, body 1 to 1,000 plain characters, `at`,
  `edited_at`, `hidden_at`, `removed_at`/`removed_by`), `comment_settings`,
  `mail_choices` (off by default), `comment_digests`, and `reports.comment`;
  no grant on the new tables to anybody, the service role too: only the
  functions (`comment_trouble`, `comments_on`, `add_comment`,
  `change_comment`, `set_comments`, `admin_comments`,
  `admin_remove_comment`, `mail_choice`, `claim_comment_digest`,
  `finish_comment_digest`, `comment_digest_kept`, `comment_model`), and a
  trigger refusing under 13, barred and closed whatever writes. `GET
  /api/people?op=comments&id=X&v=N` (oldest first; each `said` "on step 7 of
  version 2", `older`, and `on_step`, the step of version N it shows on, or
  null once a version between changed that step or one before it; `you`:
  `may_write` and `why_not` in words); `POST ?op=comment` (10 an hour, 50 a
  day), `?op=comment_change` (edit, remove; hide, show for the owner),
  `?op=comments_open&id=X`, `?op=mail`; `?op=report` takes `comment`; the
  knock also sends each owner's day's email, a test's dry. The model's
  page draws them (`web/model-page.js`, the section from `api/share.js`
  `commentsSection`, the step picker of the version shown); `/profile` has
  the email box; `/admin` lists the newest and the reported, with Remove
  (`?op=uncomment&comment=N`). Before comments.sql: none shown, "not open
  yet", the admin page as before.
- `comments on a step` (`src/ui/step_comments.gd`, `StepComments`; wired in
  `src/main.gd` `_load_comments`, `_comments_opened`, `_send_comment`): in
  the viewer, a count above the timeline for the step it is on (0, the
  whole model, at either end or with it away); in the step player, a count
  in the top bar for the page. Tapped, the step's comments (`on_step`) and
  a box, or the server's `why_not` and a way to the model's page to sign
  in. The viewer reads no account until a step's comments are opened on a
  device that keeps a session: then an `Account` of the comments' own,
  `keeps = true`, renews it as the site's pages do. `page_state` has
  `comments`, `comments_open`, `comments_shown`, `comment_why_not`,
  `comment_can_write`, `comment_pill`; controls `view_comments`,
  `build_comments`, `*_comment_box`, `*_comment_send`, `*_comment_sign_in`.
  Proved by `share_view_probe` (no network: FakeShared) and the flow.
- `comments browser flow` (`tools/web/comments_flow.mjs`): below. Since
  2026-10-22 it proves replies too (once the list says `replies: true`; on
  a deployment without `replies.sql`, that nobody is offered Reply and the
  API says not open yet): locally on a relay with `--hold=replies` over the
  live project, throwaway accounts deleted at the end.
- `replies to a comment` (`supabase/replies.sql`, 2026-10-22, docs/SOCIAL.md
  U8; **not applied**: apply after comments, follows, challenges,
  designers, gallery_tabs and notifications, whose functions it replaces,
  each marked REPLACED LATER and guarded in `tools/apply_sql.mjs`).
  `model_comments.parent` (nullable, cascades with its comment), `add_reply`
  (a reply to a reply joins its thread; on the comment's version and step;
  a comment's rules and limits), and `comment_parent_shown`, the one rule:
  a reply is shown only where its comment is (page, cards' counts, a
  designer's numbers, the day's email, notifications). `notification_rows`
  tells a comment's author of each reply, and whoever replied in the
  thread of each reply after theirs (kind `reply`, `yours`), on any model.
  `POST /api/people?op=reply {id, body}`; the list says `parent` on each
  and `replies: true`. Proved by `tools/replies_try.sql` in a rolled-back
  dry run (the command in the feature map), and the comments flow.
- `comment threads on a model page` (`web/model-page.js` `startComments`,
  `web/directory.css`): the newest thread first, its replies oldest first
  under a line; each with its writer's avatar (`avatarHtml`), Designer on
  the model's owner's, a step comment's step as `a.pill.step` to
  `/app?view=<id>[&v=<n>]&step=<n>`; Reply under each comment opens
  `form.reply-new`; the box is shown signed out ("Sign in and add it"),
  sending asks to sign in and keeps the words. Hiding or removing a
  comment hides its replies. `model_page_flow` checks it on the stand-in's
  watchtower at 390 and 1280, light and dark, in and out
  (`*_comments.png`).
- `open a shared model at a step` (`src/main.gd` `_viewing_step`, from
  `--step=<n>`): taken up as Build it pressed while the steps were being
  worked out (`_build_wanted`), so the step player opens at page n.
  `step_link_probe` proves it (no network: a stand-in for the link).
  Build it on the model's page is `?build` (`_viewing_build`, from
  `--build`, viewer218 2026-10-24): the step player at step 1 in one press,
  or at the page this device was building it at (`BuildSteps.recall`
  building); it was the viewer on the finished model, its own Build it,
  then Start on the cover (walk180 W3). The picture (View in 3D) is still
  the plain viewer. `viewer_steps_probe` (windowed) proves both, and
  `share_flow` on a deployment presses Build it on a real page.
- `follows and the feed` (`api/_follows.js`): `supabase/follows.sql`,
  2026-10-18. `GET ?op=follows&handle=X` (counts, and with a session
  whether the caller follows and may, why not in words), `POST ?op=follow`
  `{handle, on}`, `GET ?op=following&handle=X` (whom X follows, only when
  X chose to show it), `POST ?op=follow_choice` `{shows}`, `GET ?op=feed`
  (`&before=`; the first page marks the feed opened), `GET ?op=feed_count`;
  `POST ?op=mail` takes `models`, `versions`, `photos`, `remixes` beside
  `comments` (`mail_kinds`), and the day's email has a feed section
  (`renderCommentDigest`, `feedSaid`). Before the file is applied every one
  answers as "not open yet" and nothing else changes.
- `your feed page` (`web/feed.html`): with `web/feed.js`, `/feed`, signed in,
  newest first, one link a row, New on what came since the last opening and
  after the follow that brought it (`isNew` in `api/_follows.js`, from
  `supabase/feed_new_rows.sql`'s `feed_followed_at`, 2026-10-25, walk256's W7:
  a new follow's backlog was marked New; `since_follows` in the answer says
  the rule is in force, and before the file New is by the last look alone;
  `first_steps_flow` checks Cy's feed right after the follow, and
  `tools/feed_new_rows_try.sql` the function in a dry run),
  Older for the page before; signed out, Sign in. Since 2026-10-22
  (docs/SOCIAL.md U7) what the people you follow made (`follow_page`),
  Notifications a tab beside it (`.tabs`, each with what is new in it);
  before `supabase/notifications.sql` it is the feed of before, your
  models' news in it too. Since U9 (docs/SOCIAL.md, 2026-10-22) a feed you
  look at: `ol#rows` of `li.feed-row[data-kind]` (`.new`), each a post:
  `.post-head` (the avatar and `a.who` to `/u/`, `.what` the sentence with
  `a.go` the thing's link, New, a `time`), the `q` said (a version's note,
  a photo's words), then the gallery's card (`article.model`, `cardHtml`)
  or `.feed-photo` (the photo, "A build of" its model). `#designers`
  (`.feed-rail`, `ul#people` of `li.person-row[data-handle]` with Follow,
  `followButton` given its state) beside it from 1100 px, under it on a
  phone, leaving out whom you follow and you; `#latest` (Latest on
  Brickworks: `#latest-models` cards, `#latest-photos` a `.build-grid`)
  when signed out (`#signed-out`, Sign in), following nobody (`#nobody`)
  or with nothing in 90 days (`#quiet`). `html[data-feed]` is `ready`,
  `signed-out`, `not-yet` or `failed`. The 60-word lede is gone.
- `follow a person and the count on Account` (`web/follow.js`): loaded by
  every page with the site's header, the model page and `/u/`, `/c/`.
  `button[data-follow]` shown once `?op=follows` answers (Follow, Following,
  hidden on your own; signed out it opens the sign-in dialog; a refusal is
  said beside it), and `a[data-account]` in the header: Sign in until you
  are, then hidden for your avatar (below), which carries the count.
- `the account menu` (`web/follow.js` `showFeedCount`, 2026-10-22,
  docs/SOCIAL.md U7, D10): signed in, `details.more-menu.end.account-menu`
  after the hidden `a[data-account]`, the last thing in `.nav`, after Open
  the app at the far right (2026-10-23; `design_flow.mjs` fails another
  order, and `keyboard_flow.mjs` the Tab to it): its summary `.account-btn`
  is your avatar (`avatarHtml`, 36 px) with `.count` over its corner (what
  is new: notifications and the feed together, as `?op=feed_count`'s
  `count`), labelled "Your account, N new"; its `.menu-list` holds
  `.account-part` (`.menu-who`: avatar, name, @handle; then `nav` links
  `data-place` profile, notifications, feed, saved, settings, the two
  with their own `.count`), the footer's theme choice and
  `button.sign-out`. Under 600 px (860 and under before 2026-10-26) the avatar menu is hidden and
  `details.menu`'s summary becomes the avatar (`.account-btn`), its list
  the site's links, the same `.account-part`, the theme and Sign out. Who
  you are and the counts come from `GET ?op=feed_count` (`me`,
  `notifications`, `feed`), kept in `sessionStorage["brickworks.me"]` so
  the next page draws at once (cleared by `signOut()`); /feed and
  /notifications ask only once they have opened.
- `notifications apart from the feed` (`api/_notifications.js`,
  `supabase/notifications.sql`, **not applied to the live project** until
  the lead applies it): `GET ?op=notifications` (session; marks them
  seen) answers `{ready, kept, seen_at, groups: [{model, name, picture,
  link, at, new, unread, rows: [{kind, at, who, by, did, said, link, new,
  unread}]}], unread, fresh}`: comments, photos of builds of your models,
  remixes, `likes` a row a model a day ("10 new likes today", never who),
  `result` a challenge's end (won, or see who did); grouped by the model
  they are about, newest group first (`noticeGroups`, pure). `POST
  ?op=notifications_read {model}` (that group read) or `{all: true}` (Mark
  all read; also clears the count); a model not yours 404, not an id 400.
  `GET ?op=feed_count` adds `notifications`, `feed` and `me`; `count` is
  the two together (the app's Account reads only `count`). The feed's count
  is only what came after each follow (`feed_new_count`,
  `supabase/follow_counts.sql`, applied 2026-10-24; the count of before
  while it is missing): a new account that followed the house in First steps
  had 7 on its avatar at once for the house's old models (walk180 W7). Tables
  `notification_marks` (seen_at, read_at; an account without a row has its
  feed's) and `notification_reads` (account, model, at), both cascading;
  functions `notification_rows` and `follow_rows` (the live `feed_rows`
  split by kind), `notification_list`, `notification_read`,
  `notification_counts`, `follow_page`; `feed_of`, `feed_count`,
  `feed_rows` and the day's email unchanged. Before the file: the rows
  from `feed_of` and `model_likes`, the feed's seen_at the only mark (read
  is seen), `kept: false`, no challenge results.
- `notifications page` (`web/notifications.html`, `web/notifications.js`):
  `/notifications`, `ol#groups` of `li.notice` (`data-model`; `.unread`
  edged and dotted in `--accent-edge` until a link in it is followed,
  which posts `notifications_read` with `keepalive`), each `.pic` (4:3) and
  `h2` name, `ul.lines` (`li[data-kind]`, an avatar for a person, the like
  or award icon otherwise, New since the last opening, the time); `#all-read`
  while any is unread; `#empty` with its ways in; `#not-yet`; signed out,
  Sign in. `html[data-notifications]` is `ready`, `signed-out` or
  `failed`.
- `notifications browser flow` (`tools/web/notifications_flow.mjs`,
  preview check `[notifications]`): below.
- `latest on Brickworks and designers to follow` (`api/_follows.js`
  `latest`, `designersFrom`, docs/SOCIAL.md U9): `GET ?op=latest`, anybody,
  `{models, photos, designers}`: the 8 newest listed models as the
  gallery's cards (`gallery_models` sort newest), the 6 newest photos of
  builds of listed models by builders shown in public (`photosWhere`), and
  8 designers read from Top builds' first 49 cards, each credited one
  with a public profile (a card's `by`, D1), most first by the sum of
  their models' score (a build 3, a remix 2, Tested 5), then builds, then
  the newest: `{handle, name, score, builds, models: [{id, name}]}`.
  `s-maxage=30` for everybody; `&tests=1` test models too, `no-store`. No
  SQL of its own. And `GET ?op=feed` gives each row `card` (directory_card
  read as a column, `shared_models?select=card:directory_card`) and a
  photo row `photo` `{id, url, width, height}`; its first page
  `following`, the handles the caller follows (`follow_list_mine`).
- `feed browser flow` (`tools/web/feed_flow.mjs`, preview check
  `[feed]`): below.
- `first steps after a first sign-in` (`web/first-steps.js`, docs/SOCIAL.md
  U10): `web/account.js` `askAgeIfAsked`, once the age question is
  answered 13 or over (a first sign-in, from the dialog or a page that asks
  on load), imports it and opens `dialog.first-steps` before the page goes
  on: `[data-step]` `profile` (`#first-name`, `#first-handle` made from the
  name until typed in, the `.face-row` avatar from it, `#first-make` posts
  `?op=profile`; left out with a profile already), `kinds` (the gallery's
  kinds from `?op=list&sort=top` as `button.pill[data-kind]`,
  `aria-pressed`; `#first-next`), `start` (`ul.people-list` of up to three
  `li.person-row[data-handle]` from `?op=latest`'s designers, those with
  most models of the kinds chosen first, each Follow `followButton`; six
  cards, the kinds chosen first); `#first-skip` on the first two;
  `#first-feed` See your feed (`/feed`, `?tests=1` kept) unless the sign-in
  was asked for something on the page (`askToSignIn(why)`: then only
  `#first-done`, and the like or follow goes on after). Escape closes it.
  Nothing of the kinds is kept. The page's own Sign in is `askToSignIn()`.
- `the house's profile` (`supabase/house.sql`): the studio's account, the
  one whose listed models are credited "Brickworks" at a brickworks.diy
  address, given its age answer, `people` (`brickworks`, Brickworks, words
  saying its models were made with the assistant) and `profile_shows` (the
  castle as banner, three pins), each only if not there; then, a step
  apart, `ai-designed` appended to the seven house models' tags (named by
  id, once), so their cards carry the Assistant mark; nothing else on any
  model. `/u/brickworks` is drawn as every person's page is. The lead
  applies it. `supabase/house_shelf.sql` (gallery261) says its words again
  once it shares the shelf from the LDraw library ("Its own models were
  designed with the assistant… The collection From the LDraw library holds
  real sets as LDraw's builders modelled them"), only while they are still
  house.sql's, since the API refuses a profile save of the reserved handle;
  dry-run with `tools/house_shelf_try.sql` (296 characters, no other
  profile changed). The lead applies it with the shelf's first slice.
- `who modelled a shared model` (`supabase/modelled_by.sql`,
  `supabase/modelled_by_changed.sql`, `api/_omr_credit.js`
  `libraryCredit`): a model its sharer did not make, the shelf from the
  LDraw library (gallery261, 2026-10-25). The app keeps
  `0 !BRICKWORKS CREDIT {by, licence, page, from}` with a model its Library
  opened (`ModelLibrary.credit_of`), and the Share panel puts that line in
  the file it publishes (`SharePanel.publish`, before its steps are worked
  out and tested, so a Tested finding is of the file sent). The server
  never takes a name from it, which anyone can type: it reads only its page,
  finds that page's models in the Library the parts store holds
  (`library/index.json`, 10 minutes kept), fetches each one's own file
  (`library/omr/<file>.mpd`), and holds the shared file to it: the same name
  inside (an .mpd's first FILE, or a single model's `0 Name:`), and at
  least half of each one's parts, by part and colour, in the other. Then
  `{name, page}` from the index, and `changed: true` when the parts are not
  exactly the library model's, go in `shared_models.modelled_by`
  (`keepModelledBy`, after the row), and the licence is the index's
  (`cc-by-2.0` for CCAL 2.0, `cc-by-4.0`) whatever was chosen: somebody
  else's CC BY work is not licensed again. No match is nobody. All 30 of
  the shelf's bodies matched the live store, unchanged (2026-10-25). Then
  the card's who-line is "Modelled by <name>" (`web/card.js`,
  `[data-modelled-by]`, words that wrap on a phone's card) in place of the
  sharer's profile; the page has `.from.modelled-by` under `.shared-by`
  ("Modelled by **name** for LDraw's Official Model Repository", linked to
  its LDraw page, and ", changed by <sharer>" when changed); the licence
  words credit them with that link (and ask to say who changed it), the
  head's description and schema.org's author name them, and `/api/share?id=`
  says `author` and `modelled_by` from the row, so the gallery tool over
  MCP credits them too. The SQL also lets a licence be `cc-by-2.0` (LDraw's
  CCAL 2.0 is CC BY 2.0, `vendor/ldraw/CAreadme.txt`), which the Share panel
  does not offer. Held by `tests/test_modelled_by.py` (against
  `tests/fixtures/omr_credit`: 346-2 credited from the index even when its
  line names somebody else; a forged line over a model of one's own, the
  library model's name over other parts, a page not in the index, no line,
  or under half its parts: nobody; a tenth taken out: changed; the copy of
  made_with.sql's `directory_card` keeps every key; the licence ids are one
  list in the SQL, the site and the gallery tool; the card and the page as
  driven) and on a deployment by `share_probe` (`theLibrary`: credited,
  CC BY 2.0 kept when CC BY 4.0 or all rights reserved is chosen, changed,
  forged). Dry-run with `tools/modelled_by_try.sql` and
  `tools/modelled_by_changed_try.sql` (changed: true allowed; false, a
  word, another key, no name refused; no row refused after; no client
  reach) and `tools/sql_compare.mjs supabase/modelled_by.sql modelled_by`
  (17 of 17 the same). The lead applies them.
- `first steps browser flow` (`tools/web/first_steps_flow.mjs`, preview
  check `[first_steps]`): below.
- `the app's Account count` (`src/ui/account_panel.gd`): `ask_feed`, and
  `src/ui/model_bar.gd` `show_feed_count`. "Account · N" on the bar, "N new
  in your feed since you last opened it." and Open your feed (control
  `account_feed`) in its panel; asked at sign-in, on opening Account, on
  the window's focus and every five minutes. `brickworksState.feed`:
  `count`, `account`, `panel`.
- `follows browser flow` (`tools/web/follows_flow.mjs`): below.
- `following a collection` (`supabase/collection_follows.sql`,
  `api/_lists.js`, docs/SOCIAL.md U11): `GET ?op=list_follows&id=X`
  (followers, and with the session `you_follow`, `may`, `why_not`) and
  `POST ?op=list_follow` `{id, on}` by follows.sql's rules (13 or over, not
  taken out, not your own, counted with following people); table
  `collection_follows`, read by no key; `list_rows` in `follow_rows`, so a
  model put in a followed collection is in the feed (kind `collection`,
  `feedSaid`'s `list`) and the avatar's count; `model_lists`, the public
  collections a model is in, on its page as "In N collections", a tab and
  `#collections` (`listsOf`, `listCardHtml` with covers by `coversOf`). The
  collection's page `/c/X` (`api/people.js` `listPage`): its cover
  (`mosaicHtml`), Follow (`web/follow.js` `followButton` with
  `data-follow-list`), its counts, Share (`web/person.js`), More.
- `collections directory` (`supabase/collection_directory.sql`,
  `api/_lists.js` `directoryOf`/`directoryCardHtml`, `api/people.js`
  `collectionsPage`, W12): `/collections` (`?sort=followed`, `?page=N`,
  `?tests=1`), the public collections with a model in the gallery whose
  owner may be followed, 24 a page: `nav.tabs` Recently added to · Most
  followed, `#collections` of `article.list-card.in-directory` (cover
  `.mosaic`, name, owner `a.who` with an avatar, "N models", "N followers"
  when any, Follow), Previous · Page N of M · Next; `#collections-empty`
  for none, a page past the end and the SQL not applied. Follow by
  `web/follow.js`, the cards' states in one `GET ?op=list_follows&ids=A,B`
  (48 at most). Linked from the gallery's tabs (`#to-collections`) and the
  footer of every page.
- `collections browser flow` (`tools/web/collections_flow.mjs`, preview
  check `[collections]`): below, under "The collections directory".
- `share sheet` (`api/share.js` `shareSheet`, `web/model-page.js`,
  docs/SOCIAL.md U14): Share on a model's page opens `dialog.share-sheet`,
  `#share-link` and `#share-embed` with `[data-copy]`, `[data-share-app]`
  where `navigator.share` is; `html[data-shared]` `open`, `copied`,
  `embed`, `sheet` or `failed`. The embed `/m/X/embed` loads `web/theme.js`
  (`<html data-embed>`: never the account).
- `list follows browser flow` (`tools/web/list_follows_flow.mjs`, preview
  check `[list_follows]`): below, under "A collection followed".
- `Top builds and this week's pick` (`supabase/discovery.sql`, 2026-10-19):
  `gallery_score` (a build finished 3, a remix 2, the Tested mark 5; views
  nothing), `directory_models` with sort `top` (and `owned`, a pool's
  shares, `buildable`; the page cut before its cards are made),
  `gallery_week` / `gallery_week_counts` / `gallery_week_of` (the past seven
  days), `gallery_pick` (the owner's newest open choice still in the
  gallery, or the week's best), `gallery_choose_pick`, `gallery_end_pick`,
  `gallery_choices`; tables `gallery_picks`, `model_needs`,
  `model_needs_kept`, `collection_pools`, `collection_pools_kept`, read by no
  key. `api/_directory.js` `SORTS.top` "Top builds", `MINE_SORTS.owned`
  "Parts I own", `SCORE`, `SHELF` (8); `api/share.js` `?op=shelves` (pick,
  small builds under 200 parts by Top builds, and with `mine=1` You can
  build now) and `?op=list&mine=1` (each card's `owned: {pieces, have,
  share}`, sort `owned`, `ready=1`), never kept by the CDN with `mine=1`.
- `the gallery's front shelves` (`web/gallery.js`): on `/gallery` with
  nothing asked, This week's pick (a wide card, its why: "Built twice this
  week", "New this week, and Tested", "Chosen by Brickworks"), You can
  build now (signed in: the shelf, or how to tell Brickworks what you own),
  Small builds (sideways inside itself on a phone, See every small build
  past eight); a card's "✓ You have every part" / "You have N of its M
  parts · P%"; under Sort › Top builds the line saying how it weighs.
  `document.documentElement.dataset.shelves` is `ready` once drawn.
- `choosing this week's pick` (`web/admin.js`, `api/admin.js`): This week's
  pick on `/admin` (what visitors see, the open choices with End, the
  week's best five with Make it the pick), and Make it the pick beside every
  model in the gallery's table; `?op=pick&id=X&days=N`, `?op=unpick&pick=N`.
- `build with what I own` (`api/_owned.js`): `ownedFacts` (from
  `_part_facts.json`, which `tools/web/part_facts.mjs` now writes with every
  part number anybody owns on its own, the moved ones and the colours' plain
  codes; `ownable` leaves out stickers, links of a hose or chain drawn link
  by link and LDraw's ~ pieces, a moved number judged by its target, as
  `Collection.ownable` does, 2026-10-19), `keyed`,
  `familyOf` (a mould letter left off, as the app lets another moulding
  stand in), `shardOf`, `readShard`, `poolOf`, `freshPool` (a pool counted again the
  first time it is asked after the collection changed); `checkModel`'s
  `needs` in `api/share.js`, kept on publish.
- `needs backfill` (`tools/web/needs_backfill.mjs`): below.
- `parts count backfill` (`tools/web/parts_backfill.mjs`, web295): the
  count a published model keeps for its card, as its page counts it
  (`piecesIn` in `api/share.js`, which a publish keeps since web295):
  reads every published model's versions and files, and writes
  `supabase/parts_counted.sql`, one update a count that differs, each held
  to the row as read. Proved by `tools/apply_sql.mjs supabase/parts_counted.sql
  --dry --try=<a select of the rows it names>`: on 2026-10-26, 39 published,
  4 models and 4 versions changed (6085's 983 to 748), rolled back. And
  `share_probe` lists 10243-1 and reads its card and page: 2458 and
  "2,458", not its 2,479 part lines.
- `discovery browser flow` (`tools/web/discovery_flow.mjs`): below.
- `designers' numbers` (`supabase/designers.sql`, 2026-10-19): table
  `model_opens` (a model, a day, how many opened its page: kept by the
  trigger `model_opens_count` after each insert into `model_views`, so
  `count_view` is not replaced; read by no key), `designer_said(model_ids,
  since)` (the comments each earned: shown to a visitor, in this life of
  the link, not the owner's), `designer_page(wanted, tests)` (models,
  builds, remixes, comments, tested, likes, builders, each card's comments,
  the newest twelve photos by others; each the sum of the cards'),
  `designer_mine(designer, days)` (each published model's last 1 to 90
  days and in all, and up to six photos by others). Replaces no function.
  `api/_designers.js`: `designerOf`, `designs` (`GET ?op=designs`, session;
  `&handle=X` answers `{mine: false}` unless X is the caller's), `DAYS`
  (30), `MINE_CACHE` (`private, no-store`, on every answer, a 401 too).
  Before the file is applied the page is as before and `?op=designs`
  answers `ready: false`.
- `a designer's page` (`api/people.js` `profilePage`, `numbersHtml`,
  `stripHtml`, `cardHtml(card, {earned})`): `/u/<handle>` with a model in
  the gallery says Designer (`[data-role]`) and its numbers are what the
  models earned (builds finished and remixes first, `[data-followers]`,
  which `web/follow.js` counts again); on the Models tab Start with their
  most built (`.start-with`, Build it to `/app?view=<id>`) and the cards by
  Top builds; Built by others (`.builds-of`) on the Builds tab; the cards
  (`a.model[data-builds]
  [data-remixes][data-comments]`, "3 built · 1 remix · 1 comment", Tested,
  never views). `?op=profile` gives `designer` and each card's `comments`.
  The page is the same bytes for everybody; `#designs-mine` is empty and
  hidden in it.
- `your models as a designer` (`web/designs.js` `showDesigns`): on your own
  `/u/<handle>` (How your models are doing) and on `/profile?tab=insights`
  (Your models, as a designer; `web/profile.js`): totals (`.mine-totals`, opens and
  builds finished leading), then a row a model (`li.design-row[data-id]`,
  its numbers `dd[data-kind]`, the last 30 days large and in all beneath,
  who built it with their photos). `document.documentElement.dataset.designs`
  is `ready`, `empty`, `not-yet`, `not-mine`, `signed-out` or `trouble`.
- `designers browser flow` (`tools/web/designers_flow.mjs`): below.
- `profile browser flow` (`tools/web/profile_flow.mjs`, preview check
  `[profile]`): below.
- `your own picture as your avatar` (`web/picture.js`, `api/_avatars.js`,
  `api/_faces.js`, `supabase/avatars.sql`, 2026-10-22): Edit profile's
  Choose a picture opens `dialog#crop-dialog` (`.cropper`: a 640 px canvas,
  `#crop[data-zoom]`, the zoom's `[data-zoom=in|out]`, `[data-crop=use]`);
  the square sent as `{picture: base64, type}` to POST `?op=avatar` (at most
  2 MB; 401 signed out, 409 no profile, 413, 415, 422 under 120 px, 503
  before the file), kept as `avatars/<id>.jpg` at most 400 px, served by GET
  `?op=avatar&id=` while it may be shown (404 else). `withFaces` gives every
  `{handle}` in an answer or page `picture`; `avatarHtml` draws only this
  site's `/api/people?op=avatar&id=` (`.avatar.pictured`), else the tile.
  POST `?op=avatar_remove` takes it off; `/admin` shows it on a report about
  the profile (`tr[data-picture]`, `img.reported-avatar`) and
  `?op=remove_avatar&handle=` takes it out; deleting the account deletes
  its file (`deleted.avatars`).
- `likes on a profile` (`supabase/avatars.sql` `profile_choices`,
  `profile_likes`, `profile_likes_count`): `/settings` `#shows-likes`
  (POST `?op=likes_choice {shows}`, off by default); then a Likes tab
  (`data-tab="likes"`) on `/u/<handle>` and `/profile`, and GET
  `?op=likes&handle=X&page=N` (404 while not shown). `?op=profile` says
  `liked_count`, null while not shown.
- `avatar browser flow` (`tools/web/avatar_flow.mjs`, preview check
  `[avatar]`): below.
- `the monthly challenge's rules` (`supabase/challenges.sql`, 2026-10-19):
  tables `challenges` (title, brief, `starts_on`/`ends_on` whole UTC days,
  `most_parts`, `set_number`/`set_name`, `tested`, `test`, `ended_at`,
  `settled_at`), `challenge_set_parts` (the set's lots, keyed as
  `model_needs`), `challenge_entries` (model, owner, `way` hand or
  assistant), `challenge_votes` (one per challenge, way and voter),
  `challenge_winners`; read by no key. Functions, the service role's alone:
  `challenge_state`, `challenge_open(tests)`, `challenge_shown(tests)`,
  `challenge_check(challenge, model)` (`{ok, parts, set: {short,
  short_lots, counted}, tested}`), `challenge_keeps`, `challenge_set`
  (refused `past`, `overlap` naming the other, `set_empty`),
  `challenge_end`, `challenge_list`, `challenge_enter` (refused `no_model`,
  `not_yours`, `under_13`, `not_asked`, `barred`, `not_in_gallery`,
  `no_challenge`, `entered`, `three`, `rules` with its check),
  `challenge_withdraw`, `challenge_for_model`, `challenge_vote` (refused
  `not_open`, `under_13`, `not_asked`, `barred`, `no_entry`, `own`,
  `breaks`, `voted`), `challenge_settle`, `challenge_page(tests)`,
  `challenge_mine(account, challenge)`, `challenge_wins(owner, models,
  tests)`. Replaces no function. `api/_challenges.js` has the words
  (`rulesSaid`, `brokenSaid`, `ENTER_SAID`, `VOTE_SAID`) and the routes;
  `withWins` adds `won` to a page of cards (`api/share.js` list and
  shelves, `api/people.js` designer page), `challengeLine` the gallery's
  line (`?op=shelves` `challenge`).
- `this month's challenge page` (`web/challenge.html`, `web/challenge.js`):
  `/challenge`, drawn from `GET /api/people?op=challenge` (with the sign-in
  `you`: `voted`, `entries`, `may_vote`, `why_not`; then `private,
  no-store`, else 30 s at the CDN): `#title`, `#days`, `#brief`, `#rules
  li`, `#how`, `#winners` (`#winner-cards .kept`), `#groups
  section#group-hand` and `#group-assistant`, each entry a `.kept[data-entry]
  [data-way]` with the gallery's card, `.challenge-said` lines (Winner, N
  votes, No longer keeps the rules) and a button (Vote for it, Your vote,
  You voted in this group, Your entry). `dataset.challenge` is `open`,
  `upcoming`, `ended`, `none`, `not-yet` or `broken`. The gallery's front
  line is `#challenge-line` (`web/gallery.js` `sayChallenge`); a card that
  won has `small.won` (`data-won`).
- `enter this month's challenge` (`web/model-page.js` `challengeEntry`,
  `enterDialog`): for the model's own designer, signed in, `#challenge-entry`
  after `#marks`: Enter this month's challenge (`button[data-enter]`), a
  `dialog.enter` with the rules, radios `way` hand or assistant, Enter it;
  a refusal lists `[data-rule]` items (`parts`, `set`, `tested`) and sets
  `dataset.challengeRefused`; once in, "In this month's challenge, …, built
  by hand. Take it out" (`dataset.challengeEntry` `entered`).
- `setting the monthly challenge` (`web/admin.html`, `web/admin.js`
  `drawChallenges`): This month's challenge, a table `#challenges
  tr[data-challenge][data-state]` with End it now, and `#challenge-form`
  (title, brief, first and last day each as three dropdowns in a
  `fieldset.date[data-date]`, `select[name=starts_on_day|_month|_year]`
  and the same for `ends_on`, this year and next; three ticks: at most N
  parts, only the parts of set N, marked Tested); `/admin?tests=1` lists
  and sets the flows' test ones. The table is at most 24 rows, the ones not
  yet ended first, open then upcoming by their first day, then the ended,
  the one that ended last first (`supabase/challenge_list_order.sql`, 2026-10-25: newest
  first, a year planned ahead and the ended test challenges runs leave in
  coming months filled all 24, and the open one and a run's own were in
  none; `tests/test_challenge_list_order.py`,
  `tools/challenge_list_order_try.sql`). Then `#year-form` (`drawYear`, Set a year
  of themes): the first month (`select[name=year_from_month|_year]`, by
  default the month after the last challenge not ended) and twelve
  `#year-months fieldset[data-month]`, each `theme_N_title` and
  `theme_N_brief`; empty months skipped; POST `/api/admin?op=plan {themes:
  [{month, title, brief}]}`, all or none, refused in words naming the month
  (`#year-note`). An upcoming row's State says `to come, told from <day>`
  until its `announced_at`. Before challenge_year.sql, `#year-not-yet`
  shows and Set the year is disabled (`year: false` in GET /api/admin).
- `challenges between months` (`supabase/challenge_year.sql`, 2026-10-24,
  docs/SOCIAL.md U12): `challenges.announced_at` (null: told at once);
  `challenge_announced(c)`, `challenge_opened(c)`, `challenge_next(tests,
  after)`, `challenge_past(tests)` (the 24 that ran, last first, winners
  with `directory_card`, a test one only while it has an entry),
  `challenge_page_at(id, tests)` (null for one not told, not opened, or a
  test one unasked), `challenge_plan(themes, lead_days 31, test)` (refused
  `none`, `words`, `days`, `past`, `overlap` with `at` and `with`). Replaces
  challenges.sql's `challenge_shown` (an upcoming one once told),
  `challenge_page` (`challenge_page_at` of the shown one) and
  `challenge_list` (+`announced_at`), each guarded in `tools/apply_sql.mjs`
  LATER. Applied live 2026-10-24; before it, GET `?op=challenge` said
  `year: false`, no `next`, `past: []`, and `&id=N` answered `ready:
  false`, as a project without it still would. On `/challenge`: `#next[data-next]`
  (`#next-title`, `#next-days`, `#next-brief`) and `#past article.past-one
  [data-past]` (`h3 a` to `/challenge?id=N`, `.note` days and entries,
  winners as `.kept[data-entry]` with `.challenge-said` "Winner, built by
  hand · 2 votes"); `/challenge?id=N` shows `#crumbs` to the hub,
  `dataset.challenge` `gone` for a number not shown; `dataset.year` yes or
  no. Held by `tools/web/challenges_stand_in.mjs` (`--hold=challenges`).
- `achievements on a profile` (`api/people.js` `achievementsOf`, `web/card.js`
  `awardsHtml`, 2026-10-24, docs/SOCIAL.md U13): computed, never stored,
  from what the profile reads: `won` (each challenge won, `a.pill.new` to
  the model, `data-won`), `ten` (designer builds ≥ 10), `tested` (a Tested
  model), `listed` (a model in the gallery), `built` (a photo of their real
  build); `ul.pills.awards li[data-award]` after `.numbers` in one
  `.standing` row on `/u/<handle>` and `/profile` (`#awards-shown`); GET `?op=profile` says `achievements:
  [{id, name, said, model?}]`. None for a profile under 13 or taken out
  (404); `/profile` of an account under 13 asks for no public page.
- the feed's entry line (`supabase/challenges.sql` `feed_rows`, which
  supersedes follows.sql's; `api/_follows.js` `feedSaid` kind `challenge`,
  with `after`; `web/feed.js`): somebody you follow entered a model, "Ada
  entered “The house” in the challenge “…”, built by hand", linked to the
  model, `.feed-row[data-kind="challenge"]`; a test challenge's only in a
  test account's feed.
- `challenges browser flow` (`tools/web/challenges_flow.mjs`): below.
- `play in a shared model` (`src/ui/share_view.gd`'s pill, `src/main.gd`
  `_ready_play`, `_play_press`, `_play_touch`, `_play_reset`, 2026-10-19;
  docs/MECHANISMS.md §21): once a shared model is up, its steps worked out
  and its lattice told of every part, the grab reads its joints and the
  pill under the bar says what moves ("Moves: steering"; only when
  Playable names something or the model has motions of its own,
  `ShareView._offers_play`: a car whose wheels only turn on their pins says
  nothing, as its card does, though a drag still turns them and the pill
  then offers Reset; walk180 W5, `viewer_steps_probe`) and how ("Drag a part that moves. Drag anywhere else to turn the
  model."; on a touch screen "Touch a part that moves and drag it…"). A
  left drag on a part that moves moves it on the builder's own joints
  (`GrabDrag.press`, held still 0.4 s first by its chain's end); one that
  does not, or a drag before the joints are read or while the timeline is
  short of the whole model, turns the view as before. A finger: the first
  one down (whatever its index) on a part that moves, or within about 10
  points of one (`_play_brick_near`: a phone's steering wheel is thinner
  than a fingertip), and past 14 px takes hold before the camera sees it;
  a second finger lets go and pinches; `brickworksShare.finger` says what
  the last was taken as. The viewer's drag draws no balance marks and does
  not weigh each frame (`GrabDrag.show_marks`), and reads the joints on a
  worker whatever the size (`read_off_thread_from`). The pill says what the drag is
  doing; let go, Reset (`view_reset`) undoes every play's step; Build it
  and the booklet put it back first. Nothing is written (the store is
  read-only). `brickworksShare.view.play`: `ready`, `shown`, `moves`,
  `title`, `says`, `played`, `reset`, `touch`, `motions`, `motions_out`; the
  page that sets `window.brickworksGrabAsk` gets the play's handles first in
  `brickworksGrab.handles` (`play: "steering"`, `GrabDrag.handle_parts`).
  A model with motions of its own (docs/MOTIONS.md, unit 3, 2026-10-20): the
  pill says "Play its motions" with a button each (`view_motion_1`…, Reset's
  face, a fingertip tall on a phone) and "Press one to play it, and again to
  put it back…" ("Tap one…" on a touch screen); pressed, `main._play_motion`
  plays it through `MotionPlayer.play` kept (one step), its frames drawn
  12 a second (`_motion_frame`, `BrickWorld.set_drawn`), the button lit while
  it stands where it ends; pressed again it plays backwards; Reset undoes a
  motion's step as a drag's and puts every button out. What the last press
  played: `brickworksShare.motion` (`name`, `backwards`, `joints` [name,
  from, to], `stopped`, `frames`, `ms`, `motions`). A sequence (unit 5) is a
  button like any motion: `MotionPlayer.play_in_order` plays its motions
  each from where the one before left the model, one step; again, backwards
  in reverse order.
- `what moves in a model` (`src/assembly/playable.gd`, `Playable.read`,
  `kinds`, `words`, `KINDS`, `MECHANISMS`): steering, turntable, boom,
  doors, gears, pneumatics, actuator, rack, from `Bodies` and the gear
  trains; sent with a publish (`SharePanel.moves_of`, `main._moves_now`).
  A steering wheel spinning alone on its stud is never the steering's
  handle. A boom works something at its end (`Playable.working_end`: a
  crane's arm, hook or basket, a digger's bucket, forklift forks, a grab),
  on it or beyond it on its chain, or is in a sub-model named for a
  machine that lifts (`Playable.lifting_named`: 4096-1's "4096 - EB
  Crane", 8862-1's "boom" and "bucket"); a door is its body's biggest part or
  hangs on the joint itself (moves268: the gallery's King's Castle and
  Dragon Defender both said "boom", the castle's being its drawbridge, and
  ten of the thirty seeds said a boom or a door they do not have).
  `tools/probe.sh moves_probe` opens the thirty seeds, the models that ship
  and two batches held out, sixteen and twenty sets
  (`tests/fixtures/moves/truth.json`, judged from renders and each set's
  steps) and fails a word a set does not move, and a word the seeds
  plainly have and do not say; `-- dump FILE...` tells each
  moving body, its joint, reach and parts. On 2e28f712 it fails 11 seeds
  and 4 held out (castles' drawbridges and walls, a house's garage door,
  wings, a train's door rail); misses that the joints cannot see (five
  small cranes' and diggers' arms) are told, not failed. The shipped kart's wheel drives its front wheels through a
  universal joint, a pinion and the rack that is its track rod
  (docs/MECHANISMS.md, section 38): `tools/probe.sh kart_steer_probe`
  (windowed) takes it where its card says, drags it round its rim each way
  by Grab, checks each stage against the linkage's ratio and undoes it,
  with pictures in `shots/kart_steer/`.
- `what moves on a gallery card` (`supabase/play.sql`, not applied until
  the owner does): `shared_models.moves` (the words, eight at most, `{}`
  for every row before), `moves_mechanism`, `directory_card` with `moves`,
  `directory_models` (discovery.sql's, technic also by moves);
  `api/share.js` `checkMoves` (400 on a word it does not know) and
  `keepMoves` (never stops a publish; `moves: null` in the answer before
  the file is applied), `api/_directory.js` `MOVES`, `movesOf`, `cardOf`'s
  `moves`; `web/cards.js` "Moves: steering, boom" on the card
  (`data-moves`). And a model's own motions (`supabase/motions.sql`, not
  applied until the owner does): `shared_models.motions` (names, 12 at most
  of 60 characters, `motion_names_ok`), `directory_card` with `motions`;
  `api/_directory.js` `motionsIn` (the names read from the text published),
  `motionsOf`, `movesWords`; `keepMoves` sends both in one request, and
  the words alone when that fails (`motions: null` in the answer before the
  file is applied); the card "Moves: open the dome, extend the telescope"
  (`motionWords`, three and "and N more", `data-motions`), the page's facts
  all of them, or the words.
- `share play probe` (`src/dev/share_play_probe.gd`): below.
- `what a frame costs in a browser` (`tools/web/look_cost.mjs`): serves
  the export with `serve.py --share L00kM0del1=vendor/omr/files/6392-1.mpd
  --share Pl4yFl0w01=vendor/omr/files/8808-1.mpd`, with .env sourced, and
  runs in Chromium on SwiftShader at 1280 x 800 and 390 x 844 (3x).
  `--mode=cuts --rounds=1` pins each cut in the page with "none" between
  every two and times a turn of the view up to a WebGL fence after it
  (SwiftShader draws behind the page, so the page's own frame gaps are
  17 ms whatever a frame costs). A build without FrameBudget measures
  "none" alone (`--base=3`): run the base and the branch in turn, A B A B,
  each row saying the load. The first row of each scene is a warm-up.
  `--mode=acts` (orbit, a part dragged, a brick swept in hand, and Play's
  steering drag) runs on any build; `--gate` fails where the app chose no
  lighter look by the end of the acts, which a build without FrameBudget
  never does. Each act says the cuts in force when it began and any made
  during it. The acts begin once the page is quiet, which comes sooner on
  a build that draws less while loading; `--from=30` begins them 30 s after
  the engine started, so two builds paired are turned at the same moment.
  Numbers: docs/SLOW_DEVICES.md.
- `play browser flow` (`tools/web/play_flow.mjs`): below.
- **The sitemap** (`GET /sitemap.xml`, `api/share.js ?op=sitemap`, routed by
  `deploy.sh`, with `web/sitemap.xml` beside the function as `_sitemap.xml`):
  the site's own pages and every listed model, profile with a model in the
  gallery and public collection with one (`sitemap_pages`), the CDN keeping
  it an hour. **OG cards and structured data**: a model's page has og and
  twitter cards with its description, a canonical link, and JSON-LD
  (schema.org CreativeWork: name, url, description, image, author as
  credited, licence, keywords, what it is based on, views and likes; "<"
  written \u003c); a profile's and a collection's page have cards with
  their first model's picture. **The CDN** keeps the list, a model's page and
  its pictures, and profile and collection pages, for 30 s and serves them 30 s
  more while it asks again (`SHARED_CACHE`, `public, max-age=0, s-maxage=30,
  stale-while-revalidate=30`); a versioned small picture five minutes in a
  browser; the viewer's JSON, everything signed in and anything asked with
  `tests=1` (`TESTS_CACHE`, `private, no-store`), never. A model taken
  down or out leaves within a minute rather than at once; the probes ask past
  the CDN with a query of their own, and the browser flows load a page again
  until it shows what was done, for two minutes at most.
- `moderation browser flow` (`tools/web/moderation_flow.mjs`): below.
- `directory` (`api/_directory.js`): what the list, a model's page and
  publishing share — `KINDS` (the same ids, in the same order, as
  `src/net/model_kinds.gd`), `LICENCES`, `SIZES`, `SORTS`; the edge's
  cleaning of a description, tags, a kind and a licence; `listQuery` and
  `searchWords`; `cardOf`; `partFacts` (`./_part_facts.json` in a deployment,
  worked out from `assets/generated/catalogue.json` in a checkout by the same
  `derivePartFacts`; a number LDraw moved, 3648 to 3648b, counts as its new
  one); `looksLikePerson` and `visitorKey`; and `siteChrome`, the site's
  header and footer taken from `web/gallery.html` (`./_site.html` in a
  deployment, a footer of its own with the notice if neither is there), so
  a page made by a function is a page of the site and changes when the
  site's do.
- `model kinds` (`src/net/model_kinds.gd`): `ModelKinds.KINDS` and
  `guess(text)`, the Share panel's first guess at a kind from the name, the
  tags and the description, read with the design loop's vocabularies
  (`Style.GROUP_WORDS`, `Style.TRAITS`) as whole words (`SubjectWords`), the
  narrow before the broad: a mechanism, space, castles and fantasy, figures,
  art, vehicles, architecture, town, robots, nature.
- `part facts` (`tools/web/part_facts.mjs`): writes the Technic parts and
  the parts that make a model move (gears, worms, differentials, motors,
  actuators, chain links, pneumatics; never a "~" sub-part or a sticker)
  from the catalogue; `deploy.sh` puts it beside `/api/share` as
  `_part_facts.json`, and fails the deploy if the catalogue gives fewer than
  500 and 50.
- `list load test` (`tools/web/list_load.mjs`): N requests to the list (200 by
  default, 10 at a time), each a question a person could ask, timed; passes
  with no errors and nine in ten within `--most-ms` (2500).
- `gallery page` (`web/gallery.html`, `web/gallery.js`): `/gallery`, its
  `.html` redirecting to it as every page's does (`deploy.sh`'s page loop; the
  local relay maps `/gallery` itself). Since U3 (docs/SOCIAL.md, 2026-10-22)
  the work first: the title and a search (`#q`, asked 350 ms after typing
  stops, at once on Enter) on one line; the tabs `#tabs [data-tab]` Top · New
  · Following (Following only signed in and once the list says `following:
  true`), one `aria-current`; Top over `#window` (All time, This month, This
  week: `window=month` or `week`, offered when the list sends `windows`); the kinds as
  `#kinds button.pill[data-kind]`, one `aria-pressed`, a row that scrolls
  inside itself; `#filters` (a `.more-menu` whose summary says how many are on)
  holding the order (Top builds, Newest, Most liked, Most built, Most remixed,
  Parts I own signed in; never Most viewed), Size, `#made` (Hand-built, With the
  assistant: offered when the list sends `mades`), Has instructions, Technic,
  Tested only, and Clear the filters; a tag as a chip to take off. Then the
  cards (`web/card.js`, `like: true`), two to a row under 900 px, three to
  1200, four above; on the front (Top, all time, nothing asked) this week's
  pick first and the shelves after the first rows (`ui:the gallery's front
  shelves`). A card's heart likes it from the card, signed in, at once
  (`POST /api/people?op=like`), and asks to sign in when not. The next page
  comes by itself as Show more comes within a screen of the window, three
  times (`data-auto`), then waits for Show more; a page that came by itself
  is put in only while the end of the list is under the screen, and waits
  (Show more pressable, drawing it at once) while Put yours here or the
  footer shows (site277: it pushed them down, CLS 0.51 signed in at 1280);
  the shelves' cards are lazy; the address keeps the question and
  how many pages (`/gallery?q=castle&kind=space&sort=newest&page=3`), put back
  with `replaceState`, so it can be sent; a card opened is kept in the
  history's state and Back puts it where it was (`data-back` its id or
  `lost`). States: `#empty` (nothing listed, with Open the app), `#nothing`
  (nothing matches, with Clear), `#quiet` (Following with nobody, or a quiet
  week, with its way back), `#broken`. `data-gallery` on `<html>` is `asking`,
  `ready` or `broken`, `data-pages` how many are shown. An address asking
  what the list does not know gets the whole gallery and its address put
  right; an answer to an older question is thrown away. `tests=1` asks the
  list with test models in on every question. Before `supabase/gallery_tabs.sql`
  is applied `api/share.js` answers from `directory_models` and refuses
  `window`, `following` and `made` in words (400); after, from
  `gallery_models`, its cards carrying `comments`.
- `gallery browser flow` (`tools/web/gallery_flow.mjs`, preview check
  `[gallery]`): below.
- `seed the gallery` (`src/dev/gallery_seed.gd`, `tools/web/gallery_seed.mjs`):
  the project's own showcase models, listed by the project's account
  (`gallery@brickworks.diy`, signed in as the tests are) so the gallery is not
  empty on day one. The Godot half opens each file in the real app and
  publishes it through the real Share panel (Show who made it: Brickworks;
  List it in the gallery ticked) into a `SharedModels` that keeps the body —
  so the pictures are the panel's own; the node half publishes those bodies to a
  deployment's `/api/share`, updating at its link any model that account
  already shares under the same title. The list is
  `tools/web/gallery_seeds/seeds.json`, beside the files that are not in
  `models/`: each model's file, title, what its page says (a sentence or two,
  its tags, its kind, its licence, CC BY 4.0 for all) and, for two, the way
  the view is turned for its picture (`turn`, [yaw, pitch] in degrees: the
  tower from lower down, the car from its front). The Godot half types them
  into the panel's own boxes and menus and checks each body says them, with
  a 480 x 252 card picture. Seeded 2026-10-13: Wizard's Tower
  (`models/orthanc.ldr`) and A castle, from one sentence
  (`models/castle.ldr`), A barn owl and A sports car, and its driver (the
  homepage's renders), A three-core heavy-lift rocket and A small modular
  corner shop (the bench's best, 2026-10-12); re-seeded the same day with
  their words, kinds, licences and card pictures, and Orrery of the Sun and
  eight planets (`models/orrery.ldr`) added, first in the gallery since it
  was listed last (an update keeps its listing time). Titles carry no
  licensed name (films, books, brands): the tower is Wizard's Tower on every
  public page, and since the re-seed its file's figures are named as the
  app's are, not as the book's. A fixed model goes up as its link's next
  version: run the Godot half on a list of just that one (entries copied
  from seeds.json, which carries the ai-designed tag the seven were given
  live, since the panel sends tags every time) and the node half updates it,
  sending the entry's `note` (what changed, shown with the version) and the
  panel's own Tested finding; `--dry` first says `would update <id>`, which
  proves the account is the house's. Republished 2026-10-23 (m158's files):
  the castle and the orrery, each version 2, Tested, 2,497 and 502 parts,
  version 1 kept at `/m/<id>/v/1`. The Godot half waits for the app's own
  sign-in check to give up before it signs the panel in: since that check
  asks again (2026-10-20) its answer signed the panel out after the first
  model. Twelve more seeded 2026-10-24 (seed211), after the seven in
  seeds.json, their files beside them: each designed on the subscription
  by the app's own designer (`--ask-claude-code`), then its steps put in an
  order a person can follow (nothing put down before what holds it, hidden
  behind what is built, or hanging past what its studs hold), a part printed
  here put back as its real part, a colour no part was made in changed, and
  Tested by the panel: 37 to 678 parts across nine kinds. The site lists six
  models an hour from one account (`may_list`, `supabase/gallery.sql`), so
  more than six go up as node-half runs an hour apart, each on a DIR of at
  most six bodies; a seventh is refused 429 and nothing of it is kept.
  The scripts that made them are `tools/house_models/` (each says how in its
  header): `design.sh` (one design on the plan), `finish.sh` (`flatten.py`
  then the step fixer `fixsteps.gd`, which derives an id-naming copy of the
  Tested check from `src/assembly/tested.gd` as it runs), `colours.py
  --check`, `drop.py`, `tested_check.gd`, `preview.sh` (the Godot half and
  each body's Tested finding), `house_listing.mjs` and `compare.py` (the
  read-only before and after) and `live_shot.mjs`. Proved 2026-10-24: the
  committed `finish.sh --steps` on the tractor's design wrote the file the
  published tractor was made from, line for line, and `tested_check.gd` on
  the twelve seed files said TESTED for each. Four of the older seven went
  up as version 2 on 2026-10-24 (house227), Tested: Wizard's Tower as
  `models/orthanc.ldr` stands, and the barn owl, the rocket and the corner
  shop fixed by hand into `models/` (their originals gone from
  `tools/web/gallery_seeds/`). `fixsteps.gd` now names every part of the
  whole test's findings by its line (each pair that passes into the other,
  each loose piece with all its parts), and when a part is hidden even
  beside what holds it, the parts in front of it wait for it (the shop's
  wall studs). The sports car followed as its version 2, Tested
  (`models/sports_car.ldr`; its sub-model original stays in
  `tools/web/gallery_seeds/` for the step count probe): each fender was a
  brick body over a wheel with nothing under it, and now sits a stud in and
  a plate up on the chassis brick, over the hood's grille tiles and the
  rear deck's black slopes it replaced; its floor bricks go in first, so no
  step tips. The shelf from the LDraw library (gallery261, 2026-10-25):
  `tools/house_models/ldraw_shelf.py --table` writes
  `tools/web/gallery_seeds/ldraw_library.json` from the library's index and
  every FILE section of each `vendor/omr/files` model (one person, one
  licence, CCAL 2.0 or CC BY 4.0, under 250 KB, or it stops), each entry
  with its `credit` {by, licence, page}, shared by Brickworks as
  "LEGO® set 6080 King's Castle" under `cc-by-2.0` or `cc-by-4.0`; the
  Godot half keeps the credit in the file as the Library does
  (`store.credit`) and says the licence the panel's menu lacks in the body
  (the server keeps the Library's licence in any case).
  The node half's `--only=A-B` sends a slice of DIR (six an hour, twenty a
  day), and `--collection="From the LDraw library"` puts each in the house's
  public collection of that name, made when it has none. Needs
  `supabase/modelled_by.sql` applied first.
- `shared model page and card`: `/m/<id>` and `/m/<id>/embed`, rendered by
  `api/share.js` (above) and routed by `deploy.sh` before the catch-all, so the
  app's isolation headers and CSP are not put on them. Since the directory
  (2026-10-13) `/m/<id>` is the model's own page, a page of the site (its
  stylesheet, header and footer, `siteChrome`; `web/directory.css` for what only
  it has). Since U4 (2026-10-22) the picture (a link into the viewer) leads,
  with a column beside it on a laptop that stays on screen as the page
  scrolls (`.side`, sticky) and under it on a phone: the name, the designer
  (`.shared-by`: avatar, name and @handle linking to /u/, Follow), Build it
  (`.actions a.cta`, `/app?view=<id>&build`: the step player at step 1) and
  Open in Brickworks, the action bar
  (below), then facts as pills (Tested first, parts, steps and whether they
  are its builder's, Technic, Moves, views, when it was listed, its version
  and remixes as links), and what it was remixed from while that is listed
  ("a model shared by link" when not); its builds, versions,
  what its owner wrote (escaped, its lines kept), its tags (each a link to
  `/gallery?tag=`), its kind (in the crumbs, a link to `/gallery?kind=`), its
  licence in words with whom to credit and the licence's own page, and its
  remix tree (the line it came from, eight back at most, and the listed
  models made from it as small cards, with how many more are shared by link
  only). A canonical link and the description in its card. Its policy lets it
  load the site's stylesheet and talk to its own origin and nothing else.
  `web/share-page.js` is its one script: it counts the view once a day in
  this browser (`localStorage` `brickworks.seen`), and when a reload finds the
  viewer's mark in the history (`main._set_address` puts
  `{brickworksViewer: id}` there with `/m/<id>`) it `location.replace`s back
  to the viewer, so a phone whose tab reloaded mid-build is not left on the
  page. A link taken down answers 410 "This model is no longer shared" and
  names nothing; one that never was, 404 (both pages of the site too). The
  card is a picture and a View in 3D that opens the link in a tab. Until the
  page's picture is drawn its frame says "Loading its picture…" (`.picture
  .waiting`, the card's no-picture face), and one that fails is asked again
  twice (`web/model-page.js` `startPicture`) before it says "No picture": the
  first view right after publishing was a blank grey frame (walk180 S2).
  `model_page_flow` holds the picture (and fails it once) at 390 and 1280,
  light and dark (`picture_waiting_*.png`, `picture_came_*.png`).
- `shared model viewer` (`src/ui/share_view.gd`, `main._enter_view`,
  `_view_shared`; `src/net/shared_models.gd`): `/app?view=<id>` — the app's page
  itself since 2026-10-12, query and all, so the address bar keeps it (`?copy=`
  likewise) — which the shell hands the app as `--view=<id>`
  (checked against `^[A-Za-z0-9]{10}$` before anything uses it). The same app,
  read-only, no second renderer: one GET of `/api/share?id=` — made by the
  page itself the moment it loads (`src/boot/shell.html`,
  `window.brickworksSharePrefetch`, 2026-10-17), while the engine downloads
  and starts, and taken by `SharedModels.fetch` (on a preview it came 2.4 s
  after the engine's first frame when the app asked) — (asked again, up
  to three times, when nothing at all comes back: on a preview a viewer said
  "Could not reach Brickworks" once in four runs, and the same link opened at
  the next try), the model opened
  through `ModelStore.open_text` (made parts and prints built from the file),
  the parts fetched, then the timeline (`StepsBar`) at the finished model,
  whose Next and Back (and the arrow keys) outline the step's new parts and
  turn and frame the view on them as the step player draws that page
  (`main._light_step`, `StepsBar.stepped`; any other move lets them go;
  walk180 W4, `viewer_steps_probe`); a bar
  along the top with the name, part count and author, Steps, Booklet, Parts list
  and Open in Brickworks; the part under the pointer outlined in blue and named
  beside it (`_view_hover`, the lattice ray, skipping parts the timeline hides);
  the address put back to `/m/<id>`; a remix's about line ends "· remixed from
  X", and a click on it opens X's link (`view_remixed_from` in the controls,
  `about` and `remixed_from` in `view`). **No sign-in** (no gate) and **no write
  path**: `Shell.can` runs only `Shell.LOOKING` (views, fit, timeline, parts
  list, instructions, full screen, website, about), the mouse goes to
  `_view_input` (a left drag turns the view, Shift slides it; on a part that
  moves, once its joints are read, it moves it: `play in a shared model`) and
  the keys to `_looking_key` (F, Home, End, Space, arrows, 0–7, B, P, Esc),
  `ModelStore.read_only` makes its one writer refuse (autosave, Save, Save as),
  `CustomParts.keeps` off builds carried parts for the visit only,
  `ShellPrefs.frozen` neither reads nor writes the visitor's layout,
  `Account.keeps` off never reads, renews or writes their session, and the
  connector never starts; the builder's bars, panels, toolbar, status bar and
  key strip are hidden. The parts list (`InventoryPanel`) now has BrickLink and
  Rebrickable buttons of its own (`shop_wanted`, also in the builder), since a
  viewer has no File menu. Open in Brickworks goes to `/app?copy=<id>` — see
  [account](account.md). A link taken down or wrong: a card saying so with Go
  to Brickworks. Published to the page as `window.brickworksShare` (`viewing`,
  `read_only`, `keeps`, `view` {state, name, author, parts, title, says,
  hover}, `steps` [shown, total], `parts_open`, `panel`, `title`), with the
  bar's, the timeline's (`steps_*`) and the parts list's (`parts_*`) controls
  in `brickworksControls`. **Not interactive inside somebody else's page**:
  the threaded engine needs cross-origin isolation, which an iframe in a page
  that did not ask for it cannot have — so the embed is the card, and the 3D
  opens in a tab.
- `build it step player` (`src/ui/build_mode.gd`, `main._enter_build`,
  `_build_go`, `_leave_build`): **Build it**, first and yellow on the viewer's
  bar, turns the viewer into a step player for building the model with real
  bricks, on a phone, a tablet or the desktop. The whole window: along the top
  Close, "Step 3 of 24" (a callout's steps as the timeline says them, "Step 12
  of 40 · Window (2x), 1 of 3") and a progress bar; the model between the bars,
  what earlier steps built drawn **faded** (`BrickWorld.set_faded`: washed pale
  and still solid — x-ray's 4% ghosts left the new parts floating) and the
  step's new parts in their own colours with a yellow outline; along the
  bottom the step's parts on a pale card, a picture and "2x" each, and a Back
  and a bigger red Next. Page 0 is the finished model, "Ready to build", with
  Start; Next past the last step (Finish) is Close. Sized in points, not
  interface units (a phone has ~1.85 units to the point): Next and Back 60 pt
  tall, the step at 24 pt. A swipe across either bar turns the page (left is
  Next) and never turns the model; on the model one finger turns it and two
  pinch, as `CadCamera` already did — `_view_input` now leaves a finger's
  emulated click alone, which turned the view a second time. Keys: Right,
  Space, Page Down, Enter are Next; Left, Page Up, Backspace Back; Home the
  cover, End the last step; Esc Close. Each page opens on the view the booklet
  would draw it from (`BuildSteps.view`: front unless the new parts are
  hidden from there and the back shows them, decided per page) framed between
  the bars (`CadCamera.seen` is the player's free rect while it is up), close
  round the new parts when they are under a fifth of the model across. The
  page is kept per link on the device — `localStorage["brickworks.build.<id>"]`
  = `{"page", "building"}`, the one thing the viewer writes, and only in the
  browser (this run only on the desktop) — so a link opened again goes
  straight back to the step it was on. The steps are the timeline's
  (`StepsBar.steps`); since they break ties by the order parts stand in, the
  viewer opens a link a second time once every part has arrived, so the parts
  stand in the file's order and step 12 is the same step 12 after a reload.
  Published as `brickworksShare.build` (`open`, `page`, `last`, `caption`,
  `note`, `told`, `lots`, `pictures`, `next`, `points` of the buttons,
  `caption_points`, `faded`, `fresh`, `shown`, `from`); controls `build_next`,
  `build_back`, `build_close`, `build_parts`, `build_top`, `build_bottom`, and
  `view_build` (the bar's, or on a window under 1,040 points a big yellow
  Build it over the model, above the timeline: where the timeline's top is or
  will be, from its first frame, so it never moves as the timeline comes once
  the steps are worked out; it rose 46 px then, and a tap meant for it landed
  on the timeline, `builds_flow --first-told`, 2026-10-26). `brickworksState.told_ms` and
  `told_most_ms` say what publishing all this to the page costs a frame,
  twice a second. **A page turn** (2026-10-17) changes the step's parts,
  not the model: a page is a count of the build order (`BuildSteps.order`,
  `count`, shown by `BrickWorld.reveal_upto` with the timeline's own order
  and key when the pages are its steps, so the world the timeline laid out
  is laid out for the player and the cover costs nothing), and only the
  bricks whose fading changes are faded or not (`BuildSteps.fading(from,
  to)`: the two pages' own parts and those of the pages between), each
  written into the buffer its batch was written with and the batch handed
  that buffer again (`BrickWorld.set_faded_in_order`; `_write_in_order`
  packs it and keeps it — a slot written in place is never drawn in a
  browser). It asked every brick whether it was shown and faded and wrote
  every batch holding one that changed again whole: on 4,000 parts on a
  phone slowed four times, 90 to 500 ms a turn and 1.4 s to the last page;
  the turn's own work is now 2 to 10 ms (`turn_last`). A tap on or within
  16 points of the progress bar goes to the step under it (`page_wanted`,
  control `build_progress`; the bar keeps its size, so every picture of a
  step is as it was). Build it tapped while the steps are still being
  worked out is taken up when they are (`_build_wanted`; it did nothing).
  `brickworksShare.build` also has `turn_last`, `turn_frames` (the rest of
  the turn's frame) and `told_laps` (what telling the page cost, piece by
  piece), and the page hears which frame drew a page
  (`window.brickworksBuildDrawn`). **The parts' pictures** along the bottom
  are asked for once the page is drawn (`BuildMode._watch_after_this_frame`)
  and drawn ahead while the page is left alone (`main._draw_ahead`: once the
  page's own are in and a second has passed, the next three pages' parts and
  then every other page's, a stage's worth (`PartThumbnails.STAGES`) at a
  time, each part in a colour once, kept by `PartThumbnails`): drawn only
  when a page asked, a picture took seconds behind the turn on a slowed
  phone, and pictures of the player showed blank tiles. `pictures_ms` in
  `brickworksShare.build`, and `window.brickworksPicturesDrawn` = [page,
  when] the frame every picture of the page is in. Not done: the author's own steps (`0 STEP`, item 1
  of docs/COMPETITIVE.md) are not kept yet, so these are always
  `Instructions.plan`'s; the parts are fetched for the whole model before
  the first page, not page by page; a link shared before steps were carried
  (`SharedPages`, below) still has them worked out on the phone (9 to 12 s
  after the first frame for 1,000 parts slowed four times, 75 to 135 s for
  4,000). The grab's twice-a-second search for handles stalled turns on
  4,000 parts by 180 to 460 ms (found by `share_steps_flow --trace`, in the
  nodes' processing, not Main's); the viewer stops the grab
  (`_grab_drag.set_process(false)`), and the stability weigh, and tells the
  lattice of the parts after the model is up (`ModelStore.lattice_later`,
  `register_later`). Left: on a box at load 30 to 50 a turn's frame now and
  then waits hundreds of ms to seconds inside WebGL calls on SwiftShader
  (the part pictures' fence, the outline's window-sized passes, step 30's
  7,000 calls), however little the app did (see the share steps flow
  below).
- `build pages` (`src/assembly/build_steps.gd`): what each page shows —
  `shown`, `fresh`, `faded`, `lots` (by part and colour via `Inventory.key_of`,
  the most first), `caption`, `note` ("Build this on the side", "Put them on",
  "hold this one in place"), `view` — and `recall`/`remember` for the kept
  page, which reads a stored value of the wrong shape as none.
- `steps carried with a shared model` (`src/net/shared_pages.gd`,
  `SharedPages`, 2026-10-17): the Share panel works the model's build steps
  out once ("Working out its steps for the link…") and writes them at the end
  of the text it publishes: `0 !BRICKWORKS PAGES {v, model, order, parts,
  mode, steps}` and a `0 !BRICKWORKS PAGE {i, n, b, …}` line a step, every
  field of `Instructions.Step` with bricks as their place in the order the
  viewer puts the text down. They are worked out on a world of their own put
  down as `ModelStore.open_text` puts a file down (flattened, Studio parts,
  unmirrored, resolved, the known parts in turn, lifted alike), by the same
  `Instructions.plan_paced`. The viewer (`main._view_shared`) reads them with
  `SharedPages.read` and starts the timeline from them (`StepsBar.start_from`)
  only when `model` (the text's lines trimmed, blanks and these lines left
  out, SHA-256) and `order` (the parts and colours in the order it put them
  down) match, and works them out as before otherwise — an old link, a
  model edited since, a catalogue that differs. No server or database
  change: api/share.js takes them as LDraw meta lines; a file over 1.9 MB
  with them goes without. `brickworksShare.carried` says which, and
  `window.brickworksStepsReady` when the steps were in. A kept source file
  drops them on save (`ModelStore._without_app_lines`). Proved by
  `src/dev/share_pages_probe.gd` (below) and the share steps flow.
- `versions of a shared model` (`supabase/versions.sql`, `api/_versions.js`,
  `api/share.js`, 2026-10-18; **not applied to the live project yet**, the
  owner applies it at release, before the deploy): publishing a link again
  makes its next version and keeps the one before. Table `share_versions`
  (`model` → `shared_models(id)` on delete cascade, `n`, `at`, `note` 1 to
  280, `parts`, `steps`, `bytes`, `has_image`, `changes` jsonb, `first_changed`,
  `remixed_from_version`; primary key `(model, n)`; row security on, no grant
  to `anon` or `authenticated`: only the server; **applied to the live project
  2026-10-18** with `tools/apply_sql.mjs`, dry-run first, 7 rows), and a version 1 for every
  model published when it is applied. The newest's files stay `<id>.mpd` and
  `<id>.png`; an older one's are `<id>.v<n>.mpd` and `<id>.v<n>.png`, renamed
  when a newer one takes the link (the sweep keys by what is before the first
  dot, so it keeps them while the model is published). What changed is
  worked out by `changesBetween` from the two files, never typed: the parts
  by part and colour; and, when both carry their steps (`SharedPages`) and
  the server's own flattening of each file (`partsOf`, as `LdrModel.flatten`)
  gives the same parts in the same order the steps were counted in (the
  `order` SHA-256), the steps added, taken out and changed, the steps the
  added and removed parts are in, and `first_changed`. A file without
  carried steps has its parts compared and `first_changed` 1 if any changed.
  `saidOf` says it short ("Version 2: 2 parts added and 2 removed in step
  3."). `GET ?id=X[&v=N]` answers `version`, `newest` and `versions` (the
  newest hundred: `n`, `at`, `note`, `said`, `first_changed`, `url`);
  `/m/X/v/N` (`?op=page&v=N`) is an older one's page — "An older version",
  its own picture (`/m/X/v/N.png`), counts and viewer (`/app?view=X&v=N`),
  noindex, canonical the link — and the link's page has a Versions section
  (what changed, the owner's note, "Steps 1–2 are as they were", part by
  part, the others). POST takes `note` and `remixed_from_version`; the
  answer has `version`, `said`, `changes`, `first_changed`. A version counts
  as a publish (`may_publish`). Unpublish deletes every version's files and
  rows. **`tools/deploy.sh` has no route for `/m/<id>/v/<n>` yet** (the
  relay server has). Until it does, Vercel passes a query on through the
  `/m/<id>` route (the gallery's `/m/<id>.webp?v=` relies on it), so
  `/m/<id>?v=<n>` should reach the same page; not yet tried on a
  deployment. The app: the Share panel's What changed? (for a model with a link;
  `brickworksShare.panel.note`, `version`, `said`); the viewer's version line
  (`view.version`, `newest`, `version_line`) and, for a place kept on another
  version where a step at or before it changed (`BuildSteps.changed_since`),
  "This model changed from step J since you were on step K" with Build from
  step J and Keep step K (`view.place_says`, `view_build_from`), and in the
  step player "This model changed from step J." with Go to step J
  (`build.changed`, `build_changed_go`); the kept place has its version
  (`brickworks.build.<id>` = `{page, building, version}`); a copy keeps the
  version it came from (`0 !BRICKWORKS REMIX_VERSION n`) and its page says
  "Remixed from X, version N".
- `content security policy`: every page may connect only to itself, Anthropic,
  Wikimedia, the parts store's origin (from `PARTS_URL`) and the sign-in
  service's (from `SUPABASE_URL`, named on its own since 2026-10-11: it was
  reachable only because the parts store is in the same project); the page's
  one inline script is allowed by a hash computed at deploy, which is why
  `web/admin.html` loads `admin.js` rather than carrying a script; `unsafe-eval`
  stays for Godot's JavaScript bridge. The defence for a key held in a browser
  is that it has nowhere else to go. `assistant_flow.mjs` and
  `account_flow.mjs` fail on any refusal in the console.
- `signed in, in every browser flow`: `tools/web/browser.mjs` gives each
  context a session of the test account, minted on the test side
  (`tools/web/session.mjs`, needs `.env` sourced), so `check.mjs`, `fit_check`,
  `assistant_flow`, `connector_flow` and the rest drive the builder rather than
  the sign-in screen. `deploy.sh` sources `.env`, so its checks are signed in.
  Pages of the site that are not the app launch with `{ signedOut: true }`.
- `which build this is`: the deploy writes `version.json` (commit, UTC time)
  beside the build, and the Help panel finds it beside the engine
  (`GODOT_CONFIG.executable`), not beside the page — at `/app` the page is not
  in the build's directory — and shows "This build: <commit>, updated
  <local time>". The owner, looking at the live site, could not tell when it had
  last been deployed. Desktop builds say "Development build".
- `fits the page at every density`: the layout stretches to the canvas
  (`canvas_items`, expand), device pixels and all, so `Main._match_screen_density`
  adds nothing on a wide window; below `ROOMY` it sizes the interface from the
  window in points (about 720 x 480 units). It multiplied by the device ratio
  too, and at 2x the toolbar ran off at "He…" with the assistant off the page.
  `tools/web/fit_check.mjs` opens 1x, 2x and 3x desktops, a small laptop window
  and a phone both ways and requires every published control (the toolbar's
  Clear included) on the page; the deploy runs its `--quick` pair. On the
  phones it asks for Clear and both panels' rails (`parts_rail`,
  `assistant_rail`, published from 2026-10-11): it asked only for New and
  Save while the one-row toolbar pushed Clear and the assistant's rail off
  every phone. A drawer is sized in the interface's units, not points: in
  points a phone is 390 across where it shows about 720 units, and both
  drawers were cut off down their right edge. It also samples the model's part
  of the window at each size (`window.brickworksLayout`, building's `docked
  panels`): nothing over it but the view cube, and at 1100 x 700, 1280 x 720,
  1400 x 900 and 1440 x 900 at 2x and 3x the model keeps 60% of the width,
  with the assistant's key field and both rails on the page (a first visit
  there shows the assistant). The deploy's `--quick` set is 1400 x 900 at 2x,
  1100 x 700 and the phone. A page whose app never publishes its controls
  within `START_MS` (5 minutes, arrival_check's budget; `--start=<s>`) is
  its own failure, "the app did not start in N s (load L)", and fit_check
  exits 2 when that is the only kind, which `deploy.sh` reports as not
  starting rather than not fitting: a production deploy failed at load 80
  with nothing on the page at one size, reported as every control "not
  shown". Each size that started says how long it took ("up in N s").
  Proved on a local export at load 30 to 45 (2026-10-13): `--quick` passes,
  each size up in 17 to 25 s; `--quick --throttle=30 --start=120` (each
  page's CPU slowed by Chromium's `Emulation.setCPUThrottlingRate`) says
  "the app did not start in 120 s (load 46)" at every size and exits 2. A browser flow after a control in the folded
  column calls `openColumnFor(page, name)` (`tools/web/browser.mjs`), which
  clicks that column's rail as a person would, by `brickworksState.columns`.
- `browser check`: `tools/web/check.mjs` loads the real URL in real Chromium and
  waits for the canvas to show something other than the loading colour.
- `freeze check`: `tools/web/freeze_check.mjs` makes the design that froze the
  owner's computer — their 4,242-part Falcon Heavy, `src/dev/fixtures/
  falcon_heavy.json` — in a real browser, playing Claude over the connector
  (check it, submit it, read it back, look at it, recolour a brick, review
  it), and times the page through each call and the build animation after:
  the app's own slowest frame (`Main._watch_own_frames`, published as
  `brickworksState.slow`, from a frame's start to its drawing, or, for a
  frame that draws nothing, to the end of its scripts: `OwnFrames`), long tasks,
  the longest gap between frames, a mouse move's wait, bricks, batches,
  triangles and the WebAssembly heap. Each slow frame carries what the app
  was doing (the tool called, the assistant's last step), and the longest of
  each call is printed with it. With `--dir=build/web` it serves the
  export itself through `tools/web/relay_server.mjs --static`, the deployment's
  real functions; with `--url=` it drives a preview (`BW_BYPASS`). `--calls=`
  replays a run's own calls. Fails when a frame of the app's own work is over
  `--budget` (500 ms: the browser here is niced on a shared box and runs the
  scripts four to eight times slower than the desktop app, whose freeze_probe
  holds 200 ms on a GPU) or a call goes unanswered; a build from before the app
  timed its own frames is judged by its longest task (`--task-budget`, 10 s).
  Long tasks are otherwise printed beside the idle page's and not judged:
  drawn in software (SwiftShader), an idle page's every frame is a task of a
  second here. So is the wait for a picture to be read back
  (`ModelShot.gpu_wait_us`), printed apart: in software it waited on every
  frame queued before it, tens of seconds, until the read waited for a fence
  with the drawing held (`GpuFence`, 2026-10-11); now milliseconds. Still
  over budget then: frames of 670 to 1,750 ms while check_design's design
  went down, and as much drawing every frame as drawing only what changed
  (902 and 973 ms in one build; 1,645 ms on integrate with `IdleDraw` taken
  out). Timed, each was one new batch counting its triangles from its
  mesh's arrays, which are read back off the card: a synchronous
  getBufferSubData that waits for the frame before to be rasterised, once
  for every part new to the page. `BrickWorld._triangles_of` now takes the
  index count the mesh keeps: side by side, check_design's longest frame
  went from 1,754 ms to 413 ms. The longest left is the autosave
  (`ModelStore.tick`, writing the whole model a second after it changed):
  about 200 ms on a quiet box, 450 to 540 ms on a busy one, so a run on a
  loaded machine can still go over on submit_design. The 590 ms once seen
  after edit_model's picture did not come back (edit_model 190 to 350 ms
  in six runs). Leaves `console.log` (what the app printed, as it came)
  and `freeze.json`.
- `redraw check`: `tools/web/redraw_check.mjs --url=…` puts one red brick on an
  empty baseplate in a browser, turns it (`R`), mirrors it (`Shift-M`), nudges
  it three studs (arrows) and lets go, finding the red on the canvas after each:
  it must have moved. In a browser a batch's instance data written over in
  place was never drawn, so a brick turned or nudged stayed where it had been
  while its outline moved on (live site and every build to 2026-10-11) — desktop
  OpenGL drew the same writes. `BrickWorld._fresh_slots` lets a batch's slots go
  and takes them again on every rebuild, so each one writes a new buffer. Run
  it against a local export the way `freeze check` does (`relay_server.mjs
  --static`) or a preview (`--bypass`); pictures in `--out`.
- `the real-set index beside the build`: the index `find_techniques` searches
  (`assets/knowledge/snippets.json.gz`, 3.6 MB with its descriptions) and the part looks
  (`part_looks.json`) are not in the web pack: `export_presets.cfg` keeps
  `assets/knowledge/*` out of both web presets, `tools/export.sh web` copies
  them to `build/web/knowledge/`, and `deploy.sh` serves them at
  `/b/<sha>/knowledge/` (immutable like the rest of the build; it refuses to
  deploy a build without them). `RealSnippets.ensure()` fetches the index from
  `Origin.build()` + `knowledge/` the first time a design asks, once a visit;
  the desktop reads its own files. `tools/web/knowledge_check.mjs` proves it in
  a fresh page: nothing under `knowledge/` is asked for while the app arrives,
  idles and connects Claude; then `find_techniques` fetches the index once and
  answers with credited pieces and a picture, `place_technique` lays one on a
  plate without fetching again, and `find_parts_like` fetches the looks.
  Measured 2026-10-12 on a local export in SwiftShader: nothing asked for in
  arrival, 8 s idle or connecting; the first `find_techniques` 21.9 s, fetching
  3.7 MB once, reading it and drawing five pieces in software.
- `arrival check`: `tools/web/arrival_check.mjs` times what the owner meant by
  "the rendering after Claude reports being done is EXTREMELY SLOW": from
  submit_design's answer to the last brick drawn. It plays Claude over the
  connector in a fresh page per case, for the Falcon's lowest 300 and 2,000
  parts and all 4,242. Each case runs twice: with the tab in view (`shown`),
  and with the tab out of view from before the check until 5 s after the
  answer (`hidden`), as when designing from claude.ai. `--flow=submit`
  submits onto the bare baseplate with no check first, so every brick is new.
  It times every engine frame in the page by wrapping requestAnimationFrame,
  and takes the time spent inside WebGL calls off each one. In software
  (SwiftShader) the page waits a second or more a frame on the rasteriser,
  inside those calls. It counts the instances each frame asks WebGL to draw.
  - `drawn`: the first frame in view from which every frame that draws
    into the window draws what the last one did, to within 1%. A frame that
    draws nothing shows what the last drew: the app draws only what changed
    (`IdleDraw`, 2026-10-11), and a page standing still draws nothing, which
    `settle` counts as settled too. So does a frame that drew only off
    screen (no draw, clear or blit with the canvas's own framebuffer bound):
    Render's set made ready once the window has been idle 3 s
    (`StudioRender.warm_up`) draws 8-pixel viewports alone, and read as
    frames of the model they were 0 or 1 instances after it (m145, m146).
  - `idle`: the last frame in view with over 100 ms of the engine's own work.

  It also prints the slowest own frame, long task and evaluate round trip in
  view, and how many frames ran between the answer and the tab being shown.
  It hides a tab the way `connector_flow.mjs` does: `document.hidden`, plus
  a gate on the browser's frames. A browser driven from here never hides a
  page itself, not even behind another tab (tried 2026-10-11). It reads the
  same way on a build that does not time itself, so the old build is judged
  by the same numbers. Fails when a case is not drawn within three frames of
  being in view (frames that drew; 0 when it was on the screen already as
  the tab was shown), or took more than `--budget` ms (2,000) of the engine's own
  work to get there, or the app said the model was still going up
  (`brickworksState.playing`, asked every 250 ms) after the answer, in view.
  It is judged in frames because in software a frame of a
  4,000-part model is 2 to 3 s of rasterising, which a graphics card does in
  milliseconds. Three frames because the ground is laid wider under a design
  that outgrew it, a frame after it is built. But a build animation is timed
  by the clock: 2.5 s of it was two to five frames here and 150 on a graphics
  card, so counted in frames alone it failed one run and passed the next;
  asked whether it plays, it fails every time. A call still going after 20 s
  answers with a job (`src/net/tool_jobs.gd`): the Falcon's check did at a
  load of 50, and the submit after it was refused as the app being busy. The
  check polls `job` as a session does, and the job's last answer is the
  call's. If a case's tab never answers
  the connector, the case is tried again on a fresh page, up to three pages
  in all. The test account is shared by every check on the machine, and a
  page can come up saying "Sign in to Brickworks again to connect Claude".
  A case that still never answers fails as that, not as a slow model. Leaves
  `<size>_<mode>.png`, `.frames.json` (every frame: start, length, own work,
  instances, draws, slowest WebGL call; and each instanced draw's count
  whenever they changed) and `arrival.json`.

  It caught the status line and the pointer each looking up the part under
  the pointer every frame (since the CAD shell, 1528ccc, and ab356d8). A ray
  that hits nothing marches the whole lattice: 18 to 25 ms on the desktop with
  the Falcon built, several times that in the page, twice a frame. Hidden 4,242
  was never drawn in 600 s on brickworks.diy at 91ae209, and hidden 2,000 idle
  only after 9 s. `EditVerbs.brick_at` now keeps its last answer until the ray
  or `BrickLattice.revision` changes, and answers nothing out of view
  (`Main._watch_view`).

  It caught the build animation outliving the answer (2026-10-13): every
  shown case drawn on frame 4 or 5, 1.5 to 1.9 s after submit_design
  answered, on brickworks.diy and on local exports of da0dd3d. Each frame's
  instanced draws (`changes` in `.frames.json`) showed every batch's count
  rising a step a frame for 2.5 s from the build: `BuildPlayback` raising
  `visible_instance_count`. A check from outside had put the design down as
  a draft, so the submit had nothing new to play; since a8e1aa5 it never
  does, and the submit put all of it down to go up in view. Measured, not
  read: da0dd3d with only that check line put back drew all three shown
  cases on frame 0 or 1, never going up. What a session's
  call puts down is now drawn whole as it answers (`CommandSocket.at_work`;
  see [view](view.md) `build animation`).
- `idle check`: `tools/web/idle_check.mjs` loads the app in Chromium, lets
  it settle (the model, its parts and the bin's pictures in, nothing
  moving), and counts what a page standing still costs for 15 s: the
  engine's frames, those that asked WebGL to draw, the main thread's busy
  share (CDP `TaskDuration`), and the CPU of every Chromium process by kind
  (the page; SwiftShader in the GPU process). Then a wheel notch over the
  model, the - key and the ghost of a part in hand moved over the baseplate
  must each be drawn, and the page go quiet after. The page says where the
  ghost stands (`brickworksState.ghost`), and every move of it must be a
  frame: eight small steps over the example car once aimed every time at its
  windscreen and put the part on the roof, so nothing moved and nothing was
  drawn, rightly, and the check failed live and on every build
  (2026-10-13; the ghost follows the pointer, seen step by step). Fails past one frame drawn a
  second standing still or a tenth of the engine's frames (drawn in
  software a frame of the old build took over a second, so it drew under
  one a second while drawing every frame it had). Measured 2026-10-11 on
  local exports: the build before drew 12 of 12 frames, its main thread
  106% busy and Chromium 587% of a core (the GPU process 498%); now 0 of
  904 drawn and no WebGL call, the main thread 4%. On the CAD shell it drew
  every frame again (16 of 16, Chromium 820%, the GPU process 720%): the
  bin's shimmering tiles below its fold were inside the window (see
  [parts](parts.md) gotchas); with only tiles in sight shimmering, 0 of 657
  drawn and the GPU process 1% (2026-10-12). The main thread was still about
  100% busy in the engine's own frames, which drew nothing: the status line
  and the pointer each looked up the part under the pointer every frame (see
  `arrival check`). Looked up only on change, on the preview of ce4fc09 the
  main thread is 5% busy standing still and 0 of 906 frames drawn. The
  part in hand is taken with Q, as Select is where the app rests. It waits 20 s after
  settling (`--after`) before it measures: in software the GPU process
  rasterises seconds behind the page, and straight after settling it was
  still at 160% on frames drawn before. Not the app's drawing, and in both
  builds: one of the page's workers (a `DedicatedWorker` thread of the
  renderer) runs at about a core, not yet traced. Leaves `idle.json` and
  `idle.png`.
- The desktop downloads page (`web/download.html`, `download.js`,
  `releases.json`) ships with every deploy like the rest of `web/`; what it
  does and how it is checked is in [release](release.md). The landing page
  links to it from the nav and the footer. The deploy does not check it yet:
  after a release, run `node tools/web/download_check.mjs
  --url=https://brickworks.diy/download`.
- `put the website together` (`tools/site.py OUT`): every file in `web/` (and
  `web/img/`) but working ones named `_…` and `img/manifest.json`, with
  `changelog.html` filled from `CHANGELOG.md` and `releases.json`. The deploy runs
  it into `.vercel/output/static`; run it into a scratch directory to look at the
  changelog. **Clean addresses** (2026-10-12, the owner: "pages at brickworks.diy
  shouldn't end in .html"): every top-level page but `index`, `404` and
  `authorize` is served at its bare name by a Build Output `overrides` entry
  (`/download`, `/changelog`, `/admin`), and `/<name>.html` answers 308 to it,
  query and all (`/index.html` to `/`, `/authorize.html` to `/oauth/authorize`);
  `/download/` and `/app/` lose the slash; `/challenges` (and with a slash)
  answers 308 to `/challenge`, query and all (2026-10-24, walk239's W10: it
  was a 404). **`/app` is a rewrite**, not a redirect:
  the page under `/b/<sha>/` is served at `/app`, `no-cache`, with every file it
  names made absolute by the deploy (`src="/b/<sha>/index.js"`,
  `GODOT_CONFIG.executable` and `fileSizes`), because the CSP's `base-uri 'none'`
  rules out a `<base>`. The CSP's script hash is of that served copy. **An unknown
  address answers 404 with `web/404.html`**, at any depth and inside `/b/<sha>/`;
  it used to 308 to `/`. `/parts/` and `/sets/` keep their plain-text 404s.
- `the challenge among the site's places` (2026-10-24, walk239's W10): every
  page's footer list of places ("More") starts with Challenge, `/challenge`,
  which shows the month's challenge or the next told (Coming next). The
  landing page linked neither `/challenge` nor `/challenges`. `site_check`
  asks that `/` links it there, and the three `/challenges` redirects (red
  on m166).
- `landing page` (`web/index.html`, `web/landing.js`, `web/site.css`, the
  pictures in `web/img/`): rebuilt 2026-10-20 (the owner: "complete garbage";
  before that, 2026-10-13, "overly wordy and verbose and none elegant ...
  brickworks is much more than an ai tool, its also a fully advanced expert cad
  system"). It shows rather than says: the hero is one line ("A complete CAD
  for LEGO® models", `h1.display`), one sub-line (in your browser, on a computer,
  tablet or phone; nothing to install, free), one primary action (Open Brickworks) and a quiet link to the
  desktop download, over the builder at work on the castle
  (`img/hero-*.webp`) under a window's bar with the app's address; `#features`,
  six pictures from the app of what a Studio or LDD user cannot do there, one
  line each (Will it stand?, gears at their real ratios on the orrery,
  grabbing a boom on its hinges, Studio `.io` both ways, booklets, every part
  at true size) and one sentence of the rest (building together, models on
  every device, worked constructions, 3D export, renders, what your sets can
  build; 2026-10-24, each a feature in this map), with a link to /compare;
  `#made`, a strip from the live gallery (`landing.js`: Top builds from
  `/api/share?op=list&sort=top`, asked as it nears the screen, a card put in
  only once its picture has decoded and the strip shown only once three are,
  so it can never show a dead card; `data-strip` on `<html>` says how many,
  `none` when hidden). Its cards come from `card.js` `modelCard`, which must
  give an element of the page's own document: made in a `<template>` they
  never loaded a picture, `decode()` refused all seven and the strip never
  showed (walk180, 2026-10-23). `tools/web/landing_check.mjs` (run by every
  deploy) scrolls to it at 390 and 1280, light and dark: shown with every
  card's picture drawn when the gallery has three with pictures, else
  hidden; `--out=DIR` keeps `strip_<width>_<theme>.png`);
  `#assistant` last, short, off until you turn it on. Claim only what ships:
  gear trains went on the page the day Tools, Simulate mechanism merged, not
  before. Every
  page shares `/site.css` (every text colour 4.5:1 or better on its background
  in both schemes), a skip link, a sticky bar with a `<details>` menu under 860
  px (no script: the CSP runs none inline) whose last item keeps the 16 px
  gutter at every phone width (under 390 px the mark is the cube alone, its
  name still Brickworks), and one footer: the header and
  footer are `web/_shell.html`, written into every page by `tools/site_shell.py`
  (`tests/test_site_shell.py` fails on a page that differs). Pictures are WebP at
  the widths a laptop and a phone need (the landing page's six at 400, 720 and
  full, `sizes` the tile's own width, not the screen's: a phone at twice its
  density took 310 KB of 1200s when it said 100vw), taken from the live app at
  a device ratio of two (`tools/web/app_shot.mjs --ratio=2`, or `BW_RATIO=2`
  before any flow that launches through `browser.mjs`), with `srcset`, `width`
  and `height`; all but the hero load lazily. Weigh a change to it by what the
  page fetched (`encodedBodySize`), scrolled to its foot, at 390 and 1280 px
  against the live one (2026-10-20: 206/264 KB at load/scrolled on a phone and
  146/204 on a laptop, where the page before took 228/418 and 195/234). `img/manifest.json` says where each came from and holds
  its alt text. `FAQ page` (`web/faq.html`): the two ways to bring Claude, each
  as numbered steps with what it costs (`#claude`), the questions (FAQPage
  JSON-LD, the same answers), the dimensions (a `.table`). Since 2026-10-24:
  signing in (`#sign-in`: `ui:sign in with orangecheck`, and on the desktop
  `ui:sign in with orangecheck on the desktop`, from 0.8.0), building
  together (`#together`, `ui:build together`; the desktop from 0.8.0),
  Tested (`#tested`, `lib:the Tested mark's four tests`), a tablet or a
  phone (`phone layout`, `tablet layout` in [building](building.md)), a
  booklet saved as PDF or PNG pages ([view](view.md)), and a screen reader
  or the keys alone (`#access`, `ui:accessibility`: desktop 0.8.0, never
  the browser's canvas). `privacy page` (`web/privacy.html`): what an account
  holds and what Brickworks never sees — each claim is in
  `src/account/account.gd`, `api/otp.js`, `api/mcp.js`, `src/ai/own_key.gd` and
  the CSP in `deploy.sh`; change one, change the page. `changelog page`
  (`web/changelog.html`) and `404 page` (`web/404.html`, `noindex`) use the same
  bar and foot. `robots.txt` keeps `/admin`, `/api/`, `/oauth/` and `/b/` out and
  names `sitemap.xml`, which lists `/`, `/download`, `/changelog`, `/faq` and
  `/privacy`. The mark is `web/icon.svg`, a cube with a corner cut away
  (no brick, no studs: docs/TRADEMARKS.md, Decisions); `tools/web/make_icons.mjs`
  draws the favicons, the manifest's icons, `assets/icon.png` and the
  desktop's boot splash `assets/splash.png` from it (`make_icons.mjs FILE`
  draws that one alone),
  `tools/web/make_share.mjs` the share card, and every header shows it as `.chip`
  in `site.css`. Judge it at 390, 1280 and 1920 px:
  `node tools/web/page_shot.mjs --file=web/index.html --width=1920 --full`.
  Lighthouse (performance and accessibility at least 95), on a preview:
  `CHROME_PATH=~/.cache/ms-playwright/chromium-1248/chrome-linux64/chrome npx
  lighthouse@12 <preview>/ --extra-headers='{"x-vercel-protection-bypass":"…"}'
  --chrome-flags="--headless=new --use-angle=swiftshader" --only-categories=performance,accessibility`.
- `site check` (`tools/web/site_check.mjs --url=<deployment>`): every page 200 at
  its bare name with its title, description, canonical link and an Open Graph
  card whose picture answers; every old `.html` 308 to its bare name; `/app` 200
  with its build's engine named under `/b/<sha>/`, COOP/COEP and the app's CSP, not
  cached, and the build's files immutable; unknown addresses the 404 page with a
  404; the sitemap's pages 200 and robots keeping `/admin` out; every link,
  picture, clip, poster, script and `#fragment` on every page resolving (external
  links fail only when gone, 404 or 410); and in a browser, no page logging an error or scrolling
  sideways at 390 px, with a full-page shot of each at 390 and 1280 px in `--out`,
  and `/app` booting with the address bar still `/app` and its `version.json`
  found. About four minutes on SwiftShader.
- `compare page` (`web/compare.html`, `web/compare.js`, `img/compare-*`): the
  answer to "Studio exists, LDD exists… why?" (a builder on Reddit), linked from
  the home page's features ("How it compares") and the FAQ's first question
  (`#studio`). Since 2026-10-24 (copy252) three parts, each short. Six points,
  each one claim on a real model with what Studio (or LDD, or LDCad) does.
  Then the field, row by row (`.table.wide`, site.css): Brickworks, Studio,
  Mecabricks, LeoCAD and LDCad, from docs/COMPETITIVE.md's matrix, "—" where
  none was found. Then where the others still lead, plainly: renders, prices,
  rubber bands and springs, years. Every
  claim about another tool is sourced at the foot (their own pages and forum
  threads, read 2026-10-12 and 13, versions rechecked 2026-10-24); a claim
  that cannot be sourced is cut, not softened. Studio has project tabs and an
  instruction maker, so neither is claimed as ours alone; its stability check
  exists, so the claim is what ours adds. What the desktop gets only after
  0.7.0 is said so ("desktop 0.8.0": Build together, the screen reader,
  orangecheck on the desktop). Each Brickworks claim
  and the feature that proves it:
  - in a browser, on a tablet or a phone, every tab a project, models on
    every device: `cli:web build and deploy`, [building](building.md)
    `phone layout` and `tablet layout`,
    `ui:new tab or window`, `lib:models kept with the account`,
    `ui:download page`;
  - will it stand: `lib:stability`, `lib:balance`, `ui:stress view`;
  - gears: `ui:gears put in mesh by hand`, `ui:simulate mechanism`;
  - Studio files: `ui:open a studio model` (its own parts carried),
    `ui:save as a studio model`, `ui:open an ldd model`;
  - STL, OBJ, GLB: `ui:3d model export`;
  - instructions: `ui:the booklet`, `ui:the booklet by hand`,
    `ui:the booklet page by hand`, and [view](view.md)'s `the booklet as a
    PDF and as PNG pages`;
  - the field's rows: connections `lib:occupancy lattice`,
    `lib:placing a part by its connectors`, `ui:snap onto a joint`; finding a
    part `lib:part search` (BrickLink's and Rebrickable's names and element
    numbers, names248), `ui:find a part from a photo`,
    `ui:techniques in the bin`; rendering `ui:photo-real render`; flexible
    parts `lib:flexible parts along a path`, `ui:hoses and chains by hand`;
    making parts `lib:element maker`, `lib:change a part`,
    `ui:print designer`, `lib:stickers`; files `lib:ldr read and write`,
    `ui:brickify a 3d model` and the Studio, LDD and 3D ones above; shops
    and collections `ui:parts lists for shops`, `ui:my collection`;
    building together `ui:build together`, `lib:building together`;
    sharing `ui:gallery page`, `lib:directory`,
    `lib:comments on a shared model`, `ui:shared model page and card`,
    `lib:the Tested mark kept and shown`; accessibility `ui:accessibility`;
    AI `lib:design loop`, `ui:assistant on or off`;
  - where the others lead: `ui:photo-real render`, `ui:3d model export`,
    `ui:parts lists for shops`, `lib:flexible parts along a path`,
    `ui:tour`.
  The clips are muted, looping, `preload
  ="none"` with a poster, WebM then MP4 (Playwright's Chromium has no H.264, so
  a check there plays the WebM), and `compare.js` plays each only while it is on
  screen and never for `prefers-reduced-motion`. Judge it at 390 and 1280 px
  (site check's shots: the field scrolls inside its region on a phone, its row
  names held) and with Lighthouse on the preview (performance at least
  95 on mobile): `npx lighthouse@12 <preview>/compare --form-factor=mobile ...`
  as for the landing page.
- `compare media` (`tools/web/compare_media.mjs`): retakes every picture and clip
  of `/compare` from the live app in a real, headed Chromium window on
  SwiftShader, its tabs and address bar in the picture (ffmpeg's x11grab):
  `heavy xvfb-run -a --server-args="-screen 0 1600x1000x24" node --env-file=.env
  tools/web/compare_media.mjs --out=shots/compare`, about eleven minutes, then
  `node tools/web/compare_media.mjs --encode` writes `web/img/compare-*` (crops
  in `CROPS`). Each scene reads back what it did and fails the run if it did not
  happen: the castle, kart, orrery and tree open (by `?model=`, as the home
  page's links do: typing into Open…'s list in software let the first letters
  through to the app as keys, and K left the kart cut away), Simulate
  mechanism's readout naming Mars, Play playing, Check stability saying how
  many studs inside, the booklet's tab with pages. Look at every picture before
  encoding: a menu that did not open still makes a picture.
- `the assistant, as a person uses it`: `tools/web/assistant_flow.mjs` pastes a
  key, asks for a small house and records every answer from Anthropic, with a
  screenshot at each step. With its default fake key it is free and proves the
  path: the key is taken, the request leaves the browser and reaches Anthropic,
  and the refusal reads "Anthropic refused that key…" with the form back. With
  `--key=-` (reads `BW_KEY`) it watches a real design start. With
  `--recorded` it answers Anthropic in the browser itself, from
  `tests/fixtures/sketches/lighthouse.json`, and proves Sketch first: three
  cards, the sketches asked of Sonnet 5.5 at medium, sketch 2 pressed, and the
  design asked of Opus from it; against a local export (`serve.py`) it is the
  way to see a change to the panel before a deploy. The live site was
  reported as "the assistant doesn't work at all"; it was answering — four 200s
  in ninety seconds — while showing nothing, and no check had ever pressed
  Build. On a preview set `BW_BYPASS`; it goes in the first address only, as a
  cookie for that domain, never to Anthropic. It clicks controls by name: the
  web build publishes their centres as `window.brickworksControls`
  (`main._tell_page`), after a fixed-position click landed on a paragraph and
  typed the key into the app as shortcuts. It also says where the model's own
  part of the window is ("view") and the parts list ("parts list"): at a device
  ratio of two the panels take far more of the page, and the cursor check's
  "middle of the model" was the parts bin there. `window.brickworksCursor` is
  the pointer's state (`Cursors.show_state`), for `tools/web/cursor_check.mjs`.
  A centre is published only once the control has stayed there for a
  telling (`Main._page_places`): one shown in the frame the page was told is
  not laid out yet, and the warning that the browser may clear the models is
  offered in that frame every second, so its Download my models was published
  440 px from where it is drawn and keep_flow pressed nothing, one run in two
  (2026-10-14; `page_places_probe`). So a control is in the map about a second
  after it appears, and gone from it at once, and a flow that reads it once
  right after showing a control can miss it: each waits for the controls it
  needs, as a person waits for a panel (`controlsWith(page, names, ms,
  {any})` in `tools/web/browser.mjs`, up to 10 s; fit_check, app_shot,
  booklet, cursor, freeze, idle, placeholder and progress; the cursor check
  waits for the controls panel's Done to come and to go). Still, what a flow
  clicks must not move once it is on screen: LEGO Art's brief sat over a
  description that grew from one line to three a moment after the dialog
  opened, the click landed on the text, and the brief was typed into the
  model as shortcuts. A menu reached by keys is not searched like a list:
  each letter moves to the *next* line starting with what has been typed,
  and the search starts again when two keys reach the app more than two
  seconds apart, as one slow software frame makes them. Type only a prefix
  no other line in that menu shares (E for Export), and go by the arrows
  from there. "BrickLink Studio" swung between two lines and downloaded the
  wanted list on a busy machine.
- **A newer build is live** (2026-10-13): `ui:newer build banner`
  (`src/ui/update_offer.gd`), `lib:newer build` (`src/net/newer_build.gd`)
  and the page's half in `src/boot/shell.html` ("A newer build"). `deploy.sh`
  writes `/version.json` at the root of every deployment, served `no-store`,
  beside the immutable `/b/<sha>/version.json`. The page knows its own build
  from its address (`/b/<sha>/index`; served from a folder, the version.json
  beside the build, read as the page starts) and asks `/version.json` on
  focus, on being shown again, and every 4 minutes while in view, never twice
  in 20 s. Once it names another build: `window.brickworksNewer()` says which,
  the app shows "Brickworks has been updated" with **Reload** in the strip
  above the model (control `update_reload`), and the page holds back every
  write and delete outside the tab's own `user://sessions/<id>/`
  (`holdBack`, listed by `window.brickworksHeld()`); a file changed before
  the newer build was seen is still stored. The app refuses a save to the
  shared models with `NewerBuild.REFUSAL` (`ModelStore._write`) rather than
  saying "saved" for a file never stored, and Claude is told once over the
  connector (`CommandSocket.NEWER_WORDS`). Reload writes the working model at
  once (`ModelStore.write_now`), waits until the browser has stored it, then
  reloads into the same session. The sign-in in localStorage is not held
  back (a renewed session not kept would sign every tab out).
  **`update probe`** (`src/dev/update_probe.gd`, headless): the page's
  word played with `NewerBuild.pretend`; banner, the refusal, the working
  model written at once, Reload writing before it reloads, Claude told once.
  **`reload browser flow`** (`tools/web/reload_flow.mjs`, real Chromium,
  `.env` sourced): `node tools/web/relay_server.mjs 8790 --static=build/web`
  then `node tools/web/reload_flow.mjs --url=http://127.0.0.1:8790/app
  --out=shots/reload`. The newer build is simulated by handing the browser
  another commit for `/version.json`; with `--next-deploy` against an alias
  nothing is simulated and it waits for the next deploy there (`vercel alias
  set <url> <alias>`). A model renamed and changed, the newer build, a focus:
  the banner within seconds; then Save and a deleted part, with another page
  of the site watching IndexedDB every 500 ms: the tab's own autosave lands
  and nothing outside its session is added, changed or deleted up to the
  reload; another part deleted and Reload pressed at once: the page reloads
  asking nothing, in the same session, with the model part for part under its
  name, and no banner. Against the build before (a7a0099, tabs merged) 5
  checks fail: no banner, no `brickworksNewer`, and Save stored
  `models/Reload Flow House.ldr`, `command_costs.json` and two folders after
  the newer build was seen. Two deploys apart, for real (2026-10-13): a
  preview of ffeb8db aliased to a test address, the flow started there with
  `--next-deploy`, a preview of 9f72c2d (`--no-export`) aliased over it; all
  20 checks passed, the banner within 6 s of the focus, and the page came back
  on 9f72c2d. The alias answered the old `/version.json` for a few seconds
  after `vercel alias set` (Vercel's edge, `age:` on a `no-store` file), which
  is why the flow polls it rather than reading it once.
  **`list changed check`** (`tools/web/list_changed_check.mjs`, `node
  tools/web/relay_server.mjs 8790` and `.env`): a tab played from the script
  says hello with one build's tools and again with a newer build's, both ways
  in (`?t=` and OAuth, one throwaway account). initialize says
  `listChanged: true` and hands out a session id on both; after the newer
  hello the next call is `text/event-stream` with
  `notifications/tools/list_changed` ahead of the answer, once; a client
  sending `Accept: application/json` alone is told in words at the end of the
  call's answer, once. Before: 9 of its checks fail (`listChanged: false`,
  JSON every time, no session id on `?t=`). It passes against a preview too
  (ffeb8db, 2026-10-13): Vercel's function sends the event stream as one body
  (`response.end`), and the root `/version.json` there is `no-store`. Needs `relay_lists`
  (`supabase/relay.sql`, applied to the live project 2026-10-13). The
  desktop's port is checked by `mcp_probe` (`_list_changes`: a session id
  carrying a hash of its list, an older id told as a stream, GET with
  `Accept: text/event-stream` is 405), and `tools/brickworks_mcp.py` by
  `tests/test_mcp_list_changed.py` (the real bridge and a stand-in app on a
  port of its own, restarted with a newer list; the bridge's copy of the list
  goes to a file of the test's own via `BRICKWORKS_MCP_CACHE`). The other
  relay checks play a client that reads an event-stream answer as Claude
  does (`connector_probe._claude`, `oauth_probe.call`): a probe whose tab says
  hello with a list of its own is told the tools changed, and read only JSON.

## How to reach it

```sh
tools/deploy.sh                 # a preview URL
tools/deploy.sh --prod          # the one brickworks.diy points at
tools/deploy.sh --no-export     # deploy what is already in build/web
node tools/web/check.mjs --url=https://brickworks.diy/app --out=shots/deploy.png
VERCEL_BYPASS=… node tools/web/site_check.mjs --url=<deployment> --out=shots/site
python3 tools/site.py /tmp/site && (cd /tmp/site && python3 -m http.server 8098)   # the pages, as files
python3 tools/web/serve.py build/web 8099    # locally, with the isolation headers
# ...and standing in for the deployment on a slow network: /api/account names
# its own /parts/, served from the directory after a delay (see parts.md previews)
python3 tools/web/serve.py build/web 8761 --parts assets/generated/parts --delay 2500
# the export and the deployment's functions together, for the connector
set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 --static=build/web
node tools/web/freeze_check.mjs --dir=build/web --out=shots/freeze   # a big design, timed
node tools/web/idle_check.mjs --dir=build/web --out=shots/idle       # nothing drawn standing still
node tools/web/idle_check.mjs --url=http://127.0.0.1:8761/index.html --floor=none   # ...on no floor, its shadow showing
```

## How to check it

Static: `pyright` covers `tools/web/serve.py`. Nothing static covers the endpoints.

Static: `for f in api/*.js; do node --check $f; done`.

Runtime — safe to run against production:

```sh
node tools/web/knowledge_check.mjs --dir=build/web   # the real-set index stays out of arrival and comes when asked (.env sourced)
curl -s https://brickworks.diy/api/account | python3 -m json.tool
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://brickworks.diy/api/account
curl -s -w ' %{http_code}\n' -X POST 'https://brickworks.diy/api/mcp?t=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&i=checking1&op=hello' \
  -H 'content-type: application/json' -d '{"tools":[]}'
```

Proves it when: the GET is `200` with `enabled: true`, a `url` and publishable
`key`, `assistant: "own_key"` and a `parts_url` (the Supabase storage bucket);
the POST is `405`; and a hello with no sign-in is `401`. The deployment before
2026-10-11's accounts answered `enabled: false` with no `url`, and took any
hello.

A model shared by link, every endpoint and every refusal, against the real
functions, database and bucket (three throwaway accounts, deleted at the end
with their rows; every model it publishes is taken down or swept first, so no
file is left; `CRON_SECRET` from `.env` for the sweep; about 40 s locally):

```sh
set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 &
node tools/web/share_probe.mjs --url=http://127.0.0.1:8790 --master
BW_BYPASS=$VERCEL_BYPASS node tools/web/share_probe.mjs --url=<deployment> --master
```

The gallery's part of it (since 2026-10-13, two more throwaway accounts;
`--master` signs in as `MASTER_EMAIL` the way the tests sign in, to take a
model out; without it that part is skipped and said to be): listed, a model
is ahead of every card listed before it in `?op=list`, the page newest first,
with its name, author, count, link and picture, no owner, 24 a page (another
flow's test model listed after it may be ahead: the release runs two flows at
once against one database, and a check that wanted it first held m115 and
m122; `tools/web/gallery_order.mjs` judges where it stands); one shared unticked is not there; the list `no-cache`; a page
outside 1 to 400 is 400; `listed: "yes"` 400; a name that is markup listed
later is ahead of it, comes back from the list as text and is escaped on its
page; a copy published with `remixed_from` says it on its page with a link and
in the viewer's JSON, and still knows after a republish that does not say;
`remixed_from` that is not an id 400, one that never was stored as none;
unticked and republished it leaves the list and keeps its link; ticked again
it is back; unpublished it leaves, and the remix's page stops naming it;
another account asking to take it out 404, signed out 401; the owner's admin
answer lists it with its account, takes it out (200), it leaves the list, its
link works, its owner listing it again 409 and publishing it unlisted 200, an
unknown or malformed id 404 or 400; six listings an hour then 429, a listed
model republished still listed, and publishing unlisted unaffected; with the
publishable key, `listed`, `listed_at` and `remixed_from` refused (readable
before `no_client_access_models.sql`), `barred` not, the listing log closed
and `may_list` not callable. 120 checks with
`--master`, about a minute locally.

The directory's part of it (since 2026-10-13, one more throwaway account):
the gallery's kinds the app's, in its order (read from `model_kinds.gd`); a
description with control characters out and blank lines one, tags in lower
case once each, the too short left out, a kind and a licence; 2 steps,
Brickworks's own, not Technic, counted from the file; refusals for a
description over 1000, nine tags, tags that are not words, a kind or a
licence that is not one (400), a small picture that is not a WebP (415) or
over 64 KB (413); a file by another tool with steps is its builder's own; three
gears (one by its old number) and a brick are Technic; a card with kind,
tags, licence, steps and counts and no owner or description, its small
picture at a versioned address and served as published; fourteen questions
(a word of the description, a word's start in capitals, two words of the
name, a tag's plural, the credit, a tag, two kinds, two sizes, instructions,
Technic, two filters at once, a word nothing has) each finding what it should
and nothing it should not; six malformed questions 400, and punctuation and
markup asking nothing of the query's syntax; a view counted for a person's
first look and another person's, not for the same person again, a crawler,
a headless browser, a link preview, curl, another site's page or no Fetch
Metadata, an unknown link or a bad id (400); most viewed and most remixed in
order; a CC BY version of a CC BY-SA model 422 and a CC BY-SA one listed; a
listed version of an all-rights-reserved model 422, by link allowed; the
page with the description escaped and its lines, tags and kind as links,
the licence with whom to credit, 2 steps and its counts, the remix as a
card, the site's stylesheet, header and footer with the notice, a canonical
link and its description in the card, its policy; the remix's page naming
it and its line; republished saying nothing, all of it kept; unlisted, the
remix's page saying "a model shared by link" and the viewer's JSON naming
nothing; republished without a small picture, gone from the page and its
bucket, and that bucket not public; emptied, emptied, the licence kept; the
owner's list with what each says; with the publishable key, the new columns
readable, `search` not, `model_stats` and `model_views` closed, and the
three functions not callable. 201 checks with `--master`, about two minutes
locally (2026-10-13).

People's part of it (since 2026-10-13, one more throwaway account): who-am-I
signed out 401, a new account with no profile and no lists; eight refusals
of a profile (handles of two letters, a symbol, a trailing hyphen, two
hyphens together, 25 letters; one kept for the site 409; no name; about-you
over 300), signed out 401; made with its handle lower-cased and its name and
about-you cleaned; somebody else taking it 409; the profile listing only the
listed, credited model, never one shared without a name or by link only, and
never the account; `/u/<handle>` with the name escaped, that card alone, a
canonical link and the site's header; an unknown handle 404; the credited
model's page "Shared by" a link to it and the nameless one's not; a card's
`by`; likes (signed out 401, `on: "yes"` 400, an unknown link 404, 1, again
still 1, another account 2, unliked 1, the page "1 like", most liked in
order, marks); a model shared by link kept in favourites, in nobody else's,
signed out 401; a private list (made, two models in it, somebody else
changing it 404, asking for it 404, no page) seen whole by its owner, made
public showing anybody only the listed model, its page escaped with that card
only, marks naming it, somebody else deleting it 404, its owner deleting it
and its page gone; the five tables closed to the publishable key,
`profile_page` not callable, and schema.sql's `profiles` as closed as
before. 254 checks with `--master`, about two minutes locally.

The pages and actions in a real browser, on a deployment (two throwaway
accounts, deleted at the end with everything of theirs; one sign-in code sent
to a Resend test address that delivers nowhere):

```sh
BW_BYPASS=$VERCEL_BYPASS node tools/web/people_flow.mjs --url=<deployment> --out=shots/people
```

Proves it when it ends "people can sign in from a model, like it, keep it,
collect it and be found by name": see the steps in its header — a signed-out
visitor's Like opening the dialog (`1_sign_in_dialog.png`), the code minted
on the test side typed in, the like going through with the count, Favourite,
a collection made with the house in it (`2_model_marked-laptop.png`);
`/profile` with no profile yet offering two fields on its Saved tab, the
house in favourites, a name and handle making the profile drawn at once,
Edit profile's words shown with no reload, the collection made public with
its page (`3_profile-laptop.png`); `/settings` with the address and Claude,
and the account deleted there; `/c/<id>` and `/u/<owner>` signed out
(`4_collection-laptop.png`, `5_profile_public-laptop.png`) and `/u/<visitor>`
with the public list; and the model page (with the collection panel open),
`/profile`, `/c/<id>` and `/u/<owner>` at 390 px with nothing sideways
(`6_*-phone.png`); no console error or refused request.

Moderation's part of it (since 2026-10-13, two more throwaway accounts;
`--master` for the owner's half): six names refused (abuse spelt round, the
LEGO Group's mark, a licensed name run together, as a tag, a credit with
abuse, a description with a slur) and a description saying what inspired it
allowed; a handle with the mark 409, a profile's licensed name 400, a
collection's abusive name 400; reports signed out and signed in, of a model,
a profile and a collection, five refusals, six an hour from one visitor then
429; the owner's queue with what was said, the contact and the account and
never the reporter, a report let go, anybody else letting one go 404; a model
taken out with its file barred and its reports settled, the same file at a
new link 409, by another account with its line endings changed 409, by link
only allowed, a different file allowed; the account taken out by one of its
models — every model of it out, its profile and public list 404, anything new
listed 409, by link allowed, listed as taken out with why, anybody else
taking one out 404, let back in and listing again; twenty collections an hour
then 429; `/sitemap.xml` with the site's pages and every listed model and none
taken out; and the four tables and three functions closed to the publishable
key. On a deployment, also the list's and a model page's second asking
answered by the CDN (`x-vercel-cache` HIT or STALE). It removes what it made
that does not go with its accounts (barred fingerprints, reports by handle,
its accounts' counts). 304 checks with `--master`, about two minutes locally.

Test models' part of it (since 2026-10-17, `supabase/test_models.sql`): every
model it publishes is a test account's, so every list it checks (the gallery,
a profile, a collection, the remix and search questions) is asked with
`tests=1`, and beside them what a visitor gets: the row marked `test` (read
with the secret key); the visitor's list, past the CDN and as the CDN gives
it (the address `/gallery` asks), without the probe's listed models, twice;
the `tests=1` answer `private, no-store` and, on a deployment, answered by
the function a second time, never the CDN; `tests=maybe` 400; a profile's
JSON and page without `tests=1` showing 0 models; a public collection's JSON
and page without it showing none; the sitemap with none of the probe's
models or profiles; `test` closed to the publishable key. 288 checks
locally and 291 on a deployment, without `--master`. On preview
brickworks-k5c2nla0r (2026-10-17) a watcher polling the public list every
5 s through the run saw up to 15 test models listed and none shown to a
visitor in 31 polls, nor in the sitemap.

Reporting and acting on it, in a real browser on a deployment (one
throwaway account; `MASTER_EMAIL` signed in as the tests are):

```sh
BW_BYPASS=$VERCEL_BYPASS node tools/web/moderation_flow.mjs --url=<deployment> --out=shots/moderation
```

Proves it when it ends "a model can be reported, asked to be taken down, and
taken out with its account": a signed-out visitor's Report it at 1280 and 390
(`1_report-*.png`), sent with thanks; `/takedown` at both widths, its form sent
(`2_takedown-*.png`); `/admin` with the three reports, what was said and the
account (`3_admin_queue.png`); Take out — off the queue, out of the gallery;
the second model reported and Take out the account — listed as out, its
other model out, its profile 404, anything new 409 (`4_admin_barred.png`);
Let back in; no console error or refused request anywhere.

The ground rules (2026-10-18), against a local server standing in for
`supabase/trust.sql` until it is applied (`--trust-stand-in`, which answers
its five functions in memory and sends the rest to the real database), or a
deployment once it is (four and one throwaway accounts, deleted at the end;
the local server needs `build/web` from `tools/export.sh web`):

```sh
set -a; . ./.env; set +a
node tools/web/relay_server.mjs 8742 --static=build/web --trust-stand-in &
BW_STAND_IN=http://127.0.0.1:8742 node tools/web/age_flow.mjs --url=http://127.0.0.1:8742 --out=shots/age
BW_STAND_IN=http://127.0.0.1:8742 node tools/web/digest_flow.mjs --url=http://127.0.0.1:8742 --out=shots/digest
```

`trust.sql` is applied now (m81): run `age_flow` against a relay without
`--trust-stand-in` and without `BW_STAND_IN`. With the stand-in its ages
never reach the database's own triggers, which refuse the profile, the
public list and the listing (three 502s, 2026-10-18); without it, 42 checks
all ok the same evening.

The theme, with no network (the checkout's pages served as design_flow
serves them, every API call answered by the stand-in):

```sh
heavy node tools/web/theme_flow.mjs --out=shots/theme                 # this checkout
node tools/web/theme_flow.mjs --url=<preview>                         # a deployment, signed out
node tools/web/theme_flow.mjs --url=<preview> --account --only=home   # and its account (theme.sql applied; .env)
```

Every kind of page (the 16 static ones, a model's, a person's, a
collection's) at 390 and 1280, the computer set to light: Dark, System and
Light pressed in the footer (Menu at 390; another tab for /admin and
/oauth/authorize) each change the page with no reload (background,
`data-theme`, the pressed button, the bar's colour), System follows the
computer when it changes, a reload and a new tab keep the choice, and every
frame of each load (read in `requestAnimationFrame`) is the chosen theme's,
never the other's. A control page whose theme comes after load must be
caught as a flash. Locally it also calls `api/account.js ?op=theme` in-process
against a stand-in database before and after the column, and, signed in,
chooses Dark in Settings, then opens a fresh browser profile that must follow
the account on its first page; an account with none takes the browser's
Light. With `--account` the same on the deployment with a throwaway account,
deleted after, and its `profiles` row checked gone. 2026-10-22: 0 failures
locally (numbers in the unit's report).

The design system, with no network and no account (pages from the
checkout, `/m/<id>`, `/u/<handle>`, `/c/<id>` and the embed made by its
`api/` in-process, every API call answered by `tools/web/design_stand_in.mjs`):

```sh
heavy node tools/web/design_flow.mjs --out=shots/design              # this checkout
heavy node tools/web/design_flow.mjs --root=<an old export> --out=…   # an older site, to see it fail
node tools/web/design_flow.mjs --url=<preview>                        # a deployment's pages, the API stood in
```

```

It visits home, gallery (its filters opened at 390), a model nobody has
remixed (`/m/DesignFox1`, local only), the kit page `/_kit` with its more
menu open (local only), a model's page (signed
out: More opened, and its Report it opens the report dialog; signed in:
Save's lists, the comment form, and I built it's photo form with its file picker), the
stand-in's own model signed in with Enter this month's challenge and its
dialog (here only: a deployment has none of the stand-in's models), an older
version, the embed card, a person, a collection, `/challenge` (an open one,
with Vote for it, Your vote and You voted in this group), the feed, Account (signed
out: Sign in and its code step; signed in: the age question for an account
not asked yet), admin, authorize, compare, download, faq, changelog, terms,
guidelines, privacy, takedown and the 404 page, at 390 and 1280, light and
dark, signed out and in. It fails a visible control the browser drew its
own way (a `menulist` dropdown, a checkbox in its own colour, 13.33 px type),
controls of one kind on a page that differ (fields in type, height,
corners, border or fill; buttons of one size), a page wider than 390
with anything open, a count of none shown ("0 remixes", "following 0"),
a header whose last item is closer than the page's 16 px gutter to the
screen's right edge (on a phone at 320, 360 and 390 px, the page resized
and put back), and, once each however many pages have it, any rule in a page's
stylesheets, `<style>` or `style=""` with a font size, corner or colour off
the token scale (`style: <sheet> | <selector> | <declaration>`).
2026-10-22 (U2): 236 pages and dialogs, 2,418 controls, 236 passed, 0
failed, and `ok style: every font size, corner and colour on the token
scale`; the same flow on theme01's web/ and api/ (`--root=`) names 178
rules off the scale and "0 remixes" on `/m/DesignFox1` in all 8 states. It proves it when it ends `design flow: N pages and
dialogs, M controls; P checks passed, 0 failed` (2026-10-19: 188, 1,264,
188, 0; with the challenge's page and dialog and /admin's date dropdowns,
204, 1,464, 204, 0). On the site before the age fix (an export of `c98af5bd^`'s web/
and api/, given as `--root=`) it fails the age question by name:
`select#age-month … the browser's own dropdown (appearance auto)`, its
13.33 px type, and the year box differing from it in type, corners, fill
and height. Pictures of every state in --out.

The model page (docs/SOCIAL.md U4), with no network: the stand-in's
watchtower (More by Robin Castell, 3 cards; no Similar, 2 found; a strip
of 3 pictures), its remix at dusk (Similar, 3; no More by; no strip) and
Sam's bakery, shared by link, that nobody has commented on, built or
remixed (More in the gallery; signed in it is Sam's own: Add a picture),
at 390 and 1280, light and dark, signed out and in. It fails on the
picture, name, designer and action bar not all on a phone's first screen,
the column not staying beside the picture on a laptop, the bar's six
names not Like, Save, Share, Comment, I built it, More, a count not in
its label or a count of none (in the bar, the facts, the tabs or any
words on the page), Share not copying the link with "Link copied" (or,
given a share sheet, not using it), Save not asking to sign in or not
opening Favourites first and ticked, More without the embed code, Report
it (its owner: How your models are doing) and Takedown requests, a row of
fewer than three, the last row without a model, the tabs not About,
Comments, Builds, Remixes (Versions) with their counts, a tab not
bringing its part under the tabs or the tabs not staying under the
header, the strip not leading with the published picture or a photo
chosen not shown whole in its place, the owner without Add a picture or
it not opening the form, an empty part in more than one line or without
its way in, or the old paragraph. Pictures of each page whole, its first
screen, Save, More, a photo chosen and the tabs stuck. On a deployment
(`--url`) its comments are asked of it as a visitor, not of the stand-in;
where comments are not open the Builds tab is the one chosen. 2026-10-22:
556 passed, 0 failed here; 148 passed, 0 failed with `--url=` a local
`relay_server.mjs` on the live database (the gallery's first model, which
ends on More in the gallery).

```sh
heavy node tools/web/model_page_flow.mjs --out=shots/model_page      # this checkout
node tools/web/model_page_flow.mjs --url=<preview>                   # a deployment's first gallery model
```

The one model card, server against browser, with no network (local
only: preview_checks.sh says why):

```sh
heavy node tools/web/card_check.mjs              # this checkout
```

It makes `/c/<id>` with the checkout's `api/people.js` (the stand-in's
collection), parses its cards in Chromium, and compares each with the card
the browser's `/card.js` draws from the same handler's `?op=collection`
JSON; then four sample cards (owned, won, moves and motions, Tested, no
picture, markup and quotes in a name, a designer's earned card) by the
module the server imports (`api/_card.js`) and by `/card.js`. Since
2026-10-26 also the card's shape: a like that is a button over the
picture, builds and comments in `.by`'s `small.acts`, a like that is a
count there too, no card whose numbers are a button alone; `quietMarks`
at 10, 9 and 8 of 10 cards and at three; the server's `/c/` page's
`data-quiet` against the browser's for the same cards; and five cards
put on a page at once, and five two frames after they were made, each
naming theirs on `<body>`. It proves it when it ends
`card check: 15 cards compared, 0 failed` (2026-10-26).

`age_flow` proves it when it ends "the age question is asked neutrally, and
what it answers holds on the site, in the app and on the server": every
page's footer links `/terms` and `/guidelines`; each topic on
`/guidelines`; the operator's and the agent's lines marked; the
counter-notice form; nothing sideways at 390 and 1280; on `/profile`, "When
were you born?" with no word of 13 before the answer; under 13, what that
means said after, the profile form off, and the server refusing a profile, a
public collection, a listing and a credit (422) while a private list and a
link go, and a second answer changing nothing; 13 or over, a profile, a
public list and a credited listing; in the app, the sign-in screen asking it
(only its controls pressable), under 13 its words and Start building, Share
with List it and Show who made it off and "Publishing means you agree to
the guidelines" opening `/guidelines`; 13 or over, let straight in with the
box to tick. `digest_flow` ends "a report reaches the owner as one email an
hour, and a test's is only ever a dry run": a report from a model's page
makes a dry digest at once, recorded with its subject, its link to
`/admin#report-<id>` and the note escaped; a second that hour makes none;
the knock finds nothing real to send; the owner's admin page at that link
shows the row, marked and in view (`1_digest_email.png`,
`2_admin_at_the_link.png`). Never knock a real deployment from a test: it
would send the owner that hour's real reports.

The SQL itself, every trigger and function, in a rolled-back transaction
(prints each refusal and permission; nothing kept):

```sh
PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
  node tools/apply_sql.mjs supabase/trust.sql --dry --try=tools/trust_trial.sql --table=profiles
```

Comments (2026-10-18). The SQL first, with trust.sql, which it needs and
the project does not have yet, in one rolled-back transaction:

```sh
cat supabase/trust.sql supabase/comments.sql > /tmp/trust_comments.sql
PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
  node tools/apply_sql.mjs /tmp/trust_comments.sql --dry --try=tools/comments_trial.sql --table=model_comments
```

It proves it when every line says what its label says: refused `sign_in`,
`under_13`, `ask_first`, `barred`, `closed` (a model of an account under
13), `no_model`, `no_step`, `no_version`, `body` (space only, 1,001
characters); the trigger refusing under 13, barred, a control character and
a closed model when written directly; 8 allowed and 2 refused for the limit;
off by somebody else `not_owner`, off and on by the owner; the owner's
hide (a visitor sees one fewer, the owner and the author all); edit and
remove by the author only; a report naming its model and comment, its
stream the test's, its digest with `comment` and `said`; the admin's
removal (`removed_by` admin); `mail_choice` false until chosen, then one dry
digest that day and none after; no grant on the four tables, `anon` and
`authenticated` unable to execute, the service role able; "rolled back,
nothing kept".

Then the code, in real browsers, against a local server holding
comments.sql (`--hold=model_comments`) and standing in for trust.sql
(needs `build/web`; `--site` leaves the app out):

```sh
node tools/web/relay_server.mjs 9040 --static=build/web --hold=model_comments --trust-stand-in &
BW_STAND_IN=http://127.0.0.1:9040 node tools/web/comments_flow.mjs --url=http://127.0.0.1:9040 --out=shots/comments
```

`comments_flow` proves it when it ends "comments: who may write, where each
was said, the owner's say, reports, and the step player": a comment on the
model and one on step 4 picked from the page's step list, each saying where;
the owner's email a dry run once that day; version 1's step 2 on step 2 of
version 2, its step 5 on none; refusals for 1,001 characters, a word, a
step; a visitor reading with "Sign in to add a comment…" and a 401; under
13 with its words and a 422; the owner's hide, off (409 for the builder)
and on; Report it on a comment, on the admin page with its words, Remove the
comment, gone from the page and kept; and the app at 390 x 844: the viewer's
count, step 4's in the step player, its comments tapped, one added there
(the count up, on the page "on step 4 of version 2"), a visitor and an
account under 13 reading with their reasons. Pictures `1_` to `11_` in
`--out`. On a deployment (`BW_BYPASS=$VERCEL_BYPASS`, `--url=<preview>`)
the owner's dry run is read back as the project kept it: the flow hears
the API's answer to each comment the page posts (`told: {state: "dry",
id}`) and asks `comment_digest_kept` for it with the secret key, since no
key reads comment_digests itself. Before that it read only the relay's
held table, and on m81's preview said `a dry run (): "undefined"` while the
server had told the owner (43 checks, all ok, on m81's preview,
2026-10-18). 44 checks, all ok, against the local relay on 2026-10-18 (a run
takes about 4 minutes, the export first ~3). The stand-in keeps what it
holds for the life of the relay, so a second run sees the first's comments
on the admin page: the flow scopes its admin checks to its own model.
`share_view_probe` checks the same in the app with no network (159 checks
with comments, 2026-10-18).

Follows and the feed (2026-10-18). The SQL first, after the live files
(trust, tested, comments, builds and versions are applied), in one
rolled-back transaction:

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/follows.sql \
  --again=supabase/challenges.sql --dry --try=tools/follows_try.sql --table=follows
```

(`--again`: challenges.sql replaces follows.sql's `feed_rows`, so it goes
again after it; alone, apply_sql refuses follows.sql while the live one is
challenges.sql's.)

It proves it when every line says what its label says: Bob follows Ada
(1 follower, again still 1); refused `yourself`, `under_13`, `ask_first`,
`sign_in`, `nobody` (a handle nobody has, an account with no profile); the
trigger refusing under 13, never asked and no profile when written
directly; counts to a visitor with `trouble` `sign_in`, `you_follow` and
`mine` to each; whom Bob follows `[]` until he shows it, then Ada; Bob's
feed `version`, `model` (not the model by link only, nor the one without
her name); Ed's (not a test account) empty of a test account's models;
then remix, photo (Ed's mill, followed), photo (his barn, `yours`),
comment, version, model, newest first, the remix once; two at a time
`more`; before 25 minutes ago comment, version, model; the count 6 never
opened, 6 after opening (one transaction), 3 since 25 minutes ago, 0 for
nobody; the 61st follow `limit`, letting go not counted; `mail_kinds` all
false, two refusals, photos and remixes with `mail_choice` unchanged; the
email `photo, photo, remix` with no comments, kept `sending` with `feed`
3, finished dry, none again that day; the next day comments on, the
comment and only the photo since; Ada taken out: no state, none of her
rows, Bob following 0; no grant to any key, row security on, only the
service role executing; and how long a feed takes (3 to 5 ms on
2026-10-18); "rolled back, nothing kept".

Then the code, in real browsers. follows.sql is applied (rel-m82), so the
way a preview runs it is a local server with nothing held, every table the
live project's, or the preview itself; the flow reads the day's email back
through `comment_digest_kept` with the secret key, from the id the API
answered the comment with (no key reads `comment_digests`), and never
knocks. Needs `build/web`; `--site` leaves the app out:

```sh
node --env-file=.env tools/web/relay_server.mjs 9250 --static=build/web &
BW_BYPASS=$VERCEL_BYPASS node tools/web/follows_flow.mjs --url=http://127.0.0.1:9250 --out=shots/follows   # .env sourced
BW_BYPASS=$VERCEL_BYPASS node tools/web/follows_flow.mjs --url=<preview> --out=shots/follows
```

Or against a local server holding follows.sql in memory (`--hold=follows`,
`tools/web/follows_stand_in.mjs`) with comments.sql's functions
(`model_comments`, whose day's email asks it for the feed), the photos'
table and buckets, and trust.sql stood in: the flow sees `/__held/follows`
answer, reads the held digests, and knocks once (the stand-ins claim
nothing real):

```sh
node --env-file=.env tools/web/relay_server.mjs 9251 --static=build/web \
  --hold=follows,model_comments,build_photos,report_photos --trust-stand-in &
node --env-file=.env tools/web/follows_flow.mjs --url=http://127.0.0.1:9251 --out=shots/follows
```

Since 2026-10-22 the header's Account is the avatar (`the account
menu`) and, once `supabase/notifications.sql` is applied, the photo and
the comment on Bob's barn are his Notifications, not his feed: the flow
reads which from `?op=feed_count` (`notifications` a number) and opens
the avatar's menu at Notifications or Your feed accordingly. Passed both
ways, 2026-10-22, `--site`: through a relay with nothing held, and with
`--hold=notifications` (`tools/web/notifications_stand_in.mjs`).

`follows_flow` proves it when it ends "follows: a follow, the feed, the
count on Account, under 13, and counts not lists": two profiles, Bob's
barn, his email choices read back by `/profile`; Follow on Ada's profile
becoming Following with "1 follower" (`1_follow.png`), a visitor's answer
and her page naming nobody, himself 409; her castle and its version 2 in
Bob's `/feed`, newest first, each linking to `/m/<id>` and `/m/<id>/v/2`
(`2_feed.png`), a row opened; Follow beside "Shared by" (Following for Bob,
Follow for a visitor, which opens the sign-in dialog, `3_model_follow.png`);
her photo and comment on his barn counted 2: the header's Account "2" to
`/feed` (`4_account_count.png`), Menu's at 390 px with nothing sideways
(`5_account_count-phone.png`), the app's "Account · 2" at 390 px and 1280 px
with its panel's line and Open your feed (`9_app_account-phone.png`,
`10_app_account_panel.png`); opened from Account, the two marked New with
their links to `#photo-<id>` and `#comment-<id>`, the count gone on the
page, from the API, back in the gallery and in the app (`6_feed_opened.png`,
`11_app_account_panel.png`); his day's email a dry run with the comment and
3 from the feed (its subject), each with its link, and, held, no second
from the knock; Cy under
13 told why beside Follow and refused 422 (`7_under_13.png`); his profile
listing Ada only once he ticks Show (`8_profile_choices.png`), hers still
only counting; letting her go; and Older, strictly before a row to the
microsecond, a time that is not one 400. 52 checks, all ok, on the live
project through a relay with nothing held and `BW_BYPASS` set, and 53
(the knock) against the held relay, 2026-10-18, about 4 minutes each with
the app.

Follow, then the feed at once (web295, 2026-10-26): having let Ada go, Bob
presses Follow on her profile and at once Your feed in his avatar's menu,
the follow's request held 1.5 s by the flow as a slow phone's is. The feed
must wait for it (web/follow.js `followsSent`: a follow not yet answered
is kept in sessionStorage, sent again by the next page, and waited on by
the feed, a Follow button, the avatar's count and /profile's list) and
show her castle and its version 2, and the server must have the follow
("the feed opened N ms after Follow, the follow held: version, model",
"...and the server has it: following true, 1 follower"). Before the fix
the page left dropped the request: "nothing", "following false".

Notifications apart from the feed (2026-10-22, docs/SOCIAL.md U7). The
SQL first, after the live files (follows and challenges are applied), in
one rolled-back transaction:

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/notifications.sql \
  --dry --try=tools/notifications_try.sql --table=notification_marks
```

It proves it when every line says what its label says: Ada's
notifications newest first `likes` (10, today), `result` twice (the mill
not won, the tower won with 5), `remix` (on the mill), `photo`, `comment`,
`likes` (3, yesterday), not her own like or comment nor the hidden one;
today's ten likes one row saying 10, no like naming who; the two models'
pictures; her feed Bob's cart `model` and `challenge`, not his photo of
her tower; never opened `{"feed":2,"notifications":7}` beside the old
`feed_count` 5, null for nobody; opened, seen before null, then
notifications 0 and feed 2; opened 25 minutes ago, 4; read: the tower
`{read: true}`, Bob of her tower and a model nobody has `nobody`, nobody
`sign_in`; the tower read, all read never; Mark all read, read_at set,
reads `{}`, count 0; Ed's marks his feed's until the new feed is opened,
then still his old ones while his feed is seen now; `feed_of` as before
(remix, photo, comment, model, challenge); no execute for anon or
authenticated, the service role executing and not reading the tables;
her marks and reads gone with her account; "rolled back, nothing kept".

Then the code, in real browsers, against the live project through a local
relay (nothing held: the API reads the feed of before), and holding the
file's functions (`--hold=notifications`: the marks in memory, the rows
from the project's `feed_rows` and `model_likes`, as the SQL reads them;
not a challenge's end):

```sh
node --env-file=.env tools/web/relay_server.mjs 8820 &
node --env-file=.env tools/web/relay_server.mjs 8821 --hold=notifications &
node --env-file=.env tools/web/notifications_flow.mjs --url=http://127.0.0.1:8820 --out=shots/notifications
node --env-file=.env tools/web/notifications_flow.mjs --url=http://127.0.0.1:8821 --out=shots/notifications-held
BW_BYPASS=$VERCEL_BYPASS node tools/web/notifications_flow.mjs --url=<preview> --out=shots/notifications
```

`notifications_flow` proves it when it ends "notifications: the avatar,
the menu, the list, read and seen, the feed apart: ok": Ada's avatar where
Sign in was, no count, its menu her name and handle and the five places
and Sign out (`1_account_menu-1280-dark.png`); Bob's comment and photo and
ten likes (each liker with a profile); her count 3 (2 before the file, the
old feed's), on the avatar labelled "Your account, 3 new" and on
Notifications in its menu (`2_avatar_count-1280-dark.png`), at 390 px on
Menu, which is her avatar and holds the site's links and hers, nothing
sideways (`3_menu-390-light.png`); /notifications one group, the tower's
picture drawn, rows likes, photo, comment, "10 new likes today" with no
avatar, Bob's two with his avatar and their `#comment-`/`#photo-` links,
all New and unread, no liker's name or handle on the page and nothing of
following; the count gone on the page and from the API; Mark all read
offered (`4_notifications-1280-dark.png`, `4_notifications-390-light.png`);
reloaded no longer New (still unread after the file, read before it); the
comment's row opening its model, Back showing the group read, kept on a
reload; Bob may not read hers (404, after the file); signed out 401, not
an id 400; the Your feed tab: her feed without the comment and photo after
the file, with them before (`6_feed-1280-dark.png`); Bob's like making 11
and the group unread again; Mark all read kept across a reload
(`7_notifications_read-1280-light.png`); Bob's empty page
(`7_empty-1280-light.png`); signed out at 1280 dark and 390 light and dark
(`7_signed_out-*.png`); Sign out from her menu. 38 checks before the file
and 39 held, all ok, 2026-10-22, about a minute each; the throwaway
accounts deleted.

A feed you look at (2026-10-22, docs/SOCIAL.md U9). No SQL. The look
first, on the stand-in (Sam follows Mika and Priya; `feed-nobody` follows
nobody), then the code against the live project through a local relay
with nothing held:

```sh
node tools/web/design_flow.mjs --only=feed,feed-nobody --out=shots/design-feed
node --env-file=.env tools/web/relay_server.mjs 8840 &
node --env-file=.env tools/web/feed_flow.mjs --url=http://127.0.0.1:8840 --out=shots/feed
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/feed_flow.mjs --url=<preview> --out=shots/feed
```

`design_flow` passes 12 pages with no failure: signed in, Priya's photo,
her rover, her challenge entry and Mika's version and mech as posts with
the designers Sam does not follow beside them (Robin, Jo; not Sam);
signed out and following nobody, the ask or "You follow nobody yet",
Latest's cards and photos and five designers. `feed_flow` proves it when
it ends "feed: Latest signed out and following nobody, a follow from the
suggestions, posts with pictures: ok": a throwaway Ada lists a tower, one
build finished, a photo of her build and its version 2; a visitor at 390
light and 1280 dark sees the ask, Latest with her tower and every picture
drawn, Ada among the designers (`1_signed_out-*.png`); Bob, following
nobody, the same under "You follow nobody yet", not himself suggested,
the designers beside the feed at 1280 (`2_nobody-390-dark.png`,
`2_nobody-1280-light.png`); Follow beside Ada makes Following and "What
they share is in your feed now.", and the API says he follows her
(`3_followed-390-dark.png`); the next load at 390 and 1280: version,
photo, model, newest first, each sentence and its link (`/m/<id>/v/2`,
`#photo-`, `/m/<id>`), the note and the photo's words, her card or her
photo, every picture drawn, none New (made before he last opened it), no
Latest, Ada no longer suggested, nothing sideways
(`4_posts-{390,1280}-{light,dark}.png`); the version's name opens it;
latest kept by the CDN and never with tests=1, her tower only with it,
Ada's score 3; the feed itself 401 signed out; no script errors.
33 checks, all ok, on the live project through a relay with nothing held,
2026-10-22; the throwaway accounts and their models deleted. The flows
that read the feed's markup, run with it: `follows_flow --site` (the
post's `.what`, `q` and `a.go`), `notifications_flow`, `challenges_flow`
(50 checks; the entry's post at 390 and 1280).

First steps and the house (2026-10-22, docs/SOCIAL.md U10). The house's
profile is a script the lead applies; tried first, run twice and rolled
back on the live project, it reads back one profile (`brickworks`, its
words 210 characters, 13 or over), its banner and three pins, all seven
house models' cards credited to it with no model row changed, may be
followed, 7 models on its page, all 7 of Top builds' cards credited to it
(so the feed's designers to follow have it), its page in the sitemap, and
step 2: each of the seven tagged ai-designed once, its other tags and its
`updated_at` as they were, With the assistant finding all seven and
Hand-built none (the one trigger on `shared_models`, `trust_guard_model`,
only refuses):

```sh
set -a; . ./.env; set +a
PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs supabase/house.sql \
  --dry --again=supabase/house.sql --try=tools/house_try.sql --table=people
node tools/web/first_steps_flow.mjs --out=shots/first-steps
node tools/web/design_flow.mjs --only=first-steps,feed,feed-nobody,person-house,account,age --out=shots/design-first
node --env-file=.env tools/web/relay_server.mjs 8870 &
node --env-file=.env tools/web/first_steps_flow.mjs --url=http://127.0.0.1:8870 --out=shots/first-steps-live
```

With no `--url` the flow is the stand-in with the live gallery and the
house's profile held in memory (`liveCommunity(true)`; `state.fresh` a new
account): a first visit at 390 light and 1280 dark, the feed suggests
Brickworks and its seven Latest cards link to `/u/brickworks`, the
gallery's seven cards each with its avatar and link and the Assistant
mark, and `/u/brickworks`
has its words (the studio's own account, made with the assistant), the castle across the top, three pinned
(`1_{feed,gallery,house}-*.png`); a first sign-in at 390 dark and 1280
light from the feed's Sign in: the code, the age question, First steps
1 of 3, the handle `sam-okafor` made from "Sam Okafor" and the avatar "S",
Make my profile, 2 of 3 with 11 kinds, Castles chosen, 3 of 3 with
Brickworks to follow and six models castles first, Following, See your
feed: 7 posts by Brickworks with their cards, no Latest
(`2_{profile,kinds,start,followed,feed}-*.png`); Skip, Skip, Follow, See
your feed: 4 taps to a filled feed (`3_feed-390-*.png`); signed in from
Follow on `/u/brickworks`: First steps end with Done only, and the follow
goes on after (`4_start_pending-*.png`). It ends "first steps: a first
visit meets a designer to follow, a first sign-in makes a profile and
fills the feed: ok". With `--url`, throwaway Ada (a listed castle, one
build) is suggested at 390 and 1280; Bob signs in through the dialog,
makes `bob-<rand>` on the live project, follows Ada from step 3 and his
feed is her castle; Cy, signed in elsewhere, meets the age question and
First steps on `/profile` and reaches the filled feed in 4 taps, with
nothing new on the avatar after the follow for Ada's castle, listed
before it (`feed_count` 0 and 0; m163 said 1, walk180 W7), and 1 once Ada
lists a tower after it; every throwaway deleted (18 checks, all ok,
open222 through a relay, 2026-10-24). 34 checks on the stand-in and 16 on the live project
through a relay, all ok, 2026-10-22. `design_flow --only=first-steps`
judges each of the three steps at 390 and 1280, light and dark (with the
feed, the house's page, the account and the age question: 104 checks, all
ok). The flows that answer the
age question on the site were taught First steps: `age_flow` (13 or over
on /profile: skipped to the page) and `people_flow` (signed in from Like:
Done only, then the like).

Discovery (2026-10-19): Top builds, this week's pick, small builds, and
build with what I own. The SQL first, after the live files, in one
rolled-back transaction, and the sums alone:

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/discovery.sql \
  --dry --try=tools/discovery_try.sql --table=gallery_picks
node tools/web/owned_probe.mjs --sets=<checkout>/assets/generated/sets
python3 tools/minitest.py tests/test_discovery.py
node --env-file=.env tools/web/needs_backfill.mjs --dry --facts=<part_facts.mjs output>
```

The dry run proves it when every line says what its label says: the
weights 11, 12, 5, 5, 0; Top builds Wall, Tower, Bridge, Barn, Mill,
Longer; pages DiscTry002/001, 003/004, 006/005; Most built and newest as
before; small builds Wall, Tower, Barn; a visitor's 0; the week Tower 11,
Bridge 5, Barn 5; the pick Tower worked out, a visitor's none; Mill
chosen until a week from now with its own week; unlisted and nobody's
`not_in_gallery`, 0 and 32 days refused, 40 written directly refused;
Barn chosen, the open choices newest first, Barn unlisted passed over for
Mill, Mill ended back to Tower, ended once not again, Bridge run out not
the pick; an account taken out: none in the week, not the pick; Bob's
cards Barn 1/1, Tower 3/3, Bridge not counted, Wall 1/3, Mill 50/300, none
with no pool; Parts I own Tower, Barn, Wall, Mill, Bridge; build now
Tower, Barn; no grant on the five tables to any key, row security on, only
the service role executing; three pages of 25 the same as one list; the
timings (docs/COMMUNITY.md, Discovery: Top builds about 170 ms and Parts I
own 125 to 360 ms on 5,000 models and 300,000 need rows); "rolled back,
nothing kept". `owned_probe` ends "owned_probe: 11 checks, all ok".
`needs_backfill --dry` names the seven real models' parts and lots, keeping
nothing.

Then the code, in real browsers. Until discovery.sql is applied the local
server holds it (`--hold=gallery_picks`, `tools/web/discovery_stand_in.mjs`)
over the live project's models, builds, Tested marks and collections; once
it is, a preview with the bypass, through its API alone. The admin part
signs in as `MASTER_EMAIL` (a code minted, nothing sent):

```sh
node --env-file=.env tools/web/relay_server.mjs 9252 --hold=gallery_picks &
node --env-file=.env tools/web/discovery_flow.mjs --url=http://127.0.0.1:9252 --out=shots/discovery
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/discovery_flow.mjs --url=<preview> --out=shots/discovery
```

`discovery_flow` proves it when it ends "discovery: Top builds, this
week's pick, small builds, the owner's choice, and what you can build":
four test models listed, Tower's finding kept as passed, builds counted
2, 3, 1; Top builds tower, wall, hall, shed on the list and the page with
its line (`1_top_builds.png`), Most built wall first, a visitor's none,
`tests=maybe` 400; the pick Tower with its week (11), small builds Tower
then Wall without Hall; the front signed out and signed in at 1280 and 390
px (`2_front_*.png`), the pick "Built twice this week", You can build now
asking for a collection only when signed in, the small shelf scrolling
inside itself on a phone (`3_small_shelf_*.png`), the pick a link; on
`/admin` Make it the pick beside Shed, its row "no: a test account's"
(`4_admin_pick_now.png`, `5_admin_choices.png`), the front's pick Shed
"Chosen by Brickworks" on a phone (`6_front_chosen-390.png`), a visitor's
never, the model by link only 422 in words, anybody else 404, End back to
Tower; Bob's collection (a real set, an unknown one, six loose bricks)
read as 3/3, 3/3, 1/3, 5/210 with his pool's lots, pieces and one unknown
set, Parts I own offered him and ordering tower, shed, wall, hall, ready=1
tower, shed, signed out 401 both ways and no shares without mine=1, You
can build now tower, shed at 1280 and 390 px (`7_build_now-*.png`,
`8_build_now_shelf-390.png`), the page by Parts I own with "You have 1 of
its 3 parts · 33%" (`9_parts_i_own.png`); Ada with no collection asked to
tell what she owns (`10_no_collection-390.png`); no page errors. 48
checks, all ok, 2026-10-19, against the held relay with the live project
(about 4 minutes), with the catalogue beside api/ and without it (a pool
then counts every part as named, and the set's shard comes from
brickworks.diy/sets/). share_probe, against the same relay with the
catalogue: 288 checks, all ok.

A designer's page and their own numbers (`supabase/designers.sql`). The SQL
first, in a transaction rolled back on the live project (the trial makes
its own accounts and models inside it):

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/designers.sql \
  --dry --try=tools/designers_try.sql --table=model_opens
python3 tools/minitest.py tests/test_designers.py
```

It proves it when every line reads as its label says: model_views' days
all counted in (0 missing), `count_view` true then false with the trigger
off and on alike (views 1, visitors 1; opens today 1 only with it), the
castle's opens 3 today, 5 and 7 kept; Ada's page models 1, builds 3,
remixes 2, comments 2, tested 1, builders 2, the photos Ed's and Bob's and
not hers or the hidden one; a visitor's count of test models 0; models,
likes, builds, remixes and Tested all true against profile_page and the
cards; comments true against the page; her own castle 8 opens (15 in
all), 2 builds (3), 1 remix (2), 1 comment (2), the secret and the
nameless among her models; Bob's only his two; days 1 and 90; Bob taken
out and Cy under 13 no page; no grant on model_opens, row security on,
the functions the service role's alone; the timings (docs/COMMUNITY.md,
Designers); "rolled back, nothing kept". The tests: 10 passed.

Then the code, in real browsers. Until designers.sql is applied the local
server holds it (`--hold=model_opens`); once it is, a preview with the
bypass, through its API alone:

```sh
node --env-file=.env tools/web/relay_server.mjs 9267 --hold=model_opens &
node --env-file=.env tools/web/designers_flow.mjs --url=http://127.0.0.1:9267 --out=shots/designers
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/designers_flow.mjs --url=<preview> --out=shots/designers
```

`designers_flow` proves it when it ends "designers: what a designer's models
earned, and their own numbers for them alone (N checks, all ok)": three
test models (the castle Tested), built on 3, 1 and 1 devices and opened by
4, 1 and 2 visitors, Bob's remix, his comments and photo and Ada's answer;
`?op=profile` models 2, builds 4, remixes 1, comments 2, Tested 1; signed
out at 1280 and 390 px (`1_visitor-1280.png`, `2_visitor-390.png`)
Designer, the tiles in order builds, remixes, tested, comments, models,
followers, each the sum of the cards, the castle first ("3 built · 1 remix
· 1 comment", Tested), no views, Bob's photo under Built by others, Start
with their most built to `/app?view=<castle>`, none of Ada's own numbers;
Bob signed in (`3_bob-*.png`) the same and `not-mine`, his follow making
the tile "1 follower", his own page with his photo under Built,
`?op=designs&handle=<hers>` `{"mine":false}`, plainly his own model only;
Ada (`5_ada_own-1280.png` in dark, `6_ada_own-390.png`, `7_ada_account-*`,
`8_ada_account-*`) the panel ready, totals 7 opens, 5 builds, 1 remix, 2
comments, the castle first 4/3/1/1 with Bob's photo, the secret by link
among them, every picture loaded, the same on Account; signed out and
forged 401, a bad handle 400, every answer `private, no-store`, none from
the CDN, Ada then Bob on one address each their own, her page the same
bytes signed in or not, without tests public for 30 s with none of her
test models (on a deployment, where the CDN keeps `s-maxage` for itself
and sends `public, max-age=0`, the CDN answering it again); no page errors.
39 checks, all ok, 2026-10-19, against the held relay with the live
project (about 2 minutes). Never paired with `discovery` on a preview: each
reads the week's test models, and one's castle took the other's pick.
**Play** (`play in a shared model`, `what moves in a model`, `what moves on
a gallery card`, `share play probe`, `play browser flow`). The SQL first,
in a rolled-back dry run on the live project (after discovery.sql), and
the words held together across the app, the API and the SQL:

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/play.sql --dry --try=tools/play_try.sql --table=shared_models
python3 tools/minitest.py tests/test_play.py
```

The dry run proves it when it ends "rolled back, nothing kept" with: every
model's `moves` `{}` and none null; "wings" and nine words refused by
`shared_models_moves_words`; `moves_mechanism` true for steering and for
doors and gears, false for doors, nothing and null; the cards saying
`["steering"]`, `[]`, `["doors"]`, `[]`; Technic or mechanism "PlayTry001,
PlayTry002" (the racer by its steering, the crane by its parts; not the
house, nor the hut), everything all four, a visitor's none; the three
functions the service role's alone; the filter's first page about 4 ms.
`test_play` ends "6 passed".

A model's own motions on its card (`supabase/motions.sql`, after play.sql),
the same way, and the gallery's answers compared before and after it:

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/motions.sql --dry --try=tools/motions_try.sql --table=shared_models
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/sql_compare.mjs supabase/motions.sql motions
python3 tools/minitest.py tests/test_motions.py
```

The dry run proves it when it ends "rolled back, nothing kept" with: every
model's `motions` `{}` and none null; thirteen names, 61 characters, a line
break, a space first and an empty name refused by
`shared_models_motion_names`, twelve allowed, null refused; the cards
saying `["Open the gates","Open the mailbox"]`, the observatory's three and
`[]` beside their `moves`; the list asked with tests saying the same;
Technic or mechanism as play.sql made it (the observatory and the racer);
the house's page (`directory_model`) with its motions; a visitor's list of
test models empty; `directory_card` and `motion_names_ok` the service
role's alone; a visitor's first page about 7 ms (2026-10-20). The compare
ends "17 of 17 answered the same". `test_motions` ends "5 passed".

The viewer in the real scene, on 8808-1 (a window: on Xvfb under `gpu`;
about a minute on the GPU):

```sh
tools/probe.sh share_play_probe
```

Proves it when it ends "a shared model's steering turns by its wheel,
nothing is kept, and Reset puts it back" with no `FAIL` (40 checks): the
pill says "Moves: steering" and "Drag a part that moves…" about 2 s after
the steps; the steering taken by its steering wheel, turned 30° by the
mouse round its column with the loop and the rack, the pill saying "The
steering, 34°", the view not turning, no balance marks drawn and no lean,
each drag frame's own work under 33 ms (1.3 ms mean, 1.6 worst on the
GPU); let go, both steering arms turned 7.7°, 21 parts moved, Reset
offered, nothing published, the link asked for once, its text unchanged,
the store read-only, nothing written to the data folder; Reset puts every
part back exactly; a fingertip on the plate beside the wheel's thin rim
means the wheel, and a finger (index 1, as a browser numbers it) turns it
-24° with the camera still, and Reset again; a drag on the chassis turns
the view and moves nothing; Build it after a play opens on the model as
built; and published from the builder, the panel sends `moves:
["steering"]`. Then (section 8, 2026-10-20, 66 checks in all) 1484-1 with
`tests/fixtures/motions/1484-1.motions` written into it: "Play its motions"
with `view_motion_1` and `_2`; Open the gates pressed, its frames drawn (2
parts moving, about 1.9 s), both gates at 90.0°, the mailbox still, the
button lit and Reset offered; Open the mailbox at 90.0°; the gates pressed
again back where they were built (0 off), the mailbox still open; Reset,
every part as built, nothing lit; a press's own cost said (50 to 93 ms
here); nothing published, nothing written, the text unchanged. Pictures in
`shots/play/` (`5_motions.png` to `7_motions_reset.png`). About two
minutes on the GPU.

In a browser, on a local export (serve.py plays the link), then on a
preview through the API alone:

```sh
PARTS_URL=x tools/export.sh web
python3 tools/web/serve.py build/web 8771 --parts assets/generated/parts --delay 0 --share Pl4yFl0w01=vendor/omr/files/8808-1.mpd &
node tools/web/play_flow.mjs --url=http://127.0.0.1:8771 --out=shots/play_web
tools/release/preview_checks.sh <preview> <worktree> TAG play     # publishes from a throwaway account
```

`serve.py --parts` hands out each part's exact shape too (`/parts/<hash>.bwx`
from `exact/` beside `parts/`, as the bucket has it), so the steering is
judged by its parts' shapes as on a deployment: without them it stopped by
its covers, at 95° rather than 108°, and its stop cost half as much (G14a).
Proves it when it ends "a shared model's steering turns by its wheel, by
mouse and by finger, and Reset puts it back" (34 checks, about 100 s), at
1280 x 800 by the mouse and at 390 x 844 by a finger (index 1), in
SwiftShader: what moves said inside the
page, the joints read on a worker, the steering wheel's handle (`play:
"steering"`) turned 10° or more with the view still (85° and 107°), the
finger taken as the steering's (`brickworksShare.finger` "part"), the pill
saying what turns, the app's own work in a drag frame under 36 ms on
average on a CPU (2026-10-23: each engine frame after a move of the
pointer, its `tdur` in Chrome's trace, the dearest apart, the frame it
takes hold in; on the phone each counted four times, as on a phone that
much slower; m158 and m159 22.6 to 28.9 ms on the phone at load 14 to 35,
about 6.5 on the laptop; the drag runs at the box's speed, since CDP's
CPU throttle spins a slowed thread as long as the clock says, so a slowed
frame's CPU time grows with the load; the app's own figures by the page's
clock, which held m147 and m159 at load 35 to 40 on the old bar of 33 ms,
and the page's frame gaps said beside it; and, said, its worst frame
checking the way while the finger rested,
`worst_pause_ms`, where a loop's joints' own parts are asked, Grab 15:
by a finger slowed four times 18.8 and 22.9 ms on Grab 16, 34.7 to 42.3 on
m101), Reset offered and inside the page, the pill clear of the view cube,
the link's text unchanged, Reset putting it back; then the
gallery's page from the checkout with its list played: the racer's card
"Moves: steering", the house's "Moves: doors", the hut's nothing, the
observatory's "Moves: open the dome, extend the telescope, open the back
wall panels and 1 more" (its four motions), Technic or mechanism asking
`technic=1`. With `--publish` (or `--house=ID`, serve.py serving the file
`--write-house=FILE` writes), the house with its two motions too, at each
size: the buttons inside the page, clear of the cube, 34 px tall on the
phone; each played (`brickworksShare.motion`: the gates 0° to -90°, the
mailbox 0° to 90°) and lit, the press's own work and its wait for the
parts' shapes said (laptop 180 and 44 ms, the first press waiting 12.4 s;
the phone slowed four times 713 and 171 ms, 10.1 s; local relay, load 40,
2026-10-20); the gates pressed again back to 0°; Reset; the text unchanged.
And its page's facts, "Moves: doors" before motions.sql (`motions: null`),
"Moves: open the gates, open the mailbox" after, at 390 and 1280, light and
dark. The local relay (`relay_server.mjs 9120 --static=build/web`, .env
sourced) sends `/app?view=` on to `/?view=`; the flow follows either. With `--publish`, once play.sql is applied,
the list asked with tests and technic finds the published racer with
`["steering"]` on its card. Pictures `laptop_*.png`, `phone_*.png`. On a
deployment the link is the model's page, which does not go on by itself
(only serve.py redirects), so the flow presses View in 3D as a person
does: 37 checks, all ok, 2026-10-19, on a preview (about 2 minutes); before
that it waited 600 s on the page and failed.

The monthly challenge (`supabase/challenges.sql`). The SQL first, in a
transaction rolled back on the live project (the trial makes its own
accounts, models and challenges inside it):

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/challenges.sql \
  --dry --try=tools/challenges_try.sql --table=challenge_entries
python3 tools/minitest.py tests/test_challenges.py
```

It proves it when every line reads as its label says: refused `past`,
`set_empty`, `overlap` with "Try October", too long by the check; the house
keeps all three rules, the tower one lot short (3003 Yellow, need 10, have
4), the hall parts, set and Tested broken, the uncounted one `counted`
false; entering refused `not_yours`, `no_model`, `not_in_gallery` twice,
`under_13`, `rules`, a way that is neither, `entered`, `not_asked`,
`no_challenge` for a model that is not a test's; Ed, who follows Ada, has
in `feed_rows` the house as a `challenge` row ("Try October", hand) beside
her four `model` rows, it is his newest and his count 5, and Fay (not a
test account) has none; votes refused `own`,
`under_13`, `not_asked`, `no_entry`, `not_open`, then `voted`; the page
with two entries, no votes shown; the house not keeping the rules on an
untested newer version and a vote for it `breaks`; taking back and in
again; `three`; a designer taken out leaves the page; after the end no
entry or vote; settled once, the house by hand 2 and the shed 1; the tie
to the shed, entered first; the list; no table grants, row security on,
17 functions the service role's alone; the timings (docs/COMMUNITY.md,
Challenges); models, designer and pick "the same"; "rolled back, nothing
kept". The tests: 9 passed. And what it keeps: every gallery answer and
every feed the same before and after, rolled back:

```sh
set -a; . ./.env; set +a
PG_MODULE=<pg>/lib/index.js node tools/sql_compare.mjs supabase/challenges.sql won
```

Then the code, in real browsers. Until challenges.sql is applied the local
server holds it (`--hold=challenges`); once it is, a preview with the
bypass, through its API alone:

```sh
node --env-file=.env tools/web/relay_server.mjs 9271 --hold=challenges &
node --env-file=.env tools/web/challenges_flow.mjs --url=http://127.0.0.1:9271 --out=shots/challenges
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/challenges_flow.mjs --url=<preview> --out=shots/challenges
```

`challenges_flow` proves it when it ends "challenges: set, entered, voted
and won, every rule checked on the stored model (N checks, all ok)": the
owner sets it on `/admin?tests=1` (`1_admin_set-1280.png`,
`1_admin_form-390.png`) with set 6075-2, Castle, another on its days 409,
anybody else 404; the tower refused on its page for "3004 in Red (it needs
12, the set has 0)" (`2_enter_refused-390.png`), the house entered by hand
(`3_enter_dialog-390.png`, `4_entered-390.png`) and said in Ed's feed, who
follows Ada, as one line linked to the house (`4b_feed_ed-390.png` light,
`4b_feed_ed-1280.png` dark; not Bob's shed), the hall refused for parts
and set, the plain one for Tested, Bob's shed in with the assistant, Cy
under 13 refused; `/challenge` signed out (`5_challenge_visitor-*`), the
gallery's line (`6_gallery_line-1280.png`), Ed's two votes
(`7_challenge_ed-*`), Bob's vote, second vote and own refused, Cy told why
(`8_challenge_cy-390.png`); ended on `/admin`, the winners 2 and 1 votes
(`9_challenge_winners-*`), Ada's win as a pill under her numbers (the
house and its 2 votes in its title) and the card (`10_designer_won-390.png`), the gallery card's `won`; no page errors.
A visitor's answer is `public, max-age=0` on a deployment (Vercel's CDN
keeps `s-maxage` for itself), so there the CDN answering the same question
again (`x-vercel-cache: HIT`) is the proof; locally, `s-maxage=30`. 50
checks, all ok, 2026-10-19, on a preview with challenges.sql applied, and
the same against a local relay over the live tables.

Between months (challenge_year.sql, 2026-10-24): the owner also sets a
year of three themes from next month (`1b_admin_year-1280.png`), read back
from the table (the first "to come", the others "to come, told from …")
and the admin's answer (each its month, `announced_at`); the hub's Coming
next names the first and never the others (whose `?id=` is 404, as the
first's is without tests=1); ended, the hub shows the first theme and lists
the challenge first under Past challenges with both winners' cards
(`9a_challenge_past-*`), its name opening `/challenge?id=N&tests=1`, where
the winners checks above run; Ada's win is the first of her achievements
(`won,tested,listed`). Until the file is applied, run it against
`relay_server.mjs <port> --hold=challenges` with `--held` (the feed, which
the database makes from its own entries, is then not asked): 59 checks, all
ok, 2026-10-24; against base code 2 failed (no year form, no achievements).
On a preview before the file: the year's form says it is not open yet, and
the hub is read as before (62 checks, all ok); with it applied (2026-10-24),
the year path above on the unit's preview: 62 checks, all ok.

The list, asked hard (reads only):

```sh
node tools/web/list_load.mjs --url=http://127.0.0.1:8790 --n=200
BW_BYPASS=$VERCEL_BYPASS node tools/web/list_load.mjs --url=<deployment> --n=200
```

Proves it when it ends "list_load ok: no errors, 90% within N ms": 200
answers, all 200 with a list, and the slowest questions named. Locally
against the live database, 2026-10-13: median 224 ms, 90% within 316 ms.

Proves it when it ends "a model can be shared by link, and nothing else can be
done with one" (79 checks): publish refused signed out and with a made-up
session; published with an id and a link; the part count 9 for a sub-model
placed twice, two bricks and a made part (a `!DATA` picture not counted); read
signed out byte for byte with name, author and count and no owner; the page's
og:title and og:image, its way on to the viewer, not frameable; the picture and
its CORP; the card, frameable; refused at the edge — over 2 MB 413, JSON, a
binary file, HTML, a part line cut short, no parts and a sub-model inside
itself 415, a picture that is not a PNG 415, no name 400; republished in place
(10 parts, new name, author gone, picture gone and the page falling back to the
site's); another account updating or unpublishing 403, signed out 401, an
unknown id 404, none of it changing anything; the owner's list and nobody
else's; with the publishable key straight at Supabase: the row refused
(readable before `no_client_access_models.sql`), its `owner` not, no insert, no update, the publish log closed, the file not in a
public bucket; unpublished — the model 410, the page and the card 410 saying
so and no longer naming it, no picture, the row unreadable; a link that never
was 404; republished, the same link back; the sweep refused with no secret and
a wrong one, then a third account published and deleted with its model up — its
row gone and its two files still there — and the sweep takes exactly those two,
the bucket no longer has them, and the published model is untouched, swept
whole too; twenty publishes an hour, then 429.

The viewer and the Share panel in the real scene, with no network
(`FakeShared` plays the endpoint; a window, so on Xvfb in a session with no
screen; about three minutes in software, 74 s on the GPU under `gpu`, most
of it two catalogue loads). The viewer is up before its steps are worked
out, so the probe waits on the steps bar, not a count of frames: it prints
how long the steps took (0.6 s for the 73-part house on the GPU):

```sh
godot --path . --resolution 1400x900 --script src/dev/share_view_probe.gd
```

Proves it when it ends "a shared model opens to look at and nothing else, and
the panel shares one" with no `FAIL`: a model made in a library of its own
(the house, a part made in the element maker and a printed tile, so both reach
the viewer only inside the file) opens with no sign-in screen; account, store,
layout and made parts all set to write nothing; every part standing, the made
part and print built and not kept; the builder's bars and panels gone; the
timeline at the end, and its own Start, Next and End pressed with the mouse
scrub it; twenty editing commands refused and the looking ones allowed; Save
and the store's writer refused with nothing on disk; a click, a drag (which
turns the view) and Delete, R, X, C, Q, M, lift and Ctrl Z/V/D/A/S changing no
part; the part under the pointer outlined and named beside it; Parts list
pressed on the bar, and its BrickLink and Rebrickable lists written; the
booklet; a link taken down saying so on a card in the middle. Then the panel,
signed in: Share opens it with the name, Show who made it offers one, Publish
sends the LDraw with the made part and print and no link line, the author, and
a 1200 x 630 PNG; the link kept with the model and sent back on the next
publish (no author once unticked); not listed unless List it in the gallery is
ticked, then sent `listed: true` with the panel saying so, unticked sent false;
a copy's `remixed_from` sent, kept in its saves on a line LDraw ignores beside
the link's and read back when it opens; Unpublish; another account's link
replaced; Clear and new work forget both. The viewer's about line ends
"· remixed from Probe Original" for a link that is a remix. Versions
(2026-10-18): the version line says "Version 2: …" or "Version 1 of 2, an
older one"; a place kept on step 2 of version 1 opens on step 2 told nothing
and kept on version 2, one on step 5 is told "This model changed from step
3." and Go to step 3 goes there, one closed on step 5 is told on the viewer
and Build from step 3 opens it; `BuildSteps.changed_since` case by case;
What changed? only once there is a link, sent trimmed with the next
publish, and the panel saying which version is up and what changed
(`12_version_line.png`, `13_changed_from.png`, `14_viewer_changed.png`,
`8a_new_version.png`). Pictures in
`shots/share/` (`7_og_image.png` is the link's preview picture,
`8b_list_ticked.png` the panel with the box ticked).

The whole of it in real browsers, on a deployment (two throwaway accounts,
deleted at the end with the row; no email sent; ten minutes or more on
SwiftShader):

```sh
BW_BYPASS=$VERCEL_BYPASS node tools/web/share_flow.mjs --url=<deployment>/app --out=shots/share_web
```

Proves it when it ends "a model can be shared by link, looked at by anyone,
and taken down": see the steps in the script's header; pictures
`1_shared.png` to `11_viewer_unpublished.png` and `og_image.png`. The gallery
in it: the box there and unticked, ticked, published "listed in the gallery";
its card on `/gallery` in a browser that never signed in, ahead of every card
listed before it and the page newest first (`tools/web/gallery_order.mjs`,
from the list the page drew: another flow's model listed after it may be
ahead), with its name, "N parts, by Flow Builder" and its picture drawn (`1b_gallery.png`); the
copier's copy knowing what it came from, shared at a link of its own unlisted,
its page saying "Remixed from Share Flow Car" with a link (`9b_remix_shared.png`);
the owner's panel opened again with the box ticked as the link is, unticked
and updated, the card gone from `/gallery` (`9c_gallery_unlisted.png`) and
the link still working; no script error or refused request on any page.
The directory in it (since 2026-10-13): the tags then the description typed
in the panel, each read back before the next (keys sent to a canvas drawn in
software arrive late, and the second box's once went nowhere), the kind
guessed from the name (vehicle) and CC BY unless changed; the page with the
description, the tags and the kind as links and CC BY 4.0; the card found on
`/gallery?q=<a word of the description>` and `/gallery?tag=...&sort=views`
(`1c_gallery_search.png`, `1d_gallery_tag.png`); the link opened by a visitor
whose browser says it is a person's is the model's page with View in 3D
(`2a_model_page.png`), its view counted once, and View in 3D pressed opens
the viewer; the owner's page counting the copier's remix, shared by link and
so not named. With a bypass it sends `x-vercel-skip-toolbar`, since Vercel
puts its preview toolbar in a page for a browser that is not headless and
the site's policy refuses it. 49 checks on the preview of 2026-10-13, about
six minutes at a load of 10.

The gallery page under the site's security policy, locally with a made-up
list of 26 (one with no picture, one whose name is markup) or against a
deployment (part of `download_check.mjs`, after the download page):

```sh
node tools/web/download_check.mjs --shots=shots/gallery
VERCEL_BYPASS=$VERCEL_BYPASS node tools/web/download_check.mjs --url=<deployment>/download --shots=shots/gallery
```

Proves it when the gallery lines say 24 cards then 26 after Show more
(locally), the markup name shown as text and no `img` but the pictures', a
model with no picture given none, "86 parts, by Builder 2"; and at 390 and
1280 px no console error, no sideways scroll, no broken picture
(`gallery-phone.png`, `gallery-laptop.png`). Locally, since the directory:
"model 2" typed in the search box asks `q=model+2` and shows its 8, Space
picked as well shows 5, a search that finds nothing says so with Clear,
Clear brings back the 24 and `/gallery`, an address asking for a kind there
is not gets the whole gallery and its address put right (its one refused
answer not counted as an error), and `?kind=castle` picks Castles and shows
its 13. `site_check.mjs` has `/gallery` among its pages (200, title,
description, canonical, card), `/gallery.html` 308 to it, its links resolving
and its screenshots; and the newest listed model's page, `/m/<id>`, as one of
the site's pages (title, description, a canonical at the deployment's own
address, its card's picture there, every link and file it loads answering —
asked with HEAD, which the function answers as GET — no console error and no
sideways scroll at 390 and 1280, `model-phone.png`, `model-laptop.png`). It
found the model page's two columns not folding on a phone (440 px in 390) on
the first preview of 2026-10-13.

Seeding (once; again only to change the seeds — it updates them in place):

```sh
xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/gallery_seed.gd -- \
    --seed-list=tools/web/gallery_seeds/seeds.json --seed-out=DIR
BW_BYPASS=$VERCEL_BYPASS node tools/web/gallery_seed.mjs --url=<deployment> --dir=DIR [--dry]
```

Proves it when the first ends "the gallery's models, as the app shares them"
(each a 1200 x 630 picture, listed, credited; a 480 x 252 card picture; its
words, tags, kind and licence as the list says) and the second "N models in
the gallery, shared by gallery@brickworks.diy", every line `ok`, each seed
`updated` but one newly added. DIR keeps each picture as `<n>.png` and
`<n>-thumb.png`, to look at before publishing. Then
`/api/share?op=list` carries each one's description, kind and licence, and
its `thumb`.

**Build it.** The pages, headless, in about half a minute (the catalogue load):

```sh
godot --headless --path . --script src/dev/build_steps_probe.gd
```

Proves it when it ends "every page of the step player can be built from, and
a link comes back where it was left" with no `FAIL`: on the shed (two windows
and a figure in callouts), the house and the 2,438-part castle, every part
picked up on exactly one page, each page showing what is built by then and
nothing after, what came before faded and the page's own parts not, the parts
listed being the page's new parts by part and colour, the most first, the
pages numbered as the timeline numbers them, a callout's first page saying to
build it on the side and the page that puts it on outlining every copy; a
page's view worked out in under 20 ms on the castle; the same file making the
same pages twice (and, printed, that the reverse order does not — why the
viewer opens a link again in its file's order); a part behind a wall looked
at from the back; a tile on a big floor framed close; the kept page per link,
and junk in its place read as none; and each turn's changes (`count`,
`fading`) the same as the whole model asked, next, back and jumps.

The steps carried with a shared model, headless, about a minute:

```sh
godot --headless --path . --script src/dev/share_pages_probe.gd
```

Proves it when it ends "a shared model's steps are carried with it and read
back as the viewer would work them out" with no `FAIL`: on the house, the
castle (436 steps, callouts and all) and Orthanc's lowest 1,000 parts, the
steps written at the end of the text; the text opened as the viewer opens it
(`ModelStore.open_text`, a baseplate laid under it as scenery) and the steps
read back for it in milliseconds; and they are the very steps the viewer
works out there itself (`Instructions.plan_paced`), every field step for
step, and every page of Build it the same (caption, note, new parts, what is
on the baseplate, the parts to pick up). Then never used: the text edited by
one part, an old link with none, a part fewer in the world; and written
twice, the second replaces the first. `-- --write IN OUT ...` writes each IN
with its steps carried (the share steps flow shares those).

A model's step count, the server's and the app's alike, headless, about five
minutes (it needs `node`):

```sh
godot --headless --path . --script src/dev/step_count_probe.gd
```

Proves it when it ends "the server counts a model's steps as the app counts
them, in the same words" with no `FAIL`: the orrery, the castle, the kart,
the sports car and 6680-1, each shared as the app shares it and opened as the
viewer opens it; its steps (`Instructions.count`: the numbers the booklet
prints, "87 steps", and what is built on the side said apart, "12
sub-assemblies built on the side in 64 steps of their own") the same as its
timeline works out, its last step's "of", the step player's cover and the
text read alone (`SharedPages.count`); and `api/share.js` run on the very
text (`checkModel`, `api/_steps.js stepCount`) counting the same, in the same
words, keeping every page as the model's `steps`. The model page says them
from its file as it is read, never the stored count (`share_probe`: "3 steps
as its booklet numbers them, its tower built on the side said apart").

The player in the real scene is the last part of `share_view_probe` above
(`shots/share/9_build_cover.png` to `11_build_again.png`): Build it pressed on
the bar, the cover, Next pressed three times to "Step 3 of N", the faded parts
read back from their batch as `BrickWorld.faded` of their colour and the new
ones in their own, the outline, every part picture drawn, the step framed
between the bars, a swipe each way across the parts (and the model not
turning under it), the arrow keys, a finger turning the model and two
pinching it, the page kept; the viewer opened again straight on step 3;
Close; Build it again back on step 3; and Finish.

In real Chromium with touch, at a phone's and a tablet's size, against a local
export (no account, no database: `serve.py --share` plays the link), about ten
minutes on SwiftShader:

```sh
tools/export.sh web
python3 tools/web/serve.py build/web 8761 --parts assets/generated/parts --delay 0 --share models/house.ldr &
node tools/web/build_flow.mjs --url=http://127.0.0.1:8761 --out=shots/build_web
```

Proves it when it ends "build it works on a phone and a tablet, and comes back
where it was left": at 390 x 844 (3x) and 820 x 1180 (2x), `/m/<id>` opens the
viewer with Build it on the bar; tapped, the cover; Next tapped three times,
"Step 3 of N" with steps 1 and 2 faded and every part picture drawn, Next and
Back at least 46 points tall, every control inside the page; with the CPU
slowed four times, the worst frame of three page turns no more than twice the
worst of three Nexts on the viewer's own timeline (both printed: the aim is
100 ms and on this box neither meets it — 2026-10-13, phone, the timeline 158
to 165 ms, the pages 122 to 280 ms, of which the page's own work
(`brickworksShare.build.turn_most`) was 54 to 126); a swipe each way across
the parts; a finger turning the model; the page in `localStorage`; and after a
reload, step 3 again. Pictures
`shots/build_web/<size>_1_viewer.png` to `_5_reloaded.png`. Against a
deployment: `--url=<preview> --id=<a published link's id> --bypass=…`.

**Versions** (`supabase/versions.sql`, `tools/web/versions_flow.mjs`,
2026-10-18). The SQL, dry: run in a transaction and rolled back, with the
trial queries after it (`pg` from npm, `.env` sourced):

```sh
PG_MODULE=<pg>/lib/index.js node tools/apply_sql.mjs supabase/versions.sql \
  --dry --try=tools/versions_try.sql --table=share_versions
```

Proves it when it prints, before "rolled back, nothing kept", every
published model with a version 1 (`published_without_version_1` 0,
`as_the_model_is` equal to `compared`), a version 2 written as the server
writes one, the five refusals (no such model, the same version twice, a
note over 280, a version 0, changes not an object), `anon_reads` false and
`server_writes` true, and the file run again adding nothing. 2026-10-18: 7
published models, 7 version 1s.

In real browsers, until the file is applied against a local relay that
holds `share_versions` in memory (`--hold`, `tools/web/held_tables.mjs`) and
sends everything else to the real project; once it is applied, against a
preview with `BW_BYPASS`:

```sh
tools/export.sh web
node tools/web/relay_server.mjs 8852 --static=build/web --hold=share_versions &
node tools/web/versions_flow.mjs --url=http://127.0.0.1:8852 --out=shots/versions
```

Proves it when it ends "a model published again keeps the old one, says what
changed, and keeps a builder's place" with no `FAIL`: a six-step tower (its
steps carried by `share_pages_probe --write`) published, then published
again with step 3's two bricks blue and a note — version 2, "2 parts added
and 2 removed in step 3", by part and colour, step 3 the first changed, both
files in the bucket; the link's page says it with the note, part by part,
"Steps 1–2 are as they were", and names `/m/<id>/v/1`, which says it is
older, links to the newest, is noindex, and whose model is still red; the
viewer on `?v=1` says "Version 1 of 2, an older one" at `/m/<id>/v/1`; a
builder kept on step 2 of version 1 opens on step 2 told nothing and kept
on version 2; one on step 5 is told "This model changed from step 3." and
Go to step 3 goes there; one who closed the player on step 5 is told on the
viewer and Build from step 3 opens it there; the gallery's card is the link;
a second account's Open in Brickworks copy, shared, says "Remixed from …,
version 2"; unpublished, the link, version 1's page and model answer 410,
neither file is in the bucket and no row is left. Pictures in `--out`.
`share_view_probe` (above) proves the same in the desktop scene against the
fake, with `BuildSteps.changed_since` case by case.

**Tested** (`src/assembly/tested.gd`, `api/_tested.js`, `supabase/tested.sql`,
`tools/web/tested_flow.mjs`, 2026-10-18). The four tests, headless, on
models whose answers are known:

```sh
godot --headless --path . --script src/dev/tested_probe.gd
godot --headless --path . --script src/dev/tested_probe.gd -- --sets vendor/omr/files/10218-1.mpd   # each test, and where the time went
godot --headless --path . --script src/dev/tested_models_probe.gd
```

Proves it when it ends "each of the four tests passes a model that should
and fails one that should not, saying why" with no `FAIL`: 6680-1 stands at
its 15 steps, every part made in its colour, its figures and stretcher
builds of their own, and its whole test names only the 1 x 2 plate its file
puts inside a 1 x 6 one; three bricks
stacked pass all four; the top one put in before what holds it fails steps
("Step 2: Brick 2 x 4 is put down in the air"); a brick put in a closed box
after its roof fails steps as hidden; an arm on a 1 x 2 base tips it over
onto the arm's tip and lies there whole, which passes stands (a build that
tips is let fall to where it rests, `Tested.Weighing.settle`, tested305);
a table on one leg tipped over onto its edge by a stack of eight 4 x 12
bricks on one stud fails stands ("At step 4 it tipped over to the right and
rests leaning 46°, its far end on the floor, and Plate 1 x 1 Round is held
by Plate 6 x 16 on 1 stud past where it lets go"), and with five it holds
and passes; a 1 x 1 brick in
Light Blue fails parts ("never made in Light Blue"); a brick held by nothing
fails whole ("Brick 1 x 1 falls"); the finding names its file's
fingerprint and the app's version; 10218-1 (2,042 parts, 190 steps) tested in
about 2.2 s.

The whole test is the exact check's (since 2026-10-23, tested176): every
part held by BrickNet's connections or caught where it is, no two parts
passing into each other past a joint's own; a piece on the floor that stands
by itself and touches no bigger piece is a build of its own. BrickBench's one
piece stays the design check's count. `tested_models_probe` proves it when it
ends "a model is Tested when it goes together, and one that does not says
why": a tile on two bricks is Tested and a brick resting on the tile is not
("Brick 1 x 2 rests on Tile 1 x 2"); two stacks apart are "2 builds" and
Tested, a round plate left on the floor against one is not ("stands
against"); 6680-1's figures and stretcher are builds of their own, and
without the one 1 x 2 plate its file draws inside a 1 x 6 it is Tested
("4 builds"); 620-1 and 6511-1, a vehicle and a figure, pass the whole test
as "2 builds"; a cheese slope on a round plate's
rim is not ("where it has no stud"); the kart, castle and orrery in models/
are Tested (the orrery's steps are its own, `0 !BRICKWORKS AUTHORED_STEPS`:
its lower and upper decks, crank, planets and Sun built in the hand, each
drive gear in before the ring round it); the six sculpt170 bench designs (`src/dev/fixtures/bench/`) pass
the whole test, and are Tested where their other three pass (one, model-043:
the rest fail steps or parts); Orthanc as it ships (`models/orthanc.ldr`,
rebuilt in one piece in m157) is Tested in a share's time: its steps are its
own since orthsteps212 (the base, the guards, the tower in eight stages a
course at a time round the ring, the upper works, each horn's tip built in
the hand, the wizards), its staffs and flail are in colours they are made
in, and the steps are weighed as they go (`Tested.Weighing`: what is held
to the floor two ways or more is weighed as the floor, a piece hanging off
it again only when a part joins it), where every step's build was weighed
afresh and its 1,420 steps took ten minutes.

The SQL, dry (never applied by an agent):

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/tested.sql \
  --dry --try=tools/tested_try.sql --table=share_tests
```

Proves it when, before "rolled back, nothing kept": a passed mark makes
`model_tested` and the card say true and a failed one false; `directory_models`
with `tested` lists the passed one alone; cleared, it is not tested; the five
refusals (no such version, passed with a test failed, fewer than four tests,
an app that is not a version, anybody but the app); a version deleted takes
its mark; `anon_reads` false, `server_writes` true, `anon_asks` false.

In real browsers, against a local relay holding `share_tests` (which also
says what the gallery's functions would, `tools/web/held_tables.mjs`):

```sh
tools/export.sh web
node --env-file=.env tools/web/relay_server.mjs 8923 --static=build/web --hold=share_tests &
node --env-file=.env tools/web/tested_flow.mjs --url=http://127.0.0.1:8923 --out=shots/tested
```

Proves it when it ends "a model is marked Tested by what the app found, shown
to all when it passed and only to its owner when not" with no `FAIL`: three
models tested by `tested_probe --write` and published (passed, failed,
none); a finding of another file not kept; a visitor sees the mark, the four
on hover and on a tap, on the passed one's page, its card and its viewer,
and no mark or failure on the others; Tested only lists the passed one; the
failed one's owner is told "A step is not reachable: Step 2: …" on its page,
`?op=mine` says each, `?op=tested` answers nobody else; and a publish from
the app's own Share panel sends what it found, which the server keeps.

**Real builds** (`supabase/builds.sql`, `api/_builds.js`, `api/_photo.js`,
`tools/web/builds_flow.mjs`, 2026-10-18): a build finished counted once per
device (`POST /api/share?op=built`), "N built" on the page, the card and the
viewer, Most built; and "I built it" photos (`/api/people?op=photo_start`,
`?op=photo`, `?op=photos`, `?op=photo_file`, `?op=photo_hide`; the admin's
`?op=remove_photo`, `?op=photo`). How a photo is made safe, alone and fast:

```sh
# shots/builds/build_with_gps.jpg is drawn by builds_flow (below): 960 x 640, Exif with GPS, a make, Orientation 6, and a comment
node -e 'import("./api/_photo.js").then(async ({cleanPhoto}) => { const m = await cleanPhoto(require("fs").readFileSync("shots/builds/build_with_gps.jpg")); console.log(m.width, m.height, m.bytes.includes("Exif"), m.bytes.includes("GPS")) })'
```

Proves it when it prints `640 960 false false`: turned upright, nothing of
the file but its pixels. Drawn PNGs (every colour type, 1- to 16-bit,
interlaced), lossy and lossless WebPs and progressive JPEGs all came back
JPEGs whose markers are `e0,db,c0,c4,da` only (JFIF, tables, frame,
picture); a file that is not a picture is refused 415, one under 120 px a
side 422 (2026-10-18; a 4,000 x 3,000 JPEG in about 1 s).

The SQL, dry (never applied by an agent), in the release's order, after the
three files before it that are not applied yet (builds.sql's
`directory_card`, `directory_models`, `report_stream` and
`claim_report_digest` supersede theirs and keep what each added):

```sh
cat supabase/tested.sql supabase/trust.sql supabase/comments.sql supabase/builds.sql > /tmp/builds_dry.sql   # trust.sql's hourly knock block may be left out of a dry run
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs /tmp/builds_dry.sql \
  --dry --try=tools/builds_try.sql --table=build_photos
```

Proves it when, before "rolled back, nothing kept": a device finishes once
(true, false for the same device, true for another, false for a model taken
down), a key that is not one refused; the card says builds 2 and keeps
`tested` and `by`, Most built first; three photos allowed and a fourth
refused, under 13 and never asked refused, a removed one not counted; a
report about a photo and one about a comment both in the test account's
stream and both in its one digest, the photo named and the comment's words
said; a photo that is not there refused by its foreign key; the two
buckets private, 8 MB of JPEG, PNG or WebP and 4 MB of JPEG; row security on.

In real browsers, against a local relay holding the new tables and buckets:

```sh
tools/export.sh web
node --env-file=.env tools/web/relay_server.mjs 9104 --static=build/web \
  --hold=model_builds,build_photos,report_photos,share_tests,model_comments --trust-stand-in &
node --env-file=.env tools/web/builds_flow.mjs --url=http://127.0.0.1:9104 --out=shots/builds
```

Proves it when it ends "a build finished counts once per device, and a photo
of it is made safe, shown, hidden, reported and taken out" with no `FAIL`: on
a 390 x 844 touch page, Next to the last step sends one finish and the model
is built once; Back and Next again, and the viewer opened again in the same
browser, send nothing more; a robot's finish not counted, the desktop app's
counted; "1 built" on the page and the card, Most built putting it ahead of
every card built less (one built more, or as often and listed later, may be
ahead: `tools/web/gallery_order.mjs`); a JPEG drawn
with GPS, a make and a comment comes back with markers `e0,db,c0,c4,da`, no
Exif, GPS, make or comment in its bytes, turned upright; the original gone
from the uploads bucket; the photo in the strip and on the profile; three a
model and a fourth refused; under 13 refused in words; the owner hides it
(404 at its address) and shows it again; a report from its Report it reaches
the admin page with the photo, and Take the photo out deletes that one file.
On a deployment (`BW_BYPASS=$VERCEL_BYPASS node --env-file=.env
tools/web/builds_flow.mjs --url=<preview>`, `builds` in
`preview_checks.sh`) every request, the pages' too, says Vercel's bypass,
and what is kept is read from the project with the secret key, this flow's
rows and files only (its model's builds, its builder's uploads, its photos).
The model's page and a photo's file are kept at the CDN for up to a minute
(`SHARED_CACHE`), so a photo added, hidden, shown again or taken out is
asked for again every 5 s until it shows, up to 90 s, and the check says
how long it took. On m81's preview the flow sent no bypass: the listing got
Vercel's 401 and the viewer its sign-in page, which read as the age rule
refusing it. The test accounts' age is answered by `mintSession`
(`answerAge`), and an account never asked is refused with a 422 saying so.
`share_view_probe` (above) proves the app's half: a finish sent once per
device and link, never for a jump, the cover or opening the viewer.

Build it where it is first shown (jump290, 2026-10-26): `--first-told` does
only the phone's first Build it, tapped the moment the viewer is ready where
the page first says it is, as the flow did before m177, and stops. With
`--slow=2` (the page's CPU slowed twice, as a busy box's) the timeline comes
just after Build it is told at the foot. On 974ebff1 a phone's Build it was
told at y 800 and rested at 754, and the tap missed 7 of 13; a tablet's
(820 x 1180) at 1136 and 1039, missed 1 of 3. Since `main.floor_at` reckons
the timeline's top from the foot of the window in whole units (the status
bar is up while the steps are worked out), it is told once, at 754 (8 of 8)
and 1039 (3 of 3), where it rested before, and every tap opened the step
player, most of them taken up before the timeline came. Against the relay
above:

```sh
node --env-file=.env tools/web/builds_flow.mjs --url=http://127.0.0.1:9104 --out=DIR \
  --first-told --slow=2 [--size=820x1180]
```

Proves it when every run ends "Build it, tapped where it was first told, opens
the step player where it stays": `first-told {...}` says where it was told
each time it moved (`moves`, one entry) and `told` equals `rests`.

**Share steps browser flow** (`tools/web/share_steps_flow.mjs`, 2026-10-17):
each page turn of Build it timed from the finger to the frame, and the first
step from the link, on a phone slowed four times, at 300, 1,000 and 4,000
parts (the lowest parts of Orthanc's own model, so the steps are worked out).
About ten minutes a size here, most of it the steps being worked out:

```sh
tools/export.sh web
node tools/web/share_steps_flow.mjs --build=build/web --port=8800 --out=DIR
set -a; . ./.env; set +a
BW_BYPASS=$VERCEL_BYPASS node tools/web/share_steps_flow.mjs --url=<preview> --publish --out=DIR
```

`--build` serves the export itself (`serve.py`, one link a size with
`--share ID=FILE`); `--publish` publishes the three to a deployment from a
throwaway account at a Resend test address (marked a test, so no gallery
lists them), and unpublishes them and deletes the account at the end;
`--ids=300:ID,...` names links already up. Chromium on SwiftShader, 390 x
844 at 3x, touch, `Emulation.setCPUThrottlingRate` 4 from the engine's first
frame (slowed from the start, the download and the engine starting took over
ten minutes). Build it is tapped the moment it is offered and Start the
moment the cover is up; then Next three times, Back, a tap on the progress
bar at step 30, and End. Every engine frame is timed in the page (its
callback, its time inside WebGL, its WebGL calls and draws); a turn is from
the touchend the page heard to the end of the frame that drew the page (the
app says which: `window.brickworksBuildDrawn` = [page, when]) and to the
next frame's start, "on screen"; with `brickworksShare.build.turn_last` (the
turn's own laps: world, outline, view, page, kept), `turn_frames` (the rest
of that frame: to its processing, the processing, the drawing, and the page
told all within it, Main's own processing, the nodes' processing between
the first and the last to process) and whether the page was told all in
that frame. The models are shared as the app shares them, their steps
carried (written by `share_pages_probe.gd --write`, the Share panel's own
`SharedPages.attach`; the Godot run uses `XDG_DATA_HOME`, the checkout's
`.scratch-data` when unset); `--bare` shares the text alone, as a link from
before carried steps, whose steps the phone works out. The first step is
said as tapped by the flow and with each tap made at once — from the
engine's first frame to the steps being in (`window.brickworksStepsReady`),
plus the cover drawn after Build it and step 1 after Start: the page hears
of a control half a second after it appears, which is the flow's time, not
the app's — with `brickworksShare.carried` and the viewer's way there
(`brickworksShare.opened`: fetched, opened with `ModelStore.open_phases`,
drawn, parts, steps). `--trace=DIR` records a Chromium trace of the turns
and says, for each turn's frame, what ran between the app's marks
(`console.timeStamp` "bw:turned", "bw:process_frame", "bw:first_node",
"bw:last_node", "bw:pre_draw", "bw:post_draw") and the garbage collection
in it: how the grab's twice-a-second search for handles was found in the
nodes' processing. Proves it when it ends "a shared model's pages turn
quickly on a slow phone, and its first step comes up quickly": each turn on
screen under 100 ms at 300 and 1,000 parts and under 200 ms at 4,000, the
first step, each tap at once, within 3 s of the first frame at 300 and
1,000 parts and 5 s at 4,000, and every turn's parts' pictures all drawn
within 1 s of the tap (`window.brickworksPicturesDrawn`). On a box at load 30 to 50 a frame's WebGL
calls wait seconds on SwiftShader now and then, and a turn with them misses
however little the app did (the line says the WebGL time). Measured
2026-10-17 at load 25 to 54 (bench/results/sharesteps-2026-10-17, r7 to
r11, local and preview): the first step, taps at once, 0.25 to 3.2 s after
the first frame with the steps carried, or 6 to 9 s when Start's frame
waited on SwiftShader (9 to 12 s and 75 to 135 s worked out on the phone);
a turn's own work 13 to 56 ms, one to three turns of five at each size over
the bar on WebGL waits of 0.2 to 2.7 s; every turn's parts' pictures in 14
to 130 ms of the tap, drawn ahead. Start's own pictures are drawn when the
page asks if Start comes within the cover's 4 s (`AHEAD_ON_COVER_MS`): 15
to 18 s on this box.
`--report-only`
says it all and judges nothing (a build from before: no drawn mark, no tap
on the bar, the turn read as the first frame after the tap). Pictures `<size>_step1.png`, `_step4`,
`_step30`, `_step<last>` (at full speed), and `times.json`. In
`tools/release/preview_checks.sh` as `share_steps`, run alone.

And the deploy, which is the only proof that counts for the web build:

```sh
node tools/web/check.mjs --url=https://brickworks.diy/app --out=shots/deploy.png
```

Proves it when: it exits 0 and prints `crossOriginIsolated: true`, `the build runs
at <url>`, then four `ok` lines for the view controls it drives in the browser —
turn (right-drag), zoom (wheel), slide (shift-scroll), turn (middle-drag) — ending
`check ok: <url>`. The PNG shows the baseplate with the model on it, not the
loading colour and not a blank canvas. Measured against production 2026-10-02.

And a big design, made the way the owner's froze their computer:

```sh
set -a; . ./.env; set +a
node tools/web/freeze_check.mjs --dir=build/web --out=shots/freeze
```

Proves it when: it exits 0 and ends `the page stayed alive: the app's longest
frame was N ms (budget 500)`, every call answered. Against the build before
2026-10-11 it fails: a check_design was one 31 s task, a submit 43 s, and the
look that followed came back "The Brickworks tab did not answer in time" while
the build animation weighed the model once a step.

### A person's page (/u/), and what it shows

The SQL first, in a rolled-back dry run (never applied by a unit):

```sh
set -a; . ./.env; set +a
PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs supabase/profile_shows.sql \
  --dry --try=tools/profile_shows_try.sql --table=profile_shows
```

It passes when Ada's links, banner and pins are allowed and read back; an
http link, three links, a password in a link, a host with no dot,
javascript:, four pins, a pin twice, a pin or a banner not an id are each
refused by a check; Cy (under 13) and Di (never asked) refused by the
profile's trigger; anon and authenticated may not read; her row gone when
her account is deleted; "rolled back, nothing kept" (2026-10-22: all so).

Then the page, locally from the stand-in's people (Robin with links, a
banner and pins; the house account; Ines with 60 models; Alex with
nothing), and on the relay or a preview with a throwaway designer:

```sh
node tools/web/profile_flow.mjs --out=shots/profile
node --env-file=.env tools/web/relay_server.mjs 8993 --hold=profile_shows &
node --env-file=.env tools/web/profile_flow.mjs --url=http://127.0.0.1:8993 --out=shots/profile-relay
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/profile_flow.mjs --url=<preview> --out=shots/profile-preview
```

It passes when it ends "N passed, 0 failed" (2026-10-22: 196 locally, 82 on
the relay): at 390 and 1280, light and dark, signed out and in, the avatar a
tile with the initial, every shown number not 0, links https and ugc
nofollow, the tabs one current with no count of none, at 390 the avatar,
name, numbers and Follow above 844 px; Robin's numbers builds first (77),
his links said as their domain, the watchtower banner loaded, his pins in
his order, whom he follows and no follower named, Share copying the link
and saying so, More opening Report it; the Builds and Collections tabs;
the house's 7 models and its empty tabs' words; Ines's 60 models reached
by Show more twice, page 3 as served 12 cards; on the relay, op=showcase's
seven refusals, Ada's links, banner and pins kept (or "not open yet"
before the SQL on a preview) and her page as above. Achievements
(2026-10-24, docs/SOCIAL.md U13): Robin's five in order (won, ten, tested,
listed, built), the win a link to the watchtower, each with the award icon
and its meaning as its title; the house's include listed and no win; Alex
none; your own `/profile` (Sam) the same ones /u/sam-builds shows. On the
relay, Ada earns each by doing it, read from `?op=profile` after each step:
nothing with a profile alone, `listed`, `tested,listed`, then a photo of her
build of Bob's model `tested,listed,built`, then ten finishes of her castle
`ten,tested,listed,built`, and her page at both widths and themes says so
under her numbers; Cy, with a profile and a listed model, says he is under
13 (his profiles row): his page and its answer 404 naming nothing, and his
own /profile says under 13 with no achievements. Ada is deleted by Delete
account (her photo's file with her). 210 passed locally (14 failed against
base code), 102 on the relay, 2026-10-24. `design_flow` judges
`person`, `person-builds`, `person-lists` (More open), `person-house` and
`person-new` for controls, the scale and zeros.

### Your account as your profile (/profile, /settings)

docs/SOCIAL.md U6. Throwaway accounts on the site's live project, deleted
by the end; a relay, or a preview:

```sh
node --env-file=.env tools/web/relay_server.mjs 8890 &
node --env-file=.env tools/web/account_page_flow.mjs --url=http://127.0.0.1:8890 --out=shots/account_page
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/account_page_flow.mjs --url=<preview> --out=shots/account_page
```

It passes when it ends "account page: N passed, 0 failed": Ada set all the
old page could (name, handle, words, two links, a banner, two pins, a
favourite, a private collection, two email choices, whom she follows
shown); signed out both pages offer Sign in; signed in at 1280 and 390 in
both themes her head as `/u/` draws it with her links, banner and pins in
her order, the tabs Models · Builds · Saved · Sets · Insights with Models
open (4 of her 5 and Show more), under 2,000 px at 1280, avatar, name and
Edit profile above 844 px at 390 with the head's buttons in one row; Edit profile holds all nine fields as she set them, a name changed
there shows with no reload and nothing else changes (`?op=me` and her
public page read back); Saved, Sets and Insights drawn, and a reload keeps
the tab; her own `/u/` page offers Edit profile (to her alone) and it opens
the dialog; `/settings` has the seven rows with her choices, an email choice
and the theme changed and changed back, Settings' Edit profile opens the
dialog, Sign out; Bea with no profile sees two fields and her profile
drawn at once; Ada deleted from Settings is gone from the sign-in service,
her page and models 404, and no row of hers in people, profile_shows,
model_collections or model_favourites. `design_flow` judges `account`
(Edit open), `account-saved`, `account-sets`, `account-insights` and
`settings` (Delete open).

### Your own picture as your avatar, and your likes on your profile

docs/SOCIAL.md D11, U5, U6; `supabase/avatars.sql`. Locally with the
stand-in's people (Robin and Priya chose pictures, Robin shows their
likes), then on a relay that holds the file's tables, or on a preview:

```sh
node tools/web/avatar_flow.mjs --out=shots/avatar
node --env-file=.env tools/web/relay_server.mjs 8871 --hold=profile_avatars,profile_choices &
node --env-file=.env tools/web/avatar_flow.mjs --url=http://127.0.0.1:8871 --out=shots/avatar-relay
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/avatar_flow.mjs --url=<preview> --out=shots/avatar-preview
```

It passes when it ends "PASS: N passed, 0 failed". Locally: Robin's
picture loaded and round on their head, their cards, the model page's
byline and comments, the feed; Mika's, Jo's and Sam's the tiles; Robin's
Likes tab counted 3, newest first; Sam has none; Sam's crop sends a square
JPEG of 120 to 400 px whose middle is the face dragged into the circle; 9
MB and a text file refused in words. On a relay: the refusals, Ada's
picture in Edit profile, her head and header with no reload, on her page,
card, model, comment and Bob's feed at both widths and themes; her Likes
shown from Settings and hidden again; the owner takes it out on /admin
(MASTER_EMAIL) and its file 404s; a third replaces a second (its file
404s); Remove the picture; deleting the account deletes its file. On a
deployment before the file: every avatar the tile, no Choose a picture,
and a picture or Likes 503 "not open yet". `design_flow` judges
`account-picture` (the crop dialog) and `person-likes`. The SQL's own
refusals and cascade: `tools/avatars_try.sql` in the dry run
(`tools/apply_sql.mjs supabase/avatars.sql --dry --try=tools/avatars_try.sql`).

### The gallery (/gallery), as a person uses it

The SQL first, in rolled-back dry runs (never applied by a unit): what it
adds, then that the gallery answers as it did.

```sh
set -a; . ./.env; set +a
PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs supabase/gallery_tabs.sql \
  --dry --try=tools/gallery_tabs_try.sql --table=shared_models
PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/sql_compare.mjs supabase/gallery_tabs.sql comments
```

The first passes when the Tower's card says 1 comment (its hidden one not
counted); Top over all time is Tower, Wall, Hut, over 30 days Tower, Wall,
over 7 days Tower; with the assistant the Hut and the Tower, by hand the
Wall; Bob's Following Ada's three, the Hut gone from it once uncredited,
Cy's none; a visitor's list no test model; gallery_models the same as
directory_models on all 14 questions without a new word; both functions
the service role's alone; and "rolled back, nothing kept" (2026-10-22: all
so, a page of Top in 9 ms, this week's in 5). The second passes at "17 of
17 answered the same" (2026-10-22).

Then the page, this checkout's `web/` and `api/` with the stand-in's API
and a crowd of 130 behind its own models, or a deployment's pages with the
same API:

```sh
node tools/web/gallery_flow.mjs --out=shots/gallery
BW_BYPASS=$VERCEL_BYPASS node tools/web/gallery_flow.mjs --url=<preview> --out=shots/gallery-preview
```

It passes when it ends "N passed, 0 failed" (2026-10-22: 37 locally, and
37 with `--url` on `relay_server.mjs` serving this checkout's pages;
2026-10-26: 41 locally): at 390 x 844, light and dark, the first card's
picture within 330 px of the top, two to a row (the most cards sharing a
top, outside the shelves' rows) and four cards' names on the first two
screens; at 1280 x 900 five whole cards, five to a row (four before
2026-10-26); at each, one row of marks at most (a mark clipped off by
`.marks` is not counted), none shown on 90% of the cards, and no card
whose numbers' row is its like alone; Top over all time with this week's
pick first and no count of 0; New newest first; Top over this week the
week's, no pick or shelves; the Space pill pressed; Made with the
assistant every card made so and its mark left off (`data-quiet` says
made, as every card carries it), Filters saying 1; Following only signed
in, only whom Sam follows; a search with New, a size and two pages or
more opened by somebody else at 390 in the dark showing the same cards in
the same order (five shorter cards a row bring a third page with the
same scroll); Filters a sheet inside a phone's screen; nothing matching said,
and Clear bringing the gallery back; a like from a card signed out asking
to sign in, signed in pressed and one more at once, its page saying
Liked; three pages by scrolling (the end 100 px under the screen), then
Show more, page=5 in the address; flung to the foot, the next page waiting
with Put yours here where it was, and Show more drawing it at once;
Back to card 101 within 100 px; the empty gallery, an empty Following and
a quiet week each saying theirs with its way; and `api/share.js` before
the SQL refusing a window or Made in words (400), after offering them with
each card's comments. Pictures `gallery_<width>_<theme>[_fold].png` and
each step's. `design_flow` judges `gallery` for controls, the scale and
zeros.

### A collection followed, and Share's sheet

docs/SOCIAL.md U11 and U14. The SQL first, in a rolled-back dry run with
trial queries (never applied by a unit):

```sh
set -a; . ./.env; set +a
PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs supabase/collection_follows.sql \
  --dry --table=collection_follows --try=<a file of queries>
```

Then the pages with no network, from the stand-in (Robin's castles, which
Sam, Jo and Priya follow; the watchtower in two public collections):
`tests/test_model_page.py` (the pill, the part's cards and covers, the
collection's head, Follow, Share, More, followers hidden at none),
`model_page_flow.mjs` (Share's sheet: the link selected, Copy link and Copy
code onto the clipboard and said, Escape back on Share, a phone's own
sheet offered and given the link; "In N collections" and its tab, the pill
bringing the part into view; the embed light chosen on a dark computer and
dark on a light one, the computer's with nothing chosen), `keyboard_flow`
and `design_flow`/`a11y_flow` (`model` with the sheet open, `collection`
with More open). Then live, with throwaway accounts, once the SQL is
applied:

```sh
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/list_follows_flow.mjs --url=<preview> --out=shots/list_follows
```

It passes when it ends "list follows: ..." with no FAIL: Bob's Follow on
Ada's empty collection (its cover "No pictures yet") pressed, Following,
"1 follower"; a visitor told the count and no name; Ada's own refused
(409) and her counts unchanged; Cy (under 13) told why on the page and
refused (422); Ada puts her tower in and Bob's feed says "Ada Collects
added “…” to their collection “…”" with the tower's card, linked both
ways, counted on his avatar; the tower's page "In 1 collection" and
"Collections 1", the pill bringing its card into view; the collection's
cover the tower; let go, Follow again with no count and nothing in his
feed; made private, its page 404 and no collection on the tower's page.

### The collections directory (/collections)

The SQL first, in a rolled-back transaction (Ada's and Bob's public ones
in both orders; the private, the empty and a barred owner's never; a test
account's only with tests; the page's bounds; made private, gone; the
service role's alone):

```sh
PG_MODULE=<pg>/lib/index.js node --env-file=.env tools/apply_sql.mjs supabase/collection_directory.sql --dry --try=tools/collection_directory_try.sql
```

With no network, from the stand-in: `design_flow` and `a11y_flow` pages
`collections` and `collections-followed` (Sam's and Robin's public ones,
never Sam's private one; Follow drawn signed in). Then live, with
throwaway accounts, once the SQL is applied:

```sh
BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/collections_flow.mjs --url=<preview> --out=shots/collections
```

It passes when it ends "collections: public ones as cards ..." with no
FAIL: Ada's tower in her public collection and her private one; a
visitor's `/collections?tests=1` lists the public one as a card (name,
Ada's avatar and link, "1 model", the tower's picture as its cover, linked
to `/c/<id>`, Follow) and never the private one; `/collections` without
tests no test account's and no 404; the gallery's tab and the footer link
to it; Bob at 390 px dark presses Follow on the card, Following and "1
follower", the API agreeing, one batched request answering for the cards;
Most followed lists it; 390 and 1280 px in both themes with nothing
sideways; made private, gone.

### The site for everyone: axe, names and the keyboard

No network and no account: this checkout's pages, the stand-in's API.

```sh
heavy node tools/web/a11y_flow.mjs --out=shots/a11y
heavy node tools/web/keyboard_flow.mjs --out=shots/keyboard
BW_BYPASS=$VERCEL_BYPASS node tools/web/a11y_flow.mjs --url=<preview>       # a deployment's pages, the API stood in
BW_BYPASS=$VERCEL_BYPASS node tools/web/keyboard_flow.mjs --url=<preview>
```

`a11y_flow` passes when it ends "356 pages and dialogs, ... 0 failed"
(2026-10-23, about 10 minutes): axe-core 4.12.1 (`tools/web/axe-core`,
WCAG 2.2 A and AA and best practices) finds nothing serious or critical on
any page or state at 390 and 1280, light and dark, signed out and in, and
lists each moderate one once after (one: the embed has no h1); every
control in Chromium's accessibility tree has a name that says something;
and the key pages' controls are there by name (a card's "Like <model>",
"Reply to <who>", Mark all read, Edit profile, the theme's three). Before
the fixes it named 246 serious findings on 58 states.

`keyboard_flow` passes when it ends "79 checks passed, 0 failed" (2026-10-23,
light and dark, about 4 minutes): with Tab, Enter and Escape (Space for a checkbox)
the skip link first, the first card's name in 20 presses and Enter opening
it; Like pressed with its count in its name and the focus kept, Enter
again taking it back; Save's lists with the focus in them, a list ticked,
Escape back on Save; Share's sheet opened on its link, Copy link and Copy
code each said in the sheet's status line with the focus kept, Escape
back on Share; a comment and a reply sent,
Escape taking a reply's box away back on "Reply to ..."; Report it's dialog
named, 15 Tabs inside it, Escape back on More; Follow; the account menu,
Escape, Notifications, Mark all read said with the focus on the title;
Edit profile's dialog keeping 40 Tabs and saving back on Edit profile;
Settings' theme and a checkbox said; Sign in's dialog named, the code
sent, Escape back on Sign in; the download started; and every one of
the 354 stops showing its focus ring, on the screen and clear of the
sticky header, with nothing moving (reduced motion asked).

## Gotchas

- **A successful upload proves nothing.** The threaded build refuses to start
  unless the page is cross-origin isolated. Those headers are host config, so the
  failure looks like a successful deploy from here and a blank page to everyone
  else. That is why `check.mjs` exists and why `--no-check` is "not advised".
- **Route order matters more than it looks.** `/parts/*.lbm` 404s were being
  caught by a catch-all 308 and answered with the landing page's HTML and a 200.
  The `/parts/` 404 route has to come *after* `{"handle":"filesystem"}`.
- **4xx in the browser fails the deploy** and names the URL. It used to collect
  console errors and ignore them.
- **The screenshot is not fatal.** A hung screenshot used to fail good builds.
- **Vercel seat-checks the commit author.** Any author other than
  `Xaxis <william.neeley@gmail.com>` fails the deploy silently —
  `readyStateReason: seat block`, no build log, nothing in CI.
- Vercel also has a file-count limit; the parts the web build does not carry live
  in Supabase storage, which is what `tools/storage_parts.py` fills.
- **No GDScript string literal is greppable in a `.pck`.** Compiled scripts go in
  as bytecode, so looking for a tool name or a line of the system prompt to prove
  it shipped reads 0 for code that has been live for weeks. `search_parts`,
  `submit_design` and `attachment_points` all read 0 in a build serving them.
  **Control-test with a string that has shipped for ages before concluding
  anything.** What *is* greppable is packed data: `assets/generated/catalogue.json`
  goes in as JSON, so
  `curl --compressed <build>/index.pck | grep -a '"castle":{"sets"'` really does
  prove the catalogue that shipped. For code, the honest proof is the stamp —
  `/app` names `/b/<sha>/index.js`, and that sha names the tree.
- **A 200 from the landing page says nothing about how it renders.** That was
  the whole of the deploy's landing check, and what it missed for as long as the
  page has existed: five header links are 405px wide in a 358px bar, the nav does
  not wrap, so at 390px the document came out **566px wide and the whole page
  scrolled sideways**. `tools/web/landing_check.mjs` loads it in a browser at
  phone and laptop width and fails the deploy on a sideways scroll, on nothing
  visible linking to `/app`, or on a missing heading. Run it on a file while
  editing: `node tools/web/landing_check.mjs --file=web/index.html`. A file is
  served from its directory over http (`static_server.mjs`), not opened as
  `file://`: the pages name `/site.css` and `/img/…` from the root (the 404 page
  is served at any depth), and as files they load unstyled.

  The picture at the top is retaken from a deployment with
  `tools/web/app_shot.mjs --url=<build>/app --ratio=2 --model=res://models/castle.ldr
  --menu=menu_view:Key --fold=assistant --click=outliner --click=cube_zoom_in
  --click=cube_zoom_in --click=view --out=web/_shot-app.png` (a clean browser,
  1600x900 at twice the pixels, the key strip off), not by hand, then made
  `img/hero-3200.webp`, `-2400` and `-1200`. Several pictures in one run, which on
  a busy machine waits for its turn once: `--plan=FILE`, a JSON list of the same
  options. The stability picture is `src/dev/balance_view_probe.gd` in a 3200x1800
  window (`img/manifest.json` has each picture's command).

  Measure a page where its assets resolve. Comparing the edited page against a
  copy kept in the scratchpad "proved" the overflow was mine — the copy had no
  `shot-app.png` beside it, so the screenshot collapsed and the page fitted.
  Three single-change bisects all showing the same 566px is what exposed the
  baseline rather than the change.

- **A wrong path under `/b/<sha>/` answers 404 with the site's 404 page** (it
  was a 308 to `/` until 2026-10-12), so a typo in a filename reads as "the file
  is missing" when it is the URL that is wrong. Read the deployed page for the real names: `index.js`, `index.pck`,
  `index.wasm`.
