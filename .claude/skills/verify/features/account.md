# Account

Everyone who uses Brickworks signs in, on the web and the desktop, with an
email address and a code sent to it. Nothing in the builder can be used until
they have. A Claude connector belongs to the account that switched it on.

<!-- covers: ui:sign-in screen, lib:account session, ui:account panel, api:POST /api/otp, api:GET /api/admin, ui:admin page, cli:sign a machine in, cli:account browser flow, api:Claude's sign-in (OAuth), ui:connect Claude sign-in page, cli:oauth probe, cli:connect Claude browser flow, ui:share panel -->

## Sub-features

- `sign-in screen` (`src/ui/sign_in_gate.gd`, with `src/ui/sign_in_form.gd`):
  over the whole window, the builder dimmed behind, until `Account.lets_in()`.
  "Signing you in…" while a kept session is renewed; the address-then-code form
  when signed out (with "Your sign-in has ended" when a session ended rather
  than being ended); "Cannot reach Brickworks to sign in" with Try again when
  there is nowhere to sign in. It takes every click and unhandled key, and
  `Main._steer_from_keys` stops while it is up. On the web, while it is up
  `window.brickworksControls` names only its own controls (`signin_email`,
  `signin_send`, `signin_code`, `signin_go`, `signin_retry`), and
  `window.brickworksAccount` says `{state, email, offline, gated}`.
  **Not shown** when nobody is in front of the window (`Main._gate_wanted`): a
  probe (`--script`), a headless run, or a command line that renders, exports
  or designs and quits (`--shot --booklet --out --ask --ask-claude-code --bench
  --stress --autobuild --showcase --about`). `--mcp` in a window does show it:
  that is somebody's session. Nor when the deployment answers `enabled: false`
  (a local `serve.py`, somebody's own copy): there is nothing to sign in to. A
  probe about the screen sets `gate_for_probe` on the scene.
- `account session` (`src/account/account.gd`): `request_code` posts
  `/api/otp`; `verify_code` redeems with Supabase directly (`/auth/v1/verify`,
  type `email`); `sign_out` revokes this session only (`/logout?scope=local`)
  and forgets it whatever Supabase said. Only the refresh token is kept, with
  the address, the account id and where to redeem it: in `localStorage`
  (`brickworks.session`) on the web, so a reload has it at once; in
  `user://session.json` on the desktop. A start renews it; Supabase refusing
  (4xx) signs out with a reason; Supabase unreachable keeps the person signed
  in from what was kept (`offline`) — **the desktop works offline once signed
  in**. Renewal re-reads the kept token first, because another tab or window
  on the device may have renewed it. `keeps = false` for a run nobody is at
  (`Main` sets it from `_gate_wanted`): it starts signed out and never touches
  the person's session. Where to sign in comes from `Deployment`
  (`accounts_url`, `accounts_key`, from `/api/account`).
- `account panel` (`src/ui/account_panel.gd`): Account on the toolbar.
  "Signed in as …", whether it was confirmed or is the offline one, what the
  account holds, Sign out (which switches the tab's connector off first;
  Claude stays connected to the account), and for the owner on the web a link
  to the admin page. Its tooltip on the bar names the address. A **Claude**
  section (since 2026-10-11): which of Claude's apps are connected, since when
  and last used (`AccountPanel.when`: "today at 14:05", "11 Oct"), with
  **Disconnect Claude** (`account_disconnect_claude`), which ends every
  connection at once; or "Not connected" and Connect Claude
  (`account_connect_claude`). Asked again each time the panel opens.
- `POST /api/otp` (`api/otp.js`): rate limited in Postgres
  (`may_ask_for_code`: 4 per address and 20 per network address in 15 minutes,
  failing closed — 503 if the limiter cannot be asked, 429 if refused). Mints
  the code with Supabase's admin `generate_link` (sends nothing) and delivers
  it through Resend from `EMAIL_FROM`; on Resend's 403 "not verified" it sends
  from `EMAIL_FROM_FALLBACK` and logs that it did. Never says whether an
  address has an account; does say when the email could not be sent (502).
- `GET /api/account` with `Authorization: Bearer`: also `signed_in`, `email`,
  `master` (cache `private, no-store`). Without: the public answer
  (`enabled`, `url`, `key`, `parts_url`, `assistant`), cacheable.
- `GET /api/admin` (`api/admin.js`): read-only, MASTER_EMAIL only (404 for
  everyone else signed in, 401 signed out): accounts from Supabase's admin API
  with joined and last sign-in, connectors per owner from `relay_tabs`, and
  whether codes are going out under the borrowed sender.
- `admin page` (`web/admin.html`, `web/admin.js`): uses the app's session in
  that browser (renews it and puts the renewed one back), so there is one
  sign-in, in the app. Text only, never markup, for addresses people typed.
- The connector's half is in [web](web.md) (`POST /api/mcp`): hello needs the
  session, records `relay_tabs.owner`, refuses another account's address
  (403), and work goes only to a tab with an owner.
- `Claude's sign-in (OAuth)` (`api/oauth.js`, `api/_oauth.js`,
  `supabase/oauth.sql`; written up with sources in `docs/CONNECTING.md`):
  one connector address for everybody, `https://brickworks.diy/api/mcp`, that
  Claude signs in to as MCP's authorization spec says. Asked with no token the
  relay answers 401 with `WWW-Authenticate: Bearer resource_metadata=…,
  scope="build"`; `/.well-known/oauth-protected-resource[/api/mcp]` names the
  site as the authorization server; `/.well-known/oauth-authorization-server[/…]`
  (issuer = the request's own origin, so a preview is its own issuer) offers
  S256 PKCE only, public clients, Client ID Metadata Documents
  (`client_id_metadata_document_supported`, which is what makes claude.ai use
  `https://claude.ai/oauth/mcp-oauth-client-metadata` and Claude Code
  `…/claude-code-client-metadata` instead of registering) and RFC 7591
  registration at `/oauth/register`. A document client is fetched (https,
  public host, 5 s, 10 KB, no redirects) and kept an hour. Return addresses
  match exactly, except a loopback one may name any port (RFC 8252; Claude Code
  picks one per session). `/oauth/token`: a code (two minutes, once — spent by
  a failed attempt too) with its verifier for a Bearer token (an hour) and a
  refresh token (rotated on use; the old one is answered again within 30 s, a
  retry, and after that ends the whole connection). Tokens and codes are kept
  as SHA-256 only. `/oauth/revoke` (RFC 7009): a refresh token ends its
  connection, an access token itself. The account's own:
  `GET /api/oauth?op=connections` (Bearer session: id, client — "Claude",
  "Claude Code" or what it registered as — since, last used) and
  `POST /api/oauth?op=disconnect[&id=]`. A connection is deleted with its
  account. Issuing tokens tells the account's open tabs
  (`brickworks/connected` on the relay), so the panel says so at once.
- `connect Claude sign-in page` (`web/authorize.html`, `web/authorize.js`,
  served at `/oauth/authorize` with its own security policy and no
  cross-origin isolation headers): checks the request first
  (`/api/oauth?op=check` — an unknown client or an undeclared return address
  is refused on the page; other faults are shown with a link back to the client
  carrying the OAuth error — never forwarded by themselves, since anyone may
  register a return address and an automatic forward would be an open
  redirector);
  uses the app's kept session in that browser if there is one (renewed and put
  back, like the admin page), else the email code (`/api/otp`, redeemed with
  Supabase) and keeps the new session where the app looks, unless the app here
  is signed in as someone else; then one question, naming who asks and the host
  the answer goes back to (with a warning for a loopback program); Allow posts
  `op=approve` with the session and follows the answer back to Claude.
- `share panel` (`src/ui/share_panel.gd`, File › Share… and Share on the
  toolbar, `tool_share`; since 2026-10-12): publishes the open model as the
  signed-in account (`POST /api/share`, [web](web.md)) — its LDraw
  (`ModelStore.to_text`, made parts and prints inside), the name, the name to
  credit only when Show who made it is ticked (offered from the address before
  the @, never sent unticked), and a 1200 x 630 PNG of the model from where the
  view looks, on a light ground (`Picture.take`, 800 x 420 if it would pass
  560 KB). The link comes back with Copy link, Copy embed code, Open and
  Unpublish. It is kept with the model as `0 !BRICKWORKS SHARE <id>` in the
  autosave and saves (`ModelStore.share_id`, `with_share`, `share_in`; never in
  what is published or exported), so publishing the same model again updates
  the same link, and "Publish again" after Unpublish brings it back there. A
  link that is another account's (403) or gone (404) is replaced by a new one;
  New and Clear forget it. Opening the panel asks `?op=mine` whether its link
  is up or taken down. Signed out, it says to sign in.
- `Open in Brickworks` (`main._maybe_copy`, `/app?copy=<id>`): the viewer's
  button. The app as everyone gets it, sign-in screen and all; once somebody
  is signed in and what was on the baseplate is back, the shared model is
  fetched and opened, what was there is saved first if it had unsaved work
  (not the untouched example), the copy waits for its parts and is saved under
  its own name — "Name (copy)" if one of theirs has it — with no link of its
  own, and the address loses its `?copy=` so a reload makes no second copy.
- `sign a machine in` (`src/dev/sign_in.gd`): for a windowed app driven from a
  checkout (`--mcp` and `tools/brick.py`, a look by hand), which opens on the
  sign-in screen like anyone's. Mints the code with the admin API (needs
  `.env`), redeems it as the app does, keeps it where the app keeps its own.

