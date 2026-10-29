# Designing with any model

provider339, 2026-10-29. The owner's ask: "App should be refactored to not
JUST work with claude but also chatgpt, user should ALSO be able to provide an
api key to any provider they want and work with just about (any reasonable
model) and configure that."

This is the research, the design, the first working slice and the work left,
in order. Every outside claim has its source and the day it was read; where a
source could not be read, or only a third party says it, this says so. Claims
about this repo name the file.

## 1. In short

1. **Two ways in, as with Claude today.** A chat app connects to Brickworks as
   an MCP connector (ChatGPT, as claude.ai does now), or the app itself drives
   any provider's model on the person's own key (as Claude Code does here).
2. **ChatGPT as a connector needs one change to the relay**: it identifies
   itself with a client document that our authorization server refuses today
   (section 3). Then the same address, tools and sign-in serve it.
3. **The own-key designer is a client of the app's own MCP tools** (section 8),
   not a second copy of the in-app Anthropic loop: the model is given exactly
   what Claude is given, and the fresh look works unchanged.
4. **One adapter per API**: OpenAI Chat Completions (built, and it covers
   OpenRouter, Groq, Together, Mistral, DeepSeek, Gemini's compatible endpoint,
   Ollama, LM Studio, vLLM), then Anthropic Messages, OpenAI Responses and
   Gemini's own API, each one file.
5. **Desktop calls the provider directly. So can the web**: every hosted
   provider tested answers a page on brickworks.diy (section 4.6, measured).
   No pass-through server; the key never reaches us.
6. **Keys stay on the device**, one per provider, or for the visit only, as
   Anthropic keys are kept today (`src/ai/own_key.gd`). Never on our server.
7. **"Any reasonable model" means tool calling, pictures and room**: tools are
   a must, vision is needed for view_model and the fresh look, and the tool
   list alone is about 42,000 tokens. A Test button finds out per model.
8. **Supported first**: Claude Opus and Sonnet 5.5, GPT-6 Astra and GPT-6.1
   Sol, Gemini 4 Argon and 3.8 Flash, once each has passed a bench subset.
   Anything else with tools and vision "may work"; without tools, refused.
9. **Builds are counted as the plans count Claude's** (section 7): connector
   clients at the relay, the own-key loop by `/api/builds` on the web, not on
   the desktop. The plan needs one amendment: call them AI builds.
10. **Next, in order**: ChatGPT on the relay, the settings panel, the other
    three adapters, streaming, the web, the model tiers by measurement
    (section 10).

## 2. How it works today

| Path | Who is the model's client | Where the model runs | File |
|---|---|---|---|
| **The connector** | claude.ai, the Claude apps, Claude Code with the address added | Anthropic, on the person's plan | `api/mcp.js`, `api/oauth.js`, `docs/CONNECTING.md` |
| **My Claude** (desktop) | Claude Code, started by the app on the port | Anthropic, on the person's plan | `src/ai/claude_code.gd`, `Main.design_with_claude_code` |
| **The in-app assistant** | The app itself (`Assistant._send`) | Anthropic, on the person's API key | `src/ai/assistant.gd`, `src/ai/own_key.gd`, `src/ai/brain.gd` |

The first two are clients of the app's MCP server (`CommandSocket.answer_rpc`,
served on the desktop's port and to the relay from each tab). Both get the
same instructions (`Assistant.guidance()`) and the same 61 tools
(`tools/mcp_tools.json`), and every call runs through the same path
(`CommandSocket._call`): one history step a call, long calls as jobs
(`ToolJobs`), and the fresh look at a new design's first save (`FreshEyes`:
the save hands back three pictures and the judge's question, and every call
but `fresh_eyes` and `save_model` is refused until it is answered).

The third is a design loop of its own, 23,000 lines that speak Anthropic's
Messages API: thinking blocks, cache marks, tool results with pictures, the
streamed reply drawn brick by brick. It is not where the design quality work
of the last month went (the bench measures the connector path), and it is
Anthropic-shaped through and through. So the new loop does not generalise it.

## 3. ChatGPT, and other chat apps, as connector clients

### What ChatGPT supports

From OpenAI's Apps SDK documents, now titled "plugins" (read 2026-10-29):

