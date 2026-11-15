"""The account menu's Admin, for the site's owner alone (bugbar, 2026-11-13).

The owner: "for me and me only there should be a link to the admin page from
the top nav dropdown menu". The menu draws it from GET /api/people?op=feed_count,
the header's "who you are" (web/follow.js), which says admin: true to the
owner and has no such key for anybody else, not even false: api/admin.js
answers them 404, as if there were no console, and the header says nothing
different. Through api/people.js's real handler (tests/fixtures/menu/
admin_check.mjs).
"""

from __future__ import annotations

import functools
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


@functools.cache
def _answers() -> dict:
    if shutil.which("node") is None:
        pytest.skip("node is not here")
    done = subprocess.run(["node", "tests/fixtures/menu/admin_check.mjs"], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


def test_the_owner_is_told_admin() -> None:
    owner = _answers()["owner"]
    assert owner["status"] == 200
    assert owner.get("admin") is True


def test_nobody_else_has_the_key_at_all() -> None:
    for who in ("other", "unverified", "signed_out"):
        said = _answers()[who]
        assert said["status"] == 200, who
        assert "admin" not in said["keys"], who

