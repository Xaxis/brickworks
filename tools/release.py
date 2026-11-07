#!/usr/bin/env python3
"""Cut, build, check and publish a desktop release of Brickworks.

    tools/release.py version                 do VERSION, project.godot and CHANGELOG.md agree?
    tools/release.py version --set 0.2.0     bump all three; [Unreleased] becomes 0.2.0's section
    tools/release.py notes [0.1.0]           that version's changelog section
    tools/release.py build [linux mac windows]   export and package into dist/<version>/
          --assets=DIR                       the mesh cache to ship (default assets/generated)
    tools/release.py inspect [DIR]           what is in each package: versions, architectures,
                                             signatures, contents. Reads the packages, not notes
    tools/release.py smoke FILE [--window]   unpack it as a person would and run it in a clean home;
                                             --window draws the car and traces it at Best
    tools/release.py best-reference          the editor's Best of the car, which smoke holds a
                                             package's to (tools/release/best_car.png)
    tools/release.py publish --draft         upload the packages to a draft release on
                                             Xaxis/brickworks-releases and check GitHub's
                                             SHA-256 of each against dist/
    tools/release.py publish                 publish that draft, check it again, tag the
                                             commit on origin, and write web/releases.json
          [--tag=TAG] [--target=REF] [--no-manifest]
    tools/release.py manifest --local [--out=FILE]   the page's manifest from dist/, to preview it
    tools/release.py latest --check FILE      is FILE a latest.json the app would believe?

docs/RELEASING.md is the cycle this is part of, and says when to run each.

The packages carry the whole part library (about a gigabyte of geometry),
because the desktop app works with no network and the web build cannot.
That library is not in git, so a release is built on a machine that has
it, and CI only proves what was built (tools/release/releases_repo/release.yml,
run in the releases repository).

Signing plugs in by environment, from .env or the shell; values are never
printed. Without them the macOS app is ad-hoc signed and Windows unsigned,
and the download page says what that means for the first launch:

    APPLE_SIGN_P12, APPLE_SIGN_P12_PASSWORD       Developer ID Application certificate
    APPLE_NOTARY_KEY, APPLE_NOTARY_KEY_ID, APPLE_NOTARY_ISSUER
                                                  App Store Connect API key, to notarise
    WINDOWS_SIGN_COMMAND                          signs one file in place; {file} is its path

The desktop app's updater believes latest.json only under a signature by a
key it knows (docs/UPDATES.md). Publishing signs it with both of these,
from .env, and refuses a key whose public half src/net/updates.gd lacks:

    UPDATE_SIGN_KEY, UPDATE_SIGN_KEY_BACKUP       RSA private keys, PEM, base64 on one line
"""

from __future__ import annotations

import base64
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
from typing import Any, Callable

from trademarks import MARK_FAULTS

ROOT = Path(__file__).resolve().parent.parent
# Where the packages are published: a public repository of builds only, so
# the downloads answer whether or not the source repository is public
# (tools/release/releases_repo.sh made it, 2026-10-27).
REPO = "Xaxis/brickworks-releases"
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
    # The C compiler that builds the macOS launcher on Linux
    # (tools/release/package/launcher.c, build_launcher): zig carries
    # macOS's libSystem, so no Apple SDK is needed. Unpacked once (zig()).
    "zig": {
        "url": "https://ziglang.org/download/0.17.1/zig-x86_64-linux-0.17.1.tar.xz",
        "sha256": "3581863e3cbcfd0fce0efc682ce7e9e93da96668a977791d356a26d2a7e9b17a",
    },
    # The macOS disk image, made on Linux as Mozilla makes Firefox's (hdiutil
    # is macOS's own): mkfs.hfsplus from Ubuntu 24.04's hfsprogs makes an
    # empty HFS+ volume, and libdmg-hfsplus (Mozilla's fork, at a commit with
    # addall's --symlinks and --special-modes) fills it and compresses it
    # into a UDIF image. Built once from source, zlib and bzip2 linked in
    # (dmg_tools). The same pins as Reelwright's.
    "hfsprogs": {
        "url": "http://archive.ubuntu.com/ubuntu/pool/universe/h/hfsprogs/hfsprogs_540.1.linux3-5build3_amd64.deb",
        "sha256": "21aab68916cdba913b8571f1d83285f958878d2378255ee87a225575b917b77f",
    },
    "libdmg-hfsplus": {
        "url": "https://github.com/mozilla/libdmg-hfsplus/archive/ec239599c1f234a4e01ae3fe51214d0c77e5baa3.tar.gz",
        "sha256": "190e29e4e0bd53e31af1f617b62dcd46b300ffbb0b7cd9e1bf49adb218872763",
    },
    "zlib": {
        "url": "https://zlib.net/fossils/zlib-1.3.1.tar.gz",
        "sha256": "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23",
    },
    "bzip2": {
        "url": "https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz",
        "sha256": "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269",
    },
    # The .DS_Store that lays out the image's window, and the alias in it
    # that names its background: pure Python (MIT), what dmgbuild uses,
    # imported from the wheels themselves.
    "ds_store": {
        "url": "https://files.pythonhosted.org/packages/66/c0/718a4132306ff8ff052f2c40595f45595993b480409400d55b07f3842d45/ds_store-1.3.3-py3-none-any.whl",
        "sha256": "b92a371efbf1b4ccce2a04d1ed13fceacc4736c81ba09cf5aefb74c088160a35",
    },
    "mac_alias": {
        "url": "https://files.pythonhosted.org/packages/13/20/103f4e4a6e8a524ea92eee7d938c6133d0b129aa999a50f8648ad126c728/mac_alias-2.2.3-py3-none-any.whl",
        "sha256": "7362b521d2132ef92f606a37abfed5fcd849ceb2f28b6f9743e014b02af92f0d",
    },
    # The Windows installer, made on Linux: makensis from Ubuntu 24.04's
    # NSIS, unpacked with NSISDIR naming its data (makensis).
    "nsis": {
        "url": "http://archive.ubuntu.com/ubuntu/pool/universe/n/nsis/nsis_3.09-4ubuntu1_amd64.deb",
        "sha256": "9e061bef1a8b611aeb2ea76d9a3bd7722b960ca1a9dff8e38d2ab51e5a8f5e5b",
    },
    "nsis-common": {
        "url": "http://archive.ubuntu.com/ubuntu/pool/universe/n/nsis/nsis-common_3.09-4ubuntu1_all.deb",
        "sha256": "49471b9debdee4751ebb4caf6b705cc4c678eebfaecefbe56362258893f85859",
    },
}

SIGNING_NAMES = ("APPLE_SIGN_P12", "APPLE_SIGN_P12_PASSWORD", "APPLE_NOTARY_KEY",
                 "APPLE_NOTARY_KEY_ID", "APPLE_NOTARY_ISSUER", "WINDOWS_SIGN_COMMAND",
                 "UPDATE_SIGN_KEY", "UPDATE_SIGN_KEY_BACKUP")
UPDATE_KEYS = ("UPDATE_SIGN_KEY", "UPDATE_SIGN_KEY_BACKUP")
# What the app's manifest says it is for, and where it reads the keys it
# believes (Updates.PRODUCT, Updates.KEYS).
UPDATE_PRODUCT = "brickworks-desktop"
UPDATES_GD = ROOT / "src" / "net" / "updates.gd"


# The licence texts every package carries beside the app (extras), and what
# THIRD-PARTY-NOTICES.txt must say for them to be whole: each licence's own
# words that a copy has to carry. Credits.notices writes it from the list
# Help, About shows (tools/release_notices.gd); inspect reads it back out of
# every package.
LICENCE_FILES = ("ATTRIBUTION.md", "THIRD-PARTY-NOTICES.txt")
NOTICES_SAY = {
    "Godot's licence": "Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md)",
    "its components' notices": "== Components ==",
    "BrickNet's MIT text": "Copyright (c) 2026 Peter Kulits\n\nPermission is hereby granted",
    "LDraw's notice": "the LDraw community, licensed under CC BY 2.0 and CC BY 4.0",
    "Rebrickable's credit": "Catalog data: Rebrickable",
}


# The model files each package tells its system Brickworks opens: what
# File, Open from a file reads, and what the app opens when the system hands
# it one (TabSession.given_file). LDraw's it claims; Studio's and LDD's it
# only offers to open, so a person with Studio or LDD keeps them opening
# there. The MIME types are LeoCAD's, so the two share them on Linux.
# "drawn": the file browser shows a picture of the model the app draws
# (THUMBNAILER); an LDD file keeps its type's icon, the app reading only
# what LDD's own parts become in LDraw's.
MODEL_TYPES = (
    {"ext": "ldr", "name": "LDraw model", "uti": "org.ldraw.ldr",
     "mime": "application/x-ldraw", "text": True, "claims": True, "drawn": True},
    {"ext": "mpd", "name": "LDraw multi-part model", "uti": "org.ldraw.mpd",
     "mime": "application/x-multi-part-ldraw", "text": True, "claims": True, "drawn": True},
    {"ext": "io", "name": "BrickLink Studio model", "uti": "dev.brickworks.studio-io",
     "mime": "application/x-bricklink-studio", "text": False, "claims": False, "drawn": True},
    {"ext": "lxf", "name": "LDD model", "uti": "dev.brickworks.ldd-lxf",
     "mime": "application/x-lxf", "text": False, "claims": False, "drawn": False},
)
# Art the packages carry, drawn by tools/web/make_icons.mjs: the icon at the
# sizes each system asks for, and the disk image's background.
PACKAGE_ART = ROOT / "tools" / "release" / "package"
# The Linux packages' name for the app: the .desktop file, the icon, the
# MIME types and the metainfo are all called this (the macOS bundle's id).
APP_ID = "dev.brickworks.app"
# The .deb's thumbnailer: a folder of models shows a picture of each, drawn
# by the app from its corner view (src/render/model_thumbnail.gd), where it
# showed the type's icon on every file. GNOME's file browser (and anything
# else reading /usr/share/thumbnailers, Xfce's tumbler among them) runs the
# entry's Exec with %i the model, %o the PNG to write and %s the size, in
# GNOME's case inside a bubblewrap sandbox: /usr read only, the model, an
# empty /tmp for the picture, no display, no network. THUMBNAIL_RUNNER runs
# the app headless with a data folder of its own there, made and removed
# each time, so the app's logs and settings are never touched: the engine
# writes a log at every start and keeps five, and a folder of fifty models
# would have pushed out every log of the app's own. It is a command on PATH
# as evince-thumbnailer is, so "brickworks-thumbnailer MODEL PICTURE" works
# from a terminal too.
THUMBNAILER = "usr/share/thumbnailers/%s.thumbnailer" % APP_ID
THUMBNAIL_RUNNER = "usr/bin/brickworks-thumbnailer"


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
        for pattern, why, _ in MARK_FAULTS:
            for found in pattern.finditer(body):
                around = body[max(0, found.start() - 30):found.end() + 30].replace("\n", " ")
                problems.append("CHANGELOG.md's [%s]: %s: ...%s..." % (version, why, around))
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
    """Each system's packages, the one the download page offers first first.
    The zips are the packages from before the disk image and the installer,
    kept for one release so links already shared keep working
    (docs/DISTRIBUTION.md)."""
    base = "Brickworks-%s" % version
    return {
        "linux": [base + "-linux-x86_64.AppImage", base + "-linux-amd64.deb",
                  base + "-linux-x86_64.tar.xz"],
        "mac": [base + "-macos-universal.dmg", base + "-macos-universal.zip"],
        "windows": [base + "-windows-x86_64-setup.exe", base + "-windows-x86_64.zip"],
    }


def describe_file(name: str) -> dict[str, str]:
    """Which system and what kind of package a file name is."""
    if "-linux-" in name:
        kind = ("AppImage" if name.endswith(".AppImage") else "deb" if name.endswith(".deb")
                else "tar.xz")
        return {"os": "linux", "arch": "x86_64", "kind": kind}
    if "-macos-" in name:
        return {"os": "macos", "arch": "universal", "kind": "dmg" if name.endswith(".dmg") else "zip"}
    if "-windows-" in name:
        return {"os": "windows", "arch": "x86_64",
                "kind": "installer" if name.endswith("-setup.exe") else "zip"}
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
    # LDraw's primitives, every one (PartForge.SHIPPED): what the parts a
    # file carries and LDCad's flexible parts are drawn from. Git-ignored,
    # and copied in by tools/export.sh for its builds, so from git alone no
    # package had them: bay_2025.io's own part, made from 3001.dat, wanted
    # box3u2p.dat once 3001.dat was fetched (2026-11-03).
    primitives = ROOT / "vendor" / "ldraw" / "p"
    if not (primitives / "stud.dat").exists():
        raise Failed("no LDraw primitives at %s: tools/fetch_data.sh first" % primitives)
    shutil.copytree(primitives, STAGE / "assets" / "ldraw" / "p")
    shipped_primitives = list((STAGE / "assets" / "ldraw" / "p").rglob("*.dat"))

    generated = STAGE / "assets" / "generated"
    (generated / "parts").mkdir(parents=True)
    for table in sorted(assets.glob("*.json")):
        # Copied, not linked: refresh_catalogue.py rewrites these in place.
        shutil.copy2(table, generated / table.name)
    for mesh in meshes:
        name = mesh + ".lbm"
        link_or_copy(assets / "parts" / name, generated / "parts" / name)
    # The exact shapes (BrickNet's, which the build check reads where the
    # lattice's cells would forgive a real collision) of every part a real
    # set uses: 4,455 of 15,417, 337 MB of 938, and every part appearance in
    # the 30,000 inventories (2026-10-16). The other 10,962 are parts no
    # inventory has, stickers and rare variants mostly; a part without one
    # is checked by its cover, as every part was before 2026-10-15.
    exact = sorted({part["mesh"] for part in catalogue.get("parts", [])
                    if part.get("mesh") and (part.get("in_sets") or 0) > 0
                    and (assets / "exact" / (part["mesh"] + ".bwx")).exists()})
    if exact:
        (generated / "exact").mkdir()
        for mesh in exact:
            name = mesh + ".bwx"
            link_or_copy(assets / "exact" / name, generated / "exact" / name)
    stamp = {"version": version, "commit": commit, "date": date}
    (STAGE / "release.json").write_text(json.dumps(stamp) + "\n")
    say("  staged %s: %d parts' meshes, %s; %d exact shapes, %s; %d LDraw primitives, %s"
        % (commit, len(meshes), human(
            sum((generated / "parts" / (m + ".lbm")).stat().st_size for m in meshes)), len(exact),
           human(sum((generated / "exact" / (m + ".bwx")).stat().st_size for m in exact)),
           len(shipped_primitives), human(sum(path.stat().st_size for path in shipped_primitives))))

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
    lacking = notices_lacking(target.read_text())
    if lacking:
        raise Failed("THIRD-PARTY-NOTICES.txt lacks %s" % ", ".join(lacking))


def notices_lacking(text: str) -> list[str]:
    """What of NOTICES_SAY a THIRD-PARTY-NOTICES.txt does not say."""
    return [what for what, words in NOTICES_SAY.items() if words not in text]


def licences(read: Callable[[str], bytes | None]) -> dict[str, Any]:
    """The licence texts a package carries: [read] gives a file beside the
    app by its name, or None. What is lacking, files or words, is named."""
    texts = {name: read(name) for name in LICENCE_FILES}
    notices = texts["THIRD-PARTY-NOTICES.txt"]
    lacking = [name for name, data in texts.items() if not data]
    if notices:
        lacking += notices_lacking(notices.decode("utf-8", "replace"))
    return {"files": [name for name, data in texts.items() if data],
            "notices": len(notices or b""), "lacking": lacking}


def say_licences(package: str, facts: dict[str, Any]) -> None:
    said = [what for what in NOTICES_SAY if what not in facts["lacking"]]
    say("      licences: %s; the notices (%s) say %s" % (
        ", ".join(facts["files"]) or "none", human(facts["notices"]), ", ".join(said) or "nothing"))
    if facts["lacking"]:
        raise Failed("%s lacks %s" % (package, ", ".join(facts["lacking"])))


