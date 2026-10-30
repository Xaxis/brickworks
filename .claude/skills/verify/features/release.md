# Release

The desktop release cycle: one version for the whole app, the packages for
Linux, macOS and Windows with the part library inside, the smoke test that
runs each one as a person would, the GitHub release in the public
repository of builds only (Xaxis/brickworks-releases), and the download page
that offers each system its own build. The cycle and its cadence are
`docs/RELEASING.md`.

<!-- covers: cli:say which build this is, cli:build the desktop packages, cli:smoke a package, ui:the boot splash, cli:publish a release, cli:check a release on three systems, ui:download page, cli:download page check, cli:move the downloads to the releases repository, cli:check every release link, cli:release train, ui:about and the licences, cli:about credits probe, cli:desktop token key, cli:outside probe -->

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
- `about and the licences`: Help, About names everyone whose work ships in
  Brickworks, one list in `src/ui/credits.gd` (`Credits.LIST`): Godot (and
  the type, Open Sans), the LDraw Parts Library (its CC BY notice, links to
  both licences), BrickNet, Rebrickable ("Catalog data: Rebrickable"), the
  LDraw OMR, Poly Haven and ldraw.xml, each with its terms and links
  (`Shell._credits`). Godot's licence (the engine's text, every component's
  notice and their licence texts, read from the running engine) and
  BrickNet's MIT text (`Credits.BRICKNET_MIT`) open in full over About in a
  read-only page (`Shell._read_licence`), the same on the web. About's words
  scroll in most of the window's height (`_about_room`), so its OK stays on
  a short window or a phone. The same list, both licences in full, is the
  `THIRD-PARTY-NOTICES.txt` every package carries (`tools/release_notices.gd`
  writes `Credits.notices()`); `build` refuses notices and `inspect` refuses
  a package whose copy lacks a licence's words (`NOTICES_SAY`: Godot's
  licence, its components, BrickNet's notice and permission, LDraw's notice,
  Rebrickable's credit). `docs/ATTRIBUTION.md` says why each term is what it
  is.
- `smoke a package`: `tools/release.py smoke FILE [--window]` unpacks it the
  way a person's system would into a fresh home, then: `--about` must say the
  version and that it is a release; the example car is opened from the
  package and written back with every part; the app is started with `--mcp`
  and `tools/mcp_check.py --port` drives it (search, clear, place two
  bricks, save, read back); its state must land in the fresh home. An
  AppImage also runs with `--appimage-extract-and-run`. `--window` draws the
  car on Xvfb (under `gpu`) and keeps `shots/release-<os>.png`, and fails
  a package that boots on Godot's logo because the splash project.godot
  names is not in it (Godot says "invalid boot splash"; see
  `the boot splash`).
- `the boot splash` (project.godot `application/boot_splash/*.pc`,
  `assets/splash.png`): the desktop app boots on the mark on the app's dark
  face (`Look.FACE`), not the engine's logo (walk256 DS1, 2026-10-25). The
  picture is a window's shape drawn from `web/icon.svg` by
  `tools/web/make_icons.mjs assets/splash.png`, kept to the window's aspect,
  so the mark is a fifth of its height; imported as `keep`, so the PNG
  itself is packed for Godot to read at boot. Named for the desktop (`pc`)
  alone and left out of the web's pack: the web's page covers its canvas
  with its own loading wall (`src/boot/shell.html`). `tests/test_boot_splash.py`
  reads the settings and the picture; the windowed smoke, the package.
- `publish a release`: `tools/release.py publish --draft` creates a draft
  release on `Xaxis/brickworks-releases` (`REPO`), on that repository's
  `main`, with the packages and `SHA256SUMS`, then compares GitHub's own
  SHA-256 of every asset with `dist/`. Without `--draft` it promotes that
  draft (never creates a public one), checks again, pushes the tag to origin
  on the commit that was built (`tag_source`; a tag already there must name
  it), and writes `web/releases.json` with pinned URLs for the page.
  `tests/test_release.py` pins the repository, the target and the tag push
  with GitHub and git answered in the test.
