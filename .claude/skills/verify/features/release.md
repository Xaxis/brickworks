# Release

The desktop release cycle: one version for the whole app, the packages for
Linux, macOS and Windows with the part library inside, the smoke test that
runs each one as a person would, the GitHub release in the public
repository of builds only (Xaxis/brickworks-releases), and the download page
that offers each system its own build. The cycle and its cadence are
`docs/RELEASING.md`.

<!-- covers: cli:say which build this is, cli:build the desktop packages, cli:smoke a package, ui:the boot splash, cli:publish a release, cli:check a release on three systems, ui:download page, cli:download page check, cli:coming soon check, cli:move the downloads to the releases repository, cli:check every release link, cli:a model file's picture, cli:check the .deb's thumbnails, cli:release train, ui:about and the licences, cli:about credits probe, cli:outside probe, lib:the desktop app updates itself, lib:the signed update manifest, ui:update notice, ui:check for updates reinstall and restart, cli:update helper, cli:updater probe, cli:update check -->

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
  back N: bay_2025.io all 6, its Part Designer part made from `3001.dat`,
  which a package has only as a mesh (the file carries Studio's copy, drawn
  from the library's `s/3001s01.dat`), what it lacks fetched as LDraw text
  from the parts store as the web does (`carried parts fetched`; the
  primitives come in the package, staged from `vendor/ldraw/p`). Then
  `carried_offline`: what was fetched kept in the home (`…/ldraw/parts/`),
  bay_2025.io opened again with no network (`BRICKWORKS_API` at a port
  nobody listens on) and drawn whole from it, and in a home that never
  fetched it 5 of 6 with `m1a2b3c4_2025408_163200 could not be drawn: … the
  parts store could not be reached` on its `opened` line, the sixth written back;
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
- `a model file's picture` (`src/render/model_thumbnail.gd`,
  `src/boot/brickworks_loop.gd`): `--headless --thumbnail MODEL PICTURE
  [SIZE]` draws an .ldr, .mpd or .io as the app's corner view
  (`ModelShot.ANGLES["corner"]`, framed as it frames) in a PNG SIZE px square
  (256 by default, 16 to 1024) on a clear ground, and quits: `thumbnail:
  NAME, N of M parts drawn, T ms`, exit 0; parts the library has not got are
  left out, and a file with none it knows says so and exits 1, so a file
  manager keeps the type's icon. It is drawn on the CPU from the part meshes
  (a thumbnailer runs where there is no display or graphics card), a band of
  rows per core, with seams between parts and see-through parts over the
  rest. The project's main loop is `BrickworksLoop`: given the flag it puts a
  scene of one empty node in main.tscn's place before the engine loads it,
  since compiling main.gd alone took 3.5 s and an export template refuses
  `--script` and a scene on the command line; without the flag it does
  nothing. The .deb carries `/usr/share/thumbnailers/dev.brickworks.app.thumbnailer`
  (`thumbnailer_entry`: `Exec=brickworks-thumbnailer %i %o %s`, the three
  types) and `/usr/bin/brickworks-thumbnailer` (`thumbnail_runner`), which
  runs the app from a data folder made for the run and removed after, under
  TMPDIR or else /tmp (the sandbox's), so Godot's log of the run never
  pushes one of the app's own out. `inspect_deb` reads both back
  (`thumbnailed`).
- `check the .deb's thumbnails` (`tools/release/thumbnail_check.py`): dpkg
  installs the .deb into a root of its own, `update-mime-database` runs as
  its trigger does, and GNOME's own `GnomeDesktopThumbnailFactory`
  (`gnome_thumbnail.py`, Python GI) is asked for each model's picture at
  Files' 256 px, as Files asks: it finds the entry by GIO's MIME type and
  runs it through `bwrap` on the PATH. On this box bwrap cannot start (Ubuntu
  24.04's `kernel.apparmor_restrict_unprivileged_userns=1`: no thumbnailer
  of any kind is drawn here), so `bwrap` is `bwrap_standin.py`: GNOME's own
  seccomp filter from its descriptor, its environment, its working folder,
  death with the factory, each path through the binds, TMPDIR as the
  sandbox's /tmp, no display; and `sandbox_view.c`, preloaded, refuses every
  file the sandbox has not got (ENOENT). `--trace` follows one run with
  strace and names what the thumbnailer found outside the sandbox anyway.
  `--installed` uses the system's bwrap on a package installed in /, for a
  runner that can make the namespaces, and fails if GNOME's factory is
  missing rather than check nothing; the release workflow's Ubuntu run does
  that. The .deb's smoke runs it (`thumbnails_linux`).
- `graphics mode` (`src/render/graphics_mode.gd`,
  `tools/release/package/launcher.c`): the desktop draws in its full mode
  (Forward+) or its simpler one (Compatibility, on OpenGL, as the web does).
  A Mac starts through the launcher, the bundle's `CFBundleExecutable`
  (`launch_through`, built with a pinned zig as one universal binary,
  `build_launcher`), which asks Metal what the GPU is before Vulkan starts:
  on an Intel slice with Apple's paravirtual GPU, no Metal GPU, or under
  256 MB to work with, it writes the simpler mode into `graphics.cfg`,
  marked as its own (`[brickworks] graphics/automatic=true`, which
  `GraphicsMode.chosen` reads as Automatic, and which it removes again on a
  GPU the full mode runs on), and says why in `BRICKWORKS_GRAPHICS`; then it
  becomes `Contents/MacOS/Brickworks` (exec, the same process, so Launch
  Services' open events still arrive). Never on the command line: Godot
  keeps the files a Mac opens a new app with only when it was started with
  no arguments (`godot_application_delegate.mm`, `get_cmd_argc() == 0`), and
  `--rendering-driver opengl3` made `open car.ldr` on the Intel VM open
  nothing. Not when the person chose (graphics.cfg names a rendering method,
  unmarked) or names a renderer on the command line. Godot's own
  fallback cannot catch MoltenVK's abort (`display_server_macos.mm` falls
  back only when `initialize()` returns an error). Windows and Linux fall
  back in Godot itself (Windows to Direct3D 12, on a basic display adapter
  the Microsoft Basic Render Driver; Linux with no Vulkan ICD: "switching to
  OpenGL 3"). On the Intel VM OpenGL is Apple's software renderer, minutes
  to a first picture, and FrameBudget cuts its whole ladder before the
  first frame there (`known_slow`, checked in `look_probe`). Either way
  the window says "This Mac's (This computer's) graphics run Brickworks in
  its simpler mode." once, above the model (`ShellPrefs`
  `said_simpler_graphics`), every start logs `graphics: <mode> mode (<why>),
  <driver> on <adapter>`, and path tracing and Good's bounced light say
  they need the full graphics mode. Settings, Graphics (on the keys' line):
  Automatic, Full or Simpler, written to `user://graphics.cfg`, which Godot
  reads at start (`application/config/project_settings_override`) and the
  launcher reads too, so it outlives an update. `graphics_mode_probe`
  (windowed; restarts itself with the launcher's graphics.cfg, no renderer
  named, as the launcher would) checks the
  line once in this start and the next, Got it, the words of Best and Good,
  and each choice's file and the renderer of the start after it. On a Mac:
  the runner proof below.
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
  the four types default to the app, `brickworks --about`), GNOME's
  thumbnail factory drawing each model through it in the real bwrap sandbox
  (`sysctl kernel.apparmor_restrict_unprivileged_userns=0`, bubblewrap and
  gir1.2-gnomedesktop-4.0, then `/usr/bin/python3
  tools/release/thumbnail_check.py --installed`; a failed check fails the
  run, and the pictures and `thumbnails.json` are kept as the
  `thumbnails-ubuntu-24.04` artifact), and `apt remove` leaving nothing,
  checked even when a picture failed. The Intel runner's only GPU is
  Apple's paravirtual one, which MoltenVK aborts on, so the app's launcher
  starts it in the simpler
  graphics mode; the Mac double-click checks each window's log says the
  mode `mac_mode` expects there (simpler on an Intel Mac whose GPUs are all
  paravirtual, full elsewhere) and that the simpler one was said once (see
  `graphics mode`). It builds nothing: the part library is not in
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
  failure lines. With no `--probes` its probes are every one
  `tools/suite/headless.txt` lists in the branch's tree, said with how many
  in the stage output and `TAG.train/probes.why`; `--probes "a b"` names
  exactly those; `--probes none --why "..."` runs none and the log and
  status say why; `--probes ""` is refused.
  tools/release/README.md has the
  rest. `tests/test_release_train.py` runs it with stand-ins for the hour's
  work.
  With `RELEASES_TOKEN` set it asks the releases repo's addresses through
  GitHub's API with the token instead (a release by tag, a file as its
  asset's bytes, followed to the signed URL, the token never sent past the
  API): the check that still means something once the repo is private (U8).
  Both ways 15 of 15 on 2026-10-29 (a gh token standing in).
- `download page`: `web/download.html`, served at `/download`
  (tools/site.py copies every file in `web/`; the old `/download.html` 308s
  to `/download`), and its copies at /de/download, /fr/download and
  /es/download. The desktop app is coming soon (the owner, 2026-11-07:
  "make the downloadable access 'Coming soon' ... since we can't properly
  support it yet"): the page says so in its heading, offers Open Brickworks
  (`#open-app`, into `/app`, `/app?lang=<code>` in a copy) as its one
  button, and has no installer, no file name, no button for a system, and
  no script (web/download.js is no longer loaded, and nothing reads
  /releases.json but the changelog's dates). A note tells whoever has the
  app already that it updates itself (Help › Check for updates…); the
  update feed, src/net/updates.gd, version.json and the releases repository
  are untouched. The header's Menu and the footer call it "Desktop app",
  and the 404 page's tile, the home page, Plans, the FAQ, Compare, the
  beta's page, the changelog (no Download or On GitHub on a release) and
  the docs (web-and-desktop, troubleshooting, index, plans, claude-code,
  connect) say coming soon and point at the app instead. Until 2026-11-07
  it offered each system its build from /releases.json (git log --
  web/download.html web/download.js).
- `download page check`: `tools/web/download_check.mjs` serves `web/` with a
  CSP at least as strict as the site's and loads the page as Linux, macOS,
  Windows and an Android phone through the DevTools protocol: each sees the
  heading "The desktop app is coming soon", one primary button, Open
  Brickworks to `/app`, no installer or releases link, no file name, no
  button for a system, nothing asked of /releases.json or GitHub, at most
  150 words, nothing past the edge at its width or 390, no console error;
  then every link on the page answers. And the gallery (below).

  ```sh
  node tools/web/download_check.mjs --shots=shots
  VERCEL_BYPASS=$VERCEL_BYPASS node tools/web/download_check.mjs --url=<deployment>/download
  ```
- `coming soon check`: `tools/web/coming_soon_check.mjs` puts the site
  together (tools/site.py) and serves it at the host's addresses (or takes
  `--url=` a deployment, its pages listed from this checkout's build), then
  every page, 151 on 2026-11-07 (79 English with the docs, 24 each in
  German, French and Spanish), and every script each loads and imports:
  as sent, no link, button or form to an installer (.deb, .dmg, .exe, .msi,
  .AppImage, a system's .zip or .tar.xz), the releases repository's
  releases or files, or /releases.json, no JSON-LD downloadUrl, and no
  script that names any of them; as drawn in a browser, the same of every
  link and button, and none saying Download (in any of the four languages)
  to /download or beside a system. Then /download in each language at 390
  and 1280: its heading the language's "The desktop app is coming soon",
  its one primary button the language's "Open Brickworks" to `/app` (with
  `?lang=`), no file name, no button for a system, nothing asked of GitHub,
  nothing past the edge, no console error. `--static` is the first pass
  alone (tests/test_coming_soon.py runs it, and a made-up site with each
  way of offering one, which it must fail); `--shots=DIR` writes /download
  and / at 390 and 1280, light and dark. `flows_for: every page` in it
  names it for a change to any page (tools/release/flows_for.py), and
  preview_checks.sh runs it as `coming_soon`.

  ```sh
  node tools/web/coming_soon_check.mjs --static
  node tools/web/coming_soon_check.mjs --shots=shots/coming-soon
  VERCEL_BYPASS=$VERCEL_BYPASS node tools/web/coming_soon_check.mjs --url=<deployment>
  ```

  Proves it when: `coming_soon: every page says the desktop app is coming
  soon, and none offers an installer`, exit 0. On pre261 (3f13e35f) it
  said 478 problems: the footer's Download on every page, the download
  page's GitHub links, the changelog's On GitHub, the home page's JSON-LD
  downloadUrl and web/download.js reaching for releases.json.
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
  SHA-256, makes it ready (the AppImage; the tar.xz and a Windows zip
  copy's zip unpacked; the DMG's app copied out; the Windows installer as
  it is; the .deb as it is, in the app's own data), and puts it in as the
  app quits (a .deb's copy waits for Update and restart, since apt asks for
  a password); Ask first says it is
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
  release-assets.githubusercontent.com and brickworks.diy, matched whole
  (`github.com.example.net`, `evilgithub.com` and `//host` redirects are
  refused). `tools/release.py publish --draft` signs it with both keys and uploads it
  with the packages, and refuses one that lacks a kind a copy updates from
  (`missing_update_kinds`: AppImage, tar.xz, .deb, DMG, installer);
  `tools/release.py latest --check FILE` reads one as the app would.
- `update notice`: "Brickworks 0.17.0 is out" (or "is ready") above the
  model, in UpdateOffer's look: What's new (the release notes' first
  paragraph), Update and restart, Later. Where the copy cannot write its
  install, the button reads Download and opens brickworks.diy/download; a
  copy installed from the .deb (in /usr/lib/brickworks) is never swapped:
  Update and restart runs `pkexec /usr/bin/apt-get install -y` on the
  checked .deb, and with no pkexec or the password refused says which and
  offers Show the file; a Mac app run from Downloads or a disk image reads
  Move to Applications and update.
- `check for updates reinstall and restart`: Help, Check for updates…
  ("You're up to date (0.16.0)" or what is new), Reinstall Brickworks…
  (this same version downloaded again, checked the same way) and Restart
  Brickworks, desktop only (src/ui/update_dialog.gd, Shell DESKTOP_ONLY).
  Every restart writes the working model first and comes back in the same
  session (`--session=`), on the same model.
- `update helper`: `src/net/update_helper.sh` (Linux, macOS) and `.ps1`
  (Windows), written to `user://updates/` and run as the app quits: waits
  for it to end, swaps the folder, .app or AppImage by renames (for a copy
  with `Uninstall Brickworks.exe` beside it, moves the folder aside and runs
  the new `setup.exe /VERYSILENT /D=<folder>`; for a .deb's copy, which apt
  has already updated, only restarts), asks the new copy `--about`, starts
  it and waits for it to say its window is up, and puts the old copy back
  (started with `--update-failed=`) when it cannot.
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
node tools/web/download_check.mjs --shots=shots   # the page says coming soon (2026-11-07)
python3 tools/release.py publish --draft --tag=v0.0.0-upload-test --target=main --no-manifest
gh workflow run release.yml -R Xaxis/brickworks-releases -f tag=v0.1.0
tools/release/releases_repo.sh --dir=<scratch>      # a dry run: about 5 GB downloaded
tools/release/release_links.sh                      # this checkout's web/releases.json
godot --headless --path . --thumbnail "$PWD/models/car.ldr" /tmp/car.png 256   # a model's picture
python3 tools/release/thumbnail_check.py dist/<version>/Brickworks-<version>-linux-amd64.deb --out=DIR --trace
tools/probe.sh thumbs_probe && PROBE_SIZE=1280x720 tools/probe.sh thumbs_probe
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
godot --headless --path . --thumbnail "$PWD/models/car.ldr" /tmp/car.png 256
```

Proves it when: it prints `thumbnail: car.png, 61 of 61 parts drawn, N ms`
and exits 0 in about a second, and /tmp/car.png is the car from its front
corner on a clear ground (0.75 s from start to exit, the editor binary,
2026-11-06). Without `--thumbnail` the app starts as before.

```sh
tools/probe.sh thumbs_probe && PROBE_SIZE=1280x720 tools/probe.sh thumbs_probe
```

Proves it when: it ends `thumbs: PASS`: the loop, flag and corner wired;
the catalogue read for geometry as JSON reads it; car.ldr, gatehouse.mpd,
gatehouse_2025.io and the car with 3 parts no library has each drawn by the
engine started as the thumbnailer starts it, in 3 s or less, 256 x 256, all
parts but the 3; each outline the app's own corner picture's (ModelShot) to
0.90 or more and nearer it than any other corner's. Look at
`<out>/*.png` beside `*_app_corner.png`. On pre261 it fails: no
BrickworksLoop, and the engine given `--thumbnail` starts the whole app and
is stopped after 30 s.

```sh
python3 tools/release/thumbnail_check.py dist/<version>/Brickworks-<version>-linux-amd64.deb --out=DIR --trace
```

Proves it when: it ends `thumbnails: PASS`. dpkg installs it into a root of
its own, and GNOME's own factory draws car.ldr, gatehouse.mpd,
gatehouse_2025.io and the car with unknown parts at 256 px in 3 s or less
each; a .lxf is not offered; a file of only unknown parts gets no picture;
nothing lands in the home; and, past the sandbox's view, only what the C
library and the engine look up past the view (input devices under /sys), which
refused too gives the same picture. On 2026-11-06 a .deb of 0435ace (0.18.0
plus this, 454 MB): 426, 453, 431 and 431 ms. Look at `DIR/*.png`. Here
bwrap is the stand-in (it says so): this box cannot make GNOME's sandbox.
The release workflow's Ubuntu run lifts that (`sudo sysctl -w
kernel.apparmor_restrict_unprivileged_userns=0`) and, with the .deb installed
by apt, runs `/usr/bin/python3 tools/release/thumbnail_check.py --installed
--out=thumbnail-check`, the real bwrap; read its `thumbnails-ubuntu-24.04`
artifact. setup-python's `python3` has no GObject bindings, and
`--installed` fails without them.

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

Proves it when: `32 passed`, in about 85 s, and 8 copies at once all pass
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
stopped release's worktree is refused, the fix kept. Named no probes, a
branch listing four headless probes (one added on the branch, one with
`:ARGS`, one after a comment) stages `probes: all 4 headless (1 windowed
left to the suite)` and runs those four; a windowed probe, one out.txt
keeps out, and names in headless.txt's comments never run; a branch with
no headless.txt is refused; a list named is kept as it is (`named at
staging`); `--probes none` without `--why`, and `--probes ""`, are refused,
and with one the log says `runs no probe: none: REASON` and status
`probes: none run, none: REASON`.
A dry stage on the real repository (train.sh with its `setsid` lines taken
out, RELEASE_OUT in scratch) of origin/main said `probes: all 209 headless
(103 windowed left to the suite)`, its spec the 209 in headless.txt's order
(2026-11-04). All 209 took 19m30s four at a time (22m12s with the six that
failed again alone), beside a battery of about two hours.
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
node tools/web/download_check.mjs --shots=shots
node tools/web/coming_soon_check.mjs --shots=shots/coming-soon
```

Proves it when (2026-11-07, the desktop app coming soon): linux, macos,
windows and phone each print `"The desktop app is coming soon" · "Open
Brickworks" /app` and under 150 words, every link answers, the gallery's
lines follow, and it ends `the download page says the desktop app is coming
soon, to every system`; the coming soon check ends `every page says the
desktop app is coming soon, and none offers an installer`, exit 0. Until
2026-11-07 it held each system to being offered its own build from a
manifest (`--manifest=`, no longer read).

```sh
tools/probe.sh updater_probe
python3 tools/minitest.py tests/test_updates.py
```

Proves it when: the probe prints 46 `ok` lines and ends `the desktop app
checks, refuses what it must, downloads, and hands over the restart with the
model kept` (among them: the two release keys each load under their own id;
Check for updates refuses a bad signature and `0.0.1, which is older`; in
Automatic a download is refused for a wrong SHA-256, a short size and
`refused an address off GitHub and brickworks.diy: https://example.com/...`;
`a redirect to any other host is refused, however like an allowed one it
looks` (14 lookalikes, `//host` and plain HTTP among them); a copy in
/usr/lib/brickworks is the .deb's, and in Automatic `a .deb's copy, in
Automatic, downloads the new .deb into its own data, checked`; `...Update
and restart asks apt to install it as root (/usr/bin/apt-get install -y
.../data/.brickworks-update/99.0.0/Brickworks-99.0.0-linux-amd64.deb);
refused: Couldn't install Brickworks 99.0.0: the password was refused or
not given, so nothing was installed`, Show the file shows that .deb, and
`...let, apt puts it in and the helper only starts the new copy, in the
same session: restart <pid>`;
Update and restart hands `/bin/sh helper.sh install <pid> <install> <staged>
... 99.0.0` with `--session=<id>`); and the tests print `14 passed`.
Before 2026-11-03 (0.15.0) Help had only `keys` and `tour` and no release
carried a latest.json.

```sh
python3 tools/update_check.py run --old OLD --new NEW --log=DIR/log.txt
```

Proves it when: every line is `ok` and it ends `<old> → <new>: every refusal
held, and it updates, restarts, reinstalls and puts back`, for the AppImage
and the tar.xz alike: `Off asks nothing: no request in 90 s, where
Automatic's same start asked /older/latest/download/latest.json N s in` (a
person's start, set to Off, then the same start in Automatic, both on one
feed), six refusals with their words, `Check for updates:
Brickworks B is out`, `Update and restart (by a redirect on the same host):
report: running B; model “House”, N parts; session S` with the same model,
parts and session as before the restart, the copy in place says B and
nothing is left in `.brickworks-update/`, Restart and Reinstall come back
the same, Automatic's next start says B, and a copy that cannot start is
put back and A started again (17 `ok`).

For the .deb pair (`Brickworks-A-linux-amd64.deb`) it proves it when it ends
`the .deb's copy downloads the new .deb, and apt installs it (refused and
missing here, then put in the dpkg way)`: the copy in `usr/lib/brickworks` says
A, Off asks nothing, the same six refusals, Check for updates says B is
out, `Update and restart with pkexec refused:
Couldn't install Brickworks B: the password was refused or not given, so
nothing was installed; it offers .../.brickworks-update/B/...deb` and the
same `with no pkexec` (`pkexec isn't on this system`), `...apt was asked for
the checked .deb, as root: /usr/bin/apt-get install -y ...`, `nothing dpkg
put there was changed`, the copy is still A, then `Update and restart, its
files renamed in as dpkg does while the old copy runs: report: running B;
model “House”, N parts; session S`, the copy says B and the downloaded .deb
is gone (17 `ok`). The stand-in renames each file in as dpkg does, under the
running copy: an updater that reads its package after apt fails it, as
0.16.0's first build did on Ubuntu (docs/UPDATES.md). Nothing is installed
on this machine; packages build HEAD, so commit app changes first
(`packages` refuses otherwise).

On macOS, Windows and Ubuntu the same, from a runner, with the DMG, the
installer, the zip and the .deb: `update_check.py lay --old OLD --new NEW
--port=8697 --out=DIR` here (the runner has no signing key), then `run
--laid=DIR --system` there (docs/UPDATES.md), which installs the first copy
from the DMG into /Applications, by `setup.exe /VERYSILENT` into
`%LOCALAPPDATA%\Programs\Brickworks`, or by `sudo apt-get install` into
/usr/lib, and takes them away after (a zip copy runs without `--system`).
It proves it when it ends the same way, the updater's log says `put B in
place at /Applications/Brickworks.app` (or `.../Programs/Brickworks`,
staged as `...-setup.exe`): the DMG 17 `ok`, the zip 17; the installer 21,
among them `Settings, Apps lists B`, `...with its Start menu entry and .ldr
opening in it`, `Uninstall leaves nothing of it: no file, no Settings, Apps
entry, no Start menu entry, no file type` and `...lists what it did before:
A-before` after the put back; the .deb 17, among them `Update and restart,
apt installing it by sudo in pkexec's place: report: running B; model
“House”, N parts`, `dpkg lists brickworks B`, and `apt remove leaves
nothing of it` (sudo stands in for pkexec, whose dialog a runner cannot
answer).
On Windows the log-judged steps start `Brickworks.exe`: the console wrapper
keeps its own file in use until the new copy ends.

At a release all of that runs as `tools/release/runner_check.sh VERSION LAID
OUT` (docs/RELEASING.md, step 5), with old copies from `update_check.py
packages` (a throwaway version: a Mac bundle's version is numbers only, so
0.15.99 for 0.16.0, never 0.16.0-pre, which the disk image reads as 1.0.0)
and the release's own packages as the new, taken from its draft. The same
run keeps a key in macOS's and Windows' real keychains (`keychain_check.py`)
and pictures an unsigned first launch on a Mac: `"Brickworks" Not Opened.
Apple could not verify "Brickworks" is free of malware that may harm your
Mac or compromise your privacy.` with Done and Move to Trash (macos-15).
windows-2022 has no SmartScreen: a marked installer opens straight to its
welcome page there, so what a Windows 10 or 11 person sees is not pictured.
It proves it when every job is green and `-- what is left --` reads 0 four
times.

## Gotchas

- **No thumbnailer at all draws on this box.** GNOME's factory runs each one
  in bubblewrap, and Ubuntu 24.04's
  `kernel.apparmor_restrict_unprivileged_userns=1` refuses bwrap its user
  namespace ("setting up uid map: Permission denied") for every
  thumbnailer, gdk-pixbuf's own too (this home's thumbnail cache holds
  nothing newer than 2026-09-29). A file manager with an AppArmor profile that
  allows user namespaces, or that setting at 0, draws them. Check the .deb
  with `thumbnail_check.py`, which says it used the stand-in.
- **An export template takes no `--script` and no scene on the command
  line** ("compiled without support for path overrides"): the only way past
  main.tscn is the main loop (`BrickworksLoop`), which runs before the main
  scene loads.

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
