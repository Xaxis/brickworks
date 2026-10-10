# Web

The same app, in a browser, at brickworks.diy — plus one small endpoint that
tells it where the parts are. There are no accounts: the assistant runs on the
person's own key, sent only to Anthropic, or on their own Claude plan with Claude
as the client.

<!-- covers: api:*, cli:web build and deploy, cli:browser check -->

## Sub-features

- `GET /api/account`: the only endpoint. Answers everybody the same:
  `{enabled: false, assistant: "own_key", parts_url}`, where `parts_url` is the
  project's `PARTS_URL` (null means beside the app). The client is
  `src/net/deployment.gd`; `main.gd` hands the answer to
  `PartLibrary.remote_parts`, and on the web part fetches wait for it. The name
  is left from the accounts, removed 2026-10-09 with `/api/claude` (the proxy
  that spent the project's key for one account), `/api/otp`, `/api/admin` and
  `web/admin.html`; builds already out still ask here. The desktop asks
  brickworks.diy, or `BRICKWORKS_API` when set. **The person's own key never
  reaches the server** — there is nothing on it that could take one.
- `web build and deploy`: `tools/deploy.sh` exports the WebAssembly build, puts it
  under `/b/<sha>/`, points `/` at it and then proves it in a browser. With
  `--prod` it ends only once brickworks.diy redirects to the new sha: the domain
  lagged `vercel promote` by up to a minute, twice, and checks run on "done"
  measured the previous build.
- `POST /api/mcp` — the Claude connector relay: someone on a Claude plan turns
  on Connect Claude in the app, adds the tab's private address
  (`/api/mcp?t=<token>`) to Claude as a custom connector (claude.ai, the Claude
  app, or `claude mcp add --transport http`), and asks Claude to build. Claude
  is the client, on the person's own plan; Brickworks never sees a login, a
  token or a key, and never calls a model — Anthropic's terms allow exactly
  this (a product may not offer Claude.ai login or route plan credentials;
  an end user using Anthropic's own apps is ordinary use). The function only
  carries JSON-RPC between Claude and the tab through `supabase/relay.sql`
  (rows keyed by the token's SHA-256, swept after ten minutes, row security on
  with no policies, public keys refused). The tab answers with
  `CommandSocket.answer_rpc`, the code behind the desktop's MCP port, so tools
  added later reach Claude unchanged.
  **A browser pauses a tab it is not showing, and the person is in claude.ai
  while Claude works** — found on the first real use (2026-10-10): Claude's
  `plan_scale` was taken by a tab in the background, timed out there and was
  lost, and the next call was told "not open" with the tab open. So: the tab
  sends its initialize and tools/list answers when it switches on (`op=hello`)
  and the relay answers those itself; the page — not the paused app — sends
  `op=state&visible=0|1` and `op=close` by `sendBeacon`; a call to a tab out of
  view waits 20 s for it, then tells Claude to ask for it to be brought into
  view; a call taken and not answered is handed out again on the next ask; a
  call Claude stopped waiting for is deleted; the newest page load to switch
  on (`&i=`) takes over and an older one gets 409. The address is kept on the
  device (`ClaudeConnector.where`) and the connector resumes on load, so it is
  added to Claude once. Prove it: `node tools/web/relay_server.mjs 8790` (real
  handler, real queue, needs `.env`) and `godot --headless --path . --script
  src/dev/connector_probe.gd -- 8790` — 18 checks: handshake, takeover, asleep,
  dropped and re-taken, closed. claude.ai's help centre says custom
  connectors accept authless servers (support.claude.com/en/articles/11503834);
  OAuth can follow if that changes. Real Claude Code has been through it: `claude
  -p` with `--mcp-config` naming the address (type http), `--strict-mcp-config`
  and `--tools ""`, asked for a 2x4 brick's part number, initialized, listed,
  called `search_parts` in the tab and answered 3001. On a deployment,
  `tools/web/connector_flow.mjs` does it as a person and as Claude: the switch
  and Copy in a real browser, the address off the clipboard, then initialize,
  tools/list and real calls through the deployed relay; the page told it is
  hidden (Claude asked to bring it back, not told it is closed) and shown
  again; then a reload, after which the same address answers with nothing
  pressed.
- `content security policy`: every page may connect only to itself, Anthropic,
  Wikimedia and the parts store's origin (from `PARTS_URL`); the page's one
  inline script is allowed by a hash computed at deploy; `unsafe-eval` stays
  for Godot's JavaScript bridge. The defence for a key held in a browser is
  that it has nowhere else to go. `assistant_flow.mjs` fails on any refusal in
  the console.
- `which build this is`: the deploy writes `version.json` (commit, UTC time)
  beside the build and the Help panel shows "This build: <commit>, updated
  <local time>". The owner, looking at the live site, could not tell when it had
  last been deployed. Desktop builds say "Development build".
- `browser check`: `tools/web/check.mjs` loads the real URL in real Chromium and
  waits for the canvas to show something other than the loading colour.
- The desktop downloads page (`web/download.html`, `download.js`,
  `releases.json`) ships with every deploy like the rest of `web/`; what it
  does and how it is checked is in [release](release.md). The landing page
  links to it from the nav and the footer. The deploy does not check it yet:
  after a release, run `node tools/web/download_check.mjs
  --url=https://brickworks.diy/download.html`.
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
  typed the key into the app as shortcuts.

## How to reach it

```sh
tools/deploy.sh                 # a preview URL
tools/deploy.sh --prod          # the one brickworks.diy points at
tools/deploy.sh --no-export     # deploy what is already in build/web
node tools/web/check.mjs --url=https://brickworks.diy/app --out=shots/deploy.png
python3 tools/web/serve.py build/web 8099    # locally, with the isolation headers
```

## How to check it

Static: `pyright` covers `tools/web/serve.py`. Nothing static covers the endpoints.

Static: `node --check api/account.js`.

Runtime — safe to run against production:

```sh
curl -s https://brickworks.diy/api/account | python3 -m json.tool
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://brickworks.diy/api/account
```

Proves it when: the GET is `200` with `enabled: false`, `assistant: "own_key"`
and a `parts_url` (the Supabase storage bucket), and the POST is `405`. Until a
deploy carries this change, production still answers in the old shape, with
`enabled: true` and a sign-in `url`; the `parts_url` in it is the same.

And the deploy, which is the only proof that counts for the web build:

```sh
node tools/web/check.mjs --url=https://brickworks.diy/app --out=shots/deploy.png
```

Proves it when: it exits 0 and prints `crossOriginIsolated: true`, `the build runs
at <url>`, then four `ok` lines for the view controls it drives in the browser —
turn (right-drag), zoom (wheel), slide (shift-scroll), turn (middle-drag) — ending
`check ok: <url>`. The PNG shows the baseplate with the model on it, not the
loading colour and not a blank canvas. Measured against production 2026-10-02.

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
  prove the catalogue that shipped. For code, the honest proof is the stamp — `/`
  308s to `/b/<sha>/`, and that sha names the tree.
- **A 200 from the landing page says nothing about how it renders.** That was
  the whole of the deploy's landing check, and what it missed for as long as the
  page has existed: five header links are 405px wide in a 358px bar, the nav does
  not wrap, so at 390px the document came out **566px wide and the whole page
  scrolled sideways**. `tools/web/landing_check.mjs` loads it in a browser at
  phone and laptop width and fails the deploy on a sideways scroll, on nothing
  visible linking to `/app`, or on a missing heading. Run it on a file while
  editing: `node tools/web/landing_check.mjs --file=web/index.html`.

  What the page says, in order: the two ways to design with Claude (`#how`:
  the plan through Connect Claude, or an API key, each as numbered steps with
  what it costs), the castle, what the app does, what Brickworks never sees
  (`#private`: key, login, the relay, models — each claim is in `api/mcp.js`,
  `own_key.gd` and the CSP in `deploy.sh`; change one, change the page), and the
  dimensions. The picture at the top is retaken from a deployment with
  `tools/web/app_shot.mjs --url=<build>/app --out=web/shot-app.png` (the castle,
  a clean browser, 1600x900), not by hand.

  Measure a page where its assets resolve. Comparing the edited page against a
  copy kept in the scratchpad "proved" the overflow was mine — the copy had no
  `shot-app.png` beside it, so the screenshot collapsed and the page fitted.
  Three single-change bisects all showing the same 566px is what exposed the
  baseline rather than the change.

- **A wrong path under `/b/<sha>/` answers with a 308 to `/`,** not a 404, so a
  typo in a filename reads as "the file is missing" when it is the URL that is
  wrong. Read the deployed page for the real names: `index.js`, `index.pck`,
  `index.wasm`.
