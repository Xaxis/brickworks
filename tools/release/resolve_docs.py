import re, sys
# A doc conflict is resolved by keeping both sides: two units each added a
# section, and both belong. When both reworded the same lines, though, the
# union keeps two versions of one sentence, and docs/CADTASK.md shipped two
# such pairs (2026-10-16). So a union names every line that begins as a line
# from the other side does, for whoever merged to read and mend.
pat = re.compile(r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", re.S)
doubled = []
def starts(text):
    return {l.strip()[:40] for l in text.split("\n") if len(l.strip()) >= 40}
def fix(o, t):
    if o.startswith("<!-- covers:") and t.startswith("<!-- covers:"):
        a = re.search(r"covers: (.*?) -->", o).group(1).split(", ")
        b = re.search(r"covers: (.*?) -->", t).group(1).split(", ")
        return "<!-- covers: " + ", ".join(a + [x for x in b if x not in a]) + " -->\n"
    if t.strip() in o: return o
    if o.strip() in t: return t
    both = starts(o) & starts(t)
    doubled.extend(sorted(both))
    return o + t
for p in sys.argv[1:]:
    doubled.clear()
    s = open(p).read(); n = len(pat.findall(s))
    s = pat.sub(lambda m: fix(m.group(1), m.group(2)), s); open(p, "w").write(s)
    print(p, n, "resolved")
    for line in doubled:
        print("  DOUBLED? %s: a line beginning %r is in both sides; keep one" % (p, line))
