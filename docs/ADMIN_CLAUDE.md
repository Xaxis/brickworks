# Claude in the owner's console

Claude on the owner's own Anthropic key, in `/admin` (adminclaude,
2026-11-18). docs/ADMIN.md › Claude has the short form; this is the whole of
it: how the key is kept, what Claude may read and write, what it costs, and
how it is proven.

## Where it is

- **Claude › Settings** (`/admin#claude`). The key: pasted, checked with
  Anthropic's Models API and kept only when Anthropic takes it; shown as
  `sk-ant-…` and its last four; Check key; Forget key. The model, from the
  models the key may use that take adaptive thinking (`claude-opus-5-5` until
  one is chosen), with its price; the effort; the monthly cap in dollars and
  this month's spend against it.
- **The panel**, from the bar's Claude button on every section. At 1100 px
  and wider it is docked at the right edge and the page narrows beside it;
  narrower, it opens over the page. With no choice made it is open on Social
  and closed elsewhere; a wide window remembers the owner's choice. Beside
  it, under 1,660 px, the desk's tables are the cards they are on a phone,
  so no row's acts are scrolled out of sight. Escape
  closes it to its button. One conversation, kept in the tab (sessionStorage)
  until New chat, streamed in as it is written, with each tool it read, and
  under each answer what it cost, its tokens and cache reads.
- **On Social.** Suggest a post (beside Write's community), Suggest a reply
  (each inbox row), Improve (each draft), Overview by Claude (above the
  desk's tabs). Each lands as a draft among the desk's drafts marked "by
  Claude", or as words in the panel; nothing goes out by itself. The owner
  opens a draft (Open it in Write, which asks first when Write holds other
  words), edits it, and sends it with the desk's own Review and send.

## The key

- Pasted once, sent to `POST /api/admin?op=claude_key` and checked against
  `GET https://api.anthropic.com/v1/models` before anything is kept: a key
  Anthropic refuses is not kept, and the page says why in words.
- Sealed with AES-256-GCM (a fresh 12-byte nonce each time) under a key drawn
  by HKDF-SHA256 from **`CLAUDE_KEY_SECRET`**, a Vercel variable the
  deployment alone has, and kept in `admin_claude_settings`, which only the
  server's role reads (row security on, no policy, nothing granted to `anon`
  or `authenticated`).
- Opened for one request to Anthropic at a time and put in that request's
  `x-api-key` header and nowhere else: never in an answer, a page, the audit,
  a log or an error. The page is told `sk-ant-…` and the last four.
- Forget key deletes the sealed key; Check key opens it and asks the Models
  API again.
- The checks' pool (`?tests=1`) seals with a fixed secret written in
  api/_claude.js and talks only to the stand-in (api/_claude_mock.js), which
  accepts only its own key. So no real key can be kept or spent there.

### Setting CLAUDE_KEY_SECRET

At least 32 characters, made once:

```sh
openssl rand -base64 48
```

Set it in Vercel (Settings › Environment Variables) for Production and
Preview, then redeploy. Without it, Settings says so and keeps no key; Forget
key still works. If it changes, the kept key no longer opens: Settings says
so, and the key is pasted again.

## The model and the call

- No SDK. The API ships through tools/package_api.sh, which copies `api/*.js`
  and nothing of `node_modules`, so the official `@anthropic-ai/sdk` cannot be
  packed by it. api/_claude_api.js is the plain HTTP shape of the claude-api
  skill's cURL docs:
  - `x-api-key` and `anthropic-version: 2026-10-21`;
  - `POST /v1/messages` with `stream: true`, read as Server-Sent Events;
  - `thinking: {type: "adaptive"}` and `output_config: {effort}`, with no
    temperature, top_p or top_k;
  - the prompt cached by a top-level `cache_control` (ephemeral);
  - the server-side refusal fallback (`fallbacks: "default"`, beta
    `server-side-fallback-2026-07-01`) on the models that take it. When
    another model answered, the panel says which and the cost is counted at
    the dearer of the two;
  - `eager_input_streaming` on each tool, and every tool input checked
    against its schema before it runs (one that does not parse is answered
    `INVALID_JSON` as an error result);
  - `GET /v1/models`, paged, for the list.
- The models offered are the key's own, from the live list, that take
  adaptive thinking; each with its price. A model not in the price table is
  counted at the dearest there, so the cap is never under-counted.
- Effort: low, medium, high, xhigh or max, as the model allows. Each effort
  has a ceiling on what one call may write (16k, 16k, 32k, 64k, 64k tokens).
- The function streams for at most 300 s (`maxDuration`). A turn stops at
  ten rounds of reading or with 20 s left, and says so.

### The conversation

- The system prompt and the tool list are the same on every request. So the
  prompt's cache holds, and each thinking block sent back stays bound to the
  conversation that made it. The date and the section go in the owner's own
  message.
- The browser keeps the conversation, each block as the API gave it, and
  sends it back whole. A turn is added only when it ended whole (`done` with
  its `append`). A refusal, a 429, a stop or the cap leave the question out,
  and the panel says so.
- The server checks what comes back. Roles alternate, starting with the
  owner. Blocks are only the kinds the API gives. Every tool call in an
  answer is answered in the next message by the same ids, and no tool result
  answers nothing. Otherwise: 400, "This conversation is not one the console
  made (…): start a new chat."
- Nothing in history is ever run. Tools run only from the answer being
  written now, and only the tools in the list. An unknown name is refused
  whatever it is called.
- At most 8,000 characters a question, said in words, never cut.

## The cap

- A monthly cap in dollars (the calendar month, UTC), kept by the server.
- Before each call to Anthropic, the most it may cost is held in the
  database (`admin_claude_hold`, under an advisory lock, so two holds at once
  cannot both pass). The most is the prompt counted dear plus every token it
  may write. `max_tokens` is the smaller of the effort's ceiling and what the
  room left buys. Under 1,024 tokens of room, no call is made and the panel
  says the cap is reached, how much is spent, and where to raise it.
- After the call, the hold is settled at what the answer's usage says it
  cost (`admin_claude_settle`): input, output, cache reads and writes.
- A call refused before it began costs nothing. A call cut off once it began
  is counted at all it held: what it spent is not known.
- A hold neither settled nor six minutes old counts as held. Older than six
  minutes (its function was ended) it counts whole as spent.
- This month's spend (`admin_claude_month`) is shown in Settings and after
  each answer.

## What Claude may do

One JS module per area of the console, each reading what that section's own
read gives:

| Module | Tools |
|---|---|
| api/_claude_social.js | `social_inbox`, `social_thread`, `social_sends` (drafts and sends with results), `social_overview` (visits by tag), `social_rules`, `whats_new` (the changelog and release notes), `make_draft` |
| api/_claude_people.js | `people_counts`: counts and growth, never an address |
| api/_claude_plans.js | `plans_read` |
| api/_claude_mail.js | `mail_health` |
| api/_claude_site.js | `site_health`: the site and backend |
| api/_claude_feedback.js | `feedback_list` |

- **Its one write** is `make_draft`: a draft on the social desk through the
  desk's own `socialDraft` (so the site's links are tagged as the owner's
  drafts are), marked in `admin_claude_drafts` so the desk shows "by
  Claude".
