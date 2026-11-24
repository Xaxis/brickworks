"""Tests for tools/design_ladder.py: the rungs between a real set and a naive stack of it.

A ladder is worth something only if each rung takes away what it says and
nothing it does not: rung 1.5 lays half of what rung 2 lays, rung 2 leaves no
part with its studs off up but what rolls, rung 3 no curve and no wheel laid
sideways, rung 4 no more than three solid colours, rung 5 only plain bricks,
each keeps the set's size, and each is the one above it with more gone.
Pinned on four real sets of the proof half, each a different kind of build:
Big Ben (a tower of SNOT panels and arches), Valentine's Bee (a small
character, half its parts sideways), the Container Stacker (a vehicle) and
the Technic Corvette (a frame of beams under panels).
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
from bench import calibrate, pairwise, realset  # noqa: E402

SETS = ("21013-1", "40270-1", "7992-1")
TECHNIC = "42093-1"
needs_sets = pytest.mark.skipif(
    not all((realset.FILES / f"{n}.mpd").exists() for n in SETS)
    or not (realset.FILES / f"{TECHNIC}.mpd").exists()
    or not style.CATALOGUE.exists() or not (style.LDRAW / "parts").is_dir(),
    reason="no vendor/omr, catalogue or LDraw library")


@pytest.fixture(scope="module")
def made():
    parts, palette = style.Parts(), calibrate.palette()
    out = {}
    for number in (*SETS, TECHNIC):
        text = (realset.FILES / f"{number}.mpd").read_text(errors="replace")
        rungs = design_ladder.ladder(text, parts, palette, technic=number == TECHNIC)
        # "flat": the set written untouched, its submodels' parts each on its own line.
        flat = design_ladder.write(design_ladder.start(text, parts), design_ladder.RUNGS[1])
        out[number] = {1: text, "flat": flat,
                       **{k: body for k, (body, _said) in rungs.items()}}
    return out, parts, palette


def _off_up(text: str, parts: style.Parts) -> list[tuple[style.Placed, style.PartInfo]]:
    """The parts of a rung whose studs do not point up, as rung 2 reads them."""
    model = style.read(text)
    pairs = [(p, parts.get(p.part, model.embedded)) for p in model.placed]
    return [(p, i) for p, i in pairs if i is not None and design_ladder.off_up(p, i)]


LAID_AS = ("3020", "3021", "3022", "3710", "3623", "3023", "3024")    # the plates a rung lays


def _kept(text: str) -> set[tuple]:
    """A rung's parts but the plain plates it lays, by where they are and what."""
    out = set()
    for line in text.splitlines():
        bits = line.split()
        if len(bits) >= 15 and bits[0] == "1" and not bits[14].startswith(LAID_AS):
            out.add((tuple(round(float(v), 1) for v in bits[2:5]), bits[14].lower()))
    return out


def _measured(text: str, parts: style.Parts) -> tuple[dict, list]:
    model = style.read(text)
    placed = [(p, i) for p in model.placed for i in [parts.get(p.part, model.embedded)]
              if i is not None and style.building(i)]
    boxes = style._boxes(placed, parts)
    return style.measure(model, parts), boxes


def _span(boxes) -> list[float]:
    return [max(b.centre[k] + b.half[k] for b in boxes) - min(b.centre[k] - b.half[k]
                                                              for b in boxes) for k in range(3)]


@needs_sets
def test_snot_out_leaves_no_part_off_studs_up_but_what_rolls(made):
    rungs, parts, _palette = made
    for number in SETS:
        before, _b = _measured(rungs[number][1], parts)
        assert before["snot"] > 0.15, number          # each set has SNOT to take out
        left = _off_up(rungs[number][2], parts)
        assert all(design_ladder.rolling(i) for _p, i in left), (number, left[:3])
        # Rung 3 lays the wheels too: no part off studs up at all.
        after, _a = _measured(rungs[number][3], parts)
        assert after["snot"] == 0.0, number


