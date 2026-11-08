"""The version a release says it is, and the file names it goes out under.

One version is read from three places: VERSION, project.godot (which the
macOS Info.plist and the Windows file version are filled from at export)
and CHANGELOG.md (which becomes the release notes). A release where two of
them disagree tells the download page one thing and the app another, so
tools/release.py sets all three at once and refuses to build when they
differ. These pin both halves on a throwaway copy of the three files.

The packages themselves are proven by building them: `tools/release.py
build` reads every one back, and `smoke` runs it.
"""

from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import release  # noqa: E402

LOG = """# Changelog

## [Unreleased]

### Fixed
- A thing that was broken.

## [0.1.0] - 2026-10-10

The first one.

### Added
- Everything.
"""


def _copy_of_the_three(version: str = "0.1.0", log: str = LOG) -> Path:
    where = Path(tempfile.mkdtemp(prefix="brickworks-release-test-"))
    (where / "VERSION").write_text(version + "\n")
    (where / "project.godot").write_text(
        '[application]\n\nconfig/name="Brickworks"\nconfig/version="%s"\n' % version)
    (where / "CHANGELOG.md").write_text(log)
    return where


def _in(where: Path, action):
    kept = release.ROOT
    release.ROOT = where
    try:
        return action()
    finally:
        release.ROOT = kept
        shutil.rmtree(where, ignore_errors=True)


def test_each_changelog_section_is_read_with_its_date():
    sections = release.changelog_sections(LOG)
    assert [(name, date) for name, date, _ in sections] == [
        ("Unreleased", ""), ("0.1.0", "2026-10-10")]
    assert sections[1][2].startswith("The first one.")
    assert "A thing that was broken." in sections[0][2]


def test_the_version_agrees_with_itself():
    assert _in(_copy_of_the_three(), release.check_version) == []


def test_a_disagreement_names_the_file():
    where = _copy_of_the_three()
    (where / "VERSION").write_text("0.2.0\n")
    problems = _in(where, release.check_version)
    assert any("project.godot" in p for p in problems)
    assert any("no ## [0.2.0] section" in p for p in problems)


def test_notes_that_write_the_mark_wrong_are_refused_before_a_build():
    """0.13.0's notes said "the names LEGO gives them". The CI gate caught it
    only after the release was built, and its tag still carries it."""
    log = LOG.replace("The first one.", "Parts have the names LEGO gives them there.")
    problems = _in(_copy_of_the_three(log=log), release.check_version)
    assert any("[0.1.0]" in p and "LEGO Group" in p for p in problems), problems
    fixed = LOG.replace("The first one.", "Parts have the names the LEGO Group gives them there.")
    assert _in(_copy_of_the_three(log=fixed), release.check_version) == []


def test_setting_a_version_moves_unreleased_into_a_dated_section():
    where = _copy_of_the_three()

    def bump():
        release.set_version("0.2.0", "2026-10-17")
        return (release.version_file(), release.project_version(),
                release.changelog_sections(), release.check_version())

    version, godot, sections, problems = _in(where, bump)
    assert version == "0.2.0"
    assert godot == "0.2.0"
    assert [(name, date) for name, date, _ in sections] == [
        ("Unreleased", ""), ("0.2.0", "2026-10-17"), ("0.1.0", "2026-10-10")]
    # What was under Unreleased is the release's now, and Unreleased is empty.
    assert sections[0][2] == ""
    assert "A thing that was broken." in sections[1][2]
    assert problems == []


def test_a_released_version_cannot_be_set_again():
    def again():
        try:
            release.set_version("0.1.0", "2026-10-17")
        except release.Failed as failure:
            return str(failure)
        return ""

    assert "already has a section" in _in(_copy_of_the_three(), again)


def test_a_version_must_be_semver():
    def short():
        try:
            release.set_version("0.2", "2026-10-17")
        except release.Failed as failure:
            return str(failure)
        return ""

    assert "not X.Y.Z" in _in(_copy_of_the_three(), short)


def test_every_package_name_says_its_system():
    named = {name: release.describe_file(name)
             for names in release.artifacts("1.2.3").values() for name in names}
    assert named == {
        "Brickworks-1.2.3-linux-x86_64.AppImage": {"os": "linux", "arch": "x86_64", "kind": "AppImage"},
        "Brickworks-1.2.3-linux-amd64.deb": {"os": "linux", "arch": "x86_64", "kind": "deb"},
        "Brickworks-1.2.3-linux-x86_64.tar.xz": {"os": "linux", "arch": "x86_64", "kind": "tar.xz"},
        "Brickworks-1.2.3-macos-universal.dmg": {"os": "macos", "arch": "universal", "kind": "dmg"},
        "Brickworks-1.2.3-macos-universal.zip": {"os": "macos", "arch": "universal", "kind": "zip"},
        "Brickworks-1.2.3-windows-x86_64-setup.exe": {"os": "windows", "arch": "x86_64",
                                                      "kind": "installer"},
        "Brickworks-1.2.3-windows-x86_64.zip": {"os": "windows", "arch": "x86_64", "kind": "zip"},
    }
    # The one the download page offers first, first (web/download.js PREFER).
    assert [names[0].rsplit("-", 2)[-1] for names in release.artifacts("1.2.3").values()] == [
        "x86_64.AppImage", "universal.dmg", "setup.exe"]


