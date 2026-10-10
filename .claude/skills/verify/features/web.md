# Web

The same app, in a browser, at brickworks.diy — plus the small server behind
accounts.

<!-- covers: api:*, cli:web build and deploy, cli:browser check -->

## Sub-features

- `GET /api/account`: one request that tells the client everything about accounts.
  Without a token: where to sign in, whether this deployment has accounts at all,
  and the parts bucket URL. With one: who you are, your tier, designs left.
- `POST /api/claude`: the proxy for accounts that pay in our tokens. A
  bring-your-own-key client never comes here — **the person's own key must never
  reach the server.**
- `POST /api/otp`: mints a one-time code with Supabase and delivers it through
  Resend from our own sender. No passwords anywhere.
- `GET /api/admin`: the account list and tier changes. Fails closed, and answers
  404 rather than 403 to anyone signed in who is not the master, so the surface
  does not announce itself.
- `web build and deploy`: `tools/deploy.sh` exports the WebAssembly build, puts it
  under `/b/<sha>/`, points `/` at it and then proves it in a browser.
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
  added later reach Claude unchanged. A closed tab is told so at once, in words.
  Prove it: `node tools/web/relay_server.mjs 8790` (real handler, real queue,
  needs `.env`) and `godot --headless --path . --script
  src/dev/connector_probe.gd -- 8790` — initialize with the app's guidance, 13
  tools, a real call, then the tab off. claude.ai's help centre says custom
  connectors accept authless servers (support.claude.com/en/articles/11503834);
  OAuth can follow if that changes.
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

Runtime — every one of these is safe to run against production:

```sh
curl -s https://brickworks.diy/api/account | python3 -m json.tool
curl -s -o /dev/null -w '%{http_code}\n' https://brickworks.diy/api/admin
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://brickworks.diy/api/claude \
  -H 'content-type: application/json' -d '{}'
curl -s -w '\n%{http_code}\n' -X POST https://brickworks.diy/api/otp \
  -H 'content-type: application/json' -d '{"email":"not-an-email"}'
curl -s -o /dev/null -w '%{http_code}\n' https://brickworks.diy/api/otp
```

Proves it when (measured 2026-10-02):

| Request | Answer |
|---|---|
| `GET /api/account`, no token | `200`, JSON with `enabled: true`, a `url`, a publishable `key`, `parts_url`, `signed_in: false` |
| `GET /api/admin`, no token | `401` `{"error":"sign in to use the design assistant"}` |
| `POST /api/claude`, no token | `401` |
| `POST /api/otp`, `{"email":"not-an-email"}` | `422` `{"error":"That is not an email address."}` |
| `GET /api/otp` | `405` |

And the deploy, which is the only proof that counts for the web build:

```sh
node tools/web/check.mjs --url=https://brickworks.diy/app --out=shots/deploy.png
```

Proves it when: it exits 0 and prints `crossOriginIsolated: true`, `the build runs
at <url>`, then four `ok` lines for the view controls it drives in the browser —
turn (right-drag), zoom (wheel), slide (shift-scroll), turn (middle-drag) — ending
`check ok: <url>`. The PNG shows the baseplate with the model on it, not the
loading colour and not a blank canvas. Measured against production 2026-10-02.

A signed-in path needs a real account: sign in through the app, or run
`src/dev/account_probe.gd`, which walks a whole sign-in from the client's side
against the real server. It sends a real email to `MASTER_EMAIL`.

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
- **Never POST `/api/otp` with a valid address as a check.** It emails a person.
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

  Measure a page where its assets resolve. Comparing the edited page against a
  copy kept in the scratchpad "proved" the overflow was mine — the copy had no
  `shot-app.png` beside it, so the screenshot collapsed and the page fitted.
  Three single-change bisects all showing the same 566px is what exposed the
  baseline rather than the change.

- **A wrong path under `/b/<sha>/` answers with a 308 to `/`,** not a 404, so a
  typo in a filename reads as "the file is missing" when it is the URL that is
  wrong. Read the deployed page for the real names: `index.js`, `index.pck`,
  `index.wasm`.