@needs_sets
def test_rung_two_keeps_the_wheels_where_the_set_has_them(made):
    """The Container Stacker and the Corvette roll on wheels laid sideways: rung 2 keeps
    each, in its place, and rung 3 lays them as plates."""
    rungs, parts, _palette = made
    for number in ("7992-1", TECHNIC):
        wheels = {k for k in _kept(rungs[number]["flat"])
                  for p, i in _off_up(rungs[number]["flat"], parts)
                  if design_ladder.rolling(i) and k[1] == p.part.lower() + ".dat"
                  and abs(k[0][0] - round(p.matrix.x, 1)) < 0.2}
        assert len(wheels) >= 2, number
        assert wheels <= _kept(rungs[number][2]), number
        assert not wheels & _kept(rungs[number][3]), number
    assert not design_ladder.rolling(style.PartInfo("Car Steering Wheel 2L", "Car"))
    assert design_ladder.rolling(style.PartInfo("Tyre 14/ 50 x 17", "Tyre"))
    assert design_ladder.rolling(style.PartInfo("Technic Axle 3 with Stud", "Technic"))


@needs_sets
def test_rung_one_and_a_half_lays_half_of_what_rung_two_lays(made):
    """1.5 sits between the set and rung 2: it keeps every part rung 2 keeps, lays
    some of what rung 2 lays and leaves some, and never lays a wheel."""
    rungs, parts, _palette = made
    for number in (*SETS, TECHNIC):
        one, half, two = (_kept(rungs[number][k]) for k in ("flat", 1.5, 2))
        assert two < half < one, number
        assert {k for k in one - half} < one - two, number


@needs_sets
def test_a_system_sets_half_is_its_smaller_snot_parts(made):
    rungs, parts, _palette = made
    for number in SETS:
        laid_half = _off_up(rungs[number]["flat"], parts)
        kept = _kept(rungs[number][1.5])
        size = {}
        laid, left = [], []
        for p, i in laid_half:
            if design_ladder.rolling(i) or p.part.startswith(LAID_AS):
                continue            # a plain plate can't be told from the plates laid
            key = ((round(p.matrix.x, 1), round(p.matrix.y, 1), round(p.matrix.z, 1)),
                   p.part.lower() + ".dat")
            size[key] = design_ladder._volume(i)
            (left if key in kept else laid).append(size[key])
        assert laid and left, number
        assert max(laid) <= min(left), number           # the smaller ones go first
        # As many laid as the smallest fit in half the volume, the plain plates counted.
        said = design_ladder.half_out(design_ladder.start(rungs[number][1], parts), parts,
                                      False).said[-1]
        n = int(said.split(": ")[1].split()[0])
        every = sorted(design_ladder._volume(i) for _p, i in laid_half
                       if not design_ladder.rolling(i))
        assert sum(every[:n]) <= sum(every) / 2 < sum(every[:n + 1]), (number, n)


@needs_sets
def test_a_technic_sets_half_lays_its_skin_and_leaves_its_working_part(made):
    rungs, parts, _palette = made
    model = style.read(rungs[TECHNIC]["flat"])
    kept = _kept(rungs[TECHNIC][1.5])
    beams = skin = 0
    for p in model.placed:
        i = parts.get(p.part, model.embedded)
        if i is None or not design_ladder.off_up(p, i) or design_ladder.rolling(i):
            continue
        key = ((round(p.matrix.x, 1), round(p.matrix.y, 1), round(p.matrix.z, 1)),
               p.part.lower() + ".dat")
        if i.name.startswith(("Technic Beam", "Technic Gear", "Technic Pin")):
            assert key in kept, i.name
            beams += 1
        elif "Panel" in i.name:
            assert key not in kept, i.name
            skin += 1
    assert beams > 50 and skin > 5


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
    for number in (*SETS, TECHNIC):
        _m, boxes = _measured(rungs[number][1], parts)
        size = _span(boxes)
        for k in (1.5, 2, 3, 4, 5):
            _m, boxes = _measured(rungs[number][k], parts)
            for a, b in zip(size, _span(boxes)):
                assert abs(a - b) <= 2 * design_ladder.STUD, (number, k, size, _span(boxes))