def readme(platform: str, version: str, date: str, signed: dict[str, bool]) -> str:
    """The README.txt each package carries: what it is and how to start it."""
    lines = ["Brickworks %s, released %s" % (version, date), "",
             "A dimensionally exact brick construction system: every part in the",
             "LDraw library at true size, building by hand or with Claude, and",
             "instructions and a parts list at the end. The whole part library is",
             "inside this package, so building needs no network.", "",
             "https://brickworks.diy        the site, and this app in a browser",
             "https://brickworks.diy/download        checksums and every download", ""]
    if platform == "linux":
        lines += ["To start it:", "",
                  "  ./brickworks.x86_64", "",
                  "Or, from the AppImage: chmod +x the file and run it. AppImages mount",
                  "themselves with FUSE; without it, run it with --appimage-extract-and-run.",
                  "From the .deb, it is in your menu, and brickworks in a terminal;",
                  "sudo apt remove brickworks uninstalls it.", ""]
        where = "~/.local/share/godot/app_userdata/Brickworks/"
    elif platform == "mac":
        lines += ["To start it: move Brickworks.app to Applications and open it. To",
                  "uninstall it, move it to the Trash.", ""]
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
        lines += ["From the installer, Brickworks is in the Start menu, and Settings >",
                  "Apps uninstalls it. From the zip: extract the whole folder first, then",
                  "run Brickworks.exe. Brickworks.pck must stay beside it.",
                  "Brickworks.console.exe is the same app with a console window, for",
                  "reading what it says.", ""]
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
              "sponsor, authorize or endorse this app. Part geometry is derived",
              "from the LDraw(TM) Parts Library; see ATTRIBUTION.md.", "",
              "Help, About in the app names everyone whose work it is made with;",
              "THIRD-PARTY-NOTICES.txt carries their licences in full.", ""]
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


def tool_home(names: tuple[str, ...]) -> Path:
    """Where tools built or unpacked from [names] are kept: named by their
    pins, so a new pin builds afresh rather than using the last one's."""
    key = hashlib.sha256(json.dumps([TOOLS[name] for name in names]).encode()).hexdigest()
    return CACHE / ("%s-%s" % (key[:16], names[0]))


def dmg_tools() -> dict[str, Path]:
    """mkfs.hfsplus and fsck.hfsplus from hfsprogs, and libdmg-hfsplus's
    hfsplus and dmg, built once (about a minute) with zlib and bzip2 inside,
    so nothing of this machine's libraries is needed but the C library."""
    home = tool_home(("libdmg-hfsplus", "hfsprogs", "zlib", "bzip2"))
    tools = {"mkfs": home / "hfsprogs" / "sbin" / "mkfs.hfsplus",
             "fsck": home / "hfsprogs" / "sbin" / "fsck.hfsplus",
             "hfsplus": home / "bin" / "hfsplus", "dmg": home / "bin" / "dmg"}
    if all(path.exists() for path in tools.values()):
        return tools
    say("  building libdmg-hfsplus (once)")
    work = home.with_name(home.name + ".partial")
    shutil.rmtree(work, ignore_errors=True)
    (work / "bin").mkdir(parents=True)
    prefix = work / "prefix"
    (prefix / "include").mkdir(parents=True)
    (prefix / "lib").mkdir()
    subprocess.run(["dpkg-deb", "-x", str(fetch("hfsprogs")), str(work / "hfsprogs")], check=True)
    # Ubuntu 24.04 keeps them in usr/sbin; the paths above are what is run.
    for name in ("mkfs.hfsplus", "fsck.hfsplus"):
        found = next((work / "hfsprogs").rglob(name))
        (work / "hfsprogs" / "sbin").mkdir(exist_ok=True)
        if found.parent != work / "hfsprogs" / "sbin":
            shutil.copy2(found, work / "hfsprogs" / "sbin" / name)
    sources = work / "src"
    sources.mkdir()
    for name in ("zlib", "bzip2", "libdmg-hfsplus"):
        with tarfile.open(fetch(name)) as archive:
            archive.extractall(sources, filter="data")
    jobs = str(max(1, (os.cpu_count() or 2) // 4))

    def run(where: Path, *command: str, **env: str) -> None:
        done = subprocess.run(command, cwd=where, capture_output=True, text=True,
                              env=dict(os.environ, LC_ALL="C", **env))
        if done.returncode != 0:
            raise Failed("building the disk image tools: %s failed:\n%s"
                         % (" ".join(command[:3]), done.stderr[-2000:]))

    zlib = next(sources.glob("zlib-*"))
    run(zlib, "./configure", "--static", "--prefix=%s" % prefix, CFLAGS="-O2")
    run(zlib, "make", "-j", jobs, "libz.a")
    run(zlib, "make", "install")
    bzip2 = next(sources.glob("bzip2-*"))
    run(bzip2, "make", "-j", jobs, "libbz2.a", "CFLAGS=-O2 -D_FILE_OFFSET_BITS=64")
    shutil.copy2(bzip2 / "libbz2.a", prefix / "lib")
    shutil.copy2(bzip2 / "bzlib.h", prefix / "include")
    lib = next(sources.glob("libdmg-hfsplus-*"))
    flags = ["-O2", "-fno-strict-aliasing", "-I%s" % (lib / "includes"), "-I%s" % (prefix / "include")]
    hfs = [str(lib / "hfs" / (name + ".c")) for name in (
        "btree", "catalog", "extents", "xattr", "fastunicodecompare", "flatfile", "hfslib",
        "rawfile", "utility", "volume", "hfscompress")]
    common = [str(lib / "common" / (name + ".c")) for name in ("abstractfile", "base64")]
    dmg = [str(lib / "dmg" / (name + ".c")) for name in (
        "dmg", "adc", "attribution", "checksum", "compress", "dmgfile", "dmglib", "filevault",
        "io", "partition", "resources", "udif")]
    run(lib, "gcc", *flags, "-o", str(work / "bin" / "hfsplus"), str(lib / "hfs" / "hfs.c"),
        *hfs, *common, str(prefix / "lib" / "libz.a"))
    run(lib, "gcc", *flags, "-o", str(work / "bin" / "dmg"), *dmg, *hfs, *common,
        str(prefix / "lib" / "libz.a"), str(prefix / "lib" / "libbz2.a"), "-lpthread")
    shutil.rmtree(sources)
    shutil.rmtree(prefix)
    shutil.rmtree(home, ignore_errors=True)
    work.rename(home)
    return tools


def makensis() -> tuple[Path, dict[str, str]]:
    """makensis and the environment it runs in: Ubuntu's NSIS packages
    unpacked once, NSISDIR naming the data they keep in /usr/share/nsis."""
    home = tool_home(("nsis", "nsis-common"))
    program = home / "usr" / "bin" / "makensis"
    if not program.exists():
        work = home.with_name(home.name + ".partial")
        shutil.rmtree(work, ignore_errors=True)
        work.mkdir(parents=True)
        for name in ("nsis", "nsis-common"):
            subprocess.run(["dpkg-deb", "-x", str(fetch(name)), str(work)], check=True)
        work.rename(home)
    return program, {"NSISDIR": str(home / "usr" / "share" / "nsis")}


def zig() -> Path:
    """zig, unpacked once."""
    home = tool_home(("zig",))
    program = home / "zig"
    if not program.exists():
        work = home.with_name(home.name + ".partial")
        shutil.rmtree(work, ignore_errors=True)
        work.mkdir(parents=True)
        with tarfile.open(fetch("zig")) as archive:
            archive.extractall(work, filter="data")
        shutil.rmtree(home, ignore_errors=True)
        next(work.iterdir()).rename(home)
        shutil.rmtree(work)
    return program


# The program a Mac starts (CFBundleExecutable): it judges the GPU before
# Vulkan can abort on it, then becomes the app, Contents/MacOS/Brickworks
# (tools/release/package/launcher.c).
LAUNCHER = "launcher"


def build_launcher(target: Path) -> None:
    """The launcher as one universal binary, each slice for the oldest macOS
    the macOS preset's own slice runs on."""
    presets = (ROOT / "export_presets.cfg").read_text()
    oldest = dict(re.findall(r'application/min_macos_version_(x86_64|arm64)="([\d.]+)"', presets))
    compiler = zig()
    slices = []
    with tempfile.TemporaryDirectory() as scratch:
        cache = str(Path(scratch) / "cache")
        for arch, target_arch in (("x86_64", "x86_64"), ("arm64", "aarch64")):
            out = Path(scratch) / arch
            done = subprocess.run(
                [str(compiler), "cc", "-target", "%s-macos.%s" % (target_arch, oldest[arch]),
                 "-Os", "-Wall", "-Wextra", "-Werror", "-o", str(out),
                 str(ROOT / "tools" / "release" / "package" / "launcher.c")],
                capture_output=True, text=True,
                env=dict(os.environ, ZIG_GLOBAL_CACHE_DIR=cache, ZIG_LOCAL_CACHE_DIR=cache))
            if done.returncode != 0:
                raise Failed("building the launcher for %s:\n%s" % (arch, done.stderr[-2000:]))
            slices.append(out.read_bytes())
    target.write_bytes(fat_binary(slices))
    target.chmod(0o755)


def fat_binary(slices: list[bytes]) -> bytes:
    """Mach-O slices as one universal binary, as lipo joins them: each on a
    16 KB boundary, the page Apple silicon maps by."""
    align = 14
    out = bytearray(struct.pack(">II", 0xCAFEBABE, len(slices)))
    at = 1 << align
    placed = []
    for data in slices:
        cpu, subtype = struct.unpack("<ii", data[4:12])
        out += struct.pack(">iiIII", cpu, subtype, at, len(data), align)
        placed.append((at, data))
        at = (at + len(data) + (1 << align) - 1) & ~((1 << align) - 1)
    for offset, data in placed:
        out += b"\0" * (offset - len(out)) + data
    return bytes(out)


def launch_through(app: Path) -> None:
    """The launcher in, as the program a Mac starts. Before it is signed:
    the signature seals the Info.plist."""
    build_launcher(app / "Contents" / "MacOS" / LAUNCHER)
    path = app / "Contents" / "Info.plist"
    plist = plistlib.loads(path.read_bytes())
    plist["CFBundleExecutable"] = LAUNCHER
    path.write_bytes(plistlib.dumps(plist))


# -- each platform ----------------------------------------------------------

def build_linux(version: str, stamp: dict[str, str], out: Path, epoch: int) -> None:
    folder_name = "Brickworks-%s-linux-x86_64" % version
    work = WORK / "linux"
    shutil.rmtree(work, ignore_errors=True)
    folder = work / folder_name
    export("Linux", folder / "brickworks.x86_64")
    (folder / "brickworks.x86_64").chmod(0o755)
    shutil.copy2(PACKAGE_ART / "icons" / "512.png", folder / "brickworks.png")
    # For whoever installs the folder by hand: the icon beside it by name.
    (folder / "brickworks.desktop").write_text(desktop_entry("brickworks"))
    extras(folder, "linux", version, stamp["date"], {})
    tarball = out / (folder_name + ".tar.xz")
    write_tar_xz(folder, tarball, epoch)
    say("  %s, %s" % (tarball.name, human(tarball.stat().st_size)))

    # The AppImage: the same files, laid out the way appimagetool wants,
    # with the desktop entry, icons and MIME types a desktop takes it into
    # its menu and its file associations with (AppImageLauncher, Gear Lever,
    # appimaged read them from inside the image).
    appdir = work / "Brickworks.AppDir"
    (appdir / "usr" / "bin").mkdir(parents=True)
    (appdir / "usr" / "share" / "doc" / "brickworks").mkdir(parents=True)
    for name in ("brickworks.x86_64", "brickworks.pck"):
        os.link(folder / name, appdir / "usr" / "bin" / name)
    for name in ("README.txt", "ATTRIBUTION.md", "THIRD-PARTY-NOTICES.txt"):
        shutil.copy2(folder / name, appdir / "usr" / "share" / "doc" / "brickworks" / name)
    desktop_files(appdir / "usr" / "share", "brickworks", version)
    shutil.copy2(PACKAGE_ART / "icons" / "256.png", appdir / (APP_ID + ".png"))
    (appdir / ".DirIcon").symlink_to(APP_ID + ".png")
    shutil.copy2(appdir / "usr" / "share" / "applications" / (APP_ID + ".desktop"),
                 appdir / (APP_ID + ".desktop"))
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

    package = out / ("Brickworks-%s-linux-amd64.deb" % version)
    write_deb(folder, package, version, epoch)
    say("  %s, %s" % (package.name, human(package.stat().st_size)))


def desktop_entry(command: str = "brickworks", icon: str = "brickworks", version: str = "") -> str:
    """The menu entry: the app, the model files it opens (one window each,
    %f), and the window class that ties its windows to the entry."""
    return ("[Desktop Entry]\nType=Application\nName=Brickworks\nGenericName=Brick CAD\n"
            "Comment=A dimensionally exact brick construction system\n"
            "Exec=%s %%f\nIcon=%s\nTerminal=false\n"
            "Categories=Graphics;3DGraphics;Engineering;\n"
            "Keywords=CAD;LDraw;bricks;model;instructions;\n"
            "MimeType=%s;\nStartupWMClass=%s\n%s"
            % (command, icon, ";".join(kind["mime"] for kind in MODEL_TYPES), WINDOW_CLASS,
               "X-AppImage-Version=%s\n" % version if version else ""))


# The X11 window class Godot gives the app's windows, which StartupWMClass
# names so a dock groups them under the menu entry (measured under Xvfb).
WINDOW_CLASS = "Brickworks"


def mime_types() -> str:
    """The model files' MIME types, by their extensions. LDraw's are text and
    Studio's and LDD's are zips; a glob that names a subclass of what the
    content says wins over it, so a .ldr is a model and not plain text."""
    entries = []
    for kind in MODEL_TYPES:
        entries.append(
            '  <mime-type type="%s">\n    <comment>%s</comment>\n'
            '    <sub-class-of type="%s"/>\n    <generic-icon name="%s"/>\n'
            '    <glob pattern="*.%s"/>\n  </mime-type>\n'
            % (kind["mime"], kind["name"], "text/plain" if kind["text"] else "application/zip",
               APP_ID, kind["ext"]))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">\n'
            + "".join(entries) + "</mime-info>\n")


def desktop_files(share: Path, command: str, version: str = "") -> None:
    """What a desktop needs under share/ to put the app in its menu and open
    models in it: the entry, the icon at each size the theme has, and the
    MIME types. The .deb installs them; the AppImage carries them."""
    (share / "applications").mkdir(parents=True, exist_ok=True)
    (share / "applications" / (APP_ID + ".desktop")).write_text(
        desktop_entry(command, APP_ID, version))
    for png in sorted((PACKAGE_ART / "icons").glob("*.png")):
        size = int(png.stem)
        target = share / "icons" / "hicolor" / ("%dx%d" % (size, size)) / "apps" / (APP_ID + ".png")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(png, target)
    scalable = share / "icons" / "hicolor" / "scalable" / "apps" / (APP_ID + ".svg")
    scalable.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PACKAGE_ART / "icons" / "brickworks.svg", scalable)
    (share / "mime" / "packages").mkdir(parents=True, exist_ok=True)
    (share / "mime" / "packages" / (APP_ID + ".xml")).write_text(mime_types())


def thumbnailer_entry() -> str:
    """The thumbnailer entry: what runs, for which model files."""
    runner = THUMBNAIL_RUNNER.rsplit("/", 1)[-1]
    return ("[Thumbnailer Entry]\nTryExec=%s\nExec=%s %%i %%o %%s\nMimeType=%s;\n"
            % (runner, runner, ";".join(kind["mime"] for kind in MODEL_TYPES if kind["drawn"])))


