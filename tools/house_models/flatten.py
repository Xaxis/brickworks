#!/usr/bin/env python3
"""A model as one flat LDraw file, ready for the step fixer.

    python3 tools/house_models/flatten.py IN.ldr OUT.ldr ["TITLE"] [--steps]

Every part of IN's sub-models is placed in the main model's own frame (colour
16 takes its parent's), so OUT is a list of parts the app opens as the same
model. Without --steps it has no steps, and the app works them out; with
--steps the author's own steps are kept in the order the sub-models are walked
and OUT is marked AUTHORED_STEPS. The main model's floor and its motions
(MOTION, MOTION_DRIVER, MOTION_TRACK, MOTION_KEY, whose joints are named by
part and position in that frame) are kept.

A part printed here (bw-<part>-p<hash>.dat, the app's print designer) is not a
real element, and the Tested mark refuses it: it goes back to the real part it
was printed on, in its colour. A sticker made here (bw-st-<hash>.dat) has no
real part under it and is left off. Each is said.

Used by seed211 (2026-10-24) on the twelve house models for the gallery, before
fixsteps.gd: the fox's printed nameplate, the bakery's sign and chalkboard and
the campsite's sign went back to plain tiles and a panel or came off.
"""
import re
import sys

STEPS = "--steps" in sys.argv
sys.argv = [a for a in sys.argv if a != "--steps"]
if len(sys.argv) < 3:
    sys.exit(__doc__)
src = open(sys.argv[1]).read().replace("\r\n", "\n").split("\n")
files, order, cur = {}, [], None
for line in src:
    t = line.strip()
    if t.startswith("0 FILE "):
        cur = t[7:].strip().lower(); files[cur] = []; order.append(cur); continue
    if t == "0 NOFILE":
        cur = None; continue
    if cur is None:
        if not files:
            cur = "__main__"; files[cur] = []; order.append(cur)
        else:
            continue
    files[cur].append(t)
main = order[0]
head = [l for l in files[main] if l.startswith("0 !BRICKWORKS FLOOR") or l.startswith("0 !BRICKWORKS MOTION")]


def mul(a, b):  # 3x3, row-major
    return [sum(a[r * 3 + k] * b[k * 3 + c] for k in range(3)) for r in range(3) for c in range(3)]


def num(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if abs(v - round(v)) > 1e-6 else str(int(round(v)))


out = []


def walk(name, pos, rot, colour):
    for l in files[name]:
        if l == "0 STEP" and STEPS:
            if out and out[-1] != "0 STEP":
                out.append("0 STEP")
            continue
        if not l.startswith("1 "):
            continue
        f = l.split()
        c = int(f[1]); x, y, z = map(float, f[2:5]); m = list(map(float, f[5:14])); ref = " ".join(f[14:])
        cc = colour if c == 16 else c
        p = [pos[0] + rot[0] * x + rot[1] * y + rot[2] * z, pos[1] + rot[3] * x + rot[4] * y + rot[5] * z,
             pos[2] + rot[6] * x + rot[7] * y + rot[8] * z]
        r = mul(rot, m)
        printed = re.match(r"bw-([0-9a-z]+)-p[0-9a-f]+\.dat$", ref.lower())
        if printed:
            print("  printed here, put back as the real part: %s -> %s.dat" % (ref, printed.group(1)))
            ref = printed.group(1) + ".dat"
        elif re.match(r"bw-st-[0-9a-f]+\.dat$", ref.lower()):
            print("  a sticker made here, left off: %s" % ref)
            continue
        if ref.lower() in files:
            walk(ref.lower(), p, r, cc)
        else:
            out.append("1 %d %s %s %s" % (cc, " ".join(num(v) for v in p), " ".join(num(v) for v in r), ref))


walk(main, [0, 0, 0], [1, 0, 0, 0, 1, 0, 0, 0, 1], 16)
title = sys.argv[3] if len(sys.argv) > 3 else "model"
if STEPS:
    head = head + ["0 !BRICKWORKS AUTHORED_STEPS"]
lines = ["0 %s" % title, "0 Name: model.ldr", "0 Author: Brickworks"] + head + [""] + out + [""]
open(sys.argv[2], "w").write("\n".join(lines))
print("%d parts flattened from %d files" % (len([l for l in out if l.startswith("1 ")]), len(order)))
