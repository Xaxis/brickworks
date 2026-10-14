# Connecting Claude to Brickworks

How someone on a Claude plan gets Claude building in Brickworks, what Claude's
own apps support for that, and how Brickworks does it. Researched 2026-10-11
from Anthropic's documentation and the MCP specification, and checked against
what claude.ai actually serves. Every claim below has its source.

## What a person does

Brickworks has one connector address for everybody:

    https://brickworks.diy/api/mcp

**claude.ai and the Claude desktop and mobile apps.** In Brickworks, the
assistant panel's **Connect Claude** opens claude.ai's *Add custom connector*
dialog with the name and the address already filled in. They press Add, then
Connect; Claude sends them to Brickworks to sign in with their email code (or
straight to the question, if Brickworks is already signed in in that browser),
they press Allow, and they are back in Claude, connected. Connecting again
after a Disconnect is **Connect** on the Brickworks already in their Claude
(Customize › Connectors, Your connectors), which Connect Claude opens for an
account that has had Claude connected: adding it again sets up a second one,
with its tool permissions to choose again. A connector added on
claude.ai is in the desktop and mobile apps too, and in Claude Code when it is
signed in with the same Claude account.

**Claude Code.**

    claude mcp add --transport http brickworks https://brickworks.diy/api/mcp

then `/mcp` in Claude Code and *Authenticate* (or `claude mcp login brickworks`
from a shell). The browser opens on the same Brickworks sign-in; Allow, and
Claude Code holds the token.

Then, with Brickworks open and signed in in any browser, they ask Claude to
"build a small red house in Brickworks". Claude's calls go to that account's
open tab, on whichever device it is.

The private per-browser addresses that came before
(`https://brickworks.diy/api/mcp?t=…`, pasted by hand) keep working for
everyone who added one.

## What Claude supports, with sources

### Adding a custom connector

- Where: on claude.ai and in the desktop app, **Customize → Connectors → Add
  custom connector**, then a name and the server's URL. "Free, Pro, Max, Team,
  and Enterprise… Free users are limited to one custom connector."
  <https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp>,
  <https://claude.com/docs/connectors/custom/add-unlisted>,
  <https://claude.com/docs/connectors/getting-started>
- Team and Enterprise: an Owner adds it for the organization first
  (Organization settings → Connectors); members then press Connect.
  <https://claude.com/docs/connectors/custom/add-unlisted>
- Everywhere at once: "the same authentication infrastructure backs claude.ai,
  Claude Desktop, Claude mobile, Claude Code, and Cowork"; a connected
  connector "is available in your conversations on the web, desktop, and
  mobile", and in Claude Code "when you sign in with your Claude account".
  <https://claude.com/docs/connectors/building/authentication>,
  <https://claude.com/docs/connectors/getting-started>

### The one-click link (it exists)

claude.ai documents an install link that opens *Add custom connector* with the
name and URL prefilled, for exactly this use — "a **Connect to Claude** button":

    https://claude.ai/customize/connectors?modal=add-custom-connector&connectorName=NAME&connectorUrl=ENCODED_URL

