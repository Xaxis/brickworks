#!/usr/bin/env python3
"""Merge .claude/skills/verify/featuremap.config.json as data, not lines.

Every branch that adds a feature appends an entry to the end of "manual",
so any two branches that both add one conflict on the same closing lines,
and resolving it by hand once left a missing "}," that broke the JSON. As a
git merge driver this merges the entries themselves:

    git config merge.featuremap.driver "python3 tools/merge_featuremap.py %O %A %B"
    (.gitattributes: .claude/skills/verify/featuremap.config.json merge=featuremap)

An entry is known by its kind and label ("ignore" entries by themselves). One
added on either side is kept, ours first; one removed on one side and left
alone on the other goes; one changed on one side takes the change. Only the
same entry changed differently on both sides, or the same top-level field
changed both ways, is a real conflict: then this exits 1 and git leaves its
usual markers.
"""
import json
import sys


def key(entry):
    if isinstance(entry, dict):
        return (entry.get("kind"), entry.get("label"))
    return entry


def merge_lists(base, ours, theirs):
    base_by = {key(e): e for e in base}
    ours_by = {key(e): e for e in ours}
    theirs_by = {key(e): e for e in theirs}
    merged = []
    for k, mine in ours_by.items():
        if k not in theirs_by:
            if k in base_by and base_by[k] == mine:
                continue  # they removed it and we left it alone
            merged.append(mine)
            continue
        other = theirs_by[k]
        if mine == other or other == base_by.get(k):
            merged.append(mine)
        elif mine == base_by.get(k):
            merged.append(other)
        else:
            raise ValueError(f"both sides changed {k}")
    for k, other in theirs_by.items():
        if k in ours_by:
            continue
        if k in base_by and base_by[k] == other:
            continue  # we removed it and they left it alone
        if k in base_by:
            raise ValueError(f"we removed {k} and they changed it")
        merged.append(other)
    return merged


def merge(base, ours, theirs):
    result = {}
    for field in list(ours) + [f for f in theirs if f not in ours]:
        b, o, t = base.get(field), ours.get(field), theirs.get(field)
        if isinstance(o, list) and isinstance(t, list):
            result[field] = merge_lists(b if isinstance(b, list) else [], o, t)
        elif o == t or t == b:
            if o is not None:
                result[field] = o
        elif o == b:
            if t is not None:
                result[field] = t
        else:
            raise ValueError(f"both sides changed {field}")
    return result


def main(base_path, ours_path, theirs_path):
    def read(path):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        return json.loads(text) if text.strip() else {}

    try:
        merged = merge(read(base_path), read(ours_path), read(theirs_path))
    except (ValueError, json.JSONDecodeError) as trouble:
        print(f"featuremap config: {trouble}", file=sys.stderr)
        return 1
    with open(ours_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
