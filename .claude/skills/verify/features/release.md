# Release

The desktop release cycle: one version for the whole app, the packages for
Linux, macOS and Windows with the part library inside, the smoke test that
runs each one as a person would, the GitHub release in the public
repository of builds only (Xaxis/brickworks-releases), and the download page
that offers each system its own build. The cycle and its cadence are
`docs/RELEASING.md`.

<!-- covers: cli:say which build this is, cli:build the desktop packages, cli:smoke a package, ui:the boot splash, cli:publish a release, cli:check a release on three systems, ui:download page, cli:download page check, cli:move the downloads to the releases repository, cli:check every release link, cli:release train, ui:about and the licences, cli:about credits probe, cli:outside probe, lib:the desktop app updates itself, lib:the signed update manifest, ui:update notice, ui:check for updates reinstall and restart, cli:update helper, cli:updater probe, cli:update check -->

## Sub-features

- `say which build this is`: `VERSION` is the version, and `project.godot`'s
  `config/version` is kept equal to it by `tools/release.py version --set`
  (the macOS Info.plist and the Windows file version are read from there at
  export). `src/build_info.gd` reads it, and for a release the stamp
  `res://release.json` that only a release build carries (commit and date).
  `-- --about` prints `BuildInfo.describe()` and quits before the catalogue
  loads, in the language chosen in Settings or by `--lang=` (English in a
  fresh home, which the smoke test reads); Help shows the same line; the window title is `Brickworks <version>`.
  `tools/check.sh` and CI's `check` both run `tools/release.py version`.
