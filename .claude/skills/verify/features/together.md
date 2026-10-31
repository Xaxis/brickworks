# Together

Two people build one model at once, live, each in a browser or the desktop
app, joined by a link (docs/TOGETHER.md).

<!-- covers: ui:build together, lib:building together, api:POST /api/together, cli:together probe, cli:together browser flow, cli:together desktop probe, cli:together timing -->

## Sub-features

- `build together` (`src/ui/together_dialog.gd`, `TogetherDialog`): File,
  Build together… (`Shell` command `together`, `Main.open_together`), in
  the app's look (`Look.dialogs`, `dialog_look_probe`; it was the engine's
  grey, walk256 DS1). Out of a
  session: a note, **Start a session**, and a field to paste a link with
  **Join** (Enter on an empty field does nothing). In one: the link with
  **Copy link**, each person with "here" or "away" (the owner's view has
  **Remove** beside the others), and **End the session** (owner) or
  **Leave**, and a short chat (`together_chat_field`, `together_chat_send`;
  for an account under 13 or not yet asked its age, a line saying why
  instead). A browser opened at `/app?together=<secret>` (the shell maps it
  to `--together=`) joins once signed in and the first model is down
  (`Main._maybe_join_together`), then shows the panel. Controls for checks:
  `together_start`, `together_join_field`, `together_join`, `together_copy`,
  `together_end`, `together_remove_N`, `together_close`.
- `building together` (`src/net/together.gd`, `Together`): start (uids for
  every part, a snapshot), join (opens the text, matches parts to uids, pins
  each to the owner's exact state and lift), capture (the world's change log
  since the last revision; every part when a builder step changed), send
  (one request in flight, up to 200 changes), poll (long-poll, ~20 s), take
  (numbered changes in order; another's change to a part with one of mine on
  its way waits until mine is numbered; a copy's change seen twice put down
  once), per-person undo/redo (puts a part back only where it is still as
  the step left it). The model's own state as keys of their own
  (`_meta_now`: `~title`, `~floor`, `~hidden`, `~motions`, `~looks`,
  `~unit_steps`, `~broken`), read every 250 ms and on each builder step;
  a part made in the app sent as `~part:<id>` with its files. Chat as
  `~chat` ops (`messages`, `chat_words`). Pointers: `op=point` four times a
  second while the part under the mouse or the ghost moves
  (`Main`'s `pointer_at`), the others' drawn as a dot and a name at a
  fixed size on the screen (`pointers_shown`); one that leaves the model
  is sent as gone once it has stayed off 250 ms (`OFF_MS`), so crossing a
  gap between parts it does not blink. The server tells each
  `op=point` at once to every poll waiting in the session on the
  session's Realtime channel (`channelOf`, `tell`, `listen` in
  api/together.js), and a poll answers with it; it also reads who is in
  it every 250 ms, and every 100 ms while another's pointer moved in the
  last 2 s if it is not listening yet. A browser's poll asks
  `stream: true` and reads its answer a line at a time (`_ask_page`,
  `_on_page_heard`): who is in it comes as a line
  `{more: true, people, seen, at}` the moment it changes and the poll
  waits on; the desktop's is answered whole (`tests/test_together_poll.py`,
  the channel stood in for; Vercel needs `supportsResponseStreaming`,
  tools/deploy.sh). Going back in: the session kept in
  `TabSession.path("together.txt")`; `Main._maybe_join_together` rejoins
  without asking after a reload or a restart. In a session
  `EditVerbs.press("undo"/"redo")` and `go_back` route here. Leaves the
  session when the model is replaced (Open, New, Clear). On the web it says
  its state to `window.brickworksTogether` (live, owner, link, seq, waiting,
  people, parts, trips, ended, can_undo) and takes
  `window.brickworksTogetherAsk` (edits for `check_edit`, or `{text:true}`
  for the file, its hash and the uids).
- `POST /api/together` (`api/together.js`, `supabase/together.sql`): ops
  `start`, `join`, `send`, `poll`, `end`, `leave`, `remove`, `point`. Chat
  follows comments' rule (13 or over, not barred, words filtered); an
  under-13 reader's copy of a chat op has the words taken out. Numbers come
  from `together_append` under the session row's lock. Names: the profile's
  when `shown_publicly`, else "Builder N"; never an email. A profile made or
  renamed mid-session names its person from then on: a poll that waits
  `NAME_MS` (5 s) looks at its person's name again, once; and one joining
  again is named by the profile as it is then (walk256 BT1: names were fixed
  at the first join). The owner's view
  goes in the session's snapshot (`CadCamera.aim`), and whoever joins opens
  on it (`aim_at`), not framed on the parts alone. The panel keeps who is in
  it to 3 rows and the chat to 4 lines, each scrolled, so it does not grow
  and Close does not move (`TogetherDialog._hold_heights`).