def test_help_after_a_command_is_help_and_does_nothing():
    called = []
    kept = release.publish
    release.publish = lambda *a, **k: called.append(a) or 0
    try:
        assert release.main(["publish", "--help"]) == 0
    finally:
        release.publish = kept
    assert called == [], "publish --help ran publish"


def test_a_flag_a_command_does_not_take_is_refused():
    called = []
    kept = release.publish
    release.publish = lambda *a, **k: called.append(a) or 0
    try:
        try:
            release.main(["publish", "--drfat"])
            refused = False
        except release.Failed:
            refused = True
    finally:
        release.publish = kept
    assert refused and called == []


def test_nothing_is_made_public_without_a_draft_first():
    kept_view, kept_check, kept_built = release.release_view, release.check_version, release.built
    release.release_view = lambda tag: None
    release.check_version = lambda: []
    release.built = lambda version: (Path("/nonexistent"), {"commit": "x", "files": []})
    try:
        try:
            release.publish(False, "v9.9.9", "deadbeef", False)
            refused = False
        except release.Failed as failure:
            refused = "publish --draft first" in str(failure)
    finally:
        release.release_view, release.check_version, release.built = kept_view, kept_check, kept_built
    assert refused


# The update manifests publish signed, as it handed them over to be signed.
SIGNED: list[dict] = []


def _publish_with_github_stubbed(draft: bool, existing: bool,
                                 latest_on_draft: bool = True) -> list[list[str]]:
    """Every command publish runs, with GitHub and git answered here: a
    one-file build, a draft already up or none, and GitHub's SHA-256 the
    file's own. Signing, and the kinds latest.json must list, are
    tests/test_updates.py's; here they are stubbed."""
    where = Path(tempfile.mkdtemp(prefix="brickworks-release-test-"))
    package = where / "Brickworks-9.9.9-linux-x86_64.tar.xz"
    package.write_bytes(b"a package")
    (where / "SHA256SUMS").write_text("%s  %s\n" % (release.sha256_of(package), package.name))
    if existing and latest_on_draft:
        # The draft's, written when it was made.
        (where / "latest.json").write_text("{}")
    # GitHub holds what is in the folder when it is asked: a new draft's
    # latest.json is written by publish itself.
    files = lambda: sorted(where.iterdir())  # noqa: E731
    held = lambda drafted: {  # noqa: E731
        "url": "https://github.com/%s/releases/tag/v9.9.9" % release.REPO, "isDraft": drafted,
        "databaseId": 1, "assets": [{"name": p.name, "size": p.stat().st_size} for p in files()]}
    asked: list[str] = []
    ran: list[list[str]] = []

    def view(tag):
        # First whether it is there; then, after the upload, what it holds.
        asked.append(tag)
        if len(asked) == 1:
            return held(True) if existing else None
        return held(draft)

    def run(command, **kwargs):
        ran.append(list(command))
        out = ""
        if command[:2] == ["gh", "api"]:
            out = json.dumps({"assets": [{"name": p.name, "digest": "sha256:" + release.sha256_of(p),
                                          "browser_download_url": "https://example/" + p.name}
                                         for p in files()]})
        elif command[:2] == ["git", "rev-parse"]:
            out = "f" * 40
        return subprocess.CompletedProcess(command, 0, stdout=out, stderr="")

    kept = (release.release_view, release.check_version, release.built, release.subprocess.run,
            release.sign_update_manifest, release.check_update_manifest, release.missing_update_kinds)
    release.release_view = view
    release.check_version = lambda: []
    release.built = lambda version: (where, {"commit": "x", "files": [
        {"name": package.name, "os": "linux", "kind": "tar.xz", "size": package.stat().st_size,
         "sha256": release.sha256_of(package), "facts": {}}]})
    release.subprocess.run = run
    SIGNED.clear()
    release.sign_update_manifest = lambda manifest: (SIGNED.append(manifest)
                                                     or {"signed": json.dumps(manifest), "signatures": []})
    release.check_update_manifest = lambda envelope: []
    release.missing_update_kinds = lambda manifest: []
    try:
        release.publish(draft, "v9.9.9", "abc", False)
    finally:
        (release.release_view, release.check_version, release.built, release.subprocess.run,
         release.sign_update_manifest, release.check_update_manifest, release.missing_update_kinds) = kept
        shutil.rmtree(where, ignore_errors=True)
    return ran


