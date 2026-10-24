# Account

Everyone who uses Brickworks signs in, on the web and the desktop, with an
email address and a code sent to it. Nothing in the builder can be used until
they have. A Claude connector belongs to the account that switched it on.

<!-- covers: ui:sign-in screen, lib:account session, ui:account panel, api:POST /api/otp, api:GET /api/admin, ui:admin page, cli:sign a machine in, cli:account browser flow, api:Claude's OAuth sign-in, ui:connect Claude sign-in page, cli:oauth probe, cli:connect Claude browser flow, ui:share panel, api:POST /api/account?op=age, api:POST /api/orangecheck, ui:sign in with orangecheck, cli:orangecheck check, cli:orangecheck browser flow, cli:signup check, api:GET /api/otp/canary, cli:canary check -->

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
  (`accounts_url`, `accounts_key`, from `/api/account`), and where the parts
  the build does not ship live (`parts_url`). An ask that goes unanswered in a
  way that may pass (a timeout, a cut connection, a 5xx) is asked again after
  2, 6 and 12 s before `settled`: asked once until 2026-10-20, a phone whose
  start-up outlasted the 20 s timeout fetched no such part all visit
  (`fetch_retry_probe`'s last part).
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
  `master` (cache `private, no-store`), and `age: {ask, over_13}` once
  `supabase/trust.sql` is applied (left out before, and when the database
  cannot be asked). Without: the public answer (`enabled`, `url`, `key`,
  `parts_url`, `assistant`), cacheable.
- `POST /api/account?op=age` (2026-10-18, Bearer, `{month, year}`): the age
  question's answer. 422 for a month or year that is not one (or not come
  yet), 503 before trust.sql; otherwise `{age}`. Turned into 13-or-over in
  `api/_trust.js` (a birthday this month counts as had) and let go: only
  `profiles.over_13` and `age_asked_at` are kept, never the date. An answer
  stands — a second try returns the first — except that an under-13 answer
  is asked again a year on. See [web](web.md) for what it refuses.
- `GET` and `POST /api/account?op=theme` (2026-10-22, Bearer): the site's
  theme on the account (`profiles.theme`, `supabase/theme.sql`). GET
  `{theme: system|light|dark, chosen, ready}`; POST `{theme}` answers
  `{theme, kept}`, 422 for anything else. Before theme.sql (PostgREST 400
  for the column) GET says `system`, `ready: false`, and POST `kept: false`:
  never an error. See [web](web.md) "theme choice".
- `the age question in the sign-in screen` (`src/ui/sign_in_gate.gd`,
  `Account.age_ask`, `over_13`, `asking_who`, `answer_age`): after a code is
  typed the screen stays up ("Signing you in…") for `/api/account`; a start
  with a kept session lets them in at once and puts the screen back up only
  to ask (an account from before the question, once). When it says
  `ask`, "One question first: When were you born?", twelve month buttons
  (`age_month_1`…`12`), the year (`age_year`), Carry on (`age_go`), and "The
  date itself is not kept." The site's own dialog (web/account.js) asks it
  with two dropdowns side by side, Month by name and Year newest first,
  drawn as its text boxes are. Under 13, the screen then says what is open and
  what is for 13 and over, and Start building (`age_done`) lets them in.
  `window.brickworksAccount` adds `age_ask` and `over_13`. Not asked offline
  or by a deployment that does not say `ask`.