- Seeing each other (APP_UX B8): `op=point` carries `{at, sel, view}`
  (the selection by uid, at most 500; `CadCamera.aim`); the server re-reads
  people every 250 ms while a poll waits. Each other person's selection is
  outlined in their colour (`Together._outlines`, a `SelectionOutline`
  each; `selections_shown()`), their colour their place in `people`
  (`colour_of`). **Follow** on a name in the panel (`together_follow_N`,
  `Together.follow`): the view goes where theirs goes until this person
  moves it, presses Stop (`together_stop_following`, in a frame of their
  colour over the model's column) or they leave.
- Comments pinned to parts (`src/assembly/pinned_comments.gd`
  `PinnedComments`, kept on `ModelStore.pins`; `src/ui/pins_view.gd`
  `PinsView`, the marks over the model's column; `src/ui/pins_dialog.gd`
  `PinsDialog`, File, Comments…, the `comments` Shell command, also on a
  part's right-click): a `0 !BRICKWORKS PIN {json}` line each in the
  file's head; a builder `"pins"` undo step each (`Builder.pins_hook`); in
  a session a `~pin:<id>` key each with its part by uid. Chat's rule in a
  session (422 for an account that may not chat); an account under 13 is
  sent none (`api/together.js` takes them out of its ops and its join; a
  model sent in parts carries its comments in the session's row, never in
  the parts, and the app takes none from the parts). Not drawn when `ModelStore.read_only`
  (a shared link's viewer). Controls: `pins_field`, `pins_pin`,
  `pins_close`, `pins_resolve_N`, `pin_mark_N`, `pin_resolve` (the card's).
- Changes on their way when a page goes: each send a kept-alive fetch
  (`KEPT_ALIVE_SEND`), and kept as queued with the tab's session
  (localStorage `brickworks.together_pending.<TabSession id>` on the web,
  `together_pending.json` in the session's folder on the desktop); sent by
  a kept-alive fetch at `pagehide`, by the desktop's quit
  (`Together._exit_tree`, a blocking send of `GOODBYE_MS` at most), and
  sent again by the next page to take up the session: the tab reloaded, or
  the next tab after it was closed (`_restore_pending`, `timing.restored`).
  A page closed mid-frame never runs `pagehide`; only the kept copy brings
  those (tools/web/together_close.mjs).
- A model over 4 MB (`supabase/together_big.sql`, not applied until the
  lead does): `op=start {stored}`, `op=upload`, `op=snapshot`
  (`Together.parts_above`, 3.5 MB; parts of 2 MB). Without the table a big
  model is refused as before.
- `together probe` (`tools/web/together_probe.mjs`), `together browser flow`
  (`tools/web/together_flow.mjs`), `together desktop probe`
  (`src/dev/together_probe.gd`), and `together_pins_probe` (the real app
  in a window): below.

## How to reach it

    set -a; . ./.env; set +a
    tools/export.sh web
    node tools/web/relay_server.mjs 9011 --static=build/web &
    # before supabase/together.sql is applied to the project the server talks to:
    #   ... --hold=together_sessions,together_ops,together_people
    # and before supabase/together_big.sql, for a model over 4 MB:
    #   ... --hold=together_sessions,together_ops,together_people,together_snapshot_parts

Then in a browser at http://127.0.0.1:9011/app (signed in): File, Build
together…, Start a session; open the link in a second browser profile
signed in as someone else.

## How to check it

- Server half, seconds: `node tools/web/together_probe.mjs
  --url=http://127.0.0.1:9011` (or `--url=<preview>` with `BW_BYPASS`).
  Expect `all ok`: 40 concurrent sends numbered 1..40 once each, read back in
  one order by both; p50/p95 of a change reaching the other's poll; made-up
  link 404, never-joined 403, removed 403 (poll, send, join), ended 410.
- Engine, headless, a minute: `godot --headless --path . --script
  src/dev/together_probe.gd -- --api=http://127.0.0.1:9011`. Expect
  `together probe: all passed`: the house byte for byte after join, ~55 of 60
  random edits, the same hash on both, the same part moved by both ending in
  one place, each undo its own and one leaving a part changed since.
  Section 4f: a change held as the copy quits reaches the owner in the
  quit itself (`Build together: 1 change ... sent as the app quit: taken`).
- A page closed with a change on its way, about 10 minutes for 30 rounds:
  `node tools/web/together_close.mjs --url=http://127.0.0.1:9011
  --rounds=30 --held --frame=600` (the relay holding the together tables).
  Expect `together_close: none lost`, each round "as it went" or "on the
  next visit". With `--frame=600` most go on the next visit: a page closed
  in a long frame runs no `pagehide`. Before the fix: 29 of 30 lost.
- Whole thing, about 30 minutes, two SwiftShader browsers and a headless
  desktop copy: `node tools/web/together_flow.mjs --url=http://127.0.0.1:9011
  --out=DIR` (`--desktop=no` without the desktop's half). Expect
  `together_flow: all ok`: the edits made and the hash equal in both
  browsers and the desktop; then each kind of the model's own state (name
  typed, floor, printed part, step, booklet look, motion, hidden colours)
  byte-identical after each; Ctrl+Z; latency p50/p95; a reload and an
  offline spell rejoining; the owner's pointer drawn in the other view;
  chat heard by the desktop and refused to the under-13; the guest opening
  on the owner's turned and zoomed view; the owner's profile made
  mid-session naming them in both browsers while the under-13 stays
  "Builder 2"; six chat lines and Close where it was; a real MCP
  `edit_model` from the owner's Claude reaching the other browser. Then
  B8: the pointer over 40 moves to the frame the second page drew its dot
  in, twice: after the 50 edits p95 under 1 s; on the rich car p95 under
  1 s or 95% within 500 ms and four of that page's own frames, as the
  change measure; stages send, reach, frame, Follow and its frame, the owner's selected part outlined
  in their colour off the second page's pixels, the wheel stopping it; a
  comment pinned from File, Comments… and resolved by one click on its
  card, in the owner's and the desktop's files and not the under-13's; the
  shared link's .mpd keeping it and its page not showing it; a reload and a
  closed page with changes on their way, the owner's page reloaded; and
  two more sessions on the car as all that left it, in one request and in
  parts (`parts_above`), each byte for byte without the comment. A
  mismatch writes both files to DIR and prints the first lines that differ.
  On a build without the feature it fails at "File, Build together… opens
  its panel".
- The real app in a window, no server (`Together.check_alone`), at both
  sizes: `tools/probe.sh together_pins_probe` and `PROBE_SIZE=1400x900
  tools/probe.sh together_pins_probe` (add `--shots=DIR`). Expect `together
  pins probe: all checks passed`: the comment's mark in its colour read off
  the window over its part, its card, one click on Resolve, Ctrl+Z, saved
  and opened again on the same part; another's two selected parts outlined
  and their pointer drawn in their colour (pixels, none before; the dot
  gone when they point nowhere, its size kept with the view 2.5 times
  nearer); Follow clicked in the panel, the frame, following a turn, the wheel stopping it,
  Stop.
- The desktop pair probe's B8 part (sections 4c to 4e and 6 of
  `together_probe.gd`, run with the relay holding
  `together_snapshot_parts`): selection outlined in e8590c, pointer p95
  about 350 ms, Follow and its stop, a comment pinned/resolved/two at
  once/opened again, three changes held as a copy goes and sent again, a
  session begun again on the car with a part moved and a step of its own
  (5b, in one request and in parts), and 25,600 parts started in 2 parts
  and joined byte for byte.
- Where the time of a change goes, stage by stage (`together timing`,
  `tools/web/together_timing.mjs`, a measure, local only): a baseline of
  paints, then each of the seven kinds of change and paints again; a line
  each with the median total and p95 and the stages pickup, send, number,
  reach, apply, shown, and the worst frame, capture and read of the
  model's own state on each side (`Together.timing`). On 2026-10-24 after
  the page's fetch: p50 193 to 701 ms, p95 under 1 s but one round.
- In the preview battery: `together_probe` and `together`
  (tools/release/preview_checks.sh); they need supabase/together.sql applied
  to the project, and the flow's section 8 (a model sent in parts)
  supabase/together_big.sql.

## Gotchas

- An account under 13's file in a session is the others' without the
  comment lines, by design: the flow compares it with the owner's less
  those lines (`withoutPins`), and the desktop's with the owner's whole.
- The flow's section 8 (a session begun again on the car) allows the
  owner's and the joiner's files to differ in where a STEP line falls, and
  prints "only where a STEP line falls": the file writer's fault with a
  part in no step of the author's (docs/TOGETHER.md, Not done yet). Byte
  for byte once that is fixed.
- The flow's 5i counts only the held edits that changed the model (a
  paint in the colour a part has, or a move a part above refuses, sends
  nothing). The changes a closed page sends as it goes go in a fetch kept
  alive past it, which Playwright never lists among the page's requests:
  only their arrival at the owner proves them, and the check says what the
  page had ready.
- A view handed to `aim_at` and then changed in place reads as unchanged
  (`Together._followed` keeps the dictionary): a probe gives Follow a copy
  per turn, as each poll's words are new.

- A menu row typed to with a space presses the row the menu is on: the flow
  types "Buildtog", not "Build together".
- `Together.owns`, not `owner`: Node has an `owner` already.
- In a browser the session asks with the page's fetch (`_ask_page`), not
  HTTPRequest: polled once a frame, a state a frame, it held every change
  two or three software-drawn frames (150 ms each) after it had arrived.
- `Together._heal` puts back, every two seconds, what this side shows that
  the numbered changes say otherwise; "together: put back N parts" on the
  console names them.
- The desktop probe signs in by the password grant itself (as
  tools/web/session.mjs does) and needs `BW_BYPASS` in its environment to
  reach a protected preview (`Together.extra_headers`).
- A part placed at y = 0 in a check cannot be moved down or sideways where
  its boxes reach below the ground: checks place their parts 48 LDU up.
- Nothing runs outside a session; the frames gate is unaffected but for the
  web's twice-a-second state line.
- Two copies in one process share a tab: the pair probe sets
  `keeps_place = false`, or each would rejoin the other's session.
- The owner's Claude must be connected before the owner's tab opens (the
  flow mints it first): a tab opened earlier listens only once reloaded.
- `ModelStore._in_file_order` breaks a tie of one part in one place by its
  turn: two copies built in another order wrote turned twins the other way
  round.
