#!/usr/bin/env python3
"""Cut, build, check and publish a desktop release of Brickworks.

    tools/release.py version                 do VERSION, project.godot and CHANGELOG.md agree?
    tools/release.py version --set 0.2.0     bump all three; [Unreleased] becomes 0.2.0's section
    tools/release.py notes [0.1.0]           that version's changelog section
    tools/release.py build [linux mac windows]   export and package into dist/<version>/
          --assets=DIR                       the mesh cache to ship (default assets/generated)
    tools/release.py inspect [DIR]           what is in each package: versions, architectures,
                                             signatures, contents. Reads the packages, not notes
    tools/release.py smoke FILE [--window]   unpack it as a person would and run it in a clean home
    tools/release.py publish --draft         upload the packages to a draft GitHub release and
                                             check GitHub's SHA-256 of each against dist/
    tools/release.py publish                 publish that draft (or create and publish), check
                                             it again, and write web/releases.json for the page
          [--tag=TAG] [--target=REF] [--no-manifest]
    tools/release.py manifest --local [--out=FILE]   the page's manifest from dist/, to preview it

docs/RELEASING.md is the cycle this is part of, and says when to run each.

The packages carry the whole part library (about a gigabyte of geometry),
because the desktop app works with no network and the web build cannot.
That library is not in git, so a release is built on a machine that has
it, and CI only proves what was built (.github/workflows/release.yml).

Signing plugs in by environment, from .env or the shell; values are never
printed. Without them the macOS app is ad-hoc signed and Windows unsigned,
and the download page says what that means for the first launch:

    APPLE_SIGN_P12, APPLE_SIGN_P12_PASSWORD       Developer ID Application certificate
    APPLE_NOTARY_KEY, APPLE_NOTARY_KEY_ID, APPLE_NOTARY_ISSUER
                                                  App Store Connect API key, to notarise
    WINDOWS_SIGN_COMMAND                          signs one file in place; {file} is its path
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import plistlib
import re
import shutil
import signal
import socket
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import zipfile
import zlib
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
REPO = "Xaxis/brickworks"
DIST = ROOT / "dist"
WORK = ROOT / "build" / "release"
STAGE = WORK / "stage"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "brickworks" / "downloads"
MANIFEST = ROOT / "web" / "releases.json"
SEMVER = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?$")
PLATFORMS = ("linux", "mac", "windows")

# The tools a package is made with, pinned by SHA-256 and fetched once into
# CACHE. appimagetool and its runtime are the versions Reelwright ships
# with; the runtime is passed in, so nothing is fetched while it runs.
TOOLS = {
    "appimagetool": {
        "url": "https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage",
        "sha256": "ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0",
    },
    "appimage-runtime": {
        "url": "https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64",
        "sha256": "2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d",
    },
    # Signs and notarises a macOS app from Linux. Only fetched when there
    # is a certificate to sign with, or to read a signature back.
    "rcodesign": {
        "url": "https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign/0.29.0/apple-codesign-0.29.0-x86_64-unknown-linux-musl.tar.gz",
        "sha256": "dbe85cedd8ee4217b64e9a0e4c2aef92ab8bcaaa41f20bde99781ff02e600002",
    },
}

SIGNING_NAMES = ("APPLE_SIGN_P12", "APPLE_SIGN_P12_PASSWORD", "APPLE_NOTARY_KEY",
                 "APPLE_NOTARY_KEY_ID", "APPLE_NOTARY_ISSUER", "WINDOWS_SIGN_COMMAND")


class Failed(Exception):
    """Something a release cannot go out with. The message says what."""


def say(text: str) -> None:
    print(text, flush=True)


def human(size: int) -> str:
    return "%.1f MB" % (size / 1e6) if size >= 1e6 else "%.0f KB" % (size / 1e3)


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True,
                          text=True).stdout.strip()


def godot() -> str:
    return os.environ.get("GODOT", "godot")


def gh_env() -> dict[str, str]:
    # An invalid GITHUB_TOKEN in this machine's environment shadows gh's
    # own keyring login. CI passes GH_TOKEN, which this keeps.
    env = dict(os.environ)
    env.pop("GITHUB_TOKEN", None)
    return env


def load_signing_env() -> None:
    """The signing names from .env, when the shell has not set them.

    Only those names: the rest of .env is keys for other things, and a
    release has no business reading them.
    """
    path = ROOT / ".env"
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        name, _, value = line.partition("=")
        name = name.strip().removeprefix("export ").strip()
        if name in SIGNING_NAMES and name not in os.environ:
            os.environ[name] = value.strip().strip('"').strip("'")


def under_heavy(argv: list[str]) -> None:
    """Re-run in the machine's queue for heavy jobs, where it has one."""
    heavy = Path.home() / ".claude" / "claude-core" / "bin" / "heavy"
    if os.environ.get("BOX_HEAVY_HELD") or not os.access(heavy, os.X_OK):
        return
    os.execv(str(heavy), [str(heavy), sys.executable, str(Path(__file__).resolve()), *argv])


# -- the version ------------------------------------------------------------

def version_file() -> str:
    return (ROOT / "VERSION").read_text().strip()


def project_version(text: str | None = None) -> str:
    text = text if text is not None else (ROOT / "project.godot").read_text()
    found = re.search(r'^config/version="([^"]*)"', text, re.M)
    return found.group(1) if found else ""


def changelog_sections(text: str | None = None) -> list[tuple[str, str, str]]:
    """(version, date, body) for each section, newest first."""
    text = text if text is not None else (ROOT / "CHANGELOG.md").read_text()
    heads = list(re.finditer(r"^## \[([^\]]+)\](?: - (\d{4}-\d{2}-\d{2}))?[ \t]*$", text, re.M))
    sections = []
    for at, head in enumerate(heads):
        end = heads[at + 1].start() if at + 1 < len(heads) else len(text)
        sections.append((head.group(1), head.group(2) or "", text[head.end():end].strip()))
    return sections


def section(version: str) -> tuple[str, str]:
    for name, date, body in changelog_sections():
        if name == version:
            return date, body
    raise Failed("CHANGELOG.md has no section for %s" % version)


def check_version() -> list[str]:
    problems = []
    version = version_file()
    if not SEMVER.match(version):
        problems.append("VERSION says %r, which is not X.Y.Z" % version)
    godot_says = project_version()
    if godot_says != version:
        problems.append("project.godot config/version is %r, VERSION is %r" % (godot_says, version))
    names = [name for name, _, _ in changelog_sections()]
    if version not in names:
        problems.append("CHANGELOG.md has no ## [%s] section" % version)
    else:
        date, body = section(version)
        if not date:
            problems.append("CHANGELOG.md's [%s] has no date" % version)
        if not body:
            problems.append("CHANGELOG.md's [%s] says nothing" % version)
    repeated = sorted({name for name in names if names.count(name) > 1})
    if repeated:
        problems.append("CHANGELOG.md repeats %s" % ", ".join(repeated))
    return problems


def set_version(new: str, today: str) -> None:
    if not SEMVER.match(new):
        raise Failed("%r is not X.Y.Z" % new)
    log = (ROOT / "CHANGELOG.md").read_text()
    if any(name == new for name, _, _ in changelog_sections(log)):
        raise Failed("CHANGELOG.md already has a section for %s" % new)
    head = re.search(r"^## \[Unreleased\][ \t]*$", log, re.M)
    if head is None:
        raise Failed("CHANGELOG.md has no ## [Unreleased] heading to move")
    # What was under Unreleased is now under the release, and Unreleased
    # starts empty again.
    log = log[:head.end()] + "\n\n## [%s] - %s" % (new, today) + log[head.end():]
    project = (ROOT / "project.godot").read_text()
    if not project_version(project):
        raise Failed("project.godot has no config/version line")
    project = re.sub(r'^config/version="[^"]*"', 'config/version="%s"' % new, project,
                     count=1, flags=re.M)
    (ROOT / "CHANGELOG.md").write_text(log)
    (ROOT / "project.godot").write_text(project)
    (ROOT / "VERSION").write_text(new + "\n")
    _, body = section(new)
    say("version %s, dated %s, in VERSION, project.godot and CHANGELOG.md" % (new, today))
    if not body:
        say("  its changelog section is empty: say what changed before building it")


