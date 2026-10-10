# Release

The desktop release cycle: one version for the whole app, the packages for
Linux, macOS and Windows with the part library inside, the smoke test that
runs each one as a person would, the GitHub release, and the download page
that offers each system its own build. The cycle and its cadence are
`docs/RELEASING.md`.

<!-- covers: cli:say which build this is, cli:build the desktop packages, cli:smoke a package, cli:publish a release, cli:check a release on three systems, ui:download page, cli:download page check -->

## Sub-features

- `say which build this is`: `VERSION` is the version, and `project.godot`'s
  `config/version` is kept equal to it by `tools/release.py version --set`
  (the macOS Info.plist and the Windows file version are read from there at
  export). `src/build_info.gd` reads it, and for a release the stamp
  `res://release.json` that only a release build carries (commit and date).
  `-- --about` prints `BuildInfo.describe()` and quits before the catalogue
  loads; Help shows the same line; the window title is `Brickworks <version>`.
  `tools/check.sh` and CI's `check` both run `tools/release.py version`.
- `build the desktop packages`: `tools/release.py build [linux mac windows]`
  stages `git archive HEAD` with only the meshes the catalogue names, exports
  each preset, packages (AppImage and tar.xz; a universal macOS zip, signed
  by rcodesign, ad hoc without a Developer ID; a Windows zip with the console
  wrapper), writes
  `SHA256SUMS`, and reads every package back: Info.plist version, Mach-O
  architectures and oldest macOS per slice, the code signature parsed from
  the binary, PE machine, version and Authenticode, archive contents. Into
  `dist/<version>/`, with `build.json` holding what was read. Signing plugs in
  by environment (`APPLE_SIGN_P12`..., `WINDOWS_SIGN_COMMAND`; see
  `docs/RELEASING.md`).
- `smoke a package`: `tools/release.py smoke FILE [--window]` unpacks it the
  way a person's system would into a fresh home, then: `--about` must say the
  version and that it is a release; the example car is opened from the
  package and written back with every part; the app is started with `--mcp`
  and `tools/mcp_check.py --port` drives it (search, clear, place two
  bricks, save, read back); its state must land in the fresh home. An
  AppImage also runs with `--appimage-extract-and-run`. `--window` draws the
  car on Xvfb (under `gpu`) and keeps `shots/release-<os>.png`.
- `publish a release`: `tools/release.py publish --draft` creates a draft
  GitHub release with the packages and `SHA256SUMS`, then compares GitHub's
  own SHA-256 of every asset with `dist/`. Without `--draft` it promotes that
  draft (or creates a public one), checks again, and writes
  `web/releases.json` with pinned URLs for the page.
- `check a release on three systems`: `.github/workflows/release.yml`
  downloads a release, draft or published, on ubuntu-24.04, macos-15 (Apple
  silicon), macos-15-intel and windows-2022, runs `inspect` and `smoke` on
  each package there, and on macOS `codesign --verify --deep --strict` and
  `lipo -archs`. It builds nothing: the part library is not in git.
- `download page`: `web/download.html` with `web/download.js`, served at
  `/download.html` (deploy.sh copies every top-level file in `web/`; `/download`
  without `.html` 308s home). Reads same-origin `releases.json`, detects the
  system (`?os=`, then client hints, `navigator.platform`, the user agent; a
  phone or an iPad gets no guess), offers its primary file with version,
  size and date, and shows every file with its SHA-256, a Copy button, the
  command to check it, what the system needs (glibc and oldest macOS read
  from the packages, disk once unpacked) and, while unsigned, the Gatekeeper
  and SmartScreen first-launch steps. No release in the manifest reads "on
  its way" with a link to the web app.
- `download page check`: `tools/web/download_check.mjs` serves `web/` with a
  CSP at least as strict as the site's and loads the page as Linux, macOS,
  Windows and an Android phone through the DevTools protocol.

## How to reach it