def test_a_draft_goes_to_the_public_releases_repository():
    # The source repository is to be private, and a private repository's
    # files answer 404 to everyone else (2026-10-27). Its commits are not in
    # the releases repository, so the tag there goes on that one's main.
    ran = _publish_with_github_stubbed(draft=True, existing=False)
    create = next(c for c in ran if c[:3] == ["gh", "release", "create"])
    assert create[create.index("--repo") + 1] == "Xaxis/brickworks-releases"
    assert create[create.index("--target") + 1] == "main"
    assert "--draft" in create
    assert not any(c[:2] == ["git", "push"] for c in ran), "a draft tagged the source"
    # With the packages goes the updater's manifest, each file at the address
    # it has once published.
    assert any(arg.endswith("/latest.json") for arg in create)
    assert [f["url"] for f in SIGNED[0]["files"]] == [
        "https://github.com/Xaxis/brickworks-releases/releases/download/v9.9.9/"
        "Brickworks-9.9.9-linux-x86_64.tar.xz"]


def test_a_draft_with_no_update_manifest_is_never_published():
    # Every installed copy reads the newest release's latest.json.
    try:
        _publish_with_github_stubbed(draft=False, existing=True, latest_on_draft=False)
    except release.Failed as failure:
        assert "has no latest.json" in str(failure)
    else:
        raise AssertionError("a draft with no latest.json was published")


def test_publishing_tags_the_built_commit_on_origin():
    ran = _publish_with_github_stubbed(draft=False, existing=True)
    edit = next(c for c in ran if c[:3] == ["gh", "release", "edit"])
    assert edit[edit.index("--repo") + 1] == "Xaxis/brickworks-releases"
    assert "--draft=false" in edit
    assert ["git", "push", "-q", "origin", "f" * 40 + ":refs/tags/v9.9.9"] in ran


# The words a THIRD-PARTY-NOTICES.txt carries, as Credits.notices writes it
# and Godot 4.7 says its own licence: what each licence asks a copy to carry.
WHOLE_NOTICES = (ROOT / "src/ui/credits.gd").read_text() + """
Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

== Components ==
"""
# Before 2026-10-29: BrickNet's notice line, and not its permission.
NOTICE_LINE_ONLY = WHOLE_NOTICES.replace(
    "Copyright (c) 2026 Peter Kulits\n\nPermission is hereby granted", "Copyright (c) 2026 Peter Kulits.")


def _package(tmp_path: Path, platform: str, notices: str | None) -> Path:
    """A package as release.py makes one, with a stand-in for the app: the
    files beside it put there by extras(), from a staged ATTRIBUTION.md and
    the notices given (None: none written)."""
    kept = release.STAGE, release.WORK
    release.STAGE, release.WORK = tmp_path / "stage", tmp_path / "work"
    (release.STAGE / "docs").mkdir(parents=True)
    shutil.copy2(ROOT / "docs" / "ATTRIBUTION.md", release.STAGE / "docs" / "ATTRIBUTION.md")
    release.WORK.mkdir()
    if notices is not None:
        (release.WORK / "THIRD-PARTY-NOTICES.txt").write_text(notices)
    folder = tmp_path / platform / ("Brickworks-9.9.9-%s" % platform)
    folder.mkdir(parents=True)
    try:
        if notices is not None:
            release.extras(folder, platform, "9.9.9", "2026-10-29", {})
        else:
            (folder / "ATTRIBUTION.md").write_text("terms")
        if platform == "linux":
            binary = folder / "brickworks.x86_64"
            binary.write_bytes(b"\x7fELF GLIBC_2.31\0")
            binary.chmod(0o755)
            package = tmp_path / (folder.name + ".tar.xz")
            release.write_tar_xz(folder, package, 1761696000)
        else:
            package = tmp_path / (folder.name + ".zip")
            release.write_zip(folder, package, 1761696000)
    finally:
        release.STAGE, release.WORK = kept
    return package


def test_the_credits_carry_every_licences_words_but_the_engines():
    source = (ROOT / "src/ui/credits.gd").read_text()
    engine = {"Godot's licence", "its components' notices"}
    assert [what for what, words in release.NOTICES_SAY.items()
            if what not in engine and words not in source] == []
    assert release.notices_lacking(WHOLE_NOTICES) == []


def test_inspect_reads_the_licences_out_of_each_package(tmp_path):
    tar = release.inspect_tar(_package(tmp_path / "a", "linux", WHOLE_NOTICES))
    assert {"README.txt", "ATTRIBUTION.md", "THIRD-PARTY-NOTICES.txt"} <= set(tar["contents"])
    assert tar["licences"]["files"] == ["ATTRIBUTION.md", "THIRD-PARTY-NOTICES.txt"]
    assert tar["licences"]["lacking"] == []
    assert tar["licences"]["notices"] == len(WHOLE_NOTICES.encode())
    release.say_licences("linux", tar["licences"])
    zipped = release.inspect_windows(_package(tmp_path / "b", "windows", WHOLE_NOTICES))
    assert zipped["licences"]["lacking"] == []


