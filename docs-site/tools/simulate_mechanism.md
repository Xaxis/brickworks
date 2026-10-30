---
tool: simulate_mechanism
example: {"driver": "crank", "record": true, "turns": 2}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Turn the model's gear train as Tools, Simulate mechanism does, and what it drives in a loop as a drag moves it (a pinion's rack slides, a crank's rod rocks and its slider strokes), without changing the model: from driver= (a part's number or a sub-assembly's name; else the one named Crank, Motor or Handle, else the one that turns most). It says each turning part's turns per driver turn and, with reference= (the part periods are counted in; Earth when one is named so), every other's period in its turns, against the real one for a planet or targets= ({name: period}). It names a locked train's meshes and the free and floating parts by number, and weighs the balance over the whole cycle: the worst frame, the arm furthest past the base's edge, a picture of it there. record=true also renders turns= turns of the reference (1) in frames= frames (24) as a WebP and an MP4 where Render saves, as a job (job gives the result).
```