def thumbnail_runner() -> str:
    """The script the entry runs: the app headless, drawing the model,
    with a data folder of its own (see THUMBNAILER)."""
    return ("#!/bin/sh\n"
            "# A file browser's picture of a Brickworks model: thumbnail MODEL PICTURE [SIZE].\n"
            "# The app draws it headless (--thumbnail) from a data folder of its own,\n"
            "# made here and removed after, so the app's own logs and settings stay as\n"
            "# they are.\n"
            "app=${0%/*}/../lib/brickworks/brickworks.x86_64\n"
            # A TMPDIR outside the sandbox (pam_tmpdir's /tmp/user/1000) is not
            # in it: /tmp is.
            "data=$(mktemp -d \"${TMPDIR:-/tmp}/brickworks-thumbnail.XXXXXX\" 2>/dev/null \\\n"
            "  || mktemp -d /tmp/brickworks-thumbnail.XXXXXX) || exit 1\n"
            "XDG_DATA_HOME=$data XDG_CONFIG_HOME=$data XDG_CACHE_HOME=$data \\\n"
            "  \"$app\" --headless --thumbnail \"$1\" \"$2\" \"${3:-256}\"\n"
            "code=$?\n"
            "rm -rf \"$data\"\n"
            "exit $code\n")


def write_deb(folder: Path, target: Path, version: str, epoch: int) -> None:
    """A .deb for Debian and Ubuntu: the app in /usr/lib/brickworks, run as
    brickworks, in the menu and opening models. No maintainer scripts:
    dpkg's triggers bring the menu, the icon cache and the MIME database
    up to date when it installs and when it is removed."""
    root = WORK / "deb"
    shutil.rmtree(root, ignore_errors=True)
    lib = root / "usr" / "lib" / "brickworks"
    lib.mkdir(parents=True)
    for name in ("brickworks.x86_64", "brickworks.pck"):
        os.link(folder / name, lib / name)
    (root / "usr" / "bin").mkdir()
    # Godot finds its .pck beside the program's real path, through the link.
    (root / "usr" / "bin" / "brickworks").symlink_to("../lib/brickworks/brickworks.x86_64")
    share = root / "usr" / "share"
    desktop_files(share, "brickworks")
    (root / THUMBNAILER).parent.mkdir(parents=True)
    (root / THUMBNAILER).write_text(thumbnailer_entry())
    (root / THUMBNAIL_RUNNER).write_text(thumbnail_runner())
    docs = share / "doc" / "brickworks"
    docs.mkdir(parents=True)
    for name in ("README.txt", "ATTRIBUTION.md", "THIRD-PARTY-NOTICES.txt"):
        shutil.copy2(folder / name, docs / name)
    (docs / "copyright").write_text(
        "Brickworks %s, https://brickworks.diy\n\nATTRIBUTION.md and THIRD-PARTY-NOTICES.txt "
        "beside this file name everyone whose work it is made with, and carry their "
        "licences in full.\n" % version)
    # The root too: its mode is the "./" entry, which dpkg has been known to
    # give the system's / (a group-writable / breaks sshd and sudo).
    for path in [root, *root.rglob("*")]:
        if not path.is_symlink():
            path.chmod(0o755 if path.is_dir() or path.name in (
                "brickworks.x86_64", "brickworks-thumbnailer") else 0o644)
    glibc = glibc_needed((folder / "brickworks.x86_64").read_bytes()) or "2.28"
    installed = sum(path.stat().st_size for path in root.rglob("*")
                    if path.is_file() and not path.is_symlink()) // 1024
    (root / "DEBIAN").mkdir()
    (root / "DEBIAN" / "control").write_text("\n".join([
        "Package: brickworks", "Version: %s" % version, "Architecture: amd64",
        "Maintainer: Brickworks <noreply@brickworks.diy>", "Installed-Size: %d" % installed,
        # The program needs the C library only: Godot opens the display,
        # sound and graphics libraries itself, whichever the desktop has.
        "Depends: libc6 (>= %s)" % glibc, "Recommends: libvulkan1 | libgl1",
        "Section: graphics", "Priority: optional", "Homepage: https://brickworks.diy",
        "Description: A dimensionally exact brick construction system",
        " Every part in the LDraw library at true size, building by hand or with",
        " Claude, and instructions and a parts list at the end. The whole part",
        " library is inside, so building needs no network.", ""]))
    target.unlink(missing_ok=True)
    env = dict(os.environ, SOURCE_DATE_EPOCH=str(epoch))
    done = subprocess.run(["dpkg-deb", "--root-owner-group", "-Zxz", "-z6", "--build", str(root),
                           str(target)], env=env, capture_output=True, text=True)
    if done.returncode != 0 or not target.exists():
        raise Failed("dpkg-deb failed: %s" % done.stderr.strip()[-600:])
    shutil.rmtree(root)


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
        # The launcher (launch_through) is what macOS starts, under the
        # hardened runtime and needing nothing more. The app it becomes keeps
        # what it had as the bundle's own program: that entitlement, the
        # runtime and the bundle's identifier, so its identity to macOS is
        # what 0.15.0's was.
        engine = "Contents/MacOS/Brickworks"
        identifier = plistlib.loads((app / "Contents" / "Info.plist").read_bytes())[
            "CFBundleIdentifier"]
        settings = ["--code-signature-flags", "runtime",
                    "--code-signature-flags", "%s:runtime" % engine,
                    "--entitlements-xml-file", "%s:%s" % (engine, entitlements),
                    "--binary-identifier", "%s:%s" % (engine, identifier)]
        if not p12:
            subprocess.run([str(rcodesign), "sign", *settings, str(app)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            say("  macOS: ad-hoc signed (no APPLE_SIGN_P12): first launch needs Open Anyway")
            return {"developer_id": False, "notarized": False}
        password = Path(private) / "p12-password"
        password.write_text(os.environ.get("APPLE_SIGN_P12_PASSWORD", ""))
        # --for-notarization turns on the hardened runtime and a secure
        # timestamp, and checks for what Apple's notary would refuse.
        subprocess.run([str(rcodesign), "sign", "--p12-file", p12, "--p12-password-file",
                        str(password), "--for-notarization", *settings, str(app)], check=True)
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


def sign_dmg(image: Path, signed: dict[str, bool]) -> None:
    """The disk image signed with the Developer ID and notarised, when the app
    in it was: Gatekeeper then opens it, and the app copied out of it, with
    no warning. Without one it goes out unsigned, which costs nothing: an
    ad-hoc signature on an image means nothing to Gatekeeper, and the app
    inside carries its own."""
    if not signed.get("developer_id"):
        return
    rcodesign = fetch("rcodesign")
    with tempfile.TemporaryDirectory() as private:
        password = Path(private) / "p12-password"
        password.write_text(os.environ.get("APPLE_SIGN_P12_PASSWORD", ""))
        subprocess.run([str(rcodesign), "sign", "--p12-file", os.environ["APPLE_SIGN_P12"],
                        "--p12-password-file", str(password), str(image)], check=True)
        say("  macOS: the disk image signed with the Developer ID")
        if not signed.get("notarized"):
            return
        key = Path(private) / "notary-key.json"
        subprocess.run([str(rcodesign), "encode-app-store-connect-api-key", "--output-path", str(key),
                        os.environ["APPLE_NOTARY_ISSUER"], os.environ["APPLE_NOTARY_KEY_ID"],
                        os.environ["APPLE_NOTARY_KEY"]], check=True)
        subprocess.run([str(rcodesign), "notary-submit", "--api-key-file", str(key), "--staple",
                        str(image)], check=True)
        say("  macOS: the disk image notarised and stapled")


def declare_types(app: Path) -> None:
    """The model files the app opens, in its Info.plist, so Finder offers it
    for them and opens a double-clicked one in it; and its category. Before
    it is signed: the signature seals the Info.plist."""
    path = app / "Contents" / "Info.plist"
    plist = plistlib.loads(path.read_bytes())
    # Godot's preset says Developer Tools; it is a CAD.
    plist["LSApplicationCategoryType"] = "public.app-category.graphics-design"
    plist["CFBundleDocumentTypes"] = [{
        "CFBundleTypeName": kind["name"],
        "CFBundleTypeRole": "Editor" if kind["claims"] else "Viewer",
        "LSHandlerRank": "Default" if kind["claims"] else "Alternate",
        "LSItemContentTypes": [kind["uti"]]} for kind in MODEL_TYPES]
    # Imported, not exported: these are LDraw's, Studio's and LDD's formats.
    plist["UTImportedTypeDeclarations"] = [{
        "UTTypeIdentifier": kind["uti"], "UTTypeDescription": kind["name"],
        "UTTypeConformsTo": ["public.plain-text"] if kind["text"] else ["public.data"],
        "UTTypeTagSpecification": {"public.filename-extension": [kind["ext"]],
                                   "public.mime-type": [kind["mime"]]}} for kind in MODEL_TYPES]
    path.write_bytes(plistlib.dumps(plist))


def write_tiff(pictures: list[tuple[bytes, int]], target: Path) -> None:
    """RGB PNGs as one TIFF, a page each at its resolution: what Finder wants
    for a window's background, the 2x page for a Retina screen (what
    tiffutil -cathidpicheck makes on a Mac)."""
    pages = []
    for data, dpi in pictures:
        channels, rows = png_rows(data)
        if channels not in (3, 4) or not rows:
            raise Failed("a disk image background must be an 8-bit RGB PNG")
        width = len(rows[0]) // channels
        pixels = b"".join(bytes(row) if channels == 3 else
                          bytes(b for at in range(0, len(row), 4) for b in row[at:at + 3])
                          for row in rows)
        pages.append((width, len(rows), zlib.compress(pixels, 9), dpi))
    out = bytearray(b"II*\0\0\0\0\0")
    link = 4
    for width, height, strip, dpi in pages:
        strip_at = len(out)
        out += strip + b"\0" * (len(strip) % 2)
        extra = len(out)
        out += struct.pack("<HHH", 8, 8, 8) + struct.pack("<IIII", dpi, 1, dpi, 1)
        tags = [(256, 4, 1, width), (257, 4, 1, height), (258, 3, 3, extra),
                (259, 3, 1, 8), (262, 3, 1, 2), (273, 4, 1, strip_at), (277, 3, 1, 3),
                (278, 4, 1, height), (279, 4, 1, len(strip)), (282, 5, 1, extra + 6),
                (283, 5, 1, extra + 14), (284, 3, 1, 1), (296, 3, 1, 2)]
        struct.pack_into("<I", out, link, len(out))
        out += struct.pack("<H", len(tags))
        for tag, kind, count, value in tags:
            out += struct.pack("<HHI", tag, kind, count)
            out += struct.pack("<HH", value, 0) if kind == 3 and count == 1 else struct.pack("<I", value)
        link = len(out)
        out += b"\0\0\0\0"
    target.write_bytes(bytes(out))


# The disk image's window (tools/release/package/dmg-background.svg): its
# size in points, and where each icon's middle is.
DMG_WINDOW = (640, 400)
DMG_ICONS = {"Brickworks.app": (160, 176), "Applications": (480, 176)}


def dmg_layout(target: Path, volume: str, created: dt.datetime, folder_cnid: int,
               cnid: int) -> None:
    """The .DS_Store that makes the image's window what people expect: the
    app and Applications side by side at 128 points over the background
    picture, no toolbar or sidebar, the window the picture's size. Finder
    finds the picture by an alias, written here as a Mac would write it
    for /Volumes/<volume>/.background/background.tiff (Alias.for_file is
    macOS's only)."""
    for wheel in ("mac_alias", "ds_store"):
        path = str(fetch(wheel))
        if path not in sys.path:
            sys.path.insert(0, path)
    from ds_store import DSStore  # type: ignore[import-not-found]
    from mac_alias import (ALIAS_FIXED_DISK, ALIAS_KIND_FILE, Alias,  # type: ignore[import-not-found]
                           TargetInfo, VolumeInfo)
    alias = Alias()
    alias.volume = VolumeInfo(volume.encode(), created, b"H+", ALIAS_FIXED_DISK, 0, b"\0\0")
    alias.volume.posix_path = ("/Volumes/" + volume).encode()
    alias.target = TargetInfo(ALIAS_KIND_FILE, b"background.tiff", folder_cnid, cnid, created,
                              b"\0\0\0\0", b"\0\0\0\0")
    alias.target.folder_name = b".background"
    alias.target.cnid_path = [folder_cnid]
    alias.target.carbon_path = ("%s:.background:\0background.tiff" % volume).encode()
    alias.target.posix_path = b"/.background/background.tiff"
    width, height = DMG_WINDOW
    target.unlink(missing_ok=True)
    with DSStore.open(str(target), "w+") as store:
        # The window's frame: the picture, and the title bar above it.
        store["."]["bwsp"] = {
            "WindowBounds": "{{200, 120}, {%d, %d}}" % (width, height + 28),
            "ShowToolbar": False, "ShowSidebar": False, "ContainerShowSidebar": False,
            "ShowStatusBar": False, "ShowPathbar": False, "ShowTabView": False,
            "PreviewPaneVisibility": False, "SidebarWidth": 0}
        store["."]["icvp"] = {
            "viewOptionsVersion": 1, "backgroundType": 2,
            "backgroundImageAlias": alias.to_bytes(),
            "backgroundColorRed": 1.0, "backgroundColorGreen": 1.0, "backgroundColorBlue": 1.0,
            "iconSize": 128.0, "textSize": 13.0, "labelOnBottom": True, "arrangeBy": "none",
            "gridSpacing": 100.0, "gridOffsetX": 0.0, "gridOffsetY": 0.0,
            "showIconPreview": False, "showItemInfo": False,
            "scrollPositionX": 0.0, "scrollPositionY": 0.0}
        store["."]["vSrn"] = ("long", 1)
        store["."]["icvl"] = ("type", b"icnv")
        for name, (x, y) in DMG_ICONS.items():
            store[name]["Iloc"] = (x, y)


def hfs_header(volume: Path) -> tuple[dt.datetime, int]:
    """An HFS+ volume's creation date and the next catalog node id it gives."""
    with volume.open("rb") as handle:
        handle.seek(1024)
        header = handle.read(128)
    if header[:2] != b"H+":
        raise Failed("%s is not an HFS+ volume" % volume)
    # Seconds since 1904, in local time: the one HFS+ date that is not UTC.
    # Kept as the same count of seconds (mac_alias counts from a UTC 1904),
    # which is what an alias to the volume must say to match it.
    created = dt.datetime(1904, 1, 1, tzinfo=dt.timezone.utc) + dt.timedelta(
        seconds=struct.unpack(">I", header[16:20])[0])
    return created, struct.unpack(">I", header[64:68])[0]


def write_dmg(app: Path, target: Path, volume: str = "Brickworks") -> None:
    """The app and an Applications link in a compressed disk image, laid out
    for dragging one onto the other: the background with its arrow, the
    app's icon on the volume, the window its size. Read back before it is
    kept: the volume byte for byte, fsck.hfsplus's word on it, and every
    file, mode and link the app has."""
    tools = dmg_tools()
    work = WORK / "dmg"
    shutil.rmtree(work, ignore_errors=True)
    stage = work / "stage"
    stage.mkdir(parents=True)
    shutil.copytree(app, stage / app.name, symlinks=True, copy_function=link_or_copy)
    want = tree_of(stage)
    shutil.copy2(app / "Contents" / "Resources" / "icon.icns", stage / ".VolumeIcon.icns")
    background = work / "background.tiff"
    write_tiff([((PACKAGE_ART / "dmg-background.png").read_bytes(), 72),
                ((PACKAGE_ART / "dmg-background@2x.png").read_bytes(), 144)], background)

    size = sum(path.stat().st_size + 4096 for path in stage.rglob("*") if path.is_file())
    hfs = work / "volume.hfs"
    with hfs.open("wb") as handle:
        handle.truncate((int(size * 1.02) // (1 << 20) + 16) << 20)

    def run(*command: str) -> str:
        done = subprocess.run([str(c) for c in command], capture_output=True, text=True)
        if done.returncode != 0:
            raise Failed("%s %s failed: %s" % (Path(command[0]).name, command[2] if len(command) > 2
                                               else "", (done.stderr or done.stdout).strip()[-800:]))
        return done.stdout

    run(tools["mkfs"], "-v", volume, hfs)
    created, next_id = hfs_header(hfs)
    # The background first, so its folder and file take the next two ids,
    # which the layout's alias names.
    run(tools["hfsplus"], hfs, "mkdir", "/.background")
    run(tools["hfsplus"], hfs, "add", background, "/.background/background.tiff")
    dmg_layout(stage / ".DS_Store", volume, created, next_id, next_id + 1)
    # Links stay links, and no mode is changed: the app's seal covers both.
    run(tools["hfsplus"], hfs, "addall", stage, "--symlinks=clone_link", "--special-modes=no")
    run(tools["hfsplus"], hfs, "symlink", "/Applications", "/Applications")
    # The volume shows the app's icon (.VolumeIcon.icns), not a blank disk.
    run(tools["hfsplus"], hfs, "attr", "/", "C")
    target.unlink(missing_ok=True)
    # bzip2, not lzma: an image in lzma does not open before macOS 10.15, and
    # the app runs from 10.13 on an Intel Mac.
    run(tools["dmg"], "build", hfs, target, "--compression", "bzip2", "--level", "9",
        "--run-sectors", "2048")

    # dmg can exit 0 and leave no image.
    with target.open("rb") as handle:
        handle.seek(-512, os.SEEK_END)
        if handle.read(4) != b"koly":
            raise Failed("%s has no UDIF trailer: dmg build failed" % target.name)
    back = work / "back.hfs"
    run(tools["dmg"], "extract", target, back)
    if sha256_of(back) != sha256_of(hfs):
        raise Failed("%s does not hold the volume it was made from" % target.name)
    hfs.unlink()
    checked = run(tools["fsck"], "-f", "-n", back)
    if "appears to be OK" not in checked:
        raise Failed("fsck.hfsplus on %s: %s" % (target.name, checked.strip()[-400:]))
    out = work / "out"
    out.mkdir()
    run(tools["hfsplus"], back, "extractall", "/", out)
    got = tree_of(out)
    link = got.pop("Applications", None)
    for hidden in (".DS_Store", ".VolumeIcon.icns", ".background", ".background/background.tiff"):
        if hidden not in got:
            raise Failed("%s has no %s" % (target.name, hidden))
        del got[hidden]
    differ = [path for path in sorted(set(want) | set(got)) if want.get(path) != got.get(path)]
    if link != ("link", "/Applications"):
        differ.append("Applications is not a link to /Applications")
    if differ:
        raise Failed("%s is not the app: %s" % (target.name, ", ".join(differ[:8])))
    shutil.rmtree(work)


def tree_of(folder: Path) -> dict[str, tuple[str, str]]:
    """Every file, folder and link under [folder]: its kind and its mode, its
    target or its SHA-256."""
    found: dict[str, tuple[str, str]] = {}
    for path in sorted(folder.rglob("*")):
        name = path.relative_to(folder).as_posix()
        if path.is_symlink():
            found[name] = ("link", os.readlink(path))
        elif path.is_dir():
            found[name] = ("dir", oct(path.stat().st_mode & 0o7777))
        else:
            found[name] = ("file", "%s %s" % (oct(path.stat().st_mode & 0o7777), sha256_of(path)))
    return found


def build_mac(version: str, stamp: dict[str, str], out: Path, epoch: int) -> dict[str, bool]:
    folder_name = "Brickworks-%s-macos" % version
    work = WORK / "mac"
    shutil.rmtree(work, ignore_errors=True)
    folder = work / folder_name
    export("macOS", folder / "Brickworks.app")
    # The licences inside the app, where they go with it to Applications: the
    # disk image holds the app and nothing beside it.
    resources = folder / "Brickworks.app" / "Contents" / "Resources"
    shutil.copy2(STAGE / "docs" / "ATTRIBUTION.md", resources / "ATTRIBUTION.md")
    shutil.copy2(WORK / "THIRD-PARTY-NOTICES.txt", resources / "THIRD-PARTY-NOTICES.txt")
    declare_types(folder / "Brickworks.app")
    launch_through(folder / "Brickworks.app")
    signed = sign_mac(folder / "Brickworks.app")
    image = out / ("Brickworks-%s-macos-universal.dmg" % version)
    write_dmg(folder / "Brickworks.app", image)
    sign_dmg(image, signed)
    say("  %s, %s" % (image.name, human(image.stat().st_size)))
    # The zip people had before the image, kept for one release so links
    # already shared keep working (docs/DISTRIBUTION.md).
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
    installer = out / (folder_name + "-setup.exe")
    write_installer(folder, installer, version, command)
    say("  %s, %s" % (installer.name, human(installer.stat().st_size)))
    # The zip people had before the installer, kept for one release so links
    # already shared keep working (docs/DISTRIBUTION.md).
    package = out / (folder_name + ".zip")
    write_zip(folder, package, epoch)
    say("  %s, %s" % (package.name, human(package.stat().st_size)))
    return signed


def write_ico(target: Path, sizes: tuple[int, ...] = (16, 24, 32, 48, 64, 256)) -> None:
    """The icon's PNGs in one .ico, each kept as a PNG, which Windows has
    read at every size since Vista."""
    pictures = [(size, (PACKAGE_ART / "icons" / ("%d.png" % size)).read_bytes()) for size in sizes]
    head = struct.pack("<HHH", 0, 1, len(pictures))
    at = 6 + 16 * len(pictures)
    for size, data in pictures:
        head += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(data), at)
        at += len(data)
    target.write_bytes(head + b"".join(data for _, data in pictures))


def write_installer(folder: Path, target: Path, version: str, sign: str) -> None:
    """The per-user installer (tools/release/windows/brickworks.nsi), made by
    makensis here. [sign] is WINDOWS_SIGN_COMMAND, which signs the
    uninstaller as it is written and the installer once it is made."""
    program, env = makensis()
    work = WORK / "nsis"
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    write_ico(work / "brickworks.ico")
    # What an update deletes before it copies, and an uninstall after: the
    # release folder's files by name, so neither touches anything else in a
    # folder the person chose.
    files = sorted(path.relative_to(folder) for path in folder.rglob("*") if path.is_file())
    folders = sorted({p for path in files for p in path.parents if p != Path(".")},
                     key=lambda p: -len(p.parts))
    (work / "installed.nsh").write_text("".join(
        ['Delete "$INSTDIR\\%s"\n' % str(path).replace("/", "\\") for path in files]
        + ['RMDir "$INSTDIR\\%s"\n' % str(path).replace("/", "\\") for path in folders]))
    numbers = re.match(r"(\d+)\.(\d+)\.(\d+)", version)
    if numbers is None:
        raise Failed("%s has no X.Y.Z for the installer's version" % version)
    command = [str(program), "-INPUTCHARSET", "UTF8", "-V2",
               "-DVERSION=%s" % version, "-DVERSION4=%s.0" % ".".join(numbers.groups()),
               "-DSOURCE=%s" % folder, "-DOUTFILE=%s" % target,
               "-DICON=%s" % (work / "brickworks.ico"), "-DINSTALLED=%s" % (work / "installed.nsh")]
    if sign:
        command.append("-DSIGN=%s" % sign.replace("{file}", '"%1"'))
    command.append(str(ROOT / "tools" / "release" / "windows" / "brickworks.nsi"))
    target.unlink(missing_ok=True)
    log = WORK / "makensis.log"
    started = time.time()
    with log.open("w") as handle:
        code = subprocess.run(command, env=dict(os.environ, **env), stdout=handle,
                              stderr=subprocess.STDOUT).returncode
    if code != 0 or not target.exists():
        tail = log.read_text(errors="replace").strip().splitlines()[-12:]
        raise Failed("makensis failed (exit %d), see %s:\n  %s" % (code, log, "\n  ".join(tail)))
    if sign and not pe_facts(target.read_bytes())["signed"]:
        raise Failed("WINDOWS_SIGN_COMMAND ran but %s carries no signature" % target.name)
    say("  made the installer in %.0f s" % (time.time() - started))


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
    return {"machine": {0x8664: "x86_64", 0xAA64: "arm64", 0x14C: "x86"}.get(machine, hex(machine)),
            "subsystem": {2: "window", 3: "console"}.get(subsystem, str(subsystem)),
            "version": version, "signed": security_size > 0}


def glibc_needed(data: bytes) -> str:
    versions = {tuple(int(n) for n in m.groups()) for m in re.finditer(rb"GLIBC_(\d+)\.(\d+)", data)}
    return "%d.%d" % max(versions) if versions else ""


def inspect_tar(path: Path) -> dict[str, Any]:
    # One pass through the stream, each file read as it is reached: a read
    # back from the end decompresses the whole archive again.
    members = []
    binary = None
    data = b""
    beside: dict[str, bytes] = {}
    with tarfile.open(path) as archive:
        for member in archive:
            members.append(member)
            leaf = member.name.split("/", 1)[-1]
            if member.name.endswith("/brickworks.x86_64") or leaf in LICENCE_FILES:
                handle = archive.extractfile(member)
                read = handle.read() if handle else b""
                if leaf in LICENCE_FILES:
                    beside[leaf] = read
                else:
                    binary, data = member, read
    if binary is None:
        raise Failed("%s has no brickworks.x86_64" % path.name)
    tops = {member.name.split("/")[0] for member in members}
    names = sorted(member.name.split("/", 1)[1] for member in members if "/" in member.name)
    return {"folder": sorted(tops), "contents": names,
            "executable": bool(binary.mode & 0o111), "glibc": glibc_needed(data),
            "unpacked": sum(member.size for member in members),
            "licences": licences(beside.get)}


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

        def read(name: str) -> bytes | None:
            got = subprocess.run(["unsquashfs", "-o", str(squash), "-cat", str(path),
                                  "usr/share/doc/brickworks/" + name], capture_output=True)
            return got.stdout if got.returncode == 0 else None
        facts["licences"] = licences(read)
    return facts


def inspect_mac(path: Path) -> dict[str, Any]:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        prefix = next(name for name in names if name.endswith("Brickworks.app/"))
        beside = prefix[:-len("Brickworks.app/")]
        texts = licences(lambda name: archive.read(beside + name)
                         if beside + name in names else None)
        plist = plistlib.loads(archive.read(prefix + "Contents/Info.plist"))
        binary = prefix + "Contents/MacOS/Brickworks"
        facts = macho_facts(archive.read(binary))
        starts = prefix + "Contents/MacOS/" + plist.get("CFBundleExecutable", "")
        facts["launcher"] = macho_facts(archive.read(starts)) \
            if starts != binary and starts in names else {}
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
        "licences": texts,
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
        tops = sorted({name.split("/")[0] for name in names})
        texts = licences(lambda name: archive.read(tops[0] + "/" + name)
                         if len(tops) == 1 and tops[0] + "/" + name in names else None)
    return {"top": tops,
            "contents": sorted(name.split("/", 1)[1] for name in names
                               if "/" in name and name.split("/", 1)[1]),
            "exes": exes, "unpacked": unpacked, "licences": texts}


def ar_members(path: Path) -> dict[str, tuple[int, int]]:
    """A .deb's members (an ar archive): where each starts and its size."""
    found = {}
    with path.open("rb") as handle:
        if handle.read(8) != b"!<arch>\n":
            raise Failed("%s is not a .deb (no ar header)" % path.name)
        while True:
            head = handle.read(60)
            if len(head) < 60:
                return found
            name, size = head[:16].decode().strip().rstrip("/"), int(head[48:58])
            found[name] = (handle.tell(), size)
            handle.seek(size + size % 2, os.SEEK_CUR)


class Slice:
    """Part of a file, read as a file: a .deb member, streamed into tarfile."""

    def __init__(self, path: Path, start: int, size: int) -> None:
        self.handle = path.open("rb")
        self.handle.seek(start)
        self.left = size

    def read(self, size: int = -1) -> bytes:
        size = self.left if size < 0 else min(size, self.left)
        data = self.handle.read(size)
        self.left -= len(data)
        return data

    def close(self) -> None:
        self.handle.close()


def inspect_deb(path: Path) -> dict[str, Any]:
    members = ar_members(path)
    control_name = next(name for name in members if name.startswith("control.tar"))
    data_name = next(name for name in members if name.startswith("data.tar"))
    control = Slice(path, *members[control_name])
    with tarfile.open(fileobj=control, mode="r|*") as archive:  # type: ignore[call-overload]
        fields = {}
        for member in archive:
            if member.name.lstrip("./") == "control":
                handle = archive.extractfile(member)
                text = handle.read().decode() if handle else ""
                fields = dict(line.split(": ", 1) for line in text.splitlines()
                              if ": " in line and not line.startswith(" "))
    control.close()
    contents, links, beside, loose = [], {}, {}, []
    binary, data = None, b""
    wanted = {"usr/lib/brickworks/brickworks.x86_64",
              "usr/share/applications/%s.desktop" % APP_ID,
              "usr/share/mime/packages/%s.xml" % APP_ID, THUMBNAILER, THUMBNAIL_RUNNER}
    runnable = set()
    stream = Slice(path, *members[data_name])
    # One pass, each file read as it is reached (inspect_tar).
    with tarfile.open(fileobj=stream, mode="r|*") as archive:  # type: ignore[call-overload]
        for member in archive:
            name = member.name.lstrip("./")
            contents.append(name)
            # dpkg gives these to the system's own folders, "./" to / itself.
            if (member.isdir() and member.mode & 0o7777 != 0o755) or (member.uid, member.gid) != (0, 0):
                loose.append("%s %o %d:%d" % (name or "/", member.mode, member.uid, member.gid))
            if member.issym():
                links[name] = member.linkname
            if member.isfile() and member.mode & 0o111:
                runnable.add(name)
            leaf = name.rsplit("/", 1)[-1]
            if name in wanted or (name.startswith("usr/share/doc/brickworks/")
                                  and leaf in LICENCE_FILES):
                handle = archive.extractfile(member)
                read = handle.read() if handle else b""
                if leaf in LICENCE_FILES:
                    beside[leaf] = read
                elif name.endswith(".x86_64"):
                    binary, data = member, read
                else:
                    beside[name] = read
    stream.close()
    if binary is None:
        raise Failed("%s has no usr/lib/brickworks/brickworks.x86_64" % path.name)
    entry = beside.get("usr/share/applications/%s.desktop" % APP_ID, b"").decode()
    return {"package": fields.get("Package", ""), "version": fields.get("Version", ""),
            "architecture": fields.get("Architecture", ""), "depends": fields.get("Depends", ""),
            "unpacked": int(fields.get("Installed-Size", "0")) * 1024,
            "executable": bool(binary.mode & 0o111), "glibc": glibc_needed(data),
            "command": links.get("usr/bin/brickworks", ""),
            "opens": [kind["ext"] for kind in MODEL_TYPES if kind["mime"] in entry
                      and ('"*.%s"' % kind["ext"]) in beside.get(
                          "usr/share/mime/packages/%s.xml" % APP_ID, b"").decode()],
            "icons": sorted(name.split("/")[4] for name in contents
                            if name.startswith("usr/share/icons/hicolor/")
                            and name.endswith("/apps/%s.png" % APP_ID)),
            "thumbnails": thumbnailed(beside.get(THUMBNAILER, b"").decode(),
                                      beside.get(THUMBNAIL_RUNNER, b"").decode(),
                                      THUMBNAIL_RUNNER in runnable),
            "contents": [name for name in contents if not name.endswith("/")],
            "loose": loose, "licences": licences(beside.get)}


def thumbnailed(entry: str, runner: str, runs: bool) -> list[str]:
    """The model files a .deb's thumbnailer draws, by extension: those its
    entry names, when the entry runs the runner it carries, executable, and
    the runner asks the app for a picture."""
    fields = dict(line.split("=", 1) for line in entry.splitlines() if "=" in line)
    runner_name = THUMBNAIL_RUNNER.rsplit("/", 1)[-1]
    if not (runs and fields.get("Exec", "").startswith(runner_name + " ")
            and fields.get("TryExec") == runner_name
            and "--thumbnail" in runner and runner.startswith("#!/bin/sh")):
        return []
    named = fields.get("MimeType", "").split(";")
    return [kind["ext"] for kind in MODEL_TYPES if kind["mime"] in named]


def dmg_reader(path: Path, into: Path) -> tuple[Callable[[str], bytes | None], int]:
    """A disk image's files by their path on the volume (a link's target for
    a link), and how much its files take: hdiutil mounts it on a Mac,
    libdmg-hfsplus reads it elsewhere."""
    if sys.platform == "darwin":
        mount = into / "volume"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount),
                        str(path)], check=True, capture_output=True)

        def read_mounted(name: str) -> bytes | None:
            target = mount / name
            if target.is_symlink():
                return os.readlink(target).encode()
            return target.read_bytes() if target.is_file() else None
        used = sum(p.lstat().st_size for p in mount.rglob("*") if not p.is_dir())
        return read_mounted, used
    tools = dmg_tools()
    volume = into / "volume.hfs"
    subprocess.run([str(tools["dmg"]), "extract", str(path), str(volume)], check=True,
                   capture_output=True)

    def listing(folder: str) -> tuple[dict[str, tuple[str, int]], int]:
        said = subprocess.run([str(tools["hfsplus"]), str(volume), "ls", folder],
                              capture_output=True, text=True).stdout
        entries = {}
        for line in said.splitlines():
            found = re.match(r"(\d{6})\s+\d+\s+\d+\s+(\d+)\s+\d+/\s*\d+/\d+\s+\d+:\d+\s(.+)$", line)
            if found:
                entries[found.group(3)] = (found.group(1), int(found.group(2)))
        total = re.search(r"Total filesystem size: (\d+)", said)
        return entries, int(total.group(1)) if total else 0

    def read_extracted(name: str) -> bytes | None:
        folder, _, leaf = ("/" + name).rpartition("/")
        mode, size = listing(folder or "/")[0].get(leaf, ("", 0))
        if mode.startswith("12"):
            # hfsplus follows a link and cannot read one that leaves the
            # volume (/Applications): its length is all it gives here.
            # write_dmg read the target back when it made the image.
            return b"/Applications" if size == len(b"/Applications") else b"?"
        got = subprocess.run([str(tools["hfsplus"]), str(volume), "cat", "/" + name],
                             capture_output=True)
        return got.stdout if got.returncode == 0 and got.stdout else None
    return read_extracted, listing("/")[1]


