"""First steps' step 3 (web/first-steps.js): a newcomer who chose a kind is shown that kind's models
first, from its own Top builds, not only the few on Top's first page (tests/web/first_steps.test.mjs,
under node)."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")


@pytest.mark.skipif(NODE is None, reason="no node on PATH")
def test_chosen_kinds_come_first_from_their_own_top():
    reply = subprocess.run([NODE, "--test", str(ROOT / "tests/web/first_steps.test.mjs")],
                           capture_output=True, text=True, timeout=120)
    assert reply.returncode == 0, reply.stdout[-3000:] + reply.stderr[-2000:]
    assert "fail 0" in reply.stdout
    assert "pass 5" in reply.stdout