@needs_sets
def test_rungs_are_cumulative(made):
    """Each of rungs 1.5 to 4 keeps only parts the rung above it kept, where they were."""
    rungs, parts, _palette = made
    for number in (*SETS, TECHNIC):
        one, half, two, three, four = (_kept(rungs[number][k])
                                       for k in ("flat", 1.5, 2, 3, 4))
        assert half <= one, number
        assert two <= half, number
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
    assert design_ladder.walk(asked({3: 1, 2: 1, 1.5: 1, 1: 1})) == 0.5
    # Beats rung 2, loses to half the SNOT out: between them.
    assert design_ladder.walk(asked({3: 1, 2: 1, 1.5: 0, 1: 0})) == 1.75
    # Beats half the SNOT out, loses to the set.
    assert design_ladder.walk(asked({3: 1, 2: 1, 1.5: 1, 1: 0})) == 1.25
    # Splits with half the SNOT out.
    assert design_ladder.walk(asked({3: 1, 2: 1, 1.5: 0.5})) == 1.5
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
    # Rung 1.5's files, named bare, are the ladder too.
    for said in ("r1.5.mpd", "Saved r1.5_corner.png", "r2.mpd"):
        assert design_ladder.LADDER_SAID.search(said), said
    assert not design_ladder.LADDER_SAID.search("Plate 1 x 5.mpd is not a part")


def test_a_remade_rung_gets_a_new_key_and_its_old_verdicts_are_not_read(tmp_path, monkeypatch):
    """A rung remade (rung 2 keeping its wheels) is a new key, so a verdict on the old
    one is neither read back for it nor counted in the order table."""
    monkeypatch.setattr(design_ladder, "LADDER", tmp_path / "ladder")
    monkeypatch.setattr(design_ladder, "_VERSIONS", {})
    (tmp_path / "ladder" / "1-1").mkdir(parents=True)
    (tmp_path / "ladder" / "1-1" / "ladder.json").write_text(json.dumps({"versions": {"2": 2}}))
    assert design_ladder.key_of("1-1", 2) == "ladder:1-1:r2:v2"
    assert design_ladder.key_of("1-1", 1.5) == "ladder:1-1:r1.5"
    assert design_ladder.key_of("1-1", 3) == "ladder:1-1:r3"
    assert design_ladder.rung_of("ladder:1-1:r2:v2") == 2.0
    assert design_ladder.rung_of("ladder:1-1:r1.5") == 1.5
    order = tmp_path / "out" / "order" / "1-1"
    order.mkdir(parents=True)
    for first, second, winner in (("ladder:1-1:r2", "ladder:1-1:r3", "ladder:1-1:r3"),
                                  ("ladder:1-1:r2:v2", "ladder:1-1:r3", "ladder:1-1:r2:v2"),
                                  ("ladder:1-1:r1.5", "ladder:1-1:r2:v2", "ladder:1-1:r1.5")):
        dims = {d: winner for d in realset.DIMS}
        v = pairwise.Verdict(first=first, second=second, winners=dims, reasons={})
        (order / f"{pairwise.opaque(first)}-{pairwise.opaque(second)}.json").write_text(
            json.dumps(v.as_dict()))
    table = design_ladder.order_table(tmp_path / "out", ["1-1"])["table"]
    assert table[(2, 3, "overall")]["n"] == 1 and table[(2, 3, "overall")]["right"] == 1
    assert table[(1.5, 2, "overall")]["right"] == 1


def test_a_second_judging_asks_rung_one_afresh(tmp_path, monkeypatch):
    # The record says the design lost to the set both times; the judge, asked afresh,
    # says it won both. A first judging takes the record's word, a second the judge's.
    folder = tmp_path / "arm"
    (folder / "1-1").mkdir(parents=True)
    for view in realset.VIEWS:
        (folder / "1-1" / f"views_{view}.png").write_bytes(b"png")
    monkeypatch.setattr(design_ladder, "views", lambda number, rung: [
        folder / "1-1" / f"views_{v}.png" for v in realset.VIEWS])
    monkeypatch.setattr(realset, "shown", lambda key, pictures: (key,))
    asked = []

    def judged(brief, number, ours, rung_side, into, model):
        asked.append(rung_side[0])
        winner = ours[0]
        return [pairwise.Verdict(first=ours[0], second=rung_side[0],
                                 winners={"overall": winner}, reasons={})] * 2

    monkeypatch.setattr(realset, "both_orders", judged)
    monkeypatch.setattr(design_ladder, "rung_side", lambda number, rung: (f"r{rung}", ()))
    lost = {"winners": {"overall": "set"}}
    record = {"keys": {"ours": "ours"}, "brief": "", "verdicts": [lost, lost]}
    first = design_ladder.place_one(record, folder, "1-1", tmp_path / "a", "opus")
    assert first["place"] == 1.25 and "r1" not in asked     # beat rung 1.5, lost to the set
    second = design_ladder.place_one(record, folder, "1-1", tmp_path / "b", "opus", fresh=True)
    assert second["place"] == 0.5 and "r1" in asked