def inspect_dmg(path: Path) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="brickworks-dmg-", dir=WORK if WORK.exists()
                                     else None) as scratch:
        read, used = dmg_reader(path, Path(scratch))
        try:
            app = "Brickworks.app/Contents/"
            plist = plistlib.loads(read(app + "Info.plist") or b"")
            facts = macho_facts(read(app + "MacOS/Brickworks") or b"")
            starts = plist.get("CFBundleExecutable", "Brickworks")
            launcher = read(app + "MacOS/" + starts) if starts != "Brickworks" else None
            facts["launcher"] = macho_facts(launcher) if launcher else {}
            facts.update({
                "bundle": "Brickworks.app", "unpacked": used,
                "version": plist.get("CFBundleShortVersionString", ""),
                "build": plist.get("CFBundleVersion", ""),
                "identifier": plist.get("CFBundleIdentifier", ""),
                "opens": [ext for t in plist.get("CFBundleDocumentTypes", [])
                          for d in plist.get("UTImportedTypeDeclarations", [])
                          if d["UTTypeIdentifier"] in t.get("LSItemContentTypes", [])
                          for ext in d["UTTypeTagSpecification"]["public.filename-extension"]],
                "sealed": read(app + "_CodeSignature/CodeResources") is not None,
                "stapled": read(app + "CodeResources") is not None,
                "pck": read(app + "Resources/Brickworks.pck") is not None,
                "applications": (read("Applications") or b"").decode(errors="replace"),
                "volume_icon": read(".VolumeIcon.icns") is not None,
                "layout": read(".DS_Store") is not None
                and read(".background/background.tiff") is not None,
                "licences": licences(lambda name: read(app + "Resources/" + name)),
            })
        finally:
            if sys.platform == "darwin":
                subprocess.run(["hdiutil", "detach", str(Path(scratch) / "volume")],
                               capture_output=True)
    with path.open("rb") as handle:
        handle.seek(-512, os.SEEK_END)
        koly = handle.read(512)
    # The trailer's code signature (its offset and size at 0x128 and 0x130),
    # where rcodesign puts the image's own.
    facts["image_signed"] = koly[:4] == b"koly" and struct.unpack(">Q", koly[0x130:0x138])[0] > 0
    return facts