Decisions, so they can be changed: the gate is a client gate (the desktop is
open source and runs on the person's machine); the server enforces accounts
where it serves something — the relay. `/api/account`'s `parts_url` stays open
to everyone, because builds already out ask it and the parts bucket is public
anyway. Sessions last until signed out (Supabase's refresh token); there is no
idle timeout.

## How to reach it

```sh
godot --path .                               # signed out: the sign-in screen
set -a; . ./.env; set +a
node tools/web/relay_server.mjs 8790 &       # the deployment's functions, here
BRICKWORKS_API=http://127.0.0.1:8790 godot --path .    # the app against them
godot --headless --path . --script src/dev/sign_in.gd -- you@example.com
godot --headless --path . --script src/dev/sign_in.gd -- --out
```

## How to check it

Offline, in `tools/check.sh` ("sign-in screen"):

```sh
godot --path . --resolution 1400x900 --script src/dev/gate_probe.gd
```

Proves it when: the screen is up saying it cannot reach Brickworks, with Try
again; a click on the model places nothing and `]` changes no colour; let in,
the same click places a brick and the same key picks the next colour; signed
out, the form is back. Pictures in `shots/signin/`.

Against the real functions and Supabase (needs `.env`; makes throwaway accounts
at `delivered+bw…@resend.dev`, Resend's test addresses, and deletes them):

```sh
set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790 &
BRICKWORKS_API=http://127.0.0.1:8790 godot --headless --path . --script src/dev/account_probe.gd
BRICKWORKS_API=http://127.0.0.1:8790 godot --path . --resolution 1400x900 --script src/dev/gate_probe.gd -- live
godot --headless --path . --script src/dev/connector_probe.gd -- 8790
```

`account_probe` ends "signing in works from the app's side" (26 checks: a
malformed address refused in words, a code sent, a wrong code refused in words,
the minted code signs in, only the refresh token kept, `/api/account` with and
without the token, `/api/admin` 404 to them and 401 to nobody, a restart renews,
offline stays signed in and says so, a session revoked elsewhere is refused and
forgotten, the sixth code in a row refused). `gate_probe -- live` types the
address, presses Email me a code, types a wrong code then the minted one, signs
in, opens Account and signs out, with pictures `shots/signin/1_form.png` to
`6_signed_out.png`. `connector_probe` covers the relay's half.

Claude's sign-in, every endpoint as claude.ai and Claude Code use it, and every
refusal (same server; a throwaway account, deleted at the end; about 90 s, 31 of
them waiting out the refresh grace):

```sh
node tools/web/oauth_probe.mjs --url=http://127.0.0.1:8790
BW_BYPASS=$VERCEL_BYPASS node tools/web/oauth_probe.mjs --url=<deployment>
```

Proves it when it ends "Claude can sign in to Brickworks, and nothing else can"
(60 checks, 62 on a deployment): the 401 and its pointer, both metadata documents and their path
variants, `/oauth/authorize` serving the page (on a deployment: no COOP, not
frameable); Claude by its published document — told "Claude, claude.ai", no code
without a session, a code with state and `iss`, a wrong verifier refused and the
code spent by it, another `redirect_uri` refused, tokens form-encoded, a code
twice refused; the token at the MCP address (initialize, the app's tool list
with no tab, a call told no tab is open, a made-up token 401 `invalid_token`); a
call routed to this account's tab and not another account's; refresh rotation,
a retry inside the grace, another client's refresh refused; Claude Code on a
random loopback port, an undeclared path refused; registration and what it
refuses (`javascript:`, plain http elsewhere, a fragment, none), no PKCE and
`plain` sent back `invalid_request`, another resource `invalid_target`, an
unknown client refused, a secret client refused without its secret and served
with it; Cancel `access_denied`; the connections listed for the account only;
revocation ending a connection; Disconnect ending the rest at once; a refresh
token replayed after the grace ending its connection.

The whole of it in a real browser, on a deployment (a throwaway account, deleted
at the end; one email to a Resend test address; about four minutes):

```sh
BW_BYPASS=$VERCEL_BYPASS node tools/web/oauth_flow.mjs --url=<deployment>/app --out=shots/oauth
```

Proves it when it ends "connecting Claude works on this deployment": Connect
Claude opens exactly claude.ai's install link with the deployment's address and
puts the address on the clipboard, and the panel waits; then, as claude.ai: the
401 and its metadata, Brickworks' page in the same browser already signed in
(the app's session) asking once and naming claude.ai, Allow arriving at
claude.ai's callback (stood in for; nothing reaches claude.ai) with code, state
and `iss`, tokens; the panel saying "Connected to Claude" by itself and Connect
giving way to Disconnect; initialize, the tool list and a search answered by the
tab, and a design built with the tab's frames stopped (out of view); then a
second browser not signed in — address, Email me a code (really sent), a wrong
code refused, the minted code, the question, Allow, its session kept — whose
token builds in the first browser's tab; Account listing the connection and
Disconnect Claude refusing both tokens at once. Pictures `1_before_connect.png`
to `10_disconnected.png`.

On a deployment, in a real browser (needs `.env` sourced; `BW_BYPASS` for a
preview):

```sh
BW_BYPASS=$VERCEL_BYPASS node tools/web/account_flow.mjs --url=<deployment>/app --out=shots/account
```

Proves it when it ends "signing in works on this deployment": the screen on a
first visit with only the form pressable, clicks and keys changing nothing
behind it, an address that is not one held back, Email me a code moving on (the
deployment really sends it, to a Resend test address), a wrong code refused, the
minted code signing in, the session kept in the browser, a reload still signed
in, `/admin` refusing the account, Account then Sign out bringing the
screen back with the session gone, and no security-policy refusals. `--master`
also signs the owner's account in (no email sent) and checks the admin page
lists the accounts.

Every other browser flow here starts signed in: `tools/web/browser.mjs` mints a
session of the test account (`delivered+brickworks-tests@resend.dev`,
`BW_TEST_EMAIL` for another) per context and puts it where the app keeps one,
once, so a reload finds the renewed one. Without `.env` sourced the pages start
signed out and say so.

## Gotchas

- **Never ask `/api/otp` for a real person's address as a check.** It emails
  them. Use `delivered+…@resend.dev`.
- **Mail goes out from the borrowed sender** until brickworks.diy is verified
  at Resend: `EMAIL_FROM` is refused with 403 and `EMAIL_FROM_FALLBACK` (another
  product's domain) is used. Verifying needs a Resend key with domain access
  and DNS records at the registrar, both the owner's; the key in `.env` is
  send-only. The admin page says when this is happening.
- **Minting a code replaces the one emailed.** `generate_link` leaves one
  live code per address, so a test that presses Email me a code and then mints
  must type the minted one.
- **A refresh token works once.** Renewing replaces it, and after about ten
  seconds the old one is refused (and may end the session). Two runs renewing
  the same kept session end it; that is why probes and command-line runs do not
  keep one (`Account.keeps`), and why a browser test's injected session is put
  in only when the browser has none.
- **The session is in `localStorage` on the web, not `user://`.** A `user://`
  write reaches the browser's storage only seconds later (see
  `ModelStore.stored`), and a reload in between lost the sign-in.
- **A preview's `check.mjs` sends the bypass as a header on every request**,
  Supabase's included. Measured 2026-10-11: renewal still works under it
  (`signed_in`, not `offline`, no failed requests). If renewing ever fails
  only on previews, look there first.
