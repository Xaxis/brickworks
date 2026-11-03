# Updates: the desktop app keeps itself up to date

The owner (2026-11-03): "every installable app should have standard
update/auto update features that allow the user to easily update and
reinstall/restart the software." Before this, a person who downloaded 0.14.0
ran it until they visited /download again. The web app already reloads into
a new build (`src/ui/update_offer.gd`). This is the desktop's.

## What the best apps do

| App | Check | Install | Trust |
|---|---|---|---|
| VS Code | on start, then hourly; `update.mode` default, manual or none | downloads in the background, then **Restart to Update**; Windows' user setup swaps files after exit (inno_updater); macOS Squirrel swaps on quit | https, code signature on Windows and macOS |
| Figma, Obsidian | on start; Obsidian has a toggle and **Check for updates** in Settings | background download, **Relaunch** | Electron's updater: `latest.yml` with each file's SHA-512 and size |
| Sparkle (most Mac apps) | daily (`SUScheduledCheckInterval` 86400), and **Check for Updates…** in the app menu | **Install on Quit**, or now; a separate helper waits for the app to quit, checks the new bundle's code signature matches, swaps, relaunches; refuses to update a translocated app and offers to move it to Applications | an appcast, every archive signed with EdDSA |
| AppImageUpdate | when asked | replaces the AppImage in place, keeps the old one | GPG signature embedded in the AppImage |

Brickworks takes the common shape: a signed manifest, a daily check after
the window is up, a background download, install as the app quits or now,
a helper outside the app doing the swap, the old copy kept until the new
one starts.

## How it works here

- **The manifest.** Each release uploads `latest.json` (tools/release.py
  publish). It holds the manifest's JSON text exactly as signed (version,
  date, tag, release page, a short "What's new", and for every package its
  system, kind, URL, size and SHA-256), and its signatures: RSA 3072 over
  SHA-256, which Godot's Crypto verifies with no new dependency. The newest
  release's is at `releases/latest/download/latest.json` on
  Xaxis/brickworks-releases; each release's own stays at
  `releases/download/vX.Y.Z/latest.json`, which Reinstall reads.
- **Two keys.** The private halves are only in `.env` (`UPDATE_SIGN_KEY`,
  `UPDATE_SIGN_KEY_BACKUP`, base64 PEM); the public halves are in
  `src/net/updates.gd`. A release is signed by both, and the app takes
  either. If one is lost, a release signed by the other ships an app with a
  new second key.
- **What is refused, said plainly** (`Updates.read`, `Updater._fetch`): a
  signature that does not hold; a manifest that is not Brickworks'; a file
  whose size or SHA-256 is not the manifest's; a version not newer than this
  one (a replayed old manifest is a downgrade attack); plain HTTP; any
  address, a redirect included, off `github.com`,
  `objects.githubusercontent.com`, `release-assets.githubusercontent.com`
  (where GitHub sends release downloads since 2025) and `brickworks.diy`.
- **The check**: once a day, 8 s after the model is back, on HTTPRequest's
  own thread; hashing and unpacking on a thread of their own. Help ▸
  **Check for updates…** asks at once and says "You're up to date (0.x.y)"
  or what is new.
- **The notice**, above the model in the look of the web's "Brickworks has
  been updated": the version, **What's new** (the release notes' first
  paragraph), **Update and restart**, **Later**.
- **Settings ▸ Updates**, beside the version: **Automatic** (the default:
  downloads in the background, puts it in as the app quits, or now on
  Update and restart), **Ask first** (says it is out; downloads on the
  press), **Off** (nothing until Help asks). `BRICKWORKS_UPDATES=off` in the
  environment is Off whatever the setting: a package under test
  (`tools/release.py smoke`), or a machine an administrator updates. A copy
  run from source never asks by itself.
- **Restart** writes the working model first, as the web's Reload does, and
  the window comes back in the same session (`--session=`), so it opens the
  model as it was. Help ▸ **Restart Brickworks** does only that; Help ▸
  **Reinstall Brickworks…** downloads this same version, checked the same
  way, and puts it in place.
- **Never half installed.** The download is unpacked in
  `.brickworks-update/` beside the install, on the same disk, so the swap is
  a rename. A helper (`src/net/update_helper.sh`, `.ps1` on Windows) waits
  for the app to exit, moves the old copy aside, moves the new one in, asks
  it its version (`--about`), starts it, and waits for it to say its window
  is up. A copy that cannot say its version, or ends first, is taken away,
  the old one put back and started with `--update-failed=`, which the app
  says and never tries that version again. The new copy takes the old one
  away once it has started.

## Each system

| System | Package | What happens |
|---|---|---|
| Linux | AppImage | verified, then renamed over `$APPIMAGE` (the old one hard-linked aside first), relaunched |
| Linux | tar.xz | unpacked beside the folder with `tar`, the folders swapped after exit, relaunched |
| macOS | zip | unpacked with `ditto`; `codesign --verify --deep --strict`, and the same Developer ID team when this copy has one; the `.app` swapped after quit and opened with `open -n`. Run from Downloads or a disk image (translocated), the button reads **Move to Applications and update** and it goes to /Applications (or ~/Applications) |
| Windows | zip | unpacked with Windows' own `tar.exe`; the PowerShell helper waits for the exe to exit, swaps the folders (retrying while another window holds them), relaunches |

A copy that cannot write where it is installed (a tar.xz under /opt) says so,
and its button opens the download page.

**On Windows the helper first leaves the app's folder.** An exported Godot
app makes its own folder its working directory as it starts (`main.cpp`),
and `OS.create_process` starts the helper there. Windows will not move a
folder that is a process's working directory, so on the first runner proof
every install said `could not move` and 0.90.0 stayed (2026-11-03). Linux
and macOS rename it all the same.

**A Windows installer** (per-user, Start menu, Uninstall in Settings ▸ Apps,
as VS Code, Figma and Obsidian ship) is standard, and is the packaging
unit's. A copy it installs is a folder in `%LOCALAPPDATA%\Programs`, which
this updater swaps the same way.

## Testing it

`BRICKWORKS_UPDATE_URL`, set by hand, puts a test server in place of GitHub's
releases (plain HTTP only on this machine's own address). Every signature,
size and hash is still checked, so the test manifests are signed by the real
keys. `tools/update_check.py` builds two versions, serves them, and drives
`--update=check|fetch|install|reinstall|restart` through every refusal and
through a real install that restarts with the model kept. A macOS or
Windows runner has no signing key, so `update_check.py lay` signs every
scenario here and `run --laid=DIR` drives them there, at the same port; the
first proof ran them from a throwaway branch's workflow and a draft release,
both deleted after.
`src/dev/updater_probe.gd` checks the manifest, the versions and the
addresses, and drives the notice, the Help menu and the setting.