# -- names ------------------------------------------------------------------

def artifacts(version: str) -> dict[str, list[str]]:
    base = "Brickworks-%s" % version
    return {
        "linux": [base + "-linux-x86_64.AppImage", base + "-linux-x86_64.tar.xz"],
        "mac": [base + "-macos-universal.zip"],
        "windows": [base + "-windows-x86_64.zip"],
    }


def describe_file(name: str) -> dict[str, str]:
    """Which system and what kind of package a file name is."""
    if "-linux-" in name:
        kind = "AppImage" if name.endswith(".AppImage") else "tar.xz"
        return {"os": "linux", "arch": "x86_64", "kind": kind}
    if "-macos-" in name:
        return {"os": "macos", "arch": "universal", "kind": "zip"}
    if "-windows-" in name:
        return {"os": "windows", "arch": "x86_64", "kind": "zip"}
    return {"os": "", "arch": "", "kind": ""}


# -- staging ----------------------------------------------------------------

def link_or_copy(source: Path, target: Path) -> None:
    # A hard link where the two are on one disk: a gigabyte of geometry
    # costs nothing to stage, and the export only reads it.
    try:
        os.link(source, target)
    except OSError:
        shutil.copy2(source, target)


def stage(assets: Path, version: str, date: str) -> dict[str, str]:
    """A copy of the project as committed, with the mesh cache it ships.

    From git rather than the working tree, so a release is exactly a
    commit and says which; and only the meshes the catalogue names, so
    geometry left behind by an older build does not ship. The full cache
    held 3,924 such files, 234 MB of them.
    """
    catalogue_path = assets / "catalogue.json"
    if not catalogue_path.exists():
        raise Failed("no catalogue at %s: build the meshes (tools/build_meshes.py) or "
                     "pass --assets=DIR" % catalogue_path)
    try:
        catalogue = json.loads(catalogue_path.read_text())
    except json.JSONDecodeError as error:
        # A mesh build in progress rewrites it from scratch.
        raise Failed("%s does not parse (%s): is a mesh build running?" % (catalogue_path, error))
    meshes = sorted({part["mesh"] for part in catalogue.get("parts", []) if part.get("mesh")})
    missing = [mesh for mesh in meshes if not (assets / "parts" / (mesh + ".lbm")).exists()]
    if missing:
        raise Failed("%d meshes the catalogue names are not in %s/parts, %s first"
                     % (len(missing), assets, missing[0]))

    commit = git("rev-parse", "--short=7", "HEAD")
    shipped = git("status", "--porcelain", "--untracked-files=no", "--", "src", "models",
                  "project.godot", "export_presets.cfg", "assets")
    if shipped:
        say("  building %s as committed; uncommitted changes to these are not in it:" % commit)
        for line in shipped.splitlines()[:8]:
            say("    " + line)

    shutil.rmtree(STAGE, ignore_errors=True)
    STAGE.mkdir(parents=True)
    archive = subprocess.Popen(["git", "archive", "--format=tar", "HEAD"], cwd=ROOT,
                               stdout=subprocess.PIPE)
    subprocess.run(["tar", "-x", "-C", str(STAGE)], stdin=archive.stdout, check=True)
    if archive.wait() != 0:
        raise Failed("git archive failed")
    if project_version((STAGE / "project.godot").read_text()) != version:
        raise Failed("the commit's project.godot does not say %s: commit the version first"
                     % version)

    generated = STAGE / "assets" / "generated"
    (generated / "parts").mkdir(parents=True)
    for table in sorted(assets.glob("*.json")):
        # Copied, not linked: refresh_catalogue.py rewrites these in place.
        shutil.copy2(table, generated / table.name)
    for mesh in meshes:
        name = mesh + ".lbm"
        link_or_copy(assets / "parts" / name, generated / "parts" / name)
    stamp = {"version": version, "commit": commit, "date": date}
    (STAGE / "release.json").write_text(json.dumps(stamp) + "\n")
    say("  staged %s: %d parts' meshes, %s" % (commit, len(meshes), human(
        sum((generated / "parts" / (m + ".lbm")).stat().st_size for m in meshes))))

    log = WORK / "import.log"
    with log.open("w") as out:
        subprocess.run([godot(), "--headless", "--path", str(STAGE), "--import"],
                       stdout=out, stderr=subprocess.STDOUT)
    return stamp


def export(preset: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    log = WORK / ("export-%s.log" % preset.split()[0].lower())
    started = time.time()
    with log.open("w") as out:
        code = subprocess.run([godot(), "--headless", "--path", str(STAGE), "--export-release",
                               preset, str(target)], stdout=out, stderr=subprocess.STDOUT).returncode
    text = log.read_text(errors="replace")
    if code != 0 or not target.exists() or re.search(r"SCRIPT ERROR|Parse Error|Compile Error", text):
        tail = [line for line in text.splitlines() if re.search(r"error|cannot|failed", line, re.I)]
        raise Failed("export %s failed (exit %d), see %s:\n  %s"
                     % (preset, code, log, "\n  ".join(tail[:12])))
    say("  exported %s in %.0f s" % (preset, time.time() - started))


def notices(target: Path) -> None:
    # A build tool, like this file, so it runs as it is here rather than
    # as committed; tools/ is never exported.
    (STAGE / "tools").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "tools" / "release_notices.gd", STAGE / "tools" / "release_notices.gd")
    code = subprocess.run([godot(), "--headless", "--path", str(STAGE), "--script",
                           "res://tools/release_notices.gd", "--", str(target)],
                          capture_output=True, text=True).returncode
    if code != 0 or not target.exists():
        raise Failed("could not write the engine's notices")


def readme(platform: str, version: str, date: str, signed: dict[str, bool]) -> str:
    """The README.txt each package carries: what it is and how to start it."""
    lines = ["Brickworks %s, released %s" % (version, date), "",
             "A dimensionally exact brick construction system: every part in the",
             "LDraw library at true size, building by hand or with Claude, and",
             "instructions and a parts list at the end. The whole part library is",
             "inside this package, so building needs no network.", "",
             "https://brickworks.diy        the site, and this app in a browser",
             "https://brickworks.diy/download.html   checksums and every download", ""]
    if platform == "linux":
        lines += ["To start it:", "",
                  "  ./brickworks.x86_64", "",
                  "Or, from the AppImage: chmod +x the file and run it. AppImages mount",
                  "themselves with FUSE; without it, run it with --appimage-extract-and-run.", ""]
        where = "~/.local/share/godot/app_userdata/Brickworks/"
    elif platform == "mac":
        lines += ["To start it: move Brickworks.app to Applications and open it.", ""]
        if not signed.get("notarized"):
            lines += ["This build is not yet notarised by Apple, so the first time macOS",
                      "will not open it. Open it once, choose Done, then open System",
                      "Settings > Privacy & Security and choose Open Anyway beside",
                      "Brickworks. After that it opens like any other app.", "",
                      "If macOS says it is damaged, that is the download's quarantine flag",
                      "on an app Apple has not notarised. Check the download's SHA-256",
                      "against the site, then in Terminal:", "",
                      "  xattr -dr com.apple.quarantine /Applications/Brickworks.app", ""]
        where = "~/Library/Application Support/Godot/app_userdata/Brickworks/"
    else:
        lines += ["To start it: extract the whole folder first, then run Brickworks.exe.",
                  "Brickworks.pck must stay beside it. Brickworks.console.exe is the",
                  "same app with a console window, for reading what it says.", ""]
        if not signed.get("windows"):
            lines += ["This build is not yet signed, so Windows SmartScreen may say",
                      "\"Windows protected your PC\". Check the download's SHA-256 against",
                      "the site, then choose More info and Run anyway.", ""]
        where = "%APPDATA%\\Godot\\app_userdata\\Brickworks\\"
    lines += ["Your models and settings are kept in %s" % where, "",
              "From a terminal, --about says which build this is:", "",
              "  %s --headless -- --about" % {
                  "linux": "./brickworks.x86_64",
                  "mac": "Brickworks.app/Contents/MacOS/Brickworks",
                  "windows": "Brickworks.console.exe"}[platform], "",
              "LEGO(R) is a trademark of the LEGO Group of companies which does not",
              "sponsor, authorize or endorse this software. Part geometry is derived",
              "from the LDraw(TM) Parts Library; see ATTRIBUTION.md.", ""]
    return "\n".join(lines)


