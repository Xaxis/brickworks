---
tool: check_design
example: {"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0}, {"part": "3001", "color": 4, "x": 2, "y": 3, "z": 0}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Check a list of parts for overlaps, floating parts and whether it is one connected model, and weigh it: whether it stands (its centre of mass against the edge of what it stands on, in every pose its hinges and turntables reach), the counterweight that would hold it, and its most loaded stud joints. Safe to call on a partial design while you work. Or edit= instead of bricks: the model as it stands with that change made to a copy, to ask what if.
```
