# Downloading and installing Brickworks

How the desktop app gets onto a computer, held against the apps people
already trust, and what is left for the owner. The owner, 2026-11-03: "we
don't follow standard download and install patterns". They were right: until
0.16.0 a Mac got a zip of an .app and Windows a zip of an .exe.

How the packages are built and published is docs/RELEASING.md; this is what
a person meets.

## What the apps people trust ship

Read from each download page on 2026-11-03.

| | macOS | Windows | Linux | The page |
|---|---|---|---|---|
| **Blender** | .dmg (Apple silicon) | .msi installer, portable .zip, Microsoft Store | .tar.xz, Snap | a card per file with its size; SHA-256 files linked; no single button |
| **VS Code** | .dmg (universal, Intel, Apple silicon) | **User Installer** (per user, the default), System Installer, .zip | .deb, .rpm, .tar.gz, Snap | one button per system; no sizes or checksums |
| **Figma** | desktop app | per-user installer, and Windows on Arm | none | no sizes or checksums |
| **BrickLink Studio** | .pkg installer | .exe installer | none | |
| **LeoCAD** | .dmg, drag to Applications | .exe installer | AppImage | no sizes or checksums |
| **Obsidian** | universal .dmg | .exe installer | AppImage (x86_64, ARM64), .deb, Snap, Flatpak | one button for the system, the rest listed; no sizes or checksums |

The pattern: a disk image on a Mac, laid out to drag into Applications; an
installer on Windows, per-user where the app can be (VS Code, Figma,
Obsidian); on Linux an AppImage or a tarball, and a .deb for Debian and
Ubuntu. Every one of them opens its own documents by double-click.

## Where we stood, and what changed

### The download page
- **Had already:** the system detected and offered as one button, the other
  systems a click away, each file's size, and a command that checks its
  SHA-256. More than any of the six shows.
- **Gap, fixed:** only the offered file's checksum was there, and the other
  files of the same system (the .tar.xz) had no size. Now *All files and
  checksums* lists every file for the system with its link, size and
  check, and the Linux steps offer the .deb with its install command.
- **Gap, fixed:** nothing said how to uninstall. Each system's steps now do,
  and that a person's models and settings stay.

### macOS
- **Gap, fixed: a zip, not a disk image.** `Brickworks-X-macos-universal.dmg`
  holds the app and a link to /Applications, in a 640 x 400 window with a
  background whose arrow runs from one to the other (Retina and not), the
  icons at 128 points, no toolbar or sidebar, and the app's icon on the
  volume. Built on Linux the way Mozilla builds Firefox's: mkfs.hfsplus,
  libdmg-hfsplus, and a .DS_Store written in Python (tools/release.py
  write_dmg). Compressed with bzip2, not lzma, because an lzma image does not
  open before macOS 10.15 and the app runs from 10.13 on Intel.
- **Had already:** universal (Apple silicon and Intel in one app); the app
  signed ad hoc, or with a Developer ID and notarised when the keys are in
  `.env`.
- **Gap, fixed:** the disk image itself is signed and notarised whenever the
  app is (sign_dmg), as Apple asks of a downloaded image.
- **Gap, fixed: a Mac whose GPU cannot run Vulkan closed the app at once.**
  Apple's paravirtual GPU (any macOS VM on an Intel host; GitHub's
  macos-15-intel) aborts MoltenVK inside vkCreateInstance, which Godot's own
  fallback to OpenGL cannot catch. The app now starts through a small
  launcher (tools/release/package/launcher.c, the bundle's
  CFBundleExecutable) that asks Metal what the GPU is and, on one the full
  mode cannot run on, starts the app in its simpler mode (OpenGL), which says
  so once. Apple silicon draws through Metal and is left alone. Standard
  apps run on whatever GPU they find, in a lesser mode if need be; Settings,
  Graphics lets a person choose either, kept in the app's own folder across
  updates (src/render/graphics_mode.gd). The paravirtual GPU has no OpenGL
  of its own, so there it is Apple's software renderer, which compiles and
  runs every shader on the CPU: the first picture of the car takes minutes,
  and the frame budget cuts all it can before the first frame
  (FrameBudget.known_slow). ANGLE, which would draw OpenGL through Metal,
  cannot make a display on it ("Can't create an EGL display"). Windows on a
  basic display adapter (windows-2022, Hyper-V Video) already fell back in
  Godot itself, from Vulkan to Direct3D 12 on the Microsoft Basic Render
  Driver, and draws the car in the full mode; Linux without Vulkan falls
  back to OpenGL and now says so the same way.
- **Owner's:** the Developer ID, below.

### Windows
- **Gap, fixed: a zip, not an installer.** People had to extract it (it would
  not run from inside the zip), had no Start menu entry, nothing in Settings
  ▸ Apps, and no way to uninstall but deleting a folder.
  `Brickworks-X-windows-x86_64-setup.exe` (NSIS, made on Linux,
  tools/release/windows/brickworks.nsi) installs for the person running it,
  with no administrator, into `%LOCALAPPDATA%\Programs\Brickworks`; puts
  Brickworks in the Start menu, and on the desktop if they tick it; lists it
  in Settings ▸ Apps with its icon, version, size and publisher, whose
  Uninstall removes exactly what it installed and leaves the person's models
  and settings. In English, German, French or Spanish, as Windows is.