def inspect_installer(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    setup = pe_facts(data)
    return {"exes": {path.name: setup}, "nsis": b"NullsoftInst" in data}


def say_launcher(name: str, facts: dict[str, Any]) -> None:
    """The launcher a Mac starts, read back: there, universal and signed, or
    the package fails. Without it an Intel Mac whose GPU MoltenVK cannot
    use closes the app at once (launch_through)."""
    launcher = facts.get("launcher") or {}
    if not launcher:
        raise Failed("%s starts the app itself, not through its launcher" % name)
    say("      launcher: architectures %s; oldest macOS %s; signature %s" % (
        " + ".join(launcher["architectures"]), launcher["min_macos"], launcher["signature"]))
    if sorted(launcher["architectures"]) != ["arm64", "x86_64"]:
        raise Failed("%s: the launcher is not universal: %s" % (name, launcher["architectures"]))
    unsigned = [s for s in launcher["signature"].values() if s == "none" or s.startswith("invalid")]
    if unsigned:
        raise Failed("%s: the launcher is not validly signed (%s)" % (name, unsigned[0]))


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
            say_licences(path.name, facts["licences"])
            if not facts["executable"]:
                raise Failed("%s: the binary lost its executable bit" % path.name)
        elif path.name.endswith(".AppImage"):
            facts = inspect_appimage(path)
            say("  %s  %s; ELF %s, executable %s" % (path.name, human(entry["size"]),
                "yes" if facts["elf"] else "NO", "yes" if facts["executable"] else "NO"))
            if facts.get("contents"):
                say("      " + ", ".join(facts["contents"]))
                say_licences(path.name, facts["licences"])
        elif path.name.endswith(".deb"):
            facts = inspect_deb(path)
            say("  %s  %s, %s %s %s, installs %s; executable %s; glibc %s or newer" % (
                path.name, human(entry["size"]), facts["package"], facts["version"],
                facts["architecture"], human(facts["unpacked"]),
                "yes" if facts["executable"] else "NO", facts["glibc"]))
            say("      brickworks -> %s; opens %s; pictures of %s; icons %s" % (
                facts["command"], ", ".join(facts["opens"]) or "nothing",
                ", ".join(facts["thumbnails"]) or "nothing", " ".join(facts["icons"])))
            say_licences(path.name, facts["licences"])
            if facts["version"] != version or not facts["executable"] or not facts["command"]:
                raise Failed("%s: version %s, executable %s, command %r" % (
                    path.name, facts["version"], facts["executable"], facts["command"]))
            if sorted(facts["opens"]) != sorted(kind["ext"] for kind in MODEL_TYPES):
                raise Failed("%s opens only %s" % (path.name, facts["opens"]))
            if facts["thumbnails"] != [kind["ext"] for kind in MODEL_TYPES if kind["drawn"]]:
                raise Failed("%s's thumbnailer draws only %s" % (path.name, facts["thumbnails"]))
            if facts["loose"]:
                raise Failed("%s would install these other than 0755 root: %s" % (
                    path.name, ", ".join(facts["loose"][:5])))
        elif path.name.endswith(".dmg"):
            facts = inspect_dmg(path)
            say("  %s  %s; %s %s (build %s), %s; architectures %s; oldest macOS %s" % (
                path.name, human(entry["size"]), facts["bundle"], facts["version"],
                facts["build"], facts["identifier"], " + ".join(facts["architectures"]),
                facts["min_macos"]))
            say("      signature %s; sealed %s; notarisation ticket %s; pck inside %s; image "
                "signed %s" % (facts["signature"], facts["sealed"], facts["stapled"], facts["pck"],
                               facts["image_signed"]))
            say("      Applications -> %s; volume icon %s; window laid out %s; opens %s" % (
                facts["applications"], facts["volume_icon"], facts["layout"],
                ", ".join(facts["opens"]) or "nothing"))
            say_launcher(path.name, facts)
            say_licences(path.name, facts["licences"])
            if facts["version"] != version:
                raise Failed("%s says it is %s" % (path.name, facts["version"]))
            if sorted(facts["architectures"]) != ["arm64", "x86_64"]:
                raise Failed("%s is not universal: %s" % (path.name, facts["architectures"]))
            if facts["applications"] != "/Applications" or not facts["pck"]:
                raise Failed("%s: no Applications link or no pck" % path.name)
            if sorted(facts["opens"]) != sorted(kind["ext"] for kind in MODEL_TYPES):
                raise Failed("%s opens only %s" % (path.name, facts["opens"]))
        elif path.name.endswith("-setup.exe"):
            facts = inspect_installer(path)
            setup = facts["exes"][path.name]
            say("  %s  %s; %s, %s, version %s, %s; NSIS %s" % (
                path.name, human(entry["size"]), setup["machine"], setup["subsystem"],
                setup["version"], "signed" if setup["signed"] else "unsigned", facts["nsis"]))
            if setup["version"] != version or not facts["nsis"]:
                raise Failed("%s says version %r, NSIS %s" % (path.name, setup["version"],
                                                              facts["nsis"]))
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
            say_launcher(path.name, facts)
            say_licences(path.name, facts["licences"])
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
            say_licences(path.name, facts["licences"])
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

# Where the Windows installer puts the app, for the person running it.
WINDOWS_INSTALLED = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Brickworks"


def unpack(package: Path, into: Path) -> Path:
    """Unpacked or installed the way a person's system would, and the program
    to run."""
    name = package.name
    if name.endswith(".AppImage"):
        target = into / name
        shutil.copy2(package, target)
        target.chmod(0o755)
        return target
    if name.endswith(".tar.xz"):
        subprocess.run(["tar", "-xf", str(package), "-C", str(into)], check=True)
        return next(into.glob("*/brickworks.x86_64"))
    if name.endswith(".deb"):
        # The files dpkg installs, under a folder of their own rather than
        # /, which needs no root; opens_models tells a desktop about them as
        # dpkg's triggers do.
        subprocess.run(["dpkg-deb", "-x", str(package), str(into / "root")], check=True)
        return into / "root" / "usr" / "bin" / "brickworks"
    if name.endswith(".dmg"):
        if sys.platform != "darwin":
            raise Failed("a disk image runs on a Mac: tools/release.py inspect reads one here")
        mount = into / "volume"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount),
                        str(package)], check=True, capture_output=True)
        # Dragged onto Applications, as its window says: Finder copies the
        # bundle as ditto does.
        target = Path("/Applications/Brickworks.app")
        shutil.rmtree(target, ignore_errors=True)
        subprocess.run(["ditto", str(mount / "Brickworks.app"), str(target)], check=True)
        subprocess.run(["hdiutil", "detach", str(mount)], check=True, capture_output=True)
        return target / "Contents" / "MacOS" / "Brickworks"
    if name.endswith("-setup.exe"):
        if os.name != "nt":
            raise Failed("an installer runs on Windows: tools/release.py inspect reads one here")
        # As the updater runs it: silently, for this person, no administrator.
        done = subprocess.run([str(package), "/VERYSILENT"], timeout=1200)
        if done.returncode != 0:
            raise Failed("%s /VERYSILENT exited %d" % (name, done.returncode))
        return WINDOWS_INSTALLED / "Brickworks.console.exe"
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
    # The package under test never updates itself mid-run (Updater.mode).
    env.update({"BRICKWORKS_UPDATES": "off", "HOME": str(home), "USERPROFILE": str(home),
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
                end_tree(process.pid)
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


def end_tree(pid: int) -> None:
    """End a Windows process and everything it started.

    Brickworks.console.exe is a wrapper that starts Brickworks.exe as a
    child. Ending the wrapper alone left the app running and holding its
    files, so the smoke run on Windows could not remove its clean home.
    """
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(pid)], capture_output=True)


def takes_bricks(base: list[str], env: dict[str, str], root: Path) -> list[tuple[str, bool, str]]:
    """Placing bricks from outside, the way a Claude Code session does,
    through the relay in this checkout. tools/mcp_check.py searches the
    catalogue, clears the baseplate, builds two bricks, saves and reads the
    file back."""
    port = free_port()
    said: list[tuple[str, bool, str]] = []
    with (root / "mcp-app.log").open("w") as log:
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
        said.append(("listens for MCP on %d after %.0f s" % (port, time.time() - started), listening,
                     (root / "mcp-app.log").read_text(errors="replace")))
        if listening:
            # The relay keeps the list it hears in tools/mcp_tools.json, and
            # a package from another commit serves another: kept here
            # instead, as smoking 0.13.0 rewrote the checkout's (2026-11-01).
            drive = subprocess.run([sys.executable, str(ROOT / "tools" / "mcp_check.py"),
                                    "--port=%d" % port], capture_output=True, text=True,
                                   timeout=600, env=dict(os.environ, BRICKWORKS_MCP_CACHE=str(
                                       root / "mcp_tools.json")))
            built = next((line.strip() for line in drive.stdout.splitlines()
                          if "a design lands" in line), "")
            said.append(("a session places bricks in it over MCP: %s" % built,
                         drive.returncode == 0, drive.stdout + drive.stderr))
    finally:
        stop(app)
    return said


# A model of each kind the packages open, from the checkout: LDraw, a
# multi-part LDraw, BrickLink Studio and LDD.
MODEL_FIXTURES = (ROOT / "models" / "car.ldr", ROOT / "src" / "dev" / "fixtures" / "telescope.mpd",
                  ROOT / "tests" / "fixtures" / "studio" / "bay_2025.io",
                  ROOT / "src" / "dev" / "fixtures" / "49311_test.lxf")


def opened_line(text: str, model: Path) -> int:
    """The parts the app said it opened [model] with (Main._open_given), or
    -1. By the file's name: a system can hand over another spelling of its
    folder (/private/var for /var on a Mac)."""
    found = re.findall(r"opened [^\n]*%s: (\d+) parts" % re.escape(model.name), text)
    return int(found[-1]) if found else -1


def ldraw_parts(text: str) -> int:
    """The parts in an LDraw model, a sub-model's counted each time it is
    placed, as the app counts them (ModelStore.count_in): a section whose
    header says it is a part, as a Studio file's own parts do, is one part."""
    def key(named: str) -> str:
        leaf = named.replace("\\", "/").strip().lower().rsplit("/", 1)[-1]
        return next((leaf[:-4] for suffix in (".ldr", ".dat", ".mpd") if leaf.endswith(suffix)), leaf)
    refs: dict[str, list[str]] = {}
    is_part: dict[str, bool] = {}
    order: list[str] = []
    name, lines, head = "", [], []  # type: str, list[str], list[str]
    for raw in (text + "\n0 NOFILE").split("\n"):
        line = raw.strip()
        if line.startswith("0 FILE ") or line.startswith("0 NOFILE"):
            if lines and name not in refs:
                refs[name] = lines
                is_part[name] = any(said.startswith("0 !LDRAW_ORG") and "part" in said.lower()
                                    for said in head)
                order.append(name)
            name = key(line[7:]) if line.startswith("0 FILE ") else ""
            lines, head = [], []
            continue
        if len(head) < 16:
            head.append(line)
        fields = line.split()
        if line.startswith("1 ") and len(fields) >= 15:
            lines.append(key(" ".join(fields[14:])))

    def count(section: str, depth: int) -> int:
        return sum(count(used, depth + 1) if depth < 32 and used in refs and used != section
                   and not is_part[used] else 1 for used in refs[section])
    return count(order[0], 0) if order else 0


def logs_say(folder: Path, model: Path, seconds: int) -> int:
    """[opened_line] from the app's own logs under [folder], waiting up to
    [seconds] for it: the app keeps running, so they are read as it goes."""
    end = time.time() + seconds
    while True:
        text = "".join(log.read_text(errors="replace") for log in folder.glob("*.log"))
        parts = opened_line(text, model)
        if parts >= 0 or time.time() > end:
            return parts
        time.sleep(1)


