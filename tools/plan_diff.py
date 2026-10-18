#!/usr/bin/env python3
"""Two checkouts' plans (src/dev/plan_dump.gd --dump), file by file and plan by plan.

    tools/plan_diff.py BEFORE.jsonl AFTER.jsonl

A change meant only to make planning faster must not move a step: the steps
score's measures can stay put while steps move, so the plans themselves are
compared.

Every step's every field is compared: its bricks, parts, section, callout
fields, copies, the author's step it is, and the step player's view (the
direction and the box framed). Prints each file that differs and how.

A plan moves with its parts as well as with the planner: a dump made since
2026-10-17 says which catalogue it read and a digest of each file's parts'
geometry, and a file whose parts' geometry differs between the two is said
so. Two dumps of one checkout, either side of a 13 minutes in which the
shared catalogue gave 421 wheels and tyres other covers, differed in 7 files
for that alone (docs/INSTRUCTIONS.md, samebooklet).
"""
import json
import sys

FIELDS = ["index", "number", "brick_ids", "parts", "unsupported", "section", "assembly",
          "callout", "callout_step", "callout_steps", "times", "figure", "shown_ids", "copies",
          "authored_in", "authored_step", "view_from", "view_box"]


def rows(path):
    out = {}
    for line in open(path):
        line = line.strip()
        if line:
            r = json.loads(line)
            if "file" in r:
                out[r["file"]] = r
            elif "catalogue" in r:
                out[None] = r
    return out


before, after = rows(sys.argv[1]), rows(sys.argv[2])
read = [run.pop(None, {}).get("catalogue") for run in (before, after)]
if None not in read and read[0] != read[1]:
    print(f"the two read different catalogues ({read[0]}, {read[1]})")
files = [f for f in before if f in after]
missing = [f for f in before if f not in after] + [f for f in after if f not in before]
differ = 0
moved_parts = 0
steps = 0
callouts = 0
for f in files:
    bad = []
    for variant in ["opened", "drawn", "ours", "flat"]:
        a, b = before[f].get(variant), after[f].get(variant)
        if a is None and b is None:
            continue
        if a is None or b is None:
            bad.append(f"{variant}: missing on one side")
            continue
        steps += len(a)
        callouts += sum(1 for s in a if s[7] > 0 and s[8] == 0)
        if a == b:
            continue
        if len(a) != len(b):
            bad.append(f"{variant}: {len(a)} steps before, {len(b)} after")
            continue
        for at, (x, y) in enumerate(zip(a, b)):
            if x != y:
                which = [FIELDS[k] for k in range(len(FIELDS)) if x[k] != y[k]]
                bad.append(f"{variant}: step {at + 1} differs in {', '.join(which)}")
                break
    if bad:
        differ += 1
        a, b = before[f].get("geometry"), after[f].get("geometry")
        if a is not None and b is not None and a != b:
            moved_parts += 1
            bad.append("and its parts' geometry differs")
        print(f, "; ".join(bad))
print(f"{len(files)} files compared, {differ} differ ({moved_parts} of them with other parts' "
      f"geometry), {len(missing)} missing on one side; "
      f"{steps} steps and {callouts} callouts compared (four plans a file)")