- **Where a person adds one.** "Go to ChatGPT Plugins (chatgpt.com/plugins)",
  the plus button, **Add custom MCP server**, a name and description, the
  server's URL, then authentication, "acknowledge the risk warning, and select
  Create as a plugin". A changed tool list is picked up with **Refresh** on
  that page, then a new conversation.
  <https://developers.openai.com/apps-sdk/deploy/connect-chatgpt>
- **Transport**: "A public endpoint supports streamable HTTP, typically at
  /mcp." Ours is streamable HTTP at `/api/mcp`. (same page)
- **Sign-in**: the protected resource metadata, or a `WWW-Authenticate` that
  points to it; RFC 8414 or OpenID discovery; `code_challenge_methods_supported`
  must include S256; "ChatGPT prioritizes CIMD when it is available", else
  dynamic client registration, which it "runs once per MCP server connection,
  then keeps and reuses". The `resource` parameter on both requests. Return
  address `https://chatgpt.com/connector_platform_oauth_redirect` when the
  server supports RFC 9207's `iss`, else a per-connection
  `https://chatgpt.com/connector/oauth/{callback_id}`. No client credentials
  grant; ChatGPT presents "an OpenAI-managed client certificate" (mTLS) and
  publishes egress IP ranges.
  <https://developers.openai.com/apps-sdk/build/auth>,
  <https://developers.openai.com/plugins/llms-full.txt>
- **Tool annotations** (`readOnlyHint`, `destructiveHint`, `openWorldHint`)
  "help ChatGPT and Codex choose appropriate confirmation and safety
  behavior". Ours carry them already (`CommandSocket.HINTS`).
  <https://developers.openai.com/apps-sdk/build/mcp-server>
- **Limits**: none stated on tool count or schema; OpenAI's API guide's soft
  advice is "fewer than 20 functions available at the start of a turn".
  <https://developers.openai.com/api/docs/guides/function-calling>. Ours is 61.
- **Not said**: how ChatGPT shows MCP image content to the model,
  `notifications/tools/list_changed`, and whether our model cards (MCP Apps'
  `ui://` pages, `src/net/model_views.gd`) render. All three are for the unit to
  try on a real account.
- **Which plans**: not answered by OpenAI's developer pages, and
  help.openai.com refused to be read (403). Third parties disagree: full MCP
  with write tools on Business, Enterprise and Edu with an admin's say
  (Boomi, <https://help.boomi.com/docs/Atomsphere/Platform/Connect_chatgpt_setup>),
  or on Plus and Pro too (Speakeasy,
  <https://www.speakeasy.com/docs/mcp/build/integrate/clients/using-chatgpt-developer-mode-with-gram>).
  None says Free. The owner's own account settles it in the unit.

### What our relay has to change: measured

ChatGPT's client document, fetched 2026-10-29 from
`https://chatgpt.com/oauth/client.json`:

```json
{"client_id": "https://chatgpt.com/oauth/client.json", "client_name": "ChatGPT",
 "redirect_uris": ["https://chatgpt.com/connector_platform_oauth_redirect"],
 "token_endpoint_auth_method": "private_key_jwt",
 "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
 "token_endpoint_auth_signing_alg": "RS256",
 "jwks_uri": "https://chatgpt.com/oauth/jwks.json",
 "grant_types": ["authorization_code", "refresh_token"], "response_types": ["code"]}
```

Our authorization server advertises `client_id_metadata_document_supported:
true` (`api/oauth.js`, `serverMetadata`), so ChatGPT will use this document.
And `documentClient` refuses any document whose `token_endpoint_auth_method`
is not `"none"`: *"A document cannot carry a secret, so it is a public client
or nothing."* ChatGPT's says `private_key_jwt`, so `/oauth/authorize` would
find no client and the connection would fail before the person sees our
sign-in. Claude's documents say `"none"`, which is why Claude works.

The rest already fits: S256 PKCE, `resource`, RFC 9207 `iss` (so ChatGPT uses
the stable return address, which `returnAddressAllowed` takes), refresh
tokens, the 401 with `resource_metadata`, streamable HTTP, annotations.

So the relay unit (P1, section 10):

1. **Take ChatGPT's document.** Best: verify `private_key_jwt` (RFC 7523): at
   the token endpoint, a `client_assertion` JWT signed RS256 by a key in the
   document's `jwks_uri` (read and kept an hour, as documents are), `iss` and
   `sub` the client id, `aud` our token endpoint, a fresh `jti`; and say
   `private_key_jwt` in `token_endpoint_auth_methods_supported` with
   `token_endpoint_auth_signing_alg_values_supported: ["RS256"]`. That proves
   the caller is ChatGPT. The smaller fallback: a document whose
   `token_endpoint_auth_methods_supported` lists `"none"` is kept as a public
   client, PKCE being the proof, as Claude's is.
2. **Say who is asking.** `web/authorize.html` says "Claude" in its title and
   copy; `clientLabel` (`api/_oauth.js`) knows Claude and Claude Code. Both
   name ChatGPT (by `chatgpt.com`) and any other client by its document's
   `client_name`. On-screen words: the lead's brief names them.
3. **Tell people how**: `docs/CONNECTING.md` and the FAQ gain the ChatGPT
   steps below; the app's Connect Claude gains a sibling (words the lead's).

### The steps a person takes (once P1 is live)

1. In ChatGPT: **chatgpt.com/plugins**, the **+** button, **Add custom MCP
   server**.
2. Name: Brickworks, a description. Connection: a public endpoint,
   `https://brickworks.diy/api/mcp`. Authentication: OAuth.
3. Read the risk warning, **I understand and want to continue**, then
   **Create as a plugin**.
4. ChatGPT opens Brickworks' sign-in ("Let ChatGPT build in Brickworks?",
   back to chatgpt.com): the email code, then **Allow**.