- `check a release on three systems`: `tools/release/releases_repo/release.yml`,
  which runs in Xaxis/brickworks-releases as `.github/workflows/release.yml`
  (Actions are free on a public repository; macOS minutes cost ten times
  Linux's on a private one). It checks out the source's tools from
  Xaxis/brickworks (`BRICKWORKS_SOURCE_TOKEN` once that is private, else the
  run's own token), downloads a release there, draft or published, on
  macos-15 (Apple silicon), macos-15-intel and windows-2022, runs `inspect`
  and `smoke` on each package, and on macOS `codesign --verify --deep
  --strict` and `lipo -archs`. It builds nothing: the part library is not in
  git. A change to it goes to that repository by hand.
- `move the downloads to the releases repository`:
  `tools/release/releases_repo.sh [--go] [--dir=DIR]`. A dry run reads
  v0.8.0 and v0.9.0 on Xaxis/brickworks, downloads every asset into DIR,
  checks each against GitHub's SHA-256 and the release's `SHA256SUMS`,
  prints them, and prints every step `--go` would take. `--go` (the owner's
  yes only) creates the public repository with one commit by Xaxis (the
  README and the workflow from `tools/release/releases_repo/`), copies each
  release as a draft, compares every uploaded file's SHA-256, title and
  notes with the original's, publishes only when all match, then fetches
  each file with no login. A mismatch exits 1 and leaves a draft. It reads
  the source through `from_source`, which runs `release view` and
  `release download` and refuses anything else, and every write must name
  the new repository. Run again, it checks what is there and redoes nothing.
- `check every release link`: `tools/release/release_links.sh [MANIFEST]`
  asks for every release page and file in `web/releases.json` with no login,
  following GitHub's redirect: a page must answer 200, a file 200 with the
  manifest's size. `tools/release/ship.sh` runs it before a deploy and holds
  on any failure, so a branch pointing at a repository that does not exist
  yet cannot go out. `tests/test_release_links.py` runs it against a server
  on this machine that redirects as GitHub does: all there, a file missing,
  a file of another size.
- `release train`: `tools/release/train.sh stage TAG BRANCH --after PREV
  --checks ... --probes ... --units ... --title ...` stages a release and
  ships it in turn, detached: it waits until PREV's `_lead.out` says
  brickworks.diy serves it, makes the release worktree, merges BRANCH,
  refuses a dirty or half-merged tree, runs the lists and probes, then
  `ship.sh`, and retires the worktrees once live. `status` says each one's
  step, its checks passed of all, and when it should serve, under what
  brickworks.diy serves and since when; `hold TAG`
  and `release TAG` set and lift a hold. tools/release/README.md has the
  rest. `tests/test_release_train.py` runs it with stand-ins for the hour's
  work.
  With `RELEASES_TOKEN` set it asks the releases repo's addresses through
  GitHub's API with the token instead (a release by tag, a file as its
  asset's bytes, followed to the signed URL, the token never sent past the
  API): the check that still means something once the repo is private (U8).
  Both ways 15 of 15 on 2026-10-29 (a gh token standing in).
- `desktop token key` (`tools/desktop_key.mjs`): `new FILE` makes the RSA key
  a desktop token is signed with, the private half to FILE (0600, never over
  another) and only the public half's id and KEYS line printed; `public`
  prints the id of the key in DESKTOP_TOKEN_KEY; `sign FILE JSON` signs claims
  with a test key (the desktop pass probe's). docs/RELEASING.md, "The desktop
  token's key", says how to set and rotate it.
- `download page`: `web/download.html` with `web/download.js`, served at
  `/download` (tools/site.py copies every file in `web/`; the old
  `/download.html` 308s to `/download`). Reads same-origin `releases.json`, detects the
  system (client hints, `navigator.platform`, the user agent; a phone or an
  iPad is "mobile", Linux on ARM "other"; `?os=` chooses one), and offers
  its primary file as the one primary button, version and size in small
  type, the other systems as links (`?os=`, in place). Folded away
  (`details.qa`): the first launch, one line saying what happens, its steps
  (the Gatekeeper and SmartScreen ones only while unsigned, what it needs
  read from the packages), and Verify the download, a command per file
  that prints OK or True. What is new: the four lines written for the
  release in `<ul data-highlights="X">`, or else the summary's first four
  sentences. A phone is told the desktop app is for a computer and offered
  the web app first. No release in the manifest reads "on its way" with a
  link to the web app (2026-10-20: the owner found the page that listed
  everything at once broken and "way too verbose").
- `download page check`: `tools/web/download_check.mjs` serves `web/` with a
  CSP at least as strict as the site's and loads the page as Linux, macOS,
  Windows and an Android phone through the DevTools protocol, then checks
  every link the page has.
- `outside probe`: nothing a probe or a check does opens on the owner's
  desktop (noopen, 2026-10-29). Every link and Show in folder goes through
  `Outside` (src/ui/outside.gd), held in any script's run or with
  `BRICKWORKS_OPEN_NOTHING`; `tests/test_outside.py` fails a direct call;
  `tools/probe.sh` stubs the desktop's openers and fails a run that reached
  one. `src/dev/outside_probe.gd` presses the share panel's Open, Help's
  Website and Documentation, and the status bar's Show in folder after
  File, Export, LDraw.

  ```sh
  tools/probe.sh outside_probe
  ```

  Proves it when: every line is `ok`, each opener keeps exactly its address
  (`https://brickworks.diy/m/outside-probe-model`, `https://brickworks.diy`,
  the docs page) or the exported .ldr's path in `Outside.opened`, it ends
  `outside probe: all checks passed`, and probe.sh prints no `asked the
  desktop to open` lines.

## How to reach it

```sh
godot --headless --path . -- --about        # from source
python3 tools/release.py version            # do VERSION, project.godot and CHANGELOG agree?
python3 tools/release.py build linux        # or mac, windows; all three by default
python3 tools/release.py inspect            # read dist/<version>/ back
tools/probe.sh about_credits_probe -- --shots=DIR   # Help, About, and the licences in full
godot --headless --path . --script res://tools/release_notices.gd -- OUT   # the packages' THIRD-PARTY-NOTICES.txt
python3 tools/release.py smoke dist/0.1.0/Brickworks-0.1.0-linux-x86_64.tar.xz --window
python3 tools/release.py manifest --local --out=/tmp/releases.json
node tools/web/download_check.mjs --manifest=/tmp/releases.json --shots=shots
python3 tools/release.py publish --draft --tag=v0.0.0-upload-test --target=main --no-manifest
gh workflow run release.yml -R Xaxis/brickworks-releases -f tag=v0.1.0
tools/release/releases_repo.sh --dir=<scratch>      # a dry run: about 5 GB downloaded
tools/release/release_links.sh                      # this checkout's web/releases.json
tools/release/train.sh status                       # each release staged: its step, checks, what is live
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
tar.xz's binary executable; and under every package `licences:
ATTRIBUTION.md, THIRD-PARTY-NOTICES.txt; the notices (94 KB) say Godot's
licence, its components' notices, BrickNet's MIT text, LDraw's notice,
Rebrickable's credit`. It exits 1 on any of those being wrong: 0.4.0's
tar.xz fails with `lacks BrickNet's MIT text, LDraw's notice, Rebrickable's
credit` (its notices were Godot's alone; BrickNet's permission was nowhere
in it, 2026-10-29). Without a build,
`tests/test_release.py` makes small packages with `extras()` and reads
them back the same way.

```sh
tools/probe.sh about_credits_probe -- --shots=DIR
```

Proves it when: it ends `about credits probe: all checks passed`: each of
the seven credits in About with its name, what it is and its terms,
scrolled into sight; Rebrickable's "Catalog data: Rebrickable"; LDraw's
links to CC BY 2.0 and 4.0; About and its OK inside a 1400 x 900 window;
Tab from OK reaches "Godot's licence and notices", Return opens it (about
2,240 lines, the components' notices among them), the keys on its words,
Page Down scrolls, Escape puts it away with About still up; the same for
"BrickNet's licence" (22 lines, `Credits.BRICKNET_MIT` exactly), put away
with Close; every control named. Its pictures: About at the top and the
end, and each licence open. On the web, `dialogs_flow.mjs` audits About at
phone and tablet sizes with the rest of More (`rest`), and
`window.brickworksControls` names `about_read_godot`,
`about_read_bricknet`, `licence_text` and `licence_close` while they show.

```sh
python3 tools/release.py smoke dist/0.1.0/Brickworks-0.1.0-linux-x86_64.tar.xz --window
python3 tools/release.py smoke dist/0.1.0/Brickworks-0.1.0-linux-x86_64.AppImage
```

Proves it when: every line is `ok` and it ends `... starts, loads the part
library, opens a model and takes bricks`; `shots/release-linux.png` shows the
example car on its baseplate. To see the boot itself, record the unpacked
package's first seconds on an Xvfb of its own (`ffmpeg -f x11grab`): the mark
on the dark face, then the app.

```sh
tools/release/release_links.sh
```

Proves it when: every line is `ok` and it ends `release_links: all N
addresses in ... answer`, exit 0 (2026-10-27, main's manifest: 51
addresses, 31 s). Against a manifest naming a repository that does not
exist, each address is `FAIL ... answered '404 ...'` and it exits 1; a file
whose size is one byte off is `FAIL ... answered '200 <size>'`.

```sh
python3 tools/minitest.py tests/test_release_train.py
```

Proves it when: `4 passed`, in about 10 s. Each test makes a repository
with an origin and unit worktrees, and stand-ins for release_wt.sh,
merge_unit.sh, ship.sh, check.sh and probe.sh (retire_wt.sh is the real
one), and runs the train detached as staged: it waits for the release
before it, then ships the checks, probes and title as edited after staging;
a hold stops it before the merge and before the ship; a tree left dirty or
mid-merge is refused, and so is a probe with a FAIL line or a nonzero exit;
it stops when the release before held, was killed, or died without a word,
and at its deadline; and `status` reads `checks: 2 of 4 passed; failed: io (passed
alone); 1 to run` mid-ship and `live: brickworks.diy serves it (SHA)` after,
its first line `live: brickworks.diy serves SHA, TAG's, since HH:MMZ`, and
a ship begun by hand is listed with its ETA (a median ship after it began)
and the train behind it a ship after that.
On a real release, `tools/release/train.sh status` while it waits says
`step: HH:MMZ waits for PREV to serve (until HH:MMZ)`. Against the real
release-out on 2026-10-30 with rel-m218 shipping by hand: `live:
brickworks.diy serves e5c5deaf, rel-m217's, since 06:30Z`, `a ship takes
about 38 min`, and `rel-m218: shipping, begun by hand at 06:36Z ... eta:
serves about 07:14Z`.

```sh
tools/release/releases_repo.sh --dir=<scratch>
```

Proves it when: for v0.8.0 and v0.9.0 it prints each of the five files'
SHA-256 (the same as `gh release view TAG -R Xaxis/brickworks --json assets`
gives as `digest`), then `TAG: every file matches GitHub's SHA-256 and
SHA256SUMS`, then the `would:` lines (repo create, the push of the first
commit by Xaxis, release create `--draft`, release edit `--draft=false`),
and ends `dry run: nothing was created, uploaded or changed`, exit 0.

```sh
node tools/web/download_check.mjs --manifest=/tmp/releases.json --shots=shots
```

Proves it when: linux is offered the AppImage, macos the universal zip and
windows the windows zip, each as the one primary button with the version and
size, about 100 words before anything is opened (150 at most); the phone is
offered the web app first and told why; the other systems are one click away,
each with its own steps and checksums, nothing past the edge at 1280 or 390 px
with everything opened; every link answers; nothing is refused by the CSP; it
ends `the download page offers each system its own build`. With a manifest
that has no release it reads `no release yet` for all four.

## Gotchas

- **Public only by promoting a checked draft.** `publish` without `--draft`
  refuses to create a release: it only promotes a draft that exists, which is
  the one the three-system workflow ran. It used to create a public "latest"
  release in one step, and it ignored flags it did not know, so `publish
  --help` (or a typo such as `--drfat`) began exactly that; it was stopped part
  way through the upload, while GitHub still held it as a draft. Every command
  now refuses a flag it does not take, and `--help` anywhere prints help.
  `tests/test_release.py` holds all three.

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
- **A draft release has no tag yet.** The workflow checks out the source's
  main for its tools and downloads the draft by tag name with a token that
  can see drafts (`contents: write`). The tag in the releases repository is
  on its own README commit; the source's tag is pushed by `publish`.
- **gh's token here has no `workflow` scope**, so a push of
  `.github/workflows/` over HTTPS is refused. `releases_repo.sh` pushes its
  first commit over SSH.
