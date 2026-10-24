#!/usr/bin/env python3
"""A flat model without some of its part lines.

    python3 tools/house_models/drop.py IN.ldr OUT.ldr "1 25 330 -112 -300 ... 3004.dat" ...

Each line given, matched exactly (as fixsteps.gd prints it), is taken out once.
Used by seed211 (2026-10-24) for the few parts fixsteps.gd found hidden behind
what was built even beside the part that holds them, all inside a body where
no one sees them: two bricks and a plate inside the fox, two of the first
dragon's coins under its hoard. Run fixsteps.gd again after, to be sure nothing
stood on them.
"""
import sys

if len(sys.argv) < 3:
    sys.exit(__doc__)
lines = open(sys.argv[1]).read().replace("\r\n", "\n").split("\n")
kept = [l.strip() for l in lines]
for gone in sys.argv[3:]:
    try:
        i = kept.index(gone.strip())
    except ValueError:
        sys.exit("drop.py: no line %s" % gone)
    del lines[i]
    del kept[i]
open(sys.argv[2], "w").write("\n".join(lines))
print("dropped %d" % len(sys.argv[3:]))
