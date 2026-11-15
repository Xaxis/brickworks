"""The api's counts hold past PostgREST's page of 1,000 rows.

Supabase's PostgREST gives at most 1,000 rows a read (max-rows), whatever
limit the read asks for, and says nothing of what it left out. lists1's
review found a list of 2,000 sets read as 1,000 (api/_db.js dbAll, dbCount);
webfaults (2026-11-14) found the same in a day's likes in Notifications, in
each person's models and connectors on the owner's People page, and in the
connector page's tabs. Through the real handlers, against a stand-in that
stops at 1,000 as the project does (tests/fixtures/rowcap/rowcap_check.mjs).
"""

from __future__ import annotations

import functools
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


@functools.cache
def _counted() -> dict:
    if shutil.which("node") is None:
        pytest.skip("node is not here")
    done = subprocess.run(["node", "tests/fixtures/rowcap/rowcap_check.mjs"], cwd=ROOT, capture_output=True,
                          text=True, timeout=120, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


def test_a_days_likes_are_all_counted() -> None:
    assert _counted()["likes"] == 1500


def test_the_owners_people_page_counts_every_model_and_connector() -> None:
    assert _counted()["models"] == 1500
    assert _counted()["connectors"] == 1500


def test_the_connector_page_lists_every_tab() -> None:
    assert _counted()["tabs"] == 1500


def test_no_read_asks_for_more_than_a_page_gives() -> None:
    # A read that asks for more than 1,000 rows is given 1,000 and believes
    # it has them all: page it (dbAll) or count it (dbCount).
    over = []
    for path in sorted((ROOT / "api").glob("*.js")):
        for n, line in enumerate(path.read_text().splitlines(), 1):
            for asked in re.findall(r"[?&]limit=(\d+)", line):
                if int(asked) > 1000:
                    over.append(f"{path.name}:{n} limit={asked}")
    assert not over, over