def extras(folder: Path, platform: str, version: str, date: str, signed: dict[str, bool]) -> None:
    """The text every package carries beside the app."""
    (folder / "README.txt").write_text(readme(platform, version, date, signed))
    shutil.copy2(STAGE / "docs" / "ATTRIBUTION.md", folder / "ATTRIBUTION.md")
    shutil.copy2(WORK / "THIRD-PARTY-NOTICES.txt", folder / "THIRD-PARTY-NOTICES.txt")


# -- archives ---------------------------------------------------------------

def write_zip(source: Path, target: Path, epoch: int) -> None:
    """source/ as one folder in a zip, keeping modes and links.

    Python's zipfile rather than a zip command, so it is the same on
    every system and the date inside is the commit's, not today's.
    """
    stamp = time.gmtime(max(epoch, 315532800))[:6]
    target.unlink(missing_ok=True)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted([source, *source.rglob("*")]):
            name = path.relative_to(source.parent).as_posix()
            info = os.lstat(path)
            entry = zipfile.ZipInfo(name + ("/" if stat.S_ISDIR(info.st_mode) else ""), stamp)
            entry.create_system = 3
            entry.external_attr = (info.st_mode & 0xFFFF) << 16
            if stat.S_ISLNK(info.st_mode):
                archive.writestr(entry, os.readlink(path), zipfile.ZIP_STORED)
            elif stat.S_ISDIR(info.st_mode):
                archive.writestr(entry, b"", zipfile.ZIP_STORED)
            else:
                entry.compress_type = zipfile.ZIP_DEFLATED
                with path.open("rb") as handle, archive.open(entry, "w", force_zip64=True) as out:
                    shutil.copyfileobj(handle, out, 1 << 20)


def write_tar_xz(source: Path, target: Path, epoch: int) -> None:
    target.unlink(missing_ok=True)
    env = dict(os.environ, XZ_OPT="-T0 -6")
    subprocess.run(["tar", "--sort=name", "--owner=0", "--group=0", "--numeric-owner",
                    "--mtime=@%d" % epoch, "-cJf", str(target), "-C", str(source.parent),
                    source.name], check=True, env=env)


def fetch(tool: str) -> Path:
    """A pinned tool, downloaded once and checked every time."""
    pin = TOOLS[tool]
    name = pin["url"].rsplit("/", 1)[1]
    path = CACHE / ("%s-%s" % (pin["sha256"][:16], name))
    if not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        say("  fetching %s" % name)
        request = urllib.request.Request(pin["url"], headers={"User-Agent": "brickworks-release"})
        partial = path.with_suffix(".part")
        with urllib.request.urlopen(request, timeout=120) as response, partial.open("wb") as out:
            shutil.copyfileobj(response, out)
        partial.rename(path)
    if sha256_of(path) != pin["sha256"]:
        path.unlink()
        raise Failed("%s did not match its pinned SHA-256; removed it" % name)
    path.chmod(0o755)
    if tool == "rcodesign":
        unpacked = CACHE / ("%s-rcodesign" % pin["sha256"][:16])
        if not unpacked.exists():
            with tarfile.open(path) as archive:
                member = next(m for m in archive.getmembers() if m.name.endswith("/rcodesign"))
                handle = archive.extractfile(member)
                if handle is None:
                    raise Failed("the rcodesign archive has no program in it")
                with handle, unpacked.open("wb") as out:
                    shutil.copyfileobj(handle, out)
            unpacked.chmod(0o755)
        return unpacked
    return path


# -- each platform ----------------------------------------------------------

def build_linux(version: str, stamp: dict[str, str], out: Path, epoch: int) -> None:
    folder_name = "Brickworks-%s-linux-x86_64" % version
    work = WORK / "linux"
    shutil.rmtree(work, ignore_errors=True)
    folder = work / folder_name
    export("Linux", folder / "brickworks.x86_64")
    (folder / "brickworks.x86_64").chmod(0o755)
    shutil.copy2(STAGE / "web" / "favicon-512.png", folder / "brickworks.png")
    (folder / "brickworks.desktop").write_text(desktop_entry())
    extras(folder, "linux", version, stamp["date"], {})
    tarball = out / (folder_name + ".tar.xz")
    write_tar_xz(folder, tarball, epoch)
    say("  %s, %s" % (tarball.name, human(tarball.stat().st_size)))

    # The AppImage: the same files, laid out the way appimagetool wants.
    appdir = work / "Brickworks.AppDir"
    (appdir / "usr" / "bin").mkdir(parents=True)
    (appdir / "usr" / "share" / "doc" / "brickworks").mkdir(parents=True)
    for name in ("brickworks.x86_64", "brickworks.pck"):
        os.link(folder / name, appdir / "usr" / "bin" / name)
    for name in ("README.txt", "ATTRIBUTION.md", "THIRD-PARTY-NOTICES.txt"):
        shutil.copy2(folder / name, appdir / "usr" / "share" / "doc" / "brickworks" / name)
    shutil.copy2(folder / "brickworks.png", appdir / "brickworks.png")
    (appdir / ".DirIcon").symlink_to("brickworks.png")
    shutil.copy2(folder / "brickworks.desktop", appdir / "brickworks.desktop")
    run = appdir / "AppRun"
    run.write_text('#!/bin/sh\n# Brickworks, from inside its AppImage.\n'
                   'here="$(dirname "$(readlink -f "$0")")"\n'
                   'exec "$here/usr/bin/brickworks.x86_64" "$@"\n')
    run.chmod(0o755)
    image = out / (folder_name + ".AppImage")
    image.unlink(missing_ok=True)
    env = dict(os.environ, ARCH="x86_64", APPIMAGE_EXTRACT_AND_RUN="1",
               SOURCE_DATE_EPOCH=str(epoch))
    log = WORK / "appimagetool.log"
    # zstd at 19 in 1 MB blocks: 382 MB, against 420 MB at appimagetool's
    # defaults (128 KB blocks), measured on 0.1.0. Squashfs compresses each
    # block alone, so a bigger block finds more of the repetition across
    # meshes. xz would make 291 MB, but appimagetool's mksquashfs and the
    # runtime that mounts the image only know zstd.
    with log.open("w") as handle:
        code = subprocess.run([str(fetch("appimagetool")), "--no-appstream", "--runtime-file",
                               str(fetch("appimage-runtime")), "--comp", "zstd",
                               "--mksquashfs-opt", "-Xcompression-level",
                               "--mksquashfs-opt", "19", "--mksquashfs-opt", "-b",
                               "--mksquashfs-opt", "1M", str(appdir), str(image)],
                              env=env, stdout=handle, stderr=subprocess.STDOUT).returncode
    if code != 0 or not image.exists():
        raise Failed("appimagetool failed, see %s" % log)
    image.chmod(0o755)
    say("  %s, %s" % (image.name, human(image.stat().st_size)))


def desktop_entry() -> str:
    return ("[Desktop Entry]\nType=Application\nName=Brickworks\n"
            "Comment=A dimensionally exact brick construction system\n"
            "Exec=brickworks\nIcon=brickworks\nTerminal=false\n"
            "Categories=Graphics;3DGraphics;\n")