def test_a_package_without_a_licences_words_is_refused(tmp_path):
    old = release.inspect_tar(_package(tmp_path / "a", "linux", NOTICE_LINE_ONLY))
    assert old["licences"]["lacking"] == ["BrickNet's MIT text"]
    try:
        release.say_licences("Brickworks-9.9.9-linux-x86_64.tar.xz", old["licences"])
        refused = ""
    except release.Failed as failure:
        refused = str(failure)
    assert refused == "Brickworks-9.9.9-linux-x86_64.tar.xz lacks BrickNet's MIT text"
    bare = release.inspect_windows(_package(tmp_path / "b", "windows", None))
    assert bare["licences"]["lacking"] == ["THIRD-PARTY-NOTICES.txt"]


# -- the smoke test's path-traced Best ---------------------------------------

TRACED = "Best is path traced on this graphics card."


def _png(rows: list[bytes]) -> bytes:
    """An 8-bit RGB PNG of these rows, each three bytes a pixel."""
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))
    header = struct.pack(">IIBBBBB", len(rows[0]) // 3, len(rows), 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(b"".join(b"\x00" + row for row in rows)))
            + chunk(b"IEND", b""))


def _smoke_given(tmp_path, monkeypatch, capsys, picture, said,
                 own_part: bool = True) -> tuple[int, str]:
    """smoke --window on a package that does everything else right, the app
    stood in for here, and its Best render answering picture and said.
    Without [own_part] it is 0.15.0, which drew bay_2025.io's own part
    nowhere: it had 3001.dat only as a mesh."""
    reference = release.BEST_REFERENCE.read_bytes()

    def run_app(command, env, seconds=420):
        data = Path(env["HOME"]) / ".local/share/godot/app_userdata/Brickworks"
        data.mkdir(parents=True, exist_ok=True)
        given = dict(arg.split("=", 1) for arg in command if arg.startswith("--") and "=" in arg)
        # A model handed over as a double-click hands it over: a bare path.
        model = next((arg for arg in command[1:] if not arg.startswith("-")), "")
        if "--out" in given:
            Path(given["--out"]).write_text("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" * 60)
            parts, why = 60, ""
            # bay_2025.io's own part is drawn from 3001.dat: fetched and kept
            # online, from what was kept offline, and else not drawn.
            kept = data / "ldraw" / "parts" / "s" / "3001s01.dat"
            if model.endswith("bay_2025.io") and "BRICKWORKS_API" not in env and own_part:
                kept.parent.mkdir(parents=True, exist_ok=True)
                kept.write_text("0 ~Brick  2 x  4 without Front Face\n")
            elif model.endswith("bay_2025.io") and not kept.exists():
                parts, why = 59, (" — 1 not shown, kept in the file (m1a2b3c4_2025408_163200)"
                                  " — m1a2b3c4_2025408_163200 could not be drawn: it uses parts"
                                  " this build does not have: s/3001s01.dat (fetching"
                                  " s/3001s01.dat: the parts store could not be reached)")
            return 0, ("opened %s: %d parts%s\n" % (model, parts, why) if model else "") \
                + "wrote %s (%d parts)" % (given["--out"], parts)
        if "--shot" in given:
            Path(given["--shot"]).write_bytes(reference)
            return 0, ""
        return 0, "Brickworks 9.9.9, released 2026-11-01"

    monkeypatch.setattr(release, "ROOT", tmp_path)
    monkeypatch.setattr(release, "unpack", lambda package, into: into / "brickworks.x86_64")
    monkeypatch.setattr(release, "run_app", run_app)
    monkeypatch.setattr(release, "takes_bricks", lambda base, env, root: [
        ("a session places bricks in it over MCP", True, "")])
    monkeypatch.setattr(release, "ask_for_best", lambda base, env, log: (
        picture, said, "7 s, the app up in 9 s"))
    package = tmp_path / "Brickworks-9.9.9-linux-x86_64.tar.xz"
    package.write_bytes(b"")
    code = release.smoke(package, True, "9.9.9")
    return code, capsys.readouterr().out


def test_the_smoke_fails_a_package_that_leaves_a_studio_file_s_own_part_off(
        tmp_path, monkeypatch, capsys):
    code, said = _smoke_given(tmp_path, monkeypatch, capsys,
                              release.BEST_REFERENCE.read_bytes(), "Opened Car.\n" + TRACED,
                              own_part=False)
    assert code == 1, said
    assert "FAIL  opens bay_2025.io given as the system gives it: 59 parts, 60 written back" in said
    assert "FAIL  ...and kept the LDraw files its own part is drawn from: none" in said


def test_the_smoke_holds_a_package_to_the_editors_best(tmp_path, monkeypatch, capsys):
    code, said = _smoke_given(tmp_path, monkeypatch, capsys,
                              release.BEST_REFERENCE.read_bytes(), "Opened Car.\n" + TRACED)
    assert code == 0, said
    assert "ok    path-traced Best of the car over MCP: 7 s, the app up in 9 s" in said
    assert "ok    ...and the editor's own picture of it: SSIM 1.000" in said
    assert "and traces it at Best" in said
    assert (tmp_path / "shots" / "release-linux-best.png").read_bytes() \
        == release.BEST_REFERENCE.read_bytes()


