---
tool: make_part
example: {"family": "slope", "angle": 45, "across": 3, "deep": 2}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Make a part the LEGO Group has not made, when no real part will do: search_parts first, and use a real one if there is one. Either a new part of a family at any size — a 1 x 7 brick, a bracket with a 3 x 2 upright, a Technic brick 1 x 9, a brick with studs on two sides — or a real part changed: from="3700" with across 6, from="3062b" without its studs, from="3003" with a corner cut out. It is checked as a person's part is (sizes the system has, walls 1.6 mm, studs on the grid) and refused with the reason if it cannot be made. Made, it is a part like any other: put its number in check_design, edit_model or submit_design, and a saved model carries it. Its studs, holes and pins are found as a real part's are, so it clutches and pins as they do.
```
