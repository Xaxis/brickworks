---
tool: plan_massing
example: {"subject": "a lighthouse on a rock", "volumes": [{"name": "rock", "x_from": 0, "x_to": 16, "z_from": 0, "z_to": 14, "y_from": 0, "y_to": 9, "top": {"x_from": 3, "x_to": 13, "z_from": 3, "z_to": 11}}, {"name": "tower", "x_from": 5, "x_to": 11, "z_from": 4, "z_to": 10, "y_from": 9, "y_to": 60, "round": true, "top": {"x_from": 6, "x_to": 10, "z_from": 5, "z_to": 9}}, {"name": "lantern", "x_from": 6, "x_to": 10, "z_from": 5, "z_to": 9, "y_from": 60, "y_to": 72, "round": true}], "front": "a tall white tower tapering over a low rock, the lantern a narrower drum on top", "side": "the same, the rock deeper than it is wide"}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
The model's massing, planned before its first brick: the subject's main volumes, each a footprint in studs and a height in plates, on the ground or on another volume (set back from its edges or overhanging them), round or square, its top the same or narrower (a roof falling to its eaves, a taper, a wedge); and what you would know it by from the front and from the side. The answer says how much of its box that fills against real sets of its theme and size, and draws its outline from the front and the side, while changing it costs nothing. Each build of the design is then read against these volumes: each there at its height, the setbacks, the gaps and the space under an overhang kept. Call it after how_real_sets_build_this and before the first submit_design, in the coordinates the design is built in.
```
