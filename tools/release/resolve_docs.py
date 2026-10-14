import re, sys
pat = re.compile(r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", re.S)
def fix(o, t):
    if o.startswith("<!-- covers:") and t.startswith("<!-- covers:"):
        a = re.search(r"covers: (.*?) -->", o).group(1).split(", ")
        b = re.search(r"covers: (.*?) -->", t).group(1).split(", ")
        return "<!-- covers: " + ", ".join(a + [x for x in b if x not in a]) + " -->\n"
    if t.strip() in o: return o
    if o.strip() in t: return t
    return o + t
for p in sys.argv[1:]:
    s = open(p).read(); n = len(pat.findall(s))
    s = pat.sub(lambda m: fix(m.group(1), m.group(2)), s); open(p, "w").write(s)
    print(p, n, "resolved")