- `GET /api/admin` (`api/admin.js`): MASTER_EMAIL only (404 for everyone
  else signed in, 401 signed out): accounts from Supabase's admin API with
  joined and last sign-in, connectors per owner from `relay_tabs`, whether
  codes are going out under the borrowed sender, and `gallery`: every listed,
  published model (id, name, credit, parts, when listed, its account's
  address). Its one write (2026-10-13): `POST ?op=unlist&id=` takes a model
  out of the gallery and bars it (`listed` off, `barred` on; 404 for no such
  link, 400 for no id) — its link goes on working, and its owner cannot list
  it again ([web](web.md)). Since the directory's moderation (2026-10-13,
  `supabase/moderation.sql`): unlist also keeps the file's fingerprint
  (`barred_models`, `modelHash`), so the same model listed again at any link,
  by anybody, is refused 409, and settles its reports; `POST ?op=bar&id=`
  (a model's account) or `&account=` takes an account out whole
  (`barred_accounts`, its listed models unlisted and barred with their files,
  its profile and public lists gone, its reports settled, anything it lists
  refused 409); `?op=unbar&account=` lets it list again; `?op=dismiss&report=`
  lets a report go. The GET also answers `reports` (open, newest first, each
  with what it is about, its reason, note and contact, and the model's
  account's address; never who reported) and `barred` (account, when, why,
  address).
- `admin page` (`web/admin.html`, `web/admin.js`): uses the app's session in
  that browser (renews it and puts the renewed one back), so there is one
  sign-in, in the app. Text only, never markup, for addresses people typed and
  names they chose. In the gallery: the listed models, each a link to its page,
  with Take out (asks first, then `?op=unlist` and the page again). Above it,
  Reported: each open report with a link to what it is about, why, what was
  said, the way to reach them and the account, and Take out, Take out the
  account (each asking first) and Let it go; and Accounts taken out, each with
  Let back in. Proven by the moderation browser flow ([web](web.md)).
- The connector's half is in [web](web.md) (`POST /api/mcp`): hello needs the
  session, records `relay_tabs.owner`, refuses another account's address
  (403), and work goes only to a tab with an owner.
- `Claude's OAuth sign-in` (`api/oauth.js`, `api/_oauth.js`,
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
  "Claude Code" or what it registered as — since, last used — and `before`:
  whether the account has had Claude connected, kept in its server-only record,
  Supabase's `app_metadata.claude_connected_at`, written when claude.ai's client
  connects and when Disconnect ends one, so it outlives the Disconnect) and
  `POST /api/oauth?op=disconnect[&id=]`. A connection is deleted with its
  account. **Asked once** (2026-10-14): `POST /api/oauth?op=remembered` (Bearer
  session, the request's fields) answers with a code at once when the account
  still holds a connection (`oauth_grants`) to that same client — by its id,
  never its name — at the same return address, for this server; otherwise
  `{ask: true}`. A loopback client is remembered at the port it was allowed on.
  Disconnect, a revocation and a replayed refresh token delete the connection,
  so the next one asks again. Issuing tokens tells the account's open tabs
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
  `op=approve` with the session and follows the answer back to Claude. Signed
  in (either way), the page first asks `op=remembered`, and an account already
  connected to that app goes straight back with its code, asked nothing ("You
  allowed Claude before…").
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
  is up or taken down. Signed out, it says to sign in. **List it in the
  gallery** (`share_list`, 2026-10-13): off for a model with no link, set from
  `?op=mine` for one with (so updating a listed link does not unlist it), and
  disabled with a word when Brickworks took the model out; sent as `listed`
  on every publish, and the status says when it is listed. A model copied with
  Open in Brickworks sends `remixed_from`. Beside Publish (2026-10-18):
  "Publishing means you agree to the guidelines" (`share_guidelines`, opens
  `/guidelines` on the deployment). For an account under 13 List it in the
  gallery and Show who made it are off, with a line why; `page_state` says
  `list_disabled`, `credit_disabled`, `young` and `guidelines`.
- `Open in Brickworks` (`main._maybe_copy`, `/app?copy=<id>`): the viewer's
  button. The app as everyone gets it, sign-in screen and all; once somebody
  is signed in and what was on the baseplate is back, the shared model is
  fetched and opened, what was there is saved first if it had unsaved work
  (not the untouched example), the copy waits for its parts and is saved under
  its own name — "Name (copy)" if one of theirs has it — with no link of its
  own, and the address loses its `?copy=` so a reload makes no second copy.
  It knows the link it came from (`ModelStore.remixed_from`, kept in its
  saves as `0 !BRICKWORKS REMIX <id>`), so shared, its page says what it was
  remixed from.
- `sign a machine in` (`src/dev/sign_in.gd`): for a windowed app driven from a
  checkout (`--mcp` and `tools/brick.py`, a look by hand), which opens on the
  sign-in screen like anyone's. Mints the code with the admin API (needs
  `.env`), redeems it as the app does, keeps it where the app keeps its own.
- `signup check` (`tools/web/signup_check.mjs`, 2026-10-23): every account is
  made on the server, by the admin users API (`api/otp.js`, then its code by
  the admin `generate_link`, orangecheck's sign-in and the test sessions), so Supabase's own
  public sign-up must be off and "Confirm email" on: `disable_signup: true`,
  `mailer_autoconfirm: false`, with anonymous, phone and every other provider
  off. Measured open on 2026-10-23 (`false`, `true`): a password sign-up at an
  unused address came back confirmed with a session `/api/account` took as
  signed in. Nothing here can change it (the dashboard, or a Management API
  token, which `.env` does not hold): orangecheck's session turned both, and
  TOTP enrolment off, on 2026-10-24 ~09:55Z.
- `sign-in canary` (`GET /api/otp/canary`, `api/_canary.js`, 2026-10-24):
  Vercel's cron, daily at 04:47 UTC with `CRON_SECRET` (`tools/deploy.sh`
  writes it beside the sweep's), holds those settings by behaviour, at
  Resend test addresses: (a) a public sign-up refused `signup_disabled`, no
  account left; (b) an account the admin API made unconfirmed: its password
  refused `email_not_confirmed`, the public `/otp` (which would sign it up
  again and confirm it) `signup_disabled`, still unconfirmed; (c) a new
  address given a code by `api/otp.js`'s own `mint` and `deliver` (exported
  for it), redeemed, the session taken by `api/_auth.js` `verify` (amr
  `otp`), TOTP enrolment refused `mfa_totp_enroll_not_enabled`. Each judged
  by Supabase's own error code, so a trigger refusing the same call cannot
  pass for the setting. And (d), orangecheck Connect's key works:
  `connectDelete` for a made-up user id (`canary-<ms>-<hex>`) answers
  `unknown_user` (an `invalid_api_key`, an outage or no key where the signing
  secret is fails it; a deployment with neither orangecheck key, a unit's
  preview or a checkout, skips it and says so), since without the key a
  Connect account's deletion is paused. Its accounts deleted whatever happens, a cut-off
  run's at the next start (`delivered+canary-[abc]-<ms>-<hex>@resend.dev`
  only). 200 or 500; each run a row of `canary_runs` (`supabase/canary.sql`,
  server only); a failed run mails `MASTER_EMAIL` once, naming each failed
  check and what came back (`skipped: no RESEND_API_KEY here` on a unit's
  preview). `mailer_autoconfirm` alone cannot be seen while sign-up is off:
  (b)'s `/otp` is where it would act. `canary check`
  (`tools/web/canary_check.mjs`) runs the same from a checkout.

- `sign in with orangecheck` (2026-10-23; `api/orangecheck.js` POST
  `?op=signin`, `api/_oc.js`, `web/account.js` `orangecheckButton` and
  `exchangeOrangecheck`, `supabase/orangecheck.sql`): the site's sign-in
  dialog has **Sign in with orangecheck** under the email code ("A Bitcoin
  wallet, email, Google or GitHub. Brickworks gets an id for you, not your
  address."). Since step 4 (2026-10-24, oc225) every such button (the
  dialog's, /settings' Link orangecheck, an orangecheck account's delete) is
  our own `.cta.ghost` with `data-oc-sign-in`, made orangecheck's by its own
  code: its mono mark, its busy state, its window opened from the click, and
  how the window ended said in its words (`OUTCOME_COPY`). That code is
  me-client 0.48.0's, served from here (`web/oc-button.mjs`,
  `web/oc-button.css`, `web/oc-connect-consent.mjs`, made by
  `tools/web/vendor_orangecheck.sh` with the server's checks in
  `api/_orangecheck.js`); the token it hands back is checked (`checkOcToken`;
  audience from configuration: brickworks.diy alone in production, a Preview
  deployment's own `VERCEL_URL`, or a loopback `OC_AUDIENCE` on this machine;
  orangecheck's keys unreadable is 503; `rh` required; the project's rule,
  `{min_sats, min_days}`; the list of ended
  sessions, which must be readable), spent once (`oc_spend`), and exchanged
  for a Supabase session minted with the admin API (the account marked first
  if it is not), bound to the token's `rh`, `aud` and `iat` (`oc_sessions`)
  before it is handed out, and only while the did is still the account's
  (else the session is ended, 409); the token is then
  ended at orangecheck. A new did is a new account, address 32 random hex
  `@oc.brickworks.diy` (never derived from the did), `app_metadata.orangecheck`
  true, keyed in `oc_identities`. That address gets no code (`/api/otp` 422)
  and no digest (`_comments.js`), is never shown (`/settings` says "Signed in
  with orangecheck", hides the email choices), and the account is deleted
  with a fresh orangecheck sign-in as itself instead of the typed address.
  Needs `OC_PROJECT_KEY` and `OC_SIGNING_SECRET` (Vercel: the secret in
  Production alone); without either nobody signs in with orangecheck, and
  where the deployment has no signing secret (a unit's preview) the button is
  drawn and a sign-in says it is unavailable; production without both takes
  no token, and says so in its log at every start. Offered to everybody, on
  every page and in the app's sign-in screen:
  `ORANGECHECK_FOR_EVERYONE` in `api/_oc_config.js` is the one switch (step 1
  alone kept it to a tab opened with `?oc=1`, a flag oc205 removed), told to
  pages and the app by `/api/account` as `orangecheck: {ready, everyone}`.
  Where the docs fell short, and orangecheck's review and its fixes:
  `docs/ORANGECHECK.md`. In the web
  app the sign-in screen has **Sign in with orangecheck** too
  (`signin_orangecheck`, `src/ui/sign_in_form.gd`, web only): it goes to
  `/profile?then=/app…`, which opens the dialog by itself and, signed in,
  goes back (`web/profile.js`; only ever to `/app`). Linking from
  `/settings` (`GET ?op=status`, `POST ?op=link`, `?op=unlink`) asks for a
  code emailed in the last five minutes (`amr` `otp`; a password only for a
  `@resend.dev` test account), never a session orangecheck started
  (`api/_oc.js` `codeOf`); so does deleting an account with its own email
  from a session orangecheck started (403 `fresh: false`, and /settings
  asks for the code in the delete form); the address is told; unlinking
  ends that id's sessions, the Claude connections it approved and their
  codes not yet exchanged. Each authenticated request of an account
  marked `app_metadata.orangecheck`, or at a made-up address, asks
  `oc_session_of` (held 5 s): a gone session is refused, and one
  orangecheck started is refused and deleted once ended everywhere or once
  its did is no longer the account's, and reads but does not write while
  orangecheck cannot be asked; a made-up address's session orangecheck did
  not start is refused and deleted (`api/_auth.js` → `api/_oc.js`
  `sessionStanding`). Any session signed in by password, but a test
  account's, is refused (403) and deleted (`api/_auth.js`), and Supabase
  refuses setting a password on any account but a `@resend.dev` test
  account's, and any change of address (`supabase/no_new_ways_in.sql`, a
  trigger on `auth.users`; its dry run `tools/no_new_ways_in_try.sql`), a
  sign-in by password on such an account (`auth.mfa_amr_claims`), and any
  second factor; and the account a public sign-up makes (its user data says
  `phone_verified`; refused as it commits) until
  `supabase/drop_no_public_sign_up.sql`, since sign-up is off and the canary
  holds it. The keys a
  page holds reach nothing in the database (`supabase/no_client_access.sql`,
  then `no_client_access_models.sql` once oc205's release is live; read by
  `supabase/client_exposure.sql`); `api/otp.js` makes a new person's account
  through the admin API, then asks `generate_link` for its code, so it needs
  no public sign-up (`signup check` holds that it is off). A connection approved in one carries its `rh`
  (`oauth_grants.oc_*`), and its code is refused once the did is unlinked. Site pages send
  `Cross-Origin-Opener-Policy: same-origin-allow-popups` so the window can
  answer; `/app` and `/b/` keep `same-origin`. In the app the button carries
  orangecheck's mark (`assets/ui/orangecheck-mark-mono-white.svg`, mark
  0.3.0) and a 44 px target.
- `orangecheck account merge` (2026-10-24, oc225; `api/_oc.js` `merged`,
  `keepHandle`, `supabase/orangecheck_merge_connect.sql`): every token's
  `rh` is kept with its did (`oc_handles`, gone with the did, moved with
  it). A did new here whose token carries `merged_rh` (me-client 0.45.0
  `matchMergedUser`) signs in to the one account those handles name: the
  account's did becomes the new one, what the old did started there ends,
  its address is told; handles naming two accounts sign in to neither and
  make nothing (409, in words); an unlinked did's handles name nobody.
- `orangecheck Connect` (2026-10-24, oc225; `api/orangecheck.js` POST
  `?op=connect`, `api/_oc.js` `provision`/`unprovision`, `oc_connected`):
  under the dialog's orangecheck button, an unticked box with
  orangecheck's exact words (`CONNECT_CONSENT_LABEL`, `_BLURB`), drawn where
  `/api/account` says `orangecheck.connect` (the deployment has
  `OC_CONNECT_KEY`; a unit's preview never does). Ticked, a sign-in by
  emailed code then asks, never waited on: the server, for a fresh code's
  session of an account without orangecheck, writes the ask down and calls
  `connectProvision({consent: true})`, with `email` and `emailVerified: true`
  only when that session is a fresh emailed code's (amr `otp`) for that
  address (`codeOf` `emailed`); a refusal or an outage is an
  answer, never in the sign-in's way. Unticked, nothing is asked. Deleting
  an account Connect was asked for calls `connectDelete` first (`unprovision`).
  A person can always delete their account (site-attest's L1): orangecheck
  refusing for good (`holds_earnings`, `not_deletable`) deletes ours anyway
  and the answer says theirs stays at ochk.app (`orangecheck: {kept, said}`,
  shown on /settings); an outage (`unavailable`, `rate_limited`) holds it,
  503 "try again"; no Connect key (a unit's preview; nothing asked) or a key
  orangecheck does not know holds it too, Brickworks' setup fault
  (orangecheck's final ruling): 503 "Deleting is paused while Brickworks
  fixes a setup problem. Nothing has been deleted." The canary's (d) hears
  of that by the next morning. An account that never ticked the box asks
  orangecheck nothing, and is deleted whatever Connect's state.

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
out, the form is back, and drawn as a browser draws it, Sign in with
orangecheck under the email with orangecheck's mark, 2:1 at the screen's
pixels, and a 44 px target (`orangecheck.png`). Pictures in `shots/signin/`.

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

Sign in with orangecheck, the server against the real database with only
orangecheck stood in for (tokens signed here with a key served as ochk.io's;
its rule and list answered here; every account it makes deleted after; about
40 s; Supabase limits redemptions per address, so give it five minutes
between runs):

```sh
set -a; . ./.env; set +a; node tools/web/orangecheck_check.mjs
BW_BYPASS=$VERCEL_BYPASS node tools/web/oc_flow.mjs --url=<deployment> --out=shots/oc
```

`orangecheck_check` ends "N passed, 0 failed" (133 since step 4; a sign-in
turned away by Supabase's redemption limit is tried again after 11 s. A
first sign-in is a new
account at a random address whose session `/api/account` takes; the token
ended at orangecheck and never in the answer; refused a second time, here and
on another instance; the same did is the same account; no `rh`, another
audience, none, another key, another issuer, expired, no or a malformed did,
nothing, junk and `alg: none` all refused in words; a session ended
everywhere refused, one started after the cutoff let in; no list, no rule, no
secret or no audience: nobody signs in; a backed-only rule refuses an unbacked
account with `back_url`; two first sign-ins at once make one account and
leave none over; three at once all get in; an orangecheck account is not
deleted by its made-up address or somebody else's sign-in, is by a fresh one of
its own, which is then spent, and signing in again makes a new one; linking
from an email account (told, marked, a second id or another's refused), the
linked id signing in to it, a session orangecheck started never fresh enough
to unlink, reading but not writing while the list is down, ended everywhere
and not renewable while the email session goes on, unlinking ending what the
id started, an orangecheck account unable to link or unlink, a Claude
connection it approved waiting while the list is down and ended with it;
orangecheck's review, each failing case: a password set from an
orangecheck sign-in refused at Supabase, none signing in, the account's
other session not signed out, an address change refused, both sessions 401
after Sign out everywhere, and the same refusal for an account with its own
email (H1); a new person signing in by a code asked for twice, again, and a
test account by its password, as before; the catalogue holding nothing in
public for anon, authenticated or PUBLIC (`client_exposure()`), and PostgREST
refusing every table and function to an emailed-code session and to anon
(N1); a public sign-up with a password giving `/api` no session (N2; that
Supabase refuses it, and that sign-up is off, is `signup check`'s); a second
factor refused; a new person signing in by a code from `api/otp.js` itself
(its mail caught, never sent), as Supabase is now and with `generate_link`
making no account, as once sign-up is off; an
unlink racing a sign-in leaves no session (409), and a binding whose did
is gone is ended (M1); an unmarked account's session carries the mark
(L1); a code approved in an orangecheck sign-in refused once its did is
not the owner's, and deleted by unlinking (L2); deleting from an
orangecheck sign-in asks for a fresh code (L4); production's one audience;
keys unreadable 503; a `{min_sats, min_days}` rule letting a backed account
in; `/api/account`'s offer; twenty tries from one address, the next 429;
step 4: a sign-in's handle kept, a merged did signing in to the account
the old one had and only that, the old did's session ended, handles naming
nobody or two accounts, more than 16, a linked then unlinked did; Connect
without its key, unticked or not `true`, without a sign-in, ticked once with
consent and the key, orangecheck down or never answering, never for an
account with orangecheck, deletion held while orangecheck is down and
calling `connectDelete` when it can, deleted anyway with orangecheck's kept
said when it refuses for good (`holds_earnings`, `not_deletable`), paused
(503, in its words, nothing deleted) without the key (no call) or with a key
orangecheck does not know, and an account that never ticked the box deleted
with orangecheck down or no key, 0 calls; a stale code's session refused 403 with no call at all; the address sent as verified for a fresh emailed code's
session, and never for a password's, an address the request names, a code's
past five minutes or an orangecheck session's).
`oc_flow` (a preview check, `oc`) needs no orangecheck account: drawn
for everybody with nothing on the address, the dialog at 390 and 1280 in
both themes with orangecheck's button (its mark, its stylesheet from this
origin, the height and type of Email me a code) and the Connect box under it,
unticked, in orangecheck's words; the window opened at me.ochk.io and closed
(said in orangecheck's words), a blocked one too, or on a unit's preview (no
signing secret) the button saying it is unavailable, the files served, the
headers, the server's refusals, Link orangecheck on /settings orangecheck's
button; then Connect with orangecheck's side stood in for in the browser on
every deployment: unticked no ask, ticked one with consent, a failed ask
still signed in, and an account Connect was asked for deleted only once
orangecheck has answered (on a unit's preview, with no key, paused: 503,
nothing deleted).
A finished sign-in through orangecheck's real window, and Connect for real
(`--connect` alone), run only on brickworks.diy (`tools/web/oc_live_flow.mjs`).

Claude's sign-in, every endpoint as claude.ai and Claude Code use it, and every
refusal (same server; a throwaway account, deleted at the end; about 90 s, 31 of
them waiting out the refresh grace):

```sh
node tools/web/oauth_probe.mjs --url=http://127.0.0.1:8790
BW_BYPASS=$VERCEL_BYPASS node tools/web/oauth_probe.mjs --url=<deployment>
```

Proves it when it ends "Claude can sign in to Brickworks, and nothing else can"
(72 checks, 74 on a deployment): the 401 and its pointer, both metadata documents and their path
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
with it; Cancel `access_denied`; a second connection from the same account
(`op=remembered`) given a code at once that trades for tokens, while nobody
signed in gets 401, another account, a client registered as "Claude" at
Claude's return address, and Claude Code on another port are asked; the
connections listed for the account only, `before` false for a new account and
another; revocation ending a connection and what was allowed with it;
Disconnect ending the rest at once, and the next connection asked again, with
`before` still true and kept beside the record's own `provider`; a refresh token replayed after the grace ending its
connection.

That nobody can make an account at an address they cannot read (Supabase
itself, so any deployment; a few seconds; throwaway accounts at Resend test
addresses, deleted and checked gone):

```sh
node tools/web/signup_check.mjs --url=https://brickworks.diy
```

Proves it when it ends "all ok" (14 checks, 16 with `--url`): the public
settings say sign-up off, confirmation on, no way in but email; a password
sign-up, the public `/otp` asked to make an account, an anonymous and a wallet sign-in
each refused with no account left; and still a first sign-in by a minted code
(taken as signed in and asked its age), a returning one reaching the same
account, and an admin-made account signing in by its password.

The sign-in canary, the cron's three checks (Supabase itself; ~5 s from here,
~10 s more with `--route`; throwaway accounts at Resend test addresses,
deleted; one code mailed to one, through Resend where the key is):

```sh
node tools/web/canary_check.mjs --url=https://brickworks.diy           # from here, and the site asked of (c)'s session
node tools/web/canary_check.mjs --url=<deployment> --route             # and the deployment's own run (preview check canary)
node tools/web/canary_check.mjs --stand-in                             # the canary itself, no network
```

Proves it when it ends "all ok" (13 checks, 14 with `--url`, 29 with `--route`): (a), (b)
and (c) as above, each step's answer in brackets, and no canary account left
in Supabase; with `--route` the route refusing a call without the secret, the
deployment's run all held and recorded, and how its mail went. `--stand-in`
(57 checks) runs the route against `tools/web/canary_stand_in.mjs`, a
Supabase and Resend in memory: sign-up open fails (a) and (b), an unconfirmed
password signing in (b), the code refused and TOTP on (c), an undeletable
account `gone`, Connect not knowing the key (d), with one ask of Connect for a
made-up user each run, all at once with Resend down and the record unwritable (a),
(b), (c); each the owner's mail attempted once naming each failed step and
what it got (caught), the run recorded; right, it passes with no mail, and a
cut-off run's account is deleted while another run's and one only named
alike are not. The last runs: `select at, ok, host, mailed, checks from
public.canary_runs order by at desc limit 7`.

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
tab, and a design built with the tab's frames stopped (out of view); claude.ai
connecting again sent straight back with a code, the question not put (this
account allowed it already), and that code traded; then a second browser not
signed in — address, Email me a code (really sent), a wrong code refused, the
minted code, and nothing more asked — whose token builds in the first
browser's tab; Account listing the connection and Disconnect Claude refusing
all three tokens at once; Connect Claude then opening Claude's connectors
(`https://claude.ai/customize/connectors`), not Add custom connector, the
account having had Claude; then claude.ai connecting after that asked the
question again, and Allow connecting it. Pictures `1_before_connect.png` to
`11_asked_again.png`.

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

`account_flow` (in the app) and `people_flow` (on the site) answer the age question
13 or over when it is asked (once
`supabase/trust.sql` is applied). `tools/web/session.mjs` `mintSession` answers
it 13 or over for every account it signs in but `MASTER_EMAIL`'s (in the
database, and in a local stand-in named by `BW_STAND_IN`), so flows that list
or make a profile are not stopped by it; `{ age: false }` leaves it to be
asked, as `age_flow` does.

Every other browser flow here starts signed in: `tools/web/browser.mjs` mints a
session of the test account (`delivered+brickworks-tests@resend.dev`,
`BW_TEST_EMAIL` for another) per context and puts it where the app keeps one,
once, so a reload finds the renewed one. Without `.env` sourced the pages start
signed out and say so.

`mintSession` signs a Resend test address in by password, not by a code
(2026-10-23): the account made by the admin API with a password worked out from
`SUPABASE_SECRET_KEY`, then `/auth/v1/token?grant_type=password`, which counts
against the token limit (shared with renewals) rather than verify's (30 in five
minutes, which m156's battery spent). An address that has an account made some
other way (by a code, or by the dialog earlier in the flow) and every other
address, `MASTER_EMAIL`'s above all, is still signed in by its code, and no
password is put on it. On a 429 it waits and asks again, about two minutes in
all, saying so. The flows about the sign-in itself (`account_flow`,
`people_flow`'s visitor, `first_steps`' dialog, `oauth_flow`'s authorize page)
type a minted code (`mintCode`) and so still drive the real `/auth/v1/verify`.

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