def sign_mac(app: Path) -> dict[str, bool]:
    """Signed by rcodesign: ad hoc, or with a Developer ID and notarised.

    An Apple silicon Mac runs nothing unsigned, so even without a
    certificate the app is signed ad hoc. Not by Godot, which signs the
    export itself: Godot 4.7.2 writes its entitlements in a DER form that
    is not Apple's and lists its code directory twice, and macOS 12 and
    later check both at launch (code_signature() says what was found).
    rcodesign writes what Apple's codesign writes, and reads it back.

    With a Developer ID it signs with the hardened runtime for
    notarisation, and with an App Store Connect key it notarises and
    staples, so the app opens on a double-click. All of it from Linux.
    """
    p12 = os.environ.get("APPLE_SIGN_P12", "")
    if p12 and not Path(p12).exists():
        raise Failed("APPLE_SIGN_P12 names a file that does not exist")
    rcodesign = fetch("rcodesign")
    with tempfile.TemporaryDirectory() as private:
        entitlements = Path(private) / "entitlements.plist"
        # The preset's one entitlement, kept: under the hardened runtime a
        # library signed by someone else will not load without it.
        entitlements.write_bytes(plistlib.dumps(
            {"com.apple.security.cs.disable-library-validation": True}))
        if not p12:
            subprocess.run([str(rcodesign), "sign", "--code-signature-flags", "runtime",
                            "--entitlements-xml-file", str(entitlements), str(app)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            say("  macOS: ad-hoc signed (no APPLE_SIGN_P12): first launch needs Open Anyway")
            return {"developer_id": False, "notarized": False}
        password = Path(private) / "p12-password"
        password.write_text(os.environ.get("APPLE_SIGN_P12_PASSWORD", ""))
        # --for-notarization turns on the hardened runtime and a secure
        # timestamp, and checks for what Apple's notary would refuse.
        subprocess.run([str(rcodesign), "sign", "--p12-file", p12, "--p12-password-file",
                        str(password), "--for-notarization", "--code-signature-flags", "runtime",
                        "--entitlements-xml-file", str(entitlements), str(app)], check=True)
        say("  macOS: signed with the Developer ID")
        names = ("APPLE_NOTARY_KEY", "APPLE_NOTARY_KEY_ID", "APPLE_NOTARY_ISSUER")
        if not all(os.environ.get(name) for name in names):
            say("  macOS: not notarised (set %s): Gatekeeper will still ask" % ", ".join(names))
            return {"developer_id": True, "notarized": False}
        key = Path(private) / "notary-key.json"
        subprocess.run([str(rcodesign), "encode-app-store-connect-api-key", "--output-path", str(key),
                        os.environ["APPLE_NOTARY_ISSUER"], os.environ["APPLE_NOTARY_KEY_ID"],
                        os.environ["APPLE_NOTARY_KEY"]], check=True)
        # --staple waits for Apple's answer and attaches the ticket, so the
        # app opens offline the first time too.
        subprocess.run([str(rcodesign), "notary-submit", "--api-key-file", str(key),
                        "--staple", str(app)], check=True)
        say("  macOS: notarised and stapled")
        return {"developer_id": True, "notarized": True}


def build_mac(version: str, stamp: dict[str, str], out: Path, epoch: int) -> dict[str, bool]:
    folder_name = "Brickworks-%s-macos" % version
    work = WORK / "mac"
    shutil.rmtree(work, ignore_errors=True)
    folder = work / folder_name
    export("macOS", folder / "Brickworks.app")
    signed = sign_mac(folder / "Brickworks.app")
    extras(folder, "mac", version, stamp["date"], signed)
    package = out / ("Brickworks-%s-macos-universal.zip" % version)
    write_zip(folder, package, epoch)
    say("  %s, %s" % (package.name, human(package.stat().st_size)))
    return signed


def build_windows(version: str, stamp: dict[str, str], out: Path, epoch: int) -> bool:
    folder_name = "Brickworks-%s-windows-x86_64" % version
    work = WORK / "windows"
    shutil.rmtree(work, ignore_errors=True)
    folder = work / folder_name
    export("Windows", folder / "Brickworks.exe")
    command = os.environ.get("WINDOWS_SIGN_COMMAND", "")
    signed = False
    if command:
        for exe in sorted(folder.glob("*.exe")):
            # The command is the owner's own, from their .env: it is run as
            # written, with the file's path put in for {file}.
            subprocess.run(command.replace("{file}", '"%s"' % exe), shell=True, check=True)
            if not pe_facts(exe.read_bytes())["signed"]:
                raise Failed("WINDOWS_SIGN_COMMAND ran but %s carries no signature" % exe.name)
        signed = True
        say("  Windows: signed")
    else:
        say("  Windows: unsigned (no WINDOWS_SIGN_COMMAND): SmartScreen will ask once")
    extras(folder, "windows", version, stamp["date"], {"windows": signed})
    package = out / (folder_name + ".zip")
    write_zip(folder, package, epoch)
    say("  %s, %s" % (package.name, human(package.stat().st_size)))
    return signed


def write_sums(out: Path) -> None:
    names = sorted(path.name for path in out.iterdir()
                   if path.name.startswith("Brickworks-") and path.is_file())
    (out / "SHA256SUMS").write_text("".join("%s  %s\n" % (sha256_of(out / name), name)
                                            for name in names))


def build(platforms: list[str], assets: Path) -> int:
    problems = check_version()
    if problems:
        raise Failed("the version does not agree with itself:\n  " + "\n  ".join(problems))
    version = version_file()
    date, _ = section(version)
    load_signing_env()
    out = DIST / version
    out.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    (ROOT / "build" / ".gdignore").touch()
    lock = WORK / ".lock"
    try:
        lock.mkdir()
    except FileExistsError:
        raise Failed("another release build is running in this copy (%s)" % lock)
    try:
        started = time.time()
        say("── staging %s ──" % version)
        stamp = stage(assets, version, date)
        notices(WORK / "THIRD-PARTY-NOTICES.txt")
        epoch = int(git("show", "-s", "--format=%ct", "HEAD"))
        for platform in platforms:
            say("── %s ──" % platform)
            if platform == "linux":
                build_linux(version, stamp, out, epoch)
            elif platform == "mac":
                build_mac(version, stamp, out, epoch)
            else:
                build_windows(version, stamp, out, epoch)
        write_sums(out)
        say("── what was built, read back from the packages ──")
        facts = inspect(out)
        (out / "build.json").write_text(json.dumps({
            "version": version, "date": date, "commit": stamp["commit"], "files": facts},
            indent=1) + "\n")
        say("built %s in %.0f s: %s" % (version, time.time() - started, out))
        return 0
    finally:
        lock.rmdir()
        shutil.rmtree(STAGE, ignore_errors=True)


# -- reading packages back --------------------------------------------------

CPU = {0x01000007: "x86_64", 0x0100000C: "arm64"}


def macho_slices(data: bytes) -> list[tuple[str, bytes]]:
    magic = struct.unpack(">I", data[:4])[0]
    if magic in (0xCAFEBABE, 0xCAFEBABF):
        count = struct.unpack(">I", data[4:8])[0]
        slices = []
        for at in range(count):
            if magic == 0xCAFEBABE:
                cpu, _, offset, size, _ = struct.unpack(">iiIII", data[8 + at * 20:28 + at * 20])
            else:
                cpu, _, offset, size, _, _ = struct.unpack(">iiQQII", data[8 + at * 32:40 + at * 32])
            slices.append((CPU.get(cpu & 0xFFFFFFFF, hex(cpu)), data[offset:offset + size]))
        return slices
    if magic == 0xCFFAEDFE:
        cpu = struct.unpack("<i", data[4:8])[0]
        return [(CPU.get(cpu & 0xFFFFFFFF, hex(cpu)), data)]
    raise Failed("not a Mach-O binary")


def macho_facts(binary: bytes) -> dict[str, Any]:
    """Architectures, the oldest macOS each will run on, and how it is signed."""
    facts: dict[str, Any] = {"architectures": [], "min_macos": {}, "signature": {}}
    for arch, data in macho_slices(binary):
        facts["architectures"].append(arch)
        ncmds = struct.unpack("<I", data[16:20])[0]
        at = 32
        signature = "none"
        for _ in range(ncmds):
            cmd, size = struct.unpack("<II", data[at:at + 8])
            if cmd == 0x32:  # LC_BUILD_VERSION
                minos = struct.unpack("<I", data[at + 12:at + 16])[0]
                facts["min_macos"][arch] = "%d.%d" % (minos >> 16, (minos >> 8) & 0xFF)
            elif cmd == 0x24:  # LC_VERSION_MIN_MACOSX
                minos = struct.unpack("<I", data[at + 8:at + 12])[0]
                facts["min_macos"][arch] = "%d.%d" % (minos >> 16, (minos >> 8) & 0xFF)
            elif cmd == 0x1D:  # LC_CODE_SIGNATURE
                offset, length = struct.unpack("<II", data[at + 8:at + 16])
                signature = code_signature(data[offset:offset + length])
            at += size
        facts["signature"][arch] = signature
    return facts


def code_signature(blob: bytes) -> str:
    """'ad-hoc', 'developer-id (TEAMID)' or 'invalid', from the SuperBlob itself."""
    magic, _, count = struct.unpack(">III", blob[:12])
    if magic != 0xFADE0CC0:
        return "invalid"
    flags, team, cms = 0, "", 0
    kinds = [struct.unpack(">I", blob[12 + at * 8:16 + at * 8])[0] for at in range(count)]
    if len(set(kinds)) != len(kinds):
        # What Godot 4.7.2's own signer writes: two code directories, both
        # in slot 0. Apple's second one goes in 0x1000.
        return "invalid (the same slot twice)"
    for at in range(count):
        kind, offset = struct.unpack(">II", blob[12 + at * 8:20 + at * 8])
        inner = blob[offset:]
        inner_magic, inner_length = struct.unpack(">II", inner[:8])
        if kind == 7 and inner[8:9] != b"\x70":
            # Entitlements in DER, which macOS 12 and later check at launch,
            # are [APPLICATION 16] { version 1, [16] { ... } }. Godot 4.7.2
            # writes a bare SET with TRUE as 01 rather than FF, and rcodesign
            # cannot read it back.
            return "invalid (entitlements not in Apple's DER form)"
        if kind == 0 and inner_magic == 0xFADE0C02:
            version, flags = struct.unpack(">II", inner[8:16])
            if version >= 0x20200:
                team_offset = struct.unpack(">I", inner[48:52])[0]
                if team_offset:
                    team = inner[team_offset:inner.index(b"\0", team_offset)].decode()
        elif kind == 0x10000:
            cms = inner_length - 8
    runtime = ", hardened runtime" if flags & 0x10000 else ""
    if flags & 0x2 or cms <= 0:
        return "ad-hoc" + runtime
    return "developer-id %s%s" % (team or "?", runtime)


def pe_facts(data: bytes) -> dict[str, Any]:
    """Machine, console or window, file version, and whether it is signed."""
    at = struct.unpack("<I", data[0x3C:0x40])[0]
    if data[at:at + 4] != b"PE\0\0":
        raise Failed("not a PE file")
    machine = struct.unpack("<H", data[at + 4:at + 6])[0]
    optional = at + 24
    magic = struct.unpack("<H", data[optional:optional + 2])[0]
    subsystem = struct.unpack("<H", data[optional + 68:optional + 70])[0]
    directories = optional + (112 if magic == 0x20B else 96)
    _, security_size = struct.unpack("<II", data[directories + 32:directories + 40])
    version = ""
    key = "ProductVersion".encode("utf-16-le") + b"\0\0"
    found = data.find(key)
    if found >= 0:
        start = found + len(key)
        while data[start:start + 2] == b"\0\0":
            start += 2
        end = start
        while data[end:end + 2] != b"\0\0":
            end += 2
        version = data[start:end].decode("utf-16-le", "replace")
    return {"machine": {0x8664: "x86_64", 0xAA64: "arm64"}.get(machine, hex(machine)),
            "subsystem": {2: "window", 3: "console"}.get(subsystem, str(subsystem)),
            "version": version, "signed": security_size > 0}


def glibc_needed(data: bytes) -> str:
    versions = {tuple(int(n) for n in m.groups()) for m in re.finditer(rb"GLIBC_(\d+)\.(\d+)", data)}
    return "%d.%d" % max(versions) if versions else ""


def inspect_tar(path: Path) -> dict[str, Any]:
    with tarfile.open(path) as archive:
        members = archive.getmembers()
        tops = {member.name.split("/")[0] for member in members}
        binary = next(m for m in members if m.name.endswith("/brickworks.x86_64"))
        handle = archive.extractfile(binary)
        data = handle.read() if handle else b""
    names = sorted(member.name.split("/", 1)[1] for member in members if "/" in member.name)
    return {"folder": sorted(tops), "contents": names,
            "executable": bool(binary.mode & 0o111), "glibc": glibc_needed(data),
            "unpacked": sum(member.size for member in members)}


def inspect_appimage(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    # The image starts where the runtime's ELF ends: after its section
    # headers, which is how the runtime itself finds it.
    shoff = struct.unpack("<Q", data[0x28:0x30])[0]
    shentsize, shnum = struct.unpack("<HH", data[0x3A:0x3E])
    squash = shoff + shentsize * shnum
    facts: dict[str, Any] = {"elf": data[:4] == b"\x7fELF",
                                "executable": bool(path.stat().st_mode & 0o111),
                                "squashfs": data[squash:squash + 4] == b"hsqs"}
    if not facts["squashfs"]:
        raise Failed("%s has no squashfs image after its runtime" % path.name)
    if shutil.which("unsquashfs"):
        listing = subprocess.run(["unsquashfs", "-o", str(squash), "-l", str(path)],
                                 capture_output=True, text=True).stdout
        facts["contents"] = sorted(line.split("squashfs-root/", 1)[1]
                                   for line in listing.splitlines() if "squashfs-root/" in line)
    return facts


def inspect_mac(path: Path) -> dict[str, Any]:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        prefix = next(name for name in names if name.endswith("Brickworks.app/"))
        plist = plistlib.loads(archive.read(prefix + "Contents/Info.plist"))
        binary_name = plist.get("CFBundleExecutable", "Brickworks")
        binary = prefix + "Contents/MacOS/" + binary_name
        facts = macho_facts(archive.read(binary))
        mode = archive.getinfo(binary).external_attr >> 16
        unpacked = sum(info.file_size for info in archive.infolist())
    facts.update({
        "bundle": prefix.rstrip("/"),
        "version": plist.get("CFBundleShortVersionString", ""),
        "build": plist.get("CFBundleVersion", ""),
        "identifier": plist.get("CFBundleIdentifier", ""),
        "plist_min_macos": plist.get("LSMinimumSystemVersion", ""),
        "executable": bool(mode & 0o111),
        "sealed": prefix + "Contents/_CodeSignature/CodeResources" in names,
        "stapled": prefix + "Contents/CodeResources" in names,
        "pck": any(name.endswith("Contents/Resources/Brickworks.pck") for name in names),
        "top": sorted({name.split("/")[0] for name in names}),
        "unpacked": unpacked,
    })
    return facts


def inspect_windows(path: Path) -> dict[str, Any]:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        exes = {}
        for name in names:
            if name.endswith(".exe"):
                exes[name.split("/")[-1]] = pe_facts(archive.read(name))
        unpacked = sum(info.file_size for info in archive.infolist())
    return {"top": sorted({name.split("/")[0] for name in names}),
            "contents": sorted(name.split("/", 1)[1] for name in names
                               if "/" in name and name.split("/", 1)[1]),
            "exes": exes, "unpacked": unpacked}


def inspect(out: Path) -> list[dict[str, Any]]:
    """Every package in a dist folder, read back and described."""
    version = out.name
    sums = {}
    if (out / "SHA256SUMS").exists():
        for line in (out / "SHA256SUMS").read_text().splitlines():
            digest, name = line.split(None, 1)
            sums[name.strip()] = digest
    files = []
    for path in sorted(out.glob("Brickworks-*")):
        entry: dict[str, Any] = {"name": path.name, "size": path.stat().st_size,
                                    **describe_file(path.name)}
        digest = sha256_of(path)
        if sums.get(path.name) != digest:
            raise Failed("%s does not match SHA256SUMS" % path.name)
        entry["sha256"] = digest
        if path.name.endswith(".tar.xz"):
            facts = inspect_tar(path)
            say("  %s  %s, unpacks to %s; executable %s; glibc %s or newer" % (
                path.name, human(entry["size"]), human(facts["unpacked"]),
                "yes" if facts["executable"] else "NO", facts["glibc"]))
            say("      " + ", ".join(facts["contents"]))
            if not facts["executable"]:
                raise Failed("%s: the binary lost its executable bit" % path.name)
        elif path.name.endswith(".AppImage"):
            facts = inspect_appimage(path)
            say("  %s  %s; ELF %s, executable %s" % (path.name, human(entry["size"]),
                "yes" if facts["elf"] else "NO", "yes" if facts["executable"] else "NO"))
            if facts.get("contents"):
                say("      " + ", ".join(facts["contents"]))
        elif "-macos-" in path.name:
            facts = inspect_mac(path)
            say("  %s  %s, unpacks to %s" % (path.name, human(entry["size"]),
                                             human(facts["unpacked"])))
            say("      %s %s (build %s), %s; architectures %s; oldest macOS %s" % (
                facts["bundle"], facts["version"], facts["build"], facts["identifier"],
                " + ".join(facts["architectures"]), facts["min_macos"]))
            say("      signature %s; sealed %s; notarisation ticket %s; executable %s; "
                "pck inside %s" % (facts["signature"], facts["sealed"], facts["stapled"],
                                   facts["executable"], facts["pck"]))
            if not facts["executable"]:
                raise Failed("%s: the app's binary lost its executable bit" % path.name)
            if facts["version"] != version:
                raise Failed("%s says it is %s" % (path.name, facts["version"]))
            if sorted(facts["architectures"]) != ["arm64", "x86_64"]:
                raise Failed("%s is not universal: %s" % (path.name, facts["architectures"]))
            unsigned = [s for s in facts["signature"].values()
                        if s == "none" or s.startswith("invalid")]
            if unsigned or not facts["sealed"]:
                raise Failed("%s is not validly signed (%s): an Apple silicon Mac may refuse "
                             "to run it" % (path.name, unsigned[0] if unsigned else "no seal"))
        elif "-windows-" in path.name:
            facts = inspect_windows(path)
            say("  %s  %s, unpacks to %s" % (path.name, human(entry["size"]),
                                             human(facts["unpacked"])))
            say("      " + ", ".join(facts["contents"]))
            for exe, about in facts["exes"].items():
                say("      %s: %s, %s, version %s, %s" % (exe, about["machine"], about["subsystem"],
                    about["version"], "signed" if about["signed"] else "unsigned"))
            if not facts["exes"]:
                raise Failed("%s has no .exe in it" % path.name)
        else:
            continue
        entry["facts"] = facts
        files.append(entry)
    missing = [name for names in artifacts(version).values() for name in names
               if not (out / name).exists()]
    if missing:
        say("  not built: %s" % ", ".join(missing))
    return files


# -- running a package ------------------------------------------------------

def unpack(package: Path, into: Path) -> Path:
    """Unpacked the way a person's system would, and the program to run."""
    name = package.name
    if name.endswith(".AppImage"):
        target = into / name
        shutil.copy2(package, target)
        target.chmod(0o755)
        return target
    if name.endswith(".tar.xz"):
        subprocess.run(["tar", "-xf", str(package), "-C", str(into)], check=True)
        return next(into.glob("*/brickworks.x86_64"))
    if sys.platform == "darwin":
        # ditto is what Finder's Archive Utility is, and keeps the seal.
        subprocess.run(["ditto", "-x", "-k", str(package), str(into)], check=True)
    elif shutil.which("unzip") and os.name != "nt":
        subprocess.run(["unzip", "-q", str(package), "-d", str(into)], check=True)
    else:
        with zipfile.ZipFile(package) as archive:
            archive.extractall(into)
    if "-macos-" in name:
        return next(into.glob("*/Brickworks.app/Contents/MacOS/Brickworks"))
    return next(into.glob("*/Brickworks.console.exe"))


def clean_env(home: Path) -> dict[str, str]:
    """A person's machine with nothing of this one in it.

    A fresh home, so the app's saved state is its own and a model left on
    this machine's baseplate cannot stand in for one the package opened;
    and none of the variables that point the app somewhere else or spend
    money.
    """
    # No display and no session bus: the runs are headless, and the one that
    # draws is given an Xvfb of its own.
    keep = ("PATH", "LANG", "LC_ALL", "SystemRoot", "ComSpec", "PATHEXT", "WINDIR", "TMPDIR",
            "VK_DRIVER_FILES", "VK_ICD_FILENAMES", "BOX_GPU_STATE", "BOX_GPU_HELD")
    env = {name: os.environ[name] for name in keep if name in os.environ}
    env.update({"HOME": str(home), "USERPROFILE": str(home),
                "APPDATA": str(home / "AppData" / "Roaming"),
                "LOCALAPPDATA": str(home / "AppData" / "Local"),
                "TEMP": str(home / "tmp"), "TMP": str(home / "tmp")})
    (home / "tmp").mkdir(parents=True, exist_ok=True)
    return env


def run_app(command: list[str], env: dict[str, str], seconds: int = 420) -> tuple[int, str]:
    """Exit status and everything it said, 124 if it ran out of time.

    Into a file and not a pipe, and waiting on the process rather than on
    the pipe closing: under xvfb-run and the GPU lease, something outlives
    the app holding its output open, and a drawn frame that exited 0 was
    reported as a timeout with nothing to say.
    """
    with tempfile.TemporaryFile("w+", errors="replace") as log:
        # A group of its own, so running out of time ends the app and not
        # only the wrapper in front of it: that left one running, orphaned.
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=os.name != "nt")
        try:
            code = process.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            if os.name != "nt":
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
            process.wait()
            code = 124
        log.seek(0)
        output = log.read()
    if code == 124:
        output += "\n(no answer in %d s)" % seconds
    return code, output


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def smoke(package: Path, window: bool, expect: str) -> int:
    """Unpack a package and run it in a clean home. Exit 0 only if every check held."""
    failures = 0

    def check(what: str, ok: bool, detail: str = "") -> None:
        nonlocal failures
        say("  %s  %s" % ("ok  " if ok else "FAIL", what))
        if not ok:
            failures += 1
            for line in detail.strip().splitlines()[-12:]:
                say("        " + line)

    def clean(output: str) -> bool:
        return not re.search(r"SCRIPT ERROR|Parse Error|Failed to load script", output)

    with tempfile.TemporaryDirectory(prefix="brickworks-smoke-") as scratch:
        root = Path(scratch)
        (root / "unpacked").mkdir()
        program = unpack(package.resolve(), root / "unpacked")
        env = clean_env(root / "home")
        say("── %s, unpacked in a clean home ──" % package.name)
        say("  %s" % program.relative_to(root))
        base = [str(program)]

        code, output = run_app(base + ["--headless", "--", "--about"], env, 180)
        about = next((line for line in output.splitlines() if line.startswith("Brickworks ")), "")
        check("--about: %s" % (about or "nothing"), code == 0 and clean(output)
              and about.startswith("Brickworks %s, released " % expect), output)

        if package.name.endswith(".AppImage"):
            # Without FUSE an AppImage can still unpack itself and run.
            code, output = run_app(base + ["--appimage-extract-and-run", "--headless", "--",
                                           "--about"], env, 420)
            check("--appimage-extract-and-run works too", code == 0
                  and "Brickworks %s, released " % expect in output, output)

        # The catalogue, a model shipped in the package and every mesh it
        # names, written back out: the whole read path, offline.
        written = root / "car.ldr"
        code, output = run_app(base + ["--headless", "--", "--model=res://models/car.ldr",
                                       "--out=%s" % written], env)
        said = re.search(r"wrote .* \((\d+) parts\)", output)
        bricks = [line for line in written.read_text().splitlines() if line.startswith("1 ")] \
            if written.exists() else []
        check("opens the example car and writes it back: %s parts in the file"
              % len(bricks), code == 0 and clean(output) and said is not None
              and int(said.group(1)) == len(bricks) > 50, output)

        # Placing bricks from outside, the way a Claude Code session does,
        # through the relay in this checkout. tools/mcp_check.py searches
        # the catalogue, clears the baseplate, builds two bricks, saves and
        # reads the file back.
        port = free_port()
        log = (root / "mcp-app.log").open("w")
        # Its own process group, so stopping it cannot reach this one.
        app = subprocess.Popen(base + ["--headless", "--", "--mcp=%d" % port], env=env,
                               stdout=log, stderr=subprocess.STDOUT,
                               start_new_session=os.name != "nt",
                               creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))
        try:
            started = time.time()
            listening = False
            while time.time() - started < 300 and app.poll() is None:
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=2):
                        listening = True
                        break
                except OSError:
                    time.sleep(0.5)
            check("listens for MCP on %d after %.0f s" % (port, time.time() - started), listening,
                  (root / "mcp-app.log").read_text(errors="replace"))
            if listening:
                drive = subprocess.run([sys.executable, str(ROOT / "tools" / "mcp_check.py"),
                                        "--port=%d" % port], capture_output=True, text=True,
                                       timeout=600)
                built = next((line.strip() for line in drive.stdout.splitlines()
                              if "a design lands" in line), "")
                check("a session places bricks in it over MCP: %s" % built,
                      drive.returncode == 0, drive.stdout + drive.stderr)
        finally:
            if app.poll() is None:
                if os.name != "nt":
                    os.killpg(os.getpgid(app.pid), signal.SIGTERM)
                else:
                    app.terminate()
                try:
                    app.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    app.kill()
            log.close()
        check("the app kept its state in the clean home", any((root / "home").rglob("Brickworks")))

        if window:
            # Drawn, not just loaded: a picture of the car from the package's
            # own geometry, on Xvfb when there is no screen.
            shot = root / "car.png"
            command = base + ["--resolution", "1280x800", "--", "--model=res://models/car.ldr",
                              "--shot=%s" % shot]
            if shutil.which("xvfb-run"):
                # Always off-screen, whatever this shell's display is. The
                # clean home kept WAYLAND_DISPLAY at first, Godot chose
                # Wayland over the Xvfb it was given, and the smoke test
                # opened a window on the desktop of whoever was sitting
                # there; one of those never exited.
                env["MESA_VK_WSI_DEBUG"] = "sw"
                command = ["xvfb-run", "-a", "--server-args=-screen 0 1280x800x24"] + command
            elif sys.platform.startswith("linux"):
                for name in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY"):
                    if name in os.environ:
                        env[name] = os.environ[name]
                say("        no xvfb-run: drawing on this machine's own screen")
            gpu = Path.home() / ".claude" / "claude-core" / "bin" / "gpu"
            if os.access(gpu, os.X_OK):
                # This machine's GPU lease. It finds the account's own home
                # itself, so the fresh one given to the app does not split it.
                command = [str(gpu)] + command
            code, output = run_app(command, env, 600)
            colours = png_colours(shot) if shot.exists() else 0
            check("draws the car: %d colours in a %s picture" % (colours, "1280x800"),
                  code == 0 and clean(output) and colours > 200, output)
            if shot.exists():
                keep = ROOT / "shots" / ("release-%s.png" % describe_file(package.name)["os"])
                keep.parent.mkdir(exist_ok=True)
                shutil.copy2(shot, keep)
                say("        kept the picture at %s" % keep.relative_to(ROOT))

    say("")
    if failures:
        say("%d check(s) failed: %s is not fit to ship" % (failures, package.name))
        return 1
    say("%s starts, loads the part library, opens a model and takes bricks" % package.name)
    return 0


