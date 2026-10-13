# Web

The same app, in a browser, at brickworks.diy — plus the small server behind
it: where the parts are, signing in, the owner's account list, and the Claude
connector's relay. Everyone signs in (see [account](account.md)); the assistant
runs on the person's own key, sent only to Anthropic, or on their own Claude
plan with Claude as the client.

<!-- covers: api:GET /api/account, api:POST /api/mcp, cli:web build and deploy, cli:browser check, cli:freeze check, cli:progress check, cli:arrival check, cli:redraw check, cli:idle check, api:GET/POST /api/share, cli:share probe, ui:shared model viewer, ui:shared model page and card, cli:share view probe, cli:share browser flow, ui:landing page, ui:changelog page, ui:404 page, cli:put the website together, cli:site check, ui:build it step player, lib:build pages, cli:build steps probe, cli:build browser flow -->

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
- `POST /api/mcp` — the Claude connector relay: someone on a Claude plan adds
  Brickworks to Claude as a connector (claude.ai and the Claude apps, or
  `claude mcp add --transport http`), and asks Claude to build. **Two ways
  in** (2026-10-11): `https://brickworks.diy/api/mcp`, one address for
  everybody, which Claude signs in to with OAuth (`api/oauth.js`, see
  [account](account.md)) — each call then goes to that account's open tab on
  any device (`accountTabs`: answering before paused, the tab the connection
  last built in, then in view, then latest heard; the handshake and tool list
  from that tab, else the account's last, else the fullest recent one, so
  Claude can add it before the app is opened) — and one browser's private
  address (`/api/mcp?t=<token>`), the way from 2026-10-09, still answered for
  everyone who added one (`oneTab`). With no `t` and no good token: 401 and a
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
  gets 409. The address is kept on the device (`ClaudeConnector.where`) and the
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
  ([account](account.md)). Real Claude Code went through the private address
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
- `progress check` (`tools/web/progress_check.mjs`, 2026-10-12): presses each
  slow thing in Chromium on SwiftShader and times it against the press's own
  time in the page — how long before the status bar's bar (`Working`) was
  drawn (`window.brickworksWork`; a build without it is read by its page
  state, polled, and marked ~); the app's own longest piece of work, which is
  what is judged (an engine frame less the time it spent inside WebGL calls,
  or one of its input handlers, timed in the page — a press can be handled
  outside a frame, and Timeline's was — or its slowest frame by its own
  clock, `brickworksState.slow`, labelled with what `Working` said); the
  longest engine frame callback (as `render_open_check` times them, WebGL
  calls included) and the longest the page ran no timer, both said and not
  judged, since on SwiftShader on a busy box a WebGL call waits for the
  software drawing of the frame before; the total; and that the bar is gone.
  That last is why the bar is not redrawn until the card has drawn its last
  change (`GpuFence`): every 250 ms regardless, as first written, Orthanc's
  timeline took 77 s instead of 8, software drawings of the whole tower
  queued up behind each other. The parts bin is timed until the page has gone
  quiet after it, since it opens at once and then draws its pictures (the
  quiet is the engine's frames, not the pictures: with them read back after
  the card's fence the next press can come while the bin is still drawing,
  and its bar then waits for the card too). A first visit's car: the parts bin's first open,
  Instructions, Render, LEGO Art's Build of art_flow's galaxy at 48 across,
  Brickify of the bunny; then Orthanc opened from a file: Timeline, Save
  (the toolbar's), File > Export > LDraw (typed into the menus, as a person
  finds them; a space in a menu presses the item it is on, so only words), the toolbar's Select by > Same colour from one part, Shift-M Mirror
  and Shift-E of all of it, Tools > Check stability, Delete of all of it,
  Undo, and New's "Save, then start new" (`brickworksControls.new_save`; the
  owner's freeze, 2026-10-13; a build without that control is not
  measured, and plain New is then, as `--only=new` asks). The commands after
  Timeline are the ones `src/dev/command_probe.gd` found holding the window
  longest. Fails when one that should show the bar does not
  within `--heard` ms (150), when Timeline, the booklet, Art or Brickify has
  work of its own over `--budget` ms (250) in one go, or a bar is left up; `--report-only` prints
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
  ?op=mine` (session): the account's links. `/m/<id>` (`op=page`) is the
  link's page: og/twitter tags (title, the part count and author, the picture),
  the picture and the way in, and `web/share-page.js` sends a person straight
  on to `/app?view=<id>`; its own CSP, not frameable. `/m/<id>.png`
  (`op=image`): the picture the app rendered, `Cross-Origin-Resource-Policy:
  cross-origin`. Every answer here is `no-cache` or `no-store`: the picture was
  `public, max-age=60` until the probe on a preview found Vercel's CDN still
  serving it after the model was taken down. `/m/<id>/embed` (`op=embed`): a card for an iframe
  (`frame-ancestors *`) that opens the link in a tab — the threaded engine
  cannot run in somebody else's page, which cannot be cross-origin isolated.
  **Who can do what:** a visitor's read goes through the publishable key, so
  row security (`shared_models_read_published`, select only, `published`) is
  what says a row is public, and the key's roles are granted every column but
  `owner`; the bucket `shared-models` is private with no policies, and the
  function reads a file with the secret key only after that read; every write
  is the function's, after the session is verified and the row found to be the
  caller's. Rows (and the publish log) go with the account. Its files cannot
  (Supabase refuses to delete storage objects from SQL), so Vercel's cron calls
  `/api/share/sweep` (`op=sweep`) at 04:17 UTC daily with `CRON_SECRET`, and it
  removes every file an hour old or more that no published row owns.
- `shared model page and card`: `/m/<id>` and `/m/<id>/embed`, rendered by
  `api/share.js` (above) and routed by `deploy.sh` before the catch-all, so the
  app's isolation headers and CSP are not put on them; `web/share-page.js` is the
  page's one script (`location.replace` to the viewer, so Back leaves the link).
  A link taken down answers 410 "This model is no longer shared" and names
  nothing; one that never was, 404. The card is a picture and a View in 3D that
  opens the link in a tab.
- `shared model viewer` (`src/ui/share_view.gd`, `main._enter_view`,
  `_view_shared`; `src/net/shared_models.gd`): `/app?view=<id>` — the app's page
  itself since 2026-10-12, query and all, so the address bar keeps it (`?copy=`
  likewise) — which the shell hands the app as `--view=<id>`
  (checked against `^[A-Za-z0-9]{10}$` before anything uses it). The same app,
  read-only, no second renderer: one GET of `/api/share?id=` (asked again, up
  to three times, when nothing at all comes back: on a preview a viewer said
  "Could not reach Brickworks" once in four runs, and the same link opened at
  the next try), the model opened
  through `ModelStore.open_text` (made parts and prints built from the file),
  the parts fetched, then the timeline (`StepsBar`) at the finished model; a bar
  along the top with the name, part count and author, Steps, Booklet, Parts list
  and Open in Brickworks; the part under the pointer outlined in blue and named
  beside it (`_view_hover`, the lattice ray, skipping parts the timeline hides);
  the address put back to `/m/<id>`. **No sign-in** (no gate) and **no write
  path**: `Shell.can` runs only `Shell.LOOKING` (views, fit, timeline, parts
  list, instructions, full screen, website, about), the mouse goes to
  `_view_input` (a left drag turns the view, Shift slides it; nothing else) and
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
  Build it over the model, above the timeline). `brickworksState.told_ms` and
  `told_most_ms` say what publishing all this to the page costs a frame,
  twice a second. Not done: the author's own steps (`0 STEP`, item 1
  of docs/COMPETITIVE.md) are not kept yet, so these are always
  `Instructions.plan`'s; the parts are fetched for the whole model before
  the first page, not page by page; and a page turn is not yet under 100 ms
  on a phone (see the browser flow below).
- `build pages` (`src/assembly/build_steps.gd`): what each page shows —
  `shown`, `fresh`, `faded`, `lots` (by part and colour via `Inventory.key_of`,
  the most first), `caption`, `note` ("Build this on the side", "Put them on",
  "hold this one in place"), `view` — and `recall`/`remember` for the kept
  page, which reads a stored value of the wrong shape as none.
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
  1100 x 700 and the phone. A browser flow after a control in the folded
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
    draws what the last one did, to within 1%. A frame that draws nothing
    shows what the last drew: the app draws only what changed (`IdleDraw`,
    2026-10-11), and a page standing still draws nothing, which `settle`
    counts as settled too.
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
  work to get there. It is judged in frames because in software a frame of a
  4,000-part model is 2 to 3 s of rasterising, which a graphics card does in
  milliseconds. Three frames because the ground is laid wider under a design
  that outgrew it, a frame after it is built. If a case's tab never answers
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
- `idle check`: `tools/web/idle_check.mjs` loads the app in Chromium, lets
  it settle (the model, its parts and the bin's pictures in, nothing
  moving), and counts what a page standing still costs for 15 s: the
  engine's frames, those that asked WebGL to draw, the main thread's busy
  share (CDP `TaskDuration`), and the CPU of every Chromium process by kind
  (the page; SwiftShader in the GPU process). Then a wheel notch over the
  model, the - key and the pointer over the model with a part in hand must
  each be drawn, and the page go quiet after. Fails past one frame drawn a
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
  `/download/` and `/app/` lose the slash. **`/app` is a rewrite**, not a redirect:
  the page under `/b/<sha>/` is served at `/app`, `no-cache`, with every file it
  names made absolute by the deploy (`src="/b/<sha>/index.js"`,
  `GODOT_CONFIG.executable` and `fileSizes`), because the CSP's `base-uri 'none'`
  rules out a `<base>`. The CSP's script hash is of that served copy. **An unknown
  address answers 404 with `web/404.html`**, at any depth and inside `/b/<sha>/`;
  it used to 308 to `/`. `/parts/` and `/sets/` keep their plain-text 404s.
- `landing page` (`web/index.html`, `web/site.css`, the pictures in `web/img/`):
  the hero (the builder with Orthanc, `img/hero-*.webp`), a gallery of real
  models, a row per feature (the designer, LEGO Art, hoses and posing, Studio and
  files, instructions, renders, share links, collection), the rest of the
  toolbox, how it works with the two ways to bring Claude, privacy, the
  dimensions, an FAQ (also as FAQPage JSON-LD beside the SoftwareApplication) and a
  last call to open the app. Every page shares `/site.css` (every text colour 4.5:1
  or better on its background in both schemes), a skip link, a sticky bar with a
  `<details>` menu under 860 px (no script: the CSP runs none inline), and one
  footer. Pictures are WebP at two widths with `srcset`, `width` and `height`;
  all but the hero load lazily. `img/manifest.json` says where each came from
  (`shots/` of the run that made it) and holds its alt text. `changelog page`
  (`web/changelog.html`) and `404 page` (`web/404.html`, `noindex`) use the same
  bar and foot. `robots.txt` keeps `/admin`, `/api/`, `/oauth/` and `/b/` out and
  names `sitemap.xml`, which lists `/`, `/download` and `/changelog`.
- `site check` (`tools/web/site_check.mjs --url=<deployment>`): every page 200 at
  its bare name with its title, description, canonical link and an Open Graph
  card whose picture answers; every old `.html` 308 to its bare name; `/app` 200
  with its build's engine named under `/b/<sha>/`, COOP/COEP and the app's CSP, not
  cached, and the build's files immutable; unknown addresses the 404 page with a
  404; the sitemap's pages 200 and robots keeping `/admin` out; every link,
  picture and `#fragment` on every page resolving (external links fail only when
  gone, 404 or 410); and in a browser, no page logging an error or scrolling
  sideways at 390 px, with a full-page shot of each at 390 and 1280 px in `--out`,
  and `/app` booting with the address bar still `/app` and its `version.json`
  found. About four minutes on SwiftShader.