- `build the desktop packages`: `tools/release.py build [linux mac windows]`
  stages `git archive HEAD` with only the meshes the catalogue names, exports
  each preset, packages them the way each system's own apps come
  (docs/DISTRIBUTION.md): the AppImage, a .deb (`write_deb`) and the tar.xz,
  each with the menu entry, hicolor icons and MIME types of the four model
  files (`desktop_files`); a universal macOS app, its model types declared
  (`declare_types`) and signed by rcodesign (ad hoc without a Developer ID),
  in a disk image laid out to drag onto Applications (`write_dmg`:
  mkfs.hfsplus, libdmg-hfsplus and a `.DS_Store`, built on Linux and read
  back by fsck and file by file), signed and notarised with the app
  (`sign_dmg`); the per-user NSIS installer for Windows (`write_installer`,
  `tools/release/windows/brickworks.nsi`); and, for one release, the zips
  from before them. It writes
  `SHA256SUMS`, and reads every package back: Info.plist version, Mach-O
  architectures and oldest macOS per slice, the code signature parsed from
  the binary, PE machine, version and Authenticode, archive contents, the
  .deb's control, command link, types and icons, the disk image's
  Applications link, volume icon, layout and types, and the installer's
  version. Into
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
- `smoke a package`: `tools/release.py smoke FILE [--window]` unpacks or
  installs it the way a person's system would into a fresh home (the .deb's
  files under a folder of their own; on a Mac the disk image mounted and its
  app copied to /Applications; on Windows the installer run with
  /VERYSILENT), then: `--about` must say the
  version and that it is a release; the example car is opened from the
  package and written back with every part; the app is started with `--mcp`
  and `tools/mcp_check.py --port` drives it (search, clear, place two
  bricks, save, read back); each of .ldr, .mpd, .io and .lxf is given to it
  as a bare path, as a double-click gives it (`opens_models`), from a folder
  with a space in its name, and must say `opened <path>: N parts` and write
  back N (a package cannot draw a part a Studio file builds from LDraw
  subparts, which it has only as meshes: it says `could not build a part
  the file carries` and writes that part back too, bay_2025.io's 5 + 1);
  then the system's own double-click on two models, the second with
  the first still open, each in a window of its own (a hold whose process
  is not a running Brickworks is not one): gio with the .deb's
  entry and MIME types (and each window's WM_CLASS the entry's
  StartupWMClass), Launch Services' `open` on a Mac, `os.startfile` on
  Windows, where the Start menu entry, Settings ▸ Apps line, ProgIDs and
  then the uninstaller are checked too; an AppImage must carry its entry,
  icons and types inside; its state must land in the fresh home. An
  AppImage also runs with `--appimage-extract-and-run`. `--window` draws the
  car on Xvfb (under `gpu`) and keeps `shots/release-<os>.png`, and fails
  a package that boots on Godot's logo because the splash project.godot
  names is not in it (Godot says "invalid boot splash"; see
  `the boot splash`). Then it starts the package in a window with `--mcp`
  and asks it over the socket, as a session does (`ask_for_best`):
  `open_model` Car, `render_model` at Best (product look, 720p, followed
  through `job`), `render_queue` list. `judge_best` fails no picture, Best
  not path traced, a shape the path tracer refused, a blank picture, and
  SSIM under 0.98 against `tools/release/best_car.png` (160 x 90 grey); the
  picture is kept as `shots/release-<os>-best.png`. A release template once
  refused every shape the editor traced (0.12.0). The sign-in screen is up
  in the clean home; the socket answers behind it, no account needed.
  `tools/release.py best-reference` makes `best_car.png` again from this
  checkout's editor (an imported checkout, under `gpu`).
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
  macos-15 (Apple silicon), macos-15-intel, windows-2022 and ubuntu-24.04,
  runs `inspect` and `smoke` on each package (the disk image, the installer
  and the .deb first, then the zips while a release has them), on macOS
  `hdiutil verify`, `codesign --verify --deep --strict` and `lipo -archs` on
  the mounted image's app and a screenshot of the image's window kept as a
  run artifact, and on Ubuntu `apt install` of the .deb (/ keeps its mode,
  the four types default to the app, `brickworks --about`) and `apt remove`
  leaving nothing. The Intel runner's only GPU is Apple's paravirtual one,
  which MoltenVK aborts on, so the smoke prints its double-click as `--  not
  run here` with the reason (`mac_cannot_draw`) instead of failing; a check
  this machine cannot make neither passes nor fails. It builds nothing: the part library is not in
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
  brickworks.diy serves it, makes the release worktree, merges BRANCH at
  its tip then (a later commit waits for the next release), refuses a dirty
  or half-merged tree, runs the lists, then the probes (four at a time, at
  the release's priority) and `ship.sh` side by side, main moving only once
  every probe passed (`TAG.probes`), and retires the worktrees once live.
  Each check failing in the battery runs once more alone (timing checks
  not); what still fails then runs on brickworks.diy as it is, after the
  battery and as a unit's check would (`ship.sh`, `SHIP_STALE`), and the
  train's mark on the live database goes once its battery is done
  (`SHIP_LIVE_MARK`). `status` says each one's step, its checks and probes
  passed of all, which of its failures already fail on brickworks.diy, and
  when it should serve, under what brickworks.diy serves and since when; `hold TAG`
  and `release TAG` set and lift a hold. Restaging a stopped TAG clears
  its worktree and branch when they hold its merge alone, and refuses when
  they hold a fix of their own. `reship TAG [--probes ...] CHECK...` ships
  a TAG whose train stopped after its ship began, from the worktree it kept
  (a check's fix committed there), on the same preview when only checks or
  release tools changed (SHIP_REUSE), beside the probes that did not pass,
  and keeps the train's record so a release staged after it waits for it.
  `--accept CHECK "REASON"` (at reship or stage) ships past a check that
  failed on brickworks.diy too as the same script, and is refused for one
  that passes there; the log, status and merge message name it with both
  failure lines.
  tools/release/README.md has the
  rest. `tests/test_release_train.py` runs it with stand-ins for the hour's
  work.
  With `RELEASES_TOKEN` set it asks the releases repo's addresses through
  GitHub's API with the token instead (a release by tag, a file as its
  asset's bytes, followed to the signed URL, the token never sent past the
  API): the check that still means something once the repo is private (U8).
  Both ways 15 of 15 on 2026-10-29 (a gh token standing in).
- `download page`: `web/download.html` with `web/download.js`, served at
  `/download` (tools/site.py copies every file in `web/`; the old
  `/download.html` 308s to `/download`). Reads same-origin `releases.json`, detects the
  system (client hints, `navigator.platform`, the user agent; a phone or an
  iPad is "mobile", Linux on ARM "other"; `?os=` chooses one), and offers
  its primary file as the one primary button, version and size in small
  type, the other systems as links (`?os=`, in place). Folded away
  (`details.qa`): the first launch, one line saying what happens, its steps
  for the kind of file offered (`data-kind`: the disk image, the
  installer, or a release's zips before them; the Gatekeeper and
  SmartScreen ones only while unsigned; how to uninstall; the .deb's
  command where a release has one, `data-has`; what it needs read from the
  packages), and All files and checksums: every file for the system, linked
  with its size, and a command per file that prints OK or True. The file
  offered first is the first of `PREFER`'s kinds a release has. What is new: the four lines written for the
  release in `<ul data-highlights="X">`, or else the summary's first four
  sentences. A phone is told the desktop app is for a computer and offered
  the web app first. No release in the manifest reads "on its way" with a
  link to the web app (2026-10-20: the owner found the page that listed
  everything at once broken and "way too verbose"). Free, like the web app
  (2026-11-02, docs/PLANS.md): every link is the file's public address, with
  no sign-in and no plan asked.
- `download page check`: `tools/web/download_check.mjs` serves `web/` with a
  CSP at least as strict as the site's and loads the page as Linux, macOS,
  Windows and an Android phone through the DevTools protocol, then checks
  every link the page has. `--manifest=FILE` serves another releases.json:
  one with the disk image, the installer and the .deb holds the page to
  offering them first, with their steps, sizes and checksums.
- `open a model by double-click`: `TabSession.given_file()` is the first
  bare argument that is an existing .ldr, .mpd, .io, .lxf or .lxfml file,
  as each system hands a double-clicked model over (Exec=brickworks %f, the
  installer's `"%1"`, the openFiles event Godot puts in the arguments on a
  Mac); `Main._open_given` opens it (`ModelFilePicker.read` turns Studio's
  and LDD's into LDraw) in a session of its own, so a second double-click
  with the app open comes up in a window of its own and replaces nothing,
  and says `opened <path>: N parts` on stderr and in the log, or `could not
  open`. `src/dev/given_file_probe.gd` runs the editor build on each kind
  with `--out=` and on a file that is not a model:

  ```sh
  godot --headless --path . --script src/dev/given_file_probe.gd
  ```

  Proves it when: each kind says it opened N parts, N > 0, and the file
  written back holds N; the garbled one says it could not open; it ends
  `given_file: each kind opens as a double-click gives it`.
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
- `the desktop app updates itself` (docs/UPDATES.md): `Updater`
  (src/net/updater.gd) asks once a day, 8 s after the model is back, for
  `releases/latest/download/latest.json` on Xaxis/brickworks-releases; in
  Settings, Updates, Automatic (the default) downloads the newer version
  beside the install (`.brickworks-update/<version>/`), checks its size and
  SHA-256, unpacks it, and puts it in as the app quits; Ask first says it is
  out; Off asks nothing until Help does. A test server takes GitHub's place
  only by `BRICKWORKS_UPDATE_URL`, set by hand (plain HTTP only on
  127.0.0.1). `--update=check|fetch|install|reinstall|restart` drives it from
  a command line and prints `update: <mode>: <what it says>`.
- `the signed update manifest`: `Updates` (src/net/updates.gd) believes
  latest.json only under an RSA/SHA-256 signature by one of the two keys it
  carries (their private halves only in `.env`: `UPDATE_SIGN_KEY`,
  `UPDATE_SIGN_KEY_BACKUP`), then refuses a manifest not Brickworks', a
  version not newer, a file with no size or SHA-256, plain HTTP, and any
  address or redirect off github.com, objects.githubusercontent.com,
  release-assets.githubusercontent.com and brickworks.diy.
  `tools/release.py publish --draft` signs it with both keys and uploads it
  with the packages; `tools/release.py latest --check FILE` reads one as the
  app would.
- `update notice`: "Brickworks 0.17.0 is out" (or "is ready") above the
  model, in UpdateOffer's look: What's new (the release notes' first
  paragraph), Update and restart, Later. Where the copy cannot write its
  install, the button reads Download and opens brickworks.diy/download; a
  Mac app run from Downloads or a disk image reads Move to Applications and
  update.
- `check for updates reinstall and restart`: Help, Check for updates…
  ("You're up to date (0.16.0)" or what is new), Reinstall Brickworks…
  (this same version downloaded again, checked the same way) and Restart
  Brickworks, desktop only (src/ui/update_dialog.gd, Shell DESKTOP_ONLY).
  Every restart writes the working model first and comes back in the same
  session (`--session=`), on the same model.
- `update helper`: `src/net/update_helper.sh` (Linux, macOS) and `.ps1`
  (Windows), written to `user://updates/` and run as the app quits: waits
  for it to end, swaps the folder or the AppImage by renames, asks the new
  copy `--about`, starts it and waits for it to say its window is up, and
  puts the old copy back (started with `--update-failed=`) when it cannot.
- `updater probe`: `src/dev/updater_probe.gd` signs a release with a key of
  its own, serves it with `tools/update_check.py serve`, and drives the real
  scene through every refusal, the notice, the download and the hand-over.
- `update check`: `tools/update_check.py` builds two versions with a small
  library (`packages`), serves them, and drives real packages through every
  refusal and a real install, restart, reinstall, install on quit and put
  back; `lay` and `run --laid` do it on a runner that has no key.

## How to reach it

```sh
godot --headless --path . -- --about        # from source
python3 tools/release.py version            # do VERSION, project.godot and CHANGELOG agree?
python3 tools/release.py build linux        # or mac, windows; all three by default
python3 tools/release.py inspect            # read dist/<version>/ back
tools/probe.sh about_credits_probe -- --shots=DIR   # Help, About, and the licences in full
godot --headless --path . --script res://tools/release_notices.gd -- OUT   # the packages' THIRD-PARTY-NOTICES.txt
python3 tools/release.py smoke dist/0.1.0/Brickworks-0.1.0-linux-x86_64.tar.xz --window
python3 tools/release.py best-reference     # the editor's Best of the car, smoke's reference
python3 tools/release.py manifest --local --out=/tmp/releases.json
node tools/web/download_check.mjs --manifest=/tmp/releases.json --shots=shots
python3 tools/release.py publish --draft --tag=v0.0.0-upload-test --target=main --no-manifest
gh workflow run release.yml -R Xaxis/brickworks-releases -f tag=v0.1.0
tools/release/releases_repo.sh --dir=<scratch>      # a dry run: about 5 GB downloaded
tools/release/release_links.sh                      # this checkout's web/releases.json
tools/release/train.sh status                       # each release staged: its step, checks, what is live
tools/probe.sh updater_probe                        # the updater on the real scene, against a local server
python3 tools/minitest.py tests/test_updates.py     # signing, the helper's swaps and put-backs
python3 tools/update_check.py packages --versions=0.90.0,0.91.0 --out=DIR linux   # ~small test packages
python3 tools/update_check.py run --old DIR/0.90.0/Brickworks-0.90.0-linux-x86_64.AppImage --new DIR/0.91.0/Brickworks-0.91.0-linux-x86_64.AppImage
python3 tools/release.py latest --check dist/<version>/latest.json
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
library, opens a model and takes bricks` (`, and traces it at Best` with
`--window`); `shots/release-linux.png` shows the example car on its
baseplate and `shots/release-linux-best.png` the car path traced, with the
lines `ok    path-traced Best of the car over MCP: N s, the app up in N s`
and `ok    ...and the editor's own picture of it: SSIM 0.9xx`. On
2026-11-01: the 0.13.0 download and an export of stage225 (95b874c) passed,
Best in 5 s, the app up in 7 s, SSIM 0.999; an export of ae0ba0e (the commit
before Best's de-indexed BLAS) failed `path-traced Best of the car over MCP:
no picture`, the job `Cancelled.` and 27 shapes refused.
To see the boot itself, record the unpacked
package's first seconds on an Xvfb of its own (`ffmpeg -f x11grab`): the mark
on the dark face, then the app.

```sh
python3 tools/minitest.py tests/test_release.py
```

Proves it when: every test passes. Without a GPU, smoke runs on a stand-in
package whose Best answers no picture, a blank one, the reference mirrored,
one not path traced and one with a shape refused: each exits 1 with its own
`FAIL` line; the reference itself passes with `SSIM 1.000`. With the Best
step taken out of smoke, those six fail.

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

Proves it when: `22 passed`, in about 80 s, and 8 copies at once all pass
(about 56 s each); the killed-train test passes 1000 runs of 16 at once at
load 33 (4 of 300 failed so before 2026-11-03). Each test makes a repository with an origin and unit
worktrees; train.sh, ship.sh, preview_lib.sh and retire_wt.sh are the real
ones, with stand-ins for release_wt.sh, merge_unit.sh, the gates,
deploy.sh, preview_checks.sh, check.sh and probe.sh, and for heavy, godot
and curl by HOME and PATH. It runs the train detached as staged: it waits
for the release before it, then ships the checks, probes and title as
edited after staging; a hold stops it before the merge and before the
probes and the ship, and one set while the ship waits for its probes still
holds; the battery runs while a probe still runs, and the preview is
promoted only after the last probe ended (`probe_times`, `check_times`,
`promoted`); a probe failing then stops the ship before main moves, the
result `stopped: probes failed: NAME (TAG_probe_NAME.log)`; every check
failing on the preview runs again alone whatever else failed, a timing
check not (`SHIP: held, failed on the preview: progress`); what still fails
runs on brickworks.diy only after the preview's battery, at no priority and
with the train's mark gone (`check_how`), status saying `already failing
there: people; failing there, changed since: light_render; passing there:
keys`; `--accept` ships past progress where it fails there too, its merge
message naming it, and is refused for keys, which passes there; a ship that ends first
stops the probes beside it; preview_checks.sh runs 3 checks at once
(`PC_AT_ONCE`) and begins none once the probes failed (`exit=125`); a tree left dirty or
mid-merge is refused, and so is a probe with a FAIL line or a nonzero exit;
it stops when the release before held, was killed, or died without a word,
and at its deadline; stopped by hand, by its group, its pid alone or an INT,
it says `stopped: killed`, its probes stop with it and nothing of it runs
on; its ship, stopped with the group while it waits for the probes, writes
143 to its `.done`, and left to run on holds, writing 1 (0 of 5400 stops of
ship.sh so at load 32-74 went on; 4 of 1800 ran on before 2026-11-03),
and killed outright by its pid its work takes no step after; and `status` reads `checks: 2 of 4 passed; failed: io; 1 to run`
mid-ship, `failed: io (passed alone)` once ship.sh has run it alone, and `live: brickworks.diy serves it (SHA)` after,
its first line `live: brickworks.diy serves SHA, TAG's, since HH:MMZ`, and
a ship begun by hand is listed with its ETA (a median ship after it began)
and the train behind it a ship after that. Six probes run no more than
four at once, and one that fails beside others says `beside others: again
alone` and passes alone (`TRAIN_PROBES_AT_ONCE=1` stops on it). A commit to the branch while it
merges ships in the next release, not this one (`tip` in the spec is the one
merged); a restage after a failed probe says `cleared TAG's attempt before
(its merge alone)` and ships, and one over a fix staged or committed in the
stopped release's worktree is refused, the fix kept.
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
with everything opened; every link answers; nothing is refused by the CSP;
the Linux button, pressed, asks its public address and nothing of
/api/plans, with no sign-in shown (`free linux:`); it ends `the download
page offers each system its own build`. With a manifest
that has no release it reads `no release yet` for all four.

```sh
tools/probe.sh updater_probe
python3 tools/minitest.py tests/test_updates.py
```

Proves it when: the probe prints 39 `ok` lines and ends `the desktop app
checks, refuses what it must, downloads, and hands over the restart with the
model kept` (among them: the two release keys each load under their own id;
Check for updates refuses a bad signature and `0.0.1, which is older`; in
Automatic a download is refused for a wrong SHA-256, a short size and
`refused an address off GitHub and brickworks.diy: https://example.com/...`;
Update and restart hands `/bin/sh helper.sh install <pid> <install> <staged>
... 99.0.0` with `--session=<id>`); and the tests print `13 passed`.
Before 2026-11-03 (0.15.0) Help had only `keys` and `tour` and no release
carried a latest.json.

```sh
python3 tools/update_check.py run --old OLD --new NEW --log=DIR/log.txt
```

Proves it when: every line is `ok` and it ends `<old> → <new>: every refusal
held, and it updates, restarts, reinstalls and puts back`, for the AppImage
and the tar.xz alike: six refusals with their words, `Check for updates:
Brickworks B is out`, `Update and restart (by a redirect on the same host):
report: running B; model “House”, N parts; session S` with the same model,
parts and session as before the restart, the copy in place says B and
nothing is left in `.brickworks-update/`, Restart and Reinstall come back
the same, Automatic's next start says B, and a copy that cannot start is
put back and A started again.

On macOS and Windows the same, from a runner: `update_check.py lay --old
OLD --new NEW --port=8697 --out=DIR` here (the runner has no signing key),
then `run --laid=DIR` there (docs/UPDATES.md). It proves it when it
ends the same way. On Windows the log-judged steps start `Brickworks.exe`:
the console wrapper keeps its own file in use until the new copy ends.

## Gotchas

- **0.15.0 and older have no updater.** The first version with one, and its
  latest.json, has to be downloaded by hand once; from then on it updates
  itself. A release with no latest.json leaves `releases/latest/download/
  latest.json` answering 404, said as `Couldn't check for updates: the
  server answered 404`.
- **GitHub sends release downloads to release-assets.githubusercontent.com**
  (since 2025), not objects.githubusercontent.com: both are let in. A new
  host there refuses every update until `Updates.HOSTS` names it.

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