def held_windows(data: Path) -> list[int]:
    """The process of each window open on [data] (an app_userdata folder):
    a window holds its session with its process id (TabSession._hold). A
    run that quit without letting go leaves its hold behind, so only those
    still running a Brickworks count: the smoke counted three windows for
    two, and end_windows would have killed whatever had the old id since."""
    found = []
    for pid in data.glob("sessions/*/held/pid"):
        text = pid.read_text().strip()
        if text.isdigit() and app_running(int(text)):
            found.append(int(text))
    return found


def app_running(pid: int) -> bool:
    if os.name == "nt":
        listed = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"],
                                capture_output=True, text=True).stdout
    else:
        listed = subprocess.run(["ps", "-p", str(pid), "-o", "comm="],
                                capture_output=True, text=True).stdout
    return "brickworks" in listed.lower()


def end_windows(data: Path) -> None:
    for pid in held_windows(data):
        if os.name == "nt":
            end_tree(pid)
        else:
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass


def opens_models(package: Path, base: list[str], env: dict[str, str],
                 root: Path) -> list[tuple[str, bool | None, str]]:
    """The model files a person opens, opened as their system hands them over.

    Every package: each kind given to the program as a bare path, as a file
    association runs it, in a folder with a space in its name, and written
    back out. Then each system's own double-click, where the package
    registers one: the .deb's menu entry and MIME types through gio, which
    is what a file manager does; the disk image's app through Launch
    Services, as Finder does; the installer's types through the shell, as
    Explorer does, then its uninstaller. Each twice, the second with the
    app already open: it comes up in a window of its own.
    """
    said: list[tuple[str, bool | None, str]] = []
    folder = root / "my models"
    folder.mkdir(exist_ok=True)
    models = []
    for fixture in MODEL_FIXTURES:
        models.append(folder / fixture.name)
        shutil.copy2(fixture, models[-1])
    for model in models:
        out = root / ("from-%s.ldr" % model.suffix[1:])
        code, output = run_app(base + ["--headless", str(model), "--", "--out=%s" % out], env)
        parts = opened_line(output, model)
        written = ldraw_parts(out.read_text()) if out.exists() else 0
        said.append(("opens %s given as the system gives it: %d parts, %d written back"
                     % (model.name, parts, written),
                     code == 0 and parts > 0 and written == parts, output))
    said += carried_offline(base, env, root, folder / "bay_2025.io")

    twice = [folder / "car one.ldr", folder / "car two.ldr"]
    for copy in twice:
        shutil.copy2(models[0], copy)
    name = package.name
    if name.endswith(".deb"):
        said += double_click_linux(root / "unpacked", env, twice)
        said += thumbnails_linux(root / "unpacked", models)
    elif name.endswith(".dmg"):
        said += double_click_mac(twice)
    elif name.endswith("-setup.exe"):
        said += double_click_windows(package, twice)
    elif name.endswith(".AppImage"):
        said += appimage_integration(base[0], root)
    return said


def carried_offline(base: list[str], env: dict[str, str], root: Path,
                    bay: Path) -> list[tuple[str, bool, str]]:
    """A Studio file's own part, drawn from an LDraw part that a package has
    as a mesh and not as text: bay_2025.io's, made from 3001.dat, which the
    file carries as Studio's copy, drawn from the library's s/3001s01.dat.
    Opened above, the package fetched what it lacked from the parts store,
    as the web does, and kept it (PartForge.kept_dir): opened again with
    no network, it is drawn from those. In a home that never fetched them, it
    opens with the part said not drawn, by name and why, and the part is kept
    in the file. No network is a deployment that does not answer
    (BRICKWORKS_API at a port nobody listens on): the app learns nowhere to
    fetch from."""
    said: list[tuple[str, bool, str]] = []
    kept = [path for path in (root / "home").rglob("*.dat") if "ldraw" in path.parts]
    said.append(("...and kept the LDraw files its own part is drawn from: %s"
                 % (", ".join(str(path.relative_to(root)) for path in kept) or "none"),
                 bool(kept), ""))
    for home, wanted in ((root / "home", 0), (root / "home-offline", 1)):
        offline = dict(clean_env(home), BRICKWORKS_API="http://127.0.0.1:%d" % free_port())
        out = root / ("offline-%s.ldr" % home.name)
        code, output = run_app(base + ["--headless", str(bay), "--", "--out=%s" % out], offline)
        parts = opened_line(output, bay)
        written = ldraw_parts(out.read_text()) if out.exists() else 0
        line = next(iter(re.findall(r"opened [^\n]*%s: ([^\n]*)" % re.escape(bay.name), output)[-1:]), "")
        if not wanted:
            said.append(("opens it again with no network, drawn from what it kept: %d parts, %d "
                         "written back" % (parts, written),
                         code == 0 and parts > 0 and written == parts, output))
        else:
            told = "m1a2b3c4_2025408_163200 could not be drawn" in line \
                and "could not be reached" in line
            said.append(("opens it with no network in a home that never fetched it: %d of %d "
                         "drawn, and says why: %s" % (parts, written, line),
                         code == 0 and parts > 0 and written == parts + wanted and told, output))
    return said


def content_type(path: Path, env: dict[str, str]) -> str:
    """The type a file manager gives [path]: GIO's, from the shared MIME
    database, as Files, Nemo and Thunar read it. Not xdg-mime's: outside a
    desktop it asks file(1), which knows no LDraw, and a runner with no
    desktop said every .ldr was text/plain while gio opened it with us."""
    said = subprocess.run(["gio", "info", "--attributes=standard::content-type", str(path)],
                          env=env, capture_output=True, text=True).stdout
    found = re.search(r"standard::content-type: (\S+)", said)
    return found.group(1) if found else ""


def double_click_linux(root: Path, env: dict[str, str],
                       models: list[Path]) -> list[tuple[str, bool, str]]:
    """The .deb's files, told to a desktop as dpkg's triggers tell it, then
    each model opened with gio, as a file manager opens a double-click."""
    said: list[tuple[str, bool, str]] = []
    share = root / "root" / "usr" / "share"
    for tool, where in (("update-mime-database", "mime"), ("update-desktop-database", "applications")):
        if shutil.which(tool):
            subprocess.run([tool, str(share / where)], capture_output=True)
    desk = dict(env, XDG_DATA_DIRS="%s:/usr/share" % share,
                PATH="%s:%s" % (root / "root" / "usr" / "bin", env.get("PATH", "")))
    entry = share / "applications" / (APP_ID + ".desktop")
    if shutil.which("desktop-file-validate"):
        checked = subprocess.run(["desktop-file-validate", str(entry)], capture_output=True, text=True)
        said.append(("its menu entry is valid", checked.returncode == 0 and not checked.stdout.strip(),
                     checked.stdout + checked.stderr))
    if not shutil.which("xdg-mime") or not shutil.which("gio"):
        said.append(("xdg-mime and gio are here to open a model with", False, ""))
        return said
    for model in MODEL_FIXTURES:
        kind = next(k for k in MODEL_TYPES if k["ext"] == model.suffix[1:])
        typed = content_type(model, desk)
        handler = subprocess.run(["xdg-mime", "query", "default", kind["mime"]], env=desk,
                                 capture_output=True, text=True).stdout.strip()
        said.append(("a .%s is %s, which opens in %s" % (kind["ext"], typed or "nothing", handler or
                                                        "nothing"),
                     typed == kind["mime"] and handler == APP_ID + ".desktop", ""))
    data = Path(env["HOME"]) / ".local" / "share" / "godot" / "app_userdata" / "Brickworks"
    script = root / "double_click.sh"
    # Each opened as a file manager opens it, and waited for in the app's own
    # log; then the windows are counted while both are open, and the class
    # each says it is (WM_CLASS), which ties it to the menu entry's icon.
    script.write_text('set -u\nlogs="%s/logs"\nfor model in "$@"; do\n'
                      '  gio open "$model" || exit 3\n  name=$(basename "$model")\n'
                      '  for _ in $(seq 1 300); do\n'
                      '    grep -qsF "$name: " "$logs"/*.log && break\n'
                      '    sleep 1\n  done\ndone\n'
                      'n=0\nfor held in "%s"/sessions/*/held/pid; do\n'
                      '  ps -p "$(cat "$held" 2>/dev/null)" -o comm= 2>/dev/null | grep -qi brickworks'
                      ' && n=$((n + 1))\ndone\necho "$n" > "%s"\n'
                      'for id in $(xwininfo -root -children | awk \'/^ +0x/ {print $1}\'); do\n'
                      '  xprop -id "$id" WM_CLASS\ndone > "%s"\n'
                      % (data, data, root / "windows.txt", root / "classes.txt"))
    code, output = run_app(windowed(["bash", str(script)] + [str(m) for m in models], desk), desk, 900)
    text = "".join(log.read_text(errors="replace") for log in (data / "logs").glob("*.log"))
    for at, model in enumerate(models):
        parts = opened_line(text, model)
        said.append(("a double-click on %s opens it in Brickworks%s: %d parts"
                     % (model.name, ", the app already open" if at else "", parts), parts > 0,
                     output + text[-2000:]))
    windows = (root / "windows.txt").read_text().strip() if (root / "windows.txt").exists() else "0"
    said.append(("...each in a window of its own: %s open" % windows, windows == "2", output))
    classes = (root / "classes.txt").read_text() if (root / "classes.txt").exists() else ""
    named = re.findall(r'WM_CLASS\(STRING\) = "([^"]*)", "([^"]*)"', classes)
    said.append(("...whose class is the menu entry's StartupWMClass, %s: %s" % (
        WINDOW_CLASS, ", ".join(sorted({c for _, c in named})) or "no window named one"),
        len([c for _, c in named if c == WINDOW_CLASS]) == 2, classes))
    end_windows(data)
    return said


def thumbnails_linux(root: Path, models: list[Path]) -> list[tuple[str, bool | None, str]]:
    """The .deb's files, as double_click_linux told a desktop of them, and
    GNOME's own thumbnail factory asked for a picture of each model, as
    Files asks: tools/release/thumbnail_check.py, whose checks these are."""
    out = root / "thumbnails"
    done = subprocess.run([sys.executable, str(ROOT / "tools" / "release" / "thumbnail_check.py"),
                           "--root=%s" % (root / "root"), "--out=%s" % out, "--trace"]
                          + [str(model) for model in models],
                          capture_output=True, text=True, timeout=900)
    said: list[tuple[str, bool | None, str]] = []
    for line in done.stdout.splitlines():
        found = re.match(r"  (ok  |FAIL|--  )  (.*)$", line)
        if found:
            said.append(("thumbnail: " + found.group(2),
                         {"ok  ": True, "FAIL": False, "--  ": None}[found.group(1)],
                         done.stderr[-2000:]))
    if not said or done.returncode not in (0, 1):
        said.append(("thumbnail_check.py ran (exit %d)" % done.returncode, False,
                     done.stdout[-1000:] + done.stderr[-2000:]))
    return said


def double_click_mac(models: list[Path]) -> list[tuple[str, bool | None, str]]:
    """The app in /Applications (unpack put it there), registered with
    Launch Services as Finder registers a new app, then each model opened
    with open(1), which is a double-click in Finder. Through the launcher,
    so in the graphics mode it chooses for this Mac (mac_mode), said in
    each window's log and the simpler one said to the person once."""
    said: list[tuple[str, bool | None, str]] = []
    app = Path("/Applications/Brickworks.app")
    subprocess.run(["/System/Library/Frameworks/CoreServices.framework/Frameworks/"
                    "LaunchServices.framework/Support/lsregister", "-f", str(app)], check=True)
    # Launch Services starts it as the person, in their own home.
    data = Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata" / "Brickworks"
    try:
        for at, model in enumerate(models):
            # Launch Services starts it in the person's environment, not
            # clean_env's: told here, or an older release under check could
            # update itself part way through.
            done = subprocess.run(["open", "--env", "BRICKWORKS_UPDATES=off", str(model)],
                                  capture_output=True, text=True)
            parts = logs_say(data / "logs", model, 300) if done.returncode == 0 else -1
            said.append(("a double-click on %s opens it in Brickworks%s: %d parts"
                         % (model.name, ", the app already open" if at else "", parts), parts > 0,
                         done.stderr + ("" if parts > 0 else mac_state(data))))
        windows = held_windows(data)
        said.append(("...each in a window of its own: %d open" % len(windows), len(windows) == 2, ""))
        logs = "".join(log.read_text(errors="replace") for log in (data / "logs").glob("*.log"))
        mode = mac_mode()
        modes = re.findall(r"^graphics: (\w+) mode \((.*)\), (\S+) on (.*)$", logs, re.M)
        said.append(("...each in the %s graphics mode: %s" % (mode, "; ".join(
            "%s (%s), %s on %s" % found for found in modes) or "no window said"),
            len(modes) >= 2 and all(found[0] == mode for found in modes), logs[-1500:]))
        told = logs.count("graphics run Brickworks in its simpler mode.")
        said.append(("...and said so to the person %s" % ("once" if told == 1 else "%d times" % told),
                     told == (1 if mode == "simpler" else 0), ""))
    finally:
        end_windows(data)
    return said


def mac_mode() -> str:
    """The graphics mode the launcher should start this Mac in.

    An Intel Mac draws through Vulkan on MoltenVK; Apple silicon through
    Metal. The only GPU a macOS VM on an Intel host has is Apple's
    paravirtual one, 64 MB and Metal 2, and MoltenVK aborts on it in
    vkCreateInstance (an argument encoder it cannot make), or with argument
    buffers off runs out of device memory: GitHub's macos-15-intel is such a
    VM. The launcher starts the simpler mode there (OpenGL), and the full
    one on Apple silicon, paravirtual or not, and on a real Intel GPU."""
    arm = subprocess.run(["sysctl", "-n", "hw.optional.arm64"], capture_output=True, text=True)
    if arm.stdout.strip() == "1":
        return "full"
    gpus = subprocess.run(["system_profiler", "SPDisplaysDataType"], capture_output=True,
                          text=True).stdout
    chips = re.findall(r"Chipset Model: (.+)", gpus)
    return "simpler" if chips and all("Paravirtual" in chip for chip in chips) else "full"


def mac_state(data: Path) -> str:
    """What a Mac shows of an app that did not say it opened a model: its
    processes, the end of its newest log, and any crash report."""
    listed = subprocess.run(["ps", "-axo", "pid,etime,comm"], capture_output=True, text=True).stdout
    running = [line for line in listed.splitlines() if "Brickworks" in line]
    logs = sorted((data / "logs").glob("*.log"), key=lambda log: log.stat().st_mtime)
    tail = logs[-1].read_text(errors="replace")[-1500:] if logs else "no log in %s" % (data / "logs")
    reports = sorted((Path.home() / "Library" / "Logs" / "DiagnosticReports").glob("Brickworks*"))
    # The log first: a check prints only the last lines it is given.
    return tail + "\n" + "\n".join(running or ["no Brickworks running"]) + "\n" + (
        "crash reports: " + ", ".join(r.name for r in reports) if reports else "no crash report")


