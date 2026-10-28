"""Tests for tools/bench/ideas.py: the fixed briefs, and whose share the head to head reports.

realset's compare prints the first arm's share under a header that names
no arm, and a reader once took it for the second's. Here verdicts written
by hand, one arm winning some dimensions in both orders and the other arm
the rest, must come out as each arm's share in the column named for it,
and turn over when the arms are given the other way round. The compare is
also run end to end on records and pictures written here, with the canned
judge, so its files and keys are pinned as well as its arithmetic.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from bench import ideas, pairwise, realset  # noqa: E402
from bench.ideas_briefs import IDEAS, KINDS, by_id  # noqa: E402


def _record(arm: str, idea, made: bool = True, brief: str | None = None) -> dict:
    return {"id": idea.id, "kind": idea.kind, "brief": brief or idea.brief, "arm": arm,
            "date": "D", "key": f"ideas:{arm}:D:{idea.id}",
            "design": {"model": made, "design_seconds": 600},
            **({"measures": {"parts": 300}} if made else {})}


def _row(text: str, dim: str) -> list[str]:
    line = next(line for line in text.splitlines() if line.startswith(f"| {dim} |"))
    return [cell.strip() for cell in line.strip("|").split("|")][1:]


def _header(text: str) -> list[str]:
    line = next(line for line in text.splitlines() if line.startswith("| dimension |"))
    return [cell.strip() for cell in line.strip("|").split("|")]


# -- the briefs -----------------------------------------------------------------


def test_the_briefs_are_twenty_original_ideas_across_every_kind():
    assert len(IDEAS) == 20 and len({i.id for i in IDEAS}) == 20
    assert {i.kind for i in IDEAS} == set(KINDS)
    # Their first eight take turns over the kinds, so --first 8 is a spread too.
    assert len({i.kind for i in IDEAS[:8]}) == len(KINDS)
    for idea in IDEAS:
        # An idea in a person's words, with several things in it; never a set's name.
        assert "in the style of LEGO" not in idea.brief, idea.id
        assert idea.brief.count(",") >= 3, idea.id
        assert by_id(idea.id) is idea


# -- whose share ----------------------------------------------------------------


def test_the_compare_reports_the_share_of_the_arm_its_column_names():
    idea = IDEAS[0]
    left, right = _record("left", idea), _record("right", idea)
    lk, rk = left["key"], right["key"]
    won = {"likeness": lk, "realism": rk, "creativity": rk, "technique": rk, "overall": lk}
    said = [pairwise.Verdict(lk, rk, won, {}), pairwise.Verdict(rk, lk, won, {})]

    text = ideas.compare_report(["left", "right"], ["D", "D"], [(idea, left, right, said)], [])
    assert "share of verdicts that preferred left's design to right's" in text
    assert _header(text) == ["dimension", "left preferred", "95% interval of left's share",
                             "right preferred"]
    for dim in ("likeness", "overall"):
        assert _row(text, dim)[0] == "100%" and _row(text, dim)[2] == "0%", dim
    for dim in ("realism", "creativity", "technique"):
        assert _row(text, dim)[0] == "0%" and _row(text, dim)[2] == "100%", dim
    assert "the two orders named the same design on 5 of 5 (100%)" in text.lower()
    assert "the design shown first won 5 of 10 (50%)" in text

    # The same verdicts with the arms given the other way round: right's share now.
    turned = ideas.compare_report(["right", "left"], ["D", "D"],
                                  [(idea, right, left, said)], [])
    assert _header(turned)[1] == "right preferred"
    assert _row(turned, "likeness")[0] == "0%" and _row(turned, "realism")[0] == "100%"


def test_a_brief_one_arm_made_nothing_for_is_lost_by_it_on_every_dimension():
    idea = IDEAS[1]
    made, empty = _record("made", idea), _record("empty", idea, made=False)
    for dim in ideas.DIMS:
        assert ideas.share_won(made, empty, [], dim) == 1.0
        assert ideas.share_won(empty, made, [], dim) == 0.0
    # Both made and nothing judged is no verdict, not a draw.
    assert ideas.share_won(made, _record("other", idea), [], "overall") is None
    text = ideas.compare_report(["empty", "made"], ["D", "D"], [(idea, empty, made, [])], [])
    assert _row(text, "overall")[0] == "0%" and _row(text, "overall")[2] == "100%"
    assert "1 of them made by one arm only" in text


def test_a_reply_is_read_on_the_ideas_dimensions_and_the_prompt_asks_them():
    reply = json.loads(ideas.CANNED_PAIR.read_text())
    verdict = realset.parse(reply, "a", "b", ideas.DIMS)
    assert set(verdict.winners) == set(ideas.DIMS)
    assert verdict.winners["likeness"] == "a" and verdict.winners["realism"] == "b"
    text = realset.prompt(IDEAS[0].brief, (), (), ideas.QUESTION)
    assert IDEAS[0].brief in text
    for dim in ideas.DIMS:
        assert f"  {dim}: {ideas.RUBRIC[dim]}" in text
    assert "surface:" not in text
    assert ideas.QUESTION.schema()["required"] == ["looked_at", *ideas.DIMS]


# -- end to end -----------------------------------------------------------------


def test_compare_judges_both_orders_and_leaves_out_a_changed_brief(tmp_path, monkeypatch):
    monkeypatch.setattr(ideas, "RESULTS", tmp_path)
    monkeypatch.setattr(realset, "BLIND", tmp_path / "blind")
    both, changed, alone = IDEAS[0], IDEAS[1], IDEAS[2]
    for arm in ("x", "y"):
        for idea in (both, changed, alone):
            made = arm == "x" or idea is not alone
            record = _record(arm, idea, made, "older words" if idea is changed and arm == "y"
                             else None)
            where = ideas.arm_dir("D", arm) / idea.id
            where.mkdir(parents=True)
            (where / "record.json").write_text(json.dumps(record))
            for view in ideas.VIEWS:
                (where / f"views_{view}.png").write_bytes(f"{arm}{view}".encode())
    args = argparse.Namespace(arms="x,y", dates="", date="D", jobs=1, judge_model="opus",
                              dry_run=True, first=0,
                              subjects=",".join(i.id for i in (both, changed, alone)))
    assert ideas.compare(args) == 0
    text = (tmp_path / "ideas-D-x-vs-y" / "report.md").read_text()
    assert f"Left out: {changed.id} (its brief changed since a design)" in text
    assert "2 briefs judged, 1 of them made by one arm only" in text
    # Two verdicts asked, one each way round, for the brief both arms made.
    asked = sorted(p.name for p in (tmp_path / "ideas-D-x-vs-y" / both.id).glob("*-*.json"))
    assert len(asked) == 2
    # The canned judge picks A on likeness both times: a split, so 50% for that brief,
    # and x's lone design wins the other brief outright: 75% to x, 25% to y.
    assert _row(text, "likeness")[0] == "75%" and _row(text, "likeness")[2] == "25%"
