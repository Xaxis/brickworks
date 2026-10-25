# Signing in with orangecheck

Brickworks signs people in with orangecheck beside the emailed code
(2026-10-23, unit oc188). The code is api/orangecheck.js, api/_oc.js and
api/_oc_config.js, the sign-in dialog in web/account.js, and
supabase/orangecheck.sql. The recipe and every check are in
.claude/skills/verify/features/account.md.

It was built from orangecheck's public docs alone (ochk.io/docs and the
oc-docs pages it links, as they stood on 2026-10-23), never from its
packages' source. These are the places the docs fell short (missing, wrong
or unclear) and what was done instead. Each one is a doc bug to fix on
orangecheck's side.

Step 1 of orangecheck's brief was sign-in alone, offered only to a tab
opened with `?oc=1` and to test accounts. Steps 2-3 (linking from
Settings, and ending a session when somebody signs out of orangecheck
everywhere) turn it on for everybody (`ORANGECHECK_FOR_EVERYONE` in
api/_oc_config.js). orangecheck reviewed all three adversarially; unit
oc205 fixed every finding (below), dropped the `?oc=1` flag, and the three
ship together with the button on every page and in the app's sign-in
screen.

## Step 4: the button, Connect, merged accounts (2026-10-24, oc225)

The owner said yes to step 4. orangecheck named the versions: me-client
0.48.0 (auth-core 2.18.0 with it) and mark 0.3.0, vendored by
tools/web/vendor_orangecheck.sh.

- **The button.** Every place we offer orangecheck (the sign-in dialog,
  /settings' Link orangecheck, an orangecheck account's delete) is our
  own `.cta.ghost` with `data-oc-sign-in`, made orangecheck's by
  `enhanceSignInButton` (`web/oc-button.mjs` and `web/oc-button.css`,
  copied from the package onto our origin, so `script-src 'self'` holds):
  its mono mark, its busy state, the window opened inside the click. How
  the window ended is said in its words (`OUTCOME_COPY`): a closed window
  now says so, where it said nothing. It replaces our own popup call
  (`web/oc-popup.mjs` is gone); the exchange, `?op=signin`, is as it was.
  In the app, the button carries the mark (mono, white, as its words are)
  and a 44 px target; nothing else in the app changed.
- **Connect.** Under the dialog's button, an unticked box in orangecheck's
  words (`web/oc-connect-consent.mjs`). Ticked, a sign-in by emailed code
  then asks `?op=connect`, never waited on; the server writes the ask down
  (`oc_connected`) and calls `connectProvision({consent: true})` with the
  account's id, for a fresh code's session of an account with no
  orangecheck of its own. Unticked, no call. Deleting the account calls
  `connectDelete` first. A person can always delete their Brickworks
  account (site-attest's L1): when orangecheck refuses for good
  (`holds_earnings`, `not_deletable`) ours is deleted anyway and they are
  told theirs stays at ochk.app. That is an allow-list in our own
  `unprovision`, whatever me-client makes of an answer (site-attest): the
  account goes only on `unknown_user`, `deleted`, `detached`,
  `already_deleted`, `holds_earnings` or `not_deletable`. An outage
  (`unavailable`, `rate_limited`, a network failure, a throw) holds it, 503,
  try again. Anything else (no key, so no call; `invalid_api_key`;
  `bad_request`; an answer not named) is our setup fault, and deleting
  would leave their orangecheck account behind, so it is paused, 503,
  "Deleting is paused while Brickworks fixes a setup problem. Nothing has
  been deleted." (orangecheck's final ruling). The daily
  canary's (d) asks `connectDelete` for a made-up user and wants
  `unknown_user`, so a key gone or replaced is heard of by morning. An
  account that never ticked the box never asks, and is always deleted.
  `OC_CONNECT_KEY` is withheld from a unit's preview (tools/deploy.sh).
  So that the person can claim it, orangecheck asked (2026-10-24) for
  `email` with `emailVerified: true`, but only when the same request carries
  a fresh Brickworks code's session (amr `otp`, the five minutes linking
  asks) for that very address (`api/_oc.js` `codeOf`, `emailed`): never a
  password's, an orangecheck session's, a stale code's, or an address the
  request names, which is never read.