def double_click_windows(package: Path, models: list[Path]) -> list[tuple[str, bool, str]]:
    """What the installer left: the app, its Start menu entry, its line in
    Settings, Apps and its model types; each model opened as Explorer opens a
    double-click; then its uninstaller, which leaves the person's models."""
    import winreg  # type: ignore[import-not-found]

    def value(key: int, path: str, name: str = "") -> str:
        try:
            with winreg.OpenKey(key, path) as opened:
                return str(winreg.QueryValueEx(opened, name)[0])
        except OSError:
            return ""

    said: list[tuple[str, bool, str]] = []
    uninstall = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\Brickworks"
    start_menu = Path(os.environ["APPDATA"]) / "Microsoft" / "Windows" / "Start Menu" / "Programs" \
        / "Brickworks.lnk"
    version = package.name.split("-")[1]
    said.append(("installed for this person: %s" % WINDOWS_INSTALLED,
                 (WINDOWS_INSTALLED / "Brickworks.exe").exists(), ""))
    said.append(("in Settings, Apps as Brickworks %s" % value(winreg.HKEY_CURRENT_USER, uninstall,
                                                             "DisplayVersion"),
                 value(winreg.HKEY_CURRENT_USER, uninstall, "DisplayVersion") == version, ""))
    said.append(("in the Start menu", start_menu.exists(), str(start_menu)))
    for kind in MODEL_TYPES:
        progid = value(winreg.HKEY_CLASSES_ROOT, "." + kind["ext"])
        command = value(winreg.HKEY_CLASSES_ROOT, progid + r"\shell\open\command") if progid else ""
        said.append((".%s opens with %s" % (kind["ext"], command or "nothing"),
                     progid == "Brickworks." + kind["ext"] and "Brickworks.exe" in command, ""))
    data = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "Brickworks"
    # What startfile starts inherits this process's environment, not
    # clean_env's: an older release under check must not update itself.
    kept = os.environ.get("BRICKWORKS_UPDATES")
    os.environ["BRICKWORKS_UPDATES"] = "off"
    try:
        for at, model in enumerate(models):
            os.startfile(str(model))  # type: ignore[attr-defined]
            parts = logs_say(data / "logs", model, 300)
            said.append(("a double-click on %s opens it in Brickworks%s: %d parts"
                         % (model.name, ", the app already open" if at else "", parts), parts > 0, ""))
        windows = held_windows(data)
        said.append(("...each in a window of its own: %d open" % len(windows), len(windows) == 2, ""))
    finally:
        end_windows(data)
        time.sleep(2)
        if kept is None:
            os.environ.pop("BRICKWORKS_UPDATES", None)
        else:
            os.environ["BRICKWORKS_UPDATES"] = kept
    subprocess.run([str(WINDOWS_INSTALLED / "Uninstall Brickworks.exe"), "/S"], timeout=600)
    # The uninstaller runs from a copy of itself, so its own exit says
    # nothing: the folder going says it is done.
    end = time.time() + 300
    while (WINDOWS_INSTALLED / "Brickworks.exe").exists() and time.time() < end:
        time.sleep(2)
    left = sorted(p.name for p in WINDOWS_INSTALLED.glob("*")) if WINDOWS_INSTALLED.exists() else []
    said.append(("Uninstall removes it: %s" % (", ".join(left) or "nothing left"),
                 not left and not value(winreg.HKEY_CURRENT_USER, uninstall, "DisplayVersion")
                 and not start_menu.exists()
                 and not value(winreg.HKEY_CURRENT_USER, r"Software\Classes\.ldr"), ""))
    said.append(("...and keeps the person's models and settings", data.exists(), str(data)))
    return said


def appimage_integration(image: str, root: Path) -> list[tuple[str, bool, str]]:
    """What a desktop's AppImage integration (AppImageLauncher, Gear Lever,
    appimaged) takes from inside the image: its entry, icons and types."""
    subprocess.run([image, "--appimage-extract"], cwd=root, capture_output=True)
    inside = root / "squashfs-root"
    share = inside / "usr" / "share"
    entry = share / "applications" / (APP_ID + ".desktop")
    have = [entry, share / "mime" / "packages" / (APP_ID + ".xml"),
            share / "icons" / "hicolor" / "256x256" / "apps" / (APP_ID + ".png"),
            share / "icons" / "hicolor" / "scalable" / "apps" / (APP_ID + ".svg"),
            inside / (APP_ID + ".desktop")]
    missing = [str(path.relative_to(inside)) for path in have if not path.exists()]
    said = [("carries its menu entry, icons and model types: %s" % (
        "all there" if not missing else "lacks " + ", ".join(missing)), not missing, "")]
    if entry.exists() and shutil.which("desktop-file-validate"):
        checked = subprocess.run(["desktop-file-validate", str(entry)], capture_output=True, text=True)
        said.append(("...and the entry is valid", checked.returncode == 0 and not checked.stdout.strip(),
                     checked.stdout + checked.stderr))
    shutil.rmtree(inside, ignore_errors=True)
    return said


def stop(app: subprocess.Popen) -> None:
    if os.name == "nt":
        # Always, and the whole tree: the wrapper may have gone and left the
        # app it started running.
        end_tree(app.pid)
    elif app.poll() is None:
        os.killpg(os.getpgid(app.pid), signal.SIGTERM)
    try:
        app.wait(timeout=30)
    except subprocess.TimeoutExpired:
        app.kill()
        app.wait()


def windowed(command: list[str], env: dict[str, str]) -> list[str]:
    """The command run in a window: on an Xvfb of its own where there is
    one, and in this machine's GPU lease where it has one."""
    if shutil.which("xvfb-run"):
        # Always off-screen, whatever this shell's display is. The clean
        # home kept WAYLAND_DISPLAY at first, Godot chose Wayland over the
        # Xvfb it was given, and the smoke test opened a window on the
        # desktop of whoever was sitting there; one of those never exited.
        env["MESA_VK_WSI_DEBUG"] = "sw"
        command = ["xvfb-run", "-a", "--server-args=-screen 0 1280x800x24"] + command
    elif sys.platform.startswith("linux"):
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY"):
            if name in os.environ:
                env[name] = os.environ[name]
        say("        no xvfb-run: drawing on this machine's own screen")
    gpu = Path.home() / ".claude" / "claude-core" / "bin" / "gpu"
    if os.access(gpu, os.X_OK):
        # This machine's GPU lease. It finds the account's own home itself,
        # so the fresh one given to the app does not split it.
        command = [str(gpu)] + command
    return command


# Path-traced Best of the example car, asked as a session asks for it, and
# the picture it is held to: the same render from the editor build every
# probe runs (tools/release.py best-reference makes it).
BEST_ASK = {"kind": "picture", "quality": "best", "size": "720p", "view": "hero",
            "look": "product", "backdrop": "white"}
BEST_REFERENCE = ROOT / "tools" / "release" / "best_car.png"
# Measured 2026-11-01 at 160 x 90 grey against the editor's: the 0.13.0
# download 0.9993 (two release builds 0.9997 apart); the window's look in
# place of the product's 0.978; the car with its red parts gone 0.906, gone
# altogether 0.723.
BEST_ALIKE = 0.98
# A picture of one colour spreads 0; the car's spreads about 60.
BEST_BLANK = 4.0


def ask_for_best(base: list[str], env: dict[str, str], log: Path) -> tuple[bytes | None, str, str]:
    """The app in a window with its socket open, asked as a Claude Code
    session asks: open the car, render it at Best, and say whether Best is
    path traced here. The picture it answered with (None without one),
    everything it said, and how long it took."""
    port = free_port()
    command = windowed(base + ["--resolution", "1280x720", "--", "--mcp=%d" % port], env)
    said: list[str] = []
    picture = None
    took = ""
    with log.open("w") as out:
        # Its own process group, so stopping it cannot reach this one.
        app = subprocess.Popen(command, env=env, stdout=out, stderr=subprocess.STDOUT,
                               start_new_session=os.name != "nt",
                               creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))
    try:
        started = time.time()
        sock = None
        while sock is None:
            try:
                sock = socket.create_connection(("127.0.0.1", port), timeout=120)
            except OSError:
                # Timed from the GPU lease: gpu may queue the app behind
                # other jobs first, and says when it has the card.
                text = log.read_text(errors="replace")
                if "gpu: waiting" in text and "holds the GPU" not in text:
                    started = time.time()
                if app.poll() is not None or time.time() - started > 300:
                    said += ["the app did not listen for MCP on %d:" % port] \
                        + text.strip().splitlines()[-8:]
                    break
                time.sleep(0.5)
        if sock is not None:
            up = time.time() - started
            with sock:
                reader = sock.makefile("r", encoding="utf-8")
                asked = 0

                def call(tool: str, given: dict[str, Any]) -> dict[str, Any]:
                    nonlocal asked
                    asked += 1
                    sock.sendall((json.dumps({"id": asked, "tool": tool, "input": given})
                                  + "\n").encode())
                    while True:
                        line = reader.readline()
                        if not line:
                            raise OSError("the app closed its socket")
                        answer = json.loads(line)
                        if answer.get("id") == asked:
                            return answer

                def words(answer: dict[str, Any]) -> str:
                    return " ".join([str(answer.get("error") or "")] + [
                        c.get("text", "") for c in answer.get("content", [])
                        if c.get("type") == "text"]).strip()

                try:
                    said.append(words(call("open_model", {"name": "Car", "discard_changes": True})))
                    began = time.time()
                    answer = call("render_model", BEST_ASK)
                    job = re.match(r"Started job (\d+)", words(answer))
                    # Each job call waits up to 45 s for the render to end.
                    while job and time.time() - began < 600:
                        answer = call("job", {"id": int(job.group(1))})
                        if "is still going" not in words(answer):
                            break
                    took = "%.0f s, the app up in %.0f s" % (time.time() - began, up)
                    said.append(words(answer))
                    for block in answer.get("content", []):
                        if block.get("type") == "image":
                            picture = base64.b64decode(block.get("data") or block["source"]["data"])
                    said.append(words(call("render_queue", {"action": "list"})))
                except (OSError, ValueError) as error:
                    said.append("the socket: %s" % error)
    finally:
        stop(app)
    # What the path tracer refused, which a release build once refused all of.
    refused = [line.strip() for line in log.read_text(errors="replace").splitlines()
               if "was refused" in line]
    said += refused[:4] + (["...%d shapes refused in all" % len(refused)] if len(refused) > 4 else [])
    return picture, "\n".join(said), took


def judge_best(picture: bytes | None, said: str, took: str) -> list[tuple[str, bool, str]]:
    """A Best render held to what it must be: made, path traced, not blank,
    and the editor's picture of the same car."""
    if picture is None:
        return [("path-traced Best of the car over MCP: no picture", False, said)]
    traced = "Best is path traced on this graphics card" in said
    # A shape refused is a hole in the picture too small to tell by eye.
    whole = "was refused" not in said
    levels = grey(picture)
    if not levels:
        return [("path-traced Best of the car over MCP: not a PNG it can read", False, said)]
    flat = spread(levels)
    alike = ssim(levels, grey(BEST_REFERENCE.read_bytes()))
    return [
        ("path-traced Best of the car over MCP: %s" % (
            took if traced and whole else "it was not path traced" if not traced
            else "the path tracer refused shapes"), traced and whole, said),
        ("...not blank: its grey levels spread %.0f" % flat, flat > BEST_BLANK, ""),
        ("...and the editor's own picture of it: SSIM %.3f, %.2f wanted" % (alike, BEST_ALIKE),
         alike >= BEST_ALIKE, "if the look changed on purpose, tools/release.py best-reference "
         "makes the picture again from the editor"),
    ]


def smoke(package: Path, window: bool, expect: str) -> int:
    """Unpack a package and run it in a clean home. Exit 0 only if every check held."""
    failures = 0

    # ok is None for a check this machine cannot make: said, and why, and
    # neither passed nor failed.
    def check(what: str, ok: bool | None, detail: str = "") -> None:
        nonlocal failures
        say("  %s  %s" % ("ok  " if ok else "--  " if ok is None else "FAIL", what))
        if ok is False:
            failures += 1
            for line in detail.strip().splitlines()[-12:]:
                say("        " + line)

    def clean(output: str) -> bool:
        return not re.search(r"SCRIPT ERROR|Parse Error|Failed to load script", output)

    # Removing the clean home is tidying, not a verdict on the package: a
    # file Windows still had open failed a run whose every check had passed.
    with tempfile.TemporaryDirectory(prefix="brickworks-smoke-",
                                     ignore_cleanup_errors=True) as scratch:
        root = Path(scratch)
        (root / "unpacked").mkdir()
        program = unpack(package.resolve(), root / "unpacked")
        env = clean_env(root / "home")
        say("── %s, unpacked in a clean home ──" % package.name)
        # Where it went: inside the scratch for most, /Applications or
        # %LOCALAPPDATA%\Programs for the disk image and the installer.
        say("  %s" % (program.relative_to(root) if program.is_relative_to(root) else program))
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

        for what, ok, detail in takes_bricks(base, env, root):
            check(what, ok, detail)
        for what, ok, detail in opens_models(package, base, env, root):
            check(what, ok, detail)
        check("the app kept its state in the clean home", any((root / "home").rglob("Brickworks")))

        if window:
            # Drawn, not just loaded: a picture of the car from the package's
            # own geometry, on Xvfb when there is no screen.
            shot = root / "car.png"
            command = windowed(base + ["--resolution", "1280x800", "--",
                                       "--model=res://models/car.ldr", "--shot=%s" % shot], env)
            code, output = run_app(command, env, 600)
            colours = png_colours(shot) if shot.exists() else 0
            check("draws the car: %d colours in a %s picture" % (colours, "1280x800"),
                  code == 0 and clean(output) and colours > 200, output)
            # Godot says so when the splash project.godot names is not in the
            # package, and boots on its own logo instead (walk256 DS1).
            check("boots on the app's own splash", "invalid boot splash" not in output, output)
            if shot.exists():
                keep = ROOT / "shots" / ("release-%s.png" % describe_file(package.name)["os"])
                keep.parent.mkdir(exist_ok=True)
                shutil.copy2(shot, keep)
                say("        kept the picture at %s" % keep.relative_to(ROOT))

            # Path-traced Best, from the package's own build. Every probe
            # runs the editor, a debug build, and a release template leaves
            # out what is under DEBUG_ENABLED: 0.12.0's Best refused every
            # shape at blas_create (only a debug build works out an index
            # buffer's largest index), where the editor traced it in 3 s.
            # The sign-in screen covers the window in a clean home, and the
            # socket answers behind it, as it does headless: no account,
            # and nothing in the package let past the screen.
            picture, said, took = ask_for_best(base, env, root / "best-app.log")
            for what, ok, detail in judge_best(picture, said, took):
                check(what, ok, detail)
            if picture is not None:
                keep = ROOT / "shots" / ("release-%s-best.png" % describe_file(package.name)["os"])
                keep.parent.mkdir(exist_ok=True)
                keep.write_bytes(picture)
                say("        kept the picture at %s" % keep.relative_to(ROOT))

    say("")
    if failures:
        say("%d check(s) failed: %s is not fit to ship" % (failures, package.name))
        return 1
    say("%s starts, loads the part library, opens a model and takes bricks%s"
        % (package.name, ", and traces it at Best" if window else ""))
    return 0


def best_reference() -> int:
    """BEST_REFERENCE made again: the car at Best from this checkout's
    editor, the debug build every probe runs, in a clean home so Render's
    settings are its own. Made from a package it would hold a broken build
    to itself."""
    with tempfile.TemporaryDirectory(prefix="brickworks-best-") as scratch:
        root = Path(scratch)
        picture, said, took = ask_for_best([godot(), "--path", str(ROOT)],
                                           clean_env(root / "home"), root / "app.log")
        if picture is None or "Best is path traced on this graphics card" not in said:
            raise Failed("the editor did not trace the car at Best:\n  " + said.replace("\n", "\n  "))
        BEST_REFERENCE.write_bytes(picture)
    say("the editor's Best of the car in %s: %s; look at it before committing it"
        % (took, BEST_REFERENCE.relative_to(ROOT)))
    return 0


def png_rows(data: bytes) -> tuple[int, list[bytearray]]:
    """The channels and the rows of an 8-bit RGB or RGBA PNG, unfiltered.
    0 and no rows for any other kind."""
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
    if len(header) < 10:
        return 0, []
    width, height, depth, colour = struct.unpack(">IIBB", header[:10])
    if depth != 8 or colour not in (2, 6):
        return 0, []
    channels = 3 if colour == 2 else 4
    raw = zlib.decompress(b"".join(chunks))
    stride = width * channels
    previous = bytearray(stride)
    rows = []
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
        rows.append(line)
        previous = line
    return channels, rows


def png_colours(path: Path) -> int:
    """Distinct colours in an 8-bit RGB or RGBA PNG: a blank frame has a handful."""
    channels, rows = png_rows(path.read_bytes())
    return len({bytes(line[i:i + 3]) for line in rows[::4]
                for i in range(0, len(line), channels * 4)})


