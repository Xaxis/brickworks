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

import shutil
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
