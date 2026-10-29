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
import shutil
import subprocess
import sys
import tempfile
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
        "Brickworks-1.2.3-linux-x86_64.tar.xz": {"os": "linux", "arch": "x86_64", "kind": "tar.xz"},
        "Brickworks-1.2.3-macos-universal.zip": {"os": "macos", "arch": "universal", "kind": "zip"},
        "Brickworks-1.2.3-windows-x86_64.zip": {"os": "windows", "arch": "x86_64", "kind": "zip"},
    }


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


def _publish_with_github_stubbed(draft: bool, existing: bool) -> list[list[str]]:
    """Every command publish runs, with GitHub and git answered here: a
    one-file build, a draft already up or none, and GitHub's SHA-256 the
    file's own."""
    where = Path(tempfile.mkdtemp(prefix="brickworks-release-test-"))
    package = where / "Brickworks-9.9.9-linux-x86_64.tar.xz"
    package.write_bytes(b"a package")
    (where / "SHA256SUMS").write_text("%s  %s\n" % (release.sha256_of(package), package.name))
    files = [package, where / "SHA256SUMS"]
    held = {"url": "https://github.com/%s/releases/tag/v9.9.9" % release.REPO, "isDraft": True,
            "databaseId": 1, "assets": [{"name": p.name, "size": p.stat().st_size} for p in files]}
    views = [held if existing else None, {**held, "isDraft": draft}]
    ran: list[list[str]] = []

    def run(command, **kwargs):
        ran.append(list(command))
        out = ""
        if command[:2] == ["gh", "api"]:
            out = json.dumps({"assets": [{"name": p.name, "digest": "sha256:" + release.sha256_of(p),
                                          "browser_download_url": "https://example/" + p.name}
                                         for p in files]})
        elif command[:2] == ["git", "rev-parse"]:
            out = "f" * 40
        return subprocess.CompletedProcess(command, 0, stdout=out, stderr="")

    kept = (release.release_view, release.check_version, release.built, release.subprocess.run)
    release.release_view = lambda tag: views.pop(0)
    release.check_version = lambda: []
    release.built = lambda version: (where, {"commit": "x", "files": [
        {"name": package.name, "os": "linux", "size": package.stat().st_size, "facts": {}}]})
    release.subprocess.run = run
    try:
        release.publish(draft, "v9.9.9", "abc", False)
    finally:
        release.release_view, release.check_version, release.built, release.subprocess.run = kept
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