- `the assistant, as a person uses it`: `tools/web/assistant_flow.mjs` pastes a
  key, asks for a small house and records every answer from Anthropic, with a
  screenshot at each step. With its default fake key it is free and proves the
  path: the key is taken, the request leaves the browser and reaches Anthropic,
  and the refusal reads "Anthropic refused that key…" with the form back. With
  `--key=-` (reads `BW_KEY`) it watches a real design start. The live site was
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
node tools/web/share_probe.mjs --url=http://127.0.0.1:8790
BW_BYPASS=$VERCEL_BYPASS node tools/web/share_probe.mjs --url=<deployment>
```

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
else's; with the publishable key straight at Supabase: the row readable, its
`owner` not, no insert, no update, the publish log closed, the file not in a
public bucket; unpublished — the model 410, the page and the card 410 saying
so and no longer naming it, no picture, the row unreadable; a link that never
was 404; republished, the same link back; the sweep refused with no secret and
a wrong one, then a third account published and deleted with its model up — its
row gone and its two files still there — and the sweep takes exactly those two,
the bucket no longer has them, and the published model is untouched, swept
whole too; twenty publishes an hour, then 429.

The viewer and the Share panel in the real scene, with no network
(`FakeShared` plays the endpoint; a window, so on Xvfb in a session with no
screen; about three minutes, most of it two catalogue loads):

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
publish (no author once unticked); Unpublish; another account's link replaced;
Clear forgets it. Pictures in `shots/share/` (`7_og_image.png` is the link's
preview picture).

The whole of it in real browsers, on a deployment (two throwaway accounts,
deleted at the end with the row; no email sent; ten minutes or more on
SwiftShader):

```sh
BW_BYPASS=$VERCEL_BYPASS node tools/web/share_flow.mjs --url=<deployment>/app --out=shots/share_web
```

Proves it when it ends "a model can be shared by link, looked at by anyone,
and taken down": see the steps in the script's header; pictures
`1_shared.png` to `11_viewer_unpublished.png` and `og_image.png`.

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
and junk in its place read as none.

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

  What the page says, in order: the two ways to design with Claude (`#how`:
  the plan through Connect Claude, or an API key, each as numbered steps with
  what it costs, after signing in), the castle, what the app does, what
  Brickworks keeps and never sees (`#private`: the email address and what an
  account holds, key, login, the relay, models — each claim is in
  `src/account/account.gd`, `api/otp.js`, `api/mcp.js`, `own_key.gd` and the
  CSP in `deploy.sh`; change one, change the page), and the dimensions. The picture at the top is retaken from a deployment with
  `tools/web/app_shot.mjs --url=<build>/app --out=web/_shot-app.png` (a clean
  browser, 1600x900), not by hand, then made `img/hero-1600.webp` and
  `img/hero-960.webp`.

  Measure a page where its assets resolve. Comparing the edited page against a
  copy kept in the scratchpad "proved" the overflow was mine — the copy had no
  `shot-app.png` beside it, so the screenshot collapsed and the page fitted.
  Three single-change bisects all showing the same 566px is what exposed the
  baseline rather than the change.

- **A wrong path under `/b/<sha>/` answers 404 with the site's 404 page** (it
  was a 308 to `/` until 2026-10-12), so a typo in a filename reads as "the file
  is missing" when it is the URL that is wrong. Read the deployed page for the real names: `index.js`, `index.pck`,
  `index.wasm`.
