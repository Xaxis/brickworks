#!/usr/bin/env python3
"""resolve_po.py FILE: resolve a merge conflict in a language's word list by keeping both sides.

Every unit that adds words appends its own block at the end of locale/*.po, so two units merged
one after the other conflict there every time: quiet and whatsthis did, one after the other, on
2026-11-06. Both blocks belong. This keeps both sides of each conflict and writes the file only
when no entry (msgctxt and msgid) then appears twice and every msgid has its msgstr: a conflict
where both sides changed the same entry stays for a person to resolve. Exits 0 when it wrote the
file, 1 when it left it as it was.
"""
import re
import sys
from collections import Counter

MARK = re.compile(r"^(<<<<<<< .*|=======|>>>>>>> .*|\|\|\|\|\|\|\| .*)$")


def entries(lines):
    """(msgctxt, msgid) of each entry, the msgids with no msgstr after them, and those with two
    msgstr of one form (both sides changed the same translation)."""
    keys, bare, doubled, ctx, current, forms = [], [], [], None, None, set()
    for line in lines:
        m = re.match(r'^msgctxt "(.*)"$', line)
        if m:
            ctx = m.group(1)
            continue
        m = re.match(r'^msgid "(.*)"$', line)
        if m:
            if current is not None and not forms:
                bare.append(current)
            current, forms = (ctx, m.group(1)), set()
            keys.append(current)
            ctx = None
            continue
        m = re.match(r'^(msgstr(\[\d+\])?) ', line)
        if m and current is not None:
            if m.group(1) in forms:
                doubled.append(current)
            forms.add(m.group(1))
    if current is not None and not forms:
        bare.append(current)
    return keys, bare, doubled


def main(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    if not any(MARK.match(line) for line in lines):
        return 1
    # A diff3 base section (||||||| to =======) is the base's lines: drop them, keep both sides.
    kept, in_base = [], False
    for line in lines:
        if line.startswith("||||||| "):
            in_base = True
            continue
        if line == "=======":
            in_base = False
            continue
        if MARK.match(line) or in_base:
            continue
        kept.append(line)
    keys, bare, doubled = entries(kept)
    twice = [k for k, n in Counter(keys).items() if n > 1 and k[1]] + doubled
    if twice or bare:
        for k in twice[:5]:
            print(f"resolve_po: {path}: twice: {k[1]!r}" + (f" ({k[0]})" if k[0] else ""))
        for k in bare[:5]:
            print(f"resolve_po: {path}: no msgstr: {k[1]!r}")
        return 1
    open(path, "w", encoding="utf-8").write("\n".join(kept))
    print(f"resolve_po: {path}: both sides kept, {len(keys)} entries, none twice")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