- **Merged accounts.** Every token's `rh` is kept with its did
  (`oc_handles`). A did new here whose token carries `merged_rh` signs in
  to the one account those handles name (`matchMergedUser`, then
  `oc_follow_merge`: the account's did becomes the new one, its address is
  told, what the old did started there ends); two accounts named, neither,
  and nothing is made.

What changed for us between 0.42.0 and 0.48.0 (the CHANGELOG):

- 0.43.0 `checkSignInRule`: the project's rule for a session verified
  directly, held as `withOcAuth` holds it. Ours (`api/_oc.js`
  `whoMaySignIn`) does the same and was reviewed; left as it is, and a
  candidate to replace it.
- 0.44.0 family sessions (no `aud`) are checked against ochk.io's feed and
  throw without `OC_REVOCATION_FEED_TOKEN`. Not ours: every token here is
  for one audience, and `checkOcToken` (the only check we use) is unchanged.
- 0.45.0 `matchMergedUser` and `mergedHandles`: wired, above.
- 0.46.0 to 0.48.0 the button, its stylesheet and `button-auto`: the
  button, above; `button.mjs`, since we import it ourselves.
- auth-core 2.17.1 and 2.18.0: documentation and the `merged_rh` type.
  Nothing else in the server bundle changed.

## The desktop, and Connect's L2 (2026-10-24, oc237)