- **For the updater:** `setup.exe /VERYSILENT` (or `/S`) installs with no
  window over the version there, waits up to a minute for a running
  Brickworks to close (exit code 2 if it does not), and `/LAUNCH` starts it
  after. `"Uninstall Brickworks.exe" /S` removes it.
- **Gap, fixed:** the .exe's properties had no description or copyright, so
  Task Manager named it by its file name. The export preset now sets both.
- **Owner's:** a code-signing certificate, below.

### Linux
- **Gap, fixed: no .deb.** `Brickworks-X-linux-amd64.deb` installs the app
  in /usr/lib/brickworks with `brickworks` on the PATH, its menu entry,
  icons and model types, depending only on the C library. No maintainer
  scripts: dpkg's triggers update the menu, icons and MIME database.
  `sudo apt remove brickworks` takes it away.
- **Gap, fixed:** the AppImage's menu entry opened no files, named no types
  and had one icon. It now carries the same entry, MIME types and icons as
  the .deb, which AppImageLauncher, Gear Lever and appimaged install from
  inside it.
- **Had already, kept:** the tar.xz, for a system without FUSE.

### Opening a model by double-click
- **Gap, fixed, on every system.** Nothing opened .ldr, .mpd, .io or .lxf
  files, and the app ignored a file given to it. Now:
  - macOS: the app declares the four types (Info.plist), as the editor for
    LDraw's and an alternative viewer for Studio's and LDD's;
  - Windows: the installer registers a ProgID for each, and is the default
    only where no other app is (Studio keeps .io, LDD keeps .lxf);
  - Linux: the .deb and the AppImage register the MIME types LeoCAD uses for
    LDraw (`application/x-ldraw`, `application/x-multi-part-ldraw`) and two
    for Studio and LDD.
- **With the app already open,** the model opens in a window of its own, as
  a second tab of the app does, so nothing open is replaced.

### A model's picture in the file manager
- **Gap, fixed on Linux (.deb).** A folder of models showed the type's icon
  for each. The .deb now carries a GNOME thumbnailer entry
  (`/usr/share/thumbnailers/dev.brickworks.app.thumbnailer`) for .ldr, .mpd
  and .io, which Files reads, as do the file managers that read GNOME's
  entries (Nemo, Caja, Thunar through tumbler), and
  `/usr/bin/brickworks-thumbnailer`, which runs the app headless with
  `--thumbnail MODEL PICTURE SIZE` in a data folder of its own. The picture
  is the app's corner view, drawn on the CPU (a thumbnailer runs in a
  sandbox with no display or graphics card), on a clear ground; parts the
  library has not got are left out, and a file with none it knows keeps the
  icon. .lxf is not drawn: LDD's own files are better pictured by LDD.
- **Next:** Windows' thumbnail provider (an IThumbnailProvider the installer
  registers); the Mac's Quick Look extension is parked.

### The icon
- **Had already:** macOS's .icns at every size from 16 to 1024 (Godot makes
  it), and Windows's in the .exe.
- **Gap, fixed:** Linux had one 512 px picture. Now 16, 22, 24, 32, 48, 64,
  128, 256 and 512 px and an SVG, in the hicolor theme.

### First launch
Until the app is signed, each system asks once, and the page and each
README say how to answer: on a Mac **Open Anyway** in Privacy & Security; on
Windows **More info** then **Run anyway**, now once, for the installer (the
app it installs carries no download mark, so it opens without asking).

### Opening the desktop app from the web
Not offered, and not a gap: the web app is the same builder, and a model
moves to the desktop as a file. Offering it would take a `brickworks:` URL
scheme registered by each package, and something worth handing over.

### Not offered (named, not planned here)
Windows on Arm and Linux on ARM (Blender, VS Code and Obsidian have them),
.rpm, Snap and Flatpak. Each is one more package to build and prove on every
release.

## The zips, for one release

0.16.0 also carries the zips people had before, so links already shared keep
working, and its notes say so. The release after drops them from
`artifacts()` in tools/release.py and from the page's `PREFER` and
`data-kind="zip"` steps.

## What needs the owner

Nothing for either is in `.env` (none of `APPLE_SIGN_P12`,
`APPLE_SIGN_P12_PASSWORD`, `APPLE_NOTARY_KEY`, `APPLE_NOTARY_KEY_ID`,
`APPLE_NOTARY_ISSUER`, `WINDOWS_SIGN_COMMAND` is set, 2026-11-03).

- **An Apple Developer ID and an App Store Connect API key** (the Apple
  Developer Program, $99 a year): removes the Gatekeeper warning and the
  Open Anyway steps; the app and the disk image are then signed and
  notarised by the build with no other change (docs/RELEASING.md).
- **A Windows code-signing certificate**: Azure Artifact Signing (formerly
  Trusted Signing, $9.99 a month, identity checked by Microsoft), or an OV
  certificate on a token or a CA's cloud HSM (a few hundred dollars a year).
  Removes the SmartScreen warning once the certificate has reputation; an
  EV certificate no longer skips that wait. The installer, its uninstaller
  and both .exe files are then signed by the build.