```sh
godot --headless --path . -- --about        # from source
python3 tools/release.py version            # do VERSION, project.godot and CHANGELOG agree?
python3 tools/release.py build linux        # or mac, windows; all three by default
python3 tools/release.py inspect            # read dist/<version>/ back
python3 tools/release.py smoke dist/0.1.0/Brickworks-0.1.0-linux-x86_64.tar.xz --window
python3 tools/release.py manifest --local --out=/tmp/releases.json
node tools/web/download_check.mjs --manifest=/tmp/releases.json --shots=shots
python3 tools/release.py publish --draft --tag=v0.0.0-upload-test --target=main --no-manifest
gh workflow run release.yml -f tag=v0.1.0   # once the workflow is on main
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

```sh
python3 tools/release.py build && python3 tools/release.py inspect
```

Proves it when: it ends `built 0.1.0`, and the read-back shows the macOS
bundle at `0.1.0` with `arm64 + x86_64`, a signature on both slices and
`sealed True`; both Windows executables `x86_64` with `version 0.1.0`; the
tar.xz's binary executable. It exits 1 on any of those being wrong.

```sh
python3 tools/release.py smoke dist/0.1.0/Brickworks-0.1.0-linux-x86_64.tar.xz --window
python3 tools/release.py smoke dist/0.1.0/Brickworks-0.1.0-linux-x86_64.AppImage
```

Proves it when: every line is `ok` and it ends `... starts, loads the part
library, opens a model and takes bricks`; `shots/release-linux.png` shows the
example car on its baseplate.

```sh
node tools/web/download_check.mjs --manifest=/tmp/releases.json --shots=shots
```

Proves it when: linux is offered the AppImage, macos the universal zip and
windows the windows zip, each with the version; the phone is offered nothing
and told why; the other systems are one click away; nothing is refused by the
CSP; it ends `the download page offers each system its own build`. With the
committed (empty) manifest it reads `no release yet` for all four.

## Gotchas

- **`quit()` ends the run after the frame, not at once.** `--about` returned
  from `_ready` before the UI was built, `_process` ran once more and called
  into a playback bar that did not exist: a `SCRIPT ERROR` on every `--about`.
  Both early returns in `_ready` now `set_process(false)` first.
- **The build is of HEAD.** Uncommitted changes to `src/`, `models/`, the
  presets or `project.godot` are listed and left out; commit first.
- **Godot 4.7.2's own macOS signature is malformed.** Its DER entitlements are
  a bare SET with TRUE as `01` (Apple's are `70 .. 02 01 01 b0 ..`, TRUE `ff`)
  and its superblob lists slot 0 twice; `rcodesign print-signature-info`
  cannot read it, and macOS 12+ checks DER entitlements at launch. So the
  release re-signs with rcodesign, and `inspect` fails a package with
  `invalid (the same slot twice)` or `invalid (entitlements not in Apple's DER
  form)`. `tools/export.sh mac` still ships Godot's signature; nothing has
  launched either on a real Mac until the release workflow runs.
- **The windowed smoke draws off-screen only because it is told to.** This
  machine's shell has `DISPLAY=:0` and `WAYLAND_DISPLAY`; kept in the clean
  home, Godot chose Wayland, opened a window on the owner's desktop and once
  hung on exit, orphaned when its wrapper timed out. The clean home now
  carries no display, `--window` always uses `xvfb-run`, and a run that runs
  out of time is killed with its whole process group.
- **Big zips.** macOS and Windows get deflate (543 and 521 MB) because that
  is what Finder and Explorer open; the tar.xz is 255 MB. A DMG compressed
  with LZMA (`hdiutil` on a Mac) would roughly halve the macOS download.
- **Playwright's `userAgent` does not make a Mac.** `navigator.platform` and
  the client hints still say Linux, and the page reads those first; the check
  sets all three through `Emulation.setUserAgentOverride`.
- **The site's CSP is site-wide** (`tools/deploy.sh`): no inline script that
  is not hashed, and `connect-src` only to itself and a short list. The page
  is an external script reading a same-origin manifest for that reason.
- **A draft release has no tag yet.** The workflow checks out the default
  branch for its tools and downloads the draft by tag name with a token that
  can see drafts (`contents: write`).
