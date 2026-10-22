---
name: verify
description: Verify Brickworks — a Godot 4.7 LEGO CAD app (desktop and WebAssembly), a Python LDraw pipeline, a Vercel-hosted web build with a small API (accounts, sign-in by emailed code, the Claude connector relay), and an AI design loop. Holds the feature map of where every scene, endpoint and command lives, how to launch and health-check a checkout, and a proven recipe for checking each feature. Use to prove a change in this repo works, to find where a feature lives, or to see what a change could break.
---

# Verify Brickworks

`FM=~/.claude/claude-core/bin/featuremap`

- **Where does a feature live?** Look it up in `features.json` (`id`, `entry`, `reach`,
  `tests`), then read `features/<area>.md` for its recipe.
- **What did my change touch?** `$FM affected` (add `--since <base>` on a branch).
  It follows imports, so it never lists a browser flow that visits a changed
  page by its address: for any change to `web/` or `api/`, also run
  `tools/release/flows_for.py --since <base>` and run the preview checks it
  names (three flows broke on Discovery's gallery that way and held m84).
  Every feature it lists is in scope.
- **Keeping it current:** when you add, rename, move or remove a feature, run
  `$FM generate --write`, update the matching `features/<area>.md`, and confirm
  `$FM check` exits 0. Commit that with the feature change.

One thing to know before trusting anything below: **Godot exits 0 when a script
fails to parse.** A probe with a typo in it prints nothing and reports success.
`tools/check.sh` greps every run for `SCRIPT ERROR|Parse Error|Failed to load
script` and turns that into a failure; a probe you run by hand needs the same
reading, by eye.

## Static checks

| Check | Command | Proves | Baseline |
|---|---|---|---|
| the suite | `tools/check.sh` | the parse check, the Python pipeline (every `tests/test_*.py`), and every probe in `src/dev` but the 20 its `out` list names with why (money, the relay, benches, pictures with no verdict, over ten minutes, or failing on the code with the finding and the day): 140 headless (the MCP in step with the app first), 54 windowed runs, each line with its time, and a session driving the app over MCP. **It stops before it starts when a probe is in no list**, or a list names one that is gone, naming it: a new probe goes in `headless`, `windowed` or `out`. `tools/check.sh --lists` asks only that, in a second. A probe has ten minutes (`PROBE_SECONDS`), its wait for the GPU included, and one that skips itself fails | not yet timed whole: the 70 probes brought in on 2026-10-22 took 2.6 h one after another at load 30-40 |
| network suite | `tools/check.sh --network` | also fetching a part over the wire, opening a model the way the browser does, the model library from the store (`.env`'s `PARTS_URL`) and the gallery as a session reads it (hosted) | passes, +~15s before the library and the gallery |
| types | `pyright` | the Python pipeline and tools | passes, 3s, warnings only for pytest, numpy and scipy imports |
| pipeline only | `python3 -m pytest tests/ -q`, or `python3 tools/minitest.py tests/test_ldraw.py tests/test_style.py tests/test_release.py tests/test_minifig.py tests/test_elements.py tests/test_trademarks.py` | the LDraw facts everything rests on: 8 mm stud pitch, 9.6 mm brick, −Y up; the colour join; the style measures on hand-made models; where a minifigure's parts go; and that every word a person reads writes LEGO® as the Fair Play policy asks, with its disclaimer where it must be (`docs/TRADEMARKS.md`) | 102 passed, 25 skipped, 2.7s |
| no write through a packed cast | `python3 tools/minitest.py tests/test_packed_casts.py` (in the suite too) | no `.gd` under `src/` or `tools/` writes through `(x as Packed…Array)`, which writes to a copy on Godot 4.7.2 and is silently lost: three such were found on 2026-10-17 (`docs/INSTRUCTIONS.md`, lostappend) | 5 passed, 1.7s |
| parses | `godot --headless --path . --quit` | every script and scene loads | passes, ~20s |

`features.json` lists `python -m pytest -q` and `pyright` because those are what
static analysis can see. `tools/check.sh` is the real suite and runs both.

Known, and not a regression:

- **25 of the 114 pipeline tests skip** on a machine without numpy and scipy. They
  are the six that voxelise a part. `apt install python3-numpy python3-scipy`
  brings them back. The suite says so on the `ok pipeline` line.
- **There is no pytest, pip or ensurepip on this machine** and `apt` wants a
  password, so `tools/check.sh` falls back to `tools/minitest.py`, which
  implements the four pytest features the suite uses and raises by name on
  anything else. If you add a test that needs `pytest.raises`, add it there too.
- **7 probes never run in the suite.** Four spend money (`bakeoff revise sideways
  stream`); `gallery` renders every shipped model for a person to look at and has
  no pass or fail, and so does `technique_sheet`, a contact sheet of the worked
  constructions; `harvest` needs a directory of real sets' sub-models from
  `tools/omr.py harvest` or `clusters`.

## Launch

The app is a window, not a server — there is no port and nothing to poll.

```sh
godot --path .                                   # the real thing
godot --path . -- --mcp                          # ...with the MCP port open
tools/probe.sh X_probe                           # one probe, run as its header says
godot --headless --path . --script src/dev/X_probe.gd   # one probe, by hand
godot --path . --resolution 1400x900 --script src/dev/feel_probe.gd   # a windowed probe
```

`tools/probe.sh` reads the probe's header for headless or a window and its
size, gives it its own data folder, the GPU lease and Xvfb for a window, and
fails a run that printed a script error or skipped itself (both exit 0
from Godot). `PROBE_DRY=1` shows the command.

Probes may run at once in one checkout: none writes `.godot`. What breaks
them is a class list (`.godot/global_script_class_cache.cfg`) older than the
scripts, from a copied `.godot` or a merge, checkout or bisect: every script
naming a missing class fails, as `"BestOfTwo" not declared`. `probe.sh`
imports first when the list is behind (`tools/fresh_import.sh`, one import a
checkout, the others wait for it) and does not run the probe (exit 2) when an
import cannot fix it. A probe run by hand gets no such check: run
`tools/fresh_import.sh` first.

Needs: a display (`DISPLAY` or `WAYLAND_DISPLAY`) for anything that draws —
previews, the renders the assistant is shown, and what a dragged box catches all
come from a SubViewport that a headless run has no device to draw into. Needs
`vendor/ldraw` (`tools/fetch_data.sh`) and a built mesh cache
(`tools/build_meshes.py`, ~45 min) — without either, parts load empty and every
dimension check fails for the wrong reason.

Start-up reads a 14 MB catalogue, so **every** run costs ~15–20s before it does
anything. That is not a hang.

A window opened by hand (`godot --path .`, with or without `--mcp`) starts on the
**sign-in screen**, as it does for everyone: sign this machine in once with
`godot --headless --path . --script src/dev/sign_in.gd -- you@example.com`
(needs `.env`; see [account](features/account.md)). Probes, headless runs and
command lines that render, export or design and quit are never asked.

## Doctor

```sh
tools/doctor.sh              # read-only: can this checkout be driven?
tools/doctor.sh --network    # also whether brickworks.diy answers
```

It names the commit, checks the LDraw library and the mesh cache, says which
checks this machine can run at all, and reports key *names* from `.env`, never
values. Non-zero means the app cannot be driven here and says what to fix. Run it
before the first drive and again after any failure that doesn't make sense.

## Drive

- **The app (scene, building, view):** launch it, do the thing with the mouse and
  keyboard, and read the ghost brick and the brick count. Most of it also has a
  probe that drives the real scene through `Input.parse_input_event`; prefer the
  probe for a regression, your hands for how it feels.
- **A probe:** run it and read the last line. Probes print `ok`/`FAIL` per
  assertion and end in a sentence. Exit 0 **and** no `FAIL` and no `SCRIPT ERROR`
  is the pass.
- **The CLI:** run it, read stdout and `$?`, then read the file it wrote.
- **The API and the web build:** `curl -si` the endpoint on the deployed URL, then
  `node tools/web/check.mjs --url=...` to prove the engine actually boots there.
  A successful upload proves nothing: the threaded build refuses to start unless
  the host sends the cross-origin isolation headers.
- **Over MCP:** `tools/mcp_check.py` starts its own headless app, drives the relay
  the way a Claude Code session does, and stops what it started. Against an app you
  already have open: `tools/mcp_check.py --port=8787`, which never kills anything.
- **The assistant:** `tools/design.py "<brief>"` spends real money on every run.
  Everything that can be checked without spending is already a probe — use those
  first, and say in your report when you spent.

## Evidence

- Record the command and its decisive output: the probe's last line, the exit
  code, the parts written, the status plus body, the text on the page.
- Capture both the action and the resulting state, through a second read-only
  view: a model that saved is a model that reopens with the same brick count.
- A screenshot is evidence for anything visual: `godot --path . --script
  src/dev/shot_probe.gd` writes to `shots/`.
- If a path can't be reached, name the missing precondition and prove the nearest
  real path. Never report it as verified.

## Cleanup

Godot runs exit on their own; a windowed probe closes its window. If one hangs,
kill **only** the pid you started — parallel sessions share this checkout and
another one's Godot looks exactly like yours in `pgrep godot`.

**Use `tools/running.py` to find a run, and `--stop` to end one.** Neither
`pgrep -f` nor `ps | grep` works here: both match the command line of the shell
that asked, so they report a run that has already exited — and stopping what
they return kills the shells *waiting* on the run too, because an `until` loop
polling for it holds the pattern in its own command line. That happened here and
ended two background waiters along with the run.

```sh
python3 tools/running.py design.py          # what is running, excluding the asker
python3 tools/running.py --stop design.py   # ends the run, spares the waiters
```

`tests/test_running.py` pins both halves, and the sparing half was claimed in a
docstring before it was true — the test is what said so. Watch out for one more
trap in testing it: `os.kill(pid, 0)` succeeds on a child that has died and not
been reaped, so the first version reported the run as surviving while holding its
exit status of `-SIGTERM`.

Probe runs write to `models/design.ldr`, `shots/` and the app's own saved state
(`user://`), all of which are gitignored or deliberately kept. Nothing needs
undoing, but `git status --porcelain | grep -v '^??'` before committing tells you
if a probe changed something tracked.
