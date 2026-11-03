"""Whom the switch to live comps with Pro (tools/plan_comps.py, docs/PLANS.md 8.7).

Every account made before 29 October 2026 keeps Pro free, as /plans promised
then; the owner's has every feature already, and an account made on the day
or after has no promise to keep.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import plan_comps  # noqa: E402


def test_accounts_made_before_29_october_are_comped_and_the_owners_is_not() -> None:
    users = [
        {"id": "b", "created_at": "2026-10-28T23:59:59.999Z", "email": "someone@example.com"},
        {"id": "a", "created_at": "2026-09-20T22:22:51Z", "email": "Owner@Example.com"},
        {"id": "c", "created_at": "2026-10-29T00:00:00Z", "email": "later@example.com"},
        {"id": "d", "created_at": "2026-10-01T08:00:00Z", "email": None},
        {"id": "e", "created_at": "2026-11-03T08:00:00Z", "email": "new@example.com"},
    ]
    assert plan_comps.comped(users, "owner@example.com") == ["b", "d"]
    # Without MASTER_EMAIL nobody is left out for being the owner.
    assert plan_comps.comped(users, "") == ["a", "b", "d"]
