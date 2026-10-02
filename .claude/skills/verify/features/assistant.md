# Assistant

Turning a sentence into a model that holds together, then looking at it and
fixing what it got wrong.

<!-- covers: lib:design loop, cli:design from a brief, lib:model and effort settings, lib:reference pictures -->

## Sub-features

- `design loop`: the real loop in `src/ai/assistant.gd`. It is given the part
  catalogue, the rules, and tools to search, place, read back the world and look at
  a render; it places bricks, is told what collides, floats or will not survive
  being lifted, and revises. Sections let it carry a sub-assembly at an angle.
- `design from a brief`: `tools/design.py "<sentence>"`, which shells out to
  `godot --path . -- --ask=... --out=...`. **This spends real money.**
- `model and effort settings`: which Claude model and which effort level, and
  whether the request it builds is one that model will accept — `max_tokens`
  ceilings, adaptive thinking, the cached system block.
- `reference pictures`: a picture of what is wanted, put into the conversation,
  and old ones dropped so the context does not grow without bound.

## How to reach it

```sh
godot --path .                                   # the Design panel
tools/design.py "a small lighthouse"             # COSTS MONEY
tools/design.py "a red sports car" --out models/car.ldr --effort max
godot --headless --path . -- --ask="a small lighthouse" --out=/tmp/x.ldr --effort=low
```

Effort is one of `low medium high xhigh max`. The app needs either the person's own
key or a signed-in account; the CLI uses the key in the environment. **The user's
key never reaches our server** — `/api/claude` is for accounts that pay in our
tokens, and a bring-your-own-key client talks to Anthropic directly.

## How to check it

Static: nothing static covers the loop. `pyright` covers `tools/design.py`.

Runtime, all free — these are the ones to run after changing the loop:

```sh
godot --headless --path . --script src/dev/rules_probe.gd       # the rules, and what it is told
godot --headless --path . --script src/dev/world_view_probe.gd  # it reads back what it wrote
godot --headless --path . --script src/dev/edit_probe.gd        # change a model without re-describing it
godot --headless --path . --script src/dev/scale_probe.gd       # a model too big to list in one go
godot --headless --path . --script src/dev/scanner_probe.gd     # half-written arguments yield whole bricks
godot --headless --path . --script src/dev/reader_probe.gd      # the reassembled answer matches what was sent
godot --headless --path . --script src/dev/busy_probe.gd        # a second design during the first
godot --headless --path . --script src/dev/dropped_probe.gd     # a dropped connection, retried
godot --headless --path . --script src/dev/restore_probe.gd     # a failed design leaves the model alone
godot --headless --path . --script src/dev/brain_probe.gd       # the request carries only what the model accepts
godot --headless --path . --script src/dev/reference_probe.gd   # a picture gets in
godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd  # and it is a picture of the model
```

Proves it when: each exits 0 with no `FAIL`. `rules` is the one that catches a
message that reads as three problems when there is one, or advice counted as an
error.

Paid, and only when the thing they exercise has changed — each spends tokens:

```sh
godot --headless --path . --script src/dev/assistant_probe.gd   # a real design, through the real gate
godot --headless --path . --script src/dev/revise_probe.gd      # add to a model it did not build
godot --headless --path . --script src/dev/sideways_probe.gd     # build sideways when the job needs it
godot --headless --path . --script src/dev/stream_probe.gd       # appears while it is being written
godot --headless --path . --script src/dev/bakeoff_probe.gd      # do the settings change anything
godot --headless --path . --script src/dev/tier_probe.gd         # who may use it, on whose money
godot --headless --path . --script src/dev/account_probe.gd      # a whole sign-in, against a real server
```

A real brief is the end-to-end proof: `tools/design.py "a small lighthouse"
--effort low`, then open the `.ldr` and count the parts. Report that you spent.

## Gotchas

- **Four tests here once asserted against the thing under test** and passed with
  the bug reinstated: `_tries >= TRIES_WHEN_DROPPED - 1`, a colour lookup that
  never returns null, a wedge assertion the old wrong answer also satisfied, and
  wording that matched either way. Before trusting a new assertion here, break the
  code and watch it fail.
- **GDScript lambdas capture by value.** A callback that reads a counter captured
  the number, not the variable.
- **`advice` is not `issues`.** Hints live in their own array, because
  `errors += issues[kind].size()` counted the hint as a problem and the model spent
  turns fixing it.
- **Every brief is a different model.** A run that produced 193 bricks and a run
  that produced 0 are the same code. Judge a change by several runs, and read the
  transcript — it has caught more bugs here than the probes have.
- A render only exists where there is something to draw with, so `shot_probe`
  needs a display. The headless suite would never exercise the path the app takes.
