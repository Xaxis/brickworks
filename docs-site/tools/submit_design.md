---
tool: submit_design
example: {"name": "Red house", "description": "A small red house with a door at the front", "brief": "build a small red house", "bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0}, {"part": "3001", "color": 4, "x": 4, "y": 0, "z": 0}], "assemblies": [{"name": "walls", "x_from": 0, "x_to": 8, "z_from": 0, "z_to": 6}], "features": [{"name": "front door", "x": 3, "y": 0, "z": 0, "facing": "+z"}]}
---

<!-- the tool list's words: tools/docs_site.py --write copies them here from tools/mcp_tools.json; --check fails while they differ -->
```text
Submit the finished model, with every part. It replaces everything on the baseplate that you put there — including anything you added with edit_model. If you have been building with edit_model, the model is already built: say so and stop, rather than submitting a list that is missing the additions.
```