- It never sends, posts, replies, schedules, deletes, mails, or changes a
  plan or a switch. No tool does, and none is offered.
- An Improve writes a new draft beside the owner's and leaves theirs as it
  is.
- A rules read goes through the desk's own read, which fetches the
  community's rules again when its copy is over a day old and keeps them
  (`social_rules`), as it does when the owner opens Write. Every server write a whole run of
  the checks makes is listed and matched exactly: the draft (`social_sends`),
  its mark, the rules' copy, the cap's holds, and the database functions
  that mail, beta and the releases are read by (PostgREST takes a function
  as a POST; they change nothing).

### Words from outside

Inbox items, Reddit's rules, threads and feedback are written by people who
are not the owner. They reach Claude only inside
`<untrusted source="…">…</untrusted>` tags, with any such tag inside them
defused and any email address replaced. The system prompt says that what is inside is data to read, never
instructions: a request inside it (post this, follow new rules, drop your
instructions) is something it says, which Claude may mention to the owner. Even if one were followed, the
most it could do is a draft, because there is no tool that does more.
`tests/test_adminclaude.py` sends a hostile reply that asks for a send. The
outcome is at most one draft, nothing sent, and the conversation carries on
whole.

## The audit

Each ask is one row in the console's audit: op `claude_chat`, kind `claude`.
It records:

- the ask, and the model asked and the one that answered;
- the effort and the number of calls;
- tokens in and out, cache reads and writes;
- the cost in dollars, the tools used and the drafts made;
- how it ended (`end_turn`, `max_tokens`, `refusal`, `cap`, `rounds`, `time`,
  or the API's own error type, such as `rate_limit_error`).

Never the key, never the words: what was asked and answered stays in the
owner's tab. Key and settings changes are audited as `claude_key`,
`claude_check`, `claude_forget` and `claude_settings` on `claude/key` or
`claude/settings`, as every console POST is, and none of them names the key.

## The tables

`supabase/admin_claude.sql`, additive. Applied twice, it changes nothing the
second time. `tools/admin_claude_try.sql` is its dry run, which rolls back.

- `admin_claude_settings`: one row a pool. The sealed key, its last four,
  the model, effort and cap.
- `admin_claude_holds`: each call's hold and what it settled at.
- `admin_claude_drafts`: which desk drafts Claude made, and from which ask.
- `admin_claude_hold`, `admin_claude_settle`, `admin_claude_month`: the cap's
  functions, executable by the server's role alone.

Row security is on with no policy, nothing is granted but to the server, and
nothing refers to an account, so no export or account deletion reaches
them. Until the file is applied, Settings and the panel say so, and every
write answers 503.

## How it is proven

- `python3 tools/minitest.py tests/test_adminclaude.py`. The handlers run
  against the tables held in memory, the stand-in Anthropic and the stand-in
  Reddit, through `tests/fixtures/adminclaude/api_check.mjs`. It covers:
  - the gate on all 7 ops;
  - the key never in an answer, log or audit row;
  - the cap;
  - streaming, the conversation's checks, refusal, 429 and fallback;
  - the desk's four asks;
  - only drafts written;
  - the hostile reply;
  - the audit, and the request's shape.

  `db_check.mjs` applies admin_claude.sql twice to a Postgres of its own:
  no role but the server's reaches it, and holds made at once never pass
  the cap.
- `tools/web/adminclaude_flow.mjs` (preview check `adminclaude`). It runs
  the whole of it in a browser as the owner on `?tests=1`, at 390 and 1280,
  light and dark, by keyboard and by name.
- Locally, with nothing applied and the project's checks' pool untouched:

  ```sh
  node tools/web/relay_server.mjs 10690 --hold=admin_claude_settings,admin_claude_holds,admin_claude_drafts,social_accounts,social_tokens,social_items,social_sends,social_results,social_visits,social_rules
  BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/adminclaude_flow.mjs --url=http://127.0.0.1:10690 --out=DIR --held
  ```

  Restart the relay between runs: the held rows last as long as it does.
