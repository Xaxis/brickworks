---
tool: where_to_attach
example: {"part": "49668", "toward": "out", "limit": 4}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Where the selected parts can take another part: every open stud, anti-stud (the hollow underneath that takes a stud), side stud, pin hole, bar and clip, grouped by the way it faces, each with the part that carries it and where it is in the coordinates edit_selection takes (a section's own, for parts laid turned), and a picture with the free ones numbered. Give part= (and color=) and it seats that part on them and tries each against the model as it stands: what comes back fits and holds, to put in edit_selection's add as it is. toward= puts first the points facing that way (out: away from the model's middle, for spikes or detail on an outer face); near= {x, y, z} those nearest a place.
```
