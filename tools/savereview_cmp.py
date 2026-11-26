import re, sys
def parse(path):
    out = {}; case = None
    for line in open(path, errors='replace'):
        line = line.rstrip('\n')
        m = re.match(r'^== (\S+)', line)
        if m:
            case = m.group(1); out[case] = []; continue
        if case is None: continue
        s = line.strip()
        if s.startswith(('W ', 'L ', 'S ', 'ok', 'FAIL', 'NOTE', 'T ')) or s.startswith(('worst:', 'lost:', 'kind:', 'step:')):
            s = re.sub(r'^(ok|FAIL)\s+', lambda m: m.group(1) + ' ', s)
            out[case].append(s)
    return out
a = parse(sys.argv[1]); b = parse(sys.argv[2])
show_t = len(sys.argv) > 3
for case in list(dict.fromkeys(list(a) + list(b))):
    la = [x for x in a.get(case, []) if show_t or not x.startswith('T ')]
    lb = [x for x in b.get(case, []) if show_t or not x.startswith('T ')]
    if la == lb and not show_t:
        print(f"== {case}: same"); continue
    print(f"== {case}")
    for x, y in zip(la + [''] * (len(lb) - len(la)), lb + [''] * (len(la) - len(lb))):
        if x == y: print("   =", x[:200])
        else:
            print("   B", x[:300]); print("   H", y[:300])