def grey(data: bytes, width: int = 160, height: int = 90) -> list[list[float]]:
    """A PNG's grey levels, each the mean of the pixels it covers at width
    x height. Small, so a path tracer's grain averages out and a part
    missing does not."""
    channels, rows = png_rows(data)
    if not rows:
        return []
    across, down = len(rows[0]) // channels, len(rows)
    out = []
    for y in range(height):
        band = rows[y * down // height:max((y + 1) * down // height, y * down // height + 1)]
        line = []
        for x in range(width):
            first = x * across // width
            last = max((x + 1) * across // width, first + 1)
            total = 0.0
            for row in band:
                for at in range(first * channels, last * channels, channels):
                    total += 0.299 * row[at] + 0.587 * row[at + 1] + 0.114 * row[at + 2]
            line.append(total / (len(band) * (last - first)))
        out.append(line)
    return out


def spread(levels: list[list[float]]) -> float:
    """The standard deviation of grey levels: near 0 for a blank picture."""
    values = [v for line in levels for v in line]
    mean = sum(values) / len(values)
    return (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5


def ssim(a: list[list[float]], b: list[list[float]], size: int = 8) -> float:
    """Mean structural similarity of two grey pictures of one size, over
    size x size windows half a window apart, with Wang et al.'s constants:
    1 for the same picture, falling as light, contrast and shape part."""
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    scores = []
    for top in range(0, len(a) - size + 1, size // 2):
        for left in range(0, len(a[0]) - size + 1, size // 2):
            xs = [v for line in a[top:top + size] for v in line[left:left + size]]
            ys = [v for line in b[top:top + size] for v in line[left:left + size]]
            n = len(xs)
            mx, my = sum(xs) / n, sum(ys) / n
            vx = sum((x - mx) ** 2 for x in xs) / (n - 1)
            vy = sum((y - my) ** 2 for y in ys) / (n - 1)
            cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / (n - 1)
            scores.append((2 * mx * my + c1) * (2 * cov + c2)
                          / ((mx * mx + my * my + c1) * (vx + vy + c2)))
    return sum(scores) / len(scores)


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
                     "your PC\" about the installer: check the SHA-256, then **More info** > "
                     "**Run anyway**.")
    kinds = {describe_file(str(f["name"]))["kind"] for f in files}
    # The zips beside the disk image and the installer, for one release
    # (docs/DISTRIBUTION.md).
    kept = ["The macOS and Windows **zips** are still here for this release, so links "
            "already shared keep working; the next one has only the disk image and the "
            "installer.", ""] if {"zip", "dmg"} <= kinds else []
    return "\n".join([
        body, "", "## Downloads", "",
        "The right one for your system, with checksums and what each needs: "
        "https://brickworks.diy/download", "",
        "| System | File | Size |", "|---|---|---|", rows, "",
        *(["On a Mac, open the **.dmg** and drag Brickworks onto Applications. On Windows, "
           "run the **setup.exe**: it installs for you alone, with no administrator, and "
           "Settings > Apps uninstalls it. On Debian or Ubuntu, `sudo apt install "
           "./Brickworks-%s-linux-amd64.deb`; anywhere else, the AppImage." % version, ""]
          if {"dmg", "installer", "deb"} <= kinds else []),
        *kept,
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
            # The release's own page carries its notes. The tag's CHANGELOG.md
            # did not when a tag was set on the live build rather than on the
            # release commit (v0.7.0, 2026-10-24).
            "notes": "https://github.com/%s/releases/tag/%s" % (REPO, tag),
            "summary": summary, "files": entries}


# -- the updater's manifest -------------------------------------------------

def update_manifest(version: str, tag: str, files: list[dict[str, Any]], date: str,
                    urls: dict[str, str]) -> dict[str, Any]:
    """What the desktop app reads to update itself (Updates.read): this
    release's version, its first paragraph of notes, and every package with
    the address it is fetched from, its size and its SHA-256."""
    _, body = section(version)
    notes = body.split("\n\n", 1)[0].replace("\n", " ").strip()
    return {"product": UPDATE_PRODUCT, "version": version, "date": date, "tag": tag,
            "page": "https://github.com/%s/releases/tag/%s" % (REPO, tag), "notes": notes,
            "files": [{"os": f["os"], "kind": f["kind"], "name": f["name"],
                       "url": urls[str(f["name"])], "size": int(f["size"]),
                       "sha256": f["sha256"]} for f in files]}


def _with_key(pem: bytes, command: list[str], data: bytes = b"") -> bytes:
    """openssl run with a private key handed over a pipe, never a file:
    KEY in [command] is its path. Only what openssl writes on stdout back."""
    read, write = os.pipe()
    try:
        os.write(write, pem)
        os.close(write)
        write = -1
        done = subprocess.run([part.replace("KEY", "/dev/fd/%d" % read) for part in command],
                              input=data, capture_output=True, pass_fds=(read,))
    finally:
        os.close(read)
        if write >= 0:
            os.close(write)
    if done.returncode != 0:
        # Its first line only: openssl never echoes the key, but nothing of
        # what it read is printed here either way.
        raise Failed("openssl %s failed: %s" % (command[1], done.stderr.decode(
            "utf-8", "replace").strip().splitlines()[:1]))
    return done.stdout


def update_key_id(public_der: bytes) -> str:
    return hashlib.sha256(public_der).hexdigest()[:16]


def app_update_keys(text: str | None = None) -> dict[str, str]:
    """The public keys the app believes, by id, read from updates.gd."""
    text = UPDATES_GD.read_text() if text is None else text
    return dict(re.findall(r'"([0-9a-f]{16})": """(-----BEGIN PUBLIC KEY-----.*?-----END PUBLIC KEY-----\n)"""',
                           text, re.S))


def _public_der(pem: str) -> bytes:
    with tempfile.NamedTemporaryFile("w", suffix=".pem", delete=False) as handle:
        handle.write(pem)
    try:
        return subprocess.run(["openssl", "pkey", "-pubin", "-in", handle.name, "-outform", "DER"],
                              check=True, capture_output=True).stdout
    finally:
        os.unlink(handle.name)


def sign_update_manifest(manifest: dict[str, Any],
                         keys: list[bytes] | None = None) -> dict[str, Any]:
    """latest.json: the manifest's text and a signature by each key, RSA over
    SHA-256 (what Godot's Crypto verifies). [keys] are private PEMs; by
    default .env's UPDATE_SIGN_KEY and UPDATE_SIGN_KEY_BACKUP, each of which
    must be one whose public half the app carries."""
    text = json.dumps(manifest, indent=1, sort_keys=True, ensure_ascii=False)
    known = app_update_keys()
    if keys is None:
        load_signing_env()
        keys = []
        for name in UPDATE_KEYS:
            value = os.environ.get(name, "")
            if not value:
                raise Failed("no %s in .env: the updater's manifest cannot be signed "
                             "(docs/UPDATES.md)" % name)
            try:
                keys.append(base64.b64decode(value, validate=True))
            except ValueError:
                raise Failed("%s is not base64" % name)
        for pem in keys:
            key_id = update_key_id(_with_key(pem, ["openssl", "pkey", "-in", "KEY", "-pubout",
                                                   "-outform", "DER"]))
            if key_id not in known:
                raise Failed("a key in .env (%s) is not one src/net/updates.gd knows: the app "
                             "would refuse everything it signs" % key_id)
    signatures = []
    for pem in keys:
        key_id = update_key_id(_with_key(pem, ["openssl", "pkey", "-in", "KEY", "-pubout",
                                               "-outform", "DER"]))
        signature = _with_key(pem, ["openssl", "dgst", "-sha256", "-sign", "KEY"],
                              text.encode("utf-8"))
        signatures.append({"key": key_id, "rsa_sha256": base64.b64encode(signature).decode()})
    return {"$comment": "Written by tools/release.py publish; read by the desktop app "
                        "(src/net/updates.gd), which believes the manifest in 'signed' only "
                        "under a signature by a key it carries.",
            "signed": text, "signatures": signatures}


# The packages an installed copy updates itself from, by system: a release
# without one leaves every copy installed from it unable to update.
UPDATE_KINDS = {"linux": ("AppImage", "tar.xz", "deb"), "macos": ("dmg",), "windows": ("installer",)}


def missing_update_kinds(manifest: dict[str, Any]) -> list[str]:
    """Each package kind of UPDATE_KINDS latest.json does not list."""
    have = {(str(f.get("os")), str(f.get("kind"))) for f in manifest.get("files", [])}
    return ["%s %s" % (os_, kind) for os_, kinds in UPDATE_KINDS.items() for kind in kinds
            if (os_, kind) not in have]


def check_update_manifest(envelope: dict[str, Any],
                          keys: dict[str, str] | None = None) -> list[str]:
    """What the app would refuse in latest.json, as Updates.read does it: the
    signatures, by the keys it carries, then every field. [] when none."""
    keys = app_update_keys() if keys is None else keys
    signed = envelope.get("signed")
    if not isinstance(signed, str):
        return ["no signed manifest in it"]
    good = []
    for each in envelope.get("signatures", []):
        pem = keys.get(str(each.get("key", "")))
        if pem is None:
            continue
        with tempfile.TemporaryDirectory() as private:
            (Path(private) / "key.pem").write_text(pem)
            (Path(private) / "sig").write_bytes(base64.b64decode(str(each.get("rsa_sha256", ""))))
            done = subprocess.run(["openssl", "dgst", "-sha256", "-verify",
                                   str(Path(private) / "key.pem"), "-signature",
                                   str(Path(private) / "sig")], input=signed.encode("utf-8"),
                                  capture_output=True)
            if done.returncode == 0:
                good.append(each["key"])
    problems = [] if good else ["no signature by a key the app carries holds"]
    manifest = json.loads(signed)
    if manifest.get("product") != UPDATE_PRODUCT:
        problems.append("its product is %r" % manifest.get("product"))
    if not SEMVER.match(str(manifest.get("version", ""))):
        problems.append("its version is %r" % manifest.get("version"))
    for f in manifest.get("files", []):
        if not str(f.get("url", "")).startswith("https://github.com/%s/releases/download/" % REPO):
            problems.append("%s is not on the release: %s" % (f.get("name"), f.get("url")))
        if not re.fullmatch(r"[0-9a-f]{64}", str(f.get("sha256", ""))) or int(f.get("size", 0)) < 1:
            problems.append("%s has no SHA-256 or size" % f.get("name"))
    if not manifest.get("files"):
        problems.append("it lists no files")
    return problems


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
    latest_json = out / "latest.json"
    files = [out / f["name"] for f in facts["files"]] + [out / "SHA256SUMS"]
    existing = release_view(tag)
    # Public only by promoting a draft that was checked. Creating it public
    # in one step skipped the run on macOS and Windows, and one mistyped
    # flag was all it took: "publish --help" started exactly that, and was
    # stopped part way through its upload.
    if existing is None and not draft:
        raise Failed("there is no draft %s to publish: publish --draft first, check it "
                     "on all three systems (gh workflow run release.yml -R %s -f tag=%s), "
                     "then publish it" % (tag, REPO, tag))
    if existing is None:
        # The updater's manifest, signed here: each package at the address it
        # has once the release is published, which is the only time any copy
        # of the app reads it (releases/latest/download/ names no draft).
        pinned = {f["name"]: "https://github.com/%s/releases/download/%s/%s" % (REPO, tag, f["name"])
                  for f in facts["files"]}
        latest = sign_update_manifest(update_manifest(version, tag, facts["files"], date, pinned))
        problems = check_update_manifest(latest)
        missing = missing_update_kinds(json.loads(latest["signed"]))
        if missing:
            problems.append("it has no %s, so copies installed from one could not update"
                            % ", ".join(missing))
        if problems:
            raise Failed("latest.json would be refused by the app: " + "; ".join(problems))
        latest_json.write_text(json.dumps(latest, indent=1) + "\n")
        say("  latest.json signed by %d keys the app carries" % len(latest["signatures"]))
    elif existing["isDraft"] and not draft \
            and "latest.json" not in {asset["name"] for asset in existing["assets"]}:
        # Every installed copy reads the newest release's latest.json: one
        # without it would leave them all unable to update.
        raise Failed("the draft %s has no latest.json, so no installed copy could update to it: "
                     "delete it (gh release delete %s --yes) and publish --draft again" % (tag, tag))
    if latest_json.exists() and (existing is None
                                 or "latest.json" in {a["name"] for a in existing["assets"]}):
        files.append(latest_json)
    if existing is None:
        # Uploaded once. A draft is how a release is checked on the
        # systems it is for before anyone can see it; publishing then
        # promotes that same draft, so what was checked is what ships.
        notes = release_notes(version, facts["files"], tag)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as handle:
            handle.write(notes)
        say("── %s %s, %d files, %s ──" % ("drafting" if draft else "publishing", tag,
                                         len(files), human(sum(p.stat().st_size for p in files))))
        # The tag there is on that repository's own main, its README: the
        # source is not in it. The source's tag goes on the commit when the
        # release is published (tag_source).
        command = ["gh", "release", "create", tag, "--repo", REPO, "--title",
                   "Brickworks %s" % version, "--notes-file", handle.name, "--target", "main"]
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
    if not draft:
        tag_source(tag, commit)
    if manifest and not draft:
        public = {name: "https://github.com/%s/releases/download/%s/%s" % (REPO, tag, name)
                  for name in urls}
        write_manifest(manifest_entry(version, tag, facts["files"], date, public), MANIFEST)
        say("next: tools/site_lang.py, commit web/releases.json and the download pages, and send "
            "the lead `ready: <sha>`: the page ships on the next release train "
            "(docs/RELEASING.md), never by a push to main or a deploy by hand, so it offers %s"
            % version)
    return 0


def tag_source(tag: str, commit: str) -> None:
    """The release's tag on the commit it was built from, on origin. GitHub set
    it there while the releases lived in the source repository; theirs holds
    builds only, so it is pushed here. A tag already there must name the
    same commit."""
    full = git("rev-parse", commit + "^{commit}")
    there = git("ls-remote", "origin", "refs/tags/%s^{}" % tag, "refs/tags/%s" % tag)
    if there:
        named = there.splitlines()[-1].split()[0]
        if named != full:
            raise Failed("origin's tag %s names %s, not %s, which was built" % (tag, named, full))
        return
    subprocess.run(["git", "push", "-q", "origin", "%s:refs/tags/%s" % (full, tag)],
                   cwd=ROOT, check=True)
    say("  tagged %s on origin: %s" % (tag, full[:12]))


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


## What each command takes. Anything else is refused rather than ignored:
## an ignored "--drfat" is a public release.
TAKES: dict[str, tuple[str, ...]] = {
    "version": ("--set",),
    "notes": (),
    "build": ("--assets=",),
    "inspect": (),
    "smoke": ("--window", "--expect="),
    "best-reference": (),
    "publish": ("--draft", "--no-manifest", "--tag=", "--target="),
    "manifest": ("--local", "--out="),
    "latest": ("--check",),
}


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help", "help") or "-h" in argv or "--help" in argv:
        print(__doc__)
        return 0
    command, args = argv[0], argv[1:]
    for arg in args:
        if arg.startswith("-") and command in TAKES and not any(
                arg == known or (known.endswith("=") and arg.startswith(known))
                for known in TAKES[command]):
            raise Failed("%s does not take %s: see tools/release.py --help" % (command, arg))
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
    if command == "best-reference":
        return best_reference()
    if command == "publish":
        return publish("--draft" in args, option(args, "tag"), option(args, "target"),
                       "--no-manifest" not in args)
    if command == "latest":
        if "--check" not in args or len([a for a in args if not a.startswith("--")]) != 1:
            raise Failed("latest --check FILE")
        path = Path(next(a for a in args if not a.startswith("--")))
        problems = check_update_manifest(json.loads(path.read_text()))
        for problem in problems:
            say("  FAIL  " + problem)
        if not problems:
            manifest = json.loads(json.loads(path.read_text())["signed"])
            say("  ok    %s: Brickworks %s, %d files, signed by a key the app carries"
                % (path, manifest["version"], len(manifest["files"])))
        return 1 if problems else 0
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
