"""The walk's 30 builders' words through search_parts, as a session asks:
where the wanted part comes, against the window's bin (APP_UX3)."""
import json, re, sys, time
sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parents[3] / "tools"))
from brickworks_mcp import App

QUERIES = [
    ["2x4", "3001"], ["brick 2x4", "3001"], ["2 x 4 brick", "3001"], ["1x2 plate", "3023"],
    ["plate 2x2", "3022"], ["3001", "3001"], ["300121", "3001"], ["slope 45 2x2", "3039"],
    ["cheese slope", "54200"], ["tile 1x2", "3069b"], ["grille", "2412b"], ["jumper", "3794b"],
    ["headlight", "4070"], ["round 1x1", "4073"], ["hinge", ""], ["clip", ""],
    ["technic pin", "2780"], ["axle 4", "3705"], ["liftarm 7", "32524"], ["beam 7", "32524"],
    ["window", ""], ["door", ""], ["wheel", ""], ["minifig head", "3626"], ["torso", ""],
    ["macaroni", "25269"], ["snot", ""], ["bracket", "99781"], ["log", "30136"], ["arch", ""],
    ["1x4 brick", "3010"],
]
app = App(int(sys.argv[1]))
first = top3 = 0
wanted = 0
for query, want in QUERIES:
    t = time.time()
    answer = app.ask("search_parts", {"query": query, "limit": 20})
    ms = (time.time() - t) * 1000
    text = " ".join(b.get("text", "") for b in answer.get("content", []) if b.get("type") == "text")
    ids = re.findall(r"^([0-9A-Za-z][0-9A-Za-z.-]*): ", text, re.M)
    rank = ids.index(want) + 1 if want and want in ids else None
    if want:
        wanted += 1
        first += rank == 1
        top3 += bool(rank and rank <= 3)
    print("search %-16s want=%-6s rank=%-4s %4.0f ms first=%s" % ('"%s"' % query, want, rank or "-", ms,
          " | ".join(ids[:5])))
print("wanted parts first: %d of %d; in the top three: %d" % (first, wanted, top3))
open(sys.argv[2], "w").write(json.dumps({"q": QUERIES}))
