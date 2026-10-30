---
tool: place_technique
example: {"id": "posed minifigure", "x": 4, "y": 1, "z": 2, "turn": 1}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Lay one of find_techniques' pieces into the model as the LEGO Group built it, or one of show_technique's by its name (a posed minifigure, a hinged wing: its joints put by their connectors): every part where the set has it, turned a number of quarter turns about the upright and moved so its low corner is at x, y, z, in your colours if you say which of its colours become which. The app finds the hold: laid where you say if the model holds it there, or at the nearest place within 4 studs where it does (a free stud under each part that needs one), and otherwise refused with the nearest place that holds it. Parts cannot be scaled: the answer says the same build at the sizes real sets use it, to pick the one your model's scale wants. Checked like any edit. The answer says where it went and what holds it, and lists the bricks as placed.
```
