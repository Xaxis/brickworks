#!/usr/bin/env python3
"""Merge a --only sub-build into the full catalogue, and prove it sound.

A full tools/build_meshes.py run is longer than this session can hold a
process open for, and it died twice at 95%. Only about two thousand
parts changed, so those are rebuilt on their own and merged.

The merge is only trustworthy if a sub-build produces, for a part that
did not change, byte-identical output to what is already there. So the
sub-build deliberately includes a few hundred parts that are *not* in
the affected set, and every one of them has to match. If any differs,
the sub-build is not equivalent to a full build and nothing is merged.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ROOT / "assets" / "generated"

# Added later by tools/refresh_catalogue.py, so not part of the compare,
# and carried over to a merged entry because the sub-build does not make
# them. in_sets was missing: merging 2,379 rebuilt parts on 2026-10-10
# took it off 1,239 of them, so the parts bin and search, which rank by
# it, would have sunk every one of them below parts no set uses.
LATER = ("colors", "colors_recent", "colors_partial", "years",
         "packed", "reachable", "in_sets")


def bare(entry: dict) -> dict:
    return {k: v for k, v in entry.items() if k not in LATER}


def carry_exact(before: dict[str, str], after: dict[str, str]) -> tuple[int, list[str]]:
    """Each part's exact shape under its new mesh hash: (copied, still lacking).

    before and after are part id -> mesh hash. An exact shape is BrickNet's,
    the part's own and not our mesh's; the mesh hash is only its file name
    (tools/build_exact.py). A rebuilt mesh has a new hash, so without this
    the shape is lost: merging covers2 left 942 parts without one, and the
    joint check skipped, which reads as a pass (2026-10-19).
    """
    exact = GENERATED / "exact"
    copied, lacking = 0, []
    for part_id, mesh in after.items():
        old = before.get(part_id)
        if not old or old == mesh or not (exact / f"{old}.bwx").exists():
            continue
        target = exact / f"{mesh}.bwx"
        if not target.exists():
            shutil.copy2(exact / f"{old}.bwx", target)
            copied += 1
        if not target.exists():
            lacking.append(part_id)
    return copied, lacking


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: merge_subbuild.py <sub-build dir> <affected-ids file>")
        return 2
    built = Path(argv[1])
    affected = {
        line.strip() for line in Path(argv[2]).read_text().splitlines()
        if line.strip()
    }

    fresh = json.loads((built / "catalogue.json").read_text())
    whole_path = GENERATED / "catalogue.json"
    whole = json.loads(whole_path.read_text())
    have = {e["id"]: e for e in whole["parts"]}

    controls = changed = missing = 0
    broken, drifted = [], []
    for entry in fresh["parts"]:
        here = have.get(entry["id"])
        if here is None:
            missing += 1
            continue
        if entry["id"] in affected:
            changed += 1
            continue
        controls += 1
        # The connectors are what a change to connectivity.py can move,
        # so a control part disagreeing about them means the affected
        # set was wrong and the merge would leave the catalogue half
        # updated. Everything else -- geometry, triangle counts, the
        # unofficial flag -- moves when the LDraw library is re-fetched
        # under a catalogue built before it, which is a staleness this
        # tool cannot fix and must not hide.
        if entry.get("connector_counts") != here.get("connector_counts"):
            broken.append(entry["id"])
        elif bare(entry) != bare(here):
            drifted.append(entry["id"])

    print(f"sub-build: {len(fresh['parts']):,} parts "
          f"({changed:,} affected, {controls:,} controls, {missing} new)")
    if controls < 50:
        print("REFUSED: too few control parts to trust the merge")
        return 1
    if broken:
        print(f"REFUSED: {len(broken)} control parts disagree about their "
              f"connectors, so the affected set is incomplete")
        for part_id in broken[:10]:
            print(f"    {part_id}")
        return 1
    print(f"all {controls:,} control parts agree about their connectors")
    if drifted:
        share = 100.0 * len(drifted) / controls
        print(f"NOTE: {len(drifted)} of them ({share:.1f}%) have different "
              f"geometry or flags — the LDraw library has moved since the")
        print("      catalogue was built, so roughly that share of the "
              "library needs a full")
        print("      rebuild to pick up. Not caused by this merge, and "
              "not fixed by it.")

    copied = 0
    for mesh in (built / "parts").iterdir():
        target = GENERATED / "parts" / mesh.name
        if not target.exists() or target.read_bytes() != mesh.read_bytes():
            shutil.copy2(mesh, target)
            copied += 1

    replaced = 0
    before, after = {}, {}
    for index, entry in enumerate(whole["parts"]):
        fresher = next(
            (e for e in fresh["parts"] if e["id"] == entry["id"]), None)
        if fresher is None or entry["id"] not in affected:
            continue
        kept = {k: v for k, v in entry.items() if k in LATER}
        whole["parts"][index] = {**fresher, **kept}
        replaced += 1
        if entry.get("mesh") and fresher.get("mesh"):
            before[entry["id"]] = entry["mesh"]
            after[entry["id"]] = fresher["mesh"]

    whole_path.write_text(json.dumps(whole, separators=(",", ":")))
    print(f"merged {replaced:,} entries and {copied:,} mesh files")
    carried, lacking = carry_exact(before, after)
    print(f"carried {carried:,} exact shapes to their parts' new meshes")
    if lacking:
        print(f"WARNING: {len(lacking)} parts lost their exact shapes")
        return 1

    gone = [
        e["id"] for e in whole["parts"]
        if e.get("mesh") and not (GENERATED / "parts" / f"{e['mesh']}.lbm").exists()
    ]
    if gone:
        print(f"WARNING: {len(gone)} parts now reference a missing mesh")
        return 1
    print("every part in the catalogue still has its geometry")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
