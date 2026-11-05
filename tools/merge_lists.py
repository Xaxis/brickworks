#!/usr/bin/env python3
"""Merge a list kept one entry a line: tools/suite/*.txt and supabase/later.tsv.

A union merge keeps both sides' new lines, so two units each adding a probe
never conflict. But it keeps lines, not entries: a unit that edited a probe's
comment came out of the merge with the old line and the new one, the probe
listed twice, and tools/check.sh --lists refused the suite. That happened
twice to steps_kept (62d9de65, fe6808ae), fixed by hand each time. A union
also brings back a line one side took out when the other added one beside it.

So this merges entries. An entry is a probe, known by its name (before any
`:ARGS` and `#` comment, as check.sh reads it), or a later.tsv row, known by
its earlier file, function and later file. Each is merged three ways: one
added on either side is kept; one removed on either side stays removed; one
changed on one side takes the change; one changed both ways takes the side
being merged in. git's own union lays the lines out, so comments and blank
lines keep their place, and each entry is written once, where its winning
line stands. It never leaves a conflict.

As a git merge driver (.gitattributes: merge=lists):

    git config merge.lists.driver "python3 tools/merge_lists.py %O %A %B %P"

The main checkout's .git/config has that, which every worktree shares, and
tools/release/merge_unit.sh passes it on its merge, so a fresh clone merges a
unit right too. A merge with no driver configured falls back to git's text
merge, which stops on a conflict where a union would list a probe twice.
"""
import re
import subprocess
import sys


def key(line, path):
    """What names the entry on [line], or None for a comment or a blank."""
    text = line.rstrip("\r\n")
    if path.endswith(".tsv"):
        if not text.strip() or text.startswith("#"):
            return None
        return tuple(text.split("\t")[:3])
    name = re.sub(r"(^|\s)#.*", "", text).strip()
    return name.split(":", 1)[0] if name else None


def entries(lines, path):
    """{key: line} of a side, and the keys it has on more than one line."""
    out, twice = {}, set()
    for line in lines:
        k = key(line, path)
        if k in out:
            twice.add(k)
        elif k is not None:
            out[k] = line.rstrip("\r\n")
    return out, twice


def winner(base, ours, theirs):
    """The entry's line after the merge, or None for no line."""
    if ours is None or theirs is None:
        if base is not None:
            return None  # removed on one side
        return ours if theirs is None else theirs
    if ours == theirs or theirs == base:
        return ours
    return theirs  # changed on their side only, or both ways: theirs


def merge(base, ours, theirs, union, path):
    """The merged lines, laid out as git's union [union] has them."""
    (b, _), (o, o2), (t, t2) = (entries(side, path) for side in (base, ours, theirs))
    # A key one side already has twice is left as the union has it: nothing
    # is lost, and check.sh still names a probe listed twice.
    wanted, twice = {}, o2 | t2
    for k in list(o) + [k for k in t if k not in o]:
        line = winner(b.get(k), o.get(k), t.get(k))
        if line is not None and k not in twice:
            wanted[k] = line
    out = []
    for line in union:
        line = line if line.endswith("\n") else line + "\n"
        k = key(line, path)
        if k is None or k in twice:
            out.append(line)
        elif wanted.get(k) == line.rstrip("\r\n"):
            out.append(line)
            del wanted[k]
    # Every winning line is one side's, so the union has it; none is lost if not.
    out += [line + "\n" for line in wanted.values()]
    return out


def main(base_path, ours_path, theirs_path, path):
    def read(name):
        with open(name, encoding="utf-8") as f:
            return f.read().splitlines(keepends=True)

    union = subprocess.run(
        ["git", "merge-file", "-p", "--union", ours_path, base_path, theirs_path],
        capture_output=True, text=True, check=True).stdout.splitlines(keepends=True)
    merged = merge(read(base_path), read(ours_path), read(theirs_path), union, path)
    with open(ours_path, "w", encoding="utf-8") as f:
        f.writelines(merged)
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:5]))
