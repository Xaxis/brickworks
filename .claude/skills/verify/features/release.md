# Release

The desktop release cycle: one version for the whole app, what a downloaded
build says it is, and (as it lands) the packages, the smoke test, the GitHub
release and the download page. The cycle itself is `docs/RELEASING.md`.

<!-- covers: cli:say which build this is -->

## Sub-features

- `say which build this is`: `VERSION` is the version, and `project.godot`'s
  `config/version` is kept equal to it by `tools/release.py version --set`
  (the macOS Info.plist and the Windows file version are read from there at
  export). `src/build_info.gd` reads it, and for a release the stamp
  `res://release.json` that only a release build carries (commit and date).
  `-- --about` prints `BuildInfo.describe()` and quits before the catalogue
  loads; Help shows the same line; the window title is `Brickworks <version>`.

## How to reach it

```sh
godot --headless --path . -- --about        # from source
python3 tools/release.py version            # do VERSION, project.godot and CHANGELOG agree?
```

## How to check it

```sh
godot --headless --path . -- --about
```

Proves it when: it prints `Brickworks 0.1.0, development build` (the version in
`VERSION`) and exits 0 within a few seconds, with no `SCRIPT ERROR`. A release
build prints `Brickworks 0.1.0, released <date> (<commit>)` instead.

```sh
python3 tools/release.py version
```

Proves it when: `ok    version 0.1.0 in VERSION, project.godot and
CHANGELOG.md (<date>)`, exit 0. Change one of the three and it names the one
that disagrees and exits 1.

## Gotchas

- **`quit()` ends the run after the frame, not at once.** `--about` returned
  from `_ready` before the UI was built, `_process` ran once more and called
  into a playback bar that did not exist: a `SCRIPT ERROR` on every `--about`.
  Both early returns in `_ready` now `set_process(false)` first.
