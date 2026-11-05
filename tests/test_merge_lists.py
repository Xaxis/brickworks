"""tools/merge_lists.py: a merge lists each probe once, through the real merge.

Each case is a throwaway repo with this checkout's .gitattributes and driver,
a base, a release side (ours) and a unit (theirs), merged by
tools/release/merge_unit.sh as a train merges a unit, and so with no driver
in the repo's own config, as on a fresh clone. The first is the merge that
listed steps_kept twice (62d9de65, fe6808ae).
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID = ["-c", "user.name=Xaxis", "-c", "user.email=william.neeley@gmail.com"]
HEADLESS = "tools/suite/headless.txt"
OUT = "tools/suite/out.txt"
LATER = "supabase/later.tsv"

HEADER = ["# The probes run headless, one a line.", "#"]
KEPT = "steps_kept   # keeps its numbers (stepsnum)"
KEPT_MARKS = "steps_kept   # keeps its numbers and section marks (stepsnum, sectionmarks)"
CHAT = "together_chat   # chat ends on its newest line (layoutwait)"


def git(where: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *ID, *args], cwd=where, capture_output=True, text=True)


def write(where: Path, files: dict[str, list[str]]) -> None:
    for name, lines in files.items():
        path = where / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(line + "\n" for line in lines))


def sides(tmp: Path, base: dict, ours: dict, theirs: dict) -> Path:
    """A repo at the base on main, the unit on branch unit, main moved on."""
    repo = tmp / "repo"
    (repo / "tools").mkdir(parents=True)
    shutil.copy(ROOT / ".gitattributes", repo / ".gitattributes")
    shutil.copy(ROOT / "tools" / "merge_lists.py", repo / "tools" / "merge_lists.py")
    write(repo, {"CHANGELOG.md": ["# Changelog", "", "## [Unreleased]", "", "## [0.1.0]"]})
    write(repo, base)
    assert git(repo, "init", "-q", "-b", "main").returncode == 0
    for side, branch in ((None, None), (theirs, "unit"), (ours, "main")):
        if branch:
            git(repo, "checkout", "-q", "-B", branch, "base")
            write(repo, side)
            for name in base:
                if name not in side:
                    (repo / name).unlink()
        git(repo, "add", "-A")
        assert git(repo, "commit", "-q", "-m", branch or "base").returncode == 0
        if not branch:
            git(repo, "tag", "base")
    return repo


def merge_unit(repo: Path) -> subprocess.CompletedProcess:
    env = dict(os.environ, MERGE_ONLY="1")
    return subprocess.run(["bash", str(ROOT / "tools/release/merge_unit.sh"), str(repo), "unit",
                           "Merge: the unit"], cwd=repo, env=env, capture_output=True, text=True)


def merged(tmp: Path, base: dict, ours: dict, theirs: dict) -> dict[str, list[str]]:
    repo = sides(tmp, base, ours, theirs)
    done = merge_unit(repo)
    assert done.returncode == 0, done.stdout + done.stderr
    assert git(repo, "status", "--porcelain").stdout.strip() == ""
    return {name: (repo / name).read_text().splitlines() if (repo / name).exists() else None
            for name in set(base) | set(ours) | set(theirs)}


def test_a_comment_edited_beside_a_new_probe_lists_the_probe_once(tmp_path):
    """The merge that broke: the unit edits steps_kept's comment, the release
    adds together_chat after it. A union kept both steps_kept lines."""
    base = {HEADLESS: HEADER + ["mcp_sync", KEPT]}
    got = merged(tmp_path, base, {HEADLESS: HEADER + ["mcp_sync", KEPT, CHAT]},
                 {HEADLESS: HEADER + ["mcp_sync", KEPT_MARKS]})
    assert got[HEADLESS] == HEADER + ["mcp_sync", CHAT, KEPT_MARKS]


def test_an_edit_on_the_release_side_holds_beside_the_units_new_probe(tmp_path):
    base = {HEADLESS: HEADER + ["mcp_sync", KEPT]}
    got = merged(tmp_path, base, {HEADLESS: HEADER + ["mcp_sync", KEPT_MARKS]},
                 {HEADLESS: HEADER + ["mcp_sync", KEPT, CHAT]})
    assert got[HEADLESS] == HEADER + ["mcp_sync", KEPT_MARKS, CHAT]


def test_both_sides_new_probes_are_kept_and_comments_keep_their_place(tmp_path):
    middle = ["", "# The ones in a window's size:", "responsive:--size 390x844   # a phone"]
    base = {HEADLESS: HEADER + ["mcp_sync"] + middle + ["snap"]}
    got = merged(tmp_path, base, {HEADLESS: HEADER + ["mcp_sync"] + middle + ["snap", "ours_new"]},
                 {HEADLESS: HEADER + ["mcp_sync"] + middle + ["snap", "theirs_new   # (unit)"]})
    assert got[HEADLESS] == HEADER + ["mcp_sync"] + middle + ["snap", "ours_new", "theirs_new   # (unit)"]


def test_a_probe_removed_on_either_side_stays_removed(tmp_path):
    """A union brings a line back that one side took out when the other
    added one beside it."""
    base = {HEADLESS: ["a", "b", "c"]}
    got = merged(tmp_path, base, {HEADLESS: ["a", "c"]}, {HEADLESS: ["a", "b", "b2", "c"]})
    assert got[HEADLESS] == ["a", "b2", "c"]
    got = merged(tmp_path / "2", base, {HEADLESS: ["a", "b", "b2", "c"]}, {HEADLESS: ["a", "c"]})
    assert got[HEADLESS] == ["a", "b2", "c"]


def test_a_probe_changed_both_ways_takes_the_unit_merged_in(tmp_path):
    base = {HEADLESS: ["a", "b   # base"]}
    got = merged(tmp_path, base, {HEADLESS: ["a", "b:--fast   # release"]},
                 {HEADLESS: ["a", "b   # unit", "c"]})
    assert got[HEADLESS] == ["a", "b   # unit", "c"]


def test_a_probe_moved_out_of_out_txt_is_run_and_not_also_out(tmp_path):
    """check.sh's twice check was written for this one: a unit moves a probe
    from out.txt to headless.txt while the release adds one beside it."""
    base = {OUT: ["bakeoff   # spends money", "fixed_now   # fails: 11-01"], HEADLESS: ["a"]}
    got = merged(tmp_path, base,
                 {OUT: ["bakeoff   # spends money", "fixed_now   # fails: 11-01", "slow   # a bench"],
                  HEADLESS: ["a"]},
                 {OUT: ["bakeoff   # spends money"], HEADLESS: ["a", "fixed_now   # (fixedunit)"]})
    assert got[OUT] == ["bakeoff   # spends money", "slow   # a bench"]
    assert got[HEADLESS] == ["a", "fixed_now   # (fixedunit)"]


def test_a_later_row_edited_beside_a_new_row_is_one_row(tmp_path):
    """supabase/later.tsv has the same union: a row's words edited on one
    side came out beside the old row. The same function from the same
    earlier file, replaced by another later file, is a row of its own."""
    head = ["# Functions a later file replaced, one a line, tab-separated:"]
    row = "notifications.sql\tnotification_rows\tachievements.sql\t'achieve'"
    fixed = "notifications.sql\tnotification_rows\tachievements.sql\t'achievement'::text"
    other = "notifications.sql\tnotification_rows\tchallenge_notices.sql\t'challenge_open'::text"
    base = {LATER: head + [row]}
    got = merged(tmp_path, base, {LATER: head + [row, other]}, {LATER: head + [fixed]})
    assert got[LATER] == head + [other, fixed]


def test_a_probe_one_side_already_lists_twice_is_left_for_check_sh(tmp_path):
    """Nothing is dropped to hide it: check.sh --lists names it."""
    base = {HEADLESS: ["a", "b"]}
    got = merged(tmp_path, base, {HEADLESS: ["a", "b", "a   # again"]}, {HEADLESS: ["a", "b", "c"]})
    assert got[HEADLESS] == ["a", "b", "a   # again", "c"]


def test_with_no_driver_configured_a_merge_stops_rather_than_list_a_probe_twice(tmp_path):
    """A by-hand merge in a clone whose .git/config lacks merge.lists: git's
    text merge, a conflict to settle, never the union's duplicate."""
    base = {HEADLESS: HEADER + ["mcp_sync", KEPT]}
    repo = sides(tmp_path, base, {HEADLESS: HEADER + ["mcp_sync", KEPT, CHAT]},
                 {HEADLESS: HEADER + ["mcp_sync", KEPT_MARKS]})
    done = git(repo, "merge", "--no-ff", "--no-commit", "unit")
    assert done.returncode != 0
    assert git(repo, "diff", "--name-only", "--diff-filter=U").stdout.split() == [HEADLESS]
