#!/usr/bin/env python3
"""Two house_listing.mjs files: what was there before, and whether any of it changed.

    python3 tools/house_models/compare.py BEFORE.json AFTER.json

For the house account's own rows and the public gallery's: how many before and
after, which rows there before differ in any field after (views, likes,
remixes, builds and comments, which visitors change, left out), and the names
of the new ones; then how many gallery rows are not the house's. Used by
seed211 (2026-10-24): 7 before, 19 after, none of the seven changed.
"""
import json
import sys

if len(sys.argv) < 3:
    sys.exit(__doc__)
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
SKIP = {"views", "likes", "remixes", "builds", "comments", "viewer"}


def rows(d, key):
    return {r["id"]: r for r in (d["mine"].get("shared", []) if key == "mine" else d["gallery"])}


def fields(r):
    return {k: v for k, v in r.items() if k not in SKIP}


changed_any = False
for key in ("mine", "gallery"):
    old, new = rows(a, key), rows(b, key)
    changed = [i for i in old if i not in new or fields(old[i]) != fields(new[i])]
    changed_any = changed_any or bool(changed)
    print("%s: %d before, %d after, %d of those before changed %s; new: %s" % (
        key, len(old), len(new), len(changed), changed, [new[i]["name"] for i in new if i not in old]))
    for i in changed:
        if i in new:
            print("   ", i, {k: (old[i].get(k), new[i].get(k)) for k in set(old[i]) | set(new[i])
                             if k not in SKIP and old[i].get(k) != new[i].get(k)})
print("gallery rows not the house's: %d" % len([r for r in b["gallery"] if (r.get("by") or {}).get("handle") != "brickworks"]))
sys.exit(1 if changed_any else 0)