def png_colours(path: Path) -> int:
    """Distinct colours in an 8-bit RGB or RGBA PNG: a blank frame has a handful."""
    data = path.read_bytes()
    at, chunks, header = 8, [], b""
    while at < len(data):
        length = struct.unpack(">I", data[at:at + 4])[0]
        kind = data[at + 4:at + 8]
        body = data[at + 8:at + 8 + length]
        if kind == b"IHDR":
            header = body
        elif kind == b"IDAT":
            chunks.append(body)
        at += 12 + length
    width, height, depth, colour = struct.unpack(">IIBB", header[:10])
    if depth != 8 or colour not in (2, 6):
        return 0
    channels = 3 if colour == 2 else 4
    raw = zlib.decompress(b"".join(chunks))
    stride = width * channels
    previous = bytearray(stride)
    seen: set[bytes] = set()
    for row in range(height):
        kind = raw[row * (stride + 1)]
        line = bytearray(raw[row * (stride + 1) + 1:(row + 1) * (stride + 1)])
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            corner = previous[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + left) & 0xFF
            elif kind == 2:
                line[i] = (line[i] + up) & 0xFF
            elif kind == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 0xFF
            elif kind == 4:
                guess = left + up - corner
                pa, pb, pc = abs(guess - left), abs(guess - up), abs(guess - corner)
                line[i] = (line[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 0xFF
        if row % 4 == 0:
            for i in range(0, stride, channels * 4):
                seen.add(bytes(line[i:i + 3]))
        previous = line
    return len(seen)


# -- publishing -------------------------------------------------------------

def release_notes(version: str, files: list[dict[str, Any]], tag: str) -> str:
    date, body = section(version)
    rows = "\n".join("| %s | `%s` | %s |" % (
        {"linux": "Linux", "macos": "macOS", "windows": "Windows"}[str(f["os"])], f["name"],
        human(int(f["size"]))) for f in files)
    mac = next((f for f in files if f["os"] == "macos"), None)
    notarized = bool(mac and "developer-id" in json.dumps(mac.get("facts", {}))
                     and mac["facts"].get("stapled"))
    win = next((f for f in files if f["os"] == "windows"), None)
    win_signed = bool(win and all(e["signed"] for e in win["facts"]["exes"].values()))
    first = []
    if not notarized:
        first.append("- **macOS** is not yet notarised by Apple. Open it once and choose "
                     "Done, then System Settings > Privacy & Security > **Open Anyway**.")
    if not win_signed:
        first.append("- **Windows** is not yet signed. SmartScreen may say \"Windows protected "
                     "your PC\": check the SHA-256, then **More info** > **Run anyway**.")
    return "\n".join([
        body, "", "## Downloads", "",
        "The right one for your system, with checksums and what each needs: "
        "https://brickworks.diy/download.html", "",
        "| System | File | Size |", "|---|---|---|", rows, "",
        "Every file's SHA-256 is in `SHA256SUMS` (`sha256sum -c SHA256SUMS`).", "",
        *(["### The first launch", "", *first, ""] if first else []),
        "Released %s from %s." % (date, tag)])


def manifest_entry(version: str, tag: str, files: list[dict[str, Any]], date: str,
                   urls: dict[str, str]) -> dict[str, Any]:
    _, body = section(version)
    summary = body.split("\n\n", 1)[0].replace("\n", " ").strip()
    entries = []
    for f in files:
        facts = f.get("facts", {})
        item: dict[str, Any] = {key: f[key] for key in ("os", "arch", "kind", "name", "size",
                                                            "sha256")}
        item["url"] = urls[str(f["name"])]
        item["unpacked"] = facts.get("unpacked")
        if f["os"] == "linux" and facts.get("glibc"):
            item["glibc"] = facts["glibc"]
        if f["os"] == "macos":
            item["min_macos"] = facts.get("min_macos")
            signature = " ".join(str(v) for v in facts.get("signature", {}).values())
            item["signed"] = "developer-id" if "developer-id" in signature else "ad-hoc"
            item["notarized"] = bool(facts.get("stapled"))
        if f["os"] == "windows":
            item["signed"] = all(e["signed"] for e in facts.get("exes", {}).values())
        entries.append(item)
    return {"version": version, "tag": tag, "date": date,
            "page": "https://github.com/%s/releases/tag/%s" % (REPO, tag),
            "notes": "https://github.com/%s/blob/%s/CHANGELOG.md" % (REPO, tag),
            "summary": summary, "files": entries}


def write_manifest(entry: dict[str, Any], path: Path) -> None:
    current: dict[str, Any] = {"releases": []}
    if path.exists():
        current = json.loads(path.read_text())
    others = [r for r in current.get("releases", []) if r.get("version") != entry["version"]]
    releases = [entry, *others]
    data = {"$comment": "Written by tools/release.py publish; read by download.js. "
                        "Every url is pinned to its release, so what the page says is "
                        "exactly what it links to.",
            "latest": entry["version"], "releases": releases}
    path.write_text(json.dumps(data, indent=1) + "\n")
    say("  wrote %s" % path.relative_to(ROOT) if path.is_relative_to(ROOT) else str(path))


def built(version: str) -> tuple[Path, dict[str, Any]]:
    out = DIST / version
    record = out / "build.json"
    if not record.exists():
        raise Failed("nothing built for %s: tools/release.py build" % version)
    facts = json.loads(record.read_text())
    expected = [name for names in artifacts(version).values() for name in names]
    names = [f["name"] for f in facts["files"]]
    if sorted(names) != sorted(expected):
        raise Failed("%s has %s, a release needs %s" % (out, names, expected))
    say("── checking %s against SHA256SUMS ──" % out.relative_to(ROOT))
    for f in facts["files"]:
        if sha256_of(out / f["name"]) != f["sha256"]:
            raise Failed("%s changed since it was built" % f["name"])
    return out, facts


def release_view(tag: str) -> dict[str, Any] | None:
    """GitHub's view of a release, drafts included, or None when there is none."""
    done = subprocess.run(["gh", "release", "view", tag, "--repo", REPO, "--json",
                           "url,isDraft,assets,tagName,publishedAt,databaseId"],
                          env=gh_env(), capture_output=True, text=True)
    if done.returncode != 0:
        if "not found" in (done.stderr + done.stdout).lower():
            return None
        raise Failed("gh release view %s: %s" % (tag, done.stderr.strip()))
    return json.loads(done.stdout)


def publish(draft: bool, tag: str, target: str, manifest: bool) -> int:
    problems = check_version()
    if problems:
        raise Failed("the version does not agree with itself:\n  " + "\n  ".join(problems))
    version = version_file()
    tag = tag or "v" + version
    out, facts = built(version)
    date, _ = section(version)
    commit = target or str(facts["commit"])
    if not target:
        full = git("rev-parse", commit)
        subprocess.run(["git", "fetch", "-q", "origin"], cwd=ROOT, check=True)
        if not git("branch", "-r", "--contains", full):
            raise Failed("%s, which this was built from, is not pushed: push it first" % commit)
        commit = full
    files = [out / f["name"] for f in facts["files"]] + [out / "SHA256SUMS"]
    existing = release_view(tag)
    if existing is None:
        # Uploaded once. A draft is how a release is checked on the
        # systems it is for before anyone can see it; publishing then
        # promotes that same draft, so what was checked is what ships.
        notes = release_notes(version, facts["files"], tag)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as handle:
            handle.write(notes)
        say("── %s %s, %d files, %s ──" % ("drafting" if draft else "publishing", tag,
                                         len(files), human(sum(p.stat().st_size for p in files))))
        command = ["gh", "release", "create", tag, "--repo", REPO, "--title",
                   "Brickworks %s" % version, "--notes-file", handle.name, "--target", commit]
        command += ["--draft"] if draft else ["--latest"]
        started = time.time()
        subprocess.run(command + [str(p) for p in files], env=gh_env(), check=True)
        os.unlink(handle.name)
        say("  uploaded in %.0f s" % (time.time() - started))
    elif existing["isDraft"] and draft:
        raise Failed("%s is already a draft (%s): publish it without --draft, or delete it "
                     "with gh release delete %s --yes" % (tag, existing["url"], tag))
    elif existing["isDraft"]:
        say("── publishing the draft %s ──" % tag)
        subprocess.run(["gh", "release", "edit", tag, "--repo", REPO, "--draft=false",
                        "--latest"], env=gh_env(), check=True, capture_output=True)
    else:
        say("── %s is already published: checking it against dist/ ──" % tag)

    # Read back what GitHub holds, and compare it with what was built.
    # GitHub computes each asset's SHA-256 itself.
    view = release_view(tag)
    if view is None:
        raise Failed("GitHub has no release %s after creating it" % tag)
    held = {asset["name"]: asset for asset in view["assets"]}
    api = json.loads(subprocess.run(
        ["gh", "api", "repos/%s/releases/%s" % (REPO, view["databaseId"])],
        env=gh_env(), check=True, capture_output=True, text=True).stdout)
    digests = {asset["name"]: (asset.get("digest") or "") for asset in api.get("assets", [])}
    urls = {asset["name"]: asset["browser_download_url"] for asset in api.get("assets", [])}
    wrong = 0
    for path in files:
        digest = sha256_of(path)
        got = held.get(path.name)
        theirs = digests.get(path.name, "").removeprefix("sha256:")
        ok = got is not None and got["size"] == path.stat().st_size and theirs == digest
        wrong += 0 if ok else 1
        say("  %s  %s  %s" % ("ok  " if ok else "FAIL", path.name,
                              "GitHub's SHA-256 matches" if ok else "size or digest differs"))
    if wrong:
        raise Failed("%d file(s) on the release are not what was built: %s" % (wrong, view["url"]))
    say("  %s%s" % (view["url"], " (a draft: nobody else can see it)" if view["isDraft"] else ""))
    if manifest and not draft:
        public = {name: "https://github.com/%s/releases/download/%s/%s" % (REPO, tag, name)
                  for name in urls}
        write_manifest(manifest_entry(version, tag, facts["files"], date, public), MANIFEST)
        say("next: commit web/releases.json, push, then tools/deploy.sh --prod so the "
            "download page offers %s" % version)
    return 0


def local_manifest(out_path: Path) -> int:
    version = version_file()
    _, facts = built(version)
    tag = "v" + version
    urls = {f["name"]: "https://github.com/%s/releases/download/%s/%s" % (REPO, tag, f["name"])
            for f in facts["files"]}
    write_manifest(manifest_entry(version, tag, facts["files"], str(facts["date"]), urls),
                   out_path)
    return 0


# -- the command line -------------------------------------------------------

def option(args: list[str], name: str, default: str = "") -> str:
    for arg in args:
        if arg.startswith("--%s=" % name):
            return arg.split("=", 1)[1]
    return default


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    command, args = argv[0], argv[1:]
    if command == "version":
        new = option(args, "set") or (args[args.index("--set") + 1] if "--set" in args else "")
        if new:
            set_version(new, dt.date.today().isoformat())
            return 0
        problems = check_version()
        for problem in problems:
            say("  FAIL  " + problem)
        if not problems:
            say("  ok    version %s in VERSION, project.godot and CHANGELOG.md (%s)"
                % (version_file(), section(version_file())[0]))
        return 1 if problems else 0
    if command == "notes":
        version = args[0] if args else version_file()
        print(section(version)[1])
        return 0
    if command == "build":
        under_heavy(argv)
        wanted = [arg for arg in args if not arg.startswith("--")] or list(PLATFORMS)
        wanted = ["mac" if w == "macos" else w for w in wanted]
        unknown = [w for w in wanted if w not in PLATFORMS]
        if unknown:
            raise Failed("unknown platform %s: linux, mac or windows" % unknown)
        assets = Path(option(args, "assets", str(ROOT / "assets" / "generated"))).resolve()
        return build(wanted, assets)
    if command == "inspect":
        out = Path(args[0]) if args else DIST / version_file()
        inspect(out.resolve())
        return 0
    if command == "smoke":
        if not args or args[0].startswith("--"):
            raise Failed("smoke needs a package: tools/release.py smoke dist/<version>/<file>")
        under_heavy(argv)
        return smoke(Path(args[0]), "--window" in args, option(args, "expect", version_file()))
    if command == "publish":
        return publish("--draft" in args, option(args, "tag"), option(args, "target"),
                       "--no-manifest" not in args)
    if command == "manifest":
        if "--local" not in args:
            raise Failed("manifest --local: publish writes the real one")
        return local_manifest(Path(option(args, "out", str(MANIFEST))).resolve())
    raise Failed("unknown command %r: see tools/release.py --help" % command)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Failed as failure:
        print("release FAILED: %s" % failure, file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as failure:
        print("release FAILED: %s exited %d" % (failure.cmd[0], failure.returncode), file=sys.stderr)
        sys.exit(1)
