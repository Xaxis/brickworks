"""Where a minifigure's parts go: the tool that measured it, held to the
LDraw library and to the app that uses its numbers.

tools/minifig.py measures the joints over real sets and writes the
per-part tables the app reads (src/minifig/minifig_data.gd); the joints
themselves are written twice, there and in src/minifig/minifig.gd. These
pin the two together and pin the rules that wrote the tables to parts
whose answer is known.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import minifig  # noqa: E402
from ldraw.library import Library  # noqa: E402

LDRAW_ROOT = ROOT / "vendor" / "ldraw"
needs_ldraw = pytest.mark.skipif(
    not (LDRAW_ROOT / "parts").is_dir(),
    reason="LDraw library not present; run tools/fetch_data.sh",
)
GDSCRIPT = (ROOT / "src" / "minifig" / "minifig.gd").read_text()


def _gd_constant(name: str) -> list[float]:
    found = re.search(r"const %s: Array\[float\] = \[(.*?)\]" % name, GDSCRIPT, re.S)
    assert found, name
    return [float(v) for v in found.group(1).replace("\n", " ").split(",")]


@pytest.mark.parametrize("tool, app", [
    ("arm_r", "ARM_R"), ("arm_l", "ARM_L"), ("hand_r", "HAND_R"),
    ("hand_l", "HAND_L"), ("head", "HEAD"), ("hips", "HIPS"), ("leg_r", "LEGS"),
])
def test_the_app_places_parts_where_the_tool_measured(tool: str, app: str) -> None:
    (x, y, z), rotation = minifig.JOINTS[tool]
    assert _gd_constant(app) == [x, y, z, *rotation]


def test_the_grip_is_where_the_hand_part_says() -> None:
    assert re.search(r"const GRIP := Vector3\(0.0, -0.8229, -9.8948\)", GDSCRIPT)
    assert minifig.GRIP == (0.0, -0.8229, -9.8948)


def test_a_figure_is_not_counted_in_a_models_texture() -> None:
    # tools/texture.py measures a model against real sets' inventories,
    # which keep figures apart; what a figure holds is a set part.
    import texture
    by_id = {
        "3001": {"category": "Brick"},
        "973": {"category": "Minifig"},
        "3626cp01": {"category": "Minifig"},
        "3901": {"category": "Minifig Headwear"},
        "3838": {"category": "Minifig Neckwear"},
        "2530": {"category": "Minifig Accessory"},
    }
    parts = [("3001", 4), ("973", 4), ("3626cp01", 14), ("3901", 70),
             ("3838", 0), ("2530", 72), ("3001", 1)]
    assert texture.without_figures(parts, by_id) == [("3001", 4), ("2530", 72), ("3001", 1)]


@pytest.fixture(scope="module")
def library() -> Library:
    return Library(LDRAW_ROOT)


@needs_ldraw
def test_a_cutlass_is_held_at_its_origin_along_y(library: Library) -> None:
    # 2530 is drawn the LDraw way: its handle a bar along Y through the
    # origin. Real figures hold it within half an LDU of there.
    (at, along) = minifig.grip_of(library, "2530")
    assert max(abs(v) for v in at) < 0.01
    assert abs(abs(along[1]) - 1.0) < 1e-6


@needs_ldraw
def test_a_shortsword_is_held_by_its_handle_not_its_guard(library: Library) -> None:
    # 3847's origin is at its guard, where a cross bar runs through it; the
    # handle is the bar along Y below, and real hands are 2 LDU from its
    # middle.
    (at, along) = minifig.grip_of(library, "3847")
    assert abs(at[1] - 8.0) < 0.01 and abs(at[0]) < 0.01 and abs(at[2]) < 0.01
    assert abs(along[1]) > 0.99


@needs_ldraw
def test_a_bow_has_no_bar_and_is_held_at_its_origin(library: Library) -> None:
    assert minifig.bars(library, "4499") == []
    assert minifig.grip_of(library, "4499") == ((0.0, 0.0, 0.0), (0.0, 1.0, 0.0))


def test_the_tool_sorts_parts_into_slots_by_the_apps_rule() -> None:
    # The rule is written twice: here, to know which parts to work the
    # tables out for, and in minifig.gd, which the app offers parts by.
    # Every name pattern of one is in the other, word for word.
    for _slot, rule in minifig.NAME_RULES:
        assert rule.replace("\\", "\\\\") in GDSCRIPT, rule
    for rule in (minifig.HAT_EXTRA_NAMES.pattern, minifig.BACK_NAMES.pattern):
        assert rule.replace("\\", "\\\\") in GDSCRIPT, rule


@pytest.mark.parametrize("name, category, slot", [
    ("Minifig Head with Vented Stud", "Minifig", "head"),
    ("Minifig Mechanical Head and Torso", "Minifig", "torso"),
    ("Minifig Hips and Skirt", "Minifig", "legs"),
    ("Minifig Hips with Gold Belt Pattern", "Minifig", "hips"),
    ("Minifig Helmet Visor Standard", "Minifig", "hat_extra"),
    ("Minifig Plume Small", "Minifig Headwear", "hat_extra"),
    ("Minifig Helmet Classic with Thick Chin Guard and Visor Dimples", "Minifig Headwear",
     "headwear"),
    ("Minifig Airtanks", "Minifig Neckwear", "back"),
    ("Minifig Cape Cloth (Formed)", "Minifig Neckwear", "cape"),
    ("Minifig Cape Cloth", "Sheet Fabric", "cape"),
    ("Minifig Skirt  1.5L Fringed", "Sheet Fabric", "hipwear"),
    ("Minifig Bowtie", "Minifig Neckwear", "neck"),
    ("Minifig Hand Hook", "Minifig", "hands"),
    ("Arm Skeleton with Vertical Clip Bent 53.13", "Minifig", "arms"),
    ("Minifig Bicycle Frame", "Vehicle", "accessory"),
    ("Sail 17 x 21 Triangular", "Sheet Fabric", ""),
    ("Brick  2 x  4", "Brick", ""),
])
def test_each_kind_of_part_has_its_slot(name: str, category: str, slot: str) -> None:
    assert minifig.slot_of(name, category) == slot


def test_a_print_belongs_to_its_mould() -> None:
    assert minifig.family("3816cp0b") == "3816c"
    assert minifig.family("973pbn") == "973"
    assert minifig.family("3626bpc94") == "3626b"
    assert minifig.family("43741-f1") == "43741-f1"
    assert minifig.family("u9209p01c01") == "u9209"
    assert minifig.family("50231c01") == "50231c01"


def test_a_mirrored_arm_is_turned_instead() -> None:
    # The library mirrors a left arm to stand for the right (11263, the
    # bird wing); a real part can only be turned. A part symmetric in its
    # own X (a hand) just loses the mirror.
    mirrored = minifig.mat([-15.552, 9, 0, -0.985, -0.17, 0, -0.17, 0.985, 0, 0, 0, 1])
    turned = minifig.unmirrored(mirrored)
    assert [row[:3] for row in turned[:3]] == [[-0.985, -0.17, -0.0], [-0.17, 0.985, -0.0],
                                               [0, 0, -1]]
    hand = minifig.unmirrored(mirrored, symmetric=True)
    assert [row[:3] for row in hand[:3]] == [[0.985, -0.17, 0], [0.17, 0.985, 0], [-0.0, 0, 1]]


@needs_ldraw
def test_a_visor_turns_where_its_helmet_takes_it(library: Library) -> None:
    # The current visor is drawn about its pins, the old one in the head's
    # frame with its pins 6.5 down, as the old helmet's dimples are; the
    # current classic helmet's dimples are 5 down. The castle visor's pins
    # are its bumps, not the rings round its hinge 2.7 LDU off.
    assert minifig.pivot_of(library, "2447b") == (0.0, 0.0)
    assert minifig.pivot_of(library, "2447") == (6.5, 0.0)
    assert minifig.pivot_of(library, "2446") == (6.5, 0.0)
    assert minifig.pivot_of(library, "3842b") == (5.0, 0.0)
    assert minifig.pivot_of(library, "2594a") == (0.0, 0.0)
    assert minifig.pivot_of(library, "3844") is None


@needs_ldraw
def test_a_head_sits_on_its_neck_socket(library: Library) -> None:
    # The classic head is drawn from its top, its socket opening 24 down;
    # the moulded ones (a goblin, a baby) from the neck up.
    assert minifig.neck_seat(library, "3626c") == 24.0
    assert minifig.neck_seat(library, "28621") == 24.0
    assert minifig.neck_seat(library, "42109") == 0.0
    assert minifig.neck_seat(library, "24581") == 0.0


@needs_ldraw
def test_a_head_drawn_as_a_brick_rests_on_its_rim(library: Library) -> None:
    # A Minion's tube for the neck post opens 20 LDU up inside it; its rim
    # is 40 down, and that is what rests on the shoulders.
    assert minifig.neck_seat(library, "67649") == 40.0
    assert minifig.neck_seat(library, "29030") == 32.0
    # A head with no socket at all says so.
    assert minifig.neck_seat(library, "30378") is None


def test_the_library_says_what_odd_parts_attach_to() -> None:
    data = (ROOT / "src" / "minifig" / "minifig_data.gd").read_text()
    # 73200bpx0: printed legs with their printed hips; 43743-f1: springs
    # in hips 43221 and legs 43220; 6828.dat's HELP: the prosthetic hand on
    # the stump; 30375cs0: the droid's head on the droid's torso.
    assert '"3816cpx0": ["3815bpx0", -1],' in data
    assert '"43741-f1": ["43221", -1],' in data
    assert '"43741-f1": [["43220", [0.0, 44.0, 0.0,' in data
    assert '"5059": ["6828", 5.311, 5.023, -30.326,' in data
    assert '"30378": "30375",' in data
    # Not the plain hand, which goes on every arm.
    assert '"3820": [' not in data.split("const ON_ARMS")[1].split("}")[0]


@needs_ldraw
def test_airtanks_have_a_collar(library: Library) -> None:
    # Real figures wearing 3838 sit the head up 3 LDU (29 of 38); the
    # geometry says 4. The table uses what real figures do where they do.
    assert minifig.collar(library, "3838") == 4.0
    data = (ROOT / "src" / "minifig" / "minifig_data.gd").read_text()
    assert '"3838": 3,' in data