def test_a_best_with_no_picture_fails_the_smoke(tmp_path, monkeypatch, capsys):
    # 0.12.0: every shape refused at blas_create, and the render cancelled.
    code, said = _smoke_given(tmp_path, monkeypatch, capsys, None,
                              "Job 1 (render_model) is done, after 3 s:\nCancelled.\n"
                              "path tracer: a shape of 672 triangles was refused")
    assert code == 1
    assert "FAIL  path-traced Best of the car over MCP: no picture" in said
    assert "a shape of 672 triangles was refused" in said
    assert "is not fit to ship" in said


def test_a_blank_best_fails_the_smoke(tmp_path, monkeypatch, capsys):
    blank = _png([b"\xf0\xf0\xf0" * 800] * 450)
    code, said = _smoke_given(tmp_path, monkeypatch, capsys, blank, TRACED)
    assert code == 1
    assert "FAIL  ...not blank: its grey levels spread 0" in said


def test_a_best_unlike_the_editors_fails_the_smoke(tmp_path, monkeypatch, capsys):
    # The same picture the other way round: as busy, and not the car's.
    channels, rows = release.png_rows(release.BEST_REFERENCE.read_bytes())
    mirrored = [b"".join(bytes(row[at:at + 3]) for at in range(len(row) - channels, -1, -channels))
                for row in rows]
    code, said = _smoke_given(tmp_path, monkeypatch, capsys, _png(mirrored), TRACED)
    assert code == 1
    assert "ok    ...not blank" in said
    assert "FAIL  ...and the editor's own picture of it: SSIM" in said
    assert "tools/release.py best-reference" in said


def test_a_best_that_was_not_path_traced_fails_the_smoke(tmp_path, monkeypatch, capsys):
    code, said = _smoke_given(tmp_path, monkeypatch, capsys, release.BEST_REFERENCE.read_bytes(),
                              "Best is frames averaged here. This graphics card traces no rays.")
    assert code == 1
    assert "FAIL  path-traced Best of the car over MCP: it was not path traced" in said


def test_a_best_with_shapes_refused_fails_the_smoke(tmp_path, monkeypatch, capsys):
    # A part or two missing from the picture is too little for SSIM to see.
    code, said = _smoke_given(tmp_path, monkeypatch, capsys, release.BEST_REFERENCE.read_bytes(),
                              TRACED + "\npath tracer: a shape of 76 triangles was refused")
    assert code == 1
    assert "FAIL  path-traced Best of the car over MCP: the path tracer refused shapes" in said
    assert "ok    ...and the editor's own picture of it" in said


