import json, sys
for path in sys.argv[1:]:
    calls = []
    result = None
    for line in open(path):
        try: d = json.loads(line)
        except Exception: continue
        if d.get("type") == "assistant":
            for b in d["message"].get("content", []):
                if b.get("type") == "tool_use":
                    calls.append((b["name"].replace("mcp__brickworks__", ""), json.dumps(b.get("input", {}))[:160]))
        if d.get("type") == "result":
            result = d
    print("=== %s: %d calls, %s s, error=%s" % (path.split("/")[-1], len(calls),
          int(result.get("duration_ms", 0) / 1000) if result else "?", result.get("is_error") if result else "?"))
    for n, (name, args) in enumerate(calls, 1):
        print("  %2d %s %s" % (n, name, args))
    if result:
        print("  RESULT:", str(result.get("result", ""))[:1500].replace("\n", "\n    "))
