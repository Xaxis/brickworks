"""The keystroke-level model of building a set by hand, in both apps.

The comparison with Studio is only as good as these sums: a part that needs
a search, a colour and a turn has to cost exactly the operators listed, in
each app, or the seconds per part said in the report are someone's guess.
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from bench import cadtask_klm as klm  # noqa: E402


def _part(id_: str, colour: int, face: str = "up", q: int = 0) -> dict:
    return {"id": id_, "colour": colour, "turn": [face, q]}


def test_operator_seconds_are_card_moran_newell():
    assert klm.SECONDS == {"K": 0.28, "P": 1.1, "B": 0.1, "H": 0.4, "M": 1.35}
    assert klm.seconds(["P", "B", "B"]) == 1.3
    assert klm.seconds(Counter({"M": 2, "K": 5})) == 4.1


def test_the_24_turns_are_24():
    seen = {klm.basis_for(face, q) for face in klm.FACES for q in range(4)}
    assert len(seen) == 24
    # A quarter about the up: x goes to -z, as Godot's Basis(UP, PI/2) has it.
    assert klm.basis_for("up", 1) == ((0, 0, 1), (0, 1, 0), (-1, 0, 0))
    assert klm.basis_for("up", 0) == ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def test_brickworks_turn_keys():
    assert klm.brickworks_turn_keys(("up", 0), ("up", 0)) == []
    assert klm.brickworks_turn_keys(("up", 0), ("up", 1)) == ["K"]
    assert klm.brickworks_turn_keys(("up", 0), ("up", 2)) == ["K", "K"]
    # Three quarters one way is one the other: Shift-R, two keys.
    assert klm.brickworks_turn_keys(("up", 0), ("up", 3)) == ["K", "K"]
    # Onto the next face, T; onto -x, five forward or one back with Shift.
    assert klm.brickworks_turn_keys(("up", 0), ("+z", 0)) == ["K"]
    assert klm.brickworks_turn_keys(("up", 0), ("-x", 0)) == ["K", "K"]


def test_studio_turn_keys_are_the_fewest_arrows():
    assert klm.studio_turn_keys(("up", 0), ("up", 0)) == []
    assert klm.studio_turn_keys(("up", 0), ("up", 1)) == ["K"]
    assert klm.studio_turn_keys(("up", 0), ("up", 2)) == ["K", "K"]
    assert klm.studio_turn_keys(("up", 0), ("down", 0)) == ["K", "K"]
    # Two axes reach every one of the 24 within four arrows; one needs all four.
    for face in klm.FACES:
        for q in range(4):
            assert len(klm.studio_turn_keys(("up", 0), (face, q))) <= 4
    assert len(klm.studio_turn_keys(("up", 0), ("down", 2))) == 4


def test_a_new_part_with_a_colour_and_a_turn_brickworks():
    ops = klm.model_part("brickworks", _part("3023", 15, "up", 1), _part("3020", 4))
    # Search: M H, "/" and Ctrl+A (3 K), "3023" (4 K), H M P BB; colour M P BB;
    # turn M K; put M P BB.
    assert Counter(ops) == Counter({"M": 5, "H": 2, "K": 8, "P": 3, "B": 6})
    assert klm.seconds(ops) == 13.69


def test_a_new_part_with_a_colour_and_a_turn_studio():
    ops = klm.model_part("studio", _part("3023", 15, "up", 1), _part("3020", 4))
    # Search: M H, Ctrl+F and Ctrl+A (4 K), "3023" (4 K), H M P BB; colour
    # M P BB P BB; turn M K; put M P BB.
    assert Counter(ops) == Counter({"M": 5, "H": 2, "K": 9, "P": 4, "B": 8})
    assert klm.seconds(ops) == 15.27


def test_a_second_copy_costs_studio_a_palette_click_and_brickworks_nothing():
    first = _part("3023", 15)
    again = _part("3023", 15)
    assert Counter(klm.model_part("brickworks", again, first)) == Counter({"M": 1, "P": 1, "B": 2})
    assert Counter(klm.model_part("studio", again, first)) == Counter({"M": 2, "P": 2, "B": 4})


def test_model_build_sums_parts_and_steps():
    parts = [_part("3034", 7), _part("3022", 15), _part("3022", 15, "up", 1)]
    built = klm.model_build("brickworks", parts, steps=[1, 2])
    assert built["parts"] == 3
    assert built["modelled"] is True
    one = klm.model_part("brickworks", parts[0], None)
    two = klm.model_part("brickworks", parts[1], parts[0])
    three = klm.model_part("brickworks", parts[2], parts[1])
    assert built["seconds"] == klm.seconds(one + two + three)
    assert built["seconds_per_part"] == round(built["seconds"] / 3, 2)
    # Steps: E once a step, as Studio's.
    marking = klm.model_steps("brickworks", [1, 2])
    assert Counter(marking) == Counter({"M": 2, "K": 2})
    assert built["with_steps"]["seconds"] == klm.seconds(one + two + three + marking)
    assert Counter(klm.model_steps("studio", [1, 2])) == Counter({"M": 2, "K": 2})
    # Actions are keys, pointings and clicks, a click once.
    ops = Counter(one + two + three)
    assert built["actions"] == ops["K"] + ops["P"] + ops["B"] // 2


def test_compare_run_says_what_was_extra():
    parts = [_part("3034", 7), _part("3022", 15)]
    modelled = klm.model_build("brickworks", parts)
    measured = {"tried": 2, "seconds_per_part": 30.0,
                "counts": {"point": 9, "click": 6, "key": 4, "typed": 8, "scroll": 1, "aim_fix": 3}}
    got = klm.compare_run(measured, modelled)
    assert got["measured_operators"] == {"P": 9, "B": 12, "K": 13}
    assert got["extra_operators"]["P"] == 9 - modelled["operators"]["P"]
    assert got["extra_operators"]["K"] == 13 - modelled["operators"]["K"]
    assert got["measured_actions_per_part"] == round((9 + 13 + 6) / 2, 2)
    assert got["measured_motor_seconds_per_part"] == round((9 * 1.1 + 12 * 0.1 + 13 * 0.28) / 2, 2)
    assert got["modelled_seconds_per_part"] == modelled["seconds_per_part"]
    assert got["extra_aims"] == 3
    assert got["measured_wall_seconds_per_part"] == 30.0


def test_an_old_grey_is_its_name_typed_in_brickworks():
    # 7, Light Grey, is in no set since the palette's year: not in the short
    # palette, so Shift-C, "Light Grey", Enter, both hands to the keys.
    assert not klm.in_short_palette(7)
    assert klm.in_short_palette(15)
    ops = klm.model_part("brickworks", _part("3034", 7), _part("3034", 15))
    assert Counter(ops) == Counter({"M": 2, "H": 2, "K": 3 + len("Light Grey"), "P": 1, "B": 2})
    # Studio's colour menu shows every colour: two clicks either way.
    assert Counter(klm.model_part("studio", _part("3034", 7), _part("3034", 15))) \
        == Counter(klm.model_part("studio", _part("3034", 71), _part("3034", 15)))