def test_a_check_this_machine_cannot_make_is_said_and_neither_passes_nor_fails(
        tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(release, "opens_models", lambda package, base, env, root: [
        ("a double-click on a model, not run here: no GPU", None, "")])
    code, said = _smoke_given(tmp_path, monkeypatch, capsys,
                              release.BEST_REFERENCE.read_bytes(), "Opened Car.\n" + TRACED)
    assert code == 0, said
    assert "  --    a double-click on a model, not run here: no GPU" in said


def _mac_with(monkeypatch, arm64: str, gpus: str) -> str:
    def run(command, **_):
        out = arm64 if command[0] == "sysctl" else gpus
        return subprocess.CompletedProcess(command, 0, out, "")
    monkeypatch.setattr(release.subprocess, "run", run)
    return release.mac_mode()


def test_an_intel_mac_vm_is_expected_in_the_simpler_mode(monkeypatch):
    # GitHub's macos-15-intel: MoltenVK aborts on this GPU in vkCreateInstance,
    # so the launcher starts it on OpenGL.
    vm = "    Apple Paravirtualized Graphics Device:\n      Chipset Model: Apple Paravirtualized Graphics Device\n"
    assert _mac_with(monkeypatch, "", vm) == "simpler"
    assert _mac_with(monkeypatch, "0\n", vm) == "simpler"


def test_apple_silicon_and_a_real_intel_gpu_are_expected_in_the_full_mode(monkeypatch):
    # macos-15 has the same paravirtual GPU and draws on it through Metal.
    vm = "      Chipset Model: Apple Paravirtualized Graphics Device\n"
    assert _mac_with(monkeypatch, "1\n", vm) == "full"
    assert _mac_with(monkeypatch, "", "      Chipset Model: AMD Radeon Pro 5500M\n"
                                      "      Chipset Model: Intel UHD Graphics 630\n") == "full"


def test_two_mach_o_slices_join_as_lipo_joins_them():
    # The launcher is built per architecture and joined (build_launcher).
    def thin(cpu: int, size: int) -> bytes:
        return struct.pack("<Iii", 0xFEEDFACF, cpu, 3) + bytes(range(256)) * (size // 256)
    intel, arm = thin(0x01000007, 5120), thin(0x0100000C, 20480)
    fat = release.fat_binary([intel, arm])
    assert release.macho_slices(fat) == [("x86_64", intel), ("arm64", arm)]
    # Each slice on a 16 KB boundary, as Apple silicon maps them.
    offsets = [struct.unpack(">I", fat[16 + at * 20:20 + at * 20])[0] for at in range(2)]
    assert offsets == [16384, 16384 * 2]


def _double_clicks_stubbed(monkeypatch, tmp_path) -> list[Path]:
    """Opening models answered here: each opened with 3 parts, in a window
    of its own."""
    monkeypatch.setattr(release, "logs_say", lambda folder, model, seconds: 3)
    monkeypatch.setattr(release, "held_windows", lambda data: [1, 2])
    monkeypatch.setattr(release, "end_windows", lambda data: None)
    models = [tmp_path / "car one.ldr", tmp_path / "car two.ldr"]
    for model in models:
        model.write_text("0 car\n")
    return models


def test_a_double_click_on_a_mac_starts_the_app_with_updates_off(monkeypatch, tmp_path):
    # open(1) starts it through Launch Services, in the person's environment,
    # not clean_env's: an older release under check could update itself.
    models = _double_clicks_stubbed(monkeypatch, tmp_path)
    ran: list[list[str]] = []

    def run(command, **kwargs):
        ran.append(list(command))
        return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

    monkeypatch.setattr(release.subprocess, "run", run)
    # Each window says its graphics mode in its log, as the launcher's choice.
    monkeypatch.setattr(release, "mac_mode", lambda: "full")
    monkeypatch.setattr(release.Path, "home", lambda: tmp_path)
    logs = tmp_path / "Library" / "Application Support" / "Godot" / "app_userdata" / "Brickworks" / "logs"
    logs.mkdir(parents=True)
    (logs / "godot.log").write_text("graphics: full mode (automatic), Metal on Apple M1\n" * 2)
    said = release.double_click_mac(models)
    assert [ok for _, ok, _ in said] == [True, True, True, True, True], said
    assert [c for c in ran if c[0] == "open"] == [
        ["open", "--env", "BRICKWORKS_UPDATES=off", str(model)] for model in models]


def test_a_double_click_on_windows_starts_the_app_with_updates_off(monkeypatch, tmp_path):
    # os.startfile's app inherits this process's environment: off while the
    # models open, and this process's own setting back after.
    models = _double_clicks_stubbed(monkeypatch, tmp_path)
    heard: list[tuple[str, str | None]] = []
    environ = {"APPDATA": str(tmp_path / "AppData"), "BRICKWORKS_UPDATES": "ask"}
    windows = type(sys)("os")
    windows.environ = environ
    windows.startfile = lambda path: heard.append((path, environ.get("BRICKWORKS_UPDATES")))
    monkeypatch.setattr(release, "os", windows)
    monkeypatch.setattr(release, "WINDOWS_INSTALLED", tmp_path / "Programs" / "Brickworks")
    monkeypatch.setattr(release.subprocess, "run", lambda command, **kwargs: None)
    monkeypatch.setattr(release.time, "sleep", lambda seconds: None)
    # A registry with nothing in it: what the installer wrote is not asked here.
    registry = type(sys)("winreg")
    registry.HKEY_CURRENT_USER, registry.HKEY_CLASSES_ROOT = 1, 2

    def no_key(key, path):
        raise OSError(path)

    registry.OpenKey = no_key
    sys.modules["winreg"] = registry
    try:
        said = release.double_click_windows(tmp_path / "Brickworks-9.9.9-windows-x86_64-setup.exe", models)
    finally:
        del sys.modules["winreg"]
    assert heard == [(str(model), "off") for model in models]
    assert environ["BRICKWORKS_UPDATES"] == "ask"
    assert [what for what, ok, _ in said if ok and "double-click" in what] == [
        "a double-click on car one.ldr opens it in Brickworks: 3 parts",
        "a double-click on car two.ldr opens it in Brickworks, the app already open: 3 parts"]


def test_the_smokes_session_keeps_its_tool_list_out_of_the_checkout(tmp_path, monkeypatch):
    # The relay keeps the last tools/list it heard in tools/mcp_tools.json.
    # A package from another commit serves another list, and smoking 0.13.0
    # on 2026-11-01 rewrote the checkout's copy, which mcp_sync then failed.
    checkout = tmp_path / "checkout"
    (checkout / "tools").mkdir(parents=True)
    ours = '[{"name": "place"}]\n'
    (checkout / "tools" / "mcp_tools.json").write_text(ours)
    # The check as the relay behaves: it writes the app's list where it is told.
    (checkout / "tools" / "mcp_check.py").write_text(
        "import os, pathlib\n"
        "here = pathlib.Path(__file__).resolve().parent.parent\n"
        "cache = os.environ.get('BRICKWORKS_MCP_CACHE') or here / 'tools' / 'mcp_tools.json'\n"
        "pathlib.Path(cache).write_text('[{\"name\": \"from_another_commit\"}]\\n')\n"
        "print('a design lands in 2 s')\n")
    app = tmp_path / "app.py"
    app.write_text(
        "import socket, sys, time\n"
        "port = int(next(a for a in sys.argv if a.startswith('--mcp=')).split('=')[1])\n"
        "server = socket.create_server(('127.0.0.1', port))\n"
        "time.sleep(120)\n")
    smoke = tmp_path / "smoke"
    smoke.mkdir()
    monkeypatch.setattr(release, "ROOT", checkout)
    said = release.takes_bricks([sys.executable, str(app)], {"PATH": "/usr/bin:/bin"}, smoke)
    assert [ok for _, ok, _ in said] == [True, True], said
    assert (checkout / "tools" / "mcp_tools.json").read_text() == ours
    assert "from_another_commit" in (smoke / "mcp_tools.json").read_text()


# -- what a desktop needs to open a model in the app -------------------------

def test_the_menu_entry_opens_each_model_type_and_is_valid(tmp_path):
    entry = release.desktop_entry("brickworks", release.APP_ID, "9.9.9")
    fields = dict(line.split("=", 1) for line in entry.splitlines() if "=" in line)
    # %f: a double-click hands over the file, one window each.
    assert fields["Exec"] == "brickworks %f"
    assert fields["MimeType"].rstrip(";").split(";") == [kind["mime"] for kind in release.MODEL_TYPES]
    assert fields["StartupWMClass"] == release.WINDOW_CLASS
    if shutil.which("desktop-file-validate"):
        path = tmp_path / (release.APP_ID + ".desktop")
        path.write_text(entry)
        checked = subprocess.run(["desktop-file-validate", str(path)], capture_output=True, text=True)
        assert (checked.returncode, checked.stdout) == (0, "")


def test_each_model_extension_is_its_own_mime_type(tmp_path):
    import xml.etree.ElementTree as ElementTree
    space = "{http://www.freedesktop.org/standards/shared-mime-info}"
    root = ElementTree.fromstring(release.mime_types())
    globs = {kind.get("type"): [g.get("pattern") for g in kind.iter(space + "glob")]
             for kind in root.iter(space + "mime-type")}
    assert globs == {kind["mime"]: ["*." + kind["ext"]] for kind in release.MODEL_TYPES}
    if shutil.which("update-mime-database") and shutil.which("gio"):
        share = tmp_path / "share"
        release.desktop_files(share, "brickworks")
        subprocess.run(["update-mime-database", str(share / "mime")], capture_output=True, check=True)
        env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp_path), "XDG_DATA_DIRS": str(share)}
        for kind in release.MODEL_TYPES:
            model = tmp_path / ("model." + kind["ext"])
            model.write_bytes(b"0 a model\n" if kind["text"] else b"PK\x03\x04")
            assert release.content_type(model, env) == kind["mime"], kind["ext"]


