"""The links release_wt.sh makes in a worktree are ignored by git.

A rule ending in "/" matches only a folder, never a link of the same name:
every unit's worktree listed node_modules, tools/web/node_modules and
assets/generated as untracked, and the release train, which keeps a
worktree with files git does not track, kept all of them (rel-m221b,
2026-10-30). This makes each link release_wt.sh makes, in a repository with
this checkout's .gitignore, and asks git what it does not track.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _links() -> list[str]:
    text = (ROOT / "tools/release/release_wt.sh").read_text()
    return sorted(set(re.findall(r'ln -s\S* \$R/(\S+) "\$W/\1"', text)))


def _untracked(where: Path) -> list[str]:
    out = subprocess.run(["git", "-C", str(where), "status", "--porcelain", "--untracked-files=all"],
                         capture_output=True, text=True, check=True).stdout
    return [line[3:] for line in out.splitlines() if line.startswith("??")]


def test_every_link_release_wt_makes_is_ignored(tmp_path: Path) -> None:
    links = _links()
    assert {"node_modules", "tools/web/node_modules", "assets/generated", "vendor"} <= set(links), links
    target = tmp_path / "elsewhere"
    target.mkdir()
    repo = tmp_path / "repo"
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    (repo / ".gitignore").write_text((ROOT / ".gitignore").read_text())
    for link in links:
        (repo / link).parent.mkdir(parents=True, exist_ok=True)
        (repo / link).symlink_to(target)
    shown = [path for path in _untracked(repo) if path != ".gitignore"]
    assert not shown, f"git lists release_wt.sh's links as untracked: {shown}"


def test_the_check_sees_a_link_left_unignored(tmp_path: Path) -> None:
    # The same, with a link no rule names: it must be listed.
    repo = tmp_path / "repo"
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    (repo / ".gitignore").write_text((ROOT / ".gitignore").read_text())
    (repo / "a_link_of_no_rule").symlink_to(tmp_path)
    assert "a_link_of_no_rule" in _untracked(repo)


def test_the_merges_data_folder_is_ignored(tmp_path: Path) -> None:
    # merge_unit.sh and merge_finish.sh run Godot with its data in the
    # worktree; what Godot writes there must not hold the worktree back.
    folders: set[str] = set()
    for script in ("merge_unit.sh", "merge_finish.sh"):
        text = (ROOT / "tools/release" / script).read_text()
        folders |= set(re.findall(r'XDG_DATA_HOME="\$PWD/([^"/]+)"', text))
    assert folders, "no XDG_DATA_HOME=\"$PWD/...\" in the merge scripts"
    repo = tmp_path / "repo"
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    (repo / ".gitignore").write_text((ROOT / ".gitignore").read_text())
    for folder in folders:
        (repo / folder / "godot/logs").mkdir(parents=True)
        (repo / folder / "godot/logs/godot.log").write_text("a log")
    shown = [path for path in _untracked(repo) if path != ".gitignore"]
    assert not shown, f"git lists what Godot writes in the merges' data folder: {shown}"
