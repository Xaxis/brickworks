#!/usr/bin/env python3
"""Two checkouts' plans (src/dev/plan_dump.gd --dump), file by file and plan by plan.

    tools/plan_diff.py BEFORE.jsonl AFTER.jsonl

A change meant only to make planning faster must not move a step: the steps
score's measures can stay put while steps move, so the plans themselves are
compared.

Every step's every field is compared: its bricks, parts, section, callout
fields, copies, the author's step it is, and the step player's view (the
direction and the box framed). Prints each file that differs and how.
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
    return out


before, after = rows(sys.argv[1]), rows(sys.argv[2])
files = [f for f in before if f in after]
missing = [f for f in before if f not in after] + [f for f in after if f not in before]
differ = 0
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
        print(f, "; ".join(bad))
print(f"{len(files)} files compared, {differ} differ, {len(missing)} missing on one side; "
      f"{steps} steps and {callouts} callouts compared (four plans a file)")
