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
  (where GitHub sends release downloads since 2025) and `brickworks.diy`,
  matched whole: `github.com.example.net`, `evilgithub.com`, `github.com.`
  and `github.com@example.net` are all refused, and so is a `//host/path`
  redirect to any of them.
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
- **Never half installed.** The download is made ready in
  `.brickworks-update/` beside the install, on the same disk, so the swap is
  a rename. A helper (`src/net/update_helper.sh`, `.ps1` on Windows) waits
  for the app to exit, moves the old copy aside, puts the new one in (on
  Windows by running the new installer into the folder the old one left), asks
  it its version (`--about`), starts it, and waits for it to say its window
  is up. A copy that cannot say its version, or ends first, is taken away,
  the old one put back and started with `--update-failed=`, which the app
  says and never tries that version again. The new copy takes the old one
  away once it has started. A `.deb`'s copy is the one exception: apt puts
  it in (below), and the helper only restarts.

## Each system

| System | Package | What happens |
|---|---|---|
| Linux | AppImage | verified, then renamed over `$APPIMAGE` (the old one hard-linked aside first), relaunched |
| Linux | tar.xz | unpacked beside the folder with `tar`, the folders swapped after exit, relaunched |
| Linux | .deb | never swapped: the new `.deb` is downloaded and checked into the app's own data (`user://.brickworks-update`), and **Update and restart** runs `pkexec /usr/bin/apt-get install -y <that file>`, which asks for the password in the system's own dialog, then restarts into it. With no pkexec, or the password refused (pkexec's 126 or 127), it says which, installs nothing, and offers **Show the file** for the system's software installer or `sudo apt install`. Never at quit in Automatic, since it asks for a password |
| macOS | DMG | attached read-only and unseen (`hdiutil attach -nobrowse -noautoopen`), `Brickworks.app` copied out with `ditto` as a drag to Applications copies it, detached; `codesign --verify --deep --strict`, and the same Developer ID team when this copy has one; the `.app` where it is installed (normally /Applications) swapped after quit and opened with `open -n`. Run from Downloads or the disk image itself (translocated), the button reads **Move to Applications and update** and it goes to /Applications (or ~/Applications) |
| Windows | installer | a copy with `Uninstall Brickworks.exe` beside it is the installer's: the NSIS `setup.exe` (tools/release/windows/brickworks.nsi) downloaded and checked; after the app exits the PowerShell helper moves the install folder aside, runs `setup.exe /VERYSILENT /D=<that folder>` (per person, no administrator), which writes Settings ▸ Apps, the Start menu and the file types again, needs exit 0, and relaunches; put back, it also puts back the version Settings ▸ Apps lists |
| Windows | zip | a copy unpacked from the zip keeps the folder swap, from the new zip; once a release has no zip, from the installer, into its own folder, and it is an installed copy from then on |

The zips stay for one release, for links already shared. A Mac copy
unpacked from one is updated from the DMG all the same, in its own place.
`release.py publish` refuses a `latest.json` that lacks a kind a copy
updates from (`missing_update_kinds`: the AppImage, the tar.xz, the .deb,
the DMG, the installer), since every copy installed from it would be
stranded.

A copy that cannot write where it is installed (a tar.xz under /opt) says so,
and its button opens the download page.

**Why apt puts the .deb in.** Its files are dpkg's (`/usr/lib/brickworks`,
linked from `/usr/bin`): written over by the app, `dpkg -L` and `apt remove`
would describe a version that is not there. So apt installs the new `.deb`,
as root, through pkexec: the system's own password dialog, never one the
app draws. `BRICKWORKS_UPDATE_ELEVATE` names a stand-in for pkexec, and is
read only beside `BRICKWORKS_UPDATE_URL`, so only a test can set it. A
`.deb` in an apt repository (Chrome's, VS Code's) would be updated by apt
with the rest of the system, the next step if the releases ever have one.

**On Windows the helper first leaves the app's folder.** An exported Godot
app makes its own folder its working directory as it starts (`main.cpp`),
and `OS.create_process` starts the helper there. Windows will not move a
folder that is a process's working directory, so on the first runner proof
every install said `could not move` and 0.90.0 stayed (2026-11-03). Linux
and macOS rename it all the same.

**On Windows the update is the installer, run into the same folder.** The
folder is moved aside first, so the installer finds no running Brickworks
to wait for and the old copy is whole until the new one has started. `/D=`
must come last and unquoted, as NSIS reads it, and it wins over the folder
the installer remembers (`HKCU\Software\Brickworks`), so a copy installed
anywhere is updated where it is. The installer's `/LAUNCH` is not used: the
helper first asks the new copy its version, then starts it in the same
session (`--session=`) so the model comes back, and can still put the old
one back if it never says its window is up.

## Testing it

`BRICKWORKS_UPDATE_URL`, set by hand, puts a test server in place of GitHub's
releases (plain HTTP only on this machine's own address). Every signature,
size and hash is still checked, so the test manifests are signed by the real
keys. `tools/update_check.py` builds two versions, serves them, and drives
`--update=check|fetch|install|reinstall|restart` through every refusal and
through a real install that restarts with the model kept. A macOS or
Windows runner has no signing key, so `update_check.py lay` signs every
scenario here and `run --laid=DIR` drives them there, at the same port; the
proofs run them from a throwaway branch's workflow and a draft release,
both deleted after, with the runs. `run --system` installs the first copy
where its installer puts it (/Applications, `%LOCALAPPDATA%\Programs`, or
`/usr/lib` by `sudo apt-get install`) on a runner's throwaway machine; there
an installer copy also proves its Start menu entry, its file types and that
its uninstaller leaves nothing. A `.deb` pair runs the .deb's own checks:
told what is out, the new `.deb` downloaded and checked, pkexec refused and
then missing each said with the file offered, nothing of dpkg's changed;
with `--system` apt installs it for real, sudo standing in for pkexec's
password dialog, and `apt remove` leaves nothing.
`src/dev/updater_probe.gd` checks the manifest, the versions and the
addresses, and drives the notice, the Help menu and the setting.