"claude.ai opens the dialog with the name and URL prefilled and shows a notice
that the values came from an external link. The user reviews the values and
confirms before anything is added. A signed-out user is prompted to sign in
first and then sees the prefilled dialog." Organization Owners use the same
parameters on `https://claude.ai/admin-settings/connectors`.
<https://claude.com/docs/connectors/building/directory-vs-custom#custom-connector-install-link>
(shipped through <https://github.com/anthropics/claude-ai-mcp/issues/74>).

What there is not:

- No link that also signs in or skips the person's confirmation: "Install
  links only prefill the form."
- No documented link that installs a connector into the **desktop app**
  (`claude://` links are documented only for Claude Code sessions,
  <https://code.claude.com/docs/en/desktop>). The desktop app shows connectors
  added on claude.ai, so the claude.ai link serves it too.
- No install link for **Claude Code** like Cursor's: `claude-cli://open` takes
  only a prompt, a directory and a repository
  (<https://code.claude.com/docs/en/deep-links>). The command line is the way.
- A listing in Anthropic's Connectors Directory would give a permanent
  `https://claude.ai/directory/connectors/<slug>` page with a Connect button
  and in-chat suggestions; submitting is open to anyone on a paid plan, after
  review (<https://claude.com/docs/connectors/directory>,
  <https://claude.com/docs/connectors/building/submission>). Not done; it is
  the owner's call.

### How Claude signs in to a connector

From <https://claude.com/docs/connectors/building/authentication> unless noted:

- **Discovery.** Claude needs a `401` with `WWW-Authenticate: Bearer
  resource_metadata="…"` ("Claude doesn't honor a `WWW-Authenticate` header on
  a `200`"); without the pointer it probes
  `/.well-known/oauth-protected-resource/<path>` then the root. The protected
  resource metadata's `resource` "must equal the URL as the user enters it in
  Claude, including any path component"; only the first
  `authorization_servers` entry is used. Then the authorization server's
  RFC 8414 metadata at `/.well-known/oauth-authorization-server` (or OpenID
  discovery). A user report says claude.ai has also asked for
  `/.well-known/oauth-authorization-server/<mcp path>` on a path-less issuer
  (<https://github.com/anthropics/claude-ai-mcp/issues/376>); Brickworks
  answers there too.
- **Who Claude is.** Claude prefers a Client ID Metadata Document (CIMD, MCP
  spec 2025-11-25) and uses one "only when your authorization server metadata
  advertises both `"client_id_metadata_document_supported": true` and `"none"`
  in `token_endpoint_auth_methods_supported`"; otherwise Dynamic Client
  Registration (RFC 7591), which "causes Claude to register a new client on
  every fresh connection". Claude's documents, fetched 2026-10-11:
  - `https://claude.ai/oauth/mcp-oauth-client-metadata` — `client_name`
    "Claude", `redirect_uris` `["https://claude.ai/api/mcp/auth_callback"]`,
    `token_endpoint_auth_method` "none" (claude.ai, desktop, mobile, Cowork)
  - `https://claude.ai/oauth/claude-code-client-metadata` — "Claude Code",
    `["http://localhost/callback", "http://127.0.0.1/callback"]`, "none"
- **Return addresses.** claude.ai: exactly
  `https://claude.ai/api/mcp/auth_callback`. Claude Code: a loopback address
  on "an ephemeral port that varies per session… match both with the port
  component ignored" (RFC 8252 §7.3). The consent screen should show the
  return host plainly, and warn when it is a loopback program
  (<https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization#localhost-redirect-uri-risks>).
- **PKCE** S256 on every request, and the server must advertise
  `code_challenge_methods_supported: ["S256"]` — spec clients refuse to go on
  without it (<https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization#authorization-code-protection>).
- **Resource indicators.** "Claude sends the RFC 8707 `resource` parameter on
  authorization and token requests, set to the canonical form of your MCP
  server URL" (<https://claude.com/docs/connectors/building/troubleshooting>).
- **Scopes.** The `scope` in the 401's challenge, else the resource
  metadata's `scopes_supported`; `offline_access` is added when the
  authorization server lists it.
- **Tokens.** The token endpoint must take form-encoded bodies; 10 s for
  discovery, registration and token calls, 30 s for refresh. Claude refreshes
  on a 401 and up to five minutes before expiry; a dead refresh token must be
  `invalid_grant`; public clients' refresh tokens must rotate.
- **Network.** Claude's requests come from Anthropic's servers,
  `160.79.104.0/21`, over IPv4 (<https://platform.claude.com/docs/en/api/ip-addresses>).
- **Claude Code** (<https://code.claude.com/docs/en/mcp>): `claude mcp add
  --transport http <name> <url>`, then `/mcp` or `claude mcp login <name>
  [--no-browser]`; a random callback port unless `--callback-port`; CIMD or
  DCR; tokens "stored securely and refreshed automatically".
- **The spec.** MCP authorization, current revision and 2025-11-25:
  <https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization>,
  <https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/authorization-server-discovery>,
  client registration priority (pre-registered, CIMD, DCR, ask the user):
  <https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration>.
  The 2026-07-28 revision also has the `issuer` equal the address its metadata
  was fetched from, and RFC 9207's `iss` on the authorization response.

## How Brickworks does it

| | |
|---|---|
| MCP address | `https://brickworks.diy/api/mcp` (`api/mcp.js`) — no token: 401, `resource_metadata` and `scope="build"` |
| Protected resource metadata | `/.well-known/oauth-protected-resource` and `…/api/mcp` |
| Authorization server metadata | `/.well-known/oauth-authorization-server` (and with any path after it); issuer = the site |
| Client identity | CIMD (Claude's and Claude Code's documents, read and kept an hour) or registration at `/oauth/register` |
| Sign-in and consent | `/oauth/authorize` → `web/authorize.html`: the app's email code, or the app's session in that browser; one question naming who asks and where the answer goes, asked once: while the account still holds a connection to that same client (its id, the same return address, this server) a connection made again is answered with a code at once (`op=remembered`, 2026-10-14). Disconnect, a revocation or a replayed refresh token end it, and the next connection asks |
| Tool annotations | every tool carries MCP's `annotations` — `title`, `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint` — from one table in the app (`CommandSocket.HINTS`; the relay's `tabs` and `select_tab` in `api/mcp.js`). Claude reads them in deciding what to ask about; the per-tool switches in Claude's own connector settings are Claude's, and the person's choices there stand |
| Tokens | `/oauth/token`: S256 PKCE, exact return address (loopback: any port), resource checked; access an hour, refresh rotated, both kept only as SHA-256 |
| Revocation | `/oauth/revoke` (RFC 7009), **Disconnect** in the app, or deleting the account |
| Routing | each call goes to the account's open tab (`relay_tabs.owner`), whichever device |
| Tools that change | `listChanged: true`. A tab reloaded into a newer build says hello with its tools; each conversation's next call after that is answered as an event stream with `notifications/tools/list_changed` ahead of the answer, once (`relay_lists`). A client that takes JSON alone is told in words in that answer. The desktop's port and `tools/brickworks_mcp.py` do the same for an app updated and started again |

A client that does not act on `notifications/tools/list_changed` keeps the
list it was given until it connects again: a new conversation, or reconnecting
Brickworks (claude.ai: Settings, Connectors; Claude Code: `/mcp`, Reconnect).
The FAQ says so (`web/faq.html#new-tools`). `tools/web/list_changed_check.mjs`
proves the relay's half, both ways in.

The endpoints are in `api/oauth.js`, the tables in `supabase/oauth.sql`, and
the proofs in `tools/web/oauth_probe.mjs` (every endpoint and refusal),
`src/dev/connector_probe.gd` (an app tab answering Claude signed in to its
account) and `tools/web/oauth_flow.mjs` (the whole thing in a browser on a
deployment). `.claude/skills/verify/features/account.md` says how to run them.

## Not done

- **A listing in the Connectors Directory** would make Brickworks findable in
  Claude and give a permanent Connect page. It needs a submission and
  Anthropic's review; the owner's to decide.
- **A sign-in that knows the person's Claude login.** Brickworks never asks
  for one and never sees one: Claude holds a Brickworks token, never the other
  way round.
