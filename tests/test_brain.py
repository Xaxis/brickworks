"""Tests for the design validator.

The validator is the only reason a language model's output can be
trusted, so what it rejects matters as much as what it accepts. These
pin both: a design that is genuinely buildable must pass, and each way a
design can be unbuildable must be caught specifically, with a message
that says which brick and why.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from brain.catalogue import GENERATED, Catalogue  # noqa: E402
from brain.model import Model, Placement, to_ldr  # noqa: E402
from brain.validate import check  # noqa: E402

pytestmark = pytest.mark.skipif(
    not (GENERATED / "catalogue.json").exists(),
    reason="catalogue not built; run tools/build_meshes.py",
)


@pytest.fixture(scope="session")
def catalogue() -> Catalogue:
    return Catalogue()


def _wall(courses: int = 4, bricks: int = 3, bond: bool = True) -> Model:
    """A wall, optionally with its joints staggered the way a wall is."""
    model = Model(name="Wall")
    for course in range(courses):
        offset = 2 if (bond and course % 2) else 0
        for n in range(bricks):
            model.add(Placement("3001", 4, x=n * 4 + offset, y=course * 3, z=0))
    return model


def test_a_bonded_wall_is_buildable(catalogue: Catalogue) -> None:
    report = check(_wall(), catalogue)
    assert report.ok, report.as_feedback()
    assert report.connected_groups == 1


def test_an_unbonded_wall_is_not_one_piece(catalogue: Catalogue) -> None:
    """Columns stacked without staggering are separate towers.

    This is not pedantry — it is the first thing anyone learns about
    building, and a design that ignores it comes apart in the hand.
    """
    report = check(_wall(bond=False), catalogue)
    assert not report.ok
    assert any(i.kind == "not one piece" for i in report.errors)


def test_overlap_is_caught(catalogue: Catalogue) -> None:
    model = Model()
    model.add(Placement("3001", 4, 0, 0, 0))
    model.add(Placement("3001", 14, 2, 0, 0))   # two studs in
    report = check(model, catalogue)
    assert any(i.kind == "overlap" for i in report.errors)


def test_touching_but_not_overlapping_is_fine(catalogue: Catalogue) -> None:
    """A 2x4 brick is four studs wide, so x=0 and x=4 abut exactly."""
    model = Model()
    model.add(Placement("3001", 4, 0, 0, 0))
    model.add(Placement("3001", 14, 4, 0, 0))
    report = check(model, catalogue)
    assert not any(i.kind == "overlap" for i in report.errors)


def test_floating_is_caught(catalogue: Catalogue) -> None:
    model = Model()
    model.add(Placement("3001", 4, 0, 0, 0))
    model.add(Placement("3001", 14, 0, 9, 0))   # three plates of air below
    report = check(model, catalogue)
    assert any(i.kind == "floating" for i in report.errors)


def test_side_by_side_does_not_count_as_connected(catalogue: Catalogue) -> None:
    """Two bricks pushed together on a table come apart when you lift."""
    model = Model()
    model.add(Placement("3001", 4, 0, 0, 0))
    model.add(Placement("3001", 14, 4, 0, 0))
    report = check(model, catalogue)
    assert report.connected_groups == 2


def test_unknown_part_is_caught(catalogue: Catalogue) -> None:
    model = Model()
    model.add(Placement("not-a-part", 4, 0, 0, 0))
    report = check(model, catalogue)
    assert any(i.kind == "unknown part" for i in report.errors)


def test_below_ground_is_caught(catalogue: Catalogue) -> None:
    model = Model()
    model.add(Placement("3001", 4, 0, -2, 0))
    report = check(model, catalogue)
    assert any(i.kind == "below ground" for i in report.errors)


def test_a_brick_is_three_plates(catalogue: Catalogue) -> None:
    """Stacking a brick at y=3 rests it exactly on one at y=0."""
    model = Model()
    model.add(Placement("3001", 4, 0, 0, 0))
    model.add(Placement("3001", 14, 0, 3, 0))
    report = check(model, catalogue)
    assert report.ok, report.as_feedback()

    # y=2 would bury it a plate deep, y=4 would leave it floating.
    for wrong, kind in ((2, "overlap"), (4, "floating")):
        bad = Model()
        bad.add(Placement("3001", 4, 0, 0, 0))
        bad.add(Placement("3001", 14, 0, wrong, 0))
        assert any(i.kind == kind for i in check(bad, catalogue).errors)


def test_plates_stack_three_to_a_brick(catalogue: Catalogue) -> None:
    model = Model()
    model.add(Placement("3001", 4, 0, 0, 0))
    for n in range(3):
        model.add(Placement("3020", 14, 0, 3 + n, 0))   # Plate 2 x 4
    report = check(model, catalogue)
    assert report.ok, report.as_feedback()
    assert report.size_studs[1] == 6          # one brick plus three plates


def test_rotation_swaps_the_footprint(catalogue: Catalogue) -> None:
    """Turned a quarter, a 2x4 occupies 2 across and 4 deep.

    Unrotated, two bricks at x=0 and x=2 overlap; rotated, they do not,
    because the footprint is only two studs across.
    """
    flat = Model()
    flat.add(Placement("3001", 4, 0, 0, 0))
    flat.add(Placement("3001", 14, 2, 0, 0))
    assert any(i.kind == "overlap" for i in check(flat, catalogue).errors)

    turned = Model()
    turned.add(Placement("3001", 4, 0, 0, 0, rot=1))
    turned.add(Placement("3001", 14, 2, 0, 0, rot=1))
    assert not any(i.kind == "overlap" for i in check(turned, catalogue).errors)


def test_ldraw_export_writes_one_line_per_part(catalogue: Catalogue) -> None:
    model = _wall()
    text = to_ldr(model, catalogue.sizes(), author="tests")
    placed = [line for line in text.splitlines() if line.startswith("1 ")]
    assert len(placed) == len(model.placements)
    assert all(line.endswith(".dat") for line in placed)


def test_report_feedback_names_the_problem(catalogue: Catalogue) -> None:
    """Feedback has to be specific enough to act on, and short enough to read."""
    model = Model()
    model.add(Placement("3001", 4, 0, 0, 0))
    model.add(Placement("3001", 14, 1, 0, 0))
    feedback = check(model, catalogue).as_feedback()
    assert "overlap" in feedback.lower()
    assert len(feedback.splitlines()) < 20
