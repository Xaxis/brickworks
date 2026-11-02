# Any assistant: ChatGPT, Gemini and the rest as easily as Claude

anyai, 2026-11-02. The owner's ask: "wasnt one of the major refactors the
task of building so a user could just as easily connect with claude as they
could with chatgpt? And the workflows being as identically and conveniently
managed for the user as possible? Or even another model service provider?
Critically research, this will be a big change and effects the website and
the apps, but I think its very important."

This is what a person meets today (A), what each assistant allows (B), where
Brickworks assumes Claude (C), one workflow for all of them (D), the risks
(E) and the units, in order (F). Outside facts carry their address and the
day read; "TP" marks a third party's word where the maker's own page could
not be read. Claims about this repo name a file and line, or a command and
what it printed. docs/PROVIDERS.md (the own-key designer) and
docs/CONNECTING.md (connecting Claude) are not repeated here.

## 1. In short

1. **The plumbing is already neutral; everything a person sees is not.**
   One address, one sign-in and one tab relay serve any MCP client. Measured
   today on a local relay (section A.3): the documented sign-in shapes of
   ChatGPT, Codex, VS Code, Zed, Cursor, Gemini, Gemini CLI, Microsoft 365
   Copilot, Perplexity and Grok all sign in, list the tools and build in a
   tab. But the app says "Claude" 617 times in 62 files, Connect only opens
   claude.ai, "New chat for this tab" only opens Claude, and the history
   names every connector call "Claude's", ChatGPT's included, because the
   relay never tells the tab who called (`src/net/command_socket.gd:986`,
   `api/mcp.js:1142`). The site contradicts itself: home and plans promise
   "your own Claude, ChatGPT or key" (`web/index.html:160`), the FAQ offers
   three ways, all Claude or an Anthropic key (`web/faq.html:127`).
2. **ChatGPT, the largest assistant, is the hardest to reach, and not
   because of us.** No link fills its form in; a custom server is added on
   the web only; OpenAI's help page on plans refuses to be read (403, twice,
   2026-10-29 and today) and what quotes it says full custom MCP is for
   Business, Enterprise and Edu, with Pro read and fetch only, which cannot
   build. And pictures a tool returns do not reliably reach ChatGPT's model
   (OpenAI support, 2026-04-22), while Brickworks' design method looks at
   its work. For most ChatGPT users the one real path is a listing in
   OpenAI's directory.
3. **Gemini can connect, but our refresh rule may cut it off after an
   hour.** Google says a server "must avoid rotating the Refresh Token" and
   return the same one; ours replaces it on every use and ends the whole
   connection when an old one comes back after 30 seconds
   (`api/oauth.js:678-689`). Measured in A.3: sent again as Google says,
   the first refresh token ended the connection. The Gemini app is also US,
   18+, personal accounts and English only.
4. **Design quality is measured for one model only: Claude Opus 5.5.**
   Every bench round in docs/ROADMAP.md runs Claude Code over MCP. No GPT or
   Gemini number exists, through the connector or on a key; `.env` holds
   only `ANTHROPIC_API_KEY`. The "supported" tier in PROVIDERS section 5 is
   a claim until P6 runs.
5. **One workflow is possible, with exactly one step that differs**: choose
   your assistant; add Brickworks to it (one click for Claude, Cursor and VS
   Code; one command for Claude Code, Codex and Gemini CLI; copy the address
   and open the right page for ChatGPT, Gemini, Le Chat, Perplexity and
   Grok); then the same sign-in, the same tab listening, the same status
   and history in the assistant's own name, and one docs page per assistant
   from one table. The plan (section F) is eight units, then PROVIDERS P5 and P7; three
   need the owner.

## A. Today, measured

### A.1 The routes, as a person takes them

