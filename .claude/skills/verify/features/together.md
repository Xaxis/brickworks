# Together

Two people build one model at once, live, each in a browser or the desktop
app, joined by a link (docs/TOGETHER.md).

<!-- covers: ui:build together, lib:building together, api:POST /api/together, cli:together probe, cli:together browser flow, cli:together desktop probe -->

## Sub-features

- `build together` (`src/ui/together_dialog.gd`, `TogetherDialog`): File,
  Build together… (`Shell` command `together`, `Main.open_together`). Out of a
  session: a note, **Start a session**, and a field to paste a link with
  **Join** (Enter on an empty field does nothing). In one: the link with
  **Copy link**, each person with "here" or "away" (the owner's view has
  **Remove** beside the others), and **End the session** (owner) or
  **Leave**. A browser opened at `/app?together=<secret>` (the shell maps it
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
  its way waits until mine is numbered), per-person undo/redo (puts a part
  back only where it is still as the step left it). In a session
  `EditVerbs.press("undo"/"redo")` and `go_back` route here. Leaves the
  session when the model is replaced (Open, New, Clear). On the web it says
  its state to `window.brickworksTogether` (live, owner, link, seq, waiting,
  people, parts, trips, ended, can_undo) and takes
  `window.brickworksTogetherAsk` (edits for `check_edit`, or `{text:true}`
  for the file, its hash and the uids).
- `POST /api/together` (`api/together.js`, `supabase/together.sql`): ops
  `start`, `join`, `send`, `poll`, `end`, `leave`, `remove`. Numbers come
  from `together_append` under the session row's lock. Names: the profile's
  when `shown_publicly`, else "Builder N"; never an email.
- `together probe` (`tools/web/together_probe.mjs`), `together browser flow`
  (`tools/web/together_flow.mjs`), `together desktop probe`
  (`src/dev/together_probe.gd`): below.

## How to reach it

    set -a; . ./.env; set +a
    tools/export.sh web
    node tools/web/relay_server.mjs 9011 --static=build/web &
    # before supabase/together.sql is applied to the project the server talks to:
    #   ... --hold=together_sessions,together_ops,together_people

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
- Whole thing, about 6 minutes, one SwiftShader browser and a headless
  desktop copy: `node tools/web/together_flow.mjs --url=http://127.0.0.1:9011
  --out=DIR` (`--desktop=no` without the desktop's half). Expect
  `together_flow: all ok`, with the edits made, the hash equal in both
  browsers and the desktop, the Ctrl+Z check, and latency p50/p95 printed.
  On a build without the feature it fails at "File, Build together… opens
  its panel".
- In the preview battery: `together_probe` and `together`
  (tools/release/preview_checks.sh); they need supabase/together.sql applied
  to the project.

## Gotchas

- A menu row typed to with a space presses the row the menu is on: the flow
  types "Buildtog", not "Build together".
- `Together.owns`, not `owner`: Node has an `owner` already.
- The desktop probe signs in by the password grant itself (as
  tools/web/session.mjs does) and needs `BW_BYPASS` in its environment to
  reach a protected preview (`Together.extra_headers`).
- A part placed at y = 0 in a check cannot be moved down or sideways where
  its boxes reach below the ground: checks place their parts 48 LDU up.
- Nothing runs outside a session; the frames gate is unaffected but for the
  web's twice-a-second state line.
