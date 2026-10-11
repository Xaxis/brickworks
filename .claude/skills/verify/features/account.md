# Account

Everyone who uses Brickworks signs in, on the web and the desktop, with an
email address and a code sent to it. Nothing in the builder can be used until
they have. A Claude connector belongs to the account that switched it on.

<!-- covers: ui:sign-in screen, lib:account session, ui:account panel, api:POST /api/otp, api:GET /api/admin, ui:admin page, cli:sign a machine in, cli:account browser flow -->

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
  account holds, Sign out (which switches the tab's connector off first), and
  for the owner on the web a link to the admin page. Its tooltip on the bar
  names the address.
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
in, `/admin.html` refusing the account, Account then Sign out bringing the
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