def test_a_model_s_parts_count_its_sub_models_where_they_are_placed():
    text = (ROOT / "src" / "dev" / "fixtures" / "telescope.mpd").read_text()
    assert release.ldraw_parts(text) == 48
    assert release.ldraw_parts((ROOT / "models" / "car.ldr").read_text()) == 61
    assert release.ldraw_parts("0 FILE a.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 b.ldr\n"
                               "1 4 0 0 0 1 0 0 0 1 0 0 0 1 b.ldr\n0 FILE b.ldr\n"
                               "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
                               "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3002.dat\n") == 4
    # A part carried in the file, as a Studio .io carries its own, is one
    # part however many lines draw it: the app wrote 5 for bay_2025.io and
    # this counted 6 until it read the headers as the app does.
    assert release.ldraw_parts("0 FILE a.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
                               "1 4 0 0 0 1 0 0 0 1 0 0 0 1 custom.dat\n0 FILE custom.dat\n"
                               "0 !LDRAW_ORG Unofficial_Part\n"
                               "1 16 0 0 0 1 0 0 0 1 0 0 0 1 s/custom01.dat\n"
                               "1 16 0 0 0 1 0 0 0 1 0 0 0 1 stud.dat\n") == 2


def test_the_deb_installs_the_app_its_entry_icons_and_types(tmp_path):
    if not shutil.which("dpkg-deb"):
        return
    folder = tmp_path / "Brickworks-9.9.9-linux-x86_64"
    folder.mkdir()
    (folder / "brickworks.x86_64").write_bytes(b"\x7fELF GLIBC_2.31\0")
    (folder / "brickworks.pck").write_bytes(b"GDPC")
    for name in ("README.txt", "ATTRIBUTION.md"):
        (folder / name).write_text("words")
    (folder / "THIRD-PARTY-NOTICES.txt").write_text(WHOLE_NOTICES)
    shutil.copy2(ROOT / "docs" / "ATTRIBUTION.md", folder / "ATTRIBUTION.md")
    kept = release.WORK
    release.WORK = tmp_path / "work"
    try:
        target = tmp_path / "Brickworks-9.9.9-linux-amd64.deb"
        release.write_deb(folder, target, "9.9.9", 1761696000)
    finally:
        release.WORK = kept
    facts = release.inspect_deb(target)
    assert (facts["package"], facts["version"], facts["architecture"]) == ("brickworks", "9.9.9", "amd64")
    assert facts["depends"] == "libc6 (>= 2.31)" and facts["glibc"] == "2.31"
    assert facts["executable"] and facts["command"] == "../lib/brickworks/brickworks.x86_64"
    assert facts["opens"] == [kind["ext"] for kind in release.MODEL_TYPES]
    assert sorted(facts["icons"], key=lambda size: int(size.split("x")[0])) == [
        "%dx%d" % (n, n) for n in (16, 22, 24, 32, 48, 64, 128, 256, 512)]
    assert "usr/share/icons/hicolor/scalable/apps/%s.svg" % release.APP_ID in facts["contents"]
    # A folder of models shows each model: the thumbnailer entry names the
    # runner it carries, executable, for the model files the app draws.
    assert facts["thumbnails"] == ["ldr", "mpd", "io"]
    assert release.THUMBNAILER in facts["contents"]
    assert facts["loose"] == []
    assert facts["licences"]["lacking"] == []


