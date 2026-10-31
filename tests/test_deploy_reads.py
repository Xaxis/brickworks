"""tools/release/deploy_reads.sh: when a build of an earlier commit stands for
this one. A release's preview is reused when only checks changed since it was
made (preview_lib.sh), and the same build is promoted (tools/deploy.sh); the
two once disagreed, and rel-m227's production was built afresh (2026-10-31).
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
pytestmark = pytest.mark.skipif(not shutil.which("git"), reason="needs git")


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t", *args],
                          check=True, capture_output=True, text=True).stdout.strip()


def _commit(repo: Path, name: str, text: str) -> str:
    path = repo / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    _git(repo, "add", name)
    _git(repo, "commit", "-q", "-m", name)
    return _git(repo, "rev-parse", "--short", "HEAD")


def _stands(repo: Path, built: str, head: str) -> bool:
    # A clean bash, as ship.sh and deploy.sh run, under pipefail as deploy.sh is.
    script = f'set -o pipefail; . "{ROOT}/tools/release/deploy_reads.sh"; unread_since {built} {head}'
    return subprocess.run(["bash", "--noprofile", "--norc", "-c", script], cwd=repo).returncode == 0


def test_a_build_stands_for_a_later_commit_only_when_nothing_the_deploy_reads_changed(tmp_path):
    repo = tmp_path / "r"
    repo.mkdir()
    _git(repo, "init", "-q")
    built = _commit(repo, "src/main.gd", "extends Node\n")
    checks = _commit(repo, "tools/web/together_flow.mjs", "// the check fixed\n")
    tools = _commit(repo, "tools/release/ship.sh", "#!/bin/bash\n")
    assert _stands(repo, built, checks)
    assert _stands(repo, built, tools)
    # Nothing changed: the caller compares the commits itself.
    assert not _stands(repo, built, built)
    # A file the deploy reads, after the checks that it does not.
    code = _commit(repo, "web/site.css", ":root {}\n")
    assert not _stands(repo, built, code)
    # A helper beside the checks, not a check, is read by them and the site.
    lib = tmp_path / "s"
    lib.mkdir()
    _git(lib, "init", "-q")
    first = _commit(lib, "src/main.gd", "extends Node\n")
    helper = _commit(lib, "tools/web/lib/common.mjs", "export {};\n")
    assert not _stands(lib, first, helper)
    # Not a later commit at all.
    _git(repo, "checkout", "-q", "-b", "other", built)
    apart = _commit(repo, "tools/web/other_flow.mjs", "//\n")
    assert not _stands(repo, checks, apart)
