"""Tests for tools/design_ladder.py: the rungs between a real set and a naive stack of it.

A ladder is worth something only if each rung takes away what it says and
nothing it does not: rung 2 leaves no part with its studs off up, rung 3 no
curve, rung 4 no more than three solid colours, rung 5 only plain bricks,
each keeps the set's size, and each is the one above it with one more thing
gone. Pinned on three real sets of the proof half, each a different kind of
build: Big Ben (a tower of SNOT panels and arches), Valentine's Bee (a small
character, half its parts sideways) and the Container Stacker (a vehicle).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import design_ladder  # noqa: E402
import style  # noqa: E402
from bench import calibrate, realset  # noqa: E402

SETS = ("21013-1", "40270-1", "7992-1")
needs_sets = pytest.mark.skipif(
    not all((realset.FILES / f"{n}.mpd").exists() for n in SETS)
    or not style.CATALOGUE.exists() or not (style.LDRAW / "parts").is_dir(),
    reason="no vendor/omr, catalogue or LDraw library")


@pytest.fixture(scope="module")
def made():
    parts, palette = style.Parts(), calibrate.palette()
    out = {}
    for number in SETS:
        text = (realset.FILES / f"{number}.mpd").read_text(errors="replace")
        rungs = design_ladder.ladder(text, parts, palette)
        out[number] = {1: text, **{k: body for k, (body, _said) in rungs.items()}}
    return out, parts, palette


def _measured(text: str, parts: style.Parts) -> tuple[dict, list]:
    model = style.read(text)
    placed = [(p, i) for p in model.placed for i in [parts.get(p.part, model.embedded)]
              if style.building(i)]
    boxes = style._boxes(placed, parts)
    return style.measure(model, parts), boxes


def _span(boxes) -> list[float]:
    return [max(b.centre[k] + b.half[k] for b in boxes) - min(b.centre[k] - b.half[k]
                                                              for b in boxes) for k in range(3)]


@needs_sets
def test_snot_out_leaves_no_part_off_studs_up(made):
    rungs, parts, _palette = made
    for number in SETS:
        before, _b = _measured(rungs[number][1], parts)
        after, _a = _measured(rungs[number][2], parts)
        assert before["snot"] > 0.15, number          # each set has SNOT to take out
        assert after["snot"] == 0.0, number


@needs_sets
def test_curves_stepped_leaves_no_curve(made):
    rungs, parts, _palette = made
    for number in SETS:
        before, _b = _measured(rungs[number][2], parts)
        after, _a = _measured(rungs[number][3], parts)
        assert before["curve"] > 0.05, number
        assert after["curve"] == 0.0, number
        assert after["snot"] == 0.0, number           # what rung 2 took stays out


@needs_sets
def test_colours_flattened_to_three_solid_ones(made):
    rungs, parts, palette = made
    for number in SETS:
        model = style.read(rungs[number][4])
        solid = {p.colour for p in model.placed
                 if p.colour != 16 and not calibrate._transparent(p.colour, palette)}
        before = {p.colour for p in style.read(rungs[number][3]).placed
                  if p.colour != 16 and not calibrate._transparent(p.colour, palette)}
        assert len(solid) <= design_ladder.COLOURS_KEPT < len(before), number


@needs_sets
def test_naive_stack_is_plain_bricks(made):
    rungs, parts, _palette = made
    for number in SETS:
        model = style.read(rungs[number][5])
        assert model.placed, number
        assert {p.part for p in model.placed} <= {b[2] for b in calibrate.BRICKS}, number


@needs_sets
def test_every_rung_keeps_the_sets_size(made):
    rungs, parts, _palette = made
    for number in SETS:
        _m, boxes = _measured(rungs[number][1], parts)
        size = _span(boxes)
        for k in (2, 3, 4, 5):
            _m, boxes = _measured(rungs[number][k], parts)
            for a, b in zip(size, _span(boxes)):
                assert abs(a - b) <= 2 * design_ladder.STUD, (number, k, size, _span(boxes))


@needs_sets
def test_rungs_are_cumulative(made):
    """Each of rungs 2 to 4 keeps only parts the rung above it kept, where they were."""
    rungs, parts, _palette = made

    def lines(text: str) -> set[tuple]:
        out = set()
        for line in text.splitlines():
            bits = line.split()
            if len(bits) >= 15 and bits[0] == "1" and not bits[14].startswith(("3020", "3021",
                                                                                "3022", "3710",
                                                                                "3623", "3023",
                                                                                "3024")):
                out.add((tuple(round(float(v), 1) for v in bits[2:5]), bits[14].lower()))
        return out

    for number in SETS:
        two, three, four = (lines(rungs[number][k]) for k in (2, 3, 4))
        assert three <= two, number
        assert four == three, number


@needs_sets
def test_a_set_written_untouched_keeps_every_part_where_it_was(made):
    _rungs, parts, _palette = made
    for number in SETS:
        text = (realset.FILES / f"{number}.mpd").read_text(errors="replace")
        rung = design_ladder.start(text, parts)
        again = style.read(design_ladder.write(rung, "untouched"))
        before = style.read(text)
        assert len(again.placed) == len(before.placed)
        for p, q in zip(before.placed, again.placed):
            assert p.part == q.part and p.colour == q.colour
            assert abs(p.matrix.x - q.matrix.x) < 0.01 and abs(p.matrix.y - q.matrix.y) < 0.01
            assert abs(p.matrix.e - q.matrix.e) < 1e-3


def test_a_turned_frame_is_undone_on_writing():
    """A model saved turned on the spot is laid square, and written back turned."""
    import math
    turn = math.radians(30)
    c, s = math.cos(turn), math.sin(turn)
    lines = [f"1 4 {40 * k * c:.4f} 0 {40 * k * s:.4f} {c:.6f} 0 {-s:.6f} 0 1 0 {s:.6f} 0 {c:.6f} 3001.dat"
             for k in range(4)]
    parts = style.Parts.of({"3001": style.PartInfo("Brick 2 x 4", "Brick",
                                                    ((-40, -4, -20), (40, 24, 20)))})
    rung = design_ladder.start("\n".join(lines), parts)
    assert not design_ladder._identity(rung.fix)
    again = style.read(design_ladder.write(rung, "turned"))
    first = style.read("\n".join(lines)).placed[0].matrix
    assert abs(again.placed[0].matrix.a - first.a) < 1e-4
    assert abs(again.placed[0].matrix.c - first.c) < 1e-4


def test_walk_places_by_where_the_verdicts_turn():
    def asked(shares):
        return lambda rung: shares[rung]
    # Loses to the set and rung 2, beats rung 3: between 2 and 3.
    assert design_ladder.walk(asked({1: 0, 2: 0, 3: 1, 4: 1, 5: 1})) == 2.5
    # Ties rung 3.
    assert design_ladder.walk(asked({3: 0.5})) == 3.0
    # Loses to everything: below the naive stack.
    assert design_ladder.walk(asked({3: 0, 4: 0, 5: 0})) == 5.5
    # Beats everything, the set too: above it.
    assert design_ladder.walk(asked({3: 1, 2: 1, 1: 1})) == 0.5
    # Loses to 3, splits with 4.
    assert design_ladder.walk(asked({3: 0, 4: 0.5})) == 4.0
    # Loses to 3 and 4, beats 5.
    assert design_ladder.walk(asked({3: 0, 4: 0, 5: 1})) == 4.5


def test_the_leak_audit_flags_the_ladder_in_an_answer(tmp_path):
    session = tmp_path / "session.jsonl"
    rows = [
        {"type": "assistant", "message": {"content": [
            {"type": "tool_use", "id": "t1", "name": "mcp__brickworks__open_model",
             "input": {"name": "/mnt/Projects/brickworks/bench/ladder/21013-1/r2.mpd"}}]}},
        {"type": "user", "message": {"content": [
            {"type": "tool_result", "tool_use_id": "t1",
             "content": [{"type": "text", "text": "Opened bench/ladder/21013-1/r2.mpd"}]}]}},
        {"type": "user", "message": {"content": [
            {"type": "tool_result", "tool_use_id": "t1",
             "content": [{"type": "text", "text": "No model called Big Ben."}]}]}},
    ]
    session.write_text("\n".join(json.dumps(r) for r in rows))
    hits = design_ladder.leak_hits(session, "21013", "Big Ben")
    assert any(h.startswith("call open_model: the ladder") for h in hits)
    assert sum(h.startswith("answer of open_model: the ladder") for h in hits) == 1
