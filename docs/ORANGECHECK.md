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

## The review, and what was done

Each finding has its failing case in tools/web/orangecheck_check.mjs,
which now passes.

- **H1, password sessions.** Anybody signed in can set a password on their
  account at Supabase (`PUT /auth/v1/user`) and sign in with it: a session
  nothing here started, counted as a fresh code, and bound to nothing, so
  Sign out everywhere could not end it. *Done:* only an emailed code
  (`amr` `otp`) is fresh, a password only for the `@resend.dev` test
  accounts (`api/_oc.js` `codeOf`). `api/_auth.js` `verify` refuses any
  session signed in by password, but a test account's, with 403, and ends
  it. And an account at a made-up `@oc.brickworks.diy` address, which takes
  no code, has every session orangecheck did not start ended with 401
  (`sessionStanding`). Supabase also signs out the account's other sessions
  when a password is set: a stolen orangecheck sign-in can still sign the
  person out of their email sessions, though it keeps nothing.
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
- **Packages.** me-client 0.42.0 and auth-core 2.17.0, pinned in
  tools/web/vendor_orangecheck.sh. `checkOcToken` tells a token that is no
  good from a key set that cannot be read, which answers 503, never 401.
- **4.** The rule's floor is `{min_sats, min_days}`, read in exactly those
  names; nothing asks for `max_age_secs`.

## Where the docs fell short

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

4. **/me/require-bond: missing.** The `/api/integrator/<key>/sign-in` answer has no
   documented shape. With "Everyone" set it is `{"ok":true,"require_bond":null}`. The shape
   of `require_bond` when a floor is set was a guess until orangecheck's review said it:
   `{min_sats, min_days}`, no `max_age_secs`.
   *Did:* read exactly those two names, and refuse every sign-in when the answer doesn't
   state them.

5. **/me/sdk "Anything else" (revocation list answer): unclear.** In
   `{ v, at, tokens, accounts, handles }`, the unit of `at` isn't stated. It is Unix
   seconds: a list built with milliseconds reads as stale, and every check answers
   `unverified`. What `tokens` and `accounts` hold isn't said either.
   *Did:* found the unit by testing auth-core's check against a stub list.

6. **/me/sdk "If your own session replaces the token": unclear.** It doesn't say whether the
   exchange itself counts as a write. If it does, it must wait while the list is
   `unverified`.
   *Did:* treat it as a write. While the list can't be read, nobody signs in with
   orangecheck (503 in words). Email sign-in is untouched.

7. **/me/quickstart step 5 ("The token") versus "Ending sessions": contradictory.** One line
   says the token is "spent once and never stored". Another says "Signing out clears your
   session and ends the token". A site that never stores the token can't end it at sign-out.
   No page says to end it right after the exchange. No page says whether
   `POST /api/auth/revoke` puts the token's `rh` into the handles list, which would end the
   session you just started.
   *Did:* end it right after the exchange (the brief's rule). Its effect on the handles list
   is to be tested live once brickworks.diy is verified.

8. **/me/quickstart step 1 and /me/sdk "when someone ends every session": missing.** The list
   is served only for the verified domain's origins. So on a preview host (`*.vercel.app`),
   every token reads as `unverified`, and an integration can't be tested end to end before
   production. No staging or preview guidance is given.
   *Did:* the preview proves everything up to the list. The full flow runs live on
   brickworks.diy (tools/web/oc_live_flow.mjs).

9. **/me/quickstart step 2: missing.** It names the COOP header but not CSP. Under
   `script-src 'self'`, the popup module has to come from your own origin (the "No bundler?"
   paragraph covers that). Whether the page needs any orangecheck origin in
   `connect-src`/`frame-src` isn't said.
   *Did:* served `dist/popup.mjs` from our origin and added nothing to connect-src. This
   still has to be confirmed on the preview.

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

14. **/me/sdk "a Bitcoin wallet in the popup": missing.** It shows how to sign the message with
    a throwaway key, but not how to reach the message in a test. Nothing documents the window's
    steps for automation: the "Bitcoin wallet" tab, the address field, "Get the message to
    sign", the read-only message box, the signature box and "Sign me in".
   *Did:* read the window's controls in Playwright and drove them by their labels
   (tools/web/oc_live_flow.mjs).

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

17. **/me/sdk "when someone ends every session": missing.** No page says where on ochk.app a
    person (or a tester) finds "Sign out everywhere", so the two-minute promise can't be checked
    from the docs alone.
   *Did:* still to be found on the live test.

18. **/me/sdk: missing.** `checkOcToken` (me-client 0.42.0's `/server`), which tells
    `valid`, `invalid` (with `no_session_handle`) and `unavailable` (`key_set_unavailable`)
    apart, is in the package's types but on no page; the README names only `checkOcSession`.
   *Did:* read its type declaration, and answer `unavailable` 503.

19. **/me/sdk "your own accounts": missing.** It says to bind the token's `rh` to the
    session you mint, but not that your identity provider may let that session add a way in
    of its own that the binding never sees. With Supabase, any session can set a password
    and sign in with it (the review's H1).
   *Did:* refuse every password session but a test account's, and end any session of an
    orangecheck-only account that orangecheck did not start.