| Route | Steps today | Where it breaks | What Brickworks says |
|---|---|---|---|
| claude.ai, Claude desktop and phone apps | Connect Claude in the app opens claude.ai's form filled in; Add, Connect, Brickworks' sign-in, Allow (`src/net/claude_connector.gd:262`) | Free has one custom connector; Team and Enterprise need an Owner | Throughout. But "On Claude Pro or Max" (`src/ui/connector_form.gd:120`, `web/faq.html:127`) is wrong: Free may add one (CONNECTING.md, Anthropic's page) |
| Claude Code | `claude mcp add …`, copied from the panel (`claude_connector.gd:268`); or My Claude on the desktop starts it (`src/ai/claude_code.gd:10`) | none | Throughout |
| ChatGPT web | chatgpt.com/plugins, +, Add custom MCP server, paste the address, OAuth, risk warning, Create, install, `@Brickworks` (CONNECTING.md) | plan gates (B.1); pictures; never proven with a real account (PROVIDERS P1) | Steps only in docs/CONNECTING.md and `docs-site/connector.md:38`; the app and the FAQ say nothing; plans and home promise it |
| ChatGPT desktop and phone | added on the web first; phone use unsettled (TP sources disagree) | as above | nothing |
| Codex (CLI, IDE, app) | `codex mcp add brickworks --url …`, `codex mcp login brickworks` | none known; its document is read (A.3) | nothing |
| Gemini app | gemini.google.com, Settings, Connected Apps, Add a custom app, the address, Next | US, 18+, personal account, English, Keep Activity on; refresh (A.3) | nothing |
| Gemini CLI | `gemini mcp add --transport http brickworks …`, `/mcp auth brickworks` | now paid Code Assist only; free users moved to Antigravity CLI (B.1) | nothing |
| Microsoft Copilot | consumer: no custom servers. Microsoft 365: an admin builds a connector | admin only | nothing |
| Mistral Le Chat | Connectors, Add, Custom MCP Connector, the address | the account's admin (on personal plans, the owner) | nothing |
| Perplexity | Plugins, Add custom, Remote, the address | Pro, Max, Enterprise; "not on mobile yet" | nothing |
| Grok | grok.com/connectors, New, Custom, the address | Business and Enterprise need an admin first | nothing |
| Cursor, VS Code, Zed, Devin Desktop | a config entry, or Cursor's and VS Code's install links | none known | nothing |
| Own key, desktop | Settings, AI…, Another AI, provider, model, key, Test (`src/ui/ai_settings.gd:99`) | no real design has run on a non-Anthropic key (no key in `.env`) | the FAQ's key card names only Anthropic's console (`web/faq.html:148`) |
| Own key, web | the same panel in the web build (`ai_settings.gd:296` has its web note) | P5's bar (a browser flow against the stub) was never run | as above |
| Local models | desktop only, by design (PROVIDERS 4.6) | small context: P7 not done | nothing |

### A.2 What the site and the apps say (live, read 2026-11-02)

- **Home** (`https://brickworks.diy/`): "The AI is your own Claude, ChatGPT
  or key"; then "ask Claude in claude.ai and it builds in your open tab" and
  a link "How to bring your Claude".
- **Plans** (`/plans`): "Bring your own AI: Claude or ChatGPT through the
  connector, Claude Code, or an API key of your own" and "your own API key
  for any provider".
- **FAQ** (`/faq`, section `#claude`): "Bring your own AI … one of three
  ways": Your Claude plan ("Claude Pro or Max"), Claude Code, Your own API
  key ("Make a key at console.anthropic.com … checked with Anthropic").
  "Do I need a Claude subscription?" No ChatGPT, no Gemini.
- **Docs** (`/docs`): "Connect Claude", "The Claude connector", "Claude
  Code"; "design with Claude".
- **Settings** (`/settings`): a section titled "Claude": "Whether your
  Claude can work in your Brickworks tabs." Its list of connections already
  names each by app (`web/settings.js:102`).
- **The consent page** (`/oauth/authorize`) already names the app asking
  ("Let ChatGPT build in Brickworks?"), proven by `chatgpt_flow`'s browser
  half (account.md, 2026-10-29).
- **The app**: section C.

### A.3 The relay, measured with each assistant's documented sign-in

`tools/web/chatgpt_flow.mjs` and `tools/web/oauth_probe.mjs` against
`relay_server.mjs` on port 9671, and a probe written for this unit
(`docs/any_assistant/clients_probe.mjs`; section F's U1 makes it a
check; the run's whole output is `docs/any_assistant/run-2026-11-02.txt`)
that plays each assistant's sign-in as its maker documents it (B.1): its
published client document where it has one, else registration with its
documented return address. Each row: registered or document read, what the
consent page names it, tokens, the tool list, one `search_parts` call into a
played tab and what the tab is told of the caller. A throwaway account,
deleted at the end. Run under `tools/release/live_db.sh anyai`.

Run 2026-11-02 14:07 to 14:11 UTC. `chatgpt_flow`: 27 checks, "ChatGPT can
connect to Brickworks and build in its tab" (ChatGPT's real document, its
signature refused when forged, a stand-in holding its own key through to a
call in the tab, 70 tools with no bare array and three hints each).
`oauth_probe`: "Claude can sign in to Brickworks, and nothing else can".
`clients_probe`, one row a client:

| Client, as documented | Registered or document read | The consent page names it | Tokens | Tools | The tab is told of the caller |
|---|---|---|---|---|---|
| Claude (claude.ai's document) | read | "Claude", back to claude.ai | 200 | 70 | only `brickworks/chat` |
| Codex (`chatgpt.com/oauth/codex/client.json`) | read | "Codex", back to 127.0.0.1 | 200 | 70 | only `brickworks/chat` |
| VS Code (`vscode.dev`'s document) | read | "Visual Studio Code", back to vscode.dev | 200 | 70 | only `brickworks/chat` |
| Zed (`zed.dev`'s document) | read | "Zed", back to 127.0.0.1 | 200 | 70 | only `brickworks/chat` |
| Gemini app (registers, a secret, a googleusercontent.com return) | 201, a secret | "Gemini" (the name it gave), back to oauth-redirect.googleusercontent.com | 200 | 70 | only `brickworks/chat` |
| Gemini CLI (registers, loopback) | 201 | its own name, back to localhost | 200 | 70 | only `brickworks/chat` |
| Cursor (registers, public) | 201 | "Cursor", back to www.cursor.com | 200 | 70 | only `brickworks/chat` |
| Microsoft 365 Copilot (registers, a secret, HTTP Basic) | 201, a secret | "Microsoft Copilot", back to teams.microsoft.com | 200 | 70 | only `brickworks/chat` |
| Perplexity (registers, public) | 201 | "Perplexity", back to www.perplexity.ai | 200 | 70 | only `brickworks/chat` |
| Grok (registers, public) | 201 | "Grok", back to console.x.ai | 200 | 70 | only `brickworks/chat` |
| A client with no name | 201 | "An MCP client", back to its host | 200 | 70 | only `brickworks/chat` |
| **A client calling itself "Claude"**, returning to not-claude.example | 201 | **"Claude", `claude: true`**, back to not-claude.example | 200 | 70 | only `brickworks/chat` |

The names a client registers with are this probe's guesses where its maker
does not publish one; the page shows whatever it gives. What the rows show:

- **Every shape signs in and builds.** No assistant is refused by the
  relay; the remaining faults are in what people see and in refresh.
- **The tab is never told who called** (last column), so the history says
  "Claude's" for all twelve.
- **Gemini's refresh, as Google documents it, ends the connection.** The
  Gemini row went on: the first refresh answered 200 with a new refresh
  token; the first refresh token sent again 32 seconds later (Google: "return
  the exact same Refresh Token") was refused `invalid_grant`, and with it
  the whole connection: the newest access token then answered 401 and the
  newest refresh token `invalid_grant`. Account no longer listed Gemini.
- **Account's list names a connection by what the client said**, at sign-in
  or at `initialize`: it read "Claude | x | Grok | Perplexity | Microsoft
  Copilot | Cursor | Gemini CLI MCP Client | Zed | Visual Studio Code |
  Codex | Claude" ("x" is the nameless client's `initialize` name). Two
  "Claude"s, one of them not Claude, and nothing to tell them apart.
- A self-named "Claude" is given Claude's tool list too
  (`api/mcp.js:815`, `isClaude(clientLabel(grant))`).

## B. The field, as of 2026-11-02

Read 2026-11-02 unless dated. FP = the maker's own page; TP = a third party.

### B.1 How each assistant takes a remote MCP server

| Assistant | Where, steps | Who may | Prefilled link | Sign-in it uses | Pictures to the model | Tool list changes | Phone |
|---|---|---|---|---|---|---|---|
| **Claude** (web, desktop, phone) | Customize, Connectors, Add custom connector; ~4 | Free (one), Pro, Max, Team and Enterprise (an Owner adds it) | **Yes**: `claude.ai/customize/connectors?modal=add-custom-connector&connectorName=…&connectorUrl=…` | CIMD (`none`), else DCR; `https://claude.ai/api/mcp/auth_callback` | yes | `list_changed` honoured | yes, from the web |
| **ChatGPT** (web) | chatgpt.com/plugins, +, Add custom MCP server, …, Create, install; ~6 | FP help page 403; quoted by search: Business and Enterprise/Edu full, "Pro users … read/fetch permissions", Business "Only admins and owners can create and publish"; Plus, Go, Free unlisted. "Developer mode" gate dropped 2026-10-01 (OpenAI staff, TP forum) | **No** | CIMD `https://chatgpt.com/oauth/client.json`, `private_key_jwt`; `https://chatgpt.com/connector_platform_oauth_redirect` | **not reliably**: "should not currently be treated as a guaranteed" path; "return model-readable output as content text and/or structuredContent" (OpenAI_Support, 2026-04-22) | Refresh by hand, then a new chat; Business keeps a snapshot until an admin republishes (TP) | add on the web; phone unsettled (TP disagree) |
| **Codex** (CLI, IDE, app) | `codex mcp add NAME --url URL`, `codex mcp login NAME` | every ChatGPT plan; Enterprise admins may restrict | no; a command | CIMD `https://chatgpt.com/oauth/codex/client.json` (`none`, loopback) | yes (TP) | not found | Codex on iOS: cloud, servers may be missing |
| **Gemini app** | Settings, Connected Apps, Add a custom app, URL, Next; ~4, web only | "18 or over and in the US", personal account, "Only available in English", Keep Activity on | **No** | DCR, and "currently requires a dedicated registration_endpoint … Even if your server supports Client ID Metadata Documents"; six `oauth-redirect*.googleusercontent.com/{r,a}/*` addresses; "must avoid rotating the Refresh Token" | not found | not found | "available on both the Gemini mobile app and Gemini web app" |
| **Gemini Enterprise** | an admin makes a data store | admin only | no | a client id and secret made by hand, HTTP Basic, `https://vertexaisearch.cloud.google.com/oauth-redirect` | not found | Reload by hand; at most 100 actions, off by default | not found |
| **Gemini CLI** | `gemini mcp add --transport http NAME URL`, `/mcp auth NAME` | paid Code Assist only since 2026-06-18; free users: Antigravity CLI | no; a command | DCR, `http://localhost:<port>/oauth/callback` | yes, as `inlineData` | not found | no |
| **Microsoft Copilot** | consumer: none. 365: an admin's federated connector | 365 licence and an admin | no | DCR **with a secret** ("DCR without a client secret isn't supported yet"); `teams.microsoft.com/api/platform/v1.0/oAuthRedirect` | not found | quality "might degrade" above 10 tools | store agents must render on phones |
| **Mistral Le Chat** | Connectors, Add, Custom MCP Connector; ~4 | "administrator-only"; on Free, Pro and Student the owner is admin | no | "OAuth 2.1 with dynamic client registration" | not found | dynamic discovery "not yet supported" | not found |
| **Perplexity** | Plugins, Add custom, Remote; ~6 | Pro, Max, Enterprise (members off by default) | no | DCR or a typed client; `https://www.perplexity.ai/rest/connections/oauth_callback` | not found | new tools only after reconnecting | "not on mobile yet" |
| **Grok** | grok.com/connectors, New, Custom; ~4 | "all Grok users"; Business and Enterprise: an admin first | no | "OAuth or API keys"; DCR on every reconnect (TP) | not found | not found | connectors on iOS and Android |
| **Cursor** | `~/.cursor/mcp.json` or settings | all plans | **Yes**: `cursor://anysphere.cursor-deeplink/mcp/install?name=…&config=<base64>` | DCR, public; `https://www.cursor.com/agents/mcp/oauth/callback`, `http://localhost:8787/callback` | yes | known gap (TP) | cloud agents |
| **VS Code** (Copilot) | MCP: Add Server; ~4 | not gated; Business and Enterprise off by default | **Yes**: `vscode:mcp/install?<json>`, `https://vscode.dev/redirect/mcp/install?…` | CIMD `https://vscode.dev/oauth/client-metadata.json`; 128 tools a request | not found | dynamic discovery yes | no |
| **Zed** | Settings, MCP Servers, Add Remote | not found | no | CIMD `https://zed.dev/oauth/client-metadata.json`, loopback | not found | honoured | no |

Sources: Claude: <https://claude.com/docs/connectors/building/directory-vs-custom>,
<https://claude.com/docs/connectors/building/authentication>. ChatGPT:
<https://developers.openai.com/apps-sdk/deploy/connect-chatgpt>,
<https://developers.openai.com/apps-sdk/build/auth>,
<https://developers.openai.com/apps-sdk/build/mcp-server> ("Keep the most
important details in the first 512 characters" of the instructions),
<https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt>
(403; quoted by search results), <https://community.openai.com/t/1375446>
(pictures), <https://community.openai.com/t/developer-mode-missing-from-security-login-on-chatgpt-pro/1402157>
(TP forum, OpenAI staff). Codex: <https://learn.chatgpt.com/docs/extend/mcp>.
Gemini: <https://support.google.com/gemini/answer/17209137>,
<https://developers.google.com/connected-apps/mcp/oauth> (last updated
2026-09-14), <https://docs.cloud.google.com/gemini/enterprise/docs/connectors/custom-mcp-server/set-up-custom-mcp-server>,
<https://geminicli.com/docs/tools/mcp-server>, <https://github.com/google-gemini/gemini-cli>.
Microsoft: <https://support.microsoft.com/microsoft-copilot/connecting-microsoft-copilot-to-other-services>,
<https://learn.microsoft.com/microsoft-365/copilot/connectors/set-up-custom-federated-connectors>,
<https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/plugin-authentication-dynamic-client-registration>.
Le Chat: <https://docs.mistral.ai/le-chat/knowledge-integrations/connectors/mcp-connectors>.
Perplexity: <https://www.perplexity.ai/help-center/en/articles/13915507-adding-custom-remote-connectors>.
Grok: <https://docs.x.ai/grok/connectors>. Cursor: <https://cursor.com/docs/mcp/install-links>,
<https://cursor.com/docs/context/mcp>. VS Code:
<https://code.visualstudio.com/api/extension-guides/ai/mcp>. Zed's, Codex's,
VS Code's, ChatGPT's and Claude's client documents were fetched today
(`curl` of each address above); their names: "Zed", "Codex", "Visual Studio
Code", "ChatGPT", "Claude".

### B.2 How many people use each

| Assistant | Users | Source |
|---|---|---|
| ChatGPT | 1.2 billion a week | shown at DevDay 2026-09-29, reported by <https://www.engadget.com/2271985/openai-dev-day-live-blog-chatgpt-news/> (TP quoting OpenAI) |
| Gemini app | over 1 billion a month | Google, 2026-08-11, as reported (TP) |
| Claude | about 245 million a month | Sensor Tower, May 2026 (TP); Anthropic publishes none |
| Microsoft Copilot | over 150 million a month, the whole family | Microsoft FY26 Q1, 2025-10-29 (FP) |
| Grok | about 117 million a month, with Grok in X | a filing, March 2026 (TP) |
| GitHub Copilot | 50 million | Microsoft proxy statement, 2026-10-21 (FP) |
| Perplexity | 34 to 45 million a month | estimates (TP) |
| Codex | over 5 million a week | 2026-06-02 (TP) |

So by reach: ChatGPT and Gemini each outnumber Claude four or five times
over. By who can actually connect a custom server today, the order flips:
Claude's every plan can, ChatGPT's consumer plans probably cannot, and
Gemini's only in the US in English.

### B.3 Directories

- **Claude's Connectors Directory**: any paid plan may submit; an automatic
  scan, listed as Community by default, Verified on review; every tool a
  `title` and `readOnlyHint` or `destructiveHint` (ours have all, from
  `CommandSocket.HINTS`); no ads; "frugal" with tokens; must not infringe.
  Listed, a permanent `claude.ai/directory/connectors/<slug>` page with
  Connect. <https://claude.com/docs/connectors/building/submission>,
  <https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy>.
- **OpenAI's directory** (ChatGPT and Codex): an organisation owner, after
  individual or business verification; domain verification, 5 positive and
  3 negative test cases, a demo video, reviewer credentials, website,
  support, privacy and terms; refused: EU data residency projects, digital
  goods or subscriptions sold in the app, ads; names: do not append "MCP" or
  "Plugin", do not imply OpenAI endorses it; descriptions must not "advertise
  pricing, subscriptions, free trials" or compare with other products; work
  "on both desktop and mobile".
  <https://developers.openai.com/apps-sdk/deploy/submission>,
  <https://developers.openai.com/apps-sdk/app-submission-guidelines>.
- **Google Connected Apps** (Gemini): a phased preview since 2026-10-28; an
  account administrator accepts terms; domain proof at
  `/.well-known/google-connected-apps`; three capabilities, three example
  prompts, seeded test accounts; tools locked at publish.
  <https://blog.google/innovation-and-ai/technology/developers-tools/connected-apps-one-place/>,
  <https://developers.google.com/connected-apps/gpc/perform-the-steps>.
- **Microsoft**: Partner Center, then each tenant's admin approves.
  **Le Chat, Perplexity, Grok**: curated; no open submission found.
- **The MCP Registry** (`registry.modelcontextprotocol.io`) is "not intended
  to be directly consumed by host applications", and Claude says listing
  there "doesn't surface your server in Claude". **Server Cards** (SEP-2127)
  are read by no major assistant yet.
  <https://modelcontextprotocol.io/registry/about>.

### B.4 How products that serve several assistants present it

- **Figma** (`figma.com/mcp-catalog`): one page, "Connect Figma to top MCP
  clients", 30 cards (Claude, Claude Code, ChatGPT, Codex, Cursor, …), one
  button each.
- **Stripe** (`docs.stripe.com/mcp`): a section per client; Claude and
  ChatGPT buttons go to their directory listings, Cursor and VS Code to
  install links; connections listed afterwards under "OAuth sessions" with
  Revoke.
- **Vercel** (`vercel.com/docs/agent-resources/vercel-mcp`): one page,
  ordered Claude Code, Claude.ai, ChatGPT, Codex, Cursor, VS Code, …, install
  links where they exist, ChatGPT's steps in words.
- **Zapier**: a grid, "Popular": Claude, Claude Code, ChatGPT, Cursor,
  Codex; one page per client; "Claude is the easiest starting point".
- **Canva, HubSpot**: one help page per assistant, both directory-listed.
- **Linear, Notion, Supabase, Atlassian, GitHub**: one page, a section or
  picker per client.
- Copy is "Connect [assistant] to X" or "the X app in ChatGPT"; nobody uses
  a "Works with" badge; plan lines are given per assistant.

Read 2026-11-02 at each address named.

### B.5 Naming other companies' assistants

- **OpenAI** (<https://openai.com/brand/>, 403; quoted by search): the
  ChatGPT name is OpenAI's; do not "imply endorsement"; "Use the logo only
  when it directly relates to OpenAI services".
- **Anthropic** (<https://www.anthropic.com/legal/trademark-guidelines>):
  marks only "as specifically permitted" and "in materials we approve
  beforehand"; Claude's own docs offer a "Connect to Claude" button for an
  install link (directory-vs-custom page above).
- **Google** (<https://about.google/brand-resource-center/guidance/>): "You
  can refer to Google or our products in an informational context in plain
  text"; nothing implying "affiliation, endorsement, or sponsorship".
- **Microsoft** (<https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks>):
  names "without alteration in text", "less prominently than your own
  brand", no logos.

So: assistant names in plain text, never their logos, never in our own
product names, and a line in the footer that they are their owners' marks.

## C. Where Brickworks assumes Claude

Counted 2026-11-02 in this worktree (`grep -o Claude | wc -l`): 617 in 62
files of `src/` (not `src/dev`), 142 on the site's English pages and
scripts (`web/*.html`, `web/*.js`), 200 in `docs-site/`; "ChatGPT" twice in
`src/`, 13 times on the site; "Gemini" never on the site. Each line below
was read.

**Words in the app.**
- The Connect panel, `src/ui/connector_form.gd` (`ConnectorForm`): "Or with
  your Claude plan" (:104), "On Claude Pro or Max, no key needed: connect
  Claude…" (:120), "Connect Claude" (:126), "Already in your Claude?" (:144),
  ways in "Claude Code", "Claude app" (:155, :162), "Claude is building — %d
  calls" (:449), a connection's name defaulting to "Claude" (:458).
- The assistant panel, `src/ui/chat_panel.gd`: "Claude is building"
  (:1388), "Stop Claude in this tab" (:1393), "Which Claude designs for you"
  (:300), "My Claude" (:328).
- The tab's status, `src/ui/claude_tab_view.gd`: "New chat for this tab"
  opening claude.ai only (:51), "Claude working · tab %s" (:225), "%d Claude
  chats" (:222).
- Account, `src/ui/account_panel.gd`: a section titled "Claude" (:111),
  "Connect Claude" (:116), "Disconnect Claude" (:132).
- Menus, `src/ui/shell.gd`: "Ask Claude about this…" (:1116), "Claude
  connector…" (:1422); renamed only for an own-key model
  (`name_designer`, :1659; `ProviderSettings.designer_name`,
  `src/ai/provider_settings.gd:309`).
- Settings, AI, `src/ui/ai_settings.gd`: "Claude, on your Claude plan or
  Anthropic key" (:96) against "Another AI, on your own API key" (:99): the
  axis is the maker, not the way in, so ChatGPT through the connector has no
  place in it.
- First steps, `src/ui/first_build.gd:479`: "and Claude builds it with you."
- Translations: `locale/{de,fr,es}.po`, 55 messages each naming Claude.

**Flows that only go to Claude.**
- Connect opens claude.ai's form (`src/net/claude_connector.gd:262`); the
  copied command is Claude Code's (:268); "New chat for this tab" opens
  `https://claude.ai/new?q=`, `claude://`, `claude-cli://` (:347-349).
- "Already in your Claude?" is keyed on claude.ai alone
  (`api/oauth.js:663` `rememberClaude`; `claude_connector.gd:648`).
- **A coupling that hides the connector from non-Claude users**: choosing
  Another AI in Settings sets `has_key` and hides the Connect panel
  (`src/ui/chat_panel.gd:856-874`), though that panel is also ChatGPT's way
  in.
- The tab is told an app connected (`brickworks/connected {client}`,
  `api/oauth.js:608`) and ignores which (`claude_connector.gd:1131`).

**The relay and the history.**
- The relay names a client by its return host (Claude, ChatGPT) or by the
  name it gives itself (`api/_oauth.js:125-140`), and uses that only for
  the consent page, Account's list and the tool list's shape
  (`api/mcp.js:688`, `:815`).
- It adds only `"brickworks/chat"` to a call's `_meta` (`api/mcp.js:1142`)
  and keeps whatever `_meta` the client sent. The tab's history names a call
  by `_meta["brickworks/who"]`, else "Claude"
  (`src/net/command_socket.gd:986-994`). So every connector call, ChatGPT's
  too, is "Claude's submit design (…)", and a client could name itself
  anything there by sending `brickworks/who`.
- Words returned to the model that say Claude: `api/mcp.js:296-300` (how to
  reconnect, Claude's menus), `:355-357`, `:1359`, `:1396`;
  `src/net/command_socket.gd:674`; `src/ai/app_tools.gd:2618` ("another
  Claude chat").

**What is already neutral.** The instructions name no assistant
(`src/ai/connector_guide.gd`; the served text has no "Claude") and the 68
tool descriptions none (`tools/mcp_tools.json`). The consent page names the
app asking (`web/authorize.js:52-60`). Account's list on the site names each
connection (`web/settings.js:102`). `made_with` says "assistant"
(`supabase/made_with.sql:33`). No plan counts AI (`api/plans.js:36`: "nothing
of AI, which no plan limits"), so PROVIDERS section 7's "AI builds" and P9
no longer apply.

**Only Claude Code on the desktop.** My Claude runs `claude -p` with Claude
Code's own flags (`src/ai/claude_code.gd:52-77`), looks only for a `claude`
binary (:106-131), and best of two needs it (`src/ai/best_of_two.gd:124`).
Codex, Gemini CLI and the rest can reach the desktop's port
(`src/net/command_socket.gd:34`) or the shared address, but nothing in the
app starts or offers them.

## D. One workflow for every assistant

### D.1 The flow

1. **Choose your assistant.** One chooser, the same in the app's Connect
   panel, Account, the site's Settings, the FAQ and /docs: Claude, ChatGPT,
   Gemini, then "More": Le Chat, Perplexity, Grok, Copilot (365), Claude
   Code, Codex, Cursor, VS Code, Gemini CLI, Zed, "Another app". A model on
   your own API key sits beside it as the other way ("Use an API key"), not
   inside it. Remembered per account; `?assistant=chatgpt` opens a docs
   page or the panel on one.
2. **Add Brickworks to it, in the fewest steps it allows.**
   - One click, prefilled: Claude (the form link), Cursor (`cursor://`), VS
     Code (`vscode:` and `vscode.dev/redirect`).
   - One command, copied: Claude Code, Codex, Gemini CLI.
   - **Copy and open**: one button copies `https://brickworks.diy/api/mcp`
     and opens the assistant's own page (chatgpt.com/plugins; Gemini's
     Connected Apps; Le Chat's Connectors; perplexity.ai/computer/plugins;
     grok.com/connectors), with the two or three of its own words to press,
     named exactly as its screen names them.
   - Listed in a directory (once, section E.4): that listing's Connect, one
     click, for Claude, then ChatGPT, then Gemini.
3. **The same sign-in.** Brickworks' page names the assistant ("Let
   ChatGPT build in Brickworks?", already so), the email code or the
   browser's session, Allow, once per assistant.
4. **The same tab listening.** Any connection switches every open tab on,
   as now (`claude_connector.gd:273`); the panel says which assistants are
   connected, by name, from the relay's word.
5. **The same first message.** "New chat for this tab" opens the
   assistant's new chat with "Use my Brickworks tab k7qd (“Castle”) for this
   chat." filled in where it takes one (Claude documented; ChatGPT's `?q=`
   only third-party word: checked in U4), and copies it for every assistant.
6. **The same status and history**, in the caller's name: "ChatGPT working ·
   tab k7qd", "ChatGPT's submit design (…)", "Stop ChatGPT in this tab", one
   undo per chat as now.
7. **One docs page per assistant from one table**: `/docs/connect/claude`,
   `/chatgpt`, `/gemini`, … with the same five headings (Before you start,
   Add Brickworks, Sign in, Build, If something is wrong), each with its
   plan line and "checked on <date>". The FAQ's cards, the app's chooser and
   the docs pages come from that one table, so they cannot disagree again.

### D.2 What cannot be identical, and why

- **Step 2.** Only Claude, Cursor and VS Code take a link that fills their
  form in. ChatGPT, Gemini, Le Chat, Perplexity and Grok document none, so
  their way is copy, open, paste, three to six clicks, until a directory
  listing replaces it with one.
- **Who may.** Each assistant's own plans and admins: ChatGPT's business
  workspaces (and, unsettled, its consumer plans), Gemini's US-only
  personal accounts, Le Chat's admin, Perplexity's Pro. We can only say so,
  per assistant, with the date we checked.
- **Pictures.** ChatGPT's model may not see what `view_model` and the fresh
  look return. The design method looks at its own work; how much a blind assistant
  loses is not measured, and U5 measures it before anything is changed.
- **The phone.** ChatGPT and Gemini add a server on the web only; Perplexity
  not on phones yet.
- **New tools.** Claude, VS Code and Zed pick up a changed tool list; ChatGPT
  needs Refresh (an admin's republish on Business), Perplexity a reconnect,
  Le Chat does not support it. So a tool's schema must keep taking what an
  older list sent.
- **The tool permission switches** are each assistant's own, and differ.
- **"My Claude"** stays Claude Code's: no other CLI takes the same flags.
  Codex and Gemini CLI get the command to copy, not a launcher.

## E. Critique, and recommendations

### E.1 Risks in the relay

- **Gemini's refresh** (finding 3). If Gemini keeps the first refresh token,
  as Google tells servers to expect, the connection ends an hour after it
  began and the person must connect again, every hour. OAuth 2.1 asks
  rotation only of public clients; a client that proves itself (a secret or
  a signed assertion, as a client that registered with a secret does and as
  ChatGPT does by `private_key_jwt`)
  may keep one refresh token. Recommended: keep it for those, rotate for
  public ones (U2). Whether Gemini registers with a secret is learnt from
  the owner's first real connection (its registration, logged without
  secrets).
- **A name is not an identity.** A client that registers as "Claude" is
  shown as Claude on the consent page and given Claude's tool list (A.3,
  the last rows). The return host is shown beside it, which is what the MCP
  spec asks, but the label should come from what is checked (a client
  document's address, a known return host), and a self-chosen name be shown
  as such (U1).
- **`brickworks/who` from the client.** The relay passes the client's own
  `_meta` through (`api/mcp.js:1142`), so a client can write any name into
  the history. The relay must set it from the connection (U1).

### E.2 Design quality per model

No measurement exists for any model but Claude Opus 5.5. Two cheap ones
first, then the real one:
- **Claude without pictures** (U5): the bench subset on Claude with every
  picture taken out of tool answers, against Claude with them, the same
  night. That is what ChatGPT through the connector risks, and it needs no
  new key.
- **P6 as written**: GPT-6.1 Sol and Gemini 4 Argon on the own-key loop, on
  the owner's keys with spend limits. Until then the presets' "supported"
  tier says "not yet measured".
- ChatGPT through the connector cannot be benched by machine (no API drives
  chatgpt.com). The owner's real connection builds one bench subject by
  hand, judged as the bench judges.

### E.3 Size

68 app tools and the relay's 2 are 185 KB of compact JSON (`tools/mcp_tools.json`),
about 46,000 tokens. VS Code caps 128 tools a request, Gemini Enterprise 100
actions, Microsoft warns past 10. ChatGPT reads the first 512 characters of
the instructions with most weight: ours start with the tab note and "Only
the start of these instructions may reach you: read_guide gives any section
… in full" (`src/ai/connector_guide.gd:9-17`), which is the right first
thing. No change recommended now; a core set (PROVIDERS P7) only if a
client refuses the size.

### E.4 Directories: recommend, in order

1. **Claude's directory, first.** Cheapest: the mechanical rules are met
   today (OAuth, a title and hints on every tool, a privacy policy); a
   reviewer account is to make; and the policy's "frugal" with tokens (5B)
   is a judgement our 46,000-token tool list could fail, so the submission
   says why the list is that size. A Community listing gives a permanent
   Connect page and in-chat suggestions. One external send, the owner's.
2. **OpenAI's directory, second, after the owner's real ChatGPT connection
   works.** It is the only path for most ChatGPT users. Costs: business or
   individual verification under the owner's name, a demo video, a
   reviewer account, test prompts; no pricing in the listing; "Brickworks",
   never "Brickworks MCP". Pictures must not be the only answer (U5).
3. **Google Connected Apps, third**: preview, US and English; join when it
   opens wider.
4. Not Microsoft, Le Chat, Perplexity or Grok directories: curated or
   enterprise, small return for us.

**The trademark side.** A listing is a public description of Brickworks in
another company's store. It uses LEGO® as an adjective only and the
disclaimer, as everywhere (docs/TRADEMARKS.md). Decision 6 there holds
while Brickworks is free; Pro on sale reopens it, and a store listing of a
product with a paid tier is part of that review. The listing itself sells
nothing (OpenAI forbids that), so it does not by itself change Decision 6.

### E.5 Support load

Each assistant's screens change every few months (ChatGPT's connectors
became apps, then plugins, within a year; Windsurf became Devin Desktop on
2026-06-02). Recommended: three kinds, said plainly on the chooser:
- **Guided**: Claude, ChatGPT, Gemini. Steps with their own words, checked
  by hand each release that touches them, and a real connection by the
  owner at least once.
- **One click or one command**: Cursor, VS Code, Claude Code, Codex, Gemini
  CLI, Zed. Proven by the relay check's sign-in shapes (U1).
- **Should work**: Le Chat, Perplexity, Grok, Copilot 365, any other MCP
  app. The address and a link to that app's own instructions.

## F. The plan

Each unit is one agent's bounded task from `origin/main`, ending in the
lead's merge. Words on screen are the lead's to name in each brief; the
words here are proposals.

**U1. The relay names the caller** (relay, small). The relay sets
`_meta["brickworks/who"]` on every call from the connection's label,
replacing anything the client sent; `clientLabel` learns the documented
hosts and documents (Gemini's `googleusercontent.com`, Microsoft's,
Perplexity's, x.ai's, Cursor's, `vscode.dev`, Codex's and Zed's documents)
and stops giving a self-chosen "Claude" Claude's label; the tab reads the
name in `brickworks/connected`. `docs/any_assistant/clients_probe.mjs`
becomes `tools/web/clients_check.mjs`. *Bar:* the check passes every row of A.3
with the right name on the page, in Account and in the tab's `_meta`;
`designer_words_probe` reads "ChatGPT's submit design" for a call the relay
named ChatGPT; `chatgpt_flow` and `oauth_probe` pass as before.

**U2. Refresh that keeps Gemini connected** (relay, small). A client that
proves itself at the token endpoint keeps its refresh token (its expiry
moved on); public clients rotate as now. *Bar:* the check's Gemini row: the
first refresh token used again after the grace still works and the
connection stays; a public client's replay still ends it
(`oauth_probe`, `tests/test_oauth_clients.py`).

**U3. One table of assistants, and the app's Connect** (app). A data file
(`assistants.json`: name, kind, how to add, link or command template, page
to open, steps, plan line and date, limits) read by the app and the site.
The Connect panel becomes "Connect your AI" with the chooser (D.1, 1-2),
says which assistants are connected by name, and stays shown whoever
designs (fixing `chat_panel.gd:874`); Account's section and the tab's
status take the caller's name (`claude_tab_view.gd:225`); Settings, AI asks
the way in (your AI app, an API key, My Claude on the desktop), not the
maker. Claude's words stay where the thing is Claude's (My Claude, Claude
Code). *Bar:* a probe drives the chooser for Claude, ChatGPT and Cursor (the
link opened, the address copied, the command copied), the status naming a
ChatGPT stand-in connected through the relay, at 1024 and 1400, light and
dark; `connector_probe`, `ai_settings_probe` pass.

**U4. The site and /docs from the same table** (website). /docs gains one
page per assistant from one template (D.1, 7) and a "Connect your AI" hub;
the FAQ's "Bring your own AI" becomes the chooser's cards; Settings'
section is "Assistants"; home and plans say what the FAQ says; "Claude Pro or
Max" corrected (Free has one connector); the footer names the marks as
their owners'. Checks ChatGPT's `?q=` and Gemini's equivalent in a browser,
signed out. *Bar:* site check: every assistant page renders at 390 and 1280,
light and dark; no page says a way the table does not; de, fr and es after
(U4b, as the languages units do).

**U5. Pictures with words, and what blindness costs** (app and bench).
Every tool answer that carries a picture also carries the words a model
needs without it (what `review_model` already says, as text or
`structuredContent`), and the fresh look asks a client that cannot see in
words. First the measure: the bench subset on Claude with pictures stripped,
against with them, the same night. *Bar:* the numbers; the change kept only
if the blind score rises and the seeing one does not fall.

**U6. The owner connects ChatGPT and Gemini** (owner, by hand, after U1 and
U2 are on a preview). The owner's ChatGPT account (whatever plan; if it
refuses, which plan it asked for), and a US personal Google account if
there is one, add Brickworks, sign in, build one small model, on the web
and the phone. The unit records: the plan gate met, whether pictures
reached the model, whether the card drew, Refresh after a release, what
Gemini registered with. *Bar:* both build in the owner's tab; the facts
written into the assistants table and CONNECTING.md.

**U7. P6, the tiers measured** (bench). As PROVIDERS P6, on the owner's
OpenAI and Google keys with spend limits. *Bar:* the numbers, the presets
ordered by them.

**U8. Directory submissions** (owner's yes, external sends). Claude's
directory first; OpenAI's after U6 and U5; Google's when its preview opens
to us. The unit prepares everything (reviewer account, test prompts,
listing text, the video's script) and the owner submits. *Bar:* the
submissions made, and each listing's Connect, once live, added to the table.

**U9. PROVIDERS P5 and P7** stay as written, after the above.

### What needs the owner

1. **A real ChatGPT account** for U6, and to say which plan it is; if
   consumer plans cannot add a custom server, a Business workspace (paid,
   the owner's call) or waiting for the directory.
2. **A US personal Google account** for Gemini in U6, if one exists.
3. **API keys** for OpenAI and Google, with spend limits, for U7 (and U5's
   second half if it uses them).
4. **Yes or no to each directory** (U8): submissions under the owner's name,
   OpenAI's identity or business verification, a demo video.
5. Nothing else: U1 to U5 need no account of the owner's.

### Order, and why

U1 and U2 first: small, the relay only, and they turn two silent faults
(every caller named Claude; Gemini dropped after an hour) into proven
behaviour before anything says "ChatGPT" or "Gemini" to a person. Then U3
and U4 together, the change people see. U5 before any directory, because a
ChatGPT listing whose designs are blind would be the first impression for
the largest audience. U6 as soon as U1 and U2 are on a preview, in
parallel. U7 and U8 last.
