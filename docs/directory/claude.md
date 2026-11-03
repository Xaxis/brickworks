# Brickworks in Claude's Connectors Directory

Everything the submission at [claude.ai/directory/manage](https://claude.ai/directory/manage)
asks for, filled in, and the evidence that Brickworks meets each requirement.
Prepared 2026-11-03 (claudedir) after the owner said yes to listing it. The
owner submits; nothing here was sent.

## The owner's steps

1. Wait for the release that carries this commit, then check https://brickworks.diy/review shows "Sign in to review Brickworks".
2. At claude.ai/directory/manage choose **Submit new**, **MCP connector**, and paste `https://brickworks.diy/api/mcp`.
3. Fill each step from [The portal, step by step](#the-portal-step-by-step), uploading the icon (https://brickworks.diy/favicon-512.png) and the carousel from this folder.
4. In **Test & launch** paste [the reviewer's steps](#8-test--launch), with the password from `.env` (`grep BW_REVIEW_PASSWORD .env`).
5. Tick the seven acknowledgments, read **Review** for warnings, and submit.

## The requirements, checked against brickworks.diy

Each row was read from the live site on 2026-11-03 unless it says otherwise.
The commands and their full output are in the unit's evidence folder; the
lines that decide each row are quoted here.

| Requirement | Met | Evidence |
|---|---|---|
| A remote server over HTTPS | yes | `https://brickworks.diy/api/mcp`. Certificate from Let's Encrypt (YR2) for brickworks.diy, valid to 2026-12-18 and renewed by Vercel. |
| Streamable HTTP | yes | `initialize` by POST answers JSON with an `mcp-session-id`, protocol `2025-06-18`, capabilities `tools.listChanged`, `resources` and the MCP Apps extension `io.modelcontextprotocol/ui`. |
| OAuth 2.0, required | yes | A call with no token: `401`, `www-authenticate: Bearer resource_metadata="https://brickworks.diy/.well-known/oauth-protected-resource/api/mcp", scope="build"`. The protected-resource document names `https://brickworks.diy` as its authorization server, whose metadata has a `registration_endpoint` (DCR), `client_id_metadata_document_supported: true` (CIMD), PKCE `S256` only, token auth `none` among others, and scopes `build` and `offline_access`. claude.ai's own client signs in through it: `tools/web/oauth_flow.mjs` passes on every release. |
| Every tool has a title and `readOnlyHint` or `destructiveHint` | yes | 70 tools on the live list, none without. 30 say `readOnlyHint: true`, 12 `destructiveHint: true`, and the other 28 `readOnlyHint: false, destructiveHint: false` (they add or change without taking anything away). From this release each also carries its title on the tool itself (`Tool.title`, as Anthropic's quickstart sets it) as well as in its annotations, so a scan that reads either finds it (`tests/test_relay_hello.py`, `mcp_sync_probe`, `connector_probe`). |
| Tool names of 64 characters or fewer | yes | The longest is `how_real_sets_build_this`, 24. |
| Read and write in separate tools | yes | No tool takes a method; each does one thing (`look_at_model` reads, `edit_model` changes, `clear_model` clears). |
| No prompt injection in descriptions | yes | Descriptions say what each tool does and when to call it. Nothing fetches instructions from elsewhere: `read_guide` serves the server's own guide. |
| Frugal with tokens | yes, explained | See [How much a session hears](#how-much-a-session-hears). The instructions were cut from 31,405 tokens to 1,334; the tool list is a CAD's 70 tools and stays. |
| Every tool answers with valid input | yes | All 70 called once through the live connector from a browser tab, and all 70 answered, none with an error: [Every tool, called once](#every-tool-called-once). One limit there: in a browser tab, `brickify`'s `url=` and `print_part`'s `picture_url=` reach only the sites the page's content policy names. |
| Privacy policy | yes | https://brickworks.diy/privacy: what is collected (the address, last sign-in, the Claude apps connected, a day of network addresses), how it is used and stored (the relay deletes each message once answered; Claude's tokens are kept only as hashes), third parties, retention and deletion, and how to reach us. |
| Terms | yes | https://brickworks.diy/terms |
| Support contact | yes | https://brickworks.diy/feedback (a form, answered by email), and issues at https://github.com/Xaxis/brickworks-releases/issues. |
| Documentation | yes | https://brickworks.diy/docs/connector (connect, tabs, the 3D view in Claude) and https://brickworks.diy/docs/mcp-tools (every tool, with an example call). |
| No ads | yes | The site's content policy lets pages load from itself, its own analytics (overlook.technology, no cookies), Anthropic's API, Wikimedia, Rebrickable, Brickognize and Supabase, and images only from itself, `data:` and `blob:`. No ad network on any of seven pages. |
| Own first-party API | yes | Every call goes to Brickworks' relay and on to the person's own open Brickworks tab. |
| Not a money mover, not AI media generation | yes | A design tool. Its pictures are renders of the model, not generated by an AI model. |
| Conversation data | yes | Brickworks receives only the tool calls Claude makes and never reads chats, memory or files. |
| Nothing infringes | yes | LEGO® only as an adjective, with the Fair Play disclaimer on every page (docs/TRADEMARKS.md). In the live tool list and instructions the mark is never without its ®, apart from "the LEGO Group", and never plural or possessive. The icon is a cut cube, no brick and no studs (Decision 1). The listing below follows the same rules and names no price. |
| A test account with sample data | yes | See [The review account](#the-review-account). |
| Allowed link URIs | yes | One: `https://brickworks.diy`, which the card's Open in Brickworks opens (`ui/open-link`). |
| Carousel, 3 to 5 PNGs at least 1000 px wide | yes | See [Carousel](#carousel). |

## The portal, step by step

### 1. Connection

- **Server URL**: `https://brickworks.diy/api/mcp`
- **Users connect to different URLs**: leave unticked. One address serves everybody; each account's calls go to that account's own tab.

### 2. Tools

Nothing to enter: the 70 tools sync from the server, 30 read-only and 40
write. None should be flagged. If any is, stop and tell the lead: the fix is
on the server, not in the portal.

### 3. Listing

- **Name**: `Brickworks`
- **One-liner** (153 of 200 characters):

  > A CAD for LEGO® models. Claude designs with real parts in your Brickworks tab, checks that the model holds together, and makes its building instructions.

- **Description** (1,376 of 2,000 characters):

  > Brickworks is a CAD for LEGO® models, in your browser and on your desktop. Every part is a real part, in the colours it really comes in, placed on the stud grid and joined the way real bricks join.
  >
  > Connect it and ask Claude for a model. Claude builds it in your open Brickworks tab while you watch, then checks it as a builder would: does it hold together, which joint gives first if you pick it up, do the gears mesh and at what ratio. It draws on how thousands of real sets build each feature, so a roof, a window or a gear train is made the way the LEGO Group makes one.
  >
  > Claude can also:
  > - strengthen a weak joint without changing the look
  > - pose hinges and play a model's motions
  > - lay a picture as a mosaic, or a 3D file in bricks
  > - split a model into sections and make step-by-step building instructions with a parts list
  > - export to LDraw, BrickLink Studio, a BrickLink wanted list or a 3D file
  > - search the gallery of models people have shared
  >
  > The model shows in the chat in 3D: turn it, step through its instructions, check it, and open it in Brickworks. Every change is in your tab and one undo away, and you can take over by hand at any time.
  >
  > You need a free Brickworks account, signed in with a code sent to your email, and a Brickworks tab open at brickworks.diy/app with the assistant switched on. Brickworks sees only the calls Claude makes to it, never your chats.

- **Categories**: `Creative`, then `Education`. The directory's list is
  Commerce & shopping, Communication, Consumer health, Creative, Data &
  analytics, Developer tools, Education, Financial services, Health & life
  sciences, Legal, Media & entertainment, Nonprofit, Other, Productivity,
  Sales & marketing, Travel, Healthcare. Creative is where Canva, Figma and
  Framer are; Education for the engineering a model teaches (load, gears,
  ratios).
- **Documentation URL**: `https://brickworks.diy/docs/connector`
- **Privacy policy URL**: `https://brickworks.diy/privacy`
- **Support contact**: `https://brickworks.diy/feedback`
- **Icon**: https://brickworks.diy/favicon-512.png (`web/favicon-512.png`), 512 x 512: the cut cube in yellow, red and blue on a dark tile.
- **URL slug**: `brickworks`. Permanent once published.
- **Allowed link URIs**: `https://brickworks.diy`

### Carousel

Five PNGs in `carousel/`, each 1206 px wide and cropped to the app's answer:
Brickworks' 3D card, as an MCP Apps host shows it after `look_at_model`. Each
shows a model the example prompts built, opened in the review account's tab
on brickworks.diy on 2026-11-03 and shown in the reference host
(basic-host, from the MCP Apps SDK). Upload them in this order, each with
its prompt:

| Picture | Prompt to pair it with |
|---|---|
| `carousel/1_design.png`: the lighthouse, 312 parts | Design a lighthouse in Brickworks on a small rocky island: about 25 cm tall, a red and white striped tower, a gallery with a railing near the top, and a lamp room with clear windows. Make sure it holds together, then save it. |
| `carousel/2_check.png`: Check on, "It holds together" | In my Brickworks tab, which joints of the lighthouse would fail first if I picked it up by the top? Strengthen the weakest one without changing how it looks, and tell me what you changed. |
| `carousel/3_mechanism.png`: the winch, crank to drum at 1:5 | Start a new model in Brickworks (my lighthouse is saved): a hand-cranked winch, a crank that turns a drum through gears at about 1:5, on a sturdy stand. Simulate it turning, tell me the real ratio, and save it. |
| `carousel/4_steps.png`: Instructions, step 30 of 63, with its parts | Make building instructions for the model in my Brickworks tab: split it into steps a builder can follow, and give me the parts list with colours. |
| `carousel/5_parts.png`: Parts, 312 pieces in 50 lots, with a BrickLink wanted list | Make building instructions for the model in my Brickworks tab: split it into steps a builder can follow, and give me the parts list with colours. |

The fourth and fifth share a prompt, which asked for both: every prompt here
was run for real, and none was made up for a picture.

### 4. Use cases

- **Primary use cases**:
  1. Design a model from a description, with real parts and colours, built in the person's open Brickworks tab.
  2. Check a model as a builder would: what falls off, what gives first when it is lifted, whether gears mesh, and strengthen it.
  3. Mechanisms: gear trains at a ratio, cranks, hinges, poses and motions, simulated.
  4. Building instructions: sections, steps, the booklet and the parts list with colours.
  5. Change what the person built by hand: their selection, recoloured, moved, mirrored, split or merged.
- **What users need first**: a free Brickworks account (an email address; sign-in is by a code sent to it), and a Brickworks tab open at https://brickworks.diy/app, or the desktop app, with the assistant switched on (Tools, Settings, Assistant). The tab is where the model is built.
- **Reads or writes**: both. 30 tools only read; 40 change the model in the person's tab, each one undo away.

### 5. Company

- **Company name**: `Atypic` (the name Brickworks' terms give)
- **Website**: `https://brickworks.diy`
- **Primary contact**: your own address, the one you submit with.

### 6. Authentication

- **Authentication requirement**: required (every tool acts on the person's account and tab).
- **Authentication methods**: OAuth. Claude registers itself (its client metadata document, or dynamic registration); there is no client ID or secret for Anthropic to hold, so leave those empty.

### 7. Data handling

- **The underlying API**: our own.
- **Personal health data**: no.
- **Sponsored content**: no.

### 8. Test & launch

Paste this, with the password from `.env` where it says so:

```text
Brickworks builds in the person's own Brickworks tab, so the review needs that
tab open in your browser, signed in to the review account.

Address:  delivered+claude-review@resend.dev
Password: <the password>

1. Open https://brickworks.diy/review and sign in with the address and
   password above. Everyone else signs in with a code sent by email; this
   test address receives no mail, so the review account has a password
   instead, and this page is the only place it works.
2. Press "Open the app". Brickworks opens at brickworks.diy/app, signed in,
   with its assistant switched on. Keep that tab open: Claude builds there.
   File, Open lists the account's saved models, a lighthouse and a winch
   among them.
3. In Claude, connect Brickworks. It sends you to Brickworks to allow it;
   you are signed in already, so press Allow.
4. Ask, for example: "Open my lighthouse in Brickworks and tell me which
   joints would fail first if I picked it up by the top." Watch the
   Brickworks tab; the model also shows in 3D in the chat.

Every tool works on the model in the open tab. With two Brickworks tabs open,
Claude asks which one (tabs, select_tab). Files a tool makes (export_model,
render_model) download in that tab. In a browser tab, brickify and print_part
take a file the person picks; a link works only from a few sites there (the
desktop app fetches any link).
```

Then confirm you have run every tool: [Every tool, called once](#every-tool-called-once)
shows each called through the connector on 2026-11-03.

### 9. Compliance

All seven are true of Brickworks, each for the reason in the requirements table:

1. **Directory guidelines**: the table above.
2. **First-party API**: our own relay and the person's own tab.
3. **Financial transactions**: none. Nothing is bought or sold through the connector.
4. **AI media generation**: none. Pictures are renders of the model the person built.
5. **Prompt injection**: descriptions say what a tool does; nothing pulls instructions from elsewhere.
6. **Conversation data**: only the calls Claude makes, deleted by the relay once answered.
7. **Public documentation**: https://brickworks.diy/docs/connector and https://brickworks.diy/docs/mcp-tools.

### 10. Review and submit

Read the warnings it shows, if any, before submitting.

## The example prompts, run for real

Each was run on 2026-11-03 as a reviewer would meet it: Claude Code
(2.1.316, on a Claude subscription, no API key) connected to
`https://brickworks.diy/api/mcp` with the review account's OAuth token, its
only tools the connector's, and the review account's Brickworks tab open
and answering. The tab was this branch's app, run headless on the build
machine; a person's tab is a browser's. The prompts ran one after another
in the same tab, as one person's afternoon would, the winch last. Pictures
are the tab's own, taken after each run; the carousel shows the same models in Claude's
3D card.

### 1. Design a model

> Design a lighthouse in Brickworks on a small rocky island: about 25 cm tall, a red and white striped tower, a gallery with a railing near the top, and a lamp room with clear windows. Make sure it holds together, then save it.

6.5 minutes, 43 calls. A 312-part lighthouse, 82 plates (about 26 cm) tall, on
a grey rock island on a blue baseplate: a round tower 6 studs across in red
and white bands, a round gallery 8 studs across with a white spindled
railing, a trans-clear lamp room under a red cone roof, and a keeper with a
lantern at the foot. The app's check passed (it holds together, nothing
overloaded) and the session saved it as "lighthouse". It said what fell
short: each red band has a dark red ring (the round plates never came in
red), and the lamp room reads pale rather than lit.

![The lighthouse, from a corner](examples/1_lighthouse.png)

### 2. Check and strengthen it

> In my Brickworks tab, which joints of the lighthouse would fail first if I picked it up by the top? Strengthen the weakest one without changing how it looks, and tell me what you changed.

3 minutes, 14 calls (`weakest_joints` four times). It found the tip of the
roof weakest when lifted by the top: the 2 x 2 cone on a 2 x 2 round plate on
the 4 x 4 cone, four studs each carrying about 1.55 N of the model's 632 g,
past a stud's working load of 1 N. It added one part, a red Technic axle
inside the cones, unseen from outside, and said plainly that the axle stops
the top rocking but does not clamp it, and how to lift the model instead.

### 3. A mechanism

> Start a new model in Brickworks (my lighthouse is saved): a hand-cranked winch, a crank that turns a drum through gears at about 1:5, on a sturdy stand. Simulate it turning, tell me the real ratio, and save it.

5 minutes, 27 calls (`simulate_mechanism` three times). A 21-part winch of
57 g on a 6 x 10 plate: a red crank arm with a grey handle on the front turns
an 8-tooth gear, which drives a 40-tooth gear on the drum's axle; the drum is
two yellow 2 x 2 round bricks, and both axles turn in Technic bricks in the
stand's two sides. It turned the crank five times in the simulation and gave
the real ratio as exactly 1:5 (a fifth of a drum turn for each turn of the
crank, the other way round, through one 8-to-40 mesh), with nothing hitting
anything in either direction and the model standing in every position. It
saved it as "hand-cranked-winch.ldr". It said what it left out: a cable it
wound on the drum ran down through the plate, so it took it off, and a video
of the turning needs a window.

The prompt's first wording ("Build a hand-cranked winch...") was met with a
question rather than a model: the tab held the lighthouse, and the session
would not clear it unasked. Saying the lighthouse is saved was enough.

![The winch, from a corner](examples/3_winch.png)

### 4. Building instructions

> Make building instructions for the model in my Brickworks tab: split it into steps a builder can follow, and give me the parts list with colours.

3 minutes, 22 calls. The lighthouse in 58 steps from the bottom up (the
baseplates, the island's courses, the keeper, the tower's rings, the
gallery and the lantern, the roof), and its parts list: 313 pieces in 51
lots, 633 g, by part and colour. It wrote the steps as an LDraw `.mpd` and the
parts as a Rebrickable `.csv`. The printable booklet was refused, rightly:
the tab here had no window to draw its pictures in, which a browser tab
has (in the every-tool pass below, a browser tab drew a render and an
animation). It also found a fault:
`edit_steps` moving parts "to step 1" put them elsewhere in the list, so it
undid its own three step edits and said so.

## Every tool, called once

All 70 tools the connector lists, each called once on 2026-11-03 through
`https://brickworks.diy/api/mcp` with the review account's OAuth token, as
a client that shows MCP Apps pages, while the account's Brickworks tab was
open in a browser (Chromium) at brickworks.diy/app. Each was given the
example its page at https://brickworks.diy/docs/mcp-tools shows, apart from
three: `open_model` opened the saved lighthouse, `select_tab` named the
open tab, and `brickify` was given a real file. They ran one after another
in one chat, on whatever the calls before had left in the tab, and a call
that became a job was followed with `job` to its end, as a session does.

All 70 answered and none with an error. Where an example did not fit the
model in the tab (a minifigure with nothing under it, a section or a motion
the model does not have, nothing selected), the answer says so and what to
do instead, which is what a reviewer will meet too.

One limit is worth knowing before review. `brickify` with `url=` fetches
the file from the person's tab, and a browser tab may fetch only from the
sites brickworks.diy's content policy names, so a link anywhere else (here
raw.githubusercontent.com) fails as "Could not fetch ... (error 4)".
`print_part`'s `picture_url=` has the same limit. `pick=true` (the
person chooses the file) works in a browser, and any link works in the
desktop app.

| Tool | Time | What it answered |
|---|---|---|
| `submit_design` | 14.3 s | Built. 2 bricks on the baseplate, buildable, and what to do next. (The guidance a chat's first call carries came first, so these words are from the same call 20 minutes earlier.) |
| `add_minifig` | 2.6 s | Not placed: nothing to stand on at x 4, z 2, y 14.25 — it would stand in the air. Give the height of a floor that is there, or leave y out to stand... |
| `add_rooms` | 5.7 s | Laid 1 floor and furnished it, 17 parts, the floors held up on 2 columns. The inside is walled all round, so none of this shows: leave a side open (a... |
| `animate_model` | 26.1 s | Started job 1: Rendering Hand Cranked Winch's animation… Then: Job 1 (animate_model) is done, after 25 s: 0 keys over 1.0 s, turning round once: 12 frames, 12 a second, drawn in 24 s: downloaded Hand... |
| `attachment_points` | 1.3 s | brick 12 (3941) has 4 studs. Its footprint from above — x left to right, z top to bottom. # is a whole stud, a digit is tenths of one, . is nothing... |
| `booklet_layout` | 1.7 s | 6 pages of steps and 0 of callouts, 12 steps; as many as fit a page; the parts each step adds outlined. Then the finished model and the parts list.... |
| `break_out_section` | 0.9 s | Give section= a sub-assembly by name. There are: winch. |
| `brickify` | 4.4 s | Started job 2: Brickifying pr2_head_pan.stl. Then: Could not fetch https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/models/stl/binary/pr2_head_pan.stl (error 4). See above. |
| `check_design` | 1.0 s | overlap (2): - brick 0 (3001 at 0,0,0) overlaps a 3033 already on the baseplate - brick 1 (3001 at 2,3,0) overlaps a 3008 already on the baseplate... |
| `colour_hidden_parts` | 65.4 s | Started job 3: Finding the hidden parts of Hand Cranked Winch… Then: Job 3 (colour_hidden_parts) is done, after 63 s: 2 of the 38 parts are hidden: seen from none of 64 sides, a pixel 1.0 LDU at most. 2 would... |
| `define_motion` | 1.1 s | left door: no part or sub-assembly left door Nothing was kept. |
| `edit_booklet` | 1.5 s | set how step 4 is printed; step 4 is now: turned 90°, zoom 1.5x |
| `edit_model` | 2.4 s | Not applied — the model would not hold together. overlap (1): - brick 8 (3009 at 9,7,0) overlaps brick 6, which fills y=7 up to y=10 — so the course... |
| `edit_selection` | 1.6 s | Nothing is selected in Brickworks. Ask the person to select the parts they mean (click one; shift-click or drag a box for more), then call selection... |
| `edit_steps` | 2.3 s | 17 steps, the model's own. 1: #26 2: #28 3: #25 #27 #29 #34 4: #22 #35 #36 5: #24 #30 #32 #33 #37 6: #23 #31 #38 7: #1 8: #2 #3 #4 9: #5 #18 #19 10... |
| `evaluate_section` | 1.1 s | Give section= a sub-assembly by name, or suggestion= a suggest_sections number. |
| `export_model` | 10.8 s | Started job 4: Writing Hand Cranked Winch as a Studio file… Then: Job 4 (export_model) is done, after 9 s: Downloaded hand_cranked_winch.io. |
| `find_parts_like` | 1.2 s | Parts that read as a curved car bonnet, best first: Technic Panel Curved n x n — reads as: curved technic panel, rounded fairing, car body panel... |
| `find_reference` | 5.3 s | No pictures of "Fresnel lighthouse lantern room" came back — Wikimedia Commons answered 0. Build it from what you know of it, and look at what you... |
| `find_techniques` | 15.4 s | How real sets built castle turret roof, best first: 1. 10182-1/second-floor-roof-tower-roof-element "second floor - roof tower roof element", from... |
| `fresh_eyes` | 1.2 s | Nothing to answer: a new design's first save asks for this, once. |
| `fresh_eyes_final` | 1.0 s | Nothing to answer: the first save after the creative pass asks for this, once. |
| `gallery` | 2.4 s | The gallery at https://brickworks.diy ("lighthouse"), Top builds first (a build finished counts 3, a remix 2, the Tested mark 5), page 1: nothing... |
| `how_real_sets_build_this` | 1.7 s | STATION — measured over 122 real sets of 11700 What they are built from, and how much more often than sets in general: 3963 x17.3 Brick 2 x 1 with... |
| `in_view` | 1.1 s | What the person sees in the window: - The timeline is down: the whole model shows. - Nothing in their hand: the Select tool. - Selected: nothing. -... |
| `job` | 3.0 s | Job 1 (animate_model) is done, after 25 s: 0 keys over 1.0 s, turning round once: 12 frames, 12 a second, drawn in 24 s: downloaded Hand Cranked... |
| `lay_flex` | 0.8 s | #5 (3009) has nothing a pneumatic tube goes on: it takes pin hole, nozzle. |
| `list_motions` | 1.6 s | The model has no motions of its own yet. Suggested from what moves, each tried for room (define_motion {"name": "Turn the gears", "suggested": true}... |
| `look_at_model` | 1.4 s | 38 parts are on the baseplate. 2 of them are the parts you asked about. They span x 0..10, z 0..9.10 studs, and stand y 0..18.25 plates. Where they... |
| `look_at_picture` | 2.9 s | No picture has been chosen. Draw one as make_art's svg: big simple shapes in flat colours, one stud a pixel. |
| `make_art` | 3.5 s | The plan was not laid — 1 thing to fix: - there is no picture to work from: the person has not chosen one, so draw it and pass it as svg |
| `make_part` | 3.8 s | Made part "bw-s2x3x3r1": Slope Brick 45 2 x 3. It is in the parts library now (Custom) — use "bw-s2x3x3r1" as the part in check_design, edit_model or... |
| `make_sections` | 1.0 s | Nothing suggested: call suggest_sections first. |
| `make_unique` | 2.6 s | #14 is in no sub-assembly with other copies. |
| `measure` | 1.9 s | from= #4 (Brick 1 x 8) has no hinge; it has 7 bar, 8 hole, 7 post, 8 stud. |
| `merge_parts` | 2.2 s | Nothing merged: no real part is made of these: nothing merged (nothing changed). |
| `mirror_parts` | 2.6 s | Mirrored a copy of 3 parts left to right across x = 0: #39 to #41, beside them; the 3 stay as they were. The copy is in no sub-assembly (edit_model's... |
| `move_part` | 1.8 s | No part or sub-assembly boom here. part= takes a part's number (look_at_model) or a sub-assembly's name. |
| `parts_list` | 1.3 s | The person's collection is empty: they add their sets and parts in Build, My collection. |
| `place_technique` | 8.6 s | "posed minifigure": 12 parts, as laid; each with attach goes where it names and follows it, and its names are the model's now, for a later edit to... |
| `plan_scale` | 1.1 s | Fire engine is 10 metres along its longest side. At each scale builders use, the model would be: minifigure 20.80 studs long a minifigure fits inside... |
| `play_motion` | 0.8 s | No motion "Open the doors": the model has none yet (list_motions suggests some). |
| `pose_model` | 1.2 s | Nothing here turns: a joint is a sub-assembly on a hinge, a turntable or a clip on a bar. Name the part that turns as an assembly (edit_model's... |
| `print_part` | 1.5 s | The +z side of #12 has no flat face open for a sticker (#11 is in the way). |
| `read_guide` | 1.2 s | SAY THE SHAPE, DO NOT COUNT IT OUT Writing placements one at a time is the part of this you are worst at, and most of a model is repetition. The... |
| `render_model` | 39.9 s | Started job 5: Rendering a picture of Hand Cranked Winch… Then: Job 5 (render_model) is done, after 38 s: downloaded hand_cranked_winch_render.png |
| `render_motion` | 4.9 s | Started job 6: Rendering Hand Cranked Winch's motion "Open the doors"… Then: Job 6 (render_motion) is done, after 0 s: No motion "Open the doors": the model has none yet (list_motions suggests some). |
| `render_queue` | 5.3 s | Queued 1: Hand Cranked Winch, 1920×1080, Best, drawing now. 512 frames averaged: soft shadows from an area light, smooth edges, shading under every... |
| `restyle_model` | 2.9 s | Nothing to restyle: no plain brick one or two studs wide with an open face in that box. |
| `review_model` | 2.2 s | No assembly called walls. No assemblies were named when it was submitted; name them in submit_design's assemblies to have each reviewed close up. |
| `save_model` | 1.4 s | Written to red_house.ldr, with the app's models (/userfs/godot/app_userdata/Brickworks/models/red_house.ldr). |
| `search_gear_ratio` | 1.2 s | Nearest 0.2 (output turns per input turn) in up to 2 meshes of spur gears on the stud grid: 1. 0.2 = 1/5, +0.0000%, 2 meshes, the same way round: an... |
| `search_parts` | 8.1 s | 3039: Slope Brick 45 2 x 2, covers 2x2 studs, 3 plates, 2 studs on top, made in 41 colours, 74 prints and 8 stickered 3660c: Slope Brick 45 2 x 2... |
| `select_tab` | 0.7 s | This chat's calls go to tab hp7c7 now, on “Hand Cranked Winch”. |
| `selection` | 38.2 s | Nothing is selected in Brickworks. Ask the person to select the parts they mean (click one; shift-click or drag a box for more), then call selection... |
| `set_floor` | 40.0 s | It stands on baseplate 32 × 32, green. |
| `settle_feature` | 27.8 s | No feature called "eyes". The features listed: none (submit_design's features). |
| `settle_surface` | 20.5 s | Nothing has been proposed yet: review_model {"surface": true} reads the model and lays the surface pass's pieces. |
| `show_technique` | 19.7 s | Posed minifigure — a person at minifigure scale posed as the brief has them: an arm raised or reaching, a head turned, a tool held out. A minifigure... |
| `simulate_mechanism` | 50.2 s | Started job 7: Recording Hand Cranked Winch's mechanism… Then: Job 7 (simulate_mechanism) is done, after 3 s: No part or sub-assembly crank here. driver= takes a part's number (look_at_model) or a... |
| `split_parts` | 36.6 s | Nothing split: #21 (Technic Brick 1 x 8 with Holes) does not split. Plates, bricks and tiles split into 1 x 1s, a 1 x 1 brick into three plates... |
| `suggest_sections` | 23.2 s | 3 sections, in the order they are built (shown in the person's model tree). Parts, joints to the rest, what each is built onto, the way it comes off... |
| `tabs` | 0.5 s | One Brickworks tab is open: - hp7c7: “Hand Cranked Winch”, in view, used 9 min ago — this chat's This chat's calls go to hp7c7. |
| `view_model` | 19.3 s | Measured, in studs: the whole model is 17 across, 9.10 deep and 18 plates tall, its near corner at x -7, z 0. Its massing, layer by layer — compare... |
| `weakest_joints` | 17.9 s | As View, Stress weighs it: stands up · 69 g. 0 past working load · 0 near it (red past the studs' working load, amber within twice it). 6 joints each... |
| `where_to_attach` | 11.5 s | Nothing is selected in Brickworks. Ask the person to select the parts they mean (click one; shift-click or drag a box for more), then call selection... |
| `open_model` | 20.6 s | Opened lighthouse: 300 parts. look_at_model to see it. |
| `choose_sketch` | 14.3 s | There are no sketches to choose from. submit_design with "sketch": true, three times, makes them. |
| `undo` | 17.4 s | Undid opened “Lighthouse” in place of “Hand Cranked Winch”; opened “Hand Cranked Winch” in place of “Car”. Nothing more to undo. undo {"redo": true}... |
| `clear_model` | 19.9 s | The baseplate is bare. undo puts it back. |

## How much a session hears

Counted with Anthropic's token counter (`count_tokens`, claude-opus-5-5) on
what the connector served on 2026-11-03: before, from brickworks.diy as it
was; after, from the review account's tab of this commit, through the same
live relay.

| What a session is given | Before | After |
|---|---|---|
| The instructions, at `initialize` | 90,009 characters, 31,405 tokens | 3,827 characters, 1,334 tokens |
| The tool list, 70 tools | 73,589 tokens | 73,589 tokens |

**The instructions** were the whole design guide. Claude Code reads the first
4,096 characters of a server's instructions and no more (2.1.316, tested by
asking a session what it had been told), so 86,000 of them reached nobody
there, and every other client paid for all of them. Now they are the guide's
head (how a session works in a tab) and the rules' opening (what the app
does, and the LEGO® notice), in 3,827 characters. Everything else is still
one call away: `read_guide` serves the guide a section at a time, when a
design needs it, as it did before. `mcp_sync_probe` fails if what the
connector serves passes 4,096 characters; `designer_words_probe` and
`mcp_lean_probe` passed on the change.

**The tool list** stays. It is a CAD: 70 tools, 18,426 tokens of
descriptions and about 55,000 of input schemas. A third of it is two tools,
`submit_design` (13,455) and `check_design` (11,709), whose schema is the
design language a model is written in: parts, patterns, sections and
assemblies. That language is the API, tuned against real sets by the bench;
cutting it would cut what Claude can build, so it is neither cheap nor safe
to shrink. The titles added this release are not sent to the model.

**The answers** are short. Over the four example sessions' 106 calls, a
tool's answer was 1,125 characters at the median and 6,855 at the 90th
percentile. A session starts small: `tabs` answers in about 200
characters. The largest were the
guide's "shapes" section (15,904 characters, asked for by name when a
design needs it) and `look_at_model` of the 313-part lighthouse (14,816),
which gives a big model's parts a page at a time (`skip`) rather than all
at once. Pictures come only when a session asks for one (`view_model`).
A whole session heard 47,000 to 105,000 characters of answers: the
lighthouse's design the most, over 43 calls.

## The review account

The review needs a test account with sample data, and Brickworks' sign-in
is a code sent by email, which a reviewer could not receive for an account
of ours. So the review account is a Resend test address, which receives no
mail, with a password: the one kind of account a password signs in to
(`api/_auth.js`, `isTestAccount`). It is made the way the flows make theirs,
by `tools/web/relay_account.mjs review`, and it is nobody's own: not the
owner's, and not the shared account the probes sign in to.

- **Address**: `delivered+claude-review@resend.dev`
- **Password**: in `.env` as `BW_REVIEW_PASSWORD`, never in a document.
  `relay_account.mjs review` writes it there the first time, and after
  that puts it back on the account if the two ever differ.
- **Where it signs in**: https://brickworks.diy/review (`web/review.html`),
  which refuses every other address before asking for a password, and is
  linked from nowhere and not indexed. `tools/web/review_flow.mjs` proves
  it on every release whose change it touches.
- **What it holds**: the models the example prompts built and saved, and
  the every-tool pass's saves. Its models are never in a public list, as
  no test account's are.

Keep it while Brickworks is listed: reviewers come back for updates. To
make it again or put its password back:

```sh
node --env-file=.env tools/web/relay_account.mjs review
```