5. Review the 63 tools ChatGPT found, install the plugin.
6. With Brickworks open in a browser tab and signed in, a new ChatGPT chat,
   `@` and **Brickworks**: "build a small red house in Brickworks". The tab
   listens by itself once the account has any connection
   (`ClaudeConnector`, as for Claude).

These are in `docs/CONNECTING.md` too, with what is known only once the
owner's account has done it.

### Other MCP clients

- **Gemini.** The consumer app is reported to take a custom remote MCP server
  under Settings, Connected Apps, since mid-2026 (third party,
  <https://skillsplayground.com/integrations/gemini/>), and one developer
  reports its dynamic registration never reaching the token endpoint
  (<https://discuss.ai.google.dev/t/gemini-spark-custom-mcp-oauth-stops-after-302-callback-and-never-calls-token/177327>).
  Gemini Enterprise wants a client made by hand with a fixed return address
  (<https://docs.cloud.google.com/gemini/enterprise/docs/connectors/custom-mcp-server/set-up-custom-mcp-server>);
  Gemini CLI takes MCP servers with OAuth in `~/.gemini/settings.json`. Worth
  a test with the owner's account after P1, not a unit of its own.
- **Mistral Le Chat**: custom MCP connectors with OAuth, by an admin of the
  workspace (Mistral's help, <https://help.mistral.ai/en/articles/393572-configuring-a-custom-connector>;
  details third party). Same: a test after P1.
- **Cursor, VS Code, Codex, Claude Code**: MCP clients with DCR or CIMD; the
  relay serves them as it serves Claude Code. Nothing to build.

## 4. Bring your own key

### 4.1 The APIs

| | Tools go as | A call and its answer | A picture in a tool's answer | Reasoning between turns | Read |
|---|---|---|---|---|---|
| **Anthropic Messages** | `tools[].input_schema` (JSON Schema) | `tool_use` id, `tool_result` with `tool_use_id` | Yes: image blocks in `tool_result` (the in-app assistant does it today) | thinking blocks sent back with their signatures | `src/ai/assistant.gd`, `src/ai/stream.gd` |
| **OpenAI Chat Completions** | `tools[].function.parameters` | `tool_calls[].id`, then a `role: "tool"` message per call | **Not documented**: the guide shows pictures as function output for Responses only | not carried | <https://developers.openai.com/api/docs/guides/function-calling> |
| **OpenAI Responses** | `tools[]` functions | `function_call` `call_id`, `function_call_output` | Yes: `output` as an array with `input_image` ("we've updated function calling to support files and images as tool call outputs", 2025-09-26) | reasoning items kept with the response | same, and <https://community.openai.com/t/images-and-files-as-function-call-outputs/1360081> |
| **Gemini** | `functionDeclarations` ("Only a subset of the OpenAPI schema is supported") | `functionCall`, `functionResponse` | Gemini 3 and later: "you can include multimodal content in the function response parts" | thought signatures, sent back "exactly as received" | <https://ai.google.dev/gemini-api/docs/function-calling> |
| **OpenAI-compatible servers** (OpenRouter, Groq, Together, Mistral, DeepSeek, Gemini's `/v1beta/openai`, Ollama, LM Studio, vLLM) | as Chat Completions | as Chat Completions | as Chat Completions: none; pictures in user messages, where the model sees | none | each server's own page |

So the transcript the loop keeps (`src/ai/provider.gd`) holds MCP's own
content blocks, and each adapter puts pictures where its API takes them.
Chat Completions (built): the tool message says "(N pictures, in the next
message)" and one user message after the turn's answers carries them, each
named by its call. Responses and Gemini: in the answer itself. Anthropic: as
`tool_result` blocks.

### 4.2 The tools, translated

The MCP schemas use `type`, `properties`, `required`, `enum`, `items`,
`minItems`, `maxItems`, `minimum`, `maximum`, `description` and
`additionalProperties` (counted over `tools/mcp_tools.json`). All 61 names
already match OpenAI's `^[a-zA-Z0-9_-]{1,64}$`.

- **Chat Completions and Responses**: the schema as it is, not strict mode.
  Strict needs every property required and `additionalProperties: false` on
  every object; most of ours have optional properties.
- **Anthropic**: as it is (`input_schema`), as the in-app assistant sends.
- **Gemini's own API**: the OpenAPI subset. The adapter drops what Gemini
  refuses and keeps the rest; its unit's probe sends all 61 to the real API
  and fails on any refusal, so the list of what to drop is measured, not read.

**Size.** The 61 tools are 167 KB of compact JSON, about **42,000 tokens**, on
every request. A provider that caches the start of a request makes that
cheap after the first (OpenAI caches automatically: GPT-6.1 Sol's cached input
is $0.10 a million against $2,
<https://developers.openai.com/api/docs/models/gpt-6.1-sol>; Anthropic's
`cache_control`; Gemini's implicit cache). The loop keeps the start of the
conversation still (4.4) so the cache holds. A model with 32,000 tokens of
room cannot take the list at all: a smaller set of core tools is unit P7.

### 4.3 Streaming

The slice asks for whole replies. The person still watches the model being
built, call by call, since each call changes the window. Streaming each API
(OpenAI's `delta.tool_calls[].function.arguments` fragments, Anthropic's events
as `Streamer` reads them, Gemini's `streamGenerateContent?alt=sse`) is unit P4,
with the bricks of a `submit_design` drawn as they are written, as the in-app
assistant does (`Assistant._sketch_one`).

### 4.4 Long sessions

A design from outside makes 70 to 200 calls (`docs/BRICKBENCH.md`). The loop
(`src/ai/designer_loop.gd`):

- caps a design at 200 replies;
- keeps the newest 6 pictures: past 12, all but the newest 6 become a line
  of text at once, so the start of the conversation changes seldom and the
  provider's cache holds;
- past a million characters (about 250,000 tokens) cuts every answer before
  the newest dozen turns to its first 400 characters;
- waits for a long call itself: a call that answers "Started job N" is
  followed with `job` until it ends, and the model is handed the call's own
  answer, spending no turns asking after it;
- asks again, up to four times with a growing pause, on a dropped connection,
  a rate limit or the provider's own fault; a refused key or unknown model
  ends the design with words saying so.

The current models have room: GPT-6 and 6.1 1,050,000 tokens, Gemini 4 Argon
"a unified 1M context window", Claude Sonnet and Opus 5.5 1,000,000 (OpenAI's
models page; Google's models page, <https://ai.google.dev/gemini-api/docs/models>;
OpenRouter's model list, 2026-10-29).

### 4.5 Where the loop runs: the desktop

In the app, as the slice does: requests go from the person's machine to the
provider's address with their key. Nothing of ours is in the path.

### 4.6 Where the loop runs: the web, and CORS, measured

A Godot web build's requests are the browser's `fetch`, so a provider has to
answer a page from brickworks.diy. Asked 2026-10-29 from this machine, a
preflight (`OPTIONS`, `Origin: https://brickworks.diy`, POST with
`authorization, content-type`, plus each API's own key header), and a POST
with no key to see that the refusal is readable too:

| Provider | Preflight | `Access-Control-Allow-Origin` | The keyless refusal readable |
|---|---|---|---|
| OpenAI `/v1/chat/completions`, `/v1/responses` | 200 | the origin, or `*` | yes (401, `*`) |
| Anthropic `/v1/messages` | 200 | `*` | **only with** `anthropic-dangerous-direct-browser-access: true`, which the app sends on the web (`Assistant._send`) |
| Google `generativelanguage.googleapis.com` (native and `/v1beta/openai`) | 200 | the origin | yes (403, the origin) |
| OpenRouter | 204 | `*` | yes |
| Groq | 204 | `*` | yes |
| Together | 200 | `*` | yes |
| Mistral | 200 | `*` | yes |
| DeepSeek | 200 | the origin | yes |
| xAI, Cerebras, Fireworks | 200 | `*` | not asked |

Every hosted provider tried answers the page. So **the loop runs in the
browser and calls the provider directly**; no pass-through. A pass-through
would put every key through a function of ours, where one logging line is a
breach, and would make us its keeper in law and in fact. Built only if a
provider people ask for ever refuses browsers, and then streamed through,
never logged, never kept, and said so.

**A model on the person's own computer, from the web**, is harder and is not
promised there: Ollama allows only its own origins unless `OLLAMA_ORIGINS`
names more ("Ollama allows cross-origin requests from 127.0.0.1 and 0.0.0.0
by default", <https://docs.ollama.com/faq>), and Chrome since 142 asks the
person's permission before a public site reaches `localhost` (Local Network
Access, <https://developer.chrome.com/blog/local-network-access>, as reported
by <https://blog.openreplay.com/chrome-local-network-access-lna-permission/>).
Local models are a desktop feature; the web's panel says how, for those who
want it anyway.

### 4.7 The key

Recommended, and what the slice does (`src/ai/provider_settings.gd`), as
`OwnKey` keeps an Anthropic key today:

- **Local only.** One file per provider in the app's own data on the desktop
  (`user://provider-openai.key`), encrypted (`FileAccess.open_encrypted_with_pass`)
  with a password made of this computer's id and a salt the app made once,
  so a copy taken elsewhere cannot be read (aiset345); in the browser, the same
  path, which the web build keeps in the site's storage, where there is no
  computer id and the encryption only scrambles it, as the panel says. Or
  **for this visit only**, kept nowhere. Forgetting it deletes it.
- **Never on our server**, not even encrypted: a key we can decrypt is a key
  we hold. The plans' `/api/builds` count (section 7) never sees it.
- **Shown as a fingerprint** (`sk-pro…abcd`), never whole, in the panel and in
  every log (the probe checks the run's log for the key).
- **Checked before use**: the provider's prefix where it has one, and a
  Claude plan's sign-in token refused with the way to use the plan instead.
- Said plainly in the panel: anything running as the person can read the
  file. A key with a spending limit (an OpenAI project budget, an OpenRouter
  key limit) is the advice.
- An operating system keychain on the desktop would be better than a file;
  Godot has no API for one, so it is a GDExtension, later if asked.

## 5. Which models can design here

What a model needs, from what the tools ask of it:

1. **Tool calling**, reliably, for 70 to 200 calls, with arguments that are
   long JSON (a `submit_design` runs to thousands of parts). Without it,
   nothing can be built.
2. **Vision**: `view_model` answers with pictures, and the fresh look is three
   pictures and a question about them. A model that cannot see designs blind
   and answers the fresh look by guessing.
3. **Room**: about 42,000 tokens of tools before the brief, and a long
   design's conversation after it. 256,000 tokens is comfortable; 128,000 is
   the least.

**The tiers.**

| Tier | Models (2026-10-29) | How it got there |
|---|---|---|
| **Supported** | Claude Opus 5.5, Sonnet 5.5 (today's paths); OpenAI GPT-6 Astra, GPT-6.1 Sol; Google Gemini 4 Argon, Gemini 3.8 Flash | Each provider's flagship and its agentic tier, all with tools, pictures and a million tokens (OpenAI's and Google's model pages). **Not yet measured here**: each is labelled supported only once it passes a bench subset (P6) |
| **May work** | Any other model whose provider lists tool calling and image input, with 128,000 tokens or more: GPT-6.1 Terra, Qwen 3.8 Max, Mistral Large 4, Grok 4.7, Kimi K3.1 Pro, GLM 5.3, DeepSeek V4.1 Flash, and local ones through Ollama or LM Studio | OpenRouter lists 277 of its 457 models with both (`supported_parameters` has `tools`, `input_modalities` has `image`, read 2026-10-29 from `openrouter.ai/api/v1/models`) |
| **Tools but no pictures** | Allowed, with a warning before the design: it builds without seeing and the fresh look is let go of | |
| **No tools** | Refused at Test, with why | |

**How the app tells a person.** Three ways, in order of cost:

1. What the provider says, where it says it: OpenRouter's model list (tools
   and image input per model, as above); for a server on the person's
   computer, whatever its own listing says of a model (Ollama's and LM
   Studio's, which P7 reads and checks against Test).
2. **Test**, beside the model in the panel: two small requests, one that must
   call a tool, one with a 32-pixel picture of one colour to name. It says
   "Calls tools: yes. Sees pictures: yes." or what is missing, in words, and is
   kept per provider and model. Less than a cent.
3. In the design: a model whose first reply calls no tool, or whose reply is
   cut off, ends the design with words saying which (the slice does this).

## 6. The settings, in the app and on the site

In the app: **Settings, Assistant (AI)**, where Claude is today. One question
first, then only what it needs:

- **Who designs**: Claude, on your plan (Connect Claude; My Claude on the
  desktop), or a model on your own key.
- On your own key: **Provider** (the presets of `ProviderSettings.PRESETS`, and
  "another OpenAI-compatible server"); **Model** (a list to pick from, best
  first, and a field for any other id); **Key** (a password field, Show,
  "Remember on this device", the fingerprint once kept, Forget);
  **Address** (shown for a server on this computer or another server, under
  Advanced for the hosted ones); **Advanced**: reasoning effort where the model
  takes it, the most a reply may write, and the room the conversation may
  take; **Test**.
- The chat panel's send works as it does, with whoever is chosen; while a
  model on a key designs, the toolbar says so, as it says "Claude working".

On the site: no key is ever asked for or typed on brickworks.diy's pages.
The FAQ and the docs say what the app offers and how; the web app's panel is
the app's own. The panel uses the shared controls and look
(`docs/DESIGN_SYSTEM.md` for the site, the app's own theme in the app): every
field labelled, the order a keyboard takes, a problem said beside its field in
words (never by colour alone), and Test's answer in words.

All of this is on-screen interface, so the words are the lead's to name in
P2's brief (AGENT_RULES, "The product").

## 7. How builds are counted

The plans (`docs/PLANS.md` on plans332, sections 1, 3 and 5): a **Claude
build** is "one stretch of Claude working on a model in one tab or window:
from Claude's first change there until 30 minutes pass without a call", counted
at the relay (`api/mcp.js`, a stretch's first call not marked read-only); the
in-app own-key path asks `POST /api/builds` before a run on the web; "Desktop
builds count only through the relay".

Each new path, against that:

| Path | Counted | Same as the plans? |
|---|---|---|
| ChatGPT, or any connector client | At the relay, by the stretch, whatever the client | **Yes**: the relay counts calls to a tab, not who makes them. Checked in P1 (chatgpt344): the only thing the relay does differently for a client that is not Claude's is the shape of `tools/list` (`portable`); a call's routing, its tab and the `readOnlyHint` a stretch is judged by come from the tab's own list, the same for every client, so U2's count applies to ChatGPT unchanged |
| A model on the person's key, web | `POST /api/builds` before a run, as the own-key Anthropic path | **Yes** |
| A model on the person's key, desktop | Not counted: the desktop is Pro, and Pro has no limit | **Yes** ("Desktop builds count only through the relay") |

**The amendment:** the name. "Claude builds" stops being true the day ChatGPT
or a key of OpenAI's builds one. Admission's product is not created yet
(PLANS section 10, "Status, 2026-10-29: not created"), so before U0 runs:
the feature is `ai_builds`, "AI builds", and the words people see say "builds
with AI" ("Free has 10 AI builds a month"). Nothing else in the plan changes.
P9 makes that edit in PLANS.md.

## 8. The architecture

```
  provider's API  <-- HTTPS, the person's key -->  Provider adapter
  (OpenAI, Gemini,                                   OpenAIChat (built)
   Anthropic, a                                      AnthropicMessages, OpenAIResponses,
   server here)                                      GeminiNative (one file each, next)
                                                          ^
                                                          | the transcript: MCP's own blocks
                                                          v
                                                     DesignerLoop (src/ai/designer_loop.gd)
                                                          |  initialize, tools/list, tools/call
                                                          v  (in process: no port, no relay)
                                                     CommandSocket.answer_rpc
                                                          |  the same calls Claude makes
                                                          v
                                       Assistant tools, AppTools, ToolJobs, FreshEyes
```

- `src/ai/provider.gd`: `Provider`, the adapter's two methods (`request`,
  `read`), the transcript's shape, and what a refusal is said as.
- `src/ai/openai_chat.gd`: `OpenAIChat`, Chat Completions.
- `src/ai/provider_settings.gd`: `ProviderSettings`, the presets, the key's
  keeping and checking, the choice of provider and model.
- `src/ai/designer_loop.gd`: `DesignerLoop`, the loop, with the signals
  `ClaudeCode` has (progress, said, finished), so whatever shows one shows
  both.
- `Main.design_with_provider(brief, provider)`: starts it on the app's one
  MCP server (the port's, else the tab's connector's, else one of its own that
  listens on nothing), refusing while Claude Code or another design runs.
  `--ask-provider=BRIEF --provider=ID --provider-model=M --provider-base=URL
  --provider-effort=E` drives it from a command line, as `--ask-claude-code`.

An adapter is one file with two methods, and a preset is one row. Nothing of
the Claude paths changed: no tool, no instruction, no answer
(`mcp_sync_probe`, `fresh_eyes_probe`, `connector_method_probe` pass as
before).

**The proof.** `src/dev/provider_loop_probe.gd` (windowed, for the pictures),
with `tools/provider_stub.py` as the provider: an OpenAI-compatible model that
scripts a design (two calls in one reply, submit, look, save, answer the fresh
look, save again, a last word) and is as strict as OpenAI about tool calls
answered in order, pictures as data URLs and the tool list's shape. Its first
answer is a rate limit. The probe checks the model is built, the fresh look
asked and answered in the judge's shape, the design saved, every request
carrying the key, the app's instructions and all its tools, view_model's
picture and the fresh look's three reaching the model, and the key in no log.
Then a design stopped while a slower stub thinks ends once, as stopped, and
the next one is answered by nothing of the stopped one's.
No key for OpenAI, OpenRouter, Gemini, Groq, Mistral, DeepSeek, Together or
xAI was in `.env` on 2026-10-29, so no real model was run; with one,
`--ask-provider` runs a real design (section 9). The command line itself was
run against the stub, headless: `provider ok=true bricks=6 replies=7 calls=7`,
the model written to `--out` with its 6 parts, the key shown only as its
fingerprint (headless there are no pictures, so the fresh look is not asked,
as on any headless run).

## 9. Running it by hand

```sh
# a real model, the key from the environment (never printed: a fingerprint is)
OPENAI_API_KEY=… godot --path . -- --ask-provider="a small red lighthouse" \
    --provider=openai --provider-model=gpt-6.1-sol --out=lighthouse.ldr

# any OpenAI-compatible server, here the stub
python3 -I tools/provider_stub.py --port 9621 --log stub.jsonl &
OPENAI_API_KEY=sk-stub-key-for-a-test-only godot --path . -- --ask-provider="a red tower" \
    --provider=openai --provider-base=http://127.0.0.1:9621/v1
```

## 10. The work left, in order

Each is one agent's unit from `origin/main`, ending in the lead's merge.

**P1. ChatGPT on the relay.** `api/oauth.js` takes ChatGPT's client document
(`private_key_jwt` verified against its `jwks_uri`, or as a public client
where its document allows `none`), says so in the metadata, and the consent
page and `clientLabel` name the client. CONNECTING.md and the FAQ gain the
steps. *Bar:* `tools/web/oauth_probe.mjs` drives the whole sign-in with
ChatGPT's real document and a test key standing in for its signing key
(a refusal for a bad signature, a wrong `aud`, a reused `jti`); Claude's two
documents pass as before; on a preview, the owner's ChatGPT account connects
and builds a small model, the lead or owner watching (a real account, by
hand).

*Done (chatgpt344, 2026-10-29), but the owner's real connection.* A client
whose document prefers `private_key_jwt` must sign: RS256 by a key at its
`jwks_uri` (https, the document's own origin), iss = sub = client_id, aud this
server's issuer or token endpoint, exp within the hour, jti spent once
(`api/_assertion.js`; `oc_spend` under `oauth:` keys). A document that lists
methods with no preference is a public client when it lists `none`, its
assertion checked if sent. Registration takes `private_key_jwt` with inline
`jwks`. `supabase/oauth_keys.sql` (applied, additive) keeps `jwks_uri`,
`jwks` and the new `auth_method`; Claude's rows never name them. The
metadata lists `private_key_jwt` and RS256. Any client but Claude's gets the
tool list with every array's `items` said (OpenAI refuses `attach.align`'s
bare array) and all three hints. Proofs: `tests/test_oauth_clients.py` (16),
`tools/web/chatgpt_flow.mjs` (check `chatgpt`: ChatGPT's real document up to
its signature, then a key-holding stand-in all the way to a call in a tab),
`oauth_probe.mjs` unchanged. The own-key OpenAI adapter
(`src/ai/openai_chat.gd`) sent the same bare array, which OpenAI's API
refuses ("array schema missing items"); it now sends the same portable list
(`Provider.portable`), which `provider_loop_probe` holds to the relay's for
all 61 tools, against a stub that refuses a bare array as OpenAI does.

**P2. The settings panel (desktop).** Section 6, with Test. The chat panel
designs with the chosen model. *Bar:* a probe drives the panel (choose,
keep, forget, Test against the stub, design); the panel at 1024 and 1400 in
light and dark; on-screen words as the brief names them.
*Built (aiset345):* Settings, AI… (`src/ui/ai_settings.gd`), Test
(`src/ai/model_test.gd`), the column designing with it; `ai_settings_probe`.

**P3. Three more adapters.** `AnthropicMessages` (pictures in `tool_result`,
thinking blocks sent back, `cache_control`), `OpenAIResponses` (pictures as
`input_image` in `function_call_output`, reasoning items kept; the default for
OpenAI's own models), `GeminiNative` (the schema subset, thought signatures,
multimodal function responses). *Bar:* for each, a stub scripted as
`provider_loop_probe`'s, strict as that API is; and one real design each where
a key exists, printed with its numbers.
*Built (aiset345):* `AnthropicMessages` and `GeminiNative` (not yet Responses),
`provider_apis_probe` against `tools/provider_stub.py`'s two strict APIs. A real
Test of Claude Sonnet 5.5 on the Anthropic key in .env: tools and pictures
(2026-10-29). No real design yet; no Gemini key.

**P4. Streaming**, per adapter, with a `submit_design`'s bricks drawn as they
are written. *Bar:* the stub streams; the probe sees bricks before the reply
ends, and the whole reply equal to the unstreamed one.

**P5. The web.** The loop in the browser on the person's key (CORS as 4.6),
the key in the site's storage or for the visit, and `POST /api/builds` before
a run once the plans' U2 has it. *Bar:* a browser flow against the stub served
on localhost, wired in `tools/release/preview_checks.sh` (marked local only,
since a deployed page cannot reach the stub), and one real provider's
preflight checked from a preview.

**P6. The tiers, measured.** A bench subset (tune's first 8) on GPT-6.1 Sol,
Gemini 4 Argon and one "may work" model, against Claude Sonnet 5.5 on the same
night; "supported" only within the noise floor of Claude's score. *Bar:* the
numbers, and the presets' model lists ordered by them. An hour or more: the
lead runs it from the unit's command.

**P7. Small rooms.** A core set of tools (search, submit, check, edit, view,
review, save, fresh_eyes, job, read_guide) and smaller budgets, for a model
under 128,000 tokens. *Bar:* a local model through Ollama or LM Studio on
this machine builds a small brief end to end.

**P8. Saying who designs.** The history's steps and the toolbar say "Claude's
design" and "Claude working"; a model on a key gets its own name there. *Bar:*
the words the lead names, in the probe that reads them.

**P9. The plan's word.** `docs/PLANS.md`: `claude_builds` becomes `ai_builds`,
"AI builds", before U0 creates the product. *Bar:* the dry run of section 10
shows the new name.
