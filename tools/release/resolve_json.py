#!/usr/bin/env python3
"""Settle a conflicted JSON file whose two sides each added entries: three-way, by meaning.

    tools/release/resolve_json.py PATH    (run inside a merge, PATH conflicted)

The site's word lists (web/_lang/*.json) and the docs' picture lists
(docs-site/pictures/*.json) take a block from every unit at their end, so two
units conflict there at every merge (remixdiff after claudelink, 2026-11-23:
85 files held, the translated pages with them). Read from the index's three
stages (base, ours, theirs): an object merges key by key, a list of objects
with an "id" merges by id (ours' order, then theirs' new ones); where one side
left a value as the base had it, the other side's value is kept; where both
changed one value differently it stays a conflict (exit 1, the key said).
Written as the file is written (indent 1, characters as they are).
"""
import json
import subprocess
import sys


class Clash(Exception):
    pass


def stage(n, path):
    out = subprocess.run(["git", "show", f":{n}:{path}"], capture_output=True, text=True)
    return json.loads(out.stdout) if out.returncode == 0 else None


def by_id(items):
    return all(isinstance(one, dict) and "id" in one for one in items)


def merge(base, ours, theirs, where):
    if ours == theirs:
        return ours
    if ours == base:
        return theirs
    if theirs == base:
        return ours
    if isinstance(ours, dict) and isinstance(theirs, dict):
        base = base if isinstance(base, dict) else {}
        out = {}
        for key in [*ours, *(k for k in theirs if k not in ours)]:
            if key in ours and key in theirs:
                out[key] = merge(base.get(key), ours[key], theirs[key], f"{where}.{key}")
            elif key in ours:
                if key in base and base[key] != ours[key]:
                    raise Clash(f"{where}.{key}: changed here, removed there")
                if key not in base:
                    out[key] = ours[key]
            else:
                if key in base and base[key] != theirs[key]:
                    raise Clash(f"{where}.{key}: removed here, changed there")
                if key not in base:
                    out[key] = theirs[key]
        return out
    if isinstance(ours, list) and isinstance(theirs, list) and by_id(ours) and by_id(theirs):
        base = base if isinstance(base, list) and by_id(base) else []
        b = {one["id"]: one for one in base}
        o = {one["id"]: one for one in ours}
        t = {one["id"]: one for one in theirs}
        out = []
        for key in [*o, *(k for k in t if k not in o)]:
            if key in o and key in t:
                out.append(merge(b.get(key), o[key], t[key], f"{where}[{key}]"))
            elif key in o:
                if key in b and b[key] != o[key]:
                    raise Clash(f"{where}[{key}]: changed here, removed there")
                if key not in b:
                    out.append(o[key])
            else:
                if key in b and b[key] != t[key]:
                    raise Clash(f"{where}[{key}]: removed here, changed there")
                if key not in b:
                    out.append(t[key])
        return out
    raise Clash(f"{where}: both sides changed it differently")


def main(path):
    base, ours, theirs = stage(1, path), stage(2, path), stage(3, path)
    if ours is None or theirs is None:
        print(f"{path}: not conflicted in both sides")
        return 1
    try:
        merged = merge(base, ours, theirs, path)
    except Clash as clash:
        print(f"{path}: {clash}")
        return 1
    with open(path, "w", encoding="utf-8") as out:
        out.write(json.dumps(merged, ensure_ascii=False, indent=1) + "\n")
    print(f"{path}: settled")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