orangecheck asked for native sign-in (#321) on its test stack first:
project `pk_test_WlwvYN8n055vuMCm`, audience `http://127.0.0.1:8790` (the
project's development origin), auth host `https://oc-www-test.vercel.app`,
`https://oc-me-test.vercel.app` for the rule and the list. Never the live
project: orangecheck offers it to test projects alone until it is proven on
real builds, and the live rollout waits on its site-attest's review.

- **The app.** The desktop's sign-in screen offers **Sign in with
  orangecheck**, the same button the web form has (its mark, its 44 px),
  only where `/api/account` says where to open it:
  `orangecheck.native = {project, auth, audience}`, all public
  (`api/_oc_config.js` `nativeOffered`). A press listens on `127.0.0.1` at
  any free port and opens `<auth>/native/authorize` in the person's own
  browser with a PKCE challenge (S256), a `state` and the loopback
  redirect (`src/account/orangecheck_sign_in.gd`, orangecheck's Godot
  recipe, with one signal in place of two). The browser comes back with a
  code; the app posts `{code, code_verifier, redirect_uri}` to
  `?op=native` and keeps the session it gets as an emailed code's
  (`Account.sign_in_with_orangecheck`). While it waits, the form's note
  says to finish in the browser; a second press starts again (a tab closed
  by mistake), and signing in by email meanwhile stops the listener.
  Nothing else in the app changed.
- **The server.** `?op=native` refuses anything but a code, an RFC 7636
  verifier and an `http://127.0.0.1:<port>/<path>` redirect with no query
  (422, nothing asked), counts the address as `?op=signin` does, then
  trades the code with me-client 0.50.0's `exchangeNativeCode`: the
  project key from configuration (never the app's), our one audience, the
  test or live hosts, and our own list of ended sessions (the trade is a
  write). The token it gives is then taken exactly as the window's:
  `checkToken`, spent once, the same account, merge and binding
  (`signInWith`). Refusals: an outage, or a project that does not offer it,
  503; a backed-only rule, 403 with `back_url`; anything else (a spent,
  expired or mismatched code, another audience, no `rh`, an ended session)
  401, "Sign in with orangecheck again", since a code works once whatever
  the answer.
- **Where it is on.** Everywhere orangecheck takes a token, since m167
  (`NATIVE_FOR_EVERYONE` in `api/_oc_config.js`, unit oc246): site-attest
  reviewed it, and orangecheck proved it on brickworks.diy's live project,
  19 of 19, at 2026-10-24 19:58:59Z (its consent page "Sign in to an app on
  this device? … App Brickworks · Website brickworks.diy", the token's aud
  `https://brickworks.diy`, azp native). A deployment without the project's
  keys (a unit's preview) offers it to nobody: `native: null`, and
  `?op=native` says it is not offered. False turns it off for everybody.
  `OC_ISSUER` and `OC_ME_ORIGIN` point the server at a test stack, and are
  read only off Vercel (`ocHosts`), so nothing set on a deployment can send
  a token anywhere but ochk.io. The app sends the audience `/api/account`
  names, `https://brickworks.diy` itself, which orangecheck's live proof
  took (doc gap 22).
- **Proof.** `tools/web/oc_native_flow.mjs` on the test stack: a throwaway
  Bitcoin key signed in at the test auth host, `src/dev/oc_native_probe.gd`
  headless (the real form, button, listener and `Account`), a real
  Chromium opening the link it printed and pressing Continue, and this
  machine's functions (`relay_server.mjs` at 8790) with the test key: the
  app signed in (12 checks), then as the app from Node, a code twice, a
  wrong verifier (and the right one after), another `redirect_uri`, and a
  code traded by a server at another origin (9051) are each refused (8
  checks, every one passing, 2026-10-24). `orangecheck_check` holds the same
  refusals against a stand-in token endpoint, beside sign-ins that get in.
- **Connect, L2** (orangecheck's review of step 4). An account deleted while
  `connectProvision` was still in flight: deleting asked orangecheck to
  delete one not made yet (`unknown_user`), the account and its
  `oc_connected` row went, and the answer that came after made an
  orangecheck account nothing here knew of. Now deleting marks the account
  as leaving as it reads it (`oc_connect_leaving`), and provision keeps
  orangecheck's answer only while the row is there and carries no mark of
  the last 15 minutes (`oc_connect_kept`); otherwise it calls
  `connectDelete` at once (`unprovision`, the same allow-list) and answers
  `{made: false, reason: "account_leaving"}`. Each takes the row's lock, so
  either order ends with orangecheck's account deleted. site-attest found
  two holes, each proven on our own SQL (PGlite) and fixed: the mark found
  no row yet, a first tick then wrote one and was kept (so the mark writes
  a row of its own, `asked_at` `-infinity`, read as never asked, which
  `oc_connected_of` now answers null, so an account that never ticked still
  asks orangecheck nothing when deleted); and a deletion that failed lifted
  the mark another deletion of the same account still relied on, a double
  submit being enough (R1, and R1b with an earlier did). So a mark is never
  lifted: it lapses after 15 minutes, longer than a deletion runs
  (orangecheck's ruling), and a tick in those minutes after a deletion that
  did not go through deletes what it makes, which fails safe.
  `supabase/orangecheck_connect_leaving.sql` holds the column and the three
  functions (`oc_connected_of` replacing `orangecheck_merge_connect.sql`'s,
  which `tools/apply_sql.mjs` now guards), replaced in place and
  idempotent; dry run with `tools/orangecheck_connect_leaving_try.sql`,
  which walks each race on the real Postgres.
- **The listener reads the whole request** (site-attest's nit). It answers
  once the headers have ended (or 16 KB came without an end), so a
  request line a browser sends in two pieces is never answered 404 from
  its first piece (`src/dev/oc_listener_probe.gd`, in the suite).
- **A token ended by its id** (site-attest, 2026-10-24). The exchange
  (`checkToken`, so `?op=signin`, `?op=native`, link and delete) asks the
  list of ended sessions with the token's `jti` too: a token orangecheck
  ended by itself (`POST /api/auth/revoke`) before it reached us is
  refused, 401; anything but `live`, 503. The requests after
  (`sessionStanding`, `grantStanding`) ask without it: `endToken` revokes
  our own token right after the exchange, and its id on the list must sign
  nobody out. (`exchangeNativeCode` already asked with the `jti`, so the
  app's path refused it before; the window's did not.)

## The review, and what was done

Each finding has its failing case in tools/web/orangecheck_check.mjs,
which now passes. H1, N1 and N2 are fixed as of oc205's last commit; N1's
last piece waits on its release (below).

- **H1, password sessions.** Anybody signed in can set a password on their
  account at Supabase (`PUT /auth/v1/user`) and sign in with it: a session
  nothing here started, counted as a fresh code, and bound to nothing, so
  Sign out everywhere could not end it. *Done:* only an emailed code
  (`amr` `otp`) is fresh, a password only for the `@resend.dev` test
  accounts (`api/_oc.js` `codeOf`). `api/_auth.js` `verify` refuses any
  session signed in by password, but a test account's, with 403, and ends
  it. And an account at a made-up `@oc.brickworks.diy` address, which takes
  no code, has every session orangecheck did not start ended with 401
  (`sessionStanding`). And, at orangecheck's follow-up, Supabase itself
  refuses the first step (supabase/no_new_ways_in.sql, a trigger on
  `auth.users`): a password set on any account but a test account's, and a
  change of any account's address, which would have been the same kind of
  way in. Setting a password also signed the account's other sessions out,
  so a stolen session can no longer sign the person out that way. Accounts
  are made as before: Supabase gives every one a random password hash when
  it makes it, and no sign-in by code changes it (measured).
- **N1, the database straight from a page.** Row security let any live
  session, and the publishable key every page holds, use tables through
  PostgREST, past everything `api/_auth.js` checks: a session ended on
  orangecheck still read and wrote what its policies allowed. Nothing here
  needs that (every route asks as the server, and the site and the app
  reach Supabase only to sign in), so `supabase/no_client_access.sql` drops
  every policy for anon, authenticated or everyone in public, takes back
  every table, column and sequence privilege of anon and authenticated and
  the right of anon, authenticated and PUBLIC to run any function, and
  changes postgres's defaults so nothing made later is granted them.
  `api/share.js` reads published rows as the server. The last piece,
  shared_models' published read, which the release before oc205's still
  asks for, is `supabase/no_client_access_models.sql`, applied once oc205's
  release is live. `supabase/client_exposure.sql` reads the catalogue, and
  orangecheck_check holds it empty and has PostgREST refuse every table and
  function to an emailed-code session and to anon.
- **N2, public sign-up.** Sign-up is open and Supabase confirms an address
  itself, so `POST /auth/v1/signup` with a password made an account and
  handed out a password session at once. `api/_auth.js` refused that
  session at /api, 403, and ended it (checked while nothing at Supabase
  refused it, 2026-10-24). Every account Supabase makes carries a random
  password hash, so its row cannot tell a chosen password from that, and
  `supabase/no_new_ways_in.sql` refuses at two other places: Supabase's
  record of a password sign-in (`auth.mfa_amr_claims`) but for a test
  account; and, as its making commits, the account a public sign-up makes,
  which alone writes user data that says `phone_verified` (measured against
  every account Brickworks makes). A password sign-up now answers 500 and
  leaves nothing, and so does the public `/otp` asked for a new address.
  `api/otp.js` makes a new person's account through the admin API, then
  asks generate_link for its code, so code sign-in goes on once sign-up is
  off. Turning it off (`disable_signup`, and "Confirm email" on) is
  orangecheck's to do with its Management token once oc205's release is
  live: `tools/web/signup_check.mjs` (authsec197's) holds that, and reads
  "all ok" only after. Turned off 2026-10-24 ~09:55Z, with TOTP enrolment;
  a daily canary (`api/_canary.js`, Vercel's cron) holds all three by
  trying each, and the `phone_verified` trigger, which stood in for the
  setting, goes with `supabase/drop_no_public_sign_up.sql`.
- **Second factors.** Brickworks asks for none, and Supabase's setting is
  out of reach here, so `no_new_ways_in.sql` refuses enrolling one
  (`auth.mfa_factors`) on any account.
- **Left as it is: global logout.** Any session can end every session of its
  account at Supabase (`POST /auth/v1/logout?scope=global`). It gains the
  holder nothing and signs the person out; orangecheck accepted it.
- **M1, an unlink racing a sign-in.** `oc_bind_session` binds only while
  the did is still the account's, holding the identity's row while it
  writes, and answers whether it bound; when not, the sign-in ends the
  session it minted and says so (409). A binding whose did is no longer
  the account's (`oc_session_of` `linked`) is refused and ended.
- **L1.** An account its did signs in to that is not marked
  (`app_metadata.orangecheck`) is marked before the session is minted, so
  every bound session's own token carries the mark.
- **L2.** `oc_unlink` deletes the Claude codes that sign-in approved and
  nobody exchanged yet, and the exchange refuses a code whose did is no
  longer its owner's.
- **L3, documented.** Every request of a marked account reads its session's
  binding. When that read fails, a write cannot tell the account's emailed
  code's session from one orangecheck started, so it answers 503 ("could
  not check your orangecheck sign-in") for the email session too; reads go
  on. Only accounts that have orangecheck are touched; nobody else's
  session is ever asked after. Carrying the binding in the session's own
  token would need a Supabase access token hook, which is more than this
  is worth.
- **L4.** Deleting an account that has its own email from a session
  orangecheck started asks for the same fresh emailed code as unlinking
  (403 `fresh: false`; /settings sends the code and asks for it).
- **Step 1's L1.** In production the only audience is
  `https://brickworks.diy`; the deployment's own `*.vercel.app` address is
  not one (13, below).
- **Packages.** me-client 0.50.0 (exchangeNativeCode; 0.48.0 at step 4,
  0.42.0 before) and auth-core 2.18.0, pinned in
  tools/web/vendor_orangecheck.sh. From 0.48.0 the button, its stylesheet
  and the Connect words are byte for byte the same, and the server bundle
  only gains what `exchangeNativeCode` brings (`checkOcSession`,
  `checkSignInRule`). `checkOcToken` tells a token that is no
  good from a key set that cannot be read, which answers 503, never 401.
- **4.** The parser was right already: it reads `{min_sats, min_days}` and
  takes `max_age_secs` only if it is there (orangecheck's correction). A
  check now covers a floor without it.

The exchange stays Brickworks' own rather than `withOcAuth`. orangecheck's
updated /me/sdk ("If your own session replaces the token") asks for what it
does: the project's rule, the list of ended sessions with the exchange
counted as a write, `rh` required, the `jti` spent in a shared store, and
the token ended right after. `withOcAuth` reads the token from a header and
runs before the handler, so it would ask orangecheck before the per-address
limit is counted, and the link and delete routes, which take a token in
their body, would still need their own check.

orangecheck's checklist asks a server to refuse to start without
`OC_PROJECT_KEY` and `OC_SIGNING_SECRET`. Brickworks keeps serving, since
email sign-in needs neither, takes no orangecheck token, and says so in its
log at every start.

## Where the docs fell short

orangecheck answered most of these in its docs on 2026-10-24; each says so
where it did.

1. **/me/sdk → "Full reference" (/sdk/me-client): missing.** The generated pages cover only
   the main entry. Nothing is generated for `/server` (`verifyOcToken`, `getOcSession`,
   `checkOcSession` and the wrappers' options) or for `/popup` (`signInWithOc`,
   `signInWithOcOutcome` and their options, such as `signal`).
   *Did:* used auth-core's generated pages (`VerifyOcOptions`, `integratorRevocationCheck`)
   and the /me/sdk prose.

2. **/sdk/auth-core/interfaces/SessionPayload: missing.** It lists no `rh`, `aud`, `iat` or
   `exp`, yet the checklist says to keep `rh`, `aud` and `iat`.
   *Did:* took the names from /me/sdk "verify without the SDK" and the "when someone ends
   every session" prose.

3. **/me/quickstart step 2 and /me/sdk "the session cookie": unclear and incomplete.** The
   route that exchanges the token calls `verifyOcToken(token, { audience })`, which takes no
   `projectKey`, so step 4's "who can sign in" rule is never enforced there. The docs don't
   say how to honour the rule when your own session replaces the token.
   *Did:* read the rule from `GET me.ochk.io/api/integrator/<key>/sign-in` (named on
   /me/require-bond). I re-read it at most once a minute, keep the last answer for ten
   minutes, then refuse. When it asks for a backed account, I apply `bondMeets`.
   *Answered:* the wrappers apply it; read it directly only where no wrapper runs, as here.

4. **/me/require-bond: missing.** The `/api/integrator/<key>/sign-in` answer has no
   documented shape. With "Everyone" set it is `{"ok":true,"require_bond":null}`. The shape
   of `require_bond` when a floor is set was a guess until orangecheck's review said it:
   `{min_sats, min_days}`, no `max_age_secs`.
   *Did:* read those two names (and `max_age_secs` if it is ever there), and refuse every
   sign-in when the answer doesn't state them.
   *Answered:* /me/require-bond gives the shapes; the floor is `{min_sats, min_days}`, with no
   age field, and any other key is to be ignored.

5. **/me/sdk "Anything else" (revocation list answer): unclear.** In
   `{ v, at, tokens, accounts, handles }`, the unit of `at` isn't stated. It is Unix
   seconds: a list built with milliseconds reads as stale, and every check answers
   `unverified`. What `tokens` and `accounts` hold isn't said either.
   *Did:* found the unit by testing auth-core's check against a stub list.
   *Answered:* "the list of ended sessions, without an SDK": `tokens` and `accounts` are always
   empty.

6. **/me/sdk "If your own session replaces the token": unclear.** It doesn't say whether the
   exchange itself counts as a write. If it does, it must wait while the list is
   `unverified`.
   *Did:* treat it as a write. While the list can't be read, nobody signs in with
   orangecheck (503 in words). Email sign-in is untouched.
   *Answered:* "The exchange is a write."

7. **/me/quickstart step 5 ("The token") versus "Ending sessions": contradictory.** One line
   says the token is "spent once and never stored". Another says "Signing out clears your
   session and ends the token". A site that never stores the token can't end it at sign-out.
   No page says to end it right after the exchange. No page says whether
   `POST /api/auth/revoke` puts the token's `rh` into the handles list, which would end the
   session you just started.
   *Did:* end it right after the exchange (the brief's rule). Its effect on the handles list
   is to be tested live once brickworks.diy is verified.
   *Answered:* "End the token right after the exchange."

8. **/me/quickstart step 1 and /me/sdk "when someone ends every session": missing.** The list
   is served only for the verified domain's origins. So on a preview host (`*.vercel.app`),
   every token reads as `unverified`, and an integration can't be tested end to end before
   production. No staging or preview guidance is given.
   *Did:* the preview proves everything up to the list. The full flow runs live on
   brickworks.diy (tools/web/oc_live_flow.mjs).
   *Answered:* test on a subdomain of the domain, or on localhost with a test project. The
   domain's DNS is at Namecheap, out of this project's reach, so the full flow is still
   proven live after a release.

9. **/me/quickstart step 2: missing.** It names the COOP header but not CSP. Under
   `script-src 'self'`, the popup module has to come from your own origin (the "No bundler?"
   paragraph covers that). Whether the page needs any orangecheck origin in
   `connect-src`/`frame-src` isn't said.
   *Did:* served `dist/popup.mjs` from our origin and added nothing to connect-src.
   *Answered:* the popup needs no orangecheck origin in `connect-src` or `frame-src`; the flows
   see no refusal from the page's policy.

10. **/me/sdk intro ("That is all sign-in needs"): wrong for this case.** me-client's
    `/server` doesn't export `integratorRevocationCheck`, so a site whose own session
    replaces the token needs `@orangecheck/auth-core` as well. /me/sdk names it deep in the
    page, but the "one package" framing at the top misleads.
    *Did:* bundled both (tools/web/vendor_orangecheck.sh).

11. **/me/sdk "your own accounts", identity provider paragraph: missing.** It says to mint a
    provider session for the new user and check it is theirs, but not how. For Supabase:
    admin `generate_link` (type `magiclink`), then `verify` with `token_hash`.
    *Did:* exactly that, checking the user id at each step.

12. **/me/quickstart checklist "If your own table of handles breaks, only orangecheck
    sessions are affected": unclear.** It doesn't say how to tell an orangecheck-started
    session apart without that table. With Supabase, every session's `amr` is `otp`,
    whichever way it started.
    *Did:* tag orangecheck accounts in Supabase `app_metadata` (it rides in the JWT), so an
    account with no tag is never held to the table.

13. **/me/sdk options table (`audience`) and /sdk/auth-core VerifyOcOptions: unclear.** The
    docs don't say whether `audience` takes more than one origin, for a site served at several.
    The "www and the apex" note covers revocation only. Brickworks checks each release at its
    deployment's own address before the domain moves onto it, so it has two origins.
   *Did:* keep a fixed list, pick the entry that equals the token's `aud` and pass that one
   string. In production the list is brickworks.diy alone (the review's step 1 L1): a
   release checked at its own address takes no token there.
   *Answered:* `audience` is one origin or a list of exact origins, never `'*'`.

14. **/me/sdk "a Bitcoin wallet in the popup": missing.** It shows how to sign the message with
    a throwaway key, but not how to reach the message in a test. Nothing documents the window's
    steps for automation: the "Bitcoin wallet" tab, the address field, "Get the message to
    sign", the read-only message box, the signature box and "Sign me in".
   *Did:* read the window's controls in Playwright and drove them by their labels
   (tools/web/oc_live_flow.mjs).
   *Answered:* the section names them: "Bitcoin wallet", "Bitcoin address", "Get the message to
   sign", "Message to sign", "Signature", "Sign me in". The flow finds each by that label, or
   the placeholder it was found by first, and clicks the tab until the address field shows:
   a click before the window's script runs leaves it on Email.

15. **/me/sdk "verify without the SDK" (`iat`): unclear.** It doesn't say whether `iat` is when
    the popup minted the token or when the ochk.io session began. That matters to a site
    deciding whether a token proves a fresh sign-in. On the token seen, `iat` was the popup's
    time and `exp` was 30 days later.
   *Did:* treat an unspent token from a click just now as the proof, and rely on its `jti`
   being spent once rather than on its age.

16. **/me/quickstart checklist ("Link and unlink each ask for a fresh sign-in"): unclear.**
    "Fresh" isn't given a number. /me/sdk says "within the last few minutes".
   *Did:* an emailed code from the last 5 minutes, and never a session the orangecheck id itself
   started.
   *Answered:* /me/quickstart: "a sign-in with your own login from the last five minutes".

17. **/me/sdk "when someone ends every session": missing.** No page says where on ochk.app a
    person (or a tester) finds "Sign out everywhere", so the two-minute promise can't be checked
    from the docs alone.
   *Did:* still to be found on the live test.

18. **/me/sdk: missing.** `checkOcToken` (me-client 0.42.0's `/server`), which tells
    `valid`, `invalid` (with `no_session_handle`) and `unavailable` (`key_set_unavailable`)
    apart, is in the package's types but on no page; the README names only `checkOcSession`.
   *Did:* read its type declaration, and answer `unavailable` 503.
   *Answered:* /me/sdk's session route sample now uses it, with 503 on `unavailable`.

19. **/me/sdk "your own accounts": missing.** It says to bind the token's `rh` to the
    session you mint, but not that your identity provider may let that session add a way in
    of its own that the binding never sees. With Supabase, any session can set a password
    and sign in with it (the review's H1).
   *Did:* refuse every password session but a test account's, and end any session of an
    orangecheck-only account that orangecheck did not start.

20. **/sdk/me-client/server/interfaces/ExchangeNativeCodeInput: wrong.** It lists
    `projectKey` ("Your project key, as the app sent it") as an input field, but
    `exchangeNativeCode` throws when the input has one: the key goes in its options, from
    your own configuration (as /integration/native-sign-in says). The reference also leaves
    out `meOrigin`, `revocation` and `requireBond` from `ExchangeNativeCodeOptions`.
   *Did:* followed the guide and the type declarations: the key, the hosts and our own
    list of ended sessions in the options.

21. **/integration/native-sign-in, "What comes back": missing.** It says to spend the
    `jti`, but not to end the token at orangecheck right after, as the popup's token is
    (/me/quickstart, "End the token right after the exchange"), nor that a test stack's
    issuer must be passed so the token's `iss` matches.
   *Did:* took the native token exactly as the popup's (`checkToken`, spent, ended), and
    the test stack's auth host as `issuer` for both the trade and the check.

22. **/integration/native-sign-in, the app (`audience`): unclear.** "Empty for its verified
    domain": it doesn't say whether naming the verified domain itself is also accepted.
   *Did:* the app sends what `/api/account` names, the deployment's one audience
    (`https://brickworks.diy` in production). To ask before the live rollout.
