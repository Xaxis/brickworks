"""The collection API's words for op built and its siblings (smalls5, 2026-11-18).

kbreview (finding 6) found op built's refusals said the wrong thing: a
`sets` that was not a list was "sets is a list of lots"; a set never owned
was 409 "is not in your collection any more", as though it had been taken
out since; and "sw0001", the number of a minifigure the collection holds,
was read as set sw0001-1. Own and missing read a figure's number the same
way: Own would have added a set sw0001-1 nobody has. api/collection.js's
applyOp runs here under node on a collection as the database keeps it.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

HAVE = {
    "there": True, "rev": 7, "recent": [], "parts": [],
    "sets": [
        {"set": "7140-1", "qty": 2, "spares": False, "src": "hand", "built": 1},
        {"set": "sw0001", "qty": 1, "spares": False, "fig": True, "src": "hand"},
    ],
}


def ops(cases: dict) -> dict | None:
    """Each of [cases] (name -> op body) applied to HAVE: {status, error} for
    a refusal, or {done, sets} for a change."""
    if shutil.which("node") is None:
        return None
    script = (
        "const { applyOp } = await import('./api/collection.js');"
        f"const have = {json.dumps(HAVE)};"
        f"const cases = {json.dumps(cases)};"
        "const out = {};"
        "for (const [name, body] of Object.entries(cases)) {"
        "  try {"
        "    const made = applyOp(structuredClone(have), body);"
        "    out[name] = { done: made.done, sets: made.next ? made.next.sets : null };"
        "  } catch (e) { out[name] = { status: e.status ?? null, error: e.message }; }"
        "}"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_a_list_that_is_not_one_is_named_for_what_it_lists() -> None:
    got = ops({
        "built_object": {"op": "built", "sets": {"set": "7140-1"}},
        "built_string": {"op": "built", "sets": "7140-1"},
        "built_many": {"op": "built", "sets": [{"set": f"{n}-1", "was": 0, "built": 1} for n in range(2001)]},
        "lots_object": {"op": "lots", "add": {"part": "3001"}},
    })
    if got is None:
        return
    assert got["built_object"] == got["built_string"] == {"status": 400, "error": "sets is a list of sets"}
    assert got["built_many"] == {"status": 413, "error": "that is 2001 sets; one change is at most 2000"}
    assert got["lots_object"] == {"status": 400, "error": "add is a list of lots"}


def test_a_set_never_owned_is_a_400_that_says_so_and_one_gone_since_a_409() -> None:
    got = ops({
        "never": {"op": "built", "sets": [{"set": "3000-1", "was": 0, "built": 1}]},
        "never_same_rev": {"op": "built", "rev": 7, "sets": [{"set": "3000-1", "was": 0, "built": 1}]},
        "gone_since": {"op": "built", "rev": 6, "sets": [{"set": "3000-1", "was": 0, "built": 1}]},
        "one_of_two": {"op": "built", "sets": [{"set": "7140-1", "was": 1, "built": 2},
                                               {"set": "3000-1", "was": 0, "built": 1}]},
    })
    if got is None:
        return
    never = {"status": 400, "error": "set 1: 3000-1 is not in your collection: only a set you own is kept built"}
    assert got["never"] == got["never_same_rev"] == never
    assert got["gone_since"] == {"status": 409, "error": "3000-1 is not in your collection any more"}
    assert got["one_of_two"] == {"status": 400,
                                 "error": "set 2: 3000-1 is not in your collection: only a set you own is kept built"}


def test_a_figures_number_is_refused_as_a_figure_never_read_as_a_set() -> None:
    got = ops({
        "built": {"op": "built", "sets": [{"set": "sw0001", "was": 0, "built": 1}]},
        "own": {"op": "own", "set": "sw0001", "was": 0, "qty": 1},
        "missing": {"op": "missing", "set": "sw0001", "lots": [{"part": "3001", "colour": 4, "was": 0, "qty": 1}]},
        # Its number with -1 is a set's, and that set is not owned.
        "as_a_set": {"op": "built", "sets": [{"set": "sw0001-1", "was": 0, "built": 1}]},
    })
    if got is None:
        return
    assert got["built"] == {"status": 400, "error": "set 1: sw0001 is a minifigure in your collection, not a set"}
    assert got["own"] == got["missing"] == {"status": 400, "error": "sw0001 is a minifigure in your collection, not a set"}
    assert got["as_a_set"]["status"] == 400 and "sw0001-1 is not in your collection" in got["as_a_set"]["error"]


def test_a_figures_number_not_held_and_a_part_file_are_refused_never_made_sets() -> None:
    """s5review: the check above covered only a figure the collection holds.
    Own "sw0002", not held, made set sw0002-1; built "3001.dat" said
    "3001.dat-1 is not in your collection"."""
    got = ops({
        "own": {"op": "own", "set": "sw0002", "was": 0, "qty": 1},
        "built": {"op": "built", "sets": [{"set": "cty0001a", "was": 0, "built": 1}]},
        "missing": {"op": "missing", "set": "hp001", "lots": [{"part": "3001", "colour": 4, "was": 0, "qty": 1}]},
        "file": {"op": "built", "sets": [{"set": "3001.dat", "was": 0, "built": 1}]},
        "own_file": {"op": "own", "set": "3001.DAT", "was": 0, "qty": 1},
        # A set numbered in a figure's shape, named with its -N, is a set;
        # so is a number of digits alone, given without it.
        "shaped_set": {"op": "own", "set": "hp2113-1", "was": 0, "qty": 1},
        "digits": {"op": "own", "set": "10237", "was": 0, "qty": 1},
    })
    if got is None:
        return
    assert got["own"] == {"status": 400,
                          "error": "sw0002 is a minifigure's number, not a set's: a set is named with its -N, as sw0002-1"}
    assert got["built"] == {"status": 400, "error": "set 1: cty0001a is a minifigure's number, not a set's: "
                            "a set is named with its -N, as cty0001a-1"}
    assert got["missing"]["status"] == 400 and got["missing"]["error"].startswith("hp001 is a minifigure's number")
    assert got["file"] == {"status": 400, "error": 'set 1: "3001.dat" is a part\'s file name, not a set number'}
    assert got["own_file"] == {"status": 400, "error": '"3001.DAT" is a part\'s file name, not a set number'}
    assert got["shaped_set"]["done"]["owned"] == 1, got["shaped_set"]
    assert got["digits"]["done"]["owned"] == 1 and any(s["set"] == "10237-1" for s in got["digits"]["sets"])


def test_built_and_its_undo_the_same_op_the_other_way_round() -> None:
    got = ops({
        "press": {"op": "built", "rev": 7, "sets": [{"set": "7140-1", "was": 1, "built": 2}]},
        "undo_of_it": {"op": "built", "rev": 7, "sets": [{"set": "7140-1", "was": 1, "built": 0}]},
        "own_more": {"op": "own", "set": "7140-1", "was": 2, "qty": 3},
    })
    if got is None:
        return
    assert got["press"]["done"] == {"built": [{"set": "7140-1", "was": 1, "built": 2}]}
    assert got["press"]["sets"][0]["built"] == 2
    assert got["undo_of_it"]["sets"][0].get("built", 0) == 0
    # The figure is never touched by a set's op.
    assert got["press"]["sets"][1] == HAVE["sets"][1]
    assert got["own_more"]["done"]["owned"] == 3