def test_the_thumbnailer_runs_the_app_headless_from_a_data_folder_of_its_own(tmp_path):
    entry = release.thumbnailer_entry()
    assert "TryExec=brickworks-thumbnailer\nExec=brickworks-thumbnailer %i %o %s\n" in entry
    assert "MimeType=application/x-ldraw;application/x-multi-part-ldraw;" \
        "application/x-bricklink-studio;\n" in entry
    # Run as a file browser runs it, with the app swapped for a stand-in that
    # says what it was given: the model, the picture and the size, headless,
    # and a data folder that is not the person's and is gone afterwards.
    (tmp_path / "bin").mkdir()
    lib = tmp_path / "lib" / "brickworks"
    lib.mkdir(parents=True)
    runner = tmp_path / "bin" / "brickworks-thumbnailer"
    runner.write_text(release.thumbnail_runner())
    runner.chmod(0o755)
    app = lib / "brickworks.x86_64"
    app.write_text('#!/bin/sh\necho "$XDG_DATA_HOME" > "$4.data"\necho "$@" > "$4"\n'
                   'touch "$XDG_DATA_HOME/godot.log"\n')
    app.chmod(0o755)
    env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp_path / "home"),
           "TMPDIR": str(tmp_path / "not-in-the-sandbox")}
    done = subprocess.run([str(runner), "/tmp/model.ldr", str(tmp_path / "out.png"), "128"],
                          env=env, capture_output=True, text=True)
    assert done.returncode == 0, done.stderr
    said = (tmp_path / "out.png").read_text().split()
    assert said == ["--headless", "--thumbnail", "/tmp/model.ldr", str(tmp_path / "out.png"),
                    "128"]
    data = (tmp_path / "out.png.data").read_text().strip()
    assert data.startswith("/tmp/brickworks-thumbnail.") and not os.path.exists(data)
    # The app's own exit is the runner's.
    app.write_text("#!/bin/sh\nexit 3\n")
    assert subprocess.run([str(runner), "a", "b"], env=env).returncode == 3


def test_the_disk_image_background_is_one_tiff_with_a_page_at_each_resolution(tmp_path):
    pictures = [((release.PACKAGE_ART / name).read_bytes(), dpi)
                for name, dpi in (("dmg-background.png", 72), ("dmg-background@2x.png", 144))]
    target = tmp_path / "background.tiff"
    release.write_tiff(pictures, target)
    data = target.read_bytes()
    assert data[:4] == b"II*\0"
    pages, at = [], struct.unpack("<I", data[4:8])[0]
    while at:
        count = struct.unpack("<H", data[at:at + 2])[0]
        tags = {}
        for n in range(count):
            tag, kind, _, value = struct.unpack("<HHII", data[at + 2 + 12 * n:at + 14 + 12 * n])
            tags[tag] = value & 0xFFFF if kind == 3 else value
        strip = data[tags[273]:tags[273] + tags[279]]
        dpi = struct.unpack("<I", data[tags[282]:tags[282] + 4])[0]
        pages.append((tags[256], tags[257], dpi, len(zlib.decompress(strip))))
        at = struct.unpack("<I", data[at + 2 + 12 * count:at + 6 + 12 * count])[0]
    width, height = release.DMG_WINDOW
    assert pages == [(width, height, 72, width * height * 3),
                     (width * 2, height * 2, 144, width * height * 12)]


def test_the_notes_say_the_zips_stay_for_one_release(tmp_path):
    files = [{"os": describe["os"], "kind": describe["kind"], "name": name, "size": 1,
              "facts": {"exes": {name: {"signed": False}}} if describe["os"] == "windows" else {}}
             for names in release.artifacts("0.1.0").values() for name in names
             for describe in [release.describe_file(name)]]
    notes = _in(_copy_of_the_three(), lambda: release.release_notes("0.1.0", files, "v0.1.0"))
    assert "zips** are still here for this release" in notes
    assert "drag Brickworks onto Applications" in notes and "setup.exe" in notes
    assert "sudo apt install ./Brickworks-0.1.0-linux-amd64.deb" in notes
